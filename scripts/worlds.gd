extends RefCounted
## Les cinq mondes (univers Hokusai) : données (palette, ambiance, ennemis, difficulté)
## et décor procédural : lointain, props autour de l'arène, particules d'ambiance.
## Uniquement des const et des fonctions static. Matériaux et maillages partagés via des caches ;
## uniquement StandardMaterial3D et CPUParticles3D (renderer Compatibility).
## Performances : tout le décor d'une salle est fusionné par matériau (2 lots : avec / sans ombre)
## et les éléments répétés nombreux (bambous, écume, glaçons, cailloux, papiers) sont des MultiMesh.
## Le lointain « estampe » (ciel en bokashi, montagnes en couches, brume en bandes, oiseaux,
## silhouettes) tient en un seul maillage à couleurs de sommets, sans lumière.

const Toon = preload("res://scripts/toon.gd")
const Decor = preload("res://scripts/decor.gd")

## Surface du vide (eau, lave, encre) : le plan de arena.gd est à y = -0.6, épaisseur 0.1.
const VOID_Y := -0.55
## Zone des particules d'ambiance (couvre l'arène et un peu au-delà).
const PART_AREA := AABB(Vector3(-6, 0, -11), Vector3(12, 5, 22))
const NONE2 := Vector2(9999.0, 9999.0)
const NONE4 := Vector4(9999.0, 9999.0, 0.0, 0.0)
const MAX_LIGHTS := 3  # OmniLight3D de props par salle (mobile)
## Distance des props de bord au bord de la plateforme (empreinte toujours à plus de 0.3).
const EDGE_OFF := 0.55

# couleurs propres aux décors
const TANZAKU := [Color("#EBB8C3"), Color("#B9D3E8"), Color("#F1E3A6"), Color("#C2DFB3"), Color("#FBF8F0")]
const STONE := Color("#B9B3A6")
const STONE_DARK := Color("#8F897D")
const GRAVE := Color("#8F8E92")
const SNOW := Color("#F2F5F8")
const SNOW_SHADE := Color("#B9BCCF")
const BONNET := Color("#2E3446")
const BASALT := Color("#3A3433")
const IRON := Color("#3B3A3E")
const BRAISE := Color("#8E2A1E")
const LAVA := Color("#1E1517")
const LAVA_GOLD := Color("#E0A84A")
const EMBER := Color("#F29A3A")
const FLAME_CORE := Color("#FFD27A")
const SEAL_RED := Color("#B8352A")
const HULL := Color("#4A3A2E")
const CREW := Color("#27324A")
const ICE := Color("#BFD6E3")
const INK_SEA := Color("#1B2232")

## Index 0 = monde 1. Lecture seule (dictionnaires constants) : dupliquer avant de modifier.
const WORLDS: Array = [
	{
		"id": 1,
		"name": "Grande Vague",
		"kanji": "波",
		"subtitle": "Sous la vague au large de Kanagawa",
		"color": Color("#1F3A5F"),
		"sky": Color("#EFE6D2"),
		"fog": Color("#EFE6D2"),
		"fog_density": 0.0028,
		"sun_color": Color(1.0, 0.9, 0.78),
		"sun_energy": 0.72,
		"ambient_color": Color(0.86, 0.9, 1.0),
		"ambient_energy": 0.3,
		"ground": [Color("#B98E52"), Color("#AD8148"), Color("#C39A5E"), Color("#A57A43"), Color("#B48A50")],
		"ground_style": "planks",
		"edge": Color("#1B1A1E"),
		"under": Color("#5B4630"),
		"void": Color("#1F3A5F"),
		"void_metal": true,
		"enemies": {"oni": 5, "kappa": 2, "brute": 1, "tate": 1, "funa": 2},
		"hp_mult": 1.0,
	},
	{
		"id": 2,
		"name": "Tanabata",
		"kanji": "竹",
		"subtitle": "Feux de renards la nuit à Oji",
		"color": Color("#5E7F4A"),
		"sky": Color("#1F2A3A"),
		"fog": Color("#2C3848"),
		"fog_density": 0.0035,
		"sun_color": Color(0.78, 0.85, 1.0),
		"sun_energy": 0.55,
		"ambient_color": Color(0.58, 0.68, 0.88),
		"ambient_energy": 0.5,
		"ground": [Color("#8E8A7C"), Color("#827E70"), Color("#97937F"), Color("#7A7668"), Color("#8A8676")],
		"ground_style": "stones",
		"edge": Color("#26252B"),
		"under": Color("#3E4A3A"),
		"void": Color("#1E3330"),
		"void_metal": true,
		"enemies": {"oni": 3, "kappa": 3, "brute": 1, "tate": 2, "funa": 1},
		"hp_mult": 1.15,
	},
	{
		"id": 3,
		"name": "Cent Contes",
		"kanji": "雪",
		"subtitle": "Neige sur la Sumida",
		"color": Color("#8C8FA8"),
		"sky": Color("#D9DFE6"),
		"fog": Color("#E2E7EC"),
		"fog_density": 0.0045,
		"sun_color": Color(0.95, 0.97, 1.0),
		"sun_energy": 0.55,
		"ambient_color": Color(0.8, 0.86, 0.95),
		"ambient_energy": 0.45,
		"ground": [Color("#DDE4EC"), Color("#D0D9E3"), Color("#C6D0DC"), Color("#D8DFE8"), Color("#BFCAD8")],
		"ground_style": "snow",
		"edge": Color("#3A3A48"),
		"under": Color("#8C8FA8"),
		"void": Color("#34465A"),
		"void_metal": true,
		"enemies": {"oni": 2, "kappa": 2, "brute": 1, "tate": 1, "funa": 4},
		"hp_mult": 1.3,
	},
	{
		"id": 4,
		"name": "Fuji Rouge",
		"kanji": "火",
		"subtitle": "Vent du sud, ciel clair (Gaifu kaisei)",
		"color": Color("#8E2A1E"),
		"sky": Color("#3F5677"),
		"fog": Color("#5A4A4E"),
		"fog_density": 0.003,
		"sun_color": Color(1.0, 0.72, 0.52),
		"sun_energy": 0.8,
		"ambient_color": Color(1.0, 0.75, 0.6),
		"ambient_energy": 0.3,
		"ground": [Color("#4A4542"), Color("#55504B"), Color("#5A5550"), Color("#3F3B39"), Color("#4F4945")],
		"ground_style": "basalt",
		"edge": Color("#141215"),
		"under": Color("#2A2220"),
		"void": Color("#241A1A"),
		"void_metal": false,
		"enemies": {"oni": 3, "kappa": 1, "brute": 3, "tate": 2, "funa": 1},
		"hp_mult": 1.45,
	},
	{
		"id": 5,
		"name": "Trente-six Vues",
		"kanji": "墨",
		"subtitle": "Trente-six vues du mont Fuji",
		"color": Color("#0E1A2E"),
		"sky": Color("#EAD2C8"),
		"fog": Color("#E4C3B8"),
		"fog_density": 0.0035,
		"sun_color": Color(1.0, 0.88, 0.82),
		"sun_energy": 0.7,
		"ambient_color": Color(1.0, 0.9, 0.9),
		"ambient_energy": 0.35,
		"ground": [Color("#E9DFC9"), Color("#E2D6BD"), Color("#EFE6D2"), Color("#D9CCB1"), Color("#E6DBC4")],
		"ground_style": "paper",
		"edge": Color("#1B1A1E"),
		"under": Color("#3A3530"),
		"void": Color("#0E1A2E"),
		"void_metal": true,
		"enemies": {"oni": 2, "kappa": 2, "brute": 2, "tate": 3, "funa": 2},
		"hp_mult": 1.6,
	},
]

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


## Données du monde `id` (1..5).
static func world(id: int) -> Dictionary:
	var d: Dictionary = WORLDS[clampi(id, 1, WORLDS.size()) - 1]
	return d


# ------------------------------------------------------------------ matériaux (cache)

## Toon à contour d'encre (ou non), partagé par couleur.
static func _toon(color: Color, outline := true, osz := 0.03) -> StandardMaterial3D:
	var key := "t%s_%d_%.3f" % [color.to_html(true), 1 if outline else 0, osz]
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := Toon.mat(color, outline, osz)
	_mats[key] = m
	return m


## Toon sans contour, visible des deux faces (feuilles, herbes : maillages plats).
static func _toon_ds(color: Color) -> StandardMaterial3D:
	var key := "d" + color.to_html(true)
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := Toon.mat(color, false)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## Toon lumineux (flammes, lanternes, veines de lave).
static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var key := "g%s_%.2f" % [color.to_html(true), energy]
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := Toon.mat(color, false)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


## Aplat sans lumière pour le très lointain (transparent seulement si alpha < 1).
static func _flat(color: Color) -> StandardMaterial3D:
	var key := "f" + color.to_html(true)
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


## Aplat opaque à couleurs de sommets : tout le lointain « estampe » d'un monde en un draw call.
static func _vc_mat() -> StandardMaterial3D:
	if _mats.has("vc_flat"):
		var cached: StandardMaterial3D = _mats["vc_flat"]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["vc_flat"] = m
	return m


## Vague d'encre : le dégradé de sommets de Decor.great_wave assombri.
static func _ink_wave_mat() -> StandardMaterial3D:
	if _mats.has("ink_wave"):
		var cached: StandardMaterial3D = _mats["ink_wave"]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = Color(0.26, 0.26, 0.32)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["ink_wave"] = m
	return m


## Matériau de particules : couleur par particule, fondu alpha, additif pour les lueurs.
static func _pmat(billboard: bool, additive: bool) -> StandardMaterial3D:
	var key := "p%d%d" % [1 if billboard else 0, 1 if additive else 0]
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m


# ------------------------------------------------------------------ briques

static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(s * 7919 + 4243)
	return r


static func _at(p: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), p)


## Maillages partagés (cache de decor.gd).
static func _ball(r: float, h: float, seg := 8, rings := 4) -> SphereMesh:
	return Decor.ball(r, h, seg, rings)


static func _box(s: Vector3) -> BoxMesh:
	return Decor.box(s)


static func _cyl(top: float, bottom: float, h: float, sides := 8) -> CylinderMesh:
	return Decor.cyl(top, bottom, h, sides)


## Base dont l'axe Y suit `d`.
static func _basis_y(d: Vector3) -> Basis:
	if d.length_squared() < 0.000001:
		return Basis()
	var y := d.normalized()
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


## Ajoute une primitive au lot du matériau `m` (1 draw call par matériau au final).
static func _add(b: Dictionary, m: Material, mesh: Mesh, xf: Transform3D) -> void:
	var k := m.get_instance_id()
	if not b.has(k):
		var st0 := SurfaceTool.new()
		st0.begin(Mesh.PRIMITIVE_TRIANGLES)
		b[k] = [st0, m]
	var entry: Array = b[k]
	var st: SurfaceTool = entry[0]
	st.append_from(mesh, 0, xf)


static func _flush(b: Dictionary, parent: Node3D, shadow := false) -> void:
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


## Segment conique de a (rayon r0) vers c (rayon r1), placé par `xf`.
static func _limb(b: Dictionary, m: Material, a: Vector3, c: Vector3, r0: float, r1: float, sides := 6, xf := Transform3D.IDENTITY) -> void:
	var d := c - a
	var l := d.length()
	if l < 0.001:
		return
	_add(b, m, _cyl(r1, r0, l, sides), xf * Transform3D(_basis_y(d), (a + c) * 0.5))


