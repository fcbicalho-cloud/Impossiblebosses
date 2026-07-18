extends Node2D
class_name Actor
## Base de QUALQUER entidade com vida: jogadores (PartyMember), boss e adds.
##
## Unifica hp/alive/take_damage/heal/morte e o desenho da barra de vida — antes
## cada tipo reimplementava isso do seu jeito. Subclasses definem grupos,
## movimento, mecânicas e o desenho do próprio corpo (`_draw`).
##
## Pontos de extensão:
##   _apply_damage(amount) — PartyMember sobrescreve para descontar escudo.
##   _die()               — Add sobrescreve para sair dos grupos e liberar o nó.

signal died

var max_hp := 100.0
var hp := 100.0
var alive := true
var radius := 14.0


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		_die()
	queue_redraw()


func _die() -> void:
	alive = false
	died.emit()


func heal(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	queue_redraw()
	return hp - before


func hp_fraction() -> float:
	if max_hp <= 0.0:
		return 0.0
	return hp / max_hp


func pick_radius() -> float:
	return radius + 6.0


func _draw_hp_bar(width: float, height: float, y_offset: float, fill: Color) -> void:
	var off := Vector2(-width / 2.0, y_offset)
	draw_rect(Rect2(off, Vector2(width, height)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(width * hp_fraction(), height)), fill, true)
