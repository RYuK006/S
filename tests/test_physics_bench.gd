# test_physics_bench.gd
# Validates Pacejka Magic Formula tire curves, peak slip, sliding plateau, and friction ellipse coupling.
class_name TestPhysicsBench
extends RefCounted

const PacejkaTire = preload("res://scripts/vehicle/pacejka_tire.gd")

static func run() -> bool:
	print("--- Running TestPhysicsBench ---")
	var tire = PacejkaTire.new({
		"peak_slip": 0.13,
		"slide_slip": 0.52,
		"peak_mu": 1.62,
		"slide_mu": 1.12,
		"long_mu": 1.55
	})
	
	var fz = 2600.0
	var res_peak = tire.solve(fz, 0.0, 0.13, 1.0)
	var res_slide = tire.solve(fz, 0.0, 0.60, 1.0)
	
	if res_peak.fy <= res_slide.fy or not res_slide.is_sliding:
		printerr("[FAIL] Pacejka curve failed: Peak FY (%.1f) should exceed Slide FY (%.1f)" % [res_peak.fy, res_slide.fy])
		return false
	print("[PASS] Pacejka Tire Dynamics: Peak FY (%.0f N) > Slide FY (%.0f N)" % [res_peak.fy, res_slide.fy])
	
	# Friction ellipse coupling test: applying brake slip must reduce lateral grip
	var res_coupled = tire.solve(fz, 0.35, 0.13, 1.0)
	if res_coupled.fy >= res_peak.fy:
		printerr("[FAIL] Friction ellipse failed: Coupled FY (%.1f) should be < Pure Lateral FY (%.1f)" % [res_coupled.fy, res_peak.fy])
		return false
	print("[PASS] Friction Ellipse Coupling: Coupled Lat (%.0f N) < Pure Lat (%.0f N)" % [res_coupled.fy, res_peak.fy])
	
	return true
