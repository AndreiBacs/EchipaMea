import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { AppConfig } from '../common/config/configuration';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';

@Module({
  imports: [
    MulterModule.registerAsync({
      inject: [AppConfig],
      useFactory: (config: AppConfig) => ({
        // Memory storage: files go straight to the object store, so writing
        // them to a temp directory first would only add I/O and cleanup.
        // Bounded by the same limit the service enforces.
        limits: {
          fileSize: config.uploadMaxFileBytes,
          files: config.uploadMaxFiles,
        },
      }),
    }),
  ],
  controllers: [MediaController],
  providers: [MediaService],
  exports: [MediaService],
})
export class MediaModule {}
