extends SceneTree
## Fabrique les boucles musicales une fois pour toutes (lancé par le CI, pas dans le jeu) :
##   godot --headless --path . --script tools/bake_music.gd
## Écrit assets/music/m0.wav (menu) … m5.wav (mondes 1 à 5) ; le CI les convertit ensuite en OGG.

const IDS := [0, 1, 2, 3, 4, 5]

var _m: Node
var _frames := 0


func _initialize() -> void:
	_m = load("res://scripts/music.gd").new()
	root.add_child(_m)
	for id in IDS:
		_m.prepare(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/music"))


func _process(_delta: float) -> bool:
	_frames += 1
	for id in IDS:
		if not _m.is_ready(id):
			if _frames > 200000:
				print("SCRIPT ERROR: musique non générée (", id, ")")
				return true
			return false
	for id in IDS:
		var w: AudioStreamWAV = _m._cache[id]
		var path := ProjectSettings.globalize_path("res://assets/music/m%d.wav" % id)
		w.save_to_wav(path)
		print("musique ", id, " -> ", path)
	return true
