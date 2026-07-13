extends Node2D
class_name Boss
## Boss de protótipo com trindade: threat/aggro, fases e quatro mecânicas.
##
## Mecânica A — ataque corpo-a-corpo periódico no alvo com MAIS THREAT (exige
## um tank segurando aggro; sem tank, ele bate em quem estiver no topo da
## tabela de threat, geralmente quem causou mais dano).
## Mecânica B — AoE telegrafado no chão, mirado num membro aleatório do grupo
## (mecânica "espalha" — qualquer um pode ser o alvo, inclusive o tank).
## Mecânica C — projéteis (fase 2+) disparados num membro aleatório do grupo.
## Mecânica D — adds que perseguem o membro mais próximo.
##
## Fases por % de vida:
##   Fase 1 (100–66%): corpo-a-corpo + AoE + adds.
##   Fase 2 (66–33%):  + projéteis, AoE mais frequente.
##   Fase 3 (33–0%):   dois AoEs simultâneos + projéteis mais rápidos.

signal died
signal phase_changed(new_phase: int)

const MAX_HP := 900.0
const RADIUS := 34.0

const AOE_TELEGRAPH := 1.3
const AOE_RADIUS := 90.0
const AOE_DAMAGE := 32.0

const MELEE_INTERVAL := 1.6
const MELEE_DAMAGE := 30.0

const ADD_SPAWN_INTERVAL := 8.0
const MAX_ADDS := 3

const REZ_CHARGES_PER_ENCOUNTER := 1
const TAUNT_THREAT_BONUS := 40.0

var arena_rect := Rect2()
var hp := MAX_HP
var entity_parent: Node2D = null
var rez_charges := REZ_CHARGES_PER_ENCOUNTER

var _alive := true
var phase := 1
var _aoes: Array = []   # cada item: {"pos": Vector2, "timer": float}
var _aoe_cd := 1.6
var _proj_cd := 1.4
var _add_cd := 6.0
var _melee_cd := 2.0

var _threat_members: Array = []      # PartyMember (guardados sem tipo estrito)
var _threat_values := {}             # instance_id(int) -> float


func _ready() -> void:
	add_to_group("targetable")


func _process(delta: float) -> void:
	if not _alive:
		return
	_update_phase()
	_update_melee(delta)
	_update_aoes(delta)
	_update_projectiles(delta)
	_update_adds(delta)
	queue_redraw()


# --- Ameaça / aggro ---------------------------------------------------------

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


# --- Fases -------------------------------------------------------------

func _update_phase() -> void:
	var frac := hp / MAX_HP
	var new_phase := 1
	if frac <= 0.33:
		new_phase = 3
	elif frac <= 0.66:
		new_phase = 2
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)


# --- Corpo-a-corpo (exige tank) ----------------------------------------

func _update_melee(delta: float) -> void:
	_melee_cd -= delta
	if _melee_cd > 0.0:
		return
	var t: PartyMember = current_target()
	if t == null:
		return
	_melee_cd = MELEE_INTERVAL
	t.take_damage(MELEE_DAMAGE)


# --- AoE telegrafado (mira aleatória entre o grupo) ---------------------

func _update_aoes(delta: float) -> void:
	for i in range(_aoes.size() - 1, -1, -1):
		_aoes[i]["timer"] -= delta
		if _aoes[i]["timer"] <= 0.0:
			_detonate(_aoes[i]["pos"])
			_aoes.remove_at(i)

	_aoe_cd -= delta
	if _aoe_cd <= 0.0:
		_cast_aoes()
		_aoe_cd = _current_aoe_cooldown()


func _current_aoe_cooldown() -> float:
	if phase >= 3:
		return 2.0
	elif phase == 2:
		return 2.4
	return 2.8


func _cast_aoes() -> void:
	var party := _alive_party()
	if party.is_empty():
		return
	var primary: PartyMember = party[randi() % party.size()]
	_aoes.append({"pos": primary.position, "timer": AOE_TELEGRAPH})
	if phase >= 3:
		_aoes.append({"pos": _random_arena_point(), "timer": AOE_TELEGRAPH})


