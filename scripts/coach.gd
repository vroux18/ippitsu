extends Control
## Coach : le tutoriel se fait en jouant. Bandeau v2 en haut de l'écran (zone 88–130 u, même coup de pinceau que
## le bandeau d'événement du HUD : sceau vermillon à picto, titre en capitales, une ligne), geste fantôme sur le
## terrain (main fantôme, trait fantôme, taps), au moment où chaque geste sert : tracer, trancher, l'encre, une
## figure, l'ultime, la course. (Pas de bulle « esquive » : le simple tap ne fait rien, on s'écarte en traçant.)
## Chaque leçon ne vient qu'une fois (meta.coach_seen) et part dès que le geste est fait (ou au bout de quelques
## secondes). Chaque leçon arrive en arrêt sur image : le jeu se fige, voile d'encre percé d'un projecteur sur le
## geste, bandeau, geste fantôme animé, puis une main qui pulse (invite à toucher, sans un mot) ; ce toucher
## relance le jeu (jamais un trait) et le bandeau reste en rappel. La première garde ensuite le temps ralenti
## jusqu'au trait. Leçon des figures (« figures ») : au 2e combat, une planche des six figures, puis « Un zigzag ».
## Pas de texte d'interaction (UI v2) : le picto, le geste fantôme et la main portent la consigne.
## main appelle on_launch, on_event, on_pick, slows, frozen, freeze_tap, is_over_ui et skip ;
## le coach lit l'état de main.
const Perf = preload("res://scripts/perf_probe.gd")  # relevé par image (-- --perf)

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
const PowerData = preload("res://scripts/power_data.gd")

# une bulle = quelques mots ; le geste fantôme (main, trait, taps) montre le reste
const TEXTS := {
	"stroke": "Trace un trait",
	"cut": "Traverse-le",
	"ink": "L'encre revient",
	"ult": "Double tap : ultime",
	"run": "Maintiens : cours",
	"figures": "Un zigzag",
}
# une ligne sous le titre (comme la planche Coach : « Le ronin suit ton doigt et tranche. »)
const SUBS := {
	"stroke": "Le ronin suit ton doigt et tranche.",
	"cut": "Passe à travers lui d'un trait.",
	"ink": "Elle revient quand tu ne traces pas.",
	"ult": "Deux taps : la lame balaie l'écran.",
	"run": "Doigt posé : le ronin court.",
	"figures": "Une forme frappe plus fort.",
	"figure": "Sa technique est à toi.",
}
# picto du sceau du bandeau (clé ui_icons.gd, ou glyph UiKit) ; les leçons de figure montrent la figure elle-même
const ICONS := {"stroke": "hud/slash", "cut": "hud/slash", "ink": "water", "ult": "interface/double_tap", "run": "effets/vitesse"}
# mode pad (option) : le geste se fait dans le pad du bas, pas sur le terrain
const TEXTS_PAD := {
	"stroke": "Trace dans le pad",
	"figures": "Un zigzag dans le pad",
}
# leçon des figures (planche en arrêt sur image) : une figure reconnue donne d'elle-même +15 % de dégâts
# à sa ruée et +1 chaîne si elle touche (powers.figure_launch, main._on_dash_finished) ; son rouleau
# (PowerData.FIG_UNLOCK) débloque sa technique. Une seule ligne, sans chiffre : la planche montre le reste.
const LESSON := [
	"Une forme frappe plus fort",
]
# technique de chaque figure (celle de son rouleau), en petit sous la figure
const TECH := {"loop": "toupie", "zigzag": "éclair", "straight": "iaï", "return": "garde", "enso": "ensō", "hook": "estoc"}
const GLUE := [":", ";", "!", "?", "%", "=", "»", "..."]
const FIG_TEXT := {
	"loop": "Une boucle",
	"zigzag": "Un zigzag",
	"straight": "Un trait droit",
	"return": "Un aller-retour",
	"enso": "Un grand cercle",
	"hook": "Un crochet",
}
# durée de vie (s réelles, arrêt sur image non compté) ; 0 : jusqu'au geste
const LIFE := {"stroke": 0.0, "cut": 7.0, "ink": 6.0, "figure": 10.0, "ult": 8.0, "run": 7.0, "figures": 14.0}
const ORDER := ["stroke", "cut", "figures", "ult", "figure", "ink", "run"]
var _lesson_bottom := -1.0  # bas de la planche des figures à cette image (< 0 : pas de planche)
const GAP := 0.8  # silence entre deux bulles
const SLOW := 0.3  # temps ralenti tant que le premier trait n'est pas tracé
const FREEZE_HINT := 0.8  # arrêt sur image : le doigt qui pulse (invite à toucher) après ce délai (s réelles)
const FREEZE_MAX := 12.0  # garde-fou : l'arrêt sur image se lève seul (s réelles)
const FREEZE_MAX_BOT := 3.0  # robot (CI) : jamais bloqué longtemps
const FREEZE_HARD_MS := 60000  # garde-fou absolu (horloge murale), même si le coach ne tournait plus
const VEIL := 0.55  # voile d'encre de l'arrêt sur image (percé d'un projecteur sur le geste)
const BIG := 1.06  # bandeau à peine agrandi pendant l'arrêt sur image

