extends Control
## Choix d'un rouleau parmi trois, présentés comme de petites estampes.

const Toon = preload("res://scripts/toon.gd")
const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")

signal picked(id: String)

var _ids: Array = []
var _infos: Array = []
var _t := 0.0
var _down := -1
var _chosen := -1
var _rects: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(ids: Array, infos: Array) -> void:
	_ids = ids
	_infos = infos
	_t = 0.0
	_down = -1
	_chosen = -1
	visible = true


func _gui_input(event: InputEvent) -> void:
	if _chosen >= 0 or _t < 0.45:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _hit(event.position)
		if event.pressed:
			_down = i
		elif _down >= 0 and i == _down:
			_chosen = i
			_t = 0.0
		accept_event()


func _hit(p: Vector2) -> int:
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		if r.has_point(p):
			return i
	return -1


func _process(delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	_t += delta / maxf(Engine.time_scale, 0.01)
	if _chosen >= 0 and _t > 0.45:
		visible = false
		picked.emit(String(_ids[_chosen]))
	queue_redraw()


func _draw() -> void:
	if size.x < 10.0:
		return
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var fade := clampf(_t / 0.3, 0.0, 1.0) if _chosen < 0 else 1.0 - clampf(_t / 0.4, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.WASHI, 0.78 * fade))

	var cw := w * 0.84
	var ch := 128.0 * u
	var gap := 18.0 * u
	var total := ch * _infos.size() + gap * (_infos.size() - 1)
	var y0 := (h - total) / 2.0 + 20.0 * u
	_rects.clear()
	for i in _infos.size():
		var info: Dictionary = _infos[i]
		var appear := 1.0 - pow(1.0 - clampf((_t - 0.08 * i) / 0.35, 0.0, 1.0), 3.0)
		if _chosen >= 0:
			appear = 1.0 if i == _chosen else 1.0 - clampf(_t / 0.25, 0.0, 1.0)
		var r := Rect2(Vector2((w - cw) / 2.0 + 40.0 * u * (1.0 - appear), y0 + i * (ch + gap)), Vector2(cw, ch))
		if _chosen == i:
			r = r.grow(6.0 * u * sin(clampf(_t / 0.45, 0.0, 1.0) * PI))
		_rects.append(r)
		_card(r, info, u, appear * (0.92 if _down == i else 1.0))


func _card(r: Rect2, info: Dictionary, u: float, a: float) -> void:
	var col: Color = info.color
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Toon.SUMI, 0.18 * a)
	sb.set_corner_radius_all(int(10 * u))
	draw_style_box(sb, Rect2(r.position + Vector2(0, 6 * u), r.size))
	sb.bg_color = Color(Color("#F6F0E2"), a)
	sb.border_color = Color(Toon.SUMI, a)
	sb.set_border_width_all(int(2.5 * u))
	draw_style_box(sb, r)
	# cartouche vertical à la couleur de l'école, avec son idéogramme
	var band := Rect2(r.position + Vector2(10, 10) * u, Vector2(58 * u, r.size.y - 20 * u))
	var bb := StyleBoxFlat.new()
	bb.bg_color = Color(col, a)
	bb.set_corner_radius_all(int(6 * u))
	draw_style_box(bb, band)
	var kfs := int(40 * u)
	var kw := TITLE_FONT.get_string_size(String(info.kanji), HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
	draw_string(TITLE_FONT, Vector2(band.get_center().x - kw / 2.0, band.get_center().y + kfs * 0.35), String(info.kanji),
		HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(Toon.WASHI, a))
	# nom, niveau, effet
	var tx := band.end.x + 16 * u
	var tw := r.end.x - tx - 14 * u
	var nfs := int(27 * u)
	draw_string(TITLE_FONT, Vector2(tx, r.position.y + 46 * u), String(info.name), HORIZONTAL_ALIGNMENT_LEFT, tw, nfs, Color(Toon.SUMI, a))
	for k in 3:
		var c := Vector2(tx + 7 * u + k * 17 * u, r.position.y + 66 * u)
		if k < int(info.level):
			draw_circle(c, 5.5 * u, Color(col, a))
		else:
			draw_arc(c, 5.0 * u, 0, TAU, 16, Color(Toon.SUMI, 0.3 * a), 1.5 * u, true)
	draw_multiline_string(UI_FONT, Vector2(tx, r.position.y + 96 * u), String(info.text), HORIZONTAL_ALIGNMENT_LEFT, tw, int(15 * u), 2,
		Color(Toon.SUMI, 0.8 * a))
