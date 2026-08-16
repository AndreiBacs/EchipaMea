import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module';
import { ProjectStatusService } from './project-status.service';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';

@Module({
  imports: [MediaModule],
  controllers: [ProjectsController],
  providers: [ProjectsService, ProjectStatusService],
  exports: [ProjectsService, ProjectStatusService],
})
export class ProjectsModule {}
