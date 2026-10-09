extends RefCounted
## Décor japonais low-poly et procédural (univers Hokusai) : arbres, lanternes, torii, vague, îlots,
## et accessoires (tonneaux de saké, fanions nobori, hokora, clôtures, kadomatsu, ponts, katanas…).
## Deux façons de construire :
##  - les fonctions « nœud » (torii, grande vague, îlot…) créent un Node3D enfant de `parent`, le placent et le renvoient ;
##  - les fonctions `*_into(bs, bn, xf, …)` ajoutent leurs pièces, transformées par `xf`, à des lots partagés
##    (bs : pièces qui projettent une ombre, bn : petites pièces sans ombre). Toute une salle peut ainsi
##    tenir en un MeshInstance3D par matériau.
## Les pièces d'un même matériau sont fusionnées (SurfaceTool.append_from) : 1 draw call par teinte.
## Matériaux et maillages partagés via des caches statiques ; uniquement StandardMaterial3D (Compatibility).

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
const KOMO := Color("#D9C590")
const ROPE_DARK := Color("#3A2E24")
const GLASS := [Color("#7FB7A8"), Color("#8FB4CF"), Color("#A9C79A")]
const STEEL := Color("#C9CED6")
const BRONZE := Color("#4E5E4F")
const PLANK := Color("#A57A43")
const PILE := Color("#4A3A2E")
const LABEL := Color("#2E3446")

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


# ------------------------------------------------------------------ maillages (cache)

## Quantification douce des dimensions (pas de 3 %) : borne la taille du cache de maillages.
static func _qf(v: float) -> float:
	return snappedf(v, maxf(absf(v) * 0.03, 0.002))


## Cylindre / cône partagé (rayon haut, rayon bas, hauteur, côtés).
static func cyl(top: float, bottom: float, h: float, sides := 8) -> CylinderMesh:
	var t := _qf(top)
	var bo := _qf(bottom)
	var hh := _qf(h)
	var key := "c%.4f_%.4f_%.4f_%d" % [t, bo, hh, sides]
	if _meshes.has(key):
		var cached: CylinderMesh = _meshes[key]
		return cached
	var m := Toon.cyl(t, bo, hh, sides)
	_meshes[key] = m
	return m


## Boîte partagée.
static func box(size: Vector3) -> BoxMesh:
	var s := Vector3(_qf(size.x), _qf(size.y), _qf(size.z))
	var key := "b%.4f_%.4f_%.4f" % [s.x, s.y, s.z]
	if _meshes.has(key):
		var cached: BoxMesh = _meshes[key]
		return cached
	var m := Toon.box(s)
	_meshes[key] = m
	return m


## Sphère basse résolution partagée ; h < 2r donne un ellipsoïde aplati.
static func ball(r: float, h: float, seg := 8, rings := 4) -> SphereMesh:
	var rr := _qf(r)
	var hh := _qf(h)
	var key := "s%.4f_%.4f_%d_%d" % [rr, hh, seg, rings]
	if _meshes.has(key):
		var cached: SphereMesh = _meshes[key]
		return cached
	var m := SphereMesh.new()
	m.radius = rr
	m.height = hh
	m.radial_segments = seg
	m.rings = rings
	_meshes[key] = m
	return m


## Tore partagé (anneaux, cerclages, maillons).
static func torus(inner: float, outer: float, rings := 10, segs := 4) -> TorusMesh:
	var a := _qf(inner)
	var o := _qf(outer)
	var key := "t%.4f_%.4f_%d_%d" % [a, o, rings, segs]
	if _meshes.has(key):
		var cached: TorusMesh = _meshes[key]
		return cached
	var m := TorusMesh.new()
	m.inner_radius = a
	m.outer_radius = o
	m.rings = rings
	m.ring_segments = segs
	_meshes[key] = m
	return m


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


## Ajoute la surface `surf` d'un maillage au lot du matériau `m` (fusion par matériau).
static func _add(b: Dictionary, m: Material, mesh: Mesh, xf: Transform3D, surf := 0) -> void:
	var k := m.get_instance_id()
	if not b.has(k):
		var st0 := SurfaceTool.new()
		st0.begin(Mesh.PRIMITIVE_TRIANGLES)
		b[k] = [st0, m]
	var entry: Array = b[k]
	var st: SurfaceTool = entry[0]
	merge_into(st, mesh, xf, surf)


# ------------------------------------------------------------------ fusion rapide (copies CPU)

## Copie en mémoire des sommets d'une surface. SurfaceTool.append_from relit sinon le maillage sur la
## carte graphique à chaque pièce (GL Compatibility, WebGL : attente du GPU) ; ici une seule lecture par
## maillage différent, puis la fusion se fait en C++ comme avant (même résultat, mêmes sommets).
class CpuMesh extends Mesh:
	var arrays: Array = []
	var prim: int = Mesh.PRIMITIVE_TRIANGLES
	var fmt: int = 0
	var bounds := AABB()

	func _get_surface_count():
		return 1

	func _surface_get_array_len(_index):
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			return v.size()
		return 0

	func _surface_get_array_index_len(_index):
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			var v: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			return v.size()
		return 0

	func _surface_get_arrays(_index):
		return arrays

	func _surface_get_format(_index):
		return fmt

	func _surface_get_primitive_type(_index):
		return prim

	func _surface_get_material(_index):
		return null

	func _surface_set_material(_index, _material):
		pass

	func _get_blend_shape_count():
		return 0

	func _get_aabb():
		return bounds


static var _cpu: Dictionary = {}  # clé (paramètres ou identifiant) -> CpuMesh
static var _unit_box: CpuMesh = null
static var _cpu_ok := 0  # désactivé : un Mesh écrit en script n'est pas accepté par SurfaceTool.append_from (ancien chemin)
const CPU_MAX := 2048  # au-delà, le cache repart de zéro (maillages uniques jetables)


## Ajoute `mesh` (surface `surf`), placé par `xf`, au SurfaceTool `st` — sans relecture GPU.
## Les boîtes deviennent une boîte unité mise à l'échelle (mêmes sommets, normales dans le même sens).
static func merge_into(st: SurfaceTool, mesh: Mesh, xf: Transform3D, surf := 0) -> void:
	if _cpu_ok == 0 or mesh is CpuMesh:
		st.append_from(mesh, surf, xf)
		return
	var bm := mesh as BoxMesh
	if bm != null and surf == 0 and _unit_ok(bm):
		if _unit_box == null:
			_unit_box = _cpu_of(BoxMesh.new(), 0)
		st.append_from(_unit_box, 0, xf * Transform3D(Basis.from_scale(bm.size), Vector3.ZERO))
		return
	var key := _cpu_key(mesh, surf)
	if key == "":
		st.append_from(mesh, surf, xf)
		return
	var c: CpuMesh = _cpu.get(key, null)
	if c == null:
		if _cpu.size() >= CPU_MAX:
			_cpu.clear()
		c = _cpu_of(mesh, surf)
		_cpu[key] = c
	st.append_from(c, 0, xf)


## Boîte simple (sans subdivision ni UV2), de taille strictement positive.
static func _unit_ok(bm: BoxMesh) -> bool:
	if bm.subdivide_width != 0 or bm.subdivide_height != 0 or bm.subdivide_depth != 0 or bm.add_uv2 or bm.flip_faces:
		return false
	return bm.size.x > 0.00001 and bm.size.y > 0.00001 and bm.size.z > 0.00001


## Copie CPU d'un SurfaceTool qu'on vient de remplir (maillage jetable : rien n'est envoyé au GPU).
static func cpu_from(st: SurfaceTool) -> Mesh:
	if _cpu_ok == 0:
		return st.commit()
	var c := CpuMesh.new()
	c.arrays = st.commit_to_arrays()
	c.prim = Mesh.PRIMITIVE_TRIANGLES
	return c


static func _cpu_of(mesh: Mesh, surf: int) -> CpuMesh:
	var c := CpuMesh.new()
	c.arrays = mesh.surface_get_arrays(surf)
	c.prim = mesh.surface_get_primitive_type(surf)
	c.fmt = mesh.surface_get_format(surf)
	c.bounds = mesh.get_aabb()
	return c


