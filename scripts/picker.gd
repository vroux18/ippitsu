extends Control
## Choix d'un rouleau parmi trois (pouvoirs) ou d'une malédiction au sanctuaire.
## Trois cartes hautes côte à côte, à lire d'un coup d'œil : grand médaillon (pictogramme sur la couleur
## d'école, cadre de rareté, crans de niveau), nom court, une ligne d'effet au chiffre en couleur,
## déclencheur en pictogramme, affinité en petites pastilles d'école.
## Premier toucher : la carte se lève et son détail s'ouvre dans une bulle ; second toucher (ou CHOISIR) : choisie.
## Légendaire : carte noire et or, arrive face cachée (ensō doré) puis se retourne dans une gerbe d'or.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/power_data.gd")

const GOLD_HI := Color("#E2A93B")
const LEG_BODY := Color("#1C1A21")
const CURSE_BODY := Color("#2A0E0B")
const PASS_BODY := Color("#2A2B33")
const CURSE_COL := Color("#7A1F1A")
const RED_TXT := Color("#FF8A7A")
const REVEAL_AT := 0.6  # le légendaire se retourne à cet instant (s)
const REVEAL_DUR := 0.34
const CONFIRM := 100  # cible « bouton CHOISIR »
const GLUE := [":", ";", "!", "?", "%", "→", "·"]  # jamais en début de ligne

signal picked(id: String)
signal reroll

var rerolls := 0  # relances disponibles (Atelier : Choix, Omamori)

var _ids: Array = []
var _infos: Array = []
var _t := 0.0
var _down := -1  # cible appuyée : carte, CONFIRM, ou -1
var _sel := -1  # carte levée (détail ouvert), -1 sinon
var _sel_t := 0.0
var _chosen := -1
var _rects: Array = []  # rectangles de toucher des cartes (fixes : la carte levée garde le sien)
var _confirm_rect := Rect2()
var _reroll_rect := Rect2()
var _curse_mode := false
var _leg_index := -1  # première carte légendaire (pour le retournement), -1 sinon
var _leg_last := -1  # dernière carte légendaire
var _motes: Array = []  # poussière d'or : [x 0..1, vitesse, phase, taille]
var _ui := FontVariation.new()
var _title := FontVariation.new()
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné
var _big := 40.0  # rayon du médaillon, commun aux cartes (fixé par la mise en page)
var _title_text := ""  # titre imposé (rouleau « sans une égratignure »), vide : titre ordinaire
var _sub_text := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 1
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 6


func open(ids: Array, infos: Array, title := "", sub := "") -> void:
	_ids = ids
	_infos = infos
	_title_text = title
	_sub_text = sub
	_t = 0.0
	_down = -1
	_sel = -1
	_sel_t = 0.0
	_chosen = -1
	_curse_mode = false
	_leg_index = -1
	_leg_last = -1
	for i in infos.size():
		var info: Dictionary = infos[i]
		if String(info.get("kanji", "")) == "鬼":
			_curse_mode = true
		if String(info.get("rarity", "")) == "legendary":
			if _leg_index < 0:
				_leg_index = i
			_leg_last = i
	_motes.clear()
	if _leg_index >= 0:
		for k in 26:
			_motes.append([randf(), randf_range(0.05, 0.14), randf(), randf_range(1.2, 2.8)])
	visible = true


## Instant où l'on peut choisir (après l'arrivée des cartes et le retournement du légendaire).
func _ready_time() -> float:
	if _leg_index >= 0:
		return _reveal_start(_leg_last) + REVEAL_DUR + 0.15
	return 0.5


func _reveal_start(i: int) -> float:
	return REVEAL_AT + 0.12 * float(i)


func _gui_input(event: InputEvent) -> void:
	if _chosen >= 0 or _t < _ready_time():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if rerolls > 0 and _reroll_rect.has_point(event.position):
			if not event.pressed:
				rerolls -= 1
				visible = false
				reroll.emit()
			accept_event()
			return
		var i := _hit(event.position)
		if event.pressed:
			_down = i
		elif _down != -1 and i == _down:
			if i == CONFIRM:
				_choose(_sel)
			elif i == _sel:
				_choose(i)
			else:
				# premier toucher : la carte se lève, son détail s'ouvre
				_sel = i
				_sel_t = 0.0
			_down = -1
		else:
			_down = -1
		accept_event()


func _choose(i: int) -> void:
	if i < 0 or i >= _ids.size():
		return
	_sel = i
	_chosen = i
	_t = 0.0


func _hit(p: Vector2) -> int:
	if _sel >= 0 and _confirm_rect.has_point(p):
		return CONFIRM
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		if r.has_point(p):
			return i
	return -1


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	_sel_t += real
	if _chosen >= 0 and _t > 0.55:
		visible = false
		picked.emit(String(_ids[_chosen]))
	queue_redraw()


func _p(s: String) -> String:
	return UiKit.plain(s)


