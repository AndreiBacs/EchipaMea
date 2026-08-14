import { Global, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerGuard } from '@nestjs/throttler';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { TenantGuard } from './guards/tenant.guard';
import { PasswordService } from './password.service';
import { TokenService } from './token.service';
import { WorkerAuthController } from './worker-auth.controller';
import { WorkerTicketService } from './worker-ticket.service';

/**
 * Guard order is significant and is the order they are registered in:
 *
 *   JwtAuthGuard  -> establishes the principal (or rejects)
 *   RolesGuard    -> fail-closed role check against that principal
 *   TenantGuard   -> asserts a tenant and rejects cross-tenant references
 *   ThrottlerGuard-> rate limiting
 */
@Global()
@Module({
  imports: [JwtModule.register({})],
  controllers: [AuthController, WorkerAuthController],
  providers: [
    AuthService,
    PasswordService,
    TokenService,
    WorkerTicketService,
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: TenantGuard },
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
  exports: [AuthService, TokenService, PasswordService, WorkerTicketService],
})
export class AuthModule {}
