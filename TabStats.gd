extends Node

var host: Node

var _state: int       = 0
var _picked_rune: int = -1
var _popup_canvas: CanvasLayer = null
var _confirm_reset: bool = false

const RUNE_INFO: Dictionary = {
	0: {"name": "Fire",  "color": Color(1.0, 0.45, 0.0, 1.0), "framed_sprite": "res://assets/ui/Backgroundframes/fireframed.webp"},
	1: {"name": "Wind",  "color": Color(0.5, 1.0, 1.0, 1.0),  "framed_sprite": "res://assets/ui/Backgroundframes/windframed.webp"},
	2: {"name": "Soul",  "color": Color(0.7, 0.3, 1.0, 1.0),  "framed_sprite": "res://assets/ui/Backgroundframes/soulfrmaed.webp"},
	3: {"name": "Blood", "color": Color(0.9, 0.0, 0.1, 1.0),  "framed_sprite": "res://assets/ui/Backgroundframes/bloodframed.webp"},
	4: {"name": "Earth", "color": Color(0.3, 0.7, 0.2, 1.0),  "framed_sprite": "res://assets/ui/Backgroundframes/earth framed.webp"},
}
const RUNE_ORDER: Array        = [0, 1, 2, 3, 4]
const DARK_BTN: String         = "res://assets/ui/buttons/Dark_button.png"
const DARK_BTN_PRESSED: String = "res://assets/ui/buttons/Dark_button_pressed.png"
const TIER_FRAME: String       = "res://assets/ui/Backgroundframes/Charachter tier up .webp"
const RESET_FRAME: String      = "res://assets/ui/Backgroundframes/removetierup.webp"

func _make_dark_btn(text: String, font_size: int, btn_w: float, btn_h: float, col: Color = Color.WHITE) -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(btn_w, btn_h)
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_SCALE
	if ResourceLoader.exists(DARK_BTN):
		btn.texture_normal = UIFactory.cached_load(DARK_BTN)
	if ResourceLoader.exists(DARK_BTN_PRESSED):
		btn.texture_pressed = UIFactory.cached_load(DARK_BTN_PRESSED)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	return btn

func _make_framed_rune_btn(rune_key: int, frame_size: float, is_selected: bool) -> Control:
	var info: Dictionary = RUNE_INFO[rune_key]
	var wrap := Control.new()
	wrap.custom_minimum_size   = Vector2(frame_size, frame_size)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sprite_path: String = info.get("framed_sprite", "")
	if ResourceLoader.exists(sprite_path):
		if is_selected:
			# Soft additive glow in the rune's colour behind the selected frame
			var glow_mat := CanvasItemMaterial.new()
			glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			var glow_col: Color = info["color"]
			for g in [[0.16, 0.30], [0.08, 0.45]]:
				var glow := TextureRect.new()
				glow.texture      = UIFactory.cached_load(sprite_path)
				glow.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
				glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				glow.set_anchors_preset(Control.PRESET_FULL_RECT)
				var grow: float = -frame_size * float(g[0])
				glow.offset_left   = grow
				glow.offset_top    = grow
				glow.offset_right  = -grow
				glow.offset_bottom = -grow
				glow.mouse_filter  = Control.MOUSE_FILTER_IGNORE
				glow.material      = glow_mat
				glow.modulate      = Color(glow_col.r, glow_col.g, glow_col.b, float(g[1]))
				wrap.add_child(glow)
		var rect := TextureRect.new()
		rect.texture      = UIFactory.cached_load(sprite_path)
		rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# EDIT 1: Unselected runes brighter
		rect.modulate     = Color(1, 1, 1, 1) if is_selected else Color(0.68, 0.68, 0.68, 0.92)
		wrap.add_child(rect)
	return wrap

func _clear_popup() -> void:
	if is_instance_valid(_popup_canvas):
		_popup_canvas.queue_free()
		_popup_canvas = null

