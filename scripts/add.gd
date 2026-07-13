extends Node2D
class_name Add
## Inimigo menor ("add"). Persegue um alvo FIXO sorteado aleatoriamente entre
## o grupo "party" — não recalcula "quem está mais perto" a cada frame. O
## Guardiao pode chamar taunt() (via Provocar) pra forçar o add a mirar nele
## por um tempo; quando o travamento expira, sorteia um novo alvo aleatório.
## É alvo válido do tab-target (grupo "targetable"). Mate-o com o Mago
## (Tab/clique) ou ele desgasta quem estiver mirando.

const HP_MAX := 40.0
const RADIUS := 11.0
const SPEED := 95.0
const CONTACT_RANGE := 24.0
const CONTACT_DAMAGE := 6.0
const CONTACT_INTERVAL := 0.9
const TAUNT_LOCK_DURATION := 5.0

var hp := HP_MAX

var _contact_cd := 0.0
var _alive := true
var _target: PartyMember = null
var _taunt_timer := 0.0


func _ready() -> void:
	add_to_group("targetable")
	add_to_group("add")


func _process(delta: float) -> void:
	if not _alive:
		return
	_contact_cd = maxf(0.0, _contact_cd - delta)

	if _taunt_timer > 0.0:
		_taunt_timer -= delta
		if _taunt_timer <= 0.0:
			_pick_random_target()  # taunt expirou, sorteia de novo

	if _target == null or not is_instance_valid(_target) or not _target.alive:
		_pick_random_target()

	if _target != null:
		var to_target: Vector2 = _target.position - position
		if to_target.length() > CONTACT_RANGE:
			position += to_target.normalized() * SPEED * delta
		elif _contact_cd == 0.0:
			_contact_cd = CONTACT_INTERVAL
			_target.take_damage(CONTACT_DAMAGE)
	queue_redraw()


## Chamado pelo Provocar do Guardiao: força este add a mirar em `source` por
## TAUNT_LOCK_DURATION segundos, depois volta a sortear alvo aleatório.
func taunt(source: PartyMember) -> void:
	if source == null or not is_instance_valid(source):
		return
	_target = source
	_taunt_timer = TAUNT_LOCK_DURATION


## Usado pelo Guardiao pra saber se este add está em cima dele (pra decidir
## se ataca o add em vez do boss).
func is_targeting(who: PartyMember) -> bool:
	return _target == who


func _pick_random_target() -> void:
	var alive_party: Array = []
	for n: PartyMember in get_tree().get_nodes_in_group("party"):
		if is_instance_valid(n) and n.alive:
			alive_party.append(n)
	if alive_party.is_empty():
		_target = null
		return
	_target = alive_party[randi() % alive_party.size()]


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
	if _taunt_timer > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 3.0, 0.0, TAU, 16, Color(1.0, 0.3, 0.3, 0.85), 2.0)
	var w := 26.0
	var h := 4.0
	var off := Vector2(-w / 2.0, -RADIUS - 8.0)
	draw_rect(Rect2(off, Vector2(w, h)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(w * (hp / HP_MAX), h)), Color(0.8, 0.5, 1.0), true)
