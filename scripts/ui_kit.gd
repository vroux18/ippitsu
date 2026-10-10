extends RefCounted
## Petits outils partagés par les écrans dessinés : polices, texte sans macrons, horloge réelle,
## courbe d'arrivée, texte centré, coupe de lignes, StyleBoxFlat réutilisée, pictogrammes (glyph,
## pouvoirs, figures, estampes) et aire de polygone.

const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")
const Toon = preload("res://scripts/toon.gd")
const UIColors = preload("res://scripts/ui_colors.gd")  # jetons de couleur du handoff UI v2 (theme.json)
const Icons = preload("res://scripts/ui_icons.gd")  # sources SVG des pictogrammes v2 (res://ui/icons)
# UI v2 : plus de kanji dans l'interface (seul le logo 一筆 de l'accueil reste) : les sceaux à côté des titres
# d'écran et de section ne se dessinent plus (screen_title, section)
const KANJI_SEALS := false
# les six figures, dans l'ordre d'affichage
const FIGURES := ["straight", "return", "zigzag", "loop", "enso", "hook"]

# ================================================================== système de design
# Mesures en unités u (largeur de l'écran / 400) : on multiplie par u au dessin. Accueil, pause,
# résultats, options, mes pouvoirs, atelier et garde-robe puisent ici (composants plus bas :
# screen_title, back_button, section, chip, sheet, seigaiha, asanoha, mon, shuriken, kunai).

# --- échelle typographique (taille × u) ; TITLE_FONT : titres, noms ; num_font() : tous les chiffres (UI v2 :
# Zen Kaku Gothic New Black, chiffres tabulaires, jamais Shippori qui décale la ligne de base) ; UI_FONT : le reste
const FS_DISPLAY := 34.0  # mot-événement (VICTOIRE), un seul par écran
const FS_TITLE := 24.0  # titre d'écran (OPTIONS, MES POUVOIRS, ATELIER, GARDE-ROBE, PAUSE)
const FS_HEADING := 15.0  # nom d'une carte, d'un élément, titre d'une bulle
const FS_NUMBER := 19.0  # chiffre mis en avant (étape, score, compteur)
const FS_LABEL := 12.0  # libellé de bouton, de segment, d'onglet
const FS_BODY := 11.0  # texte courant, effets, descriptions
const FS_CAPTION := 10.0  # petites capitales de section, légendes (encre à 55 %)
const FS_MICRO := 8.5  # rubans, badges, prix dans une tuile : plancher lisible au téléphone
const TITLE_SPACING := 4  # espacement des lettres (px) du titre d'écran
const CAPS_SPACING := 1  # espacement des petites capitales (UI_FONT)

# --- espacements (× u)
const SP_XS := 4.0
const SP_S := 8.0
const SP_M := 14.0  # marge d'écran, marge intérieure d'une carte
const SP_L := 22.0
const SP_XL := 36.0

# --- rayons des coins (× u) ; pilules (puces, segments, prix) : la moitié de la hauteur
const R_S := 8.0  # encarts dans une carte, petites pastilles carrées
const R_M := 14.0  # tuiles de grille, barre d'information
const R_L := 18.0  # feuilles et panneaux

# --- épaisseurs de trait (× u, jamais sous 1 px)
const BW_HAIR := 1.0  # filet, contour d'une puce éteinte
const BW := 1.5  # cadre d'une tuile ordinaire
const BW_STRONG := 2.5  # cadre choisi, rareté, sceau

# --- ombre portée : une seule, douce et vers le bas
const SHADOW_A := 0.3  # opacité (× alpha de l'écran)
const SHADOW_Y := 4.0  # décalage vertical (× u)
const SHADOW_SIZE := 10.0  # flou (× u)

# --- boutons (hauteur × u) et icônes
const BTN_HERO_H := 78.0  # pinceau JOUER de l'accueil
const BTN_MAIN_H := 64.0  # pinceau principal (REJOUER, REPRENDRE, MONDE SUIVANT)
const BTN_H := 46.0  # bouton secondaire (texte, fantôme, ACHETER)
const BTN_SMALL_H := 28.0  # prix dans une tuile (la tuile entière est la cible)
const ICON_BTN := 46.0  # bouton rond à icône : retour, réglages, son (diamètre)
const ICON_MIN := 28.0  # plus petite cible tactile
const ICON_GLYPH := 0.5  # pictogramme d'un bouton rond : moitié de son rayon
const HEAD_X := 37.0  # centre du bouton retour depuis le bord gauche (de l'écran ou de la carte)
const HEAD_Y := 39.0  # centre vertical de l'en-tête (sous l'encoche, ou depuis le haut de la carte), comme la carte des mondes
const HEAD_BASE := 49.0  # ligne de base du titre d'écran, même repère que HEAD_Y
# retour : maison (écran plein qui ramène à l'accueil : carte, atelier, garde-robe) ;
# flèche (fenêtre qui se referme sur l'écran d'avant : options, mes pouvoirs)

# --- puces, segments, pilules
const SEG_H := 40.0  # onglets principaux (commande segmentée)
const CHIP_H := 30.0  # filtres, onglets secondaires
const OPT_H := 44.0  # choix d'une option (segment en pilule)

# --- palette : règles d'usage
# sumi (Toon.ui_ink) : texte, boutons principaux, segment actif ;
# washi (Toon.ui_paper, Toon.ui_wash) : feuilles, cartes, fonds clairs ;
# vermillon (Toon.VERMILION) : l'accent unique (souligné de titre, choix en cours, confirmation, sceaux) ;
# or : récompenses et monnaies (GOLD_INK sur papier clair, GOLD_HI sur fond sombre : voir gold()) ;
# indigo (INDIGO) : information, aide, rareté « rare ».
const GOLD_INK := Color("#9A6B12")
const GOLD_HI := Color("#E2A93B")
const INDIGO := Color("#2F5D8A")
# opacités de l'encre : texte 1, secondaire, légende, désactivé, filet, lavis, motif de fond
const A_SUB := 0.6
const A_CAPTION := 0.5
const A_DIM := 0.3
const A_RULE := 0.15
const A_WASH := 0.05
const A_PATTERN := 0.06

static var _last_ms := 0
static var _frame := -1
static var _delta := 0.0


## Les polices réduites n'ont pas les voyelles longues (ō, ū) : on les écrit sans macron.
static func plain(s: String) -> String:
	return s.replace("Ō", "O").replace("ō", "o").replace("Ū", "U").replace("ū", "u")


## Temps réel écoulé depuis l'image précédente (indépendant du ralenti et de la pause),
## le même pour tous les écrans pendant une image.
static func real_delta() -> float:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		var now := Time.get_ticks_msec()
		_delta = 0.0 if _last_ms == 0 else minf(float(now - _last_ms) / 1000.0, 0.1)
		_last_ms = now
	return _delta


## Delta d'image ramené au temps réel (s'arrête quand le jeu est figé : time_scale = 0).
static func unscaled(delta: float, cap := 0.1) -> float:
	return minf(delta / maxf(Engine.time_scale, 0.0001), cap)


static func ease_out(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


## Texte centré horizontalement sur `center.x` (ligne de base en `center.y`) ; renvoie sa largeur.
static func text(ci: CanvasItem, font: Font, txt: String, center: Vector2, fs: int, c: Color) -> float:
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, Vector2(center.x - tw / 2.0, center.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return tw


## Remet à neuf une StyleBoxFlat réutilisée : fond, coins, bordure facultative, sans ombre.
## draw_style_box dessine tout de suite : on peut la reconfigurer pour le tracé suivant.
static func box(sb: StyleBoxFlat, bg: Color, radius := 0, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2.ZERO
	return sb


## Symbole d'une figure au pinceau, dans un sceau rond de rayon r (même dessin que le HUD).
static func figure(ci: CanvasItem, shape: String, c: Vector2, r: float, a: float) -> void:
	ci.draw_circle(c, r + 2.5 * r / 30.0, Color(Toon.ui_ink, 0.85 * a))
	ci.draw_circle(c, r, Color(Toon.ui_paper, 0.95 * a))
	var ink := Color(Toon.ui_ink, a)
	var w := 4.0 * r / 30.0
	var s := r * 0.62
	match shape:
		"loop":
			var pts := PackedVector2Array()
			for i in 40:
				var t := float(i) / 39.0
				pts.append(c + Vector2.from_angle(t * TAU * 1.75) * s * (0.15 + 0.85 * t))
			ci.draw_polyline(pts, ink, w, true)
		"zigzag":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.6, -0.9) * s, c + Vector2(0.25, -0.15) * s, c + Vector2(-0.25, 0.1) * s, c + Vector2(0.6, 0.9) * s]), Color(Toon.GOLD.darkened(0.2), a), w * 1.2, true)
		"straight":
			ci.draw_line(c + Vector2(-0.95, 0.55) * s, c + Vector2(0.95, -0.55) * s, ink, w * 1.3, true)
			ci.draw_line(c + Vector2(-0.6, 0.55) * s, c + Vector2(0.95, -0.35) * s, Color(Toon.VERMILION, a * 0.8), w * 0.5, true)
		"return":
			ci.draw_arc(c + Vector2(0, -0.1) * s, s * 0.55, PI, TAU, 16, ink, w, true)
			ci.draw_line(c + Vector2(-0.55, -0.1) * s, c + Vector2(-0.55, 0.8) * s, ink, w, true)
			ci.draw_line(c + Vector2(0.55, -0.1) * s, c + Vector2(0.55, 0.6) * s, ink, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.3, 0.55) * s, c + Vector2(0.8, 0.55) * s, c + Vector2(0.55, 0.95) * s]), ink)
		"enso":
			ci.draw_arc(c, s * 0.85, -PI * 0.35, PI * 1.5, 32, ink, w * 1.5, true)
			ci.draw_circle(c + Vector2.from_angle(-PI * 0.35) * s * 0.85, w * 0.9, ink)
		"hook":
			ci.draw_line(c + Vector2(0.35, -0.9) * s, c + Vector2(0.35, 0.3) * s, ink, w, true)
			ci.draw_arc(c + Vector2(0.0, 0.3) * s, s * 0.35, 0.0, PI, 14, ink, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.35, 0.3) * s, c + Vector2(-0.6, 0.0) * s, c + Vector2(-0.2, 0.05) * s]), ink)


## Geste d'une figure, en coordonnées 0..1 du cadre (tracé de bas en haut, comme au doigt).
## Partagé par le tutoriel (coach.gd) et le carnet du dojo (dojo.gd).
static func gesture_points(kind: String) -> PackedVector2Array:
	var p := PackedVector2Array()
	match kind:
		"loop":
			for i in 41:
				var t := float(i) / 40.0
				var base := Vector2(0.5, 0.92 - 0.82 * t)
				var lp := clampf((t - 0.3) / 0.4, 0.0, 1.0)
				if lp > 0.0 and lp < 1.0:
					base += Vector2(sin(lp * TAU) * 0.22, (1.0 - cos(lp * TAU)) * 0.12)
				p.append(base)
		"zigzag":
			var zz := [Vector2(0.5, 0.92), Vector2(0.2, 0.7), Vector2(0.8, 0.5), Vector2(0.2, 0.3), Vector2(0.75, 0.1)]
			for i in range(zz.size() - 1):
				var za: Vector2 = zz[i]
				var zb: Vector2 = zz[i + 1]
				for j in 6:
					p.append(za.lerp(zb, j / 6.0))
			p.append(zz[zz.size() - 1])
		"straight":
			for i in 13:
				p.append(Vector2(0.5, 0.95 - 0.9 * i / 12.0))
		"return":
			for i in 13:
				p.append(Vector2(0.44, 0.9 - 0.75 * i / 12.0))
			for i in range(1, 13):
				p.append(Vector2(0.54, 0.15 + 0.73 * i / 12.0))
		"hook":
			for i in 13:
				p.append(Vector2(0.35 + 0.15 * i / 12.0, 0.9 - 0.75 * i / 12.0))
			for i in range(1, 9):
				p.append(Vector2(0.5 + 0.3 * i / 8.0, 0.15 + 0.4 * i / 8.0))
		_:
			for i in 41:
				var ang := PI / 2.0 + TAU * 0.92 * i / 40.0
				p.append(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * 0.4)
	return p


## La figure se trace en boucle dans un petit cadre (t : horloge en secondes). col : encre du tracé
## (alpha 0 : papier clair sur cadre d'encre) ; light : cadre clair teinté de col ; start : marque le point
## de départ d'un petit rond (sens du geste). sb : StyleBoxFlat réutilisée par l'écran qui dessine.
static func draw_gesture(ci: CanvasItem, sb: StyleBoxFlat, kind: String, frame: Rect2, u: float, a: float, t: float,
		col := Color(0, 0, 0, 0), light := false, start := false) -> void:
	var c := Toon.WASHI if col.a <= 0.0 else Color(col, 1.0)
	if light:
		ci.draw_style_box(box(sb, Color(c, 0.12 * a), int(8.0 * u), Color(c, 0.6 * a), int(maxf(1.0, 1.2 * u))), frame)
	else:
		ci.draw_style_box(box(sb, Color(Toon.SUMI, 0.9 * a), int(8.0 * u)), frame)
	var inner := frame.grow(-8.0 * u)
	var pts := gesture_points(kind)
	var k := clampf(fmod(maxf(t, 0.0), 2.2) / 1.6, 0.0, 1.0)
	var n := int(k * float(pts.size() - 1))
	var mapped := PackedVector2Array()
	for p in pts:
		mapped.append(inner.position + p * inner.size)
	ci.draw_polyline(mapped, Color(c, 0.2 * a), 2.0 * u, true)
	if start:
		# point de départ : seul accent, toujours vermillon (planches monotones du coach et du carnet)
		ci.draw_circle(mapped[0], 3.5 * u, Color(Toon.VERMILION, 0.9 * a))
	if n >= 1:
		ci.draw_polyline(mapped.slice(0, n + 1), Color(c, a), 2.5 * u, true)
	ci.draw_circle(mapped[n], 4.0 * u, Color(Toon.VERMILION, 0.9 * a))


## Vignette d'une Vue (meta.PRINTS) : ciel en bokashi, Fuji enneigé, sol, cartouche et filet.
static func print_thumb(ci: CanvasItem, r: Rect2, p: Dictionary, u: float, a := 1.0) -> void:
	var sky: Color = p.get("sky", Toon.WASHI)
	var fuji: Color = p.get("fuji", Toon.PRUSSIAN)
	var ground: Color = p.get("ground", Toon.WOOD)
	var fx := float(p.get("fx", 0.5))
	var x0 := r.position.x
	var y0 := r.position.y
	var xe := r.end.x
	var hz := y0 + r.size.y * 0.64
	var top := sky.lerp(Toon.PRUSSIAN, 0.35)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(xe, y0), Vector2(xe, hz), Vector2(x0, hz)]),
		PackedColorArray([Color(top, a), Color(top, a), Color(sky, a), Color(sky, a)]))
	var cx := clampf(x0 + r.size.x * fx, x0 + r.size.x * 0.3, xe - r.size.x * 0.3)
	var peak := hz - r.size.y * 0.4
	var bw := r.size.x * 0.3
	var tw := r.size.x * 0.05
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - bw, hz), Vector2(cx - tw, peak), Vector2(cx + tw, peak), Vector2(cx + bw, hz)]), Color(fuji, a))
	var sd := (hz - peak) * 0.32
	var sx := tw + (bw - tw) * 0.32
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - tw, peak), Vector2(cx + tw, peak), Vector2(cx + sx, peak + sd),
		Vector2(cx + sx * 0.3, peak + sd * 0.7), Vector2(cx - sx * 0.2, peak + sd * 1.05), Vector2(cx - sx, peak + sd)]), Color(Toon.WASHI, a))
	ci.draw_rect(Rect2(Vector2(x0, hz), Vector2(r.size.x, r.end.y - hz)), Color(ground, a))
	var cart := Rect2(r.position + Vector2(3, 3) * u, Vector2(4, 12) * u)
	ci.draw_rect(cart, Color(Color("#E8D9A8"), a))
	ci.draw_rect(r, Color(Toon.SUMI, 0.7 * a), false, 1.2 * u)


# ------------------------------------------------------------------ pictogrammes des pouvoirs
# Tout est dessiné en coordonnées unité (environ -1..1, y vers le bas), mis à l'échelle du rayon r.
# glyph() : un pictogramme nommé ; `bg` sert aux découpes (yeux, reflets), ignorées s'il est transparent.

const Data = preload("res://scripts/power_data.gd")
const NONE := Color(0, 0, 0, 0)

static var _shapes := {}  # polygones unité, calculés une fois


## Nom du pictogramme d'un pouvoir (champ « icon », sinon celui de son école).
static func icon_of(id: String) -> String:
	var d: Dictionary = Data.POWERS.get(id, {})
	if d.is_empty():
		return "ink"
	return String(d.get("icon", d.get("school", "ink")))


static func power_school(id: String) -> String:
	var d: Dictionary = Data.POWERS.get(id, {})
	return String(d.get("school", "ink"))


