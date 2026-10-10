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
	"seal": "Brise le sceau",
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
	"seal": "Trace sa figure à travers lui.",
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
# technique de chaque figure (celle de son rouleau), en petit sous la figure ; glossaire du handoff v2 §6 :
# l'ensō déclenche l'onde de choc (« ensō » sous ENSO ne répétait que le nom de la figure)
const TECH := {"loop": "toupie", "zigzag": "éclair", "straight": "iaï", "return": "garde", "enso": "onde de choc", "hook": "estoc",
	"wave": "ressac", "point": "kunai", "triangle": "kekkai"}
const GLUE := [":", ";", "!", "?", "%", "=", "»", "..."]
const FIG_TEXT := {
	"loop": "Une boucle",
	"zigzag": "Un zigzag",
	"straight": "Un trait droit",
	"return": "Un aller-retour",
	"enso": "Un grand cercle",
	"hook": "Un crochet",
	"wave": "Une vague",
	"point": "Une pointe",
	"triangle": "Un triangle",
}
# durée de vie (s réelles, arrêt sur image non compté) ; 0 : jusqu'au geste
const LIFE := {"stroke": 0.0, "cut": 7.0, "ink": 6.0, "figure": 10.0, "ult": 8.0, "run": 7.0, "figures": 14.0, "seal": 9.0}
const ORDER := ["stroke", "cut", "figures", "seal", "ult", "figure", "ink", "run"]
# leçons hors tutoriel (meta.COACH_EXTRA) : elles viennent une fois, même le tutoriel fini (le premier yōkai scellé
# arrive à l'étape 2, souvent après la fin du tutoriel)
const EXTRA := ["seal"]
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
# calques (voir « dessin ») : voile, planche des figures, bouton passer, bandeau et son sceau, deux mains fantômes
var _veil_n: _Part
var _board_n: _Part
var _skip_n: _Part
var _banner_n: _Part
var _seal_n: _Part
var _fing: Array = []  # [geste fantôme, invite à toucher]
var _fa := [0.0, 0.0]  # opacité de chaque main à cette image (0 : cachée)
var _fing_u := -1.0  # échelle à laquelle les mains sont dessinées
var _shown := false  # le coach montre quelque chose à cette image (en jeu, tutoriel actif)
var _drew := false  # le coach a dessiné à l'image précédente (une image de plus pour s'effacer)
var _lay := {}  # mise en page de la planche des figures
var _rows: Array = []  # lignes de la planche, coupées une fois
var _rows_key: Array = []


## Calque du coach : ses commandes de dessin restent en place d'une image à l'autre ; il n'est redessiné que si
## sa signature change (coach._resign) ; on l'anime par sa transformation et son modulate.
class _Part extends Node2D:
	var paint: Callable
	var sig: Array = []

	func _draw() -> void:
		var _pt := Time.get_ticks_usec() if Perf.on else 0
		paint.call(self)
		if _pt != 0:
			Perf.add(&"coach_draw", _pt)


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
	_make_parts()


