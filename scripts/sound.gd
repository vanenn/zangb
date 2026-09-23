extends Node

var players = []
var clips = {}
var cooldowns = {}
var level = 0.45
var atmosphere: AudioStreamPlayer
var spatial_players = []
var audio_rng = RandomNumberGenerator.new()
const IMPACTS = ["paper_hit","heavy_hit","baton_hit","fire_hit","nail_hit","shotgun_hit","pistol_hit","slice_hit","stone_hit","electric_hit","acid_hit","saw_hit","bolt_hit","pulse_hit","water_hit","armor_hit","step","splash_step"]

func _ready():
	audio_rng.seed = 88715
	for i in range(16):
		var player = AudioStreamPlayer2D.new()
		player.max_distance = 1050
		player.attenuation = 1.5
		add_child(player)
		spatial_players.append(player)
	for i in range(10):
		var player = AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	for id in ["shot","melee","fire","hurt","pickup","rescue","bell","boss","victory","click","charge","hammer","baton","cleaver","saw","book","nail","shotgun","pistol","brick","bow","decoy","arc","acid","water","explosion"]:
		clips[id] = _synthesize(id)
	for id in IMPACTS: clips[id] = _synthesize(id)
	atmosphere = AudioStreamPlayer.new()
	add_child(atmosphere)
	atmosphere.stream = _synthesize("ambience")
	atmosphere.volume_db = -22
	atmosphere.play()
	set_level(level)

func set_level(value: float):
	level = clampf(value,0,1)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,level)))

func play(id: String):
	var now = Time.get_ticks_msec()
	if now < cooldowns.get(id,0) or not clips.has(id):
		return
	cooldowns[id] = now + (95 if id in ["shot","melee"] else 180)
	for player in players:
		if not player.playing:
			player.stream = clips[id]
			player.volume_db = -17 if id in ["shot","melee"] else -10
			player.play()
			return

func play_at(id: String,offset: Vector2,intensity: float = 1.0):
	if not clips.has(id) or offset.length() > 1050: return
	var now = Time.get_ticks_msec()
	var key = "world_"+id
	var continuous = id in ["saw","water","acid","fire_hit","water_hit","acid_hit","saw_hit"]
	if now < cooldowns.get(key,0): return
	cooldowns[key] = now+(130 if continuous else 65)
	var priority = intensity*(1.0-offset.length()/1100.0)
	var selected = null
	var least = INF
	for player in spatial_players:
		if not player.playing:
			selected = player
			break
		var score = player.get_meta("priority",0.0)
		if score < priority and score < least:
			least = score
			selected = player
	if selected == null: return
	selected.stop()
	selected.position = Vector2(800,450)+offset
	selected.stream = clips[id]
	selected.pitch_scale = audio_rng.randf_range(0.94,1.06)
	selected.volume_db = (-25.0 if continuous else -19.0)+linear_to_db(maxf(0.1,intensity))
	if id in ["explosion","heavy_hit","shotgun"]: selected.volume_db += 2.0
	selected.set_meta("priority",priority)
	selected.play()

