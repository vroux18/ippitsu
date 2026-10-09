extends Control
## Accueil (sceau, titre, pinceau JOUER, entrées Atelier · Dojo · Garde-robe), résultats en fin de partie, et pause.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const PowerData = preload("res://scripts/power_data.gd")
const Meta = preload("res://scripts/meta.gd")
const Score = preload("res://scripts/score.gd")
const GOLD_INK := Color("#9A6B12")  # or lisible sur le papier
# feuille de résultats : hauteurs des blocs (× u) et sceaux par ligne
const HEAD_H := 164.0
const STATS_H := 62.0
const SCORE_H := 58.0  # rangée du score (sceau du rang, points, record)
const FIG_H := 80.0
const BTN_H := 132.0  # bas de l'écran réservé aux boutons
const PER_ROW := 10
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
var score_rank := 0  # 0 : aucun, 1..4 : 梅 竹 松 極
var score_next := 0  # points du rang suivant (0 : rang maximal)
var pause_powers: Array = []  # ids des pouvoirs de la partie (rangée d'icônes de la pause)
var world_name := ""
var world_kanji := "波"
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

	# accueil : un coup de pinceau JOUER (sceau 始), trois entrées à icône, icônes nues en haut
	_play = _button("JOUER", "brush")
	_play.kanji = "始"
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

	# résultats : pinceau principal (REJOUER, ou le monde suivant), actions secondaires en texte
	_replay = _button("REJOUER", "brush")
	_replay.lead_icon = "replay"
	_replay.pressed.connect(func(): play_pressed.emit())
	_next = _button("MONDE SUIVANT", "brush")
	_next.pressed.connect(func(): next_pressed.emit())
	_over_atelier = _button("ATELIER", "text")
	_over_atelier.lead_icon = "brush"
	_over_atelier.pressed.connect(func(): atelier_pressed.emit())
	_home = _button("ACCUEIL", "text")
	_home.lead_icon = "home"
	_home.pressed.connect(func(): home_pressed.emit())

	# pause : REPRENDRE au pinceau, la rangée des pouvoirs ouvre MES POUVOIRS, deux actions confirmées
	_resume = _button("REPRENDRE", "brush")
	_resume.lead_icon = "play"
	_resume.pressed.connect(func(): resume_pressed.emit())
	_powers_btn = _button("MES POUVOIRS", "area")
	_powers_btn.pressed.connect(func(): powers_pressed.emit())
	_restart = _button("RECOMMENCER", "text")
	_restart.lead_icon = "replay"
	_restart.pressed.connect(func(): _confirm_press("restart"))
	_quit = _button("QUITTER", "text")
	_quit.lead_icon = "home"
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


func _build_rows() -> int:
	var n := mini(_build_list.size(), PER_ROW * 2)
	return int(ceil(float(n) / float(PER_ROW)))


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
	_sound.visible = mode == "home" or mode == "pause"
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
	queue_redraw()


## Accueil : icônes nues en haut à droite, le pinceau JOUER, puis ATELIER · DOJO · GARDE-ROBE.
func _layout_home(w: float, h: float, u: float) -> void:
	var ty := _top_y(u)
	var ib: float = UiKit.ICON_BTN * u
	_sound.size = Vector2(ib, ib)
	_sound.position = Vector2(w - 14.0 * u - ib, ty)
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
	var row: Array = [_atelier, _dojo, _wardrobe]
	var ew := 108.0 * u
	for i in row.size():
		var b: Control = row[i]
		var k := UiKit.ease_out(clampf((_t - 0.9 - 0.08 * i) / 0.4, 0.0, 1.0))
		b.size = Vector2(ew, 74.0 * u)
		b.position = Vector2(w / 2.0 + (i - 1) * 118.0 * u - ew / 2.0, py + 108.0 * u + 12.0 * u * (1.0 - k))
		b.modulate.a = k
		b.font_size = _fit_font(b, int(11 * u), ew - 6.0 * u)


