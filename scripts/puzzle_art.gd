extends RefCounted
const SHOW_EMA := false
## Décor des énigmes des recoins (appelé par main.gd : _puzzle_node, _update_puzzle, _solve_puzzle, _puzzle_fail).
## Stèle de pierre (sekihi) et sa figure qui se trace toute seule au pinceau dans un cercle de pierres,
## lanternes de pierre (tōrō) numérotées à relier dans l'ordre, esprit errant (hitodama) à entourer.
## Maillages et matières partagés entre recoins ; seules les matières animées (encre de la figure, papier
## et lueur des lanternes, flamme et cercle de l'esprit) sont propres à chaque énigme.
## Rien n'est alloué image par image : update() ne fait que déplacer des nœuds et régler des valeurs.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const KANJI_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const INK_SHADER := "res://shaders/puzzle_ink.gdshader"

## Centre de la figure peinte au sol, devant la stèle (côté caméra) ; la stèle recule d'autant.
const GLYPH_O := Vector3(0, 0, 1.25)
const GLYPH_K := 0.75
const STELE_Z := -0.45
const INLAY_R := 1.3
## Numéros des lanternes, sur le papier du foyer (il y en a 3 à 5).
const NUMS := ["一", "二", "三", "四", "五"]
const SPIRIT_RING_R := 1.4
const DRAW_PERIOD := 3.4  # la figure se trace, reste, s'efface : un cycle (s)
const FAIL_T := 0.6

const STONE := Color("#8A857C")
const STONE_DARK := Color("#6E6A63")
const MOSS := Color("#5F7D3C")
## Pierre, mousse et galets des énigmes à la teinte du monde (design/PALETTES.md) ; sinon la palette commune.
const WORLD_STONE := {
	1: {"stone": Color("#8E8678"), "moss": Color("#5F7D3C"), "pebble": Color("#9C978C")},
	2: {"stone": Color("#7E8678"), "moss": Color("#4A6A44"), "pebble": Color("#8A9284")},
	3: {"stone": Color("#9A9EAC"), "moss": Color("#C7CFD8"), "pebble": Color("#A9AFBE")},
	4: {"stone": Color("#5E5753"), "moss": Color("#6E5A48"), "pebble": Color("#4A4542")},
	5: {"stone": Color("#8C8780"), "moss": Color("#6E6A62"), "pebble": Color("#9A958D")},
	6: {"stone": Color("#8A7A78"), "moss": Color("#7E5A3E"), "pebble": Color("#8C7C7A")},
	7: {"stone": Color("#AE9E84"), "moss": Color("#4E6E7E"), "pebble": Color("#A89C86")},
	8: {"stone": Color("#6E6A70"), "moss": Color("#5A5660"), "pebble": Color("#7A7680")},
}
static var _wid := 0
const ENGRAVE := Color("#F3E2AE")
const INK_COL := Color(0.106, 0.102, 0.118, 0.88)
const PAPER_DIM := Color("#B9AD93")
const PAPER_LIT := Color("#FFE6AE")
const LAMP_EMIT := Color("#FFB648")
const SPIRIT := Color("#BFF1FA")
const SPIRIT_INK := Color("#2E8FA3")
const PETAL := Color("#F6C1CC")

const P_INK := &"ink"
const P_HEAD := &"head_col"
const P_REVEAL := &"reveal"
const P_FADE := &"fade"
const P_DASH := &"dash"
const P_FILL := &"dash_fill"
const P_SCROLL := &"scroll"
const P_DRY := &"dry"

static var _meshes := {}
static var _mats := {}


## Change de monde : les matières de pierre, mousse et galets sont refaites à la teinte du monde
## (arena.set_world) ; les autres (papier, flamme, encre) sont communes.
static func set_world(id: int) -> void:
	if id == _wid:
		return
	_wid = id
	for k in ["stone", "stone_dark", "stone_light", "moss", "pebble", "inlay", "lantern"]:
		_mats.erase(k)


static func _wcol(key: String, fallback: Color) -> Color:
	var d: Dictionary = WORLD_STONE.get(_wid, {})
	return d.get(key, fallback)
static var _shader: Shader = null
static var _grad: Gradient = null


# ------------------------------------------------------------------ stèle

