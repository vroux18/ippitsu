extends Control
## Interface de jeu dessinée à la main, planches Main / Nuit / Specs de l'UI v2 (design/ui_v2, §2 du handoff).
## Zones (en u, 1 u = 1/400 de la largeur) : 0–32 encoche ; 36–80 barre haute (pilule d'étape à gauche :
## picto du monde, « 5/8 », crans de combat ; puce de multiplicateur et score à droite, puis la pause ronde) ;
## 88–130 bandeau d'événement / coach, en haut ; avec un gardien, makimono 380 × 44 en 90–154 ; 136–430 jeu pur ;
## 434–682 grappes latérales : à gauche jauge de vie en fourreau (cœur en pommeau, segments inclinés), filet d'XP et
## hexagone de niveau ; à droite goutte d'encre, jauge claire et sceau d'ultime ; 690–836 zone du pouce, libre.
## Le HUD ne dépend pas du thème : fond sumi 92 %, contour papier 1,5 ; aucun kanji, des pictos ; les chiffres en
## Zen Kaku Gothic New 900 tabulaire (UiKit.num_font) ; les halos sans flou (cercles ou contours concentriques).
## Par-dessus : sceaux de figure et de pouvoir, barres de vie des ennemis, voile de mort, rideau, lavis du torii.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
const InkStroke = preload("res://scripts/ink_stroke.gd")
const Score = preload("res://scripts/score.gd")

signal pause_pressed

# état fourni par main à chaque image
var hp := 5
var max_hp := 5
var elan := 1.0
var elan_m := 14.0  # longueur max du trait (graduations tous les 2 m)
var elan_empty := false
var wave := 1  # étape en cours (1..rooms_total)
var rooms_total := 8
var gate_hint := false
var boss_name := ""
var boss_hint := ""  # point faible du boss affiché sous sa barre
var boss_ratio := 1.0
var boss_has_shield := false  # le boss a un bouclier (puce bleue sous le makimono)
var boss_shield := 0.0  # bouclier du boss (0..1)
var boss_vuln := 0.0  # secondes de vulnérabilité restantes (0 = bouclier levé)
var boss_vuln_len := 6.0
var boss_phase := 0  # phase en cours et nombre de phases (encoches d'or du makimono) ; 0 : inconnu, pas d'encoche
var boss_phases := 0
var wipe := 0.0  # rideau d'encre de la transition entre étapes (0..1)
# expédition (main) : avancée dans l'étape (0..1, < 0 = cachée), zones [début, fin, état 0/1/2], combats
var stage_k := -1.0
var top_off := 0.0  # marge du haut : encoche / barre d'état du téléphone (zone de sécurité) + un peu d'air
var stage_marks: Array = []
var enc_done := 0
var enc_total := 0
var wash := 0.0  # lavis d'encre du rituel du torii (0..1), qui s'étend depuis wash_c
var wash_c := Vector2.ZERO
var wash_out := false  # vrai : l'encre se retire (fondu) après la reconstruction
var hurt_flash := 0.0
var dying := 0.0  # 0..1 : l'écran se délave pendant la mort
var world_kanji := "波"  # clé du monde (main) : sert à choisir son picto (UIColors.WORLD_ICON), jamais affiché
var world_color := Toon.PRUSSIAN
var combo := 0
var chain := 0  # ruées réussies d'affilée sans prendre de coup
var chain_left := 1.0  # temps restant avant extinction (0..1)
var chain_mult := 1.0
var chain_break := 0.0  # éclat quand la chaîne se brise (1 -> 0)
var chain_lost := 0
var score := -1  # points de la partie (-1 : pas de score, dojo)
var score_mult := 1.0  # multiplicateur de points de la chaîne en cours
var enemy_bars: Array = []  # [position écran, ratio de vie, (ratio de bouclier, élite)]
const SHIELD_BAR := Color("#6FB7FF")
const ELITE_MARK := Color("#FFB23E")
var in_play := false
var dojo := false  # dojo (main) : HUD réduit à l'encre et à l'ultime, l'en-tête du dojo remplace les pastilles
var pause_enabled := true  # main : vrai seulement quand la pause est possible (état « play »)
var level := 1
var xp_ratio := 0.0
var gold := 0
var _toast := ""
var _toast_t := -1.0
var screen_flash := 0.0  # éclair blanc bref à la mise à mort
var show_fps := false  # `?fps` dans l'adresse web
var hero_screen := Vector2(-9999, -9999)  # position du héros à l'écran (main), pour les sceaux de figure
# mode pad (option, au lancement) : zone du bas où l'on trace ; vide en mode « sur l'écran »
var pad := Rect2()
var pad_active := false
var pad_alpha := 1.0  # le pad s'efface après les premiers traits (option)
var pad_trail := PackedVector2Array()  # geste en cours dans le pad (coordonnées écran)
var _shapes: Array = []  # figures enchaînées : [forme, âge]
# sceaux de pouvoir : petit cachet rond (couleur de l'élément + pictogramme) au-dessus de l'effet qui vient d'agir
const POP_LIFE := 1.15  # assez long pour être lu (les sceaux brefs agaçaient)
const POP_MAX := 2  # sceaux visibles en même temps
const POP_CD := 1200  # ms : un même pouvoir ne ressort pas avant
var _pops: Array = []  # [clé, pictogramme, couleur, position monde, âge, majeur]
var _pop_cd := {}  # clé -> instant (ms) où le pouvoir peut ressortir
var shape_name := ""
var _shape_t := 9.0
var _real_dt := 0.0
var ult := 0.0  # jauge d'ultime (0..1), écrite par main

var _shown_hp := -1
var _lost: Array = []  # segments perdus : [index, âge] (traînée washi, puis vidage)
var _combo_shown := 0
var _combo_t := 0.0
var _banner_big := ""
var _banner_small := ""
var _banner_col := Toon.SUMI
var _banner_t := -1.0
var _banner_len := 2.0
var _banner_icon := "ink"  # pictogramme du sceau du bandeau (UiKit.glyph)
var _bfit_at := Vector2(-1, -1)  # (u, place) des tailles de texte ajustées du bandeau
var _bfit_big := 12
var _bfit_small := 7
var cine := 0.0  # bandes de cinéma (0..1) pendant l'entrée d'un boss
var _card: Array = []  # carton titre de boss : [picto (clé UiKit.icon), nom, épithète, sous-titre]
var _card_mini := false
var _card_t := -1.0
var _card_len := 2.0
var _pause: Control
var _idle_drawn := false  # la dernière image dessinée était vide (hors jeu, rien d'animé)
var _idle_size := Vector2.ZERO
var _t := 0.0
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné
var _title_sp := FontVariation.new()  # Shippori espacée (bandeau, nom du gardien)
var _caps_sp := FontVariation.new()  # Zen Kaku espacée (petites capitales)
var _xp_shown := 0.0  # remplissage affiché de la barre d'expérience (rattrape xp_ratio)
var _lv_shown := -1
var _lv_flash := 0.0  # éclat du passage de niveau (1 -> 0)
var _gain_from := 0  # premier segment regagné (soin)
var _gain_t := 0.0
var _gold_shown := -1
var _score_shown := 0.0  # le compteur rattrape le score
var _score_int := -1  # valeur affichée (son texte est refait seulement quand elle change)
var _score_txt := "0"
var _score_pop := 0.0  # bond de la pastille de score à chaque gain (1 -> 0)
var _mult_shown := 1.0
var _mult_txt := ""  # texte de la puce (refait au changement de palier)
var _mult_pop := 0.0  # le multiplicateur monte d'un palier (1 -> 0 en 180 ms)
var _mult_lost := 1.0  # multiplicateur perdu (chaîne brisée ou éteinte) : flash blanc puis fondu
var _mult_lost_txt := ""
var _mult_lost_t := 0.0  # 1 -> 0 en 300 ms
var _score_pops: Array = []  # primes annoncées sous le score : [libellé, points, âge]
var _band_k := 68.0  # bas de la zone du haut (en u, sous la marge), lissé : s'allonge sous la barre du gardien
var _wave_shown := -1  # étape affichée (texte refait au changement)
var _wave_txt := "1"
var _rooms_txt := "/8"
var _lv_txt := "1"
var _ult_full_t := 0.0  # tampon du sceau d'ultime quand il se remplit (1 -> 0)
var _ult_was_full := false
var _boss_trail := 1.0  # traînée washi derrière la vie du gardien (rattrape boss_ratio lentement)
var _boss_seen := ""  # nom du gardien dont la traînée est réglée
var _shield_breaks := 0  # boucliers brisés sur le gardien en cours (puce « ×N »)
var _vuln_was := false
var _sheath := PackedVector2Array()  # fourreau de la jauge de vie (coordonnées du gabarit 32 × 188)
var _heart := PackedVector2Array()  # cœur en pommeau (même gabarit, translaté de +5)
var _drop := PackedVector2Array()  # goutte d'encre (gabarit 18 × 22)
var _maki := PackedVector2Array()  # corps du makimono (gabarit 380 × 44)
var _banner_shape := PackedVector2Array()  # coup de pinceau du bandeau (gabarit 228 × 38, normalisé 0..1)
var _banner_line := PackedVector2Array()  # son filet vermillon (normalisé)
var _fill_pts := PackedVector2Array()  # polygone de travail (remplissages du makimono)
const HUD_JADE := Color("#3E9C8C")  # XP sous 80 %, puce ×1,5
const HUD_WOOD := Color("#6B4A2E")  # rouleaux du makimono
const MAKI_ROLLS := [18.0, 346.0]  # x des deux rouleaux (gabarit 380 × 44)
const ULT_RING_OFF := Color("#3A3846")  # anneau du sceau d'ultime tant qu'il n'est pas plein
const BAR_Y := 24.0  # haut de la barre haute (en u, sous la marge : 36 avec la marge par défaut de 12)
const BAR_H := 44.0
const TOP_K := 68.0  # bas de la barre haute (en u, sous la marge)
const BOSS_Y := 78.0  # haut du makimono (en u, sous la marge : 90 avec la marge par défaut)
const BOSS_K := 148.0  # bas de la zone du gardien (barre + libellés)
const CLUSTER_Y := 434.0  # haut des grappes latérales (en u depuis le haut de l'écran)
const CLUSTER_H := 248.0  # leur hauteur (jusqu'à 682)
const LIFE_SEG_TOP := 34.0  # segments de vie : de y 34 à 178 du gabarit
const LIFE_SEG_BOT := 178.0
const LOST_HOLD := 1.4  # la traînée washi d'un segment perdu reste ce temps, puis se vide en 0,2 s
const LOST_FADE := 0.2


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause = InkButton.new()
	_pause.style = "area"  # la cible tactile ; le rond papier est dessiné par le HUD (indépendant du thème)
	_pause.icon = "pause"
	add_child(_pause)
	_pause.pressed.connect(func(): pause_pressed.emit())
	_title_sp.base_font = UiKit.TITLE_FONT
	_caps_sp.base_font = UiKit.UI_FONT
	# fourreau : M7 24 C 12 22, 20 22, 26 25 L 27 100 L 25.5 182 C 19 185, 12 185, 6 182 L 5 100 Z
	_sheath.append(Vector2(7, 24))
	_cubic(_sheath, Vector2(7, 24), Vector2(12, 22), Vector2(20, 22), Vector2(26, 25), 6)
	_sheath.append(Vector2(27, 100))
	_sheath.append(Vector2(25.5, 182))
	_cubic(_sheath, Vector2(25.5, 182), Vector2(19, 185), Vector2(12, 185), Vector2(6, 182), 6)
	_sheath.append(Vector2(5, 100))
	# cœur : M16 21 C 6 14, 3.5 9.5, 6 5.5 C 8.5 2, 13.5 2.5, 16 6.5 C 18.5 2.5, 23.5 2, 26 5.5 C 28.5 9.5, 26 14, 16 21 (+5)
	_heart.append(Vector2(16, 21))
	_cubic(_heart, Vector2(16, 21), Vector2(6, 14), Vector2(3.5, 9.5), Vector2(6, 5.5), 8)
	_cubic(_heart, Vector2(6, 5.5), Vector2(8.5, 2), Vector2(13.5, 2.5), Vector2(16, 6.5), 8)
	_cubic(_heart, Vector2(16, 6.5), Vector2(18.5, 2.5), Vector2(23.5, 2), Vector2(26, 5.5), 8)
	_cubic(_heart, Vector2(26, 5.5), Vector2(28.5, 9.5), Vector2(26, 14), Vector2(16, 21), 8)
	for i in _heart.size():
		_heart[i] += Vector2(0, 5)
	# goutte : pointe en (9, 2), rond de rayon 7 en (9, 14.5)
	_drop.append(Vector2(9, 2))
	for i in 17:
		var a := lerpf(-0.95, PI + 0.95, float(i) / 16.0)
		_drop.append(Vector2(9, 14.5) + Vector2(cos(a), sin(a)) * 7.0)
	# makimono : M34 9 C 120 5, 260 6, 346 8 L 346 34 C 260 37, 120 37, 34 35 Z
	_maki.append(Vector2(34, 9))
	_cubic(_maki, Vector2(34, 9), Vector2(120, 5), Vector2(260, 6), Vector2(346, 8), 10)
	_maki.append(Vector2(346, 34))
	_cubic(_maki, Vector2(346, 34), Vector2(260, 37), Vector2(120, 37), Vector2(34, 35), 10)
	# bandeau : M6 10 C 40 3, 120 5, 222 7 L 218 16 L 224 22 C 150 34, 70 34, 4 30 L 10 21 Z (ramené en 0..1)
	_banner_shape.append(Vector2(6, 10))
	_cubic(_banner_shape, Vector2(6, 10), Vector2(40, 3), Vector2(120, 5), Vector2(222, 7), 8)
	_banner_shape.append(Vector2(218, 16))
	_banner_shape.append(Vector2(224, 22))
	_cubic(_banner_shape, Vector2(224, 22), Vector2(150, 34), Vector2(70, 34), Vector2(4, 30), 8)
	_banner_shape.append(Vector2(10, 21))
	for i in _banner_shape.size():
		_banner_shape[i] = _banner_shape[i] / Vector2(228.0, 38.0)
	_banner_line.append(Vector2(30, 31))
	_cubic(_banner_line, Vector2(30, 31), Vector2(90, 35), Vector2(150, 34), Vector2(200, 30), 6)
	for i in _banner_line.size():
		_banner_line[i] = _banner_line[i] / Vector2(228.0, 38.0)


