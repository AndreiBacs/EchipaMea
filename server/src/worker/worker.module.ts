import { Module } from '@nestjs/common';
import { RealtimeCoreModule } from '../realtime/realtime-core.module';
import { WorkerController } from './worker.controller';
import { WorkerService } from './worker.service';

/**
 * Imports `RealtimeCoreModule` for the registry only -- an arrival has to reach
 * the foreman's socket. Not `RealtimeModule`, which imports the report handling
 * that would eventually import back here.
 */
@Module({
  imports: [RealtimeCoreModule],
  controllers: [WorkerController],
  providers: [WorkerService],
  exports: [WorkerService],
})
export class WorkerModule {}
