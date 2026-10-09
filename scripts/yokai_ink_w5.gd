extends RefCounted
## Yōkai d'encre du monde 5 (Trente-six Vues : encre, papier, Fuji) : kagebo, sumidama (et sumidama_s), kasa.
## Règles de la direction « Masque d'encre » : en tête de yokai_ink_w1.gd. Constructeurs appelés par
## yokai_parts.ink_parts (table INK_WORLD_PATHS) ; rig et animation : ink_rig.gd.
## Étoffe du monde (design/PALETTES.md) : obi d'indigo nuit NIGHT, écailles de papier PAPER, liseré au rouge du
## sceau SEAL (le seul rouge du monde) ; l'encre est le sumi le plus pur du jeu (INK5).

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")

const INK5 := Color("#17151C")  # sumi pur
const INK_MASK := Color("#2A2733")  # masque vide du double : à peine plus clair que l'encre
const VOID := Color("#07060A")  # trous des yeux
const SCARF := Color("#6E6A78")  # l'écharpe blanche du héros, vue en encre
const NIGHT := Color("#1B2A44")  # indigo nuit
const PAPER := Color("#CFC6B2")  # papier vieilli (écailles)
const PAPER_L := Color("#EAE2CF")  # papier du parapluie
const SEAL := Color("#9E3028")  # sceau du peintre
const RIB := Color("#2A2228")  # baleines du parapluie


static func kinds() -> PackedStringArray:
	return PackedStringArray(["kagebo", "sumidama", "sumidama_s", "kasa"])


static func build(kind: String, d: Dictionary, lite: bool, elite: bool) -> void:
	match kind:
		"kagebo":
			_kagebo(d, lite, elite)
		"sumidama", "sumidama_s":
			_sumidama(d, lite, elite)
		"kasa":
			_kasa(d, lite, elite)


## Kagebō : le double d'encre du héros. Silhouette d'encre pure (obi d'indigo à peine lisible, écharpe grise,
## nœud vermillon du héros), masque VIDE : plaque d'encre au liseré vermillon, deux trous d'yeux sans lueur,
## larmes d'encre ; katana de sumi en main droite basse. Il rejoue le trait du héros (clip Slice).
static func _kagebo(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 1.0, INK5, NIGHT, Color("#3C3A48"), Color("#4A4652"), lite, elite)
	# écharpe du héros, en encre grise : anneau au cou, deux pans dans le dos
	b.cyl(Vector3(0, 1.08, 0), Vector3(0.45, 0.1, 0.43), SCARF, Vector3(0.1, 0, 0), 0.82, 10)
	for s in [-1.0, 1.0]:
		b.stick(Vector3(float(s) * 0.12, 1.05, 0.4), Vector3(0.1, 0.5, 0.03), SCARF, Vector3(PI - 0.35, 0, -float(s) * 0.2))
	# nœud vermillon de l'obi (le seul accent du héros qu'il garde)
	b.ball(Vector3(0.14, 0.66, -0.33), Vector3(0.055, 0.045, 0.03), Toon.VERMILION, Vector3.ZERO, 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, INK_MASK, 1.0, 1.0, elite)
	# liseré vermillon du masque du héros, sur le bord haut
	a.box(Vector3(0, 0.3, Yokai.MASK_Z - 0.06), Vector3(0.36, 0.022, 0.03), Toon.VERMILION, Vector3(0.25, 0, 0))
	# trous d'yeux : rien ne brille (surface toon, pas d'aplat)
	for s in [-1.0, 1.0]:
		a.ball(Vector3(float(s) * 0.115, 0.06, Yokai.FACE_Z), Vector3(0.06, 0.05, 0.015), VOID, Vector3.ZERO, 8)
		if not lite:
			a.box(Vector3(float(s) * 0.115, -0.08, Yokai.FACE_Z), Vector3(0.02, 0.2, 0.012), VOID)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK5)
	Yokai.ink_drip(d, INK5)
	# katana d'encre (unités du monde) : poignée, tsuba, lame sumi au fil gris
	var k := Yokai.Mesher.new(1.0)
	k.box(Vector3(0, -0.02, 0), Vector3(0.05, 0.24, 0.05), Color("#2A2530"))
	k.cyl(Vector3(0, 0.1, 0), Vector3(0.07, 0.02, 0.07), Toon.GOLD if elite else Color("#3A3644"), Vector3.ZERO, 1.0, 8)
	k.box(Vector3(0, 0.52, 0), Vector3(0.03, 0.82, 0.07), Color("#1E1C24"))
	k.box(Vector3(0, 0.52, -0.034), Vector3(0.014, 0.82, 0.012), SCARF)
	d["weapon_r"] = k.mesh()