## Clé de cache : paramètres des primitives (deux cylindres égaux partagent leurs sommets), identifiant
## pour les maillages faits main (jamais modifiés après coup) ; "" : pas de cache.
static func _cpu_key(mesh: Mesh, surf: int) -> String:
	if mesh is CpuMesh:
		return ""
	var pm := mesh as PrimitiveMesh
	if pm != null:
		if surf != 0 or pm.add_uv2 or pm.flip_faces:
			return ""
		var cm := mesh as CylinderMesh
		if cm != null:
			return "c%s|%s|%s|%d|%d|%d%d" % [cm.top_radius, cm.bottom_radius, cm.height, cm.radial_segments, cm.rings,
				1 if cm.cap_top else 0, 1 if cm.cap_bottom else 0]
		var sm := mesh as SphereMesh
		if sm != null:
			return "s%s|%s|%d|%d|%d" % [sm.radius, sm.height, sm.radial_segments, sm.rings, 1 if sm.is_hemisphere else 0]
		var tm := mesh as TorusMesh
		if tm != null:
			return "t%s|%s|%d|%d" % [tm.inner_radius, tm.outer_radius, tm.rings, tm.ring_segments]
		var bx := mesh as BoxMesh
		if bx != null:
			return "b%s|%d|%d|%d" % [bx.size, bx.subdivide_width, bx.subdivide_height, bx.subdivide_depth]
		return ""
	if mesh is ArrayMesh:
		return "i%d|%d" % [mesh.get_instance_id(), surf]
	return ""


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


## Segment conique de a vers c (branche, tige, griffe) : r0 au départ, r1 au bout ; `xf` place le tout.
static func _limb(b: Dictionary, m: Material, a: Vector3, c: Vector3, r0: float, r1: float, sides := 7, xf := Transform3D.IDENTITY) -> void:
	var d := c - a
	var l := d.length()
	if l < 0.001:
		return
	_add(b, m, cyl(r1, r0, l, sides), xf * Transform3D(_basis_y(d), (a + c) * 0.5))


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


# ------------------------------------------------------------------ toits incurvés (profil extrudé)

## Toit japonais à quatre pans (yosemune ; hōgyō de pagode si `rl` = 0) : pans incurvés, presque plats à
## l'égout et raides vers le faîtage, coins relevés (sori) et un peu sortis, bandeau d'égout épais `t`,
## sous-face fermée (le contour d'encre reste propre). Empreinte w × d (x, z) au dessus de l'égout (y = 0),
## faîtage à `h` le long de x, long de `rl` × w. `lift` : relevé des coins en fraction de h.
## Maillage partagé (cache) : à fusionner dans les lots comme une primitive.
static func roof_mesh(w: float, d: float, h: float, rl := 0.0, lift := 0.35, t := 0.06) -> ArrayMesh:
	var qw := _qf(w)
	var qd := _qf(d)
	var qh := _qf(h)
	var qt := _qf(t)
	var key := "roof%.4f_%.4f_%.4f_%.2f_%.2f_%.4f" % [qw, qd, qh, rl, lift, qt]
	if _meshes.has(key):
		var cached: ArrayMesh = _meshes[key]
		return cached
	var hw := qw * 0.5
	var hd := qd * 0.5
	var r := clampf(rl, 0.0, 0.95) * hw
	var lf := lift * qh
	var c0 := Vector3(-hw, 0, hd)
	var c1 := Vector3(hw, 0, hd)
	var c2 := Vector3(hw, 0, -hd)
	var c3 := Vector3(-hw, 0, -hd)
	var t0 := Vector3(-r, qh, 0)
	var t1 := Vector3(r, qh, 0)
	# pans : [égout A, égout B, faîtage A, faîtage B, normale horizontale sortante]
	var faces: Array = [[c0, c1, t0, t1, Vector3(0, 0, 1)], [c1, c2, t1, t1, Vector3(1, 0, 0)],
		[c2, c3, t1, t0, Vector3(0, 0, -1)], [c3, c0, t0, t0, Vector3(-1, 0, 0)]]
	var ns := 6
	var nu := 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var down := Vector3(0, -qt, 0)
	for f in faces:
		var fa: Array = f
		var ea: Vector3 = fa[0]
		var eb: Vector3 = fa[1]
		var ta: Vector3 = fa[2]
		var tb: Vector3 = fa[3]
		var out: Vector3 = fa[4]
		var grid: Array[PackedVector3Array] = []
		var norms: Array[PackedVector3Array] = []
		for i in ns + 1:
			var s := float(i) / ns
			var row := PackedVector3Array()
			var nrow := PackedVector3Array()
			for j in nu + 1:
				var u := float(j) / nu
				row.append(_roof_pt(ea, eb, ta, tb, s, u, qh, lf))
				# normale par différences finies (u borné : le faîtage d'un pan en triangle est un point)
				var uu := minf(u, 0.9)
				var ds := _roof_pt(ea, eb, ta, tb, minf(s + 0.02, 1.0), uu, qh, lf) - _roof_pt(ea, eb, ta, tb, maxf(s - 0.02, 0.0), uu, qh, lf)
				var du := _roof_pt(ea, eb, ta, tb, s, uu + 0.05, qh, lf) - _roof_pt(ea, eb, ta, tb, s, maxf(uu - 0.05, 0.0), qh, lf)
				var n := ds.cross(du).normalized()
				if n.dot(out + Vector3(0, 0.6, 0)) < 0.0:
					n = -n
				nrow.append(n)
			grid.append(row)
			norms.append(nrow)
		for i in ns:
			var g0: PackedVector3Array = grid[i]
			var g1: PackedVector3Array = grid[i + 1]
			var m0: PackedVector3Array = norms[i]
			var m1: PackedVector3Array = norms[i + 1]
			for j in nu:
				_tri_s(st, g0[j], g1[j], g1[j + 1], m0[j], m1[j], m1[j + 1])
				_tri_s(st, g0[j], g1[j + 1], g0[j + 1], m0[j], m1[j + 1], m0[j + 1])
			# bandeau d'égout (épaisseur du toit) et sous-face
			var e0 := g0[0]
			var e1 := g1[0]
			_tri_s(st, e0, e1, e1 + down, out, out, out)
			_tri_s(st, e0, e1 + down, e0 + down, out, out, out)
			_tri_s(st, e0 + down, e1 + down, down, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## Point du pan : (s le long de l'égout, u de l'égout vers le faîtage). Coins relevés et sortis.
static func _roof_pt(ea: Vector3, eb: Vector3, ta: Vector3, tb: Vector3, s: float, u: float, h: float, lf: float) -> Vector3:
	var k := pow(absf(2.0 * s - 1.0), 3.0)
	var e := ea.lerp(eb, s)
	e = Vector3(e.x * (1.0 + 0.07 * k), lf * k, e.z * (1.0 + 0.07 * k))
	var tp := ta.lerp(tb, s)
	var q := e.lerp(tp, u)
	q.y = lerpf(e.y, h, pow(u, 1.5))
	return q


## Toit incurvé ajouté au lot `b` (matériau `m`), placé par `xf` (voir roof_mesh), et son faîtage :
## poutre ronde (kamune) et tuiles de bout (onigawara) dans le lot `bn` (matériau `ridge`).
static func roof_into(b: Dictionary, bn: Dictionary, m: Material, ridge: Material, xf: Transform3D, w: float, d: float, h: float, rl := 0.0, lift := 0.35) -> void:
	var t := clampf(minf(w, d) * 0.04, 0.025, 0.12)
	_add(b, m, roof_mesh(w, d, h, rl, lift, t), xf)
	var r := clampf(rl, 0.0, 0.95) * w * 0.5
	var rr := clampf(minf(w, d) * 0.035, 0.02, 0.1)
	if r > 0.05:
		_add(bn, ridge, cyl(rr, rr, r * 2.0 + rr * 2.0, 6), xf * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0, h + rr * 0.4, 0)))
		for sx: float in [-1.0, 1.0]:
			_add(bn, ridge, box(Vector3(rr * 1.6, rr * 3.2, rr * 3.0)), xf * _at(Vector3(sx * (r + rr), h + rr * 1.2, 0)))
	else:
		# hōgyō : bouton au sommet
		_add(bn, ridge, ball(rr * 1.6, rr * 3.0, 6, 3), xf * _at(Vector3(0, h + rr, 0)))


