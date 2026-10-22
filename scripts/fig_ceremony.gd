extends Control
## Cérémonie de nouvelle figure : après la chute du boss d'un monde (l'aller-retour au monde 1, l'ensō au 2,
## le crochet au 3), AVANT la feuille de résultats. Écran plein sumi au grain washi : NOUVELLE FIGURE, le nom de
## la figure (ALLER-RETOUR) souligné d'un coup de vermillon, le geste qui se trace au pinceau en boucle lente (le
## tracé du dojo et du carnet : UiKit.gesture_points), comment on l'a gagnée (« Uwabami vaincu »), ce qu'elle
## fait, la prochaine à gagner ; CONTINUER (ou un toucher n'importe où après 1 s) mène à la feuille de résultats.
## main : open(...), signal closed ; `&ft=` (captures) fige l'horloge du geste. Compte en temps réel (UiKit.real_delta).

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const UIColors = preload("res://scripts/ui_colors.gd")

signal closed

const INPUT_DELAY := 1.0  # un toucher n'importe où ne ferme qu'après ce délai (s)
const PERIOD := 4.8  # une boucle du geste (s) : le trait se pose en TRACE s, reste, puis s'efface
const TRACE := 3.0
const FADE_AT := 4.2  # l'encre s'efface de FADE_AT à PERIOD
const W_INK := 9.0  # largeur du trait d'encre (× u)
const GLUE := [":", ";", "!", "?", "%", "→", "·", "»"]
# kanji de chaque figure (sceau du nom) : affiché seulement si l'interface remet les sceaux (UiKit.KANJI_SEALS)
const FIG_KANJI := {"return": "返", "enso": "円", "hook": "鉤", "loop": "環", "zigzag": "雷", "straight": "一",
	"wave": "波", "point": "尖", "triangle": "三"}

var fig := ""  # figure célébrée (meta.FIG_GATES)
var how := ""  # « Uwabami vaincu »
var what := ""  # ce qu'elle fait (technique connue, sinon +40 % et une technique à découvrir)
var next_line := ""  # « Prochaine : battre Kyūbi (monde 2) », "" si toutes sont connues
var hold := -1.0  # captures (`&ft=`) : horloge du geste figée à cet instant (s)
var _t := 0.0
var _down := false
var _press := 0.0  # CONTINUER enfoncé (0..1)
var _btn := Rect2()
var _ui := FontVariation.new()
var _caps := FontVariation.new()
var _title := FontVariation.new()
var _btn_font := FontVariation.new()
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = UiKit.CAPS_SPACING
	_caps.base_font = UiKit.UI_FONT
	_caps.spacing_glyph = 3
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = UiKit.TITLE_SPACING
	_btn_font.base_font = UiKit.UI_FONT
	_btn_font.spacing_glyph = 2


## La cérémonie de la figure `kind` : comment on l'a gagnée, ce qu'elle fait, la prochaine (ou "").
func open(kind: String, how_s: String, what_s: String, nxt: String) -> void:
	fig = kind
	how = how_s
	what = what_s
	next_line = nxt
	_t = 0.0
	_down = false
	_press = 0.0
	visible = true
	queue_redraw()


## CONTINUER, un toucher après le délai, ou le retour du téléphone : la feuille de résultats suit (main).
func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Le toucher qui ferme peut déjà agir (pour le robot et les contrôles : rien avant INPUT_DELAY).
func ready_to_close() -> bool:
	return visible and _t >= INPUT_DELAY


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	accept_event()
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = true
		if _btn.has_point(mb.position):
			_press = 1.0
		return
	if not _down:
		return
	_down = false
	if _t >= INPUT_DELAY:
		close()


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	_press = maxf(0.0, _press - real * 3.0)
	queue_redraw()


func _unit() -> float:
	return minf(size.x / 400.0, size.y / 800.0)


