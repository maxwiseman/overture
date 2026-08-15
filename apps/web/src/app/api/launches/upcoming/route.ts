const cacheDurationSeconds = 60 * 60 * 24;
const pageSize = 25;

export async function GET(request: Request) {
  const requestURL = new URL(request.url);
  const offsetValue = requestURL.searchParams.get("offset");
  const limitValue = requestURL.searchParams.get("limit");
  const offset = offsetValue === null ? 0 : Number(offsetValue);
  const limit = limitValue === null ? pageSize : Number(limitValue);

  if (
    !Number.isSafeInteger(offset) ||
    offset < 0 ||
    !Number.isSafeInteger(limit) ||
    limit < 1 ||
    limit > pageSize
  ) {
    return Response.json(
      { error: "Invalid launch pagination parameters" },
      { status: 400, headers: { "Cache-Control": "no-store" } },
    );
  }

  const upstreamURL = new URL(
    "https://ll.thespacedevs.com/2.3.0/launches/upcoming/",
  );
  upstreamURL.searchParams.set("limit", String(limit));
  upstreamURL.searchParams.set("mode", "detailed");
  upstreamURL.searchParams.set("format", "json");
  if (offset > 0) {
    upstreamURL.searchParams.set("offset", String(offset));
  }

  try {
    const upstreamResponse = await fetch(upstreamURL, {
      headers: { Accept: "application/json" },
    });
    const body = await upstreamResponse.text();

    if (!upstreamResponse.ok) {
      return new Response(body, {
        status: upstreamResponse.status,
        headers: {
          "Cache-Control": "no-store",
          "Content-Type":
            upstreamResponse.headers.get("Content-Type") ?? "application/json",
        },
      });
    }

    return new Response(body, {
      headers: {
        "Cache-Control": "public, max-age=0, must-revalidate",
        "CDN-Cache-Control": `public, s-maxage=${cacheDurationSeconds}`,
        "Content-Type":
          upstreamResponse.headers.get("Content-Type") ?? "application/json",
      },
    });
  } catch (error) {
    console.error("Unable to load upcoming launches", error);
    return Response.json(
      { error: "Launch service unavailable" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }
}
