class_name LookModeHandler
extends RefCounted

## LookModeHandler - Handles look/examine mode for inspecting visible objects
##
## Extracted from InputHandler to reduce file size and improve maintainability.
## Manages state for cycling through visible objects in the player's FOV.

signal object_changed(obj: Dictionary)
signal mode_exited()

# State
var active: bool = false
var objects: Array = []
var current_index: int = 0
var current_object: Dictionary = {}

## Start look mode - gather all visible objects
## objects_array should be provided by InputHandler (which has access to the gathering logic)
func start(objects_array: Array) -> Dictionary:
	if active:
		stop()
		return {"action": "stopped"}

	if objects_array.is_empty():
		return {"action": "no_objects", "message": "Nothing visible to examine."}

	objects = objects_array
	active = true
	current_index = 0
	current_object = objects[0]
	object_changed.emit(current_object)

	return {
		"action": "started",
		"object": current_object,
		"index": current_index,
		"total": objects.size(),
		"message": "Look mode: [Tab] cycle, [Enter] target enemy, [Esc] exit"
	}


## Stop look mode
func stop() -> void:
	active = false
	objects.clear()
	current_index = 0
	current_object = {}
	mode_exited.emit()


## Check if look mode is active
func is_active() -> bool:
	return active


## Check if this handler should process the input
func wants_input() -> bool:
	return active


## Handle input event
## Returns Dictionary with result of handling
func handle_input(keycode: int, shift_pressed: bool = false) -> Dictionary:
	if not active:
		return {"handled": false}

	match keycode:
		KEY_TAB, KEY_RIGHT, KEY_D:
			# Cycle to next object (or previous with shift)
			if shift_pressed:
				_cycle_previous()
			else:
				_cycle_next()
			return {
				"handled": true,
				"action": "cycled",
				"object": current_object,
				"index": current_index,
				"total": objects.size()
			}

		KEY_LEFT, KEY_A:
			# Cycle to previous object
			_cycle_previous()
			return {
				"handled": true,
				"action": "cycled",
				"object": current_object,
				"index": current_index,
				"total": objects.size()
			}

		KEY_ENTER, KEY_KP_ENTER:
			# Try to target the looked-at object
			var can_target = _can_target_current()
			if can_target:
				var target = current_object.get("object")
				stop()
				return {"handled": true, "action": "target_selected", "target": target}
			else:
				return {"handled": true, "action": "cannot_target", "message": "Can only target enemies."}

		KEY_ESCAPE:
			stop()
			return {"handled": true, "action": "stopped", "message": "Exited look mode."}

	return {"handled": false}


## Get the currently looked-at object
func get_current_object() -> Dictionary:
	return current_object


## Get position of current object
func get_current_position() -> Vector2i:
	return current_object.get("position", Vector2i.ZERO)


## Check if current object can be targeted
func _can_target_current() -> bool:
	if current_object.is_empty():
		return false

	var obj = current_object.get("object")
	if obj == null:
		return false

	if obj is Enemy and obj.is_alive:
		return true

	return false


## Cycle to next object
func _cycle_next() -> void:
	if objects.is_empty():
		return
	current_index = (current_index + 1) % objects.size()
	current_object = objects[current_index]
	object_changed.emit(current_object)


## Cycle to previous object
func _cycle_previous() -> void:
	if objects.is_empty():
		return
	current_index = (current_index - 1 + objects.size()) % objects.size()
	current_object = objects[current_index]
	object_changed.emit(current_object)