## Couleur d'un pouvoir : celle de son élément ; les rouleaux de figure prennent l'élément de leur technique
## (boucle = vent, zigzag = foudre, retour = eau, crochet = ombre, trait droit et ensō = encre).
const FIG_COLOR_SCHOOL := {"loop": "wind", "zigzag": "bolt", "return": "water", "hook": "shadow", "straight": "ink", "enso": "ink"}


static func power_color(id: String) -> Color:
	var school := power_school(id)
	if school == "fig":
		for f in FIG_COLOR_SCHOOL.keys():
			if id.begins_with("fig_" + String(f)):
				return school_color(String(FIG_COLOR_SCHOOL[f]))
	return school_color(school)


static func school_color(school: String) -> Color:
	var sd: Dictionary = Data.SCHOOLS.get(school, {})
	return sd.get("color", Toon.SUMI)


## Nom court en français (champ « label », sinon le nom), sans macrons.
static func power_label(id: String) -> String:
	var d: Dictionary = Data.POWERS.get(id, {})
	if d.is_empty():
		return id
	return plain(String(d.get("label", d.get("name", id))))


## Pictogramme d'école seul (couleur `col`), dans un rayon r.
static func school_icon(ci: CanvasItem, school: String, c: Vector2, r: float, col: Color, a := 1.0, bg := NONE) -> void:
	glyph(ci, school, c, r, col, bg, a)


## Pictogramme propre d'un pouvoir, couleur `col` (découpes en `bg`).
static func power_glyph(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color, bg := NONE, a := 1.0) -> void:
	glyph(ci, icon_of(id), c, r, col, bg, a)


## Pastille complète : disque de la couleur d'école, pictogramme du pouvoir en papier.
static func power_icon(ci: CanvasItem, id: String, c: Vector2, r: float, a := 1.0) -> void:
	var col := power_color(id)
	ci.draw_circle(c, r, Color(col, a))
	# léger relief : lune plus claire en haut
	ci.draw_circle(c + Vector2(0, -r * 0.18), r * 0.78, Color(col.lightened(0.12), 0.5 * a))
	glyph(ci, icon_of(id), c, r * 0.64, Toon.WASHI, col, a)


## Déclencheur d'un pouvoir (champ « trig ») en petit pictogramme.
static func trigger_icon(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color, bg := NONE, a := 1.0) -> void:
	var d: Dictionary = Data.POWERS.get(id, {})
	glyph(ci, "t_" + String(d.get("trig", "always")), c, r, col, bg, a)


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)


static func _shape(name: String) -> PackedVector2Array:
	if _shapes.has(name):
		return _shapes[name]
	var p := PackedVector2Array()
	match name:
		"flame":
			for i in 13:
				var t := PI * float(i) / 12.0
				p.append(Vector2(0, 0.3) + Vector2(cos(t), sin(t)) * 0.6)
			for i in range(1, 11):
				p.append(_bez(Vector2(-0.6, 0.3), Vector2(-0.68, -0.4), Vector2(0.1, -1.0), float(i) / 10.0))
			for i in range(1, 10):
				p.append(_bez(Vector2(0.1, -1.0), Vector2(0.72, -0.35), Vector2(0.6, 0.3), float(i) / 10.0))
		"drop":
			for i in 15:
				var t := lerpf(-0.46, PI + 0.46, float(i) / 14.0)
				p.append(Vector2(0, 0.35) + Vector2(cos(t), sin(t)) * 0.6)
			p.append(Vector2(0, -1.0))
		"heart":
			for i in 28:
				var t := TAU * float(i) / 28.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				p.append(Vector2(x, -y) / 16.0 + Vector2(0, -0.12))
		"bolt":
			p = PackedVector2Array([Vector2(0.25, -1.0), Vector2(-0.5, 0.12), Vector2(-0.05, 0.12), Vector2(-0.3, 1.0), Vector2(0.5, -0.2), Vector2(0.05, -0.2)])
		"crescent":
			for i in 17:
				var t := lerpf(0.35 * PI, 1.65 * PI, float(i) / 16.0)
				p.append(Vector2(cos(t), sin(t)))
			for j in range(1, 12):
				var f := 1.5 * PI - PI * float(j) / 12.0
				p.append(Vector2(0.44, 0) + Vector2(cos(f), sin(f)) * 0.89)
		"shield":
			p = PackedVector2Array([Vector2(-0.75, -0.8), Vector2(0.75, -0.8), Vector2(0.75, -0.15)])
			for i in range(1, 9):
				p.append(_bez(Vector2(0.75, -0.15), Vector2(0.7, 0.55), Vector2(0, 0.98), float(i) / 8.0))
			for i in range(1, 9):
				p.append(_bez(Vector2(0, 0.98), Vector2(-0.7, 0.55), Vector2(-0.75, -0.15), float(i) / 8.0))
		"great_wave":
			p = PackedVector2Array([Vector2(1, 0.85), Vector2(1, 0.1), Vector2(0.7, -0.5), Vector2(0.25, -0.85), Vector2(-0.2, -0.85),
				Vector2(-0.55, -0.55), Vector2(-0.62, -0.18), Vector2(-0.35, -0.35), Vector2(-0.05, -0.4), Vector2(0.2, -0.15),
				Vector2(0.1, 0.2), Vector2(-0.4, 0.5), Vector2(-1, 0.6), Vector2(-1, 0.85)])
		"ghost":
			for i in 13:
				var t := PI + PI * float(i) / 12.0
				p.append(Vector2(0, -0.2) + Vector2(cos(t), sin(t)) * 0.68)
			p.append_array(PackedVector2Array([Vector2(0.68, 0.85), Vector2(0.45, 0.62), Vector2(0.23, 0.88), Vector2(0, 0.62),
				Vector2(-0.23, 0.88), Vector2(-0.45, 0.62), Vector2(-0.68, 0.85)]))
		"hood":
			for i in 13:
				var t := PI + PI * float(i) / 12.0
				p.append(Vector2(0, -0.1) + Vector2(cos(t), sin(t)) * 0.8)
			p.append_array(PackedVector2Array([Vector2(0.8, 0.95), Vector2(0.4, 0.8), Vector2(0, 0.95), Vector2(-0.4, 0.8), Vector2(-0.8, 0.95)]))
		"fox":
			p = PackedVector2Array([Vector2(-0.85, -0.9), Vector2(-0.3, -0.42), Vector2(0.3, -0.42), Vector2(0.85, -0.9),
				Vector2(0.72, 0.05), Vector2(0, 0.88), Vector2(-0.72, 0.05)])
		"leaf":
			for i in 13:
				var x := -1.0 + 2.0 * float(i) / 12.0
				p.append(Vector2(x, -0.32 * sin(PI * (x + 1.0) / 2.0)))
			for i in range(11, 0, -1):
				var x := -1.0 + 2.0 * float(i) / 12.0
				p.append(Vector2(x, 0.22 * sin(PI * (x + 1.0) / 2.0)))
		"chevron":
			p = PackedVector2Array([Vector2(-0.05, -0.75), Vector2(0.4, -0.75), Vector2(0.95, 0), Vector2(0.4, 0.75), Vector2(-0.05, 0.75), Vector2(0.5, 0)])
		"bag":
			p = PackedVector2Array([Vector2(-0.55, 0.92), Vector2(-0.55, -0.32), Vector2(-0.28, -0.58), Vector2(0.28, -0.58), Vector2(0.55, -0.32), Vector2(0.55, 0.92)])
		"star4", "star5", "star8":
			var n := 4
			var inner := 0.36
			if name == "star5":
				n = 5
				inner = 0.45
			elif name == "star8":
				n = 8
				inner = 0.42
			for i in n * 2:
				var t := -PI / 2.0 + PI * float(i) / float(n)
				p.append(Vector2(cos(t), sin(t)) * (1.0 if i % 2 == 0 else inner))
	_shapes[name] = p
	return p


## Polygone plein, bord adouci d'un fin contour.
static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	# polygone minuscule (pictogramme qui apparaît à l'échelle 0) : la triangulation échouerait
	if pts.size() < 3 or absf(poly_area(pts)) < 0.6:
		return
	ci.draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, col, 1.0, true)


static func _shp(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, off := Vector2.ZERO, k := 1.0, rot := 0.0) -> void:
	_poly(ci, Transform2D(rot, Vector2(s * k, s * k), 0.0, c + off * s) * _shape(name), col)


static func _ln(ci: CanvasItem, c: Vector2, s: float, p0: Vector2, p1: Vector2, col: Color, w: float) -> void:
	ci.draw_line(c + p0 * s, c + p1 * s, col, w, true)


