import { sniffMime } from './mime-sniffer';

/** Builds a header-only buffer; sniffing only ever reads the first bytes. */
const bytes = (...values: number[]) => Buffer.from([...values, ...new Array(16).fill(0)]);
const withAscii = (prefix: number[], at8: string) => {
  const buf = Buffer.alloc(32);
  Buffer.from(prefix).copy(buf, 0);
  buf.write(at8, 8, 'latin1');
  return buf;
};

describe('sniffMime', () => {
  it('detects JPEG', () => {
    expect(sniffMime(bytes(0xff, 0xd8, 0xff, 0xe0))).toMatchObject({
      contentType: 'image/jpeg',
      kind: 'photo',
    });
  });

  it('detects PNG', () => {
    expect(sniffMime(bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))).toMatchObject({
      contentType: 'image/png',
      kind: 'photo',
    });
  });

  it('detects WEBP via the RIFF form type', () => {
    const buf = Buffer.alloc(32);
    buf.write('RIFF', 0, 'latin1');
    buf.write('WEBP', 8, 'latin1');
    expect(sniffMime(buf)).toMatchObject({ contentType: 'image/webp', kind: 'photo' });
  });

  it('detects WAV via the RIFF form type', () => {
    const buf = Buffer.alloc(32);
    buf.write('RIFF', 0, 'latin1');
    buf.write('WAVE', 8, 'latin1');
    expect(sniffMime(buf)).toMatchObject({ contentType: 'audio/wav', kind: 'audio' });
  });

  it('detects HEIC from the ftyp brand', () => {
    const buf = Buffer.alloc(32);
    buf.write('ftyp', 4, 'latin1');
    buf.write('heic', 8, 'latin1');
    expect(sniffMime(buf)).toMatchObject({ contentType: 'image/heic', kind: 'photo' });
  });

  it('detects M4A from the ftyp brand -- what `record` produces for voice memos', () => {
    const buf = Buffer.alloc(32);
    buf.write('ftyp', 4, 'latin1');
    buf.write('M4A ', 8, 'latin1');
    expect(sniffMime(buf)).toMatchObject({ contentType: 'audio/mp4', kind: 'audio' });
  });

  it('treats an unbranded ftyp container as mp4 video', () => {
    const buf = Buffer.alloc(32);
    buf.write('ftyp', 4, 'latin1');
    buf.write('isom', 8, 'latin1');
    expect(sniffMime(buf)).toMatchObject({ contentType: 'video/mp4', kind: 'video' });
  });

  it('detects MP3 with an ID3 tag', () => {
    expect(sniffMime(bytes(0x49, 0x44, 0x33, 0x03))).toMatchObject({
      contentType: 'audio/mpeg',
      kind: 'audio',
    });
  });

  it('detects PDF', () => {
    expect(sniffMime(bytes(0x25, 0x50, 0x44, 0x46))).toMatchObject({
      contentType: 'application/pdf',
      kind: 'document',
    });
  });

  describe('filename fallback', () => {
    // The client declares application/octet-stream for everything, so when the
    // magic bytes are inconclusive the extension is the only remaining signal.
    it('uses the extension when magic bytes do not match', () => {
      expect(sniffMime(Buffer.alloc(32), 'worker_memo_1786714993.m4a')).toMatchObject({
        contentType: 'audio/mp4',
        kind: 'audio',
      });
    });

    it('is case-insensitive', () => {
      expect(sniffMime(Buffer.alloc(32), 'PHOTO.JPG')).toMatchObject({ contentType: 'image/jpeg' });
    });

    it('prefers magic bytes over a lying extension', () => {
      expect(sniffMime(bytes(0xff, 0xd8, 0xff, 0xe0), 'not-really.mp3')).toMatchObject({
        contentType: 'image/jpeg',
      });
    });
  });

  it('falls back to octet-stream for unrecognised content', () => {
    expect(sniffMime(Buffer.from([0x01, 0x02, 0x03, 0x04]), 'mystery.xyz')).toMatchObject({
      contentType: 'application/octet-stream',
      kind: 'document',
    });
  });

  it('does not crash on a tiny buffer', () => {
    expect(sniffMime(Buffer.from([0x01]))).toMatchObject({
      contentType: 'application/octet-stream',
    });
  });
});
