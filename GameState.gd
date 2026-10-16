extends Node

const SAVE_PATH: String    = "user://gamestate.cfg"
const SAVE_VERSION: int    = 13   # no longer wipes saves on change; see _migrate()
const REFERENCE_WIDTH: float = 720.0

enum Rune {
	FIRE  = 0,
	WIND  = 1,
	SOUL  = 2,
	BLOOD = 3,
	EARTH = 4,
	ANY   = 5,
}

enum GameMode {
	PROGRESSION,
	ENDLESS
}

var CHARACTERS: Array:
	get: return GameData.CHARACTERS

var BACKGROUNDS: Array:
	get: return GameData.BACKGROUNDS

var WORLDS: Array:
	get: return GameData.WORLDS

var RUNE_UPGRADES: Dictionary:
	get: return GameData.RUNE_UPGRADES

var WHEEL_REWARDS: Array:
	get: return GameData.WHEEL_REWARDS

var current_game_mode: int  = GameMode.PROGRESSION
var endless_unlocked: bool  = false
var scene_fade_in: bool    = false   # not saved: fade the next Main scene in from black
var selected_character: int = -1
var lifetime_coins: int     = 0
var coins: int              = 0
var best_score: int         = 0
var selected_background: int = 0
var tutorial_shown: bool    = false
var buttons_visible: bool   = false
var first_character_choice_done: bool = false

var runes: Dictionary = {
	Rune.FIRE:  0,
	Rune.WIND:  0,
	Rune.SOUL:  0,
	Rune.BLOOD: 0,
	Rune.EARTH: 0,
}

var unlocked_characters: Array  = [false, false, false, false, false]
var unlocked_backgrounds: Array = [true, true, true]

var character_circle_rune:    Array = []
var character_rune_used:      Array = []
var character_upgrade_levels: Array = []
var progression:              Array = []

# display multipliers so UI numbers look large but real gameplay values stay tiny
const DISPLAY_MULTIPLIERS: Dictionary = {
	"move_speed": 8.0,
	"jump_speed": 12.0,
	"jump_boost": 15.0,
	"attack":     10.0,
}

func _ready() -> void:
	# Default clear colour is grey; use black so any gap between scenes is black.
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
	load_data()

func get_screen_scale() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var w: float = vp.get_visible_rect().size.x
	if w <= 0.0:
		return 1.0
	return w / REFERENCE_WIDTH

func get_character() -> Dictionary:
	if selected_character < 0 or selected_character >= GameData.CHARACTERS.size():
		return GameData.CHARACTERS[0]
	return GameData.CHARACTERS[selected_character]

func get_background() -> Dictionary:
	if selected_background < 0 or selected_background >= GameData.BACKGROUNDS.size():
		return GameData.BACKGROUNDS[0]
	return GameData.BACKGROUNDS[selected_background]

func is_character_unlocked(index: int) -> bool:
	if index < 0 or index >= unlocked_characters.size():
		return false
	return unlocked_characters[index]

func can_select_character(index: int) -> bool:
	return is_character_unlocked(index)

func select_character(index: int) -> bool:
	if index < 0 or index >= GameData.CHARACTERS.size():
		return false
	if not is_character_unlocked(index):
		return false
	selected_character = index
	if not first_character_choice_done:
		first_character_choice_done = true
		for i in range(unlocked_characters.size()):
			unlocked_characters[i] = (i == index)
	save()
	return true

func unlock_character_by_progression(index: int) -> void:
	if index < 0 or index >= GameData.CHARACTERS.size():
		return
	if unlocked_characters[index]:
		return
	unlocked_characters[index] = true
	if index >= 1:
		endless_unlocked = true
	save()

func is_background_unlocked(index: int) -> bool:
	if index < 0 or index >= unlocked_backgrounds.size():
		return false
	return unlocked_backgrounds[index]

func get_progression(char_index: int) -> Dictionary:
	if char_index < 0 or char_index >= progression.size():
		return {"checkpoint_meter": 0, "boss_1_defeated": false, "boss_2_defeated": false}
	return progression[char_index]

func set_checkpoint(char_index: int, meter: int) -> void:
	if char_index < 0 or char_index >= progression.size():
		return
	progression[char_index]["checkpoint_meter"] = meter
	save()

