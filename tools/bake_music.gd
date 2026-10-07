extends SceneTree
## Fabrique la musique une fois pour toutes (lancé par le CI, pas dans le jeu) :
##   godot --headless --path . --script tools/bake_music.gd
## Écrit assets/music/<piste>.wav pour chaque piste de scripts/music_player.gd (TRACKS) :
## menu, w1…w5 (mondes), boss1…boss5 (gardiens), mini (gardien de salle), win / lose (jingles).
## Le CI les convertit ensuite en OGG.

const MP = preload("res://scripts/music_player.gd")


func _initialize() -> void:
	var gen_script: GDScript = load("res://scripts/music.gd")
	var gen: Object = null
	if gen_script != null:
		gen = gen_script.new()
	if gen == null or not gen.has_method("render"):
		print("SCRIPT ERROR: scripts/music.gd illisible")
		quit(1)
		return
	var dir := ProjectSettings.globalize_path("res://assets/music")
	DirAccess.make_dir_recursive_absolute(dir)
	var t_all := Time.get_ticks_msec()
	var failed := 0
	for t in MP.TRACKS.keys():
		var tname := String(t)
		var t0 := Time.get_ticks_msec()
		var w: AudioStreamWAV = gen.call("render", tname)
		if w == null:
			print("SCRIPT ERROR: musique non générée (", tname, ")")
			failed += 1
			continue
		var path := dir.path_join(tname + ".wav")
		if w.save_to_wav(path) != OK:
			print("SCRIPT ERROR: écriture impossible ", path)
			failed += 1
			continue
		var secs := float(w.data.size()) / 2.0 / float(w.mix_rate)
		print("musique %s : %.1f s (fabriquée en %d ms)" % [tname, secs, Time.get_ticks_msec() - t0])
	print("musique : %d pistes en %.1f s" % [MP.TRACKS.size(), (Time.get_ticks_msec() - t_all) / 1000.0])
	quit(1 if failed > 0 else 0)
