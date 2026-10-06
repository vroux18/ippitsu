extends Control
## Accueil (titre, sceau, Jouer, Atelier, son), écran de résultats en fin de partie, et pause.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

signal play_pressed
signal home_pressed
signal sound_toggled(muted: bool)
signal atelier_pressed
signal worlds_pressed
signal resume_pressed
signal restart_pressed
signal tuto_pressed
signal options_pressed
signal powers_pressed

var mode := "home"  # home | over | pause | hidden
var best := 0
var rooms_total := 15  # salles d'une partie
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
var _restart: Control
var _powers_btn: Control
var _help: Control
var _gear: Control
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 6
	_ui.base_font = UiKit.UI_FONT
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
	_resume.lead_icon = "play"
	_restart = _button("RECOMMENCER", "ghost")
	_restart.lead_icon = "replay"
	_restart.pressed.connect(func(): restart_pressed.emit())
	_powers_btn = _button("MES POUVOIRS", "ghost")
	_powers_btn.pressed.connect(func(): powers_pressed.emit())
	_quit = _button("QUITTER", "ghost")
	_quit.lead_icon = "home"
	_quit.pressed.connect(func(): home_pressed.emit())
	_play.lead_icon = "play"
	_help = _button("", "round")
	_help.icon = "help"
	_help.pressed.connect(func(): tuto_pressed.emit())
	_gear = _button("", "round")
	_gear.icon = "gear"
	_gear.pressed.connect(func(): options_pressed.emit())
	_replay.lead_icon = "replay"
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


func _process(_delta: float) -> void:
	if not visible or mode == "hidden":
		return
	size = get_viewport_rect().size
	_t += UiKit.real_delta()
	var w := size.x
	var h := size.y
	var u := w / 400.0

	_play.visible = mode == "home"
	_replay.visible = mode == "over" and _t > 0.9
	_home.visible = mode == "over" and _t > 0.9
	_worlds.visible = mode == "over" and _t > 0.9
	_resume.visible = mode == "pause"
	_quit.visible = mode == "pause"
	_restart.visible = mode == "pause"
	_powers_btn.visible = mode == "pause"
	_sound.visible = mode == "home" or mode == "pause"
	_atelier.visible = mode == "home"
	_help.visible = mode == "home"
	_gear.visible = mode == "home" or mode == "pause"
	_gear.size = Vector2(40, 40) * u
	_gear.position = Vector2(w - 106 * u, 24 * u) if mode == "home" else Vector2(_pause_card().position.x + 16 * u, _pause_card().position.y + 14 * u)
	_help.size = Vector2(40, 40) * u
	_help.position = Vector2(16 * u, 58 * u)
	_sound.icon = "sound_off" if muted else "sound_on"

	var bw := w * 0.6
	var bh := 64.0 * u
	var appear := UiKit.ease_out(clampf((_t - 0.55) / 0.5, 0.0, 1.0))
	_play.size = Vector2(bw, bh)
	_play.position = Vector2((w - bw) / 2.0, h * 0.76 + 30.0 * u * (1.0 - appear))
	_play.modulate.a = appear
	_play.font_size = int(26 * u)
	_atelier.size = Vector2(w * 0.42, 46.0 * u)
	_atelier.position = Vector2((w - w * 0.42) / 2.0, h * 0.76 + bh + 14.0 * u + 30.0 * u * (1.0 - appear))
	_atelier.modulate.a = appear
	_atelier.font_size = int(17 * u)

	var over_in := UiKit.ease_out(clampf((_t - 0.9) / 0.4, 0.0, 1.0))
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
	# pause : boutons empilés dans la carte
	var pc := _pause_card()
	var pw := pc.size.x - 48 * u
	var px := pc.position.x + 24 * u
	_resume.size = Vector2(pw, 58 * u)
	_resume.position = Vector2(px, pc.position.y + 206 * u)
	_resume.font_size = int(20 * u)
	_powers_btn.size = Vector2(pw, 48 * u)
	_powers_btn.position = Vector2(px, pc.position.y + 276 * u)
	_powers_btn.font_size = int(15 * u)
	_restart.size = Vector2(pw, 48 * u)
	_restart.position = Vector2(px, pc.position.y + 334 * u)
	_restart.font_size = int(15 * u)
	_quit.size = Vector2(pw, 48 * u)
	_quit.position = Vector2(px, pc.position.y + 392 * u)
	_quit.font_size = int(15 * u)

	_sound.size = Vector2(44, 44) * u
	_sound.position = Vector2(w - 60 * u, 22 * u) if mode == "home" else Vector2(pc.end.x - 56 * u, pc.position.y + 14 * u)
	queue_redraw()


func _draw() -> void:
	if size.x < 10.0:
		return
	if mode == "home":
		_draw_home()
	elif mode == "over":
		_draw_results()
	elif mode == "pause":
		_draw_pause()