## Résultats : le pinceau principal (REJOUER, ou le monde suivant) puis les actions en texte.
## Touches bloquées les 0,6 premières secondes.
func _layout_over(w: float, h: float, u: float, has_next: bool) -> void:
	var over_in := UiKit.ease_out(clampf((_t - 0.45) / 0.35, 0.0, 1.0))
	var ink_in := clampf((_t - 0.45) / 0.6, 0.0, 1.0)
	var by := h - _safe.y - BTN_H * u + 20.0 * u * (1.0 - over_in)
	if has_next:
		# victoire avec un monde après : le monde suivant au pinceau (son sceau), puis REJOUER, ATELIER, ACCUEIL
		var nbw := w * 0.88
		var nx := (w - nbw) / 2.0
		_next.text = next_label
		_next.kanji = unlock_world_kanji
		_next.size = Vector2(nbw, UiKit.BTN_MAIN_H * u)
		_next.position = Vector2(nx, by)
		_next.reveal = ink_in
		_next.font_size = _fit_font(_next, int(18 * u), nbw * 0.6)
		_replay.style = "text"
		var tw3 := nbw / 3.0
		var row: Array = [_replay, _over_atelier, _home]
		for i in row.size():
			var rb: Control = row[i]
			rb.size = Vector2(tw3, UiKit.BTN_H * u)
			rb.position = Vector2(nx + tw3 * i, by + 72 * u)
			rb.modulate.a = over_in
			rb.font_size = _fit_font(rb, int(14 * u), tw3 - 12 * u)
	else:
		var obw := minf(w * 0.76, 320.0 * u)
		_replay.style = "brush"
		_replay.modulate.a = 1.0
		_replay.size = Vector2(obw, UiKit.BTN_MAIN_H * u)
		_replay.position = Vector2((w - obw) / 2.0, by)
		_replay.reveal = ink_in
		_replay.font_size = _fit_font(_replay, int(23 * u), obw * 0.62)
		var hw := w * 0.36
		var row2: Array = [_over_atelier, _home]
		for i in row2.size():
			var rb2: Control = row2[i]
			rb2.size = Vector2(hw, UiKit.BTN_H * u)
			rb2.position = Vector2(w / 2.0 - hw + hw * i, by + 72 * u)
			rb2.modulate.a = over_in
			rb2.font_size = _fit_font(rb2, int(15 * u), hw - 12 * u)
	var live := mode == "over" and _t >= 0.6
	for b in [_replay, _next, _over_atelier, _home]:
		var bc: Control = b
		if live:
			bc.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			bc.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pause : réglages en haut de la carte, la rangée des pouvoirs, REPRENDRE au pinceau,
## RECOMMENCER et QUITTER côte à côte (second toucher pour confirmer).
func _layout_pause(u: float) -> void:
	var pc := _pause_card()
	# réglages et son : boutons ronds de l'en-tête commun, centrés à (HEAD_X, HEAD_Y) des coins de la carte
	var ib: float = UiKit.ICON_BTN * u
	var hc := Vector2(UiKit.HEAD_X, UiKit.HEAD_Y) * u
	_gear.size = Vector2(ib, ib)
	_gear.position = pc.position + hc - Vector2(ib, ib) / 2.0
	_sound.size = Vector2(ib, ib)
	_sound.position = Vector2(pc.end.x - hc.x - ib / 2.0, pc.position.y + hc.y - ib / 2.0)
	var pr := _powers_rect(pc, u)
	_powers_btn.position = pr.position
	_powers_btn.size = pr.size
	var rw := pc.size.x - 64.0 * u
	_resume.size = Vector2(rw, UiKit.BTN_MAIN_H * u)
	_resume.position = Vector2(pc.get_center().x - rw / 2.0, pc.position.y + 309.0 * u)
	_resume.reveal = clampf((_t - 0.1) / 0.45, 0.0, 1.0)
	_resume.font_size = _fit_font(_resume, int(21 * u), rw * 0.6)
	_restart.text = "CONFIRMER" if _confirm == "restart" else "RECOMMENCER"
	_restart.accent = _confirm == "restart"
	_quit.text = "CONFIRMER" if _confirm == "quit" else "QUITTER"
	_quit.accent = _confirm == "quit"
	var hw := (pc.size.x - 40.0 * u) / 2.0
	_restart.size = Vector2(hw, UiKit.BTN_H * u)
	_restart.position = Vector2(pc.position.x + 20.0 * u, pc.position.y + 408.0 * u)
	_quit.size = Vector2(hw, UiKit.BTN_H * u)
	_quit.position = Vector2(pc.position.x + 20.0 * u + hw, pc.position.y + 408.0 * u)
	_restart.font_size = _fit_font(_restart, int(14 * u), hw - 14.0 * u)
	_quit.font_size = _fit_font(_quit, int(14 * u), hw - 14.0 * u)


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
	# sceau du monde (délavé s'il est scellé), cadenas posé sur son coin
	var seal := Rect2(sr.position + Vector2(10.0 * u, 7.0 * u), Vector2(26.0 * u, sr.size.y - 14.0 * u))
	var scol: Color = th_ink.lerp(th_paper, 0.5) if sel_locked else sel_color
	UiKit.seal(self, seal, sel_kanji, scol, Toon.WASHI, sa, u * 0.8, float(sel_world))
	if sel_locked:
		var lc := seal.end - Vector2(1.0, 3.0) * u
		draw_circle(lc, 8.0 * u, Color(th_paper, sa))
		UiKit.glyph(self, "at_lock", lc, 5.5 * u, th_ink, th_paper, sa)
	# MONDE N (VERROUILLÉ en vermillon), puis le nom
	var x0 := seal.end.x + 8.0 * u
	var x1 := sr.end.x - 16.0 * u
	var cx := (x0 + x1) / 2.0
	var cap := UiKit.plain("MONDE %d" % sel_world)
	if sel_locked:
		cap = UiKit.plain("MONDE %d  ·  VERROUILLÉ" % sel_world)
	var cfs := int(UiKit.FS_CAPTION * u)
	var cw := _small.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
	if cw > x1 - x0 and cw > 0.0:
		cfs = maxi(1, int(float(cfs) * (x1 - x0) / cw))
	var ccol := Color(Toon.VERMILION, 0.9 * sa) if sel_locked else Color(th_ink, UiKit.A_CAPTION * sa)
	UiKit.text(self, _small, cap, Vector2(cx, sr.position.y + 17.0 * u), cfs, ccol)
	var nm := UiKit.plain(sel_name)
	var nfs := int(UiKit.FS_HEADING * u)
	var nw := _title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	if nw > x1 - x0 and nw > 0.0:
		nfs = maxi(1, int(float(nfs) * (x1 - x0) / nw))
	UiKit.text(self, _title, nm, Vector2(cx, sr.end.y - 10.0 * u), nfs, Color(th_ink, (0.55 if sel_locked else 1.0) * sa))


