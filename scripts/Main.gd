## Main.gd
## Cena raiz: orquestra GameManager, TerritoryGenerator, TerritoryRenderer e UI.
## Direcao de arte: HUD medieval cartografico inspirado no hud.png.

extends Node2D

# ─────────────────────────────────────────────
#  CONFIGURACOES
# ─────────────────────────────────────────────
const CELL_SIZE         : int   = 60
const GRID_COLS         : int   = 32
const GRID_ROWS         : int   = 13   
const HALF_COLS         : int   = GRID_COLS / 2
const HUD_TOP_HEIGHT    : int   = 80
const HUD_BOTTOM_HEIGHT : int   = 220  
const TOTAL_ROUNDS      : int   = 10

# Controle de diferenca de tamanho do inimigo (em porcentagem: 0.05 = 5%, 0.15 = 15%)
const ENEMY_DIFF_MIN_PCT : float = 0.05  # Diferenca minima
const ENEMY_DIFF_MAX_PCT : float = 0.15  # Diferenca maxima

# ─────────────────────────────────────────────
#  PALETA DE CORES MEDIEVAIS
# ─────────────────────────────────────────────
const C_BG_DARK       := Color8( 18,  14,  10, 255)
const C_BG_PANEL      := Color8( 28,  22,  14, 245)
const C_BORDER_GOLD   := Color8(148, 112,  38, 255)
const C_BORDER_GOLD2  := Color8(196, 156,  60, 180)
const C_TEXT_GOLD     := Color8(212, 180,  90, 255)
const C_TEXT_GOLD2    := Color8(240, 210, 120, 255)
const C_TEXT_WHITE    := Color8(238, 232, 218, 255)
const C_TEXT_MUTED    := Color8(160, 148, 120, 255)
const C_BLUE_MAIN     := Color8( 60, 110, 190, 255)
const C_BLUE_LIGHT    := Color8(120, 175, 255, 255)
const C_BLUE_DIM      := Color8( 35,  65, 120, 200)
const C_RED_MAIN      := Color8(160,  30,  30, 255)
const C_RED_BORDER    := Color8(200,  60,  60, 255)
const C_RED_DIM       := Color8( 90,  18,  18, 200)
const C_GREEN_MAIN    := Color8( 30, 100,  70, 255)
const C_GREEN_LIGHT   := Color8( 80, 180, 120, 255)
const C_GREEN_DIM     := Color8( 18,  58,  40, 200)
const C_BAR_BG        := Color8( 42,  34,  20, 255)
const C_BAR_GREEN     := Color8( 68, 168,  68, 255)
const C_BAR_ORANGE    := Color8(220, 140,  40, 255)
const C_SEPARATOR     := Color8(100,  80,  30, 140)

# ─────────────────────────────────────────────
#  REFERENCIAS DE NOS E VARIAVEIS
# ─────────────────────────────────────────────
var game_manager  : GameManager
var territory_gen : TerritoryGenerator
var renderer      : TerritoryRenderer

var lbl_area_value    : Label
var lbl_area_unit     : Label
var bar_dominance     : ProgressBar
var lbl_dominance_pct : Label
var hud_round_dots    : Array[ColorRect] = []
var lbl_world_phase   : Label

var lbl_terrain      : Label
var lbl_multiplier   : Label
var lbl_streak       : Label
var lbl_atk          : Label
var lbl_def          : Label
var lbl_timer        : Label

var btn_row           : HBoxContainer
var result_vbox       : VBoxContainer
var btn_attack        : Button
var btn_defend        : Button
var btn_retreat       : Button

var lbl_result_title  : Label
var lbl_result_detail : Label
var lbl_result_areas  : Label
var btn_continue      : Button

var panel_summary     : PanelContainer
var lbl_sum_title     : Label
var lbl_sum_stats     : Label
var lbl_sum_dom       : Label
var btn_restart       : Button

var _current_round   : int   = 0
var _player_area_val : float = 0.0
var _dominance_val   : float = 0.0

var _wins            : int   = 0
var _losses          : int   = 0
var _retreats        : int   = 0

var _last_timer_sec  : int   = -1 
var _pending_action  : int   = 2  

# ─────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────
func _ready() -> void:
	# --- CARREGANDO OS CURSORES CUSTOMIZADOS ---
	# Cursor Padrão (Seta)
	var cursor_default = load("res://assets/cursor/default.png")
	if cursor_default:
		Input.set_custom_mouse_cursor(cursor_default, Input.CURSOR_ARROW, Vector2(0, 0))
		
	# Cursor de Clique (Mãozinha/Pointer)
	var cursor_pointer = load("res://assets/cursor/pointer.png")
	if cursor_pointer:
		# Define o cursor da mãozinha. Dependendo do desenho, você pode precisar mudar o Vector2(0,0) 
		# para alinhar a pontinha do dedo indicador da sua imagem.
		Input.set_custom_mouse_cursor(cursor_pointer, Input.CURSOR_POINTING_HAND, Vector2(0, 0))
	# -------------------------------------------

	var win_w := CELL_SIZE * GRID_COLS
	var win_h := CELL_SIZE * GRID_ROWS + HUD_TOP_HEIGHT + HUD_BOTTOM_HEIGHT
	
	get_window().size = Vector2i(win_w, win_h)
	var screen_size := DisplayServer.screen_get_size()
	get_window().position = (screen_size / 2) - (get_window().size / 2)
	DisplayServer.window_set_title("Reinos da Área")

	_build_game_manager()
	_build_territory_system()
	_build_ui()
	_connect_signals()

	_start_new_campaign()

