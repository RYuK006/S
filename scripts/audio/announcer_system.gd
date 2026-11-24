# scripts/audio/announcer_system.gd
class_name AnnouncerSystem
extends Node

signal announcement_triggered(text: String, cue_type: String)

var player: AudioStreamPlayer
var countdown_low_sample: AudioStreamWAV
var countdown_high_sample: AudioStreamWAV
var stinger_sample: AudioStreamWAV
var victory_sample: AudioStreamWAV

func _ready() -> void:
	_generate_announcer_tones()
	player = AudioStreamPlayer.new()
	player.bus = "Voice"
	add_child(player)

func _generate_announcer_tones() -> void:
	var sample_rate := 22050
	
	# Low beep (440 Hz A4, 150ms)
	var low_len := int(sample_rate * 0.15)
	var low_bytes := PackedByteArray()
	low_bytes.resize(low_len * 2)
	for i in range(low_len):
		var t := float(i) / float(sample_rate)
		var s := sin(t * 440.0 * TAU) * exp(-t * 8.0) * 0.8
		low_bytes.encode_s16(i * 2, int(clamp(s * 32767.0, -32767, 32767)))
	countdown_low_sample = AudioStreamWAV.new()
	countdown_low_sample.format = AudioStreamWAV.FORMAT_16_BITS
	countdown_low_sample.mix_rate = sample_rate
	countdown_low_sample.data = low_bytes
	
	# High beep (880 Hz A5, 280ms)
	var high_len := int(sample_rate * 0.28)
	var high_bytes := PackedByteArray()
	high_bytes.resize(high_len * 2)
	for i in range(high_len):
		var t := float(i) / float(sample_rate)
		var s := (sin(t * 880.0 * TAU) + 0.3 * sin(t * 1760.0 * TAU)) * exp(-t * 6.0) * 0.85
		high_bytes.encode_s16(i * 2, int(clamp(s * 32767.0, -32767, 32767)))
	countdown_high_sample = AudioStreamWAV.new()
	countdown_high_sample.format = AudioStreamWAV.FORMAT_16_BITS
	countdown_high_sample.mix_rate = sample_rate
	countdown_high_sample.data = high_bytes
	
	# Combat Stinger (Minor 3rd power chord sweep, 350ms)
	var stinger_len := int(sample_rate * 0.35)
	var stinger_bytes := PackedByteArray()
	stinger_bytes.resize(stinger_len * 2)
	for i in range(stinger_len):
		var t := float(i) / float(sample_rate)
		var s := (sin(t * 330.0 * TAU) + sin(t * 392.0 * TAU) + sin(t * 494.0 * TAU)) * 0.3 * exp(-t * 5.0)
		stinger_bytes.encode_s16(i * 2, int(clamp(s * 32767.0, -32767, 32767)))
	stinger_sample = AudioStreamWAV.new()
	stinger_sample.format = AudioStreamWAV.FORMAT_16_BITS
	stinger_sample.mix_rate = sample_rate
	stinger_sample.data = stinger_bytes

func play_countdown_low() -> void:
	if player:
		player.stream = countdown_low_sample
		player.play()
	announcement_triggered.emit("3... 2... 1...", "countdown")

func play_countdown_go() -> void:
	if player:
		player.stream = countdown_high_sample
		player.play()
	announcement_triggered.emit("GO!", "countdown")

func play_combat_callout(text: String) -> void:
	if player:
		player.stream = stinger_sample
		player.play()
	announcement_triggered.emit(text.to_upper(), "combat")

func play_final_lap() -> void:
	if player:
		player.stream = countdown_high_sample
		player.play()
	announcement_triggered.emit("FINAL LAP!", "race")

func play_victory() -> void:
	if player:
		player.stream = countdown_high_sample
		player.play()
	announcement_triggered.emit("VICTORY!", "race")
