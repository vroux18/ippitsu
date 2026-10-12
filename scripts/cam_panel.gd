extends Control
## Réglage de la caméra (mode mesure, réservé au propriétaire) : ouvert depuis la pause (étiquette CAMÉRA),
## feuille washi compacte en bas de l'écran, le jeu figé reste visible au-dessus et suit chaque réglage.
## Trois lignes à gros boutons − / + : INCLINAISON (plongée, degrés), FOCALE (cam.fov, degrés), RECUL (facteur
## sur la distance du cadrage : < 1 rapproche, > 1 éloigne). RÉINITIALISER (valeurs du jeu), COPIER (le réglage
## « tilt=48 fov=44 recul=1.00 » dans le presse-papiers et le rapport de mesure), VOIR (la feuille s'efface,
## un toucher la rend). main applique et renvoie les valeurs (set_values) ; ce nœud ne touche pas à la caméra.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
const InkButton = preload("res://scripts/ink_button.gd")

signal step(key: String, dir: int)  # key : tilt | fov | recul ; dir : -1 ou +1
signal reset_pressed
signal copy_pressed
signal closed

const ROWS := [["tilt", "INCLINAISON"], ["fov", "FOCALE"], ["recul", "RECUL"]]
const HEAD_H := 48.0
const ROW_H := 60.0
const FOOT_H := 64.0

var values := {"tilt": 48.0, "fov": 34.0, "recul": 0.9}
var defaults := {"tilt": 48.0, "fov": 34.0, "recul": 0.9}
var peek := false  # VOIR : feuille masquée, le jeu seul (un toucher la rend)

var _t := 0.0
var _title := FontVariation.new()
var _caps := FontVariation.new()
var _btn_font := FontVariation.new()
var _sb := StyleBoxFlat.new()
var _close: Control
var _minus := {}  # clé -> bouton −
var _plus := {}  # clé -> bouton +
var _see: Control
var _reset: Control
var _copy: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # rien ne passe au jeu (en pause) tant que le panneau est ouvert
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 6
	_caps.base_font = UiKit.UI_FONT
	_caps.spacing_glyph = UiKit.CAPS_SPACING
	_btn_font.base_font = UiKit.UI_FONT
	_btn_font.spacing_glyph = UiKit.CAPS_SPACING
	_close = _button("", "round")
	_close.icon = "back"
	_close.pressed.connect(close)
	for r in ROWS:
		var key := String(r[0])
		var m := _button("－", "ghost")
		m.pressed.connect(func(): step.emit(key, -1))
		_minus[key] = m
		var p := _button("＋", "ghost")
		p.pressed.connect(func(): step.emit(key, 1))
		_plus[key] = p
	_see = _button("VOIR", "ghost")
	_see.pressed.connect(func():
		peek = true
		_layout())
	_reset = _button("RÉINITIALISER", "ghost")
	_reset.pressed.connect(func(): reset_pressed.emit())
	_copy = _button("COPIER", "primary")
	_copy.pressed.connect(func(): copy_pressed.emit())


func _button(label: String, style: String) -> Control:
	var b := InkButton.new()
	b.text = label
	b.style = style
	b.font = _btn_font
	add_child(b)
	return b


func open() -> void:
	_t = 0.0
	peek = false
	visible = true
	size = get_viewport_rect().size
	_layout()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Valeurs affichées (main les a bornées et appliquées).
func set_values(v: Dictionary, d: Dictionary) -> void:
	values = v.duplicate()
	defaults = d.duplicate()
	queue_redraw()


## Feuille en bas de l'écran (au-dessus de la barre de geste), toute la largeur moins les marges.
func sheet_rect() -> Rect2:
	var u := size.x / 400.0
	var safe := UiKit.safe_insets(size)
	var h := (HEAD_H + 8.0 + ROW_H * float(ROWS.size()) + FOOT_H + 8.0) * u
	var w := minf(size.x - 24.0 * u, 376.0 * u)
	return Rect2(Vector2((size.x - w) / 2.0, size.y - safe.y - 10.0 * u - h), Vector2(w, h))


func _layout() -> void:
	var u := size.x / 400.0
	var r := sheet_rect()
	var show := not peek
	var cb := 36.0 * u
	_close.visible = show
	_close.size = Vector2(cb, cb)
	_close.position = Vector2(r.position.x + 12.0 * u, r.position.y + (HEAD_H * u - cb) / 2.0)
	var bw := 66.0 * u
	var bh := 48.0 * u
	for i in ROWS.size():
		var key := String(ROWS[i][0])
		var y := r.position.y + (HEAD_H + 8.0 + ROW_H * float(i)) * u + (ROW_H * u - bh) / 2.0
		var m: Control = _minus[key]
		var p: Control = _plus[key]
		m.visible = show
		p.visible = show
		p.size = Vector2(bw, bh)
		p.position = Vector2(r.end.x - 16.0 * u - bw, y)
		m.size = Vector2(bw, bh)
		m.position = Vector2(p.position.x - 10.0 * u - bw, y)
		m.font_size = int(28 * u)
		p.font_size = int(28 * u)
	var fy := r.position.y + (HEAD_H + 8.0 + ROW_H * float(ROWS.size())) * u + 8.0 * u
	var gap := 8.0 * u
	var fw := (r.size.x - 32.0 * u - 2.0 * gap)
	var widths := [fw * 0.27, fw * 0.43, fw * 0.30]
	var x := r.position.x + 16.0 * u
	var fh := 46.0 * u
	var foot: Array = [_see, _reset, _copy]
	for i in 3:
		var b: Control = foot[i]
		b.visible = show
		b.size = Vector2(float(widths[i]), fh)
		b.position = Vector2(x, fy)
		b.font_size = int(13 * u)
		x += float(widths[i]) + gap
	queue_redraw()


