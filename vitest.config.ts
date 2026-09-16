import { defineConfig } from 'vitest/config';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { resolve } from 'node:path';

export default defineConfig({
  plugins: [svelte({ hot: false })],

  resolve: {
    alias: {
      $components: resolve('./src/lib/components'),
      $server: resolve('./src/lib/server'),
      $utils: resolve('./src/lib/utils'),
      $workers: resolve('./workers/src'),
      $lib: resolve('./src/lib')
    }
  },

  test: {
    environment: 'node',
    globals: false,
    setupFiles: ['./tests/setup.ts'],
    include: [
      'src/**/*.test.ts',
      'tests/unit/**/*.test.ts'
    ],
    exclude: [
      'node_modules',
      '.svelte-kit',
      'tests/e2e/**',
      'tests/mutation/**'
    ],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',
      thresholds: {
        lines: 70,
        functions: 70,
        branches: 60,
        statements: 70
      },
      exclude: [
        '**/*.d.ts',
        '**/*.test.ts',
        '**/+page.svelte',
        '**/+layout.svelte',
        '**/+error.svelte',
        'tests/**',
        '.svelte-kit/**',
        'build/**',
        'dist/**',
        'scripts/**'
      ]
    },
    pool: 'forks',
    poolOptions: {
      forks: {
        singleFork: true
      }
    },
    testTimeout: 10000,
    hookTimeout: 10000
  }
});
