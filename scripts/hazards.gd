extends Node3D
## Dangers d'arène, dans tous les mondes (hors salles de boss) :
##  trous   — planches pourries : on peut tracer au-dessus, pas finir dedans (chute, 1 dégât).
##            Les ennemis projetés dedans tombent à l'eau (sauf les costauds).
##  vague   — déferlante : bande transversale annoncée 1.3 s, qui balaie et repousse.

const Toon = preload("res://scripts/toon.gd")
const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)
const WAVE_W := 2.5
const WAVE_WARN := 1.3

var main: Node
var holes: Array = []  # [centre, rayon]
var _hole_nodes: Array = []
var _wave_on := false
var _wave_t := 0.0  # temps avant la prochaine déferlante
var _band: Node3D
var _band_fill: MeshInstance3D
var _band_z := 0.0
var _band_dir := 1.0
var _warn := 0.0
var _crest: Node3D
var _crest_t := -1.0


func begin_room(room: int, hero_pos: Vector3, boss := false) -> void:
	clear()
	# trous à partir de la salle 2, plus nombreux ensuite ; rien dans une salle de boss (il a ses propres attaques)
	var n := 0 if room < 2 or boss else mini(1 + room / 3, 3)
	for i in n:
		for attempt in 30:
			var r := randf_range(0.8, 1.15)
			var c := Vector3(randf_range(-HALF.x + 1.4, HALF.x - 1.4), 0, randf_range(-HALF.y + 2.0, HALF.y - 2.0))
			var ok: bool = c.distance_to(hero_pos) > 3.0 and main.arena.walkable(c, r + 0.4)
			for h in holes:
				var hc: Vector3 = h[0]
				if hc.distance_to(c) < float(h[1]) + r + 1.5:
					ok = false
			if ok:
				holes.append([c, r])
				_make_hole(c, r)
				break
	_wave_on = room >= 4 and not boss
	_wave_t = randf_range(6.0, 8.0)


func clear() -> void:
	for nd in _hole_nodes:
		if is_instance_valid(nd):
			nd.queue_free()
	_hole_nodes.clear()
	holes.clear()
	_wave_on = false
	_end_band()
	if is_instance_valid(_crest):
		_crest.queue_free()
	_crest = null
	_crest_t = -1.0