func _start_new_campaign() -> void:
	if AudioManager: AudioManager.play_music("bg_music")
	
	_player_area_val = float(randi_range(30, 45))
	_dominance_val   = 0.0
	_wins            = 0
	_losses          = 0
	_retreats        = 0
	_current_round   = 0
	
	if game_manager:
		game_manager.reset_campaign()
	
	_update_dominance(_dominance_val)
	_update_area_display(_player_area_val)
	
	await get_tree().create_timer(0.3).timeout
	_start_round()

# ─────────────────────────────────────────────
#  SISTEMAS
# ─────────────────────────────────────────────
func _build_game_manager() -> void:
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	add_child(game_manager)

func _build_territory_system() -> void:
	territory_gen           = TerritoryGenerator.new()
	territory_gen.grid_cols = GRID_COLS
	territory_gen.grid_rows = GRID_ROWS
	
	territory_gen.min_cells = 10 
	territory_gen.max_cells = 200

	renderer           = TerritoryRenderer.new()
	renderer.name      = "Renderer"
	renderer.cell_size = CELL_SIZE
	renderer.grid_cols = GRID_COLS
	renderer.grid_rows = GRID_ROWS
	renderer.position  = Vector2(0, HUD_TOP_HEIGHT)
	
	renderer.textura_fundo = load("res://assets/icons/fundo.jpg")
	
	add_child(renderer)

# ─────────────────────────────────────────────
#  BUILD UI GERAL
# ─────────────────────────────────────────────
func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(screen)

	_build_top_bar(screen)
	_build_bottom_hud(screen)
	_build_summary_overlay(ui)

