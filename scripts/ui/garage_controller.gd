# scripts/ui/garage_controller.gd
class_name GarageController
extends Node3D

const CarModelLoader = preload("res://scripts/vehicle/car_model_loader.gd")
const VisualPipeline = preload("res://scripts/core/visual_pipeline.gd")

@export var turntable_node: Node3D
@export var camera_node: Camera3D
@export var car_mount: Node3D

var save_manager: SaveManager
var current_car_mesh: Node3D
var active_tab: String = "showroom"
var preview_car_id: String = "sprinter_r2"
var orbit_yaw: float = 0.42
var orbit_pitch: float = 0.19
var orbit_dist: float = 4.95
var is_orbit_dragging: bool = false

# UI Nodes
@onready var ui_canvas: CanvasLayer = $CanvasLayer
@onready var label_cash: Label = $CanvasLayer/TopBar/MarginContainer/HBoxContainer/LabelCash
@onready var label_gold: Label = $CanvasLayer/TopBar/MarginContainer/HBoxContainer/LabelGold
@onready var label_scrap: Label = $CanvasLayer/TopBar/MarginContainer/HBoxContainer/LabelScrap
@onready var label_car_title: Label = $CanvasLayer/TopBar/MarginContainer/HBoxContainer/LabelCarTitle
@onready var content_container: Control = $CanvasLayer/MainPanel/ScrollContainer/ContentVBox

