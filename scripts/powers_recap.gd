extends Control
## Récapitulatif « MES POUVOIRS » (depuis la pause), à lire d'un coup d'œil comme les cartes
## de rouleau : grille de médaillons (pictogramme sur la couleur d'élément, anneau de rareté, crans de niveau, nom court) ;
## un toucher lève la tuile et ouvre sa bulle de détail. Dessous, les cinq écoles en pastilles à anneau de progression
## (paliers 2 et 4), une bulle donne leurs bonus. Carte de papier sur voile d'encre ; le contenu glisse au doigt
## (ou à la molette). Marche jeu figé : tout est compté en temps réel (UiKit.real_delta). main : open(powers), signal closed.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/power_data.gd")

signal closed

const INPUT_DELAY := 0.3  # le toucher qui a ouvert la carte ne doit rien faire
const NO_TARGET := -2
const BACK_TARGET := -1
const SCHOOL_BASE := 1000  # cible « pastille d'école k » = SCHOOL_BASE + k (les tuiles : leur index)
const DRAG_START := 8.0  # glissé minimal (× u) avant de faire défiler
const OPEN_DUR := 0.18  # ouverture de la bulle (s)
const GOLD_INK := Color("#9A6B12")  # or lisible sur le papier
const GOLD_HI := Color("#E2A93B")
const BUB_BODY := Color("#1C1A21")  # bulle d'encre
const STAT_TXT := Color("#FF9A85")  # valeur chiffrée sur la bulle d'encre
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
var _card := Rect2()
var _view := Rect2()  # zone qui défile (coordonnées de l'écran)
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
var _med_r := 30.0
var _empty_h := 0.0
var _sec_y := 0.0
var _school_c: Array = []
var _school_r := 18.0
var _bub := Rect2()
var _bub_tip := 0.0
var _bub_row_top := 0.0
var _list: Control
var _ui := FontVariation.new()
var _title := FontVariation.new()
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 1
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 3
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
	for k in _school_c.size():
		var c: Vector2 = _school_c[k]
		if c.distance_to(lp) <= _school_r + 12.0 * _u:
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

## Carte (qui glisse un peu à l'ouverture), bouton retour et zone qui défile.
func _layout() -> void:
	var w := size.x
	var h := size.y
	_u = minf(w / 400.0, h / 760.0)
	var u := _u
	var ch := minf(h - 40.0 * u, 720.0 * u)
	_card = Rect2(Vector2(w * 0.05, h * 0.5 - ch / 2.0 + 14 * u * (1.0 - UiKit.ease_out(_t / 0.3))), Vector2(w * 0.9, ch))
	var bc := _card.position + Vector2(34, 40) * u
	_back = Rect2(bc - Vector2(26, 26) * u, Vector2(52, 52) * u)
	_view = Rect2(Vector2(_card.position.x + 10 * u, _card.position.y + 92 * u), Vector2(_card.size.x - 20 * u, _card.size.y - 102 * u))
	_list.position = _view.position
	_list.size = _view.size
	_list.modulate.a = clampf(_t / 0.25, 0.0, 1.0)


