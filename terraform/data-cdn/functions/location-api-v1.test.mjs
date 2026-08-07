import assert from "node:assert/strict";
import test from "node:test";

import { handler, locationFromHeaders } from "./location-api-v1.mjs";

function event(method = "GET", headers = {}, rawPath = "/api/v1/location") {
  return {
    rawPath,
    headers,
    requestContext: { http: { method, path: rawPath } },
  };
}

test("decodes and validates a complete CloudFront location", () => {
  assert.deepEqual(
    locationFromHeaders({
      "cloudfront-viewer-latitude": "52.3676",
      "cloudfront-viewer-longitude": "4.9041",
      "cloudfront-viewer-city": "Amsterdam",
      "cloudfront-viewer-country-region-name": "North%20Holland",
      "cloudfront-viewer-country-name": "Netherlands",
      "cloudfront-viewer-country": "nl",
      "cloudfront-viewer-postal-code": "1012",
      "cloudfront-viewer-time-zone": "Europe%2FAmsterdam",
      "cloudfront-viewer-address": "203.0.113.4%3A53124",
    }),
    {
      available: true,
      precision: "ip",
      latitude: 52.3676,
      longitude: 4.9041,
      city: "Amsterdam",
      region: "North Holland",
      countryName: "Netherlands",
      countryCode: "NL",
      postalCode: "1012",
      timezone: "Europe/Amsterdam",
    },
  );
});

test("returns a stable null-filled result when AWS omits detailed location headers", () => {
  assert.deepEqual(locationFromHeaders({ "cloudfront-viewer-country": "US" }), {
    available: false,
    precision: "ip",
    latitude: null,
    longitude: null,
    city: null,
    region: null,
    countryName: null,
    countryCode: "US",
    postalCode: null,
    timezone: null,
  });
});

test("rejects malformed and out-of-range header values", () => {
  const location = locationFromHeaders({
    "cloudfront-viewer-latitude": "91",
    "cloudfront-viewer-longitude": "NaN",
    "cloudfront-viewer-city": "%E0%A4%A",
    "cloudfront-viewer-country-region": "TOO-LONG",
    "cloudfront-viewer-country": "USA",
    "cloudfront-viewer-postal-code": "line%0Abreak",
    "cloudfront-viewer-time-zone": "../../etc/passwd",
  });

  assert.equal(location.available, false);
  assert.equal(location.latitude, null);
  assert.equal(location.longitude, null);
  assert.equal(location.city, null);
  assert.equal(location.countryCode, null);
  assert.equal(location.postalCode, null);
  assert.equal(location.timezone, null);
});

test("GET returns JSON, CORS, and no-store without exposing the viewer address", async () => {
  const result = await handler(
    event("GET", {
      "cloudfront-viewer-latitude": "64.1466",
      "cloudfront-viewer-longitude": "-21.9426",
      "cloudfront-viewer-address": "203.0.113.8:43120",
    }),
  );

  assert.equal(result.statusCode, 200);
  assert.equal(result.headers["access-control-allow-origin"], "*");
  assert.equal(result.headers["cache-control"], "no-store");
  assert.equal(JSON.parse(result.body).available, true);
  assert.equal(result.body.includes("203.0.113.8"), false);
});

test("HEAD and OPTIONS return no body", async () => {
  const head = await handler(event("HEAD"));
  const options = await handler(event("OPTIONS"));

  assert.equal(head.statusCode, 200);
  assert.equal(head.body, "");
  assert.equal(options.statusCode, 204);
  assert.equal(options.body, "");
  assert.equal(options.headers["access-control-max-age"], "86400");
});

test("rejects unsupported methods and paths", async () => {
  const post = await handler(event("POST"));
  const wrongPath = await handler(event("GET", {}, "/api/v1/elsewhere"));

  assert.equal(post.statusCode, 405);
  assert.equal(post.headers.allow, "GET, HEAD, OPTIONS");
  assert.deepEqual(JSON.parse(post.body), { error: "method_not_allowed" });
  assert.equal(wrongPath.statusCode, 404);
});
