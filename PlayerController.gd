class_name PlayerController
extends RefCounted

signal died(bird_killed: bool)
signal respawned
signal game_over_triggered

const FLASH_DURATION: float = 0.3
const RESPAWN_DELAY: float = 1.2
const SLOW_MO_SCALE: float = 0.18
const GRACE_PERIOD: float = 1.5
const PLAYER_BASE_SCALE: float = 2.45

var player: CharacterBody2D
var lives: int = 3
var invincible: bool = false
var dead: bool = false

var _is_flashing: bool = false
var _flash_timer: float = 0.0
var _is_respawning: bool = false
var _respawn_timer: float = 0.0
var _grace_timer: float = 0.0
var _bird_killed: bool = false
var _highest_player_y: float = 0.0
var _screen_scale: float = 1.0

var _left_pressed: bool = false
var _right_pressed: bool = false
var _last_left_tap_ms: int = -999999
var _last_right_tap_ms: int = -999999
var _double_tap_ms: int = 260
var _facing_dir: int = 1

var _attack_triggered: bool = false
var _suppress_cancelled: bool = false
var _pending_jump: bool = false

func setup(p_player: CharacterBody2D, double_tap_ms: int) -> void:
	player = p_player
	_double_tap_ms = double_tap_ms
	_screen_scale = GameState.get_screen_scale()

	var char_index: int = GameState.selected_character
	var stats: Dictionary = GameState.get_character_stats(char_index)
	var char_data: Dictionary = GameState.get_character()

	if stats.size() > 0:
		player.move_speed = stats["move_speed"] * _screen_scale
		player.jump_speed  = stats["jump_speed"] * _screen_scale
		player.gravity     = stats["gravity"]
	else:
		player.move_speed = char_data.get("speed",   420.0) * _screen_scale
		player.jump_speed = char_data.get("jump",    820.0) * _screen_scale
		player.gravity    = char_data.get("gravity", 1600.0)

	var final_scale: float = PLAYER_BASE_SCALE * _screen_scale
	player.scale = Vector2(final_scale, final_scale)

	if char_data.has("frames"):
		var frames_path: String = char_data["frames"]
		if frames_path != "" and ResourceLoader.exists(frames_path):
			var anim: AnimatedSprite2D = player.get_node_or_null("Sprite2D/AnimatedSprite2D")
			if is_instance_valid(anim):
				var loaded_frames = UIFactory.cached_load(frames_path)
				if loaded_frames != null:
					anim.sprite_frames = loaded_frames
					if anim.sprite_frames != null and anim.sprite_frames.has_animation("idle"):
						anim.play("idle")

	_highest_player_y = player.global_position.y

func get_player_visual_height() -> float:
	var sprite_root: Node = player.get_node_or_null("Sprite2D")
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
				return tex.get_size().y * player.scale.y
	return 64.0 * player.scale.y

func _clear_input_state() -> void:
	_left_pressed = false
	_right_pressed = false
	_pending_jump = false
	_last_left_tap_ms = -999999
	_last_right_tap_ms = -999999

func place_on_platform(platform_pos: Vector2) -> void:
	var player_h: float = get_player_visual_height()
	var spawn_offset: float = player_h * 0.6 + 20.0
	player.global_position = Vector2(platform_pos.x, platform_pos.y - spawn_offset)
	player.velocity = Vector2.ZERO
	if player.has_method("reset_motion"):
		player.reset_motion()
	player.modulate = Color(1.0, 1.0, 1.0, 1.0)
	dead = false
	invincible = true
	_grace_timer = 0.5
	_suppress_cancelled = true
	_attack_triggered = false
	_clear_input_state()
	if is_instance_valid(player) and player.is_inside_tree():
		player.suppress_turns = false
	_highest_player_y = player.global_position.y

func on_left_down() -> void:
	var now := Time.get_ticks_msec()
	_left_pressed = true
	if now - _last_left_tap_ms <= _double_tap_ms:
		_pending_jump = true
		_last_left_tap_ms = -999999
	else:
		_last_left_tap_ms = now

func on_left_up() -> void:
	_left_pressed = false

func on_right_down() -> void:
	var now := Time.get_ticks_msec()
	_right_pressed = true
	if now - _last_right_tap_ms <= _double_tap_ms:
		_pending_jump = true
		_last_right_tap_ms = -999999
	else:
		_last_right_tap_ms = now

func on_right_up() -> void:
	_right_pressed = false

func try_attack_from_input() -> void:
	if _attack_triggered:
		return
	var actual_dir: int = player.get_facing_dir()
	if actual_dir == 0:
		if _facing_dir != 0:
			actual_dir = _facing_dir
		else:
			return
	_attack_triggered = true
	player.external_axis = 0.0
	if player.has_method("cancel_turn"):
		player.cancel_turn()
	else:
		player.suppress_turns = true
	player.get_tree().call_group("main", "spawn_magic_circle", player.global_position, actual_dir)
	_finish_attack_suppress()

func try_attack_from_input_dir(dir: int) -> void:
	if _attack_triggered:
		return
	if dir == 0:
		return
	_attack_triggered = true
	player.external_axis = 0.0
	if player.has_method("cancel_turn"):
		player.cancel_turn()
	else:
		player.suppress_turns = true
	player.get_tree().call_group("main", "spawn_magic_circle", player.global_position, dir)
	_finish_attack_suppress()

