extends Node3D
## Boucle de jeu : on trace, on lâche = ruée qui tranche. 9 salles, un rouleau à choisir entre chaque.

const Toon = preload("res://scripts/toon.gd")
const Hero = preload("res://scripts/hero.gd")
const Enemy = preload("res://scripts/enemy.gd")
const InkStroke = preload("res://scripts/ink_stroke.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Hud = preload("res://scripts/hud.gd")
const Menu = preload("res://scripts/menu.gd")
const Decor = preload("res://scripts/decor.gd")
const Powers = preload("res://scripts/powers.gd")
const Picker = preload("res://scripts/picker.gd")
const Boss = preload("res://scripts/boss.gd")
const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
const Hazards = preload("res://scripts/hazards.gd")
const Arena = preload("res://scripts/arena.gd")
const Worlds = preload("res://scripts/worlds.gd")
const WorldMap = preload("res://scripts/worldmap.gd")
const Meta = preload("res://scripts/meta.gd")
const Refuge = preload("res://scripts/refuge.gd")
# malédictions du sanctuaire (après les salles 3 et 7) : un malus pour toute la partie, une récompense tout de suite
const CURSES := {
	"dry": {"name": "Encre sèche", "text": "Trait -30 %  ·  2 rouleaux en plus"},
	"oni_eye": {"name": "Œil d'oni", "text": "Ennemis +50 % de vie  ·  2 rouleaux en plus"},
	"heavy": {"name": "Pas lourd", "text": "Plus de pas de côté  ·  +2 vies max, soin"},
	"haste": {"name": "Hâte des morts", "text": "Ennemis +25 % vitesse  ·  1 rouleau, soin"},
}
const KANJI_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const SHAPE_KANJI := {"loop": "渦", "zigzag": "雷", "return": "返", "straight": "一", "enso": "円", "hook": "鉤"}
const ROOMS := 9
const KIND_COST := {"oni": 1, "kappa": 2, "brute": 3, "tate": 3, "funa": 2}
const KIND_ROOM := {"oni": 1, "kappa": 2, "brute": 3, "tate": 3, "funa": 4}  # première salle où chaque ennemi peut venir
const UNLOCK_ALL := true  # prototype : tous les mondes ouverts pour les tester
const SAVE_PATH := "user://ippitsu.cfg"

const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (x, z)
const REL := 1.25  # amplification du geste du doigt
const SLOW := 0.1

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

var hitstop := 0.0
var shake := 0.0
var wave := 0
var wave_wait := 1.0
var safety_left := 1  # pas de côté automatiques restants dans la salle
var attack_tokens := 2  # ennemis autorisés à préparer une attaque en même temps
var _attackers: Array = []
var game_over := false
var _ticks := 0
var _cam_base := Transform3D()

var state := "menu"  # menu | intro | play | over
var menu: Control
var record := 0
var _state_t := 0.0
var _menu_slash := 3.0
var _env: Environment
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
	apply_world(clampi(int(wsearch.substr(wpos + 6).get_slice("&", 0)), 1, 5) if wpos >= 0 else 1)
	_start()
	# `-- --autoplay` : démarre directement en jeu (vérification automatique du CI)
	var autoplay := "--autoplay" in OS.get_cmdline_user_args()
	if autoplay:
		var fails: Array = StrokeShapes.self_test()
		if not fails.is_empty():
			print("SCRIPT ERROR: formes de trait : ", fails)
	if OS.has_feature("web"):
		autoplay = autoplay or "autoplay" in str(JavaScriptBridge.eval("location.search", true))
	_set_state("play" if autoplay else "menu")
	# `?pick` (web) : ouvre directement le choix de rouleau, pour vérifier l'écran
	# `?room=N` (web) : commence directement à la salle N (tests des boss : 5 et 9)
	var search := str(JavaScriptBridge.eval("location.search", true)) if OS.has_feature("web") else ""
	var rm := search.find("room=")
	if rm >= 0:
		_set_state("play")
		room = clampi(int(search.substr(rm + 5).get_slice("&", 0)), 1, ROOMS) - 1
		arena.build_room(room + 1, ROOMS, randi())
		hero.position = arena.start
		_prev_hero = hero.position
		_begin_room()
	if OS.has_feature("web") and "pick" in str(JavaScriptBridge.eval("location.search", true)):
		_set_state("play")
		room = 1
		_room_cleared()
	_ticks = Time.get_ticks_usec()


# ------------------------------------------------------------------ états

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		record = int(cfg.get_value("game", "best", 0))
		menu.muted = bool(cfg.get_value("game", "muted", false))
	menu.best = record
	menu.sumi = meta.sumi
	AudioServer.set_bus_mute(0, menu.muted)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", record)
	cfg.set_value("game", "muted", menu.muted)
	cfg.save(SAVE_PATH)


func _set_state(s: String) -> void:
	state = s
	_state_t = 0.0
	hud.visible = s != "menu"
	match s:
		"menu":
			menu.show_mode("home")
			hero.face(Vector3(0, 0, 1))
			hero.snap_facing()
		"intro":
			menu.show_mode("hidden")
			hero.face(Vector3(0, 0, -1))
		"play":
			menu.show_mode("hidden")
		"over":
			menu.show_mode("over")


func _on_play() -> void:
	sfx.play("slash", 0.8, -4.0)
	if state == "over":
		_start()
		_set_state("play")
	else:
		# choix du monde sur le rouleau
		menu.show_mode("hidden")
		state = "worlds"
		var unlocked: int = 5 if UNLOCK_ALL else int(meta.unlocked)
		worldmap.open(Worlds.WORLDS, unlocked, meta.world_best, current_world)


func _on_world_chosen(id: int) -> void:
	sfx.play("slash", 0.9, -4.0)
	if id != current_world:
		apply_world(id)
	_start()
	_set_state("intro")


func _on_worldmap_closed() -> void:
	_set_state("menu")


func _on_atelier() -> void:
	sfx.play("whoosh", 0.8)
	menu.show_mode("hidden")
	refuge.open()


func _on_refuge_closed() -> void:
	menu.sumi = meta.sumi
	_set_state("menu")
	_start()


func _on_home() -> void:
	_start()
	_set_state("menu")


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
	_env.ambient_light_energy = float(w.ambient_energy)
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
	var bottom := vs.y * 0.9
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
	arena.build_room(1, ROOMS, randi())
	hero = Hero.new()
	add_child(hero)
	hero.position = arena.start
	hero.dash_finished.connect(_on_dash_finished)
	_prev_hero = hero.position
	elan = elan_max()
	wave = 0
	wave_wait = 0.8
	room = 0
	_room_queue = []
	_waves_left = []
	_room_done = false
	powers.reset()
	hazards.clear()
	curses.clear()
	_extra_picks = 0
	picker.rerolls = meta.rerolls()
	kills = 0
	boss_kills = 0
	mini_kills = 0
	hero.max_hp = 5 + meta.hp_bonus()
	hero.hp = hero.max_hp
	game_over = false
	touching = false
	hud.game_over = false
	hud.over_t = 0.0
	hitstop = 0.0
	shake = 0.0
	Engine.time_scale = 1.0
	_fit_camera()


func elan_max() -> float:
	return (ELAN_MAX + powers.elan_bonus() + meta.elan_bonus()) * (0.7 if "dry" in curses else 1.0)


## Salle suivante : 3 vagues d'ennemis à tuer, tirées selon le monde, budget croissant.
func _begin_room() -> void:
	room += 1
	wave = room
	_room_done = false
	safety_left = 0 if "heavy" in curses else meta.safety_per_room()
	hazards.begin_room(room, hero.position)
	var w: Dictionary = Worlds.world(current_world)
	var weights: Dictionary = w.enemies
	var budget := 5 + 3 * room
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
	if room == 5:
		list = ["oni", "oni", "oni"]
		_spawn_boss("okappa")
	elif room == ROOMS:
		list = []
		_spawn_boss("uwabami")
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

func _spawn_boss(k: String) -> void:
	var b := Boss.new()
	b.setup(k, self)
	if k == "okappa":
		b.position = Vector3(0, 0, -HALF.y + 3.0)
	b.max_hp_mult = float(Worlds.world(current_world).hp_mult)
	add_child(b)
	bosses.append(b)
	sfx.play("strike", 0.5)
	shake = 0.4


func spawn_minions(list: Array) -> void:
	_spawn_list(list)


func boss_killed(_b: Node3D) -> void:
	if _b.kind == "okappa":
		mini_kills += 1
	else:
		boss_kills += 1
	hitstop = 0.3
	shake = 0.7
	sfx.play("kill", 0.6)
	_splash(_b.position, Toon.VERMILION, 30)
	_splash(_b.position, Toon.GOLD, 20)


func small_hit(pos: Vector3) -> void:
	_splash(pos, Toon.VERMILION, 4)
	sfx.play("slash", randf_range(1.2, 1.5), -8.0)


func big_hit(pos: Vector3) -> void:
	hitstop = maxf(hitstop, 0.12)
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
		enemies.append(e)


func _room_cleared() -> void:
	if touching and stroke:
		stroke.queue_free()
		stroke = null
	touching = false
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	if room >= ROOMS:
		_victory()
		return
	_set_state("pick")
	if room == 3 or room == 7:
		_open_sanctuary()
	else:
		_open_upgrades()


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
		_open_upgrades()
		return
	powers.add(id)
	sfx.play("slash", 1.2, -4.0)
	if _extra_picks > 0:
		_extra_picks -= 1
		_open_upgrades()
		return
	elan = elan_max()
	_set_state("play")
	arena.open_gate()
	sfx.play("shot", 1.4, -4.0)


## Passage du torii : un coup de pinceau couvre l'écran, la salle suivante apparaît derrière.
func _transit() -> void:
	_set_state("transit")
	_rebuilt = false
	if touching and stroke:
		stroke.queue_free()
		stroke = null
	touching = false
	hero.stop_dash()
	sfx.play("whoosh", 0.6)


func _rebuild_room() -> void:
	_rebuilt = true
	for e in effects:
		if is_instance_valid(e.node):
			e.node.queue_free()
	effects.clear()
	arena.build_room(room + 1, ROOMS, randi())
	hero.position = arena.start
	_prev_hero = hero.position
	hero.face(Vector3(0, 0, -1))
	hero.snap_facing()
	_begin_room()


func _award(victory: bool) -> void:
	var cleared := room if victory else room - 1
	var g: Dictionary = meta.award_run(cleared, kills, boss_kills, curses.size(), victory, mini_kills)
	meta.record_world(current_world, room, victory)
	menu.gain_sumi = int(g.get("sumi", 0))
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


## Chute dans un trou du ponton : 1 dégât et retour au dernier point sûr.
func _fall() -> void:
	_splash(hero.position, Toon.PRUSSIAN, 18)
	_splash(hero.position, Toon.FOAM, 10)
	sfx.play("strike", 1.4)
	var back := _safe_point
	if hazards.is_hole(back, -0.4):
		back = arena.start
	hero.position = back
	_prev_hero = back
	_hurt_hero()


func drown(e: Node3D) -> void:
	_splash(e.position, Toon.PRUSSIAN, 14)
	damage_enemy(e, 99.0, false)


func wave_hit(push: Vector3) -> void:
	_hurt_hero()
	hero.position = _clamp_point(hero.position + push)
	_prev_hero = hero.position


func _victory() -> void:
	game_over = true
	hud.best_wave = room
	menu.victory = true
	_award(true)
	menu.new_record = room > record
	if room > record:
		record = room
		_save()
	menu.best = record
	hero.invuln = 999.0
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


## Effet de la forme reconnue, déclenché à l'arrivée de la ruée.
func _apply_shape() -> void:
	if _shape.is_empty():
		return
	var sh: Dictionary = _shape
	_shape = {}
	match String(sh.shape):
		"loop":
			# Uzu : tourbillon au centre de la boucle
			var c: Vector3 = sh.center
			fire_ring(c, 1.6)
			_splash(c, Toon.FOAM, 20)
			for o in nearest_enemies(c, 1.6 + 0.5, 99, null):
				damage_enemy(o, 2.0)
		"zigzag":
			# Inazuma : éclair en chaîne sur 4 ennemis
			var from := hero.position
			for o in nearest_enemies(hero.position, 6.0, 4, null):
				zap(from, o.position)
				damage_enemy(o, 1.0)
				from = o.position
		"enso":
			# Ensō : tout ce qui est dans le cercle est frappé
			var c2: Vector3 = sh.center
			var r2: float = sh.radius
			_blot(c2, Color(Toon.VERMILION, 0.25), r2, 1.2)
			for o in nearest_enemies(c2, r2, 99, null):
				damage_enemy(o, 1.5)
				o.push((o.position - c2).normalized() * -3.0)


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


func float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
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

func clamp_to_arena(n: Node3D, r: float) -> void:
	var cp: Vector3 = arena.clamp_walk(n.position, r)
	n.position = Vector3(cp.x, n.position.y, cp.z)
	return


func _clamp_to_bounds(n: Node3D, r: float) -> void:
	n.position.x = clampf(n.position.x, -HALF.x + r, HALF.x - r)
	n.position.z = clampf(n.position.z, -HALF.y + r, HALF.y - r)


func _clamp_point(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -HALF.x + 0.3, HALF.x - 0.3), 0, clampf(p.z, -HALF.y + 0.3, HALF.y - 0.3))