## Corde qui s'affaisse entre a et c (suite de segments).
static func _rope(b: Dictionary, m: Material, a: Vector3, c: Vector3, sag: float, r := 0.02) -> void:
	var n := 6
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var q := a.lerp(c, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		_limb(b, m, prev, q, r, r, 4)
		prev = q


## Lot d'instances (MultiMesh) : une clé = un maillage + un matériau.
static func _inst(ctx: Dictionary, key: String, mesh: Mesh, mat: Material, xf: Transform3D, shadow := false) -> void:
	var mm: Dictionary = ctx["mm"]
	if not mm.has(key):
		mm[key] = [mesh, mat, [], shadow]
	var e: Array = mm[key]
	var list: Array = e[2]
	list.append(xf)


static func _flush_mm(mm: Dictionary, parent: Node3D) -> void:
	for k in mm:
		var e: Array = mm[k]
		var list: Array = e[2]
		if list.is_empty():
			continue
		var mesh: Mesh = e[0]
		var mat: Material = e[1]
		var shadow: bool = e[3]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = list.size()
		for i in list.size():
			var t: Transform3D = list[i]
			multi.set_instance_transform(i, t)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = multi
		mi.material_override = mat
		if shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Pièce isolée du lointain : aplat sans ombre.
static func _far(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Toon.part(parent, mesh, _flat(color), pos, scl)
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Montagne lointaine (cône) posée en `base`, avec calotte (neige, sommet sombre) qui épouse la pente.
static func _peak(parent: Node3D, base: Vector3, top_r: float, base_r: float, h: float, col: Color, cap: Color, cap_frac: float, sides: int) -> void:
	_far(parent, Toon.cyl(top_r, base_r, h, sides), col, base + Vector3(0, h * 0.5, 0))
	if cap_frac > 0.0:
		var hc := h * cap_frac
		var br := (top_r + (base_r - top_r) * cap_frac) * 1.04
		_far(parent, Toon.cyl(top_r * 1.04, br, hc, sides), cap, base + Vector3(0, h - hc * 0.5 + 0.02, 0))


## Rayon d'un cône (top_r en haut, base_r en bas, hauteur h) à la profondeur `depth` sous le sommet.
static func _cone_r(top_r: float, base_r: float, h: float, depth: float) -> float:
	return top_r + (base_r - top_r) * clampf(depth / h, 0.0, 1.0)


## Hauteur de la surface d'une berge en dôme (centre cx, cz ; rayon r ; aplatie à 0.15 r).
static func _dome_y(cx: float, cz: float, r: float, x: float, z: float) -> float:
	var d := Vector2(x - cx, z - cz).length() / r
	return VOID_Y + 0.15 * r * sqrt(maxf(1.0 - d * d, 0.0))


# ------------------------------------------------------------------ maillages faits main (cache)

## Croissant d'écume plat (deux traits concentriques), centré sur l'origine, tourné vers +Z.
static func _crescent_mesh() -> ArrayMesh:
	if _meshes.has("crescent"):
		var cached: ArrayMesh = _meshes["crescent"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for arc in 2:
		var rad := 0.5 - arc * 0.13
		var span := 1.0 - arc * 0.35
		var wmax := 0.09 - arc * 0.03
		var n := 10
		for i in n:
			var a0 := lerpf(-span, span, float(i) / n)
			var a1 := lerpf(-span, span, float(i + 1) / n)
			var w0 := wmax * sin(PI * float(i) / n) + 0.004
			var w1 := wmax * sin(PI * float(i + 1) / n) + 0.004
			var o0 := Vector3(sin(a0), 0, cos(a0))
			var o1 := Vector3(sin(a1), 0, cos(a1))
			st.add_vertex(o0 * (rad - w0 * 0.5))
			st.add_vertex(o1 * (rad - w1 * 0.5))
			st.add_vertex(o1 * (rad + w1 * 0.5))
			st.add_vertex(o0 * (rad - w0 * 0.5))
			st.add_vertex(o1 * (rad + w1 * 0.5))
			st.add_vertex(o0 * (rad + w0 * 0.5))
	var mesh := st.commit()
	_meshes["crescent"] = mesh
	return mesh


## Panache de feuilles de bambou retombantes (sommet des tiges).
static func _spray_mesh() -> ArrayMesh:
	if _meshes.has("spray"):
		var cached: ArrayMesh = _meshes["spray"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in 9:
		var yaw := TAU * k / 9.0 + (0.3 if k % 2 == 0 else 0.0)
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-dir.z, 0, dir.x)
		var ln := 0.5 + 0.14 * float(k % 3)
		var droop := -0.22 - 0.1 * float(k % 2)
		var base := dir * 0.04
		var mid := dir * ln * 0.5 + Vector3(0, droop * 0.3, 0)
		var tip := dir * ln + Vector3(0, droop, 0)
		var wdt := 0.065
		st.add_vertex(base)
		st.add_vertex(mid + side * wdt)
		st.add_vertex(mid - side * wdt)
		st.add_vertex(mid - side * wdt)
		st.add_vertex(mid + side * wdt)
		st.add_vertex(tip)
	var mesh := st.commit()
	_meshes["spray"] = mesh
	return mesh


## Touffe d'herbes / roseaux (lames fines en éventail), hauteur ~0.5.
static func _tuft_mesh() -> ArrayMesh:
	if _meshes.has("tuft"):
		var cached: ArrayMesh = _meshes["tuft"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in 7:
		var yaw := TAU * k / 7.0
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-dir.z, 0, dir.x)
		var h := 0.32 + 0.1 * float(k % 3)
		var tip := dir * (0.14 + 0.05 * float(k % 2)) + Vector3(0, h, 0)
		st.add_vertex(-side * 0.025)
		st.add_vertex(side * 0.025)
		st.add_vertex(tip)
	var mesh := st.commit()
	_meshes["tuft"] = mesh
	return mesh


# ------------------------------------------------------------------ lointain « estampe » (couleurs de sommets)

static func _vc_begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _vc_end(st: SurfaceTool, root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Estampe"
	mi.mesh = st.commit()
	mi.material_override = _vc_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _vv(st: SurfaceTool, col: Color, p: Vector3) -> void:
	st.set_color(col)
	st.add_vertex(p)


static func _vtri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_vv(st, ca, a)
	_vv(st, cb, b)
	_vv(st, cc, c)


## Quadrilatère a-b-c-d (dans l'ordre du contour), une couleur par sommet.
static func _vquad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_vtri(st, a, b, c, ca, cb, cc)
	_vtri(st, a, c, d, ca, cc, cd)


## Rectangle vertical face à +Z, de `lo` (bas-gauche) à `hi` (haut-droit), dégradé vertical.
static func _vrect(st: SurfaceTool, lo: Vector3, hi: Vector3, c_lo: Color, c_hi: Color) -> void:
	_vquad(st, Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), c_lo, c_lo, c_hi, c_hi)


## Trait d'encre plat de a à b (largeur w) dans le plan XY.
static func _vstroke(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var d := b - a
	var n := Vector3(-d.y, d.x, 0).normalized() * w * 0.5
	_vquad(st, a - n, b - n, b + n, a + n, col, col, col, col)


## Chaîne de montagnes en aplat (rideau face à +Z) : crête irrégulière, dégradé bokashi
## de `top_c` (crête) vers `low_c` (pied fondu dans la brume).
static func _ridge(st: SurfaceTool, rng: RandomNumberGenerator, x0: float, x1: float, z: float, base_y: float, h: float, top_c: Color, low_c: Color, steps := 28) -> void:
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var f1 := rng.randf_range(5.0, 8.0)
	var f2 := rng.randf_range(13.0, 19.0)
	var ys := PackedFloat32Array()
	for i in steps + 1:
		var t := float(i) / steps
		var y := h * (0.6 + 0.28 * sin(t * f1 + ph1) + 0.14 * sin(t * f2 + ph2)) + h * rng.randf_range(-0.06, 0.06)
		ys.append(maxf(y, h * 0.12))
	for i in steps:
		var xa := lerpf(x0, x1, float(i) / steps)
		var xb := lerpf(x0, x1, float(i + 1) / steps)
		var ya := ys[i]
		var yb := ys[i + 1]
		var ca := low_c.lerp(top_c, clampf(ya / h, 0.0, 1.0))
		var cb := low_c.lerp(top_c, clampf(yb / h, 0.0, 1.0))
		_vquad(st, Vector3(xa, base_y, z), Vector3(xb, base_y, z), Vector3(xb, base_y + yb, z), Vector3(xa, base_y + ya, z), low_c, low_c, cb, ca)


## Bande de brume (kasumi) aux bouts arrondis, dégradée de haut en bas.
static func _band(st: SurfaceTool, c: Vector3, w: float, hgt: float, top_c: Color, low_c: Color) -> void:
	var r := hgt * 0.5
	var ww := maxf(w, hgt * 2.2)
	var pts := PackedVector3Array()
	for k in 7:
		var a := -PI * 0.5 + PI * k / 6.0
		pts.append(c + Vector3(ww * 0.5 - r + cos(a) * r, sin(a) * r, 0))
	for k in 7:
		var a := PI * 0.5 + PI * k / 6.0
		pts.append(c + Vector3(-ww * 0.5 + r + cos(a) * r, sin(a) * r, 0))
	var cm := low_c.lerp(top_c, 0.5)
	var n := pts.size()
	for i in n:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var c0 := low_c.lerp(top_c, clampf((p0.y - c.y + r) / hgt, 0.0, 1.0))
		var c1 := low_c.lerp(top_c, clampf((p1.y - c.y + r) / hgt, 0.0, 1.0))
		_vtri(st, c, p0, p1, cm, c0, c1)


## Oiseau en « M » vu de loin.
static func _bird(st: SurfaceTool, p: Vector3, s: float, col: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		var e := p + Vector3(sx * s * 0.45, s * 0.22, 0)
		var t := p + Vector3(sx * s, s * 0.04, 0)
		_vtri(st, p + Vector3(0, s * 0.07, 0), e, p + Vector3(0, -s * 0.07, 0), col, col, col)
		_vtri(st, e, t, e + Vector3(0, -s * 0.11, 0), col, col, col)


static func _flock(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, n: int, spread: Vector3, s: float, col: Color) -> void:
	for i in n:
		var p := c + Vector3(rng.randf_range(-spread.x, spread.x), rng.randf_range(-spread.y, spread.y), rng.randf_range(-spread.z, spread.z))
		_bird(st, p, s * rng.randf_range(0.7, 1.2), col)


## Pagode en silhouette : étages, toits aux coins relevés, flèche ; fenêtres si `win.a > 0`.
static func _sil_pagoda(st: SurfaceTool, base: Vector3, s: float, tiers: int, col: Color, roof_c: Color, win: Color) -> void:
	var y := base.y
	var w := s
	var z := base.z
	for k in tiers:
		var bh := 0.5 * s
		_vrect(st, Vector3(base.x - w * 0.32, y, z), Vector3(base.x + w * 0.32, y + bh, z), col, col)
		if win.a > 0.0:
			_vrect(st, Vector3(base.x - w * 0.08, y + bh * 0.25, z + 0.15), Vector3(base.x + w * 0.08, y + bh * 0.75, z + 0.15), win, win)
		y += bh
		var rw := w * 0.82
		_vquad(st, Vector3(base.x - rw, y - 0.05 * s, z + 0.25), Vector3(base.x + rw, y - 0.05 * s, z + 0.25),
			Vector3(base.x + w * 0.36, y + 0.2 * s, z + 0.25), Vector3(base.x - w * 0.36, y + 0.2 * s, z + 0.25), roof_c, roof_c, roof_c, roof_c)
		for sx: float in [-1.0, 1.0]:
			_vtri(st, Vector3(base.x + sx * rw, y - 0.05 * s, z + 0.25), Vector3(base.x + sx * (rw + 0.12 * s), y + 0.1 * s, z + 0.25),
				Vector3(base.x + sx * (rw - 0.2 * s), y + 0.03 * s, z + 0.25), roof_c, roof_c, roof_c)
		y += 0.2 * s
		w *= 0.86
	_vstroke(st, Vector3(base.x, y, z), Vector3(base.x, y + 1.0 * s, z), 0.07 * s, roof_c)


## Bateau à voile carrée (bezaisen) en silhouette ; `facing` = ±1 (côté de la proue).
static func _sil_boat(st: SurfaceTool, p: Vector3, s: float, hull: Color, sail: Color, facing: float) -> void:
	var f := facing
	_vquad(st, p + Vector3(-1.0 * s * f, 0, 0), p + Vector3(1.0 * s * f, 0, 0), p + Vector3(1.45 * s * f, 0.42 * s, 0), p + Vector3(-1.15 * s * f, 0.32 * s, 0), hull, hull, hull, hull)
	_vstroke(st, p + Vector3(0, 0.3 * s, 0.1), p + Vector3(0, 2.7 * s, 0.1), 0.07 * s, hull)
	var sd := sail.darkened(0.08)
	_vquad(st, p + Vector3(-0.75 * s, 0.75 * s, 0.2), p + Vector3(0.75 * s, 0.75 * s, 0.2), p + Vector3(0.7 * s, 2.5 * s, 0.2), p + Vector3(-0.7 * s, 2.5 * s, 0.2), sd, sd, sail, sail)
	for k in 3:
		var x := (-0.37 + k * 0.37) * s
		_vstroke(st, p + Vector3(x, 0.78 * s, 0.3), p + Vector3(x, 2.47 * s, 0.3), 0.035 * s, sail.darkened(0.25))


## Maison de pêcheur en silhouette (mur, toit en trapèze).
static func _sil_house(st: SurfaceTool, p: Vector3, s: float, wall: Color, roof: Color) -> void:
	_vrect(st, p + Vector3(-0.6 * s, 0, 0), p + Vector3(0.6 * s, 0.55 * s, 0), wall, wall)
	_vquad(st, p + Vector3(-0.8 * s, 0.5 * s, 0.1), p + Vector3(0.8 * s, 0.5 * s, 0.1), p + Vector3(0.45 * s, 0.95 * s, 0.1), p + Vector3(-0.45 * s, 0.95 * s, 0.1), roof, roof, roof, roof)


## Temple en silhouette : grand toit en croupe aux coins relevés, ligne de neige si `snow.a > 0`.
static func _sil_temple(st: SurfaceTool, p: Vector3, s: float, wall: Color, roof: Color, snow: Color) -> void:
	_vrect(st, p + Vector3(-1.2 * s, 0, 0), p + Vector3(1.2 * s, 0.8 * s, 0), wall, wall)
	_vquad(st, p + Vector3(-1.9 * s, 0.75 * s, 0.2), p + Vector3(1.9 * s, 0.75 * s, 0.2), p + Vector3(0.9 * s, 1.55 * s, 0.2), p + Vector3(-0.9 * s, 1.55 * s, 0.2), roof, roof, roof, roof)
	for sx: float in [-1.0, 1.0]:
		_vtri(st, p + Vector3(sx * 1.9 * s, 0.75 * s, 0.2), p + Vector3(sx * 2.1 * s, 0.95 * s, 0.2), p + Vector3(sx * 1.6 * s, 0.85 * s, 0.2), roof, roof, roof)
	if snow.a > 0.0:
		_vquad(st, p + Vector3(-0.95 * s, 1.48 * s, 0.3), p + Vector3(0.95 * s, 1.48 * s, 0.3), p + Vector3(0.85 * s, 1.62 * s, 0.3), p + Vector3(-0.85 * s, 1.62 * s, 0.3), snow, snow, snow, snow)


## Lisière de conifères (triangles), chapeaux de neige si `cap.a > 0`.
static func _sil_trees(st: SurfaceTool, rng: RandomNumberGenerator, x0: float, x1: float, z: float, y0: float, n: int, h: float, col: Color, cap: Color) -> void:
	for i in n:
		var hh := h * rng.randf_range(0.6, 1.3)
		var w := hh * 0.32
		var b := Vector3(rng.randf_range(x0, x1), y0 + rng.randf_range(-0.3, 0.6), z + rng.randf_range(-1.0, 1.0))
		_vtri(st, b + Vector3(-w, 0, 0), b + Vector3(w, 0, 0), b + Vector3(0, hh, 0), col, col, col)
		_vtri(st, b + Vector3(-w * 0.8, hh * 0.4, 0.05), b + Vector3(w * 0.8, hh * 0.4, 0.05), b + Vector3(0, hh * 1.1, 0.05), col, col, col)
		if cap.a > 0.0:
			_vtri(st, b + Vector3(-w * 0.42, hh * 0.72, 0.1), b + Vector3(w * 0.42, hh * 0.72, 0.1), b + Vector3(0, hh * 1.1, 0.1), cap, cap, cap)


## Pont en arc en silhouette (tablier, garde-corps, poteaux), piles sur les côtés ; neige si `snow.a > 0`.
static func _sil_bridge(st: SurfaceTool, c: Vector3, span: float, rise: float, thick: float, col: Color, snow: Color, piles: int) -> void:
	var n := 18
	var half := span * 0.5
	for i in n:
		var x0 := lerpf(-half, half, float(i) / n)
		var x1 := lerpf(-half, half, float(i + 1) / n)
		var y0 := rise * (1.0 - pow(x0 / half, 2.0))
		var y1 := rise * (1.0 - pow(x1 / half, 2.0))
		_vquad(st, c + Vector3(x0, y0 - thick, 0), c + Vector3(x1, y1 - thick, 0), c + Vector3(x1, y1, 0), c + Vector3(x0, y0, 0), col, col, col, col)
		_vquad(st, c + Vector3(x0, y0 + thick * 0.75, 0.1), c + Vector3(x1, y1 + thick * 0.75, 0.1), c + Vector3(x1, y1 + thick * 0.95, 0.1), c + Vector3(x0, y0 + thick * 0.95, 0.1), col, col, col, col)
		_vstroke(st, c + Vector3(x0, y0, 0.1), c + Vector3(x0, y0 + thick * 0.95, 0.1), thick * 0.1, col)
		if snow.a > 0.0:
			_vquad(st, c + Vector3(x0, y0 - 0.02, 0.2), c + Vector3(x1, y1 - 0.02, 0.2), c + Vector3(x1, y1 + thick * 0.22, 0.2), c + Vector3(x0, y0 + thick * 0.22, 0.2), snow, snow, snow, snow)
	var per_side := maxi(int(ceil(float(piles) * 0.5)), 1)
	for k in piles:
		var sx: float = -1.0 if k % 2 == 0 else 1.0
		var j := floorf(float(k) * 0.5)
		var x := sx * half * (0.45 + 0.4 * j / maxf(float(per_side - 1), 1.0))
		var y := rise * (1.0 - pow(x / half, 2.0)) - thick
		_vrect(st, c + Vector3(x - thick * 0.18, -2.0, 0.05), c + Vector3(x + thick * 0.18, y, 0.05), col, col)


## Ensō : cercle zen tracé d'un seul geste (s'amincit, ouverture en fin de trait).
static func _enso(st: SurfaceTool, c: Vector3, r: float, thick: float, col: Color) -> void:
	var n := 40
	var a0 := 0.6
	var span := TAU * 0.9
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var w0 := thick * (1.0 - 0.75 * t0) * (0.85 + 0.15 * sin(t0 * 31.0))
		var w1 := thick * (1.0 - 0.75 * t1) * (0.85 + 0.15 * sin(t1 * 31.0))
		var d0 := Vector3(cos(a0 + span * t0), sin(a0 + span * t0), 0)
		var d1 := Vector3(cos(a0 + span * t1), sin(a0 + span * t1), 0)
		_vquad(st, c + d0 * (r - w0 * 0.5), c + d1 * (r - w1 * 0.5), c + d1 * (r + w1 * 0.5), c + d0 * (r + w0 * 0.5), col, col, col, col)


## Fudō Myōō en silhouette : rocher, corps assis, tête, épée, halo de flammes (karura-en).
static func _fudo(st: SurfaceTool, p: Vector3, s: float, body: Color, fin: Color, fout: Color) -> void:
	var hc := p + Vector3(0, 6.2 * s, -0.5)
	var n := 20
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		_vtri(st, hc, hc + Vector3(cos(a0), sin(a0), 0) * 3.0 * s, hc + Vector3(cos(a1), sin(a1), 0) * 3.0 * s, fout, fin, fin)
	for k in 15:
		var a := deg_to_rad(-30.0 + 240.0 * k / 14.0)
		var tip_r := (4.3 + 0.9 * sin(k * 1.7)) * s
		_vtri(st, hc + Vector3(cos(a - 0.13), sin(a - 0.13), 0) * 2.7 * s, hc + Vector3(cos(a + 0.13), sin(a + 0.13), 0) * 2.7 * s,
			hc + Vector3(cos(a + 0.18), sin(a + 0.18), 0) * tip_r, fin, fin, fout)
	var z := p.z + 0.3
	_vquad(st, Vector3(p.x - 2.8 * s, p.y, z), Vector3(p.x + 2.8 * s, p.y, z), Vector3(p.x + 2.1 * s, p.y + 1.5 * s, z), Vector3(p.x - 2.1 * s, p.y + 1.5 * s, z), body, body, body, body)
	_vquad(st, Vector3(p.x - 1.7 * s, p.y + 1.5 * s, z), Vector3(p.x + 1.7 * s, p.y + 1.5 * s, z), Vector3(p.x + 1.0 * s, p.y + 4.9 * s, z), Vector3(p.x - 1.0 * s, p.y + 4.9 * s, z), body, body, body, body)
	var head := Vector3(p.x, p.y + 5.6 * s, z)
	for k in 8:
		var a0 := TAU * k / 8.0
		var a1 := TAU * (k + 1) / 8.0
		_vtri(st, head, head + Vector3(cos(a0), sin(a0), 0) * 0.8 * s, head + Vector3(cos(a1), sin(a1), 0) * 0.8 * s, body, body, body)
	_vstroke(st, Vector3(p.x + 1.4 * s, p.y + 2.2 * s, z + 0.1), Vector3(p.x + 1.9 * s, p.y + 7.0 * s, z + 0.1), 0.22 * s, Color("#B8B2A6"))


## Personnage croqué du Hokusai Manga (traits d'encre), en pleine course si `pose` = ±1.
static func _sketch_man(st: SurfaceTool, p: Vector3, s: float, col: Color, pose: float) -> void:
	var hip := p + Vector3(0, 0.9 * s, 0)
	var neck := hip + Vector3(0.12 * s * pose, 0.6 * s, 0)
	_vstroke(st, hip, neck, 0.08 * s, col)
	var hc := neck + Vector3(0.05 * s * pose, 0.2 * s, 0)
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		_vtri(st, hc, hc + Vector3(cos(a0), sin(a0), 0) * 0.13 * s, hc + Vector3(cos(a1), sin(a1), 0) * 0.13 * s, col, col, col)
	_vstroke(st, hip, p + Vector3(0.32 * s * pose, 0, 0), 0.06 * s, col)
	_vstroke(st, hip, hip + Vector3(-0.2 * s * pose, -0.45 * s, 0), 0.06 * s, col)
	_vstroke(st, hip + Vector3(-0.2 * s * pose, -0.45 * s, 0), p + Vector3(-0.42 * s * pose, 0.08 * s, 0), 0.05 * s, col)
	var sh := neck - Vector3(0, 0.08 * s, 0)
	_vstroke(st, sh, sh + Vector3(0.38 * s * pose, -0.22 * s, 0), 0.05 * s, col)
	_vstroke(st, sh, sh + Vector3(-0.3 * s * pose, -0.3 * s, 0), 0.05 * s, col)

# ------------------------------------------------------------------ lointain

## Le lointain du monde : vu surtout depuis la caméra d'accueil (basse, vers -Z)
## et en haut de la vue de jeu. Tout est hors de |x| < 9 et |z| < 12.
static func build_backdrop(world_id: int, parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Backdrop"
	parent.add_child(root)
	match clampi(world_id, 1, 5):
		1:
			_backdrop_wave(root)
		2:
			_backdrop_tanabata(root)
		3:
			_backdrop_contes(root)
		4:
			_backdrop_fuji_rouge(root)
		_:
			_backdrop_ink(root)


## Monde 1 : port de Kanagawa. Ciel d'aube du premier jour, chaînes bleues en couches, village,
## brume en bandes, voiles et oiseaux de mer ; Fuji, soleil vermillon, Grande Vague, îlots ;
## plus près : torii dans l'eau, ponton du port, lanterne de port, pieux d'amarrage, barques.
static func _backdrop_wave(root: Node3D) -> void:
	var rng := _rng(11)
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -250), Vector3(340, 30, -250), Color("#EDB48F"), Toon.WASHI)
	_vrect(st, Vector3(-340, 30, -250), Vector3(340, 140, -250), Toon.WASHI, Color("#DCD6C6"))
	_ridge(st, rng, -280.0, 280.0, -215.0, -1.0, 11.0, Color("#8597B0"), Color("#E6D8C2"), 34)
	_ridge(st, rng, -260.0, 260.0, -192.0, -1.0, 7.0, Color("#5F7593"), Color("#DCD3C1"), 34)
	_ridge(st, rng, -220.0, 220.0, -128.0, -1.0, 3.2, Color("#3F5878"), Color("#C9C6B8"), 30)
	for i in 18:
		var x := rng.randf_range(-110.0, 110.0)
		if absf(x + 18.0) < 14.0:
			continue
		_sil_house(st, Vector3(x, -0.6, -126.5), rng.randf_range(2.0, 3.2), Color("#4A5E78"), Color("#2E3B52"))
	for k in 7:
		_band(st, Vector3(rng.randf_range(-90.0, 90.0), 3.0 + k * 3.2 + rng.randf_range(-1.0, 1.0), -112.0 - k * 6.0),
			rng.randf_range(40.0, 95.0), rng.randf_range(1.6, 3.2), Color("#F7F0E2"), Color("#E9DCC6"))
	for k in 7:
		var z := rng.randf_range(-115.0, -45.0)
		var face: float = -1.0 if rng.randf() < 0.5 else 1.0
		_sil_boat(st, Vector3(rng.randf_range(-60.0, 60.0), VOID_Y, z), rng.randf_range(0.9, 1.5) * (1.0 - z / 260.0), Color("#2E3B52"), Color("#F4EEDF"), face)
	_flock(st, rng, Vector3(10, 17, -75), 9, Vector3(14, 4, 6), 1.1, Color("#2B3448"))
	_flock(st, rng, Vector3(-30, 24, -120), 6, Vector3(10, 3, 4), 1.6, Color("#3A4660"))
	_vc_end(st, root)
	# Fuji bleu et sa neige, soleil vermillon du premier jour, brume
	_far(root, Toon.cyl(2.0, 46.0, 26.0, 48), Color("#5D7392"), Vector3(-18, 12.4, -170))
	_far(root, Toon.cyl(2.05, 12.5, 7.0, 48), Toon.FOAM, Vector3(-18, 21.9, -169.6))
	_far(root, Toon.sphere(11.0), Toon.VERMILION, Vector3(26, 26, -230))
	var mist := Color(Toon.WASHI, 0.85)
	_far(root, _box(Vector3(140, 1.6, 0.1)), mist, Vector3(-30, 6.0, -150))
	_far(root, _box(Vector3(90, 1.1, 0.1)), mist, Vector3(30, 10.5, -160))
	# rides d'écume au large
	var foam := {}
	var fm := _toon(Toon.FOAM, false)
	for i in 40:
		var x := rng.randf_range(-27.0, 27.0)
		var z := rng.randf_range(-70.0, -13.0)
		_add(foam, fm, Toon.box(Vector3(rng.randf_range(1.8, 6.6), 0.02, 0.14)), _at(Vector3(x, VOID_Y + 0.01, z)))
	_flush(foam, root)
	# la Grande Vague de Kanagawa et des îlots à pins
	var w1: Node3D = Decor.great_wave(root, Vector3(-24, VOID_Y, -48), 2.6, 1)
	w1.rotation.y = 0.6
	var w2: Node3D = Decor.great_wave(root, Vector3(32, VOID_Y, -75), 3.5, 2)
	w2.rotation.y = -0.5
	Decor.island(root, Vector3(14, VOID_Y, -30), 1.4, 1)
	Decor.island(root, Vector3(-34, VOID_Y, -70), 2.4, 2)
	Decor.island(root, Vector3(45, VOID_Y, -110), 3.0, 3)
	# le port, plus près
	var b := {}
	var bn := {}
	Decor.torii_into(b, _at(Vector3(-14.0, VOID_Y, -27.0), Vector3(0, 0.3, 0), Vector3.ONE * 0.95), -0.7)
	var px := _at(Vector3(13.0, 0.0, -19.0), Vector3(0, -0.12, 0))
	Decor.pier_into(b, px, 1.7, 7.5, -0.05, VOID_Y - 0.4)
	for k in 4:
		Decor.sake_barrel_into(b, bn, px * _at(Vector3(rng.randf_range(-0.45, 0.45), -0.05, -2.8 + k * 0.6), Vector3(0, rng.randf() * TAU, 0)))
	Decor.net_rack_into(b, bn, px * _at(Vector3(0, 0, 1.6), Vector3(0, PI * 0.5, 0)), -0.05)
	_port_lantern_into(b, bn, _at(Vector3(11.0, VOID_Y, -24.5), Vector3.ZERO, Vector3.ONE * 1.3))
	for k in 12:
		var top := _bitt_into(b, bn, Vector3(-10.6 + rng.randf_range(-0.2, 0.2), VOID_Y - 0.3, -12.5 - k * 2.3), rng.randf_range(1.2, 1.9))
		if rng.randf() < 0.3:
			Decor.gull_into(bn, _at(top, Vector3(0, rng.randf() * TAU, 0)))
	_boat_into(b, _at(Vector3(-17.5, VOID_Y, -17.0), Vector3(0, 0.5, 0), Vector3.ONE * 1.1), 2)
	_boat_into(b, _at(Vector3(18.0, VOID_Y, -33.0), Vector3(0, -0.3, 0), Vector3.ONE * 1.2), 3)
	_boat_into(b, _at(Vector3(-6.0, VOID_Y, -38.0), Vector3(0, 0.1, 0), Vector3.ONE * 1.3), 0)
	_flush(b, root, false)
	_flush(bn, root, false)


## Monde 2 : nuit de Tanabata, ciel en bokashi nocturne, chaînes sombres, pagode aux fenêtres
## éclairées, nuages en bandes devant la lune, procession des feux de renards ; rideau de bambous,
## allée de torii, cascade de Kirifuri, pont arqué vermillon.
static func _backdrop_tanabata(root: Node3D) -> void:
	var rng := _rng(22)
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 40, -252), Color("#2E3B4E"), Color("#1F2A3A"))
	_vrect(st, Vector3(-340, 40, -252), Vector3(340, 150, -252), Color("#1F2A3A"), Color("#121A26"))
	_ridge(st, rng, -280.0, 280.0, -205.0, -1.0, 24.0, Color("#2C384C"), Color("#2C3848"), 30)
	_ridge(st, rng, -260.0, 260.0, -178.0, -1.0, 13.0, Color("#1C2531"), Color("#283444"), 30)
	_ridge(st, rng, 8.0, 64.0, -106.0, -1.0, 5.0, Color("#18202A"), Color("#202B38"), 12)
	_sil_pagoda(st, Vector3(36, 2.6, -105.5), 2.6, 5, Color("#141A22"), Color("#0F141B"), Color("#F2C46A"))
	_band(st, Vector3(-18, 26.5, -146), 36.0, 1.5, Color("#5A6880"), Color("#3B475C"))
	_band(st, Vector3(-32, 33.0, -146), 24.0, 1.1, Color("#5A6880"), Color("#3B475C"))
	_band(st, Vector3(30, 40.0, -170), 60.0, 2.0, Color("#3E4A60"), Color("#2C3848"))
	for i in 22:
		var t := float(i) / 21.0
		var c := Vector3(lerpf(-46.0, -6.0, t), 2.0 + 5.0 * t + sin(t * 9.0) * 1.2, -96.0)
		_vrect(st, c - Vector3(0.28, 0.4, 0), c + Vector3(0.28, 0.4, 0), Color("#F6D58A"), Color("#FBE9B8"))
	_vc_end(st, root)
	# lune et son halo (disque tourné vers la caméra)
	_far(root, Toon.sphere(6.0), Color("#F4ECD2"), Vector3(-24, 30, -150))
	_far(root, Toon.cyl(11.0, 11.0, 0.1, 32), Color(0.96, 0.93, 0.82, 0.12), Vector3(-24, 30, -158), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	# Voie lactée en bande, étoiles
	_far(root, _box(Vector3(340, 16, 0.1)), Color(0.9, 0.9, 1.0, 0.07), Vector3(20, 62, -240), Vector3.ONE, Vector3(0, 0, -0.32))
	_far(root, _box(Vector3(340, 6, 0.1)), Color(0.95, 0.95, 1.0, 0.1), Vector3(20, 62, -239), Vector3.ONE, Vector3(0, 0, -0.32))
	var stars := {}
	var sm := _flat(Color("#F6F0DC"))
	for i in 70:
		var p := Vector3(rng.randf_range(-170.0, 170.0), rng.randf_range(18.0, 110.0), rng.randf_range(-235.0, -215.0))
		var r := rng.randf_range(0.25, 0.6)
		_add(stars, sm, Toon.box(Vector3(r, r, r)), _at(p, Vector3(0, 0, PI * 0.25)))
	_flush(stars, root)
	# montagnes sombres
	for i in 6:
		var h := rng.randf_range(18.0, 34.0)
		_peak(root, Vector3(-90.0 + i * 36.0 + rng.randf_range(-8.0, 8.0), -1.0, rng.randf_range(-130.0, -115.0)),
			1.5, h * 1.3, h, Color("#26313F"), Color("#26313F"), 0.0, 7)
	# cascade de Kirifuri : falaise, filets d'eau digités, brume au pied
	var fall := Node3D.new()
	fall.name = "Kirifuri"
	fall.position = Vector3(26, VOID_Y, -82)
	root.add_child(fall)
	var fb := {}
	var cliff := _flat(Color("#2F3B45"))
	var cliff_hi := _flat(Color("#3A4752"))
	var water := _flat(Color("#DCE7EF"))
	_add(fb, cliff, Toon.box(Vector3(16, 30, 6)), _at(Vector3(0, 15, -3)))
	_add(fb, cliff_hi, Toon.box(Vector3(13, 4, 8)), _at(Vector3(-0.5, 29, 0), Vector3(0, 0, 0.08)))
	for k in 6:
		var x := -4.0 + k * 1.6 + rng.randf_range(-0.3, 0.3)
		var w := rng.randf_range(0.5, 1.2)
		_add(fb, water, Toon.box(Vector3(w, 26, 0.2)), _at(Vector3(x, 14, 0.6)))
		for sx: float in [-1.0, 1.0]:
			_add(fb, water, Toon.box(Vector3(w * 0.35, 6, 0.2)), _at(Vector3(x + sx * w * 0.5, 3.5, 0.7), Vector3(0, 0, sx * 0.18)))
	var mist := _flat(Color(0.92, 0.95, 1.0, 0.5))
	for k in 4:
		_add(fb, mist, Toon.sphere(1.0), _at(Vector3(-4.0 + k * 2.8, 0.6, 1.5), Vector3.ZERO, Vector3(4.0, 2.5, 4.0)))
	_flush(fb, fall)
	# rideau lointain de tiges (aplats) et leurs feuillages sombres
	var far := {}
	var g1 := _flat(Color("#2C4434"))
	var g2 := _flat(Color("#38563F"))
	var gl := _flat(Color("#27402F"))
	for i in 56:
		var x := rng.randf_range(-34.0, 34.0)
		var z := rng.randf_range(-40.0, -24.0)
		var h := rng.randf_range(14.0, 24.0)
		var w := rng.randf_range(0.22, 0.42)
		var gm: StandardMaterial3D = g1 if rng.randf() < 0.5 else g2
		_add(far, gm, Toon.cyl(w * 0.8, w, h, 5), _at(Vector3(x, VOID_Y + h * 0.5, z), Vector3(0, 0, rng.randf_range(-0.04, 0.04))))
		_add(far, gl, _ball(rng.randf_range(1.2, 2.2), rng.randf_range(0.8, 1.4), 7, 3), _at(Vector3(x, VOID_Y + h, z)))
	_flush(far, root)
	# bosquets de bambous géants, allée de torii vermillon, pont arqué
	var b := {}
	var bn := {}
	for k in 9:
		Decor.bamboo_into(b, bn, _at(Vector3(-12.0 + k * 3.0 + rng.randf_range(-0.6, 0.6), VOID_Y, rng.randf_range(-16.5, -13.5)), Vector3.ZERO,
			Vector3.ONE * rng.randf_range(2.6, 3.4)), 200 + k)
	for k in 5:
		Decor.bamboo_into(b, bn, _at(Vector3(rng.randf_range(10.5, 12.5), VOID_Y, -11.0 + k * 3.8), Vector3.ZERO, Vector3.ONE * rng.randf_range(2.4, 3.2)), 220 + k)
	for k in 3:
		Decor.bamboo_into(b, bn, _at(Vector3(rng.randf_range(-15.0, -14.0), VOID_Y, -10.0 + k * 5.0), Vector3.ZERO, Vector3.ONE * rng.randf_range(2.4, 3.0)), 240 + k)
	for k in 9:
		Decor.torii_into(b, _at(Vector3(-11.0, VOID_Y, -12.5 - k * 2.3), Vector3.ZERO, Vector3.ONE * 0.8), 0.0)
	var bxf := _at(Vector3(16.5, VOID_Y + 0.3, -23.0), Vector3(0, -0.35, 0))
	Decor.arched_bridge_into(b, bxf, 7.0, 1.4, Toon.VERMILION.darkened(0.08), Color("#3B2E25"), -0.7)
	for sx: float in [-1.0, 1.0]:
		var e := bxf * Vector3(sx * 4.0, -0.3, 0.0)
		Decor.rock_into(b, _at(Vector3(e.x, VOID_Y, e.z), Vector3.ZERO, Vector3.ONE * 1.4), 300 + int(sx))
		Decor.stone_lantern_into(b, bn, _at(Vector3(e.x, VOID_Y + 0.45, e.z), Vector3.ZERO, Vector3.ONE * 0.9))
	_flush(b, root, false)
	_flush(bn, root, false)


## Monde 3 : temple sous la neige. Ciel bokashi lavande en haut, chaînes blanches en couches,
## lisière de conifères enneigés, toits de temples, pont de la Sumida sous la neige, corbeaux ;
## berges, pagode, cimetière, pins, beffroi, torii enneigé, lanternes flottantes.
static func _backdrop_contes(root: Node3D) -> void:
	var rng := _rng(33)
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 24, -252), Color("#E2E7EC"), Color("#D3D9E2"))
	_vrect(st, Vector3(-340, 24, -252), Vector3(340, 150, -252), Color("#D3D9E2"), Color("#6F7896"))
	_ridge(st, rng, -280.0, 280.0, -222.0, -1.0, 30.0, Color("#F2F5F8"), Color("#A9AFC2"), 34)
	_ridge(st, rng, -260.0, 260.0, -196.0, -1.0, 17.0, Color("#E9EDF2"), Color("#9AA1B6"), 30)
	_sil_trees(st, rng, -160.0, 160.0, -158.0, -1.0, 70, 6.0, Color("#3E4656"), SNOW)
	for k in 3:
		_sil_temple(st, Vector3(-70.0 + k * 62.0 + rng.randf_range(-8.0, 8.0), 0.5, -156.0), rng.randf_range(4.0, 6.0), Color("#4A4652"), Color("#2E2C33"), SNOW)
	_sil_bridge(st, Vector3(-26.0, VOID_Y, -74.0), 48.0, 3.4, 0.8, Color("#3A3A48"), SNOW, 6)
	_flock(st, rng, Vector3(-8, 16, -62), 7, Vector3(10, 3, 5), 1.0, Color("#2B2A30"))
	_flock(st, rng, Vector3(26, 22, -95), 5, Vector3(8, 3, 4), 1.4, Color("#3A3942"))
	_vc_end(st, root)
	# montagnes blanches lointaines (pied lavande, calotte de neige)
	for i in 7:
		var h := rng.randf_range(22.0, 40.0)
		_peak(root, Vector3(-100.0 + i * 33.0 + rng.randf_range(-6.0, 6.0), -1.0, rng.randf_range(-170.0, -120.0)),
			1.0, h * 1.4, h, Color("#A9AFC2"), Color("#EEF2F6"), 0.55, 9)
	# berges enneigées : (x, z, rayon)
	var banks: Array[Vector3] = [Vector3(-11, -20, 7), Vector3(10, -19, 6), Vector3(0, -33, 10),
		Vector3(-12.5, -4, 3.5), Vector3(12.5, 1, 3.5)]
	var sb := {}
	var snow := _toon(SNOW, false)
	var shade := _toon(SNOW_SHADE, false)
	for bk in banks:
		_add(sb, snow, Toon.sphere(1.0), _at(Vector3(bk.x, VOID_Y, bk.y), Vector3.ZERO, Vector3(bk.z, bk.z * 0.15, bk.z)))
		_add(sb, shade, Toon.cyl(bk.z * 1.03, bk.z * 1.06, 0.05, 18), _at(Vector3(bk.x, VOID_Y + 0.02, bk.y)))
	# pagode sur la berge de gauche, beffroi et torii enneigé sur la berge du fond
	var b := {}
	var bn := {}
	_pagoda_into(sb, _at(Vector3(-11, VOID_Y + 7.0 * 0.15 - 0.08, -20), Vector3(0, 0.3, 0), Vector3.ONE * 1.5))
	Decor.bell_tower_into(sb, bn, _at(Vector3(-2.5, _dome_y(0, -33, 10, -2.5, -36) - 0.05, -36.0), Vector3(0, 0.2, 0), Vector3.ONE * 1.25), true)
	_snow_torii(sb, bn, _at(Vector3(2.5, _dome_y(0, -33, 10, 2.5, -29) - 0.08, -29.0), Vector3(0, -0.15, 0), Vector3.ONE * 0.75))
	for k in 4:
		var lx := 1.2 + k * 0.9
		var lz := -25.5 + k * 0.3
		Decor.stone_lantern_into(b, bn, _at(Vector3(lx, _dome_y(0, -33, 10, lx, lz) - 0.04, lz), Vector3.ZERO, Vector3.ONE * 0.8))
	# cimetière : stèles en rangées sur la berge de droite
	var gm := _toon(GRAVE, true, 0.02)
	for i in 4:
		for j in 4:
			var lx := -2.4 + j * 1.5 + rng.randf_range(-0.2, 0.2)
			var lz := -2.0 + i * 1.3 + rng.randf_range(-0.2, 0.2)
			var y := _dome_y(0, 0, 6, lx, lz) - 0.05
			var xf := _at(Vector3(10.0 + lx, y, -19.0 + lz), Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.08, 0.08)),
				Vector3.ONE * rng.randf_range(0.9, 1.25))
			_stele_into(b, gm, snow, xf)
	_sotoba_into(b, _at(Vector3(10.2, _dome_y(10, -19, 6, 10.2, -22.5) - 0.05, -22.5)), rng)
	# pins enneigés sur les berges
	var pspots: Array[Vector3] = [Vector3(-15, 0.1, -17), Vector3(-7, 0.1, -23), Vector3(-5, 0.6, -30), Vector3(6, 0.6, -31),
		Vector3(14, -0.1, -16), Vector3(-12.5, -0.15, -4), Vector3(12.8, -0.15, 1)]
	for p in pspots:
		_snow_pine_into(sb, _at(p, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(1.3, 2.0)))
	Decor.stone_lantern_into(b, bn, _at(Vector3(7.0, 0.15, -16.5)))
	_flush(sb, root, true)
	# lanternes flottantes (tōrō nagashi) et glaçons sur l'étang
	var placed := 0
	for attempt in 160:
		if placed >= 30:
			break
		var p := Vector3.ZERO
		if rng.randf() < 0.65:
			p = Vector3(rng.randf_range(-15.0, 15.0), VOID_Y, rng.randf_range(-36.0, -13.0))
		else:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector3(sx * rng.randf_range(9.5, 14.0), VOID_Y, rng.randf_range(-11.0, 6.0))
		var inside := false
		for bk in banks:
			if Vector2(p.x - bk.x, p.z - bk.y).length() < bk.z * 1.1:
				inside = true
				break
		if inside:
			continue
		if placed % 3 == 2:
			_add(bn, _toon(ICE, false), _cyl(0.6, 0.62, 0.06, 6), _at(p + Vector3(0, 0.02, 0), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.8, 1.8), 1, rng.randf_range(0.6, 1.4))))
		else:
			_toro_into(bn, _at(p, Vector3(0, rng.randf() * TAU, 0)))
		placed += 1
	_flush(b, root, false)
	_flush(bn, root, false)


