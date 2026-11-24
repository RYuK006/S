# weapon_data.gd
# Data specifications for Stage 3 weapons (10 weapons across Front, Roof, Rear, Melee and Defensive).
class_name WeaponData
extends RefCounted

const WEAPONS = {
	"twin_mg": {
		"id": "twin_mg",
		"name": "Twin MG",
		"category": "GUN",
		"slot": "FRONT",
		"damage": 7.0,
		"rate_of_fire": 14.0, # shots per second
		"magazine_size": 300,
		"max_ammo": 300,
		"range_m": 90.0,
		"projectile_speed": 450.0, # fast tracer hitscan-assisted
		"spread_rad": 0.035,
		"heat_per_shot": 0.012,
		"cooling_rate": 0.25,
		"weight_kg": 18.0,
		"price": 1500,
		"unlock_level": 1,
		"desc": "Light dual-barrel machine gun with rapid tracer rounds."
	},
	"heavy_mg": {
		"id": "heavy_mg",
		"name": "Heavy MG",
		"category": "CANNON",
		"slot": "FRONT",
		"damage": 16.0,
		"rate_of_fire": 8.0,
		"magazine_size": 200,
		"max_ammo": 200,
		"range_m": 110.0,
		"projectile_speed": 550.0,
		"spread_rad": 0.02,
		"heat_per_shot": 0.028,
		"cooling_rate": 0.22,
		"weight_kg": 45.0,
		"price": 6500,
		"unlock_level": 6,
		"desc": "Armor-piercing heavy caliber machine gun with high punch."
	},
	"shotgun_cannon": {
		"id": "shotgun_cannon",
		"name": "Shotgun Cannon",
		"category": "SHOTGUN",
		"slot": "FRONT",
		"damage": 9.0, # 9 dmg * 12 pellets = 108 dmg at point blank
		"pellets": 12,
		"rate_of_fire": 1.4,
		"magazine_size": 24,
		"max_ammo": 24,
		"range_m": 35.0,
		"projectile_speed": 320.0,
		"spread_rad": 0.12,
		"heat_per_shot": 0.15,
		"cooling_rate": 0.35,
		"recoil_impulse": 3200.0,
		"weight_kg": 38.0,
		"price": 7500,
		"unlock_level": 8,
		"desc": "Devastating close-range blast that knocks cars sideways."
	},
	"rocket_pod": {
		"id": "rocket_pod",
		"name": "Rocket Pod",
		"category": "ROCKET",
		"slot": "ROOF",
		"damage": 70.0,
		"salvo_size": 4,
		"rate_of_fire": 0.5, # salvos/sec
		"magazine_size": 16,
		"max_ammo": 16,
		"range_m": 150.0,
		"projectile_speed": 85.0,
		"splash_radius": 5.0,
		"weight_kg": 65.0,
		"price": 9000,
		"unlock_level": 10,
		"desc": "Roof-mounted 4-tube salvo launcher with explosive splash radius."
	},
	"homing_missile": {
		"id": "homing_missile",
		"name": "Homing Missile",
		"category": "MISSILE",
		"slot": "ROOF",
		"damage": 110.0,
		"rate_of_fire": 0.4,
		"magazine_size": 10,
		"max_ammo": 10,
		"range_m": 250.0,
		"projectile_speed": 110.0,
		"lock_on_time": 1.2,
		"weight_kg": 80.0,
		"price": 18000,
		"unlock_level": 18,
		"desc": "Heat-seeking guided missile requiring reticle lock-on."
	},
	"mine_dropper": {
		"id": "mine_dropper",
		"name": "Mine Dropper",
		"category": "MINE",
		"slot": "REAR",
		"damage": 180.0,
		"rate_of_fire": 0.66, # 1 per 1.5s
		"magazine_size": 12,
		"max_ammo": 12,
		"arming_time": 1.0,
		"blast_radius": 4.5,
		"upward_impulse": 12000.0,
		"weight_kg": 22.0,
		"price": 3500,
		"unlock_level": 3,
		"desc": "Drops proximity magnetic mines that launch cars into the air."
	},
	"oil_slick": {
		"id": "oil_slick",
		"name": "Oil Slick",
		"category": "HAZARD",
		"slot": "REAR",
		"damage": 0.0,
		"rate_of_fire": 0.4,
		"magazine_size": 10,
		"max_ammo": 10,
		"duration_sec": 12.0,
		"grip_multiplier": 0.20,
		"weight_kg": 15.0,
		"price": 2500,
		"unlock_level": 4,
		"desc": "Releases slippery oil patches that cause pursuing cars to spin."
	},
	"ram_plate": {
		"id": "ram_plate",
		"name": "Ram Plate",
		"category": "MELEE",
		"slot": "FRONT",
		"damage_boost": 0.50, # +50% front collision damage
		"damage_reduction": 0.35, # 35% less damage taken at front
		"weight_kg": 40.0,
		"price": 4000,
		"unlock_level": 2,
		"desc": "Heavy reinforced steel bull-bar for brutal head-on ramming."
	},
	"armour_plating": {
		"id": "armour_plating",
		"name": "Armour Plating",
		"category": "DEFENSIVE",
		"slot": "DEFENSIVE",
		"health_bonus_pct": 0.20, # +20% health
		"weight_kg": 60.0,
		"price": 5000,
		"unlock_level": 3,
		"desc": "Reinforced chassis plating and composite panels."
	},
	"countermeasures": {
		"id": "countermeasures",
		"name": "Countermeasures",
		"category": "DEFENSIVE",
		"slot": "DEFENSIVE",
		"charges": 4,
		"max_ammo": 4,
		"weight_kg": 8.0,
		"price": 6000,
		"unlock_level": 11,
		"desc": "Hot flare decoy canisters that divert incoming homing missiles."
	}
}
