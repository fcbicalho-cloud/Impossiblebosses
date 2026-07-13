extends Node2D
class_name Add
## Inimigo menor ("add"). Anda em direção ao jogador e causa dano de contato.
## É alvo válido do tab-target (grupo "targetable"): mate-o trocando de alvo
## (Tab ou clique) e conjurando/atirando nele. Ignorar adds = tomar dano
## constante enquanto tenta conjurar parado no boss.

const HP_MAX := 40.0
const RADIUS := 11.0
const SPEED := 95.0
const CONTACT_RANGE := 24.0
const CONTACT_DAMAGE := 6.0
const CONTACT_INTERVAL := 0.9

var player: Node2D = null
var hp := HP_MAX

var _contact_cd := 0.0
var _alive := true


func _ready() -> void:
	add_to_group("targetable")
	add_to_group("add")


func _process(delta: float) -> void:
	if not _alive:
		return
	_contact_cd = maxf(0.0, _contact_cd - delta)
	if player != null and is_instance_valid(player):
		var to_player := player.position - position
		if to_player.length() > CONTACT_RANGE:
			position += to_player.normalized() * SPEED * delta
		elif _contact_cd == 0.0 and player.has_method("take_damage"):
			_contact_cd = CONTACT_INTERVAL
			player.take_damage(CONTACT_DAMAGE)
	queue_redraw()


func pick_radius() -> float:
	return RADIUS + 6.0


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		_alive = false
		remove_from_group("targetable")
		remove_from_group("add")
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.7, 0.4, 0.9))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 20, Color(0.9, 0.75, 1.0), 2.0)
	var w := 26.0
	var h := 4.0
	var off := Vector2(-w / 2.0, -RADIUS - 8.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (hp / HP_MAX), h)), Color(0.8, 0.5, 1.0), true)
