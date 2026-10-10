extends Control
## Intro : six planches animées qui présentent le jeu (premier JOUER, ou bouton « ? » de l'accueil).
## Glisser à gauche / à droite, ou toucher, pour tourner les planches.
## main appelle open(replay) ; l'intro émet finished(action) : "done" (fin ou PASSER au premier lancement),
## "tuto" (lancer le tutoriel, depuis le « ? ») ou "back" (retour à l'accueil).

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const InkStroke = preload("res://scripts/ink_stroke.gd")

signal finished(action: String)

const PAGES := [
	{"kanji": "一", "title": "Trace un trait",
		"text": "Glisse ton doigt : le ronin suit ton trait et tranche tout ce qu'il touche."},
	{"kanji": "墨", "title": "L'encre",
		"text": "Chaque trait use de l'encre. Elle revient quand tu ne traces pas."},
	{"kanji": "円", "title": "Les figures",
		"text": "Dessine une forme (boucle, zigzag, cercle…) : ton coup devient plus fort. Trouve son rouleau pour débloquer sa technique."},
	{"kanji": "風", "title": "Esquive en traçant",
		"text": "Un ennemi va frapper ? Trace un trait : la ruée te rend intouchable au départ, le coup tombe dans le vide."},
	{"kanji": "道", "title": "Progresse",
		"text": "Tue des yokai pour monter de niveau et choisis un pouvoir sur un rouleau."},
	{"kanji": "鬼", "title": "8 étapes, un gardien",
		"text": "Chaque monde compte 8 étapes. Un mini-boss à la 4e, le gardien t'attend à la 8e. Bonne route !"},
]
const INPUT_DELAY := 0.3  # le toucher qui a ouvert l'intro (ou tourné la planche) ne compte pas
const TRANS := 0.35  # durée du fondu entre deux planches
const GLUE := [":", ";", "!", "?", "%", "=", "…"]  # jamais en début de ligne
const JADE := Color("#3FD1B2")
# figures, dans l'ordre de la planche 3 (couleurs d'encre : ink_stroke.gd FIG_INK)
const FIGS := ["loop", "zigzag", "straight", "return", "enso", "hook"]
const FIG_KANJI := {"loop": "渦", "zigzag": "雷", "straight": "一", "return": "返", "enso": "円", "hook": "鉤"}
# technique débloquée par le rouleau de chaque figure (powers.gd FIG_NAMES, en clair)
const FIG_TECH := {"loop": "TOUPIE", "zigzag": "ÉCLAIR EN CHAÎNE", "straight": "COUPE IAÏ", "return": "GARDE",
	"enso": "FRAPPE AU SOL", "hook": "ESTOC"}
# le Ronin de papier (même allure que le héros 3D, ninja_rig.gd RONIN_PAL) : chapeau de paille, chevelure
# d'encre, kimono washi, hakama bleu de Prusse aux vagues claires, obi d'encre, écharpe vermillon
const STRAW := Color("#CDAB6B")
const HAIR := Color("#1E1B22")
const KIMONO := Color("#F4EAD6")
const HAKAMA := Color("#1F3A5C")
const WAVE := Color("#6F9BC8")
const HEM := Color("#2A2733")
const ONI := Color("#C2453A")  # peau du petit oni
const GAUGE_INK := Color("#7B7B83")  # encre par défaut de la jauge du HUD (sumi éclaircie, hud.gd)
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
	var body := UiKit.plain(String(pg.text))
	var lines := _wrap(UiKit.UI_FONT, body, fs, card.size.x - 48.0 * u)
	while lines.size() > 4 and fs > 10:
		fs -= 1  # jamais plus de 4 lignes : le texte rapetisse plutôt que d'être coupé
		lines = _wrap(UiKit.UI_FONT, body, fs, card.size.x - 48.0 * u)
	for j in mini(lines.size(), 4):
		UiKit.text(self, UiKit.UI_FONT, lines[j], Vector2(cx, ty + 40.0 * u + j * 21.0 * u), fs, Color(Toon.SUMI, 0.8 * alpha))


## Coupe un texte en lignes qui tiennent dans `width` (mots entiers ; la ponctuation reste collée au mot).
func _wrap(font: Font, txt: String, fs: int, width: float) -> PackedStringArray:
	return UiKit.wrap(font, txt, fs, width, GLUE)


# ------------------------------------------------------------------ planches
# Chaque planche joue en boucle une petite scène avec le ronin, qui montre une seule mécanique.
# Les boucles commencent et finissent dans un fondu : le raccord ne se voit pas.

## 1. Un doigt trace un trait au sol ; le ronin fonce le long et tranche les deux oni qu'il croise.
func _page_trait(t0: float) -> void:
	var u := _u
	var lp := 3.8
	var t := fmod(t0, lp)
	var fade := _k(t, 0.0, 0.25) * (1.0 - _k(t, lp - 0.4, 0.4))
	var path := _bez_pts(_at(0.12, 0.84), _at(0.4, 0.08), _at(0.88, 0.7), 40)
	var drawn := _k(t, 0.3, 1.0)
	var dash := _k(t, 1.45, 0.6)
	if drawn > 0.0:
		_stroke(path, 0.0, drawn, 7.0 * u, _c(Toon.SUMI, 0.85 * fade))
	# deux oni sur le chemin
	var kills := 0
	for j in 2:
		var hp := 0.42 if j == 0 else 0.76
		var sp := _pt_at(path, hp)
		var t_hit := 1.45 + 0.6 * hp
		var hit := -1.0
		if t >= t_hit:
			hit = t - t_hit
			kills += 1
		_oni(sp, u, -1.0, fade, 0.0, hit)
		if hit >= 0.0:
			_slash_fx(sp - Vector2(0, 12) * u, _k(hit, 0.0, 0.4))
			_puff(sp - Vector2(0, 10) * u, _k(hit, 0.12, 0.6))
	# le ronin attend au départ du trait, puis le suit
	var rp := _pt_at(path, dash)
	var dashing := dash > 0.0 and dash < 1.0
	if dashing:
		_speed_lines(rp, _dir_at(path, dash), u, fade)
	_ronin(rp, u, 1.0, 1 if dashing else 0, fade)
	if t < 1.5:
		_finger(_pt_at(path, drawn), u, _k(t, 0.15, 0.15) * (1.0 - _k(t, 1.3, 0.2)) * fade)
	if kills >= 2:
		var pk := UiKit.ease_out(_k(t, 1.45 + 0.6 * 0.76, 0.25))
		UiKit.text(self, UiKit.TITLE_FONT, "×2", rp + Vector2(0, -54) * u, int((18.0 + 10.0 * (1.0 - pk)) * u), _c(Toon.VERMILION, pk * fade))