## Mon (blason de clan) plat, face à +Z local, rayon `r` : cercle (anneau) et motif au centre.
## 0 : trois tomoe stylisés, 1 : deux barres (maru ni ni-no-ji), 2 : losange (hishi), 3 : étoile de shuriken.
static func mon_into(b: Dictionary, m: Material, xf: Transform3D, r: float, kind: int) -> void:
	var th := 0.012
	var ring := torus(r * 0.82, r, 16, 3)
	_add(b, m, ring, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.0, 0.4)), Vector3.ZERO))
	match kind:
		0:
			for k in 3:
				var a := TAU * k / 3.0 + 0.3
				var c := Vector3(cos(a), sin(a), 0) * r * 0.32
				_add(b, m, ball(r * 0.2, r * 0.4, 7, 3), xf * Transform3D(Basis.from_scale(Vector3(1, 1, 0.25)), c))
				var tail := Vector3(cos(a + 1.3), sin(a + 1.3), 0) * r * 0.42
				_add(b, m, cyl(0.0, r * 0.09, r * 0.34, 4), xf * Transform3D(_basis_y(tail - c).scaled(Vector3(1, 1, 0.3)), (c + tail) * 0.5))
		1:
			for sy: float in [-1.0, 1.0]:
				var wl := r * (1.2 if sy > 0.0 else 1.0)
				_add(b, m, box(Vector3(wl, r * 0.16, th)), xf * _at(Vector3(0, sy * r * 0.22, 0)))
		2:
			_add(b, m, box(Vector3(r * 0.7, r * 0.7, th)), xf * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25).scaled(Vector3(1.0, 0.75, 1.0)), Vector3.ZERO))
		_:
			for k in 4:
				var a := PI * 0.5 * k + PI * 0.25
				_add(b, m, cyl(0.0, r * 0.16, r * 0.62, 4), xf * Transform3D(Basis(Vector3(0, 0, 1), a).scaled(Vector3(1, 1, 0.2)), Vector3(cos(a + PI * 0.5), sin(a + PI * 0.5), 0) * r * 0.3))
			_add(b, m, cyl(r * 0.12, r * 0.12, th, 8), xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))


# ------------------------------------------------------------------ cerisier

## Cerisier en fleurs (tronc tordu, branches, 6-10 amas roses, pétales au sol) ajouté aux lots partagés (tronc et fleurs dans `bs`, pétales au sol dans `bn`).
static func sakura_into(bs: Dictionary, bn: Dictionary, xf: Transform3D, sd := 0) -> void:
	var rng := _rng(sd)
	var x2 := xf * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3.ZERO)
	_sakura_build(bs, bs, bn, rng, x2)


static func _sakura_build(wood: Dictionary, bloom: Dictionary, ground: Dictionary, rng: RandomNumberGenerator, xf: Transform3D) -> void:
	var bark := _toon("sakura_bark", BARK_SAKURA)
	var pinks: Array[StandardMaterial3D] = []
	for i in SAKURA.size():
		var c: Color = SAKURA[i]
		pinks.append(_toon("sakura_%d" % i, c, true, 0.03))

	# tronc tordu : segments qui dérivent, pied évasé, rotules aux coudes
	_add(wood, bark, cyl(0.15, 0.26, 0.22, 7), xf * _at(Vector3(0, 0.11, 0)))
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
		_limb(wood, bark, pts[i], pts[i + 1], r0, r1, 7, xf)
		_add(wood, bark, ball(r1 * 1.05, r1 * 2.1, 7, 3), xf * _at(pts[i + 1]))

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
		_limb(wood, bark, start, mid, 0.065, 0.045, 6, xf)
		_add(wood, bark, ball(0.047, 0.094, 6, 3), xf * _at(mid))
		_limb(wood, bark, mid, tip, 0.045, 0.025, 6, xf)
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
		_add(bloom, pinks[rng.randi_range(0, pinks.size() - 1)], ball(r, r * 1.3, 8, 4),
			xf * _at(c + Vector3(0, r * 0.15, 0), Vector3(0, rng.randf() * TAU, 0)))
		for j in rng.randi_range(1, 2):
			var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.4), rng.randf_range(-1, 1)).normalized() * r * 0.85
			var r2 := r * rng.randf_range(0.45, 0.65)
			_add(bloom, pinks[rng.randi_range(0, pinks.size() - 1)], ball(r2, r2 * 1.3, 7, 3), xf * _at(c + off))

	# tapis de pétales tombés (petits disques plats, sans ombre)
	var petal_m := _toon("sakura_ground", SAKURA[2], false)
	for i in rng.randi_range(8, 12):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 1.3
		var pr := rng.randf_range(0.04, 0.07)
		_add(ground, petal_m, cyl(pr, pr, 0.008, 6), xf * _at(Vector3(cos(a) * d, 0.006, sin(a) * d)))


# ------------------------------------------------------------------ pin

## Pin japonais (matsu : tronc en S penché, plateaux d'aiguilles) ajouté au lot partagé `bs`.
static func pine_into(bs: Dictionary, xf: Transform3D, sd := 0) -> void:
	var rng := _rng(sd)
	var x2 := xf * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3.ZERO)
	_pine_build(bs, bs, rng, true, x2)


static func _pine_build(wood: Dictionary, leaf: Dictionary, rng: RandomNumberGenerator, near: bool, xf: Transform3D) -> void:
	var pre: String = "pine_" if near else "pine_far_"
	var bark := _toon(pre + "bark", BARK_PINE, near, 0.03)
	var greens: Array[StandardMaterial3D] = [_toon(pre + "b", PINE_B, near, 0.03),
		_toon(pre + "a", PINE_A, near, 0.03), _toon(pre + "hi", PINE_HI, near, 0.03)]

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
	_add(wood, bark, cyl(0.15, 0.24, 0.2, 7), xf * _at(Vector3(0, 0.1, 0)))
	for i in nseg:
		var r0 := lerpf(0.15, 0.06, float(i) / nseg)
		var r1 := lerpf(0.15, 0.06, float(i + 1) / nseg)
		_limb(wood, bark, pts[i], pts[i + 1], r0, r1, 7, xf)
		_add(wood, bark, ball(r1, r1 * 2.0, 7, 3), xf * _at(pts[i + 1]))

	# étages de branches horizontales (angle d'or), chacune terminée par un plateau
	var ang := rng.randf() * TAU
	for i in range(2, nseg + 1):
		ang += 2.4 + rng.randf_range(-0.3, 0.3)
		var start: Vector3 = pts[i]
		var reach := rng.randf_range(0.55, 0.95) * (1.15 - 0.12 * i)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var end := start + dir * reach + Vector3(0, rng.randf_range(-0.05, 0.12), 0)
		_limb(wood, bark, start, end, 0.05, 0.028, 5, xf)
		var lvl: int = 0 if i < 4 else 1
		_pad(leaf, greens, rng, end + Vector3(0, 0.06, 0), rng.randf_range(0.45, 0.65) * (1.1 - 0.08 * i), lvl, xf)
	# couronne
	_pad(leaf, greens, rng, pts[nseg] + Vector3(0, 0.1, 0), rng.randf_range(0.48, 0.6), 1, xf)


## Plateau d'aiguilles : coussin aplati, 2-3 petits coussins autour, reflet plus clair dessus.
static func _pad(b: Dictionary, greens: Array[StandardMaterial3D], rng: RandomNumberGenerator, c: Vector3, r: float, lvl: int, xf := Transform3D.IDENTITY) -> void:
	_add(b, greens[lvl], ball(r, r * 0.42, 9, 4), xf * _at(c))
	for j in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		var rr := r * rng.randf_range(0.45, 0.62)
		var off := Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.55, 0.8) + Vector3(0, rng.randf_range(0.0, 0.07), 0)
		_add(b, greens[lvl], ball(rr, rr * 0.5, 8, 3), xf * _at(c + off))
	var hi := Vector3(rng.randf_range(-0.08, 0.08), r * 0.17, rng.randf_range(-0.08, 0.08))
	_add(b, greens[mini(lvl + 1, 2)], ball(r * 0.62, r * 0.3, 8, 3), xf * _at(c + hi))


# ------------------------------------------------------------------ bambous

## Bosquet de 5-9 tiges à nœuds, feuilles en fer de lance, une ou deux pousses, ajouté aux lots partagés (tiges dans `bs`, feuilles dans `bn`).
static func bamboo_into(bs: Dictionary, bn: Dictionary, xf: Transform3D, sd := 0) -> void:
	_bamboo_build(bs, bn, _rng(sd), xf)


