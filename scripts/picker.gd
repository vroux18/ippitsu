extends Control
## Choix d'un rouleau parmi trois (pouvoirs) ou d'une malédiction au sanctuaire.
## En haut, « TES POUVOIRS » : les pouvoirs déjà pris (couleur d'élément, niveau) ; la carte touchée (ou survolée)
## y allume ceux qu'elle améliore, renforce ou complète, reliés à elle par un trait.
## Chaque carte se lit en mots : ruban NOUVEAU / AMÉLIORATION, déclencheur nommé (figure ou pictogramme),
## médaillon et rareté en clair, niveau en texte et barre à crans, nom, valeur expliquée, élément et bonus d'élément.
## Premier toucher : la carte se lève et son détail s'ouvre dans une bulle ; second toucher (ou CHOISIR) : choisie.
## Légendaire : carte noire et or, arrive face cachée (ensō doré) puis se retourne dans une gerbe d'or.
## Les cartes arrivent en décalé : montent de sous leur place, grandissent et se posent sans rebond ; le médaillon
## « pope », le texte suit, puis un reflet unique les traverse. Un toucher pendant l'arrivée l'achève d'un coup.
## Au choix, la choisie fait un petit bond puis s'envole en s'effaçant ; les autres tombent et s'effacent.
## Toute première ouverture : une petite feuille au-dessus des cartes explique les rouleaux (COMPRIS, ou un choix).

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/power_data.gd")

const GOLD_HI := Color("#E2A93B")
const LEG_BODY := Color("#1C1A21")
const CURSE_BODY := Color("#2A0E0B")
const PASS_BODY := Color("#2A2B33")
const CURSE_COL := Color("#7A1F1A")
const RED_TXT := Color("#FF8A7A")
const UP_COL := Color("#3FA88E")  # amélioration d'un pouvoir déjà pris
const FLIP_AFTER := 0.4  # le légendaire se retourne juste après s'être posé (s après son arrivée)
const REVEAL_DUR := 0.3
const CONFIRM := 100  # cible « bouton CHOISIR »
const TIP := 101  # cible « explication des rouleaux » (COMPRIS)
const DEAL_AT := 0.03  # première carte qui arrive (s, temps réel)
const DEAL_GAP := 0.09  # décalage d'une carte à la suivante
const DEAL_DUR := 0.4  # arrivée d'une carte (montée, grandit, se pose)
const DEAL_RISE := 40.0  # elle monte de cette hauteur (× u)
const DEAL_TILT := 3.0  # inclinaison de départ (degrés), redressée à la pose
const POP_AT := 0.08  # médaillon : petit « pop » (s après le début de l'arrivée)
const POP_DUR := 0.26
const TXT_AT := 0.14  # puis le texte se fond
const TXT_DUR := 0.2
const SHEEN_AT := 0.3  # reflet unique, juste après la pose
const SHEEN_DUR := 0.5
const WOOD := Color("#5A3F2C")  # baguettes
const WOOD_CAP := Color("#2A1E17")  # embouts (jiku)
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
var _hover := -1  # carte sous la souris (liens vers TES POUVOIRS), -1 sinon
var _chosen := -1
var _rects: Array = []  # rectangles de toucher des cartes (fixes : la carte levée garde le sien)
var _confirm_rect := Rect2()
var _reroll_rect := Rect2()
var _curse_mode := false
var _leg_index := -1  # première carte légendaire (pour le retournement), -1 sinon
var _leg_last := -1  # dernière carte légendaire
var _motes: Array = []  # poussière d'or : [x 0..1, vitesse, phase, taille]
var _owned: Array = []  # pouvoirs déjà pris : [id, niveau, niveau max], par école
var _links: Array = []  # par carte : id possédé -> "up" (amélioré), "need" (technique requise), "syn" (synergie), "school"
var _owned_pos := {}  # id possédé -> centre de son icône (dernière image)
var _ui := FontVariation.new()
var _title := FontVariation.new()
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné
var _big := 36.0  # rayon du médaillon, commun aux cartes (fixé par la mise en page)
var _title_text := ""  # titre imposé (rouleau « sans une égratignure »), vide : titre ordinaire
var _sub_text := ""
var _lift: Array = []  # par carte : levée 0..1 (amortie, suit la carte touchée)
var _xf := Transform2D.IDENTITY  # transformation de la carte en cours de dessin (arrivée, levée, retournement)
var _ct := 0.0  # temps du contenu de la carte en cours de dessin (s depuis son arrivée ; grand : tout se voit)
var _raise := 0.0  # levée de la carte en cours de dessin (ombre plus large)
var _swallow := false  # relâché à ignorer (l'appui a achevé l'arrivée)
var _tip_on := false  # explication des rouleaux : place réservée dans la mise en page (première ouverture)
var _tip_gone := false  # explication fermée (COMPRIS ou choix)
var _tip_a := 0.0
var _tip_rect := Rect2()
var _tip_ex: Array = []  # exemples de déclencheurs (« DANS LE DOS = frappe de dos »…), cartes montrées d'abord


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
	_hover = -1
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
	_owned = _read_owned()
	_links.clear()
	for i in ids.size():
		_links.append(_relations(String(ids[i])))
	_owned_pos.clear()
	_swallow = false
	_lift.clear()
	for i in ids.size():
		_lift.append(0.0)
	_xf = Transform2D.IDENTITY
	_ct = 0.0
	_raise = 0.0
	# toute première ouverture d'un vrai rouleau (pas le sanctuaire) : l'explication s'affiche
	_tip_gone = false
	_tip_a = 0.0
	_tip_rect = Rect2()
	_tip_on = not _curse_mode and _tip_due()
	_tip_ex = _tip_examples() if _tip_on else []
	visible = true


## Méta (sauvegarde), lue sur le nœud de jeu parent qui porte « meta » ; null hors du jeu.
func _meta() -> Object:
	var n: Node = get_parent()
	while n != null:
		if "meta" in n:
			var cand = n.get("meta")
			if cand is Object and is_instance_valid(cand) and "scroll_tip_done" in cand:
				return cand
		n = n.get_parent()
	return null


## L'explication des rouleaux reste-t-elle à montrer ?
func _tip_due() -> bool:
	var m: Object = _meta()
	return m != null and not bool(m.get("scroll_tip_done"))


## Explication lue (COMPRIS, ou un rouleau choisi) : elle s'efface et ne reviendra plus.
func _tip_close() -> void:
	if not _tip_on or _tip_gone:
		return
	_tip_gone = true
	var m: Object = _meta()
	if m != null:
		m.set("scroll_tip_done", true)
		if m.has_method("save_data"):
			m.call("save_data")


## Déclencheurs à expliquer : ceux des cartes montrées, puis des exemples connus (dos, arrivée, figure).
func _tip_examples() -> Array:
	var out: Array = []
	var cands: Array = _ids.duplicate()
	cands.append("shadow_back")
	cands.append(String(Data.FIG_UNLOCK.get("enso", "")))
	cands.append("water_tide")
	var fig_done := false  # une seule figure en exemple
	for c in cands:
		var cid := String(c)
		var line := UiKit.trigger_hint(cid)
		if line == "" or out.has(line):
			continue
		var is_fig := UiKit.trigger_figure(cid) != ""
		if is_fig and fig_done:
			continue
		fig_done = fig_done or is_fig
		out.append(line)
	return out


## Pouvoirs déjà pris, lus sur le nœud de jeu parent qui porte « powers » : [id, niveau, niveau max], par école.
func _read_owned() -> Array:
	var out: Array = []
	var p: Object = null
	var n: Node = get_parent()
	while n != null:
		if "powers" in n:
			var cand = n.get("powers")
			if cand is Object and is_instance_valid(cand) and "levels" in cand:
				p = cand
				break
		n = n.get_parent()
	if p == null:
		return out
	var lv: Dictionary = p.get("levels")
	for sc in Data.SCHOOL_ORDER:
		for key in lv.keys():
			var sid := String(key)
			if int(lv[key]) <= 0 or not Data.POWERS.has(sid):
				continue
			var d: Dictionary = Data.POWERS[sid]
			if String(d["school"]) != String(sc):
				continue
			out.append([sid, int(lv[key]), int(d.get("max", 3))])
	return out


## Liens d'une carte avec les pouvoirs possédés : amélioration, technique requise, synergie, même élément.
func _relations(id: String) -> Dictionary:
	var out := {}
	if not Data.POWERS.has(id):
		return out
	var d: Dictionary = Data.POWERS[id]
	var school := String(d["school"])
	var needs: Array = d.get("needs", [])
	var partners: Array = []
	for syn in Data.SYNERGIES:
		if String(syn[0]) == id:
			partners.append(String(syn[1]))
		elif String(syn[1]) == id:
			partners.append(String(syn[0]))
	for o in _owned:
		var oid := String(o[0])
		if oid == id:
			out[oid] = "up"
		elif oid in needs:
			out[oid] = "need"
		elif oid in partners:
			out[oid] = "syn"
		elif school != "ink" and school != "fig" and UiKit.power_school(oid) == school:
			out[oid] = "school"
	return out


