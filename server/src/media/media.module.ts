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
          // +1: busboy flags a file once it *reaches* this size, which would
          // make the real ceiling one byte under UPLOAD_MAX_FILE_BYTES. The
          // service's own `> limit` check is the one that decides.
          fileSize: config.uploadMaxFileBytes + 1,
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
