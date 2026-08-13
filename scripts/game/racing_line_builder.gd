class_name RacingLineBuilder
extends RefCounted

const SAMPLE_SPACING := 1.5
const MINIMUM_ROUTE_LENGTH := 30.0
const SAFE_EDGE_MARGIN := 1.9
const CORNER_THRESHOLD := 0.012
const APEX_THRESHOLD := 0.035


static func build(
	route_points: Array[Vector3],
	shortcut_definitions: Array[Dictionary] = [],
	fingerprint: String = "",
	road_width: float = CoastalTrack.ROAD_WIDTH,
	shortcut_width: float = CoastalTrack.SHORTCUT_WIDTH
) -> RacingLine:
	var line := RacingLine.new()
	line.track_fingerprint = fingerprint
	if not _valid_points(route_points, true):
		return line
	var center_samples := _resample(route_points, true, SAMPLE_SPACING)
	if center_samples.size() < 3:
		return line
	line.total_length = _closed_length(center_samples)
	if line.total_length < MINIMUM_ROUTE_LENGTH:
		return RacingLine.new()
	line.track_fingerprint = fingerprint
	line.samples = _build_samples(center_samples, road_width, true)
	line.sections = _classify_sections(line.samples, line.total_length)
	for section in line.sections:
		for sample in line.samples:
			if _distance_in_section(sample.distance, section, line.total_length):
				sample.section_id = section.id
	for shortcut in shortcut_definitions:
		var branch := _build_branch(shortcut, route_points, line, shortcut_width)
		if branch != null:
			line.shortcut_branches.append(branch)
	return line


static func _build_samples(points: Array[Vector3], width: float, optimize: bool) -> Array[RacingLineSample]:
	var samples: Array[RacingLineSample] = []
	var distance := 0.0
	var half_safe_width := maxf(width * 0.5 - SAFE_EDGE_MARGIN, 0.5)
	var curvatures: Array[float] = []
	for index in points.size():
		curvatures.append(_curvature(points, index))
	var smoothed: Array[float] = curvatures.duplicate()
	for index in points.size():
		var sum := 0.0
		for offset in range(-2, 3):
			sum += curvatures[posmod(index + offset, points.size())]
		smoothed[index] = sum / 5.0
	for index in points.size():
		if index > 0:
			distance += points[index - 1].distance_to(points[index])
		var previous := points[posmod(index - 1, points.size())]
		var next := points[(index + 1) % points.size()]
		var forward := (next - previous).normalized()
		if not _finite_vector(forward) or forward.is_zero_approx():
			return []
		var signed_curvature: float = smoothed[index]
		var offset := 0.0
		if optimize:
			# A smooth outside-inside-outside bias. It remains deliberately modest.
			var future_curve: float = smoothed[(index + 4) % points.size()]
			var previous_curve: float = smoothed[posmod(index - 4, points.size())]
			var phase := clampf((future_curve - previous_curve) * 18.0, -1.0, 1.0)
			offset = clampf(-signf(signed_curvature) * half_safe_width * 0.42 + phase * half_safe_width * 0.2, -half_safe_width, half_safe_width)
		var right := Vector3.UP.cross(forward).normalized()
		var sample := RacingLineSample.new()
		sample.distance = distance
		sample.position = points[index] + right * offset
		sample.forward = forward
		sample.curvature = signed_curvature
		sample.available_width = half_safe_width
		sample.lateral_offset = offset
		var slope := absf(forward.y)
		var curvature_cost := clampf(absf(signed_curvature) * 10.5, 0.0, 0.68)
		var width_penalty := clampf((4.5 - half_safe_width) * 0.035, 0.0, 0.12)
		sample.recommended_speed_ratio = clampf(1.0 - curvature_cost - slope * 0.22 - width_penalty, 0.32, 1.0)
		if not _finite_sample(sample):
			return []
		samples.append(sample)
	return samples


static func _classify_sections(samples: Array[RacingLineSample], total_length: float) -> Array[RacingLineSection]:
	var sections: Array[RacingLineSection] = []
	if samples.is_empty():
		return sections
	var types: Array[int] = []
	for index in samples.size():
		var curvature := absf(samples[index].curvature)
		var previous := absf(samples[posmod(index - 4, samples.size())].curvature)
		var future := absf(samples[(index + 4) % samples.size()].curvature)
		var type := RacingLineSection.Type.STRAIGHT
		if curvature >= APEX_THRESHOLD and curvature >= previous and curvature >= future:
			type = RacingLineSection.Type.CORNER_APEX
		elif curvature >= CORNER_THRESHOLD and future > curvature:
			type = RacingLineSection.Type.CORNER_ENTRY
		elif curvature >= CORNER_THRESHOLD:
			type = RacingLineSection.Type.CORNER_EXIT
		elif future >= CORNER_THRESHOLD:
			type = RacingLineSection.Type.BRAKING
		types.append(type)
	var start := 0
	for index in range(1, samples.size() + 1):
		if index < samples.size() and types[index] == types[start]:
			continue
		var section := RacingLineSection.new()
		section.id = sections.size()
		section.type = types[start]
		section.start_distance = samples[start].distance
		section.end_distance = samples[index - 1].distance
		for sample_index in range(start, index):
			var curvature := samples[sample_index].curvature
			if absf(curvature) > absf(section.peak_curvature):
				section.peak_curvature = curvature
		section.turn_direction = signf(section.peak_curvature)
		sections.append(section)
		start = index
	return sections


