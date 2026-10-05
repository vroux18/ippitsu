extends Control
## Accueil (titre, sceau, Jouer, Atelier, son), écran de résultats en fin de partie, et pause.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")

signal play_pressed
signal home_pressed
signal sound_toggled(muted: bool)
signal atelier_pressed
signal worlds_pressed
signal resume_pressed

var mode := "home"  # home | over | pause | hidden
var best := 0
var last := 0
var new_record := false
var victory := false
var muted := false
var sumi := 0  # encre (monnaie permanente), affichée sur l'accueil
var gain_sumi := 0  # encre gagnée à la dernière partie
var gain_seals := 0
# résultats de la partie (écran de fin)
var stat_room := 0
var stat_kills := 0
var stat_combo := 0
var stat_time := 0.0
var world_name := ""
var world_kanji := "波"
var world_color := Toon.PRUSSIAN

var _t := 0.0  # temps réel depuis l'affichage
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _play: Control
var _replay: Control
var _home: Control
var _sound: Control
var _atelier: Control
var _worlds: Control
var _resume: Control
var _quit: Control


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
	_worlds = _button("MONDES", "ghost")
	_worlds.pressed.connect(func(): worlds_pressed.emit())
	_resume = _button("REPRENDRE", "primary")
	_resume.pressed.connect(func(): resume_pressed.emit())
	_quit = _button("ABANDONNER", "ghost")
	_quit.pressed.connect(func(): home_pressed.emit())
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
	_t += _real_delta()
	var w := size.x
	var h := size.y
	var u := w / 400.0

	_play.visible = mode == "home"
	_replay.visible = mode == "over" and _t > 0.9
	_home.visible = mode == "over" and _t > 0.9
	_worlds.visible = mode == "over" and _t > 0.9
	_resume.visible = mode == "pause"
	_quit.visible = mode == "pause"
	_sound.visible = mode == "home" or mode == "pause"
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

	var over_in := _ease_out(clampf((_t - 0.9) / 0.4, 0.0, 1.0))
	var by := h * 0.77 + 20.0 * u * (1.0 - over_in)
	_replay.size = Vector2(bw, bh)
	_replay.position = Vector2((w - bw) / 2.0, by)
	_replay.modulate.a = over_in
	_replay.font_size = int(26 * u)
	_worlds.size = Vector2(w * 0.36, 46 * u)
	_worlds.position = Vector2(w / 2.0 - w * 0.36 - 6 * u, by + bh + 14 * u)
	_worlds.modulate.a = over_in
	_worlds.font_size = int(16 * u)
	_home.size = Vector2(46, 46) * u
	_home.position = Vector2(w / 2.0 + 6 * u, by + bh + 14 * u)
	_home.modulate.a = over_in
	# pause
	_resume.size = Vector2(bw, bh)
	_resume.position = Vector2((w - bw) / 2.0, h * 0.5)
	_resume.font_size = int(24 * u)
	_quit.size = Vector2(w * 0.5, 46 * u)
	_quit.position = Vector2((w - w * 0.5) / 2.0, h * 0.5 + bh + 16 * u)
	_quit.font_size = int(15 * u)

	_sound.size = Vector2(44, 44) * u
	_sound.position = Vector2(w - 60 * u, 22 * u) if mode == "home" else Vector2((w - 44 * u) / 2.0, h * 0.5 + bh + 80 * u)
	queue_redraw()


func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func _draw() -> void:
	if size.x < 10.0:
		return
	if mode == "home":
		_draw_home()
	elif mode == "over":
		_draw_results()
	elif mode == "pause":
		_draw_pause()


