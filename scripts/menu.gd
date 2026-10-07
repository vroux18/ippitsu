extends Control
## Accueil (titre, sceau, Jouer, Atelier, son), écran de résultats en fin de partie, et pause.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const PowerData = preload("res://scripts/power_data.gd")
const Meta = preload("res://scripts/meta.gd")
const GOLD_INK := Color("#9A6B12")  # or lisible sur le papier
# feuille de résultats : hauteurs des blocs (× u) et sceaux par ligne
const HEAD_H := 164.0
const STATS_H := 62.0
const FIG_H := 80.0
const BTN_H := 132.0  # bas de l'écran réservé aux boutons
const PER_ROW := 10
# auteur du coup fatal (type d'ennemi), pour « VAINCU PAR … »
const KILLER_NAMES := {"oni": "un oni", "brute": "une brute", "kappa": "un kappa", "tate": "un porte-bouclier",
	"funa": "un funayūrei", "umibozu": "un umibōzu", "kitsunebi": "un kitsunebi", "kitsunebi_s": "un feu follet",
	"yukionna": "une yuki-onna", "kasha": "un kasha", "kagebo": "ton double d'encre"}

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
var stat_shapes := {}  # figure -> nombre réalisé
var build := {}  # pouvoir -> niveau (powers.levels)
var affinities := {}  # école -> [nombre de pouvoirs, palier] (powers.affinities())
var new_prints: Array = []  # Vues gagnées à cette partie (ids de meta.PRINTS)
var killer_kind := ""  # type d'ennemi du coup fatal (vide : inconnu ou boss)
var killer_name := ""  # nom du boss du coup fatal
var _build_list: Array = []  # [id du pouvoir, couleur d'école, niveau, couleur de rareté, rang, niveau max, ordre d'école]
var _over_atelier: Control

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
	_home = _button("ACCUEIL", "ghost")
	_home.lead_icon = "home"
	_home.pressed.connect(func(): home_pressed.emit())
	_over_atelier = _button("ATELIER", "ghost")
	_over_atelier.pressed.connect(func(): atelier_pressed.emit())
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
	if m == "over":
		_make_build_list()


## Sceaux du build, les plus rares d'abord, puis par école.
func _make_build_list() -> void:
	_build_list = []
	for id in build.keys():
		var pd: Dictionary = PowerData.POWERS.get(String(id), {})
		var lv := int(build[id])
		if pd.is_empty() or lv <= 0:
			continue
		var sid := String(pd.get("school", ""))
		var school: Dictionary = PowerData.SCHOOLS.get(sid, {})
		var rar: Dictionary = PowerData.RARITIES.get(String(pd.get("rarity", "common")), {})
		_build_list.append([String(id), school.get("color", Toon.SUMI), lv,
			rar.get("color", Color(0.6, 0.6, 0.6)), int(rar.get("rank", 0)), int(pd.get("max", 3)), PowerData.SCHOOL_ORDER.find(sid)])
	_build_list.sort_custom(func(x, y): return int(x[4]) > int(y[4]) or (int(x[4]) == int(y[4]) and int(x[6]) < int(y[6])))


func _build_rows() -> int:
	var n := mini(_build_list.size(), PER_ROW * 2)
	return int(ceil(float(n) / float(PER_ROW)))


func _process(_delta: float) -> void:
	if not visible or mode == "hidden":
		return
	size = get_viewport_rect().size
	_t += UiKit.real_delta()
	var w := size.x
	var h := size.y
	var u := w / 400.0

	_play.visible = mode == "home"
	_replay.visible = mode == "over" and _t > 0.45
	_home.visible = mode == "over" and _t > 0.45
	_over_atelier.visible = mode == "over" and _t > 0.45
	_worlds.visible = false
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

	# fin de partie : REJOUER, puis ATELIER et ACCUEIL côte à côte (touches bloquées les 0,6 premières secondes)
	var over_in := UiKit.ease_out(clampf((_t - 0.45) / 0.35, 0.0, 1.0))
	var obw := w * 0.68
	var ox := (w - obw) / 2.0
	var by := h - BTN_H * u + 20.0 * u * (1.0 - over_in)
	_replay.size = Vector2(obw, 56 * u)
	_replay.position = Vector2(ox, by)
	_replay.modulate.a = over_in
	_replay.font_size = int(24 * u)
	var hw := (obw - 10 * u) / 2.0
	_over_atelier.size = Vector2(hw, 44 * u)
	_over_atelier.position = Vector2(ox, by + 66 * u)
	_over_atelier.modulate.a = over_in
	_over_atelier.font_size = int(15 * u)
	_home.size = Vector2(hw, 44 * u)
	_home.position = Vector2(ox + hw + 10 * u, by + 66 * u)
	_home.modulate.a = over_in
	_home.font_size = int(15 * u)
	var live := mode == "over" and _t >= 0.6
	for b in [_replay, _over_atelier, _home]:
		var bc: Control = b
		if live:
			bc.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
