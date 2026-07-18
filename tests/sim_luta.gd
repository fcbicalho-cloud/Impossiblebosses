extends SceneTree
## Simulador de luta 100% bots (ferramenta de balanceamento, não é teste):
##   godot --headless --path . -s tests/sim_luta.gd -- [dificuldade] [repeticoes]
## dificuldade: 0 Normal | 1 Heroico | 2 Impossivel (padrão 0)
##
## Roda o encontro inteiro sem humano e reporta vitória/wipe, tempo de luta e
## quem sobreviveu. Serve para responder "os bots jogam bem?" com número em vez
## de impressão — rode antes e depois de mexer na IA.
##
## Usa Engine.time_scale para acelerar: em headless o loop roda solto e o delta
## real é minúsculo, então sem isso uma luta de 60s levaria 60s de relógio.

const TIME_SCALE := 8.0
const LIMITE_SEGUNDOS := 200.0

var _main: Node2D = null
var _dificuldade := Difficulty.NORMAL
var _restantes := 1
var _tempo := 0.0
var _iniciado := false
var _vitorias := 0
var _wipes := 0
var _estouros := 0
var _tempos: Array[float] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_dificuldade = int(args[0])
	if args.size() > 1:
		_restantes = int(args[1])
	Engine.time_scale = TIME_SCALE
	_main = (load("res://Main.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _nova_luta() -> void:
	_tempo = 0.0
	_main.difficulty_index = _dificuldade
	_main.human_role = "sim"  # nenhum papel bate: os 3 viram bots
	_main._start_encounter()
	_iniciado = true


func _on_frame() -> void:
	if not _iniciado:
		_nova_luta()
		return

	# get_process_delta_time() JÁ vem multiplicado pelo time_scale — multiplicar de
	# novo fazia o relógio correr 8× mais rápido que o jogo, inflando os tempos e
	# cortando lutas cedo demais (elas viravam "estouro" aos 25s reais de jogo).
	_tempo += root.get_process_delta_time()

	var estado: String = _main.state
	if estado == "won":
		_vitorias += 1
		_tempos.append(_tempo)
		_proxima()
	elif estado == "lost":
		_wipes += 1
		_tempos.append(_tempo)
		_proxima()
	elif _tempo > LIMITE_SEGUNDOS:
		_estouros += 1
		_tempos.append(_tempo)
		_proxima()


func _proxima() -> void:
	_restantes -= 1
	if _restantes > 0:
		_nova_luta()
		return
	_relatorio()


func _relatorio() -> void:
	var total: int = _vitorias + _wipes + _estouros
	var media := 0.0
	for t: float in _tempos:
		media += t
	if not _tempos.is_empty():
		media /= float(_tempos.size())
	print("SIM [%s] %d lutas: %d vitorias, %d wipes, %d estouros | tempo medio %.1fs" % [
		Difficulty.label_for(_dificuldade), total, _vitorias, _wipes, _estouros, media])
	quit(0)
