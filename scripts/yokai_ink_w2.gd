extends RefCounted
## Yōkai d'encre du monde 2 (Tanabata : nuit, bambouseraie, feux de renards) : kitsunebi, kitsunebi_s (le petit
## scindé), kamaitachi (aussi en 3 et 6), tanuki, tanuki_d (leurre), kitsune_tsukai (aussi en 5).
## Règles de la direction « Masque d'encre » : en tête de yokai_ink_w1.gd. Constructeurs appelés par
## yokai_parts.ink_parts ; rig et animation : ink_rig.gd (REST_ARMS y donne la pose des bras de chaque genre).
## Étoffe du monde : nuit de Tanabata (ciel W2_CLOTH), écailles d'or pâle du feu de renard (W2_WAVE), liseré de
## jade pâle (W2_LINE) ; braise sombre EMBER pour les parures des renards (jamais de vermillon en aplat).
## Idées (une par yōkai, lisible du dessus) : kitsunebi = masque de renard à grandes oreilles et TROIS QUEUES en
## éventail à la place des gouttes ; kamaitachi = oreilles rondes, griffes d'acier aux deux mains, QUEUE-FAUCILLE
## à lame qui se dresse dans le dos ; tanuki = large, grand CHAPEAU DE PAILLE, loup sombre sur les yeux, grosse
## queue annelée (le leurre n'en a pas : seul indice) ; kitsune_tsukai = prêtresse à la chevelure noire, MASQUE DE
## RENARD RELEVÉ sur le front (il regarde le ciel), ofuda à l'obi, lanterne levée.

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")

const W2_CLOTH := Color("#2E3B4E")  # ciel de la nuit des étoiles
const W2_WAVE := Color("#F1E3A6")  # or pâle du feu de renard (écailles de l'obi)
const W2_LINE := Color("#A3B07A")  # jade pâle des bambous
const EMBER := Color("#6E2A24")  # braise sombre : bavoir et oreilles des renards, robe de la prêtresse
const FOX_FIRE := Color("#8FE3FF")  # feu de renard (yeux, bouts de queues : aplat)
const FOX_TIP := Color("#BFEFFF")
const INK_FOX := Color("#1E1C26")  # encre froide des renards
const INK_FUR := Color("#241C16")  # encre chaude des bêtes (belette, tanuki)
const FUR_W := Color("#8A5F35")  # pelage de la belette
const FUR_L := Color("#B38A52")  # masque fauve clair de la belette
const FUR_T := Color("#7A5838")  # pelage du tanuki
const DARK := Color("#3A2A20")  # loup du tanuki, anneaux de la queue
const CREAM := Color("#E8D2A8")  # museaux, face du tanuki
const CREAM_L := Color("#F2E6CC")


static func kinds() -> PackedStringArray:
	return PackedStringArray(["kitsunebi", "kitsunebi_s", "kamaitachi", "tanuki", "tanuki_d", "kitsune_tsukai"])


static func build(kind: String, d: Dictionary, lite: bool, elite: bool) -> void:
	match kind:
		"kitsunebi":
			_kitsunebi(d, lite, elite, false)
		"kitsunebi_s":
			_kitsunebi(d, lite, false, true)
		"kamaitachi":
			_kamaitachi(d, lite, elite)
		"tanuki":
			_tanuki(d, lite, elite, false)
		"tanuki_d":
			_tanuki(d, lite, false, true)
		"kitsune_tsukai":
			_tsukai(d, lite, elite)


