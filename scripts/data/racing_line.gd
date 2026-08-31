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


func project(
	position: Vector3,
	hint_index: int = -1,
	previous_distance: float = -1.0,
	allow_lap_wrap: bool = false
) -> RacingLineProjection:
	return _project_samples(
		position, samples, hint_index, true, -1,
		previous_distance, allow_lap_wrap
	)


func project_branch(
	position: Vector3,
	branch_id: int,
	hint_index: int = -1,
	previous_distance: float = -1.0
) -> RacingLineProjection:
	var branch := get_branch(branch_id)
	if branch == null:
		return RacingLineProjection.new()
	return _project_samples(
		position, branch.samples, hint_index, false, branch_id,
		previous_distance, false
	)


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
	branch_id: int,
	previous_distance: float,
	allow_lap_wrap: bool
) -> RacingLineProjection:
	var result := RacingLineProjection.new()
	result.branch_id = branch_id
	if source.size() < 2:
		return result
	var segment_count := source.size() if closed else source.size() - 1
	var candidates: Array[int] = []
	if hint_index >= 0 and hint_index < source.size():
		for offset in range(-LOCAL_SEARCH_RADIUS, LOCAL_SEARCH_RADIUS + 1):
			var index := hint_index + offset
			if closed:
				index = posmod(index, segment_count)
			elif index < 0 or index >= segment_count:
				continue
			candidates.append(index)
	else:
		candidates = _coarse_segment_candidates(segment_count)
	var best := _closest_segment(position, source, candidates, closed)
	var local_missed := (
		hint_index >= 0
		and best.sample_index >= 0
		and best.distance_squared > 144.0
	)
	if hint_index < 0 or local_missed:
		best = _closest_segment(
			position, source, _coarse_segment_candidates(segment_count), closed
		)
	if best.sample_index >= 0 and (hint_index < 0 or local_missed):
		candidates.clear()
		for offset in range(-FALLBACK_SEARCH_STEP, FALLBACK_SEARCH_STEP + 1):
			var index := best.sample_index + offset
			if closed:
				index = posmod(index, segment_count)
			elif index < 0 or index >= segment_count:
				continue
			candidates.append(index)
		best = _closest_segment(position, source, candidates, closed)
	if best.sample_index < 0:
		return result
	best.branch_id = branch_id
	if previous_distance >= 0.0 and not allow_lap_wrap:
		# A kart can briefly move sideways or backwards while escaping a wall,
		# but the navigation target must not walk backwards with it. Recovery
		# and the finish-line wrap explicitly reset this caller-owned guard.
		var minimum_distance := previous_distance
		if best.distance < minimum_distance:
			best.distance = minimum_distance
			best.progress_clamped = true
	return best


func _coarse_segment_candidates(segment_count: int) -> Array[int]:
	var candidates: Array[int] = []
	for index in range(0, segment_count, FALLBACK_SEARCH_STEP):
		candidates.append(index)
	if not candidates.has(segment_count - 1):
		candidates.append(segment_count - 1)
	return candidates


func _closest_segment(
	position: Vector3,
	source: Array[RacingLineSample],
	candidates: Array[int],
	closed: bool
) -> RacingLineProjection:
	var best := RacingLineProjection.new()
	var best_distance := INF
	var segment_count := source.size() if closed else source.size() - 1
	for index in candidates:
		if index < 0 or index >= segment_count:
			continue
		var next_index := (index + 1) % source.size()
		var start := source[index].position
		var finish := source[next_index].position
		var segment := finish - start
		var segment_length_squared := segment.length_squared()
		if segment_length_squared <= 0.000001:
			continue
		var weight := clampf((position - start).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest := start.lerp(finish, weight)
		var distance_squared := position.distance_squared_to(closest)
		if distance_squared >= best_distance:
			continue
		var forward := segment
		forward.y = 0.0
		if forward.length_squared() <= 0.000001:
			forward = source[index].forward
			forward.y = 0.0
		if forward.length_squared() <= 0.000001:
			continue
		forward = forward.normalized()
		var right := forward.cross(Vector3.UP).normalized()
		best.sample_index = index
		var distance_span := source[next_index].distance - source[index].distance
		if closed and next_index == 0:
			distance_span = total_length - source[index].distance
		best.distance = source[index].distance + maxf(distance_span, 0.0) * weight
		best.position = closest
		best.lateral_error = (position - closest).dot(right)
		best.distance_squared = distance_squared
		best_distance = distance_squared
	return best