static func _build_branch(
	definition: Dictionary,
	route_points: Array[Vector3],
	line: RacingLine,
	width: float
) -> RacingLineBranch:
	var points: Array[Vector3] = definition.get("points", [])
	var entry_index := int(definition.get("entry_index", -1))
	var exit_index := int(definition.get("exit_index", -1))
	if not _valid_points(points, false) or entry_index < 0 or exit_index <= entry_index or exit_index >= route_points.size():
		return null
	var resampled := _resample(points, false, SAMPLE_SPACING)
	if resampled.size() < 3:
		return null
	var entry_projection := line.project(route_points[entry_index])
	var exit_projection := line.project(route_points[exit_index], entry_projection.sample_index)
	if entry_projection.sample_index < 0 or exit_projection.sample_index < 0:
		return null
	var branch := RacingLineBranch.new()
	branch.shortcut_id = int(definition.get("id", -1))
	branch.entry_distance = entry_projection.distance
	branch.exit_distance = exit_projection.distance
	branch.samples = _build_samples(resampled, width, false)
	if branch.samples.is_empty():
		return null
	branch.total_length = branch.samples[-1].distance
	for sample in branch.samples:
		sample.distance += branch.entry_distance
	var main_distance := branch.exit_distance - branch.entry_distance
	if main_distance < 0.0:
		main_distance += line.total_length
	branch.estimated_gain = main_distance - branch.total_length
	var peak := 0.0
	for sample in branch.samples:
		peak = maxf(peak, absf(sample.curvature))
	branch.risk = clampf(peak * 8.0 + maxf(-branch.estimated_gain, 0.0) * 0.02, 0.0, 1.0)
	branch.minimum_precision = clampf(0.45 + branch.risk * 0.35, 0.45, 0.9)
	return branch


static func _resample(points: Array[Vector3], closed: bool, spacing: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var segment_count := points.size() if closed else points.size() - 1
	var length := 0.0
	for index in segment_count:
		length += points[index].distance_to(points[(index + 1) % points.size()])
	var count := maxi(roundi(length / spacing), 3)
	var step := length / count if closed else length / (count - 1)
	var segment := 0
	var segment_start_distance := 0.0
	var segment_length := points[0].distance_to(points[1])
	var output_count := count if closed else count + 1
	for sample_index in output_count:
		var wanted := minf(sample_index * step, length)
		while segment < segment_count - 1 and wanted > segment_start_distance + segment_length:
			segment_start_distance += segment_length
			segment += 1
			segment_length = points[segment].distance_to(points[(segment + 1) % points.size()])
		var weight := clampf((wanted - segment_start_distance) / maxf(segment_length, 0.001), 0.0, 1.0)
		result.append(points[segment].lerp(points[(segment + 1) % points.size()], weight))
	return result


static func _curvature(points: Array[Vector3], index: int) -> float:
	var previous := points[posmod(index - 1, points.size())]
	var current := points[index]
	var next := points[(index + 1) % points.size()]
	var incoming := current - previous
	var outgoing := next - current
	incoming.y = 0.0
	outgoing.y = 0.0
	if incoming.is_zero_approx() or outgoing.is_zero_approx():
		return 0.0
	var average_length := maxf((incoming.length() + outgoing.length()) * 0.5, 0.001)
	return incoming.normalized().cross(outgoing.normalized()).y / average_length


static func _closed_length(points: Array[Vector3]) -> float:
	var result := 0.0
	for index in points.size():
		result += points[index].distance_to(points[(index + 1) % points.size()])
	return result


static func _valid_points(points: Array[Vector3], closed: bool) -> bool:
	if points.size() < (3 if closed else 2):
		return false
	for point in points:
		if not _finite_vector(point):
			return false
	return true


static func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _finite_sample(sample: RacingLineSample) -> bool:
	return (
		is_finite(sample.distance)
		and _finite_vector(sample.position)
		and _finite_vector(sample.forward)
		and is_finite(sample.curvature)
		and is_finite(sample.recommended_speed_ratio)
	)


static func _distance_in_section(distance: float, section: RacingLineSection, _total_length: float) -> bool:
	return distance >= section.start_distance and distance <= section.end_distance + SAMPLE_SPACING
