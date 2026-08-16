import { auth } from "@overture/auth";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { connection } from "next/server";
import { Suspense } from "react";

import { getCurrentEdition } from "@/lib/publication";

import Dashboard from "./dashboard";

export const instant = true;

export default function DashboardPage() {
  return (
    <main className="mx-auto min-h-[calc(100svh-88px)] max-w-[1000px] px-[42px] py-[90px] text-foreground">
      <p className="mb-3 text-[0.72rem] font-[650] tracking-[0.17em] text-publication-accent uppercase">
        Your reading list
      </p>
      <h1 className="m-0 [font-family:Georgia,'Times_New_Roman',serif] text-[clamp(3.8rem,7vw,6rem)] font-normal tracking-[-0.05em]">
        Saved stories
      </h1>
      <Suspense fallback={<DashboardFallback />}>
        <AuthenticatedDashboard />
      </Suspense>
    </main>
  );
}

async function AuthenticatedDashboard() {
  await connection();

  const requestHeaders = headers();
  const edition = getCurrentEdition().catch(() => null);
  const session = auth.api.getSession({ headers: await requestHeaders });
  const [resolvedSession, resolvedEdition] = await Promise.all([session, edition]);

  if (!resolvedSession?.user) {
    redirect("/login");
  }

  return (
    <>
      <p className="mt-[22px] text-publication-muted">Welcome back, {resolvedSession.user.name}.</p>
      <Dashboard stories={resolvedEdition?.stories ?? []} />
    </>
  );
}

function DashboardFallback() {
  return (
    <div className="mt-[22px] animate-pulse border-publication-border border-t pt-[54px]" aria-hidden="true">
      <div className="h-4 w-44 bg-publication-border" />
      <div className="mt-8 h-10 w-full max-w-[520px] bg-publication-placeholder" />
    </div>
  );
}
