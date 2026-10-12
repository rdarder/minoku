extends Control

const OrchardCore = preload("res://scripts/OrchardCore.gd")
const GameData = preload("res://scripts/GameData.gd")

const MINE_TEXTURE = preload("res://assets/icons/mine.svg")
const CROSS_TEXTURE = preload("res://assets/icons/cross.svg")
const EXPLOSION_TEXTURE = preload("res://assets/icons/explosion.svg")
const BOMB_TEXTURE = MINE_TEXTURE

enum GameState { PLAYING, WON, LOST, SHOWING_SOLUTION }
var game_state: GameState = GameState.PLAYING

# Cell states: 0 = Empty, 1 = Bomb, 2 = Player Crossed
var grid_size: int = 6
var pending_next_size: int = 6
var puzzle_data: Dictionary = {}
var player_grid: Array = [] # 2D array of ints (0, 1, 2)
var current_palette: Array = []
var start_time: int = 0
var moves_count: int = 0
var assist_mode: bool = true
var hints_used_this_level: bool = false
var current_run_score: int = 0
var displayed_score: int = 0

# Node references
@onready var background: ColorRect = $Background
@onready var grid_container: GridContainer = $ScreenCenter/PortraitLayout/GridCenter/GridContainer
@onready var portrait_layout: VBoxContainer = $ScreenCenter/PortraitLayout
@onready var landscape_layout: HBoxContainer = $ScreenCenter/LandscapeLayout
@onready var land_grid_center: CenterContainer = $ScreenCenter/LandscapeLayout/LandGridCenter
@onready var port_grid_center: CenterContainer = $ScreenCenter/PortraitLayout/GridCenter

# HUD references (Portrait)
@onready var timer_label: Label = $ScreenCenter/PortraitLayout/TopHUD/TopRow/TimerBadge/Margin/TimerLabel
@onready var bomb_counter: Label = $ScreenCenter/PortraitLayout/TopHUD/TopRow/BombBadge/Margin/BombCounter
@onready var score_label: Label = $ScreenCenter/PortraitLayout/TopHUD/ScoreRow/ScoreBadge/Margin/ScoreLabel
@onready var score_badge: PanelContainer = $ScreenCenter/PortraitLayout/TopHUD/ScoreRow/ScoreBadge
@onready var bomb_badge: PanelContainer = $ScreenCenter/PortraitLayout/TopHUD/TopRow/BombBadge
@onready var timer_badge: PanelContainer = $ScreenCenter/PortraitLayout/TopHUD/TopRow/TimerBadge
@onready var btn_restart_same: Button = $ScreenCenter/PortraitLayout/BottomHUD/BtnRestartSame
@onready var btn_carry_on: Button = $ScreenCenter/PortraitLayout/BottomHUD/BtnCarryOn
@onready var btn_assist: Button = $ScreenCenter/PortraitLayout/BottomHUD/BtnAssist
@onready var top_hud: VBoxContainer = $ScreenCenter/PortraitLayout/TopHUD
@onready var bottom_hud: HBoxContainer = $ScreenCenter/PortraitLayout/BottomHUD

# HUD references (Landscape)
@onready var timer_label_land: Label = $ScreenCenter/LandscapeLayout/SideLeft/TimerBadgeLand/Margin/TimerLabelLand
@onready var bomb_counter_land: Label = $ScreenCenter/LandscapeLayout/SideLeft/BombBadgeLand/Margin/BombCounterLand
@onready var score_label_land: Label = $ScreenCenter/LandscapeLayout/SideLeft/ScoreBadgeLand/Margin/ScoreLabelLand
@onready var score_badge_land: PanelContainer = $ScreenCenter/LandscapeLayout/SideLeft/ScoreBadgeLand
@onready var bomb_badge_land: PanelContainer = $ScreenCenter/LandscapeLayout/SideLeft/BombBadgeLand
@onready var timer_badge_land: PanelContainer = $ScreenCenter/LandscapeLayout/SideLeft/TimerBadgeLand
@onready var btn_restart_same_land: Button = $ScreenCenter/LandscapeLayout/SideRight/BtnRestartSameLand
@onready var btn_carry_on_land: Button = $ScreenCenter/LandscapeLayout/SideRight/BtnCarryOnLand
@onready var btn_assist_land: Button = $ScreenCenter/LandscapeLayout/SideRight/BtnAssistLand

# Overlays
@onready var modal_overlay: ColorRect = $ModalOverlay
@onready var difficulty_modal: PanelContainer = $ModalOverlay/DifficultyModal
@onready var cards_container: BoxContainer = $ModalOverlay/DifficultyModal/Margin/ModalVBox/CardsContainer
@onready var btn_6x6: Button = $ModalOverlay/DifficultyModal/Margin/ModalVBox/CardsContainer/Btn6x6
@onready var btn_8x8: Button = $ModalOverlay/DifficultyModal/Margin/ModalVBox/CardsContainer/Btn8x8
@onready var btn_10x10: Button = $ModalOverlay/DifficultyModal/Margin/ModalVBox/CardsContainer/Btn10x10
@onready var btn_close_modal: Button = $ModalOverlay/DifficultyModal/Margin/ModalVBox/BtnCloseModal

