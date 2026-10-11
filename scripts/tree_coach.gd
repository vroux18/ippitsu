extends Control
## Tutoriel de l'Arbre du pinceau (une fois, meta.coach_seen["arbre"]) : au premier retour à l'accueil après une
## partie qui a vaincu le boss du monde 1 (ou, mort avant, dès que l'encre suffit pour un nœud), il montre où
## dépenser l'encre. Même langage que le coach en jeu (coach.gd) : voile d'encre percé d'un projecteur, bandeau
## sumi à sceau vermillon (titre court, une ligne), main fantôme qui tape sur la cible.
## 1. accueil : projecteur sur ATELIER ;  2. Atelier, onglet ARBRE : projecteur sur le nœud à apprendre (le moins
## cher à portée, celui que l'Atelier choisit d'office) ;  3. projecteur sur APPRENDRE ;  4. le jeton d'encre :
## « chaque partie rapporte de l'encre », qui part seul ou au toucher.
## Seule la cible répond (les autres touchers sont avalés) ; PASSER sous le bandeau ferme tout. Jamais bloquant :
## chaque étape a un garde-fou de temps, et le tutoriel s'efface si l'écran attendu n'est plus là.
## Robot et captures : jamais de lui-même (auto faux) ; `request()` le demande (bot_ui, `--q=tutoarbre`).
const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
const Coach = preload("res://scripts/coach.gd")
const Meta = preload("res://scripts/meta.gd")
const Menu = preload("res://scripts/menu.gd")

const ID := "arbre"  # clé de meta.coach_seen
const TEXTS := {
	1: ["L'Arbre du pinceau", "Dépense ton encre pour devenir plus fort."],
	2: ["Touche un sceau", "Il se décrit en bas de l'écran."],
	3: ["Apprends-le", "Il reste acquis pour toutes les parties."],
	4: ["Reviens ici", "Chaque partie rapporte de l'encre."],
}
const GLYPHS := {1: "at_brush", 2: "stamp", 3: "stamp", 4: "at_drop"}
const VEIL := 0.7
const STEP_MAX := 45.0  # garde-fou : une étape sans réponse ferme le tutoriel (s réelles)
const LAST_LIFE := 4.5  # bulle finale : part seule
const HARD_MS := 180000  # garde-fou absolu (horloge murale)

var main: Node
var auto := true  # déclenchement de lui-même (faux : robot, captures)
var hold := false  # captures : ni garde-fou de temps ni départ de la bulle finale
var dry := false  # captures : le drapeau n'est pas sauvegardé
var step := 0  # 0 : rien ; 1..4 : étape
var target := ""  # nœud montré (étapes 2 et 3)
var spot := Rect2()  # cible de l'étape (écran) : seule zone qui répond
var _want := 0  # étape demandée (request), en attente de son écran
var _t := 0.0  # temps réel depuis l'étape
var _ms := 0  # début (horloge murale)
var _ready_t := -1.0  # temps réel depuis que la cible est posée (-1 : pas encore)
var _skip_rect := Rect2()
var _eat := false  # avale les touchers jusqu'au relâché (tutoriel fermé sur un appui)
var _title := FontVariation.new()
var _sb := StyleBoxFlat.new()
var _shape := PackedVector2Array()
var _line := PackedVector2Array()
var _pts := PackedVector2Array()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.base_font = UiKit.TITLE_FONT
	# même coup de pinceau que le bandeau du coach (et celui du HUD)
	_shape.append(Vector2(6, 10))
	Coach._cubic(_shape, Vector2(6, 10), Vector2(40, 3), Vector2(120, 5), Vector2(222, 7), 8)
	_shape.append(Vector2(218, 16))
	_shape.append(Vector2(224, 22))
	Coach._cubic(_shape, Vector2(224, 22), Vector2(150, 34), Vector2(70, 34), Vector2(4, 30), 8)
	_shape.append(Vector2(10, 21))
	for i in _shape.size():
		_shape[i] = _shape[i] / Vector2(228.0, 38.0)
	_line.append(Vector2(30, 31))
	Coach._cubic(_line, Vector2(30, 31), Vector2(90, 35), Vector2(150, 34), Vector2(200, 30), 6)
	for i in _line.size():
		_line[i] = _line[i] / Vector2(228.0, 38.0)


