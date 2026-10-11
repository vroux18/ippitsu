extends Control
## Garde-robe (bouton GARDE-ROBE de l'accueil) : panneau de papier en bas de l'écran, le héros reste
## visible au-dessus sur sa barque (main tourne la caméra vers lui) et change d'apparence aussitôt.
## Catégories : Chapeau, Lame (le sabre est tiré pour le montrer), Écharpe, Sillage, Encre (apparences des Vues et
## en plus), Thème (interface). Six onglets à pictogramme et petit libellé ; la grille défile quand une catégorie
## dépasse deux rangées (glisser, molette). Les éléments verrouillés disent comment les obtenir ; certains
## s'achètent en pétales ; ceux gagnés par exploit portent une pastille « nouveau » jusqu'au premier toucher.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const Meta = preload("res://scripts/meta.gd")
const GOLD_INK := Color("#9A6B12")

# plus d'onglet TENUE : le hakama du ronin est fixe ; le chapeau et le sabre, eux, changent
const CATS := ["hat", "blade", "cape", "trail", "ink", "theme"]
const CAT_LABELS := ["CHAPEAU", "LAME", "ÉCHARPE", "SILLAGE", "ENCRE", "THÈME"]
const COLS := 5
const PANEL_H := 392.0  # hauteur du panneau (u)
const TAB_Y := 16.0  # haut des onglets dans le panneau (u)
const TAB_H := 46.0  # pictogramme et libellé
const GRID_Y := 70.0  # haut de la grille dans le panneau (u)
const RH := 72.0  # hauteur d'une rangée (u)
const WIN_ROWS := 2.4  # rangées visibles : la troisième dépasse un peu, on devine qu'elle défile
const SW_R := 23.0  # rayon d'une pastille (u)

signal changed(category: String)  # apparence ou thème porté : main réapplique sur le héros et l'accueil
signal closed

var meta  # instance de meta.gd, fournie par main
var cat := 0  # catégorie affichée
var _tab_f := 0.0  # onglet actif, glissé (pinceau d'encre derrière)
var _sel := ""  # dernier élément touché ("" : celui qui est porté)
var _sel_on := false
var _t := 0.0
var _hits: Array = []  # [Rect2, cible] : « tab:i », « item:<id> »
var _pressed := ""
var _down := false  # un appui est en cours (doigt ou souris)
var _press_pos := Vector2.ZERO
var _press_ms := 0
var _drag := false  # l'appui fait défiler la grille (plus de toucher)
var _drag_s0 := 0.0
var _scroll := 0.0  # défilement de la grille (px)
var _scroll_max := 0.0
var _scroll_pending := false
var _msg := ""
var _msg_t := 0.0
var _bump := 0.0  # élément qui vient d'être porté ou acheté (1 -> 0)
var _bump_key := ""
var _paper := Toon.PAPER
var _wash := Toon.WASHI
var _ink := Toon.SUMI
var _accent := Toon.VERMILION
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _sb := StyleBoxFlat.new()
var _back: Control
var _buy: Control
var _grid: Control  # fenêtre de la grille (découpe ses pastilles quand elle défile)
var _safe := Vector2.ZERO  # marges de sécurité de l'écran (haut, bas), en pixels


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = UiKit.TITLE_SPACING
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = UiKit.CAPS_SPACING
	# grille : enfant qui découpe son dessin (sous les boutons), les touches restent à la garde-robe
	_grid = Control.new()
	_grid.clip_contents = true
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)
	_grid.draw.connect(_draw_grid)
	# retour à l'accueil : bouton rond à la maison, au même endroit que ceux de l'Atelier et de la carte
	_back = InkButton.new()
	_back.text = "RETOUR"
	_back.style = "round"
	_back.icon = "home"
	_back.font = _ui
	add_child(_back)
	_back.pressed.connect(close)
	_buy = InkButton.new()
	_buy.text = "ACHETER"
	_buy.style = "primary"
	_buy.font = _ui
	add_child(_buy)
	_buy.pressed.connect(_on_buy)


func open() -> void:
	_t = 0.0
	_sel = ""
	_sel_on = false
	_pressed = ""
	_down = false
	_drag = false
	_msg_t = 0.0
	_bump = 0.0
	_hits.clear()
	_tab_f = float(cat)
	if meta != null:
		meta.refresh_new()  # exploits déjà remplis (anciennes sauvegardes, records) : pastilles « nouveau »
	_read_theme()
	_scroll_to_worn()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	_pressed = ""
	_down = false
	_drag = false
	closed.emit()


func _read_theme() -> void:
	if meta == null:
		return
	var th: Dictionary = meta.theme_colors()
	_paper = th["paper"]
	_wash = th["wash"]
	_ink = th["ink"]
	_accent = th["accent"]


func cat_id() -> String:
	return String(CATS[cat])


## Élément affiché dans le détail : le dernier touché, sinon celui qui est porté.
func shown_id() -> String:
	if _sel_on:
		return _sel
	for id in meta.cosmetic_ids(cat_id()):
		if bool(meta.cosmetic_worn(cat_id(), String(id))):
			return String(id)
	return ""


# ------------------------------------------------------------------ géométrie

func _u() -> float:
	return size.x / 400.0


func _panel(h: float, u: float) -> Rect2:
	var top := maxf(h * 0.44, h - _safe.y - PANEL_H * u)
	return Rect2(Vector2(0, top), Vector2(size.x, h - top))


