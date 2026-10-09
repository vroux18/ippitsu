extends RefCounted
## Yōkai d'encre du monde 6 (Kurama, montagne des tengu) : karasu, yamabushi, konoha.
## Règles de la direction « Masque d'encre » : en tête de yokai_ink_w1.gd. Constructeurs appelés par
## yokai_parts.ink_parts (table INK_WORLD_PATHS) ; rig et animation : ink_rig.gd.
## Étoffe du monde (design/PALETTES.md, Kurama) : cèdre CLOTH + écume du ravin WAVE en seigaiha, liseré braise LINE
## (le vermillon reste au temple du fond). Les trois tengu partagent la famille (bec ou long nez, tokin) mais pas
## la silhouette : le karasu est un corbeau aux ailes déployées (ses bras), le yamabushi un grand ascète au long
## nez et à l'éventail levé, le konoha un petit à grande feuille sur la tête et feuilles en gouttes.

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")

const CLOTH := Color("#2E4A34")  # cèdre
const WAVE := Color("#9CB08E")  # écume du ravin
const LINE := Color("#8E2A1E")  # braise (liseré, tokin)
const INK_CROW := Color("#17171E")  # encre bleu-noir du corbeau
const FEATHER := Color("#24232C")
const TENGU_RED := Color("#A8382A")  # masque de tengu : entre braise et masque d'oni
const MANE := Color("#EFE6D2")
const TOKIN := Color("#2A2630")
const LEAF := Color("#4F6E3E")  # fougère
const LEAF_D := Color("#3A5A40")
const LEAF_VEIN := Color("#C9C25A")
const MASK_KONOHA := Color("#8FB07A")


static func kinds() -> PackedStringArray:
	return PackedStringArray(["karasu", "yamabushi", "konoha"])


static func build(kind: String, d: Dictionary, lite: bool, elite: bool) -> void:
	match kind:
		"karasu":
			_karasu(d, lite, elite)
		"yamabushi":
			_yamabushi(d, lite, elite)
		"konoha":
			_konoha(d, lite, elite)