## Synergie d'une carte, en noms français : [nom du partenaire, effet, partenaire possédé ?] ([] sans synergie).
func _syn_of(id: String) -> Array:
	var best: Array = []
	for syn in Data.SYNERGIES:
		var partner := ""
		if String(syn[0]) == id:
			partner = String(syn[1])
		elif String(syn[1]) == id:
			partner = String(syn[0])
		if partner == "" or not Data.POWERS.has(partner):
			continue
		var have := false
		for o in _owned:
			if String(o[0]) == partner:
				have = true
		var row := [UiKit.power_label(partner), _p(String(syn[2])), have]
		if have:
			return row
		if best.is_empty():
			best = row
	return best


## Instant où l'on peut choisir (cartes posées, légendaire retourné) : ≈ 0.61 s pour trois cartes.
func _ready_time() -> float:
	var t := _deal_start(_ids.size() - 1) + DEAL_DUR
	if _leg_index >= 0:
		t = maxf(t, _reveal_start(_leg_last) + REVEAL_DUR + 0.1)
	return t


## Le légendaire se retourne juste après s'être posé.
func _reveal_start(i: int) -> float:
	return _deal_start(i) + FLIP_AFTER


## Début de l'arrivée de la carte i (en décalé).
func _deal_start(i: int) -> float:
	return DEAL_AT + DEAL_GAP * float(maxi(i, 0))


## Pose douce (ease-out-back léger) : 0 -> 1, dépasse de quelques % puis se pose, sans oscillation.
func _settle(k: float, s := 1.1) -> float:
	var x := clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + (s + 1.0) * x * x * x + s * x * x


## Mise à l'échelle autour d'un point (médaillon qui « pope »).
func _about(c: Vector2, s: float) -> Transform2D:
	return Transform2D(0.0, Vector2(s, s), 0.0, c * (1.0 - s))


func _gui_input(event: InputEvent) -> void:
	if _chosen >= 0:
		return
	if _t < _ready_time():
		# un appui pendant l'arrivée l'achève d'un coup (son relâché ne choisit rien)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_t = _ready_time()
			_down = -1
			_swallow = true
			accept_event()
		return
	if _swallow and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_swallow = false
		if not event.pressed:
			accept_event()
			return
	if event is InputEventMouseMotion:
		# survol (souris) : les liens de la carte s'allument dans TES POUVOIRS
		var hv := _hit(event.position)
		_hover = hv if hv >= 0 and hv < _ids.size() else -1
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
			if i == TIP:
				_tip_close()
			elif i == CONFIRM:
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
	_tip_close()


func _hit(p: Vector2) -> int:
	if _sel >= 0 and _confirm_rect.has_point(p):
		return CONFIRM
	if _tip_on and not _tip_gone and _tip_a > 0.3 and _tip_rect.has_point(p):
		return TIP
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
	# explication des rouleaux : arrive avec les cartes, s'efface une fois lue
	var tip_to := 1.0 if _tip_on and not _tip_gone and _t > 0.15 else 0.0
	_tip_a = move_toward(_tip_a, tip_to, real * 5.0)
	# levée des cartes : amortie (critique, sans rebond) vers la carte touchée
	var sm := 1.0 - exp(-real * 16.0)
	for i in _lift.size():
		var to := 1.0 if i == _sel else 0.0
		_lift[i] = lerpf(float(_lift[i]), to, sm)
	if _chosen >= 0 and _t > 0.55:
		visible = false
		picked.emit(String(_ids[_chosen]))
	queue_redraw()


func _p(s: String) -> String:
	return UiKit.plain(s)


func _id(i: int) -> String:
	return String(_ids[i]) if i >= 0 and i < _ids.size() else ""


## Taille de police d'une légende : jamais sous 11 px.
func _fs(v: float, s: float) -> int:
	return maxi(11, int(roundf(v * s)))


## Carte dont on montre les liens : la choisie, la levée, sinon celle survolée.
func _focus() -> int:
	if _chosen >= 0:
		return _chosen
	if _sel >= 0:
		return _sel
	return _hover


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
	# mise en page : titre, TES POUVOIRS, cartes ajustées à leur contenu, bulle de détail, CHOISIR et relance
	# forment un seul bloc, centré verticalement quelle que soit la hauteur de l'écran
	var n := _infos.size()
	var gap := 8.0 * u
	var side := 12.0 * u
	var cw := minf((w - 2.0 * side - gap * float(n - 1)) / maxf(1.0, float(n)), 150.0 * u)
	_big = minf(cw * 0.3, 38.0 * u)
	var ch := 0.0
	var bub_h := 70.0 * u  # place réservée à la bulle de détail (la mise en page ne saute pas au toucher)
	for i in n:
		ch = maxf(ch, _need_h(_infos[i], _id(i), cw, u, i))
		bub_h = maxf(bub_h, _bubble_h(_infos[i], _id(i), w - 28.0 * u, u))
	var strip_h := _strip_h(w, u)
	var head := 62.0 * u + strip_h + 18.0 * u
	if _tip_on:
		head += _tip_h(u) + 10.0 * u  # place gardée jusqu'à la fermeture : les cartes ne sautent pas
	var conf_h := 50.0 * u
	var tail := 16.0 * u + bub_h + 12.0 * u + conf_h
	if rerolls > 0:
		tail += 12.0 * u + 44.0 * u
	var avail := h - 32.0 * u
	var over := head + ch + tail - avail
	if over > 0.0:
		# écran trop court : le médaillon rapetisse d'abord, puis la carte
		var cut := minf(over / 2.0, _big - 22.0 * u)
		if cut > 0.0:
			_big -= cut
			ch -= cut * 2.0
		ch = maxf(ch - maxf(0.0, head + ch + tail - avail), 120.0 * u)
	var gt := maxf(12.0 * u, (h - (head + ch + tail)) * 0.47)
	var gy := gt + head + ch * 0.5  # centre des cartes : la lueur les suit
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
	UiKit.text(self, _ui, _p(sub), Vector2(w / 2.0, ty + 22 * u), _fs(12.0, u), Color(GOLD_HI if leg else Toon.WASHI, (0.85 if leg else 0.55) * fade))

	# rectangles des cartes (fixes), puis TES POUVOIRS et les liens de la carte en vue (sous les cartes)
	var top := gt + head
	var x0 := (w - (cw * float(n) + gap * float(n - 1))) / 2.0
	_rects.clear()
	for i in n:
		_rects.append(Rect2(Vector2(x0 + float(i) * (cw + gap), top), Vector2(cw, ch)))
	_draw_links(u, fade)  # positions des icônes de l'image précédente : les traits passent sous la bande
	_draw_strip(gt + 62.0 * u, w, u, fade)
	_draw_tip(gt + 62.0 * u + strip_h + 6.0 * u, w, u, fade)

	# cartes côte à côte, distribuées en décalé ; la carte levée (ou choisie) se dessine en dernier, par-dessus
	# les rectangles de toucher restent fixes : seul le dessin bouge (transformation par carte)
	var order: Array = []
	for i in n:
		if i != _sel:
			order.append(i)
	if _sel >= 0 and _sel < n:
		order.append(_sel)
	for oi in order:
		var i := int(oi)
		var info: Dictionary = _infos[i]
		var base: Rect2 = _rects[i]
		var c := base.get_center()
		var lf := float(_lift[i]) if i < _lift.size() else 0.0
		var tilt := clampf(float(i) - float(n - 1) * 0.5, -1.0, 1.0)  # -1 à gauche, 0 au centre, 1 à droite
		var lt := _t - _deal_start(i)
		var a := fade
		var sc := 1.0
		var dy := 0.0
		var rot := 0.0
		_ct = lt
		if _chosen >= 0:
			_ct = 99.0
			if i == _chosen:
				# la choisie : petit bond (1.04 -> 1.08), puis rétrécit et s'envole en s'effaçant
				var p2 := clampf((_t - 0.16) / 0.3, 0.0, 1.0)
				p2 *= p2
				sc = lerpf(1.04, 1.08, UiKit.ease_out(_t / 0.1)) - 0.2 * p2
				dy = -8.0 * u - 46.0 * u * p2
				a = 1.0 - UiKit.ease_out((_t - 0.24) / 0.24)
				lf = 1.0
				# onde d'or au bond, derrière la carte
				var rk := clampf(_t / 0.35, 0.0, 1.0)
				if rk < 1.0:
					var rc0 := c + Vector2(0, -8.0 * u)
					draw_arc(rc0, base.size.x * (0.55 + 0.45 * UiKit.ease_out(rk)), 0.0, TAU, 48, Color(GOLD_HI, 0.45 * (1.0 - rk)), (4.0 * (1.0 - rk) + 1.0) * u)
			else:
				# les autres tombent un peu et s'effacent vite
				var q := UiKit.ease_out(_t / 0.2)
				dy = 26.0 * u * q
				sc = 1.0 - 0.04 * q
				rot = deg_to_rad(2.0) * tilt * q
				a = (1.0 - q) * lerpf(0.62, 1.0, lf)
		else:
			# arrivée : monte de sous sa place, grandit (0.92 -> 1), se redresse et se pose sans rebond
			var k := lt / DEAL_DUR
			var p := _settle(k)
			a *= UiKit.ease_out(k / 0.55)
			dy = (1.0 - p) * DEAL_RISE * u
			sc = 0.92 + 0.08 * p
			rot = deg_to_rad(DEAL_TILT) * tilt * (1.0 - p)
			# repos : flottement à peine visible, une fois posée
			dy += sin(_t * 1.7 + float(i) * 2.1) * 1.5 * u * clampf((lt - DEAL_DUR) / 0.5, 0.0, 1.0)
			# carte levée : monte, grandit, ombre plus large ; les autres s'estompent
			dy -= 8.0 * u * lf
			sc *= 1.0 + 0.04 * lf
			if _sel >= 0:
				a *= lerpf(0.62, 1.0, lf)
		if _down == i:
			sc *= 0.97
		_raise = lf
		var xf := Transform2D(rot, Vector2(sc, sc), 0.0, c + Vector2(0, dy)) * Transform2D(0.0, -c)
		_card(base, info, _id(i), u, a, i, xf)
	_xf = Transform2D.IDENTITY
	_raise = 0.0

	# bulle de détail juste sous les cartes, bouton CHOISIR collé sous la bulle
	var bub := Rect2(Vector2(14.0 * u, top + ch + 16.0 * u), Vector2(w - 28.0 * u, bub_h))
	var bh := bub_h
	if _sel >= 0 and _sel < n:
		bh = minf(_bubble_h(_infos[_sel], _id(_sel), bub.size.x, u), bub_h)
	_confirm_rect = Rect2(Vector2(w / 2.0 - 105.0 * u, bub.position.y + bh + 12.0 * u), Vector2(210.0 * u, conf_h))
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
		var fs := _fs(13.0, u)
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