static func _cubic(out: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		var c := p2.lerp(p3, t)
		out.append(a.lerp(b, t).lerp(b.lerp(c, t), t))


func active() -> bool:
	if main == null or main.meta == null:
		return false
	return not bool(main.meta.tuto_done) or mark in EXTRA or _extra_due()


## Leçon hors tutoriel à montrer maintenant (le tutoriel fini) : premier yōkai scellé croisé.
func _extra_due() -> bool:
	return not seen("seal") and _in_play() and _sealed() != null


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
	var se := _sealed() if mark == "seal" else null
	if mark == "stroke" or (mark == "figure" and shape == _fig) or (mark == "figures" and shape != "") \
			or (se != null and shape == String(se.seal_fig)):
		_finish()


## Gestes signalés par main : "hit" (le trait a touché), "ult", "run".
func on_event(ev: String) -> void:
	if (ev == "hit" and mark == "cut") or (ev == "ult" and mark == "ult") or (ev == "run" and mark == "run") or (ev == "seal" and mark == "seal"):
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
		"seal":
			# premier yōkai scellé (après la leçon des figures si le tutoriel est en cours)
			return (seen("figures") or bool(main.meta.tuto_done)) and not bool(main.hero.dashing) and _sealed() != null
		"ult":
			return float(main.ult) >= 1.0 and not bool(main.in_hub)
		"run":
			var ar = main.arena
			return bool(main._explore) and not bool(main.in_hub) and bool(ar.stage) and int(main._enc) < 0 \
				and int(ar.zones_done()) >= 1 and int(ar.zones_left()) > 0
	return false


## Yōkai scellé vivant et visible le plus proche du héros (leçon « seal »), ou null.
func _sealed() -> Node3D:
	if main.get("enemies") == null or not is_instance_valid(main.hero):
		return null
	var best: Node3D = null
	var bd := 1.0e9
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or e.is_harmless() or String(e.seal_fig) == "":
			continue
		var d: float = (e as Node3D).position.distance_to(main.hero.position)
		if d < bd:
			bd = d
			best = e
	return best


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
	var _pt := Time.get_ticks_usec() if Perf.on else 0
	size = get_viewport_rect().size
	if main == null:
		if _pt != 0:
			Perf.add(&"coach", _pt)
		return
	if not active():
		if mark != "" or _fig != "":
			clear()
		if visible:
			visible = false
		if _pt != 0:
			Perf.add(&"coach", _pt)
		return
	visible = true
	if not _in_play():
		_update_parts()  # (pause, rouleaux, mort : rien d'affiché)
		if _pt != 0:
			Perf.add(&"coach", _pt)
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
				if bool(main.meta.tuto_done) and not EXTRA.has(sid):
					continue  # tutoriel fini : seules les leçons hors tutoriel
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
	_update_parts()
	if _pt != 0:
		Perf.add(&"coach", _pt)


# ------------------------------------------------------------------ dessin
# Ce qui ne bouge pas d'une image à l'autre (voile percé du projecteur, bandeau, sceau, planche des figures,
# bouton passer, main fantôme) vit sur des calques enfants (_Part) : leurs commandes de dessin restent en place
# et ne sont refaites que si ce qu'ils montrent change (signature) ; fondus, échelle et déplacements passent par
# leur modulate et leur transformation. Avant, tout était redessiné à chaque image (une centaine de polygones
# rien que pour le voile, chacun un tampon de sommets refait par le rendu) : les bulles saccadaient sur téléphone.
# Le coach lui-même ne dessine plus que ce qui s'anime vraiment (gestes fantômes, traits des figures, invite).

func _screen(p: Vector3) -> Vector2:
	var cam: Camera3D = main.cam
	if cam.is_position_behind(p):
		return Vector2(-9999, -9999)
	return cam.unproject_position(p)


func _make_parts() -> void:
	_veil_n = _part(_paint_veil, true)
	_board_n = _part(_paint_board, true)  # (sous les traits animés des figures, dessinés par le coach)
	_skip_n = _part(_paint_skip)
	_banner_n = _part(_paint_banner)
	_seal_n = _part(_paint_seal, false, _banner_n)
	_seal_n.rotation = -0.087  # posé comme un tampon (penché de 5°)
	for i in 2:
		var f := _part(_paint_finger)
		_part(_paint_halo, true, f)
		_fing.append(f)


func _part(paint: Callable, behind := false, parent: Node = null) -> _Part:
	var p := _Part.new()
	p.paint = paint
	p.show_behind_parent = behind
	p.visible = false
	(parent if parent != null else self).add_child(p)
	return p


## Le calque ne se redessine que si sa signature change.
static func _resign(p: _Part, sig: Array) -> void:
	if p.sig != sig:
		p.sig = sig
		p.queue_redraw()


## Calques du coach à cette image : signatures, transformations, fondus (appelé à chaque _process).
func _update_parts() -> void:
	_shown = main != null and active() and _in_play() and size.x >= 10.0
	var u := size.x / 400.0
	if _shown and u != _fing_u:
		_fing_u = u
		for f in _fing:
			f.queue_redraw()
			f.get_child(0).queue_redraw()
	_update_veil(u)
	_update_skip(u)
	_update_banner(u)
	_update_board(u)
	if not _shown or mark == "":
		for f in _fing:
			f.visible = false
	# le coach ne se redessine que s'il a quelque chose d'animé à montrer (et une fois pour s'effacer)
	if (_shown and mark != "") or _drew:
		queue_redraw()


## Arrêt sur image : voile d'encre percé d'un projecteur (ellipse) sur le geste à faire. Dessiné une fois à pleine
## opacité ; son fondu suit _veil par le modulate du calque.
func _update_veil(u: float) -> void:
	var on := _shown and _veil > 0.005
	if on:
		var hp: Vector3 = main.hero.position
		var pr := _pad()
		var in_pad := pr.size.x >= 10.0
		var feet := pr.get_center() if in_pad else _screen(hp)
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
			"seal":
				var se := _sealed()
				# le projecteur prend le yōkai et son cadenas (au-dessus de sa tête)
				sc = _screen(se.seal_anchor()).lerp(feet, 0.3) if se != null else feet
				sr = Vector2(110.0, 170.0) * u
		if sc.x < -9000.0 or mark == "" or mark == "figures":
			_resign(_veil_n, [1, size])
		else:
			_resign(_veil_n, [2, size, sc.snapped(Vector2(0.25, 0.25)), sr.snapped(Vector2(0.25, 0.25))])
		_veil_n.modulate.a = _veil / VEIL
	_veil_n.visible = on


func _paint_veil(ci: CanvasItem) -> void:
	var s: Array = _veil_n.sig
	if s.is_empty():
		return
	if int(s[0]) == 1:
		ci.draw_rect(Rect2(Vector2.ZERO, s[1]), Color(Toon.VEIL, VEIL))
	else:
		_draw_spot(ci, s[1], s[2], s[3])


## Voile d'encre percé d'un projecteur : ellipse claire (centre c, demi-axes r) autour du geste, le reste
## de l'écran sous le voile ; liseré washi pointillé sur l'ellipse (planche Coach). Sans flou : anneau de quads.
## (À pleine opacité du voile : le calque porte le fondu.) Les quads partent en un seul tableau de triangles et
## le liseré en une seule multiligne : deux appels de dessin au lieu d'une centaine.
func _draw_spot(ci: CanvasItem, sz: Vector2, c: Vector2, r: Vector2) -> void:
	var n := 48
	var veil := Color(Toon.VEIL, VEIL)
	var prev_e := Vector2.ZERO
	var prev_b := Vector2.ZERO
	var tri := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in n + 1:
		var ang := TAU * float(i) / float(n)
		var d := Vector2(cos(ang), sin(ang))
		var e := c + Vector2(d.x * r.x, d.y * r.y)
		# point du bord de l'écran dans la même direction (le rayon sort par le côté le plus proche)
		var tx := 1.0e9
		if absf(d.x) > 0.0001:
			tx = ((sz.x + 4.0 - c.x) if d.x > 0.0 else (-4.0 - c.x)) / d.x
		var ty := 1.0e9
		if absf(d.y) > 0.0001:
			ty = ((sz.y + 4.0 - c.y) if d.y > 0.0 else (-4.0 - c.y)) / d.y
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
				# triangulé comme le faisait draw_colored_polygon (le quad peut être concave près des coins)
				var tris := Geometry2D.triangulate_polygon(_pts)
				var base := tri.size()
				tri.append_array(_pts)
				for t in tris:
					idx.append(base + t)
		prev_e = e
		prev_b = b
	if not idx.is_empty():
		var cols := PackedColorArray()
		cols.resize(tri.size())
		cols.fill(veil)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, tri, cols)
	# liseré pointillé (4 / 8 u) sur l'ellipse
	var u := sz.x / 400.0
	var per := 2.0 * PI * sqrt((r.x * r.x + r.y * r.y) * 0.5)
	var m := maxi(12, int(per / (12.0 * u)))
	var dash := PackedVector2Array()
	for j in m:
		var a0 := TAU * float(j) / float(m)
		var a1 := a0 + TAU / float(m) * 0.35
		dash.append(c + Vector2(cos(a0) * r.x, sin(a0) * r.y))
		dash.append(c + Vector2(cos(a1) * r.x, sin(a1) * r.y))
	ci.draw_multiline(dash, Color(Toon.WASHI, 0.5), 1.5 * u, true)


