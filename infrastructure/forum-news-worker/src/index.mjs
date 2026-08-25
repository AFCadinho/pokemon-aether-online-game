const DEFAULTS = Object.freeze({
  forumBaseUrl: "https://forums.pokeaether.com",
  categoryId: 17,
  maxArticles: 5,
  summaryLength: 180,
  newsKey: "data/news.json",
  previousNewsKey: "data/news.previous.json",
});

const MAX_WEBHOOK_BYTES = 256 * 1024;
const MAX_DISCOURSE_BYTES = 2 * 1024 * 1024;
const MAX_FETCH_ATTEMPTS = 3;
const CACHE_CONTROL = "no-cache, max-age=0";
const USER_AGENT = "PokeAether-Forum-News-Worker/1.0";
const MONTH_NAMES = Object.freeze([
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
]);

const HTML_ENTITIES = Object.freeze({
  amp: "&",
  apos: "'",
  gt: ">",
  hellip: "…",
  ldquo: "“",
  lsquo: "‘",
  lt: "<",
  mdash: "—",
  nbsp: " ",
  ndash: "–",
  quot: '"',
  rdquo: "”",
  rsquo: "’",
});

export class FeedError extends Error {}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return jsonResponse({ ok: true, service: "pokeaether-forum-news" });
    }
    if (request.method !== "POST" || url.pathname !== "/webhooks/discourse") {
      return new Response("Not found", { status: 404 });
    }

    try {
      const config = readConfig(env, { requireSecret: true });
      const rawBody = await readLimitedBody(request, MAX_WEBHOOK_BYTES);
      const signature = request.headers.get("X-Discourse-Event-Signature") || "";
      if (!(await verifyDiscourseSignature(rawBody, signature, config.webhookSecret))) {
        return new Response("Unauthorized", { status: 401 });
      }

      let payload;
      try {
        payload = JSON.parse(new TextDecoder().decode(rawBody));
      } catch {
        return new Response("Invalid JSON", { status: 400 });
      }
      if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
        return new Response("Invalid JSON", { status: 400 });
      }

      const eventType = (request.headers.get("X-Discourse-Event-Type") || "").toLowerCase();
      if (eventType === "ping") {
        return new Response(null, { status: 204 });
      }
      if (eventType !== "topic") {
        return new Response("Unsupported Discourse event", { status: 400 });
      }

      await syncForumNews(env, config);
      return new Response(null, { status: 204 });
    } catch (error) {
      console.error(`Forum news webhook failed: ${safeErrorMessage(error)}`);
      return new Response("News synchronization failed", { status: 500 });
    }
  },

  async scheduled(_controller, env) {
    try {
      await syncForumNews(env, readConfig(env));
    } catch (error) {
      console.error(`Forum news reconciliation failed: ${safeErrorMessage(error)}`);
      throw error;
    }
  },
};

export async function syncForumNews(env, suppliedConfig = null, fetchImpl = fetch) {
  if (!env?.UPDATES_BUCKET || typeof env.UPDATES_BUCKET.get !== "function") {
    throw new FeedError("UPDATES_BUCKET binding is missing");
  }
  const config = suppliedConfig || readConfig(env);
  const { categoryPayload, topicsPayload } = await fetchCategoryPayloads(config, fetchImpl);
  const feed = buildFeed(categoryPayload, topicsPayload, config);
  const rendered = `${JSON.stringify(feed, null, 2)}\n`;

  const current = await env.UPDATES_BUCKET.get(config.newsKey);
  if (current === null) {
    const created = await env.UPDATES_BUCKET.put(config.newsKey, rendered, objectOptions());
    if (created === null) {
      throw new FeedError("news feed was created concurrently; retry reconciliation");
    }
    return { changed: true, articles: feed.articles.length };
  }
  if (typeof current.text !== "function") {
    throw new FeedError("current news object has no readable body");
  }

  const currentText = await current.text();
  let currentFeed;
  try {
    currentFeed = JSON.parse(currentText);
  } catch {
    throw new FeedError("current news object is not valid JSON; refusing to overwrite it");
  }
  validateFeed(currentFeed);
  if (currentText === rendered) {
    return { changed: false, articles: feed.articles.length };
  }

  await env.UPDATES_BUCKET.put(config.previousNewsKey, currentText, objectOptions());
  const updated = await env.UPDATES_BUCKET.put(config.newsKey, rendered, {
    ...objectOptions(),
    onlyIf: { etagMatches: current.etag },
  });
  if (updated === null) {
    throw new FeedError("news feed changed concurrently; retry reconciliation");
  }
  return { changed: true, articles: feed.articles.length };
}

