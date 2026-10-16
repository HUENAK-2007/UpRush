extends Node

@export var spawn_interval_min: float = 2.5
@export var spawn_interval_max: float = 5.0
@export var start_height: float = 300.0   # pixels (= 30 m)
# Heights here are PIXELS. Birds reach their fastest spawn rate at this height
# (was 3000 px past the start = ~330 m; now ~1500 m, matching the platforms).
const DIFFICULTY_RAMP_PX: float = 15000.0
@export var bird_speed_min: float = 120.0
@export var bird_speed_max: float = 220.0
@export var collision_scale: float = 0.7

var _timer: float = 0.0
var _next_spawn: float = 3.0
var _total_climbed: float = 0.0
var _active_birds: Array = []
var _rng := RandomNumberGenerator.new()
var _bird_color: Color = Color(1.0, 0.92, 0.6, 1.0)
var _bird_frames_1: SpriteFrames = null
var _bird_frames_2: SpriteFrames = null
var _bird_scale_1: Vector2 = Vector2(1.0, 1.0)
var _bird_scale_2: Vector2 = Vector2(1.0, 1.0)
var _screen_scale: float = 1.0

func setup(_camera: Camera2D) -> void:
	_rng.randomize()
	_screen_scale = GameState.get_screen_scale()

	var bg: Dictionary = GameState.get_background()
	_bird_color = bg.get("bird_color", Color(1.0, 0.92, 0.6, 1.0))
	_bird_scale_1 = bg.get("bird_scale_1", Vector2(1.0, 1.0))
	_bird_scale_2 = bg.get("bird_scale_2", Vector2(1.0, 1.0))

	var path1: String = bg.get("bird_frames_1", "")
	var path2: String = bg.get("bird_frames_2", "")
	if path1 != "" and ResourceLoader.exists(path1):
		_bird_frames_1 = UIFactory.cached_load(path1)
	else:
		_bird_frames_1 = null

	if path2 != "" and ResourceLoader.exists(path2):
		_bird_frames_2 = UIFactory.cached_load(path2)
	else:
		_bird_frames_2 = null

func tick(delta: float, total_climbed: float, camera_top_y: float, camera_bottom_y: float) -> void:
	_total_climbed = total_climbed

	for bird in _active_birds.duplicate():
		if not is_instance_valid(bird):
			_active_birds.erase(bird)
			continue

		var view_w: float = get_viewport().get_visible_rect().size.x
		if bird.global_position.x < -view_w * 1.5 or bird.global_position.x > view_w * 1.5:
			bird.queue_free()
			_active_birds.erase(bird)

	if _total_climbed < start_height:
		return

	_timer += delta
	if _timer >= _next_spawn:
		_timer = 0.0
		var difficulty: float = clampf((_total_climbed - start_height) / DIFFICULTY_RAMP_PX, 0.0, 1.0)
		var min_i: float = lerpf(spawn_interval_min, 1.2, difficulty)
		var max_i: float = lerpf(spawn_interval_max, 2.5, difficulty)
		_next_spawn = _rng.randf_range(min_i, max_i)
		_spawn_bird(camera_top_y, camera_bottom_y)

func _spawn_bird(camera_top_y: float, camera_bottom_y: float) -> void:
	var view_w: float = get_viewport().get_visible_rect().size.x
	var half_w: float = view_w * 0.5
	var spawn_y: float = _rng.randf_range(camera_top_y + 80.0, camera_bottom_y - 80.0)
	var bird_dir: float = 1.0 if _rng.randf() < 0.5 else -1.0
	var spawn_x: float = -half_w - 50.0 if bird_dir > 0.0 else half_w + 50.0

	var bird: Node2D = _make_bird()
	get_parent().add_child(bird)
	bird.global_position = Vector2(spawn_x, spawn_y)

	var speed: float = _rng.randf_range(bird_speed_min, bird_speed_max) * _screen_scale
	if bird.has_method("setup"):
		bird.setup(speed, bird_dir)

	_active_birds.append(bird)

func reset() -> void:
	for bird in _active_birds:
		if is_instance_valid(bird):
			bird.queue_free()
	_active_birds.clear()
	_timer = 0.0
	_next_spawn = 3.0
	SoundManager.stop_bird_flap()

func _pick_bird() -> Dictionary:
	var has_1: bool = _bird_frames_1 != null
	var has_2: bool = _bird_frames_2 != null

	if has_1 and has_2:
		if _rng.randf() < 0.5:
			return {"frames": _bird_frames_1, "scale": _bird_scale_1}
		else:
			return {"frames": _bird_frames_2, "scale": _bird_scale_2}
	elif has_1:
		return {"frames": _bird_frames_1, "scale": _bird_scale_1}
	elif has_2:
		return {"frames": _bird_frames_2, "scale": _bird_scale_2}

	return {}

func _get_frame_size(frames: SpriteFrames) -> Vector2:
	if frames == null:
		return Vector2(30.0, 20.0)
	var anim_name: String = "fly" if frames.has_animation("fly") else "default"
	if frames.has_animation(anim_name) and frames.get_frame_count(anim_name) > 0:
		var first_frame: Texture2D = frames.get_frame_texture(anim_name, 0)
		if first_frame != null:
			return first_frame.get_size()
	return Vector2(30.0, 20.0)

func _make_bird() -> Node2D:
	var root := Area2D.new()
	root.set_script(UIFactory.cached_load("res://scripts/Bird.gd"))
	root.name = "Bird"
	root.collision_layer = 4
	root.collision_mask = 1

	var bird_data: Dictionary = _pick_bird()

	if bird_data.size() > 0:
		var frames: SpriteFrames = bird_data["frames"]
		var base_scale: Vector2 = bird_data["scale"]
		var final_scale: Vector2 = base_scale * _screen_scale

		var anim_sprite := AnimatedSprite2D.new()
		anim_sprite.sprite_frames = frames
		anim_sprite.scale = final_scale
		root.add_child(anim_sprite)

		if frames.has_animation("fly"):
			anim_sprite.play("fly")
		elif frames.has_animation("default"):
			anim_sprite.play("default")

		if root.has_method("set_animated_sprite"):
			root.set_animated_sprite(anim_sprite)

		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var tex_size: Vector2 = _get_frame_size(frames) * final_scale
		shape.size = tex_size * collision_scale
		collision.shape = shape
		root.add_child(collision)
	else:
		var s: float = _screen_scale
		var wing_color: Color = _bird_color.darkened(0.2)

		var body := ColorRect.new()
		body.color = _bird_color
		body.size = Vector2(30.0, 12.0) * s
		body.position = Vector2(-15.0, -6.0) * s
		root.add_child(body)

		var wing_l := ColorRect.new()
		wing_l.color = wing_color
		wing_l.size = Vector2(15.0, 8.0) * s
		wing_l.position = Vector2(-22.0, -14.0) * s
		root.add_child(wing_l)

		var wing_r := ColorRect.new()
		wing_r.color = wing_color
		wing_r.size = Vector2(15.0, 8.0) * s
		wing_r.position = Vector2(7.0, -14.0) * s
		root.add_child(wing_r)

		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(30.0, 20.0) * s
		collision.shape = shape
		root.add_child(collision)

	return root
