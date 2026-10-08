extends Control
## Coach : le tutoriel se fait en jouant. Petites bulles d'encre posées sur le jeu, près du héros,
## au moment où chaque geste sert : tracer, trancher, esquiver, l'encre, une figure, l'ultime, la course.
## Chaque bulle ne vient qu'une fois (meta.coach_seen) et part dès que le geste est fait (ou au bout
## de quelques secondes). Seule la première attend le joueur (temps ralenti, pas figé).
## main appelle on_launch, on_event, on_pick, slows, is_over_ui et skip ; le coach lit l'état de main.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const PowerData = preload("res://scripts/power_data.gd")

const TEXTS := {
	"stroke": "Trace un trait : le rōnin le suit",
	"cut": "Traverse-le pour trancher",
	"dodge": "Glisse vite ou touche pour esquiver",
	"ink": "L'encre se recharge quand tu ne traces pas",
	"ult": "Double tap : ultime",
	"run": "Maintiens pour courir",
}
const FIG_TEXT := {
	"loop": "Dessine une boucle : la toupie",
	"zigzag": "Trace un zigzag : l'éclair",
	"straight": "Un long trait droit : l'iaï",
	"return": "Un aller-retour : la garde",
	"enso": "Un grand cercle : l'ensō",
	"hook": "Un trait en crochet : l'estoc",
}
# durée de vie (s réelles) ; 0 : jusqu'au geste
const LIFE := {"stroke": 0.0, "cut": 7.0, "dodge": 5.0, "ink": 6.0, "figure": 10.0, "ult": 8.0, "run": 7.0}
const ORDER := ["stroke", "dodge", "cut", "ult", "figure", "ink", "run"]
const GAP := 0.8  # silence entre deux bulles
const SLOW := 0.3  # temps ralenti tant que le premier trait n'est pas tracé

var main: Node
var mark := ""  # bulle affichée ("" : aucune)
var _t := 0.0  # temps réel depuis son apparition
var _gap := 0.0
var _fig := ""  # figure du rouleau pris, à montrer
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


func seen(id: String) -> bool:
	return main.meta.coach_seen.has(id)


## Premier trait attendu : main ralentit le temps.
func slows() -> bool:
	return mark == "stroke" and active()


## Nouvelle partie, retour à l'accueil : rien d'affiché.
func clear() -> void:
	mark = ""
	_fig = ""
	_t = 0.0
	_gap = 0.0


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
	if mark == "stroke" or (mark == "figure" and shape == _fig):
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
	_gap = GAP
	main.sfx.play("shot", 1.6, -10.0)


func _show(id: String) -> void:
	mark = id
	_t = 0.0


## Le geste de cette bulle sert-il maintenant ?
func _wanted(id: String) -> bool:
	match id:
		"stroke":
			return not bool(main.hero.dashing)
		"cut":
			return _first_enemy() != null
		"dodge":
			for e in main.enemies:
				if is_instance_valid(e) and not e.dead and not e.dummy and str(e.get("_state")) == "windup":
					return true
			return false
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
		# une attaque annoncée passe avant le reste (sauf le tout premier trait)
		if mark != "dodge" and mark != "stroke" and not seen("dodge") and _wanted("dodge"):
			_show("dodge")
		elif mark == "ink" and _t > 1.5 and float(main.elan) >= float(main.elan_max()) * 0.9:
			_finish()  # l'encre est revenue : compris
		else:
			var life := float(LIFE.get(mark, 6.0))
			if life > 0.0 and _t > life:
				_finish()
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
	if _skip_shown():
		_draw_skip(u, insets)
	if mark == "":
		return
	var a := clampf(_t / 0.3, 0.0, 1.0)
	var hero: Node3D = main.hero
	var hp := hero.position
	var head := _screen(hp + Vector3(0, 2.3, 0))
	var feet := _screen(hp)
	var txt := String(TEXTS.get(mark, ""))
	match mark:
		"stroke":
			_ghost_path(hp, u, a)
			_bubble(txt, head, u, a, false)
		"cut":
			var e := _first_enemy()
			if e != null:
				var ep := _screen(e.position)
				_ghost_line(feet, ep, u, a)
				_bubble(txt, _screen(e.position + Vector3(0, 2.2, 0)), u, a, false)
			else:
				_bubble(txt, head, u, a, false)
		"dodge":
			_ghost_flick(feet, u, a)
			_bubble(txt, head, u, a, false)
		"ink":
			# la jauge d'encre du HUD : bord droit, de 0,3 à 0,6 de la hauteur
			var gx := size.x - 16.0 * u - 12.0 * u
			var gr := Rect2(Vector2(gx - 3.0 * u, size.y * 0.3 - 3.0 * u), Vector2(22.0 * u, size.y * 0.3 + 6.0 * u))
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			_sb.bg_color = Color(0, 0, 0, 0)
			_sb.set_corner_radius_all(int(14.0 * u))
			_sb.border_color = Color(Toon.GOLD, (0.5 + 0.5 * pulse) * a)
			_sb.set_border_width_all(int(maxf(2.0, 3.0 * u)))
			_sb.shadow_size = 0
			draw_style_box(_sb, gr.grow((4.0 + 3.0 * pulse) * u))
			_bubble(txt, Vector2(gr.position.x - 10.0 * u, gr.get_center().y), u, a, true)
		"figure":
			var ft := String(FIG_TEXT.get(_fig, "Dessine la figure"))
			var r := _bubble(ft, head, u, a, false, 64.0 * u)
			var demo := Rect2(Vector2(r.end.x - 60.0 * u, r.position.y + 4.0 * u), Vector2(56, r.size.y / u - 8.0) * u)
			_draw_figure(_fig, demo, u, a)
		"ult":
			_ghost_double_tap(feet, u, a)
			_bubble(txt, head, u, a, false)
		"run":
			_ghost_hold(feet, hp, u, a)
			_bubble(txt, head, u, a, false)


