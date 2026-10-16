extends Node

const SAVE_PATH: String = "user://sound.dat"

var master_volume: float = 1.0
var music_enabled: bool = true
var sfx_enabled: bool = true

var music_player: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()
var _music_playlist: Array = []
var _current_music_index: int = -1

var _sfx_coin: AudioStream
var _sfx_jump: AudioStream
var _sfx_hit_bird: AudioStream
var _sfx_wing_flap: AudioStream
var _sfx_click_button: AudioStream
var _sfx_buy_background: AudioStream
var _sfx_buy_character: AudioStream
var _sfx_game_over: AudioStream
var _sfx_spell_fire: AudioStream
var _sfx_bolt_bird_hit: AudioStream
var _sfx_landing: AudioStream


var _flap_player: AudioStreamPlayer = null
var _flap_cooldown: float = 0.0
var _flap_is_playing: bool = false
const FLAP_COOLDOWN: float = 3.0
const MUSIC_START_MAX_PERCENT: float = 0.7

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_load_settings()
	_setup_music_player()
	_setup_audio_buses()
	_apply_volume()
	_apply_sfx_bus()
	_load_sounds()
	_load_music_playlist()
	play_random_music()

func _process(delta: float) -> void:
	if _flap_cooldown > 0.0:
		_flap_cooldown -= delta

	if _flap_is_playing and is_instance_valid(_flap_player):
		if not _flap_player.playing:
			_flap_is_playing = false
			_flap_cooldown = FLAP_COOLDOWN

	if music_enabled and is_instance_valid(music_player):
		if not music_player.playing and _music_playlist.size() > 0:
			play_random_music()

func _setup_audio_buses() -> void:
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		AudioServer.add_bus()
		var new_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(new_idx, "SFX")
		AudioServer.set_bus_send(new_idx, "Master")

	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx == -1:
		AudioServer.add_bus()
		var new_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(new_idx, "Music")
		AudioServer.set_bus_send(new_idx, "Master")

func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.autoplay = false
	add_child(music_player)

func _load_music_playlist() -> void:
	_music_playlist.clear()

	var music_paths := [
		"res://assets/music/blesksound-night-walks-276741.ogg",
		"res://assets/music/crab_audio-night-work-381486.ogg",
		"res://assets/music/gearfive-whispers-of-the-night-226985.ogg",
		"res://assets/music/nojisuma-night-cherry-blossoms-9536.ogg",
		"res://assets/music/nojisuma-night-sky-116765.ogg",
		"res://assets/music/tomomi_kato-holy-night-11014.ogg",
		"res://assets/music/z8phyr-in-violet-skies-115621_compressed.ogg"
	]

	for path in music_paths:
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream != null:
				_music_playlist.append(stream)
		else:
			push_warning("SoundManager: Music not found at " + path)

	_music_playlist.shuffle()

func _load_sounds() -> void:
	_sfx_coin           = _load_sound("res://assets/sounds/coin.wav")
	_sfx_jump           = _load_sound("res://assets/sounds/Jump.wav")
	_sfx_landing        = _load_sound("res://assets/sounds/Landing.wav")
	_sfx_hit_bird       = _load_sound("res://assets/sounds/Hitting bird.wav")
	_sfx_wing_flap      = _load_sound("res://assets/sounds/wing flap.wav")
	_sfx_click_button   = _load_sound("res://assets/sounds/Click_button.wav")
	_sfx_buy_background = _load_sound("res://assets/sounds/Buy_backgroun.wav")
	_sfx_buy_character  = _load_sound("res://assets/sounds/Buy_character.wav")
	_sfx_game_over      = _load_sound("res://assets/sounds/Gameover (2).ogg")
	_sfx_spell_fire     = _load_sound("res://assets/sounds/Spellboltfirewav.wav")
	_sfx_bolt_bird_hit  = _load_sound("res://assets/sounds/bird_hit.wav")


