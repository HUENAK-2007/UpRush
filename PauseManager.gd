class_name PauseManager
extends RefCounted

signal resumed
signal main_menu_requested
signal buttons_visibility_changed(visible: bool)

const WHITE := Color(1, 1, 1, 1)
const DIM_WHITE := Color(0.85, 0.85, 0.85, 1)

var _pause_overlay: CanvasLayer = null
var _owner_node: Node = null
var _pause_btn: TextureButton = null
var _tex_normal: Texture2D = null
var _tex_active: Texture2D = null

# ── Setup ──

func setup(owner: Node, pause_btn: TextureButton) -> void:
	_owner_node = owner
	_pause_btn = pause_btn
	_tex_normal = pause_btn.texture_normal
	_tex_active = pause_btn.texture_pressed

func set_pause_btn_icon(paused: bool) -> void:
	if paused and _tex_active != null:
		_pause_btn.texture_normal = _tex_active
	elif not paused and _tex_normal != null:
		_pause_btn.texture_normal = _tex_normal

# ── Build / Destroy ──

func build_pause_overlay() -> void:
	if is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()

	var screen := _owner_node.get_viewport().get_visible_rect().size
	var sz := _calc_sizes(screen)

	_pause_overlay = _make_canvas(100)
	var root := _make_dimmed_root()
	var panel := _make_panel(root, sz)
	var vbox := _make_content_box(panel, sz)

	_build_header(vbox, sz)
	_build_volume(vbox, sz)
	_build_toggle_row(vbox, sz, "Music", SoundManager.music_enabled, func(btn: TextureButton):
		SoundManager.set_music_enabled(!SoundManager.music_enabled)
		_refresh_toggle(btn, SoundManager.music_enabled)
	)
	_build_toggle_row(vbox, sz, "SFX", SoundManager.sfx_enabled, func(btn: TextureButton):
		SoundManager.set_sfx_enabled(!SoundManager.sfx_enabled)
		_refresh_toggle(btn, SoundManager.sfx_enabled)
	)
	_build_toggle_row(vbox, sz, "Buttons", GameState.buttons_visible, func(btn: TextureButton):
		GameState.buttons_visible = not GameState.buttons_visible
		GameState.save()
		_refresh_toggle(btn, GameState.buttons_visible)
		buttons_visibility_changed.emit(GameState.buttons_visible)
	)
	_add_gap(vbox, sz.gap)
	_build_menu_btn(vbox, sz)
	_defer_panel_layout(panel, vbox, sz, screen)

func destroy_overlay() -> void:
	if is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
		_pause_overlay = null

# ── Sizes ──

class Sizes:
	var panel_w: float
	var margin: float
	var inner_w: float
	var slider_w: float
	var toggle: float
	var menu_w: float
	var menu_h: float
	var close: float
	var title_fs: int
	var label_fs: int
	var sep: int
	var gap: float
	var row_sep: int

func _calc_sizes(screen: Vector2) -> Sizes:
	var s := Sizes.new()
	s.panel_w   = min(520.0, screen.x * 0.82)
	s.margin    = maxf(20.0, s.panel_w * 0.07)
	s.inner_w   = s.panel_w - s.margin * 2.0
	s.slider_w  = min(s.inner_w, s.panel_w * 0.72)
	s.toggle    = maxf(60.0, s.inner_w * 0.20)
	s.menu_w    = s.inner_w * 0.85
	s.menu_h    = s.menu_w * 0.34
	s.close     = maxf(48.0, s.inner_w * 0.14)
	s.title_fs  = int(maxf(30.0, s.inner_w * 0.13))
	s.label_fs  = int(maxf(16.0, s.inner_w * 0.068))
	s.sep       = int(maxf(10.0, s.inner_w * 0.04))
	s.gap       = maxf(8.0, s.inner_w * 0.03)
	s.row_sep   = int(maxf(8.0, s.inner_w * 0.03))
	return s

# ── Scaffolding ──

func _make_canvas(layer: int) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.layer = layer
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	_owner_node.add_child(c)
	return c

func _make_dimmed_root() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	return root

