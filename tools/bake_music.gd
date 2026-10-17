extends SceneTree
## Fabrique la musique et la banque de bruitages une fois pour toutes (lancé par le CI, pas dans le jeu) :
##   godot --headless --path . --script tools/bake_music.gd [-- --only=w1,menu] [--out=dossier] [--threads=N]
## Écrit assets/music/<piste>.wav pour chaque piste de scripts/music_player.gd (TRACKS) : menu, shrine
## (sanctuaire / marchand), w1…w8 (mondes, chacun avec sa couche de tension w1_t…w8_t), boss1…boss8
## (gardiens), mini (gardien de salle), win / lose (jingles). Le CI les convertit ensuite en OGG.
## Écrit aussi assets/sfx/bank.res (tous les bruitages de scripts/sfx.gd, déjà synthétisés : le jeu les charge
## au lieu de les fabriquer au lancement).
## Plusieurs pistes sont fabriquées en parallèle (un générateur par fil).

const MP = preload("res://scripts/music_player.gd")

var _todo: Array = []
var _mutex := Mutex.new()
var _failed := 0
var _dir := ""
var _secs := 0.0


func _initialize() -> void:
	var gen_script: GDScript = load("res://scripts/music.gd")
	if gen_script == null or not gen_script.new().has_method("render"):
		print("SCRIPT ERROR: scripts/music.gd illisible")
		quit(1)
		return
	var only: Array = []
	var nth := clampi(OS.get_processor_count() - 1, 1, 4)
	_dir = ProjectSettings.globalize_path("res://assets/music")
	var sfx_only := false
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--only="):
			only = Array(s.substr(7).split(",", false))
		elif s.begins_with("--out="):
			_dir = s.substr(6)
		elif s.begins_with("--threads="):
			nth = clampi(int(s.substr(10)), 1, 8)
		elif s == "--sfx-only":
			sfx_only = true
	DirAccess.make_dir_recursive_absolute(_dir)
	var t_all := Time.get_ticks_msec()
	if not sfx_only:
		# les plus longues d'abord (meilleur partage entre les fils)
		var order := ["w4", "w1", "w6", "w2", "w5", "w3", "w8", "w7"]
		for t in MP.TRACKS.keys():
			if not String(t) in order:
				order.append(String(t))
		for t in order:
			if only.is_empty() or t in only:
				_todo.append(t)
		var threads: Array = []
		for k in nth:
			var th := Thread.new()
			th.start(_work.bind(gen_script))
			threads.append(th)
		for th in threads:
			(th as Thread).wait_to_finish()
		print("musique : %d pistes, %.0f s de son, en %.1f s (%d fils)" % [MP.TRACKS.size() if only.is_empty() else only.size(), _secs, (Time.get_ticks_msec() - t_all) / 1000.0, nth])
	if only.is_empty() or sfx_only:
		var t0 := Time.get_ticks_msec()
		var sfx_script: GDScript = load("res://scripts/sfx.gd")
		var sfx: Object = sfx_script.new() if sfx_script != null else null
		if sfx == null or not sfx.has_method("bake_bank"):
			print("SCRIPT ERROR: scripts/sfx.gd illisible")
			_failed += 1
		else:
			var path := "res://assets/sfx/bank.res"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sfx"))
			var err: int = sfx.call("bake_bank", path)
			if err != OK:
				print("SCRIPT ERROR: banque de bruitages non écrite (%d)" % err)
				_failed += 1
			else:
				print("bruitages : %s en %.1f s" % [path, (Time.get_ticks_msec() - t0) / 1000.0])
			(sfx as Node).free()
	quit(1 if _failed > 0 else 0)


func _work(gen_script: GDScript) -> void:
	var gen: Object = gen_script.new()
	while true:
		_mutex.lock()
		var tname := ""
		if not _todo.is_empty():
			tname = String(_todo.pop_front())
		_mutex.unlock()
		if tname == "":
			break
		var t0 := Time.get_ticks_msec()
		var res: Dictionary = gen.call("render", tname)
		if res.is_empty():
			print("SCRIPT ERROR: musique non générée (", tname, ")")
			_mutex.lock()
			_failed += 1
			_mutex.unlock()
			continue
		for fname in res.keys():
			var w: AudioStreamWAV = res[fname]
			var path := _dir.path_join(String(fname) + ".wav")
			if w.save_to_wav(path) != OK:
				print("SCRIPT ERROR: écriture impossible ", path)
				_mutex.lock()
				_failed += 1
				_mutex.unlock()
				continue
			var secs := float(w.data.size()) / 2.0 / float(w.mix_rate)
			_mutex.lock()
			_secs += secs
			_mutex.unlock()
			print("musique %s : %.1f s (fabriquée en %d ms)" % [fname, secs, Time.get_ticks_msec() - t0])
