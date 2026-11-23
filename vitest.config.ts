import { defineConfig } from 'vitest/config';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { resolve } from 'node:path';

export default defineConfig({
  // `hot` saiu das opções do vite-plugin-svelte 7; o plugin já roda em modo
  // de teste quando detecta o Vitest.
  plugins: [svelte()],

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
    include: ['src/**/*.test.ts', 'tests/unit/**/*.test.ts'],
    exclude: ['node_modules', '.svelte-kit', 'tests/e2e/**', 'tests/mutation/**'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',
      // Mede só o nosso código de biblioteca. Componentes de UI são
      // vendorizados pelo shadcn e não entram no denominador.
      include: ['src/lib/**/*.ts'],
      thresholds: {
        lines: 70,
        functions: 70,
        branches: 60,
        statements: 70
      },
      exclude: [
        '**/*.d.ts',
        '**/*.test.ts',
        // Re-export de `cn` (pacote `cn`): sem statements próprios.
        'src/lib/utils.ts',
        // Código gerado/regenerado pelo shadcn-svelte.
        'src/lib/components/**',
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
    // `poolOptions` saiu do Vitest 4; `fileParallelism: false` é o substituto
    // direto do antigo `singleFork`.
    pool: 'forks',
    fileParallelism: false,
    testTimeout: 10000,
    hookTimeout: 10000
  }
});
