# Escopo — Impossible Bosses (top-down)

> **Documento vivo.** Este arquivo é o ponto de partida para detalharmos as
> intenções do jogo. Nada aqui é definitivo: as seções marcadas com ❓ são decisões
> em aberto, e o resto deve ser revisitado conforme o protótipo revelar o que
> funciona na prática. O tom é deliberadamente crítico — a ideia é expor riscos e
> trade-offs, não vender o projeto para nós mesmos.

**Status:** M0 (definição de escopo). Nenhum código ainda.
**Última atualização:** 2026-07-12.

---

## 1. Visão geral / pitch

Um jogo de ação cooperativo, visto de cima (top-down 2D), em que um pequeno time
enfrenta uma sequência de **chefes** com padrões de ataque telegrafados. Não há farm,
level nem exploração: o jogo inteiro é a **luta contra o chefe**. Vitória depende de
ler os telégrafos, desviar, posicionar-se e usar bem os cooldowns. A referência de
sensação é o **Zelda top-down clássico**; a referência de *conteúdo* é o mapa
**Impossible Bosses** de Warcraft 3. O jogo é leve, rápido e mede o **desempenho
individual** de cada jogador dentro do esforço do time.

## 2. Referências

**Do Impossible Bosses (WC3) herdamos:**
- Encontros contra chefes como o *único* conteúdo — sem farm, sem level, sem loot.
- Ataques telegrafados que exigem desvio ativo; alta punição por erro.
- Fases de chefe que mudam o padrão de ataque ao longo da luta.
- "Adds" (inimigos menores) e mecânicas que forçam decisão sob pressão.

**Do Zelda top-down clássico herdamos:**
- Câmera de cima, movimento em plano 2D, leitura espacial clara.
- Sprites simples e leveza técnica — roda em qualquer máquina.
- Combate de resposta imediata (game feel > fidelidade visual).

**O que deliberadamente deixamos de fora:**
- Mundo aberto, dungeons, puzzles de exploração, história longa.
- Progressão por itens/equipamento e economia.
- Qualquer coisa que dilua o foco em "executar a luta bem".

## 3. Pilares de design

Servem de filtro: se uma feature nova não reforça um destes pilares, ela provavelmente
está fora de escopo.

1. **Mecânica acima de tudo.** O prazer vem de desviar e posicionar, não de números
   subindo. Se um sistema não melhora a qualidade do desvio/posicionamento, questione.
2. **Encontros curtos e intensos.** Uma luta dura minutos, não horas. Morrer e tentar
   de novo é barato e rápido.
3. **Leveza técnica e visual.** Clareza > beleza. O visual existe para tornar os
   telégrafos legíveis, não para impressionar.
4. **Skill individual visível.** Cada jogador deve conseguir enxergar o próprio
   desempenho e melhorá-lo. O co-op soma indivíduos competentes; não esconde os fracos.

## 4. Loop de gameplay

**Micro (segundo a segundo):** mover → ler telégrafo → desviar/posicionar → atacar →
gerenciar cooldowns → reagir à mudança de fase do chefe.

**Macro (por sessão):** escolher classe → (opcional) preencher vagas com bots →
enfrentar o chefe → vitória **ou** wipe → repetir/próximo chefe.

Crítica: o loop macro é curtíssimo. Isso é intencional, mas cria o risco de o jogo
"acabar rápido" e ficar repetitivo. A profundidade precisa vir da **variedade de
mecânicas por chefe** e do **teto de habilidade individual**, não de tempo de
sessão. Vale monitorar isso desde o primeiro protótipo.

## 5. Modo de jogo & multiplayer

**Alvo:** co-op **online**. É a tese do jogo — desempenho individual só faz sentido
comparado ao dos outros no mesmo combate.

**Número de jogadores:** ❓ em aberto. Sugestão inicial: **2–4**. Quanto maior o time,
mais difícil balancear a "visibilidade individual" e mais pesado o netcode. Começar
pequeno.

### Netcode (seção crítica)

O maior risco técnico do projeto. Pontos:

- **É PvE.** Não há competição direta entre jogadores, então **não precisamos de um
  servidor autoritativo à prova de trapaça** — que é a parte mais cara do netcode.
  Trapaça em co-op prejudica no máximo o próprio grupo. Isso *reduz drasticamente* o
  custo.