## Petit « PASSER » dans le coin bas gauche.
func _draw_skip(u: float, insets: Vector2) -> void:
	_skip_rect = Rect2(Vector2(14.0 * u, size.y - insets.y - 44.0 * u), Vector2(76.0 * u, 28.0 * u))
	UiKit.box(_sb, Color(Toon.ui_paper, 0.8), int(14.0 * u), Color(Toon.ui_ink, 0.35), int(maxf(1.0, 1.2 * u)))
	draw_style_box(_sb, _skip_rect)
	var fs := int(11.0 * u)
	UiKit.text(self, _ui, "PASSER", Vector2(_skip_rect.get_center().x, _skip_rect.get_center().y + fs * 0.36), fs, Color(Toon.ui_ink, 0.8))


## Bulle d'encre (papier, liseré d'encre, queue vers `anchor`). side : à gauche de l'ancre (sinon au-dessus).
## extra : place réservée à droite du texte (démonstration de la figure). Renvoie le cadre de la bulle.
func _bubble(txt: String, anchor: Vector2, u: float, a: float, side: bool, extra := 0.0) -> Rect2:
	var t := UiKit.plain(txt)
	var fs := int(14.0 * u)
	var maxw := size.x * 0.84 - extra - 28.0 * u
	var tw := _ui.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > maxw and tw > 1.0:
		fs = maxi(8, int(float(fs) * maxw / tw))
		tw = _ui.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := 40.0 * u if extra <= 0.0 else 64.0 * u
	var w := tw + 28.0 * u + extra
	var anc := anchor
	if anc.x < -9000.0:
		anc = Vector2(size.x * 0.5, size.y * 0.4)
	var top_min := 70.0 * u
	var pos := Vector2.ZERO
	var tail := PackedVector2Array()
	if side:
		if side and w > anc.x - 12.0 * u:
			fs = maxi(8, int(float(fs) * (anc.x - 40.0 * u) / maxf(w, 1.0)))
			tw = _ui.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			w = tw + 28.0 * u
		pos = Vector2(anc.x - 12.0 * u - w, anc.y - h * 0.5)
		pos.x = maxf(pos.x, 8.0 * u)
		tail = PackedVector2Array([Vector2(pos.x + w - 2.0 * u, anc.y - 7.0 * u), anc, Vector2(pos.x + w - 2.0 * u, anc.y + 7.0 * u)])
	else:
		pos = Vector2(anc.x - w * 0.5, anc.y - h - 14.0 * u)
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
	draw_string(_ui, Vector2(r.position.x + 18.0 * u, r.position.y + h * 0.5 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.ui_ink, a))
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


## La figure se trace en boucle dans un petit cadre d'encre.
func _draw_figure(kind: String, box: Rect2, u: float, a: float) -> void:
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.9 * a), int(8.0 * u)), box)
	var inner := box.grow(-8.0 * u)
	var pts := _gesture_points(kind)
	var k := clampf(fmod(_t, 2.2) / 1.6, 0.0, 1.0)
	var n := int(k * float(pts.size() - 1))
	var mapped := PackedVector2Array()
	for p in pts:
		mapped.append(inner.position + p * inner.size)
	draw_polyline(mapped, Color(Toon.WASHI, 0.2 * a), 2.0 * u, true)
	if n >= 1:
		draw_polyline(mapped.slice(0, n + 1), Color(Toon.WASHI, a), 2.5 * u, true)
	draw_circle(mapped[n], 4.0 * u, Color(Toon.VERMILION, 0.9 * a))


## Gestes des figures, en coordonnées 0..1 (de bas en haut).
func _gesture_points(kind: String) -> PackedVector2Array:
	var p := PackedVector2Array()
	match kind:
		"loop":
			for i in 41:
				var t := float(i) / 40.0
				var base := Vector2(0.5, 0.92 - 0.82 * t)
				var lp := clampf((t - 0.3) / 0.4, 0.0, 1.0)
				if lp > 0.0 and lp < 1.0:
					base += Vector2(sin(lp * TAU) * 0.22, (1.0 - cos(lp * TAU)) * 0.12)
				p.append(base)
		"zigzag":
			var zz := [Vector2(0.5, 0.92), Vector2(0.2, 0.7), Vector2(0.8, 0.5), Vector2(0.2, 0.3), Vector2(0.75, 0.1)]
			for i in range(zz.size() - 1):
				var za: Vector2 = zz[i]
				var zb: Vector2 = zz[i + 1]
				for j in 6:
					p.append(za.lerp(zb, j / 6.0))
			p.append(zz[zz.size() - 1])
		"straight":
			for i in 13:
				p.append(Vector2(0.5, 0.95 - 0.9 * i / 12.0))
		"return":
			for i in 13:
				p.append(Vector2(0.44, 0.9 - 0.75 * i / 12.0))
			for i in range(1, 13):
				p.append(Vector2(0.54, 0.15 + 0.73 * i / 12.0))
		"hook":
			for i in 13:
				p.append(Vector2(0.35 + 0.15 * i / 12.0, 0.9 - 0.75 * i / 12.0))
			for i in range(1, 9):
				p.append(Vector2(0.5 + 0.3 * i / 8.0, 0.15 + 0.4 * i / 8.0))
		_:
			for i in 41:
				var ang := PI / 2.0 + TAU * 0.92 * i / 40.0
				p.append(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * 0.4)
	return p
