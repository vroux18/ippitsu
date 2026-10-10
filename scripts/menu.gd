extends Control
## Accueil (sceau, titre, pinceau JOUER, entrées Atelier · Dojo · Garde-robe), résultats en fin de partie, et pause.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const PowerData = preload("res://scripts/power_data.gd")
const Meta = preload("res://scripts/meta.gd")
const Score = preload("res://scripts/score.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
# pictogramme d'un monde d'après son kanji (UI v2 : plus de kanji dans l'interface) : table partagée avec le HUD
# (UIColors.WORLD_ICON). Vague, bambou, neige : planches ; feu, encre, ciel, dragon, enfers : provisoires, à valider.
const WORLD_ICON := UIColors.WORLD_ICON
const GOLD_INK := Color("#9A6B12")  # or lisible sur le papier
# feuille de résultats (× u) : en-tête sumi, bloc score + rang, lignes à sceau ; le bas est réservé aux boutons
const HEADER_H := 64.0
const HEAD_H := 104.0
const ROW_HEIGHTS := {"killer": 74.0, "stats": 50.0, "figures": 50.0, "build": 52.0, "loot": 66.0, "unlock": 86.0, "advice": 60.0}
const VERMILION_LIGHT := Color("#E8574A")  # VAINCU sur l'en-tête sumi (planche Défaite)
const RANK_ICON := ["hud/prunier", "hud/bambou", "hud/pin", "hud/couronne"]  # pictos des rangs (score.gd)
# auteur du coup fatal (type d'ennemi), pour « VAINCU PAR … »
const KILLER_NAMES := {"shinobi": "un shinobi", "shuriken": "un lanceur de shuriken", "kemuri": "un ninja des fumées",
	"kunoichi": "une kunoichi", "oni": "un oni", "brute": "une brute", "kappa": "un kappa", "tate": "un porte-bouclier",
	"funa": "un funayūrei", "umibozu": "un umibōzu", "kitsunebi": "un kitsunebi", "kitsunebi_s": "un feu follet",
	"yukionna": "une yuki-onna", "kasha": "un kasha", "kagebo": "ton double d'encre",
	"kappa_yumi": "un kappa archer", "ika": "un calmar d'encre", "umi_nyobo": "une umi-nyōbō", "kamaitachi": "un kamaitachi",
	"tanuki": "un tanuki", "tanuki_d": "un leurre de tanuki", "kitsune_tsukai": "une prêtresse renarde", "yuki_warashi": "un yuki-warashi",
	"tsurara": "des stalactites", "onryo": "un onryō", "hinotama": "un hinotama", "kanabo": "un oni à massue",
	"tengu": "un tengu", "teppo": "un arquebusier", "sumidama": "une goutte d'encre", "sumidama_s": "une gouttelette d'encre",
	"kasa": "un kasa-obake", "moryo": "un mōryō",
	"karasu": "un karasu-tengu", "yamabushi": "un yamabushi-tengu", "konoha": "un konoha-tengu",
	"kani": "un crabe heikegani", "ningyo": "une ningyo", "fugu": "un fugu",
	"gaki": "un gaki affamé", "gokusotsu": "un geôlier des enfers", "shiryo": "un shiryō"}

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
signal dojo_pressed
signal next_pressed  # résultats d'une victoire : vers le monde suivant
signal wardrobe_pressed
signal bestiary_pressed  # BESTIAIRE (accueil) : tous les ennemis rencontrés
signal world_step(dir: int)  # accueil : monde précédent (-1) ou suivant (+1), chevrons ou glissé

var mode := "home"  # home | over | pause | hidden
var best := 0
var rooms_total := 8  # étapes d'une partie (main.STAGE_PLAN)
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
var stat_score := 0  # points de la partie (score.gd)
var best_score := 0  # meilleur score du monde (record compris)
var score_record := false  # le score bat l'ancien record du monde
var score_rank := 0  # 0 : aucun, 1..4 : prunier, bambou, pin, maître (picto RANK_ICON)
var score_next := 0  # points du rang suivant (0 : rang maximal)
var pause_powers: Array = []  # ids des pouvoirs de la partie (rangée d'icônes de la pause)
var world_name := ""
var world_kanji := "波"  # clé du monde (jamais affichée) : choisit son picto (WORLD_ICON)
var world_color := Toon.PRUSSIAN
var stat_shapes := {}  # figure -> nombre réalisé
var build := {}  # pouvoir -> niveau (powers.levels)
var affinities := {}  # école -> [nombre de pouvoirs, palier] (powers.affinities())
var new_prints: Array = []  # Vues gagnées à cette partie (ids de meta.PRINTS)
var killer_kind := ""  # type d'ennemi du coup fatal (vide : inconnu ou boss)
var killer_name := ""  # nom du boss du coup fatal
# victoire : bouton principal vers le monde suivant ("" : REJOUER reste le bouton principal)
var next_label := ""
# ce que la victoire a débloqué (rangée DÉBLOQUÉ) : monde ouvert (0 : aucun) et nouveaux rouleaux
var unlock_world := 0
var unlock_world_name := ""
var unlock_world_kanji := ""
var unlock_world_color := Toon.PRUSSIAN
var unlock_powers: Array = []  # ids des pouvoirs du nouveau palier
var unlock_family := ""  # nom de la famille de rouleaux (power_data.UNLOCK_NAMES)
var _build_list: Array = []  # [id du pouvoir, couleur d'école, niveau, couleur de rareté, rang, niveau max, ordre d'école]
var _over_atelier: Control

var _t := 0.0  # temps réel depuis l'affichage
var _title := FontVariation.new()
var _title_wide := FontVariation.new()  # titre IPPITSU de l'accueil, lettres espacées
var _ui := FontVariation.new()
var _small := FontVariation.new()  # légendes des entrées de l'accueil
var _tag_font := FontVariation.new()  # étiquettes de la pause (OPTIONS, QUITTER) : Shippori espacée
var _resume_font := FontVariation.new()  # REPRENDRE : Shippori largement espacée
var _pause_title := FontVariation.new()  # PAUSE dans l'en-tête sumi (espacement 8 u)
var _band_font := FontVariation.new()  # POUVOIRS sur la bande de la pause (espacement 3 u)
var _play: Control
var _replay: Control
var _next: Control
var _home: Control
var _sound: Control
var _atelier: Control
var _dojo: Control  # entraînement libre aux figures
var _worlds: Control
var _resume: Control
var _quit: Control
var _restart: Control
var _powers_btn: Control  # la rangée des pouvoirs de la pause (zone tactile)
var _help: Control
var _gear: Control
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné
var _wardrobe: Control  # GARDE-ROBE (accueil)
var _bestiary: Control  # BESTIAIRE (accueil)
# sélecteur de monde de l'accueil (posé par main._home_select) ; _worlds : la pastille, ouvre la carte
var sel_world := 1
var sel_name := ""
var sel_kanji := "波"
var sel_color := Toon.PRUSSIAN
var sel_locked := false
var _sel_prev: Control
var _sel_next: Control
var _swipe_on := false  # glissé commencé sur le paysage
var _swipe_p := Vector2.ZERO
var _safe := Vector2.ZERO  # marges de sécurité de l'écran (haut, bas), en pixels
# pause : RECOMMENCER et QUITTER demandent un second toucher
var _confirm := ""  # restart | quit | ""
var _confirm_t := 0.0
# thème de l'interface (garde-robe) : papier des cartes, voile, encre du texte
var th_paper := Toon.PAPER
var th_wash := Toon.WASHI
var th_ink := Toon.SUMI


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = UiKit.TITLE_SPACING
	_title_wide.base_font = UiKit.TITLE_FONT
	_title_wide.spacing_glyph = 12
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 4
	_small.base_font = UiKit.UI_FONT
	_small.spacing_glyph = 2

	# accueil : un coup de pinceau JOUER, quatre entrées à icône, icônes nues en haut
	_play = _button("JOUER", "brush")
	_play.shimmer = true  # encre encore humide : un reflet passe de temps en temps
	_play.pressed.connect(func(): play_pressed.emit())
	_atelier = _button("ATELIER", "icon")
	_atelier.icon = "brush"
	_atelier.font = _small
	_atelier.pressed.connect(func(): atelier_pressed.emit())
	_dojo = _button("DOJO", "icon")
	_dojo.icon = "dojo"
	_dojo.font = _small
	_dojo.pressed.connect(func(): dojo_pressed.emit())
	_wardrobe = _button("GARDE-ROBE", "icon")
	_wardrobe.icon = "hanger"
	_wardrobe.font = _small
	_wardrobe.pressed.connect(func(): wardrobe_pressed.emit())
	_bestiary = _button("BESTIAIRE", "icon")
	_bestiary.icon = "bestiary"
	_bestiary.font = _small
	_bestiary.pressed.connect(func(): bestiary_pressed.emit())
	_help = _button("", "bare")
	_help.icon = "help"
	_help.pressed.connect(func(): tuto_pressed.emit())
	_gear = _button("", "bare")
	_gear.icon = "gear"
	_gear.pressed.connect(func(): options_pressed.emit())
	_sound = _button("", "bare")
	_sound.pressed.connect(_toggle_sound)
	# sélecteur de monde : pastille (ouvre la carte des mondes) entre deux chevrons, dessinés par _draw_home
	_worlds = _button("MONDES", "area")
	_worlds.pressed.connect(func(): worlds_pressed.emit())
	_sel_prev = _button("", "area")
	_sel_prev.pressed.connect(func(): world_step.emit(-1))
	_sel_next = _button("", "area")
	_sel_next.pressed.connect(func(): world_step.emit(1))

	# résultats : pinceau principal (REJOUER, ou le monde suivant), ronds de papier à picto (accueil, atelier)
	_replay = _button("REJOUER", "brush")
	_replay.lead_icon = "replay"
	_replay.pressed.connect(func(): play_pressed.emit())
	_next = _button("MONDE SUIVANT", "brush")
	_next.pressed.connect(func(): next_pressed.emit())
	_over_atelier = _button("", "round")
	_over_atelier.icon = "brush"
	_over_atelier.pressed.connect(func(): atelier_pressed.emit())
	_home = _button("", "round")
	_home.icon = "home"
	_home.pressed.connect(func(): home_pressed.emit())

	# pause : REPRENDRE au pinceau, la bande des pouvoirs ouvre MES POUVOIRS, deux actions confirmées en étiquettes
	_tag_font.base_font = UiKit.TITLE_FONT
	_tag_font.spacing_glyph = 2
	_resume_font.base_font = UiKit.TITLE_FONT
	_resume_font.spacing_glyph = 6
	_pause_title.base_font = UiKit.TITLE_FONT
	_pause_title.spacing_glyph = 8
	_band_font.base_font = UiKit.TITLE_FONT
	_band_font.spacing_glyph = 3
	_resume = _button("REPRENDRE", "brush")
	_resume.font = _resume_font
	_resume.pressed.connect(func(): resume_pressed.emit())
	_powers_btn = _button("MES POUVOIRS", "area")
	_powers_btn.pressed.connect(func(): powers_pressed.emit())
	_restart = _button("RECOMMENCER", "label")
	_restart.icon = "replay"
	_restart.font = _tag_font
	_restart.pressed.connect(func(): _confirm_press("restart"))
	_quit = _button("QUITTER", "label")
	_quit.icon = "quit"
	_quit.danger = true
	_quit.font = _tag_font
	_quit.pressed.connect(func(): _confirm_press("quit"))
	show_mode("home")


## Thème de la garde-robe (meta.theme_colors()) : {paper, wash, ink}.
func apply_theme(t: Dictionary) -> void:
	th_paper = t.get("paper", Toon.PAPER)
	th_wash = t.get("wash", Toon.WASHI)
	th_ink = t.get("ink", Toon.SUMI)
	queue_redraw()


func _button(label: String, style: String) -> Control:
	var b := InkButton.new()
	b.text = label
	b.style = style
	b.font = _ui
	add_child(b)
	return b


## Taille de police (<= fs) pour que le texte d'un bouton (et son icône) tienne dans max_w.
func _fit_font(b: Control, fs: int, max_w: float) -> int:
	var txt := String(b.get("text"))
	var f: Font = b.get("font")
	if f == null:
		f = _ui
	var lead := fs * 0.42 * 3.4 if String(b.get("lead_icon")) != "" else 0.0
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + lead
	if tw > max_w and tw > 0.0:
		return maxi(1, int(float(fs) * max_w / tw))
	return maxi(1, fs)


## Haut de la barre d'icônes de l'accueil (sous l'encoche).
func _top_y(u: float) -> float:
	return _safe.x + 16.0 * u


## Haut du coup de pinceau JOUER : la rangée ATELIER · DOJO · GARDE-ROBE et le record tiennent dessous,
## au-dessus de la barre de geste.
func _play_y(h: float, u: float) -> float:
	return h - _safe.y - 236.0 * u


## Pastille du sélecteur de monde (au-dessus de JOUER) ; les chevrons se posent de part et d'autre.
func _sel_rect(w: float, h: float, u: float) -> Rect2:
	var sw := minf(w - 120.0 * u, 214.0 * u)
	var sh := 46.0 * u
	return Rect2(Vector2((w - sw) / 2.0, _play_y(h, u) - sh - 14.0 * u), Vector2(sw, sh))


## Accueil : un glissé horizontal sur le paysage (hors boutons) change de monde, comme les chevrons.
## Souris (le tactile est émulé en souris : project.godot).
func _unhandled_input(event: InputEvent) -> void:
	if mode != "home" or not visible:
		_swipe_on = false
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var u := size.x / 400.0
	if mb.pressed:
		var top := _top_y(u) + UiKit.ICON_BTN * u
		var bottom := _sel_rect(size.x, size.y, u).position.y
		_swipe_on = mb.position.y > top and mb.position.y < bottom
		_swipe_p = mb.position
	elif _swipe_on:
		_swipe_on = false
		var d := mb.position - _swipe_p
		if absf(d.x) > 48.0 * u and absf(d.x) > absf(d.y) * 1.4:
			world_step.emit(1 if d.x < 0.0 else -1)


func _toggle_sound() -> void:
	muted = not muted
	sound_toggled.emit(muted)


## Premier toucher : le bouton demande confirmation (2,5 s) ; second toucher : l'action.
func _confirm_press(which: String) -> void:
	if _confirm == which and _confirm_t > 0.0:
		_confirm = ""
		_confirm_t = 0.0
		if which == "quit":
			home_pressed.emit()
		else:
			restart_pressed.emit()
		return
	_confirm = which
	_confirm_t = 2.5


func show_mode(m: String) -> void:
	mode = m
	_t = 0.0
	_confirm = ""
	_confirm_t = 0.0
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
		_build_list.append([String(id), school.get("color", th_ink), lv,
			rar.get("color", Color(0.6, 0.6, 0.6)), int(rar.get("rank", 0)), int(pd.get("max", 3)), PowerData.SCHOOL_ORDER.find(sid)])
	_build_list.sort_custom(func(x, y): return int(x[4]) > int(y[4]) or (int(x[4]) == int(y[4]) and int(x[6]) < int(y[6])))


func _process(_delta: float) -> void:
	if not visible or mode == "hidden":
		return
	size = get_viewport_rect().size
	var dt := UiKit.real_delta()
	_t += dt
	if _confirm_t > 0.0:
		_confirm_t -= dt
		if _confirm_t <= 0.0:
			_confirm = ""
	_safe = UiKit.safe_insets(size)
	var w := size.x
	var h := size.y
	var u := w / 400.0

	_play.visible = mode == "home"
	var has_next := next_label != ""
	_replay.visible = mode == "over" and _t > 0.45
	_next.visible = mode == "over" and _t > 0.45 and has_next
	_home.visible = mode == "over" and _t > 0.45
	_over_atelier.visible = mode == "over" and _t > 0.45
	_worlds.visible = mode == "home"
	_sel_prev.visible = mode == "home"
	_sel_next.visible = mode == "home"
	_resume.visible = mode == "pause"
	_quit.visible = mode == "pause"
	_restart.visible = mode == "pause"
	_powers_btn.visible = mode == "pause"
	_sound.visible = mode == "home"  # en pause, le son se règle dans OPTIONS (planche Pause v2)
	_atelier.visible = mode == "home"
	_dojo.visible = mode == "home"
	_wardrobe.visible = mode == "home"
	_bestiary.visible = mode == "home"
	_help.visible = mode == "home"
	_gear.visible = mode == "home" or mode == "pause"
	_sound.icon = "sound_off" if muted else "sound_on"
	if mode == "home":
		_layout_home(w, h, u)
	elif mode == "over":
		_layout_over(w, h, u, has_next)
	elif mode == "pause":
		_layout_pause(u)
	queue_redraw()


## Accueil : icônes nues en haut à droite, le pinceau JOUER, puis ATELIER · DOJO · GARDE-ROBE.
func _layout_home(w: float, h: float, u: float) -> void:
	var ty := _top_y(u)
	var ib: float = UiKit.ICON_BTN * u
	_sound.size = Vector2(ib, ib)
	_sound.position = Vector2(w - 14.0 * u - ib, ty)
	# réglages : icône nue à l'accueil (étiquette OPTIONS en pause)
	_gear.style = "bare"
	_gear.text = ""
	_gear.size = Vector2(ib, ib)
	_gear.position = _sound.position - Vector2(ib + 4.0 * u, 0)
	_help.size = Vector2(ib, ib)
	_help.position = _gear.position - Vector2(ib + 4.0 * u, 0)
	# l'encre arrive : le trait se pose de gauche à droite, puis les entrées montent une à une
	var appear := UiKit.ease_out(clampf((_t - 0.5) / 0.7, 0.0, 1.0))
	var bw := minf(w * 0.8, 330.0 * u)
	var bh: float = UiKit.BTN_HERO_H * u
	var py := _play_y(h, u)
	_play.size = Vector2(bw, bh)
	_play.position = Vector2((w - bw) / 2.0, py + 10.0 * u * (1.0 - appear))
	_play.reveal = appear
	_play.font_size = int(27 * u)
	_play.modulate.a = 0.55 if sel_locked else 1.0  # monde scellé : JOUER ouvre la carte, sur lui
	# sélecteur de monde, juste au-dessus du pinceau
	var sk := UiKit.ease_out(clampf((_t - 0.7) / 0.4, 0.0, 1.0))
	var sr := _sel_rect(w, h, u)
	_worlds.position = sr.position
	_worlds.size = sr.size
	var cb := sr.size.y
	_sel_prev.size = Vector2(cb, cb)
	_sel_prev.position = Vector2(sr.position.x - cb - 4.0 * u, sr.position.y)
	_sel_next.size = Vector2(cb, cb)
	_sel_next.position = Vector2(sr.end.x + 4.0 * u, sr.position.y)
	for sb in [_worlds, _sel_prev, _sel_next]:
		var sc: Control = sb
		sc.modulate.a = sk
	# quatre entrées : ATELIER · DOJO · GARDE-ROBE · BESTIAIRE
	var row: Array = [_atelier, _dojo, _wardrobe, _bestiary]
	var ew := 90.0 * u
	var step := 94.0 * u
	for i in row.size():
		var b: Control = row[i]
		var k := UiKit.ease_out(clampf((_t - 0.9 - 0.08 * i) / 0.4, 0.0, 1.0))
		b.size = Vector2(ew, 74.0 * u)
		b.position = Vector2(w / 2.0 + (float(i) - 1.5) * step - ew / 2.0, py + 108.0 * u + 12.0 * u * (1.0 - k))
		b.modulate.a = k
		b.font_size = _fit_font(b, int(11 * u), ew - 6.0 * u)


## Résultats (UI v2) : la feuille washi à en-tête sumi (comme la pause) porte les boutons en bas. Pinceau principal
## (le monde suivant après une victoire, sinon REJOUER en héros), puis ACCUEIL et ATELIER en étiquettes légères ;
## après une victoire, REJOUER se glisse entre elles en texte souligné. Touches bloquées les 0,6 premières secondes.
func _layout_over(w: float, h: float, u: float, has_next: bool) -> void:
	var sheet := _sheet_rect()
	var over_in := UiKit.ease_out(clampf((_t - 0.45) / 0.35, 0.0, 1.0))
	var ink_in := clampf((_t - 0.45) / 0.6, 0.0, 1.0)
	var y0 := sheet.end.y - _btn_zone_h(has_next) * u + 20.0 * u * (1.0 - over_in)
	var inner_w := sheet.size.x - 40.0 * u
	var bx := sheet.position.x + 20.0 * u
	var main_btn: Control = _next if has_next else _replay
	var mh := (UiKit.BTN_MAIN_H if has_next else UiKit.BTN_HERO_H) * u
	main_btn.style = "brush"
	main_btn.size = Vector2(inner_w, mh)
	main_btn.position = Vector2(bx, y0)
	main_btn.reveal = ink_in
	main_btn.modulate.a = 1.0
	_spacing(_tag_font, maxi(1, int(2.0 * u)))
	_spacing(_resume_font, maxi(1, int(5.0 * u)))
	if has_next:
		_next.text = next_label
		_next.font = _ui
		_next.font_size = _fit_font(_next, int(18 * u), inner_w * 0.72)
	else:
		_replay.lead_icon = "replay"
		_replay.font = _resume_font
		_replay.font_size = _fit_font(_replay, int(22 * u), inner_w * 0.62)
	# étiquettes : ACCUEIL à gauche, ATELIER à droite (REJOUER en texte entre les deux après une victoire)
	var ly := y0 + mh + 12.0 * u
	var lh := 40.0 * u
	var lw := 112.0 * u if has_next else minf(150.0 * u, (inner_w - 12.0 * u) / 2.0)
	for b in [[_home, "home", "ACCUEIL"], [_over_atelier, "brush", "ATELIER"]]:
		var lb: Control = b[0]
		lb.style = "label"
		lb.icon = String(b[1])
		lb.text = String(b[2])
		lb.font = _tag_font
		lb.font_size = int((12 if has_next else 13) * u)
		lb.size = Vector2(lw, lh)
		lb.modulate.a = over_in
	_home.position = Vector2(bx, ly)
	_over_atelier.position = Vector2(sheet.end.x - 20.0 * u - lw, ly)
	if has_next:
		_replay.style = "text"
		_replay.lead_icon = ""  # le mot seul : la place est comptée entre les deux étiquettes
		_replay.font = _tag_font
		_replay.font_size = int(12 * u)
		_replay.size = Vector2(inner_w - 2.0 * lw - 12.0 * u, lh)
		_replay.position = Vector2(sheet.get_center().x - _replay.size.x / 2.0, ly)
		_replay.modulate.a = over_in
	var live := mode == "over" and _t >= 0.6
	for b in [_replay, _next, _over_atelier, _home]:
		var bc: Control = b
		if live:
			bc.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			bc.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Feuille de résultats : largeur 368 u au plus, de l'encoche au bas de l'écran (marges de sécurité comprises).
func _sheet_rect() -> Rect2:
	var w := size.x
	var u := w / 400.0
	var cw := minf(w - 32.0 * u, 368.0 * u)
	var top := _safe.x + 10.0 * u
	var bottom := size.y - _safe.y - 10.0 * u
	return Rect2(Vector2((w - cw) / 2.0, top), Vector2(cw, bottom - top))


## Hauteur (× u) réservée aux boutons en bas de la feuille : pinceau, puis la rangée d'étiquettes.
func _btn_zone_h(has_next: bool) -> float:
	return (UiKit.BTN_MAIN_H if has_next else UiKit.BTN_HERO_H) + 12.0 + 40.0 + 16.0


## Pause (UI v2, planche Pause) : feuille à en-tête sumi, trois tuiles (étape, temps, score), bande POUVOIRS
## (ouvre MES POUVOIRS), REPRENDRE au pinceau, OPTIONS et QUITTER en étiquettes, RECOMMENCER dessous
## (QUITTER et RECOMMENCER : second toucher pour confirmer, l'étiquette s'arme en vermillon).
func _layout_pause(u: float) -> void:
	var pc := _pause_card()
	var pr := _powers_rect(pc, u)
	_powers_btn.position = pr.position
	_powers_btn.size = pr.size
	_spacing(_tag_font, maxi(1, int(2.0 * u)))
	_spacing(_resume_font, maxi(1, int(6.0 * u)))
	var rw := pc.size.x - 40.0 * u
	_resume.size = Vector2(rw, UiKit.BTN_MAIN_H * u)
	_resume.position = Vector2(pc.get_center().x - rw / 2.0, pc.position.y + 303.0 * u)
	_resume.reveal = clampf((_t - 0.1) / 0.45, 0.0, 1.0)
	_resume.font_size = _fit_font(_resume, int(21 * u), rw * 0.6)
	_restart.text = "CONFIRMER" if _confirm == "restart" else "RECOMMENCER"
	_restart.accent = _confirm == "restart"
	_quit.text = "CONFIRMER" if _confirm == "quit" else "QUITTER"
	_quit.accent = _confirm == "quit"
	# étiquettes 150 × 46 : OPTIONS à gauche, QUITTER à droite, RECOMMENCER centré dessous
	var lw := 150.0 * u
	var lh := 46.0 * u
	_gear.style = "label"
	_gear.icon = "gear"
	_gear.text = "OPTIONS"
	_gear.font = _tag_font
	_gear.size = Vector2(lw, lh)
	_gear.position = Vector2(pc.position.x + 20.0 * u, pc.position.y + 396.0 * u)
	_quit.size = Vector2(lw, lh)
	_quit.position = Vector2(pc.end.x - 20.0 * u - lw, pc.position.y + 396.0 * u)
	var rlw := 176.0 * u
	_restart.size = Vector2(rlw, lh)
	_restart.position = Vector2(pc.get_center().x - rlw / 2.0, pc.position.y + 456.0 * u)
	for b in [_gear, _quit, _restart]:
		var lb: Control = b
		lb.font_size = int(13 * u)


func _draw() -> void:
	if size.x < 10.0:
		return
	if mode == "home":
		_draw_home()
	elif mode == "over":
		_draw_results()
	elif mode == "pause":
		_draw_pause()


## Dégradé vertical plein écran de y0 (alpha a0) à y1 (alpha a1), couleur c.
func _veil(y0: float, y1: float, c: Color, a0: float, a1: float) -> void:
	var w := size.x
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
		PackedColorArray([Color(c, a0), Color(c, a0), Color(c, a1), Color(c, a1)]))