## 2. Tracer vide la jauge d'encre (même pilule que le HUD) ; quand le doigt se repose, elle remonte.
func _page_encre(t0: float) -> void:
	var u := _u
	var lp := 5.4
	var t := fmod(t0, lp)
	var fade := _k(t, 0.0, 0.25) * (1.0 - _k(t, lp - 0.4, 0.4))
	var path := PackedVector2Array()
	for i in 41:
		var f := float(i) / 40.0
		path.append(_at(lerpf(0.08, 0.66, f), 0.7 + 0.1 * sin(f * TAU * 1.25)))
	var drawn := _k(t, 0.3, 1.6)
	var dash := _k(t, 2.05, 0.6)
	var rest := t >= 2.7
	var ink := 1.0 - 0.75 * drawn
	if rest:
		ink = lerpf(0.25, 1.0, smoothstep(2.8, 4.4, t))
	# le trait sèche pendant que l'encre revient
	var dry := _k(t, 2.8, 1.2)
	if drawn > 0.0:
		_stroke(path, 0.0, drawn, 7.0 * u, _c(Toon.SUMI.lerp(InkStroke.DRY, dry), 0.85 * (1.0 - 0.75 * dry) * fade))
	var rp := _pt_at(path, dash)
	var dashing := dash > 0.0 and dash < 1.0
	if dashing:
		_speed_lines(rp, _dir_at(path, dash), u, fade)
	_ronin(rp, u, 1.0, 1 if dashing else 0, fade)
	if t < 2.1:
		_finger(_pt_at(path, drawn), u, _k(t, 0.15, 0.15) * (1.0 - _k(t, 1.9, 0.2)) * fade)
	# la jauge, comme en jeu : pilule verticale, goutte dessous ; vermillon quand il en reste peu
	var gw := 16.0 * u
	var gr := Rect2(Vector2(_at(0.87, 0.0).x - gw / 2.0, _at(0.0, 0.1).y), Vector2(gw, _r.size.y * 0.6))
	var col := GAUGE_INK
	if ink < 0.3:
		col = Toon.VERMILION
	_ink_gauge(gr, ink, col, fade)
	if rest and ink >= 0.999:
		draw_circle(Vector2(gr.get_center().x, gr.position.y), 3.5 * u + 1.5 * u * sin(t * 6.0), _c(Toon.GOLD, fade))
	# flèche à côté du niveau : elle descend quand on trace, remonte au repos
	var going := t > 0.3 and t < 1.9
	if going or (rest and ink < 0.999):
		var sgn := 1.0 if going else -1.0  # 1 : vers le bas
		var ay := gr.end.y - gr.size.y * ink
		var tipp := Vector2(gr.position.x - 14.0 * u, ay + sgn * (6.0 + 3.0 * sin(t * 10.0)) * u)
		var acol: Color = Toon.VERMILION if going else JADE.darkened(0.3)
		draw_colored_polygon(PackedVector2Array([tipp, tipp + Vector2(-5.0, -sgn * 7.0) * u, tipp + Vector2(5.0, -sgn * 7.0) * u]), _c(acol, fade))
	var cap := "TU TRACES : L'ENCRE BAISSE"
	if rest:
		cap = "TU ATTENDS : ELLE REVIENT"
	UiKit.text(self, _ui, UiKit.plain(cap), _at(0.4, 0.95), int(11 * u), _c(Toon.SUMI, 0.75 * fade))


## 3. Les six figures tour à tour : le doigt trace, l'encre prend la couleur de la figure, le ronin la suit,
## puis part la technique que débloque son rouleau. La figure (kanji et tracé) est montrée en grand, en fond.
func _page_figures(t0: float) -> void:
	var u := _u
	var cyc := 2.6
	var fi := int(t0 / cyc) % FIGS.size()
	var t := fmod(t0, cyc)
	var kind := String(FIGS[fi])
	var fc: Color = InkStroke.FIG_INK[kind]
	var dark := fc.darkened(0.2)  # plus lisible sur le papier
	var fade := _k(t, 0.0, 0.2) * (1.0 - _k(t, cyc - 0.3, 0.3))
	var box := Rect2(_at(0.3, 0.25), _r.size * Vector2(0.4, 0.48))
	var raw := UiKit.gesture_points(kind)
	var pts := PackedVector2Array()
	for i in raw.size():
		pts.append(box.position + raw[i] * box.size)
	var center := box.get_center()
	# en fond : le kanji de la figure et le tracé à suivre (départ marqué d'un point)
	UiKit.text(self, UiKit.TITLE_FONT, String(FIG_KANJI[kind]), center + Vector2(0, 44) * u, int(128 * u), _c(fc, 0.1 * fade))
	draw_polyline(pts, _c(fc, 0.22 * fade), 3.0 * u, true)
	draw_circle(pts[0], 4.0 * u, _c(fc, 0.35 * fade))
	# le tracé : l'encre se teinte dès que la figure est reconnue
	var drawn := _k(t, 0.15, 0.8)
	var rec := 0.95
	if drawn > 0.0:
		_stroke(pts, 0.0, drawn, 6.0 * u, _c(Toon.SUMI.lerp(dark, _k(t, rec - 0.1, 0.2)), fade))
	if t >= rec and t < rec + 0.4:
		var pk := _k(t, rec, 0.4)
		draw_arc(pts[pts.size() - 1], (6.0 + 22.0 * pk) * u, 0, TAU, 24, _c(fc, (1.0 - pk) * fade), 3.0 * u, true)
	# le ronin suit la figure (ensō : il bondit ensuite au centre du cercle, d'où part l'onde)
	var s := 0.78 * u
	var dash := _k(t, 1.05, 0.55)
	var fx_t := 1.6
	var rp := _pt_at(pts, dash)
	var dir := _dir_at(pts, dash)
	var face := -1.0 if dir.x < -0.2 else 1.0
	var pose := 1 if dash > 0.0 and dash < 1.0 else 0
	var lift := 0.0
	if kind == "enso":
		fx_t = 1.9
		var hk := _k(t, 1.62, 0.28)
		if hk > 0.0:
			rp = rp.lerp(center + Vector2(0, 16) * u, UiKit.ease_out(hk))
			if hk < 1.0:
				lift = sin(PI * hk) * 34.0 * u
				pose = 2
	if pose == 1:
		_speed_lines(rp, dir, s, fade)
	if t >= fx_t:
		_fig_fx(kind, fc, pts, rp, face, center + Vector2(0, 16) * u, _k(t, fx_t, 0.6), fade, s)
	_ronin(rp, s, face, pose, fade, lift)
	if t < 1.15:
		_finger(_pt_at(pts, drawn), 0.9 * u, _k(t, 0.05, 0.12) * (1.0 - _k(t, 0.95, 0.15)) * fade)
	# le nom de la figure, en grand ; dessous, ce qu'elle apporte
	if t >= rec:
		var nk := UiKit.ease_out(_k(t, rec, 0.25))
		UiKit.text(self, UiKit.TITLE_FONT, UiKit.plain(String(UiKit.FIG_WORD[kind])), _at(0.5, 0.14), int(26.0 * u * (1.0 + 0.25 * (1.0 - nk))), _c(dark, nk * fade))
		var sub := "COUP PLUS FORT"
		if t >= fx_t:
			sub = "AVEC SON ROULEAU : " + String(FIG_TECH[kind])
		UiKit.text(self, _ui, UiKit.plain(sub), _at(0.5, 0.215), int(10 * u), _c(Toon.SUMI, 0.75 * nk * fade))
	# la rangée des six figures : celle du moment s'allume
	for j in FIGS.size():
		var c := _at(0.115 + 0.154 * j, 0.885)
		var sh := String(FIGS[j])
		var rr := 13.0 * u
		var al := 0.4
		if j == fi:
			al = 1.0
			rr *= 1.12
			var ic: Color = InkStroke.FIG_INK[sh]
			draw_arc(c, rr + 4.0 * u, 0, TAU, 28, _c(ic, fade), 2.5 * u, true)
		_symbol(sh, c, rr, al)