## Compteur d'encre : un bâton d'encre et le nombre.
func _draw_ink_counter(p: Vector2, u: float) -> void:
	var stick := Rect2(p + Vector2(0, -12) * u, Vector2(9, 24) * u)
	draw_style_box(UiKit.box(_sb, th_ink, int(2 * u), Toon.GOLD, int(maxf(1.0, 1.5 * u))), stick)
	var fs := int(17 * u)
	draw_string(_ui, p + Vector2(16, 6) * u, str(sumi), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, th_ink)


## Écran de fin : la feuille de résultats posée sur le jeu délavé.
## Titre, chiffres de la partie, build, figures, puis les gains révélés un à un.
func _draw_results() -> void:
	var w := size.x
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.45, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(th_wash, 0.72 * a))
	# lavis plus dense sous les actions (texte lisible sur le jeu)
	var vb := size.y - _safe.y - (BTN_H + 16.0) * u
	_veil(vb, vb + 40.0 * u, th_wash, 0.0, 0.22 * a)
	_veil(vb + 40.0 * u, size.y, th_wash, 0.22 * a, 0.22 * a)
	var lay := _results_layout(u)
	var v: float = lay["v"]
	var card := Rect2(Vector2(14 * u, float(lay["top"]) + 24 * u * (1.0 - a)), Vector2(w - 28 * u, float(lay["height"])))
	# feuille de washi commune aux bords barbés (vagues seigaiha pâles derrière l'ensō), trait de la couleur du monde en tête
	UiKit.sheet(self, card, th_paper, th_ink, a, u, 3.0, maxf(0.0, HEAD_H * v / u - 22.0))
	var band := Rect2(card.position + Vector2(card.size.x * 0.2, 9.0 * u), Vector2(card.size.x * 0.6, 7.0 * u))
	var bk := UiKit.ease_out(clampf(_t / 0.6, 0.0, 1.0))
	if bk > 0.05:
		draw_colored_polygon(UiKit.swash_points(band, bk, 2.0), Color(world_color, 0.9 * a))
	var x0 := card.position.x + 18 * u
	var x1 := card.end.x - 18 * u
	var y := card.position.y
	_draw_head(card, y, u, v, a)
	y += HEAD_H * v
	_draw_score(x0, x1, y, u, v, a)
	y += SCORE_H * v
	_draw_stats(x0, x1, y, u, v, a)
	y += STATS_H * v
	_draw_build(x0, x1, y, u, v, a)
	y += float(lay["build_h"]) * v
	_draw_figures(x0, x1, y, u, v, a)
	y += FIG_H * v
	_draw_gains(x0, x1, y, u, v, a)
	y += float(lay["gains_h"]) * v
	if _unlock_rows() > 0:
		_draw_unlocks(x0, x1, y, u, v, a)
	if new_record:
		_draw_record_stamp(Vector2(card.end.x - 52 * u, card.position.y + 46 * v), u, a)


## Hauteurs de la feuille (selon le build et les Vues gagnées), resserrées si l'écran est court.
func _results_layout(u: float) -> Dictionary:
	var rows := _build_rows()
	var build_h := 50.0
	if rows > 0:
		build_h = 28.0 + 38.0 * rows + (26.0 if not affinities.is_empty() else 0.0)
	var gains_h := 56.0 + 42.0 * mini(new_prints.size(), 3)
	var unlock_h := 0.0
	if _unlock_rows() > 0:
		unlock_h = 26.0 + 42.0 * _unlock_rows()
	var content := HEAD_H + SCORE_H + STATS_H + build_h + FIG_H + gains_h + unlock_h + 12.0
	var avail := (size.y - _safe.x - _safe.y) / u - 14.0 - BTN_H - 12.0
	var k := clampf(avail / content, 0.72, 1.0)
	var top := 14.0 + _safe.x / u + maxf(0.0, avail - content) * 0.35
	return {"v": u * k, "top": top * u, "height": content * u * k, "build_h": build_h, "gains_h": gains_h}