func _process(_delta: float) -> void:
	if not visible:
		return
	_t += UiKit.real_delta()
	var vs := get_viewport_rect().size
	if size != vs:
		size = vs
		_layout()
	if _t < 0.4:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_layout()


func _gui_input(event: InputEvent) -> void:
	# VOIR : un toucher n'importe où rend la feuille
	if peek and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		peek = false
		_layout()
		accept_event()


static func fmt(key: String, v: float) -> String:
	if key == "recul":
		return ("×%.2f" % v).replace(".", ",")
	return "%d°" % int(round(v))


func _draw() -> void:
	if size.x < 10.0:
		return
	var u := size.x / 400.0
	var safe := UiKit.safe_insets(size)
	if peek:
		# pastille discrète : le réglage en cours, et comment revenir
		var txt := "%s · %s · %s — TOUCHER POUR REVENIR" % [fmt("tilt", values.tilt), fmt("fov", values.fov), fmt("recul", values.recul)]
		var fs := int(11 * u)
		var tw := _caps.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pr := Rect2(Vector2((size.x - tw) / 2.0 - 14.0 * u, size.y - safe.y - 44.0 * u), Vector2(tw + 28.0 * u, 30.0 * u))
		draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI, 0.85), int(15 * u)), pr)
		draw_string(_caps, Vector2(pr.position.x + 14.0 * u, pr.get_center().y + float(fs) * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIColors.WASHI)
		return
	var a := UiKit.ease_out(clampf(_t / 0.25, 0.0, 1.0))
	var r := sheet_rect()
	r.position.y += 14.0 * u * (1.0 - a)
	# feuille washi aux coins arrondis (ombre sans flou), en-tête sumi souligné de vermillon
	var sheet := UiKit.rrect_points(r, 18.0 * u)
	draw_colored_polygon(Transform2D(0.0, Vector2(0, 6.0 * u)) * sheet, Color(0, 0, 0, 0.16 * a))
	draw_colored_polygon(Transform2D(0.0, Vector2(0, 2.0 * u)) * sheet, Color(0, 0, 0, 0.2 * a))
	draw_colored_polygon(sheet, Color(Toon.ui_paper, a))
	var head := Rect2(r.position, Vector2(r.size.x, HEAD_H * u))
	draw_colored_polygon(UiKit.rrect_points(head, 18.0 * u, true), Color(UIColors.SUMI, a))
	var cx := r.get_center().x
	var sp := maxi(1, int(6.0 * u))
	if _title.spacing_glyph != sp:
		_title.spacing_glyph = sp
	UiKit.text(self, _title, "CAMÉRA", Vector2(cx + float(sp) * 0.5, r.position.y + 31.0 * u), int(20 * u), Color(UIColors.WASHI, a))
	var swash := Rect2(Vector2(cx - 54.0 * u, r.position.y + 37.0 * u), Vector2(108.0 * u, 7.0 * u))
	draw_colored_polygon(UiKit.swash_points(swash, a, 3.0), Color(UIColors.VERMILION, a))
	# lignes : petites capitales, valeur en grand (vermillon si elle s'écarte du jeu), défaut en légende
	var ink: Color = Toon.ui_ink
	var nf := UiKit.num_font()
	for i in ROWS.size():
		var key := String(ROWS[i][0])
		var y0 := r.position.y + (HEAD_H + 8.0 + ROW_H * float(i)) * u
		if i > 0:
			draw_line(Vector2(r.position.x + 16.0 * u, y0), Vector2(r.end.x - 16.0 * u, y0), Color(ink, UiKit.A_RULE * a), maxf(1.0, u))
		var x0 := r.position.x + 20.0 * u
		var cfs := int(UiKit.FS_CAPTION * u)
		draw_string(_caps, Vector2(x0, y0 + 20.0 * u), String(ROWS[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(ink, 0.6 * a))
		var v := float(values.get(key, 0.0))
		var d := float(defaults.get(key, 0.0))
		var off := absf(v - d) > 0.001
		var vfs := int(24 * u)
		var vs := fmt(key, v)
		draw_string(nf, Vector2(x0, y0 + 48.0 * u), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs, Color(UIColors.VERMILION if off else ink, a))
		var vw := nf.get_string_size(vs, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs).x
		if off:
			draw_string(_caps, Vector2(x0 + vw + 8.0 * u, y0 + 47.0 * u), "jeu " + fmt(key, d), HORIZONTAL_ALIGNMENT_LEFT, -1,
				int(UiKit.FS_CAPTION * u), Color(ink, UiKit.A_CAPTION * a))
