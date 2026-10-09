extends RefCounted
## Yōkai d'encre du monde 7 (Ryūgū-jō, fond marin) : kani, ningyo, fugu.
## Règles de la direction « Masque d'encre » : en tête de yokai_ink_w1.gd. Constructeurs appelés par
## yokai_parts.ink_parts (table INK_WORLD_PATHS) ; rig et animation : ink_rig.gd.
## Étoffe du monde (design/PALETTES.md, Ryūgū-jō) : turquoise profond CLOTH + écume turquoise WAVE en seigaiha,
## liseré corail LINE ; nacre et perle pour les parures (le vermillon reste au palais du fond).
## Trois silhouettes : le crabe bas et large coiffé d'une carapace-visage tournée vers la caméra, la sirène
## élancée à queue de poisson, le poisson-globe rond et hérissé (son corps gonfle, enemy.gd met à l'échelle).

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")

const CLOTH := Color("#145060")  # turquoise profond
const WAVE := Color("#9EE0DA")  # écume turquoise
const LINE := Color("#C86E7E")  # corail rose
const NACRE := Color("#E7D9C8")
const PEARL := Color("#F4F1EA")
const SHELL := Color("#6E2A28")  # laque sombre de la carapace
const SHELL_L := Color("#8E3A34")
const CLAW := Color("#4A1E1C")
const SCALE := Color("#3E8E8A")  # écailles de la sirène
const SCALE_L := Color("#7FC9C0")
const HAIR := Color("#1E1B22")
const INK_FUGU := Color("#2A2820")
const BELLY := Color("#E0C27A")  # sable
const SPINE := Color("#4A3E2A")
const FIN := Color("#B8952E")
const MASK_FUGU := Color("#EAD9A8")
const MASK_NINGYO := Color("#F2EFE8")


static func kinds() -> PackedStringArray:
	return PackedStringArray(["kani", "ningyo", "fugu"])


static func build(kind: String, d: Dictionary, lite: bool, elite: bool) -> void:
	match kind:
		"kani":
			_kani(d, lite, elite)
		"ningyo":
			_ningyo(d, lite, elite)
		"fugu":
			_fugu(d, lite, elite)


