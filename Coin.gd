extends Area2D

signal collected

var _bob_speed: float = 2.0
var _bob_amp: float = 5.0
var _base_y: float = 0.0
var _collected: bool = false
var _anim: AnimatedSprite2D = null
var _sound: AudioStreamPlayer2D = null
var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	var ref_width: float = 320.0
	var current_width: float = get_viewport().get_visible_rect().size.x
	var s: float = current_width / ref_width
	scale = Vector2(s, s)
	_base_scale = scale

	_base_y = position.y
	monitoring = true
	monitorable = true
	collision_layer = 8
	collision_mask = 1
	if has_node("AnimatedSprite2D"):
		_anim = $AnimatedSprite2D
		_anim.play("spin")
	if has_node("CollectSound"):
		_sound = $CollectSound
		_sound.bus = "SFX"
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func connect_collected(callable: Callable) -> void:
	if not collected.is_connected(callable):
		collected.connect(callable)

func _physics_process(_delta: float) -> void:
	if _collected:
		return
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			collect()
			return

func _process(_delta: float) -> void:
	if _collected:
		return
	var t: float = float(Time.get_ticks_msec()) * 0.001
	position.y = _base_y + sin(t * _bob_speed) * _bob_amp

func collect() -> void:
	if _collected:
		return
	_collected = true
	emit_signal("collected")
	if is_instance_valid(_sound):
		_sound.play()
		await _sound.finished
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * 1.6, 0.08)
	tween.tween_property(self, "scale", Vector2(0.0, 0.0), 0.12)
	tween.tween_callback(queue_free)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		collect()