# ------------------------------------------------------------------ explication des rouleaux (première fois)

## Hauteur de l'explication : quatre lignes courtes.
func _tip_h(u: float) -> float:
	return 20.0 * u + 4.0 * float(_fs(11.5, u)) * 1.45


## Feuille de washi au-dessus des cartes : un rouleau = un pouvoir, le bandeau dit quand, l'élément, le niveau.
## Onglet COMPRIS sur le bord haut ; toute la feuille se touche pour la fermer.
func _draw_tip(y0: float, w: float, u: float, fade: float) -> void:
	var a := _tip_a * fade
	if not _tip_on or a <= 0.01:
		_tip_rect = Rect2()
		return
	var fs := _fs(11.5, u)
	var lh := float(fs) * 1.45
	var pad := 10.0 * u
	var box := Rect2(Vector2(14.0 * u, y0 - 6.0 * u * (1.0 - _tip_a)), Vector2(w - 28.0 * u, _tip_h(u)))
	UiKit.box(_sb, Color(Toon.ui_paper, 0.97 * a), int(10 * u), Color(GOLD_HI, 0.85 * a), maxi(1, int(1.5 * u)))
	_sb.shadow_color = Color(0, 0, 0, 0.35 * a)
	_sb.shadow_size = int(10 * u)
	_sb.shadow_offset = Vector2(0, 4 * u)
	draw_style_box(_sb, box)
	var ink: Color = Toon.ui_ink
	var accent: Color = GOLD_HI if Toon.ui_dark else Toon.VERMILION
	var x := box.position.x + pad + 10.0 * u
	var tw := box.end.x - pad - x
	# exemples de déclencheurs : autant qu'il en tient sur la ligne (au moins un)
	var when := "En haut = QUAND il agit : "
	var ex := ""
	for e in _tip_ex:
		var cand: String = String(e) if ex == "" else ex + " · " + String(e)
		if ex == "" or _ui.get_string_size(when + cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= tw:
			ex = cand
	var lines: Array = [
		"Un rouleau = un pouvoir, gardé toute la partie",
		"En bas : son élément, ou la figure à tracer",
		"Points près de l'élément : 2 du même = bonus",
		"Crans dorés : reprends-le plus tard pour le monter",
	]
	for k in lines.size():
		var by := box.position.y + pad + lh * float(k) + float(fs)
		draw_circle(Vector2(x - 8.0 * u, by - float(fs) * 0.35), 2.5 * u, Color(accent, a))
		var lf := fs
		var txt := _p(String(lines[k]))
		while lf > maxi(10, int(float(fs) * 0.8)) and _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lf).x > tw:
			lf -= 1
		draw_string(_ui, Vector2(x, by), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lf, Color(ink, 0.9 * a))
	# onglet COMPRIS, posé sur le bord haut à droite
	var cfs := _fs(11.0, u)
	var cw := _ui.get_string_size("COMPRIS", HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x + 18.0 * u
	var tab := Rect2(Vector2(box.end.x - cw - 12.0 * u, box.position.y - 10.0 * u), Vector2(cw, 20.0 * u))
	draw_style_box(UiKit.box(_sb, Color(Toon.VERMILION, a), 999, Color(Toon.SUMI, 0.5 * a), maxi(1, int(1.2 * u))), tab)
	UiKit.text(self, _ui, "COMPRIS", Vector2(tab.get_center().x, tab.get_center().y + float(cfs) * 0.36), cfs, Color(Toon.WASHI, a))
	_tip_rect = box.merge(tab).grow(6.0 * u)


# ------------------------------------------------------------------ TES POUVOIRS

## Mise en page de la bande : [rayon des icônes, pas, icônes par rangée, rangées].
func _strip_fit(w: float, u: float) -> Array:
	var n := _owned.size()
	var avail := w - 28.0 * u
	var r := 12.0 * u
	var step := 2.0 * r + 8.0 * u
	var cap := maxi(1, int(avail / step))
	if n > cap * 2:
		cap = int(ceil(float(n) / 2.0))
		step = avail / float(cap)
		r = minf(r, step * 0.4)
	var rows := 1 if n <= cap else 2
	return [r, step, cap, rows]


## Hauteur de la bande : libellé, rangées d'icônes, ligne des liens.
func _strip_h(w: float, u: float) -> float:
	var fit := _strip_fit(w, u)
	var r: float = fit[0]
	var rows: int = fit[3]
	return 16.0 * u + float(rows) * (2.0 * r + 10.0 * u) + 16.0 * u


## Bande TES POUVOIRS : icône d'élément et niveau de chaque pouvoir pris ; ceux liés à la carte en vue brillent.
func _draw_strip(y0: float, w: float, u: float, a: float) -> void:
	if a <= 0.01:
		return
	var fit := _strip_fit(w, u)
	var r: float = fit[0]
	var step: float = fit[1]
	var cap: int = fit[2]
	var rows: int = fit[3]
	var cfs := _fs(11.0, u)
	var n := _owned.size()
	var f := _focus()
	var rel := {}
	if f >= 0 and f < _links.size():
		rel = _links[f]
	# libellé et filets de part et d'autre
	var lab := "TES POUVOIRS" if n == 0 else "TES POUVOIRS  (%d)" % n
	var lw := UiKit.text(self, _ui, lab, Vector2(w / 2.0, y0 + 11.0 * u), cfs, Color(Toon.WASHI, 0.8 * a))
	var ly := y0 + 7.0 * u
	draw_line(Vector2(18.0 * u, ly), Vector2(w / 2.0 - lw / 2.0 - 8.0 * u, ly), Color(Toon.WASHI, 0.25 * a), 1.0)
	draw_line(Vector2(w / 2.0 + lw / 2.0 + 8.0 * u, ly), Vector2(w - 18.0 * u, ly), Color(Toon.WASHI, 0.25 * a), 1.0)
	var row_h := 2.0 * r + 10.0 * u
	var y := y0 + 16.0 * u
	_owned_pos.clear()
	if n == 0:
		UiKit.text(self, _ui, "Aucun pour l'instant : ce rouleau sera le premier", Vector2(w / 2.0, y + row_h * 0.5 + cfs * 0.36), cfs, Color(Toon.WASHI, 0.45 * a))
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	for k in n:
		var o: Array = _owned[k]
		var oid := String(o[0])
		var row := k / cap
		var in_row := mini(cap, n - row * cap)
		var col_i := k - row * cap
		var c := Vector2(w / 2.0 + (float(col_i) - float(in_row - 1) / 2.0) * step, y + float(row) * row_h + row_h * 0.5 - 1.0 * u)
		_owned_pos[oid] = c
		var kind := String(rel.get(oid, ""))
		var ia := a
		if f >= 0 and kind == "":
			ia *= 0.4
		# lueur du lien : or (amélioré, technique requise, synergie), couleur d'élément (même élément)
		if kind != "":
			var gc: Color = UP_COL.lightened(0.2) if kind == "up" else (GOLD_HI if kind != "school" else UiKit.school_color(UiKit.power_school(oid)).lightened(0.35))
			draw_circle(c, r + (5.0 + 2.0 * pulse) * u, Color(gc, 0.22 * a))
			draw_arc(c, r + 3.0 * u, 0.0, TAU, 28, Color(gc, a), (2.5 if kind != "school" else 1.6) * u, true)
		draw_circle(c, r + 1.5 * u, Color(Toon.SUMI, 0.7 * ia))
		UiKit.power_icon(self, oid, c, r, ia)
		# niveau : pastille chiffrée (or au niveau max)
		var lv := int(o[1])
		var mx := int(o[2])
		var bc := c + Vector2(r * 0.78, r * 0.72)
		var br := maxf(6.5 * u, float(cfs) * 0.62)
		draw_circle(bc, br + 1.2 * u, Color(Toon.WASHI, ia))
		draw_circle(bc, br, Color(GOLD_HI if lv >= mx else Toon.SUMI, ia))
		UiKit.text(self, _ui, str(lv), Vector2(bc.x, bc.y + float(cfs) * 0.36), cfs, Color(LEG_BODY if lv >= mx else Toon.WASHI, ia))
	# ligne des liens de la carte en vue (ou une consigne)
	var hy := y + float(rows) * row_h + 11.0 * u
	var hint := ""
	var hc: Color = Color(Toon.WASHI, 0.45 * a)
	if f >= 0 and f < _ids.size() and Data.POWERS.has(_id(f)):
		hint = _link_line(f)
		hc = Color(GOLD_HI, 0.95 * a)
	elif n > 0 and not _curse_mode:
		hint = "Touche un rouleau : ses liens s'allument ici"
	if hint != "":
		var hf := cfs
		while hf > 10 and _ui.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hf).x > w - 24.0 * u:
			hf -= 1
		UiKit.text(self, _ui, hint, Vector2(w / 2.0, hy), hf, hc)