## Heikegani : corps bas et large ; la CARAPACE coiffe la tête, et son dessus porte le visage du samouraï noyé
## (sourcils froncés, yeux, moustache tombante) tourné vers la caméra plongeante. Devant : deux yeux pédonculés.
## Les deux bras sont des pinces ; il garde de face (comme le porte-bouclier).
static func _kani(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 1.3
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, Yokai.INK, CLOTH, WAVE, LINE, lite, elite)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	# carapace : large dôme laqué posé sur la tête, bord relevé en pointes
	var cc := Vector3(0, 0.2, -0.06)
	a.ball(cc, Vector3(0.66, 0.18, 0.54), SHELL, Vector3.ZERO, 10)
	a.ball(cc + Vector3(0, 0.02, 0), Vector3(0.54, 0.18, 0.45), SHELL_L, Vector3.ZERO, 10)
	if elite:
		a.ball(cc + Vector3(0, -0.02, 0), Vector3(0.69, 0.15, 0.57), Toon.GOLD, Vector3.ZERO, 10)
	var n := 4 if lite else 8
	for i in n:
		var ang := TAU * (float(i) + 0.5) / float(n)
		a.spike(Vector3(sin(ang) * 0.62, 0.2, cc.z + cos(ang) * 0.5), 0.05, 0.14, SHELL, Vector3(0, ang, -1.35), 0.0, 4)
	# le visage du samouraï sur le dessus (normale +Y) : front, sourcils, yeux d'or, nez, moustache, bouche
	var top := cc.y + 0.19
	for s in [-1.0, 1.0]:
		var x := float(s)
		a.box(Vector3(x * 0.19, top, cc.z - 0.14), Vector3(0.26, 0.03, 0.07), Toon.SUMI, Vector3(0, -x * 0.4, 0))
		f.ball(Vector3(x * 0.19, top, cc.z - 0.02), Vector3(0.09, 0.014, 0.065), Yokai.EYE_GOLD, Vector3.ZERO, 8)
		f.ball(Vector3(x * 0.19, top + 0.008, cc.z - 0.02), Vector3(0.035, 0.012, 0.04), Toon.SUMI, Vector3.ZERO, 6)
		a.box(Vector3(x * 0.18, top, cc.z + 0.2), Vector3(0.26, 0.03, 0.05), Toon.SUMI, Vector3(0, x * 0.55, 0))
	a.box(Vector3(0, top, cc.z + 0.08), Vector3(0.06, 0.03, 0.18), Toon.SUMI)
	a.box(Vector3(0, top, cc.z + 0.31), Vector3(0.22, 0.03, 0.04), Toon.SUMI)
	# devant : deux yeux pédonculés noirs qui pointent vers l'avant et le haut
	for s in [-1.0, 1.0]:
		var x := float(s) * 0.17
		var tip := a.spike(Vector3(x, 0.05, Yokai.MASK_Z - 0.02), 0.03, 0.2, CLAW, Vector3(-1.0, 0, 0), 0.8, 5)
		a.ball(tip, Vector3(0.055, 0.055, 0.055), Toon.SUMI, Vector3.ZERO, 6)
		f.ball(tip + Vector3(0, 0.0, -0.045), Vector3(0.02, 0.02, 0.015), Toon.WASHI, Vector3.ZERO, 6)
	# plaque buccale : petite grille sumi sous la carapace, bouche du crabe
	a.box(Vector3(0, -0.1, Yokai.MASK_Z - 0.06), Vector3(0.26, 0.09, 0.05), CLAW)
	for i in 3:
		a.box(Vector3(-0.08 + 0.08 * float(i), -0.1, Yokai.MASK_Z - 0.09), Vector3(0.02, 0.07, 0.01), NACRE)
	d["head"] = Yokai.two(a, f)
	# bras-pince : bras d'encre court, grosse pince laquée aux deux doigts (fixe et mobile)
	var p := Yokai.Mesher.new(1.0)
	p.cyl(Vector3(0, -0.14, 0), Vector3(0.1, 0.28, 0.1), Yokai.INK, Vector3(PI, 0, 0), 0.7, 7)
	p.ball(Vector3(0, -0.36, 0), Vector3(0.21, 0.24, 0.17), SHELL, Vector3.ZERO, 8)
	p.spike(Vector3(0.09, -0.48, 0), 0.09, 0.34, SHELL_L, Vector3(PI, 0, -0.25), 0.0, 5, 0.8)
	p.spike(Vector3(-0.09, -0.48, 0), 0.07, 0.28, SHELL_L, Vector3(PI, 0, 0.4), 0.0, 5, 0.8)
	if elite:
		p.cyl(Vector3(0, -0.2, 0), Vector3(0.105, 0.04, 0.105), Toon.GOLD, Vector3.ZERO, 1.0, 8)
	d["arm"] = p.mesh()
	# pattes : gouttes d'encre courtes et nombreuses, penchées vers l'extérieur
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.05, 0.06, 0.05), Yokai.INK, Vector3.ZERO, 6)
	t.spike(Vector3.ZERO, 0.045, 0.2, Yokai.INK, Vector3(PI, 0, 0), 0.2, 5)
	d["drip"] = t.mesh()
	var pts := PackedVector3Array()
	var m := 4 if lite else 6
	for i in m:
		var ang := TAU * (float(i) + 0.5) / float(m)
		pts.append(Vector3(sin(ang) * 0.3 * w, 0.42, cos(ang) * 0.2))
	d["drips"] = pts
	d["spread"] = 0.6