export function readConfig(env, { requireSecret = false } = {}) {
  const forumBaseUrl = normalizeForumBaseUrl(env?.FORUM_BASE_URL || DEFAULTS.forumBaseUrl);
  const categoryId = parseBoundedInteger(env?.FORUM_CATEGORY_ID, DEFAULTS.categoryId, 1, 1_000_000);
  const maxArticles = parseBoundedInteger(env?.MAX_ARTICLES, DEFAULTS.maxArticles, 1, 20);
  const summaryLength = parseBoundedInteger(env?.SUMMARY_LENGTH, DEFAULTS.summaryLength, 20, 1_000);
  const newsKey = normalizeObjectKey(env?.NEWS_OBJECT_KEY || DEFAULTS.newsKey, "NEWS_OBJECT_KEY");
  const previousNewsKey = normalizeObjectKey(
    env?.PREVIOUS_NEWS_OBJECT_KEY || DEFAULTS.previousNewsKey,
    "PREVIOUS_NEWS_OBJECT_KEY",
  );
  if (newsKey === previousNewsKey) {
    throw new FeedError("news and rollback object keys must be different");
  }

  const webhookSecret = typeof env?.DISCOURSE_WEBHOOK_SECRET === "string"
    ? env.DISCOURSE_WEBHOOK_SECRET
    : "";
  if (requireSecret && webhookSecret.length < 32) {
    throw new FeedError("DISCOURSE_WEBHOOK_SECRET must contain at least 32 characters");
  }

  return {
    forumBaseUrl,
    categoryId,
    maxArticles,
    summaryLength,
    newsKey,
    previousNewsKey,
    webhookSecret,
  };
}

export async function fetchCategoryPayloads(config, fetchImpl = fetch) {
  const categoryUrl = `${config.forumBaseUrl}/c/${config.categoryId}/show.json`;
  const topicsUrl = `${config.forumBaseUrl}/c/${config.categoryId}/l/latest.json?order=created`;
  const [categoryPayload, topicsPayload] = await Promise.all([
    fetchJson(categoryUrl, fetchImpl),
    fetchJson(topicsUrl, fetchImpl),
  ]);
  await hydrateMissingExcerpts(categoryPayload, topicsPayload, config, fetchImpl);
  return { categoryPayload, topicsPayload };
}

async function hydrateMissingExcerpts(categoryPayload, topicsPayload, config, fetchImpl) {
  const categoryTopicId = categoryTopicIdFromUrl(categoryPayload?.category?.topic_url);
  const topics = topicsPayload?.topic_list?.topics;
  if (!Array.isArray(topics)) return;

  const recentTopics = topics
    .filter((topic) => (
      topic
      && typeof topic === "object"
      && !Array.isArray(topic)
      && Number.isInteger(topic.id)
      && topic.id > 0
      && topic.id !== categoryTopicId
      && topic.category_id === config.categoryId
      && topic.visible === true
      && topic.archetype === "regular"
    ))
    .map((topic) => ({ topic, createdAt: parseDiscourseDate(topic.created_at, topic.id) }))
    .sort((left, right) => (
      right.createdAt.getTime() - left.createdAt.getTime() || right.topic.id - left.topic.id
    ))
    .slice(0, config.maxArticles);

  await Promise.all(recentTopics.map(async ({ topic }) => {
    if (cleanText(topic.excerpt)) return;

    const topicPayload = await fetchJson(`${config.forumBaseUrl}/t/${topic.id}.json`, fetchImpl);
    if (topicPayload?.id !== topic.id) {
      throw new FeedError(`Discourse topic response was for ID ${String(topicPayload?.id)}, expected ${topic.id}`);
    }
    const posts = topicPayload?.post_stream?.posts;
    const firstPost = Array.isArray(posts)
      ? posts.find((post) => post?.post_number === 1 && post?.topic_id === topic.id)
      : null;
    if (!firstPost || !cleanText(firstPost.cooked)) {
      throw new FeedError(`Discourse topic ${topic.id} has no public first-post content`);
    }
    topic.excerpt = firstPost.cooked;
  }));
}

