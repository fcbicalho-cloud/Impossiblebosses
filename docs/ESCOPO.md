# Escopo — Impossible Bosses (top-down)

> **Documento vivo.** Este arquivo é o ponto de partida para detalharmos as
> intenções do jogo. Nada aqui é definitivo: as seções marcadas com ❓ são decisões
> em aberto, e o resto deve ser revisitado conforme o protótipo revelar o que
> funciona na prática. O tom é deliberadamente crítico — a ideia é expor riscos e
> trade-offs, não vender o projeto para nós mesmos.

**Status:** M1 em andamento (vertical slice solo com bots). Já em código: trindade
completa (tank/healer/dps + bots), threat/aggro, cura/mana, combat-rez, AoE
telegrafado, **fases do boss (66%/33%), adds e enrage**, e **3 níveis de
dificuldade**. Arte deixou de ser placeholder (pixel art CC0 — ver `CLAUDE.md`).
Falta para fechar M1: projéteis e as métricas de desempenho da seção 13.
**Última atualização:** 2026-07-18 (Revisão 2 — status de implementação; o design
das seções abaixo continua valendo como escrito).

> **Nota de rumo (importante).** As decisões desta revisão aproximam o jogo de uma
> **raid do WoW vista de cima**, não de um action-RPG estilo Zelda. O combate é
> **tab-target com auto-attack** (seção 4), há **trindade** de papéis (seção 7) e o
> alvo é **8–10 jogadores** (seção 5). A referência do Zelda top-down passa a valer
> para **visual e movimentação**; a referência de *combate e conteúdo* é o
> Impossible Bosses / raid de MMO. "Rápido e leve" vira uma meta a **defender
> ativamente** contra o peso natural desse gênero.

---

## 1. Visão geral / pitch

Um jogo de raid cooperativo visto de cima (top-down 2D), em que um time enfrenta uma
sequência de **chefes** com mecânicas telegrafadas. Não há farm, level nem
exploração: o jogo inteiro é a **luta contra o chefe**. O combate é **tab-target**
(seleção de alvo + auto-attack + habilidades ativas, estilo WoW); a habilidade
individual está em **executar mecânicas** (sair de AoE, reagir a fases), **otimizar a
rotação** e **cumprir o papel** (tank/healer/dps). A referência de sensação visual e
de movimento é o **Zelda top-down clássico**; a de conteúdo e combate é o mapa
**Impossible Bosses** de Warcraft 3. Leve, rápido e medindo o **desempenho
individual** dentro do esforço do time.

## 2. Referências

**Do Impossible Bosses (WC3) herdamos:**
- Encontros contra chefes como o *único* conteúdo — sem farm, sem level, sem loot.
- Mecânicas telegrafadas que exigem reação e reposicionamento; alta punição por erro.
- Fases de chefe que mudam o padrão de ataque ao longo da luta.
- "Adds" (inimigos menores) e mecânicas que forçam decisão sob pressão.
- **Combate baseado em alvo** (WC3 é target-based) — coerente com a escolha tab-target.

**Do Zelda top-down clássico herdamos (só visual/movimento):**
- Câmera de cima, movimento em plano 2D, leitura espacial clara.
- Sprites simples e leveza técnica — roda em qualquer máquina.
- **Não** herdamos o combate de ação/mira do Zelda — aqui o combate é tab-target.

**O que deliberadamente deixamos de fora:**
- Mundo aberto, dungeons, puzzles de exploração, história longa.
- Progressão por itens/equipamento e economia.
- Qualquer coisa que dilua o foco em "executar a luta bem".

## 3. Pilares de design

Servem de filtro: se uma feature nova não reforça um destes pilares, ela provavelmente
está fora de escopo.

1. **Mecânica acima de tudo.** O prazer vem de executar mecânicas e cumprir o papel,
   não de números subindo por si só.
2. **Encontros curtos e intensos.** Uma luta dura minutos, não horas. Morrer e tentar
   de novo é barato e rápido.
