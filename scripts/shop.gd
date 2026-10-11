extends Control
## Échoppe du marchand tanuki (main._open_shop) : feuille de washi sur voile d'encre, en-tête à vagues seigaiha,
## bouton retour, titre MARCHAND et l'or de la partie (koban). Trois ou quatre articles en tuiles : pastille
## (pictogramme ou pouvoir), nom, effet en une ou deux lignes, prix (koban et somme) à droite. Article acheté :
## barré d'un coup de pinceau, sceau VENDU ; or insuffisant : tuile grisée, prix en vermillon (le toucher la fait
## trembler) ; article sans effet maintenant (cœurs pleins…) : grisé, sa raison à la place du prix.
## main fournit les articles ({id, name, line, glyph | power, col, price, sold, can, why}) et l'or ; un toucher
## sur une tuile émet `bought(i)` (main vérifie, retire l'or et rafraîchit), PARTIR ou retour émet `closed`.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")

signal bought(i: int)
signal closed

const INPUT_DELAY := 0.3  # le toucher qui a ouvert l'échoppe ne doit rien acheter
const NO_TARGET := -2
const BACK_TARGET := -1
const LEAVE_TARGET := 100
const HEAD := 64.0  # bande seigaiha de l'en-tête (× u)
const ROW_TOP := 104.0  # première tuile (× u depuis le haut de la feuille)
const TILE_H := 80.0
const TILE_GAP := 10.0
const FOOT := 92.0  # sous les tuiles : bouton PARTIR et marge (× u)
const PRICE_W := 74.0
const PRICE_H := 34.0
const GLUE := [":", ";", "!", "?", "%", "→", "·"]

var items: Array = []
var gold := 0
var _t := 0.0
var _pressed := NO_TARGET
var _shake := {}  # tuile -> tremblement 1 -> 0 (or insuffisant)
var _flash := {}  # tuile -> éclat d'or 1 -> 0 (achat)
var _tile_rects: Array = []
var _leave_rect := Rect2()
var _back := Rect2()
var _ui := FontVariation.new()
var _title := FontVariation.new()
var _btn := FontVariation.new()
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = UiKit.CAPS_SPACING
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = UiKit.TITLE_SPACING
	_btn.base_font = UiKit.TITLE_FONT
	_btn.spacing_glyph = 4


func open(its: Array, g: int) -> void:
	items = its
	gold = g
	_t = 0.0
	_pressed = NO_TARGET
	_shake.clear()
	_flash.clear()
	_tile_rects.clear()
	visible = true


## Après un achat : articles et or à jour, sans rejouer l'ouverture ; `i` : la tuile achetée (éclat d'or).
func refresh(its: Array, g: int, i := -1) -> void:
	items = its
	gold = g
	if i >= 0:
		_flash[i] = 1.0
	queue_redraw()


## Prêt à recevoir un toucher (ouverture finie).
func ready_for_input() -> bool:
	return visible and _t >= INPUT_DELAY and not _tile_rects.is_empty()


## L'article `i` peut être acheté maintenant (pas vendu, utile, assez d'or).
func can_buy(i: int) -> bool:
	if i < 0 or i >= items.size():
		return false
	var it: Dictionary = items[i]
	return not bool(it.get("sold", false)) and bool(it.get("can", true)) and gold >= int(it.get("price", 0))


