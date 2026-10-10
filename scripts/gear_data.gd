extends RefCounted
## Pinceaux et omamori (maquettes Pinceaux.dc.html et Omamori.dc.html, validées par le propriétaire).
##
## PINCEAUX : l'arme du jeu. Chacun change la règle du trait (pas seulement les chiffres) ; trois aspects
## par pinceau : le premier est acquis avec le pinceau, les deux autres se gagnent, dans l'ordre, en battant
## un boss de monde avec ce pinceau équipé (meta.on_world_won). Le geste du doigt ne change jamais : la lecture
## des figures (raw, points du trait) est la même pour tous ; seuls le rendu du trait (ink_stroke) et son
## effet (main._check_slashes) changent.
##
## OMAMORI : un seul charme par partie, gagné au rang Maître (極) du monde correspondant (le rang Maître exige
## le boss : score.rank_of). Il pend à la ceinture du héros (hero.set_charm) et brille quand il agit.

const ORDER := ["fude", "hake", "menso", "warefude", "chi"]
const BRUSHES := {
	"fude": {"name": "FUDE", "word": "Fude", "jp": "筆", "sub": "pinceau de base", "col": Color("#1B1A1E"), "world": 0,
		"how": "Offert",
		"rule": "Le trait de référence : élan moyen, épais au départ, effilé au bout.",
		"aspects": [["Maître", "Aucun changement. Le pinceau de référence."],
			["Pluie", "Le trait sèche en gouttes d'encre qui ralentissent 1,5 s les ennemis qui marchent dessus."],
			["Vent", "Élan +2 m, mais dégâts −10 %. Pour enchaîner les figures longues."]]},
	"hake": {"name": "HAKE", "word": "Hake", "jp": "刷毛", "sub": "pinceau large", "col": Color("#C49A45"), "world": 1,
		"how": "Battre le boss du monde 1",
		"rule": "Trait court (élan −40 %) mais très large : il touche tout ce qu'il frôle.",
		"aspects": [["Large", "Largeur ×3, élan −40 %."],
			["Mur", "Le trait posé bloque les projectiles ennemis pendant 1 s."],
			["Balai", "Les ennemis touchés sont repoussés de 2 m dans le sens du trait."]]},
	"menso": {"name": "MENSO", "word": "Menso", "jp": "面相", "sub": "pinceau fin", "col": Color("#1F3A5F"), "world": 2,
		"how": "Battre le boss du monde 2",
		"rule": "Trait long et fin (élan +30 %). Critique garanti au centre d'un ennemi.",
		"aspects": [["Fin", "Élan +30 %, largeur ÷2, critique au centre."],
			["Aiguille", "Un critique déclenche aussi la technique de la figure en cours de tracé."],
			["Fil", "Le trait traverse : chaque ennemi transpercé ajoute +1 à la chaîne."]]},
	"warefude": {"name": "WAREFUDE", "word": "Warefude", "jp": "割筆", "sub": "pinceau fendu", "col": Color("#A8436B"), "world": 4,
		"how": "Battre le boss du monde 4",
		"rule": "Deux lignes parallèles écartées de 1,2 m, 60 % des dégâts chacune.",
		"aspects": [["Fendu", "Deux lignes, 60 % des dégâts chacune."],
			["Jumeaux", "Les lignes s'écartent avec la longueur du trait : étroit au départ, large au bout."],
			["Tresse", "Les lignes se croisent en vague ; chaque croisement éclate en petite onde."]]},
	"chi": {"name": "CALAME DE SANG", "word": "Calame de sang", "jp": "血筆", "sub": "chi-fude", "col": Color("#8E2A1E"), "world": 6,
		"how": "Battre le boss du monde 6",
		"rule": "Dégâts +40 %. Au-delà de 8 m de trait, chaque mètre coûte un peu de vie (jamais le dernier cœur).",
		"aspects": [["Sang", "Dégâts +40 %, trait long payé en vie."],
			["Pacte", "Une figure qui tue rend un demi-cœur."],
			["Démon", "À 2 cœurs ou moins, dégâts ×1,5 de plus."]]},
}

