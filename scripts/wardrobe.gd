extends Control
## Garde-robe (bouton GARDE-ROBE de l'accueil) : panneau de papier en bas de l'écran, le héros reste
## visible au-dessus sur sa barque (main tourne la caméra vers lui) et change d'apparence aussitôt.
## Catégories : Tenue (atlas recoloré), Écharpe, Sillage, Encre (apparences des Vues), Interface (thème).
## Les éléments verrouillés disent comment les obtenir ; certains s'achètent à l'encre.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const Meta = preload("res://scripts/meta.gd")
const GOLD_INK := Color("#9A6B12")

const CATS := ["outfit", "cape", "trail", "ink", "theme"]
const CAT_LABELS := ["TENUE", "ÉCHARPE", "SILLAGE", "ENCRE", "INTERFACE"]
const COLS := 5

signal changed(category: String)  # apparence ou thème porté : main réapplique sur le héros et l'accueil
signal closed

var meta  # instance de meta.gd, fournie par main
var cat := 0  # catégorie affichée
var _sel := ""  # dernier élément touché ("" : celui qui est porté)
var _sel_on := false
var _t := 0.0
var _hits: Array = []  # [Rect2, cible] : « tab:i », « item:<id> »
var _pressed := ""
var _down := false  # un appui est en cours (doigt ou souris)
var _press_pos := Vector2.ZERO
var _press_ms := 0
var _msg := ""
var _msg_t := 0.0
var _bump := 0.0  # élément qui vient d'être porté ou acheté (1 -> 0)
var _bump_key := ""
var _paper := Toon.PAPER
var _wash := Toon.WASHI
var _ink := Toon.SUMI
var _accent := Toon.VERMILION
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _sb := StyleBoxFlat.new()
var _back: Control
var _buy: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 4
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 2
	_back = InkButton.new()
	_back.text = "RETOUR"
	_back.style = "ghost"
	_back.font = _ui
	_back.lead_icon = "home"
	add_child(_back)
	_back.pressed.connect(close)
	_buy = InkButton.new()
	_buy.text = "ACHETER"
	_buy.style = "primary"
	_buy.font = _ui
	add_child(_buy)
	_buy.pressed.connect(_on_buy)


func open() -> void:
	_t = 0.0
	_sel = ""
	_sel_on = false
	_pressed = ""
	_down = false
	_msg_t = 0.0
	_bump = 0.0
	_hits.clear()
	_read_theme()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	_pressed = ""
	_down = false
	closed.emit()


func _read_theme() -> void:
	if meta == null:
		return
	var th: Dictionary = meta.theme_colors()
	_paper = th["paper"]
	_wash = th["wash"]
	_ink = th["ink"]
	_accent = th["accent"]


func cat_id() -> String:
	return String(CATS[cat])


## Élément affiché dans le détail : le dernier touché, sinon celui qui est porté.
func shown_id() -> String:
	if _sel_on:
		return _sel
	for id in meta.cosmetic_ids(cat_id()):
		if bool(meta.cosmetic_worn(cat_id(), String(id))):
			return String(id)
	return ""


# ------------------------------------------------------------------ entrée

func _target_at(p: Vector2) -> String:
	for i in range(_hits.size() - 1, -1, -1):
		var hr: Array = _hits[i]
		var r: Rect2 = hr[0]
		if r.has_point(p):
			return String(hr[1])
	return ""


