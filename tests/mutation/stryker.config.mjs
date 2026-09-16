// ==============================================================
// tests/mutation/stryker.config.mjs — configuração do Stryker
//
// Mutation testing: verifica se os testes realmente detectam bugs.
// Um mutante "sobrevivente" indica um teste fraco.
//
// Uso:
//   pnpm test:mutation                     # roda todos os mutantes
//   pnpm test:mutation -- --mutate "src/lib/**/*.ts"
//   pnpm test:mutation -- --since main     # só o que mudou
//
// Threshold: 60% (ajuste conforme maturidade do projeto).
// ==============================================================

/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  // ----------------------------------------------------------
  // Gerenciador de pacotes e runner
  // ----------------------------------------------------------
  packageManager: 'pnpm',
  testRunner: 'vitest',

  // ----------------------------------------------------------
  // Descoberta de arquivos para mutar
  // ----------------------------------------------------------
  mutate: [
    'src/lib/**/*.ts',
    'workers/src/**/*.ts',
    '!src/**/*.test.ts',
    '!src/**/*.spec.ts',
    '!src/**/*.d.ts',
    '!src/**/+page.server.ts',
    '!src/**/+layout.server.ts',
    '!workers/src/**/*.test.ts',
    '!workers/src/**/*.d.ts',
    '!src/lib/server/db/migrations/**'
  ],

  // ----------------------------------------------------------
  // Análise de cobertura — quais testes cobrem quais mutantes
  // ----------------------------------------------------------
  coverageAnalysis: 'perTest',

  // ----------------------------------------------------------
  // Thresholds: score abaixo de 'break' falha o pipeline
  // ----------------------------------------------------------
  thresholds: {
    high: 80,
    low: 60,
    break: 60
  },

  // ----------------------------------------------------------
  // Timeouts
  // ----------------------------------------------------------
  timeoutMS: 10000,
  timeoutFactor: 1.5,

  // ----------------------------------------------------------
  // Concorrência
  // ----------------------------------------------------------
  concurrency: 4,
  maxConcurrentTestRunners: 4,

  // ----------------------------------------------------------
  // Reporters
  // ----------------------------------------------------------
  reporters: [
    'clear-text',
    'progress',
    'html',
    'json'
  ],
  htmlReporter: {
    fileName: 'reports/mutation/mutation.html'
  },
  jsonReporter: {
    fileName: 'reports/mutation/mutation.json'
  },

  // ----------------------------------------------------------
  // Diretório de trabalho temporário
  // ----------------------------------------------------------
  tempDirName: '.stryker-tmp',
  cleanTempDir: true,

  // ----------------------------------------------------------
  // Ignorar mutações específicas que geram falsos positivos
  // ----------------------------------------------------------
  ignorers: [],

  // ----------------------------------------------------------
  // Mutadores habilitados (padrão é bom; customizar se necessário)
  // ----------------------------------------------------------
  mutator: {
    plugins: [
      '@stryker-mutator/typescript-checker'
    ],
    excludedMutations: [
      // Log strings não valem testar
      'StringLiteral',
      // Comentários
      'ObjectLiteral'
    ]
  },

  // ----------------------------------------------------------
  // Checker de TypeScript (evita mutantes inválidos)
  // ----------------------------------------------------------
  checkers: ['typescript'],
  tsconfigFile: 'tsconfig.json',

  // ----------------------------------------------------------
  // Integração com Vitest
  // ----------------------------------------------------------
  vitest: {
    configFile: 'vitest.config.ts',
    dir: '.'
  },

  // ----------------------------------------------------------
  // Configuração para CI
  // ----------------------------------------------------------
  // Em CI, reduza concorrência e use reporters compactos:
  // concurrency: 2,
  // reporters: ['clear-text', 'json'],
  // htmlReporter: { fileName: 'reports/mutation/mutation.html' }
};
