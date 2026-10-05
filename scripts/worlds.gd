extends RefCounted
## Les cinq mondes (univers Hokusai) : données (palette, ambiance, ennemis, difficulté)
## et décor procédural : lointain, props autour de l'arène, particules d'ambiance.
## Uniquement des const et des fonctions static. Matériaux partagés via un cache statique ;
## uniquement StandardMaterial3D et CPUParticles3D (renderer Compatibility).

const Toon = preload("res://scripts/toon.gd")
const Decor = preload("res://scripts/decor.gd")

## Surface du vide (eau, lave, encre) : le plan de arena.gd est à y = -0.6, épaisseur 0.1.
const VOID_Y := -0.55
## Zone des particules d'ambiance (couvre l'arène et un peu au-delà).
const PART_AREA := AABB(Vector3(-6, 0, -11), Vector3(12, 5, 22))
const NONE2 := Vector2(9999.0, 9999.0)
const NONE4 := Vector4(9999.0, 9999.0, 0.0, 0.0)
const MAX_LIGHTS := 3  # OmniLight3D de props par salle (mobile)

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


static func _node(parent: Node3D, pos: Vector3, nm: String, rot_y := 0.0, s := 1.0) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	return n


static func _at(p: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), p)


## Sphère basse résolution ; h < 2r donne un ellipsoïde aplati.
static func _ball(r: float, h: float, seg := 8, rings := 4) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = seg
	m.rings = rings
	return m


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


## Segment conique de a (rayon r0) vers c (rayon r1).
static func _limb(b: Dictionary, m: Material, a: Vector3, c: Vector3, r0: float, r1: float, sides := 6) -> void:
	var d := c - a
	var l := d.length()
	if l < 0.001:
		return
	_add(b, m, Toon.cyl(r1, r0, l, sides), Transform3D(_basis_y(d), (a + c) * 0.5))


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


## Monde 1 : Fuji bleu, soleil vermillon du premier jour, brume, Grande Vague et îlots.
static func _backdrop_wave(root: Node3D) -> void:
	var rng := _rng(11)
	_far(root, Toon.cyl(2.0, 46.0, 26.0, 48), Color("#5D7392"), Vector3(-18, 12.4, -170))
	_far(root, Toon.cyl(2.05, 12.5, 7.0, 48), Toon.FOAM, Vector3(-18, 21.9, -169.6))
	_far(root, Toon.sphere(11.0), Toon.VERMILION, Vector3(26, 26, -230))
	var mist := Color(Toon.WASHI, 0.85)
	_far(root, Toon.box(Vector3(140, 1.6, 0.1)), mist, Vector3(-30, 6.0, -150))
	_far(root, Toon.box(Vector3(90, 1.1, 0.1)), mist, Vector3(30, 10.5, -160))
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


## Monde 2 : nuit de Tanabata, rideau de bambous géants, allée de torii (Fushimi Inari),
## lune, Voie lactée, cascade de Kirifuri au loin.
static func _backdrop_tanabata(root: Node3D) -> void:
	var rng := _rng(22)
	# lune et son halo (disque tourné vers la caméra)
	_far(root, Toon.sphere(6.0), Color("#F4ECD2"), Vector3(-24, 30, -150))
	_far(root, Toon.cyl(11.0, 11.0, 0.1, 32), Color(0.96, 0.93, 0.82, 0.12), Vector3(-24, 30, -158), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	# Voie lactée en bande, étoiles
	_far(root, Toon.box(Vector3(340, 16, 0.1)), Color(0.9, 0.9, 1.0, 0.07), Vector3(20, 62, -240), Vector3.ONE, Vector3(0, 0, -0.32))
	_far(root, Toon.box(Vector3(340, 6, 0.1)), Color(0.95, 0.95, 1.0, 0.1), Vector3(20, 62, -239), Vector3.ONE, Vector3(0, 0, -0.32))
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
	var fall := _node(root, Vector3(26, VOID_Y, -82), "Kirifuri")
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
		_add(fb, mist, _ball(rng.randf_range(3.0, 5.0), rng.randf_range(2.0, 3.0), 10, 5), _at(Vector3(-4.0 + k * 2.8, 0.6, 1.5)))
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
	# bosquets de bambous géants : rangée du fond et côté droit, quelques-uns derrière les torii
	for k in 9:
		Decor.bamboo(root, Vector3(-12.0 + k * 3.0 + rng.randf_range(-0.6, 0.6), VOID_Y, rng.randf_range(-16.5, -13.5)),
			rng.randf_range(2.6, 3.4), 200 + k)
	for k in 5:
		Decor.bamboo(root, Vector3(rng.randf_range(10.5, 12.5), VOID_Y, -11.0 + k * 3.8), rng.randf_range(2.4, 3.2), 220 + k)
	for k in 3:
		Decor.bamboo(root, Vector3(rng.randf_range(-15.0, -14.0), VOID_Y, -10.0 + k * 5.0), rng.randf_range(2.4, 3.0), 240 + k)
	# allée de torii vermillon qui s'enfonce vers le fond
	for k in 9:
		Decor.torii(root, Vector3(-11.0, VOID_Y, -12.5 - k * 2.3), 0.8)


## Monde 3 : temple sous la neige, pagode à trois toits, montagnes blanches,
## cimetière de stèles, lanternes flottantes d'Obon.
static func _backdrop_contes(root: Node3D) -> void:
	var rng := _rng(33)
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
		_add(sb, snow, _ball(bk.z, bk.z * 0.3, 16, 6), _at(Vector3(bk.x, VOID_Y, bk.y)))
		_add(sb, shade, Toon.cyl(bk.z * 1.03, bk.z * 1.06, 0.05, 18), _at(Vector3(bk.x, VOID_Y + 0.02, bk.y)))
	_flush(sb, root, true)
	# pagode sur la berge de gauche
	_pagoda(root, Vector3(-11, VOID_Y + 7.0 * 0.15 - 0.08, -20), 1.5)
	# cimetière : stèles en rangées sur la berge de droite
	var cem := {}
	var gm := _toon(GRAVE, true, 0.02)
	var cap := _toon(SNOW, false)
	for i in 4:
		for j in 4:
			var lx := -2.4 + j * 1.5 + rng.randf_range(-0.2, 0.2)
			var lz := -2.0 + i * 1.3 + rng.randf_range(-0.2, 0.2)
			var d := Vector2(lx, lz).length()
			var y := VOID_Y + 6.0 * 0.15 * sqrt(maxf(1.0 - pow(d / 6.0, 2.0), 0.0)) - 0.05
			var xf := _at(Vector3(10.0 + lx, y, -19.0 + lz), Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.08, 0.08)),
				Vector3.ONE * rng.randf_range(0.9, 1.25))
			_stele_into(cem, gm, cap, xf)
	_flush(cem, root, true)
	# pins enneigés sur les berges
	var pines := {}
	var pspots: Array[Vector3] = [Vector3(-15, 0.1, -17), Vector3(-7, 0.1, -23), Vector3(-5, 0.6, -30), Vector3(6, 0.6, -31),
		Vector3(14, -0.1, -16), Vector3(-12.5, -0.15, -4), Vector3(12.8, -0.15, 1)]
	for p in pspots:
		_snow_pine_into(pines, _at(p, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(1.3, 2.0)))
	_flush(pines, root, true)
	Decor.stone_lantern(root, Vector3(7.0, 0.15, -16.5), 1.0)
	# lanternes flottantes (tōrō nagashi) sur l'étang
	var toro := {}
	var placed := 0
	for attempt in 120:
		if placed >= 22:
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
		_toro_into(toro, _at(p, Vector3(0, rng.randf() * TAU, 0)))
		placed += 1
	_flush(toro, root)


