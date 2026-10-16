extends Node2D

@onready var sky_object:    Sprite2D        = $BackgroundLayer/SkyObject
@onready var Background:    ColorRect       = $BackgroundLayer/Background
@export  var initial_platforms: int         = 14
@export  var double_tap_ms:     int         = 260
@onready var world:         Node2D          = $World
@onready var player:        CharacterBody2D = $World/Player
@onready var cam:           Camera2D        = $Camera2D
@onready var score_label:   Label           = $UI/HUD/ScoreLabel
@onready var left_btn:      Button          = $UI/HUD/Controls/LeftButton
@onready var right_btn:     Button          = $UI/HUD/Controls/RightButton
@onready var spawner:       Node            = $World/PlatformSpawner
@onready var hearts_label:  Label           = $UI/HUD/HeartsLabel
@onready var coin_label:    Label           = $UI/HUD/CoinLabel
@onready var pause_btn:     TextureButton   = $UI/HUD/PauseButton

const SCORE_SCALE: float  = 10.0
const MENU_SCENE:  String = "res://scenes/MainMenu.tscn"

var _bird_spawner:  Node = null
var _coin_spawner:  Node = null
var _deco_spawner:  Node = null

var _power_up_mgr:  PowerUpManager     = null
var _attack_mgr:    AttackManager      = null

var _ready_done:    bool  = false
var _start_y:       float = 0.0
var _total_climbed: float = 0.0
var _max_climbed:   float = 0.0
var _paused:        bool  = false
var _game_over:     bool  = false
var _session_coins: int   = 0
var _session_runes: int   = 0
var _height_unlock_done: bool = false

var _hud:           HUDManager        = null
var _pause_mgr:     PauseManager      = null
var _game_over_mgr: GameOverManager   = null
var _tutorial_mgr:  TutorialManager   = null
var _bg_mgr:        BackgroundManager = null
var _player_ctrl:   PlayerController  = null

@onready var _circle_scene:    PackedScene = preload("res://scenes/MagicCircle.tscn")
@onready var _ghost_scene:     PackedScene = preload("res://scenes/GhostCircle.tscn")
@onready var _rune_drop_scene: PackedScene = preload("res://scenes/RuneDrop.tscn")

var _can_attack:      bool  = true
var _attack_cooldown: float = 2.0

# ─────────────────────────────────────────────────────────────────────────────

func _start_fade_in() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 1)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.35)
	tw.tween_callback(layer.queue_free)

# Spell assets used by the attack. Loading these for the first time (or again
# after they were freed) while attacking made the whole game stall on slower
# phones, so they are loaded once, up front, and kept in memory.
const _SPELL_FRAMES: Dictionary = {
	0: "res://assets/Sprites/Spell/fire.tres",
	1: "res://assets/Sprites/Spell/wind.tres",
	2: "res://assets/Sprites/Spell/soul.tres",
	3: "res://assets/Sprites/Spell/blood.tres",
	4: "res://assets/Sprites/Spell/earth.tres",
}
const _CIRCLE_RUNE_SPRITES: Dictionary = {
	0: "res://assets/Sprites/Runes/fire-Photoroom.webp",
	1: "res://assets/Sprites/Runes/wind-Photoroom.webp",
	2: "res://assets/Sprites/Runes/flower-Photoroom.webp",
	3: "res://assets/Sprites/Runes/water_drop-Photoroom.webp",
	4: "res://assets/Sprites/Runes/leaves-Photoroom.webp",
}

func _prewarm_attack_assets() -> void:
	var char_index: int = GameState.selected_character
	if char_index < 0 or char_index >= GameState.character_circle_rune.size():
		return
	var rune: int = GameState.character_circle_rune[char_index]
	if _SPELL_FRAMES.has(rune) and ResourceLoader.exists(_SPELL_FRAMES[rune]):
		UIFactory.cached_load(_SPELL_FRAMES[rune])
	if _CIRCLE_RUNE_SPRITES.has(rune) and ResourceLoader.exists(_CIRCLE_RUNE_SPRITES[rune]):
		UIFactory.cached_load(_CIRCLE_RUNE_SPRITES[rune])

