extends SceneTree

# Production authoring utility: uses the same TrackEditorSession create/save/publish
# pipeline as the Pistas tab. It is intentionally repeatable for catalog rebuilds.
const TRACKS := [
	["Dunas Doradas", "Desierto abierto entre oasis y ruinas, con amplias curvas sobre arena.", "desert", "Media", 0],
	["Pantano Brumoso", "Humedal de agua oscura, árboles retorcidos y pasos de tierra entre la bruma.", "swamp", "Media", 1],
	["Cañón Carmesí", "Rectas rápidas y horquillas elevadas entre barrancos rojizos.", "canyon", "Media", 2],
	["Valle de Otoño", "Un trazado fluido entre campos dorados, robles y flores.", "autumn", "Media", 1],
	["Bahía Pirata", "Costa de palmeras, muelles y tesoros, con una escapada por la playa.", "pirate", "Media", 0],
	["Caldera Furiosa", "Ascensos técnicos sobre roca negra junto a una caldera de lava.", "volcano", "Difícil", 2],
	["Cumbre Glacial", "Rasantes exigentes y curvas sobre hielo entre cumbres nevadas.", "glacier", "Difícil", 1],
	["Ruinas Esmeralda", "Una ruta estrecha entre templos y vegetación de selva profunda.", "jungle", "Difícil", 0],
	["Neón Medianoche", "Curvas rápidas encadenadas entre túneles y luces de una ciudad nocturna.", "neon", "Difícil", 2],
]
const MUSIC := [
	"res://assets/music/bahia_turbo.ogg",
	"res://assets/music/garden.ogg",
	"res://assets/music/coastal.ogg",
]
const SURFACES := ["sand", "dirt", "dirt", "grass", "sand", "dirt", "sand", "grass", "asphalt"]
const PROP_SCENES := [
	"res://assets/track/large_rock.tscn",
	"res://assets/track/large_bush.tscn",
	"res://assets/track/large_rock.tscn",
	"res://assets/track/oak_tree.tscn",
	"res://assets/track/palm_tree.tscn",
	"res://assets/track/large_rock.tscn",
	"res://assets/track/large_rock.tscn",
	"res://assets/track/large_bush.tscn",
	"res://assets/track/racing_tents.tscn",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for index in TRACKS.size():
		var data: Array = TRACKS[index]
		var session := TrackEditorSession.new()
		session.create_track(&"large", data[0])
		var track := session.track
		track.track_theme = load("res://levels/themes/%s_theme.tres" % data[2])
		track.track_music = load(MUSIC[index % MUSIC.size()])
		track.difficulty = data[3]
		_shape_route(track.get_main_route().curve, index)
		track.environment_size = Vector2(620, 560)
		_rebuild_items(session)
		_add_surface(track, index)
		_add_props(track, index)
		var validation := track.validate_track()
		if not validation.is_empty():
			push_error("%s: %s" % [data[0], ", ".join(validation)])
			quit(1)
			return
		var error := session.publish(3, data[1])
		if error != OK:
			push_error("No se pudo publicar %s: %s" % [data[0], error_string(error)])
			quit(1)
			return
		print("PUBLICADA: %s (%.0f m)" % [data[0], track.get_main_route().curve.get_baked_length()])
	quit()


func _shape_route(curve: Curve3D, variant: int) -> void:
	var positions: Array[Vector3] = []
	for point_index in curve.point_count:
		var point := curve.get_point_position(point_index)
		var radial := 2.0 + 0.18 * sin(float(point_index * (variant + 2)))
		point.x *= radial * (1.0 + 0.04 * variant)
		point.z *= radial * (1.05 - 0.025 * variant)
		point.y = 0.5 + sin(float(point_index) * 1.15 + variant) * (2.0 + variant * 0.42)
		positions.append(point)
	for point_index in positions.size():
		curve.set_point_position(point_index, positions[point_index])
		var previous := positions[(point_index - 1 + positions.size()) % positions.size()]
		var next := positions[(point_index + 1) % positions.size()]
		var tangent := (next - previous) / (5.2 + 0.12 * variant)
		curve.set_point_in(point_index, -tangent)
		curve.set_point_out(point_index, tangent)


func _rebuild_items(session: TrackEditorSession) -> void:
	var root := session.track.get_node("ItemSpawns")
	for child in root.get_children():
		child.free()
	var curve := session.track.get_main_route().curve
	for item_index in 8:
		var marker := Marker3D.new()
		marker.name = "ItemSpawn%d" % (item_index + 1)
		var progress := 0.08 + item_index * 0.115
		marker.position = curve.sample_baked(curve.get_baked_length() * progress, true)
		root.add_child(marker)
		marker.owner = session.track
		session.anchor_item_spawn(marker, progress)


func _add_surface(track: TrackLevel, index: int) -> void:
	var zone := TrackSurfaceZone.new()
	zone.name = "IdentitySurface"
	zone.id = StringName("%s_zone" % SURFACES[index])
	zone.start_progress = 0.18
	zone.end_progress = 0.36
	zone.width = 8.5
	zone.surface = load("res://levels/surfaces/%s.tres" % SURFACES[index])
	track.get_node("Surfaces").add_child(zone)
	zone.owner = track


func _add_props(track: TrackLevel, index: int) -> void:
	var scene := load(PROP_SCENES[index]) as PackedScene
	var curve := track.get_main_route().curve
	for prop_index in 8:
		var prop := scene.instantiate() as Node3D
		prop.name = "ThemeProp%d" % (prop_index + 1)
		var progress := 0.04 + prop_index * 0.12
		var center := curve.sample_baked(curve.get_baked_length() * progress, true)
		var before := curve.sample_baked(curve.get_baked_length() * fposmod(progress - 0.005, 1.0), true)
		var after := curve.sample_baked(curve.get_baked_length() * fposmod(progress + 0.005, 1.0), true)
		var forward := after - before
		forward.y = 0.0
		var side := Vector3(-forward.z, 0, forward.x).normalized()
		prop.position = center + side * (18.0 if prop_index % 2 == 0 else -18.0)
		prop.scale = Vector3.ONE * (4.0 if index in [3, 4, 7] else 6.0)
		track.get_node("Props").add_child(prop)
		prop.owner = track
