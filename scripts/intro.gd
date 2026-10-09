extends Control
## Intro : six planches animées qui présentent le jeu (premier JOUER, ou bouton « ? » de l'accueil).
## Glisser à gauche / à droite, ou toucher, pour tourner les planches.
## main appelle open(replay) ; l'intro émet finished(action) : "done" (fin ou PASSER au premier lancement),
## "tuto" (lancer le tutoriel, depuis le « ? ») ou "back" (retour à l'accueil).

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

signal finished(action: String)

const PAGES := [
	{"kanji": "一", "title": "Un seul trait",
		"text": "Trace un trait du doigt : ton ronin fonce le long et tranche tout ce qu'il touche."},
	{"kanji": "墨", "title": "L'encre",
		"text": "Chaque trait coûte de l'encre (la jauge à droite). Elle remonte quand tu ne traces pas, et à chaque ennemi touché."},
	{"kanji": "円", "title": "Les figures",
		"text": "Boucle, zigzag, ensō… Une forme cachée dans ton trait : +1 chaîne. Ramasse son rouleau de figure pour débloquer sa technique, puis l'améliorer."},
	{"kanji": "風", "title": "Esquive",
		"text": "Une zone rouge annonce un coup : sors-en ! Un tap = un bond d'esquive (gratuit). Pas touché ? Ta chaîne monte, tes dégâts aussi."},
	{"kanji": "道", "title": "Progresse",
		"text": "Nettoie les vagues, ramasse l'XP et l'or. Chaque niveau t'offre un rouleau de pouvoir, du commun au légendaire. Puis le torii s'ouvre."},
	{"kanji": "鬼", "title": "8 étapes, un gardien",
		"text": "Avance de combat en combat, fouille les recoins. Mini-boss à l'étape 4, gardien du monde à l'étape 8. Bonne route !"},
]
const INPUT_DELAY := 0.3  # le toucher qui a ouvert l'intro (ou tourné la planche) ne compte pas
const TRANS := 0.35  # durée du fondu entre deux planches
const GLUE := [":", ";", "!", "?", "%", "=", "…"]  # jamais en début de ligne
const JADE := Color("#3FD1B2")
const SHAPES := ["loop", "zigzag", "straight", "enso"]
const SHAPE_LABELS := ["BOUCLE", "ZIGZAG", "DROIT", "ENSŌ"]
const TECH_NAMES := ["TOUPIE", "RUÉE ÉCLAIR", "IAÏ", "FRAPPE AU SOL"]
const RARITY_COLS := [Color("#8A8478"), Color("#3D78B8"), Color("#8752B5"), Color("#E2A93B")]
const RARITY_NAMES := ["COMMUN", "RARE", "ÉPIQUE", "LÉGENDAIRE"]
const CARD_KANJI := ["火", "水", "雷", "風"]
const CARD_COLS := [Color("#D7372B"), Color("#1F3A5F"), Color("#C49A45"), Color("#5F8F86")]
const LEG_BODY := Color("#1C1A21")

var replay := false  # ouverte depuis le « ? » : la dernière planche propose le tutoriel
var page := 0
var _t := 0.0  # temps réel depuis l'ouverture
var _pt := 0.0  # temps réel depuis le changement de planche
var _prev := -1  # planche qui s'efface pendant la transition
var _prev_t0 := 0.0
var _dir := 1
var _down := false
var _down_ok := false
var _down_pos := Vector2.ZERO
var _next: Control
var _skip: Control
var _tuto: Control
var _back: Control
var _ui := FontVariation.new()
var _btn := FontVariation.new()
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné
# contexte de dessin de la planche en cours
var _a := 1.0
var _u := 1.0
var _r := Rect2()
var _now := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 1
	_btn.base_font = UiKit.UI_FONT
	_btn.spacing_glyph = 2
	_next = _button("SUIVANT", "primary")
	_next.pressed.connect(_on_next)
	_skip = _button("PASSER", "ghost")
	_skip.pressed.connect(func(): _finish("back" if replay else "done"))
	_tuto = _button("LANCER LE TUTORIEL", "primary")
	_tuto.lead_icon = "play"
	_tuto.pressed.connect(func(): _finish("tuto"))
	_back = _button("RETOUR", "ghost")
	_back.pressed.connect(func(): _finish("back"))


func _button(label: String, style: String) -> Control:
	var b := InkButton.new()
	b.text = label
	b.style = style
	b.font = _btn
	add_child(b)
	return b


func open(from_help: bool) -> void:
	replay = from_help
	page = 0
	_prev = -1
	_t = 0.0
	_pt = 0.0
	_down = false
	visible = true


## Fermeture immédiate (bouton Retour du téléphone).
func close() -> void:
	if visible:
		visible = false
		finished.emit("back")


func _finish(action: String) -> void:
	if not visible or _pt < INPUT_DELAY:
		return
	visible = false
	finished.emit(action)


func _on_next() -> void:
	if _pt < INPUT_DELAY:
		return
	if page >= PAGES.size() - 1:
		_finish("done")
	else:
		_go(page + 1)


func _go(i: int) -> void:
	if i < 0 or i >= PAGES.size() or i == page:
		return
	_prev = page
	_prev_t0 = _pt
	_dir = 1 if i > page else -1
	page = i
	_pt = 0.0


## Glisser pour tourner les planches, toucher pour avancer (les boutons gardent leurs propres touchers).
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	accept_event()
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = true
		_down_ok = _pt >= INPUT_DELAY
		_down_pos = mb.position
		return
	if not _down:
		return
	_down = false
	if not _down_ok:
		return
	var u := _unit()
	var d := mb.position - _down_pos
	if absf(d.x) > 48.0 * u and absf(d.x) > absf(d.y) * 1.2:
		_go(page + 1 if d.x < 0.0 else page - 1)
	elif d.length() < 24.0 * u and page < PAGES.size() - 1:
		_go(page + 1)


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	_pt += real
	_layout()
	queue_redraw()


func _unit() -> float:
	return minf(size.x / 400.0, size.y / 800.0)


func _card() -> Rect2:
	var u := _unit()
	var cw := minf(size.x - 28.0 * u, 372.0 * u)
	var ch := 686.0 * u
	var top := 66.0 * u + maxf(0.0, (size.y - 84.0 * u - ch) / 2.0)
	return Rect2(Vector2((size.x - cw) / 2.0, top), Vector2(cw, ch))


func _panel_rect(card: Rect2) -> Rect2:
	var u := _unit()
	return Rect2(card.position + Vector2(16, 44) * u, Vector2(card.size.x - 32.0 * u, 290.0 * u))


