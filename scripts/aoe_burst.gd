extends Node2D
class_name AoeBurst
## Explosão visual quando um AoE do boss detona: um anel que expande e some.
## Criado por Boss._detonate na camada de FX. Puramente cosmético.

const LIFE := 0.4

var _radius := 90.0
var _age := 0.0


func setup(r: float) -> void:
	_radius = r


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_age / LIFE, 0.0, 1.0)
	var a: float = (1.0 - t) * 0.85
	var rr: float = _radius * (0.55 + 0.55 * t)
	draw_circle(Vector2.ZERO, rr * 0.6, Color(1.0, 0.5, 0.2, a * 0.35))
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(1.0, 0.45, 0.2, a), 4.0)
