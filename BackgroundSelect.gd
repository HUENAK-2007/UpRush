extends Node2D

const MENU_SCENE: String = "res://scenes/MainMenu.tscn"
const BACK_BTN_PATH := "res://assets/ui/arrow_left.webp"
const BG_PATH := "res://assets/ui/backgrounds/Select char_back.webp"

const FRAME_TWISTEDMETAL := "res://assets/ui/Backgroundframes/twistedmetalframes.webp"
const FRAME_LIGHTFLOWER := "res://assets/ui/Backgroundframes/lightflower.webp"
const FRAME_METAL := "res://assets/ui/Backgroundframes/metalframe.webp"

func _ready() -> void:
	get_viewport().size_changed.connect(_build_ui)
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var screen_size := get_viewport().get_visible_rect().size
	var screen_w: float = screen_size.x
	var screen_h: float = screen_size.y

	var title_font_size: int = int(clampf(screen_w * 0.045, 30.0, 48.0))
	var card_w: float = clampf(screen_w * 0.16, 110.0, 170.0)
	var card_h: float = clampf(card_w * 1.5, 165.0, 255.0)
	var frame_extension: float = clampf(card_w * 0.12, 12.0, 22.0)
	var grid_h_sep: int = int(clampf(screen_w * 0.05, 28.0, 70.0))
	var grid_v_sep: int = int(clampf(screen_h * 0.04, 28.0, 70.0))
	var name_font_size: int = int(clampf(screen_w * 0.036, 22.0, 34.0))   # was 0.018 / 12–18
	var active_font_size: int = int(clampf(screen_w * 0.026, 16.0, 26.0))   # was 0.012 / 8–12

	# Back button 1.5x larger
	var back_btn_size: float = clampf(screen_w * 0.07, 50.0, 72.0) * 1.5

	var canvas := CanvasLayer.new()
	add_child(canvas)

	if ResourceLoader.exists(BG_PATH):
		var bg := TextureRect.new()
		bg.texture = UIFactory.cached_load(BG_PATH)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		canvas.add_child(bg)

	var darkener := ColorRect.new()
	darkener.color = Color(0, 0, 0, 0.5)
	darkener.set_anchors_preset(Control.PRESET_FULL_RECT)
	darkener.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(darkener)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", int(clampf(screen_h * 0.02, 18.0, 28.0)))
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(root_vbox)

	var title := Label.new()
	title.text = "SELECT BACKGROUND"
	title.add_theme_font_size_override("font_size", title_font_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", grid_h_sep)
	grid.add_theme_constant_override("v_separation", grid_v_sep)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root_vbox.add_child(grid)

	for i in range(GameState.BACKGROUNDS.size()):
		var card := _make_card(i, card_w, card_h, frame_extension, name_font_size, active_font_size)
		grid.add_child(card)

	var btn_canvas := CanvasLayer.new()
	btn_canvas.layer = 5
	add_child(btn_canvas)

	var back_btn := _make_texture_button(BACK_BTN_PATH, "", Vector2(back_btn_size, back_btn_size))
	back_btn.position = Vector2(14, 14)
	back_btn.pressed.connect(_on_back)
	btn_canvas.add_child(back_btn)

	_maybe_show_hint()

# One-time explanation. The rune list is read from GameData, so it stays
# correct if the drop tables change.
func _maybe_show_hint() -> void:
	var lines: Array = ["Tap a background to play on it.", "", "Each background drops different runes:"]
	var everywhere: bool = true   # do Soul and Earth drop on every background?
	for bg_data in GameState.BACKGROUNDS:
		var bg_drops: Dictionary = bg_data.get("rune_drops", {})
		if not bg_drops.has(GameState.Rune.SOUL) or not bg_drops.has(GameState.Rune.EARTH):
			everywhere = false
		var main_rune: String = ""
		var drops: Dictionary = bg_data.get("rune_drops", {})
		var best_weight: float = -1.0
		for rune_key in drops:
			if rune_key == GameState.Rune.SOUL or rune_key == GameState.Rune.EARTH:
				continue
			if float(drops[rune_key]) > best_weight:
				best_weight = float(drops[rune_key])
				main_rune = str(GameState.Rune.find_key(rune_key)).capitalize()
		if main_rune != "":
			lines.append("%s: %s" % [bg_data["name"], main_rune])
	if everywhere:
		lines.append("")
		lines.append("Soul and Earth runes drop on every background.")
	UIFactory.show_hint_card(self, "hint_backgrounds", "BACKGROUNDS", "\n".join(lines))

func _get_frame_for_index(index: int) -> String:
	match index % 3:
		0:
			return FRAME_TWISTEDMETAL
		1:
			return FRAME_LIGHTFLOWER
		2:
			return FRAME_METAL
		_:
			return FRAME_METAL

func _make_card(index: int, card_w: float, card_h: float, frame_extension: float, name_font_size: int, active_font_size: int) -> Control:
	var bg_data: Dictionary = GameState.BACKGROUNDS[index]
	var is_selected: bool = GameState.selected_background == index

	var card_container := Control.new()
	card_container.custom_minimum_size = Vector2(card_w, card_h)
	card_container.mouse_filter = Control.MOUSE_FILTER_STOP
	card_container.clip_contents = false
	card_container.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_selected else Control.CURSOR_POINTING_HAND

	var texture_path: String = bg_data.get("texture", "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var bg_texture := TextureRect.new()
		bg_texture.texture = UIFactory.cached_load(texture_path)
		bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_texture.stretch_mode = TextureRect.STRETCH_SCALE
		bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_container.add_child(bg_texture)
	else:
		var bg_color := ColorRect.new()
		bg_color.color = Color(0.1, 0.1, 0.1, 1.0)
		bg_color.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_container.add_child(bg_color)

	if is_selected:
		var glow := ColorRect.new()
		glow.color = Color(0.4, 0.9, 0.4, 0.3)
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_container.add_child(glow)

	var frame_path := _get_frame_for_index(index)
	if ResourceLoader.exists(frame_path):
		var frame := TextureRect.new()
		frame.texture = UIFactory.cached_load(frame_path)
		frame.anchor_left = 0.0
		frame.anchor_top = 0.0
		frame.anchor_right = 1.0
		frame.anchor_bottom = 1.0
		frame.offset_left = -frame_extension
		frame.offset_top = -frame_extension
		frame.offset_right = frame_extension
		frame.offset_bottom = frame_extension
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_container.add_child(frame)

	card_container.gui_input.connect(_on_card_input.bind(index))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_container.add_child(vbox)

	if is_selected:
		var status_lbl := Label.new()
		status_lbl.text = "✓ ACTIVE"
		status_lbl.add_theme_font_size_override("font_size", active_font_size)
		status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
		status_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		status_lbl.add_theme_constant_override("outline_size", maxi(4, int(active_font_size * 0.22)))
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(status_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	var name_lbl := Label.new()
	name_lbl.text = bg_data["name"]
	name_lbl.add_theme_font_size_override("font_size", name_font_size)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	# Dark outline + shadow so the name reads on light cards (Sunset) too.
	name_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", maxi(4, int(name_font_size * 0.22)))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	name_lbl.add_theme_constant_override("shadow_offset_y", maxi(1, int(name_font_size * 0.08)))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Keep the name off the bottom edge of the frame.
	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, name_font_size * 0.35)
	bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_pad)

	return card_container

func _make_texture_button(image_path: String, pressed_path: String, button_size: Vector2) -> TextureButton:
	var btn := TextureButton.new()

	if ResourceLoader.exists(image_path):
		btn.texture_normal = UIFactory.cached_load(image_path)
	else:
		push_warning("Missing texture: " + image_path)

	if pressed_path != "" and ResourceLoader.exists(pressed_path):
		btn.texture_pressed = UIFactory.cached_load(pressed_path)

	btn.custom_minimum_size = button_size
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.pivot_offset = button_size * 0.5

	btn.button_down.connect(func():
		btn.scale = Vector2(0.95, 0.95)
	)

	btn.button_up.connect(func():
		btn.scale = Vector2(1.0, 1.0)
	)

	btn.mouse_exited.connect(func():
		btn.scale = Vector2(1.0, 1.0)
	)

	return btn

func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_select(index)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_select(index)

func _on_select(index: int) -> void:
	if GameState.selected_background == index:
		return
	SoundManager.play_buy_background()
	GameState.selected_background = index
	GameState.save()
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()

func _on_back() -> void:
	SoundManager.play_click()
	UIFactory.change_scene(get_tree(), MENU_SCENE)