func _layout() -> void:
	var u := _unit()
	var card := _card()
	var a := UiKit.ease_out(_t / 0.3)
	var last := page == PAGES.size() - 1
	var two := last and replay
	_skip.visible = not last
	_skip.size = Vector2(100, 36) * u
	_skip.position = Vector2(card.end.x - 100.0 * u, 22.0 * u)
	_skip.font_size = int(13 * u)
	_skip.modulate.a = a
	_next.visible = not two
	_next.text = "C'EST PARTI" if last else "SUIVANT"
	_next.lead_icon = "play" if last else ""
	var bw := card.size.x * 0.7
	_next.size = Vector2(bw, 58.0 * u)
	_next.position = Vector2(card.get_center().x - bw / 2.0, card.end.y - 80.0 * u)
	_next.font_size = int(20 * u)
	_next.modulate.a = a
	_tuto.visible = two
	_tuto.size = Vector2(card.size.x - 56.0 * u, 54.0 * u)
	_tuto.position = Vector2(card.position.x + 28.0 * u, card.end.y - 136.0 * u)
	_tuto.font_size = int(17 * u)
	_back.visible = two
	_back.size = Vector2(card.size.x * 0.5, 44.0 * u)
	_back.position = Vector2(card.get_center().x - card.size.x * 0.25, card.end.y - 70.0 * u)
	_back.font_size = int(15 * u)


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	if size.x < 10.0:
		return
	var u := _unit()
	var a := UiKit.ease_out(_t / 0.3)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.86 * a))
	var card := _card()
	card.position.y += 18.0 * u * (1.0 - a)
	draw_string(_ui, Vector2(card.position.x + 4.0 * u, 46.0 * u), "COMMENT JOUER", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), Color(Toon.WASHI, 0.7 * a))
	# carte de papier et cadre de l'illustration
	UiKit.box(_sb, Color(Toon.PAPER, a), int(18 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.5 * a)
	_sb.shadow_size = int(20 * u)
	draw_style_box(_sb, card)
	var panel := _panel_rect(card)
	# cadre de l'illustration (absent du lexique : il s'efface pendant la transition)
	var k := UiKit.ease_out(_pt / TRANS)
	var fr := _framed(page)
	if _prev >= 0 and k < 1.0:
		fr = lerpf(_framed(_prev), fr, k)
	if fr > 0.01:
		draw_style_box(UiKit.box(_sb, Color(Toon.WASHI, a * fr), int(12 * u), Color(Toon.SUMI, 0.8 * a * fr), int(maxf(1.0, 2.0 * u))), panel)
	_a = a * fr
	_u = u
	_r = panel
	_ellipse(_at(0.5, 0.88), panel.size.x * 0.44, panel.size.y * 0.09, _c(Toon.SUMI, 0.05))  # lavis au sol
	draw_string(_ui, card.position + Vector2(20, 30) * u, "%d / %d" % [page + 1, PAGES.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(Toon.VERMILION, a))
	# planches : fondu enchaîné, le texte glisse dans le sens de la lecture
	if _prev >= 0 and k < 1.0:
		_draw_page(_prev, card, panel, u, a * (1.0 - k), -_dir * 36.0 * u * k, _prev_t0 + _pt)
		_draw_page(page, card, panel, u, a * k, _dir * 36.0 * u * (1.0 - k), _pt)
	else:
		_draw_page(page, card, panel, u, a, 0.0, _pt)
	# points de progression
	var n := PAGES.size()
	var dy := card.position.y + 504.0 * u
	var x0 := card.get_center().x - (n - 1) * 8.0 * u
	for i in n:
		var c := Vector2(x0 + i * 16.0 * u, dy)
		if i == page:
			draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, a), int(4 * u)), Rect2(c - Vector2(9, 3.5) * u, Vector2(18, 7) * u))
		else:
			draw_circle(c, 3.5 * u, Color(Toon.SUMI, (0.55 if i < page else 0.2) * a))
	if page == 0:
		var ha := a * (0.35 + 0.15 * sin(_t * 3.0))
		UiKit.text(self, _ui, "GLISSE OU TOUCHE POUR CONTINUER", Vector2(card.get_center().x, dy + 26.0 * u), int(9 * u), Color(Toon.SUMI, ha))


## 1.0 pour une planche illustrée, 0.0 pour le lexique (sans cadre).
func _framed(i: int) -> float:
	var pg: Dictionary = PAGES[i]
	return 0.0 if pg.has("terms") else 1.0


func _draw_page(i: int, card: Rect2, panel: Rect2, u: float, alpha: float, dx: float, t: float) -> void:
	if alpha <= 0.01:
		return
	_a = alpha
	_u = u
	_r = panel
	_now = t
	match i:
		0:
			_page_trait(t)
		1:
			_page_encre(t)
		2:
			_page_figures(t)
		3:
			_page_esquive(t)
		4:
			_page_progres(t)
		_:
			_page_gardien(t)
	var pg: Dictionary = PAGES[i]
	# sceau de la planche
	var seal := Rect2(Vector2(card.end.x - 48.0 * u, card.position.y + 10.0 * u), Vector2(30, 30) * u)
	draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, alpha), int(6 * u)), seal)
	UiKit.text(self, UiKit.TITLE_FONT, String(pg.kanji), seal.get_center() + Vector2(0, 8.0 * u), int(21 * u), Color(Toon.WASHI, alpha))
	if pg.has("terms"):
		_page_lexique(pg, card, dx, t)
		return
	# titre et texte
	var cx := card.get_center().x + dx
	var ty := panel.end.y + 44.0 * u
	var title := UiKit.plain(String(pg.title))
	var tfs := int(27 * u)
	while tfs > 12 and UiKit.TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > card.size.x - 40.0 * u:
		tfs -= 1
	UiKit.text(self, UiKit.TITLE_FONT, title, Vector2(cx, ty), tfs, Color(Toon.SUMI, alpha))
	draw_line(Vector2(cx - 22.0 * u, ty + 12.0 * u), Vector2(cx + 22.0 * u, ty + 12.0 * u), Color(Toon.VERMILION, alpha), 2.0 * u)
	var fs := int(14 * u)
	var lines := _wrap(UiKit.UI_FONT, UiKit.plain(String(pg.text)), fs, card.size.x - 48.0 * u)
	for j in mini(lines.size(), 4):
		UiKit.text(self, UiKit.UI_FONT, lines[j], Vector2(cx, ty + 40.0 * u + j * 21.0 * u), fs, Color(Toon.SUMI, 0.8 * alpha))


## Coupe un texte en lignes qui tiennent dans `width` (mots entiers ; la ponctuation reste collée au mot).
func _wrap(font: Font, txt: String, fs: int, width: float) -> PackedStringArray:
	return UiKit.wrap(font, txt, fs, width, GLUE)


# ------------------------------------------------------------------ planches

## 1. Un doigt trace, le ronin fonce le long du trait et tranche deux squelettes.
func _page_trait(t0: float) -> void:
	var u := _u
	var t := fmod(t0, 3.4)
	var fade := 1.0 - _k(t, 3.0, 0.4)
	var a0 := _at(0.12, 0.8)
	var path := _bez_pts(a0, _at(0.42, -0.1), _at(0.88, 0.48), 40)
	var feet := Vector2(0, 14) * u
	var drawn := _k(t, 0.15, 0.9)
	var dash := _k(t, 1.1, 0.7)
	for j in 2:
		var hp := 0.45 if j == 0 else 0.78
		var t_hit := 1.1 + 0.7 * hp
		var sp := _pt_at(path, hp) + feet
		var cut := -1.0
		if t >= t_hit:
			cut = _k(t, t_hit, 0.8)
		_skeleton(sp, 0.95 * u, cut, _k(t, 0.0, 0.25))
		if cut >= 0.0:
			_slash_fx(sp - Vector2(0, 16) * u, cut)
	if drawn > 0.0:
		_stroke(path, dash, drawn, 6.0 * u, _c(Toon.SUMI, fade))
	var rp := a0 + feet
	if dash > 0.0:
		rp = _pt_at(path, dash) + feet
		if dash < 1.0:
			for g in 3:
				var gd := maxf(0.0, dash - 0.07 * (g + 1))
				_ronin(_pt_at(path, gd) + feet, u, 1.0, true, 0.22 * (3 - g) / 3.0 * fade)
	_ronin(rp, u, 1.0, dash > 0.0 and dash < 1.0, fade * _k(t, 0.0, 0.2))
	if t < 1.3:
		_finger(_pt_at(path, drawn), u, _k(t, 0.0, 0.15) * (1.0 - _k(t, 1.05, 0.2)))
	if t > 1.85:
		var pk := UiKit.ease_out(_k(t, 1.85, 0.25))
		UiKit.text(self, UiKit.TITLE_FONT, "×2", rp + Vector2(0, -50) * u, int((18.0 + 10.0 * (1.0 - pk)) * u), _c(Toon.VERMILION, pk * fade))


