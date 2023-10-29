extends Node2D

var size = 24
var color_index = 0
var prev_position = Vector2.ZERO
var prev_paint_pos = Vector2.ZERO
var paint_pos = Vector2.ZERO

var flood_start_timer = 0.0
var flood_node

const FLOOD_START = 1.0
const BRUSH_SIZES = [6, 24, 72]

func reset_flood():
	flood_start_timer = 0.0
	if is_instance_valid(flood_node): flood_node.queue_free()

func _physics_process(delta):
	prev_position = position
	position = get_global_mouse_position()
	
	prev_paint_pos = paint_pos
	paint_pos = (position / Global.paint_res).round()
	
	if Input.is_action_just_pressed("brush_size_next"):
		size = BRUSH_SIZES[(BRUSH_SIZES.find(size)+1) % len(BRUSH_SIZES)]
		reset_flood()
		
	if Input.is_action_just_pressed("brush_color_next"):
		color_index = (color_index+1) % len(Global.palette)
		reset_flood()
	elif Input.is_action_just_pressed("brush_color_prev"):
		color_index = posmod(color_index-1, len(Global.palette))
		reset_flood()
	
	var drawing = false
	var draw_col
	if Input.is_action_pressed("draw"):
		draw_col = color_index + 1
		drawing = true
		if (not Input.is_action_pressed("erase") or Input.is_action_just_pressed("erase")) and Input.is_action_just_pressed("draw"): # If button just pressed change prev_pos to not use that
			prev_position = position
	if Input.is_action_pressed("erase"):
		draw_col = 0
		drawing = true
		if not Input.is_action_pressed("draw") and Input.is_action_just_pressed("erase"): # If button just pressed change prev_pos to not use that
			prev_position = position
	if drawing:
		if prev_position.distance_to(position) <= 1:
			flood_start_timer += delta
		else:
			reset_flood()
		if flood_start_timer > 1.0 and not flood_node:
			flood_node = PaintBurst.new(Global.paint_target, draw_col)
			flood_node.position = paint_pos
			add_child(flood_node)
		else:
			PaintUtil.draw_line(Global.paint_target, draw_col, prev_position/Global.paint_res, position/Global.paint_res, ceil(size / 12))
	else:
		reset_flood()

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
