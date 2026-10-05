extends Control
## Interface dessinée à la main : vies, jauge d'élan au pinceau, vague, écran de mort.

const Toon = preload("res://scripts/toon.gd")

var hp := 5
var max_hp := 5
var elan := 1.0
var elan_empty := false
var wave := 1
var slow := 0.0  # 0 = temps normal, 1 = ralenti total
var hurt_flash := 0.0
var game_over := false
var over_t := 0.0
var best_wave := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	if hurt_flash > 0.0:
		hurt_flash = maxf(0.0, hurt_flash - delta * 2.5)
	if game_over:
		over_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	if sz.x < 10.0:
		return
	var u := sz.x / 400.0  # unité relative à la largeur

	# voile du ralenti : bords qui s'assombrissent légèrement
	if slow > 0.01:
		var c := Color(Toon.SUMI, 0.16 * slow)
		var b := 28.0 * u
		draw_rect(Rect2(0, 0, sz.x, b), c)
		draw_rect(Rect2(0, sz.y - b, sz.x, b), c)
		draw_rect(Rect2(0, b, b * 0.6, sz.y - 2 * b), c)
		draw_rect(Rect2(sz.x - b * 0.6, b, b * 0.6, sz.y - 2 * b), c)

	# vies : petits sceaux vermillon
	for i in max_hp:
		var p := Vector2(22 * u + i * 24 * u, 34 * u)
		if i < hp:
			draw_circle(p, 8.5 * u, Toon.VERMILION)
		else:
			draw_arc(p, 8.0 * u, 0, TAU, 20, Color(Toon.SUMI, 0.35), 2.0 * u)

	# numéro de vague
	var font := get_theme_default_font()
	var fs := int(26 * u)
	var txt := str(wave)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_circle(Vector2(sz.x - 30 * u, 32 * u), 17 * u, Toon.SUMI)
	draw_string(font, Vector2(sz.x - 30 * u - tw / 2.0, 32 * u + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Toon.WASHI)

	# jauge d'élan : un trait de pinceau qui se remplit
	var gw := sz.x * 0.62
	var gh := 12.0 * u
	var gx := (sz.x - gw) / 2.0
	var gy := sz.y - 48.0 * u
	_brush_bar(Vector2(gx, gy), gw, gh, 1.0, Color(Toon.SUMI, 0.15))
	var col := Toon.SUMI
	if elan_empty:
		col = Toon.VERMILION if (Time.get_ticks_msec() / 90) % 2 == 0 else Toon.SUMI
	_brush_bar(Vector2(gx, gy), gw, gh, elan, col)

	# coup reçu : liseré vermillon
	if hurt_flash > 0.0:
		var hc := Color(Toon.VERMILION, 0.45 * hurt_flash)
		var hb := 14.0 * u
		draw_rect(Rect2(0, 0, sz.x, hb), hc)
		draw_rect(Rect2(0, sz.y - hb, sz.x, hb), hc)
		draw_rect(Rect2(0, 0, hb, sz.y), hc)
		draw_rect(Rect2(sz.x - hb, 0, hb, sz.y), hc)

	if game_over:
		_draw_game_over(sz, u, font)


func _brush_bar(pos: Vector2, w: float, h: float, fill: float, c: Color) -> void:
	if fill <= 0.001:
		return
	var pts := PackedVector2Array()
	var n := 24
	var fw := w * clampf(fill, 0.0, 1.0)
	for i in n + 1:
		var k := float(i) / n
		var th := h * (0.55 + 0.45 * sin(PI * minf(1.0, k * 1.1 + 0.05)))
		pts.append(pos + Vector2(fw * k, h / 2.0 - th / 2.0))
	for i in range(n, -1, -1):
		var k := float(i) / n
		var th := h * (0.55 + 0.45 * sin(PI * minf(1.0, k * 1.1 + 0.05)))
		pts.append(pos + Vector2(fw * k, h / 2.0 + th / 2.0))
	draw_colored_polygon(pts, c)


func _draw_game_over(sz: Vector2, u: float, font: Font) -> void:
	var a := clampf(over_t / 0.6, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, sz), Color(Toon.WASHI, 0.82 * a))
	# ensō vermillon tracé progressivement
	var c := sz / 2.0 - Vector2(0, 40 * u)
	var sweep := TAU * 0.92 * clampf((over_t - 0.2) / 0.7, 0.0, 1.0)
	if sweep > 0.01:
		draw_arc(c, 80 * u, -PI / 2.0, -PI / 2.0 + sweep, 64, Toon.VERMILION, 14 * u, true)
	var fs := int(64 * u)
	var txt := str(best_wave)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-tw / 2.0, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.SUMI, a))
