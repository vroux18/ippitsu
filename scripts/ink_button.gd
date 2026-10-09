extends Control
## Bouton dessiné : principal (encre, liseré vermillon), secondaire clair (ghost), rond à icône,
## coup de pinceau (brush), texte souligné au pinceau (text), icône et légende (icon), icône nue (bare)
## ou simple zone tactile (area). Une icône peut accompagner le texte (lead_icon).
## Ne se redessine que si quelque chose change (sauf le coup de pinceau, qui respire).

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

signal pressed

var text := "":
	set(v):
		if v != text:
			text = v
			queue_redraw()
var style := "primary":  # primary | ghost | round | brush | text | icon | bare | area
	set(v):
		if v != style:
			style = v
			queue_redraw()
var lead_icon := "":  # icône dessinée à gauche du texte (play, replay, home…)
	set(v):
		if v != lead_icon:
			lead_icon = v
			queue_redraw()
var icon := "":  # sound_on | sound_off | home | replay | pause | play | gear | help | brush | dojo | hanger | back
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
var _down := false
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
			queue_redraw()
		else:
			# caché pendant un appui : on oublie l'appui
			_down = false
			_press = 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
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
	var target := 1.0 if _down else 0.0
	if _press != target:
		_press = move_toward(_press, target, UiKit.real_delta() * 12.0)
		queue_redraw()
	if style == "brush":
		_life += UiKit.real_delta()
		queue_redraw()


func _draw() -> void:
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
			draw_circle(c2, rr2 * 0.86, Color(Toon.ui_wash, 0.5 + 0.35 * _press))
			var ring: Color = Toon.VERMILION if _press > 0.05 else Color(Toon.ui_ink, 0.4)
			UiKit.enso(self, c2, rr2 * 0.82, maxf(1.5, rr2 * 0.1), ring, 1.0, -PI * 0.3)
			_icon(icon, c2, rr2 * 0.42, Toon.ui_ink)
		"area":
			# zone tactile : le dessin est fait par l'écran ; seul l'appui se voit
			if _press > 0.01:
				_box.set_corner_radius_all(int(minf(r.size.y * 0.3, 18.0)))
				_box.bg_color = Color(Toon.ui_ink, 0.08 * _press)
				draw_style_box(_box, r)


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
	var body := Rect2(Vector2(size.x * (1.0 - sw) / 2.0, 3.0 * _press), Vector2(size.x * sw, size.y))
	var hh := body.size.y * 0.5
	# lavis qui saigne autour du trait
	var halo := body.grow_individual(size.x * 0.03, hh * (0.22 + 0.08 * breath), size.x * 0.05, hh * (0.22 + 0.08 * breath))
	draw_colored_polygon(UiKit.swash_points(halo, rv, 3.0), Color(ink, (0.06 + 0.05 * breath) * rv))
	# ombre, puis le trait
	var pts := UiKit.swash_points(body, rv, 1.0)
	var drop := Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0, 5.0 * (1.0 - _press)))
	draw_colored_polygon(drop * pts, Color(0, 0, 0, 0.2 * rv))
	draw_colored_polygon(pts, ink)
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
	_label_at(r.get_center().x, cy, col)
	var tw := _label_width()
	var k := 1.0 if accent else 0.3 + 0.7 * _press
	var ww := tw * k
	if ww > 2.0:
		var uy := cy + font_size * 0.66
		var uc: Color = Toon.VERMILION if (accent or _press > 0.05) else Color(Toon.ui_ink, 0.45)
		UiKit.brush_line(self, Vector2(r.get_center().x - ww / 2.0, uy), Vector2(r.get_center().x + ww / 2.0, uy), maxf(2.0, font_size * 0.17), uc)


## Entrée à icône : pictogramme dans un ensō, légende dessous ; l'ensō rougit et se ferme à l'appui.
func _draw_icon_entry(r: Rect2) -> void:
	_hole = Toon.ui_wash
	var fs := font_size
	var lab_h := float(fs) * 1.4 if text != "" else 0.0
	var c := Vector2(r.get_center().x, r.position.y + (r.size.y - lab_h) * 0.5)
	var s := minf((r.size.y - lab_h) * 0.27, r.size.x * 0.22)
	draw_circle(c, s * 1.5, Color(Toon.ui_wash, 0.35 + 0.3 * _press))
	var ring: Color = Color(Toon.VERMILION, 0.55 + 0.45 * _press) if _press > 0.05 else Color(Toon.ui_ink, 0.32)
	UiKit.enso(self, c, s * 1.5, maxf(1.5, s * (0.16 + 0.08 * _press)), ring, 0.9 + 0.1 * _press, -PI * 0.35)
	_icon(icon, c, s, Toon.ui_ink)
	if text != "" and font != null and fs > 0:
		UiKit.text(self, font, text, Vector2(r.get_center().x, r.end.y - float(fs) * 0.3), fs, Color(Toon.ui_ink, 0.85))


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
			# Dojo : le caractère 道 (la Voie)
			var dfs := int(s * 1.75)
			if dfs > 0:
				UiKit.text(self, UiKit.TITLE_FONT, "道", c + Vector2(0, dfs * 0.36), dfs, ink)
		"hanger":
			UiKit.hanger_icon(self, c, s * 1.15, ink)
		"back":
			# retour : flèche vermillon (même dessin que UiKit.back_button)
			UiKit.back_arrow(self, c, s, Toon.VERMILION)