## Monde 4 : Fuji rouge (Gaifū kaisei) sous un ciel bokashi bleu de Prusse, nuages en écailles,
## pagode Chūreitō, Fudō Myōō et son halo de flammes, fumée du sommet ; coulées de lave noire
## veinée d'or, piques de roche, torches géantes de Yoshida, torii qui encadre le Fuji.
static func _backdrop_fuji_rouge(root: Node3D) -> void:
	var rng := _rng(44)
	var fx := 8.0
	var fz := -165.0
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 28, -252), Color("#D9A07A"), Color("#5E7393"))
	_vrect(st, Vector3(-340, 28, -252), Vector3(340, 150, -252), Color("#5E7393"), Toon.PRUSSIAN)
	_ridge(st, rng, -260.0, -36.0, -152.0, -1.0, 11.0, Color("#33403C"), Color("#5A4A4E"), 18)
	_ridge(st, rng, 52.0, 260.0, -152.0, -1.0, 11.0, Color("#33403C"), Color("#5A4A4E"), 18)
	_ridge(st, rng, -220.0, 220.0, -116.0, -1.0, 3.6, Color("#1E2523"), Color("#3A3335"), 30)
	_ridge(st, rng, -52.0, -16.0, -112.0, -1.0, 4.5, Color("#1A211F"), Color("#2F2A2C"), 10)
	_sil_pagoda(st, Vector3(-34, 2.6, -111.5), 2.4, 5, Color("#3A2422"), Color("#24171A"), Color(0, 0, 0, 0))
	_fudo(st, Vector3(34, -1.0, -100), 1.5, Color("#1E1517"), LAVA_GOLD, BRAISE)
	for k in 4:
		_band(st, Vector3(fx + 6.0 + k * 7.0, 31.0 + k * 3.0, fz + 8.0), 14.0 + k * 6.0, 1.4, Color("#9A8C86"), Color("#7C6E6A"))
	_flock(st, rng, Vector3(-6, 22, -120), 5, Vector3(10, 4, 4), 1.4, Color("#1E1A1C"))
	_vc_end(st, root)
	_peak(root, Vector3(fx, -1.0, fz), 3.0, 52.0, 30.0, Color("#A3462E"), Color("#5E2A22"), 0.2, 40)
	# coulées de neige au sommet (face caméra)
	var streaks := {}
	var white := _flat(Color("#F1EEE6"))
	for k in 9:
		var ang := rng.randf_range(-0.9, 0.9)
		var d0 := 0.4
		var d1 := rng.randf_range(3.0, 7.5)
		var r0 := _cone_r(3.0, 52.0, 30.0, d0) * 1.07
		var r1 := _cone_r(3.0, 52.0, 30.0, d1) * 1.07
		var a := Vector3(fx + sin(ang) * r0, 29.0 - d0, fz + cos(ang) * r0)
		var c := Vector3(fx + sin(ang) * r1, 29.0 - d1, fz + cos(ang) * r1)
		_limb(streaks, white, a, c, 0.35, 0.6, 4)
	_flush(streaks, root)
	# forêt sombre au pied
	_far(root, Toon.sphere(1.0), Color("#2B3F3C"), Vector3(fx, -2.0, -140.0), Vector3(70.0, 7.0, 24.5))
	# nuages en écailles (alto-cumulus de l'estampe)
	var clouds := {}
	var cm := _flat(Color("#EDE6D8"))
	for row in 5:
		for col in 18:
			var x := -150.0 + col * 17.0 + (8.5 if row % 2 == 1 else 0.0) + rng.randf_range(-2.0, 2.0)
			var r := 4.5 - row * 0.35
			_add(clouds, cm, _ball(1.0, 1.0, 8, 4), _at(Vector3(x, 34.0 + row * 5.0, -195.0 - row * 3.0), Vector3.ZERO, Vector3(r, r * 0.5, r * 0.3)))
	_flush(clouds, root)
	# coulées de lave noire veinées d'or, du fond vers l'arène et le long des côtés
	var lava := {}
	var veins := {}
	var lm := _toon(LAVA, false)
	var vm := _glow(LAVA_GOLD, 1.4)
	_lava_flow(lava, veins, lm, vm, Vector2(-22, -85), Vector2(-6, -13), 3.6, rng)
	_lava_flow(lava, veins, lm, vm, Vector2(16, -95), Vector2(5, -13), 3.2, rng)
	_lava_flow(lava, veins, lm, vm, Vector2(-11.5, -45), Vector2(-11.5, 8), 2.6, rng)
	_lava_flow(lava, veins, lm, vm, Vector2(12, -45), Vector2(11.5, 8), 2.6, rng)
	_flush(lava, root)
	_flush(veins, root)
	# piques de roche, torii qui encadre le Fuji, lanternes sur basalte
	var sp := {}
	var bn := {}
	var bm := _toon(BASALT, true, 0.03)
	for i in 16:
		var p := Vector2.ZERO
		if rng.randf() < 0.6:
			p = Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-42.0, -13.5))
			if absf(p.x) < 4.5 and p.y > -30.0 and p.y < -24.0:
				p.x += 9.0
		else:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector2(sx * rng.randf_range(13.0, 18.0), rng.randf_range(-12.0, 6.0))
		var h := rng.randf_range(3.0, 8.0)
		var base := Vector3(p.x, VOID_Y - 0.2, p.y)
		_limb(sp, bm, base, base + Vector3(rng.randf_range(-0.2, 0.2) * h, h, rng.randf_range(-0.2, 0.2) * h), rng.randf_range(0.8, 1.8), 0.05, 5)
	Decor.torii_into(sp, _at(Vector3(0, VOID_Y, -27.0), Vector3.ZERO, Vector3.ONE * 1.1), -0.6)
	for sx: float in [-1.0, 1.0]:
		_add(sp, bm, _cyl(0.5, 0.6, 0.9, 6), _at(Vector3(sx * 4.4, VOID_Y + 0.05, -26.0)))
		Decor.stone_lantern_into(sp, bn, _at(Vector3(sx * 4.4, VOID_Y + 0.5, -26.0), Vector3.ZERO, Vector3.ONE * 1.1))
	# torches géantes du Yoshida Hi-Matsuri
	var spots: Array[Vector3] = [Vector3(-10, VOID_Y, -11), Vector3(10, VOID_Y, -11), Vector3(-10, VOID_Y, -3),
		Vector3(10, VOID_Y, -3), Vector3(-10, VOID_Y, 5), Vector3(10, VOID_Y, 5), Vector3(-5.5, VOID_Y, -13.5), Vector3(5.5, VOID_Y, -13.5)]
	for p in spots:
		_yoshida_into(sp, bn, _at(p))
	_flush(sp, root, true)
	_flush(bn, root, false)


## Monde 5 : mer d'encre. Ciel de papier rose d'aube sous une bande de Prusse, chaînes d'encre
## en couches, ensō dans le ciel, pont de Mannen qui encadre le petit Fuji, banc de sable
## et croquis du Manga, grues, voiles ; grandes vagues noires, barques, pinceaux, papiers, barrique.
static func _backdrop_ink(root: Node3D) -> void:
	var rng := _rng(55)
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 26, -252), Color("#EDC2B4"), Color("#EAD2C8"))
	_vrect(st, Vector3(-340, 26, -252), Vector3(340, 150, -252), Color("#EAD2C8"), Color("#8FA3B8"))
	_ridge(st, rng, -280.0, 280.0, -210.0, -1.0, 13.0, Color("#5B6070"), Color("#E4C3B8"), 34)
	_ridge(st, rng, -260.0, 260.0, -184.0, -1.0, 6.5, Color("#2B3448"), Color("#DDBFB4"), 34)
	_enso(st, Vector3(36, 36, -196), 11.0, 1.9, Toon.SUMI)
	_sil_bridge(st, Vector3(-4.0, VOID_Y, -100.0), 66.0, 9.2, 1.3, Color("#2E2A28"), Color(0, 0, 0, 0), 6)
	_ridge(st, rng, -70.0, 70.0, -62.0, VOID_Y - 0.3, 1.0, Color("#D9CCB1"), Color("#C9BBA0"), 14)
	for k in 8:
		var x := rng.randf_range(-40.0, 40.0)
		var pose: float = -1.0 if rng.randf() < 0.5 else 1.0
		_sketch_man(st, Vector3(x, VOID_Y + 0.45, -61.6), rng.randf_range(0.9, 1.2), Color("#2A2830"), pose)
	_flock(st, rng, Vector3(20, 20, -82), 8, Vector3(12, 4, 6), 1.3, Color("#F6F2EA"))
	for k in 5:
		var z := rng.randf_range(-95.0, -40.0)
		var face: float = -1.0 if rng.randf() < 0.5 else 1.0
		_sil_boat(st, Vector3(rng.randf_range(-55.0, 55.0), VOID_Y, z), rng.randf_range(0.9, 1.4) * (1.0 - z / 260.0), Color("#1B1A1E"), Color("#F1E8D6"), face)
	_vc_end(st, root)
	# soleil pâle et bandes de nuages rose aube / washi
	_far(root, Toon.sphere(9.0), Color("#F3D3B5"), Vector3(28, 18, -230))
	for k in 6:
		var col: Color = Color(Color("#E4B7B0"), 0.7) if k % 2 == 0 else Color(Toon.WASHI, 0.8)
		_far(root, _box(Vector3(rng.randf_range(80.0, 160.0), rng.randf_range(1.2, 3.0), 0.1)), col,
			Vector3(rng.randf_range(-60.0, 60.0), 9.0 + k * 6.5, -200.0 - k * 5.0))
	# petit Fuji d'encre au creux de la vague
	_peak(root, Vector3(-4, -0.6, -140), 1.2, 16.0, 9.0, Color("#2B3448"), Toon.WASHI, 0.3, 32)
	# grandes vagues noires
	var w1: Node3D = Decor.great_wave(root, Vector3(-22, VOID_Y, -46), 2.8, 5)
	w1.rotation.y = 0.55
	_ink_wave(w1)
	var w2: Node3D = Decor.great_wave(root, Vector3(30, VOID_Y, -78), 3.8, 6)
	w2.rotation.y = -0.45
	_ink_wave(w2)
	# barques oshiokuri et leurs rameurs, pinceaux plantés comme des mâts, barrique du tonnelier
	var b := {}
	var bn := {}
	_boat_into(b, _at(Vector3(-14, VOID_Y, -28), Vector3(0, 0.3, 0), Vector3.ONE * 1.5), 4)
	_boat_into(b, _at(Vector3(8, VOID_Y, -36), Vector3(0, -0.25, 0), Vector3.ONE * 1.7), 4)
	_boat_into(b, _at(Vector3(-30, VOID_Y, -55), Vector3(0, 0.5, 0), Vector3.ONE * 2.2), 3)
	_brush_into(b, _at(Vector3(-11, VOID_Y, -15), Vector3(0, 0, 0.18), Vector3.ONE * 2.0))
	_brush_into(b, _at(Vector3(11.5, VOID_Y, -17), Vector3(0.1, 0, -0.15), Vector3.ONE * 2.3))
	_barrel_giant_into(b, bn, _at(Vector3(15.5, VOID_Y, -25.0), Vector3(0, -0.25, 0), Vector3.ONE * 1.4))
	_flush(b, root, true)
	# feuilles de papier déchiré qui flottent sur l'encre et dans l'air
	var pa := _toon(Color("#F1E8D6"), false)
	var pb := _toon(Color("#E2D6BD"), false)
	for i in 22:
		var p := Vector3.ZERO
		if rng.randf() < 0.65:
			p = Vector3(rng.randf_range(-25.0, 25.0), rng.randf_range(1.0, 14.0), rng.randf_range(-60.0, -14.0))
		else:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector3(sx * rng.randf_range(10.0, 18.0), rng.randf_range(2.0, 8.0), rng.randf_range(-10.0, 4.0))
		if rng.randf() < 0.3:
			p.y = VOID_Y + 0.02
		var rot := Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))
		if p.y < 0.0:
			rot = Vector3(0, rot.y, 0)
		var pm: StandardMaterial3D = pa if rng.randf() < 0.6 else pb
		_sheet_into(bn, pm, _at(p, rot), rng.randf_range(1.0, 2.6), rng.randf_range(1.2, 3.2))
	_flush(bn, root, false)