var main: Node
var mark := ""  # bulle affichée ("" : aucune)
var _t := 0.0  # temps réel depuis son apparition (animations)
var _life := 0.0  # temps réel de jeu depuis son apparition (arrêt sur image non compté)
var _gap := 0.0
var _fig := ""  # figure du rouleau pris, à montrer
var _fz := -1.0  # arrêt sur image : temps réel écoulé (-1 : le jeu tourne)
var _fz_ms := 0  # début de l'arrêt sur image (horloge murale, garde-fou)
var _fz_want := false  # arrêt sur image demandé, en attente du doigt levé (jamais au milieu d'un trait)
var _froze := {}  # bulles déjà montrées en arrêt sur image (une seule fois, même reprises plus tard)
var _veil := 0.0  # opacité du voile (suit l'arrêt sur image)
var _big := 1.0  # échelle de la bulle (suit l'arrêt sur image)
var _skip_rect := Rect2()
var _force := ""  # bulle à montrer dès que possible, sans condition (captures : `?coach=figures`)
var _ui := FontVariation.new()
var _title := FontVariation.new()  # titre du bandeau : Shippori espacé
var _sb := StyleBoxFlat.new()
var _shape := PackedVector2Array()  # coup de pinceau du bandeau (gabarit 228 × 38 du HUD, normalisé 0..1)
var _line := PackedVector2Array()  # son filet vermillon (normalisé)
var _pts := PackedVector2Array()  # tampon de points (polygones du bandeau, du projecteur)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 1
	_title.base_font = UiKit.TITLE_FONT
	# même coup de pinceau que hud.gd (_banner_shape) : les deux bandeaux se ressemblent trait pour trait
	_shape.append(Vector2(6, 10))
	_cubic(_shape, Vector2(6, 10), Vector2(40, 3), Vector2(120, 5), Vector2(222, 7), 8)
	_shape.append(Vector2(218, 16))
	_shape.append(Vector2(224, 22))
	_cubic(_shape, Vector2(224, 22), Vector2(150, 34), Vector2(70, 34), Vector2(4, 30), 8)
	_shape.append(Vector2(10, 21))
	for i in _shape.size():
		_shape[i] = _shape[i] / Vector2(228.0, 38.0)
	_line.append(Vector2(30, 31))
	_cubic(_line, Vector2(30, 31), Vector2(90, 35), Vector2(150, 34), Vector2(200, 30), 6)
	for i in _line.size():
		_line[i] = _line[i] / Vector2(228.0, 38.0)