func _draw() -> void:
	var _pt := Time.get_ticks_usec() if Perf.on else 0
	_fa[0] = 0.0
	_fa[1] = 0.0
	_drew = _shown and mark != ""
	if not _drew:
		if _pt != 0:
			Perf.add(&"coach_draw", _pt)
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
		"seal":
			var se := _sealed()
			if se != null:
				_ghost_line(_screen(hp), _screen(se.position), u, a)
				_show_lock(se, u, a)
		"figures":
			if _fz >= 0.0:
				_draw_lesson_traces(u, a)  # traits animés de la planche des six figures (le calque porte le reste)
		"ult":
			_ghost_double_tap(feet, u, a)
		"run":
			if in_pad:
				_ghost_pad_hold(feet, u, a)
			else:
				_ghost_hold(feet, hp, u, a)
	if _fz >= 0.0:
		_draw_hint(u, insets)
	_place_fingers()
	if _pt != 0:
		Perf.add(&"coach_draw", _pt)


## Leçon « seal » : le cadenas du yōkai (celui du HUD, redessiné par-dessus le voile), cerclé d'un anneau d'or
## qui pulse : c'est sa figure qu'il faut tracer.
func _show_lock(se: Node3D, u: float, a: float) -> void:
	var p := _screen(se.seal_anchor())
	if p.x < -9000.0:
		return
	var hud: Control = main.hud
	var c: Vector2 = hud.call("_lock_at", p, hud.size, hud.size.x / 400.0)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_arc(c + Vector2(0, -4.0 * u), (24.0 + 4.0 * pulse) * u, 0.0, TAU, 48, Color(Toon.GOLD, (0.55 + 0.45 * pulse) * a), 2.5 * u, true)
	UiKit.seal_lock(self, c, hud.LOCK_S * hud.size.x / 400.0, String(se.seal_fig), a, float(se.seal_rico), 0.0, 0.0, _t)


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
	_finger(c + Vector2(0, 3.0 * u * press), u, k, 1.0 - press, 1)


