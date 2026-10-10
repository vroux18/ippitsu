extends Control
## Dojo : entraînement libre aux figures et aux acrobaties, ouvert depuis l'accueil.
## Encre infinie, héros intouchable, techniques des figures prêtées, quatre mannequins qui reviennent.
## En-tête compact en haut (sous l'encoche) : maison, titre, défis relevés, OFFENSIF et CARNET,
## puis le défi en cours ou la figure ciblée. Le HUD de partie est réduit (hud.dojo : encre et ultime).
## Chaque trait a son verdict, dans une pastille sous l'en-tête : la figure reconnue et sa technique,
## sinon ce qui a manqué (StrokeShapes.near_miss / describe).
## Le carnet (page déroulante, planche Carnet v2) : les six figures en tuiles (geste animé, nom, picto de la
## technique, compte), sans texte d'explication ; toucher une figure en fait la cible de l'entraînement, et
## son geste fantôme se trace en grand sous l'en-tête. Il compte aussi esquives, zones, ultimes et défis.
## Mode offensif : trois mannequins (au plus) poursuivent le héros et frappent avec leurs annonces, comme en
## combat (le héros reste intouchable, ils reviennent quand on les abat) ; l'un d'eux annonce aussi
## régulièrement une zone rouge sous le héros, pour s'exercer au bond.
## Le tutoriel (tutorial.gd) le possède et lui transmet on_dash_end, on_dodge, on_ultimate et is_over_ui.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
const InkStroke = preload("res://scripts/ink_stroke.gd")

signal closed

const SLOTS := [Vector3(-2.2, 0, 1.6), Vector3(2.2, 0, 1.6), Vector3(-1.6, 0, -1.8), Vector3(1.8, 0, -1.4)]
const RESPAWN := 1.2        # secondes avant qu'un mannequin abattu revienne
const OFF_MAX := 3          # mode offensif : mannequins qui attaquent en même temps (les premiers emplacements)
const ZONE_R := 1.6         # rayon de la zone rouge (le bond fait 2,4 m)
const ZONE_TIME := 2.0      # durée de l'annonce
const ZONE_EVERY := 3.5     # pause entre deux annonces
const ULT_PER_STROKE := 0.34  # la jauge d'ultime se remplit vite au dojo
const ULT_REGEN := 0.08     # ... et toute seule (par seconde)
const FIG_MIN_LEN := 2.0    # main : pas de figure sous 2 m de trait
const VERDICT_LEN := 2.0
const HEAD_H := 50.0        # rangée du titre et des boutons (× u)
const TASK_H := 26.0        # rangée du défi en cours, ou de la figure ciblée (× u)
const PAGE_HEAD := 50.0     # titre fixe du carnet, au-dessus de la partie qui défile (× u)
# technique que débloque le rouleau de chaque figure (power_data : fig_loop, fig_zigzag…)
const TECH := {"loop": "TOUPIE", "zigzag": "ÉCLAIR", "straight": "IAÏ", "return": "GARDE", "enso": "ONDE DE CHOC", "hook": "ESTOC"}
# picto de la technique de chaque figure (SVG techniques/*) ; le geste animé de la tuile montre comment la tracer
const TECH_ICON := {"loop": "techniques/toupie", "zigzag": "techniques/eclair", "straight": "techniques/iai",
	"return": "techniques/garde", "enso": "techniques/onde_de_choc", "hook": "techniques/estoc"}
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
var target := ""         # figure ciblée depuis le carnet ("" : aucune)
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
var _ghost_t := -1.0     # geste fantôme de la cible (s depuis le choix ; < 0 : aucun)
var _open_k := 0.0
var _t := 0.0
var _home: Control
var _book: Control
var _off: Control
var _task: Control       # rangée du défi en cours : ouvre le carnet, ou retire la cible
var _page: Control       # page du carnet (découpée à son cadre, elle défile)
var _scroll := 0.0
var _vel := 0.0          # élan du défilement (px/s)
var _content_h := 0.0
var _drag_on := false
var _drag_moved := false
var _drag_from := 0.0
var _drag_s0 := 0.0
var _drag_ms := 0
var _row_hits: Array = []  # [cadre dans le contenu, figure] (relevés au dessin de la page)
var _close_rect := Rect2()
var _ui := FontVariation.new()
var _tfont := FontVariation.new()  # DOJO : Shippori espacée (titre d'écran)
var _sb := StyleBoxFlat.new()
var _psb := StyleBoxFlat.new()  # celle de la page


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 2
	_tfont.base_font = UiKit.TITLE_FONT
	_tfont.spacing_glyph = UiKit.TITLE_SPACING
	# la page d'abord : les boutons de l'en-tête passent par-dessus
	_page = Control.new()
	_page.clip_contents = true
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.visible = false
	add_child(_page)
	_page.draw.connect(_draw_page)
	_page.gui_input.connect(_on_page_input)
	_task = InkButton.new()
	_task.style = "area"
	add_child(_task)
	_task.pressed.connect(_on_task)
	_home = InkButton.new()
	_home.style = "round"
	_home.icon = "home"
	add_child(_home)
	_home.pressed.connect(stop)
	_book = _button("CARNET", "brush")
	_book.pressed.connect(_toggle_book)
	_off = _button("OFFENSIF", "bestiary")
	_off.pressed.connect(_toggle_offensive)