## 2. Petit lexique : huit mots du jeu, chacun avec sa pastille ; les lignes arrivent l'une après l'autre.
func _page_lexique(pg: Dictionary, card: Rect2, dx: float, t: float) -> void:
	var u := _u
	var base_a := _a
	var cx := card.get_center().x + dx
	var ty := card.position.y + 74.0 * u
	UiKit.text(self, UiKit.TITLE_FONT, UiKit.plain(String(pg.title)), Vector2(cx, ty), int(25 * u), _c(Toon.SUMI))
	draw_line(Vector2(cx - 22.0 * u, ty + 12.0 * u), Vector2(cx + 22.0 * u, ty + 12.0 * u), _c(Toon.VERMILION), 2.0 * u)
	var terms: Array = pg.terms
	var wmax := card.size.x - 88.0 * u
	for j in terms.size():
		var row: Array = terms[j]
		var k := UiKit.ease_out(_k(t, 0.1 + 0.07 * j, 0.4))
		if k <= 0.0:
			continue
		_a = base_a * k
		var y := card.position.y + (100.0 + 48.0 * j) * u
		var ox := card.position.x + dx + 14.0 * u * (1.0 - k)
		if j > 0:
			draw_line(Vector2(ox + 24.0 * u, y), Vector2(ox + card.size.x - 24.0 * u, y), _c(Toon.SUMI, 0.08), maxf(1.0, u))
		_lex_icon(String(row[0]), Vector2(ox + 38.0 * u, y + 24.0 * u), 17.0 * u, k)
		draw_string(UiKit.TITLE_FONT, Vector2(ox + 70.0 * u, y + 21.0 * u), UiKit.plain(String(row[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), _c(Toon.SUMI))
		var d := UiKit.plain(String(row[2]))
		var fs := int(12 * u)
		while fs > 8 and UiKit.UI_FONT.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > wmax:
			fs -= 1
		draw_string(UiKit.UI_FONT, Vector2(ox + 70.0 * u, y + 39.0 * u), d, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _c(Toon.SUMI, 0.75))
	_a = base_a


## Pastille d'un mot du lexique : sceau rond (comme ceux des figures) et petit dessin à l'encre.
## r = rayon du sceau ; k = arrivée de la ligne (le trait se dessine pendant ce temps).
func _lex_icon(kind: String, c: Vector2, r: float, k: float) -> void:
	if kind == "figure":
		_symbol("loop", c, r, 1.0)
		return
	draw_circle(c, r + 2.5 * r / 30.0, _c(Toon.SUMI, 0.85))
	draw_circle(c, r, _c(Toon.PAPER, 0.95))
	var s := r / 17.0
	match kind:
		"trait":
			# un trait de pinceau, la pointe vermillon au bout
			var pts := _bez_pts(c + Vector2(-10, 7) * s, c + Vector2(-2, -15) * s, c + Vector2(10, -3) * s, 16)
			_stroke(pts, 0.0, k, 4.0 * s, _c(Toon.SUMI))
			draw_circle(_pt_at(pts, k), 2.0 * s, _c(Toon.VERMILION))
		"encre":
			# une goutte au-dessus de la jauge
			_drop(c + Vector2(0, -3) * s, 5.5 * s, _c(Toon.SUMI))
			_bar(c + Vector2(-10, 6.5) * s, 20.0 * s, 4.5 * s, 1.0, _c(Toon.SUMI, 0.15))
			_bar(c + Vector2(-10, 6.5) * s, 20.0 * s, 4.5 * s, 0.6, _c(Toon.SUMI))
		"esquive":
			# un bond hors de la zone rouge
			draw_line(c + Vector2(-13, 8) * s, c + Vector2(13, 8) * s, _c(Toon.SUMI, 0.3), 1.2 * s, true)
			_ellipse(c + Vector2(-8, 8) * s, 6.0 * s, 2.2 * s, _c(Toon.VERMILION, 0.5))
			draw_circle(c + Vector2(-8, 3) * s, 3.0 * s, _c(Toon.SUMI, 0.25))
			draw_arc(c + Vector2(0, 3) * s, 8.0 * s, PI * 1.1, PI * 1.9, 12, _c(Toon.SUMI, 0.7), 1.6 * s, true)
			draw_circle(c + Vector2(8, 3) * s, 3.2 * s, _c(Toon.SUMI))
			draw_line(c + Vector2(6, 2) * s, c + Vector2(2, 1) * s, _c(Toon.VERMILION), 1.2 * s, true)
		"chaine":
			# trois maillons
			_ellipse_line(c + Vector2(-8, 0) * s, 5.5 * s, 3.6 * s, _c(Toon.PRUSSIAN), 2.2 * s)
			_ellipse_line(c, 3.6 * s, 5.5 * s, _c(Toon.PRUSSIAN), 2.2 * s)
			_ellipse_line(c + Vector2(8, 0) * s, 5.5 * s, 3.6 * s, _c(Toon.PRUSSIAN), 2.2 * s)
		"rouleau":
			# un rouleau dont le liseré passe par les quatre raretés
			var rc: Color = RARITY_COLS[int(_now / 0.9) % RARITY_COLS.size()]
			var body := Rect2(c + Vector2(-7, -9) * s, Vector2(14, 18) * s)
			draw_style_box(UiKit.box(_sb, _c(Toon.WASHI), int(2 * s), _c(rc), int(maxf(1.0, 1.6 * s))), body)
			draw_rect(Rect2(c + Vector2(-9, -11) * s, Vector2(18, 2.5) * s), _c(Toon.SUMI))
			draw_rect(Rect2(c + Vector2(-9, 8.5) * s, Vector2(18, 2.5) * s), _c(Toon.SUMI))
			draw_rect(Rect2(c + Vector2(-4, -6) * s, Vector2(8, 6) * s), _c(rc))
			draw_line(c + Vector2(-4, 3.5) * s, c + Vector2(4, 3.5) * s, _c(Toon.SUMI, 0.35), 1.5 * s)
		"affinite":
			# deux sceaux d'une même école, reliés par un arc d'or
			var pulse := 0.6 + 0.4 * sin(_now * 3.0)
			draw_arc(c + Vector2(0, -2) * s, 7.0 * s, PI * 1.15, PI * 1.85, 10, _c(Toon.GOLD, pulse), 1.8 * s, true)
			for sx in [-1.0, 1.0]:
				var q := Rect2(c + Vector2(6.5 * sx - 4.5, -2.0) * s, Vector2(9, 9) * s)
				draw_style_box(UiKit.box(_sb, _c(Toon.VERMILION), int(2 * s)), q)
			draw_circle(c + Vector2(0, -12.5) * s, 1.6 * s, _c(Toon.GOLD, pulse))
		_:
			# la porte, entrouverte sur l'or
			_torii(c + Vector2(0, 10) * s, 0.36 * s, 0.35 + 0.1 * sin(_now * 2.0), 1.0)


## 3. Tracer vide la jauge d'encre ; toucher un ennemi en rend un peu ; au repos, elle remonte.
func _page_encre(t0: float) -> void:
	var u := _u
	var t := fmod(t0, 3.8)
	var fade := 1.0 - _k(t, 3.4, 0.4)
	var feet := Vector2(0, 14) * u
	var a0 := _at(0.1, 0.42)
	var b0 := _at(0.84, 0.42)
	var path := PackedVector2Array()
	for i in 41:
		var f := float(i) / 40.0
		path.append(a0.lerp(b0, f) + Vector2(0, sin(f * TAU * 1.5) * 24.0 * u))
	var drawn := _k(t, 0.1, 1.3)
	var dash := _k(t, 1.5, 0.45)
	var sk := b0 + feet + Vector2(8, 0) * u
	var cut := -1.0
	if t >= 1.95:
		cut = _k(t, 1.95, 0.8)
	_skeleton(sk, 0.95 * u, cut, _k(t, 0.0, 0.25))
	if cut >= 0.0:
		_slash_fx(sk - Vector2(0, 16) * u, cut)
	if drawn > 0.0:
		_stroke(path, dash, drawn, 6.0 * u, _c(Toon.SUMI, fade))
	var rp := a0 + feet
	if dash > 0.0:
		rp = _pt_at(path, dash) + feet
	_ronin(rp, u, 1.0, dash > 0.0 and dash < 1.0, fade * _k(t, 0.0, 0.2))
	if t < 1.6:
		_finger(_pt_at(path, drawn), u, _k(t, 0.0, 0.15) * (1.0 - _k(t, 1.35, 0.2)))
	# la jauge
	var ink := 1.0 - 0.72 * drawn
	if t >= 2.4:
		ink = lerpf(0.46, 1.0, UiKit.ease_out(_k(t, 2.5, 0.9)))
	var gx := _at(0.17, 0.0).x
	var gw := _r.size.x * 0.7
	var gh := 15.0 * u
	var gy := _at(0.0, 0.78).y
	_drop(Vector2(gx - 16.0 * u, gy + gh / 2.0), 5.5 * u, _c(Toon.SUMI))
	_bar(Vector2(gx, gy), gw, gh, 1.0, _c(Toon.SUMI, 0.13))
	var col := Toon.SUMI
	if ink < 0.32:
		col = Toon.VERMILION if int(t * 8.0) % 2 == 0 else Toon.SUMI
	_bar(Vector2(gx, gy), gw, gh, ink, _c(col))
	if ink >= 0.999:
		draw_circle(Vector2(gx + gw, gy + gh / 2.0), 3.5 * u + 1.5 * u * sin(t * 6.0), _c(Toon.GOLD))
	# gouttes d'encre rendues par l'ennemi touché
	if t >= 1.95 and t < 2.4:
		var dk := _k(t, 1.95, 0.45)
		var en := Vector2(gx + gw * 0.4, gy + gh / 2.0)
		for j in 3:
			var q := clampf(dk * 1.3 - j * 0.15, 0.0, 1.0)
			if q > 0.0 and q < 1.0:
				var st := sk - Vector2(0, 18) * u
				_drop(_bez(st, (st + en) / 2.0 + Vector2(-40.0 + 25.0 * j, -40.0) * u, en, q), 4.0 * u, _c(Toon.SUMI))
	if t >= 2.4 and t < 2.9:
		var fk := _k(t, 2.4, 0.5)
		draw_arc(Vector2(gx + gw * 0.46, gy + gh / 2.0), (6.0 + 18.0 * fk) * u, 0, TAU, 24, _c(Toon.GOLD, 1.0 - fk), 2.5 * u, true)
	var cap := "TU TRACES : L'ENCRE BAISSE"
	if t >= 2.6:
		cap = "TU NE TRACES PAS : ELLE REMONTE"
	elif t >= 1.95:
		cap = "ENNEMI TOUCHÉ : + ENCRE"
	UiKit.text(self, _ui, cap, _at(0.5, 0.95), int(10 * u), _c(Toon.SUMI, 0.7))


## 4. Quatre formes tracées tour à tour : chacune allume son sceau et montre la technique que son rouleau débloque.
func _page_figures(t0: float) -> void:
	var u := _u
	var cyc := 1.9
	var si := int(t0 / cyc) % SHAPES.size()
	var t := fmod(t0, cyc)
	var fade := 1.0 - _k(t, 1.55, 0.35)
	var box := Rect2(_at(0.3, 0.04), _r.size * Vector2(0.4, 0.46))
	var kind := String(SHAPES[si])
	var raw := _gesture_points(kind)
	var pts := PackedVector2Array()
	for i in raw.size():
		pts.append(box.position + raw[i] * box.size)
	var drawn := _k(t, 0.05, 0.85)
	if drawn > 0.0:
		_stroke(pts, 0.0, drawn, 6.0 * u, _c(Toon.SUMI, fade))
	if t >= 0.9:
		_tech_fx(kind, box, pts, _k(t, 0.9, 0.65), fade)
		var nk := UiKit.ease_out(_k(t, 0.9, 0.2))
		UiKit.text(self, UiKit.TITLE_FONT, String(TECH_NAMES[si]) + " !", _at(0.5, 0.63), int(17.0 * u * (1.0 + 0.3 * (1.0 - nk))), _c(Toon.VERMILION, nk * fade))
	if t < 1.1:
		_finger(_pt_at(pts, drawn), u, _k(t, 0.0, 0.12) * (1.0 - _k(t, 0.85, 0.15)))
	# la rangée des sceaux
	for j in SHAPES.size():
		var c := _at(0.2 + 0.2 * j, 0.79)
		var al := 0.35
		var rr := 19.0 * u
		if j == si and t >= 0.9:
			al = 1.0
			rr *= 1.0 + 0.3 * (1.0 - UiKit.ease_out(_k(t, 0.9, 0.3)))
			draw_arc(c, rr + 6.0 * u, 0, TAU, 32, _c(Toon.VERMILION, 1.0 - _k(t, 1.7, 0.2)), 2.5 * u, true)
		_symbol(String(SHAPES[j]), c, rr, al)
		UiKit.text(self, _ui, UiKit.plain(String(SHAPE_LABELS[j])), _at(0.2 + 0.2 * j, 0.96), int(9 * u), _c(Toon.SUMI, 0.4 + 0.5 * (al - 0.35) / 0.65))


func _tech_fx(kind: String, box: Rect2, pts: PackedVector2Array, k: float, fade: float) -> void:
	var u := _u
	var c := box.position + box.size * Vector2(0.5, 0.55)
	match kind:
		"loop":
			# toupie : arcs qui tournent autour du héros
			var rot := k * TAU * 1.5
			for j in 3:
				var a0 := rot + TAU * j / 3.0
				draw_arc(c, (30.0 + 14.0 * k) * u, a0, a0 + 1.4, 12, _c(Toon.VERMILION, (1.0 - k) * fade), 3.0 * u, true)
		"zigzag":
			# éclair : le trait s'électrise
			var fl := 0.6 + 0.4 * sin(_now * 40.0)
			draw_polyline(pts, _c(Toon.GOLD, (1.0 - k) * fl * fade), 4.0 * u, true)
			for j in 5:
				var p := _pt_at(pts, j / 4.0)
				draw_line(p, p + Vector2.from_angle(j * 2.3 + _now * 9.0) * 9.0 * u, _c(Toon.GOLD, (1.0 - k) * fade), 2.0 * u, true)
		"straight":
			# iaï : une coupe nette prolonge la ligne
			var top := _pt_at(pts, 1.0)
			var bot := _pt_at(pts, 0.0)
			var d := (top - bot).normalized()
			var e := UiKit.ease_out(k * 2.0)
			draw_line(bot - d * 16.0 * u * e, top + d * 16.0 * u * e, _c(Toon.VERMILION, (1.0 - k) * fade), 5.0 * u * (1.0 - k) + 1.0, true)
		_:
			# ensō : onde de choc au sol
			var ce := box.get_center()
			for j in 2:
				var rk := clampf(k * 1.3 - j * 0.3, 0.0, 1.0)
				if rk > 0.0 and rk < 1.0:
					draw_arc(ce, (20.0 + 60.0 * rk) * u, 0, TAU, 40, _c(Toon.SUMI, (1.0 - rk) * 0.6 * fade), 3.0 * u * (1.0 - rk) + 1.0, true)


## 5. Une zone rouge se remplit ; un tap fait bondir le ronin hors de portée ; la chaîne monte.
func _page_esquive(t0: float) -> void:
	var u := _u
	var lp := 3.4
	var t := fmod(t0, lp)
	var side := 1.0 if int(t0 / lp) % 2 == 0 else -1.0
	var c0 := _at(0.5, 0.66)
	var fade := (1.0 - _k(t, 3.0, 0.4)) * _k(t, 0.0, 0.2)
	var rx := 72.0 * u
	var ry := 28.0 * u
	# la zone annonce le coup
	if t < 1.8:
		var za := _k(t, 0.1, 0.2) * (1.0 - _k(t, 1.3, 0.5))
		var fill := _k(t, 0.2, 1.1)
		_ellipse(c0, rx, ry, _c(Toon.VERMILION, 0.12 * za))
		_ellipse(c0, rx * fill, ry * fill, _c(Toon.VERMILION, 0.35 * za))
		_ellipse_line(c0, rx, ry, _c(Toon.VERMILION, 0.9 * za), 2.5 * u)
	# le coup tombe…
	if t >= 1.0 and t < 1.32:
		var fk := _k(t, 1.0, 0.3)
		var bp := _at(0.5, -0.05).lerp(c0 - Vector2(0, 6) * u, fk * fk)
		draw_line(bp - Vector2(0, 46) * u, bp, _c(Toon.SUMI, 0.25), 12.0 * u, true)
		draw_circle(bp, 14.0 * u, _c(Toon.SUMI, 0.95))
	# … et frappe le sol
	if t >= 1.3 and t < 2.2:
		var ik := _k(t, 1.3, 0.9)
		_ellipse(c0, rx * (1.0 + 0.3 * ik), ry * (1.0 + 0.3 * ik), _c(Toon.SUMI, 0.45 * (1.0 - ik)))
		for j in 6:
			var ang := TAU * j / 6.0 + 0.3
			var reach := minf(1.0, ik * 3.0)
			draw_line(c0, c0 + Vector2(cos(ang) * 64.0, sin(ang) * 26.0) * u * reach, _c(Toon.SUMI, 0.8 * (1.0 - ik)), 2.0 * u, true)
	# le bond d'esquive
	var hop := _k(t, 0.8, 0.32)
	var land := c0 + Vector2(side * 108.0 * u, 0)
	var rp := c0.lerp(land, UiKit.ease_out(hop)) + Vector2(0, -sin(PI * hop) * 30.0 * u)
	if hop > 0.0 and hop < 1.0:
		for g in 3:
			var gh := maxf(0.0, hop - 0.12 * (g + 1))
			_ronin(c0.lerp(land, UiKit.ease_out(gh)) + Vector2(0, -sin(PI * gh) * 30.0 * u), u, side, false, 0.2 * (3 - g) / 3.0 * fade)
	_ronin(rp, u, side, false, fade)
	if t >= 1.15 and t < 2.4:
		var ek := _k(t, 1.15, 0.2) * (1.0 - _k(t, 2.1, 0.3))
		UiKit.text(self, _ui, "ESQUIVE !", land + Vector2(0, -54) * u, int(11 * u), _c(Toon.PRUSSIAN, ek))
	# le doigt qui tape (petit glissé vers le côté du bond)
	var fk2 := _k(t, 0.4, 0.15) * (1.0 - _k(t, 1.0, 0.2))
	if fk2 > 0.0:
		var flick := UiKit.ease_out(_k(t, 0.62, 0.18))
		var base := c0 + Vector2(-side * 14.0, 34.0) * u
		var tip := base + Vector2(side * 34.0, -6.0) * u * flick
		if flick > 0.0:
			draw_line(base, tip, _c(Toon.SUMI, 0.6 * fk2), 4.0 * u, true)
		_finger(tip, 0.9 * u, fk2)
	# la chaîne (comme en jeu, sous les cœurs)
	var up := t >= 1.55
	var n := 5 if up else 4
	var bp2 := _at(0.04, 0.06)
	var tier: Color = Toon.PRUSSIAN if up else Toon.SUMI
	draw_style_box(UiKit.box(_sb, _c(Toon.PAPER, 0.9), int(8 * u), _c(tier), int(2 * u)), Rect2(bp2, Vector2(132, 36) * u))
	draw_string(UiKit.UI_FONT, bp2 + Vector2(9, 14) * u, "CHAÎNE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), _c(Toon.SUMI, 0.6))
	var pop := 1.0
	if up:
		pop = 1.0 + 0.45 * (1.0 - UiKit.ease_out(_k(t, 1.55, 0.3)))
	draw_string(UiKit.TITLE_FONT, bp2 + Vector2(9, 31) * u, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, int(17.0 * u * pop), _c(tier))
	draw_string(UiKit.UI_FONT, bp2 + Vector2(52, 28) * u, "+%d %% DÉGÂTS" % (n * 5), HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), _c(Toon.SUMI, 0.8))


## 6. Les vagues tombent, l'XP et l'or filent vers la barre, un rouleau apparaît, le torii s'ouvre.
func _page_progres(t0: float) -> void:
	var u := _u
	var lp := 4.6
	var t := fmod(t0, lp)
	var rar := int(t0 / lp) % RARITY_COLS.size()
	var fade := 1.0 - _k(t, 4.2, 0.4)
	var ground := _at(0.0, 0.8).y
	# le torii, qui s'ouvre quand la salle est nettoyée
	var gate := Vector2(_at(0.85, 0.0).x, ground)
	_torii(gate, 1.25 * u, _k(t, 3.3, 0.5), fade)
	# niveau, barre d'XP et or
	var lv_up := t >= 1.85
	var bar_p := _at(0.05, 0.1)
	var bx := bar_p.x + 40.0 * u
	var bw := _r.size.x * 0.34
	var bar_end := Vector2(bx + bw, bar_p.y)
	var coin_p := Vector2(bx + bw + 16.0 * u, bar_p.y + 1.0 * u)
	var xp_f := 0.3 + 0.7 * _k(t, 1.0, 0.8)
	if lv_up:
		xp_f = 0.06
	draw_string(UiKit.UI_FONT, bar_p + Vector2(0, 4) * u, "NIV %d" % (2 if lv_up else 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), _c(Toon.SUMI))
	draw_rect(Rect2(Vector2(bx, bar_p.y - 2.0 * u), Vector2(bw, 7.0 * u)), _c(Toon.SUMI, 0.55))
	draw_rect(Rect2(Vector2(bx + 1.0 * u, bar_p.y - 1.0 * u), Vector2((bw - 2.0 * u) * xp_f, 5.0 * u)), _c(JADE))
	if t >= 1.85 and t < 2.4:
		var lk := _k(t, 1.85, 0.55)
		draw_rect(Rect2(Vector2(bx, bar_p.y - 2.0 * u), Vector2(bw, 7.0 * u)).grow(5.0 * u * lk), _c(JADE, 0.6 * (1.0 - lk)))
	_coin(coin_p, 5.5 * u, 1.0)
	var coins := 12 + int(clampf((t - 1.0) / 0.25, 0.0, 3.0))
	draw_string(UiKit.UI_FONT, coin_p + Vector2(9, 4) * u, str(coins), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), _c(Toon.SUMI))
	# la vague : trois squelettes tranchés d'un trait, chacun lâche une gemme et une pièce
	var rx0 := Vector2(_at(0.04, 0.0).x, ground)
	var rx1 := Vector2(_at(0.66, 0.0).x, ground)
	var dash := _k(t, 0.15, 0.55)
	for j in 3:
		var x := 0.18 + 0.16 * j
		var sp := Vector2(_at(x, 0.0).x, ground)
		var hit_t := 0.15 + 0.55 * (x - 0.04) / 0.62
		var cut := -1.0
		if t >= hit_t:
			cut = _k(t, hit_t, 0.7)
		_skeleton(sp, 0.9 * u, cut, _k(t, 0.0, 0.25))
		if cut >= 0.0:
			_slash_fx(sp - Vector2(0, 15) * u, cut)
		if t >= hit_t + 0.1:
			var jump := _k(t, hit_t + 0.1, 0.3)
			var fly := _k(t, 1.0 + 0.1 * j, 0.5)
			if fly < 1.0:
				var lift := Vector2(0, -10.0 - sin(PI * jump) * 16.0) * u
				var gp := (sp + lift + Vector2(-7, 0) * u).lerp(bar_end, fly * fly)
				var cp := (sp + lift + Vector2(7, 0) * u).lerp(coin_p, fly * fly)
				_gem(gp, 5.5 * u)
				_coin(cp, 4.5 * u, 1.0)
	# le ronin : ruée à travers la vague, puis il passe le torii
	var rp := rx0.lerp(rx1, dash)
	var ra := fade * _k(t, 0.0, 0.2)
	if t >= 3.5:
		rp = rx1.lerp(gate, _k(t, 3.5, 0.6))
		ra *= 1.0 - _k(t, 3.85, 0.3)
	_ronin(rp, u, 1.0, dash > 0.0 and dash < 1.0, ra)
	# niveau supérieur : un rouleau de pouvoir (rareté différente à chaque tour)
	if t >= 1.85 and t < 3.5:
		_scroll_card(_at(0.4, 0.43), 0.95 * u, rar, UiKit.ease_out(_k(t, 1.85, 0.35)), 1.0 - _k(t, 3.2, 0.3))


## 7. Le chemin des 8 étapes : sanctuaires, mini-boss, et le gardien qui attend au bout.
func _page_gardien(t0: float) -> void:
	var u := _u
	var lp := 4.4
	var t := fmod(t0, lp)
	var fade := 1.0 - _k(t, 4.0, 0.4)
	var nodes := PackedVector2Array()
	for i in 8:
		var f := float(i) / 7.0
		nodes.append(_at(lerpf(0.07, 0.64, f), lerpf(0.26, 0.86, f) + 0.06 * sin(float(i) * 1.9)))
	var walk := _k(t, 0.2, 2.8)
	var rage := _k(t, 3.0, 0.3) * fade
	_boss(_at(0.83, 0.97), 0.95 * u, rage)
	UiKit.text(self, _ui, "GARDIEN", _at(0.83, 0.97) + Vector2(0, -136) * u, int(9 * u), _c(Toon.VERMILION, 0.6 + 0.4 * rage))
	# le chemin, encré jusqu'au ronin
	draw_polyline(nodes, _c(Toon.SUMI, 0.22), 2.0 * u, true)
	if walk > 0.0:
		_stroke(nodes, 0.0, walk, 3.5 * u, _c(Toon.SUMI, 0.85))
	# sanctuaires facultatifs (au bout des étapes 2 et 5), un peu à l'écart
	for si in [1, 4]:
		var n0: Vector2 = nodes[si]
		var n1: Vector2 = nodes[si + 1]
		var mid := n0.lerp(n1, 0.5)
		var sp := mid + Vector2(16, -16) * u
		draw_line(mid, sp, _c(Toon.SUMI, 0.35), 1.5 * u, true)
		_shrine(sp, u, walk * 7.0 >= float(si) + 0.5)
		if si == 1:
			UiKit.text(self, _ui, "SANCTUAIRE", sp + Vector2(10, -20) * u, int(9 * u), _c(Toon.SUMI, 0.6))
	for i in 8:
		var c: Vector2 = nodes[i]
		var reached := walk * 7.0 >= float(i) - 0.01
		if i == 3:
			# mini-boss (son arène, étape 4) : cornes et étiquette en dessous à gauche
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -4) * u, c + Vector2(-3, -6) * u, c + Vector2(-8, -12) * u]), _c(Toon.SUMI))
			draw_colored_polygon(PackedVector2Array([c + Vector2(6, -4) * u, c + Vector2(3, -6) * u, c + Vector2(8, -12) * u]), _c(Toon.SUMI))
			draw_circle(c, 7.0 * u, _c(Toon.VERMILION, 1.0 if reached else 0.5))
			draw_arc(c, 7.0 * u, 0, TAU, 20, _c(Toon.SUMI), 1.5 * u, true)
			var lw := _ui.get_string_size("MINI-BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u)).x
			draw_string(_ui, c + Vector2(-12.0 * u - lw, 22.0 * u), "MINI-BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), _c(Toon.SUMI, 0.6))
		elif i == 7:
			draw_circle(c, 8.0 * u, _c(Toon.SUMI, 1.0 if reached else 0.45))
			draw_arc(c, 8.0 * u, 0, TAU, 20, _c(Toon.VERMILION), 2.0 * u, true)
		elif reached:
			draw_circle(c, 4.0 * u, _c(Toon.SUMI))
		else:
			draw_circle(c, 4.0 * u, _c(Toon.WASHI))
			draw_arc(c, 4.0 * u, 0, TAU, 14, _c(Toon.SUMI, 0.45), 1.5 * u, true)
	var first: Vector2 = nodes[0]
	var last: Vector2 = nodes[7]
	UiKit.text(self, _ui, "1", first + Vector2(0, -10) * u, int(9 * u), _c(Toon.SUMI, 0.6))
	UiKit.text(self, _ui, "8", last + Vector2(0, 21) * u, int(10 * u), _c(Toon.VERMILION))
	# le ronin en route
	_ronin(_pt_at(nodes, walk) + Vector2(0, 3) * u, 0.55 * u, 1.0, false, fade * _k(t, 0.0, 0.2))
	# le gardien s'éveille
	if rage > 0.0:
		var hc := _at(0.83, 0.97) + Vector2(0, -86) * 0.95 * u
		for j in 2:
			var rk := fmod(t * 1.2 + j * 0.5, 1.0)
			draw_arc(hc, (30.0 + 40.0 * rk) * u, 0, TAU, 32, _c(Toon.VERMILION, 0.5 * (1.0 - rk) * rage), 2.0 * u, true)


# ------------------------------------------------------------------ petits dessins

## Petit ronin à l'encre, pieds en p ; s = pixels par unité (36 unités de haut), face = 1 (droite) ou -1.
## slash : sabre tendu vers l'avant (pendant la ruée).
func _ronin(p: Vector2, s: float, face: float, slash: bool, k: float) -> void:
	if k <= 0.01:
		return
	var xf := Transform2D(Vector2(face * s, 0.0), Vector2(0.0, -s), p)
	_ellipse(p + Vector2(0, 1.5 * s), 11.0 * s, 3.0 * s, _c(Toon.SUMI, 0.18 * k))
	# sabre
	var h0 := xf * Vector2(5, 18)
	var h1: Vector2 = xf * (Vector2(25, 16) if slash else Vector2(14, 34))
	draw_line(h0, h1, _c(Toon.SUMI, k), 3.4 * s, true)
	draw_line(h0.lerp(h1, 0.25), h1, _c(Toon.FOAM, k), 1.4 * s, true)
	# hakama, kimono, ceinture
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(6, 14), Vector2(-6, 14)]), _c(Toon.SUMI, k))
	var torso := xf * PackedVector2Array([Vector2(-7, 13), Vector2(7, 13), Vector2(6, 25), Vector2(-6, 25)])
	draw_colored_polygon(torso, _c(Toon.WASHI, k))
	_outline(torso, _c(Toon.SUMI, k), 1.5 * s)
	draw_line(xf * Vector2(-7, 15.5), xf * Vector2(7, 15.5), _c(Toon.VERMILION, k), 3.0 * s)
	draw_line(xf * Vector2(1, 22), h0, _c(Toon.SUMI, k), 2.6 * s, true)
	# tête, cheveux, chignon, bandeau qui flotte
	var hc := xf * Vector2(0, 30)
	draw_circle(hc, 6.3 * s, _c(Toon.SUMI, k))
	draw_circle(hc, 5.0 * s, _c(Toon.SKIN, k))
	draw_arc(hc, 4.2 * s, PI * 1.05, PI * 1.95, 10, _c(Toon.SUMI, k), 2.6 * s, true)
	draw_circle(xf * Vector2(-3, 37), 2.4 * s, _c(Toon.SUMI, k))
	draw_line(xf * Vector2(-5, 31.5), xf * Vector2(-13, 30.0 + 2.5 * sin(_now * 9.0)), _c(Toon.VERMILION, k), 1.8 * s, true)
	draw_circle(xf * Vector2(2.6, 30), 0.9 * s, _c(Toon.SUMI, k))


