extends RefCounted
## Yōkai d'encre du monde 4 (Fuji Rouge : faille, cendre, feu sumi + or) : kasha, hinotama, teppo, tengu, kanabo, moryo.
## Règles de la direction « Masque d'encre » : en tête de yokai_ink_w1.gd. Constructeurs appelés par
## yokai_parts.ink_parts (table INK_WORLD_PATHS) ; rig et animation : ink_rig.gd.
## Étoffe du monde (design/PALETTES.md) : obi de cendre ASH_CLOTH, écailles de flammes ambre FLAME (jamais orange),
## liseré d'or ; les masques prennent la braise EMBER, le fer IRON_D ; l'encre est un sumi un peu chaud (INK_ASH).
## Les kinds partagés (tengu 4-5-6, moryo 4-5-6-8, teppo 4-5, kanabo 4-8) sont bâtis ici, à la palette du monde 4.

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")

const INK_ASH := Color("#211C1E")  # sumi chaud de la faille
const INK_EMBER := Color("#2A1A18")  # encre de braise (boule de feu)
const INK_AO := Color("#1C2030")  # encre bleutée de l'ao-oni
const INK_MIST := Color("#26222E")  # encre violacée de l'esprit
const ASH_CLOTH := Color("#4A403C")  # étoffe de cendre
const FLAME := Color("#D9A64A")  # flamme ambre (palette : jamais orange)
const FLAME_CORE := Color("#FFE2A0")  # cœur des flammes
const EMBER := Color("#8E2A1E")  # braise des masques
const IRON_D := Color("#3B3A3E")  # fer de la faille
const MASK_AO := Color("#4F6A8C")  # masque bleu de l'oni à massue
const MASK_CROW := Color("#2E2A34")  # masque de plumes du tengu
const MASK_MIST := Color("#D9D2E6")  # masque pâle de l'esprit
const FEATHER := Color("#24222A")
const CAT_NOSE := Color("#D98A8A")
const EYE_SHIELD := Color("#9FD0FF")  # yeux du mōryō (bleu des boucliers)


static func kinds() -> PackedStringArray:
	return PackedStringArray(["kasha", "hinotama", "teppo", "tengu", "kanabo", "moryo"])


static func build(kind: String, d: Dictionary, lite: bool, elite: bool) -> void:
	match kind:
		"kasha":
			_kasha(d, lite, elite)
		"hinotama":
			_hinotama(d, lite, elite)
		"teppo":
			_teppo(d, lite, elite)
		"tengu":
			_tengu(d, lite, elite)
		"kanabo":
			_kanabo(d, lite, elite)
		"moryo":
			_moryo(d, lite, elite)


## Flamme à deux tons : langue ambre et cœur clair qui en sort (même base, même direction).
static func _flame(a: Yokai.Mesher, base: Vector3, r: float, h: float, rot: Vector3, elite := false) -> void:
	a.spike(base, r, h, FLAME, rot, 0.0, 5, 0.7)
	a.spike(base, r * 0.45, h * 0.62, Toon.GOLD if elite else FLAME_CORE, rot, 0.0, 4, 0.7)