static func _pl(ci: CanvasItem, c: Vector2, s: float, pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_polyline(Transform2D(0.0, Vector2(s, s), 0.0, c) * pts, col, w, true)


static func _dot(ci: CanvasItem, c: Vector2, s: float, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + p * s, r * s, col)


static func _arc(ci: CanvasItem, c: Vector2, s: float, p: Vector2, r: float, a0: float, a1: float, col: Color, w: float) -> void:
	ci.draw_arc(c + p * s, r * s, a0, a1, 28, col, w, true)


static func _box(ci: CanvasItem, c: Vector2, s: float, p0: Vector2, p1: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(c + p0 * s, (p1 - p0) * s), col)


static func _ellipse(ci: CanvasItem, c: Vector2, s: float, p: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var t := TAU * float(i) / 16.0
		pts.append(c + (p + Vector2(cos(t) * rx, sin(t) * ry).rotated(rot)) * s)
	_poly(ci, pts, col)


## Trait effilé de p0 (épais) à p1 (fin), largeurs en unités.
static func _taper(ci: CanvasItem, c: Vector2, s: float, p0: Vector2, p1: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	_poly(ci, PackedVector2Array([c + (p0 + n * w0 / 2.0) * s, c + (p1 + n * w1 / 2.0) * s, c + (p1 - n * w1 / 2.0) * s, c + (p0 - n * w0 / 2.0) * s]), col)


## Arc effilé aux deux bouts (lame de vent).
static func _sweep(ci: CanvasItem, c: Vector2, s: float, p: Vector2, r: float, a0: float, a1: float, wmax: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var t := float(i) / n
		var ang := lerpf(a0, a1, t)
		pts.append(c + (p + Vector2(cos(ang), sin(ang)) * (r + wmax * sin(PI * t) / 2.0)) * s)
	for i in range(n - 1, 0, -1):
		var t := float(i) / n
		var ang := lerpf(a0, a1, t)
		pts.append(c + (p + Vector2(cos(ang), sin(ang)) * (r - wmax * sin(PI * t) / 2.0)) * s)
	_poly(ci, pts, col)


static func _head(ci: CanvasItem, c: Vector2, s: float, tip: Vector2, dir: Vector2, size: float, col: Color) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	_poly(ci, PackedVector2Array([c + tip * s, c + (tip - d * size + n * size * 0.62) * s, c + (tip - d * size - n * size * 0.62) * s]), col)


## Silhouette (tête et épaules) centrée en p, taille k.
static func _person(ci: CanvasItem, c: Vector2, s: float, p: Vector2, k: float, col: Color) -> void:
	ci.draw_circle(c + (p + Vector2(0, -0.35) * k) * s, 0.26 * k * s, col)
	var pts := PackedVector2Array()
	for i in 13:
		var t := PI + PI * float(i) / 12.0
		pts.append(c + (p + Vector2(0, 0.55) * k + Vector2(cos(t), sin(t)) * 0.5 * k) * s)
	_poly(ci, pts, col)


static func _cloud(ci: CanvasItem, c: Vector2, s: float, p: Vector2, k: float, col: Color) -> void:
	ci.draw_circle(c + (p + Vector2(-0.45, -0.25) * k) * s, 0.35 * k * s, col)
	ci.draw_circle(c + (p + Vector2(0.05, -0.45) * k) * s, 0.45 * k * s, col)
	ci.draw_circle(c + (p + Vector2(0.5, -0.25) * k) * s, 0.35 * k * s, col)
	ci.draw_rect(Rect2(c + (p + Vector2(-0.45, -0.3) * k) * s, Vector2(0.95, 0.4) * k * s), col)


## Symbole d'une figure (même dessin que UiKit.figure) en coordonnées unité, centré en `off`, taille k.
static func _fsym(ci: CanvasItem, shape: String, c: Vector2, s: float, col: Color, w: float, off := Vector2.ZERO, k := 1.0) -> void:
	var o := c + off * s
	var q := s * k
	match shape:
		"loop":
			var pts := PackedVector2Array()
			for i in 40:
				var t := float(i) / 39.0
				pts.append(Vector2.from_angle(t * TAU * 1.75) * 0.85 * (0.15 + 0.85 * t))
			_pl(ci, o, q, pts, col, w)
		"zigzag":
			_pl(ci, o, q, PackedVector2Array([Vector2(-0.6, -0.9), Vector2(0.25, -0.15), Vector2(-0.25, 0.1), Vector2(0.6, 0.9)]), col, w * 1.2)
		"straight":
			_ln(ci, o, q, Vector2(-0.95, 0.55), Vector2(0.95, -0.55), col, w * 1.3)
		"return":
			_arc(ci, o, q, Vector2(0, -0.1), 0.55, PI, TAU, col, w)
			_ln(ci, o, q, Vector2(-0.55, -0.1), Vector2(-0.55, 0.8), col, w)
			_ln(ci, o, q, Vector2(0.55, -0.1), Vector2(0.55, 0.55), col, w)
			_head(ci, o, q, Vector2(0.55, 0.95), Vector2(0, 1), 0.4, col)
		"enso":
			_arc(ci, o, q, Vector2.ZERO, 0.8, -PI * 0.35, PI * 1.45, col, w * 1.5)
			ci.draw_circle(o + Vector2.from_angle(-PI * 0.35) * 0.8 * q, w * 0.8, col)
		"hook":
			_ln(ci, o, q, Vector2(0.35, -0.9), Vector2(0.35, 0.3), col, w)
			_arc(ci, o, q, Vector2(0.0, 0.3), 0.35, 0.0, PI, col, w)
			_head(ci, o, q, Vector2(-0.45, 0.0), Vector2(-0.25, -1.0), 0.4, col)


static func _sword(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	_taper(ci, c, s, Vector2(-0.4, 0.4), Vector2(0.8, -0.8), 0.24, 0.04, col)
	_ln(ci, c, s, Vector2(-0.66, 0.16), Vector2(-0.16, 0.66), col, w * 1.1)
	_ln(ci, c, s, Vector2(-0.4, 0.4), Vector2(-0.82, 0.82), col, w * 1.2)


## Un pictogramme nommé (école, pouvoir, déclencheur « t_… », don de l'Atelier, bandeau),
## de couleur `col`, tenant dans un rayon r autour de c.
static func glyph(ci: CanvasItem, name: String, c: Vector2, r: float, col: Color, bg := NONE, a := 1.0) -> void:
	var s := r
	var w := maxf(1.2, r * 0.17)
	var k := Color(col, col.a * a)
	var b := Color(bg, bg.a * a)
	var cut := bg.a > 0.01
	match name:
		# ------------------------------------------------ écoles
		"fire":
			_shp(ci, "flame", c, s, k, Vector2(0, 0.05), 0.95)
			if cut:
				_shp(ci, "flame", c, s, b, Vector2(0.02, 0.45), 0.38)
		"water":
			_shp(ci, "drop", c, s, k, Vector2(0, 0.02), 0.95)
			if cut:
				_arc(ci, c, s, Vector2(0, 0.35), 0.36, PI * 0.6, PI * 0.95, b, w * 0.8)
		"bolt":
			_shp(ci, "bolt", c, s, k, Vector2.ZERO, 0.95)
		"wind":
			_ln(ci, c, s, Vector2(-0.95, -0.35), Vector2(0.35, -0.35), k, w)
			_arc(ci, c, s, Vector2(0.35, -0.6), 0.25, PI * 0.5, -PI * 0.9, k, w)
			_ln(ci, c, s, Vector2(-0.75, 0.05), Vector2(0.8, 0.05), k, w)
			_ln(ci, c, s, Vector2(-0.95, 0.45), Vector2(0.15, 0.45), k, w)
			_arc(ci, c, s, Vector2(0.15, 0.7), 0.25, -PI * 0.5, PI * 0.9, k, w)
		"shadow":
			_shp(ci, "crescent", c, s, k, Vector2(-0.12, 0.05), 0.85)
			_shp(ci, "star4", c, s, k, Vector2(0.55, -0.45), 0.3)
		"ink":
			_ln(ci, c, s, Vector2(0.8, -0.85), Vector2(0.12, -0.18), k, w * 1.3)
			_ln(ci, c, s, Vector2(0.18, -0.24), Vector2(-0.02, -0.04), k, w * 2.2)
			_shp(ci, "drop", c, s, k, Vector2(-0.32, 0.33), 0.52, deg_to_rad(220.0))
		# ------------------------------------------------ feu
		"blade_fire":
			_sword(ci, c, s, k, w)
			_shp(ci, "flame", c, s, k, Vector2(0.45, 0.42), 0.45)
		"claws_fire":
			for i in 3:
				var x0 := -0.5 + 0.38 * float(i)
				_taper(ci, c, s, Vector2(x0 + 0.45, -0.85), Vector2(x0 - 0.35, 0.25), 0.24, 0.04, k)
			_shp(ci, "flame", c, s, k, Vector2(0.52, 0.5), 0.42)
		"trail_fire":
			_taper(ci, c, s, Vector2(-0.95, 0.72), Vector2(0.95, 0.72), 0.18, 0.06, k)
			_shp(ci, "flame", c, s, k, Vector2(-0.45, 0.05), 0.55)
			_shp(ci, "flame", c, s, k, Vector2(0.35, -0.05), 0.65)
		"ring_fire":
			_dot(ci, c, s, Vector2.ZERO, 0.2, k)
			_arc(ci, c, s, Vector2.ZERO, 0.56, 0.0, TAU, k, w)
			for i in 8:
				var t := TAU * float(i) / 8.0 - PI / 2.0
				_poly(ci, PackedVector2Array([c + Vector2.from_angle(t - 0.2) * 0.68 * s, c + Vector2.from_angle(t) * 1.0 * s, c + Vector2.from_angle(t + 0.2) * 0.68 * s]), k)
		"spark":
			_shp(ci, "star8", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_dot(ci, c, s, Vector2.ZERO, 0.14, b)
		"wheel_fire":
			_arc(ci, c, s, Vector2(0, 0.25), 0.52, 0.0, TAU, k, w)
			for i in 6:
				_ln(ci, c, s, Vector2(0, 0.25), Vector2(0, 0.25) + Vector2.from_angle(TAU * float(i) / 6.0) * 0.52, k, w * 0.7)
			_dot(ci, c, s, Vector2(0, 0.25), 0.13, k)
			_shp(ci, "flame", c, s, k, Vector2(0, -0.52), 0.45)
		"halo_fire":
			var o := Vector2(0, 0.1)
			_arc(ci, c, s, o, 0.78, PI * 0.8, PI * 2.2, k, w)
			for t in [-PI / 2.0, -PI / 2.0 - 0.75, -PI / 2.0 + 0.75]:
				var ang := float(t)
				_poly(ci, PackedVector2Array([c + (o + Vector2.from_angle(ang - 0.22) * 0.8) * s, c + (o + Vector2.from_angle(ang) * 1.08) * s, c + (o + Vector2.from_angle(ang + 0.22) * 0.8) * s]), k)
			_person(ci, c, s, Vector2(0, 0.25), 0.75, k)
		"phoenix":
			for i in 4:
				var t := -PI / 2.0 + 0.42 * float(i)
				_shp(ci, "leaf", c, s, k, Vector2(-0.55, 0.6) + Vector2.from_angle(t) * 0.58, 0.58, t)
			_shp(ci, "flame", c, s, k, Vector2(0.55, 0.55), 0.36)
		# ------------------------------------------------ eau
		"push_wave":
			_arc(ci, c, s, Vector2(-1.15, 0), 0.5, -0.75, 0.75, k, w)
			_arc(ci, c, s, Vector2(-1.15, 0), 0.85, -0.6, 0.6, k, w)
			_ln(ci, c, s, Vector2(-0.15, 0), Vector2(0.6, 0), k, w * 1.3)
			_head(ci, c, s, Vector2(0.95, 0), Vector2(1, 0), 0.42, k)
		"heart_drop":
			_shp(ci, "heart", c, s, k, Vector2(-0.12, 0.18), 0.72)
			_shp(ci, "drop", c, s, k, Vector2(0.58, -0.55), 0.38)
		"shield":
			_shp(ci, "shield", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_arc(ci, c, s, Vector2(-0.12, -0.15), 0.26, 0.0, TAU, b, w * 0.6)
		"tide":
			_dot(ci, c, s, Vector2.ZERO, 0.2, k)
			for j in 4:
				var a0 := float(j) * PI / 2.0 + 0.25
				_arc(ci, c, s, Vector2.ZERO, 0.55, a0, a0 + PI / 2.0 - 0.5, k, w)
				_arc(ci, c, s, Vector2.ZERO, 0.9, a0 + 0.1, a0 + PI / 2.0 - 0.6, k, w)
		"whirl":
			var sp := PackedVector2Array()
			for i in 40:
				var t := float(i) / 39.0
				sp.append(Vector2.from_angle(t * TAU * 2.2) * (0.08 + 0.88 * t))
			_pl(ci, c, s, sp, k, w)
		"mirror":
			_ln(ci, c, s, Vector2(0.55, -0.9), Vector2(0.55, 0.9), k, w * 1.6)
			_ln(ci, c, s, Vector2(-0.85, -0.6), Vector2(0.38, 0.0), k, w)
			_ln(ci, c, s, Vector2(0.38, 0.0), Vector2(-0.55, 0.46), k, w)
			_head(ci, c, s, Vector2(-0.88, 0.62), Vector2(-1.2, 0.6), 0.38, k)
		"great_wave":
			_shp(ci, "great_wave", c, s, k)
		# ------------------------------------------------ foudre
		"chain_bolt":
			_dot(ci, c, s, Vector2(-0.7, 0.6), 0.22, k)
			_dot(ci, c, s, Vector2(0.7, -0.6), 0.22, k)
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.55, 0.45), Vector2(-0.02, 0.0), Vector2(0.06, 0.32), Vector2(0.55, -0.45)]), k, w * 1.2)
		"speed":
			_shp(ci, "chevron", c, s, k, Vector2(0.12, 0), 0.85)
			_ln(ci, c, s, Vector2(-0.95, -0.45), Vector2(-0.3, -0.45), k, w)
			_ln(ci, c, s, Vector2(-0.8, 0), Vector2(-0.05, 0), k, w)
			_ln(ci, c, s, Vector2(-0.95, 0.45), Vector2(-0.3, 0.45), k, w)
		"battery":
			ci.draw_rect(Rect2(c + Vector2(-0.85, -0.5) * s, Vector2(1.55, 1.0) * s), k, false, w)
			_box(ci, c, s, Vector2(0.72, -0.22), Vector2(0.92, 0.22), k)
			_shp(ci, "bolt", c, s, k, Vector2(-0.08, 0), 0.36)
		"storm":
			_cloud(ci, c, s, Vector2(0, -0.2), 1.0, k)
			_shp(ci, "bolt", c, s, k, Vector2(0.05, 0.45), 0.5)
		"stun":
			_dot(ci, c, s, Vector2(0, 0.45), 0.4, k)
			var el := PackedVector2Array()
			for i in 25:
				var t := TAU * float(i) / 24.0
				el.append(Vector2(cos(t) * 0.85, -0.38 + sin(t) * 0.28))
			_pl(ci, c, s, el, k, w * 0.7)
			_shp(ci, "star4", c, s, k, Vector2(-0.6, -0.45), 0.3)
			_shp(ci, "star4", c, s, k, Vector2(0.55, -0.28), 0.25)
		"paw":
			_dot(ci, c, s, Vector2(-0.2, 0.45), 0.3, k)
			_dot(ci, c, s, Vector2(0.2, 0.45), 0.3, k)
			_dot(ci, c, s, Vector2(0, 0.28), 0.33, k)
			_dot(ci, c, s, Vector2(-0.68, -0.12), 0.17, k)
			_dot(ci, c, s, Vector2(-0.27, -0.5), 0.18, k)
			_dot(ci, c, s, Vector2(0.27, -0.5), 0.18, k)
			_dot(ci, c, s, Vector2(0.68, -0.12), 0.17, k)
		"fork_bolt":
			_pl(ci, c, s, PackedVector2Array([Vector2(0.3, -0.95), Vector2(-0.25, -0.15), Vector2(0.2, 0.05), Vector2(-0.35, 0.95)]), k, w * 1.3)
			_pl(ci, c, s, PackedVector2Array([Vector2(0.2, 0.05), Vector2(0.75, 0.3), Vector2(0.55, 0.75)]), k, w)
		"drum":
			var dp := PackedVector2Array([c + Vector2(-0.62, -0.3) * s, c + Vector2(-0.75, 0.15) * s, c + Vector2(-0.62, 0.6) * s])
			for i in range(1, 8):
				var t := PI - PI * float(i) / 8.0
				dp.append(c + Vector2(0.62 * cos(t), 0.6 + 0.2 * sin(t)) * s)
			dp.append_array(PackedVector2Array([c + Vector2(0.62, 0.6) * s, c + Vector2(0.75, 0.15) * s, c + Vector2(0.62, -0.3) * s]))
			for i in range(1, 8):
				var t := -PI * float(i) / 8.0
				dp.append(c + Vector2(0.62 * cos(t), -0.3 + 0.2 * sin(t)) * s)
			_poly(ci, dp, k)
			if cut:
				var top := PackedVector2Array()
				for i in 17:
					var t := TAU * float(i) / 16.0
					top.append(Vector2(0.5 * cos(t), -0.3 + 0.12 * sin(t)))
				_pl(ci, c, s, top, b, w * 0.6)
			_ln(ci, c, s, Vector2(0.1, -0.42), Vector2(0.75, -0.95), k, w * 0.8)
			_ln(ci, c, s, Vector2(-0.1, -0.42), Vector2(-0.75, -0.95), k, w * 0.8)
			_dot(ci, c, s, Vector2(0.75, -0.95), 0.1, k)
			_dot(ci, c, s, Vector2(-0.75, -0.95), 0.1, k)
		# ------------------------------------------------ vent
		"long_stroke":
			_taper(ci, c, s, Vector2(-0.88, 0.42), Vector2(0.95, 0.42), 0.38, 0.05, k)
			_dot(ci, c, s, Vector2(-0.88, 0.42), 0.19, k)
			_ln(ci, c, s, Vector2(-0.6, -0.42), Vector2(0.6, -0.42), k, w)
			_head(ci, c, s, Vector2(0.95, -0.42), Vector2(1, 0), 0.38, k)
			_head(ci, c, s, Vector2(-0.95, -0.42), Vector2(-1, 0), 0.38, k)
		"refill":
			_shp(ci, "drop", c, s, k, Vector2(0, 0.08), 0.45)
			var e := PI * 1.2
			var ed := Vector2(-sin(e), cos(e))
			_arc(ci, c, s, Vector2.ZERO, 0.85, -PI * 0.3, e, k, w * 0.9)
			_head(ci, c, s, Vector2.from_angle(e) * 0.85 + ed * 0.14, ed, 0.34, k)
		"feather":
			_shp(ci, "leaf", c, s, k, Vector2(0.08, -0.08), 0.92, -PI / 4.0)
			if cut:
				_ln(ci, c, s, Vector2(-0.45, 0.45), Vector2(0.55, -0.55), b, maxf(1.0, w * 0.45))
			_ln(ci, c, s, Vector2(-0.5, 0.5), Vector2(-0.92, 0.92), k, w * 0.8)
		"blades":
			_sweep(ci, c, s, Vector2(-0.15, 0.95), 0.95, -2.5, -0.7, 0.34, k)
			_sweep(ci, c, s, Vector2(0.15, 0.4), 0.95, -2.5, -0.7, 0.34, k)
		"tornado":
			_ln(ci, c, s, Vector2(-0.85, -0.75), Vector2(0.85, -0.75), k, w * 1.1)
			_ln(ci, c, s, Vector2(-0.55, -0.38), Vector2(0.7, -0.38), k, w * 1.1)
			_ln(ci, c, s, Vector2(-0.3, 0.0), Vector2(0.5, 0.0), k, w * 1.1)
			_ln(ci, c, s, Vector2(-0.1, 0.38), Vector2(0.35, 0.38), k, w * 1.1)
			_ln(ci, c, s, Vector2(0.02, 0.74), Vector2(0.22, 0.74), k, w * 1.1)
		"clock":
			_arc(ci, c, s, Vector2(0, 0.08), 0.8, 0.0, TAU, k, w)
			_ln(ci, c, s, Vector2(0, -0.72), Vector2(0, -0.98), k, w * 1.4)
			_ln(ci, c, s, Vector2(0, 0.08), Vector2(0, -0.42), k, w)
			_ln(ci, c, s, Vector2(0, 0.08), Vector2(0.38, 0.22), k, w)
			_dot(ci, c, s, Vector2(0, 0.08), 0.1, k)
		"cloud_gust":
			_cloud(ci, c, s, Vector2(-0.2, -0.3), 0.85, k)
			_ln(ci, c, s, Vector2(-0.55, 0.28), Vector2(0.9, 0.28), k, w)
			_ln(ci, c, s, Vector2(-0.25, 0.62), Vector2(0.65, 0.62), k, w)
			_arc(ci, c, s, Vector2(0.9, 0.08), 0.2, PI * 0.5, -PI * 0.7, k, w)
		# ------------------------------------------------ ombre
		"backstab":
			_person(ci, c, s, Vector2(0.38, 0.12), 0.7, k)
			var e2 := -PI - 0.75
			var dir := Vector2(sin(e2), -cos(e2))
			_arc(ci, c, s, Vector2(0.1, 0.05), 0.75, -0.15, e2, k, w)
			_head(ci, c, s, Vector2(0.1, 0.05) + Vector2.from_angle(e2) * 0.75 + dir * 0.14, dir, 0.36, k)
		"footsteps":
			_ellipse(ci, c, s, Vector2(-0.38, 0.12), 0.2, 0.32, k, -0.2)
			_dot(ci, c, s, Vector2(-0.38, 0.12) + Vector2(0, 0.5).rotated(-0.2), 0.15, k)
			_ellipse(ci, c, s, Vector2(0.38, -0.45), 0.2, 0.32, k, 0.2)
			_dot(ci, c, s, Vector2(0.38, -0.45) + Vector2(0, 0.5).rotated(0.2), 0.15, k)
		"hood":
			_shp(ci, "hood", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_ellipse(ci, c, s, Vector2(0, 0.1), 0.42, 0.48, b)
				_ellipse(ci, c, s, Vector2(-0.17, 0.06), 0.11, 0.06, k)
				_ellipse(ci, c, s, Vector2(0.17, 0.06), 0.11, 0.06, k)
		"skull":
			_dot(ci, c, s, Vector2(0, -0.15), 0.68, k)
			_box(ci, c, s, Vector2(-0.38, 0.3), Vector2(0.38, 0.82), k)
			if cut:
				_dot(ci, c, s, Vector2(-0.26, -0.08), 0.19, b)
				_dot(ci, c, s, Vector2(0.26, -0.08), 0.19, b)
				_poly(ci, PackedVector2Array([c + Vector2(0, 0.12) * s, c + Vector2(0.09, 0.3) * s, c + Vector2(-0.09, 0.3) * s]), b)
				_ln(ci, c, s, Vector2(-0.13, 0.55), Vector2(-0.13, 0.82), b, maxf(1.0, w * 0.5))
				_ln(ci, c, s, Vector2(0.13, 0.55), Vector2(0.13, 0.82), b, maxf(1.0, w * 0.5))
		"ghost":
			_shp(ci, "ghost", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_ellipse(ci, c, s, Vector2(-0.22, -0.15), 0.1, 0.15, b)
				_ellipse(ci, c, s, Vector2(0.22, -0.15), 0.1, 0.15, b)
		"hourglass":
			_ln(ci, c, s, Vector2(-0.7, -0.88), Vector2(0.7, -0.88), k, w * 1.3)
			_ln(ci, c, s, Vector2(-0.7, 0.88), Vector2(0.7, 0.88), k, w * 1.3)
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.55, -0.85), Vector2(0, 0), Vector2(-0.55, 0.85)]), k, w * 0.8)
			_pl(ci, c, s, PackedVector2Array([Vector2(0.55, -0.85), Vector2(0, 0), Vector2(0.55, 0.85)]), k, w * 0.8)
			_poly(ci, PackedVector2Array([c + Vector2(-0.35, -0.52) * s, c + Vector2(0.35, -0.52) * s, c + Vector2(0, -0.08) * s]), k)
			_poly(ci, PackedVector2Array([c + Vector2(-0.45, 0.85) * s, c + Vector2(0.45, 0.85) * s, c + Vector2(0, 0.42) * s]), k)
		"clone":
			_person(ci, c, s, Vector2(-0.32, -0.02), 0.75, Color(k, k.a * 0.45))
			_person(ci, c, s, Vector2(0.25, 0.12), 0.82, k)
		"fox":
			_shp(ci, "fox", c, s, k, Vector2.ZERO, 0.95)
			if cut:
				_ln(ci, c, s, Vector2(-0.42, 0.02), Vector2(-0.14, 0.14), b, w * 0.8)
				_ln(ci, c, s, Vector2(0.42, 0.02), Vector2(0.14, 0.14), b, w * 0.8)
				_dot(ci, c, s, Vector2(0, 0.7), 0.08, b)
			_shp(ci, "flame", c, s, k, Vector2(0, -0.72), 0.26)
		# ------------------------------------------------ encre
		"heart_plus":
			_shp(ci, "heart", c, s, k, Vector2(-0.15, 0.18), 0.78)
			_ln(ci, c, s, Vector2(0.62, -0.88), Vector2(0.62, -0.32), k, w * 1.2)
			_ln(ci, c, s, Vector2(0.34, -0.6), Vector2(0.9, -0.6), k, w * 1.2)
		"amulet":
			_shp(ci, "bag", c, s, k)
			_dot(ci, c, s, Vector2(0, -0.72), 0.14, k)
			_ln(ci, c, s, Vector2(0, -0.72), Vector2(-0.25, -0.98), k, w * 0.7)
			_ln(ci, c, s, Vector2(0, -0.72), Vector2(0.25, -0.98), k, w * 0.7)
			if cut:
				_shp(ci, "star4", c, s, b, Vector2(0, 0.22), 0.32)
		"stamp":
			_dot(ci, c, s, Vector2(0, -0.68), 0.25, k)
			_box(ci, c, s, Vector2(-0.16, -0.5), Vector2(0.16, -0.05), k)
			_box(ci, c, s, Vector2(-0.62, -0.08), Vector2(0.62, 0.28), k)
			ci.draw_rect(Rect2(c + Vector2(-0.48, 0.45) * s, Vector2(0.96, 0.48) * s), k, false, maxf(1.0, w * 0.7))
		"enso":
			_arc(ci, c, s, Vector2.ZERO, 0.75, -PI * 0.35, PI * 1.45, k, w * 1.6)
			ci.draw_circle(c + Vector2.from_angle(-PI * 0.35) * 0.75 * s, w * 0.9, k)
		"one_stroke":
			_taper(ci, c, s, Vector2(-0.82, 0.55), Vector2(0.92, -0.62), 0.42, 0.05, k)
			_dot(ci, c, s, Vector2(-0.82, 0.55), 0.21, k)
			_dot(ci, c, s, Vector2(0.5, 0.38), 0.09, k)
			_dot(ci, c, s, Vector2(0.72, 0.18), 0.06, k)
		# ------------------------------------------------ figures (le symbole de la forme, et ce que le rouleau ajoute)
		"fig":
			_fsym(ci, "loop", c, s, k, w, Vector2(-0.38, -0.32), 0.62)
			_fsym(ci, "zigzag", c, s, k, w, Vector2(0.42, 0.3), 0.62)
		"fig_loop":
			_fsym(ci, "loop", c, s, k, w)
		"fig_loop_pull":
			_fsym(ci, "loop", c, s, k, w, Vector2.ZERO, 0.62)
			for i in 4:
				var dl := Vector2.from_angle(PI * 0.25 + PI * 0.5 * float(i))
				_head(ci, c, s, dl * 0.68, -dl, 0.3, k)
		"fig_zigzag":
			_fsym(ci, "zigzag", c, s, k, w)
		"fig_zigzag_long":
			_fsym(ci, "zigzag", c, s, k, w, Vector2(-0.3, 0), 0.75)
			_ln(ci, c, s, Vector2(0.15, 0.62), Vector2(0.72, 0.1), k, w * 0.7)
			_dot(ci, c, s, Vector2(0.72, 0.1), 0.17, k)
			_ln(ci, c, s, Vector2(0.72, 0.1), Vector2(0.6, -0.55), k, w * 0.7)
			_dot(ci, c, s, Vector2(0.6, -0.55), 0.17, k)
		"fig_straight":
			_fsym(ci, "straight", c, s, k, w)
		"fig_straight_double":
			_fsym(ci, "straight", c, s, k, w, Vector2(-0.12, -0.2), 0.95)
			_fsym(ci, "straight", c, s, k, w, Vector2(0.12, 0.2), 0.95)
		"fig_straight_wave":
			_fsym(ci, "straight", c, s, k, w, Vector2(-0.22, 0.13), 0.72)
			_sweep(ci, c, s, Vector2(0.15, 0.1), 0.75, -1.3, 0.25, 0.3, k)
		"fig_return":
			_fsym(ci, "return", c, s, k, w)
		"fig_return_reflect":
			_fsym(ci, "return", c, s, k, w, Vector2(-0.3, 0.1), 0.72)
			_dot(ci, c, s, Vector2(0.55, -0.15), 0.17, k)
			_ln(ci, c, s, Vector2(0.55, -0.15), Vector2(0.8, -0.6), k, w * 0.7)
			_head(ci, c, s, Vector2(0.92, -0.85), Vector2(0.45, -0.9), 0.3, k)
		"fig_return_counter":
			_shp(ci, "shield", c, s, k, Vector2(-0.2, 0.1), 0.72)
			_shp(ci, "star4", c, s, k, Vector2(0.55, -0.55), 0.4)
		"fig_enso":
			_fsym(ci, "enso", c, s, k, w)
			_dot(ci, c, s, Vector2.ZERO, 0.14, k)
		"fig_enso_big":
			_fsym(ci, "enso", c, s, k, w, Vector2.ZERO, 0.7)
			_arc(ci, c, s, Vector2.ZERO, 0.95, 0.0, TAU, Color(k, k.a * 0.6), w * 0.6)
		"fig_enso_heal":
			_fsym(ci, "enso", c, s, k, w)
			_shp(ci, "heart", c, s, k, Vector2(0, 0.04), 0.36)
		"fig_hook":
			_fsym(ci, "hook", c, s, k, w)
		"fig_hook_back":
			_fsym(ci, "hook", c, s, k, w, Vector2(-0.32, 0.05), 0.75)
			_person(ci, c, s, Vector2(0.55, 0.15), 0.55, k)
		"fig_hook_double":
			_fsym(ci, "hook", c, s, k, w, Vector2(-0.35, 0.05), 0.72)
			_fsym(ci, "hook", c, s, k, w, Vector2(0.35, 0.05), 0.72)
		# ------------------------------------------------ sanctuaire, bandeaux, Atelier
		"oni":
			_dot(ci, c, s, Vector2(0, 0.2), 0.62, k)
			_poly(ci, PackedVector2Array([c + Vector2(-0.55, -0.05) * s, c + Vector2(-0.75, -0.95) * s, c + Vector2(-0.18, -0.32) * s]), k)
			_poly(ci, PackedVector2Array([c + Vector2(0.55, -0.05) * s, c + Vector2(0.18, -0.32) * s, c + Vector2(0.75, -0.95) * s]), k)
			if cut:
				_poly(ci, PackedVector2Array([c + Vector2(-0.42, 0.02) * s, c + Vector2(-0.1, 0.16) * s, c + Vector2(-0.36, 0.24) * s]), b)
				_poly(ci, PackedVector2Array([c + Vector2(0.42, 0.02) * s, c + Vector2(0.36, 0.24) * s, c + Vector2(0.1, 0.16) * s]), b)
				_box(ci, c, s, Vector2(-0.3, 0.44), Vector2(0.3, 0.58), b)
		# malédictions du sanctuaire
		"c_dry":
			# encre sèche : goutte fendue sous un pinceau
			_shp(ci, "drop", c, s, k, Vector2(-0.2, 0.18), 0.78)
			if cut:
				_pl(ci, c, s, PackedVector2Array([Vector2(-0.3, -0.22), Vector2(-0.12, 0.05), Vector2(-0.32, 0.28), Vector2(-0.16, 0.62)]), b, maxf(1.0, w * 0.8))
			_ln(ci, c, s, Vector2(0.95, -0.95), Vector2(0.5, -0.5), k, w * 1.1)
			_taper(ci, c, s, Vector2(0.55, -0.55), Vector2(0.28, -0.28), 0.26, 0.05, k)
		"c_eye":
			# œil d'oni : amande, iris, pupille fendue, deux cornes
			var eye := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				eye.append(c + Vector2(-0.88 + 1.76 * t, 0.15 - 0.5 * sin(PI * t)) * s)
			for i in range(11, 0, -1):
				var t2 := float(i) / 12.0
				eye.append(c + Vector2(-0.88 + 1.76 * t2, 0.15 + 0.4 * sin(PI * t2)) * s)
			_poly(ci, eye, k)
			if cut:
				_dot(ci, c, s, Vector2(0, 0.12), 0.32, b)
				_ellipse(ci, c, s, Vector2(0, 0.12), 0.08, 0.26, k)
			_poly(ci, PackedVector2Array([c + Vector2(-0.62, -0.16) * s, c + Vector2(-0.8, -0.95) * s, c + Vector2(-0.3, -0.3) * s]), k)
			_poly(ci, PackedVector2Array([c + Vector2(0.62, -0.16) * s, c + Vector2(0.3, -0.3) * s, c + Vector2(0.8, -0.95) * s]), k)
		"c_heavy":
			# pas lourd : poids de fonte à anneau
			_poly(ci, PackedVector2Array([c + Vector2(-0.5, -0.22) * s, c + Vector2(0.5, -0.22) * s, c + Vector2(0.82, 0.8) * s, c + Vector2(-0.82, 0.8) * s]), k)
			_arc(ci, c, s, Vector2(0, -0.42), 0.3, PI, TAU, k, w * 1.3)
			_ln(ci, c, s, Vector2(-0.3, -0.42), Vector2(-0.3, -0.2), k, w * 1.3)
			_ln(ci, c, s, Vector2(0.3, -0.42), Vector2(0.3, -0.2), k, w * 1.3)
			if cut:
				_ln(ci, c, s, Vector2(-0.4, 0.3), Vector2(0.4, 0.3), b, maxf(1.0, w * 0.8))
		"c_haste":
			# hâte des morts : sablier qui file
			glyph(ci, "hourglass", c + Vector2(0.24, 0) * s, r * 0.78, col, bg, a)
			_ln(ci, c, s, Vector2(-0.98, -0.4), Vector2(-0.5, -0.4), k, w)
			_ln(ci, c, s, Vector2(-1.0, 0.0), Vector2(-0.42, 0.0), k, w)
			_ln(ci, c, s, Vector2(-0.98, 0.4), Vector2(-0.5, 0.4), k, w)
		"path":
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.7, -0.6), Vector2(-0.1, 0), Vector2(-0.7, 0.6)]), k, w * 1.4)
			_pl(ci, c, s, PackedVector2Array([Vector2(0.0, -0.6), Vector2(0.6, 0), Vector2(0.0, 0.6)]), k, w * 1.4)
		"torii":
			_poly(ci, PackedVector2Array([c + Vector2(-1.0, -0.88) * s, c + Vector2(1.0, -0.88) * s, c + Vector2(0.9, -0.66) * s, c + Vector2(-0.9, -0.66) * s]), k)
			_box(ci, c, s, Vector2(-0.78, -0.42), Vector2(0.78, -0.28), k)
			_box(ci, c, s, Vector2(-0.6, -0.68), Vector2(-0.42, 0.95), k)
			_box(ci, c, s, Vector2(0.42, -0.68), Vector2(0.6, 0.95), k)
			_box(ci, c, s, Vector2(-0.07, -0.68), Vector2(0.07, -0.3), k)
		"star":
			_shp(ci, "star5", c, s, k, Vector2(0, 0.06), 0.98)
		"check":
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.72, 0.02), Vector2(-0.2, 0.55), Vector2(0.75, -0.55)]), k, w * 1.7)
		"cross":
			_ln(ci, c, s, Vector2(-0.6, -0.6), Vector2(0.6, 0.6), k, w * 1.7)
			_ln(ci, c, s, Vector2(0.6, -0.6), Vector2(-0.6, 0.6), k, w * 1.7)
		"reroll":
			for j in 2:
				var a0 := -PI * 0.1 + PI * float(j)
				var a1 := a0 + PI * 0.75
				var dd := Vector2(-sin(a1), cos(a1))
				_arc(ci, c, s, Vector2.ZERO, 0.7, a0, a1, k, w * 1.1)
				_head(ci, c, s, Vector2.from_angle(a1) * 0.7 + dd * 0.14, dd, 0.36, k)
		"scroll":
			_box(ci, c, s, Vector2(-0.55, -0.6), Vector2(0.55, 0.6), k)
			_box(ci, c, s, Vector2(-0.75, -0.82), Vector2(0.75, -0.58), k)
			_box(ci, c, s, Vector2(-0.75, 0.58), Vector2(0.75, 0.82), k)
			if cut:
				_ln(ci, c, s, Vector2(-0.35, -0.25), Vector2(0.35, -0.25), b, maxf(1.0, w * 0.6))
				_ln(ci, c, s, Vector2(-0.35, 0.05), Vector2(0.35, 0.05), b, maxf(1.0, w * 0.6))
				_ln(ci, c, s, Vector2(-0.35, 0.33), Vector2(0.15, 0.33), b, maxf(1.0, w * 0.6))
		"coin":
			_dot(ci, c, s, Vector2.ZERO, 0.85, k)
			if cut:
				_box(ci, c, s, Vector2(-0.22, -0.22), Vector2(0.22, 0.22), b)
				_arc(ci, c, s, Vector2.ZERO, 0.62, 0.0, TAU, b, maxf(1.0, w * 0.5))
		"cards":
			var card := PackedVector2Array([Vector2(-0.4, -0.6), Vector2(0.4, -0.6), Vector2(0.4, 0.6), Vector2(-0.4, 0.6)])
			_poly(ci, Transform2D(-0.3, Vector2(s, s), 0.0, c + Vector2(-0.25, 0.02) * s) * card, Color(k, k.a * 0.55))
			_poly(ci, Transform2D(0.2, Vector2(s, s), 0.0, c + Vector2(0.22, 0.05) * s) * card, k)
			if cut:
				_shp(ci, "star4", c, s, b, Vector2(0.22, 0.05), 0.3)
		"kintsugi":
			_shp(ci, "heart", c, s, k, Vector2(0, 0.12), 0.9)
			_pl(ci, c, s, PackedVector2Array([Vector2(-0.05, -0.5), Vector2(0.12, -0.12), Vector2(-0.1, 0.2), Vector2(0.08, 0.6)]), Color(Toon.GOLD, a), maxf(1.2, w * 0.8))
		# ------------------------------------------------ déclencheurs
		"t_hit":
			_sword(ci, c, s, k, w)
		"t_stroke":
			_taper(ci, c, s, Vector2(-0.8, 0.55), Vector2(0.9, -0.55), 0.4, 0.06, k)
			_dot(ci, c, s, Vector2(-0.8, 0.55), 0.2, k)
		"t_arrive":
			_dot(ci, c, s, Vector2.ZERO, 0.22, k)
			_arc(ci, c, s, Vector2.ZERO, 0.55, 0.0, TAU, k, w)
			_arc(ci, c, s, Vector2.ZERO, 0.9, 0.0, TAU, Color(k, k.a * 0.6), w * 0.8)
		"t_kill":
			glyph(ci, "skull", c, r, col, bg, a)
		"t_dodge":
			glyph(ci, "speed", c, r, col, bg, a)
		"t_always":
			var lem := PackedVector2Array()
			for i in 33:
				var t := TAU * float(i) / 32.0
				var dn := 1.0 + sin(t) * sin(t)
				lem.append(Vector2(0.92 * cos(t) / dn, 0.92 * sin(t) * cos(t) / dn))
			_pl(ci, c, s, lem, k, w * 1.2)
		"t_hurt":
			glyph(ci, "shield", c, r, col, bg, a)
		"t_figure":
			glyph(ci, "whirl", c, r, col, bg, a)
		"t_multi":
			_ln(ci, c, s, Vector2(-0.95, 0.0), Vector2(0.95, 0.0), k, w * 0.8)
			for i in 3:
				_dot(ci, c, s, Vector2(-0.58 + 0.58 * float(i), 0.0), 0.22, k)
		"t_timer":
			glyph(ci, "clock", c, r, col, bg, a)
		"t_back":
			glyph(ci, "backstab", c, r, col, bg, a)
		"t_target":
			_arc(ci, c, s, Vector2.ZERO, 0.6, 0.0, TAU, k, w)
			_dot(ci, c, s, Vector2.ZERO, 0.15, k)
			for i in 4:
				var d2 := Vector2.from_angle(PI * 0.5 * float(i))
				_ln(ci, c, s, d2 * 0.42, d2 * 0.98, k, w)
		"t_now":
			glyph(ci, "star", c, r, col, bg, a)
		"t_luck":
			glyph(ci, "cards", c, r, col, bg, a)
		"t_school":
			glyph(ci, "stamp", c, r, col, bg, a)
		"t_once":
			_arc(ci, c, s, Vector2.ZERO, 0.82, 0.0, TAU, k, w)
			var fs := maxi(6, int(s * 1.25))
			text(ci, UI_FONT, "1", c + Vector2(0, fs * 0.36), fs, k)
		"t_touch":
			_dot(ci, c, s, Vector2.ZERO, 0.28, k)
			_arc(ci, c, s, Vector2.ZERO, 0.6, 0.0, TAU, Color(k, k.a * 0.7), w * 0.8)
			_arc(ci, c, s, Vector2.ZERO, 0.92, 0.0, TAU, Color(k, k.a * 0.4), w * 0.7)
		# ------------------------------------------------ Atelier : lignes de la Pierre à encre, monnaies
		"at_brush":
			# pinceau long : manche, virole, pointe, et le trait qui file
			_taper(ci, c, s, Vector2(0.92, -0.92), Vector2(0.12, -0.12), 0.2, 0.22, k)
			_taper(ci, c, s, Vector2(0.14, -0.14), Vector2(-0.08, 0.08), 0.32, 0.32, k)
			_taper(ci, c, s, Vector2(-0.06, 0.06), Vector2(-0.46, 0.46), 0.3, 0.03, k)
			if cut:
				_ln(ci, c, s, Vector2(0.72, -0.52), Vector2(0.52, -0.72), b, maxf(1.0, w * 0.45))
				_ln(ci, c, s, Vector2(0.47, -0.27), Vector2(0.27, -0.47), b, maxf(1.0, w * 0.45))
			_taper(ci, c, s, Vector2(-0.6, 0.7), Vector2(0.95, 0.7), 0.24, 0.04, k)
			_dot(ci, c, s, Vector2(-0.6, 0.7), 0.12, k)
		"at_ink":
			# goutte d'encre et sa flèche de recharge
			_shp(ci, "drop", c, s, k, Vector2(-0.12, 0.0), 0.86)
			if cut:
				_arc(ci, c, s, Vector2(-0.3, 0.3), 0.26, PI * 0.95, PI * 1.4, b, maxf(1.0, w * 0.6))
				_dot(ci, c, s, Vector2(0.55, 0.55), 0.44, b)
			var ik0 := -PI * 0.35
			var ik1 := PI * 1.15
			var ikd := Vector2(-sin(ik1), cos(ik1))
			_arc(ci, c, s, Vector2(0.55, 0.55), 0.27, ik0, ik1, k, w * 0.75)
			_head(ci, c, s, Vector2(0.55, 0.55) + Vector2.from_angle(ik1) * 0.27 + ikd * 0.1, ikd, 0.24, k)
		"at_heart":
			_shp(ci, "heart", c, s, k, Vector2(-0.1, 0.12), 0.82)
			if cut:
				_dot(ci, c, s, Vector2(0.58, -0.55), 0.4, b)
			_ln(ci, c, s, Vector2(0.58, -0.78), Vector2(0.58, -0.32), k, w * 1.1)
			_ln(ci, c, s, Vector2(0.35, -0.55), Vector2(0.81, -0.55), k, w * 1.1)
		"at_breath":
			# second souffle : un filet tendu, et ce qui y retombe
			var nb_rim := PackedVector2Array()
			var nb_low := PackedVector2Array()
			for i in 9:
				var nb_t := float(i) / 8.0
				var nb_y := -0.05 + 0.5 * sin(PI * nb_t)
				nb_rim.append(Vector2(-0.92 + 1.84 * nb_t, nb_y))
				nb_low.append(Vector2(-0.92 + 1.84 * nb_t, nb_y + 0.32 * sin(PI * nb_t)))
			_pl(ci, c, s, nb_rim, k, w)
			_pl(ci, c, s, nb_low, k, w * 0.6)
			for i in range(1, 8):
				_ln(ci, c, s, nb_rim[i], nb_low[i - 1], k, w * 0.5)
				_ln(ci, c, s, nb_rim[i], nb_low[i + 1], k, w * 0.5)
			_dot(ci, c, s, Vector2(-0.92, -0.05), 0.11, k)
			_dot(ci, c, s, Vector2(0.92, -0.05), 0.11, k)
			_dot(ci, c, s, Vector2(0.0, -0.62), 0.22, k)
			_ln(ci, c, s, Vector2(-0.3, -0.98), Vector2(-0.12, -0.82), k, w * 0.6)
			_ln(ci, c, s, Vector2(0.3, -0.98), Vector2(0.12, -0.82), k, w * 0.6)
		"at_purse":
			# bourse nouée, une pièce dessus
			_ellipse(ci, c, s, Vector2(0, 0.3), 0.74, 0.6, k)
			_poly(ci, PackedVector2Array([c + Vector2(-0.56, -0.86) * s, c + Vector2(0.56, -0.86) * s, c + Vector2(0.24, -0.36) * s, c + Vector2(-0.24, -0.36) * s]), k)
			_box(ci, c, s, Vector2(-0.3, -0.42), Vector2(0.3, -0.18), k)
			if cut:
				_ln(ci, c, s, Vector2(-0.3, -0.32), Vector2(0.3, -0.32), b, maxf(1.0, w * 0.55))
				_arc(ci, c, s, Vector2(0, 0.36), 0.28, 0.0, TAU, b, maxf(1.0, w * 0.55))
				_box(ci, c, s, Vector2(-0.08, 0.28), Vector2(0.08, 0.44), b)
		"at_choice":
			# une carte de plus
			var ch_card := PackedVector2Array([Vector2(-0.36, -0.55), Vector2(0.36, -0.55), Vector2(0.36, 0.55), Vector2(-0.36, 0.55)])
			_poly(ci, Transform2D(-0.28, Vector2(s, s), 0.0, c + Vector2(-0.3, 0.1) * s) * ch_card, Color(k, k.a * 0.5))
			_poly(ci, Transform2D(0.12, Vector2(s, s), 0.0, c + Vector2(0.08, 0.14) * s) * ch_card, k)
			if cut:
				_shp(ci, "star4", c, s, b, Vector2(0.08, 0.14), 0.26)
				_dot(ci, c, s, Vector2(0.6, -0.6), 0.4, b)
			_ln(ci, c, s, Vector2(0.6, -0.84), Vector2(0.6, -0.36), k, w * 1.1)
			_ln(ci, c, s, Vector2(0.36, -0.6), Vector2(0.84, -0.6), k, w * 1.1)
		"at_drop":
			_shp(ci, "drop", c, s, k, Vector2(0, 0.05), 0.95)
			if cut:
				_arc(ci, c, s, Vector2(-0.18, 0.38), 0.3, PI * 0.9, PI * 1.35, b, maxf(1.0, w * 0.7))
		"at_seal":
			_box(ci, c, s, Vector2(-0.78, -0.78), Vector2(0.78, 0.78), k)
			if cut:
				ci.draw_rect(Rect2(c + Vector2(-0.56, -0.56) * s, Vector2(1.12, 1.12) * s), b, false, maxf(1.0, w * 0.55))
				_box(ci, c, s, Vector2(-0.3, -0.36), Vector2(0.3, -0.22), b)
				_box(ci, c, s, Vector2(-0.07, -0.22), Vector2(0.07, 0.36), b)
				_box(ci, c, s, Vector2(-0.34, 0.1), Vector2(0.34, 0.24), b)
		"at_print":
			ci.draw_rect(Rect2(c + Vector2(-0.82, -0.68) * s, Vector2(1.64, 1.36) * s), k, false, maxf(1.0, w * 0.8))
			_poly(ci, PackedVector2Array([c + Vector2(-0.62, 0.5) * s, c + Vector2(-0.12, -0.3) * s, c + Vector2(0.08, -0.3) * s, c + Vector2(0.62, 0.5) * s]), k)
			_dot(ci, c, s, Vector2(0.48, -0.36), 0.12, k)
			if cut:
				_poly(ci, PackedVector2Array([c + Vector2(-0.12, -0.3) * s, c + Vector2(0.08, -0.3) * s, c + Vector2(0.215, -0.1) * s,
					c + Vector2(0.05, -0.16) * s, c + Vector2(-0.05, -0.08) * s, c + Vector2(-0.245, -0.1) * s]), b)
		"at_lock":
			_arc(ci, c, s, Vector2(0, -0.28), 0.4, PI, TAU, k, w * 1.2)
			_ln(ci, c, s, Vector2(-0.4, -0.3), Vector2(-0.4, 0.0), k, w * 1.2)
			_ln(ci, c, s, Vector2(0.4, -0.3), Vector2(0.4, 0.0), k, w * 1.2)
			_box(ci, c, s, Vector2(-0.66, -0.04), Vector2(0.66, 0.88), k)
			if cut:
				_dot(ci, c, s, Vector2(0, 0.32), 0.13, b)
				_box(ci, c, s, Vector2(-0.05, 0.36), Vector2(0.05, 0.62), b)
		# ------------------------------------------------ pastilles d'effet (cartes de rouleau, bulles)
		"fx_dmg":
			# impact : éclat à pointes autour d'un cœur plein
			var burst := PackedVector2Array()
			for i in 16:
				var t := -PI / 2.0 + PI * float(i) / 8.0
				burst.append(c + Vector2.from_angle(t) * (0.95 if i % 2 == 0 else 0.5) * s)
			_poly(ci, burst, k)
			if cut:
				_dot(ci, c, s, Vector2.ZERO, 0.22, b)
		"fx_range":
			# distance : double flèche entre deux bornes
			_ln(ci, c, s, Vector2(-0.95, -0.55), Vector2(-0.95, 0.55), k, w)
			_ln(ci, c, s, Vector2(0.95, -0.55), Vector2(0.95, 0.55), k, w)
			_ln(ci, c, s, Vector2(-0.5, 0), Vector2(0.5, 0), k, w * 1.2)
			_head(ci, c, s, Vector2(-0.82, 0), Vector2(-1, 0), 0.4, k)
			_head(ci, c, s, Vector2(0.82, 0), Vector2(1, 0), 0.4, k)
		"fx_pull":
			# attraction : quatre flèches vers le centre
			_dot(ci, c, s, Vector2.ZERO, 0.2, k)
			for i in 4:
				var dl := Vector2.from_angle(PI * 0.25 + PI * 0.5 * float(i))
				_ln(ci, c, s, dl * 0.95, dl * 0.55, k, w)
				_head(ci, c, s, dl * 0.36, -dl, 0.3, k)
		"fx_radius":
			# rayon : cercle et sa flèche du centre au bord
			_arc(ci, c, s, Vector2.ZERO, 0.85, 0.0, TAU, k, w)
			_dot(ci, c, s, Vector2.ZERO, 0.15, k)
			_ln(ci, c, s, Vector2.ZERO, Vector2(0.45, -0.45), k, w)
			_head(ci, c, s, Vector2(0.6, -0.6), Vector2(1, -1), 0.32, k)
		"fx_heart":
			_shp(ci, "heart", c, s, k, Vector2(0, 0.06), 0.95)
		"fx_crit":
			# coup critique : grande étoile à quatre branches et sa petite sœur
			_shp(ci, "star4", c, s, k, Vector2(-0.12, 0.1), 0.85)
			_shp(ci, "star4", c, s, k, Vector2(0.62, -0.6), 0.32)
		_:
			if name != "ink":
				glyph(ci, "ink", c, r, col, bg, a)