static func _cubic(out: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		var c := p2.lerp(p3, t)
		out.append(a.lerp(b, t).lerp(b.lerp(c, t), t))


func active() -> bool:
	return main != null and main.meta != null and not bool(main.meta.tuto_done)


func _in_play() -> bool:
	return String(main.state) == "play" and not bool(main.game_over) and is_instance_valid(main.hero)


## Pad tactile de main (mode pad), vide en mode « sur l'écran ».
func _pad() -> Rect2:
	if String(main.ctrl_mode) != "pad":
		return Rect2()
	var pr: Rect2 = main.hud.pad
	return pr


func seen(id: String) -> bool:
	return main.meta.coach_seen.has(id)


## Premier trait attendu (après l'arrêt sur image) : main ralentit le temps.
func slows() -> bool:
	return mark == "stroke" and active() and _fz < 0.0


## Arrêt sur image en cours : main fige le jeu (Engine.time_scale = 0), comme la pause.
## Jamais hors du jeu (pause, rouleaux, mort) ; garde-fou à l'horloge murale.
func frozen() -> bool:
	return _fz >= 0.0 and mark != "" and active() and _in_play() and Time.get_ticks_msec() - _fz_ms < FREEZE_HARD_MS


## Invite affichée (doigt qui pulse) : le prochain toucher relance le jeu.
func hint_shown() -> bool:
	return frozen() and _fz >= FREEZE_HINT


## Toucher pendant l'arrêt sur image (main._touch_down) : pris par le coach, jamais un trait ;
## après l'invite, il relance le jeu. Faux hors arrêt sur image (le toucher suit son cours).
func freeze_tap(_sp: Vector2) -> bool:
	if not frozen():
		return false
	if _fz >= FREEZE_HINT:
		_unfreeze()
	return true


## Captures : la bulle `id` se montre dès que le jeu tourne, sans attendre son moment.
func force(id: String) -> void:
	if TEXTS.has(id) or id == "figure":
		_force = id


## Nouvelle partie, retour à l'accueil : rien d'affiché.
func clear() -> void:
	mark = ""
	_fig = ""
	_t = 0.0
	_life = 0.0
	_gap = 0.0
	_fz = -1.0
	_fz_want = false
	_veil = 0.0
	_big = 1.0
	# tutoriel (re)commencé : les arrêts sur image reviendront
	if main != null and main.meta != null and main.meta.coach_seen.is_empty():
		_froze = {}


## Rouleau pris : un rouleau de figure (technique débloquée) montre sa figure.
func on_pick(id: String) -> void:
	if not active() or seen("figure"):
		return
	for k in PowerData.FIG_UNLOCK.keys():
		if String(PowerData.FIG_UNLOCK[k]) == id:
			_fig = String(k)


## Ruée lancée ; shape : figure reconnue ("" sinon).
func on_launch(shape: String) -> void:
	if mark == "":
		return
	if mark == "stroke" or (mark == "figure" and shape == _fig) or (mark == "figures" and shape != ""):
		_finish()


## Gestes signalés par main : "hit" (le trait a touché), "ult", "run".
func on_event(ev: String) -> void:
	if (ev == "hit" and mark == "cut") or (ev == "ult" and mark == "ult") or (ev == "run" and mark == "run"):
		_finish()


## « Passer » : plus aucune bulle.
func skip() -> void:
	main.meta.coach_skip()
	main.meta.save_data()
	clear()
	main.sfx.play("whoosh", 1.2, -6.0)
	main.hud.toast("TUTORIEL PASSÉ")


func is_over_ui(p: Vector2) -> bool:
	return _skip_shown() and _skip_rect.grow(6.0).has_point(p)


func _skip_shown() -> bool:
	return active() and _in_play() and (mark != "" or bool(main.gentle))


func _finish() -> void:
	if mark == "":
		return
	main.meta.coach_see(mark)
	main.meta.save_data()
	if mark == "figure":
		_fig = ""
	mark = ""
	_fz = -1.0
	_fz_want = false
	_gap = GAP
	main.sfx.play("shot", 1.6, -10.0)


func _show(id: String) -> void:
	mark = id
	_t = 0.0
	_life = 0.0
	_fz = -1.0
	# arrêt sur image pour lire (une fois par bulle : une bulle reprise plus tard revient en petit)
	_fz_want = not _froze.has(id)


## Le jeu se fige : la bulle se lit en grand.
func _freeze() -> void:
	_fz_want = false
	_fz = 0.0
	_fz_ms = Time.get_ticks_msec()
	_froze[mark] = true
	main.sfx.play("whoosh", 0.6, -12.0)


## Le jeu repart : la bulle reste en petit rappel.
func _unfreeze() -> void:
	if _fz < 0.0:
		return
	_fz = -1.0
	main.sfx.play("whoosh", 1.4, -12.0)


## Le geste de cette bulle sert-il maintenant ?
func _wanted(id: String) -> bool:
	match id:
		"stroke":
			return not bool(main.hero.dashing)
		"cut":
			return _first_enemy() != null
		"figures":
			# après la base (trancher), dès le 2e combat, avec un ennemi sur qui essayer
			return seen("cut") and int(main.room) >= 2 and not bool(main.in_hub) and not bool(main.hero.dashing) and _first_enemy() != null
		"ink":
			return not bool(main._explore) and float(main.elan) < float(main.elan_max()) * 0.35
		"figure":
			return _fig != ""
		"ult":
			return float(main.ult) >= 1.0 and not bool(main.in_hub)
		"run":
			var ar = main.arena
			return bool(main._explore) and not bool(main.in_hub) and bool(ar.stage) and int(main._enc) < 0 \
				and int(ar.zones_done()) >= 1 and int(ar.zones_left()) > 0
	return false


## Ennemi vivant le plus proche du héros (pour « traverse-le »).
func _first_enemy() -> Node3D:
	var best: Node3D = null
	var bd := 1.0e9
	var hp: Vector3 = main.hero.position
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or e.dummy or e.is_harmless():
			continue
		var n: Node3D = e
		var d := n.position.distance_to(hp)
		if d < bd:
			bd = d
			best = n
	return best


func _process(_delta: float) -> void:
	if Perf.on:
		var _pt := Time.get_ticks_usec()
		_process_body(_delta)
		Perf.add(&"coach", _pt)
	else:
		_process_body(_delta)


func _process_body(_delta: float) -> void:
	size = get_viewport_rect().size
	if main == null:
		return
	if not active():
		if mark != "" or _fig != "":
			clear()
		if visible:
			visible = false
		return
	visible = true
	if not _in_play():
		queue_redraw()
		return
	var real := UiKit.real_delta()
	if mark == "":
		_gap -= real
		if _force != "":
			_show(_force)
			_force = ""
		elif _gap <= 0.0:
			for id in ORDER:
				var sid := String(id)
				if not seen(sid) and _wanted(sid):
					_show(sid)
					break
	else:
		_t += real
		if _fz >= 0.0:
			# arrêt sur image : le jeu attend un toucher (garde-fou : il repart seul)
			_fz += real
			var fz_max := FREEZE_MAX_BOT if main.get("_bot") != null else FREEZE_MAX
			if _fz > fz_max or not frozen():
				_unfreeze()
		else:
			_life += real
			if mark == "ink" and _life > 1.5 and float(main.elan) >= float(main.elan_max()) * 0.9:
				_finish()  # l'encre est revenue : compris
			else:
				var life := float(LIFE.get(mark, 6.0))
				if life > 0.0 and _life > life:
					_finish()
	# arrêt sur image demandé : dès que le doigt est levé (jamais au milieu d'un trait ou d'une course)
	if mark != "" and _fz_want and _fz < 0.0:
		if not bool(main.touching):
			_freeze()
		elif _life > 1.0:
			_fz_want = false  # le doigt reste posé : la bulle reste en petit
	# voile et taille de la bulle suivent l'arrêt sur image (en temps réel)
	var on := _fz >= 0.0
	_veil = move_toward(_veil, VEIL if on else 0.0, real * 2.5)
	_big = move_toward(_big, BIG if on else 1.0, real * 2.5)
	queue_redraw()


# ------------------------------------------------------------------ dessin

func _screen(p: Vector3) -> Vector2:
	var cam: Camera3D = main.cam
	if cam.is_position_behind(p):
		return Vector2(-9999, -9999)
	return cam.unproject_position(p)


func _draw() -> void:
	if Perf.on:
		var _pt := Time.get_ticks_usec()
		_draw_body()
		Perf.add(&"coach_draw", _pt)
	else:
		_draw_body()


func _draw_body() -> void:
	_lesson_bottom = -1.0
	if main == null or not active() or not _in_play() or size.x < 10.0:
		return
	var u := size.x / 400.0
	var insets := UiKit.safe_insets(size)
	var a := clampf(_t / 0.3, 0.0, 1.0)
	var hero: Node3D = main.hero
	var hp := hero.position
	var feet := _screen(hp)
	# mode pad : les gestes fantômes se font dans le pad (le terrain garde le bandeau)
	var pr := _pad()
	var in_pad := pr.size.x >= 10.0
	if in_pad:
		feet = pr.get_center()
	# arrêt sur image : voile d'encre percé d'un projecteur (ellipse) sur le geste à faire
	if _veil > 0.005:
		var sc := Vector2(-9999, -9999)
		var sr := Vector2(120.0, 190.0) * u
		match mark:
			"stroke":
				sc = pr.get_center() if in_pad else _screen(hp + Vector3(0, 0, -1.8))
				if in_pad:
					sr = pr.size * 0.5
			"cut":
				var e := _first_enemy()
				sc = _screen(e.position).lerp(feet, 0.5) if e != null else feet
				sr = Vector2(110.0, 170.0) * u
			"ink":
				var ir: Rect2 = main.hud.ink_rect()
				sc = ir.get_center()
				sr = Vector2(44.0 * u, ir.size.y * 0.7)
			"figure", "ult", "run":
				sc = feet
				sr = Vector2(120.0, 150.0) * u
		if sc.x < -9000.0 or mark == "" or mark == "figures":
			draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, _veil))
		else:
			_draw_spot(sc, sr, _veil)
	if _skip_shown():
		_draw_skip(u, insets)
	if mark == "":
		return
	var txt := String(TEXTS.get(mark, ""))
	if in_pad:
		txt = String(TEXTS_PAD.get(mark, txt))
	var sub := String(SUBS.get(mark, ""))
	var icon := String(ICONS.get(mark, ""))
	match mark:
		"stroke":
			if in_pad:
				_ghost_pad_path(pr, u, a)
			else:
				_ghost_path(hp, u, a)
		"cut":
			var e := _first_enemy()
			if e != null:
				_ghost_line(_screen(hp), _screen(e.position), u, a)  # chemin du rōnin sur le terrain (aussi en mode pad)
		"ink":
			# la jauge d'encre du HUD (bord droit), avec son cadre : géométrie lue dans le HUD (raccourcie au-dessus du pad)
			var ir: Rect2 = main.hud.ink_rect()
			var gr := ir.grow(3.0 * u)
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			_sb.bg_color = Color(0, 0, 0, 0)
			_sb.set_corner_radius_all(int(14.0 * u))
			_sb.border_color = Color(Toon.GOLD, (0.5 + 0.5 * pulse) * a)
			_sb.set_border_width_all(int(maxf(2.0, 3.0 * u)))
			_sb.shadow_size = 0
			draw_style_box(_sb, gr.grow((4.0 + 3.0 * pulse) * u))
		"figure":
			txt = String(FIG_TEXT.get(_fig, "Dessine la figure"))
			icon = "fig:" + _fig
		"figures":
			icon = "fig:zigzag"
			if _fz >= 0.0:
				_draw_lesson(u, a)  # planche des six figures (elle porte son propre titre : pas de bandeau)
				txt = ""
		"ult":
			_ghost_double_tap(feet, u, a)
		"run":
			if in_pad:
				_ghost_pad_hold(feet, u, a)
			else:
				_ghost_hold(feet, hp, u, a)
	if txt != "":
		_banner(txt, sub, icon, u, a)
	if _fz >= 0.0:
		_draw_hint(u, insets)


