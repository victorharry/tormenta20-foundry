# Migração Foundry VTT v13 → v14 — Tormenta20

Mapa das quebras encontradas ao subir o sistema Tormenta20 (build 1.5.015 da Vizael)
para o **Foundry VTT v14.365**, com causa raiz, referência ao código do core e a
correção aplicada em cada release deste fork.

> **Como diagnosticar quebras novas:** leia o código do core direto no container.
> É o que resolveu todos os casos abaixo — nenhum foi resolvido por tentativa e erro.
> ```
> docker exec <container-foundry> sh -c "grep -rn 'termo' /home/node/resources/app/client/"
> docker exec <container-foundry> sh -c "grep -rn 'termo' /home/node/resources/app/common/data/fields.mjs"
> ```

---

## Resumo

| # | Sintoma | Causa raiz | Release |
|---|---|---|---|
| 1 | Sistema não carrega: *"Unsupported Core Version"* | `compatibility.maximum` é teto rígido | 1.5.015 |
| 2 | Mundo não abre: *`actions["crawl"] must have a label`* | v14 exige `label`+`icon` em toda ação de movimento; `-=crawl` não deleta | 1.5.016 |
| 3 | **Perícias viram todas "FOR" a cada edição** | `DataField.clean` ganhou 3º parâmetro `_state`, não repassado | 1.5.019 |
| 4 | *"forced deletion key using legacy syntax"* | `-=chave: null` agora lança **erro**, não aviso | 1.5.020 |
| 5 | *`ModelValidationError is not a constructor`* | Classe removida do v14 | 1.5.021 |
| 6 | Exclusão falha na validação | Operadores chegando em campos customizados como se fossem dados | 1.5.021 |
| 7 | Remoção "funciona" mas não remove, **sem erro** | `ForcedDeletion` só entra no diff se a chave existir no *source* | — (comportamento) |

---

## 1. `compatibility.maximum` bloqueia o carregamento

**Sintoma:** badge vermelho *Unsupported Core Version*; o sistema nem aparece.

**Causa:** o `system.json` do upstream declara `"maximum": "13"`. O Foundry trata como
**teto rígido** e recusa carregar em qualquer núcleo acima.

**Correção:** `compatibility.verified`/`maximum` → `"14"`. Como as correções abaixo usam
APIs exclusivas do v14, o `minimum` também subiu para `"14"` na 1.5.020.

---

## 2. Ações de movimento exigem `label` e `icon`

**Sintoma:** ao abrir o mundo —
`Uncaught Error: CONFIG.Token.movement.actions["crawl"] must have a label`

**Causa:** o core agora valida **todas** as ações de movimento:

```js
// client/game.mjs — #initializeMovementActions
for ( const [action, config] of Object.entries(CONFIG.Token.movement.actions) ) {
  if ( !config.label ) throw new Error(`... "${action}" must have a label`);
  if ( !config.icon )  throw new Error(`... "${action}" must have an icon`);
```

O sistema tentava **remover** a ação `crawl` com `{"-=crawl": null}` via `mergeObject`.
No v14 isso não remove a chave — deixa `crawl` sem `label`, e o setup do mundo quebra.

**Correção** (`module/canvas/token-ruler.mjs`): em vez de deletar, definir `crawl` com
`label`/`icon` válidos e `canSelect: () => false` (indisponível, mas válida).

---

## 3. `DataField.clean` ganhou um terceiro parâmetro — **corrupção de dados**

> O mais grave da lista. Corrompia dados silenciosamente a **cada** edição de ficha.

**Sintoma:** ao alterar qualquer campo (até só o nome), **todas as perícias** voltavam
para o atributo `for` e perdiam as marcações "somente treinado" (`st`) e "penalidade de
armadura" (`pda`).

**Causa:** a assinatura mudou para `clean(value, options, _state)`. O `_state` carrega
o `_source` atual daquele ramo, e o core usa isso para decidir o que preservar num
update parcial:

```js
// common/data/fields.mjs — SchemaField._cleanType
const cleanField = (name in data) || !options.partial || !_state.source;
```

O `MappingField` do sistema chamava `this.model.clean(v, options)` — **sem o terceiro
argumento**. Com `_state.source` indefinido, `cleanField` virava `true` para todo campo,
e o core reaplicava os `initial` de cada perícia (`atributo: "for"`, `st/pda: false`).

**Correção** (`module/dataModel/helpers.mjs`): propagar o estado por chave, como o
`SchemaField` do core faz:

```js
_cleanType(value, options, _state) {
  Object.entries(value).forEach(([k, v]) => {
    if (k.startsWith("-=")) return;
    if (v instanceof foundry.data.operators.DataFieldOperator) return;
    const _innerState = { ..._state, source: _state?.source?.[k] };
    value[k] = this.model.clean(v, options, _innerState);
  });
  return value;
}
```

> **Regra geral:** todo `DataField` customizado que sobrescreve `clean`/`_cleanType`
> precisa repassar `_state`.

**Reparo dos dados já corrompidos:** `foundry/_ferramentas/macro-reparar-pericias.js`
(no repo da campanha) restaura `atributo`/`st`/`pda`/`size` a partir de
`CONFIG.T20.pericias`, preservando treinamento e bônus manuais.

---

## 4. Sintaxe legada de remoção (`-=chave`) agora lança erro

**Sintoma:**
`Error: You are specifying a forced deletion key "-=ofic" using legacy syntax which
should be migrated to instead pass {ofic: _del} or {ofic: new ForcedDeletion()}`

**Causa:** `{"caminho.-=chave": null}` deixou de ser apenas depreciado — o
`_migrateDeletionKey` (em `common/utils/helpers.mjs`) agora **lança**.

**Correção:** trocar por `new foundry.data.operators.ForcedDeletion()`.

