extends Control
## Accueil (sceau, titre, pinceau JOUER, entrées Atelier · Dojo · Garde-robe), résultats en fin de partie, et pause.
const Perf = preload("res://scripts/perf_probe.gd")  # relevé par image (-- --perf)

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const PowerData = preload("res://scripts/power_data.gd")
const Meta = preload("res://scripts/meta.gd")
const Score = preload("res://scripts/score.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
const GOLD_INK := Color("#9A6B12")  # or lisible sur le papier
const Intro = preload("res://scripts/intro.gd")  # noms des figures (FIG_NAME) pour la feuille de résultats
# feuille de résultats (× u) : en-tête sumi (le mot, le monde et l'étape), puis des blocs titrés ; le bas est réservé aux boutons
const HEADER_H := 86.0
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
signal world_step(dir: int)
signal measure_toggled  # appui long (1,5 s) sur le titre IPPITSU : mode mesure (mesure.gd)
signal report_copy_pressed  # pause, mode mesure : COPIER LE RAPPORT
signal camera_pressed  # pause, mode mesure : CAMÉRA (réglage de la caméra, cam_panel.gd)
signal unlock_all_pressed  # pause, mode développeur : TOUT DÉBLOQUER (confirmé par un second toucher)
signal god_pressed  # pause, mode développeur : GOD MODE (interrupteur)
signal report_reset_pressed  # pause, mode mesure : REMETTRE À ZÉRO  # accueil : monde précédent (-1) ou suivant (+1), chevrons ou glissé

var mode := "home"  # home | over | pause | hidden
var best := 0
var rooms_total := 8  # étapes d'une partie (main.STAGE_PLAN)
var new_record := false
var victory := false
var muted := false
var sumi := 0  # encre (monnaie permanente), affichée sur l'accueil
const HOME_SETTLED := 1.4  # accueil : toutes ses arrivées (sceau 0,4 s, titre 0,6, trait 0,8, sélecteur 1,1) sont finies
var _home_sig: Array = []  # entrées du dernier dessin de l'accueil ou de la pause posés (vide : à refaire)
var gain_sumi := 0  # encre gagnée à la dernière partie
var gain_petals := 0  # pétales (garde-robe) gagnés à la dernière partie
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
var world_kanji := "波"  # clé du monde (jamais affichée) : choisit son kamon (Kamon.WORLD, via UiKit.world_icon)
var world_color := Toon.PRUSSIAN
var stat_shapes := {}  # figure -> nombre réalisé
var build := {}  # pouvoir -> niveau (powers.levels)
var affinities := {}  # école -> [nombre de pouvoirs, palier] (powers.affinities())
var new_prints: Array = []  # Vues gagnées à cette partie (ids de meta.PRINTS)
var new_looks: Array = []  # garde-robe : éléments gagnés par exploit à cette partie ({name, col, col2})
var killer_kind := ""  # type d'ennemi du coup fatal (vide : inconnu ou boss)
var killer_name := ""  # nom du boss du coup fatal
var killer_hint := ""  # son point faible (main.BOSS_HINTS), repris dans le conseil
# victoire : bouton principal vers le monde suivant ("" : REJOUER reste le bouton principal)
var next_label := ""
# ce que la victoire a débloqué (rangée DÉBLOQUÉ) : monde ouvert (0 : aucun) et nouveaux rouleaux
var unlock_world := 0
var unlock_world_name := ""
var unlock_world_kanji := ""
var unlock_world_color := Toon.PRUSSIAN
var unlock_powers: Array = []  # ids des pouvoirs du nouveau palier
var unlock_family := ""  # nom de la famille de rouleaux (power_data.UNLOCK_NAMES)
var unlock_gear: Array = []  # pinceaux, aspects et omamori gagnés : [{"kind": "brush"|"aspect"|"charm", "id", "k"}]
const Gear = preload("res://scripts/gear_data.gd")
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
# mode mesure : appui long sur le titre (accueil) ; deux étiquettes sous la feuille de pause quand il est actif
const LONG_PRESS := 1.5
var measure_on := false
var _lp_t := -1.0  # durée de l'appui sur le titre (< 0 : aucun)
var _lp_p := Vector2.ZERO
var _rep_copy: Control
var _rep_reset: Control
var _rep_cam: Control  # mode développeur : CAMÉRA (panneau de réglage, cam_panel.gd)
var _rep_unlock: Control  # mode développeur : TOUT DÉBLOQUER (second toucher : CONFIRMER)
var _rep_god: Control  # mode développeur : GOD MODE OUI / NON
var god_on := false  # GOD MODE (main) : l'étiquette s'allume en vermillon
const DEV_H := 154.0  # section DEV sous la feuille de pause (u) : titre, deux rangées d'étiquettes, REMETTRE À ZÉRO
const DEV_ROW := 24.0  # haut des étiquettes DEV sous la feuille (u)


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
	_rep_copy = _button("COPIER LES DONNÉES", "label")
	_rep_copy.font = _tag_font
	_rep_copy.icon = "brush"
	_rep_copy.pressed.connect(func(): report_copy_pressed.emit())
	_rep_reset = _button("REMETTRE À ZÉRO", "label")
	_rep_reset.font = _tag_font
	_rep_reset.icon = "replay"
	_rep_reset.pressed.connect(func(): report_reset_pressed.emit())
	_rep_cam = _button("CAMÉRA", "label")
	_rep_cam.font = _tag_font
	_rep_cam.icon = "gear"
	_rep_cam.pressed.connect(func(): camera_pressed.emit())
	_rep_god = _button("GOD MODE : NON", "label")
	_rep_god.font = _tag_font
	_rep_god.icon = "play"
	_rep_god.pressed.connect(func(): god_pressed.emit())
	_rep_unlock = _button("TOUT DÉBLOQUER", "label")
	_rep_unlock.font = _tag_font
	_rep_unlock.icon = "dojo"
	_rep_unlock.danger = true
	_rep_unlock.pressed.connect(func(): _confirm_press("unlock"))
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
		_lp_t = -1.0
		return
	var u := size.x / 400.0
	# appui long sur le titre : un doigt qui glisse l'annule
	if event is InputEventMouseMotion and _lp_t >= 0.0 and (event as InputEventMouseMotion).position.distance_to(_lp_p) > 24.0 * u:
		_lp_t = -1.0
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_lp_t = 0.0 if mb.pressed and _title_rect().has_point(mb.position) else -1.0
	_lp_p = mb.position
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


## Zone du titre IPPITSU de l'accueil (sceau compris), pour l'appui long du mode mesure.
func _title_rect() -> Rect2:
	var u := size.x / 400.0
	var title_y := maxf(_top_y(u) + 170.0 * u, size.y * 0.21)
	var tw := minf(size.x * 0.84, 300.0 * u)
	return Rect2(Vector2((size.x - tw) / 2.0, title_y - 120.0 * u), Vector2(tw, 140.0 * u))


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
		elif which == "unlock":
			unlock_all_pressed.emit()
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
	var _pt := Time.get_ticks_usec() if Perf.on else 0
	if not visible or mode == "hidden":
		if _pt != 0:
			Perf.add(&"menu", _pt)
		return
	size = get_viewport_rect().size
	var dt := UiKit.real_delta()
	_t += dt
	if _confirm_t > 0.0:
		_confirm_t -= dt
		if _confirm_t <= 0.0:
			_confirm = ""
	_safe = UiKit.safe_insets(size)
	if _lp_t >= 0.0:
		_lp_t += dt
		if _lp_t >= LONG_PRESS:
			_lp_t = -1.0
			_swipe_on = false
			measure_toggled.emit()
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
	_rep_copy.visible = mode == "pause" and measure_on
	_rep_reset.visible = mode == "pause" and measure_on
	_rep_cam.visible = mode == "pause" and measure_on
	_rep_god.visible = mode == "pause" and measure_on
	_rep_unlock.visible = mode == "pause" and measure_on
	_sound.visible = mode == "home"  # en pause, le son se règle dans OPTIONS (planche Pause v2)
	_atelier.visible = mode == "home"
	_dojo.visible = mode == "home"
	_wardrobe.visible = mode == "home"
	_help.visible = mode == "home"
	_gear.visible = mode == "home" or mode == "pause"
	_sound.icon = "sound_off" if muted else "sound_on"
	if mode == "home":
		_layout_home(w, h, u)
	elif mode == "over":
		_layout_over(w, h, u, has_next)
	elif mode == "pause":
		_layout_pause(u)
	# accueil et pause : une fois arrivés (accueil 1,4 s : sceau, titre, trait, sélecteur ; pause : feuille, trait,
	# médaillons), l'image ne bouge plus tant que leurs entrées restent les mêmes : plus de redessin à chaque image
	var sig: Array = []
	if mode == "home" and _t > HOME_SETTLED:
		sig = [mode, size, _safe, th_paper, th_wash, th_ink, sel_world, sel_name, sel_kanji, sel_color, sel_locked, sumi]
	elif mode == "pause" and _t > 0.7 + 0.04 * float(pause_powers.size()):
		sig = [mode, size, _safe, th_paper, th_ink, world_color, world_kanji, stat_room, rooms_total, stat_time, stat_score,
			pause_powers.duplicate(), measure_on]
	if sig.is_empty() or sig != _home_sig:
		_home_sig = sig
		queue_redraw()
	if _pt != 0:
		Perf.add(&"menu", _pt)


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
	# trois entrées : ATELIER · DOJO · GARDE-ROBE
	var row: Array = [_atelier, _dojo, _wardrobe]
	var ew := 90.0 * u
	var step := 94.0 * u
	for i in row.size():
		var b: Control = row[i]
		var k := UiKit.ease_out(clampf((_t - 0.9 - 0.08 * i) / 0.4, 0.0, 1.0))
		b.size = Vector2(ew, 74.0 * u)
		b.position = Vector2(w / 2.0 + (float(i) - 1.0) * step - ew / 2.0, py + 108.0 * u + 12.0 * u * (1.0 - k))
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
	# mode développeur : section DEV sous la feuille (remontée d'autant) : CAMÉRA et COPIER LES DONNÉES,
	# REMETTRE À ZÉRO (mesure de fluidité) dessous
	if measure_on:
		var gap := 10.0 * u
		var mw := (pc.size.x - gap) / 2.0
		var mh := 40.0 * u
		var my := pc.end.y + DEV_ROW * u
		_rep_cam.size = Vector2(mw, mh)
		_rep_cam.position = Vector2(pc.position.x, my)
		_rep_copy.size = Vector2(mw, mh)
		_rep_copy.position = Vector2(pc.position.x + mw + gap, my)
		var my2 := my + mh + 8.0 * u
		_rep_god.text = "GOD MODE : OUI" if god_on else "GOD MODE : NON"
		_rep_god.accent = god_on
		_rep_god.size = Vector2(mw, mh)
		_rep_god.position = Vector2(pc.position.x, my2)
		_rep_unlock.text = "CONFIRMER" if _confirm == "unlock" else "TOUT DÉBLOQUER"
		_rep_unlock.accent = _confirm == "unlock"
		_rep_unlock.size = Vector2(mw, mh)
		_rep_unlock.position = Vector2(pc.position.x + mw + gap, my2)
		var zw := 176.0 * u
		_rep_reset.size = Vector2(zw, 34.0 * u)
		_rep_reset.position = Vector2(pc.get_center().x - zw / 2.0, my2 + mh + 8.0 * u)
		for b in [_rep_cam, _rep_copy, _rep_god, _rep_unlock, _rep_reset]:
			var rb: Control = b
			rb.font_size = _fit_font(rb, int(12 * u), (rb.size.x - 52.0 * u * rb.size.y / (46.0 * u)) - 8.0 * u)


func _draw() -> void:
	var _pt := Time.get_ticks_usec() if Perf.on else 0
	if size.x < 10.0:
		if _pt != 0:
			Perf.add(&"menu_draw", _pt)
		return
	if mode == "home":
		_draw_home()
	elif mode == "over":
		_draw_results()
	elif mode == "pause":
		_draw_pause()
	if _pt != 0:
		Perf.add(&"menu_draw", _pt)


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
	UiKit.world_icon(self, sel_kanji, seal.get_center(), seal.size.x * 0.68, sa, Toon.WASHI)
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


## Écran de fin (UI v2, planches Victoire / Défaite, sur la feuille washi de la pause), lisible sans légende à
## deviner : en-tête sumi (le mot, trait vermillon, « Grande Vague · étape 4 sur 8 ») ; défaite : « Tombé face à »
## et le portrait du yokai ; le score et le rang expliqué (« Rang Prunier — prochain : Bambou à 22 000 », RECORD) ;
## puis des sections titrées : la partie (chiffres libellés, deux colonnes), les figures tracées (nommées, les plus
## tracées d'abord), les pouvoirs (victoire), les gains (« +98 encre — pour l'Arbre (Atelier) ») et ce qui vient
## d'être débloqué en toutes lettres ; enfin un conseil en une phrase choisi d'après la partie (_advice).
## Jamais de kanji ni de macron (polices réduites : UiKit.plain), les chiffres en num_font, pas de flou.
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
	# en-tête sumi : VICTOIRE en papier (VAINCU en vermillon clair), trait vermillon, puis le monde et l'étape
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
	UiKit.text(self, _pause_title, word, Vector2(cx + float(sp) * 0.5, head.position.y + 38.0 * u + 4.0 * u * (1.0 - kh)), tfs, Color(wc, a * kh))
	var bk := UiKit.ease_out(clampf((_t - 0.25) / 0.4, 0.0, 1.0))
	if bk > 0.05:
		var swash := Rect2(Vector2(cx - 81.0 * u, head.position.y + 44.0 * u), Vector2(162.0 * u, 9.0 * u))
		draw_colored_polygon(UiKit.swash_points(swash, bk, 5.0), Color(UIColors.VERMILION, a))
	var sub := UiKit.plain("%s · étape %d sur %d" % [world_name, stat_room, rooms_total])
	var sfs := _fit_text(_body_font(), sub, int(UiKit.FS_LABEL * u), head.size.x - 40.0 * u)
	var sk := UiKit.ease_out(clampf((_t - 0.35) / 0.35, 0.0, 1.0))
	UiKit.text(self, _body_font(), sub, Vector2(cx, head.position.y + 73.0 * u), sfs, Color(UIColors.WASHI, 0.8 * a * sk))
	# contenu : blocs empilés (hauteurs mesurées, l'écart se resserre si l'écran est court)
	var lay := _results_layout(u)
	var x0: float = lay["x0"]
	var x1: float = lay["x1"]
	var y: float = lay["top"]
	var gap: float = lay["gap"]
	var blocks: Array = lay["blocks"]
	for i in blocks.size():
		var kind := String(blocks[i][0])
		var bh := float(blocks[i][1])
		var rk := UiKit.ease_out(clampf((_t - 0.45 - 0.1 * float(i)) / 0.3, 0.0, 1.0))
		if rk > 0.0:
			var ra := a * rk
			var ry := y + 6.0 * u * (1.0 - rk)
			match kind:
				"killer":
					_draw_killer(x0, x1, ry, bh, u, ra)
				"score":
					_draw_head(ry, u, ra)
				"stats":
					_draw_stats(x0, x1, ry, u, ra)
				"figures":
					_draw_figures(x0, x1, ry, u, ra)
				"build":
					_draw_build(x0, x1, ry + _SEC_H * u, bh - _SEC_H * u, u, ra)
				"gains":
					_draw_gains(x0, x1, ry, u, ra)
				"advice":
					_draw_advice(x0, x1, ry, bh, u, ra)
		y += bh + gap


const _SEC_H := 20.0  # titre de section (petites capitales, trait d'encre), × u


## Blocs de la feuille et leurs hauteurs (px) ; l'écart entre blocs se resserre (jusqu'à 2 u) si tout ne tient pas,
## et ce qui reste est réparti au-dessus et dessous.
func _results_layout(u: float) -> Dictionary:
	var sheet := _sheet_rect()
	var x0 := sheet.position.x + 18.0 * u
	var x1 := sheet.end.x - 18.0 * u
	var cw := x1 - x0
	var blocks: Array = []
	if not victory:
		blocks.append(["killer", 50.0 * u])
	blocks.append(["score", 80.0 * u])
	blocks.append(["stats", _SEC_H * u + 2.0 * 26.0 * u])
	blocks.append(["figures", _SEC_H * u + float(maxi(1, _fig_rows(u, cw).size())) * 24.0 * u])
	if victory:
		blocks.append(["build", _SEC_H * u + 40.0 * u])
	blocks.append(["gains", _SEC_H * u + _gains_h(u, cw)])
	blocks.append(["advice", _advice_h(u, cw)])
	var total := 0.0
	for b in blocks:
		total += float(b[1])
	var top0 := sheet.position.y + HEADER_H * u + 10.0 * u
	var avail := sheet.end.y - _btn_zone_h(next_label != "") * u - 6.0 * u - top0
	# écran trop court pour tout (beaucoup de déblocages) : les pouvoirs cèdent leur place (ils sont dans la pause)
	if victory and total + 2.0 * u * float(blocks.size() - 1) > avail:
		for b in blocks:
			if String(b[0]) == "build":
				total -= float(b[1])
				blocks.erase(b)
				break
	var n := float(blocks.size() - 1)
	var gap := clampf((avail - total) / maxf(n, 1.0), 2.0 * u, 12.0 * u)
	var spare := maxf(0.0, avail - total - gap * n)
	return {"x0": x0, "x1": x1, "top": top0 + spare * 0.3, "gap": gap, "blocks": blocks}


## Police du texte courant de la feuille (Zen Kaku, sans espacement).
func _body_font() -> Font:
	return UiKit.UI_FONT


## Taille (<= fs) à laquelle `txt` tient dans maxw.
func _fit_text(font: Font, txt: String, fs: int, maxw: float) -> int:
	var f := fs
	while f > 7 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > maxw:
		f -= 1
	return f


## Titre de section : petites capitales pâles et trait d'encre jusqu'au bord (UiKit.section).
func _section(label: String, x0: float, x1: float, y: float, u: float, a: float) -> void:
	_spacing(_small, maxi(1, int(2.0 * u)))
	UiKit.section(self, _small, label, x0, x1, y + 12.0 * u, u, th_ink, a)


## Nom d'un rang en minuscules accentuées (« PRUNIER » -> « Prunier »).
func _rank_word(r: int) -> String:
	var n := Score.rank_name(r)
	if n == "":
		return ""
	return n.substr(0, 1) + n.substr(1).to_lower()


## Picto du rang (prunier, bambou, pin, couronne du maître).
func _rank_icon(r: int) -> String:
	return String(RANK_ICON[clampi(r - 1, 0, RANK_ICON.size() - 1)])


## Ce que dit la ligne du rang : [« Rang Prunier » ou « Sans rang », la suite (« prochain : Bambou à 22 000 »)].
func _rank_text() -> Array:
	var cur := ("Rang " + _rank_word(score_rank)) if score_rank > 0 else "Sans rang"
	var nxt := "rang maximal"
	if score_next > 0:
		nxt = "prochain : %s à %s" % [_rank_word(mini(score_rank + 1, 4)), Score.fmt(score_next)]
	elif score_next < 0:
		nxt = "prochain : %s, en battant le gardien" % _rank_word(4)
	return [cur, nxt]


## Score (compteur qui monte, or après une victoire) et RECORD en pastille à sa droite ; dessous, le rang : tuile de
## sa couleur à picto (elle s'abat une fois les points comptés), « Rang Prunier — prochain : Bambou à 22 000 » ;
## enfin le record du monde (« Nouveau record sur ce monde » ou « Ton record ici : 41 200 »).
func _draw_head(y: float, u: float, a: float) -> void:
	var cx := size.x / 2.0
	var nf := UiKit.num_font()
	var ck := UiKit.ease_out(clampf((_t - 0.3) / 1.0, 0.0, 1.0))
	var sc: Color = GOLD_INK if victory else th_ink
	var nfs := int(36 * u)
	var stxt := Score.fmt(int(round(float(stat_score) * ck)))
	UiKit.text(self, nf, stxt, Vector2(cx, y + 34.0 * u), nfs, Color(sc, a))
	var rec := score_record or new_record
	var ra := a * UiKit.ease_out(clampf((_t - 1.3) / 0.3, 0.0, 1.0))
	if rec:
		var pfs := int(10 * u)
		var pw := _tag_font.get_string_size("RECORD", HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x + 18.0 * u
		var sw := nf.get_string_size(Score.fmt(stat_score), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var pulse := 0.85 + 0.15 * sin(_t * 6.0)
		var pr := Rect2(Vector2(cx + sw / 2.0 + 10.0 * u, y + 12.0 * u), Vector2(pw, 20.0 * u))
		draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD, ra * pulse), int(10 * u)), pr)
		UiKit.text(self, _tag_font, "RECORD", pr.get_center() + Vector2(1.0 * u, pfs * 0.36), pfs, Color(UIColors.SUMI, ra))
	# le rang : tuile + « Rang Prunier » (Shippori) + « — prochain : … » (plus pâle), le groupe centré
	var rt := _rank_text()
	var t1 := String(rt[0])
	var t2 := "  —  " + String(rt[1])
	var ts := 24.0 * u
	var fs1 := int(14 * u)
	var fs2 := int(UiKit.FS_BODY * u)
	_spacing(_title, maxi(1, int(0.5 * u)))
	var maxw := _sheet_rect().size.x - 36.0 * u - ts - 8.0 * u
	var w1 := _title.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x
	var w2 := _body_font().get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	while w1 + w2 > maxw and fs2 > 8:
		fs1 -= 1
		fs2 -= 1
		w1 = _title.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x
		w2 = _body_font().get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var gx := cx - (ts + 8.0 * u + w1 + w2) / 2.0
	var ry := y + 58.0 * u
	var tc := Vector2(gx + ts / 2.0, ry)
	var rk := clampf((_t - 1.3) / 0.22, 0.0, 1.0)
	if score_rank > 0:
		if rk > 0.0:
			var s := 1.0 + 0.6 * (1.0 - UiKit.ease_out(rk))
			draw_set_transform(tc, -0.1, Vector2(s, s))
			var tr := Rect2(Vector2(-ts, -ts) / 2.0, Vector2(ts, ts))
			draw_style_box(UiKit.box(_sb, Color(Score.rank_color(score_rank), a * rk), int(6 * u), Color(UIColors.WASHI, 0.9 * a * rk), int(maxf(1.0, 1.5 * u))), tr)
			UiKit.draw_icon(self, _rank_icon(score_rank), Vector2.ZERO, ts * 0.62, a * rk, UIColors.WASHI)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_dashed_rect(Rect2(tc - Vector2(ts, ts) / 2.0, Vector2(ts, ts)), 5.0 * u, Color(th_ink, 0.35 * a), u)
	var tx := gx + ts + 8.0 * u
	draw_string(_title, Vector2(tx, ry + fs1 * 0.36), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, Color(th_ink, ra))
	draw_string(_body_font(), Vector2(tx + w1, ry + fs1 * 0.36), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(th_ink, 0.62 * ra))
	# le record du monde
	var t3 := ""
	if score_record:
		t3 = "Nouveau record de points sur ce monde"
	elif new_record:
		t3 = "Nouveau record : ton étape la plus lointaine sur ce monde"
	elif best_score > stat_score:
		t3 = "Ton record de points ici : %s" % Score.fmt(best_score)
	if t3 != "":
		var fs3 := int(UiKit.FS_CAPTION * u)
		UiKit.text(self, _body_font(), t3, Vector2(cx, y + 78.0 * u), fs3, Color(GOLD_INK if rec else th_ink, (0.9 if rec else 0.5) * ra))


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


