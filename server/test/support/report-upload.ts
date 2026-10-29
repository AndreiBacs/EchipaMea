import { randomInt } from 'crypto';
import type { TestApp } from './app';
import { bearer } from './auth';

/**
 * A byte-for-byte replica of the multipart body `package:http` builds for the
 * worker report upload in `lib/src/features/worker/application/worker_reports_api.dart`.
 *
 * Built by hand rather than with supertest's `.field()`/`.attach()` so the wire
 * shape is the one the phone actually sends: `MultipartRequest.finalize()`
 * writes every text field first (in insertion order), then every file; headers
 * are lowercase; a non-ASCII field value gets its own `text/plain` header; and
 * every file part is `application/octet-stream`, because
 * `MultipartFile.fromPath` is called without a content type.
 */

export interface ReportFile {
  filename: string;
  bytes: Buffer;
}

export interface ReportUpload {
  projectId: string;
  projectName?: string;
  phaseId: string;
  phaseName?: string;
  /** Sent because the app sends it; the server must ignore it. */
  employeeId?: string;
  employeeName?: string;
  description?: string;
  /** Verbatim: Dart's `toUtc().toIso8601String()`, see `dartTimestamp()`. */
  submittedAt: string;
  photos?: ReportFile[];
  /**
   * The indexed `photoNames[i]` values. The app sends each photo's own name,
   * which is the default here; pass this to make them differ from the
   * part filenames.
   */
  photoNames?: string[];
  voiceMemo?: ReportFile;
}

export const REPORTS_PATH = '/worker/reports';

/** POSTs a report the way the phone does. Chain `.expect(...)` on the result. */
export function postReport(t: TestApp, accessToken: string, upload: ReportUpload) {
  const { body, contentType } = buildReportMultipart(upload);
  return t.http
    .post(REPORTS_PATH)
    .set(bearer(accessToken))
    .set('Content-Type', contentType)
    .send(body);
}

export function buildReportMultipart(upload: ReportUpload): { body: Buffer; contentType: string } {
  const photos = upload.photos ?? [];

  // Same insertion order as `request.fields[...] = ...` in the Dart client.
  const fields: [string, string][] = [
    ['projectId', upload.projectId],
    ['projectName', upload.projectName ?? ''],
    ['phaseId', upload.phaseId],
    ['phaseName', upload.phaseName ?? ''],
    ['employeeId', upload.employeeId ?? ''],
    ['employeeName', upload.employeeName ?? ''],
    ['description', upload.description ?? ''],
    ['submittedAt', upload.submittedAt],
  ];
  photos.forEach((photo, i) => {
    fields.push([`photoNames[${i}]`, upload.photoNames?.[i] ?? photo.filename]);
  });

  const files: { field: string; filename: string; bytes: Buffer }[] = photos.map((photo) => ({
    field: 'photos[]',
    ...photo,
  }));
  if (upload.voiceMemo) files.push({ field: 'voiceMemo', ...upload.voiceMemo });

  return dartMultipart(fields, files);
}

/** `MultipartRequest.finalize()` from package:http, transliterated. */
export function dartMultipart(
  fields: [string, string][],
  files: { field: string; filename: string; bytes: Buffer }[],
): { body: Buffer; contentType: string } {
  const boundary = dartBoundary();
  const chunks: Buffer[] = [];
  const separator = Buffer.from(`--${boundary}\r\n`);
  const line = Buffer.from('\r\n');

  for (const [name, value] of fields) {
    let header = `content-disposition: form-data; name="${browserEncode(name)}"`;
    if (!isPlainAscii(value)) {
      header += '\r\ncontent-type: text/plain; charset=utf-8\r\ncontent-transfer-encoding: binary';
    }
    chunks.push(separator, Buffer.from(`${header}\r\n\r\n`), Buffer.from(value, 'utf8'), line);
  }

  for (const file of files) {
    const header =
      'content-type: application/octet-stream\r\n' +
      `content-disposition: form-data; name="${browserEncode(file.field)}"; ` +
      `filename="${browserEncode(file.filename)}"`;
    chunks.push(separator, Buffer.from(`${header}\r\n\r\n`), file.bytes, line);
  }

  chunks.push(Buffer.from(`--${boundary}--\r\n`));
  return {
    body: Buffer.concat(chunks),
    contentType: `multipart/form-data; boundary=${boundary}`,
  };
}

