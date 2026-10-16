extends Node

@export var platform_scene:   PackedScene = preload("res://scenes/Platform.tscn")
@export var platform_scene_2: PackedScene = null
@export var pool_size:         int   = 16
@export var horizontal_margin: float = 70.0
@export var spawn_buffer:      float = 900.0
@export var recycle_buffer:    float = 800.0
@export var center_bias:       float = 0.01

# ── Physics-derived jump height ───────────────────────────────────────────
const PLAYER_JUMP_SPEED:   float = 820.0
const PLAYER_GRAVITY:      float = 1600.0
const MAX_JUMPABLE_HEIGHT: float = \
	(PLAYER_JUMP_SPEED * PLAYER_JUMP_SPEED) / (2.0 * PLAYER_GRAVITY) * 0.85

const JUMPABLE_GAP_MAX:   float = 160.0
const ROCK_GAP_MIN_Y:     float = 260.0
const ROCK_GAP_MAX_Y:     float = 380.0
const ROCK_GAP_CHANCE:    float = 0.40
const ROCK_GAP_MIN_SCORE: float = 300.0   # pixels (= 30 m)

# Everything in this file measures height in PIXELS (Main divides by 10 to get
# meters). The difficulty ramp used to finish at 3000 px = 300 m, so nothing got
# harder after that. It now reaches full difficulty at DIFFICULTY_FULL_AT_M.
const PX_PER_METER:          float = 10.0
const DIFFICULTY_FULL_AT_M:  float = 1500.0
const DIFFICULTY_RAMP_PX:    float = DIFFICULTY_FULL_AT_M * PX_PER_METER
# Moving-platform chance starts rising at 60 m and maxes at the same point.
const MOVING_RAMP_START_PX:  float = 600.0

signal cloud_spawned(local_pos: Vector2, platform: Node2D)
signal rock_gap_spawned(top_local_pos: Vector2, bottom_local_pos: Vector2)

var _rng := RandomNumberGenerator.new()
var _platforms: Array[Node2D] = []
var _player: CharacterBody2D
var _next_spawn_y:            float = 0.0
var _path_x:                  float = 0.0
var _total_climbed:           float = 0.0
var _last_move_padding_y:     float = 0.0
var _last_was_moving:         bool  = false
var _spawn_index:             int   = 0
var _drift_bias:              float = 0.0
var _recent_xs:               Array[float] = []
var _same_side_run:           int   = 0
var _same_column_run:         int   = 0
var _screen_scale:            float = 1.0
var _last_spawn_pos:          Vector2 = Vector2.ZERO
var _platform_width_factor_1: float = 1.0
var _platform_width_factor_2: float = 1.0

var _flip_counter: int  = 0
var _current_flip: bool = false

# ─────────────────────────────────────────────────────────────────────────────

func setup(player: CharacterBody2D) -> void:
	_player = player
	_rng.randomize()
	_screen_scale = GameState.get_screen_scale()

	var bg: Dictionary = GameState.get_background()
	var scene1_path: String = bg.get("platform_scene",   "res://scenes/Platform.tscn")
	var scene2_path: String = bg.get("platform_scene_2", "")
	_platform_width_factor_1 = bg.get("platform_width_factor_1", 1.0)
	_platform_width_factor_2 = bg.get("platform_width_factor_2", 1.0)

	if ResourceLoader.exists(scene1_path):
		platform_scene = UIFactory.cached_load(scene1_path)
	if scene2_path != "" and ResourceLoader.exists(scene2_path):
		platform_scene_2 = UIFactory.cached_load(scene2_path)
	else:
		platform_scene_2 = null

func _next_flip() -> bool:
	if _flip_counter >= 2:
		_current_flip = not _current_flip
		_flip_counter = 1
	else:
		if _rng.randf() < 0.30:
			_current_flip = not _current_flip
			_flip_counter = 1
		else:
			_flip_counter += 1
	return _current_flip

