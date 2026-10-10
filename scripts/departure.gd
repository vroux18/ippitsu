extends Control
## Écran AVANT LE DÉPART (maquettes Pinceaux/Main.dc.html et Omamori/Main.dc.html) : ouvert par JOUER (accueil)
## et PARTIR (carte des mondes), juste avant le rideau d'encre. En haut le pinceau : aperçu du trait, flèches,
## règle, trois aspects (verrouillés grisés avec leur condition) ; en bas la grille des huit omamori (un seul,
## ou aucun), le détail du charme touché, et PARTIR. L'écran s'ouvre sur le dernier choix : un seul toucher
## sur PARTIR repart avec lui. Le choix est gardé dans meta (choose_gear) ; un élément verrouillé grise PARTIR.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const Gear = preload("res://scripts/gear_data.gd")

const BG := Color("#1B1A1E")
const PAPER := Color("#EFE6D2")
const PAPER_HI := Color("#F5EEDD")
const RED := Color("#D7372B")
const RED_DARK := Color("#B3261C")
const OK_GREEN := Color("#3E7A4A")

signal go  # PARTIR : le choix est enregistré, main entre dans le monde
signal closed  # retour sans partir

var meta  # instance de meta.gd, fournie par main
var bi := 0  # pinceau affiché (Gear.ORDER)
var ak := 0  # aspect choisi
var cid := ""  # omamori choisi ("" : aucun)
var _t := 0.0
var _hits: Array = []  # [Rect2, cible] : prev, next, asp:i, charm:id, go
var _pressed := ""
var _down := false
var _press_pos := Vector2.ZERO
var _press_ms := 0
var _shake := 0.0  # PARTIR touché alors qu'un choix est verrouillé
var _bump := 0.0
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _caps := FontVariation.new()
var _sb := StyleBoxFlat.new()
var _back: Control
var _safe := Vector2.ZERO
var go_rect := Rect2()  # PARTIR (robot ui)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 3
	_ui.base_font = UiKit.UI_FONT
	_caps.base_font = UiKit.UI_FONT
	_caps.spacing_glyph = 2
	_back = InkButton.new()
	_back.text = "RETOUR"
	_back.style = "round"
	_back.icon = "back"
	_back.font = _ui
	add_child(_back)
	_back.pressed.connect(close)


## Ouvre l'écran sur le dernier choix (ramené à ce qui est possédé : un toucher sur PARTIR suffit).
func open() -> void:
	var g: Dictionary = meta.gear_now() if meta != null else {"brush": "fude", "aspect": 0, "charm": ""}
	bi = maxi(0, Gear.ORDER.find(String(g["brush"])))
	ak = int(g["aspect"])
	cid = String(g["charm"])
	_t = 0.0
	_pressed = ""
	_down = false
	_shake = 0.0
	_hits.clear()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func brush_id() -> String:
	return String(Gear.ORDER[bi])


## Affiche le pinceau `id` (captures, robot), sur son aspect choisi s'il est possédé.
func show_brush(id: String) -> void:
	var i := Gear.ORDER.find(id)
	if i < 0:
		return
	bi = i
	ak = int(meta.aspect_sel.get(id, 0)) if meta != null else 0
	if meta != null and not bool(meta.aspect_owned(id, ak)):
		ak = 0


func brush_open() -> bool:
	return meta != null and bool(meta.brush_unlocked(brush_id()))


func aspect_open(k: int) -> bool:
	return meta != null and bool(meta.aspect_owned(brush_id(), k))


func charm_open(id: String) -> bool:
	return id == "" or (meta != null and bool(meta.charm_owned(id)))


## PARTIR permis : pinceau, aspect et charme possédés.
func can_go() -> bool:
	return brush_open() and aspect_open(ak) and charm_open(cid)


func go_label() -> String:
	if not brush_open():
		return "PINCEAU VERROUILLÉ"
	if not aspect_open(ak):
		return "ASPECT À GAGNER"
	if not charm_open(cid):
		return "CHARME VERROUILLÉ"
	return "PARTIR"


