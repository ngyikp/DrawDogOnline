extends Node

var USER_INFO = {
	"username": "Default", "position": Vector2.ZERO, "animation": "idle", "facing": false,
	"brush": {
		"position": Vector2.ZERO, "drawing": false, "color": 1, "size": 24
	},
	"dog": Global.dog_dict
}
var level_puppets = {} # pid: dogpuppet
var dogpuppet = preload("res://objects/dog_puppet.tscn")
var level_scene
var dog
var me = USER_INFO

# Signal

func on_player_disconnected(id):
	if id in level_puppets:
		if is_instance_valid(level_puppets[id]):
			level_puppets[id].queue_free()
		level_puppets.erase(id)

func on_connected_ok():
	me.position = dog.position
	me.username = Global.username
	set_loading(true)
	MultiplayerManager.request_move_to_level.rpc_id(1, me, Global.current_level)

func on_connected_fail():
	set_loading(false)
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func on_server_disconnected():
	set_loading(false)
	get_tree().change_scene_to_file("res://scenes/title.tscn")

# Util

func brush_me_update(position, drawing, color, size):
	me.brush.position = position
	me.brush.drawing = drawing
	me.brush.color = color
	me.brush.size = size

func set_loading(loading):
	Global.loading_screen.visible = loading

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
	puppet.animation.set_dog_dict(userinfo.dog)
	puppet.brush.handle.modulate = userinfo.dog.color.brush_handle

# Start

func start():
	get_tree().paused = true
	var peer = WebSocketMultiplayerPeer.new()
	peer.supported_protocols = ["ludus"]
	#var error = peer.create_client(ip, port)
	var error = peer.create_client("ws://%s:%s" % [MultiplayerManager.ip, MultiplayerManager.port])
	if error:
		print(error)
	multiplayer.multiplayer_peer = peer
	print("Connection Started")

# RPC

func draw_diff(_pid, size, diff, rect, level):
	if level == Global.current_level:
		diff = MultiplayerManager.decode_diff(diff, size)
		PaintUtil.apply_diff(Global.paint_target, diff, rect)

func recieve_level_paint(_pid, newpaint, size):
	Global.paint_target.clear_paint()
	Global.paint_target.paint = MultiplayerManager.decompress_paint(newpaint, size)

func kill_puppets(_pid):
	for puppet in level_puppets:
		level_puppets.erase(puppet)
	get_tree().call_group("dogpuppets", "queue_free")

func recieve_puppet(_pid, puppet, userinfo):
	if puppet != MultiplayerManager.uid:
		add_puppet(puppet, userinfo)

func complete_level_move(_pid, level):
	Global.current_level = level
	get_tree().paused = false
	set_loading(false)
	MultiplayerManager.client_level_moved.rpc(me, level)

func client_level_moved(pid, userinfo, level):
	if level != Global.current_level:
		if pid in level_puppets:
			level_puppets[pid].queue_free()
			level_puppets.erase(pid)
	else:
		add_puppet(pid, userinfo)

func set_palette(_pid, palette, level):
	if level == Global.current_level:
		Global.palette = palette
		Global.paint_target.palette = palette
		Global.paint_target.setup_tilemap_layers()
		dog.brush.color_index = min(dog.brush.color_index, len(Global.palette)-1)

func brush_update(pid, position, drawing, color, size):
	if pid in level_puppets:
		if not is_instance_valid(level_puppets[pid]):
			level_puppets.erase(pid)
			return
		level_puppets[pid].brush_position = position
		level_puppets[pid].brush_drawing = drawing
		level_puppets[pid].brush_color = color
		level_puppets[pid].brush_size = size

func dog_update_position(pid, position):
	if pid in level_puppets:
		level_puppets[pid].position = position

func dog_update_animation(pid, animation):
	if pid in level_puppets:
		level_puppets[pid].animation.play(animation)

func dog_update_dog(pid, newdog):
	if pid == MultiplayerManager.uid:
		Global.dog_dict = newdog
		me.dog = newdog
		dog.animation.set_dog_dict(newdog)
		dog.brush.prop.handle.modulate = newdog.color.brush_handle
		Global.save_dog()
	if pid in level_puppets:
		level_puppets[pid].animation.set_dog_dict(newdog)
		level_puppets[pid].brush.handle.modulate = newdog.color.brush_handle
