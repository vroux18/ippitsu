extends RefCounted
## Sanctuaire d'oni des recoins « défi d'élite » (main._pocket_node, _update_oni) : socle de pierre à trois
## degrés, hokora au toit de bois noir à pignon sur rue et piliers vermillon, masque d'oni en relief sur le
## fronton, shimenawa et shide entre les piliers, brasero d'offrandes, deux tōrō de pierre, pas japonais devant.
## Pierre, bois, laque, neige ou braise à la palette du monde (BossShrine.pal + quelques touches propres).
##
## Quatre états (o["state"], o = pk["oni"]) : « idle » (lanternes chaudes, braises qui couvent), « summon » (invocation, ≈ 1,2 s :
## lanternes rouges, corde qui se tend, brasero qui s'embrase, masque qui s'illumine, colonne d'encre rouge ;
## main fait paraître l'élite devant à SPAWN_T), « active » (tant que l'élite vit), « done » (éteint, fumée
## douce, masque fendu et sombre). Les matières animées ont leur émission allumée dès la construction (même
## shader du début à la fin) ; update() ne fait que régler des valeurs et déplacer quelques nœuds.

const Toon = preload("res://scripts/toon.gd")
const BossShrine = preload("res://scripts/boss_shrine.gd")

const TRIGGER_R := 3.0  # le héros à moins de 3 m (hors combat) : invocation
const SPAWN_T := 1.0  # de l'appel à l'élite (s)
const SUMMON_T := 1.6  # fin de la colonne d'encre (s)
const DONE_T := 0.8  # extinction (s)
const FRONT := 1.6  # l'élite paraît à cette distance devant le sanctuaire (côté pas japonais)
const YAW := 0.2  # le sanctuaire se tourne un peu vers le milieu de l'étape
const MASK_S := 1.3  # onigawara : masque agrandi au bout du faîtage
const BODY_S := 1.15  # tout le sanctuaire (lisible de la caméra de jeu, dans l'emprise du recoin)
const SAG := 0.075  # flèche de la shimenawa au repos
const RED := Color("#FF3A22")  # feu d'invocation
const RED_DEEP := Color("#B0201A")
const OFF := Color("#3C383C")  # papier des lanternes éteintes

const HOKORA_Y := 0.36  # dessus du degré haut
const HOKORA_Z := -0.2
const HOKORA_S := 1.12
const BRAZIER := Vector3(0, 0.25, 0.4)  # sur le deuxième degré, devant le hokora
const ROPE_Y := 0.5  # (repère du hokora)
const ROPE_X := 0.3
const ROPE_Z := 0.235


## Couleurs du sanctuaire dans le monde `wid`.
static func look(wid: int) -> Dictionary:
	var p := BossShrine.pal(wid)
	var d := {
		"stone": p["stone"], "stone_dk": p["stone_dk"], "plinth": p["stone"], "plinth_dk": p["stone_dk"],
		"wood": Color(p["wood"]).darkened(0.25), "roof": Color("#24202A"), "ridge": Color("#141216"),
		"trim": p["trim"], "flame": p["flame"], "pillar": Color("#C8402D"), "mask": Color("#C23A2C"),
		"horn": Color("#EFE6D2"), "cap": Color(0, 0, 0, 0), "moss": Color(0, 0, 0, 0), "ember": false,
		"day": wid == 1 or wid == 3 or wid == 5,
	}
	match wid:
		1:
			d["moss"] = Color("#5F7D3C")
		2:
			# Tanabata : socle de planches sur pierre, mousse
			d["plinth"] = Color("#6A5440")
			d["plinth_dk"] = Color("#4A3A2E")
			d["pillar"] = Color("#B8402E")
			d["moss"] = Color("#4A6A44")
		3:
			# Cent Contes : neige sur les toits et les degrés, oni bleu (ao-oni)
			d["cap"] = Color("#EEF2F6")
			d["mask"] = Color("#3E5E8E")
			d["roof"] = Color("#2A2C36")
		4:
			# Fuji Rouge : basalte, laque sombre, braises dans les joints
			d["stone"] = Color("#4A4442")
			d["stone_dk"] = Color("#2E2A2A")
			d["plinth"] = Color("#4A4442")
			d["plinth_dk"] = Color("#2E2A2A")
			d["pillar"] = Color("#9A2A1E")
			d["mask"] = Color("#C8402E")
			d["ember"] = true
			d["roof"] = Color("#1E1A1E")
		5:
			d["pillar"] = Color("#B23A2E")
		6:
			d["pillar"] = Color("#A8382A")
			d["moss"] = Color("#3E5A48")
		7:
			# Ryūgū-jō : platelage de bois délavé, piliers corail, oni bleu-vert
			d["plinth"] = Color("#8A8270")
			d["plinth_dk"] = Color("#5E584C")
			d["pillar"] = Color("#C8563E")
			d["mask"] = Color("#2E6A72")
			d["moss"] = Color("#C86E7E")
		8:
			# Yomi : pierre cendre, laque lie-de-vin, masque d'os
			d["pillar"] = Color("#7A2A3E")
			d["mask"] = Color("#CFC6B4")
			d["horn"] = Color("#2A2430")
	return d


