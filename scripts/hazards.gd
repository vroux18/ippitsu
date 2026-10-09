extends Node3D
## Dangers d'arène, dans tous les mondes (hors salles de boss), à l'allure du sol de chaque monde :
##  trous   — planches pourries : on peut tracer au-dessus, pas finir dedans (chute, 1 dégât).
##            Les ennemis projetés dedans tombent à l'eau (sauf les costauds).
##  vague   — déferlante : bande transversale annoncée 1.3 s, qui balaie et repousse.

const Toon = preload("res://scripts/toon.gd")
const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)
const WAVE_W := 2.5
const WAVE_WARN := 1.3
const K_PROJ := 0.7265  # 1/tan(54°) : en plongée, une profondeur d se voit décalée de d·K vers la caméra (+z)
const PLANK_W := 0.62  # planches du monde 1 (arena.gd), posées le long de z
const STONE := 1.0  # dalles du monde 2 (arena.gd), rangées impaires décalées d'une demi-dalle
# couches des aplats au-dessus du sol (y = 0) : fond, liserés, reflets, paroi, détails, pièces, encre
const Y_FOND := 0.014
const Y_LISERE := 0.018
const Y_REFLET := 0.021
const Y_PAROI := 0.024
const Y_DETAIL := 0.028
const Y_PIECE := 0.031
const Y_PIECE2 := 0.034
const Y_ENCRE := 0.037
# allure des trous selon le monde : fond (loin/près), liseré, paroi (arête, face, dessous), profondeurs, reflets
const HOLE_STYLES := {
	1: {"deep": Color("#07111C"), "near": Color("#18395A"), "rim": Color("#4F86A6"), "lip": Color("#B5A994"),
		"face": Color("#6E6458"), "face2": Color("#3E3631"), "dark": Color("#1A1612"), "abyss": Color("#0A1420"),
		"ink": Color("#1B1A1E"), "d_slab": 0.25, "d_total": 0.5, "glint": Color("#E9F2F5")},
	2: {"deep": Color("#040608"), "near": Color("#0E1A1C"), "rim": Color("#2A6662"), "lip": Color("#BDB7A4"),
		"face": Color("#7A7567"), "face2": Color("#4C4942"), "dark": Color("#17181A"), "abyss": Color("#050709"),
		"ink": Color("#26252B"), "d_slab": 0.22, "d_total": 0.62, "glint": Color("#6FD6C6")},
	3: {"deep": Color("#071725"), "near": Color("#1A4560"), "centre": Color("#0C2234"), "rim": Color("#79B9DA"),
		"wall0": Color("#E2F4FB"), "wall1": Color("#86C5E2"), "wall2": Color("#245F86"),
		"ink": Color("#3A3A48"), "d_total": 0.55, "glint": Color("#F2FBFF")},
	4: {"deep": Color("#C2360E"), "near": Color("#F27A26"), "centre": Color("#FFD866"), "rim": Color("#FFF1A6"),
		"wall0": Color("#22150F"), "wall1": Color("#6A2410"), "wall2": Color("#E4561A"),
		"ink": Color("#1A0F0B"), "d_total": 0.42, "glint": Color("#FFF4B8")},
	5: {"deep": Color("#040405"), "near": Color("#16141B"), "centre": Color("#0A090D"), "rim": Color("#3A3644"),
		"wall0": Color("#D3C6A8"), "wall1": Color("#4A4038"), "wall2": Color("#09090B"),
		"ink": Color("#1B1A1E"), "d_total": 0.2, "glint": Color("#F4F1FA")},
}
var main: Node
var holes: Array = []  # [centre, rayon]
var _hole_nodes: Array = []
var _wave_on := false
var _wave_t := 0.0  # temps avant la prochaine déferlante
var _band: Node3D
var _band_fill: MeshInstance3D
var _band_z := 0.0
var _zone := Rect2(-4.6, -8.6, 9.2, 17.2)  # zone du combat en cours (déferlantes)
var _band_dir := 1.0
var _warn := 0.0
var _crest: Node3D
var _crest_t := -1.0
var _m_flat: StandardMaterial3D  # aplats, couleur de sommet
var _m_lava: StandardMaterial3D  # aplats de lave (pulsation)
var _m_relief: StandardMaterial3D  # reliefs cernés d'encre
var _m_sheet: StandardMaterial3D  # feuilles souples (neige, papier)
var _m_glint: StandardMaterial3D  # reflets mobiles
var _glint_mesh: ArrayMesh
var _glint_col := Color.WHITE
var _glints: Array = []  # [nœud, position de base, phase, taille]
var _pops: Array = []  # [nœud, temps] : apparition des trous
var _anim_t := 0.0


## Début d'un combat. `zone` : cadre de la zone de combat (vide = salle classique autour de l'origine) ;
## `keep` : étape longue, les trous des zones précédentes restent en place.
func begin_room(room: int, hero_pos: Vector3, boss := false, zone := Rect2(), keep := false) -> void:
	if keep:
		calm()
	else:
		clear()
	_zone = zone if zone.has_area() else Rect2(-HALF.x, -HALF.y, HALF.x * 2.0, HALF.y * 2.0)
	# trous à partir de la salle 4, un de plus toutes les 4 salles ; rien dans une salle de boss
	var n := 0 if room < 4 or boss else mini(1 + int((room - 4) / 4.0), 3)
	for i in n:
		for attempt in 30:
			var r := randf_range(0.8, 1.15)
			var c := Vector3(randf_range(_zone.position.x + 1.4, _zone.end.x - 1.4), 0, randf_range(_zone.position.y + 2.0, _zone.end.y - 2.0))
			# (ni contre une pièce de décor : bateau, bosquet… on ne lirait plus le trou)
			var ok: bool = c.distance_to(hero_pos) > 3.0 and main.arena.walkable(c, r + 0.4) and not main.arena.is_bridge(c, r + 1.0) \
				and not main.arena.on_set_piece(c, r + 0.7)
			for h in holes:
				var hc: Vector3 = h[0]
				if hc.distance_to(c) < float(h[1]) + r + 1.5:
					ok = false
			if ok:
				holes.append([c, r])
				_make_hole(c, r)
				break
	# déferlante : seulement avec le pacte « Déferlante » du sanctuaire (mode difficile choisi)
	_wave_on = room >= 3 and not boss and "tide" in main.curses
	_wave_t = randf_range(6.0, 8.0)


func clear() -> void:
	for nd in _hole_nodes:
		if is_instance_valid(nd):
			nd.queue_free()
	_hole_nodes.clear()
	_glints.clear()
	_pops.clear()
	holes.clear()
	_wave_on = false
	_end_band()
	if is_instance_valid(_crest):
		_crest.queue_free()
	_crest = null
	_crest_t = -1.0


