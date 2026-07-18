# assets/ — arte do jogo (pixel art 16×16, estilo Zelda top-down)

Coloque aqui os PNGs dos packs (CC0 ou licença permissiva). O projeto já está
configurado com **filtro Nearest** (`project.godot`), então pixel art renderiza
nítida sem configuração extra por textura.

## Estrutura esperada

```
assets/
  characters/   # spritesheets dos personagens: mago, guardiao, clerigo, boss, adds
  tiles/        # tilesets do chão/paredes da arena (16×16)
  fx/           # efeitos: explosões, projéteis, brilhos
  ui/           # ícones de habilidade, molduras de barra, cursores
```

## Convenções

- **Tamanho base: 16×16 px por tile/frame** (packs 16×16 top-down; personagens
  podem ser 16×16 ou 16×24). Misturar tamanhos de pack diferentes fica feio —
  prefira tirar tudo de um mesmo pack no início.
- **Spritesheets** (grade regular de frames) em vez de frames soltos, quando o
  pack oferecer — facilita montar `AnimatedSprite2D`/`SpriteFrames`.
- Nomes de arquivo minúsculos, sem espaço: `mago_walk.png`, `tileset_dungeon.png`.

## Licenças (obrigatório)

Só entra asset **CC0 ou licença permissiva** (CC-BY ok, registrando o crédito).
**Toda adição deve ser registrada no [`CREDITS.md`](CREDITS.md)** com pack, autor,
fonte (URL) e licença. Sem registro, o asset não entra.

## Fontes recomendadas

- [Kenney](https://kenney.nl) — CC0 (ex.: *Tiny Dungeon*).
- [OpenGameArt](https://opengameart.org) — buscar "Zelda-like tileset" (CC0 do
  ArMM1998 é um bom começo).
- [itch.io](https://itch.io/game-assets/free/tag-top-down) — conferir a licença
  de cada pack antes de usar.