func defeat_boss(char_index: int, boss_num: int) -> void:
	if char_index < 0 or char_index >= progression.size():
		return
	var world: Dictionary = GameData.WORLDS[char_index]
	if boss_num == 1:
		progression[char_index]["boss_1_defeated"] = true
		set_checkpoint(char_index, world["boss_1_meter"])
	elif boss_num == 2:
		progression[char_index]["boss_2_defeated"] = true
		set_checkpoint(char_index, world["boss_2_meter"])
		var next_char: int = char_index + 1
		if next_char < GameData.CHARACTERS.size():
			unlock_character_by_progression(next_char)
		endless_unlocked = true
	save()

# Bosses were removed: reaching a world's unlock height with that world's
# character makes the NEXT character purchasable (it is not given for free).
# Returns true if a new milestone was recorded.
func check_height_unlock(char_index: int, meters: int) -> bool:
	if char_index < 0 or char_index >= progression.size() or char_index >= GameData.WORLDS.size():
		return false
	var world: Dictionary = GameData.WORLDS[char_index]
	var prog: Dictionary = progression[char_index]
	var changed: bool = false
	if not prog["boss_1_defeated"] and meters >= int(world["boss_1_meter"]):
		prog["boss_1_defeated"] = true
		prog["checkpoint_meter"] = int(world["boss_1_meter"])
		changed = true
	if not prog["boss_2_defeated"] and meters >= int(world["unlock_meter"]):
		prog["boss_2_defeated"] = true
		prog["checkpoint_meter"] = int(world["unlock_meter"])
		changed = true
	if changed:
		save()
	return changed

# Soul Coin price of a character: Vampire (1) = 30, Dwarf = 60, Elf = 90, Angel = 120.
const CHARACTER_PRICE_STEP: int = 30

func get_character_price(index: int) -> int:
	if index <= 0:
		return 0
	return CHARACTER_PRICE_STEP * index

# True once the previous character has reached its unlock height.
func is_character_purchasable(index: int) -> bool:
	if index <= 0 or index >= GameData.CHARACTERS.size():
		return false
	if is_character_unlocked(index):
		return false
	return bool(get_progression(index - 1).get("boss_2_defeated", false))

func can_afford_character(index: int) -> bool:
	return coins >= get_character_price(index)

func buy_character(index: int) -> bool:
	if not is_character_purchasable(index):
		return false
	var price: int = get_character_price(index)
	if coins < price:
		return false
	coins          -= price
	lifetime_coins -= price
	unlock_character_by_progression(index)
	return true

func roll_rune_drop(background_index: int) -> int:
	var bg: Dictionary = GameData.BACKGROUNDS[background_index] \
						 if background_index < GameData.BACKGROUNDS.size() \
						 else GameData.BACKGROUNDS[0]
	var drops: Dictionary = bg.get("rune_drops", {Rune.SOUL: 1.0})
	var roll: float       = randf()
	var cumulative: float = 0.0
	for rune_key in drops:
		cumulative += drops[rune_key]
		if roll < cumulative:
			return rune_key
	return Rune.SOUL

func add_rune(rune_type: int, amount: int = 1) -> void:
	if rune_type == Rune.ANY:
		return
	runes[rune_type] = runes.get(rune_type, 0) + amount
	mark_dirty()

func can_spin_wheel() -> bool:
	return lifetime_coins >= 100

func spin_wheel() -> Dictionary:
	if not can_spin_wheel():
		return {}
	lifetime_coins -= 100
	coins          -= 100
	var total_weight: int = 0
	for reward in GameData.WHEEL_REWARDS:
		total_weight += reward["weight"]
	var roll: int       = randi() % total_weight
	var cumulative: int = 0
	for reward in GameData.WHEEL_REWARDS:
		cumulative += reward["weight"]
		if roll < cumulative:
			if reward["type"] == "coins":
				lifetime_coins += reward["amount"]
				coins          += reward["amount"]
			elif reward["type"] == "rune":
				add_rune(reward["rune"], reward["amount"])
			save()
			return reward
	save()
	return GameData.WHEEL_REWARDS[0]

