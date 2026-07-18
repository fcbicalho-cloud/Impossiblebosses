extends Node2D
## Orquestrador do jogo (reconstrução limpa).
##
## Dono da arena, da máquina de estados, do HUD, do spawn, do roteamento de
## teclas e da camada de FX (`_world`, grupo "fx", onde sobem números de dano e
## explosões).
##
## Fase 3: escolha de papel (1 Guardiao / 2 Mago); o outro vira bot. Tank segura
## o boss via threat; DPS conjura no boss desviando do AoE. Clérigo (Healer) e o
## 3º slot voltam na Fase 4.

const ARENA_RECT := Rect2(60, 60, 840, 500)

## Chão/paredes: atlas 16×16 do Tiny Dungeon escalado 3× (célula de 48px no
## mundo). O ARENA_RECT NÃO é múltiplo de 48 de propósito — ele é a fronteira de
## jogo (clamp/spawns) e continua intocado; o tilemap só se encaixa por fora
## dela. Ver o aviso sobre coordenadas hardcoded no CLAUDE.md.
const TILE_SCALE := 3
const TILE_PX := 16
const CELL_PX := TILE_PX * TILE_SCALE
## Coordenadas no atlas (coluna, linha): piso de terra e parede de tijolo.
## O piso tem só liso + salpicado: o tile (3,4) tem uma faixa escura que, espalhada,
## vira mancha marrom aleatória no chão em vez de textura.
const FLOOR_TILES: Array[Vector2i] = [Vector2i(0, 4), Vector2i(1, 4)]
const WALL_TILES: Array[Vector2i] = [Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4)]
const FLOOR_VARIATION_CHANCE := 0.18
const BOSS_POS := Vector2(480, 200)
const TANK_START := Vector2(480, 290)
const HEALER_START := Vector2(360, 430)
const MAGO_START := Vector2(600, 430)

var state := "select"  # "select" | "playing" | "won" | "lost"
var human_role := ""   # "tank" | "healer" | "dps"
var difficulty_index := Difficulty.NORMAL

var boss: Boss
var party: Array = []
var human_unit = null  # Guardiao | Mago — sem tipo fixo de propósito

var _world: Node2D
var _status_label: Label
var _hint_label: Label
var _tiles: TileMapLayer
var _phase_banner_timer := 0.0


func _ready() -> void:
	_build_arena_tiles()
	_build_hud()
	_world = Node2D.new()
	_world.add_to_group("fx")
	_world.z_index = 10
	add_child(_world)
	_show_select()


## Monta o chão/paredes uma única vez (o cenário não muda entre tentativas).
## z_index -1 põe o tilemap ABAIXO do _draw do próprio Main, que ainda desenha a
## vinheta e a borda da arena por cima; personagens (z 0) e FX (z 10) ficam acima.
func _build_arena_tiles() -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = preload("res://assets/tiles/dungeon.png")
	atlas.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	for coord: Vector2i in FLOOR_TILES + WALL_TILES:
		atlas.create_tile(coord)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_PX, TILE_PX)
	tile_set.add_source(atlas, 0)

	_tiles = TileMapLayer.new()
	_tiles.tile_set = tile_set
	_tiles.scale = Vector2(TILE_SCALE, TILE_SCALE)
	_tiles.z_index = -1
	_paint_cells()
	add_child(_tiles)


## Cobre a janela inteira: célula que encosta na arena vira chão; célula
## totalmente fora vira parede. Assim a parede nunca invade a área jogável — no
## máximo sobra uma faixa fina de chão entre ela e a borda, que lê como beirada.
func _paint_cells() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260718  # cenário estável entre execuções
	# Tamanho vem do ProjectSettings, não do viewport: em headless o viewport não
	# reporta 960×640 e o cenário sairia com 4 células (pego pelo smoke_arena).
	var win_w: int = ProjectSettings.get_setting("display/window/size/viewport_width", 960)
	var win_h: int = ProjectSettings.get_setting("display/window/size/viewport_height", 640)
	var cols := int(ceil(float(win_w) / CELL_PX))
	var rows := int(ceil(float(win_h) / CELL_PX))
	for cy in range(rows):
		for cx in range(cols):
			var cell_rect := Rect2(cx * CELL_PX, cy * CELL_PX, CELL_PX, CELL_PX)
			var pool := FLOOR_TILES if cell_rect.intersects(ARENA_RECT) else WALL_TILES
			var coord: Vector2i = pool[0]
			if pool == WALL_TILES:
				coord = pool[rng.randi() % pool.size()]
			elif rng.randf() < FLOOR_VARIATION_CHANCE:
				coord = pool[1 + rng.randi() % (pool.size() - 1)]
			_tiles.set_cell(Vector2i(cx, cy), 0, coord)


func _show_select() -> void:
	state = "select"
	_clear_encounter()
	if _status_label:
		_status_label.text = ""


