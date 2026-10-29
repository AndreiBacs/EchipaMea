import { Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import type { Principal } from '../common/auth/principal';
import { AppConfig } from '../common/config/configuration';
import { CurrentPrincipal } from '../common/decorators/current-principal.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AppException } from '../common/errors/app-exception';
import { ConnectionRegistryService } from './connection-registry.service';

/**
 * Hooks for the Flutter app's end-to-end suite, which drives the real app
 * against this server. They answer 404, exactly like a missing route, unless
 * E2E_TEST_HOOKS=true, and are left out of the OpenAPI spec.
 *
 * Even when enabled they need a foreman token and only touch that foreman's
 * own company.
 */
@ApiExcludeController()
@Controller('__e2e')
export class E2eHooksController {
  constructor(
    private readonly config: AppConfig,
    private readonly registry: ConnectionRegistryService,
  ) {}

  /** Drops the company's foreman sockets, so the suite can watch the app reconnect. */
  @Roles('foreman', 'admin')
  @Post('realtime/drop-foremen')
  @HttpCode(HttpStatus.OK)
  dropForemen(@CurrentPrincipal() principal: Principal): { closed: number } {
    if (!this.config.e2eTestHooks) throw AppException.notFound('Route');
    return { closed: this.registry.disconnectForemen(principal.companyId) };
  }
}