export function buildFeed(categoryPayload, topicsPayload, config = DEFAULTS) {
  const category = categoryPayload?.category;
  if (!category || typeof category !== "object" || Array.isArray(category)) {
    throw new FeedError("Discourse category response has no category object");
  }
  if (category.id !== config.categoryId) {
    throw new FeedError(`Discourse category response was for ID ${String(category.id)}, expected ${config.categoryId}`);
  }
  if (category.read_restricted === true) {
    throw new FeedError("Official announcements category is no longer public");
  }

  const categoryTopicId = categoryTopicIdFromUrl(category.topic_url);
  const topics = topicsPayload?.topic_list?.topics;
  if (!Array.isArray(topics)) {
    throw new FeedError("Discourse topics response has no topic_list.topics array");
  }

  const candidates = [];
  for (const topic of topics) {
    if (!topic || typeof topic !== "object" || Array.isArray(topic)) continue;
    if (!Number.isInteger(topic.id) || topic.id <= 0 || topic.id === categoryTopicId) continue;
    if (topic.category_id !== config.categoryId) continue;
    if (topic.visible !== true || topic.archetype !== "regular") continue;

    const title = cleanText(topic.title);
    const summary = truncateText(cleanText(topic.excerpt), config.summaryLength);
    const createdAt = parseDiscourseDate(topic.created_at, topic.id);
    if (!title || !summary) continue;
    candidates.push({ topic, title, summary, createdAt });
  }

  candidates.sort((left, right) => (
    right.createdAt.getTime() - left.createdAt.getTime() || right.topic.id - left.topic.id
  ));
  const articles = candidates
    .slice(0, config.maxArticles)
    .map(({ topic, title, summary, createdAt }) => buildArticle(
      topic,
      title,
      summary,
      createdAt,
      config.forumBaseUrl,
    ));
  const feed = { articles };
  validateFeed(feed, { requireForumLinks: true, forumBaseUrl: config.forumBaseUrl });
  return feed;
}

export function validateFeed(feed, { requireForumLinks = false, forumBaseUrl = DEFAULTS.forumBaseUrl } = {}) {
  if (!feed || typeof feed !== "object" || Array.isArray(feed)) {
    throw new FeedError("news feed must be a JSON object");
  }
  if (!Array.isArray(feed.articles) || feed.articles.length < 1 || feed.articles.length > 20) {
    throw new FeedError("news feed must contain between 1 and 20 articles");
  }

  const requiredStrings = ["title", "date", "summary", "featuredImage", "imageAlt", "externalLink"];
  const forumOrigin = new URL(forumBaseUrl).origin;
  feed.articles.forEach((article, index) => {
    if (!article || typeof article !== "object" || Array.isArray(article)) {
      throw new FeedError(`article ${index} must be an object`);
    }
    for (const field of requiredStrings) {
      if (typeof article[field] !== "string") {
        throw new FeedError(`article ${index}.${field} must be a string`);
      }
    }
    if (!article.title.trim() || !article.date.trim() || !article.summary.trim()) {
      throw new FeedError(`article ${index} has an empty required display field`);
    }
    if (article.localizations !== undefined && (
      !article.localizations || typeof article.localizations !== "object" || Array.isArray(article.localizations)
    )) {
      throw new FeedError(`article ${index}.localizations must be an object`);
    }
    if (requireForumLinks) {
      const link = safeUrl(article.externalLink);
      if (!link || link.protocol !== "https:" || link.origin !== forumOrigin || !link.pathname.startsWith("/t/")) {
        throw new FeedError(`article ${index}.externalLink must be a forum topic URL`);
      }
      if (article.featuredImage) validateHttpsUrl(article.featuredImage, `article ${index}.featuredImage`);
    }
  });
}

