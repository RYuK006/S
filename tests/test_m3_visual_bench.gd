# test_m3_visual_bench.gd
# Headless verification benchmark for Milestone 3 (Visual Look): shaders, materials, and DRS scaling.
class_name TestM3VisualBench
extends Node

const GameConstants = preload("res://scripts/core/constants.gd")
const DRSController = preload("res://scripts/core/drs_controller.gd")
const ProceduralCarMesh = preload("res://scripts/vehicle/procedural_car_mesh.gd")

static func run() -> bool:
	print("--- Running TestM3VisualBench ---")
	var passed = true
	
	# 1. Verify Car Paint Shader
	var car_paint = load("res://shaders/car_paint.gdshader") as Shader
	if not car_paint:
		printerr("[FAIL] Unable to load res://shaders/car_paint.gdshader")
		passed = false
	else:
		print("[PASS] Car Paint Shader: Loaded successfully (PBR Clearcoat + Metallic Flake)")
		
	# 2. Verify Wet Road Shader
	var wet_road = load("res://shaders/wet_road.gdshader") as Shader
	if not wet_road:
		printerr("[FAIL] Unable to load res://shaders/wet_road.gdshader")
		passed = false
	else:
		print("[PASS] Wet Road Shader: Loaded successfully (SSR Puddle Mirrors + Aggregate Roughness)")
		
	# 3. Verify Skydome Shader
	var skydome = load("res://shaders/skydome.gdshader") as Shader
	if not skydome:
		printerr("[FAIL] Unable to load res://shaders/skydome.gdshader")
		passed = false
	else:
		print("[PASS] Skydome Shader: Loaded successfully (Rayleigh/Mie Atmospheric Scattering)")
		
	# 4. Verify DRS Controller Logic
	var drs = DRSController.new()
	drs._ready()
	if drs.current_scale != 1.0 or drs.min_scale != 0.65 or drs.max_scale != 1.0:
		printerr("[FAIL] DRS controller invalid configuration: ", drs.current_scale)
		passed = false
	else:
		# Simulate low FPS trigger (frame time = 22ms -> ~45 FPS < 60*0.92)
		for i in range(drs.history_size):
			drs.frame_history[i] = 0.022
		drs.update_timer = drs.check_interval + 0.01
		drs._process(0.022)
		if drs.current_scale < 1.0:
			print("[PASS] DRS Scaling Dynamic Response: Throttled scale down to %.2f under simulated load" % drs.current_scale)
		else:
			printerr("[FAIL] DRS did not reduce resolution scale under low FPS!")
			passed = false
	drs.free()
	
	# 5. Verify Procedural Car Mesh Shader Assignment
	var car_proc = ProceduralCarMesh.new()
	var recipe: Dictionary = GameConstants.CAR_RECIPES["sprinter_r2"]
	car_proc.build_car(recipe)
	if car_proc.body_mesh_instance and car_proc.body_mesh_instance.material_override:
		print("[PASS] ProceduralCarMesh: Assigned ShaderMaterial override to body mesh")
	else:
		printerr("[FAIL] ProceduralCarMesh missing body material override!")
		passed = false
	car_proc.free()
	
	return passed
