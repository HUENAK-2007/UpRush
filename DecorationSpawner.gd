extends Node

# ── Night assets (index 0) ────────────────────────────────────────────────
const NIGHT_TREE:     String = "res://scenes/Background_Assets/Night_scene/Tree_night.tscn"
const NIGHT_MUSHROOM: String = "res://scenes/Background_Assets/Night_scene/Mushroom_night.tscn"
const NIGHT_ROCK:     String = "res://scenes/Background_Assets/Night_scene/Rock_night.tscn"

# ── Sunset assets (index 1) ───────────────────────────────────────────────
const SUNSET_TREE:     String = "res://scenes/Background_Assets/Sunset_scenes/Tree_sunset.tscn"
const SUNSET_MUSHROOM: String = "res://scenes/Background_Assets/Sunset_scenes/Mushroom_sunset.tscn"
const SUNSET_ROCK:     String = "res://scenes/Background_Assets/Sunset_scenes/Rock_sunset.tscn"

# ── Ocean assets (index 2) ────────────────────────────────────────────────
const OCEAN_TREE:     String = "res://scenes/Background_Assets/Ocean_scenes/Tree_pceoan.tscn"
const OCEAN_MUSHROOM: String = "res://scenes/Background_Assets/Ocean_scenes/Mushroom_oceoan.tscn"
const OCEAN_ROCK:     String = "res://scenes/Background_Assets/Ocean_scenes/Rock_ocean.tscn"

# ── Tree spacing on clouds ────────────────────────────────────────────────
const PIXELS_PER_METER:  float = 10.0
const DECO_MIN_METERS:   float = 60.0
const DECO_MAX_METERS:   float = 100.0
const DECO_MIN_Y:        float = DECO_MIN_METERS * PIXELS_PER_METER
const DECO_MAX_Y:        float = DECO_MAX_METERS * PIXELS_PER_METER
const DECO_SPAWN_CHANCE: float = 0.40

const CLOUD_SURFACE_OFFSET:   float = 20.0
const TREE_HEIGHT_OFFSET:     float = 55.0
const MUSHROOM_HEIGHT_OFFSET: float = 15.0

# ── Rock settings ─────────────────────────────────────────────────────────
const ROCK_LIFETIME:        float = 2.5
const ROCK_WARN_TIME:       float = 0.5
const ROCK_FALL_DURATION:   float = 1.5
const ROCK_MUSHROOM_CHANCE: float = 0.3
const DESPAWN_MARGIN:       float = 700.0

@export var rock_top_offset:    float = 20.0
@export var player_feet_offset: float = 32.0
@export var rock_half_width:    float = 60.0
@export var vertical_tolerance: float = 40.0

signal rock_fell(world_position: Vector2)

var _cam:    Camera2D        = null
var _world:  Node2D          = null
var _player: CharacterBody2D = null
var _rng:    RandomNumberGenerator = RandomNumberGenerator.new()
var _bg_id:  int             = 0

var _spawned_deco:   Array      = []
var _cloud_has_deco: Dictionary = {}
var _next_deco_y:    float      = 0.0
var _active_rocks:   Array      = []

var _tree_path:     String = ""
var _mushroom_path: String = ""
var _rock_path:     String = ""

var _deco_flip_counter: int  = 0
var _deco_current_flip: bool = false
var _rock_flip_counter: int  = 0
var _rock_current_flip: bool = false

var _player_was_on_floor: bool = false

# ─────────────────────────────────────────────────────────────────────────────

func setup(cam: Camera2D, world: Node2D, player: CharacterBody2D, start_y: float) -> void:
	_cam         = cam
	_world       = world
	_player      = player
	_next_deco_y = start_y
	_rng.randomize()
	_resolve_bg_paths()

