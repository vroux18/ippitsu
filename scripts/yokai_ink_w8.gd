extends RefCounted
## Yōkai d'encre du monde 8 (Yomi, cendre) : gaki, gokusotsu, shiryo.
## Règles de la direction « Masque d'encre » : en tête de yokai_ink_w1.gd. Constructeurs appelés par
## yokai_parts.ink_parts (table INK_WORLD_PATHS) ; rig et animation : ink_rig.gd.
## Étoffe du monde (design/PALETTES.md, Yomi) : violet des haies CLOTH + lilas des âmes WAVE en seigaiha, liseré
## d'os LINE ; cendre et os pour les parures, le lilas reste la seule couleur vive (feu froid du shiryō).
## Trois silhouettes : l'affamé fluet au ventre énorme, le geôlier massif à tête de bœuf et chaîne, la flamme
## d'âme qui flotte (gouttes remplacées par des flammes au-dessus de la tête et une traîne).

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")

const CLOTH := Color("#5A3A7A")  # violet des haies
const WAVE := Color("#B9A8E8")  # lilas des âmes
const LINE := Color("#D8D2C4")  # os
const ASH := Color("#6E6A70")
const BONE := Color("#D8D2C4")
const INK_YOMI := Color("#1C1626")  # encre violacée du feu d'âme
const INK_GAKI := Color("#2A2428")
const BELLY := Color("#8A8290")  # ventre de cendre gonflé
const MASK_GAKI := Color("#CFC9C4")
const EYE_GAKI := Color("#9AE070")  # lueur verte de la faim
const IRON := Color("#3A3C42")
const IRON_L := Color("#5A5C64")
const MASK_OX := Color("#8A7A6A")
const MUZZLE := Color("#5A4A42")
const SOUL := Color("#B9A8E8")
const SOUL_CORE := Color("#F0E8FF")
const MASK_SOUL := Color("#D9D0E6")


static func kinds() -> PackedStringArray:
	return PackedStringArray(["gaki", "gokusotsu", "shiryo"])


static func build(kind: String, d: Dictionary, lite: bool, elite: bool) -> void:
	match kind:
		"gaki":
			_gaki(d, lite, elite)
		"gokusotsu":
			_gokusotsu(d, lite, elite)
		"shiryo":
			_shiryo(d, lite, elite)


## Gaki : affamé fluet (corps étroit, bras maigres) au VENTRE ÉNORME de cendre sous l'obi, côtes saillantes ;
## masque gris décharné aux orbites creuses à lueur verte, bouche béante pleine de dents, mèches rares ;
## un os rongé à la main (il mord et se soigne).
static func _gaki(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.85, INK_GAKI, CLOTH, WAVE, LINE, lite, elite)
	# ventre : grosse boule de cendre qui déborde sous l'obi, nombril sumi
	b.ball(Vector3(0, 0.5, -0.1), Vector3(0.36, 0.3, 0.34), BELLY, Vector3.ZERO, 10)
	b.ball(Vector3(0, 0.46, -0.43), Vector3(0.03, 0.04, 0.015), Toon.SUMI, Vector3.ZERO, 6)
	if elite:
		b.cyl(Vector3(0, 0.44, -0.1), Vector3(0.365, 0.03, 0.345), Toon.GOLD, Vector3.ZERO, 1.0, 12)
	# côtes : trois arcs d'os sur la poitrine, de chaque côté
	var n := 2 if lite else 3
	for i in n:
		var y := 1.0 - 0.07 * float(i)
		for s in [-1.0, 1.0]:
			var x := float(s)
			b.box(Vector3(x * 0.14, y, -0.345 + 0.02 * float(i)), Vector3(0.2, 0.022, 0.02), BONE, Vector3(0, -x * 0.5, x * 0.3))
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_GAKI, 0.85, 1.0, elite)
	# joues creuses (ombres sumi), orbites creuses et lueur verte, bouche béante aux dents d'os
	for s in [-1.0, 1.0]:
		var x := float(s)
		a.ball(Vector3(x * 0.115, 0.06, Yokai.FACE_Z + 0.005), Vector3(0.075, 0.09, 0.025), Toon.SUMI, Vector3.ZERO, 8)
		f.ball(Vector3(x * 0.115, 0.05, Yokai.FACE_Z - 0.015), Vector3(0.028, 0.028, 0.01), EYE_GAKI, Vector3.ZERO, 6)
		a.box(Vector3(x * 0.17, -0.1, Yokai.FACE_Z + 0.01), Vector3(0.06, 0.12, 0.02), Color("#9A9290"), Vector3(0, 0, x * 0.2))
	a.ball(Vector3(0, -0.17, Yokai.FACE_Z), Vector3(0.11, 0.09, 0.02), Toon.SUMI, Vector3.ZERO, 8)
	var teeth := 3 if lite else 5
	for i in teeth:
		var x := -0.08 + 0.16 * float(i) / float(teeth - 1)
		a.spike(Vector3(x, -0.1, Yokai.FACE_Z - 0.01), 0.014, 0.05, BONE, Vector3(PI, 0, 0), 0.0, 4)
		a.spike(Vector3(x + 0.016, -0.24, Yokai.FACE_Z - 0.01), 0.012, 0.04, BONE, Vector3.ZERO, 0.0, 4)
	# mèches rares : quelques brins raides sur le crâne
	var m := 3 if lite else 5
	for i in m:
		var k := float(i) - float(m - 1) * 0.5
		a.stick(Vector3(k * 0.1, 0.3, Yokai.MASK_Z + 0.12 + 0.03 * absf(k)), Vector3(0.025, 0.24, 0.02), Yokai.HAIR, Vector3(-0.3 - 0.2 * absf(k), 0, -k * 0.5))
	if elite:
		a.cyl(Vector3(0, 0.3, Yokai.MASK_Z + 0.1), Vector3(0.2, 0.03, 0.2), Toon.GOLD, Vector3(0.2, 0, 0), 0.9, 10)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_GAKI, 0.75)
	Yokai.ink_drip(d, INK_GAKI)
	# os rongé (unités du monde, +Y vers le bout)
	var o := Yokai.Mesher.new(1.0)
	o.cyl(Vector3(0, 0.2, 0), Vector3(0.025, 0.36, 0.025), BONE, Vector3.ZERO, 1.0, 6)
	for y in [0.03, 0.38]:
		o.ball(Vector3(0.025, float(y), 0), Vector3.ONE * 0.045, BONE, Vector3.ZERO, 6)
		o.ball(Vector3(-0.025, float(y), 0), Vector3.ONE * 0.045, BONE, Vector3.ZERO, 6)
	d["weapon_r"] = o.mesh()