## Salle nettoyée : plus de déferlante (les trous restent).
func calm() -> void:
	_wave_on = false
	_end_band()
	if is_instance_valid(_crest):
		_crest.queue_free()
	_crest = null
	_crest_t = -1.0


## Petit assembleur de maillage : triangles colorés (couleur de sommet), tournés vers `up`.
class Mb:
	var st := SurfaceTool.new()
	var n := 0

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, up := Vector3.UP) -> void:
		var g := (b - a).cross(c - a)
		var l2 := g.length_squared()
		if not (l2 > 1e-10):
			return  # triangle plat ou invalide : ignoré
		# face avant dans le sens horaire (convention Godot) : normale = -(b-a)x(c-a)
		var nr := -g / sqrt(l2)
		if nr.dot(up) < 0.0:
			_vert(a, ca, -nr)
			_vert(c, cc, -nr)
			_vert(b, cb, -nr)
		else:
			_vert(a, ca, nr)
			_vert(b, cb, nr)
			_vert(c, cc, nr)
		n += 3

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color, up := Vector3.UP) -> void:
		tri(a, b, c, ca, cb, cc, up)
		tri(a, c, d, ca, cc, cd, up)

	func _vert(p: Vector3, col: Color, nr: Vector3) -> void:
		st.set_color(col)
		st.set_normal(nr)
		st.add_vertex(p)

	func build(parent: Node3D, m: Material, shadow := false) -> void:
		if n == 0:
			return
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


func _ensure_mats() -> void:
	if _m_flat != null:
		return
	_m_flat = StandardMaterial3D.new()
	_m_flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_flat.vertex_color_use_as_albedo = true
	_m_flat.vertex_color_is_srgb = true
	_m_flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_m_lava = _m_flat.duplicate() as StandardMaterial3D
	_m_relief = Toon.mat(Color.WHITE, true, 0.014)
	_m_relief.vertex_color_use_as_albedo = true
	_m_relief.vertex_color_is_srgb = true
	_m_sheet = Toon.mat(Color.WHITE, false)
	_m_sheet.vertex_color_use_as_albedo = true
	_m_sheet.vertex_color_is_srgb = true
	_m_sheet.cull_mode = BaseMaterial3D.CULL_DISABLED
	_m_glint = StandardMaterial3D.new()
	_m_glint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_glint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m_glint.vertex_color_use_as_albedo = true
	_m_glint.vertex_color_is_srgb = true
	_m_glint.cull_mode = BaseMaterial3D.CULL_DISABLED
	# reflet : fuseau de longueur 1, pointes transparentes
	var mb := Mb.new()
	var xs := [-0.5, -0.32, -0.12, 0.0, 0.12, 0.32, 0.5]
	var ws := [0.0, 0.45, 0.85, 1.0, 0.85, 0.45, 0.0]
	for i in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		var w0: float = ws[i] * 0.09
		var w1: float = ws[i + 1] * 0.09
		var c0 := Color(1, 1, 1, 1.0 - absf(x0) * 1.8)
		var c1 := Color(1, 1, 1, 1.0 - absf(x1) * 1.8)
		mb.quad(Vector3(x0, 0, -w0), Vector3(x1, 0, -w1), Vector3(x1, 0, w1), Vector3(x0, 0, w0), c0, c1, c1, c0)
	_glint_mesh = mb.st.commit()


## Un trou, à l'allure du sol du monde. Tout est en coordonnées locales (centre du trou en 0) ;
## les aplats sont légèrement au-dessus du sol et simulent la profondeur vue en plongée.
func _make_hole(c: Vector3, r: float) -> void:
	_ensure_mats()
	var n := Node3D.new()
	add_child(n)
	n.position = c
	var w := 1
	if main != null:
		# mondes 6 à 8 : sol de pierre (Kurama, palais de Ryūgū) ou d'encre (Yomi)
		w = [1, 1, 2, 3, 4, 5, 2, 2, 5][clampi(int(main.current_world), 1, 8)]
	var pal: Dictionary = HOLE_STYLES[w]
	var flat := Mb.new()  # aplats : fond, parois, liserés, encre
	var relief := Mb.new()  # reliefs cernés d'encre : échardes, cailloux, plaques
	var sheet := Mb.new()  # feuilles souples sans contour : lèvre de neige, papier retroussé
	var lava := Mb.new()  # lave (pulsation)
	var spots: Array = []  # reflets mobiles [position, taille]
	match w:
		2:
			_hole_stones(c, r, pal, flat, relief, spots)
		3:
			_hole_ice(c, r, pal, flat, sheet, spots)
		4:
			_hole_lava(c, r, pal, flat, relief, lava, spots)
		5:
			_hole_ink(c, r, pal, flat, sheet, spots)
		_:
			_hole_planks(c, r, pal, flat, relief, spots)
	flat.build(n, _m_flat)
	lava.build(n, _m_lava)
	relief.build(n, _m_relief, true)
	sheet.build(n, _m_sheet)
	_glint_col = pal["glint"]
	for s in spots:
		var base: Vector3 = s[0]
		var size: float = s[1]
		var g := MeshInstance3D.new()
		g.mesh = _glint_mesh
		g.material_override = _m_glint
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.position = base
		g.rotation.y = randf_range(-0.25, 0.25)
		g.scale = Vector3(size, 1.0, size)
		n.add_child(g)
		_glints.append([g, base, randf() * TAU, size])
	# le sol cède d'un coup à l'entrée de la salle (pas d'annonce : le trou est là dès le début)
	n.scale = Vector3(0.82, 1.0, 0.82)
	_pops.append([n, 0.0])
	_hole_nodes.append(n)


func _process(delta: float) -> void:
	if _hole_nodes.is_empty():
		return
	_anim_t += delta
	var i := _pops.size() - 1
	while i >= 0:
		var p: Array = _pops[i]
		var t: float = float(p[1]) + delta
		p[1] = t
		if is_instance_valid(p[0]):
			var nd: Node3D = p[0]
			var k := clampf(t / 0.28, 0.0, 1.0)
			var sc := lerpf(0.82, 1.0, 1.0 - (1.0 - k) * (1.0 - k))
			nd.scale = Vector3(sc, 1.0, sc)
		if t >= 0.28:
			_pops.remove_at(i)
		i -= 1
	_m_glint.albedo_color = Color(_glint_col.r, _glint_col.g, _glint_col.b, 0.55 + 0.3 * sin(_anim_t * 1.7))
	var lv := 0.86 + 0.14 * sin(_anim_t * 2.1)
	_m_lava.albedo_color = Color(lv, lv, lv)
	for g in _glints:
		if not is_instance_valid(g[0]):
			continue
		var nd: Node3D = g[0]
		var base: Vector3 = g[1]
		var ph: float = g[2]
		var sz: float = g[3]
		nd.position = base + Vector3(sin(_anim_t * 0.6 + ph) * 0.05, 0.0, cos(_anim_t * 0.45 + ph) * 0.025)
		var k := sz * (0.8 + 0.25 * sin(_anim_t * 1.3 + ph * 1.7))
		nd.scale = Vector3(k, 1.0, k)


