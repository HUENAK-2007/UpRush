extends Node

var host: Node

var _rune_svcs: Dictionary = {}
var _circle_svc: SubViewportContainer = null

const RUNE_INFO: Dictionary = {
	0: {"name": "Fire",  "color": Color(1.0, 0.45, 0.0, 1.0), "frames": "res://assets/Sprites/Runes/Fire_idle.tres",  "scale_mult": 1.0,  "icon": "res://assets/Sprites/Runes/fire-Photoroom.webp",       "frame": "res://assets/ui/Backgroundframes/Fire_frame.webp",  "framed_sprite": "res://assets/ui/Backgroundframes/fireframed.webp"},
	1: {"name": "Wind",  "color": Color(0.5, 1.0, 1.0, 1.0),  "frames": "res://assets/Sprites/Runes/Wind_idle.tres",  "scale_mult": 1.0,  "icon": "res://assets/Sprites/Runes/wind-Photoroom.webp",       "frame": "res://assets/ui/Backgroundframes/Wind_frame.webp",  "framed_sprite": "res://assets/ui/Backgroundframes/windframed.webp"},
	2: {"name": "Soul",  "color": Color(0.7, 0.3, 1.0, 1.0),  "frames": "res://assets/Sprites/Runes/Soul_idle.tres",  "scale_mult": 1.0,  "icon": "res://assets/Sprites/Runes/flower-Photoroom.webp",     "frame": "res://assets/ui/Backgroundframes/Soul_frame.webp",  "framed_sprite": "res://assets/ui/Backgroundframes/soulfrmaed.webp"},
	3: {"name": "Blood", "color": Color(0.9, 0.0, 0.1, 1.0),  "frames": "res://assets/Sprites/Runes/Blood_idle.tres", "scale_mult": 0.70, "icon": "res://assets/Sprites/Runes/water_drop-Photoroom.webp", "frame": "res://assets/ui/Backgroundframes/Blood_framw.webp", "framed_sprite": "res://assets/ui/Backgroundframes/bloodframed.webp"},
	4: {"name": "Earth", "color": Color(0.3, 0.7, 0.2, 1.0),  "frames": "res://assets/Sprites/Runes/Earth_idle.tres", "scale_mult": 1.0,  "icon": "res://assets/Sprites/Runes/leaves-Photoroom.webp",     "frame": "res://assets/ui/Backgroundframes/Earht_framew.webp", "framed_sprite": "res://assets/ui/Backgroundframes/earth framed.webp"},
}

const RUNE_ORDER: Array     = [0, 1, 2, 3, 4]
const CIRCLE_FRAMES: String = "res://assets/Sprites/Spell/Spell_criclestraigt.tres"

var _state: int        = 0
var _pending_rune: int = -1

func _make_plain_icon(rune_key: int, size: float, is_active: bool) -> Control:
	var info: Dictionary = RUNE_INFO[rune_key]
	var wrap := Control.new()
	wrap.custom_minimum_size   = Vector2(size, size)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon := TextureRect.new()
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(info["icon"]):
		icon.texture = UIFactory.cached_load(info["icon"])
	icon.modulate = Color(1, 1, 1, 1) if is_active else Color(0.55, 0.55, 0.55, 0.80)
	wrap.add_child(icon)
	return wrap

func _make_framed_selector(rune_key: int, size: float, is_active: bool) -> Control:
	var info: Dictionary = RUNE_INFO[rune_key]
	var wrap := Control.new()
	wrap.custom_minimum_size   = Vector2(size, size)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var sprite_path: String = info.get("framed_sprite", "")
	if ResourceLoader.exists(sprite_path):
		var rect := TextureRect.new()
		rect.texture      = UIFactory.cached_load(sprite_path)
		rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.modulate     = Color(1, 1, 1, 1) if is_active else Color(0.45, 0.45, 0.45, 0.80)
		wrap.add_child(rect)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var capture_rune: int = rune_key
	btn.pressed.connect(func():
		GameState.set_circle_rune(GameState.selected_character, capture_rune)
		_state        = 0
		_pending_rune = -1
		host.rebuild()
	)
	wrap.add_child(btn)
	return wrap

