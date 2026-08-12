import { revalidateTag } from "next/cache";
import { NextResponse } from "next/server";

export async function POST(request: Request) {
  const secret = process.env.PUBLICATION_REVALIDATE_SECRET;

  if (!secret) {
    return NextResponse.json({ error: "Revalidation is not configured" }, { status: 503 });
  }

  if (request.headers.get("authorization") !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  revalidateTag("publication", { expire: 0 });

  return NextResponse.json({ revalidated: true });
}
