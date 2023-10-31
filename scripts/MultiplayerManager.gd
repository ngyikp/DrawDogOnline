extends Node

const DEFAULT_IP = "127.0.0.1"
const DEFAULT_PORT = 33363

const LEVEL_RANGE = Vector2(20, 20)

const PAINT_CHANNEL = 2

var connection_status = ""

var ip = DEFAULT_IP
var port = DEFAULT_PORT

var server = false

var connected = false

var uid = 0

var USER_INFO = {
	"username": "Default", "position": Vector2.ZERO, "animation": "idle", "facing": false,
	"brush": {
		"position": Vector2.ZERO, "drawing": false, "color": 1, "size": 24
	}
}

# Server
var paint = {}
var players = {} # level: {pid: userinfo}
var player_location = {} # pid: level

# Client
var level_puppets = {} # pid: dogpuppet
var dogpuppet = preload("res://objects/dog_puppet.tscn")
var level_scene
var me = USER_INFO

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	process_mode = PROCESS_MODE_ALWAYS

# SIGNALS

func _on_player_connected(id):
	prints(" new peer", id)

func _on_player_disconnected(id):
	prints("lost peer", id)
	if server:
		if id in player_location:
			players[player_location[id]].erase(id)
			player_location.erase(id)
	else:
		if id in level_puppets:
			if is_instance_valid(level_puppets[id]):
				level_puppets[id].queue_free()
			level_puppets.erase(id)

func _on_connected_ok():
	connection_status = "Conncted to server"
	print("Connected to server!")
	connected = true
	uid = multiplayer.get_unique_id()
	me.position = level_scene.get_node("Dog").position
	me.username = Global.username
	set_loading(true)
	move_to_level.rpc_id(1, me, Global.current_level)

func _on_connected_fail():
	connection_status = "Connection to server failed"
	print("Connection to server failed.")
	set_loading(false)
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _on_server_disconnected():
	connection_status = "Disconnected from server"
	print("Disconnected from Server.")
	connected = false
	set_loading(false)
	get_tree().change_scene_to_file("res://scenes/title.tscn")

# OTHER

func set_loading(loading):
	Global.loading_screen.visible = loading

func get_ip_port(newip):
	if ":" in newip:
		var both = newip.split(":")
		ip = both[0]
		if not both[1].is_valid_int():
			return false
		port = int(both[1])
	ip = newip
	return true

func encode_diff(diff):
	var buffer = diff.to_ascii_buffer()
	return [buffer.size(), buffer.compress()]

func decode_diff(diff, size):
	return diff.decompress(size).get_string_from_ascii()

# SERVER

func check_level_in_bounds(level):
	if level.x > LEVEL_RANGE.x or level.x < -LEVEL_RANGE.x or level.y > LEVEL_RANGE.y or level.y < -LEVEL_RANGE.y:
		return false
	return true

func new_paint():
	var newpaint = []
	for i in range(Global.paint_total):
		if i % int(Global.paint_size.x) == 0:
			newpaint.append([])
		newpaint[-1].append(0)
	return newpaint
	
func load_level_paint(_level):
	return new_paint()

func check_server_level(level):
	if not check_level_in_bounds(level): return
	if level not in players:
		players[level] = {}
	if level not in paint:
		paint[level] = load_level_paint(level)

func server_start():
	var peer = WebSocketMultiplayerPeer.new()
	peer.supported_protocols = ["ludus"]
	var error = peer.create_server(port)
	if error:
		print(error)
	multiplayer.multiplayer_peer = peer
	print("Server Started")

var hex = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]

func paint_to_str(inpaint):
	var out = ""
	for y in inpaint:
		for i in y:
			out += hex[i]
	var buffer = out.to_ascii_buffer()
	return [buffer.size(), buffer.compress()]

func paint_from_str(instr, size):
	instr = instr.decompress(size).get_string_from_ascii()
	var newpaint = []
	for i in range(Global.paint_total):
		if i % int(Global.paint_size.x) == 0:
			newpaint.append([])
		newpaint[-1].append(instr[i].hex_to_int())
	return newpaint

func server_move_to_level(pid, userinfo, level):
	if pid in player_location:
		players[player_location[pid]].erase(pid)
		player_location.erase(pid)
	check_server_level(level)
	var newpaint = paint_to_str(paint[level])
	recieve_level_paint.rpc_id(pid, newpaint[1], newpaint[0])
	kill_puppets.rpc_id(pid)
	for puppet in players[level]:
		recieve_puppet.rpc_id(pid, puppet, players[level][puppet])
	players[level][pid] = userinfo
	player_location[pid] = level
	complete_level_move.rpc_id(pid)

func server_brush_update(pid, position, drawing, color, size):
	if pid in player_location:
		players[player_location[pid]][pid].brush.position = position
		players[player_location[pid]][pid].brush.drawing = drawing
		players[player_location[pid]][pid].brush.color = color
		players[player_location[pid]][pid].brush.size = size

