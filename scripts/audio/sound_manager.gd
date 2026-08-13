class_name SoundManager
extends Node

const SAMPLE_RATE := 22050
const ITEM_ACTIVATION_SOUND: AudioStream = preload(
	"res://assets/vendor/kenney/digital-audio/powerUp2.ogg"
)
const ITEM_DEPLOY_SOUND: AudioStream = preload(
	"res://assets/vendor/kenney/digital-audio/lowDown.ogg"
)
const ITEM_LAUNCH_SOUND: AudioStream = preload(
	"res://assets/vendor/kenney/digital-audio/laser3.ogg"
)
const ITEM_BLOCK_SOUND: AudioStream = preload(
	"res://assets/vendor/kenney/impact-sounds/impactGlass_light_000.ogg"
)
const ITEM_IMPACT_SOUND: AudioStream = preload(
	"res://assets/vendor/kenney/impact-sounds/impactSoft_heavy_000.ogg"
)

var _music_player: AudioStreamPlayer
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index := 0
var _music_tween: Tween
var music_catalog := MusicCatalog.new()
var _sfx_player: AudioStreamPlayer # Compatibility alias for the most recently used pooled player.
var _pools: Dictionary = {}
var _pool_cursor: Dictionary = {}
var _is_shutdown := false

const POOL_SIZES := {"UI": 4, "Impacts": 6, "Items": 6}


func _ready() -> void:
	_is_shutdown = false
	_ensure_buses()
	for index in 2:
		var music_player := AudioStreamPlayer.new()
		music_player.name = "MusicPlayer%d" % (index + 1)
		music_player.bus = &"Music"
		music_player.volume_db = -11.0 if index == 0 else -80.0
		add_child(music_player)
		_music_players.append(music_player)
	_music_player = _music_players[0]
	for bus_name in POOL_SIZES:
		var players: Array[AudioStreamPlayer] = []
		for _index in int(POOL_SIZES[bus_name]):
			var player := AudioStreamPlayer.new()
			player.bus = StringName(bus_name)
			player.volume_db = -5.0
			add_child(player)
			players.append(player)
		_pools[bus_name] = players
		_pool_cursor[bus_name] = 0
	var ui_players: Array = _pools["UI"]
	_sfx_player = ui_players[0] as AudioStreamPlayer