func _make_panel(root: Control, sz: Sizes) -> Control:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.process_mode = Node.PROCESS_MODE_ALWAYS
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrap)

	var panel := Control.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	panel.size = Vector2(sz.panel_w, 0)
	wrap.add_child(panel)

	var bg := TextureRect.new()
	bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_top    = -140
	bg.offset_bottom = 140
	bg.modulate = Color(1, 1, 1, 0.82)
	if ResourceLoader.exists(UIFactory.PAUSE_BG):
		bg.texture = UIFactory.cached_load(UIFactory.PAUSE_BG)
	panel.add_child(bg)
	return panel

func _make_content_box(panel: Control, sz: Sizes) -> VBoxContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.process_mode = Node.PROCESS_MODE_ALWAYS
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := int(sz.margin)
	for side in ["left", "top", "right", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	panel.add_child(mc)

	var vb := VBoxContainer.new()
	vb.process_mode = Node.PROCESS_MODE_ALWAYS
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", sz.sep)
	mc.add_child(vb)
	return vb

# ── Sections ──

func _build_header(vbox: VBoxContainer, sz: Sizes) -> void:
	var row := _hbox(vbox)

	var title := _label("PAUSED", sz.title_fs, WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var btn := UIFactory.make_icon_btn(
		UIFactory.BTN_CLOSE,
		Vector2(sz.close, sz.close),
		UIFactory.BTN_OFF_CLICKED
	)
	btn.pressed.connect(func(): resumed.emit())
	row.add_child(btn)

func _build_volume(vbox: VBoxContainer, sz: Sizes) -> void:
	vbox.add_child(_label("Master Volume", sz.label_fs, DIM_WHITE))
	var slider := UIFactory.make_custom_slider(
		SoundManager.master_volume, sz.slider_w,
		func(v: float): SoundManager.set_volume(v)
	)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(slider)

func _build_toggle_row(vbox: VBoxContainer, sz: Sizes, text: String, initial: bool, callback: Callable) -> void:
	var row := _hbox(vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", sz.row_sep)

	var lbl := _label(text, sz.label_fs, DIM_WHITE)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var btn := _toggle(initial, sz.toggle)
	btn.pressed.connect(func(): callback.call(btn))
	row.add_child(btn)

func _build_menu_btn(vbox: VBoxContainer, sz: Sizes) -> void:
	var btn := UIFactory.make_icon_btn(
		UIFactory.BTN_MAIN_MENU,
		Vector2(sz.menu_w, sz.menu_h),
		UIFactory.BTN_MAIN_MENU_PRESSED
	)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		_owner_node.get_tree().create_timer(0.15).timeout.connect(
			func(): main_menu_requested.emit()
		)
	)
	vbox.add_child(btn)

# ── Layout Finalize ──

func _defer_panel_layout(panel: Control, vbox: VBoxContainer, sz: Sizes, screen: Vector2) -> void:
	# The panel height must come from the content's real minimum size. Reading
	# vbox.size.y one frame later can be too early (the container has not been
	# laid out yet), which left the panel cropped to a thin strip. So size it
	# right away from the minimum size, and again after two frames in case
	# wrapped text changed the height.
	var apply := func():
		if not is_instance_valid(panel) or not is_instance_valid(vbox):
			return
		var content_h: float = maxf(vbox.get_combined_minimum_size().y, vbox.size.y)
		var h: float = content_h + sz.margin * 2.0
		panel.size = Vector2(sz.panel_w, h)
		panel.position = Vector2(
			(screen.x - sz.panel_w) * 0.5,
			(screen.y - h) * 0.5
		)
	apply.call()
	var tree := _owner_node.get_tree()
	tree.process_frame.connect(func():
		apply.call()
		tree.process_frame.connect(func(): apply.call(), CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)

# ── Tiny Helpers ──

func _label(text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	return l

func _hbox(parent: VBoxContainer) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	return h

func _toggle(on: bool, size: float) -> TextureButton:
	var tex := UIFactory.BTN_ON if on else UIFactory.BTN_OFF
	var btn := UIFactory.make_icon_btn(tex, Vector2(size, size))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return btn

func _refresh_toggle(btn: TextureButton, on: bool) -> void:
	var tex := UIFactory.BTN_ON if on else UIFactory.BTN_OFF
	if ResourceLoader.exists(tex):
		btn.texture_normal = UIFactory.cached_load(tex)

func _add_gap(vbox: VBoxContainer, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, maxf(4.0, h))
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(s)