## Étiquette papier (UI v2, bouton secondaire) à puce picto.
func _button(label: String, icon: String) -> Control:
	var b := InkButton.new()
	b.text = label
	b.style = "label"
	b.icon = icon
	b.font = _ui
	add_child(b)
	return b


func begin() -> void:
	active = true
	visible = true
	open = false
	offensive = false
	target = ""
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
	_scroll = 0.0
	_vel = 0.0
	_drag_on = false
	_page.visible = false
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
	open = false
	_open_k = 0.0
	_page.visible = false
	_clear_zone()
	for e in main.enemies:
		if is_instance_valid(e) and e.dummy:
			e.queue_free()
	if main.powers != null:
		main.powers.demo = false
	if notify:
		closed.emit()


## Carnet ouvert : tout l'écran lui appartient (aucun trait) ; sinon, seulement l'en-tête.
func is_over_ui(p: Vector2) -> bool:
	if not active or not visible:
		return false
	if open:
		return true  # (en se refermant, la page laisse déjà passer les traits)
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
	_vel = 0.0
	_drag_on = false
	main.sfx.play("whoosh", 1.3, -10.0)


func _toggle_offensive() -> void:
	offensive = not offensive
	_off.accent = offensive  # étiquette armée (vermillon, coche) tant que les mannequins attaquent
	_zone_wait = 1.0
	if not offensive:
		_clear_zone()
	# offensif : les premiers mannequins se mettent en garde et attaquent, le dernier se retire ;
	# sinon les attaquants s'effacent (annonces comprises) et des cibles immobiles reviennent vite
	for i in _slot_e.size():
		var e = _slot_e[i]
		if not is_instance_valid(e) or e.dead:
			continue
		if offensive and i < OFF_MAX:
			e.spar = true
		else:
			e.queue_free()
			_slot_e[i] = null
			_slot_t[i] = 0.3


## Rangée du défi : carnet ouvert, elle le referme ; une cible posée, elle la retire ; sinon elle ouvre le carnet.
func _on_task() -> void:
	if open:
		_toggle_book()
	elif target != "":
		target = ""
		main.sfx.play("whoosh", 1.1, -12.0)
	else:
		_toggle_book()


## Figure touchée dans le carnet : elle devient la cible (la retouchée la retire), le carnet se referme.
func _set_target(kind: String) -> void:
	target = "" if target == kind else kind
	if open:
		_toggle_book()
	if target != "":
		_show_verdict(String(UiKit.FIG_WORD.get(kind, kind)), "", kind, false)
		_ghost_t = 0.0  # le geste fantôme se trace en grand sous l'en-tête


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
		# verdict sous l'en-tête (les sceaux du HUD sont masqués au dojo) : figure, technique, compte ou cible
		var word := String(UiKit.FIG_WORD.get(shape, shape))
		var sub := "×%d" % int(counts[shape])
		var wrong := false
		if target != "" and shape != target:
			sub = "×%d  ·  %s ?" % [int(counts[shape]), String(UiKit.FIG_WORD.get(target, target))]
			wrong = true
		_show_verdict(word, sub, shape, wrong)
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
		_show_verdict("Trait trop court", "", "", true)
		return
	var m: Dictionary = StrokeShapes.near_miss(_pts)
	var txt: String = StrokeShapes.describe(m)
	if txt == "":
		# reconnu ici mais pas par main (trait enchaîné, coupé par le bord…)
		_show_verdict("Pas de figure", "", "", true)
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


