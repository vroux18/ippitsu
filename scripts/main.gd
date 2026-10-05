extends Node3D
## Boucle du prototype : un doigt posé = ralenti, on trace, on lâche = ruée qui tranche.

const Toon = preload("res://scripts/toon.gd")
const Hero = preload("res://scripts/hero.gd")
const Enemy = preload("res://scripts/enemy.gd")
const InkStroke = preload("res://scripts/ink_stroke.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Hud = preload("res://scripts/hud.gd")
const Menu = preload("res://scripts/menu.gd")
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

var elan := ELAN_MAX
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
var safety := true
var game_over := false
var _ticks := 0
var _cam_base := Transform3D()

var state := "menu"  # menu | intro | play | over
var menu: Control
var record := 0
var _state_t := 0.0
var _menu_slash := 3.0
var _water_mat: StandardMaterial3D


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
	_load()
	get_viewport().size_changed.connect(_fit_camera)
	_start()
	# `-- --autoplay` : démarre directement en jeu (vérification automatique du CI)
	_set_state("play" if "--autoplay" in OS.get_cmdline_user_args() else "menu")
	_ticks = Time.get_ticks_usec()


# ------------------------------------------------------------------ états

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		record = int(cfg.get_value("game", "best", 0))
		menu.muted = bool(cfg.get_value("game", "muted", false))
	menu.best = record
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
		_set_state("intro")


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

	# l'eau tout autour (bleu de Prusse) et ses rides d'écume
	# eau : bleu de Prusse, reflets animés (normal map de bruit qui défile)
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Toon.PRUSSIAN
	_water_mat.roughness = 0.25
	_water_mat.metallic_specular = 0.7
	var noise := FastNoiseLite.new()
	noise.frequency = 0.035
	var ntex := NoiseTexture2D.new()
	ntex.noise = noise
	ntex.seamless = true
	ntex.as_normal_map = true
	ntex.bump_strength = 6.0
	ntex.width = 256
	ntex.height = 256
	_water_mat.normal_enabled = true
	_water_mat.normal_texture = ntex
	_water_mat.normal_scale = 0.6
	_water_mat.uv1_scale = Vector3(60, 60, 1)
	var water := Toon.part(world, Toon.box(Vector3(600, 0.1, 600)), _water_mat, Vector3(0, -0.6, 0))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.name = "water"
	var foam_mat := Toon.mat(Toon.FOAM, false)
	for i in 90:
		var far := i >= 50
		var foam := Toon.part(world, Toon.box(Vector3(randf_range(0.6, 2.2) * (3.0 if far else 1.0), 0.02, 0.07 * (2.0 if far else 1.0))), foam_mat,
			Vector3(randf_range(-9, 9) * (3.0 if far else 1.0), -0.54, randf_range(-14, 14) if not far else randf_range(-70, -12)))
		if absf(foam.position.x) < HALF.x + 0.8 and absf(foam.position.z) < HALF.y + 0.8:
			foam.position.x += signf(foam.position.x + 0.01) * (HALF.x + 1.5)

	# au loin : le Fuji, le soleil vermillon et des bancs de brume (vus depuis l'accueil)
	var fuji := Toon.flat(Color("#5D7392"))
	fuji.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	Toon.part(world, Toon.cyl(2.0, 46.0, 26.0, 48), fuji, Vector3(-18, 12.4, -170))
	var snow := Toon.flat(Toon.FOAM)
	snow.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	Toon.part(world, Toon.cyl(2.05, 12.5, 7.0, 48), snow, Vector3(-18, 21.9, -169.6))
	var sun_mat := Toon.flat(Toon.VERMILION)
	sun_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	Toon.part(world, Toon.sphere(11.0), sun_mat, Vector3(26, 26, -230))
	var mist := Toon.flat(Color(Toon.WASHI, 0.85))
	Toon.part(world, Toon.box(Vector3(140, 1.6, 0.1)), mist, Vector3(-30, 6.0, -150))
	Toon.part(world, Toon.box(Vector3(90, 1.1, 0.1)), mist, Vector3(30, 10.5, -160))

	# le ponton : grande plateforme de bois clair, planches et bord d'encre
	var deck := Vector2(HALF.x + 0.5, HALF.y + 0.5)
	# structure sombre sous les planches (visible dans les jointures)
	Toon.part(world, Toon.box(Vector3(deck.x * 2, 0.46, deck.y * 2)), Toon.mat(Color("#5B4630"), false), Vector3(0, -0.27, 0))
	# planches : teintes et longueurs variées, joints décalés
	var woods := [Color("#C9AE7C"), Color("#BFA171"), Color("#D0B686"), Color("#B99B6B"), Color("#C5A978")]
	var wood_mats := []
	for wc in woods:
		var wm := Toon.mat(wc, false)
		wm.rim_enabled = false
		wm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		wood_mats.append(wm)
	var pw := 0.62
	var count := int(deck.x * 2 / pw)
	for i in count:
		var px := -deck.x + pw * (i + 0.5)
		var z0 := -deck.y
		while z0 < deck.y - 0.01:
			var l := minf(randf_range(2.6, 5.5), deck.y - z0)
			var pl := Toon.part(world, Toon.box(Vector3(pw - 0.035, 0.09, l - 0.03)), wood_mats[randi() % wood_mats.size()],
				Vector3(px, -0.045 + randf_range(-0.006, 0.006), z0 + l / 2.0))
			pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			z0 += l
	var edge := Toon.mat(Toon.SUMI, false)
	Toon.part(world, Toon.box(Vector3(deck.x * 2 + 0.1, 0.56, 0.1)), edge, Vector3(0, -0.25, deck.y))
	Toon.part(world, Toon.box(Vector3(deck.x * 2 + 0.1, 0.56, 0.1)), edge, Vector3(0, -0.25, -deck.y))
	Toon.part(world, Toon.box(Vector3(0.1, 0.56, deck.y * 2)), edge, Vector3(deck.x, -0.25, 0))
	Toon.part(world, Toon.box(Vector3(0.1, 0.56, deck.y * 2)), edge, Vector3(-deck.x, -0.25, 0))
	# pieux
	var post := Toon.mat(Color("#5B4630"))
	for sx in [-1.0, 1.0]:
		for k in 5:
			var z := lerpf(-deck.y, deck.y, k / 4.0)
			Toon.part(world, Toon.cyl(0.14, 0.14, 0.9), post, Vector3(sx * (deck.x + 0.05), -0.3, z))

	# torii vermillon au fond de l'arène
	var red := Toon.mat(Toon.VERMILION)
	var black := Toon.mat(Toon.SUMI)
	var tz := -deck.y - 0.2
	Toon.part(world, Toon.cyl(0.16, 0.19, 3.2), red, Vector3(-2.2, 1.6, tz))
	Toon.part(world, Toon.cyl(0.16, 0.19, 3.2), red, Vector3(2.2, 1.6, tz))
	Toon.part(world, Toon.box(Vector3(5.2, 0.22, 0.28)), red, Vector3(0, 2.6, tz))
	Toon.part(world, Toon.box(Vector3(6.2, 0.26, 0.42)), black, Vector3(0, 3.25, tz))
	Toon.part(world, Toon.box(Vector3(0.3, 0.6, 0.2)), red, Vector3(0, 2.95, tz))

	# lanternes de pierre aux coins proches
	var stone := Toon.mat(Color("#9C978C"))
	for sx in [-1.0, 1.0]:
		var base := Vector3(sx * (deck.x - 0.45), 0, deck.y - 0.45)
		Toon.part(world, Toon.cyl(0.18, 0.24, 0.5), stone, base + Vector3(0, 0.25, 0))
		Toon.part(world, Toon.box(Vector3(0.42, 0.32, 0.42)), stone, base + Vector3(0, 0.66, 0))
		Toon.part(world, Toon.box(Vector3(0.22, 0.16, 0.44)), Toon.mat(Toon.GOLD, false), base + Vector3(0, 0.66, 0))
		Toon.part(world, Toon.cyl(0.0, 0.38, 0.28, 4), stone, base + Vector3(0, 0.96, 0))


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
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	if hero:
		hero.queue_free()
	hero = Hero.new()
	add_child(hero)
	hero.position = Vector3(0, 0, HALF.y - 2.5)
	hero.dash_finished.connect(_on_dash_finished)
	_prev_hero = hero.position
	elan = ELAN_MAX
	wave = 0
	wave_wait = 0.8
	game_over = false
	touching = false
	hud.game_over = false
	hud.over_t = 0.0
	hitstop = 0.0
	shake = 0.0
	Engine.time_scale = 1.0
	_fit_camera()


func _spawn_wave() -> void:
	wave += 1
	safety = true
	var oni := 1 + wave
	var kappa := 0 if wave < 2 else (wave) / 2
	var brute := 0 if wave < 3 else (wave - 1) / 2
	var list := []
	for i in oni:
		list.append("oni")
	for i in kappa:
		list.append("kappa")
	for i in brute:
		list.append("brute")
	for k in list:
		var e := Enemy.new()
		e.setup(k, hero, self)
		var p := Vector3.ZERO
		for attempt in 30:
			p = Vector3(randf_range(-HALF.x + 0.8, HALF.x - 0.8), 0, randf_range(-HALF.y + 0.8, HALF.y - 3.0))
			if p.distance_to(hero.position) > 4.5:
				break
		e.position = p
		add_child(e)
		enemies.append(e)


func clamp_to_arena(n: Node3D, r: float) -> void:
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
		if flick.length() > 0.12 and elan >= DODGE_COST:
			var s: MeshInstance3D = stroke
			var end := _clamp_point(origin + flick.normalized() * DODGE_DIST)
			s.extend_to(end, DODGE_DIST)
			elan -= DODGE_COST
			_launch(s)
		else:
			elan = minf(ELAN_MAX, elan + stroke.length)
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
	_prev_hero = hero.position
	sfx.play("whoosh", randf_range(0.9, 1.1))


func _on_dash_finished() -> void:
	if dash_stroke and is_instance_valid(dash_stroke):
		dash_stroke.start_drying()
	dash_stroke = null
	if combo >= 3:
		elan = ELAN_MAX


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
		hud.best_wave = wave
		menu.new_record = wave > record
		if wave > record:
			record = wave
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
			var killed: bool = e.take_hit(dmg, dir)
			elan = minf(ELAN_MAX, elan + ELAN_PER_HIT)
			hitstop = maxf(hitstop, 0.085 if killed else 0.06)
			shake = maxf(shake, 0.28 if killed else 0.18)
			sfx.play("kill" if killed else "slash", 1.0 + 0.08 * (combo - 1) + randf_range(-0.04, 0.04))
			_splash(p, Toon.VERMILION, 18 if killed else 10)
			_blot(p, Toon.VERMILION, randf_range(0.35, 0.6) * (1.6 if e.kind == "brute" else 1.0), 2.5)
			_slash_mark(p, dir)
			if combo >= 2:
				_combo_label(p, combo)


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
		if safety and d < 1.0 and not hero.dashing and hero.invuln <= 0.0 and not touching and not game_over:
			var v: Vector3 = b.vel
			var side := Vector3(-v.z, 0, v.x).normalized()
			if side.dot(hero.position - hp) < 0:
				side = -side
			safety = false
			var step := PackedVector3Array([hero.position, _clamp_point(hero.position + side * 1.3)])
			hero.start_dash(step)
		if d < 0.3 + Hero.RADIUS and not hero.dashing and hero.invuln <= 0.0:
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
		elan = minf(ELAN_MAX, elan + ELAN_REGEN * real)

	_check_slashes()
	_update_bullets(dt)
	_update_effects(dt, real)

	# nettoyage et vagues
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]):
			enemies.remove_at(i)
	_state_t += real
	_water_mat.uv1_offset += Vector3(0.0035, 0.0018, 0) * real
	if state == "play" and enemies.is_empty():
		wave_wait -= real
		if wave_wait <= 0.0:
			_spawn_wave()
			wave_wait = 1.2

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
	hud.elan = elan / ELAN_MAX
	hud.elan_empty = touching and stroke != null and stroke.exhausted
	hud.wave = maxi(wave, 1)
	hud.slow = 0.0
	hud.game_over = game_over
