extends RefCounted
## Yōkai d'encre du monde 3 (Cent Contes : neige, temple) : yukionna, yuki_warashi, onryo (aussi en 5 et 8), tsurara.
## Règles de la direction « Masque d'encre » : en tête de yokai_ink_w1.gd. Constructeurs appelés par
## yokai_parts.ink_parts ; rig et animation : ink_rig.gd (REST_ARMS y donne la pose des bras de chaque genre).
## Étoffe du monde : bonnets sombres des jizō (W3_CLOTH), flocons d'écume (W3_WAVE), liseré gris lavande des ombres
## sur la neige (W3_LINE) ; glace pâle ICE_* pour les cristaux, neige SNOW pour les châles.
## Idées (une par yōkai, lisible du dessus) : yukionna = grande et fine, CHÂLE DE NEIGE sur les épaules, longue
## chevelure noire en deux nappes, COURONNE DE CRISTAUX de glace, glaçons à la place des gouttes ; yuki_warashi =
## tout petit sous un CHAPEAU DE PAILLE ROND démesuré, cape de paille, écharpe rouge (il explose : le vermillon
## annonce le danger) ; onryō = masque pâle VOILÉ DE MÈCHES NOIRES (un seul œil visible), triangle des morts,
## col de kimono washi, obi lilas ; tsurara = pas de masque ni de bras qui marchent : BOUQUET DE STALAGMITES sur
## un tertre de neige né d'une flaque d'encre, bloc de glace au visage creux, glaçons aux épaules.

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")

const W3_CLOTH := Color("#2E3446")  # bonnets sombres des jizō
const W3_WAVE := Color("#DCE6EE")  # flocons (écailles de l'obi)
const W3_LINE := Color("#8C8FA8")  # gris lavande des ombres sur la neige
const ICE := Color("#A9DDF5")
const ICE_L := Color("#CFEFFF")
const ICE_D := Color("#7FB8E0")
const SNOW := Color("#EAF4FF")
const INK_SNOW := Color("#222A38")  # encre bleutée de la dame des neiges et de la stalactite
const INK_ONRYO := Color("#231E2C")  # encre violacée du spectre
const LILAC := Color("#B9A8E8")  # âmes (obi et yeux de l'onryō)
const LILAC_D := Color("#5A3A7A")
const MASK_SNOW := Color("#F6F0E6")
const MASK_GHOST := Color("#E4E8F2")
const STRAW_W := Color("#D9C9A0")  # paille givrée du chapeau de l'enfant
const MINO := Color("#B8A47A")
const MINO_D := Color("#8C7A52")
const CHEEK := Color("#F2C6C0")


static func kinds() -> PackedStringArray:
	return PackedStringArray(["yukionna", "yuki_warashi", "onryo", "tsurara"])


static func build(kind: String, d: Dictionary, lite: bool, elite: bool) -> void:
	match kind:
		"yukionna":
			_yukionna(d, lite, elite)
		"yuki_warashi":
			_warashi(d, lite, elite)
		"onryo":
			_onryo(d, lite, elite)
		"tsurara":
			_tsurara(d, lite)