## Accueil : sceau 一筆 frappé, IPPITSU en capitales espacées souligné d'un trait vermillon,
## la barque au milieu (rien ne la couvre), le pinceau JOUER et les entrées en bas.
func _draw_home() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var ty0 := _top_y(u)
	var title_y := maxf(ty0 + 170.0 * u, h * 0.21)  # ligne de base du titre

	# voile washi en haut (titre) et en bas (pinceau, entrées) ; le milieu reste à la scène
	var top_end := title_y + 90.0 * u
	_veil(0.0, top_end * 0.6, th_wash, 0.95, 0.85)
	_veil(top_end * 0.6, top_end, th_wash, 0.85, 0.0)
	var vy := _play_y(h, u) - 80.0 * u
	_veil(vy, vy + 80.0 * u, th_wash, 0.0, 0.7)
	_veil(vy + 80.0 * u, h, th_wash, 0.7, 0.93)

	var a := UiKit.ease_out(clampf(_t / 0.6, 0.0, 1.0))
	# la mer de Hokusai en filigrane sous le pinceau et les entrées : vagues seigaiha très pâles
	var sea := Rect2(Vector2(0.0, vy + 80.0 * u), Vector2(w, maxf(0.0, h - vy - 80.0 * u)))
	UiKit.seigaiha(self, sea, Color(th_ink, 0.05 * a), 20.0 * u)

	# sceau vermillon 一筆, frappé comme une signature
	var sk := clampf((_t - 0.15) / 0.25, 0.0, 1.0)
	if sk > 0.0:
		var ss := 1.0 + 0.5 * (1.0 - UiKit.ease_out(sk))
		draw_set_transform(Vector2(w / 2.0, title_y - 92.0 * u), 0.04, Vector2(ss, ss))
		UiKit.hanko(self, Rect2(Vector2(-17, -26) * u, Vector2(34, 52) * u), "一筆", Toon.VERMILION, Toon.WASHI, sk, u, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# titre, lettres espacées (l'espacement suit la dernière lettre : on recentre)
	var tfs := int(54 * u)
	var tw := _title_wide.get_string_size("IPPITSU", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	if tw > w * 0.84:
		tfs = int(float(tfs) * w * 0.84 / tw)
		tw = _title_wide.get_string_size("IPPITSU", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	UiKit.text(self, _title_wide, "IPPITSU", Vector2(w / 2.0 + 6.0, title_y + 8.0 * u * (1.0 - a)), tfs, Color(th_ink, a))

	# trait vermillon posé sous le titre, de gauche à droite
	var k := UiKit.ease_out(clampf((_t - 0.35) / 0.45, 0.0, 1.0))
	if k > 0.05:
		var bw := tw * 0.6
		var br := Rect2(Vector2(w / 2.0 - bw / 2.0, title_y + 13.0 * u), Vector2(bw, 9.0 * u))
		draw_colored_polygon(UiKit.swash_points(br, k, 5.0), Color(Toon.VERMILION, 0.95))

	_draw_world_sel(w, h, u)

	# compteur d'encre (par-dessus le voile du haut)
	_draw_ink_counter(Vector2(20.0 * u, ty0 + 23.0 * u), u)
	# numéro de version : pour vérifier que l'appli est bien à jour
	var ver := "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	UiKit.text(self, _ui, ver, Vector2(w - 30 * u, h - _safe.y - 8 * u), int(9 * u), Color(th_ink, 0.35))


## Sélecteur de monde : chevrons au pinceau, pastille de papier avec le sceau du monde, « MONDE N »
## et son nom ; scellé : sceau délavé, cadenas et « VERROUILLÉ ».
func _draw_world_sel(w: float, h: float, u: float) -> void:
	var sa := UiKit.ease_out(clampf((_t - 0.7) / 0.4, 0.0, 1.0))
	if sa <= 0.01:
		return
	var sr := _sel_rect(w, h, u)
	var cy := sr.get_center().y
	# chevrons : deux traits de pinceau épais à la pointe, effilés vers l'arrière
	for sgn in [-1.0, 1.0]:
		var sg: float = sgn
		var tip := Vector2(w / 2.0 + sg * (sr.size.x / 2.0 + 4.0 * u + sr.size.y * 0.58), cy)
		var back := tip - Vector2(sg * 8.0 * u, 0.0)
		var col := Color(th_ink, 0.72 * sa)
		UiKit.brush_line(self, tip, back + Vector2(0.0, -10.0 * u), 4.0 * u, col)
		UiKit.brush_line(self, tip, back + Vector2(0.0, 10.0 * u), 4.0 * u, col)
	# pastille de papier
	var rad := int(sr.size.y / 2.0)
	draw_style_box(UiKit.box(_sb, Color(th_paper, 0.86 * sa), rad, Color(th_ink, 0.2 * sa), maxi(1, int(UiKit.BW_HAIR * u))), sr)
	# pastille du monde (son picto sur sa couleur, délavée s'il est scellé), cadenas posé sur son coin
	var seal := Rect2(sr.position + Vector2(9.0 * u, 8.0 * u), Vector2(sr.size.y - 16.0 * u, sr.size.y - 16.0 * u))
	var scol: Color = th_ink.lerp(th_paper, 0.5) if sel_locked else sel_color
	draw_style_box(UiKit.box(_sb, Color(scol, sa), int(6 * u)), seal)
	UiKit.draw_icon(self, String(WORLD_ICON.get(sel_kanji, "hud/vague")), seal.get_center(), seal.size.x * 0.68, sa, Toon.WASHI)
	if sel_locked:
		var lc := seal.end - Vector2(1.0, 3.0) * u
		draw_circle(lc, 8.0 * u, Color(th_paper, sa))
		UiKit.glyph(self, "at_lock", lc, 5.5 * u, th_ink, th_paper, sa)
	# MONDE N (en vermillon, avec un cadenas, si le monde est scellé), puis le nom
	var x0 := seal.end.x + 8.0 * u
	var x1 := sr.end.x - 16.0 * u
	var cx := (x0 + x1) / 2.0
	var cap := UiKit.plain("MONDE %d" % sel_world)
	var cfs := int(UiKit.FS_CAPTION * u)
	var cw := _small.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
	var ccol := Color(Toon.VERMILION, 0.9 * sa) if sel_locked else Color(th_ink, UiKit.A_CAPTION * sa)
	var cpy := sr.position.y + 17.0 * u
	UiKit.text(self, _small, cap, Vector2(cx, cpy), cfs, ccol)
	if sel_locked:
		UiKit.glyph(self, "at_lock", Vector2(cx + cw / 2.0 + 9.0 * u, cpy - cfs * 0.36), 4.5 * u, Toon.VERMILION, UiKit.NONE, sa)
	var nm := UiKit.plain(sel_name)
	var nfs := int(UiKit.FS_HEADING * u)
	var nw := _title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	if nw > x1 - x0 and nw > 0.0:
		nfs = maxi(1, int(float(nfs) * (x1 - x0) / nw))
	UiKit.text(self, _title, nm, Vector2(cx, sr.end.y - 10.0 * u), nfs, Color(th_ink, (0.55 if sel_locked else 1.0) * sa))


## Compteur d'encre (UI v2, planche Accueil) : pilule sumi, goutte sur disque indigo, nombre en Zen Kaku.
func _draw_ink_counter(p: Vector2, u: float) -> void:
	UiKit.ink_counter(self, _sb, p.x, p.y, sumi, u, 1.0)


## Écran de fin (UI v2, planches Victoire / Défaite, sur la feuille washi de la pause) : en-tête sumi (le mot,
## trait vermillon), le score en Zen Kaku 900, le rang en tuile picto + nom et le palier suivant en texte, RECORD
## en pastille ; puis des lignes à sceau vermillon : chiffres de la partie, figures, pouvoirs (médaillons et
## étiquettes d'élément), gains (encre, sceaux, estampes), déblocages d'une victoire ; défaite : le monstre du coup
## fatal et le conseil d'esquive en pictos. Jamais de kanji, les chiffres en num_font, pas de flou.
func _draw_results() -> void:
	var w := size.x
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.3, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.88 * a))
	var sheet := _sheet_rect()
	var cx := sheet.get_center().x
	# ombre portée sans flou (deux couches décalées), puis la feuille aux coins arrondis
	var pts := UiKit.rrect_points(sheet, 18.0 * u)
	draw_colored_polygon(Transform2D(0.0, Vector2(0, 7.0 * u)) * pts, Color(0, 0, 0, 0.14 * a))
	draw_colored_polygon(Transform2D(0.0, Vector2(0, 3.0 * u)) * pts, Color(0, 0, 0, 0.18 * a))
	draw_colored_polygon(pts, Color(th_paper, a))
	# en-tête sumi : VICTOIRE en papier (VAINCU en vermillon clair), trait vermillon qui se pose dessous
	var head := Rect2(sheet.position, Vector2(sheet.size.x, HEADER_H * u))
	draw_colored_polygon(UiKit.rrect_points(head, 18.0 * u, true), Color(UIColors.SUMI, a))
	var word := "VICTOIRE" if victory else "VAINCU"
	var wc: Color = UIColors.WASHI if victory else VERMILION_LIGHT
	var sp := maxi(1, int(8.0 * u))
	_spacing(_pause_title, sp)
	var tfs := int(24 * u)
	var tw := _pause_title.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	if tw > head.size.x * 0.82:
		tfs = int(float(tfs) * head.size.x * 0.82 / tw)
	var kh := UiKit.ease_out(clampf((_t - 0.15) / 0.35, 0.0, 1.0))
	UiKit.text(self, _pause_title, word, Vector2(cx + float(sp) * 0.5, head.position.y + 41.0 * u + 4.0 * u * (1.0 - kh)), tfs, Color(wc, a * kh))
	var bk := UiKit.ease_out(clampf((_t - 0.25) / 0.4, 0.0, 1.0))
	if bk > 0.05:
		var swash := Rect2(Vector2(cx - 81.0 * u, head.position.y + 47.0 * u), Vector2(162.0 * u, 9.0 * u))
		draw_colored_polygon(UiKit.swash_points(swash, bk, 5.0), Color(UIColors.VERMILION, a))
	# contenu : le score et le rang, puis les lignes
	var lay := _results_layout(u)
	var v: float = lay["v"]
	var x0 := sheet.position.x + 18.0 * u
	var x1 := sheet.end.x - 18.0 * u
	var y: float = lay["top"]
	_draw_head(y, u, v, a)
	y += HEAD_H * v
	var rows: Array = lay["rows"]
	for i in rows.size():
		var kind := String(rows[i])
		var rk := UiKit.ease_out(clampf((_t - 0.5 - 0.12 * float(i)) / 0.3, 0.0, 1.0))
		var rh := float(ROW_HEIGHTS[kind]) * v
		if rk > 0.0:
			var ra := a * rk
			var ry := y + 6.0 * u * (1.0 - rk)
			match kind:
				"killer":
					_draw_killer(x0, x1, ry, rh, u, ra)
				"build":
					_draw_build(x0, x1, ry, rh, u, ra)
				"figures":
					_draw_figures(x0, x1, ry, rh, u, ra)
				"stats":
					_draw_stats(x0, x1, ry, rh, u, ra)
				"loot":
					_draw_loot(x0, x1, ry, rh, u, ra)
				"unlock":
					_draw_unlocks(x0, x1, ry, rh, u, ra)
				"advice":
					_draw_advice(x0, x1, ry, rh, u, ra)
			if kind != "advice" and kind != "killer":
				draw_line(Vector2(x0, y), Vector2(x1, y), Color(th_ink, 0.12 * ra), maxf(1.0, 1.0 * u))
		y += rh


## Lignes de la feuille et leur échelle verticale v (resserrée si l'écran est court) ; top : y du score.
func _results_layout(u: float) -> Dictionary:
	var rows: Array = []
	if victory:
		rows = ["stats", "figures", "build", "loot"]
		if _unlock_rows() > 0:
			rows.append("unlock")
	else:
		rows = ["killer", "stats", "figures", "loot", "advice"]
	var content := HEAD_H
	for r in rows:
		content += float(ROW_HEIGHTS[r])
	var sheet := _sheet_rect()
	var avail := (sheet.size.y - HEADER_H * u - _btn_zone_h(next_label != "") * u) / u - 14.0
	var k := clampf(avail / content, 0.7, 1.0)
	var top := sheet.position.y + HEADER_H * u + 8.0 * u + maxf(0.0, avail - content) * 0.35 * u
	return {"v": u * k, "top": top, "rows": rows}


## Déblocages d'une victoire (rangée DÉBLOQUÉ) : le monde ouvert, la famille de rouleaux.
## Les estampes gagnées sont dans les gains.
func _unlock_rows() -> int:
	if not victory:
		return 0
	var n := 0
	if unlock_world > 0:
		n += 1
	if not unlock_powers.is_empty():
		n += 1
	return n


## Sceau d'une ligne (carré vermillon arrondi, picto papier) ; renvoie le x où commence le contenu.
func _row_icon(x0: float, cy: float, key: String, u: float, a: float) -> float:
	var sq := Rect2(Vector2(x0, cy - 14.0 * u), Vector2(28.0, 28.0) * u)
	draw_style_box(UiKit.box(_sb, Color(UIColors.VERMILION, a), int(6 * u)), sq)
	UiKit.draw_icon(self, key, sq.get_center(), 17.0 * u, a, UIColors.WASHI)
	return x0 + 40.0 * u


## Nom d'un rang en minuscules accentuées (« PRUNIER » -> « Prunier »).
func _rank_word(r: int) -> String:
	var n := Score.rank_name(r)
	if n == "":
		return ""
	return n.substr(0, 1) + n.substr(1).to_lower()


## Score (compteur qui monte, or après une victoire), puis le rang : tuile de sa couleur à picto (elle s'abat une
## fois les points comptés), son nom, et le palier suivant en texte (« Pin à 60 000 », « Rang maximal ») ;
## RECORD en pastille or à droite.
func _draw_head(y: float, u: float, v: float, a: float) -> void:
	var cx := size.x / 2.0
	var nf := UiKit.num_font()
	var ck := UiKit.ease_out(clampf((_t - 0.3) / 1.0, 0.0, 1.0))
	var sc: Color = GOLD_INK if victory else th_ink
	UiKit.text(self, nf, Score.fmt(int(round(float(stat_score) * ck))), Vector2(cx, y + 40.0 * v), int(36 * u), Color(sc, a))
	# le groupe tuile + textes (+ RECORD) est centré
	var rk := clampf((_t - 1.3) / 0.22, 0.0, 1.0)
	var ra := a * UiKit.ease_out(clampf((_t - 1.4) / 0.3, 0.0, 1.0))
	var ts := 38.0 * u
	var line1 := _rank_word(score_rank) if score_rank > 0 else "Sans rang"
	var line2 := "Rang maximal"
	if score_next > 0:
		line2 = "%s à %s" % [_rank_word(mini(score_rank + 1, 4)), Score.fmt(score_next)]
	_spacing(_title, maxi(1, int(1.0 * u)))
	var fs1 := int(15 * u)
	var fs2 := int(11 * u)
	var w1 := _title.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x
	var w2 := nf.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var tw := maxf(w1, w2)
	var gw := ts + 10.0 * u + tw
	var rec := score_record or new_record
	var pfs := int(10 * u)
	var pw := _tag_font.get_string_size("RECORD", HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x + 20.0 * u
	if rec:
		gw += 12.0 * u + pw
	var gx := cx - gw / 2.0
	var tc := Vector2(gx + ts / 2.0, y + 80.0 * v)
	if score_rank > 0:
		if rk > 0.0:
			var s := 1.0 + 0.6 * (1.0 - UiKit.ease_out(rk))
			draw_set_transform(tc, -0.1, Vector2(s, s))
			var tr := Rect2(Vector2(-ts, -ts) / 2.0, Vector2(ts, ts))
			draw_style_box(UiKit.box(_sb, Color(Score.rank_color(score_rank), a * rk), int(7 * u), Color(UIColors.WASHI, 0.9 * a * rk), int(maxf(1.0, 2.0 * u))), tr)
			UiKit.draw_icon(self, _rank_icon(score_rank), Vector2.ZERO, ts * 0.6, a * rk, UIColors.WASHI)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_dashed_rect(Rect2(tc - Vector2(ts, ts) / 2.0, Vector2(ts, ts)), 6.0 * u, Color(th_ink, 0.35 * a), u)
	var tx := gx + ts + 10.0 * u
	draw_string(_title, Vector2(tx, tc.y - 3.0 * u), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, Color(th_ink, ra))
	draw_string(nf, Vector2(tx, tc.y + 12.0 * u), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(th_ink, 0.6 * ra))
	if rec:
		var pulse := 0.85 + 0.15 * sin(_t * 6.0)
		var pr := Rect2(Vector2(tx + tw + 12.0 * u, tc.y - 11.0 * u), Vector2(pw, 22.0 * u))
		draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD, ra * pulse), int(11 * u)), pr)
		UiKit.text(self, _tag_font, "RECORD", pr.get_center() + Vector2(1.0 * u, pfs * 0.36), pfs, Color(UIColors.SUMI, ra))


