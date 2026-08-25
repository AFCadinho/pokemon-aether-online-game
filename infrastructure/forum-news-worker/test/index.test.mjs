import assert from "node:assert/strict";
import test from "node:test";

import worker, {
  FeedError,
  buildFeed,
  cleanText,
  readConfig,
  syncForumNews,
  truncateText,
  verifyDiscourseSignature,
} from "../src/index.mjs";

const SECRET = "test-only-discourse-webhook-secret-123456789";

function categoryPayload({ categoryId = 17, topicId = 23, restricted = false } = {}) {
  return {
    category: {
      id: categoryId,
      read_restricted: restricted,
      topic_url: `/t/about-the-category/${topicId}`,
    },
  };
}

function topic(
  id,
  createdAt,
  {
    title = `Announcement ${id}`,
    excerpt = "A useful announcement summary.",
    categoryId = 17,
    visible = true,
    archetype = "regular",
    pinned = false,
    imageUrl = null,
  } = {},
) {
  return {
    id,
    title,
    slug: `announcement-${id}`,
    created_at: createdAt,
    excerpt,
    category_id: categoryId,
    visible,
    archetype,
    pinned,
    image_url: imageUrl,
  };
}

function topicsPayload(topics) {
  return { topic_list: { topics } };
}

function baseEnv(bucket = new FakeBucket()) {
  return {
    UPDATES_BUCKET: bucket,
    FORUM_BASE_URL: "https://forums.pokeaether.com",
    FORUM_CATEGORY_ID: "17",
    MAX_ARTICLES: "5",
    SUMMARY_LENGTH: "180",
    NEWS_OBJECT_KEY: "data/news.json",
    PREVIOUS_NEWS_OBJECT_KEY: "data/news.previous.json",
    DISCOURSE_WEBHOOK_SECRET: SECRET,
  };
}

function discourseFetch(
  topics = [topic(26, "2026-08-20T12:00:00Z")],
  topicDetails = {},
) {
  return async (url) => {
    if (url.includes("/show.json")) return Response.json(categoryPayload());
    if (url.includes("/l/latest.json")) return Response.json(topicsPayload(topics));
    const topicId = Number(/\/t\/(\d+)\.json$/.exec(url)?.[1]);
    if (Number.isInteger(topicId) && topicDetails[topicId]) return Response.json(topicDetails[topicId]);
    return new Response("Not found", { status: 404 });
  };
}

function topicDetail(id, cooked = "<p>A useful announcement summary.</p>") {
  return {
    id,
    post_stream: {
      posts: [{ topic_id: id, post_number: 1, cooked }],
    },
  };
}

class FakeBucket {
  constructor(objects = {}) {
    this.objects = new Map();
    this.puts = [];
    this.etagCounter = 0;
    for (const [key, value] of Object.entries(objects)) this.set(key, value);
  }

  set(key, value) {
    this.etagCounter += 1;
    this.objects.set(key, { value, etag: `etag-${this.etagCounter}` });
  }

  async get(key) {
    const object = this.objects.get(key);
    if (!object) return null;
    return {
      etag: object.etag,
      text: async () => object.value,
    };
  }

  async put(key, value, options = {}) {
    const existing = this.objects.get(key);
    if (options.onlyIf?.etagMatches !== undefined && existing?.etag !== options.onlyIf.etagMatches) {
      return null;
    }
    this.puts.push({ key, value, options });
    this.set(key, value);
    return { key, etag: this.objects.get(key).etag };
  }
}

test("buildFeed sorts by creation date and ignores pin order", () => {
  const feed = buildFeed(
    categoryPayload(),
    topicsPayload([
      topic(30, "2026-08-01T12:00:00Z", { pinned: true }),
      topic(31, "2026-08-20T12:00:00Z"),
    ]),
  );
  assert.deepEqual(feed.articles.map((article) => article.title), ["Announcement 31", "Announcement 30"]);
  assert.equal(feed.articles[0].date, "August 20, 2026");
  assert.equal(feed.articles[0].externalLink, "https://forums.pokeaether.com/t/announcement-31/31");
});

test("buildFeed excludes the category definition, hidden, foreign, and private topics", () => {
  const feed = buildFeed(
    categoryPayload(),
    topicsPayload([
      topic(23, "2026-08-21T12:00:00Z"),
      topic(24, "2026-08-20T12:00:00Z", { visible: false }),
      topic(25, "2026-08-19T12:00:00Z", { categoryId: 18 }),
      topic(26, "2026-08-18T12:00:00Z", { archetype: "private_message" }),
      topic(27, "2026-08-17T12:00:00Z"),
    ]),
  );
  assert.deepEqual(feed.articles.map((article) => article.title), ["Announcement 27"]);
});