## Yuki-onna : fine et haute, encre bleutée ; châle de neige sur les épaules ; masque de ko-omote aux yeux mi-clos
## et aux lèvres de glace ; chevelure noire en calotte et deux longues nappes ; couronne de cristaux de glace ;
## glaçons qui pendent sous le corps. Élite : peigne d'or dans les cheveux.
static func _yukionna(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 0.9
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, INK_SNOW, W3_CLOTH, W3_WAVE, ICE_D, lite, elite)
	# châle de neige : disque sur les épaules, pan qui descend dans le dos
	b.cyl(Vector3(0, 1.04, 0.02), Vector3(0.5 * w, 0.1, 0.47 * w), SNOW, Vector3.ZERO, 0.78, 12)
	b.cyl(Vector3(0, 0.82, 0.3), Vector3(0.32, 0.44, 0.1), SNOW, Vector3(0.12, 0, 0), 0.9, 8)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_SNOW, 0.88, 1.0, elite)
	Yokai.mask_brows(a, Toon.SUMI, false, 0.88)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		# yeux mi-clos : paupière noire, lueur de glace dessous
		a.box(Vector3(x * 0.1, 0.06, Yokai.FACE_Z), Vector3(0.1, 0.022, 0.015), Toon.SUMI, Vector3(0, 0, -x * 0.1))
		f.ball(Vector3(x * 0.1, 0.04, Yokai.FACE_Z - 0.01), Vector3(0.04, 0.014, 0.01), ICE_L, Vector3.ZERO, 6)
	a.box(Vector3(0, -0.13, Yokai.FACE_Z), Vector3(0.07, 0.03, 0.02), ICE_D)
	# chevelure : calotte, deux longues nappes qui tombent jusqu'à l'obi, mèche devant l'épaule gauche
	a.ball(Vector3(0, 0.14, 0.12), Vector3(0.36, 0.3, 0.32), Yokai.HAIR, Vector3.ZERO, 8)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		a.stick(Vector3(x * 0.3, 0.1, -0.08), Vector3(0.12, 0.95, 0.09), Yokai.HAIR, Vector3(PI, 0, x * 0.05))
	if not lite:
		a.stick(Vector3(0.14, -0.1, -0.3), Vector3(0.05, 0.45, 0.04), Yokai.HAIR, Vector3(PI + 0.1, 0, 0))
	# couronne de cristaux : trois (cinq) pointes de glace plantées dans la chevelure
	var n := 3 if lite else 5
	for i in n:
		var k := (float(i) / float(n - 1) - 0.5) * 2.0
		var h := 0.34 - 0.1 * absf(k)
		a.spike(Vector3(k * 0.22, 0.3 - 0.06 * absf(k), 0.08 + 0.05 * absf(k)), 0.05, h, ICE_L, Vector3(-0.25, 0, -k * 0.45), 0.0, 4)
	if elite:
		a.box(Vector3(0.2, 0.36, 0.1), Vector3(0.16, 0.035, 0.05), Toon.GOLD, Vector3(0, 0, 0.35))
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_SNOW, 0.9)
	# glaçons : pointe de glace qui pend
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.06, 0.06, 0.06), INK_SNOW, Vector3.ZERO, 6)
	t.spike(Vector3(0, 0.02, 0), 0.05, 0.3, ICE_L, Vector3(PI, 0, 0), 0.0, 5)
	d["drip"] = t.mesh()
	d["drips"] = PackedVector3Array([Vector3(0.15, 0.4, -0.12), Vector3(-0.17, 0.4, 0.04), Vector3(0.04, 0.4, 0.17), Vector3(-0.06, 0.42, -0.17)]) if not lite \
		else PackedVector3Array([Vector3(0.15, 0.4, -0.12), Vector3(-0.15, 0.4, 0.1)])
	d["spread"] = 0.15


## Yuki-warashi : tout petit sous un chapeau de paille rond démesuré ; petite face washi aux joues roses et aux yeux
## en points ; cape de paille (mino) sur le corps, écharpe vermillon dont un pan vole dans le dos. Élite : bouton d'or.
static func _warashi(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 0.95
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, Yokai.INK, W3_CLOTH, W3_WAVE, W3_LINE, lite, elite)
	# mino : cône de paille sur les épaules, brins au bas ; écharpe au cou
	b.cyl(Vector3(0, 0.9, 0), Vector3(0.5, 0.4, 0.48), MINO, Vector3.ZERO, 0.62, 12)
	if not lite:
		for i in 7:
			var ang := TAU * (float(i) + 0.5) / 7.0
			b.box(Vector3(sin(ang) * 0.45, 0.63, cos(ang) * 0.43), Vector3(0.035, 0.22, 0.02), MINO_D, Vector3(0, ang, 0))
	b.cyl(Vector3(0, 1.1, 0), Vector3(0.36, 0.09, 0.34), Toon.VERMILION, Vector3.ZERO, 0.9, 10)
	b.box(Vector3(0.14, 0.92, 0.42), Vector3(0.1, 0.34, 0.04), Toon.VERMILION, Vector3(0.25, 0, -0.2))
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.MASK_WASHI, 0.82, 0.82, elite)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		f.ball(Vector3(x * 0.09, 0.05, Yokai.FACE_Z), Vector3(0.03, 0.035, 0.012), Toon.SUMI, Vector3.ZERO, 6)
		a.ball(Vector3(x * 0.14, -0.04, Yokai.FACE_Z + 0.01), Vector3(0.06, 0.04, 0.02), CHEEK, Vector3.ZERO, 6)
	a.box(Vector3(0, -0.12, Yokai.FACE_Z), Vector3(0.06, 0.02, 0.02), Toon.SUMI)
	# chapeau rond : très large bord légèrement conique, dôme, bouton
	var hy := 0.3
	a.cyl(Vector3(0, hy, 0.04), Vector3(0.62, 0.08, 0.6), STRAW_W, Vector3.ZERO, 0.5, 12)
	a.cyl(Vector3(0, hy + 0.14, 0.04), Vector3(0.3, 0.22, 0.3), STRAW_W, Vector3.ZERO, 0.35, 10)
	a.ball(Vector3(0, hy + 0.26, 0.04), Vector3.ONE * (0.06 if elite else 0.04), Toon.GOLD if elite else MINO_D, Vector3.ZERO, 6)
	if elite:
		a.cyl(Vector3(0, hy + 0.04, 0.04), Vector3(0.33, 0.025, 0.33), Toon.GOLD, Vector3.ZERO, 1.0, 10)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK, 0.9)
	Yokai.ink_drip(d, Yokai.INK)