## Assombrit une vague de Decor.great_wave (1er enfant = la nappe à couleurs de sommets).
static func _ink_wave(w: Node3D) -> void:
	if w.get_child_count() == 0:
		return
	var sheet: MeshInstance3D = w.get_child(0) as MeshInstance3D
	if sheet == null:
		return
	sheet.material_override = _ink_wave_mat()


## Coulée de lave : ruban sinueux de dalles noires, veines d'or lumineuses dessus.
static func _lava_flow(lava: Dictionary, veins: Dictionary, lm: Material, vm: Material, src: Vector2, dst: Vector2, width: float, rng: RandomNumberGenerator) -> void:
	var n := 10
	var pts: Array[Vector2] = []
	var side := (dst - src).orthogonal().normalized()
	for i in n + 1:
		var t := float(i) / n
		var wob := sin(t * 7.0 + rng.randf() * 0.5) * 1.6 * (1.0 - t * 0.6)
		pts.append(src.lerp(dst, t) + side * wob)
	for i in n:
		var a := pts[i]
		var c := pts[i + 1]
		var d := c - a
		var l := d.length()
		var ang := atan2(d.x, d.y)
		var w := width * lerpf(1.0, 0.75, float(i) / n)
		var mid := (a + c) * 0.5
		_add(lava, lm, Toon.box(Vector3(w, 0.08, l + 0.6)), _at(Vector3(mid.x, VOID_Y + 0.03, mid.y), Vector3(0, ang, 0)))
		for k in 2:
			var off := (k - 0.5) * w * 0.45 + rng.randf_range(-0.2, 0.2)
			var vp := mid + side * off
			_add(veins, vm, Toon.box(Vector3(0.09, 0.02, l * rng.randf_range(0.6, 0.95))),
				_at(Vector3(vp.x, VOID_Y + 0.08, vp.y), Vector3(0, ang + rng.randf_range(-0.25, 0.25), 0)))

# ------------------------------------------------------------------ props autour de l'arène

## Décor de salle autour des zones jouables `rects` (Rect2 : x min, z min, largeur x, profondeur z).
## Grands props hors de l'arène, alignements et petits props au ras des bords (jamais à moins de 0.3
## d'une zone jouable, rien de haut au bas de l'écran), petits props dans les vides entre plateformes,
## tapis d'éléments répétés (MultiMesh). Tout est fusionné : ~1 draw call par matériau.
static func build_props(world_id: int, parent: Node3D, rects: Array, rng_seed: int) -> void:
	var wid := clampi(world_id, 1, 5)
	var rng := _rng(rng_seed * 31 + wid)
	var root := Node3D.new()
	root.name = "Props"
	parent.add_child(root)
	var ctx := {"lights": 0, "root": root, "rects": rects, "taken": [], "avoid": [], "bs": {}, "bn": {}, "mm": {}}
	_reserve_gate(ctx)
	# grands props dans le vide autour de l'arène
	for i in rng.randi_range(13, 17):
		var p := _spot_outer(ctx, rng)
		if p == NONE2:
			continue
		_take(ctx, p)
		_prop_big(wid, ctx, p, rng)
	# alignements de bord : clôtures, cordes sacrées, fanions…
	for i in rng.randi_range(2, 4):
		var run := _spot_run(ctx, rng)
		if run.is_empty():
			continue
		_prop_run(wid, ctx, run, rng)
	# petits props de bord, juste à côté d'une plateforme
	for i in rng.randi_range(5, 8):
		var e := _spot_edge(ctx, rng)
		if e == NONE4:
			continue
		_take(ctx, Vector2(e.x, e.y))
		_prop_edge(wid, ctx, e, rng)
	# petits props dans les vides entre plateformes
	for i in rng.randi_range(3, 7):
		var p := _spot_gap(ctx, rng)
		if p == NONE2:
			continue
		_take(ctx, p)
		_prop_small(wid, ctx, p, rng)
	# tapis d'éléments répétés
	_fill(wid, ctx, rng)
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var mm: Dictionary = ctx["mm"]
	_flush(bs, root, true)
	_flush(bn, root, false)
	_flush_mm(mm, root)


## Garde dégagé l'arrière du torii de sortie (même calcul que arena.gd).
static func _reserve_gate(ctx: Dictionary) -> void:
	var rects: Array = ctx["rects"]
	if rects.is_empty():
		return
	var high: Rect2 = rects[0]
	for r in rects:
		var rr: Rect2 = r
		if rr.position.y < high.position.y or (is_equal_approx(rr.position.y, high.position.y) and absf(rr.get_center().x) < absf(high.get_center().x)):
			high = rr
	var gx := clampf(0.0, high.position.x + 1.2, high.end.x - 1.2)
	var avoid: Array = ctx["avoid"]
	avoid.append(Vector3(gx, high.position.y, 2.3))


static func _take(ctx: Dictionary, p: Vector2) -> void:
	var taken: Array = ctx["taken"]
	taken.append(p)


## Vrai si `p` est hors de toutes les zones jouables (élargies de `margin`), loin des props déjà
## posés (`spacing`, 0 = ignoré) et hors des zones réservées.
static func _ok(ctx: Dictionary, p: Vector2, margin: float, spacing: float) -> bool:
	var rects: Array = ctx["rects"]
	for r in rects:
		var rr: Rect2 = r
		if rr.grow(margin).has_point(p):
			return false
	if spacing > 0.0:
		var taken: Array = ctx["taken"]
		for q in taken:
			var qq: Vector2 = q
			if qq.distance_to(p) < spacing:
				return false
	var avoid: Array = ctx["avoid"]
	for a in avoid:
		var av: Vector3 = a
		if Vector2(av.x, av.y).distance_to(p) < av.z:
			return false
	return true


## Emplacement d'un grand prop : sur les côtés ou au fond, jamais au bas de l'écran.
static func _spot_outer(ctx: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	for attempt in 40:
		var p := Vector2.ZERO
		if rng.randf() < 0.62:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector2(sx * rng.randf_range(5.7, 9.0), rng.randf_range(-12.5, 6.0))
		else:
			p = Vector2(rng.randf_range(-8.5, 8.5), rng.randf_range(-13.8, -10.0))
		if _ok(ctx, p, 1.1, 1.9):
			return p
	return NONE2


## Emplacement d'un petit prop dans un vide intérieur de l'arène.
static func _spot_gap(ctx: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	for attempt in 40:
		var p := Vector2(rng.randf_range(-4.2, 4.2), rng.randf_range(-8.2, 6.8))
		if _ok(ctx, p, 0.9, 1.3):
			return p
	return NONE2


## Emplacement de bord : (x, z, normale sortante x, normale sortante z), à EDGE_OFF du bord ouest,
## est ou nord d'une plateforme (jamais au sud : un prop y masquerait la plateforme vue d'en haut).
static func _spot_edge(ctx: Dictionary, rng: RandomNumberGenerator) -> Vector4:
	var rects: Array = ctx["rects"]
	if rects.is_empty():
		return NONE4
	for attempt in 30:
		var r: Rect2 = rects[rng.randi_range(0, rects.size() - 1)]
		var t := rng.randf_range(0.12, 0.88)
		var n := Vector2.ZERO
		var p := Vector2.ZERO
		var side := rng.randi_range(0, 2)
		if side == 0:
			n = Vector2(-1, 0)
			p = Vector2(r.position.x, lerpf(r.position.y, r.end.y, t))
		elif side == 1:
			n = Vector2(1, 0)
			p = Vector2(r.end.x, lerpf(r.position.y, r.end.y, t))
		else:
			n = Vector2(0, -1)
			p = Vector2(lerpf(r.position.x, r.end.x, t), r.position.y)
		p += n * EDGE_OFF
		if p.y > 6.8:
			continue
		if _ok(ctx, p, 0.5, 1.2):
			return Vector4(p.x, p.y, n.x, n.y)
	return NONE4


## Alignement le long d'un bord ouest, est ou nord : [a, b, normale sortante] (Vector2), ou [] si rien.
static func _spot_run(ctx: Dictionary, rng: RandomNumberGenerator) -> Array:
	var rects: Array = ctx["rects"]
	if rects.is_empty():
		return []
	for attempt in 20:
		var r: Rect2 = rects[rng.randi_range(0, rects.size() - 1)]
		var side := rng.randi_range(0, 2)
		var span := rng.randf_range(1.6, 3.2)
		var n := Vector2.ZERO
		var a := Vector2.ZERO
		var b := Vector2.ZERO
		if side < 2:
			var x: float = r.position.x if side == 0 else r.end.x
			n = Vector2(-1, 0) if side == 0 else Vector2(1, 0)
			var z0 := rng.randf_range(r.position.y + 0.2, maxf(r.end.y - span - 0.2, r.position.y + 0.2))
			a = Vector2(x, z0)
			b = Vector2(x, minf(z0 + span, r.end.y - 0.2))
		else:
			n = Vector2(0, -1)
			var x0 := rng.randf_range(r.position.x + 0.2, maxf(r.end.x - span - 0.2, r.position.x + 0.2))
			a = Vector2(x0, r.position.y)
			b = Vector2(minf(x0 + span, r.end.x - 0.2), r.position.y)
		a += n * 0.42
		b += n * 0.42
		if a.distance_to(b) < 1.0 or maxf(a.y, b.y) > 6.8:
			continue
		var good := true
		var steps := int(ceil(a.distance_to(b) / 0.3))
		for i in steps + 1:
			if not _ok(ctx, a.lerp(b, float(i) / steps), 0.3, 0.7):
				good = false
				break
		if good:
			return [a, b, n]
	return []


## Point au hasard dans le vide autour de l'arène (côtés, fond) ou dans ses trous.
## `reach` : distance max au-delà des bords ; `low` : autorise le bas de l'écran (éléments plats).
static func _ring_pt(ctx: Dictionary, rng: RandomNumberGenerator, margin: float, spacing: float, reach: float, low: bool) -> Vector2:
	var zmax: float = 9.6 if low else 6.5
	for attempt in 12:
		var p := Vector2.ZERO
		var u := rng.randf()
		if u < 0.55:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector2(sx * (4.7 + margin + pow(rng.randf(), 1.4) * reach), rng.randf_range(-14.0, zmax))
		elif u < 0.88:
			p = Vector2(rng.randf_range(-5.0 - reach, 5.0 + reach), -8.7 - margin - pow(rng.randf(), 1.4) * reach)
		else:
			p = Vector2(rng.randf_range(-4.4, 4.4), rng.randf_range(-8.4, minf(8.4, zmax)))
		if p.y > zmax:
			continue
		if _ok(ctx, p, margin, spacing):
			return p
	return NONE2


## Pilier qui sort du vide jusqu'au niveau du sol (support des props de bord).
static func _pillar(ctx: Dictionary, p: Vector2, r: float, color: Color) -> void:
	var bn: Dictionary = ctx["bn"]
	var h := 0.0 - (VOID_Y - 0.35)
	_add(bn, _toon(color, true, 0.02), _cyl(r * 0.9, r, h, 6), _at(Vector3(p.x, -h * 0.5, p.y)))


## Angle (rotation.y) pour que le +Z local regarde le point (tx, tz) depuis p.
static func _face(p: Vector2, tx: float, tz: float) -> float:
	return atan2(tx - p.x, tz - p.y)


static func _light_ok(ctx: Dictionary) -> bool:
	var n: int = ctx["lights"]
	return n < MAX_LIGHTS


static func _use_light(ctx: Dictionary) -> void:
	var n: int = ctx["lights"]
	ctx["lights"] = n + 1


## Lumière ponctuelle chaude (dans la limite de MAX_LIGHTS par salle, sans ombre).
static func _light(ctx: Dictionary, pos: Vector3, col: Color, energy: float, reach: float) -> void:
	if not _light_ok(ctx):
		return
	_use_light(ctx)
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	var root: Node3D = ctx["root"]
	root.add_child(l)


## Lanterne de pierre (allumée si le budget de lumières le permet et si `lit`).
static func _stone_lantern(ctx: Dictionary, pos: Vector3, s: float, lit: bool) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	Decor.stone_lantern_into(bs, bn, _at(pos, Vector3.ZERO, Vector3.ONE * s))
	if lit:
		_light(ctx, pos + Vector3(0, 0.81 * s, 0), Color(1.0, 0.72, 0.4), 0.6, 3.0 * s)


## Couleurs des fanions nobori du monde : [tissu, encre] (jamais de vermillon vif).
static func _nobori_colors(wid: int) -> Array:
	match wid:
		1:
			return [Color("#2E4A6B"), Toon.WASHI]
		2:
			return [Color("#EFE6D2"), Color("#8E3A2A")]
		3:
			return [Color("#3A3A48"), Color("#E6DCC6")]
		4:
			return [Color("#2A2226"), Toon.GOLD]
		_:
			return [Color("#F1E8D6"), Toon.SUMI]


## Croissants d'écume autour d'un rocher / d'un pieu (instances).
static func _foam_ring(ctx: Dictionary, p: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(3, 5)
	var a0 := rng.randf() * TAU
	for k in n:
		var yaw := a0 + TAU * k / n + rng.randf_range(-0.3, 0.3)
		var s := r / 0.5 * rng.randf_range(1.05, 1.3)
		_inst(ctx, "foam", _crescent_mesh(), _flat(Toon.FOAM), _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, yaw, 0), Vector3(s, 1, s)))


static func _prop_big(wid: int, ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	match wid:
		1:
			_big_wave(ctx, p, rng)
		2:
			_big_tanabata(ctx, p, rng)
		3:
			_big_contes(ctx, p, rng)
		4:
			_big_fuji(ctx, p, rng)
		_:
			_big_ink(ctx, p, rng)


static func _fill(wid: int, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	match wid:
		1:
			_fill_wave(ctx, rng)
		2:
			_fill_tanabata(ctx, rng)
		3:
			_fill_contes(ctx, rng)
		4:
			_fill_fuji(ctx, rng)
		_:
			_fill_ink(ctx, rng)


# --- alignements de bord

static func _prop_run(wid: int, ctx: Dictionary, run: Array, rng: RandomNumberGenerator) -> void:
	var a2: Vector2 = run[0]
	var b2: Vector2 = run[1]
	var n2: Vector2 = run[2]
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var a := Vector3(a2.x, 0.0, a2.y)
	var c := Vector3(b2.x, 0.0, b2.y)
	var roll := rng.randf()
	var kind := "fence"
	if wid == 1:
		if roll < 0.45:
			kind = "rope"
		elif roll < 0.75:
			kind = "nobori"
		else:
			kind = "shime"
	elif wid == 2:
		if roll < 0.55:
			kind = "fence"
		elif roll < 0.8:
			kind = "shime"
		else:
			kind = "nobori"
	elif wid == 3:
		if roll < 0.45:
			kind = "fence"
		elif roll < 0.75:
			kind = "shime"
		else:
			kind = "jizo"
	elif wid == 4:
		if roll < 0.5:
			kind = "chain"
		elif roll < 0.75:
			kind = "shime"
		else:
			kind = "nobori"
	else:
		if roll < 0.4:
			kind = "shime"
		elif roll < 0.7:
			kind = "fence"
		else:
			kind = "nobori"
	if kind == "fence":
		Decor.fence_into(bs, bn, a, c, 0.62, VOID_Y - 0.3, wid == 3)
	elif kind == "rope":
		_rope_rail(ctx, a, c)
	elif kind == "nobori":
		_nobori_line(ctx, a, c, n2, wid)
	elif kind == "shime":
		_shime_run(ctx, a, c)
	elif kind == "chain":
		_chain_rail(ctx, a, c)
	else:
		_jizo_ledge(ctx, a, c, n2)
	var steps := maxi(int(a2.distance_to(b2) / 0.7), 1)
	for i in steps + 1:
		_take(ctx, a2.lerp(b2, float(i) / steps))


## Garde-corps de port : pieux et gros cordage qui pend entre eux.
static func _rope_rail(ctx: Dictionary, a: Vector3, c: Vector3) -> void:
	var bs: Dictionary = ctx["bs"]
	var pile := _toon(Decor.PILE, true, 0.02)
	var rope := _toon(Color("#B9A57E"), true, 0.012)
	var n := maxi(int(ceil(a.distance_to(c) / 1.1)), 1)
	var hh := 0.75 - (VOID_Y - 0.3)
	var prev := Vector3.ZERO
	for i in n + 1:
		var q := a.lerp(c, float(i) / n)
		_add(bs, pile, _cyl(0.06, 0.07, hh, 6), _at(Vector3(q.x, VOID_Y - 0.3 + hh * 0.5, q.z)))
		_add(bs, pile, _ball(0.07, 0.08, 6, 3), _at(Vector3(q.x, 0.77, q.z)))
		var top := Vector3(q.x, 0.62, q.z)
		if i > 0:
			_rope(bs, rope, prev, top, 0.16, 0.022)
		prev = top


## Rangée de fanions nobori, bannières tournées vers l'extérieur.
static func _nobori_line(ctx: Dictionary, a: Vector3, c: Vector3, n2: Vector2, wid: int) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var cols := _nobori_colors(wid)
	var cloth: Color = cols[0]
	var ink: Color = cols[1]
	var n := clampi(int(a.distance_to(c) / 1.1) + 1, 2, 4)
	var rot: float = PI if n2.x < -0.5 else 0.0
	for i in n:
		var q := a.lerp(c, float(i) / (n - 1))
		Decor.nobori_into(bs, bn, _at(q, Vector3(0, rot, 0)), cloth, ink, VOID_Y - 0.3)


## Shimenawa tendue entre deux poteaux de bois sombre.
static func _shime_run(ctx: Dictionary, a: Vector3, c: Vector3) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var post := _toon(Color("#3B2E25"), true, 0.02)
	var hh := 1.15 - (VOID_Y - 0.3)
	for q: Vector3 in [a, c]:
		_add(bs, post, _cyl(0.055, 0.065, hh, 6), _at(Vector3(q.x, VOID_Y - 0.3 + hh * 0.5, q.z)))
		_add(bs, post, _box(Vector3(0.16, 0.05, 0.16)), _at(Vector3(q.x, 1.17, q.z)))
	Decor.shimenawa_into(bs, bn, a + Vector3(0, 1.0, 0), c + Vector3(0, 1.0, 0))


## Rambarde de chaîne entre des poteaux de fer.
static func _chain_rail(ctx: Dictionary, a: Vector3, c: Vector3) -> void:
	var bs: Dictionary = ctx["bs"]
	var iron := _toon(IRON, true, 0.02)
	var n := maxi(int(ceil(a.distance_to(c) / 1.2)), 1)
	var hh := 0.85 - (VOID_Y - 0.3)
	var prev := Vector3.ZERO
	for i in n + 1:
		var q := a.lerp(c, float(i) / n)
		_add(bs, iron, _cyl(0.07, 0.09, hh, 6), _at(Vector3(q.x, VOID_Y - 0.3 + hh * 0.5, q.z)))
		_add(bs, iron, _cyl(0.11, 0.11, 0.06, 6), _at(Vector3(q.x, 0.87, q.z)))
		var top := Vector3(q.x, 0.72, q.z)
		if i > 0:
			_links(bs, iron, prev, top, 0.2)
		prev = top


## Rebord de pierre enneigé et rangée de jizō tournés vers l'arène.
static func _jizo_ledge(ctx: Dictionary, a: Vector3, c: Vector3, n2: Vector2) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var stone := _toon(Color("#6E6C72"), true, 0.02)
	var off := Vector3(n2.x, 0, n2.y) * 0.13
	var a2 := a + off
	var c2 := c + off
	var mid := (a2 + c2) * 0.5
	var l := a2.distance_to(c2)
	var yaw := atan2(c2.x - a2.x, c2.z - a2.z)
	var hh := 0.05 - (VOID_Y - 0.3)
	_add(bs, stone, _box(Vector3(0.5, hh, l + 0.4)), _at(Vector3(mid.x, 0.05 - hh * 0.5, mid.z), Vector3(0, yaw, 0)))
	_add(bn, _toon(SNOW, false), _box(Vector3(0.52, 0.05, l + 0.42)), _at(Vector3(mid.x, 0.06, mid.z), Vector3(0, yaw, 0)))
	var face := atan2(-n2.x, -n2.y)
	var n := maxi(int(l / 0.55), 1)
	for i in n + 1:
		var q := a2.lerp(c2, float(i) / n)
		_jizo_into(bs, _at(Vector3(q.x, 0.075, q.z), Vector3(0, face, 0), Vector3.ONE * 0.75))

# --- petits props de bord

static func _prop_edge(wid: int, ctx: Dictionary, e: Vector4, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var p := Vector2(e.x, e.y)
	var out := Vector2(e.z, e.w)
	var pos := Vector3(p.x, 0.0, p.y)
	# regarde vers la plateforme / bras de potence et bannière vers l'extérieur
	var to_arena := _face(p, p.x - out.x, p.y - out.y)
	var arm_out := atan2(-out.y, out.x)
	var flag_rot: float = PI if out.x < -0.5 else 0.0
	var cols := _nobori_colors(wid)
	var cloth: Color = cols[0]
	var ink: Color = cols[1]
	var roll := rng.randf()
	match wid:
		1:
			if roll < 0.2:
				Decor.paper_lantern_into(bs, bn, _at(pos, Vector3(0, arm_out, 0)), Toon.WASHI, VOID_Y - 0.35)
			elif roll < 0.34 and _light_ok(ctx):
				_pillar(ctx, p, 0.22, STONE_DARK)
				_stone_lantern(ctx, pos, 0.62, true)
			elif roll < 0.5:
				_pillar(ctx, p, 0.22, Decor.PILE)
				Decor.sake_barrel_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.62))
				if rng.randf() < 0.5:
					Decor.sake_barrel_into(bn, bn, _at(pos + Vector3(0, 0.35, 0), Vector3(0, to_arena + 0.4, 0), Vector3.ONE * 0.5))
			elif roll < 0.64:
				var top := _bitt_into(bs, bn, Vector3(p.x, VOID_Y - 0.3, p.y), 1.75)
				if rng.randf() < 0.6:
					Decor.gull_into(bn, _at(top, Vector3(0, rng.randf() * TAU, 0)))
			elif roll < 0.76:
				_pillar(ctx, p, 0.22, Decor.PILE)
				for k in 3:
					Decor.glass_float_into(bn, _at(pos + Vector3(rng.randf_range(-0.08, 0.08), k * 0.12, rng.randf_range(-0.08, 0.08)), Vector3.ZERO, Vector3.ONE * 0.6), k)
			elif roll < 0.88:
				Decor.nobori_into(bs, bn, _at(pos, Vector3(0, flag_rot, 0)), cloth, ink, VOID_Y - 0.35)
			else:
				_pillar(ctx, p, 0.22, Decor.PILE)
				Decor.hokora_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.72), Color("#B98E52"), Color("#3A3530"))
		2:
			if roll < 0.22:
				_pillar(ctx, p, 0.22, STONE_DARK)
				_tanzaku_into(bn, _at(pos, Vector3.ZERO, Vector3.ONE * 0.8), rng)
			elif roll < 0.42:
				_pillar(ctx, p, 0.22, STONE_DARK)
				_kitsune_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.62))
			elif roll < 0.56 and _light_ok(ctx):
				_pillar(ctx, p, 0.22, STONE_DARK)
				_stone_lantern(ctx, pos, 0.6, true)
			elif roll < 0.72:
				Decor.paper_lantern_into(bs, bn, _at(pos, Vector3(0, arm_out, 0)), Color("#F1E3A6"), VOID_Y - 0.35)
			elif roll < 0.86:
				Decor.nobori_into(bs, bn, _at(pos, Vector3(0, flag_rot, 0)), cloth, ink, VOID_Y - 0.35)
			else:
				_pillar(ctx, p, 0.22, STONE_DARK)
				Decor.hokora_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.72), Color("#7A5A3E"), Color("#2E2C33"))
		3:
			if roll < 0.2:
				Decor.paper_lantern_into(bs, bn, _at(pos, Vector3(0, arm_out, 0)), Toon.WASHI, VOID_Y - 0.35)
				return
			if roll > 0.9:
				# lanternes flottantes au pied du bord, sur l'eau
				for k in 2:
					_toro_into(bn, _at(Vector3(p.x + out.x * 0.15 * k, VOID_Y, p.y + out.y * 0.15 * k - 0.2 * k), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.8))
				return
			_pillar(ctx, p, 0.22, Color("#6E6C72"))
			_add(bn, _toon(SNOW, false), _cyl(0.2, 0.235, 0.05, 8), _at(Vector3(p.x, -0.01, p.y)))
			if roll < 0.38:
				_jizo_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.82))
			elif roll < 0.52:
				_stele_into(bs, _toon(GRAVE, true, 0.02), _toon(SNOW, false), _at(pos, Vector3(0, to_arena, 0.05), Vector3.ONE * 0.62))
			elif roll < 0.64:
				_offering_into(bs, bn, _at(pos, Vector3(0, to_arena, 0)))
			elif roll < 0.76:
				_wagasa_into(bs, _at(pos, Vector3(0, to_arena, 0)), false, BONNET)
			elif _light_ok(ctx):
				_stone_lantern(ctx, pos, 0.6, true)
			else:
				_jizo_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.82))
		4:
			if roll > 0.9:
				Decor.nobori_into(bs, bn, _at(pos, Vector3(0, flag_rot, 0)), cloth, ink, VOID_Y - 0.35)
				return
			_pillar(ctx, p, 0.22, BASALT)
			if roll < 0.28 and _light_ok(ctx):
				_brazier_into(bs, bn, _at(pos, Vector3.ZERO, Vector3.ONE * 0.6))
				_light(ctx, pos + Vector3(0, 0.8, 0), Color(1.0, 0.55, 0.25), 0.55, 3.5)
			elif roll < 0.46:
				_oni_mask_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.7))
			elif roll < 0.58:
				_brazier_into(bs, bn, _at(pos, Vector3.ZERO, Vector3.ONE * 0.55))
			elif roll < 0.7:
				for k in 2:
					Decor.katana_into(bs, _at(pos + Vector3((k - 0.5) * 0.14, 0, 0), Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)), Vector3.ONE * 0.85))
			elif roll < 0.8:
				_ingots_into(bs, bn, _at(pos, Vector3(0, rng.randf() * TAU, 0)))
			else:
				_yoshida_into(bs, bn, _at(pos, Vector3.ZERO, Vector3.ONE * 0.3))
		_:
			if roll < 0.25:
				_brush_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(out.y * 0.15, 0, -out.x * 0.15), Vector3.ONE * 0.45))
			elif roll < 0.45:
				_papers_into(bn, p, rng, 2, VOID_Y + 0.02, 0.2)
			elif roll < 0.6:
				_pillar(ctx, p, 0.22, Color("#3A3530"))
				_seal_into(bs, _at(pos, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.42))
			elif roll < 0.74:
				_pillar(ctx, p, 0.22, Color("#3A3530"))
				Decor.kadomatsu_into(bs, bn, _at(pos, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.62))
			elif roll < 0.88:
				Decor.nobori_into(bs, bn, _at(pos, Vector3(0, flag_rot, 0)), cloth, ink, VOID_Y - 0.35)
			else:
				_pillar(ctx, p, 0.22, Color("#3A3530"))
				_kagami_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.8))