func _show_centered_box(screen_w: float, screen_h: float, box_h: float) -> VBoxContainer:
	_clear_popup()
	_popup_canvas = CanvasLayer.new()
	_popup_canvas.layer = 10
	host.add_child(_popup_canvas)

	var overlay := ColorRect.new()
	overlay.color        = Color(0.0, 0.0, 0.0, 0.835)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_canvas.add_child(overlay)

	var frame_tex: Texture2D = null
	var native_w:  float     = 1.0
	var native_h:  float     = 1.0
	if ResourceLoader.exists(TIER_FRAME):
		frame_tex = UIFactory.cached_load(TIER_FRAME)
		native_w  = float(frame_tex.get_width())
		native_h  = float(frame_tex.get_height())

	var bg_h: float = screen_w * (native_h / native_w)
	bg_h = clampf(maxf(bg_h, box_h), box_h, screen_h * 0.95)

	var box := Control.new()
	box.anchor_left   = 0.0
	box.anchor_right  = 1.0
	box.anchor_top    = 0.5
	box.anchor_bottom = 0.5
	box.offset_left   = 0
	box.offset_right  = 0
	box.offset_top    = -bg_h * 0.5
	box.offset_bottom =  bg_h * 0.5
	overlay.add_child(box)

	if frame_tex != null:
		var bg := TextureRect.new()
		bg.texture      = frame_tex
		bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.05, 0.10, 0.97)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bg)

	var pad_x: float = screen_w * 0.07
	var pad_t: float = bg_h    * 0.15
	var pad_b: float = bg_h    * 0.09

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   =  pad_x
	vbox.offset_right  = -pad_x
	vbox.offset_top    =  pad_t
	vbox.offset_bottom = -pad_b
	vbox.add_theme_constant_override("separation", int(screen_h * 0.006))
	box.add_child(vbox)

	return vbox

func _show_small_confirm_box(screen_w: float, screen_h: float) -> VBoxContainer:
	_clear_popup()
	_popup_canvas = CanvasLayer.new()
	_popup_canvas.layer = 10
	host.add_child(_popup_canvas)

	var overlay := ColorRect.new()
	overlay.color        = Color(0.0, 0.0, 0.0, 0.70)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_canvas.add_child(overlay)

	# ── Increased size ──
	var box_w: float = screen_w * 0.88
	var box_h: float = screen_h * 0.42

	var frame_tex: Texture2D = null
	if ResourceLoader.exists(RESET_FRAME):
		frame_tex = UIFactory.cached_load(RESET_FRAME)

	var box := Control.new()
	box.anchor_left   = 0.5
	box.anchor_right  = 0.5
	box.anchor_top    = 0.5
	box.anchor_bottom = 0.5
	box.offset_left   = -box_w * 0.5
	box.offset_right  =  box_w * 0.5
	box.offset_top    = -box_h * 0.5
	box.offset_bottom =  box_h * 0.5
	overlay.add_child(box)

	if frame_tex != null:
		var bg := TextureRect.new()
		bg.texture      = frame_tex
		bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.05, 0.10, 0.97)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   =  box_w * 0.10
	vbox.offset_right  = -box_w * 0.10
	vbox.offset_top    =  box_h * 0.14
	vbox.offset_bottom = -box_h * 0.10
	vbox.alignment     = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(screen_h * 0.018))
	box.add_child(vbox)

	return vbox

