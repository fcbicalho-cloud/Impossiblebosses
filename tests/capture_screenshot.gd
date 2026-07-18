extends SceneTree
## Captura uma screenshot do jogo (ferramenta de conferência visual, não é
## teste). Abre uma janela por alguns segundos:
##   godot --path . -s tests/capture_screenshot.gd -- <saida.png> [cena]
## Cenas: "selecao" (tela de escolha), "luta" (encontro normal), "adds" (encontro
## empurrado para a fase 3, com adds e enrage ativos). Padrão: "luta".

var _main: Node2D = null
var _frame := 0
var _out := "user://captura.png"
var _cena := "luta"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_cena = args[1]
	_main = (load("res://Main.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 5 and _cena != "selecao":
		_main.difficulty_index = Difficulty.IMPOSSIVEL if _cena == "adds" else Difficulty.NORMAL
		_main.human_role = "healer"
		_main._start_encounter()
	elif _frame == 6 and _cena != "selecao":
		# Seleciona um aliado pra retícula de mira aparecer na captura.
		var c := _main.human_unit as Clerigo
		c.cycle_ally_target()
		if _cena == "adds":
			# Empurra para a fase 3 (duas ondas de adds) e dispara o enrage.
			_main.boss.hp = _main.boss.max_hp * 0.30
			_main.boss.enrage_remaining = 0.0
	elif _frame >= 150:
		var img := root.get_texture().get_image()
		var err := img.save_png(_out)
		print("CAPTURA %s (%s) -> %s" % [
			"OK" if err == OK else "FALHOU", _cena, ProjectSettings.globalize_path(_out)])
		quit(0 if err == OK else 1)
