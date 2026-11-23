// ==============================================================
// stryker.config.mjs — mutation testing do harness
//
// Fica na RAIZ de propósito: `stryker run` procura a config no cwd, e antes
// ela vivia em tests/mutation/, onde o comando nunca a encontrava.
//
// Uso:
//   pnpm test:mutation
//   pnpm test:mutation -- --mutate "src/lib/validation.ts"
//
// Mutação mede se os testes realmente pegam bugs: um mutante que sobrevive
// indica teste fraco. Threshold 60% para não travar o kit num número alto
// enquanto a base de código do app ainda é pequena.
// ==============================================================

/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  testRunner: 'vitest',
  plugins: ['@stryker-mutator/vitest-runner'],

  mutate: [
    'src/lib/**/*.ts',
    '!src/lib/**/*.test.ts',
    '!src/lib/**/*.spec.ts',
    '!src/**/*.d.ts',
    '!src/**/+page.server.ts',
    '!src/**/+layout.server.ts',
    // Código vendorizado pelo shadcn-svelte: não é nosso, não faz sentido
    // medir mutação nele.
    '!src/lib/components/ui/**'
  ],

  coverageAnalysis: 'perTest',

  thresholds: {
    high: 80,
    low: 60,
    break: 60
  },

  timeoutMS: 10000,
  timeoutFactor: 1.5,
  concurrency: 2,
  maxConcurrentTestRunners: 2,

  reporters: ['clear-text', 'progress', 'html', 'json'],
  htmlReporter: { fileName: 'reports/mutation/mutation.html' },
  jsonReporter: { fileName: 'reports/mutation/mutation.json' },

  tempDirName: '.stryker-tmp',
  cleanTempDir: true,

  // Sem `checkers: ['typescript']`: o @stryker-mutator/typescript-checker não
  // é dependência deste kit. Mutantes inválidos são descartados pelo runner.
  mutator: {
    excludedMutations: ['StringLiteral']
  }
};
