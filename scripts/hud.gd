extends Control
## Interface de jeu dessinée à la main.
## En haut à gauche : bloc d'état (barre de vie, puce de niveau et barre d'expérience, or), badge de chaîne dessous.
## Au centre : sceau du monde + étape (x / 8). En haut à droite : pause. Sous le haut : barre du boss.
## Bord droit : jauge d'encre verticale et sceau de l'ultime ; à gauche, la colonne de progression de l'étape.
## Par-dessus : pad tactile, bandeaux d'annonce, compteur de combo, sceaux de figure, barres de vie des ennemis,
## voile de mort, rideau de transition et lavis du torii.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const InkStroke = preload("res://scripts/ink_stroke.gd")
const BAR_N := 24  # segments des barres au pinceau

signal pause_pressed

# état fourni par main à chaque image
var hp := 5
var max_hp := 5
var elan := 1.0
var elan_m := 14.0  # longueur max du trait (graduations tous les 2 m)
var elan_empty := false
var wave := 1  # étape en cours (1..rooms_total)
var rooms_total := 8
var gate_hint := false
var boss_name := ""
var boss_hint := ""  # point faible du boss affiché sous sa barre
var boss_ratio := 1.0
var boss_has_shield := false  # le boss a un bouclier (barre bleue au-dessus de sa vie)
var boss_shield := 0.0  # bouclier du boss (0..1)
var boss_vuln := 0.0  # secondes de vulnérabilité restantes (0 = bouclier levé)
var boss_vuln_len := 6.0
var wipe := 0.0  # rideau d'encre de la transition entre étapes (0..1)
# expédition (main) : avancée dans l'étape (0..1, < 0 = cachée), zones [début, fin, état 0/1/2], combats
var stage_k := -1.0
var _stage_vis_t := 0.0
var _stage_seen_done := -1
var _stage_seen_total := -1
var top_off := 0.0  # marge du haut : encoche / barre d'état du téléphone (zone de sécurité) + un peu d'air
var stage_marks: Array = []
var enc_done := 0
var enc_total := 0
var wash := 0.0  # lavis d'encre du rituel du torii (0..1), qui s'étend depuis wash_c
var wash_c := Vector2.ZERO
var wash_out := false  # vrai : l'encre se retire (fondu) après la reconstruction
var hurt_flash := 0.0
var dying := 0.0  # 0..1 : l'écran se délave pendant la mort
var world_kanji := "波"
var world_color := Toon.PRUSSIAN
var combo := 0
var chain := 0  # ruées réussies d'affilée sans prendre de coup
var chain_left := 1.0  # temps restant avant extinction (0..1)
var chain_mult := 1.0
var chain_break := 0.0  # éclat quand la chaîne se brise (1 -> 0)
var chain_lost := 0
var enemy_bars: Array = []  # [position écran, ratio de vie, (ratio de bouclier, élite)]
const SHIELD_BAR := Color("#6FB7FF")
const ELITE_MARK := Color("#FFB23E")
var in_play := false
var pause_enabled := true  # main : vrai seulement quand la pause est possible (état « play »)
var level := 1
var xp_ratio := 0.0
var gold := 0
var pad := Rect2()  # pad tactile du bas (coordonnées écran)
var pad_active := false
var pad_alpha := 1.0  # le pad s'efface après les premiers traits (option)
var pad_trail := PackedVector2Array()
var _toast := ""
var _toast_t := -1.0
var screen_flash := 0.0  # éclair blanc bref à la mise à mort
var show_fps := false  # `?fps` dans l'adresse web
var hero_screen := Vector2(-9999, -9999)  # position du héros à l'écran (main), pour les sceaux de figure
var _shapes: Array = []  # figures enchaînées : [forme, âge]
var shape_name := ""
var _shape_t := 9.0
var _real_dt := 0.0
var ult := 0.0  # jauge d'ultime (0..1), écrite par main

var _shown_hp := -1
var _lost: Array = []  # [index du cœur, temps]
var _combo_shown := 0
var _combo_t := 0.0
var _banner_big := ""
var _banner_small := ""
var _banner_col := Toon.SUMI
var _banner_t := -1.0
var _banner_len := 2.0
var _banner_icon := "ink"  # pictogramme du sceau du bandeau (UiKit.glyph)
var cine := 0.0  # bandes de cinéma (0..1) pendant l'entrée d'un boss
var _card: Array = []  # carton titre de boss : [kanji, nom, épithète, sous-titre]
var _card_mini := false
var _card_kanji := false  # la police contient-elle ces kanji ?
var _card_t := -1.0
var _card_len := 2.0
var _pause: Control
var _t := 0.0
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné
var _heart := PackedVector2Array()  # cœur unité (rayon 1), puis fermé pour le contour
var _heart_loop := PackedVector2Array()
var _bar_th := PackedFloat32Array()  # épaisseur relative du trait le long des barres
var _bar_pts := PackedVector2Array()
var _xp_shown := 0.0  # remplissage affiché de la barre d'expérience (rattrape xp_ratio)
var _xp_sheen := 0.0  # reflet qui court sur la barre quand elle monte (1 -> 0)
var _lv_shown := -1
var _lv_flash := 0.0  # éclat du passage de niveau (1 -> 0)
var _gain_from := 0  # premier segment regagné (soin)
var _gain_t := 0.0
var _chain_shown := 0
var _chain_pop := 0.0  # bond du badge de chaîne à chaque maillon (1 -> 0)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause = InkButton.new()
	_pause.style = "round"
	_pause.icon = "pause"
	add_child(_pause)
	_pause.pressed.connect(func(): pause_pressed.emit())
	# cœur : courbe classique, calculée une fois
	for i in 28:
		var t := TAU * float(i) / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		_heart.append(Vector2(x, -y) / 16.0)
	_heart_loop = _heart.duplicate()
	_heart_loop.append(_heart[0])
	for i in BAR_N + 1:
		var k := float(i) / BAR_N
		_bar_th.append(0.55 + 0.45 * sin(PI * minf(1.0, k * 1.1 + 0.05)))
	_bar_pts.resize((BAR_N + 1) * 2)


## Les polices réduites n'ont pas les voyelles longues (ō, ū) : on les écrit sans macron.
static func plain(s: String) -> String:
	return UiKit.plain(s)


func is_over_pause(p: Vector2) -> bool:
	return _pause != null and _pause.visible and Rect2(_pause.position, _pause.size).grow(8.0).has_point(p)


## Petite annonce discrète (vague suivante, combat, butin…) sous le haut de l'écran.
func toast(text: String) -> void:
	_toast = plain(text)
	_toast_t = 0.0


## Carton titre d'un boss qui entre : kanji estampillé, nom au pinceau, épithète.
func boss_card(kanji: String, title: String, epithet: String, sub: String, small: bool, length: float) -> void:
	_card = [kanji, plain(title), plain(epithet), plain(sub)]
	_card_mini = small
	_card_t = 0.0
	_card_len = length
	# police réduite aux caractères du jeu : sans ses kanji, on ne les montre pas
	_card_kanji = kanji != ""
	for i in kanji.length():
		if not UiKit.TITLE_FONT.has_char(kanji.unicode_at(i)):
			_card_kanji = false


## Le carton s'efface vite (entrée passée d'un toucher, ou finie).
func end_boss_card(fade := 0.25) -> void:
	if _card_t >= 0.0:
		_card_len = minf(_card_len, _card_t + fade)


## Bandeau d'annonce : début de partie, nouvelle étape, boss…
func banner(big: String, small := "", col := Toon.SUMI, length := 2.0) -> void:
	_banner_big = plain(big)
	_banner_small = plain(small)
	_banner_col = col
	_banner_t = 0.0
	_banner_len = length
	# sceau du bandeau d'après l'annonce ; zone ou étape nettoyée : brève et festive
	var up := _banner_big.to_upper()
	_banner_icon = "ink"
	if up.contains("NETTOY"):
		_banner_icon = "torii"
		_banner_len = minf(length, 1.4)
	elif up.contains("VICTOIRE"):
		_banner_icon = "star"
	elif up.contains("SANCTUAIRE"):
		_banner_icon = "oni" if up.contains("UN ") else "torii"
	elif up.begins_with("BIEN"):
		_banner_icon = "check"
	elif up.begins_with("RAT"):
		_banner_icon = "cross"
	elif up.contains("TUTORIEL"):
		_banner_icon = "ink"
	elif col == Toon.VERMILION:
		_banner_icon = "oni"
	else:
		_banner_icon = "path"


func _process(_delta: float) -> void:
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_update_safe_top()
	_t += real
	if hurt_flash > 0.0:
		hurt_flash = maxf(0.0, hurt_flash - real * 2.5)
	_tick_status(real)  # segments de vie, expérience, niveau, chaîne
	# combo : reste affiché un moment après la ruée
	if combo >= 2:
		_combo_shown = combo
		_combo_t = 1.2
	elif _combo_t > 0.0:
		_combo_t -= real
	chain_break = maxf(0.0, chain_break - real * 1.6)
	screen_flash = maxf(0.0, screen_flash - real * 4.0)
	if _toast_t >= 0.0:
		_toast_t += real
		if _toast_t > 1.4:
			_toast_t = -1.0
	_shape_t += real
	_stage_vis_t = maxf(0.0, _stage_vis_t - real)
	_real_dt = real
	if _banner_t >= 0.0:
		_banner_t += real
		if _banner_t > _banner_len:
			_banner_t = -1.0
	if _card_t >= 0.0:
		_card_t += real
		if _card_t > _card_len:
			_card_t = -1.0
	var u := size.x / 400.0
	_pause.visible = in_play and pause_enabled and dying <= 0.0
	_pause.size = Vector2(40, 40) * u
	_pause.position = Vector2(size.x - 54 * u, 16 * u + top_off)
	queue_redraw()


