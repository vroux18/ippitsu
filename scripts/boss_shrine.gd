## Sanctuaires des arènes de gardien (combat 8, étape 4) et de boss (combat 15, étape 8).
##
## L'arène reste la même (plateau HALF, sol du monde, torii de sortie) ; ce module l'habille en parvis :
##  - au sol, un motif propre au monde et au combat (ensō à l'encre, cercle de dalles, sable ratissé,
##    tawara du dohyō…), bordure de pierre à l'intérieur du cadre. Un seul maillage à couleurs de sommets,
##    posé à fleur de dalles, sous les annonces d'attaque. Contraste moyen : jamais de vermillon, de sumi pur
##    ni de blanc au sol, rien de plus contrasté que le trait du héros et les disques d'annonce ;
##  - autour, hors du cadre jouable : terrasses de pierre dans le vide portant des rangées de tōrō allumés
##    (une rangée pour un gardien, deux pour un boss), nobori, braseros, komainu, arbre sacré ceint de corde,
##    et au nord, derrière le torii de sortie, le sanctuaire : haiden (gardien) ou honden à chigi et katsuogi
##    (boss), précédé d'un escalier de pierre ; pour les boss qui plongent (Uwabami, Bakekujira, Kuro-Nami,
##    Umibōzu, Ryūjin), l'eau du nord reste libre et le sanctuaire recule derrière un grand torii dans l'eau ;
##  - l'ambiance : une seule OmniLight3D (aucune en Toon.lite), quelques particules du monde.
## Coût visé : moins de 15 000 triangles et une trentaine de draw calls par arène (lots par matériau,
## tōrō en MultiMesh), moins en Toon.lite (pas de seconde rangée de détails, pas de lumière).
extends RefCounted

const Toon = preload("res://scripts/toon.gd")
const Decor = preload("res://scripts/decor.gd")
const Worlds = preload("res://scripts/worlds.gd")

const HALF := Vector2(4.6, 8.6)  # cadre jouable (arena.HALF)
const TERR_IN := 5.0  # bord intérieur des terrasses : 0,4 m de vide entre le parvis et elles
const TERR_Y := -0.18  # dessus des terrasses, plus bas que le parvis (on ne les prend pas pour du sol)
const VOID_Y := -0.55  # plan du vide (Worlds.VOID_Y)
const MOTIF_C := Vector2(0.0, -0.8)  # centre du motif au sol (un peu au nord : les boss tiennent le fond)
const FLOOR_K := 0.9  # le motif à couleurs de sommets ressort plus clair que les tuiles à albédo égal

static var _kits := {}  # maillages d'instances (tōrō) par monde
static var _floor_mat: StandardMaterial3D = null
static var _k := FLOOR_K  # facteur du motif du sol en cours (voir _floor)


# ------------------------------------------------------------------ palettes (design/PALETTES.md)

## Palette du sanctuaire d'un monde. Le vermillon reste aux annonces : laques sombres (braise, sumi,
## indigo), or terne et flammes ambre-or ; les tōrō du grand fond et de Yomi brûlent froid.
static func pal(wid: int) -> Dictionary:
	match wid:
		2:
			return {
				"stone": Color("#6E746A"), "stone_dk": Color("#4E5650"), "lacq": Color("#6E2A24"), "lacq_dk": Color("#1E2420"),
				"wood": Color("#4A3A2E"), "wall": Color("#E6DCC0"), "roof": Color("#2A3038"), "ridge": Color("#1B1E24"), "cap": Color(0, 0, 0, 0),
				"trim": Color("#A89A62"), "flame": Color("#F1E3A6"), "light": Color(1.0, 0.86, 0.55),
				"band_k": 0.14, "ink_k": 0.34, "ink2_k": 0.16,
				"leaf": [Color("#3E5A40"), Color("#4E6E48"), Color("#5E7F4A")], "bark": Color("#3A3028"),
				"motes": "fox", "motif": "web",
			}
		3:
			return {
				"stone": Color("#8F8E92"), "stone_dk": Color("#6E6E78"), "lacq": Color("#4A3A30"), "lacq_dk": Color("#2E3446"),
				"wood": Color("#5A4A3A"), "wall": Color("#EDE7DA"), "roof": Color("#3A3F4E"), "ridge": Color("#262A36"), "cap": Color("#E8EDF2"),
				"trim": Color("#B8A878"), "flame": Color("#F6D58A"), "light": Color(1.0, 0.86, 0.62),
				"band_k": 0.1, "ink_k": 0.15, "ink2_k": -0.07,
				"leaf": [Color("#2F4A3C"), Color("#3E5A4A"), Color("#E8EDF2")], "bark": Color("#4A3A30"),
				"motes": "snow", "motif": "rake",
			}
		4:
			return {
				"stone": Color("#4A4442"), "stone_dk": Color("#2E2A2A"), "lacq": Color("#2A2226"), "lacq_dk": Color("#141215"),
				"wood": Color("#3A2E28"), "wall": Color("#3B3A3E"), "roof": Color("#262226"), "ridge": Color("#141215"), "cap": Color(0, 0, 0, 0),
				"trim": Color("#C49A45"), "flame": Color("#D9A64A"), "light": Color(1.0, 0.72, 0.42),
				"band_k": 0.12, "ink_k": 0.2, "ink2_k": 0.0, "straw": Color("#8A7A58"),
				"leaf": [], "bark": Color("#221C1C"),
				"motes": "ember", "motif": "dohyo",
			}
		5:
			return {
				"stone": Color("#8E887C"), "stone_dk": Color("#5A544C"), "lacq": Color("#2A2830"), "lacq_dk": Color("#1B1A1E"),
				"wood": Color("#44403A"), "wall": Color("#F1E8D6"), "roof": Color("#34323A"), "ridge": Color("#1B1A1E"), "cap": Color(0, 0, 0, 0),
				"trim": Color("#9E3028"), "flame": Color("#F1E3C0"), "light": Color(1.0, 0.9, 0.72),
				"band_k": 0.08, "ink_k": 0.42, "ink2_k": -0.28,
				"leaf": [Color("#3A3A3C"), Color("#4E4E50"), Color("#606062")], "bark": Color("#2A2830"),
				"motes": "paper", "motif": "enso",
			}
		6:
			return {
				"stone": Color("#6A5E66"), "stone_dk": Color("#4A3E48"), "lacq": Color("#8E2A1E"), "lacq_dk": Color("#2A2028"),
				"wood": Color("#5E3A28"), "wall": Color("#E6D8C4"), "roof": Color("#2C2A36"), "ridge": Color("#14121A"), "cap": Color(0, 0, 0, 0),
				"trim": Color("#B08A4A"), "flame": Color("#F2C288"), "light": Color(1.0, 0.76, 0.5),
				"band_k": 0.12, "ink_k": 0.3, "ink2_k": 0.1,
				"leaf": [Color("#222A3A"), Color("#2C3A4C"), Color("#36465A")], "bark": Color("#3A2A24"),
				"motes": "needles", "motif": "kikko",
			}
		7:
			return {
				"stone": Color("#4E5A6E"), "stone_dk": Color("#2E3A5A"), "lacq": Color("#4E2228"), "lacq_dk": Color("#2A3052"),
				"wood": Color("#6E2A30"), "wall": Color("#E7D9C8"), "roof": Color("#2E4A66"), "ridge": Color("#1E2E5A"), "cap": Color(0, 0, 0, 0),
				"trim": Color("#C49A45"), "flame": Color("#BFE0FF"), "light": Color(0.62, 0.82, 1.0),
				"band_k": 0.12, "ink_k": 0.2, "ink2_k": 0.14,
				"leaf": [Color("#C86E7E"), Color("#D9A078"), Color("#9A5C86")], "bark": Color("#7A4A50"),
				"motes": "bubbles", "motif": "ripple", "deck": Color("#8A8270"),
			}
		8:
			return {
				"stone": Color("#6E6A70"), "stone_dk": Color("#4A4650"), "lacq": Color("#2A2430"), "lacq_dk": Color("#0E0C10"),
				"wood": Color("#3A363E"), "wall": Color("#D8D2C4"), "roof": Color("#2A2630"), "ridge": Color("#0E0C10"), "cap": Color(0, 0, 0, 0),
				"trim": Color("#8A7EA8"), "flame": Color("#D9D0E6"), "light": Color(0.78, 0.72, 1.0),
				"band_k": 0.14, "ink_k": 0.36, "ink2_k": 0.12,
				"leaf": [], "bark": Color("#B8B0A4"),
				"motes": "souls", "motif": "broken",
			}
		_:
			return {
				"stone": Color("#8C8578"), "stone_dk": Color("#5E5850"), "lacq": Color("#5A2E2A"), "lacq_dk": Color("#1B1A1E"),
				"wood": Color("#8E6B3E"), "wall": Color("#E8DCC0"), "roof": Color("#3A3F4E"), "ridge": Color("#262A36"), "cap": Color(0, 0, 0, 0),
				"trim": Color("#B89A5A"), "flame": Color("#F2D7A0"), "light": Color(1.0, 0.84, 0.6),
				"band_k": 0.14, "ink_k": 0.32, "ink2_k": -0.2,
				"leaf": [Color("#2F4A3C"), Color("#3E5A4A"), Color("#4E6E5B")], "bark": Color("#5A4434"),
				"motes": "petals", "motif": "tomoe", "deck": Color("#7A6448"),
			}


## Vrai si le nord de l'arène doit rester de l'eau libre : le boss en surgit (serpent, baleine, vague noire,
## moine et roi dragon des abysses).
static func open_north(wid: int, boss: bool) -> bool:
	return (wid == 1 and boss) or wid == 5 or wid == 7


# ------------------------------------------------------------------ construction

## Habille l'arène : `boss` faux = gardien (sanctuaire secondaire), vrai = boss (sanctuaire principal).
## Renvoie la racine (déjà accrochée à `parent`).
static func build(wid: int, boss: bool, parent: Node3D, rng_seed: int) -> Node3D:
	var root := Node3D.new()
	root.name = "BossShrine"
	parent.add_child(root)
	var p := pal(wid)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(rng_seed * 131 + wid * 7 + (1 if boss else 0))
	var ctx := {"vc": {}, "g": {}, "mm": {}, "root": root, "p": p, "wid": wid, "boss": boss, "rng": rng, "lights": 0}
	_floor(ctx)
	_terraces(ctx)
	_accents(ctx)
	_south_steps(ctx)
	if open_north(wid, boss):
		_north_water(ctx)
	else:
		_north_court(ctx)
	_flush_vc(ctx["vc"], root)
	Worlds._flush(ctx["g"], root, false)
	Worlds._flush_mm(ctx["mm"], root)
	_ambience(ctx)
	return root