## Titre, chiffres de la partie, build, figures, puis les gains révélés un à un.
func _draw_results() -> void:
	var w := size.x
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.45, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.WASHI, 0.72 * a))
	var lay := _results_layout(u)
	var v: float = lay["v"]
	var card := Rect2(Vector2(14 * u, float(lay["top"]) + 24 * u * (1.0 - a)), Vector2(w - 28 * u, float(lay["height"])))
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.2 * a), int(12 * u)), Rect2(card.position + Vector2(0, 8 * u), card.size))
	draw_style_box(UiKit.box(_sb, Color(Toon.PAPER, a), int(12 * u), Color(Toon.SUMI, a), int(2.5 * u)), card)
	# bande de couleur du monde en haut de la feuille
	UiKit.box(_sb, Color(world_color, a))
	_sb.corner_radius_top_left = int(10 * u)
	_sb.corner_radius_top_right = int(10 * u)
	draw_style_box(_sb, Rect2(card.position + Vector2(2.5, 2.5) * u, Vector2(card.size.x - 5 * u, 6 * u)))
	var x0 := card.position.x + 18 * u
	var x1 := card.end.x - 18 * u
	var y := card.position.y
	_draw_head(card, y, u, v, a)
	y += HEAD_H * v
	_draw_stats(x0, x1, y, u, v, a)
	y += STATS_H * v
	_draw_build(x0, x1, y, u, v, a)
	y += float(lay["build_h"]) * v
	_draw_figures(x0, x1, y, u, v, a)
	y += FIG_H * v
	_draw_gains(x0, x1, y, u, v, a)
	if new_record:
		_draw_record_stamp(Vector2(card.end.x - 52 * u, card.position.y + 46 * v), u, a)


## Hauteurs de la feuille (selon le build et les Vues gagnées), resserrées si l'écran est court.
func _results_layout(u: float) -> Dictionary:
	var rows := _build_rows()
	var build_h := 50.0
	if rows > 0:
		build_h = 28.0 + 38.0 * rows + (26.0 if not affinities.is_empty() else 0.0)
	var gains_h := 56.0 + 42.0 * mini(new_prints.size(), 3)
	var content := HEAD_H + STATS_H + build_h + FIG_H + gains_h + 12.0
	var avail := size.y / u - 14.0 - BTN_H - 12.0
	var k := clampf(avail / content, 0.72, 1.0)
	var top := 14.0 + maxf(0.0, avail - content) * 0.35
	return {"v": u * k, "top": top * u, "height": content * u * k, "build_h": build_h}


## Titre de section : petit mot puis filet jusqu'au bord.
func _section(label: String, x0: float, x1: float, y: float, u: float, a: float) -> void:
	var fs := int(10 * u)
	draw_string(_ui, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.SUMI, 0.55 * a))
	var tw := _ui.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_line(Vector2(x0 + tw + 6 * u, y - fs * 0.35), Vector2(x1, y - fs * 0.35), Color(Toon.SUMI, 0.15 * a), 1.5 * u)


