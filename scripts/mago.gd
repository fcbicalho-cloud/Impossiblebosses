extends PartyMember
class_name Mago
## Mago — DPS à distância. Jogável (humano) ou bot.
##
## Modelo de dano: AUTO-ATTACK fraco (funciona andando) + CONJURAÇÃO forte que
## só progride PARADO (mover interrompe e zera). Alvo de inimigo via tab-target
## (Tab cicla / clique seleciona — roteado pelo Main) ou auto-aquisição do bot.
## Dano ao boss gera threat (ver PartyMember.boss / Boss.add_threat).

const ATTACK_RANGE := 320.0
const ATTACK_INTERVAL := 0.8
const ATTACK_DAMAGE := 6.0
const CAST_TIME := 1.1
const CAST_DAMAGE := 28.0
const SPEED := 220.0

var target = null  # Boss ou Add (inimigos) — sem tipo fixo de propósito

const RETARGET_INTERVAL := 0.5

var _attack_cd := 0.0
var _cast_progress := 0.0
var _casting := false
var _interrupt_timer := 0.0
var _retarget_cd := 0.0


func _ready() -> void:
	super._ready()
	role_label = "Mago"
	max_hp = 100.0
	hp = max_hp
	radius = 14.0


func _process(delta: float) -> void:
	if not alive:
		return
	var moving: bool
	if is_bot:
		_retarget_cd -= delta
		if _retarget_cd <= 0.0:
			_retarget_cd = RETARGET_INTERVAL
			_bot_retarget()
		moving = _bot_move(delta)
	else:
		moving = _human_move(delta)
	_handle_autoattack(delta)
	_handle_cast(delta, moving)
	if _interrupt_timer > 0.0:
		_interrupt_timer -= delta
	if target == null or not is_instance_valid(target):
		_acquire_nearest_enemy()
	queue_redraw()


## Bot: prioriza matar Adds vivos sobre bater no Boss (troca de alvo real, não
## só na morte do alvo atual). Reavaliado a cada RETARGET_INTERVAL, não todo
## frame, pra evitar ficar trocando de alvo o tempo todo.
func _bot_retarget() -> void:
	if target != null and is_instance_valid(target) and target is Add:
		return  # já está limpando um add, mantém até ele morrer
	var nearest_add := _nearest_add()
	if nearest_add != null:
		target = nearest_add
	elif target == null or not is_instance_valid(target):
		_acquire_nearest_enemy()


func _nearest_add() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n: Node2D in get_tree().get_nodes_in_group("add"):
		if not is_instance_valid(n):
			continue
		var d: float = position.distance_to(n.position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _human_move(delta: float) -> bool:
	var dir := _read_wasd()
	var moving := dir != Vector2.ZERO
	if moving:
		position += dir.normalized() * SPEED * delta
		_clamp_to_arena()
	return moving


func _bot_move(delta: float) -> bool:
	if target == null or not is_instance_valid(target):
		_acquire_nearest_enemy()
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
	if not _has_valid_target_in_range():
		return
	if _attack_cd == 0.0:
		_attack_cd = ATTACK_INTERVAL
		target.take_damage(ATTACK_DAMAGE)
		_notify_threat(ATTACK_DAMAGE)


func _handle_cast(delta: float, moving: bool) -> void:
	if moving or not _has_valid_target_in_range():
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


func _has_valid_target_in_range() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("take_damage"):
		return false
	return position.distance_to(target.position) <= ATTACK_RANGE


## Usado pelo HUD (main.gd) — o Mago não tem habilidades ativadas por tecla,
## então o painel mostra o estado da conjuração em vez de custo/cooldown.
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


func _draw() -> void:
	if alive and target != null and is_instance_valid(target):
		var to_target: Vector2 = target.position - position
		draw_arc(to_target, 34.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.3, 0.9), 2.0)
		if to_target.length() <= ATTACK_RANGE:
			draw_line(Vector2.ZERO, to_target, Color(0.6, 0.9, 1.0, 0.28), 2.0)

	var body_color := Color(0.35, 0.7, 1.0) if alive else Color(0.4, 0.4, 0.45)
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.9, 0.95, 1.0), 2.0)
	if is_bot:
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.35), 1.0)

	_draw_cast_bar()
	_draw_hp_bar(40.0, 5.0, -radius - 12.0, Color(0.4, 1.0, 0.5))


func _draw_cast_bar() -> void:
	if not alive:
		return
	var w := 46.0
	var h := 5.0
	var off := Vector2(-w / 2.0, radius + 8.0)
	if _casting and _cast_progress > 0.0:
		draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
		draw_rect(Rect2(off, Vector2(w * (_cast_progress / CAST_TIME), h)), Color(0.4, 0.85, 1.0), true)
	elif _interrupt_timer > 0.0:
		draw_rect(Rect2(off, Vector2(w, h)), Color(1.0, 0.3, 0.3, 0.85), true)
