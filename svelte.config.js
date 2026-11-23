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
        persist: true,
        // Sem isto o wrangler assume `remoteBindings: true` e o `pnpm dev`
        // tenta abrir uma conexão remota, falhando com "CLOUDFLARE_API_TOKEN
        // is required" mesmo com bindings locais. Desenvolvimento local deve
        // usar o miniflare, não a conta Cloudflare.
        remoteBindings: false
      }
    }),

    alias: {
      $components: 'src/lib/components',
      $server: 'src/lib/server',
      $utils: 'src/lib/utils',
      $workers: 'workers/src'
    },

    // `csrf.checkOrigin` foi depreciado e virou `csrf.trustedOrigins`. O
    // comportamento padrão já é rejeitar origem cruzada, então não precisa
    // de bloco nenhum. Só declare `trustedOrigins` se houver origem extra.

    // Headers de segurança aplicados pelo SvelteKit
    // (reforçados também via _headers do Cloudflare Pages)
    files: {
      assets: 'static'
    }
  }
};

export default config;
