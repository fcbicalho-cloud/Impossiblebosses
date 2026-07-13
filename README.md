# Impossible Bosses (top-down) — protótipo

Jogo de raid cooperativo visto de cima, inspirado no mapa *Impossible Bosses* de
Warcraft 3. Veja a visão completa em [`docs/ESCOPO.md`](docs/ESCOPO.md).

## Estado atual: protótipo M1 (fatia-núcleo do combate)

Este é o **primeiro protótipo**, deliberadamente mínimo. Ele exercita só o núcleo
do combate na ótica do DPS ("Mago"), **sem** trindade, threat, cura ou bots ainda
(isso é trabalho dos próximos marcos — ver escopo, seções 8 e 14).

O que já dá para sentir:
- Movimento top-down (WASD).
- Modelo de dano com **tensão de posicionamento**:
  - **Auto-attack** fraco, dispara sozinho no alvo em alcance (funciona andando).
  - **Conjuração** = o dano principal, mas **só progride PARADO** — mover interrompe
    e zera o progresso. É o "parar pra causar dano te expõe às mecânicas".
- **Tab-target**: selecione o alvo com **Tab** (cicla) ou **clicando** no inimigo.
- Um **boss com fases** e três mecânicas:
  - **AoE no chão** (círculo vermelho telegrafado) — saia da área antes de detonar.
  - **Projéteis** (a partir da fase 2) disparados na sua direção — desvie andando.
  - **Adds** (inimigos menores) que perseguem você e dão dano de contato — troque de
    alvo e limpe-os, ou tome dano tentando conjurar parado.
  - **Fase 1** (100–66%): AoE + adds · **Fase 2** (66–33%): + projéteis ·
    **Fase 3** (33–0%): dois AoEs ao mesmo tempo + projéteis mais rápidos.
  - Aviso de **"FASE X!"** e o boss muda de cor a cada virada.
- Vitória (matar o boss), derrota (morrer) e reinício rápido.

## Como rodar

1. Instale o **Godot 4.3+** (gratuito): <https://godotengine.org/download>
2. No Godot, **Import** → aponte para a pasta deste repositório (onde está o
   `project.godot`).
3. Rode com **F5** (ou o botão ▶ de play).

Não há dependências externas nem passos de build.

## Controles

| Ação                         | Comando              |
|------------------------------|----------------------|
| Mover                        | `W A S D`            |
| Conjurar (dano principal)    | ficar **parado**     |
| Selecionar alvo              | `Tab` ou clique      |
| Reiniciar                    | `R`                  |

## Estrutura

```
project.godot      # configuração do projeto (Godot 4.x)
Main.tscn          # cena principal
scripts/
  main.gd          # arena, HUD, entidades e estado de jogo; Tab/clique de alvo
  player.gd        # Mago: movimento + auto-attack + conjuração parado + troca de alvo
  boss.gd          # boss: fases + AoE + projéteis + spawn de adds
  projectile.gd    # projétil do boss (fase 2+)
  add.gd           # inimigo menor que persegue o jogador
```

Tudo desenhado com formas simples (`_draw`) — arte placeholder por design
(pilar de leveza visual do escopo).

## Próximos passos sugeridos

- Ajustar o *game feel* (velocidade, alcance, dano, tempo de telégrafo).
- Adicionar uma segunda mecânica ao boss e fases por limiar de vida.
- Introduzir a trindade (tank/healer) e os sistemas da seção 8 do escopo.
- Bots para os papéis que o jogador não estiver controlando.