## Ajoute à `out` n points d'une courbe de Bézier cubique (sans son point de départ).
static func _cubic(out: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		var c := p2.lerp(p3, t)
		out.append(a.lerp(b, t).lerp(b.lerp(c, t), t))


## Les polices réduites n'ont pas les voyelles longues (ō, ū) : on les écrit sans macron.
static func plain(s: String) -> String:
	return UiKit.plain(s)


func is_over_pause(p: Vector2) -> bool:
	return _pause != null and _pause.visible and Rect2(_pause.position, _pause.size).grow(8.0).has_point(p)


## Petite annonce discrète (vague suivante, combat, butin…) sous la zone du haut.
func toast(text: String) -> void:
	_toast = plain(text)
	_toast_t = 0.0


## Carton titre d'un boss qui entre : sceau picto estampillé (plus de kanji), nom au pinceau, épithète.
func boss_card(kanji: String, title: String, epithet: String, sub: String, small: bool, length: float) -> void:
	# le kanji du boss n'est plus affiché (UI v2) : le sceau porte le picto couronne (gardien) ou oni (boss)
	_card = ["hud/couronne" if small else "hud/oni", plain(title), plain(epithet), plain(sub)]
	_card_mini = small
	_card_t = 0.0
	_card_len = length
	if kanji == "":
		_card[0] = ""


## Le carton s'efface vite (entrée passée d'un toucher, ou finie).
func end_boss_card(fade := 0.25) -> void:
	if _card_t >= 0.0:
		_card_len = minf(_card_len, _card_t + fade)


## Bandeau d'annonce : début de partie, nouvelle étape, boss…
func banner(big: String, small := "", col := Toon.SUMI, length := 2.0) -> void:
	_banner_big = plain(big)
	_banner_small = plain(small)
	_banner_col = col
	_banner_t = 0.0
	_banner_len = length
	_bfit_at = Vector2(-1, -1)  # nouveaux textes : tailles à réajuster
	# sceau du bandeau d'après l'annonce ; zone ou étape nettoyée : brève et festive
	var up := _banner_big.to_upper()
	_banner_icon = "ink"
	if up.contains("NETTOY"):
		_banner_icon = "torii"
		_banner_len = minf(length, 1.4)
	elif up.contains("VICTOIRE"):
		_banner_icon = "star"
	elif up.contains("SANCTUAIRE"):
		_banner_icon = "oni" if up.contains("UN ") else "torii"
	elif up.begins_with("BIEN"):
		_banner_icon = "check"
	elif up.begins_with("RAT"):
		_banner_icon = "cross"
	elif up.contains("TUTORIEL"):
		_banner_icon = "ink"
	elif col == Toon.VERMILION:
		_banner_icon = "oni"
	else:
		_banner_icon = "path"


func _process(_delta: float) -> void:
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_update_safe_top()
	_t += real
	if hurt_flash > 0.0:
		hurt_flash = maxf(0.0, hurt_flash - real * 2.5)
	_tick_status(real)  # segments de vie, expérience, niveau, score, multiplicateur, ultime, gardien
	# combo : reste affiché un moment après la ruée
	if combo >= 2:
		_combo_shown = combo
		_combo_t = 1.2
	elif _combo_t > 0.0:
		_combo_t -= real
	chain_break = maxf(0.0, chain_break - real * 1.6)
	screen_flash = maxf(0.0, screen_flash - real * 4.0)
	if _toast_t >= 0.0:
		_toast_t += real
		if _toast_t > 1.4:
			_toast_t = -1.0
	_shape_t += real
	for i in range(_pops.size() - 1, -1, -1):
		var pp: Array = _pops[i]
		pp[4] = float(pp[4]) + real
		if float(pp[4]) >= POP_LIFE or not in_play:
			_pops.remove_at(i)
	_real_dt = real
	if _banner_t >= 0.0:
		_banner_t += real
		if _banner_t > _banner_len:
			_banner_t = -1.0
	if _card_t >= 0.0:
		_card_t += real
		if _card_t > _card_len:
			_card_t = -1.0
	_band_k = lerpf(_band_k, _below_k(), 1.0 - exp(-real * 9.0))
	var u := size.x / 400.0
	_pause.visible = in_play and pause_enabled and dying <= 0.0 and not dojo
	_pause.size = Vector2(BAR_H, BAR_H) * u
	_pause.position = Vector2(size.x - 58.0 * u, BAR_Y * u + top_off)
	# hors jeu (accueil, carte, refuge…) et sans rien d'animé : _draw ne dessinerait rien ;
	# une dernière image vide, puis plus de redessin tant que rien ne change
	var idle := not in_play and enemy_bars.is_empty() and screen_flash <= 0.0 and hurt_flash <= 0.0 \
		and cine <= 0.001 and _card_t < 0.0 and _banner_t < 0.0 and dying <= 0.0 and not show_fps \
		and wipe <= 0.001 and wash <= 0.001 and size == _idle_size
	if not idle or not _idle_drawn:
		queue_redraw()
	_idle_drawn = idle
	_idle_size = size


func _draw() -> void:
	var sz := size
	if sz.x < 10.0:
		return
	var u := sz.x / 400.0

	# barres de vie des ennemis touchés
	for b in enemy_bars:
		var p: Vector2 = b[0]
		var r: float = b[1]
		# [position, vie] ou [position, vie, bouclier, élite]
		var sr := 0.0
		var el := false
		if b.size() >= 4:
			sr = float(b[2])
			el = bool(b[3])
		var bw := (40.0 if el else 30.0) * u
		var rect := Rect2(p - Vector2(bw / 2.0, 0), Vector2(bw, 5 * u))
		draw_rect(rect.grow(1.5 * u), Color(Toon.SUMI, 0.75))
		draw_rect(Rect2(rect.position, Vector2(bw * clampf(r, 0.0, 1.0), rect.size.y)), Toon.VERMILION)
		if sr > 0.0:
			# bouclier : fine barre bleue posée sur la barre de vie
			var srect := Rect2(rect.position - Vector2(0, 4.5 * u), Vector2(bw, 3 * u))
			draw_rect(srect.grow(1.2 * u), Color(Toon.SUMI, 0.75))
			draw_rect(Rect2(srect.position, Vector2(bw * clampf(sr, 0.0, 1.0), srect.size.y)), SHIELD_BAR)
		if el:
			# élite : losange d'or au bout de la barre
			UiKit.diamond(self, rect.position + Vector2(-5.0 * u, rect.size.y * 0.5), 4.0 * u, ELITE_MARK)

	if in_play:
		_draw_pad(u)
		# dojo : ni vie, ni XP, ni score, ni étape ; les sceaux de figure laissent la place au verdict du dojo
		# (sous son en-tête). Restent l'encre et l'ultime.
		if not dojo:
			_draw_life(u)
			_draw_xp(u)
		_draw_ink(u)
		draw_set_transform(Vector2(0, top_off))
		if not dojo:
			_draw_shape_pop(sz, u)
			_draw_stage(u)
			_draw_score(sz, u)
			_draw_pause_disc(sz, u)
		if boss_name != "":
			_draw_boss(sz, u)
		draw_set_transform(Vector2.ZERO)
		_draw_power_pops(sz, u)
		if gate_hint and not dojo:
			_draw_gate_hint(sz, u)

	if screen_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.97, 0.9, screen_flash * 0.5))

	# coup reçu : liseré vermillon et coins d'encre
	if hurt_flash > 0.0:
		var hc := Color(Toon.VERMILION, 0.4 * hurt_flash)
		var hb := 16.0 * u
		draw_rect(Rect2(0, 0, sz.x, hb), hc)
		draw_rect(Rect2(0, sz.y - hb, sz.x, hb), hc)
		draw_rect(Rect2(0, 0, hb, sz.y), hc)
		draw_rect(Rect2(sz.x - hb, 0, hb, sz.y), hc)

	if _toast_t >= 0.0 and in_play:
		var ta := clampf(minf(_toast_t / 0.15, (1.4 - _toast_t) / 0.3), 0.0, 1.0)
		var tfs := int(13 * u)
		var tw := UiKit.UI_FONT.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		# sous la zone du haut et sous le bandeau d'événement quand il est là
		var ty := top_off + (_below_k() + (64.0 if _banner_t >= 0.0 else 22.0) + 14.0) * u
		if dojo:
			ty = top_off + 210.0 * u  # sous le bandeau, loin du verdict du dojo
		var tp := Vector2(sz.x / 2.0 - tw / 2.0, ty - 6 * u * (1.0 - ta))
		draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI_HUD_BG, UIColors.SUMI_HUD_BG.a * ta), 999, Color(UIColors.WASHI, 0.55 * ta), maxi(1, int(1.5 * u))),
			Rect2(tp + Vector2(-14 * u, -tfs - 4 * u), Vector2(tw + 28 * u, tfs + 14 * u)))
		draw_string(UiKit.UI_FONT, tp, _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(UIColors.WASHI, ta))

	if cine > 0.001:
		_draw_cine(sz, u)
	if _card_t >= 0.0 and _card.size() == 4:
		_draw_card(sz, u)

	if _banner_t >= 0.0:
		_draw_banner(sz, u)

	# mort : l'image se délave dans le papier, une coulure d'encre descend
	if dying > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(Toon.WASHI, 0.55 * dying))
		var drip := PackedVector2Array()
		var steps := 20
		for i in steps + 1:
			var x := sz.x * float(i) / steps
			var y := sz.y * 0.22 * dying * (0.6 + 0.4 * sin(float(i) * 2.1) + 0.3 * sin(float(i) * 0.7))
			drip.append(Vector2(x, y))
		drip.append(Vector2(sz.x, 0))
		drip.append(Vector2(0, 0))
		draw_colored_polygon(drip, Color(Toon.SUMI, 0.85 * dying))

	if show_fps:
		draw_string(UiKit.num_font(), Vector2(10 * u, sz.y - 12 * u), "%d FPS" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Toon.VERMILION)

	# rideau d'encre : un grand coup de pinceau qui balaie l'écran
	if wipe > 0.001:
		# bande par bande (quadrilatères simples) : jamais de polygone qui se recoupe au début du balayage
		var edge := sz.x * 1.4 * wipe
		var n := 24
		var prev := Vector2.ZERO
		for i in n + 1:
			var y := -10.0 + (sz.y + 20.0) * float(i) / n
			var jag := sin(float(i) * 1.7) * 14.0 * u + sin(float(i) * 0.6) * 22.0 * u
			var cur := Vector2(maxf(edge - y * 0.25 + jag, -10.0), y)
			if i > 0 and (cur.x > -9.0 or prev.x > -9.0):
				var q := PackedVector2Array([Vector2(-10, prev.y)])
				if prev.x > -9.99:
					q.append(prev)
				if cur.x > -9.99:
					q.append(cur)
				q.append(Vector2(-10, cur.y))
				if q.size() >= 3:
					draw_colored_polygon(q, Toon.SUMI)
			prev = cur
	if wash > 0.001:
		_draw_wash(sz, u)


