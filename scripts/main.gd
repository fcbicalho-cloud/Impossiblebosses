extends Node2D
## Orquestrador do jogo (reconstrução limpa).
##
## Dono da arena, da máquina de estados, do HUD, do spawn e do roteamento de
## teclas. Entidades transitórias (projéteis, adds — fases futuras) vivem sob
## `_world` e são limpas no restart.
##
## Fase 2: Mago (DPS) vs Boss com uma mecânica (AoE telegrafado). Combate
## tab-target, vitória (matar o boss), derrota (morrer) e reinício (R).
## Trindade + escolha de papel + bots voltam na Fase 3.

const ARENA_RECT := Rect2(60, 60, 840, 500)
const BOSS_POS := Vector2(480, 200)
const MAGO_START := Vector2(480, 400)

var state := "playing"  # "playing" | "won" | "lost"

var boss: Boss
var party: Array = []
var human_unit = null  # Mago (nas próximas fases: Guardiao/Clerigo) — sem tipo fixo

var _world: Node2D
var _status_label: Label
var _hint_label: Label


func _ready() -> void:
	_build_hud()
	_world = Node2D.new()
	add_child(_world)
	_start_encounter()


func _start_encounter() -> void:
	state = "playing"
	_clear_encounter()

	boss = Boss.new()
	boss.arena_rect = ARENA_RECT
	boss.position = BOSS_POS
	boss.died.connect(_on_boss_died)
	add_child(boss)

	var mago := Mago.new()
	mago.arena_rect = ARENA_RECT
	mago.position = MAGO_START
	mago.boss = boss
	mago.target = boss
	mago.died.connect(_on_player_died)
	add_child(mago)
	party.append(mago)
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


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_start_encounter()
		elif event.keycode == KEY_TAB:
			if human_unit is Mago:
				human_unit.cycle_target()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if human_unit is Mago:
			_try_click_target(get_global_mouse_position())


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


func _on_player_died() -> void:
	if state != "playing":
		return
	state = "lost"
	_status_label.text = "DERROTA"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_status_label = Label.new()
	_status_label.position = Vector2(ARENA_RECT.position.x, 14)
	_status_label.add_theme_font_size_override("font_size", 30)
	layer.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(ARENA_RECT.position.x, ARENA_RECT.end.y + 10)
	_hint_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_hint_label)


func _update_hint() -> void:
	if _hint_label == null:
		return
	if state == "won":
		_hint_label.text = "Voce venceu! Pressione R para reiniciar."
		return
	if state == "lost":
		_hint_label.text = "Pressione R para tentar de novo."
		return
	var hp_p := 0
	var hp_b := 0
	if is_instance_valid(human_unit):
		hp_p = int(round(human_unit.hp))
	if is_instance_valid(boss):
		hp_b = int(round(boss.hp))
	_hint_label.text = "WASD: mover   Tab/clique: alvo   PARADO: conjura   |   Voce: %d HP   Boss: %d HP" % [hp_p, hp_b]


func _draw() -> void:
	draw_rect(ARENA_RECT, Color(0.14, 0.15, 0.19), true)
	draw_rect(ARENA_RECT, Color(0.48, 0.53, 0.68), false, 3.0)
