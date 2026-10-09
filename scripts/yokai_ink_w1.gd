extends RefCounted
## Yōkai d'encre du monde 1 (Grande Vague) : oni, kappa, kappa_yumi, brute, tate, funa, umibozu, ika, umi_nyobo.
## Constructeurs appelés par yokai_parts.ink_parts (table INK_WORLD_PATHS) ; rig et animation : ink_rig.gd.
##
## ======================= Règles de la direction « Masque d'encre » (B + C, validée) =======================
## Famille. Tous les yōkai sont « nés du pinceau » : un CORPS D'ENCRE VIVANTE (Yokai.ink_body : dôme tête + torse
##   d'un bloc, qui s'effile vers le bas, bosses d'épaules, obi), des BRAS d'encre (Yokai.ink_arm), des GOUTTES qui
##   pendent et s'étirent sous le corps (Yokai.ink_drip ; ou tentacules, mèches, flammes : même emplacement « drip »).
##   Jamais de squelette blanc apparent, pas de jambes : le corps flotte, l'ombre au sol est posée par enemy.gd.
## Identité = le MASQUE DE NŌ peint sur le devant de la tête (Yokai.mask_plate + mask_brows + mask_eyes + traits),
##   expression forte lisible à 10 m : sourcils, bouche, cornes, bec, coiffe. Une idée par yōkai, visible du dessus
##   (la caméra plonge : ce qui est sur le haut de la tête compte autant que la face). Pas de masque pour les
##   créatures (umibōzu : dôme et gros yeux) mais toujours une face lisible.
## Couleurs. Encre sumi (Yokai.INK et variantes teintées : INK_SEA, INK_DEEP, INK_IKA), washi (MASK_WASHI, Toon.WASHI),
##   vermillon (Toon.VERMILION : accents, jamais en grands aplats, réservé au danger), or (Toon.GOLD : liserés,
##   parures, élite). Yeux : aplat lumineux (surface « f », Yokai.ink_flat_mat) EYE_GOLD / EYE_POND / EYE_SEA.
## Étoffe aux couleurs du monde : l'obi (et un éventuel châle, kesa, cape) porte la palette du monde — pour le
##   monde 1 : bleu de Prusse SEA_CLOTH + écume SEA_WAVE en seigaiha (Yokai.ink_body les pose), étang POND_* pour
##   les kappa. Chaque monde choisit sa paire (étoffe, motif) depuis sa palette dans worlds.gd (sky, fog, accent)
##   et la passe à ink_body(cloth, wave, line) ; le motif (écailles, flammes, flocons…) peut être ajouté à part.
## Rôle lisible de loin : mêlée = arme en main droite basse ou sur l'épaule ; distance = arme ou bras levés
##   au-dessus de la tête (ink_rig.REST_ARMS) ; soutien = objet flottant (orbe attachée par enemy.gd) ; lourd =
##   plus large (ink_body w > 1) et parure d'armure (épaulières). Le vermillon pur reste aux annonces de danger.
## Proportions. Unités du modèle, H_REF = 1,75 m pour les pièces : tête à y ≈ 1,22 (HEAD_POS), épaules à
##   (±0,40, 1,00), masque centré en z = MASK_Z (-0,36), traits à FACE_Z (-0,455) ; la hauteur réelle vient de
##   enemy.KIND_H (scale_factor = h / H_REF). Largeur du corps `w` : 0,95 (fluet) à 1,25 (brute).
## Coût. Un maillage fusionné par pièce (body, head, arm, drip, weapon_r, fixed), tout en primitives Mesher
##   (ball seg ≤ 10, cyl ≤ 14 côtés) : viser ≤ 3 500 triangles par yōkai commun (≈ 2 500 pour le corps + obi,
##   ≈ 600 pour le masque), moitié en mode léger (`lite` : moins de rangs, de mèches, de détails ; jamais de
##   pièce manquante qui changerait la silhouette). Deux matériaux par yōkai (toon à contour + aplat partagé),
##   aucun matériau nouveau dans les constructeurs : tout passe par les couleurs de sommets.
## Élite (`elite`) : même silhouette, plus riche — cerne d'or du masque (mask_plate), liserés d'or de l'obi et
##   « oreilles » d'or aux épaules (ink_body), une corne ou un ornement d'or en plus par yōkai ; l'échelle ×1,25,
##   le bouclier et l'aura viennent d'enemy.promote. Gardien / boss : hors de ce socle (boss_*.gd).
## Contrat : `kinds()` liste les genres du fichier ; `build(kind, d, lite, elite)` remplit d : "body", "head",
##   "arm", "drip" obligatoires ; "weapon_r" (unités du monde, +Y vers le bout) et "fixed" (repère du corps)
##   optionnels ; "drips" (positions des gouttes, PackedVector3Array) et "spread" (inclinaison des gouttes vers
##   l'extérieur, rad) si différents du défaut (trois gouttes sous le corps).
## ==========================================================================================================

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")


