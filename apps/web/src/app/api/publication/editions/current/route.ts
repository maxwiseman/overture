import { NextResponse } from "next/server";

import { getCurrentEdition } from "@/lib/publication";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const edition = await getCurrentEdition();
    if (!edition) {
      return NextResponse.json({ error: "No published edition found" }, { status: 404 });
    }
    return NextResponse.json(edition);
  } catch (error) {
    console.error("Unable to load the current Payload edition", error);
    return NextResponse.json({ error: "Publication service unavailable" }, { status: 503 });
  }
}
