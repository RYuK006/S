# weapon_system.gd
# Manages car weapons: firing logic, ammo reserves, overheat cooling, auto-aim assist and recoil.
class_name WeaponSystem
extends Node3D

const WeaponData = preload("res://scripts/weapons/weapon_data.gd")
const Projectile = preload("res://scripts/weapons/projectile.gd")
const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")

var vehicle: VehicleController

# Equipped weapon IDs
var front_weapon_id: String = "twin_mg"
var roof_weapon_id: String = "rocket_pod"
var rear_weapon_id: String = "mine_dropper"

# State per equipped slot
var ammo: Dictionary = {}
var cooldowns: Dictionary = {}
var heat: Dictionary = { "FRONT": 0.0, "ROOF": 0.0 }
var is_overheated: Dictionary = { "FRONT": false, "ROOF": false }

# Lock-on tracking for homing missiles
var current_target = null
var lock_timer: float = 0.0
var has_lock: bool = false

# Procedural weapon visuals
var front_mesh: Node3D
var roof_mesh: Node3D
var rear_mesh: Node3D

func setup(p_vehicle: VehicleController, front_id: String, roof_id: String, rear_id: String):
	vehicle = p_vehicle
	front_weapon_id = front_id
	roof_weapon_id = roof_id
	rear_weapon_id = rear_id
	
	for slot_id in [front_weapon_id, roof_weapon_id, rear_weapon_id]:
		var data = WeaponData.WEAPONS[slot_id]
		ammo[slot_id] = data.max_ammo
		cooldowns[slot_id] = 0.0
		
	_build_mount_visuals()

func _build_mount_visuals():
	# 1. Front Gun Barrels
	front_mesh = Node3D.new()
	front_mesh.position = Vector3(0, 0.52, -1.85)
	for s in [-0.22, 0.22]:
		var barrel = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 0.6
		barrel.mesh = cyl
		barrel.rotation.x = deg_to_rad(90)
		barrel.position = Vector3(s, 0, 0)
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.12, 0.14)
		mat.metallic = 0.95
		mat.roughness = 0.2
		barrel.material_override = mat
		front_mesh.add_child(barrel)
	add_child(front_mesh)
	
	# 2. Roof Rocket Pod (4 tubes)
	roof_mesh = Node3D.new()
	roof_mesh.position = Vector3(0, 1.15, 0.2)
	var pod_base = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.55, 0.22, 0.75)
	pod_base.mesh = box
	var pod_mat = StandardMaterial3D.new()
	pod_mat.albedo_color = Color(0.18, 0.18, 0.20)
	pod_mat.metallic = 0.8
	pod_base.material_override = pod_mat
	roof_mesh.add_child(pod_base)
	add_child(roof_mesh)

func _physics_process(delta: float):
	# Update cooldowns
	for k in cooldowns.keys():
		if cooldowns[k] > 0.0:
			cooldowns[k] = max(0.0, cooldowns[k] - delta)
			
	# Cool down heat
	for slot in ["FRONT", "ROOF"]:
		if heat[slot] > 0.0:
			heat[slot] = max(0.0, heat[slot] - delta * 0.25)
			if heat[slot] < 0.2:
				is_overheated[slot] = false

func fire_front():
	var data = WeaponData.WEAPONS[front_weapon_id]
	if cooldowns[front_weapon_id] > 0.0 or ammo[front_weapon_id] <= 0 or is_overheated["FRONT"]:
		return
		
	cooldowns[front_weapon_id] = 1.0 / data.rate_of_fire
	ammo[front_weapon_id] -= 1
	heat["FRONT"] += data.heat_per_shot
	if heat["FRONT"] >= 1.0:
		is_overheated["FRONT"] = true
		
	# Recoil impulse
	var v_trans = vehicle.global_transform if vehicle.is_inside_tree() else vehicle.transform
	var forward = -v_trans.basis.z.normalized()
	if vehicle.is_inside_tree():
		vehicle.apply_central_impulse(-forward * 120.0)
	
	# Auto-aim assist: check for enemy inside forward cone
	var fire_dir = forward
	var nearest_enemy = _find_nearest_target(data.range_m, deg_to_rad(14.0))
	if nearest_enemy:
		var enemy_pos = nearest_enemy.global_position if nearest_enemy.is_inside_tree() else nearest_enemy.position
		var my_pos = global_position if is_inside_tree() else position
		fire_dir = (enemy_pos - my_pos).normalized()
		
	# Raycast hitscan test
	if not is_inside_tree() or not get_world_3d():
		return
		
	var space_state = get_world_3d().direct_space_state
	var start_pos = front_mesh.global_position if front_mesh.is_inside_tree() else front_mesh.position
	var end_pos = start_pos + (fire_dir * data.range_m)
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.exclude = [vehicle.get_rid()]
	var hit = space_state.intersect_ray(query)
	if hit:
		if hit.collider and hit.collider.has_method("apply_damage"):
			hit.collider.apply_damage(data.damage, hit.position, vehicle)

func fire_roof():
	var data = WeaponData.WEAPONS[roof_weapon_id]
	if cooldowns[roof_weapon_id] > 0.0 or ammo[roof_weapon_id] <= 0:
		return
		
	cooldowns[roof_weapon_id] = 1.0 / data.rate_of_fire
	ammo[roof_weapon_id] -= 1
	
	var forward = -vehicle.global_transform.basis.z.normalized()
	var spawn_pos = roof_mesh.global_position + (forward * 0.6)
	
	var proj = Projectile.new()
	get_tree().root.add_child(proj)
	proj.setup(spawn_pos, forward, data.projectile_speed, data.damage, data.splash_radius, vehicle, current_target)

func fire_rear():
	var data = WeaponData.WEAPONS[rear_weapon_id]
	if cooldowns[rear_weapon_id] > 0.0 or ammo[rear_weapon_id] <= 0:
		return
		
	cooldowns[rear_weapon_id] = 1.0 / data.rate_of_fire
	ammo[rear_weapon_id] -= 1
	
	var backward = vehicle.global_transform.basis.z.normalized()
	var spawn_pos = vehicle.global_position + (backward * 2.2) + Vector3(0, 0.2, 0)
	
	# Spawn static mine body
	var mine = StaticBody3D.new()
	mine.position = spawn_pos
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.5
	col.shape = sphere
	mine.add_child(col)
	
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 0.15
	mesh.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.1, 0.1) # Red blinking mine
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.1)
	mesh.material_override = mat
	mine.add_child(mesh)
	
	get_tree().root.add_child(mine)

func _find_nearest_target(max_range: float, max_angle: float):
	if not is_inside_tree() or not get_tree():
		return null
	var v_trans = vehicle.global_transform if vehicle.is_inside_tree() else vehicle.transform
	var forward = -v_trans.basis.z.normalized()
	var my_pos = global_position if is_inside_tree() else position
	var best_car = null
	var min_dist = max_range
	
	for node in get_tree().get_nodes_in_group("vehicles"):
		if node != vehicle and node is VehicleController:
			var n_pos = node.global_position if node.is_inside_tree() else node.position
			var to_node = n_pos - my_pos
			var d = to_node.length()
			if d < min_dist:
				var angle = forward.angle_to(to_node.normalized())
				if angle <= max_angle:
					min_dist = d
					best_car = node
	return best_car