# ------------------------------------------------------------------ monde 1 : planches cassées

## Deux ou trois planches manquantes dans le fil du plancher : bouts éclatés en échardes,
## épaisseur du bois, eau sombre dessous, parfois une planche qui pend dans le trou.
func _hole_planks(c: Vector3, r: float, pal: Dictionary, flat: Mb, relief: Mb, spots: Array) -> void:
	var k0 := int(floorf((c.x - r + HALF.x) / PLANK_W))
	var k1 := int(floorf((c.x + r + HALF.x) / PLANK_W))
	var cols: Array = []
	for k in range(k0, k1 + 1):
		var xl := -HALF.x + k * PLANK_W - c.x
		var xr := xl + PLANK_W
		var o0 := maxf(xl, -r)
		var o1 := minf(xr, r)
		if o1 - o0 < 0.14:
			continue
		var a := xl
		var b := xr
		# planche à peine entamée : fendue dans le fil, seule une partie manque
		if o0 > xl + 0.2:
			a = o0 - 0.04
		if o1 < xr - 0.2:
			b = o1 + 0.04
		cols.append([a, b, xl, xr])
	if cols.is_empty():
		return
	# côtés extérieurs : le chant de la planche voisine (le joint du plancher reste visible)
	var first: Array = cols[0]
	if is_equal_approx(float(first[0]), float(first[2])):
		first[0] = float(first[2]) + 0.0175
	var last: Array = cols[cols.size() - 1]
	if is_equal_approx(float(last[1]), float(last[3])):
		last[1] = float(last[3]) - 0.0175
	var runs: Array = []
	for col in cols:
		var a: float = col[0]
		var b: float = col[1]
		var dn: float = 0.0 if (a < 0.0 and b > 0.0) else minf(absf(a), absf(b))
		var df := minf(maxf(absf(a), absf(b)), r)
		var hn := 0.85 * sqrt(maxf(r * r - dn * dn, 0.0))
		var hf := 0.85 * sqrt(maxf(r * r - df * df, 0.0))
		var h := maxf(lerpf(hf, hn, 0.85), 0.34)
		var zf := -h * randf_range(0.97, 1.07)
		var zn := h * randf_range(0.97, 1.07)
		var tooth := clampf((zn - zf) * 0.16, 0.08, 0.22)
		var xs := _xs(a, b, maxi(2, int((b - a) / 0.1)), 0.015)
		runs.append({"a": a, "b": b,
			"far": _edge(xs, zf, randf_range(-0.12, 0.12), 1.0, tooth, 0.05),
			"near": _edge(xs, zn, randf_range(-0.12, 0.12), -1.0, tooth, 0.05)})
	_pit_columns(flat, runs, pal)
	# échardes en relief au bout des planches cassées
	var wood_top := Color("#D2AE74")
	var wood_side := Color("#7A5631")
	for run in runs:
		for key in ["far", "near"]:
			var e: PackedVector2Array = run[key]
			var dir: float = 1.0 if key == "far" else -1.0
			for i in range(1, e.size() - 1, 2):
				if randf() < 0.55:
					_splinter(relief, e[i], dir, wood_top, wood_side)
	if randf() < 0.75:
		_dangling_plank(flat, runs, pal, spots)
	_column_spots(runs, spots, 2)


## Écharde relevée au bout d'une planche, pointe vers le trou.
func _splinter(mb: Mb, tip: Vector2, dir: float, ctop: Color, cside: Color) -> void:
	var w := randf_range(0.022, 0.035)
	var bx := tip.x + randf_range(-0.02, 0.02)
	var bz := tip.y - dir * randf_range(0.1, 0.16)
	var top := PackedVector3Array([Vector3(bx - w, 0.05, bz), Vector3(bx + w, 0.05, bz),
		Vector3(tip.x + randf_range(-0.015, 0.015), 0.042, tip.y + dir * randf_range(0.03, 0.07))])
	_prism(mb, top, -0.005, PackedColorArray([ctop, ctop, ctop.darkened(0.15)]), PackedColorArray([cside, cside, cside]))


## Planche arrachée qui pend dans le trou, accrochée au bord du fond, le bas dans l'eau.
func _dangling_plank(flat: Mb, runs: Array, pal: Dictionary, spots: Array) -> void:
	var best: Dictionary = {}
	var best_l := 0.0
	for run in runs:
		if float(run["b"]) - float(run["a"]) < 0.45 or float(run["s"]) < 0.08:
			continue
		var l := _zmin(run["near"]) - _zmax(run["far"])
		if l > best_l:
			best_l = l
			best = run
	if best.is_empty() or best_l < 0.6:
		return
	var a: float = best["a"]
	var b: float = best["b"]
	var s: float = best["s"]
	var zt := _zmax(best["far"]) + 0.012
	var lp := minf(_zmin(best["near"]) - 0.08 - zt, randf_range(0.6, 0.85))
	if lp < 0.35:
		return
	var sk := randf_range(-0.07, 0.07)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var jag := [0.0, -0.06, 0.05, 0.0]
	for i in 4:
		var f := i / 3.0
		top.append(Vector2(lerpf(a + 0.05, b - 0.05, f), zt + (f - 0.5) * 0.04))
		bot.append(Vector2(lerpf(a + 0.07, b - 0.07, f) + sk, zt + lp + float(jag[i]) + (f - 0.5) * 0.04))
	# penchée à 55° : la ligne d'eau sur la planche (profondeur s/K) se voit à s/K·(cot 55° + K)
	var zw := zt + s / K_PROJ * (0.7 + K_PROJ)
	var mid := _leaner(flat, top, bot, zw, Color("#8E8274"), Color("#3E3631"), Color("#22384A"), pal["deep"], pal["ink"])
	for f in [0.34, 0.68]:
		_line(flat, PackedVector2Array([top[0].lerp(top[3], f), mid[0].lerp(mid[3], f)]), 0.012, 0.012, Color("#7A5631"), Y_PIECE2)
	if zt + lp > zw + 0.06:
		spots.append([Vector3(lerpf(a, b, 0.5) + sk * 0.5, Y_REFLET, zw + 0.03), 0.34])


