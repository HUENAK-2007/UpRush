extends Area2D

@export var speed := 520.0
@export var lifetime := 1.6
var _direction := Vector2.RIGHT
var _hit: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

const RUNE_SPELL_FRAMES: Dictionary = {
	0: "res://assets/Sprites/Spell/fire.tres",
	1: "res://assets/Sprites/Spell/wind.tres",
	2: "res://assets/Sprites/Spell/soul.tres",
	3: "res://assets/Sprites/Spell/blood.tres",
	4: "res://assets/Sprites/Spell/earth.tres",
}

func setup(dir: Vector2) -> void:
	_direction = dir.normalized()
	rotation = _direction.angle()

	var char_index: int = GameState.selected_character
	var char_rune: int = -1
	if char_index >= 0 and char_index < GameState.character_circle_rune.size():
		char_rune = GameState.character_circle_rune[char_index]

	if char_rune >= 0 and RUNE_SPELL_FRAMES.has(char_rune):
		var frames_path: String = RUNE_SPELL_FRAMES[char_rune]
		if ResourceLoader.exists(frames_path):
			var frames: SpriteFrames = UIFactory.cached_load(frames_path)
			if frames != null:
				_sprite.sprite_frames = frames
				if frames.has_animation("default"):
					_sprite.play("default")
				elif frames.get_animation_names().size() > 0:
					_sprite.play(frames.get_animation_names()[0])

	var rune_color: Color = GameState.get_circle_rune_color(char_index)
	var bright_color: Color = rune_color.lerp(Color.WHITE, 0.4)
	bright_color.v = 1.0
	if is_instance_valid(_sprite):
		_sprite.modulate = bright_color

	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self) and not _hit:
		queue_free()

func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	monitoring = true
	monitorable = true
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	if _sprite != null and _sprite.sprite_frames != null:
		var anim_name: String = _sprite.sprite_frames.get_animation_names()[0]
		var tex: Texture2D = _sprite.sprite_frames.get_frame_texture(anim_name, 0)
		if tex != null:
			var tex_size: Vector2 = tex.get_size() * _sprite.scale
			shape.radius = min(tex_size.x, tex_size.y) * 0.3
		else:
			shape.radius = 12.0
	else:
		shape.radius = 12.0
	col.shape = shape
	add_child(col)
	connect("area_entered", Callable(self, "_on_area_entered"))

func _physics_process(delta: float) -> void:
	if _hit:
		return
	position += _direction * speed * delta
	var rect := get_viewport().get_visible_rect()
	var half_w := rect.size.x * 0.5
	if abs(global_position.x) > half_w + 50.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _hit:
		return
	if area.has_method("die"):
		_hit = true
		set_deferred("monitoring", false)
		var bird_pos: Vector2 = area.global_position
		area.queue_free()
		SoundManager.play_bolt_bird_hit()
		get_tree().call_group("main", "spawn_rune_drop", bird_pos)
		_play_hit_effect()

func _play_hit_effect() -> void:
	var original_scale := scale
	var tween := create_tween()
	tween.tween_property(self, "scale", original_scale * 3.0, 0.15)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free)
