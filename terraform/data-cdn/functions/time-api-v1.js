function handler(event) {
  var request = event.request;

  // The cache behavior already scopes this function to this path. Keep the
  // check here so a future association cannot accidentally intercept assets.
  if (request.uri !== "/api/v1/time") {
    return request;
  }

  var headers = {
    "access-control-allow-methods": { value: "GET, HEAD, OPTIONS" },
    "access-control-allow-origin": { value: "*" },
    "cache-control": { value: "no-store" },
    "content-type": { value: "application/json; charset=utf-8" },
    "timing-allow-origin": { value: "*" },
    "x-content-type-options": { value: "nosniff" },
  };

  if (request.method === "OPTIONS") {
    headers["access-control-max-age"] = { value: "86400" };

    return {
      statusCode: 204,
      statusDescription: "No Content",
      headers: headers,
    };
  }

  // CloudFront Functions fixes Date to the function invocation start time.
  var unixTimeMs = Date.now();
  var body = JSON.stringify({
    unixTimeMs: unixTimeMs,
    iso8601: new Date(unixTimeMs).toISOString(),
  });

  return {
    statusCode: 200,
    statusDescription: "OK",
    headers: headers,
    body: request.method === "HEAD" ? "" : body,
  };
}
