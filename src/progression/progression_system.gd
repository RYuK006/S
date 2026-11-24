# src/progression/progression_system.gd
class_name ProgressionSystem
extends RefCounted

const MAX_LEVEL = 100

static func get_xp_for_level(level: int) -> int:
	if level <= 1: return 0
	return int(floor(250.0 * pow(float(level), 1.45)))

static func calculate_level_from_xp(total_xp: int) -> int:
	var lvl = 1
	while lvl < MAX_LEVEL:
		var req = get_xp_for_level(lvl + 1)
		if total_xp < req: break
		lvl += 1
	return lvl

const ACHIEVEMENTS = [
	# RACING (1 - 12)
	{ "id": "first_win", "name": "First Blood", "cat": "racing", "desc": "Win your first race." },
	{ "id": "clean_sweep", "name": "Clean Sweep", "cat": "racing", "desc": "Win a 3-lap race without taking hull damage." },
	{ "id": "lap_record", "name": "Speed Demon", "cat": "racing", "desc": "Set a circuit lap under 35 seconds." },
	{ "id": "drifter_elite", "name": "Sideways King", "cat": "racing", "desc": "Accumulate 10,000 meters of controlled drifts." },
	{ "id": "podium_streak", "name": "Consistent Podium", "cat": "racing", "desc": "Finish on the podium in 5 consecutive races." },
	{ "id": "dust_conqueror", "name": "Desert Fox", "cat": "racing", "desc": "Win all Dust Bowl campaign events." },
	{ "id": "docks_master", "name": "Harbour Master", "cat": "racing", "desc": "Win all Neon Docks campaign events." },
	{ "id": "ice_glider", "name": "Sub-Zero", "cat": "racing", "desc": "Win all Frozen Pass campaign events." },
	{ "id": "volcano_survivor", "name": "Magma Walker", "cat": "racing", "desc": "Win all Volcano Ridge campaign events." },
	{ "id": "comeback_kid", "name": "From the Ashes", "cat": "racing", "desc": "Win a race after being wrecked in lap 1." },
	{ "id": "nitro_junky", "name": "Full Throttle", "cat": "racing", "desc": "Burn nitro continuously for 12 seconds." },
	{ "id": "derby_champ", "name": "Last Car Standing", "cat": "racing", "desc": "Win a Demolition Derby as sole survivor." },

	# COMBAT (13 - 24)
	{ "id": "first_kill", "name": "Scrap Metal", "cat": "combat", "desc": "Wreck your first rival vehicle." },
	{ "id": "ramming_speed", "name": "Locomotive", "cat": "combat", "desc": "Destroy a car purely via physical collision." },
	{ "id": "rocket_sniper", "name": "Direct Hit", "cat": "combat", "desc": "Hit an enemy with an unguided rocket beyond 80 meters." },
	{ "id": "minefield", "name": "Tread Carefully", "cat": "combat", "desc": "Wreck 3 rivals with proximity mines in one race." },
	{ "id": "multi_kill", "name": "Double Trouble", "cat": "combat", "desc": "Wreck two cars within 4 seconds of each other." },
	{ "id": "hauler_down", "name": "Road Train Derailed", "cat": "combat", "desc": "Defeat The Hauler in Dust Bowl." },
	{ "id": "tide_extinguished", "name": "Extinguished", "cat": "combat", "desc": "Defeat Black Tide in Neon Docks." },
	{ "id": "frost_shattered", "name": "Thawed Out", "cat": "combat", "desc": "Defeat Frostbite in Frozen Pass." },
	{ "id": "warden_broken", "name": "Prison Break", "cat": "combat", "desc": "Defeat The Warden in Volcano Ridge." },
	{ "id": "century_kills", "name": "Centurion of Carnage", "cat": "combat", "desc": "Wreck 100 rival vehicles total." },
	{ "id": "close_call", "name": "Hanging by a Thread", "cat": "combat", "desc": "Win a race with less than 5% health remaining." },
	{ "id": "payback", "name": "Revenge Served Cold", "cat": "combat", "desc": "Wreck a rival who damaged you within 10 seconds." },

	# GARAGE & COLLECTION (25 - 36)
	{ "id": "car_collector_3", "name": "Triple Threat", "cat": "garage", "desc": "Own 3 different vehicles." },
	{ "id": "car_collector_6", "name": "Fleet Commander", "cat": "garage", "desc": "Own 6 different vehicles." },
	{ "id": "car_collector_12", "name": "Grand Collector", "cat": "garage", "desc": "Own all 12 vehicles in the showroom." },
	{ "id": "first_max_car", "name": "Perfectionist", "cat": "garage", "desc": "Max out all 10 upgrade tiers on any vehicle." },
	{ "id": "full_arsenal", "name": "Walking Fortress", "cat": "garage", "desc": "Unlock all 26 weapons." },
	{ "id": "paint_customizer", "name": "Fresh Coat", "cat": "garage", "desc": "Apply custom paint and finish to your car." },
	{ "id": "all_drivers", "name": "Crew Assembled", "cat": "garage", "desc": "Hire all 6 driver specialists." },
	{ "id": "big_spender", "name": "High Roller", "cat": "garage", "desc": "Spend over $200,000 in the workshop." },
	{ "id": "scrap_hoarder", "name": "Scrap Baron", "cat": "garage", "desc": "Accumulate 1,000 scrap parts." },
	{ "id": "gold_rush", "name": "Golden Garage", "cat": "garage", "desc": "Earn 100 gold bullion." },
	{ "id": "class_s_owner", "name": "Hyper-Spec", "cat": "garage", "desc": "Own a Class-S rated vehicle." },
	{ "id": "sovereign_acquired", "name": "The Crown Jewel", "cat": "garage", "desc": "Purchase the Gilded Sovereign." },

	# MASTERY (37 - 48)
	{ "id": "level_10", "name": "Rookie Graduate", "cat": "mastery", "desc": "Reach player level 10." },
	{ "id": "level_25", "name": "Seasoned Merc", "cat": "mastery", "desc": "Reach player level 25." },
	{ "id": "level_50", "name": "Circuit Legend", "cat": "mastery", "desc": "Reach player level 50." },
	{ "id": "level_100", "name": "Apex Predator", "cat": "mastery", "desc": "Reach max level 100." },
	{ "id": "all_races_gold", "name": "Undefeated", "cat": "mastery", "desc": "Earn 1st place in all 28 campaign missions." },
	{ "id": "ironman_win", "name": "Iron Driver", "cat": "mastery", "desc": "Win a 5-lap elimination race without repairs." },
	{ "id": "pacifist_win", "name": "Ghost on the Grid", "cat": "mastery", "desc": "Win a classic race without firing a weapon." },
	{ "id": "speed_barrier", "name": "Supersonic", "cat": "mastery", "desc": "Exceed 300 km/h in any vehicle." },
	{ "id": "air_ace", "name": "Frequent Flyer", "cat": "mastery", "desc": "Spend 60 seconds total airborne from stunt ramps." },
	{ "id": "perfect_shift", "name": "Gearshift God", "cat": "mastery", "desc": "Execute 20 perfect upshifts in one race." },
	{ "id": "bounty_hunter", "name": "Bounty Claimed", "cat": "mastery", "desc": "Earn $50,000 purely from destruction bounties." },
	{ "id": "hardcore_derby", "name": "Titanium Hull", "cat": "mastery", "desc": "Wreck 5 cars in a single Demolition Derby." },

	# SECRET & FUN (49 - 60)
	{ "id": "barrel_roll", "name": "Do a Barrel Roll", "cat": "secret", "desc": "Complete a full 360-degree mid-air roll and land on 4 wheels." },
	{ "id": "oil_slip", "name": "Banana Peel", "cat": "secret", "desc": "Spin 720 degrees on an oil slick without wrecking." },
	{ "id": "flip_recovery", "name": "Turtle Power", "cat": "secret", "desc": "Use manual flip recovery 5 times." },
	{ "id": "underdog_glory", "name": "David and Goliath", "cat": "secret", "desc": "Wreck a Scrap Titan while driving a Sprinter R2." },
	{ "id": "reverse_finish", "name": "Backwards across the Line", "cat": "secret", "desc": "Cross the finish line in reverse." },
	{ "id": "pylon_cleaner", "name": "Street Sweeper", "cat": "secret", "desc": "Knock down 50 slalom pylons or track cones." },
	{ "id": "train_close_call", "name": "Near Miss", "cat": "secret", "desc": "Cross the rail yard crossing within 1 meter of the train." },
	{ "id": "mine_rocket", "name": "Trick Shot", "cat": "secret", "desc": "Detonate an airborne rocket using a proximity mine." },
	{ "id": "zero_ammo_win", "name": "Empty Magazine", "cat": "secret", "desc": "Win a race having consumed every single round of ammo." },
	{ "id": "horn_spammer", "name": "Road Rage", "cat": "secret", "desc": "Honk your horn 20 times in a single lap." },
	{ "id": "radio_enthusiast", "name": "Audio Aficionado", "cat": "secret", "desc": "Listen to all procedural rock music tracks in the garage." },
	{ "id": "gridlethal_master", "name": "GRIDLETHAL Overlord", "cat": "secret", "desc": "Complete all other 59 achievements." }
]

static func simulate_economy_pacing(target_car_price: int = 140000) -> Dictionary:
	# Simulates races until player can afford Aurelia GT ($140,000)
	var cash = 0
	var races_played = 0
	var avg_cash_per_race = 3500 # Base purse + destruction bounties
	var time_per_race_mins = 2.5 # ~2.5 mins per 3-lap race

	while cash < target_car_price and races_played < 1000:
		races_played += 1
		cash += avg_cash_per_race

	var total_time_hours = (races_played * time_per_race_mins) / 60.0
	return {
		"races_needed": races_played,
		"total_cash": cash,
		"hours_played": total_time_hours,
		"is_balanced": total_time_hours >= 1.5 and total_time_hours <= 10.0
	}