## Réglages des pinceaux
const VENT_ELAN := 2.0  # Fude · Vent : mètres d'élan en plus
const VENT_DMG := 0.9
const PLUIE_STEP := 1.1  # Fude · Pluie : une goutte tous les 1,1 m de trait
const PLUIE_LIFE := 4.0  # durée d'une goutte au sol (s)
const PLUIE_R := 0.55  # rayon de contact d'une goutte
const PLUIE_SLOW := 1.5  # ralenti (s)
const HAKE_ELAN := 0.6
const HAKE_REACH := 1.5  # portée latérale du coup (HIT_REACH = 0,55) : il touche ce qu'il frôle
const HAKE_WALL_T := 1.0  # Hake · Mur
const HAKE_PUSH := 16.0  # Hake · Balai : élan de recul (enemy._knock, amorti ×8/s : ~2 m)
const MENSO_ELAN := 1.3
const MENSO_REACH := 0.28  # largeur ÷2
const MENSO_CENTER := 0.45  # part du rayon de l'ennemi où le trait est « au centre »
const MENSO_CRIT := 2.0
const SPLIT_DMG := 0.6  # Warefude : chaque ligne
const SPLIT_REACH := 0.4
const SPLIT_HALF := 0.6  # demi-écart (1,2 m entre les lignes)
const TRESSE_WAVE := 3.2  # longueur d'onde de la tresse (m) : un croisement tous les 1,6 m
const TRESSE_R := 1.3
const TRESSE_DMG := 0.5
const CHI_DMG := 1.4
const CHI_FREE := 8.0  # mètres de trait gratuits
const CHI_COST := 0.1  # cœur par mètre au-delà (dette cumulée, jamais le dernier cœur)
const CHI_DEMON := 1.5
const CHI_DEMON_HP := 2

const CHARM_ORDER := ["garde", "encre", "portes", "sceaux", "pacte", "or", "figure", "ascete"]
const CHARMS := {
	"garde": {"name": "Omamori de la garde", "short": "Garde", "col": Color("#C49A45"), "world": 1,
		"effect": "Le premier coup reçu à chaque étape est annulé."},
	"encre": {"name": "Omamori de l'encre", "short": "Encre", "col": Color("#1F3A5F"), "world": 2,
		"effect": "La jauge d'encre démarre pleine, et déborde, à chaque combat."},
	"portes": {"name": "Omamori des portes", "short": "Portes", "col": Color("#A8436B"), "world": 3,
		"effect": "Une fois par monde, une troisième porte à sceau apparaît au choix des portes."},
	"sceaux": {"name": "Omamori des sceaux", "short": "Sceaux", "col": Color("#7A3E9D"), "world": 4,
		"effect": "Monstres scellés : n'importe quelle figure brise leur sceau."},
	"pacte": {"name": "Omamori du pacte", "short": "Pacte", "col": Color("#8E2A1E"), "world": 5,
		"effect": "Un refus de pacte gratuit par monde, même sans or."},
	"or": {"name": "Omamori de l'or", "short": "Or", "col": Color("#E2A93B"), "world": 6,
		"effect": "Or doublé dans les coffres scellés et les sceaux d'or."},
	"figure": {"name": "Omamori de la figure", "short": "Figure", "col": Color("#4F8A3C"), "world": 7,
		"effect": "La première figure de chaque combat déclenche sa technique deux fois."},
	"ascete": {"name": "Omamori de l'ascète", "short": "Ascète", "col": Color("#5A5148"), "world": 8,
		"effect": "Aucun cœur ne se soigne pendant la partie, mais dégâts +25 % et points +25 %."},
}
const ENCRE_FILL := 1.5  # Encre : la jauge démarre à 150 % (pleine, et la moitié en réserve d'or)
const ASCETE_DMG := 1.25
const ASCETE_PTS := 1.25


