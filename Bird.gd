extends Area2D

var _speed: float = 150.0
var _direction: float = 1.0
var _dead: bool = false
var _anim_sprite: AnimatedSprite2D = null
var _tried_flap: bool = false

func setup(speed: float, direction: float) -> void:
	_speed = speed
	_direction = direction
	_apply_flip()

func set_animated_sprite(sprite: AnimatedSprite2D) -> void:
	_anim_sprite = sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_play_animation("fly")
	_apply_flip()
	SoundManager.play_bird_flap()
	_tried_flap = true

func _physics_process(delta: float) -> void:
	if _dead:
		return
	position.x += _speed * _direction * delta
	if SoundManager.can_play_flap():
		SoundManager.play_bird_flap()

func die() -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_play_animation("die")
	if _anim_sprite != null:
		await _anim_sprite.animation_finished
	queue_free()

func _apply_flip() -> void:
	if _anim_sprite == null:
		return
	_anim_sprite.flip_h = (_direction > 0.0)

func _play_animation(anim_name: String) -> void:
	if _anim_sprite == null:
		return
	if _anim_sprite.sprite_frames == null:
		return
	if _anim_sprite.sprite_frames.has_animation(anim_name):
		_anim_sprite.play(anim_name)
	elif anim_name == "fly" and _anim_sprite.sprite_frames.has_animation("default"):
		_anim_sprite.play("default")

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		get_tree().call_group("main", "on_bird_hit_player", self)