func set_circle_rune(char_index: int, rune: int) -> void:
	if char_index >= 0 and char_index < character_circle_rune.size():
		character_circle_rune[char_index] = rune
		save()

func remove_circle_rune(char_index: int) -> bool:
	if coins < 10:
		return false
	coins          -= 10
	lifetime_coins -= 10
	if char_index >= 0 and char_index < character_circle_rune.size():
		character_circle_rune[char_index] = Rune.SOUL
	save()
	return true

func get_circle_rune_color(char_index: int) -> Color:
	if char_index < 0 or char_index >= character_circle_rune.size():
		return Color.WHITE
	var rune: int = character_circle_rune[char_index]
	var rune_colors: Dictionary = {
		Rune.FIRE:  Color(1.0, 0.3, 0.0, 1.0),
		Rune.WIND:  Color(0.5, 1.0, 1.0, 1.0),
		Rune.SOUL:  Color(0.7, 0.3, 1.0, 1.0),
		Rune.BLOOD: Color(0.9, 0.0, 0.1, 1.0),
		Rune.EARTH: Color(0.3, 0.7, 0.2, 1.0),
	}
	return rune_colors.get(rune, Color.WHITE)

func get_character_upgrades(index: int) -> Array:
	if index < 0 or index >= GameData.CHARACTERS.size():
		return []
	var rune_used: int = character_rune_used[index] \
						 if index < character_rune_used.size() \
						 else Rune.SOUL
	return GameData.RUNE_UPGRADES.get(rune_used, GameData.RUNE_UPGRADES[Rune.SOUL])

func can_upgrade_character(index: int, rune_type: int) -> bool:
	if index < 0 or index >= GameData.CHARACTERS.size():
		return false
	var level: int      = character_upgrade_levels[index]
	var upgrades: Array = GameData.RUNE_UPGRADES.get(rune_type, [])
	var next_level: int = level + 1
	if next_level >= upgrades.size():
		return false
	var upgrade: Dictionary = upgrades[next_level]
	return runes.get(rune_type, 0) >= upgrade["rune_cost"] and coins >= upgrade["soul_cost"]

func upgrade_character(index: int, rune_type: int) -> bool:
	if not can_upgrade_character(index, rune_type):
		return false
	var level: int      = character_upgrade_levels[index]
	var upgrades: Array = GameData.RUNE_UPGRADES.get(rune_type, [])
	var next_level: int = level + 1
	var upgrade: Dictionary = upgrades[next_level]
	runes[rune_type]               -= upgrade["rune_cost"]
	coins                          -= upgrade["soul_cost"]
	lifetime_coins                 -= upgrade["soul_cost"]
	character_upgrade_levels[index] = next_level
	character_rune_used[index]      = rune_type
	save()
	return true

func reset_character_tier(index: int) -> bool:
	if coins < 100:
		return false
	if character_upgrade_levels[index] <= 0:
		return false
	coins                           -= 100
	lifetime_coins                  -= 100
	character_upgrade_levels[index] -= 1
	save()
	return true

func get_character_stats(index: int) -> Dictionary:
	if index < 0 or index >= GameData.CHARACTERS.size():
		return {}
	var data: Dictionary = GameData.CHARACTERS[index]
	var level: int       = character_upgrade_levels[index]
	var rune_used: int   = character_rune_used[index] \
						   if index < character_rune_used.size() else Rune.SOUL
	var upgrades: Array  = GameData.RUNE_UPGRADES.get(rune_used, GameData.RUNE_UPGRADES[Rune.SOUL])

	var move_speed: float = data["base_move_speed"]
	var jump_speed: float = data["base_jump_speed"]
	var gravity: float    = data["base_gravity"]
	var jump_boost: float = data["base_jump_boost"]
	var attack: float     = data["base_attack"]

	for i in range(1, level + 1):
		if i < upgrades.size():
			var u: Dictionary = upgrades[i]
			move_speed += u["move_speed"]
			jump_speed += u["jump_speed"]
			gravity    += u["gravity"]
			jump_boost += u["jump_boost"]
			attack     += u["attack"]

	var tint       := Color.WHITE
	var rune_colors = data.get("rune_colors", {})
	if rune_colors.size() > 0:
		tint = rune_colors.get(rune_used, Color.WHITE)

	return {
		"move_speed":        move_speed,
		"jump_speed":        jump_speed,
		"gravity":           gravity,
		"jump_boost":        jump_boost,
		"attack":            attack,
		"level":             level,
		"max_level":         GameData.RUNE_UPGRADES[Rune.SOUL].size() - 1,
		"tint":              tint,
		"circle_rune_color": get_circle_rune_color(index),
	}