## Figures de la planche : les six du départ, puis celles de l'arbre déjà apprises (meta.fig_learned).
func _lesson_figs() -> Array:
	var out: Array = []
	for f in UiKit.FIGURES:
		if not String(f) in UiKit.FIGURES_TREE or (main != null and main.meta != null and bool(main.meta.fig_learned(String(f)))):
			out.append(String(f))
	return out


## Leçon des figures (arrêt sur image) : planche de papier, une ligne, puis les figures connues qui se
## tracent en boucle. Vignettes monotones : même papier assombri, liseré sumi fin, trait à l'encre sumi,
## point de départ vermillon (seul accent) ; nom et technique à l'encre.
## Mise en page (planche à sa place finale ; elle glisse de 10 u à l'entrée par la position du calque).
func _lesson_layout(u: float) -> Dictionary:
	var w := minf(size.x - 32.0 * u, 372.0 * u)
	var pad := 16.0 * u
	var fs := int(13.0 * u)
	var tfs := int(22.0 * u)
	var lfs := int(11.0 * u)
	var sfs := int(10.0 * u)
	var text_w := w - 2.0 * pad - 14.0 * u
	var rk := [fs, text_w]
	if _rows_key != rk:
		# lignes coupées une fois (UiKit.wrap mesure chaque mot)
		_rows_key = rk
		_rows = []  # [ligne, début d'un point]
		for s in LESSON:
			var first := true
			for l in UiKit.wrap(_ui, UiKit.plain(String(s)), fs, text_w, GLUE):
				_rows.append([String(l), first])
				first = false
	var lh := float(fs) * 1.45
	var cell := minf((w - 2.0 * pad) / 3.0, 112.0 * u)
	var tile := cell * 0.6
	var cell_h := tile + float(lfs) * 1.5 + float(sfs) * 1.5 + 8.0 * u
	var head_h := float(tfs) * 1.4
	var figs := _lesson_figs()
	var h := pad + head_h + 6.0 * u + float(_rows.size()) * lh + 12.0 * u + ceilf(float(figs.size()) / 3.0) * cell_h + pad
	var top_min: float = main.hud.top_clear()
	top_min += 8.0 * u
	var y0 := clampf(size.y * 0.44 - h * 0.5, top_min, maxf(top_min, size.y - h - 130.0 * u))
	var r := Rect2(Vector2((size.x - w) * 0.5, y0), Vector2(w, h))
	var gy := r.position.y + pad + head_h + 6.0 * u + float(_rows.size()) * lh + 12.0 * u
	return {"u": u, "r": r, "pad": pad, "fs": fs, "tfs": tfs, "lfs": lfs, "sfs": sfs, "lh": lh, "cell": cell, "tile": tile,
		"cell_h": cell_h, "head_h": head_h, "figs": figs, "gx": r.position.x + (w - 3.0 * cell) * 0.5, "gy": gy}


## Case de la figure i de la planche (vignette).
static func _lesson_tile(lay: Dictionary, i: int) -> Rect2:
	var cell: float = lay.cell
	var tile: float = lay.tile
	var cx: float = float(lay.gx) + cell * (float(i % 3) + 0.5)
	var cy: float = float(lay.gy) + float(lay.cell_h) * floorf(float(i) / 3.0)
	return Rect2(Vector2(cx - tile * 0.5, cy), Vector2(tile, tile))


