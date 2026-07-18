extends Actor
class_name Boss
## Boss — Fase 2 (mínimo jogável). Estende Actor (HP unificado).
##
## Uma mecânica: AoE telegrafado no chão (círculo vermelho que cresce durante o
## aviso; ao fim, detona e dá dano em quem estiver dentro). Mira num membro
## aleatório do grupo "party" no início do aviso, dando tempo de sair.
##
## Threat/aggro, fases, corpo-a-corpo, adds e projéteis voltam nas fases 3-4.

signal phase_changed(new_phase: int)

const AOE_TELEGRAPH := 1.3
const AOE_RADIUS := 90.0
const AOE_DAMAGE := 35.0
const AOE_COOLDOWN := 2.6

var arena_rect := Rect2()
var phase := 1

var _aoes: Array = []   # cada item: {"pos": Vector2, "timer": float}
var _aoe_cd := 1.5


func _ready() -> void:
	add_to_group("targetable")
	max_hp = 450.0
	hp = max_hp
	radius = 30.0


func _process(delta: float) -> void:
	if not alive:
		return
	_update_aoes(delta)
	queue_redraw()


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


func _draw() -> void:
	for aoe in _aoes:
		var local: Vector2 = aoe["pos"] - position
		var frac: float = clampf(1.0 - (aoe["timer"] / AOE_TELEGRAPH), 0.0, 1.0)
		draw_circle(local, AOE_RADIUS, Color(1.0, 0.2, 0.2, 0.16))
		draw_circle(local, AOE_RADIUS * frac, Color(1.0, 0.25, 0.2, 0.35))
		draw_arc(local, AOE_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, 0.9), 2.5)

	var body_color := Color(0.82, 0.3, 0.35) if alive else Color(0.45, 0.3, 0.32)
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.85, 0.85), 3.0)

	_draw_hp_bar(110.0, 8.0, -radius - 18.0, Color(0.9, 0.3, 0.3))
