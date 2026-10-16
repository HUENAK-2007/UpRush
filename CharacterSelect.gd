extends Node2D

const MENU_SCENE: String = "res://scenes/MainMenu.tscn"

var _back_btn_tex: Texture2D            = preload("res://assets/ui/arrow_left.webp")
var _card_bg_tex: Texture2D             = preload("res://assets/ui/Character card.webp")
var _card_bg_goldengrey_tex: Texture2D  = preload("res://assets/ui/charachter card_goldengrey.webp")
var _card_bg_blackgolden_tex: Texture2D = preload("res://assets/ui/charachter card_blackgolden.webp")
var _bg_tex: Texture2D                  = preload("res://assets/ui/backgrounds/Select char_back.webp")
var _coin_icon_tex: Texture2D           = preload("res://assets/ui/icons/coin.webp")
var _rune_icon_tex: Texture2D           = preload("res://assets/Sprites/Runes/all.webp")
var _tab_normal_tex: Texture2D          = preload("res://assets/ui/Backgroundframes/tab (2).webp")
var _tab_active_tex: Texture2D          = preload("res://assets/ui/Backgroundframes/On_tab.webp")

var _current_tab: int = 0
var _selected: int    = -1

var _card_viewports: Dictionary = {}
var _hero_viewport: Dictionary  = {}

var _viewport_park: Node

var _tab_characters: Node
var _tab_stats: Node
var _tab_runes: Node

func _ready() -> void:
	_viewport_park      = Node.new()
	_viewport_park.name = "ViewportPark"
	add_child(_viewport_park)

	_tab_characters      = preload("res://scripts/TabCharacters.gd").new()
	_tab_stats           = preload("res://scripts/TabStats.gd").new()
	_tab_runes           = preload("res://scripts/TabRunes.gd").new()
	_tab_characters.host = self
	_tab_stats.host      = self
	_tab_runes.host      = self

	_init_viewports()

	get_viewport().size_changed.connect(_on_resize)
	_selected = GameState.selected_character
	_build_ui()

func _reclaim_all_viewports() -> void:
	for key in _card_viewports:
		var entry: Dictionary = _card_viewports[key]
		if not entry.has("svc"):
			continue
		var svc = entry.svc
		if not is_instance_valid(svc):
			continue
		var parent = svc.get_parent()
		if parent != null and parent != _viewport_park:
			parent.remove_child(svc)
			_viewport_park.add_child(svc)

	if _hero_viewport.has("svc"):
		var svc = _hero_viewport.svc
		if is_instance_valid(svc):
			var parent = svc.get_parent()
			if parent != null and parent != _viewport_park:
				parent.remove_child(svc)
				_viewport_park.add_child(svc)

func _init_viewports() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var sz          := _make_sizes(screen_size.x, screen_size.y)

	for key in _card_viewports:
		var entry: Dictionary = _card_viewports[key]
		if is_instance_valid(entry.svc):
			entry.svc.queue_free()
	_card_viewports.clear()

	if _hero_viewport.has("svc") and is_instance_valid(_hero_viewport.svc):
		_hero_viewport.svc.queue_free()
	_hero_viewport.clear()

	for i in range(GameState.CHARACTERS.size()):
		var char_data: Dictionary = GameState.CHARACTERS[i]
		var frames_path: String   = char_data.get("frames", "")
		if frames_path == "" or not ResourceLoader.exists(frames_path):
			continue

		var frames: SpriteFrames = UIFactory.cached_load(frames_path)
		var sprite_size: Vector2 = get_sprite_size_from_frames(frames)
		var fit_scale: float = minf(
			sz.preview_w / maxf(sprite_size.x, 1.0),
			sz.preview_h / maxf(sprite_size.y, 1.0)
		) * 0.85

		var svc := SubViewportContainer.new()
		svc.custom_minimum_size   = Vector2(sz.preview_w, sz.preview_h)
		svc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		svc.stretch               = false
		svc.mouse_filter          = Control.MOUSE_FILTER_IGNORE
		svc.clip_contents         = false

		var svp := SubViewport.new()
		svp.size                      = Vector2i(int(sz.preview_w), int(sz.preview_h))
		svp.transparent_bg            = true
		svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		svc.add_child(svp)

		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = frames
		anim.position      = Vector2(sz.preview_w * 0.5, sz.preview_h * 0.55)
		anim.scale         = Vector2(fit_scale, fit_scale)
		if frames.has_animation("idle"):
			anim.play("idle")
		svp.add_child(anim)

		_viewport_park.add_child(svc)
		_card_viewports[i] = { "svc": svc, "svp": svp, "anim": anim }

	_rebuild_hero_viewport(sz, GameState.selected_character)

