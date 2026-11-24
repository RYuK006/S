# src/campaign/boss_manager.gd
class_name BossManager
extends RefCounted

signal boss_phase_changed(phase: int, boss_name: String)
signal boss_defeated(boss_name: String)

var boss_name: String = ""
var max_hp: float = 3000.0
var current_hp: float = 3000.0
var current_phase: int = 1
var total_phases: int = 3
var is_active: bool = false

func initialize_boss(name_str: String, hp: float, phases: int = 3):
	boss_name = name_str
	max_hp = hp
	current_hp = hp
	current_phase = 1
	total_phases = phases
	is_active = true

func apply_boss_damage(amount: float) -> int:
	if not is_active: return current_phase
	current_hp = max(0.0, current_hp - amount)

	var hp_ratio = current_hp / max_hp
	var target_phase = 1

	if total_phases == 4: # The Warden
		if hp_ratio < 0.25: target_phase = 4
		elif hp_ratio < 0.50: target_phase = 3
		elif hp_ratio < 0.75: target_phase = 2
	else:
		if hp_ratio < 0.33: target_phase = 3
		elif hp_ratio < 0.66: target_phase = 2

	if target_phase > current_phase:
		current_phase = target_phase
		boss_phase_changed.emit(current_phase, boss_name)

	if current_hp <= 0.0:
		is_active = false
		boss_defeated.emit(boss_name)

	return current_phase

func get_boss_attack_pattern() -> Dictionary:
	# Returns attack configuration based on phase
	return {
		"phase": current_phase,
		"ram_aggression": 0.5 + (current_phase * 0.25),
		"fire_rate_multiplier": 1.0 + (current_phase * 0.4),
		"uses_flamethrower": current_phase >= 3,
		"salvo_size": current_phase * 2
	}