## Lignes de la rangée DÉBLOQUÉ : le monde ouvert, la famille de rouleaux (victoire seulement).
func _unlock_rows() -> int:
	if not victory:
		return 0
	var n := 0
	if unlock_world > 0:
		n += 1
	if not unlock_powers.is_empty():
		n += 1
	return n


## Titre de section commun (UiKit.section) : sceau à kanji, petit mot, trait de pinceau fini d'un shuriken.
func _section(label: String, x0: float, x1: float, y: float, u: float, a: float, kanji := "") -> void:
	UiKit.section(self, _ui, label, x0, x1, y, u, th_ink, a, kanji)


## Ensō (plein en victoire, à la mesure des salles franchies sinon), titre et sous-titres.
func _draw_head(card: Rect2, y: float, u: float, v: float, a: float) -> void:
	var cx := card.get_center().x
	var ec := Vector2(cx, y + 52 * v)
	var ring_col := Toon.GOLD if victory else Toon.VERMILION
	var prog := 1.0
	if not victory:
		prog = clampf(float(stat_room) / float(maxi(rooms_total, 1)), 0.08, 1.0)
	var full := TAU * 0.92
	draw_arc(ec, 30 * u, -PI / 2.0, -PI / 2.0 + full, 48, Color(th_ink, 0.08 * a), 7 * u, true)
	var sweep := full * prog * UiKit.ease_out(clampf((_t - 0.15) / 0.7, 0.0, 1.0))
	if sweep > 0.01:
		draw_arc(ec, 30 * u, -PI / 2.0, -PI / 2.0 + sweep, 48, Color(ring_col, a), 7 * u, true)
	UiKit.text(self, UiKit.TITLE_FONT, world_kanji, ec + Vector2(0, 10 * u), int(28 * u), Color(th_ink, a))
	var kh := UiKit.ease_out(clampf((_t - 0.25) / 0.35, 0.0, 1.0))
	var hy := y + 118 * v + 8 * u * (1.0 - kh)
	var wn := UiKit.plain(world_name.to_upper())
	if victory:
		UiKit.text(self, _title, "VICTOIRE", Vector2(cx, hy), int(34 * u), Color(GOLD_INK, a * kh))
		UiKit.text(self, _ui, wn, Vector2(cx, y + 142 * v), int(12 * u), Color(th_ink, 0.6 * a * kh))
	else:
		UiKit.text(self, UiKit.TITLE_FONT, "Tombé, étape %d" % stat_room, Vector2(cx, hy), int(28 * u), Color(th_ink, a * kh))
		UiKit.text(self, _ui, wn, Vector2(cx, y + 138 * v), int(11 * u), Color(th_ink, 0.5 * a * kh))
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


