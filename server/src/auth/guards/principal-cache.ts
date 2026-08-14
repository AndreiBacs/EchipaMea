import type { Principal } from '../../common/auth/principal';

/**
 * Very short-lived cache of resolved principals.
 *
 * Every authenticated request would otherwise hit the database twice (session
 * revocation check + subject lookup). The TTL is deliberately small: it bounds
 * how long a disabled account or revoked session keeps working to a few seconds.
 */
export class PrincipalCache {
  private readonly entries = new Map<string, { principal: Principal; expiresAt: number }>();

  constructor(
    private readonly ttlMs = 60_000,
    private readonly maxEntries = 5_000,
  ) {}

  get(key: string): Principal | undefined {
    const hit = this.entries.get(key);
    if (!hit) return undefined;
    if (hit.expiresAt <= Date.now()) {
      this.entries.delete(key);
      return undefined;
    }
    return hit.principal;
  }

  set(key: string, principal: Principal): void {
    if (this.entries.size >= this.maxEntries) this.evictExpired();
    this.entries.set(key, { principal, expiresAt: Date.now() + this.ttlMs });
  }

  invalidate(key: string): void {
    this.entries.delete(key);
  }

  clear(): void {
    this.entries.clear();
  }

  private evictExpired(): void {
    const now = Date.now();
    for (const [key, value] of this.entries) {
      if (value.expiresAt <= now) this.entries.delete(key);
    }
    // Still full of live entries: drop the oldest insertions.
    if (this.entries.size >= this.maxEntries) {
      const excess = this.entries.size - Math.floor(this.maxEntries / 2);
      let removed = 0;
      for (const key of this.entries.keys()) {
        if (removed++ >= excess) break;
        this.entries.delete(key);
      }
    }
  }
}