static func brush(id: String) -> Dictionary:
	return BRUSHES.get(id, BRUSHES["fude"])


static func charm(id: String) -> Dictionary:
	return CHARMS.get(id, {})


static func aspect_name(id: String, k: int) -> String:
	var asp: Array = brush(id)["aspects"]
	return String(asp[clampi(k, 0, asp.size() - 1)][0])


static func aspect_text(id: String, k: int) -> String:
	var asp: Array = brush(id)["aspects"]
	return String(asp[clampi(k, 0, asp.size() - 1)][1])


## « Fude · Maître »
static func label(id: String, k: int) -> String:
	return "%s · %s" % [String(brush(id)["word"]), aspect_name(id, k)]


## Couleur d'encre du trait : Fude garde l'encre de l'Atelier (alpha 0), les autres ont la leur.
static func ink_of(id: String) -> Color:
	if id == "fude" or not BRUSHES.has(id):
		return Color(0, 0, 0, 0)
	return brush(id)["col"]


## Largeur du trait dessiné (×WIDTH d'ink_stroke).
static func width_k(id: String) -> float:
	match id:
		"hake":
			return 3.0
		"menso":
			return 0.5
		"warefude":
			return 0.55
	return 1.0


## Warefude : demi-écart signé de la ligne A à l'abscisse `s` (m) le long du trait (la ligne B est en face).
static func split_off(k: int, s: float) -> float:
	match k:
		1:
			return minf(0.2 + 0.07 * maxf(s, 0.0), 1.3)  # Jumeaux : étroit au départ, large au bout
		2:
			return SPLIT_HALF * sin(TAU * maxf(s, 0.0) / TRESSE_WAVE)  # Tresse : elles se croisent
	return SPLIT_HALF


# ------------------------------------------------------------------ dessin 2D (écrans)

