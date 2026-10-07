extends Control
## Choix du monde façon emakimono : un rouleau peint horizontal se déroule entre deux baguettes de bois.
## Le paysage traverse les cinq mondes (vagues, bambous, neige, Fuji rouge, mer d'encre) le long d'un
## chemin d'encre ; on fait glisser le rouleau au doigt (inertie douce) ou aux flèches, PARTIR lance le monde centré.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

# teintes du paysage par monde (indice = id - 1) : ciel, plan lointain, premier plan
const SKY := [Color("#D3DEE6"), Color("#DCE2C8"), Color("#C3CCD6"), Color("#AFC2D0"), Color("#DCCBC4")]
const FAR := [Color("#7F9BB3"), Color("#93A86C"), Color("#A9BED0"), Color("#9C3B2A"), Color("#6E6A80")]
const NEAR := [Color("#1F3A5F"), Color("#5E7F4A"), Color("#E3EAEF"), Color("#5A5550"), Color("#0E1A2E")]
const TANZAKU := [Color("#E9C46A"), Color("#9EC1CF"), Color("#E7B3C3"), Color("#F1EDE4"), Color("#B5C99A")]
# la Grande Vague (contour, ligne d'écume intérieure, griffes), en unités locales
const WAVE := [Vector2(-70, 0), Vector2(-55, -28), Vector2(-38, -58), Vector2(-18, -80), Vector2(4, -90),
	Vector2(24, -86), Vector2(38, -74), Vector2(42, -60), Vector2(34, -50), Vector2(24, -56),
	Vector2(16, -62), Vector2(6, -58), Vector2(0, -44), Vector2(2, -24), Vector2(10, 0)]
const WAVE_FOAM := [Vector2(-56, -14), Vector2(-42, -40), Vector2(-24, -62), Vector2(-2, -76), Vector2(18, -76), Vector2(30, -66)]
const MINI_ROOM := 4  # étape du gardien (main.STAGE_PLAN : 8 étapes, la 4e est son arène)
const WAVE_CLAWS := [Vector2(6, -93), Vector2(16, -93), Vector2(27, -89), Vector2(36, -81), Vector2(43, -70), Vector2(45, -59), Vector2(40, -52)]

signal world_chosen(id: int)
signal closed

var _worlds: Array = []
var _unlocked := 1
var _best: Dictionary = {}
var _rooms := 8  # étapes d'une partie (record affiché sur « _rooms » points)
var _wins: Dictionary = {}  # Vues gagnées ("w4_win", "w4_mini"...) ou id -> true
var _stamp_at: Dictionary = {}  # id -> instant (_t) où le sceau ACCOMPLI frappe
static var _stamps_seen := {}  # sceaux déjà frappés pendant la session (pas de nouvelle animation)

var _t := 0.0  # temps réel depuis l'ouverture
var _scroll := 0.0  # position du rouleau, en indice de monde (0 = premier)
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
var _unroll := 0.0  # 0 = rouleau fermé, 1 = déroulé
var _fade := 1.0

# mise en page (recalculée à chaque image)
var _u := 1.0
var _cx := 0.0
var _step := 180.0  # écart entre deux étapes sur le papier
var _py0 := 0.0
var _ph := 0.0
var _pw := 0.0
var _half := 0.0
var _ready_k := 0.0
var _station_rects: Array = []
var _arrow_l := Vector2.ZERO
var _arrow_r := Vector2.ZERO
var _show_l := false
var _show_r := false

var _fibers: Array = []
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _box := StyleBoxFlat.new()
var _paper: Control  # papier du rouleau (découpé à sa largeur déroulée)
var _front: Control  # baguettes et flèches, par-dessus le papier
var _go: InkButton
var _back: InkButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 2
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 2
	_box.anti_aliasing = true

	_paper = Control.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.clip_contents = true
	add_child(_paper)
	_paper.draw.connect(_draw_paper)

	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_front)
	_front.draw.connect(_draw_front)

	_go = InkButton.new()
	_go.text = "PARTIR"
	_go.style = "primary"
	_go.font = _ui
	add_child(_go)
	_go.pressed.connect(_on_go)

	_back = InkButton.new()
	_back.style = "round"
	_back.icon = "home"
	add_child(_back)
	_back.pressed.connect(_on_back)

	_make_fibers()


## worlds : Array de Dictionary {id, name, kanji, subtitle, color} ; unlocked : nombre de mondes ouverts ;
## best : id -> meilleure salle atteinte ; current : id du monde centré à l'ouverture ;
## rooms : nombre de salles d'une partie ; wins : Vues possédées (meta.owned_prints : "w<id>_win",
## "w<id>_mini") ou id -> true. Vide : un monde compte comme fini dès que son record atteint « rooms ».
func open(worlds: Array, unlocked: int, best: Dictionary, current: int, rooms := 8, wins := {}) -> void:
	_worlds = worlds
	_unlocked = clampi(unlocked, 1, maxi(1, worlds.size()))
	_best = best
	_rooms = maxi(1, rooms)
	_wins = wins
	_stamp_at.clear()
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
	_unroll = 0.0
	_fade = 1.0
	modulate.a = 1.0
	_station_rects.clear()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true


# --- Données ---------------------------------------------------------------------

func _id(i: int) -> int:
	var d: Dictionary = _worlds[i]
	return int(d.get("id", i + 1))


func _locked(i: int) -> bool:
	return _id(i) > _unlocked


## Indice de palette du paysage (0..4) pour l'étape i.
func _pal(i: int) -> int:
	return clampi(_id(i) - 1, 0, 4)


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
	return _wins.is_empty() and _best_of(i) >= _rooms


func _mini_done(i: int) -> bool:
	return _won(i) or _flag(_id(i), "mini") or _best_of(i) > MINI_ROOM


func _sel() -> int:
	return clampi(int(roundf(_scroll)), 0, maxi(0, _worlds.size() - 1))


# --- Entrée ----------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _leaving != 0 or _t < 0.35 or _worlds.is_empty():
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
			_scroll = _rubber(_press_scroll - dx / _step)
			_drag_accum += mm.relative.x
		accept_event()


## Au-delà des extrémités, le papier résiste (élastique).
func _rubber(raw: float) -> float:
	var hi := float(_worlds.size() - 1)
	if raw < 0.0:
		return raw * 0.3
	if raw > hi:
		return hi + (raw - hi) * 0.3
	return raw


