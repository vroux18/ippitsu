extends RefCounted
## Habillage des salles : ce qui fait qu'un mètre carré « raconte quelque chose » sans gêner le jeu.
## Appelé par Worlds.build_props (lots bs/bn et instances mm partagés : les pièces se fusionnent par matériau
## avec le reste du décor, aucun draw call de plus par pièce) avant le paysage des abords :
##  - le rebord : le long des bords ouest et est de la plateforme, à ras du quai (0,1 à 0,4 m au-delà du bord,
##    hors de la zone praticable : clamp_walk n'y mène jamais), des saynètes du vocabulaire du monde posées
##    sur une tablette (tas de caisses tamponnées, coin de pêcheur, petit autel, lanterne au crochet…) ;
##    rien de haut au bas de l'écran ; les grandes saynètes réservent leur place (avoid) devant la bande proche ;
##  - le sol : décalques bas (quads en MultiMesh, un draw call par sorte, sous les télégraphes d'attaque :
##    y ≤ 0,010 < Hazards.Y_FOND) et quelques reliefs de moins de 4 cm : nattes, flaques, traces d'encre,
##    feuilles, empreintes, cendres… jamais sur les pièces de décor ni derrière le torii ;
##  - la vie : lanternes de papier qui se balancent et bannières qui flottent (decor_life.gd, un MultiMesh
##    par sorte) ; les sources de feu portent un marqueur de groupe « lamp » (méta lamp_color) pour la lumière.
## Tout est tiré de la graine de la salle (déterministe : les robots rejouent la même salle).

const Toon = preload("res://scripts/toon.gd")
const Decor = preload("res://scripts/decor.gd")
const Lueurs = preload("res://scripts/lueurs.gd")
const W = preload("res://scripts/worlds.gd")
const Life = preload("res://scripts/decor_life.gd")

const DECAL_Y := 0.009  # sous Hazards.Y_FOND (0.014) : les télégraphes passent toujours dessus
const RIM_IN := 0.06  # début de la tablette au-delà du bord de la plateforme
const LOW_Z := 6.0  # au-delà (bas de l'écran) : saynètes basses seulement
const FOOT_H := 0.03  # relief maximal des éléments posés dans la zone de jeu

const STAMP_INK := Color("#2E3446")
const CRATE := Color("#A88A5C")
const CRATE_DARK := Color("#7A6040")
const BASKET := Color("#B8975E")
const FISH := Color("#8FA3B5")
const FISH_DARK := Color("#5A6E82")
const NET := Color("#6E6A58")
const SACK := Color("#C9B48C")
const CANDLE := Color("#F1E6C8")
const WAX_GLOW := Color("#FFD98A")
const MOSS := Color("#5E7A4A")
const LEAF_GOLD := Color("#C9963E")
const LEAF_RUST := Color("#9A5A2E")
const MUSH_CAP := Color("#B8694A")
const MUSH_STEM := Color("#E8DCC4")
const SHELL := Color("#E3D2C0")
const STARFISH := Color("#C98A6A")
const SAND := Color("#D8C8A8")
const INK := Toon.SUMI
const WASHI := Toon.WASHI

# Aucun cache statique ici : les maillages et matières partagés vont dans les caches de worlds.gd (ce script
# est chargé à la demande et serait déchargé après le serveur de rendu : ses ressources GPU fuiraient à la sortie).


# ------------------------------------------------------------------ entrée

## Habille la salle. `floor` : plateformes praticables (Rect2, coordonnées du décor, ponts exclus) ;
## `kind` : "room", "stage" (tronçon), "hub" (sanctuaire : sol seulement, léger) ou "shrine" (arène de gardien
## ou de boss : rebord sous les terrasses seulement).
static func apply(ctx: Dictionary, wid_in: int, plats: Array, kind: String, seed_i: int) -> void:
	var wid := clampi(wid_in, 1, 8)
	var soft := wid_in <= 0  # le Sentier : le port, plus calme
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_i * 131 + wid * 17 + 5)
	var dens := 0.7 if Toon.lite else 1.0
	if soft:
		dens *= 0.75
	ctx["dress_lamps"] = []
	var frame: Rect2 = W._ls_frame(ctx)
	if kind != "hub":
		await _rim(wid, ctx, plats, frame, kind, rng, dens)
	await W._cut(ctx)
	_floor(wid, ctx, plats, kind, rng, dens * (0.6 if kind == "hub" else 1.0))
	await W._cut(ctx)


## Pose les nœuds vivants (lanternes qui se balancent) et les marqueurs de lampes : à appeler une fois les
## lots vidés (build_props), sous `root`.
static func finish(ctx: Dictionary, root: Node3D) -> void:
	if ctx.has("dress_life"):
		var life: Life = ctx["dress_life"]
		root.add_child(life)
		life.commit()
	var lamps: Array = ctx.get("dress_lamps", [])
	for l in lamps:
		var la: Array = l
		var n := Node3D.new()
		n.name = "Lamp"
		n.position = la[0]
		n.add_to_group("lamp")
		n.set_meta("lamp_color", la[1])
		root.add_child(n)


# ------------------------------------------------------------------ outils

static func _plane_mesh() -> PlaneMesh:
	if W._meshes.has("dress_plane"):
		var cached: PlaneMesh = W._meshes["dress_plane"]
		return cached
	var pl := PlaneMesh.new()
	pl.size = Vector2.ONE
	W._meshes["dress_plane"] = pl
	return pl


## Disque plat unité (diamètre 1, éventail de 12 triangles, face vers le haut) : taches, flaques, auréoles.
static func _disc_mesh() -> ArrayMesh:
	if W._meshes.has("dress_disc"):
		var cached: ArrayMesh = W._meshes["dress_disc"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in 12:
		var a0 := TAU * k / 12.0
		var a1 := TAU * (k + 1) / 12.0
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a1) * 0.5, 0, sin(a1) * 0.5))
		st.add_vertex(Vector3(cos(a0) * 0.5, 0, sin(a0) * 0.5))
	var disc := st.commit()
	W._meshes["dress_disc"] = disc
	return disc


## Décalque plat : quad unité (ou disque si `round`) mis à l'échelle (sx, sz), tourné de `yaw`, aplat alpha
## sans lumière, dessiné avant les télégraphes (priorité -2) et sous eux.
static func _decal(ctx: Dictionary, key: String, col: Color, p: Vector2, sx: float, sz: float, yaw: float, round := false, y := DECAL_Y) -> void:
	var m := _decal_mat(col)
	var mesh: Mesh = _disc_mesh() if round else _plane_mesh()
	W._inst(ctx, "dress_" + key + ("_o" if round else ""), mesh, m, W._at(Vector3(p.x, y, p.y), Vector3(0, yaw, 0), Vector3(sx, 1.0, sz)))


static func _decal_mat(col: Color) -> StandardMaterial3D:
	var key := "dress_decal_" + col.to_html(true)
	if W._mats.has(key):
		var cached: StandardMaterial3D = W._mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = -2
	m.no_depth_test = false
	W._mats[key] = m
	return m


## Petit relief instancié (même maillage, même matière : un draw call par sorte).
static func _bit(ctx: Dictionary, key: String, mesh: Mesh, mat: Material, xf: Transform3D) -> void:
	W._inst(ctx, "dress_" + key, mesh, mat, xf)


## Source de feu : marqueur pour la lumière (groupe « lamp »), position dans le repère du décor.
static func _lamp(ctx: Dictionary, pos: Vector3, col: Color) -> void:
	var lamps: Array = ctx["dress_lamps"]
	lamps.append([pos, col])


static func _life(ctx: Dictionary) -> Life:
	if not ctx.has("dress_life"):
		var l: Life = Life.new()
		l.name = "DecorLife"
		ctx["dress_life"] = l
	return ctx["dress_life"]


## Toon partagé : une seule épaisseur de contour (0,02) pour tout l'habillage, afin que deux pièces d'une
## même teinte partagent toujours leur matière (donc leur draw call), ou aucun contour (`outline` faux).
static func _tn(col: Color, outline := true) -> StandardMaterial3D:
	return W._toon(col, outline, 0.02)


