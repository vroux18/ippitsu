extends Control
## Options : son, vibrations, contrôles (tracer sur l'écran, ou pad en bas), taille et affichage du pad,
## revoir le tutoriel. Carte de papier sur voile d'encre, choix en boutons segmentés. main lit/écrit `values`.
## Le mode de contrôle ne change qu'au prochain lancement (cadrage de l'arène) : main pose `active_control`,
## une note le rappelle tant que le choix diffère.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

signal changed(key: String, value: String)
signal closed

const ROWS := [
	{"key": "sound", "label": "SON", "opts": [["on", "OUI"], ["off", "NON"]]},
	{"key": "vibration", "label": "VIBRATIONS", "opts": [["on", "OUI"], ["off", "NON"]]},
	{"key": "control", "label": "CONTRÔLES", "opts": [["screen", "SUR L'ÉCRAN"], ["pad", "PAD EN BAS"]]},
	# réglages du pad : grisés (et sans effet) quand on trace sur l'écran
	{"key": "pad_size", "label": "TAILLE DU PAD", "opts": [["s", "PETIT"], ["m", "MOYEN"], ["l", "GRAND"]]},
	{"key": "pad_show", "label": "AFFICHER LE PAD", "opts": [["always", "TOUJOURS"], ["start", "AU DÉBUT"], ["never", "JAMAIS"]]},
	# une seule case : cochée tant que le tutoriel en jeu (coach) est à faire
	{"key": "tuto", "label": "TUTORIEL", "opts": [["replay", "REVOIR LE TUTORIEL"]]},
]
const INPUT_DELAY := 0.3  # le toucher qui a ouvert la carte ne doit rien choisir
const NO_TARGET := -2
const BACK_TARGET := -1

const PAD_KEYS := ["pad_size", "pad_show"]
const ROW_TOP := 112.0  # première ligne (× u depuis le haut de la carte), sous l'en-tête
const ROW_STEP := 92.0  # pas entre deux lignes (× u)
const RESTART_NOTE := "Redémarre le jeu pour appliquer"

var values := {"sound": "on", "vibration": "on", "control": "screen", "pad_size": "m", "pad_show": "start"}
var active_control := "screen"  # mode de contrôle de la session en cours (lu par main au lancement)

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
	_ui.spacing_glyph = UiKit.CAPS_SPACING
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = UiKit.TITLE_SPACING


func open() -> void:
	_t = 0.0
	_pressed = NO_TARGET
	visible = true


## Le mode de contrôle choisi n'est pas celui de la session : il faut relancer le jeu.
func restart_pending() -> bool:
	return String(values.get("control", "screen")) != active_control


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
	var card_h := ROW_TOP + float(ROWS.size()) * ROW_STEP - 18.0
	var u := minf(w / 400.0, h / (card_h + 40.0))
	var a := clampf(_t / 0.25, 0.0, 1.0)
	var ka := UiKit.ease_out(a)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.85 * a))
	# feuille de washi (comme la pause), qui monte un peu à l'ouverture ; vagues seigaiha dans l'en-tête
	var card := Rect2(Vector2(w * 0.06, h * 0.5 - card_h * 0.5 * u + 14.0 * u * (1.0 - ka)), Vector2(w * 0.88, card_h * u))
	var ink: Color = Toon.ui_ink
	UiKit.sheet(self, card, Toon.ui_paper, ink, a, u, 8.0, 64.0)
	# en-tête : retour à gauche, titre souligné de vermillon et son sceau
	var bc := card.position + Vector2(UiKit.HEAD_X, UiKit.HEAD_Y) * u
	_back = UiKit.back_rect(bc, u)
	UiKit.back_button(self, bc, u, a, 1.0 if _pressed == BACK_TARGET else 0.0)
	var tmax: float = card.size.x - 2.0 * (UiKit.HEAD_X + 26.0) * u
	UiKit.screen_title(self, _title, "OPTIONS", Vector2(card.get_center().x, card.position.y + UiKit.HEAD_BASE * u), u, ink, a, "設", tmax, UiKit.ease_out(clampf((_t - 0.1) / 0.4, 0.0, 1.0)))
	# lignes d'options : libellé (puce shuriken), choix en pilules
	_hits.clear()
	var lfs: int = int(UiKit.FS_CAPTION * u)
	var ofs: int = int(UiKit.FS_LABEL * u)
	var x0 := card.position.x + UiKit.SP_L * u
	var inner_w := card.size.x - 2.0 * UiKit.SP_L * u
	var gap := 6.0 * u
	var y := card.position.y + ROW_TOP * u
	for row in ROWS:
		var key := String(row.key)
		var dim: bool = key in PAD_KEYS and String(values.get("control", "screen")) != "pad"
		var la: float = (UiKit.A_DIM if dim else UiKit.A_SUB) * a
		UiKit.shuriken(self, Vector2(x0 + 4.0 * u, y - lfs * 0.36), 4.0 * u, Color(Toon.VERMILION, (0.35 if dim else 0.85) * a), 0.25)
		draw_string(_ui, Vector2(x0 + 14.0 * u, y), UiKit.plain(String(row.label)), HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(ink, la))
		var opts: Array = row.opts
		var bw := (inner_w - float(opts.size() - 1) * gap) / float(opts.size())
		for i in opts.size():
			var o: Array = opts[i]
			var r := Rect2(Vector2(x0 + float(i) * (bw + gap), y + 9.0 * u), Vector2(bw, UiKit.OPT_H * u))
			var on := String(values.get(key, "")) == String(o[0])
			var dr := r
			if not dim and _pressed == _hits.size():
				dr = r.grow(-1.5 * u)  # la case sous le doigt s'enfonce
			UiKit.chip(self, _sb, dr, UiKit.plain(String(o[1])), _ui, ofs, on, ink, Toon.ui_paper, a, dim)
			if not dim:
				_hits.append([r, key, String(o[0])])
		if key == "control" and restart_pending():
			# choix pris en compte au prochain lancement : petite note sous les boutons
			UiKit.text(self, _ui, UiKit.plain(RESTART_NOTE), Vector2(card.get_center().x, y + (9.0 + UiKit.OPT_H + 14.0) * u), lfs, Color(Toon.VERMILION, 0.9 * a))
		y += ROW_STEP * u
