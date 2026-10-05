extends Control
## Choix d'un rouleau parmi trois (pouvoirs) ou d'une malédiction au sanctuaire.
## Cartes en bandeau empilées, lisibles au pouce : bande d'école avec l'idéogramme, ruban de rareté,
## niveaux, effet, affinité d'école et synergie. Épique : liseré qui pulse et reflet qui passe.
## Légendaire : carte noire et or, arrive face cachée (ensō doré) puis se retourne dans une gerbe d'or.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")

const SCHOOL_NAMES := {"火": "FEU", "水": "EAU", "雷": "FOUDRE", "風": "VENT", "影": "OMBRE", "墨": "ENCRE", "鬼": "MALÉDICTION", "道": "CHEMIN"}
const GOLD_HI := Color("#E2A93B")
const LEG_BODY := Color("#1C1A21")
const LEG_BAND := Color("#2C2632")
const CURSE_BODY := Color("#2A0E0B")
const REVEAL_AT := 0.6  # le légendaire se retourne à cet instant (s)
const REVEAL_DUR := 0.34

signal picked(id: String)
signal reroll

var rerolls := 0  # relances disponibles (Atelier : Choix, Omamori)

var _ids: Array = []
var _infos: Array = []
var _t := 0.0
var _down := -1
var _chosen := -1
var _rects: Array = []
var _reroll_rect := Rect2()
var _curse_mode := false
var _leg_index := -1  # première carte légendaire (pour le retournement), -1 sinon
var _leg_last := -1  # dernière carte légendaire
var _motes: Array = []  # poussière d'or : [x 0..1, vitesse, phase, taille]
var _ui := FontVariation.new()
var _title := FontVariation.new()
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 1
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 6


func open(ids: Array, infos: Array) -> void:
	_ids = ids
	_infos = infos
	_t = 0.0
	_down = -1
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
		elif _down >= 0 and i == _down:
			_chosen = i
			_t = 0.0
		else:
			_down = -1
		accept_event()


func _hit(p: Vector2) -> int:
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		if r.has_point(p):
			return i
	return -1


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	_t += UiKit.real_delta()
	if _chosen >= 0 and _t > 0.55:
		visible = false
		picked.emit(String(_ids[_chosen]))
	queue_redraw()


func _p(s: String) -> String:
	return UiKit.plain(s)


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
	# voile d'encre et lueur (prusse, sanctuaire, ou or pour un légendaire)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.84 * fade))
	var glow := Color("#5E1A14") if _curse_mode else Toon.PRUSSIAN
	draw_circle(Vector2(w / 2.0, h * 0.5), w * 0.75, Color(glow, 0.18 * fade))
	if leg:
		var pulse := 0.5 + 0.5 * sin(_t * 2.2)
		draw_circle(Vector2(w / 2.0, h * 0.52), w * (0.55 + 0.05 * pulse), Color(GOLD_HI, (0.07 + 0.04 * pulse) * revealed * fade))
		_draw_motes(w, h, u, revealed * fade)

	# titre
	var title := "SANCTUAIRE" if _curse_mode else "UN ROULEAU"
	var sub := "Une malédiction contre une récompense" if _curse_mode else "Choisis ton pouvoir"
	var title_col: Color = Toon.WASHI
	if leg and not _curse_mode:
		sub = "Un rouleau légendaire est apparu"
		title_col = Toon.WASHI.lerp(GOLD_HI, revealed)
	var tfs := int(30 * u)
	var ty := h * 0.1 + 18 * u - 16 * u * (1.0 - fade)
	UiKit.text(self, _title, title, Vector2(w / 2.0, ty), tfs, Color(title_col, fade))
	UiKit.text(self, _ui, _p(sub), Vector2(w / 2.0, ty + 26 * u), int(13 * u), Color(GOLD_HI if leg else Toon.WASHI, (0.85 if leg else 0.55) * fade))
	var lc: Color = Toon.VERMILION if _curse_mode else Toon.GOLD
	draw_line(Vector2(w / 2.0 - 40 * u, ty + 40 * u), Vector2(w / 2.0 + 40 * u, ty + 40 * u), Color(lc, fade), 2.0 * u)

	# cartes empilées
	var n := _infos.size()
	var top := ty + 58 * u
	var bottom := h - (78 * u if rerolls > 0 else 24 * u)
	var avail := bottom - top
	var gap := 12.0 * u
	var cw := minf(w - 28 * u, 380 * u)
	var ch := minf(172.0 * u, (avail - gap * (n - 1)) / maxf(1.0, float(n)))
	var total := ch * n + gap * (n - 1)
	var y0 := top + maxf(0.0, (avail - total) * 0.4)
	var x0 := (w - cw) / 2.0
	_rects.clear()
	for i in n:
		var info: Dictionary = _infos[i]
		var k := UiKit.ease_out((_t - 0.07 * i) / 0.42)
		var a := k * fade
		var grow := 1.0
		var dx := (1.0 - k) * w * 0.55
		if _chosen >= 0:
			if i == _chosen:
				a = 1.0
				dx = 0.0
				grow = 1.0 + 0.05 * UiKit.ease_out(_t / 0.2)
			else:
				var out := UiKit.ease_out(_t / 0.3)
				a = 1.0 - out
				dx = -out * w * 0.4
		elif _down == i:
			grow = 0.97
		var r := Rect2(Vector2(x0 + dx, y0 + i * (ch + gap)), Vector2(cw, ch))
		_rects.append(Rect2(Vector2(x0, r.position.y), r.size))
		r = Rect2(r.get_center() - r.size * grow / 2.0, r.size * grow)
		_card(r, info, u, a, i, i == _chosen)

	# relance
	_reroll_rect = Rect2()
	if rerolls > 0 and _chosen < 0 and n > 0:
		_reroll_rect = Rect2(Vector2(w / 2.0 - 80 * u, h - 66 * u), Vector2(160 * u, 44 * u))
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.25 * fade), 999, Color(Toon.WASHI, 0.7 * fade), int(1.5 * u)), _reroll_rect)
		var fs := int(13 * u)
		UiKit.text(self, _ui, "RELANCER   %d" % rerolls, Vector2(_reroll_rect.get_center().x, _reroll_rect.get_center().y + fs * 0.36), fs, Color(Toon.WASHI, fade))


