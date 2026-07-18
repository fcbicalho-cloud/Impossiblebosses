# Impossible Bosses (top-down) — contexto para o Claude Code

Jogo de **raid cooperativo top-down** (Godot 4.x / GDScript) inspirado no mapa
*Impossible Bosses* de WC3: só lutas de boss, combate **tab-target** (estilo WoW),
trindade tank/healer/dps, bots preenchendo os papéis que o humano não controla.
Visão completa e decisões de design: **`docs/ESCOPO.md`** (documento vivo).

## Fluxo de trabalho

- **Branch de desenvolvimento: `claude/topdown-boss-game-scope-rrouam`.** Commits em
  português, factuais. Não criar branches novas sem pedido explícito.
- Este repo é editado por sessões **locais** (na máquina do usuário, com Godot) e
  **remotas** (sem Godot). **Sempre `git pull` antes de começar e `git push` ao
  terminar** para não conflitar.
- Existe uma skill de projeto em `.claude/skills/godot-game-builder/` com o workflow
  em fases (implementar → revisar → commit real → checkpoint com o usuário) e as
  regras anti-fabricação: **nunca** inventar hash de commit, resultado de teste ou
  qualquer evidência. O que não foi executado de verdade é declarado "não
  verificado". Numa sessão local COM Godot disponível, rode de verdade
  (`godot --headless --import`, F5) antes de afirmar que funciona.
- Preferência do usuário: **seja crítico** — aponte riscos e trade-offs em vez de
  concordar por padrão; nada de "ótima ideia".

## Arquitetura (scripts/)

Herança: `Actor` → `PartyMember` → papéis.

- `actor.gd` — base de TUDO que tem vida (jogadores, boss, adds): hp/alive/
  `take_damage`/`heal`/`_die` + juice comum (flash de dano via `_flash_mix`,
  números de dano via grupo `"fx"`, `anim_time` para idle). Pontos de extensão:
  `_apply_damage` (PartyMember desconta escudo) e `_die`.
- `party_member.gd` — aliados: escudo, `revive`, clamp na arena, `_read_wasd()`,
  `_aoe_flee_vector()` (dodge dos bots), `_is_boss_target()`. Grupo `"party"`.
- `mago.gd` (DPS: auto-attack + conjuração parado + Tab/clique), `guardiao.gd`
  (tank: Ira, Provocar/taunt, Muralha, threat 3×), `clerigo.gd` (healer: Mana,
  Cura/Rápida/Escudo/Rez; auto-mira o aliado mais ferido).
- **`is_bot`** em cada papel é a costura de fonte de input (humano OU IA na mesma
  classe) — é onde o multiplayer entra no futuro. Não duplicar classes por causa
  disso.
- `boss.gd` — tabela de threat (`add_threat`/`taunt`/`current_target`), corpo-a-corpo
  no topo do threat, AoE telegrafado em membro aleatório, `get_active_aoes()` (bots
  desviam), `rez_charges`. Grupo `"targetable"` (inimigos alvo de Tab/clique).
- `main.gd` — orquestrador: escolha de papel (1/2/3), spawn, HUD, roteamento de
  teclas, wipe/vitória, container `_world` (grupo `"fx"`) para entidades/efeitos
  transitórios. HUD lê `get_ability_info(index)`/`get_cast_status()` dos papéis —
  mantenha esse contrato em vez de acessar campos privados.
- `damage_number.gd`, `aoe_burst.gd` — efeitos; vivem sob `_world`.

## Armadilhas de GDScript que já quebraram este projeto (checar SEMPRE)

1. Variável tipada como `Node`/`Node2D` acessando membro que só existe numa
   subclasse → use o tipo preciso (`PartyMember`, `Add`) ou deixe sem tipo quando o
   tipo realmente varia (ex.: `target` do Mago, `human_unit` do main).
2. `:=` inferindo de `Variant` (iterar `Array`/`Dictionary` sem tipo) → declare
   explícito: `var x: float = ...`, `for t: float in [0.33, 0.66]`.
3. **Indentação: SÓ tabs.** Nunca misturar espaços.
4. Função tipada precisa retornar em todos os caminhos → prefira `if/elif/return` a
   `match ... return`.

## Fase gráfica (estado atual e próximos passos)

Arte é **pixel art 16×16 do Kenney Tiny Dungeon (CC0)**. Pack original intacto em
`assets/packs/kenney_tiny_dungeon/`; o que o jogo usa é copiado com nome por
função para `assets/characters/` e `assets/tiles/`. Regras em
`assets/README.md`, créditos em `assets/CREDITS.md`. Filtro **Nearest** ligado.

Feito:
1. ✅ Assets no repo, import verificado (`--headless --import`).
2. ✅ Os 4 personagens usam `Sprite2D` via `Actor._setup_body_sprite(tex, escala)`
   — jogadores em 3×, boss em 4×. Barras, retículas, telégrafos e auras seguem
   em `_draw`, por cima ou por baixo do sprite.
3. ✅ Chão/paredes com `TileMapLayer` construído em código no `main.gd`
   (`_build_arena_tiles`), em `z_index -1`.

Detalhes que importam:
- **Não há frames de animação**: o Tiny Dungeon tem 1 frame por personagem. O
  movimento é sugerido por bob de idle, flip horizontal e pose de morte. Animação
  de caminhada de verdade exige outro pack (ex.: Zelda-like do ArMM1998, 4 direções)
  — aí sim troca-se `Sprite2D` por `AnimatedSprite2D`.
- **Flash de dano usa shader** (`Actor.FLASH_SHADER_CODE`), não `modulate`:
  modulate multiplica, então só escurece; clarear até branco precisa de shader.
- O `ARENA_RECT` **não** é múltiplo do tile (48px) de propósito: ele é a fronteira
  de jogo e continua intocado; o tilemap se encaixa por fora dela.
- Texto do HUD leva contorno preto (`_add_text_outline`) — o piso claro do tileset
  torna letra branca pura ilegível.

Próximo passo (não feito): resolução base retrô + stretch `canvas_items` —
**cuidado**: as coordenadas do jogo são hardcoded para 960×640 (`ARENA_RECT`,
spawns no `main.gd`); mudar resolução exige reposicionar tudo junto.

## Verificação real (há Godot na máquina do usuário)

`C:\Users\filip\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`
(o .exe está dentro de uma pasta de mesmo nome). Use o binário `_console` para ver
a saída no terminal. Comandos:

```bash
godot --headless --path . --import                    # importa assets
godot --headless --path . -s tests/smoke_sprites.gd   # 4 personagens + mira do clerigo
godot --headless --path . -s tests/smoke_arena.gd     # tilemap + spawn do encontro
godot --path . -s tests/capture_screenshot.gd -- x.png  # screenshot (abre janela)
```

Os smokes imprimem `SMOKE OK`/`SMOKE FALHOU` e usam exit code. A captura de tela é
a forma de conferir o visual sem depender do usuário — ela já pegou bugs reais
(manchas no piso, HUD ilegível) que os testes headless não pegariam.
