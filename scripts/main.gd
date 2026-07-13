extends Node2D
## Protótipo M1 — trindade (tank/healer/dps) contra um boss com fases.
##
## Tela inicial: escolha qual papel você controla (1 Guardiao / 2 Clerigo /
## 3 Mago); os outros dois viram bots. R volta pra essa tela a qualquer
## momento, então dá pra testar os 3 papéis sem reiniciar o jogo.
##
## Escopo do protótipo (docs/ESCOPO.md, seção 8): threat/aggro, cura+mana e
## 1 combat-rez por boss já existem; balanceamento é só um primeiro palpite.

const ARENA_RECT := Rect2(60, 60, 840, 500)
const BOSS_POS := Vector2(480, 200)
const TANK_START := Vector2(480, 255)
const HEALER_START := Vector2(340, 460)
const MAGO_START := Vector2(620, 460)

var state := "select"  # "select" | "playing" | "won" | "lost"
var human_role := ""   # "tank" | "healer" | "dps"

var boss: Boss
var party: Array = []       # [Guardiao, Clerigo, Mago]
var human_unit = null       # Guardiao | Clerigo | Mago — sem tipo fixo de propósito

var _world: Node2D  # container de entidades transitórias (projéteis, adds)
var _status_label: Label
var _hint_label: Label
var _flash_label: Label
var _flash_timer := 0.0


func _ready() -> void:
	_build_hud()
	_world = Node2D.new()
	add_child(_world)
	_show_select()


func _show_select() -> void:
	state = "select"
	_clear_encounter()
	if _status_label:
		_status_label.text = ""
	if _flash_label:
		_flash_label.text = ""


func _clear_encounter() -> void:
	for m in party:
		if is_instance_valid(m):
			m.queue_free()
	party.clear()
	human_unit = null
	if is_instance_valid(boss):
		boss.queue_free()
	_clear_world()


func _clear_world() -> void:
	if _world == null:
		return
	for child in _world.get_children():
		child.queue_free()


func _start_encounter() -> void:
	state = "playing"
	_clear_encounter()

	boss = Boss.new()
	boss.arena_rect = ARENA_RECT
	boss.position = BOSS_POS
	boss.entity_parent = _world
	boss.died.connect(_on_boss_died)
	boss.phase_changed.connect(_on_phase_changed)
	add_child(boss)

	var guardiao := Guardiao.new()
	guardiao.arena_rect = ARENA_RECT
	guardiao.position = TANK_START
	guardiao.boss = boss
	guardiao.is_bot = human_role != "tank"
	guardiao.died.connect(_on_member_died)
	add_child(guardiao)
	party.append(guardiao)

	var clerigo := Clerigo.new()
	clerigo.arena_rect = ARENA_RECT
	clerigo.position = HEALER_START
	clerigo.boss = boss
	clerigo.is_bot = human_role != "healer"
	clerigo.died.connect(_on_member_died)
	add_child(clerigo)
	party.append(clerigo)

	var mago := Mago.new()
	mago.arena_rect = ARENA_RECT
	mago.position = MAGO_START
	mago.boss = boss
	mago.is_bot = human_role != "dps"
	mago.target = boss
	mago.died.connect(_on_member_died)
	add_child(mago)
	party.append(mago)

	match human_role:
		"tank":
			human_unit = guardiao
		"healer":
			human_unit = clerigo
		"dps":
			human_unit = mago

	if _status_label:
		_status_label.text = ""
	if _flash_label:
		_flash_label.text = ""
	_flash_timer = 0.0


func _process(delta: float) -> void:
	_update_hint()
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _flash_label:
			_flash_label.text = ""
	if state == "playing":
		_check_wipe()


func _check_wipe() -> void:
	for m in party:
		if is_instance_valid(m) and m.alive:
			return
	state = "lost"
	_status_label.text = "DERROTA (wipe)"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if human_unit is Mago:
			_try_click_target(get_global_mouse_position())


func _handle_key(keycode: int) -> void:
	if keycode == KEY_R:
		_show_select()
		return

	if state == "select":
		if keycode == KEY_1:
			human_role = "tank"
			_start_encounter()
		elif keycode == KEY_2:
			human_role = "healer"
			_start_encounter()
		elif keycode == KEY_3:
			human_role = "dps"
			_start_encounter()
		return

	if state != "playing" or human_unit == null or not is_instance_valid(human_unit):
		return

	if keycode == KEY_TAB:
		if human_unit is Mago:
			human_unit.cycle_target()
		get_viewport().set_input_as_handled()
	elif keycode == KEY_1 and human_unit.has_method("activate_ability"):
		human_unit.activate_ability(1)
	elif keycode == KEY_2 and human_unit.has_method("activate_ability"):
		human_unit.activate_ability(2)
	elif keycode == KEY_3 and human_unit.has_method("activate_ability"):
		human_unit.activate_ability(3)
	elif keycode == KEY_4 and human_unit.has_method("activate_ability"):
		human_unit.activate_ability(4)


func _try_click_target(world_pos: Vector2) -> void:
	if not (human_unit is Mago):
		return
	var best = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("targetable"):
		if not is_instance_valid(n):
			continue
		var r := 20.0
		if n.has_method("pick_radius"):
			r = n.pick_radius()
		var d: float = world_pos.distance_to(n.position)
		if d <= r and d < best_d:
			best_d = d
			best = n
	if best != null:
		human_unit.target = best


