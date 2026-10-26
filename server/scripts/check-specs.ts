/**
 * `npm run spec:check`: fails when either contract no longer matches the code.
 *
 * - docs/backend-openapi.yaml must equal what `spec:generate` would write now.
 * - docs/websockets-asyncapi-draft.yaml is hand-written; see asyncapi-checks.ts.
 */
import { existsSync, readFileSync } from 'fs';
import * as path from 'path';
import { checkAsyncApi } from './asyncapi-checks';
import { buildOpenApiDocument } from './openapi-document';
import { ASYNCAPI_PATH, OPENAPI_PATH, renderYaml } from './spec-files';

async function main(): Promise<void> {
  const problems: string[] = [];
  const pkg = JSON.parse(readFileSync(path.resolve(__dirname, '..', 'package.json'), 'utf8')) as {
    version: string;
  };

  const expected = renderYaml(await buildOpenApiDocument());
  const committed = existsSync(OPENAPI_PATH) ? readFileSync(OPENAPI_PATH, 'utf8') : '';
  if (normalise(committed) !== normalise(expected)) {
    problems.push(
      `${path.basename(OPENAPI_PATH)} is out of date. Run \`npm run spec:generate\` in server/ ` +
        'and commit the result.',
    );
  }

  for (const problem of checkAsyncApi(readFileSync(ASYNCAPI_PATH, 'utf8'), pkg.version)) {
    problems.push(`${path.basename(ASYNCAPI_PATH)}: ${problem}`);
  }

  if (problems.length > 0) {
    console.error(`Spec check failed:\n${problems.map((p) => `  - ${p}`).join('\n')}`);
    process.exit(1);
  }
  console.log('Specs match the code.');
}

/** Git on Windows may check the file out with CRLF; that is not drift. */
function normalise(text: string): string {
  return text.replace(/\r\n/g, '\n');
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
