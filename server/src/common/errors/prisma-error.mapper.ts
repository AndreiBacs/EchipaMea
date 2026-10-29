import { HttpStatus } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AppException } from './app-exception';
import { ErrorCode } from './error-codes';

/**
 * Turns Prisma's driver-level errors into the public error envelope.
 *
 * Without this, a unique-constraint violation surfaces as a 500 with a stack
 * trace that leaks column names.
 */
export function mapPrismaError(error: unknown): AppException | undefined {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    switch (error.code) {
      case 'P2002': {
        const field = firstTargetField(error.meta?.target);
        return new AppException(
          HttpStatus.CONFLICT,
          ErrorCode.CONFLICT,
          field
            ? `A record with this ${field} already exists.`
            : 'A record with these values already exists.',
          { field, cause: error },
        );
      }
      case 'P2003':
        return new AppException(
          HttpStatus.BAD_REQUEST,
          ErrorCode.VALIDATION_FAILED,
          'Referenced record does not exist.',
          { field: fieldNameFrom(error.meta?.field_name), cause: error },
        );
      case 'P2025':
        return new AppException(
          HttpStatus.NOT_FOUND,
          ErrorCode.NOT_FOUND,
          'The requested record was not found.',
          { cause: error },
        );
      case 'P2014':
        return new AppException(
          HttpStatus.CONFLICT,
          ErrorCode.CONFLICT,
          'This change would break a required relation.',
          { cause: error },
        );
      default:
        return undefined;
    }
  }

  if (error instanceof Prisma.PrismaClientValidationError) {
    return new AppException(
      HttpStatus.BAD_REQUEST,
      ErrorCode.VALIDATION_FAILED,
      'Malformed database query.',
      { cause: error },
    );
  }

  return undefined;
}

function firstTargetField(target: unknown): string | undefined {
  if (Array.isArray(target)) {
    const first = target.find((t): t is string => typeof t === 'string');
    return first;
  }
  return typeof target === 'string' ? target : undefined;
}

function fieldNameFrom(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}