## Picto du rang (prunier, bambou, pin, couronne du maître).
func _rank_icon(r: int) -> String:
	return String(RANK_ICON[clampi(r - 1, 0, RANK_ICON.size() - 1)])


## Cadre en pointillés arrondis (tuile vide, conseil).
func _dashed_rect(r: Rect2, rad: float, col: Color, u: float) -> void:
	var pts := UiKit.rrect_points(r, rad)
	var dash := 5.0 * u
	var n := pts.size()
	var acc := 0.0
	for i in n:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var seg := p1 - p0
		var l := seg.length()
		var t := 0.0
		while t < l:
			var on := fmod(acc, dash * 2.0) < dash
			var step := minf(dash - fmod(acc, dash), l - t)
			if on:
				draw_line(p0 + seg * (t / l), p0 + seg * ((t + step) / l), col, maxf(1.0, 1.4 * u), true)
			t += step
			acc += step


## Coup fatal (défaite) : le monstre en picto sur un disque sombre, son nom (sceau vermillon à picto),
## l'étape (picto du monde et « 5/8 »).
func _draw_killer(x0: float, x1: float, y: float, rh: float, u: float, a: float) -> void:
	var r := Rect2(Vector2(x0, y + 4.0 * u), Vector2(x1 - x0, rh - 10.0 * u))
	draw_style_box(UiKit.box(_sb, Color(th_ink, 0.06 * a), int(14 * u), Color(th_ink, 0.14 * a), int(maxf(1.0, 1.0 * u))), r)
	var cc := Vector2(r.position.x + 38.0 * u, r.get_center().y)
	draw_circle(cc, 25.0 * u, Color(UIColors.VERMILION_DARK, 0.22 * a))
	UiKit.draw_icon(self, "hud/oni", cc, 32.0 * u, a, UIColors.VERMILION)
	var tx := cc.x + 38.0 * u
	var sq := Rect2(Vector2(tx, r.get_center().y - 23.0 * u), Vector2(22.0, 22.0) * u)
	draw_style_box(UiKit.box(_sb, Color(UIColors.VERMILION, a), int(5 * u)), sq)
	UiKit.draw_icon(self, "hud/oni", sq.get_center(), 14.0 * u, a, UIColors.WASHI)
	var nm := _killer_label()
	_spacing(_title, maxi(1, int(1.0 * u)))
	var nfs := int(17 * u)
	var maxw := r.end.x - 12.0 * u - (tx + 30.0 * u)
	var nw := _title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	if nw > maxw and nw > 0.0:
		nfs = maxi(8, int(float(nfs) * maxw / nw))
	draw_string(_title, Vector2(tx + 30.0 * u, sq.get_center().y + nfs * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(th_ink, a))
	var ws := Rect2(Vector2(tx, r.get_center().y + 5.0 * u), Vector2(18.0, 18.0) * u)
	draw_style_box(UiKit.box(_sb, Color(world_color, a), int(4 * u)), ws)
	UiKit.draw_icon(self, String(WORLD_ICON.get(world_kanji, "hud/vague")), ws.get_center(), 12.0 * u, a, UIColors.WASHI)
	_num_pair(Vector2(tx + 26.0 * u, ws.get_center().y), str(stat_room), "/%d" % rooms_total, int(14 * u), Color(th_ink, a), u)


## Nom du monstre du coup fatal, sans son article (« un oni » -> « Oni »), ou le nom du gardien.
func _killer_label() -> String:
	var who := ""
	if killer_name != "":
		who = killer_name
	elif killer_kind != "":
		who = String(KILLER_NAMES.get(killer_kind, ""))
	if who == "":
		return "?"
	for art in ["un ", "une ", "des ", "ton ", "le "]:
		if who.begins_with(art):
			who = who.substr(art.length())
			break
	return UiKit.plain(who.substr(0, 1).to_upper() + who.substr(1))


## Grand chiffre suivi d'un petit (« 5 » puis « /8 »), ligne de base centrée sur c.y, à partir de c.x.
func _num_pair(c: Vector2, big: String, small: String, fs: int, col: Color, _u: float) -> float:
	var nf := UiKit.num_font()
	var sfs := int(float(fs) * 0.68)
	var bw := nf.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(nf, Vector2(c.x, c.y + fs * 0.36), big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_string(nf, Vector2(c.x + bw, c.y + fs * 0.36), small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(col, col.a * 0.6))
	return bw + nf.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x


## Pouvoirs de la partie : bande des médaillons (les plus rares d'abord, « +N » s'il en reste), puis les étiquettes
## d'élément (picto + NOM) des écoles du build, trois au plus, calées à droite.
func _draw_build(x0: float, x1: float, y: float, rh: float, u: float, a: float) -> void:
	var cy := y + rh / 2.0
	var x := _row_icon(x0, cy, "hud/rouleau", u, a)
	var n := _build_list.size()
	var ms := 30.0 * u
	var step := ms + 6.0 * u
	if n == 0:
		draw_arc(Vector2(x + ms / 2.0, cy), ms * 0.45, 0.0, TAU, 36, Color(th_ink, 0.3 * a), maxf(1.0, 1.4 * u), true)
		return
	# étiquettes : écoles présentes, dans l'ordre des écoles, tant qu'elles tiennent (trois médaillons au moins restent visibles)
	var schools: Array = []
	for sd in _build_list:
		var sid := UiKit.power_school(String(sd[0]))
		if not schools.has(sid):
			schools.append(sid)
	schools.sort_custom(func(p, q): return PowerData.SCHOOL_ORDER.find(p) < PowerData.SCHOOL_ORDER.find(q))
	var th := 18.0 * u
	var tags: Array = []
	var tags_w := 0.0
	var room := (x1 - x) - 3.0 * step - 8.0 * u
	for sid in schools:
		if tags.size() >= 3:
			break
		var tw := UiKit.element_tag(self, _sb, String(sid), 0.0, 0.0, th, 1.0, false)
		if tags_w + tw + 5.0 * u > room:
			break
		tags.append([sid, tw])
		tags_w += tw + 5.0 * u
	# les médaillons d'abord : une étiquette de moins (jusqu'à une seule) tant qu'ils ne tiennent pas tous
	var cap := maxi(1, int((x1 - x - tags_w + 6.0 * u) / step))
	while tags.size() > 1 and n > cap:
		tags_w -= float(tags.pop_back()[1]) + 5.0 * u
		cap = maxi(1, int((x1 - x - tags_w + 6.0 * u) / step))
	var shown := n if n <= cap else cap - 1
	for i in shown:
		var k := UiKit.ease_out(clampf((_t - 0.7 - 0.04 * float(i)) / 0.25, 0.0, 1.0))
		if k <= 0.0:
			continue
		var sd: Array = _build_list[i]
		var mc := Vector2(x + ms / 2.0 + step * float(i), cy + 4.0 * u * (1.0 - k))
		UiKit.power_medal(self, String(sd[0]), mc, ms / 60.0, UIColors.element(UiKit.power_school(String(sd[0]))), 27.0, 4.0, UiKit.NONE, 4.0, a * k)
	if n > shown:
		var mc2 := Vector2(x + ms / 2.0 + step * float(shown), cy)
		draw_arc(mc2, ms * 0.45, 0.0, TAU, 36, Color(th_ink, 0.5 * a), maxf(1.0, 1.4 * u), true)
		UiKit.text(self, UiKit.num_font(), "+%d" % (n - shown), mc2 + Vector2(0, 4.5 * u), int(12 * u), Color(th_ink, a))
	var tx := x1 - tags_w + 5.0 * u
	for i in tags.size():
		var tk := UiKit.ease_out(clampf((_t - 0.9 - 0.08 * float(i)) / 0.3, 0.0, 1.0))
		if tk > 0.0:
			UiKit.element_tag(self, _sb, String(tags[i][0]), tx, cy, th, a * tk)
		tx += float(tags[i][1]) + 5.0 * u


## Les six figures, chacune avec son compte (celles tracées en couleur pleine, les autres pâles).
func _draw_figures(x0: float, x1: float, y: float, rh: float, u: float, a: float) -> void:
	var cy := y + rh / 2.0
	var x := _row_icon(x0, cy, "elements/figure", u, a)
	var nf := UiKit.num_font()
	var step := (x1 - x) / float(UiKit.FIGURES.size())
	var fs := int(12 * u)
	for i in UiKit.FIGURES.size():
		var sh := String(UiKit.FIGURES[i])
		var n := int(stat_shapes.get(sh, 0))
		var k := UiKit.ease_out(clampf((_t - 0.8 - 0.05 * float(i)) / 0.3, 0.0, 1.0))
		if k <= 0.0:
			continue
		var fa := a * k * (1.0 if n > 0 else 0.35)
		var col: Color = UIColors.FIGURES_INK.get(sh, th_ink)
		var c := Vector2(x + step * float(i) + 11.0 * u, cy)
		UiKit.figure_icon(self, sh, c, 20.0 * u * (0.7 + 0.3 * k), fa, col)
		draw_string(nf, Vector2(c.x + 13.0 * u, cy + fs * 0.36), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(th_ink, fa))


## Chiffres de la partie : étape (picto du monde), ennemis, chaîne max, temps.
func _draw_stats(x0: float, x1: float, y: float, rh: float, u: float, a: float) -> void:
	var cy := y + rh / 2.0
	var x := _row_icon(x0, cy, "hud/slash", u, a)
	var nf := UiKit.num_font()
	var step := (x1 - x) / 4.0
	var fs := int(15 * u)
	var clock := "%d:%02d" % [int(stat_time / 60.0), int(stat_time) % 60]
	var items := [["", str(stat_room), "/%d" % rooms_total], ["hud/oni", str(stat_kills), ""], ["hud/chaine", str(stat_combo), ""], ["effets/duree", clock, ""]]
	for i in items.size():
		var it: Array = items[i]
		var k := UiKit.ease_out(clampf((_t - 0.9 - 0.06 * float(i)) / 0.3, 0.0, 1.0))
		if k <= 0.0:
			continue
		var ka := a * k
		var c := Vector2(x + step * float(i) + 10.0 * u, cy)
		if i == 0:
			var ws := Rect2(c - Vector2(10.0, 10.0) * u, Vector2(20.0, 20.0) * u)
			draw_style_box(UiKit.box(_sb, Color(world_color, ka), int(4 * u)), ws)
			UiKit.draw_icon(self, String(WORLD_ICON.get(world_kanji, "hud/vague")), c, 13.0 * u, ka, UIColors.WASHI)
		else:
			UiKit.draw_icon(self, String(it[0]), c, 20.0 * u, ka, th_ink)
		if String(it[2]) != "":
			_num_pair(Vector2(c.x + 15.0 * u, cy), String(it[1]), String(it[2]), fs, Color(th_ink, ka), u)
		else:
			draw_string(nf, Vector2(c.x + 15.0 * u, cy + fs * 0.36), String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(th_ink, ka))


## Gains : l'encre qui monte (goutte sur pastille indigo), les sceaux (carré vermillon), puis chaque estampe
## débloquée en vignette cernée d'or, son nom dessous.
func _draw_loot(x0: float, x1: float, y: float, rh: float, u: float, a: float) -> void:
	var cy := y + rh / 2.0
	var x := _row_icon(x0, cy, "hud/piece", u, a)
	var nf := UiKit.num_font()
	var fs := int(16 * u)
	var up: Color = UIColors.JADE_UP_ON_DARK if Toon.ui_dark else UIColors.JADE_UP
	var ik := clampf((_t - 1.0) / 0.9, 0.0, 1.0)
	var dc := Vector2(x + 11.0 * u, cy)
	draw_circle(dc, 11.0 * u, Color(UIColors.element_key_color("eau"), a))
	UiKit.glyph(self, "at_drop", dc, 6.0 * u, UIColors.WASHI, UiKit.NONE, a)
	var num := "+%d" % int(round(float(gain_sumi) * UiKit.ease_out(ik)))
	draw_string(nf, Vector2(dc.x + 17.0 * u, cy + fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(up, a))
	var nw := nf.get_string_size("+%d" % gain_sumi, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sk := UiKit.ease_out(clampf((_t - 1.5) / 0.25, 0.0, 1.0))
	var px := dc.x + 30.0 * u + nw
	if sk > 0.0:
		var sa := a * sk * (1.0 if gain_seals > 0 else 0.45)
		var sq := Rect2(Vector2(px, cy - 10.0 * u), Vector2(20.0, 20.0) * u)
		var ss := 1.0 + 0.5 * (1.0 - sk)
		draw_set_transform(sq.get_center(), 0.0, Vector2(ss, ss))
		draw_style_box(UiKit.box(_sb, Color(UIColors.VERMILION, sa), int(4 * u)), Rect2(-sq.size / 2.0, sq.size))
		UiKit.glyph(self, "at_seal", Vector2.ZERO, 6.0 * u, UIColors.WASHI, UiKit.NONE, sa)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var st := "+%d" % gain_seals
		draw_string(nf, Vector2(sq.end.x + 6.0 * u, cy + fs * 0.36), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(up if gain_seals > 0 else th_ink, sa))
		px = sq.end.x + 6.0 * u + nf.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0 * u
	# estampes : vignette 40 × 28 cernée d'or, nom en petit dessous
	var tw := 40.0 * u
	var thh := 28.0 * u
	var nfs := int(7.5 * u)
	for i in mini(new_prints.size(), 3):
		var pid := String(new_prints[i])
		if not Meta.PRINTS.has(pid) or px + tw > x1:
			break
		var pd: Dictionary = Meta.PRINTS[pid]
		var pk := UiKit.ease_out(clampf((_t - 1.7 - 0.25 * float(i)) / 0.3, 0.0, 1.0))
		if pk <= 0.0:
			break
		var th := Rect2(Vector2(px, cy - 19.0 * u), Vector2(tw, thh))
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(4 * u), Color(UIColors.GOLD_DARK, a * pk), int(maxf(1.0, 2.0 * u))), th.grow(2.0 * u))
		UiKit.print_thumb(self, th, pd, u, a * pk)
		var nm := UiKit.plain(String(pd.get("name", "")))
		var f := nfs
		while f > 5 and nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > tw + 10.0 * u:
			f -= 1
		UiKit.text(self, nf, nm, Vector2(th.get_center().x, th.end.y + 11.0 * u), f, Color(th_ink, 0.8 * a * pk))
		px += tw + 14.0 * u


## Déblocages (victoire) : tuiles qui glissent en place : le monde ouvert (son picto, « monde N »), la famille
## de rouleaux (quelques médaillons et « +N »).
func _draw_unlocks(x0: float, x1: float, y: float, rh: float, u: float, a: float) -> void:
	var cy := y + rh / 2.0
	var x := _row_icon(x0, cy, "hud/ouvert", u, a)
	var tw := 64.0 * u
	var th := rh - 10.0 * u
	var step := tw + 10.0 * u
	var i := 0
	var nf := UiKit.num_font()
	var t0 := 1.5
	if unlock_world > 0:
		var pk := UiKit.ease_out(clampf((_t - t0) / 0.35, 0.0, 1.0))
		var r := Rect2(Vector2(x + 24.0 * u * (1.0 - pk), cy - th / 2.0), Vector2(tw, th))
		draw_style_box(UiKit.box(_sb, Color(th_ink, 0.05 * a * pk), int(8 * u)), r)
		_dashed_rect(r, 8.0 * u, Color(UIColors.GOLD_DARK, a * pk), u)
		var ic := Vector2(r.get_center().x, r.position.y + th * 0.42)
		var ws := Rect2(ic - Vector2(14.0, 14.0) * u, Vector2(28.0, 28.0) * u)
		draw_style_box(UiKit.box(_sb, Color(unlock_world_color, a * pk), int(6 * u)), ws)
		UiKit.draw_icon(self, String(WORLD_ICON.get(unlock_world_kanji, "hud/vague")), ic, 18.0 * u, a * pk, UIColors.WASHI)
		UiKit.text(self, nf, "monde %d" % unlock_world, Vector2(r.get_center().x, r.end.y - 7.0 * u), int(8.5 * u), Color(th_ink, 0.8 * a * pk))
		x += step
		i += 1
	if not unlock_powers.is_empty():
		var qk := UiKit.ease_out(clampf((_t - t0 - 0.25 * float(i)) / 0.35, 0.0, 1.0))
		var r := Rect2(Vector2(x + 24.0 * u * (1.0 - qk), cy - th / 2.0), Vector2(tw, th))
		draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD, 0.12 * a * qk), int(8 * u), Color(UIColors.GOLD_DARK, 0.9 * a * qk), int(maxf(1.0, 1.5 * u))), r)
		var shown := mini(unlock_powers.size(), 3)
		var ir := 9.0 * u
		for q in shown:
			var ic := Vector2(r.get_center().x + (float(q) - float(shown - 1) / 2.0) * 15.0 * u, r.position.y + th * 0.42)
			draw_circle(ic, ir + 1.5 * u, Color(UIColors.WASHI_LIGHT, a * qk))
			UiKit.power_icon(self, String(unlock_powers[q]), ic, ir, a * qk)
		UiKit.text(self, nf, "+%d" % unlock_powers.size(), Vector2(r.get_center().x, r.end.y - 7.0 * u), int(11 * u), Color(GOLD_INK, a * qk))