# ------------------------------------------------------------------ état et animations

## Animations du bloc d'état : segments perdus ou regagnés, expérience, niveau, score, multiplicateur, ultime,
## traînée et boucliers du gardien. Sans allocation à chaque image : les listes sont parcourues à l'envers,
## les textes refaits seulement quand leur valeur change.
func _tick_status(real: float) -> void:
	if _shown_hp < 0:
		_shown_hp = hp
	if hp < _shown_hp:
		for i in range(hp, _shown_hp):
			_lost.append([i, 0.0])
	elif hp > _shown_hp:
		_gain_from = _shown_hp
		_gain_t = 0.6
	_shown_hp = hp
	for i in range(_lost.size() - 1, -1, -1):
		var l: Array = _lost[i]
		l[1] = float(l[1]) + real
		if float(l[1]) >= LOST_HOLD + LOST_FADE or int(l[0]) < hp:
			_lost.remove_at(i)
	_gain_t = maxf(0.0, _gain_t - real)
	# expérience : la barre rattrape la valeur, repart de zéro au niveau suivant
	var xr := clampf(xp_ratio, 0.0, 1.0)
	if _lv_shown < 0:
		_lv_shown = level
		_xp_shown = xr
		_lv_txt = str(level)
	if level != _lv_shown:
		if level > _lv_shown:
			_lv_flash = 1.0
			_xp_shown = 0.0
		_lv_txt = str(level)
	_lv_shown = level
	if xr > _xp_shown + 0.002:
		_xp_shown = lerpf(_xp_shown, xr, 1.0 - exp(-real * 7.0))
	else:
		_xp_shown = xr
	_lv_flash = maxf(0.0, _lv_flash - real * 1.2)
	# étape : texte refait au changement
	if wave != _wave_shown:
		_wave_shown = wave
		_wave_txt = str(wave)
		_rooms_txt = "/%d" % rooms_total
	# or : un gain s'annonce comme une prime, sous le score
	if _gold_shown < 0:
		_gold_shown = gold
	if gold > _gold_shown and score >= 0:
		score_pop("OR", gold - _gold_shown)
	_gold_shown = gold
	# score : le compteur monte vers sa valeur (la pastille bondit), il repart de zéro à la partie suivante
	var sc := float(maxi(score, 0))
	if sc < _score_shown:
		_score_shown = sc
	elif sc > _score_shown + 0.5:
		if _score_pop < 0.5:
			_score_pop = 1.0
		_score_shown = minf(sc, lerpf(_score_shown, sc, 1.0 - exp(-real * 9.0)) + 600.0 * real)
	_score_pop = maxf(0.0, _score_pop - real * 4.0)
	var si := int(_score_shown)
	if si != _score_int:
		_score_int = si
		_score_txt = Score.fmt(si)
	# multiplicateur : bond quand il monte d'un palier (scale 1 → 1,25 → 1 en 180 ms), flash blanc puis fondu
	# (300 ms) quand il retombe
	if absf(score_mult - _mult_shown) > 0.01:
		if score_mult > _mult_shown:
			_mult_pop = 1.0
		elif _mult_shown >= 1.5:
			_mult_lost = _mult_shown
			_mult_lost_txt = _mult_txt
			_mult_lost_t = 1.0
		_mult_shown = score_mult
		_mult_txt = Score.mult_text(score_mult)
	_mult_pop = maxf(0.0, _mult_pop - real / 0.18)
	_mult_lost_t = maxf(0.0, _mult_lost_t - real / 0.3)
	for i in range(_score_pops.size() - 1, -1, -1):
		var sp: Array = _score_pops[i]
		sp[2] = float(sp[2]) + real
		if float(sp[2]) >= 1.6:
			_score_pops.remove_at(i)
	# ultime : tampon quand le sceau se remplit
	var full := ult >= 1.0
	if full and not _ult_was_full:
		_ult_full_t = 1.0
	_ult_was_full = full
	_ult_full_t = maxf(0.0, _ult_full_t - real / 0.22)
	# gardien : la traînée washi suit la vie avec retard ; compte des boucliers brisés
	if boss_name != _boss_seen:
		_boss_seen = boss_name
		_boss_trail = boss_ratio
		_shield_breaks = 0
		_vuln_was = false
	if boss_ratio < _boss_trail:
		_boss_trail = maxf(boss_ratio, _boss_trail - real * 0.35)
	else:
		_boss_trail = boss_ratio
	var vuln := boss_vuln > 0.0
	if vuln and not _vuln_was:
		_shield_breaks += 1
	_vuln_was = vuln


## Bas de la zone du haut (en u, sous la marge) : sous la barre haute, ou sous le makimono du gardien et ses libellés.
func _below_k() -> float:
	if boss_name == "":
		return TOP_K
	return BOSS_K + (14.0 if boss_hint != "" else 0.0)


## Bas de la zone du haut, en pixels écran (barre haute, ou barre du gardien) : le coach pose ses bulles dessous.
func top_clear() -> float:
	return top_off + _band_k * size.x / 400.0


## Haut des grappes latérales (pixels) : y 434 u de la maquette, remonté sur un écran court ou au-dessus du pad,
## jamais au-dessus de la zone du haut.
func _cluster_top() -> float:
	var u := size.x / 400.0
	var y := minf(CLUSTER_Y * u, size.y - (CLUSTER_H + 134.0) * u)
	if pad.size.x >= 10.0:
		y = minf(y, pad.position.y - (CLUSTER_H + 12.0) * u)
	return maxf(y, top_off + (_band_k + 16.0) * u)


## Piste de la jauge d'encre (bord droit), sans son cadre : le coach la montre.
func ink_rect() -> Rect2:
	var u := size.x / 400.0
	var y0 := _cluster_top()
	return Rect2(Vector2(size.x - 34.0 * u, y0 + 40.0 * u), Vector2(20.0 * u, 142.0 * u))


## Fourreau de la jauge de vie (bord gauche).
func life_rect() -> Rect2:
	var u := size.x / 400.0
	return Rect2(Vector2(8.0 * u, _cluster_top()), Vector2(32.0 * u, 188.0 * u))


## Filet d'expérience, collé à la vie côté terrain.
func xp_rect() -> Rect2:
	var u := size.x / 400.0
	return Rect2(Vector2(42.0 * u, _cluster_top() + 36.0 * u), Vector2(11.0 * u, 150.0 * u))


