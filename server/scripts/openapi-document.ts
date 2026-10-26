/**
 * Builds the OpenAPI document from the running code, so the contract cannot
 * drift from the routes that actually exist.
 *
 * Three sources, merged:
 *   - `@nestjs/swagger` metadata already on every controller: operations,
 *     tags, parameters and response DTOs.
 *   - The zod schemas behind `zodBody(...)`: the same definition that
 *     validates a request now documents it, so a body cannot be validated one
 *     way and documented another.
 *   - Cross-cutting facts no decorator states: bearer auth (and which routes
 *     are `@Public`), the error envelope, and the error statuses every guarded
 *     route can return.
 *
 * Boots the app in preview mode: controllers are scanned but no provider is
 * instantiated, so no database is needed.
 */
import 'reflect-metadata';
import { readFileSync } from 'fs';
import * as path from 'path';
import { ROUTE_ARGS_METADATA } from '@nestjs/common/constants';
import { RouteParamtypes } from '@nestjs/common/enums/route-paramtypes.enum';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule, type OpenAPIObject } from '@nestjs/swagger';
import type {
  OperationObject,
  ParameterObject,
  ReferenceObject,
  RequestBodyObject,
  ResponseObject,
  SchemaObject,
} from '@nestjs/swagger/dist/interfaces/open-api-spec.interface';
import type { ZodTypeAny } from 'zod';
import { zodToJson } from './zod-json';

const SERVER_ROOT = path.resolve(__dirname, '..');

type JsonSchema = SchemaObject & Record<string, unknown>;

interface HandlerFacts {
  isPublic: boolean;
  body?: ZodTypeAny;
  query?: ZodTypeAny;
}

const HTTP_METHODS = ['get', 'put', 'post', 'delete', 'patch', 'options', 'head'] as const;

/**
 * Environment the app needs in order to *construct*, never to run. Set before
 * AppModule is imported, because `ConfigModule.forRoot()` validates on import.
 */
function prepareEnv(): void {
  Object.assign(process.env, {
    NODE_ENV: 'test',
    DATABASE_URL: 'postgresql://spec:spec@localhost:5432/spec_generation_only',
    JWT_ALG: 'HS256',
    JWT_SECRET: 'spec-generation-only-not-a-secret-0123456789',
    STORAGE_DRIVER: 'local',
    PHASE_TRANSITIONS_LENIENT: 'false',
    SEED_DEMO: 'false',
  });
}

export async function buildOpenApiDocument(): Promise<OpenAPIObject> {
  prepareEnv();
  // Imported late on purpose -- see prepareEnv().
  const { AppModule } = await import('../src/app.module');
  const { IS_PUBLIC_KEY } = await import('../src/common/decorators/public.decorator');
  const { ZodValidationPipe } = await import('../src/common/pipes/zod-validation.pipe');
  const { ErrorCode } = await import('../src/common/errors/error-codes');

  const app = await NestFactory.create(AppModule, {
    preview: true,
    logger: false,
    abortOnError: false,
  });

  const pkg = JSON.parse(readFileSync(path.join(SERVER_ROOT, 'package.json'), 'utf8')) as {
    version: string;
  };

  const config = new DocumentBuilder()
    .setTitle('EchipaMea API')
    .setVersion(pkg.version)
    .setDescription(
      'Generated from the server code by `npm run spec:generate`; do not edit by hand. ' +
        '`npm run spec:check` fails CI when this file is out of date.\n\n' +
        'Every route except those marked `security: []` requires `Authorization: Bearer ' +
        '<token>`, where the token names a company. Errors use one envelope: ' +
        '`{ error: { code, message, field? }, traceId? }`. Realtime channels are ' +
        'described in `websockets-asyncapi-draft.yaml`.',
    )
    .addServer('http://localhost:3000', 'Local development')
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'bearerAuth')
    .addSecurityRequirements('bearerAuth')
    .build();

  const document = SwaggerModule.createDocument(app, config, {
    operationIdFactory: (_controllerKey, methodKey) => methodKey,
  });

  const facts = collectHandlerFacts(app, IS_PUBLIC_KEY, ZodValidationPipe);
  await app.close();

  document.components ??= {};
  document.components.schemas ??= {};
  document.components.schemas.ErrorResponse = errorResponseSchema(Object.values(ErrorCode));
  document.components.responses = {
    ...document.components.responses,
    ...standardErrorResponses(),
  };

  for (const [route, item] of Object.entries(document.paths)) {
    for (const method of HTTP_METHODS) {
      const operation = item[method];
      if (!operation?.operationId) continue;
      const handler = facts.get(operation.operationId);
      if (!handler) {
        throw new Error(`No handler metadata for ${method.toUpperCase()} ${route}`);
      }
      applyZodSchemas(operation, handler);
      applySecurityAndErrors(operation, handler, route);
    }
  }

  document.tags = collectTags(document);
  return sortDocument(document);
}