## Coupe `txt` en lignes d'au plus `width` pixels, mot à mot ; les mots de `glue` (ponctuation)
## ne commencent jamais une ligne.
static func wrap(font: Font, txt: String, fs: int, width: float, glue: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in txt.split(" ", false):
		var wd := String(word)
		var trial: String = wd if cur == "" else cur + " " + wd
		if cur != "" and not (wd in glue) and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			out.append(cur)
			cur = wd
		else:
			cur = trial
	if cur != "":
		out.append(cur)
	return out


## Aire d'un polygone (formule du lacet) : sert à sauter les morceaux trop fins avant de les dessiner
## (sinon la triangulation échoue et Godot écrit une erreur).
static func poly_area(pp: PackedVector2Array) -> float:
	var a := 0.0
	for i in pp.size():
		var p0 := pp[i]
		var p1 := pp[(i + 1) % pp.size()]
		a += p0.x * p1.y - p1.x * p0.y
	return absf(a * 0.5)


## Cintre (garde-robe) : crochet, épaules du cintre et petit kimono suspendu, dans un rayon s autour de c.
static func hanger_icon(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.2, s * 0.16)
	# crochet
	ci.draw_arc(c + Vector2(0, -s * 0.72), s * 0.2, PI * 1.05, PI * 2.2, 10, col, w, true)
	ci.draw_line(c + Vector2(0, -s * 0.52), c + Vector2(0, -s * 0.36), col, w, true)
	# barre du cintre
	ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.95, -s * 0.05), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.95, -s * 0.05)]), col, w, true)
	# kimono : manches et corps, col croisé
	var body := PackedVector2Array([c + Vector2(-s * 0.95, -s * 0.05), c + Vector2(-s * 0.95, s * 0.35), c + Vector2(-s * 0.5, s * 0.35),
		c + Vector2(-s * 0.5, s * 0.95), c + Vector2(s * 0.5, s * 0.95), c + Vector2(s * 0.5, s * 0.35), c + Vector2(s * 0.95, s * 0.35),
		c + Vector2(s * 0.95, -s * 0.05), c + Vector2(0, -s * 0.4)])
	ci.draw_colored_polygon(body, Color(col, col.a * 0.85))
	var hole := Color(1, 1, 1, 0.0)
	if col.v < 0.5:
		hole = Color(Toon.WASHI, col.a * 0.9)
	else:
		hole = Color(Toon.SUMI, col.a * 0.9)
	ci.draw_line(c + Vector2(-s * 0.3, -s * 0.22), c + Vector2(s * 0.12, s * 0.4), hole, w * 0.8, true)
	ci.draw_line(c + Vector2(s * 0.3, -s * 0.22), c + Vector2(-s * 0.02, s * 0.18), hole, w * 0.8, true)
	ci.draw_line(c + Vector2(-s * 0.5, s * 0.52), c + Vector2(s * 0.5, s * 0.52), hole, w * 0.9, true)