## Construit le sanctuaire sous `n` (posé au sol, centre du recoin), tourné de `yaw` ; `ok(p)` dit si un point
## du monde est de la terre ferme (pas japonais posés seulement là). Renvoie les pièces animées (aussi en
## métadonnée « oni » de `n`).
static func build(n: Node3D, wid: int, yaw: float, ok := Callable()) -> Dictionary:
	var c := look(wid)
	var day: bool = c["day"]
	var o := {"yaw": yaw, "lamps": [], "halos": [], "shide": [], "segs": []}
	var body := Node3D.new()
	body.name = "OniShrine"
	n.add_child(body)
	body.rotation.y = yaw
	body.scale = Vector3.ONE * BODY_S
	o["body"] = body
	var stone := Toon.mat_shared(c["stone"])
	var stone_dk := Toon.mat_shared(c["stone_dk"])
	var plinth := Toon.mat_shared(c["plinth"])
	var plinth_dk := Toon.mat_shared(c["plinth_dk"])
	var wood := Toon.mat_shared(c["wood"])
	var roof := Toon.mat_shared(c["roof"])
	var ridge := Toon.mat_shared(c["ridge"])
	var pillar := Toon.mat_shared(c["pillar"])
	var trim := Toon.mat_shared(c["trim"], false)
	var sumi := Toon.mat_shared(Toon.SUMI, false)
	var paper := Toon.mat_shared(Toon.WASHI, true, 0.012)
	var straw := Toon.mat_shared(Color("#C9A860"), true, 0.014)
	var cap: Color = c["cap"]
	var snow := Toon.mat_shared(cap) if cap.a > 0.0 else null

	# lueur des lanternes au sol : elle dit la zone d'approche (ambre, jamais rouge : le rouge au sol annonce les attaques)
	Toon.blob(body, 1.25, 0.3)
	var halo := _glow_mat(Color(Color(c["flame"]), 0.0))
	var hm := Toon.part(body, Toon.blob_mesh(), halo, Vector3(0, 0.016, 0.35), Vector3(1.75, 1.0, 1.55))
	hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o["halo"] = halo
	o["halo_base"] = 0.2 if day else 0.34

	# socle à trois degrés (reculés : les marches se lisent de face)
	Toon.part(body, Toon.box(Vector3(1.56, 0.12, 1.3)), plinth_dk, Vector3(0, 0.06, 0.0))
	Toon.part(body, Toon.box(Vector3(1.3, 0.12, 1.02)), plinth, Vector3(0, 0.18, -0.1))
	Toon.part(body, Toon.box(Vector3(0.98, 0.12, 0.72)), plinth, Vector3(0, 0.3, -0.2))
	# nez de marche : un filet sombre au bord avant de chaque degré (lecture des marches)
	Toon.part(body, Toon.box(Vector3(1.3, 0.02, 0.05)), plinth_dk, Vector3(0, 0.245, 0.39))
	Toon.part(body, Toon.box(Vector3(0.98, 0.02, 0.05)), plinth_dk, Vector3(0, 0.365, 0.14))
	if snow != null:
		Toon.part(body, Toon.box(Vector3(1.66, 0.035, 0.26)), snow, Vector3(0, 0.13, -0.56))
		Toon.part(body, Toon.box(Vector3(0.24, 0.03, 0.9)), snow, Vector3(-0.66, 0.255, -0.12))
	var moss: Color = c["moss"]
	if moss.a > 0.0:
		var mm := Toon.mat_shared(moss)
		Toon.part(body, Toon.sphere(0.12), mm, Vector3(0.7, 0.13, -0.5), Vector3(1.3, 0.4, 1.0))
		Toon.part(body, Toon.sphere(0.1), mm, Vector3(-0.55, 0.25, -0.46), Vector3(1.4, 0.4, 0.9))
		Toon.part(body, Toon.sphere(0.09), mm, Vector3(-0.76, 0.12, 0.3), Vector3(1.2, 0.45, 1.0))
	if bool(c["ember"]):
		# braise : veines incandescentes entre les pierres
		var em := Toon.mat(Color("#E07A2E"), false)
		em.emission_enabled = true
		em.emission = Color("#C0401A")
		Toon.part(body, Toon.box(Vector3(0.5, 0.02, 0.035)), em, Vector3(-0.32, 0.121, 0.52))
		Toon.part(body, Toon.box(Vector3(0.035, 0.02, 0.4)), em, Vector3(0.52, 0.241, 0.05))
		Toon.part(body, Toon.box(Vector3(0.3, 0.02, 0.035)), em, Vector3(0.2, 0.361, 0.04))

	# pas japonais vers l'avant (seulement sur la terre ferme)
	var step := Toon.mat_shared(Color(c["stone_dk"]).lerp(Color(c["stone"]), 0.5))
	var k := 0
	for sz in [1.05, 1.5, 1.95]:
		var lp := Vector3(0.1 if k % 2 == 0 else -0.08, 0.0, float(sz))
		k += 1
		var wp := n.position + Basis(Vector3.UP, yaw) * lp * BODY_S
		if ok.is_valid() and not bool(ok.call(wp, 0.25)):
			continue
		var s := Toon.part(body, Toon.cyl(0.21, 0.23, 0.05, 7), step, lp + Vector3(0, 0.025, 0))
		s.rotation.y = 0.4 * float(k)

	_lanterns(body, o, c, stone, stone_dk, snow)
	_brazier(body, o)
	_hokora(body, o, c, wood, roof, ridge, pillar, trim, sumi, paper, straw, snow)
	_column(body, o)
	o["state"] = "idle"
	n.set_meta("oni", o)
	return o


