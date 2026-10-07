extends Control
## Atelier : la pièce du peintre. Mur de bois sombre, tatami, enseigne gravée, trois onglets :
## - Améliorations : six rouleaux suspendus (kakejiku) = les six lignes de la Pierre à encre (encre) ;
## - Sceaux : dons permanents, cartes de papier dans une liste qui glisse au doigt ;
## - Estampes : la collection des Vues, petites estampes illustrées ; chacune offre une apparence.
## Toucher choisit (le bandeau du bas explique), toucher encore confirme : un sceau vermillon s'imprime.
## Retour : ensō d'encre en haut à gauche.

const Toon = preload("res://scripts/toon.gd")
const Meta = preload("res://scripts/meta.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/power_data.gd")

const WOOD := Color("#2A201B")
const WOOD_LINE := Color("#3A2D26")
const ROD := Color("#4A3426")
const LOCKED := Color("#9A928A")
const GOLD_INK := Color("#9A6B12")  # or lisible sur le papier
const LABEL := Color("#D9C79C")  # texte clair sur le bois
const DRAG_START := 8.0  # glissé minimal (× u) avant de faire défiler
# « brush » prend la couleur par défaut, Toon.PRUSSIAN (voir _scroll_art)
const LINE_COLORS := {
	"ink": Color("#2C2A33"),
	"paper": Color("#9E2A22"),
	"breath": Color("#3F6B67"),
	"purse": Color("#8C6A2A"),
	"choice": Color("#4E3A63"),
}
# pictogrammes des dons des sceaux (les légendaires prennent celui de leur pouvoir)
const SEAL_GLYPHS := {"reroll": "reroll", "scroll": "scroll", "purse": "coin", "blessing": "cards", "hp": "kintsugi"}
const TABS := ["AMÉLIORATIONS", "SCEAUX", "ESTAMPES"]
const KIND_LABELS := {"cape": "ÉCHARPE", "trail": "SILLAGE", "ink": "ENCRE"}

signal closed

var meta  # instance de meta.gd, fournie par main avant open()

var _t := 0.0
var _tab_t := 0.0  # temps depuis le dernier changement d'onglet
var _u := 1.0
var _tab := 0
var _sel := ""  # cible choisie (« line:2 », « seal:scroll », « print:w1_room ») : le toucher suivant confirme
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
var _hits: Array = []  # [Rect2, cible] dessinés par l'Atelier
var _list_hits: Array = []  # [Rect2 (écran), cible] dessinés dans la liste
var _stamp_key := ""
var _stamp := 0.0  # sceau qui s'imprime (1 -> 0)
var _shake_key := ""
var _shake := 0.0  # refus (1 -> 0)
var _bump := 0.0
var _bump_i := 0  # compteur qui s'illumine (0 encre, 1 sceaux, 2 Vues)
var _msg := ""
var _msg2 := ""
var _msg_t := 0.0
var _back_rect := Rect2()
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _tabf := FontVariation.new()
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 8
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 2
	_tabf.base_font = UiKit.UI_FONT
	_tabf.spacing_glyph = 1
	# les listes (sceaux, estampes) se dessinent dans un enfant qui découpe ce qui dépasse
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.clip_contents = true
	_list.visible = false
	add_child(_list)
	_list.draw.connect(_draw_list)


func open() -> void:
	_t = 0.0
	_tab_t = 0.0
	_sel = ""
	_pressed = ""
	_holding = false
	_dragging = false
	_bump = 0.0
	_stamp = 0.0
	_shake = 0.0
	_msg_t = 0.0
	_scroll = 0.0
	_vel = 0.0
	_content_h = 0.0
	_hits.clear()
	_list_hits.clear()
	visible = true


func _close() -> void:
	visible = false
	_holding = false
	_dragging = false
	closed.emit()


func _p(s: String) -> String:
	return UiKit.plain(s)


# ------------------------------------------------------------------ entrée

func _target_at(p: Vector2) -> String:
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
			if mb.pressed and _tab > 0 and _t >= 0.3:
				var dir: float = -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				_scroll = clampf(_scroll + dir * 60.0 * _u, 0.0, _max_scroll())
				_vel = 0.0
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			# le toucher qui a ouvert l'atelier ne doit ni le refermer ni acheter
			_pressed = _target_at(mb.position) if _t >= 0.3 else ""
			if _t < 0.6 and _pressed.begins_with("line:"):
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
			if _tab == 0 or not _view.has_point(_press_pos) or absf(mm.position.y - _press_pos.y) <= DRAG_START * _u:
				return
			_dragging = true
			_pressed = ""  # un glissé n'appuie sur rien
			_press_pos = mm.position
			_press_scroll = _scroll
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


func _tap(key: String) -> void:
	if key == "back":
		_close()
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
	if key == "prev" or key == "next":
		meta.cycle_start_power(-1 if key == "prev" else 1)
		_sel = "seal:scroll"
		_msg_t = 0.0
		return
	if key != _sel:
		# premier toucher : on choisit ; hors de portée, le refus se voit tout de suite
		_sel = key
		_msg_t = 0.0
		if not _can_confirm(key):
			_shake_key = key
			_shake = 1.0
		return
	_confirm(key)


## Vrai si un second toucher ferait quelque chose (acheter, sceller, porter).
func _can_confirm(key: String) -> bool:
	var kind := key.get_slice(":", 0)
	var id := key.get_slice(":", 1)
	match kind:
		"line":
			var lid: String = Meta.ORDER[int(id)]
			var ok: bool = meta.can_buy(lid)
			return ok
		"seal":
			var ok2: bool = meta.can_buy_seal(id) or meta.owns_seal(id)
			return ok2
		"print":
			var ok3: bool = meta.has_print(id)
			return ok3
	return false


