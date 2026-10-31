# Hindsight verdict proxy

A single-file Cloudflare Worker that holds one Groq key so a build you hand to
friends needs no API key. It speaks the same OpenAI-compatible routes the app
already uses, so the phone does not know the difference.

## Why not just put the key in the app?

Because anyone can pull it out of an APK with `strings`, and Groq's free tier is
**1,000 requests and 200,000 tokens per day per organization** — one leaked key
and everyone's verdicts start failing. With a proxy you can rotate the key,
change models, and cap the day without shipping a new APK. The proxy URL itself
is still public in the APK, which is what the token cap and daily counter are
for. For a handful of friends this is the right amount of protection; for a real
launch, put per-install tokens in front of it.

## Deploy (about five minutes)

1. Install Wrangler and log in:

   ```bash
   npm install -g wrangler
   wrangler login
   ```

2. From this folder, create the worker and store the key as a secret:

   ```bash
   wrangler secret put GROQ_API_KEY
   # paste gsk_... when prompted
   wrangler deploy
   ```

3. Optional, recommended — a per-day counter so the quota cannot be drained:

   ```bash
   wrangler kv namespace create LIMIT
   # paste the printed id into wrangler.toml, uncomment [[kv_namespaces]]
   wrangler deploy
   ```

4. Check it:

   ```bash
   curl https://hindsight-verdict.<your-subdomain>.workers.dev/v1/models
   ```

   It should list `openai/gpt-oss-120b` and `openai/gpt-oss-20b`.

## Point the app at it

```bash
flutter build apk --release \
  --dart-define=HINDSIGHT_PROXY=https://hindsight-verdict.<your-subdomain>.workers.dev/v1
```

That build shows a **Hindsight** option in Settings → Verdict writer that needs
no key, and a fresh install starts on it. A build without the define is
unchanged: bring your own key, or the offline verdict.

## Limits it enforces

- Models pinned to `openai/gpt-oss-120b` / `openai/gpt-oss-20b`; anything else is
  rewritten, so nobody can call an expensive model on your key.
- `max_tokens` clamped to 900 per request.
- Request bodies over 24 KB rejected.
- With the KV binding: 300 requests per UTC day across everyone, then a 429 that
  the app shows as a normal error and falls back from.

At ~1,500 tokens per verdict, the free tier's 200k tokens/day is roughly 100–130
verdicts, so the cap is a backstop rather than the usual ceiling.
