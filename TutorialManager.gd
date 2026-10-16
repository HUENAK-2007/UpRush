class_name TutorialManager
extends RefCounted

signal tutorial_finished

const TEXT_COLOR := Color(0.49, 0.93, 0.93, 1.0)
const DARK_BTN := "res://assets/ui/buttons/Dark_button.png"
const DARK_BTN_PRESSED := "res://assets/ui/buttons/Dark_button_pressed.png"

var _tutorial_layer: CanvasLayer = null
var _arrow_left: Label = null
var _arrow_right: Label = null
var _left_btn: Button = null
var _right_btn: Button = null
var _owner_node: Node = null

var is_active: bool:
	get: return is_instance_valid(_tutorial_layer)

func setup(owner: Node, left_btn: Button, right_btn: Button) -> void:
	_owner_node = owner
	_left_btn = left_btn
	_right_btn = right_btn

func show_tutorial() -> void:
	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.layer = 200
	_tutorial_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_owner_node.add_child(_tutorial_layer)

	var root := Control.new()
	root.name = "TutorialRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	_left_btn.text = "LEFT"
	_right_btn.text = "RIGHT"
	_left_btn.flat = false
	_right_btn.flat = false

	var title := Label.new()
	title.text = "HOW TO MOVE"
	title.add_theme_font_size_override("font_size", int(30 * UIFactory.UI_SCALE))
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(420, 40)
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(title)

	var center_msg := Label.new()
	center_msg.text = "Press LEFT / RIGHT to move\nDouble tap the same side to jump that direction"
	center_msg.add_theme_font_size_override("font_size", int(22 * UIFactory.UI_SCALE))
	center_msg.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	center_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_msg.size = Vector2(620, 80)
	center_msg.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(center_msg)

	var atk_title := Label.new()
	atk_title.text = "HOW TO ATTACK"
	atk_title.add_theme_font_size_override("font_size", int(26 * UIFactory.UI_SCALE))
	atk_title.add_theme_color_override("font_color", TEXT_COLOR)
	atk_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_title.size = Vector2(420, 40)
	atk_title.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(atk_title)

	var atk_msg := Label.new()
	atk_msg.text = "Press LEFT and RIGHT together to cast a spell in the direction you face. It needs a moment to recharge. Shoot birds to win runes!"
	atk_msg.add_theme_font_size_override("font_size", int(19 * UIFactory.UI_SCALE))
	atk_msg.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	atk_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	atk_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	atk_msg.size = Vector2(620, 150)
	atk_msg.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(atk_msg)

	var left_tip := Label.new()
	left_tip.text = "Move left\nDouble tap = jump left"
	left_tip.add_theme_font_size_override("font_size", int(20 * UIFactory.UI_SCALE))
	left_tip.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	left_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_tip.size = Vector2(260, 90)
	left_tip.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(left_tip)

	var right_tip := Label.new()
	right_tip.text = "Move right\nDouble tap = jump right"
	right_tip.add_theme_font_size_override("font_size", int(20 * UIFactory.UI_SCALE))
	right_tip.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	right_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_tip.size = Vector2(260, 90)
	right_tip.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(right_tip)

	_arrow_left = Label.new()
	_arrow_left.text = "↓"
	_arrow_left.add_theme_font_size_override("font_size", 46)
	_arrow_left.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_arrow_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow_left.size = Vector2(60, 60)
	_arrow_left.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_arrow_left)

	_arrow_right = Label.new()
	_arrow_right.text = "↓"
	_arrow_right.add_theme_font_size_override("font_size", 46)
	_arrow_right.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_arrow_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow_right.size = Vector2(60, 60)
	_arrow_right.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_arrow_right)

	# GOT IT button
	var got_it_size := Vector2(300, 96)
	var got_it := TextureButton.new()
	got_it.custom_minimum_size = got_it_size
	got_it.ignore_texture_size = true
	got_it.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(DARK_BTN):
		got_it.texture_normal = UIFactory.cached_load(DARK_BTN)
	if ResourceLoader.exists(DARK_BTN_PRESSED):
		got_it.texture_pressed = UIFactory.cached_load(DARK_BTN_PRESSED)
	got_it.process_mode = Node.PROCESS_MODE_ALWAYS
	got_it.pivot_offset = got_it_size * 0.5

	var got_it_label := Label.new()
	got_it_label.text = "GOT IT"
	got_it_label.add_theme_font_size_override("font_size", int(22 * UIFactory.UI_SCALE))
	got_it_label.add_theme_color_override("font_color", TEXT_COLOR)
	got_it_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	got_it_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	got_it_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	got_it_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	got_it.add_child(got_it_label)

	got_it.button_down.connect(func():
		var tw := got_it.create_tween()
		tw.tween_property(got_it, "scale", Vector2(0.88, 0.88), 0.08)
	)
	got_it.button_up.connect(func():
		var tw := got_it.create_tween()
		tw.tween_property(got_it, "scale", Vector2(1.0, 1.0), 0.08)
	)
	got_it.pressed.connect(_on_ok)
	root.add_child(got_it)

	await _owner_node.get_tree().process_frame

	var left_rect := _left_btn.get_global_rect()
	var right_rect := _right_btn.get_global_rect()
	var screen_size := _owner_node.get_viewport().get_visible_rect().size

	title.position = Vector2((screen_size.x - title.size.x) * 0.5, screen_size.y * 0.11)
	center_msg.position = Vector2((screen_size.x - center_msg.size.x) * 0.5, screen_size.y * 0.165)

	atk_title.position = Vector2((screen_size.x - atk_title.size.x) * 0.5, screen_size.y * 0.30)
	atk_msg.size.x = minf(620.0, screen_size.x * 0.92)
	atk_msg.position = Vector2((screen_size.x - atk_msg.size.x) * 0.5, screen_size.y * 0.345)

	left_tip.position = Vector2(
		left_rect.position.x + (left_rect.size.x - left_tip.size.x) * 0.5,
		left_rect.position.y - 120
	)
	right_tip.position = Vector2(
		right_rect.position.x + (right_rect.size.x - right_tip.size.x) * 0.5,
		right_rect.position.y - 120
	)

	_arrow_left.position = Vector2(
		left_rect.position.x + (left_rect.size.x - _arrow_left.size.x) * 0.5,
		left_rect.position.y - 48
	)
	_arrow_right.position = Vector2(
		right_rect.position.x + (right_rect.size.x - _arrow_right.size.x) * 0.5,
		right_rect.position.y - 48
	)

	var tips_top: float = minf(left_tip.position.y, right_tip.position.y)
	got_it.position = Vector2(
		(screen_size.x - got_it.custom_minimum_size.x) * 0.5,
		tips_top - got_it.custom_minimum_size.y - 24.0
	)

	_owner_node.get_tree().paused = true

func animate_arrows() -> void:
	if _arrow_left == null or _arrow_right == null:
		return

	var t := Time.get_ticks_msec() / 1000.0
	var offset := sin(t * 5.0) * 6.0

	var left_rect := _left_btn.get_global_rect()
	var right_rect := _right_btn.get_global_rect()

	_arrow_left.position.x = left_rect.position.x + (left_rect.size.x - _arrow_left.size.x) * 0.5
	_arrow_left.position.y = left_rect.position.y - 48 + offset

	_arrow_right.position.x = right_rect.position.x + (right_rect.size.x - _arrow_right.size.x) * 0.5
	_arrow_right.position.y = right_rect.position.y - 48 + offset

func _on_ok() -> void:
	if is_instance_valid(_tutorial_layer):
		_tutorial_layer.queue_free()
		_tutorial_layer = null

	GameState.tutorial_shown = true
	GameState.save()

	_owner_node.get_tree().paused = false
	tutorial_finished.emit()

func dismiss() -> void:
	_on_ok()
