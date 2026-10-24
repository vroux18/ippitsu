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


func _ready() -> void:
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