## Ningyo : sirène élancée, masque de nacre aux yeux turquoise mi-clos et petite bouche corail, nageoires aux
## oreilles, longue chevelure noire au peigne de perle, collier de perles ; écailles turquoise sur le corps ;
## la QUEUE DE POISSON remplace les gouttes (une seule, penchée en arrière). Bras levé : tireuse de jet d'eau
## (la perle d'eau vient d'enemy.gd).
static func _ningyo(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.92, Yokai.INK_SEA, CLOTH, WAVE, Toon.GOLD if elite else PEARL, lite, elite)
	# écailles turquoise sous l'obi (le bas du corps est déjà poisson)
	var n := 6 if lite else 8
	for i in n:
		var ang := TAU * (float(i) + 0.5) / float(n)
		b.ball(Vector3(sin(ang) * 0.3, 0.55, cos(ang) * 0.285), Vector3(0.075, 0.055, 0.02), SCALE_L if i % 2 == 0 else SCALE, Vector3(0, ang, 0), 6)
	# collier de perles sur la poitrine
	var np := 4 if lite else 5
	for i in np:
		var ang := -0.9 + 1.8 * float(i) / float(np - 1)
		b.ball(Vector3(sin(ang) * 0.3, 1.02 - 0.08 * cos(ang), -0.3 - 0.12 * cos(ang)), Vector3.ONE * 0.035, PEARL, Vector3.ZERO, 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_NINGYO, 0.88, 0.95, elite)
	Yokai.mask_brows(a, Toon.SUMI, false, 0.88)
	# yeux mi-clos : trait sumi et éclat turquoise dessous
	for s in [-1.0, 1.0]:
		var x := float(s) * 0.1
		a.box(Vector3(x, 0.07, Yokai.FACE_Z), Vector3(0.09, 0.022, 0.015), Toon.SUMI)
		f.ball(Vector3(x, 0.05, Yokai.FACE_Z - 0.01), Vector3(0.035, 0.02, 0.01), Yokai.EYE_SEA, Vector3.ZERO, 6)
	a.box(Vector3(0, -0.12, Yokai.FACE_Z), Vector3(0.07, 0.03, 0.02), LINE)
	# nageoires aux oreilles : éventails translucides turquoise, pointés vers l'extérieur et l'arrière
	for s in [-1.0, 1.0]:
		var x := float(s)
		a.spike(Vector3(x * 0.27, 0.02, Yokai.MASK_Z + 0.08), 0.12, 0.26, SCALE_L, Vector3(0, 0, -x * 1.35), 0.0, 3, 0.25)
		a.spike(Vector3(x * 0.27, -0.04, Yokai.MASK_Z + 0.1), 0.08, 0.18, SCALE, Vector3(0, 0, -x * 1.7), 0.0, 3, 0.25)
	# chevelure : calotte lisse, longue nappe dans le dos, deux mèches devant les épaules ; peigne de perle
	a.ball(Vector3(0, 0.22, Yokai.MASK_Z + 0.22), Vector3(0.34, 0.2, 0.32), HAIR, Vector3.ZERO, 8)
	a.stick(Vector3(0, 0.2, 0.2), Vector3(0.4, 0.8, 0.1), HAIR, Vector3(PI - 0.1, 0, 0))
	for s in [-1.0, 1.0]:
		var x := float(s)
		a.stick(Vector3(x * 0.26, 0.1, -0.22), Vector3(0.08, 0.5, 0.06), HAIR, Vector3(PI, 0, -x * 0.12))
	a.box(Vector3(0.15, 0.38, Yokai.MASK_Z + 0.12), Vector3(0.16, 0.03, 0.05), Toon.GOLD if elite else NACRE, Vector3(0, 0, 0.35))
	for i in 3:
		a.ball(Vector3(0.09 + 0.055 * float(i), 0.4 + 0.02 * float(i), Yokai.MASK_Z + 0.1), Vector3.ONE * 0.028, PEARL, Vector3.ZERO, 6)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK_SEA, 0.9)
	# queue de poisson : fuseau d'écailles qui descend, nageoire caudale à deux lobes
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.14, 0.1, 0.12), Yokai.INK_SEA, Vector3.ZERO, 8)
	t.cyl(Vector3(0, -0.2, 0), Vector3(0.13, 0.42, 0.11), SCALE, Vector3(PI, 0, 0), 0.45, 8)
	if not lite:
		for i in 2:
			var y := -0.08 - 0.12 * float(i)
			var r := 0.12 - 0.03 * float(i)
			for k in 3:
				var ang := TAU * (float(k) + 0.5 * float(i)) / 3.0 + PI
				t.ball(Vector3(sin(ang) * r, y, cos(ang) * r * 0.85), Vector3(0.05, 0.04, 0.015), SCALE_L, Vector3(0, ang, 0), 6)
	for s in [-1.0, 1.0]:
		t.spike(Vector3(0, -0.4, 0), 0.13, 0.3, SCALE_L, Vector3(PI, 0, float(s) * 0.55), 0.0, 3, 0.2)
	d["drip"] = t.mesh()
	d["drips"] = PackedVector3Array([Vector3(0, 0.44, 0.1)])
	d["spread"] = 0.55