## Voile d'encre percé d'un projecteur : ellipse claire (centre c, demi-axes r) autour du geste, le reste
## de l'écran sous le voile ; liseré washi pointillé sur l'ellipse (planche Coach). Sans flou : anneau de quads.
func _draw_spot(c: Vector2, r: Vector2, k: float) -> void:
	var n := 48
	var veil := Color(Toon.VEIL, k)
	var prev_e := Vector2.ZERO
	var prev_b := Vector2.ZERO
	for i in n + 1:
		var ang := TAU * float(i) / float(n)
		var d := Vector2(cos(ang), sin(ang))
		var e := c + Vector2(d.x * r.x, d.y * r.y)
		# point du bord de l'écran dans la même direction (le rayon sort par le côté le plus proche)
		var tx := 1.0e9
		if absf(d.x) > 0.0001:
			tx = ((size.x + 4.0 - c.x) if d.x > 0.0 else (-4.0 - c.x)) / d.x
		var ty := 1.0e9
		if absf(d.y) > 0.0001:
			ty = ((size.y + 4.0 - c.y) if d.y > 0.0 else (-4.0 - c.y)) / d.y
		var tb := maxf(minf(tx, ty), 0.0)
		var b := c + d * tb
		# l'ellipse peut déborder l'écran : son point est ramené au bord (le quad dégénère, on le saute)
		if (e - c).length() >= tb - 0.5:
			e = b
		if i > 0:
			_pts.resize(0)
			for q in [prev_e, e, b, prev_b]:
				if _pts.is_empty() or _pts[_pts.size() - 1].distance_squared_to(q) > 0.25:
					_pts.append(q)
			if _pts.size() >= 3 and _pts[0].distance_squared_to(_pts[_pts.size() - 1]) > 0.25:
				draw_colored_polygon(_pts, veil)
		prev_e = e
		prev_b = b
	# liseré pointillé (4 / 8 u) sur l'ellipse
	var u := size.x / 400.0
	var per := 2.0 * PI * sqrt((r.x * r.x + r.y * r.y) * 0.5)
	var m := maxi(12, int(per / (12.0 * u)))
	for j in m:
		var a0 := TAU * float(j) / float(m)
		var a1 := a0 + TAU / float(m) * 0.35
		draw_line(c + Vector2(cos(a0) * r.x, sin(a0) * r.y), c + Vector2(cos(a1) * r.x, sin(a1) * r.y), Color(Toon.WASHI, 0.5 * k / VEIL), 1.5 * u, true)


