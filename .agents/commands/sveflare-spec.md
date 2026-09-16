---
name: sveflare-spec
description: Inicia uma feature nova com especificação estruturada (SDD). Gera docs/SPEC.md via Drafter e revisa com Verifier.
argument-hint: <descrição da feature em 1-3 frases>
allowed-tools: read, write, edit, grep, bash
model: deepseek-chat
---

# /sveflare-spec — Especificação estruturada de feature

Você está iniciando uma nova feature usando Spec-Driven Development.
Seu objetivo é produzir `docs/SPEC.md` — um documento claro, testável e
sem ambiguidades — antes de qualquer decisão técnica.

## Argumento recebido

O usuário descreveu a feature assim:

```
$ARGUMENTS
```

## Restrições desta sessão

- NÃO escreva código de implementação.
- NÃO crie migrations, endpoints ou componentes.
- NÃO decida arquitetura, stack ou bibliotecas.
- NÃO altere arquivos fora de `docs/` e `.agents/goals/`.
- Peça aprovação explícita antes de qualquer transição de fase.
- Se o argumento estiver vazio ou vago, peça esclarecimento antes de
  prosseguir.

## Fluxo de execução

### Passo 1 — Preparação

1. Leia `AGENTS.md` para relembrar as regras operacionais e os 8
   Security Gates do projeto.
2. Leia `docs/FEATURES.md` (se existir) para conhecer os componentes
   disponíveis.
3. Identifique quais skills são relevantes para esta feature. Carregue
   no máximo 3:
   - Se a feature toca banco → `cloudflare-d1`
   - Se a feature toca upload/arquivos → `cloudflare-r2`
   - Se a feature toca cache/config → `cloudflare-kv`
   - Se a feature toca IA → `cloudflare-ai-gateway`
   - Se a feature tem UI → `sveltekit-runes`
   - Se a feature tem auth → `sveltekit-auth`
   - Se a feature toca input do usuário → `owasp-top10`
   - Se a feature envolve dados sensíveis → `security-leaks`
4. Confirme com o usuário quais skills você carregou e por quê.

### Passo 2 — Drafter gera rascunho

Invoque o subagente **Drafter** com o seguinte prompt:

```text
Você é um engenheiro de produto experiente. Produza um documento de
especificação (`docs/SPEC.md`) para a feature descrita abaixo.

CONTEXTO DO PROJETO:
- Stack: SvelteKit + Cloudflare (Pages, Workers, D1, KV, R2, AI Gateway)
- Regras operacionais: ver AGENTS.md
- Skills relevantes já carregadas: [liste]

FEATURE SOLICITADA:
$ARGUMENTS

ESTRUTURA OBRIGATÓRIA DO SPEC.md:

# SPEC — <nome da feature>

## 1. Visão geral
<2-3 parágrafos explicando o que é a feature e por que ela existe>

## 2. Usuários e casos de uso
<Lista de personas/roles que usam a feature, com 2-5 casos de uso>

## 3. Critérios de aceitação
<Obrigatório: formato Dado/Quando/Então. Cada critério deve ser
VERIFICÁVEL por um comando, teste ou inspeção. Nada de "funciona bem"
ou "é rápido". Mínimo 5, ideal 8-12.>

Exemplo:
- **CA-1**: DADO um usuário autenticado, QUANDO ele envia um comentário
  com texto entre 1 e 2000 caracteres, ENTÃO o sistema retorna 201 e o
  comentário aparece na lista em até 2 segundos.
- **CA-2**: DADO um usuário autenticado, QUANDO ele envia um comentário
  vazio, ENTÃO o sistema retorna 400 com mensagem "comentário não pode
  ser vazio".

## 4. Regras de negócio
<Regras que governam o comportamento: limites, prazos, permissões,
estados. Formato de lista.>

## 5. Fora de escopo
<O que explicitamente NÃO está incluído nesta feature. Isso previne
scope creep. Mínimo 3 itens.>

## 6. Dependências
<Features, dados ou sistemas externos dos quais esta feature depende.
Se não houver, escreva "nenhuma".>

## 7. Riscos e questões em aberto
<Riscos técnicos, de produto ou de segurança. Cada um com uma pergunta
que precisa ser respondida antes do plano técnico.>

## 8. Impacto em segurança
<Análise dos 8 Security Gates do AGENTS.md. Para cada um, diga se
aplica, não aplica, ou "a definir".>

RESTRIÇÕES:
- NÃO mencione tecnologia específica (exceto quando indispensável).
- NÃO proponha schema de banco, endpoints ou componentes.
- NÃO estime prazos.
- Foco em O QUÊ e POR QUÊ, não em COMO.
- Se algo estiver ambíguo na feature solicitada, escreva a ambiguidade
  como questão em aberto em vez de inventar uma resposta.

Entregue o SPEC.md completo.
```

Salve a saída do Drafter como rascunho interno (não escreva em disco
ainda).

### Passo 3 — Verifier revisa

Invoque o subagente **Verifier** com o seguinte prompt:

```text
Você é um revisor independente e cético. NÃO confie no Drafter. Sua
tarefa é encontrar problemas no SPEC.md abaixo.

RASCUNHO DO SPEC:
<cole aqui o rascunho do Drafter>

REGRAS DO PROJETO:
<cole aqui as regras relevantes do AGENTS.md>

VERIFIQUE ESPECIFICAMENTE:

1. CRITÉRIOS DE ACEITAÇÃO
   - Cada critério é testável por comando, teste ou inspeção?
   - Cada critério tem condições claras (Dado/Quando/Então)?
   - Há critérios que dependem de decisões técnicas prematuras?

2. SUPOSIÇÕES NÃO DECLARADAS
   - O SPEC assume algo sobre o usuário que não foi dito?
   - Assume comportamento de sistemas externos?
   - Assume dados que podem não existir?

3. AMBIGUIDADES
   - Alguma regra de negócio tem mais de uma interpretação?
   - Algum caso de uso tem resultado ambíguo?
   - Algum critério pode ser "cumprido" de formas incompatíveis?

4. LACUNAS
   - Falta algum caso de uso óbvio?
   - Falta alguma regra de negócio?
   - Falta considerar algum estado de erro?

5. SEGURANÇA
   - O SPEC menciona input do usuário? Se sim, há critério de
     validação?
   - Há dados sensíveis? Se sim, há critério de proteção?
   - Há alguma operação destrutiva sem confirmação?

6. ESCOPO
   - Há features que "vazaram" para o escopo sem justificativa?
   - O "fora de escopo" é suficientemente claro?

REPORTE:
- Para cada problema: arquivo, seção, problema concreto, sugestão.
- Classifique cada problema: BLOQUEANTE / IMPORTANTE / MENOR.
- NÃO reescreva o SPEC. Apenas reporte.
- Se algo estiver OK, diga explicitamente "OK".
```

### Passo 4 — Consolidação

1. Se o Verifier reportar problemas BLOQUEANTES, invoque o Drafter
   novamente com o feedback e gere uma segunda versão do SPEC.
2. Repita o ciclo Verifier → Drafter até não haver BLOQUEANTES
   (máximo 3 iterações).
3. Quando o SPEC estiver estável, escreva em `docs/SPEC.md`.

### Passo 5 — Apresentação ao usuário

Apresente:

```markdown
## SPEC.md pronto para revisão

**Resumo executivo:**
- Feature: <nome>
- Casos de uso: <N>
- Critérios de aceitação: <N>
- Riscos identificados: <N>
- Iterações Drafter↔Verifier: <N>

**Arquivo:** `docs/SPEC.md`

**Pontos que precisam da sua decisão:**
1. <questão em aberto 1>
2. <questão em aberto 2>

**Próximos passos:**
- Revise o SPEC e responda às questões em aberto.
- Quando aprovar, rode `/sveflare-plan` para gerar o plano técnico.
```

## Comportamento em casos especiais

### Se o argumento estiver vazio

Pergunte ao usuário:

```text
Qual feature você quer especificar? Descreva em 1-3 frases:
- O que ela faz?
- Quem usa?
- Qual problema resolve?
```

Aguarde resposta antes de prosseguir.

### Se o argumento for vago

Exemplo: "quero uma página nova".

Pergunte especificamente:

```text
Sua descrição está vaga. Preciso de mais detalhes:
1. Qual o propósito da página?
2. Quem vai acessar (autenticado, público, admin)?
3. Quais ações o usuário pode tomar nela?
4. Há dados que ela lê ou escreve?
```

### Se o SPEC já existir

Pergunte:

```text
Já existe um `docs/SPEC.md`. Você quer:
a) Substituir completamente
b) Adicionar uma seção nova
c) Revisar o existente
d) Cancelar

Escolha uma opção.
```

### Se a feature for grande demais

Se o Drafter produzir mais de 15 critérios de aceitação, avise:

```text
Esta feature parece grande demais para um único SPEC (mais de 15
critérios de aceitação). Considere:

a) Dividir em 2-3 SPECs menores, cada um com escopo claro
b) Prosseguir com o SPEC grande (não recomendado)

O que prefere?
```

## Evidências de conclusão

Antes de declarar o comando concluído, verifique:

- [ ] `docs/SPEC.md` existe e está escrito.
- [ ] Tem todas as 8 seções obrigatórias.
- [ ] Critérios de aceitação seguem formato Dado/Quando/Então.
- [ ] Cada critério é testável (nenhum "funciona bem").
- [ ] Fora de escopo tem pelo menos 3 itens.
- [ ] Impacto em segurança cobre os 8 Security Gates.
- [ ] Verifier não reportou BLOQUEANTES (ou foram resolvidos).
- [ ] Usuário foi apresentado ao resumo executivo.

Se algum item falhar, continue trabalhando antes de declarar
conclusão.

## Exemplo de uso

```text
/sveflare-spec Quero adicionar um sistema de comentários em posts.
Usuários autenticados podem comentar, editar seus comentários por 15
minutos, e deletar a qualquer momento. Admins podem deletar qualquer
comentário. Comentários suportam texto plano (sem markdown por
enquanto) e têm limite de 2000 caracteres.
```

**Resultado esperado:** após 1-3 iterações Drafter↔Verifier, um
`docs/SPEC.md` com ~10 critérios de aceitação, ~5 regras de negócio,
e uma lista clara de questões em aberto para você decidir.

## Referências

- `.agents/templates/SPEC.md` — template base do documento.
- `AGENTS.md` — regras operacionais e Security Gates.
- `.agents/skills/owasp-top10/SKILL.md` — checklist de segurança.
- `.agents/skills/security-leaks/SKILL.md` — categorias de vazamento.
- `docs/USAGE.md` — fluxo completo de uso.
- `docs/HARNESS.md` — arquitetura do harness (seção 7, subagentes).
