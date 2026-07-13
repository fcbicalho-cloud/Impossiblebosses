extends Node2D
class_name Player
## "Mago" (DPS à distância) — controle local neste protótipo.
##
## Modelo de dano (o coração do combate):
##   - AUTO-ATTACK: dano fraco de manutenção; dispara sozinho no alvo em alcance,
##     inclusive andando.
##   - CONJURAÇÃO: o dano PRINCIPAL. Só progride enquanto você fica PARADO; mover
##     interrompe e zera o progresso. É a tensão "parar pra causar dano te expõe
##     às mecânicas".
##
## Alvo via tab-target (Tab cicla entre boss e adds — grupo "targetable").
##
## NOTA de arquitetura: o input vem direto do teclado por enquanto; no futuro
## vira uma "fonte de input" abstrata (local / rede / bot) — ver docs/ESCOPO.md.

signal died

const SPEED := 220.0
const RADIUS := 14.0
const MAX_HP := 100.0
const ATTACK_RANGE := 320.0

# Auto-attack: dano de manutenção, funciona sempre (inclusive andando).
const ATTACK_INTERVAL := 0.8
const ATTACK_DAMAGE := 6.0

# Conjuração: dano principal — exige ficar PARADO; mover interrompe.
const CAST_TIME := 1.1
const CAST_DAMAGE := 28.0

var arena_rect := Rect2()
var hp := MAX_HP
var target: Node2D = null

var _attack_cd := 0.0
var _cast_progress := 0.0
var _casting := false
var _interrupt_timer := 0.0
var _alive := true


func _process(delta: float) -> void:
	if not _alive:
		return
	var moving := _handle_movement(delta)
	_handle_autoattack(delta)
	_handle_cast(delta, moving)
	if _interrupt_timer > 0.0:
		_interrupt_timer -= delta
	if target == null or not is_instance_valid(target):
		_acquire_nearest()
	queue_redraw()


func _handle_movement(delta: float) -> bool:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	var moving := dir != Vector2.ZERO
	if moving:
		position += dir.normalized() * SPEED * delta
		if arena_rect.size != Vector2.ZERO:
			position.x = clampf(position.x, arena_rect.position.x + RADIUS, arena_rect.end.x - RADIUS)
			position.y = clampf(position.y, arena_rect.position.y + RADIUS, arena_rect.end.y - RADIUS)
	return moving


func _handle_autoattack(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if not _has_valid_target_in_range():
		return
	if _attack_cd == 0.0:
		_attack_cd = ATTACK_INTERVAL
		target.take_damage(ATTACK_DAMAGE)


func _handle_cast(delta: float, moving: bool) -> void:
	if moving or not _has_valid_target_in_range():
		if _casting and _cast_progress > 0.15:
			_interrupt_timer = 0.35  # feedback visual de interrupção
		_casting = false
		_cast_progress = 0.0
		return
	_casting = true
	_cast_progress += delta
	if _cast_progress >= CAST_TIME:
		_cast_progress = 0.0
		target.take_damage(CAST_DAMAGE)


func _has_valid_target_in_range() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("take_damage"):
		return false
	return position.distance_to(target.position) <= ATTACK_RANGE


func cycle_target() -> void:
	var list := _targetables()
	if list.is_empty():
		target = null
		return
	var idx := list.find(target)
	target = list[(idx + 1) % list.size()]


func _acquire_nearest() -> void:
	var list := _targetables()
	var best: Node2D = null
	var best_d := INF
	for t: Node2D in list:
		var d := position.distance_to(t.position)
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


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		_alive = false
		died.emit()
	queue_redraw()


func _draw() -> void:
	# Marcador de alvo + linha de auto-attack (feedback do tab-target).
	if _alive and target != null and is_instance_valid(target):
		var to_target := target.position - position
		draw_arc(to_target, 34.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.3, 0.9), 2.0)
		if to_target.length() <= ATTACK_RANGE:
			draw_line(Vector2.ZERO, to_target, Color(0.6, 0.9, 1.0, 0.28), 2.0)

	# Corpo do jogador.
	var body_color := Color(0.35, 0.7, 1.0) if _alive else Color(0.4, 0.4, 0.45)
	draw_circle(Vector2.ZERO, RADIUS, body_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color(0.9, 0.95, 1.0), 2.0)

	_draw_cast_bar()
	_draw_hp_bar()


func _draw_cast_bar() -> void:
	if not _alive:
		return
	var w := 46.0
	var h := 5.0
	var off := Vector2(-w / 2.0, RADIUS + 8.0)
	if _casting and _cast_progress > 0.0:
		draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
		draw_rect(Rect2(off, Vector2(w * (_cast_progress / CAST_TIME), h)), Color(0.4, 0.85, 1.0), true)
	elif _interrupt_timer > 0.0:
		draw_rect(Rect2(off, Vector2(w, h)), Color(1.0, 0.3, 0.3, 0.85), true)


func _draw_hp_bar() -> void:
	var w := 40.0
	var h := 5.0
	var off := Vector2(-w / 2.0, -RADIUS - 12.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (hp / MAX_HP), h)), Color(0.4, 1.0, 0.5), true)