## Toucher une cible (doigt, robot, captures). Renvoie vrai si l'écran a agi.
func tap(key: String) -> bool:
	if meta == null:
		return false
	_bump = 1.0
	match key:
		"prev":
			bi = (bi + Gear.ORDER.size() - 1) % Gear.ORDER.size()
			show_brush(brush_id())
			return true
		"next":
			bi = (bi + 1) % Gear.ORDER.size()
			show_brush(brush_id())
			return true
		"go":
			if not can_go():
				_shake = 1.0
				return false
			meta.choose_gear(brush_id(), ak, cid)
			visible = false
			go.emit()
			return true
	if key.begins_with("asp:"):
		ak = clampi(int(key.substr(4)), 0, 2)
		return true
	if key.begins_with("charm:"):
		var id := key.substr(6)
		if Gear.CHARMS.has(id):
			cid = "" if cid == id else id  # un second toucher l'ôte : on peut partir sans charme
			return true
	return false


# ------------------------------------------------------------------ entrée

func _target_at(p: Vector2) -> String:
	for i in range(_hits.size() - 1, -1, -1):
		var hr: Array = _hits[i]
		if (hr[0] as Rect2).has_point(p):
			return String(hr[1])
	return ""


func _press_at(p: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if _down and now - _press_ms < 400 and p.distance_to(_press_pos) < 40.0:
		return  # même appui (tactile et souris émulée)
	_down = true
	_press_ms = now
	_press_pos = p
	_pressed = _target_at(p) if _t >= 0.25 else ""


func _release_at(p: Vector2) -> void:
	if not _down:
		return
	_down = false
	var start := _pressed
	_pressed = ""
	if start == "":
		return
	var u := size.x / 400.0
	if _target_at(p) == start or p.distance_to(_press_pos) <= 24.0 * u:
		tap(start)


func _gui_input(event: InputEvent) -> void:
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


# ------------------------------------------------------------------ dessin

func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	_safe = UiKit.safe_insets(size)
	var dt := UiKit.real_delta()
	_t += dt
	_shake = maxf(0.0, _shake - dt * 2.2)
	_bump = maxf(0.0, _bump - dt * 3.0)
	var u := size.x / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.3, 0.0, 1.0))
	var ib: float = UiKit.ICON_BTN * u
	_back.size = Vector2(ib, ib)
	_back.position = Vector2(UiKit.HEAD_X * u - ib / 2.0, _safe.x + UiKit.HEAD_Y * u - ib / 2.0)
	_back.modulate.a = a
	queue_redraw()


## Petites capitales (légende de section), encre claire à 60 %.
func _caption(txt: String, p: Vector2, u: float, a: float) -> void:
	draw_string(_caps, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(10.5 * u), Color(PAPER, 0.6 * a))