export function cleanText(value) {
  if (typeof value !== "string") return "";
  const withoutUnsafeBlocks = value.replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, " ");
  const withBlockSpaces = withoutUnsafeBlocks.replace(
    /<\/?(?:address|article|aside|blockquote|br|div|figcaption|figure|footer|h[1-6]|header|li|main|nav|ol|p|section|table|td|th|tr|ul)\b[^>]*>/gi,
    " ",
  );
  const withoutTags = withBlockSpaces.replace(/<[^>]*>/g, "");
  return decodeHtmlEntities(withoutTags).replace(/\s+/gu, " ").trim();
}

export function truncateText(value, maxLength) {
  if (!Number.isInteger(maxLength) || maxLength < 2) {
    throw new FeedError("summary length must be at least 2");
  }
  if (value.length <= maxLength) return value;
  const contentLength = maxLength - 1;
  let shortened = value.slice(0, contentLength).trimEnd();
  const cutsWord = contentLength < value.length && !/\s/u.test(value[contentLength]);
  if (cutsWord && shortened.includes(" ")) shortened = shortened.slice(0, shortened.lastIndexOf(" ")).trimEnd();
  if (/[.!?…]$/u.test(shortened)) return shortened;
  return `${shortened}…`;
}

export async function verifyDiscourseSignature(rawBody, signatureHeader, secret) {
  const match = /^sha256=([0-9a-f]{64})$/i.exec(signatureHeader);
  if (!match || typeof secret !== "string" || secret.length < 32) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  return crypto.subtle.verify("HMAC", key, hexToBytes(match[1]), rawBody);
}

async function fetchJson(url, fetchImpl) {
  let lastFailure = "unknown error";
  for (let attempt = 1; attempt <= MAX_FETCH_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetchImpl(url, {
        headers: { Accept: "application/json", "User-Agent": USER_AGENT },
      });
      if (!response.ok) {
        lastFailure = `HTTP ${response.status}`;
        if (response.status < 500 || attempt === MAX_FETCH_ATTEMPTS) break;
        continue;
      }
      const body = await response.arrayBuffer();
      if (body.byteLength > MAX_DISCOURSE_BYTES) {
        throw new FeedError(`Discourse response exceeded ${MAX_DISCOURSE_BYTES} bytes`);
      }
      const payload = JSON.parse(new TextDecoder().decode(body));
      if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
        throw new FeedError("Discourse returned a JSON value that is not an object");
      }
      return payload;
    } catch (error) {
      if (error instanceof FeedError || error instanceof SyntaxError) throw error;
      lastFailure = safeErrorMessage(error);
      if (attempt === MAX_FETCH_ATTEMPTS) break;
    }
  }
  throw new FeedError(`Discourse request failed: ${url} (${lastFailure})`);
}

async function readLimitedBody(request, maxBytes) {
  const declaredLength = Number(request.headers.get("Content-Length"));
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    throw new FeedError(`webhook payload exceeded ${maxBytes} bytes`);
  }
  if (!request.body) return new ArrayBuffer(0);

  const reader = request.body.getReader();
  const chunks = [];
  let byteLength = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    byteLength += value.byteLength;
    if (byteLength > maxBytes) {
      await reader.cancel();
      throw new FeedError(`webhook payload exceeded ${maxBytes} bytes`);
    }
    chunks.push(value);
  }

  const body = new Uint8Array(byteLength);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return body.buffer;
}