## Kasha : masque de chat couleur braise (museau washi, nez rose, moustaches, yeux d'or fendus), oreilles d'encre
## à flamme, crinière de feu sur le crâne ; deux queues d'encre terminées en flamme à la place des gouttes.
## Les roues en feu du char viennent d'enemy.gd.
static func _kasha(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 1.1
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, INK_ASH, ASH_CLOTH, FLAME, Toon.GOLD, lite, elite)
	# collier de corde du harnais, clochette d'or
	b.cyl(Vector3(0, 1.0, 0), Vector3(0.44 * w, 0.045, 0.42 * w), Yokai.STRAW, Vector3(0.12, 0, 0), 1.0, 12)
	b.ball(Vector3(0, 0.9, -0.44 * w), Vector3(0.06, 0.07, 0.05), Toon.GOLD, Vector3.ZERO, 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, EMBER, 1.05, 0.95, elite)
	Yokai.mask_brows(a, Toon.SUMI, true, 1.05)
	# yeux fendus : amande d'or, pupille en fente
	for s in [-1.0, 1.0]:
		var x := float(s) * 0.125
		f.ball(Vector3(x, 0.06, Yokai.FACE_Z), Vector3(0.075, 0.05, 0.015), Yokai.EYE_GOLD, Vector3(0, 0, -float(s) * 0.25), 8)
		f.box(Vector3(x, 0.06, Yokai.FACE_Z - 0.012), Vector3(0.016, 0.07, 0.01), Toon.SUMI)
	# museau washi, nez rose, moustaches
	a.ball(Vector3(0, -0.11, Yokai.FACE_Z), Vector3(0.14, 0.085, 0.035), Toon.WASHI, Vector3.ZERO, 8)
	a.ball(Vector3(0, -0.065, Yokai.FACE_Z - 0.03), Vector3(0.035, 0.028, 0.02), CAT_NOSE, Vector3.ZERO, 6)
	a.box(Vector3(0, -0.15, Yokai.FACE_Z - 0.03), Vector3(0.09, 0.02, 0.015), Toon.SUMI)
	if not lite:
		for s in [-1.0, 1.0]:
			for j in 2:
				a.box(Vector3(float(s) * 0.22, -0.09 - 0.045 * float(j), Yokai.FACE_Z - 0.02), Vector3(0.26, 0.012, 0.012), Toon.SUMI, Vector3(0, 0, float(s) * (0.12 - 0.3 * float(j))))
	# oreilles pointues, flamme dans le pavillon
	for s in [-1.0, 1.0]:
		var rot := Vector3(-0.25, 0, -float(s) * 0.4)
		var base := Vector3(float(s) * 0.2, 0.26, Yokai.MASK_Z + 0.08)
		var tip := a.spike(base, 0.1, 0.3, INK_ASH, rot, 0.0, 4, 0.5)
		a.spike(base + Vector3(0, 0.02, -0.02), 0.05, 0.17, FLAME, rot, 0.0, 4, 0.4)
		if elite:
			a.spike(tip - Vector3(0, 0.05, 0), 0.03, 0.12, Toon.GOLD, rot, 0.0, 4)
	# crinière de feu sur le crâne, couchée en arrière
	var n := 2 if lite else 3
	for i in n:
		var t := (float(i) - float(n - 1) * 0.5) * 0.14
		_flame(a, Vector3(t, 0.3, Yokai.MASK_Z + 0.22 + absf(t) * 0.3), 0.075, 0.36, Vector3(-0.9, 0, -t * 2.0), elite)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_ASH, 1.05)
	# queues : fuseau d'encre qui s'étire, flamme au bout
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.09, 0.07, 0.09), INK_ASH, Vector3.ZERO, 6)
	t.spike(Vector3.ZERO, 0.075, 0.42, INK_ASH, Vector3(PI, 0, 0), 0.35, 6)
	t.spike(Vector3(0, -0.4, 0), 0.055, 0.22, FLAME, Vector3(PI, 0, 0), 0.0, 5)
	t.spike(Vector3(0, -0.42, 0), 0.025, 0.14, Toon.GOLD if elite else FLAME_CORE, Vector3(PI, 0, 0), 0.0, 4)
	d["drip"] = t.mesh()
	d["drips"] = PackedVector3Array([Vector3(0.13, 0.42, 0.24), Vector3(-0.13, 0.42, 0.24)])
	d["spread"] = 0.55