func _confirm(key: String) -> void:
	var kind := key.get_slice(":", 0)
	var id := key.get_slice(":", 1)
	match kind:
		"line":
			var lid: String = Meta.ORDER[int(id)]
			if meta.buy(lid):
				var line: Dictionary = Meta.LINES[lid]
				var r: int = meta.rank(lid)
				_flash(0, key, "%s · rang %d" % [String(line["name"]), r], "Acquis : %s." % String(meta.effect_text(lid, r)))
			else:
				_refuse(key)
		"seal":
			if meta.owns_seal(id):
				_sel = ""
				return
			if meta.buy_seal(id):
				var it: Dictionary = Meta.SEAL_ITEMS[id]
				var more := " Choisis ton rouleau avec les flèches." if id == "scroll" else ""
				_flash(1, key, String(it["name"]), "Scellé pour toujours." + more)
			else:
				_refuse(key)
		"print":
			if not meta.has_print(id):
				_refuse(key)
				return
			var p: Dictionary = Meta.PRINTS[id]
			var look_kind := String(p["kind"])
			if meta.toggle_look(id):
				_flash(2, key, String(p["look"]), "Portée dès maintenant, et à chaque partie.")
			else:
				_flash(2, key, "%s d'origine" % String(Meta.LOOK_NAMES[look_kind]), "Tu ne portes plus : %s." % String(p["look"]))


## Achat réussi : sceau imprimé, compteur qui s'illumine, message dans le bandeau.
func _flash(counter: int, key: String, title: String, detail: String) -> void:
	_stamp_key = key
	_stamp = 1.0
	_bump = 1.0
	_bump_i = counter
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
	_bump = maxf(0.0, _bump - real * 3.0)
	_stamp = maxf(0.0, _stamp - real * 1.6)
	_shake = maxf(0.0, _shake - real * 2.5)
	_msg_t = maxf(0.0, _msg_t - real)
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


func _layout() -> void:
	var w := size.x
	var h := size.y
	_u = minf(w / 400.0, h / 780.0)
	var u := _u
	var top := 210.0 * u
	_view = Rect2(Vector2(14 * u, top), Vector2(w - 28 * u, maxf(10.0, h * 0.8 - top - 6 * u)))
	_list.position = _view.position
	_list.size = _view.size
	_list.visible = _tab > 0
	_list.modulate.a = UiKit.ease_out(_tab_t / 0.3)


func _to_screen(r: Rect2) -> Rect2:
	return Rect2(r.position + _view.position, r.size)


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	var u := _u
	_hits.clear()
	_draw_room(w, h, u)
	_draw_sign(w, u)
	_draw_counters(w, u)
	_draw_tabs(w, u)
	if _tab == 0:
		_draw_scrolls(w, h, u)
	_draw_banner(w, h, u)
	_draw_suzuri(w, h, u)
	_draw_back(u)


## Mur de planches sombres, poutre, et tatami au sol.
func _draw_room(w: float, h: float, u: float) -> void:
	draw_rect(Rect2(0, 0, w, h), WOOD)
	var x := 0.0
	var i := 0
	while x < w:
		var pw := 46.0 * u + float(i % 3) * 9.0 * u
		draw_rect(Rect2(x, 0, 1.5 * u, h * 0.8), WOOD_LINE)
		# veinage
		for k in 3:
			var yy := fmod(float(i * 97 + k * 211), h * 0.8)
			draw_line(Vector2(x + pw * 0.3 + k * 6 * u, yy), Vector2(x + pw * 0.35 + k * 6 * u, yy + 60 * u), Color(WOOD_LINE, 0.6), 1.0 * u)
		x += pw
		i += 1
	# poutre haute
	draw_rect(Rect2(0, 0, w, 14 * u), Color("#1E1713"))
	draw_rect(Rect2(0, 14 * u, w, 3 * u), Color("#5A4232"))
	# tatami
	var ty := h * 0.8
	draw_rect(Rect2(0, ty, w, h - ty), Color("#BFAE7A"))
	draw_rect(Rect2(0, ty, w, 6 * u), Color("#2E3B2C"))
	var tx := 0.0
	while tx < w:
		draw_line(Vector2(tx, ty), Vector2(tx - 30 * u, h), Color("#A8975F"), 1.0 * u)
		tx += 9.0 * u
	draw_rect(Rect2(w * 0.5 - 3 * u, ty, 6 * u, h - ty), Color("#2E3B2C"))
	# lumière douce venue d'une fenêtre (shoji) à droite
	draw_colored_polygon(PackedVector2Array([Vector2(w, 40 * u), Vector2(w, h * 0.8), Vector2(w * 0.55, h * 0.8), Vector2(w * 0.75, 40 * u)]),
		Color(1.0, 0.92, 0.75, 0.05))


