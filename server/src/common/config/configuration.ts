import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from './env.schema';

/**
 * Typed accessor over the validated environment.
 *
 * Everything here is already parsed and coerced by `env.schema.ts`, so callers
 * get real numbers and booleans rather than strings.
 */
@Injectable()
export class AppConfig {
  constructor(private readonly config: ConfigService<Env, true>) {}

  private get<K extends keyof Env>(key: K): Env[K] {
    return this.config.get(key, { infer: true });
  }

  get nodeEnv(): Env['NODE_ENV'] {
    return this.get('NODE_ENV');
  }
  get isProduction(): boolean {
    return this.nodeEnv === 'production';
  }
  get isTest(): boolean {
    return this.nodeEnv === 'test';
  }
  get port(): number {
    return this.get('PORT');
  }
  get logLevel(): string {
    return this.get('LOG_LEVEL');
  }

  /** `*` means "reflect the request origin"; otherwise an explicit allowlist. */
  get corsOrigins(): string[] | true {
    const raw = this.get('CORS_ORIGINS').trim();
    if (raw === '*') return true;
    return raw
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean);
  }

  // --- JWT -----------------------------------------------------------------
  get jwtAlg(): 'RS256' | 'HS256' {
    return this.get('JWT_ALG');
  }
  get jwtIssuer(): string {
    return this.get('JWT_ISSUER');
  }
  get jwtAudience(): string {
    return this.get('JWT_AUDIENCE');
  }
  get foremanAccessTtl(): string {
    return this.get('JWT_FOREMAN_ACCESS_TTL');
  }
  get workerAccessTtl(): string {
    return this.get('JWT_WORKER_ACCESS_TTL');
  }
  get foremanRefreshTtlDays(): number {
    return this.get('REFRESH_FOREMAN_TTL_DAYS');
  }
  get workerRefreshTtlDays(): number {
    return this.get('REFRESH_WORKER_TTL_DAYS');
  }

  /** PEM private key (RS256) or shared secret (HS256). */
  get jwtSigningKey(): string {
    if (this.jwtAlg === 'HS256') return this.get('JWT_SECRET') ?? '';
    return unescapePem(this.get('JWT_PRIVATE_KEY') ?? '');
  }

  /** PEM public key (RS256) or shared secret (HS256). */
  get jwtVerificationKey(): string {
    if (this.jwtAlg === 'HS256') return this.get('JWT_SECRET') ?? '';
    return unescapePem(this.get('JWT_PUBLIC_KEY') ?? '');
  }

  // --- Worker QR login -----------------------------------------------------
  get workerLoginTicketTtlSeconds(): number {
    return this.get('WORKER_LOGIN_TICKET_TTL_SECONDS');
  }
  get appWorkerLoginUrl(): string | undefined {
    return this.get('APP_WORKER_LOGIN_URL');
  }

  // --- Realtime ------------------------------------------------------------
  get realtimeTicketTtlSeconds(): number {
    return this.get('REALTIME_TICKET_TTL_SECONDS');
  }
  get realtimeHeartbeatIntervalMs(): number {
    return this.get('REALTIME_HEARTBEAT_INTERVAL_MS');
  }
  get realtimeAccessTokenInQuery(): boolean {
    return this.get('REALTIME_ACCESS_TOKEN_IN_QUERY');
  }

  // --- Transition flags ----------------------------------------------------
  get allowAnonymousWorkerReports(): boolean {
    return this.get('ALLOW_ANONYMOUS_WORKER_REPORTS');
  }
  get realtimeAllowAnonymous(): boolean {
    return this.get('REALTIME_ALLOW_ANONYMOUS');
  }
  get defaultCompanyId(): string | undefined {
    return this.get('DEFAULT_COMPANY_ID');
  }
  get phaseTransitionsLenient(): boolean {
    return this.get('PHASE_TRANSITIONS_LENIENT');
  }

  // --- Storage -------------------------------------------------------------
  get storageDriver(): 'local' | 's3' {
    return this.get('STORAGE_DRIVER');
  }
  get storageLocalDir(): string {
    return this.get('STORAGE_LOCAL_DIR');
  }
  get storagePublicBaseUrl(): string {
    return this.get('STORAGE_PUBLIC_BASE_URL').replace(/\/+$/, '');
  }
  get s3Endpoint(): string | undefined {
    return this.get('S3_ENDPOINT');
  }
  get s3Region(): string {
    return this.get('S3_REGION');
  }
  get s3Bucket(): string {
    return this.get('S3_BUCKET') ?? '';
  }
  get s3AccessKeyId(): string {
    return this.get('S3_ACCESS_KEY_ID') ?? '';
  }
  get s3SecretAccessKey(): string {
    return this.get('S3_SECRET_ACCESS_KEY') ?? '';
  }
  get s3ForcePathStyle(): boolean {
    return this.get('S3_FORCE_PATH_STYLE');
  }
  get s3SignedUrlTtlSeconds(): number {
    return this.get('S3_SIGNED_URL_TTL_SECONDS');
  }

  // --- Uploads -------------------------------------------------------------
  get uploadMaxFileBytes(): number {
    return this.get('UPLOAD_MAX_FILE_BYTES');
  }
  get uploadMaxFiles(): number {
    return this.get('UPLOAD_MAX_FILES');
  }

  get locationSampleRetentionDays(): number {
    return this.get('LOCATION_SAMPLE_RETENTION_DAYS');
  }

  // --- Seeding -------------------------------------------------------------
  get seedDemo(): boolean {
    return this.get('SEED_DEMO');
  }
  get seedForemanEmail(): string {
    return this.get('SEED_FOREMAN_EMAIL');
  }
  get seedForemanPassword(): string {
    return this.get('SEED_FOREMAN_PASSWORD');
  }
}

/** Env vars cannot hold real newlines, so PEM keys arrive with escaped ones. */
function unescapePem(value: string): string {
  return value.includes('\\n') ? value.replace(/\\n/g, '\n') : value;
}