# ------------------------------------------------------------------ déclenchement

func active() -> bool:
	return step > 0


## Le tutoriel est dû : jamais vu, rien d'appris, une partie jouée au moins, et le monde 1 vaincu ou assez
## d'encre pour le nœud le moins cher.
func due() -> bool:
	var m = main.meta
	if m == null or m.coach_seen.has(ID) or not m.tree.is_empty() or int(m.purse_rank) > 0 or int(m.runs) < 1:
		return false
	var c: int = m.cheapest_open_cost()
	return bool(m.world_cleared(1)) or (c >= 0 and int(m.sumi) >= c)


## Demande l'étape n (robot, captures) : elle vient dès que son écran est prêt, sans autre condition.
func request(n := 1) -> void:
	_want = clampi(n, 1, 4)


## Accueil posé, rien par-dessus (atelier, carte, options, intro, ouverture, garde-robe, départ, dojo).
func _home_idle() -> bool:
	if String(main.state) != "menu" or not main.menu.visible or String(main.menu.mode) != "home":
		return false
	if float(main.menu._t) < Menu.HOME_SETTLED + 0.2:
		return false
	for c in [main.refuge, main.worldmap, main.options, main.intro, main.opening, main.departure, main.recap]:
		if c != null and (c as CanvasItem).visible:
			return false
	if main.wardrobe != null and (main.wardrobe as CanvasItem).visible:
		return false
	return not (main.tuto != null and (main.tuto as CanvasItem).visible)


func _refuge_ready() -> bool:
	var ref = main.refuge
	return ref.visible and float(ref._t) >= 0.6 and int(ref._tab) == 0 and ref.node_center(Meta.TREE_ROOT) != Vector2.INF


func _begin(n: int) -> void:
	_ms = Time.get_ticks_msec()
	main.meta.coach_seen[ID] = true  # une seule fois, même si l'on quitte en route
	if not dry:
		main.meta.save_data()
	_go(n)


func _go(n: int) -> void:
	step = n
	_t = 0.0
	_ready_t = -1.0
	spot = Rect2()
	var ref = main.refuge
	match n:
		2:
			target = String(ref._default_node())
			ref.select_node(Meta.TREE_ROOT)  # onglet ARBRE, le tronc décrit : le toucher du nœud se voit
		3:
			if target == "" or not Meta.TREE.has(target):
				target = String(ref._default_node())
			ref.select_node(target)
	visible = true
	queue_redraw()


func _end() -> void:
	step = 0
	_want = 0
	spot = Rect2()
	visible = false


func _process(_delta: float) -> void:
	if main == null or main.meta == null:
		return
	if step == 0:
		if _want == 1 and _home_idle():
			_begin(1)
		elif _want >= 2 and _refuge_ready():
			_begin(_want)
		elif _want == 0 and auto and _home_idle() and due():
			_begin(1)
		if step == 0:
			return
		_want = 0
	size = get_viewport_rect().size
	var dt := UiKit.real_delta()
	_t += dt
	var ref = main.refuge
	match step:
		1:
			if ref.visible:
				_go(2)
			elif String(main.state) != "menu" or String(main.menu.mode) != "home" or not main.menu.visible:
				_end()
				return
			else:
				var b: Control = main.menu._atelier
				spot = b.get_global_rect()
		2:
			if not ref.visible:
				_end()
				return
			if _refuge_ready():
				spot = ref.hit_rect("node:" + target)
				if String(ref._tree_sel) == target and _ready_t >= 0.0:
					_go(3 if bool(main.meta.can_learn(target)) else 4)
		3:
			if not ref.visible:
				_end()
				return
			if bool(main.meta.learned(target)):
				_go(4)
			elif _refuge_ready():
				spot = ref.hit_rect("learn")
				if not spot.has_area() or String(ref._tree_sel) != target:
					ref.select_node(target)  # le joueur ne peut rien toucher d'autre ; par sûreté
		4:
			if not ref.visible:
				_end()
				return
			spot = ref.ink_chip_rect()
			if not hold and _t > LAST_LIFE:
				_end()
				return
	if step == 0:
		return
	if spot.has_area():
		if _ready_t < 0.0:
			_ready_t = 0.0
		else:
			_ready_t += dt
	if not hold and (_t > STEP_MAX or Time.get_ticks_msec() - _ms > HARD_MS):
		_end()
		return
	queue_redraw()