func _release_flick() -> void:
	var proj := _scroll + clampf(_vel * 0.28, -1.6, 1.6)
	var tgt := roundf(proj)
	if tgt == roundf(_scroll) and absf(_vel) > 1.4:
		tgt += signf(_vel)
	_target = clampf(tgt, 0.0, float(_worlds.size() - 1))


func _nudge(d: int) -> void:
	_target = clampf(roundf(_target) + float(d), 0.0, float(_worlds.size() - 1))


func _tap(p: Vector2) -> void:
	if _show_l and p.distance_to(_arrow_l) < 28.0 * _u:
		_nudge(-1)
		return
	if _show_r and p.distance_to(_arrow_r) < 28.0 * _u:
		_nudge(1)
		return
	var paper := Rect2(_cx - _half, _py0, _half * 2.0, _ph)
	if not paper.has_point(p):
		return
	for i in _station_rects.size():
		var r: Rect2 = _station_rects[i]
		if r.has_area() and r.has_point(p):
			if i == _sel():
				_on_go()
			else:
				_target = float(i)
			return


func _on_go() -> void:
	if _leaving != 0 or _worlds.is_empty() or _t < 0.35:
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

	if _pressing and _moved:
		if real > 0.0:
			var inst := -_drag_accum / maxf(_step, 1.0) / real
			_vel = lerpf(_vel, inst, 0.35)
		_drag_accum = 0.0
	else:
		_scroll = lerpf(_scroll, _target, 1.0 - exp(-8.0 * real))

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

	var opening := UiKit.ease_out(clampf((_t - 0.12) / 0.85, 0.0, 1.0))
	var closing := 1.0
	if _leaving != 0:
		closing = 1.0 - UiKit.ease_out(clampf(_leave_t / 0.4, 0.0, 1.0))
	_unroll = opening * closing
	_fade = closing
	modulate.a = clampf(closing * 1.8, 0.0, 1.0)
	_layout()
	queue_redraw()
	_paper.queue_redraw()
	_front.queue_redraw()


func _layout() -> void:
	var w := size.x
	var h := size.y
	_u = minf(w / 400.0, h / 760.0)
	var u := _u
	_step = 180.0 * u
	_cx = w / 2.0
	_ph = clampf(h * 0.58, 280.0 * u, 540.0 * u)
	_py0 = h * 0.47 - _ph / 2.0
	_pw = minf(w - 68.0 * u, _step * 5.6)
	_half = _pw / 2.0 * (0.04 + 0.96 * _unroll)
	_paper.position = Vector2(_cx - _half, _py0)
	_paper.size = Vector2(_half * 2.0, _ph)
	_front.position = Vector2.ZERO
	_front.size = size

	var n := _worlds.size()
	_ready_k = clampf((_unroll - 0.85) / 0.15, 0.0, 1.0)
	_show_l = n > 1 and _ready_k > 0.0 and _scroll > 0.3
	_show_r = n > 1 and _ready_k > 0.0 and _scroll < float(n - 1) - 0.3
	_arrow_l = Vector2(_cx - _half + 26.0 * u, _py0 + _ph * 0.87)
	_arrow_r = Vector2(_cx + _half - 26.0 * u, _py0 + _ph * 0.87)

	var appear := UiKit.ease_out(clampf((_t - 0.65) / 0.4, 0.0, 1.0))
	var bw := minf(w * 0.56, 230.0 * u)
	var bh := 56.0 * u
	_go.size = Vector2(bw, bh)
	_go.position = Vector2((w - bw) / 2.0, _py0 + _ph + 46.0 * u + 14.0 * u * (1.0 - appear))
	_go.font_size = maxi(1, int(22.0 * u))
	var locked_sel := n > 0 and _locked(_sel())
	_go.modulate.a = appear * (0.4 if locked_sel else 1.0)
	_back.size = Vector2(46.0, 46.0) * u
	_back.position = Vector2(14.0, 14.0) * u
	_back.modulate.a = appear