- **Modelo recomendado:** *host/listen-server* — um jogador (ou um processo dedicado
  leve) hospeda a simulação do chefe; clientes enviam input e recebem estado. Godot
  4 tem `MultiplayerAPI` / `MultiplayerSynchronizer` que cobrem esse caso.
- **Latência importa muito** num jogo baseado em dodge preciso. Sem mitigação, um
  jogador com 100  ms "morre" para ataques que já desviou na tela. Mitigações:
  predição de movimento do próprio jogador no cliente + telégrafos com janelas de
  desvio generosas o suficiente para absorver latência.
- **Não subestimar mesmo assim.** "Simples porque é PvE" não é "trivial". Este é o
  item que mais pode estourar o cronograma. Por isso o desenvolvimento começa
  **offline com bots** (seção 6), e o online entra num marco próprio (M2).

## 6. Bots (filosofia bot-first)

Decisão central: **o jogo deve ser testável solo desde o início**, com bots
controlando as classes que o desenvolvedor não estiver jogando.

**Requisito arquitetural (define o código desde a primeira linha):**
Tratar a **fonte de input como abstrata**. Um mesmo "controlador de classe" recebe
comandos de:
- **input local** (teclado/mouse/gamepad),
- **peer de rede** (outro jogador, no futuro online),
- **IA** (bot).

Com isso, **bots e multiplayer viram o mesmo problema**, resolvido uma vez. Um bot é
só mais uma fonte de comandos preenchendo o mesmo `ClassController` que um humano
usaria. Isso também garante **paridade jogador/bot**: bots não têm acesso a nada que
um jogador não teria.

**Sofisticação incremental** — não tentar bots inteligentes de cara:
1. Bot burro: fica no alcance, ataca, desvio reativo básico.
2. Bot que reconhece telégrafos e sai da área.
3. Bot que cumpre o *papel* da classe (ex.: cura quando aliado está baixo).

Crítica: um bot que sobrevive de verdade às mecânicas dá **trabalho real** — é quase
um mini-projeto de IA. O lado bom é que isso **força a formalizar** o que cada classe
e cada mecânica de chefe fazem (se o bot não consegue jogar, a regra provavelmente
está ambígua). Encarar os bots como ferramenta de teste contínuo, não como recurso
polido de lançamento.

## 7. Classes / papéis ❓

Decisão em aberto e importante. Dois caminhos:

- **Trindade (tank / healer / dps).** Mais fiel a MMO/WC3, cria interdependência
  forte. Custo: exige sistema de **ameaça/aggro** (para o tank "segurar" o chefe) e
  de **cura**, além de balancear papéis. Mais sistemas, mais superfície de bug, e
  tende a **esconder** o desempenho individual atrás do papel (um healer ruim é menos
  óbvio que um DPS ruim).
- **Todos DPS com utilidade.** Cada classe causa dano mas tem ferramentas próprias
  (dash, escudo curto, cura leve, controle de área). Mais leve, mais alinhado ao pilar
  "skill individual visível", mais fácil de balancear no começo. Custo: menos daquela
  dinâmica clássica de raid.

**Recomendação inicial:** começar **sem trindade** — todas as classes com identidade
via *utilidade e estilo de dano*, não via papel rígido. Isso mantém o foco em dodge
individual e reduz sistemas no protótipo. Reavaliar depois que a mecânica base estiver
boa. (Contra-argumento honesto: parte da graça do Impossible Bosses vem justamente da
coordenação de papéis; se testes mostrarem que o co-op fica "raso", reconsiderar.)

## 8. Chefes

**Anatomia de um encontro:**
- **Fases:** o chefe muda de padrão em limiares de vida (ex.: 100%→66%→33%).
- **Telégrafos:** indicação visual clara e antecipada de onde/quando o ataque acerta
  (área no chão, linha, cone, projétil com trajetória).
- **Adds:** inimigos menores que aparecem e forçam repriorização.
- **Enrage / timer:** pressão de tempo para o combate não se arrastar; recompensa DPS.

**Vertical slice:** projetar e polir **UM chefe completo** antes de qualquer outro.
Um chefe excelente ensina mais sobre o jogo do que dez rascunhos. **Não** desenhar um
bestiário agora — é o convite clássico ao scope creep.

