extends Control
## Tutoriel : 10 étapes guidées (trancher, enchaîner, esquiver, zone rouge, puis les six formes).
## Une carte en haut explique l'étape et rejoue le geste à faire avec un doigt animé.
## main appelle begin(), on_dash_end(...), on_dodge() et is_over_ui() ; le tutoriel émet finished.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

signal finished

const STEPS := [
	{"title": "Trancher", "hint": "Glisse le doigt sur l'écran : ton trait part du héros. Traverse le squelette.", "gesture": "line", "goal": "kill1"},
	{"title": "Enchaîner", "hint": "Deux squelettes d'un seul trait : dégâts ×1,5.", "gesture": "diag", "goal": "kill2"},
	{"title": "Esquive", "hint": "Un simple tap sur l'écran : le héros bondit loin du danger. Pendant un bond, rien ne te touche.", "gesture": "flick", "goal": "dodge"},
	{"title": "Zone rouge", "hint": "Le rouge annonce un coup. Sors du cercle avant qu'il soit plein : un bond ou un trait.", "gesture": "zone", "goal": "zone"},
	{"title": "Trait droit", "hint": "Un long trait bien droit : l'iaï tranche toute la ligne.", "gesture": "straight", "goal": "straight"},
	{"title": "Kaeshi", "hint": "Aller-retour : file tout droit, puis reviens sur ton trait jusqu'au départ. Garde et renvoi des tirs.", "gesture": "return", "goal": "return"},
	{"title": "Kagi", "hint": "Un trait, puis repars en biais vers l'arrière, comme un crochet : estoc dans le dos.", "gesture": "hook", "goal": "hook"},
	{"title": "Boucle", "hint": "Fais une petite boucle dans ton trait : le héros tourne en toupie.", "gesture": "loop", "goal": "loop"},
	{"title": "Zigzag", "hint": "Trace un zigzag : ruée éclair et foudre en chaîne.", "gesture": "zigzag", "goal": "zigzag"},
	{"title": "Ensō", "hint": "Un grand cercle presque fermé : le héros bondit et frappe le sol.", "gesture": "enso", "goal": "enso"},
]
const SHAPE_FR := {"loop": "une boucle", "zigzag": "un zigzag", "return": "un aller-retour", "straight": "un trait droit", "enso": "un ensō", "hook": "un crochet"}
const SKIP_FAILS := 3      # échecs avant de proposer « passer l'étape »
const SKIP_TIME := 25.0    # ou secondes passées sur l'étape
const ZONE_R := 1.6        # rayon de la zone rouge (le bond fait 2,4 m)
const ZONE_TIME := 2.4     # durée de l'annonce
const ZONE_WAIT := 1.2     # pause avant chaque annonce

var main: Node
var step := -1
var _t := 0.0
var _done_t := -1.0  # pause entre deux étapes réussies
var _fails := 0
var _dodged := false  # la ruée en cours est un bond d'esquive (signalé par main)
var _zone: Node3D
var _zone_fill: Node3D
var _zone_c := Vector3.ZERO
var _zone_t := 0.0
var _zone_wait := 0.0
var _skip: Control
var _quit: Control
var _ui := FontVariation.new()
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 2
	_skip = InkButton.new()
	_skip.text = "PASSER L'ÉTAPE"
	_skip.style = "ghost"
	_skip.font = _ui
	_skip.visible = false
	add_child(_skip)
	_skip.pressed.connect(_next)
	_quit = InkButton.new()
	_quit.style = "round"
	_quit.icon = "home"
	add_child(_quit)
	_quit.pressed.connect(_finish)


func begin() -> void:
	visible = true
	step = -1
	_next()


func is_over_ui(p: Vector2) -> bool:
	if not visible:
		return false
	if _skip.visible and Rect2(_skip.position, _skip.size).grow(6).has_point(p):
		return true
	return Rect2(_quit.position, _quit.size).grow(6).has_point(p) or _card_rect().has_point(p)


func _goal() -> String:
	if step < 0 or step >= STEPS.size():
		return ""
	return String(STEPS[step].goal)


