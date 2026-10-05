extends Control
## Interface de jeu dessinée à la main.
## En haut : cœurs d'encre (à gauche), sceau du monde + salle + vagues (au centre), pause (à droite).
## Sous le haut : barre du boss. En bas : jauge d'élan graduée. Par-dessus : bandeaux d'annonce,
## compteur de combo, barres de vie des ennemis, voile de mort et rideau de transition.

const Toon = preload("res://scripts/toon.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const TITLE_FONT = preload("res://assets/fonts/ShipporiMincho-ExtraBold.ttf")
const UI_FONT = preload("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")

signal pause_pressed

# état fourni par main à chaque image
var hp := 5
var max_hp := 5
var elan := 1.0
var elan_m := 14.0  # longueur max du trait (graduations tous les 2 m)
var elan_empty := false
var wave := 1  # salle en cours
var rooms_total := 9
var wave_index := 1
var waves_total := 1
var show_waves := false
var gate_hint := false
var boss_name := ""
var boss_ratio := 1.0
var wipe := 0.0  # rideau d'encre de la transition entre salles (0..1)
var hurt_flash := 0.0
var dying := 0.0  # 0..1 : l'écran se délave pendant la mort
var world_kanji := "波"
var world_color := Toon.PRUSSIAN
var combo := 0
var chain := 0  # ruées réussies d'affilée sans prendre de coup
var chain_left := 1.0  # temps restant avant extinction (0..1)
var chain_mult := 1.0
var chain_break := 0.0  # éclat quand la chaîne se brise (1 -> 0)
var chain_lost := 0
var enemy_bars: Array = []  # [position écran, ratio de vie]
var in_play := false
var show_fps := false  # `?fps` dans l'adresse web
# compatibilité (anciens noms encore écrits par main)
var slow := 0.0
var game_over := false
var over_t := 0.0
var best_wave := 0

var _shown_hp := -1
var _lost: Array = []  # [index du cœur, temps]
var _combo_shown := 0
var _combo_t := 0.0
var _banner_big := ""
var _banner_small := ""
var _banner_col := Toon.SUMI
var _banner_t := -1.0
var _banner_len := 2.0
var _pause: Control
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause = InkButton.new()
	_pause.style = "round"
	_pause.icon = "pause"
	add_child(_pause)
	_pause.pressed.connect(func(): pause_pressed.emit())


## Bandeau d'annonce au centre : début de partie, nouvelle salle, boss…
## Les polices réduites n'ont pas les voyelles longues (ō, ū) : on les écrit sans macron.
static func plain(s: String) -> String:
	return s.replace("Ō", "O").replace("ō", "o").replace("Ū", "U").replace("ū", "u")


func is_over_pause(p: Vector2) -> bool:
	return _pause != null and _pause.visible and Rect2(_pause.position, _pause.size).grow(8.0).has_point(p)


func banner(big: String, small := "", col := Toon.SUMI, length := 2.0) -> void:
	_banner_big = plain(big)
	_banner_small = plain(small)
	_banner_col = col
	_banner_t = 0.0
	_banner_len = length


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	var real := _real_delta()
	_t += real
	if hurt_flash > 0.0:
		hurt_flash = maxf(0.0, hurt_flash - real * 2.5)
	# un cœur perdu : il éclate
	if _shown_hp < 0:
		_shown_hp = hp
	if hp < _shown_hp:
		for i in range(hp, _shown_hp):
			_lost.append([i, 0.0])
	_shown_hp = hp
	for l in _lost:
		l[1] = float(l[1]) + real
	_lost = _lost.filter(func(l): return float(l[1]) < 0.7)
	# combo : reste affiché un moment après la ruée
	if combo >= 2:
		_combo_shown = combo
		_combo_t = 1.2
	elif _combo_t > 0.0:
		_combo_t -= real
	chain_break = maxf(0.0, chain_break - real * 1.6)
	if _banner_t >= 0.0:
		_banner_t += real
		if _banner_t > _banner_len:
			_banner_t = -1.0
	var u := size.x / 400.0
	_pause.visible = in_play and dying <= 0.0
	_pause.size = Vector2(40, 40) * u
	_pause.position = Vector2(size.x - 54 * u, 16 * u)
	queue_redraw()


func _draw() -> void:
	var sz := size
	if sz.x < 10.0:
		return
	var u := sz.x / 400.0

	# barres de vie des ennemis touchés
	for b in enemy_bars:
		var p: Vector2 = b[0]
		var r: float = b[1]
		var bw := 30.0 * u
		var rect := Rect2(p - Vector2(bw / 2.0, 0), Vector2(bw, 5 * u))
		draw_rect(rect.grow(1.5 * u), Color(Toon.SUMI, 0.75))
		draw_rect(Rect2(rect.position, Vector2(bw * clampf(r, 0.0, 1.0), rect.size.y)), Toon.VERMILION)

	if in_play:
		_draw_hearts(u)
		_draw_chain(u)
		_draw_room(sz, u)
		_draw_gauge(sz, u)
		if boss_name != "":
			_draw_boss(sz, u)
		if gate_hint:
			_draw_gate_hint(sz, u)
		if _combo_t > 0.0 and _combo_shown >= 2:
			_draw_combo(sz, u)

	# coup reçu : liseré vermillon et coins d'encre
	if hurt_flash > 0.0:
		var hc := Color(Toon.VERMILION, 0.4 * hurt_flash)
		var hb := 16.0 * u
		draw_rect(Rect2(0, 0, sz.x, hb), hc)
		draw_rect(Rect2(0, sz.y - hb, sz.x, hb), hc)
		draw_rect(Rect2(0, 0, hb, sz.y), hc)
		draw_rect(Rect2(sz.x - hb, 0, hb, sz.y), hc)

	if _banner_t >= 0.0:
		_draw_banner(sz, u)

	# mort : l'image se délave dans le papier, une coulure d'encre descend
	if dying > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(Toon.WASHI, 0.55 * dying))
		var drip := PackedVector2Array()
		var steps := 20
		for i in steps + 1:
			var x := sz.x * float(i) / steps
			var y := sz.y * 0.22 * dying * (0.6 + 0.4 * sin(float(i) * 2.1) + 0.3 * sin(float(i) * 0.7))
			drip.append(Vector2(x, y))
		drip.append(Vector2(sz.x, 0))
		drip.append(Vector2(0, 0))
		draw_colored_polygon(drip, Color(Toon.SUMI, 0.85 * dying))

	if show_fps:
		draw_string(UI_FONT, Vector2(10 * u, sz.y - 12 * u), "%d FPS" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * u), Toon.VERMILION)

	# rideau d'encre : un grand coup de pinceau qui balaie l'écran
	if wipe > 0.001:
		var edge := sz.x * 1.4 * wipe
		var pts := PackedVector2Array()
		pts.append(Vector2(-10, -10))
		var n := 24
		for i in n + 1:
			var y := -10.0 + (sz.y + 20.0) * float(i) / n
			var jag := sin(float(i) * 1.7) * 14.0 * u + sin(float(i) * 0.6) * 22.0 * u
			pts.append(Vector2(edge - y * 0.25 + jag, y))
		pts.append(Vector2(-10, sz.y + 10))
		draw_colored_polygon(pts, Toon.SUMI)