func reset_from_start(start_platform_local_pos: Vector2, initial_platforms: int) -> void:
	_total_climbed       = 0.0
	_last_move_padding_y = 0.0
	_last_was_moving     = false
	_spawn_index         = 0
	_drift_bias          = 0.0
	_recent_xs.clear()
	_same_side_run       = 0
	_same_column_run     = 0
	_last_spawn_pos      = start_platform_local_pos
	_flip_counter        = 0
	_current_flip        = false

	var screen_w    := get_viewport().get_visible_rect().size.x
	var play_band_w := screen_w * 0.68
	var spread      := play_band_w * 0.08
	_path_x = clampf(
		start_platform_local_pos.x + _rng.randf_range(-spread, spread),
		-play_band_w * 0.22,
		play_band_w  * 0.22
	)

	_next_spawn_y = start_platform_local_pos.y
	_ensure_pool()

	for i in range(mini(initial_platforms, _platforms.size())):
		var platform := _platforms[i]
		var x: float  = _path_x if i == 0 else _next_reachable_x(_path_x, platform)
		var spawn_pos := Vector2(x, _next_spawn_y)

		_place(platform, spawn_pos)
		_apply_platform_scale(platform)

		if i == 0:
			_configure_static(platform)
		else:
			_configure_platform(platform, x)

		cloud_spawned.emit(spawn_pos, platform)

		var gap: float = absf(spawn_pos.y - _last_spawn_pos.y)
		if gap > MAX_JUMPABLE_HEIGHT:
			rock_gap_spawned.emit(_last_spawn_pos, spawn_pos)

		_spawn_index    += 1
		_last_spawn_pos  = spawn_pos
		_path_x          = x
		_next_spawn_y   -= _next_gap_y(platform)

func tick(camera_top_y: float, camera_bottom_y: float, climbed_px: float) -> void:
	_total_climbed = climbed_px
	var target_spawn_y: float = camera_top_y - spawn_buffer

	while _next_spawn_y > target_spawn_y:
		var platform: Node2D = _get_next_platform(camera_bottom_y)
		if platform == null:
			break

		var x:     float = 0.0
		var gap_y: float = 0.0

		if _total_climbed >= ROCK_GAP_MIN_SCORE and _rng.randf() < ROCK_GAP_CHANCE:
			gap_y = _rng.randf_range(ROCK_GAP_MIN_Y, ROCK_GAP_MAX_Y)
			x     = _next_reachable_x_wide(_path_x, platform)
		else:
			gap_y = minf(_next_gap_y(platform), JUMPABLE_GAP_MAX)
			x     = _next_reachable_x(_path_x, platform)

		var spawn_pos := Vector2(x, _next_spawn_y)

		_place(platform, spawn_pos)
		_apply_platform_scale(platform)
		_configure_platform(platform, x)

		cloud_spawned.emit(spawn_pos, platform)

		var gap: float = absf(spawn_pos.y - _last_spawn_pos.y)
		if gap > MAX_JUMPABLE_HEIGHT:
			rock_gap_spawned.emit(_last_spawn_pos, spawn_pos)

		_spawn_index    += 1
		_last_spawn_pos  = spawn_pos
		_path_x          = x
		_next_spawn_y   -= gap_y

# ─────────────────────────────────────────────────────────────────────────────

func _place(platform: Node2D, local_pos: Vector2) -> void:
	platform.set_meta("flip_x", _next_flip())
	for child in platform.get_children():
		if child.is_in_group("platform_deco"):
			child.queue_free()
	if platform.has_method("on_spawned_at"):
		platform.on_spawned_at(local_pos)
	else:
		platform.position = local_pos

func _instantiate_platform() -> Node2D:
	if platform_scene_2 != null and _rng.randf() < 0.5:
		var p: Node2D = platform_scene_2.instantiate()
		p.set_meta("platform_variant", 2)
		p.set_meta("flip_x",    false)
		p.set_meta("is_moving", false)
		return p
	var p: Node2D = platform_scene.instantiate()
	p.set_meta("platform_variant", 1)
	p.set_meta("flip_x",    false)
	p.set_meta("is_moving", false)
	return p