func _id(i: int) -> String:
	return String(_ids[i]) if i >= 0 and i < _ids.size() else ""


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0:
		return
	var u := minf(w / 400.0, h / 760.0)
	var fade := UiKit.ease_out(_t / 0.3) if _chosen < 0 else 1.0 - UiKit.ease_out((_t - 0.25) / 0.3)
	var leg := _leg_index >= 0
	var revealed := 0.0
	if leg:
		revealed = 1.0 if _chosen >= 0 else clampf((_t - _reveal_start(_leg_index) - REVEAL_DUR * 0.5) / 0.4, 0.0, 1.0)
	# mise en page : titre, cartes ajustées à leur contenu, bulle de détail, CHOISIR et relance
	# forment un seul bloc, centré verticalement quelle que soit la hauteur de l'écran
	var n := _infos.size()
	var gap := 8.0 * u
	var side := 12.0 * u
	var cw := minf((w - 2.0 * side - gap * float(n - 1)) / maxf(1.0, float(n)), 150.0 * u)
	var s := minf(u, cw / 116.0)
	_big = minf(cw * 0.36, 44.0 * u)
	var ch := 0.0
	var bub_h := 70.0 * u  # place réservée à la bulle de détail (la mise en page ne saute pas au toucher)
	for i in n:
		ch = maxf(ch, _need_h(_infos[i], _id(i), cw, _big, s))
		bub_h = maxf(bub_h, _bubble_h(_infos[i], w - 28.0 * u, u))
	var head := 64.0 * u
	var conf_h := 46.0 * u
	var tail := 16.0 * u + bub_h + 12.0 * u + conf_h
	if rerolls > 0:
		tail += 12.0 * u + 44.0 * u
	var avail := h - 32.0 * u
	var over := head + ch + tail - avail
	if over > 0.0:
		# écran trop court : le médaillon rapetisse d'abord, puis la carte
		var cut := minf(over / 2.0, _big - 24.0 * u)
		if cut > 0.0:
			_big -= cut
			ch -= cut * 2.0
		ch = maxf(ch - maxf(0.0, head + ch + tail - avail), 120.0 * u)
	var gt := maxf(12.0 * u, (h - (head + ch + tail)) * 0.47)
	var gy := gt + 64.0 * u + ch * 0.5  # centre des cartes : la lueur les suit
	# voile d'encre et lueur (prusse, sanctuaire, ou or pour un légendaire)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.86 * fade))
	var glow := Color("#5E1A14") if _curse_mode else Toon.PRUSSIAN
	draw_circle(Vector2(w / 2.0, gy), w * 0.75, Color(glow, 0.18 * fade))
	if leg:
		var pulse := 0.5 + 0.5 * sin(_t * 2.2)
		draw_circle(Vector2(w / 2.0, gy), w * (0.55 + 0.05 * pulse), Color(GOLD_HI, (0.07 + 0.04 * pulse) * revealed * fade))
		_draw_motes(w, h, u, revealed * fade)

	# titre
	var title := "SANCTUAIRE" if _curse_mode else "UN ROULEAU"
	var sub := "Un pacte contre une récompense" if _curse_mode else "Choisis ton pouvoir"
	var title_col: Color = Toon.WASHI
	if leg and not _curse_mode:
		sub = "Un rouleau légendaire !"
		title_col = Toon.WASHI.lerp(GOLD_HI, revealed)
	if _title_text != "":
		title = _title_text
		sub = _sub_text
		title_col = GOLD_HI
	var tfs := int(28 * u)
	var ty := gt + 22.0 * u - 16 * u * (1.0 - fade)
	UiKit.text(self, _title, title, Vector2(w / 2.0, ty), tfs, Color(title_col, fade))
	UiKit.text(self, _ui, _p(sub), Vector2(w / 2.0, ty + 22 * u), int(12 * u), Color(GOLD_HI if leg else Toon.WASHI, (0.85 if leg else 0.55) * fade))

	# cartes côte à côte
	var top := gt + head
	var x0 := (w - (cw * float(n) + gap * float(n - 1))) / 2.0
	_rects.clear()
	for i in n:
		var info: Dictionary = _infos[i]
		var k := UiKit.ease_out((_t - 0.07 * i) / 0.42)
		var a := k * fade
		var grow := 1.0
		var dy := (1.0 - k) * h * 0.25
		var base := Rect2(Vector2(x0 + float(i) * (cw + gap), top), Vector2(cw, ch))
		_rects.append(base)
		if _chosen >= 0:
			if i == _chosen:
				a = 1.0
				dy = -10.0 * u
				grow = 1.0 + 0.06 * UiKit.ease_out(_t / 0.2)
			else:
				var out := UiKit.ease_out(_t / 0.3)
				a = 1.0 - out
				dy = out * h * 0.2
		elif _sel >= 0:
			if i == _sel:
				dy = -10.0 * u * UiKit.ease_out(_sel_t / 0.15)
				grow = 1.03
			else:
				a *= 0.62
		if _down == i:
			grow *= 0.97
		var r := Rect2(base.position + Vector2(0, dy), base.size)
		r = Rect2(r.get_center() - r.size * grow / 2.0, r.size * grow)
		_card(r, info, _id(i), u, a, i)

	# bulle de détail juste sous les cartes, bouton CHOISIR collé sous la bulle
	var bub := Rect2(Vector2(14.0 * u, top + ch + 16.0 * u), Vector2(w - 28.0 * u, bub_h))
	var bh := bub_h
	if _sel >= 0 and _sel < n:
		bh = minf(_bubble_h(_infos[_sel], bub.size.x, u), bub_h)
	_confirm_rect = Rect2(Vector2(w / 2.0 - 90.0 * u, bub.position.y + bh + 12.0 * u), Vector2(180.0 * u, conf_h))
	var ba := fade * (UiKit.ease_out(_sel_t / 0.2) if _chosen < 0 else 1.0)
	if _sel >= 0 and _sel < n:
		var sc: Rect2 = _rects[_sel]
		_bubble(Rect2(bub.position, Vector2(bub.size.x, bh)), _infos[_sel], _id(_sel), sc.get_center().x, u, ba)
		_confirm(u, ba)

	# relance
	_reroll_rect = Rect2()
	if rerolls > 0 and _chosen < 0 and n > 0:
		_reroll_rect = Rect2(Vector2(w / 2.0 - 80 * u, top + ch + tail - 44 * u), Vector2(160 * u, 44 * u))
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.25 * fade), 999, Color(Toon.WASHI, 0.7 * fade), int(1.5 * u)), _reroll_rect)
		var fs := int(13 * u)
		var rc := _reroll_rect.get_center()
		UiKit.glyph(self, "reroll", Vector2(_reroll_rect.position.x + 26 * u, rc.y), 9.0 * u, Toon.WASHI, UiKit.NONE, fade)
		UiKit.text(self, _ui, "RELANCER  %d" % rerolls, Vector2(rc.x + 10 * u, rc.y + fs * 0.36), fs, Color(Toon.WASHI, fade))