# ------------------------------------------------------------------ éléments

## Cœur : courbe classique, encre vermillon, reflet, contour sumi.
func _heart_pts(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var t := TAU * float(i) / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(c + Vector2(x, -y) * s / 16.0)
	return pts


func _draw_hearts(u: float) -> void:
	var per_row := 6
	for i in max_hp:
		var c := Vector2(24 * u + (i % per_row) * 27 * u, 34 * u + (i / per_row) * 25 * u)
		var s := 10.5 * u
		var lost_t := -1.0
		for l in _lost:
			if int(l[0]) == i:
				lost_t = float(l[1])
		if i < hp:
			var beat := 1.0 + (0.08 * maxf(0.0, sin(_t * 6.0)) if hp == 1 else 0.0)
			var pts := _heart_pts(c, s * beat)
			draw_colored_polygon(_heart_pts(c + Vector2(0, 2.5 * u), s * beat), Color(Toon.SUMI, 0.25))
			draw_colored_polygon(pts, Toon.VERMILION)
			draw_circle(c + Vector2(-4.5, -4.0) * u * beat, 2.6 * u, Color(1, 1, 1, 0.55))
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, Toon.SUMI, 2.0 * u, true)
		elif lost_t >= 0.0:
			# il vient d'être perdu : il gonfle, se fend et part en éclats
			var k := lost_t / 0.7
			var pts2 := _heart_pts(c, s * (1.0 + 0.5 * k))
			draw_colored_polygon(pts2, Color(Toon.VERMILION, 1.0 - k))
			draw_line(c + Vector2(-2, -8) * u, c + Vector2(2, 0) * u, Color(Toon.SUMI, 1.0 - k), 2.0 * u)
			draw_line(c + Vector2(2, 0) * u, c + Vector2(-1, 8) * u, Color(Toon.SUMI, 1.0 - k), 2.0 * u)
			for j in 5:
				var a := TAU * j / 5.0
				draw_circle(c + Vector2(cos(a), sin(a)) * (6.0 + 26.0 * k) * u + Vector2(0, 30 * k * k) * u, 2.4 * u * (1.0 - k), Color(Toon.VERMILION, 1.0 - k))
		else:
			var empty := _heart_pts(c, s)
			empty.append(empty[0])
			draw_polyline(empty, Color(Toon.SUMI, 0.3), 1.8 * u, true)


