extends Control
## Récapitulatif « MES POUVOIRS » (depuis la pause ou les sceaux du HUD) : pouvoirs possédés rangés par école
## (pictogramme, nom court et nom japonais, niveau, déclencheur, effet chiffré), bonus d'école en clair et petit lexique.
## Carte de papier sur voile d'encre ; la liste glisse au doigt (ou à la molette). Marche jeu figé :
## tout est compté en temps réel (UiKit.real_delta). main : open(powers), signal closed.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/power_data.gd")

signal closed

const INPUT_DELAY := 0.3  # le toucher qui a ouvert la carte ne doit rien faire
const NO_TARGET := -2
const BACK_TARGET := -1
const DRAG_START := 8.0  # glissé minimal (× u) avant de faire défiler
const GOLD_INK := Color("#9A6B12")  # or lisible sur le papier

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
var _view := Rect2()  # zone de la liste (coordonnées de l'écran)
var _rows: Array = []  # lignes de la liste, préparées à l'ouverture
var _count := 0
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
	# la liste se dessine dans un enfant qui découpe ce qui dépasse
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
	_build()
	visible = true


func _close() -> void:
	visible = false
	_holding = false
	_dragging = false
	closed.emit()


# ------------------------------------------------------------------ données

func _build() -> void:
	_rows.clear()
	var owned: Array = []
	if _powers != null:
		var lv: Dictionary = _powers.levels
		for id in lv.keys():
			if int(lv[id]) > 0 and Data.POWERS.has(String(id)):
				owned.append(String(id))
	_count = owned.size()
	if owned.is_empty():
		_rows.append({"kind": "empty"})
	for school in Data.SCHOOL_ORDER:
		var ids: Array = []
		for id in owned:
			var d: Dictionary = Data.POWERS[id]
			if String(d["school"]) == String(school):
				ids.append(id)
		if ids.is_empty():
			continue
		ids.sort_custom(_by_rarity)
		_rows.append({"kind": "head", "school": String(school)})
		for id in ids:
			_rows.append({"kind": "power", "info": _powers.recap_info(String(id))})
	var note := "2 pouvoirs d'une même école : un bonus. 4 pouvoirs : un bonus plus fort."
	if _powers != null and int(_powers.lvl("ink_rakkan")) > 0:
		note += " Ton Rakkan compte +1 dans chaque école commencée."
	_rows.append({"kind": "section", "title": "BONUS D'ÉCOLE", "note": note})
	for school in Data.SCHOOL_ORDER:
		if not Data.AFFINITY.has(String(school)):
			continue
		var st: Dictionary = {}
		if _powers != null:
			st = _powers.school_status(String(school))
		_rows.append({"kind": "school", "school": String(school), "st": st})
	_rows.append({"kind": "section", "title": "LEXIQUE", "note": ""})
	for lx in Data.LEXICON:
		_rows.append({"kind": "lex", "word": String(lx[0]), "def": String(lx[1])})


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
		var was_drag := _dragging
		_pressed = NO_TARGET
		_holding = false
		_dragging = false
		if was_drag:
			return
		var target := _target_at(mb.position)
		if target == BACK_TARGET and start == BACK_TARGET:
			_close()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _holding or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		accept_event()
		if not _dragging and absf(mm.position.y - _press_pos.y) > DRAG_START * _u:
			_dragging = true
			_pressed = NO_TARGET  # un glissé n'appuie sur rien
			_press_pos = mm.position
			_press_scroll = _scroll
		if _dragging:
			_scroll = _rubber(_press_scroll - (mm.position.y - _press_pos.y))
			_drag_accum += mm.relative.y


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


# ------------------------------------------------------------------ dessin

