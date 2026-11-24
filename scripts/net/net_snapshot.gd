# src/net/net_snapshot.gd
class_name NetSnapshot
extends RefCounted

# Binary Snapshot Packing:
# Pos (3 x 16-bit signed fixed point, factor 100): 6 bytes
# Quat (4 x 16-bit signed fixed point, factor 10000): 8 bytes
# Velocity (3 x 16-bit signed fixed point, factor 100): 6 bytes
# Speed (uint8): 1 byte
# Health (uint16): 2 bytes
# Gear & Flags (uint8): 1 byte
# Total size: 24 bytes per vehicle snapshot!

static func pack_vehicle_snapshot(pos: Vector3, rot: Quaternion, vel: Vector3, health: float, gear: int, is_wrecked: bool) -> PackedByteArray:
	var buffer = PackedByteArray()
	buffer.resize(24)

	# Position (quantized to cm)
	buffer.encode_s16(0, int(clamp(pos.x * 100.0, -32767, 32767)))
	buffer.encode_s16(2, int(clamp(pos.y * 100.0, -32767, 32767)))
	buffer.encode_s16(4, int(clamp(pos.z * 100.0, -32767, 32767)))

	# Quaternion
	buffer.encode_s16(6, int(clamp(rot.x * 10000.0, -32767, 32767)))
	buffer.encode_s16(8, int(clamp(rot.y * 10000.0, -32767, 32767)))
	buffer.encode_s16(10, int(clamp(rot.z * 10000.0, -32767, 32767)))
	buffer.encode_s16(12, int(clamp(rot.w * 10000.0, -32767, 32767)))

	# Velocity
	buffer.encode_s16(14, int(clamp(vel.x * 100.0, -32767, 32767)))
	buffer.encode_s16(16, int(clamp(vel.y * 100.0, -32767, 32767)))
	buffer.encode_s16(18, int(clamp(vel.z * 100.0, -32767, 32767)))

	# Speed (0 - 255 km/h)
	var speed_kmh = int(clamp(vel.length() * 3.6, 0, 255))
	buffer.encode_u8(20, speed_kmh)

	# Health (0 - 5000)
	buffer.encode_u16(21, int(clamp(health, 0, 65535)))

	# Flags (bit 0: is_wrecked, bits 1-4: gear)
	var flags = (gear & 0x0F) << 1
	if is_wrecked: flags |= 0x01
	buffer.encode_u8(23, flags)

	return buffer

static func unpack_vehicle_snapshot(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 24: return {}

	var pos = Vector3(
		float(bytes.decode_s16(0)) / 100.0,
		float(bytes.decode_s16(2)) / 100.0,
		float(bytes.decode_s16(4)) / 100.0
	)

	var rot = Quaternion(
		float(bytes.decode_s16(6)) / 10000.0,
		float(bytes.decode_s16(8)) / 10000.0,
		float(bytes.decode_s16(10)) / 10000.0,
		float(bytes.decode_s16(12)) / 10000.0
	).normalized()

	var vel = Vector3(
		float(bytes.decode_s16(14)) / 100.0,
		float(bytes.decode_s16(16)) / 100.0,
		float(bytes.decode_s16(18)) / 100.0
	)

	var speed = bytes.decode_u8(20)
	var health = float(bytes.decode_u16(21))
	var flags = bytes.decode_u8(23)
	var is_wrecked = (flags & 0x01) != 0
	var gear = (flags >> 1) & 0x0F

	return {
		"position": pos,
		"quaternion": rot,
		"velocity": vel,
		"speed_kmh": speed,
		"health": health,
		"gear": gear,
		"is_wrecked": is_wrecked
	}
