import { reportIdempotencyKey } from '../common/util/ids';
import { reportFieldsSchema } from '../reports/report-fields.schema';
import { workerLocationFrameSchema, workerReportSubmittedFrameSchema } from './frames';

/** Exactly what `worker_reports_api.dart` puts in both the form and the frame. */
const DART_REPORT = {
  projectId: 'p1',
  projectName: 'Casa Ionescu',
  phaseId: 'p1_phase_1',
  phaseName: 'Turnare fundatie',
  employeeId: 'e1',
  employeeName: 'Andrei D.',
  description: 'Am turnat fundatia',
  // Six fractional digits: what Dart emits on mobile. JS `Date` holds three.
  submittedAt: '2026-08-14T09:12:33.123456Z',
};

const COMPANY = 'company_1';

describe('worker_report_submitted frame', () => {
  it('produces the same idempotency key as the multipart upload', () => {
    // This is the whole dedupe mechanism. The device uploads over HTTP and then
    // announces the same report on the socket; if these two schemas normalised
    // `submittedAt` differently the foreman would be told twice about one
    // report, and the second one would have no attachments.
    const http = reportFieldsSchema.parse(DART_REPORT);
    const ws = workerReportSubmittedFrameSchema.parse({
      type: 'worker_report_submitted',
      ...DART_REPORT,
      photoCount: 2,
      hasVoiceMemo: true,
    });

    const httpKey = reportIdempotencyKey({
      companyId: COMPANY,
      phaseId: http.phaseId,
      employeeId: http.employeeId,
      submittedAtRaw: http.submittedAt,
    });
    const wsKey = reportIdempotencyKey({
      companyId: COMPANY,
      phaseId: ws.phaseId,
      employeeId: ws.employeeId,
      submittedAtRaw: ws.submittedAt,
    });

    expect(wsKey).toBe(httpKey);
  });

  it('keeps the six-digit timestamp verbatim', () => {
    const ws = workerReportSubmittedFrameSchema.parse({
      type: 'worker_report_submitted',
      ...DART_REPORT,
    });
    expect(ws.submittedAt).toBe('2026-08-14T09:12:33.123456Z');
    // Round-tripping through Date would silently drop the last three digits and
    // change the key.
    expect(new Date(ws.submittedAt).toISOString()).not.toBe(ws.submittedAt);
  });

  it('accepts the three-digit web form too', () => {
    const ws = workerReportSubmittedFrameSchema.parse({
      type: 'worker_report_submitted',
      ...DART_REPORT,
      submittedAt: '2026-08-14T09:12:33.123Z',
    });
    expect(ws.submittedAt).toBe('2026-08-14T09:12:33.123Z');
  });

  it('defaults the optional descriptive fields', () => {
    const ws = workerReportSubmittedFrameSchema.parse({
      type: 'worker_report_submitted',
      projectId: 'p1',
      phaseId: 'p1_phase_1',
      employeeId: 'e1',
      submittedAt: DART_REPORT.submittedAt,
    });
    expect(ws.photoCount).toBe(0);
    expect(ws.hasVoiceMemo).toBe(false);
    expect(ws.projectName).toBe('');
  });

  it('does not read the string "false" as true', () => {
    const ws = workerReportSubmittedFrameSchema.parse({
      type: 'worker_report_submitted',
      ...DART_REPORT,
      hasVoiceMemo: 'false',
    });
    expect(ws.hasVoiceMemo).toBe(false);
  });

  it.each([
    ['missing projectId', { phaseId: 'x', submittedAt: DART_REPORT.submittedAt }],
    ['missing phaseId', { projectId: 'p1', submittedAt: DART_REPORT.submittedAt }],
    ['unparseable submittedAt', { projectId: 'p1', phaseId: 'x', submittedAt: 'yesterday' }],
    ['wrong type', { ...DART_REPORT, type: 'something_else' }],
  ])('rejects a frame with %s', (_label, partial) => {
    const result = workerReportSubmittedFrameSchema.safeParse({
      type: 'worker_report_submitted',
      ...partial,
    });
    expect(result.success).toBe(false);
  });
});

describe('worker_location frame', () => {
  const VALID = {
    type: 'worker_location',
    employeeId: 'e1',
    employeeName: 'Andrei D.',
    latitude: 46.7712,
    longitude: 23.6236,
    accuracyMeters: 12.5,
    capturedAt: '2026-08-14T09:12:33.123456Z',
  };

  it('accepts what the telemetry coordinator sends', () => {
    const frame = workerLocationFrameSchema.parse(VALID);
    expect(frame.latitude).toBeCloseTo(46.7712);
    expect(frame.accuracyMeters).toBeCloseTo(12.5);
  });

  it('defaults a missing accuracy rather than rejecting the fix', () => {
    // Some Android devices report no accuracy. A usable position should not be
    // thrown away over a missing quality estimate.
    const { accuracyMeters: _omitted, ...withoutAccuracy } = VALID;
    const frame = workerLocationFrameSchema.parse(withoutAccuracy);
    expect(frame.accuracyMeters).toBe(0);
  });

  it.each([
    ['latitude above 90', { ...VALID, latitude: 91 }],
    ['latitude below -90', { ...VALID, latitude: -91 }],
    ['longitude above 180', { ...VALID, longitude: 181 }],
    ['negative accuracy', { ...VALID, accuracyMeters: -1 }],
    ['NaN latitude', { ...VALID, latitude: Number.NaN }],
    ['a string latitude', { ...VALID, latitude: '46.7' }],
    ['unparseable capturedAt', { ...VALID, capturedAt: 'now' }],
  ])('rejects %s', (_label, frame) => {
    // The database has matching CHECK constraints; rejecting here means the
    // client gets an error frame instead of a 500 from a constraint violation.
    expect(workerLocationFrameSchema.safeParse(frame).success).toBe(false);
  });
});
