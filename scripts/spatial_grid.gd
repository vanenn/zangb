extends RefCounted

const CELL = 112.0
var buckets = {}

func rebuild(entities: Array):
	buckets.clear()
	for index in range(entities.size()):
		var entity = entities[index]
		if not entity.active:
			continue
		var key = Vector2i(floori(entity.pos.x/CELL),floori(entity.pos.y/CELL))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(index)

func query(pos: Vector2, radius: float) -> Array:
	var result = []
	var low = Vector2i(floori((pos.x-radius)/CELL),floori((pos.y-radius)/CELL))
	var high = Vector2i(floori((pos.x+radius)/CELL),floori((pos.y+radius)/CELL))
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var key = Vector2i(x,y)
			if buckets.has(key):
				result.append_array(buckets[key])
	return result