## Enseigne de bois gravée, suspendue à la poutre.
func _draw_sign(w: float, u: float) -> void:
	var a := UiKit.ease_out(_t / 0.5)
	var sw := 236.0 * u
	var sh := 62.0 * u
	var sy := 34.0 * u - 20.0 * u * (1.0 - a)
	var sx := (w - sw) / 2.0
	var sway := sin(_t * 1.3) * 0.6 * u
	for side in [-1.0, 1.0]:
		draw_line(Vector2(w / 2.0 + side * sw * 0.32, 14 * u), Vector2(w / 2.0 + side * sw * 0.32 + sway, sy), Color("#C9B48A", a), 1.5 * u)
	var plank := Rect2(Vector2(sx + sway, sy), Vector2(sw, sh))
	UiKit.box(_sb, Color(Color("#6B4A2E"), a), int(4 * u), Color(Color("#3B281A"), a), int(3 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.35 * a)
	_sb.shadow_size = int(8 * u)
	_sb.shadow_offset = Vector2(0, 4) * u
	draw_style_box(_sb, plank)
	for k in 4:
		draw_line(plank.position + Vector2(10 * u, 12 * u + k * 12 * u), plank.position + Vector2(sw - 10 * u, 14 * u + k * 12 * u), Color(Color("#7A5636"), 0.5 * a), 1.0 * u)
	var fs := int(30 * u)
	var txt := "ATELIER"
	var tw := _title.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(plank.get_center().x - tw / 2.0 - 10 * u, plank.get_center().y + fs * 0.36)
	draw_string(_title, tp + Vector2(0, 1.5 * u), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.45 * a))
	draw_string(_title, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color("#EBD9B0"), a))
	# petit sceau vermillon cloué sur l'enseigne
	var seal := Rect2(Vector2(plank.end.x - 34 * u, plank.get_center().y - 11 * u), Vector2(22, 22) * u)
	draw_rect(seal, Color(Toon.VERMILION, a))
	var kfs := int(15 * u)
	var kw := UiKit.TITLE_FONT.get_string_size("墨", HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
	draw_string(UiKit.TITLE_FONT, Vector2(seal.get_center().x - kw / 2.0, seal.get_center().y + kfs * 0.36), "墨", HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(Toon.WASHI, a))


## Encre, sceaux, Vues : trois étiquettes de bois.
func _draw_counters(w: float, u: float) -> void:
	if meta == null:
		return
	var a := UiKit.ease_out((_t - 0.15) / 0.5)
	var y := 118.0 * u
	var items := [["ink", str(meta.sumi)], ["seal", str(meta.seals)], ["print", "%d/%d" % [int(meta.prints), Meta.MAX_PRINTS]]]
	var tw := 100.0 * u
	var gap := 10.0 * u
	var x0 := (w - (tw * 3 + gap * 2)) / 2.0
	for i in items.size():
		var r := Rect2(Vector2(x0 + i * (tw + gap), y), Vector2(tw, 34 * u))
		var lit := _bump > 0.0 and i == _bump_i
		draw_style_box(UiKit.box(_sb, Color(Toon.PAPER, 0.95 * a), int(17 * u), Color(Toon.GOLD, 0.8 * a), int(1.5 * u)), r)
		var ic := r.position + Vector2(20 * u, r.size.y / 2.0)
		var grow := 1.0 + (0.3 * _bump if lit else 0.0)
		match String(items[i][0]):
			"ink":
				_stick(ic, 11.0 * u * grow, a)
			"seal":
				_seal_icon(self, ic, 7.0 * u * grow, a, false)
			_:
				_print_icon(ic, u * grow, a)
		var fs := int(16 * u)
		var col := Toon.GOLD if lit else Toon.SUMI
		draw_string(_ui, r.position + Vector2(36 * u, r.size.y / 2.0 + fs * 0.36), String(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))


## Trois onglets : Améliorations (encre), Sceaux, Estampes. Pastille vermillon : un achat est à portée.
func _draw_tabs(w: float, u: float) -> void:
	if meta == null:
		return
	var a := UiKit.ease_out((_t - 0.2) / 0.5)
	var fs := int(11 * u)
	var y := 164.0 * u
	var hgt := 30.0 * u
	var gap := 6.0 * u
	var widths: Array = []
	var total := 0.0
	for lb in TABS:
		var tw := _tabf.get_string_size(_p(String(lb)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 26.0 * u
		widths.append(tw)
		total += tw
	total += gap * (TABS.size() - 1)
	var x := (w - total) / 2.0
	for i in TABS.size():
		var tw2: float = widths[i]
		var key := "tab:%d" % i
		var r := Rect2(Vector2(x, y), Vector2(tw2, hgt))
		x += tw2 + gap
		_hits.append([r, key])
		var active := i == _tab
		var rr := r.grow(-1.5 * u) if _pressed == key else r
		if active:
			UiKit.box(_sb, Color(Toon.PAPER, a), int(15 * u), Color(Toon.GOLD, a), int(1.5 * u))
		else:
			UiKit.box(_sb, Color(Color("#3A2D26"), 0.95 * a), int(15 * u), Color(Color("#5A4232"), a), int(1.5 * u))
		draw_style_box(_sb, rr)
		UiKit.text(self, _tabf, _p(String(TABS[i])), Vector2(rr.get_center().x, rr.get_center().y + fs * 0.36), fs, Color(Toon.SUMI if active else LABEL, a))
		if active:
			draw_line(Vector2(rr.get_center().x - 14 * u, rr.end.y + 4 * u), Vector2(rr.get_center().x + 14 * u, rr.end.y + 4 * u), Color(Toon.VERMILION, a), 2.0 * u)
		var dot := false
		if i == 0:
			dot = meta.any_affordable()
		elif i == 1:
			dot = meta.any_seal_affordable()
		if dot:
			draw_circle(Vector2(rr.end.x - 5 * u, rr.position.y + 4 * u), 4.0 * u, Color(Toon.VERMILION, a))


## Six rouleaux suspendus, deux rangées de trois.
func _draw_scrolls(w: float, h: float, u: float) -> void:
	if meta == null:
		return
	var cols := 3
	var sw := minf(112.0 * u, (w - 40 * u) / 3.0 - 8 * u)
	var gap := (w - sw * cols) / (cols + 1)
	var top := 226.0 * u
	var sh := minf(250.0 * u, (h * 0.8 - top - 30 * u) / 2.0 - 12 * u)
	for i in Meta.ORDER.size():
		var col := i % cols
		var row := i / cols
		var unroll := UiKit.ease_out((_tab_t - 0.1 - 0.07 * i) / 0.5)
		var r := Rect2(Vector2(gap + col * (sw + gap), top + row * (sh + 22 * u)), Vector2(sw, sh))
		var key := "line:%d" % i
		_hits.append([r, key])
		var shake := sin(_t * 60.0) * 4.0 * u * (_shake if _shake_key == key else 0.0)
		var sway := sin(_t * 1.1 + i * 0.9) * 1.2 * u
		_scroll_art(i, r, unroll, shake + sway, u)


func _scroll_art(i: int, r: Rect2, unroll: float, dx: float, u: float) -> void:
	var id: String = Meta.ORDER[i]
	var key := "line:%d" % i
	var line: Dictionary = Meta.LINES[id]
	var mount: Color = LINE_COLORS.get(id, Toon.PRUSSIAN)
	var rank: int = meta.rank(id)
	var maxr: int = meta.max_rank(id)
	var cost: int = meta.cost(id)
	var maxed := cost < 0
	var afford: bool = meta.can_buy(id)
	var pressed := _pressed == key
	var sel := _sel == key
	var x := r.position.x + dx
	var y := r.position.y
	var wdt := r.size.x
	var full_h := r.size.y
	var hgt := maxf(8.0 * u, full_h * unroll)
	var s := 0.97 if pressed else 1.0
	if s < 1.0:
		x += wdt * (1.0 - s) / 2.0
		wdt *= s
	# cordon et clou
	draw_line(Vector2(x + wdt / 2.0, y - 18 * u), Vector2(x + wdt * 0.25, y), Color("#C9B48A"), 1.2 * u)
	draw_line(Vector2(x + wdt / 2.0, y - 18 * u), Vector2(x + wdt * 0.75, y), Color("#C9B48A"), 1.2 * u)
	draw_circle(Vector2(x + wdt / 2.0, y - 18 * u), 2.5 * u, Toon.GOLD)
	# ombre portée sur le mur
	draw_rect(Rect2(x + 5 * u, y + 6 * u, wdt, hgt), Color(0, 0, 0, 0.35))
	# rouleau choisi : liseré d'or autour de la monture
	if sel:
		draw_rect(Rect2(x - 4 * u, y - 2 * u, wdt + 8 * u, hgt + 4 * u), Color(Toon.GOLD, 0.6 + 0.4 * sin(_t * 6.0)), false, 2.5 * u)
	# monture de soie (couleur de la ligne) puis papier
	draw_rect(Rect2(x, y, wdt, hgt), mount)
	var pad := 7.0 * u
	var paper := Rect2(x + pad, y + 16 * u, wdt - pad * 2, maxf(0.0, hgt - 32 * u))
	if paper.size.y > 2.0:
		draw_rect(paper, Toon.PAPER)
		# bandes fūtai qui pendent du haut
		draw_rect(Rect2(x + wdt * 0.3, y, 5 * u, minf(30 * u, hgt * 0.3)), Color(mount.darkened(0.3), 0.9))
		draw_rect(Rect2(x + wdt * 0.7 - 5 * u, y, 5 * u, minf(30 * u, hgt * 0.3)), Color(mount.darkened(0.3), 0.9))
	# baguettes de bois en haut et en bas, embouts dorés
	_rod(Vector2(x - 4 * u, y - 4 * u), wdt + 8 * u, u)
	_rod(Vector2(x - 6 * u, y + hgt - 4 * u), wdt + 12 * u, u)
	if unroll < 0.6 or paper.size.y < 40 * u:
		return
	var c := paper.get_center().x
	var a := clampf((unroll - 0.6) / 0.4, 0.0, 1.0)
	# idéogramme au pinceau
	var ky := paper.position.y + 44 * u
	UiKit.text(self, UiKit.TITLE_FONT, String(line["kanji"]), Vector2(c, ky), int(38 * u), Color(Toon.SUMI, (0.35 if maxed else 1.0) * a))
	# nom et effet (au prochain rang)
	UiKit.text(self, UiKit.TITLE_FONT, _p(String(line["name"])), Vector2(c, ky + 20 * u), int(13 * u), Color(Toon.SUMI, a))
	var eff: String = meta.effect_text(id)
	draw_multiline_string(UiKit.UI_FONT, Vector2(paper.position.x + 4 * u, ky + 34 * u), _p(eff), HORIZONTAL_ALIGNMENT_CENTER, paper.size.x - 8 * u, int(10 * u), 2, Color(Toon.SUMI, 0.65 * a))
	# rang : petits traits d'encre verticaux
	var dx0 := c - (maxr - 1) * 5.0 * u
	for k in maxr:
		var p := Vector2(dx0 + k * 10.0 * u, ky + 64 * u)
		var on := k < rank
		draw_rect(Rect2(p - Vector2(2.5, 6) * u, Vector2(5, 12) * u), Color(mount, a) if on else Color(Toon.SUMI, 0.18 * a))
	# prix : un sceau en bas du rouleau (il bat doucement quand le rouleau est choisi)
	var py := paper.end.y - 18 * u
	if maxed:
		UiKit.text(self, _ui, "MAX", Vector2(c, py + 4 * u), int(13 * u), Color(Toon.GOLD, a))
	else:
		var k2 := 1.0 + (0.07 * sin(_t * 8.0) if sel and afford else 0.0)
		var tag := Rect2(Vector2(c - 34 * u * k2, py - 12 * u * k2), Vector2(68, 24) * u * k2)
		draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION if afford else LOCKED, a), int(3 * u)), tag)
		_stick(tag.position + Vector2(13 * u, tag.size.y / 2.0), 8.0 * u, a, true)
		var pfs := int(13 * u)
		draw_string(_ui, tag.position + Vector2(24 * u, tag.size.y / 2.0 + pfs * 0.36), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(Toon.WASHI, a))
	# achat : un grand sceau vermillon tamponné sur le papier
	if _stamp_key == key and _stamp > 0.0:
		_stamp_fx(self, Vector2(c, paper.position.y + paper.size.y * 0.42), str(rank), u)