3. **Leveza técnica e visual.** Clareza > beleza. O visual existe para tornar os
   telégrafos legíveis, não para impressionar. (Pilar sob pressão: trindade + 8–10
   players empurram para complexidade; este pilar é a linha de defesa.)
4. **Skill individual visível.** Cada jogador enxerga o próprio desempenho e o melhora.
   O co-op soma indivíduos competentes; não esconde os fracos.

## 4. Loop de gameplay & modelo de combate

**Modelo de combate — tab-target (estilo WoW):**
- O jogador **seleciona um alvo** dentro do campo de visão (o boss ou um add).
- O **auto-attack** dispara automaticamente no alvo enquanto ele estiver no alcance/visão.
- A camada de decisão é o **uso ativo de habilidades** no alvo + **gestão de recurso**
  (Ira/Mana/Foco, ver seção 7).
- **Movimentação é desacoplada da mira:** você anda para **sair de AoE telegrafado** e
  se posicionar, enquanto o auto-attack cuida do dano no alvo travado.

Crítica honesta: com tab-target, o "skill individual" **não é mira/reflexo**. Ele é:
(a) **execução de mecânicas** (sair do que vai bater), (b) **rotação/otimização** de
habilidades e recurso, (c) **troca de alvo** (priorizar adds), (d) **execução do
papel**. É o mesmo eixo de habilidade de uma raid de MMO — bom para medir por meters
(seção 13), mas distante de "twitch".

**Micro (segundo a segundo):** selecionar alvo → auto-attack → usar habilidades e
gerenciar recurso → ler telégrafo → reposicionar/sair do AoE → reagir à mudança de
fase → trocar de alvo quando adds aparecem.

**Macro (por sessão):** montar composição (3 papéis) → preencher vagas com bots →
enfrentar o chefe → vitória **ou** wipe → repetir/próximo chefe.

Crítica: o loop macro é curtíssimo (intencional), com risco de ficar repetitivo. A
profundidade tem de vir da **variedade de mecânicas por chefe** e do **teto de execução
individual**, não de tempo de sessão. Monitorar desde o primeiro protótipo.

## 5. Modo de jogo & multiplayer

**Alvo:** co-op **online**. É a tese do jogo — desempenho individual só faz sentido
comparado ao dos outros no mesmo combate.

**Número de jogadores:**
- **Fase de teste: 3** — exatamente 1 tank, 1 healer, 1 dps. Composição mínima que
  exercita a trindade inteira.
- **Norte do projeto: 8–10 jogadores.** Tudo é projetado pensando nessa escala, mas
  **construído e validado primeiro em 3**.

Crítica: começar com 1 de cada papel é limpo, porém **frágil** (zero redundância — um
morto tende a virar wipe). Bom para testar a trindade "pura", ciente da fragilidade.
Escalar para 8–10 muda o balanceamento (múltiplos healers, threat com vários dps) e
**pesa muito no netcode**.

### Netcode (seção crítica)

O maior risco técnico do projeto. Pontos:

- **É PvE.** Sem competição direta entre jogadores, **não precisamos de servidor
  autoritativo à prova de trapaça** — a parte mais cara do netcode. Trapaça em co-op
  prejudica no máximo o próprio grupo. Isso *reduz drasticamente* o custo.
- **Modelo recomendado:** *host/listen-server* — um jogador (ou processo dedicado leve)
  hospeda a simulação; clientes enviam input e recebem estado. Godot 4 tem
  `MultiplayerAPI` / `MultiplayerSynchronizer` para isso.
- **Escala 8–10 pesa.** Sincronizar ~10 players + boss + adds + projéteis/telégrafos a
  cada tick não é trivial. Tab-target ajuda (menos precisão de posição por
  milissegundo que um twin-stick exigiria), mas o volume de entidades cresce.