## Horloge du geste : la cérémonie commence par le titre, le trait part 0,5 s après ; `hold` la fige (captures).
func _phase() -> float:
	if hold >= 0.0:
		return fmod(hold, PERIOD)
	return fmod(maxf(_t - 0.5, 0.0), PERIOD)


func _draw() -> void:
	if size.x < 10.0:
		return
	var u := _unit()
	var a := UiKit.ease_out(clampf(_t / 0.45, 0.0, 1.0))
	var ins := UiKit.safe_insets(size)
	var cx := size.x / 2.0
	# fond sumi au grain washi : fibres claires, un lavis pâle derrière le geste
	draw_rect(Rect2(Vector2.ZERO, size), Color(UIColors.SUMI, a))
	UiKit.fibres(self, Rect2(Vector2.ZERO, size), UIColors.WASHI, 2.6 * a, u, 5.0, 46)
	var avail := size.y - ins.x - ins.y
	var top := ins.x + maxf(0.0, (avail - 800.0 * u) / 2.0)
	var side := minf(236.0 * u, size.x - 96.0 * u)
	var frame := Rect2(Vector2(cx - side / 2.0, top + 196.0 * u), Vector2(side, side))
	draw_circle(frame.get_center(), side * 0.8, Color(UIColors.WASHI, 0.025 * a))
	# NOUVELLE FIGURE en petites capitales, puis le nom souligné d'un coup de vermillon (sceau du kanji si l'UI en garde)
	var tk := UiKit.ease_out(clampf((_t - 0.1) / 0.35, 0.0, 1.0))
	var cfs := int(UiKit.FS_LABEL * u) + 1
	UiKit.text(self, _caps, "NOUVELLE FIGURE", Vector2(cx + 1.5 * u, top + 102.0 * u + float(cfs) * 0.36 - 6.0 * u * (1.0 - tk)), cfs, Color(UIColors.WASHI, 0.68 * a * tk))
	var nk := UiKit.ease_out(clampf((_t - 0.25) / 0.4, 0.0, 1.0))
	var name := UiKit.plain(String(UiKit.FIG_WORD.get(fig, fig.to_upper())))
	var nfs := int(UiKit.FS_DISPLAY * u)
	var sp := float(_title.spacing_glyph)
	var nw := _title.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x - sp
	var maxw := size.x - 48.0 * u
	if nw > maxw:
		nfs = int(float(nfs) * maxw / nw)
		nw = _title.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x - sp
	var ny := top + 152.0 * u + 5.0 * u * (1.0 - nk)
	draw_string(_title, Vector2(cx - nw / 2.0, ny), name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(UIColors.WASHI, a * nk))
	var sk := UiKit.ease_out(clampf((_t - 0.45) / 0.45, 0.0, 1.0))
	if sk > 0.05:
		var bw := maxf(nw * 0.6, 60.0 * u)
		draw_colored_polygon(UiKit.swash_points(Rect2(Vector2(cx - bw / 2.0, ny + 7.0 * u), Vector2(bw, 8.0 * u)), sk, 5.0), Color(Toon.VERMILION, 0.95 * a))
	var kanji := String(FIG_KANJI.get(fig, ""))
	if kanji != "" and UiKit.KANJI_SEALS:
		var ks := 22.0 * u
		UiKit.seal(self, Rect2(Vector2(cx + nw / 2.0 + 10.0 * u, ny - float(nfs) * 0.36 - ks / 2.0), Vector2(ks, ks)), kanji, Toon.VERMILION, UIColors.WASHI, a * nk, u, 3.0)
	# le geste, au pinceau, dans un cadre de papier fantôme
	var fk := UiKit.ease_out(clampf((_t - 0.35) / 0.4, 0.0, 1.0))
	if fk > 0.0:
		draw_style_box(UiKit.box(_sb, Color(UIColors.WASHI, 0.06 * a * fk), int(16.0 * u), Color(UIColors.WASHI, 0.32 * a * fk), int(maxf(1.0, 1.2 * u))), frame)
		UiKit.fibres(self, frame.grow(-6.0 * u), UIColors.WASHI, 2.0 * a * fk, u, 11.0, 8)
		_draw_stroke(frame, u, a * fk)
	# comment on l'a gagnée, ce qu'elle fait, la prochaine
	var lk := UiKit.ease_out(clampf((_t - 0.55) / 0.4, 0.0, 1.0))
	var y := frame.end.y + 36.0 * u + 6.0 * u * (1.0 - lk)
	var hfs := int(UiKit.FS_HEADING * u)
	UiKit.text(self, _ui, UiKit.plain(how), Vector2(cx, y + float(hfs) * 0.36), hfs, Color(UIColors.WASHI, a * lk))
	y += 24.0 * u
	var bfs := int(UiKit.FS_BODY * u) + 1
	var lines := UiKit.wrap(_ui, UiKit.plain(what), bfs, size.x - 64.0 * u, GLUE)
	for i in mini(lines.size(), 3):
		UiKit.text(self, _ui, String(lines[i]), Vector2(cx, y + float(bfs) * 0.36), bfs, Color(UIColors.WASHI, 0.72 * a * lk))
		y += 16.0 * u
	if next_line != "":
		y += 8.0 * u
		var pk := UiKit.ease_out(clampf((_t - 0.8) / 0.4, 0.0, 1.0))
		var pfs := int(UiKit.FS_LABEL * u)
		var nxt := UiKit.plain(next_line)
		var pw := _ui.get_string_size(nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
		if pw > size.x - 48.0 * u:
			pfs = int(float(pfs) * (size.x - 48.0 * u) / pw)
		UiKit.text(self, _ui, nxt, Vector2(cx, y + float(pfs) * 0.36), pfs, Color(Toon.VERMILION.lightened(0.18), a * pk))
	# CONTINUER : pinceau washi (encre inversée sur le sumi, comme l'intro) ; un toucher n'importe où suffit aussi
	var bk := UiKit.ease_out(clampf((_t - 0.7) / 0.4, 0.0, 1.0))
	var bs := Vector2(minf(200.0 * u, size.x - 80.0 * u), 54.0 * u)
	_btn = Rect2(Vector2(cx - bs.x / 2.0, size.y - ins.y - 92.0 * u - bs.y / 2.0), bs)
	if bk > 0.0:
		var ba := a * bk
		var body := _btn.grow_individual(0.0, -_btn.size.y * 0.06 * _press, 0.0, -_btn.size.y * 0.06 * _press)
		var pts := UiKit.swash_points(body, 1.0, 1.0)
		draw_colored_polygon(Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0, 5.0 * u * (1.0 - _press))) * pts, Color(0, 0, 0, 0.35 * ba))
		draw_colored_polygon(pts, Color(UIColors.WASHI.lerp(Toon.VERMILION, 0.1 * _press), ba))
		var fs := int(14.0 * u)
		UiKit.text(self, _btn_font, "CONTINUER", _btn.get_center() + Vector2(2.0 * u, float(fs) * 0.36), fs, Color(UIColors.SUMI, ba))
		if _t >= INPUT_DELAY:
			var hk := UiKit.ease_out(clampf((_t - INPUT_DELAY) / 0.5, 0.0, 1.0))
			var hfs2 := int(UiKit.FS_CAPTION * u)
			UiKit.text(self, _ui, "ou touche l'écran", Vector2(cx, _btn.end.y + 20.0 * u + float(hfs2) * 0.36), hfs2, Color(UIColors.WASHI, 0.4 * ba * hk))


