# pacejka_tire.gd
# Pacejka 'Magic Formula' tire model with load sensitivity and friction ellipse coupling.
class_name PacejkaTire
extends RefCounted

var peak_slip: float = 0.13        # slip angle (rad) at peak lateral grip
var slide_slip: float = 0.55       # slip angle (rad) at sliding plateau
var peak_mu: float = 1.65          # peak lateral friction coeff
var slide_mu: float = 1.12         # sliding lateral friction coeff
var long_mu: float = 1.55          # peak longitudinal friction coeff
var load_sensitivity: float = 0.22 # degradation of mu with vertical load
var nominal_load: float = 2600.0   # reference vertical load in Newtons
var surface_mu: float = 1.00       # surface multiplier (e.g. wet asphalt = 0.72)

func _init(cfg: Dictionary = {}):
	if cfg.has("peak_slip"): peak_slip = cfg.peak_slip
	if cfg.has("slide_slip"): slide_slip = cfg.slide_slip
	if cfg.has("peak_mu"): peak_mu = cfg.peak_mu
	if cfg.has("slide_mu"): slide_mu = cfg.slide_mu
	if cfg.has("long_mu"): long_mu = cfg.long_mu
	if cfg.has("load_sensitivity"): load_sensitivity = cfg.load_sensitivity
	if cfg.has("nominal_load"): nominal_load = cfg.nominal_load

# Solves tire forces given:
# fz: vertical normal load (N)
# slip_ratio: (omega * r - vx) / max(|vx|, eps) [-1.0 .. 1.0+]
# slip_angle: -atan2(vy, |vx|) (rad)
# surface_factor: surface grip multiplier
# Returns Dictionary: { "fx": float, "fy": float, "slip_angle": float, "saturation": float, "is_sliding": bool }
func solve(fz: float, slip_ratio: float, slip_angle: float, surface_factor: float = 1.0) -> Dictionary:
	if fz <= 10.0:
		return { "fx": 0.0, "fy": 0.0, "slip_angle": slip_angle, "saturation": 0.0, "is_sliding": false }
	
	# Load sensitivity correction: heavily loaded tire yields slightly less mu per Newton
	var load_ratio = fz / nominal_load
	var effective_peak_mu = peak_mu * (1.0 - load_sensitivity * (load_ratio - 1.0)) * surface_factor
	var effective_slide_mu = slide_mu * (1.0 - load_sensitivity * (load_ratio - 1.0)) * surface_factor
	var effective_long_mu = long_mu * (1.0 - load_sensitivity * (load_ratio - 1.0)) * surface_factor
	
	effective_peak_mu = max(0.05, effective_peak_mu)
	effective_slide_mu = max(0.05, effective_slide_mu)
	effective_long_mu = max(0.05, effective_long_mu)
	
	# 1. Pure Longitudinal Force (Pacejka approximation)
	var d_long = effective_long_mu * fz
	var c_long = 1.65
	var b_long = 10.0
	var fx_pure = d_long * sin(c_long * atan(b_long * slip_ratio))
	
	# 2. Pure Lateral Force
	var abs_slip = abs(slip_angle)
	var d_lat = effective_peak_mu * fz
	var fy_pure = 0.0
	var is_sliding = false
	
	if abs_slip <= peak_slip:
		# Quarter-sine rise to peak
		var norm_slip = abs_slip / peak_slip
		fy_pure = d_lat * sin(norm_slip * (PI * 0.5))
	else:
		# Smoothstep decay to slide plateau
		var slide_d = effective_slide_mu * fz
		var t = clamp((abs_slip - peak_slip) / max(0.01, slide_slip - peak_slip), 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		fy_pure = lerp(d_lat, slide_d, t)
		is_sliding = (t > 0.3)
	
	fy_pure *= sign(slip_angle)
	
	# 3. Friction Ellipse Coupling
	# When driving or braking hard, available lateral grip is reduced
	var fx_max = effective_long_mu * fz
	var fy_max = effective_peak_mu * fz
	
	var norm_fx = clamp(abs(fx_pure) / max(1.0, fx_max), 0.0, 1.0)
	var lateral_reduction = sqrt(max(0.0, 1.0 - norm_fx * norm_fx))
	var fy_coupled = fy_pure * lateral_reduction
	
	# Combined saturation ratio (0.0 .. 1.0+)
	var saturation = sqrt(pow(fx_pure / max(1.0, fx_max), 2.0) + pow(fy_coupled / max(1.0, fy_max), 2.0))
	
	return {
		"fx": fx_pure,
		"fy": fy_coupled,
		"slip_angle": slip_angle,
		"saturation": saturation,
		"is_sliding": is_sliding or (saturation >= 1.0)
	}