func _rebuild_hero_viewport(sz: Dictionary, hero_idx: int) -> void:
	if _hero_viewport.has("svc") and is_instance_valid(_hero_viewport.svc):
		_hero_viewport.svc.queue_free()
	_hero_viewport.clear()

	if hero_idx < 0 or hero_idx >= GameState.CHARACTERS.size():
		return

	var hero_data: Dictionary = GameState.CHARACTERS[hero_idx]
	var frames_path: String   = hero_data.get("frames", "")
	if frames_path == "" or not ResourceLoader.exists(frames_path):
		return

	var frames: SpriteFrames = UIFactory.cached_load(frames_path)

	var svc := SubViewportContainer.new()
	svc.custom_minimum_size   = Vector2(sz.hero_w, sz.hero_h)
	svc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	svc.stretch               = false
	svc.clip_contents         = false
	svc.mouse_filter          = Control.MOUSE_FILTER_IGNORE

	var svp := SubViewport.new()
	svp.size                      = Vector2i(int(sz.hero_w), int(sz.hero_h))
	svp.transparent_bg            = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(svp)

	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.position      = Vector2(sz.hero_w * 0.5, sz.hero_h * 0.65)
	anim.scale         = Vector2(sz.hero_scale * 0.88, sz.hero_scale * 0.88)
	if frames != null and frames.has_animation("idle"):
		anim.play("idle")
	svp.add_child(anim)

	_viewport_park.add_child(svc)
	_hero_viewport = { "svc": svc, "svp": svp, "anim": anim }

func _on_resize() -> void:
	_reclaim_all_viewports()
	_init_viewports()
	_build_ui()

func _build_ui() -> void:
	_reclaim_all_viewports()

	for child in get_children():
		if child == _viewport_park:
			continue
		child.queue_free()

	var screen_size := get_viewport().get_visible_rect().size
	var screen_w: float = screen_size.x
	var screen_h: float = screen_size.y
	var sz := _make_sizes(screen_w, screen_h)

	var bg_canvas := CanvasLayer.new()
	bg_canvas.layer = 0
	add_child(bg_canvas)

	var bg := TextureRect.new()
	bg.texture = _bg_tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg_canvas.add_child(bg)

	var darkener := ColorRect.new()
	darkener.color        = Color(0.0, 0.0, 0.0, 0.72)
	darkener.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkener.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_canvas.add_child(darkener)

	var counter_canvas := CanvasLayer.new()
	counter_canvas.layer = 1
	add_child(counter_canvas)
	_build_top_bar(counter_canvas, screen_w, screen_h, sz)

	var tab_canvas := CanvasLayer.new()
	tab_canvas.layer = 2
	add_child(tab_canvas)
	_build_tab_bar(tab_canvas, screen_w, screen_h)

	var content_canvas := CanvasLayer.new()
	content_canvas.layer = 1
	add_child(content_canvas)
	_build_content(content_canvas, screen_w, screen_h, sz)

	_build_overlay_buttons(screen_w, screen_h, sz)
	_maybe_show_hint(screen_w, screen_h)

