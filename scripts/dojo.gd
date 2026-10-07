extends Control
## Dojo : entraînement libre aux figures et aux acrobaties, ouvert depuis l'accueil.
## Encre infinie, héros intouchable, techniques des figures prêtées, quatre mannequins qui reviennent.
## Chaque trait a son verdict : la figure reconnue (sceau du HUD), sinon ce qui a manqué (StrokeShapes.near_miss).
## Le carnet (repliable) compte figures, esquives, zones et ultimes, et coche quelques défis.
## Mannequin offensif : l'un d'eux annonce régulièrement une zone rouge sous le héros, pour s'exercer au bond.
## Le tutoriel (tutorial.gd) le possède et lui transmet on_dash_end, on_dodge, on_ultimate et is_over_ui.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const StrokeShapes = preload("res://scripts/stroke_shapes.gd")

signal closed

const SLOTS := [Vector3(-2.2, 0, 1.6), Vector3(2.2, 0, 1.6), Vector3(-1.6, 0, -1.8), Vector3(1.8, 0, -1.4)]
const RESPAWN := 1.2        # secondes avant qu'un mannequin abattu revienne
const ZONE_R := 1.6         # rayon de la zone rouge (le bond fait 2,4 m)
const ZONE_TIME := 2.0      # durée de l'annonce
const ZONE_EVERY := 3.5     # pause entre deux annonces
const ULT_PER_STROKE := 0.34  # la jauge d'ultime se remplit vite au dojo
const ULT_REGEN := 0.08     # ... et toute seule (par seconde)
const FIG_MIN_LEN := 2.0    # main : pas de figure sous 2 m de trait
const VERDICT_LEN := 2.2
const HEAD_H := 54.0        # en-tête de la carte (× u)
const BOOK_H := 232.0       # carnet déplié (× u)
const FIG_FR := {"straight": "Trait droit", "return": "Kaeshi", "zigzag": "Zigzag", "loop": "Boucle", "enso": "Ensō", "hook": "Kagi"}
const CHALLENGES := [
	{"id": "loop_zz", "text": "Boucle puis zigzag d'affilée"},
	{"id": "enso3", "text": "3 ensō de suite"},
	{"id": "multi3", "text": "Toucher 3 mannequins d'un trait"},
	{"id": "zone", "text": "Esquiver une zone rouge"},
	{"id": "ult", "text": "Lancer l'ultime"},
	{"id": "all6", "text": "Les six figures"},
]

var main: Node
var active := false
var open := false        # carnet déplié
var offensive := false   # mannequin offensif
var counts := {}         # figure -> nombre réussi
var dodges := 0
var zones_ok := 0
var ults := 0
var done := {}           # défi -> true
var last_verdict := ""   # dernier verdict affiché (lu par le robot testeur)
var _last_shape := ""    # figure du trait précédent ("" : aucune)
var _enso_run := 0
var _dodged := false
var _pts := PackedVector3Array()  # points du dernier trait lancé (relevés sur main.dash_stroke)
var _slot_e: Array = []
var _slot_t: Array = []
var _zone: Node3D
var _zone_fill: Node3D
var _zone_c := Vector3.ZERO
var _zone_t := 0.0
var _zone_wait := 0.0
var _verdict := ""
var _verdict_sub := ""
var _verdict_shape := ""
var _verdict_miss := false
var _verdict_t := -1.0
var _open_k := 0.0
var _t := 0.0
var _home: Control
var _book: Control
var _off: Control
var _ui := FontVariation.new()
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 2
	_home = InkButton.new()
	_home.style = "round"
	_home.icon = "home"
	add_child(_home)
	_home.pressed.connect(stop)
	_book = _button("CARNET")
	_book.pressed.connect(_toggle_book)
	_off = _button("OFFENSIF")
	_off.pressed.connect(_toggle_offensive)


func _button(label: String) -> Control:
	var b := InkButton.new()
	b.text = label
	b.style = "ghost"
	b.font = _ui
	add_child(b)
	return b


