---
name: shadcn-svelte
description: "shadcn-svelte no SvelteKit: components.json, CLI de componentes, aliases, tokens de tema oklch, dark mode e acessibilidade via Bits UI. Use ao adicionar ou atualizar componentes de UI, mexer no design system, ou revisar código vindo do registry."
---

# Skill: shadcn-svelte

## Quando usar

Carregue esta skill ao trabalhar com:

- Adicionar um componente novo (`pnpm ui:add <nome>`)
- Mexer em `components.json`, `src/app.css` ou `src/lib/utils.ts`
- Trocar tokens de tema, raio ou cores
- Dark mode, toggle de tema, `mode-watcher`
- Revisar um PR que traz código de UI vindo do registry
- Decidir entre usar shadcn e escrever o componente à mão

## O que é (e o que não é)

shadcn-svelte **não é uma biblioteca de componentes instalada via import**. É um
registry: o CLI baixa o **código-fonte** do componente para dentro do seu
projeto, em `src/lib/components/ui/`, e a partir daí ele é seu.

Consequências que mudam como você trabalha:

| Consequência | Implicação prática |
|---|---|
| O código é seu | Pode editar, mas prefira regenerar: `pnpm ui:add <x> -o` |
| Não há `node_modules/shadcn` em runtime | O que existe é o CLI como devDependency |
| Acessibilidade vem do Bits UI | Não reescreva foco/teclado na mão |
| O registry é remoto | **Gate 9**: todo componente novo é código executando no browser |
| Tailwind v4 é pré-requisito | Sem `@tailwindcss/vite`, nada estiliza |

Stack: **Svelte 5 (runes) + Tailwind v4 + Bits UI + tailwind-variants**.

## Arquivos de configuração

### `components.json`

```json
{
  "$schema": "https://shadcn-svelte.com/schema.json",
  "tailwind": { "css": "src/app.css", "baseColor": "neutral" },
  "aliases": {
    "components": "$lib/components",
    "utils": "$lib/utils",
    "ui": "$lib/components/ui",
    "hooks": "$lib/hooks",
    "lib": "$lib"
  },
  "typescript": true,
  "registry": "https://shadcn-svelte.com/registry",
  "style": "vega",
  "iconLibrary": "lucide"
}
```

Regras:

- `tailwind.baseColor` **não pode ser trocada depois do `init`** — os tokens do
  `app.css` já foram gerados para ela.
- `aliases.*` precisam existir em `svelte.config.js` (`kit.alias`) **ou** nos
  paths que o SvelteKit gera em `.svelte-kit/tsconfig.json`. O CLI valida isso
  antes de escrever qualquer arquivo.
- `registry` aponta para o registry oficial. Trocar é decisão de segurança, não
  de conveniência (Gate 9).

### `src/app.css`

É o **único** arquivo de tema. Contém, nesta ordem:

1. `@import 'tailwindcss'`
2. `@import 'tw-animate-css'`
3. `@import 'shadcn-svelte/tailwind.css'` (o estilo do preset)
4. `@import '@fontsource-variable/inter'`
5. `@custom-variant dark (&:is(.dark *))`
6. `:root { ... }` e `.dark { ... }` com os tokens em **oklch**
7. `@theme inline { ... }` mapeando token → utilitário do Tailwind
8. `@layer base { * { @apply border-border } body { @apply bg-background text-foreground } }`

Nunca crie um segundo CSS global. Se precisar de um token novo, adicione em
`:root` **e** em `.dark` **e** em `@theme inline`, senão o utilitário não existe.

### `src/lib/utils.ts`

```ts
export { cn } from 'cn';
```

`cn` combina `clsx` + `tailwind-merge`: resolve conflito de classe (o último
vence) e é o que todos os componentes usam.

**Não crie um diretório `src/lib/utils/`.** O alias `$utils` do projeto aponta
para esse caminho e passaria a competir com `utils.ts`. Se um dia precisar de
um diretório, mova o `cn` para dentro e atualize `components.json`.

### Aliases

O projeto tem dois conjuntos que apontam para os mesmos lugares:

- `$lib/*` (nativo do SvelteKit) — é o que o shadcn usa e o que o código gerado
  importa (`$lib/utils.js`, `$lib/components/ui/button/index.js`)
- `$components`, `$utils`, `$server`, `$workers` — aliases próprios do kit

Ao importar componentes, prefira o caminho que o componente gerado já usa.

## Padrões corretos

### Adicionar um componente

```bash
pnpm ui:add dialog
pnpm ui:add button card input label dialog dropdown-menu table sonner
```

O CLI adiciona as dependências no `package.json` e cria a pasta em
`src/lib/components/ui/<nome>/` com `index.ts` e os `.svelte`.

**Revise o diff antes de commitar.** É código novo no seu bundle.

### Usar um componente

```svelte
<script lang="ts">
  import { Button } from '$lib/components/ui/button/index.js';
</script>

<Button variant="outline" size="sm">Salvar</Button>
```

### Composição com `child` (Bits UI 2)

O jeito antigo (`asChild` + `let:props`) **não existe mais** no Bits UI 2. O
padrão correto é um snippet `child`:

```svelte
<DialogTrigger>
  {#snippet child({ props })}
    <Button {...props}>Abrir</Button>
  {/snippet}
</DialogTrigger>
```

