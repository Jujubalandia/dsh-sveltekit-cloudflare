import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import svelte from 'eslint-plugin-svelte';
import security from 'eslint-plugin-security';
import prettier from 'eslint-config-prettier';
import globals from 'globals';
import svelteConfig from './svelte.config.js';

export default tseslint.config(
  {
    ignores: [
      'node_modules/**',
      '.svelte-kit/**',
      'build/**',
      'dist/**',
      'coverage/**',
      'reports/**',
      'playwright-report/**',
      'test-results/**',
      '.stryker-tmp/**',
      'static/**',
      // Caches locais de tooling, quando ficam dentro do repo.
      '.pnpm-store/**',
      '.pnpm-home/**',
      '.xdg/**',
      '.npm-cache/**',
      '.playwright/**',
      '.corepack/**',
      // Código vendorizado pelo shadcn-svelte: é regenerado pelo CLI e não é
      // mantido à mão. Continua type-checked (svelte-check) e escaneado por
      // segurança; só não é linted/formatado como código nosso.
      'src/lib/components/ui/**'
    ]
  },

  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...svelte.configs.recommended,

  // eslint-plugin-security: o kit já o tinha como dependência e ele nunca era
  // aplicado, porque não existia config.
  security.configs.recommended,

  {
    languageOptions: {
      globals: { ...globals.browser, ...globals.node }
    },
    rules: {
      // O harness trata input não confiável no schema (Zod), não em cada call
      // site. `detect-object-injection` dispara em todo acesso dinâmico e
      // afogaria o sinal dos gates de verdade.
      'security/detect-object-injection': 'off',
      // Parâmetros prefixados com `_` são intencionalmente não usados
      // (assinaturas de mock que precisam casar com a API real).
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_', caughtErrorsIgnorePattern: '^_' }
      ]
    }
  },

  {
    // Os scripts do harness existem justamente para ler caminhos que vêm da
    // config do bundle (patch, skills, components.json). Apontar arquivo
    // dinâmico é o trabalho deles, não um defeito.
    files: ['scripts/**/*.mjs', 'lib/**/*.mjs'],
    rules: {
      'security/detect-non-literal-fs-filename': 'off',
      'security/detect-non-literal-regexp': 'off',
      'security/detect-unsafe-regex': 'off'
    }
  },

  {
    files: ['**/*.svelte'],
    languageOptions: {
      parserOptions: { svelteConfig }
    }
  },

  {
    files: ['scripts/**/*.mjs', 'lib/**/*.mjs', '*.config.js', '*.config.mjs'],
    languageOptions: {
      sourceType: 'module'
    }
  },

  // Precisa ficar por último: desliga as regras de estilo que o Prettier já
  // resolve, para os dois não brigarem.
  prettier
);
