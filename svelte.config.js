import adapter from '@sveltejs/adapter-cloudflare';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),

  kit: {
    adapter: adapter({
      // Rotas que passam pelo Worker (inclui SSR e endpoints)
      routes: {
        include: ['/*'],
        exclude: ['<all>']
      },
      // Diretório de saída do adapter (consumido pelo Wrangler)
      platformProxy: {
        configPath: 'wrangler.toml',
        environment: undefined,
        experimentalJsonConfig: false,
        persist: true
      }
    }),

    alias: {
      $components: 'src/lib/components',
      $server: 'src/lib/server',
      $utils: 'src/lib/utils',
      $workers: 'workers/src'
    },

    csrf: {
      checkOrigin: true
    },

    // Headers de segurança aplicados pelo SvelteKit
    // (reforçados também via _headers do Cloudflare Pages)
    files: {
      assets: 'static'
    }
  }
};

export default config;
