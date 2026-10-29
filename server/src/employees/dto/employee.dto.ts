import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';
import { pageQuerySchema } from '../../common/dto/page.dto';
import { latitudeSchema, longitudeSchema } from '../../common/dto/geo';

export const workerRoleEnum = z.enum([
  'electrician',
  'plumber',
  'generalWorker',
  'carpenter',
  'welder',
  'helper',
  'painter',
  'mason',
  'hvacTechnician',
]);

/**
 * ISO-8601 weekdays, 1=Mon .. 7=Sun, matching Dart's `DateTime.weekday`.
 * Sorted and de-duplicated so the stored array has one canonical form.
 */
const workingDaysSchema = z
  .array(z.number().int().min(1, 'Weekdays run 1 (Mon) to 7 (Sun).').max(7))
  .min(1, 'Select at least one working day.')
  .max(7)
  .transform((days) => [...new Set(days)].sort((a, b) => a - b));

const latitude = latitudeSchema;
const longitude = longitudeSchema;

export const employeeCreateSchema = z
  .object({
    name: z.string().trim().min(1, 'Name is required.').max(200),
    role: workerRoleEnum,
    email: z.string().trim().max(320).default(''),
    phone: z.string().trim().max(50).default(''),
    workStartHour: z.number().int().min(0).max(23),
    workEndHour: z.number().int().min(0).max(23),
    workingDays: workingDaysSchema,
    latitude: latitude.nullish(),
    longitude: longitude.nullish(),
    isActive: z.boolean().default(true),
  })
  .refine((v) => v.workStartHour !== v.workEndHour, {
    message:
      'Start and end hour cannot be equal: that describes a zero-length shift, and telemetry ' +
      'would never be inside the working window.',
    path: ['workEndHour'],
  });
export type EmployeeCreateRequest = z.infer<typeof employeeCreateSchema>;

/**
 * Partial update. `latitude`/`longitude` accept an explicit `null` to clear,
 * which the Flutter entities cannot currently express -- their `copyWith` uses
 * `x ?? this.x`, so a nullable field can never be reset once set.
 */
export const employeeUpdateSchema = z
  .object({
    name: z.string().trim().min(1).max(200).optional(),
    role: workerRoleEnum.optional(),
    email: z.string().trim().max(320).optional(),
    phone: z.string().trim().max(50).optional(),
    workStartHour: z.number().int().min(0).max(23).optional(),
    workEndHour: z.number().int().min(0).max(23).optional(),
    workingDays: workingDaysSchema.optional(),
    latitude: latitude.nullish(),
    longitude: longitude.nullish(),
    isActive: z.boolean().optional(),
  })
  .refine((value) => Object.keys(value).length > 0, {
    message: 'Provide at least one field to update.',
  });
export type EmployeeUpdateRequest = z.infer<typeof employeeUpdateSchema>;

export const employeeListQuerySchema = pageQuerySchema.extend({
  q: z.string().trim().min(1).max(200).optional(),
  role: workerRoleEnum.optional(),
  active: z
    .enum(['true', 'false'])
    .optional()
    .transform((v) => (v === undefined ? undefined : v === 'true')),
  sort: z.enum(['name', '-name', 'createdAt', '-createdAt']).default('name'),
});
export type EmployeeListQuery = z.infer<typeof employeeListQuerySchema>;

export class EmployeeDto {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
  @ApiProperty({
    enum: [
      'electrician',
      'plumber',
      'generalWorker',
      'carpenter',
      'welder',
      'helper',
      'painter',
      'mason',
      'hvacTechnician',
    ],
  })
  role!: string;
  @ApiProperty() email!: string;
  @ApiProperty() phone!: string;
  @ApiProperty({ minimum: 0, maximum: 23 }) workStartHour!: number;
  @ApiProperty({ minimum: 0, maximum: 23 }) workEndHour!: number;
  @ApiProperty({
    type: [Number],
    description: 'ISO-8601 weekdays, 1=Mon .. 7=Sun. Gates worker location telemetry.',
  })
  workingDays!: number[];
  @ApiPropertyOptional({ nullable: true }) latitude?: number | null;
  @ApiPropertyOptional({ nullable: true }) longitude?: number | null;
  @ApiProperty() isActive!: boolean;
  @ApiPropertyOptional({ format: 'date-time' }) createdAt?: string;
  @ApiPropertyOptional({ format: 'date-time' }) updatedAt?: string;
}

export class PagedEmployeesDto {
  @ApiProperty({ type: [EmployeeDto] }) items!: EmployeeDto[];
  @ApiProperty() page!: { limit: number; nextCursor?: string; total?: number };
}