func _resolve_bg_paths() -> void:
	_bg_id = GameState.selected_background
	match _bg_id:
		0:
			_tree_path     = NIGHT_TREE
			_mushroom_path = NIGHT_MUSHROOM
			_rock_path     = NIGHT_ROCK
		1:
			_tree_path     = SUNSET_TREE
			_mushroom_path = SUNSET_MUSHROOM
			_rock_path     = SUNSET_ROCK
		2:
			_tree_path     = OCEAN_TREE
			_mushroom_path = OCEAN_MUSHROOM
			_rock_path     = OCEAN_ROCK
		_:
			_tree_path     = NIGHT_TREE
			_mushroom_path = NIGHT_MUSHROOM
			_rock_path     = NIGHT_ROCK

func _next_deco_flip() -> bool:
	if _deco_flip_counter >= 2:
		_deco_current_flip  = not _deco_current_flip
		_deco_flip_counter  = 1
	else:
		if _rng.randf() < 0.30:
			_deco_current_flip = not _deco_current_flip
			_deco_flip_counter = 1
		else:
			_deco_flip_counter += 1
	return _deco_current_flip

func _next_rock_flip() -> bool:
	if _rock_flip_counter >= 2:
		_rock_current_flip  = not _rock_current_flip
		_rock_flip_counter  = 1
	else:
		if _rng.randf() < 0.30:
			_rock_current_flip = not _rock_current_flip
			_rock_flip_counter = 1
		else:
			_rock_flip_counter += 1
	return _rock_current_flip

# ─────────────────────────────────────────────────────────────────────────────

func on_cloud_spawned(local_pos: Vector2, platform: Node2D) -> void:
	if local_pos.y < _next_deco_y:
		if _rng.randf() < DECO_SPAWN_CHANCE:
			_try_place_tree_on_cloud(local_pos, platform)
		var gap_px: float = _rng.randf_range(DECO_MIN_Y, DECO_MAX_Y)
		_next_deco_y = local_pos.y - gap_px

func on_rock_gap(top_local_pos: Vector2, bottom_local_pos: Vector2) -> void:
	_spawn_rock_bridge(top_local_pos, bottom_local_pos)

func tick(bottom_y: float, delta: float) -> void:
	if not is_instance_valid(_cam) or not is_instance_valid(_world):
		return
	_update_deco_positions()
	_cleanup_deco(bottom_y)
	_update_rocks(delta)

# ─────────────────────────────────────────────────────────────────────────────

func _try_place_tree_on_cloud(cloud_local_pos: Vector2, platform: Node2D) -> void:
	var key: int = int(round(cloud_local_pos.y))
	if _cloud_has_deco.has(key):
		return
	_place_tree(cloud_local_pos, platform)
	_cloud_has_deco[key] = true

func _place_tree(cloud_local_pos: Vector2, platform: Node2D) -> void:
	if not ResourceLoader.exists(_tree_path):
		return
	var node: Node2D = UIFactory.cached_load(_tree_path).instantiate()
	_world.add_child(node)
	node.z_index       = 1
	node.z_as_relative = false
	node.process_mode  = Node.PROCESS_MODE_ALWAYS
	_apply_flip_controlled(node, _next_deco_flip())
	var offset := Vector2(
		_rng.randf_range(-20.0, 20.0),
		-CLOUD_SURFACE_OFFSET - TREE_HEIGHT_OFFSET
	)
	node.global_position = platform.global_position + offset
	var key: int = int(round(cloud_local_pos.y))
	_spawned_deco.append({
		"node":     node,
		"platform": platform,
		"offset":   offset,
		"cloud_y":  key
	})

func _apply_flip_controlled(node: Node2D, do_flip: bool) -> void:
	for child in node.get_children():
		if child is AnimatedSprite2D:
			(child as AnimatedSprite2D).flip_h = do_flip
			return
		elif child is Sprite2D:
			(child as Sprite2D).flip_h = do_flip
			return
	for child in node.get_children():
		for grandchild in child.get_children():
			if grandchild is AnimatedSprite2D:
				(grandchild as AnimatedSprite2D).flip_h = do_flip
				return
			elif grandchild is Sprite2D:
				(grandchild as Sprite2D).flip_h = do_flip
				return
	if node is AnimatedSprite2D:
		(node as AnimatedSprite2D).flip_h = do_flip
	elif node is Sprite2D:
		(node as Sprite2D).flip_h = do_flip

