extends PartyMember
class_name Guardiao
## Guardiao — Tank. Jogável (humano) ou bot.
##
## Fica no alcance corpo-a-corpo do boss e o ataca constantemente (funciona
## andando, diferente do Mago), gerando MUITO threat por dano causado, para
## "segurar" o boss. Recurso: Ira (ganha ao bater e ao apanhar; gasta em
## Muralha). Habilidades: Provocar (taunt, tecla 1) e Muralha (mitigação, 2).
##
## Visual procedural: cavaleiro com elmo, escudo e espada, olha pro boss.

const MAX_HP_VALUE := 160.0
const MELEE_RANGE := 70.0
const SPEED := 200.0

const ATTACK_INTERVAL := 1.0
const ATTACK_DAMAGE := 16.0
const THREAT_MULTIPLIER := 3.0
const IRA_MAX := 100.0
const IRA_PER_HIT := 8.0
const IRA_PER_DAMAGE_TAKEN := 0.4

const TAUNT_COOLDOWN := 8.0
const MURALHA_COOLDOWN := 10.0
const MURALHA_DURATION := 3.0
const MURALHA_IRA_COST := 30.0
const MURALHA_MITIGATION := 0.5  # reduz o dano recebido pela metade

var ira := 0.0

var _attack_cd := 0.0
var _taunt_cd := 0.0
var _muralha_cd := 0.0
var _muralha_timer := 0.0
var _facing := Vector2(0.0, -1.0)


func _ready() -> void:
	super._ready()
	role_label = "Guardiao"
	max_hp = MAX_HP_VALUE
	hp = max_hp
	radius = 15.0


func _process(delta: float) -> void:
	if not alive:
		return
	_tick_visuals(delta)
	if is_bot:
		_bot_process(delta)
	else:
		_human_process(delta)
	_handle_autoattack(delta)
	_tick_cooldowns(delta)
	if boss != null and is_instance_valid(boss):
		var bv: Vector2 = boss.position - position
		if bv.length() > 1.0:
			_facing = bv.normalized()
	queue_redraw()


func _human_process(delta: float) -> void:
	var dir := _read_wasd()
	if dir != Vector2.ZERO:
		position += dir.normalized() * SPEED * delta
		_clamp_to_arena()


func _bot_process(delta: float) -> void:
	if boss != null and is_instance_valid(boss):
		var d: float = position.distance_to(boss.position)
		if d > MELEE_RANGE * 0.8:
			var dir: Vector2 = (boss.position - position).normalized()
			position += dir * SPEED * delta
			_clamp_to_arena()
	if not _is_boss_target() and _taunt_cd <= 0.0:
		_use_taunt()
	elif hp_fraction() < 0.6 and _muralha_cd <= 0.0 and ira >= MURALHA_IRA_COST:
		_use_muralha()


func _tick_cooldowns(delta: float) -> void:
	_taunt_cd = maxf(0.0, _taunt_cd - delta)
	_muralha_cd = maxf(0.0, _muralha_cd - delta)
	if _muralha_timer > 0.0:
		_muralha_timer -= delta