## Coup fatal (défaite) : le portrait (sceau du gardien ou du boss, picto oni pour un yokai) sur un disque sombre,
## « Tombé face à » puis son nom ; un gardien ou le boss est nommé comme tel.
func _draw_killer(x0: float, x1: float, y: float, bh: float, u: float, a: float) -> void:
	var r := Rect2(Vector2(x0, y), Vector2(x1 - x0, bh))
	draw_style_box(UiKit.box(_sb, Color(th_ink, 0.06 * a), int(14 * u), Color(th_ink, 0.14 * a), int(maxf(1.0, 1.0 * u))), r)
	var cc := Vector2(r.position.x + 28.0 * u, r.get_center().y)
	var boss := killer_name != ""
	if boss:
		var s := 34.0 * u
		UiKit.monster_badge(self, _sb, Rect2(cc - Vector2(s, s) / 2.0, Vector2(s, s)), stat_room < rooms_total, a, u)
	else:
		draw_circle(cc, 18.0 * u, Color(UIColors.VERMILION_DARK, 0.22 * a))
		UiKit.draw_icon(self, "hud/oni", cc, 24.0 * u, a, UIColors.VERMILION)
	var tx := cc.x + 28.0 * u
	var nm := _killer_label()
	var cfs := int(UiKit.FS_BODY * u)
	var maxw := r.end.x - 12.0 * u - tx
	if nm == "":
		draw_string(_title, Vector2(tx, r.get_center().y + 6.0 * u), "Tombé au combat", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u), Color(th_ink, a))
		return
	var cap := "Tombé face à"
	if boss:
		cap = "Tombé face au gardien" if stat_room < rooms_total else "Tombé face au boss du monde"
	draw_string(_body_font(), Vector2(tx, r.get_center().y - 5.0 * u), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(th_ink, 0.6 * a))
	_spacing(_title, maxi(1, int(1.0 * u)))
	var nfs := _fit_text(_title, nm, int(17 * u), maxw)
	draw_string(_title, Vector2(tx, r.get_center().y + 14.0 * u), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(th_ink, a))