# ─────────────────────────────────────────────────────────────────────────────

func _update_deco_positions() -> void:
	var on_floor:    bool = is_instance_valid(_player) and _player.is_on_floor()
	var just_landed: bool = on_floor and not _player_was_on_floor
	_player_was_on_floor = on_floor

	for entry in _spawned_deco:
		var raw = entry.get("node")
		if not is_instance_valid(raw):
			continue
		var plat = entry.get("platform")
		if not is_instance_valid(plat):
			continue
		var node: Node2D = raw as Node2D
		if node == null:
			continue

		if plat.has_meta("is_moving") and plat.get_meta("is_moving"):
			node.global_position = plat.global_position + entry["offset"]

		if just_landed:
			var dx: float = absf(_player.global_position.x - plat.global_position.x)
			var dy: float = absf(_player.global_position.y - plat.global_position.y)
			if dx < 120.0 and dy < 80.0:
				# Right side = player.x >= platform.x = no flip
				# Left side  = player.x <  platform.x = flip
				var landed_right: bool = _player.global_position.x >= plat.global_position.x
				_play_deco_anim(node, landed_right)

func _play_deco_anim(node: Node2D, landed_right: bool) -> void:
	# landed_right = true  → player came from right → normal orientation
	# landed_right = false → player came from left  → flip animation
	var do_flip: bool = not landed_right
	_apply_flip_controlled(node, do_flip)

	if node is AnimatedSprite2D:
		var s := node as AnimatedSprite2D
		if s.sprite_frames != null and s.sprite_frames.get_animation_names().size() > 0:
			s.stop()
			s.play(s.sprite_frames.get_animation_names()[0])
		return
	for child in node.get_children():
		if child is AnimatedSprite2D:
			var s := child as AnimatedSprite2D
			if s.sprite_frames != null and s.sprite_frames.get_animation_names().size() > 0:
				s.stop()
				s.play(s.sprite_frames.get_animation_names()[0])
			return

# ─────────────────────────────────────────────────────────────────────────────

func _spawn_rock_bridge(top_pos: Vector2, bottom_pos: Vector2) -> void:
	var dy: float = absf(bottom_pos.y - top_pos.y)
	if dy < 10.0:
		return

	var rock_local_pos := Vector2(
		lerpf(top_pos.x, bottom_pos.x, 0.5) + _rng.randf_range(-20.0, 20.0),
		lerpf(top_pos.y, bottom_pos.y, 0.5)
	)

	if not ResourceLoader.exists(_rock_path):
		return

	var rock: Node2D = UIFactory.cached_load(_rock_path).instantiate()
	_world.add_child(rock)
	rock.position     = rock_local_pos
	rock.z_index      = 0
	rock.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_flip_controlled(rock, _next_rock_flip())

	var mush_node: Node2D = null
	if _rng.randf() < ROCK_MUSHROOM_CHANCE:
		mush_node = _attach_mushroom_to_rock(rock)

	_active_rocks.append({
		"node":           rock,
		"timer":          ROCK_LIFETIME,
		"activated":      false,
		"mush":           mush_node,
		"spawn_position": _world.to_global(rock_local_pos)
	})

func _attach_mushroom_to_rock(rock: Node2D) -> Node2D:
	if not ResourceLoader.exists(_mushroom_path):
		return null
	var mush: Node2D = UIFactory.cached_load(_mushroom_path).instantiate()
	rock.add_child(mush)
	mush.scale = Vector2(1.0, 1.0)
	_apply_flip_controlled(mush, _next_deco_flip())
	mush.position = Vector2(0.0, -MUSHROOM_HEIGHT_OFFSET)
	return mush