func _ready() -> void:
	save_manager = SaveManager.new()
	preview_car_id = save_manager.save_data.get("selected_car", "sprinter_r2")
	_spawn_preview_car(preview_car_id)
	_update_header()
	_render_showroom_tab()
	_update_orbit_camera()

	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		VisualPipeline.attach_horizon_compositor(we, 0.12, 0.10)
	var mats: Array[Material] = []
	VisualPipeline.collect_materials_from_node(self, mats)
	VisualPipeline.spawn_prewarm_batch(self, camera_node, mats)

	# Screenshot mode support
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	for arg: String in args:
		if arg == "--screenshot" or arg == "-screenshot":
			_take_garage_screenshot()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			is_orbit_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			orbit_dist = clampf(orbit_dist - 0.35, 3.2, 8.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			orbit_dist = clampf(orbit_dist + 0.35, 3.2, 8.5)
	elif event is InputEventMouseMotion and is_orbit_dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		orbit_yaw -= mm.relative.x * 0.008
		orbit_pitch = clampf(orbit_pitch + mm.relative.y * 0.006, 0.05, 0.65)
	elif event.is_action_pressed("pause_game"):
		_on_main_menu_pressed()

func _process(delta: float) -> void:
	if turntable_node and not is_orbit_dragging:
		turntable_node.rotate_y(delta * 0.28)
	_update_orbit_camera()

func _update_orbit_camera() -> void:
	if not camera_node:
		return
	var target := Vector3(0.0, 0.68, 0.0)
	var horiz: float = cos(orbit_pitch) * orbit_dist
	var cam_pos := Vector3(
		sin(orbit_yaw) * horiz,
		0.72 + sin(orbit_pitch) * orbit_dist,
		cos(orbit_yaw) * horiz
	)
	camera_node.position = cam_pos
	camera_node.look_at(target, Vector3.UP)

func _spawn_preview_car(car_id: String) -> void:
	if current_car_mesh:
		current_car_mesh.queue_free()
		current_car_mesh = null
		
	var owned: Dictionary = save_manager.save_data.get("owned_cars", {})
	var car_info: Dictionary = owned.get(car_id, {})
	var color_hex: String = str(car_info.get("paint_color", "#ee1808"))
	var paint_color := Color.from_string(color_hex, Color.RED)
	var finish: String = str(car_info.get("finish", "metallic"))
	var has_custom_paint: bool = bool(car_info.get("custom_painted", false))
	
	# Find vehicle data from data/vehicles.json or fallback
	var recipe: Dictionary = {}
	var file := FileAccess.open("res://data/vehicles.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
			var list: Array = json.data.get("vehicles", [])
			for v in list:
				if v.get("id") == car_id:
					recipe = v
					break
		file.close()
	if recipe.is_empty():
		recipe = {
			"id": car_id,
			"name": "Sprinter R2",
			"wheelbase": 2.45,
			"track_width": 1.76,
			"mass": 1050.0,
			"model_path": "res://assets/models/cars/subaru_sti.glb"
		}

	var host: Node3D = car_mount if car_mount else self
	if recipe.has("model_path") and FileAccess.file_exists(str(recipe["model_path"])):
		var showcase := CarModelLoader.load_car_visuals(host, recipe)
		if showcase:
			if has_custom_paint:
				CarModelLoader.apply_custom_paint(showcase, paint_color, finish)
			current_car_mesh = showcase
			return

	var proc := ProceduralCarMesh.new()
	proc.build_car(recipe)
	if proc.body_mesh_instance and proc.body_mesh_instance.material_override:
		var mat: Material = proc.body_mesh_instance.material_override
		if mat is ShaderMaterial:
			mat.set_shader_parameter("base_color", paint_color)
	host.add_child(proc)
	current_car_mesh = proc

func _update_header() -> void:
	if not label_cash or not save_manager:
		return
	var d := save_manager.save_data
	label_cash.text = "CASH: $%s" % _format_number(int(d.get("cash", 0)))
	label_gold.text = "GOLD: %d" % int(d.get("gold", 0))
	label_scrap.text = "SCRAP: %d" % int(d.get("scrap", 0))
	
	var car_recipe: Dictionary = GarageData.CAR_RECIPES.get(preview_car_id, {})
	var car_name: String = car_recipe.get("name", "Sprinter R2")
	var car_class: String = car_recipe.get("class", "Rally")
	var stats := GarageData.compute_car_stats(preview_car_id, (d.get("owned_cars", {}).get(preview_car_id, {})).get("upgrades", {}))
	label_car_title.text = "%s [%s CLASS | RATING %s]" % [car_name.to_upper(), car_class.to_upper(), stats.get("class_rating", "D")]

func _clear_content() -> void:
	if not content_container:
		return
	for child in content_container.get_children():
		child.queue_free()

func _render_showroom_tab() -> void:
	active_tab = "showroom"
	_clear_content()
	if not content_container:
		return
		
	var d := save_manager.save_data
	var owned: Dictionary = d.get("owned_cars", {})
	var selected_car: String = d.get("selected_car", "sprinter_r2")
	
	for car_id in GarageData.CAR_RECIPES.keys():
		var recipe: Dictionary = GarageData.CAR_RECIPES[car_id]
		var is_owned: bool = owned.has(car_id)
		var is_selected: bool = (car_id == selected_car)
		var stats := GarageData.compute_car_stats(car_id, (owned.get(car_id, {})).get("upgrades", {}))
		
		var panel := PanelContainer.new()
		var hbox := HBoxContainer.new()
		panel.add_child(hbox)
		
		var vbox_info := VBoxContainer.new()
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var lbl_title := Label.new()
		lbl_title.text = "%s (%s Class) - Perk: %s" % [recipe["name"], recipe["class"], recipe["perk"]]
		lbl_title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.0) if is_selected else Color.WHITE)
		vbox_info.add_child(lbl_title)
		
		var lbl_stats := Label.new()
		lbl_stats.text = "PWR: %.0f kW | TOP: %.0f km/h | ARMOUR: %.0f HP | MASS: %.0f kg | 0-100: %.1fs" % [
			stats["power_kw"], stats["top_speed"], stats["health"], stats["mass"], recipe["accel_0_100"]
		]
		vbox_info.add_child(lbl_stats)
		hbox.add_child(vbox_info)
		
		var btn_prev := Button.new()
		btn_prev.custom_minimum_size = Vector2(100, 40)
		btn_prev.text = "VIEW 3D"
		btn_prev.pressed.connect(func(): _preview_car_only(car_id))
		hbox.add_child(btn_prev)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 40)
		if is_selected:
			btn.text = "ACTIVE"
			btn.disabled = true
		elif is_owned:
			btn.text = "SELECT"
			btn.pressed.connect(func(): _select_car(car_id))
		else:
			var price: int = recipe.get("price", 0)
			btn.text = "BUY $%s" % _format_number(price)
			btn.disabled = not save_manager.can_afford(price)
			btn.pressed.connect(func(): _buy_car(car_id, price))
			
		hbox.add_child(btn)
		content_container.add_child(panel)

