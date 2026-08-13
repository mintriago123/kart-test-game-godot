class_name RacingLine
extends RefCounted

const FORMAT_VERSION := 1
const LOCAL_SEARCH_RADIUS := 14
const FALLBACK_SEARCH_STEP := 12

var format_version := FORMAT_VERSION
var track_fingerprint := ""
var total_length := 0.0
var samples: Array[RacingLineSample] = []
var sections: Array[RacingLineSection] = []
var shortcut_branches: Array[RacingLineBranch] = []


func is_valid() -> bool:
	return samples.size() >= 3 and total_length > 10.0


func project(position: Vector3, hint_index: int = -1) -> RacingLineProjection:
	return _project_samples(position, samples, hint_index, true, -1)


func project_branch(position: Vector3, branch_id: int, hint_index: int = -1) -> RacingLineProjection:
	var branch := get_branch(branch_id)
	if branch == null:
		return RacingLineProjection.new()
	return _project_samples(position, branch.samples, hint_index, false, branch_id)


func sample_at_distance(distance: float, branch_id: int = -1) -> RacingLineSample:
	var source := samples
	var closed := true
	if branch_id >= 0:
		var branch := get_branch(branch_id)
		if branch == null or branch.samples.is_empty():
			return null
		source = branch.samples
		closed = false
	if source.is_empty():
		return null
	var wanted := fposmod(distance, total_length) if closed else clampf(distance, source[0].distance, source[-1].distance)
	var low := 0
	var high := source.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if source[middle].distance < wanted:
			low = middle + 1
		else:
			high = middle
	var next_index := low
	var previous_index := maxi(next_index - 1, 0)
	if next_index == previous_index:
		return source[next_index]
	var previous := source[previous_index]
	var next := source[next_index]
	var span := maxf(next.distance - previous.distance, 0.001)
	var weight := clampf((wanted - previous.distance) / span, 0.0, 1.0)
	var result := previous.duplicate_sample()
	result.distance = wanted
	result.position = previous.position.lerp(next.position, weight)
	result.forward = previous.forward.lerp(next.forward, weight).normalized()
	result.curvature = lerpf(previous.curvature, next.curvature, weight)
	result.recommended_speed_ratio = lerpf(previous.recommended_speed_ratio, next.recommended_speed_ratio, weight)
	result.available_width = lerpf(previous.available_width, next.available_width, weight)
	result.lateral_offset = lerpf(previous.lateral_offset, next.lateral_offset, weight)
	result.section_id = previous.section_id if weight < 0.5 else next.section_id
	return result


func get_minimum_speed_ratio(distance: float, lookahead: float) -> float:
	if samples.is_empty():
		return 1.0
	var minimum := 1.0
	var steps := maxi(ceili(lookahead / 3.0), 1)
	for step in steps + 1:
		var sample := sample_at_distance(distance + lookahead * float(step) / steps)
		if sample != null:
			minimum = minf(minimum, sample.recommended_speed_ratio)
	return minimum


func get_branch(branch_id: int) -> RacingLineBranch:
	for branch in shortcut_branches:
		if branch.shortcut_id == branch_id:
			return branch
	return null


func _project_samples(
	position: Vector3,
	source: Array[RacingLineSample],
	hint_index: int,
	closed: bool,
	branch_id: int
) -> RacingLineProjection:
	var result := RacingLineProjection.new()
	result.branch_id = branch_id
	if source.is_empty():
		return result
	var candidates: Array[int] = []
	if hint_index >= 0 and hint_index < source.size():
		for offset in range(-LOCAL_SEARCH_RADIUS, LOCAL_SEARCH_RADIUS + 1):
			var index := hint_index + offset
			if closed:
				index = posmod(index, source.size())
			elif index < 0 or index >= source.size():
				continue
			candidates.append(index)
	else:
		for index in range(0, source.size(), FALLBACK_SEARCH_STEP):
			candidates.append(index)
	var best_index := _closest_index(position, source, candidates)
	var local_missed := (
		hint_index >= 0
		and best_index >= 0
		and position.distance_squared_to(source[best_index].position) > 144.0
	)
	if hint_index < 0 or local_missed:
		candidates.clear()
		for index in range(0, source.size(), FALLBACK_SEARCH_STEP):
			candidates.append(index)
		best_index = _closest_index(position, source, candidates)
	if best_index >= 0 and (hint_index < 0 or local_missed):
		candidates.clear()
		for offset in range(-FALLBACK_SEARCH_STEP, FALLBACK_SEARCH_STEP + 1):
			var index := best_index + offset
			if closed:
				index = posmod(index, source.size())
			elif index < 0 or index >= source.size():
				continue
			candidates.append(index)
		best_index = _closest_index(position, source, candidates)
	if best_index < 0:
		return result
	var sample := source[best_index]
	var right := Vector3.UP.cross(sample.forward).normalized()
	result.sample_index = best_index
	result.distance = sample.distance
	result.position = sample.position
	result.lateral_error = (position - sample.position).dot(right)
	result.distance_squared = position.distance_squared_to(sample.position)
	return result


func _closest_index(position: Vector3, source: Array[RacingLineSample], candidates: Array[int]) -> int:
	var best_index := -1
	var best_distance := INF
	for index in candidates:
		var distance_squared := position.distance_squared_to(source[index].position)
		if distance_squared < best_distance:
			best_distance = distance_squared
			best_index = index
	return best_index
