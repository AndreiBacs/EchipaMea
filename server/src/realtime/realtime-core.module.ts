import { Global, Module } from '@nestjs/common';
import { ConnectionRegistryService } from './connection-registry.service';

/**
 * The socket registry on its own, with no gateways and no domain imports.
 *
 * Publishers (worker reports, and notifications next) need to fan out; the
 * gateways need those same domain services to handle inbound frames. Splitting
 * the registry out is what keeps that from being an import cycle.
 */
@Global()
@Module({
  providers: [ConnectionRegistryService],
  exports: [ConnectionRegistryService],
})
export class RealtimeCoreModule {}
