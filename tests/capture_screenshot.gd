extends SceneTree
## Captura uma screenshot do jogo (ferramenta de conferência visual, não é
## teste). Abre uma janela por alguns segundos:
##   godot --path . -s tests/capture_screenshot.gd -- <saida.png> [cena]
## Cenas: "selecao" (tela de escolha), "luta" (encontro normal), "adds" (encontro
## empurrado para a fase 3, com adds e enrage ativos), "taunt" (Provocar em ação),
## "hud" (barra de habilidades com cooldowns correndo). Padrão: "luta".

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
	if _frame == 100 and _cena == "hud":
		# Gasta Rápida e Escudo para os slots aparecerem em cooldown na captura.
		var c := _main.human_unit as Clerigo
		c.activate_ability(2)
		c.activate_ability(3)
	elif _frame == 5 and _cena != "selecao":
		_main.difficulty_index = Difficulty.IMPOSSIVEL if _cena == "adds" else Difficulty.NORMAL
		_main.human_role = "healer"
		_main._start_encounter()
	elif _frame == 6 and _cena != "selecao":
		# Seleciona um aliado pra retícula de mira aparecer na captura.
		var c := _main.human_unit as Clerigo
		c.cycle_ally_target()
		if _cena == "adds" or _cena == "taunt" or _cena == "hud":
			# Empurra para a fase 3 (duas ondas de adds) e dispara o enrage.
			_main.boss.hp = _main.boss.max_hp * 0.30
			_main.boss.enrage_remaining = 0.0
	elif _frame == 120 and _cena == "taunt":
		# Puxa os adds para perto do tank e dispara o Provocar, para a onda e os
		# anéis de provocado aparecerem na captura.
		var tank := _main.party[0] as Guardiao
		var i := 0
		for a: Add in get_nodes_in_group("add"):
			if is_instance_valid(a):
				var ang: float = TAU * float(i) / 5.0
				a.position = tank.position + Vector2(cos(ang), sin(ang)) * 90.0
				i += 1
		tank._taunt_cd = 0.0
		tank.activate_ability(1)
	elif _frame >= (132 if _cena == "taunt" else 150):
		var img := root.get_texture().get_image()
		var err := img.save_png(_out)
		print("CAPTURA %s (%s) -> %s" % [
			"OK" if err == OK else "FALHOU", _cena, ProjectSettings.globalize_path(_out)])
		quit(0 if err == OK else 1)
