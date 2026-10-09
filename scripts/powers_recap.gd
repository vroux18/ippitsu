extends Control
## Récapitulatif « POUVOIRS » (depuis la pause), UI v2 (planche MesPouvoirs) : écran de papier plein, bouton retour
## d'encre, grille de tuiles (médaillon : disque washi cerné de la couleur d'élément, glyphe sumi ; nom ; étiquette
## d'élément picto + NOM ; crans de niveau ; la rareté se lit à la bordure seule). Un toucher lève la tuile et ouvre
## sa bulle d'encre (nom japonais, déclencheur en pictogrammes, phrase, tickets d'effet). Dessous, HARMONIES : une tuile
## par école à anneau (4 arcs, paliers 2 et 4 en losanges) ; une bulle donne leurs bonus. Le contenu glisse au doigt
## (ou à la molette). Marche jeu figé : tout est compté en temps réel (UiKit.real_delta). main : open(powers), signal closed.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
const Data = preload("res://scripts/power_data.gd")

signal closed

const INPUT_DELAY := 0.3  # le toucher qui a ouvert la carte ne doit rien faire
const NO_TARGET := -2
const BACK_TARGET := -1
const SCHOOL_BASE := 1000  # cible « tuile d'école k » = SCHOOL_BASE + k (les tuiles de pouvoir : leur index)
const DRAG_START := 8.0  # glissé minimal (× u) avant de faire défiler
const OPEN_DUR := 0.18  # ouverture de la bulle (s)
const GOLD_INK := Color("#9A6B12")  # or lisible sur le papier
const GOLD_HI := Color("#E2A93B")
const BUB_BODY := Color("#1B1A1E")  # bulle d'encre (sumi)
const TILE_H := 112.0  # tuile de pouvoir (× u)
const SCHOOL_H := 82.0  # tuile d'harmonie (× u)
const GLUE := [":", ";", "!", "?", "%", "→", "·"]  # jamais en début de ligne

var _powers = null  # nœud des pouvoirs (powers.gd)
var _t := 0.0
var _u := 1.0
var _pressed := NO_TARGET
var _holding := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _press_scroll := 0.0
var _drag_accum := 0.0
var _scroll := 0.0
var _vel := 0.0
var _content_h := 0.0
var _back := Rect2()
var _card := Rect2()  # l'écran entier (papier plein)
var _view := Rect2()  # zone qui défile (coordonnées de l'écran)
var _head_y := 0.0  # centre vertical de l'en-tête (bouton retour, titre)
var _infos: Array = []  # pouvoirs possédés (recap_info), rangés par école puis par rareté
var _schools: Array = []  # écoles à bonus : {"school", "st"}
var _count := 0
var _rakkan := false
var _sel := NO_TARGET  # tuile ou école ouverte
var _shown := NO_TARGET  # cible montrée dans la bulle (reste le temps de la fermeture)
var _open_k := 0.0  # ouverture de la bulle, 0..1
var _ensure := false  # faire défiler pour montrer la bulle
# mise en page, en coordonnées du contenu (avant défilement)
var _cols := 3
var _tile_rects: Array = []
var _empty_h := 0.0
var _sec_y := 0.0
var _school_rects: Array = []
var _bub := Rect2()
var _bub_tip := 0.0
var _bub_row_top := 0.0
var _list: Control
var _ui := FontVariation.new()
var _title := FontVariation.new()
var _caps := FontVariation.new()  # nom japonais de la bulle : Shippori espacée (2 u)
var _sec_font := FontVariation.new()  # titre HARMONIES : Shippori espacée (4 u)
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = UiKit.CAPS_SPACING
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = UiKit.TITLE_SPACING
	_caps.base_font = UiKit.TITLE_FONT
	_caps.spacing_glyph = 2
	_sec_font.base_font = UiKit.TITLE_FONT
	_sec_font.spacing_glyph = 4
	# le contenu se dessine dans un enfant qui découpe ce qui dépasse
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.clip_contents = true
	add_child(_list)
	_list.draw.connect(_draw_list)


func open(powers_node) -> void:
	_powers = powers_node
	_t = 0.0
	_pressed = NO_TARGET
	_holding = false
	_dragging = false
	_drag_accum = 0.0
	_scroll = 0.0
	_vel = 0.0
	_content_h = 0.0
	_sel = NO_TARGET
	_shown = NO_TARGET
	_open_k = 0.0
	_ensure = false
	_build()
	visible = true
	size = get_viewport_rect().size
	_layout()
	_layout_list()


func _close() -> void:
	visible = false
	_holding = false
	_dragging = false
	closed.emit()


# ------------------------------------------------------------------ données

func _build() -> void:
	_infos.clear()
	_schools.clear()
	var owned: Array = []
	if _powers != null:
		var lv: Dictionary = _powers.levels
		for id in lv.keys():
			if int(lv[id]) > 0 and Data.POWERS.has(String(id)):
				owned.append(String(id))
	_count = owned.size()
	for school in Data.SCHOOL_ORDER:
		var ids: Array = []
		for id in owned:
			var d: Dictionary = Data.POWERS[id]
			if String(d["school"]) == String(school):
				ids.append(id)
		ids.sort_custom(_by_rarity)
		for id in ids:
			_infos.append(_powers.recap_info(String(id)))
	_rakkan = _powers != null and int(_powers.lvl("ink_rakkan")) > 0
	for school in Data.SCHOOL_ORDER:
		if not Data.AFFINITY.has(String(school)):
			continue
		var st: Dictionary = {}
		if _powers != null:
			st = _powers.school_status(String(school))
		_schools.append({"school": String(school), "st": st})


