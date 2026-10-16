extends Area2D

const RUNE_SPRITES: Dictionary = {
	0: "res://assets/Sprites/Runes/fire-Photoroom.webp",
	1: "res://assets/Sprites/Runes/wind-Photoroom.webp",
	2: "res://assets/Sprites/Runes/flower-Photoroom.webp",
	3: "res://assets/Sprites/Runes/water_drop-Photoroom.webp",
	4: "res://assets/Sprites/Runes/leaves-Photoroom.webp",
}

const LIFETIME: float = 8.0
const FLOAT_SPEED: float = 1.5
const FLOAT_AMPLITUDE: float = 6.0
const DROP_SCALE: float = 0.16
const PICKUP_RADIUS: float = 35.0   # fallback only; normally sized to the icon
const PICKUP_TOUCH_FACTOR: float = 0.9  # fraction of the icon radius that counts as a touch
# After the player touches it, the rune stays visible this long (seconds)
const COLLECTED_DISPLAY_TIME: float = 1.5
const POP_SCALE: float = 1.35
const COLLECTED_DRIFT: float = 30.0

static var _cached_textures: Dictionary = {}

static func _get_texture(rune_type: int, sprites: Dictionary) -> Texture2D:
	if _cached_textures.has(rune_type):
		return _cached_textures[rune_type]
	var path: String = sprites.get(rune_type, "")
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cached_textures[rune_type] = tex
		return tex
	return null

var _rune_type: int = 0
var _elapsed: float = 0.0
var _start_y: float = 0.0
var _spawn_pos: Vector2 = Vector2.ZERO
var _collected: bool = false
var _scale_val: float = DROP_SCALE
var _sprite: Sprite2D = null
var _collected_elapsed: float = 0.0
var _cam_offset: Vector2 = Vector2.ZERO

# How far (px) from its centre the drop reaches, including the pickup pop,
# so Main can keep the whole icon on screen.
func get_half_extent(rune_type: int) -> float:
	var tex: Texture2D = _get_texture(rune_type, RUNE_SPRITES)
	if tex == null:
		return 40.0
	return maxf(float(tex.get_width()), float(tex.get_height())) * DROP_SCALE * 0.5 * POP_SCALE + FLOAT_AMPLITUDE + 4.0

func get_drift() -> float:
	return COLLECTED_DRIFT

func setup(rune_type: int, spawn_pos: Vector2) -> void:
	_rune_type = rune_type
	_scale_val = DROP_SCALE
	_spawn_pos = spawn_pos
	global_position = spawn_pos
	_start_y = spawn_pos.y

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	# Re-apply the spawn position now that we are inside the tree, so it is a
	# true world position even if the parent has its own offset.
	global_position = _spawn_pos
	_start_y = _spawn_pos.y

	var sprite := Sprite2D.new()
	var tex: Texture2D = _get_texture(_rune_type, RUNE_SPRITES)
	if tex != null:
		sprite.texture = tex
	sprite.scale = Vector2(_scale_val, _scale_val)
	_sprite = sprite
	add_child(sprite)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	# The player must actually touch the rune: collision size follows the icon.
	shape.radius = PICKUP_RADIUS
	if tex != null:
		shape.radius = maxf(float(tex.get_width()), float(tex.get_height())) \
					   * _scale_val * 0.5 * PICKUP_TOUCH_FACTOR
	col.shape = shape
	call_deferred("add_child", col)

	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(func():
		if is_instance_valid(self) and not _collected:
			queue_free()
	)

func _process(delta: float) -> void:
	if _collected:
		_process_collected(delta)
		return
	_elapsed += delta
	global_position.y = _start_y + sin(_elapsed * FLOAT_SPEED) * FLOAT_AMPLITUDE
	var remaining: float = LIFETIME - _elapsed
	if remaining < 2.0:
		modulate.a = maxf(0.0, remaining / 2.0)

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body is CharacterBody2D:
		_collected = true
		set_deferred("monitoring", false)
		GameState.add_rune(_rune_type, 1)
		get_tree().call_group("main", "on_rune_collected")
		# Stay on screen for COLLECTED_DISPLAY_TIME: remember where we are on
		# screen so the rune keeps up with the camera while the player climbs.
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam != null:
			_cam_offset = global_position - cam.global_position
		_collected_elapsed = 0.0
		modulate.a = 1.0

func _process_collected(delta: float) -> void:
	_collected_elapsed += delta
	var t: float = clampf(_collected_elapsed / COLLECTED_DISPLAY_TIME, 0.0, 1.0)
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		global_position = cam.global_position + _cam_offset + Vector2(0.0, -COLLECTED_DRIFT * t)
	if is_instance_valid(_sprite):
		# quick pop, then settle back
		var pop: float = 1.0 + (POP_SCALE - 1.0) * sin(clampf(t * 2.0, 0.0, 1.0) * PI)
		_sprite.scale = Vector2(_scale_val, _scale_val) * pop
	# fully visible, fades only in the last 0.3 s
	modulate.a = clampf((1.0 - t) / 0.2, 0.0, 1.0) if t > 0.8 else 1.0
	if _collected_elapsed >= COLLECTED_DISPLAY_TIME:
		queue_free()
