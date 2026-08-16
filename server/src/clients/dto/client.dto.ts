import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';
import { pageQuerySchema } from '../../common/dto/page.dto';

export const clientTypeEnum = z.enum(['individual', 'company', 'publicInstitution']);
export const clientStatusEnum = z.enum(['active', 'inactive', 'blocked']);
export const clientContactMethodEnum = z.enum(['phone', 'email', 'whatsApp']);

/**
 * `activeProjects` is accepted but ignored on write: the client currently sends
 * it, and rejecting the field would break the app before it is rewired. The
 * value returned is always the derived count.
 */
export const clientCreateSchema = z.object({
  name: z.string().trim().min(1, 'Name is required.').max(200),
  type: clientTypeEnum,
  status: clientStatusEnum.default('active'),
  preferredContactMethod: clientContactMethodEnum.default('phone'),
  notes: z.string().max(5000).default(''),
  email: z.string().trim().max(320).default(''),
  phone: z.string().trim().max(50).default(''),
  addressLine1: z.string().trim().max(300).default(''),
  city: z.string().trim().max(120).default(''),
  state: z.string().trim().max(120).default(''),
  zipCode: z.string().trim().max(30).default(''),
  contactPerson: z.string().trim().max(200).default(''),
  activeProjects: z.number().int().optional(),
});
export type ClientCreateRequest = z.infer<typeof clientCreateSchema>;

/**
 * A true partial update. The draft spec defined the update body as
 * `allOf: [ClientBase]` with every field required -- replace semantics behind a
 * PATCH verb, so changing one attribute was impossible. Sending the whole
 * object still works, which is what the current client does.
 */
export const clientUpdateSchema = clientCreateSchema
  .partial()
  .refine((value) => Object.keys(value).length > 0, {
    message: 'Provide at least one field to update.',
  });
export type ClientUpdateRequest = z.infer<typeof clientUpdateSchema>;

export const clientListQuerySchema = pageQuerySchema.extend({
  q: z.string().trim().min(1).max(200).optional(),
  status: clientStatusEnum.optional(),
  type: clientTypeEnum.optional(),
  sort: z.enum(['name', '-name', 'createdAt', '-createdAt']).default('name'),
});
export type ClientListQuery = z.infer<typeof clientListQuerySchema>;

export class ClientDto {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
  @ApiProperty({
    description: "Derived: count of this client's projects whose status is not `done`.",
    readOnly: true,
  })
  activeProjects!: number;
  @ApiProperty({ enum: ['individual', 'company', 'publicInstitution'] }) type!: string;
  @ApiProperty({ enum: ['active', 'inactive', 'blocked'] }) status!: string;
  @ApiProperty({ enum: ['phone', 'email', 'whatsApp'] }) preferredContactMethod!: string;
  @ApiProperty() notes!: string;
  @ApiProperty() email!: string;
  @ApiProperty() phone!: string;
  @ApiProperty() addressLine1!: string;
  @ApiProperty() city!: string;
  @ApiProperty() state!: string;
  @ApiProperty() zipCode!: string;
  @ApiProperty() contactPerson!: string;
  @ApiPropertyOptional({ format: 'date-time' }) createdAt?: string;
  @ApiPropertyOptional({ format: 'date-time' }) updatedAt?: string;
}

export class PagedClientsDto {
  @ApiProperty({ type: [ClientDto] }) items!: ClientDto[];
  @ApiProperty() page!: { limit: number; nextCursor?: string; total?: number };
}