## Poussière d'or qui monte derrière les cartes (présence d'un légendaire).
func _draw_motes(w: float, h: float, u: float, a: float) -> void:
	if a <= 0.01:
		return
	for m in _motes:
		var x := float(m[0]) * w + sin(_t * 0.9 + float(m[2]) * 6.0) * 10.0 * u
		var y := h - fmod(_t * float(m[1]) * h + float(m[2]) * h, h)
		var tw := 0.5 + 0.5 * sin(_t * 3.0 + float(m[2]) * 11.0)
		draw_circle(Vector2(x, y), float(m[3]) * u, Color(GOLD_HI, 0.45 * a * tw))


func _card(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int) -> void:
	if a <= 0.01:
		return
	var leg := String(info.get("rarity", "")) == "legendary"
	if not leg:
		_face(r, info, id, u, a, i)
		return
	# légendaire : dos (ensō doré), retournement, puis face et gerbe d'or
	var kf := 1.0 if _chosen >= 0 else (_t - _reveal_start(i)) / REVEAL_DUR
	var c := r.get_center()
	if kf < 0.5:
		var sx := 1.0 if kf <= 0.0 else 1.0 - kf * 2.0
		draw_set_transform_matrix(_squash(c, sx))
		_back(r, u, a)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var sx2 := 1.0 if kf >= 1.0 else (kf - 0.5) * 2.0
	draw_set_transform_matrix(_squash(c, maxf(sx2, 0.02)))
	_face(r, info, id, u, a, i)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# gerbe d'or juste après le retournement
	var tr := _t - _reveal_start(i) - REVEAL_DUR
	if _chosen < 0 and tr > 0.0 and tr < 0.9:
		var k := tr / 0.9
		var ea := (1.0 - k) * a
		var dim := minf(r.size.x, r.size.y)
		draw_rect(Rect2(Vector2.ZERO, size), Color(GOLD_HI, 0.22 * maxf(0.0, 1.0 - tr / 0.25)))
		draw_arc(c, dim * (0.5 + 0.9 * UiKit.ease_out(k)), 0.0, TAU, 48, Color(GOLD_HI, 0.8 * ea), 3.0 * u * (1.0 - k) + 1.0)
		for ray in 18:
			var ang := TAU * float(ray) / 18.0 + 0.2
			var d := Vector2(cos(ang), sin(ang))
			var r0 := dim * (0.45 + 0.6 * k)
			var r1 := r0 + dim * 0.4 * (1.0 - k)
			draw_line(c + d * r0, c + d * r1, Color(GOLD_HI, 0.7 * ea), 2.0 * u)


## Écrase horizontalement autour du centre (retournement de carte).
func _squash(c: Vector2, sx: float) -> Transform2D:
	return Transform2D(Vector2(sx, 0), Vector2(0, 1), Vector2(c.x * (1.0 - sx), 0))