func _build_top_bar(canvas: CanvasLayer, screen_w: float, screen_h: float, sz: Dictionary) -> void:
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", int(screen_w * 0.08))
	top_bar.position  = Vector2(0, clampf(screen_h * 0.04, 24.0, 52.0))
	top_bar.size      = Vector2(screen_w, sz.counter_icon + 16)
	canvas.add_child(top_bar)

	var soul_hbox := HBoxContainer.new()
	soul_hbox.alignment             = BoxContainer.ALIGNMENT_CENTER
	soul_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	soul_hbox.add_theme_constant_override("separation", 8)
	top_bar.add_child(soul_hbox)

	var soul_icon := TextureRect.new()
	soul_icon.texture             = _coin_icon_tex
	soul_icon.custom_minimum_size = Vector2(sz.counter_icon, sz.counter_icon)
	soul_icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	soul_icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	soul_hbox.add_child(soul_icon)

	var soul_lbl := Label.new()
	soul_lbl.text = str(GameState.lifetime_coins)
	soul_lbl.add_theme_font_size_override("font_size", sz.counter_font)
	soul_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3, 1.0))
	soul_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	soul_hbox.add_child(soul_lbl)

	var soul_tag := Label.new()
	soul_tag.text = "Soul Coins"
	soul_tag.add_theme_font_size_override("font_size", int(sz.counter_font * 0.70))
	soul_tag.add_theme_color_override("font_color", Color(0.8, 0.75, 1.0, 0.9))
	soul_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	soul_hbox.add_child(soul_tag)

	var total_runes: int = 0
	for k in GameState.runes:
		total_runes += GameState.runes[k]

	var rune_hbox := HBoxContainer.new()
	rune_hbox.alignment             = BoxContainer.ALIGNMENT_CENTER
	rune_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rune_hbox.add_theme_constant_override("separation", 8)
	top_bar.add_child(rune_hbox)

	var rune_icon := TextureRect.new()
	rune_icon.texture             = _rune_icon_tex
	rune_icon.custom_minimum_size = Vector2(sz.counter_icon, sz.counter_icon)
	rune_icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	rune_icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rune_hbox.add_child(rune_icon)

	var rune_lbl := Label.new()
	rune_lbl.text = str(total_runes)
	rune_lbl.add_theme_font_size_override("font_size", sz.counter_font)
	rune_lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0, 1.0))
	rune_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rune_hbox.add_child(rune_lbl)

	var rune_tag := Label.new()
	rune_tag.text = "Runes"
	rune_tag.add_theme_font_size_override("font_size", int(sz.counter_font * 0.70))
	rune_tag.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0, 0.9))
	rune_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rune_hbox.add_child(rune_tag)

func _build_tab_bar(canvas: CanvasLayer, screen_w: float, screen_h: float) -> void:
	var tab_font: int = int(clampf(screen_w * 0.030, 20.0, 36.0))
	var tab_w: float  = clampf(screen_w * 0.30, 160.0, 320.0)
	var tab_h: float  = clampf(screen_h * 0.16, 100.0, 160.0)
	var tab_y: float  = clampf(screen_h * 0.10, 60.0, 130.0)

	var tab_bar := HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", int(screen_w * 0.002))
	tab_bar.position = Vector2(0, tab_y)
	tab_bar.size     = Vector2(screen_w, tab_h)
	canvas.add_child(tab_bar)

	var tab_names := ["Characters", "Stats & Tier", "Rune Circle"]
	for t in range(tab_names.size()):
		var is_active: bool = t == _current_tab

		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(tab_w, tab_h)
		tab_bar.add_child(wrap)

		var bg_rect := TextureRect.new()
		bg_rect.texture       = _tab_active_tex if is_active else _tab_normal_tex
		bg_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode  = TextureRect.STRETCH_SCALE
		bg_rect.anchor_left   = 0.0
		bg_rect.anchor_right  = 1.0
		bg_rect.anchor_top    = 0.0
		bg_rect.anchor_bottom = 1.0
		bg_rect.offset_left   = 0
		bg_rect.offset_right  = 0
		bg_rect.offset_top    = 0
		bg_rect.offset_bottom = 0
		bg_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		bg_rect.modulate      = Color(1, 1, 1, 1) if is_active else Color(0.72, 0.72, 0.72, 0.88)
		wrap.add_child(bg_rect)

		var lbl := Label.new()
		lbl.text = tab_names[t]
		lbl.add_theme_font_size_override("font_size", tab_font)
		lbl.add_theme_color_override("font_color",
			Color(0.25, 1.0, 0.55, 1.0) if is_active else Color(0.78, 0.78, 0.78, 1.0)
		)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		lbl.anchor_left          = 0.0
		lbl.anchor_right         = 1.0
		lbl.anchor_top           = 0.0
		lbl.anchor_bottom        = 1.0
		lbl.offset_left          = 0
		lbl.offset_right         = 0
		lbl.offset_top           = 0
		lbl.offset_bottom        = 0
		wrap.add_child(lbl)

		var btn := Button.new()
		btn.flat          = true
		btn.anchor_left   = 0.0
		btn.anchor_right  = 1.0
		btn.anchor_top    = 0.0
		btn.anchor_bottom = 1.0
		btn.offset_left   = 0
		btn.offset_right  = 0
		btn.offset_top    = 0
		btn.offset_bottom = 0
		btn.mouse_filter  = Control.MOUSE_FILTER_STOP
		wrap.add_child(btn)
		var tab_index := t
		btn.pressed.connect(func():
			_current_tab = tab_index
			_build_ui()
		)