## Stèle (sekihi) sur socle à degrés, mousse, shimenawa et shide, cartouche gravé de la figure (`kanji`),
## bol d'offrande et deux bougies ; devant, la figure `pts` peinte dans un cercle de pierres.
static func build_stele(n: Node3D, pk: Dictionary, pts: PackedVector3Array, shape: String, kanji: String) -> void:
	var st := Node3D.new()
	st.name = "Stele"
	n.add_child(st)
	st.position = Vector3(0, 0, STELE_Z)
	st.rotation.y = randf_range(-0.07, 0.07)
	pk["stele"] = st
	var stone := _mat("stone")
	Toon.blob(st, 0.95, 0.32)
	Toon.part(st, _mesh("plinth0"), _mat("stone_dark"), Vector3(0, 0.08, 0))
	Toon.part(st, _mesh("plinth1"), stone, Vector3(0, 0.23, 0))
	var slab := Node3D.new()
	st.add_child(slab)
	slab.position = Vector3(0, 0.3, 0)
	slab.rotation.z = randf_range(-0.035, 0.035)  # usée par les ans, un rien de guingois
	Toon.part(slab, _mesh("slab"), stone, Vector3(0, 0.625, 0))
	var top := Toon.part(slab, _mesh("slab_top"), stone, Vector3(0, 1.25, 0))
	top.rotation.x = PI / 2.0
	# cartouche creusé : rebord clair, fond sombre, la figure gravée y luit
	Toon.part(slab, _mesh("panel_rim"), _mat("stone_light"), Vector3(0, 0.68, 0.104))
	Toon.part(slab, _mesh("panel"), _mat("panel"), Vector3(0, 0.68, 0.112))
	var eng := _label(slab, kanji, Vector3(0, 0.68, 0.124), Color(ENGRAVE, 0.7), 120, 0.0027, false, 10)
	eng.outline_modulate = Color(Toon.SUMI, 0.55)
	pk["label"] = eng
	# mousse au sommet et sur le socle
	Toon.part(slab, _mesh("moss"), _mat("moss"), Vector3(-0.1, 1.55, 0), Vector3(1.3, 0.35, 0.85))
	Toon.part(st, _mesh("moss"), _mat("moss"), Vector3(0.32, 0.31, 0.17), Vector3(1.5, 0.4, 1.0))
	Toon.part(st, _mesh("moss"), _mat("moss"), Vector3(-0.5, 0.17, 0.3), Vector3(1.2, 0.35, 1.0))
	# shimenawa : corde de paille autour de la pierre, deux shide de papier en zigzag
	Toon.part(slab, _mesh("rope"), _mat("rope"), Vector3(0, 1.12, 0), Vector3(1, 1, 0.36))
	var paper := _mat("paper")
	for sx in [-1.0, 1.0]:
		for j in 3:
			var sd := Toon.part(slab, _mesh("shide"), paper, Vector3(float(sx) * 0.27 + (0.03 if j == 1 else 0.0), 1.06 - 0.085 * float(j), 0.15))
			sd.rotation.z = 0.25 if j == 1 else -0.15
			sd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# offrandes : bol d'eau et deux bougies
	Toon.part(st, _mesh("bowl"), stone, Vector3(0, 0.045, 0.56))
	_part_flat(st, _mesh("disc"), _mat("water"), Vector3(0, 0.092, 0.56), Vector3(0.12, 1, 0.12))
	var flames: Array = []
	for sx in [-1.0, 1.0]:
		Toon.part(st, _mesh("candle"), _mat("wax"), Vector3(float(sx) * 0.4, 0.085, 0.5))
		flames.append(_part_flat(st, _mesh("flame"), _mat("flame"), Vector3(float(sx) * 0.4, 0.215, 0.5), Vector3(1, 1.7, 1)))
	pk["flames"] = flames
	# cercle de pierres incrusté au sol, la figure au pinceau dedans
	_part_flat(n, _mesh("disc"), _mat("inlay"), GLYPH_O + Vector3(0, 0.012, 0), Vector3(INLAY_R, 1, INLAY_R))
	var cnt := 7 if Toon.lite else 11
	for i in cnt:
		var a := TAU * (float(i) + randf_range(-0.2, 0.2)) / float(cnt)
		var pp := GLYPH_O + Vector3(cos(a), 0, sin(a)) * (INLAY_R + 0.08)
		if pp.z < 0.1:
			continue  # cachée sous le socle
		var pb := _part_flat(n, _mesh("pebble"), _mat("pebble"), pp + Vector3(0, 0.025, 0), Vector3(randf_range(1.1, 1.6), 0.38, randf_range(0.8, 1.1)))
		pb.rotation.y = randf() * TAU
	var key := "fig_" + shape
	if not _meshes.has(key):
		_meshes[key] = ribbon_mesh([pts], 0.11, 1.0, 0.03)
	var fig: Mesh = _meshes[key]
	# la figure entière, à peine visible, et par-dessus le trait qui se trace (départ -> arrivée)
	_part_flat(n, fig, _mat("ghost"), Vector3.ZERO)
	var gm := ink_mat(INK_COL, 0.0, Color(Toon.VERMILION, 1.0))
	gm.render_priority = 1
	_part_flat(n, fig, gm, Vector3(0, 0.004, 0))
	pk["gmat"] = gm
	pk["cyc0"] = -randf() * DRAW_PERIOD
	if not pts.is_empty():
		# sceau vermillon : c'est là que le pinceau se pose
		_part_flat(n, _mesh("disc"), _mat("seal"), Vector3(pts[0].x, 0.04, pts[0].z), Vector3(0.12, 1, 0.12))


static func _update_stele(pk: Dictionary, t: float, fk: float) -> void:
	var gmv = pk.get("gmat")
	if gmv is ShaderMaterial:
		var gm: ShaderMaterial = gmv
		var age := t - float(pk["cyc0"])
		if age < 0.0:
			# raté : la figure entière, vermillon, le temps de la secousse ; puis elle se retrace
			gm.set_shader_parameter(P_INK, Color(Toon.VERMILION, 0.9))
			gm.set_shader_parameter(P_REVEAL, 1.0)
			gm.set_shader_parameter(P_FADE, 1.0)
		else:
			var u := fmod(age, DRAW_PERIOD) / DRAW_PERIOD
			var rv := 1.0
			var fd := 1.0
			if u < 0.55:
				var e := u / 0.55
				rv = -0.02 + 1.02 * (1.0 - (1.0 - e) * (1.0 - e))
			elif u > 0.8:
				fd = 1.0 - (u - 0.8) / 0.2
			gm.set_shader_parameter(P_INK, INK_COL)
			gm.set_shader_parameter(P_REVEAL, rv)
			gm.set_shader_parameter(P_FADE, fd)
	var lb = pk.get("label")
	if is_instance_valid(lb):
		var l: Label3D = lb
		l.modulate = Color(ENGRAVE, 0.5 + 0.3 * (0.5 + 0.5 * sin(t * 2.2)))
	var fl: Array = pk["flames"]
	for i in fl.size():
		var f = fl[i]
		if is_instance_valid(f):
			var fn: Node3D = f
			fn.scale = Vector3(1.0, 1.7 * (0.85 + 0.15 * sin(t * 13.0 + float(i) * 2.1)), 1.0)
	var sv = pk.get("stele")
	if is_instance_valid(sv):
		var st: Node3D = sv
		st.position = Vector3(sin(t * 55.0) * 0.06 * fk, 0, STELE_Z)


