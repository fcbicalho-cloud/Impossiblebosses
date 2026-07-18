extends Node2D
## Orquestrador do jogo (reconstrução limpa).
##
## Dono da arena, da máquina de estados, do HUD, do spawn e do roteamento de
## teclas. Entidades transitórias (projéteis, adds — fases futuras) vivem sob
## `_world` e são limpas no restart.
##
## Fase 1: arena + HUD + Mago controlável (só movimento; ainda não há inimigo).
## Fase 2 adiciona o Boss, o combate e vitória/derrota.

const ARENA_RECT := Rect2(60, 60, 840, 500)
const MAGO_START := Vector2(480, 400)

var state := "playing"  # "playing" | "won" | "lost"

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

	var mago := Mago.new()
	mago.arena_rect = ARENA_RECT
	mago.position = MAGO_START
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
	if _world != null:
		for child in _world.get_children():
			child.queue_free()


func _process(_delta: float) -> void:
	_update_hint()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_start_encounter()


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
	var hp_txt := ""
	if is_instance_valid(human_unit):
		hp_txt = "   Voce: %d HP" % int(round(human_unit.hp))
	_hint_label.text = "WASD: mover   R: reiniciar%s   (Fase 1: sem inimigo ainda)" % hp_txt


func _draw() -> void:
	draw_rect(ARENA_RECT, Color(0.14, 0.15, 0.19), true)
	draw_rect(ARENA_RECT, Color(0.48, 0.53, 0.68), false, 3.0)