## Bond d'esquive (petit coup de doigt) : main l'appelle au lancement du bond.
func on_dodge() -> void:
	if not visible or _done_t >= 0.0 or _goal() == "":
		return
	_dodged = true
	if _goal() == "dodge":
		_success()


## Fin d'une ruée : l'étape est-elle réussie ?
func on_dash_end(_pos: Vector3, kills: int, shape: String) -> void:
	var goal := _goal()
	var was_dodge := _dodged
	_dodged = false
	if goal == "" or _done_t >= 0.0 or goal == "zone":
		return
	# un bond n'est pas un essai de forme
	if was_dodge and goal != "dodge":
		return
	var ok := false
	var miss := ""
	match goal:
		"kill1":
			ok = kills >= 1
			miss = "TRAVERSE LE SQUELETTE"
		"kill2":
			ok = kills >= 2
			miss = "LES DEUX D'UN SEUL TRAIT"
		"dodge":
			ok = was_dodge
			miss = "PLUS COURT : UN PETIT COUP SEC"
		_:
			ok = shape == goal
			if shape == "":
				miss = "PAS RECONNU · REGARDE LE GESTE"
			else:
				miss = "ÇA, C'EST %s · RÉESSAIE" % String(SHAPE_FR.get(shape, shape)).to_upper()
	if ok:
		_success()
		return
	_fails += 1
	main.hud.toast(miss)
	if goal == "kill2" and kills == 1:
		_respawn_dummies()


func _success() -> void:
	_done_t = 0.0
	main.hud.banner("BIEN !", "", Toon.GOLD, 0.9)
	main.sfx.play("shot", 1.4)
	var hp: Vector3 = main.hero.position
	main.vfx.ring(Vector3(hp.x, 0.05, hp.z), Toon.GOLD, 2.0)


func _next() -> void:
	_done_t = -1.0
	_clear_world()
	step += 1
	_t = 0.0
	_fails = 0
	_dodged = false
	if step >= STEPS.size():
		_finish()
		return
	match _goal():
		"kill1", "kill2":
			_respawn_dummies()
		"dodge":
			pass
		"zone":
			_zone_wait = ZONE_WAIT
		_:
			# quelques mannequins pour essayer la forme sur quelque chose
			main.spawn_dummy(Vector3(-2.0, 0, 1.5))
			main.spawn_dummy(Vector3(2.0, 0, 0.0))


func _respawn_dummies() -> void:
	_clear_dummies()
	if _goal() == "kill1":
		main.spawn_dummy(Vector3(0, 0, 2.0))
	else:
		main.spawn_dummy(Vector3(-1.4, 0, 3.0))
		main.spawn_dummy(Vector3(1.4, 0, 0.0))


func _clear_dummies() -> void:
	for e in main.enemies:
		if is_instance_valid(e) and e.dummy:
			e.queue_free()


func _clear_zone() -> void:
	if _zone and is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_zone_fill = null


func _clear_world() -> void:
	_clear_zone()
	_clear_dummies()


func _finish() -> void:
	_clear_world()
	visible = false
	step = -1
	finished.emit()