## Nom du monstre du coup fatal, sans son article (« un oni » -> « Oni »), ou le nom du gardien ; "" : inconnu.
func _killer_label() -> String:
	var who := ""
	if killer_name != "":
		who = killer_name
	elif killer_kind != "":
		who = String(KILLER_NAMES.get(killer_kind, ""))
	if who == "":
		return ""
	for art in ["un ", "une ", "des ", "ton ", "le "]:
		if who.begins_with(art):
			who = who.substr(art.length())
			break
	return UiKit.plain(who.substr(0, 1).to_upper() + who.substr(1))


## Chiffres de la partie, libellés, en deux colonnes : yokai tranchés, plus longue chaîne, durée, figures tracées.
func _draw_stats(x0: float, x1: float, y: float, u: float, a: float) -> void:
	_section("LA PARTIE", x0, x1, y, u, a)
	var nfig := 0
	for k in stat_shapes:
		nfig += int(stat_shapes[k])
	var clock := "%d:%02d" % [int(stat_time / 60.0), int(stat_time) % 60]
	var items := [["hud/oni", "Yokai tranchés", str(stat_kills)], ["hud/chaine", "Plus longue chaîne", str(stat_combo)],
		["effets/duree", "Durée", clock], ["elements/figure", "Figures tracées", str(nfig)]]
	var nf := UiKit.num_font()
	var cgap := 8.0 * u
	var cw := (x1 - x0 - cgap) / 2.0
	var lfs := int(UiKit.FS_BODY * u)
	var vfs := int(15 * u)
	for i in items.size():
		var it: Array = items[i]
		var k := UiKit.ease_out(clampf((_t - 0.8 - 0.06 * float(i)) / 0.3, 0.0, 1.0))
		if k <= 0.0:
			continue
		var ka := a * k
		var cell := Rect2(Vector2(x0 + float(i % 2) * (cw + cgap), y + _SEC_H * u + floorf(float(i) / 2.0) * 26.0 * u + 1.0 * u), Vector2(cw, 23.0 * u))
		draw_style_box(UiKit.box(_sb, Color(th_ink, 0.05 * ka), int(7 * u)), cell)
		var cy := cell.get_center().y
		UiKit.draw_icon(self, String(it[0]), Vector2(cell.position.x + 13.0 * u, cy), 14.0 * u, ka, Color(th_ink, 0.75))
		var val := String(it[2])
		var vw := nf.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs).x
		draw_string(nf, Vector2(cell.end.x - 8.0 * u - vw, cy + vfs * 0.36), val, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs, Color(th_ink, ka))
		var lab := String(it[1])
		var lf := _fit_text(_body_font(), lab, lfs, cell.size.x - 26.0 * u - vw - 12.0 * u)
		draw_string(_body_font(), Vector2(cell.position.x + 25.0 * u, cy + lf * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lf, Color(th_ink, 0.72 * ka))


## Figures tracées dans la partie, les plus tracées d'abord, en lignes : [[figure, nombre, largeur], ...] par ligne.
func _fig_rows(u: float, cw: float) -> Array:
	var figs: Array = []
	for f in UiKit.FIGURES:
		var n := int(stat_shapes.get(String(f), 0))
		if n > 0:
			figs.append([String(f), n])
	figs.sort_custom(func(p, q): return int(p[1]) > int(q[1]) or (int(p[1]) == int(q[1]) and UiKit.FIGURES.find(p[0]) < UiKit.FIGURES.find(q[0])))
	var rows: Array = []
	var cur: Array = []
	var x := 0.0
	var fs := int(UiKit.FS_BODY * u)
	var nf := UiKit.num_font()
	for fd in figs:
		var nm := String(Intro.FIG_NAME.get(String(fd[0]), String(fd[0])))
		var w := 20.0 * u + _body_font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x \
			+ 4.0 * u + nf.get_string_size("×%d" % int(fd[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 1).x + 10.0 * u
		if not cur.is_empty() and x + w > cw:
			rows.append(cur)
			cur = []
			x = 0.0
		cur.append([fd[0], fd[1], w, nm])
		x += w + 6.0 * u
	if not cur.is_empty():
		rows.append(cur)
	return rows


## Figures : une pastille par figure tracée (son picto à sa couleur, son nom, « ×20 »), les plus tracées d'abord.
func _draw_figures(x0: float, x1: float, y: float, u: float, a: float) -> void:
	_section("FIGURES TRACÉES", x0, x1, y, u, a)
	var rows := _fig_rows(u, x1 - x0)
	var fs := int(UiKit.FS_BODY * u)
	var nf := UiKit.num_font()
	var yy := y + _SEC_H * u + 1.0 * u
	if rows.is_empty():
		var none := "Aucune : une boucle ou un zigzag frappe plus fort qu'un trait."
		draw_string(_body_font(), Vector2(x0 + 4.0 * u, yy + 15.0 * u), none, HORIZONTAL_ALIGNMENT_LEFT, -1, _fit_text(_body_font(), none, fs, x1 - x0 - 8.0 * u), Color(th_ink, 0.6 * a))
		return
	var i := 0
	for row in rows:
		var x := x0
		for fd in row:
			var k := UiKit.ease_out(clampf((_t - 0.9 - 0.05 * float(i)) / 0.3, 0.0, 1.0))
			i += 1
			var cw := float(fd[2])
			if k > 0.0:
				var ka := a * k
				var sh := String(fd[0])
				var col: Color = UIColors.FIGURES_INK.get(sh, th_ink)
				var chip := Rect2(Vector2(x, yy), Vector2(cw, 21.0 * u))
				draw_style_box(UiKit.box(_sb, Color(col, 0.08 * ka), int(10 * u), Color(col, 0.35 * ka), int(maxf(1.0, 1.0 * u))), chip)
				var cy := chip.get_center().y
				UiKit.figure_icon(self, sh, Vector2(x + 11.0 * u, cy), 14.0 * u, ka, col)
				var nm := String(fd[3])
				draw_string(_body_font(), Vector2(x + 20.0 * u, cy + fs * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(th_ink, ka))
				var nw := _body_font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(nf, Vector2(x + 24.0 * u + nw, cy + (fs + 1) * 0.36), "×%d" % int(fd[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 1, Color(th_ink, 0.75 * ka))
			x += cw + 6.0 * u
		yy += 24.0 * u


## Pouvoirs de la partie (victoire) : bande des médaillons (les plus rares d'abord, « +N » s'il en reste), puis les
## étiquettes d'élément (picto + NOM) des écoles du build, trois au plus, calées à droite.
func _draw_build(x0: float, x1: float, y: float, rh: float, u: float, a: float) -> void:
	_section("POUVOIRS", x0, x1, y - _SEC_H * u, u, a)
	var cy := y + rh / 2.0
	var x := x0
	var n := _build_list.size()
	var ms := 30.0 * u
	var step := ms + 6.0 * u
	if n == 0:
		draw_string(_body_font(), Vector2(x0 + 4.0 * u, cy + 4.0 * u), "Aucun rouleau pris", HORIZONTAL_ALIGNMENT_LEFT, -1, int(UiKit.FS_BODY * u), Color(th_ink, 0.6 * a))
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


## Ce qui vient d'être débloqué, en toutes lettres : [[libellé, nom, couleur de la pastille], ...].
func _unlock_items() -> Array:
	var out: Array = []
	if victory and unlock_world > 0:
		out.append(["Monde ouvert", UiKit.plain(unlock_world_name if unlock_world_name != "" else "monde %d" % unlock_world), unlock_world_color])
	if victory and not unlock_powers.is_empty():
		var nr := "%d rouleaux à trouver en partie" % unlock_powers.size()
		out.append(["Nouveaux rouleaux", (UiKit.plain(unlock_family) + ", " + nr.to_lower()) if unlock_family != "" else nr, UIColors.GOLD])
	for pid in new_prints:
		if Meta.PRINTS.has(String(pid)):
			out.append(["Estampe", UiKit.plain(String(Meta.PRINTS[String(pid)].get("name", ""))), UIColors.GOLD_DARK])
	if not new_looks.is_empty():
		var names: Array = []
		for lk in new_looks:
			names.append(UiKit.plain(String(lk.get("name", ""))))
		var c0: Color = new_looks[0].get("col", Toon.SUMI)
		out.append(["Garde-robe", ", ".join(names), c0])
	for gd in unlock_gear:
		var g: Dictionary = gd
		var gid := String(g.get("id", ""))
		match String(g.get("kind", "")):
			"charm":
				out.append(["Omamori", UiKit.plain(String(Gear.charm(gid).get("name", gid))), Gear.charm(gid).get("col", Toon.SUMI)])
			"brush":
				out.append(["Pinceau", UiKit.plain(String(Gear.brush(gid)["word"])), Gear.brush(gid)["col"]])
			_:
				out.append(["Aspect du pinceau %s" % String(Gear.brush(gid)["word"]), UiKit.plain(Gear.aspect_name(gid, int(g.get("k", 0)))), Gear.brush(gid)["col"]])
	return out


## Lignes d'un déblocage : « Libellé : nom », le nom coupé mot à mot sous le libellé si besoin.
func _unlock_lines(it: Array, fs: int, w: float) -> PackedStringArray:
	return UiKit.wrap(_body_font(), "%s : %s" % [String(it[0]), String(it[1])], fs, w, [":", "(", "»"])


## Hauteur des gains : encre et pétales, puis une ligne (ou plus) par déblocage.
func _gains_h(u: float, cw: float) -> float:
	var h := 2.0 * 22.0 * u
	var fs := int(UiKit.FS_BODY * u)
	var items := _unlock_items()
	if not items.is_empty():
		h += 4.0 * u
	for it in items:
		h += float(_unlock_lines(it, fs, cw - 18.0 * u).size()) * 15.0 * u + 2.0 * u
	return h


## Gains : « +98 encre — pour l'Arbre (Atelier) », « +1 pétale — pour la Garde-robe » (le chiffre monte), puis ce
## qui a été débloqué (monde, rouleaux, estampes, garde-robe, pinceaux, omamori) en toutes lettres.
func _draw_gains(x0: float, x1: float, y: float, u: float, a: float) -> void:
	_section("GAINS", x0, x1, y, u, a)
	var nf := UiKit.num_font()
	var fs := int(15 * u)
	var bfs := int(UiKit.FS_BODY * u)
	var up: Color = UIColors.JADE_UP_ON_DARK if Toon.ui_dark else UIColors.JADE_UP
	var yy := y + _SEC_H * u + 11.0 * u
	var lines := [["ink", gain_sumi, "encre", "pour l'Arbre (Atelier)", 1.0], ["petal", gain_petals, "pétale" if gain_petals <= 1 else "pétales", "pour la Garde-robe", 1.25]]
	for ln in lines:
		var t0 := float(ln[4])
		var k := UiKit.ease_out(clampf((_t - t0) / 0.3, 0.0, 1.0))
		var cnt := UiKit.ease_out(clampf((_t - t0) / 0.9, 0.0, 1.0))
		if k > 0.0:
			var ka := a * k
			var dc := Vector2(x0 + 10.0 * u, yy)
			var n := int(ln[1])
			if String(ln[0]) == "ink":
				draw_circle(dc, 10.0 * u, Color(UIColors.element_key_color("eau"), ka))
				UiKit.glyph(self, "at_drop", dc, 5.5 * u, UIColors.WASHI, UiKit.NONE, ka)
			else:
				draw_circle(dc, 10.0 * u, Color(UIColors.SAKURA, ka))
				UiKit.glyph(self, "at_petal", dc, 6.5 * u, UIColors.WASHI, UIColors.SAKURA, ka)
			var num := "+%d" % int(round(float(n) * cnt))
			var x := dc.x + 17.0 * u
			draw_string(nf, Vector2(x, yy + fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(up if n > 0 else Color(th_ink, 0.55), ka))
			x += nf.get_string_size("+%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 5.0 * u
			var word := String(ln[2])
			draw_string(_body_font(), Vector2(x, yy + bfs * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs + 1, Color(th_ink, ka))
			x += _body_font().get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs + 1).x
			var why := "  —  " + String(ln[3])
			var wf := _fit_text(_body_font(), why, bfs, x1 - x)
			draw_string(_body_font(), Vector2(x, yy + bfs * 0.36), why, HORIZONTAL_ALIGNMENT_LEFT, -1, wf, Color(th_ink, 0.6 * ka))
		yy += 22.0 * u
	var items := _unlock_items()
	if items.is_empty():
		return
	yy += 4.0 * u - 11.0 * u
	for i in items.size():
		var it: Array = items[i]
		var ls := _unlock_lines(it, bfs, x1 - x0 - 18.0 * u)
		var k := UiKit.ease_out(clampf((_t - 1.3 - 0.08 * float(i)) / 0.3, 0.0, 1.0))
		if k > 0.0:
			var ka := a * k
			var col: Color = it[2]
			var mc := Vector2(x0 + 10.0 * u, yy + 7.5 * u)
			# losange de la couleur de l'objet, cerné d'or : « nouveau »
			var dia := PackedVector2Array([mc + Vector2(0, -6.0) * u, mc + Vector2(6.0, 0) * u, mc + Vector2(0, 6.0) * u, mc + Vector2(-6.0, 0) * u])
			draw_colored_polygon(dia, Color(col, ka))
			dia.append(dia[0])
			draw_polyline(dia, Color(UIColors.GOLD, ka), maxf(1.0, 1.3 * u), true)
			var lab := String(it[0]) + " :"
			for j in ls.size():
				var ly := yy + 7.5 * u + float(j) * 15.0 * u + bfs * 0.36
				var line := String(ls[j])
				var lx := x0 + 22.0 * u
				if j == 0 and line.begins_with(lab):
					draw_string(_body_font(), Vector2(lx, ly), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(GOLD_INK, ka))
					lx += _body_font().get_string_size(lab + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
					line = line.substr(lab.length() + 1)
				draw_string(_body_font(), Vector2(lx, ly), line, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(th_ink, ka))
		yy += float(ls.size()) * 15.0 * u + 2.0 * u


## Conseil d'après la partie : [picto, phrase]. Défaite : tombé face à un gardien ou au boss -> son point faible
## (main.BOSS_HINTS, l'astuce montrée quand la lame ricoche) ; peu
## de figures différentes -> varier les figures ; chaîne courte -> la garder ; sinon la zone rouge (la fuite au trait).
## Victoire : les points qui manquent pour le rang suivant, ou le monde suivant.
func _advice() -> Array:
	var kinds := 0
	for k in stat_shapes:
		if int(stat_shapes[k]) > 0:
			kinds += 1
	var x3 := Score.mult_text(Score.mult(10))
	if victory:
		if score_next > 0:
			return ["hud/chaine", "Encore %s points pour le rang %s : tranche avec des figures (deux fois plus de points) et garde ta chaîne à 10 ou plus (%s)." % [Score.fmt(maxi(0, score_next - stat_score)), _rank_word(mini(score_rank + 1, 4)), x3]]
		return ["hud/couronne", "Rang le plus haut atteint : tente le monde suivant, ou rejoue avec un autre pinceau."]
	if killer_name != "" and killer_hint != "":
		return ["hud/slash", "Face à %s, %s." % [_killer_label(), UiKit.plain(killer_hint.substr(0, 1).to_lower() + killer_hint.substr(1)).trim_suffix(".")]]
	if kinds <= 2:
		return ["elements/figure", "Varie les figures : une boucle ou un zigzag frappe plus fort qu'un trait droit et lance sa technique."]
	if stat_combo < 10:
		return ["hud/chaine", "Ne te fais pas toucher : chaque ruée réussie allonge la chaîne, et à 10 tes points sont multipliés (%s)." % x3]
	return ["shield", "Une zone rouge annonce un coup : trace un trait pour en sortir, la ruée est intouchable au départ."]


## Hauteur du conseil (cadre, picto, phrase sur 3 lignes au plus).
func _advice_h(u: float, cw: float) -> float:
	var ls := UiKit.wrap(_body_font(), String(_advice()[1]), int(UiKit.FS_BODY * u), cw - 58.0 * u, [":", ";", "!", "?", "(", "»"])
	return maxf(46.0 * u, float(ls.size()) * 15.0 * u + 20.0 * u)


## Conseil : cadre or en pointillés, le picto sur une pastille or, CONSEIL en petites capitales, puis la phrase.
func _draw_advice(x0: float, x1: float, y: float, bh: float, u: float, a: float) -> void:
	var r := Rect2(Vector2(x0, y), Vector2(x1 - x0, bh))
	draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD, 0.08 * a), int(12 * u)), r)
	_dashed_rect(r, 12.0 * u, Color(UIColors.GOLD_DARK, 0.9 * a), u)
	var adv := _advice()
	var ic := Vector2(r.position.x + 24.0 * u, r.get_center().y)
	draw_circle(ic, 14.0 * u, Color(UIColors.GOLD, a))
	var key := String(adv[0])
	if key == "shield":
		UiKit.glyph(self, "shield", ic, 9.0 * u, Color(UIColors.SUMI, a), UiKit.NONE, a)
	else:
		UiKit.draw_icon(self, key, ic, 17.0 * u, a, UIColors.SUMI)
	var fs := int(UiKit.FS_BODY * u)
	var tx := r.position.x + 48.0 * u
	var ls := UiKit.wrap(_body_font(), String(adv[1]), fs, x1 - x0 - 58.0 * u, [":", ";", "!", "?", "(", "»"])
	var ty := r.get_center().y - float(ls.size() - 1) * 15.0 * u / 2.0 + fs * 0.36
	for j in ls.size():
		draw_string(_body_font(), Vector2(tx, ty + float(j) * 15.0 * u), String(ls[j]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(th_ink, 0.88 * a))


## Carte de la pause (planche Pause v2 : 352 × 560 u, au centre de l'écran, dans les marges de sécurité).
## Mode développeur : la carte remonte pour laisser la section DEV dessous (DEV_H).
func _pause_card() -> Rect2:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var dev := DEV_H * u if measure_on else 0.0
	var cw := minf(w - 32.0 * u, 352.0 * u)
	var ch := minf(560.0 * u, maxf(510.0 * u, h - _safe.x - _safe.y - 24.0 * u - dev))
	var lo := _safe.x + 12.0 * u
	var cy := clampf((h - dev) * 0.5 - ch / 2.0, lo, maxf(lo, h - _safe.y - 12.0 * u - ch - dev))
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
				UiKit.world_icon(self, world_kanji, ic, 15.0 * u, a, UIColors.WASHI)
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
	if measure_on:
		# section DEV : petit titre entre deux filets, sous la feuille
		var dy := card.end.y + 14.0 * u
		var dfs := int(UiKit.FS_CAPTION * u)
		var dw := _band_font.get_string_size("DÉVELOPPEUR", HORIZONTAL_ALIGNMENT_LEFT, -1, dfs).x
		var dc := Color(UIColors.WASHI, 0.75 * a)
		draw_string(_band_font, Vector2(cx - dw / 2.0, dy + float(dfs) * 0.36), "DÉVELOPPEUR", HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, dc)
		draw_line(Vector2(card.position.x + 8.0 * u, dy), Vector2(cx - dw / 2.0 - 10.0 * u, dy), Color(dc, 0.4 * a), maxf(1.0, u))
		draw_line(Vector2(cx + dw / 2.0 + 10.0 * u, dy), Vector2(card.end.x - 8.0 * u, dy), Color(dc, 0.4 * a), maxf(1.0, u))
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