func _apply_platform_scale(platform: Node2D) -> void:
	var width_factor := _get_platform_variant_factor(platform)
	var s:    float = _screen_scale * width_factor
	var flip: bool  = platform.get_meta("flip_x") if platform.has_meta("flip_x") else false
	platform.scale  = Vector2(s, s)
	_flip_sprites_in(platform, flip)

func _flip_sprites_in(node: Node, flip: bool) -> void:
	for child in node.get_children():
		if child is Sprite2D:
			(child as Sprite2D).flip_h = flip
			return
		elif child is AnimatedSprite2D:
			(child as AnimatedSprite2D).flip_h = flip
			return
	if node is Sprite2D:
		(node as Sprite2D).flip_h = flip
	elif node is AnimatedSprite2D:
		(node as AnimatedSprite2D).flip_h = flip

func _next_reachable_x_wide(prev_x: float, platform: Node2D) -> float:
	var screen_size   := get_viewport().get_visible_rect().size
	var play_band_w:   float = screen_size.x * 0.68
	var platform_size: Vector2 = _get_platform_visual_size(platform)
	var half_plat_w:   float = platform_size.x * 0.5
	var left:  float = -play_band_w * 0.5 + half_plat_w
	var right: float =  play_band_w * 0.5 - half_plat_w
	var min_dx:    float = play_band_w * 0.38
	var max_dx:    float = play_band_w * 0.52
	var dir:       float = 1.0 if prev_x <= 0.0 else -1.0
	var mag:       float = _rng.randf_range(min_dx, max_dx)
	var candidate: float = clampf(prev_x + dir * mag, left, right)
	_update_path_tracking(candidate, prev_x, play_band_w)
	return candidate

func _get_next_platform(camera_bottom_y: float) -> Node2D:
	for platform in _platforms:
		if platform.position.y > camera_bottom_y + recycle_buffer:
			var too_close: bool = false
			for other in _platforms:
				if other == platform:
					continue
				if other.position.y > camera_bottom_y + recycle_buffer:
					continue
				if abs(other.position.y - _next_spawn_y) < 100.0:
					too_close = true
					break
			if not too_close:
				return platform

	if _platforms.size() < pool_size * 2:
		var p := _instantiate_platform()
		get_parent().add_child(p)
		p.position = Vector2(0.0, 99999.0)
		_apply_platform_scale(p)
		_platforms.append(p)
		return p

	for platform in _platforms:
		if platform.position.y > camera_bottom_y + recycle_buffer:
			return platform

	var p := _instantiate_platform()
	get_parent().add_child(p)
	p.position = Vector2(0.0, 99999.0)
	_apply_platform_scale(p)
	_platforms.append(p)
	return p

func _get_platform_variant_factor(platform: Node2D) -> float:
	var variant := 1
	if platform.has_meta("platform_variant"):
		variant = int(platform.get_meta("platform_variant"))
	return _platform_width_factor_1 if variant == 1 else _platform_width_factor_2

func _get_platform_visual_size(platform: Node2D) -> Vector2:
	var sprite: Sprite2D = platform.get_node_or_null("Sprite2D")
	if sprite != null and sprite.texture != null:
		return sprite.texture.get_size() * platform.scale
	return Vector2(128, 32) * platform.scale

func _get_player_visual_size() -> Vector2:
	if _player == null:
		return Vector2(64, 64) * _screen_scale
	var sprite_root: Node = _player.get_node_or_null("Sprite2D")
	if sprite_root != null:
		var anim: AnimatedSprite2D = sprite_root.get_node_or_null("AnimatedSprite2D")
		if anim != null and anim.sprite_frames != null:
			var tex: Texture2D = null
			if anim.sprite_frames.has_animation("idle"):
				tex = anim.sprite_frames.get_frame_texture("idle", 0)
			elif anim.sprite_frames.get_animation_names().size() > 0:
				var first_anim: StringName = anim.sprite_frames.get_animation_names()[0]
				tex = anim.sprite_frames.get_frame_texture(first_anim, 0)
			if tex != null:
				return tex.get_size() * _player.scale
	return Vector2(64, 64) * _player.scale