## Fugu : poisson-globe rond et large, ventre de sable pâle, hérissé d'ÉPINES sur le dos et le dessus de la tête ;
## masque rond aux gros yeux et à la bouche en « o » boudeuse ; nageoires jaunes en guise de bras, nageoire
## caudale à la place des gouttes. Il gonfle avant de frapper autour de lui (enemy.gd met le corps à l'échelle).
static func _fugu(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 1.3
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, INK_FUGU, CLOTH, WAVE, LINE, lite, elite)
	# ventre pâle : grosse bosse de sable devant le torse, tachetée
	b.ball(Vector3(0, 0.8, -0.2), Vector3(0.42, 0.34, 0.3), BELLY, Vector3.ZERO, 10)
	if not lite:
		for p in [Vector3(-0.18, 0.95, -0.42), Vector3(0.2, 0.9, -0.42), Vector3(0.0, 0.72, -0.46), Vector3(-0.25, 0.7, -0.38)]:
			b.ball(p, Vector3(0.05, 0.04, 0.015), Color("#B89A5A"), Vector3.ZERO, 6)
	# épines : couronne sur les épaules et le dos
	var n := 6 if lite else 10
	for i in n:
		var ang := PI * 0.25 + PI * 1.5 * float(i) / float(n - 1)
		b.spike(Vector3(sin(ang) * 0.5 * w, 1.05, cos(ang) * 0.46 * w), 0.04, 0.2, SPINE, Vector3(0, ang, -1.2), 0.0, 4)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_FUGU, 1.15, 0.9, elite)
	# gros yeux ronds écartés (blanc, iris d'or, pupille), bouche en « o » cernée de corail
	for s in [-1.0, 1.0]:
		var x := float(s) * 0.17
		a.ball(Vector3(x, 0.06, Yokai.FACE_Z + 0.01), Vector3(0.095, 0.095, 0.03), Toon.WASHI, Vector3.ZERO, 8)
		f.ball(Vector3(x, 0.06, Yokai.FACE_Z - 0.015), Vector3(0.065, 0.065, 0.015), Yokai.EYE_GOLD, Vector3.ZERO, 8)
		f.ball(Vector3(x, 0.055, Yokai.FACE_Z - 0.027), Vector3(0.03, 0.03, 0.01), Toon.SUMI, Vector3.ZERO, 6)
	a.cyl(Vector3(0, -0.12, Yokai.FACE_Z), Vector3(0.08, 0.03, 0.08), LINE, Vector3(PI / 2.0, 0, 0), 1.0, 10)
	a.cyl(Vector3(0, -0.12, Yokai.FACE_Z - 0.005), Vector3(0.05, 0.03, 0.05), Toon.SUMI, Vector3(PI / 2.0, 0, 0), 1.0, 8)
	# épines sur le dessus de la tête (vues d'en haut), nageoire dorsale en arrière
	var m := 3 if lite else 5
	for i in m:
		var ang := -0.9 + 1.8 * float(i) / float(m - 1)
		a.spike(Vector3(sin(ang) * 0.3, 0.26, Yokai.MASK_Z + 0.2 + cos(ang) * 0.12), 0.04, 0.2, SPINE, Vector3(-0.3 * cos(ang), 0, -ang * 0.8), 0.0, 4)
	a.spike(Vector3(0, 0.2, 0.26), 0.14, 0.3, Toon.GOLD if elite else FIN, Vector3(0.9, 0, 0), 0.0, 3, 0.2)
	d["head"] = Yokai.two(a, f)
	# nageoires en guise de bras : court bras d'encre, palette jaune plate
	var p := Yokai.Mesher.new(1.0)
	p.cyl(Vector3(0, -0.1, 0), Vector3(0.09, 0.2, 0.09), INK_FUGU, Vector3(PI, 0, 0), 0.8, 6)
	p.spike(Vector3(0, -0.16, 0), 0.18, 0.38, FIN, Vector3(PI, 0, 0), 0.0, 4, 0.2)
	p.box(Vector3(0, -0.33, 0), Vector3(0.012, 0.28, 0.03), Color("#8E7222"))
	d["arm"] = p.mesh()
	# nageoire caudale à la place des gouttes (derrière, penchée en arrière)
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.08, 0.06, 0.08), INK_FUGU, Vector3.ZERO, 6)
	t.cyl(Vector3(0, -0.1, 0), Vector3(0.07, 0.2, 0.07), INK_FUGU, Vector3(PI, 0, 0), 0.6, 6)
	for s in [-1.0, 1.0]:
		t.spike(Vector3(0, -0.2, 0), 0.1, 0.26, FIN, Vector3(PI, 0, float(s) * 0.5), 0.0, 3, 0.2)
	d["drip"] = t.mesh()
	d["drips"] = PackedVector3Array([Vector3(0, 0.46, 0.34)])
	d["spread"] = 0.8
