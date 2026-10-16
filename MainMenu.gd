extends Node2D

@onready var bg_control: Control = get_node_or_null("Control")

const GAME_SCENE: String = "res://scenes/Main.tscn"
const CHAR_SELECT_SCENE: String = "res://scenes/CharacterSelect.tscn"
const BG_SELECT_SCENE: String = "res://scenes/BackgroundSelect.tscn"
const SETTINGS_SCENE: String = "res://scenes/Settings.tscn"

const TITLE_PATH := "res://assets/ui/title.webp"
const PLAY_BTN_PATH := "res://assets/ui/buttons/play.webp"
const PLAY_BTN_PRESSED_PATH := "res://assets/ui/buttons/play_pressed.webp"
const CHAR_BTN_PATH := "res://assets/ui/buttons/select_character.webp"
const CHAR_BTN_PRESSED_PATH := "res://assets/ui/buttons/charachter_pressed.webp"
const BG_BTN_PATH := "res://assets/ui/buttons/select_background.webp"
const BG_BTN_PRESSED_PATH := "res://assets/ui/buttons/bacground_pressed.webp"
const SETTINGS_BTN_PATH := "res://assets/ui/buttons/settings.webp"
const QUESTION_BTN_PATH := "res://assets/ui/buttons/Question.webp"
const COIN_ICON_PATH := "res://assets/ui/icons/coin.webp"
const RUNE_ICON_PATH := "res://assets/Sprites/Runes/all.webp"

const BG_OVERSCAN := 9.0

func _ready() -> void:
	get_viewport().size_changed.connect(_rebuild_ui)
	_build_ui()
	call_deferred("_fit_background")

func _rebuild_ui() -> void:
	_build_ui()
	call_deferred("_fit_background")

func _build_ui() -> void:
	for child in get_children():
		if child is CanvasLayer:
			child.queue_free()

	var screen_size := get_viewport().get_visible_rect().size
	var screen_w: float = screen_size.x
	var screen_h: float = screen_size.y

	var title_w: float = clampf(screen_w * 0.82, 540.0, 940.0)
	var title_h: float = title_w * 0.42

	var button_w: float = clampf(screen_w * 0.58, 430.0, 620.0)
	var button_h: float = button_w * 0.28

	var settings_size: float = clampf(screen_w * 0.095, 72.0, 100.0) * 1.35
	var question_size: float = settings_size

	var side_btn_gap: float = clampf(screen_h * 0.018, 12.0, 20.0)

	var top_tab_h: float = clampf(screen_h * 0.082, 76.0, 100.0)
	var top_tab_y: float = 0.0

	var title_top: float = screen_h * 0.12
	var title_bottom: float = title_top + title_h

	var buttons_top_shift: float = screen_h * 0.25

	var coin_icon_size: float = clampf(screen_w * 0.045, 32.0, 46.0)
	var coins_font_size: int = int(clampf(screen_w * 0.038, 28.0, 40.0))
	var best_font_size: int = int(clampf(screen_w * 0.030, 24.0, 32.0))

	var canvas := CanvasLayer.new()
	add_child(canvas)

	if is_instance_valid(bg_control):
		if bg_control.get_parent() != canvas:
			var old_parent := bg_control.get_parent()
			if old_parent != null:
				old_parent.remove_child(bg_control)
			canvas.add_child(bg_control)
			canvas.move_child(bg_control, 0)
		_fit_background()

	var top_tab := PanelContainer.new()
	top_tab.anchor_left = 0.0
	top_tab.anchor_top = 0.0
	top_tab.anchor_right = 1.0
	top_tab.anchor_bottom = 0.0
	top_tab.offset_top = top_tab_y
	top_tab.offset_bottom = top_tab_y + top_tab_h
	top_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	tab_style.border_width_bottom = 2
	tab_style.border_color = Color(0.32, 0.32, 0.40, 1.0)
	top_tab.add_theme_stylebox_override("panel", tab_style)
	canvas.add_child(top_tab)

	var tab_hbox := HBoxContainer.new()
	tab_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab_hbox.add_theme_constant_override("separation", int(clampf(screen_w * 0.05, 30.0, 60.0)))
	top_tab.add_child(tab_hbox)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_hbox.add_child(left_spacer)

	# Coins
	var coins_hbox := HBoxContainer.new()
	coins_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_hbox.add_theme_constant_override("separation", 8)
	tab_hbox.add_child(coins_hbox)

	if ResourceLoader.exists(COIN_ICON_PATH):
		var coin_icon := TextureRect.new()
		coin_icon.texture = UIFactory.cached_load(COIN_ICON_PATH)
		coin_icon.custom_minimum_size = Vector2(coin_icon_size, coin_icon_size)
		coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coins_hbox.add_child(coin_icon)

	var coins_label := Label.new()
	coins_label.text = str(GameState.lifetime_coins)
	coins_label.add_theme_font_size_override("font_size", coins_font_size)
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_hbox.add_child(coins_label)

	# Runes
	var rune_hbox := HBoxContainer.new()
	rune_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rune_hbox.add_theme_constant_override("separation", 8)
	tab_hbox.add_child(rune_hbox)

	if ResourceLoader.exists(RUNE_ICON_PATH):
		var rune_icon := TextureRect.new()
		rune_icon.texture = UIFactory.cached_load(RUNE_ICON_PATH)
		rune_icon.custom_minimum_size = Vector2(coin_icon_size, coin_icon_size)
		rune_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rune_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rune_hbox.add_child(rune_icon)

	var total_runes: int = 0
	for rune_count in GameState.runes.values():
		total_runes += rune_count

	var rune_label := Label.new()
	rune_label.text = str(total_runes)
	rune_label.add_theme_font_size_override("font_size", coins_font_size)
	rune_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rune_hbox.add_child(rune_label)

	# Best score
	var best_hbox := HBoxContainer.new()
	best_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	best_hbox.add_theme_constant_override("separation", 8)
	tab_hbox.add_child(best_hbox)

	var best_label := Label.new()
	best_label.text = "Best: " + str(GameState.best_score) + " m"
	best_label.add_theme_font_size_override("font_size", best_font_size)
	best_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	best_hbox.add_child(best_label)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_hbox.add_child(right_spacer)

	var title_container := CenterContainer.new()
	title_container.anchor_left = 0.0
	title_container.anchor_top = 0.0
	title_container.anchor_right = 1.0
	title_container.anchor_bottom = 0.0
	title_container.offset_top = title_top
	title_container.offset_bottom = title_bottom
	canvas.add_child(title_container)

	if ResourceLoader.exists(TITLE_PATH):
		var title_tex := TextureRect.new()
		title_tex.texture = UIFactory.cached_load(TITLE_PATH)
		title_tex.custom_minimum_size = Vector2(title_w, title_h)
		title_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_container.add_child(title_tex)
	else:
		var title := Label.new()
		title.text = "CLIMB"
		title.add_theme_font_size_override("font_size", int(clampf(screen_w * 0.10, 72.0, 110.0)))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_container.add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = buttons_top_shift
	canvas.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(clampf(screen_h * 0.024, 22.0, 34.0)))
	center.add_child(vbox)

	var play_btn := _make_texture_button(PLAY_BTN_PATH, PLAY_BTN_PRESSED_PATH, Vector2(button_w, button_h))
	play_btn.pressed.connect(_on_play)
	vbox.add_child(play_btn)

	var char_btn := _make_texture_button(CHAR_BTN_PATH, CHAR_BTN_PRESSED_PATH, Vector2(button_w, button_h))
	char_btn.pressed.connect(_on_character_select)
	vbox.add_child(char_btn)

	var bg_btn := _make_texture_button(BG_BTN_PATH, BG_BTN_PRESSED_PATH, Vector2(button_w, button_h))
	bg_btn.pressed.connect(_on_background_select)
	vbox.add_child(bg_btn)

	var settings_btn := _make_texture_button(SETTINGS_BTN_PATH, "", Vector2(settings_size, settings_size))
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_bottom = 0.0
	settings_btn.offset_left = -settings_size - 14
	settings_btn.offset_top = top_tab_h + 16
	settings_btn.offset_right = -14
	settings_btn.offset_bottom = top_tab_h + 16 + settings_size
	settings_btn.pressed.connect(_on_settings)
	canvas.add_child(settings_btn)

	var question_btn := _make_texture_button(QUESTION_BTN_PATH, "", Vector2(question_size, question_size))
	question_btn.anchor_left = 1.0
	question_btn.anchor_top = 0.0
	question_btn.anchor_right = 1.0
	question_btn.anchor_bottom = 0.0
	question_btn.offset_left = -question_size - 14
	question_btn.offset_top = top_tab_h + 16 + settings_size + side_btn_gap
	question_btn.offset_right = -14
	question_btn.offset_bottom = question_btn.offset_top + question_size
	question_btn.pressed.connect(_on_question)
	canvas.add_child(question_btn)