func begin() -> void:
	active = true
	visible = true
	open = false
	offensive = false
	counts = {}
	dodges = 0
	zones_ok = 0
	ults = 0
	done = {}
	last_verdict = ""
	_last_shape = ""
	_enso_run = 0
	_dodged = false
	_pts = PackedVector3Array()
	_slot_e = []
	_slot_t = []
	for i in SLOTS.size():
		_slot_e.append(null)
		_slot_t.append(0.0)
	_clear_zone()
	_zone_wait = ZONE_EVERY
	_verdict_t = -1.0
	_open_k = 0.0
	_t = 0.0
	_book.text = "CARNET"
	_off.style = "ghost"
	# toutes les techniques des figures sont prêtées
	if main.powers != null:
		main.powers.demo = true
	main.ult = 0.0


## Fin du dojo (bouton maison) ; `notify` faux : arrêt silencieux (reprise du robot testeur).
func stop(notify := true) -> void:
	if not active:
		return
	active = false
	visible = false
	_clear_zone()
	for e in main.enemies:
		if is_instance_valid(e) and e.dummy:
			e.queue_free()
	if main.powers != null:
		main.powers.demo = false
	if notify:
		closed.emit()


func is_over_ui(p: Vector2) -> bool:
	if not active or not visible:
		return false
	var u := size.x / 400.0
	return _card_rect().grow(6 * u).has_point(p)


func total_figures() -> int:
	var n := 0
	for k in counts.keys():
		n += int(counts[k])
	return n


func _toggle_book() -> void:
	open = not open
	_book.text = "FERMER" if open else "CARNET"
	main.sfx.play("whoosh", 1.3, -10.0)


func _toggle_offensive() -> void:
	offensive = not offensive
	_off.style = "primary" if offensive else "ghost"
	_zone_wait = 1.0
	if not offensive:
		_clear_zone()


# ------------------------------------------------------------------ événements transmis par main (via le tutoriel)

## Bond d'esquive : la ruée qui suit n'est pas un essai de figure.
func on_dodge() -> void:
	if not active:
		return
	_dodged = true


## Ultime lancé (double tap).
func on_ultimate() -> void:
	if not active:
		return
	ults += 1
	_complete("ult")


## Fin d'une ruée : compte, défis, et verdict sur la figure.
func on_dash_end(_pos: Vector3, kills: int, shape: String) -> void:
	if not active:
		return
	if _dodged:
		_dodged = false
		dodges += 1
		return
	main.ult = minf(1.0, float(main.ult) + ULT_PER_STROKE)
	if _touched(kills) >= 3:
		_complete("multi3")
	if shape != "":
		counts[shape] = int(counts.get(shape, 0)) + 1
		if _last_shape == "loop" and shape == "zigzag":
			_complete("loop_zz")
		_enso_run = _enso_run + 1 if shape == "enso" else 0
		if _enso_run >= 3:
			_complete("enso3")
		var all := true
		for f in UiKit.FIGURES:
			if int(counts.get(String(f), 0)) <= 0:
				all = false
		if all:
			_complete("all6")
		# le sceau du HUD (hud.shape_pop) annonce déjà la figure ; carnet ouvert, il est caché : on la redit
		_show_verdict(String(FIG_FR.get(shape, shape)), "×%d" % int(counts[shape]), shape, false)
	else:
		_enso_run = 0
		_explain()
	_last_shape = shape


## Mannequins touchés par la dernière ruée (marqués du trait en cours), au moins ceux abattus.
func _touched(kills: int) -> int:
	var sid := int(main.stroke_id)
	var n := 0
	for e in main.enemies:
		if is_instance_valid(e) and e.dummy and int(e.last_stroke) == sid:
			n += 1
	return maxi(n, kills)


