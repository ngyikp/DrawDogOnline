extends Node2D
class_name PaintBurst

var paint

var queue = []
var dist = 0.0
var speed = 0.0
var accel = 0.0
var done = []
var farthest_dist = 0

var color = 0
var color_collide = -1 # -1 = no collide, 0+ = collide with all but color index (0 empty)

const CHECKED_CAP = 60

func _init(n_paint, n_color, n_color_collide=-1):
	paint = n_paint
	color = n_color
	color_collide = n_color_collide

func _ready():
	add_to_group("paintbursts")
	queue.append(position)
	for y in range(paint.size.y):
		for x in range(paint.size.x):
			if x == 0:
				done.append([])
			done[y].append(false)

func _process(delta):
	dist += speed*60*delta
	speed += accel*delta
	if speed <= 0:
		accel = 0.02*60 # values from original game times framerate for delta
	var checked = 0
	var end_time = Time.get_ticks_msec() + 1 # this is in the base game. time cap of 2ms
	if len(get_tree().get_nodes_in_group("paintburts")) >= 5:
		end_time += 1
	while queue and checked < CHECKED_CAP and Time.get_ticks_msec() < end_time:
		var pos = queue.pop_front()
		if color_collide > -1:
			if paint[pos.y][pos.x] != color_collide:
				continue
		var cur_dist = position.distance_to(pos)
		farthest_dist = max(cur_dist, farthest_dist)
		if cur_dist > dist:
			queue.append(pos)
			break
		PaintUtil.update_pos(paint, color, pos)
		var diff = Vector2(1, 1) # pos/neg is random in game but it only changes queue order so doesn't matter that much
		for newpos in [pos+Vector2(diff.x, 0), pos+Vector2(0, diff.y), pos-Vector2(diff.x, 0), pos-Vector2(0, diff.y)]:
			add_newpos(newpos)
		if cur_dist < farthest_dist:
			#diff = Vector2(1, 1) # this is rerandomised here but again it doesn't matter much
			for newpos in [pos+Vector2(diff.x, diff.y), pos+Vector2(-diff.x, diff.y), pos+Vector2(diff.x, -diff.y), pos+Vector2(-diff.x, -diff.y)]:
				add_newpos(newpos)
	if not queue:
		queue_free()

func add_newpos(newpos):
	if newpos.x > paint.size.x-1 or newpos.x < 0 or newpos.y > paint.size.y-1 or newpos.y < 0:
		return
	if not done[newpos.y][newpos.x]:
		done[newpos.y][newpos.x] = true
		queue.append(newpos)