## Polygone fermé en contour (le dernier point rejoint le premier).
func _outline(pts: PackedVector2Array, col: Color, w: float) -> void:
	draw_polyline(pts, col, w, true)
	draw_line(pts[pts.size() - 1], pts[0], col, w, true)


# ------------------------------------------------------------------ grappe gauche : vie, XP, niveau

## Vie en fourreau (gabarit 32 × 188 posé en x 8, y 434) : coup de pinceau sumi 92 % cerné de papier, cœur en pommeau,
## segments inclinés de 3,5 (coupe de lame) de y 34 à 178. Plein : vermillon + reflet blanc 40 % ; vide : washi 12 % ;
## perdu : flash, secousse ±3 u sur 120 ms, traînée washi 55 % puis vidage en 200 ms ; soin : le segment s'allume.
## Critique (1 PV ou ≤ 25 %) : liseré vermillon, halo de contours concentriques pulsé à 900 ms, cœur cerné de papier.
func _draw_life(u: float) -> void:
	var n := maxi(max_hp, 1)
	var hf := clampf(hurt_flash, 0.0, 1.0)
	var shake := Vector2(sin(_t * 80.0) * 3.0 * u, 0.0) if hf > 0.7 else Vector2.ZERO  # 120 ms après le coup
	var low := hp > 0 and (hp == 1 or float(hp) <= float(n) * 0.25)
	var pulse: float = (0.5 + 0.5 * sin(_t * TAU / 0.9)) if low else 0.0  # 0,4 → 1 → 0,4 en 900 ms
	var lr := life_rect()
	draw_set_transform(lr.position + shake, 0.0, Vector2(u, u))  # tout le gabarit en unités de la maquette
	if low:
		# halo : trois contours concentriques du fourreau, alpha décroissant (pas de flou)
		var ha := 0.4 + 0.6 * pulse
		_outline(_sheath, Color(Toon.VERMILION, 0.14 * ha), 15.0)
		_outline(_sheath, Color(Toon.VERMILION, 0.25 * ha), 11.0)
		_outline(_sheath, Color(Toon.VERMILION, 0.4 * ha), 7.0)
	draw_colored_polygon(_sheath, UIColors.SUMI_HUD_BG)
	var rim: Color = Color(Toon.VERMILION, 1.0) if low else Color(UIColors.WASHI, 0.6)
	_outline(_sheath, rim.lerp(Color(1, 1, 1, 1), hf), 1.5 + hf)
	# segments, du bas vers le haut
	var step := (LIFE_SEG_BOT - LIFE_SEG_TOP) / float(n)
	var sh := step * 0.75
	for i in n:
		var yb := LIFE_SEG_BOT - step * float(i)
		var lost_t := -1.0
		for l in _lost:
			if int(l[0]) == i:
				lost_t = float(l[1])
		var col := Color(UIColors.WASHI, 0.12)
		var hl := false
		if i < hp:
			col = Toon.VERMILION
			hl = true
			if _gain_t > 0.0 and i >= _gain_from:
				col = col.lerp(Color(1, 0.97, 0.92), 0.8 * _gain_t / 0.6)
		elif lost_t >= 0.0:
			if lost_t < 0.12:
				col = Color(1, 0.97, 0.92)
			elif lost_t < LOST_HOLD:
				col = Color(UIColors.WASHI, 0.55)
			else:
				col = Color(UIColors.WASHI, lerpf(0.55, 0.12, (lost_t - LOST_HOLD) / LOST_FADE))
		_fill_pts.resize(4)
		_fill_pts[0] = Vector2(8, yb)
		_fill_pts[1] = Vector2(24, yb - 3.5)
		_fill_pts[2] = Vector2(24, yb - 3.5 - sh)
		_fill_pts[3] = Vector2(8, yb - sh)
		draw_colored_polygon(_fill_pts, col)
		if hl and sh > 8.0:
			draw_line(Vector2(10.5, yb - 3.0), Vector2(10.5, yb - sh + 3.0), Color(1, 1, 1, 0.4), 2.0, true)
	# cœur en pommeau
	var hc: Color = Toon.VERMILION if hp > 0 else Color("#5A5560")
	hc = hc.lerp(Color(1, 0.97, 0.92), 0.6 * hf)
	var beat := 1.0 + 0.08 * pulse + 0.15 * hf
	if beat > 1.001:
		# le cœur bat autour de son centre (16, 16 du gabarit)
		draw_set_transform(lr.position + shake + Vector2(16.0, 16.0) * u * (1.0 - beat), 0.0, Vector2(u * beat, u * beat))
	draw_colored_polygon(_heart, hc)
	_outline(_heart, Color(UIColors.WASHI, 1.0) if low else UIColors.SUMI, 2.0)
	draw_line(Vector2(9.5, 13), Vector2(13, 11.5), Color(1, 1, 1, 0.6), 1.6, true)
	draw_set_transform(Vector2.ZERO)


## Expérience : filet 11 × 150 (x 42, y 470), fond sumi, cadre papier, remplissage jade qui passe à l'or au-delà de 80 %.
## Niveau : hexagone 48 (x 7, y 626) cerné d'or, chiffre seul ; passage de niveau : éclat d'or et le filet s'illumine.
func _draw_xp(u: float) -> void:
	var fl := _lv_flash
	var bar := xp_rect()
	draw_style_box(UiKit.box(_sb, UIColors.SUMI_HUD_BG, int(4.0 * u), Color(UIColors.WASHI, 0.75).lerp(Color(1, 0.92, 0.6), fl), maxi(1, int(1.5 * u))), bar)
	var inner := bar.grow(-1.5 * u)
	var fh := inner.size.y * _xp_shown
	if fh > 1.0:
		var col: Color = UIColors.GOLD if _xp_shown > 0.8 else HUD_JADE
		draw_style_box(UiKit.box(_sb, col.lerp(Color(1, 0.95, 0.75), fl), int(2.0 * u)), Rect2(Vector2(inner.position.x, inner.end.y - fh), Vector2(inner.size.x, fh)))
	# hexagone de niveau (pointe en haut), rayon 21,6 u
	var lc := Vector2(31.0 * u, _cluster_top() + 216.0 * u)
	var R := 21.6 * u * (1.0 + 0.2 * UiKit.ease_out(fl) * fl)
	if fl > 0.0:
		var e := 1.0 - fl
		draw_arc(lc, R + 5.0 * u + 20.0 * u * e, 0.0, TAU, 32, Color(UIColors.GOLD, fl), 3.0 * u * fl + 0.5, true)
		for j in 6:
			var d := Vector2.from_angle(TAU * float(j) / 6.0 + 0.3)
			draw_circle(lc + d * (R + 7.0 * u + 18.0 * u * e), 2.2 * u * fl, Color(1, 0.92, 0.6, fl))
	# passage de niveau : l'hexagone fait un tour sur lui-même (flip) en 240 ms, puis se fige
	var since := (1.0 - fl) / 1.2
	var sx := absf(cos(PI * since / 0.24)) if fl > 0.0 and since < 0.24 else 1.0
	if sx < 0.999:
		draw_set_transform(Vector2(lc.x * (1.0 - sx), 0.0), 0.0, Vector2(sx, 1.0))
	draw_colored_polygon(_hex(lc, R), UIColors.SUMI_HUD_BG)
	var hx := _hex(lc, R - 1.5 * u)
	_outline(hx, UIColors.GOLD.lerp(Color(1, 0.95, 0.75), fl), 3.0 * u)
	var lfs := int((21.6 if level < 100 else 15.0) * u)
	UiKit.text(self, UiKit.num_font(), _lv_txt, lc + Vector2(0, lfs * 0.36), lfs, UIColors.WASHI)
	if sx < 0.999:
		draw_set_transform(Vector2.ZERO)


## Hexagone pointe en haut, de rayon r.
func _hex(c: Vector2, r: float) -> PackedVector2Array:
	_fill_pts.resize(6)
	for k in 6:
		_fill_pts[k] = c + Vector2.from_angle(-PI / 2.0 + PI / 3.0 * float(k)) * r
	return _fill_pts


# ------------------------------------------------------------------ grappe droite : encre, ultime

## Encre : goutte 24 (y 436) à l'encre de l'Atelier cernée de papier, puis jauge claire 28 × 150 (x 362, y 470) : papier
## cerné d'encre et d'un filet washi, remplissage à l'encre (du bas), graduations tous les 2 m ; vide : clignote.
## Dessous, le sceau d'ultime.
func _draw_ink(u: float) -> void:
	var y0 := _cluster_top()
	var ink: Color = InkStroke.ink
	if ink.get_luminance() > 0.5:
		ink = ink.lerp(UIColors.SUMI, 0.6)  # encre claire : assombrie pour rester lisible sur le papier
	var low := elan < 0.2
	if elan_empty or low:
		# vide : clignote 2 × 100 ms en vermillon ; bas : vermillon fixe
		ink = Toon.VERMILION if (elan_empty and int(Time.get_ticks_msec() / 100.0) % 2 == 0) or (low and not elan_empty) else ink
	# goutte (gabarit 18 × 22, ×4/3)
	draw_set_transform(Vector2(size.x - 36.0 * u, y0 + 2.0 * u), 0.0, Vector2(u * 4.0 / 3.0, u * 4.0 / 3.0))
	draw_colored_polygon(_drop, ink)
	_outline(_drop, UIColors.WASHI, 1.5)
	draw_set_transform(Vector2.ZERO)
	# jauge
	var gr := Rect2(Vector2(size.x - 38.0 * u, y0 + 36.0 * u), Vector2(28.0 * u, 150.0 * u))
	draw_style_box(UiKit.box(_sb, Color(UIColors.WASHI, 0.7), int(15.5 * u)), gr.grow(1.5 * u))
	draw_style_box(UiKit.box(_sb, UIColors.WASHI, int(14.0 * u), UIColors.SUMI, maxi(1, int(2.0 * u))), gr)
	var ir := ink_rect()
	var fh := ir.size.y * clampf(elan, 0.0, 1.0)
	if fh > 1.0:
		draw_style_box(UiKit.box(_sb, ink, int(6.0 * u)), Rect2(Vector2(ir.position.x, ir.end.y - fh), Vector2(ir.size.x, fh)))
	# graduations : une encoche tous les 2 m de trait
	var ticks := int(elan_m / 2.0)
	for i in range(1, ticks + 1):
		var y := ir.end.y - ir.size.y * (2.0 * i / elan_m)
		if y > ir.position.y + 2.0:
			draw_line(Vector2(ir.position.x, y), Vector2(ir.position.x + ir.size.x * 0.35, y), Color(UIColors.SUMI, 0.3), maxf(1.0, 1.2 * u))
	if elan >= 0.999:
		draw_circle(Vector2(ir.get_center().x, ir.position.y - 1.0 * u), 2.5 * u + 1.0 * u * sin(_t * 6.0), UIColors.GOLD)
	_draw_ult(Vector2(size.x - 34.0 * u, y0 + 218.0 * u), u)