## Rouleau ouvert (makimono) du bestiaire tenant dans un rayon s : papier tendu entre deux baguettes,
## colonnes d'écriture et petit sceau vermillon ; hole : couleur des colonnes (NONE : papier clair ou encre).
static func scroll_icon(ci: CanvasItem, c: Vector2, s: float, col: Color, hole := NONE) -> void:
	var w := maxf(1.2, s * 0.16)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.62), Vector2(s * 1.4, s * 1.24)), Color(col, col.a * 0.85))
	for sx in [-1.0, 1.0]:
		var x := c.x + float(sx) * s * 0.8
		ci.draw_line(Vector2(x, c.y - s * 0.84), Vector2(x, c.y + s * 0.84), col, w * 1.6, true)
		ci.draw_circle(Vector2(x, c.y - s * 0.84), w, col)
		ci.draw_circle(Vector2(x, c.y + s * 0.84), w, col)
	var hc := hole
	if hc.a <= 0.0:
		hc = Color(Toon.WASHI, col.a * 0.9) if col.v < 0.5 else Color(Toon.SUMI, col.a * 0.9)
	for i in 3:
		var x := c.x + s * (0.36 - 0.28 * float(i))
		ci.draw_line(Vector2(x, c.y - s * 0.4), Vector2(x, c.y + s * (0.38 - 0.2 * float(i % 2))), hc, w * 0.8, true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.5, s * 0.14), Vector2(s * 0.26, s * 0.26)), Color(Toon.VERMILION, col.a))


# ------------------------------------------------------------------ pinceau et papier (accueil, pause, résultats)

## Petit bruit déterministe dans -1..1 (bords irréguliers, sans aléatoire : même dessin à chaque image).
static func _wob(x: float, sd: float) -> float:
	return 0.5 * sin(x * 12.9898 + sd * 78.233) + 0.5 * sin(x * 4.1 + sd * 3.7)


