extends Node
## Joue la musique fabriquée une fois pour toutes par le CI (assets/music/<piste>.ogg, voir
## tools/bake_music.gd et scripts/music.gd) : rien n'est synthétisé pendant le jeu.
##  - boucles des mondes / de l'accueil / du sanctuaire / des gardiens : l'introduction n'est jouée qu'une fois
##    (LOOP_START), puis le corps boucle ;
##  - chaque monde a deux couches synchrones (AudioStreamSynchronized) : calme (hors combat) et tension
##    (« wN_t » : taiko, ostinato), qui monte en combat et retombe quelques secondes après le dernier ennemi ;
##  - sanctuaire (départ, pactes) et échoppe du marchand : thème du sanctuaire en fondu croisé, puis la boucle
##    du monde reprend là où elle était ; idem après un gardien ;
##  - jingles de victoire / défaite (une fois), puis la musique de l'accueil revient doucement ;
##  - fondus enchaînés à puissance constante, en temps réel : marche aussi pendant la pause
##    (Engine.time_scale = 0), la musique y est juste un peu baissée ;
##  - son coupé (bus principal muet) : lecture suspendue (aucun décodage) ;
##  - chargement en arrière-plan (ResourceLoader.load_threaded_request) ;
##  - fichier absent (version locale sans CI) : silence, sans erreur.
## L'humeur (combat, sanctuaire) est lue sur le nœud parent (main.gd : state, enemies, shop, _pick_mode, in_hub)
## quatre fois par seconde.

const DIR := "res://assets/music/"
const WORLDS := 8  # mondes ayant leur boucle (w1…w8) et leur gardien (boss1…boss8)
const FADE := 1.2
const DUCK_DB := -4.0
const LAYER_IN := 1.6  # montée de la couche de tension (s)
const LAYER_OUT := 4.5  # retombée
const FIGHT_HOLD := 3.0  # la tension tient encore après le dernier ennemi (entre deux vagues)
const MOOD_EVERY := 0.25

## Pistes : true = boucle, false = jingle joué une seule fois.
const TRACKS := {
	"menu": true,
	"shrine": true,
	"w1": true,
	"w2": true,
	"w3": true,
	"w4": true,
	"w5": true,
	"w6": true,
	"w7": true,
	"w8": true,
	"boss1": true,
	"boss2": true,
	"boss3": true,
	"boss4": true,
	"boss5": true,
	"boss6": true,
	"boss7": true,
	"boss8": true,
	"mini": true,
	"win": false,
	"lose": false,
}

## Suffixe de la couche de tension d'un monde (même durée, même raccord que sa couche calme).
const LAYER_SUFFIX := "_t"

## Début de la boucle (s) : ce qui précède est l'introduction, jouée une seule fois.
## Lu aussi par scripts/music.gd au moment de fabriquer les pistes (mêmes tempos).
const LOOP_START := {
	"w1": 8.0 * 60.0 / 84.0,
	"w2": 8.0 * 60.0 / 72.0,
	"w3": 8.0 * 60.0 / 63.0,
	"w4": 8.0 * 60.0 / 116.0,
	"w5": 8.0 * 60.0 / 76.0,
	"w6": 8.0 * 60.0 / 92.0,
	"w7": 8.0 * 60.0 / 66.0,
	"w8": 8.0 * 60.0 / 56.0,
	"boss1": 4.0 * 60.0 / 132.0,
	"boss2": 4.0 * 60.0 / 128.0,
	"boss3": 4.0 * 60.0 / 120.0,
	"boss4": 4.0 * 60.0 / 144.0,
	"boss5": 4.0 * 60.0 / 136.0,
	"boss6": 4.0 * 60.0 / 140.0,
	"boss7": 4.0 * 60.0 / 126.0,
	"boss8": 4.0 * 60.0 / 132.0,
	"mini": 4.0 * 60.0 / 150.0,
}

## Volume de la musique (dB).
var volume_db := -10.0

var _players: Array[AudioStreamPlayer] = []
var _k: Array[float] = [0.0, 0.0]  # position du fondu de chaque lecteur (0 = muet, 1 = plein)
var _dir: Array[float] = [0.0, 0.0]  # vitesse du fondu (par seconde, + entrée / - sortie)
var _names: Array[String] = ["", ""]
var _jingle: AudioStreamPlayer
var _jingle_on := false
var _jk := 1.0
var _jdir := 0.0
var _jingle_wait := ""
var _jingle_wait_t := 0.0
var _after := ""
var _after_t := -1.0