## Sceau d'ultime 56 (x 338, y 624) : disque sumi, anneau éteint puis arc de charge or de 4 u, filet papier, picto
## pinceau au centre. Plein : tampon 1,3 → 1 en 220 ms, anneau et picto or, halo de cercles concentriques en boucle,
## picto double tap (2 points + arcs) accroché en haut à gauche, qui pulse avec le halo.
func _draw_ult(c: Vector2, u: float) -> void:
	var k := 56.0 / 46.0 * u  # gabarit 46
	var full := ult >= 1.0
	var pulse := (0.5 + 0.5 * sin(_t * TAU / 1.2)) if full else 0.0
	var stamp := 1.0 + 0.3 * _ult_full_t * _ult_full_t
	draw_set_transform(c * (1.0 - stamp), 0.0, Vector2(stamp, stamp))
	if full:
		UiKit.halo(self, c, 21.0 * k, UIColors.GOLD, 0.6 + 0.6 * pulse, 3, 3.0 * u)
	draw_circle(c, 18.0 * k, UIColors.SUMI_HUD_BG)
	draw_arc(c, 18.0 * k, 0.0, TAU, 48, UIColors.GOLD if full else ULT_RING_OFF, 4.0 * k, true)
	if not full and ult > 0.005:
		draw_arc(c, 18.0 * k, -PI / 2.0, -PI / 2.0 + TAU * clampf(ult, 0.0, 1.0), 40, UIColors.GOLD, 4.0 * k, true)
	draw_arc(c, 21.0 * k, 0.0, TAU, 48, Color(UIColors.WASHI, 0.6), maxf(1.0, 1.0 * k), true)
	UiKit.draw_icon(self, "hud/pinceau", c, 25.2 * u, 1.0, UIColors.GOLD if full else Color(UIColors.WASHI, 0.6))
	draw_set_transform(Vector2.ZERO)
	if full:
		# double tap : rond papier de 22 accroché en haut à gauche du sceau
		var bc := c + Vector2(-29.0, -27.0) * u
		var bs := u * (1.0 + 0.08 * pulse)
		draw_circle(bc, 10.0 * bs, UIColors.WASHI)
		draw_arc(bc, 10.0 * bs, 0.0, TAU, 32, UIColors.SUMI, 1.5 * u, true)
		draw_circle(bc + Vector2(-3.5, 1.0) * bs, 2.2 * bs, UIColors.SUMI)
		draw_circle(bc + Vector2(3.5, 1.0) * bs, 2.2 * bs, UIColors.SUMI)
		draw_arc(bc + Vector2(-3.5, -1.5) * bs, 3.2 * bs, PI, TAU, 10, UIColors.SUMI, 1.2 * u, true)
		draw_arc(bc + Vector2(3.5, -1.5) * bs, 3.2 * bs, PI, TAU, 10, UIColors.SUMI, 1.2 * u, true)


# ------------------------------------------------------------------ barre haute

## Pilule de la zone du haut (fond sumi 92 %, contour papier 55 %, bouts ronds).
func _pill(r: Rect2, u: float, a := 1.0) -> void:
	draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI_HUD_BG, UIColors.SUMI_HUD_BG.a * a), 999, Color(UIColors.WASHI, 0.55 * a), maxi(1, int(1.5 * u))), r)


## Étape : pilule h44 à gauche (x 14) : picto du monde dans un carré de 30 à la couleur du monde, « 5/8 » en 20/13,
## crans de combat 9 × 4 (or quand le combat est gagné).
func _draw_stage(u: float) -> void:
	var cy := (BAR_Y + BAR_H / 2.0) * u
	var nf := UiKit.num_font()
	var nfs := int(20 * u)
	var sfs := int(13 * u)
	var nw := nf.get_string_size(_wave_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var sw := nf.get_string_size(_rooms_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
	var crans := mini(enc_total, 8)
	var cw := (9.0 * float(crans) + 3.0 * float(maxi(crans - 1, 0))) * u
	var col_w := maxf(nw + sw, cw)
	var pill := Rect2(Vector2(14.0 * u, cy - BAR_H * u / 2.0), Vector2((7.0 + 30.0 + 9.0 + 14.0) * u + col_w, BAR_H * u))
	_pill(pill, u)
	var sq := Rect2(Vector2(pill.position.x + 7.0 * u, cy - 15.0 * u), Vector2(30.0, 30.0) * u)
	draw_style_box(UiKit.box(_sb, world_color, int(5.0 * u), UIColors.WASHI, maxi(1, int(1.5 * u))), sq)
	UiKit.draw_icon(self, String(UIColors.WORLD_ICON.get(world_kanji, "hud/vague")), sq.get_center(), 18.9 * u, 1.0, UIColors.WASHI)
	var tx := sq.end.x + 9.0 * u
	var by: float = (cy - 1.0 * u) if crans > 0 else (cy + nfs * 0.36)
	draw_string(nf, Vector2(tx, by), _wave_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, UIColors.WASHI)
	draw_string(nf, Vector2(tx + nw, by), _rooms_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(UIColors.WASHI, 0.7))
	for i in crans:
		var cr := Rect2(Vector2(tx + 12.0 * u * float(i), cy + 5.0 * u), Vector2(9.0, 4.0) * u)
		if i < enc_done:
			draw_style_box(UiKit.box(_sb, UIColors.GOLD, int(2.0 * u)), cr)
		else:
			draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(2.0 * u), Color(UIColors.WASHI, 0.7), maxi(1, int(1.0 * u))), cr)


## Score : pilule h44 à droite (bord droit à 66 u de l'écran), chiffres en 21 ; collée à gauche, la puce du
## multiplicateur (h32, min 44, couleurs de theme.json, ×4 avec halo) dès ×1,5 : elle bondit au palier, flashe en
## blanc puis s'efface quand la chaîne se perd. Primes de points dessous, à droite.
func _draw_score(sz: Vector2, u: float) -> void:
	if score >= 0:
		var pop := _score_pop * _score_pop
		var nf := UiKit.num_font()
		var nfs := int(21 * u)
		var nw := nf.get_string_size(_score_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var cy := (BAR_Y + BAR_H / 2.0) * u
		var has_chip := score_mult >= 1.5 or _mult_lost_t > 0.0
		var mtxt := _mult_txt if score_mult >= 1.5 else _mult_lost_txt
		var mfs := int(17 * u)
		var mw := 0.0
		if has_chip:
			mw = maxf(44.0 * u, nf.get_string_size(mtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x + 16.0 * u)
		var w := (14.0 if has_chip else 0.0) * u + mw + 14.0 * u + nw + 14.0 * u
		if not has_chip:
			w += 5.0 * u
		var pill := Rect2(Vector2(sz.x - 66.0 * u - w, cy - BAR_H * u / 2.0), Vector2(w, BAR_H * u))
		_pill(pill, u)
		var tcol := UIColors.WASHI.lerp(UIColors.GOLD.lightened(0.3), pop)
		draw_string(nf, Vector2(pill.end.x - 14.0 * u - nw, cy + nfs * 0.36), _score_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, tcol)
		if has_chip:
			var mr := Rect2(Vector2(pill.position.x + 5.0 * u, cy - 16.0 * u), Vector2(mw, 32.0 * u))
			var anchor := mr.get_center()
			if score_mult >= 1.5:
				var mcol := _mult_color(score_mult)
				# bond du palier : 1 → 1,25 → 1 en 180 ms (sortie arrière)
				var kp := 1.0 - _mult_pop
				var mp := 1.0 + 0.25 * sin(PI * kp) * (1.0 + 0.6 * (1.0 - kp))
				draw_set_transform(Vector2(0, top_off) + anchor * (1.0 - mp), 0.0, Vector2(mp, mp))
				if score_mult >= 4.0:
					# ×4 : halo de deux pilules concentriques
					draw_style_box(UiKit.box(_sb, Color(mcol, 0.12), 999), mr.grow(7.0 * u))
					draw_style_box(UiKit.box(_sb, Color(mcol, 0.22), 999), mr.grow(3.5 * u))
				draw_style_box(UiKit.box(_sb, mcol, 999), mr)
				UiKit.text(self, nf, mtxt, Vector2(anchor.x, cy + mfs * 0.36), mfs, UIColors.SUMI)
				draw_set_transform(Vector2(0, top_off))
			else:
				# chaîne perdue : flash blanc 80 ms, puis la puce pâlit, barrée de vermillon
				var age := (1.0 - _mult_lost_t) * 0.3
				var la := 1.0 if age < 0.08 else clampf(1.0 - (age - 0.08) / 0.22, 0.0, 1.0)
				var ccol := Color(1, 0.97, 0.92) if age < 0.08 else Color(_mult_color(_mult_lost), la)
				draw_style_box(UiKit.box(_sb, ccol, 999), mr)
				UiKit.text(self, nf, mtxt, Vector2(anchor.x, cy + mfs * 0.36), mfs, Color(UIColors.SUMI, la))
				if age >= 0.08:
					draw_line(mr.position + Vector2(8.0 * u, mr.size.y * 0.6), mr.end - Vector2(8.0 * u, mr.size.y * 0.6), Color(Toon.VERMILION, la), 2.0 * u, true)
	# chaîne brisée : étiquette sumi « CHAÎNE BRISÉE ×n » sous le score, qui descend et s'efface, éclats vermillon
	if chain_break > 0.0:
		var k := 1.0 - chain_break
		var txt := "CHAÎNE BRISÉE  ×%d" % chain_lost
		var tfs := int(11 * u)
		var tw2 := UiKit.UI_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		var tp := Vector2(sz.x - 66.0 * u - tw2, (_below_k() + 8.0 + 14.0 * k) * u)
		draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI, 0.8 * chain_break), 999), Rect2(tp + Vector2(-8 * u, -tfs), Vector2(tw2 + 16 * u, tfs + 6 * u)))
		draw_string(UiKit.UI_FONT, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(Toon.VERMILION.lightened(0.25), chain_break))
		var c := tp + Vector2(tw2 * 0.5, -tfs * 0.4)
		for j in 6:
			var a := TAU * j / 6.0
			draw_rect(Rect2(c + Vector2(cos(a), sin(a)) * 36.0 * u * k, Vector2(6, 3) * u), Color(Toon.VERMILION, chain_break))
	# primes : sous la zone du haut, à droite, elles montent et s'effacent
	var py := (_below_k() + 22.0 + (18.0 if chain_break > 0.0 else 0.0)) * u
	var pr := sz.x - 66.0 * u
	for i in _score_pops.size():
		var sp: Array = _score_pops[_score_pops.size() - 1 - i]
		var age := float(sp[2])
		var a := clampf(minf(age / 0.12, (1.6 - age) / 0.4), 0.0, 1.0)
		var ptxt := "%s  +%s" % [String(sp[0]), Score.fmt(int(sp[1]))]
		var pfs := int(12 * u)
		var pw := UiKit.num_font().get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
		var pp := Vector2(pr - pw, py + float(i) * 18.0 * u - 8.0 * u * UiKit.ease_out(clampf(age / 1.6, 0.0, 1.0)))
		draw_string_outline(UiKit.num_font(), pp, ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, maxi(2, int(3.0 * u)), Color(UIColors.SUMI, 0.9 * a))
		draw_string(UiKit.num_font(), pp, ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(UIColors.GOLD.lightened(0.25), a))