## Fenêtre de la grille (coordonnées de la garde-robe), panneau posé (sans l'entrée animée).
func _grid_rect(u: float) -> Rect2:
	var pr := _panel(size.y, u)
	return Rect2(Vector2(12.0 * u, pr.position.y + GRID_Y * u), Vector2(size.x - 24.0 * u, WIN_ROWS * RH * u))


## Centre d'une pastille dans la grille (repère de la fenêtre, avant défilement).
func _cell(i: int, u: float) -> Vector2:
	var cw := (size.x - 24.0 * u) / float(COLS)
	return Vector2(cw * (float(i % COLS) + 0.5), RH * u * float(i / COLS) + 27.0 * u)


func _rows() -> int:
	return int(ceil(float(meta.cosmetic_ids(cat_id()).size()) / float(COLS)))


func _update_scroll_max(u: float) -> void:
	_scroll_max = maxf(0.0, (float(_rows()) * RH + 6.0) * u - WIN_ROWS * RH * u)
	_scroll = clampf(_scroll, 0.0, _scroll_max)


## Fait défiler la grille jusqu'à l'élément porté (ou affiché) : il est toujours visible à l'ouverture d'un onglet.
func _scroll_to_worn() -> void:
	if meta == null or size.x < 10.0:
		_scroll = 0.0
		_scroll_pending = true  # taille encore inconnue : au prochain _process
		return
	var u := _u()
	_update_scroll_max(u)
	var ids: Array = meta.cosmetic_ids(cat_id())
	var i := ids.find(shown_id())
	if i < 0:
		_scroll = 0.0
		return
	var row := float(i / COLS)
	var top := row * RH * u
	var win := WIN_ROWS * RH * u
	if top < _scroll:
		_scroll = top
	elif top + RH * u > _scroll + win:
		_scroll = top + RH * u - win + 6.0 * u
	_scroll = clampf(_scroll, 0.0, _scroll_max)


# ------------------------------------------------------------------ entrée

func _target_at(p: Vector2) -> String:
	for i in range(_hits.size() - 1, -1, -1):
		var hr: Array = _hits[i]
		var r: Rect2 = hr[0]
		if r.has_point(p):
			return String(hr[1])
	return ""


