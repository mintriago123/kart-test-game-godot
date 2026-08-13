extends SceneTree

const CATALOG_PATH := "res://progression/progression_catalog.tres"
const TRACK_CATALOG_PATH := "res://levels/track_catalog.tres"

var _failed := false


func _initialize() -> void:
	call_deferred("_publish")


func _publish() -> void:
	var catalog := ResourceLoader.load(CATALOG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ProgressionCatalog
	var tracks := ResourceLoader.load(TRACK_CATALOG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TrackCatalog
	if catalog == null or tracks == null:
		push_error("Could not load the progression or track catalog.")
		quit(1)
		return
	var variants: Array[KartVariantDefinition] = []
	for id in [&"sedan", &"kart_oobi", &"taxi", &"kart_oodi", &"van", &"kart_ooli", &"suv_luxury", &"kart_oozi", &"sedan_sports", &"kart_oopi", &"hatchback_sports", &"race", &"race_future"]:
		var variant := load("res://progression/variants/%s.tres" % id) as KartVariantDefinition
		if variant == null:
			push_error("Missing variant %s." % id)
			_failed = true
		else:
			variants.append(variant)
	if _failed:
		quit(1)
		return

	var rewards: Array[UnlockDefinition] = []
	rewards.append(_cup_reward(&"tropical_bronze", &"tropical", UnlockDefinition.BRONZE, _variant(variants, &"kart_oobi")))
	rewards.append(_cup_reward(&"tropical_silver", &"tropical", UnlockDefinition.SILVER, _variant(variants, &"taxi")))
	rewards.append(_cup_reward(&"horizontes_bronze", &"horizontes", UnlockDefinition.BRONZE, _variant(variants, &"kart_oodi")))
	rewards.append(_cup_reward(&"horizontes_silver", &"horizontes", UnlockDefinition.SILVER, _variant(variants, &"van")))
	rewards.append(_cup_reward(&"salvaje_bronze", &"salvaje", UnlockDefinition.BRONZE, _variant(variants, &"kart_ooli")))
	rewards.append(_cup_reward(&"salvaje_silver", &"salvaje", UnlockDefinition.SILVER, _variant(variants, &"suv_luxury")))
	rewards.append(_cup_reward(&"extrema_bronze", &"extrema", UnlockDefinition.BRONZE, _variant(variants, &"kart_oozi")))
	rewards.append(_cup_reward(&"extrema_silver", &"extrema", UnlockDefinition.SILVER, _variant(variants, &"sedan_sports")))
	rewards.append(_career_reward(&"career_12", 12, _variant(variants, &"kart_oopi")))
	rewards.append(_career_reward(&"career_30", 30, _variant(variants, &"hatchback_sports")))
	rewards.append(_career_reward(&"career_56", 56, _variant(variants, &"race")))
	rewards.append(_career_reward(&"career_90", 90, _variant(variants, &"race_future")))
	for reward in rewards:
		var error := ResourceSaver.save(reward, "res://progression/unlocks/%s.tres" % reward.id)
		if error != OK:
			push_error("Could not save reward %s: %s" % [reward.id, error_string(error)])
			_failed = true
	if _failed:
		quit(1)
		return

	catalog.unlocks.initial_variant = _variant(variants, &"sedan")
	catalog.unlocks.variants = variants
	catalog.unlocks.unlocks = rewards
	catalog.cups.cups.clear()
	for difficulty in catalog.difficulties.difficulties:
		difficulty.progress_multiplier = difficulty.sort_order + 1
		ResourceSaver.save(difficulty, difficulty.resource_path)
	if ResourceSaver.save(catalog, CATALOG_PATH) != OK:
		push_error("Could not prepare the progression catalog.")
		quit(1)
		return

	var definitions := [
		[&"tropical", "Copa Tropical", "Costa, jardines y velocidad frente al mar.", [&"coastal", &"garden", &"bahia_turbo"], &"", &"", UnlockDefinition.BRONZE, [&"tropical_bronze", &"tropical_silver"]],
		[&"horizontes", "Copa Horizontes", "Desiertos, valles dorados y una bahía pirata.", [&"dunas_doradas", &"valle_de_otoo", &"baha_pirata"], &"tropical", &"relaxed", UnlockDefinition.BRONZE, [&"horizontes_bronze", &"horizontes_silver"]],
		[&"salvaje", "Copa Salvaje", "Bruma, cañones y ruinas de selva profunda.", [&"pantano_brumoso", &"can_carmes", &"ruinas_esmeralda"], &"horizontes", &"competitive", UnlockDefinition.BRONZE, [&"salvaje_bronze", &"salvaje_silver"]],
		[&"extrema", "Copa Extrema", "Lava, hielo y luces de medianoche.", [&"caldera_furiosa", &"cumbre_glacial", &"nen_medianoche"], &"salvaje", &"expert", UnlockDefinition.BRONZE, [&"extrema_bronze", &"extrema_silver"]],
		[&"contrastes", "Copa Contrastes", "Tres extremos del campeonato en una sola Copa.", [&"bahia_turbo", &"dunas_doradas", &"cumbre_glacial"], &"extrema", &"", UnlockDefinition.BRONZE, []],
		[&"expedicion", "Copa Expedición", "Una travesía de la costa al corazón del volcán.", [&"coastal", &"pantano_brumoso", &"caldera_furiosa"], &"extrema", &"", UnlockDefinition.BRONZE, []],
		[&"festival", "Copa Festival", "Jardines, piratas y neón para cerrar la campaña.", [&"garden", &"baha_pirata", &"nen_medianoche"], &"extrema", &"", UnlockDefinition.BRONZE, []],
	]
	for index in definitions.size():
		var data: Array = definitions[index]
		var cup := CupDefinition.new()
		cup.id = data[0]
		cup.display_name = data[1]
		cup.description = data[2]
		for track_id in data[3]: cup.tracks.append(tracks.get_track(track_id))
		cup.player_racer = catalog.racers.get_racer(&"marea")
		for racer_id in [&"lima", &"coral", &"brisa"]: cup.opponents.append(catalog.racers.get_racer(racer_id))
		cup.scoring_table = PackedInt32Array([9, 6, 3, 1])
		cup.medal_thresholds = PackedInt32Array([9, 17, 24])
		cup.difficulties.assign(catalog.difficulties.difficulties)
		cup.prerequisite_cup_id = data[4]
		cup.prerequisite_difficulty_id = data[5]
		cup.prerequisite_medal = data[6]
		cup.sort_order = index
		for reward_id in data[7]: cup.unlocks.append(_reward(rewards, reward_id))
		var session := CupEditorSession.new()
		session.catalog = catalog
		session.cup = cup
		var error := session.publish_cup()
		if error != OK:
			push_error("Could not publish %s: %s" % [cup.id, session.last_error])
			_failed = true
			break
	print("Published seven official cups through CupEditorSession.")
	quit(1 if _failed else 0)


func _cup_reward(id: StringName, cup_id: StringName, medal: int, variant: KartVariantDefinition) -> UnlockDefinition:
	var reward := UnlockDefinition.new()
	reward.id = id
	reward.display_name = variant.display_name
	reward.requirement_type = UnlockDefinition.CUP_MEDAL
	reward.cup_id = cup_id
	reward.required_medal = medal
	reward.kart_variant = variant
	return reward


func _career_reward(id: StringName, points: int, variant: KartVariantDefinition) -> UnlockDefinition:
	var reward := UnlockDefinition.new()
	reward.id = id
	reward.display_name = variant.display_name
	reward.requirement_type = UnlockDefinition.CAREER_POINTS
	reward.required_points = points
	reward.kart_variant = variant
	return reward


func _variant(values: Array[KartVariantDefinition], id: StringName) -> KartVariantDefinition:
	for value in values:
		if value.id == id: return value
	return null


func _reward(values: Array[UnlockDefinition], id: StringName) -> UnlockDefinition:
	for value in values:
		if value.id == id: return value
	return null