## Tri dans une école : légendaires d'abord, puis épiques, rares, communs.
func _by_rarity(a, b) -> bool:
	var da: Dictionary = Data.POWERS[String(a)]
	var db: Dictionary = Data.POWERS[String(b)]
	var ra := int(Data.RARITIES[String(da["rarity"])]["rank"])
	var rb := int(Data.RARITIES[String(db["rarity"])]["rank"])
	if ra != rb:
		return ra > rb
	return String(da["name"]) < String(db["name"])


func _p(s: String) -> String:
	return UiKit.plain(s)


# ------------------------------------------------------------------ entrée

func _target_at(p: Vector2) -> int:
	if _back.has_point(p):
		return BACK_TARGET
	if not _view.has_point(p):
		return NO_TARGET
	var lp := p - _view.position + Vector2(0.0, _scroll)
	# la bulle passe devant (toucher la bulle la referme)
	if _shown != NO_TARGET and _bub.size.y > 0.0 and _bub.grow(4.0 * _u).has_point(lp):
		return NO_TARGET
	for i in _tile_rects.size():
		var r: Rect2 = _tile_rects[i]
		if r.has_point(lp):
			return i
	for k in _school_rects.size():
		var sr: Rect2 = _school_rects[k]
		if sr.grow(3.0 * _u).has_point(lp):
			return SCHOOL_BASE + k
	return NO_TARGET


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		accept_event()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed and _t >= INPUT_DELAY:
				var dir: float = -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				_scroll = clampf(_scroll + dir * 60.0 * _u, 0.0, _max_scroll())
				_vel = 0.0
				_ensure = false
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if _t < INPUT_DELAY:
			_pressed = NO_TARGET
			_holding = false
			_dragging = false
			return
		if mb.pressed:
			_pressed = _target_at(mb.position)
			_holding = true
			_dragging = false
			_press_pos = mb.position
			_press_scroll = _scroll
			_drag_accum = 0.0
			_vel = 0.0
			return
		# relâché : on n'agit que si l'appui et le relâché tombent sur la même cible (et sans glissé)
		var start := _pressed
		var was_hold := _holding
		var was_drag := _dragging
		_pressed = NO_TARGET
		_holding = false
		_dragging = false
		if was_drag or not was_hold:
			return
		var target := _target_at(mb.position)
		if target != start:
			return
		if target == BACK_TARGET:
			_close()
		elif target == NO_TARGET:
			_sel = NO_TARGET
		else:
			_select(target)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _holding or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		accept_event()
		if not _dragging and absf(mm.position.y - _press_pos.y) > DRAG_START * _u:
			_dragging = true
			_ensure = false
			_pressed = NO_TARGET  # un glissé n'appuie sur rien
			_press_pos = mm.position
			_press_scroll = _scroll
		if _dragging:
			_scroll = _rubber(_press_scroll - (mm.position.y - _press_pos.y))
			_drag_accum += mm.relative.y


## Toucher une tuile (ou une école) : sa bulle s'ouvre ; la toucher encore la referme.
func _select(key: int) -> void:
	if key == _sel:
		_sel = NO_TARGET
		return
	# la bulle change de rangée : elle se rouvre depuis zéro
	if _shown != NO_TARGET and _group(key) != _group(_shown):
		_open_k = 0.0
	_sel = key
	_shown = key
	_ensure = true


func _group(key: int) -> int:
	if key >= SCHOOL_BASE:
		return -100
	return floori(float(key) / float(maxi(_cols, 1)))


func _max_scroll() -> float:
	return maxf(0.0, _content_h - _view.size.y)


## Au-delà des bords, le papier résiste (élastique).
func _rubber(raw: float) -> float:
	var hi := _max_scroll()
	if raw < 0.0:
		return raw * 0.35
	if raw > hi:
		return hi + (raw - hi) * 0.35
	return raw


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	var goal: float = 1.0 if _sel != NO_TARGET else 0.0
	_open_k = move_toward(_open_k, goal, real / OPEN_DUR)
	if _sel == NO_TARGET and _open_k <= 0.0:
		_shown = NO_TARGET
	_layout()
	_layout_list()
	var hi := _max_scroll()
	if _dragging:
		if real > 0.0:
			_vel = lerpf(_vel, -_drag_accum / real, 0.35)
		_drag_accum = 0.0
	else:
		_drag_accum = 0.0
		# lancé : le contenu continue sur son élan puis freine ; il revient en place s'il dépasse
		if absf(_vel) > 2.0:
			_scroll += _vel * real
			_vel *= exp(-4.0 * real)
		else:
			_vel = 0.0
		if _scroll < 0.0 or _scroll > hi:
			_vel *= exp(-18.0 * real)
			_scroll = lerpf(_scroll, clampf(_scroll, 0.0, hi), 1.0 - exp(-14.0 * real))
	# la bulle qui s'ouvre reste visible (défilement doux)
	if _ensure and not _dragging and _shown != NO_TARGET:
		var want := _scroll
		var bottom := _bub.end.y + 8.0 * _u
		if bottom - want > _view.size.y:
			want = bottom - _view.size.y
		if _bub_row_top - 6.0 * _u < want:
			want = _bub_row_top - 6.0 * _u
		want = clampf(want, 0.0, hi)
		_scroll = lerpf(_scroll, want, 1.0 - exp(-12.0 * real))
		_vel = 0.0
		if _open_k >= 1.0 and absf(_scroll - want) < 0.5:
			_ensure = false
	elif _shown == NO_TARGET:
		_ensure = false
	queue_redraw()
	_list.queue_redraw()