func _draw() -> void:
	var sz := size
	if sz.x < 10.0:
		return
	var u := sz.x / 400.0

	# barres de vie des ennemis touchés
	for b in enemy_bars:
		var p: Vector2 = b[0]
		var r: float = b[1]
		# [position, vie] ou [position, vie, bouclier, élite]
		var sr := 0.0
		var el := false
		if b.size() >= 4:
			sr = float(b[2])
			el = bool(b[3])
		var bw := (40.0 if el else 30.0) * u
		var rect := Rect2(p - Vector2(bw / 2.0, 0), Vector2(bw, 5 * u))
		draw_rect(rect.grow(1.5 * u), Color(Toon.SUMI, 0.75))
		draw_rect(Rect2(rect.position, Vector2(bw * clampf(r, 0.0, 1.0), rect.size.y)), Toon.VERMILION)
		if sr > 0.0:
			# bouclier : fine barre bleue posée sur la barre de vie
			var srect := Rect2(rect.position - Vector2(0, 4.5 * u), Vector2(bw, 3 * u))
			draw_rect(srect.grow(1.2 * u), Color(Toon.SUMI, 0.75))
			draw_rect(Rect2(srect.position, Vector2(bw * clampf(sr, 0.0, 1.0), srect.size.y)), SHIELD_BAR)
		if el:
			# élite : losange d'or au bout de la barre
			var c := rect.position + Vector2(-5.0 * u, rect.size.y * 0.5)
			var d := 4.0 * u
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), ELITE_MARK)

	if in_play:
		_draw_pad(u)
		# voile de papier en dégradé derrière le bandeau du haut : lisible sur n'importe quel décor
		var top_h := 96.0 * u + top_off
		var paper := Color(Toon.PAPER, 0.88)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), Vector2(sz.x, top_h * 0.55), Vector2(0, top_h * 0.55)]),
			PackedColorArray([paper, paper, paper, paper]))
		draw_polygon(PackedVector2Array([Vector2(0, top_h * 0.55), Vector2(sz.x, top_h * 0.55), Vector2(sz.x, top_h), Vector2(0, top_h)]),
			PackedColorArray([paper, paper, Color(paper, 0.0), Color(paper, 0.0)]))
		draw_set_transform(Vector2(0, top_off))
		_draw_status(u)
		# pouvoirs : plus affichés en jeu (lisibilité) — rangée sur la carte de pause et bilan de fin
		_draw_shape_pop(sz, u)
		_draw_chain(u)
		_draw_room(sz, u)
		if boss_name != "":
			_draw_boss(sz, u)
		draw_set_transform(Vector2.ZERO)
		_draw_stage_bar(sz, u)
		_draw_gauge(sz, u)
		if gate_hint:
			_draw_gate_hint(sz, u)
		if _combo_t > 0.0 and _combo_shown >= 2:
			_draw_combo(sz, u)

	if screen_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.97, 0.9, screen_flash * 0.5))

	# coup reçu : liseré vermillon et coins d'encre
	if hurt_flash > 0.0:
		var hc := Color(Toon.VERMILION, 0.4 * hurt_flash)
		var hb := 16.0 * u
		draw_rect(Rect2(0, 0, sz.x, hb), hc)
		draw_rect(Rect2(0, sz.y - hb, sz.x, hb), hc)
		draw_rect(Rect2(0, 0, hb, sz.y), hc)
		draw_rect(Rect2(sz.x - hb, 0, hb, sz.y), hc)

	if _toast_t >= 0.0 and in_play:
		var ta := clampf(minf(_toast_t / 0.15, (1.4 - _toast_t) / 0.3), 0.0, 1.0)
		var tfs := int(14 * u)
		var tw := UiKit.TITLE_FONT.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		var tp := Vector2(sz.x / 2.0 - tw / 2.0, 100 * u - 6 * u * (1.0 - ta))
		draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.75 * ta), 999), Rect2(tp + Vector2(-14 * u, -tfs - 4 * u), Vector2(tw + 28 * u, tfs + 14 * u)))
		draw_string(UiKit.TITLE_FONT, tp, _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(Toon.WASHI, ta))

	if cine > 0.001:
		_draw_cine(sz, u)
	if _card_t >= 0.0 and _card.size() == 4:
		_draw_card(sz, u)

	if _banner_t >= 0.0:
		_draw_banner(sz, u)

	# mort : l'image se délave dans le papier, une coulure d'encre descend
	if dying > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(Toon.WASHI, 0.55 * dying))
		var drip := PackedVector2Array()
		var steps := 20
		for i in steps + 1:
			var x := sz.x * float(i) / steps
			var y := sz.y * 0.22 * dying * (0.6 + 0.4 * sin(float(i) * 2.1) + 0.3 * sin(float(i) * 0.7))
			drip.append(Vector2(x, y))
		drip.append(Vector2(sz.x, 0))
		drip.append(Vector2(0, 0))
		draw_colored_polygon(drip, Color(Toon.SUMI, 0.85 * dying))

	if show_fps:
		draw_string(UiKit.UI_FONT, Vector2(10 * u, sz.y - 12 * u), "%d FPS" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Toon.VERMILION)

	# rideau d'encre : un grand coup de pinceau qui balaie l'écran
	if wipe > 0.001:
		# bande par bande (quadrilatères simples) : jamais de polygone qui se recoupe au début du balayage
		var edge := sz.x * 1.4 * wipe
		var n := 24
		var prev := Vector2.ZERO
		for i in n + 1:
			var y := -10.0 + (sz.y + 20.0) * float(i) / n
			var jag := sin(float(i) * 1.7) * 14.0 * u + sin(float(i) * 0.6) * 22.0 * u
			var cur := Vector2(maxf(edge - y * 0.25 + jag, -10.0), y)
			if i > 0 and (cur.x > -9.0 or prev.x > -9.0):
				var q := PackedVector2Array([Vector2(-10, prev.y)])
				if prev.x > -9.99:
					q.append(prev)
				if cur.x > -9.99:
					q.append(cur)
				q.append(Vector2(-10, cur.y))
				if q.size() >= 3:
					draw_colored_polygon(q, Toon.SUMI)
			prev = cur
	if wash > 0.001:
		_draw_wash(sz, u)


# ------------------------------------------------------------------ éléments

## Cœur : courbe précalculée, placée en c à l'échelle s (fermée pour le contour).
## On transforme les points plutôt que le canevas : l'épaisseur des contours reste nette.
func _heart_pts(c: Vector2, s: float, closed := false) -> PackedVector2Array:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	if closed:
		return xf * _heart_loop
	return xf * _heart


const HUD_JADE := Color("#3FD1B2")
const HUD_GOLD := Color("#E2A93B")
const HUD_HOT := Color("#FF6B5A")


## Animations du bloc d'état : segments perdus ou regagnés, expérience qui se remplit, niveau, chaîne.
func _tick_status(real: float) -> void:
	if _shown_hp < 0:
		_shown_hp = hp
	if hp < _shown_hp:
		for i in range(hp, _shown_hp):
			_lost.append([i, 0.0])
	elif hp > _shown_hp:
		_gain_from = _shown_hp
		_gain_t = 0.6
	_shown_hp = hp
	if not _lost.is_empty():
		for l in _lost:
			l[1] = float(l[1]) + real
		_lost = _lost.filter(func(l): return float(l[1]) < 0.7)
	_gain_t = maxf(0.0, _gain_t - real)
	# expérience : la barre rattrape la valeur (reflet tant qu'elle monte), repart de zéro au niveau suivant
	var xr := clampf(xp_ratio, 0.0, 1.0)
	if _lv_shown < 0:
		_lv_shown = level
		_xp_shown = xr
	if level > _lv_shown:
		_lv_flash = 1.0
		_xp_shown = 0.0
	_lv_shown = level
	if xr > _xp_shown + 0.002:
		_xp_sheen = 1.0
		_xp_shown = lerpf(_xp_shown, xr, 1.0 - exp(-real * 7.0))
	else:
		_xp_shown = xr
	_xp_sheen = maxf(0.0, _xp_sheen - real * 1.4)
	_lv_flash = maxf(0.0, _lv_flash - real * 1.2)
	if chain > _chain_shown and chain >= 2:
		_chain_pop = 1.0
	_chain_shown = chain
	_chain_pop = maxf(0.0, _chain_pop - real * 4.0)