## Conseil d'esquive (défaite), tout en pictos : bouclier d'alerte, la zone rouge, puis le bond (un toucher)
## et le trait qui tranche, dans un cadre or en pointillés.
func _draw_advice(x0: float, x1: float, y: float, rh: float, u: float, a: float) -> void:
	var r := Rect2(Vector2(x0, y + 6.0 * u), Vector2(x1 - x0, rh - 12.0 * u))
	_dashed_rect(r, 12.0 * u, Color(UIColors.GOLD_DARK, 0.9 * a), u)
	var cy := r.get_center().y
	var gold := Color(UIColors.GOLD, a)
	var ink := Color(th_ink, a)
	var x := r.position.x + 26.0 * u
	# bouclier d'alerte
	UiKit.glyph(self, "shield", Vector2(x, cy), 11.0 * u, gold, UiKit.NONE, a)
	draw_line(Vector2(x, cy - 5.0 * u), Vector2(x, cy + 1.0 * u), Color(UIColors.SUMI, a), maxf(1.0, 2.2 * u), true)
	draw_circle(Vector2(x, cy + 4.5 * u), 1.4 * u, Color(UIColors.SUMI, a))
	x += 36.0 * u
	# zone rouge qui pulse
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(Vector2(x, cy), 9.0 * u, Color(UIColors.ATTACK_ZONE_FILL, a * (0.6 + 0.4 * pulse)))
	draw_arc(Vector2(x, cy), 9.0 * u, 0.0, TAU, 28, Color(UIColors.ATTACK_ZONE_STROKE, a), maxf(1.0, 2.0 * u), true)
	x += 30.0 * u
	_arrow(Vector2(x, cy), u, ink)
	x += 30.0 * u
	# le bond : un toucher (point dans un cercle en pointillés)
	UiKit.dashed_arc(self, Vector2(x, cy), 10.0 * u, 0.0, TAU, ink, maxf(1.0, 1.4 * u), 3.0 * u, 3.0 * u)
	draw_circle(Vector2(x, cy), 3.0 * u, ink)
	x += 30.0 * u
	_arrow(Vector2(x, cy), u, ink)
	x += 30.0 * u
	# le trait qui tranche : trois traits de vitesse et le monstre barré
	for i in 3:
		var yy := cy + (float(i) - 1.0) * 5.0 * u
		draw_line(Vector2(x - 14.0 * u, yy), Vector2(x - 5.0 * u + 2.0 * u * float(i % 2), yy), ink, maxf(1.0, 1.8 * u), true)
	draw_arc(Vector2(x + 8.0 * u, cy), 8.0 * u, 0.0, TAU, 24, ink, maxf(1.0, 1.6 * u), true)
	draw_line(Vector2(x - 2.0 * u, cy), Vector2(x + 18.0 * u, cy), Color(UIColors.VERMILION, a), maxf(1.0, 2.6 * u), true)