static func _bamboo_build(stems: Dictionary, leaves: Dictionary, rng: RandomNumberGenerator, xf: Transform3D) -> void:
	var stem_m := _toon("bamboo_stem", BAMBOO, true, 0.018)
	var node_m := _toon("bamboo_node", BAMBOO_NODE, true, 0.018)
	var shoot_m := _toon("bamboo_shoot", SHOOT, true, 0.02)
	var leaf_a := _toon("bamboo_leaf_a", BAMBOO_LEAF, false)
	var leaf_b := _toon("bamboo_leaf_b", BAMBOO_LEAF.darkened(0.2), false)
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
		_limb(stems, stem_m, base, top, r, r * 0.8, 6, xf)
		var axis := (top - base).normalized()
		var bas := _basis_y(axis)
		var seg := rng.randf_range(0.38, 0.5)
		var t := seg
		while t < h - 0.1:
			var pn := base + axis * t
			_add(stems, node_m, cyl(r * 1.25, r * 1.25, 0.03, 6), xf * Transform3D(bas, pn))
			if t > h * 0.45 and rng.randf() < 0.55:
				for j in rng.randi_range(2, 3):
					var yaw := rng.randf() * TAU
					var ll := rng.randf_range(0.22, 0.34)
					var dir := Vector3(cos(yaw), rng.randf_range(-0.55, -0.1), sin(yaw)).normalized()
					var lm: StandardMaterial3D = leaf_a if rng.randf() < 0.6 else leaf_b
					_limb(leaves, lm, pn, pn + dir * ll, 0.03, 0.0, 3, xf)
			t += seg
		# panache au sommet
		for j in 3:
			var yaw := rng.randf() * TAU
			var dir := Vector3(cos(yaw), rng.randf_range(-0.2, 0.35), sin(yaw)).normalized()
			_limb(leaves, leaf_a, top, top + dir * rng.randf_range(0.25, 0.36), 0.03, 0.0, 3, xf)
	# pousses (takenoko) au pied
	for i in rng.randi_range(1, 2):
		var a := rng.randf() * TAU
		var q := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.45, 0.65)
		_limb(stems, shoot_m, q, q + Vector3(0, rng.randf_range(0.14, 0.22), 0), 0.06, 0.0, 6, xf)


# ------------------------------------------------------------------ lanternes

## Tōrō de pierre (socle hexagonal, pied, plateau, chambre à feu dorée, toit à 6 pans relevés, hōju) ajouté aux lots partagés, sans lumière (le cœur reste lumineux).
static func stone_lantern_into(bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	_lantern_build(bs, bn, xf)


static func _lantern_build(b: Dictionary, small: Dictionary, xf: Transform3D) -> void:
	var stone := _toon("stone", STONE, true, 0.025)
	var dark := _toon("stone_dark", STONE.darkened(0.18), true, 0.025)
	var glow := _glow("lantern_glow", GLOW, 1.0)
	var moss := _toon("moss", MOSS, false)
	# socle à deux gradins
	_add(b, stone, cyl(0.27, 0.3, 0.1, 6), xf * _at(Vector3(0, 0.05, 0)))
	_add(b, stone, cyl(0.2, 0.24, 0.08, 6), xf * _at(Vector3(0, 0.14, 0)))
	# pied (sao) et son anneau
	_add(b, stone, cyl(0.075, 0.095, 0.42, 8), xf * _at(Vector3(0, 0.39, 0)))
	_add(b, dark, cyl(0.1, 0.1, 0.04, 8), xf * _at(Vector3(0, 0.4, 0)))
	# plateau (chūdai)
	_add(b, stone, cyl(0.24, 0.14, 0.1, 6), xf * _at(Vector3(0, 0.65, 0)))
	# chambre à feu : cœur lumineux entre 6 montants
	_add(small, glow, cyl(0.12, 0.12, 0.22, 6), xf * _at(Vector3(0, 0.81, 0)))
	for k in 6:
		var a := TAU * k / 6.0
		_add(b, stone, box(Vector3(0.05, 0.22, 0.05)),
			xf * Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.16, 0.81, cos(a) * 0.16)))
	_add(b, stone, cyl(0.2, 0.2, 0.04, 6), xf * _at(Vector3(0, 0.94, 0)))
	# toit à 6 pans, bordure, angles relevés (warabite)
	_add(b, dark, cyl(0.38, 0.38, 0.03, 6), xf * _at(Vector3(0, 0.975, 0)))
	_add(b, stone, cyl(0.07, 0.38, 0.17, 6), xf * _at(Vector3(0, 1.075, 0)))
	for k in 6:
		var a := TAU * k / 6.0
		var corner := Vector3(sin(a) * 0.37, 1.02, cos(a) * 0.37)
		_add(b, stone, cyl(0.0, 0.035, 0.09, 4), xf * Transform3D(_basis_y(Vector3(sin(a) * 0.6, 1.0, cos(a) * 0.6)), corner))
	# bouton (hōju) : col, perle, pointe
	_add(b, stone, cyl(0.05, 0.07, 0.05, 6), xf * _at(Vector3(0, 1.185, 0)))
	_add(b, stone, ball(0.07, 0.13, 8, 4), xf * _at(Vector3(0, 1.27, 0)))
	_add(b, stone, cyl(0.0, 0.035, 0.07, 6), xf * _at(Vector3(0, 1.35, 0)))
	# touches de mousse sur le toit
	for k in 2:
		var a := TAU * (0.15 + 0.4 * k)
		_add(small, moss, ball(0.08, 0.05, 6, 3), xf * _at(Vector3(sin(a) * 0.22, 1.07, cos(a) * 0.22)))


## Chōchin (lanterne de papier allongée et lumineuse, cerclages, coiffes noires) sur potence ajouté aux lots partagés ; le poteau descend jusqu'à `low_y` (local).
static func paper_lantern_into(bs: Dictionary, bn: Dictionary, xf: Transform3D, color: Color, low_y := 0.0) -> void:
	_chochin_build(bs, bn, xf, color, low_y)


static func _chochin_build(b: Dictionary, small: Dictionary, xf: Transform3D, color: Color, low_y: float) -> void:
	var key := color.to_html(false)
	var pole_m := _toon("pole", POLE, true, 0.02)
	var black := _toon("sumi_plain", Toon.SUMI, false)
	var body := _glow("chochin_" + key, color, 0.55, true)
	var rib := _toon("chochin_rib_" + key, color.darkened(0.35), false)
	# poteau, potence et jambe de force
	if low_y < -0.01:
		var hh := 1.9 - low_y
		_add(b, pole_m, cyl(0.035, 0.045, hh, 6), xf * _at(Vector3(0, low_y + hh * 0.5, 0)))
	else:
		_add(b, pole_m, box(Vector3(0.16, 0.08, 0.16)), xf * _at(Vector3(0, 0.04, 0)))
		_add(b, pole_m, cyl(0.035, 0.045, 1.9, 6), xf * _at(Vector3(0, 0.95, 0)))
	_add(b, pole_m, box(Vector3(0.52, 0.05, 0.05)), xf * _at(Vector3(0.22, 1.86, 0)))
	_limb(b, pole_m, Vector3(0, 1.62, 0), Vector3(0.22, 1.85, 0), 0.018, 0.018, 4, xf)
	# cordon puis lanterne
	var hx := 0.4
	_limb(small, black, Vector3(hx, 1.84, 0), Vector3(hx, 1.72, 0), 0.008, 0.008, 4, xf)
	var cy := 1.47
	_add(b, body, ball(0.18, 0.42, 10, 6), xf * _at(Vector3(hx, cy, 0)))
	_add(small, black, cyl(0.1, 0.1, 0.05, 10), xf * _at(Vector3(hx, cy + 0.225, 0)))
	_add(small, black, cyl(0.1, 0.1, 0.05, 10), xf * _at(Vector3(hx, cy - 0.225, 0)))
	for dy: float in [-0.12, 0.0, 0.12]:
		var rr := 0.18 * sqrt(1.0 - pow(dy / 0.21, 2.0))
		_add(small, rib, torus(rr - 0.006, rr + 0.01, 12, 4), xf * _at(Vector3(hx, cy + dy, 0)))
	# gland sous la coiffe
	_add(small, black, cyl(0.012, 0.03, 0.12, 5), xf * _at(Vector3(hx, cy - 0.31, 0)))


# ------------------------------------------------------------------ rochers

## Rocher irrégulier facetté (sphère basse résolution déformée, mousse au sommet) ajouté au lot partagé (facettes + contour d'encre : 2 matériaux pour tous les rochers).
## `base` change la teinte (rochers volcaniques, enneigés…).
static func rock_into(bs: Dictionary, xf: Transform3D, sd := 0, base := ROCK) -> void:
	var rng := _rng(sd)
	var x2 := xf * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3.ZERO)
	var rad := Vector3(rng.randf_range(0.5, 0.7), rng.randf_range(0.35, 0.5), rng.randf_range(0.45, 0.6))
	# copies CPU des deux surfaces : le rocher n'est jamais envoyé seul au GPU, juste fusionné
	var sts: Array = _rock_tools(rng, rad, true, base)
	var st0: SurfaceTool = sts[0]
	var st1: SurfaceTool = sts[1]
	_add(bs, _toon_vc("rock_vc"), cpu_from(st0), x2, 0)
	_add(bs, _ink(0.03), cpu_from(st1), x2, 0)


