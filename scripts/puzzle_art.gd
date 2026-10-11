extends RefCounted
const SHOW_EMA := false
## Décor des énigmes des recoins (appelé par main.gd : _puzzle_node, _update_puzzle, _solve_puzzle, _puzzle_fail).
## Stèle de pierre (sekihi) et sa figure peinte, fixe, dans un cercle de pierres,
## lanternes de pierre (tōrō) numérotées à relier dans l'ordre, esprit errant (hitodama) à entourer.
## Maillages et matières partagés entre recoins ; seules les matières animées (encre de la figure, papier
## et lueur des lanternes, flamme et cercle de l'esprit) sont propres à chaque énigme.
## Rien n'est alloué image par image : update() ne fait que déplacer des nœuds et régler des valeurs.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const KANJI_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const INK_SHADER := "res://shaders/puzzle_ink.gdshader"

## Centre de la figure peinte au sol, devant la stèle (côté caméra) ; la stèle recule d'autant. Figure large
## d'environ 1,8 m sur un cercle de sable clair : lisible de la caméra de jeu, même sur les sols sombres (mondes 2, 4, 8).
const GLYPH_O := Vector3(0, 0, 1.5)
const GLYPH_K := 0.92
const STELE_Z := -0.45
const INLAY_R := 1.55
## (Numéros des lanternes : chiffres arabes sur le papier du foyer, plus de kanji en combat, UI v2.)
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

## Stèle (sekihi) sur socle à degrés, mousse, shimenawa et shide, cartouche où la figure `shape` est gravée
## (son tracé en ruban d'encre, plus de kanji : UI v2), bol d'offrande et deux bougies ; devant, la figure
## `pts` peinte dans un cercle de pierres.
static func build_stele(n: Node3D, pk: Dictionary, pts: PackedVector3Array, shape: String) -> void:
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
	# la figure gravée dans le cartouche : le même tracé que la figure au sol, ramené au gabarit du panneau
	# (0,38 × 0,72), relevé à la verticale (XZ -> XY) ; sa matière plate luit (mise à jour) et dore (résolue)
	var ek := "eng_" + shape
	if not _meshes.has(ek):
		# ruban à l'échelle de la figure au sol (le rééchantillonnage reste fin), réduit au cartouche par le nœud
		var loc := PackedVector3Array()
		for p in pts:
			var q := p - GLYPH_O
			loc.append(Vector3(q.x, 0, q.z))
		_meshes[ek] = ribbon_mesh([loc], 0.16, 0.6, 0.0)
	var emat := Toon.flat(Color(ENGRAVE, 0.7))
	var eng := Toon.part(slab, _meshes[ek], emat, Vector3(0, 0.68, 0.126), Vector3.ONE * (0.15 / GLYPH_K))
	eng.rotation.x = PI / 2.0
	eng.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pk["label"] = emat
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
		_meshes[key] = ribbon_mesh([pts], 0.13, 1.0, 0.03)
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
		# la figure de la stèle reste peinte, fixe (plus de tracé en boucle) ; seul le raté la rougit un instant
		var age := t - float(pk["cyc0"])
		if age < 0.0:
			_ink_cycle(gmv, age, DRAW_PERIOD, 0.55, INK_COL)
		else:
			gmv.set_shader_parameter(P_INK, INK_COL)
			gmv.set_shader_parameter(P_REVEAL, 1.0)
			gmv.set_shader_parameter(P_FADE, 1.0)
	var lb = pk.get("label")
	if lb is StandardMaterial3D:
		var em: StandardMaterial3D = lb
		em.albedo_color = Color(ENGRAVE, 0.5 + 0.3 * (0.5 + 0.5 * sin(t * 2.2)))
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
	if lb is StandardMaterial3D:
		var em: StandardMaterial3D = lb
		var tl := root.create_tween()
		tl.tween_property(em, "albedo_color", Color(1.0, 0.85, 0.42, 1.0), 0.35)
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
		_label(ln, str(i + 1), Vector3(0, 0.79, 0.127), Color(Toon.SUMI, 0.85), 96, 0.0019, false, 0)
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


# ------------------------------------------------------------------ coffre scellé (main._spawn_sealed_chest)

## Coffre scellé : le karabitsu de main._pocket_node (W 1,15, D 0,78, joint du couvercle à 0,78 m) ligoté de deux
## chaînes d'encre en croix sur la façade, d'une bande d'ofuda passée par-dessus le couvercle et d'un sceau hanko
## vermillon au croisement ; à côté, sur deux piquets, une plaque (ema) inclinée face à la caméra où la figure à
## tracer se peint en boucle au pinceau fantôme (point de départ vermillon). Pas de texte (UI v2).
const SEAL_PERIOD := 3.0  # la figure se peint (55 %), reste, s'efface : un cycle (s)
const SEAL_Y := 0.78  # joint du couvercle
const SEAL_AT := Vector3(0, 1.19, 0.04)  # sceau, au croisement des chaînes sur le couvercle
const SEAL_HALF := 0.085  # demi-largeur du sceau (deux moitiés)
const EMA_TILT := -0.82  # plaque renversée vers la caméra (élévation 54°) : presque de face, encore posée
const EMA_H := 1.4  # hauteur du centre de la plaque
const EMA_SIZE := Vector2(1.9, 1.5)  # planche ; le papier est 0,16 plus étroit (lisible de la caméra de jeu)
const EMA_GLYPH := 0.62  # demi-taille de la figure peinte (gabarit ±1 de glyph_path), en m
const UNSEAL_T := 0.62  # du trait juste au couvercle qui saute (main._open_chest) (s)
const SEAL_INK := Color(0.106, 0.102, 0.118, 0.95)


