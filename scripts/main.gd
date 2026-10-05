extends Node3D
## Boucle de jeu : on trace, on lâche = ruée qui tranche. 15 salles par monde, vagues d'ennemis, boss au bout.

const Toon = preload("res://scripts/toon.gd")
const Hero = preload("res://scripts/hero.gd")
const Enemy = preload("res://scripts/enemy.gd")
const InkStroke = preload("res://scripts/ink_stroke.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Hud = preload("res://scripts/hud.gd")
const Menu = preload("res://scripts/menu.gd")
const Powers = preload("res://scripts/powers.gd")
const Picker = preload("res://scripts/picker.gd")
const Boss = preload("res://scripts/boss.gd")
const BOSS_SCRIPTS := {"kyubi": preload("res://scripts/boss_kyubi.gd"), "gashadokuro": preload("res://scripts/boss_gasha.gd"),
	"daidara": preload("res://scripts/boss_daidara.gd"), "kuronami": preload("res://scripts/boss_kuronami.gd")}
const WORLD_BOSS := {1: "uwabami", 2: "kyubi", 3: "gashadokuro", 4: "daidara", 5: "kuronami"}
const Vfx = preload("res://scripts/vfx.gd")
const Options = preload("res://scripts/options.gd")
const Pickups = preload("res://scripts/pickups.gd")
const KIND_XP := {"oni": 1, "kappa": 2, "tate": 2, "funa": 2, "brute": 3}
const Tutorial = preload("res://scripts/tutorial.gd")
const Music = preload("res://scripts/music_player.gd")
const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
const Hazards = preload("res://scripts/hazards.gd")
const Arena = preload("res://scripts/arena.gd")
const Worlds = preload("res://scripts/worlds.gd")
const WorldMap = preload("res://scripts/worldmap.gd")
const Meta = preload("res://scripts/meta.gd")
const Refuge = preload("res://scripts/refuge.gd")
# malédictions du sanctuaire (après les salles de SANCTUARIES) : un malus pour toute la partie, une récompense tout de suite
const CURSES := {
	"dry": {"name": "Encre sèche", "text": "Trait -30 %  ·  2 rouleaux en plus"},
	"oni_eye": {"name": "Œil d'oni", "text": "Ennemis +50 % de vie  ·  2 rouleaux en plus"},
	"heavy": {"name": "Pas lourd", "text": "Plus de pas de côté  ·  +2 vies max, soin"},
	"haste": {"name": "Hâte des morts", "text": "Ennemis +25 % vitesse  ·  1 rouleau, soin"},
}
const KANJI_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const SHAPE_KANJI := {"loop": "渦", "zigzag": "雷", "return": "返", "straight": "一", "enso": "円", "hook": "鉤"}
const ROOMS := 15
const MINI_ROOM := 8  # salle du mini-boss
const SANCTUARIES := [5, 10]  # malédictions proposées après ces salles
const KIND_COST := {"oni": 1, "kappa": 2, "brute": 3, "tate": 3, "funa": 2}
const KIND_ROOM := {"oni": 1, "kappa": 2, "brute": 3, "tate": 3, "funa": 4}  # première salle où chaque ennemi peut venir
const UNLOCK_ALL := true  # prototype : tous les mondes ouverts pour les tester
const SAVE_PATH := "user://ippitsu.cfg"

const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (x, z)
const IN_PLAY_STATES := ["play", "transit", "dying", "pick", "tuto"]

const ELAN_MAX := 14.0  # longueur de trait maximale
const ELAN_REGEN := 9.0  # par seconde réelle, hors tracé
const ELAN_PER_HIT := 3.5
const DODGE_COST := 0.6
const DODGE_DIST := 2.4
const HIT_REACH := 0.55

var cam: Camera3D
var hero: Node3D
var sfx: Node
var hud: Control
var world: Node3D

var enemies: Array = []
var bullets: Array = []
var effects: Array = []

var elan := 14.0
var touching := false
var touch_start := Vector3.ZERO
var stroke: MeshInstance3D
var dash_stroke: MeshInstance3D
var stroke_layer := 0
var stroke_id := 0
var combo := 0
var origin := Vector3.ZERO
var _prev_hero := Vector3.ZERO

var shake := 0.0
var wave_wait := 1.0
var safety_left := 1  # pas de côté automatiques restants dans la salle
const ATTACK_TOKENS := 2  # ennemis autorisés à préparer une attaque en même temps
var _attackers: Array = []
var game_over := false
var _ticks := 0
var _cam_base := Transform3D()

var state := "menu"  # menu | worlds | intro | play | pick | transit | paused | dying | over | tuto
var menu: Control
var record := 0
var _state_t := 0.0
var _menu_slash := 3.0
var _env: Environment
var _light_mode := false  # rendu allégé (téléphone)
var _fx_cache := {}  # maillages et matières d'effets réutilisés
var _sun: DirectionalLight3D
var arena: Node3D
var current_world := 1

var powers: Node
var picker: Control
var room := 0
var _room_queue: Array = []
var _stroke_kills := 0
var bosses: Array = []
var hazards: Node3D
var meta: RefCounted
var refuge: Control
var mini_kills := 0
var curses: Array = []
var _pick_mode := "upgrade"
var _extra_picks := 0
var _safe_point := Vector3.ZERO
var kills := 0
var boss_kills := 0
var _waves_left: Array = []
var waves_total := 1
var wave_index := 1
var _room_done := false
var _rebuilt := false
var worldmap: Control
var _ending_victory := false
var _final_boss: Node3D
var music: Node
var tuto: Control
var vfx: Node3D
var options: Control
var ctrl_mode := "pad"  # pad | screen
var pad_size := "m"  # s | m | l
var pad_show := "start"  # always | start | never
var _strokes_done := 0
var _options_from := "menu"
var pickups: Node3D
# expérience et or ramassés au sol : la barre pleine fait monter de niveau (un rouleau à choisir)
var xp := 0
var level := 1
var run_gold := 0
var _pending_levels := 0
var _pick_context := "room"  # room | level
var foam := 0  # coups bloqués restants dans la salle (Écume)
var _auto_step := false  # pas de côté automatique en cours (ne compte pas comme un trait)
var run_time := 0.0
var _spin_tick := 0.0
# chaîne : ruées réussies d'affilée sans prendre de coup (bonus de dégâts)
const CHAIN_TIMEOUT := 6.0
const CHAIN_TIERS := {5: "FLUIDE", 10: "TRANCHANT", 20: "MAÎTRE"}
var chain := 0
var max_chain := 0
var _chain_t := 0.0
var _stroke_hit := false
var _iai_t := 0.0
var _iai_points := PackedVector3Array()
var _enso_center := Vector3.ZERO
var _enso_r := 2.0
var _pad_start := Vector2.ZERO
var _shape: Dictionary = {}  # forme reconnue du trait en cours de ruée


func _ready() -> void:
	randomize()
	_build_world()
	sfx = Sfx.new()
	add_child(sfx)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	var top := CanvasLayer.new()
	top.layer = 2
	add_child(top)
	menu = Menu.new()
	top.add_child(menu)
	menu.play_pressed.connect(_on_play)
	menu.home_pressed.connect(_on_home)
	menu.sound_toggled.connect(_on_sound)
	meta = Meta.new()
	meta.load_data()
	var ref_layer := CanvasLayer.new()
	ref_layer.layer = 4
	add_child(ref_layer)
	refuge = Refuge.new()
	refuge.meta = meta
	ref_layer.add_child(refuge)
	refuge.closed.connect(_on_refuge_closed)
	menu.atelier_pressed.connect(_on_atelier)
	menu.worlds_pressed.connect(_open_worlds)
	menu.resume_pressed.connect(_on_resume)
	menu.restart_pressed.connect(_on_restart)
	hud.pause_pressed.connect(_on_pause)
	pickups = Pickups.new()
	pickups.main = self
	add_child(pickups)
	vfx = Vfx.new()
	vfx.main = self
	add_child(vfx)
	music = Music.new()
	add_child(music)
	hazards = Hazards.new()
	hazards.main = self
	add_child(hazards)
	powers = Powers.new()
	powers.main = self
	add_child(powers)
	var pick_layer := CanvasLayer.new()
	pick_layer.layer = 3
	add_child(pick_layer)
	picker = Picker.new()
	pick_layer.add_child(picker)
	picker.picked.connect(_on_picked)
	picker.reroll.connect(_on_reroll)
	var opt_layer := CanvasLayer.new()
	opt_layer.layer = 5
	add_child(opt_layer)
	options = Options.new()
	opt_layer.add_child(options)
	options.changed.connect(_on_option)
	options.closed.connect(_on_options_closed)
	menu.options_pressed.connect(_open_options)
	tuto = Tutorial.new()
	tuto.main = self
	pick_layer.add_child(tuto)
	tuto.finished.connect(_on_tuto_finished)
	menu.tuto_pressed.connect(_start_tutorial)
	var map_layer := CanvasLayer.new()
	map_layer.layer = 4
	add_child(map_layer)
	worldmap = WorldMap.new()
	map_layer.add_child(worldmap)
	worldmap.world_chosen.connect(_on_world_chosen)
	worldmap.closed.connect(_on_worldmap_closed)
	_load()
	get_viewport().size_changed.connect(_fit_camera)
	# `?world=N` (web) : ouvre directement le monde N
	var wsearch := str(JavaScriptBridge.eval("location.search", true)) if OS.has_feature("web") else ""
	var wpos := wsearch.find("world=")
	hud.show_fps = "fps" in wsearch
	apply_world(clampi(int(wsearch.substr(wpos + 6).get_slice("&", 0)), 1, 5) if wpos >= 0 else 1)
	_start()
	# `-- --autoplay` : démarre directement en jeu (vérification automatique du CI)
	var autoplay := "--autoplay" in OS.get_cmdline_user_args()
	if autoplay:
		var fails: Array = StrokeShapes.self_test()
		if not fails.is_empty():
			print("SCRIPT ERROR: formes de trait : ", fails)
	autoplay = autoplay or "autoplay" in wsearch
	# `?room=N` (web) : commence directement à la salle N (tests des boss : 8 et 15)
	var rm := wsearch.find("room=")
	if rm >= 0:
		room = clampi(int(wsearch.substr(rm + 5).get_slice("&", 0)), 1, ROOMS) - 1
		arena.build_room(room + 1, ROOMS, randi(), MINI_ROOM)
		hero.position = arena.start
		_prev_hero = hero.position
		_set_state("play")
		music.play_world(current_world)
		_begin_room()
	else:
		_set_state("play" if autoplay else "menu")
	# `?pick` (web) : ouvre directement le choix de rouleau, pour vérifier l'écran
	if "pick" in wsearch:
		_pick_context = "room"
		_set_state("pick")
		_open_upgrades()
	if "atelier" in wsearch:
		_on_atelier()
	if "tuto" in wsearch:
		_start_tutorial()
	if "pause" in wsearch:
		_set_state("play")
		_on_pause()
	_warmup()
	_ticks = Time.get_ticks_usec()


## Préchauffage : on affiche une fois, cachés sous le sol, un exemplaire de chaque ennemi et de chaque
## effet. Godot prépare ainsi leurs shaders pendant l'accueil au lieu de figer l'image en pleine partie.
func _warmup() -> void:
	var w := Node3D.new()
	add_child(w)
	# dans le champ de la caméra d'accueil mais sous le sol : rendus (donc compilés) sans être vus
	w.position = hero.position + Vector3(0, -0.7, -3.0)
	var x := -3.0
	for k in ["oni", "kappa", "brute", "tate", "funa"]:
		var e := Enemy.new()
		e.setup(String(k), hero, self)
		e.position = Vector3(x, 0, 0)
		w.add_child(e)
		e.process_mode = Node.PROCESS_MODE_DISABLED
		x += 1.5
	var b := Node3D.new()
	w.add_child(b)
	Toon.part(b, Toon.sphere(0.3), Toon.mat(Toon.VERMILION, true, 0.05), Vector3.ZERO)
	var st := InkStroke.new(Vector3.ZERO, 0)
	w.add_child(st)
	st.extend_to(Vector3(2, 0, 0), 3.0)
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = "0123456789.× 渦雷返一円鉤"
	l.font_size = 120  # mêmes tailles que les textes de combat : glyphes prêts d'avance
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	w.add_child(l)
	var l2 := l.duplicate() as Label3D
	l2.font_size = 110
	w.add_child(l2)
	_splash(w.position, Toon.VERMILION, 8)
	_blot(w.position, Toon.SUMI, 0.3, 0.5)
	_slash_mark(w.position, Vector3.FORWARD)
	vfx.impact(w.position, Vector3.FORWARD, true)
	vfx.kill_burst(w.position, Vector3.FORWARD, true)
	get_tree().create_timer(1.2).timeout.connect(w.queue_free)


# ------------------------------------------------------------------ états

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		record = int(cfg.get_value("game", "best", 0))
		menu.muted = bool(cfg.get_value("game", "muted", false))
		ctrl_mode = String(cfg.get_value("settings", "control", "pad"))
		pad_size = String(cfg.get_value("settings", "pad_size", "m"))
		pad_show = String(cfg.get_value("settings", "pad_show", "start"))
	menu.best = record
	menu.sumi = meta.sumi
	AudioServer.set_bus_mute(0, menu.muted)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", record)
	cfg.set_value("game", "muted", menu.muted)
	cfg.set_value("settings", "control", ctrl_mode)
	cfg.set_value("settings", "pad_size", pad_size)
	cfg.set_value("settings", "pad_show", pad_show)
	cfg.save(SAVE_PATH)


func _set_state(s: String) -> void:
	state = s
	_state_t = 0.0
	hud.visible = s != "menu" and s != "worlds"
	match s:
		"menu":
			menu.show_mode("home")
			music.play_menu()
			hero.face(Vector3(0, 0, 1))
			hero.snap_facing()
		"intro":
			menu.show_mode("hidden")
			music.play_world(current_world)
			hero.face(Vector3(0, 0, -1))
		"play":
			menu.show_mode("hidden")
			if room == 0:
				music.play_world(current_world)
				var wd: Dictionary = Worlds.world(current_world)
				hud.banner(String(wd.name).to_upper(), "SALLE 1  ·  TRACE POUR FRAPPER", wd.color, 2.4)
		"over":
			menu.show_mode("over")
		"worlds":
			menu.show_mode("hidden")


func _on_play() -> void:
	sfx.play("slash", 0.8, -4.0)
	if state == "over":
		_start()
		_set_state("play")
	elif not meta.tuto_done:
		# toute première partie : on apprend d'abord à tracer
		_start_tutorial()
	else:
		_open_worlds()


func _open_worlds() -> void:
	# choix du monde sur le rouleau
	_set_state("worlds")
	var unlocked: int = 5 if UNLOCK_ALL else int(meta.unlocked)
	worldmap.open(Worlds.WORLDS, unlocked, meta.world_best, current_world, ROOMS)


func _on_world_chosen(id: int) -> void:
	sfx.play("slash", 0.9, -4.0)
	if id != current_world:
		apply_world(id)
	_start()
	_set_state("intro")


func _on_pause() -> void:
	if state != "play":
		return
	_cancel_stroke()
	var w: Dictionary = Worlds.world(current_world)
	menu.world_kanji = String(w.kanji)
	menu.world_color = w.color
	menu.stat_room = maxi(room, 1)
	menu.stat_combo = chain
	menu.stat_time = run_time
	hud.pause_enabled = false
	state = "paused"
	menu.show_mode("pause")


## Téléphone : bouton Retour ou appli mise en arrière-plan -> pause (au lieu de quitter en pleine partie).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if menu == null or hud == null:
			return
		if what == NOTIFICATION_WM_GO_BACK_REQUEST and state == "menu":
			get_tree().quit()  # Retour depuis l'accueil : on quitte, comme toute appli
		else:
			_on_pause()


## Tutoriel guidé : arène calme, mannequins, héros intouchable, élan illimité.
func _start_tutorial() -> void:
	sfx.play("slash", 0.9, -4.0)
	menu.show_mode("hidden")
	_start()
	_set_state("tuto")
	hero.face(Vector3(0, 0, -1))
	hero.guard_t = 99999.0
	hud.banner("TUTORIEL", "APPRENDS À TRACER", Toon.PRUSSIAN, 1.8)
	tuto.begin()


func _on_tuto_finished() -> void:
	meta.tuto_done = true
	meta.save_data()
	_start()
	_set_state("menu")


## Mannequin d'entraînement (tutoriel) : ne bouge pas, n'attaque pas.
func spawn_dummy(pos: Vector3) -> void:
	var e := Enemy.new()
	e.setup("oni", hero, self)
	e.dummy = true
	e.position = arena.clamp_walk(pos, 0.8)
	add_child(e)
	e.set_meta("max_hp", e.hp)
	enemies.append(e)


func _on_restart() -> void:
	sfx.play("slash", 0.8, -4.0)
	_start()
	_set_state("play")


func _on_resume() -> void:
	menu.show_mode("hidden")
	state = "play"


func _on_worldmap_closed() -> void:
	_set_state("menu")


func _on_atelier() -> void:
	sfx.play("whoosh", 0.8)
	menu.show_mode("hidden")
	refuge.open()


func _on_refuge_closed() -> void:
	menu.sumi = meta.sumi
	_start()
	_set_state("menu")


func _on_home() -> void:
	_start()
	_set_state("menu")


func _open_options() -> void:
	_options_from = "pause" if state == "paused" else "menu"
	options.values = {"control": ctrl_mode, "pad_size": pad_size, "pad_show": pad_show, "sound": "off" if menu.muted else "on"}
	menu.show_mode("hidden")
	options.open()


func _on_option(key: String, value: String) -> void:
	match key:
		"control":
			ctrl_mode = value
		"pad_size":
			pad_size = value
		"pad_show":
			pad_show = value
		"sound":
			menu.muted = value == "off"
			AudioServer.set_bus_mute(0, menu.muted)
	sfx.play("empty", 1.4, -6.0)
	_save()


func _on_options_closed() -> void:
	menu.show_mode("pause" if _options_from == "pause" else "home")


func _on_sound(muted: bool) -> void:
	AudioServer.set_bus_mute(0, muted)
	_save()


func _menu_transform() -> Transform3D:
	var hp := hero.position
	var pos := hp + Vector3(0.35, 1.45, 3.4)
	return Transform3D(Basis(), pos).looking_at(hp + Vector3(0.0, 2.0, -2.0), Vector3.UP)


# ------------------------------------------------------------------ décor

func _build_world() -> void:
	world = Node3D.new()
	add_child(world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Toon.WASHI
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.86, 0.9, 1.0)
	e.ambient_light_energy = 0.3
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# couleurs plus franches : un peu plus de saturation et de contraste
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	e.adjustment_contrast = 1.12
	e.adjustment_brightness = 0.97
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_strength = 1.1
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# brume d'estampe : le lointain (Fuji, îlots) se fond dans le papier
	e.fog_enabled = true
	e.fog_light_color = Toon.WASHI
	e.fog_density = 0.0028
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)

	# soleil chaud et rasant qui projette de vraies ombres
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-38), 0)
	sun.light_energy = 0.72
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.shadow_opacity = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	var light := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if light:
		# téléphone : chaque lumière refait un passage sur chaque objet -> une seule, ombres plus proches,
		# 3D rendue un peu en dessous de la résolution native (l'interface reste nette)
		sun.directional_shadow_max_distance = 26.0
		_light_mode = true
		get_viewport().scaling_3d_scale = 0.8
	else:
		# contre-jour froid, sans ombre, pour détacher les silhouettes
		var fill := DirectionalLight3D.new()
		fill.rotation = Vector3(deg_to_rad(-25), deg_to_rad(150), 0)
		fill.light_energy = 0.22
		fill.light_color = Color(0.7, 0.8, 1.0)
		add_child(fill)

	cam = Camera3D.new()
	cam.fov = 38.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	cam.current = true

	_env = e
	_sun = sun
	# la salle (sol, décor, torii de sortie) et le monde (vide, lointain, particules)
	arena = Arena.new()
	world.add_child(arena)


