extends PartyMember
class_name Mago
## Mago — DPS à distância. Jogável (humano) ou bot.
##
## Modelo de dano: AUTO-ATTACK fraco (funciona andando) + CONJURAÇÃO forte que
## só progride PARADO (mover interrompe e zera). Alvo de inimigo via tab-target
## (Tab cicla / clique seleciona — roteado pelo Main) ou auto-aquisição do bot.
##
## Visual procedural: mago com robe/chapéu/cajado, olha na direção do alvo,
## leve balanço de idle, orbe do cajado brilha ao conjurar, flash ao tomar dano.

const SPEED := 220.0
const ATTACK_RANGE := 320.0
const ATTACK_INTERVAL := 0.8
const ATTACK_DAMAGE := 6.0
const CAST_TIME := 1.1
const CAST_DAMAGE := 28.0

var target = null  # Boss/Add (inimigos) — sem tipo fixo de propósito

var _attack_cd := 0.0
var _cast_progress := 0.0
var _casting := false
var _interrupt_timer := 0.0
var _facing := Vector2(0.0, 1.0)


func _ready() -> void:
	super._ready()
	role_label = "Mago"
	max_hp = 100.0
	hp = max_hp
	radius = 14.0


func _process(delta: float) -> void:
	if not alive:
		return
	_tick_visuals(delta)
	var moving := _bot_move(delta) if is_bot else _human_move(delta)
	_handle_autoattack(delta)
	_handle_cast(delta, moving)
	if _interrupt_timer > 0.0:
		_interrupt_timer -= delta
	if target == null or not is_instance_valid(target):
		_acquire_nearest_enemy()
	if target != null and is_instance_valid(target):
		var tv: Vector2 = target.position - position
		if tv.length() > 1.0:
			_facing = tv.normalized()
	queue_redraw()


func _human_move(delta: float) -> bool:
	var dir := _read_wasd()
	var moving := dir != Vector2.ZERO
	if moving:
		position += dir.normalized() * SPEED * delta
		_clamp_to_arena()
	return moving


func _bot_move(delta: float) -> bool:
	var flee := _aoe_flee_vector()
	if flee != Vector2.ZERO:
		position += flee * SPEED * delta
		_clamp_to_arena()
		return true
	if target != null and is_instance_valid(target):
		var d: float = position.distance_to(target.position)
		if d > ATTACK_RANGE * 0.7:
			var dir: Vector2 = (target.position - position).normalized()
			position += dir * SPEED * delta
			_clamp_to_arena()
			return true
	return false


func _handle_autoattack(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if not _has_target_in_range():
		return
	if _attack_cd == 0.0:
		_attack_cd = ATTACK_INTERVAL
		target.take_damage(ATTACK_DAMAGE)
		_notify_threat(ATTACK_DAMAGE)


func _handle_cast(delta: float, moving: bool) -> void:
	if moving or not _has_target_in_range():
		if _casting and _cast_progress > 0.15:
			_interrupt_timer = 0.35
		_casting = false
		_cast_progress = 0.0
		return
	_casting = true
	_cast_progress += delta
	if _cast_progress >= CAST_TIME:
		_cast_progress = 0.0
		target.take_damage(CAST_DAMAGE)
		_notify_threat(CAST_DAMAGE)


func _notify_threat(damage: float) -> void:
	if boss != null and is_instance_valid(boss) and target == boss and boss.has_method("add_threat"):
		boss.add_threat(self, damage)


func _has_target_in_range() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("take_damage"):
		return false
	return position.distance_to(target.position) <= ATTACK_RANGE


func get_cast_status() -> Dictionary:
	return {
		"casting": _casting,
		"progress": _cast_progress,
		"cast_time": CAST_TIME,
		"interrupted": _interrupt_timer > 0.0,
	}


func cycle_target() -> void:
	var list := _targetables()
	if list.is_empty():
		target = null
		return
	var idx := list.find(target)
	target = list[(idx + 1) % list.size()]


func _acquire_nearest_enemy() -> void:
	var list := _targetables()
	var best: Node2D = null
	var best_d := INF
	for t: Node2D in list:
		var d: float = position.distance_to(t.position)
		if d < best_d:
			best_d = d
			best = t
	target = best


func _targetables() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group("targetable"):
		if is_instance_valid(n):
			out.append(n)
	out.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	return out


func _draw() -> void:
	# Retícula do alvo + linha de auto-attack.
	if alive and target != null and is_instance_valid(target):
		var to_target: Vector2 = target.position - position
		draw_arc(to_target, 34.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.3, 0.85), 2.0)
		if to_target.length() <= ATTACK_RANGE:
			draw_line(Vector2.ZERO, to_target, Color(0.6, 0.9, 1.0, 0.22), 2.0)

	_draw_character()
	_draw_shield_overlay()
	_draw_cast_bar()
	_draw_hp_bar(40.0, 5.0, -radius - 14.0, Color(0.4, 1.0, 0.5))


