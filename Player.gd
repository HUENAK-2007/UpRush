extends CharacterBody2D

signal died(bird_killed: bool)
signal respawned

var move_speed:   float = 420.0
var gravity:      float = 1600.0
var jump_speed:   float = 820.0

@export var jump_horizontal_boost: float = 1.05
@export var floor_snap:            float = 8.0
@export var physics_safe_margin:   float = 0.04

@export var anim_speed_normal:       float = 1.35
@export var hold_turn_delay_frames:  int   = 2
@export var walk_hold_threshold:     int   = 10
@export var air_turn_delay_frames:   int   = 6
@export var jump_buffer_frames:      int   = 6
# Frames after walking/falling off a platform during which a jump still works.
@export var coyote_frames:           int   = 6

@onready var anim: AnimatedSprite2D = $Sprite2D/AnimatedSprite2D

var _jump_stream := preload("res://assets/sounds/Jump.wav")

enum GroundState {
	IDLE,
	TURNING,
	WAIT_NEXT_TURN,
	WALKING
}

var external_axis:    float = 0.0
var suppress_turns:   bool  = false
var _jump_dir:        float = 0.0
var _jump_buffer_timer: int = 0
var _coyote_timer:     int = 0
var _just_jumped:     bool  = false
var _was_on_floor:    bool  = false
var _on_floor:        bool  = false
var _first_frame:     bool  = true
var _spawn_freeze_frames: int = 0

# ── Boost jump ────────────────────────────────────────────────────────────
const BOOST_MULTIPLIER: float = 1.4
var boost_active: bool  = false
var _glow_tween:  Tween = null

var _jump_sound: AudioStreamPlayer = null

var _facing_dir:      int = 0
var _turn_target_dir: int = 0
var _input_dir:       int = 0
var _prev_input_dir:  int = 0
var _tap_dir:         int = 0
var _input_held_frames: int = 0
var _ground_state:    int = GroundState.IDLE
var _wait_turn_dir:   int = 0
var _wait_turn_frames: int = 0
var _air_turn_timer:  int = 0
var _anim_cache: Dictionary = {}

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	platform_floor_layers = 1
	platform_wall_layers  = 0
	floor_snap_length     = floor_snap
	safe_margin           = physics_safe_margin

	velocity             = Vector2.ZERO
	_just_jumped         = false
	_jump_buffer_timer   = 0
	_was_on_floor        = false
	_on_floor            = false
	_first_frame         = true
	_spawn_freeze_frames = 0

	if is_instance_valid(anim) and anim.sprite_frames != null:
		if not anim.animation_finished.is_connected(_on_animation_finished):
			anim.animation_finished.connect(_on_animation_finished)
		anim.speed_scale = anim_speed_normal
		for a in anim.sprite_frames.get_animation_names():
			_anim_cache[a] = true
		if _has_anim("idle"):
			anim.play("idle")

	_jump_sound = AudioStreamPlayer.new()
	_jump_sound.bus    = "SFX"
	_jump_sound.stream = _jump_stream
	add_child(_jump_sound)

func get_facing_dir() -> int:
	return _facing_dir

func cancel_turn() -> void:
	suppress_turns = true
	_tap_dir       = 0
	_ground_state  = GroundState.IDLE

func reset_motion() -> void:
	velocity             = Vector2.ZERO
	_jump_dir            = 0.0
	_jump_buffer_timer   = 0
	_coyote_timer        = 0
	_just_jumped         = false
	_was_on_floor        = false
	_on_floor            = false
	_first_frame         = true
	_spawn_freeze_frames = 3
	external_axis        = 0.0
	suppress_turns       = false
	_input_dir           = 0
	_prev_input_dir      = 0
	_tap_dir             = 0
	_input_held_frames   = 0
	_ground_state        = GroundState.IDLE
	_wait_turn_dir       = 0
	_wait_turn_frames    = 0
	_turn_target_dir     = 0
	_facing_dir          = 0
	_air_turn_timer      = 0
	# Reset boost state on respawn
	boost_active = false
	_stop_glow()
	if is_instance_valid(anim):
		anim.speed_scale = anim_speed_normal

# ── Boost functions ───────────────────────────────────────────────────────

func activate_boost() -> void:
	boost_active = true
	_start_glow()

func deactivate_boost() -> void:
	boost_active = false
	_stop_glow()

func _start_glow() -> void:
	if _glow_tween:
		_glow_tween.kill()
	if not is_instance_valid(anim):
		return
	_glow_tween = get_tree().create_tween()
	_glow_tween.set_loops()
	# Pulse between bright electric blue and normal
	_glow_tween.tween_property(anim, "modulate",
		Color(0.4, 0.8, 2.0, 1.0), 0.35).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(anim, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.35).set_ease(Tween.EASE_IN_OUT)

func _stop_glow() -> void:
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	if is_instance_valid(anim):
		anim.modulate = Color(1.0, 1.0, 1.0, 1.0)

