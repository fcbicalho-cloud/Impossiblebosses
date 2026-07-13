extends Node2D
class_name Add
## Inimigo menor ("add"). Persegue o membro mais próximo do grupo "party" e
## causa dano de contato. É alvo válido do tab-target (grupo "targetable").
## Mate-o com o Mago (Tab/clique) ou ele desgasta quem estiver por perto.

const HP_MAX := 40.0
const RADIUS := 11.0
const SPEED := 95.0
const CONTACT_RANGE := 24.0
const CONTACT_DAMAGE := 6.0
const CONTACT_INTERVAL := 0.9

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
	var target: PartyMember = _nearest_party_member()
	if target != null:
		var to_target: Vector2 = target.position - position
		if to_target.length() > CONTACT_RANGE:
			position += to_target.normalized() * SPEED * delta
		elif _contact_cd == 0.0:
			_contact_cd = CONTACT_INTERVAL
			target.take_damage(CONTACT_DAMAGE)
	queue_redraw()


func _nearest_party_member() -> PartyMember:
	var best: PartyMember = null
	var best_d := INF
	for n: PartyMember in get_tree().get_nodes_in_group("party"):
		if not is_instance_valid(n) or not n.alive:
			continue
		var d: float = position.distance_to(n.position)
		if d < best_d:
			best_d = d
			best = n
	return best


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
