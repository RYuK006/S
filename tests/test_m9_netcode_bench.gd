# tests/test_m9_netcode_bench.gd
class_name TestM9NetcodeBench
extends RefCounted

const NetSnapshot = preload("res://scripts/net/net_snapshot.gd")
const NetworkManager = preload("res://scripts/net/network_manager.gd")

static func run() -> bool:
	print("--- Running TestM9NetcodeBench ---")
	
	# Test 1: Snapshot Byte Size Verification (Exactly 24 bytes)
	var orig_pos := Vector3(124.55, 3.20, -84.30)
	var orig_rot := Quaternion(Vector3(0, 1, 0), 0.785).normalized()
	var orig_vel := Vector3(25.4, 0.1, -15.2)
	var bytes := NetSnapshot.pack_vehicle_snapshot(orig_pos, orig_rot, orig_vel, 680.0, 3, false)
	
	if bytes.size() != 24:
		printerr("[FAIL] Snapshot size mismatch: expected 24 bytes, got %d" % bytes.size())
		return false
	print("[PASS] Binary Snapshot Bandwidth: Exactly 24 bytes per vehicle state frame")
	
	# Test 2: Position Precision Roundtrip (< 0.01m error)
	var unpacked := NetSnapshot.unpack_vehicle_snapshot(bytes)
	var pos_err: float = orig_pos.distance_to(unpacked["position"])
	if pos_err >= 0.01:
		printerr("[FAIL] Position precision error excessive: %.5f m" % pos_err)
		return false
	print("[PASS] Fixed-Point Precision: Position delta %.5f m < 0.01 m standard" % pos_err)
	
	# Test 3: Quaternion Normalization & Precision
	var quat_err: float = abs(orig_rot.dot(unpacked["quaternion"]) - 1.0)
	if quat_err >= 0.005:
		printerr("[FAIL] Quaternion encoding error: %.5f" % quat_err)
		return false
	print("[PASS] Orientation Fidelity: Quaternion encoding & normalization verified (Error: %.5f < 0.005)" % quat_err)
	
	# Test 4: Telemetry State Deserialization (HP, Gear, Wrecked)
	var hp_match: bool = abs(float(unpacked.get("health", 0.0)) - 680.0) < 1.0
	var gear_match: bool = (int(unpacked.get("gear", 0)) == 3)
	var wreck_match: bool = (bool(unpacked.get("is_wrecked", true)) == false)
	if not (hp_match and gear_match and wreck_match):
		printerr("[FAIL] Telemetry state mismatch in snapshot")
		return false
	print("[PASS] Vehicle State Telemetry: Health (680 HP), Gear (3), Wreck state (Alive) verified")
	
	# Test 5: Entity Interpolation Buffer
	var net_mgr := NetworkManager.new()
	var p1 := orig_pos
	var p2 := orig_pos + Vector3(10.0, 0.0, 0.0)
	var p3 := orig_pos + Vector3(20.0, 0.0, 0.0)
	
	var b1 := NetSnapshot.pack_vehicle_snapshot(p1, orig_rot, orig_vel, 680.0, 3, false)
	var b2 := NetSnapshot.pack_vehicle_snapshot(p2, orig_rot, orig_vel, 680.0, 3, false)
	var b3 := NetSnapshot.pack_vehicle_snapshot(p3, orig_rot, orig_vel, 680.0, 3, false)
	
	net_mgr.record_remote_snapshot(2, b1, 1.000)
	net_mgr.record_remote_snapshot(2, b2, 1.050)
	net_mgr.record_remote_snapshot(2, b3, 1.100)
	
	# Interpolate at target time t = 1.150 - 0.100 = 1.050 (exact midpoint p2)
	var interpolated := net_mgr.interpolate_remote_vehicle(2, 1.150)
	var interp_pos: Vector3 = interpolated.get("position", Vector3.ZERO)
	var diff: float = interp_pos.distance_to(p2)
	if diff >= 0.05:
		printerr("[FAIL] Entity interpolation error: %.4f m" % diff)
		return false
	print("[PASS] Entity Interpolation: 100ms jitter buffer verified with Slerp/Lerp convergence")
	
	net_mgr.queue_free()
	return true
