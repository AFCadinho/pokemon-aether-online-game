# Forum news Worker

This Cloudflare Worker turns public topics from Discourse category 17 into the
compatibility feed consumed by the launcher and login screen. A signed
Discourse topic webhook triggers an immediate refresh. A daily Cloudflare Cron
Trigger reconciles missed events; no scheduled GitHub Actions job is involved.

## Safety properties

- Webhooks are accepted only at `POST /webhooks/discourse` with a valid
  `X-Discourse-Event-Signature` HMAC-SHA256 signature.
- The webhook payload is only a trigger. Feed content is fetched from the
  public Discourse category API, so payload fields are never trusted as news.
- When a category response omits a topic excerpt, the Worker fetches that
  public topic's first post and derives the summary from its rendered content.
- Invalid, private, or empty category responses fail without replacing the
  current feed.
- The current R2 object is validated and copied to `data/news.previous.json`
  before a changed feed is published.
- Publication uses an R2 ETag precondition to avoid overwriting a concurrent
  update.

## Local verification

```bash
cd infrastructure/forum-news-worker
npm test
```

Wrangler uses local R2 storage by default. Do not pass `--remote` during local
development unless a production R2 mutation has been explicitly authorized.

## One-time production setup

Production activation is intentionally separate from merging the source. It
requires a Cloudflare API token in the GitHub secret
`CLOUDFLARE_API_TOKEN`, while the existing `R2_ACCOUNT_ID` identifies the
account. The deployment workflow is manual-only, so merging source cannot
silently create or update production infrastructure.

For the controlled activation phase:

1. Generate one random secret of at least 32 characters. Store the same value
   in the GitHub secret `DISCOURSE_WEBHOOK_SECRET` and in an inactive Discourse
   webhook. Do not commit it or place it in workflow input.
2. Manually dispatch `Deploy Forum News Worker`. The workflow rejects a missing
   or short secret and uploads it together with the Worker deployment.
3. Activate the Discourse webhook and use its ping after the Worker URL is
   available.

Configure the Discourse webhook as follows:

- Payload URL: `https://pokeaether-forum-news.<workers-subdomain>.workers.dev/webhooks/discourse`
- Content type: `application/json`
- Secret: exactly the same value as the GitHub secret
- Event: Topic Event
- Triggered category: Official Announcements (ID 17)
- TLS certificate check: enabled

Use Discourse's ping to verify the signed endpoint. Publishing, editing,
moving, recovering, or deleting an announcement then rebuilds the complete
feed from the category. The daily reconciliation runs at 03:17 UTC.