var _current := ""  # boucle voulue ("" = silence)
var _from := 0.0
var _fade := FADE
var _world := 1
var _boss := false
var _resume_pos := 0.0

var _raw := {}  # fichier (nom) -> AudioStream chargé
var _streams := {}  # piste -> AudioStream prêt à jouer (monde : AudioStreamSynchronized calme + tension)
var _pending := {}  # fichier -> chemin en cours de chargement
var _missing := {}  # fichier -> true (absent ou illisible)
var _duck := 0.0
var _last_us := 0

var _tension := 0.0  # couche de tension du monde (0 muette, 1 pleine)
var _tension_db := -80.0
var _fight := false
var _fight_hold := 0.0
var _mood_t := 0.0
var _in_shrine := false
var _shrine_resume := 0.0
var _muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus: String = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		p.bus = bus
		add_child(p)
		if i < 2:
			_players.append(p)
		else:
			_jingle = p
	_last_us = Time.get_ticks_usec()
	_request("menu")  # première musique entendue


# ===================== API =====================

func play_menu() -> void:
	_boss = false
	_in_shrine = false
	_go("menu", 0.0, FADE)


## Boucle du monde id (1..WORLDS), depuis son introduction. Précharge aussi ses gardiens et les jingles.
func play_world(id: int) -> void:
	_world = clampi(id, 1, WORLDS)
	_boss = false
	_in_shrine = false
	_resume_pos = 0.0
	_go("w%d" % _world, 0.0, FADE)
	prepare(_world)


## Précharge en arrière-plan les pistes du monde id (boucle et sa tension, gardiens, sanctuaire, jingles).
func prepare(id: int) -> void:
	var w := clampi(id, 1, WORLDS)
	for t in ["w%d" % w, "boss%d" % w, "mini", "shrine", "win", "lose"]:
		_request(String(t))


## Thème de combat : gardien du monde id, ou gardien de salle (mini = true).
func play_boss(id: int, mini := false) -> void:
	_world = clampi(id, 1, WORLDS)
	if not _boss:
		_resume_pos = _position_of("w%d" % _world)
	_boss = true
	_in_shrine = false
	_go("mini" if mini else "boss%d" % _world, 0.0, 0.6)


## Gardien vaincu : la boucle du monde reprend là où elle était (resume), sinon fondu vers le silence.
func end_boss(resume := true) -> void:
	if not _boss:
		return
	_boss = false
	if resume:
		_go("w%d" % _world, _resume_pos, 2.5)
	else:
		_go("", 0.0, 2.5)


func play_victory() -> void:
	_jingle_start("win")


func play_defeat() -> void:
	_jingle_start("lose")


## Fondu de sortie puis silence.
func stop() -> void:
	_boss = false
	_in_shrine = false
	_go("", 0.0, FADE)


## Couche de tension (combat) : forcée par l'appelant ; sinon lue sur le parent (_poll_mood).
func set_fight(on: bool) -> void:
	_fight = on
	if on:
		_fight_hold = FIGHT_HOLD


# ===================== lecture / fondus =====================

func _go(tname: String, from: float, fade: float) -> void:
	_after = ""
	_after_t = -1.0
	_jingle_wait = ""
	if _jingle_on:
		_jdir = -1.0 / 0.4
	if tname == _current:
		return
	_current = tname
	_from = from
	_fade = maxf(fade, 0.05)
	if tname == "" or _missing.has(tname) or not TRACKS.has(tname):
		_fade_all_out()
		return
	var s := _stream(tname)
	if s != null:
		_start(tname, s)
	elif _missing.has(tname):
		_fade_all_out()
	# sinon : chargement en cours, la musique actuelle continue ; _got() lancera la piste


func _fade_all_out() -> void:
	for i in 2:
		_dir[i] = -1.0 / _fade