func _rod(p: Vector2, wdt: float, u: float) -> void:
	draw_rect(Rect2(p, Vector2(wdt, 8 * u)), ROD)
	draw_rect(Rect2(p + Vector2(0, 1.5 * u), Vector2(wdt, 2 * u)), Color("#6A4C38"))
	draw_rect(Rect2(p - Vector2(4 * u, 1 * u), Vector2(5 * u, 10 * u)), Toon.GOLD)
	draw_rect(Rect2(p + Vector2(wdt - 1 * u, -1 * u), Vector2(5 * u, 10 * u)), Toon.GOLD)


## Bâton d'encre (sumi) avec liseré or.
func _stick(c: Vector2, s: float, a: float, light := false) -> void:
	var r := Rect2(c - Vector2(s * 0.35, s), Vector2(s * 0.7, s * 2.0))
	draw_rect(r, Color(Toon.WASHI if light else Toon.SUMI, a))
	draw_rect(r, Color(Toon.GOLD, a), false, maxf(1.0, s * 0.12))


## Sceau carré (hanko) : vermillon sur papier, ou papier sur une étiquette vermillon (light).
func _seal_icon(ci: CanvasItem, c: Vector2, s: float, a: float, light: bool) -> void:
	var outer := Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0)
	ci.draw_rect(outer, Color(Toon.WASHI if light else Toon.VERMILION, a))
	ci.draw_rect(outer.grow(-s * 0.45), Color(Toon.VERMILION if light else Toon.WASHI, 0.6 * a), false, maxf(1.0, s * 0.17))


## Petite estampe : papier, Fuji bleu.
func _print_icon(c: Vector2, u: float, a: float) -> void:
	var r := Rect2(c - Vector2(6, 8) * u, Vector2(12, 16) * u)
	draw_rect(r, Color(Toon.WASHI, a))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 5) * u, c + Vector2(-1, -2) * u, c + Vector2(1, -2) * u, c + Vector2(5, 5) * u]), Color(Toon.PRUSSIAN, a))
	draw_rect(r, Color(Toon.SUMI, a), false, 1.2 * u)


