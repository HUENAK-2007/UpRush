class_name PowerUpManager
extends RefCounted

const BOOST_MAX:            int    = 2
const BOOST_METER_INTERVAL: float  = 200.0
const BOOST_BUTTON_TEXTURE: String = "res://assets/Sprites/power_up.webp"
const ROCK_CHECK_DURATION:  float  = 3.0
const RESHOW_DURATION:      float  = 4.0

var _boost_charges:         int   = 0
var _last_boost_earn_score: float = 0.0
var _boost_button:          TextureButton = null
var _boost_pulse_tween:     Tween = null
var _boost_button_visible:  bool  = false
var _boost_icon_1:          TextureRect = null
var _boost_icon_2:          TextureRect = null

var _pending_rocks:      Array = []
var _gap_zones:          Array = []

var _boost_used_y:       float = 0.0
var _checking_reshow:    bool  = false
var _reshow_timer:       float = 0.0
var _boost_was_airborne: bool  = false

var _hud:          Node            = null
var _ui:           Node            = null
var _player:       CharacterBody2D = null
var _hearts_label: Label           = null
var _scene_tree:   SceneTree       = null

# ─────────────────────────────────────────────────────────────────────────────

func setup(hud: Node, ui: Node, player: CharacterBody2D, hearts_label: Label, tree: SceneTree) -> void:
	_hud          = hud
	_ui           = ui
	_player       = player
	_hearts_label = hearts_label
	_scene_tree   = tree
	_build_boost_button()

func setup_icons() -> void:
	pass

func set_boost_icons(icon_1: TextureRect, icon_2: TextureRect) -> void:
	_boost_icon_1 = icon_1
	_boost_icon_2 = icon_2
	_update_boost_icons()

func get_charges() -> int:
	return _boost_charges

# ── HUD icons ─────────────────────────────────────────────────────────────

func _update_boost_icons() -> void:
	if not is_instance_valid(_boost_icon_1) or not is_instance_valid(_boost_icon_2):
		return
	_boost_icon_1.modulate = Color(1, 1, 1, 1) if _boost_charges >= 1 else Color(0.3, 0.3, 0.3, 0.5)
	_boost_icon_2.modulate = Color(1, 1, 1, 1) if _boost_charges >= 2 else Color(0.3, 0.3, 0.3, 0.5)

# ── Popup button ──────────────────────────────────────────────────────────

func _build_boost_button() -> void:
	if not ResourceLoader.exists(BOOST_BUTTON_TEXTURE):
		push_warning("PowerUpManager: texture not found at " + BOOST_BUTTON_TEXTURE)
		return

	_boost_button = TextureButton.new()
	_boost_button.texture_normal         = UIFactory.cached_load(BOOST_BUTTON_TEXTURE)
	_boost_button.ignore_texture_size    = true
	_boost_button.stretch_mode           = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_boost_button.custom_minimum_size    = Vector2(120, 120)
	_boost_button.size                   = Vector2(120, 120)
	_boost_button.process_mode           = Node.PROCESS_MODE_ALWAYS
	_boost_button.mouse_filter           = Control.MOUSE_FILTER_STOP
	_boost_button.visible                = false
	_boost_button.z_index                = 100

	var screen := _ui.get_viewport().get_visible_rect().size
	_boost_button.position = Vector2(
		screen.x * 0.5 - 60.0,
		screen.y - 240.0
	)

	_boost_button.pressed.connect(_on_boost_pressed)
	_ui.add_child(_boost_button)