static func _glow_mat(col: Color) -> StandardMaterial3D:
	Toon.blob_mesh()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	m.albedo_texture = Toon._blob_tex
	return m


## Matière qui s'allume : toon à émission (réglée par update), contour fin ou sans.
static func _lit(col: Color, outline := true, osz := 0.02) -> StandardMaterial3D:
	var m := Toon.mat(col, outline, osz)
	m.emission_enabled = true
	m.emission = Color.BLACK
	return m


## Deux tōrō de pierre aux coins avant du socle ; leur papier s'allume (chaud, puis rouge).
static func _lanterns(body: Node3D, o: Dictionary, c: Dictionary, stone: Material, roof: Material, snow: Material) -> void:
	for sx in [-1.0, 1.0]:
		var ln := Node3D.new()
		body.add_child(ln)
		ln.position = Vector3(float(sx) * 0.6, 0.12, 0.42)
		ln.scale = Vector3.ONE * 0.7
		Toon.part(ln, Toon.cyl(0.24, 0.28, 0.1, 6), stone, Vector3(0, 0.05, 0))
		Toon.part(ln, Toon.cyl(0.17, 0.22, 0.06, 6), stone, Vector3(0, 0.13, 0))
		Toon.part(ln, Toon.cyl(0.07, 0.085, 0.42, 8), stone, Vector3(0, 0.37, 0))
		Toon.part(ln, Toon.cyl(0.21, 0.13, 0.08, 6), stone, Vector3(0, 0.62, 0))
		var lamp := _lit(Color(c["flame"]).darkened(0.1), true, 0.03)
		Toon.part(ln, Toon.box(Vector3(0.25, 0.22, 0.25)), lamp, Vector3(0, 0.79, 0))
		(o["lamps"] as Array).append(lamp)
		for px in [-1.0, 1.0]:
			for pz in [-1.0, 1.0]:
				Toon.part(ln, Toon.box(Vector3(0.055, 0.26, 0.055)), stone, Vector3(float(px) * 0.12, 0.79, float(pz) * 0.12))
		Toon.part(ln, Toon.cyl(0.25, 0.28, 0.05, 6), roof, Vector3(0, 0.945, 0))
		Toon.part(ln, Toon.cyl(0.05, 0.24, 0.14, 6), roof, Vector3(0, 1.03, 0))
		if snow != null:
			Toon.part(ln, Toon.cyl(0.04, 0.21, 0.08, 6), snow, Vector3(0, 1.07, 0))
		Toon.part(ln, Toon.sphere(0.065), stone, Vector3(0, 1.13, 0), Vector3(1, 1.25, 1))
		# halo du feu, à plat au pied (vue d'en haut, le toit cache le foyer)
		var hg := _glow_mat(Color(0, 0, 0, 0))
		var h := Toon.part(ln, Toon.blob_mesh(), hg, Vector3(0, 0.01, 0.1), Vector3(1.0, 1.0, 1.0))
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(o["halos"] as Array).append(hg)