## Préchauffage (main._warmup) : une pièce de chaque matière propre aux sanctuaires (motif du sol, lots à
## couleurs de sommets avec et sans contour, halo additif, tōrō en MultiMesh), pour que leurs shaders soient
## compilés avant la première arène de gardien. Rien d'autre : quelques triangles.
static func warm(parent: Node3D) -> void:
	var ctx := {"vc": {}, "g": {}, "mm": {}, "root": parent, "p": pal(1), "wid": 1}
	_put(ctx, _paint(Color.GRAY, true), Worlds._box(Vector3.ONE * 0.2), Transform3D.IDENTITY)
	_put(ctx, _paint(Color.GRAY, false), Worlds._box(Vector3.ONE * 0.2), Worlds._at(Vector3(0.3, 0, 0)))
	Worlds._inst(ctx, "toro", _lantern_mesh(1), null, Worlds._at(Vector3(0.6, 0, 0)))
	_halo(ctx, Vector3(0.9, 0, 0), 0.3)
	_flush_vc(ctx["vc"], parent)
	Worlds._flush(ctx["g"], parent, false)
	Worlds._flush_mm(ctx["mm"], parent)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	_quad(st, Vector2(-0.2, -0.2), Vector2(0.2, 0.2), Color.GRAY, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _fmat()
	mi.position = Vector3(1.2, 0, 0)
	parent.add_child(mi)


# ------------------------------------------------------------------ sol : parvis

## Matière du motif : toon sans contour ni reflet (comme les tuiles), couleurs de sommets.
static func _fmat() -> StandardMaterial3D:
	if _floor_mat != null:
		return _floor_mat
	# (même éclairage que le sol ; le shader du sol assombrit ses tuiles (joints, usure, variation) : les
	# couleurs du motif sont multipliées par _k dans _v pour rester à la même valeur)
	var m := Toon.mat(Color.WHITE, false)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.rim_enabled = false
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_floor_mat = m
	return m


## Hauteur du motif : juste au-dessus des tuiles les plus hautes du style de sol, sous les annonces (≥ 0,02).
static func _floor_y(wid: int) -> float:
	match String(Worlds.world(wid).ground_style):
		"planks":
			return 0.009
		"stones", "basalt":
			return 0.0125
	return 0.005


static func _floor(ctx: Dictionary) -> void:
	var wid: int = ctx["wid"]
	var boss: bool = ctx["boss"]
	var p: Dictionary = ctx["p"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var y := _floor_y(wid)
	_k = 1.0 if String(Worlds.world(wid).ground_style) == "snow" else FLOOR_K
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	# teintes du motif tirées du sol du monde : bordure et trait sombre assombris, trait clair éclairci
	# (ink2_k < 0 : assombri) ; contraste moyen, la valeur reste voisine de celle des dalles
	var g: Color = Worlds.world(wid).ground[0]
	var band: Color = g.darkened(float(p["band_k"]))
	var ink: Color = g.darkened(float(p["ink_k"]))
	var k2 := float(p["ink2_k"])
	var ink2: Color = g.lightened(k2) if k2 >= 0.0 else g.darkened(-k2)
	# bordure : bande de pierre le long du cadre, dalles d'angle carrées
	var inset := 0.16
	var bw := 0.3
	var r := Rect2(-HALF.x + inset, -HALF.y + inset, (HALF.x - inset) * 2.0, (HALF.y - inset) * 2.0)
	_band_rect(st, r, bw, band, y)
	for cx: float in [r.position.x, r.end.x - 0.56]:
		for cz: float in [r.position.y, r.end.y - 0.56]:
			_quad(st, Vector2(cx, cz), Vector2(cx + 0.56, cz + 0.56), band.darkened(0.12), y + 0.001)
	# filet intérieur (boss : double)
	_band_rect(st, r.grow(-bw - 0.18), 0.05, band, y)
	if boss:
		_band_rect(st, r.grow(-bw - 0.36), 0.05, band, y)
	var c := MOTIF_C
	# sandō : allée de dalles plus sombre qui mène du bord sud au motif, puis du motif aux marches du nord
	var sr := 3.95
	var zs0 := r.position.y + bw
	var zs1 := r.end.y - bw
	for seg: Vector2 in [Vector2(zs0, c.y - sr), Vector2(c.y + sr, zs1)]:
		if seg.y - seg.x < 0.3:
			continue
		_quad(st, Vector2(-0.68, seg.x), Vector2(0.68, seg.y), g.darkened(float(p["band_k"]) * 0.55), y + 0.0005)
		for sx: float in [-1.0, 1.0]:
			_quad(st, Vector2(sx * 0.68 - 0.04, seg.x), Vector2(sx * 0.68 + 0.04, seg.y), band, y + 0.001)
		var zj := seg.x + 0.9
		while zj < seg.y - 0.2:
			_quad(st, Vector2(-0.64, zj - 0.02), Vector2(0.64, zj + 0.02), band, y + 0.001)
			zj += 0.9
	match String(p["motif"]):
		"tomoe":
			# Grande Vague : ensō de laque humide ; au boss, mitsudomoe de Hachiman au cœur et vagues aux angles
			_enso(st, c, 3.3, 0.42, ink, y + 0.002, rng, 0.55)
			if boss:
				_tomoe3(st, c, 1.15, ink2, y + 0.003)
				_ring(st, c, 3.95, 0.06, ink2, y + 0.002)
				for sz: float in [-1.0, 1.0]:
					_seigaiha(st, Vector2(0, c.y + sz * 5.6), 1.3, ink2, y + 0.002)
			else:
				_ring(st, c, 1.0, 0.07, ink2, y + 0.003)
		"web":
			# Tanabata : cercle de dalles claires ; gardien (Tsuchigumo) : toile fine ; boss (Kyūbi) : neuf queues
			_slab_ring(st, c, 3.1, 3.7, 24, ink2, ink2.darkened(0.08), y + 0.002)
			if boss:
				_slab_ring(st, c, 1.0, 1.35, 12, ink2, ink2.darkened(0.08), y + 0.002)
				for k in 9:
					var a0 := TAU * k / 9.0 + 0.2
					_tail(st, c, a0, 1.45, 3.0, 0.42, ink, y + 0.003)
				_seven_stars(st, Vector2(0, c.y + 5.8), 0.12, ink2, y + 0.002)
			else:
				for k in 8:
					var a := TAU * k / 8.0 + PI / 8.0
					_seg(st, c + Vector2.from_angle(a) * 0.5, c + Vector2.from_angle(a) * 3.05, 0.045, ink, y + 0.003)
				for rr: float in [1.0, 1.75, 2.45]:
					_poly_ring(st, c, rr, 8, PI / 8.0, 0.04, ink, y + 0.003)
		"rake":
			# Cent Contes : neige ratissée en karesansui autour d'une pierre-cercle ; boss : plus d'ondes et
			# rayures droites jusqu'aux bords
			_ring(st, c, 0.95, 0.32, g.darkened(0.22), y + 0.002)
			var n := 7 if boss else 5
			for i in n:
				_ring(st, c, 1.45 + 0.36 * i, 0.07, ink, y + 0.002)
			if boss:
				var r_out := 1.45 + 0.36 * n
				var xz := -HALF.y + inset + bw + 0.5
				while xz < HALF.y - inset - bw - 0.3:
					var dz := xz - c.y
					if absf(dz) > r_out + 0.2:
						_seg(st, Vector2(-HALF.x + inset + bw + 0.4, xz), Vector2(HALF.x - inset - bw - 0.4, xz), 0.06, ink2, y + 0.001)
					xz += 0.36
		"dohyo":
			# Fuji Rouge : gardien (Ibaraki) : dohyō de tawara ; boss (Daidarabotchi) : mandala de dalles cerclé de fer
			if boss:
				_slab_ring(st, c, 3.2, 3.9, 20, ink, g.darkened(0.1), y + 0.002)
				_slab_ring(st, c, 1.9, 2.5, 14, g.darkened(0.1), ink, y + 0.002)
				_ring(st, c, 1.2, 0.1, p["straw"], y + 0.003)
				for k in 8:
					var a := TAU * k / 8.0
					_seg(st, c + Vector2.from_angle(a) * 2.55, c + Vector2.from_angle(a) * 3.15, 0.08, p["straw"], y + 0.003)
			else:
				_tawara(st, c, 3.0, p["straw"], y + 0.002)
				_ring(st, c, 2.55, 0.05, ink, y + 0.002)
				for sx: float in [-1.0, 1.0]:
					_quad(st, Vector2(c.x + sx * 0.7 - 0.06, c.y - 0.45), Vector2(c.x + sx * 0.7 + 0.06, c.y + 0.45), p["straw"], y + 0.003)
		"enso":
			# Trente-six Vues : ensō géant à l'encre lavée ; boss : second cercle et vagues de seigaiha
			_enso(st, c, 3.4, 0.62, ink, y + 0.002, rng, 0.75)
			if boss:
				_enso(st, c, 1.55, 0.3, ink2, y + 0.003, rng, 1.6)
				for sz: float in [-1.0, 1.0]:
					_seigaiha(st, Vector2(0, c.y + sz * 5.7), 1.4, ink2, y + 0.002)
		"kikko":
			# Kurama : carapace de tortue (kikkō) de dalles ; boss (Sōjōbō) : douze rayons du dojo
			_poly_ring(st, c, 3.6, 6, PI / 6.0, 0.22, ink, y + 0.002)
			_poly_ring(st, c, 2.2, 6, PI / 6.0, 0.08, ink, y + 0.002)
			if boss:
				for k in 12:
					var a := TAU * k / 12.0
					_seg(st, c + Vector2.from_angle(a) * 0.75, c + Vector2.from_angle(a) * 3.25, 0.05, ink, y + 0.003)
				_ring(st, c, 0.75, 0.12, ink2, y + 0.003)
				_poly_ring(st, c, 4.3, 6, PI / 6.0, 0.06, ink, y + 0.002)
			else:
				for k in 6:
					var a := TAU * k / 6.0 + PI / 6.0
					_seg(st, c + Vector2.from_angle(a) * 2.2, c + Vector2.from_angle(a) * 3.55, 0.08, ink, y + 0.003)
		"ripple":
			# Ryūgū : cercle de sable nacré ratissé incrusté dans le bois flotté ; boss : perle du dragon au cœur
			_disc(st, c, 3.2, ink2, y + 0.002)
			for i in 6:
				_ring(st, c, 0.85 + 0.38 * i, 0.06, ink, y + 0.003)
			_ring(st, c, 3.2, 0.12, ink.darkened(0.12), y + 0.003)
			if boss:
				_tomoe3(st, c, 0.7, ink.darkened(0.12), y + 0.004)
				_ring(st, c, 3.75, 0.07, ink, y + 0.002)
		"broken":
			# Yomi : ensō brisé de cendre ; boss : cercles concentriques et âmes éteintes (lilas terne)
			_enso(st, c, 3.2, 0.4, ink, y + 0.002, rng, 1.1)
			_enso(st, c, 2.2, 0.16, ink, y + 0.002, rng, 2.4)
			if boss:
				_ring(st, c, 3.9, 0.05, ink2, y + 0.002)
				_ring(st, c, 1.2, 0.05, ink2, y + 0.002)
				for k in 12:
					var a := TAU * k / 12.0
					_disc(st, c + Vector2.from_angle(a) * 3.9, 0.12, Color("#7A7090"), y + 0.003)
	var mi := MeshInstance3D.new()
	mi.name = "Parvis"
	mi.mesh = st.commit()
	mi.material_override = _fmat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var root: Node3D = ctx["root"]
	root.add_child(mi)


# --- tracés plats au sol (triangles, couleur de sommet ; y = hauteur)

static func _v(st: SurfaceTool, p: Vector2, col: Color, y: float) -> void:
	st.set_color(Color(col.r * _k, col.g * _k, col.b * _k))
	st.add_vertex(Vector3(p.x, y, p.y))


static func _quad(st: SurfaceTool, a: Vector2, b: Vector2, col: Color, y: float) -> void:
	_quad4(st, Vector2(a.x, a.y), Vector2(b.x, a.y), Vector2(b.x, b.y), Vector2(a.x, b.y), col, y)


## Quadrilatère a b c d (dans l'ordre, vu de dessus) : deux triangles tournés vers le haut.
static func _quad4(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color, y: float) -> void:
	# sens : la face est vue d'en haut (normale +Y) quel que soit l'ordre donné
	var up := (b - a).cross(c - a) > 0.0
	if up:
		_v(st, a, col, y)
		_v(st, b, col, y)
		_v(st, c, col, y)
		_v(st, a, col, y)
		_v(st, c, col, y)
		_v(st, d, col, y)
	else:
		_v(st, a, col, y)
		_v(st, c, col, y)
		_v(st, b, col, y)
		_v(st, a, col, y)
		_v(st, d, col, y)
		_v(st, c, col, y)


## Bande de largeur `w` à l'intérieur du rectangle `r`.
static func _band_rect(st: SurfaceTool, r: Rect2, w: float, col: Color, y: float) -> void:
	_quad(st, r.position, Vector2(r.end.x, r.position.y + w), col, y)
	_quad(st, Vector2(r.position.x, r.end.y - w), r.end, col, y)
	_quad(st, Vector2(r.position.x, r.position.y + w), Vector2(r.position.x + w, r.end.y - w), col, y)
	_quad(st, Vector2(r.end.x - w, r.position.y + w), Vector2(r.end.x, r.end.y - w), col, y)


## Trait droit de a à b, largeur w.
static func _seg(st: SurfaceTool, a: Vector2, b: Vector2, w: float, col: Color, y: float) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * w * 0.5
	_quad4(st, a + n, b + n, b - n, a - n, col, y)


## Ruban le long d'une polyligne (largeur par point).
static func _ribbon(st: SurfaceTool, pts: PackedVector2Array, ws: PackedFloat32Array, col: Color, y: float) -> void:
	var n := pts.size()
	if n < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var t := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		t = t.normalized()
		var nn := Vector2(-t.y, t.x) * ws[i] * 0.5
		left.append(pts[i] + nn)
		right.append(pts[i] - nn)
	for i in n - 1:
		_quad4(st, left[i], left[i + 1], right[i + 1], right[i], col, y)


## Anneau plein de rayon moyen r, largeur w.
static func _ring(st: SurfaceTool, c: Vector2, r: float, w: float, col: Color, y: float) -> void:
	var seg := clampi(int(r * 14.0), 24, 72)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var u0 := Vector2.from_angle(a0)
		var u1 := Vector2.from_angle(a1)
		_quad4(st, c + u0 * (r - w * 0.5), c + u1 * (r - w * 0.5), c + u1 * (r + w * 0.5), c + u0 * (r + w * 0.5), col, y)


static func _disc(st: SurfaceTool, c: Vector2, r: float, col: Color, y: float) -> void:
	var seg := clampi(int(r * 12.0), 10, 48)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		_v(st, c, col, y)
		_v(st, c + Vector2.from_angle(a0) * r, col, y)
		_v(st, c + Vector2.from_angle(a1) * r, col, y)


## Polygone régulier évidé (n côtés, rotation a0) : côtés de largeur w.
static func _poly_ring(st: SurfaceTool, c: Vector2, r: float, n: int, a0: float, w: float, col: Color, y: float) -> void:
	for i in n:
		var p0 := c + Vector2.from_angle(a0 + TAU * i / n) * r
		var p1 := c + Vector2.from_angle(a0 + TAU * (i + 1) / n) * r
		var p0i := c + Vector2.from_angle(a0 + TAU * i / n) * (r - w)
		var p1i := c + Vector2.from_angle(a0 + TAU * (i + 1) / n) * (r - w)
		_quad4(st, p0i, p1i, p1, p0, col, y)


## Cercle de n dalles entre r0 et r1 (joints de 4 cm), deux teintes alternées.
static func _slab_ring(st: SurfaceTool, c: Vector2, r0: float, r1: float, n: int, col_a: Color, col_b: Color, y: float) -> void:
	var gap := 0.04
	for i in n:
		var a0 := TAU * i / n + gap / r0
		var a1 := TAU * (i + 1) / n - gap / r0
		var col := col_a if i % 2 == 0 else col_b
		var am := (a0 + a1) * 0.5
		for h in 2:
			var b0 := a0 if h == 0 else am
			var b1 := am if h == 0 else a1
			_quad4(st, c + Vector2.from_angle(b0) * r0, c + Vector2.from_angle(b1) * r0, c + Vector2.from_angle(b1) * r1, c + Vector2.from_angle(b0) * r1, col, y)


## Ensō au pinceau : plusieurs poils (rubans fins) qui tournent de a0 à a0 + arc, attaque appuyée, queue
## sèche (les poils extérieurs s'arrêtent plus tôt). `dry` : longueur de la queue effilochée (radians).
static func _enso(st: SurfaceTool, c: Vector2, r: float, w: float, col: Color, y: float, rng: RandomNumberGenerator, dry: float) -> void:
	var a_start := PI * 0.62 + rng.randf_range(-0.15, 0.15)
	var arc := TAU * 0.9
	var hairs := 6
	for h in hairs:
		var off := (float(h) / (hairs - 1) - 0.5) * w * 0.86
		var end_cut := dry * absf(float(h) / (hairs - 1) - 0.5) * 2.0 * rng.randf_range(0.6, 1.0)
		var a_end := arc - end_cut
		var nseg := int(a_end * r * 2.6)
		var pts := PackedVector2Array()
		var ws := PackedFloat32Array()
		var hw := w / hairs * 1.35
		for i in nseg + 1:
			var t := float(i) / nseg
			var a := a_start + a_end * t
			# le cercle n'est pas parfait : léger souffle du rayon
			var rr := r + off + sin(a * 2.0 + 0.7) * 0.06 + sin(a * 5.0) * 0.015
			pts.append(c + Vector2.from_angle(-a) * rr)
			var k := smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.82, 1.0, t) * 0.75)
			ws.append(hw * maxf(k, 0.15))
		_ribbon(st, pts, ws, col, y)
	# goutte d'attaque, plus sombre
	_disc(st, c + Vector2.from_angle(-a_start) * r, w * 0.55, col.darkened(0.06), y + 0.0005)