## Invite à toucher (arrêt sur image) : une main fantôme qui pulse en bas, sans un mot, un instant après l'arrêt.
func _draw_hint(u: float, insets: Vector2) -> void:
	var k := clampf((_fz - FREEZE_HINT) / 0.3, 0.0, 1.0)
	if k <= 0.0:
		return
	var y := size.y - insets.y - 110.0 * u
	var pr := _pad()
	if pr.size.x >= 10.0:
		y = minf(y, pr.position.y - 86.0 * u)  # au-dessus du pad (et du bouton passer)
	if _lesson_bottom > 0.0:
		y = _lesson_bottom + 30.0 * u  # leçon des figures : juste sous la planche, jamais dessus
	var c := Vector2(size.x * 0.5, y)
	var t := fmod(_t, 1.2)
	# onde qui part du doigt, puis la main qui s'enfonce
	if t < 0.7:
		draw_arc(c, (12.0 + 30.0 * t) * u, 0, TAU, 28, Color(Toon.WASHI, (0.7 - t) * k), 2.0 * u, true)
	var press := 1.0 if t < 0.15 else 0.0
	_finger(c + Vector2(0, 3.0 * u * press), u, k, 1.0 - press)


## Leçon des figures (arrêt sur image) : planche de papier, une ligne, puis les six figures qui se
## tracent en boucle. Vignettes monotones : même papier assombri, liseré sumi fin, trait à l'encre sumi,
## point de départ vermillon (seul accent) ; nom et technique à l'encre.
func _draw_lesson(u: float, a: float) -> void:
	var w := minf(size.x - 32.0 * u, 372.0 * u)
	var pad := 16.0 * u
	var fs := int(13.0 * u)
	var tfs := int(22.0 * u)
	var lfs := int(11.0 * u)
	var sfs := int(10.0 * u)
	var text_w := w - 2.0 * pad - 14.0 * u
	var rows: Array = []  # [ligne, début d'un point]
	for s in LESSON:
		var first := true
		for l in UiKit.wrap(_ui, UiKit.plain(String(s)), fs, text_w, GLUE):
			rows.append([String(l), first])
			first = false
	var lh := float(fs) * 1.45
	var cell := minf((w - 2.0 * pad) / 3.0, 112.0 * u)
	var tile := cell * 0.6
	var cell_h := tile + float(lfs) * 1.5 + float(sfs) * 1.5 + 8.0 * u
	var head_h := float(tfs) * 1.4
	var h := pad + head_h + 6.0 * u + float(rows.size()) * lh + 12.0 * u + 2.0 * cell_h + pad
	var top_min: float = main.hud.top_clear()
	top_min += 8.0 * u
	var y0 := clampf(size.y * 0.44 - h * 0.5, top_min, maxf(top_min, size.y - h - 130.0 * u))
	var k := UiKit.ease_out(a)
	var r := Rect2(Vector2((size.x - w) * 0.5, y0 + (1.0 - k) * 10.0 * u), Vector2(w, h))
	_lesson_bottom = r.end.y
	var ink := Color(Toon.ui_ink, 0.9 * a)
	UiKit.box(_sb, Color(Toon.ui_paper, 0.96 * a), int(16.0 * u), ink, int(maxf(1.0, 1.6 * u)))
	_sb.shadow_color = Color(0, 0, 0, 0.3 * a)
	_sb.shadow_size = int(10.0 * u)
	draw_style_box(_sb, r)
	# titre, souligné d'un trait vermillon
	var y := r.position.y + pad + float(tfs) * 0.9
	var ttw := UiKit.text(self, UiKit.TITLE_FONT, UiKit.plain("LES FIGURES"), Vector2(r.get_center().x, y), tfs, Color(Toon.ui_ink, a))
	draw_rect(Rect2(Vector2(r.get_center().x - ttw * 0.3, y + 6.0 * u), Vector2(ttw * 0.6, 3.0 * u)), Color(Toon.VERMILION, a))
	y = r.position.y + pad + head_h + 6.0 * u
	# les lignes, chaque point marqué d'une goutte vermillon
	for row in rows:
		var line := String(row[0])
		var by := y + lh * 0.5 + float(fs) * 0.36
		if bool(row[1]):
			draw_circle(Vector2(r.position.x + pad + 4.0 * u, y + lh * 0.5), 3.0 * u, Color(Toon.VERMILION, a))
		draw_string(_ui, Vector2(r.position.x + pad + 14.0 * u, by), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.ui_ink, a))
		y += lh
	y += 12.0 * u
	# les six figures (trois par ligne), décalées dans le temps
	var gx := r.position.x + (w - 3.0 * cell) * 0.5
	for i in UiKit.FIGURES.size():
		var kind := String(UiKit.FIGURES[i])
		var cx := gx + cell * (float(i % 3) + 0.5)
		var cy := y + cell_h * floorf(float(i) / 3.0)
		var box := Rect2(Vector2(cx - tile * 0.5, cy), Vector2(tile, tile))
		_draw_figure(kind, box, u, a, Toon.ui_ink, true, float(i) * 0.37, true)
		UiKit.text(self, _ui, UiKit.plain(String(UiKit.FIG_WORD.get(kind, "FIGURE"))), Vector2(cx, cy + tile + float(lfs) * 1.3), lfs, Color(Toon.ui_ink, a))
		UiKit.text(self, _ui, UiKit.plain(String(TECH.get(kind, ""))), Vector2(cx, cy + tile + float(lfs) * 1.5 + float(sfs) * 1.3), sfs, Color(Toon.ui_ink, 0.6 * a))


