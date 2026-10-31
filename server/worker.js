/**
 * Hindsight verdict proxy.
 *
 * Holds one Groq key server-side so a build handed to non-technical friends can
 * write verdicts without anyone pasting an API key. The phone talks to this
 * worker exactly like an OpenAI-compatible server (`/v1/models` and
 * `/v1/chat/completions`), and this worker adds the real key.
 *
 * Deploy (see server/README.md):
 *   wrangler secret put GROQ_API_KEY
 *   wrangler deploy
 *
 * What it deliberately does not do: log prompt or verdict text, accept a model
 * outside the two gpt-oss ids, or let a client raise the token ceiling above
 * MAX_TOKENS. Those caps are the difference between "free tier" and "someone
 * found your URL and spent your quota".
 */

const GROQ = 'https://api.groq.com/openai/v1';

/** The only models a shared key may call. Pinned, not taken from the client. */
const MODELS = ['openai/gpt-oss-120b', 'openai/gpt-oss-20b'];

/** A verdict needs ~300 output tokens; this leaves room without draining TPD. */
const MAX_TOKENS = 900;

/** Requests per UTC day across everyone, when a KV binding is configured. */
const DAILY_CAP = 300;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }
    if (!env.GROQ_API_KEY) {
      return fail('This proxy has no Groq key configured.', 500);
    }

    const { pathname } = new URL(request.url);

    // The app's model picker asks for this; answer without touching Groq.
    if (pathname === '/v1/models' && request.method === 'GET') {
      return json({
        data: MODELS.map((id) => ({
          id,
          object: 'model',
          owned_by: 'hindsight',
        })),
      });
    }

    if (pathname === '/v1/chat/completions' && request.method === 'POST') {
      const raw = await request.text();
      if (raw.length > 24000) return fail('Request too large.', 413);

      let body;
      try {
        body = JSON.parse(raw);
      } catch (_) {
        return fail('Bad JSON.', 400);
      }

      if (await overDailyCap(env)) {
        return fail(
          'The shared key has hit its daily cap. Add your own key in Settings, ' +
            'or use tomorrow, or the offline verdict still works.',
          429,
        );
      }

      body.model = MODELS.includes(body.model) ? body.model : MODELS[0];
      for (const field of ['max_tokens', 'max_completion_tokens']) {
        if (typeof body[field] === 'number') {
          body[field] = Math.min(body[field], MAX_TOKENS);
        }
      }

      return passthrough(
        await groq('/chat/completions', {
          method: 'POST',
          body: JSON.stringify(body),
        }, env),
      );
    }

    return fail('Not found.', 404);
  },
};

function groq(path, init, env) {
  return fetch(`${GROQ}${path}`, {
    ...init,
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${env.GROQ_API_KEY}`,
    },
  });
}

async function overDailyCap(env) {
  // Optional: only enforced when a KV namespace is bound as LIMIT.
  if (!env.LIMIT) return false;
  const key = `n:${new Date().toISOString().slice(0, 10)}`;
  const used = Number(await env.LIMIT.get(key)) || 0;
  if (used >= DAILY_CAP) return true;
  await env.LIMIT.put(key, String(used + 1), { expirationTtl: 172800 });
  return false;
}

function passthrough(res) {
  return new Response(res.body, {
    status: res.status,
    headers: {
      ...CORS,
      'content-type': res.headers.get('content-type') ?? 'application/json',
    },
  });
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, 'content-type': 'application/json' },
  });
}

function fail(message, status) {
  return json({ error: { message, type: 'hindsight_proxy' } }, status);
}