## Surfaces du rocher remplies (facettes, puis contour si `near`, sinon null), pas encore validées.
static func _rock_tools(rng: RandomNumberGenerator, rad: Vector3, near: bool, base: Color) -> Array:
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
		# pied du rocher dans l'ombre (occlusion peinte dans les couleurs de sommets)
		var hk := clampf((out.y / maxf(rad.y, 0.01) + 0.35) / 1.17, 0.0, 1.0)
		col = col.darkened(0.24 * (1.0 - hk))
		st.set_color(col)
		st.set_normal(n)
		_tri_o(st, a, b, c, out)
	var st2: SurfaceTool = null
	if near:
		st2 = SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f in range(0, tris.size(), 3):
			var a: Vector3 = pts[tris[f]]
			var b: Vector3 = pts[tris[f + 1]]
			var c: Vector3 = pts[tris[f + 2]]
			_tri_s(st2, a, b, c, a.normalized(), b.normalized(), c.normalized())
	return [st, st2]


# ------------------------------------------------------------------ shimenawa

## Corde sacrée torsadée (deux brins, plus épaisse au milieu, shide et touffes de paille) de a à b (coordonnées du parent des lots) ajoutée aux lots partagés.
static func shimenawa_into(bs: Dictionary, bn: Dictionary, a: Vector3, b: Vector3) -> void:
	_shimenawa_build(bs, bn, b - a, Transform3D(Basis(), a))


static func _shimenawa_build(rope_b: Dictionary, bits: Dictionary, d: Vector3, xf: Transform3D) -> void:
	var span := d.length()
	if span < 0.05:
		return
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
	_add(rope_b, straw, cpu_from(st), xf)

	# nœuds aux extrémités
	_add(bits, straw, ball(r0 * 0.7, r0 * 1.4, 7, 4), xf)
	_add(bits, straw, ball(r0 * 0.7, r0 * 1.4, 7, 4), xf * _at(d))
	# shide en zigzag, touffes de paille entre eux
	var nshide := 4 if span > 1.6 else 3
	for i in nshide:
		var t := (float(i) + 0.5) / nshide
		_shide(bits, paper, _sag(d, sag, t) - Vector3(0, r0 * 0.6, 0), along, xf)
		if i < nshide - 1:
			var q := _sag(d, sag, (float(i) + 1.0) / nshide) - Vector3(0, r0 * 0.5, 0)
			_limb(bits, straw, q, q - Vector3(0, 0.16 + r0, 0), 0.03, 0.006, 5, xf)


## Point de la corde (chaînette approchée par une parabole).
static func _sag(d: Vector3, sag: float, t: float) -> Vector3:
	return d * t + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)


## Shide : bande de papier blanc pliée en éclair (4 rectangles décalés).
static func _shide(b: Dictionary, m: Material, top: Vector3, along: Vector3, xf := Transform3D.IDENTITY) -> void:
	var bas := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var w := 0.075
	var h := 0.09
	for k in 4:
		var dx: float = 0.034 if k % 2 == 1 else 0.0
		var c := top + along * dx - Vector3(0, h * 0.5 + h * 0.85 * k, 0)
		_add(b, m, box(Vector3(w, h, 0.006)), xf * Transform3D(bas, c))


# ------------------------------------------------------------------ torii

## Torii : socles noirs, piliers vermillon, nuki et kusabi, gakuzuka + plaque, shimaki, kasagi incurvé.
static func torii(parent: Node3D, pos: Vector3, s := 1.0) -> Node3D:
	var root := _root(parent, pos, s, "Torii")
	var b := {}
	_torii_build(b, Transform3D.IDENTITY, -1.0)
	_flush(b, root)
	return root


## Torii ajouté au lot partagé ; `low_y` (local) > -1 : piliers prolongés jusque-là (dans l'eau).
static func torii_into(bs: Dictionary, xf: Transform3D, low_y := 0.0) -> void:
	_torii_build(bs, xf, low_y)


static func _torii_build(b: Dictionary, xf: Transform3D, low_y: float) -> void:
	var red := _toon("torii_red", Toon.VERMILION)
	var black := _toon("torii_black", Toon.SUMI)
	var gold := _toon("torii_gold", Toon.GOLD, false)
	var px := 2.2
	for sx: float in [-1.0, 1.0]:
		var x := sx * px
		# kamebara (socle noir évasé) et nemaki
		_add(b, black, cyl(0.21, 0.27, 0.4, 12), xf * _at(Vector3(x, 0.2, 0)))
		if low_y < -0.05:
			_add(b, black, cyl(0.27, 0.27, -low_y, 12), xf * _at(Vector3(x, low_y * 0.5, 0)))
		_add(b, black, cyl(0.2, 0.2, 0.06, 12), xf * _at(Vector3(x, 0.43, 0)))
		# hashira : pilier légèrement conique
		_add(b, red, cyl(0.155, 0.18, 2.55, 12), xf * _at(Vector3(x, 1.675, 0)))
		# daiwa : anneau noir sous le shimaki
		_add(b, black, cyl(0.19, 0.19, 0.1, 12), xf * _at(Vector3(x, 2.9, 0)))
		# kusabi : coin qui bloque le nuki
		_add(b, red, box(Vector3(0.07, 0.3, 0.22)), xf * _at(Vector3(x + sx * 0.23, 2.45, 0)))
	# nuki : traverse basse qui dépasse
	_add(b, red, box(Vector3(5.7, 0.2, 0.16)), xf * _at(Vector3(0, 2.45, 0)))
	# gakuzuka et plaque (gaku) noire cerclée d'or
	_add(b, red, box(Vector3(0.22, 0.44, 0.16)), xf * _at(Vector3(0, 2.76, 0)))
	_add(b, black, box(Vector3(0.44, 0.52, 0.06)), xf * _at(Vector3(0, 2.74, 0.12)))
	_add(b, gold, box(Vector3(0.32, 0.4, 0.02)), xf * _at(Vector3(0, 2.74, 0.155)))
	# shimaki : linteau vermillon droit
	_add(b, red, box(Vector3(5.9, 0.2, 0.34)), xf * _at(Vector3(0, 3.05, 0)))
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
		_add(b, black, box(Vector3(l, 0.26, 0.48)), xf * Transform3D(Basis(Vector3(0, 0, 1), ang), mid))


# ------------------------------------------------------------------ accessoires (lots partagés)

## Komodaru : tonneau de saké emmailloté de paille, cordes sombres, étiquette frontale (+Z local).
static func sake_barrel_into(bs: Dictionary, bn: Dictionary, xf: Transform3D, label := LABEL) -> void:
	var straw := _toon("komo", KOMO, true, 0.02)
	var rope := _toon("komo_rope", ROPE_DARK, false)
	var lid := _toon("komo_lid", Color("#A88A5C"), true, 0.02)
	var paper := _toon("komo_label", SHIDE, false)
	var mark := _toon("komo_mark_" + label.to_html(false), label, false)
	_add(bs, straw, cyl(0.27, 0.27, 0.56, 10), xf * _at(Vector3(0, 0.28, 0)))
	_add(bs, lid, cyl(0.235, 0.255, 0.05, 10), xf * _at(Vector3(0, 0.585, 0)))
	for y: float in [0.07, 0.5]:
		_add(bn, rope, cyl(0.285, 0.285, 0.035, 10), xf * _at(Vector3(0, y, 0)))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_add(bn, rope, box(Vector3(0.03, 0.46, 0.03)), xf * _at(Vector3(cos(a) * 0.272, 0.29, sin(a) * 0.272)))
	_add(bn, paper, box(Vector3(0.26, 0.24, 0.03)), xf * _at(Vector3(0, 0.29, 0.255)))
	_add(bn, mark, box(Vector3(0.15, 0.13, 0.034)), xf * _at(Vector3(0, 0.29, 0.258)))