## Demi-épaisseur relative (0..1) d'un coup de pinceau horizontal en t : tête ronde, queue effilée.
static func swash_half(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return maxf(0.05, pow(maxf(0.0, sin(PI * x)), 0.3) * (1.0 - 0.5 * x * x))


## Point de l'axe du coup de pinceau tenant dans r (léger arc vers le haut).
static func swash_mid(r: Rect2, t: float) -> Vector2:
	return Vector2(r.position.x + r.size.x * t, r.get_center().y - r.size.y * 0.06 * sin(PI * clampf(t, 0.0, 1.0)))


## Contour du coup de pinceau tenant dans r ; reveal (0..1) le trace de gauche à droite.
static func swash_points(r: Rect2, reveal := 1.0, sd := 0.0) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var hh := r.size.y * 0.5
	var k := clampf(reveal, 0.02, 1.0)
	var n := clampi(int(r.size.x * k / 5.0), 4, 28)
	for i in n + 1:
		var t := k * float(i) / float(n)
		var mid := swash_mid(r, t)
		var th := hh * swash_half(t)
		top.append(mid - Vector2(0, th * (1.0 + 0.05 * _wob(float(i), sd))))
		bot.append(mid + Vector2(0, th * (1.0 + 0.05 * _wob(float(i) + 0.5, sd + 1.0))))
	bot.reverse()
	top.append_array(bot)
	return top


## Trait de pinceau de p0 (épais) à p1 (effilé), largeur w.
static func brush_line(ci: CanvasItem, p0: Vector2, p1: Vector2, w: float, col: Color) -> void:
	var d := p1 - p0
	if d.length() < 1.0 or w <= 0.0:
		return
	var nrm := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var t := float(i) / float(steps)
		pts.append(p0 + d * t + nrm * w * 0.5 * (0.55 + 0.45 * sin(PI * minf(1.0, t * 1.4 + 0.15))) * (1.0 - 0.7 * t))
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		pts.append(p0 + d * t - nrm * w * 0.5 * (0.55 + 0.45 * sin(PI * minf(1.0, t * 1.4 + 0.15))) * (1.0 - 0.7 * t))
	ci.draw_colored_polygon(pts, col)


## Ensō au pinceau : anneau ouvert, épais au départ et effilé au bout ; k (0..1) le trace depuis a0.
static func enso(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color, k := 1.0, a0 := -PI * 0.4) -> void:
	var sweep := TAU * 0.92 * clampf(k, 0.0, 1.0)
	if sweep < 0.05 or w <= 0.0 or r <= w:
		return
	var n := maxi(8, int(48.0 * sweep / TAU))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var dir := Vector2.from_angle(a0 + sweep * t)
		var hw := w * 0.5 * (1.0 - 0.7 * t) * (1.0 + 0.08 * _wob(float(i), 4.0))
		outer.append(c + dir * (r + hw))
		inner.append(c + dir * (r - hw))
	inner.reverse()
	outer.append_array(inner)
	ci.draw_colored_polygon(outer, col)


## Contour d'un rectangle aux bords barbés (deckle), coins nets : amp = écart, step = pas.
static func deckle_points(r: Rect2, amp: float, step: float, sd := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var idx := 0
	for e in 4:
		var p0: Vector2 = corners[e]
		var p1: Vector2 = corners[(e + 1) % 4]
		var d := p1 - p0
		var n := maxi(2, int(d.length() / maxf(step, 1.0)))
		var out := Vector2(d.y, -d.x).normalized()  # vers l'extérieur (tour dans le sens horaire)
		for i in n:
			var t := float(i) / float(n)
			var j := 0.0
			if i > 0:
				j = amp * _wob(float(idx), sd)
			pts.append(p0 + d * t + out * j)
			idx += 1
	return pts


## Feuille de washi : ombre douce, papier aux bords barbés, quelques fibres et un filet intérieur.
static func washi_sheet(ci: CanvasItem, r: Rect2, paper: Color, ink: Color, a: float, u: float, sd := 0.0) -> void:
	var pts := deckle_points(r, 1.6 * u, 6.0 * u, sd)
	ci.draw_colored_polygon(Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0, 9.0 * u)) * pts, Color(0, 0, 0, 0.1 * a))
	ci.draw_colored_polygon(Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0, 3.0 * u)) * pts, Color(0, 0, 0, 0.14 * a))
	ci.draw_colored_polygon(pts, Color(paper, a))
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(ink, 0.22 * a), maxf(1.0, 1.1 * u), true)
	# fibres du papier
	for i in 14:
		var p := r.position + Vector2((0.5 + 0.46 * _wob(float(i), sd + 7.0)) * r.size.x, (0.5 + 0.46 * _wob(float(i) + 2.3, sd + 9.0)) * r.size.y)
		var dv := Vector2.from_angle(_wob(float(i), sd + 11.0) * PI) * (6.0 + 5.0 * absf(_wob(float(i), sd + 13.0))) * u
		ci.draw_line(p, p + dv, Color(ink, 0.045 * a), maxf(1.0, 0.8 * u), true)
	ci.draw_rect(r.grow(-7.0 * u), Color(ink, 0.1 * a), false, maxf(1.0, 0.9 * u))


## Sceau (hanko) : bords usés, filet intérieur, caractères en colonne (chars peut être vide).
static func hanko(ci: CanvasItem, r: Rect2, chars: String, col: Color, paper: Color, a: float, u: float, sd := 0.0) -> void:
	ci.draw_colored_polygon(deckle_points(r, 0.9 * u, 4.0 * u, sd), Color(col, a))
	ci.draw_rect(r.grow(-3.0 * u), Color(paper, 0.7 * a), false, maxf(1.0, 1.2 * u))
	var n := chars.length()
	if n > 0:
		var step := (r.size.y - 6.0 * u) / float(n)
		var fs := int(minf(r.size.x * 0.64, step * 0.84))
		for i in n:
			var cy := r.position.y + 3.0 * u + step * (float(i) + 0.5)
			text(ci, TITLE_FONT, chars.substr(i, 1), Vector2(r.get_center().x, cy + fs * 0.36), fs, Color(paper, a))
	# usure : quelques points de papier
	for i in 5:
		var p := r.position + Vector2((0.5 + 0.4 * _wob(float(i), sd + 2.0)) * r.size.x, (0.5 + 0.4 * _wob(float(i) + 3.0, sd)) * r.size.y)
		ci.draw_circle(p, (0.5 + 0.5 * absf(_wob(float(i), sd + 5.0))) * u, Color(paper, 0.45 * a))


## Marges de sécurité (encoche en haut, barre de geste en bas) en pixels de l'écran `view` ; nulles sur ordinateur.
static func safe_insets(view: Vector2) -> Vector2:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return Vector2.ZERO
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var k := view.y / float(win.y)
	var top := clampf(float(safe.position.y) * k, 0.0, view.y * 0.1)
	var bot := clampf(float(win.y - safe.end.y) * k, 0.0, view.y * 0.1)
	return Vector2(top, bot)


# ------------------------------------------------------------------ système de design : composants
# Dessins communs aux écrans (voir les mesures en tête de fichier). Tout est en pixels de l'écran :
# l'appelant passe u. Les motifs (seigaiha, asanoha) sont calculés une fois par taille, puis
# redessinés d'un seul appel (draw_multiline).

static var _pat := {}  # motifs en cache : clé -> segments (coordonnées locales du cadre)


## Or lisible sur le papier du thème (foncé sur papier clair, vif sur papier sombre).
static func gold() -> Color:
	return GOLD_HI if Toon.ui_dark else GOLD_INK


## Tous les caractères de `chars` existent dans la police réduite des titres.
static func has_glyphs(chars: String) -> bool:
	for i in chars.length():
		if not TITLE_FONT.has_char(chars.unicode_at(i)):
			return false
	return true


## Sceau à kanji (hanko) ; si un caractère manque à la police réduite, un mon à losanges le remplace.
static func seal(ci: CanvasItem, r: Rect2, chars: String, col: Color, paper: Color, a: float, u: float, sd := 0.0) -> void:
	if has_glyphs(chars):
		hanko(ci, r, chars, col, paper, a, u, sd)
		return
	hanko(ci, r, "", col, paper, a, u, sd)
	mon(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.3, "hishi", Color(paper, 0.9 * a), false)


## Titre d'écran : capitales (font : variation espacée de TITLE_FONT) centrées sur c.x, ligne de base c.y,
## soulignées d'un coup de pinceau vermillon. kanji : ignoré (UI v2 : plus de sceau à côté des titres ;
## paramètre gardé pour les appelants). Rétrécit pour tenir dans maxw (0 : sans limite) ; k (0..1) pose le trait.
## Renvoie la largeur du titre.
static func screen_title(ci: CanvasItem, font: Font, txt: String, c: Vector2, u: float, ink: Color, a: float,
		kanji := "", maxw := 0.0, k := 1.0) -> float:
	var px := maxi(1, int(FS_TITLE * u))
	var sp := 0.0
	if font is FontVariation:
		sp = float((font as FontVariation).spacing_glyph)
	var sw := 0.0
	if kanji != "" and KANJI_SEALS:
		sw = 28.0 * u
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x - sp
	if maxw > 0.0 and tw + sw > maxw and tw > 0.0:
		px = maxi(1, int(float(px) * maxf(0.2, maxw - sw) / tw))
		tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x - sp
	var x0 := c.x - (tw + sw) / 2.0
	ci.draw_string(font, Vector2(x0, c.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(ink, ink.a * a))
	var kk := clampf(k, 0.0, 1.0)
	if kk > 0.05 and tw > 1.0:
		var bw := maxf(tw * 0.55, 40.0 * u)
		var br := Rect2(Vector2(x0 + tw / 2.0 - bw / 2.0, c.y + 5.0 * u), Vector2(bw, 7.0 * u))
		ci.draw_colored_polygon(swash_points(br, kk, 5.0), Color(Toon.VERMILION, 0.95 * a))
	if kanji != "" and KANJI_SEALS:
		var s := 20.0 * u
		var cy := c.y - float(px) * 0.36
		seal(ci, Rect2(Vector2(x0 + tw + 8.0 * u, cy - s / 2.0), Vector2(s, s)), kanji, Toon.VERMILION, Toon.WASHI, a, u, 3.0)
	return tw


## Disque d'un bouton rond (retour, réglages, son) : ombre, lavis, cerne d'encre ; même dessin qu'InkButton « round ».
static func icon_disc(ci: CanvasItem, c: Vector2, rr: float, ink: Color, wash: Color, a := 1.0) -> void:
	ci.draw_circle(c + Vector2(0, 2), rr, Color(0, 0, 0, 0.2 * a))
	ci.draw_circle(c, rr, Color(wash, 0.95 * a))
	ci.draw_arc(c, rr - 1.0, 0.0, TAU, 40, Color(ink, 0.75 * a), 2.0, true)


## Flèche de retour (pointe à gauche) tenant dans un rayon s.
static func back_arrow(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.28)
	var head := c + Vector2(-s * 0.75, 0.0)
	ci.draw_line(c + Vector2(s * 0.8, 0.0), head, col, w, true)
	ci.draw_line(head, head + Vector2(s * 0.6, -s * 0.6), col, w, true)
	ci.draw_line(head, head + Vector2(s * 0.6, s * 0.6), col, w, true)
	ci.draw_circle(head, w * 0.5, col)


## Maison (retour à l'accueil) tenant dans un rayon s ; hole : la porte (couleur du fond).
static func home_icon(ci: CanvasItem, c: Vector2, s: float, ink: Color, hole: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.05), c + Vector2(0, -s), c + Vector2(s, -s * 0.05)]), ink)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 0.95)), ink)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.18, s * 0.3), Vector2(s * 0.36, s * 0.55)), hole)


## Bouton retour dessiné (écrans sans InkButton), centré en c ; press (0..1) : enfoncé ;
## home : maison d'encre (retour à l'accueil) au lieu de la flèche vermillon.
static func back_button(ci: CanvasItem, c: Vector2, u: float, a: float, press := 0.0, home := false) -> void:
	var rr := ICON_BTN * 0.5 * u * (1.0 - 0.06 * clampf(press, 0.0, 1.0))
	icon_disc(ci, c, rr, Toon.ui_ink, Toon.ui_wash, a)
	if home:
		home_icon(ci, c, rr * ICON_GLYPH, Color(Toon.ui_ink, a), Color(Toon.ui_wash, a))
	else:
		back_arrow(ci, c, rr * ICON_GLYPH, Color(Toon.VERMILION, a))


## Zone tactile du bouton retour centré en c (plus large que le dessin).
static func back_rect(c: Vector2, u: float) -> Rect2:
	var hs := 26.0 * u
	return Rect2(c - Vector2(hs, hs), Vector2(hs, hs) * 2.0)


## Shuriken (quatre lames recourbées) : puce, fin de filet ; hole : couleur du trou central (NONE : aucun).
static func shuriken(ci: CanvasItem, c: Vector2, r: float, col: Color, rot := 0.0, hole := NONE) -> void:
	if r <= 0.5:
		return
	if not _shapes.has("shuriken"):
		var sh := PackedVector2Array()
		for k in 4:
			var t := PI * 0.5 * float(k)
			sh.append(Vector2.from_angle(t))
			sh.append(Vector2.from_angle(t + 0.5) * 0.42)
			sh.append(Vector2.from_angle(t + PI * 0.25) * 0.26)
		_shapes["shuriken"] = sh
	var pts: PackedVector2Array = _shapes["shuriken"]
	_poly(ci, Transform2D(rot, Vector2(r, r), 0.0, c) * pts, col)
	if hole.a > 0.01:
		ci.draw_circle(c, r * 0.18, hole)


## Kunai couché en p (centre), pointe vers dir, longueur l : lame en losange, poignée, anneau.
static func kunai(ci: CanvasItem, p: Vector2, dir: Vector2, l: float, col: Color) -> void:
	var d := dir.normalized()
	if d == Vector2.ZERO or l <= 1.0:
		return
	var n := Vector2(-d.y, d.x)
	_poly(ci, PackedVector2Array([p + d * l * 0.5, p + d * l * 0.06 + n * l * 0.13, p - d * l * 0.06, p + d * l * 0.06 - n * l * 0.13]), col)
	ci.draw_line(p - d * l * 0.06, p - d * l * 0.34, col, maxf(1.0, l * 0.08), true)
	ci.draw_arc(p - d * l * 0.42, l * 0.08, 0.0, TAU, 12, col, maxf(1.0, l * 0.04), true)


## Filet au pinceau : deux traits effilés qui partent d'un shuriken vermillon central (séparateur de blocs).
static func brush_rule(ci: CanvasItem, x0: float, x1: float, y: float, u: float, col: Color, a := 1.0) -> void:
	var cx := (x0 + x1) / 2.0
	var gap := 8.0 * u
	var c := Color(col, col.a * a)
	brush_line(ci, Vector2(cx - gap, y), Vector2(x0, y), 2.2 * u, c)
	brush_line(ci, Vector2(cx + gap, y), Vector2(x1, y), 2.2 * u, c)
	shuriken(ci, Vector2(cx, y), 4.5 * u, Color(Toon.VERMILION, 0.85 * a), 0.2)


## Titre de section : petites capitales, trait de pinceau jusqu'à x1 fini par un shuriken (kanji : ignoré en UI v2,
## voir KANJI_SEALS). y : ligne de base du libellé ; font : UI_FONT (ou sa variation) ; ink : encre pleine.
static func section(ci: CanvasItem, font: Font, label: String, x0: float, x1: float, y: float, u: float, ink: Color, a: float, kanji := "") -> void:
	var px := maxi(1, int(FS_CAPTION * u))
	var mid := y - float(px) * 0.36
	var x := x0
	if kanji != "" and KANJI_SEALS:
		var s := 16.0 * u
		seal(ci, Rect2(Vector2(x0, mid - s / 2.0), Vector2(s, s)), kanji, Toon.VERMILION, Toon.WASHI, a, u, 2.0)
		x += s + 6.0 * u
	ci.draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(ink, ink.a * 0.6 * a))
	var lx0 := x + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 8.0 * u
	var lx1 := x1 - 9.0 * u
	if lx1 - lx0 > 12.0 * u:
		brush_line(ci, Vector2(lx0, mid), Vector2(lx1, mid), 2.4 * u, Color(ink, ink.a * 0.22 * a))
		shuriken(ci, Vector2(x1 - 4.0 * u, mid), 4.0 * u, Color(Toon.VERMILION, 0.75 * a), 0.3)


## Puce ou segment en pilule : on = plein de fg, texte en bg, pointe vermillon à gauche ; sinon cerné de fg.
## dim : grisé (sans effet). Le libellé rétrécit pour tenir. sb : StyleBoxFlat réutilisée par l'écran.
static func chip(ci: CanvasItem, sb: StyleBoxFlat, r: Rect2, label: String, font: Font, px: int, on: bool, fg: Color, bg: Color, a: float, dim := false) -> void:
	var rad := int(r.size.y / 2.0)
	var k := 0.4 if dim else 1.0
	if on:
		ci.draw_style_box(box(sb, Color(fg, a * k), rad), r)
	else:
		ci.draw_style_box(box(sb, Color(0, 0, 0, 0), rad, Color(fg, 0.3 * a * k), maxi(1, int(r.size.y * 0.035))), r)
	var f := maxi(1, px)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x
	# pointe vermillon seulement s'il reste la place (puces étroites : le texte d'abord)
	var dot := on and not dim and tw <= r.size.x - r.size.y * 1.1
	var maxw := r.size.x - r.size.y * (1.1 if dot else 0.4)
	if tw > maxw and tw > 0.0 and maxw > 0.0:
		f = maxi(1, int(float(f) * maxw / tw))
	var tc: Color = Color(fg, a * (0.35 if dim else 0.8))
	if on:
		tc = Color(bg, a * (0.6 if dim else 1.0))
	text(ci, font, label, Vector2(r.get_center().x, r.get_center().y + float(f) * 0.36), f, tc)
	if dot:
		ci.draw_circle(Vector2(r.position.x + r.size.y * 0.42, r.get_center().y), maxf(1.5, r.size.y * 0.07), Color(Toon.VERMILION, a))


## Fibres de papier (washi) sur un cadre : quelques brins d'encre très pâles, toujours au même endroit.
static func fibres(ci: CanvasItem, r: Rect2, ink: Color, a: float, u: float, sd := 0.0, n := 10) -> void:
	for i in n:
		var p := r.position + Vector2((0.5 + 0.44 * _wob(float(i), sd + 7.0)) * r.size.x, (0.5 + 0.44 * _wob(float(i) + 2.3, sd + 9.0)) * r.size.y)
		var dv := Vector2.from_angle(_wob(float(i), sd + 11.0) * PI) * (5.0 + 4.0 * absf(_wob(float(i), sd + 13.0))) * u
		ci.draw_line(p, (p + dv).clamp(r.position, r.end), Color(ink, 0.05 * a), maxf(1.0, 0.8 * u), true)