func _smooth(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _hash(k: int) -> float:
	var v := sin(float(k) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


# --- Géométrie du rouleau ----------------------------------------------------------

## Abscisse à l'écran d'une position du papier (en indice de monde).
func _sx(f: float) -> float:
	return _cx + (f - _scroll) * _step


func _f_at(x: float) -> float:
	return (x - _cx) / maxf(_step, 1.0) + _scroll


func _anchor(i: int) -> Vector2:
	return Vector2(_sx(float(i)), _py0 + _ph * 0.38)


## Profil d'un plan (fraction de la hauteur du papier) propre au monde i, à la position f.
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
	return 0.5


## Mélange doux entre les deux mondes voisins de f.
func _height(far: bool, f: float) -> float:
	var n := _worlds.size()
	var ff := clampf(f, 0.0, float(n - 1))
	var i0 := int(floorf(ff))
	var i1 := mini(i0 + 1, n - 1)
	var s := _smooth(ff - float(i0))
	return lerpf(_prof(far, i0, f), _prof(far, i1, f), s)


func _mix(arr: Array, f: float) -> Color:
	var n := _worlds.size()
	var ff := clampf(f, 0.0, float(n - 1))
	var i0 := int(floorf(ff))
	var i1 := mini(i0 + 1, n - 1)
	var c0: Color = arr[_pal(i0)]
	var c1: Color = arr[_pal(i1)]
	return c0.lerp(c1, _smooth(ff - float(i0)))


func _ground_y(x: float) -> float:
	return _py0 + _height(false, _f_at(x)) * _ph


func _far_y(x: float) -> float:
	return _py0 + _height(true, _f_at(x)) * _ph


func _make_fibers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for k in 150:
		var f := rng.randf_range(-1.6, 6.6)
		var y := rng.randf()
		var ang := rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
		var ln := rng.randf_range(6.0, 26.0)
		var al := rng.randf_range(0.03, 0.08)
		var light := rng.randf() < 0.35
		_fibers.append([f, y, ang, ln, al, light])


# --- Dessin : fond, titre, repères -------------------------------------------------

func _draw() -> void:
	if size.x < 10.0:
		return
	var w := size.x
	var h := size.y
	var u := _u
	var a := UiKit.ease_out(clampf(_t / 0.25, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.WASHI, a))
	var wash := Color(Toon.SUMI, 0.035 * a)
	draw_circle(Vector2(w * 0.12, h * 0.9), 170.0 * u, wash)
	draw_circle(Vector2(w * 0.92, h * 0.08), 120.0 * u, wash)

	# ombre portée du rouleau
	if _half > 1.0:
		_box.set_border_width_all(0)
		_box.set_corner_radius_all(int(12.0 * u))
		_box.bg_color = Color(Toon.SUMI, 0.16 * a)
		draw_style_box(_box, Rect2(_cx - _half - 14.0 * u, _py0 + 10.0 * u, _half * 2.0 + 28.0 * u, _ph + 8.0 * u))

	# titre et petit sceau 道
	var ta := UiKit.ease_out(clampf((_t - 0.15) / 0.4, 0.0, 1.0))
	var tfs := maxi(1, int(32.0 * u))
	var title_txt := "Les Mondes"
	var tw := _title.get_string_size(title_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var ss := 26.0 * u
	var x0 := (w - tw - 10.0 * u - ss) / 2.0
	var ty := _py0 - 50.0 * u - 6.0 * u * (1.0 - ta)
	draw_string(_title, Vector2(x0, ty), title_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(Toon.SUMI, ta))
	var seal := Rect2(Vector2(x0 + tw + 10.0 * u, ty - 27.0 * u), Vector2(ss, ss))
	_box.set_corner_radius_all(int(4.0 * u))
	_box.bg_color = Color(Toon.VERMILION, ta)
	draw_style_box(_box, seal)
	_centered(self, UiKit.TITLE_FONT, "道", Vector2(seal.get_center().x, seal.get_center().y + 6.5 * u), maxi(1, int(18.0 * u)), Color(Toon.WASHI, ta))
	_centered(self, _ui, "GLISSE POUR DÉROULER LE ROULEAU", Vector2(w / 2.0, _py0 - 26.0 * u), maxi(1, int(11.0 * u)), Color(Toon.SUMI, 0.5 * ta))

	var n := _worlds.size()
	if n == 0:
		return
	# repères de position : un losange par monde, une goutte d'encre qui suit le rouleau
	var ra := UiKit.ease_out(clampf((_t - 0.7) / 0.4, 0.0, 1.0))
	var dy := _py0 + _ph + 24.0 * u
	var gap := 18.0 * u
	for i in n:
		var c := Vector2(_cx + (float(i) - float(n - 1) / 2.0) * gap, dy)
		if _locked(i):
			_diamond(self, c, 3.0 * u, Color(Toon.SUMI, 0.25 * ra), false)
		elif _won(i):
			_diamond(self, c, 4.5 * u, Color(Toon.GOLD, ra), true)
		else:
			_diamond(self, c, 4.0 * u, Color(Toon.SUMI, 0.7 * ra), false)
	var mc := Vector2(_cx + (clampf(_scroll, 0.0, float(n - 1)) - float(n - 1) / 2.0) * gap, dy)
	_diamond(self, mc, 5.5 * u, Color(Toon.SUMI, ra), true)

	# indication sous PARTIR pour un monde verrouillé
	var i_sel := _sel()
	if _locked(i_sel):
		var hy := _go.position.y + _go.size.y + 24.0 * u
		var hx := w / 2.0 + sin(_deny * 30.0) * 5.0 * u * _deny
		var hc := Color(Toon.SUMI, 0.6 * ra).lerp(Color(Toon.VERMILION, ra), _deny)
		_centered(self, _ui, "VAINCS LE MONDE %d POUR AVANCER" % _unlocked, Vector2(hx, hy), maxi(1, int(12.0 * u)), hc)


# --- Dessin : baguettes et flèches (par-dessus le papier) ---------------------------

func _draw_front() -> void:
	if size.x < 10.0 or _half < 0.5:
		return
	var u := _u
	var rw := 16.0 * u
	_rod(_front, _cx - _half - rw * 0.3, -1.0)
	_rod(_front, _cx + _half + rw * 0.3, 1.0)
	if _show_l:
		_arrow(_front, _arrow_l, -1.0, _ready_k)
	if _show_r:
		_arrow(_front, _arrow_r, 1.0, _ready_k)


## Baguette de bois (jiku) avec le papier encore enroulé autour et ses embouts.
func _rod(ci: Control, x: float, sgn: float) -> void:
	var u := _u
	var rw := 16.0 * u
	var top := _py0 - 12.0 * u
	var bot := _py0 + _ph + 12.0 * u
	# papier encore roulé : plus épais tant que le rouleau n'est pas ouvert
	var bulk := (4.0 + 10.0 * (1.0 - _unroll)) * u
	_box.bg_color = Toon.PAPER.darkened(0.07)
	_box.border_color = Color(Toon.SUMI, 0.3)
	_box.set_border_width_all(maxi(1, int(1.0 * u)))
	_box.set_corner_radius_all(maxi(1, int(bulk * 0.8)))
	ci.draw_style_box(_box, Rect2(x - rw * 0.5 - bulk, _py0 - 2.0 * u, rw + bulk * 2.0, _ph + 4.0 * u))
	_box.set_border_width_all(0)

	# corps cylindrique : dégradé sombre / clair / sombre
	var dark: Color = Toon.WOOD.darkened(0.38)
	var light: Color = Toon.WOOD.lightened(0.25)
	var xl := x - rw * 0.5
	var xm := x - rw * 0.12
	var xr := x + rw * 0.5
	ci.draw_polygon(PackedVector2Array([Vector2(xl, top), Vector2(xm, top), Vector2(xm, bot), Vector2(xl, bot)]),
		PackedColorArray([dark, light, light, dark]))
	ci.draw_polygon(PackedVector2Array([Vector2(xm, top), Vector2(xr, top), Vector2(xr, bot), Vector2(xm, bot)]),
		PackedColorArray([light, dark, dark, light]))
	# veines du bois qui tournent quand le papier défile
	var phase := (_scroll * _step * 0.6 + _half * sgn) / maxf(u, 0.01)
	for k in 3:
		var gx := fposmod(phase * 0.35 + float(k) * 5.3, 16.0) / 16.0
		var px := xl + rw * (0.12 + 0.76 * gx)
		ci.draw_line(Vector2(px, top + 4.0 * u), Vector2(px, bot - 4.0 * u), Color(dark, 0.35), maxf(1.0, 0.9 * u))
	# embouts sumi cerclés d'or
	_box.bg_color = Toon.SUMI
	_box.set_corner_radius_all(maxi(1, int(4.0 * u)))
	for yy in [top - 11.0 * u, bot - 1.0 * u]:
		var cy: float = yy
		var cap := Rect2(x - rw * 0.75, cy, rw * 1.5, 12.0 * u)
		ci.draw_style_box(_box, cap)
		ci.draw_line(Vector2(cap.position.x + 2.0 * u, cap.get_center().y), Vector2(cap.end.x - 2.0 * u, cap.get_center().y), Toon.GOLD, maxf(1.0, 1.5 * u))


## Flèche dessinée : rond de papier et chevron d'encre.
func _arrow(ci: Control, c: Vector2, dir: float, a: float) -> void:
	var u := _u
	var r := 17.0 * u
	ci.draw_circle(c + Vector2(0, 3.0 * u), r, Color(Toon.SUMI, 0.18 * a))
	ci.draw_circle(c, r, Color(Toon.WASHI, 0.92 * a))
	ci.draw_arc(c, r - 1.0 * u, 0.0, TAU, 32, Color(Toon.SUMI, 0.85 * a), 2.0 * u, true)
	var bob := sin(_t * 4.0) * 1.5 * u
	var pts := PackedVector2Array([
		c + Vector2(-dir * 4.0 * u + dir * bob, -7.0 * u),
		c + Vector2(dir * 5.0 * u + dir * bob, 0.0),
		c + Vector2(-dir * 4.0 * u + dir * bob, 7.0 * u)])
	ci.draw_polyline(pts, Color(Toon.SUMI, a), 3.0 * u, true)


# --- Dessin : le papier peint ---------------------------------------------------------

func _draw_paper() -> void:
	var ci: Control = _paper
	if _half < 0.5 or size.x < 10.0:
		return
	# on dessine en coordonnées de l'écran ; le Control découpe à la largeur déroulée
	ci.draw_set_transform(-_paper.position, 0.0, Vector2.ONE)
	var u := _u
	var x0 := _cx - _half
	var x1 := _cx + _half
	var top := _py0
	var bot := _py0 + _ph
	ci.draw_rect(Rect2(x0, top, x1 - x0, _ph), Toon.PAPER)
	var n := _worlds.size()
	if n == 0:
		return

	var xs := PackedFloat32Array()
	var stp := 7.0 * u
	var x := x0 - stp
	while x < x1 + stp:
		xs.append(x)
		x += stp
	xs.append(x)

	# ciel : lavis qui s'efface vers le bas
	for k in range(1, xs.size()):
		var xa: float = xs[k - 1]
		var xb: float = xs[k]
		var ca := _mix(SKY, _f_at(xa))
		var cb := _mix(SKY, _f_at(xb))
		ci.draw_polygon(PackedVector2Array([Vector2(xa, top), Vector2(xb, top), Vector2(xb, top + _ph * 0.55), Vector2(xa, top + _ph * 0.55)]),
			PackedColorArray([Color(ca, 0.75), Color(cb, 0.75), Color(cb, 0.0), Color(ca, 0.0)]))

	# fibres du washi
	for fb in _fibers:
		var arr: Array = fb
		var ff: float = arr[0]
		var fx := _sx(ff)
		if fx < x0 - 30.0 * u or fx > x1 + 30.0 * u:
			continue
		var p0 := Vector2(fx, top + float(arr[1]) * _ph)
		var dirv := Vector2.from_angle(float(arr[2])) * float(arr[3]) * u
		var light: bool = arr[5]
		var fc := Color(1, 1, 1, float(arr[4]) * 5.0) if light else Color(Toon.SUMI, float(arr[4]))
		ci.draw_line(p0, p0 + dirv, fc, maxf(1.0, u), true)

	var visible_i: Array = []
	for i in n:
		if absf(_sx(float(i)) - _cx) < _half + _step:
			visible_i.append(i)

	_strip(ci, xs, true)
	for vi in visible_i:
		var i: int = vi
		_motif_back(ci, i, _sx(float(i)))
	_strip(ci, xs, false)
	for vi in visible_i:
		var i: int = vi
		_motif_front(ci, i, _sx(float(i)))

	_path(ci, x0, x1)

	# étapes : la sélectionnée en dernier, par-dessus ses voisines
	_station_rects.clear()
	for i in n:
		_station_rects.append(Rect2())
	var sel := _sel()
	for vi in visible_i:
		var i: int = vi
		if i != sel:
			_station(ci, i)
	if visible_i.has(sel):
		_station(ci, sel)

	# montage du rouleau : bandes de brocart en haut et en bas
	var band := 7.0 * u
	ci.draw_rect(Rect2(x0, top, x1 - x0, band), Color(Toon.PRUSSIAN, 0.9))
	ci.draw_rect(Rect2(x0, bot - band, x1 - x0, band), Color(Toon.PRUSSIAN, 0.9))
	ci.draw_line(Vector2(x0, top + band + 1.0 * u), Vector2(x1, top + band + 1.0 * u), Color(Toon.GOLD, 0.9), maxf(1.0, 1.5 * u))
	ci.draw_line(Vector2(x0, bot - band - 1.0 * u), Vector2(x1, bot - band - 1.0 * u), Color(Toon.GOLD, 0.9), maxf(1.0, 1.5 * u))
	var gx := fposmod(-_scroll * _step, 14.0 * u)
	var mx := x0 - 14.0 * u + gx
	while mx < x1 + 14.0 * u:
		ci.draw_circle(Vector2(mx, top + band * 0.5), 1.3 * u, Color(Toon.GOLD, 0.8))
		ci.draw_circle(Vector2(mx + 7.0 * u, bot - band * 0.5), 1.3 * u, Color(Toon.GOLD, 0.8))
		mx += 14.0 * u

	# le papier s'assombrit en s'enroulant près des baguettes
	var sh := 20.0 * u
	var dk := Color(Toon.SUMI, 0.2)
	var clr := Color(Toon.SUMI, 0.0)
	ci.draw_polygon(PackedVector2Array([Vector2(x0, top), Vector2(x0 + sh, top), Vector2(x0 + sh, bot), Vector2(x0, bot)]),
		PackedColorArray([dk, clr, clr, dk]))
	ci.draw_polygon(PackedVector2Array([Vector2(x1 - sh, top), Vector2(x1, top), Vector2(x1, bot), Vector2(x1 - sh, bot)]),
		PackedColorArray([clr, dk, dk, clr]))


## Un plan du paysage (lointain ou proche), en bandes verticales qui fondent les couleurs des mondes.
func _strip(ci: Control, xs: PackedFloat32Array, far: bool) -> void:
	var u := _u
	var bot := _py0 + _ph
	var cols: Array = FAR if far else NEAR
	var alpha := 0.55 if far else 0.88
	var ridge := PackedVector2Array()
	for k in xs.size():
		var xk: float = xs[k]
		var yk := _far_y(xk) if far else _ground_y(xk)
		ridge.append(Vector2(xk, yk))
	for k in range(1, xs.size()):
		var pa: Vector2 = ridge[k - 1]
		var pb: Vector2 = ridge[k]
		var ca := Color(_mix(cols, _f_at(pa.x)), alpha)
		var cb := Color(_mix(cols, _f_at(pb.x)), alpha)
		ci.draw_polygon(PackedVector2Array([pa, pb, Vector2(pb.x, bot), Vector2(pa.x, bot)]), PackedColorArray([ca, cb, cb, ca]))
	# trait d'encre sur la crête
	if far:
		ci.draw_polyline(ridge, Color(Toon.SUMI, 0.18), maxf(1.0, 1.2 * u), true)
	else:
		ci.draw_polyline(ridge, Color(Toon.SUMI, 0.42), 2.0 * u, true)


# --- Motifs de chaque monde -----------------------------------------------------------

## Motifs d'arrière-plan (entre le plan lointain et le premier plan).
func _motif_back(ci: Control, i: int, sx: float) -> void:
	var u := _u
	var top := _py0
	var s := _step
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
			var summit := _py0 + _ph * 0.19
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


## Motifs de premier plan (devant le sol, derrière le chemin et les étapes).
func _motif_front(ci: Control, i: int, sx: float) -> void:
	var u := _u
	var top := _py0
	var bot := _py0 + _ph
	var s := _step
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


func _torch(ci: Control, base: Vector2, s: float, k: int) -> void:
	ci.draw_line(base, base + Vector2(0, -38.0 * s), Color(Toon.SUMI, 0.85), 3.5 * s, true)
	var c := base + Vector2(0, -44.0 * s)
	var fl := 1.0 + 0.15 * sin(_t * 11.0 + float(k) * 2.0)
	ci.draw_circle(c, 13.0 * s, Color(Toon.GOLD, 0.15))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14.0 * s * fl), c + Vector2(6.0 * s, -2.0 * s), c + Vector2(4.0 * s, 5.0 * s),
		c + Vector2(-4.0 * s, 5.0 * s), c + Vector2(-6.0 * s, -2.0 * s)]), Color(Color("#E39B3B"), 0.92))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7.0 * s * fl), c + Vector2(3.0 * s, 0.0), c + Vector2(0, 4.0 * s),
		c + Vector2(-3.0 * s, 0.0)]), Color(Color("#F4D58A"), 0.95))


