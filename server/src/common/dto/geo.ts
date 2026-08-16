import { z } from 'zod';
import { parseFlexibleIso } from '../util/iso';

/**
 * Coordinate bounds, defined once.
 *
 * The same position arrives by three routes -- the telemetry socket, the batch
 * `/worker/locations` fallback, and an employee's home base -- and the database
 * has CHECK constraints behind all of them. Restating `-90..90` per call site is
 * how one of them ends up accepting a value the database then rejects with a
 * 500 instead of a 400.
 */
export const latitudeSchema = z.number().finite().min(-90).max(90);
export const longitudeSchema = z.number().finite().min(-180).max(180);

/** Metres. Never negative; a missing estimate is 0, not a rejection. */
export const accuracyMetersSchema = z.number().finite().min(0);

/**
 * A client timestamp, kept lenient.
 *
 * Dart emits six fractional digits on mobile and three on web, and a phone with
 * a skewed clock still has a usable position.
 */
export const clientTimestampSchema = z
  .string()
  .trim()
  .refine((value) => parseFlexibleIso(value) !== undefined, {
    message: 'Must be an ISO-8601 timestamp.',
  });
