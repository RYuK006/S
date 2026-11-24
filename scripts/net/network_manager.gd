# scripts/net/network_manager.gd
class_name NetworkManager
extends Node

signal peer_connected_signal(id: int)
signal peer_disconnected_signal(id: int)
signal connection_succeeded
signal connection_failed

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 8
const RENDER_DELAY_SEC: float = 0.100 # 100ms interpolation buffer

var peer: ENetMultiplayerPeer
var is_server: bool = false
var is_active: bool = false
var local_peer_id: int = 1

# Snapshot buffers per peer: peer_id -> Array of Dictionary { "time": float, "data": Dictionary }
var remote_snapshots: Dictionary = {}

func _ready() -> void:
	# Check for dedicated server CLI launch flag
	for arg in OS.get_cmdline_args():
		if arg == "--server" or arg == "--dedicated-server":
			start_dedicated_server(DEFAULT_PORT)

func host_game(port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		printerr("[NET] Failed to start host server on port %d: %s" % [port, error_string(err)])
		return err
		
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	is_server = true
	is_active = true
	local_peer_id = 1
	print("[NET] Host server initialized on port %d (Max Clients: %d)" % [port, MAX_CLIENTS])
	return OK

func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		printerr("[NET] Failed to create client to %s:%d: %s" % [address, port, error_string(err)])
		return err
		
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	is_server = false
	is_active = true
	print("[NET] Client connecting to %s:%d..." % [address, port])
	return OK

func start_dedicated_server(port: int = DEFAULT_PORT) -> Error:
	print("[NET] Starting Headless Dedicated Relay Server...")
	return host_game(port)

func disconnect_game() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_active = false
	is_server = false
	remote_snapshots.clear()
	print("[NET] Network session closed.")

func _on_peer_connected(id: int) -> void:
	print("[NET] Peer connected: %d" % id)
	remote_snapshots[id] = []
	peer_connected_signal.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[NET] Peer disconnected: %d" % id)
	remote_snapshots.erase(id)
	peer_disconnected_signal.emit(id)

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	print("[NET] Connected to server successfully! Local Peer ID: %d" % local_peer_id)
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	printerr("[NET] Connection failed!")
	disconnect_game()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NET] Server disconnected.")
	disconnect_game()

func record_remote_snapshot(peer_id: int, snapshot_bytes: PackedByteArray, timestamp: float) -> void:
	if not remote_snapshots.has(peer_id):
		remote_snapshots[peer_id] = []
		
	var data := NetSnapshot.unpack_vehicle_snapshot(snapshot_bytes)
	if data.is_empty():
		return
		
	var list: Array = remote_snapshots[peer_id]
	list.append({ "time": timestamp, "data": data })
	
	# Cull stale snapshots older than 1 second
	while list.size() > 30:
		list.pop_front()

func interpolate_remote_vehicle(peer_id: int, current_time: float) -> Dictionary:
	var list: Array = remote_snapshots.get(peer_id, [])
	if list.is_empty():
		return {}
	if list.size() == 1:
		return list[0]["data"]
		
	var target_time := current_time - RENDER_DELAY_SEC
	
	# Find surrounding snapshot pair
	var s0: Dictionary = list[0]
	var s1: Dictionary = list[list.size() - 1]
	
	for i in range(list.size() - 1):
		if list[i]["time"] <= target_time and list[i + 1]["time"] >= target_time:
			s0 = list[i]
			s1 = list[i + 1]
			break
			
	var dt: float = s1["time"] - s0["time"]
	var alpha: float = 0.0
	if dt > 0.0001:
		alpha = clamp((target_time - s0["time"]) / dt, 0.0, 1.0)
		
	var d0: Dictionary = s0["data"]
	var d1: Dictionary = s1["data"]
	
	var pos0: Vector3 = d0.get("position", Vector3.ZERO)
	var pos1: Vector3 = d1.get("position", Vector3.ZERO)
	var rot0: Quaternion = d0.get("quaternion", Quaternion.IDENTITY)
	var rot1: Quaternion = d1.get("quaternion", Quaternion.IDENTITY)
	var vel0: Vector3 = d0.get("velocity", Vector3.ZERO)
	var vel1: Vector3 = d1.get("velocity", Vector3.ZERO)
	
	return {
		"position": pos0.lerp(pos1, alpha),
		"quaternion": rot0.slerp(rot1, alpha).normalized(),
		"velocity": vel0.lerp(vel1, alpha),
		"health": d1.get("health", 1000.0),
		"speed_kmh": int(lerp(float(d0.get("speed_kmh", 0)), float(d1.get("speed_kmh", 0)), alpha)),
		"gear": d1.get("gear", 1),
		"is_wrecked": d1.get("is_wrecked", false)
	}