## Squelette (os clairs cerclés d'encre), pieds en p. cut ∈ [0, 1] : tranché, le haut s'envole, le bas s'affaisse.
func _skeleton(p: Vector2, s: float, cut: float, k: float) -> void:
	var fade := k
	var up := Vector2.ZERO
	var down := Vector2.ZERO
	if cut >= 0.0:
		fade = k * (1.0 - _k(cut, 0.35, 0.65))
		up = Vector2(10, -12) * s * UiKit.ease_out(cut)
		down = Vector2(-2, 3) * s * cut
	if fade <= 0.01:
		return
	var sway := sin(_now * 3.0 + p.x * 0.05) * 0.8 * s
	var xb := Transform2D(Vector2(s, 0.0), Vector2(0.0, -s), p + down)
	var xt := Transform2D(Vector2(s, 0.0), Vector2(0.0, -s), p + up + Vector2(sway, 0))
	_ellipse(p + Vector2(0, 1.5 * s), 9.0 * s, 2.6 * s, _c(Toon.SUMI, 0.16 * fade))
	# bas : jambes, bassin, bas de la colonne
	_bone(xb * Vector2(-4, 0), xb * Vector2(-1.5, 8), s, fade)
	_bone(xb * Vector2(4, 0), xb * Vector2(1.5, 8), s, fade)
	_bone(xb * Vector2(-3.5, 8), xb * Vector2(3.5, 8), s, fade)
	_bone(xb * Vector2(0, 8), xb * Vector2(0, 12.5), s, fade)
	# haut : colonne, côtes, bras, crâne
	_bone(xt * Vector2(0, 12.5), xt * Vector2(0, 19), s, fade)
	_bone(xt * Vector2(-4, 17), xt * Vector2(4, 17), s, fade)
	_bone(xt * Vector2(-3.5, 14.5), xt * Vector2(3.5, 14.5), s, fade)
	_bone(xt * Vector2(-4.5, 18.5), xt * Vector2(-8, 11), s, fade)
	_bone(xt * Vector2(4.5, 18.5), xt * Vector2(8, 11), s, fade)
	var hc := xt * Vector2(0, 24.5)
	draw_circle(hc, 6.2 * s, _c(Toon.SUMI, fade))
	draw_circle(hc, 5.0 * s, _c(Toon.WASHI, fade))
	draw_circle(hc + Vector2(-2.0, 0.5) * s, 1.4 * s, _c(Toon.SUMI, fade))
	draw_circle(hc + Vector2(2.0, 0.5) * s, 1.4 * s, _c(Toon.SUMI, fade))
	draw_line(hc + Vector2(-2.0, 3.5) * s, hc + Vector2(2.0, 3.5) * s, _c(Toon.SUMI, fade), 1.0 * s)


