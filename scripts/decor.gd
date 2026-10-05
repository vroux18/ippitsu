extends RefCounted
## Décor japonais low-poly et procédural (univers Hokusai) : arbres, lanternes, torii, vague, îlots.
## Chaque fonction crée un Node3D enfant de `parent`, le place et le renvoie.
## Les pièces d'un même matériau sont fusionnées (SurfaceTool.append_from) : 1 draw call par teinte.
## Matériaux partagés via un cache statique ; uniquement StandardMaterial3D (renderer Compatibility).

const Toon = preload("res://scripts/toon.gd")

const SAKURA := [Color("#F2B8C6"), Color("#E79AB0"), Color("#F7D6DE")]
const BARK_SAKURA := Color("#4A3530")
const BARK_PINE := Color("#5A4434")
const PINE_A := Color("#3E5A4A")
const PINE_B := Color("#2F4A3C")
const PINE_HI := Color("#4E6E5B")
const BAMBOO := Color("#8DAE5E")
const BAMBOO_NODE := Color("#5E7F43")
const BAMBOO_LEAF := Color("#5F8C45")
const SHOOT := Color("#8A6A45")
const STONE := Color("#9C978C")
const MOSS := Color("#6F8A5E")
const ROCK := Color("#7C8A97")
const ISLAND_ROCK := Color("#72849A")
const STRAW := Color("#D8C48C")
const SHIDE := Color("#FBF8F0")
const POLE := Color("#3B2E25")
const GLOW := Color("#FFD27A")
const WAVE_LIGHT := Color("#5E8DB6")
const WAVE_LIP := Color("#3D6690")

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


# ------------------------------------------------------------------ matériaux (cache)

## Matériau toon partagé, mis en cache par nom.
static func _toon(key: String, color: Color, outline := true, osz := 0.03) -> StandardMaterial3D:
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := Toon.mat(color, outline, osz)
	_mats[key] = m
	return m


## Toon lumineux (lanternes, foyer) : couleur + émission.
static func _glow(key: String, color: Color, energy: float, outline := false) -> StandardMaterial3D:
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := Toon.mat(color, outline, 0.025)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


## Aplat opaque sans lumière (lointains, écume), éventuellement à couleurs de sommets.
static func _flat(key: String, color: Color, vcol := false, double := false) -> StandardMaterial3D:
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.vertex_color_use_as_albedo = vcol
	m.vertex_color_is_srgb = vcol
	if double:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## Toon à couleurs de sommets (rochers facettés).
