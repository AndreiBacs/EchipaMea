import type { Response } from 'supertest';
import type { ClientDto } from '../../src/clients/dto/client.dto';
import type { ProjectDto } from '../../src/projects/dto/project.dto';
import type { TestApp } from './app';
import { bearer } from './auth';

/** The `error` member of the standard envelope. */
export interface ApiError {
  code: string;
  message: string;
  field?: string;
}

/**
 * A typed view of a JSON body.
 *
 * supertest types `res.body` as `any`; going through this keeps the specs free
 * of unsafe member access without restating a cast at every call site.
 */
export function body<T>(res: Response): T {
  return res.body as T;
}

export function apiError(res: Response): ApiError {
  return (res.body as { error: ApiError }).error;
}

/**
 * Asserts status, `error.code` and (when given) `error.field` in one
 * comparison, so a failure prints the whole envelope rather than only the
 * first mismatching scalar.
 */
export function expectError(res: Response, status: number, code: string, field?: string): void {
  expect({ status: res.status, body: res.body as unknown }).toMatchObject({
    status,
    body: { error: { code, ...(field === undefined ? {} : { field }) } },
  });
}

/** Any 2xx, failing with the response body rather than a bare status line. */
export function expectSuccess(res: Response): void {
  if (res.status < 200 || res.status >= 300) {
    throw new Error(`Expected a 2xx response, got ${res.status}: ${JSON.stringify(res.body)}`);
  }
}

let sequence = 0;

/** A name no other row in this run carries, so `?q=` searches match exactly one. */
export function uniqueName(prefix: string): string {
  sequence += 1;
  return `${prefix} ${process.pid}-${sequence}`;
}

/** An ISO instant `minutes` from now; negative is the past. */
export function isoFromNow(minutes: number): string {
  return new Date(Date.now() + minutes * 60_000).toISOString();
}

export async function createClient(
  t: TestApp,
  token: string,
  overrides: Record<string, unknown> = {},
): Promise<ClientDto> {
  const res = await t.http
    .post('/clients')
    .set(bearer(token))
    .send({ name: uniqueName('Client'), type: 'company', ...overrides });
  expect(res.status).toBe(201);
  return body<ClientDto>(res);
}

export interface PhaseInput {
  name?: string;
  startDate?: string;
  endDate?: string;
  description?: string;
  assignedEmployeeIds?: string[];
  workInstructions?: { text: string }[];
}

/**
 * Default phase window. Deliberately far from 2026-04-14, the day the
 * sequence tests read, so phases created here never join the seeded day.
 */
export const DEFAULT_PHASE_START = '2026-06-01';
export const DEFAULT_PHASE_END = '2026-06-05';

/** Creates a project (client c2 unless told otherwise) with inline phases. */
export async function createProject(
  t: TestApp,
  token: string,
  input: {
    name?: string;
    clientId?: string;
    assignedEmployeeIds?: string[];
    phases?: PhaseInput[];
  } = {},
): Promise<ProjectDto> {
  const res = await t.http
    .post('/projects')
    .set(bearer(token))
    .send({
      name: input.name ?? uniqueName('Project'),
      clientId: input.clientId ?? 'c2',
      assignedEmployeeIds: input.assignedEmployeeIds ?? [],
      phases: (input.phases ?? []).map((phase, index) => ({
        name: `Phase ${index + 1}`,
        startDate: DEFAULT_PHASE_START,
        endDate: DEFAULT_PHASE_END,
        ...phase,
      })),
    });
  expect(res.status).toBe(201);
  return body<ProjectDto>(res);
}

/** `project.phases[index]`, failing loudly instead of yielding undefined. */
export function phaseAt(project: ProjectDto, index: number): ProjectDto['phases'][number] {
  const phase = project.phases[index];
  if (!phase) throw new Error(`Project ${project.id} has no phase at index ${index}.`);
  return phase;
}
