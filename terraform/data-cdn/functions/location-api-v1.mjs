const LOCATION_PATH = "/api/v1/location";

const RESPONSE_HEADERS = {
  "access-control-allow-methods": "GET, HEAD, OPTIONS",
  "access-control-allow-origin": "*",
  "cache-control": "no-store",
  "content-type": "application/json; charset=utf-8",
  "x-content-type-options": "nosniff",
};

function response(statusCode, body = "", additionalHeaders = {}) {
  return {
    statusCode,
    headers: { ...RESPONSE_HEADERS, ...additionalHeaders },
    body,
    isBase64Encoded: false,
  };
}

function headerValue(headers, name) {
  if (!headers || typeof headers !== "object") return null;

  const value = headers[name] ?? headers[name.toLowerCase()];
  return typeof value === "string" && value.length > 0 ? value : null;
}

function decodedHeader(headers, name, maxLength = 128) {
  const rawValue = headerValue(headers, name);
  if (rawValue === null || rawValue.length > maxLength * 3) return null;

  try {
    const value = decodeURIComponent(rawValue).trim();
    if (value.length === 0 || value.length > maxLength || /[\u0000-\u001f\u007f]/u.test(value)) {
      return null;
    }
    return value;
  } catch {
    return null;
  }
}

function coordinateHeader(headers, name, minimum, maximum) {
  const rawValue = headerValue(headers, name);
  if (rawValue === null || !/^-?(?:\d+(?:\.\d+)?|\.\d+)$/u.test(rawValue)) return null;

  const value = Number(rawValue);
  return Number.isFinite(value) && value >= minimum && value <= maximum ? value : null;
}

function codeHeader(headers, name, pattern) {
  const value = decodedHeader(headers, name, 8);
  return value !== null && pattern.test(value) ? value : null;
}

function timeZoneHeader(headers) {
  const value = decodedHeader(headers, "cloudfront-viewer-time-zone", 64);
  return value !== null && /^[A-Za-z0-9_+-]+(?:\/[A-Za-z0-9_+-]+)*$/u.test(value)
    ? value
    : null;
}

export function locationFromHeaders(headers) {
  const latitude = coordinateHeader(headers, "cloudfront-viewer-latitude", -90, 90);
  const longitude = coordinateHeader(headers, "cloudfront-viewer-longitude", -180, 180);

  return {
    available: latitude !== null && longitude !== null,
    precision: "ip",
    latitude,
    longitude,
    city: decodedHeader(headers, "cloudfront-viewer-city"),
    region: decodedHeader(headers, "cloudfront-viewer-country-region-name"),
    countryName: decodedHeader(headers, "cloudfront-viewer-country-name"),
    countryCode: codeHeader(headers, "cloudfront-viewer-country", /^[A-Za-z]{2}$/u)?.toUpperCase() ?? null,
    postalCode: decodedHeader(headers, "cloudfront-viewer-postal-code", 32),
    timezone: timeZoneHeader(headers),
  };
}

export async function handler(event) {
  const method = event?.requestContext?.http?.method ?? event?.httpMethod ?? "";
  const path = event?.rawPath ?? event?.requestContext?.http?.path ?? "";

  if (path !== LOCATION_PATH) {
    return response(404, JSON.stringify({ error: "not_found" }));
  }

  if (method === "OPTIONS") {
    return response(204, "", { "access-control-max-age": "86400" });
  }

  if (method !== "GET" && method !== "HEAD") {
    return response(405, JSON.stringify({ error: "method_not_allowed" }), {
      allow: "GET, HEAD, OPTIONS",
    });
  }

  const body = JSON.stringify(locationFromHeaders(event?.headers));
  return response(200, method === "HEAD" ? "" : body);
}
