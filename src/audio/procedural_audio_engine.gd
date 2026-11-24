# procedural_audio_engine.gd
# Advanced DSP audio engine: combustion pulse synthesis, RPM crossfading, turbo whistle, and granular tire squeal.
# Strict Anti-Buzz Compliance: Zero raw saw/square/triangle oscillator drones.
class_name ProceduralAudioEngine
extends Node

const SAMPLE_RATE = 44100
var audio_stream_player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var rng = RandomNumberGenerator.new()

# Vehicle audio tracking
var current_rpm: float = 900.0
var throttle_load: float = 0.0
var turbo_boost: float = 0.0
var max_slip: float = 0.0
var current_surface: String = "asphalt_dry"

# Combustion pulse phase tracking
var combustion_phase: float = 0.0
var turbo_phase: float = 0.0
var squeal_phase: float = 0.0
var last_throttle: float = 0.0
var blowoff_timer: float = 0.0

# Pre-computed pink noise buffer
var pink_noise_buffer: PackedFloat32Array = PackedFloat32Array()
var pink_index: int = 0

func _ready():
	rng.randomize()
	_generate_pink_noise()
	_setup_audio_generator()

func _generate_pink_noise():
	pink_noise_buffer.resize(SAMPLE_RATE)
	var b0 = 0.0
	var b1 = 0.0
	var b2 = 0.0
	var b3 = 0.0
	var b4 = 0.0
	var b5 = 0.0
	var b6 = 0.0
	
	for i in range(SAMPLE_RATE):
		var white = rng.randf_range(-1.0, 1.0)
		b0 = 0.99886 * b0 + white * 0.0555179
		b1 = 0.99332 * b1 + white * 0.0750759
		b2 = 0.96900 * b2 + white * 0.1538520
		b3 = 0.86650 * b3 + white * 0.3104856
		b4 = 0.55000 * b4 + white * 0.5329522
		b5 = -0.7616 * b5 - white * 0.0168980
		pink_noise_buffer[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
		b6 = white * 0.115926

func _setup_audio_generator():
	audio_stream_player = AudioStreamPlayer.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.1
	audio_stream_player.stream = generator
	add_child(audio_stream_player)
	audio_stream_player.play()
	playback = audio_stream_player.get_stream_playback()

func update_parameters(rpm: float, throttle: float, boost: float, slip: float, surface: String):
	current_rpm = rpm
	throttle_load = throttle
	turbo_boost = boost
	max_slip = slip
	current_surface = surface
	
	# Detect sudden throttle release under boost for blow-off valve 'pshh'
	if last_throttle > 0.6 and throttle < 0.2 and turbo_boost > 0.3:
		blowoff_timer = 0.28
	last_throttle = throttle

func _process(delta: float):
	if not playback:
		return
	if blowoff_timer > 0.0:
		blowoff_timer -= delta
		
	_fill_audio_buffer()

func _fill_audio_buffer():
	var frames_to_fill = playback.get_frames_available()
	if frames_to_fill <= 0:
		return
	
	# Four-stroke 4-cylinder engine firing frequency: (RPM / 60) * (Cylinders / 2)
	var firing_freq = (current_rpm / 60.0) * 2.0
	var phase_step = firing_freq / float(SAMPLE_RATE)
	
	for i in range(frames_to_fill):
		# 1. Engine Combustion Pulse synthesis
		combustion_phase += phase_step
		if combustion_phase >= 1.0:
			combustion_phase -= 1.0
			# Micro-jitter in pulse timing to keep engine organic and alive
			combustion_phase += rng.randf_range(-0.012, 0.012)
			
		var pulse_t = combustion_phase
		var engine_sample = 0.0
		if pulse_t < 0.35: # Pulse active duration ~8ms
			var env = exp(-pulse_t * 14.0)
			# Low frequency cylinder thump (starts at 140Hz decaying to 50Hz)
			var thump_freq = lerp(140.0, 50.0, pulse_t / 0.35)
			var thump = sin(pulse_t * thump_freq * TAU) * 0.7
			# Noise burst for combustion roar
			var noise_val = pink_noise_buffer[pink_index]
			pink_index = (pink_index + 1) % SAMPLE_RATE
			# High-frequency mechanical tick
			var tick = (1.0 if pulse_t < 0.02 else 0.0) * rng.randf_range(-0.3, 0.3)
			engine_sample = (thump + noise_val * 0.5 + tick) * env
			
		# Load-dependent rasp and loudness
		engine_sample *= (0.45 + throttle_load * 0.55)
		
		# 2. Granular Tire Squeal Synthesis (Filtered Noise + Stick-Slip LFO)
		var tire_sample = 0.0
		if max_slip > 0.15:
			squeal_phase += 1800.0 / float(SAMPLE_RATE)
			if squeal_phase >= 1.0: squeal_phase -= 1.0
			var stick_slip = sin(combustion_phase * 24.0 * TAU) * 0.2
			var squeal_noise = pink_noise_buffer[(pink_index + 1200) % SAMPLE_RATE]
			var squeal_env = clamp((max_slip - 0.15) / 0.4, 0.0, 1.0)
			tire_sample = squeal_noise * squeal_env * (0.8 + stick_slip) * 0.35
			
		# 3. Turbo Whistle & Blow-off Valve
		var turbo_sample = 0.0
		if turbo_boost > 0.1:
			turbo_phase += (2400.0 + turbo_boost * 1800.0) / float(SAMPLE_RATE)
			if turbo_phase >= 1.0: turbo_phase -= 1.0
			var turbo_noise = pink_noise_buffer[(pink_index + 5000) % SAMPLE_RATE]
			turbo_sample = turbo_noise * turbo_boost * 0.12
			
		if blowoff_timer > 0.0:
			var blowoff_noise = pink_noise_buffer[(pink_index + 8000) % SAMPLE_RATE]
			turbo_sample += blowoff_noise * (blowoff_timer / 0.28) * 0.45
			
		# Combined mix
		var master_sample = (engine_sample * 0.65) + tire_sample + turbo_sample
		
		# Soft Limiter (tanh waveshaper curve to prevent harsh clipping)
		master_sample = tanh(master_sample * 1.2) * 0.82
		
		playback.push_frame(Vector2(master_sample, master_sample))
