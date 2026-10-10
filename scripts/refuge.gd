extends Control
## Atelier : l'atelier du peintre. En-tête fin (retour, titre), jetons (encre, Vues), commande segmentée à deux onglets :
## - Arbre : l'Arbre du pinceau (meta.TREE, maquette validée) sur une feuille de papier : un tronc, quatre branches
##   (LAME, ENCRE, PAPIER, VOIE) de six nœuds et un sommet légendaire cerné d'or. Toucher un nœud le décrit dans
##   le panneau sombre du bas (branche, nom, effet, état) ; APPRENDRE l'achète en encre si celui du dessous est appris.
##   Hors de l'arbre, en bas à gauche de la feuille : la Bourse (pièce, cinq rangs en encre, AMÉLIORER) ;
## - Estampes : la collection des Vues (filtre par apparence) ; toucher ouvre la fiche de l'estampe, toucher encore
##   porte l'apparence : un sceau vermillon s'imprime.

const Toon = preload("res://scripts/toon.gd")
const Meta = preload("res://scripts/meta.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
const Data = preload("res://scripts/power_data.gd")

const BG := Color("#201814")  # bois sombre
const GOLD_HI := Color("#E2A93B")
const GOLD_INK := Color("#9A6B12")  # or lisible sur le papier
const LOCK_BODY := Color("#18141A")
const BADGE_R := 16.0  # rayon (en u) de la pastille de récompense des estampes
const C_COMMON := Color("#B9AE98")
const C_RARE := Color("#3D78B8")
const C_EPIC := Color("#8752B5")
const DRAG_START := 8.0  # glissé minimal (× u) avant de faire défiler
# en-tête (× u sous la marge de sécurité) : retour et titre (UiKit.HEAD_Y), jetons, onglets, filtres, liste
const COUNTERS_Y := 70.0
const TABS_Y := 110.0
const FILTERS_Y := 160.0
const LIST_TOP := 160.0
const LIST_TOP_PRINTS := 198.0
const TABS := ["ARBRE", "ESTAMPES"]
const TAB_GLYPHS := ["at_drop", "at_print"]
const CHIP_GLYPHS := ["at_drop", "at_print"]
const CHIP_COLORS := [Color("#2F5D8A"), Color("#C49A45")]
const CHIP_LABELS := ["ENCRE", "VUES"]
# arbre : abscisse de chaque branche (fraction de la feuille, maquette 52/148/242/338 sur 390), panneau du bas (× u),
# zone tactile d'un nœud (× u, ≥ 44)
const BRANCH_X := {"lame": 52.0 / 390.0, "encre": 148.0 / 390.0, "papier": 242.0 / 390.0, "voie": 338.0 / 390.0}
const DETAIL_H := 168.0
const PURSE := "purse"  # clé de la Bourse (hors de l'arbre) parmi les nœuds touchables
const NODE_HIT := 52.0
# glyphes des nœuds (tracés de la maquette, gabarit 60 × 60 centré en 30,30) : [tracé, épaisseur, rempli]
# Vague (S), Pointe (V) et Triangle : dessins simples, en attendant les pictos des nouvelles figures dans UiKit
const GLYPH_PATHS := {
	"lame": ["M21 39 L39 21 M19 34 L26 41", 3.6, false],
	"encre": ["M30 19 C35 27 38 30 38 34 A8 8 0 0 1 22 34 C22 30 25 27 30 19 Z", 1.0, true],
	"papier": ["M30 19 L39 23 L39 31 C39 37 34 40 30 42 C26 40 21 37 21 31 L21 23 Z", 3.0, false],
	"voie": ["M28 30 a2 2 0 1 1 4 0 a5 5 0 1 1 -9 -1.5 a9 9 0 1 1 16 5", 3.0, false],
	"vague": ["M19 34 C19 24 29 24 30 30 C31 36 41 36 41 26", 3.4, false],
	"pointe": ["M21 20 L30 40 L39 20", 3.4, false],
	"triangle": ["M30 19 L41 38 L19 38 Z", 3.4, false],
	"racine": ["M20 38 C26 28 32 22 40 20", 4.0, false],
}
const FILTERS := ["TOUT", "ÉCHARPES", "SILLAGES", "ENCRES"]
const FILTER_KINDS := ["", "cape", "trail", "ink"]
const KIND_LABELS := {"cape": "ÉCHARPE", "trail": "SILLAGE", "ink": "ENCRE"}
# élément de chaque monde (à la place de son idéogramme)
const WORLD_GLYPHS := ["great_wave", "star", "ghost", "fire", "one_stroke"]

signal closed

var meta  # instance de meta.gd, fournie par main avant open()

var _t := 0.0
var _tab_t := 0.0  # temps depuis le dernier changement d'onglet
var _u := 1.0
var _tab := 0
var _seg := 0.0  # position animée du segment actif
var _filter := 0  # filtre des estampes (0 = tout)
var _sel := ""  # estampe choisie (« print:w1_room ») : sa fiche est ouverte, le toucher suivant porte l'apparence
var _tree_sel := ""  # nœud de l'arbre décrit dans le panneau du bas (« root » : le tronc)
var _tree_rect := Rect2()  # feuille de l'arbre
var _detail_rect := Rect2()  # panneau du bas
var _tree_step := 60.0  # écart entre deux étages (px)
var _node_pos := {}  # id de nœud -> centre (écran)
var _pressed := ""  # cible sous le doigt
var _holding := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _press_scroll := 0.0
var _drag_accum := 0.0
var _scroll := 0.0
var _vel := 0.0
var _content_h := 0.0
var _view := Rect2()  # zone de la liste (coordonnées de l'écran)
var _list: Control
var _sheet: Control  # fiche d'une estampe, par-dessus la liste
var _sheet_t := 0.0
var _sheet_panel := Rect2()
var _sheet_btn := Rect2()
var _sheet_x := Rect2()
var _hits: Array = []  # [Rect2, cible] dessinés par l'Atelier
var _list_hits: Array = []  # [Rect2 (écran), cible] dessinés dans la liste
var _stamp_key := ""
var _stamp := 0.0  # sceau qui s'imprime (1 -> 0)
var _shake_key := ""
var _shake := 0.0  # refus (1 -> 0)
var _bump := 0.0
var _bump_i := 0  # jeton qui s'illumine (0 encre, 1 Vues)
var _disp := PackedFloat32Array([0.0, 0.0])  # valeurs affichées (le compteur défile)
var _spent := ""
var _spent_t := 0.0
var _msg := ""
var _msg2 := ""
var _msg_t := 0.0
var _back_rect := Rect2()
var _top := 0.0  # marge de sécurité du haut (encoche), en pixels : tout l'en-tête descend d'autant
var _bot := 0.0  # marge de sécurité du bas (barre de geste), en pixels
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = UiKit.TITLE_SPACING
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = UiKit.CAPS_SPACING
	# les listes (sceaux, estampes) se dessinent dans un enfant qui découpe ce qui dépasse
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.clip_contents = true
	_list.visible = false
	add_child(_list)
	_list.draw.connect(_draw_list)
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.visible = false
	add_child(_sheet)
	_sheet.draw.connect(_draw_sheet)


func open() -> void:
	_t = 0.0
	_tab_t = 0.0
	_seg = float(_tab)
	_sel = ""
	_tree_sel = _default_node()
	_pressed = ""
	_holding = false
	_dragging = false
	_bump = 0.0
	_stamp = 0.0
	_shake = 0.0
	_msg_t = 0.0
	_spent_t = 0.0
	_scroll = 0.0
	_vel = 0.0
	_content_h = 0.0
	_hits.clear()
	_list_hits.clear()
	if meta != null:
		for i in CHIP_LABELS.size():
			_disp[i] = _counter_val(i)
	visible = true


func _close() -> void:
	visible = false
	_holding = false
	_dragging = false
	closed.emit()


func _p(s: String) -> String:
	return UiKit.plain(s)


func _counter_val(i: int) -> float:
	if i == 0:
		return float(meta.sumi)
	return float(meta.prints)


## La fiche d'une estampe est ouverte (onglet Estampes, une Vue choisie).
func _sheet_on() -> bool:
	return _tab == 1 and _sel.begins_with("print:")


# ------------------------------------------------------------------ entrée

func _target_at(p: Vector2) -> String:
	if _sheet_on():
		if _sheet_btn.has_point(p):
			return _sel
		if _sheet_x.has_point(p) or not _sheet_panel.has_point(p):
			return "sheet:close"
		return "sheet:panel"
	if _back_rect.has_point(p):
		return "back"
	for i in range(_hits.size() - 1, -1, -1):
		var hr: Array = _hits[i]
		var r: Rect2 = hr[0]
		if r.has_point(p):
			return String(hr[1])
	if _tab > 0 and _view.has_point(p):
		for i in range(_list_hits.size() - 1, -1, -1):
			var hr: Array = _list_hits[i]
			var r: Rect2 = hr[0]
			if r.has_point(p):
				return String(hr[1])
	return ""


func _gui_input(event: InputEvent) -> void:
	if meta == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		accept_event()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed and _tab > 0 and _t >= 0.3 and not _sheet_on():
				var dir: float = -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				_scroll = clampf(_scroll + dir * 60.0 * _u, 0.0, _max_scroll())
				_vel = 0.0
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			# le toucher qui a ouvert l'atelier ne doit ni le refermer ni acheter
			_pressed = _target_at(mb.position) if _t >= 0.3 else ""
			if _t < 0.6 and _pressed == "learn":
				_pressed = ""
			_holding = true
			_dragging = false
			_press_pos = mb.position
			_press_scroll = _scroll
			_drag_accum = 0.0
			_vel = 0.0
			return
		# relâché : on n'agit que si l'appui et le relâché tombent sur la même cible (et sans glissé)
		var start := _pressed
		var was_drag := _dragging
		var was_holding := _holding
		_pressed = ""
		_holding = false
		_dragging = false
		if was_drag or not was_holding or _t < 0.3:
			return
		if start == "":
			_sel = ""  # toucher à côté : on repose le choix
		elif _target_at(mb.position) == start:
			_tap(start)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _holding or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		accept_event()
		if not _dragging:
			if _tab == 0 or _sheet_on() or not _view.has_point(_press_pos) or absf(mm.position.y - _press_pos.y) <= DRAG_START * _u:
				return
			_dragging = true
			_pressed = ""  # un glissé n'appuie sur rien
			_press_pos = mm.position
			_press_scroll = _scroll
		_scroll = _rubber(_press_scroll - (mm.position.y - _press_pos.y))
		_drag_accum += mm.relative.y


func _max_scroll() -> float:
	return maxf(0.0, _content_h - _view.size.y)


## Au-delà des bords, la liste résiste (élastique).
func _rubber(raw: float) -> float:
	var hi := _max_scroll()
	if raw < 0.0:
		return raw * 0.35
	if raw > hi:
		return hi + (raw - hi) * 0.35
	return raw


func _tap(key: String) -> void:
	if key == "back":
		_close()
		return
	if key == "sheet:panel":
		return
	if key == "sheet:close":
		_sel = ""
		return
	if key.begins_with("tab:"):
		var i := int(key.get_slice(":", 1))
		if i != _tab:
			_tab = i
			_tab_t = 0.0
			_sel = ""
			_msg_t = 0.0
			_scroll = 0.0
			_vel = 0.0
			_content_h = 0.0
			_list_hits.clear()
		return
	if key.begins_with("filter:"):
		var f := int(key.get_slice(":", 1))
		if f != _filter:
			_filter = f
			_scroll = 0.0
			_vel = 0.0
			_content_h = 0.0
			_list_hits.clear()
		_sel = ""
		return
	if key == "prev" or key == "next":
		meta.cycle_start_power(-1 if key == "prev" else 1)
		return
	if key.begins_with("node:"):
		_tree_sel = key.substr(5)  # un toucher : le nœud se décrit en bas ; APPRENDRE l'achète
		return
	if key == "learn":
		_learn()
		return
	if key != _sel:
		# premier toucher : on choisit (une estampe ouvre sa fiche) ; hors de portée, le refus se voit tout de suite
		if key.begins_with("print:") and not _sheet_on():
			_sheet_t = 0.0
		_sel = key
		_msg_t = 0.0
		if not _can_confirm(key) and not key.begins_with("print:"):
			_shake_key = key
			_shake = 1.0
		return
	_confirm(key)


## Vrai si un second toucher ferait quelque chose (porter une apparence).
func _can_confirm(key: String) -> bool:
	var kind := key.get_slice(":", 0)
	var id := key.get_slice(":", 1)
	match kind:
		"print":
			var ok3: bool = meta.has_print(id)
			return ok3
	return false


func _confirm(key: String) -> void:
	var kind := key.get_slice(":", 0)
	var id := key.get_slice(":", 1)
	match kind:
		"print":
			if not meta.has_print(id):
				_refuse(key)
				return
			var p: Dictionary = Meta.PRINTS[id]
			var look_kind := String(p["kind"])
			if meta.toggle_look(id):
				_flash(1, key, String(p["look"]), "Équipée dès maintenant, et à chaque partie.")
			else:
				_flash(1, key, "%s d'origine" % String(Meta.LOOK_NAMES[look_kind]), "Tu ne portes plus : %s." % String(p["look"]))


## Achat réussi : sceau imprimé, jeton qui s'illumine (et défile), message dans la barre du bas.
func _flash(counter: int, key: String, title: String, detail: String, spent := "") -> void:
	_stamp_key = key
	_stamp = 1.0
	_bump = 1.0
	_bump_i = counter
	_spent = spent
	_spent_t = 1.0 if spent != "" else 0.0
	_msg = title
	_msg2 = detail
	_msg_t = 2.2
	_sel = ""


func _refuse(key: String) -> void:
	_shake_key = key
	_shake = 1.0


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	_tab_t += real
	_sheet_t += real
	_bump = maxf(0.0, _bump - real * 2.5)
	_stamp = maxf(0.0, _stamp - real * 1.6)
	_shake = maxf(0.0, _shake - real * 2.5)
	_msg_t = maxf(0.0, _msg_t - real)
	_spent_t = maxf(0.0, _spent_t - real)
	_seg = lerpf(_seg, float(_tab), 1.0 - exp(-16.0 * real))
	if meta != null:
		# le compteur défile vers sa nouvelle valeur
		for i in CHIP_LABELS.size():
			var target := _counter_val(i)
			var cur: float = _disp[i]
			cur = target if absf(target - cur) < 0.5 else lerpf(cur, target, 1.0 - exp(-9.0 * real))
			_disp[i] = cur
	if _tab > 0:
		var hi := _max_scroll()
		if _dragging:
			if real > 0.0:
				_vel = lerpf(_vel, -_drag_accum / real, 0.35)
			_drag_accum = 0.0
		else:
			_drag_accum = 0.0
			# lancé : la liste continue sur son élan puis freine ; elle revient en place si elle dépasse
			if absf(_vel) > 2.0:
				_scroll += _vel * real
				_vel *= exp(-4.0 * real)
			else:
				_vel = 0.0
			if _scroll < 0.0 or _scroll > hi:
				_vel *= exp(-18.0 * real)
				_scroll = lerpf(_scroll, clampf(_scroll, 0.0, hi), 1.0 - exp(-14.0 * real))
	_layout()
	queue_redraw()
	_list.queue_redraw()
	if _sheet.visible:
		_sheet.queue_redraw()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var ins := UiKit.safe_insets(size)
	_top = ins.x
	_bot = ins.y
	_u = minf(w / 400.0, (h - _top - _bot) / 780.0)
	var u := _u
	var top := _top + (LIST_TOP_PRINTS if _tab == 1 else LIST_TOP) * u
	var reserve := 16.0 * u
	_view = Rect2(Vector2(10 * u, top), Vector2(w - 20 * u, maxf(10.0, h - _bot - reserve - top)))
	_list.position = _view.position
	_list.size = _view.size
	_list.visible = _tab > 0
	_list.modulate.a = UiKit.ease_out(_tab_t / 0.3)
	_sheet.position = Vector2.ZERO
	_sheet.size = size
	_sheet.visible = _sheet_on()
	if _sheet.visible:
		# fiche : panneau qui monte du bas
		var ph := minf(440.0 * u, h - _top - _bot - 40.0 * u)
		var off := (1.0 - UiKit.ease_out(_sheet_t / 0.25)) * (ph + 20.0 * u + _bot)
		_sheet_panel = Rect2(Vector2(14 * u, h - _bot - 14 * u - ph + off), Vector2(w - 28 * u, ph))
		_sheet_btn = Rect2(Vector2(_sheet_panel.position.x + 20 * u, _sheet_panel.end.y - 64 * u), Vector2(_sheet_panel.size.x - 40 * u, UiKit.BTN_H * u))
		_sheet_x = Rect2(Vector2(_sheet_panel.end.x - 48 * u, _sheet_panel.position.y), Vector2(46, 46) * u)
	else:
		_sheet_panel = Rect2()
		_sheet_btn = Rect2()
		_sheet_x = Rect2()


func _to_screen(r: Rect2) -> Rect2:
	return Rect2(r.position + _view.position, r.size)


# ------------------------------------------------------------------ outils de dessin

## Cadre arrondi (StyleBoxFlat réutilisée), ombre portée facultative.
func _panel(ci: CanvasItem, r: Rect2, bg: Color, radius: float, border := Color(0, 0, 0, 0), bw := 0.0, shadow := 0.0, u := 1.0) -> void:
	UiKit.box(_sb, bg, int(radius), border, maxi(1, int(round(bw))) if bw > 0.0 else 0)
	if shadow > 0.0:
		_sb.shadow_color = Color(0, 0, 0, shadow)
		_sb.shadow_size = int(10 * u)
		_sb.shadow_offset = Vector2(0, 4 * u)
	ci.draw_style_box(_sb, r)


## Taille de police qui fait tenir le texte dans maxw (sans descendre sous lo).
func _fit(font: Font, txt: String, fs: int, maxw: float, lo: int) -> int:
	var f := fs
	while f > lo and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > maxw:
		f -= 1
	return f


## Bouton de prix (planche Boutons v2) : « buy » = coup de pinceau vermillon (picto de monnaie et montant) ;
## armé (label non vide : le prochain toucher achète) = contour vermillon qui pulse, sans un mot ;
## « lack » (grisé), « owned » (coche seule) ; « max » (MAX en liseré d'or). Jamais de phrase.
func _button(ci: CanvasItem, r: Rect2, mode: String, label: String, glyph: String, amount: String, u: float, a: float, dark := false) -> void:
	var rad := r.size.y / 2.0
	var dk: bool = dark or Toon.ui_dark  # papier sombre (thème Nuit) : comme une carte légendaire
	var fs := int(r.size.y * 0.46)
	var ink: Color = Toon.WASHI
	var gbg: Color = UiKit.NONE
	var text := ""
	match mode:
		"buy":
			# pilule au pinceau (bords irréguliers) : ombre portée, corps, reflet ; armé : contour vermillon autour
			ci.draw_colored_polygon(_brush_pill(Rect2(r.position + Vector2(0, 2.5 * u), r.size), 1.0), Color(Toon.VERMILION.darkened(0.4), a))
			ci.draw_colored_polygon(_brush_pill(r, 7.0), Color(Toon.VERMILION, a))
			ci.draw_rect(Rect2(r.position + Vector2(rad, 2.0 * u), Vector2(maxf(0.0, r.size.x - rad * 2.0), 1.5 * u)), Color(1, 1, 1, 0.18 * a))
			if label != "":
				var pulse := 0.6 + 0.4 * sin(_t * 6.0)
				_panel(ci, r.grow(4.0 * u), Color(0, 0, 0, 0), rad + 4.0 * u, Color(Toon.VERMILION, (0.5 + 0.5 * pulse) * a), 2.0 * u)
			gbg = Toon.VERMILION
		"lack":
			var base: Color = Toon.WASHI if dk else Toon.ui_ink
			_panel(ci, r, Color(base, 0.09 * a), rad)
			ink = Color(base, 0.4)
		"max":
			_panel(ci, r, Color(GOLD_HI, 0.12 * a), rad, Color(GOLD_HI, a), 1.5 * u)
			ink = GOLD_HI if dk else GOLD_INK  # or lisible sur le papier
			text = "MAX"
		_:
			_panel(ci, r, Color(0, 0, 0, 0), rad, Color(GOLD_HI if dk else Toon.VERMILION, a), 1.5 * u)
			ink = GOLD_HI if dk else Toon.VERMILION
			text = label
	var gap := 5.0 * u
	var lw := 0.0
	if text != "":
		lw = _ui.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + gap
	var gr := float(fs) * 0.55
	var gw := gr * 2.0 + gap if glyph != "" else 0.0
	var nf := UiKit.num_font()
	var aw := nf.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 1).x if amount != "" else 0.0
	var total := lw + gw + aw
	if amount == "" and total > 0.0:
		total -= gap  # pas d'écart après le dernier morceau
	var x := r.get_center().x - total / 2.0
	var by := r.get_center().y + float(fs) * 0.36
	if text != "":
		ci.draw_string(_ui, Vector2(x, by), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, ink.a * a))
		x += lw
	if glyph != "":
		UiKit.glyph(ci, glyph, Vector2(x + gr, r.get_center().y), gr, ink, gbg, a)
		x += gw
	if amount != "":
		ci.draw_string(nf, Vector2(x, by + 0.5 * u), amount, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 1, Color(ink, ink.a * a))