## Appui (doigt ou souris) : la cible est retenue à l'appui ; le toucher qui a ouvert la garde-robe n'agit pas.
func _press_at(p: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if _down and now - _press_ms < 400 and p.distance_to(_press_pos) < 40.0:
		return  # même appui, déjà suivi (le tactile et la souris émulée arrivent tous les deux)
	# sinon : nouvel appui (un relâché perdu ne bloque jamais la garde-robe)
	_down = true
	_drag = false
	_drag_s0 = _scroll
	_press_ms = now
	_press_pos = p
	_pressed = _target_at(p) if _t >= 0.3 else ""


## Glissé : au-delà de quelques pixels dans la fenêtre de la grille, l'appui la fait défiler (et ne touche plus).
func _move_at(p: Vector2) -> void:
	if not _down or _scroll_max <= 0.0:
		return
	var u := _u()
	if not _drag:
		if absf(p.y - _press_pos.y) < 10.0 * u or not _grid_rect(u).grow(8.0 * u).has_point(_press_pos):
			return
		_drag = true
		_pressed = ""
	_scroll = clampf(_drag_s0 - (p.y - _press_pos.y), 0.0, _scroll_max)


## Relâché : on agit si le doigt est resté sur la cible, ou n'a presque pas bougé (un doigt dérive).
func _release_at(p: Vector2) -> void:
	if not _down:
		return  # relâché déjà traité par l'autre source : pas de double déclenchement
	_down = false
	var start := _pressed
	_pressed = ""
	if _drag:
		_drag = false
		return
	if start == "":
		return
	var u := _u()
	if _target_at(p) == start or p.distance_to(_press_pos) <= 24.0 * u:
		tap(start)


func _gui_input(event: InputEvent) -> void:
	if meta == null:
		return
	# tactile direct (téléphone) : ne dépend pas de l'émulation de la souris
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		accept_event()
		if st.index != 0:
			return
		if st.pressed:
			_press_at(st.position)
		else:
			_release_at(st.position)
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		accept_event()
		if sd.index == 0:
			_move_at(sd.position)
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_move_at(mm.position)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			accept_event()
			if mb.pressed:
				var dir := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				_scroll = clampf(_scroll + dir * RH * 0.5 * _u(), 0.0, _scroll_max)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if mb.pressed:
			_press_at(mb.position)
		else:
			_release_at(mb.position)


## Toucher une cible : onglet, ou élément (porté s'il est possédé ; sinon choisi, le détail dit comment l'obtenir).
func tap(key: String) -> void:
	if meta == null:
		return
	if key.begins_with("tab:"):
		var i := clampi(int(key.substr(4)), 0, CATS.size() - 1)
		if i != cat:
			cat = i
			_sel = ""
			_sel_on = false
			_scroll_to_worn()
		return
	if not key.begins_with("item:"):
		return
	var id := key.substr(5)
	var c := cat_id()
	_sel = id
	_sel_on = true
	_scroll_to_worn()
	meta.cosmetic_seen(c, id)
	# retour visuel à chaque toucher (même sur un élément verrouillé ou déjà porté)
	_bump = 1.0
	_bump_key = key
	if bool(meta.cosmetic_owned(c, id)):
		if not bool(meta.cosmetic_worn(c, id)) and bool(meta.wear_cosmetic(c, id)):
			if c == "theme":
				_read_theme()
			changed.emit(c)


func _on_buy() -> void:
	if meta == null:
		return
	var c := cat_id()
	var id := shown_id()
	var cost := int(meta.cosmetic_cost(c, id))
	if cost < 0 or bool(meta.cosmetic_owned(c, id)):
		return
	if int(meta.petals) < cost:
		# pas assez de pétales : les chiffres suffisent (ce qu'on a, sur le prix)
		_msg = "%d / %d" % [int(meta.petals), cost]
		_msg_t = 1.8
		return
	if bool(meta.buy_cosmetic(c, id)):
		_bump = 1.0
		_bump_key = "item:" + id
		_msg = "PORTÉ"
		_msg_t = 1.5
		if c == "theme":
			_read_theme()
		changed.emit(c)


# ------------------------------------------------------------------ dessin

func _process(_delta: float) -> void:
	if not visible or meta == null:
		return
	size = get_viewport_rect().size
	_safe = UiKit.safe_insets(size)
	var dt := UiKit.real_delta()
	_t += dt
	_msg_t = maxf(0.0, _msg_t - dt)
	_bump = maxf(0.0, _bump - dt * 2.5)
	_tab_f = move_toward(_tab_f, float(cat), dt * 9.0)
	var u := _u()
	_update_scroll_max(u)
	if _scroll_pending:
		_scroll_pending = false
		_scroll_to_worn()
	var a := UiKit.ease_out(clampf(_t / 0.35, 0.0, 1.0))
	# en-tête commun : bouton rond (ICON_BTN) centré sur (HEAD_X, HEAD_Y), sous l'encoche
	var ib: float = UiKit.ICON_BTN * u
	_back.size = Vector2(ib, ib)
	_back.position = Vector2(UiKit.HEAD_X * u - ib / 2.0, _safe.x + UiKit.HEAD_Y * u - ib / 2.0 - 16 * u * (1.0 - a))
	_back.modulate.a = a
	# fenêtre de la grille : suit l'entrée du panneau
	var gr := _grid_rect(u)
	_grid.position = gr.position + Vector2(0, 40 * u * (1.0 - a))
	_grid.size = gr.size
	_grid.queue_redraw()
	# ACHETER : seulement pour un élément à acheter
	var c := cat_id()
	var id := shown_id()
	var cost := int(meta.cosmetic_cost(c, id))
	var can := cost >= 0 and not bool(meta.cosmetic_owned(c, id))
	_buy.visible = can
	if can:
		var pr := _panel(size.y, u)
		var bw := size.x * 0.56
		_buy.size = Vector2(bw, UiKit.BTN_H * u)
		_buy.position = Vector2((size.x - bw) / 2.0, pr.end.y - _safe.y - (UiKit.BTN_H + UiKit.SP_M) * u + 30 * u * (1.0 - a))
		_buy.text = "ACHETER  ·  %d" % cost
		_buy.style = "primary" if int(meta.petals) >= cost else "ghost"
		_buy.font_size = int(UiKit.FS_HEADING * u)
		_buy.modulate.a = a
	queue_redraw()


func _draw() -> void:
	if meta == null or size.x < 10.0:
		return
	_hits.clear()
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var a := UiKit.ease_out(clampf(_t / 0.35, 0.0, 1.0))
	# voile du haut (titre lisible), le héros reste visible au milieu
	var vh := _safe.x + 100.0 * u
	var top := PackedColorArray([Color(_wash, 0.9 * a), Color(_wash, 0.9 * a), Color(_wash, 0.0), Color(_wash, 0.0)])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, vh), Vector2(0, vh)]), top)
	# en-tête commun : retour à gauche (InkButton rond), titre souligné de vermillon
	var hy := _safe.x
	var tmax: float = w - 2.0 * 112.0 * u  # place pour le compteur de pétales à droite
	UiKit.screen_title(self, _title, "GARDE-ROBE", Vector2(w / 2.0, hy + UiKit.HEAD_BASE * u - 8.0 * u * (1.0 - a)), u, _ink, a, "", tmax, UiKit.ease_out(clampf((_t - 0.15) / 0.4, 0.0, 1.0)))
	# compteur de pétales, la monnaie de la garde-robe (même pilule sumi que l'encre, pétale sur disque sakura), en haut
	# à droite sur la ligne de l'en-tête ; l'encre, elle, ne sert qu'à l'Arbre et ne s'affiche pas ici
	UiKit.ink_counter(self, _sb, w - UiKit.SP_M * u, hy + UiKit.HEAD_Y * u, int(meta.petals), u, a, true, true)
	# panneau de papier : coins hauts arrondis, ombre vers le haut, asanoha (motif de kimono) très pâle, fibres
	var pr := _panel(h, u)
	pr.position.y += 40 * u * (1.0 - a)
	UiKit.box(_sb, Color(_paper, 0.97 * a), int(UiKit.R_L * 1.2 * u))
	_sb.corner_radius_bottom_left = 0
	_sb.corner_radius_bottom_right = 0
	_sb.shadow_color = Color(0, 0, 0, UiKit.SHADOW_A * a)
	_sb.shadow_size = int(UiKit.SHADOW_SIZE * 1.6 * u)
	_sb.shadow_offset = Vector2(0, -UiKit.SHADOW_Y * u)
	draw_style_box(_sb, Rect2(pr.position, pr.size + Vector2(0, 30 * u)))
	_sb.shadow_size = 0
	_sb.shadow_offset = Vector2.ZERO
	var tx := 12.0 * u
	var ty := pr.position.y + TAB_Y * u
	# sous les onglets : asanoha (motif de kimono) très pâle, fibres du papier
	var pat_y: float = ty + (TAB_H + 4.0) * u
	var pat := Rect2(Vector2(UiKit.SP_M * u, pat_y), Vector2(w - 2.0 * UiKit.SP_M * u, maxf(10.0, pr.end.y - pat_y)))
	UiKit.asanoha(self, pat, Color(_ink, 0.045 * a), 26.0 * u)
	UiKit.fibres(self, pr, _ink, a, u, 4.0, 12)
	draw_line(Vector2(w / 2.0 - 22 * u, pr.position.y + 9 * u), Vector2(w / 2.0 + 22 * u, pr.position.y + 9 * u), Color(_ink, 0.2 * a), 3 * u, true)
	_draw_tabs(Rect2(Vector2(tx, ty), Vector2(w - 24.0 * u, TAB_H * u)), u, a)
	# éléments : dessinés par la fenêtre de la grille (_draw_grid) ; ici, leurs zones de toucher visibles
	var c := cat_id()
	var ids: Array = meta.cosmetic_ids(c)
	var gr := _grid_rect(u)
	var cw := gr.size.x / float(COLS)
	for i in ids.size():
		var cc := gr.position + _cell(i, u) - Vector2(0, _scroll)
		var hr := Rect2(cc - Vector2(cw * 0.5, 27 * u), Vector2(cw, RH * u - 2 * u)).intersection(gr)
		if hr.size.y >= 22.0 * u:
			_hits.append([hr, "item:" + String(ids[i])])
	# barre de défilement : fine, à droite de la fenêtre
	if _scroll_max > 0.0:
		var gy0 := pr.position.y + GRID_Y * u
		var win := gr.size.y
		var full := win + _scroll_max
		var bh := maxf(18.0 * u, win * win / full)
		var by := gy0 + (win - bh) * (_scroll / _scroll_max)
		var bx := w - 7.0 * u
		draw_line(Vector2(bx, gy0 + 2 * u), Vector2(bx, gy0 + win - 2 * u), Color(_ink, 0.08 * a), 3.0 * u, true)
		draw_line(Vector2(bx, by + 2 * u), Vector2(bx, by + bh - 2 * u), Color(_ink, 0.35 * a), 3.0 * u, true)
	# détail de l'élément affiché, sous un filet au pinceau (shuriken au milieu)
	var shown := shown_id()
	var ry := pr.position.y + (GRID_Y + WIN_ROWS * RH + 6.0) * u
	UiKit.brush_rule(self, w * 0.2, w * 0.8, ry, u, Color(_ink, 0.25), a)
	var dy := ry + 16 * u
	var nm := UiKit.plain(String(meta.cosmetic_name(c, shown)))
	var nw := UiKit.text(self, UiKit.TITLE_FONT, nm, Vector2(w / 2.0, dy + 8 * u), int(UiKit.FS_HEADING * u), Color(_ink, a))
	# échantillon pour le sillage et l'encre (invisibles sur le héros immobile), à droite du nom
	if c == "trail" or c == "ink":
		_sample_stroke(c, shown, Vector2(minf(w - 40.0 * u, w / 2.0 + nw / 2.0 + 40.0 * u), dy + 3 * u), u, a)
	# dessous : PORTÉ (coche), ou le message d'achat ; pour ce qui n'est pas acquis, comment l'obtenir (deux lignes)
	var sub := ""
	var sc := Color(_ink, 0.6 * a)
	var check := false
	if _msg_t > 0.0:
		sub = _msg
		sc = Color(_accent, a)
		check = _msg == "PORTÉ"
	elif bool(meta.cosmetic_worn(c, shown)):
		sub = "PORTÉ"
		check = true
	elif not bool(meta.cosmetic_owned(c, shown)):
		sub = UiKit.plain(String(meta.cosmetic_how(c, shown)))
	var bfs: int = int(UiKit.FS_BODY * u)
	var lines := UiKit.wrap(_ui, sub, bfs, w - 60 * u, ["·", ":", "»"])
	var nl := mini(lines.size(), 2)
	for li in nl:
		var lw3 := UiKit.text(self, _ui, lines[li], Vector2(w / 2.0, dy + 28 * u + 15 * u * li), bfs, sc)
		if check and li == 0:
			UiKit.glyph(self, "check", Vector2(w / 2.0 - lw3 / 2.0 - 10.0 * u, dy + 28 * u - bfs * 0.36), 4.5 * u, Color(_accent, a), UiKit.NONE, a)