## Sceau tamponné (achat, apparence portée) : grand carré vermillon qui se pose puis s'efface.
func _stamp_fx(ci: CanvasItem, c: Vector2, txt: String, u: float) -> void:
	var st := _stamp
	var k2 := 1.0 - st
	var size_k := 1.0 + 0.8 * maxf(0.0, 1.0 - k2 * 5.0)
	var half := 24.0 * u * size_k
	ci.draw_rect(Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0), Color(Toon.VERMILION, 0.85 * st), false, 4.0 * u)
	if txt != "":
		var fs := int(24 * u * size_k)
		UiKit.text(ci, UiKit.TITLE_FONT, txt, Vector2(c.x, c.y + fs * 0.36), fs, Color(Toon.VERMILION, 0.85 * st))


## Bandeau de papier sur le tatami : ce que fait le choix en cours, ou le dernier achat.
func _draw_banner(w: float, h: float, u: float) -> void:
	if meta == null:
		return
	var a := UiKit.ease_out((_t - 0.3) / 0.4)
	var r := Rect2(Vector2(16 * u, h * 0.8 + 8 * u), Vector2(w - 32 * u, 76 * u))
	var info := _banner_info()
	var title := String(info[0])
	var detail := String(info[1])
	var lit: bool = info[2]
	UiKit.box(_sb, Color(Toon.PAPER, 0.97 * a), int(10 * u), Color(Toon.GOLD if lit else Color("#3B281A"), a), int(2 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.35 * a)
	_sb.shadow_size = int(6 * u)
	_sb.shadow_offset = Vector2(0, 3) * u
	draw_style_box(_sb, r)
	draw_rect(Rect2(r.position + Vector2(12, 12) * u, Vector2(5, 18) * u), Color(Toon.VERMILION, a))
	draw_string(UiKit.TITLE_FONT, r.position + Vector2(25 * u, 26 * u), _p(title), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36 * u, int(14 * u), Color(GOLD_INK if lit else Toon.SUMI, a))
	draw_multiline_string(UiKit.UI_FONT, r.position + Vector2(25 * u, 43 * u), _p(detail), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36 * u, int(10 * u), 3, Color(Toon.SUMI, 0.72 * a))


## [titre, détail, message d'achat ?]
func _banner_info() -> Array:
	if _msg_t > 0.0:
		return [_msg, _msg2, true]
	if _sel != "":
		var kind := _sel.get_slice(":", 0)
		var id := _sel.get_slice(":", 1)
		match kind:
			"line":
				return _line_info(String(Meta.ORDER[int(id)]))
			"seal":
				return _seal_info(id)
			"print":
				return _print_info(id)
	match _tab:
		1:
			return ["Sceaux", "Gardien vaincu +1, boss +2 ; à la victoire, +1 par malédiction portée (3 au plus). Chaque don est acquis pour toujours.", false]
		2:
			return ["Les Vues", "Une estampe par exploit dans chaque monde. Chacune offre une couleur d'écharpe, de sillage ou d'encre : touche-la, puis touche encore pour la porter.", false]
	return ["Pierre à encre", "L'encre se gagne à chaque partie. Touche un rouleau pour voir son effet, puis touche encore pour l'acheter.", false]


func _line_info(lid: String) -> Array:
	var line: Dictionary = Meta.LINES[lid]
	var r: int = meta.rank(lid)
	var mx: int = meta.max_rank(lid)
	var title := "%s · rang %d/%d" % [String(line["name"]), r, mx]
	if r >= mx:
		return [title, "Rang maximum atteint : %s." % String(meta.effect_text(lid, r)), false]
	var c: int = meta.cost(lid)
	var have: int = meta.sumi
	var detail := ""
	if r > 0:
		detail = "Actuel : %s. " % String(meta.effect_text(lid, r))
	detail += "Prochain rang : %s. " % String(meta.effect_text(lid))
	if have >= c:
		detail += "Touche encore pour acheter (%d encre)." % c
	else:
		detail += "Il manque %d encre." % (c - have)
	return [title, detail, false]


func _seal_info(id: String) -> Array:
	var it: Dictionary = Meta.SEAL_ITEMS[id]
	var title := String(it["name"])
	var detail := String(it["text"])
	if meta.owns_seal(id):
		if id == "scroll":
			detail = "Tu commences chaque partie avec : %s. Change-le avec les flèches." % _power_name(String(meta.start_power()))
		else:
			detail += " Acquis."
		return [title, detail, false]
	var c: int = meta.seal_cost(id)
	var have: int = meta.seals
	if have >= c:
		detail += " Touche encore pour sceller (%d sceau%s)." % [c, "x" if c > 1 else ""]
	else:
		var miss := c - have
		detail += " Il manque %d sceau%s." % [miss, "x" if miss > 1 else ""]
	return [title, detail, false]


func _print_info(id: String) -> Array:
	var p: Dictionary = Meta.PRINTS[id]
	var n := Meta.PRINT_ORDER.find(id) + 1
	if meta.has_print(id):
		var title := "Vue %d · %s" % [n, String(p["name"])]
		if meta.is_worn(id):
			return [title, "%s, portée. Touche encore pour l'ôter." % String(p["look"]), false]
		return [title, "Offre : %s. Touche encore pour la porter." % String(p["look"]), false]
	return ["Vue %d · encore cachée" % n, "%s Elle offre : %s." % [String(meta.print_how(id)), String(p["look"])], false]


func _power_name(id: String) -> String:
	if not Data.POWERS.has(id):
		return "aucun"
	var d: Dictionary = Data.POWERS[id]
	return String(d["name"])


## Sur le tatami : la pierre à encre (suzuri), son bâton et un pinceau posé.
func _draw_suzuri(w: float, h: float, u: float) -> void:
	var a := UiKit.ease_out((_t - 0.4) / 0.5)
	var c := Vector2(w * 0.5, h - 34 * u)
	var stone := Rect2(c - Vector2(46, 22) * u, Vector2(92, 44) * u)
	UiKit.box(_sb, Color(Color("#1A1A1F"), a), int(10 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.3 * a)
	_sb.shadow_size = int(6 * u)
	draw_style_box(_sb, stone)
	# l'encre liquide au fond de la pierre, avec un reflet
	draw_circle(stone.position + Vector2(24, 22) * u, 14 * u, Color(Color("#05050A"), a))
	draw_arc(stone.position + Vector2(24, 22) * u, 10 * u, -2.4, -1.4, 8, Color(1, 1, 1, 0.25 * a), 1.5 * u)
	_stick(stone.position + Vector2(64, 22) * u, 12.0 * u, a)
	# pinceau posé en biais
	var b0 := c + Vector2(70, 18) * u
	var b1 := c + Vector2(150, -6) * u
	draw_line(b0, b1, Color(Color("#8A6A3E"), a), 6 * u, true)
	draw_line(b0, b0 + (b0 - b1).normalized() * 18 * u, Color(Toon.SUMI, a), 8 * u, true)
	draw_circle(b1, 3.5 * u, Color(Toon.VERMILION, a))


## Retour : un ensō d'encre avec une flèche tracée au pinceau.
func _draw_back(u: float) -> void:
	var c := Vector2(36 * u, 50 * u)
	var rad := 22.0 * u
	_back_rect = Rect2(c - Vector2(rad, rad) * 1.4, Vector2(rad, rad) * 2.8)
	var k := 0.92 if _pressed == "back" else 1.0
	var a := UiKit.ease_out(_t / 0.4)
	draw_circle(c, rad * k, Color(Toon.PAPER, 0.95 * a))
	draw_arc(c, rad * k, -PI * 0.35, PI * 1.45, 32, Color(Toon.SUMI, a), 4.5 * u, true)
	draw_circle(c + Vector2.from_angle(-PI * 0.35) * rad * k, 2.6 * u, Color(Toon.SUMI, a))
	# flèche vers la gauche, comme un trait de pinceau
	var head := c + Vector2(-9, 0) * u * k
	draw_line(c + Vector2(10, 0) * u * k, head, Color(Toon.VERMILION, a), 4.0 * u, true)
	draw_line(head, head + Vector2(7, -7) * u * k, Color(Toon.VERMILION, a), 4.0 * u, true)
	draw_line(head, head + Vector2(7, 7) * u * k, Color(Toon.VERMILION, a), 4.0 * u, true)


# ------------------------------------------------------------------ listes (sceaux, estampes)

func _draw_list() -> void:
	_list_hits.clear()
	if meta == null or _tab == 0:
		return
	var W := _list.size.x
	var u := _u
	if W < 10.0:
		return
	var y := -_scroll + 6 * u
	if _tab == 1:
		y = _draw_seal_list(y, W, u)
	else:
		y = _draw_gallery(y, W, u)
	_content_h = y + _scroll + 10 * u
	# fondus du mur en haut et en bas quand il reste à faire défiler
	var vh := _list.size.y
	var fade := 14.0 * u
	if _scroll > 1.0:
		_list.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, fade), Vector2(0, fade)]),
			PackedColorArray([WOOD, WOOD, Color(WOOD, 0.0), Color(WOOD, 0.0)]))
	if _scroll < _max_scroll() - 1.0:
		_list.draw_polygon(PackedVector2Array([Vector2(0, vh - fade), Vector2(W, vh - fade), Vector2(W, vh), Vector2(0, vh)]),
			PackedColorArray([Color(WOOD, 0.0), Color(WOOD, 0.0), WOOD, WOOD]))
	# ascenseur discret à droite
	if _content_h > vh + 1.0:
		var th := maxf(24.0 * u, vh * vh / _content_h)
		var k := clampf(_scroll / maxf(1.0, _max_scroll()), 0.0, 1.0)
		_list.draw_rect(Rect2(Vector2(W - 3 * u, (vh - th) * k), Vector2(2.5 * u, th)), Color(LABEL, 0.35))


