# src/campaign/campaign_data.gd
class_name CampaignData
extends RefCounted

const BIOMES = {
	"dust_bowl": {
		"id": "dust_bowl", "name": "Dust Bowl",
		"theme": "Desert Salvage Country",
		"sky_color": "#c89454", "ground_color": "#5a4d3e",
		"default_weather": "clear",
		"desc": "Sun-bleached salvage yards, dry riverbeds and heat-baked asphalt."
	},
	"neon_docks": {
		"id": "neon_docks", "name": "Neon Docks",
		"theme": "Rain-Slick Industrial Port",
		"sky_color": "#0d1b2a", "ground_color": "#1b263b",
		"default_weather": "rain",
		"desc": "High-contrast night racing through container terminals and wet docks."
	},
	"frozen_pass": {
		"id": "frozen_pass", "name": "Frozen Pass",
		"theme": "Alpine Mountain Pass",
		"sky_color": "#d0e1fd", "ground_color": "#e0e6ed",
		"default_weather": "snow",
		"desc": "Sheer cliff roads, snow drifts, icy hairpins and blinding blizzards."
	},
	"volcano_ridge": {
		"id": "volcano_ridge", "name": "Volcano Ridge",
		"theme": "Lava-Lit Highlands",
		"sky_color": "#38040e", "ground_color": "#250902",
		"default_weather": "ash",
		"desc": "Active tectonic caldera with magma rivers, ash fall and crumbling bridges."
	}
}

