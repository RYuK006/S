# constants.gd
# Global constants, physics surfaces, vehicle specifications and audio parameters.
class_name GameConstants

# Surface Friction & Rolling Resistance Multipliers
const SURFACES = {
	"asphalt_dry": { "mu": 1.00, "rolling": 1.0, "sound": "asphalt" },
	"asphalt_wet": { "mu": 0.72, "rolling": 1.0, "sound": "wet_asphalt" },
	"concrete":    { "mu": 0.95, "rolling": 1.0, "sound": "concrete" },
	"dirt":        { "mu": 0.78, "rolling": 1.4, "sound": "dirt" },
	"gravel":      { "mu": 0.68, "rolling": 1.8, "sound": "gravel" },
	"sand":        { "mu": 0.55, "rolling": 2.6, "sound": "sand" },
	"mud":         { "mu": 0.50, "rolling": 3.0, "sound": "mud" },
	"snow":        { "mu": 0.42, "rolling": 2.2, "sound": "snow" },
	"ice":         { "mu": 0.18, "rolling": 1.0, "sound": "ice" },
	"grass":       { "mu": 0.60, "rolling": 2.0, "sound": "grass" },
	"oil_slick":   { "mu": 0.20, "rolling": 1.0, "sound": "oil" }
}

# The 12 Vehicle Recipes (Section 3)
const CAR_RECIPES = {
	"sprinter_r2": {
		"id": "sprinter_r2",
		"name": "Sprinter R2",
		"class": "Rally",
		"mass": 1050.0,
		"power_kw": 140.0,
		"top_speed_kmh": 175.0,
		"accel_0_100": 6.8,
		"health": 700.0,
		"price": 0,
		"drive": "AWD_FWD_BIASED",
		"torque_split": 0.60, # 60% front, 40% rear
		"drivetrain": "turbo_4",
		"cylinders": 4,
		"idle_rpm": 900.0,
		"redline_rpm": 7200.0,
		"peak_power_rpm": 6000.0,
		"peak_torque_rpm": 3800.0,
		"peak_torque_nm": 280.0,
		"gear_ratios": [3.42, 2.14, 1.45, 1.10, 0.86],
		"reverse_ratio": 3.30,
		"final_drive": 4.10,
		"shift_time_ms": 200,
		"wheelbase": 2.45,
		"track_width": 1.62,
		"wheel_radius": 0.32,
		"wheel_width": 0.22,
		"suspension": {
			"rest_length": 0.38,
			"travel": 0.18,
			"spring_rate": 28000.0, # N/m
			"damping_bump": 2400.0,
			"damping_rebound": 3600.0,
			"anti_roll": 6500.0
		},
		"tire": {
			"peak_slip": 0.13,
			"slide_slip": 0.55,
			"peak_mu": 1.65,
			"slide_mu": 1.12,
			"long_mu": 1.55,
			"load_sensitivity": 0.22,
			"nominal_load": 2600.0
		},
		"drag_cd": 0.34,
		"frontal_area": 2.1,
		"downforce_factor": 0.15,
		"perk": "Underdog",
		"perk_desc": "+10% damage dealt when car is below half health",
		"weapon_slots": ["FRONT", "ROOF"]
	}
}