## Monde 4 : Fuji rouge (Gaifū kaisei) sous un ciel de nuages en écailles,
## coulées de lave noire veinée d'or, piques de roche, torches géantes de Yoshida.
static func _backdrop_fuji_rouge(root: Node3D) -> void:
	var rng := _rng(44)
	var fx := 8.0
	var fz := -165.0
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
	_far(root, _ball(70.0, 14.0, 16, 6), Color("#2B3F3C"), Vector3(fx, -2.0, -140.0), Vector3(1, 1, 0.35))
	# nuages en écailles (alto-cumulus de l'estampe)
	var clouds := {}
	var cm := _flat(Color("#EDE6D8"))
	for row in 5:
		for col in 18:
			var x := -150.0 + col * 17.0 + (8.5 if row % 2 == 1 else 0.0) + rng.randf_range(-2.0, 2.0)
			var r := 4.5 - row * 0.35
			_add(clouds, cm, _ball(r, r * 0.5, 8, 4), _at(Vector3(x, 34.0 + row * 5.0, -195.0 - row * 3.0), Vector3.ZERO, Vector3(1, 1, 0.3)))
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
	# piques de roche
	var sp := {}
	var bm := _toon(BASALT, true, 0.03)
	for i in 16:
		var p := Vector2.ZERO
		if rng.randf() < 0.6:
			p = Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-42.0, -13.5))
		else:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector2(sx * rng.randf_range(13.0, 18.0), rng.randf_range(-12.0, 6.0))
		var h := rng.randf_range(3.0, 8.0)
		var base := Vector3(p.x, VOID_Y - 0.2, p.y)
		_limb(sp, bm, base, base + Vector3(rng.randf_range(-0.2, 0.2) * h, h, rng.randf_range(-0.2, 0.2) * h), rng.randf_range(0.8, 1.8), 0.05, 5)
	_flush(sp, root, true)
	# torches géantes du Yoshida Hi-Matsuri
	var spots: Array[Vector3] = [Vector3(-10, VOID_Y, -11), Vector3(10, VOID_Y, -11), Vector3(-10, VOID_Y, -3),
		Vector3(10, VOID_Y, -3), Vector3(-10, VOID_Y, 5), Vector3(10, VOID_Y, 5), Vector3(-5.5, VOID_Y, -13.5), Vector3(5.5, VOID_Y, -13.5)]
	_torches(root, spots)


