import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { AppConfig } from '../common/config/configuration';
import { MediaModule } from '../media/media.module';
import { PhasesModule } from '../phases/phases.module';
import { WorkerReportsController } from './worker-reports.controller';
import { WorkerReportsService } from './worker-reports.service';

@Module({
  imports: [
    MediaModule,
    PhasesModule,
    MulterModule.registerAsync({
      inject: [AppConfig],
      useFactory: (config: AppConfig) => ({
        limits: {
          fileSize: config.uploadMaxFileBytes,
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
