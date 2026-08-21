#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import html
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import tempfile
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urljoin, urlparse
from urllib.request import Request, urlopen


DEFAULT_FORUM_BASE_URL = "https://forums.pokeaether.com"
DEFAULT_CATEGORY_ID = 17
DEFAULT_MAX_ARTICLES = 5
DEFAULT_SUMMARY_LENGTH = 180
MAX_RESPONSE_BYTES = 2 * 1024 * 1024
MAX_FETCH_ATTEMPTS = 3
USER_AGENT = "PokeAether-Forum-News-Sync/1.0"
MONTH_NAMES = (
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
)


class FeedError(RuntimeError):
    pass


class _PlainTextParser(HTMLParser):
    BLOCK_TAGS = {
        "address",
        "article",
        "aside",
        "blockquote",
        "br",
        "div",
        "figcaption",
        "figure",
        "footer",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "header",
        "li",
        "main",
        "nav",
        "ol",
        "p",
        "section",
        "table",
        "td",
        "th",
        "tr",
        "ul",
    }

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, _attrs: list[tuple[str, str | None]]) -> None:
        if tag in self.BLOCK_TAGS:
            self.parts.append(" ")

    def handle_endtag(self, tag: str) -> None:
        if tag in self.BLOCK_TAGS:
            self.parts.append(" ")

    def handle_data(self, data: str) -> None:
        self.parts.append(data)

    def text(self) -> str:
        return "".join(self.parts)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build the launcher/login news feed from a public Discourse category."
    )
    parser.add_argument("--forum-base-url", default=DEFAULT_FORUM_BASE_URL)
    parser.add_argument("--category-id", type=int, default=DEFAULT_CATEGORY_ID)
    parser.add_argument("--max-articles", type=int, default=DEFAULT_MAX_ARTICLES)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("builds/news/news.json"),
        help="Generated compatibility feed path.",
    )
    parser.add_argument(
        "--validate-feed",
        type=Path,
        help="Validate an existing compatibility feed instead of fetching Discourse.",
    )
    args = parser.parse_args()

    try:
        if args.validate_feed is not None:
            feed = _read_json_file(args.validate_feed)
            validate_feed(feed)
            print(f"Validated existing news feed: {args.validate_feed}")
            return

        if not 1 <= args.max_articles <= 20:
            raise FeedError("max-articles must be between 1 and 20")

        category_payload, topics_payload = fetch_category_payloads(
            args.forum_base_url,
            args.category_id,
        )
        feed = build_feed(
            category_payload,
            topics_payload,
            forum_base_url=args.forum_base_url,
            category_id=args.category_id,
            max_articles=args.max_articles,
        )
        write_feed(args.output, feed)
        print(f"Generated {len(feed['articles'])} forum news article(s): {args.output}")
    except (FeedError, OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Forum news sync failed: {error}") from error


def fetch_category_payloads(base_url: str, category_id: int) -> tuple[dict[str, Any], dict[str, Any]]:
    normalized_base_url = _validate_forum_base_url(base_url)
    category_url = urljoin(normalized_base_url + "/", f"c/{category_id}/show.json")
    topics_url = urljoin(
        normalized_base_url + "/",
        f"c/{category_id}/l/latest.json?order=created",
    )
    return _fetch_json(category_url), _fetch_json(topics_url)


def build_feed(
    category_payload: dict[str, Any],
    topics_payload: dict[str, Any],
    *,
    forum_base_url: str = DEFAULT_FORUM_BASE_URL,
    category_id: int = DEFAULT_CATEGORY_ID,
    max_articles: int = DEFAULT_MAX_ARTICLES,
    summary_length: int = DEFAULT_SUMMARY_LENGTH,
) -> dict[str, list[dict[str, Any]]]:
    normalized_base_url = _validate_forum_base_url(forum_base_url)
    category = category_payload.get("category")
    if not isinstance(category, dict):
        raise FeedError("Discourse category response has no category object")
    if category.get("id") != category_id:
        raise FeedError(
            f"Discourse category response was for ID {category.get('id')!r}, expected {category_id}"
        )
    if category.get("read_restricted") is True:
        raise FeedError("Official announcements category is no longer public")

    category_topic_id = _category_topic_id(category.get("topic_url"))
    topic_list = topics_payload.get("topic_list")
    topics = topic_list.get("topics") if isinstance(topic_list, dict) else None
    if not isinstance(topics, list):
        raise FeedError("Discourse topics response has no topic_list.topics array")

    candidates: list[tuple[dt.datetime, int, dict[str, Any]]] = []
    for topic in topics:
        if not isinstance(topic, dict):
            continue
        topic_id = topic.get("id")
        if not isinstance(topic_id, int) or topic_id <= 0 or topic_id == category_topic_id:
            continue
        if topic.get("category_id") != category_id:
            continue
        if topic.get("visible") is not True or topic.get("archetype") != "regular":
            continue

        title = clean_text(topic.get("title"))
        summary = truncate_text(clean_text(topic.get("excerpt")), summary_length)
        if not title or not summary:
            continue

        created_at = _parse_discourse_datetime(topic.get("created_at"), topic_id)
        candidates.append((created_at, topic_id, topic))

    candidates.sort(key=lambda entry: (entry[0], entry[1]), reverse=True)
    articles = [
        _build_article(topic, created_at, normalized_base_url, summary_length)
        for created_at, _topic_id, topic in candidates[:max_articles]
    ]
    feed = {"articles": articles}
    validate_feed(
        feed,
        require_forum_links=True,
        forum_hostname=urlparse(normalized_base_url).hostname,
    )
    return feed


def validate_feed(
    feed: Any,
    *,
    require_forum_links: bool = False,
    forum_hostname: str | None = None,
) -> None:
    if not isinstance(feed, dict):
        raise FeedError("news feed must be a JSON object")
    articles = feed.get("articles")
    if not isinstance(articles, list) or not 1 <= len(articles) <= 20:
        raise FeedError("news feed must contain between 1 and 20 articles")

    required_strings = ("title", "date", "summary", "featuredImage", "imageAlt", "externalLink")
    for index, article in enumerate(articles):
        if not isinstance(article, dict):
            raise FeedError(f"article {index} must be an object")
        for field in required_strings:
            if not isinstance(article.get(field), str):
                raise FeedError(f"article {index}.{field} must be a string")
        if not article["title"].strip() or not article["date"].strip() or not article["summary"].strip():
            raise FeedError(f"article {index} has an empty required display field")
        if not isinstance(article.get("localizations", {}), dict):
            raise FeedError(f"article {index}.localizations must be an object")
        if require_forum_links:
            _validate_generated_link(
                article["externalLink"],
                "externalLink",
                forum_hostname or urlparse(DEFAULT_FORUM_BASE_URL).hostname,
            )
            if article["featuredImage"]:
                _validate_https_url(article["featuredImage"], "featuredImage")


def clean_text(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    parser = _PlainTextParser()
    parser.feed(html.unescape(value))
    parser.close()
    return re.sub(r"\s+", " ", parser.text()).strip()


def truncate_text(value: str, max_length: int) -> str:
    if max_length < 2:
        raise FeedError("summary length must be at least 2")
    if len(value) <= max_length:
        return value
    content_length = max_length - 1
    shortened = value[:content_length].rstrip()
    cut_through_word = content_length < len(value) and not value[content_length].isspace()
    if cut_through_word and " " in shortened:
        shortened = shortened.rsplit(" ", 1)[0].rstrip()
    if shortened.endswith((".", "!", "?", "…")):
        return shortened
    return shortened + "…"


def write_feed(output_path: Path, feed: dict[str, Any]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    rendered = json.dumps(feed, ensure_ascii=False, indent=2) + "\n"
    with tempfile.NamedTemporaryFile(
        "w",
        encoding="utf-8",
        dir=output_path.parent,
        prefix=f".{output_path.name}.",
        delete=False,
    ) as temporary_file:
        temporary_file.write(rendered)
        temporary_path = Path(temporary_file.name)
    os.replace(temporary_path, output_path)


def _build_article(
    topic: dict[str, Any],
    created_at: dt.datetime,
    base_url: str,
    summary_length: int,
) -> dict[str, Any]:
    topic_id = int(topic["id"])
    slug = str(topic.get("slug", "")).strip()
    if not re.fullmatch(r"[a-z0-9-]+", slug):
        slug = "topic"
    topic_url = urljoin(base_url + "/", f"t/{quote(slug, safe='-')}/{topic_id}")

    image_url = str(topic.get("image_url") or "").strip()
    if image_url:
        try:
            _validate_https_url(image_url, "image_url")
        except FeedError:
            image_url = ""

    title = clean_text(topic["title"])
    return {
        "title": title,
        "date": f"{MONTH_NAMES[created_at.month - 1]} {created_at.day}, {created_at.year}",
        "summary": truncate_text(clean_text(topic["excerpt"]), summary_length),
        "featuredImage": image_url,
        "imageAlt": title if image_url else "",
        "externalLink": topic_url,
        "localizations": {},
    }


def _fetch_json(url: str) -> dict[str, Any]:
    request = Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
    )
    for attempt in range(1, MAX_FETCH_ATTEMPTS + 1):
        try:
            with urlopen(request, timeout=15) as response:
                body = response.read(MAX_RESPONSE_BYTES + 1)
                if len(body) > MAX_RESPONSE_BYTES:
                    raise FeedError(f"Discourse response exceeded {MAX_RESPONSE_BYTES} bytes")
                payload = json.loads(body.decode("utf-8"))
                if not isinstance(payload, dict):
                    raise FeedError("Discourse returned a JSON value that is not an object")
                return payload
        except HTTPError as error:
            if error.code < 500 or attempt == MAX_FETCH_ATTEMPTS:
                raise FeedError(f"Discourse request returned HTTP {error.code}: {url}") from error
        except (URLError, TimeoutError, OSError) as error:
            if attempt == MAX_FETCH_ATTEMPTS:
                raise FeedError(f"Discourse request failed after {attempt} attempts: {url}") from error
        time.sleep(2 ** (attempt - 1))
    raise FeedError(f"Discourse request failed: {url}")


def _read_json_file(path: Path) -> Any:
    if not path.is_file():
        raise FeedError(f"feed file does not exist: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _validate_forum_base_url(value: str) -> str:
    parsed = urlparse(value.strip())
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise FeedError("forum base URL must be an HTTPS origin without credentials")
    if parsed.query or parsed.fragment:
        raise FeedError("forum base URL must not contain a query or fragment")
    return f"https://{parsed.netloc}{parsed.path}".rstrip("/")


def _validate_generated_link(value: str, field: str, forum_hostname: str | None) -> None:
    parsed = _validate_https_url(value, field)
    if parsed.hostname != forum_hostname:
        raise FeedError(f"{field} must point to {forum_hostname}")
    if not re.fullmatch(r"/t/[a-z0-9-]+/\d+", parsed.path):
        raise FeedError(f"{field} is not a canonical Discourse topic URL")


def _validate_https_url(value: str, field: str):
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise FeedError(f"{field} must be an HTTPS URL without credentials")
    return parsed


def _category_topic_id(topic_url: Any) -> int:
    if not isinstance(topic_url, str):
        raise FeedError("Discourse category response has no topic_url")
    match = re.search(r"/(\d+)(?:/)?$", topic_url)
    if not match:
        raise FeedError("Discourse category topic_url has an unexpected format")
    return int(match.group(1))


def _parse_discourse_datetime(value: Any, topic_id: int) -> dt.datetime:
    if not isinstance(value, str):
        raise FeedError(f"topic {topic_id} has no created_at timestamp")
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise FeedError(f"topic {topic_id} has an invalid created_at timestamp") from error
    if parsed.tzinfo is None:
        raise FeedError(f"topic {topic_id} created_at timestamp has no timezone")
    return parsed.astimezone(dt.UTC)


if __name__ == "__main__":
    main()