test("text cleanup decodes entities, removes markup, and truncates on words", () => {
  assert.equal(
    cleanText("<p>Hello <strong>trainers</strong>!</p><script>bad()</script><p>More&nbsp;news&hellip;</p>"),
    "Hello trainers! More news…",
  );
  assert.equal(truncateText("alpha beta gamma delta", 17), "alpha beta gamma…");
  assert.equal(truncateText("A complete sentence. More detail follows.", 21), "A complete sentence.");
});

test("buildFeed keeps only safe featured images", () => {
  const feed = buildFeed(
    categoryPayload(),
    topicsPayload([
      topic(31, "2026-08-21T12:00:00Z", {
        imageUrl: "https://forums.pokeaether.com/uploads/default/original/image.png",
      }),
      topic(30, "2026-08-20T12:00:00Z", { imageUrl: "javascript:alert(1)" }),
    ]),
  );
  assert.equal(feed.articles[0].featuredImage, "https://forums.pokeaether.com/uploads/default/original/image.png");
  assert.equal(feed.articles[0].imageAlt, "Announcement 31");
  assert.equal(feed.articles[1].featuredImage, "");
  assert.equal(feed.articles[1].imageAlt, "");
});

test("buildFeed fails closed for a wrong, private, or empty category", () => {
  const payload = topicsPayload([topic(30, "2026-08-20T12:00:00Z")]);
  assert.throws(() => buildFeed(categoryPayload({ categoryId: 18 }), payload), /expected 17/);
  assert.throws(() => buildFeed(categoryPayload({ restricted: true }), payload), /no longer public/);
  assert.throws(() => buildFeed(categoryPayload(), topicsPayload([])), /between 1 and 20/);
});

test("configuration requires a strong webhook secret only for HTTP webhooks", () => {
  assert.doesNotThrow(() => readConfig(baseEnv(), { requireSecret: true }));
  const env = baseEnv();
  env.DISCOURSE_WEBHOOK_SECRET = "too-short";
  assert.throws(() => readConfig(env, { requireSecret: true }), /at least 32 characters/);
  assert.doesNotThrow(() => readConfig(env));
});

test("signature verification authenticates the exact raw body", async () => {
  const body = new TextEncoder().encode('{"topic":{"id":26}}');
  const signature = await sign(body, SECRET);
  assert.equal(await verifyDiscourseSignature(body, signature, SECRET), true);
  assert.equal(await verifyDiscourseSignature(new TextEncoder().encode("{}"), signature, SECRET), false);
  assert.equal(await verifyDiscourseSignature(body, "", SECRET), false);
});

test("sync creates an initial feed with mutable-cache metadata", async () => {
  const bucket = new FakeBucket();
  const env = baseEnv(bucket);
  const result = await syncForumNews(env, readConfig(env), discourseFetch());
  assert.deepEqual(result, { changed: true, articles: 1 });
  assert.equal(bucket.puts.length, 1);
  assert.equal(bucket.puts[0].key, "data/news.json");
  assert.deepEqual(bucket.puts[0].options.httpMetadata, {
    contentType: "application/json; charset=utf-8",
    cacheControl: "no-cache, max-age=0",
  });
});

test("sync fetches public first-post content when Discourse omits a topic excerpt", async () => {
  const bucket = new FakeBucket();
  const env = baseEnv(bucket);
  const announcement = topic(62, "2026-08-25T00:20:55Z", {
    title: "Battle Engine Update",
    excerpt: null,
  });
  const result = await syncForumNews(
    env,
    readConfig(env),
    discourseFetch([announcement], { 62: topicDetail(62, "<p>New Mega Evolutions are here!</p>") }),
  );

  assert.deepEqual(result, { changed: true, articles: 1 });
  const feed = JSON.parse(bucket.puts[0].value);
  assert.equal(feed.articles[0].title, "Battle Engine Update");
  assert.equal(feed.articles[0].summary, "New Mega Evolutions are here!");
});

test("sync preserves the current feed when missing topic content cannot be hydrated", async () => {
  const previous = JSON.stringify({
    articles: [{
      title: "Legacy",
      date: "August 1, 2026",
      summary: "Previous valid news.",
      featuredImage: "",
      imageAlt: "",
      externalLink: "",
      localizations: {},
    }],
  });
  const bucket = new FakeBucket({ "data/news.json": previous });
  const env = baseEnv(bucket);
  const announcement = topic(62, "2026-08-25T00:20:55Z", { excerpt: null });

  await assert.rejects(
    syncForumNews(env, readConfig(env), discourseFetch([announcement])),
    /Discourse request failed/,
  );
  assert.equal(bucket.puts.length, 0);
  assert.equal(await (await bucket.get("data/news.json")).text(), previous);
});

