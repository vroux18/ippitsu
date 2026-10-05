extends Control
## Atelier : la pièce du peintre. Mur de bois sombre, tatami, enseigne gravée,
## et six rouleaux suspendus (kakejiku) = les six lignes de la Pierre à encre.
## Toucher un rouleau l'achète : un sceau vermillon s'y imprime. Retour : ensō d'encre en haut à gauche.

const Toon = preload("res://scripts/toon.gd")
const Meta = preload("res://scripts/meta.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

const WOOD := Color("#2A201B")
const WOOD_LINE := Color("#3A2D26")
const ROD := Color("#4A3426")
# « brush » prend la couleur par défaut, Toon.PRUSSIAN (voir _scroll)
const LINE_COLORS := {
	"ink": Color("#2C2A33"),
	"paper": Color("#9E2A22"),
	"breath": Color("#3F6B67"),
	"purse": Color("#8C6A2A"),
	"choice": Color("#4E3A63"),
}

signal closed

var meta  # instance de meta.gd, fournie par main avant open()

var _t := 0.0
var _down := -1
var _rects: Array = []  # zones tactiles des rouleaux
var _stamp: Array = []  # sceau qui s'imprime (1 -> 0)
var _shake: Array = []  # refus (1 -> 0)
var _bump := 0.0
var _back_rect := Rect2()
var _back_down := false
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 8
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 2
	for i in Meta.ORDER.size():
		_stamp.append(0.0)
		_shake.append(0.0)


func open() -> void:
	_t = 0.0
	_down = -1
	_back_down = false
	_bump = 0.0
	for i in _stamp.size():
		_stamp[i] = 0.0
		_shake[i] = 0.0
	visible = true


func _close() -> void:
	visible = false
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if meta == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if event.pressed:
			# le toucher qui a ouvert l'atelier ne doit pas le refermer
			_back_down = _t >= 0.3 and _back_rect.has_point(p)
			_down = -1 if _back_down or _t < 0.6 else _hit(p)
		else:
			if _back_down and _back_rect.has_point(p):
				_close()
			elif _down >= 0 and _hit(p) == _down:
				_tap(_down)
			_down = -1
			_back_down = false
		accept_event()


func _hit(p: Vector2) -> int:
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		if r.has_point(p):
			return i
	return -1


func _tap(i: int) -> void:
	var id: String = Meta.ORDER[i]
	if meta.buy(id):
		_stamp[i] = 1.0
		_bump = 1.0
	else:
		_shake[i] = 1.0


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	_bump = maxf(0.0, _bump - real * 3.0)
	for i in _stamp.size():
		_stamp[i] = maxf(0.0, float(_stamp[i]) - real * 1.6)
		_shake[i] = maxf(0.0, float(_shake[i]) - real * 2.5)
	queue_redraw()


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	var u := minf(w / 400.0, h / 780.0)
	_draw_room(w, h, u)
	_draw_sign(w, u)
	_draw_counters(w, u)
	_draw_scrolls(w, h, u)
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
		draw_style_box(UiKit.box(_sb, Color(Toon.PAPER, 0.95 * a), int(17 * u), Color(Toon.GOLD, 0.8 * a), int(1.5 * u)), r)
		var ic := r.position + Vector2(20 * u, r.size.y / 2.0)
		match String(items[i][0]):
			"ink":
				_stick(ic, 11.0 * u * (1.0 + 0.3 * _bump), a)
			"seal":
				draw_rect(Rect2(ic - Vector2(7, 7) * u, Vector2(14, 14) * u), Color(Toon.VERMILION, a))
				draw_rect(Rect2(ic - Vector2(4, 4) * u, Vector2(8, 8) * u), Color(Toon.WASHI, 0.5 * a), false, 1.2 * u)
			_:
				draw_rect(Rect2(ic - Vector2(6, 8) * u, Vector2(12, 16) * u), Color(Toon.WASHI, a))
				draw_rect(Rect2(ic - Vector2(6, 8) * u, Vector2(12, 16) * u), Color(Toon.SUMI, a), false, 1.2 * u)
				draw_arc(ic + Vector2(0, 4) * u, 4 * u, PI, TAU, 8, Color(Toon.PRUSSIAN, a), 1.5 * u)
		var fs := int(16 * u)
		var col := Toon.GOLD if (i == 0 and _bump > 0.0) else Toon.SUMI
		draw_string(_ui, r.position + Vector2(36 * u, r.size.y / 2.0 + fs * 0.36), String(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
	# intitulé
	var lfs := int(11 * u)
	var label := "PIERRE À ENCRE"
	var lw := _ui.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var ly := y + 58 * u
	draw_line(Vector2(w / 2.0 - lw / 2.0 - 46 * u, ly - 4 * u), Vector2(w / 2.0 - lw / 2.0 - 10 * u, ly - 4 * u), Color(Toon.GOLD, 0.6 * a), 1.5 * u)
	draw_line(Vector2(w / 2.0 + lw / 2.0 + 10 * u, ly - 4 * u), Vector2(w / 2.0 + lw / 2.0 + 46 * u, ly - 4 * u), Color(Toon.GOLD, 0.6 * a), 1.5 * u)
	draw_string(_ui, Vector2(w / 2.0 - lw / 2.0, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(Color("#D9C79C"), a))


## Six rouleaux suspendus, deux rangées de trois.
func _draw_scrolls(w: float, h: float, u: float) -> void:
	_rects.clear()
	if meta == null:
		return
	var cols := 3
	var sw := minf(112.0 * u, (w - 40 * u) / 3.0 - 8 * u)
	var gap := (w - sw * cols) / (cols + 1)
	var top := 200.0 * u
	var sh := minf(250.0 * u, (h * 0.8 - top - 30 * u) / 2.0 - 12 * u)
	for i in Meta.ORDER.size():
		var col := i % cols
		var row := i / cols
		var unroll := UiKit.ease_out((_t - 0.25 - 0.08 * i) / 0.55)
		var r := Rect2(Vector2(gap + col * (sw + gap), top + row * (sh + 22 * u)), Vector2(sw, sh))
		_rects.append(r)
		var shake := sin(_t * 60.0) * 4.0 * u * float(_shake[i])
		var sway := sin(_t * 1.1 + i * 0.9) * 1.2 * u
		_scroll(i, r, unroll, shake + sway, u)


func _scroll(i: int, r: Rect2, unroll: float, dx: float, u: float) -> void:
	var id: String = Meta.ORDER[i]
	var line: Dictionary = Meta.LINES[id]
	var mount: Color = LINE_COLORS.get(id, Toon.PRUSSIAN)
	var rank: int = meta.rank(id)
	var maxr: int = meta.max_rank(id)
	var cost: int = meta.cost(id)
	var maxed := cost < 0
	var afford: bool = meta.can_buy(id)
	var pressed := _down == i
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
	var kfs := int(44 * u)
	var kanji := String(line.kanji)
	var kw := UiKit.TITLE_FONT.get_string_size(kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
	var ky := paper.position.y + 52 * u
	draw_string(UiKit.TITLE_FONT, Vector2(c - kw / 2.0, ky), kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(Toon.SUMI, (0.35 if maxed else 1.0) * a))
	# nom et effet
	var nfs := int(13 * u)
	var nm := String(line.name)
	var nw := UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	draw_string(UiKit.TITLE_FONT, Vector2(c - nw / 2.0, ky + 24 * u), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(Toon.SUMI, a))
	var efs := int(10 * u)
	var eff: String = meta.effect_text(id)
	draw_multiline_string(UiKit.UI_FONT, Vector2(paper.position.x + 4 * u, ky + 40 * u), eff, HORIZONTAL_ALIGNMENT_CENTER, paper.size.x - 8 * u, efs, 2, Color(Toon.SUMI, 0.65 * a))
	# rang : petits traits d'encre verticaux
	var dots := maxr
	var dx0 := c - (dots - 1) * 5.0 * u
	for k in dots:
		var p := Vector2(dx0 + k * 10.0 * u, ky + 74 * u)
		if k < rank:
			draw_rect(Rect2(p - Vector2(2.5, 6) * u, Vector2(5, 12) * u), Color(mount, a))
		else:
			draw_rect(Rect2(p - Vector2(2.5, 6) * u, Vector2(5, 12) * u), Color(Toon.SUMI, 0.18 * a))
	# prix : un sceau en bas du rouleau
	var py := paper.end.y - 22 * u
	if maxed:
		var mfs := int(13 * u)
		var mw := _ui.get_string_size("MAX", HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x
		draw_string(_ui, Vector2(c - mw / 2.0, py + 4 * u), "MAX", HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, Color(Toon.GOLD, a))
	else:
		var tag := Rect2(Vector2(c - 34 * u, py - 12 * u), Vector2(68 * u, 24 * u))
		draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION if afford else Color("#9A928A"), a), int(3 * u)), tag)
		_stick(tag.position + Vector2(13 * u, tag.size.y / 2.0), 8.0 * u, a, true)
		var pfs := int(13 * u)
		draw_string(_ui, tag.position + Vector2(24 * u, tag.size.y / 2.0 + pfs * 0.36), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(Toon.WASHI, a))
	# achat : un grand sceau vermillon tamponné sur le papier
	var st: float = _stamp[i]
	if st > 0.0:
		var k2 := 1.0 - st
		var size_k := 1.0 + 0.8 * maxf(0.0, 1.0 - k2 * 5.0)
		var sc := Vector2(c, paper.position.y + paper.size.y * 0.42)
		var half := 26.0 * u * size_k
		draw_rect(Rect2(sc - Vector2(half, half), Vector2(half, half) * 2.0), Color(Toon.VERMILION, 0.85 * st), false, 4.0 * u)
		var rfs := int(26 * u * size_k)
		var rt := str(rank)
		var rw := UiKit.TITLE_FONT.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
		draw_string(UiKit.TITLE_FONT, Vector2(sc.x - rw / 2.0, sc.y + rfs * 0.36), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color(Toon.VERMILION, 0.85 * st))


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


## Sur le tatami : la pierre à encre (suzuri), son bâton et un pinceau posé.
func _draw_suzuri(w: float, h: float, u: float) -> void:
	var a := UiKit.ease_out((_t - 0.4) / 0.5)
	var c := Vector2(w * 0.5, h * 0.9)
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
	var k := 0.92 if _back_down else 1.0
	var a := UiKit.ease_out(_t / 0.4)
	draw_circle(c, rad * k, Color(Toon.PAPER, 0.95 * a))
	draw_arc(c, rad * k, -PI * 0.35, PI * 1.45, 32, Color(Toon.SUMI, a), 4.5 * u, true)
	draw_circle(c + Vector2.from_angle(-PI * 0.35) * rad * k, 2.6 * u, Color(Toon.SUMI, a))
	# flèche vers la gauche, comme un trait de pinceau
	var head := c + Vector2(-9, 0) * u * k
	draw_line(c + Vector2(10, 0) * u * k, head, Color(Toon.VERMILION, a), 4.0 * u, true)
	draw_line(head, head + Vector2(7, -7) * u * k, Color(Toon.VERMILION, a), 4.0 * u, true)
	draw_line(head, head + Vector2(7, 7) * u * k, Color(Toon.VERMILION, a), 4.0 * u, true)