func _bone(a: Vector2, b: Vector2, s: float, k: float) -> void:
	draw_line(a, b, _c(Toon.SUMI, k), 3.4 * s, true)
	draw_line(a, b, _c(Toon.WASHI, k), 1.6 * s, true)


## Éclat de la coupe : trait vermillon et gouttes d'encre.
func _slash_fx(c: Vector2, k: float) -> void:
	if k >= 1.0:
		return
	var u := _u
	var a := 1.0 - k
	var d := Vector2(18, -9) * u * (0.6 + 0.6 * UiKit.ease_out(k * 2.0))
	draw_line(c - d, c + d, _c(Toon.VERMILION, a), 4.0 * u * a + 0.5, true)
	draw_line(c - d * 0.8, c + d * 0.8, _c(Toon.WASHI, a), 1.4 * u, true)
	for j in 4:
		draw_circle(c + Vector2.from_angle(j * 1.7 + 0.4) * 14.0 * u * k, 2.2 * u * a, _c(Toon.SUMI, a))


## Doigt qui trace (bout en tip), venu du bas à droite.
func _finger(tip: Vector2, s: float, k: float) -> void:
	if k <= 0.01:
		return
	var base := tip + Vector2(20, 46) * s
	draw_line(tip, base, _c(Toon.SUMI, k), 15.0 * s, true)
	draw_circle(tip, 7.5 * s, _c(Toon.SUMI, k))
	draw_line(tip, base, _c(Toon.SKIN, k), 12.0 * s, true)
	draw_circle(tip, 6.0 * s, _c(Toon.SKIN, k))
	draw_circle(tip + Vector2(2.2, 5.0) * s, 3.2 * s, _c(Color("#FBEBDD"), k))
	draw_arc(tip, 11.0 * s + 3.0 * s * sin(_now * 8.0), 0, TAU, 20, _c(Toon.VERMILION, 0.45 * k), 1.5 * s, true)


