extends Node2D
class_name Boss
## Boss de protótipo com fases e duas mecânicas.
##
## Mecânica A — AoE telegrafado no chão (círculo vermelho que cresce durante o
## aviso; ao fim, detona e dá dano em quem estiver dentro). Mira na posição do
## jogador no início do aviso.
## Mecânica B — projéteis (fase 2+), disparados na direção do jogador.
##
## Fases por % de vida:
##   Fase 1 (100–66%): só AoE.
##   Fase 2 (66–33%):  AoE mais frequente + projéteis.
##   Fase 3 (33–0%):   dois AoEs simultâneos + projéteis mais rápidos.

signal died
signal phase_changed(new_phase: int)

const MAX_HP := 450.0
const RADIUS := 30.0

const AOE_TELEGRAPH := 1.3
const AOE_RADIUS := 90.0
const AOE_DAMAGE := 35.0

var arena_rect := Rect2()
var hp := MAX_HP
var player: Node2D = null
var projectile_parent: Node2D = null

var _alive := true
var phase := 1
var _aoes: Array = []   # cada item: {"pos": Vector2, "timer": float}
var _aoe_cd := 1.5
var _proj_cd := 1.0


func _process(delta: float) -> void:
	if not _alive:
		return
	_update_phase()
	_update_aoes(delta)
	_update_projectiles(delta)
	queue_redraw()


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
	_aoes.append({"pos": _player_pos(), "timer": AOE_TELEGRAPH})
	if phase >= 3:
		_aoes.append({"pos": _random_arena_point(), "timer": AOE_TELEGRAPH})


func _update_projectiles(delta: float) -> void:
	if phase < 2:
		return
	_proj_cd -= delta
	if _proj_cd <= 0.0:
		_fire_projectile()
		_proj_cd = 2.0 if phase == 2 else 1.3


func _fire_projectile() -> void:
	if projectile_parent == null or player == null or not is_instance_valid(player):
		return
	var proj := Projectile.new()
	proj.position = position
	proj.arena_rect = arena_rect
	proj.player = player
	var dir := player.position - position
	dir = dir.normalized() if dir.length() > 0.1 else Vector2.DOWN
	proj.velocity = dir * Projectile.SPEED
	projectile_parent.add_child(proj)


func _detonate(pos: Vector2) -> void:
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		if player.position.distance_to(pos) <= AOE_RADIUS:
			player.take_damage(AOE_DAMAGE)


func _player_pos() -> Vector2:
	if player != null and is_instance_valid(player):
		return player.position
	return arena_rect.get_center()


func _random_arena_point() -> Vector2:
	var m := AOE_RADIUS
	var x := randf_range(arena_rect.position.x + m, arena_rect.end.x - m)
	var y := randf_range(arena_rect.position.y + m, arena_rect.end.y - m)
	return Vector2(x, y)


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
	# AoEs telegrafados (coordenadas locais, relativas ao boss).
	for aoe in _aoes:
		var local: Vector2 = aoe["pos"] - position
		var frac: float = clampf(1.0 - (aoe["timer"] / AOE_TELEGRAPH), 0.0, 1.0)
		draw_circle(local, AOE_RADIUS, Color(1.0, 0.2, 0.2, 0.16))
		draw_circle(local, AOE_RADIUS * frac, Color(1.0, 0.25, 0.2, 0.35))
		draw_arc(local, AOE_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, 0.9), 2.5)

	# Corpo do boss (cor por fase).
	var body_color := _phase_color() if _alive else Color(0.45, 0.3, 0.32)
	draw_circle(Vector2.ZERO, RADIUS, body_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(1.0, 0.85, 0.85), 3.0)

	_draw_hp_bar()


func _draw_hp_bar() -> void:
	var w := 90.0
	var h := 7.0
	var off := Vector2(-w / 2.0, -RADIUS - 16.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (hp / MAX_HP), h)), Color(0.9, 0.3, 0.3), true)
	# Marcadores das viradas de fase (66% e 33%).
	for t in [0.33, 0.66]:
		var x := off.x + w * t
		draw_line(Vector2(x, off.y), Vector2(x, off.y + h), Color(0, 0, 0, 0.8), 1.0)