## Couleur de la puce du multiplicateur (theme.json : ×1,5 jade, ×2 or, ×3 vermillon clair, ×4 prune).
func _mult_color(m: float) -> Color:
	if m >= 4.0:
		return UIColors.MULT_CHIP["x4"]
	if m >= 3.0:
		return UIColors.MULT_CHIP["x3"]
	if m >= 2.0:
		return UIColors.MULT_CHIP["x2"]
	return UIColors.MULT_CHIP["x1.5"]


## Pause : rond papier de 44 cerné d'encre (2), deux barres ; la cible tactile est le bouton `_pause` posé dessus.
func _draw_pause_disc(sz: Vector2, u: float) -> void:
	if not _pause.visible:
		return
	var c := Vector2(sz.x - 36.0 * u, (BAR_Y + BAR_H / 2.0) * u)
	draw_circle(c, 22.0 * u, UIColors.WASHI)
	draw_arc(c, 21.0 * u, 0.0, TAU, 48, UIColors.SUMI, 2.0 * u, true)
	draw_rect(Rect2(c + Vector2(-5.0, -8.0) * u, Vector2(5.0, 16.0) * u), UIColors.SUMI)
	draw_rect(Rect2(c + Vector2(0.0, -8.0) * u, Vector2(5.0, 16.0) * u), UIColors.SUMI)


# ------------------------------------------------------------------ sceaux de figure et de pouvoir

## Figures réussies : les sceaux s'alignent quand on les enchaîne (6 au plus), le dernier porte son nom.
## La rangée s'efface 3 s après la dernière figure.
func shape_pop(shape: String, label: String) -> void:
	if _shape_t > 3.0:
		_shapes.clear()
	_shapes.append([shape, 0.0])
	if _shapes.size() > 6:
		_shapes.pop_front()
	shape_name = plain(label)
	_shape_t = 0.0


func _draw_shape_pop(sz: Vector2, u: float) -> void:
	if _shapes.is_empty() or _shape_t > 3.4:
		return
	var a := clampf((3.4 - _shape_t) / 0.4, 0.0, 1.0)
	var n := _shapes.size()
	# petits sceaux au-dessus du héros (ne gâchent pas la vue)
	var r := 10.0 * u
	var gap := 2.0 * r + 5.0 * u
	var anchor := hero_screen if hero_screen.x > -9000.0 else Vector2(sz.x / 2.0, 150.0 * u)
	var y := clampf(anchor.y - 34.0 * u, (_below_k() + 20.0) * u, sz.y - 120.0 * u)  # bien au-dessus de la tête, sous la zone du haut
	var x0 := clampf(anchor.x - (n - 1) * gap / 2.0, 54.0 * u, sz.x - 44.0 * u - (n - 1) * gap)  # entre les jauges des bords
	for i in n:
		var sh: Array = _shapes[i]
		sh[1] = float(sh[1]) + _real_dt
		var k_in := clampf(float(sh[1]) / 0.15, 0.0, 1.0)
		var newest := i == n - 1
		var rr := r * (1.25 if newest else 1.0) * (0.6 + 0.4 * (1.0 - pow(1.0 - k_in, 3.0)))
		var c := Vector2(x0 + i * gap, y)
		if i > 0:
			# trait d'encre qui relie les figures enchaînées
			draw_line(Vector2(x0 + (i - 1) * gap + r, y), c - Vector2(rr, 0), Color(Toon.SUMI, 0.6 * a), 2.0 * u)
		# sceau rond papier cerné d'encre, picto v2 de la figure à son encre
		draw_circle(c, rr + 2.0 * u, Color(UIColors.SUMI, 0.9 * a))
		draw_circle(c, rr, Color(UIColors.WASHI_LIGHT, 0.95 * a))
		UiKit.figure_icon(self, String(sh[0]), c, rr * 1.5, a)


## Sceau du pouvoir qui vient d'agir, au-dessus de `wpos` (monde) : on voit d'un coup QUEL pouvoir a fait QUOI.
## Au plus une fois par POP_CD et par pouvoir, POP_MAX à l'écran ; un sceau mineur (déclencheur fréquent, à la touche)
## ne chasse pas un sceau affiché, un majeur remplace le plus ancien.
func power_pop(key: String, icon: String, col: Color, wpos: Vector3, major := true) -> void:
	if not in_play or not major:
		return  # les déclencheurs fréquents (à chaque touche) ne font plus clignoter de sceau
	var now := Time.get_ticks_msec()
	if int(_pop_cd.get(key, 0)) > now:
		return
	if _pops.size() >= POP_MAX:
		if not major:
			return
		var drop := 0
		for i in _pops.size():
			var q: Array = _pops[i]
			if not bool(q[5]):
				drop = i
				break
		_pops.remove_at(drop)
	_pop_cd[key] = now + POP_CD
	_pops.append([key, icon, col, wpos, 0.0, major])


## Sceaux de pouvoir : cachet rond cerné d'encre, à la couleur de l'élément, pictogramme en papier (ou en encre sur
## les teintes claires) ; il jaillit avec un rebond, monte un peu et s'efface.
func _draw_power_pops(sz: Vector2, u: float) -> void:
	if _pops.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var prev := Vector2(-9999, -9999)
	var y_min := top_off + (_below_k() + 18.0) * u
	for i in _pops.size():
		var pp: Array = _pops[i]
		var wp: Vector3 = pp[3]
		if cam.is_position_behind(wp):
			continue
		var age: float = pp[4]
		var k := clampf(age / POP_LIFE, 0.0, 1.0)
		var k_in := clampf(age / 0.14, 0.0, 1.0)
		# rebond : grossit au-delà de sa taille puis se pose
		var sc := UiKit.ease_out(k_in) * (1.0 + 0.35 * sin(k_in * PI))
		var a := clampf((1.0 - k) / 0.3, 0.0, 1.0)
		var r := 11.0 * u * maxf(sc, 0.05)
		var c := cam.unproject_position(wp) - Vector2(0, 10.0 * u * UiKit.ease_out(k))
		c.x = clampf(c.x, 18.0 * u, sz.x - 18.0 * u)
		c.y = clampf(c.y, y_min, sz.y - 40.0 * u)
		# deux sceaux au même endroit : le second se range à côté
		if c.distance_to(prev) < 24.0 * u:
			c.x += 26.0 * u
		prev = c
		var col: Color = pp[2]
		var paper := Toon.SUMI if col.get_luminance() > 0.6 else Toon.WASHI
		draw_circle(c + Vector2(0, 1.5 * u), r + 2.5 * u, Color(Toon.SUMI, 0.35 * a))
		draw_circle(c, r + 2.0 * u, Color(Toon.SUMI, 0.9 * a))
		draw_circle(c, r, Color(col, a))
		UiKit.glyph(self, String(pp[1]), c, r * 0.66, paper, col, a)


## Prime de points annoncée sous le score (« SANS DÉGÂT  +500 ») ; la même prime répétée de près se cumule.
func score_pop(label: String, pts: int) -> void:
	if pts <= 0 or score < 0:
		return
	var lb := plain(label)
	for sp in _score_pops:
		if String(sp[0]) == lb and float(sp[2]) < 0.8:
			sp[1] = int(sp[1]) + pts
			sp[2] = 0.0
			return
	_score_pops.append([lb, pts, 0.0])
	if _score_pops.size() > 3:
		_score_pops.pop_front()


# ------------------------------------------------------------------ pad tactile

## Pad tactile (mode pad) : zone où l'on trace, avec le geste en cours en miniature.
func _draw_pad(u: float) -> void:
	if pad.size.x < 10.0:
		return
	var pa := maxf(pad_alpha, 0.35 if pad_active else 0.0)
	if pa > 0.01:
		_draw_pad_frame(u, pa)
	if pad_active and pad_trail.size() > 0:
		draw_circle(pad_trail[0], 6 * u, Color(Toon.VERMILION, 0.8))
		if pad_trail.size() > 1:
			draw_polyline(pad_trail, Color(Toon.WASHI, 0.75), 4 * u, true)
		draw_circle(pad_trail[pad_trail.size() - 1], 9 * u, Color(Toon.WASHI, 0.3))


func _draw_pad_frame(u: float, pa: float) -> void:
	draw_style_box(UiKit.box(_sb, Color(Toon.WASHI, 0.06 * pa), int(18 * u), Color(Toon.WASHI, 0.22 * pa), int(1.5 * u)), pad)
	if not pad_active:
		# invitation : un doigt qui trace un petit trait vers le haut (pas de texte : l'état visuel porte la consigne)
		var c := pad.get_center()
		var k := fmod(_t, 1.6) / 1.6
		var p0 := c + Vector2(0, 18 * u)
		var p1 := p0 + Vector2(0, -36 * u * minf(k * 1.4, 1.0))
		draw_line(p0, p1, Color(Toon.WASHI, 0.35 * pa), 3 * u, true)
		draw_circle(p1, 7 * u, Color(Toon.WASHI, 0.4 * pa))


# ------------------------------------------------------------------ gardien

