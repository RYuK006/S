// web/physics.js
// Pacejka Magic Formula Tire Model and 4-Corner Raycast Suspension

class PacejkaTire {
  constructor() {
    this.peakSlip = 0.13;
    this.slideSlip = 0.55;
    this.peakMu = 1.65;
    this.slideMu = 1.12;
    this.longMu = 1.55;
    this.loadSensitivity = 0.22;
    this.nominalLoad = 2600.0;
  }

  solve(fz, slipRatio, slipAngle, surfaceMu = 1.0) {
    if (fz <= 10.0) return { fx: 0, fy: 0, saturation: 0, isSliding: false };
    const loadRatio = fz / this.nominalLoad;
    const effPeakMu = Math.max(0.05, this.peakMu * (1.0 - this.loadSensitivity * (loadRatio - 1.0)) * surfaceMu);
    const effSlideMu = Math.max(0.05, this.slideMu * (1.0 - this.loadSensitivity * (loadRatio - 1.0)) * surfaceMu);
    const effLongMu = Math.max(0.05, this.longMu * (1.0 - this.loadSensitivity * (loadRatio - 1.0)) * surfaceMu);

    const fxPure = (effLongMu * fz) * Math.sin(1.65 * Math.atan(10.0 * slipRatio));
    const absSlip = Math.abs(slipAngle);
    const dLat = effPeakMu * fz;
    let fyPure = 0;
    if (absSlip <= this.peakSlip) {
      fyPure = dLat * Math.sin((absSlip / this.peakSlip) * (Math.PI * 0.5));
    } else {
      let t = Math.min(1.0, (absSlip - this.peakSlip) / (this.slideSlip - this.peakSlip));
      t = t * t * (3.0 - 2.0 * t);
      fyPure = dLat * (1.0 - t) + (effSlideMu * fz) * t;
    }
    fyPure *= Math.sign(slipAngle);

    const fxMax = effLongMu * fz;
    const normFx = Math.min(1.0, Math.abs(fxPure) / Math.max(1.0, fxMax));
    const fyCoupled = fyPure * Math.sqrt(Math.max(0.0, 1.0 - normFx * normFx));
    const saturation = Math.sqrt(Math.pow(fxPure / Math.max(1, fxMax), 2) + Math.pow(fyCoupled / Math.max(1, dLat), 2));
    return { fx: fxPure, fy: fyCoupled, saturation, isSliding: saturation >= 1.0 };
  }
}

class RaycastWheel {
  constructor(isFront, isLeft, relPos) {
    this.isFront = isFront;
    this.isLeft = isLeft;
    this.relPos = relPos.clone();
    this.restLength = 0.38;
    this.travel = 0.18;
    this.springRate = 28000.0;
    this.dampingBump = 2400.0;
    this.dampingRebound = 3600.0;
    this.antiRollRate = 6500.0;
    this.radius = 0.32;

    this.compression = 0;
    this.compressionVel = 0;
    this.normalForce = 0;
    this.slipAngle = 0;
    this.slipRatio = 0;
    this.steerAngle = 0;
    this.wheelAngularVelocity = 0;
    this.driveTorque = 0;
    this.brakeTorque = 0;
    this.handbrakeFactor = 1.0;
    this.isGrounded = false;
    this.surfaceMu = 1.0;
    this.tire = new PacejkaTire();
    this.oppositeWheel = null;
    this.visualMesh = null;
  }

  update(chassis, dt, groundHeight = 0) {
    const worldAnchor = this.relPos.clone().applyMatrix4(chassis.matrixWorld);
    const dist = (worldAnchor.y - groundHeight) - this.radius;

    if (dist > this.restLength + this.travel) {
      this.isGrounded = false;
      this.compression = 0;
      this.normalForce = 0;
      if (this.visualMesh) this.visualMesh.position.y = this.relPos.y - this.restLength;
      return new THREE.Vector3();
    }

    this.isGrounded = true;
    const targetComp = Math.max(0, Math.min(this.travel, this.restLength - dist));
    this.compressionVel = (targetComp - this.compression) / Math.max(0.0001, dt);
    this.compression = targetComp;

    if (this.visualMesh) {
      this.visualMesh.position.y = this.relPos.y - dist;
      this.visualMesh.rotation.y = this.steerAngle;
      this.visualMesh.rotation.x += this.wheelAngularVelocity * dt;
    }

    let springF = this.compression * this.springRate;
    if (this.compression > this.travel * 0.85) {
      springF += Math.pow((this.compression - this.travel * 0.85) / (this.travel * 0.15), 2) * this.springRate * 2.5;
    }
    const damperF = this.compressionVel > 0 ? this.compressionVel * this.dampingBump : this.compressionVel * this.dampingRebound;
    let antiRollF = this.oppositeWheel ? (this.compression - this.oppositeWheel.compression) * this.antiRollRate : 0;
    this.normalForce = Math.max(0, springF + damperF + antiRollF);

    const forwardDir = new THREE.Vector3(0, 0, -1).applyEuler(new THREE.Euler(0, this.steerAngle, 0)).applyQuaternion(chassis.quaternion);
    const rightDir = new THREE.Vector3(1, 0, 0).applyEuler(new THREE.Euler(0, this.steerAngle, 0)).applyQuaternion(chassis.quaternion);

    const rArm = new THREE.Vector3().subVectors(worldAnchor, chassis.position);
    const wheelVel = chassis.velocity.clone().add(new THREE.Vector3().crossVectors(chassis.angularVelocity, rArm));
    const vLong = forwardDir.dot(wheelVel);
    const vLat = rightDir.dot(wheelVel);
    const absVLong = Math.max(0.5, Math.abs(vLong));

    this.slipAngle = -Math.atan2(vLat, absVLong);
    this.slipRatio = ((this.wheelAngularVelocity * this.radius) - vLong) / absVLong;

    const effMu = this.surfaceMu * (this.isFront ? 1.0 : this.handbrakeFactor);
    const res = this.tire.solve(this.normalForce, this.slipRatio, this.slipAngle, effMu);

    const netTorque = this.driveTorque - (res.fx * this.radius) - (Math.sign(this.wheelAngularVelocity) * this.brakeTorque);
    this.wheelAngularVelocity += (netTorque / (0.5 * 14.0 * this.radius * this.radius)) * dt;

    return new THREE.Vector3(0, this.normalForce, 0).add(forwardDir.multiplyScalar(res.fx)).add(rightDir.multiplyScalar(res.fy));
  }
}