## Gokusotsu (gozu) : geôlier massif à TÊTE DE BŒUF : masque de fer gris au mufle, cornes horizontales, anneau
## d'or au nez, oreilles ; épaulières et plastron de fer rivetés ; chaîne et boulet en main droite basse.
static func _gokusotsu(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 1.3
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, Yokai.INK, CLOTH, WAVE, LINE, lite, elite)
	# épaulières de fer en plaques, plastron bombé riveté d'or
	for s in [-1.0, 1.0]:
		var x := float(s)
		b.box(Vector3(x * 0.48 * w, 1.1, 0), Vector3(0.26, 0.09, 0.34), IRON, Vector3(0, 0, -x * 0.4))
		b.box(Vector3(x * 0.52 * w, 1.0, 0), Vector3(0.2, 0.08, 0.3), IRON_L, Vector3(0, 0, -x * 0.7))
	b.ball(Vector3(0, 0.92, -0.26), Vector3(0.36, 0.26, 0.2), IRON, Vector3.ZERO, 10)
	if not lite:
		for p in [Vector3(-0.2, 1.02, -0.4), Vector3(0.2, 1.02, -0.4), Vector3(-0.2, 0.82, -0.42), Vector3(0.2, 0.82, -0.42)]:
			b.ball(p, Vector3.ONE * 0.035, Toon.GOLD, Vector3.ZERO, 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_OX, 1.2, 1.1, elite)
	# front de fer, sourcils froncés, yeux d'or ; mufle sombre en avant, naseaux, anneau d'or
	a.box(Vector3(0, 0.26, Yokai.FACE_Z + 0.02), Vector3(0.5, 0.1, 0.04), IRON)
	Yokai.mask_brows(a, Toon.SUMI, true, 1.2)
	Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.05, 1.2, 0.07)
	a.ball(Vector3(0, -0.14, Yokai.FACE_Z - 0.06), Vector3(0.22, 0.16, 0.14), MUZZLE, Vector3.ZERO, 8)
	for s in [-1.0, 1.0]:
		a.ball(Vector3(float(s) * 0.08, -0.11, Yokai.FACE_Z - 0.19), Vector3(0.03, 0.025, 0.015), Toon.SUMI, Vector3.ZERO, 6)
	a.cyl(Vector3(0, -0.22, Yokai.FACE_Z - 0.17), Vector3(0.06, 0.02, 0.06), Toon.GOLD, Vector3(PI / 2.0 + 0.3, 0, 0), 1.0, 8)
	# cornes à l'horizontale (un peu relevées, pointes en avant), oreilles tombantes
	for s in [-1.0, 1.0]:
		var x := float(s)
		var tip := a.spike(Vector3(x * 0.3, 0.2, Yokai.MASK_Z + 0.08), 0.075, 0.42, Yokai.HORN, Vector3(0.5, 0, -x * 1.3), 0.3, 6)
		a.spike(tip, 0.03, 0.14, Toon.GOLD if elite else Yokai.HORN, Vector3(0.9, 0, -x * 0.7), 0.0, 5)
		a.ball(Vector3(x * 0.3, 0.02, Yokai.MASK_Z + 0.14), Vector3(0.07, 0.13, 0.04), MUZZLE, Vector3(0, 0, -x * 0.5), 6)
	if elite:
		a.cyl(Vector3(0, 0.33, Yokai.MASK_Z + 0.05), Vector3(0.12, 0.05, 0.08), Toon.GOLD, Vector3(0.2, 0, 0), 0.6, 6)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK, 1.25)
	Yokai.ink_drip(d, Yokai.INK)
	d["weapon_r"] = _chain(lite)


