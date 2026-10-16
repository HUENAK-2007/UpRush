# res://scripts/BackgroundManager.gd
class_name BackgroundManager
extends RefCounted

var sky_offset: Vector2 = Vector2.ZERO
var sky_scale: Vector2 = Vector2.ONE
var sky_object: Sprite2D = null

func setup(bg_layer: Node, p_sky_object: Sprite2D, bg_data: Dictionary) -> void:
	sky_object = p_sky_object
	sky_offset = bg_data.get("sky_offset", Vector2.ZERO)
	sky_scale = bg_data.get("sky_scale", Vector2.ONE)
	var bg_offset: Vector2 = bg_data.get("bg_offset", Vector2.ZERO)

	var texture_path: String = bg_data.get("texture", "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var tex_rect := TextureRect.new()
		tex_rect.texture = UIFactory.cached_load(texture_path)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.offset_left = bg_offset.x
		tex_rect.offset_top = bg_offset.y
		tex_rect.offset_right = 0
		tex_rect.offset_bottom = 0

		bg_layer.add_child(tex_rect)
		bg_layer.move_child(tex_rect, 0)

	var sky_path: String = bg_data.get("sky_object", "")
	if sky_path != "" and ResourceLoader.exists(sky_path) and is_instance_valid(sky_object):
		sky_object.texture = UIFactory.cached_load(sky_path)
		sky_object.visible = true
		sky_object.scale = sky_scale
		sky_object.z_index = 100
	else:
		if is_instance_valid(sky_object):
			sky_object.visible = false

func update_sky_position(viewport: Viewport) -> void:
	if not is_instance_valid(sky_object) or not sky_object.visible:
		return
	var rect := viewport.get_visible_rect().size
	sky_object.position = Vector2(
		rect.x * 0.5 + sky_offset.x,
		rect.y * 0.22 + sky_offset.y
	)
