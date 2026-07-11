#!/usr/bin/env bash
#
# build-guard.sh — hook PreToolUse (Bash) do dev-harness.
#
# Bloqueia comandos de dev-server / build / watch do ecossistema JS que
# torram token a toa quando a IA tenta roda-los: dev servers nunca encerram
# (a sessao fica presa no stream) e builds despejam output gigante.
#
# Se a IA precisar mesmo desse comando, o dev roda ele proprio — no Claude Code,
# via prefixo `!` (ex.: `!npm run build`) — para o output cair na conversa.
#
# Ligado por padrao (opt-out). Desligue com:
#   export DEV_HARNESS_BUILD_GUARD=0
#
# Entrada: JSON do hook no stdin ({ tool_input.command, ... }).
# Saida:   exit 0 = deixa passar; exit 2 = bloqueia (stderr vai para o agente).
# Sem parser JSON (jq/python3), falha aberto: nao bloqueia nada.

set -u

# --- opt-out: default ON; qualquer valor "falso" desliga o guard
case "${DEV_HARNESS_BUILD_GUARD:-1}" in
  0 | false | FALSE | off | OFF | no | NO) exit 0 ;;
esac

INPUT="$(cat)"

# --- pre-filtro barato: so segue se ha um verbo/ferramenta suspeito na string
case "$INPUT" in
  *dev* | *build* | *serve* | *watch* | *preview* | *start* | *vite* | *webpack* | *next* | *nuxt* | *ng*) ;;
  *) exit 0 ;;
esac

# --- extrai o command do JSON (jq > python3 > falha aberto)
if command -v jq > /dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
elif command -v python3 > /dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')
else
  exit 0
fi
[ -z "$CMD" ] && exit 0

# --- quebra em segmentos (&&, ||, |, ; e quebras de linha)
SEGMENTS=$(printf '%s' "$CMD" | tr '\n' ';' | sed 's/&&/;/g; s/||/;/g; s/|/;/g')

OFFENDER=""
IFS=';' read -ra PARTS <<< "$SEGMENTS"
for part in "${PARTS[@]}"; do
  # trim + remove prefixos que nao mudam o veredito (sudo, VAR=valor)
  seg=$(printf '%s' "$part" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  seg=$(printf '%s' "$seg" | sed -E 's/^(sudo[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//')
  # normaliza espacos duplicados
  seg=$(printf '%s' "$seg" | sed 's/[[:space:]]\{1,\}/ /g')
  [ -z "$seg" ] && continue

  case "$seg" in
    # package managers: npm/pnpm/yarn/bun run <script pesado>
    npm\ run\ dev* | npm\ run\ build* | npm\ run\ start* | npm\ run\ serve* | npm\ run\ watch* | npm\ run\ preview*) OFFENDER="$seg" ;;
    npm\ start | npm\ start\ *) OFFENDER="$seg" ;;
    pnpm\ run\ dev* | pnpm\ run\ build* | pnpm\ run\ start* | pnpm\ run\ serve* | pnpm\ run\ watch* | pnpm\ run\ preview*) OFFENDER="$seg" ;;
    pnpm\ dev* | pnpm\ build* | pnpm\ start* | pnpm\ serve* | pnpm\ watch* | pnpm\ preview*) OFFENDER="$seg" ;;
    yarn\ run\ dev* | yarn\ run\ build* | yarn\ run\ start* | yarn\ run\ serve* | yarn\ run\ watch* | yarn\ run\ preview*) OFFENDER="$seg" ;;
    yarn\ dev* | yarn\ build* | yarn\ start* | yarn\ serve* | yarn\ watch* | yarn\ preview*) OFFENDER="$seg" ;;
    bun\ run\ dev* | bun\ run\ build* | bun\ run\ start* | bun\ run\ serve* | bun\ run\ watch* | bun\ run\ preview*) OFFENDER="$seg" ;;
    bun\ dev* | bun\ build* | bun\ start* | bun\ serve* | bun\ watch* | bun\ preview*) OFFENDER="$seg" ;;
    # ferramentas diretas
    vite | vite\ * | webpack | webpack\ *) OFFENDER="$seg" ;;
    next\ dev* | next\ build* | next\ start*) OFFENDER="$seg" ;;
    nuxt\ dev* | nuxt\ build* | nuxt\ start* | nuxt\ generate*) OFFENDER="$seg" ;;
    ng\ serve* | ng\ build*) OFFENDER="$seg" ;;
    *) continue ;;
  esac
  break
done

[ -z "$OFFENDER" ] && exit 0

cat >&2 << EOF
BLOQUEADO pelo build-guard: "$OFFENDER"
Dev servers nao encerram (a sessao fica presa) e builds despejam output enorme —
rodar isso pela IA torra token a toa.

Se precisar mesmo executar, peca ao desenvolvedor para rodar ele proprio.
No Claude Code, ele digita com o prefixo "!":  !$OFFENDER

Para desligar este guard neste projeto/sessao:  export DEV_HARNESS_BUILD_GUARD=0
EOF
exit 2