## Brasero d'offrandes (trépied de fer, corbeille, braises qui couvent ; flamme cachée jusqu'à l'appel).
static func _brazier(body: Node3D, o: Dictionary) -> void:
	var b := Node3D.new()
	body.add_child(b)
	b.position = BRAZIER
	var iron := Toon.mat_shared(Color("#2E2C30"))
	for kk in 3:
		var a := TAU * float(kk) / 3.0 + 0.5
		var leg := Toon.part(b, Toon.box(Vector3(0.035, 0.16, 0.035)), iron, Vector3(sin(a) * 0.09, 0.08, cos(a) * 0.09))
		leg.rotation = Vector3(cos(a) * 0.25, 0, -sin(a) * 0.25)
	Toon.part(b, Toon.cyl(0.16, 0.1, 0.1, 10), iron, Vector3(0, 0.2, 0))
	# lit de cendre et quelques braises (pas de disque rouge : des morceaux qui rougeoient)
	Toon.part(b, Toon.cyl(0.14, 0.14, 0.02, 10), Toon.mat_shared(Color("#3A3436"), false), Vector3(0, 0.25, 0))
	var ember := _lit(Color("#6A2A1A"), false)
	for kk in 5:
		var ea := float(kk) * 2.39
		var er := 0.0 if kk == 0 else 0.075
		Toon.part(b, Toon.sphere(0.04), ember, Vector3(sin(ea) * er, 0.265, cos(ea) * er), Vector3(1.0, 0.6, 1.0))
	o["ember"] = ember
	var fire := Node3D.new()
	b.add_child(fire)
	fire.position = Vector3(0, 0.25, 0)
	var fm := _lit(RED, false)
	var cm := _lit(Color("#FFD27A"), false)
	Toon.part(fire, Toon.cyl(0.0, 0.13, 0.36, 7), fm, Vector3(0, 0.18, 0))
	Toon.part(fire, Toon.cyl(0.0, 0.07, 0.22, 5), cm, Vector3(0.02, 0.11, 0.02))
	fire.scale = Vector3.ONE * 0.001
	fire.visible = false
	o["fire"] = fire
	o["fire_m"] = fm
	o["brazier"] = b


## Hokora : plancher, parois de bois sombre, quatre piliers vermillon, nuki, pignon face à la caméra avec le
## masque d'oni en relief, toit de bois noir en pente (bordé d'or), faîtage et chigi croisés, shimenawa.
static func _hokora(body: Node3D, o: Dictionary, c: Dictionary, wood: Material, roof: Material, ridge: Material,
		pillar: Material, trim: Material, sumi: Material, paper: Material, straw: Material, snow: Material) -> void:
	var h := Node3D.new()
	body.add_child(h)
	h.position = Vector3(0, HOKORA_Y, HOKORA_Z)
	h.scale = Vector3.ONE * HOKORA_S
	o["hokora"] = h
	Toon.part(h, Toon.box(Vector3(0.74, 0.08, 0.58)), wood, Vector3(0, 0.04, -0.02))
	# parois : fond et côtés de bois sombre, intérieur d'encre, miroir d'or (shintai) et lueur rouge
	Toon.part(h, Toon.box(Vector3(0.58, 0.5, 0.05)), wood, Vector3(0, 0.33, -0.24))
	for sx in [-1.0, 1.0]:
		Toon.part(h, Toon.box(Vector3(0.05, 0.5, 0.42)), wood, Vector3(float(sx) * 0.28, 0.33, -0.02))
	Toon.part(h, Toon.box(Vector3(0.5, 0.46, 0.02)), sumi, Vector3(0, 0.32, -0.21))
	var inner := Toon.flat(Color(RED, 0.0))
	var im := Toon.part(h, Toon.box(Vector3(0.46, 0.42, 0.01)), inner, Vector3(0, 0.32, -0.195))
	im.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o["inner"] = inner
	var mir := Toon.part(h, Toon.cyl(0.07, 0.07, 0.02, 14), Toon.mat_shared(Toon.GOLD, true, 0.012), Vector3(0, 0.3, -0.18))
	mir.rotation.x = PI / 2.0
	# piliers vermillon et nuki
	for sx in [-1.0, 1.0]:
		for z in [0.2, -0.24]:
			Toon.part(h, Toon.cyl(0.036, 0.036, 0.5, 8), pillar, Vector3(float(sx) * 0.3, 0.33, float(z)))
	Toon.part(h, Toon.box(Vector3(0.72, 0.06, 0.06)), pillar, Vector3(0, 0.56, 0.2))
	for sx in [-1.0, 1.0]:
		Toon.part(h, Toon.box(Vector3(0.06, 0.06, 0.56)), wood, Vector3(float(sx) * 0.3, 0.6, -0.02))
	# pignon (prisme triangulaire, pointe en haut) face à la caméra
	var g := Toon.part(h, Toon.cyl(1.0, 1.0, 1.0, 3), wood, Vector3(0, 0.67, 0.2), Vector3(0.4, 0.05, 0.18))
	g.rotation.x = -PI / 2.0
	# toit à deux pans (faîtage dans l'axe : pignon sur rue), bordé d'or au bord avant
	var a := 0.62
	var ls := 0.58
	var ry := 0.93
	for sx in [-1.0, 1.0]:
		var slab := Toon.part(h, Toon.box(Vector3(ls, 0.05, 0.7)), roof, Vector3(float(sx) * ls * 0.5 * cos(a), ry - ls * 0.5 * sin(a), -0.02))
		slab.rotation.z = -float(sx) * a
		var hafu := Toon.part(slab, Toon.box(Vector3(ls + 0.02, 0.07, 0.035)), trim, Vector3(0, 0.0, 0.36))
		hafu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if snow != null:
			Toon.part(slab, Toon.box(Vector3(ls - 0.04, 0.04, 0.64)), snow, Vector3(0.0, 0.045, 0))
	Toon.part(h, Toon.box(Vector3(0.08, 0.08, 0.76)), ridge, Vector3(0, ry + 0.02, -0.02))
	# chigi : planches croisées au-dessus du pignon avant (à l'arrière, vues d'en haut, elles feraient une flèche)
	for z in [0.32]:
		for sx in [-1.0, 1.0]:
			var ch := Toon.part(h, Toon.box(Vector3(0.04, 0.26, 0.03)), ridge, Vector3(float(sx) * 0.05, ry + 0.1, float(z)))
			ch.rotation.z = float(sx) * 0.62
	_mask(h, o, c, sumi)
	# shimenawa entre les piliers avant (segments recalculés quand elle se tend) et trois shide
	var rope := Node3D.new()
	h.add_child(rope)
	o["rope"] = rope
	for kk in 4:
		var sg := Toon.part(rope, Toon.cyl(0.026, 0.026, 1.0, 6), straw, Vector3.ZERO)
		(o["segs"] as Array).append(sg)
	for kk in 3:
		var sd := Node3D.new()
		rope.add_child(sd)
		for j in 2:
			var leaf := Toon.part(sd, Toon.box(Vector3(0.06, 0.07, 0.008)), paper, Vector3(0.012 * float(j), -0.04 - 0.065 * float(j), 0))
			leaf.rotation.z = 0.25 if j == 0 else -0.25
			leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(o["shide"] as Array).append(sd)
	_rope_pose(o, SAG, 0.0)