static func _toon_vc(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := Toon.mat(Color.WHITE, false)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	_mats[key] = m
	return m


## Contour d'encre seul : 2e surface des maillages faits main (normales lisses, pas de fissures).
static func _ink(osz: float) -> StandardMaterial3D:
	var key := "ink_%.3f" % osz
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = Toon.SUMI
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = osz
	_mats[key] = o
	return o


# ------------------------------------------------------------------ briques

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(seed_value * 7919 + 101)
	return r


static func _root(parent: Node3D, pos: Vector3, s: float, nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	return n


## Sphère basse résolution ; h < 2r donne un ellipsoïde aplati (sans échelle : contour régulier).
static func _ball(r: float, h: float, seg := 8, rings := 4) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = seg
	m.rings = rings
	return m


static func _at(p: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), p)


## Base dont l'axe Y suit `d` (pour orienter cylindres et cônes).
static func _basis_y(d: Vector3) -> Basis:
	if d.length_squared() < 0.000001:
		return Basis()
	var y := d.normalized()
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


## Ajoute une primitive au lot du matériau `m` (fusion par matériau).
static func _add(b: Dictionary, m: Material, mesh: Mesh, xf: Transform3D) -> void:
	var k := m.get_instance_id()
	if not b.has(k):
		var st0 := SurfaceTool.new()
		st0.begin(Mesh.PRIMITIVE_TRIANGLES)
		b[k] = [st0, m]
	var entry: Array = b[k]
	var st: SurfaceTool = entry[0]
	st.append_from(mesh, 0, xf)


## Transforme chaque lot en un MeshInstance3D.
static func _flush(b: Dictionary, parent: Node3D, shadow := true) -> void:
	for k in b:
		var entry: Array = b[k]
		var st: SurfaceTool = entry[0]
		var m: Material = entry[1]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		if shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Segment conique de a vers c (branche, tige, griffe) : r0 au départ, r1 au bout.
static func _limb(b: Dictionary, m: Material, a: Vector3, c: Vector3, r0: float, r1: float, sides := 7) -> void:
	var d := c - a
	var l := d.length()
	if l < 0.001:
		return
	_add(b, m, Toon.cyl(r1, r0, l, sides), Transform3D(_basis_y(d), (a + c) * 0.5))


## Triangle face avant vers `out` (Godot : sens horaire = face avant).
static func _tri_o(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	st.add_vertex(a)
	if (b - a).cross(c - a).dot(out) > 0.0:
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(b)
		st.add_vertex(c)


## Triangle à normales par sommet, orienté vers l'extérieur.
static func _tri_s(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var tp := b
		b = c
		c = tp
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


## Tube lisse le long d'une polyligne (brins de corde).
static func _tube(st: SurfaceTool, pts: PackedVector3Array, rad: PackedFloat32Array, sides: int) -> void:
	var n := pts.size()
	var rings: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	for i in n:
		var tg := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(tg.y) < 0.9 else Vector3.RIGHT
		var n1 := tg.cross(ref).normalized()
		var n2 := tg.cross(n1)
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides
			var dir := n1 * cos(a) + n2 * sin(a)
			ring.append(pts[i] + dir * rad[i])
			nr.append(dir)
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var m0: PackedVector3Array = norms[i]
		var m1: PackedVector3Array = norms[i + 1]
		for k in sides:
			var k2 := (k + 1) % sides
			_tri_s(st, r0[k], r0[k2], r1[k], m0[k], m0[k2], m1[k])
			_tri_s(st, r0[k2], r1[k2], r1[k], m0[k2], m1[k2], m1[k])


# ------------------------------------------------------------------ cerisier

## Cerisier en fleurs : tronc tordu, branches, 6-10 amas roses, quelques pétales au sol.
static func sakura(parent: Node3D, pos: Vector3, s := 1.0, seed := 0) -> Node3D:
	var rng := _rng(seed)
	var root := _root(parent, pos, s, "Sakura")
	root.rotation.y = rng.randf() * TAU
	var bark := _toon("sakura_bark", BARK_SAKURA)
	var pinks: Array[StandardMaterial3D] = []
	for i in SAKURA.size():
		var c: Color = SAKURA[i]
		pinks.append(_toon("sakura_%d" % i, c, true, 0.03))
	var wood := {}
	var bloom := {}
	var ground := {}

	# tronc tordu : segments qui dérivent, pied évasé, rotules aux coudes
	_add(wood, bark, Toon.cyl(0.15, 0.26, 0.22, 7), _at(Vector3(0, 0.11, 0)))
	var pts: Array[Vector3] = [Vector3.ZERO]
	var p := Vector3.ZERO
	var drift := Vector2.from_angle(rng.randf() * TAU) * 0.17
	var nseg := rng.randi_range(4, 5)
	for i in nseg:
		drift = drift.rotated(rng.randf_range(-0.9, 0.9))
		p += Vector3(drift.x, rng.randf_range(0.34, 0.44), drift.y)
		pts.append(p)
	for i in nseg:
		var r0 := lerpf(0.15, 0.07, float(i) / nseg)
		var r1 := lerpf(0.15, 0.07, float(i + 1) / nseg)
		_limb(wood, bark, pts[i], pts[i + 1], r0, r1)
		_add(wood, bark, _ball(r1 * 1.05, r1 * 2.1, 7, 3), _at(pts[i + 1]))

	# branches en deux coudes, réparties autour du tronc
	var tips: Array[Vector3] = [pts[nseg]]
	var nb := rng.randi_range(3, 5)
	for i in nb:
		var start: Vector3 = pts[rng.randi_range(2, nseg)]
		var ang := TAU * (float(i) + rng.randf_range(-0.25, 0.25)) / nb
		var dir := Vector3(cos(ang), rng.randf_range(0.35, 0.8), sin(ang)).normalized()
		var blen := rng.randf_range(0.55, 0.95)
		var mid := start + dir * blen * 0.55 + Vector3(0, rng.randf_range(-0.05, 0.12), 0)
		var dir2 := (dir + Vector3(rng.randf_range(-0.4, 0.4), 0.15, rng.randf_range(-0.4, 0.4))).normalized()
		var tip := mid + dir2 * blen * 0.5
		_limb(wood, bark, start, mid, 0.065, 0.045, 6)
		_add(wood, bark, _ball(0.047, 0.094, 6, 3), _at(mid))
		_limb(wood, bark, mid, tip, 0.045, 0.025, 6)
		tips.append(tip)
		if rng.randf() < 0.5:
			tips.append(mid + Vector3(0, 0.12, 0))

	# amas de fleurs : ellipsoïdes aplatis + satellites, trois roses mêlés
	var n := rng.randi_range(6, 10)
	for i in n:
		var c: Vector3
		if i < tips.size():
			c = tips[i]
		else:
			var t: Vector3 = tips[rng.randi_range(0, tips.size() - 1)]
			c = t + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.35, 0.35))
		var r := rng.randf_range(0.36, 0.55)
		_add(bloom, pinks[rng.randi_range(0, pinks.size() - 1)], _ball(r, r * 1.3, 8, 4),
			_at(c + Vector3(0, r * 0.15, 0), Vector3(0, rng.randf() * TAU, 0)))
		for j in rng.randi_range(1, 2):
			var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.4), rng.randf_range(-1, 1)).normalized() * r * 0.85
			var r2 := r * rng.randf_range(0.45, 0.65)
			_add(bloom, pinks[rng.randi_range(0, pinks.size() - 1)], _ball(r2, r2 * 1.3, 7, 3), _at(c + off))

	# tapis de pétales tombés (petits disques plats, sans ombre)
	var petal_m := _toon("sakura_ground", SAKURA[2], false)
	for i in rng.randi_range(8, 12):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 1.3
		var pr := rng.randf_range(0.04, 0.07)
		_add(ground, petal_m, Toon.cyl(pr, pr, 0.008, 6), _at(Vector3(cos(a) * d, 0.006, sin(a) * d)))

	_flush(wood, root)
	_flush(bloom, root)
	_flush(ground, root, false)
	return root


# ------------------------------------------------------------------ pin

## Pin japonais (matsu) : tronc en S penché, plateaux d'aiguilles horizontaux.
static func pine(parent: Node3D, pos: Vector3, s := 1.0, seed := 0) -> Node3D:
	var rng := _rng(seed)
	var root := _root(parent, pos, s, "Pine")
	root.rotation.y = rng.randf() * TAU
	_pine_into(root, rng, true)
	return root