## 9. Progressão & falha ❓

- **Sem farm/level** (fiel ao original). O que evolui é a **habilidade do jogador**,
  não os atributos do personagem.
- **Ao morrer:** ❓ definir entre (a) espectar até o wipe/vitória do time; (b) sistema
  de **revive** por aliados (cria interdependência — bom para co-op, mas atenua a
  punição individual). Trade-off a decidir com testes.
- **Wipe:** time inteiro morto → recomeça o encontro rápido (barato, por pilar 2).
- **Vitória:** chefe morto antes do enrage/timer.

## 10. Estilo visual & áudio

- **Arte placeholder** durante todo o desenvolvimento; substituir só quando a mecânica
  estiver validada.
- **Prioridade absoluta: legibilidade dos telégrafos.** Cor/forma/contraste do
  telégrafo importam mais que qualquer sprite. Um jogo assim vive ou morre pela
  clareza do "onde vai bater".
- Paleta simples; evitar poluição visual que esconda telégrafos.
- Áudio: cues sonoros para telégrafos e mudanças de fase ajudam muito o dodge —
  considerar cedo, mesmo que com sons placeholder.

## 11. Escopo técnico

- **Engine:** Godot 4.x, projeto 2D top-down.
- **Plataforma:** desktop (Windows/Linux) como alvo primário; avaliar export para web
  depois — bom para compartilhar, mas o netcode em WebRTC/WebSocket adiciona atrito.
- **Estrutura de projeto (futura, M1):** cenas separadas para arena, chefe, personagem
  e HUD; `ClassController` com fonte de input abstrata (ver seção 6); dados de
  chefe/classe em recursos (`.tres`) para facilitar iteração sem mexer em código.
- Sem dependências pesadas. Manter o projeto enxuto.

## 12. Métricas de desempenho individual

Para que "skill individual" (pilar 4) seja real, o jogo precisa **medir e mostrar**:
- Dano causado.
- Mortes / vezes que foi atingido por ataques evitáveis.
- **% de dodges bem-sucedidos** (talvez a métrica mais alinhada à tese).
- Uptime de habilidades / desperdício de cooldown.

Exibir isso num resumo pós-luta resolve a **tensão "individual vs. time"**: o time
vence junto, mas cada um vê sua própria performance. Cuidado crítico: métricas mal
escolhidas distorcem o comportamento (ex.: medir só dano incentiva ignorar mecânicas).
Medir aquilo que queremos que os jogadores valorizem — sobretudo sobrevivência e
desvio.

## 13. Roadmap / marcos

- **M0 — Escopo (agora):** este documento.
- **M1 — Vertical slice (solo):** 1 classe jogável + 1 chefe completo + arena +
  bots básicos, tudo offline. Objetivo: provar que o *game feel* de desviar é bom.
  **Se M1 não for divertido solo, nada depois salva o projeto.**
- **M2 — Co-op online:** host/listen-server, 2 jogadores reais, predição básica.
  O marco de maior risco.
- **M3 — Conteúdo:** mais classes e chefes, balanceamento, métricas polidas.

Ênfase crítica: **cortar escopo agressivamente** em cada marco. A tentação será
adicionar classes e chefes antes de M1 estar bom. Resistir.

## 14. Não-objetivos (out of scope)

O jogo explicitamente **NÃO** é / **NÃO** terá:
- MMO ou mundo persistente.
- Mundo aberto ou exploração.
- Loot, itens, equipamento ou economia.
- Progressão de atributos por level/farm.
- **PvP** (o design de netcode inteiro assume PvE).
- História/campanha elaborada.

Manter esta lista visível é a principal defesa contra scope creep.

## 15. Questões em aberto

- ❓ Número de jogadores por time (sugestão: 2–4).
- ❓ Modelo de classes: trindade vs. todos-DPS-com-utilidade (recomendação atual:
  sem trindade).
- ❓ Esquema de mira/ataque: mira por mouse (twin-stick) vs. 8 direções estilo Zelda.
- ❓ Morte: espectar até o wipe vs. sistema de revive.
- ❓ Quantidade e progressão dos chefes (só após M1).
- ❓ Export para web: vale o atrito de netcode adicional?
