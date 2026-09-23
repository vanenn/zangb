extends Control

var sim

func _draw():
	if sim == null:
		return
	var scale_value = size / sim.city.bounds.size
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.07,0.11,0.09,0.87))
	for rect in sim.city.obstacles:
		draw_rect(Rect2(rect.position*scale_value,rect.size*scale_value),Color(0.47,0.51,0.42,0.65))
	for enemy in sim.enemies:
		if enemy.active and (enemy.boss or enemy.elite):
			draw_circle(enemy.pos*scale_value,4,Color("c2765f"))
	if not sim.rescue_done and not sim.rescue.is_empty():
		draw_arc(sim.rescue.pos*scale_value,4,0,TAU,12,Color("cddd98"),1.6)
	if not sim.scavenging.opened:
		for site in sim.scavenging.sites:
			draw_rect(Rect2(site.pos*scale_value-Vector2(3,3),Vector2(6,6)),Color("d8b972"),false,1.5)
	draw_circle(sim.captain*scale_value,3,Color("eee0b6"))
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.65,0.67,0.51,0.45),false,1)