@onready var banner_overlay: Control = $BannerOverlay
@onready var banner_panel: PanelContainer = $BannerOverlay/BannerPanel
@onready var banner_label: Label = $BannerOverlay/BannerPanel/Margin/BannerVBox/BannerLabel
@onready var banner_sub_label: Label = $BannerOverlay/BannerPanel/Margin/BannerVBox/BannerSubLabel
@onready var breakdown_box: VBoxContainer = $BannerOverlay/BannerPanel/Margin/BannerVBox/BreakdownBox
@onready var level_pts_title: Label = $BannerOverlay/BannerPanel/Margin/BannerVBox/BreakdownBox/LevelPtsRow/LevelPtsTitle
@onready var level_pts_val: Label = $BannerOverlay/BannerPanel/Margin/BannerVBox/BreakdownBox/LevelPtsRow/LevelPtsVal
@onready var time_pts_val: Label = $BannerOverlay/BannerPanel/Margin/BannerVBox/BreakdownBox/TimePtsRow/TimePtsVal
@onready var award_total_label: Label = $BannerOverlay/BannerPanel/Margin/BannerVBox/AwardTotalLabel
@onready var flying_score_label: Label = $BannerOverlay/FlyingScoreLabel

func _ready():
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_setup_difficulty_modal_styles()
	_setup_badge_styles()
	_setup_banner_styles()
	_start_new_game(6)
	_update_responsive_layout()

func _on_viewport_size_changed():
	_update_responsive_layout()
	_refresh_cell_views()

func _process(_delta):
	if game_state == GameState.PLAYING and start_time > 0 and not puzzle_data.is_empty():
		var elapsed = (Time.get_ticks_msec() - start_time) / 1000
		var mins = elapsed / 60
		var secs = elapsed % 60
		var time_str = "%02d:%02d" % [mins, secs]
		timer_label.text = time_str
		timer_label_land.text = time_str

func _update_responsive_layout():
	var vp_size = get_viewport_rect().size
	var is_landscape = vp_size.x > vp_size.y
	
	if is_landscape:
		portrait_layout.visible = false
		landscape_layout.visible = true
		if grid_container.get_parent() != land_grid_center:
			grid_container.reparent(land_grid_center)
			
		# Responsive DifficultyModal (Landscape: side-by-side cards)
		if difficulty_modal and cards_container:
			difficulty_modal.custom_minimum_size = Vector2(920, 0)
			cards_container.vertical = false
			cards_container.add_theme_constant_override("separation", 16)
			btn_6x6.custom_minimum_size = Vector2(260, 130)
			btn_8x8.custom_minimum_size = Vector2(260, 130)
			btn_10x10.custom_minimum_size = Vector2(260, 130)
	else:
		portrait_layout.visible = true
		landscape_layout.visible = false
		if grid_container.get_parent() != port_grid_center:
			grid_container.reparent(port_grid_center)
			
		# Responsive DifficultyModal (Portrait: vertical cards)
		if difficulty_modal and cards_container:
			difficulty_modal.custom_minimum_size = Vector2(600, 0)
			cards_container.vertical = true
			cards_container.add_theme_constant_override("separation", 18)
			btn_6x6.custom_minimum_size = Vector2(0, 116)
			btn_8x8.custom_minimum_size = Vector2(0, 116)
			btn_10x10.custom_minimum_size = Vector2(0, 116)
			
	# Dynamically match TopHUD and BottomHUD width strictly to the grid's pixel width
	var board_side = _calculate_cell_dimension() * grid_size + 8 * (grid_size - 1)
	top_hud.custom_minimum_size = Vector2(board_side, 0)
	bottom_hud.custom_minimum_size = Vector2(board_side, 0)

func _calculate_cell_dimension() -> float:
	var vp_size = get_viewport_rect().size
	var is_landscape = vp_size.x > vp_size.y
	if is_landscape:
		var max_h = vp_size.y - 120.0
		return clamp(floor((max_h - (grid_size - 1) * 8) / grid_size), 42.0, 110.0)
	else:
		var max_w = vp_size.x - 48.0
		return clamp(floor((max_w - (grid_size - 1) * 8) / grid_size), 50.0, 116.0)

# Curated 10-color high-contrast game palette:
# 0: Ruby Red, 1: Emerald Green, 2: Sky/Cyan Blue, 3: Sun Yellow, 4: Royal Purple,
# 5: Vibrant Orange, 6: Cobalt Blue (2nd blue), 7: Hot Magenta/Pink, 8: Pine Teal, 9: Amber Gold
const MASTER_PALETTE_HEX = [
	"#E53935", # 0: Ruby Red
	"#43A047", # 1: Emerald Green
	"#00B0FF", # 2: Sky / Cyan Blue
	"#FDD835", # 3: Sun Yellow
	"#8E24AA", # 4: Royal Purple
	"#FB8C00", # 5: Vibrant Orange
	"#1E88E5", # 6: Cobalt Blue (distinct deep royal blue)
	"#E91E63", # 7: Hot Magenta / Pink
	"#00897B", # 8: Pine Teal (distinct deep blue-green)
	"#FFA000", # 9: Amber Gold
]

