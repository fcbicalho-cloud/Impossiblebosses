extends Node2D
class_name Boss
## Boss simples de protótipo.
##
## Uma única mecânica: um AoE telegrafado no chão (círculo vermelho que cresce
## durante o aviso) e, ao fim do telégrafo, detona — quem estiver dentro leva
## dano. É o "saia do fogo", a mecânica-núcleo do gênero. O AoE mira na posição
## do jogador no início do aviso, dando tempo de sair.

signal died

const MAX_HP := 450.0
const RADIUS := 30.0

const AOE_TELEGRAPH := 1.3   # segundos de aviso antes de detonar
const AOE_RADIUS := 90.0
const AOE_DAMAGE := 35.0
const AOE_COOLDOWN := 2.6    # segundos entre um ataque e o próximo

var arena_rect := Rect2()
var hp := MAX_HP
var player: Node2D = null

var _alive := true
var _aoe_active := false
var _aoe_timer := 0.0
var _aoe_pos := Vector2.ZERO
var _cooldown := 1.5  # respiro inicial antes do primeiro ataque


func _process(delta: float) -> void:
	if not _alive:
		return
	if _aoe_active:
		_aoe_timer -= delta
		if _aoe_timer <= 0.0:
			_detonate_aoe()
	else:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_start_aoe()
	queue_redraw()


func _start_aoe() -> void:
	if player != null and is_instance_valid(player):
		_aoe_pos = player.position
	else:
		_aoe_pos = arena_rect.get_center()
	_aoe_active = true
	_aoe_timer = AOE_TELEGRAPH


func _detonate_aoe() -> void:
	_aoe_active = false
	_cooldown = AOE_COOLDOWN
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		if player.position.distance_to(_aoe_pos) <= AOE_RADIUS:
			player.take_damage(AOE_DAMAGE)


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		_alive = false
		died.emit()
	queue_redraw()


func _draw() -> void:
	# AoE telegrafado (coordenadas locais, relativas ao boss).
	if _aoe_active:
		var local := _aoe_pos - position
		var frac := 1.0 - (_aoe_timer / AOE_TELEGRAPH)  # 0 -> 1 conforme detona
		draw_circle(local, AOE_RADIUS, Color(1.0, 0.2, 0.2, 0.16))
		draw_circle(local, AOE_RADIUS * frac, Color(1.0, 0.25, 0.2, 0.35))
		draw_arc(local, AOE_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, 0.9), 2.5)

	# Corpo do boss.
	var body_color := Color(0.82, 0.3, 0.35) if _alive else Color(0.45, 0.3, 0.32)
	draw_circle(Vector2.ZERO, RADIUS, body_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(1.0, 0.8, 0.8), 3.0)

	_draw_hp_bar()


func _draw_hp_bar() -> void:
	var w := 90.0
	var h := 7.0
	var off := Vector2(-w / 2.0, -RADIUS - 16.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (hp / MAX_HP), h)), Color(0.9, 0.3, 0.3), true)