func _update_board(u: float) -> void:
	_lesson_bottom = -1.0
	var on := _shown and mark == "figures" and _fz >= 0.0
	if on:
		var a := clampf(_t / 0.3, 0.0, 1.0)
		_lay = _lesson_layout(u)
		var r: Rect2 = _lay.r
		_resign(_board_n, [size, r, _lay.figs, _rows_key])
		var dy := (1.0 - UiKit.ease_out(a)) * 10.0 * u
		_board_n.position = Vector2(0.0, dy)
		_board_n.modulate.a = a
		_lesson_bottom = r.end.y + dy
	_board_n.visible = on


## Calque de la planche : papier, titre, ligne, vignettes (cadre, tracé pâle, départ), noms (pleine opacité).
func _paint_board(ci: CanvasItem) -> void:
	if _lay.is_empty():
		return
	var u: float = _lay.u
	var r: Rect2 = _lay.r
	var pad: float = _lay.pad
	var fs: int = _lay.fs
	var tfs: int = _lay.tfs
	var lfs: int = _lay.lfs
	var sfs: int = _lay.sfs
	var lh: float = _lay.lh
	var ink := Color(Toon.ui_ink, 0.9)
	UiKit.box(_sb, Color(Toon.ui_paper, 0.96), int(16.0 * u), ink, int(maxf(1.0, 1.6 * u)))
	_sb.shadow_color = Color(0, 0, 0, 0.3)
	_sb.shadow_size = int(10.0 * u)
	ci.draw_style_box(_sb, r)
	# titre, souligné d'un trait vermillon
	var y := r.position.y + pad + float(tfs) * 0.9
	var ttw := UiKit.text(ci, UiKit.TITLE_FONT, UiKit.plain("LES FIGURES"), Vector2(r.get_center().x, y), tfs, Color(Toon.ui_ink, 1.0))
	ci.draw_rect(Rect2(Vector2(r.get_center().x - ttw * 0.3, y + 6.0 * u), Vector2(ttw * 0.6, 3.0 * u)), Color(Toon.VERMILION, 1.0))
	y = r.position.y + pad + float(_lay.head_h) + 6.0 * u
	# les lignes, chaque point marqué d'une goutte vermillon
	for row in _rows:
		var line := String(row[0])
		var by := y + lh * 0.5 + float(fs) * 0.36
		if bool(row[1]):
			ci.draw_circle(Vector2(r.position.x + pad + 4.0 * u, y + lh * 0.5), 3.0 * u, Color(Toon.VERMILION, 1.0))
		ci.draw_string(_ui, Vector2(r.position.x + pad + 14.0 * u, by), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.ui_ink, 1.0))
		y += lh
	# les figures (trois par ligne) : la partie fixe des vignettes, et leurs noms
	var figs: Array = _lay.figs
	var tile: float = _lay.tile
	for i in figs.size():
		var kind := String(figs[i])
		var box := _lesson_tile(_lay, i)
		var cx := box.get_center().x
		var cy := box.position.y
		UiKit.draw_gesture(ci, _sb, kind, box, u, 1.0, 0.0, Toon.ui_ink, true, true, 1)
		UiKit.text(ci, _ui, UiKit.plain(String(UiKit.FIG_WORD.get(kind, "FIGURE"))), Vector2(cx, cy + tile + float(lfs) * 1.3), lfs, Color(Toon.ui_ink, 1.0))
		UiKit.text(ci, _ui, UiKit.plain(String(TECH.get(kind, ""))), Vector2(cx, cy + tile + float(lfs) * 1.5 + float(sfs) * 1.3), sfs, Color(Toon.ui_ink, 0.6))


## Traits animés de la planche (décalés dans le temps), au-dessus du calque.
func _draw_lesson_traces(u: float, a: float) -> void:
	if _lay.is_empty():
		return
	var off := Vector2(0.0, _board_n.position.y)
	var figs: Array = _lay.figs
	for i in figs.size():
		var box := _lesson_tile(_lay, i)
		box.position += off
		UiKit.draw_gesture(self, _sb, String(figs[i]), box, u, a, _t + float(i) * 0.37, Toon.ui_ink, true, true, 2)