## Zone rouge scriptée : annoncée sous le héros, elle tombe au bout de ZONE_TIME.
func _update_zone(dt: float) -> void:
	if _zone == null:
		_zone_wait -= dt
		if _zone_wait <= 0.0:
			var hp: Vector3 = main.hero.position
			_zone_c = Vector3(hp.x, 0, hp.z)
			_zone = Node3D.new()
			main.add_child(_zone)
			_zone.position = _zone_c
			_zone_fill = main.vfx.tele_disc(_zone, ZONE_R)
			_zone_t = ZONE_TIME
		return
	_zone_t -= dt
	main.vfx.tele_update(_zone_fill, clampf(1.0 - _zone_t / ZONE_TIME, 0.01, 1.0), _zone_t)
	if _zone_t > 0.0:
		return
	# impact : en ruée (ou hors du cercle), le héros n'est pas touché
	var hp2: Vector3 = main.hero.position
	var safe: bool = bool(main.hero.dashing) or Vector2(hp2.x - _zone_c.x, hp2.z - _zone_c.z).length() > ZONE_R
	_clear_zone()
	main.vfx.ring(Vector3(_zone_c.x, 0.05, _zone_c.z), Toon.VERMILION, ZONE_R)
	main.sfx.play("strike", 0.9, -2.0)
	main.shake = maxf(float(main.shake), 0.3)
	if safe:
		_success()
	else:
		_fails += 1
		main.hud.banner("RATÉ", "RÉESSAIE", Toon.VERMILION, 0.9)
		_zone_wait = ZONE_WAIT


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	if _done_t >= 0.0:
		_done_t += real
		if _done_t > 0.9:
			_next()
	var goal := _goal()
	if goal != "" and _done_t < 0.0:
		# mannequins de l'étape « trancher » : on en remet s'ils ont tous disparu
		if goal in ["kill1", "kill2"]:
			var alive := 0
			for e in main.enemies:
				if is_instance_valid(e) and e.dummy and not e.dead:
					alive += 1
			if alive == 0:
				_respawn_dummies()
		elif goal == "zone" and String(main.state) == "tuto":
			_update_zone(real)
	var u := size.x / 400.0
	var card := _card_rect()
	# « passer l'étape » seulement si on bloque (échecs répétés ou trop long)
	_skip.visible = goal != "" and (_fails >= SKIP_FAILS or _t >= SKIP_TIME)
	_skip.size = Vector2(132, 36) * u
	_skip.position = Vector2(card.end.x - 132 * u, card.end.y + 10 * u)
	_skip.font_size = int(13 * u)
	_quit.size = Vector2(36, 36) * u
	_quit.position = Vector2(card.position.x, card.end.y + 10 * u)
	queue_redraw()


func _card_rect() -> Rect2:
	var u := size.x / 400.0
	return Rect2(Vector2(size.x * 0.05, 64 * u), Vector2(size.x * 0.9, 104 * u))