## Les dons des sceaux, une carte par don.
func _draw_seal_list(y0: float, W: float, u: float) -> float:
	var y := y0
	var vh := _list.size.y
	for id in Meta.SEAL_ORDER:
		var sid := String(id)
		var ch := 116.0 * u if (sid == "scroll" and meta.owns_seal(sid)) else 84.0 * u
		var r := Rect2(Vector2(4 * u, y), Vector2(W - 10 * u, ch))
		if r.end.y >= -8 * u and r.position.y <= vh + 8 * u:
			_seal_card(sid, r, u)
		y += ch + 10 * u
	return y


func _seal_card(id: String, r: Rect2, u: float) -> void:
	var it: Dictionary = Meta.SEAL_ITEMS[id]
	var key := "seal:" + id
	var owned: bool = meta.owns_seal(id)
	var c: int = meta.seal_cost(id)
	var afford: bool = meta.can_buy_seal(id)
	var sel := _sel == key
	var rr := r
	if _shake_key == key and _shake > 0.0:
		rr.position.x += sin(_t * 60.0) * 4.0 * u * _shake
	if _pressed == key:
		rr = rr.grow(-2.0 * u)
	var border := Color(Toon.SUMI, 0.15)
	var bw := 1.0
	if sel:
		border = Toon.VERMILION
		bw = 2.5
	elif owned:
		border = Toon.GOLD
		bw = 1.5
	UiKit.box(_sb, Toon.PAPER, int(10 * u), border, int(bw * u))
	_sb.shadow_color = Color(0, 0, 0, 0.3)
	_sb.shadow_size = int(5 * u)
	_sb.shadow_offset = Vector2(0, 3) * u
	_list.draw_style_box(_sb, rr)
	# grand sceau carré : vermillon une fois acquis
	var sq := Rect2(rr.position + Vector2(12, 16) * u, Vector2(50, 50) * u)
	var scol := Toon.VERMILION if owned else (Color("#3A3846") if afford else LOCKED)
	_list.draw_style_box(UiKit.box(_sb, scol, int(6 * u)), sq)
	_list.draw_rect(sq.grow(-4 * u), Color(Toon.WASHI, 0.35), false, 1.2 * u)
	_seal_glyph(id, sq.get_center(), 16.0 * u, Toon.WASHI, scol, 1.0)
	# nom, mention légendaire, effet
	var tx := rr.position.x + 74 * u
	var tw := rr.end.x - 90 * u - tx
	var ny := rr.position.y + 30 * u
	if it.has("power"):
		_list.draw_string(_ui, Vector2(tx, rr.position.y + 15 * u), _p("LÉGENDAIRE"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * u), GOLD_INK)
		ny = rr.position.y + 32 * u
	_list.draw_string(UiKit.TITLE_FONT, Vector2(tx, ny), _p(String(it["name"])), HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * u), Toon.SUMI)
	var desc := String(it["text"])
	if owned and id == "scroll":
		desc = "Tu commences chaque partie avec ce rouleau :"
	_list.draw_multiline_string(UiKit.UI_FONT, Vector2(tx, ny + 17 * u), _p(desc), HORIZONTAL_ALIGNMENT_LEFT, tw, int(10 * u), 3, Color(Toon.SUMI, 0.7))
	# prix, ou « ACQUIS » tamponné
	var tag := Rect2(Vector2(rr.end.x - 80 * u, rr.position.y + 28 * u), Vector2(68, 26) * u)
	if owned:
		_list.draw_rect(tag, Color(Toon.VERMILION, 0.9), false, 2.0 * u)
		UiKit.text(_list, _ui, "ACQUIS", Vector2(tag.get_center().x, tag.get_center().y + 11 * u * 0.36), int(11 * u), Toon.VERMILION)
	else:
		var k2 := 1.0 + (0.07 * sin(_t * 8.0) if sel and afford else 0.0)
		var tg := Rect2(tag.get_center() - tag.size * k2 / 2.0, tag.size * k2)
		_list.draw_style_box(UiKit.box(_sb, Toon.VERMILION if afford else LOCKED, int(4 * u)), tg)
		_seal_icon(_list, tg.position + Vector2(15 * u, tg.size.y / 2.0), 6.0 * u, 1.0, true)
		var pfs := int(14 * u)
		_list.draw_string(_ui, tg.position + Vector2(28 * u, tg.size.y / 2.0 + pfs * 0.36), str(c), HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Toon.WASHI)
	if _stamp_key == key and _stamp > 0.0:
		_stamp_fx(_list, sq.get_center(), "", u)
		var zk := 1.0 + 0.8 * maxf(0.0, 1.0 - (1.0 - _stamp) * 5.0)
		_seal_glyph(id, sq.get_center(), 14.0 * u * zk, Color(Toon.VERMILION, 0.85 * _stamp), UiKit.NONE, 1.0)
	_list_hits.append([_to_screen(r), key])
	if owned and id == "scroll":
		_scroll_chooser(rr, u)