## Contour d'une pilule posée au pinceau : demi-cercles aux deux bouts, bord qui ondule à peine (sd : graine).
func _brush_pill(r: Rect2, sd: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hh := r.size.y * 0.5
	var n := 10
	var c0 := Vector2(r.position.x + hh, r.get_center().y)
	var c1 := Vector2(r.end.x - hh, r.get_center().y)
	for i in n + 1:
		var ang := PI * 0.5 + PI * float(i) / float(n)
		var wob := 1.0 + 0.04 * (0.5 * sin(float(i) * 12.9898 + sd * 78.233) + 0.5 * sin(float(i) * 4.1 + sd * 3.7))
		pts.append(c0 + Vector2.from_angle(ang) * hh * wob)
	for i in n + 1:
		var ang := -PI * 0.5 + PI * float(i) / float(n)
		var wob := 1.0 + 0.04 * (0.5 * sin(float(i + 7) * 12.9898 + sd * 78.233) + 0.5 * sin(float(i + 7) * 4.1 + sd * 3.7))
		pts.append(c1 + Vector2.from_angle(ang) * hh * wob)
	return pts


## Sceau tamponné (achat, apparence portée) : grand carré vermillon qui se pose puis s'efface.
func _stamp_fx(ci: CanvasItem, c: Vector2, txt: String, u: float) -> void:
	var st := _stamp
	var k2 := 1.0 - st
	var size_k := 1.0 + 0.8 * maxf(0.0, 1.0 - k2 * 5.0)
	var half := 22.0 * u * size_k
	ci.draw_rect(Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0), Color(Toon.VERMILION, 0.85 * st), false, 4.0 * u)
	if txt != "":
		var fs := int(24 * u * size_k)
		UiKit.text(ci, UiKit.TITLE_FONT, txt, Vector2(c.x, c.y + fs * 0.36), fs, Color(Toon.VERMILION, 0.85 * st))
	# éclats d'or qui partent du sceau
	for ray in 10:
		var d := Vector2.from_angle(TAU * float(ray) / 10.0 + 0.3)
		var r0 := (26.0 + 30.0 * k2) * u
		ci.draw_line(c + d * r0, c + d * (r0 + 9.0 * u * st), Color(GOLD_HI, 0.8 * st), 2.0 * u)