## Omamori dessiné (gabarit 40 × 56 des maquettes) centré sur `c`, hauteur 56·s. `on` : sinon grisé.
static func draw_charm(ci: CanvasItem, id: String, c: Vector2, s: float, a: float, on := true) -> void:
	var cd := charm(id)
	var col: Color = cd.get("col", Color("#5A5148")) if on else Color("#3A342E")
	var cord := Color("#D7372B") if on else Color("#5A5148")
	var o := c - Vector2(20, 28) * s
	var k := 1.0 if on else 0.55
	var aa := a * k
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	# cordon
	var lp := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		lp.append(P.call(14.0 + 12.0 * t, 6.0 - 5.0 * sin(PI * t)))
	ci.draw_polyline(lp, Color(cord, aa), maxf(1.0, 2.5 * s), true)
	ci.draw_circle(P.call(20, 8), 2.6 * s, Color(cord, aa))
	# sachet : coins du haut arrondis, cerné de sumi
	var body := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		body.append(P.call(8.0 + 24.0 * t, 16.0 - 6.5 * sin(PI * t)))
	body.append(P.call(32, 50))
	body.append(P.call(30.5, 53.5))
	body.append(P.call(9.5, 53.5))
	body.append(P.call(8, 50))
	ci.draw_colored_polygon(body, Color(col, aa))
	var closed := body.duplicate()
	closed.append(body[0])
	ci.draw_polyline(closed, Color(Color("#1B1A1E"), aa), maxf(1.0, 2.0 * s), true)
	# plaque de papier et glyphe
	ci.draw_rect(Rect2(P.call(12, 20), Vector2(16, 26) * s), Color(Color("#F5EEDD"), 0.92 * aa))
	var w := maxf(1.0, 2.6 * s)
	var gc := Color(col, aa)
	match id:
		"garde":
			var sh := PackedVector2Array([P.call(20, 24), P.call(26, 27), P.call(26, 33), P.call(24.5, 38.5), P.call(20, 42), P.call(15.5, 38.5), P.call(14, 33), P.call(14, 27), P.call(20, 24)])
			ci.draw_polyline(sh, gc, w, true)
		"encre":
			var dp := PackedVector2Array([P.call(20, 24)])
			dp.append(P.call(24.5, 30.5))
			for i in 9:
				var ang := -0.15 + PI * 1.3 * float(i) / 8.0
				dp.append(P.call(20.0 + 6.0 * cos(ang), 36.0 + 6.0 * sin(ang)))
			dp.append(P.call(15.5, 30.5))
			dp.append(P.call(20, 24))
			ci.draw_polyline(dp, gc, w, true)
		"portes":
			ci.draw_line(P.call(13, 42), P.call(13, 28), gc, w, true)
			ci.draw_line(P.call(27, 42), P.call(27, 28), gc, w, true)
			ci.draw_line(P.call(11, 28), P.call(29, 28), gc, w, true)
			ci.draw_line(P.call(12, 32), P.call(28, 32), gc, w, true)
		"sceaux":
			ci.draw_polyline(PackedVector2Array([P.call(14, 33), P.call(14, 42), P.call(26, 42), P.call(26, 33), P.call(14, 33)]), gc, w, true)
			ci.draw_arc(P.call(20, 29), 4.0 * s, PI, TAU, 10, gc, w, true)
			ci.draw_line(P.call(16, 29), P.call(16, 33), gc, w, true)
			ci.draw_line(P.call(24, 29), P.call(24, 33), gc, w, true)
		"pacte":
			ci.draw_line(P.call(14, 26), P.call(26, 40), gc, w, true)
			ci.draw_line(P.call(26, 26), P.call(14, 40), gc, w, true)
		"or":
			ci.draw_arc(P.call(20, 33), 7.0 * s, 0.0, TAU, 20, gc, w, true)
			ci.draw_line(P.call(20, 29), P.call(20, 37), gc, w, true)
		"figure":
			var fp := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				fp.append(_bez(P.call(15, 38), P.call(15, 28), P.call(25, 28), P.call(25, 33), t))
			for i in range(1, 9):
				var t := float(i) / 8.0
				fp.append(_bez(P.call(25, 33), P.call(25, 37), P.call(19, 37), P.call(19, 33), t))
			ci.draw_polyline(fp, gc, w, true)
		_:
			ci.draw_line(P.call(20, 25), P.call(20, 41), gc, w, true)
			ci.draw_line(P.call(14, 31), P.call(26, 31), gc, w, true)


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t