## 4. Un oni lève sa massue, une zone rouge annonce le coup ; le doigt trace un trait depuis le ronin, qui file
## hors de la zone en ruée (intouchable au départ), et le coup tombe dans le vide. Plus d'esquive au tap.
func _page_esquive(t0: float) -> void:
	var u := _u
	var lp := 3.8
	var t := fmod(t0, lp)
	var fade := _k(t, 0.0, 0.25) * (1.0 - _k(t, lp - 0.4, 0.4))
	var c0 := _at(0.42, 0.76)
	var zc := c0 + Vector2(8, 0) * u
	var rx := 64.0 * u
	var ry := 22.0 * u
	var draw_t := 0.55  # le doigt commence à tracer
	var dash_t := 1.1  # la ruée part
	var hit_t := 1.55  # le coup tombe
	# le trait de fuite : du ronin vers la gauche, en légère courbe
	var path := _bez_pts(c0, _at(0.26, 0.62), _at(0.1, 0.72), 30)
	var drawn := _k(t, draw_t, 0.5)
	var dash := _k(t, dash_t, 0.4)
	if drawn > 0.0:
		_stroke(path, 0.0, drawn, 7.0 * u, _c(Toon.SUMI, 0.85 * fade))
	# la zone rouge se remplit : le coup arrive
	var za := _k(t, 0.3, 0.2) * (1.0 - _k(t, hit_t + 0.1, 0.4)) * fade
	if za > 0.0:
		var fill := _k(t, 0.3, hit_t - 0.3)
		_ellipse(zc, rx, ry, _c(Toon.VERMILION, 0.12 * za))
		_ellipse(zc, rx * fill, ry * fill, _c(Toon.VERMILION, 0.3 * za))
		_ellipse_line(zc, rx, ry, _c(Toon.VERMILION, 0.9 * za), 2.5 * u)
	# l'oni lève sa massue, puis l'abat
	var club := _k(t, 0.3, 0.8)
	if t >= hit_t - 0.15:
		club = 1.0 + _k(t, hit_t - 0.15, 0.15)
	_oni(_at(0.72, 0.76), 1.25 * u, -1.0, fade, club)
	# le coup frappe le sol… vide
	if t >= hit_t and t < hit_t + 0.9:
		var ik := _k(t, hit_t, 0.9)
		_ellipse_line(zc, rx * (1.0 + 0.25 * ik), ry * (1.0 + 0.25 * ik), _c(Toon.SUMI, 0.6 * (1.0 - ik) * fade), 3.0 * u)
		for j in 6:
			var ang := TAU * j / 6.0 + 0.3
			var a0 := zc + Vector2(cos(ang) * 20.0, sin(ang) * 7.0) * u
			var a1 := zc + Vector2(cos(ang) * (20.0 + 50.0 * ik), sin(ang) * (7.0 + 18.0 * ik)) * u
			draw_line(a0, a1, _c(Toon.SUMI, 0.7 * (1.0 - ik) * fade), 2.0 * u, true)
	if t >= hit_t + 0.05:
		var mk := UiKit.ease_out(_k(t, hit_t + 0.05, 0.25))
		UiKit.text(self, UiKit.TITLE_FONT, UiKit.plain("RATÉ !"), zc + Vector2(0, -50) * u, int((18.0 + 8.0 * (1.0 - mk)) * u), _c(Toon.VERMILION, mk * fade))
	# la ruée le long du trait, hors de la zone (traits de vitesse, sabre tendu)
	var rp := _pt_at(path, dash)
	var dashing := dash > 0.0 and dash < 1.0
	if dashing:
		_speed_lines(rp, _dir_at(path, dash), u, fade)
	_ronin(rp, u, -1.0 if dash > 0.0 else 1.0, 1 if dashing else 0, fade)
	# le doigt trace le trait depuis le ronin
	if t < dash_t + 0.2:
		_finger(_pt_at(path, drawn), u, _k(t, draw_t - 0.15, 0.15) * (1.0 - _k(t, dash_t, 0.2)) * fade)
	if t >= dash_t and t < dash_t + 0.7:
		UiKit.text(self, _ui, UiKit.plain("TRACE !"), c0 + Vector2(40, -50) * u, int(11 * u), _c(Toon.VERMILION, (1.0 - _k(t, dash_t + 0.5, 0.2)) * fade))


