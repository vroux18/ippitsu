extends Node3D
## Effets de combat : traînée de lame lumineuse, éclairs d'impact, anneaux de choc, étincelles,
## confettis de papier, grand idéogramme 斬 à la mise à mort. Les matériaux émissifs brillent
## grâce au halo (glow) de l'environnement, sans délaver le reste de l'image.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

const TRAIL_LIFE := 0.16
const TRAIL_W := 0.25

# palette des écoles : chaque élément a sa couleur ET sa forme
const FIRE := Color("#FF5A1F")  # flammes orange-rouge
const FIRE_HOT := Color("#FFC23A")  # cœur jaune, braises
const WATER := Color("#1E9BE0")  # anneaux bleu-cyan
const WATER_FOAM := Color("#D6F4FF")  # écume
const BOLT := Color("#FFE600")  # éclair jaune vif
const BOLT_CORE := Color("#FFFDF0")  # cœur blanc
const WIND := Color("#5FD6A8")  # jade
const WIND_PALE := Color("#E6FFF4")
const SHADOW := Color("#8A4FD8")  # violet
const SHADOW_DARK := Color("#1F1530")
const INK := Color("#1B1A1E")  # sumi
const SCHOOL_FX := {"fire": FIRE, "water": WATER, "bolt": BOLT, "wind": WIND, "shadow": SHADOW, "ink": INK}
const SCHOOL_KANJI := {"fire": "火", "water": "水", "bolt": "雷", "wind": "風", "shadow": "影", "ink": "墨"}

# annonces d'attaque (ennemis et boss) : même langage partout
const TELE_Y := 0.07  # au-dessus des dalles et des bosses de neige (~0.04)
const TELE_INK := 0.09  # contour d'encre (à cheval sur le bord, surtout dehors)
const TELE_RIM := 0.07  # liseré vermillon juste dedans
const TELE_FLASH := 0.15

var main: Node
var _fx: Array = []  # {node, t, life, kind, ...}
var _trail_pts: Array = []  # [position, âge]
var _trail_mesh := ImmediateMesh.new()
var _trail_live := false  # la traînée a des surfaces à effacer
var _trail_mat: StandardMaterial3D
var _glow_mats := {}
# maillages partagés par tous les impacts (forme constante ; l'échelle se fait sur le nœud)
var _star_quad: QuadMesh
var _arc_mesh: ArrayMesh
var _ring_torus: TorusMesh
var _spark_boxes := {}  # couleur -> BoxMesh (matériau lumineux de cette couleur)
var _confetti: QuadMesh
var _mats := {}  # matériaux plats partagés (clé -> StandardMaterial3D)
var _meshes := {}  # maillages partagés (clé -> Mesh)
var _tmat := {}  # matériaux des annonces
var _kanji_cd := {}  # école -> instant (ms) avant le prochain idéogramme
var _flame_ramp: Gradient
var _smoke_ramp: Gradient
var _flame_curve: Curve
var _smoke_curve: Curve


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _trail_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = _trail_mat
	add_child(mi)


