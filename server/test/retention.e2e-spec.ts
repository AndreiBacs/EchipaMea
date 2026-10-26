import { createHash } from 'crypto';
import { SchedulerRegistry } from '@nestjs/schedule';
import { RetentionService } from '../src/maintenance/retention.service';
import { createTestApp, type TestApp } from './support/app';
import { bearer, loginForeman, realtimeTicket, type ForemanSession } from './support/auth';
import { resetDb } from './support/db';

const DAY = 24 * 3600_000;
const ago = (ms: number) => new Date(Date.now() - ms);

/**
 * The nightly retention job removes exactly what is past retention and
 * nothing else. Each table gets one row just past its cutoff and one row that
 * must survive, so an over-eager `where` fails as loudly as a missing one.
 */
describe('retention (e2e)', () => {
  let t: TestApp;
  let foreman: ForemanSession;
  let retention: RetentionService;

  beforeAll(async () => {
    t = await createTestApp();
    await resetDb(t.prisma);
    foreman = await loginForeman(t);
    retention = t.app.get(RetentionService);
  });

  afterAll(async () => {
    await t.close();
  });

  it('registers the nightly job, and the job is a no-op while disabled', async () => {
    expect(t.app.get(SchedulerRegistry).getCronJob('retention')).toBeDefined();

    const before = await t.prisma.refreshToken.count();
    await retention.nightly(); // RETENTION_JOBS_ENABLED=false in the e2e environment
    expect(await t.prisma.refreshToken.count()).toBe(before);
  });

  it('prunes each table past its cutoff and keeps everything else', async () => {
    // Location samples: retention is measured on the server's receivedAt, so a
    // phone whose clock says 2020 does not lose a sample received just now.
    const sample = {
      companyId: 'demo-company',
      employeeId: 'e1',
      latitude: 46.77,
      longitude: 23.62,
      accuracyMeters: 5,
    };
    await t.prisma.workerLocationSample.createMany({
      data: [
        { ...sample, capturedAt: new Date(), receivedAt: ago(91 * DAY) },
        { ...sample, capturedAt: new Date('2020-01-01T00:00:00Z'), receivedAt: new Date() },
      ],
    });

    // Refresh tokens: the login above issued one that stays valid.
    const staleSession = await t.http
      .post('/auth/refresh')
      .send({ refreshToken: foreman.refreshToken })
      .expect(200);
    foreman = staleSession.body as ForemanSession;
    const tokensBefore = await t.prisma.refreshToken.count();
    const expiredToken = await t.prisma.refreshToken.findFirstOrThrow({
      where: { companyId: 'demo-company' },
      orderBy: { issuedAt: 'asc' },
    });
    await t.prisma.refreshToken.update({
      where: { id: expiredToken.id },
      data: { expiresAt: ago(8 * DAY) },
    });

    // Worker login tickets and realtime tickets: one long expired, one fresh.
    for (const employeeId of ['e1', 'e2']) {
      await t.http
        .post(`/employees/${employeeId}/login-ticket`)
        .set(bearer(foreman.accessToken))
        .expect(201);
    }
    const oldTicket = await t.prisma.workerLoginTicket.findFirstOrThrow({
      where: { employeeId: 'e1' },
    });
    await t.prisma.workerLoginTicket.update({
      where: { id: oldTicket.id },
      data: { expiresAt: ago(2 * DAY) },
    });

    const spentRealtime = await realtimeTicket(t, foreman.accessToken);
    await realtimeTicket(t, foreman.accessToken);
    await t.prisma.realtimeTicket.updateMany({
      where: { ticketHash: sha256(spentRealtime) },
      data: { expiresAt: ago(7 * 3600_000) },
    });

    // Notifications: only read *and* old goes; unread is kept however old.
    const notification = {
      companyId: 'demo-company',
      recipientUserId: 'foreman_local',
      kind: 'workerArrived' as const,
      payload: {},
      occurredAt: ago(120 * DAY),
    };
    await t.prisma.notification.createMany({
      data: [
        { ...notification, readAt: ago(91 * DAY) },
        { ...notification, readAt: null },
        { ...notification, readAt: ago(DAY) },
      ],
    });

    // Media: an orphan older than a day goes; a fresh orphan may still be about
    // to be attached to a report, so it stays.
    const media = {
      companyId: 'demo-company',
      bucket: 'local',
      kind: 'photo' as const,
      contentType: 'image/jpeg',
      byteSize: 3,
      sha256: 'x',
    };
    await t.prisma.mediaAsset.createMany({
      data: [
        { ...media, storageKey: 'retention/old-orphan', createdAt: ago(2 * DAY) },
        { ...media, storageKey: 'retention/new-orphan' },
      ],
    });

    const report = await retention.runOnce();

    expect(report).toEqual({
      locationSamples: 1,
      refreshTokens: 1,
      workerLoginTickets: 1,
      realtimeTickets: 1,
      unreferencedMedia: 1,
      readNotifications: 1,
    });

    // The survivor is the one *received* recently, despite its 2020 clock.
    const samples = await t.prisma.workerLocationSample.findMany();
    expect(samples.map((s) => s.capturedAt.toISOString())).toEqual(['2020-01-01T00:00:00.000Z']);
    expect(await t.prisma.refreshToken.count()).toBe(tokensBefore - 1);
    expect(await t.prisma.workerLoginTicket.count({ where: { employeeId: 'e2' } })).toBe(1);
    expect(await t.prisma.notification.count()).toBe(2);
    expect(
      await t.prisma.mediaAsset.findUnique({ where: { storageKey: 'retention/new-orphan' } }),
    ).not.toBeNull();

    // A second run finds nothing left to do.
    expect(Object.values(await retention.runOnce()).every((count) => count === 0)).toBe(true);
  });
});

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}