func _draw_character() -> void:
	var dead := not alive
	var bob := 0.0 if dead else sin(anim_time * 3.5) * 1.5

	# Sombra (sem balanço).
	draw_set_transform(Vector2(0.0, radius * 0.95), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Corpo (com balanço de idle).
	draw_set_transform(Vector2(0.0, -bob), 0.0, Vector2.ONE)

	var robe := _flash_mix(Color(0.32, 0.55, 0.95) if not dead else Color(0.42, 0.42, 0.47))
	var robe_dark := _flash_mix(Color(0.22, 0.42, 0.82) if not dead else Color(0.34, 0.34, 0.40))
	var skin := _flash_mix(Color(0.96, 0.86, 0.74) if not dead else Color(0.50, 0.50, 0.52))
	var hat := _flash_mix(Color(0.24, 0.32, 0.72) if not dead else Color(0.30, 0.30, 0.36))
	var w := radius

	# Robe (trapézio) + sombreado esquerdo.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, radius), Vector2(w, radius),
		Vector2(w * 0.5, -radius * 0.15), Vector2(-w * 0.5, -radius * 0.15),
	]), robe)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, radius), Vector2(0.0, radius),
		Vector2(0.0, -radius * 0.15), Vector2(-w * 0.5, -radius * 0.15),
	]), robe_dark)

	# Cabeça.
	var head := Vector2(0.0, -radius * 0.55)
	draw_circle(head, radius * 0.42, skin)

	# Chapéu (cone + aba).
	draw_colored_polygon(PackedVector2Array([
		Vector2(-radius * 0.55, head.y - radius * 0.18),
		Vector2(radius * 0.55, head.y - radius * 0.18),
		Vector2(0.0, head.y - radius * 1.35),
	]), hat)
	draw_line(head + Vector2(-radius * 0.62, -radius * 0.18), head + Vector2(radius * 0.62, -radius * 0.18), hat, 3.0)

	# Olhos (olham na direção do facing).
	var look := Vector2(_facing.x, 0.0) * (radius * 0.08)
	draw_circle(head + Vector2(-radius * 0.14, -radius * 0.02) + look, radius * 0.05, Color(0.1, 0.1, 0.15))
	draw_circle(head + Vector2(radius * 0.14, -radius * 0.02) + look, radius * 0.05, Color(0.1, 0.1, 0.15))

	# Cajado + orbe na direção do facing.
	var fdir := _facing
	if fdir.length() < 0.1:
		fdir = Vector2(0.0, 1.0)
	fdir = fdir.normalized()
	var hand := fdir * (radius * 0.5) + Vector2(0.0, radius * 0.1)
	var tip := hand + fdir * (radius * 1.1)
	draw_line(hand, tip, _flash_mix(Color(0.55, 0.40, 0.25)), 2.5)
	var orb_pulse := 0.9 if _casting else (0.6 + 0.15 * sin(anim_time * 6.0))
	if _casting:
		draw_circle(tip, radius * 0.4, Color(0.5, 0.9, 1.0, 0.3))
	draw_circle(tip, radius * 0.2, Color(0.6, 0.95, 1.0, orb_pulse))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cast_bar() -> void:
	if not alive:
		return
	var w := 46.0
	var h := 5.0
	var off := Vector2(-w / 2.0, radius + 10.0)
	if _casting and _cast_progress > 0.0:
		draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
		draw_rect(Rect2(off, Vector2(w * (_cast_progress / CAST_TIME), h)), Color(0.4, 0.85, 1.0), true)
	elif _interrupt_timer > 0.0:
		draw_rect(Rect2(off, Vector2(w, h)), Color(1.0, 0.3, 0.3, 0.85), true)