## Trait d'un pinceau dans un cadre (aperçu de l'écran de départ, vignettes des résultats) : chemin de la
## maquette (repère 362 × 300), forme du pinceau et de l'aspect, `reveal` 0..1 (le trait se pose).
static func draw_brush(ci: CanvasItem, id: String, k: int, r: Rect2, a: float, reveal := 1.0, enemies := true) -> void:
	var sx := r.size.x / 362.0
	var sy := r.size.y / 300.0
	var sc := minf(sx, sy)
	var o := r.position
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x * sx, y * sy)
	var col: Color = brush(id)["col"]
	if enemies:
		for e in [[236, 96], [288, 170], [170, 150]]:
			ci.draw_circle(P.call(float(e[0]), float(e[1])), 13.0 * sc, Color(Color("#5A5148"), 0.22 * a))
	# chemin : courbe de la maquette (H), raccourcie (Hake) ou allongée (Menso, Vent)
	var c0 := [Vector2(70, 226), Vector2(110, 190), Vector2(150, 160), Vector2(190, 140)]
	var c1 := [Vector2(190, 140), Vector2(230, 120), Vector2(260, 112), Vector2(300, 96)]
	var span := 1.0
	match id:
		"hake":
			span = 0.62
		"menso":
			span = 1.16
	if id == "fude" and k == 2:
		span = 1.14
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var t := span * float(i) / float(n)
		var p: Vector2
		if t <= 1.0:
			var tt := t * 2.0
			p = _bez(c0[0], c0[1], c0[2], c0[3], tt) if tt <= 1.0 else _bez(c1[0], c1[1], c1[2], c1[3], tt - 1.0)
		else:
			p = Vector2(300, 96) + Vector2(40, -14) * ((t - 1.0) / 0.16)
		pts.append(p)
	var m := maxi(2, int(float(pts.size()) * clampf(reveal, 0.0, 1.0)))
	var base_w := 9.0 * width_k(id) * (1.1 if id == "hake" else 1.0)
	var ink := Color(col, 0.95 * a)
	if id == "warefude":
		# deux lignes, écart selon l'aspect (en « mètres » d'aperçu : 1 m ≈ 16 px)
		var la := PackedVector2Array()
		var lb := PackedVector2Array()
		var s := 0.0
		for i in m:
			var p: Vector2 = pts[i]
			if i > 0:
				s += p.distance_to(pts[i - 1]) / 16.0
			var tg: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var nv := Vector2(-tg.y, tg.x)
			var off := split_off(k, s) * 16.0
			la.append(P.call(p.x + nv.x * off, p.y + nv.y * off))
			lb.append(P.call(p.x - nv.x * off, p.y - nv.y * off))
			if k == 2 and i > 0:
				var prev := split_off(k, s - pts[i].distance_to(pts[i - 1]) / 16.0)
				if signf(prev) != signf(split_off(k, s)) and s > 0.5:
					ci.draw_arc(P.call(p.x, p.y), 9.0 * sc, 0.0, TAU, 16, Color(col, 0.6 * a), 2.0 * sc, true)
		ci.draw_polyline(la, ink, 6.0 * sc, true)
		ci.draw_polyline(lb, ink, 6.0 * sc, true)
	else:
		# trait plein, effilé au bout (segments de largeur décroissante)
		for i in range(1, m):
			var u := float(i) / float(pts.size())
			var w := base_w * lerpf(1.0, (0.55 if id == "hake" else 0.35), u * u) * sc
			ci.draw_line(P.call(pts[i - 1].x, pts[i - 1].y), P.call(pts[i].x, pts[i].y), ink, maxf(1.0, w), true)
			ci.draw_circle(P.call(pts[i].x, pts[i].y), maxf(0.5, w * 0.5), ink)
	# marques des aspects
	var last: Vector2 = pts[m - 1]
	if id == "fude" and k == 1:
		for i in range(4, m, 6):
			ci.draw_circle(P.call(pts[i].x + 10.0, pts[i].y + 12.0), 4.0 * sc, Color(col, 0.55 * a))
	if id == "menso" and m >= int(pts.size() * 0.55):
		ci.draw_circle(P.call(236, 96), 6.0 * sc, Color(Color("#E2A93B"), a))
		if k == 2:
			ci.draw_circle(P.call(170, 150), 5.0 * sc, Color(Color("#E2A93B"), 0.8 * a))
	if id == "chi":
		var cnt := 0
		for i in range(int(pts.size() * 0.62), m, 4):
			ci.draw_circle(P.call(pts[i].x + (6.0 if cnt % 2 == 0 else -5.0), pts[i].y + 8.0), (3.0 + float(cnt % 3)) * sc, Color(Color("#D7372B"), a))
			cnt += 1
	if id == "hake" and k == 1:
		ci.draw_line(P.call(last.x + 10, last.y - 30), P.call(last.x + 10, last.y + 30), Color(col, 0.5 * a), 4.0 * sc, true)
	if id == "hake" and k == 2:
		for e in [[236, 96], [170, 150]]:
			var ep := Vector2(float(e[0]), float(e[1]))
			ci.draw_line(P.call(ep.x - 16, ep.y + 8), P.call(ep.x + 6, ep.y - 3), Color(col, 0.7 * a), 3.0 * sc, true)
	# le héros (point vermillon) au départ du trait
	ci.draw_circle(P.call(70, 226), 16.0 * sc, Color(Color("#1B1A1E"), 0.12 * a))
	ci.draw_circle(P.call(70, 226), 7.0 * sc, Color(Color("#D7372B"), a))
