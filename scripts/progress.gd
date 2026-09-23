extends RefCounted

var directory = "user://"
var last_error = ""
var settings = {"volume":0.45,"shake":true,"flash":true,"blood":true,"fullscreen":false}
var meta = {"version":1,"runs":0,"wins":0,"best_kills":0,"best_team":0,"best_wave":0,"unlocked":["firefighter","sanitation","hunter","chemical_worker","demolitionist"],"seen":[],"finished_ids":[],"history":[]}

func _init(path: String = "user://"):
	directory=path
	DirAccess.make_dir_recursive_absolute(directory)
	var marker=_read("schema.json")
	if int(marker.get("version",0))!=3 and (int(_read("run.json").get("version",0))==3 or int(_read("progress.json").get("version",0))==3):
		marker={"version":3}
		if not _write("schema.json",marker): return
	if int(marker.get("version",0))!=3:
		# Exact allowlist only: no directory traversal or recursive deletion.
		var root=ProjectSettings.globalize_path(directory).simplify_path().trim_suffix("/")
		for stem in ["run","progress","settings"]:
			for tail in [".json",".json.bak",".json.tmp",".pre-v2.json"]:
				var target=root.path_join(stem+tail).simplify_path()
				if target.get_base_dir()!=root:
					last_error="存档目录验证失败"
					return
				if FileAccess.file_exists(target) and DirAccess.remove_absolute(target)!=OK:
					last_error="无法清理旧存档，请关闭旧版游戏后重试。"
					return
		if not _write("schema.json",{"version":3}): return
	var saved_settings=_read("settings.json")
	for key in settings:
		if saved_settings.has(key): settings[key]=saved_settings[key]
	var saved_meta=_read("progress.json")
	for key in meta:
		if saved_meta.has(key): meta[key]=saved_meta[key]
	meta.version=3
	meta.unlocked=["firefighter","sanitation","hunter","chemical_worker","demolitionist"]
	meta.difficulties=saved_meta.get("difficulties",{"easy":{"runs":0,"wins":0},"challenge":{"runs":0,"wins":0}})
	for key in ["runs","wins","best_kills","best_team","best_wave"]: meta[key]=int(meta[key])

func _read(file: String) -> Dictionary:
	for suffix in ["", ".bak"]:
		var path = directory.path_join(file + suffix)
		if FileAccess.file_exists(path):
			var parser = JSON.new()
			if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary:
				return parser.data
	return {}

func _write(file: String, data: Dictionary) -> bool:
	last_error = ""
	var path = directory.path_join(file)
	var pending = path + ".tmp"
	var handle = FileAccess.open(pending, FileAccess.WRITE)
	if handle == null:
		last_error = "无法写入存档，请检查磁盘空间和目录权限。"
		return false
	handle.store_string(JSON.stringify(data, "\t"))
	handle.flush()
	var result = handle.get_error()
	handle.close()
	if result != OK:
		last_error = "存档写入失败，当前进度仍保留在内存中。"
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		if DirAccess.rename_absolute(path, path + ".bak") != OK:
			last_error = "无法更新存档备份。"
			return false
	if DirAccess.rename_absolute(pending, path) != OK:
		last_error = "无法完成存档替换，已保留上一份备份。"
		return false
	return true

func load_run() -> Dictionary:
	var data = _read("run.json")
	if data.get("finished",false) or data.get("run_id","") in meta.finished_ids:
		return {}
	return data

func save_run(run) -> bool:
	return _write("run.json",run.snapshot())

func save_settings() -> bool:
	return _write("settings.json", settings)

func observe(id: String):
	if id not in meta.seen:
		meta.seen.append(id)

func unlock_for_wave(wave: int) -> Array:
	meta.best_wave=maxi(meta.best_wave,wave)
	_write("progress.json",meta)
	return []

func finish(run, win: bool) -> bool:
	if run.run_id in meta.finished_ids:
		return true
	var before = meta.duplicate(true)
	meta.finished_ids.append(run.run_id)
	meta.runs += 1
	meta.difficulties[run.difficulty].runs += 1
	if win: meta.difficulties[run.difficulty].wins += 1
	if win:
		meta.wins += 1
	meta.best_kills = maxi(meta.best_kills, run.kills)
	meta.best_team = maxi(meta.best_team, run.roster.size() + 1)
	meta.best_wave = maxi(meta.best_wave, run.wave)
	meta.history.push_front({"difficulty":run.difficulty,"mods":run.mods.duplicate(),"equipment":run.equipment.duplicate(),"class":run.class_id,"wave":run.wave,"win":win,"team":run.roster.size()+1,"kills":run.kills,"date":Time.get_date_string_from_system()})
	if meta.history.size() > 12:
		meta.history.resize(12)
	if not _write("progress.json", meta):
		meta = before
		return false
	return _write("run.json", {"finished":true,"run_id":run.run_id})