## 5. Le ronin tranche trois oni ; leur XP file vers la barre, il monte de niveau,
## touche un des trois rouleaux qui s'offrent à lui, et le rouleau se déroule.
func _page_progres(t0: float) -> void:
	var u := _u
	var lp := 6.0
	var t := fmod(t0, lp)
	var rar := int(t0 / lp) % RARITY_COLS.size()
	var fade := _k(t, 0.0, 0.25) * (1.0 - _k(t, lp - 0.4, 0.4))
	var gy := _at(0.0, 0.86).y
	var x0 := _at(0.08, 0.0).x
	var x1 := _at(0.86, 0.0).x
	# niveau et barre d'XP
	var lv_t := 1.6
	var up := t >= lv_t
	var bar := Rect2(_at(0.2, 0.06), Vector2(_r.size.x * 0.7, 10.0 * u))
	var xp := 0.2 + 0.8 * _k(t, 0.75, 0.8)
	if up:
		xp = 0.04
	draw_string(UiKit.UI_FONT, Vector2(_at(0.04, 0.0).x, bar.end.y - 0.5 * u), "NIV %d" % (2 if up else 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), _c(Toon.SUMI, fade))
	draw_style_box(UiKit.box(_sb, _c(Toon.SUMI, 0.55 * fade), int(5 * u)), bar)
	draw_style_box(UiKit.box(_sb, _c(JADE, fade), int(4 * u)), Rect2(bar.position + Vector2(2, 2) * u, Vector2(maxf(8.0 * u, (bar.size.x - 4.0 * u) * xp), bar.size.y - 4.0 * u)))
	if up and t < lv_t + 0.6:
		var lk := _k(t, lv_t, 0.6)
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(8 * u), _c(JADE, 0.8 * (1.0 - lk) * fade), int(maxf(1.0, 2.0 * u))), bar.grow(6.0 * u * lk))
	# la vague : un trait au sol, la ruée, trois oni tranchés qui lâchent leur XP
	var line := PackedVector2Array()
	for i in 21:
		line.append(Vector2(lerpf(x0, x1, float(i) / 20.0), gy))
	var drawn := _k(t, 0.05, 0.25)
	var dash := _k(t, 0.35, 0.6)
	if drawn > 0.0:
		_stroke(line, 0.0, drawn, 6.0 * u, _c(Toon.SUMI, 0.8 * fade * (1.0 - 0.7 * _k(t, 1.0, 0.6))))
	var gem_to := bar.position + Vector2(bar.size.x * 0.92, bar.size.y / 2.0)
	for j in 3:
		var sp := Vector2(_at(0.36 + 0.16 * j, 0.0).x, gy)
		var hit_t := 0.35 + 0.6 * (sp.x - x0) / (x1 - x0)
		var hit := -1.0
		if t >= hit_t:
			hit = t - hit_t
		_oni(sp, 0.85 * u, -1.0, fade, 0.0, hit)
		if hit >= 0.0:
			_slash_fx(sp - Vector2(0, 10) * u, _k(hit, 0.0, 0.4))
			_puff(sp - Vector2(0, 9) * u, _k(hit, 0.12, 0.6))
			var fly := _k(hit, 0.15, 0.5)
			if fly > 0.0 and fly < 1.0:
				_gem((sp - Vector2(0, 18) * u).lerp(gem_to, fly * fly) + Vector2(0, -sin(PI * fly) * 30.0 * u), 5.5 * u)
	# le ronin : ruée, petite victoire au niveau, puis l'aura du pouvoir choisi
	var rp := Vector2(lerpf(x0, x1, dash), gy)
	var dashing := dash > 0.0 and dash < 1.0
	var pose := 1 if dashing else 0
	if up and t < lv_t + 0.8:
		pose = 3
	if dashing:
		_speed_lines(rp, Vector2.RIGHT, u, fade)
	if t >= 3.5:
		var gk := _k(t, 3.5, 0.3) * fade
		var gc := rp - Vector2(0, 18) * u
		draw_circle(gc, 26.0 * u, _c(Toon.GOLD, 0.15 * gk))
		draw_arc(gc, (26.0 + 2.0 * sin(t * 6.0)) * u, 0, TAU, 32, _c(Toon.GOLD, 0.7 * gk), 2.0 * u, true)
	_ronin(rp, u, 1.0, pose, fade)
	if up and t < lv_t + 0.9:
		var nk := UiKit.ease_out(_k(t, lv_t, 0.25))
		UiKit.text(self, UiKit.TITLE_FONT, UiKit.plain("NIVEAU 2 !"), _at(0.5, 0.36), int((22.0 + 8.0 * (1.0 - nk)) * u), _c(Toon.GOLD.darkened(0.15), nk * (1.0 - _k(t, lv_t + 0.6, 0.3)) * fade))
	# trois rouleaux s'offrent ; le doigt choisit celui du milieu, qui se déroule
	var pick_t := 2.9
	for j in 3:
		var kin := UiKit.ease_out(_k(t, 2.1 + 0.1 * j, 0.3))
		var kout := 1.0 - _k(t, pick_t + 0.05, 0.25)
		if j == 1:
			kout = 1.0 - _k(t, 3.0, 0.05)
		var sc := _at(0.26 + 0.24 * j, 0.47) + Vector2(0, sin(t * 3.0 + j) * 3.0 * u)
		var rc: Color = RARITY_COLS[(rar + j + RARITY_COLS.size() - 1) % RARITY_COLS.size()]
		_rolled(sc, u * (0.6 + 0.4 * kin), rc, kin * kout * fade)
	var mid := _at(0.5, 0.47)
	var fk := _k(t, 2.45, 0.2) * (1.0 - _k(t, pick_t + 0.15, 0.2)) * fade
	if fk > 0.0:
		var press := 1.0 - UiKit.ease_out(_k(t, 2.45, pick_t - 2.45))
		_finger(mid + Vector2(14, 22) * u * press, u, fk)
	_tap_fx(mid, _k(t, pick_t, 0.45))
	if t >= 3.0:
		_scroll_card(_at(0.5, 0.46), 0.8 * u, rar, 1.0, fade, UiKit.ease_out(_k(t, 3.0, 0.45)))


## 6. Le chemin des 8 étapes : sanctuaires, mini-boss, et le gardien qui attend au bout.
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
	_ronin(_pt_at(nodes, walk) + Vector2(0, 3) * u, 0.6 * u, 1.0, 1 if walk > 0.0 and walk < 1.0 else 0, fade * _k(t, 0.0, 0.2))
	# le gardien s'éveille
	if rage > 0.0:
		var hc := _at(0.83, 0.97) + Vector2(0, -86) * 0.95 * u
		for j in 2:
			var rk := fmod(t * 1.2 + j * 0.5, 1.0)
			draw_arc(hc, (30.0 + 40.0 * rk) * u, 0, TAU, 32, _c(Toon.VERMILION, 0.5 * (1.0 - rk) * rage), 2.0 * u, true)


# ------------------------------------------------------------------ petits dessins

