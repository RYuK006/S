// web/music_sequencer.js
// Procedural Industrial-Rock Music Synthesizer (Zero External Audio Files)
// Synthesizes drums (kick, snare, hi-hat), overdriven bass riffs and cyber leads at 135 BPM.

class ProceduralMusicSequencer {
  constructor(audioEngine) {
    this.audio = audioEngine;
    this.isPlaying = false;
    this.bpm = 135;
    this.step = 0;
    this.timer = null;
    this.bassNotes = [36.7, 43.65, 41.2, 49.0]; // D, F, E, G
    this.leadScale = [220, 246.94, 261.63, 293.66, 329.63, 349.23, 392.0];
  }

  toggle() {
    if (this.isPlaying) {
      this.stop();
    } else {
      this.start();
    }
    return this.isPlaying;
  }

  start() {
    if (!this.audio.ctx) this.audio.init();
    if (!this.audio.ctx || this.isPlaying) return;
    this.isPlaying = true;

    const stepInterval = (60.0 / this.bpm) / 4.0 * 1000.0; // 16th notes
    this.timer = setInterval(() => this.tick(), stepInterval);
    if (window.addBattleFeed) window.addBattleFeed("SOUNDTRACK: INDUSTRIAL COMBAT SEQUENCER ACTIVE");
  }

  stop() {
    this.isPlaying = false;
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  tick() {
    if (!this.audio.ctx) return;
    const now = this.audio.ctx.currentTime;
    const s = this.step % 16;

    // 1. Kick on beats 0, 4, 8, 12
    if (s % 4 === 0) {
      this.playKick(now);
    }

    // 2. Snare on beats 4, 12
    if (s === 4 || s === 12) {
      this.playSnare(now);
    }

    // 3. Hi-hat on 8th notes
    if (s % 2 === 0) {
      this.playHat(now, s % 4 === 2 ? 0.35 : 0.2);
    }

    // 4. Overdriven Bass riff
    if (s % 2 === 0) {
      const noteIdx = Math.floor(this.step / 16) % this.bassNotes.length;
      const freq = this.bassNotes[noteIdx];
      this.playBass(now, freq);
    }

    // 5. Melodic lead riff variation
    if (s === 2 || s === 7 || s === 10 || s === 14) {
      const leadFreq = this.leadScale[Math.floor(Math.random() * this.leadScale.length)];
      this.playLead(now, leadFreq);
    }

    this.step++;
  }

  playKick(now) {
    const osc = this.audio.ctx.createOscillator();
    const gain = this.audio.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(110, now);
    osc.frequency.exponentialRampToValueAtTime(36, now + 0.12);
    gain.gain.setValueAtTime(0.7, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.14);
    osc.connect(gain);
    gain.connect(this.audio.compressor);
    osc.start(now);
    osc.stop(now + 0.14);
  }

  playSnare(now) {
    // Noise snap
    const buf = this.audio.ctx.createBuffer(1, 44100 * 0.12, 44100);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.exp(-i / (44100 * 0.025));
    const src = this.audio.ctx.createBufferSource();
    src.buffer = buf;
    const filter = this.audio.ctx.createBiquadFilter();
    filter.type = 'highpass';
    filter.frequency.value = 1200;
    const gain = this.audio.ctx.createGain();
    gain.gain.setValueAtTime(0.45, now);
    gain.gain.exponentialRampToValueAtTime(0.01, now + 0.12);
    src.connect(filter);
    filter.connect(gain);
    gain.connect(this.audio.compressor);
    src.start(now);
  }

  playHat(now, vol = 0.2) {
    const buf = this.audio.ctx.createBuffer(1, 44100 * 0.04, 44100);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.exp(-i / (44100 * 0.008));
    const src = this.audio.ctx.createBufferSource();
    src.buffer = buf;
    const filter = this.audio.ctx.createBiquadFilter();
    filter.type = 'highpass';
    filter.frequency.value = 6500;
    const gain = this.audio.ctx.createGain();
    gain.gain.setValueAtTime(vol, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
    src.connect(filter);
    filter.connect(gain);
    gain.connect(this.audio.compressor);
    src.start(now);
  }

  playBass(now, freq) {
    const osc = this.audio.ctx.createOscillator();
    const gain = this.audio.ctx.createGain();
    const filter = this.audio.ctx.createBiquadFilter();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(freq, now);
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(320, now);
    filter.Q.value = 4.0;
    gain.gain.setValueAtTime(0.35, now);
    gain.gain.exponentialRampToValueAtTime(0.01, now + 0.16);
    osc.connect(filter);
    filter.connect(gain);
    gain.connect(this.audio.compressor);
    osc.start(now);
    osc.stop(now + 0.16);
  }

  playLead(now, freq) {
    const osc = this.audio.ctx.createOscillator();
    const gain = this.audio.ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(freq, now);
    gain.gain.setValueAtTime(0.25, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.22);
    osc.connect(gain);
    gain.connect(this.audio.compressor);
    osc.start(now);
    osc.stop(now + 0.22);
  }
}