func _text(font: Font, txt: String, center: Vector2, fs: int, c: Color) -> float:
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(center.x - tw / 2.0, center.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return tw


func _draw_home() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0

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
	# compteur d'encre (par-dessus le voile du haut)
	_draw_ink_counter(Vector2(20, 30) * u, u)


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


## Écran de fin : la feuille de résultats posée sur le jeu délavé.
func _draw_results() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var a := _ease_out(clampf(_t / 0.5, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.WASHI, 0.6 * a))
	var card := Rect2(Vector2(w * 0.08, h * 0.12 + 30 * u * (1.0 - a)), Vector2(w * 0.84, h * 0.6))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Toon.SUMI, 0.2 * a)
	sb.set_corner_radius_all(int(12 * u))
	draw_style_box(sb, Rect2(card.position + Vector2(0, 8 * u), card.size))
	sb.bg_color = Color(Color("#F6F0E2"), a)
	sb.border_color = Color(Toon.SUMI, a)
	sb.set_border_width_all(int(2.5 * u))
	draw_style_box(sb, card)
	var cx := card.get_center().x
	# ensō et titre
	var ec := Vector2(cx, card.position.y + 62 * u)
	var sweep := TAU * 0.9 * clampf((_t - 0.15) / 0.6, 0.0, 1.0)
	var ring_col := Toon.GOLD if victory else Toon.VERMILION
	if sweep > 0.01:
		draw_arc(ec, 38 * u, -PI / 2.0, -PI / 2.0 + sweep, 48, Color(ring_col, a), 8 * u, true)
	_text(TITLE_FONT, world_kanji, ec + Vector2(0, 12 * u), int(32 * u), Color(Toon.SUMI, a))
	_text(_title, "VICTOIRE" if victory else "DÉFAITE", Vector2(cx, card.position.y + 140 * u), int(34 * u), Color(ring_col if victory else Toon.SUMI, a))
	_text(_ui, world_name.to_upper(), Vector2(cx, card.position.y + 164 * u), int(12 * u), Color(Toon.SUMI, 0.55 * a))
	# statistiques en deux colonnes
	var rows := [["SALLE", "%d / 9" % stat_room], ["ENNEMIS", str(stat_kills)], ["CHAÎNE MAX", str(stat_combo)], ["TEMPS", "%d:%02d" % [int(stat_time) / 60, int(stat_time) % 60]]]
	for i in rows.size():
		var col := i % 2
		var row := i / 2
		var k := _ease_out(clampf((_t - 0.3 - 0.08 * i) / 0.35, 0.0, 1.0))
		var p := Vector2(card.position.x + card.size.x * (0.27 + 0.46 * col), card.position.y + 214 * u + row * 62 * u)
		_text(_ui, String(rows[i][0]), p, int(11 * u), Color(Toon.SUMI, 0.5 * k * a))
		_text(TITLE_FONT, String(rows[i][1]), p + Vector2(0, 30 * u), int(26 * u), Color(Toon.SUMI, k * a))
	# trait d'encre puis gains
	var ly := card.position.y + 352 * u
	draw_line(Vector2(card.position.x + 30 * u, ly), Vector2(card.end.x - 30 * u, ly), Color(Toon.SUMI, 0.2 * a), 2 * u)
	var gk := _ease_out(clampf((_t - 0.7) / 0.4, 0.0, 1.0))
	var g := "+%d  ENCRE" % gain_sumi
	if gain_seals > 0:
		g += "    +%d  SCEAU" % gain_seals
	var gw := _ui.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * u)).x
	var gp := Vector2(cx - gw / 2.0 + 10 * u, ly + 34 * u)
	var stick := Rect2(gp + Vector2(-22, -16) * u, Vector2(9, 22) * u)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(Toon.SUMI, gk)
	ss.border_color = Color(Toon.GOLD, gk)
	ss.set_border_width_all(int(maxf(1.0, 1.5 * u)))
	draw_style_box(ss, stick)
	draw_string(_ui, gp, g, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * u), Color(Toon.SUMI, gk * a))
	if new_record:
		_text(_ui, "NOUVEAU RECORD", Vector2(cx, ly + 62 * u), int(12 * u), Color(Toon.GOLD, gk * a))


## Pause : le jeu figé sous un voile d'encre.
func _draw_pause() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.SUMI, 0.55))
	_text(_title, "PAUSE", Vector2(w / 2.0, h * 0.36), int(44 * u), Toon.WASHI)
	_text(TITLE_FONT, world_kanji, Vector2(w / 2.0, h * 0.27), int(30 * u), world_color.lightened(0.3))

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


var _last_ms := 0


## Temps réel écoulé (indépendant du ralenti et de la pause).
func _real_delta() -> float:
	var now := Time.get_ticks_msec()
	var d := 0.0 if _last_ms == 0 else (now - _last_ms) / 1000.0
	_last_ms = now
	return minf(d, 0.1)