## Gélule : contour d'un rectangle aux bouts ronds (pour les remplissages en dégradé).
func _pill_pts(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := minf(r.size.y, r.size.x - 1.0) / 2.0
	var cl := Vector2(r.position.x + rad, r.position.y + r.size.y / 2.0)
	var cr := Vector2(r.end.x - rad, cl.y)
	for k in 9:
		pts.append(cr + Vector2.from_angle(PI / 2.0 - PI * float(k) / 8.0) * rad)
	for k in 9:
		pts.append(cl + Vector2.from_angle(-PI / 2.0 - PI * float(k) / 8.0) * rad)
	return pts


## Boîte d'un segment : coins ronds seulement aux deux bouts de la barre.
func _seg_box(c: Color, first: bool, last: bool, rad: int, small: int) -> StyleBoxFlat:
	UiKit.box(_sb, c, small)
	if first:
		_sb.corner_radius_top_left = rad
		_sb.corner_radius_bottom_left = rad
	if last:
		_sb.corner_radius_top_right = rad
		_sb.corner_radius_bottom_right = rad
	return _sb


## Texte cerné d'encre : lisible sur la neige comme sur la nuit.
func _ink_text(font: Font, pos: Vector2, txt: String, fs: int, c: Color, u: float) -> void:
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(3.0 * u)), Color(Toon.SUMI, 0.9 * c.a))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


## Bloc d'état en haut à gauche, sans plaque : barre de vie segmentée (cœur en tête),
## puce de niveau et barre d'expérience fine dessous, or à droite ; la chaîne s'affiche dessous (_draw_chain).
## S'arrête avant le sceau du monde (centre).
func _draw_status(u: float) -> void:
	_draw_hearts(u)
	_draw_xp(u)
	_draw_gold(u)


## Vie : une gélule sombre, un segment vermillon brillant par cœur ; un segment perdu flashe blanc,
## se fend et s'écrase ; vie basse : la barre et le cœur battent.
func _draw_hearts(u: float) -> void:
	var n := maxi(max_hp, 1)
	var shake := Vector2(sin(_t * 70.0) * 2.2 * u * hurt_flash, 0.0)
	var low := hp > 0 and (hp == 1 or float(hp) <= float(n) * 0.25)
	var beat: float = (0.5 + 0.5 * sin(_t * 7.0)) if low else 0.0
	var track := Rect2(Vector2(22, 15) * u + shake, Vector2(114, 17) * u)
	# ombre douce, gélule sombre cernée de papier
	draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.22), 999), Rect2(track.position + Vector2(0, 2.0 * u), track.size))
	var rim: Color = Color(HUD_HOT, 0.55 + 0.4 * beat) if low else Color(Toon.WASHI, 0.35)
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.9), 999, rim, maxi(1, int((1.0 + beat) * u))), track)
	var inner := Rect2(track.position + Vector2(13.0 * u, 3.0 * u), Vector2(track.size.x - 16.0 * u, track.size.y - 6.0 * u))
	var g := (2.0 if n <= 8 else 1.2) * u
	var sw := maxf(1.0, (inner.size.x - g * float(n - 1)) / float(n))
	var rad := int(inner.size.y / 2.0)
	var small := int(2.0 * u)
	for i in n:
		var seg := Rect2(Vector2(inner.position.x + float(i) * (sw + g), inner.position.y), Vector2(sw, inner.size.y))
		var first := i == 0
		var last := i == n - 1
		var lost_t := -1.0
		for l in _lost:
			if int(l[0]) == i:
				lost_t = float(l[1])
		if i < hp:
			# segment plein : vermillon, moitié haute plus claire, liseré de lumière
			var base := Toon.VERMILION.lerp(HUD_HOT, 0.5 * beat)
			draw_style_box(_seg_box(base.darkened(0.18), first, last, rad, small), seg)
			draw_style_box(_seg_box(base.lightened(0.12), first, last, rad, small), Rect2(seg.position, Vector2(sw, seg.size.y * 0.55)))
			draw_line(seg.position + Vector2(2.0 * u, 1.6 * u), Vector2(seg.end.x - 2.0 * u, seg.position.y + 1.6 * u), Color(1, 1, 1, 0.45), 1.2 * u)
			if _gain_t > 0.0 and i >= _gain_from:
				# soin : le segment regagné s'allume
				draw_style_box(_seg_box(Color(1, 1, 1, 0.75 * _gain_t / 0.6), first, last, rad, small), seg.grow(1.0 * u * _gain_t / 0.6))
		elif lost_t >= 0.0:
			var k := lost_t / 0.7
			if lost_t < 0.12:
				# éclair blanc
				draw_style_box(_seg_box(Color(1, 0.97, 0.92), first, last, rad, small), seg.grow(1.5 * u))
			else:
				# il s'écrase vers son milieu et pâlit, fendu d'un trait d'encre
				var kk := (lost_t - 0.12) / 0.58
				var sh := seg.size.y * (1.0 - UiKit.ease_out(kk))
				var col := Toon.VERMILION.lerp(Toon.WASHI, kk)
				if sh > 1.0:
					draw_style_box(_seg_box(Color(col, 1.0 - kk), first, last, rad, small), Rect2(Vector2(seg.position.x, seg.get_center().y - sh / 2.0), Vector2(sw, sh)))
				var cc := seg.get_center()
				draw_polyline(PackedVector2Array([cc + Vector2(-1.5, -6) * u, cc + Vector2(1.5, -1) * u, cc + Vector2(-1, 2) * u, cc + Vector2(1.5, 6) * u]), Color(Toon.SUMI, 1.0 - kk), 1.4 * u, true)
			# éclats qui sautent puis retombent
			for j in 3:
				var dir := Vector2(-1.0 + float(j), -1.0 - 0.4 * float(j % 2))
				var pc := seg.get_center() + dir * 16.0 * u * k + Vector2(0, 34.0 * u * k * k)
				var ps := 2.6 * u * (1.0 - k)
				if ps > 0.3:
					draw_colored_polygon(PackedVector2Array([pc + Vector2(0, -ps), pc + Vector2(ps, ps * 0.6), pc + Vector2(-ps, ps * 0.8)]), Color(Toon.VERMILION, 1.0 - k))
		else:
			# segment vide : creux sombre
			draw_style_box(_seg_box(Color(Toon.WASHI, 0.08), first, last, rad, small), seg)
	# cœur en tête de barre, avec « 4/5 » dedans
	var c := Vector2(20.0 * u, 21.5 * u) + shake
	var s := 12.5 * u * (1.0 + 0.12 * beat + 0.18 * hurt_flash)
	draw_colored_polygon(_heart_pts(c + Vector2(0, 2.0 * u), s), Color(0, 0, 0, 0.25))
	draw_colored_polygon(_heart_pts(c + Vector2(0, -0.6 * u), s + 2.4 * u), Toon.SUMI)
	var hc: Color = Toon.VERMILION.lerp(HUD_HOT, beat) if hp > 0 else Color("#5A5560")
	draw_colored_polygon(_heart_pts(c, s), hc)
	draw_colored_polygon(_heart_pts(c + Vector2(-0.12, -0.14) * s, s * 0.62), Color(hc.lightened(0.22), 0.6))
	draw_circle(c + Vector2(-0.45, -0.38) * s, 0.16 * s, Color(1, 1, 1, 0.75))
	var txt := "%d/%d" % [maxi(hp, 0), max_hp]
	var fs := int(9.5 * u)
	while fs > 6 and UiKit.UI_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > s * 1.7:
		fs -= 1
	var tw := UiKit.UI_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_ink_text(UiKit.UI_FONT, Vector2(c.x - tw / 2.0, c.y + 0.2 * s + fs * 0.36), txt, fs, Toon.WASHI, u * 0.8)


## Niveau : puce hexagonale cerclée d'or au bout d'une barre d'expérience fine (dégradé jade → or,
## reflet qui court quand elle monte) ; passage de niveau : la puce gonfle dans un éclat d'or.
func _draw_xp(u: float) -> void:
	var fl := _lv_flash
	var bar := Rect2(Vector2(28.0 * u, 47.5 * u), Vector2(68.0 * u, 7.0 * u))
	draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.2), 999), Rect2(bar.position + Vector2(0, 1.5 * u), bar.size).grow(1.5 * u))
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.9), 999, Color(Toon.WASHI, 0.3), maxi(1, int(u))), bar.grow(1.5 * u))
	var fw := bar.size.x * _xp_shown
	if fw > 0.5 * u:
		var fill := Rect2(bar.position, Vector2(maxf(fw, bar.size.y + 1.0), bar.size.y))
		var pts := _pill_pts(fill)
		var cols := PackedColorArray()
		var mid := fill.get_center().y
		for p in pts:
			var gc := HUD_JADE.lerp(HUD_GOLD, clampf((p.x - bar.position.x) / bar.size.x, 0.0, 1.0))
			cols.append(gc.lightened(0.25) if p.y < mid else gc.darkened(0.1))
		draw_polygon(pts, cols)
		draw_line(Vector2(fill.position.x + 3.0 * u, fill.position.y + 1.4 * u), Vector2(fill.end.x - 3.0 * u, fill.position.y + 1.4 * u), Color(1, 1, 1, 0.4), 1.0 * u)
		if _xp_sheen > 0.01:
			# reflet en biais qui balaie la partie remplie
			var ph := fmod(_t * 1.6, 1.0)
			var sx := lerpf(fill.position.x - 8.0 * u, fill.end.x + 8.0 * u, ph)
			var band := PackedVector2Array([Vector2(sx, fill.position.y - 1.0), Vector2(sx + 6.0 * u, fill.position.y - 1.0), Vector2(sx + 2.0 * u, fill.end.y + 1.0), Vector2(sx - 4.0 * u, fill.end.y + 1.0)])
			for piece in Geometry2D.intersect_polygons(band, pts):
				var pp: PackedVector2Array = piece
				# morceaux trop fins (début de barre) : la triangulation échoue, on les saute
				if pp.size() >= 3 and UiKit.poly_area(pp) > 2.0:
					draw_colored_polygon(pp, Color(1, 1, 1, 0.6 * _xp_sheen))
	if fl > 0.0:
		draw_style_box(UiKit.box(_sb, Color(1, 0.95, 0.75, 0.6 * fl), 999), bar.grow(1.5 * u))
	# puce de niveau
	var lc := Vector2(17.0 * u, 51.0 * u)
	var R := 11.0 * u * (1.0 + 0.3 * UiKit.ease_out(fl) * fl)
	if fl > 0.0:
		var e := 1.0 - fl
		draw_arc(lc, R + 4.0 * u + 18.0 * u * e, 0.0, TAU, 32, Color(HUD_GOLD, fl), 3.0 * u * fl + 0.5, true)
		for j in 6:
			var d := Vector2.from_angle(TAU * float(j) / 6.0 + 0.3)
			draw_circle(lc + d * (R + 6.0 * u + 16.0 * u * e), 1.8 * u * fl, Color(1, 0.92, 0.6, fl))
	draw_colored_polygon(_hex(lc + Vector2(0, 1.8 * u), R + 2.6 * u), Color(0, 0, 0, 0.25))
	draw_colored_polygon(_hex(lc, R + 3.0 * u), Toon.SUMI)
	draw_colored_polygon(_hex(lc, R + 1.6 * u), HUD_GOLD.lerp(Color(1, 0.95, 0.75), fl))
	var hx := _hex(lc, R)
	var hcol := PackedColorArray()
	for p in hx:
		hcol.append(Color("#3A3542") if p.y < lc.y else Toon.SUMI)
	draw_polygon(hx, hcol)
	UiKit.text(self, UiKit.UI_FONT, "NIV", lc + Vector2(0, -3.2 * u), int(6.0 * u), Color(HUD_GOLD.lightened(0.2), 0.95))
	var lfs := int((11.0 if level < 100 else 8.5) * u)
	UiKit.text(self, UiKit.TITLE_FONT, str(level), lc + Vector2(0, 7.6 * u), lfs, Toon.WASHI)