## Appui (doigt ou souris) : la cible est retenue à l'appui ; le toucher qui a ouvert la garde-robe n'agit pas.
func _press_at(p: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if _down and now - _press_ms < 400 and p.distance_to(_press_pos) < 40.0:
		return  # même appui, déjà suivi (le tactile et la souris émulée arrivent tous les deux)
	# sinon : nouvel appui (un relâché perdu ne bloque jamais la garde-robe)
	_down = true
	_press_ms = now
	_press_pos = p
	_pressed = _target_at(p) if _t >= 0.3 else ""


## Relâché : on agit si le doigt est resté sur la cible, ou n'a presque pas bougé (un doigt dérive).
func _release_at(p: Vector2) -> void:
	if not _down:
		return  # relâché déjà traité par l'autre source : pas de double déclenchement
	_down = false
	var start := _pressed
	_pressed = ""
	if start == "":
		return
	var u := size.x / 400.0
	if _target_at(p) == start or p.distance_to(_press_pos) <= 24.0 * u:
		tap(start)


func _gui_input(event: InputEvent) -> void:
	if meta == null:
		return
	# tactile direct (téléphone) : ne dépend pas de l'émulation de la souris
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		accept_event()
		if st.index != 0:
			return
		if st.pressed:
			_press_at(st.position)
		else:
			_release_at(st.position)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if mb.pressed:
			_press_at(mb.position)
		else:
			_release_at(mb.position)


## Toucher une cible : onglet, ou élément (porté s'il est possédé ; sinon choisi, le détail dit comment l'obtenir).
func tap(key: String) -> void:
	if meta == null:
		return
	if key.begins_with("tab:"):
		var i := clampi(int(key.substr(4)), 0, CATS.size() - 1)
		if i != cat:
			cat = i
			_sel = ""
			_sel_on = false
		return
	if not key.begins_with("item:"):
		return
	var id := key.substr(5)
	var c := cat_id()
	_sel = id
	_sel_on = true
	# retour visuel à chaque toucher (même sur un élément verrouillé ou déjà porté)
	_bump = 1.0
	_bump_key = key
	if bool(meta.cosmetic_owned(c, id)):
		if not bool(meta.cosmetic_worn(c, id)) and bool(meta.wear_cosmetic(c, id)):
			if c == "theme":
				_read_theme()
			changed.emit(c)


func _on_buy() -> void:
	if meta == null:
		return
	var c := cat_id()
	var id := shown_id()
	var cost := int(meta.cosmetic_cost(c, id))
	if cost < 0 or bool(meta.cosmetic_owned(c, id)):
		return
	if int(meta.sumi) < cost:
		_msg = "IL TE MANQUE %d ENCRE" % (cost - int(meta.sumi))
		_msg_t = 1.8
		return
	if bool(meta.buy_cosmetic(c, id)):
		_bump = 1.0
		_bump_key = "item:" + id
		_msg = "ACHETÉ  ·  PORTÉ"
		_msg_t = 1.5
		if c == "theme":
			_read_theme()
		changed.emit(c)


# ------------------------------------------------------------------ dessin

func _panel(h: float, u: float) -> Rect2:
	var top := maxf(h * 0.5, h - 360.0 * u)
	return Rect2(Vector2(0, top), Vector2(size.x, h - top))


func _process(_delta: float) -> void:
	if not visible or meta == null:
		return
	size = get_viewport_rect().size
	var dt := UiKit.real_delta()
	_t += dt
	_msg_t = maxf(0.0, _msg_t - dt)
	_bump = maxf(0.0, _bump - dt * 2.5)
	var u := size.x / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.35, 0.0, 1.0))
	_back.size = Vector2(112, 40) * u
	_back.position = Vector2(14 * u, 20 * u - 16 * u * (1.0 - a))
	_back.font_size = int(13 * u)
	_back.modulate.a = a
	# ACHETER : seulement pour un élément à acheter
	var c := cat_id()
	var id := shown_id()
	var cost := int(meta.cosmetic_cost(c, id))
	var can := cost >= 0 and not bool(meta.cosmetic_owned(c, id))
	_buy.visible = can
	if can:
		var pr := _panel(size.y, u)
		var bw := size.x * 0.56
		_buy.size = Vector2(bw, 46 * u)
		_buy.position = Vector2((size.x - bw) / 2.0, pr.end.y - 62 * u + 30 * u * (1.0 - a))
		_buy.text = "ACHETER  ·  %d" % cost
		_buy.style = "primary" if int(meta.sumi) >= cost else "ghost"
		_buy.font_size = int(15 * u)
		_buy.modulate.a = a
	queue_redraw()


