extends Control
## Accueil (titre, sceau, bouton Jouer, record, son) et boutons de fin de partie.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")

signal play_pressed
signal home_pressed
signal sound_toggled(muted: bool)
signal atelier_pressed

var mode := "home"  # home | over | hidden
var best := 0
var last := 0
var new_record := false
var victory := false
var muted := false
var sumi := 0  # encre (monnaie permanente), affichée sur l'accueil
var gain_sumi := 0  # encre gagnée à la dernière partie
var gain_seals := 0

var _t := 0.0  # temps réel depuis l'affichage
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _play: Control
var _replay: Control
var _home: Control
var _sound: Control
var _atelier: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.base_font = TITLE_FONT
	_title.spacing_glyph = 6
	_ui.base_font = UI_FONT
	_ui.spacing_glyph = 4

	_play = _button("JOUER", "primary")
	_play.pressed.connect(func(): play_pressed.emit())
	_replay = _button("REJOUER", "primary")
	_replay.pressed.connect(func(): play_pressed.emit())
	_home = _button("", "round")
	_home.icon = "home"
	_home.pressed.connect(func(): home_pressed.emit())
	_atelier = _button("ATELIER", "ghost")
	_atelier.pressed.connect(func(): atelier_pressed.emit())
	_sound = _button("", "round")
	_sound.pressed.connect(_toggle_sound)
	show_mode("home")


func _button(label: String, style: String) -> Control:
	var b := InkButton.new()
	b.text = label
	b.style = style
	b.font = _ui
	add_child(b)
	return b


func _toggle_sound() -> void:
	muted = not muted
	sound_toggled.emit(muted)


func show_mode(m: String) -> void:
	mode = m
	_t = 0.0
	visible = m != "hidden"


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	_t += delta / maxf(Engine.time_scale, 0.01)
	var w := size.x
	var h := size.y
	var u := w / 400.0

	_play.visible = mode == "home"
	_replay.visible = mode == "over" and _t > 1.1
	_home.visible = mode == "over" and _t > 1.1
	_sound.visible = mode == "home"
	_atelier.visible = mode == "home"
	_sound.icon = "sound_off" if muted else "sound_on"

	var bw := w * 0.6
	var bh := 64.0 * u
	var appear := _ease_out(clampf((_t - 0.55) / 0.5, 0.0, 1.0))
	_play.size = Vector2(bw, bh)
	_play.position = Vector2((w - bw) / 2.0, h * 0.76 + 30.0 * u * (1.0 - appear))
	_play.modulate.a = appear
	_play.font_size = int(26 * u)
	_atelier.size = Vector2(w * 0.42, 46.0 * u)
	_atelier.position = Vector2((w - w * 0.42) / 2.0, h * 0.76 + bh + 14.0 * u + 30.0 * u * (1.0 - appear))
	_atelier.modulate.a = appear
	_atelier.font_size = int(17 * u)

	var over_in := _ease_out(clampf((_t - 1.1) / 0.4, 0.0, 1.0))
	_replay.size = Vector2(bw, bh)
	_replay.position = Vector2((w - bw) / 2.0, h * 0.7 + 20.0 * u * (1.0 - over_in))
	_replay.modulate.a = over_in
	_replay.font_size = int(26 * u)
	_home.size = Vector2(52, 52) * u
	_home.position = Vector2((w - 52 * u) / 2.0, h * 0.7 + bh + 22 * u)
	_home.modulate.a = over_in

	_sound.size = Vector2(44, 44) * u
	_sound.position = Vector2(w - 60 * u, 22 * u)
	queue_redraw()


func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func _draw() -> void:
	if size.x < 10.0:
		return
	if mode == "home":
		_draw_home()
	elif mode == "over" and _t > 1.1:
		_draw_over()