## Kitsunebi : masque de renard blanc (long museau, fentes de feu, traits de braise), grandes oreilles dressées,
## collerette blanche ; trois queues blanches à bout de feu en éventail sous le corps (une seule pour le petit).
## La flamme tenue en main droite levée vient d'enemy.gd.
static func _kitsunebi(d: Dictionary, lite: bool, elite: bool, mini: bool) -> void:
	var w := 0.85 if mini else 0.95
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, INK_FOX, W2_CLOTH, W2_WAVE, W2_LINE, lite, elite)
	# collerette : disque blanc posé sur les épaules
	b.cyl(Vector3(0, 1.06, 0), Vector3(0.46 * w, 0.08, 0.44 * w), Yokai.FOX_W, Vector3.ZERO, 0.8, 10)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	var s := 0.9 if mini else 1.0
	Yokai.mask_plate(a, Yokai.FOX_W, 0.95 * s, 0.95 * s, elite)
	# museau : long, un peu baissé, truffe noire
	var tip := a.spike(Vector3(0, -0.08 * s, Yokai.FACE_Z + 0.01), 0.11 * s, 0.24 * s, Yokai.FOX_W, Vector3(-PI / 2.0 - 0.18, 0, 0), 0.3, 5, 0.7)
	a.ball(tip, Vector3(0.035, 0.03, 0.03), Toon.SUMI, Vector3.ZERO, 6)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		# fentes des yeux : trait noir relevé vers l'extérieur, feu de renard dedans
		a.box(Vector3(x * 0.115 * s, 0.07, Yokai.FACE_Z), Vector3(0.14, 0.032, 0.02), Toon.SUMI, Vector3(0, 0, x * 0.45))
		f.ball(Vector3(x * 0.115 * s, 0.07, Yokai.FACE_Z - 0.012), Vector3(0.055, 0.014, 0.01), FOX_FIRE, Vector3(0, 0, x * 0.45), 6)
		# traits de braise : sourcils qui montent, marque des joues
		a.box(Vector3(x * 0.12 * s, 0.17, Yokai.FACE_Z), Vector3(0.15, 0.03, 0.02), EMBER, Vector3(0, 0, x * 0.5))
		if not lite:
			a.box(Vector3(x * 0.2 * s, -0.06, Yokai.FACE_Z + 0.01), Vector3(0.1, 0.024, 0.02), EMBER, Vector3(0, 0, x * 0.25))
		# grandes oreilles dressées, penchées vers l'extérieur, intérieur de braise
		var eh := 0.32 if mini else 0.42
		a.spike(Vector3(x * 0.17, 0.2, -0.04), 0.11, eh, Yokai.FOX_W, Vector3(-0.15, 0, -x * 0.3), 0.0, 4, 0.5)
		a.spike(Vector3(x * 0.165, 0.22, -0.085), 0.06, eh * 0.7, EMBER, Vector3(-0.15, 0, -x * 0.3), 0.0, 4, 0.4)
	if elite:
		# aigrette de feu d'or entre les oreilles
		a.spike(Vector3(0, 0.3, 0.02), 0.05, 0.24, Toon.GOLD, Vector3(-0.2, 0, 0), 0.0, 5)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_FOX, 0.9)
	# queues : fuseau blanc qui pend, bout de feu ; en éventail vers l'arrière (spread les penche vers l'extérieur)
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.1, 0.08, 0.1), INK_FOX, Vector3.ZERO, 6)
	t.spike(Vector3(0, 0.02, 0), 0.1, 0.5, Yokai.FOX_W, Vector3(PI, 0, 0), 0.35, 6)
	t.ball(Vector3(0, -0.5, 0), Vector3(0.065, 0.08, 0.065), FOX_TIP, Vector3.ZERO, 6)
	d["drip"] = t.mesh()
	var n := 1 if mini else (2 if lite else 3)
	var pts := PackedVector3Array()
	for i in n:
		# dans le dos (+Z) et sur les flancs, en large éventail : les bouts dépassent la silhouette vue du dessus
		var ang := (float(i) - 0.5 * float(n - 1)) * 1.15 if n > 1 else 0.9
		pts.append(Vector3(sin(ang) * 0.3 * w, 0.52, cos(ang) * 0.26 * w))
	d["drips"] = pts
	d["spread"] = 0.75


