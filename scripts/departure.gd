extends Control
## Écran AVANT LE DÉPART (maquette Depart.dc.html, validée) : ouvert par JOUER (accueil) et PARTIR (carte des
## mondes), juste avant le rideau d'encre. Une écritoire sur papier washi : en haut le râtelier de bois où pendent
## les cinq pinceaux (toucher un pinceau le décroche, glisser à gauche ou à droite passe au voisin), son nom, la
## bande de papier où il peint son trait, sa règle, ses trois aspects en sceaux hanko ; en bas la cordelette des
## huit omamori (un seul, ou aucun : un second toucher l'ôte), l'étiquette du charme touché et PARTIR, coup
## d'encre au lavis quand un choix reste à gagner. L'écran s'ouvre sur le dernier choix : un seul toucher sur
## PARTIR repart avec lui. Le choix est gardé dans meta (choose_gear).
##
## Le dessin suit le repère de la maquette (390 × 844) : x à l'échelle de la largeur, y resserré pour tenir sur
## un écran plus court (392 × 800), les tailles (texte, rayons) à la plus petite des deux échelles.

const UiKit = preload("res://scripts/ui_kit.gd")
const Gear = preload("res://scripts/gear_data.gd")
const Kamon = preload("res://scripts/kamon.gd")

const PAPER := Color("#EFE6D2")  # fond washi
const PAPER_HI := Color("#F7F0DF")  # bande, étiquette
const SUMI := Color("#1B1A1E")
const INK_TEXT := Color("#3A342E")
const CAPTION := Color("#8A7E68")
const MUTED := Color("#9A8E78")
const SUB := Color("#6A5F50")
const FIBER := Color("#B9AA8C")
const WOOD := Color("#6B4A2B")
const WOOD_HI := Color("#8C6640")
const WOOD_DARK := Color("#4A3220")
const CORD := Color("#C8322A")
const SEAL := Color("#C8322A")
const SEAL_EDGE := Color("#8E1F17")
const LOCK_RED := Color("#8E2A1E")
const RED_DARK := Color("#B3261C")
const GOLD := Color("#C49A45")
const GOLD_HI := Color("#E2A93B")
const OK_GREEN := Color("#3E7A4A")
const GREY := Color("#8A8070")
const DASH := Color("#B3A78F")
const LAVIS := Color("#BDB19A")  # trait d'un pinceau à gagner
const GO_OFF := Color("#CFC4AE")
const GO_OFF_INK := Color("#7A6E58")
const DW := 390.0  # repère de la maquette
const DH := 844.0

## Nom affiché et devise de chaque pinceau (maquette) ; règles et aspects restent dans gear_data.
const TAG := {"fude": ["FUDE", "LE PINCEAU DU MAÎTRE"], "hake": ["HAKE", "LE PINCEAU LARGE"],
	"menso": ["MENSO", "LE PINCEAU FIN"], "warefude": ["WAREFUDE", "LE PINCEAU FENDU"], "chi": ["CHI-FUDE", "LE CALAME DE SANG"]}
## Manche (couleur, demi-largeur) et forme de la pointe de chaque pinceau pendu.
const HANDLE := {"fude": [Color("#C9A86A"), 3.6], "hake": [Color("#8C6640"), 5.0], "menso": [Color("#3C3A36"), 2.6],
	"warefude": [Color("#B9A27A"), 3.6], "chi": [Color("#6E1E16"), 3.6]}

signal go  # PARTIR : le choix est enregistré, main entre dans le monde
signal closed  # retour sans partir

var meta  # instance de meta.gd, fournie par main
var bi := 0  # pinceau affiché (Gear.ORDER)
var ak := 0  # aspect choisi
var cid := ""  # omamori choisi ("" : aucun)
var _t := 0.0
var _bt := 0.0  # instant du dernier changement de pinceau (le trait se repeint, le pinceau descend)
var _ct := 0.0  # instant du dernier toucher d'omamori (il se soulève)
var _hits: Array = []  # [Rect2, cible] : back, brush:id, asp:i, charm:id, go
var _pressed := ""
var _down := false
var _press_pos := Vector2.ZERO
var _press_ms := 0
var _shake := 0.0  # PARTIR touché alors qu'un choix est à gagner
var _fonts := {}  # "t|5" (police, espacement en px) -> FontVariation
var _safe := Vector2.ZERO
# repère : x · _u ; y · _v + décalage ; tailles · _k
var _u := 1.0
var _v := 1.0
var _k := 1.0
var _top := 0.0
var _extra := 0.0
var go_rect := Rect2()  # PARTIR (robot ui)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Ouvre l'écran sur le dernier choix (ramené à ce qui est possédé : un toucher sur PARTIR suffit).
func open() -> void:
	var g: Dictionary = meta.gear_now() if meta != null else {"brush": "fude", "aspect": 0, "charm": ""}
	bi = maxi(0, Gear.ORDER.find(String(g["brush"])))
	ak = int(g["aspect"])
	cid = String(g["charm"])
	_t = 0.0
	_bt = 0.0
	_ct = -10.0
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


