import { compareWorkerProjects, selectFreshSamples } from './worker-ordering';

const project = (status: string, name: string) => ({ status, name });

describe('compareWorkerProjects', () => {
  it('puts in-progress jobs first, then planned, then done', () => {
    const list = [project('done', 'A'), project('planned', 'B'), project('inProgress', 'C')].sort(
      compareWorkerProjects,
    );

    expect(list.map((p) => p.status)).toEqual(['inProgress', 'planned', 'done']);
  });

  it('breaks ties by name within a status group', () => {
    const list = [
      project('planned', 'Zidarie'),
      project('planned', 'Acoperis'),
      project('inProgress', 'Zugravit'),
    ].sort(compareWorkerProjects);

    expect(list.map((p) => p.name)).toEqual(['Zugravit', 'Acoperis', 'Zidarie']);
  });

  it('orders names by UTF-16 code unit, like Dart', () => {
    // `localeCompare` would file "Șantier" next to "Santier"; Dart's compareTo
    // does not, and the app and the server must agree on one order.
    const list = [project('planned', 'Șantier'), project('planned', 'Tencuiala')].sort(
      compareWorkerProjects,
    );
    expect(list.map((p) => p.name)).toEqual(['Tencuiala', 'Șantier']);
  });

  it('sorts an unknown status last instead of throwing', () => {
    const list = [project('archived', 'X'), project('done', 'Y'), project('inProgress', 'Z')].sort(
      compareWorkerProjects,
    );

    expect(list.map((p) => p.status)).toEqual(['inProgress', 'done', 'archived']);
  });
});

describe('selectFreshSamples', () => {
  const at = (iso: string) => ({ capturedAtDate: new Date(iso) });

  it('keeps every sample when nothing is stored', () => {
    const samples = [at('2026-08-16T08:00:00Z'), at('2026-08-16T08:30:00Z')];
    const result = selectFreshSamples(samples, []);

    expect(result.fresh).toHaveLength(2);
    expect(result.duplicates).toBe(0);
  });

  it('drops samples already stored', () => {
    // The client resends a batch it never saw acknowledged.
    const samples = [at('2026-08-16T08:00:00Z'), at('2026-08-16T08:30:00Z')];
    const result = selectFreshSamples(samples, [new Date('2026-08-16T08:00:00Z').getTime()]);

    expect(result.fresh).toHaveLength(1);
    expect(result.fresh[0]?.capturedAtDate.toISOString()).toBe('2026-08-16T08:30:00.000Z');
    expect(result.duplicates).toBe(1);
  });

  it('drops duplicates within one batch', () => {
    // There is no unique constraint behind this, so a buffered-twice fix would
    // otherwise be written twice.
    const samples = [
      at('2026-08-16T08:00:00Z'),
      at('2026-08-16T08:00:00Z'),
      at('2026-08-16T09:00:00Z'),
    ];
    const result = selectFreshSamples(samples, []);

    expect(result.fresh).toHaveLength(2);
    expect(result.duplicates).toBe(1);
  });

  it('reports a fully redundant batch as all duplicates', () => {
    const samples = [at('2026-08-16T08:00:00Z')];
    const result = selectFreshSamples(samples, [new Date('2026-08-16T08:00:00Z').getTime()]);

    expect(result.fresh).toEqual([]);
    expect(result.duplicates).toBe(1);
  });

  it('treats sub-second differences as distinct fixes', () => {
    const samples = [at('2026-08-16T08:00:00.100Z'), at('2026-08-16T08:00:00.200Z')];
    expect(selectFreshSamples(samples, []).fresh).toHaveLength(2);
  });
});
