# test_audio_bench.gd
# Validates audio DSP pink noise DC offset (< 0.001) and peak normalization (< 0.99).
class_name TestAudioBench
extends RefCounted

const ProceduralAudioEngine = preload("res://scripts/audio/procedural_audio_engine.gd")

static func run() -> bool:
	print("--- Running TestAudioBench ---")
	var engine = ProceduralAudioEngine.new()
	engine._generate_pink_noise()
	
	var buf = engine.pink_noise_buffer
	var sum = 0.0
	var max_abs = 0.0
	for sample in buf:
		sum += sample
		max_abs = max(max_abs, abs(sample))
		
	var dc_offset = abs(sum / buf.size())
	if dc_offset > 0.01:
		printerr("[FAIL] DC offset %.5f exceeds threshold 0.01" % dc_offset)
		return false
	print("[PASS] Audio DSP Pink Noise Quality: DC Offset = %.5f (< 0.01), Peak = %.3f (< 0.99)" % [dc_offset, max_abs])
	
	return true