# ─────────────────────────────────────────────
#  BARRA SUPERIOR
# ─────────────────────────────────────────────
func _build_top_bar(parent: Control) -> void:
	var top_bg := PanelContainer.new()
	top_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bg.custom_minimum_size = Vector2(0, HUD_TOP_HEIGHT)
	top_bg.offset_bottom = HUD_TOP_HEIGHT
	_apply_panel_style(top_bg, C_BG_DARK, C_BORDER_GOLD, 0, 2, 0, 0)
	parent.add_child(top_bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	top_bg.add_child(hbox)

	var sec_area := _make_top_section(0, true)
	hbox.add_child(sec_area)

	var area_inner := HBoxContainer.new()
	area_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	area_inner.add_theme_constant_override("separation", 12)
	area_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec_area.add_child(area_inner)

	var area_label_vbox := VBoxContainer.new()
	area_label_vbox.add_theme_constant_override("separation", 0)
	area_inner.add_child(area_label_vbox)

	lbl_area_value = _make_label("0", 32, C_BLUE_LIGHT, "Cinzel")
	lbl_area_unit  = _make_label("ÁREA TOTAL", 16, C_TEXT_MUTED, "Source Sans 3")
	area_label_vbox.add_child(lbl_area_value)
	area_label_vbox.add_child(lbl_area_unit)

	_add_vertical_separator(hbox)

	var sec_dom := _make_top_section(0, true)
	hbox.add_child(sec_dom)

	var dom_vbox := VBoxContainer.new()
	dom_vbox.add_theme_constant_override("separation", 6)
	dom_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dom_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dom_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sec_dom.add_child(dom_vbox)

	var dom_title := _make_label("OBJETIVO: DOMINAR 70% DO MAPA                         ", 16, C_TEXT_MUTED, "Source Sans 3")
	dom_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dom_vbox.add_child(dom_title)

	var dom_bar_row := HBoxContainer.new()
	dom_bar_row.add_theme_constant_override("separation", 10)
	dom_bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dom_vbox.add_child(dom_bar_row)

	bar_dominance = _make_progress_bar(260, 18)
	bar_dominance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dom_bar_row.add_child(bar_dominance)

	lbl_dominance_pct = _make_label("0%", 16, C_TEXT_GOLD, "Source Sans 3")
	lbl_dominance_pct.custom_minimum_size = Vector2(45, 0)
	dom_bar_row.add_child(lbl_dominance_pct)

	_add_vertical_separator(hbox)

	var sec_rounds := _make_top_section(0, true)
	hbox.add_child(sec_rounds)

	var rounds_vbox := VBoxContainer.new()
	rounds_vbox.add_theme_constant_override("separation", 6)
	rounds_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rounds_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rounds_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sec_rounds.add_child(rounds_vbox)

	var rounds_title := _make_label("RODADAS", 16, C_TEXT_MUTED, "Source Sans 3")
	rounds_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rounds_vbox.add_child(rounds_title)

	var dots_row := HBoxContainer.new()
	dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_row.add_theme_constant_override("separation", 10)
	rounds_vbox.add_child(dots_row)

	hud_round_dots.clear()
	for i in TOTAL_ROUNDS:
		var dot := _make_round_dot(false)
		dots_row.add_child(dot)
		hud_round_dots.append(dot)

	_add_vertical_separator(hbox)

	var sec_phase := _make_top_section(0, true)
	hbox.add_child(sec_phase)

	var phase_vbox := VBoxContainer.new()
	phase_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	phase_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phase_vbox.add_theme_constant_override("separation", 2)
	sec_phase.add_child(phase_vbox)

	lbl_world_phase = _make_label("MUNDO I . FASE 1", 18, C_TEXT_GOLD, "Cinzel")
	lbl_world_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_vbox.add_child(lbl_world_phase)

	lbl_terrain = _make_label("TERRENO:  PLANÍCIE", 16, C_TEXT_WHITE, "Source Sans 3")
	lbl_terrain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_vbox.add_child(lbl_terrain)
	
	var shield_icon := TextureRect.new()
	shield_icon.texture = load("res://assets/icons/brasao.png")
	shield_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shield_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	shield_icon.custom_minimum_size = Vector2(200, 200)
	shield_icon.size = Vector2(140, 140)
	
	shield_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	shield_icon.position = Vector2(0, 5) 
	parent.add_child(shield_icon)

# ─────────────────────────────────────────────
#  HUD INFERIOR
# ─────────────────────────────────────────────
func _build_bottom_hud(parent: Control) -> void:
	var bottom_bg := PanelContainer.new()
	bottom_bg.anchor_top    = 1.0
	bottom_bg.anchor_bottom = 1.0
	bottom_bg.anchor_left   = 0.0
	bottom_bg.anchor_right  = 1.0
	bottom_bg.offset_top    = -HUD_BOTTOM_HEIGHT
	bottom_bg.offset_bottom = -20 
	_apply_panel_style(bottom_bg, C_BG_DARK, C_BORDER_GOLD, 0, 2, 0, 0)
	parent.add_child(bottom_bg)

	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 0)
	bottom_bg.add_child(main_hbox)

	# --- LADO ESQUERDO: INFORMAÇÕES DE BATALHA ---
	var left_panel := _make_bottom_section(450)
	main_hbox.add_child(left_panel)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lv.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(lv)

	var title_lbl := _make_label("INFORMAÇÕES DE BATALHA", 14, C_TEXT_GOLD2, "Cinzel")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(title_lbl)

	var sep_h := _make_horizontal_line()
	lv.add_child(sep_h)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(grid_center)

	var data_grid := GridContainer.new()
	data_grid.columns = 3
	data_grid.add_theme_constant_override("h_separation", 30)
	data_grid.add_theme_constant_override("v_separation", 12)
	grid_center.add_child(data_grid)

	lbl_multiplier = _add_stat_cell(data_grid, "MODIFICADOR TERRENO", "Nenhum", C_TEXT_WHITE)
	lbl_streak     = _add_stat_cell(data_grid, "SEQUÊNCIA", "0 vitórias", C_BAR_ORANGE)
	lbl_timer      = _add_stat_cell(data_grid, "TEMPO", "60s", C_TEXT_GOLD)
	
	lbl_atk        = _add_stat_cell(data_grid, "FORÇA ATAQUE", "1.0x", C_RED_BORDER, "res://assets/icons/swords.png")
	lbl_def        = _add_stat_cell(data_grid, "FORÇA DEFESA", "1.0x", C_BLUE_LIGHT, "res://assets/icons/shield.png")

	_add_vertical_separator(main_hbox)

	# --- CENTRO: BOTOES / RESULTADOS ---
	var center_panel := _make_bottom_section(0, true)
	main_hbox.add_child(center_panel)

	var center_vbox := VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 10)
	center_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.alignment             = BoxContainer.ALIGNMENT_CENTER
	center_panel.add_child(center_vbox)

	btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 25)
	center_vbox.add_child(btn_row)

	btn_attack  = _make_action_button("ATACAR", "Iniciar combate", C_RED_DIM, C_RED_MAIN, C_RED_BORDER, "X", "res://assets/icons/swords.png")
	btn_defend  = _make_action_button("DEFENDER", "Preparar território", C_BLUE_DIM, C_BLUE_MAIN, C_BLUE_LIGHT, "Z", "res://assets/icons/shield.png")
	btn_retreat = _make_action_button("RECUAR", "Cancelar ação", C_GREEN_DIM, C_GREEN_MAIN, C_GREEN_LIGHT, "C", "res://assets/icons/boot.png")
	
	btn_row.add_child(btn_attack)
	btn_row.add_child(btn_defend)
	btn_row.add_child(btn_retreat)

	btn_attack.pressed.connect(func(): _on_action(GameManager.Action.ATTACK))
	btn_defend.pressed.connect(func(): _on_action(GameManager.Action.DEFEND))
	btn_retreat.pressed.connect(func(): _on_action(GameManager.Action.RETREAT))

	result_vbox = VBoxContainer.new()
	result_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_vbox.add_theme_constant_override("separation", 6)
	result_vbox.visible = false
	center_vbox.add_child(result_vbox)

	lbl_result_title  = _make_label("", 24, Color.WHITE, "Cinzel")
	lbl_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_vbox.add_child(lbl_result_title)

	lbl_result_detail = _make_label("", 14, C_TEXT_WHITE, "Libre Baskerville")
	lbl_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_result_detail.custom_minimum_size = Vector2(480, 0)
	result_vbox.add_child(lbl_result_detail)

	lbl_result_areas  = _make_label("", 15, C_TEXT_MUTED, "Source Sans 3")
	lbl_result_areas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_vbox.add_child(lbl_result_areas)

	btn_continue = _make_action_button("PRÓXIMA RODADA", "", C_GREEN_DIM, C_GREEN_MAIN, C_GREEN_LIGHT, "")
	btn_continue.custom_minimum_size = Vector2(260, 60)
	btn_continue.pressed.connect(_on_continue_pressed)
	result_vbox.add_child(btn_continue)

	_add_vertical_separator(main_hbox)

	# --- LADO DIREITO: ARQUETIPO ---
	var right_panel := _make_bottom_section(500)
	main_hbox.add_child(right_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rv.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_child(rv)

	var arch_header_hbox := HBoxContainer.new()
	arch_header_hbox.add_theme_constant_override("separation", 10)
	rv.add_child(arch_header_hbox)

	var arch_title := _make_label("ARQUÉTIPO ATIVO", 16, C_TEXT_MUTED, "Source Sans 3")
	arch_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arch_header_hbox.add_child(arch_title)

	var badge_panel := PanelContainer.new()
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = C_RED_DIM
	badge_sb.border_color = C_RED_BORDER
	badge_sb.set_border_width_all(1)
	badge_sb.corner_radius_top_left = 6
	badge_sb.corner_radius_top_right = 6
	badge_sb.corner_radius_bottom_left = 6
	badge_sb.corner_radius_bottom_right = 6
	badge_panel.add_theme_stylebox_override("panel", badge_sb)
	arch_header_hbox.add_child(badge_panel)

	var badge_margin := MarginContainer.new()
	badge_margin.add_theme_constant_override("margin_left", 8)
	badge_margin.add_theme_constant_override("margin_right", 8)
	badge_margin.add_theme_constant_override("margin_top", 3)
	badge_margin.add_theme_constant_override("margin_bottom", 3)
	badge_panel.add_child(badge_margin)

	var arch_name := _make_label("GUERREIRO Nv.2", 12, C_TEXT_WHITE, "Cinzel")
	badge_margin.add_child(arch_name)

	var skill_sep := _make_horizontal_line()
	rv.add_child(skill_sep)

	var passiva_title := _make_label("PASSIVA: Legião de Cativos", 14, C_TEXT_GOLD, "Source Sans 3")
	var passiva_desc := _make_label("Cada vitória soma +2% de bônus de área ao Ataque (max +10%). Ao perder, a moral quebra e o bônus zera.", 12, C_TEXT_WHITE, "Libre Baskerville")
	passiva_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passiva_desc.custom_minimum_size = Vector2(400, 0)
	rv.add_child(passiva_title)
	rv.add_child(passiva_desc)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	rv.add_child(spacer)

	var ativa_header := HBoxContainer.new()
	ativa_header.add_theme_constant_override("separation", 15)
	rv.add_child(ativa_header)

	var ativa_title := _make_label("ATIVA: Aço Duplo", 14, C_TEXT_GOLD, "Source Sans 3")
	ativa_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ativa_header.add_child(ativa_title)

	var btn_fake_skill := Button.new()
	btn_fake_skill.text = " ATIVAR (1) "
	btn_fake_skill.custom_minimum_size = Vector2(90, 26)
	btn_fake_skill.add_theme_font_size_override("font_size", 12)
	btn_fake_skill.add_theme_color_override("font_color", C_BG_DARK)
	btn_fake_skill.add_theme_color_override("font_hover_color", C_BG_DARK)
	btn_fake_skill.focus_mode = Control.FOCUS_NONE
	
	# Define a mãozinha também para o botão de habilidade
	btn_fake_skill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var sb_skill_normal := StyleBoxFlat.new()
	sb_skill_normal.bg_color = C_TEXT_GOLD
	sb_skill_normal.corner_radius_top_left = 4
	sb_skill_normal.corner_radius_top_right = 4
	sb_skill_normal.corner_radius_bottom_left = 4
	sb_skill_normal.corner_radius_bottom_right = 4
	var sb_skill_hover := sb_skill_normal.duplicate()
	sb_skill_hover.bg_color = C_TEXT_GOLD2

	btn_fake_skill.add_theme_stylebox_override("normal", sb_skill_normal)
	btn_fake_skill.add_theme_stylebox_override("hover", sb_skill_hover)
	btn_fake_skill.add_theme_stylebox_override("pressed", sb_skill_normal)
	ativa_header.add_child(btn_fake_skill)
	
	btn_fake_skill.mouse_entered.connect(func(): if AudioManager: AudioManager.play_sfx("ui_hover", 0.1))
	btn_fake_skill.pressed.connect(func(): if AudioManager: AudioManager.play_sfx("ui_click"))

	var ativa_desc := _make_label("Dobra o poder atual da Legião de Cativos apenas para esta rodada.", 12, C_TEXT_WHITE, "Libre Baskerville")
	ativa_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ativa_desc.custom_minimum_size = Vector2(400, 0)
	rv.add_child(ativa_desc)

# ─────────────────────────────────────────────
#  RESUMO OVERLAY
# ─────────────────────────────────────────────
func _build_summary_overlay(ui: CanvasLayer) -> void:
	panel_summary = PanelContainer.new()
	panel_summary.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	panel_summary.custom_minimum_size = Vector2(680, 380)
	panel_summary.offset_left   = -340
	panel_summary.offset_top    = -190
	panel_summary.offset_right  = 340
	panel_summary.offset_bottom = 190
	
	_apply_panel_style(panel_summary, C_BG_DARK, C_BORDER_GOLD, 3, 3, 3, 3, 8, 12)
	panel_summary.visible = false
	ui.add_child(panel_summary)

	var rv := VBoxContainer.new()
	rv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 24)
	panel_summary.add_child(rv)

	lbl_sum_title = _make_label("FIM DA FASE", 40, C_TEXT_GOLD, "Cinzel")
	lbl_sum_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(lbl_sum_title)

	var sep_h := _make_horizontal_line()
	sep_h.custom_minimum_size = Vector2(460, 2)
	rv.add_child(sep_h)

	lbl_sum_stats = _make_label("Vitórias: 0  |  Derrotas: 0  |  Recuos: 0", 22, C_TEXT_WHITE, "Source Sans 3")
	lbl_sum_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(lbl_sum_stats)

	lbl_sum_dom = _make_label("DOMÍNIO FINAL: 0%", 28, C_BLUE_LIGHT, "Cinzel")
	lbl_sum_dom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(lbl_sum_dom)

	btn_restart = _make_action_button("JOGAR NOVAMENTE", "", C_GREEN_DIM, C_GREEN_MAIN, C_GREEN_LIGHT, "")
	btn_restart.custom_minimum_size = Vector2(300, 60)
	btn_restart.pressed.connect(func():
		panel_summary.visible = false
		_start_new_campaign()
	)
	rv.add_child(btn_restart)