# ------------------------------------------------------------------ monde 2 : dalles effondrées

## Fosse carrée qui suit le dallage : bords ébréchés, parois de pierre, noir en dessous,
## une dalle tombée penchée contre la paroi.
func _hole_stones(c: Vector3, r: float, pal: Dictionary, flat: Mb, relief: Mb, spots: Array) -> void:
	var cells := {}  # demi-colonne (x local, en mm) -> hauts des rangées ouvertes
	var row0 := int(floorf((c.z - 0.85 * r + HALF.y) / STONE))
	var row1 := int(floorf((c.z + 0.85 * r + HALF.y) / STONE))
	for row in range(row0, row1 + 1):
		var gz := -HALF.y + row * STONE
		var off: float = STONE * 0.5 if posmod(row, 2) == 1 else 0.0
		var j0 := int(floorf((c.x - r + HALF.x + off) / STONE))
		var j1 := int(floorf((c.x + r + HALF.x + off) / STONE))
		for j in range(j0, j1 + 1):
			var gx := -HALF.x - off + j * STONE
			# la dalle tombe si une bonne part est dans le trou
			var inside := 0
			for si in 4:
				for sj in 4:
					var px := gx + (si + 0.5) * STONE / 4.0 - c.x
					var pz := gz + (sj + 0.5) * STONE / 4.0 - c.z
					if Vector2(px, pz / 0.85).length() < r:
						inside += 1
			if inside >= 5:
				for hc in 2:
					var key := roundi((gx + hc * STONE * 0.5 - c.x) * 1000.0)
					if not cells.has(key):
						cells[key] = []
					cells[key].append(gz - c.z)
	var runs: Array = []
	for key in cells:
		var zs: Array = cells[key]
		zs.sort()
		var a := float(key) / 1000.0
		var b := a + STONE * 0.5
		var i := 0
		while i < zs.size():
			var z0: float = zs[i]
			var z1 := z0 + STONE
			while i + 1 < zs.size() and absf(float(zs[i + 1]) - z1) < 0.01:
				i += 1
				z1 += STONE
			i += 1
			var xs := _xs(a, b, 4, 0.02)
			runs.append({"a": a, "b": b, "far": _edge(xs, z0, 0.0, 1.0, 0.02, 0.09, true),
				"near": _edge(xs, z1, 0.0, -1.0, 0.02, 0.09, true)})
	if runs.is_empty():
		var xs0 := _xs(-0.5, 0.5, 8, 0.02)
		runs.append({"a": -0.5, "b": 0.5, "far": _edge(xs0, -0.5, 0.0, 1.0, 0.02, 0.09, true),
			"near": _edge(xs0, 0.5, 0.0, -1.0, 0.02, 0.09, true)})
	_pit_columns(flat, runs, pal)
	# éclats de pierre restés sur le bord
	for i in 3:
		var run: Dictionary = runs[randi() % runs.size()]
		var far_side := randf() < 0.6
		var e: PackedVector2Array = run["far"] if far_side else run["near"]
		var p: Vector2 = e[randi() % e.size()]
		var pc := Vector2(p.x + randf_range(-0.05, 0.05), p.y + (-0.1 if far_side else 0.1))
		_pebble(relief, pc, randf_range(0.05, 0.09), Color("#A09A88"), Color("#6A665A"))
	_fallen_slab(flat, runs, r, pal)
	_column_spots(runs, spots, 2)


## Dalle tombée, penchée contre la paroi du fond (vue en plongée : claire en haut, noyée d'ombre en bas).
func _fallen_slab(flat: Mb, runs: Array, r: float, pal: Dictionary) -> void:
	var ink: Color = pal["ink"]
	for attempt in 8:
		var w := randf_range(0.5, 0.7)
		var x0 := randf_range(-r * 0.6, r * 0.6 - w)
		var x1 := x0 + w
		var ra := _run_at(runs, x0 + 0.02)
		var rm := _run_at(runs, (x0 + x1) * 0.5)
		var rb := _run_at(runs, x1 - 0.02)
		if ra.is_empty() or rm.is_empty() or rb.is_empty():
			continue
		var zt := maxf(maxf(_zmax(ra["far"]), _zmax(rm["far"])), _zmax(rb["far"])) + 0.06
		var zb := minf(minf(_zmin(ra["near"]), _zmin(rm["near"])), _zmin(rb["near"])) - 0.1
		var lp := minf(zb - zt, randf_range(0.5, 0.65))
		if lp < 0.35:
			continue
		var sk := randf_range(-0.08, 0.08)
		var top := PackedVector2Array([Vector2(x0, zt + randf_range(-0.03, 0.03)), Vector2((x0 + x1) * 0.5, zt),
			Vector2(x1, zt + randf_range(-0.03, 0.03))])
		var bot := PackedVector2Array([Vector2(x0 + 0.04 + sk, zt + lp), Vector2((x0 + x1) * 0.5 + sk, zt + lp + 0.02),
			Vector2(x1 - 0.04 + sk, zt + lp - randf_range(0.05, 0.1))])
		_leaner(flat, top, bot, zt + 100.0, Color("#A39E8C"), Color("#2E2D2A"), Color("#2E2D2A"), Color("#2E2D2A"), ink)
		_strip(flat, top, _shifted(top, 0.03), Color("#D3CDBA"), Color("#A39E8C"), Y_PIECE2)
		var crack := PackedVector2Array([top[1].lerp(bot[1], 0.12) + Vector2(-0.05, 0), top[1].lerp(bot[1], 0.45) + Vector2(0.05, 0),
			top[2].lerp(bot[2], 0.7)])
		_line(flat, crack, 0.016, 0.005, ink, Y_ENCRE)
		return


## Caillou anguleux posé au sol (relief cerné d'encre).
func _pebble(mb: Mb, pc: Vector2, rad: float, ctop: Color, cside: Color) -> void:
	var pts := PackedVector3Array()
	var tc := PackedColorArray()
	var sc := PackedColorArray()
	var ph := randf() * TAU
	for i in 5:
		var t := ph + TAU * i / 5.0
		var rr := rad * randf_range(0.75, 1.0)
		pts.append(Vector3(pc.x + cos(t) * rr, randf_range(0.035, 0.06), pc.y + sin(t) * rr * 0.8))
		tc.append(ctop)
		sc.append(cside)
	_prism(mb, pts, -0.01, tc, sc)


# ------------------------------------------------------------------ monde 3 : trou dans la glace