## Onglets à pictogramme : six cases, pictogramme au-dessus d'un petit libellé, coup de pinceau d'encre derrière
## l'actif (il glisse d'un onglet à l'autre) ; pastille vermillon s'il y a du nouveau dans la catégorie.
func _draw_tabs(r: Rect2, u: float, a: float) -> void:
	var n := CATS.size()
	var cw := r.size.x / float(n)
	var fs := maxi(1, int(UiKit.FS_MICRO * u))
	var font := UiKit.tab_font()
	# le pinceau : quadrilatère aux bouts biseautés, sous le pictogramme et le mot
	var acx := r.position.x + cw * (_tab_f + 0.5)
	var aw := cw - 4.0 * u
	var y0 := r.position.y + 1.0 * u
	var y1 := r.end.y - 1.0 * u
	var pts := PackedVector2Array([Vector2(acx - aw / 2.0 + 5.0 * u, y0), Vector2(acx + aw / 2.0, y0 + 2.0 * u),
		Vector2(acx + aw / 2.0 - 5.0 * u, y1), Vector2(acx - aw / 2.0, y1 - 2.0 * u)])
	draw_colored_polygon(pts, Color(_ink, a))
	for i in n:
		var cr := Rect2(Vector2(r.position.x + cw * float(i), r.position.y), Vector2(cw, r.size.y))
		_hits.append([cr.grow_individual(0.0, 2.0 * u, 0.0, 2.0 * u), "tab:%d" % i])
		var on := clampf(1.0 - absf(_tab_f - float(i)), 0.0, 1.0)
		var col: Color = Color(_ink, 0.7).lerp(_paper, on)
		col.a *= a
		var ic := Vector2(cr.get_center().x, r.position.y + 17.0 * u)
		_tab_icon(String(CATS[i]), ic, 9.5 * u, col, u)
		var lab := UiKit.plain(String(CAT_LABELS[i]))
		UiKit.text(self, font, lab, Vector2(ic.x, r.position.y + 39.0 * u), fs, col)
		if meta.cosmetic_new(String(CATS[i])):
			draw_circle(ic + Vector2(13.0 * u, -8.0 * u), 3.2 * u, Color(Toon.VERMILION, a))