func build(root_vbox: VBoxContainer, screen_w: float, screen_h: float, sz: Dictionary) -> void:
	_clear_popup()

	var idx: int = GameState.selected_character
	if idx < 0 or idx >= GameState.CHARACTERS.size():
		var lbl := Label.new()
		lbl.text = "No character selected.\nGo to Characters tab first."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", int(screen_w * 0.04))
		lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.6, 1))
		root_vbox.add_child(lbl)
		return

	var char_data: Dictionary = GameState.CHARACTERS[idx]
	var stats: Dictionary     = GameState.get_character_stats_display(idx)
	var level: int            = stats.get("level", 0)
	var max_level: int        = stats.get("max_level", 5)

	var stat_font: int   = int(screen_w * 0.0523)
	var header_font: int = int(screen_w * 0.0456)
	var btn_font: int    = int(screen_w * 0.038)
	var pip_w: float     = screen_w * 0.10
	var pip_h: float     = screen_h * 0.018
	var sep: int         = int(screen_h * 0.008)
	var sprite_w: float  = screen_w * 0.68
	var svp_h: float     = screen_h * 0.52
	var panel_w: float   = screen_w * 0.92

	var center_h := HBoxContainer.new()
	center_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_h.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(center_h)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(panel_w, 0)
	panel.add_theme_constant_override("separation", sep)
	center_h.add_child(panel)

	var header := Label.new()
	header.text = char_data["name"] + "  —  Tier " + str(level) + " / " + str(max_level)
	header.add_theme_font_size_override("font_size", header_font)
	header.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(header)

	var tier_hbox := HBoxContainer.new()
	tier_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_hbox.add_theme_constant_override("separation", int(screen_w * 0.02))
	panel.add_child(tier_hbox)
	for t in range(max_level):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(pip_w, pip_h)
		pip.color = Color(0.4, 1.0, 0.5, 1.0) if t < level else Color(0.25, 0.25, 0.25, 0.8)
		tier_hbox.add_child(pip)

	_add_divider(panel, panel_w)

	if host._hero_viewport.has("svc") and is_instance_valid(host._hero_viewport.svc):
		var svc: SubViewportContainer = host._hero_viewport.svc
		if svc.get_parent() != null:
			svc.get_parent().remove_child(svc)
		svc.custom_minimum_size   = Vector2(sprite_w, svp_h)
		svc.clip_contents         = false
		svc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		svc.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		host._hero_viewport.svp.size      = Vector2i(int(sprite_w), int(svp_h))
		host._hero_viewport.anim.position = Vector2(sprite_w * 0.5, svp_h * 0.50)
		host._hero_viewport.anim.scale    = Vector2(sz.hero_scale * 0.92, sz.hero_scale * 0.92)
		panel.add_child(svc)

	var rows: Array = [
		["Jump Speed", "%.1f" % stats.get("jump_speed", 0.0), Color(1.0, 0.85, 0.3, 1.0)],
		["Move Speed", "%.1f" % stats.get("move_speed", 0.0), Color(0.4, 0.9,  1.0, 1.0)],
		["Jump Boost", "%.2f" % stats.get("jump_boost", 0.0), Color(0.5, 1.0,  0.7, 1.0)],
		["Attack",     "%.2f" % stats.get("attack",     0.0), Color(1.0, 0.4,  0.4, 1.0)],
	]

	var stats_vbox := VBoxContainer.new()
	stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_vbox.add_theme_constant_override("separation", int(screen_h * 0.002))
	stats_vbox.position.y = -int(screen_h * 0.12)
	panel.add_child(stats_vbox)

	for row in rows:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_vbox.add_child(hbox)

		var name_lbl := Label.new()
		name_lbl.text = row[0]
		name_lbl.add_theme_font_size_override("font_size", stat_font)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_LEFT
		hbox.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = row[1]
		val_lbl.add_theme_font_size_override("font_size", stat_font)
		val_lbl.add_theme_color_override("font_color", row[2])
		val_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
		hbox.add_child(val_lbl)

	_add_divider(panel, panel_w)

	var action_vbox := VBoxContainer.new()
	action_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_vbox.add_theme_constant_override("separation", int(screen_h * 0.006))
	action_vbox.position.y = -int(screen_h * 0.04)
	panel.add_child(action_vbox)

	if level >= max_level:
		var lbl := Label.new()
		lbl.text = "★  MAX TIER REACHED  ★"
		lbl.add_theme_font_size_override("font_size", header_font)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_vbox.add_child(lbl)
	else:
		var upgrade_btn := _make_dark_btn(
			"UPGRADE TO TIER " + str(level + 1),
			btn_font, panel_w * 0.60, screen_h * 0.082,
			Color(0.3, 1.0, 0.5, 1.0)
		)
		upgrade_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		upgrade_btn.pressed.connect(func():
			_state       = 1
			_picked_rune = -1
			host.rebuild()
		)
		action_vbox.add_child(upgrade_btn)

	if level > 0:
		var reset_btn := _make_dark_btn(
			"Reset Tier  (-100 Soul Coins)",
			int(btn_font * 0.95),
			panel_w * 0.62, screen_h * 0.082,
			Color(1.0, 0.45, 0.45, 1.0)
		)
		reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		reset_btn.modulate = Color(1.0, 0.6, 0.6, 1.0) if GameState.coins >= 100 else Color(0.4, 0.4, 0.4, 1.0)
		reset_btn.pressed.connect(func():
			if GameState.coins >= 100:
				_confirm_reset = true
				host.rebuild()
		)
		action_vbox.add_child(reset_btn)

	if _confirm_reset:
		_build_reset_confirm_box(idx, screen_w, screen_h)
	elif _state == 1 and level < max_level:
		_build_rune_picker_box(idx, level, screen_w, screen_h)
	elif _state == 2 and level < max_level:
		_build_confirm_box(idx, level, screen_w, screen_h)