func _synthesize(id: String) -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.12
	var frequency = 160.0
	match id:
		"heavy_hit": duration = 0.34; frequency = 64
		"shotgun_hit": duration = 0.25; frequency = 80
		"stone_hit": duration = 0.3; frequency = 115
		"armor_hit": duration = 0.3; frequency = 870
		"electric_hit": duration = 0.19; frequency = 1300
		"paper_hit": duration = 0.17; frequency = 400
		"baton_hit": duration = 0.16; frequency = 190
		"slice_hit": duration = 0.2; frequency = 420
		"nail_hit": duration = 0.12; frequency = 1280
		"pistol_hit": duration = 0.14; frequency = 720
		"bolt_hit": duration = 0.23; frequency = 145
		"pulse_hit": duration = 0.5; frequency = 55
		"fire_hit": duration = 0.22; frequency = 90
		"acid_hit": duration = 0.28; frequency = 450
		"water_hit": duration = 0.23; frequency = 600
		"saw_hit": duration = 0.18; frequency = 170
		"step": duration = 0.1; frequency = 85
		"splash_step": duration = 0.16; frequency = 280
		"charge": duration = 0.45; frequency = 110
		"hammer": duration = 0.27; frequency = 60
		"baton": duration = 0.1; frequency = 240
		"cleaver": duration = 0.18; frequency = 340
		"saw": duration = 0.18; frequency = 87
		"book": duration = 0.23; frequency = 410
		"nail": duration = 0.08; frequency = 1100
		"shotgun": duration = 0.3; frequency = 58
		"pistol": duration = 0.12; frequency = 260
		"brick": duration = 0.2; frequency = 72
		"bow": duration = 0.25; frequency = 370
		"decoy": duration = 0.4; frequency = 550
		"arc": duration = 0.22; frequency = 930
		"acid": duration = 0.4; frequency = 630
		"water": duration = 0.2; frequency = 410
		"explosion": duration = 0.7; frequency = 38
		"melee": duration = 0.15; frequency = 90
		"fire": duration = 0.3; frequency = 130
		"hurt": duration = 0.25; frequency = 65
		"pickup", "click": duration = 0.12; frequency = 680
		"rescue": duration = 0.65; frequency = 440
		"bell": duration = 1.8; frequency = 180
		"boss": duration = 1.4; frequency = 45
		"victory": duration = 1.4; frequency = 330
		"ambience": duration = 6; frequency = 43
	var data = PackedByteArray()
	data.resize(int(duration*rate)*2)
	var random = RandomNumberGenerator.new()
	random.seed = id.hash()
	var filtered_noise = 0.0
	var low_noise = 0.0
	for i in range(data.size()/2):
		var t = float(i)/rate
		var phase = t/duration
		var envelope = pow(1.0-phase,2.0)*minf(1,t*120)
		filtered_noise = lerpf(filtered_noise,random.randf_range(-1,1),0.12)
		low_noise = lerpf(low_noise,filtered_noise,0.045)
		var value = sin(t*frequency*TAU)*0.35
		if id in IMPACTS:
			match id:
				"heavy_hit", "shotgun_hit": value = sin(t*(frequency-20*phase)*TAU)*0.55*exp(-phase*6)+filtered_noise*0.7+sin(t*680*TAU)*0.12*exp(-phase*13)
				"armor_hit": value = (sin(t*frequency*TAU)+sin(t*frequency*2.71*TAU)*0.4)*0.35*exp(-phase*5)+filtered_noise*0.3
				"stone_hit", "bolt_hit": value = filtered_noise*1.1*exp(-phase*8)+sin(t*frequency*TAU)*0.33*exp(-phase*5)+low_noise
				"electric_hit": value = random.randf_range(-0.7,0.7)*pow(absf(sin(t*93*TAU)),4)+sin(t*(frequency-500*phase)*TAU)*0.13
				"pulse_hit": value = sin(t*(95-60*phase)*TAU)*0.5+low_noise*1.4
				"saw_hit": value = sin(t*frequency*TAU)*0.16+sin(t*frequency*5.1*TAU)*0.13+filtered_noise*1.4
				"acid_hit": value = filtered_noise*1.2+sin(t*(390+sin(t*23)*190)*TAU)*0.07
				"water_hit", "splash_step": value = filtered_noise*1.6*minf(1,t*60)+low_noise
				"fire_hit": value = filtered_noise*1.2+random.randf_range(-0.3,0.3)*pow(absf(sin(t*61*TAU)),22)
				"paper_hit": value = filtered_noise*0.8*(0.4+0.6*absf(sin(t*33*TAU)))
				"slice_hit": value = filtered_noise*1.4*exp(-phase*3)+sin(t*130*TAU)*0.2*exp(-phase*8)
				"step": value = low_noise*2.4+sin(t*85*TAU)*0.18*exp(-phase*10)
				_: value = filtered_noise*0.9+sin(t*frequency*TAU)*0.26*exp(-phase*10)
		elif id in ["shot","melee","fire","hurt"]:
			value = filtered_noise*1.6 + sin(t*(frequency-40*phase)*TAU)*0.15
		elif id in ["hammer","baton","cleaver","nail","shotgun","pistol","brick","explosion"]:
			value = filtered_noise*1.4+sin(t*frequency*TAU)*0.4*exp(-phase*6)
		elif id == "saw": value = sin(t*frequency*TAU)*0.3+sin(t*frequency*3*TAU)*0.18+filtered_noise
		elif id == "arc": value = random.randf_range(-0.6,0.6)*sin(t*140*TAU)+sin(t*frequency*TAU)*0.18
		elif id in ["water","acid"]: value = filtered_noise*1.8
		elif id == "charge": value = sin(t*(frequency+phase*200)*TAU)*0.3*phase
		elif id in ["rescue","victory"]:
			value += sin(t*frequency*1.25*TAU)*0.2 + sin(t*frequency*1.5*TAU)*0.17
		elif id == "bell":
			value += sin(t*frequency*2.76*TAU)*0.24+sin(t*frequency*5.4*TAU)*0.09
		elif id == "ambience":
			envelope = 1
			value = (sin(t*43*TAU)+sin(t*57*TAU)*0.3)*0.12+filtered_noise*0.055
		data.encode_s16(i*2,int(clampf(value*envelope,-1,1)*22000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	if id == "ambience":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size()/2
	return stream