func _draw() -> void:
	if meta == null or size.x < 10.0:
		return
	_hits.clear()
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.35, 0.0, 1.0))
	# voile du haut (titre lisible), le héros reste visible au milieu
	var top := PackedColorArray([Color(_wash, 0.9 * a), Color(_wash, 0.9 * a), Color(_wash, 0.0), Color(_wash, 0.0)])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 120 * u), Vector2(0, 120 * u)]), top)
	UiKit.text(self, _title, "GARDE-ROBE", Vector2(w / 2.0, 92 * u), int(26 * u), Color(_ink, a))
	# compteur d'encre (en haut à droite)
	var ip := Vector2(w - 86 * u, 40 * u)
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, a), int(2 * u), Color(Toon.GOLD, a), int(maxf(1.0, 1.5 * u))), Rect2(ip + Vector2(0, -12) * u, Vector2(9, 24) * u))
	draw_string(_ui, ip + Vector2(16, 6) * u, str(int(meta.sumi)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), Color(_ink, a))
	# panneau de papier
	var pr := _panel(h, u)
	pr.position.y += 40 * u * (1.0 - a)
	UiKit.box(_sb, Color(_paper, 0.97 * a), int(22 * u))
	_sb.corner_radius_bottom_left = 0
	_sb.corner_radius_bottom_right = 0
	_sb.shadow_color = Color(0, 0, 0, 0.25 * a)
	_sb.shadow_size = int(18 * u)
	_sb.shadow_offset = Vector2(0, -4 * u)
	draw_style_box(_sb, Rect2(pr.position, pr.size + Vector2(0, 30 * u)))
	_sb.shadow_size = 0
	_sb.shadow_offset = Vector2.ZERO
	draw_line(Vector2(w / 2.0 - 22 * u, pr.position.y + 9 * u), Vector2(w / 2.0 + 22 * u, pr.position.y + 9 * u), Color(_ink, 0.2 * a), 3 * u, true)
	# onglets
	var tx := 12.0 * u
	var tw := (w - 24.0 * u) / float(CATS.size())
	var ty := pr.position.y + 22 * u
	for i in CATS.size():
		var r := Rect2(Vector2(tx + tw * i + 2 * u, ty), Vector2(tw - 4 * u, 32 * u))
		var on := i == cat
		if on:
			draw_style_box(UiKit.box(_sb, Color(_ink, a), int(16 * u)), r)
		else:
			draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(16 * u), Color(_ink, 0.25 * a), int(maxf(1.0, 1.2 * u))), r)
		var lab := String(CAT_LABELS[i])
		var fs := int(10.5 * u)
		var lw := _ui.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if lw > r.size.x - 6 * u and lw > 0.0:
			fs = maxi(1, int(float(fs) * (r.size.x - 6 * u) / lw))
		UiKit.text(self, _ui, lab, r.get_center() + Vector2(0, 4 * u), fs, Color(_paper if on else _ink, a * (1.0 if on else 0.7)))
		_hits.append([r, "tab:%d" % i])
	# éléments de la catégorie
	var c := cat_id()
	var ids: Array = meta.cosmetic_ids(c)
	var gy := ty + 46 * u
	var cw := (w - 24.0 * u) / float(COLS)
	var rh := 78.0 * u
	var shown := shown_id()
	for i in ids.size():
		var id := String(ids[i])
		var col := i % COLS
		var row := i / COLS
		var cc := Vector2(tx + cw * (col + 0.5), gy + rh * row + 26 * u)
		var k := UiKit.ease_out(clampf((_t - 0.12 - 0.025 * i) / 0.25, 0.0, 1.0))
		var ka := a * k
		var owned := bool(meta.cosmetic_owned(c, id))
		var worn := bool(meta.cosmetic_worn(c, id))
		var key := "item:" + id
		var rad := 24.0 * u * (1.0 + (0.12 * _bump if key == _bump_key else 0.0))
		_swatch(c, id, cc, rad, ka * (1.0 if owned else 0.45))
		if worn:
			draw_arc(cc, rad + 4 * u, 0.0, TAU, 40, Color(_accent, ka), 2.6 * u, true)
		elif id == shown and _sel_on:
			draw_arc(cc, rad + 4 * u, 0.0, TAU, 40, Color(_ink, 0.6 * ka), 1.6 * u, true)
		if not owned:
			UiKit.glyph(self, "at_lock", cc + Vector2(rad * 0.66, -rad * 0.66), 8.5 * u, Color(Toon.WASHI, 0.95 * ka), Toon.SUMI)
		# nom court, ou prix pour ce qui s'achète
		var lab := UiKit.plain(String(meta.cosmetic_name(c, id)))
		var lc := Color(_ink, (0.85 if owned else 0.5) * ka)
		var cost := int(meta.cosmetic_cost(c, id))
		if not owned and cost >= 0:
			lab = "%d ENCRE" % cost
			lc = Color(GOLD_INK if _paper.v > 0.5 else Toon.GOLD, ka)
		var fs2 := int(9 * u)
		var lw2 := _ui.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		if lw2 > cw - 4 * u and lw2 > 0.0:
			fs2 = maxi(1, int(float(fs2) * (cw - 4 * u) / lw2))
		UiKit.text(self, _ui, lab, cc + Vector2(0, 40 * u), fs2, lc)
		_hits.append([Rect2(cc - Vector2(cw * 0.5, 30 * u), Vector2(cw, rh - 2 * u)), key])
	# détail de l'élément affiché
	var rows := int(ceil(float(ids.size()) / float(COLS)))
	var dy := gy + rh * maxi(rows, 2) + 8 * u
	var nm := UiKit.plain(String(meta.cosmetic_name(c, shown)))
	UiKit.text(self, _title, nm, Vector2(w / 2.0, dy + 6 * u), int(18 * u), Color(_ink, a))
	var sub := ""
	var sc := Color(_ink, 0.6 * a)
	if _msg_t > 0.0:
		sub = _msg
		sc = Color(_accent, a)
	elif bool(meta.cosmetic_worn(c, shown)):
		sub = "PORTÉ"
	elif bool(meta.cosmetic_owned(c, shown)):
		sub = "TOUCHE POUR PORTER"
	else:
		sub = UiKit.plain(String(meta.cosmetic_how(c, shown)))
	var lines := UiKit.wrap(_ui, sub, int(10.5 * u), w - 60 * u, ["·", ":", "»"])
	for li in mini(lines.size(), 2):
		UiKit.text(self, _ui, lines[li], Vector2(w / 2.0, dy + 26 * u + 15 * u * li), int(10.5 * u), sc)
	# échantillon pour le sillage et l'encre (invisibles sur le héros immobile)
	if c == "trail" or c == "ink":
		var sp := Vector2(w - 58 * u, dy)
		_sample_stroke(c, shown, sp, u, a)