const CAMPAIGN_RACES = [
	# DUST BOWL (Races 1 to 7)
	{ "id": 1, "name": "Rust Gate Sprint", "region": "dust_bowl", "mode": "classic", "laps": 3, "cars": 6, "weather": "clear", "time": "noon", "level_req": 1, "reward_cash": 2500, "reward_xp": 150 },
	{ "id": 2, "name": "Tumbleweed Loop", "region": "dust_bowl", "mode": "classic", "laps": 3, "cars": 6, "weather": "clear", "time": "golden", "level_req": 2, "reward_cash": 3200, "reward_xp": 200 },
	{ "id": 3, "name": "Scrapyard Derby", "region": "dust_bowl", "mode": "derby", "laps": 1, "cars": 8, "weather": "clear", "time": "noon", "level_req": 4, "reward_cash": 4500, "reward_xp": 280 },
	{ "id": 4, "name": "Salt Flat Time Trial", "region": "dust_bowl", "mode": "time_attack", "laps": 2, "cars": 1, "weather": "clear", "time": "noon", "level_req": 6, "reward_cash": 4000, "reward_xp": 250 },
	{ "id": 5, "name": "Windmill Rush", "region": "dust_bowl", "mode": "checkpoint_rush", "laps": 1, "cars": 1, "weather": "sandstorm", "time": "dusk", "level_req": 8, "reward_cash": 5200, "reward_xp": 320 },
	{ "id": 6, "name": "Dry River Elimination", "region": "dust_bowl", "mode": "elimination", "laps": 5, "cars": 6, "weather": "clear", "time": "dusk", "level_req": 10, "reward_cash": 6000, "reward_xp": 380 },
	{ "id": 7, "name": "BOSS: The Hauler", "region": "dust_bowl", "mode": "boss_duel", "laps": 3, "cars": 2, "weather": "sandstorm", "time": "dusk", "level_req": 12, "reward_cash": 15000, "reward_xp": 1000, "boss_name": "The Hauler", "boss_hp": 3000 },

	# NEON DOCKS (Races 8 to 14)
	{ "id": 8, "name": "Container Run", "region": "neon_docks", "mode": "classic", "laps": 4, "cars": 6, "weather": "rain", "time": "night", "level_req": 13, "reward_cash": 7500, "reward_xp": 450 },
	{ "id": 9, "name": "Crane Alley", "region": "neon_docks", "mode": "survival", "laps": 1, "cars": 8, "weather": "rain", "time": "night", "level_req": 15, "reward_cash": 8800, "reward_xp": 520 },
	{ "id": 10, "name": "Harbour Dash", "region": "neon_docks", "mode": "time_attack", "laps": 2, "cars": 1, "weather": "rain", "time": "night", "level_req": 17, "reward_cash": 8000, "reward_xp": 480 },
	{ "id": 11, "name": "Rail Yard Rumble", "region": "neon_docks", "mode": "classic", "laps": 3, "cars": 6, "weather": "fog", "time": "night", "level_req": 19, "reward_cash": 9500, "reward_xp": 580 },
	{ "id": 12, "name": "Sodium Strip", "region": "neon_docks", "mode": "elimination", "laps": 5, "cars": 6, "weather": "rain", "time": "night", "level_req": 21, "reward_cash": 11000, "reward_xp": 650 },
	{ "id": 13, "name": "Drydock Arena", "region": "neon_docks", "mode": "derby", "laps": 1, "cars": 8, "weather": "rain", "time": "night", "level_req": 23, "reward_cash": 12500, "reward_xp": 720 },
	{ "id": 14, "name": "BOSS: Black Tide", "region": "neon_docks", "mode": "boss_duel", "laps": 3, "cars": 2, "weather": "rain", "time": "night", "level_req": 24, "reward_cash": 25000, "reward_xp": 1800, "boss_name": "Black Tide", "boss_hp": 4500 },

	# FROZEN PASS (Races 15 to 21)
	{ "id": 15, "name": "Whiteout Run", "region": "frozen_pass", "mode": "classic", "laps": 3, "cars": 6, "weather": "snow", "time": "day", "level_req": 25, "reward_cash": 14000, "reward_xp": 800 },
	{ "id": 16, "name": "Ice Road Escort", "region": "frozen_pass", "mode": "escort", "laps": 1, "cars": 6, "weather": "snow", "time": "day", "level_req": 27, "reward_cash": 16000, "reward_xp": 920 },
	{ "id": 17, "name": "Avalanche Alley", "region": "frozen_pass", "mode": "checkpoint_rush", "laps": 1, "cars": 1, "weather": "blizzard", "time": "day", "level_req": 29, "reward_cash": 15500, "reward_xp": 890 },
	{ "id": 18, "name": "Switchback Sprint", "region": "frozen_pass", "mode": "time_attack", "laps": 2, "cars": 1, "weather": "snow", "time": "day", "level_req": 31, "reward_cash": 15000, "reward_xp": 850 },
	{ "id": 19, "name": "Glacier Derby", "region": "frozen_pass", "mode": "derby", "laps": 1, "cars": 8, "weather": "ice", "time": "aurora", "level_req": 33, "reward_cash": 18000, "reward_xp": 1050 },
	{ "id": 20, "name": "Tunnel Gauntlet", "region": "frozen_pass", "mode": "classic", "laps": 4, "cars": 6, "weather": "snow", "time": "day", "level_req": 35, "reward_cash": 20000, "reward_xp": 1200 },
	{ "id": 21, "name": "BOSS: Frostbite", "region": "frozen_pass", "mode": "boss_duel", "laps": 3, "cars": 2, "weather": "blizzard", "time": "aurora", "level_req": 38, "reward_cash": 40000, "reward_xp": 2500, "boss_name": "Frostbite", "boss_hp": 6000 },

	# VOLCANO RIDGE (Races 22 to 28)
	{ "id": 22, "name": "Ash Highway", "region": "volcano_ridge", "mode": "classic", "laps": 4, "cars": 6, "weather": "ash", "time": "day", "level_req": 39, "reward_cash": 24000, "reward_xp": 1400 },
	{ "id": 23, "name": "Lava Crossing", "region": "volcano_ridge", "mode": "checkpoint_rush", "laps": 1, "cars": 1, "weather": "ash", "time": "dusk", "level_req": 42, "reward_cash": 26000, "reward_xp": 1550 },
	{ "id": 24, "name": "Magma Escort", "region": "volcano_ridge", "mode": "escort", "laps": 1, "cars": 6, "weather": "ash", "time": "dusk", "level_req": 46, "reward_cash": 28000, "reward_xp": 1700 },
	{ "id": 25, "name": "Caldera Survival", "region": "volcano_ridge", "mode": "survival", "laps": 1, "cars": 8, "weather": "ash", "time": "night", "level_req": 50, "reward_cash": 32000, "reward_xp": 1950 },
	{ "id": 26, "name": "Obsidian Elimination", "region": "volcano_ridge", "mode": "elimination", "laps": 5, "cars": 6, "weather": "ash", "time": "night", "level_req": 54, "reward_cash": 35000, "reward_xp": 2200 },
	{ "id": 27, "name": "Final Time Attack", "region": "volcano_ridge", "mode": "time_attack", "laps": 2, "cars": 1, "weather": "ash", "time": "night", "level_req": 58, "reward_cash": 40000, "reward_xp": 2600 },
	{ "id": 28, "name": "FINAL BOSS: The Warden", "region": "volcano_ridge", "mode": "boss_duel", "laps": 4, "cars": 2, "weather": "ash", "time": "night", "level_req": 60, "reward_cash": 100000, "reward_xp": 5000, "boss_name": "The Warden", "boss_hp": 10000 }
]

const SURFACE_GRIP_TABLE = {
	"asphalt_dry": 1.00,
	"asphalt_wet": 0.72,
	"concrete": 0.95,
	"packed_dirt": 0.78,
	"gravel": 0.68,
	"sand": 0.55,
	"mud": 0.50,
	"snow": 0.42,
	"ice": 0.18,
	"oil_slick": 0.20
}