/** Maps each `operationId` to what its handler's metadata says. */
function collectHandlerFacts(
  app: Awaited<ReturnType<typeof NestFactory.create>>,
  isPublicKey: string,
  zodPipe: abstract new (...args: never[]) => { schema: ZodTypeAny },
): Map<string, HandlerFacts> {
  const result = new Map<string, HandlerFacts>();
  // `container` is not on the public INestApplication type, but it is what
  // SwaggerModule itself scans.
  const container = (app as unknown as { container: { getModules(): Map<string, unknown> } })
    .container;

  for (const module of container.getModules().values()) {
    const controllers = (module as { controllers: Map<unknown, { metatype: unknown }> })
      .controllers;
    for (const wrapper of controllers.values()) {
      const metatype = wrapper.metatype as (new (...args: never[]) => object) | undefined;
      if (!metatype) continue;
      const prototype = metatype.prototype as Record<string, unknown>;

      for (const key of Object.getOwnPropertyNames(prototype)) {
        const handler = prototype[key];
        if (key === 'constructor' || typeof handler !== 'function') continue;
        const operation = Reflect.getMetadata('swagger/apiOperation', handler) as
          { operationId?: string } | undefined;
        if (!operation?.operationId) continue;

        const facts: HandlerFacts = {
          isPublic: Boolean(
            Reflect.getMetadata(isPublicKey, handler) ?? Reflect.getMetadata(isPublicKey, metatype),
          ),
        };

        const args = (Reflect.getMetadata(ROUTE_ARGS_METADATA, metatype, key) ?? {}) as Record<
          string,
          { pipes?: unknown[] }
        >;
        for (const [argKey, arg] of Object.entries(args)) {
          const paramtype: RouteParamtypes = Number(argKey.split(':')[0]);
          const pipe = arg.pipes?.find((p): p is { schema: ZodTypeAny } => p instanceof zodPipe);
          if (!pipe) continue;
          if (paramtype === RouteParamtypes.BODY) facts.body = pipe.schema;
          if (paramtype === RouteParamtypes.QUERY) facts.query = pipe.schema;
        }

        if (result.has(operation.operationId)) {
          throw new Error(`Duplicate operationId "${operation.operationId}"`);
        }
        result.set(operation.operationId, facts);
      }
    }
  }
  return result;
}

function toJsonSchema(schema: ZodTypeAny): JsonSchema {
  return zodToJson(schema, 'openApi3');
}

function applyZodSchemas(operation: OperationObject, facts: HandlerFacts): void {
  if (facts.body && !hasExplicitBody(operation.requestBody)) {
    operation.requestBody = {
      required: true,
      content: { 'application/json': { schema: toJsonSchema(facts.body) } },
    };
  }

  if (facts.query) {
    const schema = toJsonSchema(facts.query);
    const properties = (schema.properties ?? {}) as Record<string, JsonSchema>;
    const required = new Set(schema.required ?? []);
    const parameters = (operation.parameters ??= []);

    for (const [name, property] of Object.entries(properties)) {
      const existing = parameters.find(
        (p): p is ParameterObject => 'in' in p && p.in === 'query' && p.name === name,
      );
      const description = property.description;
      delete property.description;
      if (existing) {
        // An explicit @ApiQuery keeps its prose; the schema comes from zod.
        existing.schema = property;
        existing.required = required.has(name);
      } else {
        parameters.push({
          name,
          in: 'query',
          required: required.has(name),
          schema: property,
          ...(description ? { description } : {}),
        });
      }
    }
  }
}