static func _solve_stele(pk: Dictionary, root: Node3D) -> void:
	var gmv = pk.get("gmat")
	if gmv is ShaderMaterial:
		var gm: ShaderMaterial = gmv
		gm.set_shader_parameter(P_INK, Color(Toon.GOLD.lightened(0.15), 0.95))
		gm.set_shader_parameter(P_HEAD, Color(0, 0, 0, 0))
		gm.set_shader_parameter(P_REVEAL, 1.0)
		gm.set_shader_parameter(P_FADE, 1.0)
	var lb = pk.get("label")
	if is_instance_valid(lb):
		var l: Label3D = lb
		l.outline_modulate = Color(Toon.GOLD.darkened(0.55), 0.85)
		var tl := l.create_tween()
		tl.tween_property(l, "modulate", Color(1.0, 0.85, 0.42, 1.0), 0.35)
	var sv = pk.get("stele")
	if is_instance_valid(sv):
		var st: Node3D = sv
		st.position = Vector3(0, 0, STELE_Z)
	# colonne de lumière douce sur la stèle, pétales et poussière d'or qui montent
	var bm := Toon.flat(Color(Toon.GOLD.lightened(0.45), 0.0))
	var beam := _part_flat(root, _mesh("beam"), bm, Vector3(0, 2.7, STELE_Z))
	var tb := beam.create_tween()
	tb.tween_property(bm, "albedo_color:a", 0.38, 0.35)
	tb.tween_property(bm, "albedo_color:a", 0.0, 1.5).set_delay(0.6)
	tb.tween_callback(beam.queue_free)
	_motes(root, Vector3(0, 1.0, STELE_Z + 0.2), PETAL, 10 if Toon.lite else 22, 2.4, 1.6, 0.45)
	_motes(root, GLYPH_O + Vector3(0, 0.1, 0), Toon.GOLD.lightened(0.3), 6 if Toon.lite else 16, 1.8, 1.2, 0.9)


# ------------------------------------------------------------------ lanternes

## Tōrō de pierre (socle, fût, foyer de papier entre quatre montants, toit à double pente, hōju) aux places
## `spots` (dans l'ordre), chiffre au-dessus et numéral sur le papier ; pointillés discrets de l'une à la
## suivante ; petite planchette (ema) près de la première pour la consigne.
static func build_lanterns(n: Node3D, pk: Dictionary, spots: Array, c: Vector3) -> void:
	var mats: Array = []
	var glows: Array = []
	var halos: Array = []
	var digits: Array = []
	var lnodes: Array = []
	var stone := _mat("lantern")
	var roof := _mat("roof")
	for i in spots.size():
		var q: Vector3 = spots[i]
		var ln := Node3D.new()
		n.add_child(ln)
		ln.position = q - c
		lnodes.append(ln)
		var gmat := _glow_mat(Color(LAMP_EMIT, 0.0), false)
		_part_flat(ln, Toon.blob_mesh(), gmat, Vector3(0, 0.02, 0), Vector3(0.95, 1, 0.95))
		glows.append(gmat)
		Toon.blob(ln, 0.42, 0.3)
		Toon.part(ln, _mesh("tr_base"), stone, Vector3(0, 0.05, 0))
		Toon.part(ln, _mesh("tr_base2"), stone, Vector3(0, 0.13, 0))
		Toon.part(ln, _mesh("tr_shaft"), stone, Vector3(0, 0.37, 0))
		Toon.part(ln, _mesh("tr_mid"), stone, Vector3(0, 0.62, 0))
		var lamp := Toon.mat(PAPER_DIM, false)
		lamp.emission_enabled = true
		lamp.emission = Color.BLACK
		lamp.emission_energy_multiplier = 1.4
		Toon.part(ln, _mesh("tr_paper"), lamp, Vector3(0, 0.79, 0))
		mats.append(lamp)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				Toon.part(ln, _mesh("tr_post"), stone, Vector3(float(sx) * 0.12, 0.79, float(sz) * 0.12))
		Toon.part(ln, _mesh("tr_eave"), roof, Vector3(0, 0.945, 0))
		Toon.part(ln, _mesh("tr_roof"), roof, Vector3(0, 1.03, 0))
		Toon.part(ln, _mesh("tr_hoju"), stone, Vector3(0, 1.13, 0), Vector3(1, 1.25, 1))
		Toon.part(ln, _mesh("tr_tip"), stone, Vector3(0, 1.22, 0))
		var hmat := _glow_mat(Color(LAMP_EMIT, 0.0), true)
		_part_flat(ln, _mesh("lamp_halo"), hmat, Vector3(0, 0.8, 0))
		halos.append(hmat)
		# numéral peint sur le papier du foyer, chiffre net au-dessus du toit
		_label(ln, String(NUMS[i]) if i < NUMS.size() else str(i + 1), Vector3(0, 0.79, 0.127), Color(Toon.SUMI, 0.85), 96, 0.0019, false, 0)
		digits.append(_label(ln, str(i + 1), Vector3(0, 1.5, 0), Toon.SUMI, 110, 0.0034, true, 18))
	pk["mats"] = mats
	pk["glows"] = glows
	pk["halos"] = halos
	pk["digits"] = digits
	pk["lnodes"] = lnodes
	# chemin de points de chaque lanterne à la suivante (les points avancent dans le sens du trait)
	var paths: Array = []
	for i in range(spots.size() - 1):
		var a: Vector3 = spots[i] - c
		var b: Vector3 = spots[i + 1] - c
		var dv := Vector3(b.x - a.x, 0, b.z - a.z)
		var dl := dv.length()
		if dl < 1.1:
			continue
		var dir := dv / dl
		var seg := PackedVector3Array()
		seg.append(a + dir * 0.5)
		seg.append(b - dir * 0.5)
		paths.append(seg)
	if not paths.is_empty():
		var pm := ink_mat(Color(Toon.SUMI, 0.3), 0.24)
		pm.set_shader_parameter(P_DRY, 0.0)
		pm.set_shader_parameter(P_FILL, 0.42)
		_part_flat(n, ribbon_mesh(paths, 0.04, 0.0, 0.02), pm, Vector3.ZERO)
		pk["pmat"] = pm
	# ema sur son piquet, à côté de la première lanterne (vers l'intérieur), tourné vers la caméra
	if SHOW_EMA and not spots.is_empty():  # panneau retiré (demandé) : les numéros suffisent
		var q1: Vector3 = spots[0]
		var side := -1.0 if q1.x > c.x else 1.0
		var sg := Node3D.new()
		n.add_child(sg)
		sg.position = q1 - c + Vector3(side * 0.75, 0, 0.22)
		Toon.part(sg, _mesh("ema_post"), _mat("wood_dark"), Vector3(0, 0.36, -0.03))
		Toon.blob(sg, 0.3, 0.25)
		var board := Node3D.new()
		sg.add_child(board)
		board.position = Vector3(0, 0.84, 0)
		board.rotation.x = -0.5
		Toon.part(board, _mesh("ema_board"), _mat("wood"), Vector3.ZERO)
		Toon.part(board, _mesh("ema_cap"), _mat("wood_dark"), Vector3(0, 0.245, 0))
		_label(board, UiKit.plain("D'UN SEUL TRAIT"), Vector3(0, 0.085, 0.021), Toon.SUMI, 30, 0.0032, false, 0)
		_label(board, "1 → %d" % spots.size(), Vector3(0, -0.075, 0.021), Toon.VERMILION, 60, 0.0032, false, 0)
	if not Toon.lite:
		# une seule lumière chaude pour tout le cercle, éteinte tant qu'aucune lanterne ne brûle
		var li := OmniLight3D.new()
		li.light_color = Color("#FFB866")
		li.omni_range = 3.8
		li.light_energy = 0.0
		li.shadow_enabled = false
		li.visible = false
		li.position = Vector3(0, 1.1, 0)
		n.add_child(li)
		pk["light"] = li


