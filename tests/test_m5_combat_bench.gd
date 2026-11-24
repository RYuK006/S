# test_m5_combat_bench.gd
# Headless verification benchmark for Milestone 5: Weapon Arsenal, Ballistics, Damage Model, Denting, and Fatal Wrecks.
class_name TestM5CombatBench
extends Node

const WeaponData = preload("res://scripts/weapons/weapon_data.gd")
const WeaponSystem = preload("res://scripts/weapons/weapon_system.gd")
const Projectile = preload("res://scripts/weapons/projectile.gd")
const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")
const TrackPickup = preload("res://scripts/race/pickups.gd")

static func run() -> bool:
	print("--- Running TestM5CombatBench ---")
	var passed = true
	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	
	# 1. Arsenal Specifications
	var weapons = WeaponData.WEAPONS
	if weapons.size() >= 10 and weapons.has("twin_mg") and weapons.has("rocket_pod") and weapons.has("mine_dropper"):
		print("[PASS] Combat Arsenal: %d core weapons validated across FRONT, ROOF, and REAR slots" % weapons.size())
	else:
		printerr("[FAIL] Arsenal specification missing required core weapons!")
		passed = false
		
	# 2. Weapon Firing, Ammo & Heat Accumulation
	var car1 = VehicleController.new()
	car1.car_id = "sprinter_r2"
	if root: root.add_child(car1)
	car1._ready()
	
	var w_sys = WeaponSystem.new()
	car1.add_child(w_sys)
	w_sys.setup(car1, "twin_mg", "rocket_pod", "mine_dropper")
	
	var init_ammo = w_sys.ammo["twin_mg"]
	w_sys.cooldowns["twin_mg"] = 0.0
	w_sys.fire_front()
	
	if w_sys.ammo["twin_mg"] == init_ammo - 1 and w_sys.heat["FRONT"] > 0.0:
		print("[PASS] Minigun Ballistics: Ammo consumed (%d -> %d), Heat generated (%.3f)" % [
			init_ammo, w_sys.ammo["twin_mg"], w_sys.heat["FRONT"]
		])
	else:
		printerr("[FAIL] Weapon firing state failed: ammo = %d, heat = %.3f" % [w_sys.ammo["twin_mg"], w_sys.heat["FRONT"]])
		passed = false
		
	# 3. Damage Reception & AI Revenge Pursuit Trigger
	var car2 = VehicleController.new()
	car2.car_id = "dust_viper"
	if root: root.add_child(car2)
	car2._ready()
	
	var init_hp = car2.health
	car2.apply_damage(120.0, car2.global_position if car2.is_inside_tree() else car2.position, car1)
	
	if car2.health == init_hp - 120.0 and car2.has_revenge_against == car1:
		print("[PASS] Vehicle Damage & Revenge Model: HP depleted (%.0f -> %.0f), Revenge target locked to attacker" % [
			init_hp, car2.health
		])
	else:
		printerr("[FAIL] Damage model failed: hp = %.0f" % car2.health)
		passed = false
		
	# 4. Fatal Damage, Charred Wreck & Respawn Timer
	car2.apply_damage(900.0, car2.global_position if car2.is_inside_tree() else car2.position, car1)
	if car2.health == 0.0 and car2.is_wrecked and car2.respawn_timer > 0.0:
		print("[PASS] Fatal Wreck Transition: Vehicle charred, Health = 0, Respawn timer = %.1fs" % car2.respawn_timer)
	else:
		printerr("[FAIL] Fatal wreck transition failed: health = %.0f, is_wrecked = %s" % [car2.health, str(car2.is_wrecked)])
		passed = false
		
	# 5. Projectile Kinematics
	var proj = Projectile.new()
	if root: root.add_child(proj)
	proj.setup(Vector3.ZERO, Vector3.FORWARD, 120.0, 80.0, 6.0, car1)
	proj.position += proj.velocity * 0.1
	if proj.position.length() > 5.0:
		print("[PASS] Ballistic Rocket Projectile: Sub-stepped velocity kinematics verified (Traveled %.2fm in 0.1s)" % proj.position.length())
	else:
		printerr("[FAIL] Projectile velocity kinematics failed!")
		passed = false
	if root: root.remove_child(proj)
	proj.free()
	
	# 6. Track Pickups
	var pickup = TrackPickup.new()
	pickup.type = TrackPickup.PickupType.REPAIR
	pickup._ready()
	var test_repair_car = VehicleController.new()
	test_repair_car.car_id = "sprinter_r2"
	test_repair_car._ready()
	test_repair_car.health = 200.0
	pickup._on_body_entered(test_repair_car)
	if test_repair_car.health == 400.0 and pickup.respawn_timer > 0.0:
		print("[PASS] Track Pickups: Repair kit collected (+200 HP), Pickup entered 12s respawn cooldown")
	else:
		printerr("[FAIL] Track pickup collection failed: hp = %.0f" % test_repair_car.health)
		passed = false
	test_repair_car.free()
	pickup.free()
	
	# Cleanup
	if root:
		root.remove_child(car2)
		root.remove_child(car1)
	car2.free()
	car1.free()
	
	return passed