# ------------------------------------------------------------------ entrée

## Avant l'interface : seule la cible reçoit l'appui ; PASSER ferme ; la bulle finale part au toucher.
## Les relâchés passent (un bouton n'agit que sur un appui qu'il a reçu).
func _input(event: InputEvent) -> void:
	var is_btn := event is InputEventMouseButton
	var is_touch := event is InputEventScreenTouch
	if not (is_btn or is_touch):
		return
	if _eat:
		get_viewport().set_input_as_handled()
		if is_btn and not (event as InputEventMouseButton).pressed:
			_eat = false
		return
	if step == 0:
		return
	var pressed: bool = event.pressed
	if not pressed:
		return
	var p: Vector2 = event.position
	if is_btn and (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()  # (molette : rien ne défile sous le voile)
		return
	if is_btn and (step == 4 or (_skip_rect.has_area() and _skip_rect.has_point(p))):
		_end()
		_eat = true
		get_viewport().set_input_as_handled()
		return
	if step == 4 or _skip_rect.has_point(p):
		get_viewport().set_input_as_handled()  # (toucher émulé : la souris suit et ferme)
		return
	if step < 4 and _ready_t >= 0.15 and spot.has_point(p):
		return
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	if step == 0:
		return
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var a := clampf(_t / 0.3, 0.0, 1.0)
	var ins := UiKit.safe_insets(size)
	if not spot.has_area() or _ready_t < 0.0:
		# écran pas encore prêt (l'Atelier s'ouvre) : voile seul
		draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, VEIL * a * 0.6))
		_skip_rect = Rect2()
		return
	var ka := clampf(_ready_t / 0.3, 0.0, 1.0)
	# projecteur : ellipse autour de la cible ; APPRENDRE éclaire tout le panneau du bas (on lit ce qu'on achète)
	var c := spot.get_center()
	var r := spot.size * 0.5 * 1.12 + Vector2(12.0, 12.0) * u
	var pw := 2.0
	if step == 3:
		var dr: Rect2 = main.refuge.detail_rect()
		c = dr.get_center() + Vector2(0, 4.0 * u)
		r = Vector2(dr.size.x * 0.56, dr.size.y * 0.62)
		pw = 4.0
	elif step == 4:
		r = spot.size * 0.5 + Vector2(9.0, 8.0) * u
		pw = 4.0
	_draw_spot(Vector2(w, h), c, r, pw, a)
	# cible : anneau d'or qui pulse
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var tr := spot.grow((3.0 + 3.0 * pulse) * u)
	_sb.bg_color = Color(0, 0, 0, 0)
	_sb.set_corner_radius_all(int(minf(tr.size.x, tr.size.y) * 0.5) if step == 2 else int(12.0 * u))
	_sb.border_color = Color(Toon.GOLD, (0.45 + 0.45 * pulse) * ka)
	_sb.set_border_width_all(int(maxf(2.0, 2.5 * u)))
	_sb.shadow_size = 0
	draw_style_box(_sb, tr)
	# bandeau : au-dessus de la cible s'il y a la place, sinon dessous (jamais sur elle)
	var bh := 60.0 * u
	var group := bh + (40.0 * u if step < 4 else 0.0)
	var hole_top := c.y - r.y
	var hole_bot := c.y + r.y
	if step == 1:
		# accueil : le bandeau se pose au-dessus du sélecteur de monde (ni JOUER ni le sélecteur sous lui)
		var wr: Control = main.menu._worlds
		hole_top = minf(hole_top, wr.get_global_rect().position.y - 8.0 * u)
	var by: float
	if hole_top - 10.0 * u - group > ins.x + 20.0 * u:
		by = hole_top - 10.0 * u - group + bh / 2.0
	else:
		by = minf(hole_bot + 10.0 * u + bh / 2.0, h - ins.y - group + bh / 2.0 - 8.0 * u)
	_banner(Vector2(w * 0.5, by), u, ka)
	# PASSER, discret, sous le bandeau à droite
	if step < 4:
		var fs := int(UiKit.FS_CAPTION * u)
		var lab := "PASSER"
		var tw := UiKit.UI_FONT.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pr := Rect2(Vector2(w * 0.5 + 324.0 * u / 2.0 - tw - 40.0 * u, by + bh / 2.0 + 8.0 * u), Vector2(tw + 34.0 * u, 26.0 * u))
		_sb.bg_color = Color(Toon.SUMI, 0.78 * ka)
		_sb.set_corner_radius_all(int(13.0 * u))
		_sb.border_color = Color(Toon.WASHI, 0.35 * ka)
		_sb.set_border_width_all(maxi(1, int(1.0 * u)))
		draw_style_box(_sb, pr)
		draw_string(UiKit.UI_FONT, Vector2(pr.position.x + 12.0 * u, pr.get_center().y + fs * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.WASHI, 0.85 * ka))
		var cx := pr.end.x - 14.0 * u
		var cy := pr.get_center().y
		draw_polyline(PackedVector2Array([Vector2(cx - 3.0 * u, cy - 4.0 * u), Vector2(cx + 1.0 * u, cy), Vector2(cx - 3.0 * u, cy + 4.0 * u)]), Color(Toon.WASHI, 0.85 * ka), maxf(1.0, 1.6 * u), true)
		# zone tactile : au moins 44 u de haut, sans mordre sur la cible
		_skip_rect = pr.grow_individual(6.0 * u, 9.0 * u, 6.0 * u, 9.0 * u)
		if _skip_rect.intersects(spot):
			_skip_rect = pr
	else:
		_skip_rect = Rect2()
	# main fantôme qui tape sur la cible (pas sur le jeton de la bulle finale)
	if step < 4:
		var tip := spot.get_center()
		if step == 3:
			tip.x = spot.position.x + spot.size.x * 0.2  # au bord du tampon : APPRENDRE reste lisible
		var t := fmod(_t, 1.3)
		var press := 1.0 if t > 0.55 and t < 0.75 else 0.0
		if t > 0.55 and t < 1.2:
			var k := (t - 0.55) / 0.65
			draw_arc(tip, (10.0 + 26.0 * k) * u, 0, TAU, 28, Color(Toon.WASHI, (0.75 - 0.75 * k) * ka), 2.0 * u, true)
		var lift := (1.0 - press) * (6.0 + 4.0 * sin(_t * 4.8)) * u
		# près du bas de l'écran, la main vient d'en haut (retournée) : jamais coupée par le bord
		var flip := tip.y > h - ins.y - 70.0 * u
		_finger(tip + Vector2(lift, -lift if flip else lift), u, ka, press, flip)