## Feuille d'une fenêtre (options, pause, mes pouvoirs, résultats) : washi aux bords barbés et, sur
## `head` × u de haut, des vagues seigaiha très pâles (0 : aucune) fermées d'un filet.
static func sheet(ci: CanvasItem, r: Rect2, paper: Color, ink: Color, a: float, u: float, sd := 0.0, head := 0.0) -> void:
	washi_sheet(ci, r, paper, ink, a, u, sd)
	if head > 0.0:
		var band := Rect2(r.position + Vector2(8.0, 8.0) * u, Vector2(r.size.x - 16.0 * u, head * u))
		seigaiha(ci, band, Color(ink, A_PATTERN * a), 13.0 * u)
		ci.draw_line(Vector2(band.position.x, band.end.y), Vector2(band.end.x, band.end.y), Color(ink, 0.07 * a), maxf(1.0, 0.8 * u))


## Segments mis en cache d'un motif (clé, taille, cellule) ; vide si trop petit.
static func _pattern(kind: String, size: Vector2, cell: float) -> PackedVector2Array:
	var w := float(int(size.x))
	var h := float(int(size.y))
	var cl := float(maxi(3, int(cell)))
	var key := "%s%d_%d_%d" % [kind, int(w), int(h), int(cl)]
	if _pat.has(key):
		var hit: PackedVector2Array = _pat[key]
		return hit
	if _pat.size() > 24:
		_pat.clear()
	var r := Rect2(Vector2.ZERO, Vector2(w, h))
	var segs := PackedVector2Array()
	if kind == "s":
		segs = _seigaiha_segs(r, cl)
	else:
		segs = _asanoha_segs(r, cl)
	_pat[key] = segs
	return segs


## Ajoute le segment [p0, p1] à `out` (un Array, passé par référence) s'il tient dans r.
static func _seg(out: Array, r: Rect2, p0: Vector2, p1: Vector2) -> void:
	if r.has_point(p0) and r.has_point(p1):
		out.append(p0)
		out.append(p1)


## Écailles du seigaiha (rayon R) : arcs du haut, sans ce que cache la rangée du dessous (décalée de R, R/2).
static func _seigaiha_segs(r: Rect2, cr: float) -> PackedVector2Array:
	var cell := PackedVector2Array()
	var below := [Vector2(-cr, cr * 0.5), Vector2(cr, cr * 0.5)]
	for ring in [0.96, 0.68, 0.4]:
		var rad := cr * float(ring)
		var n := 10
		for i in n:
			var t0 := PI + PI * float(i) / float(n)
			var t1 := PI + PI * float(i + 1) / float(n)
			var p0 := Vector2(cos(t0), sin(t0)) * rad
			var p1 := Vector2(cos(t1), sin(t1)) * rad
			var m := (p0 + p1) * 0.5
			var hidden := false
			for b in below:
				var bv: Vector2 = b
				if m.distance_to(bv) < cr:
					hidden = true
			if not hidden:
				cell.append(p0)
				cell.append(p1)
	var out: Array = []
	var rows := int(r.size.y / (cr * 0.5)) + 3
	var cols := int(r.size.x / (cr * 2.0)) + 3
	for j in rows:
		var ox := cr if j % 2 == 1 else 0.0
		for i in cols:
			var c := Vector2(float(i) * cr * 2.0 + ox - cr, float(j) * cr * 0.5)
			for k in range(0, cell.size() - 1, 2):
				_seg(out, r, c + cell[k], c + cell[k + 1])
	return PackedVector2Array(out)


## Asanoha (feuille de chanvre) : réseau de triangles de côté s, chaque triangle partagé en trois vers son centre.
static func _asanoha_segs(r: Rect2, s: float) -> PackedVector2Array:
	var out: Array = []
	var hh := s * sqrt(3.0) / 2.0
	var rows := int(r.size.y / hh) + 2
	var cols := int(r.size.x / s) + 2
	for j in rows:
		var y := float(j) * hh
		var ox := s * 0.5 if j % 2 == 1 else 0.0
		for i in range(-1, cols):
			var p := Vector2(float(i) * s + ox, y)
			var q := p + Vector2(s, 0.0)
			var dn := Vector2(p.x + s * 0.5, y + hh)
			var up := Vector2(p.x + s * 0.5, y - hh)
			_seg(out, r, p, q)
			_seg(out, r, p, dn)
			_seg(out, r, q, dn)
			var g := (p + q + dn) / 3.0
			_seg(out, r, p, g)
			_seg(out, r, q, g)
			_seg(out, r, dn, g)
			var g2 := (p + q + up) / 3.0
			_seg(out, r, p, g2)
			_seg(out, r, q, g2)
			_seg(out, r, up, g2)
	return PackedVector2Array(out)


## Seigaiha (vagues de la mer, Hokusai) en traits fins de couleur col dans r ; cell : rayon d'une écaille (px).
static func seigaiha(ci: CanvasItem, r: Rect2, col: Color, cell: float) -> void:
	if r.size.x < 4.0 or r.size.y < 4.0 or col.a <= 0.0:
		return
	var segs := _pattern("s", r.size, cell)
	if segs.size() >= 2:
		ci.draw_multiline(Transform2D(0.0, r.position) * segs, col)


## Asanoha (feuille de chanvre, kimono et kumiko) en traits fins de couleur col dans r ; cell : côté (px).
static func asanoha(ci: CanvasItem, r: Rect2, col: Color, cell: float) -> void:
	if r.size.x < 4.0 or r.size.y < 4.0 or col.a <= 0.0:
		return
	var segs := _pattern("a", r.size, cell)
	if segs.size() >= 2:
		ci.draw_multiline(Transform2D(0.0, r.position) * segs, col)


## Mon (blason de clan) de rayon r : « tomoe » (trois virgules), « hishi » (quatre losanges),
## « kikko » (carapace hexagonale), « kikyo » (campanule) ; ring : cerclé d'un anneau.
static func mon(ci: CanvasItem, c: Vector2, r: float, kind: String, col: Color, ring := true) -> void:
	if r <= 1.0:
		return
	var w := maxf(1.0, r * 0.09)
	var k := r
	if ring:
		ci.draw_arc(c, r * 0.94, 0.0, TAU, 40, col, w, true)
		k = r * 0.76
	match kind:
		"tomoe":
			# virgule d'un seul polygone (pas de recouvrement : la couleur reste égale même transparente) :
			# queue qui s'enroule en s'effilant, puis l'arrière rond de la tête
			for i in 3:
				var a0 := TAU * float(i) / 3.0
				var left := PackedVector2Array()
				var right := PackedVector2Array()
				for j in 9:
					var t := float(j) / 8.0
					var ang := a0 + t * 1.7
					var p := c + Vector2.from_angle(ang) * lerpf(0.38, 0.6, t) * k
					var hw := (0.3 * (1.0 - t) + 0.02) * k
					left.append(p + Vector2.from_angle(ang) * hw)
					right.append(p - Vector2.from_angle(ang) * hw)
				right.reverse()
				left.append_array(right)
				var hc := c + Vector2.from_angle(a0) * 0.38 * k
				for m in range(1, 8):
					left.append(hc + Vector2.from_angle(a0 - PI + PI * float(m) / 8.0) * 0.32 * k)
				ci.draw_colored_polygon(left, col)
		"kikko":
			var hexa := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in 7:
				var t := -PI / 2.0 + TAU * float(i % 6) / 6.0
				hexa.append(c + Vector2.from_angle(t) * 0.9 * k)
				if i < 6:
					inner.append(c + Vector2.from_angle(t) * 0.42 * k)
			ci.draw_polyline(hexa, col, w * 1.3, true)
			ci.draw_colored_polygon(inner, col)
		"kikyo":
			_shp(ci, "star5", c, k, col, Vector2.ZERO, 0.95)
		_:
			for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				var dv: Vector2 = d
				var q := c + dv * 0.46 * k
				var e := 0.38 * k
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -e), q + Vector2(e, 0), q + Vector2(0, e), q + Vector2(-e, 0)]), col)


# ------------------------------------------------------------------ libellés des rouleaux (choix de pouvoir)

# nom en clair de chaque figure tracée
const FIG_WORD := {"loop": "BOUCLE", "zigzag": "ZIGZAG", "return": "ALLER-RETOUR", "straight": "TRAIT DROIT",
	"enso": "ENSO", "hook": "CROCHET"}
# déclencheur (champ « trig ») en un ou deux mots, quand la phrase complète ne tient pas
const TRIG_WORD := {"hit": "À CHAQUE COUP", "stroke": "À CHAQUE TRAIT", "arrive": "À L'ARRIVÉE", "kill": "EN TUANT",
	"always": "PERMANENT", "dodge": "ESQUIVE", "hurt": "SI TOUCHÉ", "multi": "MULTI-TOUCHE", "target": "CIBLE",
	"timer": "MINUTERIE", "once": "1 FOIS", "now": "IMMÉDIAT", "luck": "ROULEAUX", "school": "ÉCOLE",
	"back": "DANS LE DOS", "touch": "DOIGT POSÉ", "figure": "TECHNIQUE"}


## Figure qui déclenche un pouvoir ("loop", "zigzag"…) : la sienne pour un rouleau de figure,
## sinon celle de l'unique technique requise ; "" s'il n'y en a pas.
static func trigger_figure(id: String) -> String:
	for f in Data.FIG_UNLOCK.keys():
		if id == String(Data.FIG_UNLOCK[f]) or id.begins_with(String(Data.FIG_UNLOCK[f]) + "_"):
			return String(f)
	var d: Dictionary = Data.POWERS.get(id, {})
	var needs: Array = d.get("needs", [])
	if needs.size() == 1:
		for f in Data.FIG_UNLOCK.keys():
			if String(needs[0]) == String(Data.FIG_UNLOCK[f]):
				return String(f)
	return ""


## Déclencheur en un ou deux mots (sans macrons).
static func trigger_word(id: String) -> String:
	var f := trigger_figure(id)
	if f != "":
		return String(FIG_WORD.get(f, "FIGURE"))
	var d: Dictionary = Data.POWERS.get(id, {})
	return plain(String(TRIG_WORD.get(String(d.get("trig", "always")), "PERMANENT")))


# sens des déclencheurs qui ne parlent pas d'eux-mêmes (explication des rouleaux)
const TRIG_HINT := {"back": "frappe de dos", "arrive": "fin de ton trait", "multi": "plusieurs ennemis d'un trait",
	"timer": "à intervalle régulier"}


## Déclencheur et son sens, en une courte ligne (« DANS LE DOS = frappe de dos », « ENSO = trace la figure ») ;
## "" si le mot se comprend seul.
static func trigger_hint(id: String) -> String:
	var f := trigger_figure(id)
	if f != "":
		return "%s = trace la figure" % String(FIG_WORD.get(f, "FIGURE"))
	var d: Dictionary = Data.POWERS.get(id, {})
	var trig := String(d.get("trig", ""))
	if not TRIG_HINT.has(trig):
		return ""
	return plain("%s = %s" % [String(TRIG_WORD.get(trig, "")), String(TRIG_HINT[trig])])


## Pictogramme d'une ligne de valeur (« Explosion : 3 dégâts », « Garde : 1,2 s »…), d'après ses mots.
static func stat_icon(txt: String) -> String:
	var t := txt.to_lower()
	if t.contains("cœur"):
		return "heart_plus"
	if t.contains("dégât") or t.contains("×"):
		return "t_hit"
	if t.contains("ennemi") or t.contains("cible"):
		return "t_multi"
	if t.ends_with(" s") or t.contains(" s ") or t.contains("ralenti") or t.contains("invincible"):
		return "hourglass"
	if t.ends_with(" m") or t.contains(" m ") or t.contains("portée") or t.contains("trait"):
		return "long_stroke"
	if t.contains("%"):
		return "t_luck"
	return "t_always"


## Dégâts en pourcentage d'un coup de sabre (1 dégât = 100 %) : « 0,8 dégât » -> « 80 % des dégâts ».
static var _dmg_re: RegEx = null


static func dmg_pct(txt: String) -> String:
	if _dmg_re == null:
		_dmg_re = RegEx.new()
		_dmg_re.compile("([0-9]+(?:,[0-9]+)?) dégâts?")
	var out := txt
	for m in _dmg_re.search_all(txt):
		var f := m.get_string(1).replace(",", ".").to_float()
		out = out.replace(m.get_string(0), "%d %% des dégâts" % int(roundf(f * 100.0)))
	return out


# ------------------------------------------------------------------ effet d'un pouvoir en pastilles

