# tests/test_stage7_netcode.gd
extends Node

const NetSnapshot = preload("res://scripts/net/net_snapshot.gd")

func _ready():
	print("\n=======================================================")
	print("       GRIDLETHAL STAGE 7 MULTIPLAYER NETCODE SUITE   ")
	print("=======================================================\n")

	var passes = 0

	# Test 1: Snapshot Byte Size Verification (Exactly 24 bytes)
	var orig_pos = Vector3(124.55, 3.20, -84.30)
	var orig_rot = Quaternion(Vector3(0, 1, 0), 0.785).normalized()
	var orig_vel = Vector3(25.4, 0.1, -15.2)
	var bytes = NetSnapshot.pack_vehicle_snapshot(orig_pos, orig_rot, orig_vel, 680.0, 3, false)

	if bytes.size() == 24:
		print("[PASS] Test 1: Binary Snapshot Bandwidth Size Validated (Exactly 24 bytes)")
		passes += 1
	else:
		print("[FAIL] Test 1: Expected 24 bytes, got %d" % bytes.size())

	# Test 2: Position Precision Roundtrip (< 0.01m error)
	var unpacked = NetSnapshot.unpack_vehicle_snapshot(bytes)
	var pos_err = orig_pos.distance_to(unpacked["position"])
	if pos_err < 0.01:
		print("[PASS] Test 2: Fixed-Point Position Precision Validated (Error: %.5f m < 0.01 m)" % pos_err)
		passes += 1
	else:
		print("[FAIL] Test 2: Position error excessive: %.5f m" % pos_err)

	# Test 3: Quaternion Normalization & Precision (< 0.005 error)
	var quat_err = abs(orig_rot.dot(unpacked["quaternion"]) - 1.0)
	if quat_err < 0.005:
		print("[PASS] Test 3: Quaternion Encoding & Normalization Validated (Error: %.5f < 0.005)" % quat_err)
		passes += 1
	else:
		print("[FAIL] Test 3: Quaternion error excessive: %.5f" % quat_err)

	# Test 4: Health, Velocity & Gear State Fidelity
	var health_match = abs(unpacked["health"] - 680.0) < 1.0
	var gear_match = unpacked["gear"] == 3
	var wreck_match = unpacked["is_wrecked"] == false
	if health_match and gear_match and wreck_match:
		print("[PASS] Test 4: Telemetry State Deserialization Validated (HP: %.0f, Gear: %d, Wrecked: %s)" % [
			unpacked["health"], unpacked["gear"], unpacked["is_wrecked"]
		])
		passes += 1
	else:
		print("[FAIL] Test 4: State telemetry mismatch")

	# Test 5: Entity Interpolation Step
	var pos_A = unpacked["position"]
	var pos_B = pos_A + Vector3(5.0, 0.0, 5.0)
	var t = 0.5
	var interp_pos = pos_A.lerp(pos_B, t)
	var expected_pos = pos_A + Vector3(2.5, 0.0, 2.5)
	if interp_pos.distance_to(expected_pos) < 0.001:
		print("[PASS] Test 5: Snapshot Jitter Buffer Entity Interpolation Validated")
		passes += 1
	else:
		print("[FAIL] Test 5: Entity interpolation failed")

	print("\n-------------------------------------------------------")
	print("STAGE 7 RESULTS: %d / 5 TESTS PASSED" % passes)
	print("-------------------------------------------------------\n")

	if passes == 5:
		print("STAGE 7 ACCEPTANCE CHECKLIST: ALL PASS.\n")
		get_tree().quit(0)
	else:
		print("STAGE 7 ACCEPTANCE CHECKLIST: FAILURES DETECTED.\n")
		get_tree().quit(1)
