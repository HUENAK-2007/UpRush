class_name HUDManager
extends RefCounted

var _hearts_hbox: HBoxContainer = null
var _coin_hbox: HBoxContainer = null
var _rune_hbox: HBoxContainer = null
var _heart_texture: Texture2D = null
var _score_label: Label = null
var _hearts_label: Label = null
var _coin_label: Label = null

func setup(hud: Control, score_label: Label, hearts_label: Label, coin_label: Label, heart_texture: Texture2D) -> void:
	_score_label = score_label
	_hearts_label = hearts_label
	_coin_label = coin_label
	_heart_texture = heart_texture
	hearts_label.visible = false
	coin_label.visible = false
	score_label.offset_top = 40
	score_label.add_theme_font_size_override("font_size", int(20 * UIFactory.UI_SCALE))

	# Hearts
	_hearts_hbox = HBoxContainer.new()
	_hearts_hbox.name = "HeartsHBox"
	_hearts_hbox.add_theme_constant_override("separation", 6)
	_hearts_hbox.anchor_left = 1.0
	_hearts_hbox.anchor_top = 0.0
	_hearts_hbox.anchor_right = 1.0
	_hearts_hbox.anchor_bottom = 0.0
	_hearts_hbox.offset_left = -130
	_hearts_hbox.offset_top = 40
	_hearts_hbox.offset_right = -8
	_hearts_hbox.offset_bottom = 80
	_hearts_hbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(_hearts_hbox)

	# Coins
	_coin_hbox = HBoxContainer.new()
	_coin_hbox.name = "CoinHBox"
	_coin_hbox.add_theme_constant_override("separation", 6)
	_coin_hbox.anchor_left = 0.5
	_coin_hbox.anchor_top = 0.0
	_coin_hbox.anchor_right = 0.5
	_coin_hbox.anchor_bottom = 0.0
	_coin_hbox.offset_left = -50
	_coin_hbox.offset_top = 40
	_coin_hbox.offset_right = 50
	_coin_hbox.offset_bottom = 80
	_coin_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_coin_hbox)

	var coin_icon := TextureRect.new()
	coin_icon.custom_minimum_size = Vector2(30, 30)
	coin_icon.ignore_texture_size = true
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(UIFactory.COIN_ICON):
		coin_icon.texture = UIFactory.cached_load(UIFactory.COIN_ICON)
	_coin_hbox.add_child(coin_icon)

	var coin_lbl := Label.new()
	coin_lbl.name = "CoinCount"
	coin_lbl.text = "0"
	coin_lbl.add_theme_font_size_override("font_size", int(20 * UIFactory.UI_SCALE))
	coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_hbox.add_child(coin_lbl)

	# Runes
	_rune_hbox = HBoxContainer.new()
	_rune_hbox.name = "RuneHBox"
	_rune_hbox.add_theme_constant_override("separation", 6)
	_rune_hbox.anchor_left = 0.5
	_rune_hbox.anchor_top = 0.0
	_rune_hbox.anchor_right = 0.5
	_rune_hbox.anchor_bottom = 0.0
	_rune_hbox.offset_left = -50
	_rune_hbox.offset_top = 85
	_rune_hbox.offset_right = 50
	_rune_hbox.offset_bottom = 125
	_rune_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_rune_hbox)

	var rune_icon := TextureRect.new()
	rune_icon.custom_minimum_size = Vector2(30, 30)
	rune_icon.ignore_texture_size = true
	rune_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var rune_icon_path: String = "res://assets/Sprites/Runes/all.webp"
	if ResourceLoader.exists(rune_icon_path):
		rune_icon.texture = UIFactory.cached_load(rune_icon_path)
	_rune_hbox.add_child(rune_icon)

	var rune_lbl := Label.new()
	rune_lbl.name = "RuneCount"
	rune_lbl.text = "0"
	rune_lbl.add_theme_font_size_override("font_size", int(20 * UIFactory.UI_SCALE))
	rune_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rune_hbox.add_child(rune_lbl)

func update_hearts(lives: int) -> void:
	_hearts_label.visible = false
	if _hearts_hbox == null:
		return
	for child in _hearts_hbox.get_children():
		child.queue_free()
	for i in range(3):
		var heart := TextureRect.new()
		heart.custom_minimum_size = Vector2(28, 28)
		heart.ignore_texture_size = true
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if _heart_texture != null:
			heart.texture = _heart_texture
		if i < lives:
			heart.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			heart.modulate = Color(0.2, 0.2, 0.2, 0.5)
		_hearts_hbox.add_child(heart)

func update_coin_label(session_coins: int) -> void:
	_coin_label.visible = false
	if _coin_hbox == null:
		return
	var lbl := _coin_hbox.get_node_or_null("CoinCount")
	if is_instance_valid(lbl):
		lbl.text = str(session_coins)

func update_rune_label(session_runes: int) -> void:
	if _rune_hbox == null:
		return
	var lbl := _rune_hbox.get_node_or_null("RuneCount")
	if is_instance_valid(lbl):
		lbl.text = str(session_runes)

func update_score(score_text: String) -> void:
	_score_label.text = score_text