## Masque d'oni en relief sur le fronton, penché vers la caméra : visage, cornes, sourcils froncés, yeux qui
## s'allument, gueule à crocs ; une fente d'encre (cachée) le traverse une fois le défi relevé.
static func _mask(h: Node3D, o: Dictionary, c: Dictionary, sumi: Material) -> void:
	var m := Node3D.new()
	h.add_child(m)
	m.position = Vector3(0, 0.86, 0.33)
	m.rotation.x = -0.95
	m.scale = Vector3.ONE * MASK_S
	o["mask"] = m
	var face_c: Color = c["mask"]
	var face := _lit(face_c, true, 0.022)
	o["mask_m"] = face
	o["mask_c"] = face_c
	Toon.part(m, Toon.sphere(0.17), face, Vector3.ZERO, Vector3(1.0, 1.05, 0.42))
	# joues et mâchoire : un second volume plus large en bas
	Toon.part(m, Toon.sphere(0.13), face, Vector3(0, -0.07, 0.01), Vector3(1.15, 0.7, 0.45))
	var horn := Toon.mat_shared(c["horn"], true, 0.018)
	for sx in [-1.0, 1.0]:
		var hn := Toon.part(m, Toon.cyl(0.0, 0.045, 0.17, 8), horn, Vector3(float(sx) * 0.12, 0.17, -0.01))
		hn.rotation.z = -float(sx) * 0.5
		if sx > 0.0:
			o["horn_r"] = hn
	var eye := _lit(Color("#E8C25A"), false)
	o["eye_m"] = eye
	for sx in [-1.0, 1.0]:
		var br := Toon.part(m, Toon.box(Vector3(0.12, 0.035, 0.04)), sumi, Vector3(float(sx) * 0.068, 0.07, 0.065))
		br.rotation.z = float(sx) * 0.42
		var ey := Toon.part(m, Toon.box(Vector3(0.065, 0.035, 0.03)), eye, Vector3(float(sx) * 0.065, 0.025, 0.068))
		ey.rotation.z = float(sx) * 0.2
	Toon.part(m, Toon.box(Vector3(0.17, 0.05, 0.04)), sumi, Vector3(0, -0.085, 0.06))
	var fang := Toon.mat_shared(Color("#F5EEDD"), false)
	for sx in [-1.0, 1.0]:
		Toon.part(m, Toon.cyl(0.0, 0.02, 0.06, 5), fang, Vector3(float(sx) * 0.055, -0.08, 0.08))
	# fente d'encre (après la victoire) : deux traits brisés du front au menton
	var crack := Node3D.new()
	m.add_child(crack)
	var c1 := Toon.part(crack, Toon.box(Vector3(0.036, 0.17, 0.03)), sumi, Vector3(0.03, 0.085, 0.078))
	c1.rotation.z = 0.45
	var c2 := Toon.part(crack, Toon.box(Vector3(0.036, 0.16, 0.03)), sumi, Vector3(-0.005, -0.065, 0.082))
	c2.rotation.z = -0.3
	crack.visible = false
	o["crack"] = crack


## Colonne d'encre et de fumée rouge qui jaillit du hokora à l'appel (cachée sinon) : un fil d'encre au cœur,
## des volutes d'encre et de vermillon qui montent en spirale et s'ouvrent en haut, derrière le masque.
const COL_H := 3.0
const PUFFS := 28


