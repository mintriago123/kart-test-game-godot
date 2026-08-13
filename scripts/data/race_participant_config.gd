class_name RaceParticipantConfig
extends RefCounted

enum ControlType {
	AI,
	LOCAL,
	REMOTE,
}

const DEVICE_NONE := &"none"
const DEVICE_KEYBOARD := &"keyboard"
const DEVICE_GAMEPAD := &"gamepad"
const DEVICE_NETWORK := &"network"

var slot_id := 0
var racer: RacerDefinition
var vehicle: KartVariantDefinition
var control_type := ControlType.AI
var device_type: StringName = DEVICE_NONE
var device_id := -1
var peer_id := 0
var session_token := ""


static func create(
	value_slot_id: int,
	value_racer: RacerDefinition,
	value_vehicle: KartVariantDefinition = null,
	value_control_type: int = ControlType.AI,
	value_device_type: StringName = DEVICE_NONE,
	value_device_id: int = -1,
	value_peer_id: int = 0
) -> RaceParticipantConfig:
	var participant := RaceParticipantConfig.new()
	participant.slot_id = value_slot_id
	participant.racer = value_racer
	participant.vehicle = value_vehicle
	participant.control_type = value_control_type
	participant.device_type = value_device_type
	participant.device_id = value_device_id
	participant.peer_id = value_peer_id
	return participant


func is_human() -> bool:
	return control_type != ControlType.AI


func is_local() -> bool:
	return control_type == ControlType.LOCAL


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if slot_id < 0:
		errors.append("Participant slot must be non-negative.")
	if racer == null:
		errors.append("Participant %d has no racer." % slot_id)
	if control_type not in [ControlType.AI, ControlType.LOCAL, ControlType.REMOTE]:
		errors.append("Participant %d has an invalid control type." % slot_id)
	if control_type == ControlType.LOCAL:
		if device_type not in [DEVICE_KEYBOARD, DEVICE_GAMEPAD]:
			errors.append("Local participant %d has an invalid device." % slot_id)
		if device_type == DEVICE_GAMEPAD and device_id < 0:
			errors.append("Local participant %d has no gamepad id." % slot_id)
	if control_type == ControlType.REMOTE and peer_id <= 0:
		errors.append("Remote participant %d has no peer id." % slot_id)
	return errors


func to_dict() -> Dictionary:
	return {
		"slot_id": slot_id,
		"racer_id": racer.id if racer != null else &"",
		"vehicle_id": vehicle.id if vehicle != null else &"",
		"control_type": control_type,
		"device_type": device_type,
		"device_id": device_id,
		"peer_id": peer_id,
		"session_token": session_token,
	}