# returns stats with display multipliers applied for UI only
# never use this for actual gameplay
func get_character_stats_display(index: int) -> Dictionary:
	var real: Dictionary = get_character_stats(index)
	if real.is_empty():
		return real
	var d: Dictionary = real.duplicate()
	d["move_speed"] = real["move_speed"] * DISPLAY_MULTIPLIERS["move_speed"]
	d["jump_speed"] = real["jump_speed"] * DISPLAY_MULTIPLIERS["jump_speed"]
	d["jump_boost"] = real["jump_boost"] * DISPLAY_MULTIPLIERS["jump_boost"]
	d["attack"]     = real["attack"]     * DISPLAY_MULTIPLIERS["attack"]
	return d

# returns a single upgrade level values inflated for display only
func get_upgrade_display_values(rune_type: int, level_index: int) -> Dictionary:
	var upgrades: Array = GameData.RUNE_UPGRADES.get(rune_type, [])
	if level_index >= upgrades.size():
		return {}
	var real: Dictionary = upgrades[level_index]
	return {
		"rune_cost":  real.get("rune_cost",  0),
		"soul_cost":  real.get("soul_cost",  0),
		"move_speed": real.get("move_speed", 0.0) * DISPLAY_MULTIPLIERS["move_speed"],
		"jump_speed": real.get("jump_speed", 0.0) * DISPLAY_MULTIPLIERS["jump_speed"],
		"jump_boost": real.get("jump_boost", 0.0) * DISPLAY_MULTIPLIERS["jump_boost"],
		"attack":     real.get("attack",     0.0) * DISPLAY_MULTIPLIERS["attack"],
	}

# ── Saving ──────────────────────────────────────────────────────────────────
# Saves are a ConfigFile (key = value text). Missing keys fall back to the
# defaults, so adding a new field never wipes anyone's progress — no more
# bumping SAVE_VERSION. SAVE_VERSION is kept only so a future change of
# meaning can be migrated in _migrate().
#
# Writes are crash-safe: write to .tmp, move the old file to .bak, then rename
# .tmp into place. If the app dies mid-write, the last good file still loads.
#
# During a run, call mark_dirty() instead of save(); the data is written on
# game over / pause / menu, and when Android sends the app to the background.

const _TMP_PATH:    String = SAVE_PATH + ".tmp"
const _BAK_PATH:    String = SAVE_PATH + ".bak"
const _LEGACY_PATH: String = "user://gamestate.dat"   # old binary format (v12)
const _LEGACY_VERSION: int = 12

var _dirty: bool = false

func mark_dirty() -> void:
	_dirty = true

# Writes only if something changed since the last save.
func flush() -> void:
	if _dirty:
		save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)

	cfg.set_value("player", "selected_character",          selected_character)
	cfg.set_value("player", "current_game_mode",           current_game_mode)
	cfg.set_value("player", "endless_unlocked",            endless_unlocked)
	cfg.set_value("player", "lifetime_coins",              lifetime_coins)
	cfg.set_value("player", "coins",                       coins)
	cfg.set_value("player", "best_score",                  best_score)
	cfg.set_value("player", "selected_background",         selected_background)
	cfg.set_value("player", "tutorial_shown",              tutorial_shown)
	cfg.set_value("player", "buttons_visible",             buttons_visible)
	cfg.set_value("player", "first_character_choice_done", first_character_choice_done)

	cfg.set_value("unlocks", "characters",  unlocked_characters)
	cfg.set_value("unlocks", "backgrounds", unlocked_backgrounds)

	cfg.set_value("runes", "inventory", runes)

	cfg.set_value("characters", "circle_rune",    character_circle_rune)
	cfg.set_value("characters", "rune_used",      character_rune_used)
	cfg.set_value("characters", "upgrade_levels", character_upgrade_levels)
	cfg.set_value("characters", "progression",    progression)

	if cfg.save(_TMP_PATH) != OK:
		push_warning("GameState: could not write save file")
		return
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(_BAK_PATH):
			DirAccess.remove_absolute(_BAK_PATH)
		DirAccess.rename_absolute(SAVE_PATH, _BAK_PATH)
	if DirAccess.rename_absolute(_TMP_PATH, SAVE_PATH) != OK:
		push_warning("GameState: could not finalise save file")
		return
	_dirty = false