## Trait non reconnu : la figure la plus proche et ce qui lui a manqué.
func _explain() -> void:
	if _pts.size() < 2 or StrokeShapes.length(_pts) < FIG_MIN_LEN:
		_show_verdict("Trait trop court", "une figure demande un long trait", "", true)
		return
	var m: Dictionary = StrokeShapes.near_miss(_pts)
	var txt: String = StrokeShapes.describe(m)
	if txt == "":
		# reconnu ici mais pas par main (trait enchaîné, coupé par le bord…)
		_show_verdict("Pas de figure", "trace-la d'un seul geste", "", true)
		return
	var parts := txt.split(" : ", true, 1)
	var sub := ""
	if parts.size() > 1:
		sub = parts[1]
	_show_verdict(parts[0], sub, String(m.get("shape", "")), true)


func _show_verdict(big: String, sub: String, shape: String, miss: bool) -> void:
	_verdict = UiKit.plain(big.to_upper())
	_verdict_sub = UiKit.plain(sub.to_upper())
	_verdict_shape = shape
	_verdict_miss = miss
	_verdict_t = 0.0
	last_verdict = _verdict if _verdict_sub == "" else _verdict + " · " + _verdict_sub


func _complete(id: String) -> void:
	if done.has(id):
		return
	done[id] = true
	var txt := ""
	for c in CHALLENGES:
		if String(c["id"]) == id:
			txt = String(c["text"])
	main.hud.banner("BIEN !", "DÉFI · " + txt.to_upper(), Toon.GOLD, 1.4)
	main.sfx.play("levelup", 1.2, -4.0)


# ------------------------------------------------------------------ monde : mannequins, zone rouge

func _update_dummies(dt: float) -> void:
	for i in SLOTS.size():
		var e = _slot_e[i]
		if is_instance_valid(e) and not e.dead:
			continue
		_slot_e[i] = null
		_slot_t[i] = float(_slot_t[i]) - dt
		if float(_slot_t[i]) > 0.0:
			continue
		main.spawn_dummy(SLOTS[i])
		if not main.enemies.is_empty():
			_slot_e[i] = main.enemies[main.enemies.size() - 1]
		_slot_t[i] = RESPAWN


func _clear_zone() -> void:
	if _zone and is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_zone_fill = null


## Mannequin offensif : une annonce sous le héros, lancée par le mannequin le plus proche.
func _update_zone(dt: float) -> void:
	if _zone == null:
		_zone_wait -= dt
		if _zone_wait > 0.0:
			return
		var hp: Vector3 = main.hero.position
		var src = null
		var best := INF
		for e in _slot_e:
			if is_instance_valid(e) and not e.dead:
				var d: float = hp.distance_to(e.position)
				if d < best:
					best = d
					src = e
		if src == null:
			_zone_wait = 0.5
			return
		var sp: Vector3 = src.position
		main.vfx.ring(Vector3(sp.x, 0.05, sp.z), Toon.VERMILION, 0.9)
		main.sfx.play("whoosh", 0.7, -6.0)
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
	# impact : en ruée (ou hors du cercle), c'est esquivé ; sinon rien de grave, le héros est intouchable
	var hp2: Vector3 = main.hero.position
	var safe: bool = bool(main.hero.dashing) or Vector2(hp2.x - _zone_c.x, hp2.z - _zone_c.z).length() > ZONE_R
	_clear_zone()
	main.vfx.ring(Vector3(_zone_c.x, 0.05, _zone_c.z), Toon.VERMILION, ZONE_R)
	main.sfx.play("strike", 0.9, -2.0)
	main.shake = maxf(float(main.shake), 0.3)
	_zone_wait = ZONE_EVERY
	if safe:
		zones_ok += 1
		if done.has("zone"):
			main.hud.banner("BIEN !", "ESQUIVÉ", Toon.GOLD, 0.8)
		_complete("zone")
	else:
		main.hud.banner("RATÉ", "SORS DU CERCLE : UN BOND OU UN TRAIT", Toon.VERMILION, 0.9)


# ------------------------------------------------------------------ boucle et dessin