## Trait de pinceau qui s'affine vers la fin, tracé entre les fractions f0 et f1 du chemin.
func _stroke(pts: PackedVector2Array, f0: float, f1: float, wdt: float, col: Color) -> void:
	if pts.size() < 2 or f1 <= f0:
		return
	var cuts := [0.0, 0.4, 0.75, 1.0]
	for c in 3:
		var a0 := maxf(f0, float(cuts[c]))
		var a1 := minf(f1, float(cuts[c + 1]))
		if a1 > a0:
			draw_polyline(_sub(pts, a0, a1), col, wdt * (1.0 - 0.25 * c), true)
	if f0 <= 0.0:
		draw_circle(pts[0], wdt * 0.55, col)


## Portion d'une polyligne entre deux fractions de sa longueur (en nombre de points).
func _sub(pts: PackedVector2Array, a0: float, a1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size() - 1
	var x1 := clampf(a1, 0.0, 1.0) * n
	out.append(_pt_at(pts, a0))
	var i := int(floor(clampf(a0, 0.0, 1.0) * n)) + 1
	while float(i) < x1:
		out.append(pts[i])
		i += 1
	out.append(_pt_at(pts, a1))
	return out


func _pt_at(pts: PackedVector2Array, f: float) -> Vector2:
	var n := pts.size() - 1
	if n < 1:
		return pts[0] if n == 0 else Vector2.ZERO
	var x := clampf(f, 0.0, 1.0) * n
	var i := mini(int(x), n - 1)
	return pts[i].lerp(pts[i + 1], x - i)


func _bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


func _bez_pts(a: Vector2, c: Vector2, b: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		out.append(_bez(a, c, b, float(i) / n))
	return out


## Barre au pinceau (comme la jauge du HUD).
func _bar(pos: Vector2, wd: float, h: float, fill: float, col: Color) -> void:
	if fill <= 0.001:
		return
	var fw := wd * clampf(fill, 0.0, 1.0)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 17:
		var x := pos.x + fw * i / 16.0
		var th := h * (0.78 + 0.22 * sin(i * 1.9)) / 2.0
		top.append(Vector2(x, pos.y + h / 2.0 - th))
		bot.append(Vector2(x, pos.y + h / 2.0 + th))
	bot.reverse()
	top.append_array(bot)
	draw_colored_polygon(top, col)


func _drop(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(0, r * 0.35), r, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.92, r * 0.2), c + Vector2(0, -r * 1.6), c + Vector2(r * 0.92, r * 0.2)]), col)