static func kinds() -> PackedStringArray:
	return PackedStringArray(["oni", "kappa", "kappa_yumi", "brute", "tate", "funa", "umibozu", "ika", "umi_nyobo"])


static func build(kind: String, d: Dictionary, lite: bool, elite: bool) -> void:
	match kind:
		"oni":
			_oni(d, lite, elite)
		"kappa":
			_kappa(d, lite, elite, false)
		"kappa_yumi":
			_kappa(d, lite, elite, true)
		"brute":
			_brute(d, lite, elite)
		"tate":
			_tate(d, lite, elite)
		"funa":
			_funa(d, lite, elite)
		"umibozu":
			_umibozu(d, lite, elite)
		"ika":
			_ika(d, lite, elite)
		"umi_nyobo":
			_nyobo(d, lite, elite)


## Oni : masque rouge cornu (sourcils froncés, yeux d'or, rictus à crocs), obi de Prusse ; massue de bois.
static func _oni(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 1.0, Yokai.INK, Yokai.SEA_CLOTH, Yokai.SEA_WAVE, Toon.GOLD, lite, elite)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.MASK_ONI, 1.0, 1.0, elite)
	Yokai.mask_brows(a, Toon.SUMI, true)
	Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.05)
	a.box(Vector3(0, -0.135, Yokai.FACE_Z), Vector3(0.24, 0.05, 0.02), Toon.SUMI)
	for s in [-1.0, 1.0]:
		a.spike(Vector3(float(s) * 0.07, -0.11, Yokai.FACE_Z - 0.005), 0.018, 0.06, Yokai.HORN, Vector3(PI, 0, 0), 0.0, 4)
		# cornes : penchées vers l'extérieur et en arrière
		a.spike(Vector3(float(s) * 0.16, 0.3, Yokai.MASK_Z + 0.04), 0.06, 0.32, Yokai.HORN, Vector3(-0.3, 0, -float(s) * 0.5), 0.0, 6)
	if elite:
		a.spike(Vector3(0, 0.34, Yokai.MASK_Z + 0.06), 0.045, 0.24, Toon.GOLD, Vector3(-0.2, 0, 0), 0.0, 5)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK)
	Yokai.ink_drip(d, Yokai.INK)
	d["weapon_r"] = Yokai.weapon("club_wood")