func _load_sound(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("SoundManager: Sound not found at " + path)
	return null

func _apply_sfx_bus() -> void:
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_mute(sfx_idx, not sfx_enabled)

func _stop_all_sfx() -> void:
	if is_instance_valid(_flap_player) and _flap_player.playing:
		_flap_player.stop()
	_flap_is_playing = false
	_flap_cooldown = 0.0
	for child in get_children():
		if child is AudioStreamPlayer and child != music_player and child != _flap_player:
			if child.bus == "SFX":
				child.stop()
				child.queue_free()

func _stop_all_scene_sfx() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("sfx_players"):
		if node is AudioStreamPlayer and node.playing:
			node.stop()
		elif node is AudioStreamPlayer2D and node.playing:
			node.stop()
	_mute_sfx_in_tree(tree.root)

func _mute_sfx_in_tree(node: Node) -> void:
	if node == self:
		return
	if node is AudioStreamPlayer:
		if node.bus == "SFX" and node.playing:
			node.stop()
	elif node is AudioStreamPlayer2D:
		if node.bus == "SFX" and node.playing:
			node.stop()
	elif node is AudioStreamPlayer3D:
		if node.bus == "SFX" and node.playing:
			node.stop()
	for child in node.get_children():
		_mute_sfx_in_tree(child)

func _get_random_start_time(stream: AudioStream) -> float:
	if stream == null:
		return 0.0
	var length := stream.get_length()
	if length <= 0.0:
		return 0.0
	return _rng.randf_range(0.0, length * MUSIC_START_MAX_PERCENT)

func play_random_music() -> void:
	if not music_enabled:
		return
	if _music_playlist.is_empty():
		return
	var next_index := _rng.randi_range(0, _music_playlist.size() - 1)
	if _music_playlist.size() > 1:
		while next_index == _current_music_index:
			next_index = _rng.randi_range(0, _music_playlist.size() - 1)
	_current_music_index = next_index
	var stream: AudioStream = _music_playlist[_current_music_index]
	music_player.stream = stream
	music_player.volume_db = linear_to_db(master_volume)
	music_player.play(_get_random_start_time(stream))

func play_music(stream: AudioStream) -> void:
	if not music_enabled or stream == null:
		return
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.play(_get_random_start_time(stream))

func stop_music() -> void:
	if music_player:
		music_player.stop()

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	if not music_enabled:
		stop_music()
	elif not music_player.playing:
		play_random_music()
	_save_settings()

func play_sfx(stream: AudioStream) -> void:
	if not sfx_enabled or stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = linear_to_db(master_volume)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_coin() -> void:
	play_sfx(_sfx_coin)

func play_jump() -> void:
	play_sfx(_sfx_jump)

func play_landing() -> void:
	play_sfx(_sfx_landing)

func play_hit_bird() -> void:
	play_sfx(_sfx_hit_bird)

func play_wing_flap() -> void:
	play_sfx(_sfx_wing_flap)

func play_click() -> void:
	play_sfx(_sfx_click_button)

func play_buy_background() -> void:
	play_sfx(_sfx_buy_background)

func play_buy_character() -> void:
	play_sfx(_sfx_buy_character)

func play_game_over() -> void:
	play_sfx(_sfx_game_over)

func play_spell_fire() -> void:
	play_sfx(_sfx_spell_fire)

func play_bolt_bird_hit() -> void:
	play_sfx(_sfx_bolt_bird_hit)



func can_play_flap() -> bool:
	if not sfx_enabled:
		return false
	if _flap_is_playing:
		return false
	if _flap_cooldown > 0.0:
		return false
	return true

func play_bird_flap() -> bool:
	if not can_play_flap():
		return false
	if _sfx_wing_flap == null:
		return false
	if not is_instance_valid(_flap_player):
		_flap_player = AudioStreamPlayer.new()
		_flap_player.bus = "SFX"
		add_child(_flap_player)
	_flap_player.stream = _sfx_wing_flap
	_flap_player.volume_db = linear_to_db(master_volume * 0.5)
	_flap_player.play()
	_flap_is_playing = true
	return true

func stop_bird_flap() -> void:
	if is_instance_valid(_flap_player) and _flap_player.playing:
		_flap_player.stop()
	_flap_is_playing = false
	_flap_cooldown = 0.0

func set_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_settings()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(master_volume)
	)
	if is_instance_valid(music_player):
		music_player.volume_db = linear_to_db(master_volume)

func _save_settings() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_float(master_volume)
		f.store_8(1 if music_enabled else 0)
		f.store_8(1 if sfx_enabled else 0)
		f.close()

func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		master_volume = 1.0
		music_enabled = true
		sfx_enabled = true
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		master_volume = f.get_float()
		music_enabled = f.get_8() == 1
		sfx_enabled = f.get_8() == 1
		f.close()

func set_sfx_enabled(value: bool) -> void:
	sfx_enabled = value
	_apply_sfx_bus()
	if not sfx_enabled:
		_stop_all_sfx()
		_stop_all_scene_sfx()
	_save_settings()