func _on_boss_died() -> void:
	if state != "playing":
		return
	state = "won"
	_clear_world()
	_status_label.text = "VITORIA!"
	_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))


func _on_member_died(_unused = null) -> void:
	pass  # o wipe é checado a cada frame em _check_wipe()


func _on_phase_changed(new_phase: int) -> void:
	if state != "playing" or new_phase <= 1:
		return
	if _flash_label:
		_flash_label.text = "FASE %d!" % new_phase
	_flash_timer = 1.6


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_status_label = Label.new()
	_status_label.position = Vector2(ARENA_RECT.position.x, 14)
	_status_label.add_theme_font_size_override("font_size", 30)
	layer.add_child(_status_label)

	_flash_label = Label.new()
	_flash_label.position = Vector2(ARENA_RECT.get_center().x - 70.0, 150.0)
	_flash_label.add_theme_font_size_override("font_size", 40)
	_flash_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	layer.add_child(_flash_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(ARENA_RECT.position.x, ARENA_RECT.end.y + 8)
	_hint_label.add_theme_font_size_override("font_size", 15)
	layer.add_child(_hint_label)


func _update_hint() -> void:
	if _hint_label == null:
		return
	if state == "select":
		_hint_label.text = "Escolha seu papel:   1 = Guardiao (Tank)    2 = Clerigo (Healer)    3 = Mago (DPS)\nOs outros dois viram bots. R volta pra essa tela a qualquer momento."
		return
	if state == "won":
		_hint_label.text = "Voce venceu! Pressione R para escolher papel de novo."
		return
	if state == "lost":
		_hint_label.text = "Pressione R para tentar de novo (ou trocar de papel)."
		return

	var members_txt := ""
	for m in party:
		if is_instance_valid(m):
			if members_txt != "":
				members_txt += "   "
			members_txt += _member_summary(m)
	var boss_txt := ""
	if is_instance_valid(boss):
		boss_txt = "Boss: %d HP  Fase %d  Rez: %d" % [int(round(boss.hp)), boss.phase, boss.rez_charges]
	_hint_label.text = "%s\n%s   |   %s\n%s" % [_control_hint(), members_txt, boss_txt, _format_ability_line()]


func _member_summary(m: PartyMember) -> String:
	var tag := "(bot)" if m.is_bot else "(voce)"
	var hp_txt := "%d/%d" % [int(round(m.hp)), int(round(m.max_hp))]
	if m is Guardiao:
		var g := m as Guardiao
		return "Guardiao %s %s HP, Ira %d" % [tag, hp_txt, int(round(g.ira))]
	elif m is Clerigo:
		var c := m as Clerigo
		return "Clerigo %s %s HP, Mana %d" % [tag, hp_txt, int(round(c.mana))]
	elif m is Mago:
		return "Mago %s %s HP" % [tag, hp_txt]
	return "%s %s" % [tag, hp_txt]


func _control_hint() -> String:
	if human_role == "tank":
		return "WASD mover | auto-attack automatico em alcance no boss"
	elif human_role == "healer":
		return "WASD mover | cura sempre mira o aliado com menos vida"
	elif human_role == "dps":
		return "WASD mover | PARADO = conjura (dano principal) | Tab/clique = alvo"
	return ""


## Linha de habilidades: cooldown restante e custo de cada tecla, ou (pro
## Mago, que não tem tecla de habilidade) o estado da conjuração.
func _format_ability_line() -> String:
	if human_unit == null or not is_instance_valid(human_unit):
		return ""
	if human_unit.has_method("get_ability_info"):
		var parts := ""
		for i in range(1, 5):
			var info: Dictionary = human_unit.get_ability_info(i)
			if info.is_empty():
				continue
			if parts != "":
				parts += "   "
			parts += _format_ability_slot(i, info)
		return parts
	elif human_unit.has_method("get_cast_status"):
		var status: Dictionary = human_unit.get_cast_status()
		return _format_cast_status(status)
	return ""


func _format_ability_slot(index: int, info: Dictionary) -> String:
	var ability_name: String = info.get("name", "?")
	var cost: float = info.get("cost", 0.0)
	var resource_current: float = info.get("resource_current", 0.0)
	var cd_remaining: float = info.get("cooldown_remaining", 0.0)
	var status_txt := "pronto"
	if cd_remaining > 0.05:
		status_txt = "%.1fs" % cd_remaining
	elif cost > 0.0 and resource_current < cost:
		status_txt = "sem recurso"
	var cost_txt := ""
	if cost > 0.0:
		cost_txt = " (custo %d)" % int(round(cost))
	return "[%d] %s%s: %s" % [index, ability_name, cost_txt, status_txt]


func _format_cast_status(status: Dictionary) -> String:
	var casting: bool = status.get("casting", false)
	var interrupted: bool = status.get("interrupted", false)
	if casting:
		var progress: float = status.get("progress", 0.0)
		var cast_time: float = status.get("cast_time", 1.0)
		var pct := 0
		if cast_time > 0.0:
			pct = int(round(100.0 * progress / cast_time))
		return "Conjurando: %d%%" % pct
	elif interrupted:
		return "Conjuracao interrompida!"
	return "Pronto pra conjurar (fique parado no alvo)"


func _draw() -> void:
	draw_rect(ARENA_RECT, Color(0.14, 0.15, 0.19), true)
	draw_rect(ARENA_RECT, Color(0.48, 0.53, 0.68), false, 3.0)
