extends Control
## Bouton dessiné : principal (encre, liseré vermillon), secondaire clair (ghost), rond à icône,
## coup de pinceau (brush), texte souligné au pinceau (text), icône et légende (icon), icône nue (bare)
## ou simple zone tactile (area). Une icône peut accompagner le texte (lead_icon).
## Ne se redessine que si quelque chose change (sauf le coup de pinceau, qui respire).
const Perf = preload("res://scripts/perf_probe.gd")  # relevé par image (-- --perf)

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

signal pressed

const APPEAR_T := 0.5  # apparition : trait posé de gauche à droite, puis légende
const SPLASH_T := 0.38  # éclaboussure de l'appui

var text := "":
	set(v):
		if v != text:
			text = v
			queue_redraw()
var style := "primary":  # primary | ghost | round | brush | text | icon | bare | area | label
	set(v):
		if v != style:
			style = v
			queue_redraw()
var lead_icon := "":  # icône dessinée à gauche du texte (play, replay, home…)
	set(v):
		if v != lead_icon:
			lead_icon = v
			queue_redraw()
var icon := "":  # sound_on | sound_off | home | replay | pause | play | gear | help | brush | dojo | hanger | back | bestiary
	set(v):
		if v != icon:
			icon = v
			queue_redraw()
var kanji := "":  # brush : caractère du sceau vermillon posé sur la queue du trait ("" : pas de sceau)
	set(v):
		if v != kanji:
			kanji = v
			queue_redraw()
var reveal := 1.0:  # brush : part du trait déjà posée (0..1), pour l'encre qui arrive
	set(v):
		if v != reveal:
			reveal = v
			queue_redraw()
var accent := false:  # text : en vermillon, souligné plein (confirmation attendue)
	set(v):
		if v != accent:
			accent = v
			queue_redraw()
var font: Font:
	set(v):
		font = v
		queue_redraw()
var font_size := 34:
	set(v):
		if v != font_size:
			font_size = v
			queue_redraw()
var shimmer := false  # brush : reflet d'encre humide qui passe sur le trait au repos (JOUER de l'accueil)
var danger := false:  # label : action qui fait perdre la partie (QUITTER) : contour et puce vermillon
	set(v):
		if v != danger:
			danger = v
			queue_redraw()
var _down := false
var _appear := APPEAR_T  # temps réel depuis l'apparition (le pinceau se pose, puis la légende)
var _splash := -1.0  # temps réel depuis l'appui (éclaboussure d'encre), -1 : aucune
var _splash_p := Vector2.ZERO
var _splash_sd := 0.0
var _press := 0.0
var _life := 0.0  # temps réel (respiration du coup de pinceau)
var _rev := -1  # thème d'interface dessiné (Toon.ui_rev)
var _hole := Toon.WASHI  # découpes des pictogrammes (engrenage, porte) : couleur du fond
var _box := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box.set_corner_radius_all(999)
	_box.anti_aliasing = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			_appear = 0.0  # le pinceau se repose à chaque apparition
			queue_redraw()
		else:
			# caché pendant un appui : on oublie l'appui
			_down = false
			_press = 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_splash = 0.0
			_splash_p = event.position
			_splash_sd = fmod(float(Time.get_ticks_msec()) * 0.37, 6.28)
			accept_event()
		elif _down:
			_down = false
			accept_event()
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _rev != Toon.ui_rev:
		_rev = Toon.ui_rev
		queue_redraw()
	var dt := UiKit.real_delta()
	if _appear < APPEAR_T:
		_appear = minf(_appear + dt, APPEAR_T)
		queue_redraw()
	if _splash >= 0.0:
		_splash += dt
		if _splash > SPLASH_T:
			_splash = -1.0
		queue_redraw()
	var target := 1.0 if _down else 0.0
	if _press != target:
		_press = move_toward(_press, target, UiKit.real_delta() * 12.0)
		queue_redraw()
	if style == "brush":
		_life += UiKit.real_delta()
		queue_redraw()


