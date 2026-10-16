extends Area2D

@export var bolt_scene: PackedScene = preload("res://scenes/SpellBolt.tscn")

const LIFETIME_AFTER_BOLT: float = 3.0
const INNER_WHITE_LERP: float = 0.85
const OUTER_WHITE_LERP: float = 0.4
const INNER_RADIUS: float = 0.15

@export var lifetime_after_bolt: float = LIFETIME_AFTER_BOLT

var _spawned := false
var _direction := Vector2.RIGHT
var _rune_sprite_original_x: float = 0.0
var _ready_done: bool = false

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _rune_sprite: Sprite2D = $RuneSprite

const RUNE_SPRITES: Dictionary = {
	0: "res://assets/Sprites/Runes/fire-Photoroom.webp",
	1: "res://assets/Sprites/Runes/wind-Photoroom.webp",
	2: "res://assets/Sprites/Runes/flower-Photoroom.webp",
	3: "res://assets/Sprites/Runes/water_drop-Photoroom.webp",
	4: "res://assets/Sprites/Runes/leaves-Photoroom.webp",
}

const GRADIENT_SHADER_CODE: String = """
shader_type canvas_item;
uniform vec4 inner_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 outer_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5, 0.5);
	float dist = length(centered) * 2.0;
	float t = smoothstep(inner_radius, 1.0, dist);
	vec4 grad = mix(inner_color, outer_color, t);
	COLOR = tex * grad;
}
"""

static var _cached_shader: Shader = null
static var _cached_rune_textures: Dictionary = {}

static func _get_shader() -> Shader:
	if _cached_shader == null:
		_cached_shader = Shader.new()
		_cached_shader.code = GRADIENT_SHADER_CODE
	return _cached_shader

static func _get_rune_texture(rune_type: int, sprites: Dictionary) -> Texture2D:
	if _cached_rune_textures.has(rune_type):
		return _cached_rune_textures[rune_type]
	var path: String = sprites.get(rune_type, "")
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = UIFactory.cached_load(path)
		_cached_rune_textures[rune_type] = tex
		return tex
	return null

func setup(dir: Vector2) -> void:
	_direction = dir.normalized()
	if _direction.x > 0:
		_anim.flip_h = true
		if is_instance_valid(_rune_sprite):
			_rune_sprite.position.x = -_rune_sprite_original_x
	else:
		_anim.flip_h = false
		if is_instance_valid(_rune_sprite):
			_rune_sprite.position.x = _rune_sprite_original_x

	# Fire bolt immediately now that direction is set
	_launch_bolt()

func _ready() -> void:
	if is_instance_valid(_rune_sprite):
		_rune_sprite_original_x = _rune_sprite.position.x

	collision_layer = 0
	collision_mask = 0

	var char_index: int = GameState.selected_character
	var rune_color: Color = GameState.get_circle_rune_color(char_index)

	var inner_color: Color = rune_color.lerp(Color.WHITE, INNER_WHITE_LERP)
	inner_color.v = 1.0

	var outer_color: Color = rune_color.lerp(Color.WHITE, OUTER_WHITE_LERP)
	outer_color.v = 1.0
	outer_color.s = minf(1.0, outer_color.s + 0.2)

	var mat := ShaderMaterial.new()
	mat.shader = _get_shader()
	mat.set_shader_parameter("inner_color", inner_color)
	mat.set_shader_parameter("outer_color", outer_color)
	mat.set_shader_parameter("inner_radius", INNER_RADIUS)
	_anim.material = mat

	if is_instance_valid(_rune_sprite):
		var char_rune: int = -1
		if char_index >= 0 and char_index < GameState.character_circle_rune.size():
			char_rune = GameState.character_circle_rune[char_index]
		if char_rune >= 0 and RUNE_SPRITES.has(char_rune):
			var tex: Texture2D = _get_rune_texture(char_rune, RUNE_SPRITES)
			if tex != null:
				_rune_sprite.texture = tex
		else:
			_rune_sprite.visible = false

	if _anim.sprite_frames and _anim.sprite_frames.has_animation("attack"):
		_anim.play("attack")

	await get_tree().create_timer(lifetime_after_bolt).timeout
	if is_instance_valid(self):
		queue_free()

func _launch_bolt() -> void:
	if _spawned:
		return
	_spawned = true
	if bolt_scene == null:
		return
	SoundManager.play_spell_fire()
	var bolt := bolt_scene.instantiate()
	get_parent().add_child(bolt)
	bolt.global_position = global_position + _direction * 48.0
	if bolt.has_method("setup"):
		bolt.setup(_direction)
