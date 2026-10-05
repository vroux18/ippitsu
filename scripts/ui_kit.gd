extends RefCounted
## Petits outils partagés par les écrans dessinés : polices, texte sans macrons, horloge réelle,
## courbe d'arrivée, texte centré et StyleBoxFlat réutilisée.

const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")

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
