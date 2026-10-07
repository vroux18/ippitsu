extends RefCounted
## Petits outils partagés par les écrans dessinés : polices, texte sans macrons, horloge réelle,
## courbe d'arrivée, texte centré et StyleBoxFlat réutilisée.

const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")
const Toon = preload("res://scripts/toon.gd")
# les six figures, dans l'ordre d'affichage
const FIGURES := ["straight", "return", "zigzag", "loop", "enso", "hook"]

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
	ci.draw_circle(c, r + 2.5 * r / 30.0, Color(Toon.SUMI, 0.85 * a))
	ci.draw_circle(c, r, Color(Toon.PAPER, 0.95 * a))
	var ink := Color(Toon.SUMI, a)
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
