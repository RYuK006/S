# race_hud.gd
# In-race HUD: Speedometer/Tachometer, Lap & Position counters, 2D Minimap radar, Countdown overlay, and Results panel.
class_name RaceHUD
extends Control

const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")
const RaceManager = preload("res://scripts/race/race_manager.gd")
const SplineTrack = preload("res://scripts/race/spline_track.gd")

var player_car: VehicleController
var race_mgr: RaceManager
var track: SplineTrack

# UI Nodes
var speed_label: Label
var rpm_gear_label: Label
var position_label: Label
var lap_label: Label
var time_label: Label
var countdown_label: Label
var results_panel: PanelContainer
var results_label: Label
var minimap_rect: Control
var hud_layer: CanvasLayer

func setup(p_player: VehicleController, p_race: RaceManager, p_track: SplineTrack):
	player_car = p_player
	race_mgr = p_race
	track = p_track
	
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer = CanvasLayer.new()
	hud_layer.name = "RaceHUDLayer"
	add_child(hud_layer)
	_build_ui()
	
	race_mgr.countdown_tick.connect(_on_countdown_tick)
	race_mgr.race_finished.connect(_on_race_finished)

func _build_ui():
	# 1. Top Left: Position & Lap inside crisp glassmorphic backing
	var tl_panel = PanelContainer.new()
	tl_panel.position = Vector2(24, 24)
	tl_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.05, 0.07, 0.11, 0.72)
	hud_style.border_width_left = 3
	hud_style.border_color = Color(1.0, 0.45, 0.06, 0.92)
	hud_style.content_margin_left = 14
	hud_style.content_margin_right = 14
	hud_style.content_margin_top = 8
	hud_style.content_margin_bottom = 8
	hud_style.corner_radius_top_left = 6
	hud_style.corner_radius_top_right = 6
	hud_style.corner_radius_bottom_left = 6
	hud_style.corner_radius_bottom_right = 6
	tl_panel.add_theme_stylebox_override("panel", hud_style)
	hud_layer.add_child(tl_panel)

	var top_left = VBoxContainer.new()
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl_panel.add_child(top_left)
	
	position_label = Label.new()
	position_label.text = "1ST / 6"
	position_label.add_theme_font_size_override("font_size", 40)
	position_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	top_left.add_child(position_label)
	
	lap_label = Label.new()
	lap_label.text = "LAP 1 / 3"
	lap_label.add_theme_font_size_override("font_size", 20)
	lap_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	top_left.add_child(lap_label)
	
	time_label = Label.new()
	time_label.text = "TIME: 0:00.00 | BEST: --:--.--"
	time_label.add_theme_font_size_override("font_size", 15)
	time_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	top_left.add_child(time_label)
	
	# 2. Bottom Right: Speedometer, Gear, Nitro & Health
	var br_panel = PanelContainer.new()
	br_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br_panel.offset_left = -330.0
	br_panel.offset_top = -126.0
	br_panel.offset_right = -24.0
	br_panel.offset_bottom = -24.0
	br_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br_panel.add_theme_stylebox_override("panel", hud_style)
	hud_layer.add_child(br_panel)

	var bottom_right = VBoxContainer.new()
	bottom_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br_panel.add_child(bottom_right)
	
	speed_label = Label.new()
	speed_label.text = "0 KM/H"
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.add_theme_font_size_override("font_size", 46)
	speed_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	bottom_right.add_child(speed_label)
	
	rpm_gear_label = Label.new()
	rpm_gear_label.text = "GEAR 1 | 900 RPM | NITRO 100%"
	rpm_gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rpm_gear_label.add_theme_font_size_override("font_size", 16)
	rpm_gear_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.14))
	bottom_right.add_child(rpm_gear_label)
	
	# 3. Center Screen: 3-2-1-GO Countdown Banner
	countdown_label = Label.new()
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	countdown_label.offset_left = -160.0
	countdown_label.offset_top = -80.0
	countdown_label.offset_right = 160.0
	countdown_label.offset_bottom = 80.0
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 96)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	countdown_label.visible = false
	hud_layer.add_child(countdown_label)
	
	# 4. Top Right: Dynamic 2D Minimap Radar (responsive PRESET_TOP_RIGHT anchoring)
	minimap_rect = Control.new()
	minimap_rect.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_rect.offset_left = -264.0
	minimap_rect.offset_top = 24.0
	minimap_rect.offset_right = -24.0
	minimap_rect.offset_bottom = 264.0
	minimap_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_rect.draw.connect(_draw_minimap)
	hud_layer.add_child(minimap_rect)
	
	# 5. Post-Race Results Modal Panel
	results_panel = PanelContainer.new()
	results_panel.set_anchors_preset(Control.PRESET_CENTER)
	results_panel.offset_left = -250.0
	results_panel.offset_top = -180.0
	results_panel.offset_right = 250.0
	results_panel.offset_bottom = 180.0
	results_panel.visible = false
	hud_layer.add_child(results_panel)
	
	var res_box = VBoxContainer.new()
	results_panel.add_child(res_box)
	
	var res_title = Label.new()
	res_title.text = "RACE FINISHED"
	res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_title.add_theme_font_size_override("font_size", 32)
	res_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
	res_box.add_child(res_title)
	
	results_label = Label.new()
	results_label.text = "Standings Loading..."
	results_label.add_theme_font_size_override("font_size", 16)
	res_box.add_child(results_label)

