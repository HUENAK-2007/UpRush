extends Node

@export var coin_spawn_interval: float = 150.0
@export var coin_chance: float = 0.6
@export var coin_scale: float = 0.75

var _coin_scene: PackedScene = preload("res://scenes/Coin.tscn")
var _rng := RandomNumberGenerator.new()
var _active_coins: Array = []
var _highest_spawned_y: float = 0.0
var _initialized: bool = false
var _last_x: float = 0.0
var _recent_xs: Array[float] = []
var _drift_bias: float = 0.0

func setup(start_y: float) -> void:
	_rng.randomize()
	_highest_spawned_y = start_y
	_initialized = true
	_last_x = 0.0
	_recent_xs.clear()
	_drift_bias = 0.0

func tick(player_y: float, _camera_top_y: float, camera_bottom_y: float) -> void:
	if not _initialized:
		return

	while player_y < _highest_spawned_y + coin_spawn_interval:
		_highest_spawned_y -= coin_spawn_interval + _rng.randf_range(0.0, 80.0)
		if _rng.randf() < coin_chance:
			_spawn_coin_at(_highest_spawned_y)

	for c in _active_coins.duplicate():
		if not is_instance_valid(c):
			_active_coins.erase(c)
			continue
		if c.global_position.y > camera_bottom_y + 150.0:
			c.queue_free()
			_active_coins.erase(c)

func _spawn_coin_at(y: float) -> void:
	var view_w: float = get_viewport().get_visible_rect().size.x
	var play_band_w: float = view_w * 0.92
	var left: float = -play_band_w * 0.5 + 40.0
	var right: float = play_band_w * 0.5 - 40.0

	var x := _get_next_coin_x(left, right, play_band_w)

	var coin: Node2D = _coin_scene.instantiate()
	coin.position = Vector2(x, y)
	coin.scale = Vector2(coin_scale, coin_scale)
	get_parent().add_child(coin)
	_active_coins.append(coin)
	coin.call_deferred("connect_collected", Callable(self, "_on_coin_collected").bind(coin))

func _get_next_coin_x(left: float, right: float, play_band_w: float) -> float:
	var min_dx: float = play_band_w * 0.16
	var max_dx: float = play_band_w * 0.36

	for _i in range(20):
		var go_right_probability := 0.5 - _drift_bias * 0.30
		go_right_probability = clampf(go_right_probability, 0.18, 0.82)

		var dir: float = 1.0 if _rng.randf() < go_right_probability else -1.0
		var mag: float = _rng.randf_range(min_dx, max_dx)
		var candidate: float = _last_x + dir * mag

		var half_range := maxf(1.0, right)
		var normalized_offset := _last_x / half_range
		candidate -= normalized_offset * max_dx * 0.18

		candidate = clampf(candidate, left, right)

		var too_close := false
		for rx in _recent_xs:
			if abs(candidate - rx) < play_band_w * 0.12:
				too_close = true
				break

		if too_close:
			continue

		_update_coin_tracking(candidate)
		return candidate

	var fallback := _rng.randf_range(left, right)
	_update_coin_tracking(fallback)
	return fallback

func _update_coin_tracking(x: float) -> void:
	var side := 0.0
	if x > 0.0:
		side = 1.0
	elif x < 0.0:
		side = -1.0

	_drift_bias = clampf(_drift_bias * 0.80 + side * 0.20, -1.0, 1.0)
	_last_x = x

	_recent_xs.append(x)
	if _recent_xs.size() > 5:
		_recent_xs.pop_front()

func reset() -> void:
	for c in _active_coins:
		if is_instance_valid(c):
			c.queue_free()
	_active_coins.clear()
	_initialized = false
	_recent_xs.clear()
	_last_x = 0.0
	_drift_bias = 0.0

func _on_coin_collected(coin: Node) -> void:
	_active_coins.erase(coin)
	get_tree().call_group("main", "on_coin_collected")
