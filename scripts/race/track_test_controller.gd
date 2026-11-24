# track_test_controller.gd
# Controller for Track Test Scene: initializes spline track, player car, AI rivals, race manager, cameras and HUD.
class_name TrackTestController
extends Node3D

const RaceManager = preload("res://scripts/race/race_manager.gd")
const RaceHUD = preload("res://scripts/ui/race_hud.gd")
const AIDriver = preload("res://scripts/ai/ai_driver.gd")
const WeaponSystem = preload("res://scripts/weapons/weapon_system.gd")
const TrackPickup = preload("res://scripts/race/pickups.gd")

@onready var spline_track: SplineTrack = $SplineTrack
@onready var player_vehicle: VehicleController = $PlayerVehicle
@onready var camera_rig: CameraRig = $CameraRig
@onready var audio_engine: ProceduralAudioEngine = $ProceduralAudioEngine
@onready var debug_overlay: DebugOverlay = $DebugOverlay

var race_mgr: RaceManager
var race_hud: RaceHUD
var ai_cars: Array[VehicleController] = []
var player_weapons: WeaponSystem

var screenshot_mode: bool = false
var screenshot_timer: float = 0.5

func _ready():
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for arg in args:
		if arg == "--screenshot":
			screenshot_mode = true
			
	# 1. Setup circuit geometry
	if spline_track:
		spline_track.setup_circuit()
		
	# 2. Position player vehicle on starting grid & equip weapons
	if player_vehicle:
		player_vehicle.global_position = Vector3(0, 0.8, 0)
		player_vehicle.global_rotation = Vector3.ZERO
		if debug_overlay:
			debug_overlay.set_target_vehicle(player_vehicle)
		if camera_rig:
			camera_rig.target_vehicle = player_vehicle
			
		player_weapons = WeaponSystem.new()
		player_vehicle.add_child(player_weapons)
		player_weapons.setup(player_vehicle, "twin_mg", "rocket_pod", "mine_dropper")
			
	# 3. Spawn 5 AI rivals on starting grid
	_spawn_ai_rivals()
	
	# 4. Spawn Track Pickups
	_spawn_pickups()
	
	# 5. Setup Race Manager & HUD
	race_mgr = RaceManager.new()
	add_child(race_mgr)
	race_mgr.setup_race(spline_track, player_vehicle, ai_cars, 3)
	
	race_hud = RaceHUD.new()
	add_child(race_hud)
	race_hud.setup(player_vehicle, race_mgr, spline_track)

func _spawn_ai_rivals():
	var rivals = [
		{ "id": "dust_viper", "name": "Viktor 'Rotor' Hale", "style": "Aggressive", "pos": Vector3(3.5, 0.8, 12.0), "front": "heavy_mg", "roof": "homing_missile" },
		{ "id": "gravel_fang", "name": "Mina Cross", "style": "Tactical", "pos": Vector3(-3.5, 0.8, 24.0), "front": "twin_mg", "roof": "rocket_pod" },
		{ "id": "dune_reaper", "name": "Dozer Okafor", "style": "Bully", "pos": Vector3(3.5, 0.8, 36.0), "front": "shotgun_cannon", "roof": "rocket_pod" },
		{ "id": "sand_striker", "name": "Lena Vash", "style": "Drifter", "pos": Vector3(-3.5, 0.8, 48.0), "front": "twin_mg", "roof": "homing_missile" },
		{ "id": "phantom_gt", "name": "'Hollow' Pike", "style": "Trickster", "pos": Vector3(3.5, 0.8, 60.0), "front": "heavy_mg", "roof": "rocket_pod" }
	]
	
	for r in rivals:
		var ai_car = VehicleController.new()
		ai_car.car_id = r.id
		ai_car.name = "AI_" + r.id
		add_child(ai_car)
		ai_car.global_position = r.pos
		ai_car.global_rotation = Vector3.ZERO
		ai_cars.append(ai_car)
		
		var driver = AIDriver.new()
		ai_car.add_child(driver)
		driver.setup(ai_car, spline_track, r.name, r.style)
		
		var ai_w = WeaponSystem.new()
		ai_car.add_child(ai_w)
		ai_w.setup(ai_car, r.front, r.roof, "mine_dropper")

func _spawn_pickups():
	if not spline_track or spline_track.track_points.size() < 60:
		return
	var pickup_types = [
		TrackPickup.PickupType.REPAIR,
		TrackPickup.PickupType.AMMO,
		TrackPickup.PickupType.NITRO,
		TrackPickup.PickupType.REPAIR,
		TrackPickup.PickupType.AMMO,
		TrackPickup.PickupType.NITRO
	]
	var step = spline_track.track_points.size() / pickup_types.size()
	for i in range(pickup_types.size()):
		var pt = spline_track.track_points[i * step]
		var p = TrackPickup.new()
		p.type = pickup_types[i]
		add_child(p)
		p.position = pt.pos + Vector3(0, 1.2, 0)

func _physics_process(_delta: float):
	if not player_vehicle:
		return
		
	# Player weapon firing inputs
	if player_weapons:
		if Input.is_action_pressed("fire_primary"):
			player_weapons.fire_front()
		if Input.is_action_just_pressed("fire_turret"):
			player_weapons.fire_roof()
		if Input.is_action_just_pressed("fire_rear"):
			player_weapons.fire_rear()
		
	# Feed audio engine
	if audio_engine:
		var max_slip: float = 0.0
		var surface: String = "asphalt_dry"
		for w in player_vehicle.wheels:
			var slip = abs(w.slip_angle) + abs(w.slip_ratio)
			if slip > max_slip:
				max_slip = slip
			if w.is_grounded:
				surface = w.surface_type
		audio_engine.update_parameters(
			player_vehicle.engine_rpm,
			player_vehicle.throttle_input,
			player_vehicle.turbo_boost,
			max_slip,
			surface
		)

func _process(delta: float):
	if screenshot_mode:
		screenshot_timer -= delta
		if screenshot_timer <= 0.0:
			_capture_screenshot()
			get_tree().quit(0)

func _capture_screenshot():
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("build/screenshots"):
		dir.make_dir_recursive("build/screenshots")
		
	var viewport = get_viewport()
	if viewport:
		var tex = viewport.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				img.save_png("build/screenshots/m5_combat.png")
				print("[SCREENSHOT] Successfully saved build/screenshots/m5_combat.png")
				return
	print("[SCREENSHOT] Completed frame capture pass")
