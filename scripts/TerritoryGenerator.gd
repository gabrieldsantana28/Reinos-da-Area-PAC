## TerritoryGenerator.gd
## Gera territórios orgânicos alinhados ao grid usando expansão celular.
## Retorna um Set de células (Vector2i) que representa o território.

extends RefCounted
class_name TerritoryGenerator

# ─────────────────────────────────────────────
#  CONFIGURAÇÃO
# ─────────────────────────────────────────────
var grid_cols    : int   = 20
var grid_rows    : int   = 16
var min_cells    : int   = 40
var max_cells    : int   = 80
var seed_value   : int   = 0   # 0 = aleatório

const DIRECTIONS := [
	Vector2i( 1,  0),
	Vector2i(-1,  0),
	Vector2i( 0,  1),
	Vector2i( 0, -1),
]

var _rng : RandomNumberGenerator

func _init() -> void:
	_rng = RandomNumberGenerator.new()

## Gera um território com tamanho alvo (em células).
## region_offset_x: coluna inicial da região disponível (0 = lado esquerdo)
## region_width: largura máxima em colunas para este território
func generate(
	target_cells  : int,
	region_offset_x : int,
	region_width    : int,
	margin          : int = 1
) -> Dictionary:

	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	target_cells = clampi(target_cells, min_cells, max_cells)

	# Ponto de semente no centro da região
	var seed_col := region_offset_x + margin + _rng.randi_range(
		region_width / 4,
		region_width * 3 / 4
	)
	var seed_row := margin + _rng.randi_range(grid_rows / 4, grid_rows * 3 / 4)
	seed_col = clampi(seed_col, region_offset_x + margin, region_offset_x + region_width - margin - 1)
	seed_row = clampi(seed_row, margin, grid_rows - margin - 1)

	var occupied  : Dictionary = {}   # Vector2i -> true
	var frontier  : Array[Vector2i] = []
	var start_cell := Vector2i(seed_col, seed_row)
	occupied[start_cell] = true
	frontier.append(start_cell)

	# Expansão BFS com peso aleatório para forma orgânica
	while occupied.size() < target_cells and frontier.size() > 0:
		# Embaralha a fronteira para crescimento irregular
		_shuffle_array(frontier)
		var current : Vector2i = frontier.pop_front()

		for dir in DIRECTIONS:
			if occupied.size() >= target_cells:
				break
			var neighbor: Vector2i = current + dir
			if _in_region(neighbor, region_offset_x, region_width, margin) \
			   and not occupied.has(neighbor):
				# Probabilidade de expansão decresce com distância do centro (forma blob)
				var dist_factor := _dist_weight(neighbor, start_cell, region_width)
				if _rng.randf() < dist_factor:
					occupied[neighbor] = true
					frontier.append(neighbor)

	# Se não chegou ao alvo, completa com BFS puro
	if occupied.size() < target_cells:
		_fill_remaining(occupied, frontier, target_cells, region_offset_x, region_width, margin)

	return occupied

# ─────────────────────────────────────────────
#  HELPERS INTERNOS
# ─────────────────────────────────────────────
func _in_region(cell: Vector2i, ox: int, rw: int, margin: int) -> bool:
	return (
		cell.x >= ox + margin and
		cell.x <  ox + rw - margin and
		cell.y >= margin and
		cell.y <  grid_rows - margin
	)

func _dist_weight(cell: Vector2i, origin: Vector2i, region_width: int) -> float:
	var dist := float(cell.distance_to(origin))
	var max_d := float(region_width) * 0.6
	return clampf(1.0 - (dist / max_d) * 0.3, 0.45, 1.0)

func _fill_remaining(
	occupied : Dictionary,
	frontier : Array[Vector2i],
	target   : int,
	ox: int, rw: int, margin: int
) -> void:
	# Reconstrói fronteira com todos os vizinhos não ocupados das células atuais
	var new_frontier : Array[Vector2i] = []
	for cell in occupied.keys():
		for dir in DIRECTIONS:
			var nb : Vector2i = cell + dir
			if _in_region(nb, ox, rw, margin) and not occupied.has(nb):
				if not new_frontier.has(nb):
					new_frontier.append(nb)
	_shuffle_array(new_frontier)
	for nb in new_frontier:
		if occupied.size() >= target:
			break
		occupied[nb] = true

func _shuffle_array(arr: Array[Vector2i]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
