import { HttpException, HttpStatus } from '@nestjs/common';
import { ErrorCode, type ErrorCodeValue } from './error-codes';

export interface AppExceptionOptions {
  /** Input field the error is tied to, surfaced as `error.field`. */
  field?: string;
  /** Never serialised; logged for diagnosis. */
  cause?: unknown;
}

/**
 * The only exception type application code should throw.
 *
 * `AllExceptionsFilter` renders it as the contract's error envelope:
 * `{ error: { code, message, field? }, traceId? }`.
 */
export class AppException extends HttpException {
  readonly code: ErrorCodeValue;
  readonly field?: string;

  constructor(
    status: HttpStatus,
    code: ErrorCodeValue,
    message: string,
    options: AppExceptionOptions = {},
  ) {
    super({ code, message, field: options.field }, status, { cause: options.cause });
    this.code = code;
    this.field = options.field;
  }

  static badRequest(message: string, field?: string): AppException {
    return new AppException(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_FAILED, message, { field });
  }

  static unauthenticated(
    message = 'Authentication required.',
    code: ErrorCodeValue = ErrorCode.UNAUTHENTICATED,
  ): AppException {
    return new AppException(HttpStatus.UNAUTHORIZED, code, message);
  }

  static forbidden(
    message = 'You do not have access to this resource.',
    code: ErrorCodeValue = ErrorCode.FORBIDDEN,
  ): AppException {
    return new AppException(HttpStatus.FORBIDDEN, code, message);
  }

  static notFound(resource: string, id?: string): AppException {
    return new AppException(
      HttpStatus.NOT_FOUND,
      ErrorCode.NOT_FOUND,
      id ? `${resource} "${id}" was not found.` : `${resource} was not found.`,
    );
  }

  static conflict(
    message: string,
    code: ErrorCodeValue = ErrorCode.CONFLICT,
    field?: string,
  ): AppException {
    return new AppException(HttpStatus.CONFLICT, code, message, { field });
  }

  static gone(message: string, code: ErrorCodeValue): AppException {
    return new AppException(HttpStatus.GONE, code, message);
  }

  static payloadTooLarge(message: string): AppException {
    return new AppException(
      HttpStatus.PAYLOAD_TOO_LARGE,
      ErrorCode.PAYLOAD_TOO_LARGE,
      message,
    );
  }

  static internal(message = 'Unexpected server error.', cause?: unknown): AppException {
    return new AppException(
      HttpStatus.INTERNAL_SERVER_ERROR,
      ErrorCode.INTERNAL_ERROR,
      message,
      { cause },
    );
  }
}