func _render_upgrades_tab() -> void:
	active_tab = "upgrades"
	_clear_content()
	if not content_container:
		return
		
	var d := save_manager.save_data
	var owned: Dictionary = d.get("owned_cars", {})
	var car_info: Dictionary = owned.get(preview_car_id, {})
	var upgrades: Dictionary = car_info.get("upgrades", {})
	var recipe: Dictionary = GarageData.CAR_RECIPES.get(preview_car_id, {})
	var base_price: int = recipe.get("price", 15000)
	
	for cat_id in GarageData.UPGRADE_CATEGORIES.keys():
		var cat_data: Dictionary = GarageData.UPGRADE_CATEGORIES[cat_id]
		var tier: int = int(upgrades.get(cat_id, 0))
		var is_max: bool = (tier >= 5)
		var next_cost: int = GarageData.calculate_upgrade_cost(base_price, cat_id, tier + 1)
		
		var panel := PanelContainer.new()
		var hbox := HBoxContainer.new()
		panel.add_child(hbox)
		
		var vbox_info := VBoxContainer.new()
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var lbl_name := Label.new()
		lbl_name.text = "%s [Tier %d / 5]" % [cat_data["name"], tier]
		vbox_info.add_child(lbl_name)
		
		var progress := ProgressBar.new()
		progress.min_value = 0
		progress.max_value = 5
		progress.value = tier
		progress.show_percentage = false
		progress.custom_minimum_size = Vector2(200, 16)
		vbox_info.add_child(progress)
		hbox.add_child(vbox_info)
		
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 40)
		if is_max:
			btn.text = "MAXED"
			btn.disabled = true
		else:
			btn.text = "UPGRADE $%s" % _format_number(next_cost)
			btn.disabled = not save_manager.can_afford(next_cost)
			btn.pressed.connect(func(): _buy_upgrade(preview_car_id, cat_id, next_cost))
			
		hbox.add_child(btn)
		content_container.add_child(panel)

func _render_customise_tab() -> void:
	active_tab = "customise"
	_clear_content()
	if not content_container:
		return
		
	var d := save_manager.save_data
	var owned: Dictionary = d.get("owned_cars", {})
	var car_info: Dictionary = owned.get(preview_car_id, {})
	
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	
	var lbl_color := Label.new()
	lbl_color.text = "PAINT COLOR SELECTION"
	vbox.add_child(lbl_color)
	
	var color_palette := [
		"#ee1808", "#f23518", "#189bee", "#24d436", "#ecb414",
		"#a828e0", "#ffffff", "#111111", "#ff5500", "#00ffcc"
	]
	var hbox_colors := HBoxContainer.new()
	for hex in color_palette:
		var btn_c := Button.new()
		btn_c.custom_minimum_size = Vector2(40, 40)
		btn_c.text = "■"
		btn_c.add_theme_color_override("font_color", Color.from_string(hex, Color.WHITE))
		btn_c.pressed.connect(func(): _set_paint_color(hex))
		hbox_colors.add_child(btn_c)
	vbox.add_child(hbox_colors)
	
	var lbl_finish := Label.new()
	lbl_finish.text = "\nFINISH & MATERIAL COATING"
	vbox.add_child(lbl_finish)
	
	var hbox_finish := HBoxContainer.new()
	var finishes := ["metallic", "gloss", "satin", "matte", "pearl"]
	for f in finishes:
		var btn_f := Button.new()
		btn_f.text = f.to_upper()
		btn_f.pressed.connect(func(): _set_finish(f))
		hbox_finish.add_child(btn_f)
	vbox.add_child(hbox_finish)
	
	content_container.add_child(panel)