# ------------------------------------------------------------------ entrée

func _input(event: InputEvent) -> void:
	# tactile (téléphone) et souris (ordinateur) ; la souris émulée depuis le tactile sert aux boutons du menu
	if state != "play" and state != "intro":
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
	if game_over:
		if hud.over_t > 1.0:
			_start()
		return
	touching = true
	touch_start = _ground(sp)
	origin = hero.dash_end()
	stroke_layer += 1
	stroke = InkStroke.new(origin, stroke_layer)
	add_child(stroke)


func _touch_move(sp: Vector2) -> void:
	if not touching or stroke == null:
		return
	var target := _clamp_point(origin + (_ground(sp) - touch_start) * REL)
	var was_empty: bool = stroke.exhausted
	var used: float = stroke.extend_to(target, elan)
	elan -= used
	stroke.danger = is_danger(stroke.last(), stroke.length / Hero.DASH_SPEED)
	if stroke.exhausted and not was_empty:
		sfx.play("empty", 0.8)


func _touch_up(sp: Vector2) -> void:
	if not touching:
		return
	touching = false
	if stroke == null:
		return
	if stroke.length >= 0.7:
		_launch(stroke)
	else:
		# petit coup de doigt : bond d'esquive
		var flick := (_ground(sp) - touch_start) * REL
		flick.y = 0
		if flick.length() > 0.12 and elan >= powers.dodge_cost(DODGE_COST):
			var s: MeshInstance3D = stroke
			var dd: float = powers.dodge_dist(DODGE_DIST)
			var end := _clamp_point(origin + flick.normalized() * dd)
			s.extend_to(end, dd)
			elan -= powers.dodge_cost(DODGE_COST)
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
	_prev_hero = hero.position
	hero.speed_mult = powers.dash_mult()
	_safe_point = s.points[0]
	powers.on_stroke_release(s.points)
	_shape = StrokeShapes.detect(s.points) if s.length >= 2.0 else {}
	if not _shape.is_empty():
		shape_text(s.last(), String(SHAPE_KANJI.get(_shape.shape, "")))
		sfx.play("whoosh", 0.7)
		if _shape.shape == "straight":
			hero.speed_mult *= 1.3
		elif _shape.shape == "return":
			_reflect_bullets(s.points)
	sfx.play("whoosh", randf_range(0.9, 1.1))