static func _at(p: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return W._at(p, rot, scl)


## Lanterne de papier qui pend (pivot au crochet, corps sous y = 0) : maillage partagé par couleur, pour le
## MultiMesh vivant. Surfaces : papier lumineux, coiffes noires (avec contours par passe suivante).
static func _lantern_mesh(color: Color) -> ArrayMesh:
	var key := "dress_lantern_" + color.to_html(false)
	if W._meshes.has(key):
		var cached: ArrayMesh = W._meshes[key]
		return cached
	var b := {}
	var black := _tn(Toon.SUMI, false)
	var body := W._glow(color, 0.55)
	var rib := _tn(color.darkened(0.35), false)
	W._limb(b, black, Vector3.ZERO, Vector3(0, -0.12, 0), 0.008, 0.008, 4)
	var cy := -0.37
	W._add(b, body, W._ball(0.17, 0.4, 10, 6), _at(Vector3(0, cy, 0)))
	W._add(b, black, W._cyl(0.1, 0.1, 0.05, 10), _at(Vector3(0, cy + 0.215, 0)))
	W._add(b, black, W._cyl(0.1, 0.1, 0.05, 10), _at(Vector3(0, cy - 0.215, 0)))
	for dy: float in [-0.11, 0.0, 0.11]:
		var rr := 0.17 * sqrt(1.0 - pow(dy / 0.2, 2.0))
		W._add(b, rib, Decor.torus(rr - 0.006, rr + 0.01, 12, 4), _at(Vector3(0, cy + dy, 0)))
	W._add(b, black, W._cyl(0.012, 0.03, 0.12, 5), _at(Vector3(0, cy - 0.3, 0)))
	var mesh := _commit_multi(b)
	W._meshes[key] = mesh
	return mesh


## Bannière qui flotte (pivot au mât, tissu vers +X) : rectangle de tissu et marques d'encre.
static func _flag_mesh(cloth: Color, ink: Color) -> ArrayMesh:
	var key := "dress_flag_" + cloth.to_html(false) + ink.to_html(false)
	if W._meshes.has(key):
		var cached: ArrayMesh = W._meshes[key]
		return cached
	var b := {}
	var cm := _tn(cloth)
	var im := _tn(ink, false)
	W._add(b, cm, W._box(Vector3(0.42, 1.1, 0.025)), _at(Vector3(0.24, -0.55, 0)))
	W._add(b, im, W._box(Vector3(0.42, 0.08, 0.03)), _at(Vector3(0.24, -0.06, 0)))
	for k in 3:
		W._add(b, im, W._box(Vector3(0.14, 0.11, 0.03)), _at(Vector3(0.24, -0.3 - k * 0.24, 0)))
	var mesh := _commit_multi(b)
	W._meshes[key] = mesh
	return mesh


## Fusionne un lot (matériau -> SurfaceTool) en un seul maillage à plusieurs surfaces (une par matériau).
static func _commit_multi(b: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for k in b:
		if k is String:
			continue
		var entry: Array = b[k]
		var st: SurfaceTool = entry[0]
		var m: Material = entry[1]
		var tmp := st.commit()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tmp.surface_get_arrays(0))
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	return mesh


# ------------------------------------------------------------------ briques du vocabulaire

## Caisse tamponnée (planches, tasseaux, tampon d'encre sur la face -X : vers l'arène).
static func _crate(bs: Dictionary, bn: Dictionary, xf: Transform3D, w: float, h: float, d: float, col := CRATE, stamp := STAMP_INK) -> void:
	var m := _tn(col)
	var dark := _tn(Decor.ROPE_DARK, false)
	var ink := _tn(stamp, false)
	W._add(bs, m, W._box(Vector3(w, h, d)), xf * _at(Vector3(0, h * 0.5, 0)))
	for sz: float in [-1.0, 1.0]:
		W._add(bn, dark, W._box(Vector3(w + 0.02, 0.04, 0.05)), xf * _at(Vector3(0, h - 0.03, sz * (d * 0.5 - 0.06))))
		W._add(bn, dark, W._box(Vector3(0.05, h + 0.01, 0.04)), xf * _at(Vector3(sz * (w * 0.5 - 0.06), h * 0.5, -d * 0.5 - 0.005)))
	W._add(bn, ink, W._box(Vector3(0.012, h * 0.38, d * 0.36)), xf * _at(Vector3(-w * 0.5 - 0.004, h * 0.55, 0)))
	W._add(bn, _tn(WASHI, false), W._box(Vector3(0.016, h * 0.14, d * 0.2)), xf * _at(Vector3(-w * 0.5 - 0.006, h * 0.55, 0)))


## Tonnelet de bois cerclé (seau si `handle`).
static func _tub(bs: Dictionary, bn: Dictionary, xf: Transform3D, r: float, h: float, col: Color, handle := false, fill := Color(0, 0, 0, 0)) -> void:
	var wood := _tn(col)
	var hoop := _tn(Decor.ROPE_DARK, false)
	W._add(bs, wood, W._cyl(r, r * 0.86, h, 9), xf * _at(Vector3(0, h * 0.5, 0)))
	W._add(bn, hoop, W._cyl(r * 1.01, r * 1.01, 0.03, 9), xf * _at(Vector3(0, h * 0.82, 0)))
	W._add(bn, hoop, W._cyl(r * 0.92, r * 0.92, 0.03, 9), xf * _at(Vector3(0, h * 0.2, 0)))
	if fill.a > 0.0:
		W._add(bn, _tn(fill, false), W._cyl(r * 0.9, r * 0.9, 0.02, 9), xf * _at(Vector3(0, h - 0.03, 0)))
	if handle:
		W._add(bn, hoop, Decor.torus(r * 0.95, r * 1.0, 10, 4), xf * _at(Vector3(0, h + r * 0.3, 0), Vector3(PI * 0.5, 0, 0)))


## Panier tressé (cône tronqué, bord renforcé) garni de boules (poissons, fruits, fleurs).
static func _basket(bs: Dictionary, bn: Dictionary, xf: Transform3D, r: float, h: float, fill: Color, n: int, rng: RandomNumberGenerator, fish := false) -> void:
	var wk := _tn(BASKET)
	var rim := _tn(Decor.ROPE_DARK, false)
	W._add(bs, wk, W._cyl(r, r * 0.72, h, 8), xf * _at(Vector3(0, h * 0.5, 0)))
	W._add(bn, rim, Decor.torus(r - 0.02, r + 0.02, 10, 4), xf * _at(Vector3(0, h, 0)))
	var fm := _tn(fill, false)
	for k in n:
		var a := rng.randf() * TAU
		var q := Vector3(cos(a) * r * 0.45 * rng.randf(), h + 0.02, sin(a) * r * 0.45 * rng.randf())
		if fish:
			var yaw := rng.randf() * TAU
			W._add(bn, fm, W._ball(r * 0.22, r * 0.62, 6, 3), xf * _at(q, Vector3(PI * 0.5, yaw, 0)))
			W._add(bn, _tn(FISH_DARK, false), W._cyl(0.0, r * 0.14, r * 0.2, 4), xf * _at(q + Vector3(-sin(yaw) * r * 0.36, 0, -cos(yaw) * r * 0.36), Vector3(PI * 0.5, yaw, 0)))
		else:
			W._add(bn, fm, W._ball(r * 0.26, r * 0.4, 6, 3), xf * _at(q))


## Rouleau de cordage (deux tores aplatis).
static func _coil(bn: Dictionary, xf: Transform3D, r: float, col := Decor.KOMO) -> void:
	var m := _tn(col)
	W._add(bn, m, Decor.torus(r * 0.45, r, 12, 5), xf * _at(Vector3(0, r * 0.22, 0), Vector3.ZERO, Vector3(1, 0.5, 1)))
	W._add(bn, m, Decor.torus(r * 0.4, r * 0.92, 12, 5), xf * _at(Vector3(0, r * 0.5, 0), Vector3(0, 0.6, 0), Vector3(1, 0.5, 1)))


## Sac de riz ou de sel noué.
static func _sack(bs: Dictionary, bn: Dictionary, xf: Transform3D, r: float, col := SACK) -> void:
	var m := _tn(col)
	W._add(bs, m, W._ball(r, r * 1.3, 8, 4), xf * _at(Vector3(0, r * 0.6, 0), Vector3.ZERO, Vector3(1, 1, 0.85)))
	W._add(bn, _tn(Decor.ROPE_DARK, false), W._cyl(0.03, 0.05, 0.08, 6), xf * _at(Vector3(0, r * 1.25, 0)))


## Bougie allumée (cire, flamme lumineuse, lueur au sol).
static func _candle(ctx: Dictionary, bs: Dictionary, bn: Dictionary, xf: Transform3D, h: float, col := CANDLE, flame := WAX_GLOW) -> void:
	W._add(bs, _tn(col), W._cyl(0.035, 0.04, h, 7), xf * _at(Vector3(0, h * 0.5, 0)))
	W._add(bn, W._glow(flame, 1.8), W._cyl(0.0, 0.02, 0.07, 5), xf * _at(Vector3(0, h + 0.035, 0)))
	Lueurs.add(bn, xf * Vector3(0, h + 0.03, 0), xf * Vector3.ZERO, Lueurs.tint(flame), 0.55, true)
	_lamp(ctx, xf * Vector3(0, h + 0.05, 0), flame)


## Brûle-encens : bol de bronze, sable, trois bâtonnets aux pointes rouges-or.
static func _incense(bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	W._add(bs, _tn(Decor.BRONZE), W._cyl(0.1, 0.07, 0.09, 8), xf * _at(Vector3(0, 0.045, 0)))
	W._add(bn, _tn(Color("#9A9080"), false), W._cyl(0.085, 0.085, 0.02, 8), xf * _at(Vector3(0, 0.085, 0)))
	for k in 3:
		var a := TAU * k / 3.0
		var p := Vector3(cos(a) * 0.03, 0.09, sin(a) * 0.03)
		var tip := p + Vector3(cos(a) * 0.05, 0.22, sin(a) * 0.05)
		W._limb(bn, _tn(Color("#5A3A2A"), false), p, tip, 0.006, 0.005, 4, xf)
		W._add(bn, W._glow(W.EMBER, 1.6), W._ball(0.012, 0.024, 5, 3), xf * _at(tip))


## Panneau de bois sur poteau (kanban) : planche et colonnes de marques d'encre, face à -X.
static func _sign(bs: Dictionary, bn: Dictionary, xf: Transform3D, h: float, board := Color("#CDB78E"), ink := INK) -> void:
	var pole := _tn(Decor.POLE)
	W._add(bs, pole, W._cyl(0.03, 0.04, h, 6), xf * _at(Vector3(0, h * 0.5, 0)))
	W._add(bs, _tn(board), W._box(Vector3(0.04, 0.5, 0.36)), xf * _at(Vector3(0, h - 0.3, 0)))
	var im := _tn(ink, false)
	for k in 4:
		W._add(bn, im, W._box(Vector3(0.012, 0.07, 0.08 if k % 2 == 0 else 0.05)), xf * _at(Vector3(-0.026, h - 0.12 - k * 0.1, 0.0)))
	W._add(bn, im, W._box(Vector3(0.012, 0.3, 0.012)), xf * _at(Vector3(-0.026, h - 0.3, 0.12)))


## Tas de bûches (deux rangs croisés).
static func _woodpile(bs: Dictionary, bn: Dictionary, xf: Transform3D, snow := false) -> void:
	var bark := _tn(Decor.BARK_PINE)
	var cut := _tn(Color("#D8C09A"), false)
	for row in 2:
		for k in 3 - row:
			var z := (float(k) - (2 - row) * 0.5) * 0.17
			var y := 0.08 + row * 0.15
			W._add(bs, bark, W._cyl(0.08, 0.08, 0.5, 7), xf * _at(Vector3(0, y, z), Vector3(0, 0, PI * 0.5)))
			for sx: float in [-1.0, 1.0]:
				W._add(bn, cut, W._cyl(0.07, 0.07, 0.01, 7), xf * _at(Vector3(sx * 0.252, y, z), Vector3(0, 0, PI * 0.5)))
	if snow:
		W._add(bn, _tn(W.SNOW, false), W._box(Vector3(0.5, 0.05, 0.4)), xf * _at(Vector3(0, 0.33, 0)))


## Yuki-daruma : deux boules de neige, yeux de charbon, seau renversé en chapeau, brindilles.
static func _yukidaruma(bs: Dictionary, bn: Dictionary, xf: Transform3D, s: float) -> void:
	var snow := _tn(W.SNOW)
	var coal := _tn(Toon.SUMI, false)
	W._add(bs, snow, W._ball(0.26 * s, 0.46 * s, 9, 5), xf * _at(Vector3(0, 0.22 * s, 0)))
	W._add(bs, snow, W._ball(0.18 * s, 0.34 * s, 9, 5), xf * _at(Vector3(0, 0.55 * s, 0)))
	for sz: float in [-1.0, 1.0]:
		W._add(bn, coal, W._ball(0.025 * s, 0.05 * s, 5, 3), xf * _at(Vector3(-0.15 * s, 0.6 * s, sz * 0.07 * s)))
	for k in 3:
		W._add(bn, coal, W._ball(0.02 * s, 0.04 * s, 5, 3), xf * _at(Vector3(-0.24 * s, (0.3 - k * 0.08) * s, 0)))
	_tub(bs, bn, xf * _at(Vector3(0, 0.76 * s, 0.03 * s), Vector3(PI, 0, 0.2), Vector3.ONE * s), 0.1, 0.14, Color("#4A3A30"))
	W._limb(bn, _tn(Decor.BARK_PINE, false), Vector3(0, 0.28 * s, 0.22 * s), Vector3(0.1 * s, 0.5 * s, 0.5 * s), 0.012, 0.006, 4, xf)


## Champignons en bouquet (pieds clairs, chapeaux roux).
static func _mushrooms(bs: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator, cap := MUSH_CAP) -> void:
	var stem := _tn(MUSH_STEM, false)
	var cm := _tn(cap)
	for k in rng.randi_range(3, 5):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.14)
		var h := rng.randf_range(0.06, 0.14)
		var r := h * rng.randf_range(0.55, 0.8)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		W._add(bn, stem, W._cyl(0.018, 0.024, h, 5), xf * _at(p + Vector3(0, h * 0.5, 0)))
		W._add(bs, cm, W._ball(r, r * 0.9, 7, 3), xf * _at(p + Vector3(0, h, 0)))


## Coquillages et étoile de mer au sol.
static func _shells(bs: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var sh := _tn(SHELL)
	var st := _tn(STARFISH)
	for k in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.05, 0.22)
		var r := rng.randf_range(0.05, 0.09)
		W._add(bs, sh, W._ball(r, r * 0.5, 7, 3), xf * _at(Vector3(cos(a) * d, 0.0, sin(a) * d), Vector3(0, rng.randf() * TAU, 0), Vector3(1, 1, 0.8)))
	if rng.randf() < 0.7:
		var c := Vector3(rng.randf_range(-0.1, 0.1), 0.02, rng.randf_range(-0.1, 0.1))
		var a0 := rng.randf() * TAU
		for k in 5:
			var a := a0 + TAU * k / 5.0
			W._limb(bn, st, c, c + Vector3(cos(a) * 0.1, 0, sin(a) * 0.1), 0.028, 0.008, 4, xf)


## Jarre (col étroit, panse, couvercle).
static func _jar(bs: Dictionary, bn: Dictionary, xf: Transform3D, r: float, h: float, col: Color) -> void:
	var m := _tn(col)
	W._add(bs, m, W._ball(r, h * 0.9, 9, 5), xf * _at(Vector3(0, h * 0.42, 0)))
	W._add(bs, m, W._cyl(r * 0.45, r * 0.38, h * 0.3, 8), xf * _at(Vector3(0, h * 0.8, 0)))
	W._add(bn, _tn(Decor.ROPE_DARK, false), W._cyl(r * 0.5, r * 0.5, 0.03, 8), xf * _at(Vector3(0, h * 0.95, 0)))


## Bassin de pierre (chōzubachi) : vasque, eau, louche de bambou posée en travers.
static func _basin(bs: Dictionary, bn: Dictionary, xf: Transform3D, stone: Color) -> void:
	W._add(bs, _tn(stone), W._cyl(0.26, 0.22, 0.36, 9), xf * _at(Vector3(0, 0.18, 0)))
	W._add(bn, _tn(Color("#5E8DB6"), false), W._cyl(0.2, 0.2, 0.02, 9), xf * _at(Vector3(0, 0.34, 0)))
	var bam := _tn(Decor.BAMBOO, false)
	W._add(bn, bam, W._cyl(0.012, 0.012, 0.5, 5), xf * _at(Vector3(0, 0.4, 0), Vector3(0, 0, PI * 0.5)))
	W._add(bn, bam, W._cyl(0.035, 0.035, 0.06, 6), xf * _at(Vector3(0.22, 0.4, 0)))


## Petit tōrō de pierre allumé (avec marqueur de lampe), calotte de neige optionnelle.
static func _stone_lantern(ctx: Dictionary, bs: Dictionary, bn: Dictionary, xf: Transform3D, s: float, snow := false) -> void:
	Decor.stone_lantern_into(bs, bn, xf * _at(Vector3.ZERO, Vector3.ZERO, Vector3.ONE * s))
	if snow:
		W._add(bn, _tn(W.SNOW, false), W._ball(0.3 * s, 0.1 * s, 8, 3), xf * _at(Vector3(0, 1.26 * s, 0)))
	_lamp(ctx, xf * Vector3(0, 0.81 * s, 0), Color(1.0, 0.72, 0.4))


## Lanterne de papier au crochet d'une potence : potence fixe dans les lots, lanterne vivante (balancement).
static func _hook_lantern(ctx: Dictionary, bs: Dictionary, xf: Transform3D, color: Color, h := 1.75) -> void:
	var pole_m := _tn(Decor.POLE)
	W._add(bs, pole_m, W._box(Vector3(0.16, 0.08, 0.16)), xf * _at(Vector3(0, 0.04, 0)))
	W._add(bs, pole_m, W._cyl(0.035, 0.045, h, 6), xf * _at(Vector3(0, h * 0.5, 0)))
	W._add(bs, pole_m, W._box(Vector3(0.5, 0.05, 0.05)), xf * _at(Vector3(-0.2, h - 0.04, 0)))
	W._limb(bs, pole_m, Vector3(0, h - 0.3, 0), Vector3(-0.22, h - 0.06, 0), 0.018, 0.018, 4, xf)
	var hook := xf * _at(Vector3(-0.4, h - 0.06, 0))
	var life: Life = _life(ctx)
	life.add("lantern_" + color.to_html(false), _lantern_mesh(color), hook, 0.1, 1.3, Vector3(0, 0, 1))
	Lueurs.add(bs, hook.origin + Vector3(0, -0.37, 0), Vector3(hook.origin.x, 0.0, hook.origin.z), Lueurs.tint(color), 1.2)
	_lamp(ctx, hook.origin + Vector3(0, -0.37, 0), color)


## Bannière sur mât (fixe) dont le tissu flotte (vivant).
static func _flag(ctx: Dictionary, bs: Dictionary, xf: Transform3D, cloth: Color, ink: Color, h := 2.0) -> void:
	var pole_m := _tn(Decor.POLE)
	W._add(bs, pole_m, W._cyl(0.025, 0.035, h, 6), xf * _at(Vector3(0, h * 0.5, 0)))
	W._add(bs, pole_m, W._ball(0.04, 0.08, 6, 3), xf * _at(Vector3(0, h + 0.03, 0)))
	var life: Life = _life(ctx)
	life.add("flag_" + cloth.to_html(false), _flag_mesh(cloth, ink), xf * _at(Vector3(0.0, h - 0.04, 0), Vector3(0, PI * 0.5, 0)), 0.14, 2.1, Vector3(0, 1, 0))


## Étal couvert : quatre poteaux, comptoir, toile tendue en pente, lanterne au coin ; marchandises par monde.
static func _stall(ctx: Dictionary, bs: Dictionary, bn: Dictionary, xf: Transform3D, cloth: Color, rng: RandomNumberGenerator, wid: int) -> void:
	var pole_m := _tn(Decor.POLE)
	var plank := _tn(Decor.PLANK)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var hh := 1.55 if sx < 0.0 else 1.3
			W._add(bs, pole_m, W._cyl(0.03, 0.035, hh, 6), xf * _at(Vector3(sx * 0.42, hh * 0.5, sz * 0.62)))
	W._add(bs, plank, W._box(Vector3(0.7, 0.07, 1.3)), xf * _at(Vector3(0.1, 0.68, 0)))
	for sz: float in [-1.0, 1.0]:
		W._add(bn, pole_m, W._box(Vector3(0.6, 0.05, 0.05)), xf * _at(Vector3(0.1, 0.4, sz * 0.5)))
	W._add(bs, _tn(cloth), W._box(Vector3(1.1, 0.03, 1.5)), xf * _at(Vector3(0.0, 1.5, 0), Vector3(0, 0, -0.28)))
	W._add(bn, _tn(cloth.darkened(0.35), false), W._box(Vector3(0.06, 0.04, 1.52)), xf * _at(Vector3(-0.52, 1.64, 0), Vector3(0, 0, -0.28)))
	# lanterne qui pend au coin sud de l'auvent
	var hook := xf * _at(Vector3(-0.5, 1.6, 0.7))
	_life(ctx).add("lantern_" + WASHI.to_html(false), _lantern_mesh(WASHI), hook, 0.08, 1.5, Vector3(1, 0, 0))
	_lamp(ctx, hook.origin + Vector3(0, -0.37, 0), WASHI)
	Lueurs.add(bn, hook.origin + Vector3(0, -0.37, 0), Vector3(hook.origin.x, 0.0, hook.origin.z), Lueurs.tint(WASHI), 1.0)
	# marchandises sur le comptoir et dessous
	match wid:
		1:
			_basket(bs, bn, xf * _at(Vector3(0.1, 0.715, -0.35)), 0.2, 0.14, FISH, 4, rng, true)
			_basket(bs, bn, xf * _at(Vector3(0.12, 0.715, 0.2)), 0.17, 0.12, Color("#C9A24A"), 3, rng)
			_crate(bs, bn, xf * _at(Vector3(0.2, 0.0, 0.3), Vector3(0, 0.2, 0)), 0.4, 0.3, 0.4)
			_tub(bs, bn, xf * _at(Vector3(0.15, 0.0, -0.3)), 0.13, 0.22, Color("#8A6A43"), true, Color("#4E7A9E"))
		2:
			_basket(bs, bn, xf * _at(Vector3(0.1, 0.715, -0.3)), 0.18, 0.12, Color("#E79AB0"), 5, rng)
			_basket(bs, bn, xf * _at(Vector3(0.12, 0.715, 0.25)), 0.16, 0.12, Color("#F1E3A6"), 4, rng)
			Decor.sake_barrel_into(bs, bn, xf * _at(Vector3(0.15, 0.0, -0.25), Vector3(0, PI * 0.5, 0), Vector3.ONE * 0.6))
		3:
			_woodpile(bs, bn, xf * _at(Vector3(0.15, 0.0, 0.3)), true)
			_tub(bs, bn, xf * _at(Vector3(0.1, 0.715, -0.3)), 0.14, 0.16, Color("#5A4434"))
			W._add(bn, W._glow(W.EMBER, 1.4), W._cyl(0.09, 0.09, 0.02, 8), xf * _at(Vector3(0.1, 0.87, -0.3)))
			_jar(bs, bn, xf * _at(Vector3(0.1, 0.715, 0.25)), 0.11, 0.26, Color("#6E5A50"))
		5:
			_jar(bs, bn, xf * _at(Vector3(0.1, 0.715, -0.3)), 0.1, 0.24, Color("#2A2A33"))
			for k in 3:
				W._add(bn, _tn(WASHI), W._box(Vector3(0.28, 0.012, 0.2)), xf * _at(Vector3(0.1, 0.72 + k * 0.014, 0.25), Vector3(0, k * 0.2, 0)))
			W._brush_into(bs, xf * _at(Vector3(0.2, 0.0, 0.0), Vector3(0, 0, 0.4), Vector3.ONE * 0.5))
		7:
			_shells(bs, bn, xf * _at(Vector3(0.1, 0.715, -0.3)), rng)
			_jar(bs, bn, xf * _at(Vector3(0.15, 0.0, 0.3)), 0.15, 0.36, Color("#7A6A5A"))
			W._add(bn, W._glow(W.CAUSTIC, 1.4), W._ball(0.06, 0.12, 7, 4), xf * _at(Vector3(0.1, 0.78, 0.25)))
			_lamp(ctx, xf * Vector3(0.1, 0.8, 0.25), W.CAUSTIC)
		_:
			_basket(bs, bn, xf * _at(Vector3(0.1, 0.715, -0.3)), 0.18, 0.12, Color("#C9A24A"), 4, rng)
			_crate(bs, bn, xf * _at(Vector3(0.2, 0.0, 0.3)), 0.4, 0.3, 0.4)


## Petit autel : table de pierre ou de bois, offrande, bougies, encens, shimenawa sur deux piquets.
static func _altar(ctx: Dictionary, bs: Dictionary, bn: Dictionary, xf: Transform3D, table: Color, wid: int) -> void:
	var tm := _tn(table)
	W._add(bs, tm, W._box(Vector3(0.6, 0.08, 0.9)), xf * _at(Vector3(0.1, 0.04, 0)))
	W._add(bs, tm, W._box(Vector3(0.44, 0.26, 0.7)), xf * _at(Vector3(0.1, 0.21, 0)))
	W._add(bs, tm, W._box(Vector3(0.62, 0.06, 0.92)), xf * _at(Vector3(0.1, 0.37, 0)))
	W._offering_into(bs, bn, xf * _at(Vector3(0.12, 0.4, 0.0), Vector3.ZERO, Vector3.ONE * 0.8))
	for sz: float in [-1.0, 1.0]:
		_candle(ctx, bs, bn, xf * _at(Vector3(0.0, 0.4, sz * 0.32)), 0.12 if sz < 0.0 else 0.18, CANDLE, W.YOMI_GLOW if wid == 8 else WAX_GLOW)
	_incense(bs, bn, xf * _at(Vector3(0.26, 0.4, -0.1)))
	var pole := _tn(Decor.POLE)
	for sz: float in [-1.0, 1.0]:
		W._add(bs, pole, W._cyl(0.02, 0.025, 0.9, 5), xf * _at(Vector3(0.45, 0.45, sz * 0.5)))
	Decor.shimenawa_into(bs, bn, xf * Vector3(0.45, 0.88, -0.5), xf * Vector3(0.45, 0.88, 0.5))


## Vieille ancre de fer appuyée (jas, verge, bras, anneau).
static func _anchor(bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var iron := _tn(W.IRON)
	var x2 := xf * _at(Vector3(0.1, 0, 0), Vector3(0, 0, 0.3))
	W._add(bs, iron, W._cyl(0.03, 0.035, 0.9, 6), x2 * _at(Vector3(0, 0.45, 0)))
	W._limb(bs, iron, Vector3(0, 0.08, 0), Vector3(0.22, 0.26, 0), 0.03, 0.015, 5, x2)
	W._limb(bs, iron, Vector3(0, 0.08, 0), Vector3(-0.22, 0.26, 0), 0.03, 0.015, 5, x2)
	W._add(bn, iron, W._box(Vector3(0.05, 0.05, 0.5)), x2 * _at(Vector3(0, 0.78, 0)))
	W._add(bn, iron, Decor.torus(0.03, 0.06, 8, 4), x2 * _at(Vector3(0, 0.95, 0), Vector3(PI * 0.5, 0, 0)))


## Cloche de bronze suspendue à un portique de deux poteaux.
static func _bell(bs: Dictionary, bn: Dictionary, xf: Transform3D, s: float) -> void:
	var wood := _tn(Decor.POLE)
	var bronze := _tn(Decor.BRONZE)
	for sz: float in [-1.0, 1.0]:
		W._add(bs, wood, W._cyl(0.035, 0.045, 1.3 * s, 6), xf * _at(Vector3(0, 0.65 * s, sz * 0.42 * s)))
	W._add(bs, wood, W._box(Vector3(0.08 * s, 0.08 * s, 1.0 * s)), xf * _at(Vector3(0, 1.3 * s, 0)))
	W._add(bs, bronze, W._cyl(0.14 * s, 0.2 * s, 0.4 * s, 10), xf * _at(Vector3(0, 0.95 * s, 0)))
	W._add(bn, bronze, W._ball(0.14 * s, 0.14 * s, 8, 3), xf * _at(Vector3(0, 1.15 * s, 0)))
	W._add(bn, _tn(Decor.BRONZE.darkened(0.3), false), Decor.torus(0.17 * s, 0.21 * s, 12, 4), xf * _at(Vector3(0, 0.85 * s, 0)))
	W._add(bn, wood, W._cyl(0.025 * s, 0.025 * s, 0.6 * s, 5), xf * _at(Vector3(-0.3 * s, 0.98 * s, 0), Vector3(0, 0, PI * 0.5)))


## Paire de geta (socques de bois) posées côte à côte.
static func _geta(bn: Dictionary, xf: Transform3D, s := 1.0) -> void:
	var wood := _tn(Color("#C9A86E"))
	var strap := _tn(Toon.SUMI, false)
	for sz: float in [-1.0, 1.0]:
		var x2 := xf * _at(Vector3(0, 0, sz * 0.09 * s), Vector3(0, sz * 0.1, 0))
		W._add(bn, wood, W._box(Vector3(0.24 * s, 0.025 * s, 0.1 * s)), x2 * _at(Vector3(0, 0.05 * s, 0)))
		for dx: float in [-0.07, 0.07]:
			W._add(bn, wood, W._box(Vector3(0.02 * s, 0.04 * s, 0.1 * s)), x2 * _at(Vector3(dx * s, 0.02 * s, 0)))
		W._limb(bn, strap, Vector3(0.06 * s, 0.065 * s, 0), Vector3(-0.02 * s, 0.1 * s, 0.05 * s), 0.006, 0.006, 4, x2)
		W._limb(bn, strap, Vector3(0.06 * s, 0.065 * s, 0), Vector3(-0.02 * s, 0.1 * s, -0.05 * s), 0.006, 0.006, 4, x2)


## Perche à poissons séchés : deux piquets, traverse, poissons pendus.
static func _fish_rack(bs: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var pole := _tn(Decor.POLE)
	for sz: float in [-1.0, 1.0]:
		W._add(bs, pole, W._cyl(0.025, 0.03, 1.2, 5), xf * _at(Vector3(0, 0.6, sz * 0.5)))
	W._add(bs, pole, W._cyl(0.02, 0.02, 1.1, 5), xf * _at(Vector3(0, 1.18, 0), Vector3(PI * 0.5, 0, 0)))
	var fm := _tn(FISH)
	for k in 4:
		var z := -0.36 + k * 0.24 + rng.randf_range(-0.03, 0.03)
		W._add(bs, fm, W._ball(0.05, 0.3, 6, 3), xf * _at(Vector3(0, 0.98, z), Vector3(0, 0, rng.randf_range(-0.1, 0.1))))
		W._add(bn, _tn(FISH_DARK, false), W._cyl(0.0, 0.05, 0.08, 4), xf * _at(Vector3(0, 0.8, z), Vector3(PI, 0, 0)))


## Tas de filets (boule aplatie) et flotteurs de verre.
static func _net_pile(bs: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var nm := _tn(NET)
	W._add(bs, nm, W._ball(0.32, 0.26, 9, 4), xf * _at(Vector3(0.05, 0.0, 0), Vector3(0, rng.randf() * TAU, 0), Vector3(1, 1, 0.8)))
	W._add(bs, nm, W._ball(0.18, 0.18, 7, 3), xf * _at(Vector3(0.2, 0.14, 0.12)))
	for k in 2:
		Decor.glass_float_into(bn, xf * _at(Vector3(0.3 - k * 0.1, 0.06, -0.3 + k * 0.5), Vector3(0, rng.randf() * TAU, 0)), k + 1)


## Rames et gaffe appuyées, seau à côté.
static func _oars(bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var wood := _tn(Decor.PLANK)
	for k in 2:
		var x2 := xf * _at(Vector3(0.3, 0, -0.1 + k * 0.2), Vector3(0, 0, -0.9 + k * 0.08))
		W._add(bs, wood, W._cyl(0.02, 0.022, 1.5, 5), x2 * _at(Vector3(0, 0.75, 0)))
		W._add(bs, wood, W._box(Vector3(0.03, 0.4, 0.12)), x2 * _at(Vector3(0, 1.35, 0)))
	_tub(bs, bn, xf * _at(Vector3(0.15, 0, 0.3)), 0.12, 0.2, Color("#8A6A43"), true, Color("#4E7A9E"))


## Souche de cèdre (anneaux de coupe) coiffée de champignons et de mousse.
static func _stump(bs: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	W._add(bs, _tn(W.CEDAR_BARK), W._cyl(0.22, 0.28, 0.34, 9), xf * _at(Vector3(0, 0.17, 0)))
	W._add(bn, _tn(Color("#C9A878"), false), W._cyl(0.2, 0.2, 0.02, 9), xf * _at(Vector3(0, 0.345, 0)))
	W._add(bn, _tn(Color("#A88A5C"), false), Decor.torus(0.09, 0.12, 10, 4), xf * _at(Vector3(0, 0.355, 0), Vector3.ZERO, Vector3(1, 0.2, 1)))
	W._add(bn, _tn(MOSS, false), W._ball(0.12, 0.08, 7, 3), xf * _at(Vector3(0.14, 0.34, 0.1)))
	_mushrooms(bs, bn, xf * _at(Vector3(0.24, 0.0, -0.14)), rng)


## Chaudron de fer sur trépied, braises dedans.
static func _cauldron(ctx: Dictionary, bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var iron := _tn(W.IRON)
	for k in 3:
		var a := TAU * k / 3.0
		W._limb(bs, iron, Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), Vector3(cos(a) * 0.12, 0.42, sin(a) * 0.12), 0.025, 0.02, 5, xf)
	W._add(bs, iron, W._ball(0.3, 0.44, 10, 5), xf * _at(Vector3(0, 0.5, 0)))
	W._add(bn, iron, Decor.torus(0.24, 0.3, 12, 4), xf * _at(Vector3(0, 0.7, 0)))
	W._add(bn, W._glow(W.EMBER, 1.8), W._cyl(0.22, 0.22, 0.03, 10), xf * _at(Vector3(0, 0.7, 0)))
	Lueurs.add(bn, xf * Vector3(0, 0.75, 0), xf * Vector3.ZERO, Color(1.0, 0.6, 0.26), 1.4, true)
	_lamp(ctx, xf * Vector3(0, 0.8, 0), W.EMBER)


## Torche fichée dans un socle de basalte (flamme ambre).
static func _torch(ctx: Dictionary, bs: Dictionary, bn: Dictionary, xf: Transform3D, h: float) -> void:
	W._add(bs, _tn(W.BASALT), W._cyl(0.14, 0.18, 0.18, 7), xf * _at(Vector3(0, 0.09, 0)))
	W._add(bs, _tn(Decor.POLE), W._cyl(0.03, 0.04, h, 6), xf * _at(Vector3(0, h * 0.5, 0)))
	W._add(bn, _tn(W.IRON, false), W._cyl(0.08, 0.06, 0.12, 7), xf * _at(Vector3(0, h, 0)))
	W._add(bn, W._glow(W.EMBER, 2.0), W._cyl(0.0, 0.1, 0.34, 6), xf * _at(Vector3(0, h + 0.22, 0)))
	W._add(bn, W._glow(W.FLAME_CORE, 2.4), W._cyl(0.0, 0.05, 0.2, 5), xf * _at(Vector3(0, h + 0.16, 0)))
	Lueurs.add(bn, xf * Vector3(0, h + 0.2, 0), xf * Vector3.ZERO, Color(1.0, 0.6, 0.26), 1.8, true)
	_lamp(ctx, xf * Vector3(0, h + 0.2, 0), W.EMBER)


## Nécessaire d'écriture : pierre à encre, bâton d'encre, pot, pinceau couché, feuilles.
static func _inkset(bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var dark := _tn(Color("#2A2A33"))
	W._add(bs, dark, W._box(Vector3(0.3, 0.05, 0.2)), xf * _at(Vector3(0.1, 0.025, -0.15)))
	W._add(bn, _tn(Color("#141418"), false), W._box(Vector3(0.22, 0.012, 0.12)), xf * _at(Vector3(0.08, 0.052, -0.15)))
	W._add(bs, dark, W._box(Vector3(0.04, 0.12, 0.1)), xf * _at(Vector3(0.28, 0.06, -0.2), Vector3(0, 0.3, 0)))
	_jar(bs, bn, xf * _at(Vector3(0.3, 0.0, 0.2)), 0.08, 0.2, Color("#3A4A5E"))
	_small_brush(bn, xf * _at(Vector3(0.12, 0.0, 0.22), Vector3(0, 0.4, 0)), 0.36)
	for k in 3:
		W._add(bn, _tn(WASHI), W._box(Vector3(0.3, 0.012, 0.22)), xf * _at(Vector3(0.15 + k * 0.02, 0.006 + k * 0.014, 0.0), Vector3(0, k * 0.25 - 0.2, 0)))


## Petit pinceau couché (manche de bambou, virole de laque, touffe d'encre) le long de +X local.
static func _small_brush(bn: Dictionary, xf: Transform3D, l: float) -> void:
	var cane := _tn(Color("#B89B5E"))
	W._add(bn, cane, W._cyl(0.016, 0.018, l * 0.72, 6), xf * _at(Vector3(l * 0.14, 0.018, 0), Vector3(0, 0, PI * 0.5)))
	W._add(bn, _tn(Color("#2A1F1A"), false), W._cyl(0.022, 0.024, l * 0.1, 6), xf * _at(Vector3(-l * 0.27, 0.022, 0), Vector3(0, 0, PI * 0.5)))
	W._add(bn, _tn(INK), W._cyl(0.0, 0.022, l * 0.18, 6), xf * _at(Vector3(-l * 0.41, 0.022, 0), Vector3(0, 0, PI * 0.5)))


## Rouleaux de papier empilés (bouts sombres).
static func _scrolls(bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var paper := _tn(WASHI)
	var cap := _tn(Color("#3A2E25"), false)
	var pos := [Vector3(0.12, 0.06, -0.1), Vector3(0.12, 0.06, 0.04), Vector3(0.12, 0.17, -0.03), Vector3(0.3, 0.06, 0.1)]
	for q in pos:
		var p: Vector3 = q
		W._add(bs, paper, W._cyl(0.055, 0.055, 0.5, 8), xf * _at(p, Vector3(PI * 0.5, 0, 0)))
		for sz: float in [-1.0, 1.0]:
			W._add(bn, cap, W._cyl(0.06, 0.06, 0.02, 8), xf * _at(p + Vector3(0, 0, sz * 0.25), Vector3(PI * 0.5, 0, 0)))


## Coussin de soie et perle lumineuse.
static func _pearl(ctx: Dictionary, bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	W._add(bs, _tn(Color("#6E2A4A")), W._box(Vector3(0.4, 0.1, 0.4)), xf * _at(Vector3(0.1, 0.05, 0)))
	W._add(bn, _tn(Toon.GOLD, false), W._box(Vector3(0.42, 0.02, 0.42)), xf * _at(Vector3(0.1, 0.1, 0)))
	W._add(bn, W._glow(W.CAUSTIC, 1.8), W._ball(0.1, 0.2, 9, 5), xf * _at(Vector3(0.1, 0.2, 0)))
	Lueurs.add(bn, xf * Vector3(0.1, 0.2, 0), xf * Vector3(0.1, 0, 0), W.CAUSTIC, 0.9)
	_lamp(ctx, xf * Vector3(0.1, 0.22, 0), W.CAUSTIC)


## Urnes funéraires sombres, l'une renversée.
static func _urns(bs: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	_jar(bs, bn, xf * _at(Vector3(0.1, 0, -0.15)), 0.12, 0.3, Color("#3A3640"))
	_jar(bs, bn, xf * _at(Vector3(0.25, 0, 0.15)), 0.1, 0.26, Color("#4A4650"))
	_jar(bs, bn, xf * _at(Vector3(0.1, 0.1, 0.3), Vector3(0, 0, PI * 0.5)), 0.09, 0.22, Color("#3A3640"))


## Branche morte posée, quelques feuilles sombres.
static func _dead_branch(bs: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var bark := _tn(Color("#4A4448"))
	var a := Vector3(0.05, 0.05, -0.4)
	var c := Vector3(0.3, 0.08, 0.35)
	W._limb(bs, bark, a, c, 0.04, 0.015, 5, xf)
	for k in 3:
		var t := 0.3 + k * 0.25
		var q := a.lerp(c, t)
		W._limb(bs, bark, q, q + Vector3(rng.randf_range(-0.2, 0.2), 0.1, rng.randf_range(-0.1, 0.1)), 0.015, 0.005, 4, xf)


## Fougères rousses (touffes) et pierre moussue.
static func _ferns(ctx: Dictionary, bs: Dictionary, xf: Transform3D, rng: RandomNumberGenerator, col: Color) -> void:
	for k in 3:
		var q := xf * _at(Vector3(0.15 + rng.randf_range(-0.1, 0.1), 0, (k - 1) * 0.22), Vector3(0, rng.randf() * TAU, 0), Vector3(1.1, 0.9, 1.1))
		W._inst(ctx, "dress_fern_" + col.to_html(false), W._tuft_mesh(), W._toon_ds(col), q)
	Decor.rock_into(bs, xf * _at(Vector3(0.32, 0, 0.1), Vector3.ZERO, Vector3.ONE * 0.3), rng.randi() % 10000, W.KURAMA_ROCK)


# ------------------------------------------------------------------ le rebord

## Tablette sous une saynète : planche ou dalle qui prolonge le quai de `ln` (le long de z) sur `depth`.
static func _ledge(bs: Dictionary, bn: Dictionary, wid: int, xf: Transform3D, ln: float, depth: float) -> void:
	var col := _ledge_color(wid)
	var m := _tn(col)
	W._add(bs, m, W._box(Vector3(depth + RIM_IN, 0.1, ln)), xf * _at(Vector3((depth - RIM_IN) * 0.5, -0.06, 0)))
	# ce qui la porte : pieux dans l'eau au port, bloc de pierre ou de roche ailleurs (jusque sous la surface)
	if wid == 1:
		var pile := _tn(Decor.PILE)
		for sz: float in [-1.0, 1.0]:
			W._add(bs, pile, W._cyl(0.06, 0.075, 0.75, 6), xf * _at(Vector3(depth - 0.12, -0.46, sz * (ln * 0.5 - 0.12))))
	else:
		W._add(bs, _tn(col.darkened(0.3)), W._box(Vector3(depth - 0.08, 0.5, ln - 0.14)), xf * _at(Vector3((depth - RIM_IN) * 0.5 - 0.02, -0.36, 0)))
	match wid:
		3:
			W._add(bn, _tn(W.SNOW, false), W._box(Vector3(depth + RIM_IN - 0.04, 0.03, ln - 0.06)), xf * _at(Vector3((depth - RIM_IN) * 0.5, 0.004, 0)))
		1:
			# deux lambourdes sous la planche
			for sz: float in [-1.0, 1.0]:
				W._add(bn, _tn(col.darkened(0.35), false), W._box(Vector3(depth + RIM_IN - 0.06, 0.06, 0.05)), xf * _at(Vector3((depth - RIM_IN) * 0.5, -0.14, sz * (ln * 0.5 - 0.1))))


static func _ledge_color(wid: int) -> Color:
	match wid:
		1:
			return Color("#8A6A43")
		2:
			return W.NIGHT_STONE
		3:
			return Color("#7E7B80")
		4:
			return W.BASALT
		5:
			return Color("#2A2A33")
		6:
			return W.KURAMA_ROCK
		7:
			return W.SAND_BANK
		_:
			return W.YOMI_GRAVE_CAP


## Saynètes du rebord par monde : [nom, longueur le long du bord, profondeur, hauteur (0 : bas, 1 : haut), poids].
static func _rim_kinds(wid: int) -> Array:
	match wid:
		1:
			return [["crates", 1.0, 0.6, 0, 3], ["barrels", 1.1, 0.6, 0, 2], ["baskets", 1.1, 0.5, 0, 3], ["nets", 1.0, 0.7, 0, 2],
				["lantern", 0.6, 0.5, 1, 2], ["stall", 1.6, 1.1, 1, 1], ["rope", 0.8, 0.5, 0, 2], ["sign", 0.6, 0.4, 1, 1],
				["oars", 0.9, 0.6, 1, 1], ["sacks", 0.9, 0.6, 0, 2], ["fishrack", 1.2, 0.5, 1, 1], ["flag", 0.5, 0.4, 1, 1]]
		2:
			return [["bamboo", 0.9, 0.6, 1, 2], ["tanzaku", 0.8, 0.5, 1, 2], ["lantern", 0.6, 0.5, 1, 3], ["fox", 1.1, 0.6, 0, 2],
				["basin", 0.8, 0.6, 0, 2], ["stones", 1.0, 0.6, 0, 2], ["sake", 1.0, 0.6, 0, 2], ["bell", 1.0, 0.5, 1, 1],
				["geta", 0.6, 0.4, 0, 1], ["stall", 1.6, 1.1, 1, 1], ["altar", 1.2, 0.9, 0, 1]]
		3:
			return [["yuki", 0.8, 0.6, 0, 2], ["snowlantern", 0.8, 0.6, 1, 2], ["woodpile", 0.9, 0.6, 0, 2], ["komo", 0.8, 0.6, 1, 1],
				["crates", 1.0, 0.6, 0, 2], ["wagasa", 0.9, 0.6, 0, 2], ["hibachi", 0.8, 0.6, 0, 2], ["jizo", 0.8, 0.5, 0, 2],
				["bell", 1.0, 0.5, 1, 1], ["stall", 1.6, 1.1, 1, 1], ["sled", 1.1, 0.6, 0, 1]]
		4:
			return [["cauldron", 0.9, 0.7, 0, 2], ["ingots", 0.9, 0.6, 0, 2], ["chains", 1.0, 0.6, 0, 2], ["anvil", 1.0, 0.7, 0, 1],
				["mask", 0.7, 0.5, 1, 1], ["torch", 0.6, 0.5, 1, 3], ["basalt", 1.0, 0.7, 0, 2], ["tubs", 1.0, 0.6, 0, 2],
				["spikes", 0.9, 0.6, 1, 1], ["flag", 0.5, 0.4, 1, 1]]
		5:
			return [["inkset", 0.9, 0.6, 0, 3], ["papers", 1.0, 0.6, 0, 2], ["scrolls", 0.9, 0.6, 0, 2], ["byobu", 1.1, 0.5, 1, 1],
				["seal", 0.8, 0.6, 0, 2], ["brushes", 0.9, 0.6, 1, 2], ["lantern", 0.6, 0.5, 1, 2], ["jars", 1.0, 0.6, 0, 2],
				["stall", 1.6, 1.1, 1, 1], ["sign", 0.6, 0.4, 1, 1]]
		6:
			return [["stump", 0.9, 0.7, 0, 3], ["tengu", 0.7, 0.5, 1, 1], ["fans", 0.8, 0.5, 0, 2], ["logs", 1.0, 0.6, 1, 2],
				["mossrocks", 1.0, 0.7, 0, 2], ["stonelantern", 0.8, 0.6, 1, 2], ["shime", 0.9, 0.5, 1, 1], ["geta", 0.7, 0.5, 0, 1],
				["ferns", 0.9, 0.6, 0, 3], ["altar", 1.2, 0.9, 0, 1], ["lantern", 0.6, 0.5, 1, 1]]
		7:
			return [["coral", 1.0, 0.7, 0, 3], ["clams", 1.0, 0.6, 0, 2], ["pearl", 0.8, 0.6, 0, 2], ["amphora", 1.0, 0.6, 0, 2],
				["anchor", 0.9, 0.6, 1, 1], ["shells", 0.9, 0.6, 0, 3], ["kelp", 0.9, 0.6, 1, 2], ["turtle", 1.1, 0.8, 0, 1],
				["stall", 1.6, 1.1, 1, 1], ["baskets", 1.1, 0.5, 0, 1]]
		_:
			return [["candles", 0.9, 0.6, 0, 3], ["bones", 1.0, 0.6, 0, 2], ["urns", 1.0, 0.6, 0, 2], ["sotoba", 0.8, 0.5, 1, 2],
				["jizo", 0.8, 0.5, 0, 2], ["offerings", 1.0, 0.6, 0, 2], ["deadbranch", 1.0, 0.6, 0, 2], ["lantern", 0.6, 0.5, 1, 2],
				["altar", 1.2, 0.9, 0, 1], ["flag", 0.5, 0.4, 1, 1]]


## Le rebord : des saynètes le long des bords ouest et est des plateformes qui touchent le cadre.
static func _rim(wid: int, ctx: Dictionary, plats: Array, frame: Rect2, kind: String, rng: RandomNumberGenerator, dens: float) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var avoid: Array = ctx["avoid"]
	var kinds := _rim_kinds(wid)
	var total_w := 0.0
	for kd in kinds:
		total_w += float((kd as Array)[4])
	var shrine := kind == "shrine"
	for s: float in [-1.0, 1.0]:
		var x_edge: float = frame.end.x if s > 0.0 else frame.position.x
		# segments de bord : plateformes dont le côté touche le cadre
		var segs: Array = []
		for r in plats:
			var rr: Rect2 = r
			var side: float = rr.end.x if s > 0.0 else rr.position.x
			if absf(side - x_edge) < 0.08 and rr.size.y > 1.2:
				segs.append(Vector2(rr.position.y + 0.45, rr.end.y - 0.45))
		segs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var last := ""
		for sg in segs:
			var seg: Vector2 = sg
			var z0: float = seg.x
			if shrine:
				z0 = maxf(z0, W.SHRINE_NEAR_Z + 0.3)
			var z := z0 + rng.randf_range(0.0, 0.4) / dens
			var guard := 0
			while z < seg.y - 0.5 and guard < 40:
				guard += 1
				var low := z > LOW_Z - 0.6
				# tirage pondéré, jamais deux fois de suite la même, basse au bas de l'écran
				var pick: Array = []
				for attempt in 8:
					var t := rng.randf() * total_w
					for kd in kinds:
						var ka: Array = kd
						t -= float(ka[4])
						if t <= 0.0:
							pick = ka
							break
					if pick.is_empty():
						pick = kinds[0]
					if String(pick[0]) != last and not (low and int(pick[3]) == 1):
						break
					pick = []
				if pick.is_empty():
					z += 1.0
					continue
				var ln: float = pick[1]
				var depth: float = pick[2]
				var zc := z + ln * 0.5
				if zc + ln * 0.5 > seg.y - 0.2:
					break
				var p := Vector2(x_edge + s * (RIM_IN + depth * 0.5), zc)
				# place libre (torii, départ, sanctuaire) : les abords ne sont pas encore posés
				if W._ok(ctx, p, 0.02, 0.0):
					var yaw: float = 0.0 if s > 0.0 else PI
					var xf := _at(Vector3(x_edge + s * RIM_IN, 0.0, zc), Vector3(0, yaw, 0))
					_ledge(bs, bn, wid, xf, ln, depth)
					_vignette(String(pick[0]), wid, ctx, bs, bn, xf, rng, s)
					last = String(pick[0])
					# la bande proche des abords (0,36 à 0,9 m du bord) évite la saynète ; la bande moyenne
					# (au-delà de 1,15 m) reste libre : des cercles courts, deux pour les longues tablettes
					var ra := depth * 0.5 + 0.3
					if ln > 1.2:
						for sz: float in [-1.0, 1.0]:
							avoid.append(Vector3(p.x, p.y + sz * ln * 0.25, maxf(ra, ln * 0.25 + 0.1)))
					else:
						avoid.append(Vector3(p.x, p.y, maxf(ra, ln * 0.5)))
					W._take(ctx, p)
				z += ln + rng.randf_range(0.25, 0.8) / dens
			await W._cut(ctx)


## Une saynète en `xf` (origine au bord du quai, +X vers l'extérieur, +Z le long du bord).
static func _vignette(name: String, wid: int, ctx: Dictionary, bs: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator, _s: float) -> void:
	var ry := rng.randf_range(-0.25, 0.25)
	match name:
		"crates":
			var snow := wid == 3
			_crate(bs, bn, _j(xf, 0.3, -0.22, ry), 0.44, 0.36, 0.44)
			_crate(bs, bn, _j(xf, 0.26, 0.26, ry + 0.3), 0.36, 0.28, 0.36, CRATE_DARK)
			_crate(bs, bn, _j(xf, 0.3, -0.18, ry + 0.15) * _at(Vector3(0, 0.36, 0)), 0.3, 0.24, 0.3)
			if snow:
				W._add(bn, _tn(W.SNOW, false), W._box(Vector3(0.3, 0.05, 0.3)), _j(xf, 0.3, -0.18, ry + 0.15) * _at(Vector3(0, 0.62, 0)))
				W._add(bn, _tn(W.SNOW, false), W._box(Vector3(0.36, 0.04, 0.36)), _j(xf, 0.26, 0.26, ry + 0.3) * _at(Vector3(0, 0.3, 0)))
		"barrels":
			Decor.sake_barrel_into(bs, bn, _j(xf, 0.3, -0.25, PI * 0.5 + ry, 0.7), Toon.PRUSSIAN)
			Decor.sake_barrel_into(bs, bn, _j(xf, 0.28, 0.2, PI * 0.5 + ry + 0.5, 0.62))
			_tub(bs, bn, _j(xf, 0.14, 0.42, ry), 0.1, 0.16, Color("#8A6A43"), true, Color("#4E7A9E"))
		"baskets":
			_basket(bs, bn, _j(xf, 0.28, -0.32, ry), 0.2, 0.16, FISH, 5, rng, true)
			_basket(bs, bn, _j(xf, 0.26, 0.05, ry), 0.17, 0.14, FISH, 4, rng, true)
			_basket(bs, bn, _j(xf, 0.25, 0.38, ry), 0.15, 0.2, Color("#C9A24A"), 3, rng)
			_coil(bn, _j(xf, 0.12, -0.05, ry), 0.09)
		"nets":
			_net_pile(bs, bn, _j(xf, 0.3, 0.0, ry), rng)
			_coil(bn, _j(xf, 0.14, 0.4, ry), 0.1)
		"lantern":
			_hook_lantern(ctx, bs, _j(xf, 0.3, 0.0, 0.0), _lantern_color(wid))
		"stall":
			_stall(ctx, bs, bn, _j(xf, 0.55, 0.0, 0.0), _stall_cloth(wid), rng, wid)
		"rope":
			var top := W._bitt_into(bs, bn, xf * Vector3(0.28, -0.1, -0.2), 0.5)
			_coil(bn, _j(xf, 0.22, 0.25, ry), 0.14)
			W._rope(bn, _tn(Decor.KOMO, false), top - Vector3(0, 0.15, 0), xf * Vector3(0.24, 0.1, 0.25), 0.1, 0.014)
		"sign":
			_sign(bs, bn, _j(xf, 0.25, 0.0, 0.0), 1.3 + rng.randf() * 0.3, _ledge_color(wid).lightened(0.35) if wid != 5 else WASHI)
		"oars":
			_oars(bs, bn, _j(xf, 0.1, 0.0, 0.0))
		"sacks":
			_sack(bs, bn, _j(xf, 0.3, -0.22, ry), 0.2)
			_sack(bs, bn, _j(xf, 0.28, 0.2, ry + 0.4), 0.17)
			_sack(bs, bn, _j(xf, 0.3, 0.0, ry) * _at(Vector3(0, 0.34, 0)), 0.16)
		"fishrack":
			_fish_rack(bs, bn, _j(xf, 0.3, 0.0, 0.0), rng)
		"flag":
			var nc: Array = W._nobori_colors(wid)
			_flag(ctx, bs, _j(xf, 0.25, 0.0, 0.0), nc[0], nc[1], 1.9 + rng.randf() * 0.3)
		"bamboo":
			Decor.bamboo_into(bs, bn, _j(xf, 0.35, 0.0, rng.randf() * TAU, 0.7), rng.randi() % 10000)
		"tanzaku":
			W._tanzaku_into(bs, _j(xf, 0.3, 0.0, 0.0), rng)
		"fox":
			W._kitsune_into(bs, _j(xf, 0.3, -0.3, PI if _s > 0.0 else 0.0, 0.7))
			W._kitsune_into(bs, _j(xf, 0.3, 0.3, PI if _s > 0.0 else 0.0, 0.7))
			W._offering_into(bs, bn, _j(xf, 0.26, 0.0, 0.0, 0.7))
		"basin":
			_basin(bs, bn, _j(xf, 0.32, 0.0, 0.0), W.NIGHT_STONE if wid == 2 else W.KURAMA_ROCK)
			_geta(bn, _j(xf, 0.14, 0.3, 1.2), 0.8)
		"stones":
			for k in 3:
				var sc := rng.randf_range(0.22, 0.4)
				Decor.rock_into(bs, _j(xf, 0.3 + rng.randf_range(-0.1, 0.1), (k - 1) * 0.3, 0.0, sc), rng.randi() % 10000, W.NIGHT_STONE)
				if k == 1:
					W._add(bn, _tn(MOSS, false), W._ball(0.1, 0.06, 7, 3), _j(xf, 0.3, 0.0, 0.0) * _at(Vector3(0.05, sc * 0.3, 0.05)))
		"sake":
			for k in 2:
				Decor.sake_barrel_into(bs, bn, _j(xf, 0.3, (k - 0.5) * 0.4, PI * 0.5 + ry, 0.6), Color("#6E2A24"))
			Decor.sake_barrel_into(bs, bn, _j(xf, 0.3, 0.0, PI * 0.5 + ry, 0.6) * _at(Vector3(0, 0.35, 0)), Color("#6E2A24"))
		"bell":
			_bell(bs, bn, _j(xf, 0.3, 0.0, 0.0), 0.8)
		"geta":
			_geta(bn, _j(xf, 0.3, 0.0, ry), 1.1 if wid == 6 else 0.9)
			if wid == 6:
				_geta(bn, _j(xf, 0.3, 0.26, ry + 0.4), 1.0)
		"altar":
			_altar(ctx, bs, bn, _j(xf, 0.1, 0.0, 0.0), _ledge_color(wid).lightened(0.2), wid)
		"yuki":
			_yukidaruma(bs, bn, _j(xf, 0.32, 0.0, 0.0), rng.randf_range(0.8, 1.0))
		"snowlantern":
			_stone_lantern(ctx, bs, bn, _j(xf, 0.35, 0.0, 0.0), 0.75, true)
		"stonelantern":
			_stone_lantern(ctx, bs, bn, _j(xf, 0.35, 0.0, 0.0), 0.8, false)
		"woodpile":
			_woodpile(bs, bn, _j(xf, 0.3, 0.0, PI * 0.5), wid == 3)
		"komo":
			# tronc emmailloté de paille (komomaki) contre l'hiver, neige au sommet
			W._add(bs, _tn(Decor.BARK_PINE), W._cyl(0.1, 0.12, 1.4, 7), _j(xf, 0.3, 0.0) * _at(Vector3(0, 0.7, 0)))
			W._add(bs, _tn(Decor.KOMO), W._cyl(0.16, 0.14, 0.5, 8), _j(xf, 0.3, 0.0) * _at(Vector3(0, 0.6, 0)))
			for y: float in [0.42, 0.78]:
				W._add(bn, _tn(Decor.ROPE_DARK, false), W._cyl(0.165, 0.165, 0.03, 8), _j(xf, 0.3, 0.0) * _at(Vector3(0, y, 0)))
			W._add(bn, _tn(W.SNOW, false), W._ball(0.14, 0.08, 7, 3), _j(xf, 0.3, 0.0) * _at(Vector3(0, 1.4, 0)))
		"wagasa":
			W._wagasa_into(bs, _j(xf, 0.3, -0.15, ry), true, Color("#6E2A24") if rng.randf() < 0.5 else Color("#2E4A6B"))
			W._wagasa_into(bs, _j(xf, 0.2, 0.3, ry), false, Color("#2E4A6B"))
		"hibachi":
			# brasero de bois carré, cendre et braises
			W._add(bs, _tn(Color("#5A4434")), W._box(Vector3(0.44, 0.3, 0.44)), _j(xf, 0.3, 0.0, ry) * _at(Vector3(0, 0.15, 0)))
			W._add(bn, _tn(Color("#9A9080"), false), W._box(Vector3(0.36, 0.02, 0.36)), _j(xf, 0.3, 0.0, ry) * _at(Vector3(0, 0.3, 0)))
			W._add(bn, W._glow(W.EMBER, 1.6), W._cyl(0.1, 0.1, 0.03, 8), _j(xf, 0.3, 0.0, ry) * _at(Vector3(0, 0.31, 0)))
			Lueurs.add(bn, xf * Vector3(0.3, 0.35, 0), xf * Vector3(0.3, 0, 0), Color(1.0, 0.6, 0.26), 0.9, true)
			_lamp(ctx, xf * Vector3(0.3, 0.4, 0), W.EMBER)
			_tub(bs, bn, _j(xf, 0.16, 0.38, ry), 0.09, 0.14, Color("#5A4434"))
		"jizo":
			W._jizo_into(bs, _j(xf, 0.3, -0.15, PI if _s > 0.0 else 0.0, 0.7))
			W._offering_into(bs, bn, _j(xf, 0.26, 0.22, 0.0, 0.6))
		"sled":
			var wood := _tn(Decor.PLANK)
			for sz: float in [-1.0, 1.0]:
				W._add(bs, wood, W._box(Vector3(0.06, 0.06, 1.0)), _j(xf, 0.3, 0.0, ry) * _at(Vector3(sz * 0.2, 0.05, 0)))
			W._add(bs, wood, W._box(Vector3(0.5, 0.04, 0.8)), _j(xf, 0.3, 0.0, ry) * _at(Vector3(0, 0.12, 0)))
			_sack(bs, bn, _j(xf, 0.3, 0.0, ry) * _at(Vector3(0, 0.14, -0.15)), 0.15, W.SNOW)
			_woodpile(bs, bn, _j(xf, 0.3, 0.25, ry) * _at(Vector3(0, 0.14, 0)), false)
		"cauldron":
			_cauldron(ctx, bs, bn, _j(xf, 0.35, 0.0, 0.0))
		"ingots":
			W._ingots_into(bs, bn, _j(xf, 0.3, 0.0, ry))
		"chains":
			var iron := _tn(W.IRON)
			W._add(bs, iron, W._cyl(0.08, 0.1, 0.6, 6), _j(xf, 0.3, -0.3) * _at(Vector3(0, 0.3, 0)))
			W._rope(bn, iron, xf * Vector3(0.3, 0.6, -0.3), xf * Vector3(0.32, 0.05, 0.35), 0.15, 0.025)
			for k in 3:
				W._add(bn, iron, Decor.torus(0.05, 0.09, 8, 4), _j(xf, 0.3 + k * 0.05, 0.3 + k * 0.08) * _at(Vector3(0, 0.03 + k * 0.03, 0), Vector3(PI * 0.5, k * 0.7, 0)))
		"anvil":
			W._anvil_into(bs, bn, _j(xf, 0.35, 0.0, PI * 0.5 + ry, 0.75))
		"mask":
			var pole := _tn(Decor.POLE)
			W._add(bs, pole, W._cyl(0.03, 0.04, 1.4, 6), _j(xf, 0.3, 0.0) * _at(Vector3(0, 0.7, 0)))
			W._oni_mask_into(bs, bn, _j(xf, 0.26, 0.0, -PI * 0.5 if _s > 0.0 else PI * 0.5, 0.6) * _at(Vector3(0, 1.2, 0)))
		"torch":
			_torch(ctx, bs, bn, _j(xf, 0.3, 0.0, 0.0), 1.1 + rng.randf() * 0.3)
		"basalt":
			var m := _tn(W.BASALT)
			for k in 3:
				var hh := rng.randf_range(0.2, 0.5)
				var rr := rng.randf_range(0.1, 0.16)
				W._add(bs, m, W._cyl(rr, rr * 1.05, hh, 6), _j(xf, 0.3 + rng.randf_range(-0.08, 0.08), (k - 1) * 0.28, rng.randf()) * _at(Vector3(0, hh * 0.5, 0)))
			W._add(bn, W._glow(W.LAVA_GOLD, 1.0), W._box(Vector3(0.3, 0.012, 0.03)), _j(xf, 0.3, 0.1, 0.6) * _at(Vector3(0, 0.01, 0)))
		"tubs":
			_tub(bs, bn, _j(xf, 0.3, -0.25, ry), 0.16, 0.3, Color("#3A2E28"), false, Color("#141418"))
			_tub(bs, bn, _j(xf, 0.3, 0.2, ry), 0.13, 0.22, Color("#3A2E28"))
			W._add(bn, W._glow(W.EMBER, 1.2), W._cyl(0.11, 0.11, 0.02, 8), _j(xf, 0.3, 0.2, ry) * _at(Vector3(0, 0.21, 0)))
		"spikes":
			var m := _tn(W.BASALT)
			for k in 3:
				var base := Vector3(0.3 + rng.randf_range(-0.1, 0.1), 0, (k - 1) * 0.3)
				var h := rng.randf_range(0.6, 1.3)
				W._limb(bs, m, base, base + Vector3(rng.randf_range(-0.1, 0.25), h, rng.randf_range(-0.15, 0.15)), 0.14, 0.015, 5, xf)
			W._add(bn, W._glow(W.HALO, 0.7), W._cyl(0.4, 0.4, 0.015, 10), _j(xf, 0.3, 0.0) * _at(Vector3(0, 0.008, 0)))
		"inkset":
			_inkset(bs, bn, _j(xf, 0.1, 0.0, ry))
		"papers":
			W._papers_into(bn, Vector2(xf.origin.x, xf.origin.z) + Vector2(xf.basis.x.x, xf.basis.x.z) * 0.3, rng, 5, 0.0, 0.3)
			W._add(bs, _tn(WASHI), W._box(Vector3(0.3, 0.16, 0.24)), _j(xf, 0.32, 0.25, ry) * _at(Vector3(0, 0.08, 0)))
			W._add(bn, _tn(Decor.ROPE_DARK, false), W._box(Vector3(0.32, 0.02, 0.03)), _j(xf, 0.32, 0.25, ry) * _at(Vector3(0, 0.165, 0)))
		"scrolls":
			_scrolls(bs, bn, _j(xf, 0.1, 0.0, ry))
		"byobu":
			W._byobu_into(bs, _j(xf, 0.4, 0.0, PI * 0.5 if _s > 0.0 else -PI * 0.5, 0.6))
		"seal":
			W._seal_into(bs, _j(xf, 0.3, 0.0, ry, 0.7))
		"brushes":
			for k in 3:
				W._brush_into(bs, _j(xf, 0.3 + rng.randf_range(-0.08, 0.08), (k - 1) * 0.26, rng.randf() * TAU, 0.6) * _at(Vector3.ZERO, Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))))
		"jars":
			_jar(bs, bn, _j(xf, 0.3, -0.25, ry), 0.14, 0.34, Color("#2A2A33"))
			_jar(bs, bn, _j(xf, 0.28, 0.2, ry), 0.11, 0.26, Color("#3A4A5E"))
			W._add(bn, _tn(INK, false), W._cyl(0.12, 0.12, 0.012, 9), _j(xf, 0.3, 0.45) * _at(Vector3(0, 0.006, 0), Vector3.ZERO, Vector3(1, 1, 0.6)))
		"stump":
			_stump(bs, bn, _j(xf, 0.34, 0.0, ry), rng)
		"tengu":
			var pole := _tn(Decor.POLE)
			W._add(bs, pole, W._cyl(0.03, 0.04, 1.4, 6), _j(xf, 0.3, 0.0) * _at(Vector3(0, 0.7, 0)))
			W._tengu_mask_into(bs, bn, _j(xf, 0.26, 0.0, -PI * 0.5 if _s > 0.0 else PI * 0.5, 0.6) * _at(Vector3(0, 1.2, 0)))
		"fans":
			W._hauchiwa_into(bs, _j(xf, 0.3, -0.2, ry, 0.8) * _at(Vector3.ZERO, Vector3(0, 0, 0.5)))
			W._hauchiwa_into(bs, _j(xf, 0.3, 0.2, ry + 0.4, 0.8) * _at(Vector3.ZERO, Vector3(0, 0, -0.4)))
		"logs":
			W._kunai_post_into(bs, bn, _j(xf, 0.3, 0.0, ry), rng)
		"mossrocks":
			for k in 2:
				var sc := rng.randf_range(0.3, 0.45)
				Decor.rock_into(bs, _j(xf, 0.32, (k - 0.5) * 0.45, 0.0, sc), rng.randi() % 10000, W.KURAMA_ROCK)
				W._add(bn, _tn(MOSS, false), W._ball(sc * 0.4, sc * 0.2, 7, 3), _j(xf, 0.32, (k - 0.5) * 0.45) * _at(Vector3(0.03, sc * 0.3, -0.03)))
			_mushrooms(bs, bn, _j(xf, 0.18, 0.0, 0.0), rng)
		"shime":
			var pole := _tn(Decor.POLE)
			for sz: float in [-1.0, 1.0]:
				W._add(bs, pole, W._cyl(0.025, 0.03, 1.1, 5), _j(xf, 0.3, sz * 0.4) * _at(Vector3(0, 0.55, 0)))
			Decor.shimenawa_into(bs, bn, xf * Vector3(0.3, 1.05, -0.4), xf * Vector3(0.3, 1.05, 0.4))
		"ferns":
			_ferns(ctx, bs, _j(xf, 0.1, 0.0, 0.0), rng, W.FERN_RUST)
		"coral":
			W._coral_into(bs, _j(xf, 0.32, -0.1, ry, 0.6), rng, Color("#C9705A") if rng.randf() < 0.5 else Color("#D9A05A"))
			W._coral_into(bs, _j(xf, 0.3, 0.3, ry, 0.45), rng, Color("#B86A8A"))
			_shells(bs, bn, _j(xf, 0.15, 0.2), rng)
		"clams":
			W._clam_into(bs, bn, _j(xf, 0.33, 0.0, -PI * 0.5 if _s > 0.0 else PI * 0.5, 0.5))
			_shells(bs, bn, _j(xf, 0.15, -0.3), rng)
		"pearl":
			_pearl(ctx, bs, bn, _j(xf, 0.1, 0.0, ry))
		"amphora":
			_jar(bs, bn, _j(xf, 0.3, -0.25, ry), 0.15, 0.4, Color("#7A6A5A"))
			_jar(bs, bn, _j(xf, 0.3, 0.2, ry), 0.12, 0.3, Color("#8A7A6A"))
			W._add(bn, _tn(W.SEA_WEED, false), W._ball(0.1, 0.06, 7, 3), _j(xf, 0.3, -0.25) * _at(Vector3(0.1, 0.0, 0.1)))
		"anchor":
			_anchor(bs, bn, _j(xf, 0.2, 0.0, 0.0))
			_coil(bn, _j(xf, 0.3, 0.3, ry), 0.12, Decor.ROPE_DARK)
		"shells":
			_shells(bs, bn, _j(xf, 0.25, -0.2), rng)
			_shells(bs, bn, _j(xf, 0.3, 0.25), rng)
		"kelp":
			W._kelp_into(bs, _j(xf, 0.33, 0.0, ry, 0.7), rng, 1.2)
		"turtle":
			W._kame_into(bs, bn, _j(xf, 0.4, 0.0, PI if _s > 0.0 else 0.0, 0.42))
		"candles":
			for k in rng.randi_range(3, 5):
				_candle(ctx, bs, bn, _j(xf, 0.18 + rng.randf() * 0.25, rng.randf_range(-0.35, 0.35)), rng.randf_range(0.06, 0.2), CANDLE, W.YOMI_GLOW if k % 2 == 0 else WAX_GLOW)
		"bones":
			W._bones_into(bs, Vector2(xf.origin.x, xf.origin.z) + Vector2(xf.basis.x.x, xf.basis.x.z) * 0.3, rng, 0.0, 0.6)
		"urns":
			_urns(bs, bn, _j(xf, 0.1, 0.0, ry))
		"sotoba":
			W._sotoba_into(bs, _j(xf, 0.3, 0.0, PI * 0.5 if _s > 0.0 else -PI * 0.5), rng)
		"offerings":
			W._offering_into(bs, bn, _j(xf, 0.3, -0.2, 0.0, 0.8))
			_incense(bs, bn, _j(xf, 0.28, 0.2, 0.0))
			_candle(ctx, bs, bn, _j(xf, 0.15, 0.35), 0.1, CANDLE, W.YOMI_GLOW)
		"deadbranch":
			_dead_branch(bs, bn, _j(xf, 0.1, 0.0, ry), rng)
			W._add(bn, _tn(W.ASH, false), W._ball(0.12, 0.05, 7, 3), _j(xf, 0.3, 0.1))
		_:
			pass


## Repère d'une pièce de la saynète : décalée de (dx, dz), tournée de `yaw`, à l'échelle `sc`.
static func _j(xf: Transform3D, dx: float, dz: float, yaw := 0.0, sc := 1.0) -> Transform3D:
	return xf * _at(Vector3(dx, 0, dz), Vector3(0, yaw, 0), Vector3.ONE * sc)


static func _lantern_color(wid: int) -> Color:
	match wid:
		2:
			return Color("#F2C98A")
		5:
			return WASHI
		6:
			return Color("#F2B88A")
		8:
			return W.YOMI_PAPER
		_:
			return Color("#FBE3B0")


static func _stall_cloth(wid: int) -> Color:
	match wid:
		1:
			return Color("#2E4A6B")
		2:
			return Color("#4A3A6E")
		3:
			return Color("#6E3A3A")
		5:
			return Color("#3A3A48")
		7:
			return Color("#2A5A6E")
		_:
			return Color("#5A4A3A")


# ------------------------------------------------------------------ le sol de la zone de jeu

## Décalques et petits reliefs dans les plateformes (jamais sur une pièce de décor, ni derrière le torii).
static func _floor(wid: int, ctx: Dictionary, plats: Array, kind: String, rng: RandomNumberGenerator, dens: float) -> void:
	var pieces: Array = ctx.get("pieces", [])
	var fps: Array = []
	for pc in pieces:
		var pa: Array = pc
		var fp: Rect2 = pa[0]
		fps.append(fp.grow(0.25))
	var per_m2 := 0.4 * dens
	var n_kinds := _floor_kinds(wid).size()
	for r in plats:
		var rr: Rect2 = r
		var inner := rr.grow(-0.4)
		if not inner.has_area():
			continue
		var n := int(inner.get_area() * per_m2) + (1 if rng.randf() < 0.5 else 0)
		# un tapis ou une natte au plus par plateforme (grands éléments : au centre de la plateforme)
		var mat_done := false
		for i in n:
			var p := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
			var bad := false
			for f in fps:
				var fr: Rect2 = f
				if fr.has_point(p):
					bad = true
					break
			if bad or W._taken_near(ctx, p, 0.75):
				continue
			var avoid: Array = ctx["avoid"]
			for a in avoid:
				var av: Vector3 = a
				if Vector2(av.x, av.y).distance_to(p) < av.z:
					bad = true
					break
			if bad:
				continue
			var k := rng.randi() % n_kinds
			if k == 0 and (mat_done or kind == "shrine" or inner.size.x < 2.2 or inner.size.y < 2.2):
				k = 1 + rng.randi() % (n_kinds - 1)
			if k == 0:
				mat_done = true
			_floor_item(wid, ctx, p, k, rng)
			W._take(ctx, p)


## Sortes d'éléments de sol du monde (la première est le grand élément : natte, tapis, dalle).
static func _floor_kinds(wid: int) -> Array:
	match wid:
		1:
			return ["goza", "wet", "coil", "straw", "stamp", "wet", "bucket", "scales"]
		2:
			return ["moss", "leaves", "tanzaku", "petals", "leaves", "dew", "stones"]
		3:
			return ["drift", "prints", "ice", "needles", "drift", "prints", "snowball"]
		4:
			return ["scorch", "ash", "crack", "cinders", "ash", "crack", "ingot"]
		5:
			return ["sheet", "splash", "stroke", "drips", "splash", "stroke", "brush"]
		6:
			return ["moss", "leaves", "roots", "feathers", "leaves", "mushroom", "needles"]
		7:
			return ["ripples", "shells", "starfish", "pearls", "ripples", "shells", "kelpbits"]
		_:
			return ["ashring", "deadleaves", "bones", "wax", "deadleaves", "ash", "pebbles"]


static func _floor_item(wid: int, ctx: Dictionary, p: Vector2, k: int, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var kinds := _floor_kinds(wid)
	var name := String(kinds[k])
	var yaw := rng.randf() * TAU
	var sc := rng.randf_range(0.8, 1.3)
	match name:
		"goza":
			# natte de paille : plaque fine à liseré sombre
			var w := rng.randf_range(0.9, 1.2)
			var l := w * rng.randf_range(1.6, 2.0)
			var xf := _at(Vector3(p.x, 0.006, p.y), Vector3(0, yaw * 0.25 + (PI * 0.5 if rng.randf() < 0.5 else 0.0), 0))
			W._add(bn, _tn(Color("#B9A06A")), W._box(Vector3(w, 0.012, l)), xf * _at(Vector3(0, 0.006, 0)))
			for sz: float in [-1.0, 1.0]:
				W._add(bn, _tn(Color("#3E3A30"), false), W._box(Vector3(w, 0.014, 0.06)), xf * _at(Vector3(0, 0.006, sz * (l * 0.5 - 0.03))))
			# trame : fines lignes plus sombres en travers
			for ki in 5:
				W._add(bn, _tn(Color("#9A845A"), false), W._box(Vector3(w, 0.013, 0.012)), xf * _at(Vector3(0, 0.006, (ki - 2) * l * 0.18)))
		"wet":
			_decal(ctx, "wet", Color(0.08, 0.14, 0.26, 0.2), p, 0.9 * sc, 0.6 * sc, yaw, true)
			_decal(ctx, "wet", Color(0.08, 0.14, 0.26, 0.2), p + Vector2(0.3, 0.2) * sc, 0.4 * sc, 0.3 * sc, yaw + 0.5, true)
		"coil":
			_coil(bn, _at(Vector3(p.x, 0, p.y), Vector3(0, yaw, 0)), 0.13 * sc)
		"straw":
			for i in 6:
				var q := p + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				_bit(ctx, "straw", W._box(Vector3(0.14, 0.008, 0.012)), _tn(Color("#D8C48C"), false), _at(Vector3(q.x, 0.008, q.y), Vector3(0, rng.randf() * TAU, 0)))
		"stamp":
			# marque d'encre tamponnée sur le quai (cercle et barres)
			_decal(ctx, "stamp", Color(0.18, 0.2, 0.27, 0.32), p, 0.5 * sc, 0.5 * sc, yaw, true)
			_decal(ctx, "stamp_w", Color(0.75, 0.72, 0.62, 0.4), p, 0.3 * sc, 0.3 * sc, yaw, true)
			_decal(ctx, "stamp", Color(0.18, 0.2, 0.27, 0.32), p, 0.22 * sc, 0.08 * sc, yaw + 0.3)
		"bucket":
			_tub(bs, bn, _at(Vector3(p.x, 0, p.y), Vector3(PI * 0.5 + rng.randf_range(-0.3, 0.3), yaw, 0)) * _at(Vector3(0, -0.1, 0)), 0.1, 0.16, Color("#8A6A43"), true)
		"scales":
			for i in 5:
				var q := p + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
				_decal(ctx, "scale", Color(0.85, 0.9, 0.95, 0.45), q, 0.06, 0.09, rng.randf() * TAU, true)
		"moss":
			_decal(ctx, "moss", Color(0.3, 0.42, 0.26, 0.42), p, 0.8 * sc, 0.55 * sc, yaw, true)
			_decal(ctx, "moss", Color(0.3, 0.42, 0.26, 0.42), p + Vector2(0.35, -0.15) * sc, 0.4 * sc, 0.3 * sc, yaw + 1.0, true)
		"leaves":
			var col := Color("#8DAE5E") if wid == 2 else LEAF_GOLD
			var col2 := Color("#5E7F43") if wid == 2 else LEAF_RUST
			for i in 7:
				var q := p + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
				_decal(ctx, "leaf_" + ("b" if wid == 2 else "k"), (col if i % 2 == 0 else col2) * Color(1, 1, 1, 0.85), q, 0.07 if wid == 2 else 0.11, 0.22 if wid == 2 else 0.12, rng.randf() * TAU)
		"tanzaku":
			for i in 3:
				var q := p + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				var c: Color = W.TANZAKU[rng.randi() % W.TANZAKU.size()]
				_bit(ctx, "tanzaku", W._box(Vector3(0.07, 0.006, 0.2)), _tn(c, false), _at(Vector3(q.x, 0.007, q.y), Vector3(0, rng.randf() * TAU, 0)))
		"petals":
			for i in 8:
				var q := p + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
				var c: Color = Decor.SAKURA[i % 3]
				_decal(ctx, "petal", Color(c.r, c.g, c.b, 0.9), q, 0.06, 0.08, rng.randf() * TAU, true)
		"dew":
			for i in 4:
				var q := p + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				_decal(ctx, "dew", Color(0.75, 0.85, 1.0, 0.35), q, 0.12, 0.08, rng.randf() * TAU, true)
		"stones":
			for i in 4:
				var q := p + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
				_bit(ctx, "pebble", W._ball(0.04, 0.03, 6, 3), _tn(W.NIGHT_STONE, false), _at(Vector3(q.x, 0.0, q.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.7, 1.4), 1, 1)))
		"drift":
			# congère molle : décalque large et bosse de neige au ras du sol
			_decal(ctx, "drift", Color(0.96, 0.97, 1.0, 0.55), p, 1.2 * sc, 0.7 * sc, yaw, true)
			W._add(bn, _tn(W.SNOW, false), W._ball(0.3 * sc, 0.05, 9, 3), _at(Vector3(p.x, 0.0, p.y), Vector3(0, yaw, 0), Vector3(1.6, 1, 1)))
		"prints":
			# traces de pas dans la neige, en ligne
			var d := Vector2.from_angle(yaw)
			var side := Vector2(-d.y, d.x)
			for i in 5:
				var q := p + d * (i - 2) * 0.32 + side * (0.09 if i % 2 == 0 else -0.09)
				_decal(ctx, "print", Color(0.52, 0.58, 0.76, 0.6), q, 0.1, 0.18, yaw + PI * 0.5, true)
		"ice":
			_decal(ctx, "ice", Color(0.72, 0.84, 0.94, 0.4), p, 0.7 * sc, 0.5 * sc, yaw, true)
			_decal(ctx, "ice_hi", Color(1, 1, 1, 0.35), p + Vector2(0.1, 0.05), 0.25 * sc, 0.08 * sc, yaw + 0.3, true)
		"needles":
			for i in 6:
				var q := p + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				_decal(ctx, "needle", Color(0.25, 0.35, 0.28, 0.7) if wid == 3 else Color(0.43, 0.29, 0.2, 0.8), q, 0.03, 0.14, rng.randf() * TAU)
		"snowball":
			_bit(ctx, "snowball", W._ball(0.09, 0.16, 7, 4), _tn(W.SNOW), _at(Vector3(p.x, 0.0, p.y), Vector3.ZERO, Vector3.ONE * sc * 0.8))
		"scorch":
			_decal(ctx, "scorch", Color(0.08, 0.06, 0.07, 0.42), p, 0.9 * sc, 0.7 * sc, yaw, true)
			_decal(ctx, "scorch", Color(0.08, 0.06, 0.07, 0.3), p + Vector2(0.2, 0.25) * sc, 0.5 * sc, 0.35 * sc, yaw + 0.8, true)
		"ash":
			_decal(ctx, "ash", Color(0.5, 0.48, 0.5, 0.4) if wid == 4 else Color(0.42, 0.4, 0.45, 0.4), p, 0.7 * sc, 0.5 * sc, yaw, true)
		"crack":
			# fissure de braise : traits lumineux en zigzag
			var d := Vector2.from_angle(yaw)
			var q := p - d * 0.3
			for i in 3:
				var nq := q + d.rotated(rng.randf_range(-0.6, 0.6)) * 0.22
				var c := (q + nq) * 0.5
				_bit(ctx, "ember_crack", W._box(Vector3(1.0, 0.006, 0.03)), W._glow(W.LAVA_GOLD, 1.3), _at(Vector3(c.x, 0.009, c.y), Vector3(0, -(nq - q).angle(), 0), Vector3(q.distance_to(nq), 1, 1)))
				q = nq
		"cinders":
			for i in 5:
				var q := p + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				_bit(ctx, "cinder", W._ball(0.03, 0.03, 5, 3), _tn(W.BASALT, false), _at(Vector3(q.x, 0.0, q.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.7, 1.5), 1, 1)))
		"ingot":
			_bit(ctx, "ingot", W._box(Vector3(0.2, 0.05, 0.08)), _tn(W.IRON), _at(Vector3(p.x, 0.025, p.y), Vector3(0, yaw, 0)))
		"sheet":
			W._sheet_into(bn, _tn(WASHI), _at(Vector3(p.x, 0.006, p.y), Vector3(0, yaw, 0)), 0.5 * sc, 0.7 * sc)
			_decal(ctx, "sheet_ink", Color(0.1, 0.1, 0.12, 0.6), p + Vector2(0.05, -0.1).rotated(yaw), 0.08, 0.3 * sc, yaw, true)
		"splash":
			_decal(ctx, "ink", Color(0.1, 0.1, 0.12, 0.55), p, 0.5 * sc, 0.4 * sc, yaw, true)
			for i in 4:
				var q := p + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45)) * sc
				_decal(ctx, "ink", Color(0.1, 0.1, 0.12, 0.55), q, rng.randf_range(0.05, 0.12), rng.randf_range(0.05, 0.1), rng.randf() * TAU, true)
		"stroke":
			_decal(ctx, "ink", Color(0.1, 0.1, 0.12, 0.5), p, 1.4 * sc, 0.12 * sc, yaw, true)
			_decal(ctx, "ink", Color(0.1, 0.1, 0.12, 0.5), p + Vector2.from_angle(-yaw) * 0.8 * sc, 0.3 * sc, 0.05 * sc, yaw + 0.2, true)
		"drips":
			for i in 5:
				var q := p + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				_decal(ctx, "ink", Color(0.1, 0.1, 0.12, 0.55), q, 0.06, 0.06, 0.0, true)
		"brush":
			_small_brush(bn, _at(Vector3(p.x, 0, p.y), Vector3(0, yaw, 0)), 0.5 * sc)
			_decal(ctx, "ink", Color(0.1, 0.1, 0.12, 0.5), p + Vector2.from_angle(-yaw) * 0.3 * sc, 0.2 * sc, 0.08 * sc, yaw, true)
		"roots":
			var d := Vector2.from_angle(yaw)
			var q := p - d * 0.4
			for i in 3:
				var nq := q + d.rotated(rng.randf_range(-0.5, 0.5)) * 0.3
				W._limb(bn, _tn(W.CEDAR_BARK, false), Vector3(q.x, 0.0, q.y), Vector3(nq.x, 0.0, nq.y), 0.04 - i * 0.008, 0.03 - i * 0.008, 5)
				q = nq
		"feathers":
			for i in 3:
				var q := p + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				_decal(ctx, "feather", Color(0.16, 0.16, 0.2, 0.8), q, 0.05, 0.2, rng.randf() * TAU)
				_decal(ctx, "feather_hi", Color(0.5, 0.5, 0.55, 0.7), q, 0.012, 0.18, rng.randf() * TAU)
		"mushroom":
			_mushrooms(bs, bn, _at(Vector3(p.x, 0, p.y), Vector3(0, yaw, 0)), rng, MUSH_CAP if rng.randf() < 0.6 else Color("#D9A05A"))
		"ripples":
			for i in 3:
				_decal(ctx, "ripple", Color(0.95, 0.92, 0.85, 0.3), p + Vector2.from_angle(yaw + PI * 0.5) * (i - 1) * 0.22, 1.0 * sc, 0.05, yaw, true)
		"shells":
			_shells(bs, bn, _at(Vector3(p.x, 0, p.y), Vector3(0, yaw, 0)), rng)
		"starfish":
			var st := _tn(STARFISH)
			var c := Vector3(p.x, 0.015, p.y)
			for i in 5:
				var a := yaw + TAU * i / 5.0
				W._limb(bn, st, c, c + Vector3(cos(a) * 0.13 * sc, 0, sin(a) * 0.13 * sc), 0.035 * sc, 0.008, 4)
		"pearls":
			for i in 3:
				var q := p + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
				_bit(ctx, "pearl", W._ball(0.035, 0.07, 7, 4), W._glow(W.NACRE, 1.0), _at(Vector3(q.x, 0.0, q.y)))
		"kelpbits":
			for i in 3:
				var q := p + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
				_decal(ctx, "kelpbit", Color(0.22, 0.4, 0.3, 0.75), q, 0.07, 0.3, rng.randf() * TAU)
		"ashring":
			_decal(ctx, "ashring", Color(0.3, 0.28, 0.33, 0.45), p, 0.9 * sc, 0.9 * sc, yaw, true)
			_decal(ctx, "ashring_in", Color(0.1, 0.09, 0.12, 0.4), p, 0.4 * sc, 0.4 * sc, yaw, true)
			for i in 3:
				var a := yaw + TAU * i / 3.0
				_bit(ctx, "ash_stone", W._ball(0.06, 0.06, 6, 3), _tn(W.ASH_DARK, false), _at(Vector3(p.x + cos(a) * 0.42 * sc, 0.0, p.y + sin(a) * 0.42 * sc)))
		"deadleaves":
			for i in 6:
				var q := p + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
				_decal(ctx, "deadleaf", Color(0.3, 0.26, 0.3, 0.85) if i % 2 == 0 else Color(0.42, 0.34, 0.3, 0.85), q, 0.1, 0.12, rng.randf() * TAU, true)
		"bones":
			W._bones_into(bn, p, rng, -0.04, 0.5)
		"wax":
			_decal(ctx, "wax", Color(0.9, 0.86, 0.75, 0.5), p, 0.25 * sc, 0.2 * sc, yaw, true)
			_bit(ctx, "wax_stub", W._cyl(0.03, 0.035, 0.05, 6), _tn(CANDLE, false), _at(Vector3(p.x + 0.05, 0.0, p.y), Vector3.ZERO, Vector3.ONE * sc))
		"pebbles":
			for i in 4:
				var q := p + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
				_bit(ctx, "pebble_y", W._ball(0.04, 0.03, 6, 3), _tn(W.YOMI_GRAVE_CAP, false), _at(Vector3(q.x, 0.0, q.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.7, 1.4), 1, 1)))
		_:
			pass