## Applique l'ambiance d'un monde : ciel, brume, lumière, puis le décor lointain.
func apply_world(id: int) -> void:
	current_world = id
	var w: Dictionary = Worlds.world(id)
	_env.background_color = w.sky
	_env.fog_light_color = w.fog
	_env.fog_density = float(w.fog_density)
	_env.ambient_light_color = w.ambient_color
	# sans contre-jour (téléphone), un peu plus de lumière ambiante compense
	_env.ambient_light_energy = float(w.ambient_energy) * (1.35 if _light_mode else 1.0)
	_sun.light_color = w.sun_color
	_sun.light_energy = float(w.sun_energy)
	arena.set_world(id)


func _fit_camera() -> void:
	# cherche la caméra la plus proche qui montre toute l'arène, quelle que soit la taille d'écran
	var vs := get_viewport().get_visible_rect().size
	if vs.x <= 0 or vs.y <= 0:
		return
	var tilt := deg_to_rad(54.0)
	var corners := [Vector3(-HALF.x - 0.6, 0, -HALF.y - 0.6), Vector3(HALF.x + 0.6, 0, -HALF.y - 0.6),
		Vector3(-HALF.x - 0.6, 0, HALF.y + 0.6), Vector3(HALF.x + 0.6, 0, HALF.y + 0.6),
		Vector3(0, 3.4, -HALF.y - 0.7)]
	var top := vs.y * 0.085
	var bottom := vs.y * 0.68  # sous l'arène : le pad tactile
	var best := Transform3D()
	var found := false
	var dist := 12.0
	while dist < 70.0 and not found:
		# à cette distance, garde le cadrage qui centre l'arène verticalement
		var best_gap := INF
		for zi in 41:
			var zc := -4.0 + zi * 0.2
			var focus := Vector3(0, 0, zc)
			var pos := focus + Vector3(0, sin(tilt), cos(tilt)) * dist
			var tr := Transform3D(Basis(), pos).looking_at(focus, Vector3.UP)
			cam.global_transform = tr
			var ok := true
			var min_y := INF
			var max_y := -INF
			for c in corners:
				var p := cam.unproject_position(c)
				min_y = minf(min_y, p.y)
				max_y = maxf(max_y, p.y)
				if p.x < vs.x * 0.01 or p.x > vs.x * 0.99 or p.y < top or p.y > bottom:
					ok = false
					break
			if ok:
				var gap := absf((min_y - top) - (bottom - max_y))
				if gap < best_gap:
					best_gap = gap
					best = tr
				found = true
		dist += 0.25
	if not found:
		best = Transform3D(Basis(), Vector3(0, 30, 18)).looking_at(Vector3.ZERO, Vector3.UP)
	_cam_base = best
	cam.global_transform = best