function buildArticle(topic, title, summary, createdAt, forumBaseUrl) {
  const slug = /^[a-z0-9-]+$/.test(String(topic.slug || "")) ? topic.slug : "topic";
  const externalLink = `${forumBaseUrl}/t/${slug}/${topic.id}`;
  let featuredImage = typeof topic.image_url === "string" ? topic.image_url.trim() : "";
  if (featuredImage) {
    try {
      validateHttpsUrl(featuredImage, "image_url");
    } catch {
      featuredImage = "";
    }
  }
  return {
    title,
    date: `${MONTH_NAMES[createdAt.getUTCMonth()]} ${createdAt.getUTCDate()}, ${createdAt.getUTCFullYear()}`,
    summary,
    featuredImage,
    imageAlt: featuredImage ? title : "",
    externalLink,
    localizations: {},
  };
}

function parseDiscourseDate(value, topicId) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T/.test(value)) {
    throw new FeedError(`topic ${topicId} has an invalid created_at value`);
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new FeedError(`topic ${topicId} has an invalid created_at value`);
  return date;
}

function categoryTopicIdFromUrl(value) {
  if (typeof value !== "string") return null;
  const match = /\/(\d+)(?:\/)?$/.exec(value);
  return match ? Number(match[1]) : null;
}

function decodeHtmlEntities(value) {
  return value.replace(/&(#(?:x[0-9a-f]+|\d+)|[a-z][a-z0-9]+);/gi, (entity, code) => {
    if (code[0] !== "#") return HTML_ENTITIES[code.toLowerCase()] ?? entity;
    const isHex = code[1]?.toLowerCase() === "x";
    const parsed = Number.parseInt(code.slice(isHex ? 2 : 1), isHex ? 16 : 10);
    if (!Number.isInteger(parsed) || parsed < 0 || parsed > 0x10ffff || (parsed >= 0xd800 && parsed <= 0xdfff)) {
      return "�";
    }
    return String.fromCodePoint(parsed);
  });
}

function normalizeForumBaseUrl(value) {
  let url;
  try {
    url = new URL(String(value).trim());
  } catch {
    throw new FeedError("forum base URL must be a valid HTTPS origin");
  }
  if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) {
    throw new FeedError("forum base URL must be an HTTPS origin without credentials");
  }
  return `${url.origin}${url.pathname.replace(/\/+$/, "")}`;
}

function normalizeObjectKey(value, name) {
  const key = String(value).trim();
  if (!key || key.startsWith("/") || key.endsWith("/") || key.includes("..") || /[\r\n]/.test(key)) {
    throw new FeedError(`${name} is not a safe R2 object key`);
  }
  return key;
}

function parseBoundedInteger(value, fallback, minimum, maximum) {
  const parsed = value === undefined ? fallback : Number(value);
  if (!Number.isInteger(parsed) || parsed < minimum || parsed > maximum) {
    throw new FeedError(`configuration value must be an integer between ${minimum} and ${maximum}`);
  }
  return parsed;
}

function validateHttpsUrl(value, field) {
  const url = safeUrl(value);
  if (!url || url.protocol !== "https:" || url.username || url.password) {
    throw new FeedError(`${field} must be a public HTTPS URL`);
  }
}

function safeUrl(value) {
  try {
    return new URL(value);
  } catch {
    return null;
  }
}

function hexToBytes(value) {
  const bytes = new Uint8Array(value.length / 2);
  for (let index = 0; index < value.length; index += 2) {
    bytes[index / 2] = Number.parseInt(value.slice(index, index + 2), 16);
  }
  return bytes;
}

function objectOptions() {
  return {
    httpMetadata: {
      contentType: "application/json; charset=utf-8",
      cacheControl: CACHE_CONTROL,
    },
  };
}

function jsonResponse(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function safeErrorMessage(error) {
  return error instanceof Error ? error.message : "unknown error";
}