## Ce que la carte i change à tes pouvoirs, en une ligne.
func _link_line(i: int) -> String:
	var id := _id(i)
	var rel: Dictionary = _links[i] if i < _links.size() else {}
	var parts: Array = []
	var syn: Array = []
	var school_n := 0
	for oid in rel.keys():
		var kind := String(rel[oid])
		if kind == "up":
			parts.append("Améliore : %s" % UiKit.power_label(String(oid)))
		elif kind == "need":
			parts.append("Renforce : %s" % UiKit.power_label(String(oid)))
		elif kind == "syn":
			syn.append(UiKit.power_label(String(oid)))
		else:
			school_n += 1
	if not syn.is_empty():
		parts.append("Synergie : " + ", ".join(PackedStringArray(syn)))
	if school_n > 0:
		var sd: Dictionary = Data.SCHOOLS.get(UiKit.power_school(id), {})
		parts.append("Élément %s : %d déjà pris" % [String(sd.get("word", "")), school_n])
	if parts.is_empty():
		return "Nouveau : aucun lien avec tes pouvoirs"
	return " · ".join(PackedStringArray(parts))


## Traits de la carte en vue vers les pouvoirs qu'elle touche (sous les cartes).
func _draw_links(u: float, a: float) -> void:
	var f := _focus()
	if f < 0 or f >= _links.size() or f >= _rects.size() or a <= 0.01:
		return
	var rel: Dictionary = _links[f]
	var cr: Rect2 = _rects[f]
	var from := Vector2(cr.get_center().x, cr.position.y + 4.0 * u)
	var la := a * (UiKit.ease_out(_sel_t / 0.25) if _sel >= 0 and _chosen < 0 else 1.0)
	for oid in rel.keys():
		if not _owned_pos.has(oid):
			continue
		var kind := String(rel[oid])
		var to: Vector2 = _owned_pos[oid]
		var gc: Color = UP_COL.lightened(0.2) if kind == "up" else (GOLD_HI if kind != "school" else UiKit.school_color(UiKit.power_school(String(oid))).lightened(0.35))
		var mid := Vector2(lerpf(from.x, to.x, 0.5), lerpf(from.y, to.y, 0.15))
		var pts := PackedVector2Array()
		for k in 17:
			var t := float(k) / 16.0
			pts.append(from.lerp(mid, t).lerp(mid.lerp(to + Vector2(0, 14.0 * u), t), t))
		draw_polyline(pts, Color(gc, (0.75 if kind != "school" else 0.45) * la), (2.4 if kind != "school" else 1.4) * u, true)


# ------------------------------------------------------------------ cartes

## Une carte : r = rectangle final (au repos), xf = transformation du moment (arrivée, levée, choix).
func _card(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int, xf: Transform2D) -> void:
	if a <= 0.01:
		return
	var leg := String(info.get("rarity", "")) == "legendary"
	if not leg:
		_xf = xf
		draw_set_transform_matrix(_xf)
		_face(r, info, id, u, a, i)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	# légendaire : dos (ensō doré), retournement, puis face et gerbe d'or
	var kf := 1.0 if _chosen >= 0 else (_t - _reveal_start(i)) / REVEAL_DUR
	var c := r.get_center()
	if kf < 0.5:
		var sx := 1.0 if kf <= 0.0 else 1.0 - kf * 2.0
		_xf = xf * _squash(c, sx)
		draw_set_transform_matrix(_xf)
		_back(r, u, a, i)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	# le contenu de la face paraît pendant la seconde moitié du retournement
	if _chosen < 0:
		_ct = _t - _reveal_start(i) - REVEAL_DUR * 0.5 + 0.06
	var sx2 := 1.0 if kf >= 1.0 else (kf - 0.5) * 2.0
	_xf = xf * _squash(c, maxf(sx2, 0.02))
	draw_set_transform_matrix(_xf)
	_face(r, info, id, u, a, i)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# gerbe d'or juste après le retournement (centre à l'écran)
	var tr := _t - _reveal_start(i) - REVEAL_DUR
	if _chosen < 0 and tr > 0.0 and tr < 0.9:
		var k := tr / 0.9
		var ea := (1.0 - k) * a
		var dim := minf(r.size.x, r.size.y)
		var cs := xf * c
		draw_rect(Rect2(Vector2.ZERO, size), Color(GOLD_HI, 0.22 * maxf(0.0, 1.0 - tr / 0.25)))
		draw_arc(cs, dim * (0.5 + 0.9 * UiKit.ease_out(k)), 0.0, TAU, 48, Color(GOLD_HI, 0.8 * ea), 3.0 * u * (1.0 - k) + 1.0)
		for ray in 18:
			var ang := TAU * float(ray) / 18.0 + 0.2
			var d := Vector2(cos(ang), sin(ang))
			var r0 := dim * (0.45 + 0.6 * k)
			var r1 := r0 + dim * 0.4 * (1.0 - k)
			draw_line(cs + d * r0, cs + d * r1, Color(GOLD_HI, 0.7 * ea), 2.0 * u)


## Couleur du papier d'une carte (washi, noir du légendaire, sanctuaire, « Passer »).
func _body_col(info: Dictionary) -> Color:
	var rank := int(info.get("rarity_rank", -1))
	if rank == 3:
		return LEG_BODY
	if String(info.get("kanji", "")) == "鬼":
		return CURSE_BODY
	if rank < 0:
		return PASS_BODY
	return Toon.ui_paper


## Fine baguette de bois sombre et ses embouts (jiku), de x0 à x1 à la hauteur y (embouts dans la carte).
func _rod(x0_in: float, x1_in: float, y: float, u: float, a: float) -> void:
	# embouts dans la largeur de la carte : les baguettes de deux cartes voisines ne se touchent pas
	var x0 := x0_in + 3.0 * u
	var x1 := x1_in - 3.0 * u
	var rh := 1.6 * u
	draw_rect(Rect2(Vector2(x0, y - rh), Vector2(x1 - x0, rh * 2.0)), Color(WOOD, a))
	draw_line(Vector2(x0, y - rh * 0.45), Vector2(x1, y - rh * 0.45), Color(WOOD.lightened(0.35), 0.6 * a), maxf(1.0, 0.7 * u))
	for ex in [x0, x1]:
		var cap := Rect2(Vector2(float(ex) - 2.5 * u, y - 3.5 * u), Vector2(5.0 * u, 7.0 * u))
		draw_style_box(UiKit.box(_sb, Color(WOOD_CAP, a), maxi(1, int(2.0 * u)), Color(GOLD_HI, 0.55 * a), maxi(1, int(1.0 * u))), cap)


## Écrase horizontalement autour du centre (retournement de carte).
func _squash(c: Vector2, sx: float) -> Transform2D:
	return Transform2D(Vector2(sx, 0), Vector2(0, 1), Vector2(c.x * (1.0 - sx), 0))