# ------------------------------------------------------------------ mise en page

## Écran plein (qui glisse un peu à l'ouverture) : bouton retour et titre sous l'encoche, zone qui défile dessous.
func _layout() -> void:
	var w := size.x
	var h := size.y
	_u = minf(w / 400.0, h / 760.0)
	var u := _u
	var ins := UiKit.safe_insets(size)
	var slide := 14.0 * u * (1.0 - UiKit.ease_out(_t / 0.3))
	_card = Rect2(Vector2.ZERO, size)
	_head_y = ins.x + 58.0 * u + slide
	_back = UiKit.back_rect(Vector2(36.0 * u, _head_y), u)
	var top := ins.x + 100.0 * u + slide
	_view = Rect2(Vector2(14.0 * u, top), Vector2(w - 28.0 * u, maxf(40.0 * u, h - ins.y - 8.0 * u - top)))
	_list.position = _view.position
	_list.size = _view.size
	_list.modulate.a = clampf(_t / 0.25, 0.0, 1.0)


## Grille des tuiles, bulle insérée sous la rangée touchée, HARMONIES (coordonnées du contenu).
func _layout_list() -> void:
	var u := _u
	var W := _view.size.x
	_cols = clampi(int(W / (110.0 * u)), 3, 6)
	var gap := 10.0 * u
	var tw := (W - gap * float(_cols - 1)) / float(_cols)
	var th := TILE_H * u
	var bw := W - 4.0 * u
	var bk := UiKit.ease_out(_open_k)
	var bub_h := 0.0
	if _shown != NO_TARGET:
		bub_h = _bubble(_shown, Vector2.ZERO, bw, false, 1.0)
	_bub = Rect2()
	_tile_rects.clear()
	var y := 8.0 * u  # place pour la tuile levée
	_empty_h = 0.0
	var n := _infos.size()
	if n == 0:
		_empty_h = 176.0 * u
		y += _empty_h
	var rows := ceili(float(n) / float(_cols))
	for row in rows:
		var first: int = row * _cols
		var in_row := mini(_cols, n - first)
		# rangée incomplète : alignée à gauche, comme la grille de la planche
		for c in in_row:
			_tile_rects.append(Rect2(Vector2(float(c) * (tw + gap), y), Vector2(tw, th)))
		y += th
		if _shown != NO_TARGET and _shown < SCHOOL_BASE and _shown >= first and _shown < first + in_row:
			var tr: Rect2 = _tile_rects[_shown]
			_bub_row_top = tr.position.y
			_bub_tip = tr.get_center().x
			_bub = Rect2(Vector2(2.0 * u, y + 14.0 * u), Vector2(bw, bub_h))
			y += (bub_h + 22.0 * u) * bk
		y += gap
	# HARMONIES : titre, puis une rangée de tuiles d'école
	y += 14.0 * u
	_sec_y = y
	y += 30.0 * u
	var ns := _schools.size()
	var sgap := 6.0 * u
	var sw := (W - sgap * float(maxi(ns, 1) - 1)) / float(maxi(ns, 1))
	_school_rects.clear()
	for k in ns:
		_school_rects.append(Rect2(Vector2(float(k) * (sw + sgap), y), Vector2(sw, SCHOOL_H * u)))
	y += SCHOOL_H * u + 10.0 * u
	if _shown >= SCHOOL_BASE and _shown - SCHOOL_BASE < ns:
		var sr: Rect2 = _school_rects[_shown - SCHOOL_BASE]
		_bub_row_top = sr.position.y - 12.0 * u
		_bub_tip = sr.get_center().x
		_bub = Rect2(Vector2(2.0 * u, y + 4.0 * u), Vector2(bw, bub_h))
		y += (bub_h + 12.0 * u) * bk
	_content_h = y + 12.0 * u


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	if size.x < 10.0:
		return
	var u := _u
	var a := clampf(_t / 0.25, 0.0, 1.0)
	# papier plein (planche MesPouvoirs : écran entier, pas de voile)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.ui_paper, a))
	# titre souligné de vermillon, centré sur la ligne du bouton retour
	var tmax: float = size.x - 2.0 * 80.0 * u
	UiKit.screen_title(self, _title, "POUVOIRS", Vector2(size.x / 2.0, _head_y + 8.0 * u), u, Toon.ui_ink, a, "", tmax,
		UiKit.ease_out(clampf((_t - 0.1) / 0.4, 0.0, 1.0)))
	# retour : disque d'encre, chevron de papier
	var bc := _back.get_center()
	var br := 22.0 * u * (0.94 if _pressed == BACK_TARGET else 1.0)
	draw_circle(bc, br, Color(UIColors.SUMI, a))
	UiKit.draw_path(self, "M20 6 L10 16 L20 26", 32, bc, 20.0 * u, UIColors.WASHI, 3.2, UiKit.NONE, a)