func _connect_signals() -> void:
	game_manager.phase_changed.connect(_on_phase_changed)
	game_manager.round_result.connect(_on_round_result)
	game_manager.score_updated.connect(_on_score_updated)
	game_manager.timer_tick.connect(_on_timer_tick)
	game_manager.new_round_started.connect(_on_new_round_started)

# ─────────────────────────────────────────────
#  LOGICA DE RODADA
# ─────────────────────────────────────────────
func _start_round() -> void:
	_pending_action = GameManager.Action.RETREAT
	
	var p_cells_target = int(_player_area_val)
	var e_cells_target : int
	
	var diff_pct = randf_range(ENEMY_DIFF_MIN_PCT, ENEMY_DIFF_MAX_PCT)

	if randi() % 2 == 0:
		e_cells_target = int(p_cells_target * (1.0 + diff_pct))
	else:
		e_cells_target = int(p_cells_target * (1.0 - diff_pct))

	if p_cells_target == e_cells_target:
		e_cells_target += 1 if randi() % 2 == 0 else -1

	p_cells_target = clampi(p_cells_target, territory_gen.min_cells, territory_gen.max_cells)
	e_cells_target = clampi(e_cells_target, territory_gen.min_cells, territory_gen.max_cells)

	var spawn_width := 12
	var p_offset := HALF_COLS - spawn_width
	var e_offset := HALF_COLS
	
	var player_cells := territory_gen.generate(p_cells_target, p_offset, spawn_width, 1)
	var enemy_cells  := territory_gen.generate(e_cells_target, e_offset, spawn_width, 1)

	while player_cells.size() == enemy_cells.size():
		e_cells_target += 1 if randi() % 2 == 0 else -1
		e_cells_target = clampi(e_cells_target, territory_gen.min_cells, territory_gen.max_cells)
		enemy_cells = territory_gen.generate(e_cells_target, e_offset, spawn_width, 1)

	renderer.set_territories(player_cells, enemy_cells)
	
	if AudioManager: AudioManager.play_sfx("map_unroll")
	renderer.play_vs_animation()

	_player_area_val = float(player_cells.size())
	var actual_e_area = float(enemy_cells.size())

	_update_area_display(_player_area_val)
	game_manager.start_new_round(_player_area_val, actual_e_area)

