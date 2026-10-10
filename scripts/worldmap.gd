extends Control
## Choix du monde (UI v2, planche Mondes) : une carte par monde, en carrousel sur un papier seigaiha. Chaque
## carte porte un grand paysage peint pleine largeur (sceau du monde et « MONDE N » posés dessus), le nom
## souligné de vermillon, la frise des 8 étapes (gardien = couronne à la 4e, boss = oni à la 8e, étapes
## atteintes en or), la tuile du meilleur score (chiffres Zen Kaku, sceau du rang, rang suivant et son seuil)
## et celle des Vues gagnées. On glisse d'une carte à l'autre (aimantée, parallaxe dans le paysage), les
## voisines dépassent sur les bords sous un voile de leur couleur ; PARTIR (pinceau) lance le monde centré.
## Un monde scellé est un lavis délavé avec un cadenas et sa condition d'ouverture en pictos (monde
## précédent -> oni à vaincre). Aucun texte d'aide, aucun kanji, aucun flou.
## Après une victoire qui ouvre un monde (open(..., reveal)), le carrousel part du monde vaincu, glisse
## jusqu'au nouveau, brise son cadenas (encre et or, les couleurs reviennent), puis sa carte se lève ;
## PARTIR vient ensuite.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const Score = preload("res://scripts/score.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
const RANK_ICON := ["hud/prunier", "hud/bambou", "hud/pin", "hud/couronne"]  # pictos des rangs (score.gd)
const Meta = preload("res://scripts/meta.gd")

# teintes du paysage par monde (indice = id - 1) : ciel, plan lointain, premier plan
const SKY := [Color("#D3DEE6"), Color("#DCE2C8"), Color("#C3CCD6"), Color("#AFC2D0"), Color("#DCCBC4"),
	Color("#CFD8C8"), Color("#A9D6CF"), Color("#9A90A4")]
const FAR := [Color("#7F9BB3"), Color("#93A86C"), Color("#A9BED0"), Color("#9C3B2A"), Color("#6E6A80"),
	Color("#4E6656"), Color("#2E7A7A"), Color("#4A4452")]
const NEAR := [Color("#1F3A5F"), Color("#5E7F4A"), Color("#E3EAEF"), Color("#5A5550"), Color("#0E1A2E"),
	Color("#2F4A34"), Color("#1E5A5E"), Color("#2A2430")]
const TANZAKU := [Color("#E9C46A"), Color("#9EC1CF"), Color("#E7B3C3"), Color("#F1EDE4"), Color("#B5C99A")]
# la Grande Vague (contour, ligne d'écume intérieure, griffes), en unités locales
const WAVE := [Vector2(-70, 0), Vector2(-55, -28), Vector2(-38, -58), Vector2(-18, -80), Vector2(4, -90),
	Vector2(24, -86), Vector2(38, -74), Vector2(42, -60), Vector2(34, -50), Vector2(24, -56),
	Vector2(16, -62), Vector2(6, -58), Vector2(0, -44), Vector2(2, -24), Vector2(10, 0)]
const WAVE_FOAM := [Vector2(-56, -14), Vector2(-42, -40), Vector2(-24, -62), Vector2(-2, -76), Vector2(18, -76), Vector2(30, -66)]
const MINI_ROOM := 4  # étape du gardien (main.STAGE_PLAN : 8 étapes, la 4e est son arène)
# révélation d'un monde (secondes, comptées depuis l'ouverture) : glissé, bris du sceau, carte
const RV_START := 1.05  # attente avant le glissé
const RV_BREAK := 0.95  # le cadenas se brise
const RV_CARD := 1.55  # la carte du monde se lève
const RV_HOLD := 3.4  # durée de la carte (un toucher l'abrège)
const WAVE_CLAWS := [Vector2(6, -93), Vector2(16, -93), Vector2(27, -89), Vector2(36, -81), Vector2(43, -70), Vector2(45, -59), Vector2(40, -52)]
# mise en page des cartes (unités de 400 de large)
const CARD_GAP := 10.0  # écart entre deux cartes
const CARD_R := 18.0  # rayon des coins de la carte
const TEXT_H := 260.0  # bloc sous l'estampe : nom, frise, tuiles (planche : carte 590, estampe 330)
# vignette « Vues » (planche Mondes : cadre et montagne), gabarit 32
const VUE_PATH := "M5 7 H27 V25 H5 Z M8 22 L14 14 L18 19 L21 16 L25 22"
const PRINT_KINDS := ["room", "mini", "win", "curse"]  # Vues d'un monde (meta.PRINTS « w<id>_<kind> »)
# estampe d'un monde scellé : couleurs ramenées au gris (sat) puis délavées vers le papier (wash)
const DESAT_CODE := """shader_type canvas_item;
uniform float sat = 1.0;
uniform float wash = 0.0;
uniform vec4 paper : source_color = vec4(0.96, 0.93, 0.87, 1.0);
void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(l), c.rgb, sat);
	COLOR = vec4(mix(g, paper.rgb, wash), c.a);
}
"""

signal world_chosen(id: int)
signal closed
signal seal_broken(id: int)  # le sceau du monde révélé vient de se briser (son et vibration)

var _worlds: Array = []
var _unlocked := 1
var _best: Dictionary = {}
var _rooms := 8  # étapes d'une partie (record affiché sur « _rooms » points)
var _wins: Dictionary = {}  # Vues gagnées ("w4_win", "w4_mini"...) ou id -> true
var _stamp_at: Dictionary = {}  # id -> instant (_t) où le sceau ACCOMPLI frappe
var scores: Dictionary = {}  # id -> meilleur score du monde (meta.world_score), posé par main avant open()
static var _stamps_seen := {}  # sceaux déjà frappés pendant la session (pas de nouvelle animation)
static var _cue_seen := false  # petit coup de pouce « on peut glisser » : une fois par session

var _t := 0.0  # temps réel depuis l'ouverture
var _scroll := 0.0  # position du carrousel, en indice de monde (0 = premier)
var _target := 0.0  # position visée (aimantée sur un monde)
var _vel := 0.0  # vitesse du glissé, en mondes / s
var _pressing := false
var _moved := false
var _press_pos := Vector2.ZERO
var _press_scroll := 0.0
var _drag_accum := 0.0
var _deny := 0.0  # secousse quand on veut partir vers un monde verrouillé (1 -> 0)
var _leaving := 0  # 0 = ouvert, 1 = retour, 2 = départ vers un monde
var _leave_t := 0.0
var _chosen_id := 0
var _cue := false  # coup de pouce en cours (la carte glisse un peu vers sa voisine et revient)
var _cue_dir := 1.0
# révélation d'un monde ouvert par la victoire
var _reveal_id := 0  # id du monde révélé (0 : aucun)
var _reveal_i := -1
var _reveal_powers: Array = []  # rouleaux débloqués avec lui (aperçu sur sa carte)
var _rv := 0.0  # temps de la révélation (négatif : pas encore commencée)
var _rv_glide := false
var _rv_broken := false
var _rv_out := 0.0  # instant où la carte s'efface

# mise en page (recalculée à chaque image)
var _u := 1.0
var _safe := Vector2.ZERO  # marges de sécurité (haut, bas)
var _cx := 0.0
var _top := 0.0  # haut de la barre de titre
var _pitch := 300.0  # écart entre les centres de deux cartes
var _cw := 280.0  # largeur d'une carte
var _ch := 520.0  # hauteur d'une carte
var _pph := 280.0  # hauteur de l'estampe
var _ccy := 0.0  # centre vertical des cartes
var _dots_y := 0.0
var _appear := 0.0  # arrivée des cartes (0 -> 1)
var _lift := 0.0  # décalage vertical au départ
var _ready_k := 0.0
var _card_rects: Array = []  # rectangle à l'écran de chaque carte affichée (Rect2() sinon)
var _dot_pos: Array = []
var _wrap_cache: Dictionary = {}  # "i:largeur" -> [taille, lignes] du sous-titre

# estampe en cours de dessin (coordonnées locales de son Control)
var _pi := 0
var _pw := 0.0
var _ph := 0.0
var _ps := 1.0  # largeur d'un monde dans le paysage
var _off_far := 0.0  # parallaxe du plan lointain
var _off_near := 0.0  # parallaxe du premier plan

var _fibers: Array = []
var _title := FontVariation.new()
var _name := FontVariation.new()
var _ui := FontVariation.new()
var _caps := FontVariation.new()
var _btn := FontVariation.new()
var _box := StyleBoxFlat.new()
var _shader := Shader.new()
var _cards: Control  # estampes (un Control découpé par monde)
var _paints: Array = []
var _mats: Array = []
var _front: Control  # cadres, sceaux et textes des cartes, par-dessus les estampes
var _overlay: Control  # carte du monde révélé, par-dessus tout
var _go: InkButton
var _back: InkButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = UiKit.TITLE_SPACING
	_name.base_font = UiKit.TITLE_FONT
	_name.spacing_glyph = 3  # nom du monde (planche : Shippori 26, interlettrage 3)
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 1
	_caps.base_font = UiKit.UI_FONT
	_caps.spacing_glyph = 3
	_btn.base_font = UiKit.TITLE_FONT  # PARTIR (planche : Shippori 24, interlettrage 8)
	_btn.spacing_glyph = 8
	_box.anti_aliasing = true
	_shader.code = DESAT_CODE

	_cards = Control.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)

	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_front)
	_front.draw.connect(_draw_front)

	_go = InkButton.new()
	_go.text = "PARTIR"
	_go.style = "brush"
	_go.font = _btn
	add_child(_go)
	_go.pressed.connect(_on_go)

	_back = InkButton.new()
	_back.style = "round"
	_back.icon = "home"
	add_child(_back)
	_back.pressed.connect(_on_back)

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)

	_make_fibers()


## worlds : Array de Dictionary {id, name, kanji, subtitle, color} ; unlocked : nombre de mondes ouverts ;
## best : id -> meilleure salle atteinte ; current : id du monde centré à l'ouverture ;
## rooms : nombre de salles d'une partie ; wins : Vues possédées (meta.owned_prints : "w<id>_win",
## "w<id>_mini") ou id -> true. Vide : un monde compte comme fini dès que son record atteint « rooms ».
## reveal : id du monde que la victoire vient d'ouvrir (0 : aucun), reveal_powers : ses nouveaux rouleaux.
func open(worlds: Array, unlocked: int, best: Dictionary, current: int, rooms := 8, wins := {}, reveal := 0, reveal_powers := []) -> void:
	_worlds = worlds
	_unlocked = clampi(unlocked, 1, maxi(1, worlds.size()))
	_best = best
	_rooms = maxi(1, rooms)
	_wins = wins
	_stamp_at.clear()
	_wrap_cache.clear()
	var start := 0
	for i in _worlds.size():
		if _id(i) == current:
			start = i
	_scroll = float(start)
	_target = _scroll
	_vel = 0.0
	_t = 0.0
	_pressing = false
	_moved = false
	_drag_accum = 0.0
	_deny = 0.0
	_leaving = 0
	_leave_t = 0.0
	modulate.a = 1.0
	_reveal_id = 0
	_reveal_i = -1
	for i in _worlds.size():
		if reveal > 0 and _id(i) == reveal and i != start:
			_reveal_id = reveal
			_reveal_i = i
	_reveal_powers = reveal_powers.duplicate()
	_rv = -RV_START
	_rv_glide = false
	_rv_broken = false
	_rv_out = RV_CARD + RV_HOLD
	# coup de pouce (une fois par session) : la carte glisse un peu vers sa voisine
	_cue = not _cue_seen and _reveal_id == 0 and _worlds.size() > 1
	_cue_dir = -1.0 if start >= _worlds.size() - 1 else 1.0
	_build_paints()
	_go.visible = _reveal_done()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true


## Un Control découpé par monde pour son estampe (dessin propre, parallaxe, lavis du monde scellé).
func _build_paints() -> void:
	if _paints.size() == _worlds.size():
		return
	for c in _cards.get_children():
		var old := c as Control
		if old != null:
			old.visible = false
		c.queue_free()
	_paints.clear()
	_mats.clear()
	for i in _worlds.size():
		var pc := Control.new()
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.clip_contents = true
		pc.visible = false
		_cards.add_child(pc)
		pc.draw.connect(_draw_painting.bind(pc, i))
		_paints.append(pc)
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("paper", Toon.PAPER)
		_mats.append(m)
	_card_rects.resize(_worlds.size())
	_dot_pos.resize(_worlds.size())
	for i in _worlds.size():
		_card_rects[i] = Rect2()
		_dot_pos[i] = Vector2(-1000.0, -1000.0)


# --- Données ---------------------------------------------------------------------

func _id(i: int) -> int:
	var d: Dictionary = _worlds[i]
	return int(d.get("id", i + 1))


func _locked(i: int) -> bool:
	if _id(i) == _reveal_id and _rv < RV_BREAK:
		return true  # monde révélé : scellé jusqu'au bris de son cadenas
	return _id(i) > _unlocked


## Révélation finie (ou aucune) : la carte s'est effacée, PARTIR est permis.
func _reveal_done() -> bool:
	return _reveal_id == 0 or _rv >= _rv_out + 0.35


## Un toucher pendant la révélation la fait avancer : bris du sceau, carte affichée, puis carte effacée.
func _reveal_skip() -> void:
	if _rv < RV_BREAK - 0.1:
		_rv = RV_BREAK - 0.1
		_target = float(_reveal_i)
		_scroll = _target
	elif _rv < RV_CARD + 0.35:
		_rv = RV_CARD + 0.35
	elif _rv < _rv_out:
		_rv_out = _rv


## Indice de palette du paysage (0..SKY.size() - 1) pour le monde i.
func _pal(i: int) -> int:
	return clampi(_id(i) - 1, 0, SKY.size() - 1)


func _best_of(i: int) -> int:
	var id := _id(i)
	var v: Variant = _best.get(id, _best.get(str(id), 0))
	return clampi(int(v), 0, _rooms)


func _flag(id: int, kind: String) -> bool:
	if bool(_wins.get("w%d_%s" % [id, kind], false)):
		return true
	if kind == "win":
		return bool(_wins.get(id, false)) or bool(_wins.get(str(id), false))
	return false


## Monde accompli : boss vaincu (Vue « w<id>_win »), à défaut record sur toutes les salles.
func _won(i: int) -> bool:
	if _locked(i):
		return false
	if _flag(_id(i), "win"):
		return true
	if _id(i) > 5 and _id(i) < _unlocked:
		return true  # mondes 6 et plus (sans Vue « w<id>_win ») : le suivant ne s'ouvre qu'en le gagnant
	return _wins.is_empty() and _best_of(i) >= _rooms


func _score_of(i: int) -> int:
	var id := _id(i)
	var v: Variant = scores.get(id, scores.get(str(id), 0))
	return maxi(0, int(v))


func _mini_done(i: int) -> bool:
	return _won(i) or _flag(_id(i), "mini") or _best_of(i) > MINI_ROOM


func _sel() -> int:
	return clampi(int(roundf(_scroll)), 0, maxi(0, _worlds.size() - 1))


## Vues du monde (ids de meta.PRINTS), dans l'ordre étape, gardien, boss, malédiction.
func _print_ids(id: int) -> Array:
	var out: Array = []
	for k in PRINT_KINDS:
		var pid := "w%d_%s" % [id, String(k)]
		if Meta.PRINTS.has(pid):
			out.append(pid)
	return out


## Position affichée du carrousel : celle du doigt, plus le petit glissé du coup de pouce.
func _view() -> float:
	if not _cue:
		return _scroll
	var k := clampf((_t - 1.0) / 0.9, 0.0, 1.0)
	return _scroll + _cue_dir * 0.1 * sin(PI * k)


# --- Entrée ----------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _leaving != 0 or _t < 0.35 or _worlds.is_empty():
		return
	if not _reveal_done():
		# révélation en cours : pas de glissé, un toucher la fait avancer
		if event is InputEventMouseButton:
			var rb := event as InputEventMouseButton
			if rb.button_index == MOUSE_BUTTON_LEFT and not rb.pressed:
				_reveal_skip()
		_pressing = false
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			if mb.pressed:
				_nudge(-1)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			if mb.pressed:
				_nudge(1)
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_stop_cue()
			_pressing = true
			_moved = false
			_press_pos = mb.position
			_press_scroll = _scroll
			_drag_accum = 0.0
			_vel = 0.0
		elif _pressing:
			_pressing = false
			if _moved:
				_release_flick()
			else:
				_tap(mb.position)
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		if not _moved and absf(mm.position.x - _press_pos.x) > 8.0 * _u:
			_moved = true
			_press_pos = mm.position
			_press_scroll = _scroll
		if _moved:
			var dx := mm.position.x - _press_pos.x
			_scroll = _rubber(_press_scroll - dx / maxf(_pitch, 1.0))
			_drag_accum += mm.relative.x
		accept_event()


## Clavier et manette : flèches pour changer de monde, Échap pour revenir.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _leaving != 0 or _t < 0.35 or _worlds.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		if _reveal_done():
			_on_back()
		else:
			_reveal_skip()
	elif not _reveal_done():
		return
	elif event.is_action_pressed("ui_left"):
		_stop_cue()
		_nudge(-1)
	elif event.is_action_pressed("ui_right"):
		_stop_cue()
		_nudge(1)
	else:
		return
	get_viewport().set_input_as_handled()


## Téléphone : le geste ou le bouton Retour ramène à l'accueil (ou fait avancer la révélation).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and _leaving == 0 and _t >= 0.35:
		if _reveal_done():
			_on_back()
		else:
			_reveal_skip()


## Au-delà des extrémités, la carte résiste (élastique).
func _rubber(raw: float) -> float:
	var hi := float(_worlds.size() - 1)
	if raw < 0.0:
		return raw * 0.3
	if raw > hi:
		return hi + (raw - hi) * 0.3
	return raw


## Fin du glissé : une carte à la fois. Un geste vif passe à la voisine dans son sens, sinon la plus proche.
func _release_flick() -> void:
	var tgt := roundf(_scroll)
	if _vel > 0.5:
		tgt = floorf(_scroll) + 1.0
	elif _vel < -0.5:
		tgt = ceilf(_scroll) - 1.0
	_target = clampf(tgt, 0.0, float(_worlds.size() - 1))
	_cue_seen = true


func _nudge(d: int) -> void:
	_target = clampf(roundf(_target) + float(d), 0.0, float(_worlds.size() - 1))


## Le doigt se pose : le coup de pouce s'arrête là où il en est (sans saut).
func _stop_cue() -> void:
	if _cue:
		_scroll = _view()
		_target = roundf(_target)
		_cue = false
	_cue_seen = true


func _tap(p: Vector2) -> void:
	for i in _dot_pos.size():
		var dp: Vector2 = _dot_pos[i]
		if p.distance_to(dp) < 13.0 * _u:
			_target = float(i)
			return
	for i in _card_rects.size():
		var r: Rect2 = _card_rects[i]
		if r.has_area() and r.has_point(p):
			if i != _sel():
				_target = float(i)
			elif _locked(i):
				_deny = 1.0
			return


func _on_go() -> void:
	if _leaving != 0 or _worlds.is_empty() or _t < 0.35 or not _reveal_done():
		return
	var i := _sel()
	if _locked(i):
		_deny = 1.0
		_target = float(i)
		return
	_chosen_id = _id(i)
	_target = float(i)
	_leaving = 2
	_leave_t = 0.0


func _on_back() -> void:
	if _leaving != 0:
		return
	_leaving = 1
	_leave_t = 0.0


# --- Boucle ----------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	_deny = maxf(0.0, _deny - real * 2.5)
	if _cue and _t > 1.95:
		_cue = false
		_cue_seen = true
	if _reveal_id > 0 and _leaving == 0:
		_rv += real
		if _rv >= 0.0 and not _rv_glide:
			# le carrousel glisse du monde vaincu jusqu'au monde ouvert
			_rv_glide = true
			_target = float(_reveal_i)
		if _rv >= RV_BREAK and not _rv_broken:
			_rv_broken = true
			seal_broken.emit(_reveal_id)

	if _pressing and _moved:
		if real > 0.0:
			var inst := -_drag_accum / maxf(_pitch, 1.0) / real
			_vel = lerpf(_vel, inst, 0.35)
		_drag_accum = 0.0
	else:
		_scroll = lerpf(_scroll, _target, 1.0 - exp(-9.0 * real))

	if _leaving != 0:
		_leave_t += real
		if _leave_t >= 0.45:
			var mode := _leaving
			_leaving = 0
			visible = false
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			if mode == 2:
				world_chosen.emit(_chosen_id)
			else:
				closed.emit()
			return

	_layout()
	queue_redraw()
	_front.queue_redraw()
	_overlay.queue_redraw()


func _layout() -> void:
	var w := size.x
	var h := size.y
	_safe = UiKit.safe_insets(size)
	_u = minf(w / 400.0, h / 760.0)
	var u := _u
	_cx = w / 2.0
	_top = _safe.x + 16.0 * u
	var gap := CARD_GAP * u
	_cw = minf(w * 0.75, 300.0 * u)  # planche : carte de 300 sur 400, les voisines dépassent de 30
	_pitch = _cw + gap
	# bas de l'écran : points de page puis PARTIR (280 × 72)
	var bh := 72.0 * u
	var by := h - _safe.y - 20.0 * u - bh
	_dots_y = by - 26.0 * u
	var a_top := _top + 66.0 * u
	var a_bot := _dots_y - 21.0 * u
	var avail := a_bot - a_top
	_pph = clampf(avail - TEXT_H * u, 200.0 * u, 330.0 * u)  # estampe pleine largeur, écrasée sur un écran court
	_ch = _pph + TEXT_H * u
	_ccy = a_top + maxf(0.0, avail - _ch) * 0.5 + _ch * 0.5

	_appear = UiKit.ease_out(clampf((_t - 0.08) / 0.5, 0.0, 1.0))
	_ready_k = clampf((_t - 0.55) / 0.2, 0.0, 1.0)
	var closing := 1.0
	if _leaving != 0:
		closing = 1.0 - UiKit.ease_out(clampf(_leave_t / 0.4, 0.0, 1.0))
	_lift = (1.0 - closing) * 22.0 * u * (-1.0 if _leaving == 2 else 1.0)
	modulate.a = minf(UiKit.ease_out(clampf(_t / 0.22, 0.0, 1.0)), clampf(closing * 1.8, 0.0, 1.0))

	# estampes : seules les cartes à l'écran se dessinent
	var n := _worlds.size()
	var pr := _paint_rect()
	var cr := _card_rect()
	for i in n:
		var pc: Control = _paints[i]
		var on := _on_screen(i)
		pc.visible = on
		if not on:
			_card_rects[i] = Rect2()
			continue
		var xf := _card_xf(i)
		var s := xf.get_scale().x
		pc.position = xf * pr.position
		pc.scale = Vector2(s, s)
		pc.size = pr.size
		_card_rects[i] = Rect2(xf * cr.position, cr.size * s)
		var sw := _paint_wash(i)
		if sw.x >= 1.0 and sw.y <= 0.0:
			pc.material = null
		else:
			var mat: ShaderMaterial = _mats[i]
			mat.set_shader_parameter("sat", sw.x)
			mat.set_shader_parameter("wash", sw.y)
			pc.material = mat
		pc.queue_redraw()

	var bw := minf(w * 0.72, 280.0 * u)
	_go.size = Vector2(bw, bh)
	_go.position = Vector2((w - bw) / 2.0, by + 14.0 * u * (1.0 - _appear))
	_go.font_size = maxi(1, int(24.0 * u))
	var go_k := UiKit.ease_out(clampf((_t - 0.35) / 0.6, 0.0, 1.0))
	_go.reveal = go_k
	var locked_sel := n > 0 and _locked(_sel())
	_go.kanji = ""  # plus de sceau à kanji sur le pinceau
	var ga := 1.0
	if _reveal_id > 0:
		ga = UiKit.ease_out(clampf((_rv - _rv_out - 0.2) / 0.35, 0.0, 1.0))
	_go.visible = _reveal_done()
	_go.modulate.a = ga * (0.4 if locked_sel else 1.0)
	_back.size = Vector2(46.0, 46.0) * u
	_back.position = Vector2(14.0 * u, _top)
	_back.modulate.a = _appear


## Carte i : centre et échelle (les voisines reculent un peu), secousse si on veut partir vers un monde scellé.
func _card_xf(i: int) -> Transform2D:
	var dd := float(i) - _view()
	var s := 1.0 - 0.06 * minf(absf(dd), 1.0)
	var x := _cx + dd * _pitch
	if i == _sel() and _deny > 0.0:
		x += sin(_deny * 30.0) * 6.0 * _u * _deny
	var y := _ccy + 28.0 * _u * (1.0 - _appear) + _lift
	return Transform2D(0.0, Vector2(s, s), 0.0, Vector2(x, y))


func _on_screen(i: int) -> bool:
	return absf((float(i) - _view()) * _pitch) < size.x * 0.5 + _cw * 0.55


## Carte en coordonnées locales (centrée sur l'origine).
func _card_rect() -> Rect2:
	return Rect2(-_cw / 2.0, -_ch / 2.0, _cw, _ch)


## Estampe en coordonnées locales de la carte.
func _paint_rect() -> Rect2:
	return Rect2(-_cw / 2.0, -_ch / 2.0, _cw, _pph)


## Couleur de l'estampe : (saturation, lavis vers le papier). Scellée : gris délavé ; révélée : la couleur revient.
func _paint_wash(i: int) -> Vector2:
	if _reveal_id > 0 and _id(i) == _reveal_id:
		if _rv < RV_BREAK:
			return Vector2(0.0, 0.42)
		var k := _smooth((_rv - RV_BREAK) / 0.7)
		return Vector2(k, 0.42 * (1.0 - k))
	if _locked(i):
		return Vector2(0.0, 0.42)
	return Vector2(1.0, 0.0)


func _smooth(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _hash(k: int) -> float:
	var v := sin(float(k) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


func _make_fibers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for k in 36:
		var fx := rng.randf()
		var fy := rng.randf()
		var ang := rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
		var ln := rng.randf_range(6.0, 22.0)
		var al := rng.randf_range(0.03, 0.08)
		var light := rng.randf() < 0.35
		_fibers.append([fx, fy, ang, ln, al, light])


func _gold_ink() -> Color:
	if Toon.ui_dark:
		return Toon.GOLD.lightened(0.1)
	return Toon.GOLD.darkened(0.3)


# --- Dessin : fond, titre, cartes, points de page ------------------------------------

func _draw() -> void:
	if size.x < 10.0:
		return
	var w := size.x
	var u := _u
	var ink: Color = Toon.ui_ink
	# papier du thème à motif seigaiha (planche Mondes : écailles indigo à 13 %) ; aucun halo
	draw_rect(Rect2(Vector2.ZERO, size), Toon.ui_wash)
	var pat := Color(ink, 0.08) if Toon.ui_dark else Color(Toon.PRUSSIAN, 0.13)
	UiKit.seigaiha(self, Rect2(Vector2.ZERO, size), pat, 16.0 * u)

	# titre souligné de vermillon, à la hauteur du bouton maison (même gabarit que les autres écrans)
	var ta := UiKit.ease_out(clampf((_t - 0.05) / 0.4, 0.0, 1.0))
	var ty := _top + 32.0 * u - 6.0 * u * (1.0 - ta)
	UiKit.screen_title(self, _title, "MONDES", Vector2(w / 2.0, ty), u, ink, ta, "", w - 2.0 * 96.0 * u, ta)

	var n := _worlds.size()
	if n == 0:
		return
	# papier des cartes (sous les estampes) : coins arrondis, ombre portée en deux décalages (pas de flou)
	var cr := _card_rect()
	var rad := CARD_R * u
	for i in n:
		if not _on_screen(i):
			continue
		draw_set_transform_matrix(_card_xf(i))
		var pts := UiKit.rrect_points(cr, rad)
		draw_colored_polygon(Transform2D(0.0, Vector2(0, 7.0 * u)) * pts, Color(0, 0, 0, 0.08))
		draw_colored_polygon(Transform2D(0.0, Vector2(0, 3.5 * u)) * pts, Color(0, 0, 0, 0.12))
		draw_colored_polygon(pts, Toon.ui_paper)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_dots()


## Points de page : la page courante s'allonge en trait vermillon ; or pour un monde accompli, encre pour un
## monde ouvert, filet éteint pour un monde scellé.
func _draw_dots() -> void:
	var n := _worlds.size()
	if n <= 1:
		for i in _dot_pos.size():
			_dot_pos[i] = Vector2(-1000.0, -1000.0)
		return
	var u := _u
	var ink: Color = Toon.ui_ink
	var gap := 15.0 * u
	var v := clampf(_view(), 0.0, float(n - 1))
	var hd := 7.0 * u
	var muted := Color(ink, 0.3)  # scellé : point éteint, mais lisible sur le motif du papier
	for i in n:
		var f := clampf(1.0 - absf(float(i) - v), 0.0, 1.0)
		var c := Vector2(_cx + (float(i) - float(n - 1) / 2.0) * gap, _dots_y)
		_dot_pos[i] = c
		var wd := hd + 15.0 * u * f
		var r := Rect2(c - Vector2(wd, hd) / 2.0, Vector2(wd, hd))
		var base := muted
		if _won(i):
			base = UIColors.GOLD_DARK
		elif not _locked(i):
			base = Color(ink, 0.6)
		UiKit.box(_box, base.lerp(Toon.VERMILION, f), maxi(1, int(hd / 2.0)))
		draw_style_box(_box, r)


## Cadres, sceaux et textes des cartes à l'écran.
func _draw_front() -> void:
	if size.x < 10.0 or _worlds.is_empty():
		return
	for i in _worlds.size():
		if _on_screen(i):
			_draw_card(i)
	_front.draw_set_transform_matrix(Transform2D.IDENTITY)


## Une carte (planche Mondes) : estampe pleine largeur (sceau du monde et « MONDE N » posés dessus, cadenas
## ou tampon du boss vaincu), nom souligné de vermillon, frise des 8 étapes, puis les tuiles score / rang et
## Vues, ou la condition d'ouverture en pictos pour un monde scellé. Les voisines reculent sous un voile
## de leur couleur (gris et cadenas si scellées). Cadre d'encre par-dessus.
func _draw_card(i: int) -> void:
	var ci: Control = _front
	var u := _u
	var xf := _card_xf(i)
	ci.draw_set_transform_matrix(xf)
	var d: Dictionary = _worlds[i]
	var cr := _card_rect()
	var pr := _paint_rect()
	var ink: Color = Toon.ui_ink
	var dd := float(i) - _view()
	var focus := _smooth(1.0 - absf(dd))
	var locked := _locked(i)
	var won := _won(i)
	var b := _rooms if won else _best_of(i)
	var col: Color = d.get("color", Color(0.5, 0.5, 0.5))
	var key := str(d.get("kanji", ""))  # clé du monde (jamais affichée) : son picto
	var wname := UiKit.plain(str(d.get("name", "")))
	var grey := Color("#8C8273")
	var rad := CARD_R * u

	# coins hauts de l'estampe (découpée en rectangle) rendus au fond de l'écran
	_fillets(ci, pr, rad, Toon.ui_wash, true)

	# sceau du monde et « MONDE N », en haut à gauche de l'estampe (le monde révélé reprend sa couleur)
	var rv_e := -1.0  # secondes depuis le bris du cadenas (monde révélé)
	if _reveal_id > 0 and _id(i) == _reveal_id and _rv >= RV_BREAK:
		rv_e = _rv - RV_BREAK
	var hcol := grey if locked else col
	if rv_e >= 0.0:
		hcol = grey.lerp(col, _smooth(rv_e / 0.35))
	var hs := 34.0 * u
	_world_badge(ci, Rect2(pr.position + Vector2(16.0, 16.0) * u, Vector2(hs, hs)), key, hcol, 1.0)
	var cfs := maxi(1, int(11.0 * u))
	_left(ci, _caps, "MONDE %d" % _id(i), pr.position.x + 58.0 * u, pr.position.y + 33.0 * u + float(cfs) * 0.36, cfs,
		Color(Toon.SUMI, 0.55 if locked else 0.85))

	# cadenas au centre de l'estampe (le monde révélé : il tremble, puis cède)
	var lc := pr.get_center() + Vector2(0, -4.0 * u)
	if locked:
		var amp := 0.0
		if _reveal_id > 0 and _id(i) == _reveal_id:
			amp = clampf((_rv - (RV_BREAK - 0.45)) / 0.45, 0.0, 1.0)
		var sh := Vector2(sin(_t * 46.0), cos(_t * 39.0) * 0.4) * 3.0 * u * amp
		var br := 30.0 * u * (1.0 + 0.1 * amp)
		ci.draw_circle(lc + sh + Vector2(0, 3.0 * u), br, Color(Toon.SUMI, 0.18))
		ci.draw_circle(lc + sh, br, Color(Toon.PAPER, 0.94))
		ci.draw_arc(lc + sh, br - 1.0 * u, 0.0, TAU, 40, Color(Toon.SUMI, 0.8), 2.0 * u, true)
		_lock_icon(ci, lc + sh + Vector2(0, 2.0 * u), br * 0.72)
	if rv_e >= 0.0 and rv_e < 1.4:
		_break_fx(ci, lc, 30.0 * u, rv_e)

	# tampon du boss vaincu, pressé en biais en bas à droite de l'estampe
	if won:
		var e := _stamp_elapsed(_id(i), focus)
		if e >= 0.0:
			_stamp(ci, xf, pr.end - Vector2(34.0, 34.0) * u, 20.0 * u, e)

	# --- bloc de texte : nom souligné, frise, tuiles
	var ty := pr.end.y
	var x0 := cr.position.x + 20.0 * u
	var x1 := cr.end.x - 20.0 * u
	var nfs := _fit_size(_name, wname, maxi(1, int(26.0 * u)), x1 - x0)
	_centered(ci, _name, wname, Vector2(0.0, ty + 32.0 * u), nfs, Color(ink, 0.55 if locked else 1.0))
	var sw := Rect2(Vector2(-60.0 * u, ty + 41.0 * u), Vector2(120.0 * u, 7.0 * u))
	ci.draw_colored_polygon(UiKit.swash_points(sw, 1.0, 2.0), Color(ink, 0.2) if locked else Color(Toon.VERMILION, 0.95))
	_track(ci, x0, x1, ty + 82.0 * u, 0 if locked else b, won, _mini_done(i) and not locked)
	var tiles := Rect2(Vector2(x0, ty + 130.0 * u), Vector2(x1 - x0, 64.0 * u))
	if locked:
		_draw_locked_info(ci, i, tiles)
	else:
		_draw_tiles(ci, i, xf, tiles)

	# les voisines reculent sous un voile de la couleur du monde (gris et cadenas pour un monde scellé)
	var dim := minf(absf(dd), 1.0)
	if dim > 0.01:
		var veil: Color = Color("#B9B3A6") if locked else col
		ci.draw_colored_polygon(UiKit.rrect_points(cr, rad), Color(veil, 0.82 * dim))
		if locked and dim > 0.5:
			# cadenas sur le bord visible de la voisine (il n'apparaît qu'une fois la carte bien reculée)
			var lx := cr.position.x + 15.0 * u if dd > 0.0 else cr.end.x - 15.0 * u
			UiKit.draw_icon(ci, "interface/cadenas", Vector2(lx, 0.0), 22.0 * u, (dim - 0.5) * 2.0, Toon.SUMI)
	# cadre d'encre
	var outline := UiKit.rrect_points(cr, rad)
	outline.append(outline[0])
	ci.draw_polyline(outline, Color(Toon.SUMI, 0.85 if locked else 1.0), 2.5 * u, true)


## Nom d'un rang en minuscules accentuées (« PRUNIER » -> « Prunier »).
func _rank_word(r: int) -> String:
	var n := Score.rank_name(r)
	if n == "":
		return ""
	return n.substr(0, 1) + n.substr(1).to_lower()


## Monde ouvert, dans `r` : tuile du meilleur score (sceau du rang posé de biais, points en chiffres Zen Kaku,
## rang suivant et son seuil réels : « Pin à 60 000 »), puis la tuile des Vues (vignette, « 1/3 ») s'il y en a.
func _draw_tiles(ci: CanvasItem, i: int, xf: Transform2D, r: Rect2) -> void:
	var u := _u
	var ink: Color = Toon.ui_ink
	var id := _id(i)
	var ids := _print_ids(id)
	var tile_bg := Color(ink, 0.1) if Toon.ui_dark else UIColors.WASHI_DARK
	var muted := Color(ink, 0.6) if Toon.ui_dark else UIColors.TEXT_MUTED
	var rad := maxi(1, int(12.0 * u))
	var vw := 92.0 * u if not ids.is_empty() else 0.0
	var sr := Rect2(r.position, Vector2(r.size.x - (vw + 10.0 * u if vw > 0.0 else 0.0), r.size.y))
	ci.draw_style_box(UiKit.box(_box, tile_bg, rad), sr)
	# score, rang et palier suivant (seuils de score.gd, relevés selon le monde)
	var pts := _score_of(i)
	var cleared := id < _unlocked  # le monde suivant est ouvert : son boss a été vaincu
	var rank := Score.rank_of(pts, id, cleared)
	var nxt := Score.next_rank_pts(pts, id, cleared)
	var nf := UiKit.num_font()
	var fs1 := maxi(1, int(19.0 * u))
	var fs2 := maxi(1, int(10.0 * u))
	var s1 := Score.fmt(pts)
	var s2 := "Rang maximal"
	if nxt > 0:
		s2 = "%s à %s" % [_rank_word(mini(rank + 1, 4)), Score.fmt(nxt)]
	elif nxt < 0:
		s2 = "%s : vaincs le boss" % _rank_word(4)
	var w1 := nf.get_string_size(s1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x
	var w2 := UiKit.UI_FONT.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var ts := 36.0 * u
	var gw := ts + 10.0 * u + maxf(w1, w2)
	var gx := sr.get_center().x - gw / 2.0
	var tc := Vector2(gx + ts / 2.0, sr.get_center().y)
	# sceau du rang (couleur du rang, picto prunier / bambou / pin / couronne), posé de biais ; vide sans rang
	ci.draw_set_transform_matrix(xf * Transform2D(-0.087, Vector2.ONE, 0.0, tc))
	var tr := Rect2(Vector2(-ts, -ts) / 2.0, Vector2(ts, ts))
	if rank > 0:
		ci.draw_style_box(UiKit.box(_box, Score.rank_color(rank), maxi(1, int(5.0 * u)), Toon.SUMI, maxi(1, int(1.5 * u))), tr)
		UiKit.draw_icon(ci, String(RANK_ICON[clampi(rank - 1, 0, RANK_ICON.size() - 1)]), Vector2.ZERO, ts * 0.58, 1.0, Toon.WASHI)
	else:
		ci.draw_style_box(UiKit.box(_box, Color(0, 0, 0, 0), maxi(1, int(5.0 * u)), Color(ink, 0.3), maxi(1, int(1.5 * u))), tr)
	ci.draw_set_transform_matrix(xf)
	var tx := gx + ts + 10.0 * u
	ci.draw_string(nf, Vector2(tx, tc.y - 2.0 * u), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, Color(ink, 0.95))
	ci.draw_string(UiKit.UI_FONT, Vector2(tx, tc.y + 12.0 * u), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, muted)
	if vw <= 0.0:
		return
	# Vues du monde : vignette or, « gagnées / total »
	var vr := Rect2(Vector2(sr.end.x + 10.0 * u, r.position.y), Vector2(vw, r.size.y))
	ci.draw_style_box(UiKit.box(_box, tile_bg, rad), vr)
	var owned := 0
	for q in ids.size():
		if bool(_wins.get(String(ids[q]), false)):
			owned += 1
	var c1 := str(owned)
	var c2 := "/%d" % ids.size()
	var fa := maxi(1, int(18.0 * u))
	var fb := maxi(1, int(12.0 * u))
	var wa := nf.get_string_size(c1, HORIZONTAL_ALIGNMENT_LEFT, -1, fa).x
	var wb := nf.get_string_size(c2, HORIZONTAL_ALIGNMENT_LEFT, -1, fb).x
	var cy := vr.get_center().y
	var x := vr.get_center().x - (28.0 * u + wa + wb) / 2.0
	UiKit.draw_path(ci, VUE_PATH, 32, Vector2(x + 11.0 * u, cy), 22.0 * u, Toon.SUMI, 2.2, UIColors.GOLD_DARK)
	x += 28.0 * u
	ci.draw_string(nf, Vector2(x, cy + float(fa) * 0.36), c1, HORIZONTAL_ALIGNMENT_LEFT, -1, fa, Color(ink, 0.95))
	ci.draw_string(nf, Vector2(x + wa, cy + float(fa) * 0.36), c2, HORIZONTAL_ALIGNMENT_LEFT, -1, fb, Color(ink, 0.6))


## Monde scellé, dans `r` : la condition en pictos, le monde précédent (sa pastille), une flèche, le sceau de son
## boss (oni vermillon, à vaincre). Aucune phrase. Rougit quand on veut partir vers ce monde.
func _draw_locked_info(ci: CanvasItem, i: int, r: Rect2) -> void:
	var u := _u
	var ink: Color = Toon.ui_ink
	var tile_bg := Color(ink, 0.1) if Toon.ui_dark else UIColors.WASHI_DARK
	ci.draw_style_box(UiKit.box(_box, tile_bg, maxi(1, int(12.0 * u))), r)
	var c := r.get_center()
	var hot := _deny if i == _sel() else 0.0
	var col := Color(ink, 0.85).lerp(Toon.VERMILION, hot)
	var bs := 36.0 * u
	if i <= 0:
		UiKit.draw_icon(ci, "interface/cadenas", c, 26.0 * u, 1.0, col)
		return
	var dp: Dictionary = _worlds[i - 1]
	var pc: Color = dp.get("color", Color(0.5, 0.5, 0.5))
	_world_badge(ci, Rect2(Vector2(c.x - 52.0 * u - bs / 2.0, c.y - bs / 2.0), Vector2(bs, bs)), str(dp.get("kanji", "")), pc, 1.0)
	var wdt := maxf(1.0, 2.0 * u)
	ci.draw_line(Vector2(c.x - 24.0 * u, c.y), Vector2(c.x + 8.0 * u, c.y), col, wdt, true)
	ci.draw_polyline(PackedVector2Array([Vector2(c.x + 2.0 * u, c.y - 6.0 * u), Vector2(c.x + 8.0 * u, c.y), Vector2(c.x + 2.0 * u, c.y + 6.0 * u)]), col, wdt, true)
	UiKit.monster_badge(ci, _box, Rect2(Vector2(c.x + 44.0 * u - bs / 2.0, c.y - bs / 2.0), Vector2(bs, bs)), false, 1.0, u)


## Pastille d'un monde : son picto (UIColors.WORLD_ICON, d'après sa clé) sur un carré arrondi de sa couleur,
## liseré papier (planche Mondes : 34, rayon 5, bord 1,5).
func _world_badge(ci: CanvasItem, r: Rect2, key: String, col: Color, a: float) -> void:
	var u := _u
	UiKit.box(_box, Color(col, a), maxi(1, int(r.size.x * 0.15)), Color(Toon.WASHI, 0.9 * a), maxi(1, int(1.5 * u)))
	ci.draw_style_box(_box, r)
	_box.set_border_width_all(0)
	UiKit.draw_icon(ci, String(UIColors.WORLD_ICON.get(key, "hud/vague")), r.get_center(), r.size.x * 0.6, a, Toon.WASHI)


## Sous-titre coupé en deux lignes au plus (mis en cache par monde et largeur) ; carte du monde révélé.
func _sub_lines(i: int, txt: String, width: float) -> Array:
	var key := "%d:%d" % [i, int(width)]
	if _wrap_cache.has(key):
		var hit: Array = _wrap_cache[key]
		return hit
	var fs := maxi(1, int(12.0 * _u))
	var min_fs := maxi(1, int(9.5 * _u))
	var lines := UiKit.wrap(_ui, txt, fs, width, [])
	while lines.size() > 2 and fs > min_fs:
		fs -= 1
		lines = UiKit.wrap(_ui, txt, fs, width, [])
	if lines.size() > 2:
		# dernier recours : tout le reste sur la seconde ligne, réduite au dessin pour tenir
		var rest := " ".join(lines.slice(1))
		lines = PackedStringArray([lines[0], rest])
	var e := [fs, lines]
	_wrap_cache[key] = e
	return e


## Frise des 8 étapes entre xa et xb (centrée sur y) : nœuds de 18, gardien (4e, couronne) et boss (8e, oni,
## carré) de 30, répartis comme la planche. Étapes atteintes en or sur le trait d'or, les autres en papier
## cerné d'un filet éteint ; anneau d'or autour du record. Gardien vaincu : or ; boss vaincu : vermillon ;
## atteint mais pas vaincu : liseré et picto vermillon.
func _track(ci: CanvasItem, xa: float, xb: float, y: float, b: int, won: bool, mini_done: bool) -> void:
	var u := _u
	var ink: Color = Toon.ui_ink
	var paper: Color = Toon.ui_paper
	var n := _rooms
	var muted := Color(ink, 0.25) if Toon.ui_dark else UIColors.LINE_MUTED
	var grey := Color("#8C8273")
	var sizes := PackedFloat32Array()
	var sum := 0.0
	for k in n:
		var room := k + 1
		var big := room == n or (room == MINI_ROOM and room < n)
		sizes.append(30.0 * u if big else 18.0 * u)
		sum += sizes[k]
	var gap := ((xb - xa) - sum) / float(maxi(1, n - 1))
	var cs := PackedVector2Array()
	var x := xa
	for k in n:
		cs.append(Vector2(x + sizes[k] / 2.0, y))
		x += sizes[k] + gap
	# trait : éteint, puis or jusqu'au record
	ci.draw_line(cs[0], cs[n - 1], muted, 3.0 * u, true)
	if b > 1:
		ci.draw_line(cs[0], cs[mini(b, n) - 1], UIColors.GOLD, 3.0 * u, true)
	for k in n:
		var room := k + 1
		var is_boss := room == n
		var is_mini := room == MINI_ROOM and room < n
		var reached := k < b
		var q: Vector2 = cs[k]
		var s: float = sizes[k]
		if is_boss or is_mini:
			var beaten := won if is_boss else mini_done
			var fill := paper
			var edge := muted
			var icol := grey
			if beaten:
				fill = Toon.VERMILION if is_boss else UIColors.GOLD_DARK
				edge = Toon.SUMI
				icol = Toon.WASHI
			elif reached:
				edge = Toon.VERMILION
				icol = Toon.VERMILION
			if is_boss:
				ci.draw_style_box(UiKit.box(_box, fill, maxi(1, int(5.0 * u)), edge, maxi(1, int(2.0 * u))), Rect2(q - Vector2(s, s) / 2.0, Vector2(s, s)))
			else:
				ci.draw_circle(q, s / 2.0, edge)
				ci.draw_circle(q, s / 2.0 - 2.0 * u, fill)
			UiKit.draw_icon(ci, "hud/oni" if is_boss else "hud/couronne", q, 18.0 * u, 1.0, icol)
		elif reached:
			ci.draw_circle(q, s / 2.0, Toon.SUMI)
			ci.draw_circle(q, s / 2.0 - 2.0 * u, UIColors.GOLD)
		else:
			ci.draw_circle(q, s / 2.0, muted)
			ci.draw_circle(q, s / 2.0 - 2.0 * u, paper)
		# record : anneau d'or autour de la dernière étape atteinte (monde pas encore accompli)
		if not won and b > 0 and k == b - 1:
			ci.draw_arc(q, s / 2.0 + 2.5 * u, 0.0, TAU, 40, UIColors.GOLD, 3.0 * u, true)


## Coins arrondis : quarts de fond posés sur les coins de l'estampe (découpée en rectangle) ; top_only : les
## deux coins du haut seulement (le bas de l'estampe se fond dans le papier de la carte).
func _fillets(ci: CanvasItem, r: Rect2, rad: float, col: Color, top_only := false) -> void:
	var o := 1.0  # déborde d'un pixel pour ne laisser aucun liseré
	var corners := [
		[Vector2(r.position.x - o, r.position.y - o), Vector2(r.position.x + rad, r.position.y + rad), PI],
		[Vector2(r.end.x + o, r.position.y - o), Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[Vector2(r.end.x + o, r.end.y + o), Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x - o, r.end.y + o), Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
	]
	for ci_k in corners.size():
		if top_only and ci_k >= 2:
			break
		var arr: Array = corners[ci_k]
		var p: Vector2 = arr[0]
		var c: Vector2 = arr[1]
		var a0: float = arr[2]
		var poly := PackedVector2Array([p])
		for k in 9:
			var a := a0 + PI * 0.5 * float(k) / 8.0
			poly.append(c + Vector2(cos(a), sin(a)) * rad)
		ci.draw_colored_polygon(poly, col)


func _left(ci: CanvasItem, font: Font, txt: String, x: float, y: float, fs: int, c: Color) -> float:
	ci.draw_string(font, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


# --- Dessin : l'estampe d'un monde (Control découpé, coordonnées locales) ---------------

func _draw_painting(ci: Control, i: int) -> void:
	if i >= _worlds.size() or ci.size.x < 4.0:
		return
	var u := _u
	_pi = i
	_pw = ci.size.x
	_ph = ci.size.y
	_ps = maxf(_pw, 1.0)
	# parallaxe : le lointain traîne derrière la carte, le premier plan la devance
	var dd := float(i) - _view()
	_off_far = -dd * _pw * 0.16
	_off_near = dd * _pw * 0.1
	var p := _pal(i)
	ci.draw_rect(Rect2(Vector2.ZERO, ci.size), Toon.PAPER)
	var sky: Color = SKY[p]
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(_pw, 0), Vector2(_pw, _ph * 0.6), Vector2(0, _ph * 0.6)]),
		PackedColorArray([Color(sky, 0.85), Color(sky, 0.85), Color(sky, 0.0), Color(sky, 0.0)]))
	# fibres du washi
	for fb in _fibers:
		var arr: Array = fb
		var p0 := Vector2(float(arr[0]) * _pw, float(arr[1]) * _ph)
		var dirv := Vector2.from_angle(float(arr[2])) * float(arr[3]) * u
		var light: bool = arr[5]
		var fc := Color(1, 1, 1, float(arr[4]) * 5.0) if light else Color(Toon.SUMI, float(arr[4]))
		ci.draw_line(p0, p0 + dirv, fc, maxf(1.0, u), true)

	var xs := PackedFloat32Array()
	var stp := 7.0 * u
	var x := -stp
	while x < _pw + stp:
		xs.append(x)
		x += stp
	xs.append(x)
	_strip(ci, xs, true)
	_motif_back(ci, i, _pw * 0.5 + _off_far)
	_strip(ci, xs, false)
	_motif_front(ci, i, _pw * 0.5 + _off_near)


## Abscisse du paysage (en indice de monde) sous x, pour un plan décalé de `off`.
func _f_at(x: float, off: float) -> float:
	return float(_pi) + (x - _pw * 0.5 - off) / _ps


func _ground_y(x: float) -> float:
	return _prof(false, _pi, _f_at(x, _off_near)) * _ph


func _far_y(x: float) -> float:
	return _prof(true, _pi, _f_at(x, _off_far)) * _ph


## Profil d'un plan (fraction de la hauteur de l'estampe) propre au monde i, à la position f.
func _prof(far: bool, i: int, f: float) -> float:
	var d := f - float(i)
	match _pal(i):
		0:  # baie : horizon plat, houle au premier plan
			if far:
				return 0.47 + 0.008 * sin(f * 26.0)
			return 0.70 + 0.022 * sin(f * 31.0 + _t * 1.6)
		1:  # bambouseraie : collines douces
			if far:
				return 0.42 + 0.045 * sin(f * 8.0 + 1.0)
			return 0.73 + 0.025 * sin(f * 6.0 + 0.5)
		2:  # montagne enneigée : crêtes en dents de scie, congères
			if far:
				var tri := 1.0 - absf(fposmod(f * 3.2 + 0.5, 2.0) - 1.0)
				return 0.41 - 0.12 * tri
			return 0.71 - 0.035 * absf(sin(f * 5.0))
		3:  # Fuji rouge : un grand cône au sommet plat
			if far:
				return maxf(0.47 - 0.31 * maxf(0.0, 1.0 - absf(d) * 1.5), 0.19)
			return 0.75 + 0.02 * sin(f * 12.0)
		4:  # mer d'encre : houle lourde
			if far:
				return 0.45 + 0.02 * sin(f * 9.0)
			return 0.68 + 0.03 * sin(f * 20.0 - _t * 1.8)
		5:  # Kurama : crêtes boisées, sous-bois en pente douce
			if far:
				return 0.4 + 0.06 * sin(f * 7.0 + 0.4) - 0.03 * absf(sin(f * 23.0))
			return 0.72 + 0.02 * sin(f * 9.0)
		6:  # Ryugu-jo : récifs bas, fond de sable qui ondule
			if far:
				return 0.47 + 0.03 * sin(f * 11.0)
			return 0.74 + 0.02 * sin(f * 14.0 + _t * 0.8)
		7:  # Yomi : pentes de cendre déchiquetées
			if far:
				return 0.43 + 0.05 * absf(sin(f * 6.0))
			return 0.72 + 0.015 * sin(f * 8.0)
	return 0.5


## Un plan du paysage (lointain ou proche) : un aplat sous la crête, et son trait d'encre.
func _strip(ci: Control, xs: PackedFloat32Array, far: bool) -> void:
	var u := _u
	var p := _pal(_pi)
	var base: Color = FAR[p] if far else NEAR[p]
	var c := Color(base, 0.55 if far else 0.88)
	var ridge := PackedVector2Array()
	for k in xs.size():
		var xk: float = xs[k]
		ridge.append(Vector2(xk, _far_y(xk) if far else _ground_y(xk)))
	var poly := ridge.duplicate()
	poly.append(Vector2(xs[xs.size() - 1], _ph + 2.0))
	poly.append(Vector2(xs[0], _ph + 2.0))
	ci.draw_colored_polygon(poly, c)
	if far:
		ci.draw_polyline(ridge, Color(Toon.SUMI, 0.18), maxf(1.0, 1.2 * u), true)
	else:
		ci.draw_polyline(ridge, Color(Toon.SUMI, 0.42), 2.0 * u, true)


# --- Motifs de chaque monde -----------------------------------------------------------

## Motifs d'arrière-plan (entre le plan lointain et le premier plan).
func _motif_back(ci: Control, i: int, sx: float) -> void:
	var u := _u
	var top := 0.0
	var s := _ps
	match _pal(i):
		0:
			# soleil du premier jour, petit Fuji, Grande Vague
			ci.draw_circle(Vector2(sx + 0.32 * s, top + 0.15 * _ph), 13.0 * u, Color(Toon.GOLD, 0.35))
			var fx := sx + 0.30 * s
			var yh := _far_y(fx) + 1.0 * u
			ci.draw_colored_polygon(PackedVector2Array([Vector2(fx - 24.0 * u, yh), Vector2(fx - 5.0 * u, yh - 20.0 * u),
				Vector2(fx + 5.0 * u, yh - 20.0 * u), Vector2(fx + 24.0 * u, yh)]), Color(Toon.PRUSSIAN, 0.5))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(fx - 9.0 * u, yh - 13.0 * u), Vector2(fx - 5.0 * u, yh - 20.0 * u),
				Vector2(fx + 5.0 * u, yh - 20.0 * u), Vector2(fx + 9.0 * u, yh - 13.0 * u)]), Color(1, 1, 1, 0.9))
			var wx := sx - 0.40 * s
			_great_wave(ci, Vector2(wx, _far_y(wx) + 6.0 * u), 0.9 * u, Color(Toon.PRUSSIAN, 0.85))
		1:
			# bambous lointains et feux de renards
			var offs := [-0.42, -0.2, 0.15, 0.29, 0.44]
			for k in offs.size():
				var o: float = offs[k]
				var bx := sx + o * s
				_bamboo(ci, Vector2(bx, _far_y(bx) + 8.0 * u), top - 10.0 * u, 6.0 * u, 3.0 * u, Color(Color("#93A86C"), 0.6), k, false)
			for k in 4:
				var p := Vector2(sx + (_hash(k * 7 + 3) - 0.5) * s * 0.95 + sin(_t * 0.7 + float(k)) * 10.0 * u,
					top + (0.22 + _hash(k * 5 + 1) * 0.3) * _ph + cos(_t * 0.9 + float(k) * 2.0) * 6.0 * u)
				ci.draw_circle(p, 5.0 * u, Color(Toon.GOLD, 0.2))
				ci.draw_circle(p, 2.0 * u, Color(Toon.GOLD, 0.9))
		2:
			# pagode du temple sur la crête
			var px := sx + 0.36 * s
			_pagoda(ci, Vector2(px, _far_y(px) + 6.0 * u), u, Color("#3E4652"))
		3:
			# nuages en écailles et neige sur le sommet du Fuji rouge
			for row in 2:
				for k in 7:
					var c := Vector2(sx + (float(k) - 3.0) * 20.0 * u + float(row) * 10.0 * u, top + (0.09 + float(row) * 0.05) * _ph)
					ci.draw_arc(c, 8.0 * u, PI, TAU, 10, Color(1, 1, 1, 0.75), 2.0 * u, true)
			var summit := _ph * 0.19
			for k in range(-3, 4):
				var kx := float(k)
				ci.draw_line(Vector2(sx + kx * 4.0 * u, summit + 1.0 * u), Vector2(sx + kx * 9.0 * u, summit + (9.0 + absf(kx) * 2.0) * u),
					Color(1, 1, 1, 0.75), 2.0 * u, true)
		4:
			# ensō noir dans le ciel et vague d'encre
			var ec := Vector2(sx + 0.30 * s, top + 0.17 * _ph)
			ci.draw_arc(ec, 22.0 * u, 0.5, TAU - 0.1, 40, Color(Toon.SUMI, 0.85), 5.0 * u, true)
			ci.draw_arc(ec + Vector2(1.5, 0.5) * u, 19.5 * u, 1.2, TAU - 0.6, 36, Color(Toon.SUMI, 0.5), 3.0 * u, true)
			var wx := sx - 0.40 * s
			_great_wave(ci, Vector2(wx, _far_y(wx) + 6.0 * u), 0.9 * u, Color(Color("#0E1A2E"), 0.9))
		5:
			# temple vermillon de Kurama sur la crête, corbeaux
			var px := sx + 0.34 * s
			_pagoda(ci, Vector2(px, _far_y(px) + 6.0 * u), u, Color("#8E2A1E"))
			for k in 5:
				var bp := Vector2(sx + (_hash(k * 9 + 4) - 0.5) * s * 0.9 + sin(_t * 0.6 + float(k)) * 8.0 * u,
					top + (0.12 + _hash(k * 3 + 7) * 0.18) * _ph)
				var wing := 5.0 * u * (0.8 + 0.4 * absf(sin(_t * 3.0 + float(k))))
				ci.draw_polyline(PackedVector2Array([bp + Vector2(-wing, -2.0 * u), bp, bp + Vector2(wing, -2.0 * u)]), Color(Toon.SUMI, 0.8), maxf(1.0, 1.5 * u), true)
		6:
			# palais du roi dragon et rayons de lumière qui tombent de la surface
			for k in 3:
				var rx := sx + (-0.3 + 0.3 * float(k)) * s
				ci.draw_colored_polygon(PackedVector2Array([Vector2(rx - 6.0 * u, top), Vector2(rx + 6.0 * u, top),
					Vector2(rx + 26.0 * u, top + _ph * 0.5), Vector2(rx + 10.0 * u, top + _ph * 0.5)]), Color(1, 1, 1, 0.12))
			var gx := sx + 0.3 * s
			_pagoda(ci, Vector2(gx, _far_y(gx) + 6.0 * u), u * 1.1, Color("#B8452E"))
			ci.draw_circle(Vector2(gx, _far_y(gx) - 58.0 * u), 6.0 * u, Color(Toon.GOLD, 0.8))
		7:
			# lune voilée et torii noirs sur la pente des morts
			ci.draw_circle(Vector2(sx + 0.3 * s, top + 0.16 * _ph), 14.0 * u, Color(Color("#E6E0EE"), 0.75))
			ci.draw_circle(Vector2(sx + 0.3 * s, top + 0.16 * _ph), 20.0 * u, Color(Color("#C9B8FF"), 0.15))
			for k in 2:
				var tx := sx + (-0.36 + 0.2 * float(k)) * s
				_torii_sil(ci, Vector2(tx, _far_y(tx) + 4.0 * u), u * (1.0 - 0.25 * float(k)), Color(Toon.SUMI, 0.85))


## Motifs de premier plan (devant le sol).
func _motif_front(ci: Control, i: int, sx: float) -> void:
	var u := _u
	var top := 0.0
	var bot := _ph
	var s := _ps
	match _pal(i):
		0:
			# crêtes d'écume sur la houle
			for k in range(-4, 5):
				var x := sx + float(k) * 24.0 * u + 6.0 * u
				var y := _ground_y(x)
				ci.draw_arc(Vector2(x, y + 8.0 * u), 7.0 * u, PI * 1.1, PI * 1.9, 8, Color(Toon.FOAM, 0.9), 2.0 * u, true)
				ci.draw_arc(Vector2(x + 12.0 * u, y + 22.0 * u), 6.0 * u, PI * 1.1, PI * 1.9, 8, Color(Toon.FOAM, 0.55), 1.5 * u, true)
		1:
			# grands bambous décorés de tanzaku
			var offs := [-0.48, -0.35, 0.37, 0.5]
			for k in offs.size():
				var o: float = offs[k]
				var bx := sx + o * s
				_bamboo(ci, Vector2(bx, _ground_y(bx) + 10.0 * u), top - 10.0 * u, -4.0 * u + float(k) * 3.0 * u, 6.0 * u, Color(Color("#5E7F4A"), 0.95), k, true)
		2:
			# pins sous la neige et flocons qui tombent
			var offs := [-0.44, 0.40, 0.52]
			for k in offs.size():
				var o: float = offs[k]
				var px := sx + o * s
				_pine(ci, Vector2(px, _ground_y(px) + 4.0 * u), u * (1.0 - 0.15 * float(k)))
			for k in 30:
				var hx := _hash(k * 3 + 1)
				var hy := _hash(k * 7 + 2)
				var sp := 0.5 + _hash(k * 11 + 5)
				var fx := sx + (hx - 0.5) * s * 1.1 + sin(_t * 1.3 + float(k)) * 6.0 * u
				var fy := top + fposmod(hy * _ph + _t * sp * 28.0 * u, _ph)
				ci.draw_circle(Vector2(fx, fy), (1.2 + _hash(k + 40) * 1.4) * u, Color(1, 1, 1, 0.95))
		3:
			# torches du Hi-Matsuri et braises qui montent
			for k in 2:
				var tx := sx + (-0.44 if k == 0 else 0.46) * s
				_torch(ci, Vector2(tx, _ground_y(tx) + 6.0 * u), u, k)
			for k in 14:
				var hx := _hash(k * 5 + 31)
				var hy := _hash(k * 11 + 7)
				var sp := 0.6 + _hash(k + 99)
				var span := _ph * 0.6
				var rise := fposmod(hy * span + _t * sp * 26.0 * u, span)
				var p := Vector2(sx + (hx - 0.5) * s * 1.05 + sin(_t * 2.0 + float(k)) * 4.0 * u, bot - _ph * 0.2 - rise)
				ci.draw_circle(p, 1.8 * u, Color(Toon.GOLD, 0.85 * (1.0 - rise / span)))
		4:
			# griffes d'écume et papiers déchirés qui flottent
			for k in range(-4, 5):
				var x := sx + float(k) * 22.0 * u + 8.0 * u
				var y := _ground_y(x)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 5.0 * u, y + 2.0 * u), Vector2(x + 1.0 * u, y - 8.0 * u),
					Vector2(x + 4.0 * u, y + 2.0 * u)]), Color(Toon.FOAM, 0.85))
			for k in 5:
				var fx := sx + (_hash(k * 13 + 5) - 0.5) * s
				var fy := _ground_y(fx) + 14.0 * u + sin(_t * 1.4 + float(k) * 1.7) * 3.0 * u
				var ang := sin(_t * 0.9 + float(k)) * 0.3 + float(k)
				var r := (5.0 + 4.0 * _hash(k * 3 + 1)) * u
				var c := Vector2(fx, fy)
				var pts := PackedVector2Array([c + Vector2(-r, -r * 0.6).rotated(ang), c + Vector2(r * 0.8, -r * 0.7).rotated(ang),
					c + Vector2(r, r * 0.5).rotated(ang), c + Vector2(-r * 0.7, r * 0.6).rotated(ang)])
				ci.draw_colored_polygon(pts, Toon.PAPER)
				var outline := pts.duplicate()
				outline.append(pts[0])
				ci.draw_polyline(outline, Color(Toon.SUMI, 0.6), maxf(1.0, u), true)
		5:
			# grands cèdres du Kurama et lanterne vermillon
			var offs := [-0.48, -0.36, 0.38, 0.5]
			for k in offs.size():
				var o: float = offs[k]
				var cx := sx + o * s
				_cedar(ci, Vector2(cx, _ground_y(cx) + 6.0 * u), u * (1.1 - 0.12 * float(k % 2)))
			var lx := sx - 0.22 * s
			var ly := _ground_y(lx)
			ci.draw_line(Vector2(lx, ly + 4.0 * u), Vector2(lx, ly - 16.0 * u), Color(Toon.SUMI, 0.8), 2.0 * u, true)
			ci.draw_circle(Vector2(lx, ly - 21.0 * u), 6.0 * u, Color(Toon.VERMILION, 0.9))
			ci.draw_circle(Vector2(lx, ly - 21.0 * u), 9.0 * u, Color(Toon.GOLD, 0.15))
		6:
			# coraux, varech qui ondule et bulles qui montent
			for k in 4:
				var kx := sx + (-0.5 + 0.33 * float(k)) * s + 6.0 * u
				var base := Vector2(kx, _ground_y(kx) + 6.0 * u)
				var prev := base
				for j in 5:
					var q := base + Vector2(sin(_t * 1.4 + float(j) * 0.8 + float(k)) * 4.0 * u, -float(j + 1) * 10.0 * u)
					ci.draw_line(prev, q, Color(Color("#4E7A4A"), 0.9), (3.0 - 0.4 * float(j)) * u, true)
					prev = q
			for k in 3:
				var cx2 := sx + (-0.35 + 0.35 * float(k)) * s
				var cb := Vector2(cx2, _ground_y(cx2) + 4.0 * u)
				var cc: Color = [Color("#D9705E"), Color("#E39A6A"), Color("#C2456A")][k]
				for j in 3:
					var a := -PI * 0.5 + (float(j) - 1.0) * 0.5
					ci.draw_line(cb, cb + Vector2(cos(a), sin(a)) * 12.0 * u, cc, 3.0 * u, true)
			for k in 14:
				var hx := _hash(k * 7 + 13)
				var hy := _hash(k * 5 + 3)
				var span := _ph * 0.65
				var rise := fposmod(hy * span + _t * (0.5 + _hash(k + 61)) * 22.0 * u, span)
				var p := Vector2(sx + (hx - 0.5) * s * 1.05 + sin(_t * 1.6 + float(k)) * 3.0 * u, bot - _ph * 0.18 - rise)
				ci.draw_arc(p, (1.6 + _hash(k + 21) * 1.6) * u, 0.0, TAU, 10, Color(1, 1, 1, 0.8 * (1.0 - rise / span)), maxf(1.0, 0.9 * u), true)
		7:
			# pins morts, lanternes flottantes et feux d'âmes
			for k in 2:
				var dx := sx + (-0.46 if k == 0 else 0.44) * s
				_dead_tree(ci, Vector2(dx, _ground_y(dx) + 4.0 * u), u * (1.0 - 0.15 * float(k)))
			for k in 4:
				var lx2 := sx + (-0.25 + 0.17 * float(k)) * s
				var ly2 := _ground_y(lx2) + 14.0 * u + sin(_t * 1.2 + float(k)) * 2.0 * u
				ci.draw_rect(Rect2(lx2 - 3.5 * u, ly2 - 6.0 * u, 7.0 * u, 6.0 * u), Color(Color("#F0E6C8"), 0.9))
				ci.draw_circle(Vector2(lx2, ly2 - 3.0 * u), 7.0 * u, Color(Toon.GOLD, 0.12))
			for k in 6:
				var hx2 := _hash(k * 11 + 2)
				var span2 := _ph * 0.5
				var rise2 := fposmod(_hash(k * 3 + 9) * span2 + _t * 14.0 * u, span2)
				var wp := Vector2(sx + (hx2 - 0.5) * s, bot - _ph * 0.25 - rise2)
				ci.draw_circle(wp, 4.0 * u, Color(Color("#C9B8FF"), 0.2 * (1.0 - rise2 / span2)))
				ci.draw_circle(wp, 1.8 * u, Color(Color("#E6DCFF"), 0.85 * (1.0 - rise2 / span2)))


func _great_wave(ci: Control, base: Vector2, s: float, body: Color) -> void:
	var pts := PackedVector2Array()
	for q in WAVE:
		var v: Vector2 = q
		pts.append(base + v * s)
	ci.draw_colored_polygon(pts, body)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(Toon.SUMI, 0.55), maxf(1.0, 1.5 * s), true)
	var inner := PackedVector2Array()
	for q in WAVE_FOAM:
		var v: Vector2 = q
		inner.append(base + v * s)
	ci.draw_polyline(inner, Color(Toon.FOAM, 0.85), 3.0 * s, true)
	for q in WAVE_CLAWS:
		var v: Vector2 = q
		ci.draw_circle(base + v * s, 3.2 * s, Toon.FOAM)


## Tige de bambou : nœuds, feuilles et (si riche) bandes de papier tanzaku.
func _bamboo(ci: Control, base: Vector2, top_y: float, lean: float, wdt: float, col: Color, k: int, rich: bool) -> void:
	var u := _u
	var tip := Vector2(base.x + lean, top_y)
	ci.draw_line(base, tip, col, wdt, true)
	var axis := tip - base
	var ln := axis.length()
	if ln < 1.0:
		return
	var dir := axis / ln
	var nrm := Vector2(-dir.y, dir.x)
	var seg := 30.0 * u
	var dist := seg * (0.6 + 0.2 * float(k % 3))
	var j := 0
	var node_col := col.darkened(0.35)
	while dist < ln:
		var p := base + dir * dist
		ci.draw_line(p - nrm * wdt * 0.7, p + nrm * wdt * 0.7, node_col, maxf(1.0, wdt * 0.3), true)
		if rich and (j + k) % 3 == 0:
			var side := 1.0 if j % 2 == 0 else -1.0
			var sway := sin(_t * 1.2 + float(j + k)) * 0.08
			for leaf in 2:
				var dl := Vector2(side, -0.25 + 0.35 * float(leaf)).normalized().rotated(sway)
				var nl := Vector2(-dl.y, dl.x)
				ci.draw_colored_polygon(PackedVector2Array([p, p + dl * 8.0 * u + nl * 3.0 * u, p + dl * 18.0 * u, p + dl * 8.0 * u - nl * 3.0 * u]),
					Color(Color("#3F6233"), 0.9))
		if rich and j == 2 + k % 2:
			var hp := p + nrm * wdt * 0.5
			var down := Vector2(0, 1).rotated(sin(_t * 1.7 + float(k)) * 0.18)
			var q := down.orthogonal() * 2.5 * u
			var s0 := hp + down * 6.0 * u
			ci.draw_line(hp, s0, Color(Toon.SUMI, 0.4), maxf(1.0, 0.8 * u), true)
			var tc: Color = TANZAKU[(k + j) % TANZAKU.size()]
			ci.draw_colored_polygon(PackedVector2Array([s0 - q, s0 + q, s0 + q + down * 15.0 * u, s0 - q + down * 15.0 * u]), Color(tc, 0.95))
		dist += seg
		j += 1


func _pagoda(ci: Control, base: Vector2, s: float, col: Color) -> void:
	for k in 3:
		var y := base.y - float(k) * 13.0 * s
		var hw := (15.0 - float(k) * 3.0) * s
		ci.draw_rect(Rect2(base.x - hw * 0.55, y - 9.0 * s, hw * 1.1, 9.0 * s), col)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x - hw - 3.0 * s, y - 8.0 * s), Vector2(base.x - hw * 0.4, y - 13.0 * s),
			Vector2(base.x + hw * 0.4, y - 13.0 * s), Vector2(base.x + hw + 3.0 * s, y - 8.0 * s)]), col)
		ci.draw_line(Vector2(base.x - hw * 0.4, y - 13.0 * s), Vector2(base.x + hw * 0.4, y - 13.0 * s), Color(1, 1, 1, 0.9), 2.0 * s)
	ci.draw_line(Vector2(base.x, base.y - 39.0 * s), Vector2(base.x, base.y - 50.0 * s), col, maxf(1.0, 1.5 * s))


func _pine(ci: Control, base: Vector2, s: float) -> void:
	var dark := Color(Color("#33414B"), 0.92)
	ci.draw_line(base, base + Vector2(0, -10.0 * s), Color("#4A3A2E"), 3.0 * s)
	for k in 3:
		var y := base.y - 8.0 * s - float(k) * 11.0 * s
		var hw := (14.0 - float(k) * 3.5) * s
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x - hw, y), Vector2(base.x, y - 16.0 * s), Vector2(base.x + hw, y)]), dark)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x - hw * 0.45, y - 9.0 * s), Vector2(base.x, y - 16.0 * s),
			Vector2(base.x + hw * 0.45, y - 9.0 * s)]), Color(1, 1, 1, 0.95))


## Cèdre du Japon : tronc roux, étages triangulaires sombres.
func _cedar(ci: Control, base: Vector2, s: float) -> void:
	ci.draw_line(base, base + Vector2(0, -14.0 * s), Color("#5A3A2A"), 3.5 * s)
	var dark := Color(Color("#22382A"), 0.95)
	for k in 4:
		var y := base.y - 10.0 * s - float(k) * 12.0 * s
		var hw := (15.0 - float(k) * 3.0) * s
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x - hw, y), Vector2(base.x, y - 18.0 * s), Vector2(base.x + hw, y)]), dark)
		ci.draw_line(Vector2(base.x - hw * 0.5, y - 4.0 * s), Vector2(base.x + hw * 0.2, y - 6.0 * s), Color(Color("#4E6E5B"), 0.8), maxf(1.0, 1.2 * s))


## Pin mort : tronc tordu et branches nues.
func _dead_tree(ci: Control, base: Vector2, s: float) -> void:
	var col := Color(Color("#141018"), 0.9)
	var p1 := base + Vector2(4.0 * s, -26.0 * s)
	var p2 := p1 + Vector2(-8.0 * s, -20.0 * s)
	var p3 := p2 + Vector2(6.0 * s, -14.0 * s)
	ci.draw_polyline(PackedVector2Array([base, p1, p2, p3]), col, 4.0 * s, true)
	ci.draw_line(p1, p1 + Vector2(16.0 * s, -8.0 * s), col, 2.2 * s, true)
	ci.draw_line(p2, p2 + Vector2(-15.0 * s, -6.0 * s), col, 2.0 * s, true)
	ci.draw_line(p2 + Vector2(1.0 * s, -6.0 * s), p2 + Vector2(13.0 * s, -16.0 * s), col, 1.6 * s, true)


## Torii en silhouette (deux poteaux, kasagi relevé, nuki).
func _torii_sil(ci: Control, base: Vector2, s: float, col: Color) -> void:
	ci.draw_line(base + Vector2(-9.0 * s, 0), base + Vector2(-8.0 * s, -26.0 * s), col, 3.0 * s, true)
	ci.draw_line(base + Vector2(9.0 * s, 0), base + Vector2(8.0 * s, -26.0 * s), col, 3.0 * s, true)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-15.0 * s, -27.0 * s), base + Vector2(15.0 * s, -27.0 * s),
		base + Vector2(17.0 * s, -31.0 * s), base + Vector2(-17.0 * s, -31.0 * s)]), col)
	ci.draw_line(base + Vector2(-11.0 * s, -21.0 * s), base + Vector2(11.0 * s, -21.0 * s), col, 2.0 * s, true)


func _torch(ci: Control, base: Vector2, s: float, k: int) -> void:
	ci.draw_line(base, base + Vector2(0, -38.0 * s), Color(Toon.SUMI, 0.85), 3.5 * s, true)
	var c := base + Vector2(0, -44.0 * s)
	var fl := 1.0 + 0.15 * sin(_t * 11.0 + float(k) * 2.0)
	ci.draw_circle(c, 13.0 * s, Color(Toon.GOLD, 0.15))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14.0 * s * fl), c + Vector2(6.0 * s, -2.0 * s), c + Vector2(4.0 * s, 5.0 * s),
		c + Vector2(-4.0 * s, 5.0 * s), c + Vector2(-6.0 * s, -2.0 * s)]), Color(Color("#E39B3B"), 0.92))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7.0 * s * fl), c + Vector2(3.0 * s, 0.0), c + Vector2(0, 4.0 * s),
		c + Vector2(-3.0 * s, 0.0)]), Color(Color("#F4D58A"), 0.95))


# --- Sceaux, cadenas, tampons ------------------------------------------------------------

## Secondes écoulées depuis que le tampon du boss vaincu de ce monde a frappé (< 0 : pas encore).
## La première fois de la session, il frappe quand le monde arrive au centre ; ensuite il est déjà posé.
func _stamp_elapsed(id: int, focus: float) -> float:
	if _stamp_at.has(id):
		return _t - float(_stamp_at[id])
	if _stamps_seen.has(id):
		_stamp_at[id] = -100.0
		return _t + 100.0
	if focus > 0.7 and _ready_k >= 1.0 and _leaving == 0:
		_stamps_seen[id] = true
		_stamp_at[id] = _t + 0.1
	return -1.0


## Tampon du boss vaincu : sceau vermillon cerclé d'or, picto oni en papier (aucun mot), posé en biais ;
## e = secondes depuis la frappe (il s'abat, rebondit, projette des gouttes d'encre).
## xf : transformation de la carte (déjà appliquée), qu'on retrouve à la fin.
func _stamp(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float, e: float) -> void:
	var u := _u
	var slam := 0.26
	var k := clampf(e / slam, 0.0, 1.0)
	var s := 1.0 + 1.6 * (1.0 - k) * (1.0 - k)
	var a := clampf(k * 1.6, 0.0, 1.0)
	if e > slam:
		var e2 := e - slam
		s = 1.0 + 0.07 * sin(e2 * 28.0) * exp(-e2 * 9.0)
		# gouttes d'encre projetées à l'impact
		if e2 < 0.5:
			var sp := e2 / 0.5
			for q in 10:
				var ang := float(q) / 10.0 * TAU + _hash(q + 7) * 0.5
				var dist := r * (1.1 + 0.6 * sp) * (0.9 + 0.3 * _hash(q * 3 + 1))
				ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * dist, (2.5 - 1.5 * sp) * u, Color(Toon.VERMILION, 0.8 * (1.0 - sp)))
	ci.draw_set_transform_matrix(xf * Transform2D(-0.3, Vector2(s, s), 0.0, c))
	var sq := Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0)
	var rad := maxi(1, int(r * 0.25))
	UiKit.box(_box, Color(Toon.SUMI, 0.25 * a), rad)
	ci.draw_style_box(_box, Rect2(sq.position + Vector2(2.0, 3.0) * u, sq.size))
	UiKit.box(_box, Color(Toon.VERMILION, 0.94 * a), rad, Color(UIColors.GOLD, a), maxi(1, int(2.5 * u)))
	ci.draw_style_box(_box, sq)
	_box.set_border_width_all(0)
	ci.draw_rect(sq.grow(-5.0 * u), Color(Toon.WASHI, 0.6 * a), false, maxf(1.0, 1.2 * u))
	UiKit.draw_icon(ci, "hud/oni", Vector2.ZERO, r * 1.1, a, Toon.WASHI)
	# grain du tampon
	for q in 10:
		var gp := Vector2((_hash(q * 5 + 2) - 0.5) * r * 1.7, (_hash(q * 9 + 4) - 0.5) * r * 1.7)
		ci.draw_circle(gp, (0.6 + _hash(q + 30)) * u, Color(Toon.VERMILION.lightened(0.35), 0.55 * a))
	ci.draw_set_transform_matrix(xf)