# --- Chemin et étapes ----------------------------------------------------------------

## Chemin d'encre en pointillés qui relie les sceaux en ondulant (plus pâle vers les mondes scellés).
func _path(ci: Control, x0: float, x1: float) -> void:
	var u := _u
	var n := _worlds.size()
	for i in n - 1:
		var a := _anchor(i)
		var b := _anchor(i + 1)
		if b.x < x0 - 20.0 * u or a.x > x1 + 20.0 * u:
			continue
		var open_seg := not _locked(i + 1)
		var col := Color(Toon.SUMI, 0.75 if open_seg else 0.28)
		var wav := _ph * 0.035 * (1.0 if i % 2 == 0 else -1.0)
		var segs := 30
		for k in segs:
			if k % 2 == 1:
				continue
			var t0 := float(k) / float(segs)
			var t1 := float(k + 1) / float(segs)
			var p0 := a.lerp(b, t0) + Vector2(0, sin(t0 * TAU) * wav)
			var p1 := a.lerp(b, t1) + Vector2(0, sin(t1 * TAU) * wav)
			ci.draw_line(p0, p1, col, 3.0 * u, true)


## Une étape : sceau rond à l'idéogramme du monde et cartouche (nom, sous-titre, chemin des salles, record).
## Loin du centre, la cartouche se resserre et reste épinglée au bord du papier pour rester lisible.
func _station(ci: Control, i: int) -> void:
	var u := _u
	var d: Dictionary = _worlds[i]
	var dd := float(i) - _scroll
	var focus := _smooth(1.0 - absf(dd))
	var sc := 0.88 + 0.27 * focus
	var p := _anchor(i)
	if i == _sel() and _deny > 0.0:
		p.x += sin(_deny * 30.0) * 6.0 * u * _deny
	var r := 42.0 * u * sc
	var locked := _locked(i)
	var won := _won(i)
	var b := _rooms if won else _best_of(i)
	var fresh := not locked and not won and b == 0
	var col: Color = d.get("color", Color(0.5, 0.5, 0.5))
	var kanji := str(d.get("kanji", "道"))
	var wname := UiKit.plain(str(d.get("name", "")))
	var sub := UiKit.plain(str(d.get("subtitle", "")))
	var a_full := _smooth((focus - 0.3) / 0.45)  # cartouche complète (monde centré)
	var a_comp := 1.0 - a_full  # cartouche resserrée (voisins)
	var gold_ink: Color = Toon.GOLD.darkened(0.3)

	# ensō qui tourne autour du monde centré (doré s'il est accompli)
	if focus > 0.05:
		var st := -PI * 0.5 + 0.4 + _t * 0.35
		var ring := r + 8.0 * u * sc
		var ec: Color = Toon.GOLD if won else Toon.SUMI
		ci.draw_arc(p, ring, st, st + TAU - 0.55, 56, Color(ec, 0.85 * focus), 3.2 * u, true)
		ci.draw_arc(p, ring + 2.0 * u, st + 0.6, st + TAU - 1.4, 48, Color(ec, 0.35 * focus), 1.5 * u, true)

	# sceau
	ci.draw_circle(p + Vector2(0, 4.0 * u * sc), r, Color(Toon.SUMI, 0.22))
	var fill := Color(0.66, 0.64, 0.6) if locked else col
	ci.draw_circle(p, r, fill)
	if won:
		# anneau entièrement doré
		ci.draw_arc(p, r * 0.84, 0.0, TAU, 48, Color(Toon.GOLD, 0.9), maxf(1.0, 2.0 * u * sc), true)
		ci.draw_arc(p, r - 2.5 * u * sc, 0.0, TAU, 56, Toon.GOLD, 5.0 * u * sc, true)
		ci.draw_arc(p, r, 0.0, TAU, 56, Color(Toon.SUMI, 0.85), maxf(1.0, 1.5 * u * sc), true)
	else:
		ci.draw_arc(p, r * 0.84, 0.0, TAU, 48, Color(Toon.WASHI, 0.4 if locked else 0.55), maxf(1.0, 1.5 * u * sc), true)
		ci.draw_arc(p, r - 1.0 * u, 0.0, TAU, 56, Color(Toon.SUMI, 0.9), 3.0 * u * sc, true)
		if b > 0 and not locked:
			# avancée dorée sur l'anneau, depuis le haut
			var frac := float(b) / float(_rooms)
			ci.draw_arc(p, r - 1.0 * u, -PI * 0.5, -PI * 0.5 + TAU * frac, maxi(4, int(56.0 * frac)), Toon.GOLD, 3.0 * u * sc, true)
	var kfs := maxi(1, int(r * 1.05))
	var asc := UiKit.TITLE_FONT.get_ascent(kfs)
	var desc := UiKit.TITLE_FONT.get_descent(kfs)
	_centered(ci, UiKit.TITLE_FONT, kanji, Vector2(p.x, p.y + (asc - desc) / 2.0), kfs, Color(Toon.WASHI, 0.55 if locked else 1.0))
	if locked:
		_barred_seal(ci, p + Vector2(-r * 0.74, -r * 0.74), 20.0 * u * sc)
		_lock_icon(ci, p + Vector2(r * 0.6, r * 0.55), 14.0 * u * sc)

	# numéro du monde au-dessus du sceau
	var mc := Color(Toon.SUMI, 0.4 if locked else 0.6)
	if won:
		mc = gold_ink
	_centered(ci, _ui, "MONDE %d" % _id(i), Vector2(p.x, p.y - r - 16.0 * u * sc), maxi(1, int(10.0 * u * sc)), mc)

	# cartouche : sa largeur passe de la version resserrée à la complète
	var nfs := maxi(1, int(18.0 * u * sc))
	var sfs := maxi(1, int(10.5 * u * sc))
	var rfs := maxi(1, int(11.0 * u * sc))
	var nw := _title.get_string_size(wname, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var path_min := 0.0 if locked else 9.0 * u * sc * float(_rooms)
	var cw_full := clampf(maxf(nw, path_min) + 24.0 * u * sc, 120.0 * u * sc, _step * 0.86)
	var cw := lerpf(74.0 * u, cw_full, a_full)
	var ctop := p.y + r + 10.0 * u * sc
	var y_name := ctop + 8.0 * u * sc + float(nfs) * 0.85
	var y_sub := y_name + float(sfs) + 5.0 * u * sc
	var y_path := y_sub + 13.0 * u * sc
	var y_rec := y_path + 9.0 * u * sc + float(rfs) * 0.85
	var cbot := y_rec + 8.0 * u * sc
	# épinglée au bord du papier tant que le monde est voisin du centre
	var pin := 1.0 - _smooth((absf(dd) - 1.0) * 2.0)
	var lim_l := _cx - _half + cw / 2.0 + 6.0 * u
	var lim_r := _cx + _half - cw / 2.0 - 6.0 * u
	var kx := p.x
	if lim_l < lim_r:
		kx = clampf(p.x, lim_l, lim_r)
	var card_x := lerpf(p.x, kx, pin)
	var cr := Rect2(card_x - cw / 2.0, ctop, cw, cbot - ctop)
	var rad := maxi(1, int(6.0 * u * sc))
	UiKit.box(_box, Color(Toon.SUMI, 0.15), rad)
	ci.draw_style_box(_box, Rect2(cr.position + Vector2(0, 4.0 * u * sc), cr.size))
	var frame := Color(Toon.SUMI, 0.4 if locked else 0.8)
	var bw := maxi(1, int(2.0 * u * sc))
	var bg := Color(Toon.PAPER, 0.95)
	if won:
		frame = Toon.GOLD
		bw = maxi(2, int(3.5 * u * sc))
		bg = Color(Toon.PAPER.lerp(Toon.GOLD, 0.1), 0.97)
	elif fresh:
		frame = Color(Toon.SUMI, 0.5)
	UiKit.box(_box, bg, rad, frame, bw)
	ci.draw_style_box(_box, cr)
	_box.set_border_width_all(0)
	if won:
		# second filet d'or, fin, à l'intérieur du cadre
		ci.draw_rect(cr.grow(-5.0 * u * sc), Color(Toon.GOLD, 0.75), false, maxf(1.0, 1.0 * u * sc))
	# petite bande à la couleur du monde sur le bord gauche
	ci.draw_rect(Rect2(cr.position.x + 7.0 * u * sc, cr.position.y + 8.0 * u * sc, 3.0 * u * sc, cr.size.y - 16.0 * u * sc),
		Color(fill, 0.9))

	# version complète
	if a_full > 0.01:
		var inner := cw - 18.0 * u * sc
		var cx := card_x + 2.0 * u * sc
		_centered_fit(ci, _title, wname, Vector2(cx, y_name), nfs, inner, Color(Toon.SUMI, (0.45 if locked else 1.0) * a_full))
		_centered_fit(ci, _ui, sub, Vector2(cx, y_sub), sfs, inner, Color(Toon.SUMI, (0.4 if locked else 0.65) * a_full))
		if locked:
			var lw := _centered(ci, _ui, "VERROUILLÉ", Vector2(cx + 7.0 * u * sc, y_path + float(rfs) * 0.35), rfs, Color(Toon.SUMI, 0.5 * a_full))
			if a_full > 0.5:
				_lock_icon(ci, Vector2(cx + 7.0 * u * sc - lw / 2.0 - 9.0 * u * sc, y_path - 1.0 * u * sc), 8.0 * u * sc)
			if _id(i) > 1:
				_centered_fit(ci, _ui, "Vaincs le monde %d pour l'ouvrir" % (_id(i) - 1), Vector2(cx, y_rec), rfs, inner,
					Color(Toon.VERMILION, 0.85 * a_full))
		else:
			_progress_path(ci, cx - inner / 2.0 + 5.0 * u * sc, cx + inner / 2.0 - 5.0 * u * sc, y_path, b, won, _mini_done(i), col, sc, a_full)
			var rec := "Record : étape %d" % b
			var rc := Color(Toon.SUMI, 0.8)
			if won:
				rec = "Boss vaincu - %d/%d étapes" % [_rooms, _rooms]
				rc = gold_ink
			elif fresh:
				rec = "Jamais exploré"
				rc = Color(Toon.SUMI, 0.45)
			_centered_fit(ci, _ui, rec, Vector2(cx, y_rec), rfs, inner, Color(rc, rc.a * a_full))

	# version resserrée : nom sur deux lignes au besoin, état en un mot
	if a_comp > 0.01:
		var avail := cw - 16.0 * u
		var cx2 := card_x + 2.0 * u
		var ch := cr.size.y
		_name_lines(ci, wname, cx2, ctop + ch * 0.33, maxi(1, int(float(nfs) * 0.9)), avail, Color(Toon.SUMI, (0.45 if locked else 1.0) * a_comp))
		var st_txt := "ÉTAPE %d/%d" % [b, _rooms]
		var st_col := Color(Toon.SUMI, 0.75)
		if locked:
			st_txt = "VERROUILLÉ"
			st_col = Color(Toon.SUMI, 0.45)
		elif won:
			st_txt = "ACCOMPLI"
			st_col = gold_ink
		elif fresh:
			st_txt = "INEXPLORÉ"
			st_col = Color(Toon.SUMI, 0.5)
		var sy := ctop + ch * 0.8
		var mark := 0.0
		if won or locked:
			mark = 11.0 * u
		var sfs2 := _fit_size(_ui, st_txt, rfs, avail - mark)
		var stw := _ui.get_string_size(st_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs2).x
		_centered(ci, _ui, st_txt, Vector2(cx2 + mark / 2.0, sy), sfs2, Color(st_col, st_col.a * a_comp))
		var mpos := Vector2(cx2 + mark / 2.0 - stw / 2.0 - 6.0 * u, sy - float(sfs2) * 0.35)
		if won:
			_check_mark(ci, mpos, 8.0 * u, Color(gold_ink, a_comp))
		elif locked and a_comp > 0.5:
			_lock_icon(ci, mpos, 7.0 * u)

	# étiquette « Nouveau » sur le coin d'un monde jamais exploré
	if fresh:
		_new_tag(ci, Vector2(cr.end.x - 5.0 * u * sc, cr.position.y), sc)

	# grand sceau ACCOMPLI pressé en biais sur le médaillon
	if won:
		var e := _stamp_elapsed(_id(i), focus)
		if e >= 0.0:
			_stamp(ci, p + Vector2(r * 0.05, r * 0.15), r, e)

	var hit_top := p.y - r - 28.0 * u
	_station_rects[i] = Rect2(p.x - r, hit_top, r * 2.0, cbot - hit_top).merge(cr)


## Chemin des salles : trait de pinceau et nœuds, plein jusqu'au record ; gardien et boss plus gros, avec icône.
func _progress_path(ci: Control, xa: float, xb: float, y: float, b: int, won: bool, mini_done: bool, col: Color, sc: float, a: float) -> void:
	var u := _u
	var n := _rooms
	var fillc: Color = Toon.GOLD if won else col
	var pts := PackedVector2Array()
	for k in n:
		var t := 0.0 if n <= 1 else float(k) / float(n - 1)
		pts.append(Vector2(lerpf(xa, xb, t), y + sin(float(k) * 1.9 + 0.7) * 1.3 * u * sc))
	# trait : épais et franc jusqu'au record, fin et pâle ensuite
	for k in range(1, n):
		var wdt := 1.3 * u * sc
		var c := Color(Toon.SUMI, 0.3 * a)
		if k < b:
			wdt = (3.4 - 1.2 * float(k) / float(n)) * u * sc
			c = Color(fillc, a)
		ci.draw_line(pts[k - 1], pts[k], c, maxf(1.0, wdt), true)
	for k in n:
		var room := k + 1
		var is_boss := room == n
		var is_mini := room == MINI_ROOM and room < n
		var reached := k < b
		var q: Vector2 = pts[k]
		if is_boss or is_mini:
			var nr := 4.2 * u * sc
			var beaten := won if is_boss else mini_done
			var nb := Color(Toon.PAPER, a)
			if beaten:
				nb = Color(fillc, a)
			elif reached:
				nb = Color(Toon.VERMILION.lerp(Toon.PAPER, 0.55), a)  # atteint, pas encore vaincu
			ci.draw_circle(q, nr + 1.2 * u * sc, Color(Toon.SUMI, 0.85 * a))
			ci.draw_circle(q, nr, nb)
			var ic := Color(Toon.WASHI, a) if beaten else Color(Toon.SUMI, 0.7 * a)
			if is_boss:
				_crown(ci, q + Vector2(0, 0.4 * u * sc), nr * 0.62, ic)
			else:
				_horns(ci, q, nr * 0.62, ic)
		elif reached:
			ci.draw_circle(q, 2.3 * u * sc, Color(fillc, a))
		else:
			ci.draw_circle(q, 2.1 * u * sc, Color(Toon.PAPER, a))
			ci.draw_arc(q, 2.1 * u * sc, 0.0, TAU, 10, Color(Toon.SUMI, 0.35 * a), maxf(1.0, 0.9 * u), true)


## Couronne (boss), centrée en c.
func _crown(ci: Control, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, 0.55) * s, c + Vector2(-0.9, -0.5) * s, c + Vector2(-0.4, 0.0) * s,
		c + Vector2(0.0, -0.75) * s, c + Vector2(0.4, 0.0) * s, c + Vector2(0.9, -0.5) * s, c + Vector2(0.8, 0.55) * s]), col)