## Onryō : encre violacée ; col de kimono washi croisé, obi lilas ; masque pâle voilé de mèches noires qui tombent
## devant (un seul œil lilas visible), triangle des morts sur le front, bouche tombante ; longues nappes de cheveux.
## Élite : triangle d'or.
static func _onryo(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 0.95
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, INK_ONRYO, LILAC_D, W3_WAVE, LILAC, lite, elite)
	# col de kimono : deux pans washi croisés sur la poitrine
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		b.box(Vector3(x * 0.14, 0.96, -0.4), Vector3(0.11, 0.32, 0.03), Toon.WASHI, Vector3(0.25, 0, -x * 0.55))
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_GHOST, 0.92, 1.0, elite)
	# œil droit visible, lilas ; l'autre sous les mèches
	f.ball(Vector3(-0.1, 0.06, Yokai.FACE_Z), Vector3(0.05, 0.045, 0.015), LILAC, Vector3.ZERO, 8)
	f.ball(Vector3(-0.1, 0.06, Yokai.FACE_Z - 0.012), Vector3(0.02, 0.025, 0.01), Toon.SUMI, Vector3.ZERO, 6)
	# bouche tombante
	a.box(Vector3(0, -0.14, Yokai.FACE_Z), Vector3(0.11, 0.026, 0.02), Toon.SUMI, Vector3(0, 0, -0.15))
	# triangle des morts (or pour l'élite)
	a.spike(Vector3(0, 0.2, Yokai.FACE_Z + 0.005), 0.07, 0.12, Toon.GOLD if elite else Toon.WASHI, Vector3(-0.1, 0, 0), 0.0, 3, 0.25)
	# chevelure : calotte, mèches qui tombent devant le masque (voile), deux nappes de côté
	a.ball(Vector3(0, 0.16, 0.1), Vector3(0.37, 0.3, 0.34), Yokai.HAIR, Vector3.ZERO, 8)
	var veil := [Vector3(0.12, 0.3, -0.36), Vector3(0.2, 0.25, -0.33), Vector3(0.03, 0.32, -0.38)]
	if not lite:
		veil.append(Vector3(0.27, 0.2, -0.28))
		veil.append(Vector3(-0.22, 0.26, -0.3))
	for p in veil:
		a.stick(p, Vector3(0.075, 0.75, 0.04), Yokai.HAIR, Vector3(PI + 0.08, 0, 0))
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		a.stick(Vector3(x * 0.3, 0.12, -0.06), Vector3(0.12, 0.9, 0.1), Yokai.HAIR, Vector3(PI, 0, x * 0.04))
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_ONRYO)
	Yokai.ink_drip(d, INK_ONRYO)


