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
##
## Visual: orbe sombrio com aura pulsante, chifres e olhos brilhantes.
## Fases, adds e projéteis voltam na Fase 5.

signal phase_changed(new_phase: int)

const AOE_TELEGRAPH := 1.3
const AOE_RADIUS := 90.0
const AOE_DAMAGE := 35.0
const AOE_COOLDOWN := 2.6

const MELEE_INTERVAL := 1.6
const MELEE_DAMAGE := 26.0
const TAUNT_THREAT_BONUS := 40.0

var arena_rect := Rect2()
var phase := 1

var _aoes: Array = []   # cada item: {"pos": Vector2, "timer": float}
var _aoe_cd := 1.5
var _melee_cd := 2.0

var _threat_members: Array = []   # PartyMember (guardados sem tipo estrito)
var _threat_values := {}          # instance_id(int) -> float


func _ready() -> void:
	add_to_group("targetable")
	max_hp = 450.0
	hp = max_hp
	radius = 30.0


func _process(delta: float) -> void:
	if not alive:
		return
	_tick_visuals(delta)
	_update_melee(delta)
	_update_aoes(delta)
	queue_redraw()


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
	_melee_cd = MELEE_INTERVAL
	t.take_damage(MELEE_DAMAGE)


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
		_aoe_cd = AOE_COOLDOWN


func _cast_aoe() -> void:
	var party := _alive_party()
	if party.is_empty():
		return
	var victim: PartyMember = party[randi() % party.size()]
	_aoes.append({"pos": victim.position, "timer": AOE_TELEGRAPH})


func _detonate(pos: Vector2) -> void:
	for m: PartyMember in _alive_party():
		if m.position.distance_to(pos) <= AOE_RADIUS:
			m.take_damage(AOE_DAMAGE)
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
		var frac: float = clampf(1.0 - (aoe["timer"] / AOE_TELEGRAPH), 0.0, 1.0)
		draw_circle(local, AOE_RADIUS, Color(1.0, 0.2, 0.2, 0.14))
		draw_circle(local, AOE_RADIUS * frac, Color(1.0, 0.25, 0.2, 0.34))
		draw_arc(local, AOE_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, 0.9), 2.5)

	_draw_body()
	_draw_hp_bar(110.0, 8.0, -radius - 20.0, Color(0.9, 0.3, 0.3))


func _draw_body() -> void:
	var dead := not alive
	var pulse := 0.5 + 0.5 * sin(anim_time * 2.0)

	if not dead:
		draw_circle(Vector2.ZERO, radius * (1.55 + 0.25 * pulse), Color(0.9, 0.2, 0.3, 0.05 + 0.05 * pulse))
		draw_circle(Vector2.ZERO, radius * (1.25 + 0.12 * pulse), Color(0.9, 0.25, 0.35, 0.10))

	var horn := _flash_mix(Color(0.55, 0.18, 0.22) if not dead else Color(0.4, 0.3, 0.32))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-radius * 0.72, -radius * 0.45),
		Vector2(-radius * 0.32, -radius * 0.55),
		Vector2(-radius * 0.52, -radius * 1.15),
	]), horn)
	draw_colored_polygon(PackedVector2Array([
		Vector2(radius * 0.72, -radius * 0.45),
		Vector2(radius * 0.32, -radius * 0.55),
		Vector2(radius * 0.52, -radius * 1.15),
	]), horn)

	var body := _flash_mix(Color(0.82, 0.3, 0.35) if not dead else Color(0.45, 0.3, 0.32))
	draw_circle(Vector2.ZERO, radius, body)
	draw_circle(Vector2.ZERO, radius * 0.62, Color(0.5, 0.14, 0.2, 0.5))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, _flash_mix(Color(1.0, 0.85, 0.85)), 3.0)

	if not dead:
		var eye := Color(1.0, 0.85, 0.3)
		draw_circle(Vector2(-radius * 0.3, -radius * 0.08), radius * 0.13, eye)
		draw_circle(Vector2(radius * 0.3, -radius * 0.08), radius * 0.13, eye)
		draw_circle(Vector2(-radius * 0.3, -radius * 0.08), radius * 0.06, Color(1.0, 1.0, 0.8))
		draw_circle(Vector2(radius * 0.3, -radius * 0.08), radius * 0.06, Color(1.0, 1.0, 0.8))