static func _pine_into(root: Node3D, rng: RandomNumberGenerator, near: bool) -> void:
	var pre: String = "pine_" if near else "pine_far_"
	var bark := _toon(pre + "bark", BARK_PINE, near, 0.03)
	var greens: Array[StandardMaterial3D] = [_toon(pre + "b", PINE_B, near, 0.03),
		_toon(pre + "a", PINE_A, near, 0.03), _toon(pre + "hi", PINE_HI, near, 0.03)]
	var wood := {}
	var leaf := {}

	# tronc : courbe en S, penché comme un pin de bord de mer
	var lean := Vector2.from_angle(rng.randf() * TAU)
	var bend := PackedFloat32Array([0.04, 0.2, 0.16, -0.06, -0.12])
	var pts: Array[Vector3] = [Vector3.ZERO]
	var p := Vector3.ZERO
	for i in bend.size():
		var k := bend[i] + rng.randf_range(-0.05, 0.05)
		p += Vector3(lean.x * k, rng.randf_range(0.36, 0.44), lean.y * k)
		pts.append(p)
	var nseg := pts.size() - 1
	_add(wood, bark, Toon.cyl(0.15, 0.24, 0.2, 7), _at(Vector3(0, 0.1, 0)))
	for i in nseg:
		var r0 := lerpf(0.15, 0.06, float(i) / nseg)
		var r1 := lerpf(0.15, 0.06, float(i + 1) / nseg)
		_limb(wood, bark, pts[i], pts[i + 1], r0, r1, 7)
		_add(wood, bark, _ball(r1, r1 * 2.0, 7, 3), _at(pts[i + 1]))

	# étages de branches horizontales (angle d'or), chacune terminée par un plateau
	var ang := rng.randf() * TAU
	for i in range(2, nseg + 1):
		ang += 2.4 + rng.randf_range(-0.3, 0.3)
		var start: Vector3 = pts[i]
		var reach := rng.randf_range(0.55, 0.95) * (1.15 - 0.12 * i)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var end := start + dir * reach + Vector3(0, rng.randf_range(-0.05, 0.12), 0)
		_limb(wood, bark, start, end, 0.05, 0.028, 5)
		var lvl: int = 0 if i < 4 else 1
		_pad(leaf, greens, rng, end + Vector3(0, 0.06, 0), rng.randf_range(0.45, 0.65) * (1.1 - 0.08 * i), lvl)
	# couronne
	_pad(leaf, greens, rng, pts[nseg] + Vector3(0, 0.1, 0), rng.randf_range(0.48, 0.6), 1)
	_flush(wood, root)
	_flush(leaf, root)


## Plateau d'aiguilles : coussin aplati, 2-3 petits coussins autour, reflet plus clair dessus.
static func _pad(b: Dictionary, greens: Array[StandardMaterial3D], rng: RandomNumberGenerator, c: Vector3, r: float, lvl: int) -> void:
	_add(b, greens[lvl], _ball(r, r * 0.42, 9, 4), _at(c))
	for j in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		var rr := r * rng.randf_range(0.45, 0.62)
		var off := Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.55, 0.8) + Vector3(0, rng.randf_range(0.0, 0.07), 0)
		_add(b, greens[lvl], _ball(rr, rr * 0.5, 8, 3), _at(c + off))
	var hi := Vector3(rng.randf_range(-0.08, 0.08), r * 0.17, rng.randf_range(-0.08, 0.08))
	_add(b, greens[mini(lvl + 1, 2)], _ball(r * 0.62, r * 0.3, 8, 3), _at(c + hi))


# ------------------------------------------------------------------ bambous

## Bosquet de 5-9 tiges à nœuds, feuilles en fer de lance, une ou deux pousses.
static func bamboo(parent: Node3D, pos: Vector3, s := 1.0, seed := 0) -> Node3D:
	var rng := _rng(seed)
	var root := _root(parent, pos, s, "Bamboo")
	var stem_m := _toon("bamboo_stem", BAMBOO, true, 0.018)
	var node_m := _toon("bamboo_node", BAMBOO_NODE, true, 0.018)
	var shoot_m := _toon("bamboo_shoot", SHOOT, true, 0.02)
	var leaf_a := _toon("bamboo_leaf_a", BAMBOO_LEAF, false)
	var leaf_b := _toon("bamboo_leaf_b", BAMBOO_LEAF.darkened(0.2), false)
	var stems := {}
	var leaves := {}
	var n := rng.randi_range(5, 9)
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.45
		var base := Vector3(cos(a) * d, 0, sin(a) * d)
		var h := rng.randf_range(2.0, 3.3)
		# légère inclinaison vers l'extérieur du bosquet
		var lean := Vector3(base.x * 0.35 + rng.randf_range(-0.12, 0.12), 0, base.z * 0.35 + rng.randf_range(-0.12, 0.12))
		var top := base + Vector3(0, h, 0) + lean * h * 0.4
		var r := rng.randf_range(0.035, 0.05)
		_limb(stems, stem_m, base, top, r, r * 0.8, 6)
		var axis := (top - base).normalized()
		var bas := _basis_y(axis)
		var seg := rng.randf_range(0.38, 0.5)
		var t := seg
		while t < h - 0.1:
			var pn := base + axis * t
			_add(stems, node_m, Toon.cyl(r * 1.25, r * 1.25, 0.03, 6), Transform3D(bas, pn))
			if t > h * 0.45 and rng.randf() < 0.55:
				for j in rng.randi_range(2, 3):
					var yaw := rng.randf() * TAU
					var ll := rng.randf_range(0.22, 0.34)
					var dir := Vector3(cos(yaw), rng.randf_range(-0.55, -0.1), sin(yaw)).normalized()
					var lm: StandardMaterial3D = leaf_a if rng.randf() < 0.6 else leaf_b
					_limb(leaves, lm, pn, pn + dir * ll, 0.03, 0.0, 3)
			t += seg
		# panache au sommet
		for j in 3:
			var yaw := rng.randf() * TAU
			var dir := Vector3(cos(yaw), rng.randf_range(-0.2, 0.35), sin(yaw)).normalized()
			_limb(leaves, leaf_a, top, top + dir * rng.randf_range(0.25, 0.36), 0.03, 0.0, 3)
	# pousses (takenoko) au pied
	for i in rng.randi_range(1, 2):
		var a := rng.randf() * TAU
		var q := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.45, 0.65)
		_limb(stems, shoot_m, q, q + Vector3(0, rng.randf_range(0.14, 0.22), 0), 0.06, 0.0, 6)
	_flush(stems, root)
	_flush(leaves, root, false)
	return root