func _on_phase_changed(phase: String) -> void:
	match phase:
		"ANALYSIS":
			_set_buttons_enabled(false)
			btn_row.visible = true
			result_vbox.visible = false
			await get_tree().create_timer(1.5).timeout
			_set_buttons_enabled(true)
		"DECISION":
			_set_buttons_enabled(true)
		"RESULT":
			_set_buttons_enabled(false)
		"RESTART":
			btn_row.visible = true
			result_vbox.visible = false
			await get_tree().create_timer(0.4).timeout
			_start_round()

func _on_round_result(result: String, p_area: float, e_area: float) -> void:
	_play_result_sequence(result, p_area, e_area)

func _play_result_sequence(result: String, p_area: float, e_area: float) -> void:
	await get_tree().create_timer(1.0).timeout
	
	var delay_acao := 2.0
	
	if AudioManager:
		match _pending_action:
			GameManager.Action.ATTACK:
				AudioManager.play_sfx("action_attack")
				delay_acao = 3.0
			GameManager.Action.DEFEND:
				AudioManager.play_sfx("action_defend")
				delay_acao = 3.0
			GameManager.Action.RETREAT:
				AudioManager.play_sfx("action_retreat")
				delay_acao = 2.0
				
	await get_tree().create_timer(delay_acao).timeout
	
	renderer.reveal_enemy_grid()
	renderer.play_result_flash(result)
	
	if AudioManager: AudioManager.play_sfx("result_" + result.to_lower())
	
	if result == "WIN":
		_wins += 1
		lbl_result_title.text = "VITÓRIA"
		lbl_result_title.add_theme_color_override("font_color", Color(0.30, 0.95, 0.45))
		
		_dominance_val += 10.0
		
		if p_area > e_area:
			lbl_result_detail.text = "ATACAR: Seu território era MAIOR. Você venceu, ganhou 10% de Domínio e expandiu sua área em 10%!"
			_player_area_val += _player_area_val * 0.10 
		else:
			lbl_result_detail.text = "DEFENDER: O inimigo era maior e você resistiu! Ganhou 10% de Domínio e a área cresceu 5%!"
			_player_area_val += _player_area_val * 0.05
			
	elif result == "LOSE":
		_losses += 1
		lbl_result_title.text = "DERROTA"
		lbl_result_title.add_theme_color_override("font_color", Color(0.95, 0.28, 0.28))
		
		if p_area < e_area:
			lbl_result_detail.text = "ATACAR FALHOU: O inimigo era maior. Você sofreu um duro golpe e perdeu 20% da sua área."
			_player_area_val -= _player_area_val * 0.20
		else:
			lbl_result_detail.text = "DEFENDER FALHOU: Você era o maior, deveria ter atacado! O erro de cálculo custou 10% da sua área."
			_player_area_val -= _player_area_val * 0.10
			
	elif result == "DRAW":
		_retreats += 1
		lbl_result_title.text = "RECUO"
		lbl_result_title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.30))
		lbl_result_detail.text = "RECUAR: Ação segura. Seu Domínio se mantém intacto, mas a inércia fez você perder 5% do território."
		_player_area_val -= _player_area_val * 0.05

	_dominance_val = clampf(_dominance_val, 0.0, 100.0)
	_player_area_val = maxf(10.0, _player_area_val) 

	_update_dominance(_dominance_val)

	var diff_pct := absf((p_area - e_area) / maxf(p_area, e_area)) * 100.0
	lbl_result_areas.text  = "Seu território: %d   Inimigo: %d   Diferença: %.1f%%" % [int(p_area), int(e_area), diff_pct]
	
	btn_continue.text = "" 
	var custom_lbl = btn_continue.find_child("LblTitle", true, false)
	
	if _current_round >= TOTAL_ROUNDS:
		if custom_lbl: custom_lbl.text = "VER RESUMO"
	else:
		if custom_lbl: custom_lbl.text = "PRÓXIMA RODADA"
		
	btn_row.visible = false
	result_vbox.visible = true