## Dos du légendaire : papier noir, liseré d'or, ensō doré qui se trace.
func _back(r: Rect2, u: float, a: float) -> void:
	var radius := int(14 * u)
	UiKit.box(_sb, Color(LEG_BODY, a), radius, Color(GOLD_HI, a), int(2.5 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.5 * a)
	_sb.shadow_size = int(14 * u)
	_sb.shadow_offset = Vector2(0, 6 * u)
	draw_style_box(_sb, r)
	var c := r.get_center()
	var dim := minf(r.size.x, r.size.y)
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	draw_circle(c, dim * 0.44, Color(GOLD_HI, (0.06 + 0.06 * pulse) * a))
	var k := clampf(_t / REVEAL_AT, 0.0, 1.0)
	var start := -PI * 0.5 + 0.35
	var end := start + (TAU - 0.55) * UiKit.ease_out(k)
	draw_arc(c, dim * 0.32, start, end, 48, Color(GOLD_HI, a), 6.0 * u)
	draw_arc(c, dim * 0.32 - 5 * u, start + 0.3, end - 0.2, 40, Color(GOLD_HI, 0.35 * a), 2.0 * u)
	# rayons qui tournent
	for ray in 12:
		var ang := _t * 0.6 + TAU * float(ray) / 12.0
		var d := Vector2(cos(ang), sin(ang))
		draw_line(c + d * dim * 0.4, c + d * dim * 0.48, Color(GOLD_HI, 0.3 * a), 1.5 * u)


## Face d'une carte : cadre de rareté, médaillon, nom, effet en une ligne, affinité.
func _face(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int) -> void:
	var rank := int(info.get("rarity_rank", -1))
	var leg := rank == 3
	var is_curse := String(info.get("kanji", "")) == "鬼"
	var is_pass := rank < 0 and not is_curse
	var col: Color = info.get("color", Toon.SUMI)
	var rc: Color = info.get("rarity_color", Color(0.5, 0.5, 0.5))
	var dark := leg or rank < 0
	var body: Color = LEG_BODY if leg else (CURSE_BODY if is_curse else (PASS_BODY if is_pass else Toon.PAPER))
	var ink: Color = Toon.WASHI if dark else Toon.SUMI
	var radius := int(14 * u)
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)
	var sel := i == _sel
	var s := minf(u, r.size.x / 116.0)  # échelle du contenu (cartes plus étroites sur petit écran)

	# lueur extérieure (épique, légendaire), halo de la carte levée
	if rank >= 2:
		for k in 3:
			var g := (4.0 + 4.0 * k) * u
			var ga := (0.26 - 0.07 * k) * a * (0.55 + 0.45 * pulse)
			draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), radius + int(g), Color(rc, ga), int(3 * u)), r.grow(g))
	if sel:
		var hc: Color = Toon.VERMILION if rank < 0 else GOLD_HI
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), radius + int(6 * u), Color(hc, 0.95 * a), int(3 * u)), r.grow(6 * u))
	# corps, cadre de rareté, ombre
	var frame: Color = rc if rank >= 1 else (Color(ink, 0.25) if rank == 0 else (CURSE_COL.lightened(0.2) if is_curse else Color(ink, 0.3)))
	UiKit.box(_sb, Color(body, a), radius, Color(frame, a), maxi(1, int((3.0 if rank >= 1 else 2.0) * u)))
	_sb.shadow_color = Color(0, 0, 0, 0.45 * a)
	_sb.shadow_size = int(14 * u)
	_sb.shadow_offset = Vector2(0, 6 * u)
	draw_style_box(_sb, r)

	var cx := r.get_center().x
	var big := _big
	var mc := Vector2(cx, r.position.y + 22.0 * s + big + 6.0 * s)
	# halo de la couleur d'école derrière le médaillon
	var mcol: Color = CURSE_COL if is_curse else (Color("#8C8FA8") if is_pass else col)
	for k in 3:
		draw_circle(mc, big * (1.55 - 0.18 * float(k)), Color(mcol, (0.05 + 0.03 * float(k)) * a))
	# médaillon : cadre de rareté, disque d'école, reflet, traces d'encre, pictogramme
	var ring: Color = GOLD_HI if leg else (rc if rank >= 1 else (Color("#C9BFA8") if rank == 0 else frame))
	draw_circle(mc, big + 4.0 * u, Color(ring, a))
	draw_circle(mc, big + 1.2 * u, Color(Toon.SUMI, 0.6 * a))
	draw_circle(mc, big, Color(mcol, a))
	draw_circle(mc + Vector2(0, -big * 0.2), big * 0.78, Color(mcol.lightened(0.14), 0.55 * a))
	draw_arc(mc, big * 0.86, PI * 1.1, PI * 1.55, 12, Color(1, 1, 1, 0.22 * a), 2.0 * u, true)
	draw_arc(mc + Vector2(big * 0.1, big * 0.05), big * 0.72, PI * 0.15, PI * 0.5, 10, Color(0, 0, 0, 0.12 * a), 3.0 * u, true)
	if leg:
		for ray in 10:
			var ang := _t * 0.5 + TAU * float(ray) / 10.0
			var d := Vector2(cos(ang), sin(ang))
			draw_line(mc + d * (big + 7.0 * u), mc + d * (big + 13.0 * u), Color(GOLD_HI, 0.45 * a), 2.0 * u)
	# chaque malédiction a son pictogramme (encre sèche, œil d'oni, pas lourd, hâte des morts)
	var gname := String(info.get("icon", "oni")) if is_curse else ("path" if is_pass else UiKit.icon_of(id))
	UiKit.glyph(self, gname, mc, big * 0.62, GOLD_HI if leg else Toon.WASHI, mcol, a)
	# crans de niveau sur le bas du médaillon (le nouveau pulse)
	var mx := int(info.get("max_level", 1))
	if rank >= 0 and mx > 1:
		var lv := int(info.get("level", 1))
		for k in mx:
			var dc := mc + Vector2.from_angle(PI / 2.0 + (float(k) - float(mx - 1) / 2.0) * 0.36) * (big + 3.0 * u)
			var pr := 4.2 * u
			draw_circle(dc, pr + 1.5 * u, Color(Toon.SUMI, a))
			if k < lv - 1:
				draw_circle(dc, pr, Color(Toon.WASHI, a))
			elif k == lv - 1:
				draw_circle(dc, pr * (0.85 + 0.25 * pulse), Color(GOLD_HI, a))
			else:
				draw_circle(dc, pr * 0.55, Color(Toon.WASHI, 0.25 * a))
	# rubis de rareté sur le haut du cadre, ou ruban LÉGENDAIRE
	if leg:
		var rfs := int(8 * s)
		var rt := "LÉGENDAIRE"
		var rw := _ui.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x + 14.0 * s
		var rib := Rect2(Vector2(cx - rw / 2.0, r.position.y - 7.0 * s), Vector2(rw, 14.0 * s))
		draw_style_box(UiKit.box(_sb, Color(GOLD_HI, a), int(3 * u)), rib)
		UiKit.text(self, _ui, rt, Vector2(cx, rib.position.y + 7.0 * s + rfs * 0.36), rfs, Color(LEG_BODY, a))
	elif rank >= 1:
		var gc := Vector2(cx, r.position.y)
		var gs := (5.0 + float(rank)) * u
		var gem := PackedVector2Array([gc + Vector2(0, -gs), gc + Vector2(gs, 0), gc + Vector2(0, gs), gc + Vector2(-gs, 0)])
		draw_colored_polygon(gem, Color(rc, a))
		var gl := gem.duplicate()
		gl.append(gem[0])
		draw_polyline(gl, Color(Toon.WASHI, 0.9 * a), 1.2 * u, true)
		draw_circle(gc + Vector2(-gs * 0.25, -gs * 0.3), gs * 0.22, Color(1, 1, 1, 0.6 * a))
	# déclencheur (en haut à gauche) et nouveauté / amélioration (en haut à droite)
	if rank >= 0:
		var tc := r.position + Vector2(15.0, 15.0) * s
		draw_circle(tc, 11.0 * s, Color(GOLD_HI if leg else Toon.SUMI, a))
		UiKit.trigger_icon(self, id, tc, 6.8 * s, LEG_BODY if leg else Toon.WASHI, GOLD_HI if leg else Toon.SUMI, a)
		var nc := Vector2(r.end.x - 15.0 * s, r.position.y + 15.0 * s)
		if bool(info.get("is_new", true)):
			# étoile « nouveau » (pas de draw_set_transform : le légendaire est déjà écrasé pour son retournement)
			var bob := 1.0 * s * sin(_t * 3.0 + float(i))
			UiKit.glyph(self, "star", nc + Vector2(0, 1.0 * s), 11.5 * s, Color(Toon.SUMI, 0.5), UiKit.NONE, a)
			UiKit.glyph(self, "star", nc + Vector2(0, bob), 10.5 * s, Toon.GOLD.lightened(0.15), UiKit.NONE, a)
		else:
			# flèche « amélioration »
			draw_circle(nc, 10.0 * s, Color(Color("#3FA88E"), a))
			draw_colored_polygon(PackedVector2Array([nc + Vector2(0, -6) * s, nc + Vector2(5.5, 1) * s, nc + Vector2(2, 1) * s,
				nc + Vector2(2, 6) * s, nc + Vector2(-2, 6) * s, nc + Vector2(-2, 1) * s, nc + Vector2(-5.5, 1) * s]), Color(Toon.WASHI, a))

	# nom (court, en français), une ou deux lignes
	var ny := mc.y + big + 16.0 * s
	var nm := _p(String(info.get("name", ""))) if rank < 0 else UiKit.power_label(id)
	var nfs := int(16 * s)
	var nlines := _wrap(UiKit.TITLE_FONT, nm, nfs, r.size.x - 12.0 * s)
	if nlines.size() > 1:
		nfs = int(13 * s)
		nlines = _wrap(UiKit.TITLE_FONT, nm, nfs, r.size.x - 12.0 * s)
	var name_col: Color = GOLD_HI if leg else ink
	for k in mini(nlines.size(), 2):
		ny += float(nfs) * (0.95 if k == 0 else 1.05)
		UiKit.text(self, UiKit.TITLE_FONT, nlines[k], Vector2(cx, ny), nfs, Color(name_col, a))
	# filet sous le nom
	draw_line(Vector2(cx - 14 * s, ny + 7 * s), Vector2(cx + 14 * s, ny + 7 * s), Color(GOLD_HI if dark else Toon.VERMILION, 0.8 * a), 2.0 * s)
	var ey := ny + 24.0 * s
	var efs := int(10.5 * s)
	var lh := 13.5 * s
	var tw := r.size.x - 14.0 * s
	if rank < 0:
		_curse_lines(String(info.get("text", "")), cx, ey, tw, efs, lh, a, is_curse)
		return
	# effet en une ligne, le chiffre en couleur
	var accent: Color = GOLD_HI if dark else Toon.VERMILION.darkened(0.12)
	var lines := _wrap(_ui, _short(id, info), efs, tw)
	for k in mini(lines.size(), 3):
		_rich(lines[k], cx, ey + float(k) * lh, efs, Color(ink, 0.9 * a), Color(accent, a))
	# affinité : une pastille par pouvoir de l'école, le palier en or s'il tombe maintenant
	_affinity(r, info, s, u, a, pulse, dark)
	# reflet qui traverse la carte (épique, légendaire)
	if rank >= 2:
		_shine(r, u, a, i, Color(GOLD_HI, 0.2) if leg else Color(1, 1, 1, 0.16))