### Dark mode

Uma fonte de verdade: `mode-watcher`.

- `ModeWatcher` no `+layout.svelte`
- `toggleMode()` / `mode.current` para alternar
- Chave em `localStorage`: **`mode-watcher-mode`** (`light` | `dark` | `system`)
- Script inline no `app.html` lê a **mesma** chave para evitar FOUC

Não escreva uma segunda lógica de tema. Se o script inline e o `ModeWatcher`
discordarem, o site pisca.

### Formulários

`Label` com `for` e `Input` com `id` (nunca placeholder como rótulo). Validação
fica no schema Zod, não no componente (Gate 2):

```ts
const result = parseEmail(email);
if (!result.ok) { toast.error(result.error); return; }
```

### Quando **não** usar shadcn

- Dashboard denso com tabela de dados complexa → use TanStack Table direto.
- Componente que já existe no projeto → não duplique.
- Algo muito específico do produto → escreva no seu `src/lib/components/`, fora
  de `ui/`.

## Anti-patterns (proibidos)

| Anti-pattern | Por quê |
|---|---|
| Editar `src/lib/components/ui/**` à mão | Na próxima regeneração o trabalho some. Regenere com `-o` ou componha por fora. |
| Rodar `pnpm ui:add` sem `--no-deps-install` em CI | O CLI altera `package.json` e instala; em CI isso quebra reprodutibilidade. |
| Deixar `"latest"` no `package.json` | O CLI escreve `latest` ao adicionar deps. Sie e re-pine. |
| Trocar `components.json.registry` sem revisar | É código de terceiro executando no browser (Gate 9). |
| Colocar regra de negócio dentro de `ui/` | `ui/` é apresentação. Regra vai em `$lib/server` ou `$lib/`. |
| Criar `tailwind.config.js` | Tailwind v4 não usa mais arquivo de config; o tema é CSS. |
| Adicionar `postcss.config.js` | O `@tailwindcss/vite` substitui o pipeline PostCSS. |
| Escrever `<dialog>` ou foco na mão | O Bits UI já resolve acessibilidade; reimplementar regride. |
| Usar `$utils` e `$lib/utils` misturados no mesmo arquivo | Escolha um; o gerado usa `$lib/utils.js`. |

## O que o kit já entrega

Oito componentes, em `src/lib/components/ui/`:

`button` · `card` · `input` · `label` · `dialog` · `dropdown-menu` · `table` · `sonner`

Eles estão montados em `src/routes/+page.svelte` (página de prova) e cobertos por
`tests/e2e/shadcn.spec.ts`. Se um deles parar de funcionar, o e2e falha.

## Gate 9 — supply chain de componentes

O `add` baixa **código executável** de um registry remoto. O harness exige:

1. **CLI em versão fixa** (`shadcn-svelte` pinado, nunca `@latest` em CI).
2. **`registry` oficial** em `components.json`. Trocar exige revisão explícita.
3. **Todo `add` passa por PR** com o diff de `ui/` revisado. É código no browser.
4. **`--overwrite` (`-o`) só com intenção.** Sobrescreve edição local.
5. Componente copiado de blog/GitHub passa pelo mesmo review.
6. `security-scan.sh` falha se `registry` não for oficial ou se a CLI não estiver
   pinada.

## Comandos

```bash
pnpm ui:add button            # adiciona um componente
pnpm ui:add --all             # todos (não recomendado de cara)
pnpm ui:add button -o         # regenera sobrescrevendo
pnpm ui:init                  # reinicializa (cuidado: reescreve app.css)

pnpm check                    # type check, inclui ui/
pnpm lint                     # eslint/prettier (ui/ é ignorado de propósito)
pnpm test:coverage            # unit (ui/ fora da cobertura)
pnpm test:e2e                 # e2e dos 8 componentes
```

## O que é ignorado pelos gates (e por quê)

`src/lib/components/ui/**` é **vendorizado**: regenerável pelo CLI, não mantido
à mão. Por isso fica de fora de:

- ESLint e Prettier (regras de estilo do registry)
- cobertura de testes (não é código nosso)
- knip, jscpd e complexidade (geraria ruído)

Mas **continua** dentro de:

- `svelte-check` (precisa compilar e tipar)
- e2e (precisa renderizar e interagir)
- varredura de segurança e Gate 9

## Checklist antes de finalizar

- [ ] O componente foi adicionado via CLI, não copiado à mão
- [ ] Nenhuma dependência ficou como `"latest"`
- [ ] `components.json` não mudou sem intenção
- [ ] `app.css` mantém `:root`, `.dark` e `@theme inline` em sincronia
- [ ] Dark mode verificado nos dois temas
- [ ] `svelte-check` e `pnpm lint` passam
- [ ] `tests/e2e/shadcn.spec.ts` passa
- [ ] O diff de `ui/` foi lido antes do commit (Gate 9)

## Referências

- Documentação: https://shadcn-svelte.com/docs
- Instalação SvelteKit: https://shadcn-svelte.com/docs/installation/sveltekit
- `components.json`: https://shadcn-svelte.com/docs/components-json
- CLI: https://shadcn-svelte.com/docs/cli
- Tailwind v4: https://tailwindcss.com/docs
- Bits UI: https://bits-ui.com
- mode-watcher: https://github.com/svecosystem/mode-watcher