func _ready() -> void:
	add_to_group("main")
	_prewarm_attack_assets()
	if GameState.scene_fade_in:
		GameState.scene_fade_in = false
		_start_fade_in()

	_player_ctrl = PlayerController.new()
	_player_ctrl.setup(player, double_tap_ms)
	_player_ctrl.died.connect(_on_player_died)
	_player_ctrl.respawned.connect(_on_player_respawned)
	_player_ctrl.game_over_triggered.connect(_on_game_over)

	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(_on_pause)

	_pause_mgr = PauseManager.new()
	_pause_mgr.setup(self, pause_btn)
	_pause_mgr.resumed.connect(_on_resume)
	_pause_mgr.main_menu_requested.connect(_on_main_menu)
	if not _pause_mgr.buttons_visibility_changed.is_connected(_on_buttons_visibility_changed):
		_pause_mgr.buttons_visibility_changed.connect(_on_buttons_visibility_changed)

	_game_over_mgr = GameOverManager.new()
	_game_over_mgr.setup(self)
	_game_over_mgr.play_again_requested.connect(_on_play_again)
	_game_over_mgr.main_menu_requested.connect(_on_main_menu)

	var bg_data: Dictionary = GameState.get_background()
	_bg_mgr = BackgroundManager.new()
	_bg_mgr.setup($BackgroundLayer, sky_object, bg_data)

	var heart_path: String = bg_data.get("heart_icon", UIFactory.HEART_ICON)
	var heart_tex:  Texture2D = null
	if ResourceLoader.exists(heart_path):
		heart_tex = UIFactory.cached_load(heart_path)
	elif ResourceLoader.exists(UIFactory.HEART_ICON):
		heart_tex = UIFactory.cached_load(UIFactory.HEART_ICON)

	_hud = HUDManager.new()
	_hud.setup($UI/HUD, score_label, hearts_label, coin_label, heart_tex)
	_setup_control_buttons()

	_attack_mgr = AttackManager.new()
	_attack_mgr.setup(player, _player_ctrl)
	_attack_mgr.attack_fired.connect(_on_attack_fired)

	_power_up_mgr = PowerUpManager.new()
	_power_up_mgr.setup($UI/HUD, $UI, player, hearts_label, get_tree())

	_tutorial_mgr = TutorialManager.new()
	_tutorial_mgr.setup(self, left_btn, right_btn)
	_tutorial_mgr.tutorial_finished.connect(_apply_post_tutorial_buttons)

	var start_platform_pos: Vector2 = $World/StartPlatform.position
	$World/StartPlatform.queue_free()
	await get_tree().process_frame

	spawner.setup(player)

	_deco_spawner = UIFactory.cached_load("res://scripts/DecorationSpawner.gd").new()
	world.add_child(_deco_spawner)
	if not spawner.cloud_spawned.is_connected(_deco_spawner.on_cloud_spawned):
		spawner.cloud_spawned.connect(_deco_spawner.on_cloud_spawned)
	if not spawner.rock_gap_spawned.is_connected(_deco_spawner.on_rock_gap):
		spawner.rock_gap_spawned.connect(_deco_spawner.on_rock_gap)
	if not _deco_spawner.rock_fell.is_connected(_power_up_mgr.on_rock_fell):
		_deco_spawner.rock_fell.connect(_power_up_mgr.on_rock_fell)
	if not spawner.rock_gap_spawned.is_connected(_power_up_mgr.on_rock_gap_spawned):
		spawner.rock_gap_spawned.connect(_power_up_mgr.on_rock_gap_spawned)

	spawner.reset_from_start(start_platform_pos, initial_platforms)

	_coin_spawner = UIFactory.cached_load("res://scripts/CoinSpawner.gd").new()
	world.add_child(_coin_spawner)

	_player_ctrl.place_on_platform(start_platform_pos)
	player.reset_motion()
	player.velocity = Vector2.ZERO

	await get_tree().process_frame
	await get_tree().process_frame

	_start_y = player.global_position.y
	_player_ctrl.highest_player_y = player.global_position.y
	_max_climbed = 0.0
	player.velocity = Vector2.ZERO

	_coin_spawner.setup(_start_y)
	_deco_spawner.setup(cam, world, player, _start_y)

	_bird_spawner = UIFactory.cached_load("res://scripts/BirdSpawner.gd").new()
	world.add_child(_bird_spawner)
	_bird_spawner.setup(cam)

	$UI.process_mode = Node.PROCESS_MODE_ALWAYS

	_attack_mgr.clear_touch_state()
	_player_ctrl._clear_input_state()

	call_deferred("_update_hearts")
	call_deferred("_update_coin_label")
	call_deferred("_update_rune_label")

	await get_tree().process_frame
	await get_tree().process_frame
	_build_boost_hud_icons()

	_bg_mgr.update_sky_position(get_viewport())
	_ready_done = true

	if not GameState.tutorial_shown:
		_tutorial_mgr.show_tutorial()
	else:
		_apply_post_tutorial_buttons()