func _fit_background() -> void:
	if not is_instance_valid(bg_control):
		return

	_fit_control_to_screen(bg_control, BG_OVERSCAN)

	var visuals: Array[Control] = []
	_collect_background_visuals(bg_control, visuals)

	if visuals.is_empty():
		return

	for visual in visuals:
		_fit_control_to_screen(visual, BG_OVERSCAN)

		if visual is TextureRect:
			var tex := visual as TextureRect
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_SCALE
		elif visual is VideoStreamPlayer:
			var video := visual as VideoStreamPlayer
			video.expand = true

func _fit_control_to_screen(ctrl: Control, overscan: float = 0.0) -> void:
	ctrl.anchor_left = 0.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_right = 1.0
	ctrl.anchor_bottom = 1.0
	ctrl.offset_left = -overscan
	ctrl.offset_top = -overscan
	ctrl.offset_right = overscan
	ctrl.offset_bottom = overscan

func _collect_background_visuals(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		if child is VideoStreamPlayer or child is TextureRect or child is ColorRect:
			out.append(child as Control)
		_collect_background_visuals(child, out)

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

func _on_play() -> void:
	SoundManager.play_click()
	UIFactory.change_scene(get_tree(), GAME_SCENE)

func _on_character_select() -> void:
	SoundManager.play_click()
	UIFactory.change_scene(get_tree(), CHAR_SELECT_SCENE)

func _on_background_select() -> void:
	SoundManager.play_click()
	UIFactory.change_scene(get_tree(), BG_SELECT_SCENE)

func _on_settings() -> void:
	SoundManager.play_click()
	UIFactory.change_scene(get_tree(), SETTINGS_SCENE)

func _on_question() -> void:
	SoundManager.play_click()
	GameState.tutorial_shown = false
	GameState.save()
	UIFactory.change_scene(get_tree(), GAME_SCENE)