func load_data() -> void:
	_reset_to_defaults()

	var cfg := ConfigFile.new()
	var loaded: bool = false
	for path in [SAVE_PATH, _BAK_PATH, _TMP_PATH]:
		if FileAccess.file_exists(path) and cfg.load(path) == OK:
			loaded = true
			break

	if not loaded:
		# First launch on the new format: bring over a tester's old binary save.
		if FileAccess.file_exists(_LEGACY_PATH) and _load_legacy_v12():
			save()
			DirAccess.rename_absolute(_LEGACY_PATH, _LEGACY_PATH + ".migrated")
		else:
			save()
		return

	var version: int = int(cfg.get_value("meta", "version", SAVE_VERSION))
	_migrate(cfg, version)

	selected_character          = int(cfg.get_value("player", "selected_character", selected_character))
	current_game_mode           = int(cfg.get_value("player", "current_game_mode", current_game_mode))
	endless_unlocked            = bool(cfg.get_value("player", "endless_unlocked", endless_unlocked))
	lifetime_coins              = int(cfg.get_value("player", "lifetime_coins", lifetime_coins))
	coins                       = int(cfg.get_value("player", "coins", coins))
	best_score                  = int(cfg.get_value("player", "best_score", best_score))
	selected_background         = int(cfg.get_value("player", "selected_background", selected_background))
	tutorial_shown              = bool(cfg.get_value("player", "tutorial_shown", tutorial_shown))
	buttons_visible             = bool(cfg.get_value("player", "buttons_visible", buttons_visible))
	first_character_choice_done = bool(cfg.get_value("player", "first_character_choice_done", first_character_choice_done))

	unlocked_characters      = _merge_array(cfg.get_value("unlocks", "characters", []),  unlocked_characters)
	unlocked_backgrounds     = _merge_array(cfg.get_value("unlocks", "backgrounds", []), unlocked_backgrounds)
	character_circle_rune    = _merge_array(cfg.get_value("characters", "circle_rune", []),    character_circle_rune)
	character_rune_used      = _merge_array(cfg.get_value("characters", "rune_used", []),      character_rune_used)
	character_upgrade_levels = _merge_array(cfg.get_value("characters", "upgrade_levels", []), character_upgrade_levels)

	var saved_prog = cfg.get_value("characters", "progression", [])
	if saved_prog is Array:
		for i in range(mini(saved_prog.size(), progression.size())):
			if saved_prog[i] is Dictionary:
				progression[i].merge(saved_prog[i], true)

	var saved_runes = cfg.get_value("runes", "inventory", {})
	if saved_runes is Dictionary:
		for k in runes.keys():
			runes[k] = int(saved_runes.get(k, runes[k]))

	_sanitize()

# Placeholder for future format changes, e.g.
#   if version < 14: cfg.set_value("player", "new_key", something_derived)
func _migrate(_cfg: ConfigFile, _from_version: int) -> void:
	pass

# Takes saved values where present, keeps the default for anything missing
# (e.g. a character added after the save was made).
func _merge_array(saved, defaults: Array) -> Array:
	var out: Array = defaults.duplicate(true)
	if saved is Array:
		for i in range(mini(saved.size(), out.size())):
			if typeof(saved[i]) == typeof(out[i]):
				out[i] = saved[i]
	return out