## Hauteur utile d'une carte (même enchaînement que _face) : la carte s'arrête sous son contenu.
func _need_h(info: Dictionary, id: String, cw: float, big: float, s: float) -> float:
	var rank := int(info.get("rarity_rank", -1))
	var nm := _p(String(info.get("name", ""))) if rank < 0 else UiKit.power_label(id)
	var nfs := int(16 * s)
	var nlines := _wrap(UiKit.TITLE_FONT, nm, nfs, cw - 12.0 * s)
	if nlines.size() > 1:
		nfs = int(13 * s)
		nlines = _wrap(UiKit.TITLE_FONT, nm, nfs, cw - 12.0 * s)
	var y := 22.0 * s + 2.0 * big + 6.0 * s + 16.0 * s
	for k in mini(nlines.size(), 2):
		y += float(nfs) * (0.95 if k == 0 else 1.05)
	y += 24.0 * s
	var efs := int(10.5 * s)
	var lh := 13.5 * s
	var tw := cw - 14.0 * s
	if rank < 0:
		# malédiction ou « Passer » : lignes de _curse_lines, puis une marge
		var t := _p(String(info.get("text", "")))
		var curse := String(info.get("kanji", "")) == "鬼"
		var count := 0
		if t.contains("·"):
			var parts := t.split("·")
			for k in 2:
				count += mini(_wrap(_ui, _lead(k, curse) + String(parts[k]).strip_edges(), efs, tw).size(), 2)
			y += lh * 0.4
		else:
			count = mini(_wrap(_ui, t, efs, tw).size(), 3)
		return y + float(maxi(count - 1, 0)) * lh + 18.0 * s
	var m := mini(_wrap(_ui, _short(id, info), efs, tw).size(), 3)
	y += float(maxi(m - 1, 0)) * lh + 4.0 * s
	# pied : pastilles d'affinité (et la gélule BONUS au-dessus si le palier tombe)
	var goal := int(info.get("aff_goal", 0))
	var school := String(info.get("school", ""))
	if goal <= 0 or school == "" or school == "ink":
		return y + 14.0 * s
	if bool(info.get("aff_hit", false)):
		return y + 49.0 * s
	return y + 31.5 * s


