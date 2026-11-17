import { isSupabaseConfigured } from "@/lib/env";
import { safeNextPath } from "@/lib/safe-redirect";
import LoginForm from "./login-form";

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const params = await searchParams;
  const next = safeNextPath(typeof params.next === "string" ? params.next : null);
  const error = typeof params.error === "string" ? params.error : null;

  if (!isSupabaseConfigured) {
    return <p className="text-muted">Login isn&apos;t configured yet (Supabase env vars missing).</p>;
  }

  return (
    <section className="mx-auto max-w-sm space-y-6 pt-4">
      <h1 className="text-2xl font-semibold">Sign in</h1>
      {error && <p className="rounded-lg border border-danger/40 p-3 text-sm text-danger">{error}</p>}
      <LoginForm next={next} />
    </section>
  );
}
