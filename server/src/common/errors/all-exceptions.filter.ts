import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import { ZodError } from 'zod';
import { RequestContextService } from '../context/request-context.service';
import { AppException } from './app-exception';
import { ErrorCode, type ErrorCodeValue } from './error-codes';
import { mapPrismaError } from './prisma-error.mapper';

interface ErrorBody {
  error: { code: string; message: string; field?: string };
  traceId?: string;
}

/**
 * Renders every failure as the single documented envelope:
 *
 *   { "error": { "code", "message", "field"? }, "traceId"? }
 *
 * Nothing else may reach the client -- a raw Nest or Prisma error shape would
 * break the Flutter client's error parsing and can leak internals.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  constructor(private readonly context: RequestContextService) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    // WebSocket and RPC contexts have no HTTP response to write to.
    if (host.getType() !== 'http') {
      this.logger.error(
        { err: serialiseError(exception) },
        'Unhandled exception outside an HTTP context',
      );
      return;
    }

    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const { status, body } = this.render(exception);

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      this.logger.error(
        {
          err: serialiseError(exception),
          method: request.method,
          url: request.originalUrl,
          traceId: body.traceId,
        },
        `Unhandled ${status} on ${request.method} ${request.originalUrl}`,
      );
    } else {
      this.logger.debug(
        `${status} ${body.error.code} on ${request.method} ${request.originalUrl}`,
      );
    }

    if (response.headersSent) return;
    response.status(status).json(body);
  }

  private render(exception: unknown): { status: number; body: ErrorBody } {
    const traceId = this.safeTraceId();

    if (exception instanceof AppException) {
      return {
        status: exception.getStatus(),
        body: envelope(exception.code, exception.message, exception.field, traceId),
      };
    }

    if (exception instanceof ZodError) {
      const issue = exception.issues[0];
      return {
        status: HttpStatus.BAD_REQUEST,
        body: envelope(
          ErrorCode.VALIDATION_FAILED,
          issue ? `${issue.path.join('.') || 'body'}: ${issue.message}` : 'Request validation failed.',
          issue?.path.join('.') || undefined,
          traceId,
        ),
      };
    }

    if (exception instanceof ThrottlerException) {
      return {
        status: HttpStatus.TOO_MANY_REQUESTS,
        body: envelope(ErrorCode.RATE_LIMITED, 'Too many requests. Try again shortly.', undefined, traceId),
      };
    }

    const prismaMapped = mapPrismaError(exception);
    if (prismaMapped) {
      return {
        status: prismaMapped.getStatus(),
        body: envelope(prismaMapped.code, prismaMapped.message, prismaMapped.field, traceId),
      };
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const payload = exception.getResponse();
      return {
        status,
        body: envelope(
          extractCode(payload, status),
          extractMessage(payload, exception.message),
          extractField(payload),
          traceId,
        ),
      };
    }

    // Multer surfaces limit violations as a plain error with a `code`.
    if (isMulterLimitError(exception)) {
      return {
        status: HttpStatus.PAYLOAD_TOO_LARGE,
        body: envelope(
          ErrorCode.PAYLOAD_TOO_LARGE,
          'Upload exceeds the configured size or file-count limit.',
          undefined,
          traceId,
        ),
      };
    }

    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      body: envelope(ErrorCode.INTERNAL_ERROR, 'Unexpected server error.', undefined, traceId),
    };
  }

  /** The filter must never itself throw, even with no active CLS context. */
  private safeTraceId(): string | undefined {
    try {
      return this.context.isActive ? this.context.traceId : undefined;
    } catch {
      return undefined;
    }
  }
}

function envelope(
  code: string,
  message: string,
  field: string | undefined,
  traceId: string | undefined,
): ErrorBody {
  return {
    error: { code, message, ...(field ? { field } : {}) },
    ...(traceId ? { traceId } : {}),
  };
}

/** Best-effort mapping from a bare HTTP status to a stable code. */
function statusToCode(status: number): ErrorCodeValue {
  switch (status) {
    case HttpStatus.BAD_REQUEST:
      return ErrorCode.VALIDATION_FAILED;
    case HttpStatus.UNAUTHORIZED:
      return ErrorCode.UNAUTHENTICATED;
    case HttpStatus.FORBIDDEN:
      return ErrorCode.FORBIDDEN;
    case HttpStatus.NOT_FOUND:
      return ErrorCode.NOT_FOUND;
    case HttpStatus.CONFLICT:
      return ErrorCode.CONFLICT;
    case HttpStatus.PAYLOAD_TOO_LARGE:
      return ErrorCode.PAYLOAD_TOO_LARGE;
    case HttpStatus.UNSUPPORTED_MEDIA_TYPE:
      return ErrorCode.UNSUPPORTED_MEDIA_TYPE;
    case HttpStatus.TOO_MANY_REQUESTS:
      return ErrorCode.RATE_LIMITED;
    default:
      return status >= 500 ? ErrorCode.INTERNAL_ERROR : ErrorCode.VALIDATION_FAILED;
  }
}

function extractCode(payload: unknown, status: number): string {
  if (isRecord(payload) && typeof payload.code === 'string') return payload.code;
  return statusToCode(status);
}

function extractMessage(payload: unknown, fallback: string): string {
  if (isRecord(payload)) {
    if (typeof payload.message === 'string') return payload.message;
    if (Array.isArray(payload.message)) {
      const first = payload.message.find((m): m is string => typeof m === 'string');
      if (first) return first;
    }
  }
  if (typeof payload === 'string') return payload;
  return fallback;
}

function extractField(payload: unknown): string | undefined {
  if (isRecord(payload) && typeof payload.field === 'string') return payload.field;
  return undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function isMulterLimitError(error: unknown): boolean {
  return (
    isRecord(error) &&
    typeof error.code === 'string' &&
    error.code.startsWith('LIMIT_')
  );
}

function serialiseError(error: unknown): Record<string, unknown> {
  if (error instanceof Error) {
    return { name: error.name, message: error.message, stack: error.stack };
  }
  return { value: String(error) };
}