## Passer le tutoriel : bouton rond sumi dans le coin bas gauche, picto « sauter » (double chevron et barre),
## sans un mot (mode pad : juste au-dessus du pad, qui garde ses touchers).
func _draw_skip(u: float, insets: Vector2) -> void:
	var d := 36.0 * u
	_skip_rect = Rect2(Vector2(14.0 * u, size.y - insets.y - 14.0 * u - d), Vector2(d, d))
	var pr := _pad()
	if pr.size.x >= 10.0:
		_skip_rect.position.y = minf(_skip_rect.position.y, pr.position.y - 8.0 * u - d)
	var c := _skip_rect.get_center()
	draw_circle(c + Vector2(0, 2.0 * u), d * 0.5, Color(0, 0, 0, 0.2))
	draw_circle(c, d * 0.5, Color(Toon.SUMI, 0.82))
	draw_arc(c, d * 0.5, 0, TAU, 32, Color(Toon.WASHI, 0.5), maxf(1.0, 1.2 * u), true)
	# deux chevrons vers la droite, puis la barre d'arrêt
	var col := Color(Toon.WASHI, 0.9)
	var wdt := maxf(1.0, 2.0 * u)
	for i in 2:
		var x := c.x - 8.0 * u + 6.5 * u * float(i)
		draw_polyline(PackedVector2Array([Vector2(x, c.y - 5.0 * u), Vector2(x + 4.5 * u, c.y), Vector2(x, c.y + 5.0 * u)]), col, wdt, true)
	draw_line(Vector2(c.x + 7.0 * u, c.y - 5.5 * u), Vector2(c.x + 7.0 * u, c.y + 5.5 * u), col, wdt, true)


