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
    <main className="saved-page">
      <p className="eyebrow">Your reading list</p>
      <h1>Saved stories</h1>
      <p className="saved-page__intro">Welcome back, {session.user.name}.</p>
      <Dashboard stories={edition?.stories ?? []} />
    </main>
  );
}