## Figure d'une plaque, d'un seul trait dans l'ordre du geste : les glyphes des figures de l'interface
## (UiKit._fsym : spirale, éclair, trait montant, arche, ensō, crochet), au gabarit ±1 du canevas (x à droite,
## y vers le bas), posés dans le plan XZ (z = y du canevas) pour ribbon_mesh.
static func glyph_path(shape: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	match shape:
		"loop":
			# spirale de 1,75 tour qui s'ouvre depuis le centre
			for i in 40:
				var t := float(i) / 39.0
				var v := Vector2.from_angle(t * TAU * 1.75) * 0.85 * (0.15 + 0.85 * t)
				out.append(Vector3(v.x, 0, v.y))
		"zigzag":
			# Z à deux coins (éclair)
			for v: Vector2 in [Vector2(-0.6, -0.9), Vector2(0.25, -0.15), Vector2(-0.25, 0.1), Vector2(0.6, 0.9)]:
				out.append(Vector3(v.x, 0, v.y))
		"straight":
			out.append(Vector3(-0.95, 0, 0.55))
			out.append(Vector3(0.95, 0, -0.55))
		"return":
			# arche : on monte à gauche, on tourne, on redescend à droite (sans pointe de flèche)
			out.append(Vector3(-0.55, 0, 0.8))
			for i in 29:
				var a := PI + PI * float(i) / 28.0
				out.append(Vector3(cos(a) * 0.55, 0, -0.1 + sin(a) * 0.55))
			out.append(Vector3(0.55, 0, 0.55))
		"enso":
			for i in 49:
				var a2 := -PI * 0.35 + PI * 1.8 * float(i) / 48.0
				out.append(Vector3(cos(a2), 0, sin(a2)) * 0.8)
		"hook":
			# J : descente puis demi-tour en bas (sans pointe de flèche)
			out.append(Vector3(0.35, 0, -0.9))
			out.append(Vector3(0.35, 0, 0.3))
			for i in range(1, 29):
				var a3 := PI * float(i) / 28.0
				out.append(Vector3(cos(a3) * 0.35, 0, 0.3 + sin(a3) * 0.35))
	return out


## Pose le lien et la plaque sur le coffre `n` (nœud de main._pocket_node("chest")) ; `side` : côté (±1 en x)
## où se dresse la plaque. Les nœuds animés et les matières propres à ce coffre vont dans `pk`.
static func build_seal(n: Node3D, pk: Dictionary, shape: String, side: float) -> void:
	var glow := n.get_node_or_null("Glow") as Node3D
	if glow != null:
		glow.visible = false  # l'or ne respire qu'une fois le sceau brisé
	# lavis d'encre au sol, et l'éclat d'or du déverrouillage par-dessus (jamais de vermillon au sol : c'est la
	# couleur des annonces d'attaque, design/PALETTES.md)
	_part_flat(n, _mesh("disc"), _mat("seal_wash"), Vector3(0, 0.016, 0), Vector3(1.05, 1, 1.05))
	var fm := Toon.flat(Color(Toon.GOLD, 0.0))
	_part_flat(n, _mesh("disc"), fm, Vector3(0, 0.02, 0), Vector3(1.3, 1, 1.3))
	pk["fmat"] = fm
	var bind := Node3D.new()
	bind.name = "Bind"
	n.add_child(bind)
	pk["bind"] = bind
	# deux chaînes d'encre : du pied de la façade, par-dessus le couvercle en diagonale, jusqu'à l'angle arrière
	# opposé ; elles se croisent sous le sceau, au milieu du couvercle (la caméra haute voit surtout le dessus).
	# Maillons alternés à plat / de chant contre la face qu'ils longent.
	var links: Array = []
	var lm := _mat("chain")
	var lmesh := _mesh("chain_link")
	var step := 0.12 if Toon.lite else 0.1
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		var path := [Vector3(0.4 * x, 0.2, 0.452), Vector3(0.4 * x, 0.93, 0.452), Vector3(0.4 * x, 1.072, 0.3), Vector3(-0.46 * x, 1.072, -0.3), Vector3(-0.5 * x, 0.94, -0.45)]
		var nrm := [Vector3(0, 0, 1), Vector3(0, 0.7, 0.7), Vector3(0, 1, 0), Vector3(0, 0.7, -0.7)]
		var j := 0
		for si in path.size() - 1:
			var a: Vector3 = path[si]
			var b: Vector3 = path[si + 1]
			var dir := (b - a).normalized()
			var cnt := maxi(1, roundi(a.distance_to(b) / step))
			for i in range(0 if si == 0 else 1, cnt + 1):
				var p := a.lerp(b, float(i) / float(cnt))
				j += 1
				if Vector2(p.x, p.z).length() < 0.17 and p.y > 1.0:
					continue  # caché sous le sceau
				var nv: Vector3 = nrm[si]
				var by := nv if j % 2 == 0 else dir.cross(nv).normalized()
				var li := _part_flat(bind, lmesh, lm, p + nv * (0.012 if j % 2 == 0 else 0.0))
				li.transform.basis = Basis(dir * 1.5, by, dir.cross(by))
				links.append(li)
	pk["links"] = links
	# ofuda : bande de papier de l'arrière du couvercle jusqu'au bas de la façade, déchirée au joint (deux nœuds)
	var paper := _mat("ofuda")
	var top := Node3D.new()
	bind.add_child(top)
	top.position = Vector3(0, SEAL_Y, 0)
	_part_flat(top, _mesh("ofuda_front"), paper, Vector3(0, 0.073, 0.437))
	_part_flat(top, _mesh("ofuda_step"), paper, Vector3(0, 0.147, 0.365))
	_part_flat(top, _mesh("ofuda_riser"), paper, Vector3(0, 0.205, 0.293))
	_part_flat(top, _mesh("ofuda_top"), paper, Vector3(0, 0.267, 0.0))
	var bot := Node3D.new()
	bind.add_child(bot)
	bot.position = Vector3(0, SEAL_Y, 0)
	_part_flat(bot, _mesh("ofuda_low"), paper, Vector3(0, -0.19, 0.405))
	# un coup de pinceau sumi le long du papier (motif de talisman, pas d'écriture)
	_part_flat(bot, _mesh("ofuda_mark"), _mat("seal_ink"), Vector3(0, -0.2, 0.41))
	_part_flat(top, _mesh("ofuda_mark"), _mat("seal_ink"), Vector3(0, 0.272, -0.1), Vector3(1, 1, 1)).rotation.x = PI / 2.0
	pk["ofuda"] = [top, bot]
	# sceau hanko au croisement des chaînes, dressé face à la caméra : bloc vermillon en deux moitiés (il se
	# fend au déverrouillage) cerné d'un cadre de papier
	var seal := Node3D.new()
	bind.add_child(seal)
	seal.position = SEAL_AT
	seal.rotation.x = -0.9
	pk["seal"] = seal
	var halves: Array = []
	for sx in [-1.0, 1.0]:
		var h := Node3D.new()
		seal.add_child(h)
		h.position = Vector3(float(sx) * SEAL_HALF, 0, 0)
		Toon.part(h, _mesh("seal_half"), _mat("seal_block"), Vector3.ZERO)
		var mk := _mat("seal_mark")
		_part_flat(h, _mesh("seal_bar_h"), mk, Vector3(float(sx) * -0.005, 0.14, 0.032))
		_part_flat(h, _mesh("seal_bar_h"), mk, Vector3(float(sx) * -0.005, -0.14, 0.032))
		_part_flat(h, _mesh("seal_bar_v"), mk, Vector3(float(sx) * 0.055, 0, 0.032))
		halves.append(h)
	pk["halves"] = halves
	var crack := _part_flat(seal, _mesh("seal_crack"), _mat("seal_mark"), Vector3(0, 0, 0.034))
	crack.visible = false
	pk["crack"] = crack
	# plaque (ema) sur deux piquets, à côté du coffre, renversée vers la caméra
	var ema := Node3D.new()
	ema.name = "Ema"
	n.add_child(ema)
	ema.position = Vector3(side * 1.75, 0, -0.4)
	ema.rotation.y = -side * 0.12
	pk["ema"] = ema
	Toon.blob(ema, 1.0, 0.28)
	for sx in [-1.0, 1.0]:
		Toon.part(ema, _mesh("ema_stake"), _mat("wood_dark"), Vector3(float(sx) * 0.72, 0.65, -0.14))
	var board := Node3D.new()
	ema.add_child(board)
	board.position = Vector3(0, EMA_H, 0)
	board.rotation.x = EMA_TILT
	Toon.part(board, _mesh("ema_plank"), _mat("wood"), Vector3.ZERO)
	Toon.part(board, _mesh("ema_roof"), _mat("wood_dark"), Vector3(0, EMA_SIZE.y * 0.5 + 0.03, 0.01))
	_part_flat(board, _mesh("ema_paper"), _mat("ema_paper"), Vector3(0, -0.02, 0.031))
	# cordon de paille noué au faîte, deux shide aux angles
	Toon.part(board, _mesh("ema_knot"), _mat("rope"), Vector3(0, EMA_SIZE.y * 0.5 - 0.02, 0.05))
	for sx in [-1.0, 1.0]:
		var sd := _part_flat(board, _mesh("shide"), _mat("paper"), Vector3(float(sx) * (EMA_SIZE.x * 0.5 + 0.02), EMA_SIZE.y * 0.5 - 0.12, 0.05), Vector3(1.4, 1.6, 1.0))
		sd.rotation.z = float(sx) * 0.25
	# la figure : fantôme entier, trait qui se peint par-dessus, sceau vermillon au départ
	var gl := Node3D.new()
	board.add_child(gl)
	gl.position = Vector3(0, -0.02, 0.04)
	gl.rotation.x = PI / 2.0  # plan XZ du ruban -> plan de la plaque (z du canevas vers le bas)
	var key := "ema_" + shape
	if not _meshes.has(key):
		var src := glyph_path(shape)
		var pts := PackedVector3Array()
		for p in src:
			pts.append(p * EMA_GLYPH)
		_meshes[key] = ribbon_mesh([pts], 0.078, 0.5, 0.0)
	var fig: Mesh = _meshes[key]
	_part_flat(gl, fig, _mat("ema_ghost"), Vector3.ZERO)
	var gm := ink_mat(SEAL_INK, 0.0, Color(Toon.VERMILION, 1.0))
	gm.render_priority = 1
	_part_flat(gl, fig, gm, Vector3(0, 0.004, 0))
	pk["gmat"] = gm
	pk["cyc0"] = -randf() * SEAL_PERIOD
	var start := glyph_path(shape)
	if not start.is_empty():
		_part_flat(gl, _mesh("disc"), _mat("seal"), start[0] * EMA_GLYPH + Vector3(0, 0.008, 0), Vector3(0.075, 1, 0.075))


## Trait au pinceau fantôme (stèle, plaque) : se peint en `draw` du cycle, reste, s'efface sur le dernier
## cinquième ; avant cyc0 (raté), la figure entière en vermillon.
static func _ink_cycle(gm: ShaderMaterial, age: float, period: float, draw: float, ink: Color) -> void:
	if age < 0.0:
		gm.set_shader_parameter(P_INK, Color(Toon.VERMILION, 0.9))
		gm.set_shader_parameter(P_REVEAL, 1.0)
		gm.set_shader_parameter(P_FADE, 1.0)
		return
	var u := fmod(age, period) / period
	var rv := 1.0
	var fd := 1.0
	if u < draw:
		var e := u / draw
		rv = -0.02 + 1.02 * (1.0 - (1.0 - e) * (1.0 - e))
	elif u > 0.8:
		fd = 1.0 - (u - 0.8) / 0.2
	gm.set_shader_parameter(P_INK, ink)
	gm.set_shader_parameter(P_REVEAL, rv)
	gm.set_shader_parameter(P_FADE, fd)


static func _update_seal(pk: Dictionary, t: float, fk: float) -> void:
	var gmv = pk.get("gmat")
	if gmv is ShaderMaterial:
		_ink_cycle(gmv, t - float(pk["cyc0"]), SEAL_PERIOD, 0.5, SEAL_INK)
	# raté : le lien tremble, le sceau gonfle (la figure de la plaque rougit, _ink_cycle) ; sinon le sceau respire à peine
	var bv = pk.get("bind")
	if is_instance_valid(bv):
		var bind: Node3D = bv
		bind.position = Vector3(sin(t * 55.0) * 0.04 * fk, 0, 0)
	var sv = pk.get("seal")
	if is_instance_valid(sv):
		var seal: Node3D = sv
		seal.scale = Vector3.ONE * (1.0 + 0.3 * fk + 0.04 * sin(t * 2.6))


## Déverrouillage (main._unseal_chest) : la figure de la plaque se dore ; le sceau se fend, ses moitiés tombent ;
## la chaîne se dissout en gouttes d'encre qui tachent le sol ; l'ofuda se déchire et s'envole. Le couvercle
## saute ensuite (main._open_chest, après UNSEAL_T).
static func unseal(pk: Dictionary, root: Node3D) -> void:
	var gmv = pk.get("gmat")
	if gmv is ShaderMaterial:
		var gm: ShaderMaterial = gmv
		gm.set_shader_parameter(P_INK, Color(Toon.GOLD.lightened(0.1), 1.0))
		gm.set_shader_parameter(P_HEAD, Color(0, 0, 0, 0))
		gm.set_shader_parameter(P_REVEAL, 1.0)
		gm.set_shader_parameter(P_FADE, 1.0)
	var fmv = pk.get("fmat")
	if fmv is StandardMaterial3D:
		var fm: StandardMaterial3D = fmv
		fm.albedo_color = Color(Toon.GOLD, 0.0)
		var tf := root.create_tween()
		tf.tween_property(fm, "albedo_color:a", 0.45, 0.12)
		tf.tween_property(fm, "albedo_color:a", 0.0, 0.7)
	var bv = pk.get("bind")
	if is_instance_valid(bv):
		var bind0: Node3D = bv
		bind0.position = Vector3.ZERO
	# sceau : il gonfle, la fente blanche apparaît, les deux moitiés tombent en tournoyant puis fondent
	var sv = pk.get("seal")
	if is_instance_valid(sv):
		var seal: Node3D = sv
		seal.scale = Vector3.ONE
		var ts := seal.create_tween()
		ts.tween_property(seal, "scale", Vector3.ONE * 1.35, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var cv = pk.get("crack")
		if is_instance_valid(cv):
			ts.tween_callback((cv as Node3D).show)
		ts.tween_interval(0.07)
		var halves: Array = pk.get("halves", [])
		for i in halves.size():
			var hv = halves[i]
			if not is_instance_valid(hv):
				continue
			var h: Node3D = hv
			var sg := -1.0 if i == 0 else 1.0
			var drop := func() -> void:
				# hors du sceau (incliné) : la moitié tombe droit au sol, devant le coffre, en tournoyant
				h.reparent(root)
				var th := h.create_tween()
				th.set_parallel(true)
				th.tween_property(h, "position", h.position + Vector3(sg * 0.2, 0.12, 0.12), 0.1).set_ease(Tween.EASE_OUT)
				th.chain().tween_property(h, "position", Vector3(sg * 0.5, 0.05, 0.85), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				th.tween_property(h, "rotation", Vector3(-PI / 2.0, sg * 0.5, sg * 1.7), 0.42)
				th.chain().tween_property(h, "scale", Vector3.ZERO, 0.35).set_delay(0.5)
				th.chain().tween_callback(h.queue_free)
			ts.tween_callback(drop)
		if is_instance_valid(cv):
			ts.tween_callback((cv as Node3D).hide).set_delay(0.12)
	# chaîne : chaque maillon fond (du sceau vers les bouts), gouttes d'encre qui tombent et tachent le sol
	var links: Array = pk.get("links", [])
	var drops := PackedVector3Array()
	for lv in links:
		if not is_instance_valid(lv):
			continue
		var li: Node3D = lv
		var dc := li.position.distance_to(SEAL_AT)
		var tl := li.create_tween()
		tl.tween_property(li, "scale", Vector3(0.2, 0.2, 0.2), 0.16).set_delay(0.1 + dc * 0.45).set_ease(Tween.EASE_IN)
		tl.tween_callback(li.queue_free)
		if drops.size() < 24:
			drops.append(li.position)
	if not drops.is_empty():
		_drops(root, drops, Toon.SUMI, 14 if Toon.lite else 30)
	var bm := Toon.flat(Color(Toon.SUMI, 0.72))
	for k in (3 if Toon.lite else 5):
		var bp := Vector3(randf_range(-0.6, 0.6), 0.022 + 0.001 * float(k), randf_range(0.5, 0.85))
		var blot := _part_flat(root, _mesh("disc"), bm, bp, Vector3(0.01, 1, 0.01))
		var r := randf_range(0.07, 0.14)
		var tb := blot.create_tween()
		tb.tween_property(blot, "scale", Vector3(r, 1, r * randf_range(0.7, 1.0)), 0.18).set_delay(0.35 + 0.08 * float(k)).set_ease(Tween.EASE_OUT)
		tb.tween_interval(1.4)
		tb.tween_property(blot, "scale", Vector3(0.001, 1, 0.001), 0.5)
		tb.tween_callback(blot.queue_free)
	# ofuda : déchiré au joint, les deux morceaux s'envolent en tournoyant et rapetissent
	var ofs: Array = pk.get("ofuda", [])
	for i in ofs.size():
		var ov = ofs[i]
		if not is_instance_valid(ov):
			continue
		var o: Node3D = ov
		var p0 := o.position
		var up := 1.0 if i == 0 else 0.0
		var dest := p0 + Vector3(0.55 if i == 0 else -0.6, 1.5 + 0.5 * up, 0.25 - 0.5 * up)
		var spin := Vector3(1.2 + up, 2.4 - 4.5 * (1.0 - up), 1.6 if i == 0 else -1.9)
		var fly := func(k: float) -> void:
			var q := p0.lerp(dest, k)
			q.x += sin(k * 9.0) * 0.12 * k
			o.position = q
			o.rotation = spin * k
			o.scale = Vector3.ONE * clampf(1.4 - 1.4 * k, 0.0, 1.0)
		var to := o.create_tween()
		to.tween_interval(0.26 + 0.06 * float(i))
		to.tween_method(fly, 0.0, 1.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		to.tween_callback(o.queue_free)
	_motes(root, SEAL_AT, Toon.GOLD.lightened(0.3), 6 if Toon.lite else 14, 1.2, 1.4, 0.3)


## Gouttes d'encre qui tombent (déverrouillage du coffre scellé) depuis `points` (locaux à `parent`).
static func _drops(parent: Node3D, points: PackedVector3Array, col: Color, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _mesh("ink_drop")
	p.material_override = _mat("ink_drop")
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(1, amount)
	p.lifetime = 0.75
	p.one_shot = true
	p.explosiveness = 0.55
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = points
	p.direction = Vector3(0, 1, 0.6)
	p.spread = 60.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = col
	parent.add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_callback(p.queue_free).set_delay(1.2)
	return p


## Préchauffage (main._warmup) : les gouttes du déverrouillage (les autres matières viennent de build_seal).
static func warm_seal(parent: Node3D) -> void:
	var p := _drops(parent, PackedVector3Array([Vector3.ZERO]), Toon.SUMI, 1)
	p.one_shot = false


# ------------------------------------------------------------------ autel du sanctuaire (main._spawn_shrine)

const ALTAR_RING_R := 1.3  # anneau d'approche au sol (= rayon de déclenchement, main._stage_roam)
const ALTAR_SCALE := 1.3  # l'autel lui-même est agrandi (lisible de la caméra haute) ; l'anneau garde son rayon

## Autel du sanctuaire posé sur l'étape après les combats de main.SANCTUARIES : socle de pierre à deux degrés cerné
## d'encre, table, torii miniature laqué de vermillon avec sa shimenawa et trois shide, ofuda scellé pendu au nuki,
## bol d'encre qui luit, deux tōrō allumés de part et d'autre, mousse ; au sol, un anneau d'or discret marque la
## zone d'approche. Pierre et mousse à la palette du monde (WORLD_STONE). ≈ 1 000 triangles, aucune animation.
static func build_altar(n: Node3D, world_id: int) -> void:
	set_world(world_id)
	var stone := _mat("stone")
	var dark := _mat("stone_dark")
	var moss := _mat("moss")
	var red := _mat("altar_red")
	var sumi := _mat("altar_sumi")
	var paper := _mat("paper")
	var rope := _mat("rope")
	# ombre, socle cerné d'encre, anneau d'approche (sur la racine, à l'échelle du monde)
	Toon.blob(n, 1.05 * ALTAR_SCALE, 0.32)
	_part_flat(n, _mesh("disc"), _mat("altar_ink"), Vector3(0, 0.014, 0), Vector3(0.82 * ALTAR_SCALE, 1, 0.82 * ALTAR_SCALE))
	_part_flat(n, _mesh("altar_ring"), _mat("altar_gold"), Vector3(0, 0.016, 0))
	# tout l'autel sous un nœud agrandi
	var root := n
	n = Node3D.new()
	n.name = "Autel"
	root.add_child(n)
	n.scale = Vector3.ONE * ALTAR_SCALE
	Toon.part(n, _mesh("plinth0"), dark, Vector3(0, 0.08, 0))
	Toon.part(n, _mesh("plinth1"), stone, Vector3(0, 0.23, 0))
	Toon.part(n, _mesh("altar_table"), stone, Vector3(0, 0.41, 0))
	Toon.part(n, _mesh("moss"), moss, Vector3(0.44, 0.17, 0.3), Vector3(1.3, 0.35, 0.9))
	Toon.part(n, _mesh("moss"), moss, Vector3(-0.38, 0.31, -0.2), Vector3(1.1, 0.3, 0.8))
	# torii miniature au fond de la table : deux piliers, nuki, shimaki vermillon, kasagi sumi aux bouts relevés
	var tz := -0.1
	for sx in [-1.0, 1.0]:
		Toon.part(n, _mesh("altar_pillar"), red, Vector3(float(sx) * 0.24, 0.87, tz))
		Toon.part(n, _mesh("altar_kusabi"), red, Vector3(float(sx) * 0.27, 1.0, tz))
	Toon.part(n, _mesh("altar_nuki"), red, Vector3(0, 1.0, tz))
	Toon.part(n, _mesh("altar_gaku"), sumi, Vector3(0, 1.1, tz + 0.02))
	Toon.part(n, _mesh("altar_shimaki"), red, Vector3(0, 1.16, tz))
	Toon.part(n, _mesh("altar_kasagi"), sumi, Vector3(0, 1.22, tz))
	for sx in [-1.0, 1.0]:
		var tip := Toon.part(n, _mesh("altar_kasagi_tip"), sumi, Vector3(float(sx) * 0.4, 1.235, tz))
		tip.rotation.z = -float(sx) * 0.22
	# shimenawa entre les piliers (sous le nuki) et ses shide
	var rp := Toon.part(n, _mesh("altar_rope"), rope, Vector3(0, 0.94, tz + 0.02))
	rp.rotation.z = PI / 2.0
	for k in 3:
		var sd := Toon.part(n, _mesh("altar_shide"), paper, Vector3(-0.15 + 0.15 * float(k), 0.875, tz + 0.03))
		sd.rotation.z = 0.2 if k == 1 else -0.12
		sd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ofuda pendu au nuki, sceau vermillon en tête
	Toon.part(n, _mesh("altar_ofuda"), paper, Vector3(0, 0.78, tz + 0.05))
	_part_flat(n, _mesh("altar_seal"), _mat("seal"), Vector3(0, 0.86, tz + 0.056))
	# bol d'encre sur le devant de la table, sa lueur
	Toon.part(n, _mesh("bowl"), stone, Vector3(0, 0.565, 0.1))
	_part_flat(n, _mesh("disc"), _mat("altar_ink"), Vector3(0, 0.612, 0.1), Vector3(0.12, 1, 0.12))
	_part_flat(n, _mesh("halo"), _mat("altar_glow"), Vector3(0, 0.72, 0.1), Vector3(0.6, 0.6, 0.6))
	# deux tōrō (mêmes pièces que l'énigme des lanternes, à 0,55), allumés, sur les degrés du socle
	var lamp := _mat("altar_lamp")
	var roof := _mat("roof")
	for sx in [-1.0, 1.0]:
		var ln := Node3D.new()
		n.add_child(ln)
		ln.position = Vector3(float(sx) * 0.72, 0.0, 0.12)
		ln.scale = Vector3.ONE * 0.55
		Toon.part(ln, _mesh("tr_base"), stone, Vector3(0, 0.05, 0))
		Toon.part(ln, _mesh("tr_base2"), stone, Vector3(0, 0.13, 0))
		Toon.part(ln, _mesh("tr_shaft"), stone, Vector3(0, 0.37, 0))
		Toon.part(ln, _mesh("tr_mid"), stone, Vector3(0, 0.62, 0))
		Toon.part(ln, _mesh("tr_paper"), lamp, Vector3(0, 0.79, 0))
		for px in [-1.0, 1.0]:
			for pz in [-1.0, 1.0]:
				Toon.part(ln, _mesh("tr_post"), stone, Vector3(float(px) * 0.12, 0.79, float(pz) * 0.12))
		Toon.part(ln, _mesh("tr_eave"), roof, Vector3(0, 0.945, 0))
		Toon.part(ln, _mesh("tr_roof"), roof, Vector3(0, 1.03, 0))
		Toon.part(ln, _mesh("tr_hoju"), stone, Vector3(0, 1.13, 0), Vector3(1, 1.25, 1))
		Toon.part(ln, _mesh("tr_tip"), stone, Vector3(0, 1.22, 0))
		_part_flat(ln, _mesh("lamp_halo"), _mat("altar_lamp_halo"), Vector3(0, 0.8, 0))


# ------------------------------------------------------------------ étal du marchand (main._spawn_merchant)

const YATAI_RING_R := 1.75  # anneau d'approche au sol (= rayon où l'échoppe s'ouvre, main._update_pockets)
const YATAI_SCALE := 1.25  # charrette agrandie (lisible de la caméra haute) ; l'anneau garde son rayon
const TANUKI_BROWN := Color("#8A6646")
const TANUKI_DARK := Color("#3B2E27")
const TANUKI_CREAM := Color("#EAD9B4")
const STRAW := Color("#D9B76C")
const NOREN := Color("#2B4A6E")

## Étal (yatai) du marchand tanuki, posé dans un recoin de l'étape qui précède le gardien : charrette de bois à deux
## roues, comptoir cerclé d'un bandeau vermillon, auvent d'encre sur deux montants (relevé vers le chemin : la
## caméra haute voit le comptoir), noren indigo à trois pans (mon d'or au milieu), chōchin vermillon allumé à l'angle,
## nobori d'or plantée derrière ; sur le comptoir, jarres, pile de koban, rouleau et omamori. Devant, le tanuki
## (chapeau de paille repoussé sur la nuque, feuille dessus), ventre clair, masque sombre, un koban à la patte. Au
## sol, comme l'autel, un anneau d'or marque la zone d'approche. Nœuds animés par main._update_merchant : « Tanuki »
## (il respire), « Tanuki/Arm » (il agite son koban) et « Yatai/Lantern » (balancement). ≈ 1 500 triangles.
static func build_yatai(n: Node3D) -> void:
	var wood := Toon.mat_shared(Color("#9C7346"), true, 0.02)
	var wood_dark := Toon.mat_shared(Color("#5E4029"), true, 0.02)
	var wood_light := Toon.mat_shared(Color("#A87B4C"), true, 0.02)
	var sumi := Toon.mat_shared(Color("#2A2428"), true, 0.02)
	var red := Toon.mat_shared(Toon.VERMILION, true, 0.02)
	var gold := Toon.mat_shared(Color("#E0B04E"), true, 0.015)
	var cloth := Toon.mat_shared(NOREN, true, 0.012)
	var paper := Toon.mat_shared(Toon.PAPER, true, 0.012)
	# ombre douce, lavis d'or et anneau d'approche
	Toon.blob(n, 1.7, 0.3)
	_part_flat(n, _mesh("disc"), _mat("yatai_wash"), Vector3(0, 0.014, 0), Vector3(YATAI_RING_R, 1, YATAI_RING_R))
	_part_flat(n, _mesh("yatai_ring"), _mat("yatai_gold"), Vector3(0, 0.018, 0))
	var cart := Node3D.new()
	cart.name = "Yatai"
	n.add_child(cart)
	cart.position = Vector3(0.18, 0, -0.25)
	cart.scale = Vector3.ONE * YATAI_SCALE
	# deux grandes roues de bois cerclées d'encre, moyeu d'or
	for sx in [-1.0, 1.0]:
		var wh := Toon.part(cart, Toon.cyl(0.33, 0.33, 0.08, 16), wood_dark, Vector3(float(sx) * 0.8, 0.33, 0.02))
		wh.rotation.z = PI / 2.0
		var hub := Toon.part(cart, Toon.cyl(0.08, 0.08, 0.1, 10), gold, Vector3(float(sx) * 0.82, 0.33, 0.02))
		hub.rotation.z = PI / 2.0
	# caisse, bandeau vermillon en façade, plateau du comptoir
	Toon.part(cart, Toon.box(Vector3(1.5, 0.5, 0.7)), wood, Vector3(0, 0.48, 0))
	Toon.part(cart, Toon.box(Vector3(1.52, 0.09, 0.02)), red, Vector3(0, 0.62, 0.36))
	Toon.part(cart, Toon.box(Vector3(1.66, 0.06, 0.82)), wood_light, Vector3(0, 0.76, 0.02))
	# deux montants à l'arrière, auvent d'encre relevé vers le chemin (le comptoir reste visible de la caméra
	# haute), faîtage vermillon au fond
	for sx in [-1.0, 1.0]:
		Toon.part(cart, Toon.cyl(0.035, 0.04, 1.16, 6), wood_dark, Vector3(float(sx) * 0.74, 1.34, -0.34))
	var roof := Toon.part(cart, Toon.box(Vector3(1.9, 0.07, 0.7)), sumi, Vector3(0, 1.92, -0.2))
	roof.rotation.x = -0.22
	var ridge := Toon.part(cart, Toon.box(Vector3(1.96, 0.09, 0.12)), red, Vector3(0, 1.86, -0.54))
	ridge.rotation.x = -0.22
	# noren : trois pans indigo sous le bord de l'auvent, mon d'or sur le pan du milieu
	for k in 3:
		var pan := Toon.part(cart, Toon.box(Vector3(0.46, 0.3, 0.015)), cloth, Vector3(-0.49 + 0.49 * float(k), 1.84, 0.15))
		pan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mon := Toon.part(cart, Toon.cyl(0.08, 0.08, 0.01, 18), gold, Vector3(0, 1.84, 0.16))
	mon.rotation.x = PI / 2.0
	# sur le comptoir : jarres de saké, pile de koban, rouleau au cordon vermillon, omamori
	for k in 2:
		Toon.part(cart, Toon.cyl(0.07, 0.09, 0.2, 10), paper, Vector3(-0.58 + 0.17 * float(k), 0.89, -0.12))
		Toon.part(cart, Toon.cyl(0.035, 0.035, 0.05, 8), red, Vector3(-0.58 + 0.17 * float(k), 1.01, -0.12))
	for k in 3:
		Toon.part(cart, Toon.cyl(0.075, 0.075, 0.03, 14), gold, Vector3(-0.12 + 0.04 * float(k % 2), 0.81 + 0.035 * float(k), 0.12), Vector3(1.25, 1, 1))
	var scroll := Toon.part(cart, Toon.cyl(0.05, 0.05, 0.36, 10), paper, Vector3(0.3, 0.84, 0.06))
	scroll.rotation.z = PI / 2.0
	Toon.part(cart, Toon.box(Vector3(0.03, 0.105, 0.105)), red, Vector3(0.3, 0.84, 0.06))
	var om := Toon.part(cart, Toon.box(Vector3(0.12, 0.17, 0.04)), red, Vector3(0.56, 0.87, 0.1))
	om.rotation.y = -0.3
	var knot := Toon.part(cart, Toon.box(Vector3(0.06, 0.05, 0.045)), gold, Vector3(0.56, 0.92, 0.1))
	knot.rotation.y = -0.3
	# chōchin vermillon allumé, pendu à l'angle avant droit du toit (il se balance : « Lantern »)
	var lan := Node3D.new()
	lan.name = "Lantern"
	cart.add_child(lan)
	lan.position = Vector3(0.9, 2.0, 0.14)
	Toon.part(lan, Toon.cyl(0.006, 0.006, 0.16, 4), sumi, Vector3(0, -0.08, 0))
	var glow := Toon.mat(Color("#E8574A"), false)
	glow.emission_enabled = true
	glow.emission = Color("#FF7A3C")
	glow.emission_energy_multiplier = 0.9
	Toon.part(lan, Toon.sphere(0.15), glow, Vector3(0, -0.34, 0), Vector3(1, 1.35, 1))
	Toon.part(lan, Toon.cyl(0.08, 0.08, 0.04, 10), sumi, Vector3(0, -0.15, 0))
	Toon.part(lan, Toon.cyl(0.08, 0.08, 0.04, 10), sumi, Vector3(0, -0.54, 0))
	_part_flat(lan, _mesh("lamp_halo"), _mat("altar_lamp_halo"), Vector3(0, -0.34, 0))
	# nobori d'or plantée derrière la charrette (lisible de loin)
	Toon.part(cart, Toon.cyl(0.025, 0.03, 2.3, 6), wood_dark, Vector3(1.02, 1.15, -0.42))
	var flag := Toon.part(cart, Toon.box(Vector3(0.32, 0.92, 0.015)), Toon.mat_shared(Color("#E2A93B"), true, 0.012), Vector3(1.2, 1.72, -0.42))
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Toon.part(cart, Toon.box(Vector3(0.36, 0.03, 0.03)), wood_dark, Vector3(1.2, 2.2, -0.42))
	var fmon := Toon.part(cart, Toon.cyl(0.085, 0.085, 0.01, 16), red, Vector3(1.2, 1.86, -0.41))
	fmon.rotation.x = PI / 2.0
	# le tanuki, devant à gauche, tourné vers le chemin
	var tk := Node3D.new()
	tk.name = "Tanuki"
	n.add_child(tk)
	tk.position = Vector3(-1.28, 0, 0.55)
	tk.rotation.y = 0.35
	tk.scale = Vector3.ONE * 1.3
	var fur := Toon.mat_shared(TANUKI_BROWN, true, 0.025)
	var dark := Toon.mat_shared(TANUKI_DARK, true, 0.02)
	var cream := Toon.mat_shared(TANUKI_CREAM, true, 0.02)
	for sx in [-1.0, 1.0]:
		Toon.part(tk, Toon.sphere(0.09), dark, Vector3(float(sx) * 0.13, 0.07, 0.06), Vector3(1, 0.7, 1.3))
	Toon.part(tk, Toon.sphere(0.32), fur, Vector3(0, 0.4, 0), Vector3(1, 1.08, 0.92))
	Toon.part(tk, Toon.sphere(0.24), cream, Vector3(0, 0.36, 0.16), Vector3(0.9, 1.0, 0.62))
	# queue rayée
	Toon.part(tk, Toon.sphere(0.13), fur, Vector3(0.05, 0.2, -0.34), Vector3(1, 0.9, 1.3))
	Toon.part(tk, Toon.sphere(0.09), dark, Vector3(0.07, 0.17, -0.46))
	# bras (l'un tient un koban levé)
	Toon.part(tk, Toon.sphere(0.08), dark, Vector3(-0.27, 0.42, 0.1), Vector3(0.9, 1.3, 0.9))
	var arm := Node3D.new()
	arm.name = "Arm"
	tk.add_child(arm)
	arm.position = Vector3(0.26, 0.5, 0.08)
	Toon.part(arm, Toon.sphere(0.08), dark, Vector3(0.03, 0.08, 0), Vector3(0.9, 1.4, 0.9))
	var coin := Toon.part(arm, Toon.cyl(0.07, 0.07, 0.02, 14), gold, Vector3(0.05, 0.22, 0.03), Vector3(0.8, 1, 1.1))
	coin.rotation.x = PI / 2.0
	# tête : masque sombre, museau clair, truffe, yeux, oreilles
	Toon.part(tk, Toon.sphere(0.23), fur, Vector3(0, 0.84, 0.02))
	Toon.part(tk, Toon.sphere(0.12), dark, Vector3(0, 0.86, 0.15), Vector3(1.75, 0.62, 0.7))
	Toon.part(tk, Toon.sphere(0.085), cream, Vector3(0, 0.78, 0.2), Vector3(1.1, 0.85, 1))
	Toon.part(tk, Toon.sphere(0.035), Toon.mat_shared(Toon.SUMI, false), Vector3(0, 0.8, 0.28))
	for sx in [-1.0, 1.0]:
		Toon.part(tk, Toon.sphere(0.028), Toon.mat_shared(Color("#FFF6E0"), false), Vector3(float(sx) * 0.075, 0.875, 0.235))
		Toon.part(tk, Toon.sphere(0.065), dark, Vector3(float(sx) * 0.15, 1.0, -0.02), Vector3(1, 1.1, 0.7))
	# chapeau de paille (kasa) penché, sa feuille de tanuki
	# (repoussé sur la nuque : de la caméra haute, on voit le visage sous le bord)
	var hat := Toon.part(tk, Toon.cyl(0.02, 0.3, 0.13, 14), Toon.mat_shared(STRAW, true, 0.02), Vector3(0, 1.04, -0.14))
	hat.rotation = Vector3(-0.75, 0, 0.12)
	var leaf := Toon.part(tk, Toon.sphere(0.065), Toon.mat_shared(Color("#5F9A3C"), true, 0.012), Vector3(0.02, 1.1, -0.2), Vector3(0.6, 0.25, 1.4))
	leaf.rotation = Vector3(-0.75, 0.6, 0)


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
		"seal":
			_update_seal(pk, t, fk)


## Raté (main._puzzle_fail) : la figure de la stèle (ou de la plaque du coffre scellé) passe au vermillon,
## puis se retrace depuis le début.
static func fail(pk: Dictionary, t: float) -> void:
	if String(pk["pz"]) in ["stele", "seal"]:
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


## Aplat sans lumière opaque (papier de la plaque, traits du sceau) : pas de tri avec l'encre transparente.
static func _opaque(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


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
		"altar_table":
			m = Toon.box(Vector3(0.72, 0.22, 0.48))
		"altar_pillar":
			m = Toon.cyl(0.03, 0.036, 0.7, 8)
		"altar_kusabi":
			m = Toon.box(Vector3(0.028, 0.08, 0.05))
		"altar_nuki":
			m = Toon.box(Vector3(0.62, 0.04, 0.035))
		"altar_gaku":
			m = Toon.box(Vector3(0.07, 0.1, 0.02))
		"altar_shimaki":
			m = Toon.box(Vector3(0.66, 0.045, 0.06))
		"altar_kasagi":
			m = Toon.box(Vector3(0.7, 0.06, 0.09))
		"altar_kasagi_tip":
			m = Toon.box(Vector3(0.12, 0.06, 0.09))
		"altar_rope":
			m = Toon.cyl(0.018, 0.018, 0.5, 6)
		"altar_shide":
			m = Toon.box(Vector3(0.04, 0.075, 0.006))
		"altar_ofuda":
			m = Toon.box(Vector3(0.09, 0.2, 0.008))
		"altar_seal":
			m = Toon.box(Vector3(0.045, 0.045, 0.004))
		"altar_ring":
			m = ribbon_mesh([_arc(ALTAR_RING_R, 0.0, TAU, 64)], 0.05, 0.0, 0.0)
		"yatai_ring":
			m = ribbon_mesh([_arc(YATAI_RING_R, 0.0, TAU, 72)], 0.075, 0.0, 0.0)
		"chain_link":
			var tl := TorusMesh.new()
			tl.inner_radius = 0.026
			tl.outer_radius = 0.054
			tl.rings = 10
			tl.ring_segments = 5
			m = tl
		"ofuda_front":
			m = Toon.box(Vector3(0.17, 0.146, 0.008))
		"ofuda_step":
			m = Toon.box(Vector3(0.17, 0.008, 0.15))
		"ofuda_riser":
			m = Toon.box(Vector3(0.17, 0.124, 0.008))
		"ofuda_top":
			m = Toon.box(Vector3(0.17, 0.008, 0.58))
		"ofuda_low":
			m = Toon.box(Vector3(0.17, 0.38, 0.008))
		"ofuda_mark":
			m = Toon.box(Vector3(0.03, 0.2, 0.004))
		"seal_half":
			m = Toon.box(Vector3(SEAL_HALF * 2.0, 0.34, 0.06))
		"seal_bar_h":
			m = Toon.box(Vector3(0.14, 0.02, 0.004))
		"seal_bar_v":
			m = Toon.box(Vector3(0.02, 0.3, 0.004))
		"seal_crack":
			m = Toon.box(Vector3(0.016, 0.36, 0.004))
		"ema_stake":
			m = Toon.cyl(0.045, 0.055, 1.3, 8)
		"ema_plank":
			m = Toon.box(Vector3(EMA_SIZE.x, EMA_SIZE.y, 0.05))
		"ema_roof":
			m = Toon.box(Vector3(EMA_SIZE.x + 0.16, 0.07, 0.12))
		"ema_paper":
			m = Toon.box(Vector3(EMA_SIZE.x - 0.16, EMA_SIZE.y - 0.2, 0.012))
		"ema_knot":
			m = Toon.sphere(0.06)
		"ink_drop":
			m = Toon.sphere(0.035)
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
			m = Toon.flat(Color(_wcol("stone", STONE).lerp(Color("#E2D8C0"), 0.6), 0.62))
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
		"altar_red":
			m = Toon.mat(Toon.VERMILION, true, 0.02)
		"altar_sumi":
			m = Toon.mat(Color("#2A2428"), true, 0.02)
		"altar_ink":
			var ai := Toon.flat(Color(Toon.SUMI, 0.9))
			ai.render_priority = 1
			m = ai
		"altar_gold":
			var ag := Toon.flat(Color(Toon.GOLD, 0.38))
			ag.render_priority = 1
			m = ag
		"altar_glow":
			var agl := _glow_mat(Color(Toon.VERMILION, 0.45), true)
			agl.render_priority = -1
			m = agl
		"altar_lamp":
			var al := Toon.mat(PAPER_LIT, false)
			al.emission_enabled = true
			al.emission = Color(LAMP_EMIT, 1.0)
			al.emission_energy_multiplier = 1.2
			m = al
		"yatai_gold":
			var yg := Toon.flat(Color(Toon.GOLD, 0.8))
			yg.render_priority = 1
			m = yg
		"yatai_wash":
			var yw := Toon.flat(Color(Toon.GOLD, 0.14))
			yw.render_priority = 1
			m = yw
		"altar_lamp_halo":
			var ah := _glow_mat(Color(LAMP_EMIT, 0.4), true)
			ah.render_priority = -1
			m = ah
		"seal_wash":
			m = Toon.flat(Color(Toon.SUMI, 0.12))
		"chain":
			m = Toon.mat(Color("#3E3B46"), false)
		"ofuda":
			m = Toon.mat(Color("#F4ECD8"), false)
		"seal_ink":
			m = _opaque(Toon.SUMI)
		"seal_block":
			m = Toon.mat(Toon.VERMILION, true, 0.012)
		"seal_mark":
			m = _opaque(Color("#F6E9CF"))
		"ema_paper":
			m = _opaque(Color("#E9DFC8"))
		"ema_ghost":
			var eg := ink_mat(Color(Toon.SUMI, 0.2))
			eg.set_shader_parameter(P_DRY, 0.3)
			m = eg
		"ink_drop":
			m = _opaque(Toon.SUMI)
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