## Le Ronin de papier, à l'encre (même allure que le héros 3D) : chapeau de paille conique posé en arrière,
## visage nu aux traits d'encre, queue de cheval, kimono washi aux manches amples (col et ourlet à l'encre),
## hakama bleu aux vagues seigaiha, longue écharpe vermillon qui retombe au repos et s'étire en ruée, katana.
## Pieds en p ; s = pixels par unité (environ 46 unités de haut, chapeau compris) ; face = 1 (regarde à droite)
## ou -1. pose : 0 debout, 1 ruée (sabre tendu), 2 bond, 3 victoire (sabre levé). lift : hauteur au-dessus du
## sol (pixels).
func _ronin(p: Vector2, s: float, face: float, pose: int, k: float, lift := 0.0) -> void:
	if k <= 0.01:
		return
	var lean := 0.0
	var bob := 0.0
	var back := Vector2(-4, 0)  # pied arrière
	var front := Vector2(4, 0)
	var hand := Vector2(7, 14)
	var tip := Vector2(20, 5)  # pointe du sabre
	var tail := 15.0  # longueur de l'écharpe
	var droop := 9.0  # l'écharpe retombe au repos, s'étire pendant la course
	match pose:
		1:
			lean = 0.3
			back = Vector2(-10, 3)
			front = Vector2(9, 0)
			hand = Vector2(9, 16)
			tip = Vector2(31, 18)
			tail = 30.0
			droop = -1.0
		2:
			lean = -0.12
			back = Vector2(-6, 6)
			front = Vector2(5, 4)
			hand = Vector2(4, 16)
			tip = Vector2(-12, 8)
			tail = 22.0
			droop = -6.0
		3:
			back = Vector2(-5, 0)
			front = Vector2(5, 0)
			hand = Vector2(9, 24)
			tip = Vector2(12, 46)
			bob = absf(sin(_now * 6.0)) * 1.5
		_:
			bob = 0.5 + 0.5 * sin(_now * 4.0)
	# ombre au sol (plus petite quand il est en l'air)
	var sh := 1.0 / (1.0 + lift / (40.0 * s))
	_ellipse(p + Vector2(0, 1.5 * s), 12.0 * s * sh, 3.2 * s * sh, _c(Toon.SUMI, 0.18 * k))
	var xf := Transform2D(lean * face, Vector2(face * s, -s), 0.0, p - Vector2(0, lift + bob * s))
	var ink := _c(Toon.SUMI, k)
	# écharpe : deux pans qui partent de la nuque, ondulent, retombent au repos et filent en ruée
	var w1 := sin(_now * 11.0)
	var w2 := sin(_now * 11.0 - 1.2)
	var w3 := sin(_now * 11.0 - 2.3)
	var pan := xf * PackedVector2Array([Vector2(-1, 23), Vector2(-tail * 0.33, 22.5 - droop * 0.3 + 1.2 * w1),
		Vector2(-tail * 0.66, 21.5 - droop * 0.7 + 2.0 * w2), Vector2(-tail, 20.0 - droop + 2.6 * w3)])
	draw_polyline(pan, ink, 4.4 * s, true)
	draw_polyline(pan, _c(Toon.VERMILION, k), 3.0 * s, true)
	var pan2 := xf * PackedVector2Array([Vector2(-1, 22), Vector2(-tail * 0.3, 21.0 - droop * 0.35 + 1.3 * w2),
		Vector2(-tail * 0.6, 19.5 - droop * 0.75 + 1.8 * w3), Vector2(-tail * 0.82, 17.5 - droop * 1.05 + 2.2 * w1)])
	draw_polyline(pan2, ink, 3.4 * s, true)
	draw_polyline(pan2, _c(Toon.VERMILION.darkened(0.18), k), 2.1 * s, true)
	# hakama : jambes larges, puis la jupe du haut ; vagues seigaiha claires ; zōri et tabi
	draw_line(xf * Vector2(-2.5, 9), xf * back, ink, 8.2 * s, true)
	draw_line(xf * Vector2(2.5, 9), xf * front, ink, 8.2 * s, true)
	draw_line(xf * Vector2(-2.5, 9), xf * back, _c(HAKAMA, k), 6.6 * s, true)
	draw_line(xf * Vector2(2.5, 9), xf * front, _c(HAKAMA, k), 6.6 * s, true)
	var skirt := xf * PackedVector2Array([Vector2(-8.5, 5.5), Vector2(8.5, 5.5), Vector2(7, 14), Vector2(-7, 14)])
	draw_colored_polygon(skirt, _c(HAKAMA, k))
	_outline(skirt, ink, 1.1 * s)
	for row in 3:
		var y := 7.0 + 2.6 * float(row)
		var x0 := -6.0 + (1.3 if row % 2 == 1 else 0.0)
		for i in 5:
			var cx := x0 + 2.6 * float(i)
			if absf(cx) > 6.6:
				continue
			draw_arc(xf * Vector2(cx, y), 1.2 * s, PI * (1.0 + 0.05), PI * (2.0 - 0.05), 8, _c(WAVE, 0.85 * k), 0.75 * s, true)
	draw_circle(xf * back, 2.7 * s, ink)
	draw_circle(xf * front, 2.7 * s, ink)
	draw_circle(xf * (back + Vector2(0.3, 0.8)), 1.7 * s, _c(KIMONO, k))
	draw_circle(xf * (front + Vector2(0.3, 0.8)), 1.7 * s, _c(KIMONO, k))
	# kimono washi : buste, pli, col croisé (pan gauche par-dessus, ourlet d'encre jusqu'à la hanche), juban
	var torso := xf * PackedVector2Array([Vector2(-7, 12.5), Vector2(7, 12.5), Vector2(5.8, 23), Vector2(-5.8, 23)])
	draw_colored_polygon(torso, _c(KIMONO, k))
	_outline(torso, ink, 1.2 * s)
	draw_line(xf * Vector2(-3.8, 21.5), xf * Vector2(-4.6, 14.5), _c(Toon.SUMI, 0.35 * k), 0.6 * s, true)
	draw_polyline(xf * PackedVector2Array([Vector2(-1.8, 22.8), Vector2(1.6, 18.2), Vector2(4.6, 22.8)]), _c(Color.WHITE, k), 1.3 * s, true)
	draw_polyline(xf * PackedVector2Array([Vector2(-2.4, 22.8), Vector2(1.6, 17.6), Vector2(4.4, 13.2)]), ink, 1.1 * s, true)
	draw_line(xf * Vector2(4.8, 22.6), xf * Vector2(2.4, 19.4), ink, 0.9 * s, true)
	# obi d'encre au cordon d'or
	draw_line(xf * Vector2(-6.9, 13.6), xf * Vector2(6.9, 13.6), _c(HEM, k), 2.4 * s)
	draw_line(xf * Vector2(-6.9, 13.6), xf * Vector2(6.9, 13.6), _c(Toon.GOLD, k), 0.5 * s)
	# écharpe nouée au cou
	draw_line(xf * Vector2(-5.8, 23.2), xf * Vector2(6.2, 23.2), ink, 4.6 * s, true)
	draw_line(xf * Vector2(-5.8, 23.2), xf * Vector2(6.2, 23.2), _c(Toon.VERMILION, k), 3.2 * s, true)
	# tête : chevelure d'encre, queue de cheval nouée, visage, traits (sourcils froncés, yeux fendus, nez, bouche)
	var hc := xf * Vector2(1, 30)
	draw_line(xf * Vector2(-6.5, 31.5), xf * Vector2(-12.5, 25.5), ink, 2.8 * s, true)
	draw_circle(xf * Vector2(-8.0, 30.0), 1.2 * s, _c(Color.WHITE, k))
	draw_circle(hc, 9.5 * s, ink)
	draw_circle(hc, 8.6 * s, _c(HAIR, k))
	draw_circle(xf * Vector2(2.6, 28.6), 6.9 * s, _c(Toon.SKIN, k))
	draw_line(xf * Vector2(0.2, 30.6), xf * Vector2(2.9, 29.9), ink, 0.9 * s, true)
	draw_line(xf * Vector2(4.5, 29.9), xf * Vector2(7.2, 30.6), ink, 0.9 * s, true)
	draw_line(xf * Vector2(0.8, 28.5), xf * Vector2(3.0, 28.5), ink, 1.0 * s, true)
	draw_line(xf * Vector2(4.6, 28.5), xf * Vector2(6.8, 28.5), ink, 1.0 * s, true)
	draw_line(xf * Vector2(4.0, 27.6), xf * Vector2(4.3, 26.5), _c(Toon.SUMI, 0.5 * k), 0.5 * s, true)
	draw_line(xf * Vector2(3.4, 25.3), xf * Vector2(5.2, 25.3), ink, 0.7 * s, true)
	draw_circle(xf * Vector2(1.2, 26.6), 0.9 * s, _c(Toon.VERMILION, 0.3 * k))
	draw_circle(xf * Vector2(7.0, 26.6), 0.9 * s, _c(Toon.VERMILION, 0.3 * k))
	# sandogasa : cône de paille posé en arrière, bord épais, tressage, cordon
	var hat := xf * PackedVector2Array([Vector2(-13.0, 35.0), Vector2(14.6, 35.6), Vector2(0.4, 46.0)])
	draw_colored_polygon(hat, _c(STRAW, k))
	_outline(hat, ink, 1.3 * s)
	draw_line(xf * Vector2(-9.5, 38.0), xf * Vector2(10.6, 38.4), _c(Toon.SUMI, 0.22 * k), 0.6 * s, true)
	draw_line(xf * Vector2(-6.0, 41.0), xf * Vector2(6.8, 41.3), _c(Toon.SUMI, 0.22 * k), 0.6 * s, true)
	draw_line(xf * Vector2(-13.0, 35.0), xf * Vector2(14.6, 35.6), ink, 1.8 * s, true)
	# bras : manche ample (ourlet d'encre), avant-bras nu, main ; katana (poignée, tsuba d'or, lame claire)
	var d := (tip - hand).normalized()
	var sho := Vector2(1, 20)
	var elb := sho.lerp(hand, 0.55)
	draw_line(xf * sho, xf * elb, ink, 7.0 * s, true)
	draw_line(xf * sho, xf * elb, _c(KIMONO, k), 5.4 * s, true)
	draw_circle(xf * elb, 3.5 * s, ink)
	draw_circle(xf * elb, 2.6 * s, _c(KIMONO, k))
	draw_line(xf * elb, xf * hand, ink, 3.6 * s, true)
	draw_line(xf * elb, xf * hand, _c(Toon.SKIN, k), 2.2 * s, true)
	draw_line(xf * (hand - d * 5.0), xf * (hand + d * 1.0), ink, 2.6 * s, true)
	draw_line(xf * (hand + d * 1.8), xf * tip, ink, 2.8 * s, true)
	draw_line(xf * (hand + d * 2.6), xf * tip, _c(Toon.FOAM, k), 1.2 * s, true)
	draw_circle(xf * (hand + d * 1.3), 1.7 * s, _c(Toon.GOLD, k))
	draw_circle(xf * hand, 2.2 * s, ink)
	draw_circle(xf * hand, 1.6 * s, _c(Toon.SKIN, k))


