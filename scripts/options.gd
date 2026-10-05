extends Control
## Options : contrôles (pad en bas ou directement sur l'écran), taille et affichage du pad, son.
## Carte de papier sur voile d'encre, choix en boutons segmentés. main lit/écrit `values`.

const Toon = preload("res://scripts/toon.gd")
const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")

signal changed(key: String, value: String)
signal closed

const ROWS := [
	{"key": "control", "label": "CONTRÔLES", "opts": [["pad", "PAD EN BAS"], ["screen", "SUR L'ÉCRAN"]]},
	{"key": "pad_size", "label": "TAILLE DU PAD", "opts": [["s", "PETIT"], ["m", "MOYEN"], ["l", "GRAND"]]},
	{"key": "pad_show", "label": "AFFICHER LE PAD", "opts": [["always", "TOUJOURS"], ["start", "AU DÉBUT"], ["never", "JAMAIS"]]},
	{"key": "sound", "label": "SON", "opts": [["on", "OUI"], ["off", "NON"]]},
]

var values := {"control": "pad", "pad_size": "m", "pad_show": "start", "sound": "on"}

var _t := 0.0
var _hits: Array = []  # [Rect2, clé, valeur]
var _back := Rect2()
var _ui := FontVariation.new()
var _title := FontVariation.new()
var _last_ms := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UI_FONT
	_ui.spacing_glyph = 1
	_title.base_font = TITLE_FONT
	_title.spacing_glyph = 6


func open() -> void:
	_t = 0.0
	visible = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var p: Vector2 = event.position
		if _back.has_point(p):
			visible = false
			closed.emit()
		for h in _hits:
			var r: Rect2 = h[0]
			if r.has_point(p):
				values[String(h[1])] = String(h[2])
				changed.emit(String(h[1]), String(h[2]))
		accept_event()
	elif event is InputEventMouseButton:
		accept_event()


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var now := Time.get_ticks_msec()
	_t += 0.0 if _last_ms == 0 else minf((now - _last_ms) / 1000.0, 0.1)
	_last_ms = now
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	var u := w / 400.0
	var a := clampf(_t / 0.25, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Color("#100D10"), 0.85 * a))
	var card := Rect2(Vector2(w * 0.06, h * 0.5 - 250 * u), Vector2(w * 0.88, 500 * u))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color("#F4EDDC"), a)
	sb.set_corner_radius_all(int(18 * u))
	sb.shadow_color = Color(0, 0, 0, 0.5 * a)
	sb.shadow_size = int(20 * u)
	draw_style_box(sb, card)
	var tfs := int(28 * u)
	var tw := _title.get_string_size("OPTIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	draw_string(_title, Vector2(card.get_center().x - tw / 2.0, card.position.y + 52 * u), "OPTIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(Toon.SUMI, a))
	draw_line(Vector2(card.get_center().x - 30 * u, card.position.y + 66 * u), Vector2(card.get_center().x + 30 * u, card.position.y + 66 * u), Color(Toon.VERMILION, a), 2 * u)
	# retour : ensō et flèche en haut à gauche de la carte
	var bc := card.position + Vector2(34, 40) * u
	_back = Rect2(bc - Vector2(26, 26) * u, Vector2(52, 52) * u)
	draw_arc(bc, 16 * u, -PI * 0.35, PI * 1.45, 28, Color(Toon.SUMI, a), 3.5 * u, true)
	var head := bc + Vector2(-7, 0) * u
	draw_line(bc + Vector2(8, 0) * u, head, Color(Toon.VERMILION, a), 3 * u, true)
	draw_line(head, head + Vector2(5, -5) * u, Color(Toon.VERMILION, a), 3 * u, true)
	draw_line(head, head + Vector2(5, 5) * u, Color(Toon.VERMILION, a), 3 * u, true)
	# lignes d'options
	_hits.clear()
	var y := card.position.y + 104 * u
	for row in ROWS:
		var key := String(row.key)
		var dim := key in ["pad_size", "pad_show"] and String(values.get("control", "pad")) == "screen"
		draw_string(_ui, Vector2(card.position.x + 22 * u, y), String(row.label), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(Toon.SUMI, (0.3 if dim else 0.6) * a))
		var opts: Array = row.opts
		var x0 := card.position.x + 18 * u
		var bw := (card.size.x - 36 * u - (opts.size() - 1) * 6 * u) / opts.size()
		for i in opts.size():
			var o: Array = opts[i]
			var r := Rect2(Vector2(x0 + i * (bw + 6 * u), y + 10 * u), Vector2(bw, 42 * u))
			var on := String(values.get(key, "")) == String(o[0])
			var ob := StyleBoxFlat.new()
			ob.set_corner_radius_all(int(10 * u))
			if on:
				ob.bg_color = Color(Toon.SUMI, a * (0.4 if dim else 1.0))
			else:
				ob.bg_color = Color(0, 0, 0, 0)
				ob.border_color = Color(Toon.SUMI, 0.35 * a)
				ob.set_border_width_all(int(1.5 * u))
			draw_style_box(ob, r)
			if on and not dim:
				draw_rect(Rect2(r.position + Vector2(8 * u, r.size.y * 0.3), Vector2(3 * u, r.size.y * 0.4)), Color(Toon.VERMILION, a))
			var fs := int(12 * u)
			var lw := _ui.get_string_size(String(o[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(_ui, Vector2(r.get_center().x - lw / 2.0, r.get_center().y + fs * 0.36), String(o[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(Toon.WASHI if on else Toon.SUMI, a * (0.5 if dim else 1.0)))
			if not dim:
				_hits.append([r, key, String(o[0])])
		y += 92 * u
