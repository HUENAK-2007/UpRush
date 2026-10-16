extends Node
# res://scripts/UIFactory.gd
class_name UIFactory

const BTN_MAIN_MENU: String         = "res://assets/ui/buttons/Main Menu.webp"
const BTN_MAIN_MENU_PRESSED: String = "res://assets/ui/buttons/Maine_menu_pressed.webp"
const BTN_CLOSE: String             = "res://assets/ui/buttons/close.webp"
const BTN_OFF: String               = "res://assets/ui/buttons/Off.webp"
const BTN_ON: String                = "res://assets/ui/buttons/On.webp"
const BTN_OFF_CLICKED: String       = "res://assets/ui/buttons/Of_clicked.webp"
const BTN_SLIDE_BTN: String         = "res://assets/ui/buttons/Slide_button.webp"
const BTN_RESET: String             = "res://assets/ui/buttons/reset.webp"
const PAUSE_BG: String              = "res://assets/ui/backgrounds/Pause_Background.webp"
const COIN_ICON: String             = "res://assets/ui/icons/coin.webp"
const HEART_ICON: String            = "res://assets/ui/icons/heart.webp"
const GAME_OVER_IMG: String         = "res://assets/ui/Game over .webp"

const UI_SCALE: float = 1.7

# Keeps every resource it loads alive for the whole app session. Without this,
# Godot frees textures / scenes / sprite frames when the game scene is reloaded
# (Play Again) and has to read and decode them from disk again, which causes
# the restart lag.
static var _res_cache: Dictionary = {}

static func cached_load(path: String):   # untyped on purpose, like load() on a script path
	if _res_cache.has(path):
		return _res_cache[path]
	var res = load(path)
	if res != null:
		_res_cache[path] = res
	return res

# ── Smooth scene changes ─────────────────────────────────────────────────────
# Fades to black, loads the next scene in the background while the screen is
# black, switches, then fades back in. This hides the short freeze (and the
# grey flash) that a plain change_scene_to_file() shows while it loads.
static var _scene_changing: bool = false

static func change_scene(tree: SceneTree, path: String) -> void:
	if _scene_changing:
		return
	_scene_changing = true

	ResourceLoader.load_threaded_request(path)

	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP   # ignore taps during the change
	layer.add_child(rect)
	tree.root.add_child(layer)

	var fade_out := tree.create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.tween_property(rect, "color:a", 1.0, 0.15)
	await fade_out.finished

	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame

	var packed = ResourceLoader.load_threaded_get(path)
	tree.paused = false
	Engine.time_scale = 1.0
	if packed is PackedScene:
		tree.change_scene_to_packed(packed)
	else:
		tree.change_scene_to_file(path)

	# give the new scene two frames to build its UI while still black
	await tree.process_frame
	await tree.process_frame

	var fade_in := tree.create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.tween_property(rect, "color:a", 0.0, 0.2)
	await fade_in.finished
	layer.queue_free()
	_scene_changing = false

# ── First-time hints ─────────────────────────────────────────────────────────
# Stored in its own small file so the main save format (and players' progress)
# is not affected.
const HINTS_PATH: String = "user://hints.cfg"

