// Dev-only bridge between the browser build of the app and Clerk.
//
// The production Clerk instance (clerk.auroraflix.cloud) rejects any request
// whose Origin isn't auroraflix.cloud ("origin_invalid"), so the app can't
// reach it from http://localhost:5173. The real app never has this problem:
// a native client sends no Origin header at all. This proxy makes the
// browser build behave like the native one — it forwards each request to
// Clerk with Origin/Referer/cookies stripped, and answers CORS itself.
//
//   node tool/clerk_dev_proxy.mjs          (listens on http://localhost:5174)
//
// The app's debug web build points at it automatically (lib/core/config.dart).
import http from "node:http";

const PORT = Number(process.env.PORT ?? 5174);
const TARGET = process.env.CLERK_FAPI ?? "https://clerk.auroraflix.cloud";
const ALLOWED_ORIGIN = process.env.APP_ORIGIN ?? "http://localhost:5173";

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
    "Access-Control-Allow-Methods": "GET, POST, PATCH, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type, Accept, Accept-Language",
    "Access-Control-Expose-Headers": "Authorization",
    "Access-Control-Max-Age": "600",
  };
}

http
  .createServer(async (req, res) => {
    if (req.method === "OPTIONS") {
      res.writeHead(204, corsHeaders());
      res.end();
      return;
    }

    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    const body = chunks.length ? Buffer.concat(chunks) : undefined;

    const headers = {};
    for (const name of ["authorization", "content-type", "accept", "accept-language"]) {
      if (req.headers[name]) headers[name] = req.headers[name];
    }

    try {
      const upstream = await fetch(TARGET + req.url, { method: req.method, headers, body });
      const responseHeaders = { ...corsHeaders(), "Content-Type": upstream.headers.get("content-type") ?? "application/json" };
      const authorization = upstream.headers.get("authorization");
      if (authorization) responseHeaders.Authorization = authorization;
      res.writeHead(upstream.status, responseHeaders);
      res.end(Buffer.from(await upstream.arrayBuffer()));
      console.log(`${req.method} ${req.url.split("?")[0]} -> ${upstream.status}`);
    } catch (error) {
      res.writeHead(502, corsHeaders());
      res.end(JSON.stringify({ errors: [{ message: "Proxy error", long_message: String(error), code: "proxy_error" }] }));
    }
  })
  .listen(PORT, () => console.log(`Clerk dev proxy: http://localhost:${PORT} -> ${TARGET} (for ${ALLOWED_ORIGIN})`));