# ------------------------------------------------------------------ partie

func _start() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	_attackers.clear()
	for bo in bosses:
		if is_instance_valid(bo):
			bo.queue_free()
	bosses.clear()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	if hero:
		hero.queue_free()
	arena.build_room(1, ROOMS, randi(), MINI_ROOM)
	hero = Hero.new()
	add_child(hero)
	hero.position = arena.start
	hero.dash_finished.connect(_on_dash_finished)
	hero.landed.connect(_on_hero_landed)
	_prev_hero = hero.position
	_cancel_stroke()
	if is_instance_valid(dash_stroke):
		dash_stroke.queue_free()
	dash_stroke = null
	_reset_stroke_state(true)
	_pick_context = "room"
	foam = 0
	wave_wait = 0.8
	room = 0
	_room_queue = []
	_waves_left = []
	_room_done = false
	powers.reset()
	hazards.clear()
	curses.clear()
	elan = elan_max()  # après la remise à zéro des pouvoirs et malédictions
	_extra_picks = 0
	picker.rerolls = meta.rerolls()
	kills = 0
	boss_kills = 0
	mini_kills = 0
	run_time = 0.0
	xp = 0
	level = 1
	run_gold = 0
	_pending_levels = 0
	pickups.clear()
	chain = 0
	max_chain = 0
	_chain_t = 0.0
	hud.dying = 0.0
	hero.max_hp = 5 + meta.hp_bonus()
	hero.hp = hero.max_hp
	game_over = false
	touching = false
	hud.game_over = false
	hud.over_t = 0.0
	shake = 0.0
	Engine.time_scale = 1.0
	_fit_camera()


func elan_max() -> float:
	return (ELAN_MAX + powers.elan_bonus() + meta.elan_bonus()) * (0.7 if "dry" in curses else 1.0)


## Salle suivante : 3 vagues d'ennemis à tuer, tirées selon le monde, budget croissant.
func _begin_room() -> void:
	room += 1
	_room_done = false
	foam = powers.foam_per_room()
	safety_left = 0 if "heavy" in curses else meta.safety_per_room()
	hazards.begin_room(room, hero.position, room == MINI_ROOM or room == ROOMS)
	var w: Dictionary = Worlds.world(current_world)
	var weights: Dictionary = w.enemies
	var budget := 5 + 2 * room
	var list: Array = []
	if room >= 3:
		list.append("brute")
		budget -= 3
	var guard := 0
	while budget > 0 and guard < 100:
		guard += 1
		var k := _weighted_kind(weights)
		var cost := int(KIND_COST.get(k, 1))
		if room < int(KIND_ROOM.get(k, 1)) or cost > budget:
			k = "oni"
			cost = 1
		list.append(k)
		budget -= cost
	list.shuffle()
	if room == MINI_ROOM:
		list = ["oni", "oni", "oni"]
		_spawn_boss("okappa")
	elif room == ROOMS:
		list = []
		_final_boss = _spawn_boss(String(WORLD_BOSS.get(current_world, "uwabami")))
	# découpe en vagues : 40 % / 35 % / 25 %
	_waves_left = []
	var n := list.size()
	var a := int(ceil(n * 0.4))
	var b := int(ceil(n * 0.75))
	var first: Array = list.slice(0, a)
	if b > a:
		_waves_left.append(list.slice(a, b))
	if n > b:
		_waves_left.append(list.slice(b))
	waves_total = 1 + _waves_left.size()
	wave_index = 1
	if room == MINI_ROOM:
		hud.banner("Ō-KAPPA", "GARDIEN DE LA SALLE %d" % MINI_ROOM, Toon.VERMILION, 2.2)
	elif room == ROOMS and _final_boss != null:
		hud.banner(String(_final_boss.title).to_upper(), "GARDIEN DU MONDE", Toon.VERMILION, 2.4)
	elif room > 1:
		hud.toast("SALLE %d" % room)
	_spawn_list(first)
	sfx.play("strike", 0.7, -2.0)


