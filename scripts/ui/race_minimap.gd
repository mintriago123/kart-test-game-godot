class_name RaceMinimap
extends TrackMinimapView

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

const PLAYER_COLOR := UiTokens.ELECTRIC_YELLOW
const RIVAL_COLOR := UiTokens.CORAL
const MARKER_RADIUS := 4.0

var _racers: Array[Node3D] = []
var _player: Node3D


func _ready() -> void:
	super._ready()
	clip_contents = true
	background_color = Color.TRANSPARENT
	grid_visible = false
	map_padding = 8.0
	queue_redraw()


func configure_track(track: TrackLevel) -> void:
	set_minimap_data(TrackMinimapBuilder.build(track))


func set_game_mode(game_mode: int) -> void:
	# Direction chevrons resemble rival markers at HUD scale. A time trial only
	# shows the player's live marker (and the ghost elsewhere in the HUD).
	direction_arrows_visible = game_mode != GameModeDefinition.TIME_TRIAL
	queue_redraw()


func register_racers(racers: Array[Node], player: Node3D) -> void:
	_racers.clear()
	for racer in racers:
		if racer is Node3D:
			_racers.append(racer)
	_player = player
	queue_redraw()


func update_normalized_positions(_positions: Dictionary = {}) -> void:
	# Markers read existing transforms; no arrays or geometry are allocated per frame.
	queue_redraw()


func _process(_delta: float) -> void:
	if visible and not _racers.is_empty():
		queue_redraw()


func _draw() -> void:
	super._draw()
	if not is_map_available():
		return
	for racer in _racers:
		if not is_instance_valid(racer):
			continue
		var world := racer.global_position
		var marker := _map_point_to_screen(Vector2(world.x, world.z))
		var is_player := racer == _player
		draw_circle(marker, MARKER_RADIUS + 2.0, UiTokens.GRAPHITE)
		draw_circle(marker, MARKER_RADIUS, PLAYER_COLOR if is_player else RIVAL_COLOR)
		if is_player:
			draw_arc(marker, MARKER_RADIUS + 4.0, 0.0, TAU, 16, Color.WHITE, 1.5)
