<!--
  TEMPLATE — SPEC.md

  Este template é a base para `docs/SPEC.md` gerado pelo comando
  `/sveflare-spec`.

  Como usar:
  1. Copie este arquivo para `docs/SPEC.md`.
  2. Substitua todos os `<placeholders>`.
  3. Remova os comentários HTML (<!-- ... -->) após preencher.
  4. Rode `/sveflare-spec` se preferir que o agente preencha
     automaticamente.

  Regras:
  - Critérios de aceitação DEVEM ser testáveis.
  - Não mencione tecnologia específica (exceto quando indispensável).
  - Não proponha schema de banco, endpoints ou componentes.
  - Não estime prazos.
  - Foco em O QUÊ e POR QUÊ, não em COMO.
-->

# SPEC — <nome da feature>

**ID:** SPEC-<NNN>
**Versão:** 1.0
**Data:** <YYYY-MM-DD>
**Autor:** <nome ou sessão DSH>
**Status:** `rascunho` <!-- rascunho | em-revisão | aprovado | obsoleto -->
**Aprovado em:** <YYYY-MM-DD>
**Aprovado por:** <nome>

---

## 1. Visão geral

<!--
  2-3 parágrafos explicando:
  - O que é a feature
  - Por que ela existe (problema que resolve)
  - Quem se beneficia
  - Contexto de negócio

  Não repita o título. Explique como se o leitor não soubesse nada
  sobre o projeto.
-->

<Parágrafo 1: o que é a feature e qual problema resolve.>

<Parágrafo 2: quem usa, em que contexto, e qual o valor entregue.>

<Parágrafo 3 (opcional): contexto de negócio, relação com outras
features, ou restrições de alto nível.>

---

## 2. Usuários e casos de uso

<!--
  Liste personas/roles e casos de uso concretos.
  Cada caso de uso deve ser uma narrativa curta: "Como <role>, eu
  quero <ação> para <benefício>."
-->

### Personas / roles

| Role | Descrição | Frequência de uso |
|------|-----------|-------------------|
| <role 1> | <quem é, o que faz> | <diária/semanal/mensal> |
| <role 2> | <quem é, o que faz> | <...> |

### Casos de uso

**UC-1 — <título curto>**
Como <role>, eu quero <ação> para <benefício>.

**Fluxo principal:**
1. <passo 1>
2. <passo 2>
3. <passo 3>

**Fluxos alternativos:**
- Se <condição>: <comportamento>

**UC-2 — <título curto>**
<...>

**UC-3 — <título curto>**
<...>

---

## 3. Critérios de aceitação

<!--
  OBRIGATÓRIO: formato Dado/Quando/Então.

  Cada critério DEVE ser:
  - Verificável por comando, teste ou inspeção
  - Específico (não "funciona bem")
  - Binário (passa ou não passa)

  Mínimo 5, ideal 8-12.

  Exemplos:

  ✅ Bom: "DADO um usuário autenticado, QUANDO ele envia um comentário
     com texto entre 1 e 2000 caracteres, ENTÃO o sistema retorna 201
     e o comentário aparece na lista em até 2 segundos."

  ❌ Ruim: "O sistema deve funcionar bem com comentários."

  ✅ Bom: "DADO um usuário não autenticado, QUANDO ele tenta enviar
     um comentário, ENTÃO o sistema retorna 401."

  ❌ Ruim: "Usuários precisam estar logados."
-->

### Comportamento principal

- [ ] **CA-1**: DADO <contexto>, QUANDO <ação>, ENTÃO <resultado
      observável>.
- [ ] **CA-2**: DADO <contexto>, QUANDO <ação>, ENTÃO <resultado
      observável>.
- [ ] **CA-3**: DADO <contexto>, QUANDO <ação>, ENTÃO <resultado
      observável>.

### Validações e erros

- [ ] **CA-4**: DADO <contexto inválido>, QUANDO <ação>, ENTÃO o
      sistema retorna <status> com mensagem <X>.
- [ ] **CA-5**: DADO <contexto>, QUANDO <ação que excede limite>,
      ENTÃO o sistema <comportamento>.

### Permissões

- [ ] **CA-6**: DADO um usuário <role>, QUANDO <ação>, ENTÃO
      <comportamento esperado>.
- [ ] **CA-7**: DADO um usuário <role diferente>, QUANDO <ação>,
      ENTÃO <comportamento esperado>.

### Performance e limites

- [ ] **CA-8**: DADO <condição>, QUANDO <carga>, ENTÃO <métrica>
      deve ser <valor>.
- [ ] **CA-9**: DADO <condição>, QUANDO <ação>, ENTÃO o sistema
      <comportamento em limite>.

### Estados de erro

- [ ] **CA-10**: DADO <falha de sistema X>, QUANDO <ação>, ENTÃO o
      sistema <comportamento de fallback>.

---

## 4. Regras de negócio

<!--
  Regras que governam o comportamento. Formato de lista.
  Inclua: limites, prazos, permissões, estados, ordenação,
  cálculos.

  Se uma regra depende de decisão futura, mova para "questões em
  aberto" na seção 7.
-->

- **RN-1**: <regra 1>
- **RN-2**: <regra 2>
- **RN-3**: <regra 3>
- **RN-4**: <regra 4>
- **RN-5**: <regra 5>

---

## 5. Fora de escopo

<!--
  OBRIGATÓRIO: mínimo 3 itens.

  O que EXPLICITAMENTE NÃO está incluído nesta feature. Previne
  scope creep e esclarece limites para o leitor.

  Exemplos:
  - Não implementar notificações por email nesta versão.
  - Não implementar busca por texto nesta versão.
  - Não suportar anexos nesta versão.