# --- petits props dans les vides entre plateformes (bas)

static func _prop_small(wid: int, ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var sd := rng.randi() % 100000
	var roll := rng.randf()
	match wid:
		1:
			if roll < 0.5:
				var s := rng.randf_range(0.45, 0.75)
				Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), sd)
				_foam_ring(ctx, p, s * 0.7, rng)
				if rng.randf() < 0.35:
					Decor.gull_into(bn, _at(Vector3(p.x, VOID_Y + 0.33 * s, p.y), Vector3(0, rng.randf() * TAU, 0)))
			elif roll < 0.75:
				for k in rng.randi_range(2, 3):
					Decor.glass_float_into(bn, _at(Vector3(p.x + rng.randf_range(-0.4, 0.4), VOID_Y - 0.06, p.y + rng.randf_range(-0.4, 0.4))), k)
				_foam_ring(ctx, p, 0.4, rng)
			else:
				var top := _bitt_into(bs, bn, Vector3(p.x, VOID_Y - 0.3, p.y), 1.1)
				Decor.gull_into(bn, _at(top, Vector3(0, rng.randf() * TAU, 0)))
				_foam_ring(ctx, p, 0.3, rng)
		2:
			if roll < 0.7:
				Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * rng.randf_range(0.6, 0.8)), sd)
				var top := Vector3(p.x, VOID_Y + 0.22, p.y)
				if rng.randf() < 0.5:
					_tanzaku_into(bn, _at(top, Vector3.ZERO, Vector3.ONE * 0.75), rng)
				else:
					_kitsune_into(bs, _at(top, Vector3(0, _face(p, 0.0, p.y + 3.0), 0), Vector3.ONE * 0.6))
			else:
				var stone := _toon(STONE, true, 0.02)
				for k in 4:
					_add(bs, stone, _cyl(0.3, 0.34, 0.14, 7), _at(Vector3(p.x + (k - 1.5) * 0.45, VOID_Y + 0.03, p.y + rng.randf_range(-0.2, 0.2)), Vector3(0, rng.randf() * TAU, 0)))
				_stone_lantern(ctx, Vector3(p.x, VOID_Y + 0.1, p.y - 0.5), 0.45, false)
		3:
			if roll < 0.35:
				var top := _mound_into(bn, bn, p, rng.randf_range(0.45, 0.7), rng)
				if rng.randf() < 0.5:
					_wagasa_into(bn, _at(Vector3(p.x, top, p.y), Vector3(0, rng.randf() * TAU, 0)), true, Color("#5B6C8F"))
			elif roll < 0.7:
				for k in rng.randi_range(2, 3):
					_toro_into(bn, _at(Vector3(p.x + rng.randf_range(-0.5, 0.5), VOID_Y, p.y + rng.randf_range(-0.5, 0.5)), Vector3(0, rng.randf() * TAU, 0)))
			else:
				var top := _mound_into(bn, bn, p, 0.6, rng)
				_stele_into(bn, _toon(GRAVE, true, 0.02), _toon(SNOW, false), _at(Vector3(p.x, top - 0.04, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.7))
		4:
			if roll < 0.45:
				_spikes_into(bs, bn, p, 0.55, rng)
			elif roll < 0.75:
				_basalt_into(bs, p, 0.3, VOID_Y + 0.3, rng)
				_anvil_into(bs, bn, _at(Vector3(p.x, VOID_Y + 0.3, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.6))
			else:
				_basalt_into(bs, p, 0.3, VOID_Y + 0.25, rng)
				for k in 2:
					Decor.katana_into(bs, _at(Vector3(p.x + (k - 0.5) * 0.2, VOID_Y + 0.25, p.y), Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25)), Vector3.ONE * 0.8))
		_:
			if roll < 0.4:
				_papers_into(bn, p, rng, rng.randi_range(2, 3), VOID_Y + 0.02, 0.5)
			elif roll < 0.6:
				_seal_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.6))
			elif roll < 0.8:
				_brush_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)), Vector3.ONE * 0.5))
			else:
				_ink_claw_into(bs, bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, _face(p, 0.0, p.y), 0), Vector3.ONE * 0.45), rng)


# --- monde 1 : port de Kanagawa

static func _big_wave(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var sd := rng.randi() % 100000
	var roll := rng.randf()
	if roll < 0.22:
		# rocher et son écume, couronné d'un cerisier, d'un pin, d'une lanterne ou de mouettes
		var s := rng.randf_range(1.3, 2.0)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), sd)
		_foam_ring(ctx, p, s * 0.72, rng)
		var at := Vector3(p.x, VOID_Y + 0.33 * s, p.y)
		var r2 := rng.randf()
		if r2 < 0.3:
			Decor.sakura_into(bs, bn, _at(at, Vector3.ZERO, Vector3.ONE * rng.randf_range(0.9, 1.3)), sd)
		elif r2 < 0.55:
			Decor.pine_into(bs, _at(at, Vector3.ZERO, Vector3.ONE * rng.randf_range(0.9, 1.2)), sd)
		elif r2 < 0.7 and _light_ok(ctx):
			_stone_lantern(ctx, at, 0.8, true)
		else:
			for k in rng.randi_range(1, 2):
				Decor.gull_into(bn, _at(at + Vector3(rng.randf_range(-0.3, 0.3), -0.05, rng.randf_range(-0.3, 0.3)), Vector3(0, rng.randf() * TAU, 0)))
	elif roll < 0.4:
		_moored_boat(ctx, p, rng)
	elif roll < 0.55:
		_side_pier(ctx, p, rng)
	elif roll < 0.66:
		var s := rng.randf_range(0.85, 1.1)
		var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf_range(-0.3, 0.3), 0), Vector3.ONE * s)
		_port_lantern_into(bs, bn, xf)
		_light(ctx, xf * Vector3(0, 2.46, 0), Color(1.0, 0.78, 0.5), 0.7, 3.5)
		_foam_ring(ctx, p, 0.75 * s, rng)
		if rng.randf() < 0.4:
			Decor.gull_into(bn, xf * _at(Vector3(0.38, 0.8, 0.38), Vector3(0, rng.randf() * TAU, 0)))
	elif roll < 0.77:
		_floating_shrine(ctx, p, rng)
	elif roll < 0.89:
		_piles(ctx, p, rng)
	else:
		Decor.net_rack_into(bs, bn, _at(Vector3(p.x, 0.0, p.y), Vector3(0, rng.randf_range(-0.3, 0.3), 0)), VOID_Y - 0.3)
		for k in rng.randi_range(2, 4):
			Decor.glass_float_into(bn, _at(Vector3(p.x + rng.randf_range(-1.0, 1.0), VOID_Y - 0.06, p.y + rng.randf_range(0.4, 0.9))), k)


## Barque oshiokuri amarrée à un pieu, cargaison, mouette sur la proue.
static func _moored_boat(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var rot: float = PI * 0.5 if absf(p.x) > 5.0 else 0.0
	rot += rng.randf_range(-0.25, 0.25)
	if rng.randf() < 0.5:
		rot += PI
	var s := rng.randf_range(0.65, 0.8)
	var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rot, 0), Vector3.ONE * s)
	_boat_into(bs, xf, rng.randi_range(0, 1))
	Decor.sake_barrel_into(bn, bn, xf * _at(Vector3(0.1, 0.24, 0), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.75))
	_add(bn, _toon(Color("#4A4438"), false), _ball(0.32, 0.22, 8, 3), xf * _at(Vector3(0.9, 0.3, 0)))
	var post := xf * Vector3(-2.0, 0.0, 0.7)
	var top := _bitt_into(bs, bn, Vector3(post.x, VOID_Y - 0.3, post.z), 1.5)
	_rope(bn, _toon(Decor.KOMO, false), xf * Vector3(-1.6, 0.3, 0.15), top - Vector3(0, 0.3, 0), 0.25, 0.018)
	if rng.randf() < 0.6:
		Decor.gull_into(bn, xf * _at(Vector3(2.2, 0.56, 0), Vector3(0, PI * 0.5, 0)))


## Ponton secondaire : tonneaux de saké, flotteurs de verre ou lanterne, mouette.
static func _side_pier(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var rot: float = 0.0 if absf(p.x) > 5.0 else PI * 0.5
	rot += rng.randf_range(-0.08, 0.08)
	var l := rng.randf_range(2.2, 3.0)
	var xf := _at(Vector3(p.x, 0.0, p.y), Vector3(0, rot, 0))
	Decor.pier_into(bs, xf, 1.3, l, -0.08, VOID_Y - 0.3)
	var labels: Array[Color] = [Color("#2E3446"), Toon.PRUSSIAN, Color("#5B4630")]
	for k in rng.randi_range(2, 4):
		var q := Vector3(rng.randf_range(-0.35, 0.35), -0.08, -l * 0.35 + k * 0.42)
		Decor.sake_barrel_into(bs, bn, xf * _at(q, Vector3(0, rng.randf_range(-0.5, 0.5), 0), Vector3.ONE * 0.8), labels[k % labels.size()])
	if rng.randf() < 0.5:
		for k in 3:
			Decor.glass_float_into(bn, xf * _at(Vector3(rng.randf_range(-0.4, 0.4), -0.08, l * 0.3 + rng.randf_range(-0.2, 0.2))), k)
	else:
		var arm: float = PI if p.x < 0.0 else 0.0
		Decor.paper_lantern_into(bs, bn, xf * _at(Vector3(0.55, -0.08, l * 0.42), Vector3(0, arm, 0)), Toon.WASHI)
	if rng.randf() < 0.4:
		Decor.gull_into(bn, xf * _at(Vector3(-0.68, 0.15, -l * 0.45), Vector3(0, rng.randf() * TAU, 0)))


## Petit sanctuaire flottant : radeau, hokora, torii dans l'eau, deux lanternes.
static func _floating_shrine(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, _face(p, 0.0, p.y), 0))
	_add(bs, _toon(Decor.PLANK, true, 0.02), _box(Vector3(1.1, 0.14, 0.9)), xf * _at(Vector3(0, 0.05, -0.2)))
	Decor.hokora_into(bs, bn, xf * _at(Vector3(0, 0.12, -0.3), Vector3.ZERO, Vector3.ONE * 0.85), Color("#B98E52"), Color("#3A3530"))
	Decor.torii_into(bs, xf * _at(Vector3(0, 0, 0.75), Vector3.ZERO, Vector3.ONE * 0.24), -0.4)
	for sx: float in [-1.0, 1.0]:
		_toro_into(bn, xf * _at(Vector3(sx * 0.42, 0.12, 0.1), Vector3.ZERO, Vector3.ONE * 0.7))
	_foam_ring(ctx, p, 0.8, rng)


## Pieux d'amarrage en ligne, reliés par une corde, mouettes perchées.
static func _piles(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var rope := _toon(Decor.KOMO, false)
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var n := rng.randi_range(3, 5)
	var tops: Array[Vector3] = []
	for k in n:
		var q := p + dir * (float(k) - (n - 1) * 0.5) * 0.8
		if not _ok(ctx, q, 0.5, 0.0):
			continue
		var top := _bitt_into(bs, bn, Vector3(q.x, VOID_Y - 0.3, q.y), rng.randf_range(1.2, 1.8))
		tops.append(top - Vector3(0, 0.2, 0))
		if rng.randf() < 0.35:
			Decor.gull_into(bn, _at(top, Vector3(0, rng.randf() * TAU, 0)))
		_foam_ring(ctx, q, 0.22, rng)
	for k in tops.size() - 1:
		_rope(bn, rope, tops[k], tops[k + 1], 0.18, 0.018)


static func _fill_wave(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var fm := _flat(Toon.FOAM)
	var cm := _crescent_mesh()
	for i in 46:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.6, 1.5)
		_inst(ctx, "foam", cm, fm, _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, 1, s)))
	for i in rng.randi_range(4, 7):
		var p := _ring_pt(ctx, rng, 0.4, 0.8, 4.0, true)
		if p == NONE2:
			continue
		Decor.glass_float_into(bn, _at(Vector3(p.x, VOID_Y - 0.06, p.y), Vector3(0, rng.randf() * TAU, 0)), rng.randi_range(0, 2))
	for i in rng.randi_range(3, 5):
		var p := _ring_pt(ctx, rng, 0.6, 1.2, 4.5, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.4, 0.7)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), rng.randi() % 100000)
		_foam_ring(ctx, p, s * 0.7, rng)


# --- monde 2 : bambouseraie de Tanabata

static func _big_tanabata(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var sd := rng.randi() % 100000
	var roll := rng.randf()
	if roll < 0.2:
		var s := rng.randf_range(1.2, 1.6)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), sd)
		var at := Vector3(p.x, VOID_Y + 0.33 * s, p.y)
		Decor.bamboo_into(bs, bn, _at(at, Vector3.ZERO, Vector3.ONE * rng.randf_range(1.0, 1.3)), sd)
		if rng.randf() < 0.6:
			_tanzaku_into(bn, _at(at + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))), rng)
	elif roll < 0.34:
		_fox_shrine(ctx, p, rng)
	elif roll < 0.48:
		_torii_alley(ctx, p, rng)
	elif roll < 0.6:
		var s := rng.randf_range(1.1, 1.4)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), sd)
		_stone_lantern(ctx, Vector3(p.x, VOID_Y + 0.33 * s, p.y), 0.85, true)
	elif roll < 0.72 and absf(p.x) > 5.5 and _ok(ctx, p + Vector2(0, 2.0), 1.0, 0.0) and _ok(ctx, p - Vector2(0, 2.0), 1.0, 0.0):
		_vermilion_bridge(ctx, p, rng)
	elif roll < 0.86:
		_sasa(ctx, p, rng)
	else:
		_moss_shrine(ctx, p, rng)


## Deux renards de pierre gardant un hokora, sur un socle qui sort de l'eau.
static func _fox_shrine(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var xf := _at(Vector3(p.x, 0.0, p.y), Vector3(0, _face(p, 0.0, p.y), 0))
	_add(bs, _toon(STONE_DARK, true, 0.025), _box(Vector3(1.7, 0.9, 1.1)), xf * _at(Vector3(0, -0.3, 0)))
	_add(bs, _toon(STONE, true, 0.025), _box(Vector3(1.5, 0.08, 0.9)), xf * _at(Vector3(0, 0.19, 0)))
	Decor.hokora_into(bs, bn, xf * _at(Vector3(0, 0.23, -0.18), Vector3.ZERO, Vector3.ONE * 0.9), Color("#7A5A3E"), Color("#2E2C33"))
	for sx: float in [-1.0, 1.0]:
		_kitsune_into(bs, xf * _at(Vector3(sx * 0.58, 0.23, 0.15), Vector3(0, -sx * 0.35, 0), Vector3.ONE * 0.72))
	if rng.randf() < 0.5:
		var cols := _nobori_colors(2)
		var cloth: Color = cols[0]
		var ink: Color = cols[1]
		for sx: float in [-1.0, 1.0]:
			var rot: float = PI if sx < 0.0 else 0.0
			Decor.nobori_into(bs, bn, xf * _at(Vector3(sx * 0.95, 0.0, 0.45), Vector3(0, rot, 0)), cloth, ink, VOID_Y - 0.3)


## Allée de petits torii (Fushimi Inari) qui s'enfonce le long de l'arène.
static func _torii_alley(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var side := absf(p.x) > 5.0
	var dir: Vector2 = Vector2(0, -1) if side else Vector2(1, 0)
	var yaw: float = 0.0 if side else PI * 0.5
	var n := rng.randi_range(3, 5)
	var s := 0.27
	for k in n:
		var q := p + dir * (float(k) - (n - 1) * 0.5) * 0.7
		if not _ok(ctx, q, 1.3, 0.0):
			continue
		Decor.torii_into(bs, _at(Vector3(q.x, VOID_Y, q.y), Vector3(0, yaw, 0), Vector3.ONE * s), -0.6 / s)
	var q0 := p - dir * ((n - 1) * 0.5 * 0.7 + 0.7)
	if _ok(ctx, q0, 0.6, 0.0):
		Decor.rock_into(bs, _at(Vector3(q0.x, VOID_Y, q0.y), Vector3.ZERO, Vector3.ONE * 0.9), rng.randi() % 100000)
		_stone_lantern(ctx, Vector3(q0.x, VOID_Y + 0.3, q0.y), 0.6, false)


## Pont arqué vermillon le long de l'arène, rochers et lanternes à ses pieds.
static func _vermilion_bridge(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var xf := _at(Vector3(p.x, VOID_Y + 0.25, p.y), Vector3(0, PI * 0.5, 0))
	Decor.arched_bridge_into(bs, xf, 3.4, 0.9, Toon.VERMILION.darkened(0.08), Color("#3B2E25"), -0.6)
	for sx: float in [-1.0, 1.0]:
		var e := xf * Vector3(sx * 1.95, -0.25, 0)
		Decor.rock_into(bs, _at(Vector3(e.x, VOID_Y, e.z), Vector3.ZERO, Vector3.ONE * 0.8), rng.randi() % 100000)
		_stone_lantern(ctx, Vector3(e.x, VOID_Y + 0.26, e.z), 0.5, false)


## Grand bambou de Tanabata : tanzaku, banderoles fukinagashi et kusudama.
static func _sasa(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var s := rng.randf_range(1.2, 1.5)
	Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), rng.randi() % 100000)
	var at := Vector3(p.x, VOID_Y + 0.3 * s, p.y)
	_tanzaku_into(bs, _at(at, Vector3.ZERO, Vector3.ONE * 1.6), rng)
	var top := at + Vector3(0, 2.6, 0)
	for k in 4:
		var a := TAU * k / 4.0 + rng.randf() * 0.5
		var q := top + Vector3(cos(a) * 0.45, -0.3 - k * 0.1, sin(a) * 0.45)
		var col: Color = TANZAKU[rng.randi_range(0, TANZAKU.size() - 1)]
		_add(bn, _toon(col, false), _ball(0.09, 0.16, 7, 3), _at(q))
		for j in 5:
			var c2: Color = TANZAKU[(k + j) % TANZAKU.size()]
			var aj := TAU * j / 5.0
			_add(bn, _toon(c2, false), _box(Vector3(0.035, 0.85, 0.006)), _at(q + Vector3(cos(aj) * 0.06, -0.5, sin(aj) * 0.06), Vector3(0, aj, 0)))


## Îlot de mousse avec hokora, renard et petite lanterne.
static func _moss_shrine(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var r := rng.randf_range(1.0, 1.3)
	_inst(ctx, "moss", _ball(1.0, 0.5, 10, 4), _toon(Color("#3E5A3A"), true, 0.02), _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(r, r * 0.8, r)))
	var top := VOID_Y + 0.2 * r - 0.03
	var face := _face(p, 0.0, p.y)
	var fwd := Vector3(sin(face), 0, cos(face))
	Decor.hokora_into(bs, bn, _at(Vector3(p.x, top, p.y) - fwd * 0.2, Vector3(0, face, 0), Vector3.ONE * 0.8), Color("#7A5A3E"), Color("#2E2C33"))
	_kitsune_into(bs, _at(Vector3(p.x, top, p.y) + fwd * 0.45 + Vector3(fwd.z, 0, -fwd.x) * 0.35, Vector3(0, face, 0), Vector3.ONE * 0.55))
	_stone_lantern(ctx, Vector3(p.x, top, p.y) + fwd * 0.45 - Vector3(fwd.z, 0, -fwd.x) * 0.4, 0.45, false)


## Bambouseraie dense (instances) sur des îlots de mousse, roseaux et pas japonais.
static func _fill_tanabata(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var stem_a := _toon(Decor.BAMBOO, true, 0.018)
	var stem_b := _toon(Color("#6F8F4C"), true, 0.018)
	var node_m := _toon(Decor.BAMBOO_NODE, false)
	var leaf := _toon_ds(Decor.BAMBOO_LEAF)
	var moss := _toon(Color("#3E5A3A"), true, 0.02)
	var stem_mesh := _cyl(0.05, 0.06, 1.0, 6)
	var node_mesh := _cyl(0.068, 0.068, 0.035, 6)
	var spray := _spray_mesh()
	var clumps := 0
	for i in 40:
		if clumps >= 16:
			break
		var c := _ring_pt(ctx, rng, 0.9, 1.3, 6.5, false)
		if c == NONE2:
			continue
		clumps += 1
		var mr := rng.randf_range(0.7, 1.2)
		_inst(ctx, "moss", _ball(1.0, 0.5, 10, 4), moss, _at(Vector3(c.x, VOID_Y, c.y), Vector3(0, rng.randf() * TAU, 0), Vector3(mr, mr * 0.8, mr)))
		for k in rng.randi_range(3, 7):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * mr * 0.7
			var base := Vector3(c.x + cos(a) * d, VOID_Y + 0.1, c.y + sin(a) * d)
			if not _ok(ctx, Vector2(base.x, base.z), 0.45, 0.0):
				continue
			var h := rng.randf_range(3.2, 6.5)
			var bas := Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06)))
			var sxf := Transform3D(bas * Basis.from_scale(Vector3(1, h, 1)), base + bas * Vector3(0, h * 0.5, 0))
			if rng.randf() < 0.6:
				_inst(ctx, "stem_a", stem_mesh, stem_a, sxf)
			else:
				_inst(ctx, "stem_b", stem_mesh, stem_b, sxf)
			var seg := rng.randf_range(0.5, 0.65)
			var t := seg
			while t < h - 0.2:
				_inst(ctx, "node", node_mesh, node_m, Transform3D(bas, base + bas * Vector3(0, t, 0)))
				t += seg
			var ss := rng.randf_range(0.9, 1.4)
			_inst(ctx, "spray", spray, leaf, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * ss), base + bas * Vector3(0, h, 0)))
			if h > 4.2:
				_inst(ctx, "spray", spray, leaf, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * ss * 0.7), base + bas * Vector3(0, h * 0.72, 0)))
	var reed := _toon_ds(Color("#4F6E3E"))
	for i in 34:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 3.0, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.8, 1.6)
		_inst(ctx, "reed", _tuft_mesh(), reed, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * rng.randf_range(0.9, 1.4), s)))
	var stone := _toon(STONE, true, 0.02)
	for i in 14:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 2.5, true)
		if p == NONE2:
			continue
		_inst(ctx, "step", _cyl(0.3, 0.34, 0.14, 7), stone, _at(Vector3(p.x, VOID_Y + 0.03, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.7, 1.2)))