## Le trait de la figure se pose au pinceau : tracé complet en filigrane et point de départ vermillon (le sens du
## geste), puis l'encre qui avance, épaisse sous la pression et effilée à la pointe, où le pinceau se tient ; une
## fois posé, le trait reste un instant puis s'efface, et le geste reprend.
func _draw_stroke(frame: Rect2, u: float, a: float) -> void:
	var inner := frame.grow(-30.0 * u)
	var pts := UiKit.gesture_points(fig)
	if pts.size() < 2:
		return
	var mapped := PackedVector2Array()
	mapped.resize(pts.size())
	for i in pts.size():
		mapped[i] = inner.position + pts[i] * inner.size
	var ph := _phase()
	var k := clampf(ph / TRACE, 0.0, 1.0)
	k = lerpf(k, k * k * (3.0 - 2.0 * k), 0.45)  # le pinceau part et finit un peu plus doucement
	var fade := 1.0 - clampf((ph - FADE_AT) / (PERIOD - FADE_AT), 0.0, 1.0)
	draw_polyline(mapped, Color(UIColors.WASHI, 0.16 * a), maxf(1.0, 1.5 * u), true)
	draw_circle(mapped[0], 3.5 * u, Color(Toon.VERMILION, 0.9 * a))
	var total := float(pts.size() - 1)
	var fpos := k * total
	var n := int(floor(fpos))
	var frac := fpos - float(n)
	var tip: Vector2 = mapped[n] if n >= pts.size() - 1 else mapped[n].lerp(mapped[n + 1], frac)
	if fpos <= 0.01:
		return
	var w0 := W_INK * u
	var ink := Color(UIColors.WASHI, 0.95 * a * fade)
	var wet := Color(UIColors.WASHI, 0.10 * a * fade)  # bord humide, un peu plus large
	for pass_i in 2:
		var col := wet if pass_i == 0 else ink
		var scale := 1.55 if pass_i == 0 else 1.0
		for i in range(n + 1):
			var p0: Vector2 = mapped[i]
			var p1: Vector2 = mapped[i + 1] if i < n else tip
			var sa := float(i)
			var sb := minf(float(i + 1), fpos)
			if sb - sa < 0.02:
				continue
			var wa := _width(sa, fpos, total, w0) * scale
			var wb := _width(sb, fpos, total, w0) * scale
			_quad(p0, p1, wa, wb, col)
			draw_circle(p0, wa * 0.5, col)
		draw_circle(tip, _width(fpos, fpos, total, w0) * 0.5 * scale, col)
	if k < 1.0 and fade > 0.99:
		# la pointe du pinceau sur l'encre, la hampe penchée vers le haut
		var dir := Vector2(0.5, -0.866)
		UiKit.brush_line(self, tip + dir * 46.0 * u, tip + dir * 7.0 * u, 5.5 * u, Color(UIColors.WASHI, 0.5 * a))
		draw_circle(tip, 4.0 * u, Color(Toon.VERMILION, 0.9 * a))


## Largeur de l'encre au point `s` (index fractionnaire) : pression plus forte au milieu du geste, un léger
## tremblé, et l'effilé des trois derniers points avant la pointe (qui est aussi la fin du trait posé).
func _width(s: float, fpos: float, total: float, w0: float) -> float:
	var p := clampf(s / maxf(total, 1.0), 0.0, 1.0)
	var pressure := 0.62 + 0.38 * sin(PI * p)
	var wob := 1.0 + 0.10 * UiKit._wob(s * 1.7, 3.0)
	var d := fpos - s
	var taper := 1.0 if d >= 3.0 else 0.3 + 0.7 * clampf(d / 3.0, 0.0, 1.0)
	return w0 * pressure * wob * taper


## Un segment d'encre : quadrilatère de largeur wa en p0 et wb en p1.
func _quad(p0: Vector2, p1: Vector2, wa: float, wb: float, col: Color) -> void:
	var d := p1 - p0
	if d.length() < 0.05:
		return
	var nrm := Vector2(-d.y, d.x).normalized()
	draw_colored_polygon(PackedVector2Array([p0 + nrm * wa * 0.5, p1 + nrm * wb * 0.5, p1 - nrm * wb * 0.5, p0 - nrm * wa * 0.5]), col)