## Trou rond : lèvre de neige en surplomb, parois de glace bleue, eau glacée, fissures rayonnantes.
func _hole_ice(c: Vector3, r: float, pal: Dictionary, flat: Mb, sheet: Mb, spots: Array) -> void:
	var rr := r * 1.06
	var pts := _star(rr, 30, 0.035, 0.04, 0.025, 0.012)
	var hole := _scaled(pts, 0.96)
	var bot := _pit_star(flat, flat, hole, pal, 0.35)
	var s: float = float(pal["d_total"]) * K_PROJ
	# stries claires dans la glace (côté lointain : angles > π)
	for k in 4:
		var i := 17 + k * 3
		var p0: Vector2 = hole[i]
		var p1: Vector2 = bot[i]
		_line(flat, PackedVector2Array([p0.lerp(p1, 0.12), p0.lerp(p1, 0.75) + Vector2(randf_range(-0.03, 0.03), 0)]),
			0.026, 0.006, Color("#F0FAFE"), Y_DETAIL)
	# glaçons qui flottent
	for i in 2:
		var sp := _star_spot(r * 0.88, s)
		var rad := randf_range(0.06, 0.1)
		_blob(flat, sp + Vector2(0, 0.022), rad, Color("#5E97BA"), Y_DETAIL, 6)
		_blob(flat, sp, rad, Color("#EEF6FA"), Y_PIECE, 6)
	# lèvre de neige en surplomb : ombre bleue dessous, bourrelet blanc, raccord au sol
	var rows := [[0.94, 0.04, Color("#3A3A48"), 0.0, 0.0], [0.952, 0.05, Color("#9CC2D8"), 0.0, 0.0],
		[0.975, 0.068, Color("#FFFFFF"), 0.0, 0.008], [1.06, 0.075, Color("#F3F8FB"), 0.0, 0.0],
		[1.2, 0.014, Color("#DCE4EC"), 0.0, 0.0]]
	_ring_rows(sheet, pts, rows, PackedFloat32Array())
	# fissures dans la neige autour
	var crack := Color("#6E8BA6")
	for k in 7:
		var idx := (int(float(k) * 30.0 / 7.0) + randi() % 3) % 30
		var p: Vector2 = pts[idx] * 1.12
		var line := _crack(flat, c, p, atan2(p.y, p.x), 4, 0.03, crack)
		if line.size() >= 3 and randf() < 0.6:
			var q: Vector2 = line[1]
			_crack(flat, c, q, atan2(q.y, q.x) + (0.8 if randf() < 0.5 else -0.8), 2, 0.018, crack)
	for i in 2:
		var sp := _star_spot(r * 0.88, s)
		spots.append([Vector3(sp.x, Y_REFLET, sp.y), randf_range(0.2, 0.28)])


## Fissure en zigzag qui part de `p0` vers l'extérieur ; s'arrête au bord de la plateforme.
func _crack(mb: Mb, c: Vector3, p0: Vector2, ang: float, segs: int, w: float, col: Color) -> PackedVector2Array:
	var line := PackedVector2Array([p0])
	var p := p0
	var a := ang
	for i in segs:
		a = lerp_angle(a + randf_range(-0.5, 0.5), ang, 0.4)
		var q := p + Vector2(cos(a), sin(a)) * randf_range(0.09, 0.17)
		if not _on_floor(c, q, 0.08):
			break
		line.append(q)
		p = q
	if line.size() >= 2:
		_line(mb, line, w, w * 0.2, col, Y_FOND)
	return line


# ------------------------------------------------------------------ monde 4 : puits de lave

## Plaques de croûte soulevées autour d'une lave qui luit (pulsation lente), fissures incandescentes.
func _hole_lava(c: Vector3, r: float, pal: Dictionary, flat: Mb, relief: Mb, lava: Mb, spots: Array) -> void:
	var pts := _star(r * 1.02, 28, 0.04, 0.035, 0.02, 0.03)
	_pit_star(lava, lava, pts, pal, 0.45)
	var s: float = float(pal["d_total"]) * K_PROJ
	# lueur sous les plaques : elle ne se voit que dans les fissures
	var hot := Color("#FF9A30")
	var ember := Color("#B8400E")
	for i in 28:
		var j := (i + 1) % 28
		lava.quad(_v(pts[i], Y_FOND), _v(pts[j], Y_FOND), _v(pts[j] * 1.1, Y_FOND), _v(pts[i] * 1.1, Y_FOND), hot, hot, ember, ember)
	# sept plaques de croûte, relevées vers le puits
	var charred := Color("#1C1412")
	var crust := Color("#5A534D")
	var side_hot := Color("#C2531C")
	var side := Color("#2E2724")
	for k in 7:
		var poly := PackedVector3Array()
		var tc := PackedColorArray()
		for q in 5:
			var p: Vector2 = pts[(k * 4 + q) % 28]
			poly.append(Vector3(p.x, 0.065 + randf_range(-0.01, 0.01), p.y))
			tc.append(charred)
		for q in [4, 2, 0]:
			var p: Vector2 = pts[(k * 4 + int(q)) % 28]
			var f := randf_range(1.3, 1.42)
			while f > 1.22 and not _on_floor(c, p * f, 0.05):
				f -= 0.05
			poly.append(Vector3(p.x * f, 0.03, p.y * f))
			tc.append(crust)
		# retrait vers le centre de la plaque : la fissure entre plaques
		var cen := Vector3.ZERO
		for v in poly:
			cen += v
		cen /= float(poly.size())
		var sc := PackedColorArray()
		for v in poly.size():
			var d := Vector3(cen.x - poly[v].x, 0.0, cen.z - poly[v].z)
			poly[v] = poly[v] + d.normalized() * minf(0.035, d.length() * 0.3)
			sc.append(side_hot if v < 4 else side)
		_prism(relief, poly, -0.01, tc, sc)
	# croûtes qui flottent, bord brûlant
	for i in 2:
		var sp := _star_spot(r * 0.85, s)
		var rad := randf_range(0.07, 0.11)
		_blob(lava, sp, rad * 1.3, Color("#FFC34A"), Y_LISERE, 6)
		_blob(flat, sp, rad, Color("#2A1E1A"), Y_DETAIL, 6)
	for i in 3:
		var sp := _star_spot(r * 0.85, s)
		spots.append([Vector3(sp.x, Y_REFLET, sp.y), randf_range(0.12, 0.18)])


# ------------------------------------------------------------------ monde 5 : flaque d'encre

