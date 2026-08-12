import { auth } from "@overture/auth";
import { z } from "zod";

const requestSchema = z.object({ sourceURL: z.url() });

export async function POST(request: Request) {
  const session = await auth.api.getSession({ headers: request.headers });
  if (!session) return Response.json({ message: "Sign in to save an article." }, { status: 401 });
  if (session.user.role !== "editor") {
    return Response.json({ message: "Only Overture editors can import article drafts." }, { status: 403 });
  }

  const parsed = requestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return Response.json({ message: "A valid article URL is required." }, { status: 400 });

  const payloadURL = (process.env.PAYLOAD_URL ?? "http://localhost:3002").replace(/\/$/, "");
  const ingestSecret = process.env.ARTICLE_INGEST_SECRET;
  if (!ingestSecret) {
    return Response.json({ message: "Article importing is not configured." }, { status: 503 });
  }

  const response = await fetch(`${payloadURL}/api/articles/import`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-overture-ingest-secret": ingestSecret,
    },
    body: JSON.stringify({
      sourceURL: parsed.data.sourceURL,
      requestedBy: session.user.email,
    }),
    cache: "no-store",
  });
  const result = (await response.json().catch(() => ({ message: "Payload returned an invalid response." }))) as {
    message?: string;
    runID?: string;
    status?: string;
  };

  return Response.json(result, { status: response.status });
}
