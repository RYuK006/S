// web/net_snapshot.js
// Compact 24-Byte Binary Snapshot Serialization & Deserialization

class NetSnapshotCodec {
  static packVehicleSnapshot(pos, quat, vel, health, gear, isWrecked) {
    const buffer = new ArrayBuffer(24);
    const view = new DataView(buffer);

    // Position (3 x 16-bit fixed point, factor 100)
    view.setInt16(0, Math.max(-32767, Math.min(32767, Math.round(pos.x * 100))), true);
    view.setInt16(2, Math.max(-32767, Math.min(32767, Math.round(pos.y * 100))), true);
    view.setInt16(4, Math.max(-32767, Math.min(32767, Math.round(pos.z * 100))), true);

    // Quaternion (4 x 16-bit fixed point, factor 10000)
    view.setInt16(6, Math.max(-32767, Math.min(32767, Math.round(quat.x * 10000))), true);
    view.setInt16(8, Math.max(-32767, Math.min(32767, Math.round(quat.y * 10000))), true);
    view.setInt16(10, Math.max(-32767, Math.min(32767, Math.round(quat.z * 10000))), true);
    view.setInt16(12, Math.max(-32767, Math.min(32767, Math.round(quat.w * 10000))), true);

    // Velocity (3 x 16-bit fixed point, factor 100)
    view.setInt16(14, Math.max(-32767, Math.min(32767, Math.round(vel.x * 100))), true);
    view.setInt16(16, Math.max(-32767, Math.min(32767, Math.round(vel.y * 100))), true);
    view.setInt16(18, Math.max(-32767, Math.min(32767, Math.round(vel.z * 100))), true);

    // Speed (Uint8, 0-255 km/h)
    const speed = Math.min(255, Math.round(vel.length() * 3.6));
    view.setUint8(20, speed);

    // Health (Uint16)
    view.setUint16(21, Math.min(65535, Math.round(health)), true);

    // Flags (bit 0: isWrecked, bits 1-4: gear)
    let flags = (gear & 0x0F) << 1;
    if (isWrecked) flags |= 0x01;
    view.setUint8(23, flags);

    return buffer;
  }

  static unpackVehicleSnapshot(buffer) {
    if (buffer.byteLength < 24) return null;
    const view = new DataView(buffer);

    const pos = new THREE.Vector3(
      view.getInt16(0, true) / 100.0,
      view.getInt16(2, true) / 100.0,
      view.getInt16(4, true) / 100.0
    );

    const quat = new THREE.Quaternion(
      view.getInt16(6, true) / 10000.0,
      view.getInt16(8, true) / 10000.0,
      view.getInt16(10, true) / 10000.0,
      view.getInt16(12, true) / 10000.0
    ).normalize();

    const vel = new THREE.Vector3(
      view.getInt16(14, true) / 100.0,
      view.getInt16(16, true) / 100.0,
      view.getInt16(18, true) / 100.0
    );

    const speed = view.getUint8(20);
    const health = view.getUint16(21, true);
    const flags = view.getUint8(23);
    const isWrecked = (flags & 0x01) !== 0;
    const gear = (flags >> 1) & 0x0F;

    return {
      position: pos,
      quaternion: quat,
      velocity: vel,
      speedKmh: speed,
      health: health,
      gear: gear,
      isWrecked: isWrecked
    };
  }
}