func _draw_home() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0

	# voile washi en haut (lisibilité du titre) et en bas (bouton)
	var top := PackedColorArray([Color(Toon.WASHI, 0.95), Color(Toon.WASHI, 0.95), Color(Toon.WASHI, 0.0), Color(Toon.WASHI, 0.0)])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.34), Vector2(0, h * 0.34)]), top)
	var bot := PackedColorArray([Color(Toon.WASHI, 0.0), Color(Toon.WASHI, 0.0), Color(Toon.WASHI, 0.92), Color(Toon.WASHI, 0.92)])
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.66), Vector2(w, h * 0.66), Vector2(w, h), Vector2(0, h)]), bot)

	var a := UiKit.ease_out(clampf(_t / 0.6, 0.0, 1.0))

	# sceau vermillon « 一筆 »
	var seal := Rect2(Vector2(w / 2.0 - 22 * u, h * 0.05 - 8 * u * (1.0 - a)), Vector2(44, 66) * u)
	draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, a), int(8 * u)), seal)
	var kfs := int(26 * u)
	UiKit.text(self, UiKit.TITLE_FONT, "一", Vector2(seal.get_center().x, seal.position.y + 30 * u), kfs, Color(Toon.WASHI, a))
	UiKit.text(self, UiKit.TITLE_FONT, "筆", Vector2(seal.get_center().x, seal.position.y + 58 * u), kfs, Color(Toon.WASHI, a))

	# titre
	var ty := h * 0.235
	var tfs := int(66 * u)
	var tw := UiKit.text(self, _title, "IPPITSU", Vector2(w / 2.0, ty + 10 * u * (1.0 - a)), tfs, Color(Toon.SUMI, a))

	# coup de pinceau vermillon qui tranche le titre
	var k := UiKit.ease_out(clampf((_t - 0.35) / 0.35, 0.0, 1.0))
	if k > 0.0:
		var p0 := Vector2(w / 2.0 - tw / 2.0 - 18 * u, ty - 6 * u)
		var p1 := Vector2(w / 2.0 + tw / 2.0 + 18 * u, ty - 40 * u)
		_brush(p0, p0.lerp(p1, k), 9.0 * u, Toon.VERMILION)

	# accroche
	UiKit.text(self, _ui, "UN SEUL TRAIT", Vector2(w / 2.0, ty + 42 * u), int(13 * u), Color(Toon.SUMI, 0.65 * a))

	# record
	if best > 0:
		var ra := UiKit.ease_out(clampf((_t - 0.8) / 0.5, 0.0, 1.0))
		UiKit.text(self, _ui, "RECORD  ·  SALLE %d / %d" % [best, rooms_total], Vector2(w / 2.0, h * 0.76 + 64 * u + 14 * u + 46 * u + 30 * u), int(12 * u), Color(Toon.SUMI, 0.6 * ra))

	# halo qui respire autour du bouton
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	var r := Rect2(_play.position, _play.size).grow(6 * u + 6 * u * pulse)
	draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), 999, Color(Toon.SUMI, 0.12 * (1.0 - pulse) * _play.modulate.a), int(2 * u)), r)
	# compteur d'encre (par-dessus le voile du haut)
	_draw_ink_counter(Vector2(20, 30) * u, u)
	# numéro de version : pour vérifier que l'appli est bien à jour
	var ver := "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	UiKit.text(self, _ui, ver, Vector2(w - 34 * u, h - 12 * u), int(10 * u), Color(Toon.SUMI, 0.45))


## Compteur d'encre : un bâton d'encre et le nombre.
func _draw_ink_counter(p: Vector2, u: float) -> void:
	var stick := Rect2(p + Vector2(0, -12) * u, Vector2(9, 24) * u)
	draw_style_box(UiKit.box(_sb, Toon.SUMI, int(2 * u), Toon.GOLD, int(maxf(1.0, 1.5 * u))), stick)
	var fs := int(17 * u)
	draw_string(_ui, p + Vector2(16, 6) * u, str(sumi), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Toon.SUMI)


