import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';

export const loginRequestSchema = z.object({
  email: z.string().trim().min(1, 'Email is required.').email('Must be a valid email address.'),
  password: z.string().min(1, 'Password is required.'),
});
export type LoginRequest = z.infer<typeof loginRequestSchema>;

export const refreshRequestSchema = z.object({
  refreshToken: z.string().min(1, 'refreshToken is required.'),
});
export type RefreshRequest = z.infer<typeof refreshRequestSchema>;

export const logoutRequestSchema = z.object({
  refreshToken: z.string().min(1).optional(),
});
export type LogoutRequest = z.infer<typeof logoutRequestSchema>;

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1, 'currentPassword is required.'),
  newPassword: z
    .string()
    .min(8, 'New password must be at least 8 characters.')
    .max(200, 'New password is too long.'),
});
export type ChangePasswordRequest = z.infer<typeof changePasswordSchema>;

// --- OpenAPI response shapes ------------------------------------------------

export class LoginUserDto {
  @ApiProperty() id!: string;
  @ApiProperty() email!: string;
  @ApiProperty({ enum: ['foreman', 'admin'] }) role!: string;
  @ApiProperty() companyId!: string;
  @ApiProperty() fullName!: string;
}

export class LoginResponseDto {
  @ApiProperty({
    deprecated: true,
    description:
      'Alias of `accessToken`. Emitted because the current Flutter client reads ' +
      '`token ?? accessToken`. Will be removed once the client is rewired.',
  })
  token!: string;

  @ApiProperty() accessToken!: string;
  @ApiProperty({ example: 'Bearer' }) tokenType!: string;
  @ApiProperty({ description: 'Access-token lifetime in seconds.' }) expiresIn!: number;
  @ApiProperty({ description: 'Opaque rotating refresh token.' }) refreshToken!: string;
  @ApiProperty({ description: 'Refresh-token lifetime in seconds.' }) refreshExpiresIn!: number;
  @ApiProperty({ type: LoginUserDto }) user!: LoginUserDto;
}

export class WorkerIdentityDto {
  @ApiProperty() employeeId!: string;
  @ApiProperty() employeeName!: string;
  @ApiProperty({ enum: ['worker'] }) role!: string;
  @ApiProperty() companyId!: string;
}

export class WorkerSessionResponseDto {
  @ApiProperty({ deprecated: true, description: 'Alias of `accessToken`.' }) token!: string;
  @ApiProperty() accessToken!: string;
  @ApiProperty({ example: 'Bearer' }) tokenType!: string;
  @ApiProperty() expiresIn!: number;
  @ApiProperty() refreshToken!: string;
  @ApiProperty() refreshExpiresIn!: number;
  @ApiProperty({ type: WorkerIdentityDto }) worker!: WorkerIdentityDto;
}

export class CurrentPrincipalDto {
  @ApiProperty({ enum: ['foreman', 'admin', 'worker'] }) role!: string;
  @ApiProperty() companyId!: string;
  @ApiPropertyOptional() userId?: string;
  @ApiPropertyOptional() employeeId?: string;
  @ApiPropertyOptional() email?: string;
  @ApiProperty() displayName!: string;
}