func _draw() -> void:
	var _pt := Time.get_ticks_usec() if Perf.on else 0
	var k := 1.0 - 0.04 * _press
	var r := Rect2(size * (1.0 - k) / 2.0, size * k)
	var rad := int(minf(r.size.y * 0.34, 22.0 * r.size.y / 60.0))
	_box.set_corner_radius_all(rad)
	_box.set_border_width_all(0)
	_box.shadow_size = 0
	_hole = Toon.WASHI
	match style:
		"primary":
			# ombre portée, corps d'encre, reflet haut, liseré vermillon à gauche
			_box.bg_color = Color(0, 0, 0, 0.28)
			draw_style_box(_box, Rect2(r.position + Vector2(0, 5 * (1.0 - _press)), r.size))
			_box.bg_color = Toon.SUMI.lightened(0.06 * (1.0 - _press))
			draw_style_box(_box, r)
			draw_rect(Rect2(r.position + Vector2(rad, 2), Vector2(r.size.x - rad * 2, 2)), Color(1, 1, 1, 0.08))
			draw_rect(Rect2(r.position + Vector2(maxf(8.0, rad * 0.6), r.size.y * 0.3), Vector2(3, r.size.y * 0.4)), Toon.VERMILION)
			_label(r, Toon.WASHI)
		"ghost":
			_hole = Toon.ui_wash
			_box.bg_color = Color(Toon.ui_wash, 0.92)
			_box.border_color = Color(Toon.ui_ink, 0.85)
			_box.set_border_width_all(2)
			draw_style_box(_box, r)
			_label(r, Toon.ui_ink)
		"round":
			# même disque que les boutons retour dessinés par les écrans (UiKit.icon_disc)
			var c := r.get_center()
			var rr := minf(r.size.x, r.size.y) / 2.0
			_hole = Toon.ui_wash
			UiKit.icon_disc(self, c, rr, Toon.ui_ink, Toon.ui_wash)
			_icon(icon, c, rr * UiKit.ICON_GLYPH, Toon.ui_ink)
		"brush":
			_draw_brush()
		"text":
			_draw_text(r)
		"icon":
			_draw_icon_entry(r)
		"bare":
			# icône nue sur un lavis léger, cerclée d'un ensō fin
			var c2 := r.get_center()
			var rr2 := minf(r.size.x, r.size.y) / 2.0
			_hole = Toon.ui_wash
			# apparition : l'ensō se trace, puis l'icône ; l'appui l'épaissit
			var ks := _k_stroke()
			draw_circle(c2, rr2 * 0.86, Color(Toon.ui_wash, (0.5 + 0.35 * _press) * ks))
			var ring: Color = Toon.VERMILION if _press > 0.05 else Color(Toon.ui_ink, 0.4)
			if ks > 0.02:
				UiKit.enso(self, c2, rr2 * 0.82, maxf(1.5, rr2 * (0.1 + 0.05 * _press)), ring, ks, -PI * 0.3)
			_icon(icon, c2, rr2 * 0.42, Color(Toon.ui_ink, _k_label()))
		"area":
			# zone tactile : le dessin est fait par l'écran ; seul l'appui se voit
			if _press > 0.01:
				_box.set_corner_radius_all(int(minf(r.size.y * 0.3, 18.0)))
				_box.bg_color = Color(Toon.ui_ink, 0.08 * _press)
				draw_style_box(_box, r)
		"label":
			_draw_label_tag(r)
	_draw_splash()
	if _pt != 0:
		Perf.add(&"button_draw", _pt)


# étiquette papier du bouton secondaire (UI v2, Pause : OPTIONS / QUITTER), gabarit 162 × 46 : courbes de Bézier
const LABEL_PATH := [Vector2(10, 5), Vector2(50, 1), Vector2(110, 2), Vector2(150, 5), Vector2(158, 6), Vector2(161, 13),
	Vector2(160, 23), Vector2(159, 34), Vector2(157, 41), Vector2(149, 42), Vector2(100, 45), Vector2(50, 44),
	Vector2(12, 42), Vector2(4, 41), Vector2(1, 34), Vector2(2, 23), Vector2(2, 13), Vector2(4, 6), Vector2(10, 5)]
# sortie (QUITTER), gabarit 32 : porte ouverte et flèche
const EXIT_PATH := "M13 5 H6 V27 H13 M19 10 L25 16 L19 22 M25 16 H12"


