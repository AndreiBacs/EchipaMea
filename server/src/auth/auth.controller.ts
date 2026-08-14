import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  ApiBody,
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { CurrentForeman, CurrentPrincipal } from '../common/decorators/current-principal.decorator';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { zodBody } from '../common/pipes/zod-validation.pipe';
import type { ForemanPrincipal, Principal } from '../common/auth/principal';
import { AuthService, type RequestMeta } from './auth.service';
import {
  ChangePasswordRequest,
  CurrentPrincipalDto,
  LoginRequest,
  LoginResponseDto,
  RefreshRequest,
  changePasswordSchema,
  loginRequestSchema,
  refreshRequestSchema,
} from './dto/auth.dto';

@ApiTags('Auth')
@Controller()
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /**
   * Path and body shape are fixed by the existing client, which posts
   * `{email, password}` to `AUTH_API_BASE_URL + /foreman/login`.
   */
  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('foreman/login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    operationId: 'foremanLogin',
    summary: 'Foreman login',
    description:
      'Public. Returns the access token under both `token` and `accessToken`: the former ' +
      'for the current Flutter client, the latter as the forward-looking name.',
  })
  @ApiBody({ schema: { type: 'object', required: ['email', 'password'], properties: { email: { type: 'string', format: 'email' }, password: { type: 'string', minLength: 1 } } } })
  @ApiOkResponse({ type: LoginResponseDto, description: 'Authenticated.' })
  login(
    @Body(zodBody(loginRequestSchema)) body: LoginRequest,
    @Req() request: Request,
  ): Promise<LoginResponseDto> {
    return this.auth.loginForeman(body.email, body.password, metaOf(request));
  }

  @Public()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('auth/refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    operationId: 'refreshToken',
    summary: 'Exchange a refresh token for a new session',
    description:
      'Rotating: each call invalidates the presented token. Replaying an already-rotated ' +
      'token revokes the whole session family and returns 401 TOKEN_REUSED.',
  })
  @ApiOkResponse({ type: LoginResponseDto })
  refresh(
    @Body(zodBody(refreshRequestSchema)) body: RefreshRequest,
    @Req() request: Request,
  ): Promise<LoginResponseDto> {
    return this.auth.refresh(body.refreshToken, metaOf(request));
  }

  @Roles('foreman', 'admin', 'worker')
  @Post('auth/logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    operationId: 'logout',
    summary: 'Revoke the current session',
    description: 'Idempotent. Revokes every refresh token in the caller session family.',
  })
  @ApiNoContentResponse({ description: 'Session revoked.' })
  async logout(@CurrentPrincipal() principal: Principal): Promise<void> {
    await this.auth.logout(principal);
  }

  @Roles('foreman', 'admin', 'worker')
  @Get('auth/me')
  @ApiOperation({
    operationId: 'getCurrentPrincipal',
    summary: 'Describe the authenticated principal',
  })
  @ApiOkResponse({ type: CurrentPrincipalDto })
  me(@CurrentPrincipal() principal: Principal): Promise<CurrentPrincipalDto> {
    return this.auth.describePrincipal(principal);
  }

  @Post('auth/password')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    operationId: 'changePassword',
    summary: 'Change the signed-in foreman password',
    description: 'Revokes all other sessions for the account on success.',
  })
  @ApiCreatedResponse({ description: 'Password changed.' })
  async changePassword(
    @CurrentForeman() principal: ForemanPrincipal,
    @Body(zodBody(changePasswordSchema)) body: ChangePasswordRequest,
  ): Promise<void> {
    await this.auth.changePassword(principal, body.currentPassword, body.newPassword);
  }
}

export function metaOf(request: Request): RequestMeta {
  const userAgent = request.headers['user-agent'];
  return {
    ip: request.ip,
    userAgent: typeof userAgent === 'string' ? userAgent.slice(0, 500) : undefined,
  };
}
