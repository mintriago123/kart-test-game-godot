class_name KartAudioController
extends Node

var kart: Kart
var audio_role: StringName = &"rival"
var engine_player: AudioStreamPlayer
var tires_player: AudioStreamPlayer
var boost_player: AudioStreamPlayer
var event_player: AudioStreamPlayer

func setup(value: Kart, role: StringName = &"player") -> void:
	kart = value
	audio_role = role if role in [&"player", &"rival"] else &"rival"
	if audio_role == &"player":
		engine_player = _make_player(&"Engine", 92.0, 0.32)
		tires_player = _make_player(&"Tires", 210.0, 0.48)
		boost_player = _make_player(&"Engine", 420.0, 0.62)
	else:
		engine_player = _make_player(&"Engine", 118.0, 0.22)
		event_player = _make_player(&"Items", 280.0, 0.18, false)
	kart.mini_turbo_released.connect(_play_mini_turbo)
	kart.presentation_launch_bogged.connect(_play_bog)

func _physics_process(delta: float) -> void:
	if kart == null or engine_player == null: return
	var speed_ratio := clampf(kart.get_horizontal_speed() / maxf(kart.stats.max_speed, 0.1), 0.0, 1.2)
	var load := clampf(kart.get_throttle_input() - kart.get_brake_input(), 0.0, 1.0)
	var target_pitch := 0.72 + (load if kart.get_drive_state() == Kart.DriveState.AIR else speed_ratio * 0.72 + load * 0.28)
	if kart.is_launch_bogged(): target_pitch *= 0.68
	engine_player.pitch_scale = move_toward(engine_player.pitch_scale, target_pitch, delta * 2.5)
	engine_player.volume_db = lerpf(engine_player.volume_db, (-25.0 if audio_role == &"rival" else -19.0) + 14.0 * maxf(speed_ratio, load), 1.0 - exp(-5.0 * delta))
	if audio_role != &"player": return
	var slip := kart.get_lateral_speed_ratio()
	var quality := kart.get_drift_quality()
	tires_player.pitch_scale = move_toward(tires_player.pitch_scale, kart.get_surface_audio_pitch() * (0.8 + quality * 0.35), delta * 3.0)
	var surface_gain := linear_to_db(maxf(kart.get_surface_audio_volume(), 0.01))
	tires_player.volume_db = lerpf(tires_player.volume_db, -36.0 + 28.0 * slip * maxf(speed_ratio, 0.2) + surface_gain, 1.0 - exp(-7.0 * delta))
	boost_player.volume_db = lerpf(boost_player.volume_db, -11.0 if kart.is_boost_active() else -48.0, 1.0 - exp(-9.0 * delta))

func _play_mini_turbo(level: int) -> void:
	var player := boost_player if audio_role == &"player" else event_player
	if player == null: return
	player.pitch_scale = [1.12, 1.38, 1.72][clampi(level - 1, 0, 2)]
	player.volume_db = -7.0 if audio_role == &"player" else -22.0

func _play_bog() -> void:
	if engine_player != null:
		engine_player.pitch_scale = 0.48
		engine_player.volume_db = -8.0 if audio_role == &"player" else -24.0

func shutdown() -> void:
	for player in [engine_player, tires_player, boost_player, event_player]:
		if player != null:
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	shutdown()

func _make_player(bus_name: StringName, frequency: float, roughness: float, persistent := true) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.stream = _make_loop(frequency, roughness)
	add_child(player)
	if persistent and AudioServer.get_driver_name() != "Dummy": player.play()
	return player

func _make_loop(frequency: float, roughness: float) -> AudioStreamWAV:
	var rate := 11025
	var count := int(rate * 0.75)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in count:
		var time := float(index) / rate
		var wobble := 1.0 + sin(TAU * 2.3 * time) * 0.012
		var fundamental := sin(TAU * frequency * wobble * time)
		var harmonic := sin(TAU * frequency * 2.01 * time) * 0.24
		var texture := sin(TAU * frequency * 0.51 * time + sin(time * 19.0)) * roughness * 0.24
		data.encode_s16(index * 2, int(clampf((fundamental + harmonic + texture) * 0.16, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream
