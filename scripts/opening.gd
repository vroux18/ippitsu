extends Control
## Ouverture : la mini-histoire du tout premier démarrage, dessinée à l'encre (_draw 2D, horloge réelle),
## sans un mot. La nuit, dans l'atelier, la main du vieux peintre peint la Grande Vague coup de pinceau après
## coup de pinceau ; l'encre noire déborde de la crête, la Vague Noire prend un masque de nō et avale une à une
## les estampes du mur ; d'un seul trait (ippitsu) le peintre fait naître le Ronin de papier, qui prend ses
## couleurs, ouvre les yeux, la main sur la garde ; le pinceau le pousse dans la feuille, on plonge dans la
## vague, l'encre tourbillonne en ensō, puis elle s'efface sur la mer réelle de l'accueil.
## main appelle play() ; l'ouverture émet reveal() quand l'encre commence à s'effacer (l'accueil peut se peindre
## dessous : titre, JOUER), puis finished() quand elle a disparu. Passable : toucher maintenu (anneau), PASSER
## (après 2 s), ou skip() (bouton Retour du téléphone).

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const InkButton = preload("res://scripts/ink_button.gd")

signal reveal
signal finished

# ------------------------------------------------------------------ minutage (secondes depuis play)
const T_WAVE := 1.0  # le pinceau commence la Grande Vague (coups de pinceau : voir _build_painting)
const T_DARK := 11.4  # l'encre noire monte de la crête : la Vague Noire
const T_MASK := 13.2  # le masque de nō émerge dans sa crête
const T_EAT := 13.8  # première estampe happée (puis une toutes les EAT_STEP s)
const EAT_STEP := 0.5
const T_DIP := 17.6  # le pinceau plonge dans le sumi
const T_ONE := 18.6  # début du trait unique
const ONE_DUR := 5.0  # durée du trait unique
const T_FILL := 23.8  # les couleurs prennent (chapeau, kimono, hakama, peau)
const T_SCARF := 24.9  # l'écharpe se colore en dernier
const T_EYES := 25.8  # le ronin ouvre les yeux
const T_PUSH := 26.8  # le pinceau le pousse dans la feuille
const T_ZOOM := 28.2  # plongée dans la vague
const T_ENSO := 29.5  # l'ensō se peint au cœur de la vague, puis l'encre en déborde et recouvre tout
const T_FADE := 31.0  # l'encre s'ouvre (iris d'ensō) sur la mer réelle : l'accueil se peint dessous
const T_END := 33.4  # fin
const SKIP_HOLD := 0.75  # toucher maintenu pour passer
const SKIP_FADE := 0.55

# couleurs de la scène (nuit d'atelier) et du Ronin de papier (intro.gd, ninja_rig.gd RONIN_PAL)
const NIGHT := Color("#15141B")
const WALL := Color("#2A2731")
const WOOD := Color("#4A3A2C")
const LAMP := Color("#F2B85A")
const STRAW := Color("#CDAB6B")
const HAIR := Color("#1E1B22")
const KIMONO := Color("#F4EAD6")
const HAKAMA := Color("#1F3A5C")
const WAVE := Color("#6F9BC8")
const HEM := Color("#2A2733")
const PRUSSIAN_DEEP := Color("#142A47")
const BLACK_INK := Color("#0B0A0D")
const MASK := Color("#E8DCC4")

# estampes du mur : mondes 2 à 8 (worlds.gd), chacune en trois traits ; avalées de la crête vers la gauche
const PRINTS := ["kitsune", "yuki", "faille", "fuji", "tengu", "ryugu", "yomi"]
const EAT_ORDER := [3, 2, 1, 0, 6, 5, 4]

# la Grande Vague (fractions de la feuille) : dos et crête de la grande vague, puis sa face (les deux se
# rejoignent à la pointe de la langue) ; la vague secondaire au premier plan ; la Vague Noire (repère 400 × 800)
const OUTER := [Vector2(0.0, 0.98), Vector2(0.02, 0.78), Vector2(0.08, 0.55), Vector2(0.17, 0.36), Vector2(0.29, 0.22),
	Vector2(0.44, 0.13), Vector2(0.58, 0.13), Vector2(0.69, 0.19), Vector2(0.74, 0.28), Vector2(0.73, 0.33)]
const INNER := [Vector2(0.3, 0.98), Vector2(0.28, 0.82), Vector2(0.28, 0.66), Vector2(0.33, 0.5), Vector2(0.42, 0.38),
	Vector2(0.52, 0.31), Vector2(0.6, 0.29), Vector2(0.67, 0.3), Vector2(0.71, 0.32), Vector2(0.73, 0.33)]
const W2 := [Vector2(0.54, 1.02), Vector2(0.65, 0.86), Vector2(0.77, 0.72), Vector2(0.88, 0.62), Vector2(0.96, 0.6), Vector2(1.02, 0.64)]
const KURO_OUT := [Vector2(236, 330), Vector2(262, 262), Vector2(300, 196), Vector2(326, 130), Vector2(326, 66), Vector2(292, 22),
	Vector2(226, 4), Vector2(160, 10), Vector2(110, 36), Vector2(84, 70)]
const KURO_IN := [Vector2(296, 352), Vector2(318, 290), Vector2(328, 222), Vector2(316, 156), Vector2(290, 104), Vector2(242, 74),
	Vector2(186, 62), Vector2(136, 66), Vector2(102, 78), Vector2(84, 70)]
const CREST := Vector2(0.6, 0.3)  # cœur de la vague : où le ronin plonge, centre de la plongée

var sfx: Node  # posé par main (sons : whoosh, slash, torii, shot, ink, iai)
var _t := -1.0  # temps réel depuis play() (-1 : fermée)
var _skip_btn: Control
var _holding := false
var _hold_t := 0.0
var _hold_p := Vector2.ZERO
var _end_t := -1.0  # fondu de sortie après PASSER (-1 : aucun)
var _revealed := false
var _cues := {}  # repère sonore -> déjà joué
var _tip := Vector2.ZERO  # pointe du pinceau (lissée)
var _tip_set := false
var _last_ms := 0  # horloge propre : le temps réel, hoquets du préchauffage plafonnés à 1 s par image
var _ui := FontVariation.new()
# contexte de dessin
var _u := 1.0
var _f := Rect2()  # cadre 400 × 800 centré
var _sheet := Rect2()  # la feuille de washi
var _a := 1.0
var _strokes: Array = []  # coups de pinceau de la Grande Vague, dans l'ordre de dessin (voir _build_painting)
var _strokes_sheet := Rect2()  # feuille pour laquelle ils ont été calculés
var _kuro_o := PackedVector2Array()  # la Vague Noire : son dos (pixels), de la crête peinte à sa langue
var _kuro_i := PackedVector2Array()  # et sa face
var _paint := Rect2()  # la partie de la feuille où se peint la Grande Vague (le haut reste ciel)
var _ronin_path := PackedVector2Array()  # le trait unique, en unités du ronin
var _ronin_len := PackedFloat32Array()  # longueur cumulée le long du trait
var _paper: Control  # calque écrêté à la feuille : la Grande Vague et le ronin n'en débordent pas
var _over: Control  # calque du dessus : Vague Noire, main du peintre, ensō, anneau du toucher
var _ci: CanvasItem = self  # calque sur lequel on dessine à cet instant
var _base := Transform2D.IDENTITY  # transformation de base du calque courant (repère écran avant plongée)


## Calque de dessin délégué : son _draw appelle le dessin de l'ouverture pour sa partie.
class Layer extends Control:
	var op: Control
	var part := ""

	func _draw() -> void:
		op.call("_draw_part", self, part)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 2
	_paper = Layer.new()
	_paper.op = self
	_paper.part = "paper"
	_paper.clip_contents = true
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)
	_over = Layer.new()
	_over.op = self
	_over.part = "over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)
	_skip_btn = InkButton.new()
	_skip_btn.text = "PASSER"
	_skip_btn.style = "ghost"
	_skip_btn.font = _ui
	_skip_btn.visible = false
	_skip_btn.pressed.connect(skip)
	add_child(_skip_btn)
	_build_ronin_path()


## Lance l'ouverture depuis le début (ou depuis la seconde `start`, pour les captures : `?opening&t=N`).
func play(start := 0.0) -> void:
	_t = maxf(start, 0.0)
	_end_t = -1.0
	_revealed = false
	_holding = false
	_hold_t = 0.0
	_cues.clear()
	_tip_set = false
	_last_ms = 0
	visible = true
	modulate.a = 1.0


## Passer : court fondu puis fin (toucher maintenu, PASSER, bouton Retour).
func skip() -> void:
	if not visible or _end_t >= 0.0 or _t >= T_FADE:
		return
	_end_t = 0.0
	_cue("skip", "whoosh", 0.9, -8.0)


func _finish() -> void:
	if not visible:
		return
	visible = false
	_t = -1.0
	if not _revealed:
		_revealed = true
		reveal.emit()
	finished.emit()


## Toucher maintenu : un anneau se remplit sous le doigt, puis l'ouverture passe.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_holding = mb.pressed and _t > 0.4
		_hold_t = 0.0
		_hold_p = mb.position
	elif event is InputEventMouseMotion and _holding:
		_hold_p = (event as InputEventMouseMotion).position


func _process(_delta: float) -> void:
	if not visible or _t < 0.0:
		return
	size = get_viewport_rect().size
	var now := Time.get_ticks_msec()
	var real := 0.0 if _last_ms == 0 else minf(float(now - _last_ms) / 1000.0, 1.0)
	_last_ms = now
	_t += real
	if _holding:
		_hold_t += real
		if _hold_t >= SKIP_HOLD:
			_holding = false
			skip()
	if _end_t >= 0.0:
		_end_t += real
		if not _revealed and _end_t >= SKIP_FADE * 0.4:
			_revealed = true
			reveal.emit()
		if _end_t >= SKIP_FADE:
			_finish()
			return
	elif _t >= T_FADE + 0.3 and not _revealed:
		_revealed = true
		reveal.emit()
	if _t >= T_END and _end_t < 0.0:
		_finish()
		return
	_sounds()
	_layout()
	queue_redraw()


## Repères sonores, joués une fois chacun quand l'horloge les franchit.
func _sounds() -> void:
	if _end_t >= 0.0:
		return
	if _t >= T_WAVE:
		_cue("wave", "ink", 0.8, -10.0)
	if _t >= T_WAVE + 4.0:
		_cue("foam", "whoosh", 1.3, -14.0)
	if _t >= T_WAVE + 9.9:
		_cue("seal", "shot", 1.3, -12.0)
	if _t >= T_DARK:
		_cue("dark", "whoosh", 0.55, -6.0)
	if _t >= T_MASK:
		_cue("mask", "shot", 0.6, -8.0)
	for i in PRINTS.size():
		if _t >= T_EAT + EAT_STEP * i:
			_cue("eat%d" % i, "shot", 1.1 + 0.08 * i, -12.0)
	if _t >= T_DIP:
		_cue("dip", "ink", 1.0, -8.0)
	if _t >= T_ONE:
		_cue("one", "whoosh", 0.7, -10.0)
	if _t >= T_ONE + ONE_DUR:
		_cue("katana", "slash", 1.0, -6.0)
	if _t >= T_EYES:
		_cue("eyes", "iai", 1.2, -10.0)
	if _t >= T_PUSH:
		_cue("push", "whoosh", 1.0, -8.0)
	if _t >= T_ZOOM:
		_cue("zoom", "whoosh", 0.6, -6.0)
	if _t >= T_ENSO:
		_cue("enso", "ink", 0.6, -6.0)
	if _t >= T_FADE:
		_cue("torii", "torii", 1.0, -6.0)
	if _t >= T_FADE + 0.3:
		_cue("sea", "whoosh", 0.8, -10.0)


func _cue(key: String, snd: String, pitch: float, db: float) -> void:
	if _cues.has(key):
		return
	_cues[key] = true
	if sfx != null:
		sfx.play(snd, pitch, db)


func _layout() -> void:
	var u := minf(size.x / 400.0, size.y / 800.0)
	_u = u
	_f = Rect2((size - Vector2(400, 800) * u) / 2.0, Vector2(400, 800) * u)
	# la feuille prend 70 % de la hauteur ; au-dessus, le mur et ses estampes ; dessous, le plancher
	_sheet = Rect2(_f.position + Vector2(30, 118) * u, Vector2(340, 562) * u)
	_paint = Rect2(_sheet.position + Vector2(0, 0.18 * _sheet.size.y), Vector2(_sheet.size.x, 0.82 * _sheet.size.y))
	if _sheet != _strokes_sheet:
		_build_painting()
	var safe := UiKit.safe_insets(size)
	_skip_btn.visible = _t > 2.0 and _end_t < 0.0 and _t < T_FADE
	_skip_btn.size = Vector2(96, 36) * u
	_skip_btn.position = Vector2(_f.end.x - 104.0 * u, _f.end.y - safe.y - 52.0 * u)
	_skip_btn.font_size = int(12 * u)
	_skip_btn.modulate.a = UiKit.ease_out((_t - 2.0) / 0.5) * 0.8
	# le calque de la feuille suit la plongée (grossie autour du cœur de la vague) et s'élargit pour couvrir l'écran
	var zoom := _k(_t, T_ZOOM, 1.3)
	var z := 1.0 + 7.0 * pow(zoom, 1.7)
	var g := zoom * 400.0 * u
	var xf := _cur_zoom_xf()
	_paper.position = xf.origin + (_sheet.position - Vector2(g, g)) * z
	_paper.scale = Vector2(z, z)
	_paper.size = _sheet.size + Vector2(2.0 * g, 2.0 * g)
	_over.position = Vector2.ZERO
	_over.size = size
	_paper.queue_redraw()
	_over.queue_redraw()


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	_ci = self
	_base = Transform2D.IDENTITY
	if _t < 0.0 or size.x < 10.0:
		return
	_alpha()
	if modulate.a <= 0.002:
		return
	var zoom := _k(_t, T_ZOOM, 1.3)
	if zoom < 1.0:
		# fond : la nuit de l'atelier
		_ci.draw_rect(Rect2(Vector2.ZERO, size), _c(NIGHT))
		_atelier(1.0 - zoom)


## Opacité globale : seulement le fondu court après PASSER (modulate sur tout le contrôle, calques compris) ;
## la vraie sortie est l'iris d'encre de _enso_swirl.
func _alpha() -> void:
	_a = 1.0
	modulate.a = 1.0 - UiKit.ease_out(_end_t / SKIP_FADE) if _end_t >= 0.0 else 1.0


## Dessin des calques : "paper" (la feuille, écrêtée, dans le repère écran d'avant la plongée) et "over"
## (par-dessus tout : Vague Noire, main, ensō, encre qui recouvre, anneau du toucher).
func _draw_part(ci: CanvasItem, part: String) -> void:
	if _t < 0.0 or size.x < 10.0:
		return
	_alpha()
	if modulate.a <= 0.002:
		return
	_ci = ci
	var u := _u
	var zoom := _k(_t, T_ZOOM, 1.3)
	if part == "paper":
		if _t >= T_ENSO + 1.5:
			return  # l'encre a tout recouvert
		var g := zoom * 400.0 * u
		_base = Transform2D(0.0, -(_sheet.position - Vector2(g, g)))
		_ci.draw_set_transform_matrix(_base)
		_sheet_and_painting(zoom)
	else:
		_base = Transform2D.IDENTITY
		# la Vague Noire hors de la feuille, puis la main du peintre, par-dessus tout
		if zoom < 1.0:
			if _t > T_DARK:
				_kuronami(1.0 - zoom)
			_hand(1.0 - zoom)
		# l'ensō d'encre, l'encre qui recouvre tout, puis l'iris qui s'ouvre sur la mer
		if _t >= T_ENSO:
			_enso_swirl()
		# le toucher maintenu : anneau qui se remplit
		if _holding and _hold_t > 0.08:
			var k := _hold_t / SKIP_HOLD
			_ci.draw_arc(_hold_p, 26.0 * u, -PI / 2.0, -PI / 2.0 + TAU * k, 40, Color(Toon.WASHI, 0.9), 3.0 * u, true)
			_ci.draw_arc(_hold_p, 26.0 * u, 0, TAU, 40, Color(Toon.WASHI, 0.25), 1.0 * u, true)
	_ci = self


## Transformation de plongée : la vague grossit autour d'elle-même, puis glisse vers le centre de l'écran.
func _zoom_xf(wave_c: Vector2, z: float, zoom: float) -> Transform2D:
	var target := wave_c.lerp(_f.get_center(), UiKit.ease_out(zoom))
	return Transform2D(0.0, Vector2(z, z), 0.0, target - wave_c * z)


## La transformation de plongée à cet instant (identité avant T_ZOOM).
func _cur_zoom_xf() -> Transform2D:
	var zoom := _k(_t, T_ZOOM, 1.3)
	return _zoom_xf(_sp(CREST.x, CREST.y), 1.0 + 7.0 * pow(zoom, 1.7), zoom)


## L'atelier la nuit : mur, estampes accrochées, plancher, lampe andon posée au sol, pierre à encre.
func _atelier(k: float) -> void:
	var u := _u
	var f := _f
	var floor_y := _sheet.end.y + 10.0 * u
	# mur et plancher
	_ci.draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, floor_y)), _c(WALL, 0.9 * k))
	_ci.draw_rect(Rect2(Vector2(0, floor_y), Vector2(size.x, size.y)), _c(WOOD, k))
	_ci.draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), _c(BLACK_INK, 0.6 * k), 2.0 * u)
	for i in 3:
		var y := floor_y + (24.0 + 34.0 * i) * u
		_ci.draw_line(Vector2(0, y), Vector2(size.x, y), _c(BLACK_INK, 0.18 * k), 1.0 * u)
	# andon : lampe de papier posée au sol, à gauche de la table ; halo chaud qui respire, vacille quand
	# la Vague Noire monte
	var flick := 1.0
	if _t > T_DARK:
		var d := _t * 13.0
		flick = 0.55 + 0.45 * absf(sin(d) * sin(d * 0.37 + 1.0))
		if _t > T_EAT and fmod(_t * 1.7, 1.0) < 0.12:
			flick *= 0.35
		flick = lerpf(1.0, flick, _k(_t, T_DARK, 1.5))
	var lc := Vector2(f.position.x + 54.0 * u, floor_y + 42.0 * u)
	var glow := (0.5 + 0.03 * sin(_t * 2.1)) * flick
	for i in 7:
		var r := (30.0 + 56.0 * i) * u
		_ci.draw_circle(lc, r, _c(LAMP, 0.1 * glow * (1.0 - float(i) / 7.5)))
	var body := Rect2(lc + Vector2(-18, -36) * u, Vector2(36, 60) * u)
	_ci.draw_rect(body, _c(Color("#F6D9A0").lerp(LAMP, 0.3), (0.75 + 0.25 * flick) * k))
	_ci.draw_rect(body, _c(BLACK_INK, 0.85 * k), false, 1.6 * u)
	for i in 3:
		var y := body.position.y + body.size.y * (0.25 + 0.25 * i)
		_ci.draw_line(Vector2(body.position.x, y), Vector2(body.end.x, y), _c(BLACK_INK, 0.35 * k), 1.0 * u)
	_ci.draw_line(Vector2(body.get_center().x, body.position.y), Vector2(body.get_center().x, body.end.y), _c(BLACK_INK, 0.25 * k), 1.0 * u)
	_ci.draw_colored_polygon(PackedVector2Array([body.position + Vector2(-5, 0) * u, body.position + Vector2(body.size.x + 5.0 * u, 0), body.position + Vector2(body.size.x - 3.0 * u, -5.0 * u), body.position + Vector2(3, -5) * u]), _c(BLACK_INK, k))
	_ci.draw_rect(Rect2(body.position + Vector2(-5.0 * u, body.size.y), Vector2(body.size.x + 10.0 * u, 5.0 * u)), _c(BLACK_INK, k))
	# estampes accrochées au mur (mondes 2 à 8) : happées une à une dans la crête de la Vague Noire
	# (elles glissent vers elle en rapetissant, et disparaissent dans l'encre)
	for i in PRINTS.size():
		var pr := _print_rect(i)
		var eat := UiKit.ease_out(_k(_t, _eat_time(i), 0.55))
		if eat >= 1.0:
			continue
		if eat > 0.0:
			var to := _kuro_mouth(i)
			var c := pr.get_center().lerp(to, eat)
			var sz := pr.size * (1.0 - 0.85 * eat)
			pr = Rect2(c - sz / 2.0, sz)
		_print(i, pr, k * (1.0 - eat * eat))
	# table : pierre à encre et bâton de sumi, à droite de la feuille
	var stone := Vector2(f.position.x + 318.0 * u, floor_y + 62.0 * u)
	_ellipse(stone + Vector2(0, 6) * u, 40.0 * u, 16.0 * u, _c(BLACK_INK, 0.45 * k))
	_ellipse(stone, 38.0 * u, 14.0 * u, _c(Color("#2E2B30"), k))
	_ellipse(stone, 26.0 * u, 8.0 * u, _c(BLACK_INK, k))
	_ci.draw_rect(Rect2(stone + Vector2(-70, -14) * u, Vector2(14, 28) * u), _c(BLACK_INK, k))
	_ci.draw_rect(Rect2(stone + Vector2(-70, -14) * u, Vector2(14, 28) * u), _c(Toon.GOLD, 0.6 * k), false, 1.0 * u)


## Les sept estampes, en une rangée au-dessus de la feuille.
func _print_rect(i: int) -> Rect2:
	var u := _u
	return Rect2(_f.position + Vector2(32.0 + 48.0 * i, 48.0) * u, Vector2(44, 58) * u)


## Heure à laquelle l'estampe i est avalée (ordre EAT_ORDER : de la crête vers la gauche, rangée par rangée).
func _eat_time(i: int) -> float:
	return T_EAT + EAT_STEP * EAT_ORDER.find(i)


## Estampe accrochée : petit cadre d'encre, papier, et le monde en trois traits.
func _print(i: int, r: Rect2, k: float) -> void:
	if k <= 0.01:
		return
	var u := _u
	_ci.draw_rect(r.grow(2.0 * u), _c(BLACK_INK, k))
	_ci.draw_rect(r, _c(Toon.WASHI.darkened(0.08), k))
	var c := r.get_center()
	var s := r.size.x
	var ink := _c(Toon.SUMI, k)
	var w := 1.8 * u
	match PRINTS[i]:
		"kitsune":  # renard : museau, deux oreilles, queue
			_ci.draw_polyline(PackedVector2Array([c + Vector2(-0.3, 0.1) * s, c + Vector2(-0.12, -0.26) * s, c + Vector2(0.0, -0.06) * s, c + Vector2(0.12, -0.26) * s, c + Vector2(0.3, 0.1) * s]), ink, w, true)
			_ci.draw_line(c + Vector2(-0.3, 0.1) * s, c + Vector2(0.3, 0.1) * s, ink, w, true)
			UiKit.brush_line(_ci, c + Vector2(-0.3, 0.3) * s, c + Vector2(0.34, 0.2) * s, 0.12 * s, _c(Toon.VERMILION, 0.8 * k))
		"yuki":  # neige : deux monts et des flocons
			_ci.draw_arc(c + Vector2(-0.12, 0.3) * s, 0.26 * s, PI, TAU, 10, ink, w, true)
			_ci.draw_arc(c + Vector2(0.18, 0.3) * s, 0.2 * s, PI, TAU, 10, ink, w, true)
			for j in 3:
				_ci.draw_circle(c + Vector2(-0.22 + 0.22 * j, -0.3 + 0.1 * (j % 2)) * s, 0.035 * s, ink)
		"faille":  # faille : éclair de roche, deux bords
			_ci.draw_polyline(PackedVector2Array([c + Vector2(-0.1, -0.36) * s, c + Vector2(0.06, -0.1) * s, c + Vector2(-0.08, 0.08) * s, c + Vector2(0.1, 0.38) * s]), ink, w * 1.3, true)
			_ci.draw_line(c + Vector2(-0.3, -0.3) * s, c + Vector2(-0.28, 0.34) * s, ink, w * 0.7, true)
			_ci.draw_line(c + Vector2(0.3, -0.3) * s, c + Vector2(0.28, 0.34) * s, ink, w * 0.7, true)
		"fuji":  # Fuji rouge : le cône, la neige, un nuage
			_ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.36, 0.3) * s, c + Vector2(0.0, -0.3) * s, c + Vector2(0.36, 0.3) * s]), _c(Toon.VERMILION.darkened(0.15), 0.9 * k))
			_ci.draw_polyline(PackedVector2Array([c + Vector2(-0.1, -0.13) * s, c + Vector2(-0.04, -0.08) * s, c + Vector2(0.0, -0.3) * s, c + Vector2(0.05, -0.1) * s, c + Vector2(0.1, -0.13) * s]), _c(Toon.WASHI, k), w, true)
			_ci.draw_line(c + Vector2(-0.3, -0.26) * s, c + Vector2(-0.08, -0.26) * s, ink, w * 0.8, true)
		"tengu":  # tengu : long nez de profil, l'œil, une aile
			_ci.draw_polyline(PackedVector2Array([c + Vector2(-0.1, -0.3) * s, c + Vector2(-0.14, 0.0) * s, c + Vector2(0.3, 0.06) * s, c + Vector2(-0.1, 0.16) * s]), _c(Toon.VERMILION, 0.9 * k), w * 1.4, true)
			_ci.draw_circle(c + Vector2(-0.02, -0.1) * s, 0.04 * s, ink)
			_ci.draw_arc(c + Vector2(-0.3, 0.3) * s, 0.3 * s, -PI * 0.55, -PI * 0.05, 10, ink, w, true)
		"ryugu":  # palais marin : toit retroussé, pilier, vagues dessous
			_ci.draw_polyline(PackedVector2Array([c + Vector2(-0.34, -0.1) * s, c + Vector2(-0.2, -0.22) * s, c + Vector2(0.2, -0.22) * s, c + Vector2(0.34, -0.1) * s]), ink, w * 1.3, true)
			_ci.draw_line(c + Vector2(0.0, -0.22) * s, c + Vector2(0.0, 0.14) * s, ink, w, true)
			for j in 2:
				_ci.draw_arc(c + Vector2(-0.14 + 0.28 * j, 0.32) * s, 0.14 * s, PI, TAU, 8, _c(Toon.PRUSSIAN, k), w, true)
		_:  # Yomi : porte sombre et spirale d'âmes
			_ci.draw_rect(Rect2(c + Vector2(-0.2, -0.1) * s, Vector2(0.4, 0.44) * s), _c(HEM, 0.9 * k))
			_ci.draw_line(c + Vector2(-0.3, -0.1) * s, c + Vector2(0.3, -0.1) * s, ink, w * 1.3, true)
			var pts := PackedVector2Array()
			for j in 16:
				var a := float(j) / 15.0
				pts.append(c + Vector2(0, -0.26) * s + Vector2.from_angle(a * TAU * 1.5) * 0.12 * s * a)
			_ci.draw_polyline(pts, ink, w * 0.8, true)


## La Vague Noire (Kuro-Nami) : une vraie crête de vague en sumi, même construction que la Grande Vague
## mais noire (corps en cinq coups, crête recourbée, griffes d'écume noires), qui monte depuis la crête peinte,
## déborde du cadre et se recourbe au-dessus des estampes ; des gouttes montent (l'encre coule à l'envers) ;
## le masque de nō (direction « Masque d'encre » : washi cerné d'encre, yeux fendus, bouche) émerge dans la
## crête ; les estampes happées disparaissent dans une tache d'encre au bord de sa face.
func _kuronami(k: float) -> void:
	var u := _u
	var rise := UiKit.ease_out(_k(_t, T_DARK, 2.4))
	if rise <= 0.0:
		return
	var ink := _c(BLACK_INK, k)
	# le corps : cinq coups larges du dos vers la face, qui s'allongent ensemble depuis la crête peinte
	for i in 6:
		var fr := float(i) / 5.0
		var path := _mix(_kuro_o, _kuro_i, fr)
		_brush(path, _k(rise, 0.05 * i, 0.8), 26.0 * u, ink, 0.3)
	# les griffes d'écume noires qui retombent du dessous de la langue, puis des bords du dos
	var claws := _k(_t, T_DARK + 1.5, 1.0)
	for i in 7:
		var kk := _k(claws, float(i) / 8.0, 0.3)
		if kk <= 0.0:
			continue
		var p0 := _pt_at(_kuro_i, 0.98 - 0.06 * i)
		var dir := Vector2(-0.3 - 0.08 * i, 1.0).normalized()
		_brush(_claw(p0, dir, (22.0 + 12.0 * (i % 3)) * u, 0.35), kk, 7.0 * u, ink, 0.9)
	for i in 9:
		var ph := fmod(_t * (0.5 + 0.1 * (i % 3)) + i * 0.37, 1.0)
		var base := _pt_at(_kuro_o, 0.02 + 0.03 * i)
		_ci.draw_circle(base + Vector2(16.0 * sin(i * 2.3), -(10.0 + 30.0 * ph)) * u, (3.5 - 2.5 * ph) * u, _c(BLACK_INK, (1.0 - ph) * rise * k))
	# les estampes happées : tache d'encre qui gonfle au bord de la face, là où chacune disparaît
	for i in PRINTS.size():
		var eat := _k(_t, _eat_time(i), 0.55)
		if eat <= 0.0:
			continue
		var m := _kuro_mouth(i)
		var rr := (6.0 + 22.0 * sin(minf(eat * 1.3, 1.0) * PI)) * u
		var blot := PackedVector2Array()
		for j in 16:
			var ang := TAU * float(j) / 16.0
			blot.append(m + Vector2.from_angle(ang) * rr * (1.0 + 0.25 * sin(ang * 3.0 + _t * 5.0 + i)))
		_ci.draw_colored_polygon(blot, ink)
	# le masque de nō, dans la crête : visage de washi cerné d'encre, yeux fendus, sourcils hauts, bouche
	var mk := UiKit.ease_out(_k(_t, T_MASK, 1.2))
	if mk > 0.0:
		var mc := _pt_at(_kuro_o, 0.8).lerp(_pt_at(_kuro_i, 0.8), 0.5) + Vector2(0, 14.0 * (1.0 - mk)) * u
		var ms := 24.0 * u * (0.7 + 0.3 * mk)
		var face := PackedVector2Array()
		for j in 24:
			var ang := TAU * float(j) / 24.0
			var rr := ms * (1.0 + 0.2 * cos(ang * 2.0)) * (1.0 - 0.15 * maxf(0.0, sin(ang)))  # ovale au menton étroit
			face.append(mc + Vector2(cos(ang) * rr * 0.86, sin(ang) * rr * 1.1))
		_ci.draw_colored_polygon(face, _c(MASK, mk * k))
		_outline(face, _c(BLACK_INK, mk * k), 1.6 * u)
		var sq := 0.6 + 0.4 * absf(sin(_t * 0.9))
		for sgn in [-1.0, 1.0]:
			var ec := mc + Vector2(sgn * 0.42, -0.12) * ms
			_ci.draw_colored_polygon(PackedVector2Array([ec + Vector2(-0.3, 0) * ms, ec + Vector2(0, -0.11 * sq) * ms, ec + Vector2(0.3, 0) * ms, ec + Vector2(0, 0.08 * sq) * ms]), _c(BLACK_INK, mk * k))
			_ci.draw_line(ec + Vector2(0.1 * sgn, 0.05) * ms, ec + Vector2(0.14 * sgn, 0.42) * ms, _c(BLACK_INK, 0.8 * mk * k), 1.4 * u, true)
			_ci.draw_arc(ec + Vector2(0, 0.12) * ms, 0.4 * ms, PI * 1.15, PI * 1.85, 8, _c(BLACK_INK, 0.9 * mk * k), 1.3 * u, true)
		_ci.draw_arc(mc + Vector2(0, 0.42) * ms, 0.26 * ms, PI * 0.15, PI * 0.85, 8, _c(BLACK_INK, 0.7 * mk * k), 1.5 * u, true)
		_ci.draw_arc(mc + Vector2(0, 0.42) * ms, 0.26 * ms, PI * 0.15, PI * 0.85, 8, _c(Toon.VERMILION, 0.5 * mk * k), 0.9 * u, true)


## Où l'estampe i disparaît : le point de la face de la Vague Noire au-dessus d'elle (le plus proche en x).
func _kuro_mouth(i: int) -> Vector2:
	var to := _print_rect(i).get_center()
	var best := _kuro_i[0]
	var bd := INF
	var n := _kuro_i.size()
	for j in range(int(n * 0.45), n):
		var d := absf(_kuro_i[j].x - to.x)
		if d < bd:
			bd = d
			best = _kuro_i[j]
	return best + Vector2(0, 6.0 * _u)


## La feuille de washi et ce qu'on y peint : la Grande Vague, puis le Ronin de papier.
func _sheet_and_painting(zoom: float) -> void:
	var u := _u
	var r := _sheet
	# à la plongée, la feuille s'élargit : elle couvre tout l'écran
	if zoom > 0.0:
		var g := zoom * 400.0 * u
		_ci.draw_rect(r.grow(g), _c(Toon.PAPER, 0.96))
	UiKit.washi_sheet(_ci, r, Toon.PAPER, Toon.SUMI, _a, u, 3.0)
	_painting()
	_ronin_scene()


# ------------------------------------------------------------------ la Grande Vague, coup de pinceau après coup de pinceau

## Les coups de pinceau de la Grande Vague de Kanagawa, dans l'ordre où ils se superposent (la mer au fond, la
## grande vague, le Fuji dans le creux, la vague secondaire devant, les barques, le sceau). Chacun a son heure
## (depuis T_WAVE) : le corps bleu de Prusse en cinq larges coups du dos à la langue, les veines claires, l'écume
## de la crête et ses griffes, les embruns, la mer, la vague secondaire, le Fuji, deux barques, le sceau.
func _build_painting() -> void:
	_strokes_sheet = _sheet
	_strokes = []
	var W := _paint.size.x
	var H := _paint.size.y
	var outer := _curve(OUTER)
	var inner := _curve(INNER)
	# la mer du creux (sous tout le reste)
	_add("line", 5.8, 0.4, _curve([Vector2(0.26, 0.76), Vector2(0.5, 0.75), Vector2(0.78, 0.74)]), 0.11 * H, PRUSSIAN_DEEP, 0.1)
	_add("line", 6.2, 0.4, _curve([Vector2(0.26, 0.86), Vector2(0.45, 0.86), Vector2(0.66, 0.85)]), 0.11 * H, PRUSSIAN_DEEP, 0.1)
	_add("line", 6.5, 0.4, _curve([Vector2(0.26, 0.96), Vector2(0.42, 0.96), Vector2(0.58, 0.95)]), 0.11 * H, PRUSSIAN_DEEP, 0.1)
	# le corps de la grande vague : cinq coups larges du dos vers la face, du bas à gauche jusqu'à la langue
	for i in 5:
		var fr := float(i) / 4.0
		_add("line", 0.5 * i, 1.1, _mix(outer, inner, fr), 0.1 * W, PRUSSIAN_DEEP.lerp(Toon.PRUSSIAN, fr), 0.35)
	# veines claires qui suivent la courbe
	for i in 3:
		_add("line", 3.0 + 0.25 * i, 0.6, _sub(_mix(outer, inner, 0.22 + 0.26 * i), 0.25, 0.93), 0.011 * W, WAVE, 0.5)
	# l'écume : la crête, le dessous de la langue, les griffes qui retombent, les embruns
	_add("line", 4.0, 0.7, _sub(outer, 0.5, 1.0), 0.05 * W, Toon.FOAM, 0.3)
	var under := _sub(inner, 0.6, 1.0)
	under.reverse()
	_add("line", 4.6, 0.4, under, 0.03 * W, Toon.FOAM, 0.6)
	for i in 7:
		var p0 := _pt_at(inner, 0.98 - 0.065 * i)
		var dir := Vector2(-0.35 - 0.1 * i, 1.0).normalized()
		_add("line", 4.9 + 0.08 * i, 0.3, _claw(p0, dir, (0.05 + 0.025 * (i % 3)) * H, 0.35), 0.022 * W, Toon.FOAM, 0.9)
	for i in 10:
		var pf := _pt_at(outer, 0.52 + 0.045 * i) + Vector2(5.0 * sin(i * 2.1), -8.0 - 9.0 * absf(cos(i * 1.3))) * _u
		_add("dot", 5.5 + 0.03 * i, 0.1, PackedVector2Array([pf, pf]), (1.4 + 1.6 * absf(sin(i * 1.7))) * _u, Toon.FOAM, 0.0)
	# le Fuji dans le creux (avant la vague secondaire qui passe devant)
	_add("fuji", 8.6, 0.5, PackedVector2Array([_sp(0.41, 0.72), _sp(0.53, 0.6), _sp(0.65, 0.72)]), 0.0, PRUSSIAN_DEEP, 0.0)
	# la vague secondaire, au premier plan à droite : trois coups, son écume, trois griffes
	for i in 3:
		var off := Vector2(0.0, 0.085 * i)
		var keys := []
		for p in W2:
			keys.append(p + off)
		_add("line", 6.9 + 0.3 * i, 0.6, _curve(keys), 0.1 * W, Toon.PRUSSIAN.lerp(PRUSSIAN_DEEP, float(i) / 2.0), 0.15)
	var w2 := _curve(W2)
	_add("line", 8.0, 0.4, _sub(w2, 0.5, 0.95), 0.03 * W, Toon.FOAM, 0.6)
	for i in 3:
		var p0 := _pt_at(w2, 0.62 + 0.12 * i) + Vector2(0, 0.01 * H)
		_add("line", 8.3 + 0.08 * i, 0.25, _claw(p0, Vector2(-0.5, 1.0).normalized(), 0.04 * H, 0.3), 0.018 * W, Toon.FOAM, 0.9)
	# deux barques de pêcheurs, longues et basses : dans le creux, et sur la face de la vague secondaire
	for i in 2:
		var b0 := _sp(0.42, 0.8) if i == 0 else _sp(0.82, 0.69)
		var bl := 0.1 * W
		var xf := Transform2D(-0.25 if i == 0 else -0.6, b0)
		_add("boat", 9.1 + 0.3 * i, 0.35, xf * PackedVector2Array([Vector2(-bl, -0.18 * bl), Vector2(-bl * 0.6, 0), Vector2(bl * 0.5, 0), Vector2(bl, -0.22 * bl)]), 0.012 * W, Toon.SUMI, 0.0)
	# le sceau du peintre, dans le ciel en haut à droite
	var sc := _sheet.position + Vector2(0.9, 0.07) * _sheet.size
	_add("seal", 9.9, 0.3, PackedVector2Array([sc, sc]), 0.0, Toon.VERMILION, 0.0)
	# la Vague Noire : son dos et sa face, de la crête peinte jusqu'à sa langue au-dessus des estampes
	var ko := []
	var ki := []
	for p in KURO_OUT:
		ko.append(_f.position + p * _u)
	for p in KURO_IN:
		ki.append(_f.position + p * _u)
	_kuro_o = _smooth(ko, 6)
	_kuro_i = _smooth(ki, 6)


func _add(kind: String, t0: float, dur: float, pts: PackedVector2Array, w: float, col: Color, taper: float) -> void:
	_strokes.append({"kind": kind, "t0": t0, "dur": dur, "pts": pts, "w": w, "col": col, "taper": taper})


## Dessine la Grande Vague telle qu'elle est à cet instant : chaque coup jusqu'à sa fraction peinte.
func _painting() -> void:
	var u := _u
	var t := _t - T_WAVE
	if t < 0.0:
		return
	for s in _strokes:
		var k := _k(t, float(s["t0"]), float(s["dur"]))
		if k <= 0.0:
			continue
		var pts: PackedVector2Array = s["pts"]
		var col := _c(s["col"])
		match String(s["kind"]):
			"line":
				_brush(pts, k, float(s["w"]), col, float(s["taper"]))
			"dot":
				_ci.draw_circle(pts[0], float(s["w"]) * k, col)
			"boat":
				var bw := float(s["w"])
				_brush(pts, k, bw, col, 0.3)
				for j in 4:
					if k < 0.3 + 0.2 * j:
						break
					_ci.draw_circle(_pt_at(pts, 0.25 + 0.17 * j) + Vector2(0, -0.9 * bw), bw * 0.6, col)
			"fuji":
				var ke := UiKit.ease_out(k)
				var fl := pts[0]
				var ap := pts[1]
				var fr := pts[2]
				_ci.draw_colored_polygon(PackedVector2Array([fl, fl.lerp(ap, ke), fr.lerp(ap, ke), fr]), col)
				if k > 0.8:
					var sn := (k - 0.8) / 0.2
					var hw := (fr.x - fl.x) * 0.16
					_ci.draw_colored_polygon(PackedVector2Array([ap + Vector2(-hw, hw * 1.1), ap, ap + Vector2(hw, hw * 1.1), ap + Vector2(hw * 0.4, hw * 0.75), ap + Vector2(0, hw * 1.0), ap + Vector2(-hw * 0.4, hw * 0.75)]), _c(Toon.FOAM, 0.95 * sn))
			"seal":
				var ss := 1.0 + 0.5 * (1.0 - UiKit.ease_out(k))
				# frappé comme une signature, un peu de travers ; composé avec la plongée en cours
				_ci.draw_set_transform_matrix(_base * Transform2D(0.03, Vector2(ss, ss), 0.0, pts[0]))
				UiKit.hanko(_ci, Rect2(Vector2(-11, -17) * u, Vector2(22, 34) * u), "一筆", Toon.VERMILION, Toon.PAPER, k * _a, u, 2.0)
				_ci.draw_set_transform_matrix(_base)
	# l'encre noire qui déborde : tache à la pointe de la langue, d'où jaillit la Vague Noire
	if _t > T_DARK:
		var bk := UiKit.ease_out(_k(_t, T_DARK, 1.2))
		var c := _sp(0.73, 0.33)
		var blot := PackedVector2Array()
		for j in 22:
			var ang := TAU * float(j) / 22.0
			blot.append(c + Vector2.from_angle(ang) * (6.0 + 24.0 * bk) * u * (1.0 + 0.25 * sin(ang * 4.0 + _t * 3.0)))
		_ci.draw_colored_polygon(blot, _c(BLACK_INK, 0.96))


## Où se trouve la pointe du pinceau pendant la Grande Vague : au bout du dernier coup commencé.
func _wave_tip() -> Vector2:
	var t := _t - T_WAVE
	var best: Dictionary = {}
	for s in _strokes:
		if float(s["t0"]) <= t and (best.is_empty() or float(s["t0"]) >= float(best["t0"])):
			best = s
	if best.is_empty():
		return _f.position + Vector2(380, 700) * _u
	var k := _k(t, float(best["t0"]), float(best["dur"]))
	var pts: PackedVector2Array = best["pts"]
	if String(best["kind"]) == "seal":
		return pts[0] + Vector2(0, 10.0 * (1.0 - k)) * _u
	return _pt_at(pts, k)


# ------------------------------------------------------------------ le Ronin de papier

## Le Ronin de papier : né d'un seul trait, il prend ses couleurs, ouvre les yeux, puis est poussé dans la vague.
func _ronin_scene() -> void:
	if _t < T_ONE:
		return
	var u := _u
	var one := _k(_t, T_ONE, ONE_DUR)
	var s := 3.0 * u
	var feet := _ronin_feet()
	var push := UiKit.ease_out(_k(_t, T_PUSH, 1.4))
	s = lerpf(s, 1.0 * u, push)
	var fade := 1.0 - _k(_t, T_ZOOM + 0.6, 0.5)
	if fade <= 0.0:
		return
	var pose := 0 if _t < T_PUSH else 1
	var xf := Transform2D(0.0, Vector2(s, -s), 0.0, feet)
	# le trait unique, qui ne lève pas : contour continu du ronin, fini sur le fourreau
	var fill := UiKit.ease_out(_k(_t, T_FILL, 1.0))
	if one > 0.0 and fill < 1.0:
		var pts := PackedVector2Array()
		var total: float = _ronin_len[_ronin_len.size() - 1]
		var lim := _ease_stroke(one) * total
		for i in _ronin_path.size():
			if _ronin_len[i] > lim:
				var i0 := maxi(i - 1, 0)
				var seg := _ronin_len[i] - _ronin_len[i0]
				var kk := 0.0 if seg <= 0.0001 else (lim - _ronin_len[i0]) / seg
				pts.append(xf * _ronin_path[i0].lerp(_ronin_path[i], kk))
				break
			pts.append(xf * _ronin_path[i])
		if pts.size() >= 2:
			_brush_path(pts, 3.4 * u, _c(Toon.SUMI, (1.0 - fill) * fade))
	# la figure peinte, fondue par-dessus le trait : encres, puis couleurs, l'écharpe en dernier, les yeux
	if fill > 0.0:
		var scarf := UiKit.ease_out(_k(_t, T_SCARF, 0.7))
		var eyes := UiKit.ease_out(_k(_t, T_EYES, 0.4))
		_ronin(feet, s, 1.0, pose, fill * fade, fill, scarf, eyes)
	# poussé : traits de vitesse derrière lui
	if push > 0.0 and push < 1.0:
		var d := (_sp(CREST.x, CREST.y) - _ronin_feet_at(0.0)).normalized()
		for i in 3:
			var a := float(i) / 3.0 - 0.33
			var p0 := feet - d * (14.0 + 10.0 * a) * u + d.orthogonal() * (a * 18.0) * u - Vector2(0, 18.0 * s)
			_ci.draw_line(p0, p0 - d * (16.0 + 8.0 * absf(a)) * u, _c(Toon.SUMI, 0.45 * sin(push * PI) * fade), 1.5 * u, true)


## Les pieds du ronin : debout dans le creux de l'estampe, puis poussé vers le cœur de la vague.
func _ronin_feet() -> Vector2:
	return _ronin_feet_at(UiKit.ease_out(_k(_t, T_PUSH, 1.4)))


func _ronin_feet_at(push: float) -> Vector2:
	return _sp(0.58, 0.92).lerp(_sp(CREST.x, CREST.y) + Vector2(0, 10) * _u, push)


## Courbe du trait unique : départ franc, milieu régulier, fin qui ralentit sur le fourreau.
func _ease_stroke(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x - 0.1 * sin(x * TAU) * (1.0 - x) + 0.05 * sin(x * TAU * 3.0) * x * (1.0 - x)


## Le trait unique du Ronin, en unités du ronin (y vers le haut, pieds en 0 ; il regarde à droite) : part du bout
## de l'écharpe, remonte au cou, longe la queue de cheval, fait le tour du chapeau, descend la joue et le menton,
## l'épaule et le flanc droits, le hakama, les deux pieds, remonte le flanc gauche, passe par la main sur la
## garde et finit le long du fourreau, jusqu'à sa pointe.
func _build_ronin_path() -> void:
	var keys := [Vector2(-15.0, 19.5), Vector2(-9.0, 21.5), Vector2(-3.0, 22.6), Vector2(-6.5, 25.5), Vector2(-9.5, 30.5),
		Vector2(-13.0, 35.0), Vector2(0.4, 46.0), Vector2(14.6, 35.6), Vector2(10.5, 32.0), Vector2(10.0, 27.0),
		Vector2(6.5, 23.5), Vector2(7.0, 21.0), Vector2(7.6, 17.0), Vector2(7.2, 13.5), Vector2(8.5, 5.5),
		Vector2(6.0, 0.5), Vector2(2.5, 0.5), Vector2(0.2, 5.5), Vector2(-2.5, 0.5), Vector2(-6.0, 0.5),
		Vector2(-8.5, 5.5), Vector2(-7.5, 13.0), Vector2(-2.0, 12.5), Vector2(2.5, 14.0), Vector2(-1.5, 12.6),
		Vector2(-15.5, 3.5)]
	_ronin_path = _chaikin(keys, 2)
	_ronin_len = PackedFloat32Array()
	var acc := 0.0
	for i in _ronin_path.size():
		if i > 0:
			acc += _ronin_path[i].distance_to(_ronin_path[i - 1])
		_ronin_len.append(acc)


## La main âgée du peintre, en silhouette de sumi plein : manche de kimono en trapèze venue du bas à droite,
## poing fermé sur le manche, deux doigts allongés le long du pinceau ; la pointe (lissée) suit ce qui se peint,
## trempe dans le sumi, pousse le ronin, puis se retire.
func _hand(k: float) -> void:
	var u := _u
	var rest := _f.position + Vector2(400, 740) * u  # au repos : en bas à droite, sur la table
	var target := rest
	if _t < T_WAVE - 0.4:
		target = _f.position + Vector2(480, 820) * u  # hors champ avant d'entrer
	elif _t < T_WAVE + 10.3:
		target = _wave_tip()
	elif _t < T_DIP:
		target = rest  # se retire pendant que la Vague Noire monte
	elif _t < T_ONE:
		var stone := Vector2(_f.position.x + 318.0 * u, _sheet.end.y + 72.0 * u)
		var dk := _k(_t, T_DIP, 1.0)
		target = stone + Vector2(0, -10.0 + 12.0 * sin(dk * PI)) * u
	elif _t < T_ONE + ONE_DUR:
		target = _one_tip(_k(_t, T_ONE, ONE_DUR))
	elif _t < T_PUSH:
		target = _f.position + Vector2(380, 700) * u
	else:
		var push := UiKit.ease_out(_k(_t, T_PUSH, 1.4))
		var s := lerpf(3.0, 1.0, push) * u
		target = _ronin_feet() + Vector2(-9.0 * s, -19.0 * s)
	if not _tip_set:
		_tip = target
		_tip_set = true
	_tip = _tip.lerp(target, clampf(UiKit.real_delta() * 9.0, 0.0, 1.0))
	var tip := _tip
	if tip.x > _f.end.x + 70.0 * u:
		return
	var sumi := _c(Toon.SUMI, k)
	# pinceau : manche de bambou tenu en oblique (vers le haut à droite), virole d'or, touffe effilée
	var dir := Vector2(0.52, -1.0).normalized()
	var ferrule := tip + dir * 24.0 * u
	var top := tip + dir * 150.0 * u
	_ci.draw_line(ferrule, top, sumi, 5.2 * u, true)
	_ci.draw_line(ferrule, top, _c(Color("#8A6A45"), k), 3.2 * u, true)
	_ci.draw_line(ferrule - dir * 2.0 * u, ferrule + dir * 5.0 * u, _c(Toon.GOLD, k), 5.6 * u, true)
	_ci.draw_colored_polygon(PackedVector2Array([ferrule + dir.orthogonal() * 3.2 * u, ferrule - dir.orthogonal() * 3.2 * u, tip]), _c(BLACK_INK, k))
	# la manche : trapèze de sumi, du poignet (étroit) vers le bas à droite (large, hors champ)
	var grip := tip + dir * 58.0 * u
	var wrist := grip + Vector2(10, 12) * u
	var down := Vector2(0.62, 0.78)
	var side := down.orthogonal()
	var cuff := wrist + down * 150.0 * u
	_ci.draw_colored_polygon(PackedVector2Array([wrist + side * 14.0 * u, cuff + side * 40.0 * u, cuff - side * 34.0 * u, wrist - side * 14.0 * u]), sumi)
	# le poing sur le manche, le pouce, deux doigts allongés le long du pinceau
	_ci.draw_circle(grip + Vector2(3, 5) * u, 13.0 * u, sumi)
	_ci.draw_circle(wrist + Vector2(-4, -2) * u, 10.0 * u, sumi)
	_ci.draw_circle(grip + Vector2(7, -11) * u, 5.0 * u, sumi)
	_ci.draw_line(grip + Vector2(-4, -2) * u, grip - dir * 24.0 * u + Vector2(-6, 0) * u, sumi, 6.5 * u, true)
	_ci.draw_line(grip + Vector2(2, 6) * u, grip - dir * 16.0 * u + Vector2(3, 4) * u, sumi, 6.0 * u, true)


## Où se trouve la pointe du pinceau pendant le trait unique (k ∈ 0..1).
func _one_tip(k: float) -> Vector2:
	var s := 3.0 * _u
	var xf := Transform2D(0.0, Vector2(s, -s), 0.0, _ronin_feet_at(0.0))
	var total: float = _ronin_len[_ronin_len.size() - 1]
	var lim := _ease_stroke(k) * total
	for i in range(1, _ronin_path.size()):
		if _ronin_len[i] >= lim:
			var seg := _ronin_len[i] - _ronin_len[i - 1]
			var kk := 0.0 if seg <= 0.0001 else (lim - _ronin_len[i - 1]) / seg
			return xf * _ronin_path[i - 1].lerp(_ronin_path[i], kk)
	return xf * _ronin_path[_ronin_path.size() - 1]


## L'ensō d'encre : un cercle au pinceau se peint au cœur de la vague, l'encre en déborde et recouvre tout ;
## puis l'encre s'ouvre depuis le centre (iris aux bords d'ensō) sur la mer réelle de l'accueil.
func _enso_swirl() -> void:
	var u := _u
	var c := _f.get_center()
	var ke := _k(_t, T_ENSO, 0.8)
	var r := 130.0 * u
	var open := UiKit.ease_out(_k(_t, T_FADE, 1.5))
	if open <= 0.0:
		UiKit.enso(_ci, c, r, 46.0 * u, _c(BLACK_INK), ke, -PI * 0.4)
		# l'encre déborde de l'ensō : tache qui gonfle jusqu'à couvrir l'écran
		var flood := UiKit.ease_out(_k(_t, T_ENSO + 0.7, 0.7))
		if flood > 0.0:
			_ink_disc(c, (r - 10.0 * u) + (size.length() * 0.6) * flood, 1.0)
		return
	# l'iris : l'encre recule en anneau, du centre vers les bords (il reste un cerne d'ensō, puis plus rien)
	var hole := (size.length() * 0.62) * open
	_ink_ring(c, hole, size.length() * 0.75, 1.0 - _k(open, 0.9, 0.1))


## Disque d'encre aux bords vivants.
func _ink_disc(c: Vector2, r: float, a: float) -> void:
	var pts := PackedVector2Array()
	for j in 40:
		var ang := TAU * float(j) / 40.0
		pts.append(c + Vector2.from_angle(ang) * r * (1.0 + 0.06 * sin(ang * 5.0 + _t * 2.0) + 0.03 * sin(ang * 11.0)))
	_ci.draw_colored_polygon(pts, _c(BLACK_INK, a))


## Anneau d'encre (trou de rayon r0, extérieur r1) : secteurs opaques, bord intérieur vivant comme un ensō.
func _ink_ring(c: Vector2, r0: float, r1: float, a: float) -> void:
	if a <= 0.003:
		return
	var n := 48
	var col := _c(BLACK_INK, a)
	for j in n:
		var a0 := TAU * float(j) / float(n)
		var a1 := TAU * float(j + 1) / float(n)
		var w0 := r0 * (1.0 + 0.05 * sin(a0 * 4.0 + _t * 1.5) + 0.025 * sin(a0 * 9.0))
		var w1 := r0 * (1.0 + 0.05 * sin(a1 * 4.0 + _t * 1.5) + 0.025 * sin(a1 * 9.0))
		_ci.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a0) * w0, c + Vector2.from_angle(a0) * r1 * 1.02, c + Vector2.from_angle(a1) * r1 * 1.02, c + Vector2.from_angle(a1) * w1]), col)


## Le Ronin de papier (intro.gd _ronin, même allure que le héros 3D), avec ses couleurs qui prennent :
## fill (0..1) : opacité des couleurs (chapeau, kimono, hakama, peau) ; scarf : l'écharpe se colore (avant : encre
## pâle) ; eyes : les fentes d'encre s'ouvrent. Pieds en p, s pixels par unité, face ±1, pose 0 debout en garde
## (main sur la garde, sabre au fourreau), 1 ruée (sabre tendu).
func _ronin(p: Vector2, s: float, face: float, pose: int, k: float, fill: float, scarf: float, eyes: float) -> void:
	if k <= 0.01:
		return
	var now := _t
	var lean := 0.0
	var bob := 0.5 + 0.5 * sin(now * 2.0)
	var back := Vector2(-4, 0)
	var front := Vector2(4, 0)
	var hand := Vector2(-1, 13)
	var tip := Vector2(-15.5, 3.5)  # pointe du fourreau
	var tail := 15.0
	var droop := 9.0
	if pose == 1:
		lean = 0.3
		bob = 0.0
		back = Vector2(-10, 3)
		front = Vector2(9, 0)
		hand = Vector2(9, 16)
		tip = Vector2(31, 18)
		tail = 30.0
		droop = -1.0
	_ellipse(p + Vector2(0, 1.5 * s), 12.0 * s, 3.2 * s, _c(Toon.SUMI, 0.14 * k))
	var xf := Transform2D(lean * face, Vector2(face * s, -s), 0.0, p - Vector2(0, bob * s))
	var ink := _c(Toon.SUMI, k)
	var scarf_c := Color("#B9ADA3").lerp(Toon.VERMILION, scarf)
	var scarf_d := Color("#A0948A").lerp(Toon.VERMILION.darkened(0.18), scarf)
	var w1 := sin(now * 3.0)
	var w2 := sin(now * 3.0 - 1.2)
	var w3 := sin(now * 3.0 - 2.3)
	var pan := xf * PackedVector2Array([Vector2(-1, 23), Vector2(-tail * 0.33, 22.5 - droop * 0.3 + 1.2 * w1),
		Vector2(-tail * 0.66, 21.5 - droop * 0.7 + 2.0 * w2), Vector2(-tail, 20.0 - droop + 2.6 * w3)])
	_ci.draw_polyline(pan, ink, 4.4 * s, true)
	_ci.draw_polyline(pan, _c(scarf_c, k), 3.0 * s, true)
	var pan2 := xf * PackedVector2Array([Vector2(-1, 22), Vector2(-tail * 0.3, 21.0 - droop * 0.35 + 1.3 * w2),
		Vector2(-tail * 0.6, 19.5 - droop * 0.75 + 1.8 * w3), Vector2(-tail * 0.82, 17.5 - droop * 1.05 + 2.2 * w1)])
	_ci.draw_polyline(pan2, ink, 3.4 * s, true)
	_ci.draw_polyline(pan2, _c(scarf_d, k), 2.1 * s, true)
	# sabre au fourreau, derrière la hanche (pose 0) : dessiné avant le corps
	if pose == 0:
		_ci.draw_line(xf * Vector2(-1.5, 12.5), xf * tip, ink, 3.2 * s, true)
		_ci.draw_line(xf * Vector2(-1.5, 12.5), xf * tip, _c(HEM.lightened(0.12), k), 1.8 * s, true)
	var hak := Toon.PAPER.lerp(HAKAMA, fill)
	var kim := Toon.PAPER.lerp(KIMONO, fill)
	var straw := Toon.PAPER.lerp(STRAW, fill)
	var skin := Toon.PAPER.lerp(Toon.SKIN, fill)
	var hair := Toon.PAPER.lerp(HAIR, fill)
	# hakama
	_ci.draw_line(xf * Vector2(-2.5, 9), xf * back, ink, 8.2 * s, true)
	_ci.draw_line(xf * Vector2(2.5, 9), xf * front, ink, 8.2 * s, true)
	_ci.draw_line(xf * Vector2(-2.5, 9), xf * back, _c(hak, k), 6.6 * s, true)
	_ci.draw_line(xf * Vector2(2.5, 9), xf * front, _c(hak, k), 6.6 * s, true)
	var skirt := xf * PackedVector2Array([Vector2(-8.5, 5.5), Vector2(8.5, 5.5), Vector2(7, 14), Vector2(-7, 14)])
	_ci.draw_colored_polygon(skirt, _c(hak, k))
	_outline(skirt, ink, 1.1 * s)
	for row in 3:
		var y := 7.0 + 2.6 * float(row)
		var x0 := -6.0 + (1.3 if row % 2 == 1 else 0.0)
		for i in 5:
			var cx := x0 + 2.6 * float(i)
			if absf(cx) > 6.6:
				continue
			_ci.draw_arc(xf * Vector2(cx, y), 1.2 * s, PI * 1.05, PI * 1.95, 8, _c(WAVE, 0.85 * k * fill), 0.75 * s, true)
	_ci.draw_circle(xf * back, 2.7 * s, ink)
	_ci.draw_circle(xf * front, 2.7 * s, ink)
	_ci.draw_circle(xf * (back + Vector2(0.3, 0.8)), 1.7 * s, _c(kim, k))
	_ci.draw_circle(xf * (front + Vector2(0.3, 0.8)), 1.7 * s, _c(kim, k))
	# kimono
	var torso := xf * PackedVector2Array([Vector2(-7, 12.5), Vector2(7, 12.5), Vector2(5.8, 23), Vector2(-5.8, 23)])
	_ci.draw_colored_polygon(torso, _c(kim, k))
	_outline(torso, ink, 1.2 * s)
	_ci.draw_line(xf * Vector2(-3.8, 21.5), xf * Vector2(-4.6, 14.5), _c(Toon.SUMI, 0.35 * k), 0.6 * s, true)
	_ci.draw_polyline(xf * PackedVector2Array([Vector2(-1.8, 22.8), Vector2(1.6, 18.2), Vector2(4.6, 22.8)]), _c(Color.WHITE, k), 1.3 * s, true)
	_ci.draw_polyline(xf * PackedVector2Array([Vector2(-2.4, 22.8), Vector2(1.6, 17.6), Vector2(4.4, 13.2)]), ink, 1.1 * s, true)
	_ci.draw_line(xf * Vector2(4.8, 22.6), xf * Vector2(2.4, 19.4), ink, 0.9 * s, true)
	_ci.draw_line(xf * Vector2(-6.9, 13.6), xf * Vector2(6.9, 13.6), _c(HEM, k), 2.4 * s)
	_ci.draw_line(xf * Vector2(-6.9, 13.6), xf * Vector2(6.9, 13.6), _c(Toon.GOLD, k * fill), 0.5 * s)
	_ci.draw_line(xf * Vector2(-5.8, 23.2), xf * Vector2(6.2, 23.2), ink, 4.6 * s, true)
	_ci.draw_line(xf * Vector2(-5.8, 23.2), xf * Vector2(6.2, 23.2), _c(scarf_c, k), 3.2 * s, true)
	# tête
	var hc := xf * Vector2(1, 30)
	_ci.draw_line(xf * Vector2(-6.5, 31.5), xf * Vector2(-12.5, 25.5), ink, 2.8 * s, true)
	_ci.draw_circle(xf * Vector2(-8.0, 30.0), 1.2 * s, _c(Color.WHITE, k))
	_ci.draw_circle(hc, 9.5 * s, ink)
	_ci.draw_circle(hc, 8.6 * s, _c(hair, k))
	_ci.draw_circle(xf * Vector2(2.6, 28.6), 6.9 * s, _c(skin, k))
	# sourcils, puis les yeux : deux fentes d'encre qui s'ouvrent (eyes 0 : closes, un fil)
	_ci.draw_line(xf * Vector2(0.2, 30.6), xf * Vector2(2.9, 29.9), ink, 0.9 * s, true)
	_ci.draw_line(xf * Vector2(4.5, 29.9), xf * Vector2(7.2, 30.6), ink, 0.9 * s, true)
	var ew := lerpf(0.35, 1.1, eyes) * s
	_ci.draw_line(xf * Vector2(0.8, 28.5), xf * Vector2(3.0, 28.5), ink, ew, true)
	_ci.draw_line(xf * Vector2(4.6, 28.5), xf * Vector2(6.8, 28.5), ink, ew, true)
	if eyes > 0.5:
		var g := (eyes - 0.5) * 2.0
		_ci.draw_circle(xf * Vector2(2.4, 28.5), 0.35 * s, _c(Toon.FOAM, g * k))
		_ci.draw_circle(xf * Vector2(6.2, 28.5), 0.35 * s, _c(Toon.FOAM, g * k))
	_ci.draw_line(xf * Vector2(4.0, 27.6), xf * Vector2(4.3, 26.5), _c(Toon.SUMI, 0.5 * k), 0.5 * s, true)
	_ci.draw_line(xf * Vector2(3.4, 25.3), xf * Vector2(5.2, 25.3), ink, 0.7 * s, true)
	_ci.draw_circle(xf * Vector2(1.2, 26.6), 0.9 * s, _c(Toon.VERMILION, 0.3 * k * fill))
	_ci.draw_circle(xf * Vector2(7.0, 26.6), 0.9 * s, _c(Toon.VERMILION, 0.3 * k * fill))
	# sandogasa
	var hat := xf * PackedVector2Array([Vector2(-13.0, 35.0), Vector2(14.6, 35.6), Vector2(0.4, 46.0)])
	_ci.draw_colored_polygon(hat, _c(straw, k))
	_outline(hat, ink, 1.3 * s)
	_ci.draw_line(xf * Vector2(-9.5, 38.0), xf * Vector2(10.6, 38.4), _c(Toon.SUMI, 0.22 * k), 0.6 * s, true)
	_ci.draw_line(xf * Vector2(-6.0, 41.0), xf * Vector2(6.8, 41.3), _c(Toon.SUMI, 0.22 * k), 0.6 * s, true)
	_ci.draw_line(xf * Vector2(-13.0, 35.0), xf * Vector2(14.6, 35.6), ink, 1.8 * s, true)
	# bras et main
	var sho := Vector2(1, 20)
	var elb := sho.lerp(hand, 0.55) + (Vector2(3, 0) if pose == 0 else Vector2.ZERO)
	_ci.draw_line(xf * sho, xf * elb, ink, 7.0 * s, true)
	_ci.draw_line(xf * sho, xf * elb, _c(kim, k), 5.4 * s, true)
	_ci.draw_circle(xf * elb, 3.5 * s, ink)
	_ci.draw_circle(xf * elb, 2.6 * s, _c(kim, k))
	_ci.draw_line(xf * elb, xf * hand, ink, 3.6 * s, true)
	_ci.draw_line(xf * elb, xf * hand, _c(skin, k), 2.2 * s, true)
	if pose == 0:
		# la main posée sur la garde : poignée tressée et tsuba d'or sous les doigts
		_ci.draw_line(xf * Vector2(-1.5, 12.5), xf * Vector2(3.5, 14.0), ink, 2.6 * s, true)
		_ci.draw_circle(xf * Vector2(-0.6, 12.8), 1.7 * s, _c(Toon.GOLD, k * maxf(fill, 0.3)))
	else:
		var d := (tip - hand).normalized()
		_ci.draw_line(xf * (hand - d * 5.0), xf * (hand + d * 1.0), ink, 2.6 * s, true)
		_ci.draw_line(xf * (hand + d * 1.8), xf * tip, ink, 2.8 * s, true)
		_ci.draw_line(xf * (hand + d * 2.6), xf * tip, _c(Toon.FOAM, k), 1.2 * s, true)
		_ci.draw_circle(xf * (hand + d * 1.3), 1.7 * s, _c(Toon.GOLD, k))
	_ci.draw_circle(xf * hand, 2.2 * s, ink)
	_ci.draw_circle(xf * hand, 1.6 * s, _c(skin, k))