## Petit oni (yokai de base), pieds en p ; face = -1 : il regarde à gauche.
## club : massue au repos (0), levée (1 : le coup s'annonce), abattue (2).
## hit ≥ 0 : secondes depuis qu'il est tranché (éclair blanc, il s'écrase et disparaît).
func _oni(p: Vector2, s: float, face: float, k: float, club := 0.0, hit := -1.0) -> void:
	var fade := k
	var sq := Vector2.ONE
	if hit >= 0.0:
		fade = k * (1.0 - _k(hit, 0.15, 0.25))
		var e := UiKit.ease_out(_k(hit, 0.0, 0.3))
		sq = Vector2(1.0 + 0.35 * e, 1.0 - 0.55 * e)
	if fade <= 0.01:
		return
	var bob := 0.0
	if hit < 0.0:
		bob = absf(sin(_now * 5.0 + p.x * 0.07)) * 1.2 * s
	var xf := Transform2D(0.0, Vector2(face * s * sq.x, -s * sq.y), 0.0, p - Vector2(0, bob))
	_ellipse(p + Vector2(0, 1.5 * s), 10.0 * s, 2.8 * s, _c(Toon.SUMI, 0.18 * fade))
	var ang := deg_to_rad(lerpf(65.0, 140.0, UiKit.ease_out(club)))
	if club > 1.0:
		ang = deg_to_rad(lerpf(140.0, -30.0, UiKit.ease_out(club - 1.0)))
	var hand := Vector2(7, 9)
	var ctip := hand + Vector2(cos(ang), sin(ang)) * 16.0
	# pieds et cornes
	draw_circle(xf * Vector2(-4, 1), 2.6 * s, _c(Toon.SUMI, fade))
	draw_circle(xf * Vector2(4, 1), 2.6 * s, _c(Toon.SUMI, fade))
	for sx in [-1.0, 1.0]:
		var horn := xf * PackedVector2Array([Vector2(6.5 * sx, 18.0), Vector2(2.5 * sx, 19.5), Vector2(6.5 * sx, 27.0)])
		draw_colored_polygon(horn, _c(Toon.WASHI, fade))
		_outline(horn, _c(Toon.SUMI, fade), 1.2 * s)
	# corps rond : il rougit en clignotant quand il prépare son coup
	var col := ONI
	if club > 0.0 and club <= 1.0:
		col = ONI.lerp(Toon.VERMILION.lightened(0.25), 0.5 + 0.5 * sin(_now * 18.0))
	var bc := xf * Vector2(0, 11)
	_ellipse(bc, 11.0 * s * sq.x, 11.0 * s * sq.y, _c(Toon.SUMI, fade))
	_ellipse(bc, 9.8 * s * sq.x, 9.8 * s * sq.y, _c(col, fade))
	# pagne en peau de tigre
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-8, 2.5), Vector2(8, 2.5), Vector2(7, 6.5), Vector2(-7, 6.5)]), _c(Toon.GOLD, fade))
	draw_line(xf * Vector2(-3, 2.5), xf * Vector2(-2, 6.5), _c(Toon.SUMI, fade), 1.2 * s)
	draw_line(xf * Vector2(2, 2.5), xf * Vector2(3, 6.5), _c(Toon.SUMI, fade), 1.2 * s)
	# yeux, sourcils froncés, crocs
	for ex in [-1.2, 4.2]:
		draw_circle(xf * Vector2(ex, 13.2), 2.3 * s, _c(Toon.WASHI, fade))
		draw_circle(xf * Vector2(ex + 0.6, 13.0), 1.1 * s, _c(Toon.SUMI, fade))
	draw_line(xf * Vector2(-3.8, 16.4), xf * Vector2(0.4, 15.0), _c(Toon.SUMI, fade), 1.5 * s, true)
	draw_line(xf * Vector2(2.6, 15.0), xf * Vector2(6.8, 16.4), _c(Toon.SUMI, fade), 1.5 * s, true)
	draw_line(xf * Vector2(0, 9.6), xf * Vector2(4.6, 9.6), _c(Toon.SUMI, fade), 1.3 * s)
	draw_colored_polygon(xf * PackedVector2Array([Vector2(0.6, 9.6), Vector2(1.8, 9.6), Vector2(1.2, 11.2)]), _c(Toon.WASHI, fade))
	draw_colored_polygon(xf * PackedVector2Array([Vector2(3.0, 9.6), Vector2(4.2, 9.6), Vector2(3.6, 11.2)]), _c(Toon.WASHI, fade))
	# bras et massue cloutée
	draw_line(xf * Vector2(4, 12), xf * hand, _c(Toon.SUMI, fade), 3.0 * s, true)
	draw_line(xf * hand, xf * ctip, _c(Toon.SUMI, fade), 5.6 * s, true)
	draw_line(xf * hand.lerp(ctip, 0.2), xf * ctip, _c(Toon.WOOD, fade), 3.4 * s, true)
	for j in 3:
		draw_circle(xf * hand.lerp(ctip, 0.5 + 0.17 * j), 0.9 * s, _c(Toon.SUMI, fade))
	draw_circle(xf * hand, 2.0 * s, _c(col, fade))
	if hit >= 0.0 and hit < 0.15:
		_ellipse(bc, 11.0 * s * sq.x, 11.0 * s * sq.y, _c(Color.WHITE, 0.8 * (1.0 - hit / 0.15) * k))
	if club > 0.0 and club <= 1.0:
		UiKit.text(self, UiKit.TITLE_FONT, "!", p + Vector2(0, -34.0 * s), int(20 * s), _c(Toon.VERMILION, fade * minf(club * 4.0, 1.0)))


