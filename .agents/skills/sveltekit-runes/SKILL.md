---
name: sveltekit-runes
description: "Svelte 5 runes: $state, $derived, $effect, $props e $bindable, além da migração de Svelte 4 (stores, export let, $:) para runes. Use em qualquer componente .svelte novo ou refatorado, ou ao depurar reatividade em +page.svelte e +layout.svelte."
---

# Skill: sveltekit-runes

## Quando usar

Carregue esta skill ao trabalhar com:
- Qualquer componente `.svelte` novo ou refatorado
- Migração de código Svelte 4 (stores, `export let`, `$:`) para Svelte 5
- Lógica reativa em `+page.svelte`, `+layout.svelte`, ou componentes em `src/lib/components/`
- Debug de reatividade (valores que não atualizam, loops infinitos)

## O que são runes

Runes são a nova primitiva de reatividade do Svelte 5. Substituem:

| Svelte 4 | Svelte 5 (runes) |
|----------|------------------|
| `export let prop` | `let { prop } = $props()` |
| `let count = 0` (reativo em template) | `let count = $state(0)` |
| `$: doubled = count * 2` | `const doubled = $derived(count * 2)` |
| `$: { ... }` (efeito) | `$effect(() => { ... })` |
| `$store` / stores writable | `$state` em `.svelte.ts` |
| `export const` (bind) | `$bindable()` |

Runes só funcionam dentro de componentes `.svelte` e arquivos `.svelte.ts`/`.svelte.js`.

## Padrões corretos

### `$state` — estado reativo

```svelte
<script lang="ts">
  let count = $state(0);
  let user = $state<User | null>(null);
  let items = $state<string[]>([]);

  function increment() {
    count += 1;            // ✅ reativo
    items.push('novo');    // ✅ arrays são profundamente reativos
  }
</script>

<button onclick={increment}>
  Cliques: {count}
</button>
```

**Importante:** `$state` é profundamente reativo. Objetos e arrays aninhados também são rastreados.

### `$state.raw` — estado não-reativo profundo

Use quando o valor é substituído por completo e você não quer rastreamento profundo (performance):

```ts
let config = $state.raw<Config>({ theme: 'dark', lang: 'pt' });

// ✅ substituição funciona
config = { theme: 'light', lang: 'pt' };

// ⚠️ mutação NÃO dispara reatividade (intencional)
config.theme = 'light'; // não atualiza a UI
```

### `$derived` — valores computados

```svelte
<script lang="ts">
  let count = $state(0);
  let price = $state(10);

  const total = $derived(count * price);
  const label = $derived(count === 0 ? 'vazio' : `${count} itens`);
</script>

<p>Total: {total}</p>
```

Regras:
- `$derived` **não** tem efeitos colaterais — é puro.
- Não atribua a um `$derived`.
- Se precisar de lógica complexa, use `$derived.by()`:

```ts
const filtered = $derived.by(() => {
  const min = threshold;
  const max = threshold * 10;
  return items.filter((i) => i.value >= min && i.value <= max);
});
```

### `$props` — props tipadas

```svelte
<script lang="ts">
  interface Props {
    title: string;
    count?: number;
    items: string[];
    onSelect?: (item: string) => void;
    children?: import('svelte').Snippet;
  }

  let {
    title,
    count = 0,
    items,
    onSelect,
    children
  }: Props = $props();
</script>

<h1>{title} ({count})</h1>
{@render children?.()}
```

Regras:
- Sempre tipar `$props` com interface.
- Valores default vêm na desestruturação.
- `children` é um `Snippet`, não um slot.

### `$bindable` — props que podem ser ligadas

```svelte
<!-- Input.svelte -->
<script lang="ts">
  let { value = $bindable('') }: { value?: string } = $props();
</script>

<input bind:value />
```

```svelte
<!-- Pai.svelte -->
<Input bind:value={name} />
```

Use com moderação. Prefira callbacks (`onSelect`) a `$bindable` quando possível.

### `$effect` — efeitos colaterais

```svelte
<script lang="ts">
  let count = $state(0);

  $effect(() => {
    // Roda sempre que `count` mudar
    console.log('count mudou:', count);

    // ✅ cleanup opcional
    return () => console.log('limpando');
  });
</script>
```

Regras:
- `$effect` é **último recurso**. Prefira `$derived` para valores computados.
- Nunca modifique `$state` dentro de um `$effect` que o lê (loop infinito).
- Use `$effect.pre` para rodar antes do DOM atualizar.
- Use `$effect.root` para efeitos fora do ciclo de vida do componente.

### `$inspect` — debug

```svelte
<script lang="ts">
  let count = $state(0);

  $inspect(count);              // loga toda mudança
  $inspect(count).with(console.trace); // com custom logger
</script>
```

Runes `$inspect` são removidas em produção (seguro deixar no código).

### Estado compartilhado com `.svelte.ts`

```ts
// src/lib/stores/counter.svelte.ts
export function createCounter() {
  let count = $state(0);

  return {
    get count() { return count; },
    increment: () => { count += 1; },
    reset: () => { count = 0; }
  };
}

export const counter = createCounter();
```