## Hinotama : pas de masque, une créature. Noyau d'encre de braise, couronne de flammes ambre couchées en
## arrière (la traînée, vue du dessus), deux gros yeux d'or et un rictus washi ; langues de feu sous le corps
## à la place des gouttes. Il vole : enemy.gd le tient à 1,4 m.
static func _hinotama(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	b.ball(Vector3(0, 1.0, 0), Vector3(0.46, 0.42, 0.44), INK_EMBER, Vector3.ZERO, 10)
	# traînée : grande flamme vers l'arrière, deux plus petites de côté
	_flame(b, Vector3(0, 1.08, 0.36), 0.16, 0.75, Vector3(-1.35, 0, 0), elite)
	for s in [-1.0, 1.0]:
		_flame(b, Vector3(float(s) * 0.3, 1.1, 0.26), 0.1, 0.45, Vector3(-1.1, 0, -float(s) * 0.5), elite)
	if elite:
		# auréole d'or
		b.cyl(Vector3(0, 1.0, 0), Vector3(0.55, 0.025, 0.53), Toon.GOLD, Vector3(0.35, 0, 0), 1.0, 14)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	# couronne de flammes dressée sur le haut du noyau
	var n := 3 if lite else 5
	for i in n:
		var t := (float(i) - float(n - 1) * 0.5) / float(n - 1)
		_flame(a, Vector3(t * 0.3, 0.16 - 0.06 * absf(t), -0.08 + 0.1 * absf(t)), 0.08, 0.4 - 0.1 * absf(t), Vector3(-0.35 - 0.3 * absf(t), 0, -t * 0.9), elite)
	# face : gros yeux d'or, pupilles sumi, rictus washi à dents
	for s in [-1.0, 1.0]:
		f.ball(Vector3(float(s) * 0.15, -0.1, -0.4), Vector3(0.095, 0.105, 0.02), Yokai.EYE_GOLD, Vector3.ZERO, 8)
		f.ball(Vector3(float(s) * 0.15, -0.11, -0.415), Vector3(0.04, 0.05, 0.01), Toon.SUMI, Vector3.ZERO, 6)
	a.box(Vector3(0, -0.27, -0.4), Vector3(0.26, 0.045, 0.02), Toon.WASHI)
	if not lite:
		for i in 4:
			a.box(Vector3(-0.09 + 0.06 * float(i), -0.27, -0.408), Vector3(0.012, 0.045, 0.012), Toon.SUMI)
	d["head"] = Yokai.two(a, f)
	# petits bras de braise, mains de flamme
	var arm := Yokai.Mesher.new(1.0)
	arm.cyl(Vector3(0, -0.12, 0), Vector3(0.06, 0.24, 0.06), INK_EMBER, Vector3(PI, 0, 0), 0.6, 6)
	arm.ball(Vector3(0, -0.25, 0), Vector3(0.065, 0.055, 0.065), FLAME, Vector3.ZERO, 6)
	d["arm"] = arm.mesh()
	# langues de feu qui lèchent vers le bas
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.075, 0.055, 0.075), INK_EMBER, Vector3.ZERO, 6)
	t.spike(Vector3.ZERO, 0.065, 0.28, FLAME, Vector3(PI, 0, 0), 0.0, 5)
	t.spike(Vector3.ZERO, 0.03, 0.18, FLAME_CORE, Vector3(PI, 0, 0), 0.0, 4)
	d["drip"] = t.mesh()
	d["drips"] = PackedVector3Array([Vector3(0.16, 0.64, -0.08), Vector3(-0.18, 0.63, 0.08), Vector3(0.03, 0.62, 0.22)])
	d["spread"] = 0.3