# Explicit lookalike pairs that must NEVER touch each other on the board
const FORBIDDEN_COLOR_PAIRS = [
	Vector2i(0, 7), # Ruby Red & Hot Magenta
	Vector2i(0, 5), # Ruby Red & Vibrant Orange
	Vector2i(3, 5), # Sun Yellow & Vibrant Orange
	Vector2i(3, 9), # Sun Yellow & Amber Gold
	Vector2i(5, 9), # Vibrant Orange & Amber Gold
	Vector2i(1, 8), # Emerald Green & Pine Teal
	Vector2i(2, 6), # Sky Blue & Cobalt Blue
	Vector2i(4, 7), # Royal Purple & Hot Magenta
	Vector2i(4, 6), # Royal Purple & Cobalt Blue
]

func _color_distance(c1: Color, c2: Color) -> float:
	var rmean = (c1.r + c2.r) * 0.5
	var dr = c1.r - c2.r
	var dg = c1.g - c2.g
	var db = c1.b - c2.b
	return sqrt((2.0 + rmean) * dr * dr + 4.0 * dg * dg + (3.0 - rmean) * db * db)

func _solve_patch_color_mapping(patches: Array, size: int) -> Array:
	var palette: Array = []
	for i in range(size):
		palette.append(Color(MASTER_PALETTE_HEX[i]))
		
	var dist_matrix: Array = []
	for i in range(size):
		var row: Array = []
		for j in range(size):
			row.append(_color_distance(palette[i], palette[j]))
		dist_matrix.append(row)
		
	# Extract planar patch adjacency graph
	var adj: Array = []
	for p in range(size):
		adj.append([])
		
	for r in range(size):
		for c in range(size):
			var p1: int = patches[r][c]
			for d in [Vector2i(0, 1), Vector2i(1, 0)]:
				var nr = r + d.x
				var nc = c + d.y
				if nr < size and nc < size:
					var p2: int = patches[nr][nc]
					if p1 != p2:
						if not adj[p1].has(p2): adj[p1].append(p2)
						if not adj[p2].has(p1): adj[p2].append(p1)
						
	# Order patches by degree (most constrained / most neighbors first)
	var patch_order: Array = []
	for p in range(size):
		patch_order.append(p)
	patch_order.sort_custom(func(a, b): return adj[a].size() > adj[b].size())
	
	# Backtracking CSP with Max-Contrast Priority
	var assignment: Dictionary = {}
	var available_colors: Array = []
	for i in range(size):
		available_colors.append(i)
		
	var solved = _backtrack_color_assignment(0, patch_order, adj, dist_matrix, available_colors, assignment)
	
	var result_colors: Array = []
	if solved:
		for p in range(size):
			result_colors.append(palette[assignment[p]])
	else:
		# Fallback to direct indexing if ever unconstrained
		for p in range(size):
			result_colors.append(palette[p])
			
	return result_colors

func _backtrack_color_assignment(idx: int, patch_order: Array, adj: Array, dist_matrix: Array, available: Array, assignment: Dictionary) -> bool:
	if idx == patch_order.size():
		return true
		
	var p = patch_order[idx]
	var assigned_neighbors: Array = []
	for nb in adj[p]:
		if assignment.has(nb):
			assigned_neighbors.append(assignment[nb])
			
	# Rank candidate colors: strictly reject forbidden pairs, maximize distance to neighbors
	var candidates: Array = []
	for c_idx in available:
		var has_forbidden = false
		for nb_c in assigned_neighbors:
			for pair in FORBIDDEN_COLOR_PAIRS:
				if (pair.x == c_idx and pair.y == nb_c) or (pair.x == nb_c and pair.y == c_idx):
					has_forbidden = true
					break
			if has_forbidden:
				break
				
		if not has_forbidden:
			var min_d = 999.0
			for nb_c in assigned_neighbors:
				var d = dist_matrix[c_idx][nb_c]
				if d < min_d:
					min_d = d
			candidates.append({"color": c_idx, "score": min_d})
			
	# Try highest contrast complementary colors first
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	
	for cand in candidates:
		var c_idx = cand["color"]
		assignment[p] = c_idx
		available.erase(c_idx)
		
		if _backtrack_color_assignment(idx + 1, patch_order, adj, dist_matrix, available, assignment):
			return true
			
		available.append(c_idx)
		assignment.erase(p)
		
	return false