## Karasu-tengu : corbeau d'encre bleu-noir, bec d'or, yeux d'or ronds, tokin braise, crête de plumes ; les BRAS
## sont des ailes déployées (REST_ARMS les ouvre à l'horizontale), les gouttes sont les plumes de la queue.
## Il vole (enemy.gd lève le corps) et plonge en piqué : la silhouette en croix se lit du dessus.
static func _karasu(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.9, INK_CROW, CLOTH, WAVE, LINE, lite, elite)
	# jabot : plumes du poitrail en pointe sous le masque
	b.spike(Vector3(0, 0.98, -0.3), 0.14, 0.26, FEATHER, Vector3(PI + 0.35, 0, 0), 0.0, 5, 0.4)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, FEATHER, 0.95, 0.95, elite)
	# yeux d'or ronds et fixes, cernés de washi (regard d'oiseau)
	for s in [-1.0, 1.0]:
		var x := float(s) * 0.12
		a.ball(Vector3(x, 0.07, Yokai.FACE_Z + 0.01), Vector3(0.075, 0.075, 0.02), Toon.WASHI, Vector3.ZERO, 8)
		f.ball(Vector3(x, 0.07, Yokai.FACE_Z - 0.005), Vector3(0.055, 0.055, 0.015), Yokai.EYE_GOLD, Vector3.ZERO, 8)
		f.ball(Vector3(x, 0.07, Yokai.FACE_Z - 0.017), Vector3(0.022, 0.022, 0.01), Toon.SUMI, Vector3.ZERO, 6)
	# grand bec d'or, un peu baissé, arête sumi
	a.spike(Vector3(0, -0.04, Yokai.FACE_Z + 0.02), 0.1, 0.42, Toon.GOLD, Vector3(-PI / 2.0 - 0.3, 0, 0), 0.0, 5, 0.7)
	a.box(Vector3(0, -0.05, Yokai.FACE_Z - 0.14), Vector3(0.15, 0.012, 0.24), Toon.SUMI, Vector3(0.3, 0, 0))
	# tokin : petit bonnet braise à cordon d'or, posé sur le front ; crête de trois plumes en arrière
	a.cyl(Vector3(0, 0.3, Yokai.MASK_Z + 0.1), Vector3(0.1, 0.13, 0.1), LINE, Vector3(0.2, 0, 0), 0.55, 6)
	a.cyl(Vector3(0, 0.245, Yokai.MASK_Z + 0.1), Vector3(0.115, 0.025, 0.115), Toon.GOLD if elite else TOKIN, Vector3(0.2, 0, 0), 1.0, 8)
	var n := 2 if lite else 3
	for i in n:
		var k := float(i) - float(n - 1) * 0.5
		a.stick(Vector3(k * 0.1, 0.22, Yokai.MASK_Z + 0.3), Vector3(0.05, 0.32, 0.03), FEATHER, Vector3(0.9, 0, -k * 0.35))
	if elite:
		a.stick(Vector3(0, 0.3, Yokai.MASK_Z + 0.26), Vector3(0.04, 0.3, 0.025), Toon.GOLD, Vector3(0.7, 0, 0))
	d["head"] = Yokai.two(a, f)
	# aile (bras) : vole le long de -Y depuis l'épaule, large dans le plan YZ (horizontale une fois ouverte)
	var w := Yokai.Mesher.new(1.0)
	w.cyl(Vector3(0, -0.25, 0), Vector3(0.07, 0.5, 0.1), INK_CROW, Vector3(PI, 0, 0), 0.75, 6)
	w.box(Vector3(0, -0.4, 0.02), Vector3(0.045, 0.64, 0.32), FEATHER, Vector3(0.1, 0, 0))
	var pens := 3 if lite else 5
	for i in pens:
		var k := float(i) / float(pens - 1) - 0.5  # -0.5..0.5
		var ln := 0.4 - 0.1 * absf(k)
		w.stick(Vector3(0, -0.68, 0.02 + k * 0.28), Vector3(0.035, ln, 0.08), FEATHER, Vector3(PI - k * 0.9, 0, 0))
	if elite:
		w.box(Vector3(0, -0.68, 0.02), Vector3(0.05, 0.03, 0.32), Toon.GOLD, Vector3(0.1, 0, 0))
	d["arm"] = w.mesh()
	# queue : trois plumes à la place des gouttes, penchées vers l'arrière (spread)
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.06, 0.05, 0.06), INK_CROW, Vector3.ZERO, 6)
	t.stick(Vector3.ZERO, Vector3(0.07, 0.38, 0.035), FEATHER, Vector3(PI, 0, 0))
	d["drip"] = t.mesh()
	d["drips"] = PackedVector3Array([Vector3(0, 0.42, 0.3), Vector3(-0.12, 0.44, 0.26), Vector3(0.12, 0.44, 0.26)])
	d["spread"] = 0.7


