import { Inject, Injectable, Logger } from '@nestjs/common';
import type { MediaKind, Prisma } from '@prisma/client';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode } from '../common/errors/error-codes';
import { PrismaService } from '../common/prisma/prisma.service';
import { sha256Hex, storageId } from '../common/util/ids';
import type { Principal } from '../common/auth/principal';
import { sniffMime } from './mime-sniffer';
import { STORAGE_SERVICE, type StorageReadResult, type StorageService } from './storage/storage.interface';

export interface UploadInput {
  buffer: Buffer;
  originalName?: string;
  /** Declared part type. Recorded for diagnosis only -- never trusted. */
  declaredContentType?: string;
}

export interface MediaDto {
  id: string;
  url: string;
  contentType: string;
  kind: MediaKind;
  byteSize: number;
  originalName: string;
  createdAt: string;
}

@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: AppConfig,
    @Inject(STORAGE_SERVICE) private readonly storage: StorageService,
  ) {}

  /**
   * Stores an upload and records it.
   *
   * Identical bytes within a tenant are de-duplicated by content hash: the
   * foreman phase editor re-submits its whole instruction list on every save,
   * so the same photo would otherwise be re-uploaded on each edit.
   */
  async upload(principal: Principal, input: UploadInput): Promise<MediaDto> {
    if (input.buffer.length === 0) {
      throw AppException.badRequest('Uploaded file is empty.', 'file');
    }
    if (input.buffer.length > this.config.uploadMaxFileBytes) {
      throw AppException.payloadTooLarge(
        `File exceeds the ${Math.floor(this.config.uploadMaxFileBytes / 1024 / 1024)} MB limit.`,
      );
    }

    const sniffed = sniffMime(input.buffer, input.originalName);
    const sha256 = sha256Hex(input.buffer);

    const existing = await this.prisma.mediaAsset.findFirst({
      where: { companyId: principal.companyId, sha256, byteSize: input.buffer.length },
    });
    if (existing) {
      this.logger.debug(`Reusing media ${existing.id} for identical content.`);
      return this.toDto(existing);
    }

    const now = new Date();
    const key = [
      'co',
      principal.companyId,
      String(now.getUTCFullYear()),
      String(now.getUTCMonth() + 1).padStart(2, '0'),
      `${storageId()}.${sniffed.extension}`,
    ].join('/');

    const stored = await this.storage.put(key, input.buffer, sniffed.contentType);

    const asset = await this.prisma.mediaAsset.create({
      data: {
        companyId: principal.companyId,
        storageKey: stored.key,
        bucket: stored.bucket,
        kind: sniffed.kind,
        contentType: sniffed.contentType,
        byteSize: stored.byteSize,
        sha256,
        originalName: (input.originalName ?? '').slice(0, 255),
        uploadedByUserId: principal.kind === 'user' ? principal.userId : null,
        uploadedByEmployeeId: principal.kind === 'employee' ? principal.employeeId : null,
      },
    });

    return this.toDto(asset);
  }

  async getMetadata(companyId: string, mediaId: string): Promise<MediaDto> {
    return this.toDto(await this.findOrThrow(companyId, mediaId));
  }

  /** Opens a byte stream, optionally ranged for audio seeking. */
  async read(
    companyId: string,
    mediaId: string,
    range?: { start: number; end?: number },
  ): Promise<StorageReadResult & { contentType: string; originalName: string }> {
    const asset = await this.findOrThrow(companyId, mediaId);
    const result = await this.storage.read(asset.storageKey, range);
    return {
      ...result,
      // The stored content type is authoritative; the local driver cannot
      // report one from the filesystem.
      contentType: asset.contentType,
      originalName: asset.originalName,
    };
  }

  /**
   * A time-limited direct URL, when the driver can sign one.
   *
   * This is how media should reach the app: `Image.network` cannot attach an
   * Authorization header, so without signing, private media works on mobile
   * only through the proxied endpoint and breaks under web CORS.
   */
  async signedUrl(companyId: string, mediaId: string): Promise<{ url: string; expiresIn: number }> {
    const asset = await this.findOrThrow(companyId, mediaId);
    const url = await this.storage.signedUrl(asset.storageKey);
    if (!url) {
      throw new AppException(
        501,
        ErrorCode.INTERNAL_ERROR,
        `The ${this.storage.driver} storage driver cannot issue signed URLs. ` +
          'Use GET /media/{id}/content instead.',
      );
    }
    return { url, expiresIn: this.config.s3SignedUrlTtlSeconds };
  }

  /**
   * Deletes an asset, refusing while something live still shows it.
   *
   * "Live" excludes instructions belonging to a soft-deleted phase. Those rows
   * survive the phase delete and nothing renders them, so counting them would
   * make the media undeletable forever: a foreman who removes a phase could
   * never then remove its photos. Report links always count -- reports are
   * never soft-deleted and remain part of the audit trail.
   */
  async remove(companyId: string, mediaId: string): Promise<void> {
    const asset = await this.findOrThrow(companyId, mediaId);

    const [liveInstructionLinks, reportLinks] = await Promise.all([
      this.prisma.workInstructionMedia.count({
        where: { companyId, mediaId, instruction: { phase: { deletedAt: null } } },
      }),
      this.prisma.workerReportMedia.count({ where: { companyId, mediaId } }),
    ]);
    if (liveInstructionLinks + reportLinks > 0) {
      throw AppException.conflict(
        'This file is still attached to a work instruction or report.',
        ErrorCode.MEDIA_IN_USE,
      );
    }

    await this.prisma.$transaction([
      // Only dead links can remain here. They must go first: the link rows
      // reference the asset with onDelete: Restrict, so the delete below would
      // otherwise fail at the database level.
      this.prisma.workInstructionMedia.deleteMany({ where: { companyId, mediaId } }),
      this.prisma.mediaAsset.delete({ where: { id_companyId: { id: mediaId, companyId } } }),
    ]);

    // Storage removal is best-effort and deliberately after the row delete: an
    // orphaned object costs pennies, whereas a row pointing at missing bytes
    // renders as a broken image forever.
    try {
      await this.storage.delete(asset.storageKey);
    } catch (error) {
      this.logger.warn(
        `Deleted media row ${mediaId} but its object remains: ${messageOf(error)}`,
      );
    }
  }

  /**
   * Validates that media ids exist in this tenant before they are linked.
   *
   * A foreign key alone would accept an id belonging to another company.
   */
  async assertOwned(companyId: string, mediaIds: string[]): Promise<void> {
    const unique = [...new Set(mediaIds)].filter((id) => id.length > 0);
    if (unique.length === 0) return;

    const found = await this.prisma.mediaAsset.findMany({
      where: { companyId, id: { in: unique } },
      select: { id: true },
    });
    if (found.length !== unique.length) {
      const known = new Set(found.map((m) => m.id));
      throw AppException.badRequest(
        `Unknown media: ${unique.filter((id) => !known.has(id)).join(', ')}.`,
        'mediaIds',
      );
    }
  }

  /** Housekeeping: media uploaded but never attached to anything. */
  async pruneUnreferenced(olderThanHours = 24): Promise<number> {
    const cutoff = new Date(Date.now() - olderThanHours * 60 * 60 * 1000);
    const orphans = await this.prisma.mediaAsset.findMany({
      where: {
        createdAt: { lt: cutoff },
        workInstructionLinks: { none: {} },
        reportLinks: { none: {} },
      },
      select: { id: true, companyId: true, storageKey: true },
      take: 500,
    });

    for (const orphan of orphans) {
      await this.prisma.mediaAsset.delete({
        where: { id_companyId: { id: orphan.id, companyId: orphan.companyId } },
      });
      try {
        await this.storage.delete(orphan.storageKey);
      } catch (error) {
        this.logger.warn(`Orphan object ${orphan.storageKey} not removed: ${messageOf(error)}`);
      }
    }
    return orphans.length;
  }

  private async findOrThrow(
    companyId: string,
    mediaId: string,
  ): Promise<Prisma.MediaAssetGetPayload<object>> {
    const asset = await this.prisma.mediaAsset.findFirst({
      where: { id: mediaId, companyId },
    });
    if (!asset) throw AppException.notFound('Media', mediaId);
    return asset;
  }

  private toDto(asset: Prisma.MediaAssetGetPayload<object>): MediaDto {
    return {
      id: asset.id,
      url: `${this.config.storagePublicBaseUrl}/media/${asset.id}/content`,
      contentType: asset.contentType,
      kind: asset.kind,
      byteSize: asset.byteSize,
      originalName: asset.originalName,
      createdAt: asset.createdAt.toISOString(),
    };
  }
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