func _make_hole(c: Vector3, r: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = c
	# contour déchiqueté : un rayon différent par angle
	var count := 18
	var radii: Array = []
	for i in count:
		radii.append(r * randf_range(0.78, 1.1) * (0.85 if i % 2 == 0 else 1.0))
	# bois noirci autour de la cassure, puis l'eau sombre, puis un liseré d'écume
	_ring_mesh(n, radii, 1.0, 1.22, Color("#3A2A1D"), 0.008)
	_fan_mesh(n, radii, 1.0, Color("#0A1524"), 0.012)
	_fan_mesh(n, radii, 0.72, Color("#123050"), 0.014)
	_ring_mesh(n, radii, 0.86, 1.0, Color(Toon.FOAM, 0.55), 0.016)
	# planches cassées qui pointent vers le trou, esquilles relevées
	var woods := [Toon.mat(Color("#A88452")), Toon.mat(Color("#8E6B3E")), Toon.mat(Color("#B8935F"))]
	for i in 10:
		var a := TAU * i / 10.0 + randf_range(-0.15, 0.15)
		var rr: float = radii[int(a / TAU * count) % count]
		var l := randf_range(0.3, 0.6)
		var p := Toon.part(n, Toon.box(Vector3(randf_range(0.07, 0.12), 0.05, l)), woods[i % 3],
			Vector3(cos(a), 0, sin(a) * 0.85) * (rr + 0.05) + Vector3(0, 0.04, 0))
		p.rotation = Vector3(randf_range(0.25, 0.6), -a - PI / 2.0, randf_range(-0.2, 0.2))
	# deux débris qui flottent dans l'eau
	for i in 2:
		var d := Toon.part(n, Toon.box(Vector3(0.28, 0.04, 0.09)), woods[i], Vector3(randf_range(-0.3, 0.3) * r, 0.02, randf_range(-0.25, 0.25) * r))
		d.rotation.y = randf() * PI
	_hole_nodes.append(n)


## Disque irrégulier plein (eau).
func _fan_mesh(parent: Node3D, radii: Array, k: float, col: Color, y: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := radii.size()
	for i in count:
		var a0 := TAU * i / count
		var a1 := TAU * (i + 1) / count
		var r0: float = radii[i]
		var r1: float = radii[(i + 1) % count]
		st.add_vertex(Vector3(0, y, 0))
		st.add_vertex(Vector3(cos(a0) * r0 * k, y, sin(a0) * r0 * k * 0.85))
		st.add_vertex(Vector3(cos(a1) * r1 * k, y, sin(a1) * r1 * k * 0.85))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Toon.flat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Anneau irrégulier entre deux échelles du contour (bord, écume).
func _ring_mesh(parent: Node3D, radii: Array, k0: float, k1: float, col: Color, y: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := radii.size()
	for i in count:
		var a0 := TAU * i / count
		var a1 := TAU * (i + 1) / count
		var r0: float = radii[i]
		var r1: float = radii[(i + 1) % count]
		var p00 := Vector3(cos(a0) * r0 * k0, y, sin(a0) * r0 * k0 * 0.85)
		var p01 := Vector3(cos(a0) * r0 * k1, y, sin(a0) * r0 * k1 * 0.85)
		var p10 := Vector3(cos(a1) * r1 * k0, y, sin(a1) * r1 * k0 * 0.85)
		var p11 := Vector3(cos(a1) * r1 * k1, y, sin(a1) * r1 * k1 * 0.85)
		st.add_vertex(p00)
		st.add_vertex(p01)
		st.add_vertex(p11)
		st.add_vertex(p00)
		st.add_vertex(p11)
		st.add_vertex(p10)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Toon.flat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func is_hole(p: Vector3, margin := 0.0) -> bool:
	# le vide autour des plateformes compte comme un trou
	if main != null and main.arena != null and not main.arena.walkable(p, -margin):
		return true
	for h in holes:
		var c: Vector3 = h[0]
		var r: float = h[1]
		var d := Vector2(p.x - c.x, (p.z - c.z) / 0.85)
		if d.length() < r - margin:
			return true
	return false


## Vrai si finir en `p` dans `eta` secondes est dangereux (trou, ou déferlante qui tombe).
func danger(p: Vector3, eta: float) -> bool:
	if is_hole(p, 0.1):
		return true
	if _band != null and _warn <= eta + 0.4 and absf(p.z - _band_z) < WAVE_W / 2.0 + 0.3:
		return true
	return false


func update(dt: float) -> void:
	# ennemis projetés dans un trou : à l'eau
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or e.kind == "brute" or e.kind == "funa":
			continue
		var kn: Vector3 = e._knock
		if kn.length() > 2.0 and is_hole(e.position, 0.2):
			main.drown(e)
	# déferlante
	if _wave_on:
		if _band == null and _crest_t < 0.0:
			_wave_t -= dt
			if _wave_t <= 0.0:
				_start_band()
		elif _band != null:
			_warn -= dt
			var k := clampf(1.0 - _warn / WAVE_WARN, 0.0, 1.0)
			_band_fill.scale = Vector3(1, 1, k)
			var m := _band_fill.material_override as StandardMaterial3D
			m.albedo_color = Color(Toon.FOAM, 0.8) if _warn < 0.15 else Color(Toon.PRUSSIAN, 0.5)
			if _warn <= 0.0:
				_hit_band()
	if _crest_t >= 0.0:
		_crest_t += dt
		_crest.position.x = lerpf(-HALF.x - 2.0, HALF.x + 2.0, clampf(_crest_t / 0.45, 0.0, 1.0)) * _band_dir
		if _crest_t > 0.6:
			_crest.queue_free()
			_crest = null
			_crest_t = -1.0
			_wave_t = randf_range(9.0, 12.0)


func _start_band() -> void:
	_band_z = randf_range(-HALF.y + 2.0, HALF.y - 2.0)
	if not main.arena.walkable(Vector3(main.hero.position.x, 0, _band_z), 0.0):
		_band_z = main.hero.position.z
	if absf(_band_z - main.hero.position.z) > 5.0:
		_band_z = clampf(main.hero.position.z + randf_range(-2.0, 2.0), -HALF.y + 1.5, HALF.y - 1.5)
	_band_dir = 1.0 if randf() < 0.5 else -1.0
	_warn = WAVE_WARN
	_band = Node3D.new()
	add_child(_band)
	_band.position = Vector3(0, 0.04, _band_z)
	var bg := Toon.part(_band, Toon.box(Vector3(HALF.x * 2.0, 0.01, WAVE_W)), Toon.flat(Color(Toon.PRUSSIAN, 0.18)), Vector3.ZERO)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_band_fill = Toon.part(_band, Toon.box(Vector3(HALF.x * 2.0, 0.012, WAVE_W)), Toon.flat(Color(Toon.PRUSSIAN, 0.5)), Vector3.ZERO)
	_band_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# hachures d'écume : le sens de la vague
	for i in 6:
		var s := Toon.part(_band, Toon.box(Vector3(0.6, 0.015, 0.08)), Toon.flat(Color(Toon.FOAM, 0.7)),
			Vector3(-HALF.x + 0.8 + i * 1.5, 0.004, randf_range(-0.8, 0.8)))
		s.rotation.y = 0.5 * _band_dir
	main.sfx.play("whoosh", 0.5, -2.0)


func _hit_band() -> void:
	var hero: Node3D = main.hero
	if absf(hero.position.z - _band_z) < WAVE_W / 2.0 + 0.2 and not hero.dashing:
		main.wave_hit(Vector3(0, 0, signf(hero.position.z - _band_z + 0.001) * 3.0))
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead and absf(e.position.z - _band_z) < WAVE_W / 2.0:
			e.push(Vector3(_band_dir * 4.0, 0, 0))
	# crête d'écume qui traverse
	_crest = Node3D.new()
	add_child(_crest)
	_crest.position = Vector3(0, 0, _band_z)
	Toon.part(_crest, Toon.box(Vector3(0.9, 1.1, WAVE_W)), Toon.mat(Toon.PRUSSIAN), Vector3(0, 0.5, 0))
	Toon.part(_crest, Toon.box(Vector3(0.5, 0.4, WAVE_W + 0.1)), Toon.mat(Toon.FOAM), Vector3(0.25 * _band_dir, 1.1, 0))
	_crest_t = 0.0
	main.sfx.play("strike", 0.6)
	main.shake = maxf(main.shake, 0.3)
	_end_band()


func _end_band() -> void:
	if _band:
		_band.queue_free()
		_band = null