## Hauteur de la bulle de détail d'une carte (même enchaînement que _bubble).
func _bubble_h(info: Dictionary, bw: float, u: float) -> float:
	var rank := int(info.get("rarity_rank", -1))
	var pad := 14.0 * u
	var body := _wrap(_ui, _p(String(info.get("text", ""))), int(11 * u), bw - pad * 2.0)
	var hgt := pad + 18.0 * u
	if rank >= 0:
		hgt += 22.0 * u
	hgt += float(mini(body.size(), 4)) * 14.5 * u + 4.0 * u
	if rank >= 0 and _p(String(info.get("stat", ""))) != "":
		hgt += 18.0 * u
	if rank >= 0 and int(info.get("aff_goal", 0)) > 0:
		if bool(info.get("aff_hit", false)) or _p(String(info.get("aff_text", ""))) != "":
			hgt += 15.0 * u
	if bool(info.get("synergy_on", false)):
		hgt += 15.0 * u
	return hgt + pad * 0.6


## Ligne courte de la carte : champ « short », valeurs du niveau proposé.
func _short(id: String, info: Dictionary) -> String:
	var d: Dictionary = Data.POWERS.get(id, {})
	var txt := String(d.get("short", info.get("sub", "")))
	var lv := int(info.get("level", 1))
	for key in ["v", "w"]:
		var tag := "{%s}" % key
		if not txt.contains(tag):
			continue
		var arr: Array = d.get(key, [])
		var val := "?"
		if not arr.is_empty():
			val = _fr(arr[clampi(lv - 1, 0, arr.size() - 1)])
		txt = txt.replace(tag, val)
	return _p(txt)


## Nombre à la française (virgule décimale).
func _fr(v) -> String:
	var f := float(v)
	if absf(f - roundf(f)) < 0.001:
		return str(int(roundf(f)))
	return str(snappedf(f, 0.01)).replace(".", ",")