func _start_new_game(size: int, explicit_seed: int = -1):
	grid_size = size
	pending_next_size = size
	game_state = GameState.PLAYING
	moves_count = 0
	banner_overlay.visible = false
	flying_score_label.visible = false
	breakdown_box.visible = false
	award_total_label.visible = false
	modal_overlay.visible = false
	
	player_grid.clear()
	for r in range(grid_size):
		var row = []
		for c in range(grid_size):
			row.append(0)
		player_grid.append(row)
		
	if background:
		background.color = Color(0.1, 0.11, 0.14, 1.0)
	bomb_counter.remove_theme_color_override("font_color")
	bomb_counter_land.remove_theme_color_override("font_color")
	
	assist_mode = (grid_size <= 8)
	hints_used_this_level = assist_mode
	btn_assist.set_pressed_no_signal(assist_mode)
	btn_assist_land.set_pressed_no_signal(assist_mode)
	_update_assist_button_visuals()
	
	puzzle_data = OrchardCore.generate_puzzle(grid_size, explicit_seed, 50)
	if puzzle_data.is_empty():
		return
		
	current_palette = _solve_patch_color_mapping(puzzle_data["patches"], grid_size)
		
	start_time = Time.get_ticks_msec()
	
	print("\n==================================================")
	print("💣 MINESWEEPER SEED: ", puzzle_data.get("level_code", ""))
	print("Size: %dx%d | Diff Score: %d" % [grid_size, grid_size, puzzle_data.get("difficulty_score", 0)])
	print("Techniques: ", puzzle_data.get("techniques", {}))
	print("Bombs: ", puzzle_data.get("flowers", []))
	print("==================================================")
		
	_update_hud_action_buttons()
	_update_score_labels()
	_update_bomb_counter()
	_update_responsive_layout()
	_build_grid_ui()

func _update_score_labels():
	score_label.text = "SCORE: %d" % displayed_score
	score_label_land.text = "SCORE: %d" % displayed_score

func _update_hud_action_buttons():
	var show_carry_on = (game_state == GameState.SHOWING_SOLUTION or game_state == GameState.WON)
	btn_restart_same.visible = not show_carry_on
	btn_restart_same_land.visible = not show_carry_on
	btn_carry_on.visible = show_carry_on
	btn_carry_on_land.visible = show_carry_on

func _update_bomb_counter():
	var placed = 0
	for r in range(grid_size):
		for c in range(grid_size):
			if player_grid[r][c] == 1:
				placed += 1
	var counter_text = "%d / %d" % [placed, grid_size]
	bomb_counter.text = counter_text
	bomb_counter_land.text = counter_text

func _build_grid_ui():
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
		
	grid_container.columns = grid_size
	var cell_dim = _calculate_cell_dimension()
	var pad = int(cell_dim * 0.08)
	
	for r in range(grid_size):
		for c in range(grid_size):
			var patch_id = puzzle_data["patches"][r][c]
			var btn = Button.new()
			btn.name = "Cell_%d_%d" % [r, c]
			btn.custom_minimum_size = Vector2(cell_dim, cell_dim)
			btn.size = Vector2(cell_dim, cell_dim)
			btn.clip_text = true
			btn.text = ""
			btn.focus_mode = Control.FOCUS_NONE
			btn.pivot_offset = Vector2(cell_dim * 0.5, cell_dim * 0.5)
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
			
			var base_color = current_palette[patch_id % current_palette.size()]
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = base_color
			style_box.corner_radius_top_left = 12
			style_box.corner_radius_top_right = 12
			style_box.corner_radius_bottom_left = 12
			style_box.corner_radius_bottom_right = 12
			style_box.border_width_left = 0
			style_box.border_width_right = 0
			style_box.border_width_top = 0
			style_box.border_width_bottom = 0
			style_box.content_margin_left = pad
			style_box.content_margin_right = pad
			style_box.content_margin_top = pad
			style_box.content_margin_bottom = pad
			btn.add_theme_stylebox_override("normal", style_box)
			
			var hover_box = style_box.duplicate()
			hover_box.bg_color = base_color.lightened(0.08)
			btn.add_theme_stylebox_override("hover", hover_box)
			btn.add_theme_stylebox_override("pressed", hover_box)
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			
			btn.gui_input.connect(_on_cell_gui_input.bind(r, c))
			grid_container.add_child(btn)
			
	_refresh_cell_views()

func _on_cell_gui_input(event: InputEvent, r: int, c: int):
	if game_state != GameState.PLAYING:
		return
		
	if event is InputEventMouseButton and event.pressed:
		moves_count += 1
		var current_state = player_grid[r][c]
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			player_grid[r][c] = (current_state + 1) % 3
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if current_state == 2:
				player_grid[r][c] = 0
			else:
				player_grid[r][c] = 2
				
		_animate_cell_pop(r, c)
		_update_bomb_counter()
		_refresh_cell_views()
		_check_game_rules(r, c)

func _animate_cell_pop(r: int, c: int):
	var idx = r * grid_size + c
	if idx < grid_container.get_child_count():
		var btn: Button = grid_container.get_child(idx)
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.18, 1.18), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