## Tsurara : tourelle. Flaque d'encre gelée, tertre de neige, bouquet de stalagmites de glace ; la « tête » est un
## bloc de glace au visage creux (orbites noires, pupilles de lueur froide, bouche fendue) traversé par la grande
## pointe ; aux épaules, des glaçons qui pendent (ils ne marchent pas : la stalactite ne bouge pas) ; de petits
## glaçons frémissent au bord du tertre. Pas d'élite (enemy.NO_ELITE). La lueur froide vient d'enemy.gd.
static func _tsurara(d: Dictionary, lite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	b.ball(Vector3(0, 0.03, 0), Vector3(0.62, 0.08, 0.6), INK_SNOW, Vector3.ZERO, 10)
	b.ball(Vector3(0, 0.1, 0), Vector3(0.5, 0.26, 0.48), SNOW, Vector3.ZERO, 10)
	# stalagmites : la grande au centre (elle monte jusque dans le bloc de la tête), les autres autour
	b.cyl(Vector3(0, 0.72, 0.02), Vector3(0.3, 1.45, 0.3), ICE, Vector3.ZERO, 0.08, 7)
	var pil := [[0.27, -0.1, 0.17, 1.0], [-0.26, 0.12, 0.16, 0.9], [0.05, -0.3, 0.14, 0.75], [-0.14, -0.22, 0.11, 0.55]]
	if not lite:
		pil.append([0.2, 0.26, 0.11, 0.6])
		pil.append([-0.05, 0.32, 0.09, 0.45])
	for sp in pil:
		var p: Array = sp
		b.cyl(Vector3(float(p[0]), float(p[3]) * 0.5 + 0.1, float(p[1])), Vector3(float(p[2]), float(p[3]), float(p[2])), ICE_L if float(p[3]) < 0.7 else ICE, Vector3(0.12 * float(p[1]), 0, -0.12 * float(p[0])), 0.0, 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	# bloc de glace de la tête, pointe qui le traverse, visage creux
	a.ball(Vector3(0, -0.02, -0.04), Vector3(0.3, 0.34, 0.27), ICE_L, Vector3(0, 0, 0.1), 8)
	a.spike(Vector3(0, 0.1, 0.0), 0.12, 0.42, ICE, Vector3(-0.05, 0, 0), 0.0, 6)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		a.ball(Vector3(x * 0.11, 0.04, -0.27), Vector3(0.075, 0.09, 0.05), Toon.SUMI, Vector3(0, 0, x * 0.2), 8)
		f.ball(Vector3(x * 0.11, 0.03, -0.31), Vector3(0.03, 0.035, 0.01), ICE_L, Vector3.ZERO, 6)
		# glaçons sous le bloc, de chaque côté
		a.spike(Vector3(x * 0.22, -0.2, -0.1), 0.045, 0.22 + 0.06 * x, ICE_L, Vector3(PI, 0, 0), 0.0, 5)
	a.box(Vector3(0, -0.14, -0.29), Vector3(0.13, 0.025, 0.02), Toon.SUMI, Vector3(0, 0, 0.1))
	d["head"] = Yokai.two(a, f)
	# « bras » : glaçon qui pend de l'épaule (pose de repos écartée, aucune marche : speed = 0)
	var ar := Yokai.Mesher.new(1.0)
	ar.ball(Vector3(0, 0.0, 0), Vector3(0.09, 0.07, 0.09), SNOW, Vector3.ZERO, 6)
	ar.spike(Vector3(0, 0.0, 0), 0.07, 0.42, ICE_L, Vector3(PI, 0, 0), 0.0, 5)
	d["arm"] = ar.mesh()
	# petits glaçons dressés au bord du tertre (ils frémissent : étirés en code)
	var t := Yokai.Mesher.new(1.0)
	t.spike(Vector3(0, -0.04, 0), 0.05, 0.22, ICE_L, Vector3.ZERO, 0.0, 5)
	d["drip"] = t.mesh()
	var n := 3 if lite else 5
	var pts := PackedVector3Array()
	for i in n:
		var ang := TAU * (float(i) + 0.3) / float(n)
		pts.append(Vector3(sin(ang) * 0.44, 0.22, cos(ang) * 0.42))
	d["drips"] = pts
	d["spread"] = 0.35