# ------------------------------------------------------------------ lanternes

## Tōrō de pierre : socle hexagonal, pied, plateau, chambre à feu dorée, toit à 6 pans relevés, hōju.
static func stone_lantern(parent: Node3D, pos: Vector3, s := 1.0) -> Node3D:
	var root := _root(parent, pos, s, "StoneLantern")
	var stone := _toon("stone", STONE, true, 0.025)
	var dark := _toon("stone_dark", STONE.darkened(0.18), true, 0.025)
	var glow := _glow("lantern_glow", GLOW, 1.0)
	var moss := _toon("moss", MOSS, false)
	var b := {}
	var small := {}
	# socle à deux gradins
	_add(b, stone, Toon.cyl(0.27, 0.3, 0.1, 6), _at(Vector3(0, 0.05, 0)))
	_add(b, stone, Toon.cyl(0.2, 0.24, 0.08, 6), _at(Vector3(0, 0.14, 0)))
	# pied (sao) et son anneau
	_add(b, stone, Toon.cyl(0.075, 0.095, 0.42, 8), _at(Vector3(0, 0.39, 0)))
	_add(b, dark, Toon.cyl(0.1, 0.1, 0.04, 8), _at(Vector3(0, 0.4, 0)))
	# plateau (chūdai)
	_add(b, stone, Toon.cyl(0.24, 0.14, 0.1, 6), _at(Vector3(0, 0.65, 0)))
	# chambre à feu : cœur lumineux entre 6 montants
	_add(small, glow, Toon.cyl(0.12, 0.12, 0.22, 6), _at(Vector3(0, 0.81, 0)))
	for k in 6:
		var a := TAU * k / 6.0
		_add(b, stone, Toon.box(Vector3(0.05, 0.22, 0.05)),
			Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.16, 0.81, cos(a) * 0.16)))
	_add(b, stone, Toon.cyl(0.2, 0.2, 0.04, 6), _at(Vector3(0, 0.94, 0)))
	# toit à 6 pans, bordure, angles relevés (warabite)
	_add(b, dark, Toon.cyl(0.38, 0.38, 0.03, 6), _at(Vector3(0, 0.975, 0)))
	_add(b, stone, Toon.cyl(0.07, 0.38, 0.17, 6), _at(Vector3(0, 1.075, 0)))
	for k in 6:
		var a := TAU * k / 6.0
		var corner := Vector3(sin(a) * 0.37, 1.02, cos(a) * 0.37)
		_add(b, stone, Toon.cyl(0.0, 0.035, 0.09, 4), Transform3D(_basis_y(Vector3(sin(a) * 0.6, 1.0, cos(a) * 0.6)), corner))
	# bouton (hōju) : col, perle, pointe
	_add(b, stone, Toon.cyl(0.05, 0.07, 0.05, 6), _at(Vector3(0, 1.185, 0)))
	_add(b, stone, _ball(0.07, 0.13, 8, 4), _at(Vector3(0, 1.27, 0)))
	_add(b, stone, Toon.cyl(0.0, 0.035, 0.07, 6), _at(Vector3(0, 1.35, 0)))
	# touches de mousse sur le toit
	for k in 2:
		var a := TAU * (0.15 + 0.4 * k)
		_add(small, moss, _ball(0.08, 0.05, 6, 3), _at(Vector3(sin(a) * 0.22, 1.07, cos(a) * 0.22)))
	_flush(b, root)
	_flush(small, root, false)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.81, 0)
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 0.6
	light.omni_range = 3.0
	light.shadow_enabled = false
	root.add_child(light)
	return root