static func _update_lanterns(pk: Dictionary, t: float, lit: int, fk: float) -> void:
	var mats: Array = pk["mats"]
	var glows: Array = pk["glows"]
	var halos: Array = pk["halos"]
	var digits: Array = pk["digits"]
	var lnodes: Array = pk["lnodes"]
	var spots: Array = pk["lanterns"]
	var c: Vector3 = pk["pos"]
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	for i in mats.size():
		var m: StandardMaterial3D = mats[i]
		var g: StandardMaterial3D = glows[i]
		var h: StandardMaterial3D = halos[i]
		var col: Color = Toon.SUMI
		if fk > 0.0:
			m.albedo_color = PAPER_DIM.lerp(Toon.VERMILION, fk)
			m.emission = Color.BLACK
			g.albedo_color = Color(Toon.VERMILION, 0.35 * fk)
			h.albedo_color = Color(LAMP_EMIT, 0.0)
			col = Toon.VERMILION
		elif i < lit:
			m.albedo_color = PAPER_LIT
			m.emission = LAMP_EMIT
			g.albedo_color = Color(LAMP_EMIT, 0.5)
			h.albedo_color = Color(LAMP_EMIT, 0.42)
			col = Toon.GOLD
		elif i == lit:
			# la suivante à toucher respire
			m.albedo_color = PAPER_DIM.lerp(PAPER_LIT, 0.35 * pulse)
			m.emission = Color.BLACK
			g.albedo_color = Color(LAMP_EMIT, 0.08 + 0.17 * pulse)
			h.albedo_color = Color(LAMP_EMIT, 0.0)
			col = Toon.VERMILION
		else:
			m.albedo_color = PAPER_DIM
			m.emission = Color.BLACK
			g.albedo_color = Color(LAMP_EMIT, 0.0)
			h.albedo_color = Color(LAMP_EMIT, 0.0)
		var dv = digits[i]
		if is_instance_valid(dv):
			var dl: Label3D = dv
			dl.modulate = col
		var lv = lnodes[i]
		if is_instance_valid(lv) and i < spots.size():
			var ln: Node3D = lv
			var q: Vector3 = spots[i]
			ln.position = Vector3(q.x - c.x + sin(t * 55.0 + float(i)) * 0.05 * fk, 0, q.z - c.z)
	var pmv = pk.get("pmat")
	if pmv is ShaderMaterial:
		var pm: ShaderMaterial = pmv
		pm.set_shader_parameter(P_SCROLL, -t * 0.45)
	var lv2 = pk.get("light")
	if is_instance_valid(lv2):
		var li: OmniLight3D = lv2
		var want := 1.5 * float(lit) / float(maxi(1, mats.size())) if fk <= 0.0 else 0.0
		li.light_energy = lerpf(li.light_energy, want, 0.15)
		li.visible = li.light_energy > 0.02


static func _solve_lanterns(pk: Dictionary, root: Node3D) -> void:
	var mats: Array = pk["mats"]
	for i in mats.size():
		var m: StandardMaterial3D = mats[i]
		m.albedo_color = PAPER_LIT
		m.emission = LAMP_EMIT
		var g: StandardMaterial3D = pk["glows"][i]
		g.albedo_color = Color(LAMP_EMIT, 0.5)
		var h: StandardMaterial3D = pk["halos"][i]
		h.albedo_color = Color(LAMP_EMIT, 0.45)
		var dv = pk["digits"][i]
		if is_instance_valid(dv):
			var dl: Label3D = dv
			dl.modulate = Toon.GOLD
	var spots: Array = pk["lanterns"]
	var c: Vector3 = pk["pos"]
	var lnv: Array = pk["lnodes"]
	var pts := PackedVector3Array()
	for i in spots.size():
		var q: Vector3 = spots[i]
		pts.append(Vector3(q.x - c.x, 0.95, q.z - c.z))
		var lv = lnv[i] if i < lnv.size() else null
		if is_instance_valid(lv):
			var ln: Node3D = lv
			ln.position = Vector3(q.x - c.x, 0, q.z - c.z)
	_motes(root, Vector3.ZERO, Color("#FFD27A"), 8 if Toon.lite else 6 * spots.size(), 1.8, 1.0, 0.1, true, pts)
	var lv2 = pk.get("light")
	if is_instance_valid(lv2):
		var li: OmniLight3D = lv2
		li.visible = true
		# bouffée de lumière, puis l'émission des papiers suffit (rendu de compatibilité : une passe de plus par objet éclairé)
		var tw := li.create_tween()
		tw.tween_property(li, "light_energy", 1.8, 0.4)
		tw.tween_property(li, "light_energy", 0.0, 1.6).set_delay(2.5)
		tw.tween_callback(li.hide)


