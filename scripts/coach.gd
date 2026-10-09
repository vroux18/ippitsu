extends Control
## Coach : le tutoriel se fait en jouant. Petites bulles d'encre posées sur le jeu, près du héros,
## au moment où chaque geste sert : tracer, trancher, esquiver, l'encre, une figure, l'ultime, la course.
## Chaque bulle ne vient qu'une fois (meta.coach_seen) et part dès que le geste est fait (ou au bout
## de quelques secondes). Chaque bulle arrive en arrêt sur image : le jeu se fige, voile d'encre, texte
## en grand, geste fantôme animé, puis « TOUCHE POUR CONTINUER » ; ce toucher relance le jeu (jamais un
## trait) et la bulle reste en petit rappel. La première garde ensuite le temps ralenti jusqu'au trait.
## Leçon des figures (« figures ») : au 2e combat, une planche des six figures, puis « essaie un zigzag ».
## main appelle on_launch, on_event, on_pick, slows, frozen, freeze_tap, is_over_ui et skip ;
## le coach lit l'état de main.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const PowerData = preload("res://scripts/power_data.gd")
const InkStroke = preload("res://scripts/ink_stroke.gd")

const TEXTS := {
	"stroke": "Trace un trait : le rōnin le suit",
	"cut": "Traverse-le pour trancher",
	"dodge": "Glisse vite ou touche pour esquiver",
	"ink": "L'encre se recharge quand tu ne traces pas",
	"ult": "Double tap : ultime",
	"run": "Maintiens pour courir",
	"figures": "Essaie : trace un zigzag",
}
# mode pad (option) : le geste se fait dans le pad du bas, pas sur le terrain
const TEXTS_PAD := {
	"stroke": "Trace dans le pad : le rōnin suit ton geste",
	"dodge": "Glisse vite ou touche : il bondit loin du danger",
	"figures": "Essaie : un zigzag dans le pad",
}
# leçon des figures (planche en arrêt sur image) : une figure reconnue donne d'elle-même +15 % de dégâts
# à sa ruée et +1 chaîne si elle touche (powers.figure_launch, main._on_dash_finished) ; son rouleau
# (PowerData.FIG_UNLOCK) débloque sa technique
const LESSON := [
	"Trace une forme : ta ruée devient plus forte",
	"Figure reconnue : +15 % de dégâts, +1 chaîne si elle touche",
	"Son rouleau débloque sa technique : boucle = toupie, zigzag = éclair...",
	"L'encre se colore quand la figure est reconnue",
]
# technique de chaque figure (celle de son rouleau), en petit sous la figure
const TECH := {"loop": "toupie", "zigzag": "éclair", "straight": "iaï", "return": "garde", "enso": "ensō", "hook": "estoc"}
const GLUE := [":", ";", "!", "?", "%", "=", "»", "..."]
const FIG_TEXT := {
	"loop": "Dessine une boucle : la toupie",
	"zigzag": "Trace un zigzag : l'éclair",
	"straight": "Un long trait droit : l'iaï",
	"return": "Un aller-retour : la garde",
	"enso": "Un grand cercle : l'ensō",
	"hook": "Un trait en crochet : l'estoc",
}
# durée de vie (s réelles, arrêt sur image non compté) ; 0 : jusqu'au geste
const LIFE := {"stroke": 0.0, "cut": 7.0, "dodge": 5.0, "ink": 6.0, "figure": 10.0, "ult": 8.0, "run": 7.0, "figures": 14.0}
const ORDER := ["stroke", "dodge", "cut", "figures", "ult", "figure", "ink", "run"]
const GAP := 0.8  # silence entre deux bulles
const SLOW := 0.3  # temps ralenti tant que le premier trait n'est pas tracé
const FREEZE_HINT := 0.8  # arrêt sur image : « TOUCHE POUR CONTINUER » après ce délai (s réelles)
const FREEZE_MAX := 12.0  # garde-fou : l'arrêt sur image se lève seul (s réelles)
const FREEZE_MAX_BOT := 3.0  # robot (CI) : jamais bloqué longtemps
const FREEZE_HARD_MS := 60000  # garde-fou absolu (horloge murale), même si le coach ne tournait plus
const VEIL := 0.32  # voile d'encre de l'arrêt sur image
const BIG := 1.35  # texte de la bulle agrandi pendant l'arrêt sur image

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
var _ui := FontVariation.new()
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 1


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


## Invite « TOUCHE POUR CONTINUER » affichée (le prochain toucher relance le jeu).
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