## Dos du légendaire : papier noir, liseré d'or, ensō doré qui se trace pendant l'arrivée.
func _back(r: Rect2, u: float, a: float, i: int) -> void:
	var radius := int(14 * u)
	UiKit.box(_sb, Color(LEG_BODY, a), radius, Color(GOLD_HI, a), int(2.5 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.5 * a)
	_sb.shadow_size = int(14 * u)
	_sb.shadow_offset = Vector2(0, 6 * u)
	draw_style_box(_sb, r)
	_rod(r.position.x, r.end.x, r.position.y + 1.0 * u, u, a)
	var c := r.get_center()
	var dim := minf(r.size.x, r.size.y)
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	draw_circle(c, dim * 0.44, Color(GOLD_HI, (0.06 + 0.06 * pulse) * a))
	var k := clampf((_t - _deal_start(i) - 0.05) / (FLIP_AFTER - 0.05), 0.0, 1.0)
	var start := -PI * 0.5 + 0.35
	var end := start + (TAU - 0.55) * UiKit.ease_out(k)
	draw_arc(c, dim * 0.32, start, end, 48, Color(GOLD_HI, a), 6.0 * u)
	draw_arc(c, dim * 0.32 - 5 * u, start + 0.3, end - 0.2, 40, Color(GOLD_HI, 0.35 * a), 2.0 * u)
	# rayons qui tournent
	for ray in 12:
		var ang := _t * 0.6 + TAU * float(ray) / 12.0
		var d := Vector2(cos(ang), sin(ang))
		draw_line(c + d * dim * 0.4, c + d * dim * 0.48, Color(GOLD_HI, 0.3 * a), 1.5 * u)


## Face d'une carte : lueur de rareté, halo de sélection, corps et cadre, puis le contenu et le reflet d'arrivée.
func _face(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int) -> void:
	var rank := int(info.get("rarity_rank", -1))
	var leg := rank == 3
	var is_curse := String(info.get("kanji", "")) == "鬼"
	var rc: Color = info.get("rarity_color", Color(0.5, 0.5, 0.5))
	var dark := leg or rank < 0
	var body := _body_col(info)
	var ink: Color = Toon.WASHI if dark else Toon.ui_ink
	var radius := int(14 * u)
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)
	# lueur extérieure (épique, légendaire), halo de la carte levée
	if rank >= 2:
		for k in 3:
			var g := (4.0 + 4.0 * k) * u
			var ga := (0.26 - 0.07 * k) * a * (0.55 + 0.45 * pulse)
			draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), radius + int(g), Color(rc, ga), int(3 * u)), r.grow(g))
	if i == _sel and _raise > 0.01:
		var hc: Color = Toon.VERMILION if rank < 0 else GOLD_HI
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), radius + int(6 * u), Color(hc, 0.95 * a * _raise), int(3 * u)), r.grow(6 * u))
	# corps, cadre de rareté, ombre (plus large et plus basse quand la carte est levée)
	var frame: Color = rc if rank >= 1 else (Color(ink, 0.25) if rank == 0 else (CURSE_COL.lightened(0.2) if is_curse else Color(ink, 0.3)))
	UiKit.box(_sb, Color(body, a), radius, Color(frame, a), maxi(1, int((3.0 if rank >= 1 else 2.0) * u)))
	_sb.shadow_color = Color(0, 0, 0, (0.45 + 0.1 * _raise) * a)
	_sb.shadow_size = int((14.0 + 8.0 * _raise) * u)
	_sb.shadow_offset = Vector2(0, (6.0 + 6.0 * _raise) * u)
	draw_style_box(_sb, r)
	# fine baguette du haut (le ruban NOUVEAU s'y accroche, dessiné par-dessus)
	_rod(r.position.x, r.end.x, r.position.y + 1.0 * u, u, a)
	_content(r, info, id, u, a, i, true)
	# reflet unique juste après la pose : plus franc (et doré au légendaire) dès la rareté rare
	var sk := (_ct - SHEEN_AT) / SHEEN_DUR
	if _chosen < 0 and sk > 0.0 and sk < 1.0:
		var sa := 0.12 if rank <= 0 else (0.18 if rank < 3 else 0.24)
		_shine(r, u, a, sk, Color(GOLD_HI.lightened(0.35), sa) if leg else Color(1, 1, 1, sa), rank >= 1)


## Hauteur utile d'une carte (le contenu mesuré sans être dessiné) : la carte s'arrête sous son contenu.
func _need_h(info: Dictionary, id: String, cw: float, u: float, i: int) -> float:
	return _content(Rect2(Vector2.ZERO, Vector2(cw, 2000.0)), info, id, u, 0.0, i, false)


