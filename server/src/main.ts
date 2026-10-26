import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { configureApp } from './bootstrap/configure-app';
import { AppConfig } from './common/config/configuration';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: true,
  });

  const config = app.get(AppConfig);
  const logger = new Logger('Bootstrap');

  configureApp(app, config);

  await app.listen(config.port, '0.0.0.0');
  logger.log(`EchipaMea API listening on port ${config.port} (${config.nodeEnv})`);
  logger.log(`Storage driver: ${config.storageDriver}`);

  if (config.phaseTransitionsLenient) {
    logger.warn(
      'PHASE_TRANSITIONS_LENIENT is ON: illegal phase transitions are allowed through. ' +
        'This exists for the client migration window only.',
    );
  }
}

void bootstrap();
