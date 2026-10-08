extends Control
## Options : son, vibrations, revoir le tutoriel (on trace toujours directement sur l'écran).
## Carte de papier sur voile d'encre, choix en boutons segmentés. main lit/écrit `values`.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

signal changed(key: String, value: String)
signal closed

const ROWS := [
	{"key": "sound", "label": "SON", "opts": [["on", "OUI"], ["off", "NON"]]},
	{"key": "vibration", "label": "VIBRATIONS", "opts": [["on", "OUI"], ["off", "NON"]]},
	# une seule case : cochée tant que le tutoriel en jeu (coach) est à faire
	{"key": "tuto", "label": "TUTORIEL", "opts": [["replay", "REVOIR LE TUTORIEL"]]},
]
const INPUT_DELAY := 0.3  # le toucher qui a ouvert la carte ne doit rien choisir
const NO_TARGET := -2
const BACK_TARGET := -1

var values := {"sound": "on", "vibration": "on"}

var _t := 0.0
var _hits: Array = []  # [Rect2, clé, valeur]
var _back := Rect2()
var _pressed := NO_TARGET  # cible touchée à l'appui (retour, ou indice dans _hits)
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
	_title.spacing_glyph = 6


func open() -> void:
	_t = 0.0
	_pressed = NO_TARGET
	visible = true


func _target_at(p: Vector2) -> int:
	if _back.has_point(p):
		return BACK_TARGET
	for i in _hits.size():
		var r: Rect2 = _hits[i][0]
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
	# relâché : on ne choisit que si l'appui et le relâché tombent sur la même cible
	var start := _pressed
	_pressed = NO_TARGET
	if target == NO_TARGET or target != start:
		return
	if target == BACK_TARGET:
		visible = false
		closed.emit()
		return
	var h: Array = _hits[target]
	values[String(h[1])] = String(h[2])
	changed.emit(String(h[1]), String(h[2]))


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	_t += UiKit.real_delta()
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	# la carte grandit avec le nombre de lignes ; sur écran trop bas, tout rétrécit pour tenir
	var card_h := 184.0 + (ROWS.size() - 1) * 92.0
	var u := minf(w / 400.0, h / (card_h + 40.0))
	var a := clampf(_t / 0.25, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.85 * a))
	var card := Rect2(Vector2(w * 0.06, h * 0.5 - card_h * 0.5 * u), Vector2(w * 0.88, card_h * u))
	UiKit.box(_sb, Color(Toon.ui_paper, a), int(18 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.5 * a)
	_sb.shadow_size = int(20 * u)
	draw_style_box(_sb, card)
	UiKit.text(self, _title, "OPTIONS", Vector2(card.get_center().x, card.position.y + 52 * u), int(28 * u), Color(Toon.ui_ink, a))
	draw_line(Vector2(card.get_center().x - 30 * u, card.position.y + 66 * u), Vector2(card.get_center().x + 30 * u, card.position.y + 66 * u), Color(Toon.VERMILION, a), 2 * u)
	# retour : ensō et flèche en haut à gauche de la carte
	var bc := card.position + Vector2(34, 40) * u
	_back = Rect2(bc - Vector2(26, 26) * u, Vector2(52, 52) * u)
	draw_arc(bc, 16 * u, -PI * 0.35, PI * 1.45, 28, Color(Toon.ui_ink, a), 3.5 * u, true)
	var head := bc + Vector2(-7, 0) * u
	draw_line(bc + Vector2(8, 0) * u, head, Color(Toon.VERMILION, a), 3 * u, true)
	draw_line(head, head + Vector2(5, -5) * u, Color(Toon.VERMILION, a), 3 * u, true)
	draw_line(head, head + Vector2(5, 5) * u, Color(Toon.VERMILION, a), 3 * u, true)
	# lignes d'options
	_hits.clear()
	var y := card.position.y + 104 * u
	for row in ROWS:
		var key := String(row.key)
		draw_string(_ui, Vector2(card.position.x + 22 * u, y), String(row.label), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(Toon.ui_ink, 0.6 * a))
		var opts: Array = row.opts
		var x0 := card.position.x + 18 * u
		var bw := (card.size.x - 36 * u - (opts.size() - 1) * 6 * u) / opts.size()
		for i in opts.size():
			var o: Array = opts[i]
			var r := Rect2(Vector2(x0 + i * (bw + 6 * u), y + 10 * u), Vector2(bw, 42 * u))
			var on := String(values.get(key, "")) == String(o[0])
			if on:
				UiKit.box(_sb, Color(Toon.ui_ink, a), int(10 * u))
			else:
				UiKit.box(_sb, Color(0, 0, 0, 0), int(10 * u), Color(Toon.ui_ink, 0.35 * a), int(1.5 * u))
			draw_style_box(_sb, r)
			if on:
				draw_rect(Rect2(r.position + Vector2(8 * u, r.size.y * 0.3), Vector2(3 * u, r.size.y * 0.4)), Color(Toon.VERMILION, a))
			var fs := int(12 * u)
			UiKit.text(self, _ui, String(o[1]), Vector2(r.get_center().x, r.get_center().y + fs * 0.36), fs,
				Color(Toon.ui_wash if on else Toon.ui_ink, a))
			_hits.append([r, key, String(o[0])])
		y += 92 * u