## Nobori : mât sombre, bannière verticale (face à +Z local) avec bande de tête et marques d'encre.
## `base_y` (local) : pied du mât (négatif pour descendre dans l'eau). `mon` ≥ 0 : blason de clan (mon_into)
## au lieu des « kanji » stylisés.
static func nobori_into(bs: Dictionary, bn: Dictionary, xf: Transform3D, cloth: Color, ink: Color, base_y := 0.0, mon := -1) -> void:
	var pole := _toon("pole", POLE, true, 0.02)
	var cm := _toon("nobori_" + cloth.to_html(false), cloth, true, 0.012)
	var im := _toon("nobori_ink_" + ink.to_html(false), ink, false)
	var top := 2.35
	var h := top - base_y
	_add(bs, pole, cyl(0.03, 0.04, h, 6), xf * _at(Vector3(0, base_y + h * 0.5, 0)))
	_add(bs, pole, ball(0.05, 0.1, 6, 3), xf * _at(Vector3(0, top + 0.03, 0)))
	_add(bs, pole, box(Vector3(0.48, 0.03, 0.03)), xf * _at(Vector3(0.22, top - 0.08, 0)))
	var bw := 0.38
	var bh := 1.45
	var bx := 0.25
	var by := top - 0.1 - bh * 0.5
	_add(bs, cm, box(Vector3(bw, bh, 0.012)), xf * _at(Vector3(bx, by, 0.0)))
	# bande de tête, bande de pied, « kanji » stylisés
	_add(bn, im, box(Vector3(bw + 0.004, 0.12, 0.016)), xf * _at(Vector3(bx, top - 0.18, 0)))
	_add(bn, im, box(Vector3(bw + 0.004, 0.05, 0.016)), xf * _at(Vector3(bx, by - bh * 0.5 + 0.06, 0)))
	if mon >= 0:
		for sz: float in [-1.0, 1.0]:
			mon_into(bn, im, xf * _at(Vector3(bx, by + 0.18, sz * 0.009), Vector3(0, 0.0 if sz > 0.0 else PI, 0)), 0.14, mon)
	else:
		for k in 3:
			var cy := by + 0.32 - k * 0.3
			_add(bn, im, box(Vector3(0.18 - k * 0.02, 0.04, 0.016)), xf * _at(Vector3(bx, cy, 0)))
			_add(bn, im, box(Vector3(0.035, 0.17, 0.016)), xf * _at(Vector3(bx + 0.035 * (k - 1), cy - 0.05, 0)))
	# anneaux (chichi) qui tiennent la bannière au mât
	for k in 4:
		_add(bn, im, cyl(0.045, 0.045, 0.025, 6), xf * _at(Vector3(0, by + bh * 0.4 - k * bh * 0.27, 0)))


## Hokora : petit sanctuaire de bois à toit à deux pans, portes, shimenawa et shide (face à +Z local).
static func hokora_into(bs: Dictionary, bn: Dictionary, xf: Transform3D, wood: Color, roof_c: Color) -> void:
	var wm := _toon("hokora_" + wood.to_html(false), wood, true, 0.02)
	var dark := _toon("hokora_door", Color("#2A221C"), false)
	var rm := _toon("hokora_roof_" + roof_c.to_html(false), roof_c, true, 0.02)
	var stone := _toon("stone", STONE, true, 0.025)
	var straw := _toon("straw", STRAW, true, 0.02)
	var paper := _toon("shide", SHIDE, true, 0.008)
	var gold := _toon("torii_gold", Toon.GOLD, false)
	_add(bs, stone, box(Vector3(0.62, 0.1, 0.52)), xf * _at(Vector3(0, 0.05, 0)))
	_add(bs, wm, box(Vector3(0.4, 0.36, 0.34)), xf * _at(Vector3(0, 0.28, 0)))
	_add(bn, dark, box(Vector3(0.26, 0.26, 0.02)), xf * _at(Vector3(0, 0.27, 0.171)))
	_add(bn, gold, box(Vector3(0.018, 0.26, 0.024)), xf * _at(Vector3(0, 0.27, 0.172)))
	# toit incurvé aux coins relevés (faîtage le long de Z) et sa poutre faîtière
	roof_into(bs, bs, rm, rm, xf * _at(Vector3(0, 0.46, 0), Vector3(0, PI * 0.5, 0)), 0.64, 0.6, 0.16, 0.55, 0.4)
	# chigi : planches croisées aux extrémités du faîtage
	for sz: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			_add(bs, wm, box(Vector3(0.025, 0.18, 0.025)), xf * _at(Vector3(sx * 0.04, 0.68, sz * 0.19), Vector3(0, 0, sx * 0.45)))
	# petite shimenawa et shide sur la façade
	_add(bn, straw, cyl(0.025, 0.025, 0.42, 6), xf * _at(Vector3(0, 0.44, 0.19), Vector3(0, 0, PI * 0.5)))
	for sx: float in [-1.0, 1.0]:
		_add(bn, paper, box(Vector3(0.04, 0.1, 0.006)), xf * _at(Vector3(sx * 0.09, 0.37, 0.2)))


## Clôture de bambou (yotsume-gaki) de a à c (coordonnées des lots) : poteaux jusqu'à `low_y`,
## lisses horizontales, fines tiges verticales et ligatures noires. `snow` : calottes blanches.
static func fence_into(bs: Dictionary, bn: Dictionary, a: Vector3, c: Vector3, h := 0.7, low_y := 0.0, snow := false) -> void:
	var post := _toon("fence_post", BAMBOO_NODE, true, 0.018)
	var rail := _toon("bamboo_stem", BAMBOO, true, 0.018)
	var cord := _toon("sumi_plain", Toon.SUMI, false)
	var cap := _toon("fence_snow", Color("#F2F5F8"), false)
	var d := c - a
	var l := Vector2(d.x, d.z).length()
	if l < 0.2:
		return
	var n := maxi(int(ceil(l / 0.6)), 1)
	var bas := _basis_y(Vector3(d.x, 0.0, d.z))
	for i in n + 1:
		var p := a.lerp(c, float(i) / n)
		var top_y := p.y + h + (0.08 if i % 2 == 0 else 0.0)
		var hh := top_y - low_y
		_add(bs, post, cyl(0.035, 0.04, hh, 6), Transform3D(Basis(), Vector3(p.x, low_y + hh * 0.5, p.z)))
		if snow:
			_add(bn, cap, ball(0.06, 0.06, 6, 3), Transform3D(Basis(), Vector3(p.x, top_y + 0.01, p.z)))
	for k in 3:
		var y := h * (0.28 + k * 0.3)
		var mid := (a + c) * 0.5 + Vector3(0, y, 0)
		_add(bs, rail, cyl(0.022, 0.022, l + 0.12, 6), Transform3D(bas, mid))
		if snow and k == 2:
			_add(bn, cap, box(Vector3(0.05, 0.03, l)), Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), mid + Vector3(0, 0.03, 0)))
		for i in n + 1:
			var p := a.lerp(c, float(i) / n)
			_add(bn, cord, cyl(0.045, 0.045, 0.03, 6), Transform3D(Basis(), Vector3(p.x, p.y + y, p.z)))
	var m := n * 3
	for i in m:
		var t := (float(i) + 0.5) / m
		var p := a.lerp(c, t)
		_add(bs, rail, cyl(0.016, 0.016, h * 0.85, 5), Transform3D(Basis(), p + Vector3(0, h * 0.45, 0)))


## Ukidama : flotteur de verre teinté pris dans un filet de corde.
static func glass_float_into(b: Dictionary, xf: Transform3D, tint := 0) -> void:
	var col: Color = GLASS[absi(tint) % GLASS.size()]
	var g := _glow("ukidama_%d" % (absi(tint) % GLASS.size()), col, 0.25)
	var net := _toon("komo_rope", ROPE_DARK, false)
	_add(b, g, ball(0.16, 0.32, 10, 5), xf * _at(Vector3(0, 0.12, 0)))
	_add(b, net, torus(0.155, 0.175, 12, 4), xf * _at(Vector3(0, 0.12, 0)))
	_add(b, net, torus(0.155, 0.175, 12, 4), xf * _at(Vector3(0, 0.12, 0), Vector3(PI * 0.5, 0, 0)))
	_add(b, net, torus(0.155, 0.175, 12, 4), xf * _at(Vector3(0, 0.12, 0), Vector3(0, 0, PI * 0.5)))


## Séchoir à filets : deux poteaux (jusqu'à `low_y`), perche, filet de pêche qui pend, flotteurs de liège.
static func net_rack_into(bs: Dictionary, bn: Dictionary, xf: Transform3D, low_y := 0.0) -> void:
	var pole := _toon("pole", POLE, true, 0.02)
	var net := _toon("net", Color("#4A4438"), false)
	var cork := _toon("cork", Color("#C9A46A"), true, 0.012)
	var w := 1.6
	var top := 1.5
	var hh := top - low_y
	for sx: float in [-1.0, 1.0]:
		_add(bs, pole, cyl(0.04, 0.05, hh, 6), xf * _at(Vector3(sx * w * 0.5, low_y + hh * 0.5, 0)))
	_add(bs, pole, cyl(0.03, 0.03, w + 0.3, 6), xf * _at(Vector3(0, top - 0.05, 0), Vector3(0, 0, PI * 0.5)))
	# mailles : verticales qui pendent, horizontales légèrement affaissées
	var nv := 9
	for i in nv:
		var x := lerpf(-w * 0.44, w * 0.44, float(i) / (nv - 1))
		var lv := 1.0 - 0.1 * sin(PI * float(i) / (nv - 1))
		_add(bn, net, box(Vector3(0.012, lv, 0.012)), xf * _at(Vector3(x, top - 0.05 - lv * 0.5, 0.01)))
	for k in 5:
		var y := top - 0.22 - k * 0.19
		_add(bn, net, box(Vector3(w * 0.88, 0.012, 0.012)), xf * _at(Vector3(0, y, 0.01)))
	for i in 6:
		_add(bn, cork, ball(0.05, 0.08, 6, 3), xf * _at(Vector3(lerpf(-0.65, 0.65, float(i) / 5.0), top - 1.07, 0.02)))