## Contour de l'étiquette (LABEL_PATH) étiré dans r.
func _label_points(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var sc := Vector2(r.size.x / 162.0, r.size.y / 46.0)
	var p0: Vector2 = LABEL_PATH[0]
	pts.append(r.position + p0 * sc)
	var i := 1
	while i + 2 < LABEL_PATH.size():
		var a: Vector2 = LABEL_PATH[i - 1]
		var b: Vector2 = LABEL_PATH[i]
		var c: Vector2 = LABEL_PATH[i + 1]
		var d: Vector2 = LABEL_PATH[i + 2]
		for k in range(1, 9):
			var t := float(k) / 8.0
			var mt := 1.0 - t
			var q := a * mt * mt * mt + b * 3.0 * mt * mt * t + c * 3.0 * mt * t * t + d * t * t * t
			pts.append(r.position + q * sc)
		i += 3
	pts.remove_at(pts.size() - 1)  # le dernier point refait le premier : pas de sommet en double
	return pts


## Bouton secondaire « étiquette » (planche Boutons) : papier au bord de pinceau, puce ronde à pictogramme à gauche,
## mot en capitales. danger : contour, puce et mot vermillon (QUITTER) ; appui : étiquette d'encre, puce vermillon ;
## accent (armée : confirmation attendue) : étiquette pleine de vermillon, coche dans une puce d'encre.
func _draw_label_tag(r: Rect2) -> void:
	var k := r.size.y / 46.0
	var ink: Color = Toon.ui_ink
	var pressed := _press > 0.05 and not accent
	var line: Color = Toon.VERMILION if danger else ink
	var paper: Color = Toon.ui_paper.lightened(0.06) if Toon.ui_dark else Toon.PAPER
	var fill: Color = paper
	if accent:
		fill = Toon.VERMILION
		line = Toon.SUMI
	elif pressed:
		fill = Toon.SUMI
		line = Toon.SUMI
	var pts := _label_points(r)
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, line, maxf(1.5, 2.5 * k), true)
	# puce : disque d'encre (vermillon si danger ou à l'appui), pictogramme papier ; coche quand l'étiquette est armée
	var dc := Vector2(r.position.x + 8.0 * k + 15.0 * k, r.get_center().y)
	var disc: Color = Toon.SUMI
	if pressed or (danger and not accent):
		disc = Toon.VERMILION
	var glyph_col: Color = Toon.WASHI
	draw_circle(dc, 15.0 * k, disc)
	var isz := 16.0 * k
	if accent:
		UiKit.draw_path(self, "M8 16 L14 22 L24 10", 32, dc, isz, glyph_col, 3.2)
		_label_tag_text(r, dc, k, Toon.WASHI)
		return
	match icon:
		"gear":
			UiKit.draw_icon(self, "interface/reglages", dc, isz, 1.0, glyph_col)
		"replay":
			UiKit.draw_icon(self, "interface/relancer", dc, isz, 1.0, glyph_col)
		"home":
			UiKit.draw_icon(self, "interface/maison", dc, isz, 1.0, glyph_col)
		"quit":
			UiKit.draw_path(self, EXIT_PATH, 32, dc, isz, glyph_col, 3.0)
		_:
			_icon(icon, dc, isz * 0.45, glyph_col)
	var tc: Color = ink
	if pressed:
		tc = Toon.WASHI
	elif danger:
		tc = Toon.VERMILION.darkened(0.15)
	_label_tag_text(r, dc, k, tc)


## Mot de l'étiquette, à droite de sa puce (rétréci s'il déborde).
func _label_tag_text(r: Rect2, dc: Vector2, k: float, tc: Color) -> void:
	if text == "" or font == null or font_size <= 0:
		return
	var x := dc.x + 15.0 * k + 10.0 * k
	var room := r.end.x - 8.0 * k - x
	var fs := font_size
	while fs > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	draw_string(font, Vector2(x, r.get_center().y + (asc - desc) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tc, tc.a * _k_label()))


## Apparition : le trait se pose vite (_k_stroke), la légende suit (_k_label), de 0 à 1.
func _k_stroke() -> float:
	return UiKit.ease_out(clampf(_appear / (APPEAR_T * 0.6), 0.0, 1.0))


func _k_label() -> float:
	return clampf((_appear - APPEAR_T * 0.4) / (APPEAR_T * 0.6), 0.0, 1.0)