/**
 * True when a body was declared deliberately (`@ApiBody`, e.g. multipart),
 * as opposed to the empty placeholder Swagger infers from an untyped `@Body()`.
 */
function hasExplicitBody(body: RequestBodyObject | ReferenceObject | undefined): boolean {
  if (!body || '$ref' in body) return Boolean(body);
  return Object.values(body.content ?? {}).some((media) => {
    const schema = media.schema as JsonSchema | undefined;
    return Boolean(schema && (schema.$ref || schema.properties || schema.allOf || schema.oneOf));
  });
}

function applySecurityAndErrors(
  operation: OperationObject,
  facts: HandlerFacts,
  route: string,
): void {
  const responses = operation.responses;
  const add = (status: string, name: string) => {
    responses[status] ??= { $ref: `#/components/responses/${name}` };
  };

  if (facts.body || facts.query) add('400', 'BadRequest');
  if (facts.isPublic) {
    operation.security = [];
  } else {
    add('401', 'Unauthorized');
    add('403', 'Forbidden');
  }
  if (route.includes('{')) add('404', 'NotFound');
  add('429', 'TooManyRequests');
}

function errorResponseSchema(codes: string[]): SchemaObject {
  return {
    type: 'object',
    required: ['error'],
    properties: {
      error: {
        type: 'object',
        required: ['code', 'message'],
        properties: {
          code: { type: 'string', enum: [...new Set(codes)].sort() },
          message: { type: 'string' },
          field: {
            type: 'string',
            description: 'Dotted path of the offending input, for validation errors.',
          },
        },
      },
      traceId: {
        type: 'string',
        description: 'Also sent as the `x-trace-id` response header.',
      },
    },
  };
}

function standardErrorResponses(): Record<string, ResponseObject> {
  const envelope: ResponseObject['content'] = {
    'application/json': { schema: { $ref: '#/components/schemas/ErrorResponse' } },
  };
  return {
    BadRequest: { description: 'Validation failed (`VALIDATION_FAILED`).', content: envelope },
    Unauthorized: {
      description: 'Missing, invalid, expired or revoked token (`UNAUTHENTICATED`, `TOKEN_*`).',
      content: envelope,
    },
    Forbidden: {
      description: 'Authenticated, but the role or account may not do this.',
      content: envelope,
    },
    NotFound: {
      description:
        'No such resource in the caller’s company. Never 403: that would confirm the id.',
      content: envelope,
    },
    TooManyRequests: { description: 'Rate limited (`RATE_LIMITED`).', content: envelope },
  };
}

function collectTags(document: OpenAPIObject): { name: string }[] {
  const names = new Set<string>();
  for (const item of Object.values(document.paths)) {
    for (const method of HTTP_METHODS) {
      for (const tag of item[method]?.tags ?? []) names.add(tag);
    }
  }
  return [...names].sort().map((name) => ({ name }));
}

/** Stable output: paths and component schemas sorted, so diffs show real changes only. */
function sortDocument(document: OpenAPIObject): OpenAPIObject {
  const sortKeys = <T>(record: Record<string, T>): Record<string, T> =>
    Object.fromEntries(Object.entries(record).sort(([a], [b]) => a.localeCompare(b)));

  document.paths = sortKeys(document.paths);
  if (document.components?.schemas) {
    document.components.schemas = sortKeys(document.components.schemas);
  }
  if (document.components?.responses) {
    document.components.responses = sortKeys(document.components.responses);
  }
  return document;
}
