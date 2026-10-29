import { Injectable, Logger } from '@nestjs/common';
import { createReadStream } from 'node:fs';
import { access, mkdir, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, join, normalize, resolve, sep } from 'node:path';
import { Readable } from 'node:stream';
import { AppConfig } from '../../common/config/configuration';
import { AppException } from '../../common/errors/app-exception';
import type {
  StorageRange,
  StorageReadResult,
  StorageService,
  StoredObject,
} from './storage.interface';

/**
 * Filesystem-backed storage, so `npm run start:dev` works with no object store.
 *
 * It cannot issue signed URLs, so `MediaService` falls back to serving bytes
 * through the authenticated `/media/:id/content` endpoint.
 */
@Injectable()
export class LocalStorageService implements StorageService {
  readonly driver = 'local' as const;
  readonly bucket = 'local';

  private readonly logger = new Logger(LocalStorageService.name);
  private readonly root: string;

  constructor(config: AppConfig) {
    this.root = resolve(config.storageLocalDir);
  }

  async put(key: string, body: Buffer, _contentType: string): Promise<StoredObject> {
    const path = this.resolveKey(key);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, body);
    return { key, bucket: this.bucket, byteSize: body.byteLength };
  }

  async read(key: string, range?: StorageRange): Promise<StorageReadResult> {
    const path = this.resolveKey(key);
    let size: number;
    try {
      const info = await stat(path);
      size = info.size;
    } catch {
      throw AppException.notFound('Media object', key);
    }

    if (!range) {
      return {
        stream: createReadStream(path),
        contentType: 'application/octet-stream',
        byteSize: size,
      };
    }

    const start = Math.max(0, range.start);
    const end = Math.min(range.end ?? size - 1, size - 1);
    if (start > end) {
      throw AppException.badRequest('Requested range is not satisfiable.', 'range');
    }
    return {
      stream: createReadStream(path, { start, end }),
      contentType: 'application/octet-stream',
      byteSize: end - start + 1,
      contentRange: `bytes ${start}-${end}/${size}`,
    };
  }

  async delete(key: string): Promise<void> {
    await rm(this.resolveKey(key), { force: true });
  }

  async exists(key: string): Promise<boolean> {
    try {
      await access(this.resolveKey(key));
      return true;
    } catch {
      return false;
    }
  }

  signedUrl(): Promise<string | undefined> {
    // No signing on a local filesystem; callers use the proxied endpoint.
    return Promise.resolve(undefined);
  }

  async healthCheck(): Promise<void> {
    await mkdir(this.root, { recursive: true });
    const probe = join(this.root, '.healthcheck');
    await writeFile(probe, 'ok');
    await rm(probe, { force: true });
  }

  /**
   * Resolves a storage key under the root, refusing anything that escapes it.
   * Keys are server-generated, but a traversal here would be arbitrary file
   * read/write, so it is checked rather than assumed.
   */
  private resolveKey(key: string): string {
    const cleaned = normalize(key).replace(/^([/\\])+/, '');
    const full = resolve(this.root, cleaned);
    if (full !== this.root && !full.startsWith(this.root + sep)) {
      this.logger.error(`Rejected storage key escaping the root: ${key}`);
      throw AppException.badRequest('Invalid storage key.');
    }
    return full;
  }
}

/** Narrow helper kept for symmetry with the S3 driver's stream typing. */
export function toReadable(buffer: Buffer): Readable {
  return Readable.from(buffer);
}