# --- monde 3 : temple sous la neige

static func _big_contes(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var roll := rng.randf()
	var face := _face(p, 0.0, p.y)
	if roll < 0.12 and _ok(ctx, p, 1.6, 0.0):
		# beffroi et sa cloche bonshō
		var top := _mound_into(bs, bn, p, 1.5, rng)
		Decor.bell_tower_into(bs, bn, _at(Vector3(p.x, top - 0.1, p.y), Vector3(0, face, 0), Vector3.ONE * 0.62), true)
		return
	if roll < 0.22:
		# torii enneigé (de profil sur les côtés pour ne pas déborder sur l'arène)
		var top := _mound_into(bs, bn, p, 1.3, rng)
		var yaw: float = PI * 0.5 if absf(p.x) > 5.0 else 0.0
		_snow_torii(bs, bn, _at(Vector3(p.x, top - 0.12, p.y), Vector3(0, yaw, 0), Vector3.ONE * 0.4))
		return
	if roll < 0.32:
		# lanternes flottantes d'Obon parmi les glaçons
		for k in rng.randi_range(4, 6):
			_toro_into(bn, _at(Vector3(p.x + rng.randf_range(-1.0, 1.0), VOID_Y, p.y + rng.randf_range(-1.0, 1.0)), Vector3(0, rng.randf() * TAU, 0)))
		for k in 3:
			var q := p + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
			_inst(ctx, "floe", _cyl(0.6, 0.62, 0.06, 6), _toon(ICE, false), _at(Vector3(q.x, VOID_Y + 0.02, q.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.6, 1.2), 1, rng.randf_range(0.5, 1.0))))
		return
	var r := rng.randf_range(1.1, 1.6)
	var top := _mound_into(bs, bn, p, r, rng)
	var r2 := rng.randf()
	if r2 < 0.3:
		for k in rng.randi_range(1, 2):
			var q := Vector3(p.x + rng.randf_range(-0.5, 0.5), top - 0.1, p.y + rng.randf_range(-0.5, 0.5))
			_snow_pine_into(bs, _at(q, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(1.0, 1.5)))
	elif r2 < 0.55:
		var gm := _toon(GRAVE, true, 0.02)
		var cap := _toon(SNOW, false)
		for k in rng.randi_range(2, 3):
			var q := Vector3(p.x + (k - 1) * 0.55 + rng.randf_range(-0.1, 0.1), top - 0.12, p.y + rng.randf_range(-0.3, 0.3))
			_stele_into(bs, gm, cap, _at(q, Vector3(rng.randf_range(-0.08, 0.08), face + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.1)),
				Vector3.ONE * rng.randf_range(0.8, 1.05)))
		var back := Vector3(-sin(face), 0, -cos(face)) * 0.5
		_sotoba_into(bs, _at(Vector3(p.x, top - 0.12, p.y) + back, Vector3(0, face, 0)), rng)
	elif r2 < 0.75:
		var side := Vector3(cos(face), 0, -sin(face))
		var n := rng.randi_range(2, 4)
		for k in n:
			var q := Vector3(p.x, top - 0.1, p.y) + side * (k - (n - 1) * 0.5) * 0.5
			_jizo_into(bs, _at(q, Vector3(0, face, 0)))
		_offering_into(bs, bn, _at(Vector3(p.x, top - 0.1, p.y) + Vector3(sin(face), 0, cos(face)) * 0.5, Vector3(0, face, 0)))
	elif r2 < 0.87 and _light_ok(ctx):
		_stone_lantern(ctx, Vector3(p.x, top - 0.08, p.y), 0.85, true)
	elif r2 < 0.94:
		var cols: Array[Color] = [BONNET, Color("#5B6C8F"), Toon.WASHI]
		_wagasa_into(bs, _at(Vector3(p.x - 0.3, top - 0.05, p.y), Vector3(0, rng.randf() * TAU, 0)), true, cols[rng.randi_range(0, 2)])
		_wagasa_into(bs, _at(Vector3(p.x + 0.4, top - 0.05, p.y + 0.2), Vector3(0, face, 0)), false, cols[rng.randi_range(0, 2)])
	else:
		for k in 2:
			var a := rng.randf() * TAU
			_mound_into(bs, bn, p + Vector2(cos(a), sin(a)) * r * 0.9, r * 0.55, rng)


static func _fill_contes(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bn: Dictionary = ctx["bn"]
	var lump := _toon(SNOW, false)
	for i in 40:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.4, 1.5)
		if p.y > 6.5:
			s *= 0.6
		_inst(ctx, "lump", _ball(0.5, 0.36, 9, 4), lump, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * rng.randf_range(0.7, 1.1), s * rng.randf_range(0.8, 1.2))))
	var ice := _toon(ICE, false)
	for i in 16:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 5.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.6, 1.6)
		_inst(ctx, "floe", _cyl(0.6, 0.62, 0.06, 6), ice, _at(Vector3(p.x, VOID_Y + 0.02, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, 1, s * rng.randf_range(0.6, 1.0))))
	var reed := _toon_ds(Color("#9C9480"))
	for i in 26:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 3.5, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.8, 1.5)
		_inst(ctx, "reed", _tuft_mesh(), reed, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * 1.3, s)))
	for i in rng.randi_range(6, 10):
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 4.0, true)
		if p == NONE2:
			continue
		_toro_into(bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0)))


# --- monde 4 : forges du Fuji rouge

static func _big_fuji(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var roll := rng.randf()
	if roll < 0.16:
		_spikes_into(bs, bn, p, rng.randf_range(0.9, 1.3), rng)
	elif roll < 0.29:
		_basalt_into(bs, p, 0.5, 0.05, rng)
		var s := rng.randf_range(0.9, 1.1)
		_brazier_into(bs, bn, _at(Vector3(p.x, 0.05, p.y), Vector3.ZERO, Vector3.ONE * s))
		_light(ctx, Vector3(p.x, 0.05 + 1.3 * s, p.y), Color(1.0, 0.55, 0.25), 0.55, 3.5)
	elif roll < 0.4:
		_basalt_into(bs, p, 0.5, -0.05, rng)
		_anvil_into(bs, bn, _at(Vector3(p.x, -0.05, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.9, 1.1)))
		_ingots_into(bs, bn, _at(Vector3(p.x + 0.75, VOID_Y + 0.05, p.y + 0.3), Vector3(0, rng.randf() * TAU, 0)))
	elif roll < 0.49:
		_chain_into(bs, p, rng)
	elif roll < 0.58:
		_basalt_into(bs, p, 0.45, -0.1, rng)
		_oni_mask_into(bs, bn, _at(Vector3(p.x, -0.1, p.y), Vector3(0, _face(p, 0.0, p.y), 0), Vector3.ONE * rng.randf_range(1.0, 1.2)))
	elif roll < 0.7 and _ok(ctx, p, 1.9, 0.0):
		var xf := _at(Vector3(p.x, 0.0, p.y), Vector3(0, rng.randf_range(-0.25, 0.25), 0), Vector3.ONE * 0.8)
		_forge_into(bs, bn, xf)
		_light(ctx, xf * Vector3(-0.35, 0.5, 0.5), Color(1.0, 0.5, 0.2), 0.7, 3.5)
	elif roll < 0.84:
		_katanas(ctx, p, rng)
	else:
		_basalt_into(bs, p, 0.55, VOID_Y + 0.3, rng)
		_yoshida_into(bs, bn, _at(Vector3(p.x, VOID_Y + 0.25, p.y), Vector3.ZERO, Vector3.ONE * 0.55))
		_light(ctx, Vector3(p.x, VOID_Y + 2.6, p.y), Color(1.0, 0.55, 0.25), 0.6, 4.0)


## Cimetière de katanas plantés dans une butte de basalte, auréole de braise.
static func _katanas(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	_basalt_into(bs, p, 0.45, VOID_Y + 0.35, rng)
	for k in rng.randi_range(5, 8):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.85)
		var y: float = VOID_Y + 0.35 if d < 0.45 else VOID_Y + 0.02
		var tilt := Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		Decor.katana_into(bs, _at(Vector3(p.x + cos(a) * d, y, p.y + sin(a) * d), tilt, Vector3.ONE * rng.randf_range(0.8, 1.05)))
	_add(bn, _glow(Color("#C07A2A"), 0.8), _cyl(1.1, 1.1, 0.02, 12), _at(Vector3(p.x, VOID_Y + 0.01, p.y)))


static func _fill_fuji(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bm := _toon(BASALT, true, 0.025)
	var chunk := _ball(0.5, 0.55, 6, 3)
	for i in 42:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.25, 0.8)
		if p.y > 6.5:
			s *= 0.5
		_inst(ctx, "chunk", chunk, bm, _at(Vector3(p.x, VOID_Y - 0.05, p.y), Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)), Vector3.ONE * s))
	var gm := _glow(LAVA_GOLD, 1.2)
	for i in 26:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		_inst(ctx, "crack", _box(Vector3(1.0, 0.02, 0.06)), gm, _at(Vector3(p.x, VOID_Y + 0.01, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.4, 1.4), 1, 1)))
	var pool := _glow(Color("#C07A2A"), 0.8)
	for i in 6:
		var p := _ring_pt(ctx, rng, 0.6, 0.0, 5.0, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.6, 1.3)
		_inst(ctx, "pool", _cyl(0.6, 0.6, 0.02, 10), pool, _at(Vector3(p.x, VOID_Y + 0.005, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, 1, s * rng.randf_range(0.6, 1.0))))


# --- monde 5 : mer d'encre et Trente-six vues

static func _big_ink(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var face := _face(p, 0.0, p.y)
	var roll := rng.randf()
	if roll < 0.18:
		# barque dans le sens de la longueur de l'arène (côtés) ou de sa largeur (fond)
		var rot: float = PI * 0.5 if absf(p.x) > 5.0 else 0.0
		_boat_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rot + rng.randf_range(-0.2, 0.2), 0), Vector3.ONE * rng.randf_range(0.6, 0.8)), rng.randi_range(0, 2))
	elif roll < 0.31:
		_brush_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)), Vector3.ONE * rng.randf_range(0.8, 1.2)))
	elif roll < 0.4:
		_papers_into(bn, p, rng, 2, VOID_Y + 0.02, 0.4)
		_seal_into(bs, _at(Vector3(p.x, VOID_Y + 0.03, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.9, 1.2)))
	elif roll < 0.48:
		_papers_into(bn, p, rng, rng.randi_range(3, 5), VOID_Y + 0.02, 1.0)
	elif roll < 0.6:
		# porte du Nouvel An : deux kadomatsu et une shimenawa sur un radeau
		var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, face, 0))
		_add(bs, _toon(Color("#5B4630"), true, 0.02), _box(Vector3(1.9, 0.2, 0.9)), xf * _at(Vector3(0, 0.05, 0)))
		_sheet_into(bn, _toon(Toon.WASHI, false), xf * _at(Vector3(0, 0.16, 0)), 1.6, 0.7)
		for sx: float in [-1.0, 1.0]:
			Decor.kadomatsu_into(bs, bn, xf * _at(Vector3(sx * 0.62, 0.15, 0), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.8))
		Decor.shimenawa_into(bs, bn, xf * Vector3(-0.62, 1.05, 0.0), xf * Vector3(0.62, 1.05, 0.0))
	elif roll < 0.7 and _ok(ctx, p, 1.6, 0.0):
		_barrel_giant_into(bs, bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf_range(-0.3, 0.3), 0), Vector3.ONE * 0.7))
	elif roll < 0.84:
		_ink_claw_into(bs, bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, face, 0), Vector3.ONE * rng.randf_range(0.8, 1.1)), rng)
	elif roll < 0.92:
		var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf_range(-0.3, 0.3), 0))
		_add(bs, _toon(Color("#5B4630"), true, 0.02), _box(Vector3(1.8, 0.2, 0.7)), xf * _at(Vector3(0, 0.05, 0)))
		_byobu_into(bs, xf * _at(Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE * 0.9))
	else:
		var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, face, 0))
		_add(bs, _toon(Color("#5B4630"), true, 0.02), _box(Vector3(0.9, 0.2, 0.9)), xf * _at(Vector3(0, 0.05, 0)))
		_kagami_into(bs, xf * _at(Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE * 1.2))
		_papers_into(bn, p, rng, 2, VOID_Y + 0.02, 0.9)


static func _fill_ink(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var pa := _toon(Color("#F1E8D6"), false)
	var pb := _toon(Color("#E2D6BD"), false)
	var sheet := _box(Vector3(0.4, 0.008, 0.3))
	for i in 40:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var xf := _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.6, 2.0), 1, rng.randf_range(0.6, 1.8)))
		if rng.randf() < 0.6:
			_inst(ctx, "paper_a", sheet, pa, xf)
		else:
			_inst(ctx, "paper_b", sheet, pb, xf)
	var fm := _flat(Toon.FOAM)
	for i in 22:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.6, 1.4)
		_inst(ctx, "foam", _crescent_mesh(), fm, _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, 1, s)))

# ------------------------------------------------------------------ modèles (ajoutés aux lots, placés par `xf`)

## Statue de renard (kitsune) assise sur son socle, foulard vermillon ; regarde vers +Z local.
static func _kitsune_into(b: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(STONE, true, 0.025)
	var dark := _toon(STONE_DARK, true, 0.025)
	var bib := _toon(Toon.VERMILION.darkened(0.12), true, 0.015)
	var eye := _toon(Toon.GOLD, false)
	_add(b, dark, _box(Vector3(0.55, 0.22, 0.75)), xf * _at(Vector3(0, 0.11, 0)))
	_add(b, stone, _ball(0.24, 0.3, 8, 4), xf * _at(Vector3(0, 0.35, -0.08)))
	_add(b, stone, _ball(0.18, 0.6, 8, 5), xf * _at(Vector3(0, 0.55, -0.02), Vector3(-0.25, 0, 0)))
	for sx: float in [-1.0, 1.0]:
		_limb(b, stone, Vector3(sx * 0.08, 0.22, 0.14), Vector3(sx * 0.07, 0.62, 0.06), 0.04, 0.035, 5, xf)
	_add(b, stone, _ball(0.13, 0.24, 8, 4), xf * _at(Vector3(0, 0.86, 0.04)))
	_limb(b, stone, Vector3(0, 0.84, 0.1), Vector3(0, 0.8, 0.31), 0.07, 0.01, 5, xf)
	for sx: float in [-1.0, 1.0]:
		_limb(b, stone, Vector3(sx * 0.07, 0.94, 0.02), Vector3(sx * 0.1, 1.13, 0.0), 0.045, 0.0, 4, xf)
		_add(b, eye, _ball(0.018, 0.03, 5, 3), xf * _at(Vector3(sx * 0.055, 0.89, 0.15)))
	_limb(b, stone, Vector3(0, 0.3, -0.25), Vector3(0.05, 0.6, -0.42), 0.07, 0.09, 6, xf)
	_limb(b, stone, Vector3(0.05, 0.6, -0.42), Vector3(0.02, 0.95, -0.32), 0.09, 0.02, 6, xf)
	_add(b, bib, _cyl(0.13, 0.17, 0.1, 8), xf * _at(Vector3(0, 0.72, 0.04), Vector3(0.3, 0, 0)))
	_add(b, bib, _box(Vector3(0.18, 0.15, 0.02)), xf * _at(Vector3(0, 0.63, 0.16), Vector3(0.25, 0, 0)))


## Bambou de Tanabata : tige, panache de feuilles, rameaux et bandes tanzaku colorées.
static func _tanzaku_into(b: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var x2 := xf * _at(Vector3.ZERO, Vector3(0, rng.randf() * TAU, 0))
	var stem := _toon(Decor.BAMBOO, true, 0.015)
	var node_m := _toon(Decor.BAMBOO_NODE, false)
	var leaf := _toon(Decor.BAMBOO_LEAF, false)
	var h := rng.randf_range(1.7, 2.2)
	var top := Vector3(rng.randf_range(-0.08, 0.08), h, rng.randf_range(-0.08, 0.08))
	_limb(b, stem, Vector3.ZERO, top, 0.035, 0.025, 6, x2)
	for k in 4:
		_add(b, node_m, _cyl(0.042, 0.042, 0.025, 6), x2 * _at(top * (0.2 + k * 0.22)))
	for k in 6:
		var yaw := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(yaw), rng.randf_range(-0.5, 0.1), sin(yaw)).normalized()
		_limb(b, leaf, top, top + d * rng.randf_range(0.25, 0.4), 0.03, 0.0, 3, x2)
	for k in 2:
		var yaw := rng.randf() * TAU + k * PI
		var a := top * (0.62 + k * 0.16)
		var c := a + Vector3(cos(yaw) * 0.45, -0.05, sin(yaw) * 0.45)
		_limb(b, stem, a, c, 0.014, 0.008, 4, x2)
		for j in 3:
			var q := a.lerp(c, 0.3 + j * 0.3)
			var col: Color = TANZAKU[rng.randi_range(0, TANZAKU.size() - 1)]
			_add(b, _toon(col, false), _box(Vector3(0.07, 0.24, 0.006)),
				x2 * _at(q - Vector3(0, 0.13, 0), Vector3(rng.randf_range(-0.1, 0.1), yaw + rng.randf_range(-0.4, 0.4), 0)))


## Congère / îlot de neige (ellipsoïde + bosses, liseré lavande au ras du vide). Renvoie la hauteur du sommet.
static func _mound_into(b: Dictionary, bn: Dictionary, p: Vector2, r: float, rng: RandomNumberGenerator) -> float:
	var snow := _toon(SNOW, true, 0.02)
	var shade := _toon(SNOW_SHADE, false)
	var sz := rng.randf_range(0.8, 1.15)
	_add(b, snow, _ball(r, r * 0.7, 12, 5), _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3(1, 1, sz)))
	for k in rng.randi_range(1, 2):
		var a := rng.randf() * TAU
		var rr := r * rng.randf_range(0.35, 0.55)
		_add(b, snow, _ball(rr, rr * 0.8, 9, 4), _at(Vector3(p.x + cos(a) * r * 0.8, VOID_Y, p.y + sin(a) * r * 0.8 * sz)))
	_add(bn, shade, _cyl(r * 1.05, r * 1.1, 0.05, 14), _at(Vector3(p.x, VOID_Y + 0.02, p.y), Vector3.ZERO, Vector3(1, 1, sz)))
	return VOID_Y + r * 0.35