```js
// antes
await actor.update({ [`system.pericias.-=${id}`]: null });
// depois
await actor.update({ [`system.pericias.${id}`]: new foundry.data.operators.ForcedDeletion() });
```

Quebrava: excluir perícia customizada pela ficha, limpar a flag `favorito` de item,
a migração de `ofi0`/`_pc0` e o handler genérico de exclusão.

> Os usos restantes de `-=` em `module/apps/actor-sync.mjs` são `mergeObject` com
> `performDeletions` — caminho diferente, deixados como estão. Se a sincronização de
> atores falhar algum dia, é o primeiro lugar a olhar.

---

## 5. `foundry.data.fields.ModelValidationError` foi removido

**Sintoma:** `ModelValidationError is not a constructor` — um erro que **mascarava o
erro real de validação**, e por isso custou várias rodadas de diagnóstico.

**Causa:** a classe saiu do v14. O equivalente vive em
`foundry.data.validation` (`DataModelValidationFailure` / `DataModelValidationError`).

**Correção** (`module/dataModel/helpers.mjs`):

```js
const chaves = Object.keys(errors);
const failure = new foundry.data.validation.DataModelValidationFailure(
  `${chaves.length} entrada(s) inválida(s): ${chaves.map(k => JSON.stringify(k)).join(", ")}`
);
failure.fields = errors;
throw failure.asError();
```

> A mensagem **nomeando as chaves** foi adicionada na 1.5.022: sem ela o erro chegava
> como `pericias:` e não dizia qual entrada estava inválida.

---

## 6. Operadores chegam nos campos customizados

**Sintoma:** exclusão de perícia customizada falhava na validação.

**Causa:** `ForcedDeletion`/`ForcedReplacement` são passados como *valores* do campo.
O `MappingField` os tratava como dados de perícia — tentava limpá-los e validá-los
contra o `SkillData`.

**Correção:** ignorá-los em `_cleanType` e `_validateValues`; a camada de update os
resolve.

```js
if (v instanceof foundry.data.operators.DataFieldOperator) continue;
```

---

## 7. `ForcedDeletion` pode ser descartada em silêncio

**Não é bug — é comportamento do core que engana no diagnóstico.**

```js
// common/utils/helpers.mjs — _diffObject
if ( value instanceof DataFieldOperator ) {
  if ( (value instanceof ForcedReplacement) || (key in original) ) diff[key] = value;
  continue;   // ← se a chave não existe no source, a remoção some daqui
}
```

Se a chave **não existe no `_source`**, a `ForcedDeletion` não entra no diff, o diff
fica vazio e o update é descartado **sem erro nenhum**. O código parece funcionar e
nada acontece.

**Implicações práticas:**

- `ForcedReplacement` **sempre** entra no diff — use-a quando precisar garantir a escrita.
- Ao verificar se algo foi removido, compare contra `actor.toObject()` (**source**),
  não contra `actor.system` (**derivado**). Dado derivado pode ser recriado por efeitos
  a cada preparo, dando falso negativo.

---

## Armadilha que não é do v14: curinga em Active Effect

Um poder **Torcida** caseiro tinha um efeito com a chave:

```
system.pericias.*.bonus = 2      ← ERRADO
```

A intenção era "+2 em todas as perícias", mas o Foundry trata `*` como **nome literal**
e **cria** uma perícia chamada `*`. Pior: a ficha renderiza essa perícia fantasma e seus
campos ocultos (`name="system.pericias.*.treinado"`) a **gravam no banco** no próximo
submit — um ciclo que se retroalimenta. Em uma das fichas o dado inválido resultante
travou a validação inteira, impedindo **qualquer** update naquele ator.

**O jeito certo** (é o que o compêndio oficial usa em `poderes/geral/destino/torcida.yml`):

```yaml
- key: system.modificadores.pericias.geral   # +2 em TODAS as perícias
  mode: 2
  value: '2'
- key: system.attributes.defesa.bonus        # +2 na Defesa
  mode: 2
  value: '2'
```

> **Não existe curinga em chave de Active Effect.** Para efeitos amplos, use os campos
> agregadores de `system.modificadores.*`.

---

## Notas de diagnóstico (o que custou tempo)

- **`actor.items` e `actor.effects` são Collections, não Arrays.** `.flatMap` não existe.
  Normalize com `Array.from(...)` antes de usar métodos de array.
- **Source vs. derivado.** `actor.toObject().system` é o que está gravado;
  `actor.system` é o resultado depois de efeitos e `prepareData`. Confundir os dois leva
  a conclusões erradas sobre "a remoção não funcionou".
- **Isole cada `await` em `try/catch`** em macros de manutenção em lote. Sem isso, uma
  ficha com dado inválido derruba o script inteiro e as demais nem são processadas —
  foi o que fez parecer que a correção "funcionava pela metade".
- **Erro vazio é pista.** `pericias:` sem detalhe significava relato de erro quebrado
  (item 5), não ausência de causa.

---

## Histórico de releases deste fork

| Versão | O que entrou |
|---|---|
| 1.5.015 | Republicação do build 1.5.015 com compatibilidade v14 |
| 1.5.016 | Correção da ação de movimento `crawl` |
| 1.5.017 | Tema escuro das fichas de ator |
| 1.5.018 | Tema v2 — fundos claros remanescentes e banners de seção |
| 1.5.019 | **Perícias resetando para FOR** + marcadores `*`/`+` como badges + tema v3 |
| 1.5.020 | Sintaxe de remoção migrada para `ForcedDeletion`; `minimum` → 14 |
| 1.5.021 | Operadores ignorados no `MappingField`; erro de validação migrado |
| 1.5.022 | Erro de validação passa a nomear as chaves inválidas |
