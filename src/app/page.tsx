import Link from "next/link";

export default function Home() {
  return (
    <section className="space-y-6 pt-8">
      <h1 className="text-3xl font-semibold leading-tight sm:text-4xl">
        How good a trader are you, <span className="text-accent">really</span>?
      </h1>
      <p className="text-muted">
        Paste your Polymarket wallet address and see your P&amp;L, win rate, calibration, and
        how you rank against other traders. Read-only: we only ever ask for a public address.
      </p>
      <Link
        href="/login"
        className="inline-block rounded-lg bg-accent px-5 py-3 font-medium text-black"
      >
        Get started
      </Link>
    </section>
  );
}
