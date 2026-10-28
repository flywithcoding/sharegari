/**
 * Supabase Edge Function: barikoi-search
 *
 * Acts as a server-side proxy for the Barikoi autocomplete API so that
 * web clients (Flutter Web) are not blocked by CORS.
 *
 * The Barikoi API key is stored in the Edge Function's environment
 * (Supabase Dashboard → Edge Functions → Secrets → BARIKOI_API_KEY).
 * It is never exposed to the browser.
 *
 * Request:  GET /functions/v1/barikoi-search?q=<query>
 * Response: The raw Barikoi JSON, e.g.
 *   {"places":[{"id":null,"longitude":"90.38","latitude":"23.86",
 *               "address":"Uttara, Dhaka","uCode":"XUSWI61626"}]}
 *
 * Deploy:
 *   npx supabase functions deploy barikoi-search --no-verify-jwt
 *
 * Set secret:
 *   npx supabase secrets set BARIKOI_API_KEY=bkoi_...
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight.
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const apiKey = Deno.env.get("BARIKOI_API_KEY");
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "BARIKOI_API_KEY secret not configured" }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }

  const url = new URL(req.url);
  const q = url.searchParams.get("q")?.trim() ?? "";

  if (!q) {
    return new Response(JSON.stringify({ places: [] }), {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  // Build the upstream Barikoi URL — the endpoint that works from a browser.
  const upstream = new URL("https://barikoi.xyz/v2/api/search/autocomplete/place");
  upstream.searchParams.set("api_key", apiKey);
  upstream.searchParams.set("q", q);

  let barikoiRes: Response;
  try {
    barikoiRes = await fetch(upstream.toString(), {
      headers: { "Accept": "application/json" },
      signal: AbortSignal.timeout(8000),
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: `Barikoi fetch failed: ${err}` }),
      {
        status: 502,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }

  const body = await barikoiRes.text();
  console.log(`[barikoi-search] upstream status=${barikoiRes.status} body=${body}`);

  // Forward the upstream status and body to the client.
  return new Response(body, {
    status: barikoiRes.status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": barikoiRes.headers.get("content-type") ?? "application/json",
    },
  });
});