## Mitsudomoe : trois virgules qui tournent autour du centre.
static func _tomoe3(st: SurfaceTool, c: Vector2, r: float, col: Color, y: float) -> void:
	for k in 3:
		var a0 := TAU * k / 3.0
		var head := c + Vector2.from_angle(a0) * r * 0.45
		_disc(st, head, r * 0.36, col, y)
		var pts := PackedVector2Array()
		var ws := PackedFloat32Array()
		var n := 16
		for i in n + 1:
			var t := float(i) / n
			var a := a0 + t * 2.1
			var rr := lerpf(r * 0.45, r * 0.98, t)
			pts.append(c + Vector2.from_angle(a) * rr - Vector2.from_angle(a0 + PI * 0.5) * 0.0)
			ws.append(r * 0.7 * (1.0 - t) + 0.02)
		_ribbon(st, pts, ws, col, y)


## Queue de renard : trait courbe qui part de r0 et s'effile à r1 en tournant.
static func _tail(st: SurfaceTool, c: Vector2, a0: float, r0: float, r1: float, w: float, col: Color, y: float) -> void:
	var pts := PackedVector2Array()
	var ws := PackedFloat32Array()
	var n := 14
	for i in n + 1:
		var t := float(i) / n
		var a := a0 + t * 0.55
		pts.append(c + Vector2.from_angle(a) * lerpf(r0, r1, t))
		ws.append(w * sin(PI * minf(t * 1.6, 1.0) * 0.5 + 0.2) * (1.0 - t * 0.85))
	_ribbon(st, pts, ws, col, y)


## Sept étoiles (la Grande Ourse : le tisserand de Tanabata), reliées d'un fil.
static func _seven_stars(st: SurfaceTool, c: Vector2, r: float, col: Color, y: float) -> void:
	var pts := [Vector2(-1.9, 0.3), Vector2(-1.2, 0.1), Vector2(-0.55, 0.2), Vector2(0.0, 0.0), Vector2(0.2, -0.55), Vector2(1.0, -0.65), Vector2(1.1, 0.0)]
	for i in pts.size():
		var p: Vector2 = c + Vector2(pts[i])
		_disc(st, p, r, col, y)
		if i > 0:
			_seg(st, c + Vector2(pts[i - 1]), p, 0.03, col, y)
	_seg(st, c + Vector2(pts[3]), c + Vector2(pts[6]), 0.03, col, y)


## Écailles de vagues (seigaiha) : rangées d'arcs concentriques centrées en `c`, sur une largeur ±w.
static func _seigaiha(st: SurfaceTool, c: Vector2, w: float, col: Color, y: float) -> void:
	var r := 0.42
	var x := -w
	while x <= w + 0.01:
		for k in 3:
			var rr := r * (1.0 - 0.3 * k)
			var pts := PackedVector2Array()
			var ws := PackedFloat32Array()
			for i in 13:
				var a := PI + PI * float(i) / 12.0
				pts.append(c + Vector2(x, 0.0) + Vector2(cos(a), sin(a) * 0.95) * rr)
				ws.append(0.035)
			_ribbon(st, pts, ws, col, y)
		x += r * 1.6


## Tawara du dohyō : anneau de ballots de paille (segments) liés de cordes sombres, quatre ouvertures.
static func _tawara(st: SurfaceTool, c: Vector2, r: float, col: Color, y: float) -> void:
	var n := 20
	for i in n:
		if i % 5 == 0:
			continue  # tokudawara : les quatre passages
		var a0 := TAU * i / n + 0.02
		var a1 := TAU * (i + 1) / n - 0.02
		_quad4(st, c + Vector2.from_angle(a0) * (r - 0.16), c + Vector2.from_angle(a1) * (r - 0.16), c + Vector2.from_angle(a1) * (r + 0.16), c + Vector2.from_angle(a0) * (r + 0.16), col, y)
		for q: float in [0.3, 0.7]:
			var a := lerpf(a0, a1, q)
			_seg(st, c + Vector2.from_angle(a) * (r - 0.17), c + Vector2.from_angle(a) * (r + 0.17), 0.04, col.darkened(0.35), y + 0.0005)


# ------------------------------------------------------------------ lots à couleurs de sommets
#
# Toute l'architecture (pierre, laque, bois, toits, statues, cordes) part dans deux maillages à couleurs de
# sommets : l'un avec le contour d'encre, l'autre sans (joints, détails fins). Deux matières en tout au lieu
# d'une par teinte : quelques draw calls par arène. Seuls les feux (émissifs) gardent leur matière.

static var _vc_mats := {}


## « Peinture » d'une pièce : [couleur, contour d'encre ?] (les feux passent une Material à la place).
static func _paint(col: Color, outline: bool) -> Array:
	return [col, outline]


## Ajoute `mesh` placé par `xf` au lot de sa peinture (ou au lot de sa matière émissive).
static func _put(ctx: Dictionary, paint: Variant, mesh: Mesh, xf: Transform3D) -> void:
	if paint is Material:
		Worlds._add(ctx["g"], paint, mesh, xf)
		return
	var pa: Array = paint
	var col: Color = pa[0]
	var ol: bool = pa[1]
	var vc: Dictionary = ctx["vc"]
	var key := "%d%s" % [1 if ol else 0, col.to_html(false)]
	if not vc.has(key):
		var st0 := SurfaceTool.new()
		st0.begin(Mesh.PRIMITIVE_TRIANGLES)
		vc[key] = [st0, col, ol]
	var e: Array = vc[key]
	Decor.merge_into(e[0], mesh, xf)


