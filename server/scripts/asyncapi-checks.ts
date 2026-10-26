/**
 * The AsyncAPI contract is hand-written -- its prose explains choices a
 * generator could not (why `employeeId` is accepted and ignored, why
 * `submittedAt` is kept verbatim) -- so instead of being regenerated it is
 * checked against the code that implements it.
 */
import { readFileSync, readdirSync } from 'fs';
import * as path from 'path';
import { parse } from 'yaml';
import type { ZodTypeAny } from 'zod';
import { ErrorCode } from '../src/common/errors/error-codes';
import {
  FrameType,
  workerLocationFrameSchema,
  workerReportSubmittedFrameSchema,
} from '../src/realtime/frames';
import { WS_PATHS } from '../src/realtime/realtime-ticket.service';
import { zodToJson } from './zod-json';

type Schema = {
  $ref?: string;
  properties?: Record<string, Schema>;
  required?: string[];
  const?: unknown;
  enum?: unknown[];
};

interface AsyncApiDocument {
  info: { version: string };
  channels: Record<string, { address: string }>;
  components: { messages: Record<string, { payload: Schema }>; schemas: Record<string, Schema> };
}

const REALTIME_SRC = path.resolve(__dirname, '..', 'src', 'realtime');

export function checkAsyncApi(source: string, expectedVersion: string): string[] {
  const doc = parse(source) as AsyncApiDocument;
  const problems: string[] = [];
  const resolve = (schema: Schema): Schema => {
    const name = schema.$ref?.split('/').pop();
    return name ? (doc.components.schemas[name] ?? {}) : schema;
  };

  if (doc.info.version !== expectedVersion) {
    problems.push(`info.version is ${doc.info.version}, package.json says ${expectedVersion}.`);
  }

  compareSets(
    'channel addresses',
    Object.values(doc.channels).map((c) => c.address),
    Object.values(WS_PATHS),
    problems,
  );

  const payloads = Object.values(doc.components.messages).map((m) => resolve(m.payload));
  const documentedTypes = payloads.map((p) => p.properties?.type?.const).filter(Boolean);
  compareSets('message types', documentedTypes as string[], Object.values(FrameType), problems);

  const inbound: [string, ZodTypeAny][] = [
    [FrameType.WORKER_LOCATION, workerLocationFrameSchema],
    [FrameType.WORKER_REPORT_SUBMITTED, workerReportSubmittedFrameSchema],
  ];
  for (const [type, zodSchema] of inbound) {
    const documented = payloads.find((p) => p.properties?.type?.const === type);
    if (!documented) continue; // already reported as a missing message type
    const actual = zodToJson(zodSchema, 'jsonSchema7') as Schema;
    compareSets(
      `${type} fields`,
      Object.keys(documented.properties ?? {}),
      Object.keys(actual.properties ?? {}),
      problems,
    );
    compareSets(`${type} required`, documented.required ?? [], actual.required ?? [], problems);
  }

  const errorPayload = payloads.find((p) => p.properties?.type?.const === FrameType.ERROR);
  const documentedCodes = new Set((errorPayload?.properties?.code?.enum ?? []) as string[]);
  const knownCodes = new Set<string>(Object.values(ErrorCode));
  for (const code of documentedCodes) {
    if (!knownCodes.has(code)) problems.push(`error code ${code} is documented but not defined.`);
  }
  for (const code of codesUsedInRealtime()) {
    if (!documentedCodes.has(code)) {
      problems.push(`error code ${code} is sent by src/realtime but missing from ErrorPayload.`);
    }
  }

  return problems;
}

/** `ErrorCode.X` references in the realtime module, resolved to their values. */
function codesUsedInRealtime(): Set<string> {
  const codes = new Set<string>();
  for (const file of readdirSync(REALTIME_SRC)) {
    if (!file.endsWith('.ts') || file.endsWith('.spec.ts')) continue;
    const text = readFileSync(path.join(REALTIME_SRC, file), 'utf8');
    for (const match of text.matchAll(/ErrorCode\.([A-Z_]+)/g)) {
      const value = (ErrorCode as Record<string, string>)[match[1]!];
      if (value) codes.add(value);
    }
  }
  return codes;
}

function compareSets(label: string, documented: string[], actual: string[], out: string[]): void {
  const doc = new Set(documented);
  const act = new Set(actual);
  const missing = [...act].filter((x) => !doc.has(x));
  const extra = [...doc].filter((x) => !act.has(x));
  if (missing.length) out.push(`${label}: in code but not documented: ${missing.join(', ')}`);
  if (extra.length) out.push(`${label}: documented but not in code: ${extra.join(', ')}`);
}