# ─────────────────────────────────────────────────────────────────────────────

func _build_boost_hud_icons() -> void:
	if not ResourceLoader.exists("res://assets/Sprites/power_up.webp"):
		return

	var tex:       Texture2D = UIFactory.cached_load("res://assets/Sprites/power_up.webp")
	var icon_size: float     = 28.0 * UIFactory.UI_SCALE
	var hud:       Control   = $UI/HUD

	var font:    Font  = hearts_label.get_theme_font("font")
	var font_sz: int   = hearts_label.get_theme_font_size("font_size")
	var label_h: float = font.get_height(font_sz)

	var lx: float = hearts_label.position.x
	var ly: float = hearts_label.position.y + label_h + 4.0

	var icon_1 := TextureRect.new()
	icon_1.texture             = tex
	icon_1.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_1.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_1.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_1.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icon_1.position            = Vector2(lx, ly)
	icon_1.name                = "BoostIcon1"
	hud.add_child(icon_1)

	var icon_2 := TextureRect.new()
	icon_2.texture             = tex
	icon_2.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_2.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_2.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icon_2.position            = Vector2(lx + icon_size + 4.0, ly)
	icon_2.name                = "BoostIcon2"
	hud.add_child(icon_2)

	_power_up_mgr.set_boost_icons(icon_1, icon_2)

# ─────────────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _ready_done or _game_over:
		return
	if _tutorial_mgr != null and _tutorial_mgr.is_active:
		return
	if event is InputEventScreenTouch:
		_attack_mgr.on_touch(event, get_viewport().get_visible_rect().size)

func _process(_delta: float) -> void:
	if _tutorial_mgr.is_active:
		_tutorial_mgr.animate_arrows()

func _physics_process(delta: float) -> void:
	if not _ready_done:
		return
	if _tutorial_mgr.is_active:
		return

	_tick_decorations(delta)

	if _paused or _game_over:
		return

	_attack_mgr.tick(delta)
	_player_ctrl.update_grace(delta)

	if _player_ctrl.process_flash(delta):
		return
	if _player_ctrl.process_respawn(delta):
		return
	if _player_ctrl.dead:
		return

	_player_ctrl.update_axis(get_viewport())
	_player_ctrl.check_attack()
	_update_camera()
	_bg_mgr.update_sky_position(get_viewport())
	_update_score()
	_tick_spawner()
	_tick_birds(delta)
	_tick_coins()
	_power_up_mgr.tick(delta, _max_climbed, SCORE_SCALE)
	_power_up_mgr.tick_gap_detection()

	_check_death()

# ─────────────────────────────────────────────────────────────────────────────

func _on_attack_fired(_dir: int) -> void:
	_can_attack = false
	get_tree().create_timer(_attack_cooldown).timeout.connect(func():
		_can_attack = true
		_attack_mgr.set_can_attack(true)
	)
	_attack_mgr.set_can_attack(false)

func _setup_control_buttons() -> void:
	left_btn.text  = "LEFT"
	right_btn.text = "RIGHT"
	left_btn.flat  = false
	right_btn.flat = false
	left_btn.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	right_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for btn in [left_btn, right_btn]:
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		btn.focus_mode   = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", int(18 * UIFactory.UI_SCALE))

func _apply_post_tutorial_buttons() -> void:
	_apply_button_visibility(GameState.buttons_visible)

func _apply_button_visibility(visible: bool) -> void:
	if visible:
		left_btn.text  = "LEFT"
		right_btn.text = "RIGHT"
		left_btn.flat  = false
		right_btn.flat = false
	else:
		left_btn.text  = ""
		right_btn.text = ""
		left_btn.flat  = true
		right_btn.flat = true