func _draw_list() -> void:
	var W := _list.size.x
	var u := _u
	if W < 10.0:
		return
	var oy := -_scroll
	var bk := UiKit.ease_out(_open_k)
	if _infos.is_empty():
		_draw_empty(W, 6.0 * u + oy, u)
	# tuiles (les autres s'effacent un peu quand une tuile est ouverte)
	var tile_open := _sel != NO_TARGET and _sel < SCHOOL_BASE
	for i in _tile_rects.size():
		var r: Rect2 = _tile_rects[i]
		if r.end.y + oy < -20.0 * u or r.position.y + oy > _list.size.y + 20.0 * u:
			continue
		var a: float = lerpf(1.0, 0.6, bk) if tile_open and i != _sel else 1.0
		_draw_tile(i, Rect2(r.position + Vector2(0.0, oy), r.size), u, a)
	# HARMONIES : titre (Shippori espacée) et filet jusqu'au bord
	var sy := _sec_y + oy
	var hsp := maxi(1, int(4.0 * u))
	if _sec_font.spacing_glyph != hsp:
		_sec_font.spacing_glyph = hsp
	var hfs := int(13 * u)
	var hw := _sec_font.get_string_size("HARMONIES", HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x
	_list.draw_string(_sec_font, Vector2(0.0, sy + 16.0 * u), "HARMONIES", HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Toon.ui_ink)
	_list.draw_line(Vector2(hw + 6.0 * u, sy + 11.0 * u), Vector2(W, sy + 11.0 * u), Color(Toon.ui_ink, 0.25), maxf(1.0, 1.5 * u))
	for k in _school_rects.size():
		var sr: Rect2 = _school_rects[k]
		_draw_school(k, Rect2(sr.position + Vector2(0.0, oy), sr.size), u)
	# bulle de détail, devant le reste
	if _shown != NO_TARGET and _bub.size.y > 0.0 and bk > 0.01:
		var box := Rect2(_bub.position + Vector2(0.0, oy - 6.0 * u * (1.0 - bk)), _bub.size)
		var tipx := clampf(_bub_tip, box.position.x + 22.0 * u, box.end.x - 22.0 * u)
		_list.draw_colored_polygon(PackedVector2Array([Vector2(tipx, box.position.y - 9.0 * u), Vector2(tipx + 10.0 * u, box.position.y + 1.0),
			Vector2(tipx - 10.0 * u, box.position.y + 1.0)]), Color(BUB_BODY, bk))
		_list.draw_style_box(UiKit.box(_sb, Color(BUB_BODY, bk), int(12 * u)), box)
		_bubble(_shown, box.position, box.size.x, true, bk)
	# fondus du papier en haut et en bas quand il reste à faire défiler
	var vh := _list.size.y
	var fade := 16.0 * u
	var paper: Color = Toon.ui_paper
	if _scroll > 1.0:
		_list.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, fade), Vector2(0, fade)]),
			PackedColorArray([paper, paper, Color(paper, 0.0), Color(paper, 0.0)]))
	if _scroll < _max_scroll() - 1.0:
		_list.draw_polygon(PackedVector2Array([Vector2(0, vh - fade), Vector2(W, vh - fade), Vector2(W, vh), Vector2(0, vh)]),
			PackedColorArray([Color(paper, 0.0), Color(paper, 0.0), paper, paper]))
	# ascenseur discret à droite
	if _content_h > vh + 1.0:
		var th := maxf(24.0 * u, vh * vh / _content_h)
		var ks := clampf(_scroll / maxf(1.0, _max_scroll()), 0.0, 1.0)
		_list.draw_rect(Rect2(Vector2(W - 3 * u, (vh - th) * ks), Vector2(2.5 * u, th)), Color(Toon.ui_ink, 0.25))