func _target_at(p: Vector2) -> int:
	if _back.has_point(p):
		return BACK_TARGET
	if _leave_rect.has_point(p):
		return LEAVE_TARGET
	for i in _tile_rects.size():
		var r: Rect2 = _tile_rects[i]
		if r.has_point(p):
			return i
	return NO_TARGET


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	accept_event()
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _t < INPUT_DELAY:
		_pressed = NO_TARGET
		return
	var target := _target_at(mb.position)
	if mb.pressed:
		_pressed = target
		return
	# relâché : on n'agit que si l'appui et le relâché tombent sur la même cible
	var start := _pressed
	_pressed = NO_TARGET
	if target == NO_TARGET or target != start:
		return
	if target == BACK_TARGET or target == LEAVE_TARGET:
		visible = false
		closed.emit()
		return
	var it: Dictionary = items[target]
	if bool(it.get("sold", false)):
		return
	if not can_buy(target):
		_shake[target] = 1.0  # trop cher, ou sans effet maintenant : la tuile tremble
		return
	bought.emit(target)


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var d := UiKit.real_delta()
	_t += d
	for k in _shake.keys():
		_shake[k] = maxf(0.0, float(_shake[k]) - d / 0.35)
	for k in _flash.keys():
		_flash[k] = maxf(0.0, float(_flash[k]) - d / 0.6)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	var n := maxi(1, items.size())
	var card_h := ROW_TOP + float(n) * (TILE_H + TILE_GAP) - TILE_GAP + FOOT
	var u := minf(w / 400.0, h / (card_h + 40.0))
	var a := clampf(_t / 0.25, 0.0, 1.0)
	var ka := UiKit.ease_out(a)
	var ink: Color = Toon.ui_ink
	var paper: Color = Toon.ui_paper
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.85 * a))
	var card := Rect2(Vector2(w * 0.06, h * 0.5 - card_h * 0.5 * u + 14.0 * u * (1.0 - ka)), Vector2(w * 0.88, card_h * u))
	UiKit.sheet(self, card, paper, ink, a, u, 5.0, HEAD)
	# en-tête : retour, titre souligné de vermillon, or de la partie à droite
	var bc := card.position + Vector2(UiKit.HEAD_X, UiKit.HEAD_Y) * u
	_back = UiKit.back_rect(bc, u)
	UiKit.back_button(self, bc, u, a, 1.0 if _pressed == BACK_TARGET else 0.0)
	var nf := UiKit.num_font()
	var gfs := int(15 * u)
	var gtxt := str(gold)
	var gw := nf.get_string_size(gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, gfs).x
	var pill := Rect2(Vector2(card.end.x - 16.0 * u - (34.0 * u + gw), card.position.y + UiKit.HEAD_Y * u - 15.0 * u), Vector2(34.0 * u + gw, 30.0 * u))
	draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI, 0.92 * a), int(pill.size.y / 2.0)), pill)
	UiKit.koban(self, Vector2(pill.position.x + 15.0 * u, pill.get_center().y), 8.5 * u, a)
	draw_string(nf, Vector2(pill.position.x + 27.0 * u, pill.get_center().y + gfs * 0.36), gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, gfs, Color(UIColors.GOLD.lightened(0.25), a))
	var side := maxf((UiKit.HEAD_X + 26.0) * u, card.end.x - pill.position.x + 6.0 * u)
	var tmax: float = card.size.x - 2.0 * side
	UiKit.screen_title(self, _title, "MARCHAND", Vector2(card.get_center().x, card.position.y + UiKit.HEAD_BASE * u), u, ink, a, "", tmax, UiKit.ease_out(clampf((_t - 0.1) / 0.4, 0.0, 1.0)))
	var cfs := int(UiKit.FS_CAPTION * u)
	UiKit.text(self, _ui, UiKit.plain("LE TANUKI VEND CONTRE DE L'OR"), Vector2(card.get_center().x, card.position.y + 88.0 * u), cfs, Color(ink, UiKit.A_CAPTION * a))
	# tuiles
	_tile_rects.clear()
	var x0 := card.position.x + UiKit.SP_M * u
	var tw := card.size.x - 2.0 * UiKit.SP_M * u
	var y := card.position.y + ROW_TOP * u
	for i in items.size():
		var r := Rect2(Vector2(x0, y), Vector2(tw, TILE_H * u))
		_tile_rects.append(r)
		# les tuiles arrivent l'une après l'autre
		var ti := UiKit.ease_out(clampf((_t - 0.08 - 0.06 * float(i)) / 0.3, 0.0, 1.0))
		_tile(r, items[i], i, u, a * ti, (1.0 - ti) * 10.0 * u)
		y += (TILE_H + TILE_GAP) * u
	# PARTIR : pilule d'encre
	var lw := minf(220.0 * u, tw)
	_leave_rect = Rect2(Vector2(card.get_center().x - lw / 2.0, card.end.y - (FOOT - 22.0) * u), Vector2(lw, 50.0 * u))
	var lr := _leave_rect.grow(-1.5 * u) if _pressed == LEAVE_TARGET else _leave_rect
	draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.2 * a), int(lr.size.y / 2.0)), Rect2(lr.position + Vector2(0, 3.0 * u), lr.size))
	draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI, a), int(lr.size.y / 2.0), Color(Toon.VERMILION, 0.9 * a), maxi(1, int(2.0 * u))), lr)
	var bfs := int(17 * u)
	var lab := "PARTIR"
	var bw := _btn.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x - 4.0
	draw_string(_btn, Vector2(lr.get_center().x - bw / 2.0, lr.get_center().y + bfs * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(UIColors.WASHI, a))


## Une tuile d'article : cadre, pastille, nom et effet, prix (ou VENDU, ou la raison).
func _tile(r0: Rect2, it: Dictionary, i: int, u: float, a: float, dy: float) -> void:
	if a <= 0.01:
		return
	var ink: Color = Toon.ui_ink
	var sold := bool(it.get("sold", false))
	var useful := bool(it.get("can", true))
	var afford := gold >= int(it.get("price", 0))
	var on := not sold and useful and afford
	var r := r0
	r.position.y += dy
	var sk := float(_shake.get(i, 0.0))
	r.position.x += sin(sk * 26.0) * 6.0 * u * sk
	if _pressed == i and on:
		r = r.grow(-1.5 * u)
	var k := 1.0 if on else (0.55 if sold else 0.45)  # grisé
	var fl := float(_flash.get(i, 0.0))
	var bg := Color(ink, 0.05 * a)
	if fl > 0.0:
		bg = bg.lerp(Color(UIColors.GOLD, 0.35 * a), fl)
	draw_style_box(UiKit.box(_sb, bg, int(UiKit.R_M * u), Color(ink, (0.22 if on else 0.12) * a), maxi(1, int(UiKit.BW * u))), r)
	# pastille
	var c := Vector2(r.position.x + 38.0 * u, r.get_center().y)
	var rr := 24.0 * u
	var col: Color = it.get("col", UIColors.SUMI)
	if String(it.get("power", "")) != "":
		UiKit.power_icon(self, String(it["power"]), c, rr, a * k)
	else:
		draw_circle(c, rr, Color(col, a * k))
		draw_arc(c, rr - 1.0 * u, 0.0, TAU, 32, Color(UIColors.SUMI, 0.35 * a * k), maxf(1.0, 1.2 * u), true)
		UiKit.glyph(self, String(it.get("glyph", "coin")), c, rr * 0.56, Color(UIColors.WASHI, a * k), Color(col, a * k))
	# prix (ou VENDU / raison), à droite
	var pr := Rect2(Vector2(r.end.x - (PRICE_W + 10.0) * u, r.get_center().y - PRICE_H * 0.5 * u), Vector2(PRICE_W, PRICE_H) * u)
	var nf := UiKit.num_font()
	if sold:
		pass  # (le sceau VENDU est posé par-dessus, à la fin)
	elif not useful:
		var why := UiKit.plain(String(it.get("why", "")))
		var wfs := int(UiKit.FS_MICRO * u)
		var ww := _ui.get_string_size(why, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs).x
		if ww > pr.size.x - 8.0 * u and ww > 0.0:
			wfs = maxi(1, int(float(wfs) * (pr.size.x - 8.0 * u) / ww))
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(pr.size.y / 2.0), Color(ink, 0.25 * a), maxi(1, int(1.2 * u))), pr)
		UiKit.text(self, _ui, why, Vector2(pr.get_center().x, pr.get_center().y + wfs * 0.36), wfs, Color(ink, 0.5 * a))
	else:
		var pfs := int(15 * u)
		var ptxt := str(int(it.get("price", 0)))
		var pw := nf.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
		draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI, (0.92 if afford else 0.0) * a), int(pr.size.y / 2.0), Color(Toon.VERMILION if not afford else UIColors.SUMI, (0.75 if not afford else 0.0) * a), maxi(1, int(1.5 * u))), pr)
		var cw := 17.0 * u + 5.0 * u + pw
		var px := pr.get_center().x - cw / 2.0
		UiKit.koban(self, Vector2(px + 8.0 * u, pr.get_center().y), 8.5 * u, a * (1.0 if afford else 0.6))
		var pc: Color = UIColors.GOLD.lightened(0.25) if afford else Toon.VERMILION
		draw_string(nf, Vector2(px + 22.0 * u, pr.get_center().y + pfs * 0.36), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(pc, a))
	# nom et effet entre la pastille et le prix
	var tx := r.position.x + 72.0 * u
	var tmax := pr.position.x - 8.0 * u - tx
	var nfs := int(UiKit.FS_HEADING * u)
	var nm := UiKit.plain(String(it.get("name", "")))
	var nw := _title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	if nw > tmax and nw > 0.0:
		nfs = maxi(1, int(float(nfs) * tmax / nw))
	var bfs := int(UiKit.FS_BODY * u)
	var lines := UiKit.wrap(_ui, UiKit.plain(String(it.get("line", ""))), bfs, tmax, GLUE)
	while lines.size() > 2 and bfs > int(8 * u):
		bfs -= 1
		lines = UiKit.wrap(_ui, UiKit.plain(String(it.get("line", ""))), bfs, tmax, GLUE)
	var lh := float(bfs) * 1.3
	var block := float(nfs) + 6.0 * u + lh * float(mini(lines.size(), 2))
	var ny := r.get_center().y - block / 2.0 + float(nfs) * 0.82
	draw_string(_title, Vector2(tx, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(ink, a * k))
	var ly := ny + 6.0 * u + lh * 0.9
	for li in mini(lines.size(), 2):
		var ltxt := String(lines[li])
		var lw := _ui.get_string_size(ltxt, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		if lw > tmax and lw > 0.0:
			ltxt = ltxt.left(maxi(1, int(float(ltxt.length()) * tmax / lw) - 1)) + "…"
		draw_string(_ui, Vector2(tx, ly), ltxt, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(ink, UiKit.A_SUB * a * k))
		ly += lh
	if sold:
		# barré d'un coup de pinceau, sceau VENDU vermillon à la place du prix
		var sy := r.get_center().y + 1.0 * u
		UiKit.brush_line(self, Vector2(tx - 6.0 * u, sy - 2.0 * u), Vector2(pr.position.x - 2.0 * u, sy + 3.0 * u), 7.0 * u, Color(UIColors.SUMI, 0.85 * a))
		var st := Rect2(Vector2(pr.get_center().x - 34.0 * u, pr.get_center().y - 14.0 * u), Vector2(68.0, 28.0) * u)
		draw_set_transform(st.get_center(), -0.12, Vector2.ONE)
		var sr := Rect2(-st.size / 2.0, st.size)
		draw_colored_polygon(UiKit.deckle_points(sr, 0.9 * u, 4.0 * u, float(i)), Color(Toon.VERMILION, 0.92 * a))
		draw_rect(sr.grow(-3.0 * u), Color(UIColors.WASHI, 0.7 * a), false, maxf(1.0, 1.2 * u))
		var vfs := int(11 * u)
		var vw := _btn.get_string_size("VENDU", HORIZONTAL_ALIGNMENT_LEFT, -1, vfs).x - 4.0
		draw_string(_btn, Vector2(-vw / 2.0, vfs * 0.36), "VENDU", HORIZONTAL_ALIGNMENT_LEFT, -1, vfs, Color(UIColors.WASHI, a))
		draw_set_transform(Vector2.ZERO)