## Nombre à la française (virgule décimale, deux décimales au plus).
static func fr_num(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return str(int(roundf(v)))
	return str(snappedf(v, 0.01)).replace(".", ",")


## Valeur d'un pouvoir au niveau l pour la clé "v" / "w" ; pct : dégâts en % d'un coup de sabre (0,5 -> 50).
static func _fx_val(d: Dictionary, key: String, l: int, pct: bool) -> String:
	var arr: Array = d.get(key, [])
	if arr.is_empty():
		return "?"
	var f := float(arr[clampi(l - 1, 0, arr.size() - 1)])
	if pct:
		return str(int(roundf(f * 100.0)))
	return fr_num(f)


## Remplit « {v} », « {w} », « {v%} », « {w%} » au niveau b ; « avant → après » si a > 0 et la valeur change.
static func _fx_fill(d: Dictionary, src: String, a: int, b: int) -> String:
	var out := src
	for tag in ["{v%}", "{w%}", "{v}", "{w}"]:
		var tg := String(tag)
		if not out.contains(tg):
			continue
		var key := tg.substr(1, 1)
		var pct := tg.contains("%")
		var after := _fx_val(d, key, b, pct)
		var txt := after
		if a > 0 and a != b:
			var before := _fx_val(d, key, a, pct)
			if before != after:
				# « ×2 → ×2,5 », « +20 → +30 % » : le signe collé à la valeur se répète après la flèche
				var at := out.find(tg)
				var sg := out.substr(at - 1, 1) if at > 0 else ""
				txt = before + " → " + (sg if sg == "×" or sg == "+" else "") + after
		out = out.replace(tg, txt)
	return out


## Libellé accordé à une valeur unique : « +1 cibles » -> « +1 cible », « 1 ennemis tués » -> « 1 ennemi tué ».
static func _fx_one(val: String, lab: String) -> String:
	if val != "1" and val != "+1":
		return lab
	var words := lab.split(" ")
	for k in words.size():
		var wd := String(words[k])
		if wd.length() > 2 and wd.ends_with("s"):
			words[k] = wd.substr(0, wd.length() - 1)
	return " ".join(words)


## Effet d'un pouvoir en pastilles : [[pictogramme, valeur, libellé], …] (niveau b ; « avant → après » depuis le
## niveau a > 0). Sans fiche dans Data.EFFECTS : la ligne chiffrée « stat » en une pastille. Jamais le nom du pouvoir.
static func fx_rows(id: String, a: int, b: int) -> Array:
	var out: Array = []
	var d: Dictionary = Data.POWERS.get(id, {})
	if d.is_empty():
		return out
	var e: Dictionary = Data.EFFECTS.get(id, {})
	var rows: Array = e.get("fx", [])
	var name_l := power_label(id).to_lower()
	for row in rows:
		var rw: Array = row
		if rw.size() < 3:
			continue
		var lab := plain(String(rw[2]))
		if lab.to_lower() == name_l:
			lab = ""
		var val := plain(_fx_fill(d, String(rw[1]), a, b))
		out.append([String(rw[0]), val, _fx_one(val, lab)])
	if out.is_empty():
		var st := String(d.get("stat", ""))
		if st != "":
			var line := plain(dmg_pct(_fx_fill(d, st, a, b)))
			out.append([stat_icon(line), line, ""])
	return out


## Déclencheur d'un pouvoir en 1-2 mots (bulle de détail), sinon le mot du déclencheur.
static func fx_when(id: String) -> String:
	var e: Dictionary = Data.EFFECTS.get(id, {})
	var tw := String(e.get("tw", ""))
	if tw != "":
		return plain(tw)
	var w := trigger_word(id)
	return w.substr(0, 1) + w.substr(1).to_lower()


## Une phrase courte qui explique le pouvoir (bulle de détail), sinon son texte complet.
static func fx_line(id: String) -> String:
	var e: Dictionary = Data.EFFECTS.get(id, {})
	var ln := String(e.get("line", ""))
	if ln != "":
		return plain(ln)
	var d: Dictionary = Data.POWERS.get(id, {})
	return plain(String(d.get("text", "")))


## Effet en une ligne compacte : « 0,5 s invulnérable · 50 % éclat » (listes étroites).
static func fx_compact(rows: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row in rows:
		var rw: Array = row
		var v := String(rw[1])
		var l := String(rw[2])
		parts.append((v + " " + l).strip_edges() if v != "" else l)
	return " · ".join(parts)


# ------------------------------------------------------------------ UI v2 : chiffres, capitales, pictogrammes SVG
# Handoff design/ui_v2 : chiffres en Zen Kaku Gothic New Black tabulaire, pictogrammes SVG (ui_icons.gd) rastérisés
# à la taille voulue, médaillons de pouvoir (disque washi, pictogramme sumi), anneau d'harmonie, halos sans flou.

const SVG_HEAD := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
# lettres capitales absentes de la police réduite : remplacées par leur forme sans accent
const CAPS_FALLBACK := {"Û": "U", "Ù": "U", "Ü": "U", "Ë": "E", "Ï": "I", "Î": "I", "Ô": "O", "Â": "A", "À": "A",
	"Ç": "C", "É": "E", "È": "E", "Ê": "E", "Œ": "OE"}
# pictogramme d'effet (Data.EFFECTS, fx_rows) -> pictogramme v2 (icons/effets) ; les autres gardent leur glyph()
const FX_ICON := {"fire": "effets/brulure", "hourglass": "effets/duree", "clock": "effets/duree", "fx_dmg": "effets/degats",
	"t_hit": "effets/degats", "backstab": "effets/degats", "fx_heart": "effets/cur", "heart_plus": "effets/cur",
	"chain_bolt": "effets/cibles", "t_multi": "effets/cibles", "fx_crit": "effets/critique", "stun": "effets/etourdi",
	"fx_range": "effets/portee", "long_stroke": "effets/portee", "fx_radius": "effets/portee", "push_wave": "effets/recul",
	"speed": "effets/vitesse"}
# déclencheur (champ « trig ») -> pictogramme v2 (icons/declencheurs) ; les autres gardent leur glyph « t_… »
const TRIG_ICON := {"arrive": "declencheurs/a_larrivee", "back": "declencheurs/dans_le_dos", "stroke": "declencheurs/pendant_la_ruee",
	"hurt": "declencheurs/quand_touche", "figure": "declencheurs/sur_figure"}
# figure tracée -> pictogramme v2 (icons/figures, à l'encre de la figure)
const FIG_ICON := {"loop": "figures/boucle", "zigzag": "figures/zigzag", "straight": "figures/trait_droit",
	"return": "figures/aller_retour", "enso": "figures/enso", "hook": "figures/crochet"}
# glyphe d'un pouvoir dans son médaillon (gabarit 60, disque de rayon 28) : [tracé SVG, remplissage à la couleur
# d'élément ?]. Pouvoirs dessinés par la maquette (Rouleaux, MesPouvoirs) ; les autres gardent glyph(icon_of(id)).
const POWER_GLYPH := {
	"water_tide": ["M18 32 a12 12 0 0 1 24 0 M11 32 a19 19 0 0 1 38 0 M25 32 a5 5 0 0 1 10 0 M18 40 a12 12 0 0 0 24 0", false],
	"bolt_arc": ["M15 44 L26 30 L34 37 L45 17 M15 44 m-3 0 a3 3 0 1 0 6 0 M45 17 m-3 0 a3 3 0 1 0 6 0", false],
	"fire_burn": ["M15 45 L38 22 M34 18 L42 26 M40 33 C44 39 47 41 45 45 A4 4 0 0 1 37 45 C36 41 38 39 40 33 Z", true],
	"fig_hook": ["M13 30 H45 M38 23 L46 30 L38 37 M13 25 V35", false],
	"fig_hook_double": ["M13 24 H43 M36 18 L44 24 L36 30 M13 36 H43 M36 30 L44 36 L36 42", false],
	"fig_hook_back": ["M13 30 H45 M38 23 L46 30 L38 37 M18 21 L23 30 L18 39", false],
}

static var _num_font: FontVariation = null
static var _tex := {}  # textures SVG en cache : clé|taille|couleurs -> ImageTexture (null : échec)
static var _hex_re: RegEx = null


## Police des chiffres (UI v2) : Zen Kaku Gothic New. Seule la graisse Bold est embarquée : la Black 900 est
## imitée par un léger embolden ; chiffres tabulaires (tnum) si la police les a.
static func num_font() -> Font:
	if _num_font == null:
		var f := FontVariation.new()
		f.base_font = UI_FONT
		f.variation_embolden = 0.45
		var ts := TextServerManager.get_primary_interface()
		if ts != null:
			f.opentype_features = {ts.name_to_tag("tnum"): 1}
		_num_font = f
	return _num_font


## Capitales lisibles par la police réduite (sans macrons ; « Û » absent -> « U »).
static func caps(s: String, font: Font = null) -> String:
	var f: Font = font if font != null else UI_FONT
	var up := plain(s).to_upper()
	var out := ""
	for i in up.length():
		var ch := up.substr(i, 1)
		if CAPS_FALLBACK.has(ch) and not f.has_char(up.unicode_at(i)):
			ch = String(CAPS_FALLBACK[ch])
		out += ch
	return out


## Dimension déclarée (la plus grande de width / height) de la balise racine d'un SVG.
static func _svg_dim(s: String) -> float:
	var out := 0.0
	for attr in [' width="', ' height="']:
		var tag := String(attr)
		var at := s.find(tag)
		if at < 0:
			continue
		var b := at + tag.length()
		var e := s.find('"', b)
		if e > b:
			out = maxf(out, s.substr(b, e - b).to_float())
	return out


## Texture d'une source SVG, rastérisée à px pixels (sa plus grande dimension). recolor : {"#1B1A1E": "#EFE6D2"}
## remplace des couleurs de la source ; {"*": "#RRGGBB"} les remplace toutes. key : nom court pour le cache.
## Rien n'est importé : nette à toute taille. null si la source est vide ou illisible.
static func svg_tex(src: String, px: float, recolor := {}, key := "") -> Texture2D:
	if src == "" or px < 1.0:
		return null
	var p := clampi(int(ceil(px / 2.0)) * 2, 4, 1024)  # tailles paires : moins d'entrées dans le cache
	var ck := "%s|%d|%s" % [key if key != "" else str(src.hash()), p, str(recolor)]
	if _tex.has(ck):
		return _tex[ck]
	if _tex.size() > 400:
		_tex.clear()
	var s := src
	for k in recolor.keys():
		var to := String(recolor[k])
		if String(k) == "*":
			if _hex_re == null:
				_hex_re = RegEx.new()
				_hex_re.compile("#[0-9A-Fa-f]{6}")
			s = _hex_re.sub(s, to, true)
		else:
			s = s.replace(String(k), to)
	var dim := _svg_dim(s)
	var img := Image.new()
	var err := img.load_svg_from_string(s, float(p) / maxf(dim, 1.0))
	if err != OK or img.is_empty():
		_tex[ck] = null
		return null
	var t := ImageTexture.create_from_image(img)
	_tex[ck] = t
	return t


## Texture d'un pictogramme v2 (clé de ui_icons.gd : « elements/feu », « effets/duree »…), px de côté.
static func icon(key: String, px: float, recolor := {}) -> Texture2D:
	return svg_tex(String(Icons.SVG.get(key, "")), px, recolor, key)


## Dessine une texture centrée en c, de taille sz (sa plus grande dimension), modulée par a.
static func _blit(ci: CanvasItem, t: Texture2D, c: Vector2, sz: float, a: float) -> void:
	var ts := Vector2(t.get_size())
	var ds := ts * (sz / maxf(maxf(ts.x, ts.y), 1.0))
	ci.draw_texture_rect(t, Rect2(c - ds / 2.0, ds), false, Color(1, 1, 1, a))


## Pictogramme v2 centré en c, de taille sz (px) ; col (alpha > 0) : tout le pictogramme dans cette couleur.
## Renvoie false si la clé est inconnue (l'appelant dessine alors son glyph()).
static func draw_icon(ci: CanvasItem, key: String, c: Vector2, sz: float, a := 1.0, col := NONE) -> bool:
	if not Icons.SVG.has(key):
		return false
	if sz < 1.0 or a <= 0.005:
		return true
	var rc := {}
	if col.a > 0.0:
		rc = {"*": UIColors.hex(col)}
	var t := icon(key, sz, rc)
	if t == null:
		return false
	_blit(ci, t, c, sz, a * (col.a if col.a > 0.0 else 1.0))
	return true


## Source SVG construite (tracé d) dessinée centrée en c, taille sz (gabarit box × box).
static func draw_path(ci: CanvasItem, d: String, box: int, c: Vector2, sz: float, stroke: Color, sw: float, fill := NONE, a := 1.0) -> void:
	if sz < 1.0 or a <= 0.005:
		return
	var src := SVG_HEAD % [box, box, box, box]
	src += '<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/></svg>' % [
		d, UIColors.hex(fill) if fill.a > 0.0 else "none", UIColors.hex(stroke), str(sw)]
	var t := svg_tex(src, sz, {}, "p%d|%s|%s|%s" % [d.hash(), UIColors.hex(stroke), UIColors.hex(fill) if fill.a > 0.0 else "-", str(sw)])
	if t != null:
		_blit(ci, t, c, sz, a)


## Pictogramme d'une pastille d'effet (Data.EFFECTS) en couleur col, taille sz : version v2 si elle existe.
static func fx_icon(ci: CanvasItem, name: String, c: Vector2, sz: float, col: Color, a := 1.0) -> void:
	if FX_ICON.has(name) and draw_icon(ci, String(FX_ICON[name]), c, sz, a, col):
		return
	glyph(ci, name, c, sz * 0.42, col, NONE, a)


## Déclencheur d'un pouvoir en pictogramme (couleur col, taille sz) : version v2 si elle existe.
static func trig_icon(ci: CanvasItem, id: String, c: Vector2, sz: float, col: Color, a := 1.0) -> void:
	var d: Dictionary = Data.POWERS.get(id, {})
	var trig := String(d.get("trig", "always"))
	if TRIG_ICON.has(trig) and draw_icon(ci, String(TRIG_ICON[trig]), c, sz, a, col):
		return
	glyph(ci, "t_" + trig, c, sz * 0.4, col, NONE, a)


## Pictogramme de l'élément d'une école (couleur jour, ou col si alpha > 0), taille sz.
static func element_icon(ci: CanvasItem, school: String, c: Vector2, sz: float, a := 1.0, col := NONE) -> void:
	var tint := col if col.a > 0.0 else UIColors.element(school)
	if not draw_icon(ci, UIColors.element_icon(school), c, sz, a, tint):
		glyph(ci, school, c, sz * 0.42, tint, NONE, a)


## Pictogramme d'une figure tracée, à son encre (ou col), taille sz.
static func figure_icon(ci: CanvasItem, fig: String, c: Vector2, sz: float, a := 1.0, col := NONE) -> void:
	var tint: Color = col
	if col.a <= 0.0:
		tint = UIColors.FIGURES_INK.get(fig, Toon.SUMI)
	# glyphes au trait (_fsym : spirale, aller-retour fléché, éclair, crochet fléché…) partout, préférés aux
	# pictos SVG FIG_ICON (décision de Victor : ce sont ceux de l'écran de fin)
	_fsym(ci, fig, c, sz * 0.4, Color(tint, tint.a * a), maxf(1.2, sz * 0.07))


## Médaillon de pouvoir v2, centré en c, s = pixels par unité du gabarit 60 : disque washi (rayon disc_r) cerné
## de `ring` (épaisseur ring_w), filet intérieur facultatif (inner, rayon 23, épaisseur 2), glyphe sumi (trait glyph_w).
static func power_medal(ci: CanvasItem, id: String, c: Vector2, s: float, ring: Color, disc_r: float, ring_w: float,
		inner := NONE, glyph_w := 3.0, a := 1.0) -> void:
	if s <= 0.0 or a <= 0.005:
		return
	ci.draw_circle(c, disc_r * s, Color(UIColors.WASHI_LIGHT, a))
	if inner.a > 0.0:
		ci.draw_arc(c, 23.0 * s, 0.0, TAU, 48, Color(inner, inner.a * a), maxf(1.0, 2.0 * s), true)
	var gp: Array = POWER_GLYPH.get(id, [])
	if gp.size() >= 2:
		var fill: Color = UIColors.element(power_school(id)) if bool(gp[1]) else NONE
		draw_path(ci, String(gp[0]), 60, c, 60.0 * s, UIColors.SUMI, glyph_w, fill, a)
	else:
		glyph(ci, icon_of(id), c, 15.0 * s, UIColors.SUMI, UIColors.WASHI_LIGHT, a)
	ci.draw_arc(c, disc_r * s, 0.0, TAU, 56, Color(ring, ring.a * a), maxf(1.0, ring_w * s), true)


## Arc en pointillés (tirets de `dash`, espaces de `gap`, en px le long de l'arc).
static func dashed_arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color, w: float, dash: float, gap: float) -> void:
	if r <= 0.5:
		return
	var da := dash / r
	var step := (dash + gap) / r
	var t := a0
	while t < a1 - 0.001:
		ci.draw_arc(c, r, t, minf(t + da, a1), 4, col, w, true)
		t += step


## Losange plein (palier d'harmonie), demi-diagonale e, cerné de `edge` (alpha 0 : sans cerne).
static func diamond(ci: CanvasItem, c: Vector2, e: float, col: Color, edge := NONE, ew := 1.0) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -e), c + Vector2(e, 0), c + Vector2(0, e), c + Vector2(-e, 0)])
	if col.a > 0.0:
		ci.draw_colored_polygon(pts, col)
	if edge.a > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, edge, ew, true)


## Anneau d'harmonie (gabarit 38 : 4 arcs de rayon 16, losange d'or en bas = palier 2), centré en c, rayon r.
## owned : arcs pleins (couleur col) = pouvoirs de l'élément déjà pris ; gain : arcs suivants en or pointillé
## (apportés par la carte) ; dim : arcs éteints ; lit : palier atteint, l'anneau s'illumine ; dia : losange.
static func harmony_ring(ci: CanvasItem, c: Vector2, r: float, owned: int, gain: int, col: Color, dim: Color, a := 1.0,
		lit := false, dia := true, w_on := 2.6, w_off := 2.0) -> void:
	var k := r / 16.0
	if lit:
		ci.draw_circle(c, r - 1.5 * k, Color(UIColors.GOLD, 0.3 * a))
	for i in 4:
		var a0 := deg_to_rad(-85.0 + 90.0 * float(i))
		var a1 := a0 + deg_to_rad(80.0)
		if i < owned:
			ci.draw_arc(c, r, a0, a1, 16, Color(col, col.a * a), maxf(1.0, w_on * k), true)
		elif i < owned + gain:
			dashed_arc(ci, c, r, a0, a1, Color(UIColors.GOLD, a), maxf(1.0, w_on * k), 3.0 * k, 2.0 * k)
		else:
			ci.draw_arc(c, r, a0, a1, 16, Color(dim, dim.a * a), maxf(1.0, w_off * k), true)
	if dia:
		diamond(ci, c + Vector2(0, 16.2 * k), 2.6 * k, Color(UIColors.GOLD, a), Color(UIColors.SUMI, a), maxf(1.0, 0.8 * k))


## Halo sans flou : n cercles concentriques à alpha décroissant autour de c (rayon r, écart spread).
static func halo(ci: CanvasItem, c: Vector2, r: float, col: Color, a: float, n := 3, spread := 3.0) -> void:
	for i in n:
		ci.draw_circle(c, r + spread * float(i + 1), Color(col, col.a * a * (0.24 - 0.07 * float(i))))


## Rectangle aux coins arrondis (rayon rad), en polygone (sens horaire) ; top_only : coins du bas carrés.
static func rrect_points(r: Rect2, rad: float, top_only := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr := clampf(rad, 0.0, minf(r.size.x, r.size.y) * 0.5)
	var cs: Array = [Vector2(r.end.x - rr, r.position.y + rr), Vector2(r.end.x - rr, r.end.y - rr),
		Vector2(r.position.x + rr, r.end.y - rr), Vector2(r.position.x + rr, r.position.y + rr)]
	for k in 4:
		if top_only and (k == 1 or k == 2):
			pts.append(Vector2(r.end.x, r.end.y) if k == 1 else Vector2(r.position.x, r.end.y))
			continue
		var cc: Vector2 = cs[k]
		for j in 6:
			var ang := -PI * 0.5 + PI * 0.5 * float(k) + PI * 0.5 * float(j) / 5.0
			pts.append(cc + Vector2(cos(ang), sin(ang)) * rr)
	return pts


## Valeur d'effet découpée pour l'affichage : [avant (« 3 → », vide sinon), chiffre, unité].
## « 50 %/s » -> ["", "50", "%/s"] ; « 3 → 4 s » -> ["3 →", "4", "s"] ; « +1 » -> ["", "+1", ""].
static func split_value(v: String) -> Array:
	var head := ""
	var body := v.strip_edges()
	var k := body.find(" → ")
	if k >= 0:
		head = body.substr(0, k + 2)
		body = body.substr(k + 3).strip_edges()
	var last := -1
	for i in body.length():
		var cc := body.unicode_at(i)
		if cc >= 48 and cc <= 57:
			last = i
	if last < 0:
		return [head, body, ""]
	return [head, body.substr(0, last + 1).strip_edges(), body.substr(last + 1).strip_edges()]