## Passer le tutoriel : bouton rond sumi dans le coin bas gauche, picto « sauter » (double chevron et barre),
## sans un mot (mode pad : juste au-dessus du pad, qui garde ses touchers).
func _update_skip(u: float) -> void:
	var on := _shown and _skip_shown()
	if on:
		var insets := UiKit.safe_insets(size)
		var d := 36.0 * u
		_skip_rect = Rect2(Vector2(14.0 * u, size.y - insets.y - 14.0 * u - d), Vector2(d, d))
		var pr := _pad()
		if pr.size.x >= 10.0:
			_skip_rect.position.y = minf(_skip_rect.position.y, pr.position.y - 8.0 * u - d)
		_resign(_skip_n, [_skip_rect, u])
	_skip_n.visible = on


func _paint_skip(ci: CanvasItem) -> void:
	if _skip_n.sig.is_empty():
		return
	var u: float = _skip_n.sig[1]
	var d := _skip_rect.size.x
	var c := _skip_rect.get_center()
	ci.draw_circle(c + Vector2(0, 2.0 * u), d * 0.5, Color(0, 0, 0, 0.2))
	ci.draw_circle(c, d * 0.5, Color(Toon.SUMI, 0.82))
	ci.draw_arc(c, d * 0.5, 0, TAU, 32, Color(Toon.WASHI, 0.5), maxf(1.0, 1.2 * u), true)
	# deux chevrons vers la droite, puis la barre d'arrêt
	var col := Color(Toon.WASHI, 0.9)
	var wdt := maxf(1.0, 2.0 * u)
	for i in 2:
		var x := c.x - 8.0 * u + 6.5 * u * float(i)
		ci.draw_polyline(PackedVector2Array([Vector2(x, c.y - 5.0 * u), Vector2(x + 4.5 * u, c.y), Vector2(x, c.y + 5.0 * u)]), col, wdt, true)
	ci.draw_line(Vector2(c.x + 7.0 * u, c.y - 5.5 * u), Vector2(c.x + 7.0 * u, c.y + 5.5 * u), col, wdt, true)


## Bandeau du coach (UI v2, planche Coach) : même coup de pinceau sumi 92 % que le bandeau d'événement du HUD,
## centré dans la zone 88–130 u (sous la barre haute ou le makimono du gardien ; plus bas si le HUD annonce
## quelque chose), filet vermillon, sceau vermillon carré à picto (entaille, figure, goutte, double tap,
## vitesse ; « fig:<figure> » : la figure qui se trace), titre Shippori en capitales espacées, une ligne dessous.
## Le trait se peint de gauche à droite (260 ms), le texte suit en fondu ; à peine agrandi en arrêt sur image.
## Calque : redessiné pendant son entrée seulement ; position, échelle et fondu par sa transformation et son modulate.
func _update_banner(u: float) -> void:
	var on := _shown and mark != ""
	var txt := ""
	var icon := ""
	if on:
		var in_pad := _pad().size.x >= 10.0
		txt = String(TEXTS.get(mark, ""))
		if in_pad:
			txt = String(TEXTS_PAD.get(mark, txt))
		icon = String(ICONS.get(mark, ""))
		match mark:
			"figure":
				txt = String(FIG_TEXT.get(_fig, "Dessine la figure"))
				icon = "fig:" + _fig
			"seal":
				var se := _sealed()
				if se != null:
					icon = "fig:" + String(se.seal_fig)
			"figures":
				icon = "fig:zigzag"
				if _fz >= 0.0:
					txt = ""  # planche des six figures (elle porte son propre titre : pas de bandeau)
		on = txt != ""
	if on:
		var a := clampf(_t / 0.3, 0.0, 1.0)
		var ein := UiKit.ease_out(clampf(_t / 0.26, 0.0, 1.0))
		var ta := clampf((_t - 0.08) / 0.2, 0.0, 1.0)
		var h := 60.0 * u
		var top: float = main.hud.top_clear()
		var hb = main.hud.get("_banner_t")
		if hb != null and float(hb) >= 0.0:
			top += 64.0 * u  # le HUD annonce (étape nettoyée, boss…) : le coach se range dessous
		_banner_n.position = Vector2(size.x * 0.5, top + 8.0 * u + h / 2.0)
		_banner_n.scale = Vector2(_big, _big)
		_banner_n.modulate.a = a
		_resign(_banner_n, [txt, String(SUBS.get(mark, "")), u, ein, ta])
		# sceau carré vermillon, posé comme un tampon juste après le trait (il tombe de 1,6 fois sa taille)
		var sk := clampf((_t - 0.1) / 0.22, 0.0, 1.0)
		if sk > 0.0:
			var z := lerpf(1.6, 1.0, UiKit.ease_out(sk))
			_seal_n.position = Vector2(-324.0 * u / 2.0 + 38.0 * u, 0.0)
			_seal_n.scale = Vector2(z, z)
			_seal_n.modulate.a = sk
			_resign(_seal_n, [icon, u, _seal_step(icon)])
		_seal_n.visible = sk > 0.0
	_banner_n.visible = on