var _fit_inv_icon: float = 140.0
var _fit_sel_size:  float = 180.0
var _fit_circle:    float = 520.0

# The tab has no scroll, so size the big pieces from the height that is
# really available; otherwise the bottom frames run off the screen.
func _compute_fit(screen_w: float, avail_h: float, sz: Dictionary) -> void:
	var owned_count: int = 0
	for rune_key in RUNE_ORDER:
		if GameState.runes.get(rune_key, 0) > 0:
			owned_count += 1

	var h_sep: float = screen_w * 0.03
	var base_inv: float = clampf(
		(sz.rune_panel_w - h_sep * float(RUNE_ORDER.size() - 1)) / float(RUNE_ORDER.size()),
		60.0, 140.0)
	_fit_inv_icon = clampf(minf(base_inv, avail_h * 0.10), 48.0, 140.0)

	var base_sel: float = 100.0
	if owned_count > 0:
		base_sel = clampf(sz.rune_panel_w / (float(owned_count) - 0.2) * 1.12, 112.0, 200.0)
	_fit_sel_size = clampf(minf(base_sel, avail_h * 0.14), 72.0, 200.0)

	var line_label: float = float(sz.label_font) * 1.4
	var line_value: float = float(sz.value_font) * 1.4
	var sep: float = float(sz.rune_panel_sep)
	var used: float = 0.0
	used += line_label                                   # inventory title
	used += _fit_inv_icon + line_value + line_label + 8.0 # inventory column
	used += 2.0                                          # divider
	used += line_label                                   # circle title
	used += line_value                                   # active label
	var children: float = 7.0
	if owned_count > 0:
		used += 2.0 + line_value + _fit_sel_size           # divider, label, selector row
		children += 3.0
	used += sep * children
	used += avail_h * 0.04                               # safety margin at the bottom
	_fit_circle = clampf(avail_h - used, 140.0, clampf(screen_w * 0.68, 280.0, 520.0))

func build(root_vbox: VBoxContainer, screen_w: float, screen_h: float, sz: Dictionary) -> void:
	_compute_fit(screen_w, screen_h, sz)
	var center_h := HBoxContainer.new()
	center_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_h.alignment             = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(center_h)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(sz.rune_panel_w, 0)
	panel.add_theme_constant_override("separation", sz.rune_panel_sep)
	center_h.add_child(panel)

	_build_inventory(panel, screen_w, screen_h, sz)
	_add_divider(panel, sz.rune_panel_w)
	_build_circle_section(panel, screen_w, screen_h, sz)

func _fit_anim_to_box(anim: AnimatedSprite2D, box_size: float, scale_mult: float = 1.0) -> void:
	if anim.sprite_frames == null:
		return
	var anim_names = anim.sprite_frames.get_animation_names()
	if anim_names.is_empty():
		return
	var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim_names[0], 0)
	if tex == null:
		return
	var tex_size: Vector2 = tex.get_size()
	var fit_scale: float  = minf(box_size / tex_size.x, box_size / tex_size.y) * 0.9 * scale_mult
	anim.scale = Vector2(fit_scale, fit_scale)