## Bande verticale en dégradé (fondus, vignettage).
func _vgrad(ci: CanvasItem, r: Rect2, c0: Color, c1: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c0, c0, c1, c1]))


func _hgrad(ci: CanvasItem, r: Rect2, c0: Color, c1: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c0, c1, c1, c0]))


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	var u := _u
	_hits.clear()
	_draw_bg(w, h, u)
	_draw_header(w, u)
	_draw_counters(w, u)
	_draw_tabs(w, u)
	if _tab == 0:
		_draw_tree(w, h, u)
	else:
		_draw_filters(w, u)
		_draw_info(w, h, u)
	if _sheet_on():
		_hits.append([_sheet_btn, _sel])


## Bois sombre : planches à peine marquées, lumière douce en haut, vignettage.
func _draw_bg(w: float, h: float, u: float) -> void:
	draw_rect(Rect2(0, 0, w, h), BG)
	var x := 0.0
	var i := 0
	while x < w:
		draw_rect(Rect2(x, 0, 1.0 * u, h), Color(1, 1, 1, 0.025))
		draw_rect(Rect2(x + 1.0 * u, 0, 1.0 * u, h), Color(0, 0, 0, 0.12))
		x += 52.0 * u + float(i % 3) * 7.0 * u
		i += 1
	for k in 4:
		draw_circle(Vector2(w * 0.5, -h * 0.08), w * (0.45 + 0.22 * float(k)), Color(1.0, 0.85, 0.6, 0.02))
	# kumiko : treillis asanoha à peine visible dans le bois (motif mis en cache, un seul tracé)
	UiKit.asanoha(self, Rect2(Vector2(0, 0), Vector2(w, h)), Color(Toon.WASHI, 0.03), 34.0 * u)
	_vgrad(self, Rect2(0, 0, w, _top + 70 * u), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0))
	_vgrad(self, Rect2(0, h - 120 * u, w, 120 * u), Color(0, 0, 0, 0), Color(0, 0, 0, 0.4))
	_hgrad(self, Rect2(0, 0, 36 * u, h), Color(0, 0, 0, 0.25), Color(0, 0, 0, 0))
	_hgrad(self, Rect2(w - 36 * u, 0, 36 * u, h), Color(0, 0, 0, 0), Color(0, 0, 0, 0.25))


## En-tête commun : bouton rond à la maison (comme la carte des mondes et la garde-robe), titre souligné
## de vermillon.
func _draw_header(w: float, u: float) -> void:
	var a := UiKit.ease_out(_t / 0.4)
	var c := Vector2(UiKit.HEAD_X * u, _top + UiKit.HEAD_Y * u)
	_back_rect = UiKit.back_rect(c, u)
	UiKit.back_button(self, c, u, a, 1.0 if _pressed == "back" else 0.0, true)
	var ty := _top + UiKit.HEAD_BASE * u - 8.0 * u * (1.0 - a)
	UiKit.screen_title(self, _title, "ATELIER", Vector2(w / 2.0, ty), u, Toon.WASHI, a, "", w - 2.0 * 80.0 * u, UiKit.ease_out(clampf((_t - 0.15) / 0.4, 0.0, 1.0)))


## Encre, Vues : jetons sombres (comme le HUD), pictogramme sur pastille, chiffre en gras.
func _draw_counters(w: float, u: float) -> void:
	if meta == null:
		return
	var a := UiKit.ease_out((_t - 0.1) / 0.4)
	var gap := 8.0 * u
	var nc := CHIP_LABELS.size()
	var cw := (w - 28.0 * u - gap * float(nc - 1)) / float(nc)
	for i in nc:
		var r := Rect2(Vector2(14 * u + float(i) * (cw + gap), _top + COUNTERS_Y * u), Vector2(cw, UiKit.CHIP_H * u))
		var lit := _bump > 0.0 and i == _bump_i
		var k := 1.0 + (0.07 * _bump if lit else 0.0)
		var rr := Rect2(r.get_center() - r.size * k / 2.0, r.size * k)
		var edge: Color = Color(GOLD_HI, (0.25 + 0.6 * _bump) * a) if lit else Color(Toon.WASHI, 0.12 * a)
		_panel(self, rr, Color(Toon.SUMI, 0.62 * a), rr.size.y / 2.0, edge, 1.5 * u)
		var col: Color = CHIP_COLORS[i]
		var ic := rr.position + Vector2(15 * u, rr.size.y / 2.0)
		draw_circle(ic, 11.0 * u * k, Color(col, a))
		draw_arc(ic, 11.0 * u * k, 0.0, TAU, 24, Color(1, 1, 1, 0.18 * a), 1.0 * u, true)
		UiKit.glyph(self, String(CHIP_GLYPHS[i]), ic, 6.5 * u * k, Toon.SUMI if i == 1 else Toon.WASHI, col, a)
		var v := int(round(_disp[i]))
		var txt := str(v) if i == 0 else "%d/%d" % [v, Meta.MAX_PRINTS]
		var fs := int(15 * u)
		var tc: Color = GOLD_HI if lit else Toon.WASHI
		draw_string(UiKit.UI_FONT, Vector2(ic.x + 16 * u, rr.get_center().y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tc, a))
		var num_end := ic.x + 16 * u + UiKit.UI_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lfs := int(UiKit.FS_MICRO * u)
		var lab := String(CHIP_LABELS[i])
		var la := 0.45 * a
		var spending := _spent_t > 0.0 and i == _bump_i
		if spending:
			# la dépense s'envole à la place du libellé
			lab = _spent
			lfs = int(UiKit.FS_BODY * u)
			la = minf(1.0, _spent_t * 2.0) * a
		var lw := _ui.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		var rise := (1.0 - _spent_t) * 8.0 * u if spending else 0.0
		var lc: Color = Color("#FF8A7A") if spending else Toon.WASHI
		var lx := rr.end.x - 12 * u - lw
		# grand nombre : le libellé s'efface plutôt que de chevaucher le chiffre (la dépense, elle, reste)
		if spending or lx >= num_end + 5.0 * u:
			draw_string(_ui, Vector2(lx, rr.get_center().y + lfs * 0.36 - rise), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(lc, la))


## Onglets (UI v2, Boutons) : un mot par onglet, coup de pinceau papier derrière l'actif (il glisse) ; pastille : un
## achat est à portée.
func _draw_tabs(w: float, u: float) -> void:
	if meta == null:
		return
	var a := UiKit.ease_out((_t - 0.15) / 0.4)
	var bar := Rect2(Vector2(14 * u, _top + TABS_Y * u), Vector2(w - 28 * u, UiKit.SEG_H * u))
	var dots: Array = []
	if meta.any_learnable():
		dots.append(0)
	var trs: Array = UiKit.tabs(self, TABS, bar, _seg, Toon.WASHI, Toon.SUMI, Color(Toon.WASHI, 0.75), a, u, dots)
	for i in trs.size():
		_hits.append([trs[i], "tab:%d" % i])


# ------------------------------------------------------------------ arbre du pinceau

## Nœud choisi d'office à l'ouverture : le moins cher des nœuds à portée, sinon le premier disponible, sinon le tronc.
func _default_node() -> String:
	if meta == null:
		return Meta.TREE_ROOT
	var best := ""
	for id in Meta.TREE_ORDER:
		if meta.can_learn(String(id)) and (best == "" or int(meta.node_cost(String(id))) < int(meta.node_cost(best))):
			best = String(id)
	if best != "":
		return best
	for id in Meta.TREE_ORDER:
		if meta.node_open(String(id)):
			return String(id)
	return Meta.TREE_ROOT


## Choisit un nœud (captures `?atelier&noeud=v2`, robot) : le panneau du bas le décrit.
func select_node(id: String) -> void:
	if id == Meta.TREE_ROOT or id == PURSE or Meta.TREE.has(id):
		_tree_sel = id
		_tab = 0
		_seg = 0.0


## APPRENDRE : débite l'encre et apprend le nœud choisi ; refus (secousse du bouton) sinon.
func _learn() -> void:
	var id := _tree_sel
	if meta != null and id == PURSE:
		var pc: int = meta.purse_cost()
		if meta.buy_purse():
			_stamp_key = "node:" + PURSE
			_stamp = 1.0
			_bump = 1.0
			_bump_i = 0
			_spent = "-%d" % pc
			_spent_t = 1.0
		else:
			_refuse("learn")
		return
	if meta == null or not Meta.TREE.has(id) or meta.learned(id):
		return
	var c: int = meta.node_cost(id)
	if meta.learn(id):
		_stamp_key = "node:" + id
		_stamp = 1.0
		_bump = 1.0
		_bump_i = 0
		_spent = "-%d" % c
		_spent_t = 1.0
	else:
		_refuse("learn")


## Géométrie de l'arbre (feuille de papier, panneau du bas, centre de chaque nœud), adaptée à la hauteur.
func _tree_layout(w: float, h: float, u: float) -> void:
	var top := _top + LIST_TOP * u
	var ph := DETAIL_H * u
	_detail_rect = Rect2(Vector2(10 * u, h - _bot - 10 * u - ph), Vector2(w - 20 * u, ph))
	_tree_rect = Rect2(Vector2(10 * u, top), Vector2(w - 20 * u, maxf(80.0 * u, _detail_rect.position.y - 10 * u - top)))
	var root_y := _tree_rect.end.y - 31.0 * u
	var t1 := root_y - 50.0 * u
	var t7 := _tree_rect.position.y + 37.0 * u
	_tree_step = minf(66.0 * u, maxf(10.0, (t1 - t7) / 6.0))
	_node_pos.clear()
	_node_pos[Meta.TREE_ROOT] = Vector2(_tree_rect.get_center().x, root_y)
	# Bourse : coin bas gauche, sous la branche LAME (la courbe du tronc passe au-dessus)
	_node_pos[PURSE] = Vector2(_tree_rect.position.x + _tree_rect.size.x * float(BRANCH_X["lame"]), root_y + 4.0 * u)
	for id in Meta.TREE_ORDER:
		var n: Dictionary = Meta.TREE[id]
		var bx: float = _tree_rect.position.x + _tree_rect.size.x * float(BRANCH_X[String(n["b"])])
		_node_pos[String(id)] = Vector2(bx, t1 - float(int(n["t"]) - 1) * _tree_step)