func _paint_banner(ci: CanvasItem) -> void:
	var s: Array = _banner_n.sig
	if s.is_empty():
		return
	var t := UiKit.plain(String(s[0])).to_upper()
	var st := UiKit.plain(String(s[1]))
	var u: float = s[2]
	var ein: float = s[3]
	var ta: float = s[4]
	var bw := 324.0 * u
	var h := 60.0 * u
	var x0 := -bw / 2.0
	var reach := 0.15 + 0.85 * ein
	# le coup de pinceau, tronqué à droite tant qu'il se peint, puis le filet vermillon
	_pts.resize(_shape.size())
	for i in _shape.size():
		var p := _shape[i]
		_pts[i] = Vector2(x0 + minf(p.x, reach) * bw, -h / 2.0 + p.y * h)
	ci.draw_colored_polygon(_pts, UIColors.SUMI_HUD_BG)
	_pts.resize(_line.size())
	for i in _line.size():
		var p := _line[i]
		_pts[i] = Vector2(x0 + minf(p.x, reach) * bw, -h / 2.0 + p.y * h)
	ci.draw_polyline(_pts, Color(Toon.VERMILION, 0.95), 2.5 * u, true)
	# titre et ligne, rétrécis s'ils débordent
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
		ci.draw_string(_title, Vector2(tx + (1.0 - ein) * 10.0 * u, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIColors.WASHI, ta))
	else:
		ci.draw_string(_title, Vector2(tx + (1.0 - ein) * 10.0 * u, -3.0 * u), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIColors.WASHI, ta))
		ci.draw_string(UiKit.UI_FONT, Vector2(tx, 14.0 * u), st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(UIColors.WASHI, 0.85 * ta))


## Pas de l'animation du picto du sceau (figure qui se trace : le calque ne se redessine qu'à chaque point gagné).
func _seal_step(icon: String) -> int:
	if not icon.begins_with("fig:"):
		return 0
	var np := UiKit.gesture_points(icon.substr(4)).size()
	var k := clampf(fmod(_t, 2.2) / 1.6, 0.0, 1.0)
	return int(k * float(np - 1))


## Calque du sceau : carré vermillon et son picto à leur taille finale (19 u de demi-côté, picto 22 u) ; la chute
## du tampon passe par l'échelle du calque (avant : picto rastérisé à chaque taille de la chute, à l'apparition).
func _paint_seal(ci: CanvasItem) -> void:
	var s: Array = _seal_n.sig
	if s.is_empty():
		return
	var icon := String(s[0])
	var u: float = s[1]
	var half := 19.0 * u
	ci.draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, 1.0), int(5 * u), Color(UIColors.WASHI, 0.85), maxi(1, int(1.5 * u))), Rect2(-Vector2(half, half), Vector2(half, half) * 2.0))
	_seal_icon(ci, icon, Vector2.ZERO, 22.0 * u, 1.0, int(s[2]))


## Picto du sceau du bandeau, en washi : picto v2 (ui_icons.gd), glyph UiKit (« water » : la goutte), ou la
## figure « fig:<kind> » qui se trace en boucle (trait washi, point en tête ; n : point atteint).
func _seal_icon(ci: CanvasItem, icon: String, c: Vector2, sz: float, a: float, n: int) -> void:
	if icon.begins_with("fig:"):
		var kind := icon.substr(4)
		var pts := UiKit.gesture_points(kind)
		var box := Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
		_pts.resize(pts.size())
		for i in pts.size():
			_pts[i] = box.position + pts[i] * box.size
		ci.draw_polyline(_pts, Color(Toon.WASHI, 0.3 * a), maxf(1.5, sz * 0.08), true)
		if n >= 1:
			ci.draw_polyline(_pts.slice(0, n + 1), Color(Toon.WASHI, a), maxf(1.8, sz * 0.1), true)
		ci.draw_circle(_pts[n], sz * 0.11, Color(Toon.WASHI, a))
		return
	if icon == "" or UiKit.draw_icon(ci, icon, c, sz, a, Toon.WASHI):
		return
	UiKit.glyph(ci, icon, c, sz * 0.42, Toon.WASHI, Toon.VERMILION, a)