func _build_reset_confirm_box(idx: int, screen_w: float, screen_h: float) -> void:
	var vbox := _show_small_confirm_box(screen_w, screen_h)

	var title := Label.new()
	title.text = "Reset Tier?"
	title.add_theme_font_size_override("font_size", int(screen_w * 0.052))
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "This will cost  100 Soul Coins"
	sub.add_theme_font_size_override("font_size", int(screen_w * 0.034))
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.90))
	sub.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sub)

	var btn_row := HBoxContainer.new()
	btn_row.alignment             = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", int(screen_w * 0.04))
	vbox.add_child(btn_row)

	var cancel_btn := _make_dark_btn(
		"Cancel", int(screen_w * 0.038),
		screen_w * 0.28, screen_h * 0.090,
		Color(0.85, 0.85, 0.85, 1.0)
	)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(func():
		_confirm_reset = false
		host.rebuild()
	)
	btn_row.add_child(cancel_btn)

	var captured_idx: int = idx
	var confirm_btn := _make_dark_btn(
		"Yes, Reset!", int(screen_w * 0.038),
		screen_w * 0.34, screen_h * 0.090,
		Color(1.0, 0.35, 0.35, 1.0)
	)
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_btn.pressed.connect(func():
		GameState.reset_character_tier(captured_idx)
		_confirm_reset = false
		_clear_popup()
		host.rebuild()
	)
	btn_row.add_child(confirm_btn)

