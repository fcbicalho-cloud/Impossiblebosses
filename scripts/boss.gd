extends Actor
class_name Boss
## Boss — Fase 3. Estende Actor (HP unificado + juice).
##
## Mecânicas:
##   - Ameaça/aggro: tabela de threat; o corpo-a-corpo periódico bate em quem
##     tem MAIS threat (exige um tank segurando aggro; sem tank, bate em quem
##     causou mais dano).
##   - AoE telegrafado no chão, mirado num membro aleatório do grupo "party"
##     (mecânica "espalha" — qualquer um pode ser o alvo, inclusive o tank).
##   - FASES em 66% e 33% de vida: cada fase acelera o AoE, aumenta o
##     corpo-a-corpo e solta uma onda de adds (ESCOPO seção 9).
##   - ENRAGE por tempo: passado o limite da dificuldade, o dano cresce sem teto.
##     É o relógio que impede a luta de se arrastar; recompensa dps.
##
## Números vêm do preset de Difficulty (setado pelo Main ANTES do add_child, pois
## _ready já os aplica). Sem preset, cai no Normal.
##
## Visual: sprite 16×16 (Kenney Tiny Dungeon) escalado 4× — maior que os 3× dos
## jogadores, para o boss dominar a arena — com aura sombria pulsante e flash de
## dano (shader do Actor). Telégrafos de AoE e barra de vida continuam via _draw.
## Fases, adds e projéteis voltam na Fase 5.

signal phase_changed(new_phase: int)

const AOE_RADIUS := 90.0
const MELEE_INTERVAL := 1.6
const TAUNT_THREAT_BONUS := 40.0

## O boss PERSEGUE o topo da tabela de threat e só bate dentro de MELEE_RANGE.
## Antes ele era estático e acertava a qualquer distância, o que tornava
## posicionamento e threat decorativos: dava para atravessar a arena sem largar o
## boss. Agora puxar aggro traz o boss até você — inclusive para longe do grupo.
##
## MOVE_SPEED é deliberadamente menor que a dos jogadores (200-220): dá margem
## para reposicionar e para o tank arrastar o boss, sem permitir kite infinito,
## já que parar para conjurar (Mago) ou curar (Clérigo) deixa o boss alcançar.
const MOVE_SPEED := 155.0
const MELEE_RANGE := 74.0
## Histerese: só começa a andar acima de MELEE_RANGE, e para um pouco antes dele,
## para não tremer no limite do alcance.
const MELEE_STOP := MELEE_RANGE * 0.8

## Limiares de vida que disparam as fases 2 e 3.
const PHASE_THRESHOLDS: Array[float] = [0.66, 0.33]
## Multiplicadores por fase (índice = fase - 1): AoE mais frequente e melee mais
## forte conforme o boss cai de vida.
const PHASE_AOE_SPEEDUP: Array[float] = [1.0, 0.85, 0.7]
const PHASE_MELEE_MULT: Array[float] = [1.0, 1.15, 1.3]
## A cada ENRAGE_STEP segundos após o enrage, o dano sobe ENRAGE_RAMP.
const ENRAGE_STEP := 5.0
const ENRAGE_RAMP := 0.25

var difficulty: Difficulty = Difficulty.preset(Difficulty.NORMAL)
var arena_rect := Rect2()
var phase := 1
var rez_charges := 2
var enraged := false
## Segundos restantes até o enrage (só para o HUD mostrar o relógio).
var enrage_remaining := 0.0

var _aoes: Array = []   # cada item: {"pos": Vector2, "timer": float}
var _aoe_cd := 1.5
var _melee_cd := 2.0
var _enrage_elapsed := 0.0
var _facing_x := 0.0
var _world: Node2D = null  # container onde os adds nascem (setado pelo Main)

var _threat_members: Array = []   # PartyMember (guardados sem tipo estrito)
var _threat_values := {}          # instance_id(int) -> float


func _ready() -> void:
	add_to_group("targetable")
	max_hp = difficulty.boss_hp
	hp = max_hp
	radius = 30.0
	rez_charges = difficulty.rez_charges
	enrage_remaining = difficulty.enrage_seconds
	_aoe_cd = difficulty.aoe_cooldown * 0.6  # primeira mecânica vem um pouco antes
	_setup_body_sprite(preload("res://assets/characters/boss.png"), 4.0)


func _process(delta: float) -> void:
	_update_sprite()
	if not alive:
		return
	_tick_visuals(delta)
	_update_phase()
	_update_enrage(delta)
	_update_movement(delta)
	_update_melee(delta)
	_update_aoes(delta)
	queue_redraw()


