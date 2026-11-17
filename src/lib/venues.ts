// Every venue edgebook supports. Add Kalshi here (and in the `venues` table) in v2.
export const VENUES = {
  polymarket: { id: "polymarket", name: "Polymarket", enabled: true },
} as const;

export type Venue = keyof typeof VENUES;

export function isVenue(value: string): value is Venue {
  return value in VENUES;
}
