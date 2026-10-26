import type { Response } from 'supertest';
import type { ClientDto } from '../src/clients/dto/client.dto';
import type { Paged } from '../src/common/dto/page.dto';
import type { CompanyDto, ForemanProfileDto } from '../src/company/dto/company.dto';
import type { EmployeeDto } from '../src/employees/dto/employee.dto';
import type { PhaseReportSummaryDto } from '../src/phases/dto/phase.dto';
import type { ProjectDto, ProjectPhaseDto } from '../src/projects/dto/project.dto';
import type { DailyWorkerSequenceDto, DaySequencesDto } from '../src/sequences/dto/sequence.dto';
import { createTestApp, type TestApp } from './support/app';
import { bearer, loginForeman, workerSession } from './support/auth';
import { resetDb } from './support/db';
import {
  apiError,
  body,
  createClient,
  createProject,
  expectError,
  expectSuccess,
  phaseAt,
  uniqueName,
} from './support/domain-helpers';

/**
 * Foreman-side business rules: the values the API derives instead of storing,
 * the phase state machine, ordering, sequences and the partial-update
 * contracts.
 *
 * One app and one foreman login for the whole file (login is throttled to 5 a
 * minute). Tests that move phases or delete rows build their own project or
 * client rather than touching the seeded p1/p2/p3, so the seeded derivations
 * read at the top stay true for every test that relies on them.
 */