func _draw() -> void:
	if meta == null or size.x < 10.0:
		return
	_hits.clear()
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.3, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(BG, a))
	# hauteur voulue (u) : tout tient sur un écran 392 × 800 ; plus court, les blocs se resserrent
	var need := 780.0
	var avail := (h - _safe.x - _safe.y) / u
	var v := u * clampf(avail / need, 0.72, 1.0)
	var mx := 14.0 * u
	var bid := brush_id()
	var bd: Dictionary = Gear.brush(bid)
	var bcol: Color = bd["col"]
	var bopen := brush_open()
	# en-tête : titre et trait vermillon
	UiKit.screen_title(self, _title, "AVANT LE DÉPART", Vector2(w / 2.0, _safe.x + UiKit.HEAD_BASE * u), u, PAPER, a, "", w - 2.0 * 70.0 * u,
		UiKit.ease_out(clampf((_t - 0.1) / 0.4, 0.0, 1.0)))
	var y := _safe.x + 74.0 * u
	# ---- pinceau : aperçu du trait (papier), le héros en vermillon, les ennemis en gris
	var pr := Rect2(Vector2(mx, y), Vector2(w - 2.0 * mx, 150.0 * v))
	draw_style_box(UiKit.box(_sb, Color(PAPER, a), int(14.0 * u)), pr)
	var reveal := clampf(fmod(_t, 3.2) / 1.1, 0.0, 1.0)
	var inner := Rect2(pr.position + Vector2(8.0 * u, 10.0 * v), pr.size - Vector2(16.0 * u, 14.0 * v))
	Gear.draw_brush(self, bid, ak, inner, a * (1.0 if bopen else 0.45), reveal)
	draw_string(_caps, pr.position + Vector2(12.0 * u, 18.0 * v), "APERÇU DU TRAIT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.5 * u), Color(Color("#5A5148"), a))
	if not bopen:
		var lc := pr.get_center()
		draw_circle(lc, 26.0 * u, Color(BG, 0.85 * a))
		UiKit.glyph(self, "at_lock", lc, 15.0 * u, Color(PAPER, a), UiKit.NONE, a)
	y = pr.end.y + 6.0 * v
	# ---- flèches et nom
	var nav_h := 50.0 * v
	var r44 := maxf(44.0, 44.0 * u)
	var lb := Rect2(Vector2(mx, y + nav_h / 2.0 - r44 / 2.0), Vector2(r44, r44))
	var rb := Rect2(Vector2(w - mx - r44, lb.position.y), Vector2(r44, r44))
	for q in [[lb, "prev", -1.0], [rb, "next", 1.0]]:
		var rr: Rect2 = q[0]
		var cc := rr.get_center()
		var pressed := _pressed == String(q[1])
		draw_arc(cc, rr.size.x / 2.0 - 1.0, 0.0, TAU, 32, Color(PAPER, (0.7 if pressed else 0.4) * a), 1.5 * u, true)
		var dx := float(q[2])
		var tri := PackedVector2Array([cc + Vector2(7.0 * dx, 0) * u, cc + Vector2(-5.0 * dx, -7.0) * u, cc + Vector2(-5.0 * dx, 7.0) * u])
		draw_colored_polygon(tri, Color(PAPER, a))
		_hits.append([rr, String(q[1])])
	var nm := String(bd["name"])
	var nfs := int(22.0 * u)
	while nfs > 12 and _title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > w - 2.0 * (mx + r44 + 10.0 * u):
		nfs -= 1
	UiKit.text(self, _title, nm, Vector2(w / 2.0, y + 24.0 * v), nfs, Color(PAPER, a * (1.0 if bopen else 0.6)))
	var jp := String(bd["jp"])
	var sub := (jp + " · " if UiKit.has_glyphs(jp) else "") + String(bd["sub"])
	UiKit.text(self, _ui, sub, Vector2(w / 2.0, y + 42.0 * v), int(11.0 * u), Color(PAPER, 0.65 * a))
	y += nav_h
	# pastilles des cinq pinceaux
	for i in Gear.ORDER.size():
		var px := w / 2.0 + (float(i) - 2.0) * 16.0 * u
		draw_circle(Vector2(px, y + 4.0 * v), 4.0 * u, Color(PAPER, (1.0 if i == bi else 0.25) * a))
	y += 14.0 * v
	# règle du pinceau, ou sa condition s'il est verrouillé
	var rule := String(bd["rule"])
	var rfs := int(12.0 * u)
	var lines := UiKit.wrap(_ui, rule, rfs, w - 2.0 * (mx + 4.0 * u), [":", "·"])
	for li in mini(lines.size(), 2):
		draw_string(_ui, Vector2(mx + 4.0 * u, y + (13.0 + 16.0 * li) * v), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color(PAPER, 0.88 * a))
	y += 40.0 * v
	# ---- aspects
	_caption("ASPECT", Vector2(mx + 2.0 * u, y + 9.0 * v), u, a)
	if not bopen:
		var how := "À GAGNER : %s" % String(bd["how"]).to_upper()
		var hw := _caps.get_string_size(how, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.5 * u)).x
		draw_string(_caps, Vector2(w - mx - hw, y + 9.0 * v), how, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.5 * u), Color(Color("#E8574A"), a))
	y += 15.0 * v
	var gap := 8.0 * u
	var aw := (w - 2.0 * mx - 2.0 * gap) / 3.0
	var ah := maxf(48.0, 56.0 * v)
	var asp: Array = bd["aspects"]
	for k in 3:
		var r := Rect2(Vector2(mx + float(k) * (aw + gap), y), Vector2(aw, ah))
		var own := aspect_open(k)
		var sel := k == ak
		var bc := (PAPER if bcol.v < 0.25 else bcol) if sel else Color(PAPER, 0.2)
		if sel:
			draw_style_box(UiKit.box(_sb, Color(PAPER, 0.14 * a), int(10.0 * u)), r)
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(10.0 * u), Color(bc, a), maxi(1, int(2.0 * u))), r)
		var fg := Color(PAPER, (1.0 if own or sel else 0.5) * a)
		var an := String(asp[k][0])
		UiKit.text(self, _ui, an, Vector2(r.get_center().x, r.position.y + ah * 0.45), int(12.5 * u), fg)
		var tag := "acquis" if own else ("verrouillé" if not bopen else "boss avec ce pinceau")
		if own and k > 0:
			tag = "gagné"
		var tfs := int(9.5 * u)
		while tfs > 6 and _ui.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > aw - 8.0 * u:
			tfs -= 1
		UiKit.text(self, _ui, tag, Vector2(r.get_center().x, r.position.y + ah * 0.78), tfs, Color(PAPER, (0.75 if own else 0.45) * a))
		if not own:
			UiKit.glyph(self, "at_lock", r.position + Vector2(aw - 10.0 * u, 10.0 * u), 5.5 * u, Color(PAPER, 0.6 * a), UiKit.NONE, a)
		_hits.append([r, "asp:%d" % k])
	y += ah + 6.0 * v
	var tb := Rect2(Vector2(mx, y), Vector2(w - 2.0 * mx, 40.0 * v))
	draw_style_box(UiKit.box(_sb, Color(PAPER, 0.08 * a), int(10.0 * u)), tb)
	var at := String(asp[ak][1])
	var afs := int(11.0 * u)
	var al := UiKit.wrap(_ui, at, afs, tb.size.x - 20.0 * u, [":", "·"])
	for li in mini(al.size(), 2):
		draw_string(_ui, Vector2(tb.position.x + 10.0 * u, tb.position.y + (16.0 + 14.0 * li) * v), al[li], HORIZONTAL_ALIGNMENT_LEFT, -1, afs, Color(PAPER, 0.85 * a))
	y = tb.end.y + 12.0 * v
	# ---- omamori : grille 4 × 2
	_caption("CHARME · UN SEUL", Vector2(mx + 2.0 * u, y + 9.0 * v), u, a)
	y += 16.0 * v
	var cgap := 8.0 * u
	var cw := (w - 2.0 * mx - 3.0 * cgap) / 4.0
	var ch := maxf(48.0, 64.0 * v)
	for i in Gear.CHARM_ORDER.size():
		var id := String(Gear.CHARM_ORDER[i])
		var col := i % 4
		var row := i / 4
		var r := Rect2(Vector2(mx + float(col) * (cw + cgap), y + float(row) * (ch + cgap)), Vector2(cw, ch))
		var own := charm_open(id)
		var sel := id == cid
		if sel:
			draw_style_box(UiKit.box(_sb, Color(PAPER, 0.14 * a), int(12.0 * u)), r)
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(12.0 * u), Color(PAPER, (1.0 if sel else 0.15) * a), maxi(1, int(2.0 * u))), r)
		var s := (ch - 22.0 * v) / 56.0
		Gear.draw_charm(self, id, Vector2(r.get_center().x, r.position.y + 4.0 * v + 28.0 * s), s, a, own)
		var cd: Dictionary = Gear.charm(id)
		UiKit.text(self, _ui, String(cd["short"]), Vector2(r.get_center().x, r.end.y - 6.0 * v), int(10.0 * u), Color(PAPER, (1.0 if own else 0.45) * a))
		_hits.append([r, "charm:" + id])
	y += 2.0 * ch + cgap + 10.0 * v
	# ---- détail du charme choisi (sinon : sans charme)
	var dr := Rect2(Vector2(mx, y), Vector2(w - 2.0 * mx, 74.0 * v))
	draw_style_box(UiKit.box(_sb, Color(PAPER, a), int(12.0 * u)), dr)
	var ink := Color(BG, a)
	if cid == "":
		UiKit.text(self, _title, "Sans charme", Vector2(dr.get_center().x, dr.position.y + 30.0 * v), int(15.0 * u), ink)
		UiKit.text(self, _ui, "Touche un omamori pour le porter (un seul par partie).", Vector2(dr.get_center().x, dr.position.y + 52.0 * v), int(10.5 * u), Color(Color("#5A5148"), a))
	else:
		var cd: Dictionary = Gear.charm(cid)
		var own := charm_open(cid)
		var cc: Color = cd["col"]
		draw_circle(Vector2(dr.position.x + 18.0 * u, dr.position.y + 17.0 * v), 6.0 * u, Color(cc, a))
		var nfs2 := int(15.0 * u)
		draw_string(_title, Vector2(dr.position.x + 30.0 * u, dr.position.y + 22.0 * v), String(cd["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs2, ink)
		var efs := int(11.0 * u)
		var el := UiKit.wrap(_ui, String(cd["effect"]), efs, dr.size.x - 24.0 * u, [":", "·"])
		for li in mini(el.size(), 2):
			draw_string(_ui, Vector2(dr.position.x + 12.0 * u, dr.position.y + (39.0 + 13.0 * li) * v), el[li], HORIZONTAL_ALIGNMENT_LEFT, -1, efs, ink)
		var st := "PORTÉ POUR CETTE PARTIE" if own else "À GAGNER : RANG MAÎTRE AU MONDE %d" % int(cd["world"])
		draw_string(_caps, Vector2(dr.position.x + 12.0 * u, dr.end.y - 7.0 * v), st, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.5 * u), Color(OK_GREEN if own else RED_DARK, a))
	y = dr.end.y + 10.0 * v
	# ---- PARTIR (pilule vermillon ; éteinte quand un choix est verrouillé)
	var bh := maxf(52.0, 52.0 * u)
	var by := maxf(y, h - _safe.y - bh - 12.0 * u)
	var dx := sin(_shake * 26.0) * 6.0 * u * _shake
	go_rect = Rect2(Vector2(mx + dx, by), Vector2(w - 2.0 * mx, bh))
	var ok := can_go()
	var gr := go_rect.grow(-2.0 * u) if _pressed == "go" and ok else go_rect
	if ok:
		draw_style_box(UiKit.box(_sb, Color(RED, a), int(bh / 2.0), Color(RED_DARK, a), maxi(1, int(1.5 * u))), gr)
	else:
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(bh / 2.0), Color(PAPER, 0.25 * a), maxi(1, int(1.5 * u))), gr)
	var gl := go_label()
	var gfs := int(16.0 * u)
	while gfs > 10 and _title.get_string_size(gl, HORIZONTAL_ALIGNMENT_LEFT, -1, gfs).x > gr.size.x - 30.0 * u:
		gfs -= 1
	UiKit.text(self, _title, gl, Vector2(gr.get_center().x, gr.get_center().y + float(gfs) * 0.36), gfs, Color(PAPER_HI if ok else Color(PAPER, 0.45), a))
	_hits.append([go_rect, "go"])