# ------------------------------------------------------------------ outils de dessin

## Coup de pinceau le long d'une polyligne, jusqu'à la fraction k : attaque ronde, largeur w qui s'effile
## de `taper` (0 : constante, 1 : jusqu'au fil) vers la fin, bouts arrondis.
func _brush(pts: PackedVector2Array, k: float, w: float, col: Color, taper: float) -> void:
	var n := pts.size()
	if n < 2 or k <= 0.0 or w <= 0.0 or col.a <= 0.003:
		return
	var kk := clampf(k, 0.0, 1.0)
	var x := kk * float(n - 1)
	var last := mini(int(x), n - 2)
	var prev := pts[0]
	_ci.draw_circle(prev, w * 0.5, col)
	for i in range(1, n):
		var p := pts[i]
		var fr := float(i) / float(n - 1)
		if i > last + 1:
			break
		if i == last + 1:
			p = pts[i - 1].lerp(pts[i], x - float(last))
			fr = kk
		var ww := w * (1.0 - taper * fr)
		_ci.draw_line(prev, p, col, maxf(1.0, ww), true)
		_ci.draw_circle(p, maxf(0.5, ww * 0.5), col)
		prev = p


## Coup de pinceau le long d'une polyligne : largeur qui respire, attaque ronde, fin effilée (le trait unique).
func _brush_path(pts: PackedVector2Array, w: float, col: Color) -> void:
	var n := pts.size()
	if n < 2:
		return
	_ci.draw_circle(pts[0], w * 0.55, col)
	var chunk := 4
	var i := 0
	while i < n - 1:
		var j := mini(i + chunk, n - 1)
		var f := float(i) / float(n - 1)
		var ww := w * (0.8 + 0.25 * sin(f * 37.0) + 0.15 * sin(f * 9.0))
		# les 8 derniers % s'effilent (la pointe du pinceau quitte le papier)
		var tail := 1.0 - clampf((f - 0.92) / 0.08, 0.0, 1.0)
		_ci.draw_polyline(pts.slice(i, j + 1), col, maxf(1.0, ww * (0.3 + 0.7 * tail)), true)
		_ci.draw_circle(pts[j], maxf(0.5, ww * (0.3 + 0.7 * tail) * 0.5), col)
		i = j


## Griffe d'écume (ou d'encre) : petit trait courbe depuis p0 dans la direction dir, qui s'incurve de `curl`.
func _claw(p0: Vector2, dir: Vector2, ln: float, curl: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var side := dir.orthogonal()
	for j in 6:
		var a := float(j) / 5.0
		out.append(p0 + dir * ln * a + side * ln * curl * a * a)
	return out


## Points en pixels d'une liste de fractions de la feuille, lissés.
func _curve(fr: Array, n := 6) -> PackedVector2Array:
	var pts := []
	for f in fr:
		pts.append(_sp(f.x, f.y))
	return _smooth(pts, n)


## Polyligne intermédiaire entre a et b (même nombre de points).
func _mix(a: PackedVector2Array, b: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in a.size():
		out.append(a[i].lerp(b[mini(i, b.size() - 1)], f))
	return out


func _sub(pts: PackedVector2Array, a0: float, a1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size() - 1
	var x1 := clampf(a1, 0.0, 1.0) * n
	out.append(_pt_at(pts, a0))
	var i := int(floor(clampf(a0, 0.0, 1.0) * n)) + 1
	while float(i) < x1:
		out.append(pts[i])
		i += 1
	out.append(_pt_at(pts, a1))
	return out


func _pt_at(pts: PackedVector2Array, f: float) -> Vector2:
	var n := pts.size() - 1
	if n < 1:
		return pts[0] if n == 0 else Vector2.ZERO
	var x := clampf(f, 0.0, 1.0) * n
	var i := mini(int(x), n - 1)
	return pts[i].lerp(pts[i + 1], x - i)


func _bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


## Courbe lisse (Catmull-Rom) par les points `keys`, `n` pas par segment.
func _smooth(keys: Array, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := keys.size()
	if m < 2:
		for p in keys:
			out.append(p)
		return out
	for i in m - 1:
		var p0: Vector2 = keys[maxi(i - 1, 0)]
		var p1: Vector2 = keys[i]
		var p2: Vector2 = keys[i + 1]
		var p3: Vector2 = keys[mini(i + 2, m - 1)]
		for j in n:
			var t := float(j) / float(n)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(keys[m - 1])
	return out


## Coins arrondis (Chaikin, `iters` passes) : la polyligne reste près de ses points, les angles s'adoucissent
## sans déborder (contrairement à Catmull-Rom sur un contour anguleux).
func _chaikin(keys: Array, iters: int) -> PackedVector2Array:
	var cur := PackedVector2Array()
	for p in keys:
		cur.append(p)
	for _it in iters:
		var nxt := PackedVector2Array()
		nxt.append(cur[0])
		for i in cur.size() - 1:
			var a: Vector2 = cur[i]
			var b: Vector2 = cur[i + 1]
			nxt.append(a.lerp(b, 0.25))
			nxt.append(a.lerp(b, 0.75))
		nxt.append(cur[cur.size() - 1])
		cur = nxt
	return cur


## Couleur multipliée par l'opacité de l'ouverture.
func _c(col: Color, k := 1.0) -> Color:
	return Color(col.r, col.g, col.b, col.a * k * _a)


## Point de l'estampe (la partie peinte de la feuille), en fractions de sa taille.
func _sp(x: float, y: float) -> Vector2:
	return _paint.position + Vector2(x, y) * _paint.size


## Avancement 0..1 d'une étape qui commence à t0 et dure dur.
func _k(t: float, t0: float, dur: float) -> float:
	return clampf((t - t0) / dur, 0.0, 1.0)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx < 0.5 or ry < 0.5 or col.a <= 0.003:
		return
	var p := PackedVector2Array()
	for i in 28:
		var ang := TAU * float(i) / 28.0
		p.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	_ci.draw_colored_polygon(p, col)


func _outline(pts: PackedVector2Array, col: Color, wdt: float) -> void:
	var q := pts.duplicate()
	q.append(pts[0])
	_ci.draw_polyline(q, col, wdt, true)