## Papier déchiré, bords retroussés, encre noire et laquée dessous, quelques gouttes autour.
func _hole_ink(c: Vector3, r: float, pal: Dictionary, flat: Mb, sheet: Mb, spots: Array) -> void:
	var pts := _star(r * 1.05, 40, 0.03, 0.05, 0.03, 0.015)
	var hole := _scaled(pts, 0.96)
	_pit_star(flat, flat, hole, pal, 0.3)
	var s: float = float(pal["d_total"]) * K_PROJ
	# reflet laqué
	_lens(flat, Vector2(-0.28 * r, -0.3 * r + s + 0.12), 0.5 * r, 0.045, -0.35, Color("#D8D4E4"), Y_DETAIL)
	_lens(flat, Vector2(0.02 * r, -0.17 * r + s + 0.12), 0.12 * r, 0.03, -0.3, Color("#9A96A8"), Y_DETAIL)
	# bord déchiré : fibres blanches, trois rabats qui se retroussent
	var flaps: Array = []
	for k in 3:
		flaps.append(randf() * TAU)
	var bump := PackedFloat32Array()
	for i in 40:
		var t := TAU * i / 40.0
		var b := 0.0
		for f in flaps:
			var d := wrapf(t - float(f), -PI, PI)
			b += exp(-d * d / 0.12)
		bump.append(minf(b, 1.0))
	var rows := [[0.945, 0.04, Color("#1B1A1E"), 0.02, 0.0], [0.96, 0.05, Color("#FFFDF4"), 0.09, 0.012],
		[1.03, 0.058, Color("#F2EADA"), 0.11, 0.0], [1.16, 0.014, Color("#E6DBC4"), 0.0, 0.0]]
	_ring_rows(sheet, pts, rows, bump)
	# gouttes d'encre sur le papier
	for i in 3:
		var t := randf() * TAU
		var p := Vector2(cos(t), sin(t) * 0.85) * r * randf_range(1.3, 1.6)
		if _on_floor(c, p, 0.1):
			_blob(flat, p, randf_range(0.03, 0.07), Color("#1B1A1E"), Y_FOND, 9)
	for i in 2:
		var sp := _star_spot(r * 0.88, s)
		spots.append([Vector3(sp.x, Y_REFLET, sp.y), randf_range(0.2, 0.3)])


# ------------------------------------------------------------------ briques communes

## Fosse calée sur la grille du sol : colonnes [a, b] le long de z, bord lointain `far` et proche `near`
## (mêmes x). Fond, paroi du fond vue en plongée (décalée vers la caméra), liserés, encre.
## Note dans chaque colonne la hauteur apparente de la paroi ("s").
func _pit_columns(mb: Mb, runs: Array, pal: Dictionary) -> void:
	var deep: Color = pal["deep"]
	var nearc: Color = pal["near"]
	var rim: Color = pal["rim"]
	var lip: Color = pal["lip"]
	var face: Color = pal["face"]
	var face2: Color = pal["face2"]
	var dark: Color = pal["dark"]
	var abyss: Color = pal["abyss"]
	var ink: Color = pal["ink"]
	var d_slab: float = pal["d_slab"]
	var d_total: float = pal["d_total"]
	var bnd := {}
	for run in runs:
		var far: PackedVector2Array = run["far"]
		var near: PackedVector2Array = run["near"]
		var lmin := INF
		for i in far.size():
			lmin = minf(lmin, near[i].y - far[i].y)
		var s := clampf(minf(d_total * K_PROJ, lmin - 0.14), 0.0, 1.0)
		run["s"] = s
		_strip(mb, far, near, deep, nearc, Y_FOND)
		if s > 0.05:
			var s1 := minf(d_slab * K_PROJ, s * 0.65)
			var r1 := _shifted(far, minf(0.045, s1 * 0.4))
			var r2 := _shifted(far, s1)
			var r3 := _shifted(far, s)
			_strip(mb, far, r1, lip, face, Y_PAROI)
			_strip(mb, r1, r2, face, face2, Y_PAROI)
			_strip(mb, r2, r3, dark, abyss, Y_PAROI)
			_line(mb, r2, 0.018, 0.018, ink, Y_DETAIL)
			_strip(mb, r3, _shifted(r3, 0.04), rim, deep, Y_LISERE)
		_strip(mb, _shifted(near, -0.035), near, nearc, rim, Y_LISERE)
		_line(mb, far, 0.035, 0.035, ink, Y_ENCRE)
		_line(mb, near, 0.035, 0.035, ink, Y_ENCRE)
		_bound(bnd, float(run["a"]), 1, far[0].y, near[0].y)
		_bound(bnd, float(run["b"]), -1, far[far.size() - 1].y, near[near.size() - 1].y)
	# côtés : encre là où une seule des deux colonnes voisines est ouverte
	for key in bnd:
		var lst: Array = bnd[key]
		var x := float(key) / 1000.0
		var zs: Array = []
		for e in lst:
			zs.append(e[1])
			zs.append(e[2])
		zs.sort()
		for i in zs.size() - 1:
			var z0: float = zs[i]
			var z1: float = zs[i + 1]
			if z1 - z0 < 0.01:
				continue
			var zm := (z0 + z1) * 0.5
			var left := false
			var right := false
			for e in lst:
				if zm > float(e[1]) and zm < float(e[2]):
					if int(e[0]) > 0:
						right = true
					else:
						left = true
			if left != right:
				_line(mb, PackedVector2Array([Vector2(x, z0), Vector2(x, z1)]), 0.035, 0.035, ink, Y_ENCRE)


func _bound(bnd: Dictionary, x: float, side: int, z0: float, z1: float) -> void:
	var key := roundi(x * 1000.0)
	if not bnd.has(key):
		bnd[key] = []
	bnd[key].append([side, z0, z1])