## Aucun pouvoir : rouleau fermé qui flotte dans un ensō, sceau vermillon, et une phrase pour en obtenir.
func _draw_empty(W: float, y: float, u: float) -> void:
	var c := Vector2(W / 2.0, y + 70.0 * u)
	_list.draw_circle(c, 52.0 * u, Color(Toon.ui_ink, 0.05))
	_list.draw_arc(c, 44.0 * u, -PI * 0.42, PI * 1.45, 48, Color(Toon.ui_ink, 0.28), 4.0 * u, true)
	_list.draw_arc(c, 40.0 * u, PI * 1.1, PI * 1.42, 12, Color(Toon.ui_ink, 0.16), 2.0 * u, true)
	var bob := Vector2(0.0, sin(_t * 1.6) * 3.0 * u)
	UiKit.glyph(_list, "scroll", c + bob, 26.0 * u, Color(Toon.ui_ink, 0.45))
	# sceau (hanko) posé de biais
	var hc := c + Vector2(30.0, 28.0) * u
	var hs := 7.0 * u
	var rot := Vector2.from_angle(-0.2)
	var nrm := Vector2(-rot.y, rot.x)
	_list.draw_colored_polygon(PackedVector2Array([hc + (-rot - nrm) * hs, hc + (rot - nrm) * hs, hc + (rot + nrm) * hs, hc + (-rot + nrm) * hs]),
		Color(Toon.VERMILION, 0.85))
	# trois éclats d'or qui scintillent
	var spots := [Vector2(-38.0, -30.0), Vector2(40.0, -22.0), Vector2(-30.0, 34.0)]
	for k in spots.size():
		var sp: Vector2 = spots[k]
		var tw := 0.5 + 0.5 * sin(_t * 2.4 + float(k) * 2.1)
		UiKit.glyph(_list, "star", c + sp * u, (3.0 + 2.0 * tw) * u, Color(Toon.GOLD, 0.35 + 0.45 * tw))
	UiKit.text(_list, UiKit.TITLE_FONT, "Aucun rouleau pour l'instant", Vector2(W / 2.0, y + 146.0 * u), int(15 * u), Color(Toon.ui_ink, 0.8))
	UiKit.text(_list, _ui, "Gagne un niveau pour choisir ton premier rouleau.", Vector2(W / 2.0, y + 164.0 * u), int(10 * u), Color(Toon.ui_ink, 0.55))


## Or lisible sur le papier du thème (foncé sur papier clair, vif sur papier sombre).
func _gold_ink() -> Color:
	return GOLD_HI if Toon.ui_dark else GOLD_INK


## Papier d'une tuile : washi clair (planche), un ton au-dessus du papier sur un thème sombre.
func _tile_paper() -> Color:
	return Toon.ui_paper.lightened(0.08) if Toon.ui_dark else UIColors.WASHI_LIGHT


## Bordure de rareté d'un rectangle (couleur et épaisseur de UIColors.RARITY, filet intérieur, contour sumi).
func _rarity_border(r: Rect2, rank: int, radius: float, u: float, a: float) -> void:
	var rd := UIColors.rarity(rank)
	var bc: Color = rd["color"]
	var bw := float(rd["w"]) * u
	if bool(rd["outer"]):
		_list.draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(radius + 2.0 * u), Color(UIColors.SUMI, a), maxi(1, int(2.0 * u))), r.grow(2.0 * u))
	_list.draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(radius), Color(bc, a), maxi(1, int(bw))), r)
	if bool(rd["inner"]):
		var inner := r.grow(-(bw + 2.0 * u))
		_list.draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), maxi(1, int(radius - bw - 2.0 * u)), Color(bc, a), maxi(1, int(1.5 * u))), inner)


## Une tuile (planche MesPouvoirs) : papier à bordure de rareté, médaillon (cerne de l'élément, glyphe sumi),
## nom, étiquette d'élément (picto + NOM) et crans de niveau. Tuile ouverte : levée, cerclée d'encre.
func _draw_tile(i: int, r0: Rect2, u: float, a: float) -> void:
	var info: Dictionary = _infos[i]
	var id := String(info.get("id", ""))
	var rank := int(info.get("rarity_rank", 0))
	var school := UiKit.power_school(id)
	var sel := i == _sel
	var r := r0
	if sel:
		r.position.y -= 4.0 * u * UiKit.ease_out(_open_k)
	if _pressed == i:
		r = r.grow(-2.0 * u)
	var radius := 12.0 * u
	if sel:
		_list.draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(radius + 3.0 * u), Color(UIColors.SUMI, a), maxi(1, int(3.0 * u))), r.grow(3.0 * u))
	_list.draw_style_box(UiKit.box(_sb, Color(_tile_paper(), a), int(radius)), r)
	_rarity_border(r, rank, radius, u, a)
	# médaillon 58 : disque washi, cerne de la couleur d'élément, glyphe sumi
	var mc := Vector2(r.get_center().x, r.position.y + 36.0 * u)
	UiKit.power_medal(_list, id, mc, 58.0 * u / 60.0, UIColors.element(school), 27.0, 4.0, UiKit.NONE, 3.6, a)
	# nom (Shippori 13,5), rétréci s'il déborde
	var nm := UiKit.power_label(id)
	var nfs := int(13.5 * u)
	while nfs > 8 and UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > r.size.x - 8.0 * u:
		nfs -= 1
	UiKit.text(_list, UiKit.TITLE_FONT, nm, Vector2(r.get_center().x, r.position.y + 81.0 * u), nfs, Color(Toon.ui_ink, a))
	# étiquette d'élément (pictogramme + NOM sur la couleur d'élément), puis les crans
	var word := UiKit.caps(UIColors.element_word(school), UiKit.num_font())
	var wfs := int(8.0 * u)
	var nf := UiKit.num_font()
	var ww := nf.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs).x + float(word.length()) * 1.0 * u
	var pill_w := 5.0 * u + 11.0 * u + 3.0 * u + ww + 7.0 * u
	var mx := int(info.get("max_level", 1))
	var lv := int(info.get("level", 1))
	var cr_w := 11.0 * u
	var crans_w := 0.0
	if mx > 1:
		crans_w = float(mx) * cr_w + float(mx - 1) * 2.0 * u
	var row_w := pill_w + (6.0 * u + crans_w if mx > 1 else 0.0)
	var rx := r.get_center().x - row_w / 2.0
	var ry := r.position.y + 97.0 * u
	var pill := Rect2(Vector2(rx, ry - 9.0 * u), Vector2(pill_w, 18.0 * u))
	var ec := UIColors.element(school)
	_list.draw_style_box(UiKit.box(_sb, Color(ec, a), int(9.0 * u)), pill)
	UiKit.element_icon(_list, school, Vector2(pill.position.x + 5.0 * u + 5.5 * u, ry), 11.0 * u, a, UIColors.WASHI)
	var wx := pill.position.x + 5.0 * u + 11.0 * u + 3.0 * u
	for ch_i in word.length():
		var ch := word.substr(ch_i, 1)
		_list.draw_string(nf, Vector2(wx, ry + float(wfs) * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, Color(UIColors.WASHI, a))
		wx += nf.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs).x + 1.0 * u
	if mx > 1:
		var cx0 := pill.end.x + 6.0 * u
		for kk in mx:
			var cr := Rect2(Vector2(cx0 + float(kk) * (cr_w + 2.0 * u), ry - 2.5 * u), Vector2(cr_w, 5.0 * u))
			if kk < lv:
				_list.draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD_DARK, a), int(2.5 * u)), cr)
			else:
				_list.draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(2.5 * u), Color(UIColors.LINE_MUTED, a), maxi(1, int(1.5 * u))), cr)


