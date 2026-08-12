class_name GhostRecording
extends RefCounted

const FORMAT_VERSION := 1

var format_version := FORMAT_VERSION
var track_id: StringName
var track_fingerprint := ""
var cc_id: StringName
var total_laps := 0
var total_time := 0.0
var lap_times: Array[float] = []
var sample_interval := 0.1
var samples: Array[GhostSample] = []
