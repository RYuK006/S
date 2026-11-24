# projectile.gd
# Ballistic rocket and missile projectile with sub-stepped raycast collision, splash damage and blast impulse.
class_name Projectile
extends Node3D

var shooter_vehicle = null
var velocity: Vector3 = Vector3.ZERO
var damage: float = 70.0
var splash_radius: float = 5.0
var max_lifetime: float = 4.0
var lifetime: float = 0.0

var is_homing: bool = false
var homing_target = null
var homing_turn_rate: float = 4.5

var mesh_inst: MeshInstance3D

func setup(origin: Vector3, dir: Vector3, speed: float, p_damage: float, p_splash: float, shooter = null, target = null):
	global_position = origin
	velocity = dir.normalized() * speed
	damage = p_damage
	splash_radius = p_splash
	shooter_vehicle = shooter
	homing_target = target
	is_homing = (target != null)
	
	look_at(global_position + velocity, Vector3.UP)
	
	# Procedural Rocket Model
	mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 0.65
	mesh_inst.mesh = cyl
	mesh_inst.rotation.x = deg_to_rad(90)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.22)
	mat.metallic = 0.8
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1) # Rocket motor exhaust glow
	mat.emission_energy_multiplier = 3.0
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func _physics_process(delta: float):
	lifetime += delta
	if lifetime >= max_lifetime:
		_detonate()
		return
		
	# Homing steering
	if is_homing and is_instance_valid(homing_target):
		var to_target = (homing_target.global_position - global_position).normalized()
		velocity = velocity.slerp(to_target * velocity.length(), delta * homing_turn_rate)
		look_at(global_position + velocity, Vector3.UP)
	
	# Sub-stepped raycast collision detection
	var step_move = velocity * delta
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + step_move)
	
	# Ignore shooter
	if shooter_vehicle:
		query.exclude = [shooter_vehicle.get_rid()]
		
	var hit = space_state.intersect_ray(query)
	if hit:
		global_position = hit.position
		_on_hit(hit.collider, hit.position, hit.normal)
	else:
		global_position += step_move

func _on_hit(collider: Object, hit_point: Vector3, hit_normal: Vector3):
	# Direct hit damage
	if collider and collider.has_method("apply_damage"):
		collider.apply_damage(damage, hit_point, shooter_vehicle)
		
	_detonate()

func _detonate():
	# Explosive splash radius check
	var space_state = get_world_3d().direct_space_state
	var shape_query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = splash_radius
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis(), global_position)
	
	var hits = space_state.intersect_shape(shape_query)
	for h in hits:
		var col = h.collider
		if col and col != shooter_vehicle:
			var d = global_position.distance_to(col.global_position)
			var falloff = 1.0 - clamp(d / splash_radius, 0.0, 1.0)
			var splash_dmg = damage * falloff * 0.75
			
			if col.has_method("apply_damage"):
				col.apply_damage(splash_dmg, global_position, shooter_vehicle)
				
			# Apply physical blast impulse
			if col is RigidBody3D:
				var blast_dir = (col.global_position - global_position).normalized()
				var blast_impulse = blast_dir * (falloff * 4500.0) + Vector3.UP * (falloff * 2500.0)
				col.apply_central_impulse(blast_impulse)
				
	queue_free()
