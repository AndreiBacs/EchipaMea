/**
 * Demo seed.
 *
 * Reproduces the data the Flutter app currently hardcodes in the `build()` of
 * its Riverpod notifiers, using the *same literal ids* (`c1`, `e1`, `p1`,
 * `p1_phase_1`, ...). Several Dart tests look those ids up directly, so keeping
 * them identical is what lets the app be pointed at a real backend without
 * rewriting its fixtures.
 *
 * A second tenant is seeded as well. It exists purely so `tenancy.e2e-spec.ts`
 * has something to try to leak: cross-tenant bugs are invisible when only one
 * company exists.
 *
 * Idempotent -- safe to re-run.
 */
import * as argon2 from 'argon2';
import { PrismaClient, type PhaseStatus, type WorkerRole } from '@prisma/client';

const prisma = new PrismaClient();

const DEMO_COMPANY_ID = 'demo-company';
const OTHER_COMPANY_ID = 'other-company';

const FOREMAN_EMAIL = process.env.SEED_FOREMAN_EMAIL ?? 'foreman@echipamea.local';
const FOREMAN_PASSWORD = process.env.SEED_FOREMAN_PASSWORD ?? 'foreman123';

/** Date-only helper mirroring the app's phase windows. */
function day(value: string): Date {
  return new Date(`${value}T00:00:00.000Z`);
}