## Kadomatsu (Nouvel An) : trois bambous coupés en biseau, rameaux de pin et de prunier, socle de paille.
static func kadomatsu_into(bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var stem := _toon("bamboo_stem", BAMBOO, true, 0.018)
	var cut := _toon("kado_cut", Color("#E8DDB0"), false)
	var straw := _toon("straw", STRAW, true, 0.02)
	var rope := _toon("komo_rope", ROPE_DARK, false)
	var pine_m := _toon("pine_a", PINE_A, true, 0.03)
	var plum := _toon("kado_plum", SAKURA[0], false)
	_add(bs, straw, cyl(0.3, 0.33, 0.42, 10), xf * _at(Vector3(0, 0.21, 0)))
	for y: float in [0.1, 0.32]:
		_add(bn, rope, cyl(0.335, 0.335, 0.04, 10), xf * _at(Vector3(0, y, 0)))
	var hs := PackedFloat32Array([1.25, 1.02, 0.86])
	var offs: Array[Vector3] = [Vector3(0, 0, -0.08), Vector3(-0.1, 0, 0.07), Vector3(0.1, 0, 0.07)]
	for k in 3:
		var o: Vector3 = offs[k]
		var h := hs[k]
		_add(bs, stem, cyl(0.065, 0.07, h, 8), xf * _at(o + Vector3(0, h * 0.5, 0)))
		_add(bn, cut, cyl(0.075, 0.075, 0.012, 8), xf * _at(o + Vector3(0, h + 0.01, 0), Vector3(0.6, 0, 0)))
	for k in 5:
		var a := TAU * k / 5.0
		_add(bs, pine_m, ball(0.13, 0.1, 7, 3), xf * _at(Vector3(cos(a) * 0.26, 0.45 + (k % 2) * 0.06, sin(a) * 0.26)))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_add(bn, plum, ball(0.035, 0.06, 5, 3), xf * _at(Vector3(cos(a) * 0.2, 0.62 + (k % 2) * 0.12, sin(a) * 0.2)))


## Pont arqué (taiko-bashi) le long de l'axe X local : tablier en arc, garde-corps, giboshi, piles jusqu'à `low_y`.
static func arched_bridge_into(bs: Dictionary, xf: Transform3D, span: float, width: float, rail_c: Color, deck_c: Color, low_y := -0.6) -> void:
	var rail := _toon("bridge_rail_" + rail_c.to_html(false), rail_c, true, 0.02)
	var deck := _toon("bridge_deck_" + deck_c.to_html(false), deck_c, true, 0.02)
	var knob := _toon("bridge_knob", Toon.GOLD.darkened(0.1), true, 0.015)
	var rise := span * 0.2
	var half := span * 0.5
	var n := 10
	for i in n:
		var x0 := lerpf(-half, half, float(i) / n)
		var x1 := lerpf(-half, half, float(i + 1) / n)
		var y0 := rise * (1.0 - pow(x0 / half, 2.0))
		var y1 := rise * (1.0 - pow(x1 / half, 2.0))
		var mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0)
		var l := Vector2(x1 - x0, y1 - y0).length() + 0.02
		var bas := Basis(Vector3(0, 0, 1), atan2(y1 - y0, x1 - x0))
		_add(bs, deck, box(Vector3(l, 0.08, width)), xf * Transform3D(bas, mid))
		for sz: float in [-1.0, 1.0]:
			_add(bs, rail, box(Vector3(l, 0.05, 0.05)), xf * Transform3D(bas, mid + Vector3(0, 0.42, sz * width * 0.5)))
			_add(bs, rail, box(Vector3(l, 0.035, 0.035)), xf * Transform3D(bas, mid + Vector3(0, 0.22, sz * width * 0.5)))
	for i in range(0, n + 1, 2):
		var x := lerpf(-half, half, float(i) / n)
		var y := rise * (1.0 - pow(x / half, 2.0))
		for sz: float in [-1.0, 1.0]:
			_add(bs, rail, box(Vector3(0.06, 0.5, 0.06)), xf * _at(Vector3(x, y + 0.22, sz * width * 0.5)))
			if i == 0 or i == n:
				_add(bs, knob, ball(0.06, 0.14, 6, 3), xf * _at(Vector3(x, y + 0.53, sz * width * 0.5)))
	for xi: float in [-0.3, 0.3]:
		var x := xi * span
		var y := rise * (1.0 - pow(x / half, 2.0))
		var hh := y - low_y
		for sz: float in [-1.0, 1.0]:
			_add(bs, deck, cyl(0.07, 0.08, hh, 6), xf * _at(Vector3(x, low_y + hh * 0.5, sz * width * 0.35)))


## Katana planté pointe en terre : lame d'acier, habaki d'or, tsuba sombre, poignée tressée indigo.
static func katana_into(b: Dictionary, xf: Transform3D) -> void:
	var steel := _toon("katana_steel", STEEL, true, 0.01)
	var gold := _toon("torii_gold", Toon.GOLD, false)
	var tsuba := _toon("katana_tsuba", Color("#2B2A2E"), true, 0.01)
	var wrap := _toon("katana_wrap", Color("#2E3446"), true, 0.01)
	var same := _toon("katana_same", Color("#E9DFC9"), false)
	_add(b, steel, box(Vector3(0.05, 0.62, 0.012)), xf * _at(Vector3(0, 0.24, 0)))
	_add(b, steel, box(Vector3(0.047, 0.48, 0.012)), xf * _at(Vector3(0.012, 0.78, 0), Vector3(0, 0, -0.05)))
	_add(b, gold, box(Vector3(0.06, 0.05, 0.03)), xf * _at(Vector3(0.024, 1.04, 0)))
	_add(b, tsuba, cyl(0.075, 0.075, 0.02, 8), xf * _at(Vector3(0.026, 1.08, 0)))
	_add(b, wrap, cyl(0.022, 0.026, 0.4, 6), xf * _at(Vector3(0.036, 1.29, 0), Vector3(0, 0, -0.05)))
	for k in 3:
		_add(b, same, box(Vector3(0.03, 0.03, 0.05)), xf * _at(Vector3(0.033 + k * 0.004, 1.18 + k * 0.1, 0), Vector3(0, 0, PI * 0.25)))
	_add(b, gold, cyl(0.026, 0.024, 0.03, 6), xf * _at(Vector3(0.047, 1.505, 0)))