## Appui : gouttes d'encre projetées autour du doigt, qui s'étalent puis sèchent (temps réel).
func _draw_splash() -> void:
	if _splash < 0.0 or style == "area":
		return
	var e := clampf(_splash / SPLASH_T, 0.0, 1.0)
	var r0 := minf(size.x, size.y) * 0.5
	var ink: Color = Toon.ui_ink.lerp(Toon.VERMILION, 0.25)
	var fade := 1.0 - e * e
	for i in 6:
		var ang := _splash_sd + TAU * float(i) / 6.0 + 0.4 * sin(_splash_sd * 3.0 + float(i) * 1.9)
		var far := r0 * (0.35 + 0.25 * absf(sin(float(i) * 2.3 + _splash_sd))) * UiKit.ease_out(e)
		var p := _splash_p + Vector2.from_angle(ang) * far
		var rad := r0 * (0.07 - 0.015 * float(i % 3)) * (1.0 - 0.4 * e)
		draw_circle(p, maxf(0.8, rad), Color(ink, 0.55 * fade))
	draw_circle(_splash_p, maxf(0.8, r0 * 0.12 * (1.0 - 0.5 * e)), Color(ink, 0.3 * fade))


## Coup de pinceau : lavis qui respire autour, trait d'encre posé de gauche à droite (reveal),
## stries de pinceau sec dans la queue, sceau vermillon facultatif, texte en papier.
func _draw_brush() -> void:
	var rv := clampf(reveal, 0.0, 1.0)
	if size.x < 8.0 or rv <= 0.04:
		return
	var ink: Color = Toon.ui_ink.lerp(Toon.VERMILION, 0.12 * _press)
	var paper: Color = Toon.ui_paper
	var breath := 0.5 + 0.5 * sin(_life * 2.2)
	var sw := 1.0 + 0.012 * breath  # le trait respire à peine
	var thick := size.y * 0.05 * _press  # le trait se charge d'encre à l'appui
	var body := Rect2(Vector2(size.x * (1.0 - sw) / 2.0, 3.0 * _press - thick), Vector2(size.x * sw, size.y + thick * 2.0))
	var hh := body.size.y * 0.5
	# lavis qui saigne autour du trait
	var halo := body.grow_individual(size.x * 0.03, hh * (0.22 + 0.08 * breath), size.x * 0.05, hh * (0.22 + 0.08 * breath))
	draw_colored_polygon(UiKit.swash_points(halo, rv, 3.0), Color(ink, (0.06 + 0.05 * breath) * rv))
	# ombre, puis le trait
	var pts := UiKit.swash_points(body, rv, 1.0)
	var drop := Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0, 5.0 * (1.0 - _press)))
	draw_colored_polygon(drop * pts, Color(0, 0, 0, 0.2 * rv))
	draw_colored_polygon(pts, ink)
	# encre humide (JOUER) : un reflet de papier glisse le long du haut du trait toutes les 4 s
	if shimmer and rv >= 1.0:
		var ph := fmod(_life, 4.0) / 1.1
		if ph < 1.0:
			var gl := PackedVector2Array()
			for m in 8:
				var t := clampf(lerpf(-0.12, 1.0, ph) + 0.12 * float(m) / 7.0, 0.04, 0.9)
				gl.append(UiKit.swash_mid(body, t) - Vector2(0, hh * 0.42 * UiKit.swash_half(t)))
			draw_polyline(gl, Color(paper, 0.22 * sin(PI * ph)), maxf(1.0, hh * 0.09), true)
	# pinceau sec : stries de papier dans la queue, poils qui dépassent au bout
	var tail_end := minf(rv, 0.97)
	if tail_end > 0.66:
		for j in 4:
			var f := -0.6 + 0.4 * float(j)
			var t0 := 0.64 + 0.05 * absf(sin(float(j) * 1.7))
			if t0 >= tail_end:
				continue
			var line := PackedVector2Array()
			for m in 6:
				var t := lerpf(t0, tail_end, float(m) / 5.0)
				var mid := UiKit.swash_mid(body, t)
				line.append(mid + Vector2(0, f * hh * UiKit.swash_half(t)))
			draw_polyline(line, Color(paper, 0.2), maxf(1.0, hh * 0.035), true)
	if rv >= 1.0:
		for j in 3:
			var off := (float(j) - 1.0) * hh * 0.07
			var a0 := UiKit.swash_mid(body, 0.96) + Vector2(0, off)
			draw_line(a0, a0 + Vector2(body.size.x * (0.03 + 0.012 * float(j)), off * 0.4), Color(ink, 0.5), maxf(1.0, hh * 0.04), true)
	# éclaboussures près de la tête
	if rv > 0.2:
		draw_circle(body.position + Vector2(-hh * 0.12, hh * 1.62), maxf(1.0, hh * 0.06), Color(ink, 0.7))
		draw_circle(body.position + Vector2(hh * 0.18, hh * 1.82), maxf(0.8, hh * 0.035), Color(ink, 0.55))
	# sceau vermillon posé sur la queue (s'abat quand le trait est presque fini)
	var cx := body.position.x + body.size.x * 0.47
	if kanji != "":
		cx = body.position.x + body.size.x * 0.43
		var sk := clampf((rv - 0.8) / 0.2, 0.0, 1.0)
		if sk > 0.0:
			var s := size.y * 0.5
			var sc := 1.0 + 0.4 * (1.0 - UiKit.ease_out(sk))
			var at := UiKit.swash_mid(body, 0.82) + Vector2(0, hh * 0.32)
			draw_set_transform(at, -0.07, Vector2(sc, sc))
			var ch := kanji
			if not UiKit.TITLE_FONT.has_char(ch.unicode_at(0)):
				ch = ""  # caractère absent de la police réduite : un triangle à la place
			UiKit.hanko(self, Rect2(Vector2(-s, -s) / 2.0, Vector2(s, s)), ch, Toon.VERMILION, Toon.WASHI, sk, s / 30.0, 2.0)
			if ch == "":
				_icon("play", Vector2.ZERO, s * 0.24, Color(Toon.WASHI, sk))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var la := clampf((rv - 0.5) / 0.35, 0.0, 1.0)
	if la > 0.0:
		_label_at(cx, body.get_center().y - hh * 0.1, Color(paper, la))