func _text(font: Font, txt: String, center: Vector2, fs: int, c: Color) -> float:
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(center.x - tw / 2.0, center.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return tw


func _draw_home() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	_draw_ink_counter(Vector2(20, 30) * u, u)

	# voile washi en haut (lisibilité du titre) et en bas (bouton)
	var top := PackedColorArray([Color(Toon.WASHI, 0.95), Color(Toon.WASHI, 0.95), Color(Toon.WASHI, 0.0), Color(Toon.WASHI, 0.0)])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.34), Vector2(0, h * 0.34)]), top)
	var bot := PackedColorArray([Color(Toon.WASHI, 0.0), Color(Toon.WASHI, 0.0), Color(Toon.WASHI, 0.92), Color(Toon.WASHI, 0.92)])
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.66), Vector2(w, h * 0.66), Vector2(w, h), Vector2(0, h)]), bot)

	var a := _ease_out(clampf(_t / 0.6, 0.0, 1.0))

	# sceau vermillon « 一筆 »
	var seal := Rect2(Vector2(w / 2.0 - 22 * u, h * 0.05 - 8 * u * (1.0 - a)), Vector2(44, 66) * u)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Toon.VERMILION, a)
	sb.set_corner_radius_all(int(8 * u))
	draw_style_box(sb, seal)
	var kfs := int(26 * u)
	_text(TITLE_FONT, "一", Vector2(seal.get_center().x, seal.position.y + 30 * u), kfs, Color(Toon.WASHI, a))
	_text(TITLE_FONT, "筆", Vector2(seal.get_center().x, seal.position.y + 58 * u), kfs, Color(Toon.WASHI, a))

	# titre
	var ty := h * 0.235
	var tfs := int(66 * u)
	var tw := _text(_title, "IPPITSU", Vector2(w / 2.0, ty + 10 * u * (1.0 - a)), tfs, Color(Toon.SUMI, a))

	# coup de pinceau vermillon qui tranche le titre
	var k := _ease_out(clampf((_t - 0.35) / 0.35, 0.0, 1.0))
	if k > 0.0:
		var p0 := Vector2(w / 2.0 - tw / 2.0 - 18 * u, ty - 6 * u)
		var p1 := Vector2(w / 2.0 + tw / 2.0 + 18 * u, ty - 40 * u)
		_brush(p0, p0.lerp(p1, k), 9.0 * u, Toon.VERMILION)

	# accroche
	_text(_ui, "UN SEUL TRAIT", Vector2(w / 2.0, ty + 42 * u), int(13 * u), Color(Toon.SUMI, 0.65 * a))

	# record
	if best > 0:
		var ra := _ease_out(clampf((_t - 0.8) / 0.5, 0.0, 1.0))
		_text(_ui, "RECORD  ·  SALLE %d / 9" % best, Vector2(w / 2.0, h * 0.76 + 64 * u + 14 * u + 46 * u + 30 * u), int(12 * u), Color(Toon.SUMI, 0.6 * ra))

	# halo qui respire autour du bouton
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	var r := Rect2(_play.position, _play.size).grow(6 * u + 6 * u * pulse)
	var halo := StyleBoxFlat.new()
	halo.bg_color = Color(0, 0, 0, 0)
	halo.border_color = Color(Toon.SUMI, 0.12 * (1.0 - pulse) * _play.modulate.a)
	halo.set_border_width_all(int(2 * u))
	halo.set_corner_radius_all(999)
	draw_style_box(halo, r)


## Compteur d'encre : un bâton d'encre et le nombre.
func _draw_ink_counter(p: Vector2, u: float) -> void:
	var stick := Rect2(p + Vector2(0, -12) * u, Vector2(9, 24) * u)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Toon.SUMI
	sb.border_color = Toon.GOLD
	sb.set_border_width_all(int(maxf(1.0, 1.5 * u)))
	sb.set_corner_radius_all(int(2 * u))
	draw_style_box(sb, stick)
	var fs := int(17 * u)
	draw_string(_ui, p + Vector2(16, 6) * u, str(sumi), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Toon.SUMI)


func _draw_over() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var a := _ease_out(clampf((_t - 1.1) / 0.4, 0.0, 1.0))
	var txt := "NOUVEAU RECORD" if new_record else "RECORD  ·  SALLE %d / 9" % best
	if victory:
		txt = "VICTOIRE"
	var c := Toon.GOLD if new_record or victory else Color(Toon.SUMI, 0.6)
	_text(_ui, txt, Vector2(w / 2.0, h * 0.7 - 26 * u), int(13 * u), Color(c, c.a * a))
	# encre gagnée pendant la partie
	if gain_sumi > 0 or gain_seals > 0:
		var g := "+%d  ENCRE" % gain_sumi
		if gain_seals > 0:
			g += "   ·   +%d  SCEAU" % gain_seals
		_text(_ui, g, Vector2(w / 2.0, h * 0.7 - 50 * u), int(13 * u), Color(Toon.SUMI, 0.75 * a))


func _brush(p0: Vector2, p1: Vector2, wdt: float, c: Color) -> void:
	var d := p1 - p0
	if d.length() < 1.0:
		return
	var n := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(p0 + d * t + n * wdt * (0.35 + 0.65 * sin(PI * minf(1.0, t * 1.2))) * (1.0 - 0.6 * t))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		pts.append(p0 + d * t - n * wdt * (0.35 + 0.65 * sin(PI * minf(1.0, t * 1.2))) * (1.0 - 0.6 * t))
	draw_colored_polygon(pts, c)
