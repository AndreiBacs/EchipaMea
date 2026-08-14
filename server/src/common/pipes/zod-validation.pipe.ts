import { PipeTransform } from '@nestjs/common';
import { ZodError, ZodType, type ZodTypeDef } from 'zod';
import { AppException } from '../errors/app-exception';

/**
 * Validates a handler argument against a Zod schema and surfaces failures as
 * the standard envelope with `error.field` pointing at the offending path.
 *
 * Zod is used rather than class-validator so that request schemas and the
 * generated OpenAPI can be derived from one definition.
 */
export class ZodValidationPipe<TOut> implements PipeTransform<unknown, TOut> {
  // Parameterised over the *input* type too: schemas with `.default()` or
  // coercion have an input shape that differs from their output shape, and a
  // single-parameter ZodType<T> would reject them.
  constructor(private readonly schema: ZodType<TOut, ZodTypeDef, unknown>) {}

  transform(value: unknown): TOut {
    try {
      return this.schema.parse(value);
    } catch (error) {
      if (error instanceof ZodError) throw toAppException(error);
      throw error;
    }
  }
}

export function toAppException(error: ZodError): AppException {
  const issue = error.issues[0];
  if (!issue) return AppException.badRequest('Request validation failed.');
  const path = issue.path.join('.');
  return AppException.badRequest(
    path ? `${path}: ${issue.message}` : issue.message,
    path || undefined,
  );
}

/** Convenience for `@Body(zodBody(Schema))` and `@Query(zodBody(Schema))`. */
export function zodBody<TOut>(schema: ZodType<TOut, ZodTypeDef, unknown>): ZodValidationPipe<TOut> {
  return new ZodValidationPipe(schema);
}
