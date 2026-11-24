# pickups.gd
# Interactive track pickups: Repair kits, ammo crates and nitro canisters with rotation, glow and respawns.
class_name TrackPickup
extends Area3D

enum PickupType {
	REPAIR,
	AMMO,
	NITRO
}

@export var type: PickupType = PickupType.REPAIR
var respawn_timer: float = 0.0
var respawn_duration: float = 12.0
var mesh_inst: MeshInstance3D

func _ready():
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.8
	col.shape = sphere
	add_child(col)
	
	_build_mesh()
	body_entered.connect(_on_body_entered)

func _build_mesh():
	mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.2, 1.2, 1.2)
	mesh_inst.mesh = box
	
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	match type:
		PickupType.REPAIR:
			mat.albedo_color = Color(0.1, 0.9, 0.2)
			mat.emission = Color(0.1, 0.9, 0.2)
		PickupType.AMMO:
			mat.albedo_color = Color(1.0, 0.6, 0.0)
			mat.emission = Color(1.0, 0.6, 0.0)
		PickupType.NITRO:
			mat.albedo_color = Color(0.0, 0.8, 1.0)
			mat.emission = Color(0.0, 0.8, 1.0)
	mat.emission_energy_multiplier = 2.5
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func _process(delta: float):
	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			visible = true
			set_deferred("monitoring", true)
		return
		
	# Floating animation & continuous rotation
	rotate_y(delta * 2.2)
	position.y += sin(Time.get_ticks_msec() * 0.003) * delta * 0.4

func _on_body_entered(body: Node3D):
	if respawn_timer > 0.0:
		return
		
	if body.has_method("apply_repair") and type == PickupType.REPAIR:
		body.apply_repair(200.0)
		_consume()
	elif body.get("nitro_amount") != null and type == PickupType.NITRO:
		body.nitro_amount = min(body.nitro_capacity, body.nitro_amount + 50.0)
		_consume()

func _consume():
	respawn_timer = respawn_duration
	visible = false
	set_deferred("monitoring", false)
