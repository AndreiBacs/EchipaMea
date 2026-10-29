import { Injectable } from '@nestjs/common';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { Readable } from 'node:stream';
import { AppConfig } from '../../common/config/configuration';
import { AppException } from '../../common/errors/app-exception';
import type {
  StorageRange,
  StorageReadResult,
  StorageService,
  StoredObject,
} from './storage.interface';

/** S3-compatible storage: AWS S3, Cloudflare R2, MinIO in the dev compose. */
@Injectable()
export class S3StorageService implements StorageService {
  readonly driver = 's3' as const;
  readonly bucket: string;

  private readonly client: S3Client;
  private readonly signedUrlTtl: number;

  constructor(config: AppConfig) {
    this.bucket = config.s3Bucket;
    this.signedUrlTtl = config.s3SignedUrlTtlSeconds;
    this.client = new S3Client({
      region: config.s3Region,
      endpoint: config.s3Endpoint,
      // MinIO and most self-hosted gateways cannot do virtual-host buckets.
      forcePathStyle: config.s3ForcePathStyle,
      credentials: {
        accessKeyId: config.s3AccessKeyId,
        secretAccessKey: config.s3SecretAccessKey,
      },
    });
  }

  async put(key: string, body: Buffer, contentType: string): Promise<StoredObject> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
        ContentLength: body.byteLength,
      }),
    );
    return { key, bucket: this.bucket, byteSize: body.byteLength };
  }

  async read(key: string, range?: StorageRange): Promise<StorageReadResult> {
    try {
      const response = await this.client.send(
        new GetObjectCommand({
          Bucket: this.bucket,
          Key: key,
          Range: range ? formatRange(range) : undefined,
        }),
      );
      const body = response.Body as Readable | undefined;
      if (!body) throw AppException.notFound('Media object', key);
      return {
        stream: body,
        contentType: response.ContentType ?? 'application/octet-stream',
        byteSize: response.ContentLength ?? 0,
        contentRange: response.ContentRange,
      };
    } catch (error) {
      if (isNotFound(error)) throw AppException.notFound('Media object', key);
      throw error;
    }
  }

  async delete(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }

  async exists(key: string): Promise<boolean> {
    try {
      await this.client.send(new HeadObjectCommand({ Bucket: this.bucket, Key: key }));
      return true;
    } catch (error) {
      if (isNotFound(error)) return false;
      throw error;
    }
  }

  async signedUrl(key: string, ttlSeconds?: number): Promise<string | undefined> {
    return getSignedUrl(this.client, new GetObjectCommand({ Bucket: this.bucket, Key: key }), {
      expiresIn: ttlSeconds ?? this.signedUrlTtl,
    });
  }

  async healthCheck(): Promise<void> {
    await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
  }
}

function formatRange(range: StorageRange): string {
  return range.end === undefined ? `bytes=${range.start}-` : `bytes=${range.start}-${range.end}`;
}

function isNotFound(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) return false;
  const candidate = error as { name?: string; $metadata?: { httpStatusCode?: number } };
  return (
    candidate.name === 'NoSuchKey' ||
    candidate.name === 'NotFound' ||
    candidate.$metadata?.httpStatusCode === 404
  );
}
