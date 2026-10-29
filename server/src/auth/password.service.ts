import { Injectable, Logger } from '@nestjs/common';
import * as argon2 from 'argon2';

/**
 * Argon2id password hashing at the OWASP baseline.
 *
 * Parameters live here rather than at call sites so they can be raised later:
 * `verify()` reports when a stored hash used weaker settings, and the caller
 * transparently rehashes on the next successful login.
 */
@Injectable()
export class PasswordService {
  private readonly logger = new Logger(PasswordService.name);

  private readonly options: argon2.Options = {
    type: argon2.argon2id,
    memoryCost: 19_456, // 19 MiB
    timeCost: 2,
    parallelism: 1,
  };

  /**
   * A dummy hash verified when no user matches, so a login attempt against an
   * unknown email costs the same time as one against a real account. Without
   * it, response timing enumerates which emails have accounts.
   */
  private dummyHash?: string;

  async hash(plain: string): Promise<string> {
    return argon2.hash(plain, this.options);
  }

  async verify(hash: string, plain: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, plain);
    } catch (error) {
      // A malformed stored hash is a data problem, not a wrong password.
      this.logger.warn(`Password verification failed: ${messageOf(error)}`);
      return false;
    }
  }

  /** True when `hash` was produced with weaker parameters than current policy. */
  needsRehash(hash: string): boolean {
    try {
      return argon2.needsRehash(hash, this.options);
    } catch {
      return true;
    }
  }

  /** Burns roughly one hash worth of time. Return value is meaningless. */
  async wasteTime(plain: string): Promise<void> {
    this.dummyHash ??= await this.hash('unused-placeholder-credential');
    await this.verify(this.dummyHash, plain);
  }
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