func _weighted_kind(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights.keys():
		total += float(weights[k])
	var r := randf() * total
	for k in weights.keys():
		r -= float(weights[k])
		if r <= 0.0:
			return String(k)
	return "oni"

func _spawn_boss(k: String) -> Node3D:
	var b: Node3D = BOSS_SCRIPTS[k].new() if BOSS_SCRIPTS.has(k) else Boss.new()
	b.setup(k, self)
	if k == "okappa":
		b.position = Vector3(0, 0, -HALF.y + 3.0)
	b.max_hp_mult = float(Worlds.world(current_world).hp_mult)
	add_child(b)
	bosses.append(b)
	sfx.play("strike", 0.5)
	shake = 0.4
	return b


func spawn_minions(list: Array) -> void:
	_spawn_list(list)


func boss_killed(b: Node3D) -> void:
	pickups.drop(b.position, "xp", 8)
	pickups.drop(b.position, "coin", 10)
	if b.kind == "okappa":
		mini_kills += 1
		_pending_levels += 1  # le gardien vaincu offre un rouleau
	else:
		boss_kills += 1
	shake = 0.7
	sfx.play("kill", 0.6)
	_splash(b.position, Toon.VERMILION, 30)
	_splash(b.position, Toon.GOLD, 20)


func small_hit(pos: Vector3) -> void:
	_splash(pos, Toon.VERMILION, 4)
	sfx.play("slash", randf_range(1.2, 1.5), -8.0)


func big_hit(pos: Vector3) -> void:
	shake = maxf(shake, 0.35)
	sfx.play("kill", 0.9)
	_splash(pos, Toon.VERMILION, 24)
	_blot(pos, Toon.VERMILION, 0.9, 2.5)


func clang(pos: Vector3) -> void:
	shake = maxf(shake, 0.15)
	sfx.play("empty", 0.5)
	_splash(pos, Toon.FOAM, 10)


func splash(pos: Vector3, color: Color, amount: int) -> void:
	_splash(pos, color, amount)


func _spawn_list(list: Array) -> void:
	for k in list:
		var e := Enemy.new()
		e.setup(String(k), hero, self)
		var p := Vector3.ZERO
		for attempt in 30:
			p = arena.random_point(hero.position, 4.5)
			if not hazards.is_hole(p, -0.8):
				break
		e.position = p
		add_child(e)
		if "oni_eye" in curses:
			e.hp *= 1.5
		if "haste" in curses:
			e.speed *= 1.25
		e.hp *= float(Worlds.world(current_world).hp_mult)
		e.set_meta("max_hp", e.hp)
		enemies.append(e)


func xp_need() -> int:
	# courbe plus raide : ~1 niveau par salle au début, puis de plus en plus espacé
	return 8 + 5 * level + level * level


## Butin ramassé (appelé par pickups.gd).
func collect(kind: String, value: int) -> void:
	if kind == "xp":
		xp += value
		sfx.play("shot", 1.8 + randf() * 0.2, -14.0)
		while xp >= xp_need():
			xp -= xp_need()
			level += 1
			_pending_levels += 1
	else:
		run_gold += value
		sfx.play("empty", 2.0, -10.0)


## Un ennemi tombe : il lâche de l'expérience et parfois de l'or.
func _on_enemy_killed(e: Node3D) -> void:
	var k := String(e.kind)
	pickups.drop(e.position, "xp", int(KIND_XP.get(k, 1)))
	if randf() < (0.8 if k == "brute" else 0.4):
		pickups.drop(e.position, "coin", 2 if k == "brute" else 1)


func _room_cleared() -> void:
	_cancel_stroke()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	pickups.gather()
	if room >= ROOMS:
		_victory()
		return
	if room in SANCTUARIES:
		_pick_context = "room"
		_set_state("pick")
		_open_sanctuary()
	else:
		_open_gate()


func _open_gate() -> void:
	elan = elan_max()
	_set_state("play")
	arena.open_gate()
	sfx.play("shot", 1.4, -4.0)


func _open_upgrades() -> void:
	_pick_mode = "upgrade"
	var ids: Array = powers.offer()
	var infos: Array = []
	for id in ids:
		infos.append(powers.describe(id))
	picker.open(ids, infos)
	sfx.play("shot", 0.6)


func _open_sanctuary() -> void:
	_pick_mode = "curse"
	var pool: Array = []
	for id in CURSES.keys():
		if not id in curses:
			pool.append(id)
	pool.shuffle()
	var ids: Array = pool.slice(0, 2)
	var infos: Array = []
	for id in ids:
		infos.append({"name": CURSES[id].name, "text": CURSES[id].text, "level": -1, "kanji": "鬼", "color": Color("#7A1F1A")})
	ids.append("refuse")
	infos.append({"name": "Passer", "text": "Continuer sans malédiction", "level": -1, "kanji": "道", "color": Color("#8C8FA8")})
	picker.open(ids, infos)
	sfx.play("hurt", 0.6, -6.0)


func _on_reroll() -> void:
	sfx.play("whoosh", 1.2, -4.0)
	if _pick_mode == "curse":
		_open_sanctuary()
	else:
		_open_upgrades()


func _on_picked(id: String) -> void:
	if _pick_mode == "curse":
		if id != "refuse":
			_take_curse(id)
		if _extra_picks > 0:
			_extra_picks -= 1
			_open_upgrades()
		else:
			_open_gate()
		return
	powers.add(id)
	sfx.play("slash", 1.2, -4.0)
	if _extra_picks > 0:
		_extra_picks -= 1
		_open_upgrades()
		return
	if _pick_context == "level":
		_set_state("play")
	else:
		_open_gate()


## Passage du torii : un coup de pinceau couvre l'écran, la salle suivante apparaît derrière.
func _transit() -> void:
	_set_state("transit")
	_rebuilt = false
	_cancel_stroke()
	_reset_stroke_state(true)  # pas de technique (ensō, iai…) qui déborde sur la salle suivante
	hero.stop_dash()
	sfx.play("whoosh", 0.6)


func _rebuild_room() -> void:
	_rebuilt = true
	for e in effects:
		if is_instance_valid(e.node):
			e.node.queue_free()
	effects.clear()
	arena.build_room(room + 1, ROOMS, randi(), MINI_ROOM)
	hero.cancel_moves()
	hero.position = arena.start
	_prev_hero = hero.position
	hero.face(Vector3(0, 0, -1))
	hero.snap_facing()
	_begin_room()


func _award(victory: bool) -> void:
	var cleared := room if victory else room - 1
	var g: Dictionary = meta.award_run(cleared, kills, boss_kills, curses.size(), victory, mini_kills)
	meta.record_world(current_world, room, victory)
	# l'or ramassé devient de l'encre (2 pièces = 1 encre)
	var bonus := run_gold / 2
	meta.sumi += bonus
	meta.save_data()
	menu.gain_sumi = int(g.get("sumi", 0)) + bonus
	menu.gain_seals = int(g.get("seals", 0))
	menu.sumi = meta.sumi


func _take_curse(id: String) -> void:
	curses.append(id)
	shake = 0.4
	sfx.play("strike", 0.5)
	match id:
		"dry", "oni_eye":
			_extra_picks += 2
		"heavy":
			hero.max_hp += 2
			hero.hp = hero.max_hp
		"haste":
			_extra_picks += 1
			hero.hp = hero.max_hp


## Arrivée au-dessus du vide ou d'un trou : le héros s'arrête au bord (dernier point solide du trajet).
func _land_safe() -> void:
	var path: PackedVector3Array = hero.path
	var safe := _safe_point
	for i in range(path.size() - 1, -1, -1):
		if not hazards.is_hole(path[i], 0.35):
			safe = path[i]
			break
	if hazards.is_hole(safe, 0.2):
		safe = arena.clamp_walk(hero.position, 0.5)
	_splash(hero.position, Toon.FOAM, 8)
	hero.position = Vector3(safe.x, 0, safe.z)
	_prev_hero = hero.position
	sfx.play("empty", 0.7)


func drown(e: Node3D) -> void:
	_splash(e.position, Toon.PRUSSIAN, 14)
	damage_enemy(e, 99.0, false)


func wave_hit(push: Vector3) -> void:
	_hurt_hero()
	hero.position = _clamp_point(hero.position + push)
	_prev_hero = hero.position


func _victory() -> void:
	game_over = true
	_ending_victory = true
	hero.invuln = 999.0
	hud.banner("VICTOIRE", String(Worlds.world(current_world).name), Toon.GOLD, 2.2)
	_set_state("dying")


## Après la séquence de fin : gains, record, et la feuille de résultats.
func _finish_run() -> void:
	var won := _ending_victory
	menu.victory = won
	_award(won)
	menu.new_record = room > record
	if room > record:
		record = room
		_save()
	menu.best = record
	var w: Dictionary = Worlds.world(current_world)
	menu.stat_room = room
	menu.stat_kills = kills
	menu.stat_combo = max_chain
	menu.stat_time = run_time
	menu.world_name = String(w.name)
	menu.world_kanji = String(w.kanji)
	menu.world_color = w.color
	_set_state("over")


# ------------------------------------------------------------------ aides pour les pouvoirs

func damage_enemy(e: Node3D, dmg: float, fx := true) -> void:
	if not is_instance_valid(e) or e.dead:
		return
	var killed: bool = e.hurt_dot(dmg)
	if fx:
		_splash(e.position, Toon.GOLD, 5)
	if killed:
		kills += 1
		powers.on_kill(e)
		_on_enemy_killed(e)
		sfx.play("kill", randf_range(1.1, 1.3), -6.0)
		_splash(e.position, Toon.VERMILION, 14)
		_blot(e.position, Toon.VERMILION, 0.45, 2.5)


func nearest_enemies(pos: Vector3, r: float, n: int, exclude: Node3D) -> Array:
	var found: Array = []
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e == exclude or e.is_harmless():
			continue
		var d := Vector2(e.position.x - pos.x, e.position.z - pos.z).length()
		if d <= r:
			found.append([d, e])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for i in mini(n, found.size()):
		out.append(found[i][1])
	return out


## Dégâts de zone sur les boss (techniques, pouvoirs). Renvoie les points touchés.
func damage_bosses(center: Vector3, r: float, dmg: float, fx := true) -> Array:
	var hits: Array = []
	for bo in bosses:
		if not is_instance_valid(bo) or bo.dead:
			continue
		var p: Vector3 = bo.aoe_hit(center, r, dmg, fx)
		if p == Vector3.INF:
			continue
		hits.append(p)
		if fx:
			_dmg_text(p, dmg, false)
			_splash(p, Toon.GOLD, 6)
	return hits


## Dégâts le long d'un trait sur les boss : chacun n'est touché qu'une fois.
func damage_bosses_line(pts: PackedVector3Array, r: float, dmg: float, fx := true) -> void:
	for bo in bosses:
		if not is_instance_valid(bo) or bo.dead:
			continue
		for i in range(0, pts.size(), 3):
			var p: Vector3 = bo.aoe_hit(pts[i], r, dmg, fx)
			if p != Vector3.INF:
				if fx:
					_dmg_text(p, dmg, false)
					_splash(p, Toon.GOLD, 6)
				break


func heal(n: int) -> void:
	hero.hp = mini(hero.max_hp, hero.hp + n)
	float_text(hero.position, "+%d" % n, Toon.VERMILION)


func zap(a: Vector3, b: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	var mid := (a + b) / 2.0 + Vector3(0, 0.9, 0)
	n.position = mid
	var d := b - a
	d.y = 0
	n.rotation.y = atan2(-d.x, -d.z)
	var m := Toon.flat(Color(Toon.GOLD, 1.0))
	Toon.part(n, Toon.box(Vector3(0.08, 0.08, d.length())), m, Vector3.ZERO)
	effects.append({"node": n, "t": 0.0, "life": 0.22, "kind": "fade", "mats": [m], "alpha": 1.0})


func fire_ring(pos: Vector3, r: float) -> void:
	_blot(pos, Color(Toon.GOLD, 0.55), r, 0.8)
	_splash(pos, Toon.GOLD, 16)


func fire_trail_fx(points: PackedVector3Array, dur: float) -> void:
	var n := Node3D.new()
	add_child(n)
	var mats: Array = []
	var acc := 0.0
	for i in range(1, points.size()):
		acc += points[i].distance_to(points[i - 1])
		if acc < 0.45:
			continue
		acc = 0.0
		var d := Toon.disc(n, randf_range(0.28, 0.4), Color(Toon.GOLD, 0.5), 0.05)
		d.position = Vector3(points[i].x, 0.05, points[i].z)
		mats.append(d.material_override)
	effects.append({"node": n, "t": 0.0, "life": dur, "kind": "fade", "mats": mats, "alpha": 0.5})


## Technique de la forme reconnue, déclenchée à l'arrivée de la ruée.
func _apply_shape() -> void:
	if _shape.is_empty():
		return
	var sh: Dictionary = _shape
	_shape = {}
	match String(sh.shape):
		"loop":
			# Uzu : toupie sabre tendu, aspire et lacère tout autour pendant ~1 s
			hero.spin(0.95)
			_spin_tick = 0.0
			fire_ring(hero.position, 1.8)
			sfx.play("whoosh", 1.4)
		"zigzag":
			# Inazuma : éclair en chaîne sur 4 ennemis
			var from := hero.position
			for o in nearest_enemies(hero.position, 6.0, 4, null):
				zap(from, o.position)
				damage_enemy(o, 1.2)
				from = o.position
			for bp in damage_bosses(hero.position, 6.0, 1.2):
				zap(from, bp)
			sfx.play("strike", 1.6, -2.0)
		"straight":
			# Ittō / iaï : le héros rengaine, puis la coupe s'abat sur toute la ligne
			hero.guard(0.35)
			_iai_t = 0.3
		"return":
			# Kaeshi : garde, intouchable un instant
			hero.guard(0.7)
			_splash(hero.position, Toon.GOLD, 12)
		"enso":
			# Ensō : bond au centre du cercle, puis frappe au sol
			_enso_center = sh.center
			_enso_r = maxf(float(sh.radius), 2.0)
			hero.leap(_enso_center, 0.45)
			sfx.play("whoosh", 0.8)
		"hook":
			# Kagi : demi-tour et estoc sur l'ennemi le plus proche de la pointe
			var tip: Vector3 = sh.tip
			var near: Array = nearest_enemies(tip, 2.6, 1, null)
			if not near.is_empty():
				var o: Node3D = near[0]
				hero.stab(o.position - hero.position)
				zap(hero.position, o.position)
				damage_enemy(o, 3.0)
				shape_text(o.position, "背")
				shake = maxf(shake, 0.25)
			else:
				var bh: Array = damage_bosses(tip, 2.6, 3.0)
				if not bh.is_empty():
					var bp: Vector3 = bh[0]
					hero.stab(bp - hero.position)
					zap(hero.position, bp)
					shake = maxf(shake, 0.25)


## Atterrissage du bond d'ensō : onde de choc qui repousse et blesse tout l'intérieur du cercle.
func _on_hero_landed() -> void:
	shake = maxf(shake, 0.5)
	sfx.play("strike", 0.7)
	_blot(hero.position, Color(Toon.VERMILION, 0.3), _enso_r, 1.2)
	_splash(hero.position, Toon.SUMI, 24)
	fire_ring(hero.position, _enso_r * 0.6)
	for o in nearest_enemies(hero.position, _enso_r + 0.4, 99, null):
		damage_enemy(o, 2.0)
		o.push((o.position - hero.position).normalized() * 4.0)
	damage_bosses(hero.position, _enso_r + 0.4, 2.0)


## Techniques qui durent : toupie (dégâts réguliers + aspiration) et coupe différée de l'iaï.
func _update_moves(dt: float) -> void:
	if hero.spinning > 0.0:
		_spin_tick -= dt
		for o in nearest_enemies(hero.position, 3.0, 99, null):
			var d: Vector3 = hero.position - o.position
			d.y = 0
			o.position += d.normalized() * 2.5 * dt
		if _spin_tick <= 0.0:
			_spin_tick = 0.16
			for o in nearest_enemies(hero.position, 1.9, 99, null):
				damage_enemy(o, 0.6)
				_slash_mark(o.position, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
			damage_bosses(hero.position, 1.9, 0.6)
	if _iai_t > 0.0:
		_iai_t -= dt
		if _iai_t <= 0.0 and _iai_points.size() > 1:
			# la ligne de coupe apparaît d'un coup sur tout le trait
			var a: Vector3 = _iai_points[0]
			var b: Vector3 = _iai_points[_iai_points.size() - 1]
			_iai_line(a, b)
			shake = maxf(shake, 0.4)
			sfx.play("kill", 1.3)
			for e in enemies:
				if is_instance_valid(e) and not e.dead and powers._near_line(e.position, _iai_points, 0.9 + float(e.radius)):
					damage_enemy(e, 2.0)
					_dmg_text(e.position, 2.0, false)
			damage_bosses_line(_iai_points, 0.9, 2.0)
			_iai_points = PackedVector3Array()


func _iai_line(a: Vector3, b: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = (a + b) / 2.0 + Vector3(0, 0.6, 0)
	var d := b - a
	d.y = 0
	n.rotation.y = atan2(-d.x, -d.z)
	var m := Toon.flat(Color(1, 1, 1, 1))
	Toon.part(n, Toon.box(Vector3(0.12, 0.05, d.length() + 1.0)), m, Vector3.ZERO)
	effects.append({"node": n, "t": 0.0, "life": 0.35, "kind": "fade", "mats": [m], "alpha": 1.0})

## Kaeshi : les boules proches du trait repartent vers les ennemis.
func _reflect_bullets(pts: PackedVector3Array) -> void:
	for b in bullets:
		var n: Node3D = b.node
		var q := Vector3(n.position.x, 0, n.position.z)
		for i in range(0, pts.size(), 3):
			if q.distance_to(pts[i]) < 1.6:
				b.vel = -b.vel * 1.4
				b["friendly"] = true
				_splash(n.position, Toon.GOLD, 6)
				break


func shape_text(pos: Vector3, kanji: String) -> void:
	if kanji == "":
		return
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = kanji
	l.font_size = 160
	l.pixel_size = 0.006
	l.modulate = Toon.SUMI
	l.outline_modulate = Toon.WASHI
	l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 1.6, 0)
	add_child(l)
	effects.append({"node": l, "t": 0.0, "life": 0.75, "kind": "label"})


## Chiffre de dégâts au-dessus de l'ennemi : blanc cerclé d'encre, vermillon s'il tue ou en combo.
func _dmg_text(pos: Vector3, dmg: float, killed: bool) -> void:
	var txt := str(int(round(dmg))) if absf(dmg - round(dmg)) < 0.05 else "%.1f" % dmg
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = txt
	# taille de police fixe (les glyphes ne sont rendus qu'une fois), on grossit par pixel_size
	l.font_size = 120
	l.pixel_size = 0.006 * (90.0 + 14.0 * minf(dmg, 6.0)) / 120.0
	l.modulate = Toon.VERMILION if killed or combo >= 3 else Color(1, 1, 1)
	l.outline_modulate = Toon.SUMI
	l.outline_size = 24
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(randf_range(-0.4, 0.4), 1.6, 0)
	add_child(l)
	effects.append({"node": l, "t": 0.0, "life": 0.7, "kind": "label"})


func float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	# police du jeu (le web n'a pas de police de secours) : symboles et macrons ramenés à ce qu'elle contient
	l.font = KANJI_FONT
	l.text = Hud.plain(text.replace("✕", "×").replace("○", "O"))
	l.font_size = 110
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_modulate = Toon.SUMI
	l.outline_size = 20
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 2.2, 0)
	add_child(l)
	effects.append({"node": l, "t": 0.0, "life": 0.75, "kind": "label"})

## Direction de marche d'un ennemi vers `to`, en passant par les passerelles si besoin.
func steer_dir(from: Vector3, to: Vector3) -> Vector3:
	var t: Vector3 = arena.steer(from, to)
	var d := t - from
	d.y = 0
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO


func clamp_to_arena(n: Node3D, r: float) -> void:
	var cp: Vector3 = arena.clamp_walk(n.position, r)
	n.position = Vector3(cp.x, n.position.y, cp.z)


func _clamp_point(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -HALF.x + 0.3, HALF.x - 0.3), 0, clampf(p.z, -HALF.y + 0.3, HALF.y - 0.3))


# ------------------------------------------------------------------ entrée

func _input(event: InputEvent) -> void:
	# tactile (téléphone) et souris (ordinateur) ; la souris émulée depuis le tactile sert aux boutons du menu
	if state != "play" and state != "tuto":
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_touch_down(event.position)
		else:
			_touch_up(event.position)
	elif event is InputEventScreenDrag:
		if event.index == 0:
			_touch_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_down(event.position)
		else:
			_touch_up(event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_touch_move(event.position)


func _ground(sp: Vector2) -> Vector3:
	var o := cam.project_ray_origin(sp)
	var n := cam.project_ray_normal(sp)
	if absf(n.y) < 0.0001:
		return Vector3.ZERO
	var p := o + n * (-o.y / n.y)
	p.y = 0
	return p


func _touch_down(sp: Vector2) -> void:
	if hud.is_over_pause(sp) or tuto.is_over_ui(sp):
		return
	if game_over:
		return
	# on trace dans le pad du bas : le trait part du héros et reproduit le geste du doigt, en plus grand
	# en mode pad, on peut poser le doigt n'importe où : le geste est reproduit depuis le héros
	# (le cadre du pad n'est qu'un repère visuel)
	_strokes_done += 1
	touching = true
	_pad_start = sp
	hud.pad_trail = PackedVector2Array([sp])
	origin = hero.dash_end()
	stroke_layer += 1
	stroke = InkStroke.new(origin, stroke_layer)
	add_child(stroke)


## Zone du pad tactile, en bas de l'écran (coordonnées de la vue).
func pad_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var hk := 0.2 if pad_size == "s" else (0.27 if pad_size == "m" else 0.34)
	var wk := 0.8 if pad_size == "s" else (0.92 if pad_size == "m" else 0.96)
	return Rect2(Vector2(vs.x * (1.0 - wk) / 2.0, vs.y * (0.955 - hk)), Vector2(vs.x * wk, vs.y * hk))


## Geste dans le pad -> déplacement au sol : la largeur du pad couvre ~15 m (haut de l'écran = vers le fond).
func _pad_to_world(d: Vector2) -> Vector3:
	var k := 15.0 / maxf(pad_rect().size.x, 1.0)
	return Vector3(d.x, 0, d.y) * k


func _touch_move(sp: Vector2) -> void:
	if not touching or stroke == null:
		return
	var target := _clamp_point(_ground(sp)) if ctrl_mode == "screen" else _clamp_point(origin + _pad_to_world(sp - _pad_start))
	if hud.pad_trail.size() == 0 or hud.pad_trail[hud.pad_trail.size() - 1].distance_to(sp) > 4.0:
		hud.pad_trail.append(sp)
	var was_empty: bool = stroke.exhausted
	var used: float = stroke.extend_to(target, elan)
	elan -= used
	if stroke.exhausted and not was_empty:
		sfx.play("empty", 0.8)


func _touch_up(sp: Vector2) -> void:
	if not touching:
		return
	touching = false
	hud.pad_trail = PackedVector2Array()
	if stroke == null:
		return
	if stroke.length >= 0.7:
		_launch(stroke)
	else:
		# petit coup de doigt : bond d'esquive
		var flick := (_ground(sp) - _ground(_pad_start)) if ctrl_mode == "screen" else _pad_to_world(sp - _pad_start)
		flick.y = 0
		if flick.length() > 0.12 and elan >= powers.dodge_cost(DODGE_COST):
			var s: MeshInstance3D = stroke
			var dd: float = powers.dodge_dist(DODGE_DIST)
			var end := _clamp_point(origin + flick.normalized() * dd)
			s.extend_to(end, dd)
			elan -= powers.dodge_cost(DODGE_COST)
			hero.invuln = maxf(hero.invuln, powers.val("shadow_step"))
			_launch(s)
		else:
			elan = minf(elan_max(), elan + stroke.length)
			stroke.queue_free()
	stroke = null


func _launch(s: MeshInstance3D) -> void:
	if dash_stroke and is_instance_valid(dash_stroke):
		dash_stroke.start_drying()
	dash_stroke = s
	if hero.dashing:
		# on enchaîne : la ruée en cours se termine et la nouvelle prend le relais
		var rest := PackedVector3Array()
		for i in range(hero.path_i - 1, hero.path.size()):
			rest.append(hero.path[i] if i >= hero.path_i else hero.position)
		for p in s.points:
			rest.append(p)
		hero.start_dash(rest)
	else:
		hero.start_dash(s.points)
	stroke_id += 1
	combo = 0
	_stroke_kills = 0
	_stroke_hit = false
	_prev_hero = hero.position
	hero.speed_mult = powers.dash_mult()
	_auto_step = false  # un vrai trait reprend la main sur le pas de côté automatique
	_safe_point = s.points[0]
	powers.on_stroke_release(s.points)
	_shape = StrokeShapes.detect(s.points) if s.length >= 2.0 else {}
	if not _shape.is_empty():
		shape_text(s.last(), String(SHAPE_KANJI.get(_shape.shape, "")))
		sfx.play("whoosh", 0.7)
		if _shape.shape == "straight":
			hero.speed_mult *= 1.6
			_iai_points = s.points
		elif _shape.shape == "zigzag":
			hero.speed_mult *= 1.5
		elif _shape.shape == "return":
			_reflect_bullets(s.points)
	sfx.play("whoosh", randf_range(0.9, 1.1))


func _on_dash_finished() -> void:
	if _auto_step:
		_auto_step = false
		return
	if dash_stroke and is_instance_valid(dash_stroke):
		dash_stroke.start_drying()
	dash_stroke = null
	if state == "tuto":
		tuto.on_dash_end(hero.position, _stroke_kills, String(_shape.get("shape", "")))
	if _stroke_hit:
		_add_chain(2 if not _shape.is_empty() else 1)
	_apply_shape()
	if hazards.is_hole(hero.position):
		_land_safe()
	for bo in bosses:
		if is_instance_valid(bo):
			bo.end_stroke(stroke_id)
	powers.on_dash_end(hero.position, _stroke_kills)
	if combo >= 3:
		elan = elan_max()
	_reset_stroke_state()


# ------------------------------------------------------------------ combat

func spawn_bullet(pos: Vector3, dir: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	if not _fx_cache.has("bullet"):
		_fx_cache["bullet"] = [Toon.sphere(0.3), Toon.mat(Toon.VERMILION, true, 0.05), Toon.sphere(0.13), Toon.mat(Toon.WASHI, false), Toon.flat(Color(0, 0, 0, 0.2))]
	var bc: Array = _fx_cache["bullet"]
	Toon.part(n, bc[0], bc[1], Vector3.ZERO)
	Toon.part(n, bc[2], bc[3], Vector3(0, 0.12, -0.12))
	var shadow := _disc(n, 0.26, bc[4])
	shadow.position.y = -pos.y + 0.012
	bullets.append({"node": n, "vel": dir * 3.4, "life": 7.0})
	sfx.play("shot", randf_range(0.9, 1.1), -6.0)


func take_token(e: Node) -> bool:
	for i in range(_attackers.size() - 1, -1, -1):
		if not is_instance_valid(_attackers[i]) or _attackers[i].dead:
			_attackers.remove_at(i)
	if e in _attackers:
		return true
	if _attackers.size() >= ATTACK_TOKENS:
		return false
	_attackers.append(e)
	return true


func free_token(e: Node) -> void:
	_attackers.erase(e)


## Annule le trait en train d'être tracé (pause, fin de salle, mort…).
func _cancel_stroke() -> void:
	if is_instance_valid(stroke):
		stroke.queue_free()
	stroke = null
	touching = false


## Oublie la ruée finie : touches et forme reconnue. `all` annule aussi la coupe iai en attente.
func _reset_stroke_state(all := false) -> void:
	combo = 0
	_stroke_kills = 0
	_stroke_hit = false
	_shape = {}
	if all:
		_iai_t = 0.0
		_iai_points = PackedVector3Array()


## Vrai si finir en `p` dans `eta` secondes tombe dans une attaque (zone qui frappe ou boule qui passe).
func is_danger(p: Vector3, eta: float) -> bool:
	if hazards.danger(p, eta):
		return true
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var z: Array = e.danger_zone()
		if z.size() == 3:
			var c: Vector3 = z[0]
			if Vector2(p.x - c.x, p.z - c.z).length() < float(z[1]) + 0.35 and float(z[2]) < eta + 0.35:
				return true
	for bo in bosses:
		# chaque boss teste toutes ses zones annoncées, avec leur vraie forme
		if is_instance_valid(bo) and bo.danger_at(p, eta):
			return true
	for b in bullets:
		var n: Node3D = b.node
		for k in 4:
			var q: Vector3 = n.position + b.vel * (eta + 0.15 * k)
			if Vector2(p.x - q.x, p.z - q.z).length() < 0.75:
				return true
	return false


func enemy_strike(center: Vector3, r: float) -> void:
	shake = maxf(shake, 0.12)
	sfx.play("strike", randf_range(0.9, 1.1), -3.0)
	_blot(center, Color(Toon.VERMILION, 0.35), r * 0.9, 0.6)
	var d := Vector2(hero.position.x - center.x, hero.position.z - center.z).length()
	if d < r + Hero.RADIUS * 0.6:
		_hurt_hero()


func chain_mult() -> float:
	return 1.0 + minf(chain * 0.05, 1.0)


func _add_chain(n: int) -> void:
	var before := chain
	chain += n
	max_chain = maxi(max_chain, chain)
	_chain_t = 0.0
	for tier in CHAIN_TIERS.keys():
		if before < int(tier) and chain >= int(tier):
			# petite annonce plutôt qu'un bandeau : on ne cache pas l'action en plein combat
			hud.toast("%s  ·  DÉGÂTS +%d %%" % [String(CHAIN_TIERS[tier]), int(round((chain_mult() - 1.0) * 100.0))])
			sfx.play("shot", 1.5, -2.0)


func _break_chain() -> void:
	if chain >= 3:
		hud.chain_break = 1.0
		hud.chain_lost = chain
	chain = 0
	_chain_t = 0.0


func _hurt_hero() -> void:
	if hero.dashing or hero.invuln > 0.0 or hero.protected() or game_over:
		return
	if foam > 0:
		# bouclier d'écume : le coup est bu par l'écume
		foam -= 1
		hero.invuln = 0.6
		clang(hero.position)
		float_text(hero.position, "ÉCUME", Toon.FOAM)
		return
	hero.hurt()
	_break_chain()
	hud.hurt_flash = 1.0
	shake = 0.45
	sfx.play("hurt")
	_splash(hero.position, Toon.SUMI, 14)
	if hero.hp <= 0:
		game_over = true
		_ending_victory = false
		_set_state("dying")
		sfx.play("kill", 0.5)
		_cancel_stroke()


func _check_slashes() -> void:
	if _auto_step:
		# pas de côté automatique : ce n'est pas un coup
		_prev_hero = hero.position
		return
	var a := _prev_hero
	var b := hero.position
	_prev_hero = b
	if not hero.dashing and a.distance_to(b) < 0.001:
		return
	var seg := b - a
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.is_harmless() or e.last_stroke == stroke_id:
			continue
		var p: Vector3 = e.position
		var t := 0.0
		if seg.length_squared() > 0.0001:
			t = clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var q := a + seg * t
		if Vector2(p.x - q.x, p.z - q.z).length() < e.radius + HIT_REACH:
			e.last_stroke = stroke_id
			combo += 1
			var dmg := 1.0 * (1.0 + 0.5 * (combo - 1))
			var dir: Vector3 = seg if seg.length_squared() > 0.0001 else hero.facing
			var piercing: bool = not _shape.is_empty() and _shape.shape == "straight"
			if not piercing and e.blocks(dir):
				e.last_stroke = stroke_id
				combo -= 1
				clang(p)
				float_text(p, "GARDE !", Toon.FOAM)
				e.shield_break()
				hero.stop_dash()
				# le héros rebondit sur le bouclier au lieu de rester collé
				hero.position = arena.clamp_walk(hero.position - dir.normalized() * 0.8, 0.4)
				_prev_hero = hero.position
				continue
			if piercing:
				dmg *= 1.5
			dmg *= chain_mult()
			dmg = powers.on_hit(e, dmg, dir)
			_stroke_hit = true
			_chain_t = 0.0
			var killed: bool = e.take_hit(dmg, dir)
			_dmg_text(p, dmg, killed)
			vfx.impact(p, dir, killed)
			if killed:
				_on_enemy_killed(e)
				# le grand 斬 ne vient que sur une belle série
				vfx.kill_burst(p, dir, combo >= 3)
				hud.screen_flash = maxf(hud.screen_flash, 0.12)
			if killed:
				kills += 1
				_stroke_kills += 1
				powers.on_kill(e)
			elan = minf(elan_max(), elan + ELAN_PER_HIT)
			shake = maxf(shake, 0.11 if killed else 0.05)
			sfx.play("kill" if killed else "slash", 1.0 + 0.08 * (combo - 1) + randf_range(-0.04, 0.04))
			_splash(p, Toon.VERMILION, 8 if killed else 4)
			# tache d'encre au sol seulement à la mise à mort
			if killed:
				_blot(p, Color(Toon.SUMI, 0.6), randf_range(0.25, 0.38) * (1.4 if e.kind == "brute" else 1.0), 1.8)
			_slash_mark(p, dir)
			if combo >= 3:
				_combo_label(p, combo)
	for bo in bosses:
		if not is_instance_valid(bo):
			continue
		if bo.check_dash(a, b, stroke_id):
			combo += 1
			var bd := 1.0 * (1.0 + 0.5 * (combo - 1)) * chain_mult()
			_stroke_hit = true
			_chain_t = 0.0
			var bdir: Vector3 = seg if seg.length_squared() > 0.0001 else hero.facing
			bo.take_hit(bd, bdir)
			powers.on_boss_hit(bo.position)
			elan = minf(elan_max(), elan + ELAN_PER_HIT)
			shake = maxf(shake, 0.22)
			sfx.play("slash", 0.85 + 0.08 * (combo - 1))
			_splash(bo.position + Vector3(0, 0.6, 0), Toon.VERMILION, 6)
			_slash_mark(bo.position, bdir)
			vfx.impact(bo.position, bdir, false)


func _update_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b = bullets[i]
		var n: Node3D = b.node
		n.position += b.vel * dt
		b.life -= dt
		var hp := n.position
		hp.y = 0
		var d := hp.distance_to(hero.position)
		# filet de sécurité : un pas de côté automatique, une fois par vague
		if safety_left > 0 and not b.get("friendly", false) and d < 1.0 and not hero.dashing and hero.invuln <= 0.0 and not game_over:
			var v: Vector3 = b.vel
			var side := Vector3(-v.z, 0, v.x).normalized()
			if side.dot(hero.position - hp) < 0:
				side = -side
			safety_left -= 1
			var step := PackedVector3Array([hero.position, _clamp_point(hero.position + side * 1.3)])
			_auto_step = true
			hero.start_dash(step)
		if b.get("friendly", false):
			for o in nearest_enemies(hp, 0.8, 1, null):
				damage_enemy(o, 1.5)
				b.life = 0.0
		elif d < 0.3 + Hero.RADIUS and not hero.dashing and hero.invuln <= 0.0:
			_hurt_hero()
			b.life = 0.0
		if b.life <= 0.0 or absf(n.position.x) > HALF.x + 1.0 or absf(n.position.z) > HALF.y + 1.0:
			if b.life <= 0.0:
				_splash(n.position, Toon.VERMILION, 6)
			n.queue_free()
			bullets.remove_at(i)


# ------------------------------------------------------------------ effets

func _splash(pos: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	# gouttes : un maillage par couleur, partagé (pas de nouvelle ressource à chaque coup)
	var key := "drop" + color.to_html()
	if not _fx_cache.has(key):
		var m := Toon.sphere(0.07)
		m.radial_segments = 8
		m.rings = 4
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = color
		m.material = mt
		_fx_cache[key] = m
	p.mesh = _fx_cache[key]
	p.amount = amount
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 75.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0, -20, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.position = pos + Vector3(0, 0.6, 0)
	add_child(p)
	p.emitting = true
	effects.append({"node": p, "t": 0.0, "life": 1.0, "kind": "none"})


func _blot(pos: Vector3, color: Color, r: float, life: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = Vector3(pos.x, 0, pos.z)
	# disque unité partagé, mis à l'échelle ; une seule matière par tache (elle s'efface d'un bloc)
	var mt := Toon.flat(color)
	var main_disc := _disc(n, r, mt, 0.015)
	main_disc.scale = Vector3(r, 1, r * randf_range(0.7, 1.0))
	main_disc.rotation.y = randf() * TAU
	for i in 4:
		var a := randf() * TAU
		var dd := _disc(n, r * randf_range(0.12, 0.25), mt, 0.016)
		dd.position += Vector3(cos(a), 0, sin(a)) * r * randf_range(1.1, 1.8)
	effects.append({"node": n, "t": 0.0, "life": life, "kind": "fade", "mats": [mt], "alpha": color.a})


## Disque plat au sol de rayon `r`, sur un maillage unité partagé.
func _disc(parent: Node3D, r: float, material: Material, y := 0.01) -> MeshInstance3D:
	if not _fx_cache.has("disc"):
		_fx_cache["disc"] = Toon.cyl(1.0, 1.0, 0.004, 24)
	var d := Toon.part(parent, _fx_cache["disc"], material, Vector3(0, y, 0), Vector3(r, 1, r))
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return d


func _slash_mark(pos: Vector3, dir: Vector3) -> void:
	# éclair blanc en travers de l'ennemi : le « tranchant »
	var n := Node3D.new()
	add_child(n)
	n.position = pos + Vector3(0, 0.7, 0)
	var d := dir.normalized()
	n.rotation.y = atan2(-d.x, -d.z) + randf_range(-0.5, 0.5)
	if not _fx_cache.has("slash"):
		_fx_cache["slash"] = Toon.box(Vector3(0.09, 0.03, 2.2))
	var bar := Toon.part(n, _fx_cache["slash"], Toon.flat(Color(1, 1, 1, 0.95)), Vector3.ZERO)
	bar.rotation.x = randf_range(-0.4, 0.4)
	effects.append({"node": n, "t": 0.0, "life": 0.18, "kind": "slash", "mats": [bar.material_override], "alpha": 0.95})


func _combo_label(pos: Vector3, n: int) -> void:
	var l := Label3D.new()
	l.text = "×%d" % n
	l.font = KANJI_FONT
	l.font_size = 110
	l.pixel_size = 0.006 * (70.0 + 6.0 * mini(n, 6)) / 110.0
	l.modulate = Toon.VERMILION
	l.outline_modulate = Toon.SUMI
	l.outline_size = 22
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 1.8, 0)
	add_child(l)
	effects.append({"node": l, "t": 0.0, "life": 0.75, "kind": "label"})


func _update_effects(dt: float, real: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var fx = effects[i]
		var node: Node3D = fx.node
		fx.t += real if fx.kind == "label" else dt
		var k: float = fx.t / fx.life
		match fx.kind:
			"fade":
				var a: float = fx.alpha * clampf((1.0 - k) * 2.0, 0.0, 1.0)
				for m in fx.mats:
					m.albedo_color.a = a
			"slash":
				node.scale = Vector3(1, 1, 1.0 + k)
				for m in fx.mats:
					m.albedo_color.a = fx.alpha * (1.0 - k)
			"label":
				node.position.y += real * 1.5
				var s := 1.0 + 0.4 * maxf(0.0, 1.0 - k * 6.0)
				node.scale = Vector3.ONE * s
				node.modulate.a = clampf((1.0 - k) * 3.0, 0.0, 1.0)
				node.outline_modulate.a = node.modulate.a
		if k >= 1.0:
			node.queue_free()
			effects.remove_at(i)


# ------------------------------------------------------------------ boucle

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := minf((now - _ticks) / 1000000.0, 0.05)
	_ticks = now

	# pause : tout est figé, seul l'écran de pause vit
	if state == "paused" or (state == "pick" and _pick_context == "level"):
		Engine.time_scale = 0.0
		return

	# temps : fin de partie au ralenti, sinon normal
	var target := 1.0
	if state == "dying":
		target = 0.25 if not _ending_victory else 0.6
	elif game_over:
		target = 0.35
	if target < Engine.time_scale:
		Engine.time_scale = lerpf(Engine.time_scale, target, minf(1.0, real * 18.0))
	else:
		Engine.time_scale = target
	var dt := real * Engine.time_scale

	if not touching and not hero.dashing:
		elan = minf(elan_max(), elan + ELAN_REGEN * powers.regen_mult() * meta.regen_mult() * real)

	_check_slashes()
	_update_bullets(dt)
	_update_effects(dt, real)

	# nettoyage et vagues
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]):
			enemies.remove_at(i)
	for i in range(bosses.size() - 1, -1, -1):
		if not is_instance_valid(bosses[i]):
			bosses.remove_at(i)
	_state_t += real
	if state == "dying":
		# la caméra s'approche du héros, l'image se délave
		if not _ending_victory:
			hud.dying = clampf(_state_t / 1.3, 0.0, 1.0)
			var close := Transform3D(Basis(), hero.position + Vector3(0, 7.5, 6.0)).looking_at(hero.position + Vector3(0, 0.8, 0), Vector3.UP)
			_cam_base = _cam_base.interpolate_with(close, minf(1.0, real * 2.0))
		if _state_t > 1.6:
			_finish_run()
	if state == "tuto":
		elan = elan_max()
		_update_moves(dt)
	if state == "play" and _pending_levels > 0 and not hero.dashing and not touching:
		_pending_levels -= 1
		_pick_context = "level"
		hud.toast("NIVEAU %d" % level)
		vfx.ring(Vector3(hero.position.x, 0.05, hero.position.z), Toon.GOLD, 2.2)
		_set_state("pick")
		_open_upgrades()
	if state == "play":
		run_time += real
		if chain > 0:
			_chain_t += real
			if _chain_t > CHAIN_TIMEOUT:
				chain = 0
		_update_moves(dt)
		powers.update(dt)
		hazards.update(dt)
		for bo in bosses:
			if is_instance_valid(bo) and bo.touching_hero(hero.position):
				_hurt_hero()
		var alive := 0
		for e in enemies:
			if is_instance_valid(e) and not e.dead:
				alive += 1
		if not _waves_left.is_empty() and alive <= 1:
			# vague suivante
			_spawn_list(_waves_left.pop_front())
			wave_index += 1
			sfx.play("strike", 0.8, -4.0)
			hud.toast("VAGUE %d / %d" % [wave_index, waves_total])
		elif room == 0:
			wave_wait -= real
			if wave_wait <= 0.0:
				_begin_room()
		elif not _room_done and enemies.is_empty() and _waves_left.is_empty() and bosses.is_empty():
			wave_wait -= real
			if wave_wait <= 0.0:
				wave_wait = 0.8
				_room_done = true
				_room_cleared()
		elif arena.gate_open and arena.gate_reached(hero.position):
			_transit()
		# un noyé hors de la terre ferme est ramené au bord le plus proche
		for e in enemies:
			if is_instance_valid(e) and e.kind == "funa" and not e.dead:
				var cp: Vector3 = arena.clamp_walk(e.position, 0.45)
				e.position = Vector3(cp.x, e.position.y, cp.z)
	elif state == "transit":
		hud.wipe = clampf(_state_t / 0.35, 0.0, 1.0) if _state_t < 0.45 else clampf(1.0 - (_state_t - 0.45) / 0.35, 0.0, 1.0)
		if _state_t >= 0.4 and not _rebuilt:
			_rebuild_room()
		if _state_t >= 0.8:
			hud.wipe = 0.0
			_set_state("play")

	# caméra : plan d'accueil, transition vers l'arène, secousse en jeu
	if state == "menu":
		var sway := Vector3(sin(_state_t * 0.35) * 0.25, sin(_state_t * 0.5) * 0.08, 0)
		cam.global_transform = _menu_transform().translated(sway)
		_menu_slash -= real
		if _menu_slash <= 0.0:
			_menu_slash = 4.0
			hero.ch.play_once("1H_Melee_Attack_Slice_Diagonal", 1.0)
	elif state == "intro":
		var k := clampf(_state_t / 0.9, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		cam.global_transform = _menu_transform().interpolate_with(_cam_base, k)
		if k >= 1.0:
			_set_state("play")
	elif state == "worlds":
		cam.global_transform = _menu_transform()
	elif shake > 0.0:
		shake = maxf(0.0, shake - real * 1.6)
		var s := shake * shake * 1.2
		cam.global_transform = _cam_base.translated(Vector3(randf_range(-s, s), randf_range(-s, s) * 0.5, randf_range(-s, s)))
	else:
		cam.global_transform = _cam_base

	hud.pad = pad_rect() if ctrl_mode == "pad" else Rect2()
	hud.pad_active = touching
	var show_pad := pad_show == "always" or (pad_show == "start" and (state == "tuto" or _strokes_done < 12))
	hud.pad_alpha = move_toward(hud.pad_alpha, 1.0 if show_pad else 0.0, real * 1.5)
	hud.in_play = state in IN_PLAY_STATES
	hud.pause_enabled = state == "play"  # le bouton pause n'apparaît que là où il agit
	var wd: Dictionary = Worlds.world(current_world)
	hud.world_kanji = String(wd.kanji)
	hud.world_color = wd.color
	hud.rooms_total = ROOMS
	menu.rooms_total = ROOMS
	hud.elan_m = elan_max()
	hud.combo = combo if hero.dashing else 0
	hud.chain = chain if state != "tuto" else 0
	hud.level = level
	hud.xp_ratio = float(xp) / float(xp_need())
	hud.gold = run_gold
	hud.chain_left = 1.0 - _chain_t / CHAIN_TIMEOUT
	hud.chain_mult = chain_mult()
	var bars: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.has_meta("max_hp"):
			var mh: float = e.get_meta("max_hp")
			if e.hp < mh - 0.01 and not cam.is_position_behind(e.position):
				var top := 2.9 if e.kind == "brute" else 2.1
				bars.append([cam.unproject_position(e.position + Vector3(0, top, 0)), e.hp / mh])
	hud.enemy_bars = bars
	hud.hp = hero.hp
	hud.max_hp = hero.max_hp
	hud.elan = elan / elan_max()
	if touching and stroke != null:
		stroke.danger = is_danger(stroke.last(), stroke.length / Hero.DASH_SPEED)
	hud.elan_empty = touching and stroke != null and stroke.exhausted
	hud.wave = maxi(room, 1)
	hud.wave_index = wave_index
	hud.waves_total = waves_total
	hud.show_waves = state == "play" and room > 0 and not _room_done
	hud.gate_hint = arena.gate_open and state == "play"
	hud.game_over = game_over
	hud.boss_name = ""
	for bo in bosses:
		if is_instance_valid(bo) and not bo.dead:
			hud.boss_name = bo.title
			hud.boss_ratio = clampf(bo.hp / bo.max_hp, 0.0, 1.0)
