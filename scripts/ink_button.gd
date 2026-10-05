extends Control
## Bouton dessiné : principal (encre, liseré vermillon), secondaire clair (ghost), secondaire sur fond sombre (ghost_dark)
## ou rond à icône. Une icône peut accompagner le texte (lead_icon).

const Toon = preload("res://scripts/toon.gd")

signal pressed

var text := ""
var style := "primary"  # primary | ghost | ghost_dark | round
var lead_icon := ""  # icône dessinée à gauche du texte (play, replay, home…)
var icon := ""  # sound_on | sound_off | home | replay
var font: Font
var font_size := 34
var _down := false
var _press := 0.0
var _box := StyleBoxFlat.new()
var _icon_col := Toon.SUMI


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box.set_corner_radius_all(999)
	_box.anti_aliasing = true


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


func _process(delta: float) -> void:
	var real := _real_delta()
	_press = move_toward(_press, 1.0 if _down else 0.0, real * 12.0)
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - 0.04 * _press
	var r := Rect2(size * (1.0 - k) / 2.0, size * k)
	var rad := int(minf(r.size.y * 0.34, 22.0 * r.size.y / 60.0))
	_box.set_corner_radius_all(rad)
	_box.set_border_width_all(0)
	_box.shadow_size = 0
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
			_box.bg_color = Color(Toon.WASHI, 0.92)
			_box.border_color = Color(Toon.SUMI, 0.85)
			_box.set_border_width_all(2)
			draw_style_box(_box, r)
			_label(r, Toon.SUMI)
		"ghost_dark":
			_box.bg_color = Color(1, 1, 1, 0.06 + 0.08 * _press)
			_box.border_color = Color(Toon.WASHI, 0.55)
			_box.set_border_width_all(2)
			draw_style_box(_box, r)
			_label(r, Toon.WASHI)
		"round":
			var c := r.get_center()
			var rr := minf(r.size.x, r.size.y) / 2.0
			draw_circle(c + Vector2(0, 2), rr, Color(0, 0, 0, 0.2))
			draw_circle(c, rr, Color(Toon.WASHI, 0.95))
			draw_arc(c, rr - 1.0, 0, TAU, 40, Color(Toon.SUMI, 0.75), 2.0, true)
			_icon(c, rr * 0.5)

func _label(r: Rect2, c: Color) -> void:
	if text == "" or font == null or font_size <= 0:
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var asc := font.get_ascent(font_size)
	var desc := font.get_descent(font_size)
	var isz := font_size * 0.42
	var lead := isz * 3.4 if lead_icon != "" else 0.0
	var x := r.get_center().x - (w + lead) / 2.0
	if lead_icon != "":
		var keep := icon
		icon = lead_icon
		_icon_col = c
		_icon(Vector2(x + isz, r.get_center().y), isz)
		_icon_col = Toon.SUMI
		icon = keep
	var pos := Vector2(x + lead, r.get_center().y + (asc - desc) / 2.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)


func _icon(c: Vector2, s: float) -> void:
	var ink := _icon_col
	match icon:
		"sound_on", "sound_off":
			var body := PackedVector2Array([c + Vector2(-s, -s * 0.4), c + Vector2(-s * 0.45, -s * 0.4),
				c + Vector2(s * 0.15, -s), c + Vector2(s * 0.15, s), c + Vector2(-s * 0.45, s * 0.4), c + Vector2(-s, s * 0.4)])
			draw_colored_polygon(body, ink)
			if icon == "sound_on":
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
		"map":
			# petit rouleau
			draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.55), Vector2(s * 1.6, s * 1.1)), Color(ink, 0.25))
			draw_rect(Rect2(c + Vector2(-s * 0.95, -s * 0.7), Vector2(s * 0.25, s * 1.4)), ink)
			draw_rect(Rect2(c + Vector2(s * 0.7, -s * 0.7), Vector2(s * 0.25, s * 1.4)), ink)
		"gear":
			for k in 8:
				var ang := TAU * k / 8.0
				draw_line(c + Vector2.from_angle(ang) * s * 0.55, c + Vector2.from_angle(ang) * s * 0.95, ink, s * 0.32, true)
			draw_circle(c, s * 0.62, ink)
			draw_circle(c, s * 0.26, Toon.WASHI)
		"help":
			if font:
				var fs := int(s * 2.0)
				var qw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, c + Vector2(-qw / 2.0, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		"replay":
			draw_arc(c, s * 0.8, -0.3, PI * 1.55, 20, ink, s * 0.24, true)
			var tip := c + Vector2.from_angle(-0.3) * s * 0.8
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.45, -s * 0.15), tip + Vector2(s * 0.35, -s * 0.35), tip + Vector2(0, s * 0.4)]), ink)
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.05), c + Vector2(0, -s), c + Vector2(s, -s * 0.05)]), ink)
			draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 0.95)), ink)
			draw_rect(Rect2(c + Vector2(-s * 0.18, s * 0.3), Vector2(s * 0.36, s * 0.55)), Toon.WASHI)


var _last_ms := 0


## Temps réel écoulé (indépendant du ralenti et de la pause).
func _real_delta() -> float:
	var now := Time.get_ticks_msec()
	var d := 0.0 if _last_ms == 0 else (now - _last_ms) / 1000.0
	_last_ms = now
	return minf(d, 0.1)