## Premier défi pas encore relevé ({} : tous relevés).
func _next_challenge() -> Dictionary:
	for c in CHALLENGES:
		var ch: Dictionary = c
		if not done.has(String(ch["id"])):
			return ch
	return {}


# ------------------------------------------------------------------ monde : mannequins, zone rouge

func _update_dummies(dt: float) -> void:
	var n: int = OFF_MAX if offensive else SLOTS.size()
	for i in n:
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
			var ne = _slot_e[i]
			if offensive and is_instance_valid(ne):
				ne.spar = true  # mode offensif : il revient à la charge
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
	main.shake = maxf(float(main.shake), 0.31)
	_zone_wait = ZONE_EVERY
	if safe:
		zones_ok += 1
		if done.has("zone"):
			main.hud.banner("ESQUIVÉ", "", Toon.GOLD, 0.8)
		_complete("zone")
	else:
		main.hud.banner("RATÉ", "", Toon.VERMILION, 0.9)


# ------------------------------------------------------------------ boucle et mise en page

func _process(_delta: float) -> void:
	if _ghost_t >= 0.0:
		_ghost_t += UiKit.real_delta()
		if _ghost_t > 5.0 or target == "":
			_ghost_t = -1.0
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
		# intouchable même quand une garde (figure retour) remplace la sienne : les coups ne blessent pas
		var hero = main.hero
		if is_instance_valid(hero) and float(hero.guard_t) < 1000.0:
			hero.guard_t = 99999.0
		# carnet ouvert : la zone rouge attend qu'on ait fini de lire
		if offensive and not open:
			_update_zone(real)
	var u := size.x / 400.0
	var card := _card_rect()
	_home.size = Vector2(36, 36) * u
	_home.position = card.position + Vector2(7, 7) * u
	_book.size = Vector2(92, 32) * u
	_book.position = Vector2(card.end.x - 100 * u, card.position.y + 9 * u)
	_book.font_size = int(9.5 * u)
	_book.font_size = int(10.5 * u)
	_off.size = Vector2(100, 32) * u
	_off.position = Vector2(_book.position.x - 106 * u, card.position.y + 9 * u)
	_off.font_size = int(9.5 * u)
	_off.font_size = int(10.5 * u)
	_task.position = Vector2(card.position.x, card.position.y + HEAD_H * u)
	_task.size = Vector2(card.size.x, TASK_H * u)
	_update_page(real, u)
	queue_redraw()


## En-tête : bandeau de papier pleine largeur sous la marge du haut (encoche), entre les bords de l'écran.
func _card_rect() -> Rect2:
	var u := size.x / 400.0
	var top := 12.0 * u
	if main != null and main.hud != null:
		top = float(main.hud.top_off)
	return Rect2(Vector2(12 * u, top), Vector2(size.x - 24 * u, (HEAD_H + TASK_H) * u))


## Page du carnet : sous l'en-tête jusqu'au bas de l'écran (marge de geste comprise), par-dessus le pad.
func _sheet_rect() -> Rect2:
	var u := size.x / 400.0
	var card := _card_rect()
	var y0 := card.end.y + 8.0 * u
	var bot := size.y - UiKit.safe_insets(size).y - 12.0 * u
	return Rect2(Vector2(card.position.x, y0), Vector2(card.size.x, maxf(bot - y0, 140.0 * u)))


func _max_scroll() -> float:
	var u := size.x / 400.0
	return maxf(_content_h - (_page.size.y - PAGE_HEAD * u), 0.0)


func _update_page(real: float, u: float) -> void:
	_page.visible = _open_k > 0.01
	if not _page.visible:
		_drag_on = false
		return
	var k := UiKit.ease_out(_open_k)
	var r := _sheet_rect()
	_page.position = r.position + Vector2(0, (1.0 - k) * 18.0 * u)
	_page.size = r.size
	_page.modulate = Color(1, 1, 1, k)
	# élan du défilement après un glissé
	if not _drag_on and absf(_vel) > 1.0:
		_scroll += _vel * real
		_vel *= exp(-real * 5.0)
		if _scroll < 0.0 or _scroll > _max_scroll():
			_vel = 0.0
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	_page.queue_redraw()


