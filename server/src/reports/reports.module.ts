import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { AppConfig } from '../common/config/configuration';
import { MediaModule } from '../media/media.module';
import { PhasesModule } from '../phases/phases.module';
import { RealtimeCoreModule } from '../realtime/realtime-core.module';
import { WorkerReportsController } from './worker-reports.controller';
import { WorkerReportsService } from './worker-reports.service';

@Module({
  imports: [
    MediaModule,
    PhasesModule,
    RealtimeCoreModule,
    MulterModule.registerAsync({
      inject: [AppConfig],
      useFactory: (config: AppConfig) => ({
        limits: {
          // +1: busboy flags a file once it *reaches* this size, which would
          // make the real ceiling one byte under UPLOAD_MAX_FILE_BYTES. The
          // service's own `> limit` check is the one that decides.
          fileSize: config.uploadMaxFileBytes + 1,
          // The worker UI caps photos at 8; the configured ceiling leaves room
          // for the voice memo and for that cap to be raised client-side.
          files: config.uploadMaxFiles,
        },
      }),
    }),
  ],
  controllers: [WorkerReportsController],
  providers: [WorkerReportsService],
  exports: [WorkerReportsService],
})
export class ReportsModule {}
