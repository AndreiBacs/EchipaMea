import {
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBody,
  ApiConsumes,
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiParam,
  ApiTags,
} from '@nestjs/swagger';
import type { Response } from 'express';
import { CurrentPrincipal } from '../common/decorators/current-principal.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AppException } from '../common/errors/app-exception';
import type { Principal } from '../common/auth/principal';
import { MediaService, type MediaDto } from './media.service';

/** Express.Multer.File without pulling the global namespace into scope. */
interface UploadedMulterFile {
  buffer: Buffer;
  originalname: string;
  mimetype: string;
  size: number;
}

@ApiTags('Media')
@Controller('media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Roles('foreman', 'admin', 'worker')
  @Post()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    operationId: 'uploadMedia',
    summary: 'Upload one file',
    description:
      'Generic on purpose: it decouples upload from phase save ordering, so the editor can ' +
      'upload attachments before the phase exists. The content type is sniffed from the bytes ' +
      'and the declared part type is ignored -- the Flutter client sends everything as ' +
      'application/octet-stream. Identical content within a company is de-duplicated.',
  })
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @ApiCreatedResponse({ description: 'Stored.' })
  upload(
    @CurrentPrincipal() principal: Principal,
    @UploadedFile() file: UploadedMulterFile | undefined,
  ): Promise<MediaDto> {
    if (!file) throw AppException.badRequest('No file part named "file" was provided.', 'file');
    return this.media.upload(principal, {
      buffer: file.buffer,
      originalName: file.originalname,
      declaredContentType: file.mimetype,
    });
  }

  @Roles('foreman', 'admin', 'worker')
  @Get(':mediaId')
  @ApiOperation({ operationId: 'getMedia', summary: 'Media metadata' })
  @ApiParam({ name: 'mediaId', type: String })
  @ApiOkResponse({ description: 'Metadata.' })
  get(
    @CurrentPrincipal() principal: Principal,
    @Param('mediaId') mediaId: string,
  ): Promise<MediaDto> {
    return this.media.getMetadata(principal.companyId, mediaId);
  }

  @Roles('foreman', 'admin', 'worker')
  @Get(':mediaId/signed-url')
  @ApiOperation({
    operationId: 'getMediaSignedUrl',
    summary: 'Short-lived direct URL',
    description:
      'Preferred for rendering: Image.network cannot attach an Authorization header. ' +
      'Returns 501 on the local storage driver, which cannot sign.',
  })
  @ApiParam({ name: 'mediaId', type: String })
  @ApiOkResponse({ description: 'Signed URL and its lifetime in seconds.' })
  signedUrl(
    @CurrentPrincipal() principal: Principal,
    @Param('mediaId') mediaId: string,
  ): Promise<{ url: string; expiresIn: number }> {
    return this.media.signedUrl(principal.companyId, mediaId);
  }

  /**
   * Streams the bytes through the API.
   *
   * Range-capable so `audioplayers` can seek within a voice memo instead of
   * buffering the whole file before playback.
   */
  @Roles('foreman', 'admin', 'worker')
  @Get(':mediaId/content')
  @ApiOperation({
    operationId: 'getMediaContent',
    summary: 'Stream media bytes',
    description: 'Supports HTTP Range requests, which audio seeking depends on.',
  })
  @ApiParam({ name: 'mediaId', type: String })
  @ApiOkResponse({ description: 'The file bytes.' })
  async content(
    @CurrentPrincipal() principal: Principal,
    @Param('mediaId') mediaId: string,
    @Headers('range') rangeHeader: string | undefined,
    @Res() response: Response,
  ): Promise<void> {
    const range = parseRange(rangeHeader);
    const result = await this.media.read(principal.companyId, mediaId, range);

    response.setHeader('Content-Type', result.contentType);
    response.setHeader('Accept-Ranges', 'bytes');
    response.setHeader('Content-Length', String(result.byteSize));
    // Private by default: media is tenant-scoped and must not sit in a shared
    // or CDN cache where another tenant could be served it.
    response.setHeader('Cache-Control', 'private, max-age=300');

    if (result.contentRange) {
      response.setHeader('Content-Range', result.contentRange);
      response.status(HttpStatus.PARTIAL_CONTENT);
    }

    result.stream.pipe(response);
  }

  @Delete(':mediaId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    operationId: 'deleteMedia',
    summary: 'Delete media',
    description: 'Returns 409 MEDIA_IN_USE while an instruction or report still references it.',
  })
  @ApiParam({ name: 'mediaId', type: String })
  @ApiNoContentResponse({ description: 'Deleted.' })
  async remove(
    @CurrentPrincipal() principal: Principal,
    @Param('mediaId') mediaId: string,
  ): Promise<void> {
    await this.media.remove(principal.companyId, mediaId);
  }
}

/** Parses a single-range `bytes=start-end` header; anything else is ignored. */
function parseRange(header: string | undefined): { start: number; end?: number } | undefined {
  if (!header) return undefined;
  const match = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!match) return undefined;

  const [, rawStart, rawEnd] = match;
  if (!rawStart && !rawEnd) return undefined;

  // A suffix range (`bytes=-500`) needs the object size to resolve, which the
  // driver has and this layer does not, so it is left unhandled rather than
  // guessed at.
  if (!rawStart) return undefined;

  const start = Number(rawStart);
  if (!Number.isFinite(start) || start < 0) return undefined;
  const end = rawEnd ? Number(rawEnd) : undefined;
  if (end !== undefined && (!Number.isFinite(end) || end < start)) return undefined;

  return { start, end };
}