## Une école (planche MesPouvoirs, HARMONIES) : tuile (sumi bordée d'or quand un bonus est actif, papier sinon,
## pointillés tant qu'aucun pouvoir n'y compte), anneau de 4 arcs et pictogramme de l'élément, paliers 2 et 4 en losanges.
func _draw_school(k: int, r0: Rect2, u: float) -> void:
	var sd: Dictionary = _schools[k]
	var school := String(sd["school"])
	var st: Dictionary = sd["st"]
	var n := int(st.get("count", 0))
	var tiers: Array = Data.AFF_TIERS
	var on := n >= int(tiers[0])
	var r := r0
	if _pressed == SCHOOL_BASE + k:
		r = r.grow(-2.0 * u)
	var radius := int(10.0 * u)
	var ec := UIColors.element(school)
	if _sel == SCHOOL_BASE + k:
		_list.draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), radius + int(3.0 * u), Color(Toon.VERMILION, 1.0), maxi(1, int(2.0 * u))), r.grow(3.0 * u))
	if on:
		_list.draw_style_box(UiKit.box(_sb, UIColors.SUMI, radius, UIColors.GOLD, maxi(1, int(2.0 * u))), r)
	elif n > 0:
		_list.draw_style_box(UiKit.box(_sb, _tile_paper(), radius, UIColors.LINE_MUTED, maxi(1, int(1.5 * u))), r)
	else:
		_dashed_rect(r, 10.0 * u, UIColors.LINE_MUTED, maxf(1.0, 1.5 * u), 4.0 * u, 3.0 * u)
	# anneau (gabarit 38 affiché à 48) et pictogramme au centre (papier sur sumi, pâle sans pouvoir)
	var rc := Vector2(r.get_center().x, r.position.y + 32.0 * u)
	var rr := 16.0 * 48.0 / 38.0 * u
	UiKit.harmony_ring(_list, rc, rr, mini(n, 4), 0, ec, UIColors.LINE_MUTED, 1.0, false, true)
	var ic: Color = UIColors.WASHI if on else ec
	UiKit.element_icon(_list, school, rc, 19.0 * u, 1.0 if n > 0 else 0.35, ic)
	# paliers 2 et 4 : losanges (or cerné d'encre une fois atteints)
	var dy := r.position.y + 68.0 * u
	for t in mini(tiers.size(), 2):
		var dc := Vector2(r.get_center().x + (float(t) - 0.5) * 16.0 * u, dy)
		if n >= int(tiers[t]):
			UiKit.diamond(_list, dc, 5.0 * u, UIColors.GOLD, UIColors.SUMI, maxf(1.0, 1.5 * u))
		else:
			UiKit.diamond(_list, dc, 5.0 * u, UiKit.NONE, UIColors.LINE_MUTED, maxf(1.0, 1.5 * u))
	# bonus actif : petit sceau d'or penché en haut à droite
	if on:
		var bc := Vector2(r.end.x - 5.0 * u, r.position.y + 3.0 * u)
		var hs := 10.0 * u
		var sq := PackedVector2Array()
		for j in 4:
			sq.append(bc + Vector2(-hs, -hs).rotated(deg_to_rad(8.0) + PI * 0.5 * float(j)))
		_list.draw_colored_polygon(sq, UIColors.GOLD)
		sq.append(sq[0])
		_list.draw_polyline(sq, UIColors.SUMI, maxf(1.0, 1.5 * u), true)
		UiKit.diamond(_list, bc, 3.5 * u, UIColors.SUMI)