- **Latência importa nas mecânicas.** Sair de um AoE com 100 ms de atraso pode custar a
  vida. Mitigações: predição de movimento do próprio jogador + janelas de telégrafo
  generosas o bastante para absorver latência.
- **Não subestimar.** "Simples porque é PvE" não é "trivial". Por isso o
  desenvolvimento começa **offline com bots** (seção 6); o online entra num marco
  próprio (M2).

## 6. Bots (filosofia bot-first)

Decisão central: **o jogo deve ser testável solo desde o início**, com bots
controlando os papéis que o desenvolvedor não estiver jogando.

**Requisito arquitetural (define o código desde a primeira linha):**
Tratar a **fonte de input como abstrata**. Um mesmo `ClassController` recebe comandos de:
- **input local** (teclado/mouse/gamepad),
- **peer de rede** (outro jogador, no futuro online),
- **IA** (bot).

Assim, **bots e multiplayer viram o mesmo problema**, resolvido uma vez, com
**paridade jogador/bot** (bots não acessam nada que um jogador não acessaria).

**Crítica reforçada pela trindade:** os bots ficaram **obrigatórios e mais difíceis**.
Para testar uma luta de 3 papéis solo, é preciso um **tank-bot** e um **healer-bot
competentes** — e IA de healer/tank é bem mais difícil que de dps. Um healer-bot ruim
= wipe = **bloqueia todo o teste**. Este é o principal risco à meta de "testável solo o
tempo todo". Encarar os bots como sistema de teste de primeira classe, não como enfeite.

**Sofisticação incremental:**
1. Bot burro: fica no alcance, auto-attack, usa habilidade básica.
2. Bot que reconhece telégrafos e sai da área.
3. Bot que cumpre o *papel*: tank mantém aggro; healer cura quem está baixo e prioriza;
   dps troca para adds.

## 7. Classes & papéis (trindade)

Decisão fechada: **trindade — tank / healer / dps.** As classes são o ponto crucial do
projeto e devem estar bem definidas desde o início. Isso cria **interdependência forte**
(mais co-op de verdade), ao custo de **mais sistemas** (seção 8) e de tornar o
desempenho individual menos óbvio em alguns papéis — resolvido via meters por papel
(seção 13).

**Framework de classe** — toda classe define:
- **Papel:** tank, healer ou dps.
- **Recurso:** o que gerencia (Ira, Mana, Foco Arcano…).
- **Kit:** ~4 habilidades assinatura + auto-attack.
- **Como mede desempenho individual:** a métrica que mostra se jogou bem.

### 7.1. Rascunho das 3 classes iniciais (fantasia medieval — 1ª versão, a iterar)

**Tank — "Guardião" (cavaleiro de escudo).**
Recurso: **Ira** (gerada ao dar/receber dano; gasta em mitigação e threat).
Identidade: segura o boss, controla adds, sobrevive a picos.
- *Provocar (taunt):* força o boss a atacá-lo por alguns segundos + threat alto (CD).
- *Investida:* avança até o alvo — pegar add / reposicionar.
- *Muralha (mitigação ativa):* reduz dano recebido por alguns segundos (gasta Ira); o
  **timing** é o skill.
- *Golpe de escudo:* ataque com threat alto que gera Ira.
- *Desempenho individual:* uptime de aggro no boss, mitigação nos momentos certos,
  posicionamento do boss e dos adds.

**Healer — "Clérigo".**
Recurso: **Mana** (regenera devagar; a **gestão** é o skill).
Identidade: mantém o time vivo, tria o dano, detém o combat-rez.
- *Cura direta:* cura forte single-target, mana cara.
- *Cura ao longo do tempo (HoT) / em área:* eficiente e proativa.
- *Escudo/absorção:* previne dano **antes** de acontecer (recompensa antecipar a mecânica).
- *Ressurreição:* combat-rez — traz 1 aliado de volta (**1x por boss**, ver seção 10),
  cast longo.