## Yamabushi-tengu : grand ascète au masque rouge à LONG NEZ, sourcils et crinière blancs, tokin noir sur le
## front, pompons du yuigesa sur la poitrine ; éventail de plumes levé (tireur de rafale).
static func _yamabushi(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 1.05, Yokai.INK, CLOTH, WAVE, LINE, lite, elite)
	# yuigesa : deux cordons croisés sur la poitrine et leurs pompons (or pour l'élite)
	var pom := Toon.GOLD if elite else MANE
	for s in [-1.0, 1.0]:
		var x := float(s)
		b.box(Vector3(x * 0.1, 0.9, -0.39), Vector3(0.04, 0.42, 0.02), TOKIN, Vector3(0.12, 0, x * 0.42))
		b.ball(Vector3(x * 0.2, 1.0, -0.37), Vector3(0.065, 0.065, 0.045), pom, Vector3.ZERO, 6)
		if not lite:
			b.ball(Vector3(x * 0.12, 0.78, -0.4), Vector3(0.06, 0.06, 0.04), pom, Vector3.ZERO, 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, TENGU_RED, 1.0, 1.05, elite)
	# sourcils blancs épais et froncés, yeux d'or
	for s in [-1.0, 1.0]:
		var x := float(s)
		a.box(Vector3(x * 0.12, 0.16, Yokai.FACE_Z), Vector3(0.18, 0.05, 0.025), MANE, Vector3(0, 0, x * 0.35))
	Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.05)
	# le long nez : fuseau rouge sombre qui part du milieu du masque, un peu baissé
	var nose := a.spike(Vector3(0, 0.02, Yokai.FACE_Z + 0.02), 0.075, 0.5, Color("#8E2A1E"), Vector3(-PI / 2.0 - 0.65, 0, 0), 0.4, 6)
	a.ball(nose, Vector3(0.04, 0.04, 0.04), Color("#8E2A1E"), Vector3.ZERO, 6)
	# bouche serrée, moustache blanche tombante
	a.box(Vector3(0, -0.16, Yokai.FACE_Z), Vector3(0.14, 0.03, 0.02), Toon.SUMI)
	for s in [-1.0, 1.0]:
		var x := float(s)
		a.stick(Vector3(x * 0.07, -0.12, Yokai.FACE_Z), Vector3(0.035, 0.2, 0.02), MANE, Vector3(0, 0, x * 2.6))
	# crinière blanche : calotte derrière le masque, longues mèches sur les côtés
	a.ball(Vector3(0, 0.22, Yokai.MASK_Z + 0.2), Vector3(0.36, 0.17, 0.3), MANE, Vector3.ZERO, 8)
	for s in [-1.0, 1.0]:
		var x := float(s)
		a.stick(Vector3(x * 0.3, 0.14, -0.2), Vector3(0.09, 0.55, 0.07), MANE, Vector3(PI, 0, -x * 0.1))
	if not lite:
		a.stick(Vector3(0, 0.2, 0.18), Vector3(0.12, 0.5, 0.06), MANE, Vector3(PI - 0.3, 0, 0))
	# tokin : petite boîte noire à pans sur le front, cordon d'or
	a.cyl(Vector3(0, 0.4, Yokai.MASK_Z + 0.09), Vector3(0.11, 0.14, 0.09), TOKIN, Vector3(0.25, 0, 0), 0.7, 6)
	a.cyl(Vector3(0, 0.335, Yokai.MASK_Z + 0.09), Vector3(0.125, 0.025, 0.105), Toon.GOLD, Vector3(0.25, 0, 0), 1.0, 8)
	if elite:
		a.spike(Vector3(0, 0.46, Yokai.MASK_Z + 0.1), 0.035, 0.14, Toon.GOLD, Vector3(0.1, 0, 0), 0.0, 4)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK)
	Yokai.ink_drip(d, Yokai.INK)
	d["weapon_r"] = _fan(lite, elite)


## Hauchiwa (unités du monde, +Y vers le bout) : manche, puis les plumes rayonnent dans le plan perpendiculaire au
## bras (« tournesol ») : bras levé, l'éventail fait face à la caméra plongeante au lieu de se voir par la tranche.
static func _fan(lite: bool, elite: bool) -> ArrayMesh:
	var m := Yokai.Mesher.new(1.0)
	m.cyl(Vector3(0, 0.12, 0), Vector3(0.022, 0.3, 0.022), Color("#3B2E25"), Vector3.ZERO, 1.0, 6)
	m.ball(Vector3(0, 0.3, 0), Vector3.ONE * 0.05, Toon.GOLD if elite else LINE, Vector3.ZERO, 6)
	var n := 5 if lite else 8
	for i in n:
		var ang := deg_to_rad(-120.0 + 240.0 * float(i) / float(n - 1))
		var dir := Vector3(sin(ang), 0, -cos(ang))
		m.ray(Vector3(0, 0.3, 0), dir, 0.075, 0.36, Color("#4A4650"), 0.45, 4)
		m.ray(Vector3(0, 0.305, 0) + dir * 0.24, dir, 0.045, 0.14, MANE, 0.2, 4)
	return m.mesh()


