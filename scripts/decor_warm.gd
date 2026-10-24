extends Node
## Préchauffage du décor des mondes : en Godot 4 (rendu compatibilité), le shader d'une matière ne se compile
## qu'à son premier dessin, et chaque façon de la dessiner compte (éclairée ou non par une lanterne, ombre portée,
## MultiMesh…). Sans ce préchauffage, le premier sanctuaire ou la première étape d'un monde figeait l'image le
## temps de compiler tout son décor (à-coups de 40 à 70 ms au lever du rideau, sur téléphone).
## Ici, monde après monde, un échantillon complet de son décor est construit loin de tout (étape avec ses haies,
## son torii allumé, ses fosses et toutes ses pièces de décor ; sanctuaire ; arènes du gardien et du boss ; lointain,
## particules, rayons et eau) et dessiné quelques images dans une petite SubViewport qui partage le monde 3D du
## jeu (mêmes lumières, même brume, mêmes ombres), d'abord sous une lumière ponctuelle, puis sans : les deux
## variantes de chaque shader sont prêtes. Rien n'est visible (la SubViewport n'est affichée nulle part).
## La construction est étalée (DecorWarm.SLICE_US par image) et s'efface devant les chargements du jeu ; le monde
## en cours passe en premier ; main._intro_swap attend sous le rideau le monde choisi s'il n'est pas encore prêt.

const Arena = preload("res://scripts/arena.gd")
const Worlds = preload("res://scripts/worlds.gd")
const Perf = preload("res://scripts/perf_probe.gd")
const Gfx = preload("res://scripts/graphismes.gd")
const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

const SLICE_US := 3000  # calcul par image, accueil et jeu (µs)
const WAIT_SLICE_US := 6000  # … quand l'intro attend ce monde sous le rideau
const FAR := Vector3(20000.0, 0.0, 0.0)  # loin de tout : jamais dans le champ de la caméra du jeu
const SCALE := 0.004  # échantillon réduit : tout tient devant la caméra de préchauffage
const LIT_FRAMES := 3  # images dessinées sous la lumière ponctuelle, puis autant sans

signal world_done(id: int)

var main: Node
var done := {}  # monde -> true (décor dessiné)
var busy := false  # un monde est en cours
var current := -1  # monde en cours de préchauffage (-1 : aucun ; 0 : le Sentier)
var budget := SLICE_US
var _queue: Array = []
var _sv: SubViewport
var _cam: Camera3D
var _t0 := 0
var cpu_us := 0  # calcul total (mesure)
var frame_max_us := 0  # plus longue tranche (mesure)
var _bake: Thread = null  # bruits et grain des matières (toon.gd), calculés hors du fil principal
var _bake_out: Array = []


func _ready() -> void:
	# textures des matières : bruits et grain sur un fil (≈ 150 ms de calcul), atlas des marques au sol dans une
	# SubViewport (kanji au pinceau : il faut un écran) ; toutes les matières partagent déjà les objets textures
	_bake = Thread.new()
	_bake.start(_bake_run)
	_paint_decals.call_deferred()
	_sv = SubViewport.new()
	_sv.name = "DecorWarmView"
	_sv.size = Vector2i(96, 96)
	_sv.world_3d = main.get_viewport().world_3d  # le monde du jeu : ses lumières, sa brume, ses ombres
	_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sv)
	_cam = Camera3D.new()
	_cam.fov = 150.0
	_cam.near = 0.01
	_cam.far = 60.0
	_sv.add_child(_cam)
	_cam.global_transform = Transform3D(Basis(), FAR + Vector3(0, 2.6, 0.9)).looking_at(FAR, Vector3(0, 0, -1))
	_cam.current = true


func _bake_run() -> void:
	_bake_out = Toon.bake_noise_images()


func _process(_delta: float) -> void:
	if _bake != null and not _bake.is_alive():
		_bake.wait_to_finish()
		_bake = null
		if _bake_out.size() == 2:
			Toon.set_noise_images(_bake_out)
		_bake_out = []


func _exit_tree() -> void:
	if _bake != null:
		_bake.wait_to_finish()
		_bake = null


## Atlas des marques au sol (Toon.decal_tex) : 16 cases de 256 px, blanc = encre. Rangée 0-2 : kanji des mondes
## (波 竹 雪 火 墨 天 龍 冥 道 水 山) au pinceau (Shippori Mincho) ; puis seigaiha, asanoha, auréole d'eau,
## éclaboussure, griffures. Peint une fois dans une SubViewport, converti en L8 avec mipmaps, la vue libérée.
func _paint_decals() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sv := SubViewport.new()
	sv.size = Vector2i(Toon.DECAL_PX, Toon.DECAL_PX)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	sv.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	sv.disable_3d = true
	var c := DecalPainter.new()
	c.size = Vector2(sv.size)
	sv.add_child(c)
	add_child(sv)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	if img == null or img.is_empty() or img.get_width() < 64:
		return
	img.convert(Image.FORMAT_L8)
	img.generate_mipmaps()
	Toon.decal_tex().set_image(img)