# Clamp anything that could crash the game if the file was edited or damaged.
func _sanitize() -> void:
	var n_chars: int = GameData.CHARACTERS.size()
	if selected_character < -1 or selected_character >= n_chars:
		selected_character = 0
	if selected_background < 0 or selected_background >= GameData.BACKGROUNDS.size():
		selected_background = 0
	coins          = maxi(coins, 0)
	lifetime_coins = maxi(lifetime_coins, 0)
	var max_level: int = GameData.RUNE_UPGRADES[Rune.SOUL].size() - 1
	for i in range(n_chars):
		character_upgrade_levels[i] = clampi(int(character_upgrade_levels[i]), 0, max_level)
		if not GameData.RUNE_UPGRADES.has(int(character_circle_rune[i])):
			character_circle_rune[i] = Rune.SOUL
		if not GameData.RUNE_UPGRADES.has(int(character_rune_used[i])):
			character_rune_used[i] = Rune.SOUL
	if selected_character >= 0 and not unlocked_characters[selected_character]:
		selected_character = 0
	unlocked_characters[0] = true

# Reads the old binary gamestate.dat (version 12) so testers keep their progress.
func _load_legacy_v12() -> bool:
	var file := FileAccess.open(_LEGACY_PATH, FileAccess.READ)
	if file == null:
		return false
	var version: int = file.get_32()
	if version != _LEGACY_VERSION:
		file.close()
		return false
	var raw_char: int  = file.get_8()
	selected_character = -1 if raw_char >= GameData.CHARACTERS.size() else raw_char
	current_game_mode  = file.get_8()
	endless_unlocked   = file.get_8() == 1
	lifetime_coins     = file.get_32()
	coins              = file.get_32()
	best_score         = file.get_32()

	var raw_bg: int     = file.get_8()
	selected_background = 0 if raw_bg >= GameData.BACKGROUNDS.size() else raw_bg

	tutorial_shown              = file.get_8() == 1
	buttons_visible             = file.get_8() == 1
	first_character_choice_done = file.get_8() == 1

	unlocked_characters.resize(GameData.CHARACTERS.size())
	for i in range(GameData.CHARACTERS.size()):
		unlocked_characters[i] = file.get_8() == 1

	unlocked_backgrounds.resize(GameData.BACKGROUNDS.size())
	for i in range(GameData.BACKGROUNDS.size()):
		unlocked_backgrounds[i] = file.get_8() == 1

	runes[Rune.FIRE]  = file.get_32()
	runes[Rune.WIND]  = file.get_32()
	runes[Rune.SOUL]  = file.get_32()
	runes[Rune.BLOOD] = file.get_32()
	runes[Rune.EARTH] = file.get_32()

	character_circle_rune.resize(GameData.CHARACTERS.size())
	character_rune_used.resize(GameData.CHARACTERS.size())
	character_upgrade_levels.resize(GameData.CHARACTERS.size())
	for i in range(GameData.CHARACTERS.size()):
		character_circle_rune[i]    = file.get_8()
		character_rune_used[i]      = file.get_8()
		character_upgrade_levels[i] = file.get_8()

	progression.resize(GameData.CHARACTERS.size())
	for i in range(GameData.CHARACTERS.size()):
		progression[i] = {
			"checkpoint_meter": file.get_32(),
			"boss_1_defeated":  file.get_8() == 1,
			"boss_2_defeated":  file.get_8() == 1,
		}

	file.close()
	if coins < lifetime_coins:
		coins = lifetime_coins
	_sanitize()
	return true

func _reset_to_defaults() -> void:
	selected_character          = -1
	lifetime_coins              = 0
	coins                       = 0
	best_score                  = 0
	selected_background         = 0
	tutorial_shown              = false
	buttons_visible             = false
	first_character_choice_done = false
	current_game_mode           = GameMode.PROGRESSION
	endless_unlocked            = false

	unlocked_characters  = [false, false, false, false, false]
	unlocked_backgrounds = [true, true, true]

	runes = {
		Rune.FIRE:  0,
		Rune.WIND:  0,
		Rune.SOUL:  0,
		Rune.BLOOD: 0,
		Rune.EARTH: 0,
	}

	character_circle_rune    = []
	character_rune_used      = []
	character_upgrade_levels = []
	progression              = []

	for i in range(GameData.CHARACTERS.size()):
		character_circle_rune.append(Rune.SOUL)
		character_rune_used.append(Rune.SOUL)
		character_upgrade_levels.append(0)
		progression.append({
			"checkpoint_meter": 0,
			"boss_1_defeated":  false,
			"boss_2_defeated":  false,
		})

	unlocked_characters[0]      = true
	first_character_choice_done = true
	selected_character          = 0