## Segment conique de a (rayon r0) vers c (rayon r1), placé par `xf`.
static func _limb(ctx: Dictionary, paint: Variant, a: Vector3, c: Vector3, r0: float, r1: float, sides := 6, xf := Transform3D.IDENTITY) -> void:
	var d := c - a
	var l := d.length()
	if l < 0.001:
		return
	_put(ctx, paint, Worlds._cyl(r1, r0, l, sides), xf * Transform3D(Worlds._basis_y(d), (a + c) * 0.5))


## Sommets, normales et couleurs des lots d'une famille (contour ou non), mis bout à bout.
static func _vc_arrays(vc: Dictionary, outline: bool) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for k in vc:
		var e: Array = vc[k]
		if bool(e[2]) != outline:
			continue
		var st: SurfaceTool = e[0]
		st.deindex()
		var a := st.commit_to_arrays()
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		if v.is_empty():
			continue
		var c := PackedColorArray()
		c.resize(v.size())
		c.fill(e[1])
		verts.append_array(v)
		norms.append_array(n)
		cols.append_array(c)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	return arr


## Toon à couleurs de sommets, avec ou sans contour d'encre (partagé).
static func _vc_mat(outline: bool) -> StandardMaterial3D:
	var key := 1 if outline else 0
	if _vc_mats.has(key):
		var cached: StandardMaterial3D = _vc_mats[key]
		return cached
	var m := Toon.mat(Color.WHITE, outline, 0.025)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	_vc_mats[key] = m
	return m


static func _flush_vc(vc: Dictionary, root: Node3D) -> void:
	for ol: bool in [true, false]:
		var arr := _vc_arrays(vc, ol)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if v.is_empty():
			continue
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "Sanctuaire" if ol else "Details"
		mi.mesh = mesh
		mi.material_override = _vc_mat(ol)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ol and not Toon.lite else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


## Toit incurvé (Decor.roof_mesh) et son faîtage : poutre ronde et tuiles de bout, ou bouton au sommet.
static func _roof_into(ctx: Dictionary, m: Variant, ridge: Variant, xf: Transform3D, w: float, d: float, h: float, rl := 0.0, lift := 0.35) -> void:
	var t := clampf(minf(w, d) * 0.04, 0.025, 0.12)
	_put(ctx, m, Decor.roof_mesh(w, d, h, rl, lift, t), xf)
	var r := clampf(rl, 0.0, 0.95) * w * 0.5
	var rr := clampf(minf(w, d) * 0.035, 0.02, 0.1)
	if r > 0.05:
		_put(ctx, ridge, Worlds._cyl(rr, rr, r * 2.0 + rr * 2.0, 6), xf * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0, h + rr * 0.4, 0)))
		for sx: float in [-1.0, 1.0]:
			_put(ctx, ridge, Worlds._box(Vector3(rr * 1.6, rr * 3.2, rr * 3.0)), xf * Worlds._at(Vector3(sx * (r + rr), h + rr * 1.2, 0)))
	else:
		_put(ctx, ridge, Worlds._box(Vector3(rr * 2.4, rr * 2.4, rr * 2.4)), xf * Worlds._at(Vector3(0, h + rr, 0)))


## Shimenawa léger : corde de paille qui s'affaisse (segments), nœuds aux bouts, shide en zigzag.
static func _rope(ctx: Dictionary, a: Vector3, b: Vector3) -> void:
	var straw := _paint(Decor.STRAW, true)
	var paper := _paint(Decor.SHIDE, false)
	var d := b - a
	var span := d.length()
	if span < 0.05:
		return
	var r0 := clampf(span * 0.022, 0.045, 0.1)
	var sag := 0.1 * span
	var n := 6
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var q := a + d * t + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		var k := 0.6 + 0.4 * sin(PI * (t - 0.5 / n))
		_limb(ctx, straw, prev, q, r0 * k, r0 * k, 5)
		prev = q
	_put(ctx, straw, Worlds._box(Vector3(r0 * 1.8, r0 * 1.8, r0 * 1.8)), Worlds._at(a))
	_put(ctx, straw, Worlds._box(Vector3(r0 * 1.8, r0 * 1.8, r0 * 1.8)), Worlds._at(b))
	var along := Vector3(d.x, 0, d.z).normalized()
	var ns := 4 if span > 1.6 else 3
	for i in ns:
		var t := (float(i) + 0.5) / ns
		var q := a + d * t + Vector3(0, -sag * 4.0 * t * (1.0 - t) - r0 * 0.6, 0)
		_shide(ctx, paper, q, along)


## Shide : bande de papier pliée en éclair (3 rectangles décalés).
static func _shide(ctx: Dictionary, paint: Variant, top: Vector3, along: Vector3, xf := Transform3D.IDENTITY) -> void:
	var bas := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	for k in 3:
		var dx: float = 0.034 if k % 2 == 1 else 0.0
		var c := top + along * dx - Vector3(0, 0.055 + 0.1 * k, 0)
		_put(ctx, paint, Worlds._box(Vector3(0.075, 0.11, 0.008)), xf * Transform3D(bas, c))


## Nobori : mât, bannière du monde, bandes et traits d'encre (le tissu regarde +Z local).
static func _nobori(ctx: Dictionary, xf: Transform3D, cloth: Color, ink: Color, base_y := 0.0) -> void:
	var pole := _paint(Decor.POLE, true)
	var cm := _paint(cloth, true)
	var im := _paint(ink, false)
	var top := 2.35
	var h := top - base_y
	_put(ctx, pole, Worlds._cyl(0.03, 0.04, h, 5), xf * Worlds._at(Vector3(0, base_y + h * 0.5, 0)))
	_put(ctx, pole, Worlds._box(Vector3(0.48, 0.03, 0.03)), xf * Worlds._at(Vector3(0.22, top - 0.08, 0)))
	var bw := 0.38
	var bh := 1.45
	var bx := 0.25
	var by := top - 0.1 - bh * 0.5
	_put(ctx, cm, Worlds._box(Vector3(bw, bh, 0.012)), xf * Worlds._at(Vector3(bx, by, 0.0)))
	_put(ctx, im, Worlds._box(Vector3(bw + 0.004, 0.12, 0.016)), xf * Worlds._at(Vector3(bx, top - 0.18, 0)))
	_put(ctx, im, Worlds._box(Vector3(bw + 0.004, 0.05, 0.016)), xf * Worlds._at(Vector3(bx, by - bh * 0.5 + 0.06, 0)))
	for k in 2:
		var cy := by + 0.3 - k * 0.42
		_put(ctx, im, Worlds._box(Vector3(0.18 - k * 0.03, 0.04, 0.016)), xf * Worlds._at(Vector3(bx, cy, 0)))
		_put(ctx, im, Worlds._box(Vector3(0.035, 0.2, 0.016)), xf * Worlds._at(Vector3(bx + 0.03 * (2 * k - 1), cy - 0.06, 0)))


# ------------------------------------------------------------------ côtés : terrasses et lanternes

## Terrasses de pierre de part et d'autre (dans le vide), rangées de tōrō, nobori et braseros.
## Rien de haut sous z = 3 : le bas de l'écran montre à peine les bords de l'arène.
static func _terraces(ctx: Dictionary) -> void:
	var boss: bool = ctx["boss"]
	var p: Dictionary = ctx["p"]
	var wid: int = ctx["wid"]
	var stone := _paint(p["stone"], true)
	var stone_dk := _paint(p["stone_dk"], false)
	var top_m := _paint(Color(p["stone"]).darkened(0.22), false)
	var tw := 2.3 if boss else 1.5
	var z0 := -12.5 if boss else -11.0
	var z1 := 2.6 if boss else -0.6
	for s: float in [-1.0, 1.0]:
		var xi := s * TERR_IN
		var xo := s * (TERR_IN + tw)
		var cx := (xi + xo) * 0.5
		var cz := (z0 + z1) * 0.5
		if wid == 1 or wid == 7:
			# galerie de planches sur pieux (Itsukushima ; bois flotté au palais du dragon), garde-corps laqué
			var deck := _paint(p["deck"], true)
			var lacq := _paint(p["lacq"], true)
			_put(ctx, deck, Worlds._box(Vector3(tw, 0.12, z1 - z0)), Worlds._at(Vector3(cx, TERR_Y - 0.06, cz)))
			var zp := z0 + 0.3
			var kp := 0
			while zp < z1:
				if kp % 2 == 0:
					for xx: float in [xi + s * 0.2, xo - s * 0.2]:
						_put(ctx, deck, Worlds._box(Vector3(0.14, TERR_Y - VOID_Y + 0.1, 0.14)), Worlds._at(Vector3(xx, (TERR_Y + VOID_Y) * 0.5 - 0.1, zp)))
				_put(ctx, lacq, Worlds._box(Vector3(0.08, 0.5, 0.08)), Worlds._at(Vector3(xo - s * 0.08, TERR_Y + 0.25, zp)))
				zp += 1.2
				kp += 1
			_put(ctx, lacq, Worlds._box(Vector3(0.07, 0.06, z1 - z0)), Worlds._at(Vector3(xo - s * 0.08, TERR_Y + 0.48, cz)))
			var zj := z0 + 0.8
			while zj < z1 - 0.1:
				_put(ctx, stone_dk, Worlds._box(Vector3(tw - 0.06, 0.012, 0.03)), Worlds._at(Vector3(cx, TERR_Y + 0.006, zj)))
				zj += 0.8
			continue
		# massif de la terrasse (des pieds dans le vide au dessus), dessus dallé plus sombre que ses flancs,
		# margelle côté arène, parapet bas côté extérieur
		var h := TERR_Y - (VOID_Y - 0.2)
		_put(ctx, stone, Worlds._box(Vector3(tw, h, z1 - z0)), Worlds._at(Vector3(cx, TERR_Y - h * 0.5 - 0.02, cz)))
		_put(ctx, top_m, Worlds._box(Vector3(tw - 0.12, 0.03, z1 - z0 - 0.12)), Worlds._at(Vector3(cx, TERR_Y - 0.005, cz)))
		_put(ctx, stone_dk, Worlds._box(Vector3(0.14, 0.05, z1 - z0)), Worlds._at(Vector3(xi + s * 0.07, TERR_Y + 0.02, cz)))
		_put(ctx, stone, Worlds._box(Vector3(0.2, 0.26, z1 - z0)), Worlds._at(Vector3(xo - s * 0.1, TERR_Y + 0.13, cz)))
		# dallage : joints sombres en travers
		var z := z0 + 0.9
		while z < z1 - 0.3:
			_put(ctx, stone_dk, Worlds._box(Vector3(tw - 0.3, 0.012, 0.035)), Worlds._at(Vector3(cx - s * 0.05, TERR_Y + 0.016, z)))
			z += 0.9
	# tōrō : une rangée (gardien) ou deux (boss) le long du bord intérieur
	var rows: Array = [TERR_IN + 0.42]
	if boss and not Toon.lite:
		rows.append(TERR_IN + tw - 0.45)
	# (en quinconce d'une rangée à l'autre, 2,9 m d'écart : serrés, vus d'en haut, ils faisaient une foule grise)
	var lmesh := _lantern_mesh(wid)
	for s: float in [-1.0, 1.0]:
		for ri in rows.size():
			var x: float = s * float(rows[ri])
			var z := z0 + 0.9 + (1.45 if ri == 1 else 0.0)
			while z < z1 - 0.5:
				var sc := 1.1 if ri == 0 else 1.2
				Worlds._inst(ctx, "toro", lmesh, null, Worlds._at(Vector3(x, TERR_Y, z), Vector3(0, PI * 0.5 * s, 0), Vector3.ONE * sc))
				_halo(ctx, Vector3(x, TERR_Y + 0.02, z), 0.75)
				z += 2.9
	# nobori : banderoles du monde, entre lanternes (gardien) ou sur la rangée extérieure (boss)
	var nc: Array = Worlds._nobori_colors(wid)
	var bx := TERR_IN + (tw - 0.3 if boss else tw - 0.35)
	var zb := z0 + 1.8
	while zb < z1 - 0.8:
		for s: float in [-1.0, 1.0]:
			_nobori(ctx, Worlds._at(Vector3(s * bx, TERR_Y, zb + (0.9 if boss else 0.0)), Vector3(0, PI * 0.5 - s * PI * 0.5, 0), Vector3.ONE * 0.85), nc[0], nc[1])
		zb += 7.2 if Toon.lite else 3.6
	# braseros aux deux bouts nord des terrasses, komainu au bout sud (boss : aussi un brasero au sud)
	for s: float in [-1.0, 1.0]:
		_brazier(ctx, Vector3(s * (TERR_IN + tw * 0.5), TERR_Y, z0 + 0.5), 1.0)
		_komainu(ctx, Vector3(s * (TERR_IN + 0.5), TERR_Y, z1 - 0.55), s < 0.0, 0.85)
	if boss:
		# cloche (shōrō) sur une terrasse, arbre sacré sur l'autre
		var side := -1.0 if ctx["rng"].randf() < 0.5 else 1.0
		if not Toon.lite:
			_belfry(ctx, Vector3(side * (TERR_IN + tw * 0.55), TERR_Y, -3.2))
		_sacred_tree(ctx, Vector3(-side * (TERR_IN + tw * 0.55), TERR_Y, -3.4), 1.0)
	else:
		_sacred_tree(ctx, Vector3((TERR_IN + tw * 0.5) * (1.0 if ctx["rng"].randf() < 0.5 else -1.0), TERR_Y, -5.6), 0.85)