func _start_encounter() -> void:
	state = "playing"
	_clear_encounter()

	boss = Boss.new()
	# difficulty ANTES do add_child: o _ready do Boss já aplica hp/enrage/rez.
	boss.difficulty = Difficulty.preset(difficulty_index)
	boss.arena_rect = ARENA_RECT
	boss.position = BOSS_POS
	boss.set_world(_world)
	boss.died.connect(_on_boss_died)
	boss.phase_changed.connect(_on_phase_changed)
	add_child(boss)

	var guardiao := Guardiao.new()
	guardiao.arena_rect = ARENA_RECT
	guardiao.position = TANK_START
	guardiao.boss = boss
	guardiao.is_bot = human_role != "tank"
	guardiao.died.connect(_on_member_died)
	add_child(guardiao)
	party.append(guardiao)

	var clerigo := Clerigo.new()
	clerigo.arena_rect = ARENA_RECT
	clerigo.position = HEALER_START
	clerigo.boss = boss
	clerigo.is_bot = human_role != "healer"
	clerigo.died.connect(_on_member_died)
	add_child(clerigo)
	party.append(clerigo)

	var mago := Mago.new()
	mago.arena_rect = ARENA_RECT
	mago.position = MAGO_START
	mago.boss = boss
	mago.target = boss
	mago.is_bot = human_role != "dps"
	mago.died.connect(_on_member_died)
	add_child(mago)
	party.append(mago)

	if human_role == "tank":
		human_unit = guardiao
	elif human_role == "healer":
		human_unit = clerigo
	else:
		human_unit = mago

	if _status_label:
		_status_label.text = ""


func _clear_encounter() -> void:
	_phase_banner_timer = 0.0
	_clear_adds()
	for m in party:
		if is_instance_valid(m):
			m.queue_free()
	party.clear()
	human_unit = null
	if is_instance_valid(boss):
		boss.queue_free()
	if _world != null:
		for child in _world.get_children():
			child.queue_free()


func _process(delta: float) -> void:
	_update_hint()
	if _phase_banner_timer > 0.0:
		_phase_banner_timer -= delta
		if _phase_banner_timer <= 0.0 and state == "playing":
			_status_label.text = ""
	if state == "playing":
		_check_wipe()


func _check_wipe() -> void:
	for m in party:
		if is_instance_valid(m) and m.alive:
			return
	state = "lost"
	_status_label.text = "DERROTA (wipe)"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if human_unit is Mago:
			_try_click_target(get_global_mouse_position())
		elif human_unit is Clerigo:
			var c := human_unit as Clerigo
			c.select_ally_at(get_global_mouse_position())


func _handle_key(keycode: int) -> void:
	if keycode == KEY_R:
		_show_select()
		return

	if state == "select":
		if keycode == KEY_LEFT:
			difficulty_index = (difficulty_index + Difficulty.COUNT - 1) % Difficulty.COUNT
		elif keycode == KEY_RIGHT:
			difficulty_index = (difficulty_index + 1) % Difficulty.COUNT
		elif keycode == KEY_1:
			human_role = "tank"
			_start_encounter()
		elif keycode == KEY_2:
			human_role = "healer"
			_start_encounter()
		elif keycode == KEY_3:
			human_role = "dps"
			_start_encounter()
		return

	if state != "playing" or human_unit == null or not is_instance_valid(human_unit):
		return

	if keycode == KEY_TAB:
		if human_unit is Mago:
			human_unit.cycle_target()
		elif human_unit is Clerigo:
			var c := human_unit as Clerigo
			c.cycle_ally_target()
		get_viewport().set_input_as_handled()
	elif keycode == KEY_1 and human_unit.has_method("activate_ability"):
		human_unit.activate_ability(1)
	elif keycode == KEY_2 and human_unit.has_method("activate_ability"):
		human_unit.activate_ability(2)
	elif keycode == KEY_3 and human_unit.has_method("activate_ability"):
		human_unit.activate_ability(3)
	elif keycode == KEY_4 and human_unit.has_method("activate_ability"):
		human_unit.activate_ability(4)


func _try_click_target(world_pos: Vector2) -> void:
	var best = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("targetable"):
		if not is_instance_valid(n):
			continue
		var r := 20.0
		if n.has_method("pick_radius"):
			r = n.pick_radius()
		var d: float = world_pos.distance_to(n.position)
		if d <= r and d < best_d:
			best_d = d
			best = n
	if best != null:
		human_unit.target = best


## Aviso de mudança de fase. Fica alguns segundos e some sozinho — a fase em si
## já aparece continuamente no hint, isto é só o alerta do momento da virada.
func _on_phase_changed(new_phase: int) -> void:
	if state != "playing":
		return
	_status_label.text = "FASE %d" % new_phase
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.25))
	_phase_banner_timer = 2.5


func _on_boss_died() -> void:
	if state != "playing":
		return
	state = "won"
	_phase_banner_timer = 0.0
	_clear_adds()  # senão os adds sobreviventes continuam batendo após a vitória
	_status_label.text = "VITORIA!"
	_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))