## Arquebusier : masque washi d'ashigaru (sourcils froncés, moustache, dents serrées) sous un large jingasa de fer
## laqué à pointe d'or, cordon de braise ; bandoulière et cartouchières ; arquebuse levée au-dessus de la tête.
static func _teppo(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 1.0, INK_ASH, ASH_CLOTH, FLAME, Toon.GOLD, lite, elite)
	# bandoulière de cuir en biais, trois cartouchières de bois sur le ventre
	b.cyl(Vector3(0, 0.95, 0), Vector3(0.44, 0.05, 0.42), Yokai.WOOD_D, Vector3(0, 0, -0.6), 1.0, 12)
	if not lite:
		for i in 3:
			var x := (float(i) - 1.0) * 0.12
			b.box(Vector3(x, 0.84 - absf(x) * 0.3, -0.37), Vector3(0.07, 0.09, 0.06), Yokai.WOOD_D, Vector3(0, 0, -x * 1.5))
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.MASK_WASHI, 1.0, 1.0, elite)
	Yokai.mask_brows(a, Toon.SUMI, true)
	Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.04)
	# moustache tombante, bouche serrée
	for s in [-1.0, 1.0]:
		a.box(Vector3(float(s) * 0.08, -0.08, Yokai.FACE_Z), Vector3(0.12, 0.025, 0.015), Toon.SUMI, Vector3(0, 0, float(s) * 0.45))
	a.box(Vector3(0, -0.15, Yokai.FACE_Z), Vector3(0.16, 0.03, 0.02), Toon.SUMI)
	if not lite:
		for i in 3:
			a.box(Vector3(-0.04 + 0.04 * float(i), -0.15, Yokai.FACE_Z - 0.006), Vector3(0.01, 0.03, 0.01), Toon.WASHI)
	# jingasa : large cône de fer laqué, bord cerclé, pointe d'or (élite : cercle d'or)
	var hz := Yokai.MASK_Z + 0.2
	a.cyl(Vector3(0, 0.37, hz), Vector3(0.5, 0.2, 0.47), IRON_D, Vector3(0.18, 0, 0), 0.1, 12)
	a.cyl(Vector3(0, 0.28, hz), Vector3(0.51, 0.035, 0.48), Toon.GOLD if elite else Toon.SUMI, Vector3(0.18, 0, 0), 1.0, 12)
	a.ball(Vector3(0, 0.48, hz + 0.02), Vector3(0.05, 0.04, 0.05), Toon.GOLD, Vector3.ZERO, 6)
	# cordon de braise qui descend le long des joues
	if not lite:
		for s in [-1.0, 1.0]:
			a.box(Vector3(float(s) * 0.3, 0.05, Yokai.MASK_Z - 0.02), Vector3(0.022, 0.4, 0.022), EMBER, Vector3(0, 0, float(s) * 0.12))
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_ASH)
	Yokai.ink_drip(d, INK_ASH)
	d["weapon_r"] = Yokai.weapon("rifle")


## Karasu-tengu : masque de plumes sombres à long bec d'or (yeux d'or), petit tokin de braise ; deux ailes de
## plumes d'encre déployées dans le dos (lisibles du dessus) ; houppe de plumes sur le crâne. Il lance ses
## chausse-trapes (clip Throw).
static func _tengu(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.95, INK_ASH, ASH_CLOTH, FLAME, Toon.GOLD, lite, elite)
	# plastron de plumes : rangée de pointes sur la poitrine
	if not lite:
		for i in 3:
			var x := (float(i) - 1.0) * 0.14
			b.spike(Vector3(x, 1.0, -0.35), 0.05, 0.16, FEATHER, Vector3(PI + 0.4, 0, -x * 1.2), 0.0, 4, 0.4)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_CROW, 1.0, 1.0, elite)
	Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.05, 1.0, 0.1)
	# bec : long, un peu baissé, mandibule en dessous
	a.spike(Vector3(0, -0.02, Yokai.FACE_Z + 0.01), 0.075, 0.34, Yokai.BEAK, Vector3(-PI / 2.0 - 0.2, 0, 0), 0.0, 4, 0.75)
	a.spike(Vector3(0, -0.09, Yokai.FACE_Z + 0.01), 0.05, 0.2, Color("#B8822A"), Vector3(-PI / 2.0 - 0.35, 0, 0), 0.0, 4, 0.6)
	# sourcils de plumes clairs (lisibles sur le masque sombre)
	Yokai.mask_brows(a, Color("#8E8A98"), true)
	# tokin : petit bonnet de braise sur le crâne, cordon d'or (élite : bonnet d'or)
	a.cyl(Vector3(0, 0.34, Yokai.MASK_Z + 0.14), Vector3(0.11, 0.14, 0.11), Toon.GOLD if elite else EMBER, Vector3(0.25, 0, 0), 0.65, 6)
	a.cyl(Vector3(0, 0.275, Yokai.MASK_Z + 0.14), Vector3(0.12, 0.025, 0.12), Toon.GOLD, Vector3(0.25, 0, 0), 1.0, 8)
	# houppe de plumes couchées en arrière
	var n := 2 if lite else 3
	for i in n:
		var t := (float(i) - float(n - 1) * 0.5) * 0.12
		a.spike(Vector3(t, 0.26, Yokai.MASK_Z + 0.3), 0.055, 0.32, FEATHER, Vector3(-1.2, 0, -t * 2.5), 0.0, 4, 0.4)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_ASH)
	Yokai.ink_drip(d, INK_ASH)
	# ailes : plumes d'encre en éventail depuis les omoplates, ouvertes vers le haut et l'extérieur
	var x := Yokai.Mesher.new(1.0)
	var nf := 3 if lite else 4
	for s in [-1.0, 1.0]:
		var sx := float(s)
		for i in nf:
			var k := float(i) / float(nf - 1)
			var rot := Vector3(0.35 + 0.1 * k, 0, -sx * (1.45 - 0.5 * k))
			var ln := 0.78 - 0.16 * k
			x.stick(Vector3(sx * 0.28, 1.06 - 0.05 * k, 0.22 + 0.04 * k), Vector3(0.1, ln, 0.025), FEATHER, rot)
			if elite:
				var tip := Vector3(sx * 0.28, 1.06 - 0.05 * k, 0.22 + 0.04 * k) + Basis.from_euler(rot) * Vector3(0, ln, 0)
				x.ball(tip, Vector3(0.05, 0.05, 0.02), Toon.GOLD, rot, 6)
	d["fixed"] = x.mesh()