## Page : glissé vertical pour défiler (avec élan), molette, toucher bref sur une figure (cible) ou sur la croix.
func _on_page_input(event: InputEvent) -> void:
	var u := size.x / 400.0
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_vel = 0.0
				_scroll = clampf(_scroll + (48.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -48.0) * u, 0.0, _max_scroll())
			_page.accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_on = true
				_drag_moved = false
				_drag_from = mb.position.y
				_drag_s0 = _scroll
				_drag_ms = Time.get_ticks_msec()
				_vel = 0.0
			elif _drag_on:
				_drag_on = false
				if not _drag_moved:
					_page_tap(mb.position)
				elif Time.get_ticks_msec() - _drag_ms > 90:
					_vel = 0.0  # doigt arrêté avant d'être levé : pas d'élan
			_page.accept_event()
	elif event is InputEventMouseMotion and _drag_on:
		var mm := event as InputEventMouseMotion
		var dy := mm.position.y - _drag_from
		if absf(dy) > 8.0 * u:
			_drag_moved = true
		if _drag_moved:
			_scroll = clampf(_drag_s0 - dy, 0.0, _max_scroll())
			_vel = lerpf(_vel, -mm.relative.y / maxf(UiKit.real_delta(), 0.008), 0.4)
			_drag_ms = Time.get_ticks_msec()
		_page.accept_event()


func _page_tap(p: Vector2) -> void:
	var u := size.x / 400.0
	if _close_rect.grow(6.0 * u).has_point(p):
		_toggle_book()
		return
	if p.y < PAGE_HEAD * u:
		return
	var cp := Vector2(p.x, p.y - PAGE_HEAD * u + _scroll)
	for h in _row_hits:
		var hr: Rect2 = h[0]
		if hr.has_point(cp):
			_set_target(String(h[1]))
			return


# ------------------------------------------------------------------ dessin : en-tête et verdict

func _draw() -> void:
	if not active or size.x < 10.0:
		return
	var u := size.x / 400.0
	var card := _card_rect()
	var a := clampf(_t / 0.3, 0.0, 1.0)
	# carte de papier aux couleurs du thème, liseré d'encre, ombre portée
	UiKit.box(_sb, Color(Toon.ui_paper, 0.97 * a), int(14 * u), Color(Toon.ui_ink, 0.3 * a), maxi(1, int(1.2 * u)))
	_sb.shadow_color = Color(0, 0, 0, 0.3 * a)
	_sb.shadow_size = int(10 * u)
	_sb.shadow_offset = Vector2(0, 3 * u)
	draw_style_box(_sb, card)
	_sb.shadow_offset = Vector2.ZERO
	# titre (UI v2 : capitales espacées, trait vermillon dessous) et défis relevés (compte et six pastilles)
	var tx := card.position.x + 52 * u
	var ttw := _tfont.get_string_size("DOJO", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u)).x
	draw_string(_tfont, Vector2(tx, card.position.y + 22 * u), "DOJO", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), Color(Toon.ui_ink, a))
	draw_colored_polygon(UiKit.swash_points(Rect2(Vector2(tx + ttw * 0.1, card.position.y + 25.5 * u), Vector2(ttw * 0.8, 4.5 * u)), a, 5.0), Color(Toon.VERMILION, 0.95 * a))
	var dl := "DÉFIS %d / %d" % [done.size(), CHALLENGES.size()]
	var dfs := int(8.5 * u)
	draw_string(_ui, Vector2(tx, card.position.y + 39 * u), dl, HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Color(Toon.VERMILION, a))
	var dw := _ui.get_string_size(dl, HORIZONTAL_ALIGNMENT_LEFT, -1, dfs).x
	var px := minf(tx + dw + 8.0 * u, _off.position.x - 6.0 * 7.0 * u)
	for i in CHALLENGES.size():
		var pc := Vector2(px + 3.0 * u + float(i) * 6.5 * u, card.position.y + 36 * u)
		if done.has(String(CHALLENGES[i]["id"])):
			draw_circle(pc, 2.4 * u, Color(Toon.VERMILION, a))
		else:
			draw_arc(pc, 2.2 * u, 0.0, TAU, 12, Color(Toon.ui_ink, 0.35 * a), maxf(1.0, 1.0 * u), true)
	var hy := card.position.y + HEAD_H * u
	draw_line(Vector2(card.position.x + 12 * u, hy), Vector2(card.end.x - 12 * u, hy), Color(Toon.ui_ink, 0.12 * a), maxf(1.0, 1.2 * u))
	_draw_task(card, u, a)
	if _page.visible:
		# ombre de la page (la page elle-même est découpée à son cadre)
		var pr := Rect2(_page.position, _page.size)
		var k := _page.modulate.a
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.3 * k), int(16 * u)), Rect2(pr.position + Vector2(0, 4 * u), pr.size))
	else:
		_draw_verdict(card, u)
		_draw_ghost(card, u)