## Affiche le pinceau `id` (captures, robot, toucher sur le râtelier), sur son aspect choisi s'il est possédé.
func show_brush(id: String) -> void:
	var i := Gear.ORDER.find(id)
	if i < 0:
		return
	if i != bi:
		_bt = _t
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
		return "PINCEAU À GAGNER"
	if not aspect_open(ak):
		return "ASPECT À GAGNER"
	if not charm_open(cid):
		return "CHARME À GAGNER"
	return "PARTIR"


## Toucher une cible (doigt, robot, captures). Renvoie vrai si l'écran a agi.
func tap(key: String) -> bool:
	if meta == null:
		return false
	match key:
		"back":
			close()
			return true
		"prev":
			show_brush(String(Gear.ORDER[(bi + Gear.ORDER.size() - 1) % Gear.ORDER.size()]))
			return true
		"next":
			show_brush(String(Gear.ORDER[(bi + 1) % Gear.ORDER.size()]))
			return true
		"go":
			if not can_go():
				_shake = 1.0
				return false
			meta.choose_gear(brush_id(), ak, cid)
			visible = false
			go.emit()
			return true
	if key.begins_with("brush:"):
		var id := key.substr(6)
		if Gear.BRUSHES.has(id):
			show_brush(id)
			return true
	if key.begins_with("asp:"):
		ak = clampi(int(key.substr(4)), 0, 2)
		return true
	if key.begins_with("charm:"):
		var id := key.substr(6)
		if Gear.CHARMS.has(id):
			cid = "" if cid == id else id  # un second toucher l'ôte : on peut partir sans charme
			_ct = _t
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
	var d := p - _press_pos
	# glissé horizontal sur le râtelier ou la bande : pinceau voisin (vers la gauche : le suivant)
	if _t >= 0.25 and absf(d.x) > 40.0 * _u and absf(d.x) > 1.5 * absf(d.y) and _press_pos.y < _Y(410.0):
		tap("next" if d.x < 0.0 else "prev")
		return
	if start == "":
		return
	if _target_at(p) == start or d.length() <= 24.0 * _u:
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


# ------------------------------------------------------------------ repère de la maquette

## y de la maquette -> écran : sous l'encoche, resserré ; la place en trop (écran haut) aère avant les omamori
## et avant PARTIR (aucune forme ne chevauche ces coupures).
func _Y(y: float) -> float:
	var off := 0.0
	if y >= 775.0:
		off = _extra
	elif y >= 590.0:
		off = _extra * 0.55
	elif y >= 100.0:
		off = _extra * 0.25
	return _top + y * _v + off


func _P(x: float, y: float) -> Vector2:
	return Vector2(x * _u, _Y(y))


