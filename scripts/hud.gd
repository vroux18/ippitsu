extends Control
## Interface de jeu dessinée à la main.
## En haut : cœurs d'encre (à gauche), sceau du monde + salle + vagues (au centre), pause (à droite).
## Sous le haut : barre du boss. En bas : jauge d'élan graduée. Par-dessus : bandeaux d'annonce,
## compteur de combo, barres de vie des ennemis, voile de mort et rideau de transition.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const BAR_N := 24  # segments des barres au pinceau

signal pause_pressed

# état fourni par main à chaque image
var hp := 5
var max_hp := 5
var elan := 1.0
var elan_m := 14.0  # longueur max du trait (graduations tous les 2 m)
var elan_empty := false
var wave := 1  # salle en cours
var rooms_total := 15
var wave_index := 1
var waves_total := 1
var show_waves := false
var gate_hint := false
var boss_name := ""
var boss_ratio := 1.0
var wipe := 0.0  # rideau d'encre de la transition entre salles (0..1)
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
var enemy_bars: Array = []  # [position écran, ratio de vie]
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
var _shapes: Array = []  # figures enchaînées : [forme, âge]
var shape_name := ""
var _shape_t := 9.0
var _real_dt := 0.0
var power_seals: Array = []  # [kanji, couleur d'école, niveau, couleur de rareté, rang] des pouvoirs possédés
var game_over := false
var over_t := 0.0
var best_wave := 0

var _shown_hp := -1
var _lost: Array = []  # [index du cœur, temps]
var _combo_shown := 0
var _combo_t := 0.0
var _banner_big := ""
var _banner_small := ""
var _banner_col := Toon.SUMI
var _banner_t := -1.0
var _banner_len := 2.0
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


## Petite annonce discrète (vague suivante, salle…) sous le haut de l'écran.
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


## Bandeau d'annonce au centre : début de partie, nouvelle salle, boss…
func banner(big: String, small := "", col := Toon.SUMI, length := 2.0) -> void:
	_banner_big = plain(big)
	_banner_small = plain(small)
	_banner_col = col
	_banner_t = 0.0
	_banner_len = length


func _process(_delta: float) -> void:
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	if hurt_flash > 0.0:
		hurt_flash = maxf(0.0, hurt_flash - real * 2.5)
	# un cœur perdu : il éclate
	if _shown_hp < 0:
		_shown_hp = hp
	if hp < _shown_hp:
		for i in range(hp, _shown_hp):
			_lost.append([i, 0.0])
	_shown_hp = hp
	if not _lost.is_empty():
		for l in _lost:
			l[1] = float(l[1]) + real
		_lost = _lost.filter(func(l): return float(l[1]) < 0.7)
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
	_pause.position = Vector2(size.x - 54 * u, 16 * u)
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
		var bw := 30.0 * u
		var rect := Rect2(p - Vector2(bw / 2.0, 0), Vector2(bw, 5 * u))
		draw_rect(rect.grow(1.5 * u), Color(Toon.SUMI, 0.75))
		draw_rect(Rect2(rect.position, Vector2(bw * clampf(r, 0.0, 1.0), rect.size.y)), Toon.VERMILION)

	if in_play:
		_draw_pad(u)
		# voile de papier en dégradé derrière le bandeau du haut : lisible sur n'importe quel décor
		var top_h := 96.0 * u
		var paper := Color(Toon.PAPER, 0.88)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), Vector2(sz.x, top_h * 0.55), Vector2(0, top_h * 0.55)]),
			PackedColorArray([paper, paper, paper, paper]))
		draw_polygon(PackedVector2Array([Vector2(0, top_h * 0.55), Vector2(sz.x, top_h * 0.55), Vector2(sz.x, top_h), Vector2(0, top_h)]),
			PackedColorArray([paper, paper, Color(paper, 0.0), Color(paper, 0.0)]))
		_draw_hearts(u)
		_draw_seals(sz, u)
		_draw_shape_pop(sz, u)
		_draw_xp(u)
		_draw_chain(u)
		_draw_room(sz, u)
		_draw_gauge(sz, u)
		if boss_name != "":
			_draw_boss(sz, u)
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


