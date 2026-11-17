// Always render per request: this page depends on who is signed in.
export const dynamic = "force-dynamic";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isSupabaseConfigured } from "@/lib/env";
import { normalizePlan } from "@/lib/plans";

export default async function Dashboard() {
  if (!isSupabaseConfigured) redirect("/login");

  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  if (!claims?.claims) redirect("/login?next=/dashboard");

  const { data: profile } = await supabase
    .from("profiles")
    .select("email, plan")
    .eq("id", claims.claims.sub)
    .single();

  return (
    <section className="space-y-6">
      <div className="rounded-xl border border-border bg-surface p-5">
        <p className="text-sm text-muted">Signed in as</p>
        <p className="mt-1 break-all font-medium">{profile?.email ?? claims.claims.email}</p>
        <p className="mt-3 text-sm text-muted">
          Plan: <span className="text-foreground">{normalizePlan(profile?.plan)}</span>
        </p>
      </div>
      <p className="text-muted">Wallet connect and your trade log arrive in phase 2.</p>
      <form action="/auth/signout" method="post">
        <button className="rounded-lg border border-border px-4 py-2 text-sm">Sign out</button>
      </form>
    </section>
  );
}