func _branch_col(id: String) -> Color:
	if id == PURSE:
		return UIColors.GOLD
	if not Meta.TREE.has(id):
		return UIColors.SUMI
	var n: Dictionary = Meta.TREE[id]
	var b: Dictionary = Meta.BRANCHES[String(n["b"])]
	return b["col"]


## Feuille de l'arbre (papier washi, comme la maquette) puis panneau de détail sombre en bas.
func _draw_tree(w: float, h: float, u: float) -> void:
	if meta == null:
		return
	_tree_layout(w, h, u)
	var a := UiKit.ease_out(_tab_t / 0.3)
	var tr := _tree_rect
	_panel(self, tr, Color(UIColors.WASHI, a), UiKit.R_L * u, Color(UIColors.SUMI, 0.5 * a), 1.5 * u, 0.4 * a, u)
	UiKit.fibres(self, tr.grow(-8.0 * u), UIColors.SUMI, a, u, 4.2, 10)
	# légende en bas à droite, sous les liens
	var cap := _p("ARBRE DU PINCEAU")
	var cfs := int(UiKit.FS_MICRO * u)
	var cw := _ui.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
	var cx := tr.end.x - 14 * u - cw
	draw_string(_ui, Vector2(cx, tr.end.y - 11 * u), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(UIColors.TEXT_MUTED, 0.8 * a))
	draw_rect(Rect2(Vector2(tr.end.x - 14 * u - minf(cw, 60.0 * u), tr.end.y - 8 * u), Vector2(minf(cw, 60.0 * u), 2.0 * u)), Color(UIColors.VERMILION, a))
	# liens : du tronc au premier nœud (courbe), puis d'étage en étage ; couleur de la branche une fois appris
	var root: Vector2 = _node_pos[Meta.TREE_ROOT]
	for id in Meta.TREE_ORDER:
		var n: Dictionary = Meta.TREE[id]
		var p: Vector2 = _node_pos[String(id)]
		var on: bool = meta.learned(String(id))
		var col: Color = _branch_col(String(id)) if on else UIColors.LINE_MUTED
		var lw := (5.0 if on else 3.0) * u
		if int(n["t"]) == 1:
			var pts := PackedVector2Array()
			var c1 := root + Vector2(0, -30.0 * u)
			var c2 := p + Vector2(0, 40.0 * u)
			for i in 17:
				var t := float(i) / 16.0
				var q := 1.0 - t
				pts.append(root * q * q * q + c1 * 3.0 * q * q * t + c2 * 3.0 * q * t * t + p * t * t * t)
			draw_polyline(pts, Color(col, a), lw, true)
		else:
			var below: Vector2 = _node_pos[String(meta.node_prereq(String(id)))]
			draw_line(below, p, Color(col, a), lw, true)
	# nœuds (le tronc d'abord)
	_tree_node(Meta.TREE_ROOT, u, a)
	for id in Meta.TREE_ORDER:
		_tree_node(String(id), u, a)
	_purse_node(u, a)
	_draw_detail(w, u)


## Bourse (hors de l'arbre) : pièce d'or plus petite qu'un nœud, son rang dessous (« 2/5 ») ; pleine au rang max.
func _purse_node(u: float, a: float) -> void:
	var c: Vector2 = _node_pos[PURSE]
	var key := "node:" + PURSE
	var k := 40.0 / 60.0 * u
	if _pressed == key:
		k *= 0.94
	var maxed: bool = meta.purse_cost() < 0
	var r: int = meta.purse_rank
	if _tree_sel == PURSE:
		draw_circle(c, 29.0 * k, Color(UIColors.GOLD, 0.25 * a))
	draw_circle(c, 22.0 * k, Color(UIColors.GOLD if r > 0 else UIColors.WASHI_LIGHT, a))
	draw_arc(c, 22.0 * k, 0.0, TAU, 40, Color(UIColors.SUMI if maxed else UIColors.GOLD_DARK, a), 2.5 * k, true)
	UiKit.koban(self, c, 11.0 * k, a)
	var t := "%d/%d" % [r, Meta.PURSE_COSTS.size()]
	var fs := int(UiKit.FS_MICRO * u)
	var tw := _ui.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_ui, Vector2(c.x + 22.0 * k + 4.0 * u, c.y + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIColors.TEXT_MUTED, a))
	if _stamp_key == key and _stamp > 0.0:
		var st := _stamp
		draw_arc(c, 22.0 * k + (1.0 - st) * 30.0 * u, 0.0, TAU, 40, Color(GOLD_HI, st * a), 1.0 + 3.0 * u * st, true)
	var hw := maxf(UiKit.TOUCH_MIN * u, 22.0 * k * 2.0 + tw + 10.0 * u)
	_hits.append([Rect2(Vector2(c.x - UiKit.TOUCH_MIN * u / 2.0, c.y - UiKit.TOUCH_MIN * u / 2.0), Vector2(hw, UiKit.TOUCH_MIN * u)), key])


## Un nœud (maquette : disque 22 dans un gabarit 60 ; sommet en 60, nœud en 50) : appris = plein à la couleur de la
## branche, disponible = anneau de couleur sur papier clair, verrouillé = gris et cadenas ; sommet cerné d'or.
func _tree_node(id: String, u: float, a: float) -> void:
	var c: Vector2 = _node_pos[id]
	var is_root := id == Meta.TREE_ROOT
	var cap := false
	var glyph := "racine"
	if not is_root:
		var n: Dictionary = Meta.TREE[id]
		cap = int(n["t"]) == 7
		glyph = String(n["glyph"])
	var owned: bool = meta.learned(id)
	var av: bool = (not is_root) and bool(meta.node_open(id))
	var col := _branch_col(id)
	var k := (60.0 if cap else 50.0) / 60.0 * u  # unités de la maquette -> pixels
	var key := "node:" + id
	var cc := c
	if _pressed == key:
		k *= 0.94
	if _tree_sel == id:
		draw_circle(cc, 29.0 * k, Color(col, 0.22 * a))
	if cap:
		draw_arc(cc, 27.0 * k, 0.0, TAU, 48, Color(UIColors.GOLD_DARK, a), 2.5 * k, true)
	var fill: Color = col if owned else (UIColors.WASHI_LIGHT if av else UIColors.WASHI_DARK)
	var ring: Color = UIColors.SUMI if owned else (UIColors.GOLD_DARK if cap else (col if av else UIColors.LINE_MUTED))
	var ring_w := 2.0 if owned else (3.5 if av else 2.0)
	draw_circle(cc, 22.0 * k, Color(fill, a))
	draw_arc(cc, 22.0 * k, 0.0, TAU, 48, Color(ring, a), ring_w * k, true)
	var ink: Color = UIColors.WASHI_LIGHT if owned else (col if av else UIColors.DISABLED)
	if is_root:
		ink = UIColors.WASHI_LIGHT
	var gd: Array = GLYPH_PATHS[glyph]
	var gfill: Color = ink if bool(gd[2]) else UiKit.NONE
	UiKit.draw_path(self, String(gd[0]), 60, cc, 60.0 * k, ink, float(gd[1]), gfill, a)
	if not owned and not av and not is_root:
		# cadenas : corps et anse
		draw_arc(cc + Vector2(15.0, 9.5) * k, 3.6 * k, PI, TAU, 10, Color(UIColors.DISABLED, a), 1.8 * k, true)
		_panel(self, Rect2(cc + Vector2(9.0, 9.0) * k, Vector2(12.0, 10.0) * k), Color(UIColors.DISABLED, a), 2.0 * k)
	if _stamp_key == key and _stamp > 0.0:
		var st := _stamp
		draw_circle(cc, 22.0 * k, Color(1, 1, 1, 0.5 * st * st * a))
		draw_arc(cc, 22.0 * k + (1.0 - st) * 40.0 * u, 0.0, TAU, 40, Color(GOLD_HI, st * a), 1.0 + 3.0 * u * st, true)
	# zone tactile : 52 u de large, au moins 44 u de haut (l'étage peut être plus serré sur un petit écran)
	var hh := clampf(_tree_step, UiKit.TOUCH_MIN * u, NODE_HIT * u)
	_hits.append([Rect2(c - Vector2(NODE_HIT * u, hh) / 2.0, Vector2(NODE_HIT * u, hh)), key])