## Pictogramme d'un onglet, centré en c, demi-taille s.
func _tab_icon(c: String, p: Vector2, s: float, col: Color, u: float) -> void:
	var lw := maxf(1.4, 1.9 * u)
	match c:
		"hat":
			# kasa : cône à large bord, cordon
			draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 1.15, s * 0.42), p + Vector2(0, -s * 0.62),
				p + Vector2(s * 1.15, s * 0.42), p + Vector2(0, s * 0.62)]), col)
			draw_arc(p + Vector2(0, s * 0.55), s * 0.38, 0.2, PI - 0.2, 8, col, lw, true)
		"blade":
			# katana en diagonale : lame, tsuba, poignée plus épaisse
			var d := Vector2(1, -1).normalized()
			var n := Vector2(d.y * -1.0, d.x)
			var g := p + Vector2(-s * 0.45, s * 0.45)
			draw_line(g, g + d * s * 1.55, col, lw * 1.2, true)
			draw_line(g + d * s * 1.2, g + d * s * 1.6, col, lw * 0.7, true)
			draw_line(g - n * s * 0.32, g + n * s * 0.32, col, lw * 1.4, true)
			draw_line(g, g - d * s * 0.62, col, lw * 2.0, true)
		"cape":
			# écharpe : deux pans ondulés
			for k in 2:
				var pl := PackedVector2Array()
				for j in 9:
					var t := float(j) / 8.0
					pl.append(p + Vector2(-s + 2.0 * s * t, (-0.35 + 0.7 * float(k)) * s + sin(t * TAU) * s * 0.28 * (1.0 + t)))
				draw_polyline(pl, col, lw * (1.6 - 0.4 * float(k)), true)
		"trail":
			# sillage : arc de lame effilé
			var pl := PackedVector2Array()
			for j in 12:
				var t := float(j) / 11.0
				var ang := PI * (1.1 + 0.85 * t)
				pl.append(p + Vector2(0, s * 0.45) + Vector2(cos(ang), sin(ang)) * s * 1.05)
			for j in range(11, -1, -1):
				var t := float(j) / 11.0
				var ang := PI * (1.1 + 0.85 * t)
				pl.append(p + Vector2(0, s * 0.45) + Vector2(cos(ang), sin(ang)) * s * (1.05 - 0.42 * sin(PI * t)))
			if UiKit.poly_area(pl) > 1.0:
				draw_colored_polygon(pl, col)
		"ink":
			UiKit.glyph(self, "at_drop", p, s * 1.05, col, UiKit.NONE)
		_:
			# thème : carte de papier, deux lignes et un liseré
			var cr := Rect2(p - Vector2(s * 0.9, s * 0.72), Vector2(s * 1.8, s * 1.44))
			draw_rect(cr, col, false, lw)
			draw_line(cr.position + Vector2(s * 0.35, s * 0.45), cr.position + Vector2(s * 1.45, s * 0.45), col, lw, true)
			draw_line(cr.position + Vector2(s * 0.35, s * 0.85), cr.position + Vector2(s * 1.1, s * 0.85), col, lw, true)