## Ruée lancée (trait, ou bond d'esquive) ; shape : figure reconnue ("" sinon).
func on_launch(dodge: bool, shape: String) -> void:
	if mark == "":
		return
	if dodge:
		if mark == "dodge":
			_finish()
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
		"dodge":
			return _windup_enemy() != null
		"figures":
			# après les bases (trancher, esquiver), dès le 2e combat, avec un ennemi sur qui essayer
			return seen("cut") and (seen("dodge") or int(main.room) >= 3) and int(main.room) >= 2 \
				and not bool(main.in_hub) and not bool(main.hero.dashing) and _first_enemy() != null
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


## Ennemi qui arme son attaque (pour « esquive »), ou null.
func _windup_enemy() -> Node3D:
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead and not e.dummy and str(e.get("_state")) == "windup":
			var n: Node3D = e
			return n
	return null


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
		if _gap <= 0.0:
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
			# une attaque annoncée passe avant le reste (sauf le tout premier trait)
			if mark != "dodge" and mark != "stroke" and not seen("dodge") and _wanted("dodge"):
				_show("dodge")
			elif mark == "ink" and _life > 1.5 and float(main.elan) >= float(main.elan_max()) * 0.9:
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
	if main == null or not active() or not _in_play() or size.x < 10.0:
		return
	var u := size.x / 400.0
	var insets := UiKit.safe_insets(size)
	# arrêt sur image : léger voile d'encre sur le jeu figé (la bulle et le geste fantôme restent nets)
	if _veil > 0.005:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.SUMI, _veil))
	if _skip_shown():
		_draw_skip(u, insets)
	if mark == "":
		return
	var a := clampf(_t / 0.3, 0.0, 1.0)
	var big := _big
	var hero: Node3D = main.hero
	var hp := hero.position
	var head := _screen(hp + Vector3(0, 2.3, 0))
	var feet := _screen(hp)
	var txt := String(TEXTS.get(mark, ""))
	# mode pad : les gestes fantômes se font dans le pad (le terrain montre seulement la bulle)
	var pr := _pad()
	var in_pad := pr.size.x >= 10.0
	if in_pad:
		txt = String(TEXTS_PAD.get(mark, txt))
		feet = pr.get_center()
	match mark:
		"stroke":
			if in_pad:
				_ghost_pad_path(pr, u, a)
			else:
				_ghost_path(hp, u, a)
			_bubble(txt, head, u, a, false, 0.0, big)
		"cut":
			var e := _first_enemy()
			if e != null:
				var ep := _screen(e.position)
				_ghost_line(_screen(hp), ep, u, a)  # chemin du rōnin sur le terrain (aussi en mode pad)
				_bubble(txt, _screen(e.position + Vector3(0, 2.2, 0)), u, a, false, 0.0, big)
			else:
				_bubble(txt, head, u, a, false, 0.0, big)
		"dodge":
			# arrêt sur image : l'ennemi qui arme son coup est cerclé de vermillon
			var we := _windup_enemy()
			if we != null and _fz >= 0.0:
				var wp := _screen(we.position + Vector3(0, 0.9, 0))
				if wp.x > -9000.0:
					var wpulse := 0.5 + 0.5 * sin(_t * 7.0)
					draw_arc(wp, (34.0 + 6.0 * wpulse) * u, 0, TAU, 36, Color(Toon.VERMILION, (0.55 + 0.4 * wpulse) * a), 3.0 * u, true)
			_ghost_flick(feet, u, a)
			_bubble(txt, head, u, a, false, 0.0, big)
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
			_bubble(txt, Vector2(gr.position.x - 10.0 * u, gr.get_center().y), u, a, true, 0.0, big)
		"figure":
			var ft := String(FIG_TEXT.get(_fig, "Dessine la figure"))
			var r := _bubble(ft, head, u, a, false, 64.0 * u, big)
			var demo := Rect2(Vector2(r.end.x - 60.0 * u, r.position.y + 4.0 * u), Vector2(56.0 * u, r.size.y - 8.0 * u))
			_draw_figure(_fig, demo, u, a)
		"figures":
			if _fz >= 0.0:
				_draw_lesson(u, a)  # planche des six figures
			else:
				# rappel : le zigzag fantôme, à l'encre de sa figure
				var r := _bubble(txt, head, u, a, false, 64.0 * u, big)
				var demo := Rect2(Vector2(r.end.x - 60.0 * u, r.position.y + 4.0 * u), Vector2(56.0 * u, r.size.y - 8.0 * u))
				var zc: Color = InkStroke.FIG_INK.get("zigzag", Toon.GOLD)
				_draw_figure("zigzag", demo, u, a, zc)
		"ult":
			_ghost_double_tap(feet, u, a)
			_bubble(txt, head, u, a, false, 0.0, big)
		"run":
			if in_pad:
				_ghost_pad_hold(feet, u, a)
			else:
				_ghost_hold(feet, hp, u, a)
			_bubble(txt, head, u, a, false, 0.0, big)
	if _fz >= 0.0:
		_draw_hint(u, insets)