func _next_gap_y(platform: Node2D) -> float:
	var screen_h:      float = get_viewport().get_visible_rect().size.y
	var platform_size: Vector2 = _get_platform_visual_size(platform)
	var player_size:   Vector2 = _get_player_visual_size()
	var difficulty:    float = clampf(_total_climbed / DIFFICULTY_RAMP_PX, 0.0, 1.0)

	var min_dynamic: float = screen_h * 0.072
	var max_dynamic: float = screen_h * 0.108
	var base:        float = _rng.randf_range(min_dynamic, max_dynamic)

	base += lerpf(0.0, screen_h * 0.024, difficulty)
	base -= platform_size.y * 0.10
	base += player_size.y   * 0.08

	var scale_compensation: float = (_screen_scale - 1.0) * 0.35
	if scale_compensation > 0.0:
		base += platform_size.y * scale_compensation

	if _last_was_moving:
		base += 26.0 * _screen_scale

	base += _last_move_padding_y
	return clampf(base, 70.0 * _screen_scale, JUMPABLE_GAP_MAX)

func _ensure_pool() -> void:
	if _platforms.size() > 0:
		return
	var parent := get_parent()
	for i in range(pool_size):
		var platform: Node2D
		if i % 2 == 0 or platform_scene_2 == null:
			platform = platform_scene.instantiate()
			platform.set_meta("platform_variant", 1)
		else:
			platform = platform_scene_2.instantiate()
			platform.set_meta("platform_variant", 2)
		platform.set_meta("flip_x",    i % 2 == 0)
		platform.set_meta("is_moving", false)
		parent.add_child(platform)
		platform.position = Vector2(0.0, 99999.0)
		_apply_platform_scale(platform)
		_platforms.append(platform)

func _next_reachable_x(prev_x: float, platform: Node2D) -> float:
	var screen_size   := get_viewport().get_visible_rect().size
	var play_band_w:   float = screen_size.x * 0.68
	var platform_size: Vector2 = _get_platform_visual_size(platform)
	var half_plat_w:   float = platform_size.x * 0.5
	var left:  float = -play_band_w * 0.5 + half_plat_w
	var right: float =  play_band_w * 0.5 - half_plat_w

	if left > right:
		return 0.0

	var player_size:       Vector2 = _get_player_visual_size()
	var difficulty:        float = clampf(_total_climbed / DIFFICULTY_RAMP_PX, 0.0, 1.0)
	var max_dx:            float = play_band_w * lerpf(0.30, 0.44, difficulty)
	max_dx = clampf(max_dx, 90.0 * _screen_scale, play_band_w * 0.45)

	var base_min_dx:       float = lerpf(36.0, 72.0, difficulty) * _screen_scale
	var required_edge_gap: float = platform_size.x * 0.45 + player_size.x * 0.25
	var effective_min_dx:  float = maxf(base_min_dx, required_edge_gap)

	for _i in range(28):
		var go_right_probability := clampf(0.5 - _drift_bias * 0.35, 0.15, 0.85)
		var dir: float = 1.0 if _rng.randf() < go_right_probability else -1.0

		if _same_side_run >= 2:
			dir = -1.0 if prev_x > 0.0 else 1.0

		var mag:       float = _rng.randf_range(effective_min_dx, max_dx)
		var candidate: float = prev_x + dir * mag

		var normalized_offset := 0.0
		if right != 0.0:
			normalized_offset = prev_x / right

		candidate -= normalized_offset * max_dx * 0.22
		candidate  = lerpf(candidate, 0.0, center_bias)
		candidate  = clampf(candidate, left, right)

		var actual_dx: float = abs(candidate - prev_x)
		if actual_dx < effective_min_dx:
			continue
		if _same_column_run >= 1 and actual_dx < effective_min_dx * 1.15:
			continue

		_update_path_tracking(candidate, prev_x, play_band_w)
		return candidate

	var fallback_sign: float = -1.0 if prev_x > 0.0 else 1.0
	var fallback := clampf(prev_x + fallback_sign * effective_min_dx, left, right)
	_update_path_tracking(fallback, prev_x, play_band_w)
	return fallback