## Grille des tuiles, bulle insérée sous la rangée touchée, rangée des écoles (coordonnées du contenu).
func _layout_list() -> void:
	var u := _u
	var W := _view.size.x
	_cols = clampi(int(W / (104.0 * u)), 3, 6)
	var gap := 8.0 * u
	var tw := (W - gap * float(_cols - 1)) / float(_cols)
	_med_r = minf(tw * 0.29, 32.0 * u)
	var th := _med_r * 2.0 + 58.0 * u
	var bw := W - 4.0 * u
	var bk := UiKit.ease_out(_open_k)
	var bub_h := 0.0
	if _shown != NO_TARGET:
		bub_h = _bubble(_shown, Vector2.ZERO, bw, false, 1.0)
	_bub = Rect2()
	_tile_rects.clear()
	var y := 6.0 * u
	_empty_h = 0.0
	var n := _infos.size()
	if n == 0:
		_empty_h = 176.0 * u
		y += _empty_h
	var rows := ceili(float(n) / float(_cols))
	for row in rows:
		var first: int = row * _cols
		var in_row := mini(_cols, n - first)
		# rangée incomplète : centrée
		var x0 := (W - (tw * float(in_row) + gap * float(in_row - 1))) / 2.0
		for c in in_row:
			_tile_rects.append(Rect2(Vector2(x0 + float(c) * (tw + gap), y), Vector2(tw, th)))
		y += th
		if _shown != NO_TARGET and _shown < SCHOOL_BASE and _shown >= first and _shown < first + in_row:
			var tr: Rect2 = _tile_rects[_shown]
			_bub_row_top = tr.position.y
			_bub_tip = tr.get_center().x
			_bub = Rect2(Vector2(2.0 * u, y + 10.0 * u), Vector2(bw, bub_h))
			y += (bub_h + 18.0 * u) * bk
		y += gap
	# bonus d'école : titre, puis une rangée de pastilles
	y += 8.0 * u
	_sec_y = y
	y += 46.0 * u
	var ns := _schools.size()
	var slot := W / float(maxi(ns, 1))
	_school_r = minf(18.0 * u, slot * 0.26)
	_school_c.clear()
	var cy := y + _school_r + 8.0 * u
	for k in ns:
		_school_c.append(Vector2(slot * (float(k) + 0.5), cy))
	y = cy + _school_r + 30.0 * u
	if _shown >= SCHOOL_BASE and _shown - SCHOOL_BASE < ns:
		var sc: Vector2 = _school_c[_shown - SCHOOL_BASE]
		_bub_row_top = sc.y - _school_r - 12.0 * u
		_bub_tip = sc.x
		_bub = Rect2(Vector2(2.0 * u, y + 4.0 * u), Vector2(bw, bub_h))
		y += (bub_h + 12.0 * u) * bk
	_content_h = y + 12.0 * u


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	if size.x < 10.0:
		return
	var u := _u
	var a := clampf(_t / 0.25, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.85 * a))
	var card := _card
	UiKit.box(_sb, Color(Toon.PAPER, a), int(18 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.5 * a)
	_sb.shadow_size = int(20 * u)
	draw_style_box(_sb, card)
	# titre et nombre de pouvoirs
	var cxc := card.get_center().x
	UiKit.text(self, _title, "MES POUVOIRS", Vector2(cxc + 10 * u, card.position.y + 48 * u), int(22 * u), Color(Toon.SUMI, a))
	draw_line(Vector2(cxc - 20 * u, card.position.y + 60 * u), Vector2(cxc + 40 * u, card.position.y + 60 * u), Color(Toon.VERMILION, a), 2 * u)
	var sub: String = "%d POUVOIR%s" % [_count, "S" if _count > 1 else ""] if _count > 0 else "AUCUN POUVOIR"
	UiKit.text(self, _ui, sub, Vector2(cxc + 10 * u, card.position.y + 78 * u), int(10 * u), Color(Toon.SUMI, 0.5 * a))
	# retour : ensō et flèche en haut à gauche de la carte (comme les options)
	var bc := _back.get_center()
	var k: float = 0.92 if _pressed == BACK_TARGET else 1.0
	draw_arc(bc, 16 * u * k, -PI * 0.35, PI * 1.45, 28, Color(Toon.SUMI, a), 3.5 * u, true)
	var head := bc + Vector2(-7, 0) * u * k
	draw_line(bc + Vector2(8, 0) * u * k, head, Color(Toon.VERMILION, a), 3 * u, true)
	draw_line(head, head + Vector2(5, -5) * u * k, Color(Toon.VERMILION, a), 3 * u, true)
	draw_line(head, head + Vector2(5, 5) * u * k, Color(Toon.VERMILION, a), 3 * u, true)


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
		var a: float = lerpf(1.0, 0.55, bk) if tile_open and i != _sel else 1.0
		_draw_tile(i, Rect2(r.position + Vector2(0.0, oy), r.size), u, a)
	# bonus d'école
	var sy := _sec_y + oy
	UiKit.text(_list, _title, "BONUS D'ÉCOLE", Vector2(W / 2.0, sy + 18.0 * u), int(13 * u), Toon.SUMI)
	_list.draw_line(Vector2(W / 2.0 - 20 * u, sy + 26 * u), Vector2(W / 2.0 + 20 * u, sy + 26 * u), Toon.VERMILION, 2 * u)
	UiKit.text(_list, _ui, "2 ou 4 pouvoirs d'une école : un bonus", Vector2(W / 2.0, sy + 41 * u), int(9 * u), Color(Toon.SUMI, 0.5))
	for k in _school_c.size():
		var c: Vector2 = _school_c[k]
		_draw_school(k, c + Vector2(0.0, oy), u)
	# bulle de détail, devant le reste
	if _shown != NO_TARGET and _bub.size.y > 0.0 and bk > 0.01:
		var box := Rect2(_bub.position + Vector2(0.0, oy - 6.0 * u * (1.0 - bk)), _bub.size)
		var tipx := clampf(_bub_tip, box.position.x + 22.0 * u, box.end.x - 22.0 * u)
		_list.draw_colored_polygon(PackedVector2Array([Vector2(tipx, box.position.y - 9.0 * u), Vector2(tipx + 9.0 * u, box.position.y + 1.0),
			Vector2(tipx - 9.0 * u, box.position.y + 1.0)]), Color(BUB_BODY, 0.97 * bk))
		UiKit.box(_sb, Color(BUB_BODY, 0.97 * bk), int(12 * u))
		_sb.shadow_color = Color(0, 0, 0, 0.3 * bk)
		_sb.shadow_size = int(8 * u)
		_sb.shadow_offset = Vector2(0, 3 * u)
		_list.draw_style_box(_sb, box)
		_bubble(_shown, box.position, box.size.x, true, bk)
	# fondus du papier en haut et en bas quand il reste à faire défiler
	var vh := _list.size.y
	var fade := 16.0 * u
	var paper := Toon.PAPER
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
		_list.draw_rect(Rect2(Vector2(W - 3 * u, (vh - th) * ks), Vector2(2.5 * u, th)), Color(Toon.SUMI, 0.25))


## Aucun pouvoir : rouleau fermé qui flotte dans un ensō, sceau vermillon, et une phrase pour en obtenir.
func _draw_empty(W: float, y: float, u: float) -> void:
	var c := Vector2(W / 2.0, y + 70.0 * u)
	_list.draw_circle(c, 52.0 * u, Color(Toon.SUMI, 0.05))
	_list.draw_arc(c, 44.0 * u, -PI * 0.42, PI * 1.45, 48, Color(Toon.SUMI, 0.28), 4.0 * u, true)
	_list.draw_arc(c, 40.0 * u, PI * 1.1, PI * 1.42, 12, Color(Toon.SUMI, 0.16), 2.0 * u, true)
	var bob := Vector2(0.0, sin(_t * 1.6) * 3.0 * u)
	UiKit.glyph(_list, "scroll", c + bob, 26.0 * u, Color(Toon.SUMI, 0.45))
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
	UiKit.text(_list, UiKit.TITLE_FONT, "Aucun rouleau pour l'instant", Vector2(W / 2.0, y + 146.0 * u), int(15 * u), Color(Toon.SUMI, 0.8))
	UiKit.text(_list, _ui, "Gagne un niveau pour choisir ton premier rouleau.", Vector2(W / 2.0, y + 164.0 * u), int(10 * u), Color(Toon.SUMI, 0.55))


## Une tuile : médaillon (halo d'élément, anneau de rareté, pictogramme), déclencheur en badge, crans de niveau, nom court.
func _draw_tile(i: int, r: Rect2, u: float, a: float) -> void:
	var info: Dictionary = _infos[i]
	var id := String(info.get("id", ""))
	var rank := int(info.get("rarity_rank", 0))
	var leg := rank >= 3
	var rc: Color = info.get("rarity_color", Toon.SUMI)
	var col := UiKit.power_color(id)
	var sel := i == _sel
	var pulse := 0.5 + 0.5 * sin(_t * 3.0 + float(i) * 1.1)
	var k: float = 0.94 if _pressed == i else 1.0
	var big := _med_r * k
	var mc := Vector2(r.get_center().x, r.position.y + 14.0 * u + _med_r)
	var radius := int(14 * u)
	# fond : papier doré (légendaire), liseré vermillon (tuile ouverte)
	if leg:
		_list.draw_style_box(UiKit.box(_sb, Color(GOLD_HI, (0.10 + 0.05 * pulse) * a), radius), r)
	if sel:
		_list.draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.05 * a), radius, Color(Toon.VERMILION, a), maxi(1, int(2.5 * u))), r)
	# lueurs : or (légendaire), couleur de rareté (épique), halo de l'élément
	if leg:
		_list.draw_circle(mc, big * (1.45 + 0.06 * pulse), Color(GOLD_HI, 0.18 * a))
		for ray in 10:
			var ang := _t * 0.5 + TAU * float(ray) / 10.0
			var d := Vector2(cos(ang), sin(ang))
			_list.draw_line(mc + d * (big + 7.0 * u), mc + d * (big + 12.0 * u), Color(GOLD_HI, 0.5 * a), 2.0 * u)
	elif rank == 2:
		_list.draw_circle(mc, big + 9.0 * u, Color(rc, (0.14 + 0.10 * pulse) * a))
	for h in 3:
		_list.draw_circle(mc, big * (1.36 - 0.12 * float(h)), Color(col, (0.04 + 0.03 * float(h)) * a))
	# médaillon : anneau de rareté, disque d'élément, reflet, pictogramme
	var ring: Color = GOLD_HI if leg else rc
	_list.draw_circle(mc, big + 4.0 * u, Color(ring, a))
	_list.draw_circle(mc, big + 1.2 * u, Color(Toon.SUMI, 0.6 * a))
	_list.draw_circle(mc, big, Color(col, a))
	_list.draw_circle(mc + Vector2(0, -big * 0.2), big * 0.78, Color(col.lightened(0.14), 0.55 * a))
	_list.draw_arc(mc, big * 0.86, PI * 1.1, PI * 1.55, 12, Color(1, 1, 1, 0.22 * a), 2.0 * u, true)
	UiKit.glyph(_list, UiKit.icon_of(id), mc, big * 0.62, GOLD_HI if leg else Toon.WASHI, col, a)
	# déclencheur : petit badge en haut à gauche du médaillon
	var tc := mc + Vector2(-big * 0.82, -big * 0.82)
	var tr := 8.5 * u
	_list.draw_circle(tc, tr + 1.5 * u, Color(Toon.PAPER, a))
	_list.draw_circle(tc, tr, Color(GOLD_HI if leg else Toon.SUMI, a))
	UiKit.trigger_icon(_list, id, tc, tr * 0.62, BUB_BODY if leg else Toon.WASHI, GOLD_HI if leg else Toon.SUMI, a)
	# crans de niveau sur le bas du médaillon (en or quand le pouvoir est au maximum)
	var mx := int(info.get("max_level", 1))
	if mx > 1:
		var lv := int(info.get("level", 1))
		var full := lv >= mx
		for kk in mx:
			var dc := mc + Vector2.from_angle(PI / 2.0 + (float(kk) - float(mx - 1) / 2.0) * 0.4) * (big + 3.0 * u)
			var pr := 3.8 * u
			_list.draw_circle(dc, pr + 1.5 * u, Color(Toon.SUMI, a))
			if kk < lv:
				_list.draw_circle(dc, pr, Color(GOLD_HI if full else Toon.WASHI, a))
			else:
				_list.draw_circle(dc, pr * 0.55, Color(Toon.WASHI, 0.25 * a))
	# nom court, une ou deux lignes
	var nm := UiKit.power_label(id)
	var nfs := int(12.5 * u)
	var lines := _wrap(UiKit.TITLE_FONT, nm, nfs, r.size.x - 6.0 * u)
	if lines.size() > 2:
		nfs = int(11 * u)
		lines = _wrap(UiKit.TITLE_FONT, nm, nfs, r.size.x - 6.0 * u)
	var ny := mc.y + _med_r + 20.0 * u
	var ncol: Color = GOLD_INK if leg else Toon.SUMI
	for kk in mini(lines.size(), 2):
		UiKit.text(_list, UiKit.TITLE_FONT, lines[kk], Vector2(r.get_center().x, ny + float(kk) * 13.0 * u), nfs, Color(ncol, a))


