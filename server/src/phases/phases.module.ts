import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module';
import { ProjectsModule } from '../projects/projects.module';
import { PhaseLifecycleService } from './phase-lifecycle.service';
import { PhasesController } from './phases.controller';
import { PhasesService } from './phases.service';

@Module({
  imports: [ProjectsModule, MediaModule],
  controllers: [PhasesController],
  providers: [PhasesService, PhaseLifecycleService],
  exports: [PhasesService, PhaseLifecycleService],
})
export class PhasesModule {}