- *Desempenho individual:* eficiência (overheal baixo), reação a picos, aliados vivos,
  uso do rez.

**DPS — "Mago".**
Recurso: **Foco Arcano** (builder/spender: acumula com casts básicos, gasta num burst).
Identidade: dano no boss, troca rápida para adds, burst nas janelas certas.
- *Míssil arcano:* dano no alvo, gera Foco.
- *Nuke/burst:* dano alto, gasta Foco — usar na janela certa.
- *Dano em área:* limpar adds rápido.
- *Piscar (blink curto):* mobilidade/escape — o "dodge" que resta.
- *Desempenho individual:* DPS total, prioridade de alvo (adds mortos rápido), não
  morrer para mecânica, uptime de dano.

## 8. Sistemas exigidos pela trindade

A trindade **não funciona** sem três sistemas que antes não existiam no escopo. Eles
são o grosso do trabalho novo — e a razão de o M1 ter crescido (seção 14):

- **Ameaça / aggro:** tabela de threat por entidade; o boss ataca quem tem mais threat;
  taunt força o topo temporariamente. Sem isso, "tank" não existe.
- **Cura + recurso/mana:** sistema de vida com cura, `overheal`, e um recurso
  regenerável para o healer gerenciar. Sem isso, "healer" não existe.
- **Combat-rez:** ressuscitar um aliado morto durante a luta, com limite por encontro
  (seção 10).

Crítica: estes três sistemas são interdependentes e **precisam existir juntos** para a
trindade "sentir-se certa" — não dá para validar só um. É o maior bloco de risco de
engenharia depois do netcode.

## 9. Chefes

**Anatomia de um encontro:**
- **Fases:** o chefe muda de padrão em limiares de vida (ex.: 100%→66%→33%).
- **Telégrafos:** indicação visual clara e antecipada de onde/quando o ataque acerta
  (área no chão, linha, cone, projétil com trajetória).
- **Adds:** inimigos menores que aparecem e forçam repriorização (troca de alvo).
- **Mecânica de tank:** ataques que exigem o tank posicionado / trocas de aggro.
- **Enrage / timer:** pressão de tempo para o combate não se arrastar; recompensa DPS.

**Vertical slice:** projetar e polir **UM chefe completo** antes de qualquer outro — e
esse chefe já precisa exercitar a trindade (algo que force tank, algo que force healer,
adds que forcem o dps). **Não** desenhar um bestiário agora — é o convite ao scope creep.

## 10. Progressão & falha

- **Sem farm/level** (fiel ao original). O que evolui é a **habilidade do jogador**, não
  os atributos do personagem.
- **Ao morrer:** o jogador fica fora do combate até um **combat-rez** ou até o
  wipe/vitória.
- **Combat-rez:** **1 por boss** — recurso **de raid** (limite compartilhado pelo time,
  não por jogador), lançado pelo healer. Suaviza a punição sem torná-la irrelevante.
  ❓ Ao escalar para 8–10 e múltiplos healers, definir se o limite continua 1 por
  encontro ou vira X por encontro.
- **Wipe:** time inteiro morto → recomeça o encontro rápido (barato, por pilar 2).
- **Vitória:** chefe morto antes do enrage/timer.

## 11. Estilo visual & áudio

- **Arte placeholder** durante todo o desenvolvimento; substituir só quando a mecânica
  estiver validada.
- **Prioridade absoluta: legibilidade dos telégrafos.** Cor/forma/contraste do telégrafo
  importam mais que qualquer sprite. Um jogo assim vive ou morre pela clareza do "onde
  vai bater". Com 8–10 players + adds na tela, evitar poluição visual é ainda mais
  crítico.
- **Feedback de alvo:** o alvo selecionado precisa ser inequívoco (contorno/marcador),
  já que o combate é tab-target.
- Áudio: cues sonoros para telégrafos e mudanças de fase ajudam muito — considerar cedo,
  mesmo com sons placeholder.

