import { Injectable, Logger } from '@nestjs/common';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { PrismaService } from '../common/prisma/prisma.service';
import { reportIdempotencyKey } from '../common/util/ids';
import { parseFlexibleIsoOrNow } from '../common/util/iso';
import type { Principal } from '../common/auth/principal';
import { MediaService } from '../media/media.service';
import { PhaseLifecycleService } from '../phases/phase-lifecycle.service';
import { ConnectionRegistryService } from '../realtime/connection-registry.service';
import type { ReportFields } from './report-fields.schema';

export interface IncomingFile {
  buffer: Buffer;
  filename: string;
}

export interface SubmitReportInput {
  fields: ReportFields;
  photos: IncomingFile[];
  photoNames: string[];
  voiceMemo?: IncomingFile;
}

export interface WorkerReportResult {
  id: string;
  projectId: string;
  phaseId: string;
  employeeId: string;
  submittedAt: string;
  photoCount: number;
  hasVoiceMemo: boolean;
  phaseStatus: string;
  /** True when this call matched an existing report instead of creating one. */
  duplicate: boolean;
}

/**
 * The event the foreman clients receive. Structured data only -- never a
 * rendered title, because the app localises into ro/hu/en and a server-built
 * string would bypass that.
 */
export interface ReportSubmittedEvent {
  type: 'worker_report_submitted';
  projectId: string;
  projectName: string;
  phaseId: string;
  phaseName: string;
  employeeId: string;
  employeeName: string;
  description: string;
  photoCount: number;
  hasVoiceMemo: boolean;
  submittedAt: string;
}

@Injectable()
export class WorkerReportsService {
  private readonly logger = new Logger(WorkerReportsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly lifecycle: PhaseLifecycleService,
    private readonly realtime: ConnectionRegistryService,
    private readonly config: AppConfig,
  ) {}