## Stèle (haka) : deux gradins, fût, calotte de neige.
static func _stele_into(b: Dictionary, stone: Material, cap: Material, xf: Transform3D) -> void:
	_add(b, stone, _box(Vector3(0.62, 0.14, 0.5)), xf * _at(Vector3(0, 0.07, 0)))
	_add(b, stone, _box(Vector3(0.46, 0.14, 0.38)), xf * _at(Vector3(0, 0.21, 0)))
	_add(b, stone, _box(Vector3(0.3, 0.86, 0.26)), xf * _at(Vector3(0, 0.71, 0)))
	_add(b, cap, _box(Vector3(0.33, 0.06, 0.29)), xf * _at(Vector3(0, 1.16, 0)))
	_add(b, cap, _box(Vector3(0.6, 0.03, 0.12)), xf * _at(Vector3(0, 0.155, 0.18)))


## Jizō : corps de pierre, bonnet et bavoir sombres (jamais vermillon), neige sur le bonnet.
static func _jizo_into(b: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(Color("#9A978F"), true, 0.02)
	var head := _toon(Color("#A7A49C"), true, 0.02)
	var cloth := _toon(BONNET, true, 0.02)
	var snow := _toon(SNOW, false)
	_add(b, stone, _cyl(0.2, 0.23, 0.1, 8), xf * _at(Vector3(0, 0.05, 0)))
	_add(b, stone, Toon.capsule(0.15, 0.55), xf * _at(Vector3(0, 0.36, 0)))
	_add(b, cloth, _cyl(0.12, 0.19, 0.16, 8), xf * _at(Vector3(0, 0.52, 0.01)))
	_add(b, head, _ball(0.12, 0.23, 8, 4), xf * _at(Vector3(0, 0.71, 0)))
	_add(b, cloth, _ball(0.13, 0.14, 8, 4), xf * _at(Vector3(0, 0.78, -0.01)))
	_add(b, snow, _ball(0.09, 0.06, 7, 3), xf * _at(Vector3(0, 0.84, -0.01)))


## Pin enneigé : tronc, trois étages coniques, chapeaux de neige.
static func _snow_pine_into(b: Dictionary, xf: Transform3D) -> void:
	var trunk := _toon(Decor.BARK_PINE, true, 0.025)
	var green := _toon(Decor.PINE_B, true, 0.025)
	var snow := _toon(SNOW, false)
	_add(b, trunk, _cyl(0.08, 0.12, 0.8, 6), xf * _at(Vector3(0, 0.4, 0)))
	var radii := PackedFloat32Array([0.9, 0.7, 0.5])
	var hs := PackedFloat32Array([0.9, 0.8, 0.7])
	var y := 0.5
	for k in 3:
		var r := radii[k]
		var h := hs[k]
		var yc := y + h * 0.5
		_add(b, green, _cyl(0.0, r, h, 7), xf * _at(Vector3(0, yc, 0), Vector3(0, k * 0.4, 0)))
		var hsn := h * 0.55
		_add(b, snow, _cyl(0.0, r * 0.62, hsn, 7), xf * _at(Vector3(0, yc + h * 0.5 + 0.02 - hsn * 0.5, 0), Vector3(0, k * 0.4, 0)))
		y += h * 0.55


## Lanterne flottante d'Obon : socle de bois et cube de papier lumineux.
static func _toro_into(b: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Color("#3B2E25"), false)
	_add(b, wood, _box(Vector3(0.36, 0.06, 0.36)), xf * _at(Vector3(0, 0.03, 0)))
	_add(b, _glow(Color("#FBE3B0"), 0.9), _box(Vector3(0.26, 0.3, 0.26)), xf * _at(Vector3(0, 0.21, 0)))
	_add(b, wood, _box(Vector3(0.3, 0.03, 0.3)), xf * _at(Vector3(0, 0.375, 0)))


## Pagode à trois toits enneigés (bois sombre, murs crème), flèche sōrin.
static func _pagoda_into(b: Dictionary, xf: Transform3D) -> void:
	var base_m := _toon(Color("#7E7B80"))
	var wall := _toon(Color("#E6DCC6"))
	var wood := _toon(Color("#4A3428"))
	var roof := _toon(Color("#2E2C33"))
	var snow := _toon(SNOW, false)
	var spire := _toon(Color("#5A4A3A"), true, 0.02)
	_add(b, base_m, _box(Vector3(3.2, 0.4, 3.2)), xf * _at(Vector3(0, 0.2, 0)))
	var y := 0.4
	for k in 3:
		var w := 2.2 - k * 0.45
		var h := 1.1 - k * 0.1
		_add(b, wall, _box(Vector3(w, h, w)), xf * _at(Vector3(0, y + h * 0.5, 0)))
		for c in 4:
			var cx: float = (w * 0.5 - 0.05) * (1.0 if c % 2 == 0 else -1.0)
			var cz: float = (w * 0.5 - 0.05) * (1.0 if c < 2 else -1.0)
			_add(b, wood, _box(Vector3(0.13, h, 0.13)), xf * _at(Vector3(cx, y + h * 0.5, cz)))
		y += h
		var rb := (w * 0.5 + 0.6) * sqrt(2.0)
		var rt := w * 0.3 * sqrt(2.0)
		_add(b, roof, _cyl(rt, rb, 0.44, 4), xf * _at(Vector3(0, y + 0.22, 0), Vector3(0, PI * 0.25, 0)))
		_add(b, snow, _cyl(rt * 0.95, rb * 0.9, 0.42, 4), xf * _at(Vector3(0, y + 0.29, 0), Vector3(0, PI * 0.25, 0)))
		y += 0.3
	_add(b, spire, _cyl(0.05, 0.07, 1.6, 6), xf * _at(Vector3(0, y + 0.95, 0)))
	for k in 5:
		_add(b, spire, _cyl(0.14, 0.14, 0.04, 8), xf * _at(Vector3(0, y + 0.45 + k * 0.22, 0)))
	_add(b, spire, _ball(0.1, 0.2, 8, 4), xf * _at(Vector3(0, y + 1.8, 0)))


## Torii enneigé : neige sur le kasagi, le nuki et les socles.
static func _snow_torii(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	Decor.torii_into(b, xf, 0.0)
	var snow := _toon(SNOW, false)
	_add(bn, snow, _box(Vector3(4.4, 0.12, 0.52)), xf * _at(Vector3(0, 3.47, 0)))
	_add(bn, snow, _box(Vector3(5.7, 0.07, 0.18)), xf * _at(Vector3(0, 2.585, 0)))
	for sx: float in [-1.0, 1.0]:
		_add(bn, snow, _cyl(0.22, 0.26, 0.08, 10), xf * _at(Vector3(sx * 2.2, 0.44, 0)))


## Sotoba : planchettes de bois clair à inscriptions d'encre, plantées derrière les tombes.
static func _sotoba_into(b: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var wood := _toon(Toon.WOOD, true, 0.012)
	var ink := _toon(Toon.SUMI, false)
	var n := rng.randi_range(4, 6)
	for k in n:
		var h := rng.randf_range(1.1, 1.45)
		var px := xf * _at(Vector3((float(k) - (n - 1) * 0.5) * 0.13, 0, 0), Vector3(rng.randf_range(-0.12, -0.04), 0, rng.randf_range(-0.05, 0.05)))
		_add(b, wood, _box(Vector3(0.1, h, 0.02)), px * _at(Vector3(0, h * 0.5, 0)))
		_add(b, wood, _cyl(0.0, 0.07, 0.08, 4), px * _at(Vector3(0, h + 0.04, 0), Vector3(0, PI * 0.25, 0), Vector3(1, 1, 0.3)))
		_add(b, ink, _box(Vector3(0.022, h * 0.7, 0.024)), px * _at(Vector3(0, h * 0.5, 0)))


## Offrandes : petit plateau de bois, boule de riz, coupe, bougie allumée.
static func _offering_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Toon.WOOD, true, 0.015)
	var white := _toon(Color("#F4F1EA"), true, 0.012)
	_add(b, wood, _box(Vector3(0.3, 0.14, 0.3)), xf * _at(Vector3(0, 0.07, 0)))
	_add(b, wood, _box(Vector3(0.36, 0.03, 0.36)), xf * _at(Vector3(0, 0.155, 0)))
	_add(b, white, _ball(0.08, 0.1, 7, 3), xf * _at(Vector3(-0.06, 0.2, 0.0)))
	_add(b, white, _cyl(0.035, 0.025, 0.05, 6), xf * _at(Vector3(0.09, 0.195, 0.06)))
	_add(b, white, _cyl(0.018, 0.018, 0.12, 5), xf * _at(Vector3(0.08, 0.23, -0.07)))
	_add(bn, _glow(FLAME_CORE, 1.6), _cyl(0.0, 0.02, 0.05, 4), xf * _at(Vector3(0.08, 0.315, -0.07)))


## Wagasa : ombrelle de papier huilé, ouverte posée au sol ou fermée appuyée.
static func _wagasa_into(b: Dictionary, xf: Transform3D, open: bool, col: Color) -> void:
	var cloth := _toon(col, true, 0.015)
	var stick := _toon(Color("#5A4434"), true, 0.012)
	var rim := _toon(Toon.WASHI, false)
	if open:
		var x2 := xf * _at(Vector3(0, 0.3, 0), Vector3(0.9, 0, 0.2))
		_add(b, cloth, _cyl(0.04, 0.55, 0.22, 12), x2)
		_add(b, rim, Decor.torus(0.285, 0.315, 12, 4), x2)
		_add(b, stick, _cyl(0.012, 0.012, 0.7, 5), x2 * _at(Vector3(0, -0.3, 0)))
	else:
		var x2 := xf * _at(Vector3.ZERO, Vector3(0, 0, 0.25))
		_add(b, stick, _cyl(0.012, 0.012, 1.0, 5), x2 * _at(Vector3(0, 0.5, 0)))
		_add(b, cloth, _cyl(0.025, 0.07, 0.6, 8), x2 * _at(Vector3(0, 0.62, 0)))


## Colonnes de basalte : une centrale dont le sommet est à `top`, d'autres plus basses autour.
static func _basalt_into(b: Dictionary, p: Vector2, r: float, top: float, rng: RandomNumberGenerator) -> void:
	var m := _toon(BASALT, true, 0.025)
	var y0 := VOID_Y - 0.3
	var h := top - y0
	_add(b, m, _cyl(r, r * 1.05, h, 6), _at(Vector3(p.x, y0 + h * 0.5, p.y), Vector3(0, rng.randf() * TAU, 0)))
	for k in rng.randi_range(3, 5):
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var rr := r * rng.randf_range(0.45, 0.7)
		var hh := h * rng.randf_range(0.35, 0.8)
		_add(b, m, _cyl(rr, rr * 1.05, hh, 6), _at(Vector3(p.x + cos(a) * r * 1.2, y0 + hh * 0.5, p.y + sin(a) * r * 1.2)))


## Piques de roche noire plantées dans la lave, auréole dorée à leur pied.
static func _spikes_into(b: Dictionary, bn: Dictionary, p: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	var m := _toon(BASALT, true, 0.025)
	for k in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var d := 0.0 if k == 0 else rng.randf_range(0.4, 0.8) * s
		var base := Vector3(p.x + cos(a) * d, VOID_Y - 0.1, p.y + sin(a) * d)
		var h := rng.randf_range(1.4, 2.8) * s * (1.0 if k == 0 else 0.6)
		var tip := base + Vector3(rng.randf_range(-0.25, 0.25) * h, h, rng.randf_range(-0.25, 0.25) * h)
		_limb(b, m, base, tip, rng.randf_range(0.35, 0.55) * s, 0.02, 5)
	_add(bn, _glow(Color("#C07A2A"), 0.8), _cyl(0.95 * s, 0.95 * s, 0.02, 12), _at(Vector3(p.x, VOID_Y + 0.01, p.y)))


## Enclume de forge avec une lame chauffée au rouge orangé et un marteau.
static func _anvil_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var iron := _toon(IRON, true, 0.025)
	var wood := _toon(Color("#5A4434"), true, 0.015)
	_add(b, iron, _box(Vector3(0.6, 0.15, 0.45)), xf * _at(Vector3(0, 0.075, 0)))
	_add(b, iron, _box(Vector3(0.3, 0.3, 0.25)), xf * _at(Vector3(0, 0.3, 0)))
	_add(b, iron, _box(Vector3(0.8, 0.16, 0.34)), xf * _at(Vector3(0, 0.53, 0)))
	_limb(b, iron, Vector3(0.4, 0.53, 0), Vector3(0.78, 0.57, 0), 0.1, 0.01, 6, xf)
	_add(bn, _glow(Color("#E07A30"), 1.3), _box(Vector3(0.7, 0.02, 0.06)), xf * _at(Vector3(-0.05, 0.62, 0.02), Vector3(0, 0.15, 0)))
	_add(bn, _toon(Color("#2A221C"), false), _box(Vector3(0.18, 0.04, 0.05)), xf * _at(Vector3(-0.47, 0.62, 0.07), Vector3(0, 0.15, 0)))
	# marteau posé contre l'enclume
	_add(b, wood, _cyl(0.02, 0.02, 0.5, 5), xf * _at(Vector3(0.1, 0.25, 0.3), Vector3(0.5, 0, 0.2)))
	_add(b, iron, _box(Vector3(0.16, 0.07, 0.07)), xf * _at(Vector3(0.12, 0.47, 0.42), Vector3(0.5, 0, 0.2)))


## Brasero : trépied, vasque, braises et flammes (la lumière éventuelle est ajoutée à part).
static func _brazier_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var iron := _toon(IRON, true, 0.025)
	for k in 3:
		var a := TAU * k / 3.0
		_limb(b, iron, Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), Vector3(cos(a) * 0.18, 0.72, sin(a) * 0.18), 0.035, 0.03, 5, xf)
	_add(b, iron, _cyl(0.42, 0.22, 0.25, 8), xf * _at(Vector3(0, 0.82, 0)))
	_add(bn, _glow(Color("#C8642A"), 1.0), _cyl(0.38, 0.38, 0.04, 8), xf * _at(Vector3(0, 0.93, 0)))
	_add(bn, _glow(EMBER, 2.0), _cyl(0.0, 0.25, 0.6, 6), xf * _at(Vector3(0, 1.24, 0)))
	_add(bn, _glow(FLAME_CORE, 2.4), _cyl(0.0, 0.14, 0.4, 5), xf * _at(Vector3(0, 1.15, 0)))
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var q := Vector3(cos(a) * 0.2, 0.95, sin(a) * 0.2)
		_limb(bn, _glow(EMBER, 2.0), q, q + Vector3(cos(a) * 0.08, 0.32, sin(a) * 0.08), 0.1, 0.0, 5, xf)


## Chaîne tendue entre deux poteaux de fer, qui pend au milieu.
static func _chain_into(b: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var a := Vector3(p.x - dir.x * 0.95, 0, p.y - dir.y * 0.95)
	var c := Vector3(p.x + dir.x * 0.95, 0, p.y + dir.y * 0.95)
	var iron := _toon(IRON, true, 0.02)
	for q: Vector3 in [a, c]:
		_add(b, iron, _cyl(0.09, 0.12, 2.2, 6), _at(Vector3(q.x, VOID_Y + 0.8, q.z)))
		_add(b, iron, _cyl(0.14, 0.14, 0.08, 6), _at(Vector3(q.x, VOID_Y + 1.92, q.z)))
	_links(b, iron, Vector3(a.x, 1.25, a.z), Vector3(c.x, 1.25, c.z), 0.55)


## Maillons (tores étirés, alternés à 90°) le long d'une chaînette de a à c.
static func _links(b: Dictionary, m: Material, a: Vector3, c: Vector3, sag: float) -> void:
	var d := c - a
	var span := d.length()
	if span < 0.1:
		return
	var n := maxi(int(span / 0.13), 4)
	var tor := Decor.torus(0.035, 0.07, 8, 4)
	var side := d.cross(Vector3.UP).normalized()
	for i in n + 1:
		var t := float(i) / n
		var pt := _sag(a, d, sag, t)
		var tg := (_sag(a, d, sag, minf(t + 0.02, 1.0)) - _sag(a, d, sag, maxf(t - 0.02, 0.0))).normalized()
		var axis := side if i % 2 == 0 else tg.cross(side).normalized()
		var z := tg.cross(axis).normalized()
		_add(b, m, tor, Transform3D(Basis(tg * 1.5, axis, z), pt))


static func _sag(a: Vector3, d: Vector3, sag: float, t: float) -> Vector3:
	return a + d * t + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)


## Masque d'oni (rouge braise, cornes d'os, yeux d'or) accroché à un poteau ; regarde vers +Z local.
static func _oni_mask_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Color("#3B2E25"))
	var face := _toon(BRAISE)
	var bone := _toon(Color("#D8C9A3"), true, 0.02)
	var ink := _toon(Toon.SUMI, false)
	var eye := _glow(Toon.GOLD, 1.2)
	_add(b, wood, _box(Vector3(0.14, 1.6, 0.14)), xf * _at(Vector3(0, 0.8, 0)))
	_add(b, wood, _box(Vector3(0.7, 0.1, 0.1)), xf * _at(Vector3(0, 1.5, 0)))
	var c := Vector3(0, 1.22, 0.14)
	_add(b, face, _ball(0.25, 0.56, 10, 6), xf * _at(c, Vector3.ZERO, Vector3(1, 1, 0.5)))
	for sx: float in [-1.0, 1.0]:
		_limb(b, bone, c + Vector3(sx * 0.13, 0.17, 0.0), c + Vector3(sx * 0.24, 0.42, -0.03), 0.055, 0.0, 5, xf)
		_add(bn, ink, _box(Vector3(0.15, 0.045, 0.05)), xf * _at(c + Vector3(sx * 0.09, 0.08, 0.11), Vector3(0, 0, -sx * 0.4)))
		_add(bn, eye, _ball(0.035, 0.06, 6, 3), xf * _at(c + Vector3(sx * 0.09, 0.02, 0.12)))
		_limb(b, bone, c + Vector3(sx * 0.07, -0.12, 0.11), c + Vector3(sx * 0.075, -0.04, 0.12), 0.022, 0.0, 4, xf)
	_add(bn, ink, _box(Vector3(0.22, 0.05, 0.04)), xf * _at(c + Vector3(0, -0.13, 0.11)))


## Barque oshiokuri (proue effilée relevée vers +X local) et rameurs courbés.
static func _boat_into(b: Dictionary, xf: Transform3D, rowers: int) -> void:
	var hull := _toon(HULL)
	var rim := _toon(Color("#2A221C"))
	var crew := _toon(CREW, true, 0.02)
	var skin := _toon(Toon.SKIN, true, 0.02)
	_add(b, hull, _box(Vector3(3.0, 0.28, 0.62)), xf * _at(Vector3(0, 0.1, 0)))
	for sz: float in [-1.0, 1.0]:
		_add(b, rim, _box(Vector3(3.0, 0.06, 0.08)), xf * _at(Vector3(0, 0.27, sz * 0.3)))
	_limb(b, hull, Vector3(1.45, 0.1, 0), Vector3(2.3, 0.55, 0), 0.31, 0.03, 4, xf)
	_add(b, hull, _box(Vector3(0.3, 0.36, 0.62)), xf * _at(Vector3(-1.55, 0.16, 0)))
	for k in rowers:
		var x := -1.0 + k * (2.0 / maxf(float(rowers - 1), 1.0))
		_limb(b, crew, Vector3(x, 0.25, 0), Vector3(x + 0.18, 0.62, 0), 0.11, 0.08, 6, xf)
		_add(b, skin, _ball(0.08, 0.16, 6, 3), xf * _at(Vector3(x + 0.24, 0.7, 0)))
		_limb(b, rim, Vector3(x + 0.1, 0.5, 0.25), Vector3(x - 0.5, -0.1, 0.9), 0.025, 0.025, 4, xf)


## Pinceau géant planté pointe dans l'encre (inclinaison et échelle dans `xf`).
static func _brush_into(b: Dictionary, xf: Transform3D) -> void:
	var hair := _toon(Toon.SUMI, true, 0.02)
	var lac := _toon(Color("#2A1F1A"))
	var cane := _toon(Color("#B89B5E"))
	var knot := _toon(Color("#8A7040"), false)
	_add(b, hair, _ball(0.17, 0.5, 8, 4), xf * _at(Vector3(0, 0.05, 0)))
	_limb(b, hair, Vector3(0, -0.1, 0), Vector3(0, -0.5, 0), 0.15, 0.0, 7, xf)
	_add(b, lac, _cyl(0.1, 0.14, 0.26, 8), xf * _at(Vector3(0, 0.38, 0)))
	_add(b, cane, _cyl(0.075, 0.085, 2.6, 8), xf * _at(Vector3(0, 1.8, 0)))
	for k in 3:
		_add(b, knot, _cyl(0.088, 0.088, 0.035, 8), xf * _at(Vector3(0, 0.95 + k * 0.75, 0)))
	_add(b, lac, _cyl(0.09, 0.09, 0.1, 8), xf * _at(Vector3(0, 3.13, 0)))
	_add(b, _toon(Toon.GOLD, false), Decor.torus(0.04, 0.065, 10, 4), xf * _at(Vector3(0, 3.24, 0), Vector3(PI * 0.5, 0, 0)))


## Sceau de peintre : cylindre rouge cerclé d'or, poignée en boule, empreinte à côté.
static func _seal_into(b: Dictionary, xf: Transform3D) -> void:
	var red := _toon(SEAL_RED)
	var knob := _toon(Color("#E9DFC9"), true, 0.02)
	var washi := _toon(Toon.WASHI, false)
	_add(b, red, _cyl(0.3, 0.32, 0.6, 12), xf * _at(Vector3(0, 0.3, 0)))
	_add(b, _toon(Toon.GOLD, false), _cyl(0.33, 0.33, 0.06, 12), xf * _at(Vector3(0, 0.5, 0)))
	_add(b, knob, _cyl(0.1, 0.16, 0.12, 8), xf * _at(Vector3(0, 0.66, 0)))
	_add(b, knob, _ball(0.15, 0.24, 8, 4), xf * _at(Vector3(0, 0.82, 0)))
	_add(b, red, _box(Vector3(0.45, 0.01, 0.45)), xf * _at(Vector3(0.65, 0.0, 0.1), Vector3(0, 0.2, 0)))
	_add(b, washi, _box(Vector3(0.3, 0.012, 0.04)), xf * _at(Vector3(0.65, 0.002, 0.04), Vector3(0, 0.2, 0)))
	_add(b, washi, _box(Vector3(0.04, 0.012, 0.3)), xf * _at(Vector3(0.7, 0.002, 0.1), Vector3(0, 0.2, 0)))


## Feuilles de papier déchiré posées sur l'encre (quelques traits d'encre dessus).
static func _papers_into(b: Dictionary, p: Vector2, rng: RandomNumberGenerator, count: int, y: float, spread: float) -> void:
	var m1 := _toon(Toon.WASHI, false)
	var m2 := _toon(Color("#E2D6BD"), false)
	var ink := _toon(Toon.SUMI, false)
	for k in count:
		var a := rng.randf() * TAU
		var d := rng.randf() * spread
		var c := Vector3(p.x + cos(a) * d, y + k * 0.012, p.y + sin(a) * d)
		var xf := _at(c, Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.05, 0.05)))
		var w := rng.randf_range(0.5, 1.0)
		var l := rng.randf_range(0.6, 1.2)
		var pm: StandardMaterial3D = m1 if rng.randf() < 0.6 else m2
		_sheet_into(b, pm, xf, w, l)
		if rng.randf() < 0.5:
			_add(b, ink, Toon.box(Vector3(w * 0.7, 0.004, 0.05)),
				xf * _at(Vector3(0, 0.009, rng.randf_range(-l * 0.3, l * 0.3)), Vector3(0, rng.randf_range(-0.4, 0.4), 0)))