## Score : sceau du rang qui s'abat à gauche, points qui montent, record du monde dessous,
## nom du rang et ce qu'il faut pour le suivant à droite (de quoi donner envie de rejouer le monde).
func _draw_score(x0: float, x1: float, y: float, u: float, v: float, a: float) -> void:
	var k := UiKit.ease_out(clampf((_t - 0.3) / 0.35, 0.0, 1.0))
	if k <= 0.0:
		return
	var ka := a * k
	draw_style_box(UiKit.box(_sb, Color(th_ink, 0.05 * ka), int(10 * u)), Rect2(Vector2(x0 - 6 * u, y + 2 * v), Vector2(x1 - x0 + 12 * u, 52 * v)))
	# sceau du rang : il s'abat une fois les points comptés
	var hs := 40.0 * v
	var hc := Vector2(x0 + 4 * u + hs / 2.0, y + 28 * v)
	var rk := clampf((_t - 1.45) / 0.22, 0.0, 1.0)
	if score_rank > 0:
		if rk > 0.0:
			var s := 1.0 + 0.7 * (1.0 - UiKit.ease_out(rk))
			draw_set_transform(hc, -0.12, Vector2(s, s))
			UiKit.hanko(self, Rect2(Vector2(-hs / 2.0, -hs / 2.0), Vector2(hs, hs)), Score.rank_glyph(score_rank), Score.rank_color(score_rank), Toon.WASHI, a * rk, u, 5.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_rect(Rect2(hc - Vector2(hs, hs) / 2.0, Vector2(hs, hs)), Color(th_ink, 0.25 * ka), false, maxf(1.0, 1.5 * u))
		UiKit.text(self, UiKit.UI_FONT, "—", hc + Vector2(0, 5 * u), int(14 * u), Color(th_ink, 0.35 * ka))
	# points : le compteur monte
	var ck := UiKit.ease_out(clampf((_t - 0.4) / 1.0, 0.0, 1.0))
	var tx := hc.x + hs / 2.0 + 12 * u
	draw_string(UiKit.UI_FONT, Vector2(tx, y + 15 * v), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.5 * u), Color(th_ink, 0.5 * ka))
	draw_string(UiKit.TITLE_FONT, Vector2(tx, y + 38 * v), Score.fmt(int(round(float(stat_score) * ck))), HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u), Color(th_ink, ka))
	var rfs := int(9 * u)
	if score_record:
		var pk := clampf((_t - 1.45) / 0.2, 0.0, 1.0)
		var pulse := 0.8 + 0.2 * sin(_t * 6.0)
		draw_string(UiKit.UI_FONT, Vector2(tx, y + 51 * v), "NOUVEAU MEILLEUR SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color(Toon.VERMILION, a * pk * pulse))
	elif best_score > 0:
		draw_string(UiKit.UI_FONT, Vector2(tx, y + 51 * v), "RECORD  " + Score.fmt(best_score), HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color(th_ink, 0.5 * ka))
	# rang : son nom, puis le palier suivant
	var ra := a * UiKit.ease_out(clampf((_t - 1.5) / 0.3, 0.0, 1.0))
	if ra <= 0.0:
		return
	var rx := x1 - 2 * u
	var lab := "RANG"
	var nm := Score.rank_name(score_rank) if score_rank > 0 else "SANS RANG"
	var lfs := int(9.5 * u)
	var nfs := int(15 * u)
	var lw := UiKit.UI_FONT.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var nw := UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	draw_string(UiKit.UI_FONT, Vector2(rx - lw, y + 15 * v), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(th_ink, 0.5 * ra))
	var nc: Color = Score.rank_color(score_rank) if score_rank > 0 else Color(th_ink, 0.45)
	draw_string(UiKit.TITLE_FONT, Vector2(rx - nw, y + 35 * v), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(nc, nc.a * ra))
	if score_next > 0:
		var nxt := "SUIVANT À " + Score.fmt(score_next)
		var xw := UiKit.UI_FONT.get_string_size(nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
		draw_string(UiKit.UI_FONT, Vector2(rx - xw, y + 51 * v), nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color(th_ink, 0.5 * ra))


## Rangée de chiffres : salle, ennemis, chaîne max, temps, figures.
func _draw_stats(x0: float, x1: float, y: float, u: float, v: float, a: float) -> void:
	var figs := 0
	for f in stat_shapes.keys():
		figs += int(stat_shapes[f])
	var cols := [["ÉTAPE", "%d/%d" % [stat_room, rooms_total]], ["ENNEMIS", str(stat_kills)], ["CHAÎNE MAX", str(stat_combo)],
		["TEMPS", "%d:%02d" % [int(stat_time / 60.0), int(stat_time) % 60]], ["FIGURES", str(figs)]]
	var cw := (x1 - x0) / float(cols.size())
	draw_style_box(UiKit.box(_sb, Color(th_ink, 0.05 * a), int(10 * u)), Rect2(Vector2(x0 - 6 * u, y + 2 * v), Vector2(x1 - x0 + 12 * u, 50 * v)))
	for i in cols.size():
		var k := UiKit.ease_out(clampf((_t - 0.4 - 0.07 * i) / 0.35, 0.0, 1.0))
		var c := x0 + cw * (i + 0.5)
		var col: Array = cols[i]
		UiKit.text(self, UiKit.UI_FONT, String(col[0]), Vector2(c, y + 19 * v), int(9.5 * u), Color(th_ink, 0.5 * a * k))
		UiKit.text(self, UiKit.TITLE_FONT, String(col[1]), Vector2(c, y + 43 * v + 6 * u * (1.0 - k)), int(19 * u), Color(th_ink, a * k))
		if i > 0:
			draw_line(Vector2(x0 + cw * i, y + 11 * v), Vector2(x0 + cw * i, y + 45 * v), Color(th_ink, 0.12 * a), 1.5 * u)


## Ton build : sceaux des pouvoirs (liseré de rareté, points de niveau), puis les affinités d'école.
func _draw_build(x0: float, x1: float, y: float, u: float, v: float, a: float) -> void:
	var cx := (x0 + x1) / 2.0
	var hk := UiKit.ease_out(clampf((_t - 0.6) / 0.3, 0.0, 1.0))
	_section("TON BUILD", x0, x1, y + 13 * v, u, a * hk, "巻")
	var n := _build_list.size()
	if n == 0:
		UiKit.text(self, _ui, "AUCUN ROULEAU", Vector2(cx, y + 42 * v), int(11 * u), Color(th_ink, 0.4 * a * hk))
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
			draw_circle(c, rr, Color(th_ink, 0.8 * ka))
			UiKit.text(self, UiKit.UI_FONT, "+%d" % (n - shown + 1), c + Vector2(0, 4 * u), int(11 * u), Color(th_wash, ka))
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
		var dot := Color(GOLD_INK if lv >= int(sd[5]) else th_ink, ka)
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
		var scol: Color = sdd.get("color", th_ink)
		var wch: float = widths[i]
		var rect := Rect2(Vector2(px, chy - 10 * u), Vector2(wch, 20 * u))
		if tier > 0:
			draw_style_box(UiKit.box(_sb, Color(scol, ck), int(10 * u)), rect)
		else:
			draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(10 * u), Color(th_ink, 0.3 * ck), int(maxf(1.0, 1.2 * u))), rect)
		var dc := Vector2(px + 10 * u, chy)
		var disc: Color = Toon.WASHI if tier > 0 else scol
		draw_circle(dc, 7 * u, Color(disc, ck))
		UiKit.school_icon(self, s, dc, 4.6 * u, scol if tier > 0 else Toon.WASHI, ck, disc)
		var tc := Color(Toon.WASHI, ck) if tier > 0 else Color(th_ink, 0.6 * ck)
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
	_section("FIGURES", x0, x1, y + 13 * v, u, a * hk, "形")
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
		UiKit.text(self, UiKit.TITLE_FONT, "×%d" % n, Vector2(c.x, y + 72 * v), int(14 * u), Color(th_ink, fa))


