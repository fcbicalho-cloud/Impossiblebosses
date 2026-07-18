extends PartyMember
class_name Clerigo
## Clerigo — Healer. Jogável (humano) ou bot.
##
## A cura sempre mira automaticamente o aliado com menos vida (sem seleção
## manual) — a decisão real é QUAL habilidade e QUANDO. Recurso: Mana.
## Habilidades (teclas 1-4): Cura (cast parado, forte), Cura Rápida (instant),
## Escudo (absorção), Ressurreição (channel; consome 1 carga de rez do boss).
##
## Visual procedural: clérigo de robe clara com auréola e cajado com gema;
## brilho sagrado ao conjurar.

const MAX_HP_VALUE := 90.0
const SPEED := 210.0

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
	_tick_visuals(delta)
	mana = minf(MANA_MAX, mana + MANA_REGEN * delta)
	_rapida_cd = maxf(0.0, _rapida_cd - delta)
	_escudo_cd = maxf(0.0, _escudo_cd - delta)
	if _interrupt_timer > 0.0:
		_interrupt_timer -= delta

	var moving := _bot_move(delta) if is_bot else _human_move(delta)
	if is_bot:
		_bot_decide()
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
		elif _cast_kind == "rez":
			_cast_target.revive(REZ_HP_FRACTION)
			if boss != null and is_instance_valid(boss):
				boss.rez_charges = maxi(0, boss.rez_charges - 1)
		_cast_kind = ""
		_cast_progress = 0.0
		_cast_target = null


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


func get_ability_info(index: int) -> Dictionary:
	if index == 1:
		return {"name": "Cura", "cost": CURA_COST, "cd_remaining": 0.0}
	elif index == 2:
		return {"name": "Cura Rapida", "cost": RAPIDA_COST, "cd_remaining": _rapida_cd}
	elif index == 3:
		return {"name": "Escudo", "cost": ESCUDO_COST, "cd_remaining": _escudo_cd}
	elif index == 4:
		return {"name": "Rez", "cost": REZ_COST, "cd_remaining": 0.0}
	return {}


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


## Bot: prioriza (1) rez de morto; (2) crítico <0.3 usa o que houver; (3)
## moderado 0.3-0.6 prefere Cura Rápida; (4) preventivo (mana>60%, nada urgente)
## escuda quem o boss está batendo agora; (5) sobra: Cura reservada pra <0.7.
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

	if frac < 0.3:
		if _rapida_cd <= 0.0 and mana >= RAPIDA_COST:
			_use_rapida(weakest)
		elif _escudo_cd <= 0.0 and mana >= ESCUDO_COST:
			_use_escudo(weakest)
		elif mana >= CURA_COST:
			_start_cura(weakest)
		return

	if frac < 0.6:
		if _rapida_cd <= 0.0 and mana >= RAPIDA_COST:
			_use_rapida(weakest)
		elif mana >= CURA_COST:
			_start_cura(weakest)
		return

	if mana >= MANA_MAX * 0.6 and _escudo_cd <= 0.0:
		var tanked := _current_boss_target()
		if tanked != null and tanked.shield <= 0.0:
			_use_escudo(tanked)
			return

	if frac < 0.7 and mana >= CURA_COST:
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


func _current_boss_target() -> PartyMember:
	if boss == null or not is_instance_valid(boss) or not boss.has_method("current_target"):
		return null
	var t: PartyMember = boss.current_target()
	return t


func _draw() -> void:
	_draw_character()
	_draw_shield_overlay()
	_draw_cast_bar()
	_draw_hp_bar(40.0, 5.0, -radius - 16.0, Color(0.4, 1.0, 0.5))
	_draw_mana_bar()


func _draw_character() -> void:
	var dead := not alive
	var bob := 0.0 if dead else sin(anim_time * 3.2) * 1.4

	# Sombra.
	draw_set_transform(Vector2(0.0, radius * 0.95), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2(0.0, -bob), 0.0, Vector2.ONE)

	# Brilho sagrado ao conjurar.
	if _cast_kind != "" and not dead:
		draw_circle(Vector2.ZERO, radius * 1.5, Color(1.0, 0.95, 0.6, 0.12))

	var robe := _flash_mix(Color(0.92, 0.90, 0.82) if not dead else Color(0.5, 0.5, 0.52))
	var robe_dark := _flash_mix(Color(0.75, 0.72, 0.62) if not dead else Color(0.4, 0.4, 0.44))
	var skin := _flash_mix(Color(0.96, 0.86, 0.74) if not dead else Color(0.5, 0.5, 0.52))
	var gold := _flash_mix(Color(0.85, 0.70, 0.30) if not dead else Color(0.5, 0.48, 0.42))
	var w := radius

	# Robe.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, radius), Vector2(w, radius),
		Vector2(w * 0.5, -radius * 0.15), Vector2(-w * 0.5, -radius * 0.15),
	]), robe)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, radius), Vector2(0.0, radius),
		Vector2(0.0, -radius * 0.15), Vector2(-w * 0.5, -radius * 0.15),
	]), robe_dark)
	# Estola dourada.
	draw_line(Vector2(-radius * 0.2, -radius * 0.15), Vector2(-radius * 0.2, radius), gold, 2.0)
	draw_line(Vector2(radius * 0.2, -radius * 0.15), Vector2(radius * 0.2, radius), gold, 2.0)

	# Cabeça + auréola.
	var head := Vector2(0.0, -radius * 0.55)
	draw_circle(head, radius * 0.42, skin)
	draw_arc(head + Vector2(0.0, -radius * 0.5), radius * 0.42, 0.0, TAU, 20, gold, 2.5)

	# Cajado com gema (mão direita).
	var top := Vector2(radius * 0.85, -radius * 1.2)
	draw_line(Vector2(radius * 0.85, radius * 0.5), top, gold, 2.5)
	var gem_pulse := 0.9 if _cast_kind != "" else (0.6 + 0.15 * sin(anim_time * 5.0))
	draw_circle(top, radius * 0.16, Color(0.5, 0.9, 1.0, gem_pulse))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cast_bar() -> void:
	if not alive:
		return
	var w := 46.0
	var h := 5.0
	var off := Vector2(-w / 2.0, radius + 10.0)
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
	var off := Vector2(-w / 2.0, -radius - 22.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (mana / MANA_MAX), h)), Color(0.4, 0.6, 1.0), true)