## Carte (qui glisse un peu à l'ouverture) et zone de la liste.
func _layout() -> void:
	var w := size.x
	var h := size.y
	_u = minf(w / 400.0, h / 760.0)
	var u := _u
	var ch := minf(h - 40.0 * u, 720.0 * u)
	_card = Rect2(Vector2(w * 0.05, h * 0.5 - ch / 2.0 + 14 * u * (1.0 - UiKit.ease_out(_t / 0.3))), Vector2(w * 0.9, ch))
	_view = Rect2(Vector2(_card.position.x + 10 * u, _card.position.y + 92 * u), Vector2(_card.size.x - 20 * u, _card.size.y - 102 * u))
	_list.position = _view.position
	_list.size = _view.size
	_list.modulate.a = clampf(_t / 0.25, 0.0, 1.0)


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
	var bc := card.position + Vector2(34, 40) * u
	_back = Rect2(bc - Vector2(26, 26) * u, Vector2(52, 52) * u)
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
	var y := -_scroll + 2 * u
	for row in _rows:
		var rd: Dictionary = row
		var kind := String(rd["kind"])
		var h := 0.0
		match kind:
			"empty":
				h = _row_empty(y, W, u)
			"head":
				h = _row_head(y, W, u, String(rd["school"]))
			"power":
				h = _row_power(y, W, u, rd["info"])
			"section":
				h = _row_section(y, W, u, String(rd["title"]), String(rd["note"]))
			"school":
				h = _row_school(y, W, u, String(rd["school"]), rd["st"])
			"lex":
				h = _row_lex(y, W, u, String(rd["word"]), String(rd["def"]))
		y += h
	_content_h = y + _scroll + 12 * u
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
		var k := clampf(_scroll / maxf(1.0, _max_scroll()), 0.0, 1.0)
		_list.draw_rect(Rect2(Vector2(W - 3 * u, (vh - th) * k), Vector2(2.5 * u, th)), Color(Toon.SUMI, 0.25))


## Aucun pouvoir : une phrase pour dire comment en obtenir.
func _row_empty(y: float, W: float, u: float) -> float:
	UiKit.text(_list, UiKit.TITLE_FONT, "Aucun pouvoir pour l'instant", Vector2(W / 2.0, y + 30 * u), int(15 * u), Color(Toon.SUMI, 0.8))
	UiKit.text(_list, _ui, "Gagne un niveau pour choisir ton premier rouleau.", Vector2(W / 2.0, y + 50 * u), int(10 * u), Color(Toon.SUMI, 0.55))
	return 66 * u


## En-tête d'école : pastille au pictogramme de l'école, nom, filet de la couleur de l'école.
func _row_head(y: float, W: float, u: float, school: String) -> float:
	var sd: Dictionary = Data.SCHOOLS[school]
	var col: Color = sd["color"]
	var hc := Vector2(17 * u, y + 21 * u)
	_list.draw_circle(hc, 12 * u, col)
	UiKit.school_icon(_list, school, hc, 7.5 * u, Toon.WASHI, 1.0, col)
	var nm := String(sd["name"])
	var nfs := int(14 * u)
	_list.draw_string(_title, Vector2(36 * u, y + 27 * u), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Toon.SUMI)
	var nw := _title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	_list.draw_line(Vector2(36 * u + nw + 10 * u, y + 22 * u), Vector2(W - 6 * u, y + 22 * u), Color(col, 0.45), 2 * u)
	return 38 * u