## Cadenas dessiné : anse et corps d'encre, trou de serrure washi.
func _lock_icon(ci: CanvasItem, c: Vector2, s: float) -> void:
	var body := Rect2(c.x - s * 0.6, c.y - s * 0.15, s * 1.2, s * 0.95)
	_box.set_border_width_all(0)
	_box.bg_color = Toon.WASHI
	_box.set_corner_radius_all(maxi(1, int(s * 0.28)))
	ci.draw_style_box(_box, body.grow(s * 0.12))
	ci.draw_arc(Vector2(c.x, c.y - s * 0.15), s * 0.4, PI, TAU, 16, Toon.WASHI, s * 0.42, true)
	ci.draw_arc(Vector2(c.x, c.y - s * 0.15), s * 0.4, PI, TAU, 16, Toon.SUMI, s * 0.2, true)
	_box.bg_color = Toon.SUMI
	_box.set_corner_radius_all(maxi(1, int(s * 0.18)))
	ci.draw_style_box(_box, body)
	ci.draw_circle(Vector2(c.x, c.y + s * 0.2), s * 0.13, Toon.WASHI)
	ci.draw_rect(Rect2(c.x - s * 0.05, c.y + s * 0.22, s * 0.1, s * 0.3), Toon.WASHI)


## Bris du cadenas (e = secondes depuis le bris) : l'anse s'envole, le corps tombe, gouttes d'encre
## projetées, anneau et rayons d'or, paillettes qui retombent.
func _break_fx(ci: CanvasItem, c: Vector2, r: float, e: float) -> void:
	var u := _u
	# éclats du cadenas
	var pk := clampf(e / 0.6, 0.0, 1.0)
	if pk < 1.0:
		var pa := 1.0 - pk
		var s := r * 0.72
		var up := c + Vector2(-r * 0.5 * pk, -r * 1.3 * pk + r * 0.9 * pk * pk) + Vector2(0, -s * 0.15)
		ci.draw_arc(up, s * 0.4, PI + pk * 1.2, TAU + pk * 1.2, 16, Color(Toon.SUMI, pa), s * 0.2, true)
		var body := Rect2(c.x - s * 0.6 + r * 0.45 * pk, c.y - s * 0.15 + r * 1.6 * pk * pk, s * 1.2, s * 0.95)
		_box.set_border_width_all(0)
		_box.bg_color = Color(Toon.SUMI, pa)
		_box.set_corner_radius_all(maxi(1, int(s * 0.18)))
		ci.draw_style_box(_box, body)
	# gouttes d'encre projetées
	var ik := clampf(e / 0.55, 0.0, 1.0)
	if ik < 1.0:
		for q in 14:
			var ang := float(q) / 14.0 * TAU + _hash(q + 3) * 0.6
			var dist := r * (0.9 + 1.3 * UiKit.ease_out(ik)) * (0.8 + 0.4 * _hash(q * 5 + 2))
			var dr := (3.2 - 2.2 * ik) * u * (0.7 + 0.6 * _hash(q + 11))
			ci.draw_circle(c + Vector2(cos(ang), sin(ang) * 0.8) * dist + Vector2(0, r * 0.4 * ik * ik), dr, Color(Toon.SUMI, 0.85 * (1.0 - ik)))
	# anneau et rayons d'or
	var gk := clampf(e / 0.8, 0.0, 1.0)
	if gk < 1.0:
		var ga := 1.0 - gk
		ci.draw_arc(c, r * (1.0 + 1.5 * UiKit.ease_out(gk)), 0.0, TAU, 48, Color(Toon.GOLD, 0.9 * ga), (5.0 - 3.0 * gk) * u, true)
		for q in 12:
			var ang2 := float(q) / 12.0 * TAU + 0.26
			var d0 := r * (1.05 + 0.6 * gk)
			var d1 := r * (1.35 + 1.4 * UiKit.ease_out(gk))
			var dv := Vector2.from_angle(ang2)
			ci.draw_line(c + dv * d0, c + dv * d1, Color(Toon.GOLD, 0.85 * ga), maxf(1.0, (3.0 - 1.8 * gk) * u), true)
	# paillettes d'or qui retombent
	var sk := clampf(e / 1.4, 0.0, 1.0)
	if sk < 1.0:
		for q in 18:
			var ang3 := _hash(q * 7 + 1) * TAU
			var sp := r * (1.2 + 1.6 * _hash(q * 3 + 5))
			var pos := c + Vector2(cos(ang3), sin(ang3) - 0.6) * sp * UiKit.ease_out(sk) + Vector2(0, r * 1.8 * sk * sk)
			ci.draw_circle(pos, (1.2 + _hash(q + 50) * 1.6) * u, Color(Toon.GOLD, 0.95 * (1.0 - sk)))


## Carte du monde révélé, sur un voile d'encre : feuille de washi, trait de la couleur du monde,
## « MONDE N DÉBLOQUÉ », sceau qui se pose, nom, ambiance, et l'aperçu des nouveaux rouleaux.
func _draw_overlay() -> void:
	if _reveal_id == 0 or _reveal_i < 0 or size.x < 10.0:
		return
	var k_in := UiKit.ease_out(clampf((_rv - RV_CARD) / 0.35, 0.0, 1.0))
	var k_out := 1.0 - UiKit.ease_out(clampf((_rv - _rv_out) / 0.35, 0.0, 1.0))
	var k := minf(k_in, k_out)
	if k <= 0.0:
		return
	var ci: Control = _overlay
	var u := _u
	var w := size.x
	var ink: Color = Toon.ui_ink
	var paper: Color = Toon.ui_paper
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.6 * k))
	var d: Dictionary = _worlds[_reveal_i]
	var col: Color = d.get("color", Toon.PRUSSIAN)
	var has_p := not _reveal_powers.is_empty()
	var cw := minf(w * 0.84, 330.0 * u)
	var ch := (300.0 if has_p else 214.0) * u
	var cy := _ccy - ch / 2.0 + 26.0 * u * (1.0 - k_in)
	var card := Rect2((w - cw) / 2.0, cy, cw, ch)
	# feuille aux coins arrondis cernée d'encre, comme les cartes (ombre en deux décalages, sans flou)
	var cpts := UiKit.rrect_points(card, CARD_R * u)
	ci.draw_colored_polygon(Transform2D(0.0, Vector2(0, 6.0 * u)) * cpts, Color(0, 0, 0, 0.12 * k))
	ci.draw_colored_polygon(cpts, Color(paper, k))
	cpts.append(cpts[0])
	ci.draw_polyline(cpts, Color(Toon.SUMI, k), 2.5 * u, true)
	var band := Rect2(card.position + Vector2(cw * 0.2, 12.0 * u), Vector2(cw * 0.6, 7.0 * u))
	if k_in > 0.05:
		ci.draw_colored_polygon(UiKit.swash_points(band, k_in, 2.0), Color(col, 0.9 * k))
	var cx := card.get_center().x
	var top := card.position.y
	var inner := cw - 40.0 * u
	_centered(ci, _caps, "MONDE %d DÉBLOQUÉ" % _reveal_id, Vector2(cx, top + 42.0 * u), maxi(1, int(10.5 * u)), Color(Toon.VERMILION, k))
	# sceau du monde, qui se pose
	var sk := UiKit.ease_out(clampf((_rv - RV_CARD - 0.15) / 0.3, 0.0, 1.0))
	if sk > 0.0:
		var hs := 54.0 * u
		var sc := 1.0 + 0.4 * (1.0 - sk)
		ci.draw_set_transform(Vector2(cx, top + 82.0 * u), -0.04, Vector2(sc, sc))
		_world_badge(ci, Rect2(Vector2(-hs, -hs) / 2.0, Vector2(hs, hs)), str(d.get("kanji", "道")), col, k * sk)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# nom et ambiance
	_centered_fit(ci, _title, UiKit.plain(str(d.get("name", ""))), Vector2(cx, top + 148.0 * u), maxi(1, int(26.0 * u)), inner, Color(ink, k))
	var sl := _sub_lines(_reveal_i, UiKit.plain(str(d.get("subtitle", ""))), inner)
	var sfs := int(sl[0])
	var lines: PackedStringArray = sl[1]
	var ly := top + 170.0 * u
	for line in lines:
		var lt := String(line)
		_centered(ci, _ui, lt, Vector2(cx, ly), _fit_size(_ui, lt, sfs, inner), Color(ink, 0.65 * k))
		ly += float(sfs) * 1.35
	if has_p:
		ci.draw_line(Vector2(card.position.x + 30.0 * u, top + 204.0 * u), Vector2(card.end.x - 30.0 * u, top + 204.0 * u), Color(ink, 0.15 * k), maxf(1.0, 1.0 * u))
		UiKit.draw_icon(ci, "hud/rouleau", Vector2(cx, top + 220.0 * u), 18.0 * u, k, _gold_ink())
		var n := _reveal_powers.size()
		var shown := mini(n, 6)
		var ir := 13.0 * u
		var gap := 32.0 * u
		for q in shown:
			var qk := UiKit.ease_out(clampf((_rv - RV_CARD - 0.35 - 0.07 * float(q)) / 0.25, 0.0, 1.0))
			if qk <= 0.0:
				continue
			var ic := Vector2(cx + (float(q) - float(shown - 1) / 2.0) * gap, top + 251.0 * u)
			UiKit.power_icon(ci, String(_reveal_powers[q]), ic, ir * (0.6 + 0.4 * qk), k * qk)
		_centered(ci, UiKit.num_font(), "+%d" % n, Vector2(cx, top + 284.0 * u), maxi(1, int(12.0 * u)), Color(_gold_ink(), k))
	# invitation à continuer : un doigt qui pulse (onde, puis le doigt qui s'enfonce), sans un mot
	var hc := Vector2(cx, card.end.y + 34.0 * u)
	var ht := fmod(_t, 1.2)
	if ht < 0.7:
		ci.draw_arc(hc, (12.0 + 30.0 * ht) * u, 0, TAU, 28, Color(Toon.WASHI, (0.7 - ht) * k), 2.0 * u, true)
	var press := 1.0 if ht < 0.15 else 0.0
	ci.draw_circle(hc, 14.0 * u, Color(Toon.ui_paper, 0.9 * k))
	ci.draw_arc(hc, 14.0 * u, 0, TAU, 28, Color(Toon.ui_ink, 0.5 * k), maxf(1.0, 1.2 * u), true)
	ci.draw_circle(hc, (7.0 + 1.5 * (1.0 - press)) * u, Color(Toon.VERMILION, 0.85 * k))


# --- Utilitaires ---------------------------------------------------------------------

func _centered(ci: CanvasItem, font: Font, txt: String, at: Vector2, fs: int, c: Color) -> float:
	return UiKit.text(ci, font, txt, at, fs, c)


## Texte centré qui rétrécit pour tenir dans max_w.
func _centered_fit(ci: CanvasItem, font: Font, txt: String, at: Vector2, fs: int, max_w: float, c: Color) -> void:
	_centered(ci, font, txt, at, _fit_size(font, txt, fs, max_w), c)


## Taille de police (<= fs) pour que txt tienne dans max_w.
func _fit_size(font: Font, txt: String, fs: int, max_w: float) -> int:
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > max_w and tw > 0.0:
		return maxi(1, int(float(fs) * max_w / tw))
	return fs
