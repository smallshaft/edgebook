// Google and the email link both land here with a one-time `code`.
// We swap it for a session cookie, then send the user on to where they were going.
import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { safeNextPath } from "@/lib/safe-redirect";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = safeNextPath(url.searchParams.get("next"));

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(new URL(next, url.origin));
  }

  const login = new URL("/login", url.origin);
  login.searchParams.set("error", "That sign-in link didn't work. Try again.");
  return NextResponse.redirect(login);
}
