extends Node2D
class_name DamageNumber
## Número de dano flutuante: sobe e some. Auto-destrói ao fim da vida.
## Criado por Actor._spawn_damage_number na camada de FX.

const LIFE := 0.7
const RISE_SPEED := 38.0

var _text := "0"
var _age := 0.0


func setup(amount: int) -> void:
	_text = str(amount)


func _process(delta: float) -> void:
	_age += delta
	position.y -= RISE_SPEED * delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var a: float = clampf(1.0 - _age / LIFE, 0.0, 1.0)
	# leve "pop": maior no início
	var size: int = int(round(lerpf(22.0, 16.0, clampf(_age / 0.2, 0.0, 1.0))))
	# sombra + texto
	draw_string(font, Vector2(-19.0, 1.0), _text, HORIZONTAL_ALIGNMENT_CENTER, 40.0, size, Color(0, 0, 0, a * 0.7))
	draw_string(font, Vector2(-20.0, 0.0), _text, HORIZONTAL_ALIGNMENT_CENTER, 40.0, size, Color(1.0, 0.85, 0.3, a))