func _finish_attack_suppress() -> void:
	_suppress_cancelled = false
	await player.get_tree().create_timer(0.6).timeout
	if _suppress_cancelled:
		return
	if is_instance_valid(player) and player.is_inside_tree():
		player.suppress_turns = false
	_attack_triggered = false

func update_axis(viewport: Viewport) -> void:
	if _attack_triggered:
		player.external_axis = 0.0
		_clamp_horizontally(viewport)
		if _pending_jump:
			_pending_jump = false
		return

	var axis := 0.0
	if _left_pressed and not _right_pressed:
		axis = -1.0
		_facing_dir = -1
	elif _right_pressed and not _left_pressed:
		axis = 1.0
		_facing_dir = 1

	if _pending_jump:
		_pending_jump = false
		player.request_jump(float(_facing_dir))
		SoundManager.play_jump()

	player.external_axis = axis
	_clamp_horizontally(viewport)

func check_attack() -> void:
	pass

func _clamp_horizontally(viewport: Viewport) -> void:
	var size := viewport.get_visible_rect().size
	var half_w := size.x * 0.5
	var margin: float = 16.0 * _screen_scale
	player.global_position.x = clampf(player.global_position.x, -half_w + margin, half_w - margin)

func update_grace(delta: float) -> void:
	if _grace_timer > 0.0:
		_grace_timer -= delta
		if _grace_timer <= 0.0:
			invincible = false
			player.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			var blink: bool = int(_grace_timer * 8.0) % 2 == 0
			player.modulate.a = 1.0 if blink else 0.4

func process_flash(delta: float) -> bool:
	if not _is_flashing:
		return false
	_flash_timer -= delta
	var flash_on: bool = int(_flash_timer * 10.0) % 2 == 0
	player.modulate = Color(1.0, 0.2, 0.2, 1.0) if flash_on else Color(1.0, 1.0, 1.0, 1.0)
	if _flash_timer <= 0.0:
		_is_flashing = false
		player.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_start_fall()
	return true

func process_respawn(delta: float) -> bool:
	if not _is_respawning:
		return false
	_respawn_timer -= delta
	if _bird_killed:
		player.velocity.y += 2800.0 * delta
		player.velocity.x = 0.0
	else:
		player.velocity.y += 1600.0 * delta
	player.move_and_slide()
	if _respawn_timer <= 0.0:
		_do_respawn()
	return true

func trigger_death(from_bird: bool = false) -> void:
	_suppress_cancelled = true
	_attack_triggered = false
	_clear_input_state()
	if is_instance_valid(player) and player.is_inside_tree():
		player.suppress_turns = false
	_bird_killed = from_bird
	dead = true
	invincible = true
	lives -= 1
	Engine.time_scale = SLOW_MO_SCALE
	_is_flashing = true
	_flash_timer = FLASH_DURATION
	player.velocity.x = 0.0
	died.emit(from_bird)

func _start_fall() -> void:
	Engine.time_scale = 1.0
	if _bird_killed:
		player.velocity.y = 900.0
		player.velocity.x = 0.0
	else:
		player.velocity.y = 400.0
		player.velocity.x = 0.0
	_is_respawning = true
	_respawn_timer = RESPAWN_DELAY if lives > 0 else 0.8

func _do_respawn() -> void:
	_is_respawning = false
	_bird_killed = false
	Engine.time_scale = 1.0
	if lives <= 0:
		game_over_triggered.emit()
		return
	respawned.emit()

func do_respawn_placement(world: Node2D, cam: Camera2D, viewport: Viewport) -> void:
	var best_platform: Node2D = null
	var best_dist: float = INF
	var ref_y: float = _highest_player_y
	var player_h: float = get_player_visual_height()
	var spawn_offset: float = player_h * 0.6 + 20.0

	for child in world.get_children():
		if child.has_method("configure"):
			var dist: float = abs(child.global_position.y - ref_y)
			var rect := viewport.get_visible_rect()
			var screen_bottom: float = cam.global_position.y + rect.size.y * 0.5
			if child.global_position.y < screen_bottom and dist < best_dist:
				best_dist = dist
				best_platform = child

	if best_platform != null:
		player.global_position = Vector2(
			best_platform.global_position.x,
			best_platform.global_position.y - spawn_offset
		)
	else:
		player.global_position = Vector2(0.0, _highest_player_y)

	player.velocity = Vector2.ZERO
	if player.has_method("reset_motion"):
		player.reset_motion()
	player.modulate = Color(1.0, 1.0, 1.0, 1.0)
	dead = false
	invincible = true
	_grace_timer = GRACE_PERIOD
	_suppress_cancelled = true
	_attack_triggered = false
	_clear_input_state()
	if is_instance_valid(player) and player.is_inside_tree():
		player.suppress_turns = false
	_highest_player_y = player.global_position.y

func update_highest_y() -> void:
	_highest_player_y = minf(_highest_player_y, player.global_position.y)

func check_fell_off_screen(cam: Camera2D, viewport: Viewport) -> bool:
	if invincible:
		return false
	var rect := viewport.get_visible_rect()
	var bottom_y := cam.global_position.y + rect.size.y * 0.5
	return player.global_position.y > bottom_y

var highest_player_y: float:
	get: return _highest_player_y
	set(v): _highest_player_y = v
