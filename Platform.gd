extends AnimatableBody2D

enum PlatformKind { NORMAL, MOVE_H, MOVE_V }

@export var kind: PlatformKind = PlatformKind.NORMAL
@export var color: Color = Color(0.247059, 0.776471, 0.352941, 1.0)
@export var move_amplitude: float = 110.0
@export var move_speed: float = 1.4

@onready var _rect: ColorRect = $ColorRect
var _sprite: Sprite2D = null

var _base_pos: Vector2 = Vector2.ZERO
var _phase: float = 0.0
var _prev_pos: Vector2 = Vector2.ZERO

func on_spawned_at(local_pos: Vector2) -> void:
	position = local_pos
	_base_pos = local_pos
	_prev_pos = local_pos
	# Reset kind so stale movement doesn't run for one frame before configure()
	kind = PlatformKind.NORMAL

func configure(p_kind: int, p_color: Color, p_amp: float, p_speed: float, p_phase: float, p_vertical: bool = false) -> void:
	color = p_color
	move_amplitude = p_amp
	move_speed = p_speed
	_phase = -float(Time.get_ticks_msec()) * 0.001 * move_speed + p_phase

	if p_kind == 1:
		kind = PlatformKind.MOVE_V if p_vertical else PlatformKind.MOVE_H
	else:
		kind = PlatformKind.NORMAL

	# Sync prev_pos so no frame-1 teleport after recycling
	_prev_pos = position
	_apply_visual()

func _ready() -> void:
	sync_to_physics = false
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, false)
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.one_way_collision = true
			child.one_way_collision_margin = 4.0
	_base_pos = position
	_prev_pos = position
	_phase = randf() * TAU
	_apply_visual()

func _physics_process(_delta: float) -> void:
	# Static platforms don't need any movement computation
	if kind == PlatformKind.NORMAL:
		return

	var target := _base_pos
	match kind:
		PlatformKind.MOVE_H:
			var t := float(Time.get_ticks_msec()) * 0.001
			target.x = _base_pos.x + sin(t * move_speed + _phase) * move_amplitude
		PlatformKind.MOVE_V:
			var t := float(Time.get_ticks_msec()) * 0.001
			target.y = _base_pos.y + sin(t * move_speed + _phase) * move_amplitude

	var motion := target - _prev_pos
	move_and_collide(motion)
	_prev_pos = position

func _apply_visual() -> void:
	if is_instance_valid(_sprite):
		_sprite.modulate = color
	elif is_instance_valid(_rect):
		_rect.color = color