## Contenu d'une carte, de haut en bas : ruban NOUVEAU / AMÉLIORATION, déclencheur nommé, médaillon et rareté,
## niveau, nom, valeur expliquée, élément et bonus d'élément. really = false : mesure seulement.
## Renvoie la hauteur occupée depuis le haut de la carte.
func _content(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int, really: bool) -> float:
	var rank := int(info.get("rarity_rank", -1))
	var leg := rank == 3
	var is_curse := String(info.get("kanji", "")) == "鬼"
	var is_pass := rank < 0 and not is_curse
	var dark := leg or rank < 0
	var ink: Color = Toon.WASHI if dark else Toon.ui_ink
	var col: Color = info.get("color", Toon.SUMI)
	var rc: Color = info.get("rarity_color", Color(0.5, 0.5, 0.5))
	var s := minf(u, r.size.x / 116.0)  # échelle du contenu (cartes plus étroites sur petit écran)
	var cx := r.position.x + r.size.x / 2.0
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)
	var cap := _fs(11.0, s)
	var y := r.position.y + 14.0 * s
	# apparition du contenu : le médaillon « pope » (petit rebond d'échelle), puis le texte se fond
	var pk := (_ct - POP_AT) / POP_DUR
	var ma := a * UiKit.ease_out(pk / 0.4)
	var ta := a * UiKit.ease_out((_ct - TXT_AT) / TXT_DUR)

	# ruban sur le bord haut : NOUVEAU, ou AMÉLIORATION d'un pouvoir déjà pris
	if rank >= 0 and really:
		var is_new := bool(info.get("is_new", true))
		# étiquette discrète : petit cartouche cerné, posé sur la baguette (une amélioration dit son niveau)
		var rt := "NOUVEAU" if is_new else "NIV %d → %d" % [int(info.get("cur_level", 0)), int(info.get("level", 1))]
		var rcol: Color = GOLD_HI if leg else (Toon.VERMILION if is_new else UP_COL)
		var rbg: Color = LEG_BODY if leg else (Color("#2A2522") if Toon.ui_dark else Toon.ui_paper)
		var rf := maxi(9, cap - 2)
		while rf > 9 and _ui.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rf).x > r.size.x - 30.0 * s:
			rf -= 1
		var rw := _ui.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rf).x + 12.0 * s
		var rib := Rect2(Vector2(cx - rw / 2.0, r.position.y - 7.0 * s), Vector2(rw, 14.0 * s))
		var ka := ta
		draw_style_box(UiKit.box(_sb, Color(rbg, ka), 999, Color(rcol, 0.85 * ka), maxi(1, int(1.2 * s))), rib)
		UiKit.text(self, _ui, rt, Vector2(cx, rib.get_center().y + float(rf) * 0.36), rf, Color(rcol, ka))

	# plus de pastille de déclencheur : la carte reste sobre (la figure d'une technique est dans le pied)
	y += 8.0 * s

	# médaillon : cadre de rareté, disque d'élément, reflet, traces d'encre, pictogramme
	var big := _big
	var mc := Vector2(cx, y + big + 4.0 * u)
	if really:
		var ka := ma
		draw_set_transform_matrix(_xf * _about(mc, 0.55 + 0.45 * _settle(pk, 1.7)))
		var mcol: Color = CURSE_COL if is_curse else (Color("#8C8FA8") if is_pass else col)
		var frame: Color = rc if rank >= 1 else (Color(ink, 0.25) if rank == 0 else (CURSE_COL.lightened(0.2) if is_curse else Color(ink, 0.3)))
		for k in 3:
			draw_circle(mc, big * (1.55 - 0.18 * float(k)), Color(mcol, (0.05 + 0.03 * float(k)) * ka))
		var ring: Color = GOLD_HI if leg else (rc if rank >= 1 else (Color("#C9BFA8") if rank == 0 else frame))
		draw_circle(mc, big + 4.0 * u, Color(ring, ka))
		draw_circle(mc, big + 1.2 * u, Color(Toon.SUMI, 0.6 * ka))
		draw_circle(mc, big, Color(mcol, ka))
		draw_circle(mc + Vector2(0, -big * 0.2), big * 0.78, Color(mcol.lightened(0.14), 0.55 * ka))
		draw_arc(mc, big * 0.86, PI * 1.1, PI * 1.55, 12, Color(1, 1, 1, 0.22 * ka), 2.0 * u, true)
		draw_arc(mc + Vector2(big * 0.1, big * 0.05), big * 0.72, PI * 0.15, PI * 0.5, 10, Color(0, 0, 0, 0.12 * ka), 3.0 * u, true)
		if leg:
			for ray in 10:
				var ang := _t * 0.5 + TAU * float(ray) / 10.0
				var d := Vector2(cos(ang), sin(ang))
				draw_line(mc + d * (big + 7.0 * u), mc + d * (big + 13.0 * u), Color(GOLD_HI, 0.45 * ka), 2.0 * u)
		# chaque malédiction a son pictogramme (encre sèche, œil d'oni, pas lourd, hâte des morts)
		var gname := String(info.get("icon", "oni")) if is_curse else ("path" if is_pass else UiKit.icon_of(id))
		UiKit.glyph(self, gname, mc, big * 0.62, GOLD_HI if leg else Toon.WASHI, mcol, ka)
		draw_set_transform_matrix(_xf)
	y = mc.y + big

	if rank >= 0:
		# rareté en clair, posée sur le bas du médaillon
		var rn := String(info.get("rarity_name", ""))
		var rw2 := _ui.get_string_size(rn, HORIZONTAL_ALIGNMENT_LEFT, -1, cap).x + 14.0 * s
		var tag := Rect2(Vector2(cx - rw2 / 2.0, y - 6.0 * s), Vector2(rw2, 18.0 * s))
		if really:
			var tb: Color = GOLD_HI if leg else rc
			var ka := ma
			draw_style_box(UiKit.box(_sb, Color(tb, ka), 999, Color(Toon.SUMI, 0.55 * ka), maxi(1, int(1.5 * s))), tag)
			UiKit.text(self, _ui, rn, Vector2(cx, tag.get_center().y + float(cap) * 0.36), cap, Color(LEG_BODY if leg else Toon.WASHI, ka))
		y = tag.end.y + 4.0 * s
		# niveau : texte, puis barre à crans (pris, gagné maintenant en or, à venir)
		var mx := int(info.get("max_level", 1))
		var lv := int(info.get("level", 1))
		var cur := int(info.get("cur_level", 0))
		var lt := "NIV %d/%d" % [lv, mx]
		if mx <= 1:
			lt = "NIVEAU UNIQUE"
		elif cur > 0:
			lt = "NIV %d → %d" % [cur, lv]
		# carte allégée : pas de texte de niveau (l'étiquette du haut dit « NIV 1 → 2 », les crans le reste) ;
		# même hauteur pour toutes les cartes, tout reste aligné d'une carte à l'autre
		y += 2.0 * s
		if mx > 1:
			y += 5.0 * s
			var bw := minf(r.size.x - 28.0 * s, 22.0 * s * float(mx))
			var sg := 3.0 * s
			var sw := (bw - sg * float(mx - 1)) / float(mx)
			if really:
				for k in mx:
					var sr := Rect2(Vector2(cx - bw / 2.0 + float(k) * (sw + sg), y), Vector2(sw, 6.0 * s))
					var fc: Color = Color(ink, 0.16)
					if k < cur:
						fc = Color(ink, 0.75)
					elif k < lv:
						fc = GOLD_HI.lerp(GOLD_HI.lightened(0.35), pulse)
					draw_style_box(UiKit.box(_sb, Color(fc, fc.a * ta), maxi(1, int(2 * s))), sr)
			y += 6.0 * s
		y += 8.0 * s
	else:
		y += 10.0 * s

	# nom (court, en français), une ou deux lignes
	var nm := _p(String(info.get("name", ""))) if rank < 0 else UiKit.power_label(id)
	var nfs := int(16 * s)
	var nlines := _wrap(UiKit.TITLE_FONT, nm, nfs, r.size.x - 12.0 * s)
	if nlines.size() > 1:
		nfs = _fs(13.0, s)
		nlines = _wrap(UiKit.TITLE_FONT, nm, nfs, r.size.x - 12.0 * s)
	var name_col: Color = GOLD_HI if leg else ink
	for k in mini(nlines.size(), 2):
		y += float(nfs) * (0.95 if k == 0 else 1.05)
		if really:
			UiKit.text(self, UiKit.TITLE_FONT, nlines[k], Vector2(cx, y), nfs, Color(name_col, ta))
	# filet sous le nom
	if really:
		draw_line(Vector2(cx - 14 * s, y + 7 * s), Vector2(cx + 14 * s, y + 7 * s), Color(GOLD_HI if dark else Toon.VERMILION, 0.8 * ta), 2.0 * s)
	y += 24.0 * s
	var tw := r.size.x - 12.0 * s
	if rank < 0:
		y = _curse_lines(String(info.get("text", "")), cx, y, tw, cap, 14.5 * s, ta, is_curse, really)
		return y - r.position.y + 6.0 * s

	# valeur expliquée (unités en clair), les chiffres en couleur
	var accent: Color = GOLD_HI if dark or Toon.ui_dark else Toon.VERMILION.darkened(0.12)
	var ef := _card_effect(id, info)
	var efs := _fs(12.5, s)
	var lines := _wrap(_ui, ef, efs, tw)
	if lines.size() > 3:
		efs = _fs(11.0, s)
		lines = _wrap(_ui, ef, efs, tw)
	var lh := float(efs) * 1.25
	var nl := mini(lines.size(), 4)
	for k in nl:
		if really:
			var ka := ta
			_rich(lines[k], cx, y + float(k) * lh, efs, Color(ink, 0.92 * ka), Color(accent, ka))
	y += float(maxi(nl, 2) - 1) * lh + 10.0 * s  # toujours la place de 2 lignes : pieds alignés

	# pied : élément (pictogramme et nom), bonus d'élément, synergie
	var school := String(info.get("school", ""))
	if school == "":
		return y - r.position.y + 4.0 * s
	if really:
		draw_line(Vector2(r.position.x + 10.0 * s, y), Vector2(r.end.x - 10.0 * s, y), Color(ink, 0.18 * ta), 1.0)
	y += 4.0 * s
	var sd: Dictionary = Data.SCHOOLS.get(school, {})
	var el := "Technique" if school == "fig" else ("Encre" if school == "ink" else String(sd.get("word", "")))
	if school == "fig":
		var fw := String(UiKit.FIG_WORD.get(UiKit.trigger_figure(id), ""))
		if fw != "":
			el = fw.substr(0, 1) + fw.substr(1).to_lower()  # la figure à tracer, ex. « Aller-retour »
	var goal := int(info.get("aff_goal", 0))
	# progression du bonus d'élément : des points à droite du nom (pleins = pouvoirs de cet élément)
	var pips := goal if goal > 0 and school != "ink" and school != "fig" and not bool(info.get("aff_hit", false)) else 0
	var pw := float(pips) * 9.0 * s + (6.0 * s if pips > 0 else 0.0)
	if really:
		var scol := UiKit.school_color(school)
		var ka2 := ta
		_icon_line(el, school, scol, cx - pw / 2.0, y + 9.0 * s, r.size.x - 12.0 * s - pw, cap, s, Color(ink, 0.88 * ka2), ka2, dark)
		if pips > 0:
			var tw2 := _ui.get_string_size(el, HORIZONTAL_ALIGNMENT_LEFT, -1, cap).x + 19.0 * s
			var px := cx - pw / 2.0 + tw2 / 2.0 + 6.0 * s + 4.5 * s
			var filled := mini(int(info.get("aff_next", 0)), goal)
			if bool(info.get("aff_done", false)):
				filled = goal
			for k in pips:
				var pc := Vector2(px + float(k) * 9.0 * s, y + 9.0 * s)
				if k < filled:
					draw_circle(pc, 3.4 * s, Color(scol, ka2))
				else:
					draw_arc(pc, 3.0 * s, 0.0, TAU, 14, Color(ink, 0.45 * ka2), maxf(1.0, 1.2 * s), true)
	y += 18.0 * s
	if goal > 0 and school != "ink" and school != "fig":
		if bool(info.get("aff_hit", false)):
			# le bonus d'élément tombe avec ce choix : gélule d'or
			var tiers: Array = Data.AFF_TIERS
			var tier := maxi(0, tiers.find(goal))
			var shorts: Array = Data.AFF_SHORT.get(school, [])
			var bonus := "BONUS ! "
			if tier < shorts.size():
				bonus += _p(String(shorts[tier]))
			var bf := cap
			while bf > 10 and _ui.get_string_size(bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, bf).x > r.size.x - 20.0 * s:
				bf -= 1
			if really:
				var bw2 := _ui.get_string_size(bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, bf).x + 12.0 * s
				var pl := Rect2(Vector2(cx - bw2 / 2.0, y), Vector2(bw2, 17.0 * s))
				var kb := ta
				draw_style_box(UiKit.box(_sb, Color(GOLD_HI, kb * (0.85 + 0.15 * pulse)), 999), pl)
				UiKit.text(self, _ui, bonus, Vector2(cx, pl.get_center().y + float(bf) * 0.36), bf, Color(LEG_BODY, kb))
			y += 20.0 * s
		# sinon : les points à côté du nom de l'élément suffisent (le détail est dans la fiche)
	if bool(info.get("synergy_on", false)) or _has_link(i, "syn"):
		if really:
			_fit_center("+ Élément actif" if school == "fig" else "+ Synergie active", cx, y + 12.0 * s, r.size.x - 10.0 * s, cap, Color(GOLD_HI if dark or Toon.ui_dark else Color("#9A6B12"), ta))
		y += 17.0 * s
	return y - r.position.y + 6.0 * s


## La carte i a-t-elle un lien de ce genre avec un pouvoir possédé ?
func _has_link(i: int, kind: String) -> bool:
	if i < 0 or i >= _links.size():
		return false
	var rel: Dictionary = _links[i]
	for oid in rel.keys():
		if String(rel[oid]) == kind:
			return true
	return false


