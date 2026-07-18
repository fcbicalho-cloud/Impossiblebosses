extends PartyMember
class_name Clerigo
## Clerigo — Healer. Jogável (humano) ou bot.
##
## A cura sempre mira automaticamente o aliado com menos vida (sem seleção
## manual) — a decisão real é QUAL habilidade e QUANDO. Recurso: Mana.
## Habilidades (teclas 1-4): Cura (cast parado, forte), Cura Rápida (instant),
## Escudo (absorção), Ressurreição (channel; consome 1 carga de rez do boss).
##
## Visual: sprite 16×16 (Kenney Tiny Dungeon) escalado 3×, com balanço de idle e
## flash de dano (shader do Actor). Brilho sagrado ao conjurar, feixe até o alvo
## da cura, barras e cast bar continuam via _draw.

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
	_setup_body_sprite(preload("res://assets/characters/clerigo.png"), 3.0)


func _process(delta: float) -> void:
	_update_sprite()
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
	_draw_sprite_shadow()
	_draw_holy_glow()
	_draw_heal_beam()
	_draw_shield_overlay()
	_draw_cast_bar()
	_draw_hp_bar(40.0, 5.0, -radius - 16.0, Color(0.4, 1.0, 0.5))
	_draw_mana_bar()


## Sincroniza o Sprite2D: balanço de idle e pose de morte. O clérigo não vira
## para lados (a cura é auto-mirada), então não há flip. Roda mesmo morto.
func _update_sprite() -> void:
	if body_sprite == null:
		return
	if alive:
		body_sprite.rotation_degrees = 0.0
		body_sprite.modulate = Color.WHITE
		body_sprite.position = Vector2(0.0, -sin(anim_time * 3.2) * 1.4)
	else:
		body_sprite.rotation_degrees = 90.0
		body_sprite.modulate = Color(0.5, 0.5, 0.55)
		body_sprite.position = Vector2.ZERO


## Aura dourada sob o clérigo enquanto conjura (fica atrás do sprite).
func _draw_holy_glow() -> void:
	if not alive or _cast_kind == "":
		return
	var pulse: float = 0.10 + 0.06 * sin(anim_time * 7.0)
	draw_circle(Vector2.ZERO, radius * 1.6, Color(1.0, 0.95, 0.6, pulse))


## Feixe até o alvo da cura/rez — deixa explícito QUEM está sendo curado, que era
## invisível antes (a mira é automática, o jogador não escolhe).
func _draw_heal_beam() -> void:
	if not alive or _cast_kind == "" or _cast_target == null or not is_instance_valid(_cast_target):
		return
	var to_target: Vector2 = _cast_target.position - position
	var color := Color(1.0, 0.85, 0.3, 0.5) if _cast_kind == "rez" else Color(0.5, 1.0, 0.7, 0.45)
	draw_line(Vector2.ZERO, to_target, color, 2.0)
	draw_arc(to_target, 20.0, 0.0, TAU, 20, color, 2.0)


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