# ------------------------------------------------------------------ esprit errant

## Hitodama : flamme bleutée en goutte (cœur blanc, halo, traîne de feux follets), son ombre ; au sol un
## cercle de pointillés à flèches qui tourne autour de lui ; au-dessus, l'icône du geste (boucle fléchée
## qu'un point parcourt). Les nœuds « Spirit » et « Shadow » gardent leur nom.
static func build_spirit(n: Node3D, pk: Dictionary) -> void:
	var ring := Node3D.new()
	ring.name = "Ring"
	n.add_child(ring)
	_part_flat(ring, _mesh("disc"), _mat("spirit_wash"), Vector3(0, 0.011, 0), Vector3(SPIRIT_RING_R, 1, SPIRIT_RING_R))
	var rm := ink_mat(Color(SPIRIT_INK, 0.75), TAU * SPIRIT_RING_R / 18.0)
	_part_flat(ring, _mesh("spirit_ring"), rm, Vector3.ZERO)
	var am := ink_mat(Color(SPIRIT_INK, 0.92))
	am.set_shader_parameter(P_DRY, 0.0)
	_part_flat(ring, _mesh("spirit_arrows"), am, Vector3(0, 0.002, 0))
	pk["ring"] = ring
	pk["rmat"] = rm
	pk["amat"] = am
	var sh := Toon.blob(n, 0.42, 0.22)
	sh.name = "Shadow"
	pk["shadow"] = sh
	var sp := Node3D.new()
	sp.name = "Spirit"
	n.add_child(sp)
	sp.position = Vector3(0, 0.95, 0)
	pk["sp"] = sp
	_part_flat(sp, _mesh("halo"), _mat("spirit_halo"), Vector3(0, 0.05, 0))
	var body := Node3D.new()
	sp.add_child(body)
	pk["body"] = body
	# flamme cernée d'encre bleue : goutte + pointe qui file vers le haut
	var fm := Toon.flat(Color(SPIRIT, 0.85))
	var fo := StandardMaterial3D.new()
	fo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fo.albedo_color = SPIRIT_INK
	fo.cull_mode = BaseMaterial3D.CULL_FRONT
	fo.grow = true
	fo.grow_amount = 0.022
	fm.next_pass = fo
	pk["smat"] = fm
	_part_flat(body, _mesh("sp_drop"), fm, Vector3.ZERO, Vector3(1, 1.1, 1))
	_part_flat(body, _mesh("sp_tail"), fm, Vector3(0, 0.3, 0))
	_part_flat(body, _mesh("sp_core"), _mat("spirit_core"), Vector3(0, -0.02, 0))
	var wisps: Array = []
	for i in (2 if Toon.lite else 4):
		wisps.append(_part_flat(n, _mesh("sp_wisp"), _mat("spirit_wisp"), sp.position, Vector3.ONE * (1.0 - 0.17 * float(i))))
	pk["wisps"] = wisps
	# icône du geste, inclinée face à la caméra : boucle fléchée, un point en fait le tour
	var ic := Node3D.new()
	sp.add_child(ic)
	ic.position = Vector3(0, 0.88, 0)
	ic.rotation.x = 0.54
	_part_flat(ic, _mesh("icon_dark"), _mat("icon_dark"), Vector3.ZERO)
	_part_flat(ic, _mesh("icon_light"), _mat("icon_light"), Vector3(0, 0.004, 0))
	pk["dot"] = _part_flat(ic, _mesh("icon_dot"), _mat("icon_dot"), Vector3(0.2, 0.012, 0))
	_label(sp, UiKit.plain("ENTOURE"), Vector3(0, 1.22, 0), SPIRIT_INK, 34, 0.0045, true, 12)
	pk["at"] = 0.0


static func _update_spirit(pk: Dictionary, n: Node3D, t: float, q: Vector3, fk: float) -> void:
	var spv = pk.get("sp")
	if not is_instance_valid(spv):
		return
	var sp: Node3D = spv
	var ph := float(pk["t"])
	var lx := q.x - n.position.x
	var lz := q.z - n.position.z
	sp.position = Vector3(lx + sin(t * 60.0) * 0.07 * fk, 0.95 + 0.12 * sin(t * 3.0 + ph), lz)
	var bv = pk.get("body")
	if is_instance_valid(bv):
		var body: Node3D = bv
		body.rotation.z = 0.14 * sin(t * 2.3 + ph)
		body.scale = Vector3(1.0, 1.0 + 0.08 * sin(t * 7.0 + ph), 1.0)
	var rv = pk.get("ring")
	if is_instance_valid(rv):
		var ring: Node3D = rv
		ring.position = Vector3(lx, 0, lz)
		ring.rotation.y = -t * 0.55  # dans le sens des flèches
	var shv = pk.get("shadow")
	if is_instance_valid(shv):
		var sh: Node3D = shv
		sh.position = Vector3(lx, 0.012, lz)
	# traîne : chaque feu follet suit le précédent
	var dt := clampf(t - float(pk["at"]), 0.0, 0.1)
	pk["at"] = t
	var k := 1.0 - exp(-dt * 7.0)
	var prev := sp.position + Vector3(0, -0.04, 0)
	var wisps: Array = pk["wisps"]
	for w in wisps:
		if is_instance_valid(w):
			var wn: Node3D = w
			wn.position = wn.position.lerp(prev, k)
			prev = wn.position
	var dv = pk.get("dot")
	if is_instance_valid(dv):
		var dot: Node3D = dv
		var a := 0.6 + (TAU - 0.9) * fmod(t * 0.5 + ph, 1.0)
		dot.position = Vector3(cos(a) * 0.2, 0.012, sin(a) * 0.2)
	var smv = pk.get("smat")
	if smv is StandardMaterial3D:
		var sm: StandardMaterial3D = smv
		sm.albedo_color = Color(SPIRIT, 0.85).lerp(Color(Toon.VERMILION, 0.9), fk)
	var rmv = pk.get("rmat")
	if rmv is ShaderMaterial:
		var rm: ShaderMaterial = rmv
		rm.set_shader_parameter(P_INK, Color(SPIRIT_INK, 0.75).lerp(Color(Toon.VERMILION, 0.9), fk))


