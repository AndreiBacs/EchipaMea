import { Module } from '@nestjs/common';
import { ProjectStatusService } from './project-status.service';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';

@Module({
  controllers: [ProjectsController],
  providers: [ProjectsService, ProjectStatusService],
  exports: [ProjectsService, ProjectStatusService],
})
export class ProjectsModule {}
