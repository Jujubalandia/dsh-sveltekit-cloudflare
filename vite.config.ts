import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  // tailwindcss() é o plugin oficial do Tailwind v4. Ele substitui o par
  // tailwindcss + postcss + autoprefixer do v3: não existe mais
  // tailwind.config.js nem postcss.config.js neste projeto.
  plugins: [tailwindcss(), sveltekit()],

  server: {
    port: 5173,
    strictPort: true
  },

  preview: {
    port: 4173,
    strictPort: true
  },

  build: {
    target: 'es2022',
    sourcemap: true,
    minify: 'esbuild',
    cssMinify: true
  },

  esbuild: {
    legalComments: 'none'
  },

  test: {
    environment: 'node',
    include: ['src/**/*.test.ts', 'tests/unit/**/*.test.ts'],
    exclude: ['node_modules', '.svelte-kit', 'tests/e2e/**']
  }
});
