extends Node

const MENU_SCENE: String = "res://scenes/MainMenu.tscn"
const BACK_BTN_PATH := "res://assets/ui/arrow_left.webp"
const ON_BTN_PATH := "res://assets/ui/buttons/On.webp"
const OFF_BTN_PATH := "res://assets/ui/buttons/Off.webp"
const BG_PATH := "res://assets/ui/backgrounds/Pause_Background.webp"
const SLIDER_THUMB_PATH := "res://assets/ui/buttons/Slide_button.webp"

const BASE_WIDTH: float = 720.0

func _ready() -> void:
	get_viewport().size_changed.connect(_build_ui)
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var screen_size := get_viewport().get_visible_rect().size
	var screen_w: float = screen_size.x
	var screen_h: float = screen_size.y
	var sf: float = screen_w / BASE_WIDTH

	var title_font_size: int = int(52.0 * sf)
	var label_font_size: int = int(32.0 * sf)

	var panel_w: float = 560.0 * sf
	var panel_padding: int = int(36.0 * sf)

	var slider_w: float = 460.0 * sf
	var slider_h: float = 56.0 * sf

	var toggle_btn_size: float = 120.0 * sf

	var back_btn_size: float = 90.0 * sf

	var root_sep: int = int(32.0 * sf)
	var settings_sep: int = int(28.0 * sf)
	var top_spacer_h: float = 20.0 * sf

	var slider_track_radius: int = int(10.0 * sf)
	var slider_track_margin: int = int(10.0 * sf)
	var panel_radius: int = int(20.0 * sf)

	var canvas := CanvasLayer.new()
	add_child(canvas)

	if ResourceLoader.exists(BG_PATH):
		var bg := TextureRect.new()
		bg.texture = UIFactory.cached_load(BG_PATH)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		canvas.add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", root_sep)
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(root_vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", title_font_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, top_spacer_h)
	root_vbox.add_child(spacer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_w, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root_vbox.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.72)
	panel_style.corner_radius_top_left = panel_radius
	panel_style.corner_radius_top_right = panel_radius
	panel_style.corner_radius_bottom_left = panel_radius
	panel_style.corner_radius_bottom_right = panel_radius
	panel_style.border_width_left = int(1.0 * sf)
	panel_style.border_width_top = int(1.0 * sf)
	panel_style.border_width_right = int(1.0 * sf)
	panel_style.border_width_bottom = int(2.0 * sf)
	panel_style.border_color = Color(0.28, 0.28, 0.36, 1.0)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", panel_padding)
	margin.add_theme_constant_override("margin_top", panel_padding)
	margin.add_theme_constant_override("margin_right", panel_padding)
	margin.add_theme_constant_override("margin_bottom", panel_padding)
	panel.add_child(margin)

	var settings_vbox := VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", settings_sep)
	margin.add_child(settings_vbox)

	var vol_lbl := Label.new()
	vol_lbl.text = "Master Volume"
	vol_lbl.add_theme_font_size_override("font_size", label_font_size)
	vol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_vbox.add_child(vol_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = SoundManager.master_volume
	slider.custom_minimum_size = Vector2(slider_w, slider_h)
	slider.value_changed.connect(_on_volume_changed)

	if ResourceLoader.exists(SLIDER_THUMB_PATH):
		var grabber_texture: Texture2D = UIFactory.cached_load(SLIDER_THUMB_PATH)
		slider.add_theme_icon_override("grabber", grabber_texture)
		slider.add_theme_icon_override("grabber_highlight", grabber_texture)
		slider.add_theme_icon_override("grabber_disabled", grabber_texture)

	var slider_style := StyleBoxFlat.new()
	slider_style.bg_color = Color(0.2, 0.4, 0.8, 1.0)
	slider_style.corner_radius_top_left = slider_track_radius
	slider_style.corner_radius_top_right = slider_track_radius
	slider_style.corner_radius_bottom_left = slider_track_radius
	slider_style.corner_radius_bottom_right = slider_track_radius
	slider_style.content_margin_top = slider_track_margin
	slider_style.content_margin_bottom = slider_track_margin
	slider.add_theme_stylebox_override("slider", slider_style)

	var grabber_area_style := StyleBoxFlat.new()
	grabber_area_style.bg_color = Color(0.3, 0.6, 1.0, 1.0)
	grabber_area_style.corner_radius_top_left = slider_track_radius
	grabber_area_style.corner_radius_top_right = slider_track_radius
	grabber_area_style.corner_radius_bottom_left = slider_track_radius
	grabber_area_style.corner_radius_bottom_right = slider_track_radius
	grabber_area_style.content_margin_top = slider_track_margin
	grabber_area_style.content_margin_bottom = slider_track_margin
	slider.add_theme_stylebox_override("grabber_area", grabber_area_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_area_style)

	settings_vbox.add_child(slider)

	var music_lbl := Label.new()
	music_lbl.text = "Background Music"
	music_lbl.add_theme_font_size_override("font_size", label_font_size)
	music_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_vbox.add_child(music_lbl)

	var music_btn_container := CenterContainer.new()
	settings_vbox.add_child(music_btn_container)

	var music_btn := _make_texture_button(
		ON_BTN_PATH if SoundManager.music_enabled else OFF_BTN_PATH,
		"",
		Vector2(toggle_btn_size, toggle_btn_size)
	)
	music_btn.pressed.connect(_on_music_toggle.bind(music_btn))
	music_btn_container.add_child(music_btn)

	var sfx_lbl := Label.new()
	sfx_lbl.text = "Sound Effects"
	sfx_lbl.add_theme_font_size_override("font_size", label_font_size)
	sfx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_vbox.add_child(sfx_lbl)

	var sfx_btn_container := CenterContainer.new()
	settings_vbox.add_child(sfx_btn_container)

	var sfx_btn := _make_texture_button(
		ON_BTN_PATH if SoundManager.sfx_enabled else OFF_BTN_PATH,
		"",
		Vector2(toggle_btn_size, toggle_btn_size)
	)
	sfx_btn.pressed.connect(_on_sfx_toggle.bind(sfx_btn))
	sfx_btn_container.add_child(sfx_btn)

	var btn_canvas := CanvasLayer.new()
	btn_canvas.layer = 5
	add_child(btn_canvas)

	var back_btn := _make_texture_button(BACK_BTN_PATH, "", Vector2(back_btn_size, back_btn_size))
	back_btn.position = Vector2(16.0 * sf, 16.0 * sf)
	back_btn.pressed.connect(_on_back)
	btn_canvas.add_child(back_btn)

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

func _on_volume_changed(value: float) -> void:
	SoundManager.set_volume(value)

func _on_music_toggle(btn: TextureButton) -> void:
	SoundManager.play_click()
	SoundManager.set_music_enabled(!SoundManager.music_enabled)

	if SoundManager.music_enabled:
		if ResourceLoader.exists(ON_BTN_PATH):
			btn.texture_normal = UIFactory.cached_load(ON_BTN_PATH)
	else:
		if ResourceLoader.exists(OFF_BTN_PATH):
			btn.texture_normal = UIFactory.cached_load(OFF_BTN_PATH)

func _on_sfx_toggle(btn: TextureButton) -> void:
	SoundManager.play_click()
	SoundManager.set_sfx_enabled(!SoundManager.sfx_enabled)

	if SoundManager.sfx_enabled:
		if ResourceLoader.exists(ON_BTN_PATH):
			btn.texture_normal = UIFactory.cached_load(ON_BTN_PATH)
	else:
		if ResourceLoader.exists(OFF_BTN_PATH):
			btn.texture_normal = UIFactory.cached_load(OFF_BTN_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()

func _on_back() -> void:
	SoundManager.play_click()
	UIFactory.change_scene(get_tree(), MENU_SCENE)