## Bandeau du coach (UI v2, planche Coach) : même coup de pinceau sumi 92 % que le bandeau d'événement du HUD,
## centré dans la zone 88–130 u (sous la barre haute ou le makimono du gardien ; plus bas si le HUD annonce
## quelque chose), filet vermillon, sceau vermillon carré à picto (entaille, figure, goutte, double tap,
## vitesse ; « fig:<figure> » : la figure qui se trace), titre Shippori en capitales espacées, une ligne dessous.
## Le trait se peint de gauche à droite (260 ms), le texte suit en fondu ; à peine agrandi en arrêt sur image.
func _banner(title: String, sub: String, icon: String, u: float, a: float) -> void:
	var t := UiKit.plain(title).to_upper()
	var st := UiKit.plain(sub)
	var k_in := clampf(_t / 0.26, 0.0, 1.0)
	var ein := UiKit.ease_out(k_in)
	var bw := 324.0 * u
	var h := 60.0 * u
	var top: float = main.hud.top_clear()
	var hb = main.hud.get("_banner_t")
	if hb != null and float(hb) >= 0.0:
		top += 64.0 * u  # le HUD annonce (étape nettoyée, boss…) : le coach se range dessous
	var cy := top + 8.0 * u + h / 2.0
	var cx := size.x * 0.5
	draw_set_transform(Vector2(cx, cy), 0.0, Vector2(_big, _big))
	var x0 := -bw / 2.0
	var reach := 0.15 + 0.85 * ein
	# le coup de pinceau, tronqué à droite tant qu'il se peint, puis le filet vermillon
	_pts.resize(_shape.size())
	for i in _shape.size():
		var p := _shape[i]
		_pts[i] = Vector2(x0 + minf(p.x, reach) * bw, -h / 2.0 + p.y * h)
	draw_colored_polygon(_pts, Color(UIColors.SUMI_HUD_BG, UIColors.SUMI_HUD_BG.a * a))
	_pts.resize(_line.size())
	for i in _line.size():
		var p := _line[i]
		_pts[i] = Vector2(x0 + minf(p.x, reach) * bw, -h / 2.0 + p.y * h)
	draw_polyline(_pts, Color(Toon.VERMILION, 0.95 * a), 2.5 * u, true)
	# sceau carré vermillon, posé comme un tampon (penché de 5°) juste après le trait, son picto en washi
	var sk := clampf((_t - 0.1) / 0.22, 0.0, 1.0)
	var sc := Vector2(x0 + 38.0 * u, 0.0)
	if sk > 0.0:
		var z := lerpf(1.6, 1.0, UiKit.ease_out(sk))
		var half := 19.0 * u * z
		draw_set_transform(Vector2(cx, cy) + sc * _big, -0.087, Vector2(_big, _big))
		draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, a * sk), int(5 * u), Color(UIColors.WASHI, 0.85 * a * sk), maxi(1, int(1.5 * u))), Rect2(-Vector2(half, half), Vector2(half, half) * 2.0))
		_seal_icon(icon, Vector2.ZERO, 22.0 * u * z, a * sk)
		draw_set_transform(Vector2(cx, cy), 0.0, Vector2(_big, _big))
	# titre et ligne, rétrécis s'ils débordent
	var ta := a * clampf((_t - 0.08) / 0.2, 0.0, 1.0)
	var sp := maxi(1, int(3.0 * u))
	if _title.spacing_glyph != sp:
		_title.spacing_glyph = sp
	var tx := x0 + 68.0 * u
	var room := bw - 84.0 * u
	var fs := int(16 * u)
	while fs > 10 and _title.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	var sfs := int(11 * u)
	while st != "" and sfs > 7 and UiKit.UI_FONT.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x > room:
		sfs -= 1
	if st == "":
		draw_string(_title, Vector2(tx + (1.0 - ein) * 10.0 * u, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIColors.WASHI, ta))
	else:
		draw_string(_title, Vector2(tx + (1.0 - ein) * 10.0 * u, -3.0 * u), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIColors.WASHI, ta))
		draw_string(UiKit.UI_FONT, Vector2(tx, 14.0 * u), st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(UIColors.WASHI, 0.85 * ta))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Picto du sceau du bandeau, en washi : picto v2 (ui_icons.gd), glyph UiKit (« water » : la goutte), ou la
## figure « fig:<kind> » qui se trace en boucle (trait washi, point en tête).
func _seal_icon(icon: String, c: Vector2, sz: float, a: float) -> void:
	if icon.begins_with("fig:"):
		var kind := icon.substr(4)
		var pts := UiKit.gesture_points(kind)
		var box := Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
		var k := clampf(fmod(_t, 2.2) / 1.6, 0.0, 1.0)
		var n := int(k * float(pts.size() - 1))
		_pts.resize(pts.size())
		for i in pts.size():
			_pts[i] = box.position + pts[i] * box.size
		draw_polyline(_pts, Color(Toon.WASHI, 0.3 * a), maxf(1.5, sz * 0.08), true)
		if n >= 1:
			draw_polyline(_pts.slice(0, n + 1), Color(Toon.WASHI, a), maxf(1.8, sz * 0.1), true)
		draw_circle(_pts[n], sz * 0.11, Color(Toon.WASHI, a))
		return
	if icon == "" or UiKit.draw_icon(self, icon, c, sz, a, Toon.WASHI):
		return
	UiKit.glyph(self, icon, c, sz * 0.42, Toon.WASHI, Toon.VERMILION, a)


## Main fantôme (planche Coach) : halo washi doux (deux disques, sans flou), index tendu vers `p` (le bout du
## doigt), poing et pouce ; contour sumi, chair washi. press : 1 posée, 0 relevée (le halo s'ouvre un peu).
func _finger(p: Vector2, u: float, a: float, press := 1.0) -> void:
	if a <= 0.01:
		return
	draw_circle(p, (20.0 + 4.0 * (1.0 - press)) * u, Color(Toon.WASHI, 0.22 * a))
	draw_circle(p, 12.0 * u, Color(Toon.WASHI, 0.45 * a))
	var ink := Color(Toon.SUMI, 0.9 * a)
	var skin := Color(Toon.WASHI, a)
	var q := p + Vector2(-4.0, 4.0) * u  # la main vient du bas gauche, comme sur la planche
	# ombre portée légère
	draw_circle(q + Vector2(10.0, 30.0) * u, 11.0 * u, Color(0, 0, 0, 0.15 * a))
	# index (du bout vers la première phalange), puis le poing et le pouce ; contours d'abord, chair ensuite
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
	# pli des doigts repliés
	draw_line(q + Vector2(10.0, 21.0) * u, q + Vector2(14.0, 25.0) * u, Color(Toon.SUMI, 0.35 * a), 1.2 * u, true)