/** package:http's `boundaryCharacters`: RFC 2046 bchars that are also RFC 1521 token chars. */
const BOUNDARY_CHARACTERS = '+_-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

/** `dart-http-boundary-` plus random characters, 70 in total. */
function dartBoundary(): string {
  const prefix = 'dart-http-boundary-';
  let boundary = prefix;
  while (boundary.length < 70) {
    boundary += BOUNDARY_CHARACTERS[randomInt(BOUNDARY_CHARACTERS.length)];
  }
  return boundary;
}

function browserEncode(value: string): string {
  return value.replace(/\r\n|\r|\n/g, '%0D%0A').replace(/"/g, '%22');
}

/**
 * package:http's `isPlainAscii`. Its pattern is `^[\x00-\x7F]+$`, so an *empty*
 * value does not count as plain ASCII and gets the text/plain header as well.
 */
function isPlainAscii(value: string): boolean {
  // eslint-disable-next-line no-control-regex -- the range is the point.
  return /^[\x00-\x7F]+$/.test(value);
}

let microsCounter = 0;

/**
 * What Dart's `DateTime.now().toUtc().toIso8601String()` emits on mobile: six
 * fractional digits. Each call is distinct, so each is a new idempotency key.
 */
export function dartTimestamp(at: Date = new Date()): string {
  microsCounter = (microsCounter % 999) + 1;
  const micros = String(microsCounter).padStart(3, '0');
  return at.toISOString().replace(/\.(\d{3})Z$/, `.$1${micros}Z`);
}

// --- Fixtures ---------------------------------------------------------------

/** A complete 1x1 baseline JPEG. */
const JPEG_1X1 = Buffer.from(
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP////////////////////////////////////////' +
    '//////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAA' +
    'AAAAAAAAAAAAAAAP/aAAgBAQABPxA=',
  'base64',
);

/** A complete 1x1 PNG. */
export const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

/**
 * A tiny JPEG, made unique by a COM segment so the server's per-tenant content
 * de-duplication does not fold two fixtures into one asset.
 */
export function jpeg(tag = 'fixture'): Buffer {
  const comment = Buffer.from(tag, 'latin1');
  const length = Buffer.alloc(2);
  length.writeUInt16BE(comment.length + 2);
  return Buffer.concat([
    JPEG_1X1.subarray(0, 2), // SOI
    Buffer.from([0xff, 0xfe]), // COM
    length,
    comment,
    JPEG_1X1.subarray(2),
  ]);
}

/**
 * The head of an `.m4a` as the `record` package writes it: an `ftyp` box with
 * the `M4A ` brand, followed by an (empty) `mdat`. Enough for the sniffer and
 * large enough to range over.
 */
export function m4a(tag = 'memo'): Buffer {
  const ftyp = Buffer.concat([
    Buffer.from([0x00, 0x00, 0x00, 0x1c]),
    Buffer.from('ftypM4A ', 'latin1'),
    Buffer.from([0x00, 0x00, 0x00, 0x00]),
    Buffer.from('M4A mp42isom', 'latin1'),
  ]);
  const payload = Buffer.from(`echipamea-e2e-${tag}`, 'latin1');
  const mdatHeader = Buffer.alloc(8);
  mdatHeader.writeUInt32BE(payload.length + 8);
  mdatHeader.write('mdat', 4, 'latin1');
  return Buffer.concat([ftyp, mdatHeader, payload]);
}

/** A supertest parser that keeps the body as raw bytes, whatever its type. */
export function binaryParser(
  res: NodeJS.EventEmitter,
  callback: (error: Error | null, body: Buffer) => void,
): void {
  const chunks: Buffer[] = [];
  res.on('data', (chunk: Buffer) => chunks.push(chunk));
  res.on('end', () => callback(null, Buffer.concat(chunks)));
  res.on('error', (error: Error) => callback(error, Buffer.alloc(0)));
}
