/**
 * `npm run spec:generate` (part 1): writes docs/backend-openapi.yaml.
 */
import { writeFileSync } from 'fs';
import { buildOpenApiDocument } from './openapi-document';
import { OPENAPI_PATH, renderYaml } from './spec-files';

async function main(): Promise<void> {
  const document = await buildOpenApiDocument();
  writeFileSync(OPENAPI_PATH, renderYaml(document));
  console.log(`Wrote ${OPENAPI_PATH} (${Object.keys(document.paths).length} paths).`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
