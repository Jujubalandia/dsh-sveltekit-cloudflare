<script lang="ts">
  import { mode, toggleMode } from 'mode-watcher';
  import SunIcon from '@lucide/svelte/icons/sun';
  import MoonIcon from '@lucide/svelte/icons/moon';
  import { Button } from '$lib/components/ui/button/index.js';
</script>

<Button
  variant="outline"
  size="icon"
  onclick={toggleMode}
  aria-label="Alternar entre tema claro e escuro"
  title="Alternar tema"
>
  {#if mode.current === 'dark'}
    <SunIcon class="size-4" />
  {:else}
    <MoonIcon class="size-4" />
  {/if}
</Button>