## Hexagone pointe en haut, de rayon r.
func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + PI / 3.0 * float(k)) * r)
	return pts


## Or : pièce percée et montant, à droite de la barre d'expérience.
func _draw_gold(u: float) -> void:
	var gc := Vector2(107.0 * u, 51.0 * u)
	var r := 6.5 * u
	draw_circle(gc + Vector2(0, 1.5 * u), r + 1.2 * u, Color(0, 0, 0, 0.22))
	draw_circle(gc, r + 1.3 * u, Toon.SUMI)
	draw_circle(gc, r, Toon.GOLD)
	draw_circle(gc + Vector2(0, -r * 0.18), r * 0.78, Toon.GOLD.lightened(0.2))
	draw_arc(gc, r * 0.72, 0.0, TAU, 20, Color("#8C6A2A"), 1.0 * u, true)
	draw_rect(Rect2(gc - Vector2(1.8, 1.8) * u, Vector2(3.6, 3.6) * u), Color("#5A4318"))
	var gtxt := str(gold)
	var gx := gc.x + r + 4.0 * u
	var gfs := int(12 * u)
	while gfs > 7 and UiKit.UI_FONT.get_string_size(gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, gfs).x > 140.0 * u - gx:
		gfs -= 1
	_ink_text(UiKit.UI_FONT, Vector2(gx, gc.y + gfs * 0.36), gtxt, gfs, Toon.WASHI, u)


## Figures réussies : les sceaux s'alignent quand on les enchaîne (6 au plus), le dernier porte son nom.
## La rangée s'efface 3 s après la dernière figure.
func shape_pop(shape: String, label: String) -> void:
	if _shape_t > 3.0:
		_shapes.clear()
	_shapes.append([shape, 0.0])
	if _shapes.size() > 6:
		_shapes.pop_front()
	shape_name = plain(label)
	_shape_t = 0.0


func _draw_shape_pop(sz: Vector2, u: float) -> void:
	if _shapes.is_empty() or _shape_t > 3.4:
		return
	var a := clampf((3.4 - _shape_t) / 0.4, 0.0, 1.0)
	var n := _shapes.size()
	# petits sceaux au-dessus du héros (ne gâchent pas la vue)
	var r := 10.0 * u
	var gap := 2.0 * r + 5.0 * u
	var anchor := hero_screen if hero_screen.x > -9000.0 else Vector2(sz.x / 2.0, 150.0 * u)
	var y := clampf(anchor.y - 34.0 * u, 60.0 * u + top_off, sz.y - 120.0 * u)  # bien au-dessus de la tête
	var x0 := clampf(anchor.x - (n - 1) * gap / 2.0, 14.0 * u, sz.x - 14.0 * u - (n - 1) * gap)
	for i in n:
		var sh: Array = _shapes[i]
		sh[1] = float(sh[1]) + _real_dt
		var k_in := clampf(float(sh[1]) / 0.15, 0.0, 1.0)
		var newest := i == n - 1
		var rr := r * (1.25 if newest else 1.0) * (0.6 + 0.4 * (1.0 - pow(1.0 - k_in, 3.0)))
		var c := Vector2(x0 + i * gap, y)
		if i > 0:
			# trait d'encre qui relie les figures enchaînées
			draw_line(Vector2(x0 + (i - 1) * gap + r, y), c - Vector2(rr, 0), Color(Toon.SUMI, 0.6 * a), 2.0 * u)
		_draw_symbol(String(sh[0]), c, rr, a)
	if shape_name != "":
		var fs := int(8 * u)
		var tw := UiKit.UI_FONT.get_string_size(shape_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cx := x0 + (n - 1) * gap
		var tx := clampf(cx - tw / 2.0, 8.0 * u, sz.x - tw - 8.0 * u)
		var tp := Vector2(tx, y - r * 1.25 - 5.0 * u)
		var la := a * clampf((1.6 - _shape_t) / 0.3, 0.0, 1.0)
		draw_string_outline(UiKit.UI_FONT, tp, shape_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(3 * u), Color(Toon.SUMI, 0.75 * la))
		draw_string(UiKit.UI_FONT, tp, shape_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.WASHI, la))


## Symbole d'une figure au pinceau, dans un sceau rond de rayon r.
func _draw_symbol(shape: String, c: Vector2, r: float, a: float) -> void:
	draw_circle(c, r + 2.5 * r / 30.0, Color(Toon.SUMI, 0.85 * a))
	draw_circle(c, r, Color(Toon.PAPER, 0.95 * a))
	var ink := Color(Toon.SUMI, a)
	var w := 4.0 * r / 30.0
	var s := r * 0.62
	match shape:
		"loop":
			# spirale
			var pts := PackedVector2Array()
			for i in 40:
				var t := float(i) / 39.0
				pts.append(c + Vector2.from_angle(t * TAU * 1.75) * s * (0.15 + 0.85 * t))
			draw_polyline(pts, ink, w, true)
		"zigzag":
			# éclair
			draw_polyline(PackedVector2Array([c + Vector2(-0.6, -0.9) * s, c + Vector2(0.25, -0.15) * s, c + Vector2(-0.25, 0.1) * s, c + Vector2(0.6, 0.9) * s]), Color(Toon.GOLD.darkened(0.2), a), w * 1.2, true)
		"straight":
			# coupe nette en diagonale
			draw_line(c + Vector2(-0.95, 0.55) * s, c + Vector2(0.95, -0.55) * s, ink, w * 1.3, true)
			draw_line(c + Vector2(-0.6, 0.55) * s, c + Vector2(0.95, -0.35) * s, Color(Toon.VERMILION, a * 0.8), w * 0.5, true)
		"return":
			# demi-tour
			draw_arc(c + Vector2(0, -0.1) * s, s * 0.55, PI, TAU, 16, ink, w, true)
			draw_line(c + Vector2(-0.55, -0.1) * s, c + Vector2(-0.55, 0.8) * s, ink, w, true)
			draw_line(c + Vector2(0.55, -0.1) * s, c + Vector2(0.55, 0.6) * s, ink, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.3, 0.55) * s, c + Vector2(0.8, 0.55) * s, c + Vector2(0.55, 0.95) * s]), ink)
		"enso":
			# cercle ouvert, plus épais au départ
			draw_arc(c, s * 0.85, -PI * 0.35, PI * 1.5, 32, ink, w * 1.5, true)
			draw_circle(c + Vector2.from_angle(-PI * 0.35) * s * 0.85, w * 0.9, ink)
		"hook":
			# hameçon
			draw_line(c + Vector2(0.35, -0.9) * s, c + Vector2(0.35, 0.3) * s, ink, w, true)
			draw_arc(c + Vector2(0.0, 0.3) * s, s * 0.35, 0.0, PI, 14, ink, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.35, 0.3) * s, c + Vector2(-0.6, 0.0) * s, c + Vector2(-0.2, 0.05) * s]), ink)


