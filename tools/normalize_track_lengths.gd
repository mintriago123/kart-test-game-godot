extends SceneTree

const IDS := [&"dunas_doradas", &"pantano_brumoso", &"can_carmes", &"valle_de_otoo", &"baha_pirata", &"caldera_furiosa", &"cumbre_glacial", &"ruinas_esmeralda", &"nen_medianoche"]
const DESCRIPTIONS := [
	"Desierto abierto entre oasis y ruinas, con amplias curvas sobre arena.",
	"Humedal de agua oscura, árboles retorcidos y pasos de tierra entre la bruma.",
	"Rectas rápidas y horquillas elevadas entre barrancos rojizos.",
	"Un trazado fluido entre campos dorados, robles y flores.",
	"Costa de palmeras, muelles y tesoros, con una escapada por la playa.",
	"Ascensos técnicos sobre roca negra junto a una caldera de lava.",
	"Rasantes exigentes y curvas sobre hielo entre cumbres nevadas.",
	"Una ruta estrecha entre templos y vegetación de selva profunda.",
	"Curvas rápidas encadenadas entre túneles y luces de una ciudad nocturna.",
]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var catalog := load("res://levels/track_catalog.tres") as TrackCatalog
	for index in IDS.size():
		var definition := catalog.get_track(IDS[index])
		var session := TrackEditorSession.new()
		if session.load_track(definition.scene.resource_path) != OK: quit(1); return
		var curve := session.track.get_main_route().curve
		var factor := (820.0 + index * 12.0) / curve.get_baked_length()
		for point_index in curve.point_count:
			var point := curve.get_point_position(point_index)
			point.x *= factor; point.z *= factor
			point.y = maxf(point.y, TrackLevel.MINIMUM_DRIVABLE_HEIGHT)
			curve.set_point_position(point_index, point)
			curve.set_point_in(point_index, curve.get_point_in(point_index) * Vector3(factor, 1, factor))
			curve.set_point_out(point_index, curve.get_point_out(point_index) * Vector3(factor, 1, factor))
		var validation := session.track.validate_track()
		if not validation.is_empty():
			push_error("%s: %s" % [definition.display_name, ", ".join(validation)])
			quit(1)
			return
		var publish_error := session.publish(3, DESCRIPTIONS[index])
		if publish_error != OK:
			push_error("%s: %s" % [definition.display_name, error_string(publish_error)])
			quit(1)
			return
		print("NORMALIZADA: %s %.0f m" % [definition.display_name, curve.get_baked_length()])
	quit()