## Petite flèche vers la droite, centrée sur c.
func _arrow(c: Vector2, u: float, col: Color) -> void:
	var wdt := maxf(1.0, 2.0 * u)
	draw_line(c - Vector2(7.0 * u, 0), c + Vector2(7.0 * u, 0), col, wdt, true)
	draw_polyline(PackedVector2Array([c + Vector2(2.0, -5.0) * u, c + Vector2(7.0, 0.0) * u, c + Vector2(2.0, 5.0) * u]), col, wdt, true)


## Carte de la pause (planche Pause v2 : 352 × 560 u, au centre de l'écran, dans les marges de sécurité).
func _pause_card() -> Rect2:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var cw := minf(w - 32.0 * u, 352.0 * u)
	var ch := minf(560.0 * u, maxf(510.0 * u, h - _safe.x - _safe.y - 24.0 * u))
	var lo := _safe.x + 12.0 * u
	var cy := clampf(h * 0.5 - ch / 2.0, lo, maxf(lo, h - _safe.y - 12.0 * u - ch))
	return Rect2(Vector2((w - cw) / 2.0, cy), Vector2(cw, ch))


## Bande POUVOIRS de la pause : la toucher ouvre MES POUVOIRS.
func _powers_rect(card: Rect2, u: float) -> Rect2:
	return Rect2(card.position + Vector2(20.0 * u, 186.0 * u), Vector2(card.size.x - 40.0 * u, 70.0 * u))


