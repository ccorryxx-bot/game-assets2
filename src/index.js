/**
 * game-assets2 Worker — serves game thumbnails from R2 (bucket: game-assets2)
 * URL pattern: /{provider}/{game_code}.webp  (identical to old static-asset path,
 * so any caller already using this path pattern needs no change)
 */

const CACHE_CONTROL_IMMUTABLE = "public, max-age=31536000, immutable";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let key = url.pathname.replace(/^\/+/, ""); // strip leading slash(es)

    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
          "Access-Control-Max-Age": "86400",
        },
      });
    }

    if (!key || key === "" || url.pathname === "/") {
      return new Response("game-assets2 R2 worker is running", { status: 200 });
    }

    // Only GET/HEAD serve objects
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const object = await env.GAME_ASSETS.get(key);

    if (!object) {
      return new Response("Not Found", {
        status: 404,
        headers: { "Access-Control-Allow-Origin": "*", "Cache-Control": "no-store" },
      });
    }

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set("etag", object.httpEtag);
    headers.set("Cache-Control", CACHE_CONTROL_IMMUTABLE);
    headers.set("Access-Control-Allow-Origin", "*");
    if (!headers.get("content-type")) {
      headers.set("content-type", "image/webp");
    }

    if (request.method === "HEAD") {
      return new Response(null, { headers });
    }

    return new Response(object.body, { headers });
  },
};