func _build_content(canvas: CanvasLayer, screen_w: float, screen_h: float, sz: Dictionary) -> void:
	var tab_h: float       = clampf(screen_h * 0.16, 100.0, 160.0)
	var tab_y: float       = clampf(screen_h * 0.10, 60.0, 130.0)
	var content_top: float = tab_y + tab_h * 0.72

	var root := Control.new()
	root.position = Vector2(0, content_top)
	root.size     = Vector2(screen_w, screen_h - content_top)
	canvas.add_child(root)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", sz.root_sep)
	root.add_child(root_vbox)

	var available_h: float = screen_h - content_top
	var sz_content := _make_sizes(screen_w, available_h)

	match _current_tab:
		0: _tab_characters.build(root_vbox, screen_w, available_h, sz_content)
		1: _tab_stats.build(root_vbox, screen_w, available_h, sz_content)
		2: _tab_runes.build(root_vbox, screen_w, available_h, sz_content)

const TAB_HINTS: Array = [
	{
		"key":   "hint_characters",
		"title": "CHOOSING A CHARACTER",
		"text":  "Tap a card to pick your character.\n\nTo unlock the next one, reach the shown height with the previous character, then buy it with Soul Coins.",
	},
	{
		"key":   "hint_stats",
		"title": "UPGRADES",
		"text":  "Spend runes and Soul Coins to make your character stronger.\n\nUse the upgrade button, choose a rune, then confirm.",
	},
	{
		"key":   "hint_runes",
		"title": "RUNES",
		"text":  "Runes drop when you shoot birds. Touch a rune to collect it.\n\nChoose a rune for your Spell Circle to pick the element of your spell.",
	},
]

# Shows a short one-time explanation the first time each tab is opened.
func _maybe_show_hint(_screen_w: float, _screen_h: float) -> void:
	if _current_tab < 0 or _current_tab >= TAB_HINTS.size():
		return
	var hint: Dictionary = TAB_HINTS[_current_tab]
	UIFactory.show_hint_card(self, hint["key"], hint["title"], hint["text"])

func _build_overlay_buttons(screen_w: float, screen_h: float, sz: Dictionary) -> void:
	var btn_canvas := CanvasLayer.new()
	btn_canvas.layer = 5
	add_child(btn_canvas)

	var back_btn := _make_texture_button(_back_btn_tex, Vector2(sz.back_btn, sz.back_btn))
	back_btn.position = Vector2(12, 12)
	back_btn.pressed.connect(_on_back)
	btn_canvas.add_child(back_btn)