static func hint_seen(key: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(HINTS_PATH) != OK:
		return false
	return bool(cfg.get_value("seen", key, false))

static func mark_hint_seen(key: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(HINTS_PATH)   # fine if the file does not exist yet
	cfg.set_value("seen", key, true)
	cfg.save(HINTS_PATH)

# One-time explanation card (dim background, title, text, GOT IT button).
# Does nothing if this hint was already dismissed. The caller keeps it simple:
# call it every time the screen is built; it only appears until dismissed.
static func show_hint_card(host: Node, key: String, title_text: String, body_text: String) -> CanvasLayer:
	if hint_seen(key):
		return null
	var screen: Vector2 = host.get_viewport().get_visible_rect().size
	var screen_w: float = screen.x
	var screen_h: float = screen.y

	var layer := CanvasLayer.new()
	layer.layer = 50
	host.add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # block taps behind the card
	layer.add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var card_w: float = minf(screen_w * 0.86, 640.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.12, 0.96)
	style.border_color = Color(0.49, 0.93, 0.93, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left   = 24
	style.content_margin_right  = 24
	style.content_margin_top    = 22
	style.content_margin_bottom = 22

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(card_w, 0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(clampf(screen_w * 0.045, 22.0, 40.0)))
	title.add_theme_color_override("font_color", Color(0.49, 0.93, 0.93, 1.0))
	vbox.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", int(clampf(screen_w * 0.034, 18.0, 30.0)))
	body.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	body.custom_minimum_size = Vector2(card_w - 48.0, 0)
	vbox.add_child(body)

	var btn_size := Vector2(clampf(screen_w * 0.26, 150.0, 240.0), clampf(screen_h * 0.045, 48.0, 70.0))
	var ok := TextureButton.new()
	ok.custom_minimum_size = btn_size
	ok.ignore_texture_size = true
	ok.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var normal_path := "res://assets/ui/buttons/Dark_button.png"
	var pressed_path := "res://assets/ui/buttons/Dark_button_pressed.png"
	if ResourceLoader.exists(normal_path):
		ok.texture_normal = cached_load(normal_path)
	if ResourceLoader.exists(pressed_path):
		ok.texture_pressed = cached_load(pressed_path)

	var ok_lbl := Label.new()
	ok_lbl.text = "GOT IT"
	ok_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ok_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ok_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ok_lbl.add_theme_font_size_override("font_size", int(clampf(screen_w * 0.030, 16.0, 26.0)))
	ok_lbl.add_theme_color_override("font_color", Color(0.49, 0.93, 0.93, 1.0))
	ok.add_child(ok_lbl)

	ok.pressed.connect(func():
		mark_hint_seen(key)
		layer.queue_free()
	)
	vbox.add_child(ok)
	return layer

static func make_icon_btn(tex_path: String, size: Vector2, pressed_path: String = "") -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = size
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(tex_path):
		btn.texture_normal = cached_load(tex_path)
	if pressed_path != "" and ResourceLoader.exists(pressed_path):
		btn.texture_pressed = cached_load(pressed_path)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.button_down.connect(func():
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.88, 0.88), 0.08)
	)
	btn.button_up.connect(func():
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)
	btn.pivot_offset = size * 0.5
	return btn

static func make_custom_slider(initial_value: float, slider_width: float, volume_callback: Callable) -> Control:
	var track_w: float = slider_width
	var thumb_size: float = 65.0
	var track_h: float = 8.0
	var container_h: float = thumb_size
	var pad: float = thumb_size * 0.5

	var container := Control.new()
	container.custom_minimum_size = Vector2(track_w, container_h)
	container.process_mode = Node.PROCESS_MODE_ALWAYS
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var inner_w: float = track_w - pad * 2.0

	var track_bg := ColorRect.new()
	track_bg.color = Color(0.15, 0.15, 0.15, 0.6)
	track_bg.position = Vector2(pad, (container_h - track_h) * 0.5)
	track_bg.size = Vector2(inner_w, track_h)
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(track_bg)

	var initial_fill: float = initial_value * (inner_w - thumb_size) + thumb_size * 0.5
	var fill := ColorRect.new()
	fill.color = Color(0.2, 0.5, 1.0, 0.85)
	fill.position = Vector2(pad, (container_h - track_h) * 0.5)
	fill.size = Vector2(initial_fill, track_h)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(fill)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.size = Vector2(track_w, container_h)
	slider.position = Vector2(0, 0)
	slider.modulate = Color(1, 1, 1, 0)
	slider.process_mode = Node.PROCESS_MODE_ALWAYS
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(slider)

	var thumb := TextureRect.new()
	thumb.size = Vector2(thumb_size, thumb_size)
	thumb.custom_minimum_size = Vector2(thumb_size, thumb_size)
	if ResourceLoader.exists(BTN_SLIDE_BTN):
		thumb.texture = cached_load(BTN_SLIDE_BTN)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.position = Vector2(
		pad + initial_value * (inner_w - thumb_size),
		0
	)
	container.add_child(thumb)

	slider.value_changed.connect(func(val: float):
		thumb.position.x = pad + val * (inner_w - thumb_size)
		fill.size.x = val * (inner_w - thumb_size) + thumb_size * 0.5
		volume_callback.call(val)
	)

	return container