func _refresh_cell_views():
	var bomb_cells: Array = []
	for r in range(grid_size):
		for c in range(grid_size):
			if player_grid[r][c] == 1:
				bomb_cells.append(Vector2i(r, c))
				
	var eliminated_cells: Dictionary = {}
	if assist_mode and game_state == GameState.PLAYING:
		for b in bomb_cells:
			var p = puzzle_data["patches"][b.x][b.y]
			for c2 in range(grid_size):
				if c2 != b.y: eliminated_cells[Vector2i(b.x, c2)] = true
			for r2 in range(grid_size):
				if r2 != b.x: eliminated_cells[Vector2i(r2, b.y)] = true
			for r2 in range(grid_size):
				for c2 in range(grid_size):
					if (r2 != b.x or c2 != b.y) and puzzle_data["patches"][r2][c2] == p:
						eliminated_cells[Vector2i(r2, c2)] = true
			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					if dr == 0 and dc == 0: continue
					var nr = b.x + dr
					var nc = b.y + dc
					if nr >= 0 and nr < grid_size and nc >= 0 and nc < grid_size:
						eliminated_cells[Vector2i(nr, nc)] = true

	var cell_dim = _calculate_cell_dimension()

	for r in range(grid_size):
		for c in range(grid_size):
			var idx = r * grid_size + c
			var btn: Button = grid_container.get_child(idx)
			var patch_id = puzzle_data["patches"][r][c]
			var state = player_grid[r][c]
			var base_color = current_palette[patch_id % current_palette.size()]
			var is_dimmed = eliminated_cells.has(Vector2i(r, c)) and state == 0
			
			btn.custom_minimum_size = Vector2(cell_dim, cell_dim)
			btn.size = Vector2(cell_dim, cell_dim)
			
			var style_box: StyleBoxFlat = btn.get_theme_stylebox("normal")
			if is_dimmed:
				style_box.bg_color = base_color.lerp(Color(0.10, 0.11, 0.14, 1.0), 0.50)
			else:
				style_box.bg_color = base_color
				
			btn.text = ""
			if state == 1:
				btn.icon = MINE_TEXTURE
			elif state == 2:
				btn.icon = CROSS_TEXTURE
			else:
				btn.icon = null

func _check_game_rules(last_r: int, last_c: int):
	if player_grid[last_r][last_c] == 1:
		var p = puzzle_data["patches"][last_r][last_c]
		var conflict = false
		var conflicting_cells = [Vector2i(last_r, last_c)]
		
		for c2 in range(grid_size):
			if c2 != last_c and player_grid[last_r][c2] == 1:
				conflict = true; conflicting_cells.append(Vector2i(last_r, c2))
		for r2 in range(grid_size):
			if r2 != last_r and player_grid[r2][last_c] == 1:
				conflict = true; conflicting_cells.append(Vector2i(r2, last_c))
		for r2 in range(grid_size):
			for c2 in range(grid_size):
				if (r2 != last_r or c2 != last_c) and puzzle_data["patches"][r2][c2] == p and player_grid[r2][c2] == 1:
					conflict = true; conflicting_cells.append(Vector2i(r2, c2))
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				if dr == 0 and dc == 0: continue
				var nr = last_r + dr
				var nc = last_c + dc
				if nr >= 0 and nr < grid_size and nc >= 0 and nc < grid_size:
					if player_grid[nr][nc] == 1:
						conflict = true; conflicting_cells.append(Vector2i(nr, nc))
						
		if conflict:
			_trigger_game_over_explosion(conflicting_cells)
			return

	var bombs_placed: Array = []
	for r in range(grid_size):
		for c in range(grid_size):
			if player_grid[r][c] == 1:
				bombs_placed.append(Vector2i(r, c))
				
	if bombs_placed.size() == grid_size:
		var target_flowers: Array = puzzle_data["flowers"]
		var all_match = true
		for b in bombs_placed:
			if not target_flowers.has(b):
				all_match = false; break
		if all_match:
			_trigger_victory_sequence()