static func _solve_spirit(pk: Dictionary, root: Node3D) -> void:
	# le cercle et les feux follets s'effacent
	var rv = pk.get("ring")
	if is_instance_valid(rv):
		var ring: Node3D = rv
		var tf := ring.create_tween()
		tf.set_parallel(true)
		var rmv = pk.get("rmat")
		if rmv is ShaderMaterial:
			var sm_rmv: ShaderMaterial = rmv
			tf.tween_method(func(x: float) -> void: sm_rmv.set_shader_parameter("fade", x), 1.0, 0.0, 0.5)
		var amv = pk.get("amat")
		if amv is ShaderMaterial:
			var sm_amv: ShaderMaterial = amv
			tf.tween_method(func(x: float) -> void: sm_amv.set_shader_parameter("fade", x), 1.0, 0.0, 0.5)
		tf.chain().tween_callback(ring.queue_free)
	var wisps: Array = pk["wisps"]
	for w in wisps:
		if is_instance_valid(w):
			w.queue_free()
	var shv = pk.get("shadow")
	if is_instance_valid(shv):
		shv.queue_free()
	var spv = pk.get("sp")
	if not is_instance_valid(spv):
		return
	# l'esprit tourbillonne vers le ciel en semant des étincelles
	var sp: Node3D = spv
	var p0 := sp.position
	var sparks := _motes(root, p0, Color("#E6FCFF"), 10 if Toon.lite else 26, 1.4, 0.5, 0.2, false)
	var swirl := func(k: float) -> void:
		var r := 0.45 * k
		var a := k * 10.0
		var p := p0 + Vector3(cos(a) * r, k * k * 5.0, sin(a) * r)
		sp.position = p
		sp.scale = Vector3.ONE * (1.0 - 0.7 * k)
		if is_instance_valid(sparks):
			sparks.position = p
	var tw := sp.create_tween()
	tw.tween_method(swirl, 0.0, 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(sp.queue_free)
	var ts := sparks.create_tween()
	ts.tween_callback(sparks.set_emitting.bind(false)).set_delay(1.5)
	ts.tween_callback(sparks.queue_free).set_delay(1.6)


# ------------------------------------------------------------------ entrées (main.gd)

## Chaque image, tant que l'énigme n'est pas résolue : `lit` lanternes allumées par le trait en cours,
## `q` position de l'esprit (monde). Secousse vermillon pendant FAIL_T après un raté (pk.fail_t).
static func update(pk: Dictionary, n: Node3D, t: float, lit: int, q: Vector3) -> void:
	var fk := clampf(1.0 - (t - float(pk["fail_t"])) / FAIL_T, 0.0, 1.0)
	match String(pk["pz"]):
		"stele":
			_update_stele(pk, t, fk)
		"lanterns":
			_update_lanterns(pk, t, lit, fk)
		"spirit":
			_update_spirit(pk, n, t, q, fk)


## Raté (main._puzzle_fail) : la figure de la stèle passe au vermillon, puis se retrace depuis le début.
static func fail(pk: Dictionary, t: float) -> void:
	if String(pk["pz"]) == "stele":
		pk["cyc0"] = t + FAIL_T


## Résolue (main._solve_puzzle) : gravure et figure dorées, colonne de lumière et pétales ; lanternes toutes
## allumées ; l'esprit s'envole. `n` sans type : le nœud du recoin peut avoir été libéré.
static func solve(pk: Dictionary, n) -> void:
	if not is_instance_valid(n):
		return
	var root: Node3D = n
	match String(pk["pz"]):
		"stele":
			_solve_stele(pk, root)
		"lanterns":
			_solve_lanterns(pk, root)
		"spirit":
			_solve_spirit(pk, root)


# ------------------------------------------------------------------ briques

## Matière d'encre (shaders/puzzle_ink.gdshader) : trait au pinceau, `dash` > 0 pour des pointillés (m),
## `head` : couleur de la pointe pendant le tracé progressif.
static func ink_mat(col: Color, dash := 0.0, head := Color(0, 0, 0, 0)) -> ShaderMaterial:
	if _shader == null:
		_shader = load(INK_SHADER) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(P_INK, col)
	m.set_shader_parameter(P_HEAD, head)
	m.set_shader_parameter(P_DASH, dash)
	m.set_shader_parameter(P_DRY, 0.35 if Toon.lite else 0.7)
	return m


## Ruban d'encre à plat (plan XZ, hauteur `y`) le long de chaque tracé de `paths` (PackedVector3Array),
## le tout dans un seul maillage. UV.x : abscisse normalisée du tracé, UV.y : travers, UV2.x : mètres.
## `taper` : 0 = largeur constante, 1 = pinceau (appui arrondi au départ, pointe effilée à l'arrivée).
static func ribbon_mesh(paths: Array, w: float, taper: float, y := 0.03) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	for pv in paths:
		var pts := _resample(pv, 0.07)
		var cnt := pts.size()
		if cnt < 2:
			continue
		var total := 0.0
		for i in range(1, cnt):
			total += _flat(pts[i] - pts[i - 1]).length()
		total = maxf(total, 0.001)
		var s := 0.0
		var base := verts.size()
		for i in cnt:
			if i > 0:
				s += _flat(pts[i] - pts[i - 1]).length()
			var u := s / total
			var k := 1.0
			if taper > 0.0:
				var press := minf(1.0, 0.55 + 0.45 * s / 0.12)
				k = lerpf(1.0, press * (1.0 - 0.7 * pow(u, 1.6)), taper)
			var side := _side(pts, i) * (w * k)
			var p := Vector3(pts[i].x, y, pts[i].z)
			verts.append(p + side)
			verts.append(p - side)
			uvs.append(Vector2(u, 0.0))
			uvs.append(Vector2(u, 1.0))
			uv2s.append(Vector2(s, 0.0))
			uv2s.append(Vector2(s, 0.0))
			if i > 0:
				var a := base + (i - 1) * 2
				idx.append(a)
				idx.append(a + 1)
				idx.append(a + 2)
				idx.append(a + 1)
				idx.append(a + 3)
				idx.append(a + 2)
	var am := ArrayMesh.new()
	if idx.is_empty():
		return am
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


## Côté du ruban au point `i` (onglet aux angles, borné pour les pointes aiguës).
static func _side(pts: PackedVector3Array, i: int) -> Vector3:
	var cnt := pts.size()
	var t0 := _flat(pts[i] - pts[maxi(i - 1, 0)])
	var t1 := _flat(pts[mini(i + 1, cnt - 1)] - pts[i])
	if t0.length_squared() < 0.00000001:
		t0 = t1
	if t1.length_squared() < 0.00000001:
		t1 = t0
	if t0.length_squared() < 0.00000001:
		return Vector3.RIGHT
	t0 = t0.normalized()
	t1 = t1.normalized()
	var s0 := Vector3(-t0.z, 0, t0.x)
	var s1 := Vector3(-t1.z, 0, t1.x)
	var m := s0 + s1
	if m.length_squared() < 0.000001:
		return s0
	m = m.normalized()
	return m / maxf(m.dot(s0), 0.5)


## Tracé redécoupé tous les `step` m environ (les angles restent exacts).
static func _resample(src: PackedVector3Array, step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if src.is_empty():
		return out
	out.append(src[0])
	for i in range(1, src.size()):
		var a := src[i - 1]
		var b := src[i]
		var m := maxi(1, ceili(_flat(b - a).length() / step))
		for j in range(1, m + 1):
			out.append(a.lerp(b, float(j) / float(m)))
	return out


## Arc de cercle de rayon `r` (plan XZ) de l'angle `a0` à `a1`.
static func _arc(r: float, a0: float, a1: float, seg: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / float(seg))
		out.append(Vector3(cos(a), 0, sin(a)) * r)
	return out


## Chevron posé sur le cercle de rayon `r` à l'angle `a`, pointe dans le sens des angles croissants.
static func _chev(r: float, a: float, s: float) -> PackedVector3Array:
	var rad := Vector3(cos(a), 0, sin(a))
	var tg := Vector3(-sin(a), 0, cos(a))
	var p := rad * r
	var out := PackedVector3Array()
	out.append(p - tg * s * 0.45 + rad * s)
	out.append(p + tg * s * 0.55)
	out.append(p - tg * s * 0.45 - rad * s)
	return out


static func _part_flat(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := Toon.part(parent, mesh, material, pos, scl)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _label(parent: Node3D, txt: String, pos: Vector3, col: Color, size: int, px: float, billboard: bool, outline: int) -> Label3D:
	var l := Label3D.new()
	l.font = KANJI_FONT
	l.text = txt
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_modulate = Toon.WASHI
	l.outline_size = outline
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	parent.add_child(l)
	return l


## Lueur douce additive (dégradé radial des ombres de Toon), au sol ou face à la caméra.
static func _glow_mat(col: Color, billboard: bool) -> StandardMaterial3D:
	Toon.blob_mesh()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	m.albedo_texture = Toon._blob_tex
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m


## Pétales, poussière d'or ou étincelles qui montent doucement (une rafale, ou en continu si `burst` est faux :
## l'appelant arrête et libère alors les particules). `points` : points d'émission (sinon une sphère de rayon `r`).
static func _motes(parent: Node3D, pos: Vector3, col: Color, amount: int, life: float, up: float, r: float, burst := true, points := PackedVector3Array()) -> CPUParticles3D:
	if _grad == null:
		_grad = Gradient.new()
		_grad.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
		_grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var p := CPUParticles3D.new()
	p.mesh = _mesh("mote")
	p.material_override = _mat("mote")
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.one_shot = burst
	p.explosiveness = 0.35 if burst else 0.0
	p.local_coords = false
	if points.is_empty():
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = maxf(r, 0.01)
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		p.emission_points = points
	p.direction = Vector3(0, 1, 0)
	p.spread = 35.0
	p.initial_velocity_min = up * 0.5
	p.initial_velocity_max = up
	p.gravity = Vector3(0, 0.15, 0)
	p.damping_min = 0.3
	p.damping_max = 0.8
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.color = col
	p.color_ramp = _grad
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	if burst:
		var tw := p.create_tween()
		tw.tween_callback(p.queue_free).set_delay(life + 0.4)
	return p


## Maillages partagés entre toutes les énigmes.
static func _mesh(key: String) -> Mesh:
	if _meshes.has(key):
		var cached: Mesh = _meshes[key]
		return cached
	var m: Mesh = null
	match key:
		"disc":
			m = Toon.cyl(1.0, 1.0, 0.004, 32)
		"plinth0":
			m = Toon.box(Vector3(1.2, 0.16, 0.74))
		"plinth1":
			m = Toon.box(Vector3(0.92, 0.14, 0.56))
		"slab":
			m = Toon.box(Vector3(0.66, 1.25, 0.2))
		"slab_top":
			m = Toon.cyl(0.33, 0.33, 0.2, 20)
		"panel_rim":
			m = Toon.box(Vector3(0.46, 0.8, 0.02))
		"panel":
			m = Toon.box(Vector3(0.38, 0.72, 0.02))
		"moss":
			m = Toon.sphere(0.14)
		"rope":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.345
			tm.outer_radius = 0.4
			tm.rings = 24
			tm.ring_segments = 6
			m = tm
		"shide":
			m = Toon.box(Vector3(0.075, 0.085, 0.012))
		"bowl":
			m = Toon.cyl(0.15, 0.1, 0.09, 12)
		"candle":
			m = Toon.cyl(0.032, 0.036, 0.17, 8)
		"flame":
			m = Toon.sphere(0.045)
		"pebble":
			m = Toon.sphere(0.1)
		"beam":
			m = Toon.cyl(0.5, 0.34, 5.2, 16)
		"tr_base":
			m = Toon.cyl(0.24, 0.28, 0.1, 6)
		"tr_base2":
			m = Toon.cyl(0.17, 0.22, 0.06, 6)
		"tr_shaft":
			m = Toon.cyl(0.07, 0.085, 0.42, 8)
		"tr_mid":
			m = Toon.cyl(0.21, 0.13, 0.08, 6)
		"tr_paper":
			m = Toon.box(Vector3(0.25, 0.22, 0.25))
		"tr_post":
			m = Toon.box(Vector3(0.055, 0.26, 0.055))
		"tr_eave":
			m = Toon.cyl(0.33, 0.37, 0.05, 6)
		"tr_roof":
			m = Toon.cyl(0.05, 0.31, 0.14, 6)
		"tr_hoju":
			m = Toon.sphere(0.065)
		"tr_tip":
			m = Toon.cyl(0.0, 0.035, 0.07, 8)
		"lamp_halo":
			var q1 := QuadMesh.new()
			q1.size = Vector2(0.95, 0.95)
			m = q1
		"ema_post":
			m = Toon.cyl(0.03, 0.035, 0.72, 8)
		"ema_board":
			m = Toon.box(Vector3(1.08, 0.44, 0.035))
		"ema_cap":
			m = Toon.box(Vector3(1.16, 0.05, 0.08))
		"halo":
			var q2 := QuadMesh.new()
			q2.size = Vector2(1.3, 1.3)
			m = q2
		"sp_drop":
			m = Toon.sphere(0.21)
		"sp_tail":
			m = Toon.cyl(0.0, 0.18, 0.46, 12)
		"sp_core":
			m = Toon.sphere(0.1)
		"sp_wisp":
			m = Toon.sphere(0.085)
		"spirit_ring":
			m = ribbon_mesh([_arc(SPIRIT_RING_R, 0.0, TAU, 72)], 0.055, 0.0, 0.025)
		"spirit_arrows":
			m = ribbon_mesh([_chev(SPIRIT_RING_R, 0.0, 0.16), _chev(SPIRIT_RING_R, PI, 0.16)], 0.05, 0.0, 0.027)
		"icon_dark":
			m = ribbon_mesh([_arc(0.2, 0.6, TAU - 0.3, 28), _chev(0.2, TAU - 0.3, 0.09)], 0.05, 0.0, 0.0)
		"icon_light":
			m = ribbon_mesh([_arc(0.2, 0.6, TAU - 0.3, 28), _chev(0.2, TAU - 0.3, 0.09)], 0.024, 0.0, 0.0)
		"icon_dot":
			m = Toon.sphere(0.045)
		"mote":
			var q3 := QuadMesh.new()
			q3.size = Vector2(0.1, 0.1)
			m = q3
		_:
			m = Toon.box(Vector3(0.1, 0.1, 0.1))
	_meshes[key] = m
	return m


## Matières partagées entre toutes les énigmes (aucune n'est modifiée après coup).
static func _mat(key: String) -> Material:
	if _mats.has(key):
		var cached: Material = _mats[key]
		return cached
	var m: Material = null
	match key:
		"stone":
			m = Toon.mat(_wcol("stone", STONE), true, 0.03)
		"stone_dark":
			m = Toon.mat(_wcol("stone", STONE).darkened(0.2), true, 0.03)
		"stone_light":
			m = Toon.mat(_wcol("stone", STONE).lightened(0.14), false)
		"panel":
			m = Toon.mat(Color("#4E4A45"), false)
		"moss":
			m = Toon.mat(_wcol("moss", MOSS), true, 0.02)
		"rope":
			m = Toon.mat(Color("#D6C084"), true, 0.015)
		"paper":
			m = Toon.mat(Toon.PAPER, true, 0.01)
		"wax":
			m = Toon.mat(Color("#F2ECDF"), true, 0.012)
		"flame":
			m = Toon.flat(Color("#FFC85C", 0.95))
		"water":
			m = Toon.flat(Color("#36545E", 0.9))
		"inlay":
			m = Toon.flat(Color(_wcol("stone", STONE).darkened(0.05), 0.3))
		"pebble":
			m = Toon.mat(_wcol("pebble", Color("#9C978C")), true, 0.018)
		"ghost":
			var gh := ink_mat(Color(Toon.SUMI, 0.14))
			gh.set_shader_parameter(P_DRY, 0.3)
			m = gh
		"seal":
			var se := Toon.flat(Color(Toon.VERMILION, 0.92))
			se.render_priority = 2
			m = se
		"lantern":
			m = Toon.mat(_wcol("stone", Color("#9A958D")).lightened(0.08), true, 0.025)
		"roof":
			m = Toon.mat(Color("#5A5753"), true, 0.03)
		"wood":
			m = Toon.mat(Toon.WOOD, true, 0.02)
		"wood_dark":
			m = Toon.mat(Color("#6B4A2E"), true, 0.02)
		"spirit_core":
			var co := Toon.flat(Color(1, 1, 1, 0.95))
			co.render_priority = 1
			m = co
		"spirit_halo":
			var ha := _glow_mat(Color(SPIRIT, 0.55), true)
			ha.render_priority = -1
			m = ha
		"spirit_wisp":
			m = Toon.flat(Color(SPIRIT, 0.5))
		"spirit_wash":
			m = Toon.flat(Color(SPIRIT_INK, 0.07))
		"icon_dark":
			var idk := ink_mat(Color(Toon.SUMI, 0.85))
			idk.set_shader_parameter(P_DRY, 0.0)
			m = idk
		"icon_light":
			var il := ink_mat(Color("#E9FBFF"))
			il.set_shader_parameter(P_DRY, 0.0)
			il.render_priority = 1
			m = il
		"icon_dot":
			var dm := Toon.flat(Color(1, 1, 1, 1))
			dm.render_priority = 2
			m = dm
		"mote":
			var mm := StandardMaterial3D.new()
			mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mm.vertex_color_use_as_albedo = true
			mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			mm.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = mm
		_:
			m = Toon.flat(Color(1, 0, 1, 1))
	_mats[key] = m
	return m