## Lisière du monde, derrière les terrasses (x ≈ 7,6, haut de l'écran seulement : plus bas, le cadre ne
## montre pas si loin) : bambous à tanzaku (2), pins enneigés (3), aiguilles de basalte (4), pins d'encre (5),
## cèdres (6), coraux (7), sotoba (8). Le monde 1 a ses galeries sur pieux et le large.
static func _accents(ctx: Dictionary) -> void:
	var wid: int = ctx["wid"]
	var boss: bool = ctx["boss"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var p: Dictionary = ctx["p"]
	if wid == 1:
		return
	var x0 := TERR_IN + (2.3 if boss else 1.5) + 0.45
	var socle := _paint(p["stone_dk"], true)
	for s: float in [-1.0, 1.0]:
		var z := -12.6 + rng.randf_range(0.0, 0.8)
		while z < -1.5:
			var x := s * (x0 + rng.randf_range(0.0, 0.5))
			var at := Vector3(x, VOID_Y, z)
			if wid != 7 and wid != 8:
				# socle de roche qui sort du vide
				_put(ctx, socle, Worlds._cyl(0.34, 0.46, 0.5, 6), Worlds._at(at + Vector3(0, 0.2, 0), Vector3(0, rng.randf() * TAU, 0)))
			var base := at + Vector3(0, 0.45, 0)
			match wid:
				2:
					_bamboo(ctx, base, rng)
				3:
					_snow_pine(ctx, base, rng, p)
				4:
					for k in 3:
						var o := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
						var h := rng.randf_range(0.9, 2.0)
						_put(ctx, _paint(Color("#2E2A2A"), true), Worlds._cyl(0.0, rng.randf_range(0.16, 0.28), h, 5), Worlds._at(base + o + Vector3(0, h * 0.5 - 0.1, 0), Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))))
				5:
					_ink_pine(ctx, base, rng)
				6:
					for k in 2:
						var o := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
						var h := rng.randf_range(2.6, 3.8)
						var lc: Array = p["leaf"]
						_put(ctx, _paint(p["bark"], true), Worlds._cyl(0.07, 0.1, 0.6, 5), Worlds._at(base + o + Vector3(0, 0.3, 0)))
						_put(ctx, _paint(lc[k % lc.size()], true), Worlds._cyl(0.0, rng.randf_range(0.45, 0.6), h, 6), Worlds._at(base + o + Vector3(0, 0.5 + h * 0.5, 0)))
				7:
					_coral(ctx, Vector3(at.x, VOID_Y, z), rng, p)
				8:
					for k in 3:
						var o := Vector3(rng.randf_range(-0.3, 0.3), 0, -0.25 + 0.25 * k)
						var h := rng.randf_range(1.0, 1.6)
						var sx := Worlds._at(Vector3(at.x, VOID_Y, z) + o + Vector3(0, h * 0.5, 0), Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.1)))
						_put(ctx, _paint(Color("#8C8478"), true), Worlds._box(Vector3(0.14, h, 0.03)), sx)
						_put(ctx, _paint(Color("#3A363E"), false), Worlds._box(Vector3(0.05, h * 0.5, 0.035)), sx * Worlds._at(Vector3(0, h * 0.1, 0)))
			z += rng.randf_range(2.6, 3.4)


## Touffe de deux bambous à nœuds, feuillage en fers de lance, tanzaku de papier pastel.
static func _bamboo(ctx: Dictionary, base: Vector3, rng: RandomNumberGenerator) -> void:
	var stem := _paint(Decor.BAMBOO, true)
	var node := _paint(Decor.BAMBOO_NODE, false)
	var leaf := _paint(Decor.BAMBOO_LEAF, true)
	for k in 2:
		var o := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var h := rng.randf_range(2.4, 3.4)
		var lean := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		var a := base + o
		var b := a + Vector3(0, h, 0) + lean
		_limb(ctx, stem, a, b, 0.05, 0.04, 5)
		_put(ctx, node, Worlds._box(Vector3(0.1, 0.03, 0.1)), Worlds._at(a.lerp(b, 0.5)))
		for q in 2:
			var c := b + Vector3(rng.randf_range(-0.3, 0.3), -0.15 - 0.3 * q, rng.randf_range(-0.3, 0.3))
			_put(ctx, leaf, Worlds._cyl(0.0, 0.2, 0.5, 4), Worlds._at(c, Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))))
		var tz: Color = Worlds.TANZAKU[rng.randi_range(0, Worlds.TANZAKU.size() - 1)]
		_put(ctx, _paint(tz, false), Worlds._box(Vector3(0.07, 0.22, 0.01)), Worlds._at(a.lerp(b, 0.62) + Vector3(0.09, -0.12, 0)))


## Pin couvert de neige : tronc, deux étages coniques sombres coiffés de blanc.
static func _snow_pine(ctx: Dictionary, base: Vector3, rng: RandomNumberGenerator, p: Dictionary) -> void:
	var lc: Array = p["leaf"]
	_put(ctx, _paint(p["bark"], true), Worlds._cyl(0.06, 0.09, 0.5, 5), Worlds._at(base + Vector3(0, 0.25, 0)))
	var h := rng.randf_range(0.9, 1.2)
	for k in 2:
		var r := 0.7 - 0.22 * k
		var y := 0.4 + 0.65 * k
		_put(ctx, _paint(lc[k % 2], true), Worlds._cyl(0.0, r, h * 0.85, 6), Worlds._at(base + Vector3(0, y + h * 0.42, 0)))
		_put(ctx, _paint(lc[2], false), Worlds._cyl(0.0, r * 0.62, h * 0.45, 6), Worlds._at(base + Vector3(0, y + h * 0.62, 0)))


## Pin d'encre : tronc penché, deux plateaux sumi aplatis (les pins des estampes du monde 5).
static func _ink_pine(ctx: Dictionary, base: Vector3, rng: RandomNumberGenerator) -> void:
	var bark := _paint(Color("#2A2830"), true)
	var lean := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.3, 0.3))
	var top := base + Vector3(0, 2.2, 0) + lean
	_limb(ctx, bark, base, top, 0.1, 0.05, 5)
	_put(ctx, _paint(Color("#3A3A3C"), true), Worlds._ball(0.8, 0.26, 7, 3), Worlds._at(top))
	_put(ctx, _paint(Color("#4E4E50"), true), Worlds._ball(0.55, 0.2, 7, 3), Worlds._at(base.lerp(top, 0.6) + Vector3(-lean.x * 0.8 + 0.3, 0, 0.1)))


## Massif de corail : branches roses, pêche ou mauves sur une butte de sable.
static func _coral(ctx: Dictionary, at: Vector3, rng: RandomNumberGenerator, p: Dictionary) -> void:
	var lc: Array = p["leaf"]
	_put(ctx, _paint(Color("#C4B094"), true), Worlds._ball(0.5, 0.5, 6, 2), Worlds._at(at + Vector3(0, 0.12, 0)))
	for k in 3:
		var col: Color = lc[rng.randi_range(0, lc.size() - 1)]
		var a := at + Vector3(rng.randf_range(-0.25, 0.25), 0.3, rng.randf_range(-0.25, 0.25))
		var b := a + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.6, 1.1), rng.randf_range(-0.2, 0.2))
		_limb(ctx, _paint(col, true), a, b, 0.07, 0.04, 5)
		var c := b.lerp(a, 0.45)
		_limb(ctx, _paint(col, true), c, c + Vector3(rng.randf_range(-0.3, 0.3), 0.35, rng.randf_range(-0.15, 0.15)), 0.04, 0.025, 4)


## Volée de marches qui descend du parvis dans le vide, au sud (l'arrivée du héros, bas de l'écran).
static func _south_steps(ctx: Dictionary) -> void:
	var p: Dictionary = ctx["p"]
	var stone := _paint(p["stone"], true)
	var stone_dk := _paint(p["stone_dk"], false)
	for k in 3:
		var top := -0.13 - 0.13 * k
		var z := HALF.y + 0.06 + 0.32 * k
		_put(ctx, stone, Worlds._box(Vector3(2.7 - 0.2 * k, 0.4, 0.34)), Worlds._at(Vector3(0, top - 0.2, z + 0.17)))
		_put(ctx, stone_dk, Worlds._box(Vector3(2.62 - 0.2 * k, 0.012, 0.04)), Worlds._at(Vector3(0, top + 0.004, z + 0.03)))