## Ensō (plein en victoire, à la mesure des salles franchies sinon), titre et sous-titres.
func _draw_head(card: Rect2, y: float, u: float, v: float, a: float) -> void:
	var cx := card.get_center().x
	var ec := Vector2(cx, y + 52 * v)
	var ring_col := Toon.GOLD if victory else Toon.VERMILION
	var prog := 1.0
	if not victory:
		prog = clampf(float(stat_room) / float(maxi(rooms_total, 1)), 0.08, 1.0)
	var full := TAU * 0.92
	draw_arc(ec, 30 * u, -PI / 2.0, -PI / 2.0 + full, 48, Color(Toon.SUMI, 0.08 * a), 7 * u, true)
	var sweep := full * prog * UiKit.ease_out(clampf((_t - 0.15) / 0.7, 0.0, 1.0))
	if sweep > 0.01:
		draw_arc(ec, 30 * u, -PI / 2.0, -PI / 2.0 + sweep, 48, Color(ring_col, a), 7 * u, true)
	UiKit.text(self, UiKit.TITLE_FONT, world_kanji, ec + Vector2(0, 10 * u), int(28 * u), Color(Toon.SUMI, a))
	var kh := UiKit.ease_out(clampf((_t - 0.25) / 0.35, 0.0, 1.0))
	var hy := y + 118 * v + 8 * u * (1.0 - kh)
	var wn := UiKit.plain(world_name.to_upper())
	if victory:
		UiKit.text(self, _title, "VICTOIRE", Vector2(cx, hy), int(34 * u), Color(GOLD_INK, a * kh))
		UiKit.text(self, _ui, wn, Vector2(cx, y + 142 * v), int(12 * u), Color(Toon.SUMI, 0.6 * a * kh))
	else:
		UiKit.text(self, UiKit.TITLE_FONT, "Tombé en salle %d" % stat_room, Vector2(cx, hy), int(28 * u), Color(Toon.SUMI, a * kh))
		UiKit.text(self, _ui, wn, Vector2(cx, y + 138 * v), int(11 * u), Color(Toon.SUMI, 0.5 * a * kh))
		var kl := _killer_line()
		if kl != "":
			UiKit.text(self, _ui, kl, Vector2(cx, y + 155 * v), int(11 * u), Color(Toon.VERMILION, a * kh))


## « VAINCU PAR … » (vide si l'auteur du coup fatal est inconnu).
func _killer_line() -> String:
	var who := ""
	if killer_name != "":
		who = killer_name
	elif killer_kind != "":
		who = String(KILLER_NAMES.get(killer_kind, ""))
	if who == "":
		return ""
	return UiKit.plain(("vaincu par " + who).to_upper())


## Rangée de chiffres : salle, ennemis, chaîne max, temps, figures.
func _draw_stats(x0: float, x1: float, y: float, u: float, v: float, a: float) -> void:
	var figs := 0
	for f in stat_shapes.keys():
		figs += int(stat_shapes[f])
	var cols := [["SALLE", "%d/%d" % [stat_room, rooms_total]], ["ENNEMIS", str(stat_kills)], ["CHAÎNE MAX", str(stat_combo)],
		["TEMPS", "%d:%02d" % [int(stat_time) / 60, int(stat_time) % 60]], ["FIGURES", str(figs)]]
	var cw := (x1 - x0) / float(cols.size())
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.05 * a), int(10 * u)), Rect2(Vector2(x0 - 6 * u, y + 2 * v), Vector2(x1 - x0 + 12 * u, 50 * v)))
	for i in cols.size():
		var k := UiKit.ease_out(clampf((_t - 0.4 - 0.07 * i) / 0.35, 0.0, 1.0))
		var c := x0 + cw * (i + 0.5)
		var col: Array = cols[i]
		UiKit.text(self, UiKit.UI_FONT, String(col[0]), Vector2(c, y + 19 * v), int(9.5 * u), Color(Toon.SUMI, 0.5 * a * k))
		UiKit.text(self, UiKit.TITLE_FONT, String(col[1]), Vector2(c, y + 43 * v + 6 * u * (1.0 - k)), int(19 * u), Color(Toon.SUMI, a * k))
		if i > 0:
			draw_line(Vector2(x0 + cw * i, y + 11 * v), Vector2(x0 + cw * i, y + 45 * v), Color(Toon.SUMI, 0.12 * a), 1.5 * u)


