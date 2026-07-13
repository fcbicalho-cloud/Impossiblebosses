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
- `1` **Provocar** — força o **boss** a mirar nele (taunt) **e também taunta todos
  os adds vivos**, que passam a vir pra cima dele por alguns segundos. Enquanto tiver
  um add taunado ao alcance, o auto-attack prioriza matá-lo antes de voltar pro boss.
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
- **Adds** que travam num alvo **sorteado aleatoriamente** entre o grupo (não mais
  "sempre o mais perto") — o Guardiao usa Provocar pra puxá-los pra si, e o Mago
  troca de alvo (Tab/clique, ou automaticamente se for bot) para limpá-los.
- **Fase 1** (100–66%): corpo-a-corpo + AoE + adds · **Fase 2** (66–33%): + projéteis ·
  **Fase 3** (33–0%): dois AoEs simultâneos + projéteis mais rápidos.

Vitória (matar o boss), derrota (wipe — todos mortos) e reinício rápido (R).

### Painel de habilidades (cooldown e custo)

A 3ª linha do texto embaixo da arena mostra, ao vivo, cada habilidade do papel que
você controla: nome, custo do recurso e cooldown restante (ex.: `[2] Muralha
(custo 30): 4.2s`, ou `pronto` quando disponível). Pro Mago, que não tem tecla de
habilidade, essa linha mostra o estado da conjuração (`Conjurando: 60%`,
`Pronto pra conjurar...`, etc.).

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
  add.gd                # inimigo menor: alvo travado sorteado, taunt(), is_targeting()
```

Tudo desenhado com formas simples (`_draw`) — arte placeholder por design
(pilar de leveza visual do escopo).

## Simplificações deliberadas deste protótipo

- Cura sempre mira automaticamente o aliado com menos vida (sem seleção manual de
  aliado) — reduz controle sem perder a decisão real (qual habilidade, quando).
- **Guardiao-bot não se reposiciona** além de se aproximar do boss uma vez no início
  — ele "tanca" ficando parado colado no boss, que é o comportamento correto de
  segurar aggro, mas não é visualmente muito expressivo. O feedback de que ele está
  agindo vem do painel de habilidades (barra de Ira enchendo, Muralha ativando) e do
  anel vermelho ao redor dele quando é o alvo do boss.
- Fonte de input é local (teclado) ou bot; ainda não existe uma fonte de rede — é
  o próximo ponto de extensão natural para o multiplayer (ver escopo, seção 6).
- A linha de habilidades pode ficar comprida/apertada com o Clerigo (4 habilidades
  numa linha só) — é só texto de depuração por enquanto, não uma UI final.
- **Provocar taunta TODOS os adds vivos**, sem checar distância/raio — mais simples
  de implementar sem poder compilar/testar; se parecer forte demais (ou fraco
  demais) depois de jogar, dá pra limitar por raio.
- Mudar os adds de "sempre o mais próximo" pra "alvo aleatório" é uma mudança de
  dificuldade **intencional**: agora a luta depende de verdade do tank agir. Se um
  add sortear o Healer/Mago antes do tank conseguir taunar, pode doer — é esperado,
  mas vale calibrar (cooldown do Provocar, ou um "grace period" inicial) se sentir
  punitivo demais logo no começo do encontro.

## Próximos passos sugeridos

- Calibrar números (dano, threat, cooldowns, HP) jogando os 3 papéis.
- Dar ao Mago-bot e ao Guardiao mais habilidades (Investida etc.).
- Multiplayer online (M2 do escopo) — trocar "bot" por "peer de rede" na mesma
  arquitetura de `is_bot`.