describe('domain (e2e)', () => {
  let t: TestApp;
  let token: string;
  let auth: { Authorization: string };
  /** e1's worker session, for the paths where the token decides who acted. */
  let workerE1: string;

  beforeAll(async () => {
    t = await createTestApp();
    await resetDb(t.prisma);
    token = (await loginForeman(t)).accessToken;
    auth = bearer(token);
    workerE1 = (await workerSession(t, token, 'e1')).accessToken;
  });

  afterAll(async () => {
    await t.close();
  });

  async function getProject(projectId: string): Promise<ProjectDto> {
    return body<ProjectDto>(await t.http.get(`/projects/${projectId}`).set(auth).expect(200));
  }

  /** POST to a phase action as the foreman (or `as`), expecting success. */
  async function phaseAction(
    phase: { projectId: string; phaseId: string },
    action: 'start' | 'submit' | 'review',
    payload: Record<string, unknown> = {},
    as: { Authorization: string } = auth,
  ): Promise<Response> {
    const res = await t.http
      .post(`/projects/${phase.projectId}/phases/${phase.phaseId}/${action}`)
      .set(as)
      .send(payload);
    expectSuccess(res);
    return res;
  }

  function phaseRef(project: ProjectDto, index: number): { projectId: string; phaseId: string } {
    return { projectId: project.id, phaseId: phaseAt(project, index).id };
  }

  // -------------------------------------------------------------------------
  describe('clients', () => {
    async function activeProjectsOf(clientId: string): Promise<number> {
      const res = await t.http.get(`/clients/${clientId}`).set(auth).expect(200);
      return body<ClientDto>(res).activeProjects;
    }

    it('derives activeProjects from the projects table instead of storing it', async () => {
      // The Flutter seed claimed c1=2 and c3=1. The truth: c1 and c2 have one
      // live project each, and c3's only project (p3) is done.
      expect(await activeProjectsOf('c1')).toBe(1);
      expect(await activeProjectsOf('c2')).toBe(1);
      expect(await activeProjectsOf('c3')).toBe(0);
    });

    it('creates, reads, partially updates, lists and deletes a client', async () => {
      const name = uniqueName('Client');
      const created = await t.http
        .post('/clients')
        .set(auth)
        .send({
          name,
          type: 'company',
          status: 'inactive',
          preferredContactMethod: 'email',
          notes: 'Gate code 1234.',
          email: 'ops@example.com',
          phone: '+40 700 000 001',
          // Accepted for compatibility and ignored: the value is derived.
          activeProjects: 42,
        })
        .expect(201);
      const client = body<ClientDto>(created);
      expect(client).toMatchObject({
        name,
        type: 'company',
        status: 'inactive',
        preferredContactMethod: 'email',
        activeProjects: 0,
      });

      const fetched = await t.http.get(`/clients/${client.id}`).set(auth).expect(200);
      expect(body<ClientDto>(fetched)).toEqual(client);

      // Only `phone` is sent. The update schema is the create schema made
      // partial, and the create schema carries defaults (status, notes,
      // contact method); re-applying them here would quietly reset those.
      const patched = await t.http
        .patch(`/clients/${client.id}`)
        .set(auth)
        .send({ phone: '+40 700 000 002' })
        .expect(200);
      expect(body<ClientDto>(patched)).toEqual({
        ...client,
        phone: '+40 700 000 002',
        updatedAt: expect.any(String) as unknown,
      });

      const listed = await t.http.get('/clients').query({ q: name }).set(auth).expect(200);
      expect(body<Paged<ClientDto>>(listed).items.map((c) => c.id)).toContain(client.id);

      await t.http.delete(`/clients/${client.id}`).set(auth).expect(204);

      expectError(await t.http.get(`/clients/${client.id}`).set(auth), 404, 'NOT_FOUND');
      const after = await t.http.get('/clients').query({ q: name }).set(auth).expect(200);
      expect(body<Paged<ClientDto>>(after).items.map((c) => c.id)).not.toContain(client.id);
    });

    it('refuses to delete a client that still has projects, until they are gone', async () => {
      expectError(await t.http.delete('/clients/c1').set(auth), 409, 'CLIENT_HAS_PROJECTS');
      // A finished project still references its client, so c3 (whose only
      // project is done) is refused too: only deleting the project frees it.
      expectError(await t.http.delete('/clients/c3').set(auth), 409, 'CLIENT_HAS_PROJECTS');
      await t.http.get('/clients/c1').set(auth).expect(200);

      const client = await createClient(t, token);
      const project = await createProject(t, token, { clientId: client.id });
      expectError(
        await t.http.delete(`/clients/${client.id}`).set(auth),
        409,
        'CLIENT_HAS_PROJECTS',
      );

      await t.http.delete(`/projects/${project.id}`).set(auth).expect(204);
      await t.http.delete(`/clients/${client.id}`).set(auth).expect(204);
    });

    it('activeProjects follows the derived project status', async () => {
      const client = await createClient(t, token);
      const project = await createProject(t, token, { clientId: client.id, phases: [{}] });
      expect(await activeProjectsOf(client.id)).toBe(1);

      expectSuccess(await t.http.post(`/projects/${project.id}/done`).set(auth));
      expect(await activeProjectsOf(client.id)).toBe(0);

      expectSuccess(await t.http.post(`/projects/${project.id}/reopen`).set(auth));
      expect(await activeProjectsOf(client.id)).toBe(1);
    });
  });

  // -------------------------------------------------------------------------
  describe('employees', () => {
    it('creates, reads, partially updates and soft-deletes an employee', async () => {
      const name = uniqueName('Employee');
      const created = await t.http
        .post('/employees')
        .set(auth)
        .send({
          name,
          role: 'carpenter',
          phone: '+40 700 111 222',
          workStartHour: 8,
          workEndHour: 17,
          workingDays: [5, 1, 3, 3],
        })
        .expect(201);
      const employee = body<EmployeeDto>(created);
      // Weekdays are stored in one canonical form: de-duplicated and sorted.
      expect(employee).toMatchObject({
        name,
        role: 'carpenter',
        email: '',
        workingDays: [1, 3, 5],
        latitude: null,
        longitude: null,
        isActive: true,
      });

      const fetched = await t.http.get(`/employees/${employee.id}`).set(auth).expect(200);
      expect(body<EmployeeDto>(fetched)).toEqual(employee);

      const patched = await t.http
        .patch(`/employees/${employee.id}`)
        .set(auth)
        .send({ workEndHour: 15 })
        .expect(200);
      expect(body<EmployeeDto>(patched)).toEqual({
        ...employee,
        workEndHour: 15,
        updatedAt: expect.any(String) as unknown,
      });

      await t.http.delete(`/employees/${employee.id}`).set(auth).expect(204);
      expectError(await t.http.get(`/employees/${employee.id}`).set(auth), 404, 'NOT_FOUND');
      const listed = await t.http.get('/employees').query({ q: name }).set(auth).expect(200);
      expect(body<Paged<EmployeeDto>>(listed).items).toEqual([]);
    });

    it('re-checks the zero-length-shift rule against the merged record on PATCH', async () => {
      // e1 works 7-16. `workEndHour: 7` is valid on its own; it only describes
      // a zero-length shift once merged with the stored start hour.
      expectError(
        await t.http.patch('/employees/e1').set(auth).send({ workEndHour: 7 }),
        400,
        'VALIDATION_FAILED',
        'workEndHour',
      );
      const e1 = await t.http.get('/employees/e1').set(auth).expect(200);
      expect(body<EmployeeDto>(e1)).toMatchObject({ workStartHour: 7, workEndHour: 16 });
    });

    it('deactivates with isActive:false, keeping the row and ending the worker session', async () => {
      const created = await t.http
        .post('/employees')
        .set(auth)
        .send({
          name: uniqueName('Leaver'),
          role: 'helper',
          workStartHour: 8,
          workEndHour: 16,
          workingDays: [1, 2, 3, 4, 5],
        })
        .expect(201);
      const employee = body<EmployeeDto>(created);
      // The worker token is not used before deactivation on purpose: a warm
      // principal cache may serve a deactivated employee for up to 5s by design
      // (principal-cache.ts). This checks the session revocation itself.
      const worker = await workerSession(t, token, employee.id);

      const patched = await t.http
        .patch(`/employees/${employee.id}`)
        .set(auth)
        .send({ isActive: false })
        .expect(200);
      expect(body<EmployeeDto>(patched)).toMatchObject({ id: employee.id, isActive: false });

      // Deactivated, not deleted: still readable, and listed among the inactive.
      await t.http.get(`/employees/${employee.id}`).set(auth).expect(200);
      const inactive = await t.http.get('/employees').query({ active: 'false' }).set(auth);
      expect(body<Paged<EmployeeDto>>(inactive).items.map((e) => e.id)).toContain(employee.id);
      const active = await t.http.get('/employees').query({ active: 'true' }).set(auth);
      expect(body<Paged<EmployeeDto>>(active).items.map((e) => e.id)).not.toContain(employee.id);

      expectError(
        await t.http.get('/worker/me').set(bearer(worker.accessToken)),
        401,
        'TOKEN_INVALID',
      );
    });
  });

  // -------------------------------------------------------------------------
  describe('projects', () => {
    it('derives status and workers on create, ignoring the values sent', async () => {
      const res = await t.http
        .post('/projects')
        .set(auth)
        .send({
          name: uniqueName('Project'),
          clientId: 'c2',
          status: 'done',
          workers: ['Should Be Ignored'],
          assignedEmployeeIds: ['e3', 'e1'],
          phases: [
            {
              name: 'Survey',
              startDate: '2026-06-01',
              endDate: '2026-06-02',
              assignedEmployeeIds: ['e2'],
            },
          ],
        })
        .expect(201);
      const project = body<ProjectDto>(res);

      expect(project.status).toBe('planned');
      expect(project.closedAt).toBeNull();
      // Names of the project-level assignees, sorted by name. The server builds
      // `workers` from `assignedEmployeeIds`, which the app's project form
      // computes from the phases before saving
      // (project_form_page.dart `_deriveProjectAssignmentsFromPhases`); it does
      // not fold phase-only assignees (e2 here) in by itself.
      expect(project.workers).toEqual(['Andrei D.', 'Ioana R.']);
      expect(project.assignedEmployeeIds).toEqual(['e1', 'e3']);
      expect(phaseAt(project, 0)).toMatchObject({
        name: 'Survey',
        status: 'notStarted',
        startDate: '2026-06-01',
        endDate: '2026-06-02',
        assignedEmployeeIds: ['e2'],
        submittedAt: null,
        submittedByEmployeeIds: [],
        reviewedAt: null,
      });
    });

    it('PATCH replaces assignments only when they are sent, and ignores status', async () => {
      const project = await createProject(t, token, {
        assignedEmployeeIds: ['e1', 'e2'],
        phases: [{}],
      });

      const renamed = await t.http
        .patch(`/projects/${project.id}`)
        .set(auth)
        .send({ name: `${project.name} (renamed)` })
        .expect(200);
      expect(body<ProjectDto>(renamed).assignedEmployeeIds).toEqual(['e1', 'e2']);

      const reassigned = await t.http
        .patch(`/projects/${project.id}`)
        .set(auth)
        .send({ assignedEmployeeIds: ['e3'] })
        .expect(200);
      expect(body<ProjectDto>(reassigned)).toMatchObject({
        assignedEmployeeIds: ['e3'],
        workers: ['Ioana R.'],
      });

      // `status` is accepted for compatibility and ignored: it is derived.
      const forced = await t.http
        .patch(`/projects/${project.id}`)
        .set(auth)
        .send({ status: 'done', workers: ['Nobody'] })
        .expect(200);
      expect(body<ProjectDto>(forced)).toMatchObject({ status: 'planned', workers: ['Ioana R.'] });
    });

    it('moves project status only through its phases', async () => {
      const project = await createProject(t, token, {
        phases: [{ assignedEmployeeIds: ['e1'] }, { assignedEmployeeIds: ['e1'] }],
      });
      const first = phaseRef(project, 0);
      const second = phaseRef(project, 1);
      expect(project.status).toBe('planned');

      await phaseAction(first, 'start');
      expect((await getProject(project.id)).status).toBe('inProgress');

      await phaseAction(first, 'submit', { employeeId: 'e1' });
      const firstApproved = await phaseAction(first, 'review', { approved: true });
      // Review returns the whole project: one phase done, one not started.
      expect(body<ProjectDto>(firstApproved).status).toBe('inProgress');

      // A phase may be submitted straight from notStarted.
      await phaseAction(second, 'submit', { employeeId: 'e1' });
      const secondApproved = await phaseAction(second, 'review', { approved: true });
      expect(body<ProjectDto>(secondApproved)).toMatchObject({
        status: 'done',
        closedAt: null,
      });

      const done = await t.http.get('/projects').query({ status: 'done' }).set(auth).expect(200);
      expect(body<Paged<ProjectDto>>(done).items.map((p) => p.id)).toContain(project.id);
    });

    it('POST /done overrides without touching phases; /reopen restores the derived status', async () => {
      const project = await createProject(t, token, { phases: [{}, {}] });

      const closed = await t.http.post(`/projects/${project.id}/done`).set(auth);
      expectSuccess(closed);
      expect(body<ProjectDto>(closed)).toMatchObject({
        status: 'done',
        closedAt: expect.any(String) as unknown,
      });
      expect(body<ProjectDto>(closed).phases.map((p) => p.status)).toEqual([
        'notStarted',
        'notStarted',
      ]);

      const reopened = await t.http.post(`/projects/${project.id}/reopen`).set(auth);
      expectSuccess(reopened);
      expect(body<ProjectDto>(reopened)).toMatchObject({ status: 'planned', closedAt: null });

      // Reopening restores whatever the phases say now, not a remembered value.
      await phaseAction(phaseRef(project, 0), 'start');
      expectSuccess(await t.http.post(`/projects/${project.id}/done`).set(auth));
      const reopenedAgain = await t.http.post(`/projects/${project.id}/reopen`).set(auth);
      expect(body<ProjectDto>(reopenedAgain).status).toBe('inProgress');
    });

    // Regression: these POST actions create nothing and are documented as 200
    // by their own @ApiOkResponse, but lacked @HttpCode and so answered with
    // Nest's POST default, 201.
    it('answers 200, as documented, for POST actions that create nothing', async () => {
      const project = await createProject(t, token, { phases: [{}, {}] });
      const [first, second] = [phaseRef(project, 0), phaseRef(project, 1)];
      const base = `/projects/${project.id}`;
      const phase = (ref: { phaseId: string }) => `${base}/phases/${ref.phaseId}`;

      const statuses = {
        start: (await t.http.post(`${phase(first)}/start`).set(auth)).status,
        submit: (
          await t.http
            .post(`${phase(first)}/submit`)
            .set(auth)
            .send({ employeeId: 'e1' })
        ).status,
        review: (
          await t.http
            .post(`${phase(first)}/review`)
            .set(auth)
            .send({ approved: true })
        ).status,
        reorder: (
          await t.http
            .post(`${base}/phases/reorder`)
            .set(auth)
            .send({ phaseIds: [second.phaseId, first.phaseId] })
        ).status,
        done: (await t.http.post(`${base}/done`).set(auth)).status,
        reopen: (await t.http.post(`${base}/reopen`).set(auth)).status,
      };

      expect(statuses).toEqual({
        start: 200,
        submit: 200,
        review: 200,
        reorder: 200,
        done: 200,
        reopen: 200,
      });
    });
  });

  // -------------------------------------------------------------------------
  describe('phase lifecycle (strict transitions)', () => {
    let project: ProjectDto;
    let a: { projectId: string; phaseId: string };
    let b: { projectId: string; phaseId: string };

    beforeEach(async () => {
      project = await createProject(t, token, {
        phases: [
          { name: 'A', assignedEmployeeIds: ['e1'] },
          { name: 'B', assignedEmployeeIds: ['e1'] },
        ],
      });
      a = phaseRef(project, 0);
      b = phaseRef(project, 1);
    });

    async function phase(ref: { projectId: string; phaseId: string }): Promise<ProjectPhaseDto> {
      const res = await t.http
        .get(`/projects/${ref.projectId}/phases/${ref.phaseId}`)
        .set(auth)
        .expect(200);
      return body<ProjectPhaseDto>(res);
    }

    function attempt(
      ref: { projectId: string; phaseId: string },
      action: 'start' | 'submit' | 'review',
      payload: Record<string, unknown> = {},
    ) {
      return t.http
        .post(`/projects/${ref.projectId}/phases/${ref.phaseId}/${action}`)
        .set(auth)
        .send(payload);
    }

    it('walks notStarted -> inProgress -> pendingReview -> done, with a rejection between', async () => {
      const started = await phaseAction(a, 'start');
      expect(body<ProjectPhaseDto>(started).status).toBe('inProgress');

      const submitted = await phaseAction(a, 'submit', { employeeId: 'e1' });
      expect(body<ProjectPhaseDto>(submitted)).toMatchObject({
        status: 'pendingReview',
        submittedByEmployeeIds: ['e1'],
        submittedAt: expect.any(String) as unknown,
      });

      // Rejection sends the work back to inProgress, not to notStarted.
      const rejected = await phaseAction(a, 'review', {
        approved: false,
        reviewNotes: 'Redo the corner.',
      });
      expect(body<ProjectDto>(rejected).phases.find((p) => p.id === a.phaseId)).toMatchObject({
        status: 'inProgress',
        reviewNotes: 'Redo the corner.',
        reviewedByForemanId: 'foreman_local',
        reviewedAt: expect.any(String) as unknown,
      });

      await phaseAction(a, 'submit', { employeeId: 'e1' });
      await phaseAction(a, 'review', { approved: true });
      expect(await phase(a)).toMatchObject({ status: 'done', reviewNotes: null });
    });

    it('refuses illegal moves with 409 PHASE_INVALID_TRANSITION and records nothing', async () => {
      // Review needs a submission to review.
      expectError(
        await attempt(b, 'review', { approved: true }),
        409,
        'PHASE_INVALID_TRANSITION',
        'status',
      );
      expectError(await attempt(b, 'review', { approved: false }), 409, 'PHASE_INVALID_TRANSITION');

      await phaseAction(a, 'start');
      expectError(await attempt(a, 'start'), 409, 'PHASE_INVALID_TRANSITION');
      expectError(await attempt(a, 'review', { approved: true }), 409, 'PHASE_INVALID_TRANSITION');

      await phaseAction(a, 'submit', { employeeId: 'e1' });
      await phaseAction(a, 'review', { approved: true });
      // A done phase takes no more work: not a submission, not a restart.
      expectError(
        await attempt(a, 'submit', { employeeId: 'e1' }),
        409,
        'PHASE_INVALID_TRANSITION',
      );
      expectError(await attempt(a, 'start'), 409, 'PHASE_INVALID_TRANSITION');

      // The refusals wrote no review or submission rows on the side.
      expect(await phase(b)).toMatchObject({ status: 'notStarted', reviewedAt: null });
      expect(await t.prisma.phaseReview.count({ where: { phaseId: b.phaseId } })).toBe(0);
      expect(await t.prisma.phaseSubmission.count({ where: { phaseId: a.phaseId } })).toBe(1);
      expect(await phase(a)).toMatchObject({ status: 'done' });
    });

    it('treats a second submission before review as normal, not an error', async () => {
      // Phases span days and workers report daily, so pendingReview -> submit
      // is allowed. (The route's OpenAPI description still says it 409s
      // "unless the phase is notStarted or inProgress"; the code and the
      // lifecycle comment both say otherwise.)
      await phaseAction(a, 'submit', { employeeId: 'e1' });
      const again = await phaseAction(a, 'submit', { employeeId: 'e2' });
      expect(body<ProjectPhaseDto>(again)).toMatchObject({
        status: 'pendingReview',
        submittedByEmployeeIds: ['e1', 'e2'],
      });
    });

    it('takes the submitter from a worker token, never from the body', async () => {
      const res = await phaseAction(a, 'submit', { employeeId: 'e2' }, bearer(workerE1));
      expect(body<ProjectPhaseDto>(res).submittedByEmployeeIds).toEqual(['e1']);
    });

    it('requires employeeId when a foreman submits on a worker’s behalf', async () => {
      expectError(await attempt(a, 'submit'), 400, 'VALIDATION_FAILED', 'employeeId');
      expect((await phase(a)).status).toBe('notStarted');
    });

    it('lets the same illegal move through when PHASE_TRANSITIONS_LENIENT is on', async () => {
      expectError(await attempt(b, 'review', { approved: true }), 409, 'PHASE_INVALID_TRANSITION');

      const lenient = await createTestApp({ PHASE_TRANSITIONS_LENIENT: true });
      try {
        // Same database and JWT secret, so the strict app's token works here.
        const res = await lenient.http
          .post(`/projects/${b.projectId}/phases/${b.phaseId}/review`)
          .set(auth)
          .send({ approved: true });
        expectSuccess(res);
        expect(body<ProjectDto>(res).phases.find((p) => p.id === b.phaseId)?.status).toBe('done');
      } finally {
        await lenient.close();
      }
    });
  });

  // -------------------------------------------------------------------------
  describe('phase ordering', () => {
    function names(phases: ProjectPhaseDto[]): string[] {
      return phases.map((p) => p.name);
    }

    it('reorders by full permutation and appends new phases at the end', async () => {
      const project = await createProject(t, token, {
        phases: [{ name: 'A' }, { name: 'B' }, { name: 'C' }],
      });
      const [a, b, c] = [0, 1, 2].map((i) => phaseAt(project, i).id) as [string, string, string];

      const reordered = await t.http
        .post(`/projects/${project.id}/phases/reorder`)
        .set(auth)
        .send({ phaseIds: [c, a, b] });
      expectSuccess(reordered);
      expect(names(body<ProjectPhaseDto[]>(reordered))).toEqual(['C', 'A', 'B']);
      expect(names((await getProject(project.id)).phases)).toEqual(['C', 'A', 'B']);

      // Deleting keeps the ordering dense, so the next phase lands last rather
      // than colliding with an existing index.
      await t.http.delete(`/projects/${project.id}/phases/${a}`).set(auth).expect(204);
      await t.http
        .post(`/projects/${project.id}/phases`)
        .set(auth)
        .send({ name: 'D', startDate: '2026-06-08', endDate: '2026-06-09' })
        .expect(201);
      expect(names((await getProject(project.id)).phases)).toEqual(['C', 'B', 'D']);
    });

    it('rejects anything but a full permutation and leaves the order alone', async () => {
      const project = await createProject(t, token, {
        phases: [{ name: 'A' }, { name: 'B' }, { name: 'C' }],
      });
      const [a, b, c] = [0, 1, 2].map((i) => phaseAt(project, i).id) as [string, string, string];
      const reorder = (phaseIds: string[]) =>
        t.http.post(`/projects/${project.id}/phases/reorder`).set(auth).send({ phaseIds });

      for (const phaseIds of [
        [c, a], // missing one
        [c, a, b, 'no-such-phase'], // unknown id
        [c, c, a, b], // duplicate
        [c, a, 'p1_phase_1'], // a phase of another project, standing in for b
      ]) {
        expectError(await reorder(phaseIds), 400, 'VALIDATION_FAILED', 'phaseIds');
      }

      expect(names((await getProject(project.id)).phases)).toEqual(['A', 'B', 'C']);
    });
  });

  // -------------------------------------------------------------------------
  describe('phase reports', () => {
    it('lists the reports filed against a phase, newest first', async () => {
      const project = await createProject(t, token, {
        phases: [{ name: 'Slab', assignedEmployeeIds: ['e1'] }],
      });
      const slab = phaseAt(project, 0);
      const reportsUrl = `/projects/${project.id}/phases/${slab.id}/reports`;

      expect(
        body<PhaseReportSummaryDto[]>(await t.http.get(reportsUrl).set(auth).expect(200)),
      ).toEqual([]);

      for (const [submittedAt, description] of [
        ['2026-06-01T15:00:00.000Z', 'Formwork up.'],
        ['2026-06-02T15:00:00.000Z', 'Slab poured.'],
      ] as const) {
        await t.http
          .post('/worker/reports')
          .set(bearer(workerE1))
          .field('projectId', project.id)
          .field('projectName', project.name)
          .field('phaseId', slab.id)
          .field('phaseName', slab.name)
          // Ignored: the worker token says who filed it.
          .field('employeeId', 'e2')
          .field('employeeName', '')
          .field('description', description)
          .field('submittedAt', submittedAt)
          .expect(201);
      }

      const reports = body<PhaseReportSummaryDto[]>(
        await t.http.get(reportsUrl).set(auth).expect(200),
      );
      expect(reports.map((r) => r.description)).toEqual(['Slab poured.', 'Formwork up.']);
      expect(reports[0]).toMatchObject({
        employeeId: 'e1',
        employeeName: 'Andrei D.',
        submittedAt: '2026-06-02T15:00:00.000Z',
        photoCount: 0,
        hasVoiceMemo: false,
        photoUrls: [],
        voiceMemoUrl: null,
      });
    });

    it('404s for a phase that does not belong to the project in the path', async () => {
      expectError(
        await t.http.get('/projects/p1/phases/p2_phase_1/reports').set(auth),
        404,
        'NOT_FOUND',
      );
    });
  });

  // -------------------------------------------------------------------------
  describe('sequences', () => {
    // p1_phase_1 (e1) runs 04-13..16, p1_phase_2 (e1) 04-17..24, and
    // p2_phase_1 (e3) 04-14..15, so on the 14th e1 and e3 each have one phase.
    const day = '2026-04-14';
    const url = (projectId: string, workerId: string) =>
      `/projects/${projectId}/workers/${workerId}/sequence?day=${day}`;

    async function read(projectId: string, workerId: string): Promise<DailyWorkerSequenceDto> {
      const res = await t.http.get(url(projectId, workerId)).set(auth).expect(200);
      return body<DailyWorkerSequenceDto>(res);
    }

    afterEach(async () => {
      await t.http.delete(url('p1', 'e1')).set(auth).expect(204);
    });

    it('never 404s for a missing manual order: it serves the suggestion instead', async () => {
      expect(await read('p1', 'e1')).toEqual({
        projectId: 'p1',
        workerId: 'e1',
        dayKey: day,
        orderedPhaseIds: ['p1_phase_1'],
        suggestedPhaseIds: ['p1_phase_1'],
        isManual: false,
      });

      // Nothing to do that day is an empty sequence, not an error.
      expect(await read('p1', 'e2')).toMatchObject({
        orderedPhaseIds: [],
        suggestedPhaseIds: [],
        isManual: false,
      });

      // 404 is reserved for a project or worker that does not exist.
      expectError(await t.http.get(url('no-such-project', 'e1')).set(auth), 404, 'NOT_FOUND');
      expectError(await t.http.get(url('p1', 'no-such-worker')).set(auth), 404, 'NOT_FOUND');
    });

    it('saves a manual order, serves it back, and resets to the suggestion', async () => {
      // p1_phase_2 does not start until the 17th. Saved ids must belong to the
      // project but need not match the suggestion: the foreman may pull work
      // forward.
      const saved = await t.http
        .put(url('p1', 'e1'))
        .set(auth)
        .send({ orderedPhaseIds: ['p1_phase_2', 'p1_phase_1'] })
        .expect(200);
      const manual = {
        projectId: 'p1',
        workerId: 'e1',
        dayKey: day,
        orderedPhaseIds: ['p1_phase_2', 'p1_phase_1'],
        suggestedPhaseIds: ['p1_phase_1'],
        isManual: true,
      };
      expect(body<DailyWorkerSequenceDto>(saved)).toEqual(manual);
      expect(await read('p1', 'e1')).toEqual(manual);

      await t.http.delete(url('p1', 'e1')).set(auth).expect(204);
      expect(await read('p1', 'e1')).toMatchObject({
        orderedPhaseIds: ['p1_phase_1'],
        isManual: false,
      });
      // Idempotent: resetting with no override in place is still a 204.
      await t.http.delete(url('p1', 'e1')).set(auth).expect(204);
    });

    it('refuses a phase from another project with 409 SEQUENCE_PHASE_MISMATCH', async () => {
      expectError(
        await t.http
          .put(url('p1', 'e1'))
          .set(auth)
          .send({ orderedPhaseIds: ['p1_phase_1', 'p2_phase_1'] }),
        409,
        'SEQUENCE_PHASE_MISMATCH',
        'orderedPhaseIds',
      );
      expect((await read('p1', 'e1')).isManual).toBe(false);
    });

    it('serves the whole day in one read, and one worker across projects', async () => {
      await t.http
        .put(url('p1', 'e1'))
        .set(auth)
        .send({ orderedPhaseIds: ['p1_phase_2', 'p1_phase_1'] })
        .expect(200);

      const all = body<DaySequencesDto>(
        await t.http.get('/sequences').query({ day }).set(auth).expect(200),
      );
      expect(all.dayKey).toBe(day);
      // e2's only phase (p3) ended on the 12th, so e2 has no row at all.
      expect(all.sequences).toEqual([
        {
          projectId: 'p1',
          workerId: 'e1',
          dayKey: day,
          orderedPhaseIds: ['p1_phase_2', 'p1_phase_1'],
          suggestedPhaseIds: ['p1_phase_1'],
          isManual: true,
        },
        {
          projectId: 'p2',
          workerId: 'e3',
          dayKey: day,
          orderedPhaseIds: ['p2_phase_1'],
          suggestedPhaseIds: ['p2_phase_1'],
          isManual: false,
        },
      ]);
      expect(all.phaseNames).toMatchObject({
        p1_phase_1: 'Demolition',
        p1_phase_2: 'Finishing',
        p2_phase_1: 'Inspection',
      });

      const e3 = body<DaySequencesDto>(
        await t.http.get('/workers/e3/sequence').query({ day }).set(auth).expect(200),
      );
      expect(e3.sequences.map((s) => [s.projectId, s.orderedPhaseIds])).toEqual([
        ['p2', ['p2_phase_1']],
      ]);

      expectError(
        await t.http.get('/workers/no-such-worker/sequence').query({ day }).set(auth),
        404,
        'NOT_FOUND',
      );
    });

    it('drops a deleted phase from a saved order instead of serving a dangling id', async () => {
      const project = await createProject(t, token, {
        phases: [
          { name: 'X', assignedEmployeeIds: ['e1'] },
          { name: 'Y', assignedEmployeeIds: ['e1'] },
        ],
      });
      const [x, y] = [phaseAt(project, 0).id, phaseAt(project, 1).id];
      const sequenceUrl = `/projects/${project.id}/workers/e1/sequence?day=2026-06-02`;

      await t.http
        .put(sequenceUrl)
        .set(auth)
        .send({ orderedPhaseIds: [y, x] })
        .expect(200);
      await t.http.delete(`/projects/${project.id}/phases/${y}`).set(auth).expect(204);

      const after = await t.http.get(sequenceUrl).set(auth).expect(200);
      expect(body<DailyWorkerSequenceDto>(after)).toMatchObject({
        orderedPhaseIds: [x],
        suggestedPhaseIds: [x],
        isManual: true,
      });
    });
  });

  // -------------------------------------------------------------------------
  describe('company and profile', () => {
    it('PATCH /company is genuinely partial, and addressLine is derived', async () => {
      const before = body<CompanyDto>(await t.http.get('/company').set(auth).expect(200));
      expect(before).toMatchObject({
        id: 'demo-company',
        name: 'EchipaMea Demo SRL',
        addressLine: 'Str. Victoriei 12, Bucuresti, Bucuresti, 010072',
      });

      // No `name` sent, and the name survives.
      const iban = await t.http
        .patch('/company')
        .set(auth)
        .send({ iban: 'RO66BACX0000001234567890' })
        .expect(200);
      expect(body<CompanyDto>(iban)).toEqual({ ...before, iban: 'RO66BACX0000001234567890' });

      // The display line is rebuilt from the parts, skipping the empty one.
      const moved = await t.http
        .patch('/company')
        .set(auth)
        .send({ addressLine1: '', city: 'Cluj-Napoca' })
        .expect(200);
      expect(body<CompanyDto>(moved)).toMatchObject({
        name: 'EchipaMea Demo SRL',
        cui: before.cui,
        addressLine: 'Cluj-Napoca, Bucuresti, 010072',
      });

      // Output-only: sending addressLine alongside a real field changes nothing.
      const ignored = await t.http
        .patch('/company')
        .set(auth)
        .send({ addressLine: 'Somewhere else entirely', regCom: 'J12/3456/2021' })
        .expect(200);
      expect(body<CompanyDto>(ignored)).toMatchObject({
        regCom: 'J12/3456/2021',
        addressLine: 'Cluj-Napoca, Bucuresti, 010072',
      });
    });

    it('PATCH /me/profile edits only the person: never the role or the tenant', async () => {
      const before = body<ForemanProfileDto>(await t.http.get('/me/profile').set(auth).expect(200));
      expect(before).toMatchObject({
        userId: 'foreman_local',
        role: 'foreman',
        fullName: 'Sef de echipa',
        jobTitle: 'Foreman',
        companyId: 'demo-company',
      });

      // `role` and `email` are not profile fields; they are dropped, not applied.
      const patched = await t.http
        .patch('/me/profile')
        .set(auth)
        .send({ phone: '+40 799 000 000', role: 'admin', email: 'someone@example.com' })
        .expect(200);
      expect(body<ForemanProfileDto>(patched)).toEqual({ ...before, phone: '+40 799 000 000' });

      // Naming another tenant is not silently dropped: TenantGuard refuses it.
      expectError(
        await t.http
          .patch('/me/profile')
          .set(auth)
          .send({ jobTitle: 'Owner', companyId: 'other-company' }),
        403,
        'CROSS_TENANT',
      );
      const after = await t.http.get('/me/profile').set(auth).expect(200);
      expect(body<ForemanProfileDto>(after).jobTitle).toBe('Foreman');
    });
  });

  // -------------------------------------------------------------------------
  describe('validation', () => {
    it.each<[string, 'post' | 'patch' | 'put', string, Record<string, unknown>, string]>([
      ['client with an unknown type', 'post', '/clients', { name: 'X', type: 'bogus' }, 'type'],
      [
        'employee with a zero-length shift',
        'post',
        '/employees',
        { name: 'X', role: 'helper', workStartHour: 8, workEndHour: 8, workingDays: [1] },
        'workEndHour',
      ],
      ['project with a blank name', 'post', '/projects', { name: '  ', clientId: 'c1' }, 'name'],
      [
        'project for an unknown client',
        'post',
        '/projects',
        { name: 'X', clientId: 'no-such-client' },
        'clientId',
      ],
      [
        'project with a malformed phase date',
        'post',
        '/projects',
        {
          name: 'X',
          clientId: 'c1',
          phases: [{ name: 'P', startDate: '14/04/2026', endDate: '2026-04-20' }],
        },
        'phases.0.startDate',
      ],
      [
        'phase that ends before it starts',
        'post',
        '/projects/p1/phases',
        { name: 'P', startDate: '2026-05-10', endDate: '2026-05-01' },
        'endDate',
      ],
      ['review without a verdict', 'post', '/projects/p1/phases/p1_phase_1/review', {}, 'approved'],
      [
        'sequence with a repeated phase',
        'put',
        '/projects/p1/workers/e1/sequence?day=2026-04-14',
        { orderedPhaseIds: ['p1_phase_1', 'p1_phase_1'] },
        'orderedPhaseIds',
      ],
      [
        'sequence for an impossible day',
        'put',
        '/projects/p1/workers/e1/sequence?day=2026-02-30',
        { orderedPhaseIds: ['p1_phase_1'] },
        'day',
      ],
      ['company with a blank name', 'patch', '/company', { name: '   ' }, 'name'],
      [
        'profile with an over-long name',
        'patch',
        '/me/profile',
        { fullName: 'x'.repeat(201) },
        'fullName',
      ],
    ])(
      'rejects a %s with 400 VALIDATION_FAILED naming the field',
      async (_label, method, path, payload, field) => {
        const res = await t.http[method](path).set(auth).send(payload);
        expectError(res, 400, 'VALIDATION_FAILED', field);
        expect(apiError(res).message).toEqual(expect.any(String));
      },
    );

    it('left the seeded rows untouched after all those rejections', async () => {
      const p1 = await getProject('p1');
      expect(p1.phases.map((p) => [p.id, p.status])).toEqual([
        ['p1_phase_1', 'inProgress'],
        ['p1_phase_2', 'notStarted'],
      ]);
      const company = body<CompanyDto>(await t.http.get('/company').set(auth).expect(200));
      expect(company.name).toBe('EchipaMea Demo SRL');
    });
  });
});
