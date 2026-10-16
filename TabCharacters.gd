extends Node

var host: Node

func build(root_vbox: VBoxContainer, screen_w: float, screen_h: float, sz: Dictionary) -> void:
	_build_hero_or_hint(root_vbox, sz)
	_build_grid(root_vbox, sz)

func _build_hero_or_hint(root_vbox: VBoxContainer, sz: Dictionary) -> void:
	var idx: int = GameState.selected_character

	if idx >= 0 and idx < GameState.CHARACTERS.size():
		var hero_wrap := HBoxContainer.new()
		hero_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_wrap.alignment             = BoxContainer.ALIGNMENT_CENTER
		root_vbox.add_child(hero_wrap)

		var left_fill := Control.new()
		left_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_wrap.add_child(left_fill)

		var hero_box := VBoxContainer.new()
		hero_box.alignment = BoxContainer.ALIGNMENT_CENTER
		hero_box.add_theme_constant_override("separation", 6)
		hero_box.custom_minimum_size = Vector2(sz.hero_w, 0)
		hero_wrap.add_child(hero_box)

		var right_fill := Control.new()
		right_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_wrap.add_child(right_fill)

		if host._hero_viewport.has("svc") and is_instance_valid(host._hero_viewport.svc):
			var svc: SubViewportContainer = host._hero_viewport.svc
			if svc.get_parent() != null:
				svc.get_parent().remove_child(svc)
			svc.custom_minimum_size           = Vector2(sz.hero_w, sz.hero_h)
			host._hero_viewport.svp.size      = Vector2i(int(sz.hero_w), int(sz.hero_h))
			host._hero_viewport.anim.position = Vector2(sz.hero_w * 0.5, sz.hero_h * 0.65)
			host._hero_viewport.anim.scale    = Vector2(sz.hero_scale * 0.88, sz.hero_scale * 0.88)
			hero_box.add_child(svc)
		else:
			var fallback := ColorRect.new()
			fallback.color               = GameState.CHARACTERS[idx]["color"]
			fallback.custom_minimum_size = Vector2(sz.hero_w, sz.hero_h)
			hero_box.add_child(fallback)

		# ── Hero name + world label ────────────────────────────────────────────
		var char_data: Dictionary = GameState.CHARACTERS[idx]
		var world_idx: int        = char_data.get("world", 0)
		var world_name: String    = GameState.WORLDS[world_idx]["name"] \
									if world_idx < GameState.WORLDS.size() else ""

		var hero_name := Label.new()
		hero_name.text = char_data["name"]
		hero_name.add_theme_font_size_override("font_size", sz.hero_name_font)
		hero_name.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
		hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_box.add_child(hero_name)

		if world_name != "":
			var world_lbl := Label.new()
			world_lbl.text = world_name
			world_lbl.add_theme_font_size_override("font_size", int(sz.hero_name_font * 0.65))
			world_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.9))
			world_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hero_box.add_child(world_lbl)
	else:
		var hint := Label.new()
		hint.text = "Choose your first character"
		hint.add_theme_font_size_override("font_size", sz.hint_font)
		hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65, 1.0))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root_vbox.add_child(hint)

