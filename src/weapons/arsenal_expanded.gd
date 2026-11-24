# src/weapons/arsenal_expanded.gd
class_name ArsenalExpanded
extends RefCounted

const ALL_WEAPONS = {
	# FRONT GUNS & CANNONS (1 - 7)
	"twin_mg": { "id": "twin_mg", "name": "Twin MG", "slot": "front", "damage": 7.0, "rate": 14.0, "ammo": 300, "range": 90.0, "weight": 18.0, "price": 1500, "level": 1 },
	"heavy_mg": { "id": "heavy_mg", "name": "Heavy MG", "slot": "front", "damage": 16.0, "rate": 8.0, "ammo": 200, "range": 110.0, "weight": 45.0, "price": 6500, "level": 6 },
	"shotgun_cannon": { "id": "shotgun_cannon", "name": "Shotgun Cannon", "slot": "front", "damage": 108.0, "rate": 1.4, "ammo": 24, "range": 35.0, "weight": 38.0, "price": 7500, "level": 8 },
	"flamethrower": { "id": "flamethrower", "name": "Flamethrower", "slot": "front", "damage": 120.0, "rate": 20.0, "ammo": 100, "range": 14.0, "weight": 55.0, "price": 12000, "level": 12 },
	"plasma_cannon": { "id": "plasma_cannon", "name": "Plasma Cannon", "slot": "front", "damage": 85.0, "rate": 1.0, "ammo": 30, "range": 80.0, "weight": 70.0, "price": 24000, "level": 20 },
	"railgun": { "id": "railgun", "name": "Railgun", "slot": "front", "damage": 420.0, "rate": 0.25, "ammo": 12, "range": 300.0, "weight": 120.0, "price": 60000, "level": 35 },
	"harpoon_launcher": { "id": "harpoon_launcher", "name": "Harpoon Launcher", "slot": "front", "damage": 40.0, "rate": 0.2, "ammo": 6, "range": 60.0, "weight": 60.0, "price": 14000, "level": 15 },

	# ROOF TURRETS (8 - 12)
	"rocket_pod": { "id": "rocket_pod", "name": "Rocket Pod", "slot": "roof", "damage": 70.0, "rate": 2.0, "ammo": 16, "range": 150.0, "weight": 65.0, "price": 9000, "level": 10 },
	"homing_missile": { "id": "homing_missile", "name": "Homing Missile", "slot": "roof", "damage": 110.0, "rate": 0.4, "ammo": 10, "range": 250.0, "weight": 80.0, "price": 18000, "level": 18 },
	"minigun_turret": { "id": "minigun_turret", "name": "Minigun Turret", "slot": "roof", "damage": 9.0, "rate": 40.0, "ammo": 600, "range": 100.0, "weight": 90.0, "price": 20000, "level": 22 },
	"cluster_rocket": { "id": "cluster_rocket", "name": "Cluster Rocket", "slot": "roof", "damage": 260.0, "rate": 0.3, "ammo": 8, "range": 200.0, "weight": 75.0, "price": 16000, "level": 25 },
	"emp_pulse": { "id": "emp_pulse", "name": "EMP Pulse", "slot": "roof", "damage": 0.0, "rate": 0.1, "ammo": 6, "range": 25.0, "weight": 50.0, "price": 15000, "level": 28 },

	# REAR WEAPONS (13 - 17)
	"mine_dropper": { "id": "mine_dropper", "name": "Mine Dropper", "slot": "rear", "damage": 180.0, "rate": 0.65, "ammo": 12, "range": 0.0, "weight": 22.0, "price": 3500, "level": 3 },
	"oil_slick": { "id": "oil_slick", "name": "Oil Slick", "slot": "rear", "damage": 0.0, "rate": 0.4, "ammo": 10, "range": 0.0, "weight": 15.0, "price": 2500, "level": 4 },
	"spike_strip": { "id": "spike_strip", "name": "Spike Strip", "slot": "rear", "damage": 50.0, "rate": 0.5, "ammo": 6, "range": 0.0, "weight": 12.0, "price": 3000, "level": 5 },
	"smoke_screen": { "id": "smoke_screen", "name": "Smoke Screen", "slot": "rear", "damage": 0.0, "rate": 0.3, "ammo": 8, "range": 0.0, "weight": 18.0, "price": 3000, "level": 7 },
	"napalm_drop": { "id": "napalm_drop", "name": "Napalm Drop", "slot": "rear", "damage": 112.0, "rate": 0.25, "ammo": 5, "range": 0.0, "weight": 35.0, "price": 11000, "level": 16 },

	# MELEE & MACHINERY (18 - 21)
	"ram_plate": { "id": "ram_plate", "name": "Ram Plate", "slot": "melee", "damage": 0.0, "rate": 0.0, "ammo": 0, "range": 0.0, "weight": 45.0, "price": 4000, "level": 2 },
	"saw_blades": { "id": "saw_blades", "name": "Saw Blades", "slot": "melee", "damage": 35.0, "rate": 10.0, "ammo": 0, "range": 1.5, "weight": 40.0, "price": 9000, "level": 14 },
	"side_spikes": { "id": "side_spikes", "name": "Side Spikes", "slot": "melee", "damage": 25.0, "rate": 10.0, "ammo": 0, "range": 1.2, "weight": 30.0, "price": 5000, "level": 9 },
	"wheel_blades": { "id": "wheel_blades", "name": "Wheel Blades", "slot": "melee", "damage": 15.0, "rate": 10.0, "ammo": 0, "range": 1.0, "weight": 32.0, "price": 8000, "level": 13 },

	# DEFENSIVE (22 - 26)
	"armour_plating": { "id": "armour_plating", "name": "Armour Plating", "slot": "defensive", "damage": 0.0, "rate": 0.0, "ammo": 0, "range": 0.0, "weight": 80.0, "price": 5000, "level": 3 },
	"shield_generator": { "id": "shield_generator", "name": "Shield Generator", "slot": "defensive", "damage": 0.0, "rate": 0.0, "ammo": 0, "range": 0.0, "weight": 45.0, "price": 22000, "level": 24 },
	"repair_drone": { "id": "repair_drone", "name": "Repair Drone", "slot": "defensive", "damage": 0.0, "rate": 0.0, "ammo": 0, "range": 0.0, "weight": 20.0, "price": 17000, "level": 26 },
	"countermeasures": { "id": "countermeasures", "name": "Countermeasures", "slot": "defensive", "damage": 0.0, "rate": 0.125, "ammo": 4, "range": 30.0, "weight": 8.0, "price": 6000, "level": 11 },
	"nitro_tank": { "id": "nitro_tank", "name": "Nitro Tank", "slot": "defensive", "damage": 0.0, "rate": 0.0, "ammo": 0, "range": 0.0, "weight": 25.0, "price": 4500, "level": 2 }
}
