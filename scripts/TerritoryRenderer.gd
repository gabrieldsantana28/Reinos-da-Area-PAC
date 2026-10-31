## TerritoryRenderer.gd
## Node2D que desenha o grid e os dois territorios usando _draw().
## Direção de arte: cartografia medieval com grid em pergaminho.

extends Node2D
class_name TerritoryRenderer
@export var textura_fundo : Texture2D

# ─────────────────────────────────────────────
#  PALETA MEDIEVAL (extraida do hud.png)
# ─────────────────────────────────────────────

const COLOR_GRID_BG       := Color("#bba375")
const COLOR_GRID_LINE     := Color(1, 1, 1, 0.45)
const COLOR_PLAYER_FILL   := Color(0.16, 0.38, 0.72, 0.72)
const COLOR_PLAYER_BORDER := Color(0.45, 0.72, 1.00, 0.90)
const COLOR_PLAYER_INNER  := Color(0.20, 0.50, 0.85, 0.18)
const COLOR_ENEMY_FILL    := Color(0.44, 0.08, 0.08, 0.90)
const COLOR_ENEMY_BORDER  := Color(0.70, 0.18, 0.18, 0.00)
const COLOR_DIVIDER       := Color(0.76, 0.58, 0.18, 0.82)

# Espessuras ajustadas para resolucao 1080p
const GRID_LINE_WIDTH     := 1.0
const BORDER_LINE_WIDTH   := 3.5
const DIVIDER_WIDTH       := 3.5

var cell_size      : int        = 60
var grid_cols      : int        = 32
var grid_rows      : int        = 14
var player_cells   : Dictionary = {}
var enemy_cells    : Dictionary = {}
var enemy_revealed : bool       = false

var _anim_progress : float = 0.0
var _animating     : bool  = false
var _flash_color   : Color = Color.TRANSPARENT
var _flash_alpha   : float = 0.0
var _particles     : Array[Dictionary] = []
var _result_type   : String = ""
var vs_icon        : Sprite2D

func _ready() -> void:
	set_process(true)
	
	# Cria o ícone do VS e deixa ele preparado no mapa
	vs_icon = Sprite2D.new()
	if ResourceLoader.exists("res://assets/icons/vs.png"):
		vs_icon.texture = load("res://assets/icons/vs.png")
	vs_icon.scale = Vector2(0.3, 0.3) 
	vs_icon.modulate.a = 0.0 # Começa totalmente transparente (invisível)
	vs_icon.z_index = 10     # Garante que fique por cima do grid e dos territórios
	add_child(vs_icon)

func _process(delta: float) -> void:
	var changed := false
	if _animating:
		_anim_progress = minf(_anim_progress + delta * 2.2, 1.0)
		if _anim_progress >= 1.0:
			_animating = false
		changed = true
		
	if _flash_alpha > 0.0:
		# Decai em exatamente 1 segundo (de 1.0 para 0.0)
		_flash_alpha = maxf(0.0, _flash_alpha - delta)
		
		# Atualiza a animação de acordo com o resultado
		for p in _particles:
			if _result_type == "WIN" or _result_type == "LOSE":
				p.rot += delta * p.speed
				p.phase += delta * 8.0
			elif _result_type == "DRAW":
				# Vento corre da esquerda para a direita
				p.pos.x += delta * p.speed
				# Leve oscilação orgânica no Y
				p.pos.y += sin(p.phase) * delta * 15.0
				p.phase += delta * 10.0
				
		changed = true
		
	if changed:
		queue_redraw()

func set_territories(p_cells: Dictionary, e_cells: Dictionary) -> void:
	player_cells   = p_cells
	enemy_cells    = e_cells
	enemy_revealed = false
	_anim_progress = 0.0
	_animating     = true
	queue_redraw()

func play_result_flash(type: String) -> void:
	_result_type = type
	_flash_alpha = 1.0 # Duração exata de 1 segundo
	_particles.clear()
	
	var total_w := cell_size * grid_cols
	var total_h := cell_size * grid_rows
	
	if type == "WIN":
		_flash_color = Color(0.25, 0.95, 0.35, 1.0)
		for i in 40:
			_particles.append({
				"pos": Vector2(randf_range(0, total_w), randf_range(0, total_h)),
				"size": randf_range(10.0, 30.0),
				"rot": randf_range(0, PI),
				"speed": randf_range(1.5, 4.0) * (1 if randi() % 2 == 0 else -1),
				"phase": randf_range(0, PI * 2)
			})
	elif type == "LOSE":
		_flash_color = Color(0.95, 0.15, 0.15, 1.0)
		for i in 40:
			_particles.append({
				"pos": Vector2(randf_range(0, total_w), randf_range(0, total_h)),
				"size": randf_range(12.0, 32.0),
				"rot": randf_range(0, PI), # Vai girar como o brilho verde
				"speed": randf_range(0.5, 2.0) * (1 if randi() % 2 == 0 else -1),
				"phase": randf_range(0, PI * 2)
			})
	elif type == "DRAW":
		_flash_color = Color(0.85, 0.85, 0.85, 1.0) # Fundo do vento acinzentado claro
		for i in 35:
			_particles.append({
				# Começa mais atrás na esquerda para viajar pela tela
				"pos": Vector2(randf_range(-total_w * 0.8, total_w * 0.1), randf_range(0, total_h)),
				"length": randf_range(80.0, 300.0), # Listras compridas
				"speed": randf_range(1200.0, 2500.0), # Alta velocidade
				"phase": randf_range(0, PI * 2),
				"thickness": randf_range(1.0, 4.0)
			})
			
	queue_redraw()

