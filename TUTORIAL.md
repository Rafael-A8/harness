# 📦 dev-harness — Tutorial de instalação e uso

> [!info] O que é
> O **dev-harness** é um *plugin do Claude Code* (comandos, agentes, hooks e scripts) que leva um projeto da ideia ao código de forma estruturada: especificação formal → planejamento em fases → execução autônoma com validação — sem abrir mão do controle humano nas decisões.
> É **agnóstico de stack**: quem define linguagem/framework/comandos são os documentos do próprio projeto, nunca o plugin.

- **Marketplace:** `alvarino-harness`
- **Plugin:** `dev-harness`
- **Repositório:** `git@github.com:Rafael-A8/harness.git` *(privado)*
- **Namespace dos comandos:** `/dev-harness:*`

---

## 🗺️ Índice

1. [[#⚙️ Parte 1 — Ativar em outra máquina (repo privado)|Ativar em outra máquina]]
2. [[#🧑‍💻 Parte 2 — Os comandos|Os comandos]] · [[#🎬 Exemplos de uso no dia a dia|Exemplos do dia a dia]]
3. [[#🤖 Parte 3 — ralph.sh (execução autônoma)|ralph.sh]]
4. [[#🔄 Parte 4 — Atualizar o plugin|Atualizar]]
5. [[#🧯 Parte 5 — Troubleshooting|Troubleshooting]]

---

## ⚙️ Parte 1 — Ativar em outra máquina (repo privado)

> [!warning] Repositório privado
> Como o repo é **privado**, o outro dev precisa de **duas coisas**: (a) ter acesso ao repositório na conta GitHub dele, e (b) uma **chave SSH** cadastrada. Sem isso o `marketplace add` falha com erro de permissão.

### Passo 0 — Dar acesso ao repositório

No GitHub (dono do repo), adicione o colega como colaborador:

**https://github.com/Rafael-A8/harness** → **Settings** → **Collaborators** → **Add people** → usuário/email do colega.

O colega aceita o convite que chega por email. *(Na sua própria máquina do trabalho, esse passo não é necessário — você já é o dono.)*

### Passo 1 — Gerar a chave SSH (na máquina do colega)

```bash
ssh-keygen -t ed25519 -C "email-do-dev@exemplo.com"
```

Pressione **Enter** nas 3 perguntas (local padrão + passphrase vazia).

> [!tip] Já tem chave?
> Se `~/.ssh/id_ed25519.pub` já existir, pule a geração e reutilize a chave existente.

### Passo 2 — Copiar a chave **pública**

```bash
cat ~/.ssh/id_ed25519.pub
```

Copie a linha inteira (`ssh-ed25519 AAAA... email`).

> [!danger] Nunca compartilhe a chave privada
> Compartilhe **apenas** o arquivo terminado em `.pub`. O arquivo sem `.pub` é secreto.

### Passo 3 — Cadastrar no GitHub

**https://github.com/settings/ssh/new** → Title: (qualquer nome, ex. `PC Trabalho`) → Key type: `Authentication Key` → cole a chave → **Add SSH key**.

### Passo 4 — Testar a conexão

```bash
ssh -T git@github.com
```

Digite `yes` na primeira vez. Sucesso = `Hi <usuario>! You've successfully authenticated`.

### Passo 5 — Instalar o plugin no Claude Code

Dentro do Claude Code, rode os dois comandos:

```
/plugin marketplace add Rafael-A8/harness
/plugin install dev-harness@alvarino-harness
```

Depois:

```
/reload-plugins
```

> [!success] Pronto
> Os comandos `/dev-harness:init`, `/dev-harness:plan` e `/dev-harness:ai-context` já aparecem na lista de skills.

> [!note] Alternativa: instalação por pasta local
> Se o colega tiver o repositório **clonado localmente** (ex. `~/projetos/harness`), dá pra instalar sem depender do GitHub:
> ```
> /plugin marketplace add /caminho/para/harness
> /plugin install dev-harness@alvarino-harness
> ```
> Neste modo, após editar o plugin rode `/plugin marketplace update alvarino-harness` para atualizar o cache.

---

## 🧑‍💻 Parte 2 — Os comandos

> [!important] Onde rodar
> Os comandos rodam **dentro do projeto que você quer construir** — nunca dentro da pasta do plugin. Eles leem e escrevem em `.spec/` do projeto-alvo.

São 3 pipelines independentes que se encaixam:

```
 IDEIA                                              CÓDIGO
   │                                                  ▲
   ▼                                                  │
 /init  →  descrição → user stories → schema → fases  │
   │                                                  │
   │   /plan "<feature>"  →  SPEC + PLAN + PHASES ─────┤
   ▼                                                  │
 project-phases.md / PHASES.md  ───────►  ralph.sh ───┘
                                          (execução autônoma)

 /ai-context ─► AGENTS.md + docs/agents/*  (documenta o código já implementado)
```

### `/dev-harness:init` — cadeia do zero ao plano do projeto

Roteador diagnóstico: mostra o estado dos artefatos em `.spec/init/` e **invoca o próximo passo** da cadeia (um passo por execução — re-rode para avançar).

| # | Comando | Gera |
|---|---|---|
| 1 | `/dev-harness:init:project-description` | `.spec/init/project-description.md` |
| 2 | `/dev-harness:init:user-stories` | `.spec/init/user-stories.md` |
| 3 | `/dev-harness:init:database-schema` | `.spec/init/database-schema.md` (DBML) |
| 4 | `/dev-harness:init:project-phases` | `.spec/init/project-phases.md` *(input padrão do ralph.sh)* |

> [!tip] Staleness automática
> Cada artefato carrega um *stamp* (sha256) dos insumos. Se um insumo mudar, o `/init` marca o downstream como **desatualizado** e o re-run atualiza só os deltas.

### `/dev-harness:plan` — planejamento de uma feature

```
/dev-harness:plan "<descrição da feature ou caminho de um arquivo>"
```

Produz em `.spec/features/<slug>/`:

| Artefato | Conteúdo |
|---|---|
| `SPEC.md` | Especificação formal (GEARS, seções RIGID/FLEXIBLE, AS IS / TO BE, acceptance criteria binários) |
| `PLAN.md` | Decomposição em tasks, fases de dependência, riscos |
| `PHASES.md` | Visão executável pelo `ralph.sh` |
| `openapi.yaml` / `service.proto` / `asyncapi.yaml` | Contratos formais (quando a SPEC declara API) |

Características: checkpoints humanos em cada etapa, *clarifier* adversarial de requisitos, e **nunca escreve código de aplicação** — só especifica. O fechamento aponta o handoff:

```bash
./ralph.sh .spec/features/<slug>/PHASES.md
```

### `/dev-harness:ai-context` — árvore de contexto canônica

```
/dev-harness:ai-context [path] [+id] [-id] [--adopt]
```

Gera/atualiza, a partir do **código implementado** (nunca lê `.spec/`):

- `AGENTS.md` (6 seções) + `CLAUDE.md` (redirect curto)
- `docs/agents/*.md`: project_overview, architecture, tech_stack, coding_guidelines, domain_rules, api_contracts, data_model, dependencies

> [!note] Idempotente e AS IS
> Upsert seguro (re-rodar atualiza só o que sofreu drift). Documenta **a realidade**, nunca inventa nem prescreve. Arquivos escritos à mão (sem banner na linha 3) nunca são sobrescritos.

### `/dev-harness:implement` — executor interativo por fase

```
/dev-harness:implement [PHASES.md ou slug da feature] [--phase N] [--from N] [--test-cmd "<cmd>"]
```

O **contraponto com você no loop** do `ralph.sh`: executa um plano faseado **uma fase por vez, na própria sessão do Claude Code**, parando em um **checkpoint** antes de commitar cada fase. É o meio-termo entre implementar 100% na mão e soltar o ralph 100% autônomo.

Por fase ele: anuncia as tasks → implementa no working tree → **roda a suite de testes** do projeto → verifica task a task se está de fato no código → **pergunta a você** o que fazer:

| Opção no checkpoint | Efeito |
|---|---|
| **Aprovar & commitar** | Commita a fase (`feat(phase-N): <título>`) e pergunta se continua |
| **Revisar** | Você descreve o ajuste; ele refaz e volta ao checkpoint |
| **Deixar sem commit** | Mantém o código no working tree, não commita |
| **Parar** | Encerra o run |

> [!tip] Retomada
> Sem flags, ele **retoma na próxima fase não concluída** (progresso em `.phases/interactive.progress`). `--phase N` faz só aquela fase; `--from N` começa na fase N.

> [!important] Só no Claude Code
> `/implement` é um slash command → funciona **apenas no Claude Code**. O equivalente para quem usa **Codex CLI** é o `./scripts/ralph.sh --engine codex` (autônomo, sem checkpoint). Veja [[#🤖 Parte 3 — ralph.sh (execução autônoma)|Parte 3]].

---

### 🎬 Exemplos de uso no dia a dia

> [!tip] Como ler os exemplos
> Tudo que vem depois do comando é o `$ARGUMENTS` — texto livre. Você não precisa formatar nada; o comando entrevista você para completar o que faltar.

#### 🌱 Começar um projeto novo (cadeia `init`)

> **Cenário:** vou tocar um novo sistema de controle de estoque e quero a base de specs antes de codar.

```
/dev-harness:init:project-description "Sistema web de controle de estoque para pequenas lojas, com cadastro de produtos, entradas/saídas e alerta de estoque mínimo. Stack Laravel + Vue."
```

O comando inspeciona a pasta, faz algumas perguntas pra fechar as lacunas (ex.: "tem multiusuário? controle de permissões?") e grava `.spec/init/project-description.md`. Em seguida, avance a cadeia rodando **um passo por vez**:

```
/dev-harness:init            → mostra o status e chama o próximo (user-stories)
/dev-harness:init            → chama database-schema
/dev-harness:init            → chama project-phases
```

> [!success] Resultado
> No fim você tem `.spec/init/project-phases.md` — pronto para o `ralph.sh` construir o projeto fase a fase.

#### 🧩 Planejar uma task do dia a dia (o mais usado — `/plan`)

> **Cenário:** o líder te passou um card: *"Adicionar exportação de relatório de vendas em CSV e PDF, com filtro por período."* Antes de sair codando, você gera um plano formal.

```
/dev-harness:plan "Exportação do relatório de vendas em CSV e PDF, com filtro por período (data inicial/final). Botão na tela de Relatórios; PDF com o logo da empresa no cabeçalho."
```

O que acontece:
1. Ele **normaliza** sua descrição e te pede confirmação.
2. O agente `specifier` escreve a **SPEC.md** (com acceptance criteria binários) → você aprova.
3. Se houver ambiguidade, o `clarifier` te faz perguntas objetivas (ex.: "o período filtra por data do pedido ou data de pagamento?").
4. O `planner` gera **PLAN.md** + **PHASES.md** em `.spec/features/exportacao-relatorio-vendas/`.

> [!example] Passar a descrição por arquivo
> Se o card é grande, salve num `.md` e aponte o caminho:
> ```
> /dev-harness:plan docs/cards/RB-482-export-relatorio.md
> ```

> [!example] Task pequena (tier light)
> Para algo simples ele reduz a cerimônia automaticamente:
> ```
> /dev-harness:plan "Adicionar campo 'telefone' (opcional) no cadastro de cliente e mostrar na listagem."
> ```

Depois de aprovar o plano, você implementa manualmente **ou** deixa o ralph executar:
```bash
./scripts/ralph.sh .spec/features/exportacao-relatorio-vendas/PHASES.md --engine claude
```

#### 🔄 Manter a documentação em dia (`/ai-context`)

> **Cenário:** terminei uma feature e quero que o `AGENTS.md`/`docs/agents/*` reflitam o código atual (isso alimenta o próximo `/plan` com contexto de arquitetura).

```
/dev-harness:ai-context
```

Rodar sem argumento cobre o repo inteiro (idempotente). Para focar só num subconjunto:

```
/dev-harness:ai-context +AGENTS +architecture      → regenera só esses dois
/dev-harness:ai-context app/Services               → limita a varredura a um caminho
```

> [!tip] Quando rodar cada um
> - `/plan` → **toda vez** que pega uma task nova, antes de codar.
> - `/implement` → para construir o plano com você acompanhando cada fase.
> - `/ai-context` → depois de mergear uma feature relevante (mantém o contexto fresco).
> - cadeia `init` → **uma vez** no começo do projeto (e re-run pontual quando o escopo macro muda).

#### ⚙️ Implementar acompanhando cada fase (`/implement`)

> **Cenário:** o `/plan` gerou o `PHASES.md` da feature de exportação; quero construir com o Claude, mas revisando fase a fase antes de commitar.

```
/dev-harness:implement exportacao-relatorio-vendas
```

Ele implementa a **primeira fase**, roda os testes, mostra o diff + checklist de tasks e para no checkpoint. Você aprova → ele commita `feat(phase-1): ...` e pergunta se segue. Para fazer só uma fase específica:

```
/dev-harness:implement exportacao-relatorio-vendas --phase 2
```

#### 🗓️ Um dia típico, do começo ao fim

```text
1. Pega o card               →  /dev-harness:plan "<descrição do card>"
2. Aprova SPEC + responde clarifier
3. Revisa o PHASES.md gerado
4. Implementa                →  /dev-harness:implement <slug>          (você aprova cada fase)
                             →  ou  ./scripts/ralph.sh <PHASES.md>     (autônomo, sem checkpoint)
                             →  ou  na mão
5. Testa e abre o PR
6. Após o merge              →  /dev-harness:ai-context   (atualiza a doc de contexto)
```

---

## 🤖 Parte 3 — ralph.sh (execução autônoma)

> [!info] O que é
> Script **bash independente** (roda fora do Claude Code) que lê um documento de fases, quebra por `## Phase N: <título>` e alimenta **cada fase a uma sessão nova** do engine (Codex ou Claude), sem interação humana, com validação mecânica e **1 commit por fase concluída**.

> [!abstract] Claude Code vs. Codex CLI — o que cada um roda
> A camada de **autoria** (`/init`, `/plan`, `/ai-context`, `/implement`), os agentes e os hooks são slash commands → **só Claude Code**. Já o `ralph.sh` é **agnóstico de engine**: executa um plano com Codex **ou** Claude via `--engine`.
>
> | Componente | Claude Code | Codex CLI |
> |---|:---:|:---:|
> | `/plan`, `/init`, `/ai-context`, `/implement` | ✅ | ❌ |
> | `scripts/ralph.sh` (executor) | ✅ `--engine claude` | ✅ `--engine codex` |
> | Artefatos `.spec/*` (markdown) | ✅ | ✅ (só ler) |
>
> Ou seja: um dev de Codex **executa** planos com `ralph.sh --engine codex`, mas o `PHASES.md` precisa ser gerado pela camada interativa (Claude Code).

### Pré-requisitos

- Repositório **git** com árvore de trabalho **limpa**
- Engine à escolha:
  - **Claude:** `npm install -g @anthropic-ai/claude-code` + `ANTHROPIC_API_KEY`
  - **Codex:** `npm install -g @openai/codex` + `OPENAI_API_KEY`

### Uso

```bash
./scripts/ralph.sh [opções] [caminho-do-arquivo]
# ex.:
./scripts/ralph.sh .spec/features/login/PHASES.md --engine claude
```

Sem argumento, resolve: `.spec/init/project-phases.md` → `.spec/project-phases.md`.

### Os 4 gates de validação

| Gate | Pergunta | Como decide |
|---|---|---|
| 0 | O engine terminou de verdade? | JSON de resultado (claude) / exit code (codex) |
| 1 | A sessão escreveu código? | Assinatura da árvore antes/depois (sinal, não veredito) |
| 2 | A suite de testes passa? | Rodada **pelo ralph**, fora da sessão do agente |
| 3 | Cada task está no código? | Sessão verificadora independente, read-only |

Qualquer gate vermelho → **ciclo de correção** (nova sessão com a causa real; default 3 ciclos/fase).

### Opções úteis

| Opção | Efeito |
|---|---|
| `--engine codex\|claude` | Engine (default `codex`) |
| `--from N` | Começa na fase N |
| `--keep-going` | Continua após falha (commit `wip`) |
| `--max-cycles N` | Ciclos de correção por fase (default 3) |
| `--test-cmd "<cmd>"` | Comando de teste (gate 2) |
| `--no-verify` | Desliga o gate 3 |

---

## 🔄 Parte 4 — Atualizar o plugin

Quando o repositório receber novas mudanças (`git push`), cada dev atualiza a cópia local assim:

```
/plugin marketplace update alvarino-harness
```

E, se necessário, `/reload-plugins`.

> [!note] Versionamento (SemVer + tags)
> O plugin segue [SemVer](https://semver.org/): cada release ganha uma tag `vX.Y.Z` e uma entrada no `CHANGELOG.md`. A versão fica em `.claude-plugin/plugin.json` (`marketplace.json` acompanha). Para conferir o que mudou, leia o `CHANGELOG.md`; para saber qual versão está publicada, veja a última tag no GitHub (`git tag` ou a aba **Releases**).

> [!note] CI (para quem contribui no plugin)
> O repositório roda um workflow do GitHub Actions em cada push/PR: valida os manifests JSON (com version-match entre plugin e marketplace), `check-shell.sh`, `check-init-drift.sh` e a suite `test-ralph.sh` (engines mock, sem rede). Um PR com o CI vermelho não deve ser mergeado.

> [!note] Hook sail-guard
> O plugin traz um hook `sail-guard` que, em projetos **Laravel Sail**, bloqueia comandos PHP/DB rodados no host e sugere o equivalente via `./vendor/bin/sail`. Em qualquer outro projeto ele **não faz nada** (falha aberto) — pode deixar ativo sempre.

---

## 🧯 Parte 5 — Troubleshooting

> [!bug] `marketplace add` falha com "permission denied" / "repository not found"
> O colega não tem acesso ao repo privado **ou** a chave SSH não está cadastrada. Refazer [[#Passo 0 — Dar acesso ao repositório|Passo 0]] e [[#Passo 3 — Cadastrar no GitHub|Passo 3]]. Testar com `ssh -T git@github.com`.

> [!bug] Comandos `/dev-harness:*` não aparecem
> Rodar `/reload-plugins`. Se persistir, conferir a instalação em `/plugin` (deve listar `dev-harness` como instalado).

> [!bug] Editei o plugin mas o Claude Code usa a versão antiga
> O Claude Code lê de um **cache** (`~/.claude/plugins/cache/...`). Rodar `/plugin marketplace update alvarino-harness`.

> [!bug] `ralph.sh` aborta no preflight
> Árvore git suja (commite/stashe antes), ou documento de fases fora do formato `## Phase N: <título>`, ou (Laravel Sail) containers parados — subir com `./vendor/bin/sail up -d`.

---

> [!quote] Princípios de design
> Roteadores finos (comandos orquestram, agentes autoram) · Confie mas verifique (validação mecânica) · Realidade ≠ intenção (`/ai-context` documenta o implementado; `.spec/` documenta a intenção) · Sem segredos (`.env` nunca é lido) · Staleness explícita, nunca bloqueante.