## Ton build : sceaux des pouvoirs (liseré de rareté, points de niveau), puis les affinités d'école.
func _draw_build(x0: float, x1: float, y: float, u: float, v: float, a: float) -> void:
	var cx := (x0 + x1) / 2.0
	var hk := UiKit.ease_out(clampf((_t - 0.6) / 0.3, 0.0, 1.0))
	_section("TON BUILD", x0, x1, y + 13 * v, u, a * hk)
	var n := _build_list.size()
	if n == 0:
		UiKit.text(self, _ui, "AUCUN ROULEAU", Vector2(cx, y + 42 * v), int(11 * u), Color(Toon.SUMI, 0.4 * a * hk))
		return
	var r := 12.0 * u
	var step := 33.0 * u
	var shown := mini(n, PER_ROW * 2)
	for i in shown:
		var row := i / PER_ROW
		var in_row := mini(PER_ROW, shown - row * PER_ROW)
		var col := i % PER_ROW
		var c := Vector2(cx + (col - (in_row - 1) / 2.0) * step, y + 38 * v + row * 38 * v)
		var k := UiKit.ease_out(clampf((_t - 0.7 - 0.035 * i) / 0.25, 0.0, 1.0))
		if k <= 0.0:
			continue
		var ka := a * k
		var rr := r * (0.6 + 0.4 * k)
		if i == shown - 1 and n > shown:
			# trop de rouleaux : le dernier sceau compte le reste
			draw_circle(c, rr, Color(Toon.SUMI, 0.8 * ka))
			UiKit.text(self, UiKit.UI_FONT, "+%d" % (n - shown + 1), c + Vector2(0, 4 * u), int(11 * u), Color(Toon.WASHI, ka))
			continue
		var sd: Array = _build_list[i]
		var rc: Color = sd[3]
		var glow := 0.0
		if int(sd[4]) >= 3:
			glow = 0.35 + 0.25 * sin(_t * 3.0)
		draw_circle(c, rr + 3 * u + glow * 2 * u, Color(rc, 0.95 * ka))
		# pictogramme du pouvoir sur la couleur de son école
		UiKit.power_icon(self, String(sd[0]), c, rr, ka)
		# niveau : points sous le sceau, dorés au niveau max
		var lv := int(sd[2])
		var dot := Color(GOLD_INK if lv >= int(sd[5]) else Toon.SUMI, ka)
		for d in lv:
			draw_circle(c + Vector2((d - (lv - 1) / 2.0) * 5.0 * u, r + 7.5 * u), 1.7 * u, dot)
	if affinities.is_empty():
		return
	# affinités : une pastille par école (pleine quand un palier est atteint)
	var chy := y + 38 * v * _build_rows() + 34 * v
	var chips: Array = []
	for s in PowerData.SCHOOL_ORDER:
		if affinities.has(s) and chips.size() < 4:
			chips.append(String(s))
	var fs2 := int(10 * u)
	var widths: Array = []
	var total := -8.0 * u
	for s in chips:
		var wch := 30.0 * u + UiKit.UI_FONT.get_string_size(_aff_label(String(s)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		widths.append(wch)
		total += wch + 8.0 * u
	var px := cx - total / 2.0
	var ck := a * UiKit.ease_out(clampf((_t - 1.0) / 0.3, 0.0, 1.0))
	for i in chips.size():
		var s := String(chips[i])
		var info: Array = affinities[s]
		var tier := int(info[1])
		var sdd: Dictionary = PowerData.SCHOOLS.get(s, {})
		var scol: Color = sdd.get("color", Toon.SUMI)
		var wch: float = widths[i]
		var rect := Rect2(Vector2(px, chy - 10 * u), Vector2(wch, 20 * u))
		if tier > 0:
			draw_style_box(UiKit.box(_sb, Color(scol, ck), int(10 * u)), rect)
		else:
			draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(10 * u), Color(Toon.SUMI, 0.3 * ck), int(maxf(1.0, 1.2 * u))), rect)
		var dc := Vector2(px + 10 * u, chy)
		var disc: Color = Toon.WASHI if tier > 0 else scol
		draw_circle(dc, 7 * u, Color(disc, ck))
		UiKit.school_icon(self, s, dc, 4.6 * u, scol if tier > 0 else Toon.WASHI, ck, disc)
		var tc := Color(Toon.WASHI, ck) if tier > 0 else Color(Toon.SUMI, 0.6 * ck)
		draw_string(UiKit.UI_FONT, Vector2(px + 22 * u, chy + fs2 * 0.36), _aff_label(s), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, tc)
		px += wch + 8 * u