-->

- Não <item 1>.
- Não <item 2>.
- Não <item 3>.
- Não <item 4> (opcional).

---

## 6. Dependências

<!--
  Features, dados ou sistemas externos dos quais esta feature
  depende.

  Se não houver nenhuma, escreva "Nenhuma."
-->

### Dependências internas

- <Feature X> (já implementada) — usada para <propósito>.
- <Tabela Y> (já existe) — leitura/escrita em <campos>.

### Dependências externas

- <Serviço/API externo> — usado para <propósito>.
- <Dado de terceiro> — fonte: <origem>.

### Dependências de dados

- Requer migração D1? Sim / Não
- Requer novo bucket R2? Sim / Não
- Requer nova chave KV? Sim / Não
- Requer novo endpoint no AI Gateway? Sim / Não

Se não houver dependências, escreva:

> Nenhuma.

---

## 7. Riscos e questões em aberto

<!--
  Riscos técnicos, de produto ou de segurança. Cada um com uma
  PERGUNTA que precisa ser respondida antes do plano técnico.

  Formato obrigatório: risco + pergunta.

  Exemplo:
  - **Risco**: A feature pode gerar picos de custo de LLM.
    **Pergunta**: Qual o limite máximo de chamadas por usuário por
    dia?
-->

### Riscos técnicos

- **Risco**: <descrição>
  **Pergunta**: <o que precisa ser decidido>
  **Impacto se não resolvido**: <baixo/médio/alto>

- **Risco**: <descrição>
  **Pergunta**: <o que precisa ser decidido>
  **Impacto**: <...>

### Riscos de produto

- **Risco**: <descrição>
  **Pergunta**: <...>

### Riscos de segurança

- **Risco**: <descrição>
  **Pergunta**: <...>

### Questões em aberto

<!--
  Liste TODAS as questões que precisam ser respondidas antes de
  começar o plano técnico. Estas questões bloqueiam /sveflare-plan.
-->

- [ ] **Q1**: <questão 1>
- [ ] **Q2**: <questão 2>
- [ ] **Q3**: <questão 3>

Se não houver questões, escreva:

> Nenhuma. O SPEC está completo e pode ir para /sveflare-plan.

---

## 8. Impacto em segurança

<!--
  Análise dos 8 Security Gates do AGENTS.md.

  Para cada gate, marque:
  - APLICA — a feature toca este gate e precisa endereçá-lo.
  - NÃO APLICA — a feature não toca este gate.
  - A DEFINIR — precisa de análise técnica mais profunda.
-->

| Gate | Descrição | Aplica? | Como será endereçado |
|------|-----------|---------|----------------------|
| **Gate 1** | Secrets (nunca hardcode) | <sim/não/a-definir> | <como> |
| **Gate 2** | Input (Zod obrigatório) | <...> | <como> |
| **Gate 3** | D1 (prepared statements) | <...> | <como> |
| **Gate 4** | R2 (privado, signed URL ≤15min) | <...> | <como> |
| **Gate 5** | AI Gateway (guardrails, rate limit) | <...> | <como> |
| **Gate 6** | OWASP Top 10 | <...> | <como> |
| **Gate 7** | Prompt Injection | <...> | <como> |
| **Gate 8** | Deploy (staging → smoke → aprovação) | <...> | <como> |

### Análise complementar

<!--
  Análise adicional específica desta feature.
-->

**Dados sensíveis:**
- <quais dados PII ou sensíveis a feature manipula>
- <como são protegidos>

**Superfície de ataque:**
- <novos endpoints expostos>
- <novos inputs do usuário>
- <novas integrações externas>

**Autenticação / autorização:**
- <quem pode acessar o quê>
- <regras de role>

Se a feature não tocar segurança, escreva:

> Não aplicável. Esta é uma refatoração neutra / mudança de UI sem
> input do usuário / etc.

---

## Aprovação

<!--
  Preenchido ao aprovar o SPEC.
-->

**Revisado por:** <nome / subagente Verifier>
**Data de revisão:** <YYYY-MM-DD>
**Problemas encontrados na revisão:** <N>
**BLOQUEANTES resolvidos:** <N>
**Status final:** `aprovado`

**Questões em aberto respondidas:**
- [x] Q1: <resposta>
- [x] Q2: <resposta>
- [x] Q3: <resposta>

**Próximo passo:** rodar `/sveflare-plan` para gerar o plano técnico.

---

## Histórico de versões

| Versão | Data | Autor | Mudanças |
|--------|------|-------|----------|
| 1.0 | <YYYY-MM-DD> | <autor> | Versão inicial |
| 1.1 | <YYYY-MM-DD> | <autor> | <mudanças> |

---

<!--
  CHECKLIST FINAL antes de marcar como `aprovado`:

  - [ ] Visão geral explica o quê e por quê (2-3 parágrafos).
  - [ ] Pelo menos 2 personas/roles descritas.
  - [ ] Pelo menos 3 casos de uso.
  - [ ] Pelo menos 5 critérios de aceitação em Dado/Quando/Então.
  - [ ] Cada critério é testável (não "funciona bem").
  - [ ] Pelo menos 5 regras de negócio.
  - [ ] Pelo menos 3 itens em "fora de escopo".
  - [ ] Dependências listadas (ou "nenhuma").
  - [ ] Riscos listados com perguntas.
  - [ ] Questões em aberto respondidas.
  - [ ] Impacto em segurança cobre os 8 gates.
  - [ ] Seção de aprovação preenchida.
  - [ ] Nenhum placeholder <...> restante.
  - [ ] Nenhuma decisão técnica no SPEC (só o quê, não como).
-->
