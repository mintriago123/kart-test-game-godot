class_name ItemCatalog
extends Resource

const POSITION_BAND_COUNT := 4
const EXPECTED_WEIGHT_TOTAL := 100

@export var items: Array[ItemDefinition] = []


func validate() -> Array[String]:
	var errors: Array[String] = []
	var known_ids: Dictionary = {}
	var band_totals := PackedInt32Array()
	band_totals.resize(POSITION_BAND_COUNT)
	band_totals.fill(0)
	if items.is_empty():
		errors.append("Item catalog must contain at least one item.")
		return errors
	for item in items:
		if item == null:
			errors.append("Item catalog contains a null definition.")
			continue
		if item.id == &"":
			errors.append("Every item must have a non-empty identifier.")
		elif known_ids.has(item.id):
			errors.append("Duplicate item identifier: %s" % item.id)
		else:
			known_ids[item.id] = true
		if item.position_weights.size() != POSITION_BAND_COUNT:
			errors.append(
				"Item %s must define exactly four position weights." % item.id
			)
			continue
		for band_index in POSITION_BAND_COUNT:
			var weight := item.position_weights[band_index]
			if weight < 0 or weight > EXPECTED_WEIGHT_TOTAL:
				errors.append(
					"Item %s has an invalid weight in band %d."
					% [item.id, band_index]
				)
				continue
			band_totals[band_index] += weight
	for band_index in POSITION_BAND_COUNT:
		if band_totals[band_index] != EXPECTED_WEIGHT_TOTAL:
			errors.append(
				"Position band %d totals %d instead of %d."
				% [
					band_index,
					band_totals[band_index],
					EXPECTED_WEIGHT_TOTAL,
				]
			)
	return errors


func is_valid() -> bool:
	return validate().is_empty()


func get_item(item_id: StringName) -> ItemDefinition:
	for item in items:
		if item != null and item.id == item_id:
			return item
	return null


func draw_item(
	position: int,
	total_racers: int,
	rng: RandomNumberGenerator
) -> ItemDefinition:
	if rng == null:
		push_error("ItemCatalog.draw_item requires an RNG.")
		return null
	var errors := validate()
	if not errors.is_empty():
		push_error("Invalid item catalog: %s" % "; ".join(errors))
		return null
	var band_index := get_position_band(position, total_racers)
	var roll := rng.randi_range(1, EXPECTED_WEIGHT_TOTAL)
	var cumulative_weight := 0
	for item in items:
		cumulative_weight += item.position_weights[band_index]
		if roll <= cumulative_weight:
			return item
	return null


static func get_position_band(position: int, total_racers: int) -> int:
	var safe_total := maxi(total_racers, 1)
	var safe_position := clampi(position, 1, safe_total)
	return clampi(
		roundi(
			float(safe_position - 1)
			* float(POSITION_BAND_COUNT - 1)
			/ float(maxi(safe_total - 1, 1))
		),
		0,
		POSITION_BAND_COUNT - 1
	)