## Peintre de l'atlas : traits blancs sur noir (voir _paint_decals).
class DecalPainter extends Control:
	const KANJI := ["波", "竹", "雪", "火", "墨", "天", "龍", "冥", "道", "水", "山"]

	func _draw() -> void:
		var cell := float(Toon.DECAL_PX) / 4.0
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		var font: Font = UiKit.TITLE_FONT
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in KANJI.size():
			var o := Vector2(float(i % 4), float(i / 4)) * cell
			# kanji au pinceau : le glyphe, puis deux copies à peine décalées (bord qui bave), des éclats de pointe sèche
			var fs := int(cell * 0.72)
			var w := font.get_string_size(KANJI[i], HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var pos := o + Vector2((cell - w) * 0.5, cell * 0.5 + fs * 0.36)
			for k in 3:
				var d := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0)) if k > 0 else Vector2.ZERO
				draw_string(font, pos + d, KANJI[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 1.0 if k == 0 else 0.5))
			for k in 6:
				var p := o + Vector2(rng.randf_range(cell * 0.15, cell * 0.85), rng.randf_range(cell * 0.15, cell * 0.85))
				draw_circle(p, rng.randf_range(1.5, 4.0), Color(1, 1, 1, 0.8))
		# 11 : seigaiha (éventails de trois arcs, rangées décalées)
		var o11 := Vector2(3.0, 2.0) * cell
		var r := cell / 6.0
		for row in 8:
			var y := o11.y + float(row) * r * 0.5 + r
			var off := r if row % 2 == 1 else 0.0
			for col in 5:
				var cx := o11.x + off + float(col) * 2.0 * r - r
				for a in 3:
					var rr := r * (1.0 - 0.3 * float(a))
					_arc_clip(Vector2(cx, y), rr, 3.0, Rect2(o11, Vector2(cell, cell)))
		# 12 : asanoha (étoiles de chanvre : hexagones et leurs diagonales)
		var o12 := Vector2(0.0, 3.0) * cell
		var s := cell / 4.0
		var h := s * sqrt(3.0) * 0.5
		for j in 7:
			for i in 6:
				var cx := o12.x + float(i) * 2.0 * h + (h if j % 2 == 1 else 0.0)
				var cy := o12.y + float(j) * s * 1.5
				var c := Vector2(cx, cy)
				var pts: Array = []
				for k in 6:
					var ang := PI / 6.0 + float(k) * PI / 3.0
					pts.append(c + Vector2(cos(ang), sin(ang)) * s)
				for k in 6:
					_seg_clip(pts[k], pts[(k + 1) % 6], 2.6, Rect2(o12, Vector2(cell, cell)))
					_seg_clip(c, pts[k], 2.0, Rect2(o12, Vector2(cell, cell)))
		# 13 : auréole d'eau (anneau irrégulier, plus épais d'un côté)
		var o13 := Vector2(1.0, 3.0) * cell
		var cc := o13 + Vector2(cell, cell) * 0.5
		for k in 72:
			var a0 := float(k) / 72.0 * TAU
			var a1 := float(k + 1) / 72.0 * TAU
			var rad := cell * 0.36 * (1.0 + 0.05 * sin(a0 * 3.0) + 0.03 * sin(a0 * 7.0 + 1.0))
			var th := 3.0 + 6.0 * maxf(0.0, cos(a0 - 0.8))
			draw_line(cc + Vector2(cos(a0), sin(a0)) * rad, cc + Vector2(cos(a1), sin(a1)) * rad, Color(1, 1, 1, 0.75), th, true)
		# 14 : éclaboussure d'encre (tache et gouttes projetées)
		var o14 := Vector2(2.0, 3.0) * cell
		var sc := o14 + Vector2(cell, cell) * 0.5
		var blob := PackedVector2Array()
		for k in 40:
			var a := float(k) / 40.0 * TAU
			var rad := cell * 0.17 * (1.0 + 0.25 * sin(a * 5.0 + 0.4) + 0.12 * sin(a * 11.0))
			blob.append(sc + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(blob, Color.WHITE)
		for k in 14:
			var a := rng.randf() * TAU
			var d := rng.randf_range(cell * 0.2, cell * 0.44)
			var p := sc + Vector2(cos(a), sin(a)) * d
			var rr := rng.randf_range(2.0, 9.0)
			draw_circle(p, rr, Color.WHITE)
			draw_line(sc + Vector2(cos(a), sin(a)) * (d - rr * 3.0), p, Color.WHITE, rr * 0.5, true)
		# 15 : griffures (quatre traits rapides, parallèles, effilés)
		var o15 := Vector2(3.0, 3.0) * cell
		for k in 4:
			var a := o15 + Vector2(cell * 0.25 + float(k) * cell * 0.13, cell * 0.18 + float(k) * 6.0)
			var b := a + Vector2(cell * 0.12, cell * 0.6)
			for t in 12:
				var f0 := float(t) / 12.0
				var f1 := float(t + 1) / 12.0
				draw_line(a.lerp(b, f0), a.lerp(b, f1), Color(1, 1, 1, 0.9), 2.0 + 5.0 * sin(PI * f0), true)

	## Arc de cercle (encre pleine), coupé au bord de la case.
	func _arc_clip(c: Vector2, rad: float, th: float, clip: Rect2) -> void:
		var pts := PackedVector2Array()
		for k in 25:
			var a := PI + float(k) / 24.0 * PI
			var p := c + Vector2(cos(a), sin(a)) * rad
			pts.append(Vector2(clampf(p.x, clip.position.x, clip.end.x), clampf(p.y, clip.position.y, clip.end.y)))
		draw_polyline(pts, Color.WHITE, th, true)

	func _seg_clip(a: Vector2, b: Vector2, th: float, clip: Rect2) -> void:
		var pa := Vector2(clampf(a.x, clip.position.x, clip.end.x), clampf(a.y, clip.position.y, clip.end.y))
		var pb := Vector2(clampf(b.x, clip.position.x, clip.end.x), clampf(b.y, clip.position.y, clip.end.y))
		if pa.distance_to(pb) < 1.0:
			return
		draw_line(pa, pb, Color.WHITE, th, true)


## Monde `id` à préchauffer (en tête de file si `first`).
func want(id: int, first := false) -> void:
	if done.has(id) or id == current or id < 0:
		return
	_queue.erase(id)
	if first:
		_queue.push_front(id)
	else:
		_queue.append(id)
	if not busy:
		_run()


## Attend que le monde `id` soit prêt (sous le rideau de l'intro : budget plus large).
func ensure(id: int) -> void:
	if done.has(id):
		return
	want(id, true)
	budget = WAIT_SLICE_US
	while not done.has(id):
		await world_done
	budget = SLICE_US


func _run() -> void:
	busy = true
	while not _queue.is_empty():
		var id: int = _queue.pop_front()
		if done.has(id):
			continue
		current = id
		await _warm_world(id)
		current = -1
		done[id] = true
		world_done.emit(id)
	busy = false
	# mesures : calcul total du préchauffage du décor (hors images d'attente) et sa plus longue tranche
	main.perf_mark("decor_warm", cpu_us)
	main.perf_mark("decor_warm_frame_max", frame_max_us)


## Le jeu construit une salle (rideau, décor différé) : le préchauffage attend son tour.
func _hold() -> bool:
	return bool(main.get("_loading")) or bool(main.arena.slicing())


## Découpe : au-delà du budget de l'image, on attend l'image suivante (et la fin d'un chargement du jeu).
func _cut() -> void:
	var spent := Time.get_ticks_usec() - _t0
	if spent < budget:
		return
	cpu_us += spent
	frame_max_us = maxi(frame_max_us, spent)
	await get_tree().process_frame
	while _hold():
		await get_tree().process_frame
	_t0 = Time.get_ticks_usec()


func _warm_world(id: int) -> void:
	while _hold():
		await get_tree().process_frame
	_t0 = Time.get_ticks_usec()
	var holder := Node3D.new()
	holder.set_meta("warm", true)  # (relevé --shadercheck : ces matières comptent comme vues, sans être signalées)
	_sv.add_child(holder)
	holder.global_position = FAR
	holder.scale = Vector3.ONE * SCALE
	var cut := Callable(self, "_cut")
	var seed_i := 7700 + id * 31
	# lointain du monde (comme arena.set_world, sans toucher au monde du jeu) : eau, décor peint, particules, rayons
	var far := Node3D.new()
	holder.add_child(far)
	_water(far, id)
	await _cut()
	await Worlds.build_backdrop(id, far, cut)
	await _cut()
	Worlds.build_particles(id, far)
	Worlds.build_rays(id, far)
	await _cut()
	# étape (assez avancée pour ses pièces de décor) : sol, bords, haies dressées, torii allumé, fosses, décor
	var st := _arena(holder, id, Vector3(0, 0, 0))
	st.set("_stage_n", 3)
	await _arena_build(st, "stage", seed_i)
	st.begin_zone(0)  # (toutes les haies dressées)
	st.open_gate()
	# toutes les pièces de décor du monde
	var pcs: Array = []
	var x := -20.0
	for kd in Worlds.set_piece_kinds(id):
		var ka: Array = kd
		pcs.append([Rect2(Vector2(x, 40.0), Vector2(float(ka[1]), float(ka[2]))), String(ka[0]), false])
		x += float(ka[1]) + 1.0
	if not pcs.is_empty():
		var pn := Node3D.new()
		holder.add_child(pn)
		await Worlds.build_props(id, pn, [Rect2(-4.6, -8.6, 9.2, 17.2)], seed_i + 1, Rect2(), 1, pcs, false, cut)
	# sanctuaire du monde (arrivée, décor dans l'eau, torii ouvert), arènes du gardien et du boss
	var hub := _arena(holder, id, Vector3(60, 0, 0))
	await _arena_build(hub, "hub", seed_i + 2)
	hub.open_gate()
	await _arena_build(_arena(holder, id, Vector3(120, 0, 0)), "mini", seed_i + 3)
	await _arena_build(_arena(holder, id, Vector3(180, 0, 0)), "boss", seed_i + 4)
	var spent := Time.get_ticks_usec() - _t0
	cpu_us += spent
	frame_max_us = maxi(frame_max_us, spent)
	# dessin : d'abord sous une lumière ponctuelle (variante « lanterne » de chaque shader), puis sans
	var lamp := OmniLight3D.new()
	lamp.omni_range = 200.0
	lamp.light_energy = 0.4
	lamp.shadow_enabled = Gfx.is_zinzin()  # ZINZIN : la variante « ombre ponctuelle » des shaders aussi
	_sv.add_child(lamp)
	lamp.global_position = FAR + Vector3(0, 1.0, 0)
	var lights: Array = holder.find_children("*", "OmniLight3D", true, false)
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for f in LIT_FRAMES * 2:
		if f == LIT_FRAMES:
			lamp.visible = false
			for l in lights:
				(l as Node3D).visible = false
		await get_tree().process_frame
	_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	lamp.queue_free()
	holder.queue_free()
	if Perf.on:
		print("PERF préchauffage du décor : monde %d prêt" % id)


## Construction étalée d'une arène d'échantillon, sur une image neuve, au budget du préchauffage ; puis son
## décor différé (tronçons lointains de l'étape), qu'on attend.
func _arena_build(a: Node3D, kind: String, seed_i: int) -> void:
	await _fresh()
	a.begin_slices(budget)
	match kind:
		"stage":
			await a.build_stage(4, seed_i, false, true)
		"hub":
			await a.build_hub(seed_i, true)
		"mini":
			await a.build_room(8, 15, seed_i, 8, true)
		_:
			await a.build_room(15, 15, seed_i, 8, true)
	a.end_slices()
	cpu_us += int(a.get("slice_cpu"))
	frame_max_us = maxi(frame_max_us, int(a.get("slice_max")))
	while not (a.get("_pending") as Array).is_empty() or bool(a.get("_draining")):
		await get_tree().process_frame
	_t0 = Time.get_ticks_usec()


## Image neuve (et pas pendant un chargement du jeu) : la tranche en cours est comptée.
func _fresh() -> void:
	var spent := Time.get_ticks_usec() - _t0
	cpu_us += spent
	frame_max_us = maxi(frame_max_us, spent)
	await get_tree().process_frame
	while _hold():
		await get_tree().process_frame
	_t0 = Time.get_ticks_usec()


## Arène d'échantillon (arena.gd) posée dans `holder` : elle ne touche à rien du jeu (ni au monde affiché,
## ni à la teinte des énigmes) ; ses découpes attendent les chargements du jeu.
func _arena(holder: Node3D, id: int, at: Vector3) -> Node3D:
	var a: Node3D = Arena.new()
	a.set_meta("warm", true)
	a.set("hold", Callable(self, "_hold"))
	holder.add_child(a)
	a.position = at
	a.set("world_id", id)
	return a


## Eau du monde sous l'échantillon (shaders/water.gdshader, la même matière que le jeu).
static func _water(parent: Node3D, id: int) -> void:
	var v := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(60, 0.1, 60)
	v.mesh = b
	v.material_override = Worlds.water_material(id)
	v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.position = Vector3(0, -0.6, 0)
	parent.add_child(v)