## Chōchin : lanterne de papier allongée et lumineuse, cerclages, coiffes noires, sur potence.
static func paper_lantern(parent: Node3D, pos: Vector3, s := 1.0, color := Toon.VERMILION) -> Node3D:
	var root := _root(parent, pos, s, "PaperLantern")
	var key := color.to_html(false)
	var pole_m := _toon("pole", POLE, true, 0.02)
	var black := _toon("sumi_plain", Toon.SUMI, false)
	var body := _glow("chochin_" + key, color, 0.55, true)
	var rib := _toon("chochin_rib_" + key, color.darkened(0.35), false)
	var b := {}
	var small := {}
	# poteau, potence et jambe de force
	_add(b, pole_m, Toon.box(Vector3(0.16, 0.08, 0.16)), _at(Vector3(0, 0.04, 0)))
	_add(b, pole_m, Toon.cyl(0.035, 0.045, 1.9, 6), _at(Vector3(0, 0.95, 0)))
	_add(b, pole_m, Toon.box(Vector3(0.52, 0.05, 0.05)), _at(Vector3(0.22, 1.86, 0)))
	_limb(b, pole_m, Vector3(0, 1.62, 0), Vector3(0.22, 1.85, 0), 0.018, 0.018, 4)
	# cordon puis lanterne
	var hx := 0.4
	_limb(small, black, Vector3(hx, 1.84, 0), Vector3(hx, 1.72, 0), 0.008, 0.008, 4)
	var cy := 1.47
	_add(b, body, _ball(0.18, 0.42, 10, 6), _at(Vector3(hx, cy, 0)))
	_add(small, black, Toon.cyl(0.1, 0.1, 0.05, 10), _at(Vector3(hx, cy + 0.225, 0)))
	_add(small, black, Toon.cyl(0.1, 0.1, 0.05, 10), _at(Vector3(hx, cy - 0.225, 0)))
	for dy: float in [-0.12, 0.0, 0.12]:
		var rr := 0.18 * sqrt(1.0 - pow(dy / 0.21, 2.0))
		var tor := TorusMesh.new()
		tor.inner_radius = rr - 0.006
		tor.outer_radius = rr + 0.01
		tor.rings = 12
		tor.ring_segments = 4
		_add(small, rib, tor, _at(Vector3(hx, cy + dy, 0)))
	# gland sous la coiffe
	_add(small, black, Toon.cyl(0.012, 0.03, 0.12, 5), _at(Vector3(hx, cy - 0.31, 0)))
	_flush(b, root)
	_flush(small, root, false)
	return root


# ------------------------------------------------------------------ rochers

## Rocher irrégulier facetté (sphère basse résolution déformée), gris-bleu, mousse au sommet.
static func rock(parent: Node3D, pos: Vector3, s := 1.0, seed := 0) -> Node3D:
	var rng := _rng(seed)
	var root := _root(parent, pos, s, "Rock")
	root.rotation.y = rng.randf() * TAU
	var rad := Vector3(rng.randf_range(0.5, 0.7), rng.randf_range(0.35, 0.5), rng.randf_range(0.45, 0.6))
	root.add_child(_rock_mi(rng, rad, true, ROCK))
	return root


## Maillage du rocher : surface 0 facettée à couleurs de sommets, surface 1 contour (si proche).
static func _rock_mi(rng: RandomNumberGenerator, rad: Vector3, near: bool, base: Color) -> MeshInstance3D:
	var rings := 5
	var segs := 7
	var pts: Array[Vector3] = [Vector3(0, rad.y * rng.randf_range(0.82, 0.95), 0)]
	for i in range(1, rings):
		var lat := PI * float(i) / rings
		var lon0 := rng.randf_range(-0.3, 0.3)
		for j in segs:
			var lon := lon0 + TAU * (float(j) + rng.randf_range(-0.22, 0.22)) / segs
			var p := Vector3(sin(lat) * cos(lon) * rad.x, cos(lat) * rad.y, sin(lat) * sin(lon) * rad.z) * rng.randf_range(0.8, 1.14)
			# sommet en plateau, base tronquée (posée / enfoncée)
			p.y = clampf(p.y, -rad.y * 0.35, rad.y * 0.82)
			pts.append(p)
	pts.append(Vector3(0, -rad.y * 0.35, 0))
	var last := pts.size() - 1
	var lb := 1 + (rings - 2) * segs
	var tris := PackedInt32Array()
	for j in segs:
		var j2 := (j + 1) % segs
		tris.append_array(PackedInt32Array([0, 1 + j, 1 + j2]))
		for i in rings - 2:
			var a := 1 + i * segs + j
			var b := 1 + i * segs + j2
			tris.append_array(PackedInt32Array([a, a + segs, b, b, a + segs, b + segs]))
		tris.append_array(PackedInt32Array([last, lb + j2, lb + j]))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in range(0, tris.size(), 3):
		var a: Vector3 = pts[tris[f]]
		var b: Vector3 = pts[tris[f + 1]]
		var c: Vector3 = pts[tris[f + 2]]
		var out := (a + b + c) / 3.0
		var n := (b - a).cross(c - a).normalized()
		if n.dot(out) < 0.0:
			n = -n
		# faces du dessus plus claires, variation par face, mousse sur les replats
		var col := base.lerp(base.lightened(0.22), clampf(n.y, 0.0, 1.0) * 0.7).darkened(rng.randf_range(0.0, 0.12))
		if n.y > 0.62 and rng.randf() < 0.5:
			col = col.lerp(MOSS, 0.6)
		st.set_color(col)
		st.set_normal(n)
		_tri_o(st, a, b, c, out)
	var mesh := st.commit()
	mesh.surface_set_material(0, _toon_vc("rock_vc"))
	if near:
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f in range(0, tris.size(), 3):
			var a: Vector3 = pts[tris[f]]
			var b: Vector3 = pts[tris[f + 1]]
			var c: Vector3 = pts[tris[f + 2]]
			_tri_s(st2, a, b, c, a.normalized(), b.normalized(), c.normalized())
		st2.commit(mesh)
		mesh.surface_set_material(1, _ink(0.03))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


# ------------------------------------------------------------------ shimenawa