## Grille des éléments de la catégorie (dessinée dans la fenêtre `_grid`, qui découpe ce qui défile).
func _draw_grid() -> void:
	if meta == null or size.x < 10.0:
		return
	var g := _grid
	var u := _u()
	var a := UiKit.ease_out(clampf(_t / 0.35, 0.0, 1.0))
	var c := cat_id()
	var ids: Array = meta.cosmetic_ids(c)
	var shown := shown_id()
	var wh := g.size.y
	for i in ids.size():
		var id := String(ids[i])
		var cc := _cell(i, u) - Vector2(0, _scroll)
		if cc.y < -RH * u or cc.y > wh + RH * u:
			continue
		var k := UiKit.ease_out(clampf((_t - 0.12 - 0.025 * i) / 0.25, 0.0, 1.0))
		var ka := a * k
		var owned := bool(meta.cosmetic_owned(c, id))
		var worn := bool(meta.cosmetic_worn(c, id))
		var key := "item:" + id
		var rad := SW_R * u * (1.0 + (0.12 * _bump if key == _bump_key else 0.0))
		_swatch(g, c, id, cc, rad, ka * (1.0 if owned else 0.45))
		if worn:
			g.draw_arc(cc, rad + 4 * u, 0.0, TAU, 40, Color(_accent, ka), 2.6 * u, true)
		elif id == shown and _sel_on:
			g.draw_arc(cc, rad + 4 * u, 0.0, TAU, 40, Color(_ink, 0.6 * ka), 1.6 * u, true)
		if not owned:
			UiKit.glyph(g, "at_lock", cc + Vector2(rad * 0.66, -rad * 0.66), 8.5 * u, Color(Toon.WASHI, 0.95 * ka), Toon.SUMI)
		elif bool(meta.cosmetic_new(c, id)):
			# gagné par exploit, pas encore vu : pastille vermillon cernée de papier
			var nc := cc + Vector2(-rad * 0.7, -rad * 0.7)
			g.draw_circle(nc, 5.0 * u, Color(_paper, ka))
			g.draw_circle(nc, 3.6 * u, Color(Toon.VERMILION, ka))
		# prix de ce qui s'achète : pastille sumi, pétale et chiffre (le nom se lit en bas, pour l'élément affiché)
		var cost := int(meta.cosmetic_cost(c, id))
		if not owned and cost >= 0:
			var nf := UiKit.num_font()
			var pfs := int(UiKit.FS_CAPTION * u)
			var ptxt := str(cost)
			var pw := nf.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x + 22.0 * u
			var pr2 := Rect2(Vector2(cc.x - pw / 2.0, cc.y + rad + 4.0 * u), Vector2(pw, 16.0 * u))
			g.draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, 0.9 * ka), int(8 * u)), pr2)
			UiKit.glyph(g, "at_petal", Vector2(pr2.position.x + 9.0 * u, pr2.get_center().y), 5.0 * u, UIColors.SAKURA.lightened(0.45), UiKit.NONE, ka)
			g.draw_string(nf, Vector2(pr2.position.x + 16.0 * u, pr2.get_center().y + pfs * 0.36), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(Toon.WASHI, ka))
	# bords de la fenêtre quand elle défile : la grille se fond dans le papier (on devine la suite)
	if _scroll_max > 0.0:
		var fh := 16.0 * u
		var gw := g.size.x
		if _scroll < _scroll_max - 1.0:
			g.draw_polygon(PackedVector2Array([Vector2(0, wh - fh), Vector2(gw, wh - fh), Vector2(gw, wh), Vector2(0, wh)]),
				PackedColorArray([Color(_paper, 0.0), Color(_paper, 0.0), Color(_paper, 0.95 * a), Color(_paper, 0.95 * a)]))
		if _scroll > 1.0:
			g.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(gw, 0), Vector2(gw, fh), Vector2(0, fh)]),
				PackedColorArray([Color(_paper, 0.95 * a), Color(_paper, 0.95 * a), Color(_paper, 0.0), Color(_paper, 0.0)]))


## Pastille d'un élément selon sa catégorie (dessinée sur `ci`).
func _swatch(ci: CanvasItem, c: String, id: String, p: Vector2, r: float, a: float) -> void:
	var col: Color = meta.cosmetic_color(c, id)
	ci.draw_circle(p + Vector2(0, 2), r, Color(0, 0, 0, 0.18 * a))
	match c:
		"theme":
			var th: Dictionary = Meta.THEMES.get(id, {})
			var wash: Color = th.get("wash", Toon.WASHI)
			var paper: Color = th.get("paper", Toon.PAPER)
			var ink: Color = th.get("ink", Toon.SUMI)
			var acc: Color = th.get("accent", Toon.VERMILION)
			ci.draw_circle(p, r, Color(wash, a))
			var card := Rect2(p + Vector2(-r * 0.55, -r * 0.5), Vector2(r * 1.1, r))
			ci.draw_style_box(UiKit.box(_sb, Color(paper, a), int(r * 0.18)), card)
			ci.draw_line(card.position + Vector2(r * 0.18, r * 0.3), card.position + Vector2(r * 0.92, r * 0.3), Color(ink, a), r * 0.12)
			ci.draw_line(card.position + Vector2(r * 0.18, r * 0.55), card.position + Vector2(r * 0.7, r * 0.55), Color(ink, 0.6 * a), r * 0.09)
			ci.draw_rect(Rect2(card.position + Vector2(r * 0.18, r * 0.72), Vector2(r * 0.3, r * 0.14)), Color(acc, a))
		"trail":
			ci.draw_circle(p, r, Color(Toon.SUMI, 0.9 * a))
			if col.get_luminance() < 0.25:
				# sillage sombre : liseré de papier, sinon noir sur noir
				ci.draw_arc(p, r * 0.58, PI * 0.85, PI * 2.05, 18, Color(Toon.WASHI, 0.7 * a), r * 0.36, true)
			ci.draw_arc(p, r * 0.58, PI * 0.85, PI * 2.05, 18, Color(col, a), r * 0.26, true)
		"ink":
			ci.draw_circle(p, r, Color(Toon.PAPER, a))
			_blob(ci, p, r * 0.62, Color(col, a))
		"hat":
			ci.draw_circle(p, r, Color(Toon.WASHI.lerp(Color("#9FB8C8"), 0.35), a))
			_hat_icon(ci, id, p, r, a)
		"blade":
			ci.draw_circle(p, r, Color(Toon.WASHI.lerp(Color("#C9B48A"), 0.3), a))
			_blade_icon(ci, id, p, r, a)
		"outfit":
			ci.draw_circle(p, r, Color(col, a))
			UiKit.hanger_icon(ci, p + Vector2(0, r * 0.05), r * 0.52, Color(Toon.SUMI if col.v > 0.6 else Toon.WASHI, 0.75 * a))
		_:
			ci.draw_circle(p, r, Color(col, a))
			# écharpe : un pli
			ci.draw_arc(p + Vector2(0, -r * 0.1), r * 0.55, 0.3, PI - 0.3, 14, Color(Toon.SUMI, 0.35 * a), r * 0.1, true)
	ci.draw_arc(p, r, 0.0, TAU, 40, Color(_ink, 0.55 * a), maxf(1.0, r * 0.07), true)