## Chaîne : badge vif sous le bloc d'état, seulement à partir de 2 — flamme à la couleur du palier,
## « ×n » en grand, bonus en petit, temps restant en filet ; il bondit à chaque ruée, éclate en se brisant.
func _draw_chain(u: float) -> void:
	var p := Vector2(8 * u, (78.0 if boss_name == "" else 112.0) * u)  # sous la barre du boss quand il y en a une
	if chain >= 2:
		var tier_col := Color("#F2B544")
		if chain >= 20:
			tier_col = Color("#B98CFF")
		elif chain >= 10:
			tier_col = HUD_HOT
		elif chain >= 5:
			tier_col = Color("#FF8A3D")
		var ntxt := "×%d" % chain
		var nfs := int(19 * u)
		var nw := UiKit.TITLE_FONT.get_string_size(ntxt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var bonus := "+%d %%" % int(round((chain_mult - 1.0) * 100.0))
		var bfs := int(10 * u)
		var bw := UiKit.UI_FONT.get_string_size(bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		var lfs := int(6.5 * u)
		bw = maxf(bw, UiKit.UI_FONT.get_string_size("CHAÎNE", HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x)
		var body := Rect2(p + Vector2(6.0 * u, 2.0 * u), Vector2(22.0 * u + nw + 5.0 * u + bw + 10.0 * u, 24.0 * u))
		# bond à chaque maillon (mise à l'échelle autour de la flamme)
		var pop := 1.0 + 0.22 * _chain_pop * _chain_pop
		var anchor := Vector2(p.x + 12.0 * u, body.get_center().y)
		draw_set_transform(Vector2(0, top_off) + anchor * (1.0 - pop), 0.0, Vector2(pop, pop))  # garde la marge de l'encoche
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.22), 999), Rect2(body.position + Vector2(0, 2.0 * u), body.size))
		draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.92), 999, Color(tier_col, 0.85), maxi(1, int(1.5 * u))), body)
		draw_style_box(UiKit.box(_sb, Color(tier_col, 0.16), 999), Rect2(body.position + Vector2(2.0 * u, 2.0 * u), Vector2(body.size.x * 0.5, body.size.y - 4.0 * u)))
		# flamme qui vacille, braises au-delà de 10
		var fc := Vector2(p.x + 12.0 * u, body.get_center().y + 3.5 * u)
		var fr := 7.0 * u
		draw_circle(fc + Vector2(0, -2.0 * u), fr * 1.9, Color(tier_col, 0.18))
		draw_colored_polygon(_flame(fc + Vector2(0, 1.2 * u), fr + 2.0 * u, 0.0), Toon.SUMI)
		draw_colored_polygon(_flame(fc, fr, 1.0), tier_col)
		draw_colored_polygon(_flame(fc + Vector2(0, 1.5 * u), fr * 0.55, 2.0), Color(1, 0.96, 0.8, 0.9))
		if chain >= 10:
			for j in 3:
				var ph := fmod(_t * 1.3 + float(j) * 0.33, 1.0)
				var ep := fc + Vector2(sin(_t * 5.0 + float(j) * 2.0) * 4.0 * u, -fr - 14.0 * u * ph)
				draw_circle(ep, 1.6 * u * (1.0 - ph), Color(tier_col.lightened(0.3), 1.0 - ph))
		# « ×n » au palier, bonus et libellé à droite
		var tx := body.position.x + 22.0 * u
		var base := body.get_center().y + nfs * 0.36
		_ink_text(UiKit.TITLE_FONT, Vector2(tx, base), ntxt, nfs, tier_col.lightened(0.15), u)
		var rx := tx + nw + 5.0 * u
		draw_string(UiKit.UI_FONT, Vector2(rx, body.position.y + 10.0 * u), "CHAÎNE", HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(Toon.WASHI, 0.55))
		draw_string(UiKit.UI_FONT, Vector2(rx, body.position.y + 20.0 * u), bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, HUD_GOLD.lightened(0.25))
		# temps restant : filet sous le badge (il clignote à la fin)
		var left := clampf(chain_left, 0.0, 1.0)
		var blink: float = (0.55 + 0.45 * sin(_t * 18.0)) if left < 0.3 else 1.0
		var tr := Rect2(Vector2(body.position.x + 14.0 * u, body.end.y + 3.0 * u), Vector2(body.size.x - 22.0 * u, 3.0 * u))
		draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.7), 999), tr.grow(1.0 * u))
		if left > 0.02:
			draw_style_box(UiKit.box(_sb, Color(tier_col, blink), 999), Rect2(tr.position, Vector2(maxf(tr.size.x * left, tr.size.y), tr.size.y)))
		draw_set_transform(Vector2(0, top_off))
	if chain_break > 0.0:
		var k := 1.0 - chain_break
		var txt := "CHAÎNE BRISÉE  ×%d" % chain_lost
		var tfs := int(11 * u)
		var tw2 := UiKit.UI_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		var tp := p + Vector2(8, 18 + 14 * k) * u
		draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.75 * chain_break), 999), Rect2(tp + Vector2(-6 * u, -tfs), Vector2(tw2 + 12 * u, tfs + 6 * u)))
		draw_string(UiKit.UI_FONT, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(HUD_HOT, chain_break))
		for j in 6:
			var a := TAU * j / 6.0
			draw_rect(Rect2(p + Vector2(40, 14) * u + Vector2(cos(a), sin(a)) * 40.0 * u * k, Vector2(6, 3) * u), Color(Toon.VERMILION, chain_break))


## Flamme : goutte pointe en haut, base ronde en c, la pointe vacille (phase ph).
func _flame(c: Vector2, r: float, ph: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var sway := sin(_t * 11.0 + ph) * 0.25 * r
	pts.append(c + Vector2(sway, -r * (2.1 + 0.15 * sin(_t * 17.0 + ph))))
	for k in 11:
		pts.append(c + Vector2.from_angle(-PI * 0.2 + PI * 1.4 * float(k) / 10.0) * r)
	return pts


## Pad tactile : zone où l'on trace, avec le geste en cours en miniature.
func _draw_pad(u: float) -> void:
	if pad.size.x < 10.0:
		return
	var pa := maxf(pad_alpha, 0.35 if pad_active else 0.0)
	if pa > 0.01:
		_draw_pad_frame(u, pa)
	if pad_active and pad_trail.size() > 0:
		draw_circle(pad_trail[0], 6 * u, Color(Toon.VERMILION, 0.8))
		if pad_trail.size() > 1:
			draw_polyline(pad_trail, Color(Toon.WASHI, 0.75), 4 * u, true)
		draw_circle(pad_trail[pad_trail.size() - 1], 9 * u, Color(Toon.WASHI, 0.3))


func _draw_pad_frame(u: float, pa: float) -> void:
	draw_style_box(UiKit.box(_sb, Color(Toon.WASHI, 0.06 * pa), int(18 * u), Color(Toon.WASHI, 0.22 * pa), int(1.5 * u)), pad)
	if not pad_active:
		# invitation : un doigt qui trace un petit trait vers le haut
		var c := pad.get_center()
		var k := fmod(_t, 1.6) / 1.6
		var p0 := c + Vector2(0, 18 * u)
		var p1 := p0 + Vector2(0, -36 * u * minf(k * 1.4, 1.0))
		draw_line(p0, p1, Color(Toon.WASHI, 0.35 * pa), 3 * u, true)
		draw_circle(p1, 7 * u, Color(Toon.WASHI, 0.4 * pa))
		var hint := "TRACE ICI"
		var hf := int(10 * u)
		var hw := UiKit.UI_FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hf).x
		draw_string(UiKit.UI_FONT, Vector2(c.x - hw / 2.0, pad.end.y - 10 * u), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hf, Color(Toon.WASHI, 0.45 * pa))


