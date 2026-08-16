import { z } from 'zod';
import { reportFieldsSchema } from '../reports/report-fields.schema';
import { parseFlexibleIso } from '../common/util/iso';

/**
 * Every frame on both sockets is a flat JSON object discriminated by `type`.
 *
 * This is not Nest's default `{event, data}` envelope and not socket.io -- the
 * Flutter client writes `{'type': 'worker_location', 'latitude': ..., ...}`
 * directly onto a raw RFC-6455 socket. `TypeFieldWsAdapter` exists to dispatch
 * on this field; changing the shape here means changing the app too.
 */

export const FrameType = {
  WORKER_LOCATION: 'worker_location',
  WORKER_REPORT_SUBMITTED: 'worker_report_submitted',
  CONNECTED: 'connected',
  ERROR: 'error',
  ACK: 'ack',
} as const;

export type RealtimeChannel = 'workerTelemetry' | 'foremanNotifications';

// --- Inbound -----------------------------------------------------------------

/**
 * `worker_location`, from `worker_telemetry_coordinator.dart`.
 *
 * `accuracyMeters` is defaulted rather than required: it comes from
 * `Position.accuracy`, which some Android devices report as absent. Rejecting
 * the frame over it would throw away a usable fix.
 */
export const workerLocationFrameSchema = z.object({
  type: z.literal(FrameType.WORKER_LOCATION),
  employeeId: z.string().trim().default(''),
  employeeName: z.string().trim().default(''),
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
  accuracyMeters: z.number().finite().min(0).default(0),
  capturedAt: z
    .string()
    .trim()
    .default('')
    .refine((value) => value === '' || parseFlexibleIso(value) !== undefined, {
      message: 'capturedAt must be an ISO-8601 timestamp.',
    }),
});

export type WorkerLocationFrame = z.infer<typeof workerLocationFrameSchema>;

/**
 * `worker_report_submitted`, from `worker_reports_api.dart`.
 *
 * Built by extending the multipart schema rather than restating it. The two
 * paths describe the same event and must normalise `submittedAt` identically:
 * the idempotency key is a hash of that string, so a stray `.trim()` on one side
 * only would give the HTTP upload and this frame two different keys and the
 * foreman two notifications for one report.
 */
export const workerReportSubmittedFrameSchema = reportFieldsSchema.extend({
  type: z.literal(FrameType.WORKER_REPORT_SUBMITTED),
  photoCount: z.coerce.number().int().min(0).catch(0).default(0),
  // Not `z.coerce.boolean()`: that is `Boolean(value)`, under which the string
  // "false" is true. The app sends a real JSON boolean, but a stringifying HTTP
  // bridge in front of it would otherwise flip every absent memo to present.
  hasVoiceMemo: z
    .union([z.boolean(), z.string()])
    .transform((value) =>
      typeof value === 'boolean' ? value : value.trim().toLowerCase() === 'true',
    )
    .catch(false)
    .default(false),
});

export type WorkerReportSubmittedFrame = z.infer<typeof workerReportSubmittedFrameSchema>;

// --- Outbound ----------------------------------------------------------------

export interface ConnectedFrame {
  type: typeof FrameType.CONNECTED;
  channel: RealtimeChannel;
  role: string;
  /** Server time, so a client can measure clock skew if it ever wants to. */
  serverTime: string;
  heartbeatIntervalMs: number;
}

export interface ErrorFrame {
  type: typeof FrameType.ERROR;
  code: string;
  message: string;
}

export interface AckFrame {
  type: typeof FrameType.ACK;
  of: string;
  receivedAt: string;
  /** Set when the server recognised the event as one it already had. */
  duplicate?: boolean;
}

/**
 * Errors are always a frame, never a close.
 *
 * Both Flutter sockets listen with `cancelOnError: true` and have no reconnect
 * logic, so closing the connection over one bad message would silently kill
 * notifications for the rest of the app session. A frame the client ignores is
 * strictly better than a socket it never reopens.
 */
export function errorFrame(code: string, message: string): ErrorFrame {
  return { type: FrameType.ERROR, code, message };
}

export function ackFrame(of: string, duplicate?: boolean): AckFrame {
  return {
    type: FrameType.ACK,
    of,
    receivedAt: new Date().toISOString(),
    ...(duplicate === undefined ? {} : { duplicate }),
  };
}