## Fosse ronde : contour `pts`, fond en éventail, paroi du fond décalée vers la caméra
## (rien sur les côtés ni devant), liseré clair autour de l'eau. Renvoie le pied de la paroi.
func _pit_star(fill: Mb, wall: Mb, pts: PackedVector2Array, pal: Dictionary, split: float) -> PackedVector2Array:
	var n := pts.size()
	var s: float = float(pal["d_total"]) * K_PROJ
	var deep: Color = pal["deep"]
	var nearc: Color = pal["near"]
	var centre: Color = pal["centre"]
	var rim: Color = pal["rim"]
	var w0: Color = pal["wall0"]
	var w1: Color = pal["wall1"]
	var w2: Color = pal["wall2"]
	var bot := PackedVector2Array()
	var mid := PackedVector2Array()
	for i in n:
		var p: Vector2 = pts[i]
		var w := clampf(-p.y / maxf(p.length(), 0.001) * 1.7, 0.0, 1.0)
		bot.append(p + Vector2(0.0, s * w))
		mid.append(p + Vector2(0.0, s * w * split))
	var o := Vector3(0.0, Y_FOND, 0.0)
	for i in n:
		var j := (i + 1) % n
		var ci := _edge_col(pts[i], deep, nearc)
		var cj := _edge_col(pts[j], deep, nearc)
		fill.tri(o, _v(pts[i], Y_FOND), _v(pts[j], Y_FOND), centre, ci, cj)
		wall.quad(_v(pts[i], Y_PAROI), _v(pts[j], Y_PAROI), _v(mid[j], Y_PAROI), _v(mid[i], Y_PAROI), w0, w0, w1, w1)
		wall.quad(_v(mid[i], Y_PAROI), _v(mid[j], Y_PAROI), _v(bot[j], Y_PAROI), _v(bot[i], Y_PAROI), w1, w1, w2, w2)
		var bi: Vector2 = bot[i]
		var bj: Vector2 = bot[j]
		fill.quad(_v(bi, Y_LISERE), _v(bj, Y_LISERE), _v(bj - bj.normalized() * 0.04, Y_LISERE), _v(bi - bi.normalized() * 0.04, Y_LISERE),
			rim, rim, ci, cj)
	_line(wall, pts, 0.035, 0.035, pal["ink"], Y_ENCRE, true)
	return bot


## Pièce penchée dans le trou (planche, dalle) : claire en haut, sombre en bas, noyée passé la ligne d'eau `zw`.
## Renvoie la rangée de la ligne d'eau.
func _leaner(mb: Mb, top: PackedVector2Array, bot: PackedVector2Array, zw: float, c_hi: Color, c_lo: Color, c_wet: Color, c_deep: Color, ink: Color) -> PackedVector2Array:
	var n := top.size()
	var mid := PackedVector2Array()
	var wet := false
	for i in n:
		var t0: Vector2 = top[i]
		var b0: Vector2 = bot[i]
		var k := clampf((zw - t0.y) / maxf(b0.y - t0.y, 0.001), 0.0, 1.0)
		if k < 0.999:
			wet = true
		mid.append(t0.lerp(b0, k))
	_strip(mb, top, mid, c_hi, c_lo, Y_PIECE)
	if wet:
		_strip(mb, mid, bot, c_wet, c_deep, Y_PIECE)
	_line(mb, top, 0.03, 0.03, ink, Y_ENCRE)
	_line(mb, PackedVector2Array([top[0], mid[0]]), 0.03, 0.03, ink, Y_ENCRE)
	_line(mb, PackedVector2Array([top[n - 1], mid[n - 1]]), 0.03, 0.03, ink, Y_ENCRE)
	if not wet:
		_line(mb, bot, 0.03, 0.03, ink, Y_ENCRE)
	return mid


## Lèvre en anneau, rangée par rangée : [échelle du contour, hauteur, couleur, relevé (× bump), dents].
func _ring_rows(mb: Mb, pts: PackedVector2Array, rows: Array, bump: PackedFloat32Array) -> void:
	var n := pts.size()
	for k in rows.size() - 1:
		var ra: Array = rows[k]
		var rb: Array = rows[k + 1]
		var ca: Color = ra[2]
		var cb: Color = rb[2]
		for i in n:
			var j := (i + 1) % n
			mb.quad(_ring_pt(pts, i, ra, bump), _ring_pt(pts, j, ra, bump), _ring_pt(pts, j, rb, bump), _ring_pt(pts, i, rb, bump), ca, ca, cb, cb)


func _ring_pt(pts: PackedVector2Array, i: int, row: Array, bump: PackedFloat32Array) -> Vector3:
	var f: float = row[0]
	var jag: float = row[4]
	f += jag if i % 2 == 0 else -jag
	var b: float = bump[i] if i < bump.size() else 0.0
	var p: Vector2 = pts[i] * f
	return Vector3(p.x, float(row[1]) + float(row[3]) * b, p.y)


## Prisme : dessus (polygone étoilé autour de son centre) et côtés jusqu'à `ybot`.
func _prism(mb: Mb, top: PackedVector3Array, ybot: float, tcols: PackedColorArray, scols: PackedColorArray) -> void:
	var m := top.size()
	var cen := Vector3.ZERO
	var cc := Color(0, 0, 0, 0)
	for i in m:
		cen += top[i]
		cc += tcols[i]
	cen /= float(m)
	cc = cc / float(m)
	for i in m:
		var j := (i + 1) % m
		mb.tri(cen, top[i], top[j], cc, tcols[i], tcols[j], Vector3.UP)
	for i in m:
		var j := (i + 1) % m
		var p0: Vector3 = top[i]
		var p1: Vector3 = top[j]
		var out := Vector3((p0.x + p1.x) * 0.5 - cen.x, 0.0, (p0.z + p1.z) * 0.5 - cen.z)
		var col: Color = scols[i]
		var dk := col.darkened(0.3)
		mb.quad(p0, p1, Vector3(p1.x, ybot, p1.z), Vector3(p0.x, ybot, p0.z), col, col, dk, dk, out)


## Bande entre deux lignes de même nombre de points.
func _strip(mb: Mb, top: PackedVector2Array, bot: PackedVector2Array, ct: Color, cb: Color, y: float) -> void:
	for i in top.size() - 1:
		mb.quad(_v(top[i], y), _v(top[i + 1], y), _v(bot[i + 1], y), _v(bot[i], y), ct, ct, cb, cb)


## Trait d'encre le long d'une ligne, largeur de w0 à w1.
func _line(mb: Mb, pts: PackedVector2Array, w0: float, w1: float, col: Color, y: float, closed := false) -> void:
	var n := pts.size()
	var segs := n if closed else n - 1
	for i in segs:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % n]
		var d := p1 - p0
		var l := d.length()
		if l < 0.002:
			continue
		d /= l
		var ha := lerpf(w0, w1, float(i) / float(segs)) * 0.5
		var hb := lerpf(w0, w1, float(i + 1) / float(segs)) * 0.5
		var nr := Vector2(-d.y, d.x)
		var a := p0 - d * ha  # léger recouvrement aux jointures
		var b := p1 + d * hb
		mb.quad(_v(a + nr * ha, y), _v(b + nr * hb, y), _v(b - nr * hb, y), _v(a - nr * ha, y), col, col, col, col)


