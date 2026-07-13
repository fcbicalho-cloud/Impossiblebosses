extends Node2D
class_name Player
## "Mago" (DPS à distância) — controle local neste protótipo.
##
## Movimento WASD; auto-attack automático no alvo travado quando ele está no
## alcance. NOTA de arquitetura: por ora o input vem direto do teclado. No
## futuro isto deve virar uma "fonte de input" abstrata (input local / peer de
## rede / bot), conforme docs/ESCOPO.md, seção 6. Mantido simples de propósito.

signal died

const SPEED := 220.0
const RADIUS := 14.0
const MAX_HP := 100.0
const ATTACK_RANGE := 320.0
const ATTACK_INTERVAL := 0.8
const ATTACK_DAMAGE := 14.0

var arena_rect := Rect2()
var hp := MAX_HP
var target: Node2D = null

var _attack_cd := 0.0
var _alive := true


func _process(delta: float) -> void:
	if not _alive:
		return
	_handle_movement(delta)
	_handle_autoattack(delta)
	queue_redraw()


func _handle_movement(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if dir != Vector2.ZERO:
		position += dir.normalized() * SPEED * delta
	if arena_rect.size != Vector2.ZERO:
		position.x = clampf(position.x, arena_rect.position.x + RADIUS, arena_rect.end.x - RADIUS)
		position.y = clampf(position.y, arena_rect.position.y + RADIUS, arena_rect.end.y - RADIUS)


func _handle_autoattack(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("take_damage"):
		return
	if position.distance_to(target.position) > ATTACK_RANGE:
		return
	if _attack_cd == 0.0:
		_attack_cd = ATTACK_INTERVAL
		target.take_damage(ATTACK_DAMAGE)


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

	_draw_hp_bar()


func _draw_hp_bar() -> void:
	var w := 40.0
	var h := 5.0
	var off := Vector2(-w / 2.0, -RADIUS - 12.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (hp / MAX_HP), h)), Color(0.4, 1.0, 0.5), true)
