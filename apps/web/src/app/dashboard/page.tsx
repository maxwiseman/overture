import { auth } from "@overture/auth";
import { headers } from "next/headers";
import { redirect } from "next/navigation";

import { getCurrentEdition } from "@/lib/publication";

import Dashboard from "./dashboard";

export default async function DashboardPage() {
  const session = await auth.api.getSession({
    headers: await headers(),
  });

  if (!session?.user) {
    redirect("/login");
  }

  const edition = await getCurrentEdition().catch(() => null);

  return (
    <main className="mx-auto min-h-[calc(100svh-88px)] max-w-[1000px] px-[42px] py-[90px] text-[#111]">
      <p className="mb-3 text-[0.72rem] font-[650] tracking-[0.17em] text-[#2d6bd1] uppercase">Your reading list</p>
      <h1 className="m-0 [font-family:Georgia,'Times_New_Roman',serif] text-[clamp(3.8rem,7vw,6rem)] font-normal tracking-[-0.05em]">Saved stories</h1>
      <p className="mt-[22px] text-[#62615c]">Welcome back, {session.user.name}.</p>
      <Dashboard stories={edition?.stories ?? []} />
    </main>
  );
}
