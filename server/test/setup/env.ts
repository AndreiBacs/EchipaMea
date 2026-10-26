import { applyTestEnv } from './test-env';

// Runs before each test file is loaded, so `ConfigModule.forRoot()` -- which
// validates the environment when `AppModule` is first imported -- sees these.
applyTestEnv();
