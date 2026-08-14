import { Module } from '@nestjs/common';
import { ProjectsModule } from '../projects/projects.module';
import { PhaseLifecycleService } from './phase-lifecycle.service';
import { PhasesController } from './phases.controller';
import { PhasesService } from './phases.service';

@Module({
  imports: [ProjectsModule],
  controllers: [PhasesController],
  providers: [PhasesService, PhaseLifecycleService],
  exports: [PhasesService, PhaseLifecycleService],
})
export class PhasesModule {}
