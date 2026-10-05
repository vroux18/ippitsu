extends Node
## Joue les boucles musicales déjà fabriquées (assets/music/m0.ogg = menu, m1…m5 = mondes),
## avec un fondu enchaîné. Rien n'est calculé pendant le jeu : pas de saccade.
## Si les fichiers n'existent pas (version locale sans CI), le jeu reste simplement silencieux.

const FADE := 1.0

var volume_db := -10.0
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := -1
var _fade_t := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


func play_menu() -> void:
	_play(0)


func play_world(id: int) -> void:
	_play(clampi(id, 1, 5))


func prepare(_id: int) -> void:
	pass


func stop() -> void:
	_current = -1
	_fade_t = 0.0
	_active = 1 - _active  # le lecteur actif (silencieux) devient la cible du fondu


func _play(id: int) -> void:
	if id == _current:
		return
	var path := "res://assets/music/m%d.ogg" % id
	if not ResourceLoader.exists(path):
		return
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_current = id
	_active = 1 - _active
	var p := _players[_active]
	p.stream = s
	p.volume_db = -80.0
	p.play()
	_fade_t = 0.0


func _process(delta: float) -> void:
	if _fade_t < 0.0:
		return
	_fade_t += delta
	var k := clampf(_fade_t / FADE, 0.0, 1.0)
	var inc := _players[_active]
	var out := _players[1 - _active]
	if _current >= 0:
		inc.volume_db = linear_to_db(maxf(k, 0.0001)) + volume_db
	out.volume_db = linear_to_db(maxf(1.0 - k, 0.0001)) + volume_db
	if k >= 1.0:
		_fade_t = -1.0
		out.stop()
		if _current < 0:
			inc.stop()