func _process(_delta: float) -> void:
	if not active or not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	if _verdict_t >= 0.0:
		_verdict_t += real
		if _verdict_t > VERDICT_LEN:
			_verdict_t = -1.0
	_open_k = move_toward(_open_k, 1.0 if open else 0.0, real * 6.0)
	if String(main.state) == "tuto":
		# points du trait en cours de ruée (pour expliquer un trait non reconnu)
		var ds = main.dash_stroke
		if is_instance_valid(ds):
			_pts = ds.points
		_update_dummies(real)
		main.ult = minf(1.0, float(main.ult) + ULT_REGEN * real)
		if offensive:
			_update_zone(real)
	var u := size.x / 400.0
	var card := _card_rect()
	_home.size = Vector2(36, 36) * u
	_home.position = card.position + Vector2(9, 9) * u
	_book.size = Vector2(76, 30) * u
	_book.position = Vector2(card.end.x - 85 * u, card.position.y + 12 * u)
	_book.font_size = int(11 * u)
	_off.size = Vector2(92, 30) * u
	_off.position = Vector2(_book.position.x - 98 * u, card.position.y + 12 * u)
	_off.font_size = int(11 * u)
	queue_redraw()


func _card_rect() -> Rect2:
	var u := size.x / 400.0
	var h := HEAD_H + BOOK_H * UiKit.ease_out(_open_k)
	return Rect2(Vector2(size.x * 0.05, 64 * u), Vector2(size.x * 0.9, h * u))


func _draw() -> void:
	if not active or size.x < 10.0:
		return
	var u := size.x / 400.0
	var card := _card_rect()
	var a := clampf(_t / 0.3, 0.0, 1.0)
	UiKit.box(_sb, Color(Toon.PAPER, 0.96 * a), int(14 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.3 * a)
	_sb.shadow_size = int(12 * u)
	draw_style_box(_sb, card)
	# en-tête : titre et défis relevés
	var tx := card.position.x + 54 * u
	draw_string(UiKit.TITLE_FONT, Vector2(tx, card.position.y + 27 * u), "Dojo", HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * u), Color(Toon.SUMI, a))
	var dl := "DÉFIS %d / %d" % [done.size(), CHALLENGES.size()]
	draw_string(_ui, Vector2(tx, card.position.y + 43 * u), dl, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.5 * u), Color(Toon.VERMILION, a))
	var ka := a * clampf((_open_k - 0.6) / 0.4, 0.0, 1.0)
	if ka > 0.0:
		_draw_book(card, u, ka)
	_draw_verdict(card, u)


## Carnet : les six figures et leurs compteurs, esquives, zones, ultimes, puis les défis cochés.
func _draw_book(card: Rect2, u: float, a: float) -> void:
	var x0 := card.position.x + 16 * u
	var x1 := card.end.x - 16 * u
	var y0 := card.position.y + HEAD_H * u
	draw_line(Vector2(x0, y0), Vector2(x1, y0), Color(Toon.SUMI, 0.15 * a), 1.5 * u)
	_section("FIGURES", x0, x1, y0 + 17 * u, u, a)
	var step := (x1 - x0) / float(UiKit.FIGURES.size())
	for i in UiKit.FIGURES.size():
		var sh := String(UiKit.FIGURES[i])
		var n := int(counts.get(sh, 0))
		var c := Vector2(x0 + step * (i + 0.5), y0 + 44 * u)
		var fa: float = a * (1.0 if n > 0 else 0.3)
		UiKit.figure(self, sh, c, 14 * u, fa)
		UiKit.text(self, UiKit.TITLE_FONT, "×%d" % n, Vector2(c.x, y0 + 76 * u), int(12 * u), Color(Toon.SUMI, fa))
	var cols := [["ESQUIVES", dodges], ["ZONES", zones_ok], ["ULTIMES", ults]]
	var cw := (x1 - x0) / float(cols.size())
	for i in cols.size():
		var col: Array = cols[i]
		var cx := x0 + cw * (i + 0.5)
		UiKit.text(self, _ui, "%s  %d" % [String(col[0]), int(col[1])], Vector2(cx, y0 + 100 * u), int(10 * u), Color(Toon.SUMI, 0.8 * a))
		if i > 0:
			draw_line(Vector2(x0 + cw * i, y0 + 89 * u), Vector2(x0 + cw * i, y0 + 103 * u), Color(Toon.SUMI, 0.12 * a), 1.5 * u)
	_section("DÉFIS", x0, x1, y0 + 124 * u, u, a)
	for i in CHALLENGES.size():
		var ch: Dictionary = CHALLENGES[i]
		var ok := done.has(String(ch["id"]))
		var y := y0 + 144 * u + i * 16.5 * u
		var bc := Vector2(x0 + 6 * u, y - 4 * u)
		if ok:
			draw_circle(bc, 6.5 * u, Color(Toon.VERMILION, a))
			UiKit.glyph(self, "check", bc, 4.2 * u, Toon.WASHI, UiKit.NONE, a)
		else:
			draw_arc(bc, 6 * u, 0, TAU, 20, Color(Toon.SUMI, 0.35 * a), 1.5 * u, true)
		draw_string(UiKit.UI_FONT, Vector2(x0 + 19 * u, y), UiKit.plain(String(ch["text"])), HORIZONTAL_ALIGNMENT_LEFT, -1, int(10.5 * u), Color(Toon.SUMI, (0.45 if ok else 0.85) * a))