## Pictogramme d'un don des sceaux : le légendaire qu'il libère, sinon un symbole de son effet.
func _seal_glyph(id: String, c: Vector2, r: float, col: Color, bg: Color, a: float) -> void:
	var it: Dictionary = Meta.SEAL_ITEMS.get(id, {})
	if it.has("power"):
		UiKit.power_glyph(_list, String(it["power"]), c, r, col, bg, a)
		return
	var g := String(SEAL_GLYPHS.get(id, "stamp"))
	UiKit.glyph(_list, g, c, r, col, bg, a)


## Choix du rouleau de départ : flèches de part et d'autre du sceau d'école et du nom.
func _scroll_chooser(r: Rect2, u: float) -> void:
	var sp: String = meta.start_power()
	var row := Rect2(Vector2(r.position.x + 74 * u, r.position.y + 80 * u), Vector2(r.size.x - 86 * u, 28 * u))
	_list.draw_style_box(UiKit.box(_sb, Toon.WASHI, int(14 * u), Color(Toon.SUMI, 0.2), int(1 * u)), row)
	var lp := Rect2(row.position, Vector2(34 * u, row.size.y))
	var rp := Rect2(Vector2(row.end.x - 34 * u, row.position.y), Vector2(34 * u, row.size.y))
	_arrow(lp.get_center(), -1.0, u, _pressed == "prev")
	_arrow(rp.get_center(), 1.0, u, _pressed == "next")
	if Data.POWERS.has(sp):
		var d: Dictionary = Data.POWERS[sp]
		var nm := _p(String(d["name"]))
		var lab := UiKit.power_label(sp)
		if lab != nm:
			nm = lab + " · " + nm
		var nfs := int(12 * u)
		var nw := UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var total := 26.0 * u + nw
		var x0 := row.get_center().x - total / 2.0
		var ic := Vector2(x0 + 10 * u, row.get_center().y)
		UiKit.power_icon(_list, sp, ic, 10.0 * u)
		_list.draw_string(UiKit.TITLE_FONT, Vector2(ic.x + 16 * u, row.get_center().y + nfs * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Toon.SUMI)
	_list_hits.append([_to_screen(lp.grow(4 * u)), "prev"])
	_list_hits.append([_to_screen(rp.grow(4 * u)), "next"])


func _arrow(c: Vector2, dir: float, u: float, pressed: bool) -> void:
	var k := 0.85 if pressed else 1.0
	_list.draw_colored_polygon(PackedVector2Array([c + Vector2(6 * dir, 0) * u * k, c + Vector2(-4 * dir, -6) * u * k, c + Vector2(-4 * dir, 6) * u * k]), Toon.VERMILION)


## La galerie des Vues : en-tête (collection, apparence portée) puis estampes sur quatre colonnes.
func _draw_gallery(y0: float, W: float, u: float) -> float:
	var y := y0
	UiKit.text(_list, _ui, "COLLECTION  %d / %d" % [int(meta.prints), Meta.MAX_PRINTS], Vector2(W / 2.0, y + 12 * u), int(11 * u), LABEL)
	y += 22 * u
	var cw3 := (W - 8 * u - 16 * u) / 3.0
	for k in Meta.LOOK_KINDS.size():
		var kind: String = Meta.LOOK_KINDS[k]
		var r := Rect2(Vector2(4 * u + k * (cw3 + 8 * u), y), Vector2(cw3, 30 * u))
		_list.draw_style_box(UiKit.box(_sb, Color(Toon.PAPER, 0.95), int(15 * u), Color(Toon.GOLD, 0.7), int(1.2 * u)), r)
		var on: bool = meta.look_on(kind)
		var col: Color = meta.look_color(kind)
		_look_swatch(_list, r.position + Vector2(20 * u, r.size.y / 2.0), kind, col, u, on)
		var lfs := int(10 * u)
		_list.draw_string(_ui, Vector2(r.position.x + 36 * u, r.get_center().y + lfs * 0.36), _p(String(KIND_LABELS[kind])), HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(Toon.SUMI, 1.0 if on else 0.45))
	y += 30 * u + 14 * u
	var cols := 4
	var gap := 8.0 * u
	var cw := (W - 8 * u - gap * (cols - 1)) / cols
	var art_h := cw * 1.22
	var chh := art_h + 34 * u
	var vh := _list.size.y
	for i in Meta.PRINT_ORDER.size():
		var pid: String = Meta.PRINT_ORDER[i]
		var col2 := i % cols
		var row := i / cols
		var r2 := Rect2(Vector2(4 * u + col2 * (cw + gap), y + row * (chh + 10 * u)), Vector2(cw, chh))
		if r2.end.y >= -8 * u and r2.position.y <= vh + 8 * u:
			_print_card(pid, r2, art_h, u)
	var rows := (Meta.PRINT_ORDER.size() + cols - 1) / cols
	return y + rows * (chh + 10 * u)


func _print_card(pid: String, r: Rect2, art_h: float, u: float) -> void:
	var p: Dictionary = Meta.PRINTS[pid]
	var key := "print:" + pid
	var owned: bool = meta.has_print(pid)
	var sel := _sel == key
	var kind := String(p["kind"])
	var col: Color = p["col"]
	var rr := r
	if _shake_key == key and _shake > 0.0:
		rr.position.x += sin(_t * 60.0) * 3.0 * u * _shake
	if _pressed == key:
		rr = rr.grow(-2.0 * u)
	var art := Rect2(rr.position + Vector2(4, 4) * u, Vector2(rr.size.x - 8 * u, art_h))
	if owned:
		# estampe montée sur papier, épinglée au mur
		UiKit.box(_sb, Toon.WASHI, int(3 * u), Color(Toon.SUMI, 0.8), int(1 * u))
		_sb.shadow_color = Color(0, 0, 0, 0.35)
		_sb.shadow_size = int(4 * u)
		_sb.shadow_offset = Vector2(0, 3) * u
		_list.draw_style_box(_sb, rr)
		_art(_list, art, p, u)
		_list.draw_circle(Vector2(rr.get_center().x, rr.position.y + 1.5 * u), 2.5 * u, Toon.GOLD)
		# la couleur offerte, dans une pastille
		var sc := art.position + Vector2(art.size.x - 9 * u, 9 * u)
		_list.draw_circle(sc, 8.0 * u, Toon.WASHI)
		_list.draw_arc(sc, 8.0 * u, 0.0, TAU, 16, Color(Toon.SUMI, 0.6), 0.8 * u)
		_look_swatch(_list, sc, kind, col, 0.6 * u, true)
		# portée : petit sceau vermillon coché
		if meta.is_worn(pid):
			var ws := Rect2(art.end - Vector2(16, 16) * u, Vector2(13, 13) * u)
			_list.draw_rect(ws, Toon.VERMILION)
			var wc := ws.get_center()
			_list.draw_polyline(PackedVector2Array([wc + Vector2(-3.5, 0) * u, wc + Vector2(-1, 2.5) * u, wc + Vector2(3.5, -2.5) * u]), Toon.WASHI, 1.6 * u, true)
		_list.draw_multiline_string(UiKit.UI_FONT, Vector2(rr.position.x + 3 * u, art.end.y + 12 * u), _p(String(p["name"])), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x - 6 * u, int(8.5 * u), 2, Toon.SUMI)
	else:
		# cadre vide : le kanji du monde, un point d'interrogation, et la condition en court
		_list.draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.28), int(3 * u), Color(Color("#C9B48A"), 0.45), int(1.2 * u)), rr)
		_list.draw_rect(art, Color(Color("#C9B48A"), 0.18), false, 1.0 * u)
		var wi := int(p["w"])
		var kj: String = Meta.WORLD_KANJI[wi - 1] if wi >= 1 and wi <= 5 else "筆"
		UiKit.text(_list, UiKit.TITLE_FONT, kj, Vector2(art.get_center().x, art.get_center().y + 4 * u), int(30 * u), Color(Color("#C9B48A"), 0.3))
		UiKit.text(_list, _ui, "?", Vector2(art.get_center().x, art.get_center().y + 30 * u), int(15 * u), Color(Color("#C9B48A"), 0.6))
		_look_swatch(_list, art.position + Vector2(art.size.x - 9 * u, 9 * u), kind, Color(col, 0.6), 0.6 * u, true)
		UiKit.text(_list, _ui, _p(String(meta.print_how(pid, true))), Vector2(rr.get_center().x, art.end.y + 15 * u), int(9 * u), LABEL)
	if sel:
		_list.draw_rect(rr.grow(2.0 * u), Toon.VERMILION, false, 2.5 * u)
	if _stamp_key == key and _stamp > 0.0:
		_stamp_fx(_list, art.get_center(), "", u)
	_list_hits.append([_to_screen(r), key])