func _draw_room(sz: Vector2, u: float) -> void:
	# sceau du monde, puis « étape x / rooms_total »
	var cx := sz.x / 2.0
	var seal := Rect2(Vector2(cx - 54 * u, 15 * u), Vector2(36, 36) * u)
	draw_style_box(UiKit.box(_sb, world_color, int(7 * u)), seal)
	var kfs := int(24 * u)
	var kw := UiKit.TITLE_FONT.get_string_size(world_kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
	draw_string(UiKit.TITLE_FONT, Vector2(seal.get_center().x - kw / 2.0, seal.get_center().y + kfs * 0.36), world_kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Toon.WASHI)
	var tfs := int(22 * u)
	draw_string(UiKit.TITLE_FONT, Vector2(cx - 10 * u, 38 * u), str(wave), HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Toon.SUMI)
	var nw := UiKit.TITLE_FONT.get_string_size(str(wave), HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	draw_string(UiKit.UI_FONT, Vector2(cx - 8 * u + nw, 38 * u), "/ %d" % rooms_total, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u), Color(Toon.SUMI, 0.55))


## Jauge d'encre : verticale sur le bord droit, encre bleue vive cerclée de blanc (lisible sur tous les mondes).
## Le sceau de l'ultime est posé juste au-dessus.
func _draw_gauge(sz: Vector2, u: float) -> void:
	var gw := 16.0 * u
	var gh := sz.y * 0.3
	var gx := sz.x - gw - 12.0 * u
	var gy := sz.y * 0.3  # haut placé : bien visible, hors du pad
	# couleur de l'encre choisie à l'Atelier (éclaircie si trop sombre pour rester lisible)
	var ink: Color = InkStroke.ink
	if ink.get_luminance() < 0.3:
		ink = ink.lerp(Color("#C9CBD6"), 0.55)
	var low := elan < 0.2
	if elan_empty or low:
		ink = Toon.VERMILION if (elan_empty and int(Time.get_ticks_msec() / 90.0) % 2 == 0) or (low and not elan_empty) else ink
	# fond : pilule sombre translucide, liseré blanc
	_sb.bg_color = Color(0.06, 0.06, 0.09, 0.62)
	_sb.set_corner_radius_all(int(gw / 2.0 + 3.0 * u))
	_sb.border_color = Color(1, 1, 1, 0.75)
	_sb.set_border_width_all(int(maxf(1.0, 1.5 * u)))
	_sb.shadow_size = int(6 * u)
	_sb.shadow_color = Color(0, 0, 0, 0.35)
	_sb.shadow_offset = Vector2.ZERO
	draw_style_box(_sb, Rect2(Vector2(gx - 3.0 * u, gy - 3.0 * u), Vector2(gw + 6.0 * u, gh + 6.0 * u)))
	_sb.set_border_width_all(0)
	_sb.shadow_size = 0
	# remplissage du bas vers le haut, reflet clair sur le bord gauche
	var fh := gh * clampf(elan, 0.0, 1.0)
	if fh > 1.0:
		_sb.bg_color = ink
		_sb.set_corner_radius_all(int(gw / 2.0))
		draw_style_box(_sb, Rect2(Vector2(gx, gy + gh - fh), Vector2(gw, fh)))
		draw_rect(Rect2(Vector2(gx + 3.0 * u, gy + gh - fh + 4.0 * u), Vector2(3.0 * u, maxf(0.0, fh - 8.0 * u))), Color(1, 1, 1, 0.35))
	# graduations : une encoche tous les 2 m de trait
	var ticks := int(elan_m / 2.0)
	for i in range(1, ticks + 1):
		var y := gy + gh - gh * (2.0 * i / elan_m)
		if y > gy + 2.0:
			draw_line(Vector2(gx + 1.0 * u, y), Vector2(gx + gw * 0.45, y), Color(1, 1, 1, 0.45), 1.5 * u)
	if elan >= 0.999:
		draw_circle(Vector2(gx + gw / 2.0, gy), 3.5 * u + 1.5 * u * sin(_t * 6.0), Toon.GOLD)
	# goutte d'encre sous la jauge
	var drop := Vector2(gx + gw / 2.0, gy + gh + 16.0 * u)
	draw_circle(drop + Vector2(0, 2) * u, 6.0 * u, ink)
	draw_colored_polygon(PackedVector2Array([drop + Vector2(-5.5, 1) * u, drop + Vector2(0, -10) * u, drop + Vector2(5.5, 1) * u]), ink)
	draw_circle(drop + Vector2(-2, 1) * u, 1.6 * u, Color(1, 1, 1, 0.6))
	_draw_ult(Vector2(gx + gw / 2.0, gy - 26.0 * u), u)


## Jauge d'ultime : sceau rond au bout de la jauge d'encre ; pleine, il pulse en or (double tap).
func _draw_ult(c: Vector2, u: float) -> void:
	var r := 14.0 * u
	var full := ult >= 1.0
	var pulse := (0.5 + 0.5 * sin(_t * 7.0)) if full else 0.0
	if full:
		draw_circle(c, r + (4.0 + 3.0 * pulse) * u, Color(Toon.GOLD, 0.25 + 0.25 * pulse))
	draw_circle(c, r, Color(Toon.SUMI, 0.85))
	draw_arc(c, r - 2.0 * u, -PI / 2.0, -PI / 2.0 + TAU * clampf(ult, 0.0, 1.0), 32, Toon.GOLD if full else Color(Toon.VERMILION, 0.9), 3.5 * u, true)
	var fs := int(15 * u)
	var k := "筆"
	var kw := UiKit.TITLE_FONT.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(UiKit.TITLE_FONT, c + Vector2(-kw / 2.0, fs * 0.36), k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Toon.GOLD if full else Color(Toon.WASHI, 0.7))
	if full:
		var hs := int(9 * u)
		var hint := "2× TAP"
		var hw := UiKit.UI_FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		draw_string(UiKit.UI_FONT, c + Vector2(-hw / 2.0, -r - 6.0 * u), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(Toon.GOLD, 0.7 + 0.3 * pulse))


func _draw_boss(sz: Vector2, u: float) -> void:
	var bw := sz.x * 0.72
	var bx := (sz.x - bw) / 2.0
	var by := 84.0 * u
	var vuln := boss_vuln > 0.0
	var pulse := 0.5 + 0.5 * sin(_t * 10.0)
	var bfs := int(16 * u)
	var bn := plain(boss_name)
	var nw := UiKit.TITLE_FONT.get_string_size(bn, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
	var name_y := by - (16.0 if boss_has_shield else 7.0) * u
	draw_string(UiKit.TITLE_FONT, Vector2(sz.x / 2.0 - nw / 2.0, name_y), bn, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Toon.SUMI)
	if boss_has_shield:
		_draw_boss_shield(Vector2(bx, by - 11.0 * u), bw, u, vuln, pulse)
	# rouleau : deux baguettes et la barre d'encre vermillon (dorée et pulsante quand il est vulnérable)
	if vuln:
		draw_rect(Rect2(bx - 3 * u, by - 3 * u, bw + 6 * u, 16 * u), Color(Toon.GOLD, 0.25 + 0.35 * pulse))
	draw_rect(Rect2(bx - 6 * u, by - 3 * u, 4 * u, 16 * u), Toon.SUMI)
	draw_rect(Rect2(bx + bw + 2 * u, by - 3 * u, 4 * u, 16 * u), Toon.SUMI)
	draw_rect(Rect2(bx, by, bw, 10 * u), Color(Toon.WASHI, 0.85))
	var hp_col: Color = Toon.VERMILION.lerp(Toon.GOLD, 0.35 + 0.5 * pulse) if vuln else Toon.VERMILION
	_brush_bar(Vector2(bx, by), bw, 10.0 * u, boss_ratio, hp_col)
	if vuln:
		# compte à rebours : anneau d'or qui se vide, secondes au centre
		var rc := Vector2(bx + bw + 18.0 * u, by + 5.0 * u)
		var rr := 7.5 * u
		draw_circle(rc, rr + 1.5 * u, Color(Toon.SUMI, 0.85))
		var k := clampf(boss_vuln / maxf(boss_vuln_len, 0.1), 0.0, 1.0)
		draw_arc(rc, rr - 1.0 * u, -PI / 2.0, -PI / 2.0 + TAU * k, 28, Toon.GOLD, 2.5 * u, true)
		var cs := int(9 * u)
		var ct := str(int(ceil(boss_vuln)))
		var cw := UiKit.UI_FONT.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
		draw_string(UiKit.UI_FONT, rc + Vector2(-cw / 2.0, cs * 0.36), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Toon.GOLD)
	# point faible : le geste à faire, toujours visible sous la barre
	if boss_hint != "":
		var hs := int(11 * u)
		var ht := "POINT FAIBLE : " + plain(boss_hint)
		var hw := UiKit.UI_FONT.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		while hw > sz.x - 24.0 * u and hs > 7:
			hs -= 1
			hw = UiKit.UI_FONT.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		var hr := Rect2(Vector2(sz.x / 2.0 - hw / 2.0 - 10.0 * u, by + 15.0 * u), Vector2(hw + 20.0 * u, hs * 1.7))
		_sb.bg_color = Color(0.06, 0.05, 0.07, 0.72)
		_sb.set_corner_radius_all(int(hr.size.y / 2.0))
		_sb.set_border_width_all(0)
		_sb.shadow_size = 0
		draw_style_box(_sb, hr)
		draw_string(UiKit.UI_FONT, Vector2(hr.position.x + 10.0 * u, hr.position.y + hs * 1.22), ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(Toon.GOLD, 0.95))


## Bouclier du boss, juste au-dessus de sa vie : écu et barre bleue en segments, « BOUCLIER » ;
## brisé, écu fendu et « VULNÉRABLE » doré qui pulse.
func _draw_boss_shield(pos: Vector2, w: float, u: float, vuln: bool, pulse: float) -> void:
	var h := 6.0 * u
	# écu
	var c := Vector2(pos.x - 13.0 * u, pos.y + h * 0.5)
	var s := 5.5 * u
	var ecu := PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, s * 0.25), c + Vector2(0, s * 1.25), c + Vector2(-s, s * 0.25)])
	var edge := PackedVector2Array([c + Vector2(-s - u, -s - u), c + Vector2(s + u, -s - u), c + Vector2(s + u, s * 0.3), c + Vector2(0, s * 1.25 + 1.5 * u), c + Vector2(-s - u, s * 0.3)])
	draw_colored_polygon(edge, Toon.SUMI)
	draw_colored_polygon(ecu, Toon.GOLD if vuln else SHIELD_BAR)
	if vuln:
		# écu fendu
		draw_line(c + Vector2(-s * 0.2, -s), c + Vector2(s * 0.2, -s * 0.1), Toon.SUMI, 1.5 * u)
		draw_line(c + Vector2(s * 0.2, -s * 0.1), c + Vector2(-s * 0.15, s * 1.0), Toon.SUMI, 1.5 * u)
		var vs := int(10 * u)
		var vt := plain("VULNÉRABLE")
		var vw := UiKit.UI_FONT.get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, vs).x
		var vx := pos.x + w - vw
		draw_string(UiKit.UI_FONT, Vector2(vx, pos.y + h + 0.5 * u), vt, HORIZONTAL_ALIGNMENT_LEFT, -1, vs, Color(Toon.GOLD, 0.65 + 0.35 * pulse))
		return
	# barre en segments (le dernier se remplit en partie)
	var n := 12
	var gap := 2.0 * u
	var sw := (w - gap * float(n - 1)) / float(n)
	var fill := clampf(boss_shield, 0.0, 1.0) * float(n)
	for i in n:
		var x := pos.x + float(i) * (sw + gap)
		draw_rect(Rect2(x, pos.y, sw, h), Color(0.06, 0.06, 0.09, 0.55))
		var f := clampf(fill - float(i), 0.0, 1.0)
		if f > 0.0:
			draw_rect(Rect2(x, pos.y, sw * f, h), SHIELD_BAR)
	var ls := int(8 * u)
	var lt := plain("BOUCLIER")
	var lw := UiKit.UI_FONT.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
	draw_string(UiKit.UI_FONT, Vector2(pos.x + w - lw, pos.y - 1.5 * u), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, Toon.PRUSSIAN)


