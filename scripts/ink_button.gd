extends Control
## Bouton dessiné : pilule d'encre (principal), contour (secondaire) ou rond à icône.

const Toon = preload("res://scripts/toon.gd")

signal pressed

var text := ""
var style := "primary"  # primary | ghost | round
var icon := ""  # sound_on | sound_off | home | replay
var font: Font
var font_size := 34
var _down := false
var _press := 0.0
var _box := StyleBoxFlat.new()


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
	var real := delta / maxf(Engine.time_scale, 0.01)
	_press = move_toward(_press, 1.0 if _down else 0.0, real * 12.0)
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - 0.05 * _press
	var r := Rect2(size * (1.0 - k) / 2.0, size * k)
	match style:
		"primary":
			_box.bg_color = Color(Toon.SUMI, 0.22)
			_box.border_width_left = 0
			_box.border_width_right = 0
			_box.border_width_top = 0
			_box.border_width_bottom = 0
			draw_style_box(_box, Rect2(r.position + Vector2(0, 7 * (1.0 - _press)), r.size))
			_box.bg_color = Toon.SUMI
			draw_style_box(_box, r)
			# petit coup de vermillon sur le bord gauche
			draw_circle(r.position + Vector2(r.size.y * 0.5, r.size.y * 0.5), r.size.y * 0.13, Toon.VERMILION)
			_label(r, Toon.WASHI)
		"ghost":
			_box.bg_color = Color(Toon.WASHI, 0.65)
			_box.border_color = Toon.SUMI
			_box.set_border_width_all(3)
			draw_style_box(_box, r)
			_label(r, Toon.SUMI)
		"round":
			var c := r.get_center()
			var rad := minf(r.size.x, r.size.y) / 2.0
			draw_circle(c, rad, Color(Toon.WASHI, 0.85))
			draw_arc(c, rad - 1.5, 0, TAU, 40, Color(Toon.SUMI, 0.85), 3.0, true)
			_icon(c, rad * 0.5)


func _label(r: Rect2, c: Color) -> void:
	if text == "" or font == null:
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var asc := font.get_ascent(font_size)
	var desc := font.get_descent(font_size)
	var pos := Vector2(r.get_center().x - w / 2.0, r.get_center().y + (asc - desc) / 2.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)


func _icon(c: Vector2, s: float) -> void:
	var ink := Toon.SUMI
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
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.05), c + Vector2(0, -s), c + Vector2(s, -s * 0.05)]), ink)
			draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 0.95)), ink)
			draw_rect(Rect2(c + Vector2(-s * 0.18, s * 0.3), Vector2(s * 0.36, s * 0.55)), Toon.WASHI)