func _process(_delta: float):
	if not player_car or not race_mgr:
		return
		
	# Update Gauges
	speed_label.text = "%d KM/H" % int(player_car.speed_kmh)
	var gear_str = "R" if player_car.current_gear == 0 else str(player_car.current_gear)
	rpm_gear_label.text = "GEAR %s | %d RPM | NITRO %d%%" % [gear_str, int(player_car.engine_rpm), int(player_car.nitro_amount)]
	
	# Update Position & Laps
	var pos = race_mgr.get_player_position()
	var suffixes = ["TH", "ST", "ND", "RD", "TH", "TH", "TH"]
	var suf = suffixes[pos] if pos < suffixes.size() else "TH"
	position_label.text = "%d%s / %d" % [pos, suf, race_mgr.cars.size()]
	
	var prog = race_mgr.car_progress[player_car]
	lap_label.text = "LAP %d / %d" % [prog.lap, race_mgr.total_laps]
	
	# Update Timers
	var best_str = "--:--.--"
	if race_mgr.best_lap_time < 9000.0:
		best_str = _format_time(race_mgr.best_lap_time)
	time_label.text = "TIME: %s | BEST: %s" % [_format_time(race_mgr.current_lap_time), best_str]
	
	# Redraw Minimap
	minimap_rect.queue_redraw()

func _format_time(sec: float) -> String:
	var m = int(sec / 60.0)
	var s = int(sec) % 60
	var ms = int((sec - floor(sec)) * 100.0)
	return "%02d:%02d.%02d" % [m, s, ms]

func _draw_minimap():
	if not track or track.track_points.is_empty():
		return
		
	# Draw background
	minimap_rect.draw_circle(Vector2(120, 120), 115, Color(0.06, 0.08, 0.12, 0.85))
	minimap_rect.draw_arc(Vector2(120, 120), 115, 0, TAU, 32, Color(0.3, 0.4, 0.5, 0.6), 2.0)
	
	# Track bounds scaling (center around ~130, 0, -70)
	var center_x = 130.0
	var center_z = -55.0
	var scale_factor = 0.44
	
	var prev_screen_pt = Vector2.ZERO
	var first_screen_pt = Vector2.ZERO
	
	# Draw Track Outline
	for i in range(track.track_points.size()):
		var pt = track.track_points[i]
		var sx = 120 + ((pt.pos.x - center_x) * scale_factor)
		var sy = 120 + ((pt.pos.z - center_z) * scale_factor)
		var screen_pt = Vector2(sx, sy)
		
		if i > 0:
			minimap_rect.draw_line(prev_screen_pt, screen_pt, Color(0.35, 0.40, 0.48), 3.0)
		else:
			first_screen_pt = screen_pt
		prev_screen_pt = screen_pt
	minimap_rect.draw_line(prev_screen_pt, first_screen_pt, Color(0.35, 0.40, 0.48), 3.0)
	
	# Draw AI Car Blips (Red)
	for c in race_mgr.cars:
		if c == player_car:
			continue
		var sx = 120 + ((c.global_position.x - center_x) * scale_factor)
		var sy = 120 + ((c.global_position.z - center_z) * scale_factor)
		minimap_rect.draw_circle(Vector2(sx, sy), 4.5, Color(1.0, 0.2, 0.2))
		
	# Draw Player Blip (Bright Cyan / Yellow with direction pointer)
	var px = 120 + ((player_car.global_position.x - center_x) * scale_factor)
	var py = 120 + ((player_car.global_position.z - center_z) * scale_factor)
	minimap_rect.draw_circle(Vector2(px, py), 6.0, Color(0.0, 0.95, 1.0))

func _on_countdown_tick(count: int, text: String):
	if count < 0:
		countdown_label.visible = false
	else:
		countdown_label.visible = true
		countdown_label.text = text
		if count == 0:
			countdown_label.add_theme_color_override("font_color", Color(0.1, 1.0, 0.3))
		else:
			countdown_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))

func _on_race_finished(winner: VehicleController, standings: Array):
	results_panel.visible = true
	var p_pos = race_mgr.get_player_position()
	var text = "\nYOUR FINISH: %d%s\n\nSTANDINGS:\n" % [p_pos, ("ST" if p_pos == 1 else "ND" if p_pos == 2 else "RD" if p_pos == 3 else "TH")]
	
	for i in range(standings.size()):
		var c = standings[i]
		var name_str = "YOU (Sprinter R2)" if c == player_car else "Rival %d" % i
		text += " %d. %s\n" % [i + 1, name_str]
	
	text += "\nBASE PAYOUT: +800 CASH | XP: +350"
	results_label.text = text
