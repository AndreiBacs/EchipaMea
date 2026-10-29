import { Global, Module } from '@nestjs/common';
import { AppConfig } from '../../common/config/configuration';
import { LocalStorageService } from './local.storage';
import { S3StorageService } from './s3.storage';
import { STORAGE_SERVICE, type StorageService } from './storage.interface';

@Global()
@Module({
  providers: [
    {
      provide: STORAGE_SERVICE,
      inject: [AppConfig],
      useFactory: (config: AppConfig): StorageService =>
        config.storageDriver === 's3'
          ? new S3StorageService(config)
          : new LocalStorageService(config),
    },
  ],
  exports: [STORAGE_SERVICE],
})
export class StorageModule {}