func _make_sizes(screen_w: float, screen_h: float) -> Dictionary:
	var card_w: float = clampf(screen_w * 0.21, 155.0, 220.0)
	var card_h: float = clampf(card_w * 1.9, 290.0, 420.0)
	var prev_w: float = clampf(card_w * 0.70, 100.0, 160.0)
	var prev_h: float = clampf(card_h * 0.40, 100.0, 160.0)
	return {
		"title_font":     int(clampf(screen_w * 0.045, 30.0, 48.0)),
		"counter_font":   int(clampf(screen_w * 0.042, 28.0, 48.0)),
		"counter_icon":   clampf(screen_w * 0.062, 38.0, 64.0),
		"back_btn":       clampf(screen_w * 0.07, 50.0, 72.0) * 1.5,
		"root_sep":       int(clampf(screen_h * 0.004, 2.0, 6.0)),
		"card_w":         card_w,
		"card_h":         card_h,
		"preview_w":      prev_w,
		"preview_h":      prev_h,
		"hero_w":         clampf(screen_w * 0.80, 500.0, 900.0),
		"hero_h":         clampf(screen_h * 0.34, 260.0, 440.0),
		"hero_scale":     clampf(screen_w / 500.0, 2.0, 3.1),
		"grid_h_sep":     int(clampf(screen_w * 0.02, 14.0, 32.0)),
		"grid_v_sep":     int(clampf(screen_h * 0.02, 14.0, 32.0)),
		"name_font":      int(clampf(screen_w * 0.028, 18.0, 26.0)),
		"stat_font":      int(clampf(screen_w * 0.026, 17.0, 26.0)),
		"selected_font":  int(clampf(screen_w * 0.025, 16.0, 25.0)),
		"locked_font":    int(clampf(screen_w * 0.025, 16.0, 25.0)),
		"hint_font":      int(clampf(screen_w * 0.04,  26.0, 44.0)),
		"hero_name_font": int(clampf(screen_w * 0.032, 22.0, 38.0)),
		"cost_font":      int(clampf(screen_w * 0.03,  22.0, 32.0)),
		"coin_icon":      clampf(screen_w * 0.04, 28.0, 38.0),
		"label_font":     int(clampf(screen_w * 0.028, 18.0, 30.0)),
		"value_font":     int(clampf(screen_w * 0.025, 16.0, 26.0)),
		"btn_font":       int(clampf(screen_w * 0.025, 16.0, 28.0)),
		"panel_w":        clampf(screen_w * 0.65, 340.0, 680.0),
		"panel_sep":      int(clampf(screen_h * 0.018, 12.0, 24.0)),
		"rune_panel_w":   clampf(screen_w * 0.72, 360.0, 740.0),
		"rune_panel_sep": int(clampf(screen_h * 0.016, 10.0, 22.0)),
	}

func get_card_bg_tex(index: int) -> Texture2D:
	var total: int = GameState.CHARACTERS.size()
	if index == total - 1:   return _card_bg_blackgolden_tex
	elif index == total - 2: return _card_bg_goldengrey_tex
	return _card_bg_tex

func get_sprite_size_from_frames(frames: SpriteFrames) -> Vector2:
	if frames == null:
		return Vector2(64, 64)
	var anim: String = "idle"
	if not frames.has_animation("idle"):
		var names = frames.get_animation_names()
		if names.size() > 0:
			anim = names[0]
		else:
			return Vector2(64, 64)
	if frames.get_frame_count(anim) > 0:
		var tex: Texture2D = frames.get_frame_texture(anim, 0)
		if tex != null:
			return tex.get_size()
	return Vector2(64, 64)

func shake_card(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var orig := card.position
	var tw   := create_tween()
	tw.tween_property(card, "position", orig + Vector2(-6, 0), 0.04)
	tw.tween_property(card, "position", orig + Vector2( 6, 0), 0.04)
	tw.tween_property(card, "position", orig + Vector2(-4, 0), 0.04)
	tw.tween_property(card, "position", orig + Vector2( 4, 0), 0.04)
	tw.tween_property(card, "position", orig,                  0.04)

func _make_texture_button(tex: Texture2D, button_size: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal      = tex
	btn.custom_minimum_size = button_size
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_SCALE
	btn.pivot_offset        = button_size * 0.5
	btn.button_down.connect(func():  btn.scale = Vector2(0.95, 0.95))
	btn.button_up.connect(func():    btn.scale = Vector2(1.0,  1.0))
	btn.mouse_exited.connect(func(): btn.scale = Vector2(1.0,  1.0))
	return btn

func rebuild() -> void:
	if GameState.selected_character != _selected:
		var screen_size := get_viewport().get_visible_rect().size
		var sz          := _make_sizes(screen_size.x, screen_size.y)
		_reclaim_all_viewports()
		_rebuild_hero_viewport(sz, GameState.selected_character)
	_selected = GameState.selected_character
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()

func _on_back() -> void:
	SoundManager.play_click()
	UIFactory.change_scene(get_tree(), MENU_SCENE)