## Oni à massue : plus large ; masque bleu d'ao-oni cerné d'une crinière blanche (pointes d'ivoire), deux grandes
## cornes droites, crocs ; plastron de fer riveté d'or sur le devant (l'armure frontale) et épaulières ; kanabō.
static func _kanabo(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 1.25
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, INK_AO, ASH_CLOTH, FLAME, Toon.GOLD, lite, elite)
	# plastron : plaque de fer bombée devant, bord haut, rivets d'or
	# (sous le menton du masque, dont le bas tombe à y ≈ 1,0 : la plaque s'arrête à 0,97)
	b.box(Vector3(0, 0.76, -0.46), Vector3(0.66, 0.42, 0.09), IRON_D, Vector3(-0.08, 0, 0))
	b.box(Vector3(0, 0.955, -0.45), Vector3(0.7, 0.06, 0.12), Color("#2E2D33"), Vector3(-0.08, 0, 0))
	if not lite:
		for s in [-1.0, 1.0]:
			for j in 2:
				b.ball(Vector3(float(s) * 0.24, 0.66 + 0.2 * float(j), -0.51 + 0.02 * float(j)), Vector3(0.04, 0.04, 0.025), Toon.GOLD, Vector3.ZERO, 6)
	# épaulières de fer
	for s in [-1.0, 1.0]:
		b.box(Vector3(float(s) * 0.5 * w, 1.12, 0), Vector3(0.26, 0.09, 0.32), IRON_D, Vector3(0, 0, -float(s) * 0.4))
		b.ball(Vector3(float(s) * 0.52 * w, 1.17, 0), Vector3(0.05, 0.05, 0.05), Toon.GOLD, Vector3.ZERO, 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_AO, 1.15, 1.1, elite)
	Yokai.mask_brows(a, Toon.SUMI, true, 1.15)
	Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.055, 1.15)
	# gueule : large trait sumi, deux crocs d'ivoire
	a.box(Vector3(0, -0.15, Yokai.FACE_Z), Vector3(0.3, 0.05, 0.02), Toon.SUMI)
	for s in [-1.0, 1.0]:
		a.spike(Vector3(float(s) * 0.1, -0.13, Yokai.FACE_Z - 0.005), 0.022, 0.08, Yokai.HORN, Vector3(PI, 0, 0), 0.0, 4)
	# crinière blanche : pointes d'ivoire en couronne derrière le masque
	var n := 4 if lite else 7
	for i in n:
		var ang := -1.25 + 2.5 * float(i) / float(n - 1)
		var base := Vector3(sin(ang) * 0.36, 0.14 + 0.16 * cos(ang), Yokai.MASK_Z + 0.16)
		a.spike(base, 0.09, 0.38, Yokai.HORN, Vector3(-0.55, 0, -sin(ang) * 1.1), 0.0, 4, 0.55)
	# deux grandes cornes droites (élite : bagues d'or)
	for s in [-1.0, 1.0]:
		var base := Vector3(float(s) * 0.14, 0.33, Yokai.MASK_Z + 0.06)
		var rot := Vector3(-0.15, 0, -float(s) * 0.22)
		a.spike(base, 0.07, 0.46, Yokai.HORN, rot, 0.0, 6)
		if elite:
			a.cyl(base + Basis.from_euler(rot) * Vector3(0, 0.14, 0), Vector3(0.065, 0.05, 0.065), Toon.GOLD, rot, 0.85, 8)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_AO, 1.25)
	Yokai.ink_drip(d, INK_AO)
	d["weapon_r"] = Yokai.weapon("kanabo")