## Konoha-tengu : petit, masque vert au bec jaune et aux yeux ronds, GRANDE FEUILLE en chapeau (nervure claire),
## gouttes remplacées par des feuilles qui tournoient sous lui ; il lance des feuilles (bras libres).
static func _konoha(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.95, Yokai.INK, CLOTH, WAVE, LINE, lite, elite)
	# collerette de feuilles aux épaules
	var n := 4 if lite else 6
	for i in n:
		var ang := TAU * (float(i) + 0.5) / float(n)
		b.spike(Vector3(sin(ang) * 0.3, 1.06, cos(ang) * 0.28), 0.07, 0.24, LEAF_D, Vector3(0, ang, -1.1), 0.0, 4, 0.3)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_KONOHA, 0.9, 0.9, elite)
	Yokai.mask_brows(a, Toon.SUMI, true, 0.9)
	# yeux ronds d'oiseau (grands, clairs), petit bec jaune pointé vers le bas
	for s in [-1.0, 1.0]:
		var x := float(s) * 0.1
		f.ball(Vector3(x, 0.05, Yokai.FACE_Z), Vector3(0.06, 0.065, 0.015), Yokai.EYE_GOLD, Vector3.ZERO, 8)
		f.ball(Vector3(x, 0.045, Yokai.FACE_Z - 0.012), Vector3(0.028, 0.03, 0.01), Toon.SUMI, Vector3.ZERO, 6)
	a.spike(Vector3(0, -0.08, Yokai.FACE_Z + 0.01), 0.055, 0.16, Yokai.BEAK, Vector3(-PI / 2.0 - 0.5, 0, 0), 0.0, 4, 0.6)
	# la grande feuille : limbe plat (ovale + pointe devant), nervure centrale, tige en arrière ; penchée
	var lr := Vector3(0.22, 0, 0.2)
	var lc := Vector3(0, 0.37, Yokai.MASK_Z + 0.14)
	a.ball(lc, Vector3(0.42, 0.028, 0.34), LEAF, lr, 10)
	a.spike(lc + Vector3(0, -0.06, -0.3), 0.22, 0.4, LEAF, Vector3(-PI / 2.0 - 0.22, 0, 0), 0.0, 4, 0.12)
	a.box(lc + Vector3(0, 0.02, -0.02), Vector3(0.025, 0.012, 0.7), Toon.GOLD if elite else LEAF_VEIN, lr)
	if not lite:
		for s in [-1.0, 1.0]:
			var x := float(s)
			a.box(lc + Vector3(x * 0.13, 0.02, 0.0), Vector3(0.016, 0.01, 0.3), LEAF_VEIN, lr + Vector3(0, -x * 0.6, 0))
	a.stick(lc + Vector3(0, 0, 0.28), Vector3(0.03, 0.18, 0.03), LEAF_D, Vector3(-PI / 2.0 + 0.3, 0, 0))
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK, 0.9)
	# feuilles à la place des gouttes : limbe pointu vers le bas, nervure claire
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.05, 0.05, 0.05), Yokai.INK, Vector3.ZERO, 6)
	t.spike(Vector3(0, -0.02, 0), 0.085, 0.26, LEAF, Vector3(PI, 0, 0), 0.0, 4, 0.25)
	t.box(Vector3(0, -0.14, 0), Vector3(0.012, 0.22, 0.03), LEAF_VEIN)
	d["drip"] = t.mesh()
	var pts := PackedVector3Array()
	var m := 3 if lite else 5
	for i in m:
		var ang := TAU * (float(i) + 0.5) / float(m)
		pts.append(Vector3(sin(ang) * 0.17, 0.4, cos(ang) * 0.16))
	d["drips"] = pts
	d["spread"] = 0.35
