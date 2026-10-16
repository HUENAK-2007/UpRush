class_name GameOverManager
extends RefCounted

signal play_again_requested
signal main_menu_requested

var _overlay: CanvasLayer = null
var _owner_node: Node = null
var _game_over_tex: Texture2D = null
var _coin_tex: Texture2D = null
var _dim: ColorRect = null
var _center: CenterContainer = null
var _transitioning: bool = false

const BASE_WIDTH: float = 720.0

func setup(owner: Node) -> void:
	_owner_node = owner
	# Preload here so no lag on death frame
	if ResourceLoader.exists(UIFactory.GAME_OVER_IMG):
		_game_over_tex = UIFactory.cached_load(UIFactory.GAME_OVER_IMG)
	if ResourceLoader.exists(UIFactory.COIN_ICON):
		_coin_tex = UIFactory.cached_load(UIFactory.COIN_ICON)

func build_overlay(max_climbed: float, score_scale: float, session_coins: int) -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_owner_node.add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	_dim = dim
	_transitioning = false

	var screen_size: Vector2 = _owner_node.get_viewport().get_visible_rect().size
	var sf: float = screen_size.x / BASE_WIDTH
	var btn_w: float = 420.0 * sf
	var btn_h: float = btn_w * 0.30
	var title_w: float = 560.0 * sf
	var title_h: float = title_w * 0.55
	var score_font: int = int(42.0 * sf)
	var coin_font: int = int(32.0 * sf)
	var coin_icon_size: float = 36.0 * sf
	var separation: int = int(28.0 * sf)
	var coin_sep: int = int(10.0 * sf)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	_center = center

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(vbox)

	var go_img := TextureRect.new()
	go_img.custom_minimum_size = Vector2(title_w, title_h)
	go_img.ignore_texture_size = true
	go_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	go_img.texture = _game_over_tex
	go_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(go_img)

	var score_lbl := Label.new()
	score_lbl.text = str(int(max_climbed / score_scale)) + " m"
	score_lbl.add_theme_font_size_override("font_size", score_font)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_lbl)

	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", coin_sep)
	vbox.add_child(coin_row)

	var coin_icon := TextureRect.new()
	coin_icon.custom_minimum_size = Vector2(coin_icon_size, coin_icon_size)
	coin_icon.ignore_texture_size = true
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.texture = _coin_tex
	coin_row.add_child(coin_icon)

	var coins_lbl := Label.new()
	coins_lbl.text = str(session_coins)
	coins_lbl.add_theme_font_size_override("font_size", coin_font)
	coins_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_row.add_child(coins_lbl)

	var reset_btn := UIFactory.make_icon_btn(UIFactory.BTN_RESET, Vector2(btn_w, btn_h))
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	reset_btn.pressed.connect(func(): _fade_out_then(play_again_requested))
	vbox.add_child(reset_btn)

	var menu_btn := UIFactory.make_icon_btn(UIFactory.BTN_MAIN_MENU, Vector2(btn_w, btn_h), UIFactory.BTN_MAIN_MENU_PRESSED)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.pressed.connect(func(): _fade_out_then(main_menu_requested))
	vbox.add_child(menu_btn)

# Smooth exit: the grey dim fades to solid black while the buttons and text
# fade away, and only then is the scene reloaded / changed. The new scene
# fades in from black (see Main._start_fade_in), so there is no grey flash.
func _fade_out_then(next_signal: Signal) -> void:
	if _transitioning or not is_instance_valid(_overlay):
		next_signal.emit()
		return
	_transitioning = true
	var tw: Tween = _overlay.create_tween()
	tw.set_parallel(true)
	if is_instance_valid(_dim):
		tw.tween_property(_dim, "color", Color(0, 0, 0, 1), 0.25)
	if is_instance_valid(_center):
		tw.tween_property(_center, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(func(): next_signal.emit())

func destroy_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