## Sumidama : goutte tombée du pinceau, une créature sans masque. Grosse goutte d'encre à pointe penchée, deux
## gros yeux washi et une petite bouche ronde ; moignons de bras ; gouttelettes tout autour à la place des gouttes.
## La petite (sumidama_s) est la même, à l'échelle d'enemy.gd.
static func _sumidama(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	b.ball(Vector3(0, 0.84, 0), Vector3(0.5, 0.52, 0.5), INK5, Vector3.ZERO, 12)
	b.spike(Vector3(0, 1.28, 0.04), 0.16, 0.4, INK5, Vector3(0.4, 0, 0), 0.0, 7)
	if elite:
		b.cyl(Vector3(0, 1.32, 0.06), Vector3(0.12, 0.035, 0.12), Toon.GOLD, Vector3(0.4, 0, 0), 0.85, 8)
	if not lite:
		# éclaboussures figées sur le flanc
		for p in [Vector3(0.44, 0.62, -0.18), Vector3(-0.4, 0.55, 0.22), Vector3(0.1, 0.5, 0.46)]:
			b.ball(p, Vector3(0.09, 0.12, 0.09), Toon.GOLD if elite else INK5, Vector3.ZERO, 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	for s in [-1.0, 1.0]:
		f.ball(Vector3(float(s) * 0.17, -0.3, -0.36), Vector3(0.11, 0.12, 0.03), Toon.WASHI, Vector3.ZERO, 8)
		f.ball(Vector3(float(s) * 0.17, -0.31, -0.385), Vector3(0.05, 0.055, 0.015), Toon.SUMI, Vector3.ZERO, 6)
	f.ball(Vector3(0, -0.5, -0.33), Vector3(0.045, 0.035, 0.02), Toon.WASHI, Vector3.ZERO, 6)
	a.ball(Vector3(0, -0.5, -0.345), Vector3(0.028, 0.02, 0.015), Toon.SUMI, Vector3.ZERO, 6)
	d["head"] = Yokai.two(a, f)
	var arm := Yokai.Mesher.new(1.0)
	arm.cyl(Vector3(0, -0.1, 0), Vector3(0.075, 0.2, 0.075), INK5, Vector3(PI, 0, 0), 0.6, 6)
	arm.ball(Vector3(0, -0.2, 0), Vector3(0.08, 0.065, 0.08), INK5, Vector3.ZERO, 6)
	d["arm"] = arm.mesh()
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.065, 0.08, 0.065), INK5, Vector3.ZERO, 6)
	t.spike(Vector3.ZERO, 0.055, 0.15, INK5, Vector3(PI, 0, 0), 0.3, 5)
	t.ball(Vector3(0, -0.16, 0), Vector3(0.05, 0.055, 0.05), INK5, Vector3.ZERO, 6)
	d["drip"] = t.mesh()
	var n := 3 if lite else 4
	var pts := PackedVector3Array()
	for i in n:
		var ang := TAU * (float(i) + 0.5) / float(n)
		pts.append(Vector3(sin(ang) * 0.3, 0.42, cos(ang) * 0.3))
	d["drips"] = pts
	d["spread"] = 0.35


## Kasa-obake : le parapluie est la tête. Large canopée de papier à baleines (un disque du dessus), virole
## d'encre ; dessous, un seul grand œil, bouche et longue langue au rouge du sceau ; corps d'encre fluet, une
## jambe unique chaussée d'un geta à la place des gouttes. Il bondit (enemy.gd le fait tourner en l'air).
static func _kasa(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.7, INK5, NIGHT, PAPER, SEAL, lite, elite)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	# pan de papier replié devant (la plaque du masque), un seul œil, bouche, langue
	Yokai.mask_plate(a, PAPER_L, 0.85, 0.9, elite)
	f.ball(Vector3(0, 0.03, Yokai.FACE_Z), Vector3(0.13, 0.14, 0.02), Toon.WASHI, Vector3.ZERO, 10)
	f.ball(Vector3(0, 0.02, Yokai.FACE_Z - 0.015), Vector3(0.06, 0.07, 0.01), Toon.SUMI, Vector3.ZERO, 8)
	a.box(Vector3(0, 0.17, Yokai.FACE_Z), Vector3(0.26, 0.03, 0.02), Toon.SUMI, Vector3(0, 0, 0.0))
	a.box(Vector3(0, -0.15, Yokai.FACE_Z), Vector3(0.16, 0.03, 0.02), Toon.SUMI)
	a.stick(Vector3(0, -0.16, Yokai.FACE_Z - 0.01), Vector3(0.1, 0.3, 0.025), SEAL, Vector3(PI - 0.6, 0, 0))
	# canopée : cône de papier large et plat, bord d'encre, baleines, virole (élite : d'or)
	var cz := Yokai.MASK_Z + 0.3
	var cy := 0.3
	a.cyl(Vector3(0, cy + 0.17, cz), Vector3(0.74, 0.34, 0.74), PAPER_L, Vector3(0.12, 0, 0), 0.06, 10)
	a.cyl(Vector3(0, cy, cz), Vector3(0.75, 0.04, 0.75), INK5, Vector3(0.12, 0, 0), 1.0, 10)
	a.spike(Vector3(0, cy + 0.33, cz - 0.02), 0.04, 0.14, Toon.GOLD if elite else INK5, Vector3(0.12, 0, 0), 0.3, 5)
	if not lite:
		var slope := -atan2(0.74, 0.34)
		for i in 10:
			var ang := TAU * (float(i) + 0.5) / 10.0
			var m := Basis.from_euler(Vector3(0.12, 0, 0))
			var pos := Vector3(0, cy + 0.17, cz) + m * Vector3(sin(ang) * 0.37, 0, cos(ang) * 0.37)
			a.box(pos, Vector3(0.022, 0.8, 0.022), RIB, Vector3(slope, ang, 0) + Vector3(0.12, 0, 0))
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, INK5, 0.8)
	# jambe unique : encre qui s'étire, geta de bois
	var t := Yokai.Mesher.new(1.0)
	t.ball(Vector3.ZERO, Vector3(0.1, 0.07, 0.1), INK5, Vector3.ZERO, 6)
	t.cyl(Vector3(0, -0.14, 0), Vector3(0.065, 0.28, 0.065), INK5, Vector3(PI, 0, 0), 0.75, 7)
	t.box(Vector3(0, -0.3, -0.05), Vector3(0.15, 0.04, 0.3), Toon.WOOD)
	if not lite:
		for z in [-0.14, 0.06]:
			t.box(Vector3(0, -0.34, z), Vector3(0.13, 0.04, 0.04), Yokai.WOOD_D)
	d["drip"] = t.mesh()
	d["drips"] = PackedVector3Array([Vector3(0, 0.36, 0)])
	d["spread"] = 0.01  # une seule jambe (garde la liste en mode léger)