## Seconde rangée de l'en-tête : la figure ciblée, ou le prochain défi ; vide quand le carnet est ouvert.
func _draw_task(card: Rect2, u: float, a: float) -> void:
	var cy := card.position.y + (HEAD_H + TASK_H * 0.5) * u
	var fs := int(10.5 * u)
	var lfs := int(8 * u)
	var label := "DÉFI"
	var txt := ""
	var col: Color = Toon.VERMILION
	var seal := ""
	if open:
		return  # carnet ouvert : son titre suffit
	if target != "":
		label = "CIBLE"
		seal = target
		col = InkStroke.FIG_INK.get(target, Toon.GOLD)
		txt = "%s  ×%d" % [String(UiKit.FIG_WORD.get(target, target)), int(counts.get(target, 0))]
	else:
		var ch := _next_challenge()
		if ch.is_empty():
			label = "BRAVO"
			txt = "%d / %d" % [done.size(), CHALLENGES.size()]
		else:
			txt = String(ch["text"])
	txt = UiKit.plain(txt)
	var lw := _ui.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var tw := UiKit.UI_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw := 20.0 * u if seal != "" else 0.0
	var x := card.get_center().x - (lw + 8.0 * u + sw + tw) / 2.0
	var lc: Color = Color(Toon.ui_ink).lerp(col, 0.75)
	draw_string(_ui, Vector2(x, cy + lfs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(lc, a))
	x += lw + 8.0 * u
	if seal != "":
		draw_circle(Vector2(x + 8.0 * u, cy), 9.5 * u, Color(col, a))
		UiKit.figure(self, seal, Vector2(x + 8.0 * u, cy), 8.0 * u, a)
		x += sw
	draw_string(UiKit.UI_FONT, Vector2(x, cy + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.ui_ink, 0.9 * a))
	if target != "" and not open:
		# petite croix au bout de la rangée : la toucher retire la cible
		UiKit.glyph(self, "cross", Vector2(card.end.x - 18.0 * u, cy), 4.5 * u, Color(Toon.ui_ink, 0.5 * a), UiKit.NONE, a)


## Verdict du dernier trait, en pastille sous l'en-tête (entre les jauges des bords) :
## figure réussie (son sceau, sa technique, le compte ou la cible), ou ratée (la plus proche, ce qui manque).
func _draw_verdict(card: Rect2, u: float) -> void:
	if _verdict_t < 0.0 or _verdict == "":
		return
	var a := clampf(minf(_verdict_t / 0.12, (VERDICT_LEN - _verdict_t) / 0.3), 0.0, 1.0)
	var has_sub := _verdict_sub != ""
	var bfs := int(13 * u)
	var sfs := int(9 * u)
	var sr := 11.0 * u
	var max_w := size.x - 104.0 * u  # entre la jauge d'encre et le bord gauche
	var room := max_w - (12.0 * u + 2.0 * sr + 10.0 * u + 14.0 * u)
	while bfs > 9 and UiKit.TITLE_FONT.get_string_size(_verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x > room:
		bfs -= 1
	while sfs > 7 and _ui.get_string_size(_verdict_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x > room:
		sfs -= 1
	var bw := UiKit.TITLE_FONT.get_string_size(_verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
	var sw := _ui.get_string_size(_verdict_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x if has_sub else 0.0
	var w := minf(12.0 * u + 2.0 * sr + 10.0 * u + maxf(bw, sw) + 14.0 * u, max_w)
	var h := (40.0 if has_sub else 30.0) * u
	var y := card.end.y + 8.0 * u - (1.0 - UiKit.ease_out(clampf(_verdict_t / 0.15, 0.0, 1.0))) * 6.0 * u
	var r := Rect2(Vector2((size.x - w) / 2.0, y), Vector2(w, h))
	var acc: Color = Toon.VERMILION
	if not _verdict_miss and _verdict_shape != "":
		acc = InkStroke.FIG_INK.get(_verdict_shape, Toon.GOLD)
	# pastille d'encre comme celles du HUD, cerclée de la couleur de la figure (vermillon : raté)
	draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.25 * a), 999), Rect2(r.position + Vector2(0, 2.5 * u), r.size))
	draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.92 * a), 999, Color(acc, 0.9 * a), maxi(1, int(1.5 * u))), r)
	var sc := Vector2(r.position.x + 12.0 * u + sr, r.get_center().y)
	if _verdict_shape != "":
		draw_circle(sc, sr + 2.0 * u, Color(acc, a))
		UiKit.figure(self, _verdict_shape, sc, sr, a * (0.65 if _verdict_miss else 1.0))
	else:
		draw_circle(sc, sr, Color(Toon.VERMILION, a))
		UiKit.glyph(self, "cross", sc, sr * 0.55, Toon.WASHI, UiKit.NONE, a)
	var tx := sc.x + sr + 10.0 * u
	var cy := r.get_center().y
	var by := cy - 1.0 * u if has_sub else cy + bfs * 0.36
	draw_string(UiKit.TITLE_FONT, Vector2(tx, by), _verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(Toon.WASHI, a))
	if has_sub:
		var scol: Color = Color(acc.lightened(0.35), a) if _verdict_miss else Color(Toon.WASHI, 0.7 * a)
		draw_string(_ui, Vector2(tx, cy + 13.0 * u), _verdict_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, scol)


