extends Control
## Tutoriel : 7 étapes guidées (se déplacer, trancher, enchaîner, puis les quatre formes).
## Une carte en haut explique l'étape et rejoue le geste à faire avec un doigt animé.
## main appelle begin(), on_dash_end(...) et is_over_ui() ; le tutoriel émet finished.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")

signal finished

const STEPS := [
	{"title": "Se déplacer", "hint": "Pose le doigt, glisse jusqu'au cercle doré, lâche.", "gesture": "line", "goal": "ring"},
	{"title": "Trancher", "hint": "Trace un trait qui traverse le squelette.", "gesture": "line", "goal": "kill1"},
	{"title": "Enchaîner", "hint": "Deux squelettes d'un seul trait : dégâts ×1,5.", "gesture": "diag", "goal": "kill2"},
	{"title": "Boucle", "hint": "Fais une petite boucle dans ton trait : le héros tourne en toupie.", "gesture": "loop", "goal": "loop"},
	{"title": "Zigzag", "hint": "Trace un zigzag : ruée éclair et foudre en chaîne.", "gesture": "zigzag", "goal": "zigzag"},
	{"title": "Trait droit", "hint": "Un long trait bien droit : l'iaï tranche toute la ligne.", "gesture": "straight", "goal": "straight"},
	{"title": "Ensō", "hint": "Un grand cercle presque fermé : le héros bondit et frappe le sol.", "gesture": "enso", "goal": "enso"},
]

var main: Node
var step := -1
var _t := 0.0
var _done_t := -1.0  # pause entre deux étapes réussies
var _ring: Node3D
var _skip: Control
var _quit: Control
var _ui := FontVariation.new()
var _last_ms := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ui.base_font = UI_FONT
	_ui.spacing_glyph = 2
	_skip = InkButton.new()
	_skip.text = "PASSER"
	_skip.style = "ghost"
	_skip.font = _ui
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
	return Rect2(_skip.position, _skip.size).grow(6).has_point(p) or Rect2(_quit.position, _quit.size).grow(6).has_point(p) \
		or _card_rect().has_point(p)


## Fin d'une ruée : l'étape est-elle réussie ?
func on_dash_end(pos: Vector3, kills: int, shape: String) -> void:
	if step < 0 or step >= STEPS.size() or _done_t >= 0.0:
		return
	var goal := String(STEPS[step].goal)
	var ok := false
	match goal:
		"ring":
			ok = _ring != null and Vector2(pos.x - _ring.position.x, pos.z - _ring.position.z).length() < 1.4
		"kill1":
			ok = kills >= 1
		"kill2":
			ok = kills >= 2
		_:
			ok = shape == goal
	if ok:
		_done_t = 0.0
		main.hud.banner("BIEN !", "", Toon.GOLD, 0.9)
		main.sfx.play("shot", 1.4)
	elif goal == "kill2" and kills == 1:
		_respawn_dummies()


func _next() -> void:
	_done_t = -1.0
	_clear_world()
	step += 1
	_t = 0.0
	if step >= STEPS.size():
		_finish()
		return
	var goal := String(STEPS[step].goal)
	var hp: Vector3 = main.hero.position
	match goal:
		"ring":
			_ring = Node3D.new()
			main.add_child(_ring)
			_ring.position = Vector3(hp.x, 0, hp.z - 6.0)
			Toon.disc(_ring, 1.15, Color(Toon.SUMI, 0.8), 0.03)
			Toon.disc(_ring, 1.0, Color(Toon.GOLD, 0.95), 0.035)
			Toon.disc(_ring, 0.7, Color(Toon.WASHI, 0.9), 0.04)
			Toon.disc(_ring, 0.35, Color(Toon.VERMILION, 0.95), 0.045)
		"kill1", "kill2":
			_respawn_dummies()
		_:
			# quelques mannequins pour essayer la forme sur quelque chose
			main.spawn_dummy(Vector3(-2.0, 0, -2.0))
			main.spawn_dummy(Vector3(2.0, 0, -4.0))


func _respawn_dummies() -> void:
	_clear_dummies()
	var goal := String(STEPS[step].goal)
	if goal == "kill1":
		main.spawn_dummy(Vector3(0, 0, -2.5))
	else:
		main.spawn_dummy(Vector3(-1.6, 0, -0.5))
		main.spawn_dummy(Vector3(1.6, 0, -4.5))


func _clear_dummies() -> void:
	for e in main.enemies:
		if is_instance_valid(e) and e.dummy:
			e.queue_free()


func _clear_world() -> void:
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	_clear_dummies()


