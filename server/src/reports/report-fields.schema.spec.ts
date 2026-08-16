import { collectPhotoNames, flattenBody, reportFieldsSchema } from './report-fields.schema';

describe('collectPhotoNames', () => {
  it('collects indexed fields in positional order', () => {
    expect(
      collectPhotoNames({
        'photoNames[0]': 'a.jpg',
        'photoNames[1]': 'b.jpg',
        'photoNames[2]': 'c.jpg',
      }),
    ).toEqual(['a.jpg', 'b.jpg', 'c.jpg']);
  });

  it('ignores insertion order and sorts by index', () => {
    expect(
      collectPhotoNames({
        'photoNames[2]': 'c.jpg',
        'photoNames[0]': 'a.jpg',
        'photoNames[1]': 'b.jpg',
      }),
    ).toEqual(['a.jpg', 'b.jpg', 'c.jpg']);
  });

  it('fills gaps rather than shifting later names out of alignment', () => {
    // A missing name must not make photo 2 inherit photo 1's label.
    expect(collectPhotoNames({ 'photoNames[0]': 'a.jpg', 'photoNames[2]': 'c.jpg' })).toEqual([
      'a.jpg',
      '',
      'c.jpg',
    ]);
  });

  it('ignores unrelated and malformed keys', () => {
    expect(
      collectPhotoNames({
        projectId: 'p1',
        photoNames: 'not-indexed',
        'photoNames[x]': 'bad',
        'photoNames[-1]': 'bad',
        'photoNames[0]': 'a.jpg',
      }),
    ).toEqual(['a.jpg']);
  });

  it('returns empty when there are no photo names', () => {
    expect(collectPhotoNames({ projectId: 'p1' })).toEqual([]);
  });
});

describe('flattenBody', () => {
  it('takes the first value when a parser yields arrays', () => {
    expect(flattenBody({ projectId: ['p1', 'p2'], phaseId: 'ph1' })).toEqual({
      projectId: 'p1',
      phaseId: 'ph1',
    });
  });
});

describe('reportFieldsSchema', () => {
  const valid = {
    projectId: 'p1',
    projectName: 'Renovation',
    phaseId: 'p1_phase_1',
    phaseName: 'Demolition',
    employeeId: 'e1',
    employeeName: 'Andrei D.',
    description: 'Finished the wiring',
    submittedAt: '2026-08-14T09:12:33.123456Z',
  };

  it('accepts the mobile 6-fraction-digit timestamp', () => {
    expect(reportFieldsSchema.parse(valid).submittedAt).toBe('2026-08-14T09:12:33.123456Z');
  });

  it('accepts the web 3-fraction-digit timestamp', () => {
    const parsed = reportFieldsSchema.parse({ ...valid, submittedAt: '2026-08-14T09:12:33.123Z' });
    expect(parsed.submittedAt).toBe('2026-08-14T09:12:33.123Z');
  });

  it('accepts a timestamp with no fractional part', () => {
    expect(() =>
      reportFieldsSchema.parse({ ...valid, submittedAt: '2026-08-14T09:12:33Z' }),
    ).not.toThrow();
  });

  it('accepts an offset instead of Z', () => {
    expect(() =>
      reportFieldsSchema.parse({ ...valid, submittedAt: '2026-08-14T12:12:33+03:00' }),
    ).not.toThrow();
  });

  it('rejects a non-timestamp', () => {
    expect(() => reportFieldsSchema.parse({ ...valid, submittedAt: 'yesterday' })).toThrow();
  });

  it('requires projectId and phaseId', () => {
    expect(() => reportFieldsSchema.parse({ ...valid, projectId: '' })).toThrow();
    expect(() => reportFieldsSchema.parse({ ...valid, phaseId: '' })).toThrow();
  });

  it('defaults the optional descriptive fields', () => {
    const parsed = reportFieldsSchema.parse({
      projectId: 'p1',
      phaseId: 'ph1',
      submittedAt: '2026-08-14T09:12:33.123Z',
    });
    expect(parsed.description).toBe('');
    expect(parsed.employeeName).toBe('');
  });
});