## Bouffée d'encre : le yokai tranché s'évapore.
func _puff(c: Vector2, k: float) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	var u := _u
	var a := 1.0 - k
	var e := UiKit.ease_out(k)
	for j in 6:
		var d := Vector2.from_angle(TAU * j / 6.0 + 0.5) * (5.0 + 16.0 * e) * u
		draw_circle(c + d + Vector2(0, -6.0 * e) * u, (4.0 + 4.0 * e) * u * a + 0.5, _c(Toon.SUMI, 0.3 * a))
	draw_circle(c, 9.0 * u * (1.0 - e), _c(Toon.WASHI, 0.9 * a))


## Toucher : un anneau vermillon s'ouvre sous le doigt.
func _tap_fx(c: Vector2, k: float) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	var e := UiKit.ease_out(k)
	draw_arc(c, (6.0 + 22.0 * e) * _u, 0, TAU, 28, _c(Toon.VERMILION, 0.85 * (1.0 - k)), 2.5 * _u, true)
	draw_circle(c, 5.0 * _u * (1.0 - k), _c(Toon.VERMILION, 0.5 * (1.0 - k)))


## Traits de vitesse derrière le ronin pendant la ruée (dir : sens de la course).
func _speed_lines(p: Vector2, dir: Vector2, s: float, k: float) -> void:
	if k <= 0.01 or dir.length_squared() < 0.0001:
		return
	var dn := dir.normalized()
	var n := dn.orthogonal()
	for g in 3:
		var a0 := p + n * (g - 1) * 9.0 * s + Vector2(0, -16.0 * s) - dn * (12.0 + 4.0 * g) * s
		draw_line(a0, a0 - dn * (18.0 + 6.0 * g) * s, _c(Toon.SUMI, 0.35 * k), 2.0 * s, true)


## Sens de la course le long d'une polyligne, à la fraction f.
func _dir_at(pts: PackedVector2Array, f: float) -> Vector2:
	var d := _pt_at(pts, minf(f + 0.02, 1.0)) - _pt_at(pts, maxf(f - 0.02, 0.0))
	if d.length_squared() < 0.0001:
		return Vector2.RIGHT
	return d.normalized()


## Jauge d'encre du HUD (hud.gd _draw_gauge) : pilule sombre cerclée de blanc, remplie du bas, goutte dessous.
func _ink_gauge(r: Rect2, fill: float, col: Color, k: float) -> void:
	var u := _u
	draw_style_box(UiKit.box(_sb, _c(Color(0.06, 0.06, 0.09, 0.62), k), int(r.size.x / 2.0 + 3.0 * u), _c(Color(1, 1, 1, 0.75), k), int(maxf(1.0, 1.5 * u))), r.grow(3.0 * u))
	var fh := r.size.y * clampf(fill, 0.0, 1.0)
	if fh > 1.0:
		draw_style_box(UiKit.box(_sb, _c(col, k), int(r.size.x / 2.0)), Rect2(Vector2(r.position.x, r.end.y - fh), Vector2(r.size.x, fh)))
		draw_rect(Rect2(Vector2(r.position.x + 3.0 * u, r.end.y - fh + 4.0 * u), Vector2(3.0 * u, maxf(0.0, fh - 8.0 * u))), _c(Color(1, 1, 1, 0.35), k))
	var drop := Vector2(r.get_center().x, r.end.y + 16.0 * u)
	draw_circle(drop + Vector2(0, 2) * u, 6.0 * u, _c(col, k))
	draw_colored_polygon(PackedVector2Array([drop + Vector2(-5.5, 1) * u, drop + Vector2(0, -10) * u, drop + Vector2(5.5, 1) * u]), _c(col, k))
	draw_circle(drop + Vector2(-2, 1) * u, 1.6 * u, _c(Color(1, 1, 1, 0.6), k))