## Kappa : masque vert à bec d'or, coupelle d'eau cerclée de paille, carapace dans le dos, obi d'étang ; bâton.
## Archer (`yumi`) : hachimaki vermillon, carapace plus petite, grand arc fixé au flanc gauche.
static func _kappa(d: Dictionary, lite: bool, elite: bool, yumi: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 1.0, Yokai.INK, Yokai.POND_CLOTH, Yokai.POND_WAVE, Toon.VERMILION, lite, elite)
	# carapace : dôme olive dans le dos, plaques sombres
	var sh := 0.8 if yumi else 1.0
	b.ball(Vector3(0, 0.98, 0.3), Vector3(0.33 * sh, 0.4 * sh, 0.14), Color("#5E6B3A"), Vector3(0.15, 0, 0), 8)
	if not lite:
		for p in [Vector3(0, 1.08, 0.42), Vector3(0.15, 0.9, 0.4), Vector3(-0.15, 0.9, 0.4)]:
			b.ball(p * Vector3(sh, 1.0, 1.0), Vector3(0.09 * sh, 0.1 * sh, 0.03), Color("#4A5530"), Vector3(0.15, 0, 0), 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.MASK_YUMI if yumi else Yokai.MASK_KAPPA, 1.0, 1.0, elite)
	Yokai.mask_brows(a, Toon.SUMI, true)
	Yokai.mask_eyes(f, Yokai.EYE_POND, 0.045)
	# bec : pointe d'or vers l'avant, un peu baissée
	a.spike(Vector3(0, -0.1, Yokai.FACE_Z + 0.01), 0.065, 0.14, Yokai.BEAK, Vector3(-PI / 2.0 - 0.25, 0, 0), 0.0, 4, 0.6)
	# coupelle : disque de paille, eau claire (aplat)
	a.cyl(Vector3(0, 0.33, Yokai.MASK_Z + 0.22), Vector3(0.2, 0.045, 0.2), Yokai.STRAW, Vector3.ZERO, 1.0, 12)
	f.ball(Vector3(0, 0.355, Yokai.MASK_Z + 0.22), Vector3(0.15, 0.012, 0.15), Yokai.WATER, Vector3.ZERO, 10)
	if yumi:
		a.cyl(Vector3(0, 0.2, Yokai.MASK_Z + 0.2), Vector3(0.33, 0.05, 0.31), Toon.VERMILION, Vector3.ZERO, 1.0, 12)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK)
	Yokai.ink_drip(d, Yokai.INK)
	if yumi:
		# grand arc (yumi) : deux branches cambrées vers l'arrière, corde claire
		var x := Yokai.Mesher.new(1.0)
		x.stick(Vector3(-0.5, 0.95, -0.15), Vector3(0.035, 0.75, 0.035), Yokai.WOOD_D, Vector3(0.3, 0, 0))
		x.stick(Vector3(-0.5, 0.95, -0.15), Vector3(0.035, 0.75, 0.035), Yokai.WOOD_D, Vector3(PI - 0.3, 0, 0))
		x.box(Vector3(-0.5, 0.95, -0.15), Vector3(0.05, 0.16, 0.05), Yokai.LACE)
		x.box(Vector3(-0.5, 0.95, -0.15 + 0.75 * sin(0.3)), Vector3(0.012, 1.5 * cos(0.3), 0.012), Toon.WASHI)
		d["fixed"] = x.mesh()
	else:
		d["weapon_r"] = Yokai.weapon("staff")


## Brute : plus large ; masque de fer à cornes d'or (kuwagata), menpō rouge à moustache, épaulières ; kanabō.
static func _brute(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 1.25
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, Yokai.INK, Yokai.SEA_CLOTH, Yokai.SEA_WAVE, Toon.GOLD, lite, elite)
	for s in [-1.0, 1.0]:
		b.box(Vector3(float(s) * 0.47 * w, 1.1, 0), Vector3(0.22, 0.08, 0.3), Yokai.LACQUER, Vector3(0, 0, -float(s) * 0.35))
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.IRON, 1.15, 1.1, elite)
	Yokai.mask_brows(a, Toon.SUMI, true, 1.15)
	Yokai.mask_eyes(f, Yokai.EYE_GOLD, 0.055, 1.15)
	a.box(Vector3(0, -0.16, Yokai.FACE_Z), Vector3(0.32, 0.12, 0.02), Color("#7E2A22"))
	if not lite:
		for s in [-1.0, 1.0]:
			a.box(Vector3(float(s) * 0.09, -0.11, Yokai.FACE_Z - 0.008), Vector3(0.14, 0.03, 0.02), Toon.WASHI, Vector3(0, 0, -float(s) * 0.3))
	for s in [-1.0, 1.0]:
		a.spike(Vector3(float(s) * 0.1, 0.38, Yokai.MASK_Z + 0.05), 0.08, 0.4, Toon.GOLD, Vector3(-0.2, 0, -float(s) * 0.55), 0.0, 4, 0.3)
	a.cyl(Vector3(0, 0.4, Yokai.MASK_Z + 0.03), Vector3(0.08, 0.03, 0.08), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 8)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK, 1.2)
	Yokai.ink_drip(d, Yokai.INK)
	d["weapon_r"] = Yokai.weapon("kanabo")