func _build_inventory(panel: VBoxContainer, screen_w: float, _screen_h: float, sz: Dictionary) -> void:
	var title := Label.new()
	title.text = "Rune Inventory"
	title.add_theme_font_size_override("font_size", sz.label_font)
	title.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	# All five runes are always shown; runes not collected yet are greyed out.
	var h_sep: int = int(screen_w * 0.03)

	var grid := GridContainer.new()
	grid.columns = RUNE_ORDER.size()
	grid.add_theme_constant_override("h_separation", h_sep)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(grid)

	var icon_size: float = _fit_inv_icon

	var grey_text := Color(0.55, 0.55, 0.55, 0.80)

	for rune_key in RUNE_ORDER:
		var info: Dictionary = RUNE_INFO[rune_key]
		var count: int       = GameState.runes.get(rune_key, 0)
		var owned: bool      = count > 0

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		grid.add_child(col)

		col.add_child(_make_plain_icon(rune_key, icon_size, owned))

		var name_lbl := Label.new()
		name_lbl.text = info["name"]
		name_lbl.add_theme_font_size_override("font_size", sz.value_font)
		name_lbl.add_theme_color_override("font_color", info["color"] if owned else grey_text)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.text = str(count)
		count_lbl.add_theme_font_size_override("font_size", sz.label_font)
		count_lbl.add_theme_color_override("font_color", Color.WHITE if owned else grey_text)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(count_lbl)

