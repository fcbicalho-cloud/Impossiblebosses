extends SceneTree
## Smoke test headless do pipeline de sprite do Mago:
##   godot --headless --path . -s tests/smoke_mago_sprite.gd
## Instancia o Mago como bot, roda frames de verdade, aplica dano (flash),
## mata (pose de morte) e revive. Qualquer erro de script aborta com stack trace;
## sucesso imprime "SMOKE OK".

var _mago: Mago = null
var _frame := 0


func _initialize() -> void:
	_mago = Mago.new()
	_mago.is_bot = true
	root.add_child(_mago)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 10:
		_mago.take_damage(30.0)
	elif _frame == 20:
		_mago.take_damage(999.0)
	elif _frame == 30:
		_mago.revive(0.5)
	elif _frame >= 40:
		var ok: bool = _mago.alive and _mago.body_sprite != null and _mago.hp == 50.0
		print("SMOKE %s: hp=%.0f alive=%s sprite=%s" % [
			"OK" if ok else "FALHOU", _mago.hp, _mago.alive, _mago.body_sprite != null])
		quit(0 if ok else 1)