## Porte-bouclier : masque washi sévère sous un eboshi laqué ; grand bouclier rond fixé devant le flanc gauche ;
## sabre court.
static func _tate(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 1.05, Yokai.INK, Yokai.SEA_CLOTH, Yokai.SEA_WAVE, Toon.GOLD, lite, elite)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.MASK_WASHI, 1.0, 1.0, elite)
	Yokai.mask_brows(a, Toon.SUMI, true)
	Yokai.mask_eyes(f, Toon.SUMI, 0.04)
	a.box(Vector3(0, -0.14, Yokai.FACE_Z), Vector3(0.12, 0.03, 0.02), Toon.SUMI)
	if not lite:
		for s in [-1.0, 1.0]:
			a.box(Vector3(float(s) * 0.2, -0.02, Yokai.FACE_Z), Vector3(0.025, 0.14, 0.015), Toon.VERMILION, Vector3(0, 0, float(s) * 0.2))
	# eboshi : haut bonnet laqué penché en arrière
	a.cyl(Vector3(0, 0.44, Yokai.MASK_Z + 0.26), Vector3(0.18, 0.34, 0.15), Yokai.LACQUER, Vector3(0.35, 0, 0), 0.55, 8)
	a.cyl(Vector3(0, 0.27, Yokai.MASK_Z + 0.22), Vector3(0.31, 0.06, 0.28), Yokai.LACQUER, Vector3.ZERO, 1.0, 10)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK)
	Yokai.ink_drip(d, Yokai.INK)
	# bouclier : bordure sumi, disque de bois, bosse d'or (élite : bordure d'or)
	var x := Yokai.Mesher.new(1.0)
	var at := Vector3(-0.3, 0.92, -0.5)
	var r := Vector3(PI / 2.0, 0, 0)
	x.cyl(at, Vector3(0.52, 0.05, 0.52), Toon.GOLD if elite else Toon.SUMI, r, 1.0, 16)
	x.cyl(at + Vector3(0, 0, -0.02), Vector3(0.45, 0.06, 0.45), Toon.WOOD, r, 1.0, 16)
	if not lite:
		x.cyl(at + Vector3(0, 0, -0.045), Vector3(0.28, 0.02, 0.28), Yokai.SEA_CLOTH, r, 1.0, 14)
	x.ball(at + Vector3(0, 0, -0.06), Vector3(0.11, 0.11, 0.05), Toon.GOLD, Vector3.ZERO, 8)
	d["fixed"] = x.mesh()
	d["weapon_r"] = Yokai.weapon("blade", 0.55)


## Noyé (funa-yūrei) : encre bleutée, masque pâle au triangle des morts, bouche tombante, mèches trempées ; louche.
static func _funa(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.95, Yokai.INK_SEA, Color("#243F5E"), Color("#CFE3EA"), Color("#7FB2C8"), lite, elite)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.MASK_DROWN, 0.95, 1.0, elite)
	Yokai.mask_brows(a, Toon.SUMI, false)
	Yokai.mask_eyes(f, Yokai.EYE_SEA, 0.045, 1.0, 0.05)
	# bouche tombante : trait et deux coins qui descendent
	a.box(Vector3(0, -0.13, Yokai.FACE_Z), Vector3(0.12, 0.028, 0.02), Toon.SUMI)
	for s in [-1.0, 1.0]:
		a.box(Vector3(float(s) * 0.085, -0.15, Yokai.FACE_Z), Vector3(0.06, 0.026, 0.02), Toon.SUMI, Vector3(0, 0, float(s) * 0.7))
	a.spike(Vector3(0, 0.17, Yokai.FACE_Z + 0.005), 0.075, 0.13, Toon.WASHI, Vector3(-0.1, 0, 0), 0.0, 3, 0.25)
	# cheveux trempés : calotte, mèches qui pendent sur les côtés et devant
	a.ball(Vector3(0, 0.27, Yokai.MASK_Z + 0.16), Vector3(0.33, 0.13, 0.28), Yokai.HAIR, Vector3.ZERO, 8)
	var locks := [Vector3(-0.26, 0.0, -0.3), Vector3(0.27, 0.02, -0.28)]
	if not lite:
		locks.append(Vector3(0.1, 0.1, -0.42))
	for p in locks:
		a.stick(p, Vector3(0.06, 0.5, 0.045), Yokai.HAIR, Vector3(PI, 0, 0))
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK_SEA)
	Yokai.ink_drip(d, Yokai.INK_SEA)
	d["weapon_r"] = Yokai.weapon("ladle")


