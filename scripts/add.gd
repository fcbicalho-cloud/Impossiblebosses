extends Actor
class_name Add
## Add — inimigo menor que entra em ondas nas mudanças de fase do boss.
##
## Função de design (ESCOPO seção 9): forçar REPRIORIZAÇÃO. Ele persegue o
## membro VIVO mais próximo e bate nele, ignorando threat — ou seja, vai atrás de
## quem estiver exposto (tipicamente healer/dps), e não do tank. A resposta certa
## é o dps trocar de alvo e limpá-lo rápido, não o tank tentar segurar tudo.
##
## Entra em "targetable" (alvo de Tab/clique, como o boss) e em "add" (para o dps
## bot priorizar). Ao morrer sai dos grupos e se libera — diferente do boss, que
## permanece na cena.

const SPEED := 120.0
const MELEE_RANGE := 34.0
const ATTACK_INTERVAL := 1.2

var damage := 8.0
var arena_rect := Rect2()

var _attack_cd := 0.6
var _facing := Vector2(0.0, 1.0)
var _taunt_source: PartyMember = null
var _taunt_timer := 0.0


func _ready() -> void:
	add_to_group("targetable")
	add_to_group("add")
	radius = 11.0
	_setup_body_sprite(preload("res://assets/characters/add.png"), 2.0)


func setup(hp_value: float, damage_value: float, arena: Rect2) -> void:
	max_hp = hp_value
	hp = hp_value
	damage = damage_value
	arena_rect = arena


func _process(delta: float) -> void:
	_update_sprite()
	if not alive:
		return
	_tick_visuals(delta)
	if _taunt_timer > 0.0:
		_taunt_timer = maxf(0.0, _taunt_timer - delta)
	var victim := _nearest_victim()
	if victim != null:
		var to_victim: Vector2 = victim.position - position
		if to_victim.length() > 1.0:
			_facing = to_victim.normalized()
		if to_victim.length() > MELEE_RANGE:
			position += _facing * SPEED * delta
			_clamp_to_arena()
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if victim != null and _attack_cd == 0.0:
		if position.distance_to(victim.position) <= MELEE_RANGE:
			_attack_cd = ATTACK_INTERVAL
			victim.take_damage(damage)
	queue_redraw()


## Provocar: força este add a perseguir quem provocou por `duration` segundos,
## ignorando a regra do mais próximo. É o que dá ao tank controle sobre adds —
## sem isto o Provocar só afetava o boss.
func taunt(source: PartyMember, duration: float) -> void:
	if not alive or source == null or not is_instance_valid(source) or not source.alive:
		return
	_taunt_source = source
	_taunt_timer = duration
	queue_redraw()


## Quem este add está perseguindo agora. Público para o tank bot saber quais adds
## estão em cima de outra pessoa e ir buscá-los.
func current_victim() -> PartyMember:
	return _nearest_victim()


func is_taunted() -> bool:
	return _taunt_timer > 0.0 and _taunt_source != null and is_instance_valid(_taunt_source) and _taunt_source.alive


## Alvo do add: quem o provocou enquanto durar, senão o membro vivo mais próximo.
func _nearest_victim() -> PartyMember:
	if is_taunted():
		return _taunt_source
	var best: PartyMember = null
	var best_d := INF
	for m: PartyMember in get_tree().get_nodes_in_group("party"):
		if not is_instance_valid(m) or not m.alive:
			continue
		var d: float = position.distance_to(m.position)
		if d < best_d:
			best_d = d
			best = m
	return best


func _clamp_to_arena() -> void:
	if arena_rect.size == Vector2.ZERO:
		return
	position.x = clampf(position.x, arena_rect.position.x + radius, arena_rect.end.x - radius)
	position.y = clampf(position.y, arena_rect.position.y + radius, arena_rect.end.y - radius)


## Ponto de extensão do Actor: o add some da cena ao morrer (sai dos grupos antes
## do queue_free para não aparecer em buscas no frame em que morre).
func _die() -> void:
	super._die()
	remove_from_group("targetable")
	remove_from_group("add")
	queue_free()


func _update_sprite() -> void:
	if body_sprite == null or not alive:
		return
	body_sprite.position = Vector2(0.0, -sin(anim_time * 6.0) * 1.5)
	if absf(_facing.x) > 0.1:
		body_sprite.flip_h = _facing.x < 0.0


func _draw() -> void:
	if not alive:
		return
	_draw_sprite_shadow()
	# Anel vermelho enquanto provocado: sem marcador, o jogador não tem como saber
	# que o Provocar pegou neste add.
	if is_taunted():
		var pulse: float = 0.6 + 0.3 * sin(anim_time * 10.0)
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 18, Color(1.0, 0.35, 0.25, pulse), 2.0)
	_draw_hp_bar(24.0, 4.0, -radius - 10.0, Color(0.9, 0.5, 0.3))