## Une ligne centrée : les mots chiffrés (nombres, ×, %) en couleur et en gras.
func _rich(line: String, cx: float, y: float, fs: int, ink: Color, accent: Color) -> void:
	var words := line.split(" ", false)
	var sp := _ui.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total := sp * float(maxi(words.size() - 1, 0))
	for wd in words:
		total += _ui.get_string_size(String(wd), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := cx - total / 2.0
	for wd in words:
		var word := String(wd)
		var hot := false
		for ci in word.length():
			if "0123456789×%".contains(word[ci]):
				hot = true
		var c: Color = accent if hot else ink
		draw_string(_ui, Vector2(x, y), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		if hot:
			draw_string(_ui, Vector2(x + 0.7, y), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		x += _ui.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + sp


## Pied de carte : pastilles d'école (pleines = pouvoirs de l'école après ce choix) et « BONUS ! » s'il tombe.
func _affinity(r: Rect2, info: Dictionary, s: float, u: float, a: float, pulse: float, dark: bool) -> void:
	var goal := int(info.get("aff_goal", 0))
	var school := String(info.get("school", ""))
	if goal <= 0 or school == "" or school == "ink":
		return
	var now := mini(int(info.get("aff", 0)), goal)
	var nxt := mini(int(info.get("aff_next", 0)), goal)
	var col := UiKit.school_color(school)
	var cx := r.get_center().x
	var y := r.end.y - 15.0 * s
	var pr := 6.5 * s
	var step := 16.0 * s
	for k in goal:
		var c := Vector2(cx + (float(k) - float(goal - 1) / 2.0) * step, y)
		if k < nxt:
			var fresh := k >= now
			if fresh:
				draw_circle(c, pr + 2.0 * u + 1.0 * u * pulse, Color(GOLD_HI, a))
			draw_circle(c, pr, Color(col.lightened(0.15) if dark else col, a))
			UiKit.school_icon(self, school, c, pr * 0.62, Toon.WASHI, a)
		else:
			draw_arc(c, pr - 0.5 * u, 0.0, TAU, 18, Color(Toon.WASHI if dark else Toon.SUMI, 0.3 * a), 1.4 * u, true)
	if bool(info.get("aff_hit", false)):
		var tiers: Array = Data.AFF_TIERS
		var tier := maxi(0, tiers.find(goal))
		var shorts: Array = Data.AFF_SHORT.get(school, [])
		var bonus := "BONUS !"
		if tier < shorts.size():
			bonus += " " + _p(String(shorts[tier]))
		var bfs := int(8.5 * s)
		while bfs > 6 and _ui.get_string_size(bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x > r.size.x - 18.0 * s:
			bfs -= 1
		var bw := _ui.get_string_size(bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x + 12.0 * s
		var pill := Rect2(Vector2(cx - bw / 2.0, y - 26.0 * s), Vector2(bw, 14.0 * s))
		draw_style_box(UiKit.box(_sb, Color(GOLD_HI, a * (0.85 + 0.15 * pulse)), 999), pill)
		UiKit.text(self, _ui, bonus, Vector2(cx, pill.position.y + 7.0 * s + bfs * 0.36), bfs, Color(LEG_BODY, a))


## Début de ligne d'une carte de sanctuaire : malus « - », récompense « + » (« Passer » : pas de malus).
func _lead(k: int, is_curse: bool) -> String:
	if k == 0:
		return "- " if is_curse else ""
	return "+ "


## Malédiction (malus en rouge, récompense en or) ou « Passer » (sans pacte, petit bonus en or), centrés sur la carte.
func _curse_lines(text: String, cx: float, y: float, width: float, fs: int, lh: float, a: float, is_curse: bool) -> void:
	var t := _p(text)
	var yy := y
	if t.contains("·"):
		var parts := t.split("·")
		for k in 2:
			var c: Color = Toon.GOLD.lightened(0.25)
			if k == 0:
				c = RED_TXT if is_curse else Color(Toon.WASHI, 0.75)
			var ls := _wrap(_ui, _lead(k, is_curse) + String(parts[k]).strip_edges(), fs, width)
			for line in ls.slice(0, 2):
				UiKit.text(self, _ui, String(line), Vector2(cx, yy), fs, Color(c, a))
				yy += lh
			yy += lh * 0.4
	else:
		for line in _wrap(_ui, t, fs, width).slice(0, 3):
			UiKit.text(self, _ui, String(line), Vector2(cx, yy), fs, Color(Toon.WASHI, (0.85 if is_curse else 0.7) * a))
			yy += lh


## Bulle de détail sous les cartes : le texte complet de la carte levée (déclencheur, effet, valeur, bonus).
func _bubble(bub: Rect2, info: Dictionary, id: String, px: float, u: float, a: float) -> void:
	if a <= 0.01:
		return
	var rank := int(info.get("rarity_rank", -1))
	var pad := 14.0 * u
	var tw := bub.size.x - pad * 2.0
	var efs := int(11 * u)
	var lh := 14.5 * u
	# contenu préparé (pour la hauteur de la bulle)
	var body := _wrap(_ui, _p(String(info.get("text", ""))), efs, tw)
	if body.size() > 4:
		body = body.slice(0, 4)
	var stat := _p(String(info.get("stat", "")))
	var aff_line := ""
	var aff_on := false
	var goal := int(info.get("aff_goal", 0))
	if rank >= 0 and goal > 0:
		aff_on = bool(info.get("aff_hit", false)) or bool(info.get("aff_done", false))
		var at := _p(String(info.get("aff_text", "")))
		if bool(info.get("aff_hit", false)):
			aff_line = "BONUS D'ÉCOLE : " + at
		elif at != "":
			aff_line = "%s %d/%d : %s" % [String(info.get("school_name", "")), mini(int(info.get("aff_next", 0)), goal), goal, at]
	var syn := ""
	if bool(info.get("synergy_on", false)):
		syn = "+ " + _p(String(info.get("synergy", "")))
	var hgt := _bubble_h(info, bub.size.x, u)
	var box := Rect2(bub.position, Vector2(bub.size.x, minf(hgt, bub.size.y)))
	# papier et pointe vers la carte levée
	var tipx := clampf(px, box.position.x + 24.0 * u, box.end.x - 24.0 * u)
	draw_colored_polygon(PackedVector2Array([Vector2(tipx, box.position.y - 9.0 * u), Vector2(tipx + 10.0 * u, box.position.y + 1.0), Vector2(tipx - 10.0 * u, box.position.y + 1.0)]), Color(Toon.PAPER, 0.97 * a))
	UiKit.box(_sb, Color(Toon.PAPER, 0.97 * a), int(12 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.35 * a)
	_sb.shadow_size = int(10 * u)
	_sb.shadow_offset = Vector2(0, 4 * u)
	draw_style_box(_sb, box)
	var x := box.position.x + pad
	var y := box.position.y + pad
	var ink := Toon.SUMI
	if rank >= 0:
		# déclencheur en clair, avec son pictogramme, puis rareté et niveau
		var when := _p(String(info.get("when", "")))
		var wfs := int(8.5 * u)
		var chip_w := _ui.get_string_size(when, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs).x + 30.0 * u
		var chip := Rect2(Vector2(x, y - 2.0 * u), Vector2(chip_w, 17.0 * u))
		draw_style_box(UiKit.box(_sb, Color(Toon.SUMI, a), 999), chip)
		UiKit.trigger_icon(self, id, Vector2(chip.position.x + 10.0 * u, chip.get_center().y), 5.5 * u, Toon.WASHI, Toon.SUMI, a)
		draw_string(_ui, Vector2(chip.position.x + 20.0 * u, chip.get_center().y + wfs * 0.36), when, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, Color(Toon.WASHI, a))
		var rc: Color = info.get("rarity_color", Toon.SUMI)
		var lvl_txt := String(info.get("rarity_name", ""))
		var mx := int(info.get("max_level", 1))
		if bool(info.get("is_new", true)):
			lvl_txt += "  ·  NOUVEAU"
		elif mx > 1:
			lvl_txt += "  ·  NIVEAU %d → %d" % [int(info.get("cur_level", 0)), int(info.get("level", 1))]
		_line_fit(lvl_txt, Vector2(chip.end.x + 8.0 * u, chip.get_center().y + 3.0 * u), box.end.x - pad - chip.end.x - 8.0 * u, int(8.5 * u), Color(rc.darkened(0.15), a))
		y += 22.0 * u
	# nom japonais et sous-titre
	var nm := _p(String(info.get("name", "")))
	var nfs := int(15 * u)
	draw_string(UiKit.TITLE_FONT, Vector2(x, y + 12.0 * u), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(Toon.VERMILION.darkened(0.2) if rank < 0 else ink, a))
	var sub := _p(String(info.get("sub", "")))
	if sub != "":
		var nw := UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		_line_fit("— " + sub, Vector2(x + nw + 8.0 * u, y + 12.0 * u), tw - nw - 8.0 * u, int(10 * u), Color(ink, 0.5 * a))
	y += 18.0 * u
	# effet en clair
	for k in body.size():
		y += lh
		draw_string(_ui, Vector2(x, y), body[k], HORIZONTAL_ALIGNMENT_LEFT, -1, efs, Color(ink, 0.85 * a))
	y += 4.0 * u
	if stat != "" and rank >= 0:
		y += 18.0 * u
		_bold_fit(stat, Vector2(x, y), tw, int(12 * u), Color(Toon.VERMILION.darkened(0.12), a))
	if aff_line != "":
		y += 15.0 * u
		_line_fit(aff_line, Vector2(x, y), tw, int(9.5 * u), Color(Color("#9A6B12") if aff_on else Color(ink, 0.6), a))
	if syn != "":
		y += 15.0 * u
		_line_fit(syn, Vector2(x, y), tw, int(9.5 * u), Color(Color("#9A6B12"), a))


## Bouton CHOISIR (ACCEPTER au sanctuaire, PASSER pour refuser), sous la bulle.
func _confirm(u: float, a: float) -> void:
	if a <= 0.01 or _sel < 0 or _sel >= _infos.size():
		return
	var info: Dictionary = _infos[_sel]
	var rank := int(info.get("rarity_rank", -1))
	var is_curse := String(info.get("kanji", "")) == "鬼"
	var label := "CHOISIR"
	var col: Color = Toon.VERMILION
	if rank == 3:
		col = GOLD_HI
	elif rank < 0:
		label = "ACCEPTER" if is_curse else "PASSER"
		col = CURSE_COL.lightened(0.15) if is_curse else Color("#4A4C58")
	var r := _confirm_rect
	if _down == CONFIRM:
		r = r.grow(-2.0 * u)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_style_box(UiKit.box(_sb, Color(col, 0.25 * a * pulse), 999), r.grow(4.0 * u))
	UiKit.box(_sb, Color(col, a), 999, Color(Toon.WASHI, 0.8 * a), maxi(1, int(1.5 * u)))
	_sb.shadow_color = Color(0, 0, 0, 0.4 * a)
	_sb.shadow_size = int(8 * u)
	_sb.shadow_offset = Vector2(0, 3 * u)
	draw_style_box(_sb, r)
	var fs := int(16 * u)
	var tc: Color = LEG_BODY if rank == 3 else Toon.WASHI
	UiKit.text(self, _title, label, Vector2(r.get_center().x, r.get_center().y + fs * 0.36), fs, Color(tc, a))


## Coupe un texte en lignes qui tiennent dans `width` (mots entiers ; la ponctuation reste collée au mot).
func _wrap(font: Font, txt: String, fs: int, width: float) -> PackedStringArray:
	return UiKit.wrap(font, txt, fs, width, GLUE)


## Une ligne qui rétrécit (un peu) si elle déborde.
func _line_fit(txt: String, pos: Vector2, maxw: float, fs: int, c: Color) -> void:
	var f := fs
	while f > 6 and _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > maxw:
		f -= 1
	draw_string(_ui, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, c)


## Valeur en gras (deux passes décalées), rétrécie si elle déborde.
func _bold_fit(txt: String, pos: Vector2, maxw: float, fs: int, c: Color) -> void:
	var f := fs
	while f > 6 and _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x + 1.0 > maxw:
		f -= 1
	draw_string(_ui, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, c)
	draw_string(_ui, pos + Vector2(0.7, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, c)


## Reflet en biais qui passe sur la carte toutes les ~2.5 s (découpé au rectangle de la carte).
func _shine(r: Rect2, u: float, a: float, i: int, c: Color) -> void:
	var ph := fmod(_t * 0.45 + float(i) * 0.37, 1.15)
	if ph > 1.0:
		return
	var slant := r.size.x * 0.6
	var x := lerpf(r.position.x - 40 * u, r.end.x + slant, ph)
	var wd := 22.0 * u
	var poly := PackedVector2Array([Vector2(x, r.position.y), Vector2(x + wd, r.position.y), Vector2(x + wd - slant, r.end.y), Vector2(x - slant, r.end.y)])
	var rect := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for piece in Geometry2D.intersect_polygons(poly, rect):
		var pp: PackedVector2Array = piece
		if pp.size() >= 3 and UiKit.poly_area(pp) > 2.0:
			draw_colored_polygon(pp, Color(c, c.a * a))
