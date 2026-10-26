import { zodToJsonSchema } from 'zod-to-json-schema';
import type { ZodTypeAny } from 'zod';

// The library's generic signature recurses through the whole zod type and
// trips TS2589 ("excessively deep") on the larger request schemas. The result
// is plain JSON either way, so call it through a deliberately loose type.
const convert = zodToJsonSchema as unknown as (
  schema: ZodTypeAny,
  options: Record<string, unknown>,
) => Record<string, unknown>;

/**
 * JSON Schema for what a client *sends*: `effectStrategy: 'input'` documents
 * the shape before transforms and defaults are applied.
 */
export function zodToJson(
  schema: ZodTypeAny,
  target: 'openApi3' | 'jsonSchema7',
): Record<string, unknown> {
  const json = convert(schema, { target, $refStrategy: 'none', effectStrategy: 'input' });
  delete json.$schema;
  return json;
}
