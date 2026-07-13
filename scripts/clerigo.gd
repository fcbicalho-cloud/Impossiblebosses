extends PartyMember
class_name Clerigo
## Clerigo — Healer. Jogável (humano) ou bot.
##
## Simplificação deliberada de escopo: cura sempre mira automaticamente o
## aliado com menos vida (sem seleção manual de aliado) — reduz a superfície
## de controle sem perder a decisão real, que é QUAL habilidade usar e QUANDO.
## Recurso: Mana (regenera devagar). Habilidades (teclas 1-4): Cura (cast
## parado — dano principal de cura, mover cancela), Cura Rapida (instant),
## Escudo (absorção), Ressurreição (channel; consome 1 carga do boss).

const MAX_HP_VALUE := 90.0
const SPEED := 210.0
const HEAL_RANGE := 520.0

const MANA_MAX := 100.0
const MANA_REGEN := 9.0

const CURA_CAST_TIME := 1.0
const CURA_COST := 30.0
const CURA_AMOUNT := 55.0

const RAPIDA_COOLDOWN := 2.5
const RAPIDA_COST := 15.0
const RAPIDA_AMOUNT := 22.0

const ESCUDO_COOLDOWN := 9.0
const ESCUDO_COST := 20.0
const ESCUDO_AMOUNT := 40.0

const REZ_CAST_TIME := 2.5
const REZ_COST := 40.0
const REZ_HP_FRACTION := 0.5

var mana := MANA_MAX

var _rapida_cd := 0.0
var _escudo_cd := 0.0

var _cast_kind := ""  # "" | "cura" | "rez"
var _cast_progress := 0.0
var _cast_target: PartyMember = null
var _interrupt_timer := 0.0


func _ready() -> void:
	super._ready()
	role_label = "Clerigo"
	max_hp = MAX_HP_VALUE
	hp = max_hp
	radius = 14.0


func _process(delta: float) -> void:
	if not alive:
		return
	mana = minf(MANA_MAX, mana + MANA_REGEN * delta)
	_rapida_cd = maxf(0.0, _rapida_cd - delta)
	_escudo_cd = maxf(0.0, _escudo_cd - delta)
	if _interrupt_timer > 0.0:
		_interrupt_timer -= delta

	var moving: bool
	if is_bot:
		moving = _bot_move(delta)
		_bot_decide()
	else:
		moving = _human_move(delta)

	_progress_cast(delta, moving)
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
	return false


func _progress_cast(delta: float, moving: bool) -> void:
	if _cast_kind == "":
		return
	if moving or _cast_target == null or not is_instance_valid(_cast_target):
		if _cast_progress > 0.15:
			_interrupt_timer = 0.35
		_cast_kind = ""
		_cast_progress = 0.0
		return
	_cast_progress += delta
	var needed := CURA_CAST_TIME if _cast_kind == "cura" else REZ_CAST_TIME
	if _cast_progress >= needed:
		if _cast_kind == "cura":
			_cast_target.heal(CURA_AMOUNT)
			_notify_threat(CURA_AMOUNT * 0.5)
		elif _cast_kind == "rez":
			_cast_target.revive(REZ_HP_FRACTION)
			if boss != null and is_instance_valid(boss):
				boss.rez_charges = maxi(0, boss.rez_charges - 1)
		_cast_kind = ""
		_cast_progress = 0.0
		_cast_target = null


func _notify_threat(amount: float) -> void:
	if boss != null and is_instance_valid(boss) and boss.has_method("add_threat"):
		boss.add_threat(self, amount)


## Usado pelo HUD (main.gd) para desenhar o painel de habilidades: nome,
## custo, recurso atual/máximo e cooldown restante/máximo. Cura e Rez não têm
## cooldown próprio (só custo de mana + tempo de cast), então retornam 0/0.
func get_ability_info(index: int) -> Dictionary:
	if index == 1:
		return {
			"name": "Cura",
			"cost": CURA_COST,
			"resource_current": mana,
			"resource_max": MANA_MAX,
			"cooldown_remaining": 0.0,
			"cooldown_max": 0.0,
		}
	elif index == 2:
		return {
			"name": "Cura Rapida",
			"cost": RAPIDA_COST,
			"resource_current": mana,
			"resource_max": MANA_MAX,
			"cooldown_remaining": _rapida_cd,
			"cooldown_max": RAPIDA_COOLDOWN,
		}
	elif index == 3:
		return {
			"name": "Escudo",
			"cost": ESCUDO_COST,
			"resource_current": mana,
			"resource_max": MANA_MAX,
			"cooldown_remaining": _escudo_cd,
			"cooldown_max": ESCUDO_COOLDOWN,
		}
	elif index == 4:
		return {
			"name": "Ressurreicao (%d carga)" % (boss.rez_charges if boss != null and is_instance_valid(boss) else 0),
			"cost": REZ_COST,
			"resource_current": mana,
			"resource_max": MANA_MAX,
			"cooldown_remaining": 0.0,
			"cooldown_max": 0.0,
		}
	return {}