async function main(): Promise<void> {
  const passwordHash = await argon2.hash(FOREMAN_PASSWORD, {
    type: argon2.argon2id,
    memoryCost: 19_456,
    timeCost: 2,
    parallelism: 1,
  });

  // -------------------------------------------------------------------------
  // Demo tenant
  // -------------------------------------------------------------------------
  await prisma.company.upsert({
    where: { id: DEMO_COMPANY_ID },
    update: {},
    create: {
      id: DEMO_COMPANY_ID,
      name: 'EchipaMea Demo SRL',
      addressLine1: 'Str. Victoriei 12',
      city: 'Bucuresti',
      state: 'Bucuresti',
      zipCode: '010072',
      cui: 'RO12345678',
      vatNumber: 'RO12345678',
      regCom: 'J40/1234/2020',
      iban: 'RO49AAAA1B31007593840000',
    },
  });

  await prisma.user.upsert({
    where: { email: FOREMAN_EMAIL.toLowerCase() },
    update: { passwordHash },
    create: {
      id: 'foreman_local',
      companyId: DEMO_COMPANY_ID,
      // Lowercased on the way in: login lowercases before lookup, and the
      // unique index is plain rather than functional.
      email: FOREMAN_EMAIL.toLowerCase(),
      passwordHash,
      role: 'foreman',
      fullName: 'Sef de echipa',
      jobTitle: 'Foreman',
      phone: '+40 721 000 000',
    },
  });

  // --- Clients -------------------------------------------------------------
  // `activeProjects` is deliberately absent: it is derived from the projects
  // table. The app's seed claimed c1=2 and c3=1; the true derived values are
  // c1=1 and c3=0 (p3 is done). No Dart test asserts those numbers.
  const clients = [
    {
      id: 'c1',
      name: 'Elena Popescu',
      type: 'individual' as const,
      status: 'active' as const,
      preferredContactMethod: 'phone' as const,
      notes: 'Prefers phone calls in the morning.',
      email: 'elena.popescu@example.com',
      phone: '+40 731 100 101',
      addressLine1: 'Str. Victoriei 12',
      city: 'Bucuresti',
      state: 'Bucuresti',
      zipCode: '010072',
      contactPerson: 'Elena Popescu',
    },
    {
      id: 'c2',
      name: 'SC BuildFast SRL',
      type: 'company' as const,
      status: 'active' as const,
      preferredContactMethod: 'email' as const,
      notes: 'Invoices must include purchase order reference.',
      email: 'office@buildfast.example.com',
      phone: '+40 744 222 333',
      addressLine1: 'Bd. Independentei 7',
      city: 'Cluj-Napoca',
      state: 'Cluj',
      zipCode: '400015',
      contactPerson: 'Radu Ionescu',
    },
    {
      id: 'c3',
      name: 'Cafe Luna',
      type: 'company' as const,
      status: 'active' as const,
      preferredContactMethod: 'whatsApp' as const,
      notes: '',
      email: 'contact@cafeluna.example.com',
      phone: '+40 756 333 444',
      addressLine1: 'Piata Unirii 3',
      city: 'Timisoara',
      state: 'Timis',
      zipCode: '300085',
      contactPerson: 'Ana Moldovan',
    },
  ];

  for (const client of clients) {
    await prisma.client.upsert({
      where: { id: client.id },
      update: {},
      create: { ...client, companyId: DEMO_COMPANY_ID },
    });
  }

  // --- Employees -----------------------------------------------------------
  const employees: {
    id: string;
    name: string;
    role: WorkerRole;
    email: string;
    phone: string;
    workStartHour: number;
    workEndHour: number;
    workingDays: number[];
    latitude: number;
    longitude: number;
  }[] = [
    {
      id: 'e1',
      name: 'Andrei D.',
      role: 'electrician',
      email: 'andrei@example.com',
      phone: '+40 721 000 111',
      workStartHour: 7,
      workEndHour: 16,
      workingDays: [1, 2, 3, 4, 5],
      latitude: 46.7729,
      longitude: 23.6243,
    },
    {
      id: 'e2',
      name: 'Mihai S.',
      role: 'plumber',
      email: 'mihai@example.com',
      phone: '+40 722 000 222',
      workStartHour: 8,
      workEndHour: 17,
      workingDays: [1, 2, 3, 4, 5],
      latitude: 46.7686,
      longitude: 23.6041,
    },
    {
      id: 'e3',
      name: 'Ioana R.',
      role: 'generalWorker',
      email: 'ioana@example.com',
      phone: '+40 723 000 333',
      workStartHour: 9,
      workEndHour: 18,
      workingDays: [1, 2, 3, 4, 5, 6],
      latitude: 46.7614,
      longitude: 23.5918,
    },
  ];

  for (const employee of employees) {
    await prisma.employee.upsert({
      where: { id: employee.id },
      update: {},
      create: { ...employee, companyId: DEMO_COMPANY_ID },
    });
  }

  // --- Projects, phases, assignments ---------------------------------------
  interface SeedPhase {
    id: string;
    name: string;
    startDate: string;
    endDate: string;
    description?: string;
    status: PhaseStatus;
    assignees: string[];
    instructions?: { id: string; text: string }[];
    /** Employees who already submitted, so submittedAt/By derive correctly. */
    submittedBy?: string[];
    review?: { approved: boolean; byUserId: string };
  }

  interface SeedProject {
    id: string;
    name: string;
    clientId: string;
    useClientAddress: boolean;
    addressLine1: string;
    city: string;
    state: string;
    zipCode: string;
    latitude: number;
    longitude: number;
    assignees: string[];
    phases: SeedPhase[];
  }

  const projects: SeedProject[] = [
    {
      id: 'p1',
      name: 'Renovation - Main Street 15',
      clientId: 'c1',
      useClientAddress: true,
      addressLine1: 'Str. Victoriei 12',
      city: 'Bucuresti',
      state: 'Bucuresti',
      zipCode: '010072',
      latitude: 46.7723,
      longitude: 23.6236,
      assignees: ['e1'],
      phases: [
        {
          id: 'p1_phase_1',
          name: 'Demolition',
          startDate: '2026-04-13',
          endDate: '2026-04-16',
          description: 'Strip interior down to studs; dispose debris.',
          status: 'inProgress',
          assignees: ['e1'],
          instructions: [
            { id: 'p1_wi_1', text: 'Disconnect utilities before starting.' },
            { id: 'p1_wi_2', text: 'Bag and label hazardous debris separately.' },
          ],
        },
        {
          id: 'p1_phase_2',
          name: 'Finishing',
          startDate: '2026-04-17',
          endDate: '2026-04-24',
          status: 'notStarted',
          assignees: ['e1'],
        },
      ],
    },
    {
      id: 'p2',
      name: 'Roof repair - Industrial Hall',
      clientId: 'c2',
      useClientAddress: true,
      addressLine1: 'Bd. Independentei 7',
      city: 'Cluj-Napoca',
      state: 'Cluj',
      zipCode: '400015',
      latitude: 46.7609,
      longitude: 23.5902,
      assignees: ['e3'],
      phases: [
        {
          id: 'p2_phase_1',
          name: 'Inspection',
          startDate: '2026-04-14',
          endDate: '2026-04-15',
          status: 'notStarted',
          assignees: ['e3'],
        },
      ],
    },
    {
      id: 'p3',
      name: 'Kitchen fit-out - Cafe Luna',
      clientId: 'c3',
      useClientAddress: true,
      addressLine1: 'Piata Unirii 3',
      city: 'Timisoara',
      state: 'Timis',
      zipCode: '300085',
      latitude: 46.7692,
      longitude: 23.6034,
      assignees: ['e2'],
      phases: [
        {
          id: 'p3_phase_1',
          name: 'Install',
          startDate: '2026-04-10',
          endDate: '2026-04-12',
          status: 'done',
          assignees: ['e2'],
          // The Dart seed marked this phase done with a reviewer but left
          // submittedAt/reviewedAt null -- internally inconsistent. Here the
          // submission and review rows exist, so the derived timestamps are real.
          submittedBy: ['e2'],
          review: { approved: true, byUserId: 'foreman_local' },
        },
      ],
    },
  ];

  for (const project of projects) {
    await prisma.project.upsert({
      where: { id: project.id },
      update: {},
      create: {
        id: project.id,
        companyId: DEMO_COMPANY_ID,
        clientId: project.clientId,
        name: project.name,
        useClientAddress: project.useClientAddress,
        addressLine1: project.addressLine1,
        city: project.city,
        state: project.state,
        zipCode: project.zipCode,
        latitude: project.latitude,
        longitude: project.longitude,
      },
    });

    for (const employeeId of project.assignees) {
      await prisma.projectAssignment.upsert({
        where: { projectId_employeeId: { projectId: project.id, employeeId } },
        update: {},
        create: { projectId: project.id, employeeId, companyId: DEMO_COMPANY_ID },
      });
    }

    for (const [index, phase] of project.phases.entries()) {
      await prisma.projectPhase.upsert({
        where: { id: phase.id },
        update: {},
        create: {
          id: phase.id,
          companyId: DEMO_COMPANY_ID,
          projectId: project.id,
          name: phase.name,
          startDate: day(phase.startDate),
          endDate: day(phase.endDate),
          description: phase.description ?? '',
          status: phase.status,
          sortIndex: index,
        },
      });

      for (const employeeId of phase.assignees) {
        await prisma.phaseAssignment.upsert({
          where: { phaseId_employeeId: { phaseId: phase.id, employeeId } },
          update: {},
          create: {
            phaseId: phase.id,
            employeeId,
            companyId: DEMO_COMPANY_ID,
            projectId: project.id,
          },
        });
      }

      for (const [wiIndex, instruction] of (phase.instructions ?? []).entries()) {
        await prisma.phaseWorkInstruction.upsert({
          where: { id: instruction.id },
          update: {},
          create: {
            id: instruction.id,
            companyId: DEMO_COMPANY_ID,
            phaseId: phase.id,
            text: instruction.text,
            sortIndex: wiIndex,
          },
        });
      }

      for (const employeeId of phase.submittedBy ?? []) {
        const existing = await prisma.phaseSubmission.findFirst({
          where: { companyId: DEMO_COMPANY_ID, phaseId: phase.id, employeeId },
          select: { id: true },
        });
        if (!existing) {
          await prisma.phaseSubmission.create({
            data: {
              companyId: DEMO_COMPANY_ID,
              phaseId: phase.id,
              employeeId,
              submittedAt: day(phase.endDate),
            },
          });
        }
      }

      if (phase.review) {
        const existing = await prisma.phaseReview.findFirst({
          where: { companyId: DEMO_COMPANY_ID, phaseId: phase.id },
          select: { id: true },
        });
        if (!existing) {
          await prisma.phaseReview.create({
            data: {
              companyId: DEMO_COMPANY_ID,
              phaseId: phase.id,
              approved: phase.review.approved,
              reviewedById: phase.review.byUserId,
            },
          });
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Second tenant -- the control group for cross-tenant leakage tests.
  // -------------------------------------------------------------------------
  await prisma.company.upsert({
    where: { id: OTHER_COMPANY_ID },
    update: {},
    create: { id: OTHER_COMPANY_ID, name: 'Rival Constructii SRL', city: 'Iasi' },
  });

  await prisma.user.upsert({
    where: { email: 'rival@echipamea.local' },
    update: { passwordHash },
    create: {
      id: 'rival_foreman',
      companyId: OTHER_COMPANY_ID,
      email: 'rival@echipamea.local',
      passwordHash,
      role: 'foreman',
      fullName: 'Rival Foreman',
    },
  });

  await prisma.client.upsert({
    where: { id: 'rival_c1' },
    update: {},
    create: {
      id: 'rival_c1',
      companyId: OTHER_COMPANY_ID,
      name: 'Rival Client',
      type: 'company',
      status: 'active',
      preferredContactMethod: 'email',
      email: 'rival.client@example.com',
    },
  });

  await prisma.employee.upsert({
    where: { id: 'rival_e1' },
    update: {},
    create: {
      id: 'rival_e1',
      companyId: OTHER_COMPANY_ID,
      name: 'Rival Worker',
      role: 'mason',
      workStartHour: 8,
      workEndHour: 17,
      workingDays: [1, 2, 3, 4, 5],
    },
  });

  await prisma.project.upsert({
    where: { id: 'rival_p1' },
    update: {},
    create: {
      id: 'rival_p1',
      companyId: OTHER_COMPANY_ID,
      clientId: 'rival_c1',
      name: 'Rival Project',
      addressLine1: 'Str. Rivala 1',
      city: 'Iasi',
      state: 'Iasi',
      zipCode: '700001',
    },
  });

  console.log('Seed complete.');
  console.log(`  Demo tenant:  ${DEMO_COMPANY_ID}`);
  console.log(`  Foreman:      ${FOREMAN_EMAIL} / ${FOREMAN_PASSWORD}`);
  console.log(`  Other tenant: ${OTHER_COMPANY_ID} (rival@echipamea.local)`);
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error: unknown) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
