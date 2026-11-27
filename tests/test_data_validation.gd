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
	if v_count < 62:
		printerr("[FAIL] Expected at least 62 vehicles (+30 new cars), found %d" % v_count)
		return false
	var unique_models: Dictionary = {}
	for v: Variant in v_data.data.get("vehicles", []):
		if v is Dictionary and (v as Dictionary).has("model_path"):
			unique_models[str((v as Dictionary)["model_path"])] = true
	if unique_models.size() < 45:
		printerr("[FAIL] Expected at least 45 unique 3D car GLB models on disk, found %d" % unique_models.size())
		return false
	print("[PASS] Verified %d vehicles across %d distinct 3D car models in data/vehicles.json" % [v_count, unique_models.size()])
	
	var w_data = DataValidator._load_and_validate_json("res://data/weapons.json")
	var w_count = w_data.data.get("weapons", []).size()
	if w_count < 26:
		printerr("[FAIL] Expected at least 26 weapons, found %d" % w_count)
		return false
	print("[PASS] Verified 26/26 weapons in data/weapons.json")
	
	return true