func _build_circle_section(
	panel: VBoxContainer,
	screen_w: float, _screen_h: float,
	sz: Dictionary
) -> void:
	var idx: int = GameState.selected_character

	var circle_title := Label.new()
	circle_title.text = "Spell Circle  —  " + (
		GameState.CHARACTERS[idx]["name"] if idx >= 0 else "No Character"
	)
	circle_title.add_theme_font_size_override("font_size", sz.label_font)
	circle_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.85, 1.0))
	circle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(circle_title)

	if idx < 0 or idx >= GameState.CHARACTERS.size():
		var lbl := Label.new()
		lbl.text = "Select a character first."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.6, 1))
		panel.add_child(lbl)
		return

	var current_rune: int        = GameState.character_circle_rune[idx] \
								   if idx < GameState.character_circle_rune.size() \
								   else GameState.Rune.SOUL
	var current_color: Color     = GameState.get_circle_rune_color(idx)
	var current_info: Dictionary = RUNE_INFO.get(current_rune, RUNE_INFO[2])

	var circle_size: float = _fit_circle

	var circle_wrap := Control.new()
	circle_wrap.custom_minimum_size   = Vector2(circle_size, circle_size)
	circle_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(circle_wrap)

	if ResourceLoader.exists(CIRCLE_FRAMES):
		var is_new_circle: bool = not is_instance_valid(_circle_svc)
		if not is_new_circle:
			if _circle_svc.get_parent() != null:
				_circle_svc.get_parent().remove_child(_circle_svc)

		if is_new_circle:
			_circle_svc = SubViewportContainer.new()
			var circle_svp := SubViewport.new()
			circle_svp.transparent_bg = true
			circle_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			_circle_svc.add_child(circle_svp)

			var circle_frames: SpriteFrames = UIFactory.cached_load(CIRCLE_FRAMES)
			var circle_anim := AnimatedSprite2D.new()
			circle_anim.sprite_frames = circle_frames
			circle_anim.position      = Vector2(circle_size * 0.5, circle_size * 0.5)
			circle_anim.modulate      = current_color
			_fit_anim_to_box(circle_anim, circle_size)
			if circle_frames.get_animation_names().size() > 0:
				circle_anim.play(circle_frames.get_animation_names()[0])
			circle_svp.add_child(circle_anim)

		_circle_svc.custom_minimum_size = Vector2(circle_size, circle_size)
		_circle_svc.stretch             = false
		_circle_svc.clip_contents       = false
		_circle_svc.set_anchors_preset(Control.PRESET_FULL_RECT)

		var circle_svp: SubViewport = _circle_svc.get_child(0)
		circle_svp.size = Vector2i(int(circle_size), int(circle_size))
		for child in circle_svp.get_children():
			if child is AnimatedSprite2D:
				child.position = Vector2(circle_size * 0.5, circle_size * 0.5)
				child.modulate = current_color
				_fit_anim_to_box(child, circle_size)

		circle_wrap.add_child(_circle_svc)

	var rune_cache_key: String   = "circle_rune_%d" % current_rune
	var rune_frames_path: String = current_info["frames"]
	if ResourceLoader.exists(rune_frames_path):
		var rune_size: float  = circle_size * 0.35
		var is_new_rune: bool = not (_rune_svcs.has(rune_cache_key) and is_instance_valid(_rune_svcs[rune_cache_key].svc))
		var rune_svc: SubViewportContainer
		var rune_svp: SubViewport

		if not is_new_rune:
			rune_svc = _rune_svcs[rune_cache_key].svc
			rune_svp = _rune_svcs[rune_cache_key].svp
			if rune_svc.get_parent() != null:
				rune_svc.get_parent().remove_child(rune_svc)
		else:
			rune_svc = SubViewportContainer.new()
			rune_svp = SubViewport.new()
			rune_svp.transparent_bg = true
			rune_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			rune_svc.add_child(rune_svp)

			var rune_frames: SpriteFrames = UIFactory.cached_load(rune_frames_path)
			var rune_anim := AnimatedSprite2D.new()
			rune_anim.sprite_frames = rune_frames
			rune_anim.position      = Vector2(rune_size * 0.5, rune_size * 0.5)
			_fit_anim_to_box(rune_anim, rune_size, current_info.get("scale_mult", 1.0))
			if rune_frames.get_animation_names().size() > 0:
				rune_anim.play(rune_frames.get_animation_names()[0])
			rune_svp.add_child(rune_anim)
			_rune_svcs[rune_cache_key] = {"svc": rune_svc, "svp": rune_svp}

		rune_svc.custom_minimum_size = Vector2(rune_size, rune_size)
		rune_svc.stretch             = false
		rune_svc.clip_contents       = false
		rune_svc.position = Vector2(
			(circle_size - rune_size) * 0.5,
			(circle_size - rune_size) * 0.5
		)
		rune_svp.size = Vector2i(int(rune_size), int(rune_size))
		for child in rune_svp.get_children():
			if child is AnimatedSprite2D:
				child.position = Vector2(rune_size * 0.5, rune_size * 0.5)
				_fit_anim_to_box(child, rune_size, current_info.get("scale_mult", 1.0))

		circle_wrap.add_child(rune_svc)

	var active_lbl := Label.new()
	active_lbl.text = "Active:  " + current_info["name"]
	active_lbl.add_theme_font_size_override("font_size", sz.value_font)
	active_lbl.add_theme_color_override("font_color", current_color)
	active_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(active_lbl)

	# ── Bottom selector ────────────────────────────────────────────────────────
	var owned_runes: Array = []
	for rune_key in RUNE_ORDER:
		if GameState.runes.get(rune_key, 0) > 0:
			owned_runes.append(rune_key)

	if not owned_runes.is_empty():
		_add_divider(panel, sz.rune_panel_w)

		var sel_label := Label.new()
		sel_label.text = "Select Circle Rune"
		sel_label.add_theme_font_size_override("font_size", sz.value_font)
		sel_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6, 0.90))
		sel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(sel_label)

		var sel_row := HBoxContainer.new()
		sel_row.alignment             = BoxContainer.ALIGNMENT_CENTER
		sel_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel_row.add_theme_constant_override("separation", int(screen_w * 0.018))
		panel.add_child(sel_row)

		# CHANGED: larger icons — smaller divisor, higher clamp
		var sel_size: float = _fit_sel_size

		for rune_key in owned_runes:
			var is_active: bool = rune_key == current_rune
			sel_row.add_child(_make_framed_selector(rune_key, sel_size, is_active))

func _add_divider(panel: VBoxContainer, width: float) -> void:
	var div := ColorRect.new()
	div.color               = Color(1, 1, 1, 0.15)
	div.custom_minimum_size = Vector2(width, 2)
	panel.add_child(div)
