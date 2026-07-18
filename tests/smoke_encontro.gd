extends SceneTree
## Smoke test headless da complexidade do encontro:
##   godot --headless --path . -s tests/smoke_encontro.gd
## Confere que o preset de dificuldade chega ao boss, que as fases disparam nos
## limiares de vida trazendo ondas de adds, e que o enrage escala o dano.

var _main: Node2D = null
var _boss: Boss = null
var _frame := 0
var _falhas: Array[String] = []

var _preset: Difficulty = null
var _mult_fase1 := 0.0
var _mult_fase2 := 0.0
var _adds_fase2 := 0
var _adds_fase3 := 0
var _fase_apos_66 := 0
var _fase_apos_33 := 0
var _mult_enrage := 0.0
var _salto_fase := 0
var _adds_salto := 0
var _enrajou := false


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
		_preset = Difficulty.preset(Difficulty.IMPOSSIVEL)
		_main.difficulty_index = Difficulty.IMPOSSIVEL
		_main.human_role = "healer"
		_main._start_encounter()
	elif _frame == 5:
		_boss = _main.boss
		_checar(_boss.max_hp == _preset.boss_hp, "hp do preset nao chegou ao boss")
		_checar(_boss.rez_charges == _preset.rez_charges, "rez do preset nao chegou ao boss")
		_checar(_boss.phase == 1, "encontro nao comeca na fase 1")
		_mult_fase1 = _boss.damage_multiplier()
		# Cai para 60% da vida -> deve virar fase 2.
		_boss.hp = _boss.max_hp * 0.60
	elif _frame == 7:
		_fase_apos_66 = _boss.phase
		_mult_fase2 = _boss.damage_multiplier()
		_adds_fase2 = _boss.active_add_count()
		# Cai para 30% -> fase 3, segunda onda.
		_boss.hp = _boss.max_hp * 0.30
	elif _frame == 9:
		_fase_apos_33 = _boss.phase
		_adds_fase3 = _boss.active_add_count()
		# Força o enrage e avança o relógio interno da rampa.
		_boss.enrage_remaining = 0.0
	elif _frame == 11:
		_boss._enrage_elapsed = 10.0  # 2 degraus de rampa
		_mult_enrage = _boss.damage_multiplier()
		# Lê agora: o _start_encounter do frame 13 libera este boss, e consultar a
		# instância morta em _relatorio dava erro por frame (o quit nunca vinha).
		_enrajou = _boss.enraged
	elif _frame == 13:
		# Reinicia e mata o boss de 100% até 30% num golpe só: as DUAS ondas
		# devem entrar, senão um burst grande pularia a onda da fase 2.
		_main._start_encounter()
	elif _frame == 15:
		_main.boss.hp = _main.boss.max_hp * 0.30
	elif _frame == 17:
		_salto_fase = _main.boss.phase
		_adds_salto = _main.boss.active_add_count()
	elif _frame >= 19:
		_relatorio()


func _relatorio() -> void:
	_checar(_fase_apos_66 == 2, "vida <=66%% nao virou fase 2 (foi %d)" % _fase_apos_66)
	_checar(_fase_apos_33 == 3, "vida <=33%% nao virou fase 3 (foi %d)" % _fase_apos_33)
	_checar(_adds_fase2 == _preset.adds_per_wave,
		"onda da fase 2 trouxe %d adds, esperado %d" % [_adds_fase2, _preset.adds_per_wave])
	_checar(_adds_fase3 == _preset.adds_per_wave * 2,
		"apos 2 ondas havia %d adds, esperado %d" % [_adds_fase3, _preset.adds_per_wave * 2])
	_checar(_mult_fase2 > _mult_fase1, "fase 2 nao aumentou o dano")
	_checar(_enrajou, "boss nao entrou em enrage")
	_checar(_mult_enrage > _mult_fase2, "enrage nao escalou o dano acima da fase")
	_checar(_salto_fase == 3, "salto direto para 30%% nao chegou na fase 3 (foi %d)" % _salto_fase)
	_checar(_adds_salto == _preset.adds_per_wave * 2,
		"salto de 2 fases trouxe %d adds, esperado %d (onda do meio foi pulada)" % [
			_adds_salto, _preset.adds_per_wave * 2])

	var ok := _falhas.is_empty()
	if ok:
		print("SMOKE OK: fases=%d/%d adds=%d/%d mult f1=%.2f f2=%.2f enrage=%.2f | salto: fase=%d adds=%d" % [
			_fase_apos_66, _fase_apos_33, _adds_fase2, _adds_fase3,
			_mult_fase1, _mult_fase2, _mult_enrage, _salto_fase, _adds_salto])
	else:
		print("SMOKE FALHOU:")
		for f: String in _falhas:
			print("  - " + f)
	quit(0 if ok else 1)