## Cornes d'oni (gardien) : deux pointes et un œil.
func _horns(ci: Control, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, 0.25) * s, c + Vector2(-0.65, -0.85) * s, c + Vector2(-0.15, 0.0) * s]), col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.15, 0.0) * s, c + Vector2(0.65, -0.85) * s, c + Vector2(0.8, 0.25) * s]), col)
	ci.draw_circle(c + Vector2(0, 0.5) * s, 0.28 * s, col)


func _check_mark(ci: Control, c: Vector2, s: float, col: Color) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-0.5, 0.0) * s, c + Vector2(-0.12, 0.4) * s, c + Vector2(0.55, -0.45) * s]),
		col, maxf(1.5, s * 0.22), true)


## Étiquette vermillon « NOUVEAU » accrochée au coin haut-droit (right_top) de la cartouche.
func _new_tag(ci: Control, right_top: Vector2, sc: float) -> void:
	var u := _u
	var fs := maxi(1, int(8.5 * u * sc))
	var tw := _ui.get_string_size("NOUVEAU", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tag := Rect2(right_top.x - tw - 10.0 * u * sc, right_top.y - 7.0 * u * sc, tw + 10.0 * u * sc, float(fs) + 6.0 * u * sc)
	UiKit.box(_box, Toon.VERMILION, maxi(1, int(3.0 * u * sc)))
	ci.draw_style_box(_box, tag)
	_centered(ci, _ui, "NOUVEAU", Vector2(tag.get_center().x, tag.get_center().y + float(fs) * 0.36), fs, Toon.WASHI)


## Nom en une ligne, ou en deux (coupé au blanc le plus proche du milieu) s'il ne tient pas.
func _name_lines(ci: Control, txt: String, x: float, y: float, fs: int, max_w: float, c: Color) -> void:
	var tw := _title.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sp := txt.find(" ")
	if tw <= max_w or sp < 0:
		_centered_fit(ci, _title, txt, Vector2(x, y + float(fs) * 0.45), fs, max_w, c)
		return
	var mid := int(float(txt.length()) / 2.0)
	var cut := sp
	while sp >= 0:
		if absi(sp - mid) < absi(cut - mid):
			cut = sp
		sp = txt.find(" ", sp + 1)
	var l1 := txt.substr(0, cut)
	var l2 := txt.substr(cut + 1)
	var fs2 := mini(_fit_size(_title, l1, fs, max_w), _fit_size(_title, l2, fs, max_w))
	_centered(ci, _title, l1, Vector2(x, y), fs2, c)
	_centered(ci, _title, l2, Vector2(x, y + float(fs2) + 1.0 * _u), fs2, c)


## Secondes écoulées depuis que le sceau ACCOMPLI de ce monde a frappé (< 0 : pas encore).
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


## Hanko vermillon cerclé d'or « ACCOMPLI » avec une couronne, posé en biais ; e = secondes depuis la frappe.
func _stamp(ci: Control, c: Vector2, r: float, e: float) -> void:
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
				var dist := r * (1.0 + 0.5 * sp) * (0.9 + 0.3 * _hash(q * 3 + 1))
				ci.draw_circle(c + Vector2(cos(ang) * dist * 1.25, sin(ang) * dist * 0.75), (2.5 - 1.5 * sp) * u,
					Color(Toon.VERMILION, 0.8 * (1.0 - sp)))
	var base := Vector2.ZERO
	if ci == _paper:
		base = -_paper.position
	ci.draw_set_transform(base + c, -0.3, Vector2(s, s))
	var w := r * 2.5
	var h := r * 0.8
	var rect := Rect2(-w / 2.0, -h / 2.0, w, h)
	var rad := maxi(1, int(h * 0.14))
	UiKit.box(_box, Color(Toon.SUMI, 0.25 * a), rad)
	ci.draw_style_box(_box, Rect2(rect.position + Vector2(2.0, 3.0) * u, rect.size))
	UiKit.box(_box, Color(Toon.VERMILION, 0.94 * a), rad, Color(Toon.GOLD, a), maxi(1, int(2.5 * u)))
	ci.draw_style_box(_box, rect)
	_box.set_border_width_all(0)
	ci.draw_rect(rect.grow(-4.5 * u), Color(Toon.WASHI, 0.75 * a), false, maxf(1.0, 1.2 * u))
	# couronne dans un rond washi
	var cc := Vector2(-w / 2.0 + h * 0.56, 0.0)
	var crr := h * 0.3
	ci.draw_circle(cc, crr, Color(Toon.WASHI, 0.95 * a))
	_crown(ci, cc + Vector2(0, 0.08 * crr), crr * 0.62, Color(Toon.VERMILION, a))
	# texte
	var tx0 := cc.x + crr + 4.0 * u
	var tx1 := w / 2.0 - 8.0 * u
	var fs := _fit_size(_title, "ACCOMPLI", maxi(1, int(h * 0.5)), tx1 - tx0)
	_centered(ci, _title, "ACCOMPLI", Vector2((tx0 + tx1) / 2.0, float(fs) * 0.36), fs, Color(Toon.WASHI, a))
	# grain du tampon
	for q in 14:
		var gp := Vector2((_hash(q * 5 + 2) - 0.5) * w * 0.92, (_hash(q * 9 + 4) - 0.5) * h * 0.85)
		ci.draw_circle(gp, (0.6 + _hash(q + 30)) * u, Color(Toon.VERMILION.lightened(0.35), 0.55 * a))
	ci.draw_set_transform(base, 0.0, Vector2.ONE)


## Sceau vermillon barré d'un trait d'encre (monde scellé).
func _barred_seal(ci: Control, c: Vector2, s: float) -> void:
	var r := Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s))
	ci.draw_rect(r, Toon.VERMILION)
	ci.draw_rect(r.grow(-s * 0.16), Color(Toon.WASHI, 0.75), false, maxf(1.0, s * 0.07))
	_centered(ci, UiKit.TITLE_FONT, "界", Vector2(c.x, c.y + s * 0.22), maxi(1, int(s * 0.58)), Color(Toon.WASHI, 0.9))
	ci.draw_line(c + Vector2(-s * 0.75, s * 0.6), c + Vector2(s * 0.75, -s * 0.6), Toon.SUMI, maxf(1.5, s * 0.16), true)


## Cadenas dessiné : anse et corps d'encre, trou de serrure washi.
func _lock_icon(ci: Control, c: Vector2, s: float) -> void:
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


func _diamond(ci: CanvasItem, c: Vector2, s: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	if filled:
		ci.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, col, maxf(1.0, 1.5 * _u), true)
