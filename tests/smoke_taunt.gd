extends SceneTree
## Smoke test headless do Provocar:
##   godot --headless --path . -s tests/smoke_taunt.gd
## Confere que o Provocar (1) rouba o boss de quem tem mais threat, (2) força os
## adds DENTRO do raio a perseguirem o tank, (3) NÃO afeta add fora do raio, e
## (4) expira, devolvendo o add à regra do mais próximo.

var _main: Node2D = null
var _frame := 0
var _falhas: Array[String] = []

var _boss_antes := ""
var _boss_depois := ""
var _perto_provocado := false
var _longe_provocado := true
var _perto_persegue := ""
var _expirou := false


func _initialize() -> void:
	_main = (load("res://Main.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _checar(condicao: bool, descricao: String) -> void:
	if not condicao:
		_falhas.append(descricao)


func _on_frame() -> void:
	_frame += 1
	if _frame == 3:
		_main.difficulty_index = Difficulty.NORMAL
		_main.human_role = "dps"
		_main._start_encounter()
	elif _frame == 5:
		var boss: Boss = _main.boss
		var tank := _tank()
		# Mago rouba o boss com threat absurdo; o Provocar tem de trazer de volta.
		boss.add_threat(_main.party[2] as PartyMember, 5000.0)
		_boss_antes = _nome(boss.current_target())
		tank._taunt_cd = 0.0
		tank.activate_ability(1)
		_boss_depois = _nome(boss.current_target())
		# Onda de adds para testar o raio.
		boss.hp = boss.max_hp * 0.60
	elif _frame == 7:
		var tank := _tank()
		var adds: Array = get_nodes_in_group("add")
		if adds.size() < 1:
			_falhas.append("nenhum add nasceu para testar o taunt")
			_relatorio()
			return
		# Um add colado no tank, outro no canto oposto (fora do raio).
		var perto: Add = adds[0] as Add
		perto.position = tank.position + Vector2(40.0, 0.0)
		var longe: Add = null
		if adds.size() > 1:
			longe = adds[1] as Add
		else:
			longe = Add.new()
			longe.setup(40.0, 8.0, tank.arena_rect)
			_main._world.add_child(longe)
		longe.position = tank.position + Vector2(Guardiao.TAUNT_RADIUS + 120.0, 0.0)

		tank._taunt_cd = 0.0
		tank.activate_ability(1)
		_perto_provocado = perto.is_taunted()
		_longe_provocado = longe.is_taunted()
		_perto_persegue = _nome(perto._nearest_victim())
		# Expira o taunt do de perto: deve voltar à regra do mais próximo.
		perto._taunt_timer = 0.0
		_expirou = not perto.is_taunted()
	elif _frame >= 9:
		_relatorio()


func _tank() -> Guardiao:
	return _main.party[0] as Guardiao


func _nome(n) -> String:
	if n == null or not is_instance_valid(n):
		return "<nenhum>"
	if n is PartyMember:
		return (n as PartyMember).role_label
	return n.get_class()


func _relatorio() -> void:
	_checar(_boss_antes == "Mago", "preparo falhou: boss deveria estar no Mago (estava em %s)" % _boss_antes)
	_checar(_boss_depois == "Guardiao", "Provocar nao trouxe o boss de volta (alvo: %s)" % _boss_depois)
	_checar(_perto_provocado, "add dentro do raio nao foi provocado")
	_checar(not _longe_provocado, "add FORA do raio foi provocado (o raio nao esta valendo)")
	_checar(_perto_persegue == "Guardiao", "add provocado persegue %s em vez do tank" % _perto_persegue)
	_checar(_expirou, "taunt do add nao expirou")

	var ok := _falhas.is_empty()
	if ok:
		print("SMOKE OK: boss %s->%s | add perto provocado=%s | add longe provocado=%s | persegue=%s | expira=%s" % [
			_boss_antes, _boss_depois, _perto_provocado, _longe_provocado, _perto_persegue, _expirou])
	else:
		print("SMOKE FALHOU:")
		for f: String in _falhas:
			print("  - " + f)
	quit(0 if ok else 1)