func _build_rune_picker_box(idx: int, level: int, screen_w: float, screen_h: float) -> void:
	var native_w: float = 1.0
	var native_h: float = 1.0
	if ResourceLoader.exists(TIER_FRAME):
		var ft: Texture2D = UIFactory.cached_load(TIER_FRAME)
		native_w = float(ft.get_width())
		native_h = float(ft.get_height())

	var bg_h:    float = minf(screen_w * (native_h / native_w), screen_h * 0.95)
	var inner_w: float = screen_w * 0.86
	var inner_h: float = bg_h * 0.76

	var btn_h_val:  float = screen_h * 0.110
	var title_h:    float = screen_h * 0.058
	var info_h:     float = screen_h * 0.160
	var spacer_h:   float = screen_h * 0.025
	var sep_total:  float = screen_h * 0.035
	var cost_h:     float = screen_h * 0.075
	var reserved:   float = title_h + info_h + btn_h_val + spacer_h + sep_total + cost_h

	var grid_h:     float = maxf(inner_h - reserved, screen_h * 0.28)
	var row_h:      float = (grid_h - screen_h * 0.008) * 0.5
	var frame_size: float = clampf(
		minf(row_h, minf(inner_w / 2.0, inner_w / 3.0)),
		60.0, 180.0
	)

	var actual_grid_h: float = 2.0 * frame_size + screen_h * 0.008
	var box_h: float = clampf(
		title_h + actual_grid_h + info_h + btn_h_val + spacer_h + sep_total + cost_h + bg_h * 0.24,
		screen_h * 0.72, screen_h * 0.95
	)

	var vbox := _show_centered_box(screen_w, screen_h, box_h)

	var title := Label.new()
	title.text = "Choose Upgrade Rune"
	title.add_theme_font_size_override("font_size", int(screen_w * 0.046))
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)

	var row1 := HBoxContainer.new()
	row1.alignment             = BoxContainer.ALIGNMENT_CENTER
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_theme_constant_override("separation", int(screen_w * 0.04))
	vbox.add_child(row1)
	for rune_key in [0, 1]:
		row1.add_child(_build_rune_slot(rune_key, frame_size, level))

	var row2 := HBoxContainer.new()
	row2.alignment             = BoxContainer.ALIGNMENT_CENTER
	row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_theme_constant_override("separation", int(screen_w * 0.025))
	vbox.add_child(row2)
	for rune_key in [2, 3, 4]:
		row2.add_child(_build_rune_slot(rune_key, frame_size, level))

	var div := ColorRect.new()
	div.color                 = Color(1, 1, 1, 0.12)
	div.custom_minimum_size   = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(div)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment             = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", int(screen_h * 0.003))
	vbox.add_child(info_vbox)

	if _picked_rune != -1:
		var info: Dictionary = RUNE_INFO[_picked_rune]
		var next: Dictionary = GameState.get_upgrade_display_values(_picked_rune, level + 1)
		if not next.is_empty():
			var picked_color: Color = info["color"]

			var name_cost := Label.new()
			name_cost.text = "%s Rune" % info["name"]
			name_cost.add_theme_font_size_override("font_size", int(screen_w * 0.040))
			name_cost.add_theme_color_override("font_color", picked_color)
			name_cost.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
			name_cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_vbox.add_child(name_cost)

			var grid := GridContainer.new()
			grid.columns = 4
			grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			grid.add_theme_constant_override("h_separation", int(screen_w * 0.040))
			grid.add_theme_constant_override("v_separation", int(screen_h * 0.001))
			info_vbox.add_child(grid)

			var prows: Array = [
				["Jump Spd", next.get("jump_speed", 0.0), Color(1.0, 0.85, 0.3, 1.0)],
				["Move Spd", next.get("move_speed", 0.0), Color(0.4, 0.9,  1.0, 1.0)],
				["Boost",    next.get("jump_boost", 0.0), Color(0.5, 1.0,  0.7, 1.0)],
				["Attack",   next.get("attack",     0.0), Color(1.0, 0.4,  0.4, 1.0)],
			]
			var sf: int = int(screen_w * 0.036)
			for pr in prows:
				var nl := Label.new()
				nl.text = pr[0]
				nl.add_theme_font_size_override("font_size", sf)
				nl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
				nl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
				nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(nl)
			for pr in prows:
				var vl := Label.new()
				vl.text = ("+%.1f" % pr[1]) if pr[1] != 0.0 else "—"
				vl.add_theme_font_size_override("font_size", sf)
				vl.add_theme_color_override("font_color", pr[2])
				vl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
				vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(vl)
	else:
		var hint := Label.new()
		hint.text = "Tap a rune to see details"
		hint.add_theme_font_size_override("font_size", int(screen_w * 0.034))
		hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65, 0.80))
		hint.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_child(hint)

	var spacer := Control.new()
	spacer.custom_minimum_size   = Vector2(0, spacer_h)
	spacer.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var affordable_pick: bool = false
	if _picked_rune != -1:
		var upgrades: Array = GameState.RUNE_UPGRADES.get(_picked_rune, [])
		if level + 1 < upgrades.size():
			var real_next: Dictionary = upgrades[level + 1]
			affordable_pick = GameState.runes.get(_picked_rune, 0) >= real_next.get("rune_cost", 0) \
							  and GameState.coins >= real_next.get("soul_cost", 0)

	var cost_lbl := Label.new()
	cost_lbl.custom_minimum_size   = Vector2(0, cost_h)
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	cost_lbl.add_theme_font_size_override("font_size", int(screen_w * 0.040))
	cost_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cost_lbl.add_theme_constant_override("outline_size", 4)
	if _picked_rune != -1:
		var cost_upgrades: Array = GameState.RUNE_UPGRADES.get(_picked_rune, [])
		if level + 1 < cost_upgrades.size():
			var cost_next: Dictionary = cost_upgrades[level + 1]
			cost_lbl.text = "Cost: %d %s Runes + %d Soul Coins" % [
				int(cost_next.get("rune_cost", 0)), RUNE_INFO[_picked_rune]["name"],
				int(cost_next.get("soul_cost", 0))
			]
			cost_lbl.add_theme_color_override("font_color",
				Color(0.4, 1.0, 0.5, 1.0) if affordable_pick else Color(1.0, 0.55, 0.3, 1.0))
	else:
		cost_lbl.text = "Select a rune to see the cost"
		cost_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85, 0.9))
	vbox.add_child(cost_lbl)

	var btn_color: Color = RUNE_INFO[_picked_rune]["color"] if _picked_rune != -1 else Color(0.5, 0.5, 0.5, 1.0)

	var b_font:  int   = int(screen_w * 0.040)
	var b_w_can: float = inner_w * 0.28
	var b_w_con: float = inner_w * 0.42
	var b_h:     float = btn_h_val

	var btn_row := HBoxContainer.new()
	btn_row.alignment             = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", int(screen_w * 0.04))
	vbox.add_child(btn_row)

	var cancel_btn := _make_dark_btn("Cancel", b_font, b_w_can, b_h, Color(0.85, 0.85, 0.85, 1.0))
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(func():
		_state       = 0
		_picked_rune = -1
		host.rebuild()
	)
	btn_row.add_child(cancel_btn)

	var confirm_text: String = "Next  ›  %s" % RUNE_INFO[_picked_rune]["name"] if _picked_rune != -1 else "Tap a Rune"
	var confirm_btn := _make_dark_btn(confirm_text, b_font, b_w_con, b_h,
		btn_color if affordable_pick else Color(0.4, 0.4, 0.4, 1.0))
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_btn.modulate = Color(1, 1, 1, 1) if affordable_pick else Color(0.5, 0.5, 0.5, 0.7)
	if affordable_pick:
		confirm_btn.pressed.connect(func(): _state = 2; host.rebuild())
	btn_row.add_child(confirm_btn)