func show_boost_button() -> void:
	if not is_instance_valid(_boost_button):
		return
	if _boost_charges <= 0:
		return
	if _boost_button_visible:
		return

	_boost_button.visible = true
	_boost_button_visible = true

	if _boost_pulse_tween:
		_boost_pulse_tween.kill()
	_boost_pulse_tween = _scene_tree.create_tween()
	_boost_pulse_tween.set_loops()
	_boost_pulse_tween.tween_property(_boost_button, "modulate",
		Color(1.5, 1.5, 0.4, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)
	_boost_pulse_tween.tween_property(_boost_button, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)

func hide_boost_button() -> void:
	if not is_instance_valid(_boost_button):
		return
	if _boost_pulse_tween:
		_boost_pulse_tween.kill()
		_boost_pulse_tween = null
	_boost_button.modulate = Color(1, 1, 1, 1)
	_boost_button.visible  = false
	_boost_button_visible  = false

func _on_boost_pressed() -> void:
	if _boost_charges <= 0:
		hide_boost_button()
		return
	_boost_charges -= 1
	_update_boost_icons()
	hide_boost_button()
	if is_instance_valid(_player):
		_boost_used_y        = _player.global_position.y
		_checking_reshow     = true
		_reshow_timer        = RESHOW_DURATION
		_boost_was_airborne  = false
		_player.activate_boost()

# ── Rock fell ─────────────────────────────────────────────────────────────

func on_rock_fell(rock_spawn_pos: Vector2) -> void:
	_pending_rocks.append({
		"spawn_y":   rock_spawn_pos.y,
		"timer":     ROCK_CHECK_DURATION,
		"triggered": false
	})

func _tick_pending_rocks(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var player_y: float = _player.global_position.y
	for i in range(_pending_rocks.size() - 1, -1, -1):
		var entry: Dictionary = _pending_rocks[i]
		if entry["triggered"]:
			_pending_rocks.remove_at(i)
			continue
		entry["timer"] -= delta
		if entry["timer"] <= 0.0:
			_pending_rocks.remove_at(i)
			continue
		if player_y > entry["spawn_y"]:
			entry["triggered"] = true
			show_boost_button()
			_pending_rocks.remove_at(i)

# ── Gap zone detection — for gaps with no rock ────────────────────────────

func on_rock_gap_spawned(top_local: Vector2, bottom_local: Vector2) -> void:
	var upper_y: float = minf(top_local.y, bottom_local.y)
	var lower_y: float = maxf(top_local.y, bottom_local.y)
	_gap_zones.append({
		"upper_y":   upper_y,
		"lower_y":   lower_y,
		"triggered": false,
		"passed":    false
	})
	if _gap_zones.size() > 12:
		_gap_zones.pop_front()

func tick_gap_detection() -> void:
	if not is_instance_valid(_player):
		return
	var player_y: float = _player.global_position.y
	var on_floor: bool  = _player.is_on_floor()

	for i in range(_gap_zones.size() - 1, -1, -1):
		var zone: Dictionary = _gap_zones[i]
		if zone["triggered"] or zone["passed"]:
			continue

		# Player crossed above upper platform — passed it successfully
		if player_y < zone["upper_y"] - 80.0:
			zone["passed"] = true
			continue

		# Player on floor on lower platform below the gap midpoint
		var gap_mid: float = (zone["upper_y"] + zone["lower_y"]) * 0.5
		if on_floor and player_y > gap_mid and absf(player_y - zone["lower_y"]) < 180.0:
			zone["triggered"] = true
			if _boost_charges > 0:
				show_boost_button()

# ── Reshow after failed boost ─────────────────────────────────────────────

func _tick_reshow(delta: float) -> void:
	if not _checking_reshow:
		return
	if not is_instance_valid(_player):
		_checking_reshow = false
		return

	_reshow_timer -= delta
	if _reshow_timer <= 0.0:
		_checking_reshow = false
		return

	var on_floor: bool = _player.is_on_floor()

	if not _boost_was_airborne and not on_floor:
		_boost_was_airborne = true

	if _boost_was_airborne and on_floor:
		_checking_reshow = false
		if _player.global_position.y >= _boost_used_y - 50.0:
			if _boost_charges > 0:
				show_boost_button()

# ── Tick ──────────────────────────────────────────────────────────────────

func tick(delta: float, max_climbed: float, score_scale: float) -> void:
	var score_m:       float = max_climbed / score_scale
	var intervals_now: int   = int(score_m / BOOST_METER_INTERVAL)
	var intervals_old: int   = int(_last_boost_earn_score / BOOST_METER_INTERVAL)
	if intervals_now > intervals_old:
		var prev: int  = _boost_charges
		_boost_charges = mini(_boost_charges + (intervals_now - intervals_old), BOOST_MAX)
		if _boost_charges != prev:
			_update_boost_icons()
	_last_boost_earn_score = score_m

	_tick_pending_rocks(delta)
	_tick_reshow(delta)
