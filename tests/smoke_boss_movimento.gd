extends SceneTree
## Smoke test headless do movimento do boss:
##   godot --headless --path . -s tests/smoke_boss_movimento.gd
## Confere que o boss (1) NÃO acerta fora do alcance de corpo-a-corpo, (2) anda
## na direção do topo do threat, (3) troca de rumo quando o aggro muda, e (4)
## para de andar ao chegar no alcance (não atravessa o alvo).

const TIME_SCALE := 6.0

var _main: Node2D = null
var _frame := 0
var _iniciado := false
var _falhas: Array[String] = []

var _hp_longe_intacto := false
var _aproximou := false
var _bateu_perto := false
var _seguiu_novo_alvo := false
var _parou_no_alcance := false


func _initialize() -> void:
	Engine.time_scale = TIME_SCALE
	_main = (load("res://Main.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _checar(condicao: bool, descricao: String) -> void:
	if not condicao:
		_falhas.append(descricao)


func _on_frame() -> void:
	_frame += 1
	if not _iniciado:
		_iniciado = true
		_main.difficulty_index = Difficulty.NORMAL
		_main.human_role = "sim"
		_main._start_encounter()
		return

	var boss: Boss = _main.boss
	var tank: Guardiao = _main.party[0] as Guardiao
	var mago: Mago = _main.party[2] as Mago

	if _frame == 3:
		# Congela os aliados para o teste medir só o boss.
		for m: PartyMember in _main.party:
			m.set_process(false)
		boss._threat_values.clear()
		boss._threat_members.clear()
		boss.add_threat(tank, 100.0)
		tank.position = boss.position + Vector2(420.0, 0.0)
		mago.position = boss.position + Vector2(-420.0, 0.0)
		_dist_inicial = boss.position.distance_to(tank.position)
		# Sem escudo aqui também: com absorção, um golpe indevido a longa distância
		# não mexeria no HP e o teste passaria por engano.
		tank.shield = 0.0
		_hp_tank_antes = tank.hp
	elif _frame == 6:
		# Longe: não pode ter apanhado, e o boss tem de ter se aproximado.
		_hp_longe_intacto = tank.hp == _hp_tank_antes
		_aproximou = boss.position.distance_to(tank.position) < _dist_inicial - 5.0
		# Agora o Mago rouba o aggro: o boss deve inverter o rumo.
		_x_antes = boss.position.x
		boss.add_threat(mago, 5000.0)
	elif _frame == 10:
		_seguiu_novo_alvo = boss.position.x < _x_antes
		# Cola o boss no tank e devolve o aggro: tem de bater.
		boss._threat_values.clear()
		boss._threat_members.clear()
		boss.add_threat(tank, 100.0)
		boss.position = tank.position + Vector2(50.0, 0.0)
		boss._melee_cd = 0.0
		# Zera o escudo: o Clerigo bot pode ter escudado o tank, e a absorcao
		# esconderia o golpe (o HP nao cai). Isso ja fez o teste acusar falso.
		tank.shield = 0.0
		_hp_tank_antes = tank.hp
	elif _frame == 13:
		_bateu_perto = tank.hp < _hp_tank_antes
		_parou_no_alcance = boss.position.distance_to(tank.position) >= Boss.MELEE_STOP - 12.0
		_relatorio()


var _dist_inicial := 0.0
var _hp_tank_antes := 0.0
var _x_antes := 0.0


func _relatorio() -> void:
	_checar(_hp_longe_intacto, "boss acertou o tank FORA do alcance de corpo-a-corpo")
	_checar(_aproximou, "boss nao andou na direcao do topo do threat")
	_checar(_seguiu_novo_alvo, "boss nao trocou de rumo quando o aggro mudou")
	_checar(_bateu_perto, "boss nao bateu no alvo estando dentro do alcance")
	_checar(_parou_no_alcance, "boss atravessou o alvo em vez de parar no alcance")

	var ok := _falhas.is_empty()
	if ok:
		print("SMOKE OK: fora_do_alcance_sem_dano=%s aproximou=%s trocou_rumo=%s bateu_perto=%s parou=%s" % [
			_hp_longe_intacto, _aproximou, _seguiu_novo_alvo, _bateu_perto, _parou_no_alcance])
	else:
		print("SMOKE FALHOU:")
		for f: String in _falhas:
			print("  - " + f)
	quit(0 if ok else 1)
