extends Node2D
## Protótipo M1 — orquestra arena, boss, jogador e estado de jogo.
##
## Fatia-núcleo do combate na ótica do DPS ("Mago"): mover (WASD), travar o
## alvo (Tab), o auto-attack cuida do dano, e você desvia dos AoEs telegrafados
## do boss. Vitória = matar o boss; Derrota = morrer; R = reiniciar.
##
## Escopo proposital: SEM trindade/threat/cura aqui (ver docs/ESCOPO.md, seção 8).
## É só o game feel do combate. Trindade e bots vêm depois.

const ARENA_RECT := Rect2(60, 60, 840, 500)

var player: Player
var boss: Boss
var state := "playing"  # "playing" | "won" | "lost"

var _status_label: Label
var _hint_label: Label


func _ready() -> void:
	_build_hud()
	_start_encounter()


func _start_encounter() -> void:
	state = "playing"
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(boss):
		boss.queue_free()

	boss = Boss.new()
	boss.arena_rect = ARENA_RECT
	boss.position = ARENA_RECT.get_center() + Vector2(0, -110)
	boss.died.connect(_on_boss_died)
	add_child(boss)

	player = Player.new()
	player.arena_rect = ARENA_RECT
	player.position = ARENA_RECT.get_center() + Vector2(0, 150)
	player.target = boss
	player.died.connect(_on_player_died)
	add_child(player)

	boss.player = player  # o boss precisa mirar os AoEs no jogador

	if _status_label:
		_status_label.text = ""


func _process(_delta: float) -> void:
	_update_hint()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_start_encounter()
		elif event.keycode == KEY_TAB:
			if is_instance_valid(player) and is_instance_valid(boss):
				player.target = boss
			get_viewport().set_input_as_handled()


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
	match state:
		"playing":
			var hp_p := 0
			var hp_b := 0
			if is_instance_valid(player):
				hp_p = int(round(player.hp))
			if is_instance_valid(boss):
				hp_b = int(round(boss.hp))
			_hint_label.text = "WASD: mover   Tab: alvo   |   Voce: %d HP    Boss: %d HP" % [hp_p, hp_b]
		"won":
			_hint_label.text = "Voce venceu! Pressione R para reiniciar."
		"lost":
			_hint_label.text = "Pressione R para tentar de novo."


func _draw() -> void:
	# Fundo e borda da arena (estático — desenhado uma vez).
	draw_rect(ARENA_RECT, Color(0.14, 0.15, 0.19), true)
	draw_rect(ARENA_RECT, Color(0.48, 0.53, 0.68), false, 3.0)