## Titre de section : petit mot puis filet jusqu'au bord.
func _section(label: String, x0: float, x1: float, y: float, u: float, a: float) -> void:
	var fs := int(9 * u)
	draw_string(_ui, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.SUMI, 0.55 * a))
	var tw := _ui.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_line(Vector2(x0 + tw + 6 * u, y - fs * 0.35), Vector2(x1, y - fs * 0.35), Color(Toon.SUMI, 0.15 * a), 1.5 * u)


## Verdict du dernier trait : figure ratée (la plus proche, pâlie, et ce qui manque),
## ou figure réussie quand le carnet ouvert cache le sceau du HUD.
func _draw_verdict(card: Rect2, u: float) -> void:
	if _verdict_t < 0.0 or _verdict == "":
		return
	if not _verdict_miss and _open_k < 0.5:
		return
	var a := clampf(minf(_verdict_t / 0.15, (VERDICT_LEN - _verdict_t) / 0.4), 0.0, 1.0)
	var bfs := int(15 * u)
	var sfs := int(10 * u)
	var bw := UiKit.TITLE_FONT.get_string_size(_verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
	var sw := 0.0
	if _verdict_sub != "":
		sw = UiKit.UI_FONT.get_string_size(_verdict_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
	var lead: float = 40.0 * u if _verdict_shape != "" else 0.0
	var w := minf(maxf(bw, sw) + 32 * u + lead, size.x - 24 * u)
	var h: float = (50.0 if _verdict_sub != "" else 36.0) * u
	# sous le sceau du HUD (carnet fermé), sinon sous la carte
	var top := maxf(card.end.y + 24 * u, 208 * u) - 6 * u * (1.0 - a)
	var r := Rect2(Vector2((size.x - w) / 2.0, top), Vector2(w, h))
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.8 * a), int(14 * u)), r)
	if _verdict_shape != "":
		UiKit.figure(self, _verdict_shape, Vector2(r.position.x + 16 * u + 13 * u, r.get_center().y), 13 * u, a * (0.5 if _verdict_miss else 1.0))
	var tx := r.position.x + 16 * u + lead
	var bc: Color = Color(Toon.WASHI, a) if _verdict_miss else Color(Toon.GOLD, a)
	if _verdict_sub != "":
		draw_string(UiKit.TITLE_FONT, Vector2(tx, r.position.y + 22 * u), _verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, bc)
		draw_string(UiKit.UI_FONT, Vector2(tx, r.position.y + 39 * u), _verdict_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(Toon.VERMILION.lightened(0.35), a) if _verdict_miss else Color(Toon.WASHI, 0.8 * a))
	else:
		draw_string(UiKit.TITLE_FONT, Vector2(tx, r.position.y + 24 * u), _verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, bc)