## Mōryō : petit esprit soigneur. Masque pâle dont le visage est caché par un ofuda (talisman washi au sceau de
## braise), deux lueurs bleues de part et d'autre, longues oreilles d'encre dressées, petite corne ; ofuda pendus
## à l'obi. L'orbe de bouclier vient d'enemy.gd (main droite).
static func _moryo(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.95, INK_MIST, ASH_CLOTH, FLAME, Toon.GOLD, lite, elite)
	# ofuda pendus à l'obi (un seul en mode léger)
	var hang := [Vector3(0, 0.5, -0.33)]
	if not lite:
		hang.append(Vector3(0.27, 0.52, -0.2))
		hang.append(Vector3(-0.27, 0.52, -0.2))
	for p in hang:
		var rot := Vector3(0, atan2(-p.x, -p.z), 0)  # face tournée vers l'extérieur
		b.box(p, Vector3(0.08, 0.24, 0.012), Toon.WASHI, rot)
		b.box(p + Basis.from_euler(rot) * Vector3(0, 0, -0.008), Vector3(0.03, 0.16, 0.008), EMBER, rot)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, MASK_MIST, 0.9, 0.95, elite)
	# talisman sur le visage, sceau de braise, cachet d'or
	a.box(Vector3(0, 0.0, Yokai.FACE_Z - 0.012), Vector3(0.17, 0.46, 0.016), Toon.WASHI, Vector3(0.04, 0, 0))
	a.box(Vector3(0, 0.02, Yokai.FACE_Z - 0.024), Vector3(0.05, 0.3, 0.01), EMBER, Vector3(0.04, 0, 0))
	a.box(Vector3(0, 0.17, Yokai.FACE_Z - 0.026), Vector3(0.09, 0.05, 0.01), Toon.GOLD if elite else Toon.SUMI, Vector3(0.04, 0, 0))
	# lueurs bleues qui débordent du talisman
	for s in [-1.0, 1.0]:
		f.ball(Vector3(float(s) * 0.17, 0.08, Yokai.FACE_Z), Vector3(0.05, 0.035, 0.015), EYE_SHIELD, Vector3(0, 0, -float(s) * 0.3), 6)
	# longues oreilles d'encre dressées, pavillon pâle ; élite : anneaux d'or
	for s in [-1.0, 1.0]:
		var base := Vector3(float(s) * 0.25, 0.2, Yokai.MASK_Z + 0.1)
		var rot := Vector3(-0.15, 0, -float(s) * 1.0)
		a.spike(base, 0.085, 0.58, INK_MIST, rot, 0.0, 5, 0.5)
		if not lite:
			a.spike(base + Basis.from_euler(rot) * Vector3(0, 0.03, -0.02), 0.045, 0.34, MASK_MIST, rot, 0.0, 4, 0.4)
		if elite:
			a.cyl(base + Basis.from_euler(rot) * Vector3(0, 0.3, 0), Vector3(0.06, 0.04, 0.06), Toon.GOLD, rot, 0.75, 8)
	a.spike(Vector3(0, 0.33, Yokai.MASK_Z + 0.08), 0.045, 0.2, Yokai.HORN, Vector3(-0.3, 0, 0), 0.0, 5)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK_MIST)
	Yokai.ink_drip(d, INK_MIST)
