# input_manager.gd
# Multi-platform input abstraction layer: Keyboard/Mouse, Gamepad (XInput/DualSense), and Mobile Touch.
class_name InputManager
extends Node

signal input_device_changed(device_type: String)

enum DeviceType {
	KEYBOARD_MOUSE,
	GAMEPAD,
	TOUCH
}

var current_device: DeviceType = DeviceType.KEYBOARD_MOUSE

# Virtual touch inputs (for mobile overlays)
var virtual_steer: float = 0.0
var virtual_throttle: float = 0.0
var virtual_brake: float = 0.0
var virtual_handbrake: bool = false
var virtual_nitro: bool = false
var virtual_fire_primary: bool = false
var virtual_fire_roof: bool = false
var virtual_fire_rear: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent):
	if event is InputEventKey or event is InputEventMouse:
		if current_device != DeviceType.KEYBOARD_MOUSE:
			current_device = DeviceType.KEYBOARD_MOUSE
			input_device_changed.emit("Keyboard/Mouse")
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if current_device != DeviceType.GAMEPAD:
			current_device = DeviceType.GAMEPAD
			input_device_changed.emit("Gamepad")
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		if current_device != DeviceType.TOUCH:
			current_device = DeviceType.TOUCH
			input_device_changed.emit("Touch")

func get_steer() -> float:
	if current_device == DeviceType.TOUCH and abs(virtual_steer) > 0.01:
		return clampf(virtual_steer, -1.0, 1.0)
	var left = Input.get_action_strength("steer_left")
	var right = Input.get_action_strength("steer_right")
	return clampf(right - left, -1.0, 1.0)

func get_throttle() -> float:
	if current_device == DeviceType.TOUCH and virtual_throttle > 0.01:
		return clampf(virtual_throttle, 0.0, 1.0)
	return clampf(Input.get_action_strength("throttle"), 0.0, 1.0)

func get_brake() -> float:
	if current_device == DeviceType.TOUCH and virtual_brake > 0.01:
		return clampf(virtual_brake, 0.0, 1.0)
	return clampf(Input.get_action_strength("brake"), 0.0, 1.0)

func is_handbrake() -> bool:
	return virtual_handbrake or Input.is_action_pressed("handbrake")

func is_nitro() -> bool:
	return virtual_nitro or Input.is_action_pressed("nitro")

func is_fire_primary() -> bool:
	return virtual_fire_primary or Input.is_action_pressed("fire_primary")

func is_fire_roof() -> bool:
	return virtual_fire_roof or Input.is_action_just_pressed("fire_turret")

func is_fire_rear() -> bool:
	return virtual_fire_rear or Input.is_action_just_pressed("fire_rear")