## Voile d'encre percé d'un projecteur (super-ellipse de centre c, demi-axes r, exposant pw : 2 = ellipse, 4 = presque
## un rectangle) : anneau de quads entre le bord du trou et le bord de l'écran, liseré washi pointillé (coach.gd).
func _draw_spot(sz: Vector2, c: Vector2, r: Vector2, pw: float, a: float) -> void:
	var n := 64
	var veil := Color(Toon.VEIL, VEIL * a)
	var prev_e := Vector2.ZERO
	var prev_b := Vector2.ZERO
	var edge := PackedVector2Array()
	var cut: Array = []  # point ramené au bord de l'écran (pas de liseré là)
	for i in n + 1:
		var ang := TAU * float(i) / float(n)
		var d := Vector2(cos(ang), sin(ang))
		var k := 1.0 / pow(pow(absf(d.x) / r.x, pw) + pow(absf(d.y) / r.y, pw), 1.0 / pw)
		var e := c + d * k
		var tx := 1.0e9
		if absf(d.x) > 0.0001:
			tx = ((sz.x + 4.0 - c.x) if d.x > 0.0 else (-4.0 - c.x)) / d.x
		var ty := 1.0e9
		if absf(d.y) > 0.0001:
			ty = ((sz.y + 4.0 - c.y) if d.y > 0.0 else (-4.0 - c.y)) / d.y
		var tb := maxf(minf(tx, ty), 0.0)
		var b := c + d * tb
		var clamped := k >= tb - 0.5
		if clamped:
			e = b
		edge.append(e)
		cut.append(clamped)
		if i > 0:
			_pts.resize(0)
			var quad: Array = [prev_e, e, b]
			# les deux rayons sortent par deux bords différents : le coin de l'écran entre eux ferme le quad
			if _on_side(b, sz) != _on_side(prev_b, sz):
				quad.append(Vector2(-4.0 if b.x + prev_b.x < sz.x else sz.x + 4.0, -4.0 if b.y + prev_b.y < sz.y else sz.y + 4.0))
			quad.append(prev_b)
			for q in quad:
				if _pts.is_empty() or _pts[_pts.size() - 1].distance_squared_to(q) > 0.25:
					_pts.append(q)
			if _pts.size() >= 3 and _pts[0].distance_squared_to(_pts[_pts.size() - 1]) > 0.25:
				if Geometry2D.triangulate_polygon(_pts).size() > 0:
					draw_colored_polygon(_pts, veil)
		prev_e = e
		prev_b = b
	# liseré pointillé (ellipse seulement : la super-ellipse des panneaux garde le seul anneau d'or de la cible)
	if pw > 2.0:
		return
	var u := sz.x / 400.0
	var dash := PackedVector2Array()
	for j in range(0, edge.size() - 1, 2):
		if bool(cut[j]) or bool(cut[j + 1]):
			continue
		dash.append(edge[j])
		dash.append(edge[j].lerp(edge[j + 1], 0.9))
	draw_multiline(dash, Color(Toon.WASHI, 0.45 * a), 1.5 * u, true)


