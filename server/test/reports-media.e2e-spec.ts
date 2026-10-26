import type { Response } from 'supertest';
import { createTestApp, type TestApp } from './support/app';
import {
  bearer,
  loginForeman,
  workerSession,
  type ForemanSession,
  type WorkerSession,
} from './support/auth';
import { resetDb } from './support/db';
import {
  PNG_1X1,
  binaryParser,
  dartTimestamp,
  jpeg,
  m4a,
  postReport,
  type ReportUpload,
} from './support/report-upload';

interface ApiError {
  code: string;
  message: string;
  field?: string;
}

interface ReportResult {
  id: string;
  projectId: string;
  phaseId: string;
  employeeId: string;
  submittedAt: string;
  photoCount: number;
  hasVoiceMemo: boolean;
  phaseStatus: string;
  duplicate: boolean;
}

interface MediaDto {
  id: string;
  url: string;
  contentType: string;
  kind: string;
  byteSize: number;
  originalName: string;
  createdAt: string;
}

interface NotificationDto {
  id: string;
  kind: string;
  payload: Record<string, unknown>;
  projectId: string | null;
  phaseId: string | null;
  employeeId: string | null;
  reportId: string | null;
  readAt: string | null;
}

function errorOf(res: Response): ApiError {
  // `/media/:id/content` responses are read as raw bytes, errors included.
  const body: unknown = Buffer.isBuffer(res.body)
    ? JSON.parse(res.body.toString('utf8'))
    : res.body;
  return (body as { error: ApiError }).error;
}

function bytesOf(res: Response): Buffer {
  return res.body as Buffer;
}

/**
 * The worker report upload and the media endpoints, end to end.
 *
 * The upload is the one route the shipped Flutter app already calls, so every
 * report here is built byte for byte the way `package:http` builds it (see
 * `support/report-upload.ts`): text fields first, `photoNames[i]`, file parts
 * literally named `photos[]`, and every file declared `application/octet-stream`.
 *
 * Every report goes to p1_phase_1 with a fresh six-digit timestamp, so each is
 * a new idempotency key. The phase moves inProgress -> pendingReview on the
 * first one and stays there, which the lifecycle allows.
 */
