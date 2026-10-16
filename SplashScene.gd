extends Node2D

const NEXT_SCENE: String = "res://scenes/MainMenu.tscn"
const SPLASH_TIME: float = 3.0
const FADE_TIME: float = 0.5
const SPLASH_IMAGE: String = "res://assets/ui/splash.webp"
const FOCUS_OFFSET: Vector2 = Vector2(0, -80)

var sprite: Sprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0

	sprite = Sprite2D.new()
	if ResourceLoader.exists(SPLASH_IMAGE):
		sprite.texture = UIFactory.cached_load(SPLASH_IMAGE)
	add_child(sprite)

	modulate = Color(1, 1, 1, 0)

	get_viewport().size_changed.connect(_fit_sprite)
	call_deferred("_fit_sprite")

	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	await fade_in.finished

	await get_tree().create_timer(SPLASH_TIME).timeout

	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await fade_out.finished

	UIFactory.change_scene(get_tree(), NEXT_SCENE)

func _fit_sprite() -> void:
	if not is_instance_valid(sprite):
		return
	if sprite.texture == null:
		return

	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var tex_size: Vector2 = sprite.texture.get_size()

	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var scale_factor: float = max(screen_size.x / tex_size.x, screen_size.y / tex_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.position = screen_size * 0.5 + FOCUS_OFFSET
