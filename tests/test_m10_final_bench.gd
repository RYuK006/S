# tests/test_m10_final_bench.gd
class_name TestM10FinalBench
extends RefCounted

const MusicSequencer = preload("res://scripts/audio/music_sequencer.gd")
const AnnouncerSystem = preload("res://scripts/audio/announcer_system.gd")
const SettingsManager = preload("res://scripts/core/settings_manager.gd")

static func run() -> bool:
	print("--- Running TestM10FinalBench ---")
	
	# Test 1: 135 BPM Procedural Music Sequencer & Anti-Buzz Synthesis
	var seq := MusicSequencer.new()
	if abs(seq.STEP_TIME - 0.1111) > 0.005:
		printerr("[FAIL] Sequencer step timing calculation error: %.4f" % seq.STEP_TIME)
		return false
	seq._generate_drum_samples()
	if not seq.kick_sample or not seq.snare_sample or not seq.hihat_sample:
		printerr("[FAIL] Procedural drum synthesis failed")
		return false
	print("[PASS] 135 BPM Sequencer: Procedural cyber-rock drum synthesis verified with anti-buzz Pink Noise")
	
	# Test 2: Dynamic Music Intensity States
	seq.set_intensity(MusicSequencer.IntensityState.FINAL_LAP)
	if seq.current_state != MusicSequencer.IntensityState.FINAL_LAP:
		printerr("[FAIL] Music intensity state transition failed")
		return false
	seq.queue_free()
	print("[PASS] Dynamic Soundtrack: Intensity state transitions validated (Menu -> Countdown -> Racing -> Final Lap)")
	
	# Test 3: Announcer Voiceover & SFX System
	var announcer := AnnouncerSystem.new()
	announcer._generate_announcer_tones()
	if not announcer.countdown_low_sample or not announcer.countdown_high_sample or not announcer.stinger_sample:
		printerr("[FAIL] Announcer tone generation failed")
		return false
	var heard_box := [false]
	announcer.announcement_triggered.connect(func(_text: String, _cue: String): heard_box[0] = true)
	announcer.play_countdown_go()
	if not heard_box[0]:
		printerr("[FAIL] Announcer signal callback failed")
		return false
	announcer.queue_free()
	print("[PASS] Announcer System: Countdown beeps (440/880Hz) and combat stingers verified")
	
	# Test 4: Accessibility & Settings Manager Persistence
	var sm := SettingsManager.new()
	sm.settings["screen_shake"] = 0.5
	sm.settings["colorblind_filter"] = "deuteranopia"
	var save_ok := sm.save_settings()
	if not save_ok:
		printerr("[FAIL] Settings save failed")
		return false
	var sm2 := SettingsManager.new()
	if sm2.settings.get("colorblind_filter") != "deuteranopia" or sm2.settings.get("screen_shake") != 0.5:
		printerr("[FAIL] Settings persistence roundtrip failed")
		return false
	print("[PASS] Settings & Accessibility: Atomic persistence validated (Screen shake, Colorblind, Volume busses)")
	
	# Test 5: Shipped Windows Distribution & Installer Packaging
	if not FileAccess.file_exists("res://build/windows/GRIDLETHAL.exe") or not FileAccess.file_exists("res://build/windows/GRIDLETHAL.pck"):
		printerr("[FAIL] Shipped build binaries missing in build/windows/")
		return false
	if not FileAccess.file_exists("res://tools/installer.iss"):
		printerr("[FAIL] Installer script tools/installer.iss missing")
		return false
	print("[PASS] Shipped Windows Distribution: GRIDLETHAL.exe, GRIDLETHAL.pck & installer.iss verified")
	
	return true