func _gem(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, 0), c + Vector2(0, r), c + Vector2(-r * 0.75, 0)])
	draw_colored_polygon(pts, _c(JADE))
	_outline(pts, _c(Toon.SUMI), 1.2 * _u)


func _coin(c: Vector2, r: float, k: float) -> void:
	draw_circle(c, r, _c(Toon.GOLD, k))
	draw_circle(c, r * 0.55, _c(Color("#8C6A2A"), k))


func _torii(base: Vector2, s: float, open_k: float, k: float) -> void:
	var inner := Rect2(base + Vector2(-13, -38) * s, Vector2(26, 38) * s)
	if open_k > 0.0:
		draw_rect(inner, _c(Toon.GOLD, 0.6 * open_k * k))
		var o := base + Vector2(0, -19) * s
		for j in 5:
			var ang := -PI / 2.0 + (j - 2) * 0.35
			draw_line(o, o + Vector2.from_angle(ang) * (40.0 + 10.0 * sin(_now * 3.0 + j)) * s * open_k, _c(Toon.GOLD, 0.35 * open_k * k), 3.0 * s, true)
	else:
		draw_rect(inner, _c(Toon.SUMI, 0.1 * k))
	draw_rect(Rect2(base + Vector2(-19, -46) * s, Vector2(6, 46) * s), _c(Toon.VERMILION, k))
	draw_rect(Rect2(base + Vector2(13, -46) * s, Vector2(6, 46) * s), _c(Toon.VERMILION, k))
	draw_rect(Rect2(base + Vector2(-25, -38) * s, Vector2(50, 4.5) * s), _c(Toon.VERMILION, k))
	draw_rect(Rect2(base + Vector2(-2, -46) * s, Vector2(4, 8) * s), _c(Toon.VERMILION, k))
	draw_rect(Rect2(base + Vector2(-28, -48) * s, Vector2(56, 3) * s), _c(Toon.VERMILION, k))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-34, -56) * s, base + Vector2(34, -56) * s, base + Vector2(29, -48) * s, base + Vector2(-29, -48) * s]), _c(Toon.SUMI, k))


