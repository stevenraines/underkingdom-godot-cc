class_name UICoordinator
extends RefCounted

## UICoordinator - Manages UI screen lifecycle
##
## Handles instantiation, signal wiring, opening, and close-event relay
## for all game UI screens. Extracted from game.gd.

signal screen_closed(screen_name: String)

var _screens: Dictionary = {}
var _hud: CanvasLayer
var _input_handler


func _init(hud: CanvasLayer, input_handler) -> void:
	_hud = hud
	_input_handler = input_handler


## Setup a screen from a preloaded PackedScene.
## Returns the instantiated Control for custom signal connections.
func setup_preloaded(name: String, scene: PackedScene) -> Control:
	var screen = scene.instantiate()
	return _register(name, screen)


## Setup a screen by loading a scene from a file path.
## Returns the instantiated Control for custom signal connections.
func setup_loaded(name: String, path: String, node_name: String = "") -> Control:
	var loaded = load(path)
	if not loaded:
		push_error("[UICoordinator] Could not load scene: " + path)
		return null
	var screen = loaded.instantiate()
	if not node_name.is_empty():
		screen.name = node_name
	return _register(name, screen)


## Register a screen: add to HUD and wire "closed" signal.
func _register(name: String, screen: Control) -> Control:
	_hud.add_child(screen)
	_screens[name] = screen
	if screen.has_signal("closed"):
		screen.closed.connect(_on_screen_closed.bind(name))
	return screen


## Get a screen reference by name.
func get_screen(name: String) -> Control:
	return _screens.get(name)


## Check if a screen exists.
func has_screen(name: String) -> bool:
	return name in _screens


## Check if a screen is currently visible.
func is_visible(name: String) -> bool:
	var screen = _screens.get(name)
	return screen != null and screen.visible


## Open a screen with arguments and block player input.
func open(name: String, args: Array = []) -> void:
	var screen = _screens.get(name)
	if not screen:
		return
	if screen.has_method("open"):
		screen.callv("open", args)
	else:
		screen.show()
	_input_handler.set_ui_blocking(true)


## Handle a screen's "closed" signal: unblock input and relay.
func _on_screen_closed(name: String) -> void:
	_input_handler.set_ui_blocking(false)
	screen_closed.emit(name)