```svelte
<!-- Componente.svelte -->
<script lang="ts">
  import { counter } from '$lib/stores/counter.svelte';
</script>

<button onclick={counter.increment}>
  {counter.count}
</button>
```

## Anti-patterns (proibidos)

### 1. `export let`

```svelte
<!-- ❌ Svelte 4 -->
<script>
  export let name;
</script>

<!-- ✅ Svelte 5 -->
<script lang="ts">
  let { name }: { name: string } = $props();
</script>
```

### 2. `$:` reativo

```svelte
<!-- ❌ Svelte 4 -->
<script>
  let count = 0;
  $: doubled = count * 2;
</script>

<!-- ✅ Svelte 5 -->
<script>
  let count = $state(0);
  const doubled = $derived(count * 2);
</script>
```

### 3. Stores writable em código novo

```ts
// ❌ Svelte 4 — não use em código novo
import { writable } from 'svelte/store';
export const user = writable<User | null>(null);

// ✅ Svelte 5 — use $state em .svelte.ts
// src/lib/stores/user.svelte.ts
let user = $state<User | null>(null);
export function getUser() { return user; }
export function setUser(u: User | null) { user = u; }
```

### 4. `fetch` em `onMount` para SSR

```svelte
<!-- ❌ NUNCA para dados que devem aparecer no SSR -->
<script>
  import { onMount } from 'svelte';
  let users = [];
  onMount(async () => {
    users = await fetch('/api/users').then(r => r.json());
  });
</script>

<!-- ✅ SEMPRE use load do SvelteKit -->
<!-- +page.server.ts -->
export async function load({ platform }) {
  const { results } = await platform.env.DB
    .prepare('SELECT * FROM users')
    .all();
  return { users: results };
}
```

### 5. Modificar `$state` dentro de `$effect` que o lê

```svelte
<!-- ❌ loop infinito -->
<script>
  let count = $state(0);
  $effect(() => {
    count += 1; // lê e escreve count → loop
  });
</script>

<!-- ✅ separe responsabilidades -->
<script>
  let count = $state(0);
  let doubled = $derived(count * 2);
</script>
```

### 6. `$derived` com efeitos colaterais

```ts
// ❌ $derived é puro — não faça isso
const result = $derived(() => {
  logAnalytics('view'); // efeito colateral
  return count * 2;
});

// ✅ efeito colateral vai em $effect
$effect(() => {
  logAnalytics('view');
});
const result = $derived(count * 2);
```

### 7. Passar `$state` para fora do componente

```svelte
<!-- ❌ quebra reatividade -->
<script>
  let count = $state(0);
  export function getCount() { return count; } // retorna valor, não referência
</script>
```

Para compartilhar estado entre componentes, use `.svelte.ts` com getters.

### 8. `bind:` em prop sem `$bindable`

```svelte
<!-- Child.svelte -->
<script>
  let { value }: { value: string } = $props(); // ❌ sem $bindable
</script>
<input bind:value />

<!-- ✅ -->
<script>
  let { value = $bindable('') }: { value?: string } = $props();
</script>
<input bind:value />
```

## Migração Svelte 4 → 5

Checklist por arquivo:
1. Substituir `export let x` por `let { x } = $props()`.
2. Substituir `$: y = expr` por `const y = $derived(expr)`.
3. Substituir `$: { ... }` por `$effect(() => { ... })`.
4. Substituir `writable`/`readable` por `$state` em `.svelte.ts`.
5. Substituir `<slot>` por `{@render children()}`.
6. Substituir `on:click` por `onclick`.
7. Substituir `createEventDispatcher` por callbacks em `$props`.

Comando oficial:
```bash
npx sv migrate svelte-5
```

Revise cada mudança — a migração automática não cobre 100% dos casos.

## Comandos

```bash
# Verificar tipos em componentes Svelte
pnpm check

# Migrar de Svelte 4 para 5 (automático)
npx sv migrate svelte-5

# Atualizar Svelte
pnpm add -D svelte@latest @sveltejs/kit@latest @sveltejs/vite-plugin-svelte@latest
```

## Checklist antes de finalizar

- [ ] Nenhum `export let`
- [ ] Nenhum `$:` reativo
- [ ] Nenhum store legado em código novo
- [ ] Props tipadas com interface
- [ ] `children` como `Snippet` (não slot)
- [ ] `$effect` usado apenas para efeitos colaterais reais
- [ ] `$derived` puro (sem efeitos colaterais)
- [ ] Dados carregados via `load`, não `onMount`
- [ ] Estado compartilhado em `.svelte.ts` com getters
- [ ] `onclick` (não `on:click`)
- [ ] `pnpm check` verde
- [ ] Testes e2e passando

## Referências

- Svelte 5 runes: https://svelte.dev/docs/svelte/what-are-runes
- `$state`: https://svelte.dev/docs/svelte/$state
- `$derived`: https://svelte.dev/docs/svelte/$derived
- `$effect`: https://svelte.dev/docs/svelte/$effect
- `$props`: https://svelte.dev/docs/svelte/$props
- AGENT.md — seção 4, Code Rules > Svelte 5
