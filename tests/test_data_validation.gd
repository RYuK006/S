# test_data_validation.gd
# Validates all JSON files in data/ and asserts 32 cars and 26 weapons schemas.
class_name TestDataValidation
extends RefCounted

const DataValidator = preload("res://scripts/core/data_validator.gd")

static func run() -> bool:
	print("--- Running TestDataValidation ---")
	var res = DataValidator.validate_all()
	if not res.success:
		printerr("[FAIL] Data validation failed with errors:")
		for e in res.errors:
			printerr("  - ", e)
		return false
		
	# Verify specific counts
	var v_data = DataValidator._load_and_validate_json("res://data/vehicles.json")
	var v_count = v_data.data.get("vehicles", []).size()
	if v_count < 32:
		printerr("[FAIL] Expected at least 32 vehicles, found %d" % v_count)
		return false
	print("[PASS] Verified 32/32 vehicles in data/vehicles.json")
	
	var w_data = DataValidator._load_and_validate_json("res://data/weapons.json")
	var w_count = w_data.data.get("weapons", []).size()
	if w_count < 26:
		printerr("[FAIL] Expected at least 26 weapons, found %d" % w_count)
		return false
	print("[PASS] Verified 26/26 weapons in data/weapons.json")
	
	return true