## Corde sacrée torsadée (deux brins, plus épaisse au milieu) de a à b, shide et touffes de paille.
static func rope_shimenawa(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Shimenawa"
	root.position = a
	parent.add_child(root)
	var d := b - a
	var span := d.length()
	if span < 0.05:
		return root
	var straw := _toon("straw", STRAW, true, 0.02)
	var paper := _toon("shide", SHIDE, true, 0.008)
	var horiz := Vector3(d.x, 0.0, d.z)
	var along := horiz.normalized() if horiz.length() > 0.01 else Vector3.RIGHT
	var side := along.cross(Vector3.UP)
	var sag := 0.1 * span
	var r0 := clampf(span * 0.025, 0.05, 0.12)
	var twists := clampf(span / (r0 * 5.0), 2.0, 8.0)
	var n := clampi(int(twists * 8.0), 16, 64)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in 2:
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for i in n + 1:
			var t := float(i) / n
			var c := _sag(d, sag, t)
			var tg := (_sag(d, sag, t + 0.01) - _sag(d, sag, t - 0.01)).normalized()
			var up2 := tg.cross(side).normalized()
			var th := t * twists * TAU + strand * PI
			var thick := r0 * (0.55 + 0.45 * sin(PI * t))
			pts.append(c + (side * cos(th) + up2 * sin(th)) * thick * 0.5)
			rad.append(thick * 0.62)
		_tube(st, pts, rad, 6)
	var rope := MeshInstance3D.new()
	rope.mesh = st.commit()
	rope.material_override = straw
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(rope)

	var bits := {}
	# nœuds aux extrémités
	_add(bits, straw, _ball(r0 * 0.7, r0 * 1.4, 7, 4), _at(Vector3.ZERO))
	_add(bits, straw, _ball(r0 * 0.7, r0 * 1.4, 7, 4), _at(d))
	# shide en zigzag, touffes de paille entre eux
	var nshide := 4 if span > 1.6 else 3
	for i in nshide:
		var t := (float(i) + 0.5) / nshide
		_shide(bits, paper, _sag(d, sag, t) - Vector3(0, r0 * 0.6, 0), along)
		if i < nshide - 1:
			var q := _sag(d, sag, (float(i) + 1.0) / nshide) - Vector3(0, r0 * 0.5, 0)
			_limb(bits, straw, q, q - Vector3(0, 0.16 + r0, 0), 0.03, 0.006, 5)
	_flush(bits, root, false)
	return root


## Point de la corde (chaînette approchée par une parabole).
static func _sag(d: Vector3, sag: float, t: float) -> Vector3:
	return d * t + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)


## Shide : bande de papier blanc pliée en éclair (4 rectangles décalés).
static func _shide(b: Dictionary, m: Material, top: Vector3, along: Vector3) -> void:
	var bas := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var w := 0.075
	var h := 0.09
	for k in 4:
		var dx: float = 0.034 if k % 2 == 1 else 0.0
		var c := top + along * dx - Vector3(0, h * 0.5 + h * 0.85 * k, 0)
		_add(b, m, Toon.box(Vector3(w, h, 0.006)), Transform3D(bas, c))


# ------------------------------------------------------------------ torii

## Torii : socles noirs, piliers vermillon, nuki et kusabi, gakuzuka + plaque, shimaki, kasagi incurvé.
static func torii(parent: Node3D, pos: Vector3, s := 1.0) -> Node3D:
	var root := _root(parent, pos, s, "Torii")
	var red := _toon("torii_red", Toon.VERMILION)
	var black := _toon("torii_black", Toon.SUMI)
	var gold := _toon("torii_gold", Toon.GOLD, false)
	var b := {}
	var px := 2.2
	for sx: float in [-1.0, 1.0]:
		var x := sx * px
		# kamebara (socle noir évasé) et nemaki
		_add(b, black, Toon.cyl(0.21, 0.27, 0.4, 12), _at(Vector3(x, 0.2, 0)))
		_add(b, black, Toon.cyl(0.2, 0.2, 0.06, 12), _at(Vector3(x, 0.43, 0)))
		# hashira : pilier légèrement conique
		_add(b, red, Toon.cyl(0.155, 0.18, 2.55, 12), _at(Vector3(x, 1.675, 0)))
		# daiwa : anneau noir sous le shimaki
		_add(b, black, Toon.cyl(0.19, 0.19, 0.1, 12), _at(Vector3(x, 2.9, 0)))
		# kusabi : coin qui bloque le nuki
		_add(b, red, Toon.box(Vector3(0.07, 0.3, 0.22)), _at(Vector3(x + sx * 0.23, 2.45, 0)))
	# nuki : traverse basse qui dépasse
	_add(b, red, Toon.box(Vector3(5.7, 0.2, 0.16)), _at(Vector3(0, 2.45, 0)))
	# gakuzuka et plaque (gaku) noire cerclée d'or
	_add(b, red, Toon.box(Vector3(0.22, 0.44, 0.16)), _at(Vector3(0, 2.76, 0)))
	_add(b, black, Toon.box(Vector3(0.44, 0.52, 0.06)), _at(Vector3(0, 2.74, 0.12)))
	_add(b, gold, Toon.box(Vector3(0.32, 0.4, 0.02)), _at(Vector3(0, 2.74, 0.155)))
	# shimaki : linteau vermillon droit
	_add(b, red, Toon.box(Vector3(5.9, 0.2, 0.34)), _at(Vector3(0, 3.05, 0)))
	# kasagi : linteau noir aux extrémités relevées (segments qui suivent la courbe)
	var w := 3.35
	var nk := 8
	for i in nk:
		var x0 := lerpf(-w, w, float(i) / nk)
		var x1 := lerpf(-w, w, float(i + 1) / nk)
		var y0 := 3.28 + 0.34 * pow(absf(x0) / w, 2.6)
		var y1 := 3.28 + 0.34 * pow(absf(x1) / w, 2.6)
		var mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0)
		var l := Vector2(x1 - x0, y1 - y0).length() + 0.03
		var ang := atan2(y1 - y0, x1 - x0)
		_add(b, black, Toon.box(Vector3(l, 0.26, 0.48)), Transform3D(Basis(Vector3(0, 0, 1), ang), mid))
	_flush(b, root)
	return root