# ------------------------------------------------------------------ éléments

## Cœur : courbe précalculée, placée en c à l'échelle s (fermée pour le contour).
## On transforme les points plutôt que le canevas : l'épaisseur des contours reste nette.
func _heart_pts(c: Vector2, s: float, closed := false) -> PackedVector2Array:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	if closed:
		return xf * _heart_loop
	return xf * _heart


func _draw_hearts(u: float) -> void:
	# une seule rangée : au-delà de 5 cœurs, ils se resserrent et rapetissent (place jusqu'au sceau du monde)
	var k_fit := minf(1.0, 5.0 / maxf(float(max_hp), 1.0))
	for i in max_hp:
		var c := Vector2(24 * u + i * 27 * u * k_fit, 34 * u)
		var s := 10.5 * u * lerpf(1.0, k_fit, 0.6)
		var lost_t := -1.0
		for l in _lost:
			if int(l[0]) == i:
				lost_t = float(l[1])
		if i < hp:
			var beat := 1.0 + (0.08 * maxf(0.0, sin(_t * 6.0)) if hp == 1 else 0.0)
			draw_colored_polygon(_heart_pts(c + Vector2(0, 2.5 * u), s * beat), Color(Toon.SUMI, 0.25))
			draw_colored_polygon(_heart_pts(c, s * beat), Toon.VERMILION)
			draw_circle(c + Vector2(-4.5, -4.0) * u * beat, 2.6 * u, Color(1, 1, 1, 0.55))
			draw_polyline(_heart_pts(c, s * beat, true), Toon.SUMI, 2.0 * u, true)
		elif lost_t >= 0.0:
			# il vient d'être perdu : il gonfle, se fend et part en éclats
			var k := lost_t / 0.7
			var pts2 := _heart_pts(c, s * (1.0 + 0.5 * k))
			draw_colored_polygon(pts2, Color(Toon.VERMILION, 1.0 - k))
			draw_line(c + Vector2(-2, -8) * u, c + Vector2(2, 0) * u, Color(Toon.SUMI, 1.0 - k), 2.0 * u)
			draw_line(c + Vector2(2, 0) * u, c + Vector2(-1, 8) * u, Color(Toon.SUMI, 1.0 - k), 2.0 * u)
			for j in 5:
				var a := TAU * j / 5.0
				draw_circle(c + Vector2(cos(a), sin(a)) * (6.0 + 26.0 * k) * u + Vector2(0, 30 * k * k) * u, 2.4 * u * (1.0 - k), Color(Toon.VERMILION, 1.0 - k))
		else:
			draw_polyline(_heart_pts(c, s, true), Color(Toon.SUMI, 0.3), 1.8 * u, true)


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
	var r := 19.0 * u
	var gap := 2.0 * r + 8.0 * u
	var y := 150.0 * u
	var x0 := sz.x / 2.0 - (n - 1) * gap / 2.0
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
		var fs := int(11 * u)
		var tw := UiKit.UI_FONT.get_string_size(shape_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cx := x0 + (n - 1) * gap
		var tx := clampf(cx - tw / 2.0, 8.0 * u, sz.x - tw - 8.0 * u)
		var tp := Vector2(tx, y + r * 1.25 + 17.0 * u)
		var la := a * clampf((2.2 - _shape_t) / 0.3, 0.0, 1.0)
		draw_rect(Rect2(tp + Vector2(-8 * u, -fs * 1.05), Vector2(tw + 16 * u, fs * 1.55)), Color(Toon.SUMI, 0.8 * la))
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

## Colonne des sceaux de pouvoirs (même géométrie que _draw_seals) : la toucher ouvre le récapitulatif.
func is_over_seals(p: Vector2) -> bool:
	if power_seals.is_empty() or not in_play or dying > 0.0:
		return false
	var u := size.x / 400.0
	var r := 11.0 * u
	var step := 2.0 * r + 12.0 * u
	var per_col := int(floor((size.y * 0.6 - 84.0 * u) / step)) + 1
	var n := power_seals.size()
	var cols := int(ceil(float(n) / float(maxi(per_col, 1))))
	var rows := mini(n, per_col)
	var right := size.x - 26.0 * u + r + 6.0 * u
	var left := size.x - 26.0 * u - float(cols - 1) * (2.0 * r + 10.0 * u) - r - 6.0 * u
	var top := 84.0 * u - r - 6.0 * u
	var bottom := 84.0 * u + float(rows - 1) * step + r + 10.0 * u
	return Rect2(left, top, right - left, bottom - top).has_point(p)


## Pouvoirs possédés : colonne de petits sceaux sous le bouton pause (école, niveau, liseré de rareté).
func _draw_seals(sz: Vector2, u: float) -> void:
	var r := 11.0 * u
	var x := sz.x - 26.0 * u
	var y := 84.0 * u
	for sd in power_seals:
		var c := Vector2(x, y)
		var col: Color = sd[1]
		var rc: Color = sd[3]
		# liseré de rareté (or animé pour les légendaires)
		var glow := 0.0
		if int(sd[4]) >= 3:
			glow = 0.35 + 0.25 * sin(_t * 3.0)
		draw_circle(c, r + 2.5 * u + glow * 2.0 * u, Color(rc, 0.9))
		draw_circle(c, r, col)
		var fs := int(13 * u)
		var k := String(sd[0])
		var kw := UiKit.TITLE_FONT.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(UiKit.TITLE_FONT, c + Vector2(-kw / 2.0, fs * 0.36), k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Toon.WASHI)
		# niveau : petits points sous le sceau
		var lv := int(sd[2])
		for i in lv:
			draw_circle(c + Vector2((i - (lv - 1) / 2.0) * 5.0 * u, r + 5.0 * u), 1.6 * u, Toon.SUMI)
		y += 2.0 * r + 12.0 * u
		if y > sz.y * 0.6:
			# deuxième colonne
			y = 84.0 * u
			x -= 2.0 * r + 10.0 * u


## Chaîne : sous les cœurs, nombre, bonus de dégâts et jauge de temps restant ; éclat quand elle se brise.
func _draw_chain(u: float) -> void:
	var p := Vector2(14 * u, 68 * u)
	if chain >= 2:
		var tier_col := Toon.SUMI
		if chain >= 20:
			tier_col = Toon.VERMILION
		elif chain >= 10:
			tier_col = Toon.GOLD
		elif chain >= 5:
			tier_col = Toon.PRUSSIAN
		var box := Rect2(p, Vector2(112, 34) * u)
		draw_style_box(UiKit.box(_sb, Color(Toon.WASHI, 0.85), int(8 * u), tier_col, int(2 * u)), box)
		draw_string(UiKit.UI_FONT, p + Vector2(9, 14) * u, "CHAÎNE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Color(Toon.SUMI, 0.6))
		draw_string(UiKit.TITLE_FONT, p + Vector2(9, 30) * u, str(chain), HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), tier_col)
		draw_string(UiKit.UI_FONT, p + Vector2(58, 27) * u, "+%d %%" % int(round((chain_mult - 1.0) * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), Color(Toon.SUMI, 0.8))
		# temps restant avant que la chaîne s'éteigne
		draw_rect(Rect2(p + Vector2(8, 31) * u, Vector2(96 * clampf(chain_left, 0.0, 1.0), 2) * u), tier_col)
	if chain_break > 0.0:
		var k := 1.0 - chain_break
		var txt := "CHAÎNE BRISÉE  %d" % chain_lost
		draw_string(UiKit.UI_FONT, p + Vector2(4, 28 + 18 * k) * u, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), Color(Toon.VERMILION, chain_break))
		for j in 5:
			var a := TAU * j / 5.0
			draw_rect(Rect2(p + Vector2(56, 18) * u + Vector2(cos(a), sin(a)) * 40.0 * u * k, Vector2(6, 3) * u), Color(Toon.SUMI, chain_break))


## Niveau, barre d'expérience (jade) et or ramassé, sous les cœurs.
func _draw_xp(u: float) -> void:
	var p := Vector2(14 * u, 54 * u)
	var lv := "NIV %d" % level
	draw_string(UiKit.UI_FONT, p + Vector2(0, 4 * u), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Toon.SUMI)
	var bx := p.x + 38 * u
	var bw := 96.0 * u
	draw_rect(Rect2(Vector2(bx, p.y - 2 * u), Vector2(bw, 6 * u)), Color(Toon.SUMI, 0.55))
	draw_rect(Rect2(Vector2(bx + 1 * u, p.y - 1 * u), Vector2((bw - 2 * u) * clampf(xp_ratio, 0.0, 1.0), 4 * u)), Color("#3FD1B2"))
	# or
	var gp := Vector2(bx + bw + 14 * u, p.y + 1 * u)
	draw_circle(gp, 5.5 * u, Toon.GOLD)
	draw_circle(gp, 3.0 * u, Color("#8C6A2A"))
	draw_string(UiKit.UI_FONT, gp + Vector2(9 * u, 4 * u), str(gold), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Toon.SUMI)


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
	# sceau du monde, puis « salle x / rooms_total » et les vagues de la salle
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
	if show_waves and waves_total > 1 and boss_name == "":
		for i in waves_total:
			var wp := Vector2(cx - 6 * u + i * 12 * u, 50 * u)
			if i < wave_index:
				draw_rect(Rect2(wp - Vector2(4, 2) * u, Vector2(8, 4) * u), Toon.SUMI)
			else:
				draw_rect(Rect2(wp - Vector2(4, 2) * u, Vector2(8, 4) * u), Color(Toon.SUMI, 0.22))


func _draw_gauge(sz: Vector2, u: float) -> void:
	var gw := sz.x * 0.66
	var gh := 13.0 * u
	var gx := (sz.x - gw) / 2.0
	var gy := sz.y - 46.0 * u
	# goutte d'encre à gauche
	var drop := Vector2(gx - 16 * u, gy + gh / 2.0)
	draw_circle(drop + Vector2(0, 2) * u, 5.5 * u, Toon.SUMI)
	draw_colored_polygon(PackedVector2Array([drop + Vector2(-5, 1) * u, drop + Vector2(0, -9) * u, drop + Vector2(5, 1) * u]), Toon.SUMI)
	_brush_bar(Vector2(gx, gy), gw, gh, 1.0, Color(Toon.SUMI, 0.13))
	var col := Toon.SUMI
	if elan_empty:
		col = Toon.VERMILION if (Time.get_ticks_msec() / 90) % 2 == 0 else Toon.SUMI
	_brush_bar(Vector2(gx, gy), gw, gh, elan, col)
	if elan >= 0.999:
		draw_circle(Vector2(gx + gw, gy + gh / 2.0), 3.5 * u + 1.5 * u * sin(_t * 6.0), Toon.GOLD)
	# graduations : une encoche tous les 2 m de trait
	var ticks := int(elan_m / 2.0)
	for i in range(1, ticks + 1):
		var x := gx + gw * (2.0 * i / elan_m)
		if x < gx + gw - 2:
			draw_line(Vector2(x, gy - 2 * u), Vector2(x, gy + 3 * u), Color(Toon.SUMI, 0.35), 1.5 * u)


func _draw_boss(sz: Vector2, u: float) -> void:
	var bw := sz.x * 0.72
	var bx := (sz.x - bw) / 2.0
	var by := 84.0 * u
	var bfs := int(16 * u)
	var bn := plain(boss_name)
	var nw := UiKit.TITLE_FONT.get_string_size(bn, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
	draw_string(UiKit.TITLE_FONT, Vector2(sz.x / 2.0 - nw / 2.0, by - 7 * u), bn, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Toon.SUMI)
	# rouleau : deux baguettes et la barre d'encre vermillon
	draw_rect(Rect2(bx - 6 * u, by - 3 * u, 4 * u, 16 * u), Toon.SUMI)
	draw_rect(Rect2(bx + bw + 2 * u, by - 3 * u, 4 * u, 16 * u), Toon.SUMI)
	draw_rect(Rect2(bx, by, bw, 10 * u), Color(Toon.WASHI, 0.85))
	_brush_bar(Vector2(bx, by), bw, 10.0 * u, boss_ratio, Toon.VERMILION)


func _draw_gate_hint(sz: Vector2, u: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var ax := sz.x / 2.0
	var ay := 130.0 * u - 8.0 * u * pulse
	var arrow := PackedVector2Array([Vector2(ax, ay - 16 * u), Vector2(ax + 16 * u, ay + 6 * u), Vector2(ax + 6 * u, ay + 6 * u),
		Vector2(ax + 6 * u, ay + 22 * u), Vector2(ax - 6 * u, ay + 22 * u), Vector2(ax - 6 * u, ay + 6 * u), Vector2(ax - 16 * u, ay + 6 * u)])
	draw_colored_polygon(arrow, Color(Toon.GOLD, 0.55 + 0.4 * pulse))


func _draw_combo(sz: Vector2, u: float) -> void:
	var a := clampf(_combo_t / 0.4, 0.0, 1.0)
	var c := Vector2(sz.x - 40 * u, sz.y * 0.32)
	# petite tache d'encre derrière le nombre
	draw_circle(c, 21 * u, Color(Toon.SUMI, 0.8 * a))
	draw_circle(c + Vector2(15, -12) * u, 4 * u, Color(Toon.SUMI, 0.6 * a))
	var fs := int((20 + 1.5 * mini(_combo_shown, 8)) * u)
	var txt := "×%d" % _combo_shown
	var tw := UiKit.TITLE_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(UiKit.TITLE_FONT, Vector2(c.x - tw / 2.0, c.y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.VERMILION if _combo_shown >= 4 else Toon.WASHI, a))


func _draw_banner(sz: Vector2, u: float) -> void:
	var k_in := clampf(_banner_t / 0.3, 0.0, 1.0)
	var k_out := clampf((_banner_len - _banner_t) / 0.35, 0.0, 1.0)
	var a := minf(k_in, k_out)
	var cy := sz.y * 0.3
	# grand coup de pinceau horizontal qui traverse l'écran
	var reach := sz.x * (0.1 + 0.9 * (1.0 - pow(1.0 - k_in, 3.0)))
	var pts := PackedVector2Array()
	var n := 20
	var h := 70.0 * u if _banner_small != "" else 44.0 * u
	for i in n + 1:
		var x := reach * float(i) / n
		var th := h * (0.7 + 0.3 * sin(float(i) * 0.9)) * (0.85 + 0.15 * sin(PI * float(i) / n))
		pts.append(Vector2(x, cy - th / 2.0))
	for i in range(n, -1, -1):
		var x := reach * float(i) / n
		var th := h * (0.7 + 0.3 * sin(float(i) * 1.3 + 1.0)) * (0.85 + 0.15 * sin(PI * float(i) / n))
		pts.append(Vector2(x, cy + th / 2.0))
	draw_colored_polygon(pts, Color(_banner_col, 0.92 * a))
	var fs := int(22 * u)
	var tw := UiKit.TITLE_FONT.get_string_size(_banner_big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := cy + (fs * 0.35 if _banner_small == "" else -fs * 0.05)
	draw_string(UiKit.TITLE_FONT, Vector2(sz.x / 2.0 - tw / 2.0, ty), _banner_big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.WASHI, a))
	if _banner_small != "":
		var sfs := int(10 * u)
		var sw := UiKit.UI_FONT.get_string_size(_banner_small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		draw_string(UiKit.UI_FONT, Vector2(sz.x / 2.0 - sw / 2.0, cy + 19 * u), _banner_small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(Toon.WASHI, 0.85 * a))


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