## Chaîne : sous les cœurs, nombre, bonus de dégâts et jauge de temps restant ; éclat quand elle se brise.
func _draw_chain(u: float) -> void:
	var p := Vector2(14 * u, 70 * u)
	if chain >= 2:
		var tier_col := Toon.SUMI
		if chain >= 20:
			tier_col = Toon.VERMILION
		elif chain >= 10:
			tier_col = Toon.GOLD
		elif chain >= 5:
			tier_col = Toon.PRUSSIAN
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Toon.WASHI, 0.85)
		sb.set_corner_radius_all(int(8 * u))
		sb.border_color = tier_col
		sb.set_border_width_all(int(2 * u))
		var box := Rect2(p, Vector2(112, 34) * u)
		draw_style_box(sb, box)
		draw_string(UI_FONT, p + Vector2(9, 14) * u, "CHAÎNE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Color(Toon.SUMI, 0.6))
		draw_string(TITLE_FONT, p + Vector2(9, 30) * u, str(chain), HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), tier_col)
		draw_string(UI_FONT, p + Vector2(58, 27) * u, "+%d %%" % int(round((chain_mult - 1.0) * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), Color(Toon.SUMI, 0.8))
		# temps restant avant que la chaîne s'éteigne
		draw_rect(Rect2(p + Vector2(8, 31) * u, Vector2(96 * clampf(chain_left, 0.0, 1.0), 2) * u), tier_col)
	if chain_break > 0.0:
		var k := 1.0 - chain_break
		var txt := "CHAÎNE BRISÉE  %d" % chain_lost
		draw_string(UI_FONT, p + Vector2(4, 28 + 18 * k) * u, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), Color(Toon.VERMILION, chain_break))
		for j in 5:
			var a := TAU * j / 5.0
			draw_rect(Rect2(p + Vector2(56, 18) * u + Vector2(cos(a), sin(a)) * 40.0 * u * k, Vector2(6, 3) * u), Color(Toon.SUMI, chain_break))