func _update_path_tracking(candidate: float, prev_x: float, play_band_w: float) -> void:
	var same_column_threshold: float = play_band_w * 0.16

	if abs(candidate - prev_x) < same_column_threshold:
		_same_column_run += 1
	else:
		_same_column_run = 0

	var prev_side := 0
	if prev_x > 0.0:   prev_side =  1
	elif prev_x < 0.0: prev_side = -1

	var new_side := 0
	if candidate > 0.0:   new_side =  1
	elif candidate < 0.0: new_side = -1

	if new_side != 0 and new_side == prev_side:
		_same_side_run += 1
	else:
		_same_side_run = 0

	var side_float := 0.0
	if candidate > 0.0:   side_float =  1.0
	elif candidate < 0.0: side_float = -1.0

	_drift_bias = clampf(_drift_bias * 0.78 + side_float * 0.22, -1.0, 1.0)
	_recent_xs.append(candidate)
	if _recent_xs.size() > 5:
		_recent_xs.pop_front()

func _configure_static(platform: Node2D) -> void:
	_last_was_moving     = false
	_last_move_padding_y = 0.0
	platform.set_meta("is_moving", false)
	if platform.has_method("configure"):
		var palette: Array[Color] = [
			Color(0.247059, 0.776471, 0.352941, 1.0),
			Color(0.231373, 0.509804, 0.964706, 1.0),
			Color(0.933333, 0.419608, 0.337255, 1.0),
			Color(0.639216, 0.333333, 0.941176, 1.0)
		]
		platform.configure(0, palette[_rng.randi_range(0, palette.size()-1)], 0.0, 0.0, 0.0, false)

func _configure_platform(platform: Node2D, x: float) -> void:
	var moving_chance: float = 0.22 + clampf((_total_climbed - MOVING_RAMP_START_PX) / (DIFFICULTY_RAMP_PX - MOVING_RAMP_START_PX), 0.0, 1.0) * 0.22
	var force_moving:  bool  = (_spawn_index % 5) == 0
	var is_moving:     bool  = force_moving or (_rng.randf() < moving_chance)
	var is_vertical:   bool  = false
	if is_moving:
		is_vertical = _rng.randf() < 0.45

	platform.set_meta("is_moving", is_moving)

	var amp_used: float = 0.0
	var palette: Array[Color] = [
		Color(0.247059, 0.776471, 0.352941, 1.0),
		Color(0.231373, 0.509804, 0.964706, 1.0),
		Color(0.933333, 0.419608, 0.337255, 1.0),
		Color(0.639216, 0.333333, 0.941176, 1.0)
	]
	var chosen_color: Color = palette[_rng.randi_range(0, palette.size()-1)]

	if platform.has_method("configure"):
		var kind:  int   = 1 if is_moving else 0
		var amp:   float = _rng.randf_range(35.0, 72.0) * _screen_scale
		var speed: float = _rng.randf_range(0.8, 1.4)
		var phase: float = _rng.randf() * TAU

		if is_moving and not is_vertical:
			var screen_w:      float = get_viewport().get_visible_rect().size.x
			var play_band_w:   float = screen_w * 0.68
			var platform_size: Vector2 = _get_platform_visual_size(platform)
			var half_plat_w:   float = platform_size.x * 0.5
			var left:          float = -play_band_w * 0.5 + half_plat_w
			var right:         float =  play_band_w * 0.5 - half_plat_w
			var safe_margin:   float = 60.0 * _screen_scale
			var max_amp:       float = maxf(10.0, minf(x - left, right - x) - safe_margin)
			amp = minf(amp, max_amp)

		if is_moving and is_vertical:
			amp = _rng.randf_range(18.0, 34.0) * _screen_scale

		amp_used = amp
		platform.configure(kind, chosen_color, amp, speed, phase, is_vertical)

	_last_was_moving     = is_moving
	_last_move_padding_y = (amp_used * 0.85) if (is_moving and is_vertical) else 0.0