## Un pouvoir : sceau (école, liseré de rareté, niveau), nom + sous-titre, déclencheur, effet chiffré actuel.
func _row_power(y: float, W: float, u: float, info: Dictionary) -> float:
	var x0 := 6.0 * u
	var tx := x0 + 46.0 * u
	var tw := W - tx - 8.0 * u
	var rank := int(info.get("rarity_rank", 0))
	var rc: Color = info.get("rarity_color", Toon.SUMI)
	# pastille : pictogramme du pouvoir sur la couleur d'école
	var sc := Vector2(x0 + 20 * u, y + 24 * u)
	var sr := 16.0 * u
	if rank >= 2:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		_list.draw_circle(sc, sr + 5 * u, Color(rc, 0.18 + 0.12 * pulse))
	_list.draw_circle(sc, sr + 2.5 * u, rc)
	UiKit.power_icon(_list, String(info.get("id", "")), sc, sr)
	# niveau sous le sceau : losanges, ou « UNIQUE »
	var lv := int(info.get("level", 1))
	var mx := int(info.get("max_level", 3))
	if mx > 1:
		for k in mx:
			var dc := sc + Vector2((float(k) - float(mx - 1) / 2.0) * 11 * u, sr + 10 * u)
			var ds := 3.6 * u
			var dia := PackedVector2Array([dc + Vector2(0, -ds), dc + Vector2(ds, 0), dc + Vector2(0, ds), dc + Vector2(-ds, 0)])
			if k < lv:
				_list.draw_colored_polygon(dia, Toon.SUMI)
			else:
				var dd := dia.duplicate()
				dd.append(dia[0])
				_list.draw_polyline(dd, Color(Toon.SUMI, 0.35), 1.2 * u, true)
	else:
		UiKit.text(_list, _ui, "UNIQUE", Vector2(sc.x, sc.y + sr + 14 * u), int(7.5 * u), GOLD_INK if rank >= 3 else Color(Toon.SUMI, 0.6))
	# nom (et sous-titre à côté s'il tient, sinon dessous)
	var by := y + 18 * u
	var nfs := int(15 * u)
	# nom court (celui du HUD et des cartes), puis le nom japonais s'il diffère, sinon le sous-titre
	var pid := String(info.get("id", ""))
	var jp := _p(String(info.get("name", "")))
	var nm := UiKit.power_label(pid) if pid != "" else jp
	_list.draw_string(UiKit.TITLE_FONT, Vector2(tx, by), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, GOLD_INK if rank >= 3 else Toon.SUMI)
	var nw := UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var sub := jp if jp != nm else _p(String(info.get("sub", "")))
	var sfs := int(10 * u)
	if sub != "":
		var sw := _ui.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		if nw + 8 * u + sw <= tw:
			_list.draw_string(_ui, Vector2(tx + nw + 8 * u, by), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(Toon.SUMI, 0.5))
		else:
			by += 13 * u
			_list.draw_string(_ui, Vector2(tx, by), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(Toon.SUMI, 0.5))
	# déclencheur (pastille d'encre) puis la valeur actuelle, à côté si elle tient
	var cy := by + 7 * u
	var chip_h := 15.0 * u
	var wfs := int(8 * u)
	var when := _p(String(info.get("when", "")))
	var chip_w := 0.0
	if when != "":
		chip_w = _ui.get_string_size(when, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs).x + 16 * u
		var chip := Rect2(Vector2(tx, cy), Vector2(chip_w, chip_h))
		_list.draw_style_box(UiKit.box(_sb, Toon.SUMI, 999), chip)
		_list.draw_circle(Vector2(chip.position.x + 6.5 * u, chip.get_center().y), 2.0 * u, Toon.VERMILION)
		_list.draw_string(_ui, Vector2(chip.position.x + 11 * u, cy + chip_h * 0.5 + wfs * 0.36), when, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, Toon.WASHI)
	var stat := _p(String(info.get("stat", "")))
	var stfs := int(11 * u)
	var accent := Toon.VERMILION.darkened(0.12)
	var sy := cy + chip_h * 0.5 + stfs * 0.36
	if stat != "":
		var stw := _ui.get_string_size(stat, HORIZONTAL_ALIGNMENT_LEFT, -1, stfs).x
		if chip_w > 0.0 and chip_w + 8 * u + stw <= tw:
			_bold(stat, Vector2(tx + chip_w + 8 * u, sy), stfs, accent)
		else:
			if chip_w > 0.0:
				sy = cy + chip_h + 13 * u
			var lines := _wrap(_ui, stat, stfs, tw)
			for k in mini(lines.size(), 2):
				if k > 0:
					sy += 14 * u
				_bold(lines[k], Vector2(tx, sy), stfs, accent)
	# synergie active
	var syn := _p(String(info.get("synergy", "")))
	if syn != "":
		sy += 14 * u
		_fit("+ " + syn, Vector2(tx, sy), tw, int(9.5 * u), GOLD_INK)
	var h := maxf(sy + 12 * u - y, 64 * u)
	# liseré de rareté à gauche et filet de séparation
	_list.draw_rect(Rect2(Vector2(0, y + 8 * u), Vector2(2.5 * u, h - 16 * u)), Color(rc, 0.85))
	_list.draw_line(Vector2(tx, y + h - 1.0), Vector2(W - 6 * u, y + h - 1.0), Color(Toon.SUMI, 0.08), 1.0)
	return h


## Titre de section (centré, trait vermillon) et courte explication.
func _row_section(y: float, W: float, u: float, title: String, note: String) -> float:
	UiKit.text(_list, _title, title, Vector2(W / 2.0, y + 36 * u), int(15 * u), Toon.SUMI)
	_list.draw_line(Vector2(W / 2.0 - 24 * u, y + 46 * u), Vector2(W / 2.0 + 24 * u, y + 46 * u), Toon.VERMILION, 2 * u)
	var yy := y + 50 * u
	if note != "":
		var lines := _wrap(_ui, _p(note), int(10 * u), W - 24 * u)
		for line in lines:
			yy += 13 * u
			UiKit.text(_list, _ui, String(line), Vector2(W / 2.0, yy), int(10 * u), Color(Toon.SUMI, 0.6))
	return yy - y + 12 * u