## Points de la maquette (repère local `o`, tourné de `rot`) vers l'écran.
func _map(pts: PackedVector2Array, o := Vector2.ZERO, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		var q := pts[i].rotated(rot) + o
		out[i] = _P(q.x, q.y)
	return out


func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var s := 1.0 - t
	return p0 * s * s * s + p1 * 3.0 * s * s * t + p2 * 3.0 * s * t * t + p3 * t * t * t


## Courbe de Bézier ajoutée à `pts` (sans son premier point).
func _cub(pts: PackedVector2Array, p1: Vector2, p2: Vector2, p3: Vector2, n := 10) -> void:
	var p0 := pts[pts.size() - 1]
	for i in range(1, n + 1):
		pts.append(_bez(p0, p1, p2, p3, float(i) / float(n)))


func _hash(i: float) -> float:
	var s := sin(i * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)


## Couleur vue au lavis : `c` posée à l'opacité `op` sur le papier (pas de chevauchement plus sombre).
func _fade(c: Color, op: float) -> Color:
	return PAPER.lerp(c, op) if op < 1.0 else c


func _font(base: Font, sp: float) -> Font:
	var px := int(roundf(sp * _k))
	var key := "%d|%d" % [base.get_instance_id(), px]
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = base
		fv.spacing_glyph = px
		_fonts[key] = fv
	return _fonts[key]


## Texte au repère de la maquette (ligne de base), aligné à gauche (0), au centre (1) ou à droite (2) ;
## `maxw` (repère) : la taille baisse jusqu'à tenir. Renvoie la largeur dessinée (px).
func _txt(base: Font, sp: float, s: String, x: float, y: float, fs: float, col: Color, align := 0, maxw := 0.0) -> float:
	var f := _font(base, sp)
	var px := maxi(6, int(roundf(fs * _k)))
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	while maxw > 0.0 and px > 7 and tw > maxw * _u:
		px -= 1
		tw = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var inner := tw - roundf(sp * _k)  # l'espacement suit aussi la dernière lettre
	var p := _P(x, y)
	if align == 1:
		p.x -= inner / 2.0
	elif align == 2:
		p.x -= inner
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	return tw


func _lines(s: String, fs: float, maxw: float) -> PackedStringArray:
	return UiKit.wrap(UiKit.UI_FONT, s, maxi(6, int(roundf(fs * _k))), maxw * _u, [":", "·", "%"])


func _has_kanji(s: String) -> bool:
	for i in s.length():
		if not UiKit.UI_FONT.has_char(s.unicode_at(i)):
			return false
	return true


## Rectangle arrondi (repère local centré), tourné de `rot`, en points.
func _rrect(hw: float, hh: float, r: float, rot: float, c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [Vector2(hw - r, -hh + r), Vector2(hw - r, hh - r), Vector2(-hw + r, hh - r), Vector2(-hw + r, -hh + r)]
	for q in 4:
		for i in 5:
			var ang := -PI / 2.0 + PI / 2.0 * float(q) + PI / 2.0 * float(i) / 4.0
			pts.append((cs[q] as Vector2) + Vector2.from_angle(ang) * r)
	return _map(pts, c, rot)


## Contour en tirets le long d'une boucle (px).
func _dashed(loop: PackedVector2Array, col: Color, w: float, on: float, off: float) -> void:
	var acc := 0.0
	var n := loop.size()
	for i in n:
		var a := loop[i]
		var b := loop[(i + 1) % n]
		var l := a.distance_to(b)
		var s := 0.0
		while s < l:
			var ph := fmod(acc + s, on + off)
			var step := minf(l - s, (on - ph) if ph < on else (on + off - ph))
			if ph < on:
				draw_line(a.lerp(b, s / l), a.lerp(b, (s + step) / l), col, w, true)
			s += maxf(step, 0.01)
		acc += l


func _ring(loop: PackedVector2Array, col: Color, w: float) -> void:
	var cl := loop.duplicate()
	cl.append(loop[0])
	draw_polyline(cl, col, w, true)


# ------------------------------------------------------------------ dessin

func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	_safe = UiKit.safe_insets(size)
	var dt := UiKit.real_delta()
	_t += dt
	_shake = maxf(0.0, _shake - dt * 2.2)
	modulate.a = UiKit.ease_out(clampf(_t / 0.3, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if meta == null or size.x < 10.0:
		return
	_hits.clear()
	var w := size.x
	var h := size.y
	_u = w / DW
	var avail := h - _safe.x - _safe.y
	_v = minf(_u, avail / DH)
	_k = minf(_u, _v)
	_top = _safe.x
	_extra = maxf(0.0, avail - DH * _v)
	var bid := brush_id()
	var bd: Dictionary = Gear.brush(bid)
	var bopen := brush_open()
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_draw_paper()
	_draw_head(w)
	_draw_rack()
	# nom et devise
	var tag: Array = TAG.get(bid, [String(bd["name"]), String(bd["sub"]).to_upper()])
	_txt(UiKit.TITLE_FONT, 5.0, String(tag[0]), 195.0, 290.0, 24.0, SUMI, 1, 360.0)
	var jp := String(bd["jp"])
	_txt(UiKit.UI_FONT, 2.0, (jp + " · " if _has_kanji(jp) else "") + String(tag[1]), 195.0, 308.0, 11.0, SUB, 1, 360.0)
	_draw_strip(bid, bopen, bd)
	# règle du pinceau
	var rl := _lines(String(bd["rule"]), 12.5, 346.0)
	for li in mini(rl.size(), 2):
		_txt(UiKit.UI_FONT, 0.0, rl[li], 22.0, 430.0 + 15.0 * li - (6.0 if rl.size() > 1 else 0.0), 12.5, INK_TEXT)
	_txt(UiKit.UI_FONT, 3.0, "ASPECTS", 22.0, 462.0, 10.0, CAPTION)
	_draw_aspects(bid, bopen, bd)
	_txt(UiKit.UI_FONT, 3.0, "OMAMORI · UN SEUL", 22.0, 598.0, 10.0, CAPTION)
	_draw_charms()
	_draw_card()
	_draw_go()


## Fibres du washi et soleil pâle derrière la bande.
func _draw_paper() -> void:
	for i in 44:
		var x := _hash(i) * DW
		var y := 100.0 + _hash(i + 99) * 700.0
		var ang := _hash(i + 7) * 3.1
		var l := 6.0 + _hash(i + 3) * 16.0
		draw_line(_P(x, y), _P(x + cos(ang) * l, y + sin(ang) * l), Color(FIBER, 0.25 + 0.3 * _hash(i + 11)), maxf(1.0, (0.6 + _hash(i + 5)) * _k), true)
	draw_circle(_P(352, 372), 34.0 * _k, Color(Color("#D7372B"), 0.10))


## En-tête sumi au bord inférieur brossé, bouton retour rond, titre espacé.
func _draw_head(w: float) -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0)])
	var edge := PackedVector2Array([Vector2(390, 92)])
	_cub(edge, Vector2(300, 100), Vector2(240, 88), Vector2(195, 94), 12)
	_cub(edge, Vector2(130, 102), Vector2(70, 90), Vector2(0, 96), 12)
	for q in edge:
		pts.append(_P(q.x, q.y))
	draw_colored_polygon(pts, SUMI)
	var bc := _P(38, 46)
	var br := 22.0 * _k
	var pr := _pressed == "back"
	draw_arc(bc, br, 0.0, TAU, 40, Color(PAPER, 0.6 if pr else 0.35), 1.5 * _k, true)
	if pr:
		draw_circle(bc, br - 1.0, Color(PAPER, 0.08))
	var s := 10.0 / 12.0 * _k * 0.83
	var chev := PackedVector2Array([bc + Vector2(3, -7) * s * 1.2, bc + Vector2(-4, 0) * s * 1.2, bc + Vector2(3, 7) * s * 1.2])
	draw_polyline(chev, PAPER, 2.2 * _k, true)
	var hs := maxf(UiKit.TOUCH_MIN, 52.0 * _k) / 2.0
	_hits.append([Rect2(bc - Vector2(hs, hs), Vector2(hs, hs) * 2.0), "back"])
	_txt(UiKit.TITLE_FONT, 5.0, "AVANT LE DÉPART", 70.0, 53.0, 20.0, PAPER, 0, 300.0)


## Le râtelier : barre de bois, embouts, cinq pinceaux pendus (le choisi descend, cordon vermillon).
func _draw_rack() -> void:
	draw_colored_polygon(_rrect(177, 4.5, 4, 0.0, Vector2(195, 118.5)), WOOD)
	draw_colored_polygon(_rrect(177, 1.5, 1.5, 0.0, Vector2(195, 115.5)), WOOD_HI)
	draw_circle(_P(24, 118), 7.0 * _k, WOOD_DARK)
	draw_circle(_P(366, 118), 7.0 * _k, WOOD_DARK)
	var drop := UiKit.ease_out(clampf((_t - _bt) / 0.35, 0.0, 1.0))
	for i in Gear.ORDER.size():
		var id := String(Gear.ORDER[i])
		var sel := i == bi
		var x := 55.0 + float(i) * 70.0
		var y := 160.0 + (14.0 * drop if sel else 0.0)
		var opn := meta != null and bool(meta.brush_unlocked(id))
		var op := 1.0 if opn else 0.35
		_draw_brush(id, Vector2(x, y), sel, opn, op)
		if not opn:
			_txt(UiKit.UI_FONT, 0.5, "MONDE %d" % int(Gear.brush(id)["world"]), x, 262.0, 8.5, MUTED, 1)
		var r := Rect2(_P(x - 30.0, 120.0), Vector2(60.0 * _u, _Y(270.0) - _Y(120.0)))
		_hits.append([r, "brush:" + id])


func _draw_brush(id: String, o: Vector2, sel: bool, opn: bool, op: float) -> void:
	var hd: Array = HANDLE.get(id, HANDLE["fude"])
	var hl := float(hd[1])
	var wd := _fade(WOOD_DARK, op)
	draw_line(_P(o.x, o.y - 40.0), _P(o.x, o.y - 26.0), wd, 1.5 * _k, true)
	draw_arc(_P(o.x, o.y - 41.0), 2.5 * _k, 0.0, TAU, 16, wd, 1.5 * _k, true)
	if sel:
		var cord := _fade(CORD, op)
		draw_colored_polygon(_map(PackedVector2Array([Vector2(-6, -33), Vector2(0, -27), Vector2(6, -33), Vector2(0, -39)]), o), cord)
		draw_line(_P(o.x - 3, o.y - 27), _P(o.x - 5, o.y - 18), cord, 1.6 * _k, true)
		draw_line(_P(o.x + 3, o.y - 27), _P(o.x + 5, o.y - 18), cord, 1.6 * _k, true)
	var hcol := _fade(hd[0] if opn else GREY, op)
	draw_colored_polygon(_map(PackedVector2Array([Vector2(-hl, -26), Vector2(hl, -26), Vector2(hl + 0.4, 44), Vector2(-hl - 0.4, 44)]), o), hcol)
	for ny in [-6.0, 18.0]:
		draw_line(_P(o.x - hl, o.y + ny), _P(o.x + hl, o.y + ny), hcol.darkened(0.25), 1.6 * _k, true)
	var fcol := _fade(GOLD if id == "chi" else Color("#2A2A2E"), op)
	var tcol := _fade(Color("#4A0F0A") if id == "chi" else SUMI, op)
	var fer: PackedVector2Array
	var tip := PackedVector2Array()
	match id:
		"hake":
			fer = PackedVector2Array([Vector2(-12, 44), Vector2(12, 44), Vector2(12, 52), Vector2(-12, 52)])
			tip.append_array([Vector2(-12, 52), Vector2(12, 52), Vector2(11, 74)])
			_cub(tip, Vector2(6, 78), Vector2(-6, 78), Vector2(-11, 74), 8)
		"menso":
			fer = PackedVector2Array([Vector2(-3.4, 44), Vector2(3.4, 44), Vector2(3.6, 50), Vector2(-3.6, 50)])
			tip.append(Vector2(-3.6, 50))
			_cub(tip, Vector2(-4, 62), Vector2(-1.5, 74), Vector2(0, 84), 10)
			_cub(tip, Vector2(1.5, 74), Vector2(4, 62), Vector2(3.6, 50), 10)
		"warefude":
			fer = PackedVector2Array([Vector2(-5, 44), Vector2(5, 44), Vector2(5.4, 51), Vector2(-5.4, 51)])
			# deux touffes (le pinceau fendu) : chacune son polygone
			var ta := PackedVector2Array([Vector2(-5.4, 51)])
			_cub(ta, Vector2(-7, 60), Vector2(-6, 68), Vector2(-4, 76), 8)
			_cub(ta, Vector2(-2, 70), Vector2(-0.6, 62), Vector2(-0.4, 54), 8)
			ta.append(Vector2(0, 51))
			var tb := PackedVector2Array([Vector2(0, 51), Vector2(0.4, 54)])
			_cub(tb, Vector2(0.6, 62), Vector2(2, 70), Vector2(4, 76), 8)
			_cub(tb, Vector2(6, 68), Vector2(7, 60), Vector2(5.4, 51), 8)
			draw_colored_polygon(_map(fer, o), fcol)
			draw_colored_polygon(_map(ta, o), tcol)
			draw_colored_polygon(_map(tb, o), tcol)
			return
		_:
			fer = PackedVector2Array([Vector2(-4.6, 44), Vector2(4.6, 44), Vector2(5, 51), Vector2(-5, 51)])
			tip.append(Vector2(-5, 51))
			_cub(tip, Vector2(-8, 60), Vector2(-4, 72), Vector2(0, 80), 10)
			_cub(tip, Vector2(4, 72), Vector2(8, 60), Vector2(5, 51), 10)
	draw_colored_polygon(_map(fer, o), fcol)
	draw_colored_polygon(_map(tip, o), tcol)


## Bande de trait (repère de la maquette) : largeur w0 -> w1 le long d'une Bézier, attaque appuyée, frémissement ;
## `reveal` : part du trait posée.
func _band(c: Array, w0: float, w1: float, sd: float, wob: float, reveal: float) -> PackedVector2Array:
	var n := 40
	var m := maxi(2, int(ceil(float(n) * clampf(reveal, 0.0, 1.0))))
	var L := PackedVector2Array()
	var R := PackedVector2Array()
	for i in m + 1:
		var t := float(i) / float(n)
		var a := _bez(c[0], c[1], c[2], c[3], maxf(0.0, t - 0.01))
		var b := _bez(c[0], c[1], c[2], c[3], minf(1.0, t + 0.01))
		var p := _bez(c[0], c[1], c[2], c[3], t)
		var d := (b - a).normalized()
		var att := minf(1.0, t / 0.08 + 0.35)
		var hw := (w0 + (w1 - w0) * t) * att * (1.0 + wob * sin(t * 19.0 + sd) + 0.08 * (_hash(sd * 40.0 + float(i)) - 0.5)) / 2.0
		L.append(Vector2(p.x - d.y * hw, p.y + d.x * hw))
		R.append(Vector2(p.x + d.y * hw, p.y - d.x * hw))
	R.reverse()
	L.append_array(R)
	return _map(L)


## Bande de papier : le pinceau y peint son trait ; au lavis, avec l'étiquette vermillon, s'il reste à gagner.
func _draw_strip(bid: String, bopen: bool, bd: Dictionary) -> void:
	var sp := PackedVector2Array([Vector2(14, 326)])
	_cub(sp, Vector2(80, 320), Vector2(300, 330), Vector2(376, 322), 12)
	var top := sp.duplicate()
	sp.append(Vector2(378, 404))
	_cub(sp, Vector2(300, 410), Vector2(90, 400), Vector2(12, 406), 12)
	draw_colored_polygon(_map(sp), PAPER_HI)
	draw_polyline(_map(top), Color("#CDBF9F"), maxf(1.0, _k), true)
	var rv := UiKit.ease_out(clampf((_t - _bt - 0.1) / 0.7, 0.0, 1.0))
	var ink := LAVIS if not bopen else SUMI
	var V := func(x: float, y: float) -> Vector2: return Vector2(x, y)
	match bid:
		"hake":
			for k in 5:
				var c := [V.call(30, 386 + k * 1.5 - 4), V.call(90, 352 + k * 3), V.call(150, 344 + k * 3), V.call(200, 344 + k * 3)]
				draw_colored_polygon(_band(c, 7, 3, k * 3, 0.25, rv), Color(ink, 0.85))
		"menso":
			draw_colored_polygon(_band([V.call(30, 390), V.call(120, 350), V.call(250, 334), V.call(366, 330)], 3.2, 0.6, 2, 0.1, rv), ink)
		"warefude":
			draw_colored_polygon(_band([V.call(30, 380), V.call(110, 344), V.call(230, 330), V.call(356, 334)], 7, 1.6, 4, 0.12, rv), ink)
			draw_colored_polygon(_band([V.call(38, 398), V.call(118, 362), V.call(238, 348), V.call(362, 352)], 7, 1.6, 9, 0.12, rv), ink)
		_:
			var ci := Color("#3A0D08") if bid == "chi" and bopen else ink
			draw_colored_polygon(_band([V.call(36, 388), V.call(110, 352), V.call(230, 338), V.call(356, 342)], 15, 2.2, 3, 0.15, rv), ci)
			if bid == "chi":
				var drops := [[262, 334, 3.4, 0.6], [292, 348, 2.4, 0.7], [318, 334, 2.8, 0.8], [340, 352, 2.0, 0.9]]
				for q in drops:
					if rv >= float(q[3]):
						draw_circle(_P(q[0], q[1]), float(q[2]) * _k, Color(RED_DARK, 0.3 if not bopen else 0.9))
	if not bopen:
		var lab := "À GAGNER · BOSS DU MONDE %d" % int(bd["world"])
		var f := _font(UiKit.UI_FONT, 1.2)
		var px := maxi(7, int(roundf(9.5 * _k)))
		var tw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var lw := tw + 16.0 * _k
		var lh := 20.0 * _k
		draw_set_transform(_P(370, 330), deg_to_rad(-3.0), Vector2.ONE)
		var box := StyleBoxFlat.new()
		UiKit.box(box, LOCK_RED, int(3.0 * _k))
		draw_style_box(box, Rect2(Vector2(-lw, 0), Vector2(lw, lh)))
		draw_string(f, Vector2(-lw + 8.0 * _k + roundf(1.2 * _k) * 0.5, 14.0 * _k), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, px, PAPER_HI)
		draw_set_transform_matrix(Transform2D.IDENTITY)


## Les trois aspects en sceaux hanko : vermillon si acquis, pointillé sinon ; cadre doré sur le choisi.
func _draw_aspects(bid: String, bopen: bool, bd: Dictionary) -> void:
	var asp: Array = bd["aspects"]
	var who := String(TAG.get(bid, [String(bd["word"])])[0])
	for k in 3:
		var x := 75.0 + float(k) * 120.0
		var c := Vector2(x, 504)
		var own := aspect_open(k)
		var sel := k == ak
		if sel:
			_ring(_rrect(36, 36, 10, 0.0, c), GOLD, 2.5 * _k)
		var rot := deg_to_rad((_hash(float(k + bi * 3)) - 0.5) * 10.0)
		var outer := _rrect(29, 29, 7, rot, c)
		if own:
			draw_colored_polygon(outer, SEAL)
			_ring(outer, SEAL_EDGE, maxf(1.0, _k))
			_ring(_rrect(24, 24, 4, rot, c), Color(PAPER_HI, 0.6), maxf(1.0, _k))
		else:
			_dashed(outer, DASH, 1.6 * _k, 5.0 * _k, 4.0 * _k)
		var nm := String(asp[k][0]).to_upper()
		var fs := 9.5 if nm.length() >= 7 else (10.5 if nm.length() >= 6 else 12.0)
		_txt(UiKit.TITLE_FONT, 1.0, nm, x, 509.0, fs, PAPER_HI if own else Color("#A09480"), 1, 52.0)
		var cap := "ACQUIS" if own else ("BOSS AVEC " + who if bopen else "PINCEAU À GAGNER")
		_txt(UiKit.UI_FONT, 0.5, cap, x, 552.0, 8.5, OK_GREEN if own else MUTED, 1, 116.0)
		var hs := maxf(UiKit.TOUCH_MIN, 72.0 * _k) / 2.0
		_hits.append([Rect2(_P(x, 504) - Vector2(hs, hs), Vector2(hs, hs) * 2.0), "asp:%d" % k])
	var al := _lines(String(asp[ak][1]), 11.5, 350.0)
	for li in mini(al.size(), 2):
		_txt(UiKit.UI_FONT, 0.0, al[li], 195.0, 570.0 + 14.0 * li - (6.0 if al.size() > 1 else 0.0), 11.5, INK_TEXT, 1)


## Cordelette vermillon en arc, huit omamori pendus ; le choisi se soulève dans un halo d'or.
func _draw_charms() -> void:
	var cord := PackedVector2Array([Vector2(10, 616)])
	_cub(cord, Vector2(110, 632), Vector2(280, 632), Vector2(380, 616), 24)
	draw_polyline(_map(cord), CORD, 2.0 * _k, true)
	var lift := UiKit.ease_out(clampf((_t - _ct) / 0.3, 0.0, 1.0))
	for i in Gear.CHARM_ORDER.size():
		var id := String(Gear.CHARM_ORDER[i])
		var cd: Dictionary = Gear.charm(id)
		var x := 30.0 + float(i) * 47.0
		var sel := id == cid
		var y := 626.0 + sin((x - 10.0) / 370.0 * PI) * 10.0 + (6.0 * lift if sel else 0.0)
		var own := charm_open(id)
		var op := 1.0 if own else 0.4
		var o := Vector2(x, y)
		var red := _fade(CORD, op)
		draw_line(_P(x, y - 8), _P(x, y + 2), red, 1.5 * _k, true)
		var loop := PackedVector2Array([Vector2(-4, 3)])
		_cub(loop, Vector2(-4, -1), Vector2(4, -1), Vector2(4, 3), 8)
		draw_polyline(_map(loop, o), red, 2.0 * _k, true)
		if sel:
			var halo := PackedVector2Array()
			for j in 32:
				var ang := TAU * float(j) / 32.0
				halo.append(Vector2(cos(ang) * 24.0, 26.0 + sin(ang) * 32.0))
			draw_colored_polygon(_map(halo, o), Color(GOLD_HI, 0.28))
		var col := _fade(cd["col"] if own else GREY, op)
		var body := PackedVector2Array([Vector2(-15, 10)])
		_cub(body, Vector2(-15, 4), Vector2(-9, 3), Vector2(0, 3), 6)
		_cub(body, Vector2(9, 3), Vector2(15, 4), Vector2(15, 10), 6)
		body.append(Vector2(15, 46))
		_cub(body, Vector2(15, 49), Vector2(13, 50), Vector2(10, 50), 4)
		body.append(Vector2(-10, 50))
		_cub(body, Vector2(-13, 50), Vector2(-15, 49), Vector2(-15, 46), 4)
		var bp := _map(body, o)
		draw_colored_polygon(bp, col)
		var gl := _fade(GOLD_HI, 0.7 * op)
		draw_line(_P(x - 15, y + 16), _P(x + 15, y + 16), gl, maxf(1.0, _k), true)
		draw_line(_P(x - 15, y + 44), _P(x + 15, y + 44), gl, maxf(1.0, _k), true)
		_ring(bp, _fade(SUMI, op), 1.5 * _k)
		draw_colored_polygon(_rrect(9, 11, 2, 0.0, o + Vector2(0, 30)), _fade(PAPER_HI, op) if own else PAPER_HI.lerp(PAPER, 0.3))
		Kamon.draw(self, "om_" + id, _P(x, y + 30), 0.62 * _k, col)
		var hw := maxf(UiKit.TOUCH_MIN, 46.0 * _u)
		var r := Rect2(Vector2(_P(x, 0).x - hw / 2.0, _Y(612.0)), Vector2(hw, maxf(UiKit.TOUCH_MIN, _Y(680.0) - _Y(612.0))))
		_hits.append([r, "charm:" + id])


## Étiquette de papier du charme choisi : pastille, nom, effet, état (porté / à gagner).
func _draw_card() -> void:
	var sp := PackedVector2Array([Vector2(18, 688)])
	_cub(sp, Vector2(90, 682), Vector2(300, 692), Vector2(372, 686), 12)
	sp.append(Vector2(374, 768))
	_cub(sp, Vector2(300, 774), Vector2(90, 766), Vector2(16, 772), 12)
	draw_colored_polygon(_map(sp), PAPER_HI)
	if cid == "":
		draw_arc(_P(36, 711), 5.0 * _k, 0.0, TAU, 20, GREY, 1.5 * _k, true)
		_txt(UiKit.TITLE_FONT, 1.0, "Sans omamori", 50.0, 716.0, 16.0, SUMI)
		_txt(UiKit.UI_FONT, 0.0, "Touche un omamori pour le porter : un seul par partie.", 32.0, 740.0, 11.5, INK_TEXT, 0, 330.0)
		_txt(UiKit.UI_FONT, 1.5, "LE CORDON RESTE VIDE", 32.0, 760.0, 9.5, MUTED)
		return
	var cd: Dictionary = Gear.charm(cid)
	var own := charm_open(cid)
	draw_circle(_P(36, 711), 6.0 * _k, cd["col"] if own else GREY)
	_txt(UiKit.TITLE_FONT, 1.0, "Omamori · " + String(cd["short"]), 50.0, 716.0, 16.0, SUMI, 0, 310.0)
	var el := _lines(String(cd["effect"]), 11.5, 330.0)
	var two := el.size() > 1
	for li in mini(el.size(), 2):
		_txt(UiKit.UI_FONT, 0.0, el[li], 32.0, (733.0 if two else 738.0) + 14.0 * li, 11.5, INK_TEXT)
	var st := "PORTÉ POUR CETTE PARTIE" if own else "À GAGNER : RANG MAÎTRE AU MONDE %d" % int(cd["world"])
	_txt(UiKit.UI_FONT, 1.5, st, 32.0, 761.0 if two else 757.0, 9.5, OK_GREEN if own else RED_DARK, 0, 330.0)


## PARTIR : coup d'encre plein ; au lavis, avec la raison, quand un choix reste à gagner.
func _draw_go() -> void:
	var ok := can_go()
	var dx := sin(_shake * 26.0) * 6.0 * _u * _shake
	var press := _pressed == "go" and ok
	var blob := PackedVector2Array([Vector2(28, 808)])
	_cub(blob, Vector2(30, 786), Vector2(80, 780), Vector2(150, 782), 10)
	_cub(blob, Vector2(220, 784), Vector2(300, 778), Vector2(352, 786), 10)
	_cub(blob, Vector2(372, 790), Vector2(366, 822), Vector2(344, 828), 10)
	_cub(blob, Vector2(280, 838), Vector2(200, 830), Vector2(130, 834), 10)
	_cub(blob, Vector2(80, 836), Vector2(34, 832), Vector2(28, 808), 10)
	var bp := _map(blob)
	var cen := _P(195, 808)
	var xf := Transform2D(0.0, Vector2.ONE * (0.97 if press else 1.0), 0.0, Vector2(dx, 0))
	for i in bp.size():
		bp[i] = cen + xf * (bp[i] - cen)
	draw_colored_polygon(bp, SUMI if ok else GO_OFF)
	if ok:
		var hl := PackedVector2Array([Vector2(60, 806)])
		_cub(hl, Vector2(150, 800), Vector2(250, 812), Vector2(340, 804), 16)
		var hp := _map(hl)
		for i in hp.size():
			hp[i].x += dx
		draw_polyline(hp, Color(PAPER_HI, 0.15), maxf(1.0, _k), true)
	var gl := go_label()
	_txt(UiKit.TITLE_FONT, 7.0 if ok else 3.0, gl, 195.0 + dx / _u, 815.0 if ok else 813.0, 20.0 if ok else 14.0, PAPER_HI if ok else GO_OFF_INK, 1, 300.0)
	go_rect = Rect2(_P(28, 780), Vector2(340.0 * _u, _Y(836.0) - _Y(780.0)))
	_hits.append([go_rect, "go"])