## Kamaitachi : masque de pelage fauve au museau crème, oreilles rondes, moustaches ; griffes d'acier aux deux
## mains ; longue queue qui se dresse dans le dos et finit en lame de faucille.
static func _kamaitachi(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.9, INK_FUR, W2_CLOTH, W2_WAVE, W2_LINE, lite, elite)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, FUR_L, 0.95, 0.9, elite)
	Yokai.mask_brows(a, Toon.SUMI, true, 0.9)
	Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.045, 0.95, 0.07)
	# museau crème, truffe, moustaches
	a.ball(Vector3(0, -0.1, Yokai.FACE_Z + 0.01), Vector3(0.16, 0.12, 0.07), CREAM, Vector3.ZERO, 8)
	a.ball(Vector3(0, -0.05, Yokai.FACE_Z - 0.06), Vector3(0.04, 0.03, 0.03), Toon.SUMI, Vector3.ZERO, 6)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		if not lite:
			a.box(Vector3(x * 0.22, -0.1, Yokai.FACE_Z), Vector3(0.16, 0.012, 0.01), Toon.SUMI, Vector3(0, 0, x * 0.15))
		# oreilles rondes sur le haut de la tête, intérieur crème
		a.ball(Vector3(x * 0.21, 0.27, 0.0), Vector3(0.11, 0.11, 0.05), FUR_W, Vector3(0, 0, -x * 0.35), 8)
		a.ball(Vector3(x * 0.2, 0.27, -0.03), Vector3(0.065, 0.065, 0.03), CREAM, Vector3(0, 0, -x * 0.35), 6)
	d["head"] = Yokai.two(a, f)
	# bras : encre, main en boule, trois griffes d'acier qui dépassent
	var ar := Yokai.Mesher.new(1.0)
	ar.cyl(Vector3(0, -0.2, 0), Vector3(0.08, 0.4, 0.08), INK_FUR, Vector3(PI, 0, 0), 0.7, 7)
	ar.ball(Vector3(0, -0.43, 0), Vector3(0.095, 0.08, 0.095), INK_FUR)
	for i in 3:
		var x := (float(i) - 1.0) * 0.055
		ar.spike(Vector3(x, -0.48, -0.02), 0.02, 0.17, Yokai.STEEL, Vector3(PI - 0.15, 0, (float(i) - 1.0) * 0.3), 0.0, 4)
	d["arm"] = ar.mesh()
	Yokai.ink_drip(d, INK_FUR)
	# queue-faucille : deux fuseaux de pelage qui montent dans le dos à gauche, puis la lame d'acier, large et
	# plate face à la caméra, se courbe au-dessus de l'épaule (une faucille dressée, lisible du dessus)
	var x := Yokai.Mesher.new(1.0)
	x.ball(Vector3(-0.12, 0.6, 0.42), Vector3(0.085, 0.3, 0.085), FUR_W, Vector3(-1.0, 0, 0.3), 7)
	x.ball(Vector3(-0.3, 0.95, 0.58), Vector3(0.07, 0.27, 0.07), FUR_W, Vector3(-0.35, 0, 0.55), 7)
	if elite:
		x.cyl(Vector3(-0.22, 0.8, 0.52), Vector3(0.09, 0.05, 0.09), Toon.GOLD, Vector3(-0.5, 0, 0.5), 1.0, 8)
	var br := Vector3(-0.42, 1.18, 0.62)
	x.stick(br, Vector3(0.09, 0.4, 0.03), Yokai.STEEL, Vector3(0, 0, 0.35))
	var bt := br + Basis.from_euler(Vector3(0, 0, 0.35)) * Vector3(0, 0.4, 0)
	x.stick(bt, Vector3(0.07, 0.3, 0.03), Yokai.STEEL, Vector3(0, 0, 1.0))
	if not lite:
		x.spike(bt + Basis.from_euler(Vector3(0, 0, 1.0)) * Vector3(0, 0.3, 0), 0.035, 0.12, Yokai.STEEL, Vector3(0, 0, 1.4), 0.0, 4, 0.4)
	d["fixed"] = x.mesh()


## Tanuki : large, grand chapeau de paille à calotte, face crème au loup sombre, museau clair ; grosse queue annelée
## qui se dresse à droite dans le dos (le leurre `decoy` n'en a pas : c'est le seul indice). Le ventre-tambour
## clair est accroché par enemy.gd (il bat pendant l'annonce).
static func _tanuki(d: Dictionary, lite: bool, elite: bool, decoy: bool) -> void:
	var w := 1.2
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, INK_FUR, W2_CLOTH, W2_WAVE, W2_LINE, lite, elite)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, CREAM, 1.05, 0.95, elite)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		# loup sombre autour des yeux (il descend vers les joues)
		a.ball(Vector3(x * 0.125, 0.06, Yokai.FACE_Z + 0.012), Vector3(0.135, 0.085, 0.02), DARK, Vector3(0, 0, x * 0.2), 8)
	Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.038, 1.0, 0.06)
	# museau clair, truffe, petit sourire
	a.ball(Vector3(0, -0.11, Yokai.FACE_Z - 0.02), Vector3(0.13, 0.09, 0.07), CREAM_L, Vector3.ZERO, 8)
	a.ball(Vector3(0, -0.06, Yokai.FACE_Z - 0.09), Vector3(0.04, 0.03, 0.03), Toon.SUMI, Vector3.ZERO, 6)
	a.box(Vector3(0, -0.18, Yokai.FACE_Z - 0.02), Vector3(0.1, 0.02, 0.02), Toon.SUMI)
	# chapeau de paille : large bord, calotte, bouton (or pour l'élite)
	var hat_y := 0.33
	a.cyl(Vector3(0, hat_y, 0.03), Vector3(0.56, 0.06, 0.54), Yokai.STRAW, Vector3.ZERO, 0.55, 12)
	a.cyl(Vector3(0, hat_y + 0.1, 0.03), Vector3(0.24, 0.16, 0.24), Yokai.STRAW, Vector3.ZERO, 0.45, 10)
	a.ball(Vector3(0, hat_y + 0.19, 0.03), Vector3.ONE * (0.06 if elite else 0.045), Toon.GOLD if elite else DARK, Vector3.ZERO, 6)
	if elite:
		a.cyl(Vector3(0, hat_y + 0.03, 0.03), Vector3(0.27, 0.025, 0.27), Toon.GOLD, Vector3.ZERO, 1.0, 10)
	elif not lite:
		a.cyl(Vector3(0, hat_y + 0.03, 0.03), Vector3(0.27, 0.025, 0.27), DARK, Vector3.ZERO, 1.0, 10)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_FUR, 1.1)
	Yokai.ink_drip(d, INK_FUR)
	if not decoy:
		# queue annelée : gros fuseau qui monte à droite, hors du bord du chapeau (visible du dessus), anneaux sombres
		var x := Yokai.Mesher.new(1.0)
		var rot := Vector3(-0.55, 0, -0.7)
		var dir := Basis.from_euler(rot) * Vector3.UP
		var base := Vector3(0.3, 0.55, 0.25)
		x.ball(base + dir * 0.3, Vector3(0.17, 0.34, 0.17), FUR_T, rot, 8)
		x.ball(base + dir * 0.48, Vector3(0.18, 0.07, 0.18), DARK, rot, 8)
		x.ball(base + dir * 0.66, Vector3(0.15, 0.16, 0.15), FUR_T, rot, 8)
		x.ball(base + dir * 0.82, Vector3(0.12, 0.13, 0.12), DARK, rot, 7)
		if not lite:
			x.ball(base + dir * 0.12, Vector3(0.15, 0.06, 0.15), DARK, rot, 8)
		d["fixed"] = x.mesh()


