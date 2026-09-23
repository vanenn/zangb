extends RefCounted

var members = []

func sync(run, captain: Vector2):
	while members.size() < run.roster.size():
		var index = members.size()
		members.append({"id":run.roster[index],"pos":captain,"cooldown":float(index%7)*0.09,"target":-1,"search":float(index%9)*0.02,"attack":0.0,"facing":1.0,"moving":0.0,"phase":index*2.4,"engage":captain,"engage_time":0.0,"stuck":0.0,"previous":captain,"stuck_time":0.0})

func offset(index: int) -> Vector2:
	var ring = int(floor(sqrt(index+1)))
	var radius = minf(34.0+ring*22.0,205.0)
	return Vector2.from_angle(float(index)*2.399963)*radius

func update(delta: float, captain: Vector2, city, speed: float):
	for index in range(members.size()):
		var person = members[index]
		var target = captain+offset(index)
		if not city.point_free(target,10) or not city.clear_line(captain,target):
			target = captain
		person.engage_time = maxf(0,person.engage_time-delta)
		if person.engage_time > 0 and person.engage.distance_to(captain) < 265 and city.clear_line(person.pos,person.engage,9): target = person.engage
		person.stuck_time += delta
		if person.stuck_time > 0.6:
			person.stuck = person.stuck+0.6 if person.pos.distance_to(person.previous) < 4 else 0.0
			person.previous = person.pos
			person.stuck_time = 0.0
		var distance = person.pos.distance_to(target)
		person.moving = minf(1,distance/18.0)
		if distance > 5:
			var direction = city.recovery_steer(person.pos,target,9) if person.stuck > 0.6 else city.steer(person.pos,target,9)
			person.pos = city.move_actor(person.pos,direction*minf(distance,delta*(speed+distance*1.7)),9)
			if absf(direction.x) > 0.15:
				person.facing = signf(direction.x)
		person.attack = maxf(0,person.attack-delta)
