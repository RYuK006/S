# scripts/audio/music_sequencer.gd
class_name MusicSequencer
extends Node

const BPM: float = 135.0
const SECONDS_PER_BEAT: float = 60.0 / BPM
const STEP_TIME: float = SECONDS_PER_BEAT / 4.0 # 16th note steps (~0.111s)

enum IntensityState {
	MENU,
	COUNTDOWN,
	RACING,
	FINAL_LAP,
	RESULTS
}

var current_state: IntensityState = IntensityState.MENU
var is_playing: bool = true
var step_index: int = 0
var step_timer: float = 0.0
var measure_index: int = 0

# Synthesizer audio players
var kick_player: AudioStreamPlayer
var snare_player: AudioStreamPlayer
var hihat_player: AudioStreamPlayer
var bass_player: AudioStreamPlayer

# Procedural wave buffers
var kick_sample: AudioStreamWAV
var snare_sample: AudioStreamWAV
var hihat_sample: AudioStreamWAV
var bass_notes: Dictionary = {}

func _ready() -> void:
	_generate_drum_samples()
	_setup_audio_players()

func _generate_drum_samples() -> void:
	# 1. Procedural Heavy Kick: Pitch sweep 140Hz -> 35Hz with exponential decay
	var sample_rate := 22050
	var kick_len := int(sample_rate * 0.22)
	var kick_bytes := PackedByteArray()
	kick_bytes.resize(kick_len * 2)
	
	for i in range(kick_len):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 22.0)
		var freq := 35.0 + 105.0 * exp(-t * 30.0)
		var phase := t * freq * TAU
		var s := sin(phase) * env * 0.95
		kick_bytes.encode_s16(i * 2, int(clamp(s * 32767.0, -32767, 32767)))
		
	kick_sample = AudioStreamWAV.new()
	kick_sample.format = AudioStreamWAV.FORMAT_16_BITS
	kick_sample.mix_rate = sample_rate
	kick_sample.data = kick_bytes
	
	# 2. Snare: Filtered Pink Noise burst with zero DC offset
	var snare_len := int(sample_rate * 0.18)
	var snare_bytes := PackedByteArray()
	snare_bytes.resize(snare_len * 2)
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	
	for i in range(snare_len):
		var t := float(i) / float(sample_rate)
		var white := randf_range(-1.0, 1.0)
		b0 = 0.99886 * b0 + white * 0.0555179
		b1 = 0.99332 * b1 + white * 0.0750759
		b2 = 0.96900 * b2 + white * 0.1538520
		var pink := b0 + b1 + b2 + white * 0.5362
		var snap := sin(t * 190.0 * TAU) * exp(-t * 40.0) * 0.35
		var env := exp(-t * 18.0)
		var s := (pink * 0.65 + snap) * env
		snare_bytes.encode_s16(i * 2, int(clamp(s * 32767.0, -32767, 32767)))
		
	snare_sample = AudioStreamWAV.new()
	snare_sample.format = AudioStreamWAV.FORMAT_16_BITS
	snare_sample.mix_rate = sample_rate
	snare_sample.data = snare_bytes
	
	# 3. Hi-Hat: Resonant filtered noise click
	var hat_len := int(sample_rate * 0.06)
	var hat_bytes := PackedByteArray()
	hat_bytes.resize(hat_len * 2)
	for i in range(hat_len):
		var t := float(i) / float(sample_rate)
		var white := randf_range(-1.0, 1.0)
		var env := exp(-t * 60.0)
		var s := white * env * 0.5
		hat_bytes.encode_s16(i * 2, int(clamp(s * 32767.0, -32767, 32767)))
		
	hihat_sample = AudioStreamWAV.new()
	hihat_sample.format = AudioStreamWAV.FORMAT_16_BITS
	hihat_sample.mix_rate = sample_rate
	hihat_sample.data = hat_bytes

func _setup_audio_players() -> void:
	kick_player = AudioStreamPlayer.new()
	kick_player.bus = "Music"
	kick_player.stream = kick_sample
	add_child(kick_player)
	
	snare_player = AudioStreamPlayer.new()
	snare_player.bus = "Music"
	snare_player.stream = snare_sample
	add_child(snare_player)
	
	hihat_player = AudioStreamPlayer.new()
	hihat_player.bus = "Music"
	hihat_player.stream = hihat_sample
	add_child(hihat_player)

func _process(delta: float) -> void:
	if not is_playing:
		return
		
	step_timer += delta
	if step_timer >= STEP_TIME:
		step_timer -= STEP_TIME
		_trigger_step(step_index)
		step_index = (step_index + 1) % 16
		if step_index == 0:
			measure_index += 1

func _trigger_step(step: int) -> void:
	# 16-step rock drum patterns:
	# Kick on beats 0, 4, 8, 12, with offbeats in high intensity
	var is_kick := false
	if current_state == IntensityState.RACING or current_state == IntensityState.FINAL_LAP:
		is_kick = (step == 0 or step == 6 or step == 8 or step == 12 or (current_state == IntensityState.FINAL_LAP and step == 14))
	elif current_state == IntensityState.COUNTDOWN:
		is_kick = (step % 4 == 0)
	elif current_state == IntensityState.MENU:
		is_kick = (step == 0 or step == 8)
		
	if is_kick and kick_player:
		kick_player.play()
		
	# Snare on beats 4 and 12
	var is_snare := (step == 4 or step == 12)
	if is_snare and snare_player:
		snare_player.play()
		
	# Hi-hat on 8th notes (0, 2, 4, 6, 8, 10, 12, 14), 16th notes on Final Lap
	var is_hat := false
	if current_state == IntensityState.FINAL_LAP:
		is_hat = true # Driving 16th notes
	else:
		is_hat = (step % 2 == 0)
		
	if is_hat and hihat_player:
		hihat_player.volume_db = -6.0 if (step % 4 != 0) else -2.0
		hihat_player.play()

func set_intensity(state: IntensityState) -> void:
	current_state = state

func toggle() -> void:
	is_playing = not is_playing
	if not is_playing:
		if kick_player: kick_player.stop()
		if snare_player: snare_player.stop()
		if hihat_player: hihat_player.stop()