## Panneau du bas (maquette) : pastille et nom de la branche, nom du nœud, effet, état et bouton APPRENDRE.
## « Rouleau de départ » appris : son état laisse place au choix du rouleau (flèches).
func _draw_detail(w: float, u: float) -> void:
	var a := UiKit.ease_out(_tab_t / 0.3)
	var r := _detail_rect
	_panel(self, r, Color(UIColors.SUMI, a), UiKit.R_L * u, Color(UIColors.WASHI, 0.14 * a), 1.5 * u, 0.4 * a, u)
	var id := _tree_sel
	var is_root := not Meta.TREE.has(id)
	var col := _branch_col(id)
	var bname := "TRONC"
	var nm := "Le premier trait"
	var fx := "Le point de départ de toutes les branches."
	var cost := 0
	var owned := true
	var av := false
	if id == PURSE:
		# Bourse : rang actuel -> suivant, AMÉLIORER (ou MAX)
		is_root = false
		var pr: int = meta.purse_rank
		var pmax := Meta.PURSE_COSTS.size()
		bname = "HORS DE L'ARBRE · %d/%d" % [pr, pmax]
		nm = "Bourse"
		cost = meta.purse_cost()
		owned = cost < 0
		av = not owned
		if owned:
			fx = "Encre gagnée en fin de partie +%d %% (rang max)." % (Meta.PURSE_STEP * pr)
		else:
			fx = "Encre gagnée en fin de partie +%d %%, puis +%d %% au rang suivant." % [Meta.PURSE_STEP * pr, Meta.PURSE_STEP * (pr + 1)]
	elif not is_root:
		var n: Dictionary = Meta.TREE[id]
		var b: Dictionary = Meta.BRANCHES[String(n["b"])]
		bname = String(b["name"]) + (" · SOMMET" if int(n["t"]) == 7 else " · %d" % int(n["t"]))
		nm = String(n["name"])
		fx = String(n["text"])
		cost = int(n["cost"])
		owned = meta.learned(id)
		av = meta.node_open(id)
	var can: bool = bool(meta.can_buy_purse()) if id == PURSE else ((not is_root) and bool(meta.can_learn(id)))
	var x := r.position.x + 18 * u
	var xr := r.end.x - 18 * u
	# branche
	draw_circle(Vector2(x + 5 * u, r.position.y + 18 * u), 5.0 * u, Color(col if not is_root else UIColors.WASHI, a))
	draw_string(_ui, Vector2(x + 16 * u, r.position.y + 18 * u + UiKit.FS_MICRO * u * 0.36), _p(bname), HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(UiKit.FS_MICRO * u), Color(UIColors.WASHI, 0.7 * a))
	# nom
	var nfs := _fit(UiKit.TITLE_FONT, nm, int(19 * u), xr - x, int(13 * u))
	draw_string(UiKit.TITLE_FONT, Vector2(x, r.position.y + 45 * u), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(UIColors.WASHI, a))
	# effet (deux lignes au plus)
	var efs := int(12.5 * u)
	var lines := UiKit.wrap(UiKit.UI_FONT, fx, efs, xr - x, [":", "%", "»", "!", "?"])
	if lines.size() > 2:
		efs = int(11 * u)
		lines = UiKit.wrap(UiKit.UI_FONT, fx, efs, xr - x, [":", "%", "»", "!", "?"])
	for i in mini(lines.size(), 3):
		draw_string(UiKit.UI_FONT, Vector2(x, r.position.y + 68 * u + float(i) * (efs + 4.0 * u)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, efs,
			Color(UIColors.WASHI, 0.85 * a))
	# bouton APPRENDRE (à droite, 44 u de haut)
	var bh := UiKit.TOUCH_MIN * u
	var label := "APPRIS" if owned else "APPRENDRE · %d" % cost
	if id == PURSE:
		label = "MAX" if owned else "AMÉLIORER · %d" % cost
	var bfs := int(12.5 * u)
	var bw := maxf(118.0 * u, UiKit.TITLE_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x + 34.0 * u)
	var br := Rect2(Vector2(xr - bw, r.end.y - 12 * u - bh), Vector2(bw, bh))
	if _shake_key == "learn" and _shake > 0.0:
		br.position.x += sin(_t * 60.0) * 4.0 * u * _shake
	if _pressed == "learn":
		br = Rect2(br.get_center() - br.size * 0.48, br.size * 0.96)
	if can:
		draw_colored_polygon(_brush_pill(Rect2(br.position + Vector2(0, 2.5 * u), br.size), 1.0), Color(UIColors.VERMILION_DARK.darkened(0.3), a))
		draw_colored_polygon(_brush_pill(br, 7.0), Color(UIColors.VERMILION, a))
		UiKit.text(self, UiKit.TITLE_FONT, label, Vector2(br.get_center().x, br.get_center().y + bfs * 0.36), bfs, Color(UIColors.WASHI_LIGHT, a))
	else:
		_panel(self, br, Color(0, 0, 0, 0), bh / 2.0, Color(UIColors.WASHI, 0.25 * a), 1.5 * u)
		UiKit.text(self, UiKit.TITLE_FONT, label, Vector2(br.get_center().x, br.get_center().y + bfs * 0.36), bfs, Color(UIColors.WASHI, 0.4 * a))
	if not is_root and not owned:
		_hits.append([br, "learn"])
	# état (ou choix du rouleau de départ)
	var sx1 := br.position.x - 10 * u
	if id == "v3" and owned:
		_start_chooser(Rect2(Vector2(x, br.position.y), Vector2(sx1 - x, bh)), u, a)
		return
	var st := "RANG MAX" if id == PURSE else "APPRIS"
	var sc: Color = UIColors.JADE_UP_ON_DARK
	if not is_root and not owned:
		if av:
			st = ("DISPONIBLE · %d ENCRE" % cost) if can else ("IL MANQUE %d ENCRE" % (cost - int(meta.sumi)))
			sc = UIColors.GOLD if can else UIColors.MALUS_ON_DARK
		else:
			st = "VERROUILLÉ : APPRENDS LE NŒUD DU DESSOUS"
			sc = UIColors.MALUS_ON_DARK
	st = _p(st)
	var sfs := int(10.5 * u)
	var sl := UiKit.wrap(_ui, st, sfs, sx1 - x, [":"])
	var cy := br.get_center().y
	var y0 := cy - float(sl.size() - 1) * (sfs + 2.0 * u) / 2.0
	for i in sl.size():
		draw_string(_ui, Vector2(x, y0 + float(i) * (sfs + 2.0 * u) + sfs * 0.36), sl[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(sc, a))


## Choix du rouleau de départ (nœud « Rouleau de départ » appris) : flèches rondes de part et d'autre du rouleau.
func _start_chooser(r: Rect2, u: float, a: float) -> void:
	var sp: String = meta.start_power()
	var cy := r.get_center().y
	var lc := Vector2(r.position.x + 15 * u, cy)
	var rc := Vector2(r.end.x - 15 * u, cy)
	for side in [[lc, -1.0, "prev"], [rc, 1.0, "next"]]:
		var c: Vector2 = side[0]
		var dir: float = side[1]
		var k := 0.88 if _pressed == String(side[2]) else 1.0
		draw_circle(c, 14 * u * k, Color(UIColors.WASHI, a))
		draw_colored_polygon(PackedVector2Array([c + Vector2(5.5 * dir, 0) * u * k, c + Vector2(-3.5 * dir, -6) * u * k, c + Vector2(-3.5 * dir, 6) * u * k]),
			Color(UIColors.SUMI, a))
		_hits.append([Rect2(c - Vector2(22, 22) * u, Vector2(44, 44) * u), String(side[2])])
	var x0 := lc.x + 22 * u
	var x1 := rc.x - 22 * u
	var nm := _power_name(sp)
	if Data.POWERS.has(sp):
		UiKit.power_icon(self, sp, Vector2(x0 + 10 * u, cy), 10.0 * u, a)
		x0 += 24 * u
	var nfs := _fit(UiKit.TITLE_FONT, nm, int(12 * u), x1 - x0, int(8 * u))
	draw_string(UiKit.TITLE_FONT, Vector2(x0, cy + nfs * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, x1 - x0, nfs, Color(UIColors.WASHI, a))


# ------------------------------------------------------------------ estampes : filtre

func _draw_filters(w: float, u: float) -> void:
	# onglets secondaires (UI v2) : même dessin que les onglets principaux, plus bas et plus serrés
	var a := UiKit.ease_out(_tab_t / 0.3)
	var bar := Rect2(Vector2(14.0 * u, _top + FILTERS_Y * u), Vector2(w - 28.0 * u, UiKit.CHIP_H * u))
	var trs: Array = UiKit.tabs(self, FILTERS, bar, float(_filter), Toon.WASHI, Toon.SUMI, Color(Toon.WASHI, 0.7), a, u)
	for i in trs.size():
		_hits.append([trs[i], "filter:%d" % i])


# ------------------------------------------------------------------ ligne du bas

## Ligne fine du bas (estampes), seulement quand elle a quelque chose à dire : l'apparence qui vient d'être portée
## (coche, titre). Jamais de paragraphe.
func _draw_info(w: float, h: float, u: float) -> void:
	if meta == null:
		return
	var info := _banner_info()
	if info.is_empty():
		return
	var a := UiKit.ease_out((_t - 0.25) / 0.4)
	if _msg_t > 0.0:
		a *= clampf(_msg_t / 0.3, 0.0, 1.0)
	var r := Rect2(Vector2(14 * u, h - _bot - 62 * u), Vector2(w - 28 * u, 48 * u))
	var title := String(info[0])
	var detail := String(info[1])
	var lit: bool = info[2]
	_panel(self, r, Color(Toon.SUMI, 0.8 * a), 14 * u, Color(GOLD_HI, 0.8 * a) if lit else Color(Toon.WASHI, 0.1 * a), 1.5 * u, 0.3 * a, u)
	var ic := r.position + Vector2(24 * u, r.size.y / 2.0)
	var gi := _info_icon(lit)
	var icol: Color = gi[1]
	draw_circle(ic, 13 * u, Color(icol, a))
	UiKit.glyph(self, String(gi[0]), ic, 8.0 * u, Toon.WASHI, icol, a)
	var tx := r.position.x + 46 * u
	var tw := r.end.x - 12 * u - tx
	if detail == "":
		var tfs := _fit(UiKit.TITLE_FONT, _p(title), int(13 * u), tw, int(9 * u))
		draw_string(UiKit.TITLE_FONT, Vector2(tx, r.get_center().y + tfs * 0.36), _p(title), HORIZONTAL_ALIGNMENT_LEFT, tw, tfs, Color(GOLD_HI if lit else Toon.WASHI, a))
	else:
		var tfs := _fit(UiKit.TITLE_FONT, _p(title), int(12 * u), tw, int(9 * u))
		draw_string(UiKit.TITLE_FONT, Vector2(tx, r.position.y + 19 * u), _p(title), HORIZONTAL_ALIGNMENT_LEFT, tw, tfs, Color(Toon.WASHI, a))
		var dfs := _fit(UiKit.UI_FONT, _p(detail), int(9.5 * u), tw, int(7 * u))
		draw_string(UiKit.UI_FONT, Vector2(tx, r.position.y + 35 * u), _p(detail), HORIZONTAL_ALIGNMENT_LEFT, tw, dfs, Color(Toon.WASHI, 0.68 * a))


## [pictogramme, couleur] de la pastille de la ligne du bas.
func _info_icon(lit: bool) -> Array:
	if lit:
		return ["check", Toon.VERMILION]
	return [String(TAB_GLYPHS[_tab]), Color(1, 1, 1, 0.1)]


## [titre, détail (une ligne, ou vide), achat ?] ; vide : rien à dire (la ligne ne se dessine pas).
func _banner_info() -> Array:
	if _msg_t > 0.0:
		return [_msg, "", true]
	return []


func _power_name(id: String) -> String:
	if not Data.POWERS.has(id):
		return "aucun"
	var d: Dictionary = Data.POWERS[id]
	return String(d["name"])


# ------------------------------------------------------------------ liste des estampes

func _draw_list() -> void:
	_list_hits.clear()
	if meta == null or _tab == 0:
		return
	var W := _list.size.x
	var u := _u
	if W < 10.0:
		return
	var y := _draw_gallery(-_scroll + 8 * u, W, u)
	_content_h = y + _scroll + 10 * u
	# fondus en haut et en bas quand il reste à faire défiler
	var vh := _list.size.y
	var fade := 16.0 * u
	if _scroll > 1.0:
		_vgrad(_list, Rect2(0, 0, W, fade), Color(BG, 0.95), Color(BG, 0.0))
	if _scroll < _max_scroll() - 1.0:
		_vgrad(_list, Rect2(0, vh - fade, W, fade), Color(BG, 0.0), Color(BG.darkened(0.3), 0.95))
	# ascenseur discret à droite
	if _content_h > vh + 1.0:
		var th := maxf(24.0 * u, vh * vh / _content_h)
		var k := clampf(_scroll / maxf(1.0, _max_scroll()), 0.0, 1.0)
		_panel(_list, Rect2(Vector2(W - 3 * u, (vh - th) * k), Vector2(2.5 * u, th)), Color(Toon.WASHI, 0.25), 1.5 * u)


## Galerie des Vues : apparences portées, puis estampes encadrées sur trois colonnes (selon le filtre).
func _draw_gallery(y0: float, W: float, u: float) -> float:
	var y := y0
	var gap := 8.0 * u
	var cw3 := (W - 8 * u - gap * 2.0) / 3.0
	for k in Meta.LOOK_KINDS.size():
		var kind: String = Meta.LOOK_KINDS[k]
		var r := Rect2(Vector2(4 * u + float(k) * (cw3 + gap), y), Vector2(cw3, 38 * u))
		var on: bool = meta.look_on(kind)
		_panel(_list, r, Color(Toon.SUMI, 0.5), 19 * u, Color(GOLD_HI, 0.5) if on else Color(Toon.WASHI, 0.1), 1.0 * u)
		# pastille agrandie (rayon 15) : l'apparence portée se lit d'un coup d'œil
		var sc := r.position + Vector2(19 * u, r.size.y / 2.0)
		_badge(_list, sc, 15.0 * u, kind, meta.look_color(kind), on, 1.0, u)
		var tx := r.position.x + 39 * u
		var tw := r.end.x - 8 * u - tx
		_list.draw_string(_ui, Vector2(tx, r.position.y + 15 * u), _p(String(KIND_LABELS[kind])), HORIZONTAL_ALIGNMENT_LEFT, tw, int(UiKit.FS_MICRO * u), Color(Toon.WASHI, 0.5))
		var ln := _p(String(meta.look_name(kind)))
		var lfs := _fit(UiKit.UI_FONT, ln, int(UiKit.FS_CAPTION * u), tw, int(7 * u))
		_list.draw_string(UiKit.UI_FONT, Vector2(tx, r.position.y + 28 * u), ln, HORIZONTAL_ALIGNMENT_LEFT, tw, lfs, Color(Toon.WASHI, 0.9 if on else 0.55))
	y += 50 * u
	var pids: Array = []
	var fk := String(FILTER_KINDS[_filter])
	for pid in Meta.PRINT_ORDER:
		var p: Dictionary = Meta.PRINTS[String(pid)]
		if fk == "" or String(p["kind"]) == fk:
			pids.append(String(pid))
	var cols := 3
	var cw := (W - 8 * u - gap * float(cols - 1)) / float(cols)
	var art_h := (cw - 12 * u) * 1.12
	var chh := art_h + 52 * u
	var vh := _list.size.y
	for i in pids.size():
		var r2 := Rect2(Vector2(4 * u + float(i % cols) * (cw + gap), y + float(i / cols) * (chh + gap)), Vector2(cw, chh))
		if r2.end.y >= -10 * u and r2.position.y <= vh + 10 * u:
			_print_card(String(pids[i]), r2, art_h, u)
	var rows := (pids.size() + cols - 1) / cols
	return y + float(rows) * (chh + gap)


## Cadre façon rareté d'une Vue, selon la difficulté de l'exploit.
func _print_tier(p: Dictionary) -> Color:
	match String(p["c"]):
		"mini":
			return C_RARE
		"win":
			return C_EPIC
		"curse", "all":
			return GOLD_HI
		"runs":
			var n := int(p.get("n", 1))
			if n >= 25:
				return C_EPIC
			if n >= 10:
				return C_RARE
	return C_COMMON


## [pictogramme, condition, lieu ou progrès] d'une Vue, en court.
func _cond(p: Dictionary) -> Array:
	var wi := int(p["w"])
	var g := "torii" if String(p["c"]) == "all" else "footsteps"
	if wi >= 1 and wi <= 5:
		g = String(WORLD_GLYPHS[wi - 1])
	var place := "Monde %d" % wi
	match String(p["c"]):
		"room":
			return [g, "Gagner 3 combats", place]
		"mini":
			return [g, "Battre le gardien", place]
		"win":
			return [g, "Gagner le monde", place]
		"curse":
			return [g, "Gagner, 2 malédictions", place]
		"runs":
			var n := int(p.get("n", 1))
			var done := mini(int(meta.runs), n)
			return [g, "Jouer %d parties" % n, "%d / %d" % [done, n]]
	return [g, "Gagner les 5 mondes", "Tous les mondes"]


## Version éteinte d'une Vue (silhouette au lavis) : mêmes formes, couleurs d'encre.
func _ghost(p: Dictionary) -> Dictionary:
	var g := p.duplicate()
	g["sky"] = Color("#3A3540")
	g["fuji"] = Color("#25222B")
	g["ground"] = Color("#2E2A33")
	return g


func _print_card(pid: String, r: Rect2, art_h: float, u: float) -> void:
	var p: Dictionary = Meta.PRINTS[pid]
	var key := "print:" + pid
	var owned: bool = meta.has_print(pid)
	var sel := _sel == key
	var kind := String(p["kind"])
	var col: Color = p["col"]
	var tier := _print_tier(p)
	var rr := r
	if _shake_key == key and _shake > 0.0:
		rr.position.x += sin(_t * 60.0) * 3.0 * u * _shake
	if _pressed == key:
		rr = Rect2(rr.get_center() - rr.size * 0.485, rr.size * 0.97)
	var radius := 10.0 * u
	var art := Rect2(rr.position + Vector2(6, 6) * u, Vector2(rr.size.x - 12 * u, art_h))
	var cx := rr.get_center().x
	if sel:
		_panel(_list, rr.grow(4.0 * u), Color(0, 0, 0, 0), radius + 4.0 * u, GOLD_HI, 3.0 * u)
	if owned:
		if tier == GOLD_HI:
			_panel(_list, rr.grow(3.0 * u), Color(0, 0, 0, 0), radius + 3.0 * u, Color(GOLD_HI, 0.25), 2.0 * u)
		_panel(_list, rr, Toon.ui_paper, radius, tier, 2.0 * u, 0.4, u)
		_art(_list, art, p, u)
		# récompense : pastille de l'apparence, en haut à droite (loin du ruban ÉQUIPÉ, en bas à gauche)
		var sc := art.position + Vector2(art.size.x - (BADGE_R + 3.0) * u, (BADGE_R + 3.0) * u)
		_badge(_list, sc, BADGE_R * u, kind, col, true, 1.0, u)
		if meta.is_worn(pid):
			var efs := int(UiKit.FS_MICRO * u)
			var et := _p("ÉQUIPÉ")
			var ew := _ui.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, efs).x
			var rib := Rect2(Vector2(art.position.x, art.end.y - 16 * u), Vector2(ew + 22 * u, 16 * u))
			_list.draw_rect(rib, Toon.VERMILION)
			UiKit.glyph(_list, "check", rib.position + Vector2(8 * u, 8 * u), 4.0 * u, Toon.WASHI)
			_list.draw_string(_ui, Vector2(rib.position.x + 15 * u, rib.get_center().y + efs * 0.36), et, HORIZONTAL_ALIGNMENT_LEFT, -1, efs, Toon.WASHI)
		var nm := _p(String(p["name"]))
		var nfs := _fit(UiKit.TITLE_FONT, nm, int(10.5 * u), rr.size.x - 10 * u, int(7 * u))
		UiKit.text(_list, UiKit.TITLE_FONT, nm, Vector2(cx, art.end.y + 18 * u), nfs, Toon.ui_ink)
		var ln := _p(String(p["look"]))
		var lfs := _fit(UiKit.UI_FONT, ln, int(8.5 * u), rr.size.x - 32 * u, int(7 * u))
		var lw := UiKit.UI_FONT.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		var lx := cx - (lw + 20 * u) / 2.0
		_look_swatch(_list, Vector2(lx + 7 * u, art.end.y + 32 * u), kind, col, 0.85 * u, true)
		_list.draw_string(UiKit.UI_FONT, Vector2(lx + 20 * u, art.end.y + 32 * u + lfs * 0.36), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(Toon.ui_ink, 0.6))
	else:
		# silhouette au lavis, cadenas, et la condition en court
		_panel(_list, rr, LOCK_BODY, radius, Color(Toon.WASHI, 0.12), 1.5 * u, 0.35, u)
		_art(_list, art, _ghost(p), u)
		_list.draw_rect(art, Color(LOCK_BODY, 0.55))
		var lc := art.get_center()
		_list.draw_circle(lc, 15 * u, Color(Toon.SUMI, 0.85))
		_list.draw_arc(lc, 15 * u, 0.0, TAU, 28, Color(Toon.WASHI, 0.2), 1.0 * u, true)
		UiKit.glyph(_list, "at_lock", lc, 8.0 * u, Color(Toon.WASHI, 0.8), Toon.SUMI)
		var sc2 := art.position + Vector2(art.size.x - (BADGE_R + 3.0) * u, (BADGE_R + 3.0) * u)
		_badge(_list, sc2, BADGE_R * u, kind, col, true, 0.55, u)
		var cd := _cond(p)
		var l1 := _p(String(cd[1]))
		var f1 := _fit(UiKit.UI_FONT, l1, int(8.5 * u), rr.size.x - 10 * u, int(6.5 * u))
		UiKit.text(_list, UiKit.UI_FONT, l1, Vector2(cx, art.end.y + 17 * u), f1, Color(Toon.WASHI, 0.85))
		var l2 := _p(String(cd[2]))
		var f2 := int(8 * u)
		var w2 := UiKit.UI_FONT.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, f2).x
		var x2 := cx - (w2 + 19 * u) / 2.0
		UiKit.glyph(_list, String(cd[0]), Vector2(x2 + 6.5 * u, art.end.y + 31 * u), 6.5 * u, Color(GOLD_HI, 0.8), LOCK_BODY)
		_list.draw_string(UiKit.UI_FONT, Vector2(x2 + 19 * u, art.end.y + 31 * u + f2 * 0.36), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, f2, Color(Toon.WASHI, 0.5))
	if _stamp_key == key and _stamp > 0.0:
		_panel(_list, rr, Color(1, 1, 1, 0.45 * _stamp * _stamp), radius)
		_stamp_fx(_list, art.get_center(), "", u)
	_list_hits.append([_to_screen(r), key])


# ------------------------------------------------------------------ fiche d'une estampe

func _draw_sheet() -> void:
	if not _sheet_on() or meta == null:
		return
	var u := _u
	var pid := _sel.get_slice(":", 1)
	if not Meta.PRINTS.has(pid):
		return
	var p: Dictionary = Meta.PRINTS[pid]
	var owned: bool = meta.has_print(pid)
	var worn: bool = meta.is_worn(pid)
	var kind := String(p["kind"])
	var col: Color = p["col"]
	var tier := _print_tier(p)
	var k := UiKit.ease_out(_sheet_t / 0.25)
	_sheet.draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.72 * k))
	var pr := _sheet_panel
	_panel(_sheet, pr, Toon.ui_paper, UiKit.R_L * u, tier, UiKit.BW_STRONG * u, 0.5, u * 1.5)
	UiKit.fibres(_sheet, pr.grow(-10.0 * u), Toon.ui_ink, 1.0, u, 6.0, 12)
	var cx := pr.get_center().x
	_panel(_sheet, Rect2(Vector2(cx - 18 * u, pr.position.y + 8 * u), Vector2(36 * u, 4 * u)), Color(Toon.ui_ink, 0.15), 2 * u)
	# fermer : bouton rond commun (disque des boutons retour), croix d'encre
	var xc := _sheet_x.get_center()
	var xr := 16.0 * u * (0.94 if _pressed == "sheet:close" else 1.0)
	UiKit.icon_disc(_sheet, xc, xr, Toon.ui_ink, Toon.ui_wash)
	UiKit.glyph(_sheet, "cross", xc, xr * UiKit.ICON_GLYPH, Color(Toon.ui_ink, 0.85))
	# grande estampe
	var art := Rect2(Vector2(pr.position.x + 22 * u, pr.position.y + 46 * u), Vector2(pr.size.x - 44 * u, 168 * u))
	_panel(_sheet, art.grow(6 * u), Toon.WASHI, 6 * u, Color(tier, 0.9), 1.5 * u, 0.25, u)
	if owned:
		_art(_sheet, art, p, u * 1.6)
	else:
		_art(_sheet, art, _ghost(p), u * 1.6)
		_sheet.draw_rect(art, Color(LOCK_BODY, 0.55))
		_sheet.draw_circle(art.get_center(), 26 * u, Color(Toon.SUMI, 0.85))
		UiKit.glyph(_sheet, "at_lock", art.get_center(), 14.0 * u, Color(Toon.WASHI, 0.85), Toon.SUMI)
	if worn:
		var efs := int(9 * u)
		var et := _p("ÉQUIPÉ")
		var ew := _ui.get_string_size(et, HORIZONTAL_ALIGNMENT_LEFT, -1, efs).x
		var rib := Rect2(Vector2(art.position.x, art.end.y - 20 * u), Vector2(ew + 28 * u, 20 * u))
		_sheet.draw_rect(rib, Toon.VERMILION)
		UiKit.glyph(_sheet, "check", rib.position + Vector2(10 * u, 10 * u), 5.0 * u, Toon.WASHI)
		_sheet.draw_string(_ui, Vector2(rib.position.x + 19 * u, rib.get_center().y + efs * 0.36), et, HORIZONTAL_ALIGNMENT_LEFT, -1, efs, Toon.WASHI)
	# numéro, monde, titre
	var n := Meta.PRINT_ORDER.find(pid) + 1
	var wi := int(p["w"])
	var sub := "VUE %d / %d" % [n, Meta.MAX_PRINTS]
	if wi >= 1 and wi <= 5:
		sub += "  ·  MONDE %d, %s" % [wi, String(Meta.WORLD_NAMES[wi - 1]).to_upper()]
	sub = _p(sub)
	var sfs := _fit(_ui, sub, int(UiKit.FS_MICRO * u), pr.size.x - 40 * u, int(7 * u))
	UiKit.text(_sheet, _ui, sub, Vector2(cx, art.end.y + 24 * u), sfs, Color(Toon.ui_ink, 0.5))
	var nm := _p(String(p["name"]))
	var nfs := _fit(UiKit.TITLE_FONT, nm, int(19 * u), pr.size.x - 40 * u, int(12 * u))
	UiKit.text(_sheet, UiKit.TITLE_FONT, nm, Vector2(cx, art.end.y + 46 * u), nfs, Toon.ui_ink)
	# comment l'obtenir
	var hb := Rect2(Vector2(pr.position.x + 20 * u, art.end.y + 58 * u), Vector2(pr.size.x - 40 * u, 46 * u))
	_panel(_sheet, hb, Color(Toon.ui_ink, 0.06), 10 * u)
	var cd := _cond(p)
	var gc := hb.position + Vector2(20 * u, hb.size.y / 2.0)
	_sheet.draw_circle(gc, 13 * u, tier)
	UiKit.glyph(_sheet, String(cd[0]), gc, 7.5 * u, Toon.WASHI, tier)
	var hx := hb.position.x + 40 * u
	var hw := hb.end.x - 8 * u - hx
	_sheet.draw_string(_ui, Vector2(hx, hb.position.y + 14 * u), _p("OBTENUE" if owned else "POUR L'OBTENIR"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(UiKit.FS_MICRO * u), Color(Toon.ui_ink, UiKit.A_CAPTION))
	var how := _p(String(meta.print_how(pid)))
	_sheet.draw_multiline_string(UiKit.UI_FONT, Vector2(hx, hb.position.y + 28 * u), how, HORIZONTAL_ALIGNMENT_LEFT, hw, int(9.5 * u), 2, Toon.ui_ink)
	# récompense
	var rb := Rect2(Vector2(pr.position.x + 20 * u, hb.end.y + 8 * u), Vector2(pr.size.x - 40 * u, 38 * u))
	_panel(_sheet, rb, Color(Toon.ui_ink, 0.06), 10 * u)
	var rc := rb.position + Vector2(20 * u, rb.size.y / 2.0)
	_badge(_sheet, rc, 14.0 * u, kind, col, true, 1.0, u)
	_sheet.draw_string(_ui, Vector2(hx, rb.position.y + 14 * u), _p("RÉCOMPENSE  ·  " + String(KIND_LABELS[kind])), HORIZONTAL_ALIGNMENT_LEFT, -1, int(UiKit.FS_MICRO * u), Color(Toon.ui_ink, UiKit.A_CAPTION))
	_sheet.draw_string(UiKit.TITLE_FONT, Vector2(hx, rb.position.y + 30 * u), _p(String(p["look"])), HORIZONTAL_ALIGNMENT_LEFT, hw, int(12 * u), Toon.ui_ink)
	# ÉQUIPER / RETIRER / verrouillée
	var br := _sheet_btn
	if _shake_key == _sel and _shake > 0.0:
		br.position.x += sin(_t * 60.0) * 4.0 * u * _shake
	if _pressed == _sel:
		br = Rect2(br.get_center() - br.size * 0.485, br.size * 0.97)
	if not owned:
		_button(_sheet, br, "lack", "", "at_lock", "", u, 1.0)
	elif worn:
		_button(_sheet, br, "owned", "", "cross", "", u, 1.0)
	else:
		_button(_sheet, br, "buy", "", "check", "", u, 1.0)


## Pastille ronde d'une apparence : fond de papier, liseré d'encre, pictogramme à l'échelle du rayon.
## `a` < 1 : version éteinte (Vue verrouillée).
func _badge(ci: CanvasItem, c: Vector2, rad: float, kind: String, col: Color, on: bool, a: float, u: float) -> void:
	var lit := a >= 1.0
	ci.draw_circle(c + Vector2(0, 1.5 * u), rad, Color(0, 0, 0, 0.3 * a))
	ci.draw_circle(c, rad, Color(Toon.WASHI, 0.95) if lit else Color(Toon.WASHI, 0.22))
	ci.draw_arc(c, rad - 0.6 * u, 0.0, TAU, 32, Color(Toon.SUMI, 0.45 * a), maxf(1.0, 1.2 * u), true)
	# le pictogramme (±8,5 unités) occupe ~65 % du rayon
	_look_swatch(ci, c, kind, Color(col, col.a * (1.0 if lit else 0.75)), rad * 0.075, on)


## Échantillon d'apparence : écharpe (bande et pan qui retombe), sillage (ruban effilé), encre (goutte).
## Tient dans un carré de ±8,5 unités multipliées par `s`.
func _look_swatch(ci: CanvasItem, c: Vector2, kind: String, col: Color, s: float, on: bool) -> void:
	var edge := Color(Toon.SUMI, 0.85 * col.a)
	var lw := maxf(1.0, 1.1 * s)
	match kind:
		"cape":
			var band := PackedVector2Array([c + Vector2(-8, -5) * s, c + Vector2(0, -6) * s, c + Vector2(8, -5) * s,
				c + Vector2(7, 0) * s, c + Vector2(0, -1) * s, c + Vector2(-7, 0) * s])
			var tail := PackedVector2Array([c + Vector2(1.5, -1.2) * s, c + Vector2(5.5, -0.6) * s,
				c + Vector2(7.5, 7.5) * s, c + Vector2(3, 6) * s])
			ci.draw_colored_polygon(tail, col.darkened(0.15))
			ci.draw_colored_polygon(band, col)
			var ot := tail.duplicate()
			ot.append(tail[0])
			ci.draw_polyline(ot, edge, lw, true)
			var ob := band.duplicate()
			ob.append(band[0])
			ci.draw_polyline(ob, edge, lw, true)
			# pli de l'étoffe
			ci.draw_line(c + Vector2(-5.5, -2.8) * s, c + Vector2(5.5, -2.8) * s, Color(Toon.SUMI, 0.3 * col.a), maxf(1.0, 0.9 * s), true)
		"trail":
			var pts := PackedVector2Array()
			for i in 7:
				var t := float(i) / 6.0
				pts.append(c + Vector2(-8.0 + 16.0 * t, 4.5 - 9.0 * t + 2.2 * sin(PI * t)) * s)
			if on:
				ci.draw_polyline(pts, Color(Toon.SUMI, 0.8 * col.a), 5.2 * s, true)
				ci.draw_polyline(pts, col, 3.2 * s, true)
				ci.draw_circle(pts[pts.size() - 1], 1.6 * s, col)
				# reflet du ruban
				ci.draw_line(pts[1], pts[3], Color(1, 1, 1, 0.45 * col.a), maxf(1.0, 0.9 * s), true)
			else:
				# aucun sillage porté
				ci.draw_polyline(pts, Color(Toon.SUMI, 0.35), maxf(1.0, 1.6 * s), true)
		_:
			# goutte d'encre : panse ronde, pointe, liseré et reflet
			var drop := PackedVector2Array()
			for i in 17:
				var ang := PI * (-0.18 + 1.36 * float(i) / 16.0)
				drop.append(c + Vector2(cos(ang), sin(ang)) * 5.4 * s + Vector2(0, 2) * s)
			drop.append(c + Vector2(0, -8) * s)
			ci.draw_colored_polygon(drop, col)
			var od := drop.duplicate()
			od.append(drop[0])
			ci.draw_polyline(od, edge, lw, true)
			ci.draw_circle(c + Vector2(-2, 2.6) * s, 1.3 * s, Color(1, 1, 1, 0.5 * col.a))


func _pt(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(r.size.x * x, r.size.y * y)


## Petite estampe façon Hokusai : ciel en bokashi, Fuji enneigé, sol ou mer, motif du premier plan.
func _art(ci: CanvasItem, r: Rect2, p: Dictionary, u: float) -> void:
	var sky: Color = p["sky"]
	var fuji: Color = p["fuji"]
	var ground: Color = p["ground"]
	var motif := String(p["motif"])
	var fx := float(p["fx"])
	var x0 := r.position.x
	var y0 := r.position.y
	var rw := r.size.x
	var rh := r.size.y
	var xe := r.end.x
	var hz := y0 + rh * 0.64
	# ciel : bleu de Prusse en haut qui se fond vers l'horizon (bokashi)
	var top := sky.lerp(Toon.PRUSSIAN, 0.35)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(xe, y0), Vector2(xe, hz), Vector2(x0, hz)]),
		PackedColorArray([top, top, sky, sky]))
	# le Fuji, coupé proprement par le cadre
	var cx := x0 + rw * fx
	var peak := hz - rh * 0.38
	var bw := rw * 0.5
	var tw := rw * 0.06
	var pts := PackedVector2Array()
	var lx := cx - bw
	if lx < x0:
		pts.append(Vector2(x0, hz))
		pts.append(Vector2(x0, hz - (hz - peak) * (x0 - lx) / (bw - tw)))
	else:
		pts.append(Vector2(lx, hz))
	pts.append(Vector2(cx - tw, peak))
	pts.append(Vector2(cx + tw, peak))
	var rx := cx + bw
	if rx > xe:
		pts.append(Vector2(xe, hz - (hz - peak) * (rx - xe) / (bw - tw)))
		pts.append(Vector2(xe, hz))
	else:
		pts.append(Vector2(rx, hz))
	ci.draw_colored_polygon(pts, fuji)
	# neige du sommet, bord dentelé
	var sd := (hz - peak) * 0.3
	var sx := tw + (bw - tw) * 0.3
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - tw, peak), Vector2(cx + tw, peak), Vector2(cx + sx, peak + sd),
		Vector2(cx + sx * 0.45, peak + sd * 0.7), Vector2(cx + sx * 0.1, peak + sd * 1.05), Vector2(cx - sx * 0.35, peak + sd * 0.65),
		Vector2(cx - sx, peak + sd)]), Toon.WASHI)
	# sol ou mer
	ci.draw_rect(Rect2(Vector2(x0, hz), Vector2(rw, r.end.y - hz)), ground)
	ci.draw_line(Vector2(x0, hz), Vector2(xe, hz), Color(Toon.SUMI, 0.3), 1.0 * u)
	match motif:
		"wave":
			var crest := [[0.0, 0.5], [0.14, 0.4], [0.3, 0.38], [0.44, 0.46]]
			var wp := PackedVector2Array([_pt(r, 0.0, 1.0)])
			for cp in crest:
				wp.append(_pt(r, float(cp[0]), float(cp[1])))
			wp.append(_pt(r, 0.36, 0.47))
			wp.append(_pt(r, 0.42, 0.6))
			wp.append(_pt(r, 0.62, 0.74))
			wp.append(_pt(r, 1.0, 0.78))
			wp.append(_pt(r, 1.0, 1.0))
			ci.draw_colored_polygon(wp, Color("#1F3A5F"))
			var line := PackedVector2Array()
			for cp in crest:
				var q := _pt(r, float(cp[0]), float(cp[1]))
				line.append(q)
				ci.draw_circle(q, 1.8 * u, Toon.WASHI)
			ci.draw_polyline(line, Color(Toon.WASHI, 0.9), 1.4 * u, true)
		"boat":
			ci.draw_colored_polygon(PackedVector2Array([_pt(r, 0.12, 0.8), _pt(r, 0.88, 0.76), _pt(r, 0.76, 0.86), _pt(r, 0.24, 0.88)]), Color("#4A3A2E"))
			for k in 4:
				var bx := 0.28 + 0.13 * k
				ci.draw_line(_pt(r, bx, 0.8), _pt(r, bx + 0.02, 0.72), Toon.SUMI, 1.2 * u)
				ci.draw_circle(_pt(r, bx + 0.02, 0.71), 1.5 * u, Toon.SKIN)
			ci.draw_arc(_pt(r, 0.2, 0.97), rw * 0.12, PI, TAU, 8, Toon.WASHI, 1.0 * u)
			ci.draw_arc(_pt(r, 0.75, 0.97), rw * 0.12, PI, TAU, 8, Toon.WASHI, 1.0 * u)
		"pine":
			ci.draw_line(_pt(r, 0.18, 1.0), _pt(r, 0.24, 0.42), Color("#4A3426"), 2.5 * u)
			for b in [[0.24, 0.42, 0.11], [0.13, 0.52, 0.08], [0.33, 0.56, 0.08]]:
				ci.draw_circle(_pt(r, float(b[0]), float(b[1])), rw * float(b[2]), Color("#2E4A2C"))
		"bamboo":
			for bx in [0.08, 0.18, 0.84, 0.93]:
				var fb := float(bx)
				ci.draw_line(_pt(r, fb, 1.0), _pt(r, fb, 0.0), Color("#3E5A2E"), 2.5 * u)
				for k in 6:
					var ny := 0.12 + 0.16 * k
					ci.draw_line(_pt(r, fb - 0.025, ny), _pt(r, fb + 0.025, ny), Color("#24361C"), 1.0 * u)
			ci.draw_line(_pt(r, 0.18, 0.3), _pt(r, 0.3, 0.26), Color("#3E5A2E"), 1.5 * u)
			ci.draw_line(_pt(r, 0.84, 0.4), _pt(r, 0.72, 0.36), Color("#3E5A2E"), 1.5 * u)
		"fox":
			for f in [[0.2, 0.78], [0.38, 0.84], [0.58, 0.8], [0.76, 0.88], [0.88, 0.76]]:
				var q := _pt(r, float(f[0]), float(f[1]))
				ci.draw_circle(q, 4.5 * u, Color(Color("#FFB15A"), 0.25))
				ci.draw_circle(q, 2.0 * u, Color("#FFD27A"))
		"moon":
			ci.draw_circle(_pt(r, 0.8, 0.16), rw * 0.08, Color("#F2E6C0"))
			for st in [[0.15, 0.12], [0.3, 0.22], [0.55, 0.08], [0.65, 0.3], [0.92, 0.36]]:
				ci.draw_circle(_pt(r, float(st[0]), float(st[1])), 0.9 * u, Color("#F2E6C0"))
			# bambou de Tanabata et ses vœux de papier
			ci.draw_line(_pt(r, 0.12, 1.0), _pt(r, 0.16, 0.28), Color("#5E7F4A"), 2.0 * u)
			var wish := [Toon.VERMILION, Toon.GOLD, Color("#3D78B8"), Color("#E59AAE")]
			for k in 4:
				var q := _pt(r, 0.15 + 0.04 * (k % 2), 0.36 + 0.1 * k)
				ci.draw_rect(Rect2(q, Vector2(3, 7) * u), wish[k])
		"snow":
			ci.draw_colored_polygon(PackedVector2Array([_pt(r, 0.0, 0.78), _pt(r, 0.3, 0.7), _pt(r, 0.46, 0.84), _pt(r, 0.0, 0.88)]), Color("#3A3A48"))
			ci.draw_line(_pt(r, 0.0, 0.78), _pt(r, 0.3, 0.7), Toon.WASHI, 2.0 * u)
			for k in 14:
				var sfx := fposmod(sin(float(k) * 12.9898) * 43758.5453, 1.0)
				var sfy := fposmod(sin(float(k) * 78.233) * 12543.123, 1.0)
				ci.draw_circle(_pt(r, sfx, sfy * 0.95), 1.0 * u, Color(Toon.WASHI, 0.9))
		"bridge":
			var bc := Vector2(x0 + rw * 0.5, y0 + rh * 1.25)
			ci.draw_arc(bc, rw * 0.6, PI * 1.2, PI * 1.8, 18, Color("#6B4A2E"), 4.0 * u)
			ci.draw_arc(bc, rw * 0.6 + 2.0 * u, PI * 1.2, PI * 1.8, 18, Toon.WASHI, 1.2 * u)
		"sun":
			ci.draw_circle(_pt(r, 0.8, 0.18), rw * 0.08, Toon.VERMILION)
			ci.draw_line(_pt(r, 0.05, 0.42), _pt(r, 0.4, 0.42), Color(Toon.WASHI, 0.8), 3.0 * u)
			ci.draw_line(_pt(r, 0.55, 0.5), _pt(r, 0.95, 0.5), Color(Toon.WASHI, 0.7), 2.0 * u)
		"storm":
			ci.draw_rect(Rect2(Vector2(x0, hz - rh * 0.12), Vector2(rw, rh * 0.12)), Color(Toon.SUMI, 0.35))
			ci.draw_polyline(PackedVector2Array([_pt(r, fx - 0.08, 0.5), _pt(r, fx - 0.02, 0.57), _pt(r, fx - 0.06, 0.6), _pt(r, fx + 0.02, 0.68)]), Toon.GOLD, 1.6 * u, true)
		"cloud":
			for cl in [[0.06, 0.32, 0.42], [0.52, 0.46, 0.9], [0.2, 0.52, 0.5]]:
				ci.draw_line(_pt(r, float(cl[0]), float(cl[1])), _pt(r, float(cl[2]), float(cl[1])), Color(Toon.WASHI, 0.85), 3.0 * u)
		"lake":
			var lcx := x0 + rw * fx
			ci.draw_colored_polygon(PackedVector2Array([Vector2(maxf(x0, lcx - rw * 0.4), hz), Vector2(minf(xe, lcx + rw * 0.4), hz), Vector2(lcx, hz + rh * 0.3)]), Color(fuji, 0.35))
			ci.draw_line(_pt(r, 0.15, 0.9), _pt(r, 0.3, 0.9), Toon.SUMI, 2.0 * u)
		"barrel":
			var oc := Vector2(x0 + rw * fx, hz - rh * 0.12)
			ci.draw_arc(oc, rw * 0.36, 0.0, TAU, 32, Color("#8A6A3E"), 3.5 * u)
			ci.draw_arc(oc, rw * 0.36 - 2.5 * u, 0.0, TAU, 32, Color("#5A4232"), 1.0 * u)
			ci.draw_line(_pt(r, 0.2, 0.92), _pt(r, 0.22, 0.84), Toon.SUMI, 1.5 * u)
			ci.draw_circle(_pt(r, 0.22, 0.83), 1.5 * u, Toon.SKIN)
		"enso":
			ci.draw_arc(_pt(r, 0.5, 0.42), rw * 0.32, -PI * 0.3, PI * 1.55, 32, Color(Toon.SUMI, 0.85), 3.0 * u, true)
		"lantern":
			for lp in [[0.22, 0.5], [0.78, 0.42]]:
				var q := _pt(r, float(lp[0]), float(lp[1]))
				ci.draw_circle(q, 7.0 * u, Color(Color("#FFD27A"), 0.25))
				ci.draw_rect(Rect2(q - Vector2(3, 5) * u, Vector2(6, 10) * u), Color("#E8C27A"))
				ci.draw_line(q - Vector2(0, 5) * u, q - Vector2(0, 9) * u, Toon.SUMI, 1.0 * u)
		"pilgrim":
			ci.draw_line(_pt(r, 0.0, 0.86), _pt(r, 1.0, 0.8), Color("#A8975F"), 3.0 * u)
			for k in 3:
				var q := _pt(r, 0.25 + 0.2 * k, 0.8 - 0.012 * k)
				ci.draw_line(q, q - Vector2(0, 8) * u, Toon.SUMI, 1.5 * u)
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(-4, -8) * u, q + Vector2(4, -8) * u, q + Vector2(0, -12) * u]), Color("#C9B48A"))
		"brush":
			ci.draw_line(_pt(r, 0.12, 0.86), _pt(r, 0.8, 0.7), Color(Toon.SUMI, 0.9), 5.0 * u)
			ci.draw_line(_pt(r, 0.8, 0.7), _pt(r, 0.9, 0.68), Color(Toon.SUMI, 0.9), 2.0 * u)
			ci.draw_rect(Rect2(_pt(r, 0.76, 0.82), Vector2(7, 7) * u), Toon.VERMILION)
		"rain":
			for k in 12:
				var rx0 := float(k) / 12.0
				ci.draw_line(_pt(r, rx0, 0.05), _pt(r, minf(1.0, rx0 + 0.12), 0.6), Color(Toon.SUMI, 0.25), 1.0 * u)
	# cartouche du titre (bande jaune verticale) et filet du cadre
	var cart := Rect2(r.position + Vector2(3, 3) * u, Vector2(5, 16) * u)
	ci.draw_rect(cart, Color("#E8D9A8"))
	ci.draw_rect(cart, Color(Toon.SUMI, 0.7), false, 0.8 * u)
	ci.draw_rect(r, Color(Toon.SUMI, 0.6), false, 1.0 * u)