  /**
   * Ingests a worker report: stores attachments, records the report, moves the
   * phase to pendingReview, and creates a notification per foreman.
   */
  async submit(
    principal: Principal,
    input: SubmitReportInput,
  ): Promise<{ result: WorkerReportResult; event: ReportSubmittedEvent | undefined }> {
    const { fields } = input;
    const companyId = principal.companyId;

    // The token is authoritative about who is submitting. `fields.employeeId`
    // arrives on the wire because the app sends it, and is ignored: a device
    // does not get to say whose work this was.
    const employeeId =
      principal.kind === 'employee' ? principal.employeeId : fields.employeeId.trim();
    if (!employeeId) {
      throw AppException.badRequest(
        'A worker session is required to submit a report.',
        'employeeId',
      );
    }

    const phase = await this.prisma.projectPhase.findFirst({
      where: {
        id: fields.phaseId,
        projectId: fields.projectId,
        companyId,
        deletedAt: null,
        project: { deletedAt: null },
      },
      select: { id: true, status: true, projectId: true, name: true },
    });
    if (!phase) throw AppException.notFound('Phase', fields.phaseId);

    const employee = await this.prisma.employee.findFirst({
      where: { id: employeeId, companyId, deletedAt: null },
      select: { id: true, name: true },
    });
    if (!employee) throw AppException.notFound('Employee', employeeId);

    const idempotencyKey = reportIdempotencyKey({
      companyId,
      phaseId: fields.phaseId,
      employeeId,
      submittedAtRaw: fields.submittedAt,
    });

    // Retries from a flaky mobile connection are common, and the worker device
    // also announces the same report over a WebSocket. Both must converge on
    // one row.
    const existing = await this.prisma.workerReport.findUnique({
      where: { idempotencyKey },
      include: { media: true },
    });
    if (existing) {
      this.logger.log(
        `Duplicate report ignored for phase ${fields.phaseId} (${idempotencyKey.slice(0, 12)}).`,
      );
      return {
        result: {
          id: existing.id,
          projectId: existing.projectId,
          phaseId: existing.phaseId,
          employeeId: existing.employeeId,
          submittedAt: existing.submittedAt.toISOString(),
          photoCount: existing.media.filter((m) => m.slot === 'reportPhoto').length,
          hasVoiceMemo: existing.media.some((m) => m.slot === 'reportVoiceMemo'),
          phaseStatus: phase.status,
          duplicate: true,
        },
        event: undefined,
      };
    }

    // Attachments are stored *before* the transaction. Object writes are the
    // slow part and must not hold a database transaction open -- the client
    // times out at 30s today, and a long-held transaction would block others.
    const storedPhotos = await Promise.all(
      input.photos.map((file) =>
        this.media.upload(principal, { buffer: file.buffer, originalName: file.filename }),
      ),
    );
    const storedMemo = input.voiceMemo
      ? await this.media.upload(principal, {
          buffer: input.voiceMemo.buffer,
          originalName: input.voiceMemo.filename,
        })
      : undefined;

    const submittedAt = parseFlexibleIsoOrNow(fields.submittedAt);
    const nextStatus = this.lifecycle.next(phase.status, 'submit');

    const report = await this.prisma.$transaction(async (tx) => {
      const created = await tx.workerReport.create({
        data: {
          companyId,
          projectId: fields.projectId,
          phaseId: fields.phaseId,
          employeeId,
          description: fields.description,
          submittedAt,
          submittedAtRaw: fields.submittedAt,
          projectNameSnapshot: fields.projectName,
          phaseNameSnapshot: fields.phaseName,
          employeeNameSnapshot: fields.employeeName || employee.name,
          idempotencyKey,
          source: 'http',
        },
      });

      const links = [
        ...storedPhotos.map((asset, index) => ({
          reportId: created.id,
          mediaId: asset.id,
          companyId,
          slot: 'reportPhoto' as const,
          sortIndex: index,
          clientName: input.photoNames[index] ?? asset.originalName,
        })),
        ...(storedMemo
          ? [
              {
                reportId: created.id,
                mediaId: storedMemo.id,
                companyId,
                slot: 'reportVoiceMemo' as const,
                sortIndex: 0,
                clientName: storedMemo.originalName,
              },
            ]
          : []),
      ];
      if (links.length > 0) {
        // skipDuplicates matters: de-duplicated media means two identical
        // photos in one report resolve to the same asset id.
        await tx.workerReportMedia.createMany({ data: links, skipDuplicates: true });
      }

      await tx.phaseSubmission.create({
        data: { companyId, phaseId: fields.phaseId, employeeId, submittedAt, reportId: created.id },
      });

      await tx.projectPhase.update({
        where: { id_companyId: { id: fields.phaseId, companyId } },
        data: { status: nextStatus },
      });

      // One notification row per foreman, so read state is per recipient.
      const foremen = await tx.user.findMany({
        where: { companyId, deletedAt: null, isActive: true },
        select: { id: true },
      });
      if (foremen.length > 0) {
        await tx.notification.createMany({
          data: foremen.map((user) => ({
            companyId,
            recipientUserId: user.id,
            kind: 'workerReportSubmitted' as const,
            payload: {
              projectId: fields.projectId,
              projectName: fields.projectName,
              phaseId: fields.phaseId,
              phaseName: fields.phaseName,
              employeeId,
              employeeName: fields.employeeName || employee.name,
              photoCount: storedPhotos.length,
              hasVoiceMemo: Boolean(storedMemo),
            },
            projectId: fields.projectId,
            phaseId: fields.phaseId,
            employeeId,
            reportId: created.id,
            occurredAt: submittedAt,
          })),
        });
      }

      return created;
    });

    const event: ReportSubmittedEvent = {
      type: 'worker_report_submitted',
      projectId: fields.projectId,
      projectName: fields.projectName,
      phaseId: fields.phaseId,
      phaseName: fields.phaseName,
      employeeId,
      employeeName: fields.employeeName || employee.name,
      description: fields.description,
      photoCount: storedPhotos.length,
      hasVoiceMemo: Boolean(storedMemo),
      submittedAt: fields.submittedAt,
    };

    // Fan out from here rather than from the controller, so every path that
    // creates a report notifies -- and so the client can stop doing it itself.
    const delivered = this.realtime.publishToForemen(companyId, event);
    this.logger.log(
      `Report ${report.id} stored for phase ${fields.phaseId}; pushed to ${delivered} foreman socket(s).`,
    );

    return {
      result: {
        id: report.id,
        projectId: report.projectId,
        phaseId: report.phaseId,
        employeeId: report.employeeId,
        submittedAt: report.submittedAt.toISOString(),
        photoCount: storedPhotos.length,
        hasVoiceMemo: Boolean(storedMemo),
        phaseStatus: nextStatus,
        duplicate: false,
      },
      event,
    };
  }

