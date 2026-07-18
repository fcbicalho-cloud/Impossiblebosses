extends Node2D
## Orquestrador do jogo (reconstrução limpa).
##
## Dono da arena, da máquina de estados, do HUD, do spawn, do roteamento de
## teclas e da camada de FX (`_world`, grupo "fx", onde sobem números de dano e
## explosões).
##
## Fase 3: escolha de papel (1 Guardiao / 2 Mago); o outro vira bot. Tank segura
## o boss via threat; DPS conjura no boss desviando do AoE. Clérigo (Healer) e o
## 3º slot voltam na Fase 4.

const ARENA_RECT := Rect2(60, 60, 840, 500)
const BOSS_POS := Vector2(480, 200)
const TANK_START := Vector2(480, 290)
const HEALER_START := Vector2(360, 430)
const MAGO_START := Vector2(600, 430)

var state := "select"  # "select" | "playing" | "won" | "lost"
var human_role := ""   # "tank" | "healer" | "dps"

var boss: Boss
var party: Array = []
var human_unit = null  # Guardiao | Mago — sem tipo fixo de propósito

var _world: Node2D
var _status_label: Label
var _hint_label: Label


func _ready() -> void:
	_build_hud()
	_world = Node2D.new()
	_world.add_to_group("fx")
	_world.z_index = 10
	add_child(_world)
	_show_select()


func _show_select() -> void:
	state = "select"
	_clear_encounter()
	if _status_label:
		_status_label.text = ""


func _start_encounter() -> void:
	state = "playing"
	_clear_encounter()

	boss = Boss.new()
	boss.arena_rect = ARENA_RECT
	boss.position = BOSS_POS
	boss.died.connect(_on_boss_died)
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
	mago.target = boss
	mago.is_bot = human_role != "dps"
	mago.died.connect(_on_member_died)
	add_child(mago)
	party.append(mago)

	if human_role == "tank":
		human_unit = guardiao
	elif human_role == "healer":
		human_unit = clerigo
	else:
		human_unit = mago

	if _status_label:
		_status_label.text = ""


func _clear_encounter() -> void:
	for m in party:
		if is_instance_valid(m):
			m.queue_free()
	party.clear()
	human_unit = null
	if is_instance_valid(boss):
		boss.queue_free()
	if _world != null:
		for child in _world.get_children():
			child.queue_free()


func _process(_delta: float) -> void:
	_update_hint()
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
		elif human_unit is Clerigo:
			var c := human_unit as Clerigo
			c.select_ally_at(get_global_mouse_position())


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
		elif human_unit is Clerigo:
			var c := human_unit as Clerigo
			c.cycle_ally_target()
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
	_status_label.text = "VITORIA!"
	_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))


func _on_member_died(_unused = null) -> void:
	pass  # o wipe é checado a cada frame em _check_wipe()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_status_label = Label.new()
	_status_label.position = Vector2(ARENA_RECT.position.x, 14)
	_status_label.add_theme_font_size_override("font_size", 30)
	layer.add_child(_status_label)

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

	var members := ""
	for m in party:
		if is_instance_valid(m):
			if members != "":
				members += "   "
			members += _member_summary(m)
	var boss_txt := ""
	if is_instance_valid(boss):
		boss_txt = "Boss: %d HP   Rez: %d" % [int(round(boss.hp)), boss.rez_charges]
	_hint_label.text = "%s\n%s   |   %s" % [_control_hint(), members, boss_txt]


func _member_summary(m: PartyMember) -> String:
	var tag := "(bot)" if m.is_bot else "(voce)"
	var hp_txt := "%d/%d HP" % [int(round(m.hp)), int(round(m.max_hp))]
	if m is Guardiao:
		var g := m as Guardiao
		return "Guardiao %s %s Ira %d" % [tag, hp_txt, int(round(g.ira))]
	elif m is Clerigo:
		var c := m as Clerigo
		return "Clerigo %s %s Mana %d" % [tag, hp_txt, int(round(c.mana))]
	return "Mago %s %s" % [tag, hp_txt]


func _control_hint() -> String:
	if human_role == "tank":
		return "WASD mover | auto-attack no boss | 1 Provocar | 2 Muralha"
	elif human_role == "healer":
		return "WASD mover | Tab/clique escolhe aliado (sem escolha: o mais ferido) | 1 Cura(parado) | 2 Rapida | 3 Escudo | 4 Rez"
	return "WASD mover | PARADO conjura | Tab/clique alvo"


func _draw() -> void:
	draw_rect(ARENA_RECT, Color(0.11, 0.12, 0.16), true)

	var grid_col := Color(1, 1, 1, 0.035)
	var step := 48.0
	var gx := ARENA_RECT.position.x + step
	while gx < ARENA_RECT.end.x:
		draw_line(Vector2(gx, ARENA_RECT.position.y), Vector2(gx, ARENA_RECT.end.y), grid_col, 1.0)
		gx += step
	var gy := ARENA_RECT.position.y + step
	while gy < ARENA_RECT.end.y:
		draw_line(Vector2(ARENA_RECT.position.x, gy), Vector2(ARENA_RECT.end.x, gy), grid_col, 1.0)
		gy += step

	var vign := Color(0, 0, 0, 0.10)
	var b := 26.0
	draw_rect(Rect2(ARENA_RECT.position, Vector2(ARENA_RECT.size.x, b)), vign, true)
	draw_rect(Rect2(Vector2(ARENA_RECT.position.x, ARENA_RECT.end.y - b), Vector2(ARENA_RECT.size.x, b)), vign, true)
	draw_rect(Rect2(ARENA_RECT.position, Vector2(b, ARENA_RECT.size.y)), vign, true)
	draw_rect(Rect2(Vector2(ARENA_RECT.end.x - b, ARENA_RECT.position.y), Vector2(b, ARENA_RECT.size.y)), vign, true)

	draw_rect(ARENA_RECT, Color(0.35, 0.42, 0.60), false, 2.0)
	draw_rect(ARENA_RECT.grow(-4.0), Color(0.5, 0.6, 0.85, 0.5), false, 1.0)