## Shōrō : beffroi de temple (4 poteaux, toit en croupe), cloche bonshō de bronze et poutre-battant.
static func bell_tower_into(bs: Dictionary, bn: Dictionary, xf: Transform3D, snow := false) -> void:
	var wood := _toon("shoro_wood", Color("#4A3428"), true, 0.025)
	var roof := _toon("shoro_roof", Color("#2E2C33"), true, 0.025)
	var bronze := _toon("bonsho", BRONZE, true, 0.02)
	var band := _toon("bonsho_band", BRONZE.darkened(0.3), false)
	var stone := _toon("stone", STONE, true, 0.025)
	var log_m := _toon("shumoku", Color("#B89B5E"), true, 0.015)
	var rope := _toon("komo_rope", ROPE_DARK, false)
	_add(bs, stone, box(Vector3(2.0, 0.25, 2.0)), xf * _at(Vector3(0, 0.125, 0)))
	for k in 4:
		var px: float = 0.75 if k % 2 == 0 else -0.75
		var pz: float = 0.75 if k < 2 else -0.75
		_add(bs, wood, box(Vector3(0.12, 2.0, 0.12)), xf * _at(Vector3(px, 1.25, pz)))
	for sz: float in [-1.0, 1.0]:
		_add(bs, wood, box(Vector3(1.7, 0.12, 0.12)), xf * _at(Vector3(0, 2.2, sz * 0.75)))
		_add(bs, wood, box(Vector3(0.12, 0.12, 1.7)), xf * _at(Vector3(sz * 0.75, 2.2, 0)))
	_add(bs, wood, box(Vector3(1.6, 0.1, 0.12)), xf * _at(Vector3(0, 2.08, 0)))
	roof_into(bs, bs, roof, roof, xf * _at(Vector3(0, 2.3, 0)), 2.5, 2.4, 0.6, 0.36, 0.4)
	if snow:
		var sm := _toon("fence_snow", Color("#F2F5F8"), false)
		_add(bs, sm, roof_mesh(2.3, 2.2, 0.56, 0.36, 0.4, 0.04), xf * _at(Vector3(0, 2.36, 0)))
	# cloche, dôme, crochet, cerclages, point de frappe
	_add(bs, bronze, cyl(0.3, 0.33, 0.62, 12), xf * _at(Vector3(0, 1.62, 0)))
	_add(bs, bronze, ball(0.3, 0.3, 12, 4), xf * _at(Vector3(0, 1.93, 0)))
	_add(bs, bronze, cyl(0.05, 0.05, 0.14, 6), xf * _at(Vector3(0, 2.02, 0)))
	for y: float in [1.4, 1.62, 1.84]:
		_add(bn, band, cyl(0.335, 0.335, 0.03, 12), xf * _at(Vector3(0, y, 0)))
	_add(bn, band, cyl(0.07, 0.07, 0.02, 8), xf * _at(Vector3(0, 1.48, 0.325), Vector3(PI * 0.5, 0, 0)))
	_add(bs, log_m, cyl(0.07, 0.07, 1.1, 8), xf * _at(Vector3(0, 1.5, 0.75), Vector3(0, 0, PI * 0.5)))
	for sx: float in [-1.0, 1.0]:
		_add(bn, rope, cyl(0.01, 0.01, 0.6, 4), xf * _at(Vector3(sx * 0.35, 1.8, 0.75)))


## Mouette : corps blanc, ailes grises (repliées ou en vol), bec jaune ; regarde vers +Z local.
static func gull_into(b: Dictionary, xf: Transform3D, flying := false) -> void:
	var white := _toon("gull", Color("#F4F2EC"), true, 0.012)
	var grey := _toon("gull_wing", Color("#9AA3AD"), true, 0.012)
	var beak := _toon("gull_beak", Color("#E0B04A"), false)
	_add(b, white, ball(0.07, 0.24, 7, 4), xf * _at(Vector3(0, 0.1, 0), Vector3(PI * 0.5, 0, 0)))
	_add(b, white, ball(0.05, 0.1, 6, 3), xf * _at(Vector3(0, 0.17, 0.1)))
	_add(b, beak, cyl(0.0, 0.015, 0.06, 4), xf * _at(Vector3(0, 0.165, 0.17), Vector3(PI * 0.5, 0, 0)))
	if flying:
		for sx: float in [-1.0, 1.0]:
			_add(b, grey, box(Vector3(0.3, 0.012, 0.09)), xf * _at(Vector3(sx * 0.16, 0.13, 0), Vector3(0, 0, sx * 0.25)))
			_add(b, grey, box(Vector3(0.22, 0.012, 0.07)), xf * _at(Vector3(sx * 0.41, 0.15, -0.02), Vector3(0, 0, -sx * 0.2)))
	else:
		for sx: float in [-1.0, 1.0]:
			_add(b, grey, box(Vector3(0.03, 0.06, 0.2)), xf * _at(Vector3(sx * 0.065, 0.12, -0.03)))
		_add(b, beak, box(Vector3(0.05, 0.03, 0.08)), xf * _at(Vector3(0, 0.015, 0.0)))


## Ponton secondaire : planches sur longerons, pieux jusqu'à `low_y` qui dépassent en bittes d'amarrage.
static func pier_into(bs: Dictionary, xf: Transform3D, w: float, l: float, top_y: float, low_y: float) -> void:
	var plank := _toon("pier_plank", PLANK, true, 0.02)
	var pile := _toon("pier_pile", PILE, true, 0.02)
	var nb := maxi(int(l / 0.34), 2)
	var pl := l / nb
	for i in nb:
		var z := -l * 0.5 + pl * (float(i) + 0.5)
		_add(bs, plank, box(Vector3(w, 0.07, pl - 0.03)), xf * _at(Vector3(0, top_y - 0.035, z), Vector3(0, 0, 0.012 * float((i % 3) - 1))))
	for sx: float in [-1.0, 1.0]:
		_add(bs, pile, box(Vector3(0.08, 0.1, l)), xf * _at(Vector3(sx * w * 0.42, top_y - 0.12, 0)))
		for sz: float in [-0.45, 0.0, 0.45]:
			var hh := top_y + 0.22 - low_y
			_add(bs, pile, cyl(0.07, 0.08, hh, 6), xf * _at(Vector3(sx * (w * 0.5 + 0.03), low_y + hh * 0.5, sz * l)))


# ------------------------------------------------------------------ grande vague

## Vague de Kanagawa : profil recourbé extrudé (aplat à dégradé Prusse), griffes d'écume, embruns.
## Origine posée sur l'eau ; la lèvre s'enroule vers +Z local.
static func great_wave(parent: Node3D, pos: Vector3, s := 1.0, sd := 0) -> Node3D:
	var rng := _rng(sd)
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
			_add(foam, fm, ball(cr * 1.35, cr * 2.4, 6, 3), _at(p))
			_limb(foam, fm, p, tip, cr, cr * 0.45, 5)
			_limb(foam, fm, tip, tip + hook * cl * 0.5, cr * 0.45, 0.0, 4)
		# écume au pied, sous le rouleau
		for j in 2:
			var fr := rng.randf_range(0.25, 0.45) * sh
			_add(foam, fm, ball(fr, fr * 0.35, 7, 3),
				_at(Vector3(xs[i] + rng.randf_range(-0.3, 0.3), 0.03, rng.randf_range(0.2, 1.6) * curls[i])))
	# embruns au-dessus de la lèvre
	for j in 10:
		var i := rng.randi_range(2, nx - 2)
		var row: PackedVector3Array = rows[i]
		var p := row[k1]
		var off := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.1, 0.6), rng.randf_range(0.2, 0.8))
		var dr := rng.randf_range(0.04, 0.09)
		_add(foam, fm, ball(dr, dr * 2.0, 6, 3), _at(p + off))
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
static func island(parent: Node3D, pos: Vector3, s := 1.0, sd := 0) -> Node3D:
	var root := _root(parent, pos, 1.0, "Island")
	var b := {}
	island_into(b, Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO), sd)
	_flush(b, root, false)
	return root


## Îlot ajouté au lot partagé `b` (placé et mis à l'échelle par `xf`) : plusieurs îlots d'un lointain
## tiennent ainsi en 6 draw calls (rochers, écume, écorce, trois verts) au lieu d'une dizaine chacun.
static func island_into(b: Dictionary, xf: Transform3D, sd := 0) -> void:
	var rng := _rng(sd)
	var x0 := xf * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3.ZERO)
	var big := Vector3(rng.randf_range(1.9, 2.4), rng.randf_range(0.9, 1.2), rng.randf_range(1.5, 1.9))
	var rock := _toon_vc("rock_vc")
	var sts: Array = _rock_tools(rng, big, false, ISLAND_ROCK)
	var st0: SurfaceTool = sts[0]
	_add(b, rock, cpu_from(st0), x0 * _at(Vector3(0, 0.12, 0)))
	for i in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		var ps: Array = _rock_tools(rng, Vector3(0.55, 0.42, 0.5) * rng.randf_range(0.7, 1.3), false, ISLAND_ROCK)
		var pst: SurfaceTool = ps[0]
		_add(b, rock, cpu_from(pst), x0 * _at(Vector3(cos(a) * big.x * 1.05, 0.0, sin(a) * big.z * 1.05)))
	_add(b, _flat("foam", Toon.FOAM), cyl(big.x * 1.2, big.x * 1.2, 0.02, 14),
		x0 * Transform3D(Basis.from_scale(Vector3(1, 1, big.z / big.x)), Vector3(0, 0.03, 0)))
	var npine := rng.randi_range(1, 2)
	for i in npine:
		var ox := 0.0
		if npine > 1:
			ox = -0.45 if i == 0 else 0.45
		var hp := Vector3(ox, 0.12 + big.y * 0.72, rng.randf_range(-0.25, 0.25))
		var hs := rng.randf_range(0.85, 1.2)
		var hx := x0 * Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * hs), hp)
		_pine_build(b, b, rng, false, hx)


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