## Poussière d'or qui monte derrière les cartes (présence d'un légendaire).
func _draw_motes(w: float, h: float, u: float, a: float) -> void:
	if a <= 0.01:
		return
	for m in _motes:
		var x := float(m[0]) * w + sin(_t * 0.9 + float(m[2]) * 6.0) * 10.0 * u
		var y := h - fmod(_t * float(m[1]) * h + float(m[2]) * h, h)
		var tw := 0.5 + 0.5 * sin(_t * 3.0 + float(m[2]) * 11.0)
		draw_circle(Vector2(x, y), float(m[3]) * u, Color(GOLD_HI, 0.45 * a * tw))


func _card(r: Rect2, info: Dictionary, u: float, a: float, i: int, chosen: bool) -> void:
	if a <= 0.01:
		return
	var leg := String(info.get("rarity", "")) == "legendary"
	if not leg:
		_face(r, info, u, a, i, chosen)
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
	_face(r, info, u, a, i, chosen)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# gerbe d'or juste après le retournement
	var tr := _t - _reveal_start(i) - REVEAL_DUR
	if _chosen < 0 and tr > 0.0 and tr < 0.9:
		var k := tr / 0.9
		var ea := (1.0 - k) * a
		draw_rect(Rect2(Vector2.ZERO, size), Color(GOLD_HI, 0.22 * maxf(0.0, 1.0 - tr / 0.25)))
		draw_arc(c, r.size.y * (0.5 + 0.9 * UiKit.ease_out(k)), 0.0, TAU, 48, Color(GOLD_HI, 0.8 * ea), 3.0 * u * (1.0 - k) + 1.0)
		for ray in 18:
			var ang := TAU * float(ray) / 18.0 + 0.2
			var d := Vector2(cos(ang), sin(ang))
			var r0 := r.size.y * (0.35 + 0.6 * k)
			var r1 := r0 + r.size.y * 0.35 * (1.0 - k)
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
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	draw_circle(c, r.size.y * 0.42, Color(GOLD_HI, (0.06 + 0.06 * pulse) * a))
	var k := clampf(_t / REVEAL_AT, 0.0, 1.0)
	var start := -PI * 0.5 + 0.35
	var end := start + (TAU - 0.55) * UiKit.ease_out(k)
	draw_arc(c, r.size.y * 0.3, start, end, 48, Color(GOLD_HI, a), 7.0 * u)
	draw_arc(c, r.size.y * 0.3 - 6 * u, start + 0.3, end - 0.2, 40, Color(GOLD_HI, 0.35 * a), 2.0 * u)
	# rayons qui tournent
	for ray in 12:
		var ang := _t * 0.6 + TAU * float(ray) / 12.0
		var d := Vector2(cos(ang), sin(ang))
		draw_line(c + d * r.size.y * 0.38, c + d * r.size.y * 0.47, Color(GOLD_HI, 0.3 * a), 1.5 * u)


