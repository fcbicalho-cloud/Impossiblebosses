extends PartyMember
class_name Mago
## Mago — DPS à distância. Jogável (humano) ou bot.
##
## Modelo de dano: AUTO-ATTACK fraco (funciona andando) + CONJURAÇÃO forte que
## só progride PARADO (mover interrompe e zera). Alvo de inimigo via tab-target
## (Tab cicla / clique seleciona — roteado pelo Main) ou auto-aquisição do bot.
##
## Visual: sprite 16×16 (Kenney Tiny Dungeon) escalado 3×, com flip na direção
## do alvo, balanço de idle, flash de dano (shader do Actor) e orbe de conjuração.
## Barras/retícula/sombra continuam via _draw por cima/por baixo do sprite.

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
	_setup_body_sprite(preload("res://assets/characters/mago.png"), 3.0)


func _process(delta: float) -> void:
	_update_sprite()
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
	elif is_bot:
		_bot_prioritize_adds()
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


## Bot: add na arena vira prioridade sobre o boss (ESCOPO 7.1 — "troca rápida
## para adds"). Sem isto os adds seriam ignorados pelo dps bot e a mecânica de
## repriorização não existiria no teste solo. O humano NÃO é retargetado: a
## escolha de alvo é dele.
func _bot_prioritize_adds() -> void:
	if target is Add:
		return
	var best: Add = null
	var best_d := INF
	for a: Add in get_tree().get_nodes_in_group("add"):
		if not is_instance_valid(a) or not a.alive:
			continue
		var d: float = position.distance_to(a.position)
		if d < best_d:
			best_d = d
			best = a
	if best != null:
		target = best


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

	_draw_sprite_shadow()
	_draw_cast_glow()
	_draw_shield_overlay()
	_draw_cast_bar()
	_draw_hp_bar(40.0, 5.0, -radius - 14.0, Color(0.4, 1.0, 0.5))


## Sincroniza o Sprite2D com o estado do jogo: flip na direção do alvo, balanço
## de idle e pose de morte (deitado + acinzentado). Roda mesmo morto, por isso é
## chamado antes do early-return do _process.
func _update_sprite() -> void:
	if body_sprite == null:
		return
	if alive:
		body_sprite.rotation_degrees = 0.0
		body_sprite.modulate = Color.WHITE
		body_sprite.position = Vector2(0.0, -sin(anim_time * 3.5) * 1.5)
		if absf(_facing.x) > 0.1:
			body_sprite.flip_h = _facing.x < 0.0
	else:
		body_sprite.rotation_degrees = 90.0
		body_sprite.modulate = Color(0.5, 0.5, 0.55)
		body_sprite.position = Vector2.ZERO


## Orbe de conjuração pulsando à frente do mago (o cajado do sprite é estático;
## o feedback de "estou conjurando" vem deste brilho + cast bar).
func _draw_cast_glow() -> void:
	if not alive or not _casting:
		return
	var fdir := _facing
	if fdir.length() < 0.1:
		fdir = Vector2(0.0, 1.0)
	var tip: Vector2 = fdir.normalized() * (radius + 6.0)
	var pulse: float = 0.7 + 0.2 * sin(anim_time * 10.0)
	draw_circle(tip, radius * 0.4, Color(0.5, 0.9, 1.0, 0.3))
	draw_circle(tip, radius * 0.2, Color(0.6, 0.95, 1.0, pulse))


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