func _trigger_game_over_explosion(culprit_cells: Array):
	game_state = GameState.LOST
	banner_label.text = "💥 BOOM! 💥"
	var streak_score = current_run_score
	if streak_score > 0:
		banner_sub_label.text = "STREAK ENDED · %d PTS" % streak_score
	else:
		banner_sub_label.text = "TRY AGAIN"
	banner_sub_label.visible = true
	breakdown_box.visible = false
	award_total_label.visible = false
	flying_score_label.visible = false
	banner_panel.modulate.a = 1.0
	banner_panel.scale = Vector2.ONE
	banner_overlay.visible = true
	
	# Current run score resets to 0 on loss
	current_run_score = 0
	displayed_score = 0
	_update_score_labels()
	_update_hud_action_buttons()
	
	if background:
		var tw_bg = create_tween()
		tw_bg.tween_property(background, "color", Color(0.07, 0.05, 0.06), 0.3)
	
	# Dim non-mine cells to make explosions and solution mines visually dominant
	var target_flowers = puzzle_data.get("flowers", [])
	for r in range(grid_size):
		for c in range(grid_size):
			var idx = r * grid_size + c
			var btn: Button = grid_container.get_child(idx)
			var pos = Vector2i(r, c)
			if not culprit_cells.has(pos) and not target_flowers.has(pos):
				var tw_cell = create_tween()
				tw_cell.tween_property(btn, "modulate", Color(0.82, 0.84, 0.88, 0.72), 0.25)
	
	for cell in culprit_cells:
		var idx = cell.x * grid_size + cell.y
		var btn: Button = grid_container.get_child(idx)
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
		style.bg_color = Color("#FF1744")
		style.border_color = Color("#FFFFFF")
		style.border_width_left = 5
		style.border_width_right = 5
		style.border_width_top = 5
		style.border_width_bottom = 5
		btn.add_theme_stylebox_override("normal", style)
		btn.icon = EXPLOSION_TEXTURE
		btn.text = ""
		
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.35, 1.35), 0.1)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)

	for i in range(target_flowers.size()):
		var f = target_flowers[i]
		if not culprit_cells.has(f):
			var idx = f.x * grid_size + f.y
			var btn: Button = grid_container.get_child(idx)
			get_tree().create_timer(0.08 * (i + 1)).timeout.connect(func():
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
				btn.icon = MINE_TEXTURE
				btn.text = ""
				var tw = create_tween()
				tw.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.08)
				tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
			)

func _calculate_level_score(completion_time: float) -> Dictionary:
	var base_score = grid_size * 100
	if not hints_used_this_level:
		base_score *= 2 # 2x bonus for zero hint assistance
		
	var half_life = 2.0 * grid_size
	var time_bonus = int(round(base_score * pow(0.5, completion_time / half_life)))
	var total_awarded = base_score + time_bonus
	
	return {
		"base": base_score,
		"time_bonus": time_bonus,
		"total": total_awarded,
		"no_hints": not hints_used_this_level
	}

