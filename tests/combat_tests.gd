# combat_tests.gd
# Headless verification of Stage 3 Combat: Weapons, ballistics, damage reception, and revenge system.
extends Node3D

const WeaponData = preload("res://scripts/weapons/weapon_data.gd")
const WeaponSystem = preload("res://scripts/weapons/weapon_system.gd")
const Projectile = preload("res://scripts/weapons/projectile.gd")
const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")

func _ready():
	print("\n=======================================================")
	print("       GRIDLETHAL STAGE 3 COMBAT VERIFICATION SUITE    ")
	print("=======================================================\n")
	
	var total_tests = 0
	var passed_tests = 0
	
	# Test 1: Arsenal Specifications
	total_tests += 1
	var weapons = WeaponData.WEAPONS
	if weapons.size() >= 10 and weapons.has("twin_mg") and weapons.has("rocket_pod") and weapons.has("mine_dropper"):
		print("[PASS] Test 1: Arsenal Specifications (10 Weapons validated across all slots)")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 1: Arsenal missing weapons!")
		
	# Test 2: Weapon Firing, Ammo & Heat Accumulation
	total_tests += 1
	var car1 = VehicleController.new()
	car1.car_id = "sprinter_r2"
	add_child(car1)
	
	var w_sys = WeaponSystem.new()
	car1.add_child(w_sys)
	w_sys.setup(car1, "twin_mg", "rocket_pod", "mine_dropper")
	
	var init_ammo = w_sys.ammo["twin_mg"]
	w_sys.fire_front()
	
	if w_sys.ammo["twin_mg"] == init_ammo - 1 and w_sys.heat["FRONT"] > 0.0:
		print("[PASS] Test 2: Weapon Firing, Ammo Consumption & Heat (Ammo: %d -> %d, Heat: %.3f)" % [
			init_ammo, w_sys.ammo["twin_mg"], w_sys.heat["FRONT"]
		])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 2: Weapon firing state failed!")
		
	# Test 3: Vehicle Damage Model & Health Depletion
	total_tests += 1
	var car2 = VehicleController.new()
	car2.car_id = "sprinter_r2"
	add_child(car2)
	
	var init_hp = car2.health
	car2.apply_damage(150.0, car2.global_position, car1)
	
	if car2.health == init_hp - 150.0 and car2.has_revenge_against == car1:
		print("[PASS] Test 3: Damage Model & AI Revenge Trigger (HP: %.0f -> %.0f, Revenge Target set)" % [
			init_hp, car2.health
		])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 3: Damage reception failed!")
		
	# Test 4: Fatal Damage & Charred Wreck State
	total_tests += 1
	car2.apply_damage(800.0, car2.global_position, car1)
	
	if car2.health == 0.0 and car2.is_wrecked and car2.respawn_timer > 0.0:
		print("[PASS] Test 4: Fatal Wreck & Respawn Timer (is_wrecked: true, respawn: %.1fs)" % car2.respawn_timer)
		passed_tests += 1
	else:
		printerr("[FAIL] Test 4: Wreck transition failed!")
		
	# Test 5: Projectile Ballistics & Velocity
	total_tests += 1
	var proj = Projectile.new()
	add_child(proj)
	proj.setup(Vector3.ZERO, Vector3.FORWARD, 100.0, 70.0, 5.0, car1)
	proj._physics_process(0.1) # 100ms
	
	if proj.global_position.length() > 5.0:
		print("[PASS] Test 5: Projectile Ballistics & Kinematics (Traveled: %.2fm in 0.1s)" % proj.global_position.length())
		passed_tests += 1
	else:
		printerr("[FAIL] Test 5: Projectile kinematics failed!")
		
	proj.queue_free()
	car1.queue_free()
	car2.queue_free()
	
	print("\n-------------------------------------------------------")
	print("STAGE 3 RESULTS: %d / %d TESTS PASSED" % [passed_tests, total_tests])
	print("-------------------------------------------------------\n")
	
	if passed_tests == total_tests:
		print("STAGE 3 ACCEPTANCE CHECKLIST: ALL PASS.\n")
		get_tree().quit(0)
	else:
		printerr("STAGE 3 ACCEPTANCE FAILED.\n")
		get_tree().quit(1)
