import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { AnyFilesInterceptor } from '@nestjs/platform-express';
import { ApiBody, ApiConsumes, ApiCreatedResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AllowAnonymousWorker } from '../common/decorators/public.decorator';
import { CurrentPrincipal } from '../common/decorators/current-principal.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { toAppException } from '../common/pipes/zod-validation.pipe';
import { ZodError } from 'zod';
import type { Principal } from '../common/auth/principal';
import {
  PHOTOS_FIELD,
  VOICE_MEMO_FIELD,
  collectPhotoNames,
  flattenBody,
  reportFieldsSchema,
} from './report-fields.schema';
import { WorkerReportsService, type WorkerReportResult } from './worker-reports.service';

interface MulterLikeFile {
  fieldname: string;
  originalname: string;
  buffer: Buffer;
  size: number;
}

@ApiTags('Worker Reports')
@Controller('worker/reports')
export class WorkerReportsController {
  constructor(private readonly reports: WorkerReportsService) {}

  /**
   * `AnyFilesInterceptor` rather than a named-field interceptor: the client's
   * photo field is literally `photos[]`, brackets included, and named
   * interceptors would have to declare that exact string while silently
   * rejecting anything else. Accepting all parts and sorting them by field name
   * here keeps the wire contract explicit and inspectable.
   */
  @Roles('worker', 'foreman', 'admin')
  @AllowAnonymousWorker()
  @Post()
  @UseInterceptors(AnyFilesInterceptor())
  @ApiConsumes('multipart/form-data')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    operationId: 'submitWorkerReport',
    summary: 'Submit an end-of-day report for a phase',
    description:
      'Matches the existing Flutter multipart upload exactly: text fields projectId, ' +
      'projectName, phaseId, phaseName, employeeId, employeeName, description, submittedAt, ' +
      'plus indexed photoNames[i]; file parts `photos[]` (repeated) and optional `voiceMemo`. ' +
      'All parts arrive as application/octet-stream, so types are sniffed from the bytes. ' +
      'Idempotent on (company, phase, employee, submittedAt): a retry returns the original ' +
      'result rather than creating a second report.',
  })
  @ApiBody({
    schema: {
      type: 'object',
      required: ['projectId', 'phaseId', 'submittedAt'],
      properties: {
        projectId: { type: 'string' },
        projectName: { type: 'string' },
        phaseId: { type: 'string' },
        phaseName: { type: 'string' },
        employeeId: { type: 'string' },
        employeeName: { type: 'string' },
        description: { type: 'string' },
        submittedAt: {
          type: 'string',
          description:
            'ISO-8601 UTC. Six fractional digits on mobile, three on web; both accepted and ' +
            'the raw string is retained for idempotency.',
        },
        'photos[]': { type: 'array', items: { type: 'string', format: 'binary' } },
        voiceMemo: { type: 'string', format: 'binary' },
        'photoNames[0]': { type: 'string' },
      },
    },
  })
  @ApiCreatedResponse({ description: 'Report stored.' })
  async submit(
    @CurrentPrincipal() principal: Principal,
    @Body() body: Record<string, unknown>,
    @UploadedFiles() files: MulterLikeFile[] | undefined,
  ): Promise<WorkerReportResult> {
    const flat = flattenBody(body ?? {});

    let fields;
    try {
      fields = reportFieldsSchema.parse(flat);
    } catch (error) {
      if (error instanceof ZodError) throw toAppException(error);
      throw error;
    }

    const parts = files ?? [];
    // Tolerate `photos` as well as `photos[]`: some HTTP clients strip the
    // brackets, and rejecting those would be a needless interop failure.
    const photos = parts
      .filter((f) => f.fieldname === PHOTOS_FIELD || f.fieldname === 'photos')
      .map((f) => ({ buffer: f.buffer, filename: f.originalname }));
    const memoPart = parts.find((f) => f.fieldname === VOICE_MEMO_FIELD);

    const { result } = await this.reports.submit(principal, {
      fields,
      photos,
      photoNames: collectPhotoNames(flat),
      voiceMemo: memoPart
        ? { buffer: memoPart.buffer, filename: memoPart.originalname }
        : undefined,
    });

    return result;
  }
}