static func _column(body: Node3D, o: Dictionary) -> void:
	var col := Node3D.new()
	body.add_child(col)
	col.position = Vector3(0, HOKORA_Y + 0.25, HOKORA_Z - 0.06)
	var core := Toon.flat(Color(Toon.SUMI, 0.0))
	var cm := Toon.part(col, Toon.cyl(0.08, 0.14, 1.0, 8), core, Vector3(0, 0.5, 0))
	var sheath := Toon.flat(Color(RED_DEEP, 0.0))
	var sm := Toon.part(cm, Toon.cyl(0.19, 0.26, 1.0, 10), sheath, Vector3.ZERO)
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o["col_sheath"] = sheath
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := Toon.flat(Color(Toon.SUMI, 0.0))
	var red := Toon.flat(Color(RED_DEEP, 0.0))
	var puffs: Array = []
	for kk in PUFFS:
		var pf := Toon.part(col, Toon.sphere(0.19), red if kk % 2 == 1 else ink, Vector3.ZERO)
		pf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puffs.append(pf)
	col.visible = false
	o["col"] = col
	o["col_coremesh"] = cm
	o["col_core"] = core
	o["col_ink"] = ink
	o["col_red"] = red
	o["puffs"] = puffs


## Pose la shimenawa : flèche `sag`, shide agités de `shake`.
static func _rope_pose(o: Dictionary, sag: float, shake: float) -> void:
	var segs: Array = o["segs"]
	var nseg := segs.size()
	var pts: Array = []
	for i in nseg + 1:
		var t := float(i) / float(nseg)
		pts.append(Vector3(lerpf(-ROPE_X, ROPE_X, t), ROPE_Y - sag * 4.0 * t * (1.0 - t), ROPE_Z))
	for i in nseg:
		var pa: Vector3 = pts[i]
		var pb: Vector3 = pts[i + 1]
		var dv := pb - pa
		var y := dv.normalized()
		var x := Vector3(0, 0, 1).cross(y).normalized()
		var z := x.cross(y)
		(segs[i] as Node3D).transform = Transform3D(Basis(x, y * dv.length(), z), (pa + pb) * 0.5)
	var sh: Array = o["shide"]
	for j in sh.size():
		var t := float(j + 1) / float(sh.size() + 1)
		var sd: Node3D = sh[j]
		sd.position = Vector3(lerpf(-ROPE_X, ROPE_X, t), ROPE_Y - sag * 4.0 * t * (1.0 - t) - 0.01, ROPE_Z + 0.015)
		sd.rotation.z = shake * sin(float(j) * 2.1 + shake * 37.0)
		sd.rotation.x = shake * 0.6


# ------------------------------------------------------------------ entrées (main.gd)

## Point d'apparition de l'élite : devant le sanctuaire (côté pas japonais), en coordonnées du monde.
static func front(n: Node3D, o: Dictionary) -> Vector3:
	var yaw: float = o["yaw"]
	return n.position + Vector3(sin(yaw), 0, cos(yaw)) * FRONT


static func summon(o: Dictionary, t: float) -> void:
	o["state"] = "summon"
	o["t0"] = t
	o["cues"] = 0
	(o["fire"] as Node3D).visible = true


## Le défi est relevé : le sanctuaire s'éteint, fume, le masque se fend.
static func extinguish(o: Dictionary, t: float) -> void:
	o["state"] = "done"
	o["t1"] = t
	(o["col"] as Node3D).visible = false
	(o["crack"] as Node3D).visible = true
	var hb: Node3D = o["horn_r"]
	hb.scale = Vector3(1.0, 0.45, 1.0)  # corne droite brisée
	hb.position.y -= 0.045
	var b: Node3D = o["brazier"]
	var ss = o.get("seal_smoke")
	if ss != null and is_instance_valid(ss):
		(ss as CPUParticles3D).emitting = false
	o["smoke"] = _smoke(b, Vector3(0, 0.3, 0))


## Défi garanti par le sceau de l'oni des portes : pas de sceau flottant, le sanctuaire couve déjà au repos
## (lanternes d'un rouge doux, braises vives, yeux du masque qui rougeoient).
static func mark_seal(o: Dictionary) -> void:
	o["sealed"] = true
	(o["fire"] as Node3D).visible = true
	# un fil de fumée d'encre rougie monte déjà du brasero (vu d'en haut, la flamme seule ne se lit pas)
	o["seal_smoke"] = _smoke(o["brazier"] as Node3D, Vector3(0, 0.35, 0), Color(0.8, 0.2, 0.12))


## Fumée grise et lente au-dessus du brasero éteint (continue, quelques volutes).
static func _smoke(parent: Node3D, pos: Vector3, col := Color(0.2, 0.19, 0.21)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = Toon.sphere(0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = 9
	p.lifetime = 2.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.05
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.55
	p.gravity = Vector3(0.12, 0.05, 0)
	p.damping_min = 0.1
	p.damping_max = 0.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(1.0, 2.4))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(col, 0.0), Color(col, 0.7), Color(col.lightened(0.25), 0.0)])
	p.color_ramp = g
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	return p


static func _s(a: float, a0: float, a1: float) -> float:
	return smoothstep(a0, a1, a)