## « FEU II » quand un palier est atteint, sinon « FEU 1/2 ».
func _aff_label(s: String) -> String:
	var sd: Dictionary = PowerData.SCHOOLS.get(s, {})
	var info: Array = affinities.get(s, [0, 0])
	var nm := String(sd.get("name", s.to_upper()))
	var tier := int(info[1])
	if tier > 0:
		return "%s %s" % [nm, "I".repeat(tier)]
	var goal: int = PowerData.AFF_TIERS[0]
	return "%s %d/%d" % [nm, int(info[0]), goal]


## Les six figures et combien de fois chacune a été tracée (la préférée cerclée de vermillon).
func _draw_figures(x0: float, x1: float, y: float, u: float, v: float, a: float) -> void:
	var hk := UiKit.ease_out(clampf((_t - 0.95) / 0.3, 0.0, 1.0))
	_section("FIGURES", x0, x1, y + 13 * v, u, a * hk)
	var fav := ""
	var fav_n := 0
	for f in UiKit.FIGURES:
		var fc := int(stat_shapes.get(String(f), 0))
		if fc > fav_n:
			fav_n = fc
			fav = String(f)
	var step := (x1 - x0) / float(UiKit.FIGURES.size())
	for i in UiKit.FIGURES.size():
		var sh := String(UiKit.FIGURES[i])
		var n := int(stat_shapes.get(sh, 0))
		var k := UiKit.ease_out(clampf((_t - 1.05 - 0.05 * i) / 0.3, 0.0, 1.0))
		if k <= 0.0:
			continue
		var c := Vector2(x0 + step * (i + 0.5), y + 38 * v)
		var fa := a * k * (1.0 if n > 0 else 0.3)
		if sh == fav:
			draw_arc(c, 20 * u, 0.0, TAU, 36, Color(Toon.VERMILION, a * k), 2 * u, true)
		UiKit.figure(self, sh, c, 15 * u * (0.7 + 0.3 * k), fa)
		UiKit.text(self, UiKit.TITLE_FONT, "×%d" % n, Vector2(c.x, y + 72 * v), int(14 * u), Color(Toon.SUMI, fa))