func _on_dash_finished() -> void:
	if dash_stroke and is_instance_valid(dash_stroke):
		dash_stroke.start_drying()
	dash_stroke = null
	_apply_shape()
	if hazards.is_hole(hero.position):
		_fall()
	for bo in bosses:
		if is_instance_valid(bo):
			bo.end_stroke(stroke_id)
	powers.on_dash_end(hero.position, _stroke_kills)
	if combo >= 3:
		elan = elan_max()


# ------------------------------------------------------------------ combat

func spawn_bullet(pos: Vector3, dir: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	Toon.part(n, Toon.sphere(0.3), Toon.mat(Toon.VERMILION, true, 0.05), Vector3.ZERO)
	Toon.part(n, Toon.sphere(0.13), Toon.mat(Toon.WASHI, false), Vector3(0, 0.12, -0.12))
	var shadow := Toon.disc(n, 0.26, Color(0, 0, 0, 0.2))
	shadow.position.y = -pos.y + 0.012
	bullets.append({"node": n, "vel": dir * 3.4, "life": 7.0})
	sfx.play("shot", randf_range(0.9, 1.1), -6.0)


func take_token(e: Node) -> bool:
	for i in range(_attackers.size() - 1, -1, -1):
		if not is_instance_valid(_attackers[i]) or _attackers[i].dead:
			_attackers.remove_at(i)
	if e in _attackers:
		return true
	if _attackers.size() >= attack_tokens:
		return false
	_attackers.append(e)
	return true


func free_token(e: Node) -> void:
	_attackers.erase(e)


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
		if not is_instance_valid(bo):
			continue
		var bz: Array = bo.danger_zone()
		if bz.size() == 3:
			var bc: Vector3 = bz[0]
			if Vector2(p.x - bc.x, p.z - bc.z).length() < float(bz[1]) + 0.35 and float(bz[2]) < eta + 0.35:
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


func _hurt_hero() -> void:
	if hero.dashing or hero.invuln > 0.0 or game_over:
		return
	hero.hurt()
	hud.hurt_flash = 1.0
	shake = 0.45
	hitstop = 0.12
	sfx.play("hurt")
	_splash(hero.position, Toon.SUMI, 14)
	if hero.hp <= 0:
		game_over = true
		hud.best_wave = room
		menu.victory = false
		_award(false)
		menu.new_record = room > record
		if room > record:
			record = room
			_save()
		menu.best = record
		_set_state("over")
		touching = false
		if stroke:
			stroke.queue_free()
			stroke = null


func _check_slashes() -> void:
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
				float_text(p, "×0", Toon.FOAM)
				hero.stop_dash()
				continue
			if piercing:
				dmg *= 1.5
			dmg = powers.on_hit(e, dmg, dir)
			var killed: bool = e.take_hit(dmg, dir)
			if killed:
				kills += 1
				_stroke_kills += 1
				powers.on_kill(e)
			elan = minf(elan_max(), elan + ELAN_PER_HIT)
			hitstop = maxf(hitstop, 0.085 if killed else 0.06)
			shake = maxf(shake, 0.28 if killed else 0.18)
			sfx.play("kill" if killed else "slash", 1.0 + 0.08 * (combo - 1) + randf_range(-0.04, 0.04))
			_splash(p, Toon.VERMILION, 18 if killed else 10)
			_blot(p, Toon.VERMILION, randf_range(0.35, 0.6) * (1.6 if e.kind == "brute" else 1.0), 2.5)
			_slash_mark(p, dir)
			if combo >= 2:
				_combo_label(p, combo)
	for bo in bosses:
		if not is_instance_valid(bo):
			continue
		if bo.check_dash(a, b, stroke_id):
			combo += 1
			var bd := 1.0 * (1.0 + 0.5 * (combo - 1))
			var bdir: Vector3 = seg if seg.length_squared() > 0.0001 else hero.facing
			bo.take_hit(bd, bdir)
			elan = minf(elan_max(), elan + ELAN_PER_HIT)
			hitstop = maxf(hitstop, 0.07)
			shake = maxf(shake, 0.22)
			sfx.play("slash", 0.85 + 0.08 * (combo - 1))
			_splash(bo.position + Vector3(0, 0.6, 0), Toon.VERMILION, 12)
			_slash_mark(bo.position, bdir)


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
	var m := Toon.sphere(0.07)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = color
	m.material = mt
	p.mesh = m
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
	var main_disc := Toon.disc(n, r, color, 0.015)
	main_disc.scale = Vector3(1.0, 1, randf_range(0.7, 1.0))
	main_disc.rotation.y = randf() * TAU
	var mats: Array = [main_disc.material_override]
	for i in 4:
		var a := randf() * TAU
		var dd := Toon.disc(n, r * randf_range(0.12, 0.25), color, 0.016)
		dd.position += Vector3(cos(a), 0, sin(a)) * r * randf_range(1.1, 1.8)
		mats.append(dd.material_override)
	effects.append({"node": n, "t": 0.0, "life": life, "kind": "fade", "mats": mats, "alpha": color.a})


func _slash_mark(pos: Vector3, dir: Vector3) -> void:
	# éclair blanc en travers de l'ennemi : le « tranchant »
	var n := Node3D.new()
	add_child(n)
	n.position = pos + Vector3(0, 0.7, 0)
	var d := dir.normalized()
	n.rotation.y = atan2(-d.x, -d.z) + randf_range(-0.5, 0.5)
	var bar := Toon.part(n, Toon.box(Vector3(0.09, 0.03, 2.2)), Toon.flat(Color(1, 1, 1, 0.95)), Vector3.ZERO)
	bar.rotation.x = randf_range(-0.4, 0.4)
	effects.append({"node": n, "t": 0.0, "life": 0.18, "kind": "slash", "mats": [bar.material_override], "alpha": 0.95})


func _combo_label(pos: Vector3, n: int) -> void:
	var l := Label3D.new()
	l.text = "×%d" % n
	l.font_size = 120 + 12 * mini(n, 6)
	l.pixel_size = 0.006
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

	# temps : arrêt sur image > normal (plus de ralenti quand le doigt est posé)
	var target := 1.0
	if hitstop > 0.0:
		hitstop -= real
		target = 0.02
	elif game_over:
		target = 0.35
	if target < Engine.time_scale and target != 0.02:
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
	if state == "play":
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
	elif shake > 0.0:
		shake = maxf(0.0, shake - real * 1.6)
		var s := shake * shake * 1.2
		cam.global_transform = _cam_base.translated(Vector3(randf_range(-s, s), randf_range(-s, s) * 0.5, randf_range(-s, s)))
	else:
		cam.global_transform = _cam_base

	hud.hp = hero.hp
	hud.max_hp = hero.max_hp
	hud.elan = elan / elan_max()
	if touching and stroke != null:
		stroke.danger = is_danger(stroke.last(), stroke.length / Hero.DASH_SPEED)
	hud.elan_empty = touching and stroke != null and stroke.exhausted
	hud.wave = maxi(wave, 1)
	hud.wave_index = wave_index
	hud.waves_total = waves_total
	hud.show_waves = state == "play" and room > 0 and not _room_done
	hud.gate_hint = arena.gate_open and state == "play"
	hud.slow = 0.0
	hud.game_over = game_over
	hud.boss_name = ""
	for bo in bosses:
		if is_instance_valid(bo) and not bo.dead:
			hud.boss_name = bo.title
			hud.boss_ratio = clampf(bo.hp / bo.max_hp, 0.0, 1.0)
