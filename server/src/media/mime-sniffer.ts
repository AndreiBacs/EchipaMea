import type { MediaKind } from '@prisma/client';

/**
 * Magic-byte MIME detection.
 *
 * The Flutter client sends *every* upload as `application/octet-stream` --
 * `MultipartFile.fromPath` is called without a contentType, for both photos and
 * voice memos. The declared part type therefore carries no information and must
 * never be trusted; the bytes are the only reliable signal.
 *
 * Hand-written rather than pulled from `file-type`, which is ESM-only and does
 * not import cleanly into this CommonJS build. The formats below are the ones
 * `image_picker` and `record` actually produce, plus the common web fallbacks.
 */

export interface SniffResult {
  contentType: string;
  kind: MediaKind;
  extension: string;
}

const UNKNOWN: SniffResult = {
  contentType: 'application/octet-stream',
  kind: 'document',
  extension: 'bin',
};

export function sniffMime(buffer: Buffer, filename?: string): SniffResult {
  const byMagic = sniffByMagic(buffer);
  if (byMagic) return byMagic;

  // Fall back to the filename. `record` writes .m4a files whose ftyp brand can
  // vary by platform, so the extension is a useful second opinion.
  const byExtension = sniffByExtension(filename);
  if (byExtension) return byExtension;

  return UNKNOWN;
}

function sniffByMagic(buffer: Buffer): SniffResult | undefined {
  if (buffer.length < 4) return undefined;

  // --- images -------------------------------------------------------------
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return { contentType: 'image/jpeg', kind: 'photo', extension: 'jpg' };
  }
  if (startsWith(buffer, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return { contentType: 'image/png', kind: 'photo', extension: 'png' };
  }
  if (startsWith(buffer, [0x47, 0x49, 0x46, 0x38])) {
    return { contentType: 'image/gif', kind: 'photo', extension: 'gif' };
  }
  if (buffer.length >= 12 && ascii(buffer, 0, 4) === 'RIFF' && ascii(buffer, 8, 4) === 'WEBP') {
    return { contentType: 'image/webp', kind: 'photo', extension: 'webp' };
  }
  // RIFF containers: the form type at offset 8 says whether it is audio.
  if (buffer.length >= 12 && ascii(buffer, 0, 4) === 'RIFF' && ascii(buffer, 8, 4) === 'WAVE') {
    return { contentType: 'audio/wav', kind: 'audio', extension: 'wav' };
  }

  // --- ISO base media (mp4 / m4a / heic) ----------------------------------
  // Bytes 4-8 are 'ftyp'; the brand that follows distinguishes the flavour.
  if (buffer.length >= 12 && ascii(buffer, 4, 4) === 'ftyp') {
    const brand = ascii(buffer, 8, 4);
    if (brand.startsWith('heic') || brand.startsWith('heix') || brand.startsWith('mif1')) {
      return { contentType: 'image/heic', kind: 'photo', extension: 'heic' };
    }
    if (brand.startsWith('M4A') || brand.startsWith('M4B')) {
      return { contentType: 'audio/mp4', kind: 'audio', extension: 'm4a' };
    }
    if (brand.startsWith('qt')) {
      return { contentType: 'video/quicktime', kind: 'video', extension: 'mov' };
    }
    // isom / mp42 / avc1 are used for both audio-only and video mp4 containers.
    return { contentType: 'video/mp4', kind: 'video', extension: 'mp4' };
  }

  // --- audio --------------------------------------------------------------
  if (startsWith(buffer, [0x49, 0x44, 0x33])) {
    return { contentType: 'audio/mpeg', kind: 'audio', extension: 'mp3' };
  }
  if (buffer[0] === 0xff && buffer[1] !== undefined && (buffer[1] & 0xe0) === 0xe0) {
    return { contentType: 'audio/mpeg', kind: 'audio', extension: 'mp3' };
  }
  if (startsWith(buffer, [0x4f, 0x67, 0x67, 0x53])) {
    return { contentType: 'audio/ogg', kind: 'audio', extension: 'ogg' };
  }
  if (startsWith(buffer, [0x66, 0x4c, 0x61, 0x43])) {
    return { contentType: 'audio/flac', kind: 'audio', extension: 'flac' };
  }
  // AAC ADTS
  if (buffer[0] === 0xff && buffer[1] !== undefined && (buffer[1] & 0xf6) === 0xf0) {
    return { contentType: 'audio/aac', kind: 'audio', extension: 'aac' };
  }

  if (startsWith(buffer, [0x25, 0x50, 0x44, 0x46])) {
    return { contentType: 'application/pdf', kind: 'document', extension: 'pdf' };
  }

  return undefined;
}

const EXTENSION_MAP: Record<string, SniffResult> = {
  jpg: { contentType: 'image/jpeg', kind: 'photo', extension: 'jpg' },
  jpeg: { contentType: 'image/jpeg', kind: 'photo', extension: 'jpg' },
  png: { contentType: 'image/png', kind: 'photo', extension: 'png' },
  gif: { contentType: 'image/gif', kind: 'photo', extension: 'gif' },
  webp: { contentType: 'image/webp', kind: 'photo', extension: 'webp' },
  heic: { contentType: 'image/heic', kind: 'photo', extension: 'heic' },
  m4a: { contentType: 'audio/mp4', kind: 'audio', extension: 'm4a' },
  aac: { contentType: 'audio/aac', kind: 'audio', extension: 'aac' },
  mp3: { contentType: 'audio/mpeg', kind: 'audio', extension: 'mp3' },
  wav: { contentType: 'audio/wav', kind: 'audio', extension: 'wav' },
  ogg: { contentType: 'audio/ogg', kind: 'audio', extension: 'ogg' },
  opus: { contentType: 'audio/opus', kind: 'audio', extension: 'opus' },
  mp4: { contentType: 'video/mp4', kind: 'video', extension: 'mp4' },
  mov: { contentType: 'video/quicktime', kind: 'video', extension: 'mov' },
  pdf: { contentType: 'application/pdf', kind: 'document', extension: 'pdf' },
};

function sniffByExtension(filename?: string): SniffResult | undefined {
  if (!filename) return undefined;
  const match = /\.([A-Za-z0-9]+)$/.exec(filename.trim());
  if (!match?.[1]) return undefined;
  return EXTENSION_MAP[match[1].toLowerCase()];
}

function startsWith(buffer: Buffer, bytes: number[]): boolean {
  if (buffer.length < bytes.length) return false;
  return bytes.every((byte, index) => buffer[index] === byte);
}

function ascii(buffer: Buffer, offset: number, length: number): string {
  if (buffer.length < offset + length) return '';
  return buffer.subarray(offset, offset + length).toString('latin1');
}
