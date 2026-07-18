extends Actor
class_name PartyMember
## Base dos 3 papéis (Mago/Guardiao/Clerigo). Estende Actor com o que é
## específico de um membro do grupo jogável: escudo (absorção), fonte de input
## (`is_bot`), confinamento à arena, leitura de WASD, helper de desvio de AoE e
## revive. Entra no grupo "party" para ser encontrado pelo boss e pelas mecânicas.
##
## `is_bot` é a costura de fonte de input: falso = teclado local; verdadeiro = IA
## simples na própria subclasse. É o mesmo ponto onde, no futuro, entra uma fonte
## de rede (multiplayer), sem duplicar as classes.

var role_label := "Aventureiro"
var shield := 0.0
var is_bot := false
var arena_rect := Rect2()
var boss = null  # referência solta (duck-typed) ao Boss, setada pelo Main


func _ready() -> void:
	add_to_group("party")


## Sobrescreve o ponto de extensão de dano do Actor para descontar escudo antes
## da vida.
func _apply_damage(amount: float) -> void:
	var remaining := amount
	if shield > 0.0:
		var absorbed: float = minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	if remaining > 0.0:
		super._apply_damage(remaining)
	else:
		queue_redraw()


func add_shield(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	shield += amount
	queue_redraw()


func revive(hp_fraction_value: float) -> void:
	if alive:
		return
	alive = true
	hp = max_hp * hp_fraction_value
	shield = 0.0
	queue_redraw()


func _clamp_to_arena() -> void:
	if arena_rect.size != Vector2.ZERO:
		position.x = clampf(position.x, arena_rect.position.x + radius, arena_rect.end.x - radius)
		position.y = clampf(position.y, arena_rect.position.y + radius, arena_rect.end.y - radius)


func _read_wasd() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	return dir


## Vetor de fuga (normalizado) para sair do(s) AoE(s) telegrafados que
## atingiriam a posição atual; Vector2.ZERO se nenhum ameaçar. Usado por bots.
func _aoe_flee_vector() -> Vector2:
	if boss == null or not is_instance_valid(boss) or not boss.has_method("get_active_aoes"):
		return Vector2.ZERO
	var flee := Vector2.ZERO
	for info in boss.get_active_aoes():
		var pos: Vector2 = info["pos"]
		var r: float = info["radius"]
		if position.distance_to(pos) <= r + 24.0:
			var away := position - pos
			away = away.normalized() if away.length() > 0.1 else Vector2(1, 0)
			flee += away
	return flee.normalized() if flee.length() > 0.01 else Vector2.ZERO


func _draw_shield_overlay() -> void:
	if shield > 0.0:
		draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 20, Color(0.6, 0.85, 1.0, 0.7), 2.0)