## Contour en pointillés d'un rectangle aux coins arrondis (tuile d'école vide).
func _dashed_rect(r: Rect2, rad: float, col: Color, w: float, dash: float, gap: float) -> void:
	var pts := UiKit.rrect_points(r, rad)
	pts.append(pts[0])
	var carry := 0.0  # longueur déjà parcourue dans le motif tiret + espace
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var seg := p0.distance_to(p1)
		var d := 0.0
		while d < seg:
			var pos := fmod(carry + d, dash + gap)
			var left := (dash - pos) if pos < dash else (dash + gap - pos)
			var step := minf(left, seg - d)
			if pos < dash and step > 0.01:
				_list.draw_line(p0.lerp(p1, d / seg), p0.lerp(p1, (d + step) / seg), col, w, true)
			d += maxf(step, 0.01)
		carry += seg


# ------------------------------------------------------------------ bulles

## Bulle de détail (tuile ou école) : renvoie sa hauteur ; ne dessine que si `paint` (même enchaînement pour mesurer).
func _bubble(key: int, pos: Vector2, bw: float, paint: bool, a: float) -> float:
	if key >= SCHOOL_BASE:
		return _bubble_school(key - SCHOOL_BASE, pos, bw, paint, a)
	if key < 0 or key >= _infos.size():
		return 0.0
	var u := _u
	var info: Dictionary = _infos[key]
	var id := String(info.get("id", ""))
	var px := 16.0 * u
	var py := 12.0 * u
	var x := pos.x + px
	var tw := bw - px * 2.0
	var y := pos.y + py
	# en-tête : nom japonais en capitales d'or espacées ; à droite, la figure et le déclencheur en pictogrammes
	var hfs := int(12 * u)
	y += 13.0 * u
	if paint:
		var sp := maxi(1, int(2.0 * u))
		if _caps.spacing_glyph != sp:
			_caps.spacing_glyph = sp
		var nm := UiKit.caps(_p(String(info.get("name", ""))), UiKit.TITLE_FONT)
		var ic := Vector2(x + tw - 9.0 * u, y - 4.5 * u)
		var room := tw - 52.0 * u
		var f := hfs
		while f > 8 and _caps.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > room:
			f -= 1
		_list.draw_string(_caps, Vector2(x, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, f, Color(GOLD_HI, a))
		UiKit.trig_icon(_list, id, ic, 18.0 * u, UIColors.WASHI, a)
		var fig := UiKit.trigger_figure(id)
		if fig != "":
			UiKit.figure_icon(_list, fig, ic - Vector2(24.0 * u, 0.0), 18.0 * u, a)
	# la phrase, en gras
	y = _lines(UiKit.fx_line(id), x, y + 4.0 * u, tw, int(13.5 * u), 17.5 * u, 3, Color(UIColors.WASHI, a), paint, false)
	# tickets d'effet au niveau actuel
	var rows: Array = info.get("fx", [])
	if rows.is_empty():
		rows = UiKit.fx_rows(id, 0, int(info.get("level", 1)))
	y = _fx_chips(rows, x, y + 9.0 * u, tw, paint, a)
	# synergie active
	var syn := _p(String(info.get("synergy", "")))
	if syn != "":
		y = _lines("+ " + syn, x, y + 2.0 * u, tw, int(10 * u), 13.0 * u, 2, Color(GOLD_HI, a), paint, false)
	return y - pos.y + py


## Bulle d'une école : nom, compte, bonus à 2 et à 4 (actifs en or), Sceau maître s'il compte.
func _bubble_school(k: int, pos: Vector2, bw: float, paint: bool, a: float) -> float:
	if k < 0 or k >= _schools.size():
		return 0.0
	var u := _u
	var sd: Dictionary = _schools[k]
	var school := String(sd["school"])
	var st: Dictionary = sd["st"]
	var n := int(st.get("count", 0))
	var tier := int(st.get("tier", 0))
	var tiers: Array = Data.AFF_TIERS
	var top := int(tiers[tiers.size() - 1])
	var bonus: Array = Data.AFFINITY.get(school, [])
	var col := UIColors.element(school, true)
	var pad := 14.0 * u
	var x := pos.x + pad
	var tw := bw - pad * 2.0
	var y := pos.y + pad * 0.85
	# en-tête : anneau miniature, nom de l'école, compte
	var hr := 10.0 * u
	if paint:
		var hc := Vector2(x + hr, y + hr)
		UiKit.harmony_ring(_list, hc, hr, mini(n, 4), 0, col, UIColors.LINE_MUTED_DARK, a, false, false, 3.0, 2.4)
		UiKit.element_icon(_list, school, hc, hr * 1.1, a, col)
		var info_s: Dictionary = Data.SCHOOLS[school]
		_list.draw_string(_title, Vector2(x + hr * 2.0 + 8.0 * u, y + hr + 5.0 * u), String(info_s["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Color(UIColors.WASHI, a))
		var cnt := "%d/%d" % [mini(n, top), top]
		var cfs := int(12 * u)
		var nf := UiKit.num_font()
		var cw := nf.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
		_list.draw_string(nf, Vector2(x + tw - cw, y + hr + 4.0 * u), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(GOLD_HI, a) if tier > 0 else Color(UIColors.WASHI, 0.6 * a))
	y += hr * 2.0 + 2.0 * u
	# paliers : losange d'or si actif, losange vide sinon
	var lh := 14.5 * u
	for t in mini(tiers.size(), bonus.size()):
		var on: bool = tier > t
		var txt := "%d : %s" % [int(tiers[t]), _p(String(bonus[t]))]
		var c: Color = Color(GOLD_HI, a) if on else Color(UIColors.WASHI, 0.6 * a)
		var y0 := y
		y = _lines(txt, x + 18.0 * u, y, tw - 18.0 * u, int(10.5 * u), lh, 3, c, paint, on)
		if paint:
			var mc := Vector2(x + 6.0 * u, y0 + lh - 4.0 * u)
			if on:
				UiKit.diamond(_list, mc, 4.5 * u, Color(GOLD_HI, a))
			else:
				UiKit.diamond(_list, mc, 4.5 * u, UiKit.NONE, Color(UIColors.WASHI, 0.4 * a), maxf(1.0, 1.2 * u))
		y += 3.0 * u
	if _rakkan:
		var note := UiKit.power_label("ink_rakkan") + " : +1 dans chaque école commencée."
		y = _lines(note, x, y + 2.0 * u, tw, int(9 * u), 13.0 * u, 2, Color(UIColors.WASHI, 0.5 * a), paint, false)
	return y - pos.y + pad * 0.8


## Tickets d'effet sur la bulle d'encre (planche MesPouvoirs), à la suite et à la ligne s'il le faut : fond vert d'encre,
## pictogramme papier, chiffre en Zen Kaku (vert de jade ; « avant → » pâle), unité, libellé court.
## Renvoie le bas des tickets ; ne dessine que si `paint`.
func _fx_chips(rows: Array, x: float, y: float, tw: float, paint: bool, a: float) -> float:
	var n := mini(rows.size(), 3)
	if n == 0:
		return y
	var u := _u
	var nf := UiKit.num_font()
	var h := 30.0 * u
	var gap := 8.0 * u
	var vfs := int(15 * u)
	var sfs := int(10 * u)
	var cx := x
	var cy := y
	for k in n:
		var rw: Array = rows[k]
		var parts := UiKit.split_value(String(rw[1]))
		var head := String(parts[0])
		var num := String(parts[1])
		var unit := String(parts[2])
		var lab := String(rw[2])
		var hw := nf.get_string_size(head + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x if head != "" else 0.0
		var nw := nf.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs).x if num != "" else 0.0
		var uw := _ui.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x + 2.0 * u if unit != "" else 0.0
		var lw := _ui.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x if lab != "" else 0.0
		var cw := 10.0 * u + 14.0 * u + 6.0 * u + hw + nw + uw + (6.0 * u + lw if lab != "" else 0.0) + 10.0 * u
		cw = minf(cw, tw)
		if cx + cw > x + tw + 0.5 and cx > x:
			cx = x
			cy += h + 6.0 * u
		if paint:
			var r := Rect2(Vector2(cx, cy), Vector2(cw, h))
			_list.draw_style_box(UiKit.box(_sb, Color(UIColors.CHIP_ON_DARK, a), int(8 * u)), r)
			var mid := r.get_center().y
			UiKit.fx_icon(_list, String(rw[0]), Vector2(r.position.x + 10.0 * u + 7.0 * u, mid), 14.0 * u, UIColors.WASHI, a)
			var tx := r.position.x + 30.0 * u
			if head != "":
				_list.draw_string(nf, Vector2(tx, mid + float(sfs) * 0.36), head, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(UIColors.WASHI, 0.55 * a))
				tx += hw
			if num != "":
				_list.draw_string(nf, Vector2(tx, mid + float(vfs) * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs, Color(UIColors.JADE_UP_ON_DARK, a))
				tx += nw
			if unit != "":
				_list.draw_string(_ui, Vector2(tx + 2.0 * u, mid + float(sfs) * 0.36), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(UIColors.WASHI, 0.6 * a))
				tx += uw
			if lab != "":
				var room := r.end.x - 10.0 * u - (tx + 6.0 * u)
				_fit(lab, Vector2(tx + 6.0 * u, mid + float(sfs) * 0.36), room, sfs, Color(UIColors.WASHI, a))
		cx += cw + gap
	return cy + h


# ------------------------------------------------------------------ texte

## Lignes coupées à `w`, une par `lh` sous `y` ; renvoie la ligne de base de la dernière. Ne dessine que si `paint`.
func _lines(txt: String, x: float, y: float, w: float, fs: int, lh: float, maxn: int, c: Color, paint: bool, bold: bool) -> float:
	var ls := _wrap(_ui, txt, fs, w)
	for k in mini(ls.size(), maxn):
		y += lh
		if paint:
			_list.draw_string(_ui, Vector2(x, y), ls[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
			if bold:
				_list.draw_string(_ui, Vector2(x + 0.7, y), ls[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return y


## Coupe un texte en lignes qui tiennent dans `width` (mots entiers ; la ponctuation reste collée au mot).
func _wrap(font: Font, txt: String, fs: int, width: float) -> PackedStringArray:
	return UiKit.wrap(font, txt, fs, width, GLUE)


## Une ligne qui rétrécit (un peu) si elle déborde.
func _fit(txt: String, pos: Vector2, maxw: float, fs: int, c: Color) -> void:
	var f := fs
	while f > 6 and _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > maxw:
		f -= 1
	_list.draw_string(_ui, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, c)