## Makimono 380 × 44 (x 10, y 90) : rouleaux bois à bouts d'or, corps sumi cerné de papier, traînée de dégâts washi,
## vie en rouge à bord pinceau (or pulsé quand le gardien est vulnérable), encoches de phase (losanges d'or), sceau
## monstre (picto oni sur carré vermillon, penché). Dessous : le nom en capitales espacées + losanges de phase, et à
## droite la puce du bouclier : bleue (écu + segments) tant qu'il tient, or « ×N » (écu brisé) quand il est vulnérable,
## son compte à rebours en filet. Point faible en ligne au-dessous.
func _draw_boss(sz: Vector2, u: float) -> void:
	var vuln := boss_vuln > 0.0
	var pulse := 0.5 + 0.5 * sin(_t * 10.0)
	var x0 := (sz.x - 380.0 * u) / 2.0
	var y0 := BOSS_Y * u
	draw_set_transform(Vector2(x0, y0 + top_off), 0.0, Vector2(u, u))
	# corps
	draw_colored_polygon(_maki, UIColors.SUMI_HUD_BG)
	_outline(_maki, Color(UIColors.WASHI, 0.55), 1.5)
	# traînée washi puis vie rouge, bord pinceau
	if _boss_trail > boss_ratio + 0.002:
		_maki_fill(_boss_trail, Color(UIColors.WASHI, 0.75))
	if boss_ratio > 0.002:
		var hp_col: Color = Toon.VERMILION.lerp(UIColors.GOLD, 0.35 + 0.5 * pulse) if vuln else Toon.VERMILION
		_maki_fill(boss_ratio, hp_col)
		var xr := 40.0 + 300.0 * clampf(boss_ratio, 0.0, 1.0)
		if xr > 56.0:
			draw_line(Vector2(44, 15), Vector2(xr - 8.0, 14), Color(1, 1, 1, 0.35), 2.0, true)
	# encoches de phase
	if boss_phases > 1:
		for i in range(1, boss_phases):
			var px := 40.0 + 300.0 * float(i) / float(boss_phases)
			draw_line(Vector2(px, 12), Vector2(px, 32), UIColors.SUMI, 2.0, true)
			_fill_pts.resize(3)
			_fill_pts[0] = Vector2(px - 4.0, 6.0)
			_fill_pts[1] = Vector2(px, 12.0)
			_fill_pts[2] = Vector2(px + 4.0, 6.0)
			draw_colored_polygon(_fill_pts, UIColors.GOLD)
	# rouleaux de bois, bouts d'or
	for rx in MAKI_ROLLS:
		var x := float(rx)
		draw_style_box(UiKit.box(_sb, HUD_WOOD, 3, UIColors.SUMI, 2), Rect2(x, 2, 16, 40))
		draw_style_box(UiKit.box(_sb, UIColors.GOLD_DARK, 2, UIColors.SUMI, 1), Rect2(x - 2, 0, 20, 6))
		draw_style_box(UiKit.box(_sb, UIColors.GOLD_DARK, 2, UIColors.SUMI, 1), Rect2(x - 2, 38, 20, 6))
	# sceau monstre, penché de 6°
	draw_set_transform(Vector2(x0, y0 + top_off) + Vector2(18.0, 22.0) * u, deg_to_rad(-6.0), Vector2(u, u))
	draw_style_box(UiKit.box(_sb, Toon.VERMILION, 5, UIColors.SUMI, 2), Rect2(-18, -18, 36, 36))
	UiKit.draw_icon(self, "hud/oni", Vector2.ZERO, 21.0, 1.0, UIColors.WASHI)
	draw_set_transform(Vector2(0, top_off))
	# libellés : nom espacé (ombre d'encre), losanges de phase
	var lfs := int(10 * u)
	var sp := maxi(1, int(3.0 * u))
	if _caps_sp.spacing_glyph != sp:
		_caps_sp.spacing_glyph = sp
	var nm := UiKit.caps(boss_name)
	var ny := y0 + 54.0 * u
	var nx := x0 + 40.0 * u
	draw_string_outline(_caps_sp, Vector2(nx, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, maxi(2, int(2.5 * u)), Color(UIColors.SUMI, 0.8))
	draw_string(_caps_sp, Vector2(nx, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, UIColors.WASHI)
	if boss_phases > 1:
		var dx := nx + _caps_sp.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x + 8.0 * u
		for i in boss_phases:
			var dc := Vector2(dx + 10.0 * u * float(i), ny - 3.5 * u)
			if i < boss_phase:
				UiKit.diamond(self, dc, 4.5 * u, UIColors.GOLD)
			else:
				UiKit.diamond(self, dc, 4.5 * u, UiKit.NONE, UIColors.GOLD, maxf(1.0, 1.5 * u))
	# puce du bouclier, à droite
	if vuln or boss_has_shield:
		var nf := UiKit.num_font()
		var cfs := int(13 * u)
		var ctxt := "×%d" % _shield_breaks
		var cw := nf.get_string_size(ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x if vuln else 44.0 * u
		var chip := Rect2(Vector2(x0 + 358.0 * u - 22.0 * u - cw - 4.0 * u, y0 + 40.0 * u), Vector2(26.0 * u + cw, 22.0 * u))
		var ccol: Color = UIColors.GOLD if vuln else SHIELD_BAR
		draw_style_box(UiKit.box(_sb, ccol, 999, UIColors.SUMI, maxi(1, int(1.5 * u))), chip)
		var ic := Vector2(chip.position.x + 11.0 * u, chip.get_center().y)
		UiKit.glyph(self, "shield", ic, 5.5 * u, UIColors.SUMI, ccol if not vuln else UiKit.NONE)
		if vuln:
			# écu fendu
			draw_line(ic + Vector2(0.5, -4.5) * u, ic + Vector2(-1.5, 0.0) * u, ccol, 1.4 * u, true)
			draw_line(ic + Vector2(-1.5, 0.0) * u, ic + Vector2(1.5, 1.0) * u, ccol, 1.4 * u, true)
			draw_line(ic + Vector2(1.5, 1.0) * u, ic + Vector2(-0.5, 5.0) * u, ccol, 1.4 * u, true)
			draw_string(nf, Vector2(ic.x + 9.0 * u, ic.y + cfs * 0.36), ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, UIColors.SUMI)
			# compte à rebours : filet d'or sous la puce
			var k := clampf(boss_vuln / maxf(boss_vuln_len, 0.1), 0.0, 1.0)
			var fr := Rect2(Vector2(chip.position.x + 4.0 * u, chip.end.y + 3.0 * u), Vector2(chip.size.x - 8.0 * u, 2.5 * u))
			draw_rect(fr, Color(UIColors.SUMI, 0.6))
			draw_rect(Rect2(fr.position, Vector2(fr.size.x * k, fr.size.y)), UIColors.GOLD)
		else:
			# segments du bouclier (le dernier se remplit en partie)
			var n := 6
			var sx := ic.x + 10.0 * u
			var sw := (cw - 6.0 * u - 1.5 * u * float(n - 1)) / float(n)
			var fill := clampf(boss_shield, 0.0, 1.0) * float(n)
			for i in n:
				var x := sx + float(i) * (sw + 1.5 * u)
				draw_rect(Rect2(x, ic.y - 3.0 * u, sw, 6.0 * u), Color(UIColors.SUMI, 0.55))
				var f := clampf(fill - float(i), 0.0, 1.0)
				if f > 0.0:
					draw_rect(Rect2(x, ic.y - 3.0 * u, sw * f, 6.0 * u), UIColors.WASHI)
	# point faible : le geste à faire, toujours visible sous les libellés
	if boss_hint != "":
		var hs := int(9 * u)
		var ht := "POINT FAIBLE : " + plain(boss_hint)
		var hw := UiKit.UI_FONT.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		var hp0 := Vector2(sz.x / 2.0 - hw / 2.0, y0 + 70.0 * u)
		draw_string_outline(UiKit.UI_FONT, hp0, ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, maxi(2, int(2.5 * u)), Color(UIColors.SUMI, 0.8))
		draw_string(UiKit.UI_FONT, hp0, ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, UIColors.GOLD)


## Remplissage du makimono (coordonnées du gabarit) de x 40 jusqu'à la part `k` de 300, bord droit en zigzag de pinceau.
func _maki_fill(k: float, col: Color) -> void:
	var xr := 40.0 + 300.0 * clampf(k, 0.0, 1.0)
	_fill_pts.resize(7)
	_fill_pts[0] = Vector2(40, 13)
	_fill_pts[1] = Vector2(minf(140.0, xr - 2.0), 10.5)
	_fill_pts[2] = Vector2(xr - 6.0, 12.0)
	_fill_pts[3] = Vector2(xr - 12.0, 18.0)
	_fill_pts[4] = Vector2(xr, 24.0)
	_fill_pts[5] = Vector2(xr - 6.0, 31.0)
	_fill_pts[6] = Vector2(40, 31)
	if xr < 52.0:
		_fill_pts[1] = Vector2(40, 12.5)
		_fill_pts[3] = Vector2(xr - 4.0, 18.0)
	draw_colored_polygon(_fill_pts, col)


func _draw_gate_hint(sz: Vector2, u: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var ax := sz.x / 2.0
	var ay := top_off + (_band_k + 62.0) * u - 8.0 * u * pulse
	var arrow := PackedVector2Array([Vector2(ax, ay - 16 * u), Vector2(ax + 16 * u, ay + 6 * u), Vector2(ax + 6 * u, ay + 6 * u),
		Vector2(ax + 6 * u, ay + 22 * u), Vector2(ax - 6 * u, ay + 22 * u), Vector2(ax - 6 * u, ay + 6 * u), Vector2(ax - 16 * u, ay + 6 * u)])
	draw_colored_polygon(arrow, Color(UIColors.GOLD, 0.55 + 0.4 * pulse))
	_outline(arrow, Color(UiKit.GOLD_INK, 0.6 + 0.4 * pulse), 2.0 * u)


# ------------------------------------------------------------------ bandeau, carton, cinéma

## Bandeau d'événement / coach : coup de pinceau sumi 92 % centré en haut (y 88–130, sous le makimono du gardien),
## filet vermillon, titre Shippori espacé ; avec sous-titre, plus large, et le sceau carré de l'annonce (picto) à gauche.
## Le trait se peint de gauche à droite (260 ms), le texte suit en fondu ; sortie en glissant et en s'effaçant.
func _draw_banner(sz: Vector2, u: float) -> void:
	var t := _banner_t
	var k_in := clampf(t / 0.26, 0.0, 1.0)
	var k_out := clampf((_banner_len - t) / 0.2, 0.0, 1.0)
	var a := k_out
	var ein := UiKit.ease_out(k_in)
	var has_sub := _banner_small != ""
	var bw := (312.0 if has_sub else 228.0) * u
	var h := (56.0 if has_sub else 38.0) * u
	var cy := top_off + (_band_k + 8.0) * u + h / 2.0
	if dojo:
		cy = top_off + 160.0 * u  # sous l'en-tête du dojo et son verdict
	var x0 := (sz.x - bw) / 2.0 + (1.0 - k_out) * 16.0 * u
	var reach := 0.15 + 0.85 * ein
	var acc := _banner_col
	var acc_l: Color = acc.lightened(0.35) if acc.get_luminance() < 0.4 else acc
	# le coup de pinceau, tronqué à droite tant qu'il se peint
	var n := _banner_shape.size()
	_fill_pts.resize(n)
	for i in n:
		var p := _banner_shape[i]
		_fill_pts[i] = Vector2(x0 + minf(p.x, reach) * bw, cy - h / 2.0 + p.y * h)
	draw_colored_polygon(_fill_pts, Color(UIColors.SUMI_HUD_BG, UIColors.SUMI_HUD_BG.a * a))
	# filet vermillon, tracé avec lui
	var m := _banner_line.size()
	_fill_pts.resize(m)
	for i in m:
		var p := _banner_line[i]
		_fill_pts[i] = Vector2(x0 + minf(p.x, reach) * bw, cy - h / 2.0 + p.y * h)
	draw_polyline(_fill_pts, Color(acc_l if has_sub else Toon.VERMILION, 0.95 * a), 2.5 * u, true)
	# textes (rétrécis s'ils débordent) ; tailles ajustées une fois par bandeau, pas à chaque image
	var ta := a * clampf((t - 0.08) / 0.2, 0.0, 1.0)
	var sp := maxi(1, int((2.0 if has_sub else 4.0) * u))
	if _title_sp.spacing_glyph != sp:
		_title_sp.spacing_glyph = sp
	var room := bw - (76.0 if has_sub else 30.0) * u
	if _bfit_at != Vector2(u, room):
		_bfit_at = Vector2(u, room)
		_bfit_big = int(15 * u)
		while _bfit_big > 10 and _title_sp.get_string_size(_banner_big, HORIZONTAL_ALIGNMENT_LEFT, -1, _bfit_big).x > room:
			_bfit_big -= 1
		_bfit_small = int(10 * u)
		while has_sub and _bfit_small > 7 and UiKit.UI_FONT.get_string_size(_banner_small, HORIZONTAL_ALIGNMENT_LEFT, -1, _bfit_small).x > room:
			_bfit_small -= 1
	var fs := _bfit_big
	if has_sub:
		# sceau carré de l'annonce, posé comme un tampon juste après le trait
		var sk := clampf((t - 0.1) / 0.22, 0.0, 1.0)
		var sc := Vector2(x0 + 34.0 * u, cy)
		if sk > 0.0:
			var z := lerpf(1.6, 1.0, UiKit.ease_out(sk))
			var half := 18.0 * u * z
			draw_style_box(UiKit.box(_sb, Color(acc, a * sk), int(5 * u), Color(UIColors.WASHI, 0.85 * a * sk), maxi(1, int(1.5 * u))), Rect2(sc - Vector2(half, half), Vector2(half, half) * 2.0))
			UiKit.glyph(self, _banner_icon, sc, 10.0 * u * z, UIColors.WASHI, acc, a * sk)
		# zone ou étape nettoyée : petite gerbe d'or autour du sceau
		if _banner_icon == "torii" and t < 0.8:
			var gk := clampf((t - 0.15) / 0.6, 0.0, 1.0)
			for j in 10:
				var d := Vector2.from_angle(TAU * float(j) / 10.0 + 0.3)
				draw_line(sc + d * (26.0 + 18.0 * gk) * u, sc + d * (32.0 + 24.0 * gk) * u, Color(UIColors.GOLD, (1.0 - gk) * a), 2.0 * u, true)
		var tx := x0 + 62.0 * u
		draw_string(_title_sp, Vector2(tx + (1.0 - ein) * 10.0 * u, cy - 2.0 * u), _banner_big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIColors.WASHI, ta))
		draw_string(UiKit.UI_FONT, Vector2(tx, cy + 13.0 * u), _banner_small, HORIZONTAL_ALIGNMENT_LEFT, -1, _bfit_small, Color(acc_l.lerp(UIColors.WASHI, 0.45), ta))
	else:
		UiKit.text(self, _title_sp, _banner_big, Vector2(x0 + bw / 2.0 + float(sp) * 0.5, cy + fs * 0.36), fs, Color(UIColors.WASHI, ta))


## Bandes noires du cinéma, bord inférieur/supérieur taché d'encre.
func _draw_cine(sz: Vector2, u: float) -> void:
	var h := sz.y * 0.1 * cine
	if h < 1.0:
		return
	draw_rect(Rect2(0, 0, sz.x, h), Toon.SUMI)
	draw_rect(Rect2(0, sz.y - h, sz.x, h), Toon.SUMI)
	var n := 9
	for i in n + 1:
		var x := sz.x * float(i) / n
		var r := (5.0 + 3.0 * sin(float(i) * 2.3)) * u * cine
		draw_circle(Vector2(x, h), r, Toon.SUMI)
		draw_circle(Vector2(x + sz.x * 0.5 / n, sz.y - h), (5.0 + 3.0 * sin(float(i) * 1.7 + 1.0)) * u * cine, Toon.SUMI)


## Carton titre : coup de pinceau qui traverse l'écran sous le boss, sceau picto (oni ou couronne) estampillé au-dessus.
func _draw_card(sz: Vector2, u: float) -> void:
	var sc := 0.8 if _card_mini else 1.0
	var k_in := clampf(_card_t / 0.35, 0.0, 1.0)
	var a := minf(k_in, clampf((_card_len - _card_t) / 0.3, 0.0, 1.0))
	var cy := sz.y * 0.7
	var h := 66.0 * u * sc
	var reach := sz.x * (0.1 + 0.9 * UiKit.ease_out(k_in))
	var pts := PackedVector2Array()
	var n := 20
	for i in n + 1:
		var x := reach * float(i) / n
		var th := h * (0.75 + 0.25 * sin(float(i) * 1.1)) * (0.8 + 0.2 * sin(PI * float(i) / n))
		pts.append(Vector2(x, cy - th / 2.0))
	for i in range(n, -1, -1):
		var x := reach * float(i) / n
		var th := h * (0.75 + 0.25 * sin(float(i) * 0.8 + 2.0)) * (0.8 + 0.2 * sin(PI * float(i) / n))
		pts.append(Vector2(x, cy + th / 2.0))
	draw_colored_polygon(pts, Color(Toon.SUMI, 0.92 * a))
	var icon: String = _card[0]
	var nm: String = _card[1]
	var ep: String = _card[2]
	var sub: String = _card[3]
	# nom romanisé, puis l'épithète
	var fs := int(26 * u * sc)
	var tw := UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(UiKit.TITLE_FONT, Vector2(sz.x / 2.0 - tw / 2.0, cy + fs * 0.12), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.WASHI, a))
	if ep != "":
		var et := "— " + ep + " —"
		var efs := int(11 * u * sc)
		var ew := UiKit.UI_FONT.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, efs).x
		draw_string(UiKit.UI_FONT, Vector2(sz.x / 2.0 - ew / 2.0, cy + 20 * u * sc), et, HORIZONTAL_ALIGNMENT_LEFT, -1, efs, Color(Toon.WASHI, 0.82 * a))
	# sous-titre dans un sceau vermillon, sous le trait
	if sub != "":
		var sfs := int(10 * u * sc)
		var sw := UiKit.UI_FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		var sp := Vector2(sz.x / 2.0 - sw / 2.0, cy + h / 2.0 + 20 * u * sc)
		draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, 0.92 * a), 999), Rect2(sp + Vector2(-10 * u, -sfs - 3 * u), Vector2(sw + 20 * u, sfs + 10 * u)))
		draw_string(UiKit.UI_FONT, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(Toon.WASHI, a))
	# sceau picto : tombe comme un tampon, un peu après le trait (carré vermillon penché, cerné de papier)
	if icon != "":
		var ks := clampf((_card_t - 0.12) / 0.2, 0.0, 1.0)
		if ks > 0.0:
			var half := 24.0 * u * sc
			var kc := Vector2(sz.x / 2.0, cy - h / 2.0 - half - 6.0 * u)
			var z := lerpf(1.7, 1.0, UiKit.ease_out(ks))
			var ka := a * ks
			draw_set_transform(kc, deg_to_rad(-6.0), Vector2(z, z))
			draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, ka), int(6 * u), Color(UIColors.WASHI, ka), maxi(1, int(2.0 * u))), Rect2(-half, -half, half * 2.0, half * 2.0))
			UiKit.draw_icon(self, icon, Vector2.ZERO, half * 1.2, ka, UIColors.WASHI)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Zone de sécurité : l'encoche et la barre d'état ne doivent pas cacher la barre haute.
