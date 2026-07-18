extends SceneTree
## Smoke test headless do pipeline de sprite dos 4 personagens:
##   godot --headless --path . -s tests/smoke_mago_sprite.gd
## Instancia Mago/Guardiao/Clerigo (bots) + Boss, roda frames de verdade e
## exercita dano (flash), morte (pose deitada) e revive em cada um. Qualquer erro
## de script aborta com stack trace; sucesso imprime "SMOKE OK".

var _members: Array[PartyMember] = []
var _boss: Boss = null
var _frame := 0


func _initialize() -> void:
	_boss = Boss.new()
	_boss.position = Vector2(480.0, 200.0)
	root.add_child(_boss)

	var mago := Mago.new()
	var guardiao := Guardiao.new()
	var clerigo := Clerigo.new()
	_members = [mago, guardiao, clerigo]
	var x := 300.0
	for m: PartyMember in _members:
		m.is_bot = true
		m.boss = _boss
		m.arena_rect = Rect2(40.0, 40.0, 880.0, 560.0)
		m.position = Vector2(x, 420.0)
		x += 80.0
		root.add_child(m)

	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 10:
		for m: PartyMember in _members:
			m.take_damage(20.0)
		_boss.take_damage(50.0)
	elif _frame == 20:
		for m: PartyMember in _members:
			m.take_damage(9999.0)
	elif _frame == 30:
		for m: PartyMember in _members:
			m.revive(0.5)
	elif _frame >= 40:
		_report()


func _report() -> void:
	var ok := true
	var lines: Array[String] = []
	for m: PartyMember in _members:
		# >= e não == : o Clerigo bot cura os aliados depois do revive.
		var good: bool = m.alive and m.body_sprite != null and m.hp >= m.max_hp * 0.5
		ok = ok and good
		lines.append("%s hp=%.0f/%.0f sprite=%s" % [m.role_label, m.hp, m.max_hp, m.body_sprite != null])
	var boss_good: bool = _boss.alive and _boss.body_sprite != null and _boss.hp < _boss.max_hp
	ok = ok and boss_good
	lines.append("Boss hp=%.0f/%.0f sprite=%s" % [_boss.hp, _boss.max_hp, _boss.body_sprite != null])
	print("SMOKE %s: %s" % ["OK" if ok else "FALHOU", " | ".join(lines)])
	quit(0 if ok else 1)
