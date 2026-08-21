#!/usr/bin/env python3

from __future__ import annotations

import unittest

import build_forum_news_feed as news


def category_payload(*, category_id: int = 17, topic_id: int = 23) -> dict:
    return {
        "category": {
            "id": category_id,
            "read_restricted": False,
            "topic_url": f"/t/about-the-category/{topic_id}",
        }
    }


def topic(
    topic_id: int,
    created_at: str,
    *,
    title: str | None = None,
    excerpt: str = "A useful announcement summary.",
    category_id: int = 17,
    visible: bool = True,
    archetype: str = "regular",
    pinned: bool = False,
    image_url: str | None = None,
) -> dict:
    return {
        "id": topic_id,
        "title": title or f"Announcement {topic_id}",
        "slug": f"announcement-{topic_id}",
        "created_at": created_at,
        "excerpt": excerpt,
        "category_id": category_id,
        "visible": visible,
        "archetype": archetype,
        "pinned": pinned,
        "image_url": image_url,
    }


class ForumNewsFeedTests(unittest.TestCase):
    def test_builds_newest_first_and_ignores_pinning(self) -> None:
        payload = {
            "topic_list": {
                "topics": [
                    topic(30, "2026-08-01T12:00:00Z", pinned=True),
                    topic(31, "2026-08-20T12:00:00Z"),
                ]
            }
        }

        feed = news.build_feed(category_payload(), payload)

        self.assertEqual(
            [article["title"] for article in feed["articles"]],
            ["Announcement 31", "Announcement 30"],
        )
        self.assertEqual(feed["articles"][0]["date"], "August 20, 2026")
        self.assertEqual(
            feed["articles"][0]["externalLink"],
            "https://forums.pokeaether.com/t/announcement-31/31",
        )

    def test_excludes_category_topic_hidden_and_wrong_category_topics(self) -> None:
        payload = {
            "topic_list": {
                "topics": [
                    topic(23, "2026-08-21T12:00:00Z"),
                    topic(24, "2026-08-20T12:00:00Z", visible=False),
                    topic(25, "2026-08-19T12:00:00Z", category_id=18),
                    topic(26, "2026-08-18T12:00:00Z", archetype="private_message"),
                    topic(27, "2026-08-17T12:00:00Z"),
                ]
            }
        }

        feed = news.build_feed(category_payload(), payload)

        self.assertEqual([article["title"] for article in feed["articles"]], ["Announcement 27"])

    def test_cleans_entities_markup_and_whitespace(self) -> None:
        payload = {
            "topic_list": {
                "topics": [
                    topic(
                        30,
                        "2026-08-20T12:00:00Z",
                        title="A &amp; B",
                        excerpt="<p>Hello <strong>trainers</strong>!</p>\n<p>More&nbsp;news&hellip;</p>",
                    )
                ]
            }
        }

        article = news.build_feed(category_payload(), payload)["articles"][0]

        self.assertEqual(article["title"], "A & B")
        self.assertEqual(article["summary"], "Hello trainers! More news…")

    def test_limits_articles_and_truncates_at_a_word_boundary(self) -> None:
        payload = {
            "topic_list": {
                "topics": [
                    topic(
                        topic_id,
                        f"2026-08-{topic_id:02d}T12:00:00Z",
                        excerpt="alpha beta gamma delta",
                    )
                    for topic_id in range(1, 8)
                ]
            }
        }

        feed = news.build_feed(
            category_payload(topic_id=99),
            payload,
            max_articles=3,
            summary_length=17,
        )

        self.assertEqual(len(feed["articles"]), 3)
        self.assertEqual(feed["articles"][0]["summary"], "alpha beta gamma…")

    def test_does_not_add_ellipsis_after_a_complete_sentence(self) -> None:
        self.assertEqual(
            news.truncate_text("A complete sentence. More detail follows.", 21),
            "A complete sentence.",
        )

    def test_uses_safe_featured_image_and_discards_unsafe_image(self) -> None:
        payload = {
            "topic_list": {
                "topics": [
                    topic(
                        31,
                        "2026-08-21T12:00:00Z",
                        image_url="https://forums.pokeaether.com/uploads/default/original/image.png",
                    ),
                    topic(30, "2026-08-20T12:00:00Z", image_url="javascript:alert(1)"),
                ]
            }
        }

        articles = news.build_feed(category_payload(), payload)["articles"]

        self.assertEqual(articles[0]["featuredImage"], payload["topic_list"]["topics"][0]["image_url"])
        self.assertEqual(articles[0]["imageAlt"], "Announcement 31")
        self.assertEqual(articles[1]["featuredImage"], "")
        self.assertEqual(articles[1]["imageAlt"], "")

    def test_refuses_wrong_or_private_category(self) -> None:
        payload = {"topic_list": {"topics": [topic(30, "2026-08-20T12:00:00Z")]}}
        with self.assertRaisesRegex(news.FeedError, "expected 17"):
            news.build_feed(category_payload(category_id=18), payload)

        private_category = category_payload()
        private_category["category"]["read_restricted"] = True
        with self.assertRaisesRegex(news.FeedError, "no longer public"):
            news.build_feed(private_category, payload)

    def test_refuses_empty_generated_feed(self) -> None:
        with self.assertRaisesRegex(news.FeedError, "between 1 and 20"):
            news.build_feed(category_payload(), {"topic_list": {"topics": []}})

    def test_validates_legacy_feed_without_requiring_links(self) -> None:
        feed = {
            "articles": [
                {
                    "title": "Legacy",
                    "date": "July 30, 2026",
                    "summary": "Existing compatibility feed.",
                    "featuredImage": "",
                    "imageAlt": "",
                    "externalLink": "",
                    "localizations": {"nl": {"title": "Bestaand"}},
                }
            ]
        }

        news.validate_feed(feed)
        with self.assertRaisesRegex(news.FeedError, "externalLink"):
            news.validate_feed(feed, require_forum_links=True)


if __name__ == "__main__":
    unittest.main()