func _face(r: Rect2, info: Dictionary, u: float, a: float, i: int, chosen: bool) -> void:
	var rank := int(info.get("rarity_rank", -1))
	var leg := rank == 3
	var col: Color = info.get("color", Toon.SUMI)
	var kanji := String(info.get("kanji", ""))
	var is_curse := kanji == "鬼"
	var rc: Color = info.get("rarity_color", Color(0, 0, 0, 0))
	var dark := leg or is_curse
	var body: Color = LEG_BODY if leg else (CURSE_BODY if is_curse else Toon.PAPER)
	var ink: Color = Toon.WASHI if dark else Toon.SUMI
	var radius := int(14 * u)
	var bw := maxf(1.0, (3.0 if rank >= 2 else 2.0) * u)
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)

	# lueur extérieure (épique, légendaire) et halo de la carte choisie
	if rank >= 2:
		for k in 3:
			var g := (4.0 + 4.0 * k) * u
			var ga := (0.26 - 0.07 * k) * a * (0.55 + 0.45 * pulse)
			draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), radius + int(g), Color(rc, ga), int(3 * u)), r.grow(g))
	if chosen:
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), radius + int(6 * u), Color(GOLD_HI if not is_curse else Toon.VERMILION, 0.95), int(3 * u)), r.grow(6 * u))
	# corps et ombre
	var border: Color = Color(rc, a) if rank >= 1 else Color(ink, 0.16 * a)
	UiKit.box(_sb, Color(body, a), radius, border, int(bw))
	_sb.shadow_color = Color(0, 0, 0, 0.45 * a)
	_sb.shadow_size = int(14 * u)
	_sb.shadow_offset = Vector2(0, 6 * u)
	draw_style_box(_sb, r)

	# bande d'école à gauche
	var band_w := minf(96.0 * u, r.size.x * 0.27)
	var band := Rect2(r.position + Vector2(bw, bw), Vector2(band_w, r.size.y - bw * 2.0))
	UiKit.box(_sb, Color(LEG_BAND if leg else col, a))
	_sb.corner_radius_top_left = maxi(0, radius - int(bw))
	_sb.corner_radius_bottom_left = maxi(0, radius - int(bw))
	draw_style_box(_sb, band)
	var bc := band.get_center()
	if leg:
		# rayons d'or qui tournent derrière l'idéogramme
		draw_circle(bc + Vector2(0, -8 * u), band_w * 0.36, Color(GOLD_HI, 0.16 * a))
		for ray in 12:
			var ang := _t * 0.5 + TAU * float(ray) / 12.0
			var d := Vector2(cos(ang), sin(ang))
			draw_line(bc + Vector2(0, -8 * u) + d * band_w * 0.22, bc + Vector2(0, -8 * u) + d * band_w * 0.46, Color(GOLD_HI, 0.3 * a), 2.0 * u)
	else:
		# vagues discrètes au bas de la bande
		for k in 3:
			var yy := band.end.y - (8 + k * 9) * u
			draw_arc(Vector2(band.position.x + band_w * 0.3, yy + 10 * u), 10 * u, PI, TAU, 10, Color(1, 1, 1, 0.08 * a), 1.5 * u)
			draw_arc(Vector2(band.position.x + band_w * 0.75, yy + 10 * u), 10 * u, PI, TAU, 10, Color(1, 1, 1, 0.08 * a), 1.5 * u)
	var kfs := int((58.0 if leg else 50.0) * u)
	var kcol: Color = GOLD_HI if leg else Toon.WASHI
	UiKit.text(self, UiKit.TITLE_FONT, kanji, Vector2(bc.x, bc.y + kfs * 0.3 - 8 * u), kfs, Color(kcol, a))
	# nom d'école sous l'idéogramme (avec l'idéogramme d'école si celui de la carte est propre au pouvoir)
	var school := String(info.get("school_name", SCHOOL_NAMES.get(kanji, "")))
	var sk := String(info.get("school_kanji", kanji))
	if school != "":
		var label := school if sk == kanji else sk + " " + school
		UiKit.text(self, _ui, _p(label), Vector2(bc.x, band.end.y - 12 * u), int(9.5 * u), Color(kcol, 0.85 * a))

	# contenu
	var cx := band.end.x + 13 * u
	var cr := r.end.x - 12 * u
	var cwid := cr - cx
	var y := r.position.y + 12 * u
	var tag_h := 17.0 * u
	var tfs := int(9.5 * u)
	# ruban de rareté (en haut à droite)
	if rank >= 0:
		var rname := String(info.get("rarity_name", ""))
		var rw := _ui.get_string_size(rname, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x + 16 * u
		var pill := Rect2(Vector2(cr - rw, y), Vector2(rw, tag_h))
		draw_style_box(UiKit.box(_sb, Color(rc, a), 999), pill)
		UiKit.text(self, _ui, rname, Vector2(pill.get_center().x, pill.position.y + tag_h * 0.5 + tfs * 0.36), tfs, Color(LEG_BODY if leg else Toon.WASHI, a))
	# nouveauté / niveau + losanges
	var lvl := int(info.get("level", -1))
	if lvl >= 0:
		var mx := int(info.get("max_level", 3))
		var is_new := bool(info.get("is_new", true))
		var tag := "UNIQUE" if mx <= 1 else ("NOUVEAU" if is_new else "NIVEAU %d" % lvl)
		var tcol: Color = GOLD_HI if (leg or is_new) else ink
		var tw := UiKit.text(self, _ui, tag, Vector2(cx + _ui.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x / 2.0, y + tag_h * 0.5 + tfs * 0.36), tfs, Color(tcol, (1.0 if is_new or leg else 0.6) * a))
		if mx > 1:
			for k in mx:
				var dc := Vector2(cx + tw + 12 * u + k * 13 * u, y + tag_h * 0.5)
				var s := 4.5 * u
				if k == lvl - 1:
					s *= 1.0 + 0.25 * pulse
				var dia := PackedVector2Array([dc + Vector2(0, -s), dc + Vector2(s, 0), dc + Vector2(0, s), dc + Vector2(-s, 0)])
				if k < lvl:
					draw_colored_polygon(dia, Color(rc if rank >= 1 else col, a) if k == lvl - 1 else Color(col, a))
				else:
					var dd := dia.duplicate()
					dd.append(dia[0])
					draw_polyline(dd, Color(ink, 0.3 * a), 1.2 * u, true)
	y += tag_h + 6 * u
	# nom
	var nfs := int(20 * u)
	var name_col: Color = GOLD_HI if leg else ink
	draw_string(UiKit.TITLE_FONT, Vector2(cx, y + nfs * 0.85), _p(String(info.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT, cwid, nfs, Color(name_col, a))
	y += nfs + 10 * u
	# effet ; pour une malédiction : malus en rouge, récompense en or
	var efs := int(12.5 * u)
	var text := _p(String(info.get("text", "")))
	var footer_y := r.end.y - 40 * u
	if text.contains("·"):
		var parts := text.split("·")
		draw_multiline_string(_ui, Vector2(cx, y + efs * 0.4), "- " + parts[0].strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, cwid, efs, 2, Color(Color("#FF8A7A") if is_curse else Toon.VERMILION, a))
		draw_multiline_string(_ui, Vector2(cx, y + efs * 0.4 + efs * 2.6), "+ " + parts[1].strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, cwid, efs, 2, Color(Toon.GOLD.lightened(0.2), a))
	else:
		var lines := 3 if rank >= 0 else 4
		draw_multiline_string(_ui, Vector2(cx, y + efs * 0.4), text, HORIZONTAL_ALIGNMENT_LEFT, cwid, efs, lines, Color(ink, 0.85 * a))
	if rank >= 0:
		_footer(Rect2(Vector2(cx, footer_y), Vector2(cwid, r.end.y - footer_y)), info, u, a, ink, col, pulse, dark)
	# reflet qui traverse la carte (épique, légendaire)
	if rank >= 2:
		_shine(r, u, a, i, Color(GOLD_HI, 0.2) if leg else Color(1, 1, 1, 0.16))


## Pied de carte : affinité d'école (jauge et bonus) puis synergie.
func _footer(f: Rect2, info: Dictionary, u: float, a: float, ink: Color, col: Color, pulse: float, dark: bool) -> void:
	var fs := int(10.5 * u)
	draw_line(f.position, Vector2(f.end.x, f.position.y), Color(ink, 0.15 * a), 1.0 * u)
	var y1 := f.position.y + 15 * u
	var y2 := y1 + 16 * u
	var goal := int(info.get("aff_goal", 0))
	var syn := _p(String(info.get("synergy", "")))
	var syn_on := bool(info.get("synergy_on", false))
	var accent: Color = GOLD_HI if dark else Color("#9A6B12")
	if goal > 0:
		var nxt := int(info.get("aff_next", 0))
		var now := int(info.get("aff", 0))
		var hit := bool(info.get("aff_hit", false))
		var label := "AFFINITÉ %s" % String(info.get("school_name", ""))
		var lw := _ui.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_ui, Vector2(f.position.x, y1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, 0.7 * a))
		# jauge : un cran par pouvoir de l'école, jusqu'au palier visé
		var gx := f.position.x + lw + 8 * u
		var cell := 9.0 * u
		for k in goal:
			var cr := Rect2(Vector2(gx + k * (cell + 3 * u), y1 - cell + 1 * u), Vector2(cell, cell * 0.8))
			var c := Color(ink, 0.18 * a)
			if k < now:
				c = Color(col.lightened(0.25) if dark else col, a)
			elif k < nxt:
				c = Color(accent, a * (0.6 + 0.4 * pulse))
			draw_rect(cr, c)
		var count := "%d/%d" % [mini(nxt, 99), goal]
		draw_string(_ui, Vector2(gx + goal * (cell + 3 * u) + 4 * u, y1), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, 0.7 * a))
		var bonus := _p(String(info.get("aff_text", "")))
		if hit:
			draw_multiline_string(_ui, Vector2(f.position.x, y2), "Bonus : " + bonus, HORIZONTAL_ALIGNMENT_LEFT, f.size.x, fs, 1, Color(accent, a))
		elif syn != "" and syn_on:
			draw_multiline_string(_ui, Vector2(f.position.x, y2), "+ " + syn, HORIZONTAL_ALIGNMENT_LEFT, f.size.x, fs, 1, Color(accent, a))
		elif nxt >= goal and goal >= 4:
			draw_multiline_string(_ui, Vector2(f.position.x, y2), "Complète : " + bonus, HORIZONTAL_ALIGNMENT_LEFT, f.size.x, fs, 1, Color(ink, 0.55 * a))
		else:
			draw_multiline_string(_ui, Vector2(f.position.x, y2), "À %d : %s" % [goal, bonus], HORIZONTAL_ALIGNMENT_LEFT, f.size.x, fs, 1, Color(ink, 0.5 * a))
	else:
		# pouvoir sans école : seulement la synergie, ou rien
		draw_string(_ui, Vector2(f.position.x, y1), "SANS ÉCOLE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, 0.5 * a))
		if syn != "":
			draw_multiline_string(_ui, Vector2(f.position.x, y2), "+ " + syn, HORIZONTAL_ALIGNMENT_LEFT, f.size.x, fs, 1, Color(accent if syn_on else ink, (1.0 if syn_on else 0.5) * a))


## Reflet en biais qui passe sur la carte toutes les ~2.5 s (découpé au rectangle de la carte).
func _shine(r: Rect2, u: float, a: float, i: int, c: Color) -> void:
	var ph := fmod(_t * 0.45 + float(i) * 0.37, 1.15)
	if ph > 1.0:
		return
	var slant := r.size.y * 0.45
	var x := lerpf(r.position.x - 40 * u, r.end.x + slant, ph)
	var wd := 26.0 * u
	var poly := PackedVector2Array([Vector2(x, r.position.y), Vector2(x + wd, r.position.y), Vector2(x + wd - slant, r.end.y), Vector2(x - slant, r.end.y)])
	var rect := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for piece in Geometry2D.intersect_polygons(poly, rect):
		var pp: PackedVector2Array = piece
		if pp.size() >= 3:
			draw_colored_polygon(pp, Color(c, c.a * a))
