extends SceneTree

const Content = preload("res://scripts/content.gd")
const State = preload("res://scripts/run_state.gd")
const Store = preload("res://scripts/progress.gd")
const City = preload("res://scripts/city_map.gd")
const Combat = preload("res://scripts/combat.gd")
const Sound = preload("res://scripts/sound.gd")
var failures = []
var checks = 0
func _initialize(): call_deferred("execute")
func check(ok: bool,label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func execute():
	var book = Content.new()
	check(book.vfx_frames.size() == 28,"28 authored animation clips")
	for clip_id in book.vfx_frames:
		var frames = book.vfx_frames[clip_id]
		check(frames.size() == 6,"six frames: "+clip_id)
		var hashes = {}
		for frame in frames:
			var pixels = frame.atlas.get_image().get_region(frame.region)
			check(pixels.get_pixel(0,0).a < 0.05,"transparent cell corner: "+clip_id)
			hashes[pixels.get_data().hex_encode().sha256_text()] = true
		check(hashes.size() == 6,"six distinct painted frames: "+clip_id)
		check(book.effect_frame(clip_id,0) != book.effect_frame(clip_id,0.9),"animation advances to different artwork: "+clip_id)
	var run = State.new(book)
	run.start("teacher",110)
	var store = Store.new("res://tests/user/feedback-%s" % Time.get_ticks_msec())
	var city = City.new()
	city.setup(book,"school")
	root.add_child(city)
	var sim = Combat.new()
	sim.manual_tick = true
	sim.setup(book,run,store,city)
	root.add_child(sim)
	sim.begin_wave()
	var index = sim.spawn_enemy("shambler",sim.captain+Vector2(70,0))
	var enemy = sim.enemies[index]
	enemy.hp = 10000
	var rng_state = run.rng.state
	var position = enemy.pos
	for id in book.weapons:
		sim.feedback.reset()
		sim.feedback.impact(enemy,sim.captain,id,20)
		check(not sim.feedback.particles.is_empty(),"distinct particles emitted: "+id)
		check(enemy.recoil.length() > 0,"hit animation impulse: "+id)
	check(run.rng.state == rng_state and enemy.pos == position and enemy.hp == 10000,"cosmetic feedback does not mutate gameplay RNG, position or health")
	for i in range(100): sim.feedback.burst(enemy.pos,Vector2.RIGHT,sim.feedback.STYLES.wrench,20)
	check(sim.feedback.particles.size() <= 128,"bounded animation pool")
	store.settings.shake = false
	sim.shake_amount = 0
	sim.feedback.shake_gate = 0
	sim.feedback.shake(enemy.pos,8,Vector2.RIGHT)
	check(sim.shake_amount == 0,"screen shake toggle respected")
	store.settings.shake = true
	sim.feedback.shake(enemy.pos,8,Vector2.RIGHT)
	check(sim.shake_amount > 0 and sim.shake_amount <= 8,"screen shake capped")
	var shake = sim.shake_amount
	sim.feedback.shake(enemy.pos,8,Vector2.RIGHT)
	check(sim.shake_amount == shake,"simultaneous impacts cannot stack camera shake")
	store.settings.flash = false
	sim.feedback.reset()
	sim.feedback.shot(sim.captain,Vector2.RIGHT,"shotgun","captain")
	check(sim.feedback.particles.all(func(p): return p.kind != "muzzle"),"flash toggle removes muzzle flashes")
	store.settings.blood = false
	sim.feedback.reset()
	sim.feedback.impact(enemy,sim.captain,"cleaver",20)
	check(sim.feedback.particles.all(func(p): return p.color != Color("905341")),"reduced blood toggle removes blood particles")
	sim.feedback.shot(sim.captain,Vector2.RIGHT,"wrench","captain",true)
	check(sim.feedback.poses.captain.charge,"charge animation precedes heavy swing")
	var before = sim.feedback.poses.captain.life
	run.mode = "paused"
	sim.tick(0.5)
	check(sim.feedback.poses.captain.life == before,"pause freezes particles and attack poses")
	run.mode = "combat"
	sim.feedback.update(1)
	check(sim.feedback.poses.captain.life == 0,"attack pose expires")
	sim._damage(index,20000,sim.captain,"wrench")
	check(sim.feedback.corpses.size() == 1 and not enemy.active,"death animation survives entity removal")
	sim.feedback.update(1)
	check(sim.feedback.corpses.is_empty(),"death animation expires without corpse accumulation")
	var sound = Sound.new()
	root.add_child(sound)
	var fingerprints = {}
	var audio_metrics = []
	for id in sound.IMPACTS:
		var clip = sound.clips[id]
		var hash_value = clip.data.hex_encode().sha256_text()
		check(not fingerprints.has(hash_value),"unique impact waveform: "+id)
		fingerprints[hash_value] = id
		var peak = 0
		var sum_square = 0.0
		for i in range(clip.data.size()/2):
			var sample = clip.data.decode_s16(i*2)
			peak = maxi(peak,absi(sample))
			sum_square += float(sample)*sample
		check(peak > 100 and peak < 32767,"audible unclipped waveform: "+id)
		audio_metrics.append({"id":id,"peak":peak,"rms":sqrt(sum_square/(clip.data.size()/2)),"samples":clip.data.size()/2})
	check(sound.spatial_players.size() == 16,"bounded positional audio voices")
	var file = FileAccess.open("res://tests/feedback-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"audio":audio_metrics},"\t"))
	file.close()
	print("FEEDBACK ",checks," FAILURES ",failures)
	sound.queue_free()
	sim.queue_free()
	city.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
