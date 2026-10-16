class_name AttackManager
extends RefCounted

const ATTACK_OVERLAP_MS:   int = 200
const REPRESS_LOCKOUT_MS:  int = 150
const MAX_FIRST_PRESS_MS:  int = 800
const SIMULTANEOUS_TAP_MS: int = 50

var _overlap_start_ms: int = -999999
var _armed_dir:        int = 0

var _left_touches:  Dictionary = {}
var _right_touches: Dictionary = {}

var _left_last_release_ms:  int = -999999
var _right_last_release_ms: int = -999999
var _left_first_press_ms:   int = -999999
var _right_first_press_ms:  int = -999999

var _player:      CharacterBody2D  = null
var _player_ctrl: PlayerController = null
var _can_attack:  bool  = true
var _cooldown:    float = 2.0

signal attack_fired(dir: int)

# ─────────────────────────────────────────────────────────────────────────────

func setup(player: CharacterBody2D, player_ctrl: PlayerController) -> void:
	_player      = player
	_player_ctrl = player_ctrl

func clear_touch_state() -> void:
	_left_touches.clear()
	_right_touches.clear()
	_left_first_press_ms   = -999999
	_right_first_press_ms  = -999999
	_left_last_release_ms  = -999999
	_right_last_release_ms = -999999
	_overlap_start_ms      = -999999
	_armed_dir             = 0

func on_touch(event: InputEventScreenTouch, screen_size: Vector2) -> void:
	var half_x:   float = screen_size.x * 0.5
	var is_left:  bool  = event.position.x < half_x
	if event.position.y < screen_size.y * 0.15:
		return

	if event.pressed:
		if is_left:
			var was_empty: bool = _left_touches.is_empty()
			_left_touches[event.index] = true
			if was_empty:
				_player_ctrl.on_left_down()
				_left_first_press_ms = Time.get_ticks_msec()
			if not _right_touches.is_empty() and _overlap_start_ms == -999999:
				var now := Time.get_ticks_msec()
				var recently_released := _left_last_release_ms != -999999 and now - _left_last_release_ms < REPRESS_LOCKOUT_MS
				var held_too_long     := _right_first_press_ms != -999999 and now - _right_first_press_ms > MAX_FIRST_PRESS_MS
				var simultaneous      := _right_first_press_ms != -999999 and now - _right_first_press_ms <= SIMULTANEOUS_TAP_MS
				if simultaneous or (not recently_released and not held_too_long):
					_arm_attack(now)
		else:
			var was_empty: bool = _right_touches.is_empty()
			_right_touches[event.index] = true
			if was_empty:
				_player_ctrl.on_right_down()
				_right_first_press_ms = Time.get_ticks_msec()
			if not _left_touches.is_empty() and _overlap_start_ms == -999999:
				var now := Time.get_ticks_msec()
				var recently_released := _right_last_release_ms != -999999 and now - _right_last_release_ms < REPRESS_LOCKOUT_MS
				var held_too_long     := _left_first_press_ms != -999999 and now - _left_first_press_ms > MAX_FIRST_PRESS_MS
				var simultaneous      := _left_first_press_ms != -999999 and now - _left_first_press_ms <= SIMULTANEOUS_TAP_MS
				if simultaneous or (not recently_released and not held_too_long):
					_arm_attack(now)
	else:
		if is_left:
			_left_touches.erase(event.index)
			if _left_touches.is_empty():
				_player_ctrl.on_left_up()
				_left_last_release_ms = Time.get_ticks_msec()
				_left_first_press_ms  = -999999
		else:
			_right_touches.erase(event.index)
			if _right_touches.is_empty():
				_player_ctrl.on_right_up()
				_right_last_release_ms = Time.get_ticks_msec()
				_right_first_press_ms  = -999999

func _arm_attack(now: int) -> void:
	_overlap_start_ms = now
	_armed_dir        = _player.get_facing_dir()
	if _armed_dir == 0:
		_overlap_start_ms = -999999
		return
	if _player.has_method("cancel_turn"):
		_player.cancel_turn()
	# Fire immediately — no waiting for tick
	_fire_attack()

func _fire_attack() -> void:
	_overlap_start_ms = -999999
	if _can_attack and _armed_dir != 0:
		_player_ctrl.try_attack_from_input_dir(_armed_dir)
		attack_fired.emit(_armed_dir)
		if OS.get_name() == "Android":
			Input.vibrate_handheld(40)
	else:
		if is_instance_valid(_player) and _player.is_inside_tree():
			_player.suppress_turns = false
	_armed_dir = 0

func tick(_delta: float) -> bool:
	# Attack now fires immediately in _arm_attack
	# tick kept for compatibility but does nothing
	if _overlap_start_ms == -999999:
		return false

	# Fallback cancel if somehow still armed after 500ms
	var elapsed: int = Time.get_ticks_msec() - _overlap_start_ms
	if elapsed >= 500:
		_overlap_start_ms = -999999
		_armed_dir        = 0
		if is_instance_valid(_player) and _player.is_inside_tree():
			_player.suppress_turns = false

	return false

func set_can_attack(value: bool) -> void:
	_can_attack = value

func is_left_held() -> bool:
	return not _left_touches.is_empty()

func is_right_held() -> bool:
	return not _right_touches.is_empty()
