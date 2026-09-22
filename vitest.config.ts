import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { include: process.env.FIRESTORE_EMULATOR_HOST ? ['tests/*.emulator.ts', 'tests/*.test.ts'] : ['tests/*.test.ts'], testTimeout: 30000, fileParallelism: false } });