## Prêtresse renarde (kitsune-tsukai) : face washi aux lèvres rouges et yeux de feu, longue chevelure noire,
## masque de renard relevé sur le front (il regarde le ciel : lisible du dessus), bande de braise en kesa, ofuda
## à l'obi ; perche de lanterne levée en main droite (la panse lumineuse vient d'enemy.gd). Élite : masque d'or.
static func _tsukai(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 0.95
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, Yokai.INK, W2_CLOTH, W2_WAVE, W2_LINE, lite, elite)
	# kesa de braise en écharpe
	b.cyl(Vector3(0, 0.95, 0), Vector3(0.45 * w + 0.02, 0.07, 0.43 * w + 0.02), EMBER, Vector3(0, 0, -0.55), 1.0, 14)
	# ofuda : trois bandes de papier pendues devant l'obi, trait vermillon
	for i in 3:
		var x := (float(i) - 1.0) * 0.12
		b.box(Vector3(x, 0.5, -0.31), Vector3(0.07, 0.24, 0.012), Toon.WASHI, Vector3(0.1, 0, x * 0.6))
		if not lite:
			b.box(Vector3(x, 0.5, -0.318), Vector3(0.022, 0.16, 0.008), Toon.VERMILION, Vector3(0.1, 0, x * 0.6))
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.MASK_WASHI, 0.92, 1.0, elite)
	Yokai.mask_brows(a, Toon.SUMI, false, 0.92)
	Yokai.mask_eyes(f, FOX_FIRE, 0.04, 0.92, 0.05)
	a.box(Vector3(0, -0.13, Yokai.FACE_Z), Vector3(0.06, 0.03, 0.02), Toon.VERMILION)
	# chevelure : calotte en arrière, deux longues mèches de côté
	a.ball(Vector3(0, 0.12, 0.14), Vector3(0.36, 0.3, 0.3), Yokai.HAIR, Vector3.ZERO, 8)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		a.stick(Vector3(x * 0.31, 0.08, -0.12), Vector3(0.08, 0.62, 0.07), Yokai.HAIR, Vector3(PI, 0, x * 0.06))
	# masque de renard relevé sur le front : plaque tournée vers le ciel, museau vers l'avant, fentes, oreilles
	var fox := Toon.GOLD if elite else Yokai.FOX_W
	var mrot := Vector3(-0.95, 0, 0)
	var mb := Basis.from_euler(mrot)
	var mc := Vector3(0, 0.3, -0.2)
	a.ball(mc, Vector3(0.23, 0.26, 0.08), fox, mrot, 8)
	var tip := a.spike(mc + mb * Vector3(0, -0.1, -0.06), 0.08, 0.17, fox, Vector3(-0.95 - PI / 2.0 - 0.1, 0, 0), 0.3, 5, 0.7)
	a.ball(tip, Vector3(0.028, 0.025, 0.025), Toon.SUMI, Vector3.ZERO, 6)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		a.box(mc + mb * Vector3(x * 0.09, 0.03, -0.08), Vector3(0.1, 0.026, 0.02), Toon.SUMI, Vector3(-0.95, 0, x * 0.4))
		a.spike(mc + mb * Vector3(x * 0.13, 0.2, 0.0), 0.065, 0.2, fox, Vector3(-0.6, 0, -x * 0.3), 0.0, 4, 0.5)
		if not lite:
			a.box(mc + mb * Vector3(x * 0.1, 0.1, -0.08), Vector3(0.1, 0.022, 0.02), EMBER, Vector3(-0.95, 0, x * 0.5))
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK)
	Yokai.ink_drip(d, Yokai.INK)
	d["weapon_r"] = Yokai.weapon("lantern")