func _update_safe_top() -> void:
	var u := size.x / 400.0
	var inset := 0.0
	var win := DisplayServer.window_get_size()
	if win.y > 0:
		var safe := DisplayServer.get_display_safe_area()
		inset = float(safe.position.y) * size.y / float(win.y)
	top_off = clampf(inset, 0.0, 80.0 * u) + 12.0 * u


## Rituel du torii : un lavis d'encre part de l'arche (wash_c) et couvre l'écran (bords qui bavent,
## gouttes projetées) ; au retour (wash_out), l'encre se dilue et laisse voir la suite.
func _draw_wash(sz: Vector2, u: float) -> void:
	if wash_out:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(Toon.SUMI, clampf(wash, 0.0, 1.0)))
		return
	# le coin le plus loin de l'arche (sans tableau temporaire)
	var far := maxf(maxf(wash_c.distance_to(Vector2.ZERO), wash_c.distance_to(Vector2(sz.x, 0))),
		maxf(wash_c.distance_to(Vector2(0, sz.y)), wash_c.distance_to(sz)))
	var k := clampf(wash, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 2.2)
	if k >= 0.999:
		draw_rect(Rect2(Vector2.ZERO, sz), Toon.SUMI)
		return
	var r := far * 1.18 * e
	var n := 44
	_fill_pts.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		var jag := 1.0 + 0.09 * sin(float(i) * 3.1 + _t * 2.0) + 0.05 * sin(float(i) * 7.3)
		_fill_pts[i] = wash_c + Vector2.from_angle(a) * maxf(r * jag, 1.0)
	draw_colored_polygon(_fill_pts, Toon.SUMI)
	# gouttes projetées au front du lavis
	for j in 14:
		var a2 := TAU * float(j) / 14.0 + 0.4
		var d := r * (1.08 + 0.12 * sin(float(j) * 5.7))
		draw_circle(wash_c + Vector2.from_angle(a2) * d, (3.0 + 4.0 * absf(sin(float(j) * 2.3))) * u * (0.4 + e), Color(Toon.SUMI, 0.9))
	# halo doré de l'arche, au cœur du lavis
	if k < 0.6:
		draw_circle(wash_c, (18.0 + 30.0 * k) * u, Color(UIColors.GOLD, 0.35 * (1.0 - k / 0.6)))