## Texte seul, souligné d'un trait de pinceau qui s'allonge à l'appui.
func _draw_text(r: Rect2) -> void:
	_hole = Toon.ui_wash
	var col: Color = Toon.VERMILION if accent else Toon.ui_ink
	var cy := r.get_center().y - font_size * 0.12
	_label_at(r.get_center().x, cy, Color(col, col.a * _k_label()))
	var tw := _label_width()
	var full := 1.0 if accent else 0.3 + 0.7 * _press
	var ww := tw * full * _k_stroke()
	if ww > 2.0:
		# souligné posé de gauche à droite à l'apparition, plus chargé à l'appui
		var uy := cy + font_size * 0.66
		var uc: Color = Toon.VERMILION if (accent or _press > 0.05) else Color(Toon.ui_ink, 0.45)
		var x0 := r.get_center().x - tw * full / 2.0
		UiKit.brush_line(self, Vector2(x0, uy), Vector2(x0 + ww, uy), maxf(2.0, font_size * (0.17 + 0.05 * _press)), uc)


## Entrée à icône : pictogramme dans un ensō, légende dessous ; l'ensō rougit et se ferme à l'appui.
func _draw_icon_entry(r: Rect2) -> void:
	_hole = Toon.ui_wash
	var fs := font_size
	var lab_h := float(fs) * 1.4 if text != "" else 0.0
	var c := Vector2(r.get_center().x, r.position.y + (r.size.y - lab_h) * 0.5)
	var s := minf((r.size.y - lab_h) * 0.27, r.size.x * 0.22)
	# apparition : l'ensō se trace, puis le pictogramme et la légende
	var ks := _k_stroke()
	var kl := _k_label()
	draw_circle(c, s * 1.5, Color(Toon.ui_wash, (0.35 + 0.3 * _press) * ks))
	var ring: Color = Color(Toon.VERMILION, 0.55 + 0.45 * _press) if _press > 0.05 else Color(Toon.ui_ink, 0.32)
	if ks > 0.02:
		UiKit.enso(self, c, s * 1.5, maxf(1.5, s * (0.16 + 0.08 * _press)), ring, (0.9 + 0.1 * _press) * ks, -PI * 0.35)
	_icon(icon, c, s, Color(Toon.ui_ink, kl))
	if text != "" and font != null and fs > 0:
		UiKit.text(self, font, text, Vector2(r.get_center().x, r.end.y - float(fs) * 0.3), fs, Color(Toon.ui_ink, 0.85 * kl))


