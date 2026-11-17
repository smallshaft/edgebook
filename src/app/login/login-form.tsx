"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function LoginForm({ next }: { next: string }) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [message, setMessage] = useState("");

  const redirectTo = () =>
    `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`;

  async function sendLink(e: React.FormEvent) {
    e.preventDefault();
    setStatus("sending");
    const { error } = await createClient().auth.signInWithOtp({
      email,
      options: { emailRedirectTo: redirectTo() },
    });
    if (error) {
      setStatus("error");
      setMessage(error.message);
    } else {
      setStatus("sent");
    }
  }

  async function google() {
    const { error } = await createClient().auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: redirectTo() },
    });
    if (error) {
      setStatus("error");
      setMessage(error.message);
    }
  }

  if (status === "sent") {
    return (
      <p className="rounded-lg border border-border bg-surface p-4">
        Check <strong>{email}</strong> for a sign-in link.
      </p>
    );
  }

  return (
    <div className="space-y-4">
      <button
        onClick={google}
        className="w-full rounded-lg border border-border bg-surface px-4 py-3 font-medium"
      >
        Continue with Google
      </button>
      <div className="text-center text-xs text-muted">or</div>
      <form onSubmit={sendLink} className="space-y-3">
        <input
          type="email"
          required
          inputMode="email"
          autoComplete="email"
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full rounded-lg border border-border bg-surface px-4 py-3 text-base outline-none focus:border-accent"
        />
        <button
          type="submit"
          disabled={status === "sending"}
          className="w-full rounded-lg bg-accent px-4 py-3 font-medium text-black disabled:opacity-60"
        >
          {status === "sending" ? "Sending…" : "Email me a sign-in link"}
        </button>
      </form>
      {status === "error" && <p className="text-sm text-danger">{message}</p>}
    </div>
  );
}