## Échantillon d'apparence : écharpe (bout d'étoffe), sillage (trait), encre (goutte).
func _look_swatch(ci: CanvasItem, c: Vector2, kind: String, col: Color, s: float, on: bool) -> void:
	match kind:
		"cape":
			var pts := PackedVector2Array([c + Vector2(-7, -5) * s, c + Vector2(7, -5) * s, c + Vector2(5, 2) * s,
				c + Vector2(8, 7) * s, c + Vector2(1, 3) * s, c + Vector2(-6, 3) * s])
			ci.draw_colored_polygon(pts, col)
			var outline := pts.duplicate()
			outline.append(pts[0])
			ci.draw_polyline(outline, Color(Toon.SUMI, 0.8 * col.a), maxf(0.8, 1.0 * s))
		"trail":
			if on:
				ci.draw_line(c + Vector2(-8, 4) * s, c + Vector2(8, -4) * s, Color(Toon.SUMI, 0.8 * col.a), 5.5 * s)
				ci.draw_line(c + Vector2(-8, 4) * s, c + Vector2(8, -4) * s, col, 3.5 * s)
			else:
				# aucun sillage porté
				ci.draw_line(c + Vector2(-8, 4) * s, c + Vector2(8, -4) * s, Color(Toon.SUMI, 0.3), maxf(1.0, 1.5 * s))
		_:
			ci.draw_circle(c + Vector2(0, 1.5) * s, 5.0 * s, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3.6, -0.5) * s, c + Vector2(3.6, -0.5) * s, c + Vector2(0, -8) * s]), col)


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