## Persegue o alvo do topo do threat. Sem alvo, fica onde está.
func _update_movement(delta: float) -> void:
	var t: PartyMember = current_target()
	if t == null or not is_instance_valid(t):
		return
	var to_target: Vector2 = t.position - position
	var d: float = to_target.length()
	if d <= MELEE_STOP or d < 1.0:
		return
	position += to_target.normalized() * MOVE_SPEED * delta
	_facing_x = to_target.x
	if arena_rect.size != Vector2.ZERO:
		position.x = clampf(position.x, arena_rect.position.x + radius, arena_rect.end.x - radius)
		position.y = clampf(position.y, arena_rect.position.y + radius, arena_rect.end.y - radius)


# --- Fases e enrage --------------------------------------------------------

## Sobe de fase ao cruzar os limiares de vida. Só avança (não volta se o boss for
## curado) e cada fase entrega uma onda de adds.
func _update_phase() -> void:
	var frac := hp_fraction()
	var target_phase := 1
	for t: float in PHASE_THRESHOLDS:
		if frac <= t:
			target_phase += 1
	if target_phase <= phase:
		return
	# Uma onda POR fase cruzada: um burst grande de dano pode atravessar dois
	# limiares no mesmo frame, e pular a onda do meio deixaria o dps burlar
	# conteúdo simplesmente batendo forte.
	for _p in range(target_phase - phase):
		_spawn_add_wave()
	phase = target_phase
	phase_changed.emit(phase)


func _update_enrage(delta: float) -> void:
	if not enraged:
		enrage_remaining = maxf(0.0, enrage_remaining - delta)
		if enrage_remaining == 0.0:
			enraged = true
		return
	_enrage_elapsed += delta


## Multiplicador de dano acumulado: fase atual × rampa do enrage.
func damage_multiplier() -> float:
	var mult: float = PHASE_MELEE_MULT[clampi(phase - 1, 0, PHASE_MELEE_MULT.size() - 1)]
	if enraged:
		mult *= 1.0 + ENRAGE_RAMP * floor(_enrage_elapsed / ENRAGE_STEP)
	return mult


# --- Adds ------------------------------------------------------------------

## Onda de adds entrando pelas BORDAS da arena, distribuídos ao longo do
## perímetro. Nascer perto do boss não funcionava: o tank está sempre ali, então
## todos os adds grudavam nele — viravam um borrão e não criavam pressão nenhuma.
## Vindo da borda eles têm tempo de trajeto, dão para ser vistos chegando e
## costumam alcançar quem estiver exposto. Sem container (_world), a onda é
## silenciosamente ignorada.
func _spawn_add_wave() -> void:
	if _world == null or not is_instance_valid(_world) or arena_rect.size == Vector2.ZERO:
		return
	var count := difficulty.adds_per_wave
	for i in range(count):
		var t: float = fmod(float(i) / float(count) + randf() * 0.12, 1.0)
		var a := Add.new()
		a.setup(difficulty.add_hp, difficulty.add_damage, arena_rect)
		_world.add_child(a)
		a.position = _perimeter_point(t)


## Ponto na borda da arena, com t em [0,1) percorrendo o perímetro no sentido
## horário a partir do canto superior esquerdo.
func _perimeter_point(t: float) -> Vector2:
	var w := arena_rect.size.x
	var h := arena_rect.size.y
	var perimeter: float = 2.0 * (w + h)
	var d: float = t * perimeter
	var origin := arena_rect.position
	if d < w:
		return origin + Vector2(d, 0.0)
	d -= w
	if d < h:
		return origin + Vector2(w, d)
	d -= h
	if d < w:
		return origin + Vector2(w - d, h)
	d -= w
	return origin + Vector2(0.0, h - d)


func set_world(world: Node2D) -> void:
	_world = world


func active_add_count() -> int:
	var n := 0
	for a: Node in get_tree().get_nodes_in_group("add"):
		if is_instance_valid(a):
			n += 1
	return n


# --- Ameaça / aggro --------------------------------------------------------

func add_threat(source: PartyMember, amount: float) -> void:
	if source == null or not is_instance_valid(source) or amount <= 0.0:
		return
	var id := source.get_instance_id()
	if not _threat_values.has(id):
		_threat_members.append(source)
	_threat_values[id] = float(_threat_values.get(id, 0.0)) + amount


func taunt(source: PartyMember) -> void:
	if source == null or not is_instance_valid(source):
		return
	add_threat(source, _highest_threat_value() + TAUNT_THREAT_BONUS)


func current_target() -> PartyMember:
	var best: PartyMember = null
	var best_v := -1.0
	for m: PartyMember in _threat_members:
		if not is_instance_valid(m) or not m.alive:
			continue
		var v: float = _threat_values.get(m.get_instance_id(), 0.0)
		if v > best_v:
			best_v = v
			best = m
	return best


func _highest_threat_value() -> float:
	var best := 0.0
	for m: PartyMember in _threat_members:
		if not is_instance_valid(m):
			continue
		var v: float = _threat_values.get(m.get_instance_id(), 0.0)
		if v > best:
			best = v
	return best


# --- Corpo-a-corpo (exige tank) -------------------------------------------