## Point du bord de l'écran (marge 4 px) : vrai s'il est sur un bord vertical (gauche ou droit).
static func _on_side(q: Vector2, sz: Vector2) -> bool:
	return absf(q.x + 4.0) < 0.5 or absf(q.x - sz.x - 4.0) < 0.5


## Bandeau du coach : coup de pinceau sumi, filet vermillon, sceau vermillon à picto, titre et une ligne.
func _banner(pos: Vector2, u: float, a: float) -> void:
	var tx: Array = TEXTS.get(step, ["", ""])
	var t := UiKit.plain(String(tx[0])).to_upper()
	var st := UiKit.plain(String(tx[1]))
	var ein := UiKit.ease_out(clampf(_ready_t / 0.26, 0.0, 1.0))
	var ta := clampf((_ready_t - 0.08) / 0.2, 0.0, 1.0) * a
	var bw := 324.0 * u
	var h := 60.0 * u
	var x0 := pos.x - bw / 2.0
	var y0 := pos.y - h / 2.0
	var reach := 0.15 + 0.85 * ein
	_pts.resize(_shape.size())
	for i in _shape.size():
		var p := _shape[i]
		_pts[i] = Vector2(x0 + minf(p.x, reach) * bw, y0 + p.y * h)
	draw_colored_polygon(_pts, Color(UIColors.SUMI_HUD_BG, UIColors.SUMI_HUD_BG.a * a))
	_pts.resize(_line.size())
	for i in _line.size():
		var p := _line[i]
		_pts[i] = Vector2(x0 + minf(p.x, reach) * bw, y0 + p.y * h)
	draw_polyline(_pts, Color(Toon.VERMILION, 0.95 * a), 2.5 * u, true)
	var sp := maxi(1, int(3.0 * u))
	if _title.spacing_glyph != sp:
		_title.spacing_glyph = sp
	var tx0 := x0 + 68.0 * u
	var room := bw - 84.0 * u
	var fs := int(16 * u)
	while fs > 10 and _title.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	var sfs := int(11 * u)
	while sfs > 7 and UiKit.UI_FONT.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x > room:
		sfs -= 1
	draw_string(_title, Vector2(tx0 + (1.0 - ein) * 10.0 * u, pos.y - 3.0 * u), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIColors.WASHI, ta))
	draw_string(UiKit.UI_FONT, Vector2(tx0, pos.y + 14.0 * u), st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(UIColors.WASHI, 0.85 * ta))
	# sceau carré vermillon, posé comme un tampon (il tombe de 1,6 fois sa taille)
	var sk := clampf((_ready_t - 0.1) / 0.22, 0.0, 1.0) * a
	if sk > 0.0:
		var z := lerpf(1.6, 1.0, UiKit.ease_out(sk))
		var sc := Vector2(x0 + 38.0 * u, pos.y)
		var half := 19.0 * u * z
		draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, sk), int(5 * u), Color(UIColors.WASHI, 0.85 * sk), maxi(1, int(1.5 * u))), Rect2(sc - Vector2(half, half), Vector2(half, half) * 2.0))
		UiKit.glyph(self, String(GLYPHS.get(step, "stamp")), sc, 22.0 * u * z * 0.42, Toon.WASHI, Toon.VERMILION, sk)


