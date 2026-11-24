// web/net_manager.js
// Local Multi-Tab BroadcastChannel & WebSocket Networking with Entity Interpolation

class NetworkManager {
  constructor(scene, playerCar) {
    this.scene = scene;
    this.playerCar = playerCar;
    this.peerId = `pilot_${Math.floor(Math.random() * 899999 + 100000)}`;
    this.connectedPeers = new Map(); // peerId -> { car, lastPos, targetPos, lastQuat, targetQuat, interpT }
    this.sendTimer = 0;
    this.sendInterval = 1.0 / 20.0; // 20 Hz
    this.isMultiplayerActive = false;

    // 1. Local Multi-Tab BroadcastChannel Support (Zero-Server, Zero-Dependency)
    if (typeof BroadcastChannel !== 'undefined') {
      try {
        this.broadcast = new BroadcastChannel('gridlethal_net');
        this.broadcast.onmessage = (e) => this.handleMessage(e.data);
        this.isMultiplayerActive = true;
      } catch (err) {
        console.warn("BroadcastChannel unavailable:", err.message);
      }
    }

    // 2. Optional Dedicated WebSocket Server Connection
    this.ws = null;
    this.initWebSocket();
  }

  initWebSocket() {
    try {
      this.ws = new WebSocket('ws://localhost:8080');
      this.ws.binaryType = 'arraybuffer';
      this.ws.onopen = () => {
        console.log("Connected to dedicated GRIDLETHAL relay server!");
      };
      this.ws.onmessage = (e) => {
        if (e.data instanceof ArrayBuffer) {
          const unpacked = NetSnapshotCodec.unpackVehicleSnapshot(e.data);
          if (unpacked) this.updateRemoteCar("server_peer", unpacked);
        }
      };
      this.ws.onerror = () => {
        // Silent fallback to BroadcastChannel
      };
    } catch (e) {
      // Fallback
    }
  }

  update(dt) {
    if (!this.isMultiplayerActive || !this.playerCar) return;

    // Transmit local snapshot at 20 Hz
    this.sendTimer += dt;
    if (this.sendTimer >= this.sendInterval) {
      this.sendTimer -= this.sendInterval;
      this.broadcastLocalState();
    }

    // Interpolate remote peer vehicles
    for (let [peerId, peer] of this.connectedPeers.entries()) {
      peer.interpT = Math.min(1.0, peer.interpT + dt * 15.0);
      peer.car.position.lerpVectors(peer.lastPos, peer.targetPos, peer.interpT);
      peer.car.quaternion.slerpQuaternions(peer.lastQuat, peer.targetQuat, peer.interpT);
      peer.car.meshGroup.position.copy(peer.car.position);
      peer.car.meshGroup.quaternion.copy(peer.car.quaternion);
    }
  }

  broadcastLocalState() {
    const p = this.playerCar;
    const snap = NetSnapshotCodec.packVehicleSnapshot(
      p.position,
      p.quaternion,
      p.velocity,
      p.health,
      p.currentGear,
      p.isWrecked
    );

    // Broadcast across tabs
    if (this.broadcast) {
      this.broadcast.postMessage({
        type: 'snapshot',
        sender: this.peerId,
        driverName: p.driverName,
        buffer: snap
      });
    }

    // Send via WebSocket if connected
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(snap);
    }
  }

  handleMessage(msg) {
    if (!msg || msg.sender === this.peerId) return;

    if (msg.type === 'snapshot' && msg.buffer) {
      const state = NetSnapshotCodec.unpackVehicleSnapshot(msg.buffer);
      if (state) {
        this.updateRemoteCar(msg.sender, state, msg.driverName);
      }
    }
  }

  updateRemoteCar(peerId, state, driverName = "Rival Pilot") {
    let peer = this.connectedPeers.get(peerId);

    if (!peer) {
      // Spawn new remote vehicle in scene
      const remoteCar = new VehicleController(this.scene, 0x00e5ff, false, driverName);
      peer = {
        car: remoteCar,
        lastPos: state.position.clone(),
        targetPos: state.position.clone(),
        lastQuat: state.quaternion.clone(),
        targetQuat: state.quaternion.clone(),
        interpT: 1.0
      };
      this.connectedPeers.set(peerId, peer);

      if (window.addBattleFeed) {
        window.addBattleFeed(`PILOT CONNECTED: ${driverName}!`);
      }
    } else {
      peer.lastPos.copy(peer.car.position);
      peer.targetPos.copy(state.position);
      peer.lastQuat.copy(peer.car.quaternion);
      peer.targetQuat.copy(state.quaternion);
      peer.interpT = 0.0;
      peer.car.health = state.health;
      peer.car.isWrecked = state.isWrecked;
    }
  }
}