func _shrine(p: Vector2, s: float, lit: bool) -> void:
	if lit:
		draw_circle(p + Vector2(0, -7) * s, 11.0 * s, _c(Toon.GOLD, 0.3))
	draw_rect(Rect2(p + Vector2(-5, -9) * s, Vector2(10, 9) * s), _c(Toon.VERMILION, 1.0 if lit else 0.6))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -9) * s, p + Vector2(8, -9) * s, p + Vector2(0, -15) * s]), _c(Toon.SUMI))


## Le gardien : grand oni d'encre aux yeux de braise ; rage ∈ [0, 1] quand le ronin arrive.
func _boss(c: Vector2, s: float, rage: float) -> void:
	var br := 1.0 + 0.03 * sin(_now * 2.2)
	var xf := Transform2D(Vector2(s * br, 0.0), Vector2(0.0, s * br), c)
	for j in 4:
		draw_circle(xf * Vector2(-40.0 + 27.0 * j, -20.0 + 6.0 * sin(_now * 1.3 + j)), 26.0 * s, _c(Toon.SUMI, 0.08))
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-62, 0), Vector2(-50, -46), Vector2(-24, -64), Vector2(24, -64), Vector2(50, -46), Vector2(62, 0)]), _c(Toon.SUMI, 0.95))
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-16, -98), Vector2(-6, -106), Vector2(-26, -130)]), _c(Toon.SUMI))
	draw_colored_polygon(xf * PackedVector2Array([Vector2(16, -98), Vector2(6, -106), Vector2(26, -130)]), _c(Toon.SUMI))
	draw_circle(xf * Vector2(0, -86), 25.0 * s, _c(Toon.SUMI))
	var eg := clampf(0.55 + 0.4 * rage + 0.12 * sin(_now * 5.0), 0.0, 1.0)
	for sx in [-1.0, 1.0]:
		var e := xf * Vector2(9.0 * sx, -88.0)
		draw_circle(e, (7.0 + 5.0 * rage) * s, _c(Toon.VERMILION, 0.25 * eg))
		draw_circle(e, 3.6 * s, _c(Toon.VERMILION, eg))
		draw_colored_polygon(PackedVector2Array([xf * Vector2(8.0 * sx, -70.0), xf * Vector2(4.0 * sx, -70.0), xf * Vector2(6.0 * sx, -63.0)]), _c(Toon.WASHI))
	# ceinture de perles vermillon
	for j in 5:
		draw_circle(xf * Vector2(-24.0 + 12.0 * j, -52.0 + 4.0 * absf(j - 2.0)), 3.2 * s, _c(Toon.VERMILION, 0.8))


## Rouleau de pouvoir (rareté rar), qui surgit (kin) puis s'efface (kout).
func _scroll_card(c: Vector2, s: float, rar: int, kin: float, kout: float) -> void:
	var al := kin * kout
	if al <= 0.01:
		return
	var rc: Color = RARITY_COLS[rar]
	var leg := rar == RARITY_COLS.size() - 1
	var nr := 10 if leg else 6
	for j in nr:
		var ang := _now * 0.6 + TAU * j / nr
		var r0 := 44.0 * s
		var r1 := (72.0 + 6.0 * sin(_now * 3.0 + j)) * s
		draw_line(c + Vector2.from_angle(ang) * r0, c + Vector2.from_angle(ang) * r1, _c(rc, 0.5 * al), 3.0 * s, true)
	var sc := 0.6 + 0.4 * kin
	draw_set_transform(c, sin(_now * 2.0) * 0.04, Vector2(sc, sc))
	var r := Rect2(Vector2(-44, -56) * s, Vector2(88, 112) * s)
	draw_rect(Rect2(r.position + Vector2(-4, -4) * s, Vector2(r.size.x + 8.0 * s, 5.0 * s)), _c(Toon.SUMI, al))
	draw_rect(Rect2(Vector2(r.position.x - 4.0 * s, r.end.y - 1.0 * s), Vector2(r.size.x + 8.0 * s, 5.0 * s)), _c(Toon.SUMI, al))
	draw_style_box(UiKit.box(_sb, _c(LEG_BODY if leg else Toon.PAPER, al), int(6 * s), _c(rc, al), int(maxf(1.0, 3.0 * s))), r)
	var band := Rect2(r.position + Vector2(8, 8) * s, Vector2(72, 46) * s)
	draw_style_box(UiKit.box(_sb, _c(CARD_COLS[rar], al), int(5 * s)), band)
	UiKit.text(self, UiKit.TITLE_FONT, String(CARD_KANJI[rar]), band.get_center() + Vector2(0, 11) * s, int(30 * s), _c(Toon.WASHI, al))
	var ink: Color = Toon.WASHI if leg else Toon.SUMI
	for j in 2:
		var ly := (16.0 + 10.0 * j) * s
		draw_line(Vector2(-30.0 * s, ly), Vector2((30.0 - 16.0 * j) * s, ly), _c(ink, 0.3 * al), 3.0 * s, true)
	UiKit.text(self, _ui, String(RARITY_NAMES[rar]), Vector2(0, 47.0 * s), int(9 * s), _c(rc, al))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Symbole d'une figure au pinceau dans un sceau rond (comme la rangée du HUD).
func _symbol(shape: String, c: Vector2, r: float, a: float) -> void:
	draw_circle(c, r + 2.5 * r / 30.0, _c(Toon.SUMI, 0.85 * a))
	draw_circle(c, r, _c(Toon.PAPER, 0.95 * a))
	var ink := _c(Toon.SUMI, a)
	var w := 4.0 * r / 30.0
	var s := r * 0.62
	match shape:
		"loop":
			var pts := PackedVector2Array()
			for i in 40:
				var t := float(i) / 39.0
				pts.append(c + Vector2.from_angle(t * TAU * 1.75) * s * (0.15 + 0.85 * t))
			draw_polyline(pts, ink, w, true)
		"zigzag":
			draw_polyline(PackedVector2Array([c + Vector2(-0.6, -0.9) * s, c + Vector2(0.25, -0.15) * s, c + Vector2(-0.25, 0.1) * s, c + Vector2(0.6, 0.9) * s]), _c(Toon.GOLD.darkened(0.2), a), w * 1.2, true)
		"straight":
			draw_line(c + Vector2(-0.95, 0.55) * s, c + Vector2(0.95, -0.55) * s, ink, w * 1.3, true)
			draw_line(c + Vector2(-0.6, 0.55) * s, c + Vector2(0.95, -0.35) * s, _c(Toon.VERMILION, a * 0.8), w * 0.5, true)
		_:
			draw_arc(c, s * 0.85, -PI * 0.35, PI * 1.5, 32, ink, w * 1.5, true)
			draw_circle(c + Vector2.from_angle(-PI * 0.35) * s * 0.85, w * 0.9, ink)


## Gestes de démonstration (mêmes tracés que le tutoriel), en coordonnées 0..1.
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
		_:
			for i in 41:
				var ang := PI / 2.0 + TAU * 0.92 * i / 40.0
				p.append(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * 0.4)
	return p


# ------------------------------------------------------------------ outils

## Couleur multipliée par l'opacité de la planche en cours.
func _c(col: Color, k := 1.0) -> Color:
	return Color(col.r, col.g, col.b, col.a * k * _a)


## Point du cadre de l'illustration, en fractions de sa taille.
func _at(x: float, y: float) -> Vector2:
	return _r.position + Vector2(x, y) * _r.size


## Avancement 0..1 d'une étape qui commence à t0 et dure dur.
func _k(t: float, t0: float, dur: float) -> float:
	return clampf((t - t0) / dur, 0.0, 1.0)


func _ellipse_pts(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var ang := TAU * float(i) / float(n)
		p.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return p


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx < 0.5 or ry < 0.5 or col.a <= 0.003:
		return
	draw_colored_polygon(_ellipse_pts(c, rx, ry, 28), col)


func _ellipse_line(c: Vector2, rx: float, ry: float, col: Color, wdt: float) -> void:
	if col.a <= 0.003:
		return
	_outline(_ellipse_pts(c, rx, ry, 32), col, wdt)


func _outline(pts: PackedVector2Array, col: Color, wdt: float) -> void:
	var q := pts.duplicate()
	q.append(pts[0])
	draw_polyline(q, col, wdt, true)
