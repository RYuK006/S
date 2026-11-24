# debug_overlay.gd
# F3 Debug telemetry overlay: displays frame metrics, vehicle kinematics, Pacejka slip and audio states.
class_name DebugOverlay
extends Control

var target_vehicle: VehicleController
var label: Label
var is_visible_overlay: bool = true

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Create styling and panel
	var panel = PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	
	label = Label.new()
	label.text = "GRIDLETHAL TELEMETRY"
	panel.add_child(label)

func _input(event: InputEvent):
	if event.is_action_pressed("debug_f3"):
		is_visible_overlay = !is_visible_overlay
		visible = is_visible_overlay

func _process(delta: float):
	if not visible or not target_vehicle:
		return
		
	var fps = Engine.get_frames_per_second()
	var frame_ms = delta * 1000.0
	var speed_kmh = target_vehicle.speed_kmh
	var speed_mph = speed_kmh * 0.621371
	
	var text = "=== GRIDLETHAL ENGINE TELEMETRY (F3 to toggle) ===\n"
	text += "FPS: %d (%.2f ms) | Physics Rate: %d Hz\n" % [fps, frame_ms, Engine.physics_ticks_per_second]
	text += "Vehicle: %s\n" % target_vehicle.car_id.to_upper()
	text += "Speed: %.1f km/h (%.1f mph) | RPM: %d / %d | Gear: %s\n" % [
		speed_kmh, speed_mph, int(target_vehicle.engine_rpm), int(target_vehicle.recipe.redline_rpm),
		("R" if target_vehicle.current_gear == 0 else str(target_vehicle.current_gear))
	]
	text += "Throttle: %.0f%% | Brake: %.0f%% | Turbo Boost: %.2f bar | Nitro: %.0f%%\n" % [
		target_vehicle.throttle_input * 100.0, target_vehicle.brake_input * 100.0,
		target_vehicle.turbo_boost * 1.4, target_vehicle.nitro_amount
	]
	text += "Health: %.0f / %.0f | Rollover: %s\n" % [
		target_vehicle.health, target_vehicle.max_health, ("FLIPPED (Hold R)" if target_vehicle.is_flipped else "OK")
	]
	text += "--------------------------------------------------\n"
	text += "WHEEL CONTACT & TIRE SLIP (Pacejka):\n"
	for i in range(target_vehicle.wheels.size()):
		var w = target_vehicle.wheels[i]
		var tag = ["FL", "FR", "RL", "RR"][i]
		text += " [%s] Ground: %s | Comp: %.2fm | Fz: %.0fN | SlipAngle: %.1f° | Surface: %s (x%.2f)\n" % [
			tag, ("YES" if w.is_grounded else "AIR"), w.compression, w.normal_force,
			rad_to_deg(w.slip_angle), w.surface_type, w.surface_mu
		]
	
	label.text = text
