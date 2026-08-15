import { auth } from "@overture/auth";
import { start } from "workflow/api";
import { z } from "zod";

import { importArticleWorkflow } from "@/cms/workflows/articleGeneration";

const requestSchema = z.object({ sourceURL: z.url() });

export async function POST(request: Request) {
  const session = await auth.api.getSession({ headers: request.headers });
  if (!session) return Response.json({ message: "Sign in to save an article." }, { status: 401 });
  if (session.user.role !== "editor") {
    return Response.json({ message: "Only Overture editors can import article drafts." }, { status: 403 });
  }

  const parsed = requestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return Response.json({ message: "A valid article URL is required." }, { status: 400 });

  const run = await start(importArticleWorkflow, [
    {
      sourceURL: parsed.data.sourceURL,
      requestedBy: session.user.email,
    },
  ]);

  return Response.json({ runID: run.runId, status: "generating" }, { status: 202 });
}