## Cible choisie dans le carnet : son geste fantôme se trace en grand sous l'en-tête (deux passages), puis s'efface.
func _draw_ghost(card: Rect2, u: float) -> void:
	if _ghost_t < 0.0 or target == "":
		return
	var a := clampf(minf(_ghost_t / 0.2, (4.6 - _ghost_t) / 0.4), 0.0, 1.0)
	if a <= 0.0:
		return
	var s := 120.0 * u
	var box := Rect2(Vector2(size.x / 2.0 - s / 2.0, card.end.y + 48.0 * u), Vector2(s, s))
	var col: Color = InkStroke.FIG_INK.get(target, Toon.GOLD)
	UiKit.draw_gesture(self, _sb, target, box, u * 1.6, a, _ghost_t, col, true, true)


# ------------------------------------------------------------------ dessin : page du carnet

## Carnet (planche Carnet v2) : les six figures en tuiles sur deux colonnes (geste animé en grand, nom, picto de
## la technique et compte ; la cible cernée de vermillon), puis l'entraînement et les défis.
## Le contenu défile sous le titre fixe ; la page est découpée à son cadre. Aucun texte d'explication :
## le geste qui se trace montre comment faire.
func _draw_page() -> void:
	var ci: Control = _page
	var u := size.x / 400.0
	var w := _page.size.x
	var h := _page.size.y
	var ph := PAGE_HEAD * u
	var pad := 14.0 * u
	var ink: Color = Toon.ui_ink
	var rad := int(16 * u)
	ci.draw_style_box(UiKit.box(_psb, Color(Toon.ui_paper, 1.0), rad), Rect2(Vector2.ZERO, _page.size))
	var hits: Array = []
	var top := ph - _scroll
	var y := top + 12.0 * u
	var x0 := pad
	var x1 := w - pad
	var demo := main != null and main.powers != null and bool(main.powers.demo)
	if demo:
		# une seule phrase sur la page : les techniques sont prêtées au dojo
		var br := Rect2(Vector2(x0, y), Vector2(x1 - x0, 30.0 * u))
		ci.draw_style_box(UiKit.box(_psb, Color(Toon.VERMILION, 0.85), int(10 * u)), br)
		UiKit.draw_icon(ci, "elements/figure", Vector2(br.position.x + 18.0 * u, br.get_center().y), 16.0 * u, 1.0, Toon.WASHI)
		var dfs := int(9.5 * u)
		ci.draw_string(_ui, Vector2(br.position.x + 34.0 * u, br.get_center().y + dfs * 0.36), UiKit.plain("TECHNIQUES PRÊTÉES AU DOJO"), HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Toon.WASHI)
		y += 40.0 * u
	var gap := 10.0 * u
	var tw := (x1 - x0 - gap) / 2.0
	var th := tw * 0.92
	var nf := UiKit.num_font()
	for i in UiKit.FIGURES.size():
		var kind := String(UiKit.FIGURES[i])
		var is_t := kind == target
		var col: Color = Toon.VERMILION if is_t else ink
		var rr := Rect2(Vector2(x0 + float(i % 2) * (tw + gap), y + float(int(i / 2.0)) * (th + gap)), Vector2(tw, th))
		hits.append([Rect2(Vector2(rr.position.x, rr.position.y - top), rr.size), kind])
		var n := int(counts.get(kind, 0))
		if rr.end.y > 0.0 and rr.position.y < h:
			ci.draw_style_box(UiKit.box(_psb, Color(ink, 0.05), int(12 * u), Color(col, 0.95 if is_t else 0.35), maxi(1, int((2.2 if is_t else 1.2) * u))), rr)
			# le geste, en grand (trait sumi, départ vermillon)
			var gs := tw - 36.0 * u
			var gr := Rect2(Vector2(rr.get_center().x - gs / 2.0, rr.position.y + 10.0 * u), Vector2(gs, gs * 0.82))
			UiKit.draw_gesture(ci, _psb, kind, gr, u, 1.0, _t + float(i) * 0.37, ink, true, true)
			# nom à gauche, picto de la technique et compte à droite
			var ty := rr.end.y - 12.0 * u
			var nfs := int(13 * u)
			ci.draw_string(UiKit.TITLE_FONT, Vector2(rr.position.x + 10.0 * u, ty), UiKit.plain(String(UiKit.FIG_WORD.get(kind, kind)).capitalize()), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(ink, 1.0 if n > 0 else 0.6))
			var ct := str(n)
			var cfs := int(12 * u)
			var ctw := nf.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
			ci.draw_string(nf, Vector2(rr.end.x - 10.0 * u - ctw, ty), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(Toon.VERMILION, 1.0) if n > 0 else Color(ink, 0.35))
			var tc := Vector2(rr.end.x - 10.0 * u - ctw - 16.0 * u, ty - cfs * 0.36)
			var on := demo or (main != null and main.powers != null and bool(main.powers.fig_on(kind)))
			var fcol: Color = InkStroke.FIG_INK.get(kind, Toon.GOLD)
			ci.draw_circle(tc, 10.0 * u, Color(fcol, 1.0 if on else 0.25))
			UiKit.draw_icon(ci, String(TECH_ICON.get(kind, "elements/figure")), tc, 13.0 * u, 1.0 if on else 0.5, Toon.WASHI)
	y += 3.0 * (th + gap)
	_row_hits = hits
	# entraînement : figures, esquives, zones, ultimes (chiffres et un mot)
	y += 4.0 * u
	_psection(ci, "ENTRAÎNEMENT", x0, x1, y + 9.0 * u, u)
	y += 30.0 * u
	var cols := [["FIGURES", total_figures()], ["ESQUIVES", dodges], ["ZONES", zones_ok], ["ULTIMES", ults]]
	var sw := (x1 - x0) / float(cols.size())
	for i in cols.size():
		var col_s: Array = cols[i]
		var cx := x0 + sw * (float(i) + 0.5)
		UiKit.text(ci, nf, str(int(col_s[1])), Vector2(cx, y), int(16 * u), Color(ink, 0.9))
		UiKit.text(ci, _ui, String(col_s[0]), Vector2(cx, y + 14.0 * u), int(7.5 * u), Color(ink, 0.55))
		if i > 0:
			ci.draw_line(Vector2(x0 + sw * float(i), y - 14.0 * u), Vector2(x0 + sw * float(i), y + 14.0 * u), Color(ink, 0.12), maxf(1.0, 1.2 * u))
	y += 30.0 * u
	# défis
	_psection(ci, "DÉFIS  %d / %d" % [done.size(), CHALLENGES.size()], x0, x1, y + 9.0 * u, u)
	y += 22.0 * u
	for i in CHALLENGES.size():
		var ch: Dictionary = CHALLENGES[i]
		var ok := done.has(String(ch["id"]))
		y += 19.0 * u
		var bc := Vector2(x0 + 7.0 * u, y - 4.0 * u)
		if ok:
			ci.draw_circle(bc, 7.0 * u, Toon.VERMILION)
			UiKit.glyph(ci, "check", bc, 4.5 * u, Toon.WASHI, UiKit.NONE, 1.0)
		else:
			ci.draw_arc(bc, 6.5 * u, 0, TAU, 20, Color(ink, 0.35), maxf(1.0, 1.5 * u), true)
		ci.draw_string(UiKit.UI_FONT, Vector2(x0 + 22.0 * u, y), UiKit.plain(String(ch["text"])), HORIZONTAL_ALIGNMENT_LEFT, -1, int(10.5 * u), Color(ink, 0.45 if ok else 0.85))
	y += 20.0 * u
	_content_h = y - top
	# bas : fondu quand il reste à lire, et barre de défilement
	var view := h - ph
	var ms := maxf(_content_h - view, 0.0)
	var paper: Color = Toon.ui_paper
	if _scroll < ms - 1.0:
		var fh := 26.0 * u
		ci.draw_polygon(PackedVector2Array([Vector2(0, h - fh), Vector2(w, h - fh), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(paper, 0.0), Color(paper, 0.0), Color(paper, 0.95), Color(paper, 0.95)]))
	if ms > 1.0:
		var bh := maxf(view * view / _content_h, 24.0 * u)
		var by := ph + (view - bh) * (_scroll / ms)
		ci.draw_style_box(UiKit.box(_psb, Color(ink, 0.25), 999), Rect2(Vector2(w - 6.0 * u, by + 4.0 * u), Vector2(3.0 * u, bh - 8.0 * u)))
	# titre fixe : coins hauts arrondis, filet dessous, croix pour refermer
	UiKit.box(_psb, Color(paper, 1.0), rad)
	_psb.corner_radius_bottom_left = 0
	_psb.corner_radius_bottom_right = 0
	ci.draw_style_box(_psb, Rect2(Vector2.ZERO, Vector2(w, ph)))
	ci.draw_line(Vector2(pad, ph), Vector2(w - pad, ph), Color(ink, 0.15), maxf(1.0, 1.5 * u))
	var tfs := int(17 * u)
	ci.draw_string(UiKit.TITLE_FONT, Vector2(pad, 31.0 * u), "Carnet", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, ink)
	var tw2 := UiKit.TITLE_FONT.get_string_size("Carnet", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	ci.draw_rect(Rect2(Vector2(pad + tw2 * 0.2, 36.0 * u), Vector2(tw2 * 0.6, 2.5 * u)), Toon.VERMILION)
	var cc := Vector2(w - pad - 13.0 * u, ph * 0.5)
	_close_rect = Rect2(cc - Vector2(15, 15) * u, Vector2(30, 30) * u)
	ci.draw_circle(cc, 14.0 * u, Color(Toon.ui_wash, 1.0))
	ci.draw_arc(cc, 14.0 * u, 0.0, TAU, 28, Color(ink, 0.6), maxf(1.0, 1.6 * u), true)
	UiKit.glyph(ci, "cross", cc, 5.5 * u, ink, UiKit.NONE, 1.0)
	# liseré par-dessus le contenu
	ci.draw_style_box(UiKit.box(_psb, Color(0, 0, 0, 0), rad, Color(ink, 0.45), maxi(1, int(1.4 * u))), Rect2(Vector2.ZERO, _page.size))


## Titre de section de la page : petit mot puis filet jusqu'au bord.
func _psection(ci: CanvasItem, label: String, x0: float, x1: float, y: float, u: float) -> void:
	var fs := int(8.5 * u)
	var lb := UiKit.plain(label)
	ci.draw_string(_ui, Vector2(x0, y), lb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.ui_ink, 0.55))
	var tw := _ui.get_string_size(lb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_line(Vector2(x0 + tw + 6.0 * u, y - fs * 0.35), Vector2(x1, y - fs * 0.35), Color(Toon.ui_ink, 0.15), maxf(1.0, 1.5 * u))