func _detonate(pos: Vector2) -> void:
	for m: PartyMember in _alive_party():
		if m.position.distance_to(pos) <= AOE_RADIUS:
			m.take_damage(AOE_DAMAGE)


# --- Projéteis (fase 2+) -------------------------------------------------

func _update_projectiles(delta: float) -> void:
	if phase < 2:
		return
	_proj_cd -= delta
	if _proj_cd <= 0.0:
		_fire_projectile()
		_proj_cd = 2.0 if phase == 2 else 1.3


func _fire_projectile() -> void:
	if entity_parent == null:
		return
	var party := _alive_party()
	if party.is_empty():
		return
	var t: PartyMember = party[randi() % party.size()]
	var proj := Projectile.new()
	proj.position = position
	proj.arena_rect = arena_rect
	var dir: Vector2 = t.position - position
	dir = dir.normalized() if dir.length() > 0.1 else Vector2.DOWN
	proj.velocity = dir * Projectile.SPEED
	entity_parent.add_child(proj)


# --- Adds ------------------------------------------------------------------

func _update_adds(delta: float) -> void:
	_add_cd -= delta
	if _add_cd <= 0.0:
		_add_cd = ADD_SPAWN_INTERVAL
		_spawn_add()


func _spawn_add() -> void:
	if entity_parent == null or _count_adds() >= MAX_ADDS:
		return
	var a := Add.new()
	a.position = position + Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0))
	entity_parent.add_child(a)


func _count_adds() -> int:
	var c := 0
	for n: Node in entity_parent.get_children():
		if n is Add:
			c += 1
	return c


# --- Utilidades ------------------------------------------------------------

func _alive_party() -> Array:
	var out: Array = []
	for n: PartyMember in get_tree().get_nodes_in_group("party"):
		if is_instance_valid(n) and n.alive:
			out.append(n)
	return out


func _random_arena_point() -> Vector2:
	var m := AOE_RADIUS
	var x := randf_range(arena_rect.position.x + m, arena_rect.end.x - m)
	var y := randf_range(arena_rect.position.y + m, arena_rect.end.y - m)
	return Vector2(x, y)


## Usado por bots para desviar (ver PartyMember._aoe_flee_vector).
func get_active_aoes() -> Array:
	var out: Array = []
	for aoe in _aoes:
		out.append({"pos": aoe["pos"], "radius": AOE_RADIUS})
	return out


func pick_radius() -> float:
	return RADIUS + 6.0


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		_alive = false
		died.emit()
	queue_redraw()


func _phase_color() -> Color:
	if phase >= 3:
		return Color(0.95, 0.25, 0.6)
	elif phase == 2:
		return Color(0.95, 0.5, 0.25)
	return Color(0.82, 0.3, 0.35)


func _draw() -> void:
	for aoe in _aoes:
		var local: Vector2 = aoe["pos"] - position
		var frac: float = clampf(1.0 - (aoe["timer"] / AOE_TELEGRAPH), 0.0, 1.0)
		draw_circle(local, AOE_RADIUS, Color(1.0, 0.2, 0.2, 0.16))
		draw_circle(local, AOE_RADIUS * frac, Color(1.0, 0.25, 0.2, 0.35))
		draw_arc(local, AOE_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, 0.9), 2.5)

	var body_color := _phase_color() if _alive else Color(0.45, 0.3, 0.32)
	draw_circle(Vector2.ZERO, RADIUS, body_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(1.0, 0.85, 0.85), 3.0)

	_draw_hp_bar()


func _draw_hp_bar() -> void:
	var w := 110.0
	var h := 8.0
	var off := Vector2(-w / 2.0, -RADIUS - 18.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (hp / MAX_HP), h)), Color(0.9, 0.3, 0.3), true)
	for t: float in [0.33, 0.66]:
		var x: float = off.x + w * t
		draw_line(Vector2(x, off.y), Vector2(x, off.y + h), Color(0, 0, 0, 0.8), 1.0)