func server_dog_update_position(pid, position):
	if pid in player_location:
		players[player_location[pid]][pid].position = position

func server_dog_update_animation(pid, animation):
	if pid in player_location:
		players[player_location[pid]][pid].animation = animation

@rpc("any_peer", "call_remote", "reliable", PAINT_CHANNEL)
func draw_diff_to_server(size, diff, rect, level):
	var _pid = multiplayer.get_remote_sender_id()
	draw_diff_from_server.rpc(size, diff, rect, level)
	diff = decode_diff(diff, size)
	var i = 0
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			if diff[i] != "X":
				var target_pos = rect.position + Vector2(x, y)
				paint[level][target_pos.y][target_pos.x] =  diff[i].hex_to_int()
			i += 1

# CLIENT

@rpc("authority", "call_remote", "reliable", PAINT_CHANNEL)
func draw_diff_from_server(size, diff, rect, level):
	draw_diff(size, diff, rect, level)

@rpc("any_peer", "call_remote", "unreliable") # unreliable paint doesn't need to be on paint channel
func draw_diff(size, diff, rect, level):
	var _pid = multiplayer.get_remote_sender_id()
	if server: return
	if level == Global.current_level:
		diff = decode_diff(diff, size)
		PaintUtil.apply_diff(Global.paint_target, diff, rect)

func add_puppet(pid, userinfo):
	var puppet = dogpuppet.instantiate()
	puppet.position = userinfo.position
	level_puppets[pid] = puppet
	level_scene.add_child(puppet)
	puppet.get_node("username").text = userinfo.username
	puppet.brush_position = userinfo.brush.position
	puppet.brush_drawing = userinfo.brush.drawing
	puppet.brush_color = userinfo.brush.color
	puppet.brush_size = userinfo.brush.size
	puppet.animation.play(userinfo.animation)
	puppet.animation.flip = userinfo.facing
	puppet.facing = userinfo.facing

@rpc("any_peer", "call_remote", "reliable", 3)
func move_to_level(userinfo, level):
	var pid = multiplayer.get_remote_sender_id()
	if server:
		return server_move_to_level(pid, userinfo, level)

@rpc("any_peer", "call_remote", "reliable", 3)
func clent_level_moved(userinfo, level):
	var pid = multiplayer.get_remote_sender_id()
	if server: return
	if level != Global.current_level:
		if pid in level_puppets:
			level_puppets[pid].queue_free()
			level_puppets.erase(pid)
	else:
		add_puppet(pid, userinfo)

@rpc("authority", "call_remote", "reliable", 3)
func recieve_level_paint(newpaint, size):
	Global.paint_target.clear_paint()
	Global.paint_target.paint = paint_from_str(newpaint, size)

@rpc("authority", "call_remote", "reliable", 3)
func kill_puppets():
	for puppet in level_puppets:
		level_puppets.erase(puppet)
	get_tree().call_group("dogpuppets", "queue_free")

@rpc("authority", "call_remote", "reliable", 3)
func recieve_puppet(puppet, userinfo):
	if puppet != uid:
		add_puppet(puppet, userinfo)

@rpc("authority", "call_remote", "reliable", 3)
func complete_level_move():
	get_tree().paused = false
	set_loading(false)
	clent_level_moved.rpc(me, Global.current_level)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func brush_update(position, drawing, color, size):
	var pid = multiplayer.get_remote_sender_id()
	if server:
		return server_brush_update(pid, position, drawing, color, size)
	if pid in level_puppets:
		level_puppets[pid].brush_position = position
		level_puppets[pid].brush_drawing = drawing
		level_puppets[pid].brush_color = color
		level_puppets[pid].brush_size = size

func brush_me_update(position, drawing, color, size):
	me.brush.position = position
	me.brush.drawing = drawing
	me.brush.color = color
	me.brush.size = size

@rpc("any_peer", "call_remote", "unreliable_ordered")
func dog_update_position(position):
	var pid = multiplayer.get_remote_sender_id()
	if server:
		return server_dog_update_position(pid, position)
	if pid in level_puppets:
		level_puppets[pid].position = position

@rpc("any_peer", "call_remote", "unreliable_ordered")
func dog_update_animation(animation):
	var pid = multiplayer.get_remote_sender_id()
	if server:
		return server_dog_update_animation(pid, animation)
	if pid in level_puppets:
		level_puppets[pid].animation.play(animation)

func start():
	if server:
		return server_start()
	get_tree().paused = true
	var peer = WebSocketMultiplayerPeer.new()
	peer.supported_protocols = ["ludus"]
	#var error = peer.create_client(ip, port)
	var error = peer.create_client("ws://%s:%s" % [ip, port])
	print("ws://%s:%s" % [ip, port])
	if error:
		print(error)
	multiplayer.multiplayer_peer = peer
	print("Connection Started")
