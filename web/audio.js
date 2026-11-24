// web/audio.js
// Procedural Web Audio Engine with anti-buzz synthesis, zero DC offset,
// combustion pulse trains, granular tire squeal, and synthesized combat effects.

class ProceduralAudioEngine {
  constructor() {
    this.ctx = null;
    this.sampleRate = 44100;
    this.pinkNoise = new Float32Array(this.sampleRate);
    this.pinkIdx = 0;
    this.combustionPhase = 0;
    this.currentRPM = 900;
    this.throttleLoad = 0;
    this.turboBoost = 0;
    this.maxSlip = 0;
    this.blowoffTimer = 0;
    this.lastThrottle = 0;
    this.initialized = false;
  }

  init() {
    if (this.initialized) return;
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    this.ctx = new AudioContextClass();

    // Paul Kellet's filter for true pink noise
    let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
    let sum = 0;
    for (let i = 0; i < this.sampleRate; i++) {
      let white = (Math.random() * 2) - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      let val = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11;
      this.pinkNoise[i] = val;
      sum += val;
      b6 = white * 0.115926;
    }
    // Remove DC offset
    const mean = sum / this.sampleRate;
    let maxP = 0.0001;
    for (let i = 0; i < this.sampleRate; i++) {
      this.pinkNoise[i] -= mean;
      maxP = Math.max(maxP, Math.abs(this.pinkNoise[i]));
    }
    const scl = 0.85 / maxP;
    for (let i = 0; i < this.sampleRate; i++) this.pinkNoise[i] *= scl;

    this.scriptNode = this.ctx.createScriptProcessor(2048, 0, 2);
    this.compressor = this.ctx.createDynamicsCompressor();
    this.compressor.threshold.value = -12;
    this.compressor.knee.value = 8;
    this.compressor.ratio.value = 6;
    this.compressor.attack.value = 0.003;
    this.compressor.release.value = 0.15;

    this.scriptNode.onaudioprocess = (e) => this.processAudio(e);
    this.scriptNode.connect(this.compressor);
    this.compressor.connect(this.ctx.destination);
    this.initialized = true;
  }

  update(rpm, throttle, boost, slip) {
    this.currentRPM = rpm;
    this.throttleLoad = throttle;
    this.turboBoost = boost;
    this.maxSlip = slip;
    if (this.lastThrottle > 0.6 && throttle < 0.2 && boost > 0.3) this.blowoffTimer = 0.28;
    this.lastThrottle = throttle;
  }

  processAudio(e) {
    const left = e.outputBuffer.getChannelData(0);
    const right = e.outputBuffer.getChannelData(1);
    const len = left.length;
    const firingFreq = (this.currentRPM / 60.0) * 2.0;
    const phaseStep = firingFreq / this.sampleRate;

    for (let i = 0; i < len; i++) {
      this.combustionPhase += phaseStep;
      if (this.combustionPhase >= 1.0) {
        this.combustionPhase -= 1.0;
        this.combustionPhase += (Math.random() - 0.5) * 0.02;
      }
      let engineSample = 0;
      let pulseT = this.combustionPhase;
      if (pulseT < 0.35) {
        let env = Math.exp(-pulseT * 14.0);
        let thump = Math.sin(pulseT * (140.0 - pulseT * 250.0) * Math.PI * 2.0) * 0.7;
        let noise = this.pinkNoise[this.pinkIdx];
        this.pinkIdx = (this.pinkIdx + 1) % this.sampleRate;
        engineSample = (thump + noise * 0.55) * env;
      }
      engineSample *= (0.45 + this.throttleLoad * 0.55);

      let tireSample = 0;
      if (this.maxSlip > 0.14) {
        let squealNoise = this.pinkNoise[(this.pinkIdx + 1200) % this.sampleRate];
        let squealEnv = Math.min(1.0, (this.maxSlip - 0.14) / 0.4);
        tireSample = squealNoise * squealEnv * 0.32;
      }

      let turboSample = 0;
      if (this.turboBoost > 0.1) {
        turboSample += this.pinkNoise[(this.pinkIdx + 5000) % this.sampleRate] * this.turboBoost * 0.14;
      }
      if (this.blowoffTimer > 0) {
        turboSample += this.pinkNoise[(this.pinkIdx + 8000) % this.sampleRate] * (this.blowoffTimer / 0.28) * 0.45;
        this.blowoffTimer -= 1.0 / this.sampleRate;
      }

      let sample = Math.tanh(((engineSample * 0.65) + tireSample + turboSample) * 1.2) * 0.85;
      left[i] = sample;
      right[i] = sample;
    }
  }