## Tōrō de pierre simplifié (≈ 200 triangles) : un maillage à deux surfaces (pierre à contour, feu),
## partagé par monde et posé en MultiMesh.
static func _lantern_mesh(wid: int) -> ArrayMesh:
	var key := "toro%d" % wid
	if _kits.has(key):
		var cached: ArrayMesh = _kits[key]
		return cached
	var p := pal(wid)
	var c := {"vc": {}, "g": {}}
	var stone := _paint(p["stone"], true)
	var dark := _paint(Color(p["stone"]).darkened(0.25), true)
	_put(c, stone, Worlds._box(Vector3(0.46, 0.12, 0.46)), Worlds._at(Vector3(0, 0.06, 0)))
	_put(c, stone, Worlds._cyl(0.07, 0.09, 0.5, 5), Worlds._at(Vector3(0, 0.37, 0)))
	_put(c, stone, Worlds._box(Vector3(0.36, 0.09, 0.36)), Worlds._at(Vector3(0, 0.665, 0)))
	_put(c, Worlds._glow(p["flame"], 1.1), Worlds._box(Vector3(0.24, 0.22, 0.24)), Worlds._at(Vector3(0, 0.82, 0)))
	_put(c, dark, Worlds._cyl(0.05, 0.31, 0.2, 6), Worlds._at(Vector3(0, 1.03, 0)))
	_put(c, stone, Worlds._box(Vector3(0.09, 0.12, 0.09)), Worlds._at(Vector3(0, 1.17, 0), Vector3(0, PI * 0.25, 0)))
	if Color(p["cap"]).a > 0.0:
		_put(c, _paint(p["cap"], true), Worlds._cyl(0.04, 0.26, 0.09, 6), Worlds._at(Vector3(0, 1.1, 0)))
	var mesh := ArrayMesh.new()
	var vcm: Dictionary = c["vc"]
	var arr := _vc_arrays(vcm, true)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _vc_mat(true))
	var gd: Dictionary = c["g"]
	for k in gd:
		var e: Array = gd[k]
		var st: SurfaceTool = e[0]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, e[1])
	_kits[key] = mesh
	return mesh


## Flaque de lumière chaude au pied d'un feu (dégradé radial additif en MultiMesh) : vus d'en haut, les
## tōrō cachent leur feu sous leur toit ; le halo dit qu'ils sont allumés. Plus discret en plein jour.
static func _halo(ctx: Dictionary, pos: Vector3, r: float) -> void:
	Worlds._inst(ctx, "halo", Toon.blob_mesh(), _halo_mat(ctx["wid"]), Worlds._at(pos, Vector3.ZERO, Vector3(r, 1.0, r)))


