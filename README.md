# Tormenta20

> **Fork de compatibilidade com Foundry VTT v14.** Este repositório é o **código-fonte**
> do sistema de [Victor Hugo Paiva / Vizael](https://gitlab.com/vizael/Tormenta20) (BSD-3),
> com a faixa de compatibilidade ajustada para o **v14**. O build é gerado pela
> **GitHub Action** (`.github/workflows/release.yml`) ao empurrar uma tag `vX.Y.Z` — igual
> ao fluxo da CI do GitLab. Nenhuma regra do sistema foi alterada.
>
> **Instalar no Foundry** (Install System → Manifest URL):
> ```
> https://github.com/victorharry/tormenta20-foundry/releases/latest/download/system.json
> ```
>
> **Lançar uma nova versão:** edite a fonte, dê `git push`, então crie e empurre a tag:
> `git tag v1.5.016 && git push origin v1.5.016`. A Action compila e publica o release.

## Descrição
Este é um sistema NÃO OFICIAL feito e mantido por fãs, sem qualquer afiliação a Tormenta20 ou a Jambo Editora.
Tormenta 20 é um RPG brasileiro e pertence a Jambo Editora.


## Colaboradores
* André Oliveira
* Gustavo Reis
* TheTruePortal
* Mateus Marochi
* Matheus Clemente
* Roberto Caetano
* Victor Kullack
* Alexandre Galdino
* Vinicius Lima Silva
* Gabriel Vieira

## Atribuições
- [FoundryVTT](https://github.com/FoundryVTT/) pelo módulo [dnd5e](https://github.com/FoundryVTT/dnd5e), cujo código foi adaptado neste sistema.
- Este sistema usa artes de tokens do [2 Minute TableTop](https://2minutetabletop.com/).
- Os arquivos na pasta `templates/sidebar/compendium-directory`, e os arquivos `less/compendium-directory.less` e `module/sidebar/compendium-directory.mjs` foram retirados do sistema pf2e e estão licenciados sob a Apache License v2.
- Os arquivos `less/active-effect-wizard.less`, `module/apps/active-effect-wizard.mjs`, `module/style/Accordion.mjs`, `templates/apps/active-effect-wizard.hbs` foram retirados do sistema SWADE e estão licenciados sob a MIT License.

## Lista de Mudanças

Leia o [CHANGELOG.md](./CHANGELOG.md)

## Contribuindo

Leia o [CONTRIBUTING.md](./CONTRIBUTING.md)