func _render_drivers_tab() -> void:
	active_tab = "drivers"
	_clear_content()
	if not content_container:
		return
		
	var d := save_manager.save_data
	var active_driver: String = d.get("selected_driver", "hex")
	
	for d_id in GarageData.DRIVERS.keys():
		var info: Dictionary = GarageData.DRIVERS[d_id]
		var is_active: bool = (d_id == active_driver)
		
		var panel := PanelContainer.new()
		var hbox := HBoxContainer.new()
		panel.add_child(hbox)
		
		var vbox_info := VBoxContainer.new()
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var lbl_name := Label.new()
		lbl_name.text = "%s - \"%s\"" % [info["name"], info["title"]]
		lbl_name.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0) if is_active else Color.WHITE)
		vbox_info.add_child(lbl_name)
		
		var lbl_perk := Label.new()
		lbl_perk.text = "Perk: %s" % info["perk"]
		vbox_info.add_child(lbl_perk)
		hbox.add_child(vbox_info)
		
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 40)
		btn.text = "ASSIGNED" if is_active else "ASSIGN"
		btn.disabled = is_active
		btn.pressed.connect(func(): _assign_driver(d_id))
		hbox.add_child(btn)
		
		content_container.add_child(panel)

func _select_car(car_id: String) -> void:
	save_manager.save_data["selected_car"] = car_id
	save_manager.save_slot(save_manager.current_slot)
	preview_car_id = car_id
	_spawn_preview_car(car_id)
	_update_header()
	_render_showroom_tab()

func _buy_car(car_id: String, price: int) -> void:
	if save_manager.buy_car(car_id, price):
		_select_car(car_id)

func _buy_upgrade(car_id: String, category: String, cost: int) -> void:
	if save_manager.buy_upgrade(car_id, category, cost):
		_update_header()
		_render_upgrades_tab()

func _preview_car_only(car_id: String) -> void:
	preview_car_id = car_id
	_spawn_preview_car(car_id)
	_update_header()

func _set_paint_color(hex: String) -> void:
	var owned: Dictionary = save_manager.save_data.get("owned_cars", {})
	if owned.has(preview_car_id):
		owned[preview_car_id]["paint_color"] = hex
		owned[preview_car_id]["custom_painted"] = true
		save_manager.save_slot(save_manager.current_slot)
		_spawn_preview_car(preview_car_id)

func _set_finish(finish: String) -> void:
	var owned: Dictionary = save_manager.save_data.get("owned_cars", {})
	if owned.has(preview_car_id):
		owned[preview_car_id]["finish"] = finish
		owned[preview_car_id]["custom_painted"] = true
		save_manager.save_slot(save_manager.current_slot)
		_spawn_preview_car(preview_car_id)

func _on_open_world_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/open_world.tscn")

func _on_race_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/track_test.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _assign_driver(driver_id: String) -> void:
	save_manager.save_data["selected_driver"] = driver_id
	save_manager.save_slot(save_manager.current_slot)
	_render_drivers_tab()

func _format_number(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return out

func _take_garage_screenshot() -> void:
	await get_tree().create_timer(1.0).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var dir := DirAccess.open("res://")
			if dir and not dir.dir_exists("build/screenshots"):
				dir.make_dir_recursive("build/screenshots")
			img.save_png("res://build/screenshots/m6_garage.png")
			print("[SCREENSHOT] Saved m6_garage.png")
	get_tree().quit(0)
