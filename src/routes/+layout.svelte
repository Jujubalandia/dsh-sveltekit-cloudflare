<script lang="ts">
  import { resolve } from '$app/paths';
  import '../app.css';
  import { ModeWatcher } from 'mode-watcher';
  import { Toaster } from '$lib/components/ui/sonner/index.js';
  import ThemeToggle from '$lib/components/theme-toggle.svelte';

  let { children } = $props();
</script>

<!-- Fonte única de verdade do tema. O script inline em app.html lê a mesma
     chave para evitar flash na primeira pintura. -->
<ModeWatcher defaultMode="system" />
<Toaster position="bottom-right" />

<svelte:head>
  <title>sveflare: SvelteKit + Cloudflare harness</title>
  <meta
    name="description"
    content="Harness de agente para SvelteKit na Cloudflare: 13 skills, 5 comandos, 9 gates e shadcn-svelte integrado."
  />
</svelte:head>

<div class="bg-background text-foreground flex min-h-dvh flex-col">
  <header class="border-border/60 sticky top-0 z-20 border-b backdrop-blur">
    <div class="mx-auto flex h-14 w-full max-w-5xl items-center gap-3 px-4">
      <a href={resolve('/', {})} class="font-semibold tracking-tight">sveflare</a>
      <span class="text-muted-foreground hidden text-xs sm:inline">
        SvelteKit + Cloudflare harness
      </span>
      <div class="ml-auto">
        <ThemeToggle />
      </div>
    </div>
  </header>

  <main class="mx-auto w-full max-w-5xl flex-1 px-4 py-10">
    {@render children()}
  </main>

  <footer class="border-border/60 text-muted-foreground border-t px-4 py-6 text-xs">
    <div class="mx-auto flex w-full max-w-5xl flex-wrap items-center gap-x-4 gap-y-1">
      <span>sveflare 1.1.0</span>
      <span>Tailwind v4</span>
      <span>shadcn-svelte (preset vega)</span>
      <a class="ml-auto underline underline-offset-4" href="https://shadcn-svelte.com">
        shadcn-svelte.com
      </a>
    </div>
  </footer>
</div>