## Nom du déclencheur pour la carte : la figure à tracer, la phrase complète si elle tient, sinon un ou deux mots.
func _trig_caption(id: String, info: Dictionary, maxw: float, fs: int) -> String:
	if UiKit.trigger_figure(id) != "":
		return UiKit.trigger_word(id)
	var when := _p(String(info.get("when", "")))
	if when != "" and _ui.get_string_size(when, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= maxw:
		return when
	return UiKit.trigger_word(id)


## Pastille d'élément et libellé, centrés.
func _icon_line(txt: String, school: String, scol: Color, cx: float, cy: float, maxw: float, fs: int, s: float, c: Color, a: float, dark: bool) -> void:
	var f := fs
	while f > 10 and _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x + 19.0 * s > maxw:
		f -= 1
	var tw := _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x
	var x := cx - (tw + 19.0 * s) / 2.0
	var ic := Vector2(x + 7.0 * s, cy)
	draw_circle(ic, 7.5 * s, Color(scol.lightened(0.15) if dark else scol, a))
	UiKit.school_icon(self, school, ic, 4.8 * s, Toon.WASHI, a)
	draw_string(_ui, Vector2(x + 19.0 * s, cy + float(f) * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, c)


## Texte centré qui rétrécit (jusqu'à 10 px) s'il déborde.
func _fit_center(txt: String, cx: float, y: float, maxw: float, fs: int, c: Color) -> void:
	var f := fs
	while f > 10 and _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > maxw:
		f -= 1
	UiKit.text(self, _ui, txt, Vector2(cx, y), f, c)


## Valeur de la carte : la ligne chiffrée (« stat », unités en clair) au niveau proposé ; à défaut la ligne courte.
func _card_effect(id: String, info: Dictionary) -> String:
	var d: Dictionary = Data.POWERS.get(id, {})
	var txt := String(d.get("stat", ""))
	if txt == "":
		txt = String(d.get("short", info.get("sub", "")))
	return _at_level(txt, d, int(info.get("level", 1)))


## Remplace {v} / {w} par la valeur du niveau donné (nombre à la française).
func _at_level(src: String, d: Dictionary, lv: int) -> String:
	var txt := src
	for key in ["v", "w"]:
		var tag := "{%s}" % key
		if not txt.contains(tag):
			continue
		var arr: Array = d.get(key, [])
		var val := "?"
		if not arr.is_empty():
			val = _fr(arr[clampi(lv - 1, 0, arr.size() - 1)])
		txt = txt.replace(tag, val)
	return _p(UiKit.dmg_pct(txt))


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


## Début de ligne d'une carte de sanctuaire : malus « - », récompense « + » (« Passer » : pas de malus).
func _lead(k: int, is_curse: bool) -> String:
	if k == 0:
		return "- " if is_curse else ""
	return "+ "


## Malédiction (malus en rouge, récompense en or) ou « Passer » (sans pacte, petit bonus en or), centrés sur la carte.
## Renvoie la ligne de base suivante ; really = false : mesure seulement.
func _curse_lines(text: String, cx: float, y: float, width: float, fs: int, lh: float, a: float, is_curse: bool, really := true) -> float:
	var t := _p(text)
	var yy := y
	if t.contains("·"):
		var parts := t.split("·")
		for k in mini(parts.size(), 2):
			var c: Color = Toon.GOLD.lightened(0.25)
			if k == 0:
				c = RED_TXT if is_curse else Color(Toon.WASHI, 0.75)
			var ls := _wrap(_ui, _lead(k, is_curse) + String(parts[k]).strip_edges(), fs, width)
			for line in ls.slice(0, 2):
				if really:
					UiKit.text(self, _ui, String(line), Vector2(cx, yy), fs, Color(c, a))
				yy += lh
			yy += lh * 0.4
	else:
		for line in _wrap(_ui, t, fs, width).slice(0, 3):
			if really:
				UiKit.text(self, _ui, String(line), Vector2(cx, yy), fs, Color(Toon.WASHI, (0.85 if is_curse else 0.7) * a))
			yy += lh
	return yy


# ------------------------------------------------------------------ bulle de détail

## Hauteur de la bulle de détail d'une carte (le contenu mesuré sans être dessiné).
func _bubble_h(info: Dictionary, id: String, bw: float, u: float) -> float:
	return _bubble_body(Rect2(Vector2.ZERO, Vector2(bw, 4000.0)), info, id, u, 0.0, false)


## Lignes de valeur : « Explosion : 3 dégâts · éclat : 2 » -> [["Explosion", "3 dégâts"], ["Éclat", "2"]].
func _stat_rows(stat: String) -> Array:
	var out: Array = []
	for part in stat.split("·", false):
		var p := String(part).strip_edges()
		if p == "":
			continue
		var k := p.find(" : ")
		if k > 0:
			var lab := p.substr(0, k)
			out.append([lab.substr(0, 1).to_upper() + lab.substr(1), p.substr(k + 3)])
		else:
			out.append(["", p.substr(0, 1).to_upper() + p.substr(1)])
	return out


## Bulle de détail sous les cartes : la carte levée en clair (titre, déclencheur, effet, valeurs, bonus, synergie).
func _bubble(bub: Rect2, info: Dictionary, id: String, px: float, u: float, a: float) -> void:
	if a <= 0.01:
		return
	var hgt := _bubble_h(info, id, bub.size.x, u)
	var box := Rect2(bub.position, Vector2(bub.size.x, minf(hgt, bub.size.y)))
	# papier et pointe vers la carte levée
	var tipx := clampf(px, box.position.x + 24.0 * u, box.end.x - 24.0 * u)
	draw_colored_polygon(PackedVector2Array([Vector2(tipx, box.position.y - 9.0 * u), Vector2(tipx + 10.0 * u, box.position.y + 1.0), Vector2(tipx - 10.0 * u, box.position.y + 1.0)]), Color(Toon.ui_paper, 0.97 * a))
	UiKit.box(_sb, Color(Toon.ui_paper, 0.97 * a), int(12 * u))
	_sb.shadow_color = Color(0, 0, 0, 0.35 * a)
	_sb.shadow_size = int(10 * u)
	_sb.shadow_offset = Vector2(0, 4 * u)
	draw_style_box(_sb, box)
	_bubble_body(box, info, id, u, a, true)


## Contenu de la bulle ; really = false : mesure seulement. Renvoie la hauteur occupée.
func _bubble_body(box: Rect2, info: Dictionary, id: String, u: float, a: float, really: bool) -> float:
	var rank := int(info.get("rarity_rank", -1))
	var pad := 14.0 * u
	var x := box.position.x + pad
	var tw := box.size.x - pad * 2.0
	var y := box.position.y + pad
	var ink: Color = Toon.ui_ink
	var nite: bool = Toon.ui_dark  # papier sombre : accents clairs
	var gold_ink: Color = GOLD_HI if nite else Color("#9A6B12")
	var accent: Color = GOLD_HI if nite else Toon.VERMILION.darkened(0.12)
	var cap := _fs(11.0, u)
	var bfs := _fs(12.0, u)
	var col: Color = info.get("color", Toon.SUMI)
	# titre : nom français ; nom japonais en petit s'il tient ; rareté et nouveauté / niveau à droite
	var title := UiKit.power_label(id) if rank >= 0 else _p(String(info.get("name", "")))
	var tfs := int(17 * u)
	var tag := ""
	var mx := int(info.get("max_level", 1))
	if rank >= 0:
		tag = String(info.get("rarity_name", ""))
		if bool(info.get("is_new", true)):
			tag += " · NOUVEAU"
		elif mx > 1:
			tag += " · NIV %d → %d" % [int(info.get("cur_level", 0)), int(info.get("level", 1))]
	var tag_w := _ui.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, cap).x if tag != "" else 0.0
	y += float(tfs) * 0.9
	if really:
		var title_col: Color = ((RED_TXT if nite else Toon.VERMILION.darkened(0.2)) if rank < 0 else ink)
		draw_string(UiKit.TITLE_FONT, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(title_col, a))
		var nw := UiKit.TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		var jp := _p(String(info.get("name", "")))
		if rank >= 0 and jp != "" and jp.to_lower() != title.to_lower():
			var room := tw - nw - tag_w - 18.0 * u
			var jw := _ui.get_string_size(jp, HORIZONTAL_ALIGNMENT_LEFT, -1, cap).x
			if jw <= room:
				draw_string(_ui, Vector2(x + nw + 8.0 * u, y), jp, HORIZONTAL_ALIGNMENT_LEFT, -1, cap, Color(ink, 0.45 * a))
		if tag != "":
			var rc: Color = info.get("rarity_color", Toon.SUMI)
			var tcol: Color = rc.lightened(0.25) if nite else rc.darkened(0.15)
			if not bool(info.get("is_new", true)):
				tcol = UP_COL.lightened(0.15) if nite else UP_COL.darkened(0.25)
			draw_string(_ui, Vector2(box.end.x - pad - tag_w, y), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, cap, Color(tcol, a))
	if rank >= 0:
		# déclencheur : la figure (ou le pictogramme) et la phrase complète
		y += 9.0 * u
		var when := _p(String(info.get("when", "")))
		var fig := UiKit.trigger_figure(id)
		var chip_w := minf(_ui.get_string_size(when, HORIZONTAL_ALIGNMENT_LEFT, -1, cap).x + 34.0 * u, tw)
		var chip := Rect2(Vector2(x, y), Vector2(chip_w, 22.0 * u))
		if really:
			draw_style_box(UiKit.box(_sb, Color(ink, a), 999), chip)
			var ic := Vector2(chip.position.x + 12.0 * u, chip.get_center().y)
			if fig != "":
				UiKit.figure(self, fig, ic, 8.0 * u, a)
			else:
				UiKit.trigger_icon(self, id, ic, 6.5 * u, Toon.ui_wash, ink, a)
			draw_string(_ui, Vector2(chip.position.x + 25.0 * u, chip.get_center().y + float(cap) * 0.36), when, HORIZONTAL_ALIGNMENT_LEFT, -1, cap, Color(Toon.ui_wash, a))
		y = chip.end.y
	# ce que ça fait, en une ou deux phrases
	var body := _wrap(_ui, _p(String(info.get("text", ""))), bfs, tw)
	var lh := float(bfs) * 1.3
	y += 2.0 * u
	for k in mini(body.size(), 3):
		y += lh
		if really:
			draw_string(_ui, Vector2(x, y), body[k], HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(ink, 0.85 * a))
	if rank < 0:
		return y - box.position.y + pad * 0.9
	# valeurs : une rangée par valeur, libellé et chiffre (avant → après pour une amélioration)
	var stat := _p(String(info.get("stat", "")))
	if stat != "":
		y += 6.0 * u
		var rows := _stat_rows(stat)
		for k in mini(rows.size(), 3):
			var row: Array = rows[k]
			var rr := Rect2(Vector2(x - 4.0 * u, y), Vector2(tw + 8.0 * u, 21.0 * u))
			if really:
				draw_style_box(UiKit.box(_sb, Color(col, 0.1 * a), int(6 * u)), rr)
				var cy := rr.get_center().y
				UiKit.glyph(self, UiKit.stat_icon(String(row[0]) + " " + String(row[1])), Vector2(x + 7.0 * u, cy), 6.0 * u, accent, Toon.ui_paper, a)
				var lx := x + 20.0 * u
				var lab := String(row[0])
				if lab != "":
					draw_string(_ui, Vector2(lx, cy + float(cap) * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, cap, Color(ink, 0.65 * a))
					lx += _ui.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, cap).x + 10.0 * u
				_bold_fit(String(row[1]), Vector2(lx, cy + float(bfs) * 0.36), box.end.x - pad - lx, bfs, Color(accent, a))
			y = rr.end.y + 3.0 * u
	# bonus d'élément : où tu en es, ce que ça donne
	var goal := int(info.get("aff_goal", 0))
	var school := String(info.get("school", ""))
	if goal > 0:
		var at := _p(String(info.get("aff_text", "")))
		var sname := String(info.get("school_name", ""))
		var line := ""
		var on := false
		if bool(info.get("aff_hit", false)):
			line = "Bonus d'élément %s activé : %s" % [sname, at]
			on = true
		elif bool(info.get("aff_done", false)):
			line = "Élément %s au complet : %s" % [sname, at]
			on = true
		elif at != "":
			line = "Bonus d'élément %s : %d/%d pouvoirs → %s" % [sname, mini(int(info.get("aff_next", 0)), goal), goal, at]
		if line != "":
			y += 18.0 * u
			if really:
				var scol := UiKit.school_color(school)
				draw_circle(Vector2(x + 7.0 * u, y - 4.0 * u), 7.0 * u, Color(scol, a))
				UiKit.school_icon(self, school, Vector2(x + 7.0 * u, y - 4.0 * u), 4.5 * u, Toon.WASHI, a)
				_line_fit(line, Vector2(x + 20.0 * u, y), tw - 20.0 * u, cap, Color(gold_ink if on else Color(ink, 0.7), a))
	# synergie : active (partenaire possédé) en or, sinon une piste
	var syn_line := ""
	var syn_on := false
	if school == "fig":
		if bool(info.get("synergy_on", false)):
			syn_line = "+ Élément de tes techniques : " + _p(String(info.get("synergy", "")))
			syn_on = true
	else:
		var sy := _syn_of(id)
		if not sy.is_empty():
			syn_on = bool(sy[2])
			syn_line = ("+ Synergie avec %s : %s" if syn_on else "Synergie possible avec %s : %s") % [String(sy[0]), String(sy[1])]
	if syn_line != "":
		y += 17.0 * u
		if really:
			_line_fit(syn_line, Vector2(x, y), tw, cap, Color(gold_ink if syn_on else Color(ink, 0.5), a))
	return y - box.position.y + pad * 0.8


## Bouton CHOISIR (ACCEPTER au sanctuaire, PASSER pour refuser), sous la bulle ; liseré à la couleur de l'élément.
func _confirm(u: float, a: float) -> void:
	if a <= 0.01 or _sel < 0 or _sel >= _infos.size():
		return
	var info: Dictionary = _infos[_sel]
	var rank := int(info.get("rarity_rank", -1))
	var is_curse := String(info.get("kanji", "")) == "鬼"
	var label := "CHOISIR"
	var col: Color = Toon.VERMILION
	var acc: Color = info.get("color", Toon.WASHI)
	if rank == 3:
		col = GOLD_HI
	elif rank < 0:
		label = "ACCEPTER" if is_curse else "PASSER"
		col = CURSE_COL.lightened(0.15) if is_curse else Color("#4A4C58")
		acc = Toon.WASHI
	var r := _confirm_rect
	if _down == CONFIRM:
		r = r.grow(-2.0 * u)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_style_box(UiKit.box(_sb, Color(acc.lightened(0.2), 0.28 * a * pulse), 999), r.grow(5.0 * u))
	UiKit.box(_sb, Color(col, a), 999, Color(acc.lightened(0.3), 0.95 * a), maxi(2, int(2.5 * u)))
	_sb.shadow_color = Color(0, 0, 0, 0.4 * a)
	_sb.shadow_size = int(8 * u)
	_sb.shadow_offset = Vector2(0, 3 * u)
	draw_style_box(_sb, r)
	var fs := int(17 * u)
	var tc: Color = LEG_BODY if rank == 3 else Toon.WASHI
	var tx := r.get_center().x
	if rank >= 0:
		# pastille du pouvoir à gauche du mot
		var ic := Vector2(r.position.x + r.size.y * 0.5 + 2.0 * u, r.get_center().y)
		draw_circle(ic, r.size.y * 0.32 + 1.5 * u, Color(Toon.WASHI, 0.9 * a))
		UiKit.power_icon(self, _id(_sel), ic, r.size.y * 0.32, a)
		tx += 12.0 * u
	UiKit.text(self, _title, label, Vector2(tx, r.get_center().y + fs * 0.36), fs, Color(tc, a))


## Coupe un texte en lignes qui tiennent dans `width` (mots entiers ; la ponctuation reste collée au mot).
func _wrap(font: Font, txt: String, fs: int, width: float) -> PackedStringArray:
	return UiKit.wrap(font, txt, fs, width, GLUE)


## Une ligne qui rétrécit (jusqu'à 10 px) si elle déborde.
func _line_fit(txt: String, pos: Vector2, maxw: float, fs: int, c: Color) -> void:
	var f := fs
	while f > 10 and _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > maxw:
		f -= 1
	draw_string(_ui, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, c)


## Valeur en gras (deux passes décalées), rétrécie si elle déborde.
func _bold_fit(txt: String, pos: Vector2, maxw: float, fs: int, c: Color) -> void:
	var f := fs
	while f > 10 and _ui.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x + 1.0 > maxw:
		f -= 1
	draw_string(_ui, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, c)
	draw_string(_ui, pos + Vector2(0.7, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, c)


## Reflet en biais qui traverse la carte une seule fois (ph 0 -> 1), doux aux bords ; core : filet vif au milieu.
## Découpé au rectangle de la carte.
func _shine(r: Rect2, u: float, a: float, ph: float, c: Color, core: bool) -> void:
	var e := ph * ph * (3.0 - 2.0 * ph)  # accélère puis ralentit
	var env := sin(ph * PI)  # paraît et s'éteint en douceur
	var slant := r.size.x * 0.6
	var x := lerpf(r.position.x - 30.0 * u, r.end.x + slant + 30.0 * u, e)
	var rect := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	# large bande pâle, puis (rare et plus) un filet plus vif en son milieu
	var bands: Array = [[26.0, 1.0]]
	if core:
		bands.append([6.0, 1.6])
	for b in bands:
		var wd := float(b[0]) * u
		var x0 := x - wd / 2.0
		var poly := PackedVector2Array([Vector2(x0, r.position.y), Vector2(x0 + wd, r.position.y), Vector2(x0 + wd - slant, r.end.y), Vector2(x0 - slant, r.end.y)])
		for piece in Geometry2D.intersect_polygons(poly, rect):
			var pp: PackedVector2Array = piece
			if pp.size() >= 3 and UiKit.poly_area(pp) > 2.0:
				draw_colored_polygon(pp, Color(c, minf(1.0, c.a * float(b[1])) * a * env))