## Main fantôme (planche Coach) : l'index pointe sur p, la main vient du bas à droite. press : 1 posée.
func _finger(at: Vector2, u: float, a: float, press: float, flip := false) -> void:
	if a <= 0.01:
		return
	draw_set_transform(at, 0.0, Vector2(1.0, -1.0 if flip else 1.0))
	var p := Vector2.ZERO
	draw_circle(p, (20.0 + 4.0 * (1.0 - press)) * u, Color(Toon.WASHI, 0.22 * a))
	draw_circle(p, 12.0 * u, Color(Toon.WASHI, 0.45 * a))
	var ink := Color(Toon.SUMI, 0.9 * a)
	var skin := Color(Toon.WASHI, a)
	var q := p + Vector2(-4.0, 4.0) * u
	draw_circle(q + Vector2(10.0, 30.0) * u, 11.0 * u, Color(0, 0, 0, 0.15 * a))
	var knuckle := q + Vector2(3.0, 18.0) * u
	draw_line(q, knuckle, ink, 10.0 * u, true)
	draw_circle(q + Vector2(9.0, 27.0) * u, 11.5 * u, ink)
	draw_circle(q + Vector2(12.0, 19.0) * u, 5.5 * u, ink)
	draw_circle(q + Vector2(17.0, 23.0) * u, 5.5 * u, ink)
	draw_circle(q + Vector2(-2.0, 26.0) * u, 6.0 * u, ink)
	draw_line(q, knuckle, skin, 7.0 * u, true)
	draw_circle(q + Vector2(9.0, 27.0) * u, 9.5 * u, skin)
	draw_circle(q + Vector2(12.0, 19.0) * u, 3.8 * u, skin)
	draw_circle(q + Vector2(17.0, 23.0) * u, 3.8 * u, skin)
	draw_circle(q + Vector2(-2.0, 26.0) * u, 4.3 * u, skin)
	draw_line(q + Vector2(10.0, 21.0) * u, q + Vector2(14.0, 25.0) * u, Color(Toon.SUMI, 0.35 * a), 1.2 * u, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
