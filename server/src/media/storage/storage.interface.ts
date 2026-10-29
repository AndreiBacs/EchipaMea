import type { Readable } from 'node:stream';

/** DI token, since an interface has no runtime identity to inject by. */
export const STORAGE_SERVICE = Symbol('STORAGE_SERVICE');

export interface StoredObject {
  key: string;
  bucket: string;
  byteSize: number;
}

export interface StorageReadResult {
  stream: Readable;
  contentType: string;
  byteSize: number;
  /** Present only when the driver supports ranged reads. */
  contentRange?: string;
}

export interface StorageRange {
  start: number;
  end?: number;
}

export interface StorageService {
  /** Storage backend name, surfaced in health output and media rows. */
  readonly driver: 'local' | 's3';
  /** Logical bucket. The local driver reports a synthetic name. */
  readonly bucket: string;

  put(key: string, body: Buffer, contentType: string): Promise<StoredObject>;

  read(key: string, range?: StorageRange): Promise<StorageReadResult>;

  delete(key: string): Promise<void>;

  exists(key: string): Promise<boolean>;

  /**
   * Time-limited URL granting direct read access.
   *
   * This is how media reaches the app: `Image.network` cannot attach an
   * `Authorization` header, so without signed URLs private media renders on
   * mobile and silently breaks on web. Drivers that cannot sign return
   * undefined, and callers fall back to the proxied content endpoint.
   */
  signedUrl(key: string, ttlSeconds?: number): Promise<string | undefined>;

  /** Cheap reachability probe for the readiness endpoint. */
  healthCheck(): Promise<void>;
}