## Bonus d'une école : sceau, jauge (paliers 2 et 4), bonus actif en or, prochain bonus en gris.
func _row_school(y: float, W: float, u: float, school: String, st: Dictionary) -> float:
	var sd: Dictionary = Data.SCHOOLS[school]
	var col: Color = sd["color"]
	var n := int(st.get("count", 0))
	var al: float = 1.0 if n > 0 else 0.55
	var bc := Vector2(18 * u, y + 18 * u)
	_list.draw_circle(bc, 12.5 * u, Color(col, al))
	UiKit.school_icon(_list, school, bc, 7.8 * u, Toon.WASHI, al, Color(col, al))
	var tx := 40.0 * u
	var nm := String(sd["name"])
	var nfs := int(13 * u)
	var base := y + 22 * u
	_list.draw_string(_title, Vector2(tx, base), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(Toon.SUMI, al))
	# jauge : 4 crans, un petit écart marque le palier de 2
	var tiers: Array = Data.AFF_TIERS
	var top := int(tiers[tiers.size() - 1])
	var gx := tx + _title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x + 10 * u
	var cell := 10.0 * u
	for k in top:
		var extra: float = 4.0 * u if k >= int(tiers[0]) else 0.0
		var r := Rect2(Vector2(gx + k * (cell + 3 * u) + extra, base - cell + 1 * u), Vector2(cell, cell * 0.8))
		_list.draw_rect(r, col if k < n else Color(Toon.SUMI, 0.15))
	var cnt := "%d/%d" % [mini(n, top), top]
	_list.draw_string(_ui, Vector2(gx + top * (cell + 3 * u) + 10 * u, base), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Color(Toon.SUMI, 0.6 * al))
	var yy := base
	var fs := int(10 * u)
	var active := _p(String(st.get("active", "")))
	if active != "":
		for line in _wrap(_ui, "ACTIF : " + active, fs, W - tx - 6 * u):
			yy += 14 * u
			_list.draw_string(_ui, Vector2(tx, yy), String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD_INK)
	var nxt := _p(String(st.get("next", "")))
	if nxt != "":
		var need := int(st.get("next_at", 0))
		for line in _wrap(_ui, "À %d pouvoirs : %s" % [need, nxt], fs, W - tx - 6 * u):
			yy += 14 * u
			_list.draw_string(_ui, Vector2(tx, yy), String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.SUMI, 0.55))
	return yy - y + 14 * u


## Lexique : le mot à gauche, sa définition à droite.
func _row_lex(y: float, W: float, u: float, word: String, defn: String) -> float:
	var fs := int(10 * u)
	_list.draw_string(_ui, Vector2(8 * u, y + 14 * u), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Toon.VERMILION.darkened(0.12))
	var lines := _wrap(_ui, _p(defn), fs, W - 90 * u)
	for k in lines.size():
		_list.draw_string(_ui, Vector2(84 * u, y + 14 * u + k * 13 * u), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.SUMI, 0.75))
	return 14 * u + float(maxi(lines.size(), 1) - 1) * 13 * u + 12 * u


# ------------------------------------------------------------------ texte

## Coupe un texte en lignes qui tiennent dans `width` (mots entiers ; la ponctuation reste collée au mot).
func _wrap(font: Font, txt: String, fs: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in txt.split(" ", false):
		var wd := String(word)
		var trial: String = wd if cur == "" else cur + " " + wd
		var glue := wd == ":" or wd == ";" or wd == "!" or wd == "?" or wd == "%" or wd == "→" or wd == "·"
		if cur != "" and not glue and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			out.append(cur)
			cur = wd
		else:
			cur = trial
	if cur != "":
		out.append(cur)
	return out


## Une ligne qui rétrécit (un peu) si elle déborde.
func _fit(txt: String, pos: Vector2, maxw: float, fs: int, c: Color) -> void:
	var f := fs
	while f > 6 and _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > maxw:
		f -= 1
	_list.draw_string(_ui, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, c)


## Texte en gras (deux passes décalées).
func _bold(txt: String, pos: Vector2, fs: int, c: Color) -> void:
	_list.draw_string(_ui, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	_list.draw_string(_ui, pos + Vector2(0.7, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
