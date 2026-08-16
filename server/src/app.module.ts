import { Module } from '@nestjs/common';
import { APP_FILTER } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { EmployeesModule } from './employees/employees.module';
import { PhasesModule } from './phases/phases.module';
import { ProjectsModule } from './projects/projects.module';
import { SequencesModule } from './sequences/sequences.module';
import { ClientsModule } from './clients/clients.module';
import { AppConfigModule } from './common/config/config.module';
import { RequestContextModule } from './common/context/request-context.module';
import { AllExceptionsFilter } from './common/errors/all-exceptions.filter';
import { PrismaModule } from './common/prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { StorageModule } from './media/storage/storage.module';

@Module({
  imports: [
    AppConfigModule,
    // Establishes the per-request CLS context and assigns the trace id; see
    // RequestContextModule for why that happens in the CLS setup hook.
    RequestContextModule,
    PrismaModule,
    StorageModule,
    ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: 300 }]),
    AuthModule,
    ClientsModule,
    EmployeesModule,
    ProjectsModule,
    PhasesModule,
    SequencesModule,
    HealthModule,
  ],
  providers: [{ provide: APP_FILTER, useClass: AllExceptionsFilter }],
})
export class AppModule {}