## 12. Escopo técnico

- **Engine:** Godot 4.x, projeto 2D top-down.
- **Plataforma:** desktop (Windows/Linux) como alvo primário; avaliar export web depois
  — bom para compartilhar, mas o netcode em WebRTC/WebSocket adiciona atrito.
- **Estrutura de projeto (futura, M1):** cenas separadas para arena, chefe, personagem e
  HUD; `ClassController` com **fonte de input abstrata** (seção 6); dados de
  chefe/classe/habilidade em recursos (`.tres`) para iterar sem mexer em código;
  sistemas de **threat**, **vida/cura/recurso** e **targeting** como serviços centrais.
- Sem dependências pesadas. Manter o projeto enxuto.

## 13. Métricas de desempenho individual

Para que "skill individual" (pilar 4) seja real — e para compensar que a trindade
esconde parte do desempenho —, o jogo mede e mostra, **por papel**:
- **Tank:** uptime de aggro, dano mitigado, mortes evitáveis.
- **Healer:** cura efetiva, eficiência (overheal baixo), aliados que morreram sob sua
  responsabilidade, uso do rez.
- **DPS:** dano causado, prioridade de alvo (tempo até matar adds), uptime de dano.
- **Todos:** vezes atingido por mecânica evitável (o "você pisou no fogo").

Resumo pós-luta resolve a **tensão "individual vs. time"**: o time vence junto, mas cada
um vê a própria performance. Cuidado crítico: métricas mal escolhidas distorcem o
comportamento (medir só dano incentiva ignorar mecânicas). Medir o que queremos que os
jogadores valorizem — sobretudo **execução de mecânica** e **cumprir o papel**.

## 14. Roadmap / marcos

- **M0 — Escopo (atual):** este documento.
- **M1 — Vertical slice (solo, com bots):** a trindade **inteira** funcionando numa luta
  de 1 boss — 1 tank, 1 healer, 1 dps (você joga 1, bots nos outros 2) + arena + os
  sistemas da seção 8 (threat, cura/recurso, combat-rez). Objetivo: provar que a luta de
  raid top-down é divertida. **M1 é maior do que era** por causa da trindade. **Se M1
  não for divertido solo com bots, nada depois salva o projeto.**
- **M2 — Co-op online (3 players):** host/listen-server, 3 jogadores reais, predição de
  movimento. Marco de maior risco técnico.
- **M3 — Escala e conteúdo:** subir para 8–10 players, mais chefes e classes,
  balanceamento, meters polidos.

Ênfase crítica: **cortar escopo agressivamente**. A tentação será adicionar classes,
chefes e a escala de 8–10 antes de M1 estar bom. Resistir — validar tudo em 3 primeiro.

## 15. Não-objetivos (out of scope)

O jogo explicitamente **NÃO** é / **NÃO** terá:
- MMO ou mundo persistente (é um "boss rush" de sessões curtas, apesar do combate
  estilo raid).
- Mundo aberto ou exploração.
- Loot, itens, equipamento ou economia.
- Progressão de atributos por level/farm.
- **PvP** (o design de netcode inteiro assume PvE).
- História/campanha elaborada.

Manter esta lista visível é a principal defesa contra scope creep.

## 16. Questões em aberto

- ❓ Quantas classes além das 3 iniciais, e quantas por papel (ao escalar para 8–10).
- ❓ Modelos exatos de recurso (curvas de Ira/Mana/Foco, regeneração, custos).
- ❓ Ao escalar: quantos combat-rez por encontro e quem além do healer pode lançá-lo.
- ❓ Como o "campo de visão" limita a seleção de alvo (alcance? linha de visão? só o que
  está na tela?).
- ❓ Auto-attack: alcance corpo-a-corpo (tank) vs. à distância (mago/clérigo) e como isso
  afeta posicionamento.
- ❓ Número final de jogadores no alvo (8, 10, faixa?) e tamanho da arena para comportá-los.