func _draw_room(sz: Vector2, u: float) -> void:
	# sceau du monde, puis « salle x / 9 » et les vagues de la salle
	var cx := sz.x / 2.0
	var seal := Rect2(Vector2(cx - 54 * u, 15 * u), Vector2(36, 36) * u)
	var sb := StyleBoxFlat.new()
	sb.bg_color = world_color
	sb.set_corner_radius_all(int(7 * u))
	draw_style_box(sb, seal)
	var kfs := int(24 * u)
	var kw := TITLE_FONT.get_string_size(world_kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
	draw_string(TITLE_FONT, Vector2(seal.get_center().x - kw / 2.0, seal.get_center().y + kfs * 0.36), world_kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Toon.WASHI)
	var tfs := int(22 * u)
	draw_string(TITLE_FONT, Vector2(cx - 10 * u, 38 * u), str(wave), HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Toon.SUMI)
	var nw := TITLE_FONT.get_string_size(str(wave), HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	draw_string(UI_FONT, Vector2(cx - 8 * u + nw, 38 * u), "/ %d" % rooms_total, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u), Color(Toon.SUMI, 0.55))
	if show_waves and waves_total > 1 and boss_name == "":
		for i in waves_total:
			var wp := Vector2(cx - 6 * u + i * 12 * u, 50 * u)
			if i < wave_index:
				draw_rect(Rect2(wp - Vector2(4, 2) * u, Vector2(8, 4) * u), Toon.SUMI)
			else:
				draw_rect(Rect2(wp - Vector2(4, 2) * u, Vector2(8, 4) * u), Color(Toon.SUMI, 0.22))


func _draw_gauge(sz: Vector2, u: float) -> void:
	var gw := sz.x * 0.66
	var gh := 13.0 * u
	var gx := (sz.x - gw) / 2.0
	var gy := sz.y - 46.0 * u
	# goutte d'encre à gauche
	var drop := Vector2(gx - 16 * u, gy + gh / 2.0)
	draw_circle(drop + Vector2(0, 2) * u, 5.5 * u, Toon.SUMI)
	draw_colored_polygon(PackedVector2Array([drop + Vector2(-5, 1) * u, drop + Vector2(0, -9) * u, drop + Vector2(5, 1) * u]), Toon.SUMI)
	_brush_bar(Vector2(gx, gy), gw, gh, 1.0, Color(Toon.SUMI, 0.13))
	var col := Toon.SUMI
	if elan_empty:
		col = Toon.VERMILION if (Time.get_ticks_msec() / 90) % 2 == 0 else Toon.SUMI
	_brush_bar(Vector2(gx, gy), gw, gh, elan, col)
	if elan >= 0.999:
		draw_circle(Vector2(gx + gw, gy + gh / 2.0), 3.5 * u + 1.5 * u * sin(_t * 6.0), Toon.GOLD)
	# graduations : une encoche tous les 2 m de trait
	var ticks := int(elan_m / 2.0)
	for i in range(1, ticks + 1):
		var x := gx + gw * (2.0 * i / elan_m)
		if x < gx + gw - 2:
			draw_line(Vector2(x, gy - 2 * u), Vector2(x, gy + 3 * u), Color(Toon.SUMI, 0.35), 1.5 * u)


func _draw_boss(sz: Vector2, u: float) -> void:
	var bw := sz.x * 0.72
	var bx := (sz.x - bw) / 2.0
	var by := 84.0 * u
	var bfs := int(16 * u)
	var bn := plain(boss_name)
	var nw := TITLE_FONT.get_string_size(bn, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
	draw_string(TITLE_FONT, Vector2(sz.x / 2.0 - nw / 2.0, by - 7 * u), bn, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Toon.SUMI)
	# rouleau : deux baguettes et la barre d'encre vermillon
	draw_rect(Rect2(bx - 6 * u, by - 3 * u, 4 * u, 16 * u), Toon.SUMI)
	draw_rect(Rect2(bx + bw + 2 * u, by - 3 * u, 4 * u, 16 * u), Toon.SUMI)
	draw_rect(Rect2(bx, by, bw, 10 * u), Color(Toon.WASHI, 0.85))
	_brush_bar(Vector2(bx, by), bw, 10.0 * u, boss_ratio, Toon.VERMILION)


func _draw_gate_hint(sz: Vector2, u: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var ax := sz.x / 2.0
	var ay := 130.0 * u - 8.0 * u * pulse
	var arrow := PackedVector2Array([Vector2(ax, ay - 16 * u), Vector2(ax + 16 * u, ay + 6 * u), Vector2(ax + 6 * u, ay + 6 * u),
		Vector2(ax + 6 * u, ay + 22 * u), Vector2(ax - 6 * u, ay + 22 * u), Vector2(ax - 6 * u, ay + 6 * u), Vector2(ax - 16 * u, ay + 6 * u)])
	draw_colored_polygon(arrow, Color(Toon.GOLD, 0.55 + 0.4 * pulse))


func _draw_combo(sz: Vector2, u: float) -> void:
	var a := clampf(_combo_t / 0.4, 0.0, 1.0)
	var c := Vector2(sz.x - 62 * u, sz.y * 0.36)
	# tache d'encre derrière le nombre
	draw_circle(c, 34 * u, Color(Toon.SUMI, 0.85 * a))
	draw_circle(c + Vector2(22, -18) * u, 7 * u, Color(Toon.SUMI, 0.7 * a))
	draw_circle(c + Vector2(-26, 20) * u, 4 * u, Color(Toon.SUMI, 0.6 * a))
	var fs := int((34 + 3 * mini(_combo_shown, 8)) * u)
	var txt := "×%d" % _combo_shown
	var tw := TITLE_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(TITLE_FONT, Vector2(c.x - tw / 2.0, c.y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.VERMILION if _combo_shown >= 4 else Toon.WASHI, a))


func _draw_banner(sz: Vector2, u: float) -> void:
	var k_in := clampf(_banner_t / 0.3, 0.0, 1.0)
	var k_out := clampf((_banner_len - _banner_t) / 0.35, 0.0, 1.0)
	var a := minf(k_in, k_out)
	var cy := sz.y * 0.3
	# grand coup de pinceau horizontal qui traverse l'écran
	var reach := sz.x * (0.1 + 0.9 * (1.0 - pow(1.0 - k_in, 3.0)))
	var pts := PackedVector2Array()
	var n := 20
	var h := 70.0 * u if _banner_small != "" else 54.0 * u
	for i in n + 1:
		var x := reach * float(i) / n
		var th := h * (0.7 + 0.3 * sin(float(i) * 0.9)) * (0.85 + 0.15 * sin(PI * float(i) / n))
		pts.append(Vector2(x, cy - th / 2.0))
	for i in range(n, -1, -1):
		var x := reach * float(i) / n
		var th := h * (0.7 + 0.3 * sin(float(i) * 1.3 + 1.0)) * (0.85 + 0.15 * sin(PI * float(i) / n))
		pts.append(Vector2(x, cy + th / 2.0))
	draw_colored_polygon(pts, Color(_banner_col, 0.92 * a))
	var fs := int(30 * u)
	var tw := TITLE_FONT.get_string_size(_banner_big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := cy + (fs * 0.35 if _banner_small == "" else fs * 0.05)
	draw_string(TITLE_FONT, Vector2(sz.x / 2.0 - tw / 2.0, ty), _banner_big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Toon.WASHI, a))
	if _banner_small != "":
		var sfs := int(13 * u)
		var sw := UI_FONT.get_string_size(_banner_small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		draw_string(UI_FONT, Vector2(sz.x / 2.0 - sw / 2.0, cy + 24 * u), _banner_small, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(Toon.WASHI, 0.85 * a))


func _brush_bar(pos: Vector2, w: float, h: float, fill: float, c: Color) -> void:
	if fill <= 0.001:
		return
	var pts := PackedVector2Array()
	var n := 24
	var fw := w * clampf(fill, 0.0, 1.0)
	for i in n + 1:
		var k := float(i) / n
		var th := h * (0.55 + 0.45 * sin(PI * minf(1.0, k * 1.1 + 0.05)))
		pts.append(pos + Vector2(fw * k, h / 2.0 - th / 2.0))
	for i in range(n, -1, -1):
		var k := float(i) / n
		var th := h * (0.55 + 0.45 * sin(PI * minf(1.0, k * 1.1 + 0.05)))
		pts.append(pos + Vector2(fw * k, h / 2.0 + th / 2.0))
	draw_colored_polygon(pts, c)


var _last_ms := 0


## Temps réel écoulé (indépendant du ralenti et de la pause).
func _real_delta() -> float:
	var now := Time.get_ticks_msec()
	var d := 0.0 if _last_ms == 0 else (now - _last_ms) / 1000.0
	_last_ms = now
	return minf(d, 0.1)
