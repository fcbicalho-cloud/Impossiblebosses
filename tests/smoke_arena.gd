extends SceneTree
## Smoke test headless da cena principal:
##   godot --headless --path . -s tests/smoke_arena.gd
## Carrega a Main de verdade, entra num encontro (papel healer) e confere que o
## tilemap foi pintado: chão dentro da arena, parede nos cantos (fora dela) e
## nenhuma célula de parede invadindo a área jogável.

const ARENA := Rect2(60, 60, 840, 500)
const CELL := 48

var _main: Node2D = null
var _frame := 0


func _initialize() -> void:
	_main = (load("res://Main.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(_main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame == 5:
		_main.human_role = "healer"
		_main._start_encounter()
	elif _frame >= 15:
		_report()


func _report() -> void:
	var tiles: TileMapLayer = _main._tiles
	if tiles == null:
		print("SMOKE FALHOU: tilemap nao foi criado")
		quit(1)
		return

	var floor_coords: Array[Vector2i] = _main.FLOOR_TILES
	var painted := tiles.get_used_cells().size()

	# Centro da arena deve ser chão; canto superior esquerdo da tela, parede.
	var center_cell := Vector2i(int(ARENA.get_center().x / CELL), int(ARENA.get_center().y / CELL))
	var center_is_floor: bool = floor_coords.has(tiles.get_cell_atlas_coords(center_cell))
	var corner_is_wall: bool = not floor_coords.has(tiles.get_cell_atlas_coords(Vector2i(0, 0)))

	# Nenhuma parede pode tocar a área jogável.
	var wall_invades := false
	for cell: Vector2i in tiles.get_used_cells():
		if floor_coords.has(tiles.get_cell_atlas_coords(cell)):
			continue
		if Rect2(cell.x * CELL, cell.y * CELL, CELL, CELL).intersects(ARENA):
			wall_invades = true
			break

	var party_ok: bool = _main.party.size() == 3 and _main.human_unit is Clerigo
	var ok: bool = painted > 0 and center_is_floor and corner_is_wall and not wall_invades and party_ok
	print("SMOKE %s: celulas=%d centro_chao=%s canto_parede=%s parede_invade=%s grupo=%s" % [
		"OK" if ok else "FALHOU", painted, center_is_floor, corner_is_wall, wall_invades, party_ok])
	quit(0 if ok else 1)