## Couvre-chef de la pastille : une tête de profil à trois quarts sous sa coiffe (couleurs de meta.HATS).
func _hat_icon(ci: CanvasItem, id: String, p: Vector2, r: float, a: float) -> void:
	var col: Color = meta.cosmetic_color("hat", id)
	var col2: Color = meta.cosmetic_color2("hat", id)
	var sk := Color("#F2D7B6")
	var ink := Color(Toon.SUMI, a)
	var lw := maxf(1.0, r * 0.07)
	var hc := p + Vector2(0, r * 0.32)  # tête
	var hr := r * 0.36
	var hair := Color("#1E1B22")
	match id:
		"hachimaki", "kitsune", "oni":
			ci.draw_circle(hc, hr, Color(sk, a))
			ci.draw_arc(hc, hr, PI * 1.02, PI * 1.98, 14, Color(hair, a), hr * 0.5, true)
			ci.draw_arc(hc, hr, 0.0, TAU, 24, ink, lw, true)
			if id == "hachimaki":
				var by := hc.y - hr * 0.45
				ci.draw_line(Vector2(hc.x - hr * 1.02, by), Vector2(hc.x + hr * 1.02, by), Color(col, a), hr * 0.42, true)
				ci.draw_circle(Vector2(hc.x, by), hr * 0.17, Color(col2, a))
				ci.draw_line(Vector2(hc.x + hr * 0.95, by), Vector2(hc.x + hr * 1.6, by + hr * 0.7), Color(col, a), hr * 0.22, true)
			else:
				# masque relevé sur le côté
				var mc := hc + Vector2(hr * 0.75, -hr * 1.05)
				var mr := Vector2(hr * 0.72, hr * 0.85)
				var pts := PackedVector2Array()
				for j in 16:
					var ang := TAU * float(j) / 16.0
					pts.append(mc + Vector2(cos(ang) * mr.x, sin(ang) * mr.y))
				if id == "kitsune":
					# oreilles pointues
					for sx in [-1.0, 1.0]:
						var e := mc + Vector2(float(sx) * mr.x * 0.6, -mr.y * 0.7)
						ci.draw_colored_polygon(PackedVector2Array([e + Vector2(-hr * 0.22, hr * 0.15), e + Vector2(float(sx) * hr * 0.12, -hr * 0.5),
							e + Vector2(hr * 0.22, hr * 0.15)]), Color(col, a))
				else:
					for sx in [-1.0, 1.0]:
						var e := mc + Vector2(float(sx) * mr.x * 0.55, -mr.y * 0.75)
						ci.draw_colored_polygon(PackedVector2Array([e + Vector2(-hr * 0.13, hr * 0.1), e + Vector2(float(sx) * hr * 0.2, -hr * 0.55),
							e + Vector2(hr * 0.13, hr * 0.1)]), Color(col2, a))
				ci.draw_colored_polygon(pts, Color(col, a))
				pts.append(pts[0])
				ci.draw_polyline(pts, ink, lw, true)
				# yeux
				for sx in [-1.0, 1.0]:
					var ey := mc + Vector2(float(sx) * mr.x * 0.4, -mr.y * 0.1)
					ci.draw_line(ey - Vector2(hr * 0.16, -float(sx) * hr * 0.05), ey + Vector2(hr * 0.16, -float(sx) * hr * 0.05),
						Color(col2 if id == "kitsune" else Toon.SUMI, a), maxf(1.0, hr * 0.14), true)
		"zukin":
			ci.draw_circle(hc, hr * 1.12, Color(col, a))
			ci.draw_rect(Rect2(hc + Vector2(-hr * 0.72, -hr * 0.28), Vector2(hr * 1.44, hr * 0.36)), Color(sk, a))
			for sx in [-1.0, 1.0]:
				ci.draw_circle(hc + Vector2(float(sx) * hr * 0.32, -hr * 0.1), hr * 0.09, ink)
			ci.draw_line(hc + Vector2(hr * 0.9, -hr * 0.6), hc + Vector2(hr * 1.5, -hr * 0.2), Color(col2, a), hr * 0.2, true)
			ci.draw_arc(hc, hr * 1.12, 0.0, TAU, 24, ink, lw, true)
		_:
			ci.draw_circle(hc, hr, Color(sk, a))
			ci.draw_arc(hc, hr, 0.0, TAU, 24, ink, lw, true)
			# chapeau conique (jingasa plus plat, amigasa en dôme)
			var bw := r * 0.95
			var ht := r * (0.36 if id == "jingasa" else 0.62)
			var base := hc.y - hr * 0.35
			var pts := PackedVector2Array()
			if id == "amigasa":
				for j in 13:
					var ang := PI + PI * float(j) / 12.0
					pts.append(Vector2(hc.x + cos(ang) * bw * 0.85, base + sin(ang) * ht * 0.95))
			else:
				pts = PackedVector2Array([Vector2(hc.x - bw, base), Vector2(hc.x, base - ht), Vector2(hc.x + bw, base)])
			var under := PackedVector2Array([Vector2(hc.x - bw, base), Vector2(hc.x + bw, base), Vector2(hc.x, base + r * 0.1)])
			ci.draw_colored_polygon(under, Color(col.darkened(0.4), a))
			ci.draw_colored_polygon(pts, Color(col, a))
			var ol := pts.duplicate()
			ol.append(pts[0])
			ci.draw_polyline(ol, ink, lw, true)
			match id:
				"jingasa":
					ci.draw_circle(Vector2(hc.x, base - ht * 0.72), r * 0.1, Color(col2, a))
					ci.draw_line(Vector2(hc.x - bw, base), Vector2(hc.x + bw, base), Color(col2, a), lw * 1.4, true)
				"amigasa":
					for j in 3:
						var yy := base - ht * (0.25 + 0.25 * float(j))
						var hw := bw * 0.85 * sqrt(maxf(0.0, 1.0 - pow((base - yy) / (ht * 0.95), 2.0)))
						ci.draw_line(Vector2(hc.x - hw, yy), Vector2(hc.x + hw, yy), Color(col.darkened(0.3), a), lw, true)
				"shu":
					ci.draw_line(Vector2(hc.x - bw, base), Vector2(hc.x + bw, base), Color(col2, a), lw * 1.4, true)
				_:
					for j in 2:
						var t := 0.35 + 0.3 * float(j)
						ci.draw_line(Vector2(hc.x - bw * (1.0 - t), base - ht * t), Vector2(hc.x + bw * (1.0 - t), base - ht * t),
							Color(col.darkened(0.25), a), lw, true)


