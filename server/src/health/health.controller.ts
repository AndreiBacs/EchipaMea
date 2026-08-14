import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../common/decorators/public.decorator';
import { PrismaService } from '../common/prisma/prisma.service';
import { STORAGE_SERVICE, type StorageService } from '../media/storage/storage.interface';
import { Inject } from '@nestjs/common';

interface CheckResult {
  status: 'up' | 'down';
  error?: string;
}

@ApiTags('Health')
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(STORAGE_SERVICE) private readonly storage: StorageService,
  ) {}

  @Public()
  @Get('live')
  @ApiOperation({
    operationId: 'getLiveness',
    summary: 'Liveness probe',
    description: 'Returns 200 as long as the process is running. Performs no I/O.',
  })
  @ApiOkResponse({ description: 'Process is alive.' })
  getLiveness(): { status: 'ok'; uptimeSeconds: number } {
    return { status: 'ok', uptimeSeconds: Math.floor(process.uptime()) };
  }

  @Public()
  @Get('ready')
  @ApiOperation({
    operationId: 'getReadiness',
    summary: 'Readiness probe',
    description: 'Checks the database and the object store. 503 when a dependency is unavailable.',
  })
  @ApiOkResponse({ description: 'All dependencies reachable.' })
  async getReadiness(): Promise<{
    status: 'ok' | 'degraded';
    checks: Record<string, CheckResult>;
  }> {
    const [database, storage] = await Promise.all([this.checkDatabase(), this.checkStorage()]);
    const checks = { database, storage };
    const status = Object.values(checks).every((c) => c.status === 'up') ? 'ok' : 'degraded';
    return { status, checks };
  }

  private async checkDatabase(): Promise<CheckResult> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { status: 'up' };
    } catch (error) {
      return { status: 'down', error: messageOf(error) };
    }
  }

  private async checkStorage(): Promise<CheckResult> {
    try {
      await this.storage.healthCheck();
      return { status: 'up' };
    } catch (error) {
      return { status: 'down', error: messageOf(error) };
    }
  }
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
