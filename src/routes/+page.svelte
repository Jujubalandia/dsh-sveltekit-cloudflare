<script lang="ts">
  import { toast } from 'svelte-sonner';
  import { Button } from '$lib/components/ui/button/index.js';
  import {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle
  } from '$lib/components/ui/card/index.js';
  import { Input } from '$lib/components/ui/input/index.js';
  import { Label } from '$lib/components/ui/label/index.js';
  import {
    Dialog,
    DialogClose,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger
  } from '$lib/components/ui/dialog/index.js';
  import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger
  } from '$lib/components/ui/dropdown-menu/index.js';
  import {
    Table,
    TableBody,
    TableCaption,
    TableCell,
    TableHead,
    TableHeader,
    TableRow
  } from '$lib/components/ui/table/index.js';
  import { parseEmail } from '$lib/validation.js';

  let dialogOpen = $state(false);
  let email = $state('');

  function enviar() {
    // Gate 2: o input passa pelo schema antes de qualquer uso.
    const result = parseEmail(email);
    if (!result.ok) {
      toast.error(result.error);
      return;
    }
    toast.success('Enviado', { description: `Destino normalizado: ${result.value}` });
  }

  function confirmar() {
    dialogOpen = false;
    toast.success('Componente montado', {
      description: 'Button, Card, Dialog e Sonner funcionando juntos.'
    });
  }
</script>

<div class="space-y-8">
  <header class="space-y-2">
    <h1 class="text-3xl font-semibold tracking-tight">Página de prova dos componentes</h1>
    <p class="text-muted-foreground max-w-2xl text-sm">
      Esta rota existe para provar que o shadcn-svelte está de fato integrado: ela monta os oito
      componentes do kit. Se algo aqui quebrar, o <code class="font-mono text-xs">pnpm check</code>
      e o e2e
      <code class="font-mono text-xs">tests/e2e/shadcn.spec.ts</code> falham junto.
    </p>
  </header>

  <div class="grid gap-6 md:grid-cols-2">
    <Card>
      <CardHeader>
        <CardTitle>Formulário</CardTitle>
        <CardDescription>Label, Input e Button com estado controlado.</CardDescription>
      </CardHeader>
      <CardContent class="space-y-3">
        <div class="space-y-2">
          <Label for="email">E-mail</Label>
          <Input
            id="email"
            type="email"
            placeholder="voce@exemplo.com"
            bind:value={email}
            autocomplete="email"
          />
        </div>
        <p class="text-muted-foreground text-xs">
          Valor atual: <span data-testid="email-value">{email || '(vazio)'}</span>
        </p>
      </CardContent>
      <CardFooter class="gap-2">
        <Button onclick={enviar}>Enviar</Button>
        <Button variant="outline" onclick={() => (email = '')}>Limpar</Button>
      </CardFooter>
    </Card>

    <Card>
      <CardHeader>
        <CardTitle>Overlays</CardTitle>
        <CardDescription>Dialog, Dropdown Menu e Sonner.</CardDescription>
      </CardHeader>
      <CardContent class="flex flex-wrap gap-2">
        <Dialog bind:open={dialogOpen}>
          <DialogTrigger>
            {#snippet child({ props })}
              <Button {...props}>Abrir dialog</Button>
            {/snippet}
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Confirmar operação</DialogTitle>
              <DialogDescription>
                Este dialog é um componente bits-ui por baixo, então foco e teclado funcionam.
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <DialogClose>
                {#snippet child({ props })}
                  <Button variant="outline" {...props}>Cancelar</Button>
                {/snippet}
              </DialogClose>
              <Button onclick={confirmar}>Confirmar</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        <DropdownMenu>
          <DropdownMenuTrigger>
            {#snippet child({ props })}
              <Button variant="outline" {...props}>Abrir menu</Button>
            {/snippet}
          </DropdownMenuTrigger>
          <DropdownMenuContent align="start" class="w-48">
            <DropdownMenuLabel>Ações</DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => toast('Item "Documentação"')}>
              Documentação
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => toast('Item "Repositório"')}>
              Repositório
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>

        <Button variant="secondary" onclick={() => toast.info('Toast de exemplo')}>
          Disparar toast
        </Button>
      </CardContent>
    </Card>
  </div>

  <Card>
    <CardHeader>
      <CardTitle>Tabela</CardTitle>
      <CardDescription>Table com caption, header e body.</CardDescription>
    </CardHeader>
    <CardContent>
      <Table>
        <TableCaption>Bindings do Cloudflare que o harness cobre.</TableCaption>
        <TableHeader>
          <TableRow>
            <TableHead>Binding</TableHead>
            <TableHead>Uso</TableHead>
            <TableHead class="text-right">Skill</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow>
            <TableCell class="font-mono text-xs">env.DB</TableCell>
            <TableCell>Banco SQL</TableCell>
            <TableCell class="text-right font-mono text-xs">cloudflare-d1</TableCell>
          </TableRow>
          <TableRow>
            <TableCell class="font-mono text-xs">env.CACHE</TableCell>
            <TableCell>Cache e flags</TableCell>
            <TableCell class="text-right font-mono text-xs">cloudflare-kv</TableCell>
          </TableRow>
          <TableRow>
            <TableCell class="font-mono text-xs">env.STORAGE</TableCell>
            <TableCell>Objetos</TableCell>
            <TableCell class="text-right font-mono text-xs">cloudflare-r2</TableCell>
          </TableRow>
          <TableRow>
            <TableCell class="font-mono text-xs">env.AI</TableCell>
            <TableCell>LLM via AI Gateway</TableCell>
            <TableCell class="text-right font-mono text-xs">cloudflare-ai-gateway</TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </CardContent>
  </Card>
</div>