## Pastille d'un élément selon sa catégorie.
func _swatch(c: String, id: String, p: Vector2, r: float, a: float) -> void:
	var col: Color = meta.cosmetic_color(c, id)
	draw_circle(p + Vector2(0, 2), r, Color(0, 0, 0, 0.18 * a))
	match c:
		"theme":
			var th: Dictionary = Meta.THEMES.get(id, {})
			var wash: Color = th.get("wash", Toon.WASHI)
			var paper: Color = th.get("paper", Toon.PAPER)
			var ink: Color = th.get("ink", Toon.SUMI)
			var acc: Color = th.get("accent", Toon.VERMILION)
			draw_circle(p, r, Color(wash, a))
			var card := Rect2(p + Vector2(-r * 0.55, -r * 0.5), Vector2(r * 1.1, r))
			draw_style_box(UiKit.box(_sb, Color(paper, a), int(r * 0.18)), card)
			draw_line(card.position + Vector2(r * 0.18, r * 0.3), card.position + Vector2(r * 0.92, r * 0.3), Color(ink, a), r * 0.12)
			draw_line(card.position + Vector2(r * 0.18, r * 0.55), card.position + Vector2(r * 0.7, r * 0.55), Color(ink, 0.6 * a), r * 0.09)
			draw_rect(Rect2(card.position + Vector2(r * 0.18, r * 0.72), Vector2(r * 0.3, r * 0.14)), Color(acc, a))
		"trail":
			draw_circle(p, r, Color(Toon.SUMI, 0.9 * a))
			draw_arc(p, r * 0.58, PI * 0.85, PI * 2.05, 18, Color(col, a), r * 0.26, true)
		"ink":
			draw_circle(p, r, Color(Toon.PAPER, a))
			_blob(p, r * 0.62, Color(col, a))
		"outfit":
			draw_circle(p, r, Color(col, a))
			UiKit.hanger_icon(self, p + Vector2(0, r * 0.05), r * 0.52, Color(Toon.SUMI if col.v > 0.6 else Toon.WASHI, 0.75 * a))
		_:
			draw_circle(p, r, Color(col, a))
			# écharpe : un pli
			draw_arc(p + Vector2(0, -r * 0.1), r * 0.55, 0.3, PI - 0.3, 14, Color(Toon.SUMI, 0.35 * a), r * 0.1, true)
	draw_arc(p, r, 0.0, TAU, 40, Color(_ink, 0.55 * a), maxf(1.0, r * 0.07), true)


## Tache d'encre (pastille de l'encre du trait).
func _blob(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var ang := TAU * float(i) / 14.0
		var rr := r * (0.82 + 0.18 * sin(ang * 3.0 + 0.6))
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)


## Petit coup de pinceau (encre) ou ruban de lame (sillage) à la couleur choisie.
func _sample_stroke(c: String, id: String, p: Vector2, u: float, a: float) -> void:
	var col: Color = meta.cosmetic_color(c, id)
	var p0 := p + Vector2(-26, 10) * u
	var p1 := p + Vector2(26, -6) * u
	var d := p1 - p0
	var n := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array()
	var steps := 12
	var wd := (6.0 if c == "ink" else 4.0) * u
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(p0 + d * t + n * wd * sin(PI * minf(1.0, t * 1.1)) * (1.0 - 0.5 * t))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		pts.append(p0 + d * t - n * wd * sin(PI * minf(1.0, t * 1.1)) * (1.0 - 0.5 * t))
	if c == "trail":
		draw_circle(p, 30 * u, Color(Toon.SUMI, 0.85 * a))
	if UiKit.poly_area(pts) > 1.0:
		draw_colored_polygon(pts, Color(col, a))