func _update_melee(delta: float) -> void:
	_melee_cd -= delta
	if _melee_cd > 0.0:
		return
	var t: PartyMember = current_target()
	if t == null:
		return
	# Alcance de verdade: fora dele o boss precisa CAMINHAR até o alvo. O cooldown
	# não reinicia aqui, então ele bate assim que chega.
	if position.distance_to(t.position) > MELEE_RANGE:
		return
	_melee_cd = MELEE_INTERVAL
	t.take_damage(difficulty.melee_damage * damage_multiplier())


# --- AoE telegrafado -------------------------------------------------------

func _update_aoes(delta: float) -> void:
	for i in range(_aoes.size() - 1, -1, -1):
		_aoes[i]["timer"] -= delta
		if _aoes[i]["timer"] <= 0.0:
			_detonate(_aoes[i]["pos"])
			_aoes.remove_at(i)

	_aoe_cd -= delta
	if _aoe_cd <= 0.0:
		_cast_aoe()
		var speedup: float = PHASE_AOE_SPEEDUP[clampi(phase - 1, 0, PHASE_AOE_SPEEDUP.size() - 1)]
		_aoe_cd = difficulty.aoe_cooldown * speedup


func _cast_aoe() -> void:
	var party := _alive_party()
	if party.is_empty():
		return
	var victim: PartyMember = party[randi() % party.size()]
	_aoes.append({"pos": victim.position, "timer": difficulty.aoe_telegraph})


func _detonate(pos: Vector2) -> void:
	for m: PartyMember in _alive_party():
		if m.position.distance_to(pos) <= AOE_RADIUS:
			m.take_damage(difficulty.aoe_damage * damage_multiplier())
	_spawn_burst(pos)


func _spawn_burst(pos: Vector2) -> void:
	var fx := get_tree().get_first_node_in_group("fx")
	if fx == null:
		return
	var b := AoeBurst.new()
	b.setup(AOE_RADIUS)
	fx.add_child(b)
	b.global_position = pos


func _alive_party() -> Array:
	var out: Array = []
	for n: PartyMember in get_tree().get_nodes_in_group("party"):
		if is_instance_valid(n) and n.alive:
			out.append(n)
	return out


## Usado por bots para desviar (ver PartyMember._aoe_flee_vector).
func get_active_aoes() -> Array:
	var out: Array = []
	for aoe in _aoes:
		out.append({"pos": aoe["pos"], "radius": AOE_RADIUS})
	return out


# --- Visual ----------------------------------------------------------------

func _draw() -> void:
	for aoe in _aoes:
		var local: Vector2 = aoe["pos"] - position
		var frac: float = clampf(1.0 - (aoe["timer"] / difficulty.aoe_telegraph), 0.0, 1.0)
		draw_circle(local, AOE_RADIUS, Color(1.0, 0.2, 0.2, 0.14))
		draw_circle(local, AOE_RADIUS * frac, Color(1.0, 0.25, 0.2, 0.34))
		draw_arc(local, AOE_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, 0.9), 2.5)

	_draw_sprite_shadow()
	_draw_aura()
	_draw_hp_bar(110.0, 8.0, -radius - 20.0, Color(0.9, 0.3, 0.3))


## Sincroniza o Sprite2D: respiração lenta (escala pulsante) e pose de morte.
## Roda mesmo morto, por isso é chamado antes do early-return do _process.
func _update_sprite() -> void:
	if body_sprite == null:
		return
	if alive:
		body_sprite.rotation_degrees = 0.0
		body_sprite.modulate = Color.WHITE
		var breathe: float = 4.0 + 0.12 * sin(anim_time * 2.0)
		body_sprite.scale = Vector2(breathe, breathe)
		if absf(_facing_x) > 0.1:
			body_sprite.flip_h = _facing_x < 0.0
	else:
		body_sprite.rotation_degrees = 90.0
		body_sprite.modulate = Color(0.45, 0.3, 0.32)
		body_sprite.scale = Vector2(4.0, 4.0)


## Aura sombria pulsante sob o boss (fica atrás do sprite, por ser desenhada no
## _draw do próprio nó). Some quando ele morre.
func _draw_aura() -> void:
	if not alive:
		return
	var pulse: float = 0.5 + 0.5 * sin(anim_time * 2.0)
	draw_circle(Vector2.ZERO, radius * (1.55 + 0.25 * pulse), Color(0.9, 0.2, 0.3, 0.05 + 0.05 * pulse))
	draw_circle(Vector2.ZERO, radius * (1.25 + 0.12 * pulse), Color(0.9, 0.25, 0.35, 0.10))
	# Enrage: anel vermelho batendo rápido, para a pressão de tempo ser visível na
	# arena e não só no relógio do HUD.
	if enraged:
		var beat: float = 0.55 + 0.45 * sin(anim_time * 12.0)
		draw_arc(Vector2.ZERO, radius * 1.5, 0.0, TAU, 32, Color(1.0, 0.25, 0.15, beat), 4.0)