describe('worker reports and media (e2e)', () => {
  let t: TestApp;
  let foreman: ForemanSession;
  let rival: ForemanSession;
  let worker: WorkerSession;

  beforeAll(async () => {
    t = await createTestApp();
    await resetDb(t.prisma);
    foreman = await loginForeman(t, 'demo');
    rival = await loginForeman(t, 'rival');
    worker = await workerSession(t, foreman.accessToken, 'e1');
  });

  afterAll(async () => {
    await t.close();
  });

  /** A report from e1 on p1_phase_1, as the app fills it in. */
  function report(overrides: Partial<ReportUpload> = {}): ReportUpload {
    return {
      projectId: 'p1',
      projectName: 'Renovation - Main Street 15',
      phaseId: 'p1_phase_1',
      phaseName: 'Demolition',
      employeeId: 'e1',
      employeeName: 'Andrei D.',
      description: 'Demolition finished on the ground floor.',
      submittedAt: dartTimestamp(),
      photos: [],
      ...overrides,
    };
  }

  /** Uploads as worker e1 (unless told otherwise) and expects 201. */
  async function submit(upload: ReportUpload, token = worker.accessToken): Promise<ReportResult> {
    const res = await postReport(t, token, upload).expect(201);
    return res.body as ReportResult;
  }

  async function submitRejected(upload: ReportUpload, status: number): Promise<ApiError> {
    return errorOf(await postReport(t, worker.accessToken, upload).expect(status));
  }

  function reportMedia(reportId: string) {
    return t.prisma.workerReportMedia.findMany({
      where: { reportId },
      include: { media: true },
      orderBy: { sortIndex: 'asc' },
    });
  }

  async function onlyMediaId(reportId: string): Promise<string> {
    const links = await reportMedia(reportId);
    expect(links).toHaveLength(1);
    return links[0]!.mediaId;
  }

  function getContent(token: string, mediaId: string) {
    return t.http
      .get(`/media/${mediaId}/content`)
      .set(bearer(token))
      .buffer(true)
      .parse(binaryParser);
  }

  describe('upload (the Flutter wire format)', () => {
    it('accepts the multipart body exactly as package:http builds it', async () => {
      const photo = jpeg('wire-format');
      const memo = m4a('wire-format');
      const upload = report({
        // Non-ASCII on purpose: package:http gives such a field its own
        // `text/plain; charset=utf-8` header, and the text must survive intact.
        description: 'Tencuială terminată; două prize mutate. Kész.',
        photos: [
          { filename: 'IMG_20260814_091233.jpg', bytes: photo },
          { filename: 'Screenshot_1.png', bytes: PNG_1X1 },
        ],
        voiceMemo: { filename: 'memo_1755162753.m4a', bytes: memo },
      });

      const result = await submit(upload);

      expect(result).toEqual({
        id: expect.any(String),
        projectId: 'p1',
        phaseId: 'p1_phase_1',
        employeeId: 'e1',
        // The instant is held at millisecond precision; the raw string is checked below.
        submittedAt: upload.submittedAt.replace(/(\.\d{3})\d{3}Z$/, '$1Z'),
        photoCount: 2,
        hasVoiceMemo: true,
        phaseStatus: 'pendingReview',
        duplicate: false,
      });

      const row = await t.prisma.workerReport.findUniqueOrThrow({ where: { id: result.id } });
      expect(row).toMatchObject({
        companyId: 'demo-company',
        projectId: 'p1',
        phaseId: 'p1_phase_1',
        employeeId: 'e1',
        description: upload.description,
        submittedAtRaw: upload.submittedAt,
        source: 'http',
      });

      // The declared part type is octet-stream for all three; the bytes decide.
      const links = await reportMedia(result.id);
      const linked = (slot: string, index: number) =>
        links.find((link) => link.slot === slot && link.sortIndex === index)?.media;
      expect(links).toHaveLength(3);
      expect(linked('reportPhoto', 0)).toMatchObject({
        contentType: 'image/jpeg',
        kind: 'photo',
        byteSize: photo.length,
        uploadedByEmployeeId: 'e1',
      });
      expect(linked('reportPhoto', 1)).toMatchObject({
        contentType: 'image/png',
        kind: 'photo',
        byteSize: PNG_1X1.length,
      });
      expect(linked('reportVoiceMemo', 0)).toMatchObject({
        contentType: 'audio/mp4',
        kind: 'audio',
        byteSize: memo.length,
        originalName: 'memo_1755162753.m4a',
      });

      const phase = await t.prisma.projectPhase.findFirstOrThrow({ where: { id: 'p1_phase_1' } });
      expect(phase.status).toBe('pendingReview');
    });

    it("files the report under the token's employee and ignores employeeId on the wire", async () => {
      const upload = report({ employeeId: 'e2' });

      const result = await submit(upload);

      expect(result.employeeId).toBe('e1');
      const row = await t.prisma.workerReport.findUniqueOrThrow({ where: { id: result.id } });
      expect(row.employeeId).toBe('e1');
      expect(
        await t.prisma.workerReport.count({
          where: { employeeId: 'e2', submittedAtRaw: upload.submittedAt },
        }),
      ).toBe(0);
    });

    // Regression: Multer expands `photoNames[0]` into a `photoNames` array, and
    // the controller used to read only literal `photoNames[N]` keys from the
    // flattened body -- so every name was lost and clientName fell back to
    // whichever upload first stored those bytes.
    it('records photoNames[i] verbatim, even when it differs from the part filename', async () => {
      const upload = report({
        photos: [
          { filename: 'image_picker_A1.jpg', bytes: jpeg('names-0') },
          { filename: 'image_picker_B2.jpg', bytes: jpeg('names-1') },
        ],
        photoNames: ['Kitchen wall before.jpg', 'Kitchen wall after.jpg'],
      });

      const result = await submit(upload);

      const names = (await reportMedia(result.id))
        .filter((link) => link.slot === 'reportPhoto')
        .map((link) => link.clientName);
      expect(names).toEqual(['Kitchen wall before.jpg', 'Kitchen wall after.jpg']);
    });

    it('accepts the three-digit timestamp Flutter web emits and keeps it verbatim', async () => {
      const submittedAt = new Date(Date.now() - 60 * 60 * 1000).toISOString();

      const result = await submit(report({ submittedAt }));

      expect(result.submittedAt).toBe(submittedAt);
      const row = await t.prisma.workerReport.findUniqueOrThrow({ where: { id: result.id } });
      expect(row.submittedAtRaw).toBe(submittedAt);
    });

    it('requires a token', async () => {
      const res = await t.http
        .post('/worker/reports')
        .field('projectId', 'p1')
        .field('phaseId', 'p1_phase_1')
        .field('submittedAt', dartTimestamp())
        .expect(401);
      expect(errorOf(res).code).toBe('UNAUTHENTICATED');
    });

    it('validates the text fields with the error envelope', async () => {
      expect(await submitRejected(report({ phaseId: '' }), 400)).toMatchObject({
        code: 'VALIDATION_FAILED',
        field: 'phaseId',
      });
      expect(await submitRejected(report({ submittedAt: 'yesterday evening' }), 400)).toMatchObject(
        { code: 'VALIDATION_FAILED', field: 'submittedAt' },
      );
    });

    it('refuses a phase that is not in the named project, or does not exist', async () => {
      expect((await submitRejected(report({ projectId: 'p2' }), 404)).code).toBe('NOT_FOUND');
      expect((await submitRejected(report({ phaseId: 'no_such_phase' }), 404)).code).toBe(
        'NOT_FOUND',
      );
    });

    it("a worker from another company cannot file a report on this company's phase", async () => {
      const rivalWorker = await workerSession(t, rival.accessToken, 'rival_e1');
      const upload = report({ employeeId: 'rival_e1', employeeName: 'Rival' });

      const res = await postReport(t, rivalWorker.accessToken, upload).expect(404);

      expect(errorOf(res).code).toBe('NOT_FOUND');
      expect(
        await t.prisma.workerReport.count({ where: { submittedAtRaw: upload.submittedAt } }),
      ).toBe(0);
    });
  });

  describe('idempotency', () => {
    it('a retried upload answers 201 with the original report and stores nothing new', async () => {
      const upload = report({ photos: [{ filename: 'retry.jpg', bytes: jpeg('retry-1') }] });
      const first = await submit(upload);
      const before = {
        reports: await t.prisma.workerReport.count(),
        media: await t.prisma.mediaAsset.count(),
        notifications: await t.prisma.notification.count({ where: { reportId: first.id } }),
      };

      // Same (phase, employee, submittedAt) with different bytes: the retry is
      // recognised before any attachment is stored.
      const retry = await submit({
        ...upload,
        photos: [{ filename: 'retry.jpg', bytes: jpeg('retry-2') }],
      });

      expect(retry).toMatchObject({
        id: first.id,
        employeeId: 'e1',
        photoCount: 1,
        hasVoiceMemo: false,
        duplicate: true,
      });
      expect(await t.prisma.workerReport.count()).toBe(before.reports);
      expect(await t.prisma.mediaAsset.count()).toBe(before.media);
      expect(await t.prisma.notification.count({ where: { reportId: first.id } })).toBe(
        before.notifications,
      );
    });

    it("keys on the token's employee: the same timestamp from another worker is a new report", async () => {
      const otherWorker = await workerSession(t, foreman.accessToken, 'e2');
      const submittedAt = dartTimestamp();

      const mine = await submit(report({ submittedAt }));
      const theirs = await submit(
        report({ submittedAt, employeeId: 'e1', employeeName: 'Mihai S.' }),
        otherWorker.accessToken,
      );

      expect(theirs).toMatchObject({ employeeId: 'e2', duplicate: false });
      expect(theirs.id).not.toBe(mine.id);
    });
  });

  describe('notifications', () => {
    async function unreadCount(token: string): Promise<number> {
      const res = await t.http.get('/notifications/unread-count').set(bearer(token)).expect(200);
      return (res.body as { unreadCount: number }).unreadCount;
    }

    async function notificationsFor(token: string, reportId: string): Promise<NotificationDto[]> {
      const res = await t.http
        .get('/notifications')
        .query({ kind: 'workerReportSubmitted', limit: 100 })
        .set(bearer(token))
        .expect(200);
      const { items } = res.body as { items: NotificationDto[] };
      return items.filter((n) => n.reportId === reportId);
    }

    it('notifies the company foreman exactly once, and nobody in another company', async () => {
      const unreadBefore = await unreadCount(foreman.accessToken);
      const rivalUnreadBefore = await unreadCount(rival.accessToken);

      const result = await submit(
        report({ photos: [{ filename: 'n.jpg', bytes: jpeg('notify') }] }),
      );

      const mine = await notificationsFor(foreman.accessToken, result.id);
      expect(mine).toHaveLength(1);
      expect(mine[0]).toMatchObject({
        kind: 'workerReportSubmitted',
        projectId: 'p1',
        phaseId: 'p1_phase_1',
        employeeId: 'e1',
        reportId: result.id,
        readAt: null,
        payload: expect.objectContaining({
          projectId: 'p1',
          phaseId: 'p1_phase_1',
          employeeId: 'e1',
          photoCount: 1,
          hasVoiceMemo: false,
        }),
      });
      expect(await unreadCount(foreman.accessToken)).toBe(unreadBefore + 1);

      expect(await notificationsFor(rival.accessToken, result.id)).toEqual([]);
      expect(await unreadCount(rival.accessToken)).toBe(rivalUnreadBefore);
    });

    it('writes one row per active foreman of the company, so read state is per person', async () => {
      const extraForemen = ['e2e_second_foreman', 'e2e_inactive_foreman'];
      await t.prisma.user.createMany({
        data: [
          {
            id: 'e2e_second_foreman',
            companyId: 'demo-company',
            email: 'second.foreman@e2e.local',
            passwordHash: 'not-a-real-hash',
          },
          {
            id: 'e2e_inactive_foreman',
            companyId: 'demo-company',
            email: 'inactive.foreman@e2e.local',
            passwordHash: 'not-a-real-hash',
            isActive: false,
          },
        ],
      });

      try {
        const result = await submit(report());

        const rows = await t.prisma.notification.findMany({
          where: { reportId: result.id },
          select: { recipientUserId: true, companyId: true, kind: true },
        });
        expect(rows.map((row) => row.recipientUserId).sort()).toEqual([
          'e2e_second_foreman',
          'foreman_local',
        ]);
        for (const row of rows) {
          expect(row).toMatchObject({ companyId: 'demo-company', kind: 'workerReportSubmitted' });
        }
      } finally {
        // Their notification rows cascade with them.
        await t.prisma.user.deleteMany({ where: { id: { in: extraForemen } } });
      }
    });

    it('a worker token cannot read notifications', async () => {
      const res = await t.http.get('/notifications').set(bearer(worker.accessToken)).expect(403);
      expect(errorOf(res).code).toBe('FORBIDDEN');
    });
  });

  describe('media', () => {
    async function uploadMedia(
      token: string,
      bytes: Buffer,
      filename: string,
      declaredType = 'application/octet-stream',
    ): Promise<MediaDto> {
      const res = await t.http
        .post('/media')
        .set(bearer(token))
        .attach('file', bytes, { filename, contentType: declaredType })
        .expect(201);
      return res.body as MediaDto;
    }

    it('sniffs an octet-stream JPEG and serves it back as image/jpeg, byte for byte', async () => {
      const bytes = jpeg('media-roundtrip');
      const media = await uploadMedia(foreman.accessToken, bytes, 'site.jpg');

      expect(media).toEqual({
        id: expect.any(String),
        url: expect.stringMatching(new RegExp(`/media/${media.id}/content$`)),
        contentType: 'image/jpeg',
        kind: 'photo',
        byteSize: bytes.length,
        originalName: 'site.jpg',
        createdAt: expect.any(String),
      });

      const meta = await t.http
        .get(`/media/${media.id}`)
        .set(bearer(foreman.accessToken))
        .expect(200);
      expect(meta.body).toEqual(media);

      const content = await getContent(foreman.accessToken, media.id).expect(200);
      expect(content.headers['content-type']).toBe('image/jpeg');
      expect(content.headers['content-length']).toBe(String(bytes.length));
      expect(content.headers['accept-ranges']).toBe('bytes');
      expect(content.headers['cache-control']).toBe('private, max-age=300');
      expect(bytesOf(content).equals(bytes)).toBe(true);
    });

    it('serves a PNG that arrived inside a report as image/png, byte for byte', async () => {
      const png = Buffer.concat([PNG_1X1, Buffer.from('png-in-report')]);
      const result = await submit(
        report({ photos: [{ filename: 'Screenshot_2.png', bytes: png }] }),
      );

      const content = await getContent(foreman.accessToken, await onlyMediaId(result.id)).expect(
        200,
      );

      expect(content.headers['content-type']).toBe('image/png');
      expect(bytesOf(content).equals(png)).toBe(true);
    });

    it('answers Range requests on a voice memo with 206 and Content-Range', async () => {
      const memo = m4a('range-request');
      const result = await submit(
        report({ voiceMemo: { filename: 'memo_range.m4a', bytes: memo } }),
      );
      const mediaId = await onlyMediaId(result.id);

      const head = await getContent(foreman.accessToken, mediaId)
        .set('Range', 'bytes=0-9')
        .expect(206);
      expect(head.headers['content-type']).toBe('audio/mp4');
      expect(head.headers['content-range']).toBe(`bytes 0-9/${memo.length}`);
      expect(head.headers['content-length']).toBe('10');
      expect(bytesOf(head).equals(memo.subarray(0, 10))).toBe(true);

      const tail = await getContent(worker.accessToken, mediaId)
        .set('Range', 'bytes=10-')
        .expect(206);
      expect(tail.headers['content-range']).toBe(`bytes 10-${memo.length - 1}/${memo.length}`);
      expect(bytesOf(tail).equals(memo.subarray(10))).toBe(true);
    });

    it('never trusts the declared type: HTML is stored and served as octet-stream', async () => {
      const html = Buffer.from('<!doctype html><script>alert(document.cookie)</script>');
      const media = await uploadMedia(foreman.accessToken, html, 'page.html', 'text/html');

      expect(media).toMatchObject({ contentType: 'application/octet-stream', kind: 'document' });
      const content = await getContent(foreman.accessToken, media.id).expect(200);
      expect(content.headers['content-type']).toBe('application/octet-stream');
      expect(content.headers['x-content-type-options']).toBe('nosniff');
    });

    it('de-duplicates identical bytes within a company', async () => {
      const bytes = jpeg('dedupe');
      const first = await uploadMedia(foreman.accessToken, bytes, 'a.jpg');
      const second = await uploadMedia(worker.accessToken, bytes, 'b.jpg');
      expect(second.id).toBe(first.id);
    });

    it('records a worker upload against the employee', async () => {
      const media = await uploadMedia(worker.accessToken, jpeg('worker-upload'), 'w.jpg');
      const row = await t.prisma.mediaAsset.findUniqueOrThrow({ where: { id: media.id } });
      expect(row).toMatchObject({ uploadedByEmployeeId: 'e1', uploadedByUserId: null });
    });

    it('rejects a request with no file part, or an empty file', async () => {
      const none = await t.http
        .post('/media')
        .set(bearer(foreman.accessToken))
        .field('note', 'no file here')
        .expect(400);
      expect(errorOf(none)).toMatchObject({ code: 'VALIDATION_FAILED', field: 'file' });

      const empty = await t.http
        .post('/media')
        .set(bearer(foreman.accessToken))
        .attach('file', Buffer.alloc(0), {
          filename: 'empty.jpg',
          contentType: 'application/octet-stream',
        })
        .expect(400);
      expect(errorOf(empty)).toMatchObject({ code: 'VALIDATION_FAILED', field: 'file' });
    });

    it('keeps media inside its tenant', async () => {
      const media = await uploadMedia(foreman.accessToken, jpeg('tenant'), 'tenant.jpg');

      const responses = [
        await t.http.get(`/media/${media.id}`).set(bearer(rival.accessToken)).expect(404),
        await getContent(rival.accessToken, media.id).expect(404),
        await t.http.delete(`/media/${media.id}`).set(bearer(rival.accessToken)).expect(404),
      ];
      for (const res of responses) expect(errorOf(res).code).toBe('NOT_FOUND');

      await t.http.get(`/media/${media.id}`).set(bearer(foreman.accessToken)).expect(200);
    });

    it('signed-url is 501 on the local driver and points at /content instead', async () => {
      const media = await uploadMedia(foreman.accessToken, jpeg('signed'), 'signed.jpg');
      const res = await t.http
        .get(`/media/${media.id}/signed-url`)
        .set(bearer(foreman.accessToken))
        .expect(501);
      expect(errorOf(res).message).toContain('/content');
    });

    it('deletes unreferenced media, after which it is gone', async () => {
      const media = await uploadMedia(foreman.accessToken, jpeg('delete-me'), 'delete.jpg');

      await t.http.delete(`/media/${media.id}`).set(bearer(foreman.accessToken)).expect(204);

      const gone = await t.http
        .get(`/media/${media.id}`)
        .set(bearer(foreman.accessToken))
        .expect(404);
      expect(errorOf(gone).code).toBe('NOT_FOUND');
      await getContent(foreman.accessToken, media.id).expect(404);
      await t.http.delete(`/media/${media.id}`).set(bearer(foreman.accessToken)).expect(404);
    });

    it('refuses to delete media a report still uses, with 409 MEDIA_IN_USE', async () => {
      const result = await submit(
        report({ photos: [{ filename: 'in-use.jpg', bytes: jpeg('in-use') }] }),
      );
      const mediaId = await onlyMediaId(result.id);

      const del = await t.http
        .delete(`/media/${mediaId}`)
        .set(bearer(foreman.accessToken))
        .expect(409);
      expect(errorOf(del).code).toBe('MEDIA_IN_USE');
      await t.http.get(`/media/${mediaId}`).set(bearer(foreman.accessToken)).expect(200);
    });

    it('lets a worker read media but not delete it', async () => {
      const media = await uploadMedia(foreman.accessToken, jpeg('worker-delete'), 'wd.jpg');

      await t.http.get(`/media/${media.id}`).set(bearer(worker.accessToken)).expect(200);
      const del = await t.http
        .delete(`/media/${media.id}`)
        .set(bearer(worker.accessToken))
        .expect(403);
      expect(errorOf(del).code).toBe('FORBIDDEN');
    });
  });

  /**
   * A second app over the same database with a 1 KiB ceiling. Tokens from the
   * main app are valid here: same signing key, same session rows.
   */
  describe('upload limits', () => {
    const LIMIT = 1024;
    let limited: TestApp;

    beforeAll(async () => {
      limited = await createTestApp({ UPLOAD_MAX_FILE_BYTES: LIMIT });
    });

    afterAll(async () => {
      await limited.close();
    });

    /** A JPEG padded to exactly `size` bytes. */
    function jpegOfSize(tag: string, size: number): Buffer {
      const head = jpeg(tag);
      return Buffer.concat([head, Buffer.alloc(size - head.length, 0x20)]);
    }

    it('accepts a file just under the limit', async () => {
      const res = await limited.http
        .post('/media')
        .set(bearer(foreman.accessToken))
        .attach('file', jpegOfSize('under-limit', LIMIT - 1), {
          filename: 'under-limit.jpg',
          contentType: 'application/octet-stream',
        })
        .expect(201);
      expect((res.body as MediaDto).byteSize).toBe(LIMIT - 1);
    });

    // Regression: busboy flags a file once it *reaches* multer's fileSize, so
    // with the same number as the service's `> limit` check the real ceiling
    // was one byte under UPLOAD_MAX_FILE_BYTES.
    it('accepts a file of exactly the limit', async () => {
      const res = await limited.http
        .post('/media')
        .set(bearer(foreman.accessToken))
        .attach('file', jpegOfSize('at-limit', LIMIT), {
          filename: 'at-limit.jpg',
          contentType: 'application/octet-stream',
        })
        .expect(201);
      expect((res.body as MediaDto).byteSize).toBe(LIMIT);
    });

    it('rejects a larger file on /media with 413 PAYLOAD_TOO_LARGE', async () => {
      const res = await limited.http
        .post('/media')
        .set(bearer(foreman.accessToken))
        .attach('file', jpegOfSize('over-limit', LIMIT + 1), {
          filename: 'big.jpg',
          contentType: 'application/octet-stream',
        })
        .expect(413);
      expect(errorOf(res).code).toBe('PAYLOAD_TOO_LARGE');
    });

    it('rejects an oversized report photo with 413 and files no report', async () => {
      const upload = report({
        photos: [{ filename: 'big.jpg', bytes: jpegOfSize('big-report', 4 * LIMIT) }],
      });

      const res = await postReport(limited, worker.accessToken, upload).expect(413);

      expect(errorOf(res).code).toBe('PAYLOAD_TOO_LARGE');
      expect(
        await t.prisma.workerReport.count({ where: { submittedAtRaw: upload.submittedAt } }),
      ).toBe(0);
    });
  });
});
