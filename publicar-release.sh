#!/usr/bin/env bash
# Reempacota o sistema e publica um novo release no GitHub.
# Uso: ./publicar-release.sh   (lê a versão do system.json e cria a tag vX.Y.Z)
# Pré-requisitos: git com o repo já commitado/pushado, e `gh` autenticado.
set -euo pipefail
cd "$(dirname "$0")"

VER=$(python -c "import json;print(json.load(open('system.json',encoding='utf-8'))['version'])")
TAG="v$VER"
echo ">> Empacotando $TAG ..."

# zip com todos os arquivos versionados na RAIZ (system.json no topo), sem .git
git archive --format=zip --output=system.zip HEAD

# cria (ou substitui) o release e sobe os dois assets com nomes fixos,
# que é o que as URLs releases/latest/download/system.{json,zip} esperam
if gh release view "$TAG" >/dev/null 2>&1; then
  echo ">> Release $TAG já existe — atualizando assets."
  gh release upload "$TAG" system.zip system.json --clobber
else
  gh release create "$TAG" system.zip system.json \
    -t "$TAG — Foundry v14" \
    -n "Build $VER com compatibilidade Foundry v14. Manifest: https://github.com/victorharry/tormenta20-foundry/releases/latest/download/system.json"
fi

echo ">> Pronto. Manifest URL:"
echo "   https://github.com/victorharry/tormenta20-foundry/releases/latest/download/system.json"
