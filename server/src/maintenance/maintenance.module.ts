import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { MediaModule } from '../media/media.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { TelemetryModule } from '../telemetry/telemetry.module';
import { RetentionService } from './retention.service';

/** Housekeeping that runs on its own: the nightly retention job. */
@Module({
  imports: [
    ScheduleModule.forRoot(),
    TelemetryModule,
    RealtimeModule,
    MediaModule,
    NotificationsModule,
  ],
  providers: [RetentionService],
  exports: [RetentionService],
})
export class MaintenanceModule {}