func _start(tname: String, s: AudioStream) -> void:
	var idx := -1
	for j in 2:
		if _names[j] == tname and _players[j].playing:
			idx = j
	if idx < 0:
		# le lecteur le plus discret est réutilisé
		idx = 0 if _k[0] <= _k[1] else 1
		var p := _players[idx]
		p.stop()
		p.stream = s
		p.volume_db = -80.0
		_k[idx] = 0.0
		_names[idx] = tname
		var from := _from
		var ln := s.get_length()
		if from < 0.0:
			from = 0.0
		elif ln > 0.0 and from >= ln - 0.1:
			from = float(LOOP_START.get(tname, 0.0))
		p.play(from)
		p.stream_paused = _muted
	_dir[idx] = 1.0 / _fade
	_dir[1 - idx] = -1.0 / _fade


func _position_of(tname: String, raw := false) -> float:
	var ls: float = float(LOOP_START.get(tname, 0.0))
	for i in 2:
		if _names[i] == tname and _players[i].playing:
			var pos := _players[i].get_playback_position()
			return pos if raw else maxf(pos, ls)
	return 0.0 if raw else ls


func _is_on(tname: String) -> bool:
	for i in 2:
		if _names[i] == tname and _players[i].playing and _dir[i] >= 0.0:
			return true
	return false


func _jingle_start(tname: String) -> void:
	_boss = false
	_in_shrine = false
	_go("", 0.0, 0.5)
	_jingle_wait = tname
	_jingle_wait_t = 1.5  # attente maximale du chargement
	_after = "menu"
	_after_t = -1.0
	_try_jingle()


func _try_jingle() -> void:
	if _jingle_wait == "":
		return
	var s := _stream(_jingle_wait)
	if s != null:
		_jingle_wait = ""
		_jingle.stop()
		_jingle.stream = s
		_jk = 1.0
		_jdir = 0.0
		_jingle.volume_db = volume_db + _duck
		_jingle.play()
		_jingle.stream_paused = _muted
		_jingle_on = true
	elif _missing.has(_jingle_wait) or _jingle_wait_t <= 0.0:
		# pas de jingle : la suite arrive après un court silence
		_jingle_wait = ""
		_after_t = 1.0


func _process(_delta: float) -> void:
	# temps réel : le jeu peut être figé (Engine.time_scale = 0), la musique non
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now
	if not _pending.is_empty():
		_poll()
	_mood_t -= dt
	if _mood_t <= 0.0:
		_mood_t = MOOD_EVERY
		_poll_mood()
	_fight_hold -= dt
	_update_tension(dt)
	var duck_to: float = DUCK_DB if Engine.time_scale < 0.01 else 0.0
	_duck = move_toward(_duck, duck_to, dt * 10.0)
	for i in 2:
		var p := _players[i]
		if not p.playing:
			continue
		_k[i] = clampf(_k[i] + _dir[i] * dt, 0.0, 1.0)
		if _k[i] <= 0.0 and _dir[i] < 0.0:
			p.stop()
			_names[i] = ""
			continue
		p.volume_db = volume_db + _duck + linear_to_db(maxf(sin(_k[i] * PI * 0.5), 0.0001))
	# jingle
	if _jingle_wait != "":
		_jingle_wait_t -= dt
		_try_jingle()
	if _jingle_on:
		if not _jingle.playing:
			_jingle_on = false
			if _after != "":
				_after_t = 0.6
		else:
			_jk = clampf(_jk + _jdir * dt, 0.0, 1.0)
			if _jk <= 0.0:
				_jingle.stop()
			else:
				_jingle.volume_db = volume_db + _duck + linear_to_db(maxf(sin(_jk * PI * 0.5), 0.0001))
	if _after_t >= 0.0:
		_after_t -= dt
		if _after_t < 0.0 and _after != "":
			var nxt := _after
			_go(nxt, 0.0, 3.0)


# ===================== humeur (combat, sanctuaire) =====================