## Préchauffage (main._warmup) : pictos des sceaux rastérisés à leur taille, glyphes des titres et des lignes en
## cache, pour que la première bulle ne les fabrique pas en pleine animation.
func warm() -> void:
	var u := get_viewport_rect().size.x / 400.0
	if u <= 0.0:
		return
	for k in ICONS.values():
		UiKit.icon(String(k), 22.0 * u, {"*": UIColors.hex(Toon.WASHI)})  # (même texture que draw_icon : cache svg_tex)
	var sp := maxi(1, int(3.0 * u))
	_title.spacing_glyph = sp
	for k in TEXTS.keys():
		_title.get_string_size(UiKit.plain(String(TEXTS[k])).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u))
	for k in FIG_TEXT.keys():
		_title.get_string_size(UiKit.plain(String(FIG_TEXT[k])).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u))
	for k in SUBS.keys():
		UiKit.UI_FONT.get_string_size(UiKit.plain(String(SUBS[k])), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u))


## Main fantôme (planche Coach) : halo washi doux (deux disques, sans flou), index tendu vers `p` (le bout du
## doigt), poing et pouce ; contour sumi, chair washi. press : 1 posée, 0 relevée (le halo s'ouvre un peu).
## slot : 0 le geste fantôme, 1 l'invite à toucher. Calques dessinés une fois (à l'origine, pleine opacité) :
## ici on les place, on règle leur fondu et l'ouverture du halo.
func _finger(p: Vector2, u: float, a: float, press := 1.0, slot := 0) -> void:
	if a <= 0.01:
		return
	_fa[slot] = a
	var f: _Part = _fing[slot]
	f.position = p
	f.modulate.a = a
	var halo: Node2D = f.get_child(0)
	halo.scale = Vector2.ONE * ((20.0 + 4.0 * (1.0 - press)) / 20.0)


## Fin du dessin : les mains qui n'ont pas servi à cette image se cachent (visibilité changée seulement si besoin).
func _place_fingers() -> void:
	for i in _fing.size():
		var want: bool = float(_fa[i]) > 0.01
		if _fing[i].visible != want:
			_fing[i].visible = want


func _paint_halo(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2.ZERO, 20.0 * _fing_u, Color(Toon.WASHI, 0.22))


func _paint_finger(ci: CanvasItem) -> void:
	var u := _fing_u
	var p := Vector2.ZERO
	ci.draw_circle(p, 12.0 * u, Color(Toon.WASHI, 0.45))
	var ink := Color(Toon.SUMI, 0.9)
	var skin := Color(Toon.WASHI, 1.0)
	var q := p + Vector2(-4.0, 4.0) * u  # la main vient du bas gauche, comme sur la planche
	# ombre portée légère
	ci.draw_circle(q + Vector2(10.0, 30.0) * u, 11.0 * u, Color(0, 0, 0, 0.15))
	# index (du bout vers la première phalange), puis le poing et le pouce ; contours d'abord, chair ensuite
	var knuckle := q + Vector2(3.0, 18.0) * u
	ci.draw_line(q, knuckle, ink, 10.0 * u, true)
	ci.draw_circle(q + Vector2(9.0, 27.0) * u, 11.5 * u, ink)
	ci.draw_circle(q + Vector2(12.0, 19.0) * u, 5.5 * u, ink)
	ci.draw_circle(q + Vector2(17.0, 23.0) * u, 5.5 * u, ink)
	ci.draw_circle(q + Vector2(-2.0, 26.0) * u, 6.0 * u, ink)
	ci.draw_line(q, knuckle, skin, 7.0 * u, true)
	ci.draw_circle(q + Vector2(9.0, 27.0) * u, 9.5 * u, skin)
	ci.draw_circle(q + Vector2(12.0, 19.0) * u, 3.8 * u, skin)
	ci.draw_circle(q + Vector2(17.0, 23.0) * u, 3.8 * u, skin)
	ci.draw_circle(q + Vector2(-2.0, 26.0) * u, 4.3 * u, skin)
	# pli des doigts repliés
	ci.draw_line(q + Vector2(10.0, 21.0) * u, q + Vector2(14.0, 25.0) * u, Color(Toon.SUMI, 0.35), 1.2 * u, true)


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