func _on_continue_pressed() -> void:
	if _current_round >= TOTAL_ROUNDS:
		result_vbox.visible = false
		btn_row.visible = true
		_show_summary()
	else:
		game_manager.request_restart()

func _show_summary() -> void:
	lbl_sum_stats.text = "Vitórias: %d  |  Derrotas: %d  |  Recuos: %d" % [_wins, _losses, _retreats]
	lbl_sum_dom.text = "DOMÍNIO FINAL: %.0f%%" % _dominance_val
	
	if AudioManager: AudioManager.stop_music()
	
	if _dominance_val >= 70.0:
		lbl_sum_dom.add_theme_color_override("font_color", C_BAR_GREEN)
		lbl_sum_title.text = "FASE CONCLUÍDA!"
		if AudioManager: AudioManager.play_music("phase_win")
	else:
		lbl_sum_dom.add_theme_color_override("font_color", C_BAR_ORANGE)
		lbl_sum_title.text = "FASE FRACASSADA"
		if AudioManager: AudioManager.play_music("phase_lose")
		
	panel_summary.visible = true

func _on_score_updated(_score: int, streak: int) -> void: 
	if lbl_streak:
		lbl_streak.text = "%d vitórias" % streak

func _on_timer_tick(secs_left: float) -> void:
	if lbl_timer:
		var sec_int = ceili(secs_left)
		lbl_timer.text = "%ds" % sec_int
		if secs_left <= 10.0:
			lbl_timer.add_theme_color_override("font_color", C_RED_MAIN)
			if _last_timer_sec == -1 and sec_int > 0:
				_last_timer_sec = 10 
				if AudioManager: AudioManager.play_sfx("timer_tick")
		else:
			lbl_timer.add_theme_color_override("font_color", C_TEXT_GOLD)
			_last_timer_sec = -1