func activate_ability(index: int) -> void:
	if not alive:
		return
	if index == 1:
		_start_cura(_lowest_hp_ally())
	elif index == 2:
		_use_rapida(_lowest_hp_ally())
	elif index == 3:
		_use_escudo(_lowest_hp_ally())
	elif index == 4:
		_start_rez(_dead_ally())


func _start_cura(t: PartyMember) -> void:
	if _cast_kind != "" or t == null or mana < CURA_COST:
		return
	mana -= CURA_COST
	_cast_kind = "cura"
	_cast_progress = 0.0
	_cast_target = t


func _use_rapida(t: PartyMember) -> void:
	if _rapida_cd > 0.0 or t == null or mana < RAPIDA_COST:
		return
	_rapida_cd = RAPIDA_COOLDOWN
	mana -= RAPIDA_COST
	t.heal(RAPIDA_AMOUNT)
	_notify_threat(RAPIDA_AMOUNT * 0.5)


func _use_escudo(t: PartyMember) -> void:
	if _escudo_cd > 0.0 or t == null or mana < ESCUDO_COST:
		return
	_escudo_cd = ESCUDO_COOLDOWN
	mana -= ESCUDO_COST
	t.add_shield(ESCUDO_AMOUNT)


func _start_rez(t: PartyMember) -> void:
	if _cast_kind != "" or t == null or mana < REZ_COST:
		return
	if boss == null or not is_instance_valid(boss) or boss.rez_charges <= 0:
		return
	mana -= REZ_COST
	_cast_kind = "rez"
	_cast_progress = 0.0
	_cast_target = t


func _bot_decide() -> void:
	if _cast_kind != "":
		return
	var dead := _dead_ally()
	if dead != null and boss != null and is_instance_valid(boss) and boss.rez_charges > 0 and mana >= REZ_COST:
		_start_rez(dead)
		return
	var weakest := _lowest_hp_ally()
	if weakest == null:
		return
	var frac: float = weakest.hp_fraction()
	if frac < 0.35:
		if _rapida_cd <= 0.0 and mana >= RAPIDA_COST:
			_use_rapida(weakest)
		elif _escudo_cd <= 0.0 and mana >= ESCUDO_COST:
			_use_escudo(weakest)
		elif mana >= CURA_COST:
			_start_cura(weakest)
	elif frac < 0.8 and mana >= CURA_COST:
		_start_cura(weakest)


func _lowest_hp_ally() -> PartyMember:
	var best: PartyMember = null
	var best_frac := INF
	for n: PartyMember in get_tree().get_nodes_in_group("party"):
		if not is_instance_valid(n) or not n.alive:
			continue
		var f: float = n.hp_fraction()
		if f < best_frac:
			best_frac = f
			best = n
	return best


func _dead_ally() -> PartyMember:
	for n: PartyMember in get_tree().get_nodes_in_group("party"):
		if is_instance_valid(n) and not n.alive:
			return n
	return null


func _draw() -> void:
	var body_color := Color(0.9, 0.9, 0.95) if alive else Color(0.4, 0.4, 0.45)
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(1.0, 0.85, 0.5), 2.0)
	if is_bot:
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.35), 1.0)

	_draw_cast_bar()
	_draw_hp_bar(40.0, 5.0, -radius - 12.0, Color(0.4, 1.0, 0.5))
	_draw_mana_bar()


func _draw_cast_bar() -> void:
	if not alive:
		return
	var w := 46.0
	var h := 5.0
	var off := Vector2(-w / 2.0, radius + 8.0)
	if _cast_kind != "" and _cast_progress > 0.0:
		var needed := CURA_CAST_TIME if _cast_kind == "cura" else REZ_CAST_TIME
		var color := Color(1.0, 0.85, 0.3) if _cast_kind == "rez" else Color(0.4, 1.0, 0.6)
		draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
		draw_rect(Rect2(off, Vector2(w * (_cast_progress / needed), h)), color, true)
	elif _interrupt_timer > 0.0:
		draw_rect(Rect2(off, Vector2(w, h)), Color(1.0, 0.3, 0.3, 0.85), true)


func _draw_mana_bar() -> void:
	var w := 40.0
	var h := 4.0
	var off := Vector2(-w / 2.0, -radius - 20.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (mana / MANA_MAX), h)), Color(0.4, 0.6, 1.0), true)
