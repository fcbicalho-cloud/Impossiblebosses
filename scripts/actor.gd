extends Node2D
class_name Actor
## Base de QUALQUER entidade com vida: jogadores (PartyMember), boss e adds.
##
## Unifica hp/alive/take_damage/heal/morte, o desenho da barra de vida e o
## "juice" comum (flash branco ao tomar dano, números de dano flutuantes,
## relógio de animação para idle/aura). Subclasses definem grupos, movimento,
## mecânicas e o desenho do próprio corpo (`_draw`).
##
## Pontos de extensão:
##   _apply_damage(amount) — PartyMember sobrescreve para descontar escudo.
##   _die()               — Add sobrescreve para sair dos grupos e liberar o nó.
## Visual (subclasses chamam no _process e usam no _draw):
##   _tick_visuals(delta) — avança anim_time e decai o flash.
##   _flash_mix(color)    — mistura a cor com branco enquanto o flash está ativo.

signal died

const FLASH_TIME := 0.12

## Shader do flash de dano para sprites: mistura o pixel já modulado com branco.
## (Modulate só escurece — multiplicação — então clarear até branco exige shader.)
const FLASH_SHADER_CODE := """
shader_type canvas_item;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash_amount);
}
"""

var max_hp := 100.0
var hp := 100.0
var alive := true
var radius := 14.0

var flash_timer := 0.0
var anim_time := 0.0

var body_sprite: Sprite2D = null
var _body_sprite_mat: ShaderMaterial = null


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	flash_timer = FLASH_TIME
	_spawn_damage_number(amount)
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		_die()
	queue_redraw()


func _die() -> void:
	alive = false
	flash_timer = 0.0
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


## Cria o Sprite2D do corpo (pixel art 16×16 escalada em múltiplo inteiro) com o
## material de flash. O sprite é filho do nó, então renderiza POR CIMA do _draw
## da própria classe (sombra fica embaixo; barras devem evitar sobrepor o corpo).
func _setup_body_sprite(tex: Texture2D, px_scale: float) -> void:
	body_sprite = Sprite2D.new()
	body_sprite.texture = tex
	body_sprite.scale = Vector2(px_scale, px_scale)
	var shader := Shader.new()
	shader.code = FLASH_SHADER_CODE
	_body_sprite_mat = ShaderMaterial.new()
	_body_sprite_mat.shader = shader
	body_sprite.material = _body_sprite_mat
	add_child(body_sprite)


func _tick_visuals(delta: float) -> void:
	anim_time += delta
	flash_timer = maxf(0.0, flash_timer - delta)
	if _body_sprite_mat != null:
		var amt: float = clampf(flash_timer / FLASH_TIME, 0.0, 1.0) * 0.8
		_body_sprite_mat.set_shader_parameter("flash_amount", amt)


## Sombra elíptica no pé do sprite; chamar no início do _draw (fica sob o corpo).
func _draw_sprite_shadow() -> void:
	draw_set_transform(Vector2(0.0, radius * 0.95), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _flash_mix(base: Color) -> Color:
	if flash_timer <= 0.0:
		return base
	var t: float = clampf(flash_timer / FLASH_TIME, 0.0, 1.0)
	return base.lerp(Color(1.0, 1.0, 1.0, base.a), t * 0.8)


## Sobe um número de dano flutuante na camada de FX (grupo "fx", criada pelo
## Main). Silencioso se não houver camada de FX.
func _spawn_damage_number(amount: float) -> void:
	var fx := get_tree().get_first_node_in_group("fx")
	if fx == null:
		return
	var dn := DamageNumber.new()
	dn.setup(int(round(amount)))
	fx.add_child(dn)
	dn.global_position = global_position + Vector2(0.0, -radius - 6.0)


func _draw_hp_bar(width: float, height: float, y_offset: float, fill: Color) -> void:
	var off := Vector2(-width / 2.0, y_offset)
	draw_rect(Rect2(off, Vector2(width, height)), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(off, Vector2(width * hp_fraction(), height)), fill, true)