  // Gunfire sound synthesis (punchy transient click + filtered noise burst)
  playGunfire() {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    
    // Low transient thud
    const osc = this.ctx.createOscillator();
    const oscGain = this.ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(180, now);
    osc.frequency.exponentialRampToValueAtTime(45, now + 0.05);
    oscGain.gain.setValueAtTime(0.45, now);
    oscGain.gain.exponentialRampToValueAtTime(0.001, now + 0.06);
    osc.connect(oscGain);
    oscGain.connect(this.compressor);
    osc.start(now);
    osc.stop(now + 0.06);

    // Crack noise
    const noiseBuf = this.ctx.createBuffer(1, 44100 * 0.08, 44100);
    const data = noiseBuf.getChannelData(0);
    for (let i = 0; i < data.length; i++) {
      data[i] = (Math.random() * 2 - 1) * Math.exp(-i / (44100 * 0.015));
    }
    const noiseSrc = this.ctx.createBufferSource();
    noiseSrc.buffer = noiseBuf;
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.value = 1600;
    filter.Q.value = 1.8;
    const noiseGain = this.ctx.createGain();
    noiseGain.gain.setValueAtTime(0.55, now);
    noiseGain.gain.exponentialRampToValueAtTime(0.01, now + 0.08);

    noiseSrc.connect(filter);
    filter.connect(noiseGain);
    noiseGain.connect(this.compressor);
    noiseSrc.start(now);
  }

  // Rocket launch whoosh
  playRocketLaunch() {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    const dur = 0.35;
    const buf = this.ctx.createBuffer(1, 44100 * dur, 44100);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) {
      let t = i / 44100;
      d[i] = (Math.random() * 2 - 1) * (1.0 - t / dur);
    }
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.setValueAtTime(350, now);
    filter.frequency.exponentialRampToValueAtTime(1400, now + dur);
    filter.Q.value = 2.5;

    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.5, now);
    gain.gain.exponentialRampToValueAtTime(0.01, now + dur);

    src.connect(filter);
    filter.connect(gain);
    gain.connect(this.compressor);
    src.start(now);
  }

  // Sub-bass explosive impact boom
  playExplosion() {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    const dur = 0.75;

    // Sub-bass sine boom
    const sub = this.ctx.createOscillator();
    const subGain = this.ctx.createGain();
    sub.type = 'sine';
    sub.frequency.setValueAtTime(95, now);
    sub.frequency.exponentialRampToValueAtTime(28, now + dur);
    subGain.gain.setValueAtTime(0.9, now);
    subGain.gain.exponentialRampToValueAtTime(0.001, now + dur);
    sub.connect(subGain);
    subGain.connect(this.compressor);
    sub.start(now);
    sub.stop(now + dur);

    // Deep noise rumble
    const buf = this.ctx.createBuffer(1, 44100 * dur, 44100);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) {
      let t = i / 44100;
      d[i] = (Math.random() * 2 - 1) * Math.exp(-t * 4.5);
    }
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(800, now);
    filter.frequency.exponentialRampToValueAtTime(120, now + dur);

    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.8, now);
    gain.gain.exponentialRampToValueAtTime(0.01, now + dur);

    src.connect(filter);
    filter.connect(gain);
    gain.connect(this.compressor);
    src.start(now);
  }

  // Dual tone musical pickup chime
  playPickupChime() {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    [880, 1320].forEach((freq, idx) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, now + idx * 0.08);
      gain.gain.setValueAtTime(0.35, now + idx * 0.08);
      gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.08 + 0.22);
      osc.connect(gain);
      gain.connect(this.compressor);
      osc.start(now + idx * 0.08);
      osc.stop(now + idx * 0.08 + 0.22);
    });
  }
}