## Écran de fin : la feuille de résultats posée sur le jeu délavé.
func _draw_results() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.5, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.WASHI, 0.6 * a))
	var card := Rect2(Vector2(w * 0.08, h * 0.12 + 30 * u * (1.0 - a)), Vector2(w * 0.84, h * 0.6))
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.2 * a), int(12 * u)), Rect2(card.position + Vector2(0, 8 * u), card.size))
	draw_style_box(UiKit.box(_sb, Color(Toon.PAPER, a), int(12 * u), Color(Toon.SUMI, a), int(2.5 * u)), card)
	var cx := card.get_center().x
	# ensō et titre
	var ec := Vector2(cx, card.position.y + 62 * u)
	var sweep := TAU * 0.9 * clampf((_t - 0.15) / 0.6, 0.0, 1.0)
	var ring_col := Toon.GOLD if victory else Toon.VERMILION
	if sweep > 0.01:
		draw_arc(ec, 38 * u, -PI / 2.0, -PI / 2.0 + sweep, 48, Color(ring_col, a), 8 * u, true)
	UiKit.text(self, UiKit.TITLE_FONT, world_kanji, ec + Vector2(0, 12 * u), int(32 * u), Color(Toon.SUMI, a))
	UiKit.text(self, _title, "VICTOIRE" if victory else "DÉFAITE", Vector2(cx, card.position.y + 140 * u), int(34 * u), Color(ring_col if victory else Toon.SUMI, a))
	UiKit.text(self, _ui, world_name.to_upper(), Vector2(cx, card.position.y + 164 * u), int(12 * u), Color(Toon.SUMI, 0.55 * a))
	# statistiques en deux colonnes
	var rows := [["SALLE", "%d / %d" % [stat_room, rooms_total]], ["ENNEMIS", str(stat_kills)], ["CHAÎNE MAX", str(stat_combo)], ["TEMPS", "%d:%02d" % [int(stat_time) / 60, int(stat_time) % 60]]]
	for i in rows.size():
		var col := i % 2
		var row := i / 2
		var k := UiKit.ease_out(clampf((_t - 0.3 - 0.08 * i) / 0.35, 0.0, 1.0))
		var p := Vector2(card.position.x + card.size.x * (0.27 + 0.46 * col), card.position.y + 214 * u + row * 62 * u)
		UiKit.text(self, _ui, String(rows[i][0]), p, int(11 * u), Color(Toon.SUMI, 0.5 * k * a))
		UiKit.text(self, UiKit.TITLE_FONT, String(rows[i][1]), p + Vector2(0, 30 * u), int(26 * u), Color(Toon.SUMI, k * a))
	# trait d'encre puis gains
	var ly := card.position.y + 352 * u
	draw_line(Vector2(card.position.x + 30 * u, ly), Vector2(card.end.x - 30 * u, ly), Color(Toon.SUMI, 0.2 * a), 2 * u)
	var gk := UiKit.ease_out(clampf((_t - 0.7) / 0.4, 0.0, 1.0))
	var g := "+%d  ENCRE" % gain_sumi
	if gain_seals > 0:
		g += "    +%d  SCEAU" % gain_seals
	var gw := _ui.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * u)).x
	var gp := Vector2(cx - gw / 2.0 + 10 * u, ly + 34 * u)
	var stick := Rect2(gp + Vector2(-22, -16) * u, Vector2(9, 22) * u)
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, gk), 0, Color(Toon.GOLD, gk), int(maxf(1.0, 1.5 * u))), stick)
	draw_string(_ui, gp, g, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * u), Color(Toon.SUMI, gk * a))
	if new_record:
		UiKit.text(self, _ui, "NOUVEAU RECORD", Vector2(cx, ly + 62 * u), int(12 * u), Color(Toon.GOLD, gk * a))


## Carte de la pause (au centre de l'écran).
func _pause_card() -> Rect2:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var cw := minf(w * 0.86, 360.0 * u)
	return Rect2(Vector2((w - cw) / 2.0, h * 0.5 - 235 * u), Vector2(cw, 470 * u))


## Pause : voile d'encre, carte de papier avec le sceau du monde, la partie en cours et les boutons.
func _draw_pause() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.25, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.8 * a))
	var card := _pause_card()
	card.position.y += 16 * u * (1.0 - a)
	UiKit.box(_sb, Color(Toon.PAPER, a), int(18 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.5 * a)
	_sb.shadow_size = int(24 * u)
	_sb.shadow_offset = Vector2(0, 8 * u)
	draw_style_box(_sb, card)
	# bande de couleur du monde en haut de la carte
	UiKit.box(_sb, Color(world_color, a))
	_sb.corner_radius_top_left = int(18 * u)
	_sb.corner_radius_top_right = int(18 * u)
	draw_style_box(_sb, Rect2(card.position, Vector2(card.size.x, 8 * u)))
	# sceau et titre
	var seal := Rect2(Vector2(card.get_center().x - 26 * u, card.position.y + 30 * u), Vector2(52, 52) * u)
	draw_style_box(UiKit.box(_sb, Color(world_color, a), int(10 * u)), seal)
	UiKit.text(self, UiKit.TITLE_FONT, world_kanji, Vector2(seal.get_center().x, seal.get_center().y + 13 * u), int(34 * u), Color(Toon.WASHI, a))
	UiKit.text(self, _title, "PAUSE", Vector2(card.get_center().x, card.position.y + 124 * u), int(32 * u), Color(Toon.SUMI, a))
	# la partie en cours
	var cols := [["SALLE", "%d / %d" % [stat_room, rooms_total]], ["CHAÎNE", str(stat_combo)], ["TEMPS", "%d:%02d" % [int(stat_time) / 60, int(stat_time) % 60]]]
	for i in cols.size():
		var cx := card.position.x + card.size.x * (0.2 + 0.3 * i)
		UiKit.text(self, _ui, String(cols[i][0]), Vector2(cx, card.position.y + 156 * u), int(10 * u), Color(Toon.SUMI, 0.5 * a))
		UiKit.text(self, UiKit.TITLE_FONT, String(cols[i][1]), Vector2(cx, card.position.y + 182 * u), int(19 * u), Color(Toon.SUMI, a))
		if i > 0:
			var lx := card.position.x + card.size.x * (0.05 + 0.3 * i)
			draw_line(Vector2(lx, card.position.y + 146 * u), Vector2(lx, card.position.y + 186 * u), Color(Toon.SUMI, 0.12 * a), 1.5 * u)

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