## Chaîne de fer et boulet (unités du monde, +Y vers le bout) : moins de triangles que Yokai.weapon("chain").
static func _chain(lite: bool) -> ArrayMesh:
	var m := Yokai.Mesher.new(1.0)
	var n := 3 if lite else 4
	for i in n:
		m.ball(Vector3(0, 0.1 + 0.1 * float(i), 0), Vector3(0.035, 0.05, 0.035), IRON_L, Vector3(0, 0, PI / 2.0 if i % 2 == 0 else 0.0), 6)
	m.ball(Vector3(0, 0.62, 0), Vector3.ONE * 0.17, IRON, Vector3.ZERO, 8)
	if not lite:
		for k in 4:
			var ang := TAU * float(k) / 4.0 + 0.4
			m.spike(Vector3(sin(ang) * 0.14, 0.62, cos(ang) * 0.14), 0.035, 0.1, IRON_L, Vector3(0, ang, -PI / 2.0), 0.0, 4)
	return m.mesh()


## Shiryō : feu d'âme : encre violacée, masque lilas pâle sans sourcils, yeux creux en larmes, petite bouche
## ouverte ; les gouttes sont des FLAMMES de feu froid : trois au-dessus de la tête, une longue traîne derrière
## (elles s'étirent au rythme des gouttes). Il flotte (enemy.gd lève le corps) et luit en lilas.
static func _shiryo(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	var bf := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.9, INK_YOMI, CLOTH, WAVE, Toon.GOLD if elite else SOUL, lite, elite)
	# la traîne : longue flamme couchée vers l'arrière, cœur pâle
	b.spike(Vector3(0, 0.78, 0.3), 0.17, 0.8, SOUL, Vector3(1.25, 0, 0), 0.0, 6)
	bf.spike(Vector3(0, 0.8, 0.34), 0.08, 0.5, SOUL_CORE, Vector3(1.25, 0, 0), 0.0, 5)
	if not lite:
		b.spike(Vector3(0.14, 0.7, 0.28), 0.08, 0.45, SOUL, Vector3(1.1, 0, -0.35), 0.0, 5)
		b.spike(Vector3(-0.14, 0.7, 0.28), 0.08, 0.45, SOUL, Vector3(1.1, 0, 0.35), 0.0, 5)
	d["body"] = Yokai.two(b, bf)
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_SOUL, 0.9, 1.0, elite)
	# yeux creux en larmes (goutte sumi, pointe en haut), iris lilas ; bouche ouverte en « o »
	for s in [-1.0, 1.0]:
		var x := float(s) * 0.105
		a.ball(Vector3(x, 0.05, Yokai.FACE_Z + 0.005), Vector3(0.065, 0.075, 0.02), Toon.SUMI, Vector3.ZERO, 8)
		a.spike(Vector3(x, 0.1, Yokai.FACE_Z + 0.002), 0.05, 0.12, Toon.SUMI, Vector3.ZERO, 0.0, 5, 0.3)
		f.ball(Vector3(x, 0.035, Yokai.FACE_Z - 0.012), Vector3(0.028, 0.03, 0.01), SOUL, Vector3.ZERO, 6)
	a.ball(Vector3(0, -0.15, Yokai.FACE_Z), Vector3(0.045, 0.06, 0.02), Toon.SUMI, Vector3.ZERO, 8)
	# couronne de feu : anneau lilas au sommet (les flammes articulées viennent des gouttes)
	a.cyl(Vector3(0, 0.3, Yokai.MASK_Z + 0.2), Vector3(0.22, 0.04, 0.2), Toon.GOLD if elite else SOUL, Vector3(0.1, 0, 0), 0.85, 10)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_YOMI, 0.9)
	# flamme : pointe vers +Y (lilas) au cœur pâle (aplat), base d'encre
	var t := Yokai.Mesher.new(1.0)
	var c := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.1, 0.07, 0.1), INK_YOMI, Vector3.ZERO, 6)
	t.spike(Vector3(0, 0.0, 0), 0.13, 0.62, SOUL, Vector3.ZERO, 0.0, 6)
	c.spike(Vector3(0, 0.03, 0), 0.065, 0.38, SOUL_CORE, Vector3.ZERO, 0.0, 5)
	d["drip"] = Yokai.two(t, c)
	# flammes au-dessus de la tête (une grande au centre, deux penchées vers l'extérieur par spread)
	var pts := PackedVector3Array([Vector3(0, 1.48, 0.0), Vector3(-0.2, 1.4, 0.08), Vector3(0.2, 1.4, 0.08)])
	if lite:
		pts = PackedVector3Array([Vector3(0, 1.48, 0.0), Vector3(0.16, 1.4, 0.1)])
	d["drips"] = pts
	d["spread"] = 0.45