## Umibōzu : moine de mer géant, pas de masque : dôme lisse d'encre d'abysse, deux gros yeux d'or ; kesa d'or
## en écharpe, chapelet. La perle lumineuse vient d'enemy.gd (main droite).
static func _umibozu(d: Dictionary, lite: bool, elite: bool) -> void:
	var w := 1.2
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, w, Yokai.INK_DEEP, Color("#1A2E48"), Color("#8FA6BA"), Toon.GOLD, lite, elite)
	# kesa : disque d'or en biais à travers le corps (ne dépasse qu'en bande)
	b.cyl(Vector3(0, 0.95, 0), Vector3(0.45 * w + 0.02, 0.07, 0.43 * w + 0.02), Toon.GOLD, Vector3(0, 0, 0.55), 1.0, 14)
	var n := 6 if lite else 10
	for i in n:
		var ang := TAU * float(i) / float(n)
		b.ball(Vector3(sin(ang) * 0.46 * w, 1.1 + 0.03 * sin(ang * 2.0), cos(ang) * 0.44 * w), Vector3.ONE * 0.06, Color("#6E3A2A"), Vector3.ZERO, 6)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	a.ball(Vector3(0, 0.08, -0.06), Vector3(0.5, 0.46, 0.48), Yokai.DOME, Vector3.ZERO, 12)
	if elite:
		a.cyl(Vector3(0, -0.2, -0.06), Vector3(0.49, 0.04, 0.47), Toon.GOLD, Vector3.ZERO, 1.0, 14)
	for s in [-1.0, 1.0]:
		f.ball(Vector3(float(s) * 0.2, 0.02, -0.46), Vector3(0.12, 0.13, 0.05), Yokai.EYE_GOLD, Vector3.ZERO, 8)
		f.ball(Vector3(float(s) * 0.2, 0.0, -0.5), Vector3(0.05, 0.065, 0.02), Toon.SUMI, Vector3.ZERO, 6)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK_DEEP, 1.15)
	Yokai.ink_drip(d, Yokai.INK_DEEP)