## Tache irrégulière (goutte, glaçon, croûte).
func _blob(mb: Mb, cen: Vector2, rad: float, col: Color, y: float, n: int) -> void:
	var ph := randf() * TAU
	var pts := PackedVector2Array()
	for i in n:
		var t := ph + TAU * i / float(n)
		pts.append(cen + Vector2(cos(t), sin(t) * 0.8) * rad * randf_range(0.75, 1.0))
	for i in n:
		mb.tri(_v(cen, y), _v(pts[i], y), _v(pts[(i + 1) % n], y), col, col, col)


## Fuseau (reflet fixe).
func _lens(mb: Mb, cen: Vector2, length: float, width: float, ang: float, col: Color, y: float) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var nr := Vector2(-d.y, d.x)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 7:
		var f := i / 6.0
		var w := sin(f * PI) * width * 0.5
		var p := cen + d * (f - 0.5) * length
		top.append(p + nr * w)
		bot.append(p - nr * w)
	_strip(mb, top, bot, col, col, y)


## Contour rond irrégulier (ellipse du trou, z × 0.85).
func _star(rad: float, n: int, a2: float, a3: float, a5: float, jit: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p2 := randf() * TAU
	var p3 := randf() * TAU
	var p5 := randf() * TAU
	for i in n:
		var t := TAU * float(i) / float(n)
		var k := 1.0 + a2 * sin(2.0 * t + p2) + a3 * sin(3.0 * t + p3) + a5 * sin(5.0 * t + p5) + randf_range(-jit, jit)
		out.append(Vector2(cos(t), sin(t) * 0.85) * rad * k)
	return out


## Point au hasard sur l'eau d'une fosse ronde (hors de la paroi du fond, loin du bord proche).
func _star_spot(rad: float, s: float) -> Vector2:
	for i in 12:
		var x := randf_range(-0.55, 0.55) * rad
		var hz := 0.85 * rad * sqrt(maxf(1.0 - (x / rad) * (x / rad), 0.0))
		var z0 := -hz + s + 0.1
		var z1 := hz - 0.12
		if z1 > z0:
			return Vector2(x, randf_range(z0, z1))
	return Vector2(0.0, s * 0.5)


## Reflets sur l'eau des fosses en colonnes.
func _column_spots(runs: Array, spots: Array, want: int) -> void:
	var cand: Array = []
	for run in runs:
		var a: float = run["a"]
		var b: float = run["b"]
		if b - a < 0.3:
			continue
		var z0: float = _zmax(run["far"]) + float(run["s"]) + 0.08
		var z1: float = _zmin(run["near"]) - 0.1
		if z1 - z0 < 0.04:
			continue
		cand.append(Vector3((a + b) * 0.5 + randf_range(-0.05, 0.05), Y_REFLET, randf_range(z0, z1)))
	cand.shuffle()
	for i in mini(want, cand.size()):
		spots.append([cand[i], randf_range(0.2, 0.3)])


## Abscisses régulières de a à b (intérieures un peu bougées).
func _xs(a: float, b: float, cnt: int, jit: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in cnt + 1:
		var x := lerpf(a, b, float(i) / float(cnt))
		if i > 0 and i < cnt:
			x += randf_range(-jit, jit)
		out.append(x)
	return out


## Bord cassé à la hauteur z0 (pente `slope`) ; `dir` pointe vers l'intérieur du trou.
## Bois : dents alternées (échardes vers le trou, creux vers le sol). Pierre (`chip`) : éclats vers le sol.
func _edge(xs: PackedFloat32Array, z0: float, slope: float, dir: float, tip: float, notch: float, chip := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := xs.size()
	var xm := (xs[0] + xs[n - 1]) * 0.5
	for i in n:
		var x: float = xs[i]
		var z := z0 + (x - xm) * slope
		if i > 0 and i < n - 1:
			if chip:
				if randf() < 0.4:
					z -= dir * randf_range(notch * 0.4, notch)
				else:
					z += dir * randf_range(0.0, tip)
			elif i % 2 == 1:
				z += dir * randf_range(tip * 0.35, tip)
			else:
				z -= dir * randf_range(0.0, notch)
		out.append(Vector2(x, z))
	return out


func _run_at(runs: Array, x: float) -> Dictionary:
	for run in runs:
		if x > float(run["a"]) and x < float(run["b"]):
			return run
	return {}


func _on_floor(c: Vector3, p: Vector2, m: float) -> bool:
	if main == null or main.arena == null:
		return true
	var q := c + Vector3(p.x, 0.0, p.y)
	return main.arena.walkable(q, m) and not main.arena.is_bridge(q, 0.0)


static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _shifted(e: PackedVector2Array, dz: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in e:
		out.append(p + Vector2(0.0, dz))
	return out


static func _scaled(e: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in e:
		out.append(p * f)
	return out


static func _zmax(e: PackedVector2Array) -> float:
	var z := -INF
	for p in e:
		z = maxf(z, p.y)
	return z


static func _zmin(e: PackedVector2Array) -> float:
	var z := INF
	for p in e:
		z = minf(z, p.y)
	return z


static func _edge_col(p: Vector2, far: Color, near: Color) -> Color:
	return far.lerp(near, clampf(0.5 + 0.5 * p.y / maxf(p.length(), 0.001), 0.0, 1.0))


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
	# ennemis projetés dans un trou : à l'eau (pas contre une pièce de décor : elle les arrête)
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or e.kind == "brute" or e.kind == "funa":
			continue
		var kn: Vector3 = e._knock
		if kn.length() > 2.0 and is_hole(e.position, 0.2) and not main.arena.on_set_piece(e.position, 0.45):
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
			var want := Color(Toon.FOAM, 0.8) if _warn < 0.15 else Color(Toon.PRUSSIAN, 0.5)
			if m.albedo_color != want:  # la matière n'est réécrite (et renvoyée au rendu) qu'au changement
				m.albedo_color = want
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
	_band_z = randf_range(_zone.position.y + 2.0, _zone.end.y - 2.0)
	if not main.arena.walkable(Vector3(main.hero.position.x, 0, _band_z), 0.0):
		_band_z = main.hero.position.z
	if absf(_band_z - main.hero.position.z) > 5.0:
		_band_z = clampf(main.hero.position.z + randf_range(-2.0, 2.0), _zone.position.y + 1.5, _zone.end.y - 1.5)
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
	# plus de bloc : une gerbe d'écume en travers de la bande
	for k in 5:
		main._splash(Vector3(lerpf(_zone.position.x + 0.8, _zone.end.x - 0.8, float(k) / 4.0), 0.3, _band_z), Toon.FOAM, 10)
	_crest_t = 0.0
	main.sfx.play("strike", 0.6)
	main.shake = maxf(main.shake, 0.3)
	_end_band()


func _end_band() -> void:
	if _band:
		_band.queue_free()
		_band = null