func _draw() -> void:
	if step < 0 or step >= STEPS.size() or size.x < 10.0:
		return
	var u := size.x / 400.0
	var s: Dictionary = STEPS[step]
	var card := _card_rect()
	var a := clampf(_t / 0.3, 0.0, 1.0)
	UiKit.box(_sb, Color(Toon.PAPER, 0.96 * a), int(14 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.3 * a)
	_sb.shadow_size = int(12 * u)
	draw_style_box(_sb, card)
	# démonstration du geste à droite
	var demo := Rect2(Vector2(card.end.x - 92 * u, card.position.y + 8 * u), Vector2(84, 88) * u)
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.9 * a), int(10 * u)), demo)
	_draw_gesture(String(s.gesture), demo.grow(-12 * u), u, a)
	# texte
	var tx := card.position.x + 16 * u
	draw_string(_ui, Vector2(tx, card.position.y + 24 * u), UiKit.plain("ÉTAPE %d / %d" % [step + 1, STEPS.size()]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Color(Toon.VERMILION, a))
	draw_string(UiKit.TITLE_FONT, Vector2(tx, card.position.y + 46 * u), UiKit.plain(String(s.title)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * u), Color(Toon.SUMI, a))
	draw_multiline_string(UiKit.UI_FONT, Vector2(tx, card.position.y + 64 * u), UiKit.plain(String(s.hint)), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 124 * u, int(11 * u), 3, Color(Toon.SUMI, 0.75 * a))
	# progression
	for i in STEPS.size():
		var c := Vector2(tx + i * 12 * u + 3 * u, card.end.y - 10 * u)
		draw_circle(c, 3 * u, Color(Toon.SUMI, (1.0 if i <= step else 0.2) * a))


## Le geste se dessine en boucle, un doigt (point vermillon) en tête.
func _draw_gesture(kind: String, box: Rect2, u: float, a: float) -> void:
	if kind == "flick" or kind == "zone":
		_draw_flick(kind == "zone", box, u, a)
		return
	var pts := _gesture_points(kind)
	var k := fmod(_t, 2.2) / 1.6
	var n := int(clampf(k, 0.0, 1.0) * (pts.size() - 1))
	var mapped := PackedVector2Array()
	for i in pts.size():
		mapped.append(box.position + pts[i] * box.size)
	# cibles (squelettes)
	if kind == "line":
		draw_circle(box.position + Vector2(0.5, 0.45) * box.size, 4 * u, Color(Toon.WASHI, 0.7 * a))
	if kind == "diag":
		draw_circle(box.position + Vector2(0.35, 0.62) * box.size, 4 * u, Color(Toon.WASHI, 0.7 * a))
		draw_circle(box.position + Vector2(0.65, 0.32) * box.size, 4 * u, Color(Toon.WASHI, 0.7 * a))
	draw_circle(mapped[0], 4 * u, Color(Toon.VERMILION, a))  # le héros
	if n >= 1:
		draw_polyline(mapped.slice(0, n + 1), Color(Toon.WASHI, a), 3 * u, true)
		var tip: Vector2 = mapped[n]
		draw_circle(tip, 6 * u, Color(Toon.VERMILION, 0.9 * a))
		draw_arc(tip, 9 * u, 0, TAU, 16, Color(Toon.WASHI, 0.6 * a), 1.5 * u)


## Bond d'esquive : un coup de doigt très court, puis le héros saute plus loin.
## Avec zone : le cercle rouge se remplit sous le héros, qui en sort avant l'impact.
func _draw_flick(zone: bool, box: Rect2, u: float, a: float) -> void:
	var t := fmod(_t, 2.4)
	var h0 := box.position + Vector2(0.38, 0.62) * box.size
	var h1 := box.position + Vector2(0.85, 0.3) * box.size
	var dir := (h1 - h0).normalized()
	if zone and t < 1.9:
		var zr := 0.32 * box.size.x
		if t < 1.6:
			var zk := clampf(t / 1.6, 0.0, 1.0)
			draw_circle(h0, zr, Color(Toon.VERMILION, 0.2 * a))
			draw_circle(h0, zr * zk, Color(Toon.VERMILION, 0.55 * a))
			draw_arc(h0, zr, 0, TAU, 32, Color(Toon.VERMILION, a), 1.5 * u)
		else:
			draw_circle(h0, zr, Color(Toon.WASHI, 0.8 * a))  # l'impact
	var ft := 0.9 if zone else 0.5  # instant du coup de doigt
	var p := clampf((t - ft) / 0.12, 0.0, 1.0)
	var j := clampf((t - ft - 0.08) / 0.22, 0.0, 1.0)
	var hp := h0.lerp(h1, j * (2.0 - j))
	if j > 0.0:
		draw_line(h0, hp, Color(Toon.WASHI, 0.5 * a), 2 * u, true)
	draw_circle(hp, 4 * u, Color(Toon.VERMILION, a))  # le héros
	# le doigt : à peine un trait, très vite
	if t < ft + 0.35:
		var tip := h0 + dir * (0.16 * box.size.x * p)
		if p > 0.0:
			draw_line(h0, tip, Color(Toon.WASHI, a), 3 * u, true)
		draw_circle(tip, 6 * u, Color(Toon.VERMILION, 0.9 * a))
		draw_arc(tip, 9 * u, 0, TAU, 16, Color(Toon.WASHI, 0.6 * a), 1.5 * u)


func _gesture_points(kind: String) -> PackedVector2Array:
	var p := PackedVector2Array()
	match kind:
		"line":
			for i in 13:
				p.append(Vector2(0.5, 0.9 - 0.7 * i / 12.0))
		"diag":
			for i in 13:
				p.append(Vector2(0.2 + 0.6 * i / 12.0, 0.85 - 0.7 * i / 12.0))
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
			# aller tout droit, petit demi-tour, retour collé à l'aller
			for i in 13:
				p.append(Vector2(0.44, 0.9 - 0.75 * i / 12.0))
			for i in range(1, 13):
				p.append(Vector2(0.54, 0.15 + 0.73 * i / 12.0))
		"hook":
			# montée, puis crochet en biais vers l'arrière (~130°)
			for i in 13:
				p.append(Vector2(0.35 + 0.15 * i / 12.0, 0.9 - 0.75 * i / 12.0))
			for i in range(1, 9):
				p.append(Vector2(0.5 + 0.3 * i / 8.0, 0.15 + 0.4 * i / 8.0))
		_:
			for i in 41:
				var ang := PI / 2.0 + TAU * 0.92 * i / 40.0
				p.append(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * 0.4)
	return p