static func _halo_mat(wid: int) -> StandardMaterial3D:
	var key := "halo%d" % wid
	Toon.blob_mesh()  # crée la texture du dégradé
	if _kits.has(key):
		var cached: StandardMaterial3D = _kits[key]
		return cached
	var p := pal(wid)
	var day := wid == 1 or wid == 3 or wid == 5
	var c: Color = p["flame"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Toon._blob_tex
	m.albedo_color = Color(c.r, c.g, c.b, 0.22 if day else 0.42)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_kits[key] = m
	return m


## Kagaribi : trépied de fer, corbeille, flamme ambre (ou froide au grand fond, lilas à Yomi).
static func _brazier(ctx: Dictionary, pos: Vector3, s: float) -> void:
	var p: Dictionary = ctx["p"]
	var iron := _paint(Color("#2E2C30"), true)
	var fire := Worlds._glow(p["flame"], 1.4)
	var core := Worlds._glow(Color("#FFE2A0") if p["light"].b < 0.8 else Color("#F0F4FF"), 1.6)
	var xf := Worlds._at(pos, Vector3.ZERO, Vector3.ONE * s)
	for k in 3:
		var a := TAU * k / 3.0
		_limb(ctx, iron, Vector3(sin(a) * 0.26, 0.0, cos(a) * 0.26), Vector3(sin(a + PI) * 0.1, 0.92, cos(a + PI) * 0.1), 0.025, 0.02, 3, xf)
	_put(ctx, iron, Worlds._cyl(0.24, 0.15, 0.2, 8), xf * Worlds._at(Vector3(0, 1.0, 0)))
	_put(ctx, fire, Worlds._cyl(0.0, 0.2, 0.42, 6), xf * Worlds._at(Vector3(0, 1.3, 0)))
	_put(ctx, core, Worlds._cyl(0.0, 0.1, 0.26, 5), xf * Worlds._at(Vector3(0.03, 1.24, 0.02)))
	_halo(ctx, pos + Vector3(0, 0.02, 0), 1.1 * s)


## Komainu : chien-lion de pierre assis sur un socle, la gueule ouverte (a) ou fermée (un), face au centre.
static func _komainu(ctx: Dictionary, pos: Vector3, open_mouth: bool, s: float) -> void:
	var p: Dictionary = ctx["p"]
	var stone := _paint(p["stone"], true)
	var dark := _paint(p["stone_dk"], false)
	var face := atan2(-pos.x, MOTIF_C.y - pos.z)
	var xf := Worlds._at(pos, Vector3(0, face, 0), Vector3.ONE * s)
	_put(ctx, stone, Worlds._box(Vector3(0.5, 0.3, 0.6)), xf * Worlds._at(Vector3(0, 0.15, 0)))
	_put(ctx, dark, Worlds._box(Vector3(0.56, 0.05, 0.66)), xf * Worlds._at(Vector3(0, 0.31, 0)))
	# corps assis : croupe, poitrail, pattes avant
	_put(ctx, stone, Worlds._ball(0.2, 0.34, 6, 3), xf * Worlds._at(Vector3(0, 0.5, -0.1)))
	_put(ctx, stone, Worlds._ball(0.16, 0.42, 6, 3), xf * Worlds._at(Vector3(0, 0.62, 0.08)))
	for sx: float in [-1.0, 1.0]:
		_put(ctx, stone, Worlds._box(Vector3(0.08, 0.3, 0.08)), xf * Worlds._at(Vector3(sx * 0.09, 0.48, 0.17)))
	# tête et crinière bouclée
	_put(ctx, stone, Worlds._ball(0.16, 0.28, 6, 3), xf * Worlds._at(Vector3(0, 0.9, 0.14)))
	for k in 3:
		var a := -1.0 + 1.0 * k
		_put(ctx, dark, Worlds._ball(0.08, 0.11, 6, 2), xf * Worlds._at(Vector3(sin(a) * 0.15, 0.93 + cos(a) * 0.07, 0.05)))
	_put(ctx, dark, Worlds._box(Vector3(0.16, 0.04 if not open_mouth else 0.08, 0.04)), xf * Worlds._at(Vector3(0, 0.84, 0.29)))
	# queue en flamme dressée
	_limb(ctx, stone, Vector3(0, 0.55, -0.26), Vector3(0, 0.88, -0.3), 0.07, 0.03, 4, xf)


## Arbre sacré (shinboku) : gros tronc, ramure du monde, shimenawa et shide autour du tronc.
static func _sacred_tree(ctx: Dictionary, pos: Vector3, s: float) -> void:
	var p: Dictionary = ctx["p"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var bark := _paint(p["bark"], true)
	var xf := Worlds._at(pos, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * s)
	var leaves: Array = p["leaf"]
	# socle de pierre, racines, tronc
	_put(ctx, _paint(p["stone"], true), Worlds._cyl(0.62, 0.68, 0.16, 8), xf * Worlds._at(Vector3(0, 0.08, 0)))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_limb(ctx, bark, Vector3(sin(a) * 0.1, 0.5, cos(a) * 0.1), Vector3(sin(a) * 0.48, 0.14, cos(a) * 0.48), 0.12, 0.05, 5, xf)
	var top := Vector3(0.15, 2.3, -0.1)
	_limb(ctx, bark, Vector3(0, 0.12, 0), Vector3(0.05, 1.3, 0), 0.3, 0.24, 8, xf)
	_limb(ctx, bark, Vector3(0.05, 1.3, 0), top, 0.24, 0.13, 7, xf)
	# shimenawa autour du tronc : anneau de paille et quatre shide
	var straw := _paint(Decor.STRAW, true)
	var paper := _paint(Decor.SHIDE, true)
	_put(ctx, straw, Decor.torus(0.24, 0.36, 12, 6), xf * Worlds._at(Vector3(0.02, 0.85, 0)))
	for k in 4:
		var a := TAU * k / 4.0 + 0.3
		_shide(ctx, paper, Vector3(sin(a) * 0.33, 0.8, cos(a) * 0.33), Vector3(cos(a), 0, -sin(a)), xf)
	if leaves.is_empty():
		# arbre mort (Fuji Rouge : calciné ; Yomi : blanchi) : branches nues
		for k in 5:
			var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
			var b0 := Vector3(0.05, 1.4 + 0.2 * k, 0)
			var b1 := b0 + Vector3(sin(a) * 0.9, 0.5 + rng.randf() * 0.4, cos(a) * 0.9)
			_limb(ctx, bark, b0, b1, 0.08, 0.025, 5, xf)
			_limb(ctx, bark, b1, b1 + Vector3(sin(a + 0.8) * 0.35, 0.3, cos(a + 0.8) * 0.35), 0.025, 0.01, 4, xf)
		return
	# ramure : coussins de feuillage étagés
	var mats: Array = []
	for lc in leaves:
		mats.append(_paint(lc, true))
	var pads := [[Vector3(0.0, 2.55, 0.0), 0.95], [Vector3(0.7, 2.1, 0.3), 0.7], [Vector3(-0.65, 2.15, -0.25), 0.72], [Vector3(0.2, 2.0, -0.75), 0.6], [Vector3(-0.2, 2.9, 0.3), 0.6]]
	for i in pads.size():
		var pd: Array = pads[i]
		var r: float = pd[1]
		var m: Array = mats[i % mats.size()]
		_put(ctx, m, Worlds._ball(r, r * 0.55, 7, 3), xf * Worlds._at(pd[0]))
		if i < 3:
			_limb(ctx, bark, top * 0.75, pd[0] * Vector3(0.8, 0.95, 0.8), 0.08, 0.04, 5, xf)


## Shōrō : beffroi à quatre poteaux, toit incurvé, cloche de bronze et son tronc-battant.
static func _belfry(ctx: Dictionary, pos: Vector3) -> void:
	var p: Dictionary = ctx["p"]
	var wood := _paint(p["wood"], true)
	var roof := _paint(p["roof"], true)
	var ridge := _paint(p["ridge"], false)
	var bronze := _paint(Color("#4E5E4F"), true)
	var stone := _paint(p["stone"], true)
	var xf := Worlds._at(pos)
	_put(ctx, stone, Worlds._box(Vector3(1.3, 0.22, 1.3)), xf * Worlds._at(Vector3(0, 0.11, 0)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_put(ctx, wood, Worlds._cyl(0.05, 0.06, 1.7, 6), xf * Worlds._at(Vector3(sx * 0.48, 1.07, sz * 0.48)))
	_put(ctx, wood, Worlds._box(Vector3(1.12, 0.08, 0.08)), xf * Worlds._at(Vector3(0, 1.88, 0)))
	_roof_into(ctx, roof, ridge, xf * Worlds._at(Vector3(0, 1.92, 0)), 1.7, 1.7, 0.62, 0.3, 0.4)
	if p["cap"].a > 0.0:
		_put(ctx, _paint(p["cap"], false), Worlds._ball(0.62, 0.22, 8, 3), xf * Worlds._at(Vector3(0, 2.38, 0)))
	_put(ctx, bronze, Worlds._cyl(0.22, 0.3, 0.62, 10), xf * Worlds._at(Vector3(0, 1.5, 0)))
	_put(ctx, bronze, Worlds._ball(0.22, 0.2, 10, 3), xf * Worlds._at(Vector3(0, 1.81, 0)))
	_put(ctx, _paint(p["trim"], false), Decor.torus(0.27, 0.31, 10, 3), xf * Worlds._at(Vector3(0, 1.32, 0)))
	_limb(ctx, wood, Vector3(-0.75, 1.45, 0.0), Vector3(-0.32, 1.45, 0.0), 0.06, 0.06, 6, xf)


# ------------------------------------------------------------------ nord : le sanctuaire

## Nord sur la terre ferme : volée de marches derrière le torii de sortie, cour de pierre, palissade
## (tamagaki) et haiden (gardien) ou honden (boss).
static func _north_court(ctx: Dictionary) -> void:
	var boss: bool = ctx["boss"]
	var p: Dictionary = ctx["p"]
	var stone := _paint(p["stone"], true)
	var stone_dk := _paint(p["stone_dk"], false)
	var z_edge := -HALF.y - 0.06
	var court_y := 0.5
	var hw := 4.9 if boss else 3.9  # demi-largeur de la cour
	var z_back := -16.0
	# escalier : 3 marches (de 0 à court_y) sur 1,1 m, largeur du passage du torii
	var sw := 2.7
	var nst := 3
	for k in nst:
		var zt := z_edge - 0.36 * k
		var top := court_y * float(k + 1) / nst
		_put(ctx, stone, Worlds._box(Vector3(sw, top + 0.6, 0.38)), Worlds._at(Vector3(0, top - (top + 0.6) * 0.5, zt - 0.19)))
		_put(ctx, stone_dk, Worlds._box(Vector3(sw - 0.04, 0.02, 0.05)), Worlds._at(Vector3(0, top + 0.005, zt - 0.03)))
	var z_court := z_edge - 0.36 * nst
	# murs de soutènement de part et d'autre de l'escalier, cour pavée au-dessus
	for sx: float in [-1.0, 1.0]:
		var x0 := sw * 0.5
		var x1 := hw
		_put(ctx, stone, Worlds._box(Vector3(x1 - x0, court_y + 0.6, z_edge - z_court + 0.02)), Worlds._at(Vector3(sx * (x0 + x1) * 0.5, court_y - (court_y + 0.6) * 0.5, (z_edge + z_court) * 0.5)))
	_put(ctx, stone, Worlds._box(Vector3(hw * 2.0, court_y + 0.6, z_court - z_back)), Worlds._at(Vector3(0, court_y - (court_y + 0.6) * 0.5, (z_court + z_back) * 0.5)))
	# joints de la cour
	var zz := z_court - 0.9
	while zz > z_back + 0.4:
		_put(ctx, stone_dk, Worlds._box(Vector3(hw * 2.0 - 0.2, 0.012, 0.035)), Worlds._at(Vector3(0, court_y + 0.006, zz)))
		zz -= 0.9
	# allée centrale (sandō) de dalles plus sombres jusqu'au sanctuaire
	_put(ctx, stone_dk, Worlds._box(Vector3(1.2, 0.02, z_court - z_back - 1.0)), Worlds._at(Vector3(0, court_y + 0.01, (z_court + z_back) * 0.5 - 0.5)))
	# palissade basse (tamagaki) au bord de la cour, de part et d'autre des marches
	var wood := _paint(p["lacq"], true)
	for sx: float in [-1.0, 1.0]:
		var x := sw * 0.5 + 0.25
		while x < hw - 0.1:
			_put(ctx, wood, Worlds._box(Vector3(0.07, 0.42, 0.07)), Worlds._at(Vector3(sx * x, court_y + 0.21, z_court + 0.14)))
			x += 0.42
		_put(ctx, wood, Worlds._box(Vector3(hw - sw * 0.5 - 0.3, 0.06, 0.08)), Worlds._at(Vector3(sx * (hw + sw * 0.5 + 0.2) * 0.5, court_y + 0.38, z_court + 0.14)))
	# komainu en haut des marches, lanternes de la cour
	_komainu(ctx, Vector3(-sw * 0.5 - 0.45, court_y, z_court - 0.5), true, 0.9)
	_komainu(ctx, Vector3(sw * 0.5 + 0.45, court_y, z_court - 0.5), false, 0.9)
	# (le sanctuaire est tiré vers l'arène : vu d'en haut, ce qui recule passe sous le bandeau du haut)
	var lmesh := _lantern_mesh(ctx["wid"])
	for sx: float in [-1.0, 1.0]:
		for k in (2 if boss else 1):
			var lp := Vector3(sx * (3.4 if boss else 2.75), court_y, z_court - 0.55 - 1.5 * k)
			Worlds._inst(ctx, "toro", lmesh, null, Worlds._at(lp, Vector3(0, PI * 0.5 * sx, 0), Vector3.ONE))
			_halo(ctx, lp + Vector3(0, 0.02, 0), 0.8)
	if boss:
		_honden(ctx, Vector3(0, court_y, -12.3), 1.0)
		for sx: float in [-1.0, 1.0]:
			_brazier(ctx, Vector3(sx * 4.4, court_y, z_court - 0.5), 1.15)
	else:
		_haiden(ctx, Vector3(0, court_y, -11.85), 1.0)
	_light(ctx, Vector3(0, court_y + 1.4, z_court - 1.2), 1.0, 7.0)


## Nord laissé à l'eau : grand torii planté dans le vide (le boss passe dessous), sanctuaire sur pilotis
## plus loin, galeries de pieux et lanternes de part et d'autre.
static func _north_water(ctx: Dictionary) -> void:
	var boss: bool = ctx["boss"]
	var p: Dictionary = ctx["p"]
	var stone := _paint(p["stone"], true)
	var s := 2.25 if boss else 1.9
	_torii(ctx, Vector3(0, VOID_Y, -10.7), s)
	# plateforme sur pilotis du sanctuaire, au-delà de l'eau libre
	var deck_y := 0.35
	var z0 := -12.6
	var z1 := -17.2
	var hw := 4.6 if boss else 3.6
	var wood := _paint(p["wood"], true)
	_put(ctx, stone, Worlds._box(Vector3(hw * 2.0, 0.22, z0 - z1)), Worlds._at(Vector3(0, deck_y - 0.11, (z0 + z1) * 0.5)))
	var x := -hw + 0.3
	while x <= hw - 0.29:
		_put(ctx, wood, Worlds._cyl(0.08, 0.08, deck_y - VOID_Y, 6), Worlds._at(Vector3(x, (deck_y + VOID_Y) * 0.5 - 0.1, z0 - 0.15)))
		x += 0.9
	# marches qui descendent vers l'eau, face à l'arène
	for k in 3:
		_put(ctx, stone, Worlds._box(Vector3(2.4, 0.12, 0.3)), Worlds._at(Vector3(0, deck_y - 0.17 - 0.12 * k, z0 + 0.15 + 0.3 * k)))
	if boss:
		_honden(ctx, Vector3(0, deck_y, -15.0), 0.95)
	else:
		_haiden(ctx, Vector3(0, deck_y, -14.0), 0.95)
	for sx: float in [-1.0, 1.0]:
		_brazier(ctx, Vector3(sx * (hw - 0.5), deck_y, z0 - 0.4), 1.0)
		_komainu(ctx, Vector3(sx * 1.6, deck_y, z0 - 0.45), sx < 0.0, 0.85)
	_light(ctx, Vector3(0, 1.4, -12.0), 1.1, 8.0)


## Torii monumental à la palette du monde (laque sombre, jamais le vermillon des annonces), à sode-hashira.
## Origine = pied des piliers (`pos.y` : plan de l'eau ou sol).
static func _torii(ctx: Dictionary, pos: Vector3, s: float) -> void:
	var p: Dictionary = ctx["p"]
	var lacq := _paint(p["lacq"], true)
	var dark := _paint(p["lacq_dk"], true)
	var gold := _paint(p["trim"], false)
	var xf := Worlds._at(pos, Vector3.ZERO, Vector3.ONE * s)
	var px := 2.2
	for sx: float in [-1.0, 1.0]:
		var x := sx * px
		_put(ctx, dark, Worlds._cyl(0.22, 0.27, 0.5, 10), xf * Worlds._at(Vector3(x, 0.25, 0)))
		_put(ctx, lacq, Worlds._cyl(0.155, 0.18, 2.9, 10), xf * Worlds._at(Vector3(x, 1.95, 0)))
		_put(ctx, dark, Worlds._cyl(0.19, 0.19, 0.1, 10), xf * Worlds._at(Vector3(x, 3.2, 0)))
		# sode-hashira (Itsukushima) : piliers d'appui de part et d'autre
		for sz: float in [-1.0, 1.0]:
			_put(ctx, lacq, Worlds._cyl(0.09, 0.1, 2.0, 8), xf * Worlds._at(Vector3(x, 1.0, sz * 0.75)))
			_put(ctx, lacq, Worlds._box(Vector3(0.1, 0.1, 1.5)), xf * Worlds._at(Vector3(x, 1.9, 0)))
	_put(ctx, lacq, Worlds._box(Vector3(5.6, 0.2, 0.16)), xf * Worlds._at(Vector3(0, 2.7, 0)))
	_put(ctx, lacq, Worlds._box(Vector3(0.22, 0.42, 0.16)), xf * Worlds._at(Vector3(0, 3.0, 0)))
	_put(ctx, dark, Worlds._box(Vector3(0.48, 0.56, 0.06)), xf * Worlds._at(Vector3(0, 2.98, 0.12)))
	_put(ctx, gold, Worlds._box(Vector3(0.34, 0.42, 0.02)), xf * Worlds._at(Vector3(0, 2.98, 0.155)))
	_put(ctx, lacq, Worlds._box(Vector3(5.9, 0.2, 0.34)), xf * Worlds._at(Vector3(0, 3.3, 0)))
	var w := 3.35
	var nk := 8
	for i in nk:
		var x0 := lerpf(-w, w, float(i) / nk)
		var x1 := lerpf(-w, w, float(i + 1) / nk)
		var y0 := 3.52 + 0.34 * pow(absf(x0) / w, 2.6)
		var y1 := 3.52 + 0.34 * pow(absf(x1) / w, 2.6)
		var l := Vector2(x1 - x0, y1 - y0).length() + 0.03
		_put(ctx, dark, Worlds._box(Vector3(l, 0.26, 0.48)), xf * Transform3D(Basis(Vector3(0, 0, 1), atan2(y1 - y0, x1 - x0)), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0)))
	if p["cap"].a > 0.0:
		_put(ctx, _paint(p["cap"], false), Worlds._box(Vector3(6.4, 0.08, 0.44)), xf * Worlds._at(Vector3(0, 3.7, 0)))
	# shimenawa sous le nuki
	_rope(ctx, xf * Vector3(-px + 0.2, 2.45, 0.05), xf * Vector3(px - 0.2, 2.45, 0.05))


## Toit de sanctuaire : toit incurvé (_roof_into), neige éventuelle sur le faîtage.
static func _roof(ctx: Dictionary, xf: Transform3D, w: float, d: float, h: float, rl: float) -> void:
	var p: Dictionary = ctx["p"]
	var roof := _paint(p["roof"], true)
	var ridge := _paint(p["ridge"], false)
	_roof_into(ctx, roof, ridge, xf, w, d, h, rl, 0.38)
	if p["cap"].a > 0.0:
		var cap := _paint(p["cap"], false)
		_put(ctx, cap, Worlds._box(Vector3(w * rl + 0.3, 0.12, 0.5)), xf * Worlds._at(Vector3(0, h + 0.05, 0)))
		for sz: float in [-1.0, 1.0]:
			_put(ctx, cap, Worlds._box(Vector3(w * 0.8, 0.05, d * 0.28)), xf * Transform3D(Basis(Vector3.RIGHT, sz * 0.5), Vector3(0, h * 0.62, sz * d * 0.2)))


## Corps de bâtiment : plancher surélevé, poteaux laqués, murs (plâtre, papier), portes sombres en façade.
static func _hall_body(ctx: Dictionary, xf: Transform3D, w: float, d: float, h: float, cols: int) -> void:
	var p: Dictionary = ctx["p"]
	var lacq := _paint(p["lacq"], true)
	var wall := _paint(p["wall"], true)
	var wood := _paint(p["wood"], true)
	var dark := _paint(Color("#2A221C"), false)
	var gold := _paint(p["trim"], false)
	# plancher (engawa) et sa balustrade
	_put(ctx, wood, Worlds._box(Vector3(w + 0.5, 0.12, d + 0.5)), xf * Worlds._at(Vector3(0, 0.3, 0)))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_put(ctx, wood, Worlds._box(Vector3(0.12, 0.3, 0.12)), xf * Worlds._at(Vector3(sx * (w * 0.5 + 0.15), 0.12, sz * (d * 0.5 + 0.15))))
	_put(ctx, lacq, Worlds._box(Vector3(w + 0.5, 0.05, 0.05)), xf * Worlds._at(Vector3(0, 0.62, d * 0.5 + 0.23)))
	# murs
	_put(ctx, wall, Worlds._box(Vector3(w - 0.1, h, d - 0.1)), xf * Worlds._at(Vector3(0, 0.36 + h * 0.5, 0)))
	# poteaux de façade et d'angle, linteau
	for i in cols:
		var x := lerpf(-w * 0.5, w * 0.5, float(i) / (cols - 1))
		_put(ctx, lacq, Worlds._box(Vector3(0.16, h + 0.06, 0.16)), xf * Worlds._at(Vector3(x, 0.36 + h * 0.5, d * 0.5)))
		_put(ctx, lacq, Worlds._box(Vector3(0.16, h + 0.06, 0.16)), xf * Worlds._at(Vector3(x, 0.36 + h * 0.5, -d * 0.5)))
		if i < cols - 1:
			var xm := lerpf(-w * 0.5, w * 0.5, (float(i) + 0.5) / (cols - 1))
			_put(ctx, dark, Worlds._box(Vector3(w / (cols - 1) - 0.32, h * 0.72, 0.02)), xf * Worlds._at(Vector3(xm, 0.36 + h * 0.38, d * 0.5 - 0.03)))
	_put(ctx, lacq, Worlds._box(Vector3(w + 0.2, 0.16, d + 0.2)), xf * Worlds._at(Vector3(0, 0.36 + h + 0.06, 0)))
	_put(ctx, gold, Worlds._box(Vector3(w + 0.22, 0.03, 0.02)), xf * Worlds._at(Vector3(0, 0.36 + h - 0.02, d * 0.5 + 0.1)))


## Honden (boss) : grand toit à chigi et katsuogi, escalier couvert (kōhai), shimenawa et cloches.
static func _honden(ctx: Dictionary, pos: Vector3, s: float) -> void:
	var p: Dictionary = ctx["p"]
	var xf := Worlds._at(pos, Vector3.ZERO, Vector3.ONE * s)
	var w := 5.4
	var d := 2.8
	var h := 1.25
	var stone := _paint(p["stone"], true)
	_put(ctx, stone, Worlds._box(Vector3(w + 1.2, 0.24, d + 1.4)), xf * Worlds._at(Vector3(0, 0.12, 0.1)))
	var b2 := xf * Worlds._at(Vector3(0, 0.24, 0))
	_hall_body(ctx, b2, w, d, h, 5)
	var top := 0.24 + 0.36 + h + 0.14
	_roof(ctx, xf * Worlds._at(Vector3(0, top, 0)), w + 1.9, d + 2.0, 1.55, 0.6)
	# kōhai : avant-toit au-dessus de l'escalier
	_roof(ctx, xf * Worlds._at(Vector3(0, top - 0.35, d * 0.5 + 0.75)), 2.6, 1.0, 0.4, 0.75)
	var lacq := _paint(p["lacq"], true)
	for sx: float in [-1.0, 1.0]:
		_put(ctx, lacq, Worlds._box(Vector3(0.14, top - 0.35, 0.14)), xf * Worlds._at(Vector3(sx * 1.1, (top - 0.35) * 0.5, d * 0.5 + 1.0)))
	# chigi (planches croisées aux pignons) et katsuogi (rondins sur le faîtage)
	var dark := _paint(p["ridge"], true)
	var gold := _paint(p["trim"], false)
	var rx := (w + 1.9) * 0.5 * 0.6
	var ry := top + 1.55
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_put(ctx, dark, Worlds._box(Vector3(0.1, 1.2, 0.08)), xf * Transform3D(Basis(Vector3(0, 0, 1), sz * 0.55), Vector3(sx * (rx + 0.05), ry + 0.35, sz * 0.12)))
	for k in 5:
		var x := lerpf(-rx * 0.8, rx * 0.8, float(k) / 4.0)
		_put(ctx, dark, Worlds._cyl(0.09, 0.09, 0.7, 8), xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, ry + 0.16, 0)))
		_put(ctx, gold, Worlds._cyl(0.095, 0.095, 0.05, 8), xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, ry + 0.16, 0.33)))
	# grand shimenawa en façade, cloches (suzu) et tronc d'offrandes
	var front := d * 0.5 + 0.18
	_rope(ctx, xf * Vector3(-w * 0.5 + 0.1, top - 0.32, front), xf * Vector3(w * 0.5 - 0.1, top - 0.32, front))
	for sx: float in [-0.6, 0.6]:
		_put(ctx, gold, Worlds._ball(0.1, 0.18, 8, 4), xf * Worlds._at(Vector3(sx, top - 0.62, front + 0.05)))
		_limb(ctx, _paint(Color("#E8DCC0"), false), Vector3(sx, top - 0.7, front + 0.05), Vector3(sx, 0.8, front + 0.08), 0.03, 0.03, 4, xf)
	_put(ctx, _paint(p["wood"], true), Worlds._box(Vector3(1.0, 0.42, 0.5)), xf * Worlds._at(Vector3(0, 0.45, d * 0.5 + 0.75)))
	_put(ctx, gold, Worlds._cyl(0.26, 0.26, 0.03, 10), xf * Worlds._at(Vector3(0, top - 0.85, d * 0.5 + 0.1), Vector3(PI * 0.5, 0, 0)))