# ------------------------------------------------------------------ grande vague

## Vague de Kanagawa : profil recourbé extrudé (aplat à dégradé Prusse), griffes d'écume, embruns.
## Origine posée sur l'eau ; la lèvre s'enroule vers +Z local.
static func great_wave(parent: Node3D, pos: Vector3, s := 1.0, seed := 0) -> Node3D:
	var rng := _rng(seed)
	var root := _root(parent, pos, s, "GreatWave")
	root.rotation.y = rng.randf_range(-0.3, 0.3)
	# profil (z, y) : dos en pente douce, crête dressée, lèvre qui s'enroule vers l'avant
	var key_pts := PackedVector2Array([
		Vector2(-4.0, 0.0), Vector2(-3.0, 0.35), Vector2(-2.0, 0.95), Vector2(-1.2, 1.7),
		Vector2(-0.6, 2.5), Vector2(-0.1, 3.2), Vector2(0.5, 3.65), Vector2(1.2, 3.75),
		Vector2(1.85, 3.45), Vector2(2.2, 2.9), Vector2(2.15, 2.35), Vector2(1.8, 2.0),
		Vector2(1.4, 1.95), Vector2(1.15, 2.15)])
	var nk := key_pts.size()
	var prof := PackedVector2Array()
	for k in nk - 1:
		var p0 := key_pts[maxi(k - 1, 0)]
		var p1 := key_pts[k]
		var p2 := key_pts[k + 1]
		var p3 := key_pts[mini(k + 2, nk - 1)]
		for j in 3:
			prof.append(p1.cubic_interpolate(p2, p0, p3, j / 3.0))
	prof.append(key_pts[nk - 1])
	var np := prof.size()

	# stations le long de l'axe X : hauteur et enroulement maximaux au centre
	var nx := 12
	var half := 4.6
	var rows: Array[PackedVector3Array] = []
	var crows: Array[PackedColorArray] = []
	var hfs := PackedFloat32Array()
	var curls := PackedFloat32Array()
	var xs := PackedFloat32Array()
	for i in nx + 1:
		var u := float(i) / nx * 2.0 - 1.0
		var hf := (0.06 + 0.94 * pow(maxf(1.0 - u * u, 0.0), 1.2)) * rng.randf_range(0.9, 1.08)
		var cu := lerpf(0.5, 1.0, hf)
		var x := u * half
		var shade := rng.randf_range(-0.05, 0.05)
		var row := PackedVector3Array()
		var crow := PackedColorArray()
		for k in np:
			var q := prof[k]
			row.append(Vector3(x, q.y * hf, q.x * cu))
			crow.append(_wave_color(float(k) / (np - 1), shade))
		rows.append(row)
		crows.append(crow)
		hfs.append(hf)
		curls.append(cu)
		xs.append(x)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nx:
		var r0: PackedVector3Array = rows[i]
		var r1: PackedVector3Array = rows[i + 1]
		var c0: PackedColorArray = crows[i]
		var c1: PackedColorArray = crows[i + 1]
		for k in np - 1:
			_vtx(st, c0[k], r0[k])
			_vtx(st, c1[k], r1[k])
			_vtx(st, c0[k + 1], r0[k + 1])
			_vtx(st, c1[k], r1[k])
			_vtx(st, c1[k + 1], r1[k + 1])
			_vtx(st, c0[k + 1], r0[k + 1])
	var sheet := MeshInstance3D.new()
	sheet.mesh = st.commit()
	sheet.material_override = _flat("wave", Color.WHITE, true, true)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sheet)

	# griffes d'écume : boule + cône coudé, rayonnant depuis le centre de l'enroulement
	var foam := {}
	var fm := _flat("foam", Toon.FOAM)
	var k0 := int(np * 0.55)
	var k1 := int(np * 0.93)
	for i in range(1, nx):
		var hf := hfs[i]
		if hf < 0.25:
			continue
		var row: PackedVector3Array = rows[i]
		var ctr := Vector3(xs[i], 2.85 * hf, 1.55 * curls[i])
		var sh := sqrt(hf)
		for j in rng.randi_range(3, 4):
			var p := row[rng.randi_range(k0, k1)]
			var dir := (p - ctr).normalized()
			dir = (dir + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))).normalized()
			var cl := rng.randf_range(0.28, 0.5) * sh
			var cr := rng.randf_range(0.07, 0.11) * sh
			var tip := p + dir * cl
			var hook := (dir + Vector3(0, -0.7, 0)).normalized()
			_add(foam, fm, _ball(cr * 1.35, cr * 2.4, 6, 3), _at(p))
			_limb(foam, fm, p, tip, cr, cr * 0.45, 5)
			_limb(foam, fm, tip, tip + hook * cl * 0.5, cr * 0.45, 0.0, 4)
		# écume au pied, sous le rouleau
		for j in 2:
			var fr := rng.randf_range(0.25, 0.45) * sh
			_add(foam, fm, _ball(fr, fr * 0.35, 7, 3),
				_at(Vector3(xs[i] + rng.randf_range(-0.3, 0.3), 0.03, rng.randf_range(0.2, 1.6) * curls[i])))
	# embruns au-dessus de la lèvre
	for j in 10:
		var i := rng.randi_range(2, nx - 2)
		var row: PackedVector3Array = rows[i]
		var p := row[k1]
		var off := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.1, 0.6), rng.randf_range(0.2, 0.8))
		var dr := rng.randf_range(0.04, 0.09)
		_add(foam, fm, _ball(dr, dr * 2.0, 6, 3), _at(p + off))
	_flush(foam, root, false)
	return root