# Always remember the request: if the tap comes slightly before landing, the
# jump fires on the landing frame instead of being thrown away.
func request_jump(dir: float) -> void:
	_jump_buffer_timer = jump_buffer_frames
	_jump_dir          = clampf(dir, -1.0, 1.0)

func _do_jump(dir: float) -> void:
	# Apply boost multiplier if active, then deactivate
	var effective_speed: float = jump_speed
	if boost_active:
		effective_speed = jump_speed * BOOST_MULTIPLIER
		deactivate_boost()

	velocity.y = -effective_speed
	_coyote_timer      = 0   # no second jump from the same ledge
	_jump_buffer_timer = 0
	if abs(dir) > 0.01:
		velocity.x = dir * move_speed * jump_horizontal_boost
	_just_jumped  = true
	_ground_state = GroundState.IDLE
	if is_instance_valid(_jump_sound) and SoundManager.sfx_enabled:
		_jump_sound.play()

# ─────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _spawn_freeze_frames > 0:
		_spawn_freeze_frames -= 1
		velocity = Vector2.ZERO
		return

	if _first_frame:
		_first_frame = false
		velocity     = Vector2.ZERO
		return

	_on_floor = is_on_floor()
	if _on_floor:
		_coyote_timer = coyote_frames
	elif _coyote_timer > 0:
		_coyote_timer -= 1

	var axis := external_axis
	if abs(axis) < 0.001:
		axis = Input.get_axis("ui_left", "ui_right")

	_prev_input_dir = _input_dir

	if axis < -0.001:
		_input_dir = -1
	elif axis > 0.001:
		_input_dir = 1
	else:
		_input_dir = 0

	if _input_dir != 0 and _prev_input_dir == 0:
		_tap_dir = _input_dir
	else:
		_tap_dir = 0

	if suppress_turns:
		_tap_dir = 0

	if _input_dir != 0 and _input_dir == _prev_input_dir:
		_input_held_frames += 1
	else:
		_input_held_frames = 1 if _input_dir != 0 else 0

	_update_wait_next_turn()

	if not _on_floor:
		velocity.x = axis * move_speed
	elif _ground_state == GroundState.TURNING:
		velocity.x = axis * move_speed * 0.6
	elif _ground_state == GroundState.WAIT_NEXT_TURN:
		velocity.x = axis * move_speed * 0.6
	elif _ground_state == GroundState.WALKING \
			and _input_dir != 0 \
			and _facing_dir != 0 \
			and _facing_dir == _input_dir:
		velocity.x = axis * move_speed
	elif _tap_dir != 0 and _facing_dir != 0 and _facing_dir == _tap_dir:
		velocity.x = axis * move_speed
	else:
		velocity.x = 0.0

	velocity.y += gravity * delta

	if _jump_buffer_timer > 0:
		_jump_buffer_timer -= 1

	if _jump_buffer_timer > 0 and (_on_floor or _coyote_timer > 0):
		_do_jump(_jump_dir)

	if not _was_on_floor and _on_floor and not _just_jumped:
		SoundManager.play_landing()
		_air_turn_timer = 0

	_was_on_floor = _on_floor

	if not _just_jumped and velocity.y >= 0.0:
		apply_floor_snap()

	move_and_slide()

	_on_floor = is_on_floor()

	_update_animation_state()
	_just_jumped = false

# ─────────────────────────────────────────────────────────────────────────────

func _has_anim(anim_name: String) -> bool:
	return _anim_cache.get(anim_name, false)

func _play_if_not(anim_name: String) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)

func _apply_flip() -> void:
	anim.flip_h = (_facing_dir > 0)

func _get_next_facing(current: int, input: int) -> int:
	if input == 0:
		return current
	if current == input:
		return current
	if input < 0:
		return maxi(current - 1, -1)
	else:
		return mini(current + 1, 1)

func _play_idle_for_facing() -> void:
	anim.speed_scale = anim_speed_normal
	if _facing_dir == 0:
		if not _on_floor:
			if _has_anim("jump"):
				_play_if_not("jump")
		else:
			if _has_anim("idle"):
				_play_if_not("idle")
	else:
		_apply_flip()
		if not _on_floor:
			if _has_anim("fly_left"):
				_play_if_not("fly_left")
			elif _has_anim("jump"):
				_play_if_not("jump")
		else:
			if _has_anim("idle_left"):
				_play_if_not("idle_left")
			elif _has_anim("idle"):
				_play_if_not("idle")

func _play_air_for_facing() -> void:
	anim.speed_scale = anim_speed_normal
	if _facing_dir == 0:
		if _has_anim("jump"):
			_play_if_not("jump")
		return
	_apply_flip()
	if _has_anim("fly_left"):
		_play_if_not("fly_left")
	elif _has_anim("jump"):
		_play_if_not("jump")