## Espacement des lettres (px) d'une variation de police, posé seulement s'il change (suit u).
func _spacing(f: FontVariation, px: int) -> void:
	if f.spacing_glyph != px:
		f.spacing_glyph = px


## Pause (planche Pause v2) : voile d'encre, feuille washi à en-tête sumi souligné de vermillon, tuiles de la partie
## (étape, temps, score : pictogrammes et chiffres, sans légende), bande POUVOIRS (médaillons, ouvre MES POUVOIRS).
## REPRENDRE et les étiquettes OPTIONS, QUITTER, RECOMMENCER sont des InkButton (_layout_pause).
func _draw_pause() -> void:
	var w := size.x
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.25, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.88 * a))
	var card := _pause_card()
	card.position.y += 16.0 * u * (1.0 - a)
	var cx := card.get_center().x
	# ombre portée sans flou (deux couches décalées), puis la feuille aux coins arrondis
	var sheet := UiKit.rrect_points(card, 18.0 * u)
	draw_colored_polygon(Transform2D(0.0, Vector2(0, 7.0 * u)) * sheet, Color(0, 0, 0, 0.14 * a))
	draw_colored_polygon(Transform2D(0.0, Vector2(0, 3.0 * u)) * sheet, Color(0, 0, 0, 0.18 * a))
	draw_colored_polygon(sheet, Color(th_paper, a))
	# en-tête sumi : PAUSE en papier, trait vermillon qui se pose dessous
	var head := Rect2(card.position, Vector2(card.size.x, 70.0 * u))
	draw_colored_polygon(UiKit.rrect_points(head, 18.0 * u, true), Color(UIColors.SUMI, a))
	var sp := maxi(1, int(8.0 * u))
	_spacing(_pause_title, sp)
	UiKit.text(self, _pause_title, "PAUSE", Vector2(cx + float(sp) * 0.5, card.position.y + 45.0 * u), int(26 * u), Color(UIColors.WASHI, a))
	var bk := UiKit.ease_out(clampf((_t - 0.1) / 0.4, 0.0, 1.0))
	if bk > 0.05:
		var swash := Rect2(Vector2(cx - 81.0 * u, card.position.y + 51.0 * u), Vector2(162.0 * u, 10.0 * u))
		draw_colored_polygon(UiKit.swash_points(swash, bk, 5.0), Color(UIColors.VERMILION, a))
	# la partie en cours : trois tuiles (pictogramme, chiffre)
	var nf := UiKit.num_font()
	var nfs := int(19 * u)
	var tile_w := (card.size.x - 60.0 * u) / 3.0
	for i in 3:
		var tile := Rect2(Vector2(card.position.x + 20.0 * u + float(i) * (tile_w + 10.0 * u), card.position.y + 92.0 * u), Vector2(tile_w, 74.0 * u))
		draw_style_box(UiKit.box(_sb, Color(th_ink, 0.07 * a), int(12 * u)), tile)
		var ic := Vector2(tile.get_center().x, tile.position.y + 25.0 * u)
		var by := tile.position.y + 58.0 * u
		match i:
			0:
				# étape : pastille du monde (pictogramme sur sa couleur), « 5/8 » (le total plus petit et pâle)
				var sq := Rect2(ic - Vector2(12.0, 12.0) * u, Vector2(24.0, 24.0) * u)
				draw_style_box(UiKit.box(_sb, Color(world_color, a), int(4 * u)), sq)
				UiKit.draw_icon(self, String(WORLD_ICON.get(world_kanji, "hud/vague")), ic, 15.0 * u, a, UIColors.WASHI)
				var big := str(stat_room)
				var small := "/%d" % rooms_total
				var sfs := int(12 * u)
				var bw := nf.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
				var sw := nf.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
				var x0 := tile.get_center().x - (bw + sw) / 2.0
				draw_string(nf, Vector2(x0, by), big, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(th_ink, a))
				draw_string(nf, Vector2(x0 + bw, by), small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(th_ink, 0.6 * a))
			1:
				# temps de la partie
				UiKit.draw_icon(self, "effets/duree", ic, 22.0 * u, a, th_ink)
				var clock := "%02d:%02d" % [int(stat_time / 60.0), int(stat_time) % 60]
				UiKit.text(self, nf, clock, Vector2(tile.get_center().x, by), _fit_num(clock, nfs, tile_w - 10.0 * u), Color(th_ink, a))
			_:
				# score
				UiKit.draw_icon(self, "effets/critique", ic, 22.0 * u, a)
				var sc := Score.fmt(stat_score)
				UiKit.text(self, nf, sc, Vector2(tile.get_center().x, by), _fit_num(sc, nfs, tile_w - 10.0 * u), Color(th_ink, a))
	# bande POUVOIRS (sumi) : médaillons des pouvoirs pris, le mot et un chevron ; la bande entière ouvre MES POUVOIRS
	var pr := _powers_rect(card, u)
	draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI, a), int(12 * u)), pr)
	var chev := Vector2(pr.end.x - 22.0 * u, pr.get_center().y)
	UiKit.draw_path(self, "M12 6 L22 16 L12 26", 32, chev, 16.0 * u, UIColors.WASHI, 3.0, UiKit.NONE, a)
	var bsp := maxi(1, int(3.0 * u))
	_spacing(_band_font, bsp)
	var lfs := int(14 * u)
	var lw := _band_font.get_string_size("POUVOIRS", HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var lx := chev.x - 16.0 * u - lw
	draw_string(_band_font, Vector2(lx, pr.get_center().y + float(lfs) * 0.36), "POUVOIRS", HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(UIColors.WASHI, a))
	var ids: Array = pause_powers
	var ms := 34.0 * u
	var step := ms + 8.0 * u
	var mx0 := pr.position.x + 14.0 * u
	var cap := maxi(1, int((lx - 8.0 * u - mx0 + 8.0 * u) / step))
	var shown := ids.size() if ids.size() <= cap else cap - 1
	for i in shown:
		var id := String(ids[i])
		var ik := UiKit.ease_out(clampf((_t - 0.15 - 0.04 * float(i)) / 0.25, 0.0, 1.0))
		var mc := Vector2(mx0 + ms / 2.0 + step * float(i), pr.get_center().y + 4.0 * u * (1.0 - ik))
		UiKit.power_medal(self, id, mc, ms / 60.0, UIColors.element(UiKit.power_school(id)), 27.0, 4.0, UiKit.NONE, 4.0, a * ik)
	if ids.size() > shown:
		var mc2 := Vector2(mx0 + ms / 2.0 + step * float(shown), pr.get_center().y)
		draw_arc(mc2, ms * 0.45, 0.0, TAU, 40, Color(UIColors.WASHI, 0.5 * a), maxf(1.0, 1.5 * u), true)
		UiKit.text(self, nf, "+%d" % (ids.size() - shown), mc2 + Vector2(0, 5.0 * u), int(13 * u), Color(UIColors.WASHI, a))


## Taille d'un chiffre (<= fs) qui tient dans maxw.
func _fit_num(txt: String, fs: int, maxw: float) -> int:
	var f := fs
	while f > 8 and UiKit.num_font().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > maxw:
		f -= 1
	return f