## « TOUCHE POUR CONTINUER » : pastille en bas, un instant après l'arrêt sur image.
func _draw_hint(u: float, insets: Vector2) -> void:
	var k := clampf((_fz - FREEZE_HINT) / 0.3, 0.0, 1.0)
	if k <= 0.0:
		return
	var fs := int(12.0 * u)
	var txt := UiKit.plain("TOUCHE POUR CONTINUER")
	var tw := _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := size.y - insets.y - 96.0 * u
	var pr := _pad()
	if pr.size.x >= 10.0:
		y = minf(y, pr.position.y - 72.0 * u)  # au-dessus du pad (et de PASSER)
	var r := Rect2(Vector2(size.x * 0.5 - tw * 0.5 - 16.0 * u, y - 15.0 * u), Vector2(tw + 32.0 * u, 30.0 * u))
	UiKit.box(_sb, Color(Toon.ui_paper, 0.92 * k), int(15.0 * u), Color(Toon.ui_ink, 0.5 * k), int(maxf(1.0, 1.2 * u)))
	draw_style_box(_sb, r)
	var al := k * (0.7 + 0.3 * sin(_t * 4.0))
	UiKit.text(self, _ui, txt, Vector2(size.x * 0.5, y + fs * 0.36), fs, Color(Toon.ui_ink, al))


## Leçon des figures (arrêt sur image) : planche de papier, quelques lignes, puis les six figures qui se
## tracent en boucle, chacune à l'encre de sa couleur (ink_stroke FIG_INK), son nom et sa technique.
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
		var col: Color = InkStroke.FIG_INK.get(kind, Toon.GOLD)
		var cx := gx + cell * (float(i % 3) + 0.5)
		var cy := y + cell_h * floorf(float(i) / 3.0)
		var box := Rect2(Vector2(cx - tile * 0.5, cy), Vector2(tile, tile))
		_draw_figure(kind, box, u, a, col, true, float(i) * 0.37)
		var lc := Color(Toon.ui_ink).lerp(col, 0.65)
		UiKit.text(self, _ui, UiKit.plain(String(UiKit.FIG_WORD.get(kind, "FIGURE"))), Vector2(cx, cy + tile + float(lfs) * 1.3), lfs, Color(lc, a))
		UiKit.text(self, _ui, UiKit.plain(String(TECH.get(kind, ""))), Vector2(cx, cy + tile + float(lfs) * 1.5 + float(sfs) * 1.3), sfs, Color(Toon.ui_ink, 0.6 * a))


## Petit « PASSER » dans le coin bas gauche (mode pad : juste au-dessus du pad, qui garde ses touchers).
func _draw_skip(u: float, insets: Vector2) -> void:
	_skip_rect = Rect2(Vector2(14.0 * u, size.y - insets.y - 44.0 * u), Vector2(76.0 * u, 28.0 * u))
	var pr := _pad()
	if pr.size.x >= 10.0:
		_skip_rect.position.y = minf(_skip_rect.position.y, pr.position.y - 36.0 * u)
	UiKit.box(_sb, Color(Toon.ui_paper, 0.8), int(14.0 * u), Color(Toon.ui_ink, 0.35), int(maxf(1.0, 1.2 * u)))
	draw_style_box(_sb, _skip_rect)
	var fs := int(11.0 * u)
	UiKit.text(self, _ui, "PASSER", Vector2(_skip_rect.get_center().x, _skip_rect.get_center().y + fs * 0.36), fs, Color(Toon.ui_ink, 0.8))