test("sync skips writes when the generated feed is byte-identical", async () => {
  const config = readConfig(baseEnv());
  const rendered = `${JSON.stringify(buildFeed(
    categoryPayload(),
    topicsPayload([topic(26, "2026-08-20T12:00:00Z")]),
    config,
  ), null, 2)}\n`;
  const bucket = new FakeBucket({ "data/news.json": rendered });
  const env = baseEnv(bucket);
  const result = await syncForumNews(env, readConfig(env), discourseFetch());
  assert.deepEqual(result, { changed: false, articles: 1 });
  assert.equal(bucket.puts.length, 0);
});

test("sync preserves a validated rollback before conditionally replacing news", async () => {
  const previous = JSON.stringify({
    articles: [{
      title: "Legacy",
      date: "August 1, 2026",
      summary: "Previous valid news.",
      featuredImage: "",
      imageAlt: "",
      externalLink: "",
      localizations: {},
    }],
  });
  const bucket = new FakeBucket({ "data/news.json": previous });
  const env = baseEnv(bucket);
  const result = await syncForumNews(env, readConfig(env), discourseFetch());
  assert.equal(result.changed, true);
  assert.deepEqual(bucket.puts.map((entry) => entry.key), ["data/news.previous.json", "data/news.json"]);
  assert.equal(bucket.puts[0].value, previous);
  assert.equal(bucket.puts[1].options.onlyIf.etagMatches, "etag-1");
});

test("sync refuses to overwrite an invalid current feed", async () => {
  const bucket = new FakeBucket({ "data/news.json": "not JSON" });
  const env = baseEnv(bucket);
  await assert.rejects(
    syncForumNews(env, readConfig(env), discourseFetch()),
    /refusing to overwrite/,
  );
  assert.equal(bucket.puts.length, 0);
});

test("sync detects a concurrent change through the R2 precondition", async () => {
  const valid = JSON.stringify({
    articles: [{
      title: "Legacy",
      date: "August 1, 2026",
      summary: "Previous valid news.",
      featuredImage: "",
      imageAlt: "",
      externalLink: "",
      localizations: {},
    }],
  });
  const bucket = new FakeBucket({ "data/news.json": valid });
  const originalPut = bucket.put.bind(bucket);
  bucket.put = async (key, value, options) => {
    if (key === "data/news.json") bucket.set(key, valid.replace("Legacy", "Concurrent"));
    return originalPut(key, value, options);
  };
  const env = baseEnv(bucket);
  await assert.rejects(
    syncForumNews(env, readConfig(env), discourseFetch()),
    /changed concurrently/,
  );
});

test("webhook rejects invalid signatures without fetching or writing", async () => {
  const bucket = new FakeBucket();
  const env = baseEnv(bucket);
  const request = new Request("https://worker.example/webhooks/discourse", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Discourse-Event-Type": "topic",
      "X-Discourse-Event-Signature": "sha256=" + "0".repeat(64),
    },
    body: "{}",
  });
  const response = await worker.fetch(request, env);
  assert.equal(response.status, 401);
  assert.equal(bucket.puts.length, 0);
});

test("signed ping validates the endpoint without rebuilding news", async () => {
  const body = new TextEncoder().encode('{"ping":"ok"}');
  const request = await webhookRequest(body, "ping");
  const bucket = new FakeBucket();
  const response = await worker.fetch(request, baseEnv(bucket));
  assert.equal(response.status, 204);
  assert.equal(bucket.puts.length, 0);
});

test("signed topic webhook rebuilds the source-of-truth feed", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = discourseFetch();
  try {
    const body = new TextEncoder().encode('{"topic":{"id":26}}');
    const request = await webhookRequest(body, "topic");
    const bucket = new FakeBucket();
    const response = await worker.fetch(request, baseEnv(bucket));
    assert.equal(response.status, 204);
    assert.deepEqual(bucket.puts.map((entry) => entry.key), ["data/news.json"]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("daily scheduled handler reconciles without a webhook secret", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = discourseFetch();
  try {
    const bucket = new FakeBucket();
    const env = baseEnv(bucket);
    delete env.DISCOURSE_WEBHOOK_SECRET;
    await worker.scheduled({}, env);
    assert.deepEqual(bucket.puts.map((entry) => entry.key), ["data/news.json"]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("missing R2 binding fails without falling back to credentials", async () => {
  await assert.rejects(
    syncForumNews({}, null, discourseFetch()),
    (error) => error instanceof FeedError && /UPDATES_BUCKET/.test(error.message),
  );
});

async function sign(body, secret) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, body));
  return `sha256=${Array.from(signature, (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

async function webhookRequest(body, eventType) {
  return new Request("https://worker.example/webhooks/discourse", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Discourse-Event-Type": eventType,
      "X-Discourse-Event-Signature": await sign(body, SECRET),
    },
    body,
  });
}