## Sabre de la pastille : fourreau en diagonale (couleur de la saya), lame tirée au-dessus, tsuba et poignée ;
## les lames qui luisent ont leur halo.
func _blade_icon(ci: CanvasItem, id: String, p: Vector2, r: float, a: float) -> void:
	var saya: Color = meta.cosmetic_color("blade", id)
	var tsuka: Color = meta.cosmetic_color2("blade", id)
	var glow: Color = meta.cosmetic_glow("blade", id)
	var d := Vector2(1, -1).normalized()
	var n := Vector2(1, 1).normalized()
	var ink := Color(Toon.SUMI, a)
	# fourreau, en dessous
	var s0 := p + n * r * 0.22 - d * r * 0.62
	var s1 := s0 + d * r * 1.2
	ci.draw_line(s0, s1, ink, r * 0.25, true)
	ci.draw_line(s0, s1, Color(saya, a), r * 0.17, true)
	# lame tirée : halo, acier, tsuba, poignée
	var g := p - n * r * 0.12 - d * r * 0.38
	var tip := g + d * r * 1.12
	if glow.a > 0.0:
		ci.draw_line(g, tip, Color(glow, 0.45 * a), r * 0.3, true)
	var steel: Color = Color("#E9EEF0") if id != "kage" else Color("#6A5A88")
	ci.draw_line(g, tip, ink, r * 0.14, true)
	ci.draw_line(g, tip, Color(steel, a), r * 0.08, true)
	var hilt0 := g - d * r * 0.42
	ci.draw_line(hilt0, g, ink, r * 0.2, true)
	ci.draw_line(hilt0, g, Color(tsuka, a), r * 0.13, true)
	if id != "shirasaya":
		var fit := Color("#C49A45") if id != "same" else Color("#CBD2DA")
		ci.draw_line(g - n * r * 0.17, g + n * r * 0.17, Color(fit, a), r * 0.1, true)


## Tache d'encre (pastille de l'encre du trait).
func _blob(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var ang := TAU * float(i) / 14.0
		var rr := r * (0.82 + 0.18 * sin(ang * 3.0 + 0.6))
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	ci.draw_colored_polygon(pts, col)


## Petit coup de pinceau (encre) ou ruban de lame (sillage) à la couleur choisie.
func _sample_stroke(c: String, id: String, p: Vector2, u: float, a: float) -> void:
	var col: Color = meta.cosmetic_color(c, id)
	var p0 := p + Vector2(-22, 9) * u
	var p1 := p + Vector2(22, -5) * u
	var d := p1 - p0
	var n := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array()
	var steps := 12
	var wd := (5.5 if c == "ink" else 3.6) * u
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(p0 + d * t + n * wd * sin(PI * minf(1.0, t * 1.1)) * (1.0 - 0.5 * t))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		pts.append(p0 + d * t - n * wd * sin(PI * minf(1.0, t * 1.1)) * (1.0 - 0.5 * t))
	if c == "trail":
		draw_circle(p, 25 * u, Color(Toon.SUMI, 0.85 * a))
	if UiKit.poly_area(pts) > 1.0:
		draw_colored_polygon(pts, Color(col, a))
