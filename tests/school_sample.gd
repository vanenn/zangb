extends SceneTree

var checks=0
var failures=[]
var sample
var report={"routes":[]}

func _initialize(): call_deferred("execute")

func check(ok: bool, label: String):
	checks+=1
	if not ok: failures.append(label); push_error(label)

func advance(seconds: float, held: bool=false):
	for i in range(ceili(seconds*60)): sample.tick_sample(1.0/60,Vector2.ZERO,held)

func site(id: String) -> Dictionary:
	for item in sample.sites:
		if item.id==id: return item
	return {}

func execute():
	sample=load("res://school_sample.tscn").instantiate()
	root.add_child(sample)
	sample.set_process(false)
	var city=sample.city
	var start=city.to_cell(sample.captain)
	for item in sample.sites:
		var at=Vector2(item.pos[0],item.pos[1])
		check(city.point_free(at,16),"site outside collision: "+item.id)
		check(not city.astar.get_point_path(start,city.to_cell(at)).is_empty(),"site reachable: "+item.id)
	# All doors closed must still leave the exit accessible from the entry.
	for door in city.fixtures: city.set_door(door.id,true)
	check(not city.astar.get_point_path(start,city.to_cell(Vector2(2120,280))).is_empty(),"all closed: permanent alternate route")
	for door in city.fixtures: city.set_door(door.id,false)
	for route in sample.layout.routes:
		var length=0.0
		for i in range(route.points.size()-1):
			var a=Vector2(route.points[i][0],route.points[i][1])
			var b=Vector2(route.points[i+1][0],route.points[i+1][1])
			check(city.clear_line(a,b,16),"route segment clearance: %s/%d"%[route.id,i])
			length+=a.distance_to(b)
		report.routes.append({"id":route.id,"length_px":snappedf(length,1),"walk_seconds_without_encounters":snappedf(length/220,0.1)})
	city.set_door("lab-exit",true)
	sample.captain=Vector2(1440,340)
	check(not sample.visible_at(Vector2(1620,340)),"closed door blocks visibility")
	check(city.move_actor(sample.captain,Vector2(250,0),16).x<1500,"closed door blocks movement")
	var revision=city.revision
	city.set_door("lab-exit",false)
	check(city.revision>revision,"door updates navigation revision")
	check(sample.visible_at(Vector2(1620,340)),"open door reveals far side")
	check(city.move_actor(sample.captain,Vector2(250,0),16).x>1600,"open door allows movement")
	sample.overview=false
	sample.captain=Vector2(200,400)
	advance(2.1,true)
	check(sample.health==95,"hold E heals")
	sample.apply_interaction(site("medical"))
	check(sample.health==95,"medical cannot settle twice")
	advance(0.1,false)
	sample.captain=Vector2(1390,550)
	advance(1.7,true)
	check(sample.rescued and sample.companions.size()==3,"rescue adds visible follower")
	sample.apply_interaction(site("rescue"))
	check(sample.companions.size()==3,"rescue cannot settle twice")
	advance(0.1,false)
	sample.captain=Vector2(1930,1510)
	advance(2.1,true)
	check(sample.cache_timer>0 and not sample.equipment,"cache starts delay")
	sample.paused=true
	var before=sample.cache_timer
	advance(2,false)
	check(sample.cache_timer==before,"pause freezes cache")
	sample.paused=false
	advance(8.1,false)
	advance(2.1,true)
	check(sample.equipment and sample.supplies==30,"cache grants equipment record and supplies")
	sample.apply_interaction(site("cache"))
	check(sample.supplies==30,"cache cannot settle twice")
	advance(0.1,false)
	sample.captain=Vector2(2120,280)
	advance(2.1,true)
	check(sample.exit_timer>0 and not sample.done,"exit requires preparation")
	sample.paused=true
	before=sample.exit_timer
	advance(2,false)
	check(sample.exit_timer==before,"pause freezes extraction")
	sample.paused=false
	advance(15.1,false)
	advance(2.1,true)
	check(sample.done,"second interaction completes evacuation")
	sample.restart()
	check(not sample.done and not sample.rescued and sample.health==60 and sample.supplies==0,"restart resets sample state")
	report.checks=checks
	report.failures=failures
	var file=FileAccess.open("res://tests/school-sample-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	sample.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