static func _vtx(st: SurfaceTool, col: Color, p: Vector3) -> void:
	st.set_color(col)
	st.add_vertex(p)


## Dégradé de la vague : bleu clair au pied, Prusse à la crête, lèvre éclaircie puis écume ; stries de gravure.
static func _wave_color(t: float, shade: float) -> Color:
	var c: Color
	if t < 0.5:
		c = WAVE_LIGHT.lerp(Toon.PRUSSIAN, t / 0.5)
	elif t < 0.82:
		c = Toon.PRUSSIAN.lerp(WAVE_LIP, (t - 0.5) / 0.32)
	else:
		c = WAVE_LIP.lerp(Toon.FOAM, (t - 0.82) / 0.18)
	var v := shade + 0.05 * sin(t * 42.0)
	return Color(c.r + v, c.g + v, c.b + v)


# ------------------------------------------------------------------ îlot

## Îlot rocheux d'arrière-plan : grand rocher plat, cailloux, collerette d'écume, 1-2 pins (sans contour).
static func island(parent: Node3D, pos: Vector3, s := 1.0, seed := 0) -> Node3D:
	var rng := _rng(seed)
	var root := _root(parent, pos, s, "Island")
	root.rotation.y = rng.randf() * TAU
	var big := Vector3(rng.randf_range(1.9, 2.4), rng.randf_range(0.9, 1.2), rng.randf_range(1.5, 1.9))
	var main := _rock_mi(rng, big, false, ISLAND_ROCK)
	main.position = Vector3(0, 0.12, 0)
	root.add_child(main)
	for i in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		var pebble := _rock_mi(rng, Vector3(0.55, 0.42, 0.5) * rng.randf_range(0.7, 1.3), false, ISLAND_ROCK)
		pebble.position = Vector3(cos(a) * big.x * 1.05, 0.0, sin(a) * big.z * 1.05)
		root.add_child(pebble)
	Toon.part(root, Toon.cyl(big.x * 1.2, big.x * 1.2, 0.02, 14), _flat("foam", Toon.FOAM),
		Vector3(0, 0.03, 0), Vector3(1, 1, big.z / big.x))
	var npine := rng.randi_range(1, 2)
	for i in npine:
		var holder := Node3D.new()
		var ox := 0.0
		if npine > 1:
			ox = -0.45 if i == 0 else 0.45
		holder.position = Vector3(ox, 0.12 + big.y * 0.72, rng.randf_range(-0.25, 0.25))
		holder.scale = Vector3.ONE * rng.randf_range(0.85, 1.2)
		holder.rotation.y = rng.randf() * TAU
		root.add_child(holder)
		_pine_into(holder, rng, false)
	return root


# ------------------------------------------------------------------ pétales

## Pétales de cerisier qui tombent en tournoyant dans `area` (coordonnées du parent), en boucle.
static func petals(parent: Node3D, area: AABB) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Petals"
	parent.add_child(p)
	p.position = area.position + Vector3(area.size.x * 0.5, area.size.y, area.size.z * 0.5)
	p.local_coords = false
	var fall := maxf(area.size.y, 0.5)
	# durée de vie = temps pour toucher le bas (v0 ≈ 0.38, g ≈ 0.12)
	var life := (-0.38 + sqrt(0.38 * 0.38 + 2.0 * 0.12 * fall)) / 0.12
	p.amount = clampi(int(area.size.x * area.size.z * 0.6), 24, 80)
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(area.size.x * 0.5, 0.05, area.size.z * 0.5)
	p.direction = Vector3(0.4, -1.0, 0.15)
	p.spread = 30.0
	p.gravity = Vector3(0.12, -0.12, 0.04)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.5
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -140.0
	p.angular_velocity_max = 140.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 2.2
	p.mesh = _petal_mesh()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.08, 0.85, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	var tint := Gradient.new()
	tint.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var c0: Color = SAKURA[0]
	var c1: Color = SAKURA[1]
	var c2: Color = SAKURA[2]
	tint.colors = PackedColorArray([c0, c1, c2])
	p.color_initial_ramp = tint
	p.emitting = true
	return p


## Petit pétale échancré (éventail de triangles), billboard, alpha pour le fondu.
static func _petal_mesh() -> ArrayMesh:
	if _meshes.has("petal"):
		var cached: ArrayMesh = _meshes["petal"]
		return cached
	var outline := PackedVector3Array([
		Vector3(0, -0.035, 0), Vector3(0.024, -0.012, 0), Vector3(0.026, 0.018, 0), Vector3(0.01, 0.034, 0),
		Vector3(0, 0.024, 0), Vector3(-0.01, 0.034, 0), Vector3(-0.026, 0.018, 0), Vector3(-0.024, -0.012, 0)])
	var center := Vector3(0, 0.005, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	var n := outline.size()
	for i in n:
		st.add_vertex(center)
		st.add_vertex(outline[i])
		st.add_vertex(outline[(i + 1) % n])
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.surface_set_material(0, m)
	_meshes["petal"] = mesh
	return mesh