func _play_walk_for_facing() -> void:
	if _facing_dir == 0:
		_play_idle_for_facing()
		return
	_apply_flip()
	anim.speed_scale = anim_speed_normal
	if _has_anim("walk_left"):
		_play_if_not("walk_left")
	elif _has_anim("idle_left"):
		_play_if_not("idle_left")

func _start_turn_to(new_facing: int) -> void:
	_ground_state    = GroundState.TURNING
	_turn_target_dir = new_facing
	anim.speed_scale = 2.5
	velocity.x      *= 0.3

	if new_facing == 0 and _facing_dir == -1:
		if _has_anim("turn_left"):
			anim.flip_h = false
			anim.play_backwards("turn_left")
			return

	if new_facing == 0 and _facing_dir == 1:
		if _has_anim("turn_left"):
			anim.flip_h = true
			anim.play_backwards("turn_left")
			return

	if _has_anim("turn_left"):
		anim.flip_h = (new_facing > 0)
		anim.play("turn_left")
	else:
		_ground_state = GroundState.IDLE
		_facing_dir   = new_facing

func _begin_wait_for_next_turn(dir: int) -> void:
	_ground_state  = GroundState.WAIT_NEXT_TURN
	_wait_turn_dir = dir
	_wait_turn_frames = 0

func _update_wait_next_turn() -> void:
	if _ground_state != GroundState.WAIT_NEXT_TURN:
		return
	if _input_dir != _wait_turn_dir or _input_dir == 0:
		_ground_state  = GroundState.IDLE
		_wait_turn_dir = 0
		_wait_turn_frames = 0
		return
	_wait_turn_frames += 1
	if _wait_turn_frames >= 1:
		var next_facing := _get_next_facing(_facing_dir, _wait_turn_dir)
		if next_facing != _facing_dir:
			_start_turn_to(next_facing)
		else:
			if _facing_dir != 0 and _input_held_frames >= walk_hold_threshold:
				_ground_state = GroundState.WALKING
			else:
				_ground_state = GroundState.IDLE
		_wait_turn_dir    = 0
		_wait_turn_frames = 0

func _update_animation_state() -> void:
	if not is_instance_valid(anim):
		return
	if anim.sprite_frames == null:
		return

	if not _on_floor:
		_ground_state = GroundState.IDLE

		if not suppress_turns:
			var desired_dir: int = 0
			if _input_dir != 0:
				desired_dir = _input_dir
			elif velocity.x < -10.0:
				desired_dir = -1
			elif velocity.x > 10.0:
				desired_dir = 1

			if desired_dir != 0 and _facing_dir != desired_dir:
				_air_turn_timer += 1
				if _air_turn_timer >= air_turn_delay_frames:
					_air_turn_timer = 0
					_facing_dir = _get_next_facing(_facing_dir, desired_dir)
			else:
				_air_turn_timer = 0

		_apply_flip()
		_play_air_for_facing()
		return

	if _ground_state == GroundState.TURNING:
		return

	if suppress_turns:
		_ground_state = GroundState.IDLE
		_play_idle_for_facing()
		return

	if _tap_dir != 0:
		var next_facing := _get_next_facing(_facing_dir, _tap_dir)
		if next_facing != _facing_dir:
			_start_turn_to(next_facing)
			return

	if _ground_state == GroundState.WAIT_NEXT_TURN and _input_dir != 0:
		if _facing_dir == 0:
			if _has_anim("idle"):
				_play_if_not("idle")
		else:
			if _has_anim("idle_left"):
				_apply_flip()
				_play_if_not("idle_left")
			else:
				_play_idle_for_facing()
		return

	if _input_dir != 0 \
			and _facing_dir != 0 \
			and _facing_dir == _input_dir \
			and _input_held_frames >= walk_hold_threshold:
		_ground_state = GroundState.WALKING
		_play_walk_for_facing()
		return

	_ground_state = GroundState.IDLE
	_play_idle_for_facing()

func _on_animation_finished() -> void:
	if not is_instance_valid(anim):
		return
	if anim.sprite_frames == null:
		return

	if _ground_state == GroundState.TURNING \
			and (anim.animation == "turn_left" \
			or anim.animation == "turn_from_left_straight"):
		_ground_state = GroundState.IDLE
		_facing_dir   = _turn_target_dir
		_apply_flip()
		anim.speed_scale = anim_speed_normal

		if not _on_floor:
			_play_air_for_facing()
			return

		if _input_dir != 0 and _facing_dir != 0 and _facing_dir == _input_dir:
			_ground_state = GroundState.WALKING
			_play_walk_for_facing()
			return

		if _input_dir != 0:
			var next_facing := _get_next_facing(_facing_dir, _input_dir)
			if next_facing != _facing_dir:
				_begin_wait_for_next_turn(_input_dir)
				_play_idle_for_facing()
				return

		_ground_state = GroundState.IDLE
		_play_idle_for_facing()
