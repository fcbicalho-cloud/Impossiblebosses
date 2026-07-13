extends Node2D
class_name Projectile
## Projétil do boss (fase 2+). Viaja em linha reta na direção capturada no
## momento do disparo; causa dano se acertar o jogador. Some ao sair da arena.
## Dodge = andar para fora da trajetória (ele mira em onde você estava).

const SPEED := 260.0
const RADIUS := 8.0
const DAMAGE := 20.0

var velocity := Vector2.ZERO
var arena_rect := Rect2()
var player: Node2D = null


func _process(delta: float) -> void:
	position += velocity * delta

	if player != null and is_instance_valid(player):
		if position.distance_to(player.position) <= RADIUS + Player.RADIUS:
			if player.has_method("take_damage"):
				player.take_damage(DAMAGE)
			queue_free()
			return

	if arena_rect.size != Vector2.ZERO and not arena_rect.grow(40.0).has_point(position):
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.55, 0.15))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color(1.0, 0.85, 0.5), 1.5)