func _draw_gate_hint(sz: Vector2, u: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var ax := sz.x / 2.0
	var ay := 130.0 * u - 8.0 * u * pulse
	var arrow := PackedVector2Array([Vector2(ax, ay - 16 * u), Vector2(ax + 16 * u, ay + 6 * u), Vector2(ax + 6 * u, ay + 6 * u),
		Vector2(ax + 6 * u, ay + 22 * u), Vector2(ax - 6 * u, ay + 22 * u), Vector2(ax - 6 * u, ay + 6 * u), Vector2(ax - 16 * u, ay + 6 * u)])
	draw_colored_polygon(arrow, Color(Toon.GOLD, 0.55 + 0.4 * pulse))


func _draw_combo(sz: Vector2, u: float) -> void:
	var a := clampf(_combo_t / 0.4, 0.0, 1.0)
	# à gauche : la jauge d'encre occupe la droite
	var c := Vector2(92 * u, maxf(sz.y * 0.32, 160 * u) + top_off)
	# petite tache d'encre derrière le nombre
	draw_circle(c, 21 * u, Color(Toon.SUMI, 0.8 * a))
	draw_circle(c + Vector2(15, -12) * u, 4 * u, Color(Toon.SUMI, 0.6 * a))
	var fs := int((20 + 1.5 * mini(_combo_shown, 8)) * u)
	var txt := "×%d" % _combo_shown
	var tw := UiKit.TITLE_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(UiKit.TITLE_FONT, Vector2(c.x - tw / 2.0, c.y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.VERMILION if _combo_shown >= 4 else Toon.WASHI, a))


## Bandeau d'annonce : trait d'encre opaque aux bords déchirés, dans le tiers haut (sous le HUD),
## sceau carré de la couleur d'annonce avec son pictogramme, titre papier, sous-titre teinté.
## Entre en balayant de gauche à droite, sort en glissant et en s'effaçant.
func _draw_banner(sz: Vector2, u: float) -> void:
	var t := _banner_t
	var k_in := clampf(t / 0.28, 0.0, 1.0)
	var k_out := clampf((_banner_len - t) / 0.3, 0.0, 1.0)
	var a := k_out
	var ein := UiKit.ease_out(k_in)
	var has_sub := _banner_small != ""
	var bw := minf(sz.x - 28.0 * u, 352.0 * u)
	var h := 62.0 * u if has_sub else 48.0 * u
	var cy := top_off + 118.0 * u  # en haut au centre, sous le bloc vie / étape
	var x0 := (sz.x - bw) / 2.0 + (1.0 - k_out) * 26.0 * u
	var reach := bw * (0.15 + 0.85 * ein)
	var acc := _banner_col
	var acc_l: Color = acc.lightened(0.35) if acc.get_luminance() < 0.4 else acc
	# ombre portée puis le trait d'encre (bords irréguliers, bout droit effiloché)
	var n := 22
	var pts := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / n
		var jag := (sin(float(i) * 2.7) * 1.6 + sin(float(i) * 1.1) * 1.2) * u
		pts.append(Vector2(x0 + reach * f, cy - h / 2.0 + jag - (2.0 * u if i == 0 else 0.0)))
	for i in range(n, -1, -1):
		var f := float(i) / n
		var jag := (sin(float(i) * 1.9 + 1.0) * 1.6 + sin(float(i) * 0.7) * 1.3) * u
		pts.append(Vector2(x0 + reach * f - (6.0 * u * f * f), cy + h / 2.0 + jag))
	var shadow := Transform2D(0.0, Vector2(0, 4 * u)) * pts
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.25 * a))
	draw_colored_polygon(pts, Color(Toon.SUMI, 0.96 * a))
	# poils du pinceau au bout du trait
	for j in 5:
		var yy := cy - h * 0.38 + h * 0.19 * float(j)
		var ln := (10.0 + 8.0 * sin(float(j) * 2.3 + 0.5)) * u
		draw_line(Vector2(x0 + reach - 3.0 * u, yy), Vector2(x0 + reach + ln * ein, yy + 1.0 * u), Color(Toon.SUMI, 0.75 * a), 2.0 * u, true)
	# filet de couleur sous le trait, tracé avec lui
	draw_line(Vector2(x0 + 8 * u, cy + h / 2.0 - 5 * u), Vector2(x0 + maxf(8 * u, reach - 14 * u), cy + h / 2.0 - 5 * u), Color(acc_l, 0.95 * a), 2.5 * u, true)
	# sceau : se pose comme un tampon juste après le trait
	var sk := clampf((t - 0.1) / 0.22, 0.0, 1.0)
	var sc := Vector2(x0 + 30.0 * u, cy - 1.0 * u)
	if sk > 0.0:
		var z := lerpf(1.6, 1.0, UiKit.ease_out(sk))
		var half := 17.0 * u * z
		draw_style_box(UiKit.box(_sb, Color(acc, a * sk), int(6 * u), Color(Toon.WASHI, 0.85 * a * sk), maxi(1, int(1.5 * u))), Rect2(sc - Vector2(half, half), Vector2(half, half) * 2.0))
		UiKit.glyph(self, _banner_icon, sc, 11.0 * u * z, Toon.WASHI, acc, a * sk)
	# zone ou étape nettoyée : petite gerbe d'or autour du sceau
	if _banner_icon == "torii" and t < 0.8:
		var gk := clampf((t - 0.15) / 0.6, 0.0, 1.0)
		for j in 10:
			var d := Vector2.from_angle(TAU * float(j) / 10.0 + 0.3)
			draw_line(sc + d * (22.0 + 18.0 * gk) * u, sc + d * (28.0 + 24.0 * gk) * u, Color(Toon.GOLD.lightened(0.25), (1.0 - gk) * a), 2.0 * u, true)
	# textes, à droite du sceau (rétrécis s'ils débordent)
	var tx := x0 + 58.0 * u
	var room := bw - 66.0 * u
	var ta := a * clampf((t - 0.08) / 0.2, 0.0, 1.0)
	var fs := int(22 * u)
	while fs > 12 and UiKit.TITLE_FONT.get_string_size(_banner_big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	var ty := cy + (-1.0 * u if has_sub else fs * 0.36)
	draw_string(UiKit.TITLE_FONT, Vector2(tx + (1.0 - ein) * 12.0 * u, ty), _banner_big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.WASHI, ta))
	if has_sub:
		var sfs := int(10 * u)
		while sfs > 7 and UiKit.UI_FONT.get_string_size(_banner_small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x > room:
			sfs -= 1
		draw_string(UiKit.UI_FONT, Vector2(tx, cy + 16.0 * u), _banner_small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(acc_l.lerp(Toon.WASHI, 0.45), ta))


func _brush_bar(pos: Vector2, w: float, h: float, fill: float, c: Color) -> void:
	if fill <= 0.001:
		return
	# bord haut de gauche à droite, puis bord bas de droite à gauche
	var fw := w * clampf(fill, 0.0, 1.0)
	var mid := pos.y + h / 2.0
	for i in BAR_N + 1:
		var x := pos.x + fw * float(i) / BAR_N
		var th := h * _bar_th[i] / 2.0
		_bar_pts[i] = Vector2(x, mid - th)
		_bar_pts[2 * BAR_N + 1 - i] = Vector2(x, mid + th)
	draw_colored_polygon(_bar_pts, c)


## Bandes noires du cinéma, bord inférieur/supérieur taché d'encre.
func _draw_cine(sz: Vector2, u: float) -> void:
	var h := sz.y * 0.1 * cine
	if h < 1.0:
		return
	draw_rect(Rect2(0, 0, sz.x, h), Toon.SUMI)
	draw_rect(Rect2(0, sz.y - h, sz.x, h), Toon.SUMI)
	var n := 9
	for i in n + 1:
		var x := sz.x * float(i) / n
		var r := (5.0 + 3.0 * sin(float(i) * 2.3)) * u * cine
		draw_circle(Vector2(x, h), r, Toon.SUMI)
		draw_circle(Vector2(x + sz.x * 0.5 / n, sz.y - h), (5.0 + 3.0 * sin(float(i) * 1.7 + 1.0)) * u * cine, Toon.SUMI)


## Carton titre : coup de pinceau qui traverse l'écran sous le boss, kanji estampillé au-dessus.
func _draw_card(sz: Vector2, u: float) -> void:
	var sc := 0.8 if _card_mini else 1.0
	var k_in := clampf(_card_t / 0.35, 0.0, 1.0)
	var a := minf(k_in, clampf((_card_len - _card_t) / 0.3, 0.0, 1.0))
	var cy := sz.y * 0.7
	var h := 66.0 * u * sc
	var reach := sz.x * (0.1 + 0.9 * UiKit.ease_out(k_in))
	var pts := PackedVector2Array()
	var n := 20
	for i in n + 1:
		var x := reach * float(i) / n
		var th := h * (0.75 + 0.25 * sin(float(i) * 1.1)) * (0.8 + 0.2 * sin(PI * float(i) / n))
		pts.append(Vector2(x, cy - th / 2.0))
	for i in range(n, -1, -1):
		var x := reach * float(i) / n
		var th := h * (0.75 + 0.25 * sin(float(i) * 0.8 + 2.0)) * (0.8 + 0.2 * sin(PI * float(i) / n))
		pts.append(Vector2(x, cy + th / 2.0))
	draw_colored_polygon(pts, Color(Toon.SUMI, 0.92 * a))
	var kanji: String = _card[0]
	var nm: String = _card[1]
	var ep: String = _card[2]
	var sub: String = _card[3]
	# nom romanisé, puis l'épithète
	var fs := int(26 * u * sc)
	var tw := UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(UiKit.TITLE_FONT, Vector2(sz.x / 2.0 - tw / 2.0, cy + fs * 0.12), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.WASHI, a))
	if ep != "":
		var et := "— " + ep + " —"
		var efs := int(11 * u * sc)
		var ew := UiKit.UI_FONT.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, efs).x
		draw_string(UiKit.UI_FONT, Vector2(sz.x / 2.0 - ew / 2.0, cy + 20 * u * sc), et, HORIZONTAL_ALIGNMENT_LEFT, -1, efs, Color(Toon.WASHI, 0.82 * a))
	# sous-titre dans un sceau vermillon, sous le trait
	if sub != "":
		var sfs := int(10 * u * sc)
		var sw := UiKit.UI_FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		var sp := Vector2(sz.x / 2.0 - sw / 2.0, cy + h / 2.0 + 20 * u * sc)
		draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, 0.92 * a), 999), Rect2(sp + Vector2(-10 * u, -sfs - 3 * u), Vector2(sw + 20 * u, sfs + 10 * u)))
		draw_string(UiKit.UI_FONT, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(Toon.WASHI, a))
	# kanji : tombe comme un tampon, un peu après le trait
	if _card_kanji:
		var ks := clampf((_card_t - 0.12) / 0.2, 0.0, 1.0)
		if ks > 0.0:
			var kfs := int(46 * u * sc)
			var kw := UiKit.TITLE_FONT.get_string_size(kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
			var kc := Vector2(sz.x / 2.0, cy - h / 2.0 - kfs * 0.45)
			var z := lerpf(1.7, 1.0, UiKit.ease_out(ks))
			var ka := a * ks
			draw_set_transform(kc, 0.0, Vector2(z, z))
			var kp := Vector2(-kw / 2.0, kfs * 0.36)
			draw_string_outline(UiKit.TITLE_FONT, kp, kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, int(7 * u), Color(Toon.WASHI, ka))
			draw_string(UiKit.TITLE_FONT, kp, kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(Toon.VERMILION, ka))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Zone de sécurité : l'encoche et la barre d'état ne doivent pas cacher les cœurs ni l'XP.
func _update_safe_top() -> void:
	var u := size.x / 400.0
	var inset := 0.0
	var win := DisplayServer.window_get_size()
	if win.y > 0:
		var safe := DisplayServer.get_display_safe_area()
		inset = float(safe.position.y) * size.y / float(win.y)
	top_off = clampf(inset, 0.0, 80.0 * u) + 12.0 * u


## Progression de l'étape : colonne à gauche (bas = arrivée, haut = torii), zones de combat
## (grises à venir, vermillon en cours, or nettoyées), le héros en point, et le compte des combats.
func _draw_stage_bar(_sz: Vector2, u: float) -> void:
	if stage_k < 0.0:
		return
	# seulement quelques secondes : en début d'étape et à la fin de chaque combat
	if enc_done != _stage_seen_done or enc_total != _stage_seen_total:
		_stage_seen_done = enc_done
		_stage_seen_total = enc_total
		_stage_vis_t = 3.2
	if _stage_vis_t <= 0.0:
		return
	var sa := clampf(_stage_vis_t / 0.5, 0.0, 1.0) * clampf((3.2 - _stage_vis_t) / 0.25, 0.0, 1.0)
	draw_set_transform(Vector2(-30.0 * u * (1.0 - sa), 0.0))
	var x := 18.0 * u
	var y0 := top_off + 236.0 * u
	var y1 := y0 + 200.0 * u
	# fond : pilule sombre translucide pour rester lisible partout
	_sb.bg_color = Color(0.06, 0.05, 0.07, 0.55)
	_sb.set_corner_radius_all(int(9 * u))
	_sb.set_border_width_all(0)
	_sb.shadow_size = 0
	draw_style_box(_sb, Rect2(Vector2(x - 9.0 * u, y0 - 26.0 * u), Vector2(18.0 * u, y1 - y0 + 34.0 * u)))
	draw_line(Vector2(x, y0), Vector2(x, y1), Color(1, 1, 1, 0.25), 5.0 * u, true)
	for m in stage_marks:
		var mk: Array = m
		var ya := lerpf(y1, y0, float(mk[0]))
		var yb := lerpf(y1, y0, float(mk[1]))
		var st := int(mk[2])
		var col := Color(1, 1, 1, 0.6)
		if st == 1:
			col = Toon.VERMILION
		elif st == 2:
			col = Toon.GOLD
		draw_line(Vector2(x, ya - 2.0 * u), Vector2(x, yb + 2.0 * u), col, 8.0 * u, true)
	# petit torii au bout du chemin
	var tc := Vector2(x, y0 - 13.0 * u)
	draw_line(tc + Vector2(-4, -4) * u, tc + Vector2(-3.5, 6) * u, Toon.VERMILION, 2.2 * u, true)
	draw_line(tc + Vector2(4, -4) * u, tc + Vector2(3.5, 6) * u, Toon.VERMILION, 2.2 * u, true)
	draw_line(tc + Vector2(-7, -5) * u, tc + Vector2(7, -5) * u, Toon.WASHI, 2.6 * u, true)
	draw_line(tc + Vector2(-5, -1.5) * u, tc + Vector2(5, -1.5) * u, Toon.VERMILION, 1.8 * u, true)
	# le héros
	var hy := lerpf(y1, y0, clampf(stage_k, 0.0, 1.0))
	draw_circle(Vector2(x, hy), 7.0 * u, Toon.WASHI)
	draw_circle(Vector2(x, hy), 4.6 * u, Toon.SUMI)
	draw_circle(Vector2(x, hy), 2.2 * u, Toon.VERMILION)
	if enc_total > 0:
		var txt := "%d/%d" % [enc_done, enc_total]
		var fs := int(14 * u)
		var p := Vector2(x + 14.0 * u, y1 - 2.0 * u)
		draw_string_outline(UiKit.TITLE_FONT, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(4 * u), Color(Toon.SUMI, 0.7))
		draw_string(UiKit.TITLE_FONT, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Toon.WASHI)
		var p2 := Vector2(x + 14.0 * u, y1 + 10.0 * u)
		draw_string_outline(UiKit.UI_FONT, p2, "COMBATS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * u), int(3 * u), Color(Toon.SUMI, 0.7))
		draw_string(UiKit.UI_FONT, p2, "COMBATS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * u), Color(Toon.WASHI, 0.9))
	draw_set_transform(Vector2.ZERO)


## Rituel du torii : un lavis d'encre part de l'arche (wash_c) et couvre l'écran (bords qui bavent,
## gouttes projetées) ; au retour (wash_out), l'encre se dilue et laisse voir la suite.
func _draw_wash(sz: Vector2, u: float) -> void:
	if wash_out:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(Toon.SUMI, clampf(wash, 0.0, 1.0)))
		return
	var far := 0.0
	for cp in [Vector2.ZERO, Vector2(sz.x, 0), Vector2(0, sz.y), sz]:
		var corner: Vector2 = cp
		far = maxf(far, wash_c.distance_to(corner))
	var k := clampf(wash, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 2.2)
	if k >= 0.999:
		draw_rect(Rect2(Vector2.ZERO, sz), Toon.SUMI)
		return
	var r := far * 1.18 * e
	var n := 44
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var jag := 1.0 + 0.09 * sin(float(i) * 3.1 + _t * 2.0) + 0.05 * sin(float(i) * 7.3)
		pts.append(wash_c + Vector2.from_angle(a) * maxf(r * jag, 1.0))
	draw_colored_polygon(pts, Toon.SUMI)
	# gouttes projetées au front du lavis
	for j in 14:
		var a2 := TAU * float(j) / 14.0 + 0.4
		var d := r * (1.08 + 0.12 * sin(float(j) * 5.7))
		draw_circle(wash_c + Vector2.from_angle(a2) * d, (3.0 + 4.0 * absf(sin(float(j) * 2.3))) * u * (0.4 + e), Color(Toon.SUMI, 0.9))
	# halo doré de l'arche, au cœur du lavis
	if k < 0.6:
		draw_circle(wash_c, (18.0 + 30.0 * k) * u, Color(Toon.GOLD, 0.35 * (1.0 - k / 0.6)))