## Calmar d'encre : capuche-manteau pointue à nageoires, masque rose aux grands yeux noirs ; six tentacules
## à la place des gouttes (ils ondulent).
static func _ika(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.95, Yokai.INK_IKA, Color("#4A2A5A"), Yokai.SQUID_L, Color("#E8B4DC"), lite, elite)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.MASK_IKA, 0.9, 0.9, elite)
	for s in [-1.0, 1.0]:
		f.ball(Vector3(float(s) * 0.11, 0.05, Yokai.FACE_Z), Vector3(0.075, 0.085, 0.02), Toon.SUMI, Vector3.ZERO, 8)
		f.ball(Vector3(float(s) * 0.135, 0.085, Yokai.FACE_Z - 0.015), Vector3(0.025, 0.025, 0.01), Toon.WASHI, Vector3.ZERO, 6)
	a.spike(Vector3(0, -0.12, Yokai.FACE_Z + 0.01), 0.035, 0.07, Toon.SUMI, Vector3(-PI / 2.0 - 0.3, 0, 0), 0.0, 4, 0.6)
	# manteau : cône rose vers le haut, un peu en arrière ; nageoires de côté ; taches
	a.spike(Vector3(0, 0.18, -0.06), 0.36, 0.88, Yokai.SQUID, Vector3(0.15, 0, 0), 0.0, 8)
	for s in [-1.0, 1.0]:
		a.spike(Vector3(float(s) * 0.12, 0.6, 0.0), 0.2, 0.38, Yokai.SQUID_D, Vector3(0, 0, -float(s) * 1.3), 0.0, 3, 0.2)
	if not lite:
		for p in [Vector3(0.15, 0.45, -0.22), Vector3(-0.17, 0.55, -0.18), Vector3(0.02, 0.75, -0.12)]:
			a.ball(p, Vector3(0.05, 0.05, 0.035), Color("#8E3F78"), Vector3.ZERO, 6)
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK_IKA)
	var t := Yokai.Mesher.new(1.0)
	t.spike(Vector3.ZERO, 0.075, 0.55, Yokai.SQUID_L, Vector3(PI, 0, 0), 0.2, 5)
	t.ball(Vector3.ZERO, Vector3(0.08, 0.06, 0.08), Yokai.INK_IKA, Vector3.ZERO, 6)
	d["drip"] = t.mesh()
	var n := 4 if lite else 6
	var pts := PackedVector3Array()
	for i in n:
		var ang := TAU * (float(i) + 0.5) / float(n)
		pts.append(Vector3(sin(ang) * 0.19, 0.42, cos(ang) * 0.18))
	d["drips"] = pts
	d["spread"] = 0.4


## Umi-nyōbō : masque de ko-omote (sourcils hauts, yeux mi-clos, petite bouche rouge), chevelure d'algues en
## longues mèches, coquillage et peigne, collier d'algues ; obi d'étang. La perle de soin vient d'enemy.gd.
static func _nyobo(d: Dictionary, lite: bool, elite: bool) -> void:
	var b := Yokai.Mesher.new(1.0)
	Yokai.ink_body(b, 0.95, Yokai.INK, Yokai.POND_CLOTH, Yokai.POND_WAVE, Yokai.SHELL, lite, elite)
	b.cyl(Vector3(0, 1.1, 0), Vector3(0.44, 0.1, 0.42), Yokai.WEED_L, Vector3.ZERO, 0.75, 10)
	d["body"] = b.mesh()
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	Yokai.mask_plate(a, Yokai.MASK_NYOBO, 0.9, 0.95, elite)
	Yokai.mask_brows(a, Toon.SUMI, false, 0.9)
	for s in [-1.0, 1.0]:
		a.box(Vector3(float(s) * 0.1, 0.06, Yokai.FACE_Z), Vector3(0.09, 0.024, 0.015), Toon.SUMI)
		f.ball(Vector3(float(s) * 0.1, 0.045, Yokai.FACE_Z - 0.01), Vector3(0.02, 0.014, 0.01), Color("#7FE0A8"), Vector3.ZERO, 6)
	a.box(Vector3(0, -0.12, Yokai.FACE_Z), Vector3(0.08, 0.035, 0.02), Toon.VERMILION)
	a.ball(Vector3(0, 0.24, Yokai.MASK_Z + 0.24), Vector3(0.35, 0.17, 0.31), Yokai.WEED, Vector3.ZERO, 8)
	for s in [-1.0, 1.0]:
		a.stick(Vector3(float(s) * 0.3, 0.2, -0.2), Vector3(0.1, 0.8, 0.07), Yokai.WEED, Vector3(PI, 0, -float(s) * 0.08))
	a.ball(Vector3(0.27, 0.33, -0.16), Vector3(0.11, 0.05, 0.1), Yokai.SHELL, Vector3(0, 0, -0.4), 8)
	a.box(Vector3(-0.16, 0.37, -0.14), Vector3(0.12, 0.03, 0.04), Toon.GOLD, Vector3(0, 0, 0.3))
	d["head"] = Yokai.two(a, f)
	Yokai.ink_arm(d, Yokai.INK)
	Yokai.ink_drip(d, Yokai.INK)