## Trait fantôme devant le héros : le pinceau le trace en boucle, le doigt en tête.
func _ghost_path(hp: Vector3, u: float, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var k := float(i) / 12.0
		var sp := _screen(hp + Vector3(sin(k * PI) * 0.9, 0, -3.6 * k))
		if sp.x < -9000.0:
			return
		pts.append(sp)
	draw_polyline(pts, Color(Toon.WASHI, 0.25 * a), 5.0 * u, true)
	var k2 := clampf(fmod(_t, 2.0) / 1.3, 0.0, 1.0)
	var n := int(k2 * float(pts.size() - 1))
	if n >= 1:
		draw_polyline(pts.slice(0, n + 1), Color(Toon.SUMI, 0.75 * a), 5.0 * u, true)
	_finger(pts[n], u, a)


## Mode pad : le même trait fantôme, tracé dans le pad (le geste du doigt, que le rōnin reproduit).
func _ghost_pad_path(pr: Rect2, u: float, a: float) -> void:
	var c := pr.get_center()
	var hgt := pr.size.y * 0.6
	var pts := PackedVector2Array()
	for i in 13:
		var k := float(i) / 12.0
		pts.append(c + Vector2(sin(k * PI) * hgt * 0.25, hgt * (0.5 - k)))
	draw_polyline(pts, Color(Toon.WASHI, 0.25 * a), 5.0 * u, true)
	var k2 := clampf(fmod(_t, 2.0) / 1.3, 0.0, 1.0)
	var n := int(k2 * float(pts.size() - 1))
	if n >= 1:
		draw_polyline(pts.slice(0, n + 1), Color(Toon.SUMI, 0.75 * a), 5.0 * u, true)
	_finger(pts[n], u, a)


## Mode pad : doigt posé qui se remplit (maintenir), puis qui s'oriente autour du point d'appui.
func _ghost_pad_hold(c: Vector2, u: float, a: float) -> void:
	var k := clampf(fmod(_t, 1.6) / 1.0, 0.0, 1.0)
	draw_arc(c, 16.0 * u, -PI / 2.0, -PI / 2.0 + TAU * k, 28, Color(Toon.GOLD, 0.9 * a), 3.0 * u, true)
	_finger(c, u, a)


## Trait fantôme à travers l'ennemi.
func _ghost_line(from: Vector2, to: Vector2, u: float, a: float) -> void:
	if from.x < -9000.0 or to.x < -9000.0:
		return
	var end := to + (to - from).normalized() * 40.0 * u
	var k := clampf(fmod(_t, 1.8) / 1.0, 0.0, 1.0)
	var tip := from.lerp(end, k)
	draw_line(from, end, Color(Toon.WASHI, 0.25 * a), 4.0 * u, true)
	if k > 0.02:
		draw_line(from, tip, Color(Toon.SUMI, 0.7 * a), 4.0 * u, true)
	_finger(tip, u, a)


## Deux taps rapprochés.
func _ghost_double_tap(c: Vector2, u: float, a: float) -> void:
	if c.x < -9000.0:
		return
	var t := fmod(_t, 1.5)
	for i in 2:
		var tt := t - 0.25 * float(i)
		if tt > 0.0 and tt < 0.6:
			draw_arc(c, (10.0 + 50.0 * tt) * u, 0, TAU, 24, Color(Toon.GOLD, (0.6 - tt) * 1.4 * a), 2.5 * u, true)
	_finger(c, u, a, 0.0 if (t < 0.12 or (t > 0.25 and t < 0.37)) else 1.0)


## Doigt posé qui se remplit (maintenir), devant le héros.
func _ghost_hold(c: Vector2, hp: Vector3, u: float, a: float) -> void:
	var p := _screen(hp + Vector3(0, 0, -2.2))
	if p.x < -9000.0 or c.x < -9000.0:
		return
	var k := clampf(fmod(_t, 1.6) / 1.0, 0.0, 1.0)
	draw_line(c, p, Color(Toon.WASHI, 0.3 * a), 3.0 * u, true)
	draw_arc(p, 16.0 * u, -PI / 2.0, -PI / 2.0 + TAU * k, 28, Color(Toon.GOLD, 0.9 * a), 3.0 * u, true)
	_finger(p, u, a)


## La figure se trace en boucle dans un petit cadre d'encre. col : encre du tracé (alpha 0 : papier clair) ;
## light : cadre clair teinté de col (planche des figures) ; phase : décalage de l'animation (s) ;
## start : point de départ vermillon.
func _draw_figure(kind: String, box: Rect2, u: float, a: float, col := Color(0, 0, 0, 0), light := false, phase := 0.0, start := false) -> void:
	UiKit.draw_gesture(self, _sb, kind, box, u, a, _t + phase, col, light, start)