func _build_grid(root_vbox: VBoxContainer, sz: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", sz.grid_h_sep)
	grid.add_theme_constant_override("v_separation", sz.grid_v_sep)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root_vbox.add_child(grid)

	# Row 1: Skeleton  Vampire  Dwarf
	# Row 2: Elf       Angel    [empty]
	var ORDER: Array = [0, 1, 2, 3, 4, -1]

	for slot in ORDER:
		if slot == -1:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(sz.card_w, sz.card_h)
			grid.add_child(spacer)
		else:
			grid.add_child(_make_card(slot, sz))

func _make_card(index: int, sz: Dictionary) -> Control:
	var char_data: Dictionary  = GameState.CHARACTERS[index]
	var is_selected: bool      = GameState.selected_character == index
	var is_unlocked: bool      = GameState.is_character_unlocked(index)
	var unlock_meter: int      = int(char_data.get("unlock_meter", 0))

	var prev_char_idx: int     = index - 1
	var prev_prog: Dictionary  = GameState.get_progression(prev_char_idx) \
								 if prev_char_idx >= 0 \
								 else {"boss_2_defeated": true}
	var prev_boss2_done: bool  = prev_prog.get("boss_2_defeated", false)

	var card := Control.new()
	card.name                       = "Card_%d" % index
	card.custom_minimum_size        = Vector2(sz.card_w, sz.card_h)
	card.mouse_filter               = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = \
		Control.CURSOR_ARROW if is_selected else Control.CURSOR_POINTING_HAND

	var card_bg := TextureRect.new()
	card_bg.texture      = host.get_card_bg_tex(index)
	card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	card_bg.stretch_mode = TextureRect.STRETCH_SCALE
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_bg)

	card.gui_input.connect(_on_card_input.bind(index, card))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment    = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	# ── Status badge ──────────────────────────────────────────────────────────
	if is_selected:
		_add_label(vbox, "✓ SELECTED", sz.selected_font, Color(0.4, 0.9, 0.4, 1.0))
	elif not is_unlocked:
		_add_label(vbox, "🔒 LOCKED",  sz.locked_font,   Color(0.9, 0.9, 0.9, 0.9))
	else:
		_add_label(vbox, "AVAILABLE",  sz.selected_font, Color(0.8, 0.9, 1.0, 0.95))

	# ── Viewport preview ──────────────────────────────────────────────────────
	if host._card_viewports.has(index):
		var entry: Dictionary         = host._card_viewports[index]
		var svc: SubViewportContainer = entry.svc
		if is_instance_valid(svc):
			if svc.get_parent() != null:
				svc.get_parent().remove_child(svc)
			svc.custom_minimum_size  = Vector2(sz.preview_w, sz.preview_h)
			entry.svp.size           = Vector2i(int(sz.preview_w), int(sz.preview_h))
			entry.anim.position      = Vector2(sz.preview_w * 0.5, sz.preview_h * 0.55)
			svc.modulate = Color(0.5, 1.0, 0.5, 1.0) if is_selected else \
						   (Color(0.35, 0.35, 0.35, 1.0) if not is_unlocked else Color.WHITE)
			vbox.add_child(svc)
		else:
			_add_fallback(vbox, char_data, sz, is_selected, is_unlocked)
	else:
		_add_fallback(vbox, char_data, sz, is_selected, is_unlocked)

	# ── Name ──────────────────────────────────────────────────────────────────
	var name_lbl := _add_label(vbox, char_data["name"], sz.name_font, Color.WHITE)
	if is_selected:
		name_lbl.modulate = Color(0.5, 1.0, 0.5, 1.0)

	# ── Stats or unlock condition ─────────────────────────────────────────────
	if is_unlocked:
		var spd_lbl := _add_label(vbox, "SPD " + str(int(char_data["speed"])),
								  sz.stat_font, Color.WHITE)
		var jmp_lbl := _add_label(vbox, "JMP " + str(int(char_data["jump"])),
								  sz.stat_font, Color.WHITE)
		if is_selected:
			spd_lbl.modulate = Color(0.5, 1.0, 0.5, 1.0)
			jmp_lbl.modulate = Color(0.5, 1.0, 0.5, 1.0)
	else:
		if index == 0:
			_add_label(vbox, "Always unlocked", sz.stat_font, Color(0.7, 1.0, 0.7, 1.0))
		else:
			var prev_name: String = GameState.CHARACTERS[prev_char_idx]["name"]
			_add_label(
				vbox,
				"Reach %dm" % unlock_meter,
				sz.stat_font,
				Color(1.0, 0.85, 0.3, 1.0)
			)
			_add_label(
				vbox,
				"with %s" % prev_name,
				sz.stat_font,
				Color(0.75, 0.85, 1.0, 0.9)
			)
			var price: int = GameState.get_character_price(index)
			if prev_boss2_done:
				_add_label(vbox, "Buy: %d Coins" % price, sz.selected_font,
						   Color(1.0, 0.25, 0.25, 1.0))
			else:
				_add_label(vbox, "Price: %d Coins" % price, sz.stat_font,
						   Color(1.0, 0.25, 0.25, 1.0))

	return card

# ─── Helpers ──────────────────────────────────────────────────────────────────
func _add_fallback(vbox: Control, char_data: Dictionary, sz: Dictionary,
				   is_selected: bool, is_unlocked: bool) -> void:
	var fallback := ColorRect.new()
	fallback.color                 = char_data["color"]
	fallback.custom_minimum_size   = Vector2(sz.preview_w, sz.preview_h)
	fallback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fallback.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	fallback.modulate = Color(0.5, 1.0, 0.5, 1.0) if is_selected else \
						(Color(0.35, 0.35, 0.35, 1.0) if not is_unlocked else Color.WHITE)
	vbox.add_child(fallback)

func _add_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", maxi(3, int(font_size * 0.16)))
	parent.add_child(lbl)
	return lbl

func _on_card_input(event: InputEvent, index: int, card: Control) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_card_click(index, card)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_handle_card_click(index, card)

func _handle_card_click(index: int, card: Control) -> void:
	if index < 0 or index >= GameState.CHARACTERS.size():
		return

	var is_unlocked: bool = GameState.is_character_unlocked(index)

	# ── Already unlocked → just select ───────────────────────────────────────
	if is_unlocked:
		if GameState.selected_character == index:
			return
		if GameState.select_character(index):
			SoundManager.play_buy_character()
			host.rebuild()
		return

	# ── Skeleton always free on first launch ─────────────────────────────────
	if index == 0 and not GameState.first_character_choice_done:
		GameState.first_character_choice_done = true
		GameState.unlocked_characters[0]      = true
		GameState.select_character(0)
		SoundManager.play_buy_character()
		host.rebuild()
		return

	# ── Locked: check progression requirement ─────────────────────────────────
	var prev_char_idx: int    = index - 1
	var prev_prog: Dictionary = GameState.get_progression(prev_char_idx) \
								if prev_char_idx >= 0 \
								else {"boss_2_defeated": true}

	if prev_prog.get("boss_2_defeated", false) and GameState.buy_character(index):
		GameState.select_character(index)
		SoundManager.play_buy_character()
		host.rebuild()
	else:
		SoundManager.play_click()
		host.shake_card(card)