## Gains : l'encre qui monte, les sceaux, puis chaque nouvelle Vue qui glisse en place.
func _draw_gains(x0: float, x1: float, y: float, u: float, v: float, a: float) -> void:
	var hk := UiKit.ease_out(clampf((_t - 1.25) / 0.3, 0.0, 1.0))
	var label := "GAINS"
	if new_prints.size() > 3:
		label = "GAINS  ·  %d VUES" % new_prints.size()
	_section(label, x0, x1, y + 13 * v, u, a * hk, "金")
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
		draw_style_box(UiKit.box(_sb, Color(th_ink, ia), int(2 * u), Color(Toon.GOLD, ia), int(maxf(1.0, 1.5 * u))), stick)
		draw_string(UiKit.TITLE_FONT, Vector2(lx + 17 * u, ry), num, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(th_ink, ia))
		draw_string(UiKit.UI_FONT, Vector2(lx + 23 * u + nw, ry), "ENCRE", HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, Color(th_ink, 0.6 * ia))
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
		draw_string(UiKit.TITLE_FONT, Vector2(sx + 26 * u, ry), stxt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(th_ink, sa))
		draw_string(UiKit.UI_FONT, Vector2(sx + 32 * u + sw, ry), sword, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, Color(th_ink, 0.6 * sa))
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
		draw_string(UiKit.TITLE_FONT, Vector2(tx, top + 17 * v), UiKit.plain(String(p.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Color(th_ink, pa))
		var kind := String(p.get("kind", ""))
		var sub := "NOUVELLE APPARENCE"
		if Meta.LOOK_NAMES.has(kind):
			sub += "  ·  " + String(Meta.LOOK_NAMES[kind]).to_upper()
		draw_string(UiKit.UI_FONT, Vector2(tx, top + 31 * v), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Color(GOLD_INK, pa))
		# pastille de la couleur portée
		var lc: Color = p.get("col", th_ink)
		var dc := Vector2(row.end.x - 16 * u, top + 19 * v)
		draw_circle(dc, 8 * u, Color(th_ink, 0.8 * pa))
		draw_circle(dc, 6.5 * u, Color(lc, pa))


## DÉBLOQUÉ : le monde que la victoire ouvre (son sceau), puis la nouvelle famille de rouleaux
## (quelques pictogrammes et « +N rouleaux »), qui glissent en place après les gains.
func _draw_unlocks(x0: float, x1: float, y: float, u: float, v: float, a: float) -> void:
	var t0 := 2.35 + 0.3 * mini(new_prints.size(), 3)
	var hk := UiKit.ease_out(clampf((_t - t0) / 0.3, 0.0, 1.0))
	if hk <= 0.0:
		return
	_section("DÉBLOQUÉ", x0, x1, y + 13 * v, u, a * hk, "開")
	var i := 0
	if unlock_world > 0:
		var pk := UiKit.ease_out(clampf((_t - t0 - 0.15) / 0.35, 0.0, 1.0))
		if pk > 0.0:
			var pa := a * pk
			var top := y + 24 * v
			var row := Rect2(Vector2(x0 - 4 * u + 30 * u * (1.0 - pk), top), Vector2(x1 - x0 + 8 * u, 38 * v))
			draw_style_box(UiKit.box(_sb, Color(unlock_world_color, 0.1 * pa), int(8 * u), Color(unlock_world_color, 0.7 * pa), int(maxf(1.0, 1.2 * u))), row)
			# sceau du monde, cerclé d'or
			var sc := Vector2(row.position.x + 24 * u, top + 19 * v)
			var sr := 14.0 * u
			draw_circle(sc, sr + 2 * u, Color(Toon.GOLD, pa))
			draw_circle(sc, sr, Color(unlock_world_color, pa))
			UiKit.text(self, UiKit.TITLE_FONT, unlock_world_kanji, sc + Vector2(0, 6 * u), int(16 * u), Color(Toon.WASHI, pa))
			var tx := sc.x + sr + 12 * u
			draw_string(UiKit.TITLE_FONT, Vector2(tx, top + 17 * v), UiKit.plain(unlock_world_name), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Color(th_ink, pa))
			draw_string(UiKit.UI_FONT, Vector2(tx, top + 31 * v), "NOUVEAU MONDE  ·  MONDE %d" % unlock_world, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Color(GOLD_INK, pa))
		i += 1
	if not unlock_powers.is_empty():
		var qk := UiKit.ease_out(clampf((_t - t0 - 0.15 - 0.3 * i) / 0.35, 0.0, 1.0))
		if qk > 0.0:
			var qa := a * qk
			var top2 := y + 24 * v + i * 42 * v
			var row2 := Rect2(Vector2(x0 - 4 * u + 30 * u * (1.0 - qk), top2), Vector2(x1 - x0 + 8 * u, 38 * v))
			draw_style_box(UiKit.box(_sb, Color(Toon.GOLD, 0.12 * qa), int(8 * u), Color(Toon.GOLD, 0.6 * qa), int(maxf(1.0, 1.2 * u))), row2)
			# quelques pictogrammes des nouveaux rouleaux, en éventail
			var shown := mini(unlock_powers.size(), 4)
			var ir := 10.0 * u
			for k in shown:
				var ik := UiKit.ease_out(clampf((_t - t0 - 0.3 - 0.3 * i - 0.06 * k) / 0.25, 0.0, 1.0))
				var ic := Vector2(row2.position.x + 16 * u + k * 15 * u, top2 + 19 * v)
				draw_circle(ic, ir + 1.5 * u, Color(th_paper, qa * ik))
				UiKit.power_icon(self, String(unlock_powers[k]), ic, ir * (0.6 + 0.4 * ik), qa * ik)
			var tx2 := row2.position.x + 16 * u + (shown - 1) * 15 * u + ir + 12 * u
			var fam := unlock_family if unlock_family != "" else "Nouveaux rouleaux"
			draw_string(UiKit.TITLE_FONT, Vector2(tx2, top2 + 17 * v), UiKit.plain(fam), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Color(th_ink, qa))
			var n := unlock_powers.size()
			var sub := ("+%d ROULEAU" % n) if n == 1 else ("+%d ROULEAUX" % n)
			draw_string(UiKit.UI_FONT, Vector2(tx2, top2 + 31 * v), sub + "  ·  DANS LES TIRAGES", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Color(GOLD_INK, qa))


## Tampon « NOUVEAU RECORD » qui s'abat en haut à droite de la feuille.
func _draw_record_stamp(c: Vector2, u: float, a: float) -> void:
	var k := clampf((_t - 2.0) / 0.22, 0.0, 1.0)
	if k <= 0.0:
		return
	var s := 1.0 + 0.8 * (1.0 - UiKit.ease_out(k))
	var ka := a * k
	draw_set_transform(c, -0.2, Vector2(s, s))
	var r := Rect2(Vector2(-40, -19) * u, Vector2(80, 38) * u)
	draw_style_box(UiKit.box(_sb, Color(th_paper, 0.85 * ka), int(6 * u), Color(Toon.VERMILION, ka), int(2.5 * u)), r)
	draw_rect(r.grow(-4 * u), Color(Toon.VERMILION, 0.6 * ka), false, 1.0 * u)
	UiKit.text(self, UiKit.UI_FONT, "NOUVEAU", Vector2(0, -2 * u), int(11 * u), Color(Toon.VERMILION, ka))
	UiKit.text(self, UiKit.UI_FONT, "RECORD", Vector2(0, 12 * u), int(11 * u), Color(Toon.VERMILION, ka))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Carte de la pause (au centre de l'écran, dans les marges de sécurité).
func _pause_card() -> Rect2:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var cw := minf(w * 0.9, 360.0 * u)  # même largeur que les options et MES POUVOIRS
	var ch := 470.0 * u
	var lo := _safe.x + 12.0 * u
	var cy := clampf(h * 0.5 - ch / 2.0, lo, maxf(lo, h - _safe.y - 12.0 * u - ch))
	return Rect2(Vector2((w - cw) / 2.0, cy), Vector2(cw, ch))


## Rangée des pouvoirs de la pause : la toucher ouvre MES POUVOIRS.
func _powers_rect(card: Rect2, u: float) -> Rect2:
	return Rect2(card.position + Vector2(20.0 * u, 204.0 * u), Vector2(card.size.x - 40.0 * u, 86.0 * u))


## Pause : voile d'encre, feuille de washi, sceau du monde, la partie en cours, les pouvoirs.
func _draw_pause() -> void:
	var w := size.x
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.25, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.8 * a))
	var card := _pause_card()
	var dy := 16.0 * u * (1.0 - a)
	card.position.y += dy
	# feuille de washi commune (options, mes pouvoirs) : vagues seigaiha pâles derrière le sceau et le titre
	UiKit.sheet(self, card, th_paper, th_ink, a, u, 6.0, 126.0)
	# trait de la couleur du monde en tête de feuille
	var band := Rect2(card.position + Vector2(70.0 * u, 16.0 * u), Vector2(card.size.x - 140.0 * u, 7.0 * u))
	var bk := UiKit.ease_out(clampf(_t / 0.5, 0.0, 1.0))
	if bk > 0.05:
		draw_colored_polygon(UiKit.swash_points(band, bk, 4.0), Color(world_color, 0.85 * a))
	# sceau du monde, puis le titre souligné de vermillon (même titre que les autres écrans)
	var seal := Rect2(Vector2(card.get_center().x - 23.0 * u, card.position.y + 36.0 * u), Vector2(46, 46) * u)
	UiKit.hanko(self, seal, world_kanji, world_color, Toon.WASHI, a, u, 4.0)
	UiKit.screen_title(self, _title, "PAUSE", Vector2(card.get_center().x, card.position.y + 116.0 * u), u, th_ink, a, "", 0.0, UiKit.ease_out(clampf((_t - 0.1) / 0.35, 0.0, 1.0)))
	# la partie en cours
	var cols := [["ÉTAPE", "%d / %d" % [stat_room, rooms_total]], ["CHAÎNE", str(stat_combo)], ["SCORE", Score.fmt(stat_score)],
		["TEMPS", "%d:%02d" % [int(stat_time / 60.0), int(stat_time) % 60]]]
	for i in cols.size():
		var cx := card.position.x + card.size.x * (0.14 + 0.24 * i)
		UiKit.text(self, _ui, String(cols[i][0]), Vector2(cx, card.position.y + 154 * u), int(UiKit.FS_CAPTION * u), Color(th_ink, UiKit.A_CAPTION * a))
		UiKit.text(self, UiKit.TITLE_FONT, String(cols[i][1]), Vector2(cx, card.position.y + 180 * u), int(UiKit.FS_NUMBER * u), Color(th_ink, a))
		if i > 0:
			var lx := card.position.x + card.size.x * (0.02 + 0.24 * i)
			draw_line(Vector2(lx, card.position.y + 144 * u), Vector2(lx, card.position.y + 184 * u), Color(th_ink, 0.12 * a), 1.5 * u)
	# pouvoirs de la partie : pastilles en rangée ; la rangée entière ouvre MES POUVOIRS
	var pr := _powers_rect(card, u)
	draw_style_box(UiKit.box(_sb, Color(th_ink, 0.035 * a), int(12 * u), Color(th_ink, 0.13 * a), int(maxf(1.0, u))), pr)
	var ids: Array = pause_powers
	var iy := pr.position.y + 32.0 * u
	if ids.is_empty():
		UiKit.text(self, _ui, "AUCUN ROULEAU POUR L'INSTANT", Vector2(pr.get_center().x, iy + 4.0 * u), int(10 * u), Color(th_ink, 0.4 * a))
	else:
		var r := 14.0 * u
		var gap := 2.0 * r + 5.0 * u
		var n := mini(ids.size(), maxi(1, int((pr.size.x - 24.0 * u) / gap)))
		if ids.size() > n:
			n -= 1  # place pour le « +N »
		var shown := maxi(n, 0)
		var slots := shown + (1 if ids.size() > shown else 0)
		var x0 := pr.get_center().x - gap * float(slots - 1) / 2.0
		for i in shown:
			var ik := UiKit.ease_out(clampf((_t - 0.15 - 0.03 * i) / 0.25, 0.0, 1.0))
			UiKit.power_icon(self, String(ids[i]), Vector2(x0 + gap * i, iy), r * (0.7 + 0.3 * ik), a * ik)
		if ids.size() > shown:
			var mc := Vector2(x0 + gap * shown, iy)
			draw_circle(mc, r, Color(th_ink, 0.75 * a))
			UiKit.text(self, _ui, "+%d" % (ids.size() - shown), mc + Vector2(1.0, 4.0 * u), int(11 * u), Color(th_paper, a))
	var lab := "MES POUVOIRS  ·  %d" % ids.size()
	var lfs := int(11 * u)
	var ltw := UiKit.text(self, _ui, lab, Vector2(pr.get_center().x - 6.0 * u, pr.position.y + 70.0 * u), lfs, Color(th_ink, 0.8 * a))
	# kunai pointé vers la droite : la rangée s'ouvre
	var chx := pr.get_center().x - 6.0 * u + ltw / 2.0 + 16.0 * u
	var chy := pr.position.y + 70.0 * u - lfs * 0.36
	UiKit.kunai(self, Vector2(chx, chy), Vector2.RIGHT, 18.0 * u, Color(Toon.VERMILION, a))
	# confirmation attendue (RECOMMENCER, QUITTER)
	if _confirm != "":
		var what := "RECOMMENCER" if _confirm == "restart" else "QUITTER"
		UiKit.text(self, _ui, "TOUCHE ENCORE POUR %s  ·  PARTIE PERDUE" % what, Vector2(card.get_center().x, card.position.y + 400.0 * u), int(9 * u), Color(Toon.VERMILION, a))
