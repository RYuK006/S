# race_manager.gd
# Race State Machine, lap counters, checkpoint progression and real-time position sorting.
class_name RaceManager
extends Node

const VehicleController = preload("res://scripts/vehicle/vehicle_controller.gd")
const SplineTrack = preload("res://scripts/race/spline_track.gd")

enum RaceState {
	INTRO,
	COUNTDOWN,
	RACING,
	PAUSED,
	RESULTS
}

signal countdown_tick(count: int, text: String)
signal lap_completed(car: VehicleController, lap: int, lap_time: float)
signal race_finished(winner: VehicleController, final_standings: Array)

var state: RaceState = RaceState.INTRO
var total_laps: int = 3
var countdown_timer: float = 3.99

var cars: Array[VehicleController] = []
var car_progress: Dictionary = {} # { car: { "lap": int, "next_checkpoint": int, "score": float, "is_finished": bool, "lap_times": Array } }
var current_standings: Array[VehicleController] = []

var track: SplineTrack
var player_car: VehicleController

# Timers
var race_time: float = 0.0
var current_lap_time: float = 0.0
var best_lap_time: float = 9999.0

func setup_race(p_track: SplineTrack, p_player: VehicleController, p_ai_cars: Array[VehicleController], laps: int = 3):
	track = p_track
	player_car = p_player
	total_laps = laps
	
	cars.clear()
	cars.append(player_car)
	cars.append_array(p_ai_cars)
	
	car_progress.clear()
	for c in cars:
		car_progress[c] = {
			"lap": 1,
			"next_checkpoint": 1, # First gate to pass after start line is Gate 1
			"visited_count": 0,
			"score": 0.0,
			"is_finished": false,
			"lap_times": [],
			"current_lap_timer": 0.0
		}
	
	current_standings = cars.duplicate()
	state = RaceState.COUNTDOWN
	countdown_timer = 3.99

func _physics_process(delta: float):
	match state:
		RaceState.COUNTDOWN:
			_process_countdown(delta)
		RaceState.RACING:
			_process_racing(delta)
		RaceState.PAUSED:
			pass
		RaceState.RESULTS:
			pass

func _process_countdown(delta: float):
	countdown_timer -= delta
	# Hold cars cleanly with handbrake in 1st gear during countdown (avoids reversing on brake input)
	for c in cars:
		c.throttle_input = 0.0
		c.brake_input = 0.0
		c.handbrake_input = true
		c.current_gear = 1
	
	if countdown_timer > 3.0:
		countdown_tick.emit(3, "3")
	elif countdown_timer > 2.0:
		countdown_tick.emit(2, "2")
	elif countdown_timer > 1.0:
		countdown_tick.emit(1, "1")
	elif countdown_timer > 0.0:
		countdown_tick.emit(0, "GO!")
	else:
		state = RaceState.RACING
		countdown_tick.emit(-1, "")
		for c in cars:
			c.handbrake_input = false
			c.brake_input = 0.0

func _get_node_pos(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position

func _process_racing(delta: float):
	race_time += delta
	current_lap_time += delta
	
	var num_gates = track.checkpoints.size()
	if num_gates == 0:
		return
		
	# 1. Update progression for each car
	for c in cars:
		var prog = car_progress[c]
		if prog.is_finished:
			continue
			
		prog.current_lap_timer += delta
		var next_gate_idx = prog.next_checkpoint
		var gate = track.checkpoints[next_gate_idx]
		
		# Check distance to target gate
		var car_pos = _get_node_pos(c)
		var gate_pos = _get_node_pos(gate)
		var d = car_pos.distance_to(gate_pos)
		if d < 14.0: # Checkpoint passed
			prog.visited_count += 1
			prog.next_checkpoint = (next_gate_idx + 1) % num_gates
			
			# Lap completes when crossing Gate 0 after completing the circuit gates
			if next_gate_idx == 0 and prog.visited_count >= (num_gates - 2):
				prog.visited_count = 0
				var finished_lap_time = prog.current_lap_timer
				prog.lap_times.append(finished_lap_time)
				prog.current_lap_timer = 0.0
				
				if c == player_car:
					best_lap_time = min(best_lap_time, finished_lap_time)
					current_lap_time = 0.0
					
				lap_completed.emit(c, prog.lap, finished_lap_time)
				
				if prog.lap >= total_laps:
					prog.is_finished = true
					if c == player_car:
						_finish_race()
				else:
					prog.lap += 1
		
		# Calculate continuous leaderboard score: Lap * 10000 + Checkpoint * 100 - DistToNext
		var next_gate_obj = track.checkpoints[prog.next_checkpoint]
		var dist_to_next = car_pos.distance_to(_get_node_pos(next_gate_obj))
		prog.score = (prog.lap * 10000.0) + (prog.next_checkpoint * 100.0) - dist_to_next
	
	# 2. Sort standings by score descending
	current_standings.sort_custom(func(a, b):
		return car_progress[a].score > car_progress[b].score
	)

func _finish_race():
	state = RaceState.RESULTS
	var winner = current_standings[0]
	race_finished.emit(winner, current_standings)

func get_player_position() -> int:
	for i in range(current_standings.size()):
		if current_standings[i] == player_car:
			return i + 1
	return 1