## Une école : pastille, anneau de progression (n/4, crans à 2 et 4), lueur d'or quand un bonus est actif.
func _draw_school(k: int, c: Vector2, u: float) -> void:
	var sd: Dictionary = _schools[k]
	var school := String(sd["school"])
	var st: Dictionary = sd["st"]
	var n := int(st.get("count", 0))
	var tier := int(st.get("tier", 0))
	var tiers: Array = Data.AFF_TIERS
	var top := int(tiers[tiers.size() - 1])
	var col := UiKit.school_color(school)
	var press: float = 0.92 if _pressed == SCHOOL_BASE + k else 1.0
	var sr := _school_r * press
	var rr := sr + 6.0 * u
	var pulse := 0.5 + 0.5 * sin(_t * 2.6 + float(k))
	var done := tier >= tiers.size()
	if tier > 0:
		_list.draw_circle(c, rr + (9.0 + 2.0 * pulse) * u, Color(GOLD_HI, (0.10 + 0.05 * float(tier)) * (0.6 + 0.4 * pulse)))
		_list.draw_circle(c, rr + 4.0 * u, Color(GOLD_HI, 0.12 * float(tier)))
	if _sel == SCHOOL_BASE + k:
		_list.draw_arc(c, rr + 8.0 * u, 0.0, TAU, 40, Toon.VERMILION, 2.0 * u, true)
	# anneau : fond pâle, progression de la couleur d'école (or quand l'école est complète)
	_list.draw_arc(c, rr, 0.0, TAU, 48, Color(Toon.SUMI, 0.12), 4.0 * u, true)
	var f := float(mini(n, top)) / float(maxi(top, 1))
	if f > 0.0:
		_list.draw_arc(c, rr, -PI / 2.0, -PI / 2.0 + TAU * f, maxi(8, int(48.0 * f)), GOLD_HI if done else col, 4.0 * u, true)
	for th in tiers:
		var d := Vector2.from_angle(-PI / 2.0 + TAU * float(th) / float(maxi(top, 1)))
		_list.draw_circle(c + d * rr, 3.8 * u, Toon.PAPER)
		_list.draw_circle(c + d * rr, 2.7 * u, GOLD_HI if n >= int(th) else Color(Toon.SUMI, 0.35))
	# pastille de l'école (pâle tant qu'aucun pouvoir n'y compte)
	var al: float = 1.0 if n > 0 else 0.4
	_list.draw_circle(c, sr, Color(col, al))
	_list.draw_circle(c + Vector2(0, -sr * 0.2), sr * 0.78, Color(col.lightened(0.14), 0.5 * al))
	UiKit.school_icon(_list, school, c, sr * 0.6, Toon.WASHI, al, Color(col, al))
	if done:
		UiKit.glyph(_list, "star", c + Vector2(rr * 0.74, -rr * 0.74), 6.5 * u, GOLD_HI)
	var cnt := "%d/%d" % [mini(n, top), top]
	UiKit.text(_list, _ui, cnt, Vector2(c.x, c.y + rr + 15.0 * u), int(10 * u), GOLD_INK if tier > 0 else Color(Toon.SUMI, 0.55))


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
	var rank := int(info.get("rarity_rank", 0))
	var leg := rank >= 3
	var rc: Color = info.get("rarity_color", Toon.SUMI)
	var pad := 12.0 * u
	var x := pos.x + pad
	var tw := bw - pad * 2.0
	var y := pos.y + pad
	# déclencheur : pictogramme et « quand » en clair
	var chip := 20.0 * u
	if paint:
		var tc := Vector2(x + chip * 0.5, y + chip * 0.5)
		var tcol: Color = GOLD_HI if leg else Toon.VERMILION
		_list.draw_circle(tc, chip * 0.5, Color(tcol, a))
		UiKit.trigger_icon(_list, id, tc, 6.2 * u, BUB_BODY if leg else Toon.WASHI, tcol, a)
		var when := _p(String(info.get("when", "")))
		if when != "":
			_fit(when, Vector2(x + chip + 7.0 * u, tc.y + 4.0 * u), tw - chip - 7.0 * u, int(11 * u), Color(Toon.WASHI, 0.92 * a))
	y += chip + 4.0 * u
	# nom japonais et sous-titre
	var nfs := int(15 * u)
	y += 15.0 * u
	if paint:
		var nm := _p(String(info.get("name", "")))
		_list.draw_string(UiKit.TITLE_FONT, Vector2(x, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(GOLD_HI if leg else Toon.WASHI, a))
		var sub := _p(String(info.get("sub", "")))
		var nw := UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		if sub != "" and tw - nw - 8.0 * u > 30.0 * u:
			_fit("— " + sub, Vector2(x + nw + 8.0 * u, y), tw - nw - 8.0 * u, int(10 * u), Color(Toon.WASHI, 0.5 * a))
	# rareté et niveau
	y += 14.0 * u
	if paint:
		var lv := int(info.get("level", 1))
		var mx := int(info.get("max_level", 1))
		var tag := String(info.get("rarity_name", ""))
		if mx > 1:
			tag += "  ·  NIVEAU %d/%d" % [lv, mx]
		else:
			tag += "  ·  UNIQUE"
		_fit(tag, Vector2(x, y), tw, int(8.5 * u), Color(GOLD_HI if leg else rc.lightened(0.35), a))
	y += 2.0 * u
	# effet en clair
	y = _lines(_p(String(info.get("text", ""))), x, y, tw, int(11 * u), 14.5 * u, 5, Color(Toon.WASHI, 0.85 * a), paint, false)
	# valeur actuelle
	var stat := _p(String(info.get("stat", "")))
	if stat != "":
		y = _lines(stat, x, y + 4.0 * u, tw, int(12 * u), 16.0 * u, 2, Color(STAT_TXT, a), paint, true)
	# synergie active
	var syn := _p(String(info.get("synergy", "")))
	if syn != "":
		y = _lines("+ " + syn, x, y + 3.0 * u, tw, int(9.5 * u), 13.0 * u, 2, Color(GOLD_HI, a), paint, false)
	return y - pos.y + pad * 0.8


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
	var col := UiKit.school_color(school).lightened(0.1)
	var pad := 12.0 * u
	var x := pos.x + pad
	var tw := bw - pad * 2.0
	var y := pos.y + pad
	# en-tête : pastille, nom de l'école, compte
	var hr := 10.0 * u
	if paint:
		var hc := Vector2(x + hr, y + hr)
		_list.draw_circle(hc, hr, Color(col, a))
		UiKit.school_icon(_list, school, hc, hr * 0.62, Toon.WASHI, a, col)
		var info_s: Dictionary = Data.SCHOOLS[school]
		_list.draw_string(_title, Vector2(x + hr * 2.0 + 8.0 * u, y + hr + 5.0 * u), String(info_s["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Color(Toon.WASHI, a))
		var cnt := "%d/%d" % [mini(n, top), top]
		if tier >= tiers.size():
			cnt = "COMPLÈTE  " + cnt
		var cfs := int(10 * u)
		var cw := _ui.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
		_list.draw_string(_ui, Vector2(x + tw - cw, y + hr + 4.0 * u), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(GOLD_HI, a) if tier > 0 else Color(Toon.WASHI, 0.6 * a))
	y += hr * 2.0 + 2.0 * u
	# paliers : coche d'or si actif, rond vide sinon
	var lh := 14.5 * u
	for t in mini(tiers.size(), bonus.size()):
		var on: bool = tier > t
		var txt := "À %d : %s" % [int(tiers[t]), _p(String(bonus[t]))]
		var c: Color = Color(GOLD_HI, a) if on else Color(Toon.WASHI, 0.55 * a)
		var y0 := y
		y = _lines(txt, x + 18.0 * u, y, tw - 18.0 * u, int(10.5 * u), lh, 3, c, paint, on)
		if paint:
			var mc := Vector2(x + 6.0 * u, y0 + lh - 4.0 * u)
			if on:
				UiKit.glyph(_list, "check", mc, 5.5 * u, GOLD_HI, UiKit.NONE, a)
			else:
				_list.draw_arc(mc, 4.5 * u, 0.0, TAU, 16, Color(Toon.WASHI, 0.4 * a), 1.4 * u, true)
		y += 3.0 * u
	if _rakkan:
		var note := UiKit.power_label("ink_rakkan") + " : +1 dans chaque école commencée."
		y = _lines(note, x, y + 2.0 * u, tw, int(9 * u), 13.0 * u, 2, Color(Toon.WASHI, 0.5 * a), paint, false)
	return y - pos.y + pad * 0.8


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