func _clear_adds() -> void:
	for a: Node in get_tree().get_nodes_in_group("add"):
		if is_instance_valid(a):
			a.queue_free()


func _on_member_died(_unused = null) -> void:
	pass  # o wipe é checado a cada frame em _check_wipe()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_status_label = Label.new()
	_status_label.position = Vector2(ARENA_RECT.position.x, 14)
	_status_label.add_theme_font_size_override("font_size", 30)
	_add_text_outline(_status_label, 6)
	layer.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(ARENA_RECT.position.x, ARENA_RECT.end.y + 8)
	_hint_label.add_theme_font_size_override("font_size", 15)
	_add_text_outline(_hint_label, 4)
	layer.add_child(_hint_label)


## Contorno preto no texto do HUD. Sem isso, letra branca sobre o piso claro do
## tileset fica ilegível (o fundo antigo era escuro e não precisava).
func _add_text_outline(label: Label, size: int) -> void:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", size)


func _update_hint() -> void:
	if _hint_label == null:
		return
	if state == "select":
		var d := Difficulty.preset(difficulty_index)
		_hint_label.text = "Dificuldade: < %s >  (setas Esq/Dir)   -   Boss %d HP | adds %d por onda | enrage %ds | rez %d\nEscolha seu papel:   1 = Guardiao (Tank)    2 = Clerigo (Healer)    3 = Mago (DPS)\nOs outros dois viram bots. R volta pra essa tela a qualquer momento." % [
			d.label, int(d.boss_hp), d.adds_per_wave, int(d.enrage_seconds), d.rez_charges]
		return
	if state == "won":
		_hint_label.text = "Voce venceu! Pressione R para escolher papel de novo."
		return
	if state == "lost":
		_hint_label.text = "Pressione R para tentar de novo (ou trocar de papel)."
		return

	var members := ""
	for m in party:
		if is_instance_valid(m):
			if members != "":
				members += "   "
			members += _member_summary(m)
	var boss_txt := ""
	if is_instance_valid(boss):
		var timer_txt := "ENRAGE x%.2f" % boss.damage_multiplier() if boss.enraged else "enrage em %ds" % int(ceil(boss.enrage_remaining))
		var adds := boss.active_add_count()
		var adds_txt := "   Adds: %d" % adds if adds > 0 else ""
		boss_txt = "[%s] Boss: %d HP (fase %d)   Rez: %d   %s%s" % [
			Difficulty.label_for(difficulty_index), int(round(boss.hp)), boss.phase,
			boss.rez_charges, timer_txt, adds_txt]
	# Três linhas: controles / grupo / boss. Numa linha só, o texto estourava a
	# largura da janela e cortava o fim.
	_hint_label.text = "%s\n%s\n%s" % [_control_hint(), members, boss_txt]


func _member_summary(m: PartyMember) -> String:
	var tag := "(bot)" if m.is_bot else "(voce)"
	var hp_txt := "%d/%d HP" % [int(round(m.hp)), int(round(m.max_hp))]
	if m is Guardiao:
		var g := m as Guardiao
		return "Guardiao %s %s Ira %d" % [tag, hp_txt, int(round(g.ira))]
	elif m is Clerigo:
		var c := m as Clerigo
		return "Clerigo %s %s Mana %d" % [tag, hp_txt, int(round(c.mana))]
	return "Mago %s %s" % [tag, hp_txt]


func _control_hint() -> String:
	if human_role == "tank":
		return "WASD mover | auto-attack no boss | 1 Provocar | 2 Muralha"
	elif human_role == "healer":
		return "WASD mover | Tab/clique escolhe aliado (sem escolha: o mais ferido) | 1 Cura(parado) | 2 Rapida | 3 Escudo | 4 Rez"
	return "WASD mover | PARADO conjura | Tab/clique alvo"


## Só o que fica POR CIMA do tilemap: vinheta e a borda que marca a fronteira
## exata de jogo (o chão em si vem do TileMapLayer, em z -1). O preenchimento
## opaco e a grade antigos saíram — o tile já dá textura ao piso.
func _draw() -> void:
	var vign := Color(0, 0, 0, 0.10)
	var b := 26.0
	draw_rect(Rect2(ARENA_RECT.position, Vector2(ARENA_RECT.size.x, b)), vign, true)
	draw_rect(Rect2(Vector2(ARENA_RECT.position.x, ARENA_RECT.end.y - b), Vector2(ARENA_RECT.size.x, b)), vign, true)
	draw_rect(Rect2(ARENA_RECT.position, Vector2(b, ARENA_RECT.size.y)), vign, true)
	draw_rect(Rect2(Vector2(ARENA_RECT.end.x - b, ARENA_RECT.position.y), Vector2(b, ARENA_RECT.size.y)), vign, true)

	draw_rect(ARENA_RECT, Color(0.35, 0.42, 0.60), false, 2.0)
	draw_rect(ARENA_RECT.grow(-4.0), Color(0.5, 0.6, 0.85, 0.5), false, 1.0)