func reveal_enemy_grid() -> void:
	enemy_revealed = true
	queue_redraw()

func _draw() -> void:
	var total_w := cell_size * grid_cols
	var total_h := cell_size * grid_rows
	var map_rect := Rect2(0, 0, total_w, total_h)

	# 1. Fundo do mapa
	if textura_fundo:
		var tex_size := textura_fundo.get_size()
		var map_ratio := float(total_w) / float(total_h)
		var tex_ratio := tex_size.x / tex_size.y
		
		var src_w := tex_size.x
		var src_h := tex_size.y
		var src_x := 0.0
		var src_y := 0.0
		
		if tex_ratio > map_ratio:
			src_w = tex_size.y * map_ratio
			src_x = (tex_size.x - src_w) / 2.0
		else:
			src_h = tex_size.x / map_ratio
			src_y = (tex_size.y - src_h) / 2.0
			
		var src_rect := Rect2(src_x, src_y, src_w, src_h)
		draw_texture_rect_region(textura_fundo, map_rect, src_rect)
	else:
		draw_rect(map_rect, COLOR_GRID_BG)

	var mid_x := (grid_cols / 2) * cell_size

	_draw_territory(player_cells, COLOR_PLAYER_FILL, COLOR_PLAYER_BORDER, true)
	_draw_territory(enemy_cells,  COLOR_ENEMY_FILL,  COLOR_ENEMY_BORDER,  false)

	_draw_grid_selective()

	if not player_cells.is_empty():
		for key in player_cells.keys():
			var cell: Vector2i = key
			var pos := Vector2(cell.x * cell_size + 1, cell.y * cell_size + 1)
			var rect := Rect2(pos, Vector2(cell_size - 2, cell_size - 2))
			var c := COLOR_PLAYER_INNER
			c.a *= _anim_progress
			draw_rect(rect, c)

	draw_line(
		Vector2(mid_x, 0),
		Vector2(mid_x, total_h),
		COLOR_DIVIDER,
		DIVIDER_WIDTH
	)
	draw_line(
		Vector2(mid_x + 1, 0),
		Vector2(mid_x + 1, total_h),
		Color(1.0, 0.90, 0.55, 0.18),
		1.0
	)

	# --- OVERLAY DE BRILHO E PARTICULAS ---
	if _flash_alpha > 0.0:
		var fc := _flash_color
		# Para o vento o overlay é mais suave
		fc.a = _flash_alpha * (0.60 if _result_type != "DRAW" else 0.15) 
		draw_rect(Rect2(0, 0, total_w, total_h), fc)
		
		for p in _particles:
			if _result_type == "WIN":
				_draw_star_sparkle(p.pos, p.size, p.rot, _flash_alpha, p.phase)
			elif _result_type == "LOSE":
				_draw_red_x(p.pos, p.size, p.rot, _flash_alpha, p.phase)
			elif _result_type == "DRAW":
				_draw_wind_line(p.pos, p.length, _flash_alpha, p.thickness)
			
func _draw_star_sparkle(pos: Vector2, size: float, rot: float, alpha: float, phase: float) -> void:
	var pulse := (sin(phase) * 0.4 + 0.6) * alpha 
	var c := Color(1.0, 1.0, 1.0, pulse)
	
	var dir1 := Vector2(cos(rot), sin(rot)) * size
	var dir2 := Vector2(cos(rot + PI/2.0), sin(rot + PI/2.0)) * size
	draw_line(pos - dir1, pos + dir1, c, 2.5, true)
	draw_line(pos - dir2, pos + dir2, c, 2.5, true)
	
	var dir3 := Vector2(cos(rot + PI/4.0), sin(rot + PI/4.0)) * (size * 0.4)
	var dir4 := Vector2(cos(rot - PI/4.0), sin(rot - PI/4.0)) * (size * 0.4)
	draw_line(pos - dir3, pos + dir3, c, 1.2, true)
	draw_line(pos - dir4, pos + dir4, c, 1.2, true)
	
	draw_circle(pos, size * 0.15, Color(1.0, 1.0, 1.0, pulse * 1.5))

