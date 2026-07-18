extends SceneTree
## Captura uma screenshot da luta em andamento (ferramenta de conferência
## visual, não é teste). Abre uma janela por alguns segundos:
##   godot --path . -s tests/capture_screenshot.gd -- <arquivo.png>
## Sem argumento, salva em user://captura.png.

var _main: Node2D = null
var _frame := 0
var _out := "user://captura.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_main = (load("res://Main.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 5:
		_main.human_role = "healer"
		_main._start_encounter()
	elif _frame == 6:
		# Seleciona um aliado pra retícula de mira aparecer na captura.
		var c := _main.human_unit as Clerigo
		c.cycle_ally_target()
	elif _frame >= 180:
		var img := root.get_texture().get_image()
		var err := img.save_png(_out)
		print("CAPTURA %s -> %s" % ["OK" if err == OK else "FALHOU", ProjectSettings.globalize_path(_out)])
		quit(0 if err == OK else 1)