func _trigger_victory_sequence():
	game_state = GameState.WON
	pending_next_size = grid_size
	var completion_time = (Time.get_ticks_msec() - start_time) / 1000.0
	var score_info = _calculate_level_score(completion_time)
	var awarded_points = score_info["total"]
	var old_score = current_run_score
	
	var record = {
		"timestamp": Time.get_datetime_string_from_system(),
		"size": grid_size,
		"difficulty_score": puzzle_data.get("difficulty_score", 0),
		"techniques": puzzle_data.get("techniques", {}),
		"time_seconds": completion_time,
		"moves": moves_count,
		"points_awarded": awarded_points,
		"run_total": current_run_score + awarded_points,
		"hints_used": hints_used_this_level
	}
	GameData.save_level_record(record)

	# Cell glow & pop celebration
	var target_flowers = puzzle_data.get("flowers", [])
	for i in range(target_flowers.size()):
		var f = target_flowers[i]
		var idx = f.x * grid_size + f.y
		var btn: Button = grid_container.get_child(idx)
		get_tree().create_timer(0.06 * i).timeout.connect(func():
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
			style.border_color = Color("#00E676")
			style.border_width_left = 5
			style.border_width_right = 5
			style.border_width_top = 5
			style.border_width_bottom = 5
			btn.add_theme_stylebox_override("normal", style)
			var tw = create_tween()
			tw.tween_property(btn, "scale", Vector2(1.25, 1.25), 0.1)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		)

	# 1. Populate the breakdown overlay
	banner_label.text = "🏆 CLEARED! 🏆"
	banner_sub_label.visible = false
	breakdown_box.visible = true
	if score_info["no_hints"]:
		level_pts_title.text = "LEVEL CLEAR (2× BONUS)"
	else:
		level_pts_title.text = "LEVEL CLEAR"
	level_pts_val.text = "+%d" % score_info["base"]
	time_pts_val.text = "+%d" % score_info["time_bonus"]
	award_total_label.text = "+%d PTS" % awarded_points
	award_total_label.visible = true
	flying_score_label.visible = false
	banner_overlay.visible = true

	# Pop in the breakdown banner panel
	banner_panel.modulate.a = 0.0
	await get_tree().process_frame
	banner_panel.reset_size()
	banner_panel.pivot_offset = banner_panel.size * 0.5
	banner_panel.scale = Vector2(0.82, 0.82)
	
	var tw_banner_in = create_tween().set_parallel(true)
	tw_banner_in.tween_property(banner_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_banner_in.tween_property(banner_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Hold breakdown for player to read
	await get_tree().create_timer(0.9).timeout
	if game_state != GameState.WON:
		return

	# 3. Prepare the flying score label right over the total award
	var award_rect = award_total_label.get_global_rect()
	flying_score_label.text = "+%d" % awarded_points
	flying_score_label.size = award_rect.size
	flying_score_label.global_position = award_rect.position
	flying_score_label.pivot_offset = flying_score_label.size * 0.5
	flying_score_label.scale = Vector2.ONE
	flying_score_label.modulate.a = 1.0
	flying_score_label.visible = true
	award_total_label.visible = false

	# 4. Target score badge
	var is_landscape = landscape_layout.visible
	var target_badge: Control = score_badge_land if is_landscape else score_badge
	var target_center = target_badge.get_global_rect().get_center()
	var fly_target_pos = target_center - flying_score_label.size * 0.5

	# 5. Fly score label to target badge while fading out banner panel
	var tw_fly = create_tween().set_parallel(true)
	tw_fly.tween_property(banner_panel, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_fly.tween_property(banner_panel, "scale", Vector2(0.85, 0.85), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_fly.tween_property(flying_score_label, "global_position", fly_target_pos, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw_fly.tween_property(flying_score_label, "scale", Vector2(0.75, 0.75), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await tw_fly.finished
	if game_state != GameState.WON:
		return

	# 6. Transfer completed: close overlay, roll up accumulated score, show play/next button
	flying_score_label.visible = false
	banner_overlay.visible = false
	banner_panel.modulate.a = 1.0
	banner_panel.scale = Vector2.ONE
	
	current_run_score += awarded_points
	GameData.update_high_score(current_run_score)
	_animate_score_addition(old_score, current_run_score)
	_update_hud_action_buttons()

func _animate_score_addition(from_val: int, to_val: int):
	for badge in [score_badge, score_badge_land]:
		if badge:
			badge.pivot_offset = badge.size * 0.5
			var tw_b = create_tween()
			tw_b.tween_property(badge, "scale", Vector2(1.22, 1.22), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_b.tween_property(badge, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	var tw = create_tween()
	tw.tween_method(func(val: int):
		displayed_score = val
		_update_score_labels()
	, from_val, to_val, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _reveal_solution_and_transition(next_size: int):
	if game_state == GameState.SHOWING_SOLUTION:
		return
		
	if game_state == GameState.WON or game_state == GameState.LOST:
		_start_new_game(next_size)
		return
		
	# Giving up mid-game resets current run score
	current_run_score = 0
	displayed_score = 0
	_update_score_labels()
	
	game_state = GameState.SHOWING_SOLUTION
	pending_next_size = next_size
	banner_overlay.visible = false
	modal_overlay.visible = false
	
	# Environmental shift: smoothly tint background to deep dark slate
	if background:
		var tw_bg = create_tween()
		tw_bg.tween_property(background, "color", Color(0.06, 0.07, 0.09), 0.35)
		
	# Clear HUD signal that board is inactive and solution is being inspected
	bomb_counter.text = "SOLUTION"
	bomb_counter.add_theme_color_override("font_color", Color(1.0, 0.68, 0.2))
	bomb_counter_land.text = "SOLUTION"
	bomb_counter_land.add_theme_color_override("font_color", Color(1.0, 0.68, 0.2))
	
	_update_hud_action_buttons()
	
	# Accentuate the play / carry on button with a lively attention bounce
	for play_btn in [btn_carry_on, btn_carry_on_land]:
		var tw_play = create_tween()
		tw_play.tween_property(play_btn, "scale", Vector2(1.22, 1.22), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_play.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	
	# Softly dim non-mine cells so patch colors remain clearly distinguishable
	var target_flowers = puzzle_data.get("flowers", [])
	for r in range(grid_size):
		for c in range(grid_size):
			var idx = r * grid_size + c
			var btn: Button = grid_container.get_child(idx)
			if not target_flowers.has(Vector2i(r, c)):
				var tw_cell = create_tween()
				tw_cell.tween_property(btn, "modulate", Color(0.82, 0.84, 0.88, 0.72), 0.25)
				btn.icon = null
	
	# Cascade reveal of the true solution mines
	for i in range(target_flowers.size()):
		var f = target_flowers[i]
		var idx = f.x * grid_size + f.y
		var btn: Button = grid_container.get_child(idx)
		get_tree().create_timer(0.06 * (i + 1)).timeout.connect(func():
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			btn.icon = MINE_TEXTURE
			btn.text = ""
			var tw = create_tween()
			tw.tween_property(btn, "scale", Vector2(1.22, 1.22), 0.08)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
		)

func _on_carry_on_pressed():
	_start_new_game(pending_next_size)

func _on_restart_same_pressed():
	_reveal_solution_and_transition(grid_size)

func _on_open_menu_pressed():
	btn_close_modal.visible = (game_state == GameState.PLAYING)
	modal_overlay.visible = true

func _on_close_modal_pressed():
	modal_overlay.visible = false

func _on_modal_size_selected(chosen_size: int):
	modal_overlay.visible = false
	_reveal_solution_and_transition(chosen_size)

func _on_assist_toggled(button_pressed: bool):
	assist_mode = button_pressed
	if assist_mode:
		hints_used_this_level = true
	btn_assist.button_pressed = assist_mode
	btn_assist_land.button_pressed = assist_mode
	_update_assist_button_visuals()
	_refresh_cell_views()

func _update_assist_button_visuals():
	# Clean monochrome luminance shift: bright white when active, muted charcoal when off
	var active_color = Color(1.0, 1.0, 1.0, 1.0) if assist_mode else Color(0.4, 0.42, 0.48, 0.6)
	btn_assist.modulate = active_color
	btn_assist_land.modulate = active_color

func _setup_difficulty_modal_styles():
	# Dialog Container
	var modal_box = StyleBoxFlat.new()
	modal_box.bg_color = Color("#13161F")
	modal_box.corner_radius_top_left = 24
	modal_box.corner_radius_top_right = 24
	modal_box.corner_radius_bottom_left = 24
	modal_box.corner_radius_bottom_right = 24
	modal_box.border_width_left = 3
	modal_box.border_width_right = 3
	modal_box.border_width_top = 3
	modal_box.border_width_bottom = 3
	modal_box.border_color = Color("#2D3345")
	modal_box.shadow_color = Color(0, 0, 0, 0.65)
	modal_box.shadow_size = 24
	difficulty_modal.add_theme_stylebox_override("panel", modal_box)
	
	# Helper for card buttons
	_style_card_button(btn_6x6, Color("#00E676"))
	_style_card_button(btn_8x8, Color("#FFD600"))
	_style_card_button(btn_10x10, Color("#FF3366"))
	
	# Resume Button
	var resume_norm = StyleBoxFlat.new()
	resume_norm.bg_color = Color("#222633")
	resume_norm.corner_radius_top_left = 16
	resume_norm.corner_radius_top_right = 16
	resume_norm.corner_radius_bottom_left = 16
	resume_norm.corner_radius_bottom_right = 16
	resume_norm.border_width_left = 2
	resume_norm.border_width_right = 2
	resume_norm.border_width_top = 2
	resume_norm.border_width_bottom = 2
	resume_norm.border_color = Color("#3B4254")
	btn_close_modal.add_theme_stylebox_override("normal", resume_norm)
	
	var resume_hov = resume_norm.duplicate()
	resume_hov.bg_color = Color("#2E3445")
	resume_hov.border_color = Color("#555F77")
	btn_close_modal.add_theme_stylebox_override("hover", resume_hov)
	btn_close_modal.add_theme_stylebox_override("pressed", resume_hov)
	btn_close_modal.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _style_card_button(btn: Button, accent: Color):
	var norm = StyleBoxFlat.new()
	norm.bg_color = Color("#1A202C")
	norm.corner_radius_top_left = 18
	norm.corner_radius_top_right = 18
	norm.corner_radius_bottom_left = 18
	norm.corner_radius_bottom_right = 18
	norm.border_width_left = 6
	norm.border_width_right = 2
	norm.border_width_top = 2
	norm.border_width_bottom = 2
	norm.border_color = accent
	norm.shadow_color = Color(0, 0, 0, 0.3)
	norm.shadow_size = 8
	norm.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", norm)
	
	var hov = norm.duplicate()
	hov.bg_color = Color("#242C3D")
	hov.border_color = accent.lightened(0.25)
	hov.shadow_size = 12
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _setup_badge_styles():
	var normal_badge = StyleBoxFlat.new()
	normal_badge.bg_color = Color("#151822")
	normal_badge.corner_radius_top_left = 16
	normal_badge.corner_radius_top_right = 16
	normal_badge.corner_radius_bottom_left = 16
	normal_badge.corner_radius_bottom_right = 16
	normal_badge.border_width_left = 2
	normal_badge.border_width_right = 2
	normal_badge.border_width_top = 2
	normal_badge.border_width_bottom = 2
	normal_badge.border_color = Color("#2A3042")
	normal_badge.shadow_color = Color(0, 0, 0, 0.4)
	normal_badge.shadow_size = 6
	normal_badge.shadow_offset = Vector2(0, 3)

	var score_badge_style = normal_badge.duplicate()
	score_badge_style.border_color = Color("#FFD54F").lerp(Color("#2A3042"), 0.5)

	for b in [bomb_badge, timer_badge, bomb_badge_land, timer_badge_land]:
		if b:
			b.add_theme_stylebox_override("panel", normal_badge)

	for sb in [score_badge, score_badge_land]:
		if sb:
			sb.add_theme_stylebox_override("panel", score_badge_style)

func _setup_banner_styles():
	var banner_box = StyleBoxFlat.new()
	banner_box.bg_color = Color("#13161F")
	banner_box.corner_radius_top_left = 24
	banner_box.corner_radius_top_right = 24
	banner_box.corner_radius_bottom_left = 24
	banner_box.corner_radius_bottom_right = 24
	banner_box.border_width_left = 3
	banner_box.border_width_right = 3
	banner_box.border_width_top = 3
	banner_box.border_width_bottom = 3
	banner_box.border_color = Color("#2D3345")
	banner_box.shadow_color = Color(0, 0, 0, 0.75)
	banner_box.shadow_size = 28
	banner_box.shadow_offset = Vector2(0, 8)
	banner_panel.add_theme_stylebox_override("panel", banner_box)
