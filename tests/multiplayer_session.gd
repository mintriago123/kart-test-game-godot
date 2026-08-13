extends SceneTree

const PROGRESSION: ProgressionCatalog = preload("res://progression/progression_catalog.tres")
const TRACKS: TrackCatalog = preload("res://levels/track_catalog.tres")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for action in [&"steer_left", &"steer_right", &"accelerate", &"brake", &"drift", &"use_item"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_test_catalog_and_modes()
	_test_session_validation()
	_test_input_isolation()
	_test_protocol_and_snapshots()
	_test_multiplayer_telemetry()
	await _test_local_world()
	if failures == 0:
		print("MULTIPLAYER SESSION TESTS PASSED")
	quit(1 if failures else 0)


func _test_catalog_and_modes() -> void:
	_expect([GameModeDefinition.RACE, GameModeDefinition.TIME_TRIAL, GameModeDefinition.CUP, GameModeDefinition.LOCAL_MULTIPLAYER, GameModeDefinition.LAN_MULTIPLAYER] == [0, 1, 2, 3, 4], "Published game-mode values remain compatible and append local/LAN.")
	var android_modes := ModeSelectScreen.available_modes_for_platform(true, false)
	_expect(GameModeDefinition.LAN_MULTIPLAYER in android_modes and GameModeDefinition.LOCAL_MULTIPLAYER not in android_modes, "Android exposes LAN and excludes split-screen multiplayer.")
	var desktop_modes := ModeSelectScreen.available_modes_for_platform(false, false)
	_expect(GameModeDefinition.LAN_MULTIPLAYER in desktop_modes and GameModeDefinition.LOCAL_MULTIPLAYER in desktop_modes, "Desktop exposes both multiplayer modes.")
	var export_config := ConfigFile.new()
	var export_loaded := export_config.load("res://export_presets.cfg") == OK
	_expect(export_loaded and bool(export_config.get_value("preset.0.options", "permissions/internet", false)), "The Android export enables network sockets for ENet and UDP discovery.")
	_expect(PROGRESSION.racers.racers.size() == 8, "The shared catalog contains eight racers.")
	var expected := {
		&"sol": ["f6c945", &"hatchback_sports"],
		&"coco": ["a66a3f", &"kart_oobi"],
		&"perla": ["9b6be8", &"sedan_sports"],
		&"nube": ["69d2e7", &"race"],
	}
	for racer_id in expected:
		var racer := PROGRESSION.racers.get_racer(racer_id)
		_expect(racer != null and racer.body_color.to_html(false) == expected[racer_id][0] and racer.default_kart_visual.id == expected[racer_id][1], "%s matches its color and default vehicle." % racer_id)
	for cup in PROGRESSION.cups.get_valid_cups():
		_expect(cup.opponents.size() == 3 and cup.scoring_table == PackedInt32Array([9, 6, 3, 1]), "%s keeps four racers and 9/6/3/1 scoring." % cup.id)


func _test_session_validation() -> void:
	var quick := RaceSessionConfig.create_default(GameModeDefinition.RACE)
	_expect(quick.participants.size() == 8 and quick.get_local_participants().size() == 1, "Quick race derives an eight-slot participant grid with one local player.")
	var local := _local_session()
	_expect(local.validate().is_empty(), "A keyboard plus a distinct gamepad is a valid local room.")
	local.participants[1].racer = local.participants[0].racer
	local.participants[1].device_id = -1
	local.participants[1].device_type = RaceParticipantConfig.DEVICE_KEYBOARD
	var errors := local.validate()
	var error_text := "\n".join(errors)
	_expect("Duplicate participant racer" in error_text and "Keyboard" in error_text, "Duplicate pilots and keyboard assignments are rejected.")
	var progress := PlayerProgress.new()
	progress.save_path = "/tmp/michikart-cup-participant-test.cfg"
	var cup_manager := CupManager.new(PROGRESSION, progress)
	_expect(cup_manager.start(&"tropical", &"relaxed", &"150", 42), "The first cup can start for participant compatibility testing.")
	var cup_session := cup_manager.create_session()
	cup_session.ensure_participants()
	_expect(cup_session.participants.size() == 4 and cup_session.validate().is_empty(), "Cup sessions remain exactly four participants.")
	DirAccess.remove_absolute(progress.save_path)


func _test_input_isolation() -> void:
	var keyboard := RacerInputSource.new()
	keyboard.device_type = RaceParticipantConfig.DEVICE_KEYBOARD
	var gamepad_zero := RacerInputSource.new()
	gamepad_zero.device_type = RaceParticipantConfig.DEVICE_GAMEPAD
	gamepad_zero.device_id = 0
	var gamepad_one := RacerInputSource.new()
	gamepad_one.device_type = RaceParticipantConfig.DEVICE_GAMEPAD
	gamepad_one.device_id = 1
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	var joy_zero := InputEventJoypadButton.new()
	joy_zero.device = 0
	joy_zero.button_index = JOY_BUTTON_A
	_expect(keyboard.accepts_event(key) and not gamepad_zero.accepts_event(key), "Keyboard bindings are isolated from gamepads.")
	_expect(gamepad_zero.accepts_event(joy_zero) and not gamepad_one.accepts_event(joy_zero), "Gamepad bindings are filtered by physical device id.")
	var remote := RaceParticipantConfig.create(0, PROGRESSION.racers.racers[0], null, RaceParticipantConfig.ControlType.REMOTE, RaceParticipantConfig.DEVICE_NETWORK, -1, 7)
	var source := RacerInputSource.for_participant(remote)
	_expect(source.push_frame(2, {"throttle": 2.0, "steer": -2.0}) and not source.push_frame(1, {}), "Numbered network inputs clamp values and reject late packets.")
	var frame := source.sample()
	_expect(frame.throttle == 1.0 and frame.steer == -1.0, "Network input frames expose sanitized controls.")


func _test_protocol_and_snapshots() -> void:
	var fingerprint := LanProtocol.calculate_catalog_fingerprint(PROGRESSION, TRACKS)
	var valid := {"protocol": 1, "catalog_fingerprint": fingerprint, "racer_id": &"marea", "vehicle_id": &"sedan", "track_id": &"coastal"}
	_expect(LanProtocol.validate_handshake(valid, fingerprint, PROGRESSION, TRACKS).is_empty(), "Compatible LAN handshakes pass before room entry.")
	valid.protocol = 99
	_expect("Versión LAN incompatible" in LanProtocol.validate_handshake(valid, fingerprint, PROGRESSION, TRACKS), "Protocol mismatches return an explicit message.")
	var discovery := LanDiscoveryService.new()
	_expect(discovery.ingest_announcement({"protocol": 1, "room_id": "abc", "name": "Sala"}, "192.168.1.2", 1000), "A compatible discovery announcement is accepted.")
	_expect(discovery.prune_stale(4101) and discovery.get_rooms().is_empty(), "Rooms expire after three seconds without announcements.")
	discovery.free()
	var buffer := LanSnapshotBuffer.new()
	buffer.interpolation_delay_ms = 0
	buffer.push_snapshot({"server_time_ms": 100, "racers": [{"slot_id": 2, "position": Vector3.ZERO, "velocity": Vector3.ZERO, "rotation": Quaternion.IDENTITY}]})
	buffer.push_snapshot({"server_time_ms": 200, "racers": [{"slot_id": 2, "position": Vector3(10, 0, 0), "velocity": Vector3(2, 0, 0), "rotation": Quaternion.IDENTITY}]})
	_expect(is_equal_approx((buffer.sample_racer(2, 150).position as Vector3).x, 5.0), "Rival snapshots interpolate through the 100 ms buffer.")
	var corrected := buffer.reconcile_local({"position": Vector3.ZERO, "rotation": Quaternion.IDENTITY}, {"position": Vector3(1, 0, 0), "rotation": Quaternion.IDENTITY})
	_expect((corrected.position as Vector3).x > 0.0 and (corrected.position as Vector3).x < 1.0, "Local reconciliation applies ordinary corrections gradually.")


func _test_multiplayer_telemetry() -> void:
	var progress := PlayerProgress.new()
	progress.save_path = "/tmp/michikart-multiplayer-statistics.cfg"
	var local_result := _result(GameModeDefinition.LOCAL_MULTIPLAYER, &"local-run", 1)
	_expect(progress.record_race_result(local_result) and not progress.record_race_result(local_result), "Local telemetry is idempotent and records J1 once.")
	_expect(progress.local_multiplayer.races_played == 1 and progress.local_multiplayer.victories == 1 and progress.races_played == 0, "Local multiplayer is separated from solo/cup telemetry.")
	var lan_result := _result(GameModeDefinition.LAN_MULTIPLAYER, &"lan-run", 2)
	progress.record_race_result(lan_result)
	_expect(progress.lan_multiplayer.races_played == 1 and progress.lan_multiplayer.podiums == 1, "LAN records only this PC's player result.")
	DirAccess.remove_absolute(progress.save_path)


func _test_local_world() -> void:
	var session := _local_session()
	session.track = TRACKS.get_default_track()
	session.race_class = RaceClassDefinition.get_by_id(&"100")
	session.game_mode = GameModeDefinition.LOCAL_MULTIPLAYER
	session.race_seed = 17
	var world := RaceWorld.new()
	world.play_intro = false
	world.setup(session)
	root.add_child(world)
	await process_frame
	await process_frame
	_expect(world.race_manager.racers.size() == 8 and world.local_player_karts.size() == 2 and world.human_karts.size() == 2, "Local RaceWorld builds two humans and six AI racers.")
	_expect(world.local_huds.size() == 2 and world.local_cameras.size() == 2 and world._split_viewports.size() == 2, "Each local player owns a camera, minimap and compact HUD.")
	_expect(world._split_viewports.all(func(viewport: SubViewport) -> bool: return viewport.world_3d == world.get_viewport().world_3d), "Both horizontal viewports share the race World3D.")
	_expect(world.player_kart == world.local_player_karts[0] and world.race_manager.player_kart == world.player_kart, "Legacy player_kart aliases J1.")
	world.shutdown()
	world.queue_free()
	await process_frame
	var itemless := _local_session()
	itemless.track = TRACKS.get_default_track()
	itemless.race_class = RaceClassDefinition.get_by_id(&"100")
	itemless.items_enabled = false
	var itemless_world := RaceWorld.new()
	itemless_world.play_intro = false
	itemless_world.setup(itemless)
	root.add_child(itemless_world)
	await process_frame
	_expect(itemless_world._item_executor == null and itemless_world._item_boxes.is_empty(), "A host session with items disabled creates no item authority or boxes.")
	itemless_world.shutdown()
	itemless_world.queue_free()
	await process_frame


func _local_session() -> RaceSessionConfig:
	var session := RaceSessionConfig.new()
	session.game_mode = GameModeDefinition.LOCAL_MULTIPLAYER
	session.grid_size = 8
	var participants: Array[RaceParticipantConfig] = [
		RaceParticipantConfig.create(0, PROGRESSION.racers.get_racer(&"marea"), PROGRESSION.unlocks.get_variant(&"sedan"), RaceParticipantConfig.ControlType.LOCAL, RaceParticipantConfig.DEVICE_KEYBOARD, -1),
		RaceParticipantConfig.create(1, PROGRESSION.racers.get_racer(&"lima"), PROGRESSION.unlocks.get_variant(&"sedan"), RaceParticipantConfig.ControlType.LOCAL, RaceParticipantConfig.DEVICE_GAMEPAD, 0),
	]
	for racer in PROGRESSION.racers.racers:
		if participants.size() >= 8:
			break
		if racer.id in [&"marea", &"lima"]:
			continue
		participants.append(RaceParticipantConfig.create(participants.size(), racer, racer.default_kart_visual))
	session.set_participants(participants)
	return session


func _result(mode: int, run_id: StringName, position: int) -> RaceResult:
	var row := RacerRaceResult.new()
	row.racer_id = &"marea"
	row.racer_name = "Marea"
	row.is_player = true
	row.finish_position = position
	row.start_position = 4
	row.finish_time = 65.0
	row.best_lap_time = 20.0
	row.items_collected = 3
	row.items_used = 2
	row.shortcuts_used = 1
	row.recoveries = 1
	var result := RaceResult.new()
	result.game_mode = mode
	result.run_id = run_id
	result.player_result = row
	result.player_results = [row]
	result.standings = [row]
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
