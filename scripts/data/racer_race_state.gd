class_name RacerRaceState
extends RefCounted

var lap := 0
var next_checkpoint := 1
var finished := false
var is_dnf := false
var finish_position := 0
var finish_time := 0.0
var lap_started_at := 0.0
var lap_times: Array[float] = []
var start_position := 0
var items_collected := 0
var items_used := 0
var hits_landed := 0
var hits_blocked := 0
var shortcuts_used := 0
var recoveries := 0
