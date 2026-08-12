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
var _sfx_player: AudioStreamPlayer
var _is_shutdown := false


func _ready() -> void:
	_is_shutdown = false
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -11.0
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -5.0
	add_child(_sfx_player)


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if _is_shutdown:
		return
	_is_shutdown = true
	_release_player(_music_player)
	_release_player(_sfx_player)
	_music_player = null
	_sfx_player = null


func start_music() -> void:
	if _is_shutdown or _music_player == null or _music_player.playing:
		return
	_music_player.stream = _create_music_loop()
	if _can_play_audio():
		_music_player.play()


func play_countdown(text: String) -> void:
	if text in ["3", "2", "1"]:
		_play_tone(440.0 + float(text.to_int()) * 55.0, 0.09, 0.28)
	elif text == "¡YA!":
		_play_tone(880.0, 0.22, 0.34)


func play_pickup() -> void:
	_play_tone(1046.5, 0.14, 0.28)


func play_hit() -> void:
	_play_tone(145.0, 0.24, 0.35)


func play_projectile_bounce(bounce_count: int) -> void:
	var frequency := 310.0 + minf(float(bounce_count), 3.0) * 55.0
	_play_tone(frequency, 0.08, 0.26)


func play_item_activation() -> void:
	_play_stream(ITEM_ACTIVATION_SOUND)


func play_shield_block() -> void:
	_play_stream(ITEM_BLOCK_SOUND)


func play_item_deploy() -> void:
	_play_stream(ITEM_DEPLOY_SOUND)


func play_item_launch() -> void:
	_play_stream(ITEM_LAUNCH_SOUND)


func play_item_impact() -> void:
	_play_stream(ITEM_IMPACT_SOUND)


func play_finish() -> void:
	_play_tone(783.99, 0.48, 0.35)


func _play_stream(stream: AudioStream) -> void:
	if _is_shutdown or _sfx_player == null:
		return
	_sfx_player.stream = stream
	if _can_play_audio():
		_sfx_player.play()


func _play_tone(frequency: float, duration: float, volume: float) -> void:
	if _is_shutdown or _sfx_player == null:
		return
	_sfx_player.stream = _create_tone(frequency, duration, volume)
	if _can_play_audio():
		_sfx_player.play()


func _release_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.stop()
	player.stream = null
	player.queue_free()


func _can_play_audio() -> bool:
	return AudioServer.get_driver_name() != "Dummy"


func _create_music_loop() -> AudioStreamWAV:
	var duration := 8.0
	var sample_count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var melody := [261.63, 329.63, 392.0, 523.25, 392.0, 329.63, 293.66, 392.0]
	for sample_index in sample_count:
		var time := float(sample_index) / SAMPLE_RATE
		var beat := int(time / 0.5) % melody.size()
		var beat_time := fmod(time, 0.5)
		var envelope := minf(beat_time * 18.0, 1.0) * exp(-beat_time * 2.2)
		var melody_sample := sin(TAU * melody[beat] * time) * envelope * 0.18
		var bass_frequency: float = melody[beat] * 0.5
		var bass_sample := sin(TAU * bass_frequency * time) * 0.09
		var percussion := 0.0
		if beat_time < 0.035:
			percussion = sin(TAU * 92.0 * time) * (1.0 - beat_time / 0.035) * 0.13
		var sample := clampf(melody_sample + bass_sample + percussion, -1.0, 1.0)
		data.encode_s16(sample_index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


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