func _handle_autoattack(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if boss == null or not is_instance_valid(boss):
		return
	if position.distance_to(boss.position) > MELEE_RANGE:
		return
	if _attack_cd == 0.0:
		_attack_cd = ATTACK_INTERVAL
		boss.take_damage(ATTACK_DAMAGE)
		ira = minf(IRA_MAX, ira + IRA_PER_HIT)
		if boss.has_method("add_threat"):
			boss.add_threat(self, ATTACK_DAMAGE * THREAT_MULTIPLIER)


func activate_ability(index: int) -> void:
	if not alive:
		return
	if index == 1:
		_use_taunt()
	elif index == 2:
		_use_muralha()


func get_ability_info(index: int) -> Dictionary:
	if index == 1:
		return {"name": "Provocar", "cost": 0.0, "cd_remaining": _taunt_cd}
	elif index == 2:
		return {"name": "Muralha", "cost": MURALHA_IRA_COST, "cd_remaining": _muralha_cd}
	return {}


func _use_taunt() -> void:
	if _taunt_cd > 0.0:
		return
	_taunt_cd = TAUNT_COOLDOWN
	if boss != null and is_instance_valid(boss) and boss.has_method("taunt"):
		boss.taunt(self)


func _use_muralha() -> void:
	if _muralha_cd > 0.0 or ira < MURALHA_IRA_COST:
		return
	_muralha_cd = MURALHA_COOLDOWN
	ira -= MURALHA_IRA_COST
	_muralha_timer = MURALHA_DURATION


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	var final_amount := amount
	if _muralha_timer > 0.0:
		final_amount *= (1.0 - MURALHA_MITIGATION)
	ira = minf(IRA_MAX, ira + final_amount * IRA_PER_DAMAGE_TAKEN)
	super.take_damage(final_amount)


func _draw() -> void:
	if _is_boss_target():
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 22, Color(1.0, 0.3, 0.3, 0.9), 2.5)
	_draw_character()
	_draw_shield_overlay()
	_draw_hp_bar(48.0, 6.0, -radius - 16.0, Color(0.9, 0.75, 0.3))
	_draw_ira_bar()


func _draw_character() -> void:
	var dead := not alive
	var bob := 0.0 if dead else sin(anim_time * 3.0) * 1.2
	var side := 1.0 if _facing.x >= 0.0 else -1.0  # escudo do lado oposto ao facing

	# Sombra.
	draw_set_transform(Vector2(0.0, radius * 0.95), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2(0.0, -bob), 0.0, Vector2.ONE)

	var steel := _flash_mix(Color(0.68, 0.71, 0.78) if not dead else Color(0.45, 0.45, 0.5))
	var steel_dark := _flash_mix(Color(0.46, 0.49, 0.57) if not dead else Color(0.36, 0.36, 0.42))
	var gold := _flash_mix(Color(0.85, 0.7, 0.3) if not dead else Color(0.5, 0.48, 0.42))
	var w := radius

	# Corpo (armadura).
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w * 0.9, radius), Vector2(w * 0.9, radius),
		Vector2(w * 0.7, -radius * 0.2), Vector2(-w * 0.7, -radius * 0.2),
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w * 0.9, radius), Vector2(0.0, radius),
		Vector2(0.0, -radius * 0.2), Vector2(-w * 0.7, -radius * 0.2),
	]), steel_dark)

	# Elmo.
	var head := Vector2(0.0, -radius * 0.55)
	draw_circle(head, radius * 0.44, steel)
	draw_rect(Rect2(head + Vector2(-radius * 0.34, -radius * 0.06), Vector2(radius * 0.68, radius * 0.12)), Color(0.08, 0.08, 0.12))
	# Penacho.
	draw_line(head + Vector2(0.0, -radius * 0.42), head + Vector2(0.0, -radius * 0.95), gold, 3.0)

	# Espada (lado do facing).
	var sx := side * w * 0.95
	draw_line(Vector2(sx, radius * 0.4), Vector2(sx, -radius * 1.25), steel_dark, 3.0)
	draw_line(Vector2(sx - radius * 0.25, radius * 0.35), Vector2(sx + radius * 0.25, radius * 0.35), gold, 3.0)

	# Escudo (lado oposto).
	var shx := -side * w * 0.85
	draw_colored_polygon(PackedVector2Array([
		Vector2(shx - radius * 0.4, -radius * 0.35),
		Vector2(shx + radius * 0.4, -radius * 0.35),
		Vector2(shx + radius * 0.4, radius * 0.35),
		Vector2(shx, radius * 0.65),
		Vector2(shx - radius * 0.4, radius * 0.35),
	]), steel)
	draw_circle(Vector2(shx, radius * 0.1), radius * 0.16, gold)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ira_bar() -> void:
	var w := 40.0
	var h := 4.0
	var off := Vector2(-w / 2.0, radius + 10.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (ira / IRA_MAX), h)), Color(0.9, 0.4, 0.2), true)