# ─────────────────────────────────────────────────────────────────────────────

func _update_rocks(dt: float) -> void:
	var cam_bottom: float = _cam.global_position.y + \
		get_viewport().get_visible_rect().size.y * 0.5 + DESPAWN_MARGIN

	for i in range(_active_rocks.size() - 1, -1, -1):
		var data: Dictionary = _active_rocks[i]

		var raw = data.get("node")
		if not is_instance_valid(raw):
			_active_rocks.remove_at(i)
			continue

		var rock: Node2D = raw as Node2D
		if rock == null:
			_active_rocks.remove_at(i)
			continue

		if rock.global_position.y > cam_bottom:
			rock.queue_free()
			_active_rocks.remove_at(i)
			continue

		if not data["activated"]:
			if _is_player_on_top_of_rock(rock):
				data["activated"] = true
				var orig_x: float = rock.position.x
				var shake  := get_tree().create_tween()
				shake.tween_property(rock, "position:x", orig_x + 3.0, 0.05)
				shake.tween_property(rock, "position:x", orig_x - 3.0, 0.05)
				shake.tween_property(rock, "position:x", orig_x + 2.0, 0.04)
				shake.tween_property(rock, "position:x", orig_x - 2.0, 0.04)
				shake.tween_property(rock, "position:x", orig_x,       0.03)
		else:
			data["timer"] -= dt
			if data["timer"] <= ROCK_WARN_TIME:
				var alpha: float = data["timer"] / ROCK_WARN_TIME
				rock.modulate = Color(1.0, 0.4, 0.4, alpha)
			if data["timer"] <= 0.0:
				rock_fell.emit(data["spawn_position"])
				_begin_fall(rock)
				_active_rocks.remove_at(i)

func _is_player_on_top_of_rock(rock: Node2D) -> bool:
	if not is_instance_valid(_player):
		return false
	if not _player.is_on_floor():
		return false
	if _player.velocity.y < -50.0:
		return false
	var rock_top_y:    float = rock.global_position.y - rock_top_offset
	var player_feet_y: float = _player.global_position.y + player_feet_offset
	if absf(player_feet_y - rock_top_y) > vertical_tolerance:
		return false
	if absf(_player.global_position.x - rock.global_position.x) > rock_half_width:
		return false
	return true

func _begin_fall(rock: Node2D) -> void:
	if not is_instance_valid(rock):
		return
	for child in rock.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			child.set_deferred("monitoring", false)
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(rock, "position:y", rock.position.y + 900.0, ROCK_FALL_DURATION)
	tween.tween_property(rock, "modulate:a", 0.0, ROCK_FALL_DURATION * 0.7)
	tween.chain().tween_callback(rock.queue_free)

# ─────────────────────────────────────────────────────────────────────────────

func _cleanup_deco(bottom_y: float) -> void:
	for i in range(_spawned_deco.size() - 1, -1, -1):
		var entry: Dictionary = _spawned_deco[i]

		var raw = entry.get("node")
		if not is_instance_valid(raw):
			_spawned_deco.remove_at(i)
			_cloud_has_deco.erase(entry["cloud_y"])
			continue

		var node: Node2D = raw as Node2D
		if node == null:
			_spawned_deco.remove_at(i)
			_cloud_has_deco.erase(entry["cloud_y"])
			continue

		var plat = entry.get("platform")
		if not is_instance_valid(plat):
			node.queue_free()
			_spawned_deco.remove_at(i)
			_cloud_has_deco.erase(entry["cloud_y"])
			continue

		if node.global_position.y > bottom_y + DESPAWN_MARGIN:
			_cloud_has_deco.erase(entry["cloud_y"])
			node.queue_free()
			_spawned_deco.remove_at(i)
