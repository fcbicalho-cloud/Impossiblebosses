extends Node2D
class_name AbilityBar
## Barra de habilidades do papel que o humano está jogando.
##
## Consome o contrato documentado no CLAUDE.md — `get_ability_info(index)` e
## `get_cast_status()` — que até agora existia sem ninguém do outro lado: o HUD
## só imprimia texto fixo, então cooldown e custo eram invisíveis em jogo.
##
## Mostra por slot: tecla, nome, custo de recurso e o cooldown restante (com
## escurecimento proporcional). Slot fica vermelho quando falta recurso.

const SLOT_W := 118.0  # cabe "Cura Rapida" sem cortar
const SLOT_H := 46.0
const SLOT_GAP := 6.0
const MAX_SLOTS := 4

## Unidade humana; setada pelo Main. Sem ela a barra não desenha nada.
var unit = null


func _process(_delta: float) -> void:
	queue_redraw()


## Recurso atual do papel (Ira do Guardiao, Mana do Clerigo), para saber se dá
## para pagar a habilidade. -1 significa "este papel não tem recurso".
func _recurso_atual() -> float:
	if unit is Guardiao:
		return (unit as Guardiao).ira
	if unit is Clerigo:
		return (unit as Clerigo).mana
	return -1.0


func _draw() -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.has_method("get_ability_info"):
		return

	var font := ThemeDB.fallback_font
	var recurso := _recurso_atual()

	for i in range(1, MAX_SLOTS + 1):
		var info: Dictionary = unit.get_ability_info(i)
		if info.is_empty():
			continue
		var nome: String = info.get("name", "?")
		var custo: float = info.get("cost", 0.0)
		var cd: float = info.get("cd_remaining", 0.0)

		var x: float = (i - 1) * (SLOT_W + SLOT_GAP)
		var rect := Rect2(x, 0.0, SLOT_W, SLOT_H)

		var sem_recurso: bool = recurso >= 0.0 and custo > 0.0 and recurso < custo
		var pronta: bool = cd <= 0.0 and not sem_recurso

		draw_rect(rect, Color(0.06, 0.07, 0.10, 0.85), true)
		# Escurece de baixo para cima conforme o cooldown corre.
		if cd > 0.0:
			var total: float = maxf(cd, 0.001)
			var frac: float = clampf(cd / _cooldown_total(i, total), 0.0, 1.0)
			draw_rect(Rect2(x, SLOT_H * (1.0 - frac), SLOT_W, SLOT_H * frac),
				Color(0.0, 0.0, 0.0, 0.55), true)

		var borda := Color(0.45, 0.85, 0.5) if pronta else Color(0.85, 0.35, 0.3) if sem_recurso else Color(0.4, 0.45, 0.55)
		draw_rect(rect, borda, false, 2.0)

		var cor_texto := Color(1, 1, 1) if pronta else Color(0.72, 0.72, 0.78)
		draw_string(font, Vector2(x + 7.0, 17.0), "%d  %s" % [i, nome],
			HORIZONTAL_ALIGNMENT_LEFT, SLOT_W - 12.0, 14, cor_texto)

		var rodape := ""
		if cd > 0.0:
			rodape = "%.1fs" % cd
		elif custo > 0.0:
			rodape = "%d de recurso" % int(custo)
		else:
			rodape = "pronta"
		var cor_rodape := Color(1.0, 0.75, 0.35) if cd > 0.0 else (Color(0.9, 0.45, 0.4) if sem_recurso else Color(0.6, 0.85, 0.7))
		draw_string(font, Vector2(x + 7.0, 36.0), rodape,
			HORIZONTAL_ALIGNMENT_LEFT, SLOT_W - 12.0, 12, cor_rodape)


## Cooldown cheio de cada slot, para a barra de escurecimento ter escala. Vem das
## constantes dos papéis; slot sem cooldown devolve o próprio valor atual (a
## fração vira 1 e o slot só escurece por inteiro).
func _cooldown_total(index: int, atual: float) -> float:
	if unit is Guardiao:
		if index == 1:
			return Guardiao.TAUNT_COOLDOWN
		if index == 2:
			return Guardiao.MURALHA_COOLDOWN
	elif unit is Clerigo:
		if index == 2:
			return Clerigo.RAPIDA_COOLDOWN
		if index == 3:
			return Clerigo.ESCUDO_COOLDOWN
	return atual