func _on_buttons_visibility_changed(visible: bool) -> void:
	_apply_button_visibility(visible)

func _on_player_died(_bird_killed: bool) -> void:
	_update_hearts()
	_power_up_mgr.hide_boost_button()

func _on_player_respawned() -> void:
	_attack_mgr.clear_touch_state()
	if is_instance_valid(player) and player.is_inside_tree():
		player.suppress_turns = false
	_player_ctrl.do_respawn_placement(world, cam, get_viewport())

func _on_game_over() -> void:
	_game_over = true
	_power_up_mgr.hide_boost_button()
	SoundManager.stop_music()
	SoundManager.play_game_over()
	_save_best_score()
	_hud.update_score(str(int(_max_climbed / SCORE_SCALE)) + " m")
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self):
		_game_over_mgr.build_overlay(_max_climbed, SCORE_SCALE, _session_coins)

func _on_pause() -> void:
	if _game_over or _paused or _tutorial_mgr.is_active:
		return
	SoundManager.play_click()
	_paused = true
	get_tree().paused = true
	GameState.flush()
	_pause_mgr.set_pause_btn_icon(true)
	_pause_mgr.build_pause_overlay()

func _on_resume() -> void:
	SoundManager.play_click()
	_paused = false
	get_tree().paused = false
	_pause_mgr.destroy_overlay()
	_pause_mgr.set_pause_btn_icon(false)

func _on_play_again() -> void:
	SoundManager.play_click()
	GameState.scene_fade_in = true
	GameState.flush()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	_save_best_score()
	SoundManager.play_click()
	Engine.time_scale = 1.0
	get_tree().paused = false
	UIFactory.change_scene(get_tree(), MENU_SCENE)

func _save_best_score() -> void:
	var score: int = int(_max_climbed / SCORE_SCALE)
	if score > GameState.best_score:
		GameState.best_score = score
		GameState.mark_dirty()
	GameState.flush()

# ─────────────────────────────────────────────────────────────────────────────

func on_coin_collected() -> void:
	_session_coins += 1
	GameState.lifetime_coins += 1
	GameState.coins += 1
	GameState.mark_dirty()   # written on game over / pause / app background
	_update_coin_label()
	SoundManager.play_coin()

func on_rune_collected() -> void:
	_session_runes += 1
	GameState.mark_dirty()
	_update_rune_label()

func on_bird_hit_player(_bird: Node) -> void:
	if _player_ctrl.invincible:
		return
	SoundManager.play_hit_bird()
	_attack_mgr.clear_touch_state()
	if is_instance_valid(player) and player.is_inside_tree():
		player.suppress_turns = false
	_player_ctrl.trigger_death(true)

func spawn_rune_drop(pos: Vector2) -> void:
	var rune_type: int = GameState.roll_rune_drop(GameState.selected_background)
	var drop := _rune_drop_scene.instantiate()
	if drop.has_method("setup"):
		var rect    := get_viewport().get_visible_rect()
		# Margin = size of the icon itself, so the rune lands as close to the
		# bird as possible while still being fully on screen.
		var ext: float = 40.0
		var drift: float = 0.0
		if drop.has_method("get_half_extent"):
			ext = drop.get_half_extent(rune_type)
		if drop.has_method("get_drift"):
			drift = drop.get_drift()
		# World x is centred on the camera (0 = middle of the screen), so clamp
		# around the camera, not from the viewport's top-left corner.
		var half_w: float = rect.size.x * 0.5
		var clamped := Vector2(
			clampf(pos.x, cam.global_position.x - half_w + ext, cam.global_position.x + half_w - ext),
			clampf(pos.y,
				cam.global_position.y - rect.size.y * 0.5 + ext + drift,
				cam.global_position.y + rect.size.y * 0.5 - ext)
		)
		drop.setup(rune_type, clamped)
	world.add_child(drop)