func _finish() -> void:
	_clear_world()
	visible = false
	step = -1
	finished.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var now := Time.get_ticks_msec()
	var real := 0.0 if _last_ms == 0 else minf((now - _last_ms) / 1000.0, 0.1)
	_last_ms = now
	_t += real
	if _done_t >= 0.0:
		_done_t += real
		if _done_t > 0.9:
			_next()
	# mannequins de l'étape « trancher » : on en remet s'ils ont tous disparu
	if step >= 0 and step < STEPS.size() and _done_t < 0.0:
		var goal := String(STEPS[step].goal)
		if goal in ["kill1", "kill2"]:
			var alive := 0
			for e in main.enemies:
				if is_instance_valid(e) and e.dummy and not e.dead:
					alive += 1
			if alive == 0:
				_respawn_dummies()
	var u := size.x / 400.0
	var card := _card_rect()
	_skip.size = Vector2(96, 36) * u
	_skip.position = Vector2(card.end.x - 96 * u, card.end.y + 10 * u)
	_skip.font_size = int(13 * u)
	_quit.size = Vector2(36, 36) * u
	_quit.position = Vector2(card.position.x, card.end.y + 10 * u)
	queue_redraw()


func _card_rect() -> Rect2:
	var u := size.x / 400.0
	return Rect2(Vector2(size.x * 0.05, 92 * u), Vector2(size.x * 0.9, 118 * u))


func _draw() -> void:
	if step < 0 or step >= STEPS.size() or size.x < 10.0:
		return
	var u := size.x / 400.0
	var s: Dictionary = STEPS[step]
	var card := _card_rect()
	var a := clampf(_t / 0.3, 0.0, 1.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Color("#F4EDDC"), 0.96 * a)
	sb.set_corner_radius_all(int(14 * u))
	sb.shadow_color = Color(0, 0, 0, 0.3 * a)
	sb.shadow_size = int(12 * u)
	draw_style_box(sb, card)
	# démonstration du geste à droite
	var demo := Rect2(Vector2(card.end.x - 104 * u, card.position.y + 10 * u), Vector2(94, 98) * u)
	var db := StyleBoxFlat.new()
	db.bg_color = Color(Toon.SUMI, 0.9 * a)
	db.set_corner_radius_all(int(10 * u))
	draw_style_box(db, demo)
	_draw_gesture(String(s.gesture), demo.grow(-12 * u), u, a)
	# texte
	var tx := card.position.x + 16 * u
	draw_string(_ui, Vector2(tx, card.position.y + 24 * u), "ÉTAPE %d / %d" % [step + 1, STEPS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Color(Toon.VERMILION, a))
	draw_string(TITLE_FONT, Vector2(tx, card.position.y + 50 * u), String(s.title), HORIZONTAL_ALIGNMENT_LEFT, -1, int(21 * u), Color(Toon.SUMI, a))
	draw_multiline_string(UI_FONT, Vector2(tx, card.position.y + 72 * u), String(s.hint), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 140 * u, int(12 * u), 3, Color(Toon.SUMI, 0.75 * a))
	# progression
	for i in STEPS.size():
		var c := Vector2(tx + i * 12 * u + 3 * u, card.end.y - 10 * u)
		draw_circle(c, 3 * u, Color(Toon.SUMI, (1.0 if i <= step else 0.2) * a))


## Le geste se dessine en boucle, un doigt (point vermillon) en tête.
func _draw_gesture(kind: String, box: Rect2, u: float, a: float) -> void:
	var pts := _gesture_points(kind)
	var k := fmod(_t, 2.2) / 1.6
	var n := int(clampf(k, 0.0, 1.0) * (pts.size() - 1))
	var mapped := PackedVector2Array()
	for i in pts.size():
		mapped.append(box.position + pts[i] * box.size)
	# cibles (cercle doré, squelettes)
	if kind == "line":
		draw_arc(mapped[mapped.size() - 1], 7 * u, 0, TAU, 16, Color(Toon.GOLD, a), 2 * u)
	if kind == "diag":
		draw_circle(box.position + Vector2(0.35, 0.62) * box.size, 4 * u, Color(Toon.WASHI, 0.7 * a))
		draw_circle(box.position + Vector2(0.65, 0.32) * box.size, 4 * u, Color(Toon.WASHI, 0.7 * a))
	draw_circle(mapped[0], 4 * u, Color(Toon.VERMILION, a))  # le héros
	if n >= 1:
		draw_polyline(mapped.slice(0, n + 1), Color(Toon.WASHI, a), 3 * u, true)
		var tip: Vector2 = mapped[n]
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
		_:
			for i in 41:
				var ang := PI / 2.0 + TAU * 0.92 * i / 40.0
				p.append(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * 0.4)
	return p