## Gains : l'encre qui monte, les sceaux, puis chaque nouvelle Vue qui glisse en place.
func _draw_gains(x0: float, x1: float, y: float, u: float, v: float, a: float) -> void:
	var hk := UiKit.ease_out(clampf((_t - 1.25) / 0.3, 0.0, 1.0))
	var label := "GAINS"
	if new_prints.size() > 3:
		label = "GAINS  ·  %d VUES" % new_prints.size()
	_section(label, x0, x1, y + 13 * v, u, a * hk)
	var ry := y + 44 * v
	var nfs := int(20 * u)
	var wfs := int(11 * u)
	# encre : le compteur monte jusqu'au gain
	var ik := clampf((_t - 1.35) / 0.9, 0.0, 1.0)
	var ia := a * UiKit.ease_out(clampf((_t - 1.35) / 0.2, 0.0, 1.0))
	if ia > 0.0:
		var num := "+%d" % int(round(float(gain_sumi) * UiKit.ease_out(ik)))
		var nw := UiKit.TITLE_FONT.get_string_size("+%d" % gain_sumi, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var ww := UiKit.UI_FONT.get_string_size("ENCRE", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs).x
		var lx := x0 + (x1 - x0) * 0.27 - (17 * u + nw + 6 * u + ww) / 2.0
		var stick := Rect2(Vector2(lx, ry - 19 * u), Vector2(9, 22) * u)
		draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, ia), int(2 * u), Color(Toon.GOLD, ia), int(maxf(1.0, 1.5 * u))), stick)
		draw_string(UiKit.TITLE_FONT, Vector2(lx + 17 * u, ry), num, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(Toon.SUMI, ia))
		draw_string(UiKit.UI_FONT, Vector2(lx + 23 * u + nw, ry), "ENCRE", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, Color(Toon.SUMI, 0.6 * ia))
	# sceaux : un petit hanko qui se pose
	var sk := UiKit.ease_out(clampf((_t - 1.9) / 0.25, 0.0, 1.0))
	if sk > 0.0:
		var sa := a * sk * (1.0 if gain_seals > 0 else 0.45)
		var stxt := "+%d" % gain_seals
		var sword := "SCEAU" if gain_seals <= 1 else "SCEAUX"
		var sw := UiKit.TITLE_FONT.get_string_size(stxt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var sww := UiKit.UI_FONT.get_string_size(sword, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs).x
		var sx := x0 + (x1 - x0) * 0.73 - (26 * u + sw + 6 * u + sww) / 2.0
		var hs := 18.0 * u * (1.0 + 0.5 * (1.0 - sk))
		var hr := Rect2(Vector2(sx + 9 * u - hs / 2.0, ry - 8 * u - hs / 2.0), Vector2(hs, hs))
		draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, sa), int(4 * u)), hr)
		draw_rect(hr.grow(-4 * u), Color(Toon.WASHI, 0.8 * sa), false, 1.2 * u)
		draw_string(UiKit.TITLE_FONT, Vector2(sx + 26 * u, ry), stxt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(Toon.SUMI, sa))
		draw_string(UiKit.UI_FONT, Vector2(sx + 32 * u + sw, ry), sword, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, Color(Toon.SUMI, 0.6 * sa))
	# nouvelles Vues : vignette, titre et apparence débloquée
	for i in mini(new_prints.size(), 3):
		var pid := String(new_prints[i])
		if not Meta.PRINTS.has(pid):
			continue
		var p: Dictionary = Meta.PRINTS[pid]
		var pk := UiKit.ease_out(clampf((_t - 2.2 - 0.3 * i) / 0.35, 0.0, 1.0))
		if pk <= 0.0:
			continue
		var pa := a * pk
		var top := y + 58 * v + i * 42 * v
		var row := Rect2(Vector2(x0 - 4 * u + 30 * u * (1.0 - pk), top), Vector2(x1 - x0 + 8 * u, 38 * v))
		draw_style_box(UiKit.box(_sb, Color(Toon.GOLD, 0.12 * pa), int(8 * u), Color(Toon.GOLD, 0.6 * pa), int(maxf(1.0, 1.2 * u))), row)
		var th := Rect2(Vector2(row.position.x + 6 * u, top + 4 * v), Vector2(44 * u, 30 * v))
		UiKit.print_thumb(self, th, p, u, pa)
		var tx := th.end.x + 10 * u
		draw_string(UiKit.TITLE_FONT, Vector2(tx, top + 17 * v), UiKit.plain(String(p.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Color(Toon.SUMI, pa))
		var kind := String(p.get("kind", ""))
		var sub := "NOUVELLE APPARENCE"
		if Meta.LOOK_NAMES.has(kind):
			sub += "  ·  " + String(Meta.LOOK_NAMES[kind]).to_upper()
		draw_string(UiKit.UI_FONT, Vector2(tx, top + 31 * v), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Color(GOLD_INK, pa))
		# pastille de la couleur portée
		var lc: Color = p.get("col", Toon.SUMI)
		var dc := Vector2(row.end.x - 16 * u, top + 19 * v)
		draw_circle(dc, 8 * u, Color(Toon.SUMI, 0.8 * pa))
		draw_circle(dc, 6.5 * u, Color(lc, pa))


## Tampon « NOUVEAU RECORD » qui s'abat en haut à droite de la feuille.
func _draw_record_stamp(c: Vector2, u: float, a: float) -> void:
	var k := clampf((_t - 2.0) / 0.22, 0.0, 1.0)
	if k <= 0.0:
		return
	var s := 1.0 + 0.8 * (1.0 - UiKit.ease_out(k))
	var ka := a * k
	draw_set_transform(c, -0.2, Vector2(s, s))
	var r := Rect2(Vector2(-40, -19) * u, Vector2(80, 38) * u)
	draw_style_box(UiKit.box(_sb, Color(Toon.PAPER, 0.85 * ka), int(6 * u), Color(Toon.VERMILION, ka), int(2.5 * u)), r)
	draw_rect(r.grow(-4 * u), Color(Toon.VERMILION, 0.6 * ka), false, 1.0 * u)
	UiKit.text(self, UiKit.UI_FONT, "NOUVEAU", Vector2(0, -2 * u), int(11 * u), Color(Toon.VERMILION, ka))
	UiKit.text(self, UiKit.UI_FONT, "RECORD", Vector2(0, 12 * u), int(11 * u), Color(Toon.VERMILION, ka))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