## Lue sur le parent (main.gd), sans rien lui demander : combat = un ennemi vivant en jeu ; sanctuaire = sanctuaire
## de départ, écran des pactes ou échoppe du marchand ouverte. Son coupé : lecture suspendue.
func _poll_mood() -> void:
	var muted := AudioServer.is_bus_mute(0)
	if muted != _muted:
		_muted = muted
		for p in _players:
			p.stream_paused = muted
		_jingle.stream_paused = muted
	var m := get_parent()
	if m == null:
		return
	var st: Variant = m.get("state")
	if not st is String:
		return
	var s := String(st)
	var fight := false
	if s in ["play", "tuto", "boss_intro", "paused"]:
		var en: Variant = m.get("enemies")
		if en is Array:
			for e in en:
				if is_instance_valid(e) and e.get("dead") != true and e.get("dummy") != true:
					fight = true
					break
	if fight:
		_fight_hold = FIGHT_HOLD
	_fight = fight
	var shrine := false
	var sh: Variant = m.get("shop")
	var pm: Variant = m.get("_pick_mode")
	if sh is Control and (sh as Control).visible:
		shrine = true
	elif s == "pick" and pm is String and pm == "curse":
		shrine = true
	elif s == "play" and m.get("in_hub") == true and not fight:
		shrine = true
	_set_shrine(shrine)


func _set_shrine(on: bool) -> void:
	if on == _in_shrine or _boss:
		return
	var wt := "w%d" % _world
	if on:
		if _current != wt:
			return
		_in_shrine = true
		_shrine_resume = _position_of(wt, true)
		_go("shrine", 0.0, 1.5)
	else:
		_in_shrine = false
		if _current == "shrine":
			_go(wt, _shrine_resume, 2.0)


func _update_tension(dt: float) -> void:
	var want := 1.0 if (_fight or _fight_hold > 0.0) and not _in_shrine else 0.0
	if want > _tension:
		_tension = minf(want, _tension + dt / LAYER_IN)
	elif want < _tension:
		_tension = maxf(want, _tension - dt / LAYER_OUT)
	var db := linear_to_db(maxf(sin(_tension * PI * 0.5), 0.0001))
	if absf(db - _tension_db) < 0.05:
		return
	_tension_db = db
	for t in _streams.keys():
		var sy := _streams[t] as AudioStreamSynchronized
		if sy != null:
			sy.set_sync_stream_volume(1, db)


# ===================== chargement =====================

func _stream(tname: String) -> AudioStream:
	if _streams.has(tname):
		return _streams[tname]
	_request(tname)
	if _streams.has(tname):
		return _streams[tname]
	return null


func _layered(tname: String) -> bool:
	return tname.begins_with("w") and LOOP_START.has(tname)


func _request(tname: String) -> void:
	if not TRACKS.has(tname):
		_missing[tname] = true
		return
	_request_file(tname)
	if _layered(tname):
		_request_file(tname + LAYER_SUFFIX)


func _request_file(fname: String) -> void:
	if _raw.has(fname) or _pending.has(fname) or _missing.has(fname):
		return
	var path := DIR + fname + ".ogg"
	if not ResourceLoader.exists(path):
		_got(fname, null)
		return
	var err := ResourceLoader.load_threaded_request(path)
	if err == OK:
		_pending[fname] = path
	else:
		_got(fname, load(path) as AudioStream)


func _poll() -> void:
	for t in _pending.keys():
		var fname := String(t)
		var path: String = _pending[t]
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_pending.erase(t)
		var res: Resource = null
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			res = ResourceLoader.load_threaded_get(path)
		_got(fname, res as AudioStream)


func _got(fname: String, s: AudioStream) -> void:
	var tname := fname.trim_suffix(LAYER_SUFFIX)
	if s == null:
		_missing[fname] = true
	else:
		var ogg := s as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = bool(TRACKS.get(tname, true))
			ogg.loop_offset = float(LOOP_START.get(tname, 0.0))
		_raw[fname] = s
	_assemble(tname)


## Piste prête quand ses fichiers sont là : un monde superpose sa couche de tension (si elle existe).
func _assemble(tname: String) -> void:
	if _streams.has(tname):
		return
	if _missing.has(tname):
		if tname == _current:
			_fade_all_out()
		return
	if not _raw.has(tname):
		return
	var s: AudioStream = _raw[tname]
	if _layered(tname):
		var tn := tname + LAYER_SUFFIX
		if _pending.has(tn):
			return  # la couche de tension arrive
		if _raw.has(tn):
			var sy := AudioStreamSynchronized.new()
			sy.stream_count = 2
			sy.set_sync_stream(0, s)
			sy.set_sync_stream(1, _raw[tn])
			sy.set_sync_stream_volume(0, 0.0)
			sy.set_sync_stream_volume(1, _tension_db)
			s = sy
	_streams[tname] = s
	if tname == _current and not _is_on(tname):
		_start(tname, s)
