# Impossible Bosses (top-down) — protótipo

Jogo de raid cooperativo visto de cima, inspirado no mapa *Impossible Bosses* de
Warcraft 3. Veja a visão completa em [`docs/ESCOPO.md`](docs/ESCOPO.md).

## Estado atual: protótipo M1 — trindade completa (tank/healer/dps) + bots

A **trindade inteira** já está jogável contra um boss com fases. Você escolhe qual
dos 3 papéis controla; os outros dois viram **bots**, então dá pra testar sozinho
(ver escopo, seção 8 — sistemas de threat, cura e combat-rez).

### Escolha de papel
Ao abrir, o jogo pede pra você escolher quem controla:
- **1** = Guardiao (Tank)
- **2** = Clerigo (Healer)
- **3** = Mago (DPS)

**R** volta pra essa tela a qualquer momento — dá pra trocar de papel sem reiniciar
o jogo inteiro.

### Os 3 papéis

**Guardiao (Tank)** — fica no alcance corpo-a-corpo do boss e ataca automaticamente,
gerando MUITO threat (aggro). Recurso: **Ira**.
- `1` **Provocar** — força o boss a mirar nele (taunt).
- `2` **Muralha** — reduz o dano recebido por alguns segundos (gasta Ira).

**Clerigo (Healer)** — cura automaticamente mira o aliado com menos vida. Recurso:
**Mana**.
- `1` **Cura** — cast parado (dano de cura principal; mover cancela).
- `2` **Cura Rapida** — instantânea, mais fraca.
- `3` **Escudo** — absorção que bloqueia dano antes de tirar vida.
- `4` **Ressurreição** — channel parado; revive um aliado morto (1 carga por boss).

**Mago (DPS)** — o mesmo modelo já validado no protótipo anterior:
- **Auto-attack** fraco funciona andando; a **Conjuração** (dano principal) só
  progride **parado** — mover interrompe.
- Alvo por **Tab** (cicla) ou **clicando** no inimigo (boss ou add).

### O boss
Tem **fases por % de vida** e mecânicas que forçam o uso da trindade:
- **Corpo-a-corpo** periódico no alvo com mais threat — exige um tank segurando aggro.
- **AoE telegrafado** no chão, mirado num membro aleatório do grupo (qualquer um pode
  ser alvo, inclusive o tank) — saia da área antes de detonar.
- **Projéteis** (fase 2+) num membro aleatório — desvie andando.
- **Adds** que perseguem quem estiver mais perto — o Mago troca de alvo para limpá-los.
- **Fase 1** (100–66%): corpo-a-corpo + AoE + adds · **Fase 2** (66–33%): + projéteis ·
  **Fase 3** (33–0%): dois AoEs simultâneos + projéteis mais rápidos.

Vitória (matar o boss), derrota (wipe — todos mortos) e reinício rápido (R).

## Como rodar

1. Instale o **Godot 4.3+** (gratuito): <https://godotengine.org/download>
2. No Godot, **Import** → aponte para a pasta deste repositório (onde está o
   `project.godot`).
3. Rode com **F5** (ou o botão ▶ de play).

Não há dependências externas nem passos de build.

## Controles

| Ação                          | Comando                                    |
|-------------------------------|---------------------------------------------|
| Escolher papel                | `1` Guardiao · `2` Clerigo · `3` Mago       |
| Mover                         | `W A S D`                                    |
| Habilidades (Tank/Healer)     | `1` `2` `3` `4` (ver acima, por papel)      |
| Conjurar (Mago, dano principal) | ficar **parado**                           |
| Selecionar alvo (Mago)        | `Tab` ou clique                              |
| Voltar pra escolha de papel   | `R`                                          |

## Estrutura

```
project.godot        # configuração do projeto (Godot 4.x)
Main.tscn             # cena principal
scripts/
  main.gd             # tela de escolha de papel, spawn, HUD, roteamento de teclas
  party_member.gd      # base comum: vida/escudo/revive/clamp de arena/helper de dodge
  mago.gd              # DPS: auto-attack + conjuração parado + tab/clique
  guardiao.gd           # Tank: Ira, Provocar, Muralha, auto-attack de threat
  clerigo.gd            # Healer: Mana, Cura, Cura Rapida, Escudo, Ressurreição
  boss.gd               # threat/aggro, fases, corpo-a-corpo, AoE, projéteis, adds
  projectile.gd         # projétil do boss (fase 2+)
  add.gd                # inimigo menor que persegue o membro mais próximo
```

Tudo desenhado com formas simples (`_draw`) — arte placeholder por design
(pilar de leveza visual do escopo).

## Simplificações deliberadas deste protótipo

- Cura sempre mira automaticamente o aliado com menos vida (sem seleção manual de
  aliado) — reduz controle sem perder a decisão real (qual habilidade, quando).
- Bots do Healer/Tank não desviam de AoE (o Mago-bot desvia; os outros dois
  aceitam o risco). Simplificação de escopo, não decisão final de design.
- Fonte de input é local (teclado) ou bot; ainda não existe uma fonte de rede — é
  o próximo ponto de extensão natural para o multiplayer (ver escopo, seção 6).

## Próximos passos sugeridos

- Calibrar números (dano, threat, cooldowns, HP) jogando os 3 papéis.
- Dar ao Mago-bot e ao Guardiao mais habilidades (Investida etc.).
- Multiplayer online (M2 do escopo) — trocar "bot" por "peer de rede" na mesma
  arquitetura de `is_bot`.