func _build_rune_slot(rune_key: int, frame_size: float, level: int) -> Control:
	var upgrades: Array  = GameState.RUNE_UPGRADES.get(rune_key, [])
	var affordable: bool = false
	if level + 1 < upgrades.size():
		var real_next: Dictionary = upgrades[level + 1]
		affordable = GameState.runes.get(rune_key, 0) >= real_next.get("rune_cost", 0) \
					 and GameState.coins >= real_next.get("soul_cost", 0)

	var wrap := _make_framed_rune_btn(rune_key, frame_size, _picked_rune == rune_key)
	if not affordable and _picked_rune != rune_key:
		# EDIT 2: Unaffordable runes brighter (still dimmer than affordable)
		# The picked rune is never dimmed so it lights up fully.
		wrap.modulate = Color(0.48, 0.48, 0.48, 0.78)

	var input_btn := Button.new()
	input_btn.flat         = true
	input_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.add_child(input_btn)
	var capture: int = rune_key
	input_btn.pressed.connect(func():
		_picked_rune = capture
		host.rebuild()
	)
	return wrap

func _build_confirm_box(idx: int, level: int, screen_w: float, screen_h: float) -> void:
	var rune_info: Dictionary = RUNE_INFO[_picked_rune]
	var frame_size: float = clampf(screen_w * 0.23, 100.0, 170.0)
	var box_h:      float = clampf(
		frame_size + screen_h * 0.28,
		screen_h * 0.45, screen_h * 0.65
	)
	var vbox := _show_centered_box(screen_w, screen_h, box_h)

	var title := Label.new()
	title.text = "Confirm Upgrade?"
	title.add_theme_font_size_override("font_size", int(screen_w * 0.054))
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)

	var rune_center := HBoxContainer.new()
	rune_center.alignment             = BoxContainer.ALIGNMENT_CENTER
	rune_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(rune_center)
	rune_center.add_child(_make_framed_rune_btn(_picked_rune, frame_size, true))

	var upgrades: Array = GameState.RUNE_UPGRADES.get(_picked_rune, [])
	if level + 1 < upgrades.size():
		var real_next: Dictionary = upgrades[level + 1]
		var rune_cost: int = real_next.get("rune_cost", 0)
		var soul_cost: int = real_next.get("soul_cost", 0)
		var desc := Label.new()
		desc.text = "Upgrade to Tier %d\nUsing  %s  Rune\n%d Runes  +  %d Soul Coins" % [
			level + 1, rune_info["name"], rune_cost, soul_cost
		]
		desc.add_theme_font_size_override("font_size", int(screen_w * 0.038))
		desc.add_theme_color_override("font_color", rune_info["color"])
		desc.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var inner_w: float = screen_w * 0.86
	var btn_row := HBoxContainer.new()
	btn_row.alignment             = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", int(screen_w * 0.04))
	vbox.add_child(btn_row)

	var no_btn := _make_dark_btn("Back", int(screen_w * 0.040),
		inner_w * 0.28, screen_h * 0.110, Color(0.85, 0.85, 0.85, 1.0))
	no_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	no_btn.pressed.connect(func(): _state = 1; host.rebuild())
	btn_row.add_child(no_btn)

	var capture_idx: int  = idx
	var capture_rune: int = _picked_rune
	var yes_btn := _make_dark_btn("Yes, Upgrade!", int(screen_w * 0.040),
		inner_w * 0.42, screen_h * 0.110, rune_info["color"])
	yes_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	yes_btn.pressed.connect(func():
		GameState.upgrade_character(capture_idx, capture_rune)
		_state = 0; _picked_rune = -1; _clear_popup(); host.rebuild()
	)
	btn_row.add_child(yes_btn)

func _add_divider(panel: VBoxContainer, width: float) -> void:
	var div := ColorRect.new()
	div.color               = Color(1, 1, 1, 0.15)
	div.custom_minimum_size = Vector2(width, 2)
	panel.add_child(div)
