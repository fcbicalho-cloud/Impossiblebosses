extends Node2D
class_name PartyMember
## Base compartilhada pelos 3 papéis (Mago/Guardiao/Clerigo).
##
## Fornece: vida/escudo/morte/revive, clamp na arena, grupo "party" (é assim
## que o boss e as mecânicas encontram os party members), e um helper de
## desvio de AoE reutilizável por qualquer bot.
##
## `is_bot` decide a fonte de comando: falso = teclado local; verdadeiro = IA
## simples definida em cada subclasse. É uma versão simplificada da "fonte de
## input abstrata" da seção 6 do escopo — suficiente para bots locais; uma
## fonte de rede (multiplayer) é trabalho futuro do mesmo ponto de extensão.

signal died

var role_label := "Aventureiro"
var max_hp := 100.0
var hp := 100.0
var shield := 0.0
var alive := true
var is_bot := false
var radius := 14.0

var arena_rect := Rect2()
var boss = null  # referência solta (duck-typed) ao Boss, setada pelo Main


func _ready() -> void:
	add_to_group("party")


func _clamp_to_arena() -> void:
	if arena_rect.size != Vector2.ZERO:
		position.x = clampf(position.x, arena_rect.position.x + radius, arena_rect.end.x - radius)
		position.y = clampf(position.y, arena_rect.position.y + radius, arena_rect.end.y - radius)


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	var remaining := amount
	if shield > 0.0:
		var absorbed: float = minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	if remaining > 0.0:
		hp = maxf(0.0, hp - remaining)
	if hp == 0.0:
		alive = false
		died.emit()
	queue_redraw()


func add_shield(amount: float) -> void:
	if not alive:
		return
	shield += amount
	queue_redraw()


func heal(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	queue_redraw()
	return hp - before


func revive(hp_fraction: float) -> void:
	if alive:
		return
	alive = true
	hp = max_hp * hp_fraction
	shield = 0.0
	queue_redraw()


func hp_fraction() -> float:
	return hp / max_hp


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
		var d := position.distance_to(pos)
		if d <= r + 24.0:
			var away := position - pos
			away = away.normalized() if away.length() > 0.1 else Vector2(1, 0)
			flee += away
	return flee.normalized() if flee.length() > 0.01 else Vector2.ZERO


func _draw_hp_bar(width: float, height: float, y_offset: float, fill_color: Color) -> void:
	var off := Vector2(-width / 2.0, y_offset)
	draw_rect(Rect2(off, Vector2(width, height)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(width * hp_fraction(), height)), fill_color, true)
	if shield > 0.0:
		var shield_frac: float = clampf(shield / max_hp, 0.0, 1.0)
		draw_rect(Rect2(off, Vector2(width * shield_frac, height)), Color(0.6, 0.85, 1.0, 0.6), false)


func _is_boss_target() -> bool:
	if boss == null or not is_instance_valid(boss) or not boss.has_method("current_target"):
		return false
	return boss.current_target() == self