## Bulle d'encre (papier, liseré d'encre, queue vers `anchor`). side : à gauche de l'ancre (sinon au-dessus).
## extra : place réservée à droite du texte (démonstration de la figure). big : agrandie (arrêt sur image),
## et ramenée vers le centre de l'écran. Renvoie le cadre de la bulle.
func _bubble(txt: String, anchor: Vector2, u: float, a: float, side: bool, extra := 0.0, big := 1.0) -> Rect2:
	var t := UiKit.plain(txt)
	var ub := u * big
	var fs := int(14.0 * ub)
	var maxw := size.x * 0.84 - extra - 28.0 * ub
	var tw := _ui.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > maxw and tw > 1.0:
		fs = maxi(8, int(float(fs) * maxw / tw))
		tw = _ui.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := 40.0 * ub if extra <= 0.0 else maxf(64.0 * u, 40.0 * ub)
	var w := tw + 28.0 * ub + extra
	var anc := anchor
	if anc.x < -9000.0:
		anc = Vector2(size.x * 0.5, size.y * 0.4)
	var top_clear: float = main.hud.top_clear()
	var top_min := top_clear + 6.0 * u  # sous les pastilles du haut (et la barre du boss)
	var pos := Vector2.ZERO
	var tail := PackedVector2Array()
	if side:
		if side and w > anc.x - 12.0 * u:
			fs = maxi(8, int(float(fs) * (anc.x - 40.0 * u) / maxf(w, 1.0)))
			tw = _ui.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			w = tw + 28.0 * ub
		pos = Vector2(anc.x - 12.0 * u - w, anc.y - h * 0.5)
		pos.x = maxf(pos.x, 8.0 * u)
		tail = PackedVector2Array([Vector2(pos.x + w - 2.0 * u, anc.y - 7.0 * u), anc, Vector2(pos.x + w - 2.0 * u, anc.y + 7.0 * u)])
	else:
		# arrêt sur image : la bulle agrandie glisse vers le centre (la queue pointe toujours l'ancre)
		var kc := clampf((big - 1.0) / maxf(BIG - 1.0, 0.01), 0.0, 1.0)
		pos = Vector2(lerpf(anc.x, size.x * 0.5, kc * 0.6) - w * 0.5, anc.y - h - 14.0 * u)
		pos.x = clampf(pos.x, 10.0 * u, size.x - w - 10.0 * u)
		pos.y = clampf(pos.y, top_min, size.y - h - 80.0 * u)
		var tx := clampf(anc.x, pos.x + 16.0 * u, pos.x + w - 16.0 * u)
		var tip := Vector2(anc.x, minf(anc.y, pos.y + h + 14.0 * u))
		if tip.y < pos.y + h + 4.0 * u:
			tip.y = pos.y + h + 10.0 * u
		tail = PackedVector2Array([Vector2(tx - 8.0 * u, pos.y + h - 2.0 * u), tip, Vector2(tx + 8.0 * u, pos.y + h - 2.0 * u)])
	# légère respiration à l'apparition
	var k := UiKit.ease_out(a)
	pos.y += (1.0 - k) * 8.0 * u
	var r := Rect2(pos, Vector2(w, h))
	var ink := Color(Toon.ui_ink, 0.9 * a)
	UiKit.box(_sb, Color(Toon.ui_paper, 0.95 * a), int(14.0 * u), ink, int(maxf(1.0, 1.6 * u)))
	_sb.shadow_color = Color(0, 0, 0, 0.25 * a)
	_sb.shadow_size = int(8.0 * u)
	draw_colored_polygon(tail, Color(Toon.ui_paper, 0.95 * a))
	draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2]]), ink, 1.6 * u, true)
	draw_style_box(_sb, r)
	# trait vermillon au pinceau à gauche, puis le texte
	draw_rect(Rect2(r.position + Vector2(9.0 * u, h * 0.3), Vector2(3.0 * u, h * 0.4)), Color(Toon.VERMILION, a))
	draw_string(_ui, Vector2(r.position.x + 18.0 * ub, r.position.y + h * 0.5 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.ui_ink, a))
	return r


## Bout du doigt fantôme (pastille vermillon cerclée de papier).
func _finger(p: Vector2, u: float, a: float, press := 1.0) -> void:
	draw_circle(p + Vector2(3, 5) * u, 9.0 * u, Color(0, 0, 0, 0.18 * a))
	draw_circle(p, (7.0 + 1.5 * (1.0 - press)) * u, Color(Toon.VERMILION, 0.85 * a))
	draw_arc(p, 11.0 * u, 0, TAU, 20, Color(Toon.WASHI, 0.7 * a), 1.6 * u, true)


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


## Coup de doigt bref (esquive) : un tap qui rebondit, puis un petit glissé.
func _ghost_flick(c: Vector2, u: float, a: float) -> void:
	if c.x < -9000.0:
		return
	var t := fmod(_t, 1.4)
	var p := clampf(t / 0.18, 0.0, 1.0)
	var tip := c + Vector2(34.0, -22.0) * u * p
	if p > 0.0:
		draw_line(c, tip, Color(Toon.WASHI, 0.6 * a), 3.0 * u, true)
	if t < 0.6:
		draw_arc(c, (10.0 + 40.0 * t) * u, 0, TAU, 24, Color(Toon.WASHI, (0.6 - t) * a), 2.0 * u, true)
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
## light : cadre clair teinté de col (planche des figures) ; phase : décalage de l'animation (s).
func _draw_figure(kind: String, box: Rect2, u: float, a: float, col := Color(0, 0, 0, 0), light := false, phase := 0.0) -> void:
	UiKit.draw_gesture(self, _sb, kind, box, u, a, _t + phase, col, light)