## Rouleau encore fermé (offre de pouvoir), liseré et halo à la couleur de sa rareté.
func _rolled(c: Vector2, s: float, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	draw_circle(c, 26.0 * s, _c(col, 0.12 * k))
	draw_style_box(UiKit.box(_sb, _c(Toon.PAPER, k), int(7 * s), _c(Toon.SUMI, k), int(maxf(1.0, 1.5 * s))), Rect2(c - Vector2(20, 7) * s, Vector2(40, 14) * s))
	draw_rect(Rect2(c + Vector2(-23, -8.5) * s, Vector2(4, 17) * s), _c(Toon.SUMI, k))
	draw_rect(Rect2(c + Vector2(19, -8.5) * s, Vector2(4, 17) * s), _c(Toon.SUMI, k))
	draw_rect(Rect2(c + Vector2(-3, -7) * s, Vector2(6, 14) * s), _c(col, k))
	draw_line(c + Vector2(-14, 0) * s, c + Vector2(-6, 0) * s, _c(Toon.SUMI, 0.3 * k), 1.5 * s)


## Technique d'une figure (celle que débloque son rouleau), jouée en fond quand le ronin arrive ; k ∈ [0, 1].
## rp : pieds du ronin ; center : centre de l'ensō (où tombe l'onde) ; s : échelle du ronin.
func _fig_fx(kind: String, fc: Color, pts: PackedVector2Array, rp: Vector2, face: float, center: Vector2, k: float, fade: float, s: float) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	var u := _u
	var c := rp - Vector2(0, 18) * s
	var al := (1.0 - k) * fade
	match kind:
		"loop":
			# toupie : des arcs tournent autour du ronin
			var rot := k * TAU * 2.0
			for j in 3:
				var a0 := rot + TAU * j / 3.0
				draw_arc(c, (24.0 + 8.0 * k) * u, a0, a0 + 1.5, 14, _c(fc, al), 4.0 * u, true)
		"zigzag":
			# éclair en chaîne : la foudre file vers trois points
			var fl := 0.6 + 0.4 * sin(_now * 40.0)
			for b in 3:
				var tg := c + Vector2.from_angle(-PI * 0.5 + (b - 1) * 1.15) * 54.0 * u
				var nrm := (tg - c).orthogonal().normalized()
				var pl := PackedVector2Array()
				for i in 7:
					var q := c.lerp(tg, float(i) / 6.0)
					if i > 0 and i < 6:
						q += nrm * sin(float(i) * 2.7 + floor(_now * 14.0) + float(b)) * 7.0 * u
					pl.append(q)
				draw_polyline(pl, _c(fc, al * fl), 3.0 * u, true)
				draw_circle(tg, 4.0 * u * (1.0 - k) + 1.0, _c(fc, al))
		"straight":
			# coupe iaï : une longue entaille prolonge le trait
			var a := pts[0]
			var b := pts[pts.size() - 1]
			var d := (b - a).normalized()
			var e := UiKit.ease_out(minf(k * 2.5, 1.0))
			draw_line(a - d * 10.0 * u, b + d * (10.0 + 40.0 * e) * u, _c(fc, al), 7.0 * u * (1.0 - k) + 1.0, true)
			draw_line(a, b + d * 40.0 * e * u, _c(Toon.WASHI, al), 2.0 * u * (1.0 - k) + 0.5, true)
		"return":
			# garde : un bouclier en arc devant le ronin
			var ca := 0.0 if face > 0.0 else PI
			var gr := (24.0 + 2.0 * sin(_now * 12.0)) * u
			draw_circle(c, gr, _c(fc, 0.12 * al))
			draw_arc(c, gr, ca - 1.3, ca + 1.3, 20, _c(fc, al), 4.0 * u, true)
			draw_arc(c, gr + 5.0 * u, ca - 0.9, ca + 0.9, 14, _c(fc, 0.5 * al), 2.0 * u, true)
		"enso":
			# frappe au sol : l'onde part du centre du cercle
			for j in 2:
				var q := clampf(k * 1.4 - j * 0.35, 0.0, 1.0)
				if q > 0.0 and q < 1.0:
					draw_arc(center, (12.0 + 64.0 * q) * u, 0, TAU, 40, _c(fc, (1.0 - q) * 0.9 * fade), 5.0 * u * (1.0 - q) + 1.0, true)
		_:
			# estoc : une pointe filée dans le sens du crochet
			var n := pts.size() - 1
			var d := (pts[n] - pts[maxi(0, n - 3)]).normalized()
			var e := UiKit.ease_out(minf(k * 3.0, 1.0))
			if e > 0.05:
				var tip := c + d * 58.0 * u * e
				var side := d.orthogonal() * 4.0 * u * (1.0 - k) + d.orthogonal() * 0.5
				draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]), _c(fc, al))
				for j in 4:
					var ang := d.angle() + (j - 1.5) * 0.7
					draw_line(tip, tip + Vector2.from_angle(ang) * 9.0 * u * e, _c(fc, al), 2.0 * u, true)


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


func _gem(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, 0), c + Vector2(0, r), c + Vector2(-r * 0.75, 0)])
	draw_colored_polygon(pts, _c(JADE))
	_outline(pts, _c(Toon.SUMI), 1.2 * _u)


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


## Rouleau de pouvoir (rareté rar), qui surgit (kin) puis s'efface (kout) ; unroll : il se déroule de haut en bas.
func _scroll_card(c: Vector2, s: float, rar: int, kin: float, kout: float, unroll := 1.0) -> void:
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
		draw_line(c + Vector2.from_angle(ang) * r0, c + Vector2.from_angle(ang) * r1, _c(rc, 0.5 * al * unroll), 3.0 * s, true)
	var sc := 0.6 + 0.4 * kin
	draw_set_transform(c, sin(_now * 2.0) * 0.04, Vector2(sc, sc * lerpf(0.1, 1.0, clampf(unroll, 0.0, 1.0))))
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
		"return":
			# demi-tour
			draw_arc(c + Vector2(0, -0.1) * s, s * 0.55, PI, TAU, 16, ink, w, true)
			draw_line(c + Vector2(-0.55, -0.1) * s, c + Vector2(-0.55, 0.8) * s, ink, w, true)
			draw_line(c + Vector2(0.55, -0.1) * s, c + Vector2(0.55, 0.6) * s, ink, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.3, 0.55) * s, c + Vector2(0.8, 0.55) * s, c + Vector2(0.55, 0.95) * s]), ink)
		"hook":
			# hameçon
			draw_line(c + Vector2(0.35, -0.9) * s, c + Vector2(0.35, 0.3) * s, ink, w, true)
			draw_arc(c + Vector2(0.0, 0.3) * s, s * 0.35, 0.0, PI, 14, ink, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.35, 0.3) * s, c + Vector2(-0.6, 0.0) * s, c + Vector2(-0.2, 0.05) * s]), ink)
		_:
			# ensō : cercle ouvert, plus épais au départ
			draw_arc(c, s * 0.85, -PI * 0.35, PI * 1.5, 32, ink, w * 1.5, true)
			draw_circle(c + Vector2.from_angle(-PI * 0.35) * s * 0.85, w * 0.9, ink)


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