## Haiden (gardien) : pavillon plus modeste, toit simple, gros shimenawa d'Izumo en façade.
static func _haiden(ctx: Dictionary, pos: Vector3, s: float) -> void:
	var p: Dictionary = ctx["p"]
	var xf := Worlds._at(pos, Vector3.ZERO, Vector3.ONE * s)
	var w := 3.6
	var d := 2.0
	var h := 0.95
	_hall_body(ctx, xf, w, d, h, 4)
	var top := 0.36 + h + 0.14
	_roof(ctx, xf * Worlds._at(Vector3(0, top, 0)), w + 1.4, d + 1.4, 1.05, 0.55)
	var front := d * 0.5 + 0.2
	# shimenawa épais (Izumo) : deux cordes doublées
	_rope(ctx, xf * Vector3(-w * 0.5 + 0.1, top - 0.28, front), xf * Vector3(w * 0.5 - 0.1, top - 0.28, front))
	_rope(ctx, xf * Vector3(-w * 0.5 + 0.3, top - 0.18, front + 0.04), xf * Vector3(w * 0.5 - 0.3, top - 0.18, front + 0.04))
	_put(ctx, _paint(p["trim"], false), Worlds._ball(0.09, 0.16, 8, 4), xf * Worlds._at(Vector3(0, top - 0.6, front + 0.05)))


# ------------------------------------------------------------------ ambiance

## Une seule lumière ponctuelle (aucune en Toon.lite), devant le sanctuaire.
static func _light(ctx: Dictionary, pos: Vector3, energy: float, reach: float) -> void:
	if Toon.lite or int(ctx["lights"]) > 0:
		return
	ctx["lights"] = 1
	var p: Dictionary = ctx["p"]
	var l := OmniLight3D.new()
	l.name = "ShrineLight"
	l.position = pos
	l.light_color = p["light"]
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	var root: Node3D = ctx["root"]
	root.add_child(l)


## Particules légères du sanctuaire (au nord et sur les terrasses) : pétales, feux de renard, neige, cendres,
## papier, aiguilles, bulles, âmes. Matériaux de particules du monde (déjà compilés).
static func _ambience(ctx: Dictionary) -> void:
	var p: Dictionary = ctx["p"]
	var root: Node3D = ctx["root"]
	var boss: bool = ctx["boss"]
	var n := (18 if boss else 12) / (2 if Toon.lite else 1)
	var kind := String(p["motes"])
	var em: CPUParticles3D = null
	match kind:
		"snow", "ash":
			em = Worlds._emitter(root, "ShrineMotes", Vector3(0, 3.0, -9.0), Vector3(7.0, 0.2, 4.0), n, 5.0, Worlds._sphere_mesh("snow", 0.035, false))
			em.direction = Vector3(0.3, -1, 0)
			em.spread = 10.0
			em.gravity = Vector3(0, -0.1, 0)
			em.initial_velocity_min = 0.5
			em.initial_velocity_max = 0.8
		"bubbles":
			em = Worlds._emitter(root, "ShrineMotes", Vector3(0, -0.3, -9.0), Vector3(7.0, 0.1, 4.0), n, 4.0, Worlds._sphere_mesh("shrine_bubble", 0.04, true))
			em.direction = Vector3.UP
			em.spread = 12.0
			em.gravity = Vector3(0, 0.25, 0)
			em.initial_velocity_min = 0.3
			em.initial_velocity_max = 0.6
			em.color = Color(0.75, 0.88, 1.0)
		"petals", "needles", "paper":
			em = Worlds._emitter(root, "ShrineMotes", Vector3(-1.5, 2.6, -8.0), Vector3(7.0, 1.2, 5.0), n, 6.0, Worlds._quad_mesh("shrine_" + kind, Vector2(0.1, 0.07), false))
			em.direction = Vector3(1, -0.25, 0.2)
			em.spread = 25.0
			em.gravity = Vector3(0.05, -0.12, 0)
			em.initial_velocity_min = 0.3
			em.initial_velocity_max = 0.6
			em.angle_min = 0.0
			em.angle_max = 360.0
			em.angular_velocity_min = -120.0
			em.angular_velocity_max = 120.0
			match kind:
				"petals":
					em.color = Color("#F2C4CF")
				"needles":
					em.color = Color("#A8804C")
				_:
					em.color = Color("#D8D0BE")
		_:
			# feux de renard, braises des braseros, âmes : lueurs qui montent lentement
			var col := Color("#F1E3A6")
			if kind == "ember":
				col = Color("#D9A64A")
			elif kind == "souls":
				col = Color("#B9A8E8")
			em = Worlds._emitter(root, "ShrineMotes", Vector3(0, 0.6, -9.5), Vector3(6.5, 0.4, 3.5), n, 4.5, Worlds._sphere_mesh("shrine_glow", 0.05, true))
			em.direction = Vector3.UP
			em.spread = 30.0
			em.gravity = Vector3(0, 0.12, 0)
			em.initial_velocity_min = 0.15
			em.initial_velocity_max = 0.4
			em.color = col
	em.scale_amount_min = 0.7
	em.scale_amount_max = 1.4
	em.color_ramp = Worlds._fade(0.15, 0.75)
	em.emitting = true