func _ensure_buses() -> void:
	for bus_name in [&"Music", &"Engine", &"Tires", &"Impacts", &"Items", &"UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if _is_shutdown:
		return
	_is_shutdown = true
	if _music_tween != null: _music_tween.kill()
	for player in _music_players: _release_player(player)
	_music_players.clear()
	for players in _pools.values():
		for player in players:
			_release_player(player as AudioStreamPlayer)
	_pools.clear()
	_pool_cursor.clear()
	_music_player = null
	_sfx_player = null


func start_music() -> void:
	play_menu_music()

func play_menu_music() -> void:
	_crossfade_to(music_catalog.menu_theme, true)

func play_track_music(track_id: StringName, configured_stream: AudioStream = null) -> void:
	var stream := configured_stream
	if stream == null:
		stream = music_catalog.get_track_theme(track_id)
	if stream == null:
		push_warning("No music configured for track %s." % track_id)
		stop_music()
		return
	_crossfade_to(stream, true)

func play_cup_victory() -> void:
	_crossfade_to(music_catalog.cup_victory_sting, false)

func stop_music(fade_out := true) -> void:
	if _is_shutdown: return
	if _music_tween != null: _music_tween.kill()
	if not fade_out:
		for player in _music_players:
			player.stop(); player.stream = null
		return
	_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for player in _music_players:
		_music_tween.parallel().tween_property(player, "volume_db", -80.0, 0.25)
	_music_tween.finished.connect(func():
		for player in _music_players:
			player.stop(); player.stream = null
	)

func _crossfade_to(stream: AudioStream, should_loop: bool) -> void:
	if _is_shutdown or stream == null or _music_players.is_empty(): return
	var current := _music_players[_active_music_index]
	if current.stream == stream and current.playing: return
	var next_index := 1 - _active_music_index
	var incoming := _music_players[next_index]
	if _music_tween != null: _music_tween.kill()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = should_loop
	incoming.stop(); incoming.stream = stream; incoming.volume_db = -80.0
	if _can_play_audio(): incoming.play()
	_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tween.parallel().tween_property(current, "volume_db", -80.0, 0.25)
	_music_tween.parallel().tween_property(incoming, "volume_db", -11.0, 0.25)
	_music_tween.finished.connect(func(): current.stop(); current.stream = null)
	_active_music_index = next_index
	_music_player = incoming


func play_countdown(text: String) -> void:
	if text in ["3", "2", "1"]:
		_play_tone(440.0 + float(text.to_int()) * 55.0, 0.09, 0.28)
	elif text == "¡YA!":
		_play_tone(880.0, 0.22, 0.34)


func play_pickup() -> void:
	_play_tone(1046.5, 0.14, 0.28)


func play_hit() -> void:
	_play_tone(145.0, 0.24, 0.35, "Impacts")


func play_projectile_bounce(bounce_count: int) -> void:
	var frequency := 310.0 + minf(float(bounce_count), 3.0) * 55.0
	_play_tone(frequency, 0.08, 0.26)


func play_item_activation() -> void:
	_play_stream(ITEM_ACTIVATION_SOUND, "Items")


func play_shield_block() -> void:
	_play_stream(ITEM_BLOCK_SOUND, "Impacts")


func play_item_deploy() -> void:
	_play_stream(ITEM_DEPLOY_SOUND, "Items")


func play_item_launch() -> void:
	_play_stream(ITEM_LAUNCH_SOUND, "Items")


func play_item_impact() -> void:
	_play_stream(ITEM_IMPACT_SOUND, "Impacts")


func play_finish() -> void:
	_play_tone(783.99, 0.48, 0.35)

func play_ui_navigate() -> void:
	_play_tone(520.0, 0.045, 0.12)

func play_ui_confirm() -> void:
	_play_tone(760.0, 0.075, 0.18)

func play_ui_cancel() -> void:
	_play_tone(330.0, 0.08, 0.16)

func play_ui_error() -> void:
	_play_tone(170.0, 0.13, 0.20)

func play_ui_reward() -> void:
	_play_tone(1046.5, 0.28, 0.24)


func _play_stream(stream: AudioStream, bus_name := "UI") -> void:
	var player := _acquire_player(bus_name)
	if player == null:
		return
	player.stream = stream
	if _can_play_audio():
		player.play()


func _play_tone(frequency: float, duration: float, volume: float, bus_name := "UI") -> void:
	var player := _acquire_player(bus_name)
	if player == null:
		return
	player.stream = _create_tone(frequency, duration, volume)
	if _can_play_audio():
		player.play()

func _acquire_player(bus_name: String) -> AudioStreamPlayer:
	if _is_shutdown or not _pools.has(bus_name):
		return null
	var players: Array = _pools[bus_name]
	for raw_player in players:
		var player := raw_player as AudioStreamPlayer
		if not player.playing:
			_sfx_player = player
			return player
	var cursor := int(_pool_cursor[bus_name]) % players.size()
	_pool_cursor[bus_name] = cursor + 1
	_sfx_player = players[cursor] as AudioStreamPlayer
	return _sfx_player


func _release_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.stop()
	player.stream = null
	player.queue_free()


func _can_play_audio() -> bool:
	return AudioServer.get_driver_name() != "Dummy"


func _create_tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in sample_count:
		var time := float(sample_index) / SAMPLE_RATE
		var envelope := sin(PI * float(sample_index) / sample_count)
		var sample := sin(TAU * frequency * time) * envelope * volume
		data.encode_s16(sample_index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
