import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';

/**
 * Redeem accepts either a bare `ticketId` or the raw scanned string, because
 * the scanner may hand back the whole QR payload (JSON, or a URL carrying it in
 * a `payload` query parameter, plain or base64). The server runs the same
 * normalisation the Dart client does.
 */
export const redeemTicketSchema = z
  .object({
    ticketId: z.string().trim().min(1).optional(),
    payload: z.string().trim().min(1).optional(),
    deviceId: z.string().trim().max(200).optional(),
  })
  .refine((v) => Boolean(v.ticketId ?? v.payload), {
    message: 'Provide either ticketId or payload.',
    path: ['ticketId'],
  });
export type RedeemTicketRequest = z.infer<typeof redeemTicketSchema>;

export class WorkerLoginTicketDto {
  @ApiProperty({ description: 'Opaque single-use secret. Present only in this response.' })
  ticketId!: string;

  @ApiProperty({ format: 'date-time' }) issuedAt!: string;
  @ApiProperty({ format: 'date-time' }) expiresAt!: string;
  @ApiProperty() expiresInSeconds!: number;

  @ApiProperty({
    description:
      'Render this string verbatim into the QR code. It is byte-for-byte the shape the ' +
      'existing Flutter scanner already parses.',
  })
  qrPayload!: string;

  @ApiPropertyOptional({
    description: 'Deep link carrying the payload as base64url, when APP_WORKER_LOGIN_URL is set.',
  })
  qrPayloadUrl?: string;
}

/** The JSON encoded into `qrPayload`. Field names must not change. */
export interface WorkerLoginQrPayload {
  type: 'foreman_worker_login_ticket';
  ticketId: string;
  employeeId: string;
  employeeName: string;
  issuedAt: string;
  expiresAt: string;
}

export const WORKER_LOGIN_TICKET_TYPE = 'foreman_worker_login_ticket';