static func _back(x: float) -> float:
	# sortie avec léger dépassement (0 -> 1)
	var c1 := 1.9
	var u := x - 1.0
	return 1.0 + (c1 + 1.0) * u * u * u + c1 * u * u


## Chaque image (main._update_oni). Renvoie les signaux sonores franchis à cette image : « fire » (le brasero
## s'embrase), « gust » (la colonne jaillit).
static func update(o: Dictionary, t: float) -> Array:
	var cues: Array = []
	var st := String(o["state"])
	var c_warm: Color = Color(1.0, 0.72, 0.38)
	var lamps: Array = o["lamps"]
	var halos: Array = o["halos"]
	var halo: StandardMaterial3D = o["halo"]
	var hb: float = o["halo_base"]
	var mask_m: StandardMaterial3D = o["mask_m"]
	var eye_m: StandardMaterial3D = o["eye_m"]
	var ember: StandardMaterial3D = o["ember"]
	if st == "idle":
		var br := 0.5 + 0.5 * sin(t * 2.2)
		var sealed := bool(o.get("sealed", false))
		for lm in lamps:
			var lmm := lm as StandardMaterial3D
			if sealed:
				lmm.albedo_color = Color("#F08A6A")
				lmm.emission = Color(1.0, 0.32, 0.18) * (0.75 + 0.3 * br)
			else:
				lmm.emission = c_warm * (0.55 + 0.15 * br)
		for hg in halos:
			(hg as StandardMaterial3D).albedo_color = (Color(1.0, 0.45, 0.25) if sealed else Color(1.0, 0.7, 0.35)) * Color(1, 1, 1, hb * (0.85 + 0.25 * br))
		halo.albedo_color = Color(1.0, 0.62, 0.3, hb * 0.55 * (0.8 + 0.3 * br))
		ember.emission = Color(0.55, 0.12, 0.05) * ((1.4 + 0.6 * br) if sealed else (0.5 + 0.4 * br))
		if sealed:
			eye_m.emission = Color(1.0, 0.3, 0.1) * (0.5 + 0.4 * br)
			var fs: Node3D = o["fire"]
			fs.scale = Vector3.ONE * 0.42 * (0.9 + 0.1 * sin(t * 13.0))  # petite flamme qui couve
		return cues
	if st == "summon" or st == "active":
		var a: float = t - float(o["t0"])
		var n_cue: int = o["cues"]
		if n_cue == 0 and a >= 0.3:
			cues.append("fire")
			n_cue = 1
		if n_cue == 1 and a >= 0.55:
			cues.append("gust")
			n_cue = 2
		o["cues"] = n_cue
		var fl := 0.85 + 0.15 * sin(t * 19.0) * sin(t * 7.3)
		# lanternes : du chaud au rouge
		var kl := _s(a, 0.0, 0.3)
		for lm in lamps:
			var m := lm as StandardMaterial3D
			m.albedo_color = Color(1.0, 0.75, 0.5).lerp(Color("#FF6A4A"), kl)
			m.emission = c_warm.lerp(RED, kl) * lerpf(0.65, 1.6 * fl, kl)
		for hg in halos:
			(hg as StandardMaterial3D).albedo_color = Color(1.0, 0.7, 0.35).lerp(Color(1.0, 0.36, 0.16), kl) * Color(1, 1, 1, lerpf(hb, 0.5, kl) * fl)
		halo.albedo_color = Color(1.0, 0.62, 0.3) * Color(1, 1, 1, lerpf(hb * 0.55, hb * 0.8, kl) * fl)
		# corde qui se tend d'un coup (léger rebond), shide qui claquent
		var kr := _s(a, 0.15, 0.4)
		var shake := 0.5 * _s(a, 0.15, 0.25) * (1.0 - _s(a, 0.5, 0.9))
		_rope_pose(o, SAG * (1.0 - _back(kr)) if kr < 1.0 else 0.0, shake * sin(a * 40.0))
		# brasero
		var kf := _s(a, 0.3, 0.5)
		var fire: Node3D = o["fire"]
		fire.scale = Vector3.ONE * maxf(0.42 if bool(o.get("sealed", false)) else 0.001, _back(kf) * (0.9 + 0.12 * sin(t * 17.0)) * (1.0 + 0.6 * (1.0 - _s(a, 0.5, 1.2)) * _s(a, 0.3, 0.45)))
		ember.emission = Color(0.55, 0.12, 0.05).lerp(Color(1.0, 0.25, 0.08), kf) * (1.0 + 0.5 * kf)
		# masque : yeux puis visage qui s'illuminent, une pulsation à l'apparition
		var km := _s(a, 0.45, 0.7)
		eye_m.emission = Color(1.0, 0.3, 0.1) * (3.2 * km * fl)
		eye_m.albedo_color = Color("#E8C25A").lerp(Color("#FFE0A0"), km)
		mask_m.emission = Color(o["mask_c"]).lerp(RED, 0.6) * (0.9 * km * (0.8 + 0.2 * sin(t * 6.0)))
		var mk: Node3D = o["mask"]
		mk.scale = Vector3.ONE * MASK_S * (1.0 + 0.16 * _s(a, 0.45, 0.6) * (1.0 - _s(a, 0.6, 0.85)))
		var inner: StandardMaterial3D = o["inner"]
		inner.albedo_color = Color(RED, 0.7 * _s(a, 0.35, 0.6) * fl)
		# colonne d'encre rouge : jaillit (0,55 → 0,9 s), tient, s'élargit et se dissipe (1,05 → 1,6 s)
		var col: Node3D = o["col"]
		if a < 0.5 or a > SUMMON_T:
			col.visible = false
			if a > SUMMON_T and st == "summon":
				o["state"] = "active"
		else:
			col.visible = true
			var rise := _s(a, 0.5, 0.8)
			var fade := _s(a, 1.05, SUMMON_T)
			var hh := COL_H * maxf(0.02, _back(rise))
			var cm: Node3D = o["col_coremesh"]
			cm.scale = Vector3(1.0 + 1.5 * fade, hh, 1.0 + 1.5 * fade)
			cm.position.y = hh * 0.5
			var al := (1.0 - fade) * _s(a, 0.5, 0.58)
			(o["col_core"] as StandardMaterial3D).albedo_color = Color(Toon.SUMI, 0.85 * al)
			(o["col_sheath"] as StandardMaterial3D).albedo_color = Color(RED_DEEP, 0.42 * al)
			(o["col_ink"] as StandardMaterial3D).albedo_color = Color(Toon.SUMI, 0.42 * al)
			(o["col_red"] as StandardMaterial3D).albedo_color = Color(RED_DEEP, 0.5 * al)
			var puffs: Array = o["puffs"]
			for j in puffs.size():
				var pf: Node3D = puffs[j]
				# chaque volute monte le long du fil (spirale), grossit en haut, s'écarte quand tout se dissipe
				var ph := fmod(a * 1.3 + float(j) / float(PUFFS), 1.0)
				var ang := float(j) * 2.39 + a * 5.0
				var rr := 0.06 + 0.16 * ph + 0.5 * fade
				pf.position = Vector3(sin(ang) * rr, hh * ph, cos(ang) * rr)
				var sz := (0.55 + 1.1 * ph * ph) * (1.0 + 0.8 * fade) * minf(1.0, rise * 1.5)
				pf.scale = Vector3(sz, sz * 0.75, sz)
		return cues
	# éteint : lanternes de papier gris, halos morts, masque assombri et fendu, corde lâche
	var d: float = t - float(o.get("t1", t))
	if d > DONE_T + 0.1 and bool(o.get("settled", false)):
		return cues
	var kd := _s(d, 0.0, DONE_T)
	for lm in lamps:
		var m2 := lm as StandardMaterial3D
		m2.albedo_color = Color("#FF6A4A").lerp(OFF, kd)
		m2.emission = RED * (1.6 * (1.0 - kd))
	for hg in halos:
		(hg as StandardMaterial3D).albedo_color = Color(1.0, 0.36, 0.16, 0.5 * (1.0 - kd))
	halo.albedo_color = Color(1.0, 0.62, 0.3, hb * 0.8 * (1.0 - kd))
	(o["fire"] as Node3D).scale = Vector3.ONE * maxf(0.001, 1.0 - _s(d, 0.0, 0.35))
	(o["fire"] as Node3D).visible = d < 0.35
	ember.emission = Color(1.0, 0.25, 0.08) * (1.0 - kd) * 1.5
	ember.albedo_color = Color("#5A1E16").lerp(Color("#2A2628"), kd)
	eye_m.emission = Color.BLACK
	eye_m.albedo_color = Color("#E8C25A").lerp(Color("#2A2226"), kd)
	mask_m.emission = Color(o["mask_c"]).lerp(RED, 0.6) * (0.5 * (1.0 - kd))
	mask_m.albedo_color = Color(o["mask_c"]).lerp(Color("#55505A"), 0.88 * kd)
	(o["inner"] as StandardMaterial3D).albedo_color = Color(RED, 0.0)
	(o["mask"] as Node3D).scale = Vector3.ONE * MASK_S
	(o["crack"] as Node3D).scale = Vector3(1.0, maxf(0.01, _s(d, 0.0, 0.25)), 1.0)
	_rope_pose(o, SAG * kd, 0.0)
	if d > DONE_T:
		o["settled"] = true
	return cues


## Préchauffage (main._warmup) : un sanctuaire en pleine invocation (colonne, flamme, lueurs) et la fumée
## de l'extinction, pour que leurs matières soient compilées avant le premier défi.
static func warm(n: Node3D) -> void:
	var o := build(n, 1, 0.0)
	summon(o, 0.0)
	update(o, 0.8)
	(o["col"] as Node3D).visible = true
	_smoke(o["brazier"] as Node3D, Vector3(0, 0.3, 0))