  /**
   * Handles the `worker_report_submitted` frame the worker device publishes on
   * the foreman socket right after a successful upload.
   *
   * In the normal case the HTTP upload has already created everything, and this
   * is a no-op -- which is the whole reason `submittedAtRaw` is stored verbatim.
   * It only does work if no matching report exists, so foremen still get told
   * about a report that reached the server by some other path.
   *
   * A notice with no matching upload leaves only notifications behind, so a
   * repeat of it is recognised by those: each carries the report's idempotency
   * key as `noticeKey`. A notice for a phase this company does not have is
   * reported back as such rather than acknowledged.
   */
  async ingestOutOfBandNotice(
    companyId: string,
    frame: {
      projectId: string;
      projectName?: string;
      phaseId: string;
      phaseName?: string;
      employeeId: string;
      employeeName?: string;
      description?: string;
      photoCount?: number;
      hasVoiceMemo?: boolean;
      submittedAt: string;
    },
  ): Promise<{ outcome: 'created' | 'duplicate' | 'unknownPhase' }> {
    const idempotencyKey = reportIdempotencyKey({
      companyId,
      phaseId: frame.phaseId,
      employeeId: frame.employeeId,
      submittedAtRaw: frame.submittedAt,
    });

    const existing = await this.prisma.workerReport.findUnique({
      where: { idempotencyKey },
      select: { id: true },
    });
    if (existing) return { outcome: 'duplicate' };

    const phase = await this.prisma.projectPhase.findFirst({
      where: { id: frame.phaseId, projectId: frame.projectId, companyId, deletedAt: null },
      select: { id: true, status: true },
    });
    if (!phase) {
      this.logger.warn(`Out-of-band report notice for unknown phase ${frame.phaseId}; ignoring.`);
      return { outcome: 'unknownPhase' };
    }

    const alreadyNotified = await this.prisma.notification.findFirst({
      where: {
        companyId,
        kind: 'workerReportSubmitted',
        phaseId: frame.phaseId,
        employeeId: frame.employeeId,
        payload: { path: ['noticeKey'], equals: idempotencyKey },
      },
      select: { id: true },
    });
    if (alreadyNotified) return { outcome: 'duplicate' };

    const occurredAt = parseFlexibleIsoOrNow(frame.submittedAt);
    const foremen = await this.prisma.user.findMany({
      where: { companyId, deletedAt: null, isActive: true },
      select: { id: true },
    });

    if (foremen.length > 0) {
      await this.prisma.notification.createMany({
        data: foremen.map((user) => ({
          companyId,
          recipientUserId: user.id,
          kind: 'workerReportSubmitted' as const,
          payload: {
            projectId: frame.projectId,
            projectName: frame.projectName ?? '',
            phaseId: frame.phaseId,
            phaseName: frame.phaseName ?? '',
            employeeId: frame.employeeId,
            employeeName: frame.employeeName ?? '',
            photoCount: frame.photoCount ?? 0,
            hasVoiceMemo: frame.hasVoiceMemo ?? false,
            noticeKey: idempotencyKey,
          },
          projectId: frame.projectId,
          phaseId: frame.phaseId,
          employeeId: frame.employeeId,
          occurredAt,
        })),
      });
    }

    this.realtime.publishToForemen(companyId, {
      type: 'worker_report_submitted',
      projectId: frame.projectId,
      projectName: frame.projectName ?? '',
      phaseId: frame.phaseId,
      phaseName: frame.phaseName ?? '',
      employeeId: frame.employeeId,
      employeeName: frame.employeeName ?? '',
      description: frame.description ?? '',
      photoCount: frame.photoCount ?? 0,
      hasVoiceMemo: frame.hasVoiceMemo ?? false,
      submittedAt: frame.submittedAt,
    } satisfies ReportSubmittedEvent);

    this.logger.log(
      `Recorded out-of-band report notice for phase ${frame.phaseId} with no matching upload.`,
    );
    return { outcome: 'created' };
  }
}
