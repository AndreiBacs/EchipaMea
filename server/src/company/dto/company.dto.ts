import { ApiProperty } from '@nestjs/swagger';
import { z } from 'zod';

/**
 * Company details, replacing the SharedPreferences blob in
 * `profile_controller.dart`.
 *
 * That blob mixes two things the server keeps apart: fields belonging to the
 * *person* (fullName, phone, jobTitle) and fields belonging to the *company*
 * (name, address, fiscal identifiers). One foreman editing "company IBAN" is
 * editing a shared record; one editing "my phone" is not.
 */
export const companyUpdateSchema = z
  .object({
    name: z.string().trim().min(1, 'Company name is required.').max(200).optional(),
    addressLine1: z.string().trim().max(300).optional(),
    city: z.string().trim().max(120).optional(),
    state: z.string().trim().max(120).optional(),
    zipCode: z.string().trim().max(30).optional(),
    iban: z.string().trim().max(50).optional(),
    cui: z.string().trim().max(30).optional(),
    vatNumber: z.string().trim().max(30).optional(),
    regCom: z.string().trim().max(50).optional(),
  })
  .refine((value) => Object.keys(value).length > 0, {
    message: 'Provide at least one field to update.',
  });
export type CompanyUpdateRequest = z.infer<typeof companyUpdateSchema>;

export class CompanyDto {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
  @ApiProperty() addressLine1!: string;
  @ApiProperty() city!: string;
  @ApiProperty() state!: string;
  @ApiProperty() zipCode!: string;
  @ApiProperty({
    description:
      'Derived: the address parts joined for display. The app currently stores the address as ' +
      'one free-text field, so this is what it binds to until that form is split.',
  })
  addressLine!: string;
  @ApiProperty() iban!: string;
  @ApiProperty({ description: 'Romanian fiscal code (CUI).' }) cui!: string;
  @ApiProperty() vatNumber!: string;
  @ApiProperty({ description: 'Romanian trade register number (Nr. Reg. Com.).' })
  regCom!: string;
}

export const profileUpdateSchema = z
  .object({
    fullName: z.string().trim().max(200).optional(),
    phone: z.string().trim().max(50).optional(),
    jobTitle: z.string().trim().max(120).optional(),
  })
  .refine((value) => Object.keys(value).length > 0, {
    message: 'Provide at least one field to update.',
  });
export type ProfileUpdateRequest = z.infer<typeof profileUpdateSchema>;

export class ForemanProfileDto {
  @ApiProperty() userId!: string;
  @ApiProperty() email!: string;
  @ApiProperty({ enum: ['foreman', 'admin'] }) role!: string;
  @ApiProperty() fullName!: string;
  @ApiProperty() phone!: string;
  @ApiProperty() jobTitle!: string;
  @ApiProperty() companyId!: string;
  @ApiProperty() companyName!: string;
}