func _on_new_round_started(round_num: int, _diff: float) -> void:
	_current_round = min(round_num, TOTAL_ROUNDS)
	_update_round_dots(_current_round)
	
	var world  := 1
	var phase  := 1
	var labels: Array[String] = ["I", "II", "III", "IV", "V"]
	var world_label: String = labels[clampi(world - 1, 0, labels.size() - 1)]
	lbl_world_phase.text = "MUNDO %s . FASE %d" % [world_label, phase]

func _on_action(action: GameManager.Action) -> void:
	_set_buttons_enabled(false) 
	_pending_action = action
	game_manager.resolve_action(action)

func _set_buttons_enabled(enabled: bool) -> void:
	btn_attack.disabled  = not enabled
	btn_defend.disabled  = not enabled
	btn_retreat.disabled = not enabled
	var alpha := 1.0 if enabled else 0.38
	btn_attack.modulate.a  = alpha
	btn_defend.modulate.a  = alpha
	btn_retreat.modulate.a = alpha

func _update_area_display(area: float) -> void:
	var a_int = int(area)
	lbl_area_value.text = "%d" % a_int
	if lbl_atk: lbl_atk.text = "1.0x"
	if lbl_def: lbl_def.text = "1.0x"

func _update_dominance(pct: float) -> void:
	bar_dominance.value    = pct
	lbl_dominance_pct.text = "%.0f%%" % pct
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = C_BAR_GREEN if pct >= 70.0 else (C_BAR_ORANGE if pct >= 40.0 else C_BAR_GREEN.darkened(0.3))
	bar_fill.corner_radius_top_left     = 3
	bar_fill.corner_radius_top_right    = 3
	bar_fill.corner_radius_bottom_left  = 3
	bar_fill.corner_radius_bottom_right = 3
	bar_dominance.add_theme_stylebox_override("fill", bar_fill)

func _update_round_dots(completed: int) -> void:
	for i in hud_round_dots.size():
		var dot := hud_round_dots[i]
		if i < completed - 1: dot.color = C_BORDER_GOLD
		elif i == completed - 1: dot.color = C_BAR_ORANGE
		else: dot.color = C_SEPARATOR

func _make_top_section(min_width: int, expand: bool = false) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left",   20)
	mc.add_theme_constant_override("margin_right",  20)
	mc.add_theme_constant_override("margin_top",    12)
	mc.add_theme_constant_override("margin_bottom", 12)
	if min_width > 0: mc.custom_minimum_size = Vector2(min_width, 0)
	if expand: mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return mc

func _make_bottom_section(min_width: int, expand: bool = false) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left",   24)
	mc.add_theme_constant_override("margin_right",  24)
	mc.add_theme_constant_override("margin_top",    16)
	mc.add_theme_constant_override("margin_bottom", 16)
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if min_width > 0: mc.custom_minimum_size = Vector2(min_width, 0)
	if expand: mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return mc

func _add_vertical_separator(parent: Container) -> void:
	var sep := VSeparator.new()
	
	var linha := StyleBoxLine.new()
	linha.color = C_SEPARATOR
	linha.vertical = true
	linha.thickness = 3
	
	linha.grow_end = -10.0 
	linha.grow_begin = -10.0 
	
	sep.add_theme_stylebox_override("separator", linha)
	
	parent.add_child(sep)

func _make_horizontal_line() -> Control:
	var c := ColorRect.new()
	c.custom_minimum_size = Vector2(0, 1)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.color = C_SEPARATOR
	return c