## Matériau lumineux (émissif) partagé par couleur.
func glow_mat(c: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), energy]
	if _glow_mats.has(key):
		return _glow_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 1)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	# mélange normal (pas additif) : les couleurs restent franches même sur un sol clair
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(minf(c.r * 1.15, 1.0), minf(c.g * 1.15, 1.0), minf(c.b * 1.15, 1.0), 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_mats[key] = m
	return m


# ------------------------------------------------------------------ traînée de lame

func trail_point(p: Vector3) -> void:
	_trail_pts.append([p + Vector3(0, 0.75, 0), 0.0])


func _update_trail(dt: float) -> void:
	if _trail_pts.is_empty():
		if _trail_live:
			_trail_mesh.clear_surfaces()
			_trail_live = false
		return
	for tp in _trail_pts:
		tp[1] = float(tp[1]) + dt
	_trail_pts = _trail_pts.filter(func(tp): return float(tp[1]) < TRAIL_LIFE)
	_trail_mesh.clear_surfaces()
	_trail_live = false
	var n := _trail_pts.size()
	if n < 2:
		return
	_trail_live = true
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var p: Vector3 = _trail_pts[i][0]
		var age: float = _trail_pts[i][1]
		var k := 1.0 - age / TRAIL_LIFE
		var a: Vector3 = _trail_pts[maxi(i - 1, 0)][0]
		var b: Vector3 = _trail_pts[mini(i + 1, n - 1)][0]
		var t := b - a
		t.y = 0
		if t.length_squared() < 0.0001:
			t = Vector3.FORWARD
		var side := Vector3(-t.z, 0, t.x).normalized()
		var w := TRAIL_W * k
		# fil blanc net côté tranchant, lavis d'encre de l'autre ; une pointe de vermillon en fin de trace
		var col := Color(1.0, 0.97, 0.92).lerp(Toon.VERMILION, (1.0 - k) * 0.35)
		col.a = k * 0.9
		_trail_mesh.surface_set_color(col)
		_trail_mesh.surface_add_vertex(p + side * w + Vector3(0, 0.12 * k, 0))
		_trail_mesh.surface_set_color(Color(Toon.SUMI, 0.3 * k))
		_trail_mesh.surface_add_vertex(p - side * w - Vector3(0, 0.06, 0))
	_trail_mesh.surface_end()


# ------------------------------------------------------------------ impacts

## Coup porté : éclair en étoile, anneau au sol, étincelles dorées.
func impact(pos: Vector3, dir: Vector3, strong := false) -> void:
	var p := pos + Vector3(0, 0.9, 0)
	# éclair en étoile (deux quads croisés face caméra)
	var star := Node3D.new()
	add_child(star)
	star.position = p
	if _star_quad == null:
		_star_quad = QuadMesh.new()
		_star_quad.size = Vector2(0.8, 0.1)
	for r in [0.0, PI / 2.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = _star_quad
		mi.material_override = glow_mat(Color(1, 0.95, 0.8), 4.0)
		mi.rotation.z = r
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.add_child(mi)
	# sobre : une croix brève ; l'arc de sabre et l'anneau seulement sur un coup fort (mise à mort)
	_fx.append({"node": star, "t": 0.0, "life": 0.12, "kind": "star", "s": 1.4 if strong else 1.0})
	if strong:
		ring(Vector3(pos.x, 0.06, pos.z), Toon.GOLD, 1.2)
		arc(p, dir, true)
	sparks(p, dir, 5 if strong else 3, Toon.GOLD)


## Arc de sabre : un croissant lumineux tracé dans le sens du coup.
func arc(pos: Vector3, dir: Vector3, strong := false) -> void:
	if _arc_mesh == null:
		_arc_mesh = _make_arc_mesh()
	var node := Node3D.new()
	add_child(node)
	node.position = pos
	var d := dir
	d.y = 0
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	node.rotation.y = atan2(-d.x, -d.z)
	node.rotation.z = randf_range(-0.5, 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = _arc_mesh
	mi.material_override = glow_mat(Color(1.0, 0.96, 0.9), 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	_fx.append({"node": node, "t": 0.0, "life": 0.2, "kind": "arc", "s": 1.25 if strong else 1.0})


## Croissant de l'arc de sabre (forme fixe, construite une fois).
func _make_arc_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for i in n:
		var a0 := lerpf(-1.2, 1.2, float(i) / n)
		var a1 := lerpf(-1.2, 1.2, float(i + 1) / n)
		var w0 := 0.28 * sin(PI * float(i) / n) + 0.02
		var w1 := 0.28 * sin(PI * float(i + 1) / n) + 0.02
		var o0 := Vector3(sin(a0), 0, -cos(a0)) * 1.2
		var o1 := Vector3(sin(a1), 0, -cos(a1)) * 1.2
		var i0 := Vector3(sin(a0), 0, -cos(a0)) * (1.2 - w0)
		var i1 := Vector3(sin(a1), 0, -cos(a1)) * (1.2 - w1)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i1)
		st.add_vertex(o0)
		st.add_vertex(i1)
		st.add_vertex(i0)
	return st.commit()


## Anneau de choc qui s'étend au sol.
func ring(pos: Vector3, c: Color, r: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	if _ring_torus == null:
		_ring_torus = TorusMesh.new()
		_ring_torus.inner_radius = 0.88
		_ring_torus.outer_radius = 1.0
		_ring_torus.rings = 24
		_ring_torus.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_torus
	mi.scale = Vector3(1, 0.05, 1)
	mi.material_override = glow_mat(c, 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	_fx.append({"node": n, "t": 0.0, "life": 0.35, "kind": "ring", "r": r})


## Étincelles lumineuses projetées dans la direction du coup.
func sparks(pos: Vector3, dir: Vector3, amount: int, c: Color) -> void:
	var p := CPUParticles3D.new()
	var key := c.to_html()
	if not _spark_boxes.has(key):
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.07, 0.36)
		bm.material = glow_mat(c, 3.5)
		_spark_boxes[key] = bm
	p.mesh = _spark_boxes[key]
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	var d := dir.normalized() if dir.length_squared() > 0.001 else Vector3.UP
	p.direction = (d + Vector3(0, 0.6, 0)).normalized()
	p.spread = 55.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3(0, -14, 0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.position = pos
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": 0.9, "kind": "none"})


## Mise à mort : éclat d'or, quelques confettis de papier ; le grand 斬 seulement sur un beau coup (`big`).
func kill_burst(pos: Vector3, dir: Vector3, big := false) -> void:
	impact(pos, dir, true)
	# confettis de washi
	var p := CPUParticles3D.new()
	if _confetti == null:
		_confetti = QuadMesh.new()
		_confetti.size = Vector2(0.14, 0.1)
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.albedo_color = Toon.WASHI
		pm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_confetti.material = pm
	p.mesh = _confetti
	p.amount = 7
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -5, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.color = Toon.WASHI
	p.position = pos + Vector3(0, 1.0, 0)
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": 1.4, "kind": "none"})
	if not big:
		return
	# grand idéogramme au pinceau
	var l := Label3D.new()
	l.font = UiKit.TITLE_FONT
	l.text = "斬"
	l.font_size = 220
	l.pixel_size = 0.0038
	l.modulate = Toon.VERMILION
	l.outline_modulate = Toon.SUMI
	l.outline_size = 26
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0.6, 2.0, 0)
	add_child(l)
	_fx.append({"node": l, "t": 0.0, "life": 0.55, "kind": "kanji"})


# ------------------------------------------------------------------ outils partagés

## Matériau plat (non éclairé, transparent) partagé par clé. bill : 0 aucun, 1 particules, 2 face caméra.
func _mat(key: String, c: Color, prio := 0, vcol := false, bill := 0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	m.render_priority = prio
	m.vertex_color_use_as_albedo = vcol
	if bill == 1:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	elif bill == 2:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	_mats[key] = m
	return m


func _mi(parent: Node3D, mesh: Mesh, mat: Material, y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = y
	parent.add_child(mi)
	return mi


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


## Repère qui va de a vers b : -Z local pointe vers b et mesure |b - a| (maillages tracés de 0 à -1 en z).
func _seg_xform(a: Vector3, b: Vector3) -> Transform3D:
	var d := b - a
	var l := maxf(d.length(), 0.01)
	var fwd := d / l
	var up := Vector3.UP if absf(fwd.y) < 0.9 else Vector3.FORWARD
	var zax := -fwd
	var xax := up.cross(zax).normalized()
	var yax := zax.cross(xax)
	return Transform3D(Basis(xax, yax, zax * l), a)


func _unit_disc() -> Mesh:
	if not _meshes.has("disc"):
		_meshes["disc"] = Toon.cyl(1.0, 1.0, 0.004, 18)
	return _meshes["disc"]


func _ball() -> Mesh:
	if not _meshes.has("ball"):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 8
		s.rings = 4
		_meshes["ball"] = s
	return _meshes["ball"]


func _unit_box() -> Mesh:
	if not _meshes.has("box"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_meshes["box"] = b
	return _meshes["box"]


# ------------------------------------------------------------------ annonces d'attaque
# Une annonce = un nœud racine (posé par l'appelant) avec : fond vermillon + contour d'encre (un seul maillage,
# deux surfaces), remplissage qui grandit jusqu'au contour, liseré vermillon qui pulse. Les 0.15 dernières
# secondes, le remplissage flashe. Tout est partagé (maillages par taille, matériaux uniques), rien par instance.
#   tele_disc(parent, r)                       disque centré
#   tele_rect(parent, hx, hz, grow)            rectangle centré (demi-tailles) ; grow = côté d'où part le remplissage
#                                              (Vector2.ZERO : du centre ; (±1, 0) : du bord ±x ; (0, ±1) : du bord ±z)
#   tele_fan(parent, half_angle, length)       cône depuis l'origine vers +z
#   tele_update(zone, k, t_left)               k = avancement 0..1, t_left = temps avant le coup
#   tele_dot(parent, r) / tele_dot_flash(dot, on)   petite marque de chemin (même langage)

func _tele_init() -> void:
	if not _tmat.is_empty():
		return
	_tmat["base"] = _mat("tele_base", Color(Toon.VERMILION, 0.24), 1)
	_tmat["fill"] = _mat("tele_fill", Color(0.88, 0.2, 0.13, 0.58), 2)
	_tmat["flash"] = _mat("tele_flash", Color(1.0, 0.95, 0.86, 0.92), 2)
	_tmat["rim"] = _mat("tele_rim", Color(0.95, 0.24, 0.15, 0.95), 3)
	_tmat["ink"] = _mat("tele_ink", Color(Toon.SUMI, 0.9), 4)
	_tmat["dot"] = _mat("tele_dot", Color(0.92, 0.22, 0.14, 0.9), 2)


func _circle(r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


func _rect_pts(hx: float, hz: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)])


func _fan_pts(half: float, length: float) -> PackedVector2Array:
	var out := PackedVector2Array([Vector2.ZERO])
	var steps := 12
	for i in steps + 1:
		var a := lerpf(-half, half, float(i) / float(steps))
		out.append(Vector2(sin(a), cos(a)) * length)
	return out


func _edge_normal(a: Vector2, b: Vector2, cen: Vector2) -> Vector2:
	var e := b - a
	var nrm := Vector2(-e.y, e.x).normalized()
	if nrm.dot((a + b) * 0.5 - cen) < 0.0:
		nrm = -nrm
	return nrm


## Bande le long du contour d'un polygone convexe, de d0 à d1 (négatif = dedans).
func _poly_band(st: SurfaceTool, pts: PackedVector2Array, d0: float, d1: float) -> void:
	var n := pts.size()
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= float(n)
	var offs := PackedVector2Array()
	for i in n:
		var na := _edge_normal(pts[(i - 1 + n) % n], pts[i], cen)
		var nb := _edge_normal(pts[i], pts[(i + 1) % n], cen)
		var m := (na + nb).normalized()
		offs.append(m / maxf(m.dot(nb), 0.35))
	for i in n:
		var j := (i + 1) % n
		var a0 := pts[i] + offs[i] * d0
		var a1 := pts[i] + offs[i] * d1
		var b0 := pts[j] + offs[j] * d0
		var b1 := pts[j] + offs[j] * d1
		_quad(st, Vector3(a0.x, 0, a0.y), Vector3(a1.x, 0, a1.y), Vector3(b1.x, 0, b1.y), Vector3(b0.x, 0, b0.y))


## Intérieur d'un polygone convexe (éventail depuis le barycentre).
func _poly_fill(st: SurfaceTool, pts: PackedVector2Array) -> void:
	var n := pts.size()
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= float(n)
	var c3 := Vector3(cen.x, 0, cen.y)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		st.add_vertex(c3)
		st.add_vertex(Vector3(a.x, 0, a.y))
		st.add_vertex(Vector3(b.x, 0, b.y))


func _tele_mesh(key: String, pts: PackedVector2Array, part: String) -> ArrayMesh:
	var ck := part + key
	if _meshes.has(ck):
		return _meshes[ck]
	var mesh := ArrayMesh.new()
	if part == "frame":
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_fill(st, pts)
		st.commit(mesh)
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_band(st2, pts, -0.02, TELE_INK)
		st2.commit(mesh)
		mesh.surface_set_material(0, _tmat["base"])
		mesh.surface_set_material(1, _tmat["ink"])
	elif part == "rim":
		var st3 := SurfaceTool.new()
		st3.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_band(st3, pts, -0.02 - TELE_RIM, -0.02)
		st3.commit(mesh)
		mesh.surface_set_material(0, _tmat["rim"])
	else:
		var st4 := SurfaceTool.new()
		st4.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_fill(st4, pts)
		st4.commit(mesh)
	_meshes[ck] = mesh
	return mesh


func _tele_make(parent: Node3D, key: String, pts: PackedVector2Array, fill_mesh: Mesh, fs: Vector3, grow: Vector2) -> Node3D:
	_tele_init()
	var root := Node3D.new()
	parent.add_child(root)
	_mi(root, _tele_mesh(key, pts, "frame"), null, TELE_Y)
	var fill := _mi(root, fill_mesh, _tmat["fill"], TELE_Y + 0.004)
	var rim := _mi(root, _tele_mesh(key, pts, "rim"), null, TELE_Y + 0.008)
	root.set_meta("fill", fill)
	root.set_meta("rim", rim)
	root.set_meta("fs", fs)
	root.set_meta("grow", grow)
	tele_update(root, 0.0, 99.0)
	return root


func tele_disc(parent: Node3D, r: float) -> Node3D:
	_tele_init()
	var unit := _tele_mesh("u", _circle(1.0, 40), "fdisc")
	return _tele_make(parent, "d%.2f" % r, _circle(r, 40), unit, Vector3(r, 1, r), Vector2.ZERO)


func tele_rect(parent: Node3D, hx: float, hz: float, grow := Vector2.ZERO) -> Node3D:
	_tele_init()
	var unit := _tele_mesh("u", _rect_pts(1.0, 1.0), "frect")
	# tailles arrondies à 5 cm : le cache de maillages reste petit même si les longueurs varient
	var sx := maxf(snappedf(hx, 0.05), 0.05)
	var sz := maxf(snappedf(hz, 0.05), 0.05)
	return _tele_make(parent, "r%.2f_%.2f" % [sx, sz], _rect_pts(sx, sz), unit, Vector3(sx, 1, sz), grow)


func tele_fan(parent: Node3D, half_angle: float, length: float) -> Node3D:
	_tele_init()
	var unit := _tele_mesh("u%.3f" % half_angle, _fan_pts(half_angle, 1.0), "ffan")
	var sl := maxf(snappedf(length, 0.05), 0.05)
	return _tele_make(parent, "f%.3f_%.2f" % [half_angle, sl], _fan_pts(half_angle, sl), unit, Vector3(sl, 1, sl), Vector2.ZERO)


## Avance une annonce : remplissage k (0..1) jusqu'au contour, pulsation, flash final.
func tele_update(zone: Node3D, k: float, t_left: float) -> void:
	if zone == null or not is_instance_valid(zone) or not zone.has_meta("fill"):
		return
	var kk := clampf(k, 0.01, 1.0)
	var fill: MeshInstance3D = zone.get_meta("fill")
	var rim: MeshInstance3D = zone.get_meta("rim")
	var fs: Vector3 = zone.get_meta("fs")
	var g: Vector2 = zone.get_meta("grow")
	if g.x != 0.0:
		fill.scale = Vector3(fs.x * kk, 1, fs.z)
		fill.position.x = g.x * fs.x * (1.0 - kk)
	elif g.y != 0.0:
		fill.scale = Vector3(fs.x, 1, fs.z * kk)
		fill.position.z = g.y * fs.z * (1.0 - kk)
	else:
		fill.scale = Vector3(fs.x * kk, 1, fs.z * kk)
	var flash := t_left < TELE_FLASH
	var m: Material = _tmat["flash"] if flash else _tmat["fill"]
	if fill.material_override != m:
		fill.material_override = m
	# pulsation du liseré, plus marquée à l'approche du coup
	var w := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.014)
	rim.scale = Vector3.ONE * (1.0 - (0.01 + 0.035 * kk) * w)
	rim.visible = not flash


func tele_dot(parent: Node3D, r: float) -> MeshInstance3D:
	_tele_init()
	if not _meshes.has("tele_dot"):
		var mesh := ArrayMesh.new()
		var pts := _circle(1.0, 16)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_fill(st, pts)
		st.commit(mesh)
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		_poly_band(st2, pts, 0.0, 0.45)
		st2.commit(mesh)
		mesh.surface_set_material(0, _tmat["dot"])
		mesh.surface_set_material(1, _tmat["ink"])
		_meshes["tele_dot"] = mesh
	var mi := _mi(parent, _meshes["tele_dot"], null, TELE_Y)
	mi.scale = Vector3(r, 1, r)
	return mi


func tele_dot_flash(dot: MeshInstance3D, on: bool) -> void:
	_tele_init()
	if on:
		if dot.material_override == null:
			dot.material_override = _tmat["flash"]
	elif dot.material_override != null:
		dot.material_override = null


# ------------------------------------------------------------------ foudre (雷) : éclair en zigzag

## Éclair brisé de a à b : contour d'encre, corps jaune, cœur blanc ; petit flash blanc et étincelles au bout.
func bolt(a: Vector3, b: Vector3, sparks_n := 3) -> void:
	var l := a.distance_to(b)
	if l < 0.05:
		return
	var bucket := maxi(1, int(round(l / 0.5)))
	var v := randi() % 3
	var mi := MeshInstance3D.new()
	mi.mesh = _bolt_mesh(bucket, v)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.transform = _seg_xform(a, b)
	_fx.append({"node": mi, "t": 0.0, "life": 0.2, "kind": "bolt", "alt": _bolt_mesh(bucket, (v + 1) % 3), "swap": false})
	_pop(b, BOLT_CORE, 0.55)
	if sparks_n > 0:
		sparks(b, b - a, sparks_n, BOLT)


## Foudre qui tombe du ciel sur p (Raijū, Raijin, orage).
func sky_bolt(p: Vector3, big := false) -> void:
	var g := Vector3(p.x, 0.05, p.z)
	bolt(g + Vector3(randf_range(-0.6, 0.6), 7.0, randf_range(-0.6, 0.6)), g, 0)
	ring(Vector3(p.x, 0.07, p.z), BOLT, 1.0 if big else 0.7)
	sparks(g + Vector3(0, 0.2, 0), Vector3.UP, 6 if big else 4, BOLT)
	scorch(p, 0.35 if big else 0.25, 0.8)


func _bolt_mats() -> Array:
	return [_mat("bolt_ink", Color(Toon.SUMI, 0.6), 5), _mat("bolt_body", BOLT, 6), _mat("bolt_core", BOLT_CORE, 7)]


## Maillage d'éclair (longueur bucket × 0.5 m, variante v), tracé de 0 à -1 en z (mis à l'échelle par _seg_xform).
func _bolt_mesh(bucket: int, v: int) -> ArrayMesh:
	var key := "bolt%d_%d" % [bucket, v]
	if _meshes.has(key):
		return _meshes[key]
	var length := float(bucket) * 0.5
	var n := clampi(bucket * 2, 3, 12)
	var jit := clampf(length * 0.12, 0.08, 0.3)
	var path := PackedVector3Array()
	for i in n + 1:
		var u := float(i) / float(n)
		var j := 0.0 if (i == 0 or i == n) else 1.0
		var side := 1.0 if i % 2 == 0 else -1.0  # alterne : vrai zigzag
		path.append(Vector3(side * randf_range(0.4, 1.0) * jit * j, randf_range(-0.5, 0.5) * jit * j, -u * length))
	var mesh := ArrayMesh.new()
	var widths := [0.11, 0.065, 0.025]
	var mats := _bolt_mats()
	for s in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var w: float = widths[s]
		for i in n:
			var pa := path[i] / length
			var pb := path[i + 1] / length
			# largeur perpendiculaire au segment (en vraie grandeur), ramenée à l'échelle unité en z
			var seg := path[i + 1] - path[i]
			var sx := seg.cross(Vector3.UP).normalized() * w
			var sy := sx.cross(seg).normalized() * w
			var ox := Vector3(sx.x, sx.y, sx.z / length)
			var oy := Vector3(sy.x, sy.y, sy.z / length)
			var a3 := Vector3(path[i].x, path[i].y, pa.z)
			var b3 := Vector3(path[i + 1].x, path[i + 1].y, pb.z)
			_quad(st, a3 - ox, a3 + ox, b3 + ox, b3 - ox)
			_quad(st, a3 - oy, a3 + oy, b3 + oy, b3 - oy)
		st.commit(mesh)
		mesh.surface_set_material(s, mats[s])
	_meshes[key] = mesh
	return mesh


## Petit flash (boule qui gonfle puis disparaît).
func _pop(p: Vector3, c: Color, s: float) -> void:
	var mi := _mi(self, _ball(), _mat("pop" + c.to_html(), Color(c, 0.9), 8), 0.0)
	mi.position = p
	_fx.append({"node": mi, "t": 0.0, "life": 0.12, "kind": "pop", "s": s})


# ------------------------------------------------------------------ feu (火) : flammes, braises, roussi

func _flame_res() -> void:
	if _flame_ramp != null:
		return
	_flame_ramp = Gradient.new()
	_flame_ramp.set_color(0, Color(1.0, 0.86, 0.35, 1.0))
	_flame_ramp.set_color(1, Color(0.3, 0.08, 0.04, 0.0))
	_flame_ramp.add_point(0.3, Color(1.0, 0.5, 0.12, 1.0))
	_flame_ramp.add_point(0.7, Color(0.86, 0.2, 0.1, 0.85))
	_flame_curve = Curve.new()
	_flame_curve.add_point(Vector2(0.0, 0.55))
	_flame_curve.add_point(Vector2(0.25, 1.0))
	_flame_curve.add_point(Vector2(1.0, 0.15))


## Langue de flamme (face caméra, pointe en haut).
func _tongue() -> Mesh:
	if _meshes.has("tongue"):
		return _meshes["tongue"]
	var pts := [Vector2(0, 0.5), Vector2(0.13, 0.1), Vector2(0.11, -0.08), Vector2(0, -0.17), Vector2(-0.11, -0.08), Vector2(-0.13, 0.1)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		st.add_vertex(Vector3(0, 0.05, 0))
		st.add_vertex(Vector3(a.x, a.y, 0))
		st.add_vertex(Vector3(b.x, b.y, 0))
	var m := st.commit()
	_meshes["tongue"] = m
	return m


## Langue de flamme statique (halos des pouvoirs) : maillage et matériau face caméra partagés.
func flame_mesh() -> Mesh:
	return _tongue()


func flame_mat(c: Color) -> StandardMaterial3D:
	return _mat("tongue" + c.to_html(), c, 3, false, 2)


## Émetteur de flammes : disque de rayon r au sol (ou points `pts`). emit > 0 : émission continue pendant emit s.
func _flame_emitter(pos: Vector3, r: float, amount: int, emit: float) -> CPUParticles3D:
	_flame_res()
	var p := CPUParticles3D.new()
	p.mesh = _tongue()
	p.material_override = _mat("flame_p", Color.WHITE, 3, true, 1)
	p.amount = amount
	p.lifetime = 0.5
	p.one_shot = emit <= 0.0
	p.explosiveness = 0.75 if emit <= 0.0 else 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_height = 0.05
	p.emission_ring_radius = maxf(r, 0.05)
	p.emission_ring_inner_radius = 0.0
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, 2.5, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _flame_curve
	p.color_ramp = _flame_ramp
	p.position = pos + Vector3(0, 0.12, 0)
	return p


## Gerbe de flammes (brève) : langues qui montent et vacillent.
func flames(pos: Vector3, r: float, amount := 8) -> void:
	var p := _flame_emitter(pos, r, amount, 0.0)
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": 0.8, "kind": "none"})


## Flammes continues accrochées à `parent` (brûlure, roue de feu, halo) ; l'appelant libère le nœud.
func burner(parent: Node3D, r: float, amount := 5, offset := Vector3.ZERO) -> CPUParticles3D:
	var p := _flame_emitter(Vector3.ZERO, r, amount, 1.0)
	p.position = offset + Vector3(0, 0.12, 0)
	parent.add_child(p)
	p.emitting = true
	return p


## Braises : petits points chauds qui montent.
func embers(pos: Vector3, r: float, amount := 5) -> void:
	var p := CPUParticles3D.new()
	var key := "ember"
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, 0.06)
		bm.material = glow_mat(FIRE_HOT, 3.0)
		_meshes[key] = bm
	p.mesh = _meshes[key]
	p.amount = amount
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(r, 0.05)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 1.0, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.position = pos + Vector3(0, 0.3, 0)
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": 1.0, "kind": "none"})


## Tache de roussi au sol (suie), qui se résorbe à la fin.
func scorch(pos: Vector3, r: float, life := 1.2) -> void:
	var mi := _mi(self, _unit_disc(), _mat("soot", Color(0.13, 0.08, 0.06, 0.42), 0), 0.0)
	mi.position = Vector3(pos.x, 0.05, pos.z)
	var s := Vector3(r, 1, r * randf_range(0.7, 1.0))
	mi.scale = s
	mi.rotation.y = randf() * TAU
	_fx.append({"node": mi, "t": 0.0, "life": life, "kind": "shrink", "s3": s})


## Cercle de feu : couronne de flammes, anneau orange, braises, roussi.
func fire_burst(pos: Vector3, r: float) -> void:
	flames(pos, r * 0.85, clampi(int(6.0 + r * 4.0), 6, 16))
	ring(Vector3(pos.x, 0.07, pos.z), FIRE, r)
	embers(pos, r * 0.5, 5)
	scorch(pos, r * 0.6, 1.0)


## Flammes le long d'un trait (sillage) : un seul émetteur sur des points, plus une traînée de suie.
## Temps du jeu (le sillage blesse en temps du jeu).
func fire_trail(points: PackedVector3Array, dur: float) -> void:
	if points.size() < 2:
		return
	var pts := PackedVector3Array()
	var acc := 0.0
	for i in range(1, points.size()):
		acc += points[i].distance_to(points[i - 1])
		if acc >= 0.5:
			acc = 0.0
			pts.append(Vector3(points[i].x, 0.12, points[i].z))
	if pts.is_empty():
		pts.append(Vector3(points[0].x, 0.12, points[0].z))
	var p := _flame_emitter(Vector3.ZERO, 0.1, clampi(pts.size() * 3, 6, 36), dur)
	p.position = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	p.lifetime = 0.55
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": dur + 0.6, "kind": "emit", "stop": dur, "game": true})
	# suie : ruban au sol, propre à ce trait (il s'efface d'un bloc)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var d := b - a
		d.y = 0
		if d.length_squared() < 0.0001:
			continue
		var side := Vector3(-d.z, 0, d.x).normalized() * 0.22
		var ya := Vector3(a.x, 0.05, a.z)
		var yb := Vector3(b.x, 0.05, b.z)
		_quad(st, ya - side, ya + side, yb + side, yb - side)
	var m := Toon.flat(Color(0.14, 0.08, 0.05, 0.32))
	var mi := _mi(self, st.commit(), m, 0.0)
	_fx.append({"node": mi, "t": 0.0, "life": dur, "kind": "fade_mat", "mat": m, "a": 0.32, "game": true})


# ------------------------------------------------------------------ eau (水) : anneaux, écume, vagues

## Vague en croissant (arc cyan à plat) qui part dans la direction dir.
func wave_arc(pos: Vector3, dir: Vector3, s := 1.0) -> void:
	if _arc_mesh == null:
		_arc_mesh = _make_arc_mesh()
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(pos.x, 0.25, pos.z)
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	node.rotation.y = atan2(-d.x, -d.z)
	_mi(node, _arc_mesh, glow_mat(WATER, 2.2))
	var foam := _mi(node, _arc_mesh, glow_mat(WATER_FOAM, 2.0))
	foam.scale = Vector3(0.8, 1, 0.8)
	foam.position.y = 0.02
	_fx.append({"node": node, "t": 0.0, "life": 0.3, "kind": "arc", "s": s})


## Éclat d'eau : anneau bleu, anneau d'écume, croissants de vague, gouttes.
func water_burst(pos: Vector3, r: float) -> void:
	ring(Vector3(pos.x, 0.07, pos.z), WATER, r)
	ring(Vector3(pos.x, 0.09, pos.z), WATER_FOAM, r * 0.6)
	var a0 := randf() * TAU
	for i in 3:
		var a := a0 + TAU * float(i) / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		wave_arc(pos + d * r * 0.45, d, maxf(r * 0.45, 0.6))
	if main:
		main.splash(pos, WATER, 8)
		main.splash(pos, WATER_FOAM, 5)


# ------------------------------------------------------------------ vent (風) : croissants, spirales

## Lame de vent : croissant jade qui tourne à plat.
func wind_slash(pos: Vector3, dir: Vector3, s := 0.9) -> void:
	if _arc_mesh == null:
		_arc_mesh = _make_arc_mesh()
	var node := Node3D.new()
	add_child(node)
	node.position = pos + Vector3(0, 0.7, 0)
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	node.rotation.y = atan2(-d.x, -d.z)
	node.rotation.z = randf_range(-0.3, 0.3)
	_mi(node, _arc_mesh, glow_mat(WIND, 2.4))
	var core := _mi(node, _arc_mesh, glow_mat(WIND_PALE, 2.0))
	core.scale = Vector3(0.88, 1, 0.88)
	_fx.append({"node": node, "t": 0.0, "life": 0.22, "kind": "spinarc", "s": s})


func _swirl_mesh() -> Mesh:
	if _meshes.has("swirl"):
		return _meshes["swirl"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	for arm in 2:
		var a0 := PI * float(arm)
		for i in n:
			var u0 := float(i) / float(n)
			var u1 := float(i + 1) / float(n)
			var r0 := lerpf(0.2, 1.0, u0)
			var r1 := lerpf(0.2, 1.0, u1)
			var g0 := a0 + u0 * 4.2
			var g1 := a0 + u1 * 4.2
			var w0 := 0.09 * sin(PI * u0) + 0.01
			var w1 := 0.09 * sin(PI * u1) + 0.01
			var d0 := Vector3(cos(g0), 0, sin(g0))
			var d1 := Vector3(cos(g1), 0, sin(g1))
			_quad(st, d0 * (r0 - w0), d0 * (r0 + w0), d1 * (r1 + w1), d1 * (r1 - w1))
	var m := st.commit()
	_meshes["swirl"] = m
	return m


## Tourbillon : deux spirales (jade et blanche) qui tournent vite en s'ouvrant.
func swirl(pos: Vector3, r: float) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(pos.x, 0.35, pos.z)
	_mi(node, _swirl_mesh(), glow_mat(WIND, 2.2))
	var inner := _mi(node, _swirl_mesh(), glow_mat(WIND_PALE, 2.0))
	inner.scale = Vector3(0.6, 1, 0.6)
	inner.rotation.y = PI / 2.0
	inner.position.y = 0.15
	_fx.append({"node": node, "t": 0.0, "life": 0.45, "kind": "swirl", "r": r})


## Spirale persistante (zones des pouvoirs) : l'appelant la fait tourner et la libère.
func swirl_mesh() -> Mesh:
	return _swirl_mesh()


# ------------------------------------------------------------------ ombre (影) : fumée violette, estoc

func _smoke_res() -> void:
	if _smoke_ramp != null:
		return
	_smoke_ramp = Gradient.new()
	_smoke_ramp.set_color(0, Color(0.6, 0.38, 0.92, 0.85))
	_smoke_ramp.set_color(1, Color(0.08, 0.05, 0.12, 0.0))
	_smoke_ramp.add_point(0.45, Color(0.2, 0.12, 0.3, 0.7))
	_smoke_curve = Curve.new()
	_smoke_curve.max_value = 2.0
	_smoke_curve.add_point(Vector2(0.0, 0.5))
	_smoke_curve.add_point(Vector2(1.0, 1.4))


## Bouffées de fumée violette et noire.
func smoke(pos: Vector3, r: float, amount := 6) -> void:
	_smoke_res()
	var p := CPUParticles3D.new()
	p.mesh = _ball()
	p.material_override = _mat("smoke_p", Color.WHITE, 2, true)
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(r, 0.05)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.8, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.6
	p.scale_amount_curve = _smoke_curve
	p.color_ramp = _smoke_ramp
	p.position = pos + Vector3(0, 0.5, 0)
	add_child(p)
	p.emitting = true
	_fx.append({"node": p, "t": 0.0, "life": 0.8, "kind": "none"})


## Estoc d'ombre : pique sombre liserée de violet de a vers b, bouffée de fumée au bout.
func shadow_stab(a: Vector3, b: Vector3) -> void:
	var pa := a + Vector3(0, 0.8, 0)
	var pb := b + Vector3(0, 0.8, 0)
	var node := Node3D.new()
	add_child(node)
	node.transform = _seg_xform(pa, pb)
	var edge := _mi(node, _unit_box(), _mat("stab_edge", Color(SHADOW, 0.9), 5))
	edge.scale = Vector3(0.14, 0.14, 1.0)
	edge.position.z = -0.5
	var core := _mi(node, _unit_box(), _mat("stab_core", SHADOW_DARK, 6))
	core.scale = Vector3(0.06, 0.06, 1.02)
	core.position.z = -0.5
	_fx.append({"node": node, "t": 0.0, "life": 0.2, "kind": "stab"})
	smoke(b, 0.3, 5)


# ------------------------------------------------------------------ encre (墨) : onde, coupe

## Onde d'encre : anneau noir bordé de papier (lisible sur sol clair et sombre), gouttes d'encre.
func ink_wave(pos: Vector3, r: float) -> void:
	ring(Vector3(pos.x, 0.09, pos.z), INK, r)
	ring(Vector3(pos.x, 0.07, pos.z), Toon.WASHI, r * 1.08)
	if main:
		main.splash(pos, INK, 10)


func _blade_mesh() -> ArrayMesh:
	if _meshes.has("blade"):
		return _meshes["blade"]
	var mesh := ArrayMesh.new()
	var widths := [0.17, 0.09]
	var mats := [_mat("iai_ink", Color(Toon.SUMI, 0.85), 5), _mat("iai_white", Color(1, 1, 1, 1), 6)]
	for s in 2:
		var w: float = widths[s]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# losange effilé de z = 0.5 à -0.5
		_quad(st, Vector3(0, 0, 0.5), Vector3(w, 0, 0.1), Vector3(0, 0, -0.5), Vector3(-w, 0, 0.1))
		st.commit(mesh)
		mesh.surface_set_material(s, mats[s])
	_meshes["blade"] = mesh
	return mesh


## Coupe d'iaï : long trait blanc cerné d'encre sur toute la ligne, qui s'affine et disparaît.
func slash_line(a: Vector3, b: Vector3) -> void:
	var d := b - a
	d.y = 0
	var node := Node3D.new()
	add_child(node)
	node.position = (a + b) / 2.0 + Vector3(0, 0.6, 0)
	if d.length_squared() > 0.0001:
		node.rotation.y = atan2(-d.x, -d.z)
	var mi := _mi(node, _blade_mesh(), null)
	var l := d.length() + 1.0
	mi.scale = Vector3(1.3, 1, l)
	_fx.append({"node": node, "t": 0.0, "life": 0.3, "kind": "iai", "l": l})
	if main:
		main.splash(b, INK, 6)


# ------------------------------------------------------------------ idéogramme d'école

## Petit kanji d'école au-dessus d'un gros déclenchement (rare : une fois par 1.5 s et par école).
func school_kanji(pos: Vector3, school: String) -> void:
	if not SCHOOL_KANJI.has(school):
		return
	var now := Time.get_ticks_msec()
	if int(_kanji_cd.get(school, 0)) > now:
		return
	_kanji_cd[school] = now + 1500
	var l := Label3D.new()
	l.font = UiKit.TITLE_FONT
	l.text = String(SCHOOL_KANJI[school])
	l.font_size = 120
	l.pixel_size = 0.0034
	var c: Color = SCHOOL_FX[school]
	l.modulate = c
	l.outline_modulate = Toon.SUMI if school != "ink" else Toon.WASHI
	l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(-0.5, 1.9, 0)
	add_child(l)
	_fx.append({"node": l, "t": 0.0, "life": 0.6, "kind": "kanji"})


func _process(delta: float) -> void:
	# temps réel : les effets ne ralentissent pas avec le jeu
	var dt := UiKit.unscaled(delta, 0.05)
	if main and main.hero and is_instance_valid(main.hero) and main.hero.dashing:
		trail_point(main.hero.position)
	_update_trail(dt)
	var gdt := minf(delta, 0.05)  # temps du jeu (sillage de feu)
	for i in range(_fx.size() - 1, -1, -1):
		var fx: Dictionary = _fx[i]
		var node: Node3D = fx.node
		if not is_instance_valid(node):
			_fx.remove_at(i)
			continue
		fx.t = float(fx.t) + (gdt if fx.has("game") else dt)
		var k: float = float(fx.t) / float(fx.life)
		match String(fx.kind):
			"bolt":
				# scintille : change de tracé une fois, puis s'éteint
				if not bool(fx.swap) and k > 0.4:
					fx.swap = true
					(node as MeshInstance3D).mesh = fx.alt
				node.visible = k < 0.85
			"pop":
				var ps: float = fx.s
				node.scale = Vector3.ONE * ps * (0.4 + 0.8 * k)
				node.visible = k < 0.8
			"spinarc":
				var sw: float = fx.s
				node.scale = Vector3.ONE * sw * (0.8 + 0.5 * k)
				node.rotation.y += dt * 9.0
				node.visible = k < 0.85
			"swirl":
				var rr: float = fx.r
				node.scale = Vector3.ONE * rr * (0.6 + 0.6 * k)
				node.rotation.y += dt * 12.0
				node.visible = k < 0.9
			"stab":
				node.visible = k < 0.85
			"iai":
				var mi := node.get_child(0) as MeshInstance3D
				mi.scale = Vector3(1.3 * sqrt(maxf(1.0 - k, 0.0)), 1, float(fx.l))
			"shrink":
				var s3: Vector3 = fx.s3
				var sk := clampf((1.0 - k) / 0.3, 0.0, 1.0)
				node.scale = Vector3(s3.x * maxf(sk, 0.01), 1, s3.z * maxf(sk, 0.01))
			"emit":
				if float(fx.t) >= float(fx.stop):
					(node as CPUParticles3D).emitting = false
			"fade_mat":
				var fm: StandardMaterial3D = fx.mat
				fm.albedo_color.a = float(fx.a) * clampf((1.0 - k) * 3.0, 0.0, 1.0)
			"star":
				var s: float = fx.s
				node.scale = Vector3.ONE * s * (0.3 + 0.9 * k)
				if main and main.cam:
					node.look_at(main.cam.global_position, Vector3.UP)
				for ch in node.get_children():
					(ch as Node3D).visible = k < 0.9
			"arc":
				var sa: float = fx.s
				node.scale = Vector3.ONE * sa * (0.8 + 0.5 * k)
				node.visible = k < 0.85
			"ring":
				var r: float = fx.r
				node.scale = Vector3.ONE * r * (0.3 + 1.2 * k)
				node.visible = k < 0.95
			"kanji":
				var l := node as Label3D
				var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - k * 5.0)
				l.scale = Vector3.ONE * pop
				l.modulate.a = clampf((1.0 - k) * 2.5, 0.0, 1.0)
				l.outline_modulate.a = l.modulate.a
				l.position.y += dt * 1.2
		if k >= 1.0:
			node.queue_free()
			_fx.remove_at(i)
