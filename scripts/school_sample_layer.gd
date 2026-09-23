extends Node2D
var sample
var fog = false
func _draw():
	if sample != null:
		if fog: sample.paint_fog(self)
		else: sample.paint_world(self)