func spawn_magic_circle(pos: Vector2, face_dir: int) -> void:
	if not _can_attack:
		return
	_can_attack = false
	get_tree().create_timer(_attack_cooldown).timeout.connect(func():
		_can_attack = true
		_attack_mgr.set_can_attack(true)
	)
	if not is_instance_valid(self):
		return

	var dir:    Vector2 = Vector2.RIGHT * face_dir
	var offset: float   = 90.0 if face_dir < 0 else 130.0
	var circle := _circle_scene.instantiate()
	world.add_child(circle)
	circle.global_position = pos + dir * offset
	if circle.has_method("setup"):
		circle.setup(dir)
	var ghost := _ghost_scene.instantiate()
	world.add_child(ghost)
	if ghost.has_method("setup"):
		ghost.setup(player, _attack_cooldown)

# ─────────────────────────────────────────────────────────────────────────────

func _update_camera() -> void:
	_player_ctrl.update_highest_y()
	cam.global_position.y = _player_ctrl.highest_player_y

func _update_score() -> void:
	_total_climbed = maxf(0.0, _start_y - player.global_position.y)
	_max_climbed   = maxf(_max_climbed, _total_climbed)
	_hud.update_score(str(int(_max_climbed / SCORE_SCALE)) + " m")
	_check_height_unlock()

func _check_height_unlock() -> void:
	if _height_unlock_done:
		return
	var char_idx: int = GameState.selected_character
	if char_idx < 0 or char_idx >= GameData.WORLDS.size():
		return
	var meters: int = int(_max_climbed / SCORE_SCALE)
	if meters < int(GameData.WORLDS[char_idx]["unlock_meter"]):
		return
	_height_unlock_done = true
	var newly_reached: bool = GameState.check_height_unlock(char_idx, meters)
	var next_idx: int = char_idx + 1
	if newly_reached and next_idx < GameData.CHARACTERS.size() \
			and not GameState.is_character_unlocked(next_idx):
		_show_unlock_message(next_idx)

# Small banner near the top of the screen: fades in, stays ~2 s, fades out.
func _show_unlock_message(next_idx: int) -> void:
	var char_name: String = GameData.CHARACTERS[next_idx]["name"]
	var screen: Vector2 = get_viewport().get_visible_rect().size

	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var lbl := Label.new()
	lbl.text = "%s can now be bought!" % char_name
	lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_left  = screen.x * 0.05
	lbl.offset_right = -screen.x * 0.05
	lbl.offset_top   = screen.y * 0.20
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", int(clampf(screen.x * 0.055, 22.0, 48.0)))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.modulate.a = 0.0
	layer.add_child(lbl)

	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)

func _update_hearts() -> void:
	_hud.update_hearts(_player_ctrl.lives)

func _update_coin_label() -> void:
	_hud.update_coin_label(_session_coins)

func _update_rune_label() -> void:
	_hud.update_rune_label(_session_runes)

func _tick_spawner() -> void:
	if spawner == null:
		return
	var rect     := get_viewport().get_visible_rect()
	var top_y    := cam.global_position.y - rect.size.y * 0.5
	var bottom_y := cam.global_position.y + rect.size.y * 0.5
	spawner.tick(top_y, bottom_y, _total_climbed)

func _tick_birds(delta: float) -> void:
	if _bird_spawner == null:
		return
	var rect     := get_viewport().get_visible_rect()
	var top_y    := cam.global_position.y - rect.size.y * 0.5
	var bottom_y := cam.global_position.y + rect.size.y * 0.5
	_bird_spawner.tick(delta, _total_climbed, top_y, bottom_y)

func _tick_coins() -> void:
	if _coin_spawner == null:
		return
	var rect     := get_viewport().get_visible_rect()
	var top_y    := cam.global_position.y - rect.size.y * 0.5
	var bottom_y := cam.global_position.y + rect.size.y * 0.5
	_coin_spawner.tick(player.global_position.y, top_y, bottom_y)

func _tick_decorations(delta: float) -> void:
	if _deco_spawner == null:
		return
	var rect  := get_viewport().get_visible_rect()
	var bot_y := cam.global_position.y + rect.size.y * 0.5
	_deco_spawner.tick(bot_y, delta)

func _check_death() -> void:
	if _player_ctrl.check_fell_off_screen(cam, get_viewport()):
		_player_ctrl.trigger_death(false)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _tutorial_mgr.is_active:
		_tutorial_mgr.dismiss()
		return
	if _game_over:
		return
	if _paused:
		_on_resume()
	else:
		_on_pause()