func _draw_red_x(pos: Vector2, size: float, rot: float, alpha: float, phase: float) -> void:
	var pulse := (sin(phase) * 0.3 + 0.7) * alpha 
	var c_glow := Color(0.95, 0.1, 0.1, pulse * 0.5)
	var c_core := Color(1.0, 0.6, 0.6, pulse)
	
	# X com rotação
	var dir1 := Vector2(cos(rot + PI/4.0), sin(rot + PI/4.0)) * size
	var dir2 := Vector2(cos(rot - PI/4.0), sin(rot - PI/4.0)) * size
	
	# Sombra / Brilho Externo
	draw_line(pos - dir1, pos + dir1, c_glow, 6.0, true)
	draw_line(pos - dir2, pos + dir2, c_glow, 6.0, true)
	
	# Miolo
	draw_line(pos - dir1, pos + dir1, c_core, 2.5, true)
	draw_line(pos - dir2, pos + dir2, c_core, 2.5, true)

func _draw_wind_line(pos: Vector2, length: float, alpha: float, thickness: float) -> void:
	var c := Color(1.0, 1.0, 1.0, alpha * 0.8)
	var end_pos := pos + Vector2(length, 0)
	draw_line(pos, end_pos, c, thickness, true)

func _draw_territory(cells: Dictionary, fill_col: Color, border_col: Color, animated: bool) -> void:
	if cells.is_empty(): return
	var alpha_mult := _anim_progress if animated else 1.0

	for key in cells.keys():
		var cell: Vector2i = key
		var pos  := Vector2(cell.x * cell_size, cell.y * cell_size)
		var rect := Rect2(pos, Vector2(cell_size, cell_size))
		var c    := fill_col
		c.a     *= alpha_mult
		draw_rect(rect, c)

	for key in cells.keys():
		var cell: Vector2i = key
		var px: float = cell.x * cell_size
		var py: float = cell.y * cell_size
		var bc := border_col
		bc.a   *= alpha_mult

		var neighbors := [
			Vector2i(cell.x,     cell.y - 1),
			Vector2i(cell.x,     cell.y + 1),
			Vector2i(cell.x - 1, cell.y    ),
			Vector2i(cell.x + 1, cell.y    ),
		]
		var edges := [
			[Vector2(px,             py),             Vector2(px + cell_size, py)],
			[Vector2(px,             py + cell_size), Vector2(px + cell_size, py + cell_size)],
			[Vector2(px,             py),             Vector2(px,             py + cell_size)],
			[Vector2(px + cell_size, py),             Vector2(px + cell_size, py + cell_size)],
		]
		for i in 4:
			if not cells.has(neighbors[i]):
				draw_line(edges[i][0], edges[i][1], bc, BORDER_LINE_WIDTH)

func _draw_grid_selective() -> void:
	for c in range(grid_cols + 1):
		var x := (c * cell_size) + 0.5 
		for r in range(grid_rows):
			var left_enemy  := enemy_cells.has(Vector2i(c - 1, r)) and not enemy_revealed
			var right_enemy := enemy_cells.has(Vector2i(c,     r)) and not enemy_revealed
			if left_enemy and right_enemy: continue
			draw_line(Vector2(x, r * cell_size), Vector2(x, (r + 1) * cell_size), COLOR_GRID_LINE, GRID_LINE_WIDTH)

	for r in range(grid_rows + 1):
		var y := (r * cell_size) + 0.5
		for c in range(grid_cols):
			var top_enemy    := enemy_cells.has(Vector2i(c, r - 1)) and not enemy_revealed
			var bottom_enemy := enemy_cells.has(Vector2i(c, r    )) and not enemy_revealed
			if top_enemy and bottom_enemy: continue
			draw_line(Vector2(c * cell_size, y), Vector2((c + 1) * cell_size, y), COLOR_GRID_LINE, GRID_LINE_WIDTH)

	for r in range(grid_rows + 1):
		var y := r * cell_size
		for c in range(grid_cols):
			var top_enemy    := enemy_cells.has(Vector2i(c, r - 1)) and not enemy_revealed
			var bottom_enemy := enemy_cells.has(Vector2i(c, r    )) and not enemy_revealed
			if top_enemy and bottom_enemy: continue
			draw_line(Vector2(c * cell_size, y), Vector2((c + 1) * cell_size, y), COLOR_GRID_LINE, GRID_LINE_WIDTH)

func play_vs_animation() -> void:
	if not vs_icon or not vs_icon.texture: return
	
	var total_w := cell_size * grid_cols
	var total_h := cell_size * grid_rows
	var center := Vector2(total_w / 2.0, total_h / 2.0)
	
	# Começa posicionado 250 pixels acima do centro
	vs_icon.position = center - Vector2(0, 250)
	vs_icon.modulate.a = 0.0
	
	# Cria o animador (Tween)
	var tween = create_tween()
	
	# 1. Faz cair rapidamente pro centro e ficar opaco ao mesmo tempo
	tween.set_parallel(true)
	tween.tween_property(vs_icon, "position", center, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(vs_icon, "modulate:a", 1.0, 0.25)
	
	# 2. Desliga o paralelo para que ele espere terminar a queda, pausa um pouquinho, e desaparece
	tween.set_parallel(false)
	tween.tween_interval(0.4) # Tempo que fica visível no meio da tela
	tween.tween_property(vs_icon, "modulate:a", 0.0, 0.2) # Some rapidamente