func _make_round_dot(active: bool) -> ColorRect:
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(20, 20)
	dot.color = C_BORDER_GOLD if active else C_SEPARATOR
	return dot

func _make_progress_bar(min_w: int, height: int) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0; pb.max_value = 100.0; pb.value = 0.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(min_w, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BAR_BG; bg.border_color = C_BORDER_GOLD; bg.set_border_width_all(1)
	bg.corner_radius_top_left = 3; bg.corner_radius_top_right = 3; bg.corner_radius_bottom_left = 3; bg.corner_radius_bottom_right = 3
	pb.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_BAR_GREEN
	fill.corner_radius_top_left = 3; fill.corner_radius_top_right = 3; fill.corner_radius_bottom_left = 3; fill.corner_radius_bottom_right = 3
	pb.add_theme_stylebox_override("fill", fill)
	return pb

func _make_label(txt: String, size: int, color: Color, font_hint: String = "Source Sans 3") -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	
	var font_path := ""
	
	if font_hint == "Cinzel":
		font_path = "res://assets/fonts/Cinzel.ttf"
	elif font_hint == "Libre Baskerville":
		font_path = "res://assets/fonts/Baskerville.ttf"
	else:
		font_path = "res://assets/fonts/SourceSans.ttf"
		
	if ResourceLoader.exists(font_path):
		var custom_font = load(font_path)
		lbl.add_theme_font_override("font", custom_font)
		
	return lbl

func _make_action_button(titulo: String, subtitulo: String, bg_dark: Color, col_mid: Color, col_light: Color, key_hint: String, icon_path: String = "") -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(210, 100) 
	btn.focus_mode = Control.FOCUS_NONE
	
	# Define a mãozinha também para os botões de ação e navegação!
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)    
	margin.add_theme_constant_override("margin_bottom", 10) 
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	btn.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)
	
	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(50, 50)
	icon_box.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_box)
	
	if icon_path != "":
		var icon_rect := TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(50, 50)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_box.add_child(icon_rect)
	else:
		icon_box.visible = false
		
	var text_vbox := VBoxContainer.new()
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	text_vbox.add_theme_constant_override("separation", 0) 
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)
	
	var lbl_title := _make_label(titulo, 18, C_TEXT_GOLD, "Cinzel")
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_title.custom_minimum_size = Vector2(0, 30) 
	lbl_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_title.name = "LblTitle"
	text_vbox.add_child(lbl_title)
	
	if subtitulo != "":
		var lbl_sub := _make_label(subtitulo, 16, C_TEXT_WHITE, "Source Sans 3")
		lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_sub.custom_minimum_size = Vector2(0, 22) 
		lbl_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(lbl_sub)

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = bg_dark
	sb_normal.border_color = C_BORDER_GOLD
	sb_normal.set_border_width_all(2)
	sb_normal.corner_radius_top_left = 6
	sb_normal.corner_radius_top_right = 6
	sb_normal.corner_radius_bottom_left = 6
	sb_normal.corner_radius_bottom_right = 6
	
	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = bg_dark.lightened(0.14)
	sb_hover.border_color = C_TEXT_GOLD2
	
	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = bg_dark.darkened(0.12)
	
	var sb_disabled := sb_normal.duplicate() as StyleBoxFlat
	sb_disabled.bg_color = bg_dark.darkened(0.30)
	sb_disabled.border_color = C_SEPARATOR

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	
	btn.mouse_entered.connect(func(): if AudioManager and not btn.disabled: AudioManager.play_sfx("ui_hover", 0.05))
	btn.pressed.connect(func(): if AudioManager: AudioManager.play_sfx("ui_click"))
	
	return btn

func _apply_panel_style(p: PanelContainer, bg: Color, border: Color, bw_top: float = 1.5, bw_bot: float = 1.5, bw_left: float = 1.5, bw_right: float = 1.5, radius: int = 0, padding: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg; sb.border_color = border
	sb.border_width_top = bw_top; sb.border_width_bottom = bw_bot; sb.border_width_left = bw_left; sb.border_width_right = bw_right
	
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	
	if padding > 0:
		sb.content_margin_left = padding
		sb.content_margin_right = padding
		sb.content_margin_top = padding
		sb.content_margin_bottom = padding
		
	p.add_theme_stylebox_override("panel", sb)

func _add_stat_cell(grid: GridContainer, label: String, value: String, color: Color, icon_path: String = "") -> Label:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	grid.add_child(vb)
	
	var lbl_title := _make_label(label, 14, C_TEXT_MUTED, "Source Sans 3")
	vb.add_child(lbl_title)
	
	var lbl_val := _make_label(value, 20, color, "Source Sans 3")
	
	if icon_path != "":
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.alignment = BoxContainer.ALIGNMENT_BEGIN
		
		var icon_rect := TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(24, 24)
		
		hb.add_child(icon_rect)
		hb.add_child(lbl_val)
		vb.add_child(hb)
	else:
		vb.add_child(lbl_val)
		
	return lbl_val