## Feuille déchirée : rectangle principal et coins arrachés décalés.
static func _sheet_into(b: Dictionary, m: Material, xf: Transform3D, w: float, l: float) -> void:
	_add(b, m, Toon.box(Vector3(w, 0.012, l)), xf)
	_add(b, m, Toon.box(Vector3(w * 0.45, 0.012, l * 0.35)), xf * _at(Vector3(w * 0.4, 0.004, l * 0.45), Vector3(0, 0.5, 0)))
	_add(b, m, Toon.box(Vector3(w * 0.3, 0.012, l * 0.25)), xf * _at(Vector3(-w * 0.45, -0.003, -l * 0.42), Vector3(0, -0.4, 0)))

## Bitte d'amarrage : pieu sombre de `base` sur `h`, cordage enroulé ; renvoie le sommet.
static func _bitt_into(b: Dictionary, bn: Dictionary, base: Vector3, h: float) -> Vector3:
	var pile := _toon(Decor.PILE, true, 0.02)
	var rope := _toon(Decor.KOMO, false)
	_add(b, pile, _cyl(0.09, 0.11, h, 6), _at(base + Vector3(0, h * 0.5, 0)))
	_add(b, pile, _cyl(0.12, 0.12, 0.05, 6), _at(base + Vector3(0, h + 0.02, 0)))
	_add(bn, rope, Decor.torus(0.1, 0.14, 10, 4), _at(base + Vector3(0, h - 0.25, 0)))
	_add(bn, rope, Decor.torus(0.1, 0.14, 10, 4), _at(base + Vector3(0, h - 0.18, 0)))
	return base + Vector3(0, h + 0.05, 0)


## Lanterne de port (jōyatō) : socle de pierre à gradins dans l'eau, fût, chambre de papier lumineuse, toit.
static func _port_lantern_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(Decor.STONE, true, 0.025)
	var dark := _toon(STONE_DARK, true, 0.025)
	var wood := _toon(Color("#3B2E25"), true, 0.02)
	var paper := _glow(Color("#FBE3B0"), 1.1)
	var roof := _toon(Color("#2E2C33"), true, 0.02)
	_add(b, dark, _box(Vector3(1.1, 0.5, 1.1)), xf * _at(Vector3(0, 0.25, 0)))
	_add(b, stone, _box(Vector3(0.85, 0.3, 0.85)), xf * _at(Vector3(0, 0.65, 0)))
	_add(b, stone, _box(Vector3(0.62, 0.25, 0.62)), xf * _at(Vector3(0, 0.92, 0)))
	_add(b, stone, _box(Vector3(0.3, 1.1, 0.3)), xf * _at(Vector3(0, 1.6, 0)))
	_add(b, dark, _box(Vector3(0.6, 0.08, 0.6)), xf * _at(Vector3(0, 2.19, 0)))
	_add(bn, paper, _box(Vector3(0.44, 0.46, 0.44)), xf * _at(Vector3(0, 2.46, 0)))
	for k in 4:
		var cx: float = 0.24 if k % 2 == 0 else -0.24
		var cz: float = 0.24 if k < 2 else -0.24
		_add(b, wood, _box(Vector3(0.06, 0.5, 0.06)), xf * _at(Vector3(cx, 2.46, cz)))
	for sz: float in [-1.0, 1.0]:
		_add(b, wood, _box(Vector3(0.5, 0.04, 0.03)), xf * _at(Vector3(0, 2.46, sz * 0.225)))
		_add(b, wood, _box(Vector3(0.03, 0.04, 0.5)), xf * _at(Vector3(sz * 0.225, 2.46, 0)))
	_add(b, roof, _cyl(0.05, 0.56, 0.32, 4), xf * _at(Vector3(0, 2.86, 0), Vector3(0, PI * 0.25, 0)))
	_add(b, roof, _ball(0.07, 0.14, 6, 3), xf * _at(Vector3(0, 3.06, 0)))


## Forge (tatara) : socle de basalte, four d'argile à gueule rougeoyante, cheminée, auvent,
## soufflet, enclume et bac de trempe. Face à +Z local.
static func _forge_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var clay := _toon(Color("#6B4A3A"), true, 0.025)
	var wood := _toon(Color("#4A3428"), true, 0.02)
	var roof := _toon(Color("#2E2C33"), true, 0.025)
	var fire := _glow(EMBER, 2.0)
	var core := _glow(FLAME_CORE, 2.4)
	_add(b, _toon(BASALT, true, 0.03), _box(Vector3(2.4, 1.2, 1.9)), xf * _at(Vector3(0, -0.5, 0)))
	_add(b, clay, _box(Vector3(1.0, 0.9, 0.7)), xf * _at(Vector3(-0.35, 0.55, -0.25)))
	_add(bn, fire, _box(Vector3(0.36, 0.26, 0.04)), xf * _at(Vector3(-0.35, 0.42, 0.11)))
	_add(bn, core, _box(Vector3(0.2, 0.14, 0.05)), xf * _at(Vector3(-0.35, 0.4, 0.115)))
	_add(b, clay, _cyl(0.16, 0.22, 1.0, 8), xf * _at(Vector3(-0.55, 1.45, -0.35)))
	_add(bn, fire, _cyl(0.12, 0.12, 0.03, 8), xf * _at(Vector3(-0.55, 1.96, -0.35)))
	for k in 4:
		var px: float = 1.05 if k % 2 == 0 else -1.05
		var pz: float = 0.8 if k < 2 else -0.8
		_add(b, wood, _box(Vector3(0.08, 1.8, 0.08)), xf * _at(Vector3(px, 1.0, pz)))
	for sz: float in [-1.0, 1.0]:
		_add(b, roof, _box(Vector3(2.5, 0.05, 1.1)), xf * _at(Vector3(0, 2.05, sz * 0.45), Vector3(sz * 0.35, 0, 0)))
	_add(b, roof, _box(Vector3(2.6, 0.08, 0.1)), xf * _at(Vector3(0, 2.25, 0)))
	_add(b, wood, _box(Vector3(0.5, 0.35, 0.3)), xf * _at(Vector3(0.55, 0.28, -0.2)))
	_add(b, wood, _cyl(0.025, 0.025, 0.5, 5), xf * _at(Vector3(0.55, 0.3, 0.1), Vector3(PI * 0.5, 0, 0)))
	_anvil_into(b, bn, xf * _at(Vector3(0.6, 0.1, 0.45), Vector3(0, 0.4, 0), Vector3.ONE * 0.7))
	_add(b, wood, _box(Vector3(0.6, 0.22, 0.3)), xf * _at(Vector3(-0.6, 0.21, 0.55)))
	_add(bn, _toon(Toon.PRUSSIAN, false), _box(Vector3(0.5, 0.02, 0.22)), xf * _at(Vector3(-0.6, 0.31, 0.55)))


## Pile de lingots d'acier (tamahagane), le dernier encore rougeoyant.
static func _ingots_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var iron := _toon(Color("#55545C"), true, 0.015)
	for layer in 3:
		for k in 3 - layer:
			var off := (float(k) - (2 - layer) * 0.5) * 0.16
			var y := 0.05 + layer * 0.09
			if layer % 2 == 0:
				_add(b, iron, _box(Vector3(0.14, 0.08, 0.36)), xf * _at(Vector3(off, y, 0)))
			else:
				_add(b, iron, _box(Vector3(0.36, 0.08, 0.14)), xf * _at(Vector3(0, y, off)))
	_add(bn, _glow(Color("#E07A30"), 1.2), _box(Vector3(0.12, 0.03, 0.3)), xf * _at(Vector3(0, 0.25, 0)))


## Torche géante du Yoshida Hi-Matsuri : socle de basalte, fût cerclé, flamme orangée à cœur d'or.
static func _yoshida_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(BASALT, true, 0.03)
	var body := _toon(Color("#6B4A2E"))
	var band := _toon(Color("#2E241C"), false)
	var flame := _glow(EMBER, 2.0)
	var core := _glow(FLAME_CORE, 2.4)
	_add(b, stone, _cyl(0.75, 0.9, 0.9, 6), xf * _at(Vector3(0, 0.15, 0)))
	_add(b, body, _cyl(0.62, 0.42, 3.0, 8), xf * _at(Vector3(0, 2.1, 0)))
	for k in 3:
		var hy := 1.2 + k * 1.0
		var rr := 0.42 + 0.2 * (hy - 0.6) / 3.0 + 0.025
		_add(b, band, _cyl(rr, rr, 0.12, 8), xf * _at(Vector3(0, hy, 0)))
	_add(bn, flame, _cyl(0.0, 0.62, 1.6, 7), xf * _at(Vector3(0, 4.4, 0)))
	_add(bn, core, _cyl(0.0, 0.36, 1.0, 6), xf * _at(Vector3(0, 4.15, 0)))
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var q := Vector3(cos(a) * 0.4, 3.75, sin(a) * 0.4)
		_limb(bn, flame, q, q + Vector3(cos(a) * 0.3, 0.8, sin(a) * 0.3), 0.2, 0.0, 5, xf)


## Barrique géante du tonnelier (Fujimigahara) dressée face à +Z, le tonnelier à l'ouvrage dedans.
static func _barrel_giant_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Color("#B48A50"), true, 0.02)
	var hoop := _toon(Decor.BAMBOO_NODE, true, 0.015)
	var crew := _toon(CREW, true, 0.02)
	var skin := _toon(Toon.SKIN, true, 0.02)
	var r := 1.1
	var c := Vector3(0, r - 0.35, 0)
	for k in 16:
		var a := TAU * k / 16.0
		_add(b, wood, _box(Vector3(0.44, 0.09, 1.0)), xf * Transform3D(Basis(Vector3(0, 0, 1), a + PI * 0.5), c + Vector3(cos(a), sin(a), 0) * r))
	for zz: float in [-0.32, 0.32]:
		_add(b, hoop, Decor.torus(r + 0.03, r + 0.11, 24, 4), xf * _at(c + Vector3(0, 0, zz), Vector3(PI * 0.5, 0, 0)))
	var foot := c + Vector3(0.15, -r + 0.06, 0)
	_limb(b, crew, foot + Vector3(0, 0.05, 0), foot + Vector3(-0.1, 0.45, 0.05), 0.13, 0.1, 6, xf)
	_add(b, skin, _ball(0.1, 0.19, 7, 3), xf * _at(foot + Vector3(-0.12, 0.6, 0.08)))
	_limb(b, crew, foot + Vector3(-0.05, 0.4, 0.1), foot + Vector3(0.35, 0.55, 0.15), 0.04, 0.035, 5, xf)
	_limb(bn, _toon(Color("#5A4434"), true, 0.012), foot + Vector3(0.35, 0.55, 0.15), foot + Vector3(0.5, 0.78, 0.15), 0.025, 0.025, 5, xf)


## Vague noire : bosse d'encre et doigts recourbés vers +Z local, griffes d'écume au bout.
static func _ink_claw_into(b: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var ink := _toon(INK_SEA, true, 0.02)
	var foam := _toon(Toon.FOAM, true, 0.012)
	_add(b, ink, _ball(1.0, 0.8, 10, 4), xf * _at(Vector3(0, 0.0, -0.2)))
	var n := rng.randi_range(3, 5)
	for k in n:
		var x := (float(k) - (n - 1) * 0.5) * 0.42
		var h := rng.randf_range(1.0, 1.5) * (1.0 - absf(x) * 0.35)
		var a := Vector3(x, 0.2, -0.25)
		var p1 := Vector3(x * 1.05, h * 0.7, -0.1)
		var p2 := Vector3(x * 1.1, h, 0.3)
		var p3 := Vector3(x * 1.1, h * 0.78, 0.7)
		_limb(b, ink, a, p1, 0.24, 0.17, 6, xf)
		_limb(b, ink, p1, p2, 0.17, 0.1, 6, xf)
		_limb(b, ink, p2, p3, 0.1, 0.03, 5, xf)
		_add(bn, foam, _ball(0.08, 0.11, 6, 3), xf * _at(p2 + Vector3(0, 0.07, 0)))
		for j in 3:
			var dir := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.7, -0.1), 1.0).normalized()
			_limb(bn, foam, p3, p3 + dir * rng.randf_range(0.12, 0.24), 0.035, 0.0, 4, xf)
	for j in 4:
		_add(bn, foam, _ball(rng.randf_range(0.18, 0.3), 0.08, 7, 3), xf * _at(Vector3(rng.randf_range(-0.9, 0.9), 0.02, rng.randf_range(0.4, 0.9))))


## Paravent byōbu à quatre feuilles en zigzag : washi, cadre laqué, nuage d'or, Fuji d'encre.
static func _byobu_into(b: Dictionary, xf: Transform3D) -> void:
	var paper := _toon(Toon.WASHI, true, 0.015)
	var frame := _toon(Color("#2A1F1A"), false)
	var gold := _toon(Toon.GOLD, false)
	var ink := _toon(Toon.SUMI, false)
	var pw := 0.48
	var start := Vector3(-pw * 1.8, 0, 0)
	for k in 4:
		var yaw: float = 0.4 if k % 2 == 0 else -0.4
		var dir := Vector3(cos(yaw), 0, -sin(yaw))
		var px := xf * _at(start + dir * pw * 0.5, Vector3(0, yaw, 0))
		_add(b, paper, _box(Vector3(pw, 1.1, 0.02)), px * _at(Vector3(0, 0.62, 0)))
		_add(b, frame, _box(Vector3(pw + 0.02, 0.04, 0.03)), px * _at(Vector3(0, 1.18, 0)))
		_add(b, frame, _box(Vector3(pw + 0.02, 0.06, 0.03)), px * _at(Vector3(0, 0.06, 0)))
		_add(b, gold, _box(Vector3(pw - 0.03, 0.16, 0.024)), px * _at(Vector3(0, 1.0, 0)))
		if k == 1 or k == 2:
			_add(b, ink, _cyl(0.05, 0.22, 0.26, 3), px * _at(Vector3(0, 0.6, 0.012), Vector3.ZERO, Vector3(1, 1, 0.05)))
		start += dir * pw


## Kagami-mochi : support sanbō, deux mochi superposés, bigarade et feuille.
static func _kagami_into(b: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Toon.WOOD, true, 0.015)
	var mochi := _toon(Color("#F6F1E6"), true, 0.015)
	var orange := _toon(Color("#E08A2E"), true, 0.012)
	_add(b, wood, _box(Vector3(0.34, 0.18, 0.34)), xf * _at(Vector3(0, 0.09, 0)))
	_add(b, wood, _box(Vector3(0.46, 0.04, 0.46)), xf * _at(Vector3(0, 0.2, 0)))
	_add(b, _toon(Toon.WASHI, false), _box(Vector3(0.36, 0.01, 0.36)), xf * _at(Vector3(0, 0.225, 0), Vector3(0, PI * 0.25, 0)))
	_add(b, mochi, _ball(0.17, 0.15, 10, 4), xf * _at(Vector3(0, 0.29, 0)))
	_add(b, mochi, _ball(0.13, 0.12, 10, 4), xf * _at(Vector3(0, 0.39, 0)))
	_add(b, orange, _ball(0.075, 0.13, 8, 4), xf * _at(Vector3(0, 0.5, 0)))
	_add(b, _toon(Decor.PINE_A, false), _box(Vector3(0.12, 0.012, 0.05)), xf * _at(Vector3(0.04, 0.565, 0), Vector3(0, 0.5, 0.3)))


# ------------------------------------------------------------------ particules d'ambiance

## Particules en boucle sur PART_AREA, propres à chaque monde.
static func build_particles(world_id: int, parent: Node3D) -> void:
	var area := PART_AREA
	var ctr := area.get_center()
	match clampi(world_id, 1, 5):
		1:
			# pétales de cerisier et quelques mouettes qui planent au-dessus du fond
			Decor.petals(parent, area)
			var g := _emitter(parent, "Gulls", Vector3(0, 4.6, -12.5), Vector3(9.0, 0.7, 1.6), 5, 22.0, _gull_mesh())
			g.direction = Vector3(1, 0, 0.05)
			g.spread = 8.0
			g.gravity = Vector3.ZERO
			g.initial_velocity_min = 0.7
			g.initial_velocity_max = 1.1
			g.color_ramp = _fade(0.08, 0.9)
			g.emitting = true
		2:
			# feux follets (kitsune-bi) : petites flammes or et blanches qui flottent
			var p := _emitter(parent, "KitsuneBi", Vector3(ctr.x, 1.6, ctr.z), Vector3(area.size.x * 0.5, 1.2, area.size.z * 0.5), 36, 5.0, _sphere_mesh("fire", 0.06, true))
			p.direction = Vector3.UP
			p.spread = 180.0
			p.gravity = Vector3(0, 0.05, 0)
			p.initial_velocity_min = 0.08
			p.initial_velocity_max = 0.25
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.7
			p.color_ramp = _fade(0.2, 0.75)
			p.color_initial_ramp = _ramp([Color(1.0, 0.82, 0.45), Color(1.0, 0.95, 0.8), Color(0.95, 0.75, 0.35)], false)
			p.emitting = true
		3:
			# neige en diagonale (le vent pousse vers +X : émetteur décalé à contre-vent)
			var life := 4.6
			var p := _emitter(parent, "Snow", Vector3(ctr.x - 1.2, area.position.y + area.size.y, ctr.z), Vector3(area.size.x * 0.5 + 1.2, 0.05, area.size.z * 0.5), 70, life, _sphere_mesh("snow", 0.035, false))
			p.direction = Vector3(0.45, -1.0, 0.12)
			p.spread = 6.0
			p.gravity = Vector3(0.04, -0.15, 0)
			p.initial_velocity_min = 1.1
			p.initial_velocity_max = 1.4
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.6
			p.color_ramp = _fade(0.08, 0.9)
			p.emitting = true
		4:
			# braises orange qui montent
			var p := _emitter(parent, "Embers", Vector3(ctr.x, area.position.y + 0.1, ctr.z), Vector3(area.size.x * 0.5, 0.1, area.size.z * 0.5), 50, 4.0, _quad_mesh("ember", Vector2(0.07, 0.07), true))
			p.direction = Vector3.UP
			p.spread = 25.0
			p.gravity = Vector3(0.08, 0.3, 0.02)
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.1
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -200.0
			p.angular_velocity_max = 200.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.5
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
			g.colors = PackedColorArray([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.8, 0.45, 1.0), Color(1.0, 0.45, 0.15, 0.85), Color(0.5, 0.1, 0.05, 0.0)])
			p.color_ramp = g
			p.emitting = true
		_:
			# fragments de papier et d'encre qui dérivent avec le vent
			var p := _emitter(parent, "Paper", Vector3(ctr.x - 2.2, 2.4, ctr.z), Vector3(area.size.x * 0.5, 2.2, area.size.z * 0.5), 44, 7.0, _quad_mesh("paper", Vector2(0.13, 0.1), false))
			p.direction = Vector3(1.0, 0.12, 0.2)
			p.spread = 25.0
			p.gravity = Vector3(0.1, -0.03, 0.02)
			p.initial_velocity_min = 0.25
			p.initial_velocity_max = 0.55
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -150.0
			p.angular_velocity_max = 150.0
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.6
			p.color_ramp = _fade(0.1, 0.85)
			p.color_initial_ramp = _ramp([Toon.WASHI, Color("#F6F0E2"), Toon.SUMI], true)
			p.emitting = true


static func _emitter(parent: Node3D, nm: String, center: Vector3, extents: Vector3, amount: int, life: float, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nm
	parent.add_child(p)
	p.position = center
	p.local_coords = false
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.mesh = mesh
	return p


## Fondu alpha : apparition jusqu'à `t_in`, disparition à partir de `t_out`.
static func _fade(t_in: float, t_out: float) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, t_in, t_out, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return g


## Teintes initiales : réparties uniformément (constant = tirage parmi des couleurs franches).
static func _ramp(cols: Array, constant: bool) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var pc := PackedColorArray()
	for i in cols.size():
		var c: Color = cols[i]
		offs.append(float(i) / maxf(float(cols.size() - 1), 1.0) if not constant else float(i) / float(cols.size()))
		pc.append(c)
	g.offsets = offs
	g.colors = pc
	if constant:
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g


## Sphère de particule (maillage propre : porte son matériau, jamais partagé avec le cache de décor).
static func _sphere_mesh(key: String, r: float, additive: bool) -> SphereMesh:
	if _meshes.has(key):
		var cached: SphereMesh = _meshes[key]
		return cached
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = _pmat(false, additive)
	_meshes[key] = m
	return m


static func _quad_mesh(key: String, size: Vector2, additive: bool) -> QuadMesh:
	if _meshes.has(key):
		var cached: QuadMesh = _meshes[key]
		return cached
	var q := QuadMesh.new()
	q.size = size
	q.material = _pmat(true, additive)
	_meshes[key] = q
	return q


## Mouette en vol (ailes en « M » le long de Z, vol vers +X), couleurs de sommets.
static func _gull_mesh() -> ArrayMesh:
	if _meshes.has("gull"):
		var cached: ArrayMesh = _meshes["gull"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var w := Color("#F4F2EC")
	var g := Color("#9AA3AD")
	var d := Color("#3A3F48")
	_vtri(st, Vector3(0.22, 0, 0), Vector3(0, 0.02, 0.05), Vector3(-0.2, 0, 0), w, w, w)
	_vtri(st, Vector3(0.22, 0, 0), Vector3(-0.2, 0, 0), Vector3(0, 0.02, -0.05), w, w, w)
	for sz: float in [-1.0, 1.0]:
		var e := Vector3(0.02, 0.07, sz * 0.22)
		var t := Vector3(-0.08, 0.0, sz * 0.48)
		_vtri(st, Vector3(0.08, 0.01, 0), e, Vector3(-0.06, 0.01, 0), w, g, w)
		_vtri(st, e, t, Vector3(-0.07, 0.05, sz * 0.25), g, d, g)
	var mesh := st.commit()
	mesh.surface_set_material(0, _pmat(false, false))
	_meshes["gull"] = mesh
	return mesh