## Monde 5 : mer d'encre, grandes vagues noires, barques oshiokuri, papiers flottants,
## petit Fuji d'encre, ciel de papier rose d'aube.
static func _backdrop_ink(root: Node3D) -> void:
	var rng := _rng(55)
	# ciel de papier : soleil pâle et bandes de nuages rose aube / washi
	_far(root, Toon.sphere(9.0), Color("#F3D3B5"), Vector3(28, 18, -230))
	for k in 6:
		var col: Color = Color(Color("#E4B7B0"), 0.7) if k % 2 == 0 else Color(Toon.WASHI, 0.8)
		_far(root, Toon.box(Vector3(rng.randf_range(80.0, 160.0), rng.randf_range(1.2, 3.0), 0.1)), col,
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
	# barques oshiokuri et leurs rameurs courbés
	_boat(root, Vector3(-14, VOID_Y, -28), 1.5, 0.3, 4)
	_boat(root, Vector3(8, VOID_Y, -36), 1.7, -0.25, 4)
	_boat(root, Vector3(-30, VOID_Y, -55), 2.2, 0.5, 3)
	# grands pinceaux plantés comme des mâts
	_brush(root, Vector3(-11, VOID_Y, -15), 2.0, Vector3(0, 0, 0.18))
	_brush(root, Vector3(11.5, VOID_Y, -17), 2.3, Vector3(0.1, 0, -0.15))
	# feuilles de papier déchiré qui flottent sur l'encre et dans l'air
	var sheets := {}
	var pa := _toon(Color("#F1E8D6"), false)
	var pb := _toon(Color("#E2D6BD"), false)
	for i in 18:
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
		_sheet_into(sheets, pm, _at(p, rot), rng.randf_range(1.0, 2.6), rng.randf_range(1.2, 3.2))
	_flush(sheets, root)


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


## Torches géantes : socle de basalte, fût de bois cerclé, flamme orangée à cœur d'or (sans lumière).
static func _torches(root: Node3D, spots: Array[Vector3]) -> void:
	var b := {}
	var fire := {}
	var stone := _toon(BASALT, true, 0.03)
	var body := _toon(Color("#6B4A2E"))
	var band := _toon(Color("#2E241C"), false)
	var flame := _glow(EMBER, 2.0)
	var core := _glow(FLAME_CORE, 2.4)
	for p in spots:
		_add(b, stone, Toon.cyl(0.75, 0.9, 0.9, 6), _at(p + Vector3(0, 0.15, 0)))
		_add(b, body, Toon.cyl(0.62, 0.42, 3.0, 8), _at(p + Vector3(0, 2.1, 0)))
		for k in 3:
			var hy := 1.2 + k * 1.0
			var rr := 0.42 + 0.2 * (hy - 0.6) / 3.0 + 0.025
			_add(b, band, Toon.cyl(rr, rr, 0.12, 8), _at(p + Vector3(0, hy, 0)))
		_add(fire, flame, Toon.cyl(0.0, 0.62, 1.6, 7), _at(p + Vector3(0, 4.4, 0)))
		_add(fire, core, Toon.cyl(0.0, 0.36, 1.0, 6), _at(p + Vector3(0, 4.15, 0)))
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			var q := p + Vector3(cos(a) * 0.4, 3.75, sin(a) * 0.4)
			_limb(fire, flame, q, q + Vector3(cos(a) * 0.3, 0.8, sin(a) * 0.3), 0.2, 0.0, 5)
	_flush(b, root, true)
	_flush(fire, root, false)


# ------------------------------------------------------------------ props autour de l'arène

## Décor de salle autour des zones jouables `rects` (Rect2 : x min, z min, largeur x, profondeur z).
## Grands props hors de l'arène, petits dans les vides entre plateformes, quelques-uns au ras du bord.
static func build_props(world_id: int, parent: Node3D, rects: Array, rng_seed: int) -> void:
	var wid := clampi(world_id, 1, 5)
	var rng := _rng(rng_seed * 31 + wid)
	var root := Node3D.new()
	root.name = "Props"
	parent.add_child(root)
	var taken: Array[Vector2] = []
	var ctx := {"lights": 0}
	# grands props dans le vide autour de l'arène
	for i in rng.randi_range(9, 13):
		var p := _spot_outer(rects, rng, taken)
		if p == NONE2:
			continue
		taken.append(p)
		_prop_big(wid, root, p, rng, ctx)
	# petits props dans les vides entre plateformes
	for i in rng.randi_range(2, 6):
		var p := _spot_gap(rects, rng, taken)
		if p == NONE2:
			continue
		taken.append(p)
		_prop_small(wid, root, p, rng, ctx)
	# petits props de bord, juste à côté d'une plateforme
	for i in rng.randi_range(3, 5):
		var e := _spot_edge(rects, rng, taken)
		if e == NONE4:
			continue
		taken.append(Vector2(e.x, e.y))
		_prop_edge(wid, root, e, rng, ctx)


## Vrai si `p` est hors de toutes les zones jouables (élargies de `margin`) et loin des autres props.
static func _free(rects: Array, taken: Array[Vector2], p: Vector2, margin: float, spacing: float) -> bool:
	for r in rects:
		var rr: Rect2 = r
		if rr.grow(margin).has_point(p):
			return false
	for q in taken:
		if q.distance_to(p) < spacing:
			return false
	return true


## Emplacement d'un grand prop : sur les côtés (|x| > 5.6) ou au fond (z < -10).
static func _spot_outer(rects: Array, rng: RandomNumberGenerator, taken: Array[Vector2]) -> Vector2:
	for attempt in 40:
		var p := Vector2.ZERO
		if rng.randf() < 0.72:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector2(sx * rng.randf_range(5.6, 8.4), rng.randf_range(-11.5, 7.5))
		else:
			p = Vector2(rng.randf_range(-7.5, 7.5), rng.randf_range(-12.8, -10.2))
		if _free(rects, taken, p, 1.2, 2.0):
			return p
	return NONE2


## Emplacement d'un petit prop dans un vide intérieur de l'arène.
static func _spot_gap(rects: Array, rng: RandomNumberGenerator, taken: Array[Vector2]) -> Vector2:
	for attempt in 40:
		var p := Vector2(rng.randf_range(-4.2, 4.2), rng.randf_range(-8.2, 8.2))
		if _free(rects, taken, p, 0.9, 1.3):
			return p
	return NONE2


## Emplacement de bord : (x, z, normale sortante x, normale sortante z), à 0.38 du bord d'une plateforme.
static func _spot_edge(rects: Array, rng: RandomNumberGenerator, taken: Array[Vector2]) -> Vector4:
	if rects.is_empty():
		return NONE4
	for attempt in 30:
		var r: Rect2 = rects[rng.randi_range(0, rects.size() - 1)]
		var t := rng.randf_range(0.12, 0.88)
		var n := Vector2.ZERO
		var p := Vector2.ZERO
		match rng.randi_range(0, 3):
			0:
				n = Vector2(-1, 0)
				p = Vector2(r.position.x, lerpf(r.position.y, r.end.y, t))
			1:
				n = Vector2(1, 0)
				p = Vector2(r.end.x, lerpf(r.position.y, r.end.y, t))
			2:
				n = Vector2(0, -1)
				p = Vector2(lerpf(r.position.x, r.end.x, t), r.position.y)
			_:
				n = Vector2(0, 1)
				p = Vector2(lerpf(r.position.x, r.end.x, t), r.end.y)
		p += n * 0.38
		# rien au bord bas de l'écran : masquerait le héros vu de la caméra plongeante
		if p.y > 7.6:
			continue
		if _free(rects, taken, p, 0.3, 1.4):
			return Vector4(p.x, p.y, n.x, n.y)
	return NONE4


## Pilier qui sort du vide jusqu'au niveau du sol (support des props de bord).
static func _pillar(root: Node3D, p: Vector2, r: float, color: Color) -> void:
	var h := 0.0 - (VOID_Y - 0.35)
	var mi := Toon.part(root, Toon.cyl(r * 0.9, r, h, 6), _toon(color, true, 0.02), Vector3(p.x, -h * 0.5, p.y))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Angle (rotation.y) pour que le +Z local regarde le point (tx, tz) depuis p.
static func _face(p: Vector2, tx: float, tz: float) -> float:
	return atan2(tx - p.x, tz - p.y)


static func _light_ok(ctx: Dictionary) -> bool:
	var n: int = ctx["lights"]
	return n < MAX_LIGHTS


static func _use_light(ctx: Dictionary) -> void:
	var n: int = ctx["lights"]
	ctx["lights"] = n + 1


static func _prop_big(wid: int, root: Node3D, p: Vector2, rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	match wid:
		1:
			_big_wave(root, p, rng, ctx)
		2:
			_big_tanabata(root, p, rng, ctx)
		3:
			_big_contes(root, p, rng, ctx)
		4:
			_big_fuji(root, p, rng, ctx)
		_:
			_big_ink(root, p, rng)


static func _prop_small(wid: int, root: Node3D, p: Vector2, rng: RandomNumberGenerator, _ctx: Dictionary) -> void:
	var sd := rng.randi() % 100000
	match wid:
		1:
			Decor.rock(root, Vector3(p.x, VOID_Y, p.y), rng.randf_range(0.45, 0.75), sd)
			if rng.randf() < 0.35:
				Decor.rock(root, Vector3(p.x + rng.randf_range(-0.5, 0.5), VOID_Y, p.y + rng.randf_range(-0.5, 0.5)), 0.35, sd + 1)
		2:
			Decor.rock(root, Vector3(p.x, VOID_Y, p.y), rng.randf_range(0.6, 0.8), sd)
			var top := Vector3(p.x, VOID_Y + 0.22, p.y)
			if rng.randf() < 0.5:
				_tanzaku(root, top, 0.75, rng)
			else:
				_kitsune(root, top, 0.6, _face(p, 0.0, p.y + 3.0))
		3:
			var roll := rng.randf()
			if roll < 0.4:
				_mound(root, p, rng.randf_range(0.45, 0.7), rng)
			elif roll < 0.75:
				var toro := {}
				for k in rng.randi_range(2, 3):
					_toro_into(toro, _at(Vector3(p.x + rng.randf_range(-0.5, 0.5), VOID_Y, p.y + rng.randf_range(-0.5, 0.5)), Vector3(0, rng.randf() * TAU, 0)))
				_flush(toro, root)
			else:
				var top := _mound(root, p, 0.6, rng)
				var st := {}
				_stele_into(st, _toon(GRAVE, true, 0.02), _toon(SNOW, false), _at(Vector3(p.x, top - 0.04, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.7))
				_flush(st, root, false)
		4:
			if rng.randf() < 0.6:
				_spikes(root, p, 0.55, rng)
			else:
				_basalt(root, p, 0.3, VOID_Y + 0.3, rng)
				_anvil(root, Vector3(p.x, VOID_Y + 0.3, p.y), 0.6, rng.randf() * TAU)
		_:
			var roll := rng.randf()
			if roll < 0.5:
				_papers(root, p, rng, rng.randi_range(2, 3), VOID_Y + 0.02, 0.5)
			elif roll < 0.75:
				_seal(root, Vector3(p.x, VOID_Y, p.y), 0.6, rng.randf() * TAU)
			else:
				_brush(root, Vector3(p.x, VOID_Y, p.y), 0.5, Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))


static func _prop_edge(wid: int, root: Node3D, e: Vector4, rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	var p := Vector2(e.x, e.y)
	var out := Vector2(e.z, e.w)
	var pos := Vector3(p.x, 0.0, p.y)
	# regarde vers la plateforme / bras de potence vers l'extérieur
	var to_arena := _face(p, p.x - out.x, p.y - out.y)
	var arm_out := atan2(-out.y, out.x)
	match wid:
		1:
			_pillar(root, p, 0.24, STONE_DARK)
			if _light_ok(ctx) and rng.randf() < 0.5:
				_use_light(ctx)
				Decor.stone_lantern(root, pos, 0.65)
			else:
				var pl: Node3D = Decor.paper_lantern(root, pos, 0.8, Toon.WASHI)
				pl.rotation.y = arm_out
		2:
			_pillar(root, p, 0.26, STONE_DARK)
			var roll := rng.randf()
			if roll < 0.4:
				_tanzaku(root, pos, 0.8, rng)
			elif roll < 0.75 or not _light_ok(ctx):
				_kitsune(root, pos, 0.65, to_arena)
			else:
				_use_light(ctx)
				Decor.stone_lantern(root, pos, 0.6)
		3:
			_pillar(root, p, 0.24, Color("#6E6C72"))
			var roll := rng.randf()
			if roll < 0.4:
				var pl: Node3D = Decor.paper_lantern(root, pos, 0.8, Toon.WASHI)
				pl.rotation.y = arm_out
			elif roll < 0.75:
				var j := {}
				_jizo_into(j, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.85))
				_flush(j, root, false)
			else:
				var st := {}
				_stele_into(st, _toon(GRAVE, true, 0.02), _toon(SNOW, false), _at(pos, Vector3(0, to_arena, 0.05), Vector3.ONE * 0.7))
				_flush(st, root, false)
		4:
			_pillar(root, p, 0.28, BASALT)
			var roll := rng.randf()
			if roll < 0.45 and _light_ok(ctx):
				_use_light(ctx)
				_brazier(root, pos, 0.6, true)
			elif roll < 0.75:
				_oni_mask(root, pos, 0.7, to_arena)
			else:
				_brazier(root, pos, 0.55, false)
		_:
			var roll := rng.randf()
			if roll < 0.45:
				_brush(root, Vector3(p.x, VOID_Y, p.y), 0.45, Vector3(out.y * 0.15, 0, -out.x * 0.15))
			elif roll < 0.75:
				_papers(root, p, rng, 2, VOID_Y + 0.02, 0.25)
			else:
				_pillar(root, p, 0.26, Color("#3A3530"))
				_seal(root, pos, 0.45, rng.randf() * TAU)


# --- monde 1 : rochers, cerisiers, pins, bambous, lanternes dans l'eau

static func _big_wave(root: Node3D, p: Vector2, rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	var s := rng.randf_range(1.4, 2.0)
	var sd := rng.randi() % 100000
	Decor.rock(root, Vector3(p.x, VOID_Y, p.y), s, sd)
	var at := Vector3(p.x, VOID_Y + 0.33 * s, p.y)
	var roll := rng.randf()
	if roll < 0.3:
		Decor.sakura(root, at, rng.randf_range(0.9, 1.3), sd)
	elif roll < 0.5:
		Decor.pine(root, at, rng.randf_range(0.9, 1.2), sd)
	elif roll < 0.65:
		Decor.bamboo(root, at, rng.randf_range(0.8, 1.1), sd)
	elif roll < 0.75 and _light_ok(ctx):
		_use_light(ctx)
		Decor.stone_lantern(root, at, 0.8)
	else:
		# amas de rochers
		for k in rng.randi_range(1, 2):
			var a := rng.randf() * TAU
			Decor.rock(root, Vector3(p.x + cos(a) * s * 0.7, VOID_Y, p.y + sin(a) * s * 0.7), s * rng.randf_range(0.4, 0.6), sd + k + 1)


# --- monde 2 : bambous, renards de pierre, petits torii, lanternes, tanzaku

static func _big_tanabata(root: Node3D, p: Vector2, rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	var sd := rng.randi() % 100000
	var roll := rng.randf()
	if roll < 0.35:
		var s := rng.randf_range(1.2, 1.6)
		Decor.rock(root, Vector3(p.x, VOID_Y, p.y), s, sd)
		var at := Vector3(p.x, VOID_Y + 0.33 * s, p.y)
		Decor.bamboo(root, at, rng.randf_range(1.0, 1.3), sd)
		if rng.randf() < 0.5:
			_tanzaku(root, at + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), 1.0, rng)
	elif roll < 0.55:
		# renard sur un haut socle, tourné vers l'arène
		_pillar(root, p, 0.45, STONE_DARK)
		_kitsune(root, Vector3(p.x, 0.0, p.y), rng.randf_range(1.1, 1.4), _face(p, 0.0, p.y))
	elif roll < 0.7:
		var t: Node3D = Decor.torii(root, Vector3(p.x, VOID_Y, p.y), 0.38)
		t.rotation.y = _face(p, 0.0, p.y)
	elif roll < 0.85 and _light_ok(ctx):
		_use_light(ctx)
		var s := rng.randf_range(1.1, 1.4)
		Decor.rock(root, Vector3(p.x, VOID_Y, p.y), s, sd)
		Decor.stone_lantern(root, Vector3(p.x, VOID_Y + 0.33 * s, p.y), 0.85)
	else:
		var s := rng.randf_range(1.2, 1.5)
		Decor.rock(root, Vector3(p.x, VOID_Y, p.y), s, sd)
		for k in 2:
			_tanzaku(root, Vector3(p.x + (k - 0.5) * 0.6, VOID_Y + 0.3 * s, p.y + rng.randf_range(-0.3, 0.3)), rng.randf_range(0.9, 1.2), rng)


# --- monde 3 : congères, pins enneigés, stèles, jizō, lanternes

static func _big_contes(root: Node3D, p: Vector2, rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	var r := rng.randf_range(1.1, 1.6)
	var top := _mound(root, p, r, rng)
	var roll := rng.randf()
	var b := {}
	if roll < 0.3:
		_snow_pine_into(b, _at(Vector3(p.x, top - 0.1, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(1.0, 1.5)))
		_flush(b, root, true)
	elif roll < 0.55:
		var gm := _toon(GRAVE, true, 0.02)
		var cap := _toon(SNOW, false)
		for k in rng.randi_range(2, 3):
			var q := Vector3(p.x + (k - 1) * 0.55 + rng.randf_range(-0.1, 0.1), top - 0.12, p.y + rng.randf_range(-0.3, 0.3))
			_stele_into(b, gm, cap, _at(q, Vector3(rng.randf_range(-0.08, 0.08), _face(p, 0.0, p.y) + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.1)),
				Vector3.ONE * rng.randf_range(0.8, 1.05)))
		_flush(b, root, true)
	elif roll < 0.75:
		var face := _face(p, 0.0, p.y)
		var side := Vector3(cos(face), 0, -sin(face))
		var n := rng.randi_range(2, 3)
		for k in n:
			var q := Vector3(p.x, top - 0.1, p.y) + side * (k - (n - 1) * 0.5) * 0.5
			_jizo_into(b, _at(q, Vector3(0, face, 0)))
		_flush(b, root, true)
	elif roll < 0.85 and _light_ok(ctx):
		_use_light(ctx)
		Decor.stone_lantern(root, Vector3(p.x, top - 0.08, p.y), 0.85)
	else:
		# congère seule, deux bosses de plus
		for k in 2:
			var a := rng.randf() * TAU
			_mound(root, p + Vector2(cos(a), sin(a)) * r * 0.9, r * 0.55, rng)


# --- monde 4 : piques de roche, braseros, enclumes, chaînes, masques d'oni

static func _big_fuji(root: Node3D, p: Vector2, rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	var roll := rng.randf()
	if roll < 0.3:
		_spikes(root, p, rng.randf_range(0.9, 1.3), rng)
	elif roll < 0.5:
		_basalt(root, p, 0.5, 0.05, rng)
		var lit := _light_ok(ctx)
		if lit:
			_use_light(ctx)
		_brazier(root, Vector3(p.x, 0.05, p.y), rng.randf_range(0.9, 1.1), lit)
	elif roll < 0.65:
		_basalt(root, p, 0.5, -0.05, rng)
		_anvil(root, Vector3(p.x, -0.05, p.y), rng.randf_range(0.9, 1.1), rng.randf() * TAU)
	elif roll < 0.8:
		_chain(root, p, rng)
	else:
		_basalt(root, p, 0.45, -0.1, rng)
		_oni_mask(root, Vector3(p.x, -0.1, p.y), rng.randf_range(1.0, 1.2), _face(p, 0.0, p.y))


# --- monde 5 : barques, pinceaux plantés, sceaux, papiers déchirés

static func _big_ink(root: Node3D, p: Vector2, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < 0.3:
		# barque dans le sens de la longueur de l'arène (côtés) ou de sa largeur (fond)
		var rot := PI * 0.5 if absf(p.x) > 5.0 else 0.0
		_boat(root, Vector3(p.x, VOID_Y, p.y), rng.randf_range(0.6, 0.8), rot + rng.randf_range(-0.2, 0.2), rng.randi_range(0, 2))
	elif roll < 0.55:
		_brush(root, Vector3(p.x, VOID_Y, p.y), rng.randf_range(0.8, 1.2), Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)))
	elif roll < 0.7:
		_papers(root, p, rng, 2, VOID_Y + 0.02, 0.4)
		_seal(root, Vector3(p.x, VOID_Y + 0.03, p.y), rng.randf_range(0.9, 1.2), rng.randf() * TAU)
	else:
		_papers(root, p, rng, rng.randi_range(3, 5), VOID_Y + 0.02, 1.0)


# ------------------------------------------------------------------ modèles

## Statue de renard (kitsune) assise sur son socle, foulard vermillon ; regarde vers +Z local.
static func _kitsune(root: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var n := _node(root, pos, "Kitsune", rot_y, s)
	var b := {}
	var stone := _toon(STONE, true, 0.025)
	var dark := _toon(STONE_DARK, true, 0.025)
	var bib := _toon(Toon.VERMILION.darkened(0.12), true, 0.015)
	var eye := _toon(Toon.GOLD, false)
	# socle
	_add(b, dark, Toon.box(Vector3(0.55, 0.22, 0.75)), _at(Vector3(0, 0.11, 0)))
	# arrière-train et buste penché en arrière
	_add(b, stone, _ball(0.24, 0.3, 8, 4), _at(Vector3(0, 0.35, -0.08)))
	_add(b, stone, _ball(0.18, 0.6, 8, 5), _at(Vector3(0, 0.55, -0.02), Vector3(-0.25, 0, 0)))
	# pattes avant
	for sx: float in [-1.0, 1.0]:
		_limb(b, stone, Vector3(sx * 0.08, 0.22, 0.14), Vector3(sx * 0.07, 0.62, 0.06), 0.04, 0.035, 5)
	# tête, museau pointu, oreilles dressées
	_add(b, stone, _ball(0.13, 0.24, 8, 4), _at(Vector3(0, 0.86, 0.04)))
	_limb(b, stone, Vector3(0, 0.84, 0.1), Vector3(0, 0.8, 0.31), 0.07, 0.01, 5)
	for sx: float in [-1.0, 1.0]:
		_limb(b, stone, Vector3(sx * 0.07, 0.94, 0.02), Vector3(sx * 0.1, 1.13, 0.0), 0.045, 0.0, 4)
		_add(b, eye, _ball(0.018, 0.03, 5, 3), _at(Vector3(sx * 0.055, 0.89, 0.15)))
	# queue en panache relevée
	_limb(b, stone, Vector3(0, 0.3, -0.25), Vector3(0.05, 0.6, -0.42), 0.07, 0.09, 6)
	_limb(b, stone, Vector3(0.05, 0.6, -0.42), Vector3(0.02, 0.95, -0.32), 0.09, 0.02, 6)
	# foulard (yodarekake) : collerette et pan qui tombe sur le poitrail
	_add(b, bib, Toon.cyl(0.13, 0.17, 0.1, 8), _at(Vector3(0, 0.72, 0.04), Vector3(0.3, 0, 0)))
	_add(b, bib, Toon.box(Vector3(0.18, 0.15, 0.02)), _at(Vector3(0, 0.63, 0.16), Vector3(0.25, 0, 0)))
	_flush(b, n, true)


## Bambou de Tanabata : tige, panache de feuilles, rameaux et bandes tanzaku colorées.
static func _tanzaku(root: Node3D, pos: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var n := _node(root, pos, "Tanzaku", rng.randf() * TAU, s)
	var b := {}
	var stem := _toon(Decor.BAMBOO, true, 0.015)
	var node_m := _toon(Decor.BAMBOO_NODE, false)
	var leaf := _toon(Decor.BAMBOO_LEAF, false)
	var h := rng.randf_range(1.7, 2.2)
	var top := Vector3(rng.randf_range(-0.08, 0.08), h, rng.randf_range(-0.08, 0.08))
	_limb(b, stem, Vector3.ZERO, top, 0.035, 0.025, 6)
	for k in 4:
		_add(b, node_m, Toon.cyl(0.042, 0.042, 0.025, 6), _at(top * (0.2 + k * 0.22)))
	for k in 6:
		var yaw := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(yaw), rng.randf_range(-0.5, 0.1), sin(yaw)).normalized()
		_limb(b, leaf, top, top + d * rng.randf_range(0.25, 0.4), 0.03, 0.0, 3)
	for k in 2:
		var yaw := rng.randf() * TAU + k * PI
		var a := top * (0.62 + k * 0.16)
		var c := a + Vector3(cos(yaw) * 0.45, -0.05, sin(yaw) * 0.45)
		_limb(b, stem, a, c, 0.014, 0.008, 4)
		for j in 3:
			var q := a.lerp(c, 0.3 + j * 0.3)
			var col: Color = TANZAKU[rng.randi_range(0, TANZAKU.size() - 1)]
			_add(b, _toon(col, false), Toon.box(Vector3(0.07, 0.24, 0.006)),
				_at(q - Vector3(0, 0.13, 0), Vector3(rng.randf_range(-0.1, 0.1), yaw + rng.randf_range(-0.4, 0.4), 0)))
	_flush(b, n, false)


## Congère / îlot de neige (ellipsoïde + bosses, liseré lavande au ras du vide). Renvoie la hauteur du sommet.
static func _mound(root: Node3D, p: Vector2, r: float, rng: RandomNumberGenerator) -> float:
	var b := {}
	var snow := _toon(SNOW, true, 0.02)
	var shade := _toon(SNOW_SHADE, false)
	var sz := rng.randf_range(0.8, 1.15)
	_add(b, snow, _ball(r, r * 0.7, 12, 5), _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3(1, 1, sz)))
	for k in rng.randi_range(1, 2):
		var a := rng.randf() * TAU
		var rr := r * rng.randf_range(0.35, 0.55)
		_add(b, snow, _ball(rr, rr * 0.8, 9, 4), _at(Vector3(p.x + cos(a) * r * 0.8, VOID_Y, p.y + sin(a) * r * 0.8 * sz)))
	_add(b, shade, Toon.cyl(r * 1.05, r * 1.1, 0.05, 14), _at(Vector3(p.x, VOID_Y + 0.02, p.y), Vector3.ZERO, Vector3(1, 1, sz)))
	_flush(b, root, r > 0.8)
	return VOID_Y + r * 0.35


## Stèle (haka) : deux gradins, fût, calotte de neige ; ajoutée au lot `b` avec la transformation `xf`.
static func _stele_into(b: Dictionary, stone: Material, cap: Material, xf: Transform3D) -> void:
	_add(b, stone, Toon.box(Vector3(0.62, 0.14, 0.5)), xf * _at(Vector3(0, 0.07, 0)))
	_add(b, stone, Toon.box(Vector3(0.46, 0.14, 0.38)), xf * _at(Vector3(0, 0.21, 0)))
	_add(b, stone, Toon.box(Vector3(0.3, 0.86, 0.26)), xf * _at(Vector3(0, 0.71, 0)))
	_add(b, cap, Toon.box(Vector3(0.33, 0.06, 0.29)), xf * _at(Vector3(0, 1.16, 0)))
	_add(b, cap, Toon.box(Vector3(0.6, 0.03, 0.12)), xf * _at(Vector3(0, 0.155, 0.18)))


## Jizō : corps de pierre, bonnet et bavoir sombres (jamais vermillon), neige sur le bonnet.
static func _jizo_into(b: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(Color("#9A978F"), true, 0.02)
	var head := _toon(Color("#A7A49C"), true, 0.02)
	var cloth := _toon(BONNET, true, 0.02)
	var snow := _toon(SNOW, false)
	_add(b, stone, Toon.cyl(0.2, 0.23, 0.1, 8), xf * _at(Vector3(0, 0.05, 0)))
	_add(b, stone, Toon.capsule(0.15, 0.55), xf * _at(Vector3(0, 0.36, 0)))
	_add(b, cloth, Toon.cyl(0.12, 0.19, 0.16, 8), xf * _at(Vector3(0, 0.52, 0.01)))
	_add(b, head, _ball(0.12, 0.23, 8, 4), xf * _at(Vector3(0, 0.71, 0)))
	_add(b, cloth, _ball(0.13, 0.14, 8, 4), xf * _at(Vector3(0, 0.78, -0.01)))
	_add(b, snow, _ball(0.09, 0.06, 7, 3), xf * _at(Vector3(0, 0.84, -0.01)))


## Pin enneigé : tronc, trois étages coniques, chapeaux de neige.
static func _snow_pine_into(b: Dictionary, xf: Transform3D) -> void:
	var trunk := _toon(Decor.BARK_PINE, true, 0.025)
	var green := _toon(Decor.PINE_B, true, 0.025)
	var snow := _toon(SNOW, false)
	_add(b, trunk, Toon.cyl(0.08, 0.12, 0.8, 6), xf * _at(Vector3(0, 0.4, 0)))
	var radii := PackedFloat32Array([0.9, 0.7, 0.5])
	var hs := PackedFloat32Array([0.9, 0.8, 0.7])
	var y := 0.5
	for k in 3:
		var r := radii[k]
		var h := hs[k]
		var yc := y + h * 0.5
		_add(b, green, Toon.cyl(0.0, r, h, 7), xf * _at(Vector3(0, yc, 0), Vector3(0, k * 0.4, 0)))
		var hsn := h * 0.55
		_add(b, snow, Toon.cyl(0.0, r * 0.62, hsn, 7), xf * _at(Vector3(0, yc + h * 0.5 + 0.02 - hsn * 0.5, 0), Vector3(0, k * 0.4, 0)))
		y += h * 0.55


## Lanterne flottante d'Obon : socle de bois et cube de papier lumineux.
static func _toro_into(b: Dictionary, xf: Transform3D) -> void:
	_add(b, _toon(Color("#3B2E25"), false), Toon.box(Vector3(0.36, 0.06, 0.36)), xf * _at(Vector3(0, 0.03, 0)))
	_add(b, _glow(Color("#FBE3B0"), 0.9), Toon.box(Vector3(0.26, 0.3, 0.26)), xf * _at(Vector3(0, 0.21, 0)))
	_add(b, _toon(Color("#3B2E25"), false), Toon.box(Vector3(0.3, 0.03, 0.3)), xf * _at(Vector3(0, 0.375, 0)))


## Pagode à trois toits enneigés (bois sombre, murs crème), flèche sōrin.
static func _pagoda(root: Node3D, pos: Vector3, s: float) -> void:
	var n := _node(root, pos, "Pagoda", 0.3, s)
	var b := {}
	var base_m := _toon(Color("#7E7B80"))
	var wall := _toon(Color("#E6DCC6"))
	var wood := _toon(Color("#4A3428"))
	var roof := _toon(Color("#2E2C33"))
	var snow := _toon(SNOW, false)
	var spire := _toon(Color("#5A4A3A"), true, 0.02)
	_add(b, base_m, Toon.box(Vector3(3.2, 0.4, 3.2)), _at(Vector3(0, 0.2, 0)))
	var y := 0.4
	for k in 3:
		var w := 2.2 - k * 0.45
		var h := 1.1 - k * 0.1
		_add(b, wall, Toon.box(Vector3(w, h, w)), _at(Vector3(0, y + h * 0.5, 0)))
		for c in 4:
			var cx: float = (w * 0.5 - 0.05) * (1.0 if c % 2 == 0 else -1.0)
			var cz: float = (w * 0.5 - 0.05) * (1.0 if c < 2 else -1.0)
			_add(b, wood, Toon.box(Vector3(0.13, h, 0.13)), _at(Vector3(cx, y + h * 0.5, cz)))
		y += h
		# toit : tronc de pyramide à 4 pans (cylindre à 4 côtés tourné de 45°)
		var rb := (w * 0.5 + 0.6) * sqrt(2.0)
		var rt := w * 0.3 * sqrt(2.0)
		_add(b, roof, Toon.cyl(rt, rb, 0.44, 4), _at(Vector3(0, y + 0.22, 0), Vector3(0, PI * 0.25, 0)))
		_add(b, snow, Toon.cyl(rt * 0.95, rb * 0.9, 0.42, 4), _at(Vector3(0, y + 0.29, 0), Vector3(0, PI * 0.25, 0)))
		y += 0.3
	# flèche (sōrin) et ses anneaux
	_add(b, spire, Toon.cyl(0.05, 0.07, 1.6, 6), _at(Vector3(0, y + 0.95, 0)))
	for k in 5:
		_add(b, spire, Toon.cyl(0.14, 0.14, 0.04, 8), _at(Vector3(0, y + 0.45 + k * 0.22, 0)))
	_add(b, spire, _ball(0.1, 0.2, 8, 4), _at(Vector3(0, y + 1.8, 0)))
	_flush(b, n, true)


## Colonnes de basalte : une centrale dont le sommet est à `top`, d'autres plus basses autour.
static func _basalt(root: Node3D, p: Vector2, r: float, top: float, rng: RandomNumberGenerator) -> void:
	var b := {}
	var m := _toon(BASALT, true, 0.025)
	var y0 := VOID_Y - 0.3
	var h := top - y0
	_add(b, m, Toon.cyl(r, r * 1.05, h, 6), _at(Vector3(p.x, y0 + h * 0.5, p.y), Vector3(0, rng.randf() * TAU, 0)))
	for k in rng.randi_range(3, 5):
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var rr := r * rng.randf_range(0.45, 0.7)
		var hh := h * rng.randf_range(0.35, 0.8)
		_add(b, m, Toon.cyl(rr, rr * 1.05, hh, 6), _at(Vector3(p.x + cos(a) * r * 1.2, y0 + hh * 0.5, p.y + sin(a) * r * 1.2)))
	_flush(b, root, true)


## Piques de roche noire plantées dans la lave, auréole dorée à leur pied.
static func _spikes(root: Node3D, p: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	var b := {}
	var glow := {}
	var m := _toon(BASALT, true, 0.025)
	for k in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var d := 0.0 if k == 0 else rng.randf_range(0.4, 0.8) * s
		var base := Vector3(p.x + cos(a) * d, VOID_Y - 0.1, p.y + sin(a) * d)
		var h := rng.randf_range(1.4, 2.8) * s * (1.0 if k == 0 else 0.6)
		var tip := base + Vector3(rng.randf_range(-0.25, 0.25) * h, h, rng.randf_range(-0.25, 0.25) * h)
		_limb(b, m, base, tip, rng.randf_range(0.35, 0.55) * s, 0.02, 5)
	_add(glow, _glow(Color("#C07A2A"), 0.8), Toon.cyl(0.95 * s, 0.95 * s, 0.02, 12), _at(Vector3(p.x, VOID_Y + 0.01, p.y)))
	_flush(b, root, s > 0.8)
	_flush(glow, root, false)


## Enclume de forge avec une lame chauffée au rouge orangé.
static func _anvil(root: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var n := _node(root, pos, "Anvil", rot_y, s)
	var b := {}
	var iron := _toon(IRON, true, 0.025)
	_add(b, iron, Toon.box(Vector3(0.6, 0.15, 0.45)), _at(Vector3(0, 0.075, 0)))
	_add(b, iron, Toon.box(Vector3(0.3, 0.3, 0.25)), _at(Vector3(0, 0.3, 0)))
	_add(b, iron, Toon.box(Vector3(0.8, 0.16, 0.34)), _at(Vector3(0, 0.53, 0)))
	_limb(b, iron, Vector3(0.4, 0.53, 0), Vector3(0.78, 0.57, 0), 0.1, 0.01, 6)
	_add(b, _glow(Color("#E07A30"), 1.3), Toon.box(Vector3(0.7, 0.02, 0.06)), _at(Vector3(-0.05, 0.62, 0.02), Vector3(0, 0.15, 0)))
	_add(b, _toon(Color("#2A221C"), false), Toon.box(Vector3(0.18, 0.04, 0.05)), _at(Vector3(-0.47, 0.62, 0.07), Vector3(0, 0.15, 0)))
	_flush(b, n, s > 0.8)


## Brasero : trépied, vasque, braises et flammes ; lumière orangée faible si `light`.
static func _brazier(root: Node3D, pos: Vector3, s: float, light: bool) -> void:
	var n := _node(root, pos, "Brazier", 0.0, s)
	var b := {}
	var fire := {}
	var iron := _toon(IRON, true, 0.025)
	for k in 3:
		var a := TAU * k / 3.0
		_limb(b, iron, Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), Vector3(cos(a) * 0.18, 0.72, sin(a) * 0.18), 0.035, 0.03, 5)
	_add(b, iron, Toon.cyl(0.42, 0.22, 0.25, 8), _at(Vector3(0, 0.82, 0)))
	_add(fire, _glow(Color("#C8642A"), 1.0), Toon.cyl(0.38, 0.38, 0.04, 8), _at(Vector3(0, 0.93, 0)))
	_add(fire, _glow(EMBER, 2.0), Toon.cyl(0.0, 0.25, 0.6, 6), _at(Vector3(0, 1.24, 0)))
	_add(fire, _glow(FLAME_CORE, 2.4), Toon.cyl(0.0, 0.14, 0.4, 5), _at(Vector3(0, 1.15, 0)))
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var q := Vector3(cos(a) * 0.2, 0.95, sin(a) * 0.2)
		_limb(fire, _glow(EMBER, 2.0), q, q + Vector3(cos(a) * 0.08, 0.32, sin(a) * 0.08), 0.1, 0.0, 5)
	_flush(b, n, true)
	_flush(fire, n, false)
	if light:
		var l := OmniLight3D.new()
		l.position = Vector3(0, 1.3, 0)
		l.light_color = Color(1.0, 0.55, 0.25)
		l.light_energy = 0.55
		l.omni_range = 3.5
		l.shadow_enabled = false
		n.add_child(l)


## Chaîne tendue entre deux poteaux de fer, qui pend au milieu.
static func _chain(root: Node3D, p: Vector2, rng: RandomNumberGenerator) -> void:
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var a := Vector3(p.x - dir.x * 0.95, 0, p.y - dir.y * 0.95)
	var c := Vector3(p.x + dir.x * 0.95, 0, p.y + dir.y * 0.95)
	var b := {}
	var iron := _toon(IRON, true, 0.02)
	for q: Vector3 in [a, c]:
		_add(b, iron, Toon.cyl(0.09, 0.12, 2.2, 6), _at(Vector3(q.x, VOID_Y + 0.8, q.z)))
		_add(b, iron, Toon.cyl(0.14, 0.14, 0.08, 6), _at(Vector3(q.x, VOID_Y + 1.92, q.z)))
	_links(b, iron, Vector3(a.x, 1.25, a.z), Vector3(c.x, 1.25, c.z), 0.55)
	_flush(b, root, true)


## Maillons (tores étirés, alternés à 90°) le long d'une chaînette de a à c.
static func _links(b: Dictionary, m: Material, a: Vector3, c: Vector3, sag: float) -> void:
	var d := c - a
	var span := d.length()
	if span < 0.1:
		return
	var n := maxi(int(span / 0.13), 4)
	var tor := TorusMesh.new()
	tor.inner_radius = 0.035
	tor.outer_radius = 0.07
	tor.rings = 8
	tor.ring_segments = 4
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
static func _oni_mask(root: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var n := _node(root, pos, "OniMask", rot_y, s)
	var b := {}
	var wood := _toon(Color("#3B2E25"))
	var face := _toon(BRAISE)
	var bone := _toon(Color("#D8C9A3"), true, 0.02)
	var ink := _toon(Toon.SUMI, false)
	var eye := _glow(Toon.GOLD, 1.2)
	_add(b, wood, Toon.box(Vector3(0.14, 1.6, 0.14)), _at(Vector3(0, 0.8, 0)))
	_add(b, wood, Toon.box(Vector3(0.7, 0.1, 0.1)), _at(Vector3(0, 1.5, 0)))
	var c := Vector3(0, 1.22, 0.14)
	_add(b, face, _ball(0.25, 0.56, 10, 6), _at(c, Vector3.ZERO, Vector3(1, 1, 0.5)))
	for sx: float in [-1.0, 1.0]:
		_limb(b, bone, c + Vector3(sx * 0.13, 0.17, 0.0), c + Vector3(sx * 0.24, 0.42, -0.03), 0.055, 0.0, 5)
		_add(b, ink, Toon.box(Vector3(0.15, 0.045, 0.05)), _at(c + Vector3(sx * 0.09, 0.08, 0.11), Vector3(0, 0, -sx * 0.4)))
		_add(b, eye, _ball(0.035, 0.06, 6, 3), _at(c + Vector3(sx * 0.09, 0.02, 0.12)))
		_limb(b, bone, c + Vector3(sx * 0.07, -0.12, 0.11), c + Vector3(sx * 0.075, -0.04, 0.12), 0.022, 0.0, 4)
	_add(b, ink, Toon.box(Vector3(0.22, 0.05, 0.04)), _at(c + Vector3(0, -0.13, 0.11)))
	_flush(b, n, s > 0.8)


## Barque oshiokuri (proue effilée relevée vers +X local) et rameurs courbés.
static func _boat(root: Node3D, pos: Vector3, s: float, rot_y: float, rowers: int) -> void:
	var n := _node(root, pos, "Oshiokuri", rot_y, s)
	var b := {}
	var hull := _toon(HULL)
	var rim := _toon(Color("#2A221C"))
	var crew := _toon(CREW, true, 0.02)
	var skin := _toon(Toon.SKIN, true, 0.02)
	_add(b, hull, Toon.box(Vector3(3.0, 0.28, 0.62)), _at(Vector3(0, 0.1, 0)))
	for sz: float in [-1.0, 1.0]:
		_add(b, rim, Toon.box(Vector3(3.0, 0.06, 0.08)), _at(Vector3(0, 0.27, sz * 0.3)))
	_limb(b, hull, Vector3(1.45, 0.1, 0), Vector3(2.3, 0.55, 0), 0.31, 0.03, 4)
	_add(b, hull, Toon.box(Vector3(0.3, 0.36, 0.62)), _at(Vector3(-1.55, 0.16, 0)))
	for k in rowers:
		var x := -1.0 + k * (2.0 / maxf(float(rowers - 1), 1.0))
		_limb(b, crew, Vector3(x, 0.25, 0), Vector3(x + 0.18, 0.62, 0), 0.11, 0.08, 6)
		_add(b, skin, _ball(0.08, 0.16, 6, 3), _at(Vector3(x + 0.24, 0.7, 0)))
		_limb(b, rim, Vector3(x + 0.1, 0.5, 0.25), Vector3(x - 0.5, -0.1, 0.9), 0.025, 0.025, 4)
	_flush(b, n, true)


## Pinceau géant planté pointe dans l'encre (`tilt` = inclinaison du nœud).
static func _brush(root: Node3D, pos: Vector3, s: float, tilt: Vector3) -> void:
	var n := _node(root, pos, "Brush", 0.0, s)
	n.rotation = tilt
	var b := {}
	var hair := _toon(Toon.SUMI, true, 0.02)
	var lac := _toon(Color("#2A1F1A"))
	var cane := _toon(Color("#B89B5E"))
	var knot := _toon(Color("#8A7040"), false)
	_add(b, hair, _ball(0.17, 0.5, 8, 4), _at(Vector3(0, 0.05, 0)))
	_limb(b, hair, Vector3(0, -0.1, 0), Vector3(0, -0.5, 0), 0.15, 0.0, 7)
	_add(b, lac, Toon.cyl(0.1, 0.14, 0.26, 8), _at(Vector3(0, 0.38, 0)))
	_add(b, cane, Toon.cyl(0.075, 0.085, 2.6, 8), _at(Vector3(0, 1.8, 0)))
	for k in 3:
		_add(b, knot, Toon.cyl(0.088, 0.088, 0.035, 8), _at(Vector3(0, 0.95 + k * 0.75, 0)))
	_add(b, lac, Toon.cyl(0.09, 0.09, 0.1, 8), _at(Vector3(0, 3.13, 0)))
	var loop := TorusMesh.new()
	loop.inner_radius = 0.04
	loop.outer_radius = 0.065
	loop.rings = 10
	loop.ring_segments = 4
	_add(b, _toon(Toon.GOLD, false), loop, _at(Vector3(0, 3.24, 0), Vector3(PI * 0.5, 0, 0)))
	_flush(b, n, s > 0.7)


## Sceau de peintre : cylindre rouge cerclé d'or, poignée en boule.
static func _seal(root: Node3D, pos: Vector3, s: float, rot_y: float) -> void:
	var n := _node(root, pos, "Seal", rot_y, s)
	var b := {}
	var red := _toon(SEAL_RED)
	var knob := _toon(Color("#E9DFC9"), true, 0.02)
	_add(b, red, Toon.cyl(0.3, 0.32, 0.6, 12), _at(Vector3(0, 0.3, 0)))
	_add(b, _toon(Toon.GOLD, false), Toon.cyl(0.33, 0.33, 0.06, 12), _at(Vector3(0, 0.5, 0)))
	_add(b, knob, Toon.cyl(0.1, 0.16, 0.12, 8), _at(Vector3(0, 0.66, 0)))
	_add(b, knob, _ball(0.15, 0.24, 8, 4), _at(Vector3(0, 0.82, 0)))
	# empreinte du sceau sur le papier, à côté
	_add(b, red, Toon.box(Vector3(0.45, 0.01, 0.45)), _at(Vector3(0.65, 0.0, 0.1), Vector3(0, 0.2, 0)))
	_add(b, _toon(Toon.WASHI, false), Toon.box(Vector3(0.3, 0.012, 0.04)), _at(Vector3(0.65, 0.002, 0.04), Vector3(0, 0.2, 0)))
	_add(b, _toon(Toon.WASHI, false), Toon.box(Vector3(0.04, 0.012, 0.3)), _at(Vector3(0.7, 0.002, 0.1), Vector3(0, 0.2, 0)))
	_flush(b, n, s > 0.7)


## Feuilles de papier déchiré posées sur l'encre (quelques traits d'encre dessus).
static func _papers(root: Node3D, p: Vector2, rng: RandomNumberGenerator, count: int, y: float, spread: float) -> void:
	var b := {}
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
	_flush(b, root, false)


## Feuille déchirée : rectangle principal et coin arraché décalé.
static func _sheet_into(b: Dictionary, m: Material, xf: Transform3D, w: float, l: float) -> void:
	_add(b, m, Toon.box(Vector3(w, 0.012, l)), xf)
	_add(b, m, Toon.box(Vector3(w * 0.45, 0.012, l * 0.35)), xf * _at(Vector3(w * 0.4, 0.004, l * 0.45), Vector3(0, 0.5, 0)))
	_add(b, m, Toon.box(Vector3(w * 0.3, 0.012, l * 0.25)), xf * _at(Vector3(-w * 0.45, -0.003, -l * 0.42), Vector3(0, -0.4, 0)))


# ------------------------------------------------------------------ particules d'ambiance

## Particules en boucle sur PART_AREA, propres à chaque monde.
static func build_particles(world_id: int, parent: Node3D) -> void:
	var area := PART_AREA
	var ctr := area.get_center()
	match clampi(world_id, 1, 5):
		1:
			# pétales de cerisier
			Decor.petals(parent, area)
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


static func _sphere_mesh(key: String, r: float, additive: bool) -> SphereMesh:
	if _meshes.has(key):
		var cached: SphereMesh = _meshes[key]
		return cached
	var m := _ball(r, r * 2.0, 6, 3)
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