## Largeur du texte et de son icône de tête.
func _label_width() -> float:
	if text == "" or font == null or font_size <= 0:
		return 0.0
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if lead_icon != "":
		w += font_size * 0.42 * 3.4
	return w


func _label(r: Rect2, c: Color) -> void:
	_label_at(r.get_center().x, r.get_center().y, c)


## Texte (et icône de tête) centré sur (cx, cy).
func _label_at(cx: float, cy: float, c: Color) -> void:
	if text == "" or font == null or font_size <= 0:
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var asc := font.get_ascent(font_size)
	var desc := font.get_descent(font_size)
	var isz := font_size * 0.42
	var lead := isz * 3.4 if lead_icon != "" else 0.0
	var x := cx - (w + lead) / 2.0
	if lead_icon != "":
		_icon(lead_icon, Vector2(x + isz, cy), isz, c)
	var pos := Vector2(x + lead, cy + (asc - desc) / 2.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)


func _icon(kind: String, c: Vector2, s: float, ink: Color) -> void:
	match kind:
		"sound_on", "sound_off":
			var body := PackedVector2Array([c + Vector2(-s, -s * 0.4), c + Vector2(-s * 0.45, -s * 0.4),
				c + Vector2(s * 0.15, -s), c + Vector2(s * 0.15, s), c + Vector2(-s * 0.45, s * 0.4), c + Vector2(-s, s * 0.4)])
			draw_colored_polygon(body, ink)
			if kind == "sound_on":
				draw_arc(c + Vector2(s * 0.2, 0), s * 0.55, -0.9, 0.9, 12, ink, s * 0.18, true)
				draw_arc(c + Vector2(s * 0.2, 0), s * 0.95, -0.9, 0.9, 16, ink, s * 0.18, true)
			else:
				draw_line(c + Vector2(s * 0.45, -s * 0.45), c + Vector2(s * 1.1, s * 0.45), Toon.VERMILION, s * 0.2, true)
				draw_line(c + Vector2(s * 0.45, s * 0.45), c + Vector2(s * 1.1, -s * 0.45), Toon.VERMILION, s * 0.2, true)
		"pause":
			draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.7), Vector2(s * 0.42, s * 1.4)), ink)
			draw_rect(Rect2(c + Vector2(s * 0.18, -s * 0.7), Vector2(s * 0.42, s * 1.4)), ink)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.75), c + Vector2(s * 0.75, 0), c + Vector2(-s * 0.5, s * 0.75)]), ink)
		"gear":
			for k in 8:
				var ang := TAU * k / 8.0
				draw_line(c + Vector2.from_angle(ang) * s * 0.55, c + Vector2.from_angle(ang) * s * 0.95, ink, s * 0.32, true)
			draw_circle(c, s * 0.62, ink)
			draw_circle(c, s * 0.26, _hole)
		"help":
			var fs := int(s * 2.0)
			if font and fs > 0:
				var qw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, c + Vector2(-qw / 2.0, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		"replay":
			draw_arc(c, s * 0.8, -0.3, PI * 1.55, 20, ink, s * 0.24, true)
			var tip := c + Vector2.from_angle(-0.3) * s * 0.8
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.45, -s * 0.15), tip + Vector2(s * 0.35, -s * 0.35), tip + Vector2(0, s * 0.4)]), ink)
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.05), c + Vector2(0, -s), c + Vector2(s, -s * 0.05)]), ink)
			draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 0.95)), ink)
			draw_rect(Rect2(c + Vector2(-s * 0.18, s * 0.3), Vector2(s * 0.36, s * 0.55)), _hole)
		"brush":
			# Atelier : le pinceau et son trait
			UiKit.glyph(self, "at_brush", c, s, ink, _hole)
		"dojo":
			# Dojo : le torii (plus de kanji dans l'interface)
			UiKit.glyph(self, "torii", c, s * 1.15, ink, _hole)
		"hanger":
			UiKit.hanger_icon(self, c, s * 1.15, ink)
		"bestiary":
			# Bestiaire : le rouleau des yōkai
			UiKit.scroll_icon(self, c, s * 1.1, ink, _hole)
		"back":
			# retour : flèche vermillon (même dessin que UiKit.back_button)
			UiKit.back_arrow(self, c, s, Toon.VERMILION)
