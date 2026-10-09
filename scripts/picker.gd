extends Control
## Choix d'un rouleau parmi trois (pouvoirs) ou d'une malédiction au sanctuaire.
## En haut, « TES POUVOIRS » : les pouvoirs déjà pris (couleur d'élément, niveau) ; la carte touchée (ou survolée)
## y allume ceux qu'elle améliore, renforce ou complète, reliés à elle par un trait.
## Chaque carte se lit en mots : ruban NOUVEAU / AMÉLIORATION, déclencheur nommé (figure ou pictogramme),
## médaillon et rareté en clair, niveau en texte et barre à crans, nom, valeur expliquée, élément et bonus d'élément.
## Premier toucher : la carte se lève et son détail s'ouvre dans une bulle ; second toucher (ou CHOISIR) : choisie.
## Légendaire : carte noire et or, arrive face cachée (ensō doré) puis se retourne dans une gerbe d'or.
## Chaque carte est un kakemono : roulé (gros rouleau de papier sur son jiku, embouts laqués cerclés d'or), il tombe
## au bout de son cordon en se balançant, puis se déroule (en décalé) : le rouleau du bas descend en tournant et
## maigrit, le papier et sa monture de soie paraissent, le contenu se révèle au passage, petit rebond à la pose.
## Un toucher pendant le déroulé l'achève d'un coup. Au choix, la choisie se réenroule vite puis s'envole en
## s'effaçant ; les autres se réenroulent et s'effacent.
## Toute première ouverture : une petite feuille au-dessus des cartes explique les rouleaux (COMPRIS, ou un choix).
## Trois styles de cartes à comparer (`style`, `?pickstyle=N` sur le web) : 0 kakemono épuré (ci-dessus),
## 1 ofuda (talisman de laque, sceau vermillon, pictogramme d'or), 2 estampe (tableau ukiyo-e, cartouche du nom ;
## style par défaut). L'effet se lit en pastilles (pictogramme, chiffre en couleur, libellé court : Data.EFFECTS),
## le déclencheur en pictogramme dans le coin du tableau ; la bulle de détail reprend les pastilles.
## Ofuda et estampe ne se déroulent pas : chaque carte est donnée face cachée (elle monte), puis se retourne.
## Style 3 (UI v2, par défaut ; handoff design/ui_v2, planches RouleauCard, CarteRouleau, Rouleaux) : carte 116 × 250 u
## à scène peinte de l'élément, médaillon et glyphe, pastille nouveau / ↑niveau, déclencheur en pictogramme, cartouche
## du nom (le seul texte de la carte), lignes d'effet (picto, LIBELLÉ, points de conduite, chiffre), crans, anneau
## d'harmonie (état après le choix) ; rareté = bordure seule. Écran : titre, bande des pouvoirs pris (ceux liés à la
## carte en vue cerclés d'or pointillé), cartes, bulle d'encre sous les cartes, relance ronde et CHOISIR au pinceau.
## Même donne face cachée et même retournement que l'estampe ; même logique de choix (toucher, CHOISIR, relance).
## Le sanctuaire (pactes) reste toujours en kakemono.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/power_data.gd")
const UIColors = preload("res://scripts/ui_colors.gd")

const STYLE_V2 := 3  # carte de rouleau v2 (style par défaut)
const V2_W := 116.0  # carte v2 (× u, avant mise à l'échelle des cartes)
const V2_H := 250.0
const V2_GAP := 8.0
const V2_LIFT := 14.0  # carte touchée : soulevée de 14 u
# CHOISIR au pinceau (gabarit 210 × 64) : contour (courbes de Bézier et segments) et trait vermillon dessous
const V2_BTN_W := 210.0
const V2_BTN_H := 64.0
const V2_REROLL := 54.0  # relance : bouton rond (× u)
const GOLD_HI := Color("#E2A93B")
const LEG_BODY := Color("#1C1A21")
const CURSE_BODY := Color("#2A0E0B")
const PASS_BODY := Color("#2A2B33")
const CURSE_COL := Color("#7A1F1A")
const RED_TXT := Color("#FF8A7A")
const UP_COL := Color("#3FA88E")  # amélioration d'un pouvoir déjà pris
const FLIP_AFTER := 0.08  # le légendaire se retourne juste après son déroulé (s après la pose)
const REVEAL_DUR := 0.3
const CONFIRM := 100  # cible « bouton CHOISIR »
const TIP := 101  # cible « explication des rouleaux » (COMPRIS)
const UNROLL_AT := 0.05  # premier rouleau qui arrive (s, temps réel)
const UNROLL_GAP := 0.13  # décalage d'une carte à la suivante
const UNROLL_DUR := 0.64  # chute du rouleau fermé, déroulé et rebond compris
const DROP_DUR := 0.16  # le rouleau fermé tombe de DROP_H au bout de son cordon
const DROP_H := 22.0  # (× u)
const ROLL_AT := 0.12  # le rouleau du bas commence à descendre (s après l'arrivée)
const SWAY_DEG := 4.0  # balancement au bout du cordon (degrés), amorti
const ROLL_R0 := 8.0  # rayon du rouleau fermé (× u)
const ROLL_R1 := 3.0  # rayon du rouleau du bas une fois déroulé (× u)
const KNOB_R := 4.2  # demi-hauteur des coiffes du rouleau (× u)
const CORD_H := 11.0  # hauteur du crochet du cordon au-dessus de la baguette (× u)
const NO_CUT := 1.0e9  # pas de bord de papier : tout le contenu se voit
const POP_AT := 0.08  # légendaire retourné : le médaillon « pope » (s après la mi-retournement)
const POP_DUR := 0.26
const TXT_AT := 0.14  # puis le texte se fond
const TXT_DUR := 0.2
const SHEEN_AT := 0.3  # reflet unique du légendaire, juste après le retournement
const SHEEN_DUR := 0.5
const WOOD := Color("#5A3F2C")  # baguettes
const WOOD_CAP := Color("#2A1E17")  # embouts (jiku), bois laqué
const CORD := Color("#C9A25A")  # cordon d'accroche (kakehimo)
const GOLD_CAP := Color("#C8963A")  # coiffes des baguettes, crochet de laiton
const OFUDA_BODY := Color("#17151B")  # laque noire (sumi) de l'ofuda
const OFUDA_INDIGO := Color("#5B7BE0")  # lueur indigo de l'ofuda rare
const DEAL_DUR := 0.3  # ofuda, estampe : la carte monte à sa place (s)
const DEAL_H := 34.0  # depuis cette distance sous sa place (× u)
const DEAL_DEG := 3.0  # petite inclinaison qui se redresse
const DEAL_FLIP := 0.2  # elle se retourne (s après son arrivée)
const LEG_HOLD := 0.3  # le légendaire reste un peu plus longtemps face cachée
const GLUE := [":", ";", "!", "?", "%", "→", "·"]  # jamais en début de ligne

signal picked(id: String)
signal reroll

var rerolls := 0  # relances disponibles (Atelier : Choix, Omamori)
var style := STYLE_V2  # style des cartes : 0 kakemono épuré, 1 ofuda, 2 estampe, 3 carte v2 (par défaut)

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
var _xf := Transform2D.IDENTITY  # transformation de la carte en cours de dessin (chute, levée, retournement)
var _ct := 0.0  # temps du contenu du légendaire retourné (s ; grand : tout se voit)
var _sheen := -1.0  # temps du reflet de la carte en cours de dessin (s, négatif : pas encore)
var _raise := 0.0  # levée de la carte en cours de dessin (ombre plus large)
var _cut := NO_CUT  # rouleau du bas de la carte en cours de dessin : bord du papier déroulé (y, repère de la carte)
var _ahead := 0.0  # le contenu se révèle un peu avant le rouleau (caché dessous), plein une fois déroulé
var _band := 12.0  # un élément apparaît sur cette distance, une fois sorti du rouleau
var _swallow := false  # relâché à ignorer (l'appui a achevé le déroulé)
var _tip_on := false  # explication des rouleaux : place réservée dans la mise en page (première ouverture)
var _tip_gone := false  # explication fermée (COMPRIS ou choix)
var _tip_a := 0.0
var _tip_rect := Rect2()
var _tip_ex: Array = []  # exemples de déclencheurs (« DANS LE DOS = frappe de dos »…), cartes montrées d'abord
var _no_v2 := false  # une carte sans rareté hors sanctuaire (« Passer ») : la carte v2 cède la place à l'estampe
var _v2_title := FontVariation.new()  # UN ROULEAU (espacement 6 u)
var _v2_caps := FontVariation.new()  # nom japonais de la bulle (espacement 2 u)
var _v2_btn := FontVariation.new()  # CHOISIR (espacement 6 u)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = 1
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = 6
	_v2_title.base_font = UiKit.TITLE_FONT
	_v2_title.spacing_glyph = 6
	_v2_caps.base_font = UiKit.TITLE_FONT
	_v2_caps.spacing_glyph = 2
	_v2_btn.base_font = UiKit.TITLE_FONT
	_v2_btn.spacing_glyph = 6


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
	_no_v2 = false
	_leg_index = -1
	_leg_last = -1
	for i in infos.size():
		var info: Dictionary = infos[i]
		if String(info.get("kanji", "")) == "鬼":
			_curse_mode = true
		if int(info.get("rarity_rank", -1)) < 0:
			_no_v2 = true
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
	_sheen = -1.0
	_raise = 0.0
	_cut = NO_CUT
	_ahead = 0.0
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


## Instant où l'on peut choisir (rouleaux déroulés et posés, légendaire retourné) : ≈ 0.95 s pour trois cartes.
## Ofuda, estampe : toutes les cartes retournées (≈ 0.9 s pour trois cartes).
func _ready_time() -> float:
	if _sty() != 0:
		var tf := 0.0
		for i in _ids.size():
			tf = maxf(tf, _reveal_start(i) + REVEAL_DUR + (0.1 if _is_leg(i) else 0.05))
		return tf
	var t := _unroll_start(_ids.size() - 1) + UNROLL_DUR
	if _leg_index >= 0:
		t = maxf(t, _reveal_start(_leg_last) + REVEAL_DUR + 0.1)
	return t


func _is_leg(i: int) -> bool:
	if i < 0 or i >= _infos.size():
		return false
	var info: Dictionary = _infos[i]
	return String(info.get("rarity", "")) == "legendary"


## Kakemono : le légendaire se retourne juste après son déroulé. Ofuda, estampe : chaque carte se retourne peu
## après son arrivée (le légendaire reste un peu plus longtemps face cachée).
func _reveal_start(i: int) -> float:
	if _sty() != 0:
		return _unroll_start(i) + DEAL_FLIP + (LEG_HOLD if _is_leg(i) else 0.0)
	return _unroll_start(i) + UNROLL_DUR + FLIP_AFTER


## Arrivée du rouleau de la carte i (en décalé).
func _unroll_start(i: int) -> float:
	return UNROLL_AT + UNROLL_GAP * float(maxi(i, 0))


## Déroulé à l'instant lt (s depuis l'arrivée) : 0 roulé, 1 déroulé. Le rouleau descend vite puis ralentit
## (ease-out doux : le haut de la carte reste lisible), dépasse un peu le bas, remonte d'un rien et s'arrête
## (petit rebond amorti, sans à-coup final).
func _unroll(lt: float) -> float:
	var k := clampf((lt - ROLL_AT) / (UNROLL_DUR - ROLL_AT), 0.0, 1.0)
	if k < 0.7:
		var x := 1.0 - k / 0.7
		return 1.04 * (1.0 - x * x)
	var s := (k - 0.7) / 0.3
	return 1.0 + 0.04 * cos(s * PI * 1.5) * (1.0 - s)


## Pose douce (ease-out-back léger) : 0 -> 1, dépasse de quelques % puis se pose, sans oscillation.
func _settle(k: float, s := 1.1) -> float:
	var x := clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + (s + 1.0) * x * x * x + s * x * x


## Mise à l'échelle autour d'un point (médaillon qui « pope », carte levée).
func _about(c: Vector2, s: float) -> Transform2D:
	return Transform2D(0.0, Vector2(s, s), 0.0, c * (1.0 - s))


## Rotation d'un angle (radians) autour d'un point (balancement au bout du cordon).
func _turn(p: Vector2, ang: float) -> Transform2D:
	return Transform2D(ang, p) * Transform2D(0.0, -p)


func _gui_input(event: InputEvent) -> void:
	if _chosen >= 0:
		return
	if _t < _ready_time():
		# un appui pendant le déroulé l'achève d'un coup (son relâché ne choisit rien)
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
	if _sty() == STYLE_V2:
		_draw_v2()
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
	# hauteur commune des pastilles d'effet (la plus haute des cartes) : mesures et dessin la partagent
	var fs_s := minf(u, cw / 116.0)
	var fx_res := 0.0
	for i in n:
		var inf: Dictionary = _infos[i]
		if int(inf.get("rarity_rank", -1)) >= 0:
			fx_res = maxf(fx_res, _fx_lay_h(_fx_lay(_fx_of(_id(i), inf), _fx_w(cw, fs_s), fs_s), fs_s))
	_fx_res = fx_res
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
			# chaque style n'utilise qu'une part de _big : on remesure
			ch = 0.0
			for i in n:
				ch = maxf(ch, _need_h(_infos[i], _id(i), cw, u, i))
		ch = maxf(ch - maxf(0.0, head + ch + tail - avail), 120.0 * u)
	# carte élancée (≈ 1:1,9), plus haute que son contenu (dans la place qui reste) : chaque style répartit
	# la place en plus (_extra) dans sa carte
	var need := ch
	ch = maxf(ch, minf(cw * 1.95, ch + maxf(0.0, avail - (head + ch + tail))))
	_extra = maxf(0.0, ch - need)
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

	# cartes côte à côte : chaque rouleau tombe, se balance et se déroule, en décalé ; la carte levée (ou choisie)
	# se dessine en dernier, par-dessus. Les rectangles de toucher restent fixes : seul le dessin bouge.
	var order: Array = []
	for i in n:
		if i != _sel:
			order.append(i)
	if _sel >= 0 and _sel < n:
		order.append(_sel)
	var st := _sty()
	for oi in order:
		var i := int(oi)
		var info: Dictionary = _infos[i]
		var base: Rect2 = _rects[i]
		var c := base.get_center()
		# pivot du balancement : crochet du cordon (kakemono), centre de la carte (ofuda, estampe)
		var hang := Vector2(c.x, base.position.y - CORD_H * u) if st == 0 else c
		var lf: float = float(_lift[i]) if i < _lift.size() else 0.0
		var lt := _t - _unroll_start(i)
		var a := fade
		var sc := 1.0
		var dy := 0.0
		var rot := 0.0
		var op := 1.0  # déroulé : 0 roulé, 1 déroulé
		_ct = 99.0
		_sheen = lt - UNROLL_DUR + 0.1  # reflet unique au moment de la pose
		if _chosen >= 0:
			_sheen = -1.0
			if i == _chosen:
				# la choisie : petit bond et onde d'or, se réenroule vite (le rouleau remonte), puis s'envole
				op = 1.0 - smoothstep(0.04, 0.26, _t)
				var p2 := clampf((_t - 0.22) / 0.28, 0.0, 1.0)
				p2 *= p2
				sc = lerpf(1.04, 1.08, UiKit.ease_out(_t / 0.1)) - 0.1 * p2
				dy = -8.0 * u - 70.0 * u * p2
				a = 1.0 - UiKit.ease_out((_t - 0.28) / 0.22)
				lf = 1.0
				# onde d'or au bond, derrière la carte
				var rk := clampf(_t / 0.35, 0.0, 1.0)
				if rk < 1.0:
					var rc0 := c + Vector2(0, -8.0 * u)
					draw_arc(rc0, base.size.x * (0.55 + 0.45 * UiKit.ease_out(rk)), 0.0, TAU, 48, Color(GOLD_HI, 0.45 * (1.0 - rk)), (4.0 * (1.0 - rk) + 1.0) * u)
			else:
				# les autres se réenroulent vite et s'effacent
				op = 1.0 - smoothstep(0.0, 0.2, _t)
				a = (1.0 - UiKit.ease_out((_t - 0.1) / 0.2)) * lerpf(0.62, 1.0, lf)
				dy = -8.0 * u * lf
		else:
			var sw := 1.0 if i % 2 == 0 else -1.0
			if st == 0:
				# arrivée : le rouleau fermé paraît et tombe au bout de son cordon (le cordon le retient d'un rien)
				a *= UiKit.ease_out(lt / 0.12)
				dy = -(1.0 - _settle(lt / DROP_DUR, 1.4)) * DROP_H * u
				op = _unroll(lt)
				# balancement amorti autour du crochet (sens alterné d'une carte à l'autre)
				var lt0 := maxf(lt, 0.0)
				rot = deg_to_rad(SWAY_DEG) * sw * exp(-lt0 / 0.22) * sin(lt0 * TAU / 0.42)
			else:
				# donne : la carte monte face cachée jusqu'à sa place en se redressant, puis se retourne
				a *= UiKit.ease_out(lt / 0.14)
				dy = (1.0 - _settle(lt / DEAL_DUR, 1.2)) * DEAL_H * u
				rot = deg_to_rad(DEAL_DEG) * sw * (1.0 - UiKit.ease_out(lt / DEAL_DUR))
			# carte levée : monte, grandit, ombre plus large ; les autres s'estompent
			dy -= 8.0 * u * lf
			sc *= 1.0 + 0.04 * lf
			if _sel >= 0:
				a *= lerpf(0.62, 1.0, lf)
		if _down == i:
			sc *= 0.97
		_raise = lf
		var xf := Transform2D(0.0, Vector2(0, dy)) * _turn(hang, rot) * _about(c, sc)
		_card(base, info, _id(i), u, a, i, xf, op)
	_xf = Transform2D.IDENTITY
	_raise = 0.0
	_sheen = -1.0

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
		"Points près de l'élément : 2 du même = harmonie",
		"Crans dorés : reprends-le plus tard pour le monter",
	]
	if _sty() == STYLE_V2:
		lines = [
			"Un rouleau = un pouvoir, gardé toute la partie",
			"En haut à droite : quand il agit",
			"Anneau : 2 pouvoirs du même élément = harmonie",
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

## Style des cartes ; le sanctuaire (pactes) garde toujours le kakemono ; une carte sans rareté passe la carte v2
## en estampe.
func _sty() -> int:
	if _curse_mode:
		return 0
	var st := clampi(style, 0, STYLE_V2)
	if st == STYLE_V2 and _no_v2:
		return 2
	return st


## Ombre portée de la boîte _sb (plus large et plus basse quand la carte est levée).
func _shadow(u: float, a: float) -> void:
	_sb.shadow_color = Color(0, 0, 0, (0.45 + 0.1 * _raise) * a)
	_sb.shadow_size = int((14.0 + 8.0 * _raise) * u)
	_sb.shadow_offset = Vector2(0, (6.0 + 6.0 * _raise) * u)


## Lueur de rareté autour de pr (couches qui respirent).
func _glow(pr: Rect2, gc: Color, layers: int, radius: int, u: float, a: float, i: int) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)
	for k in layers:
		var g := (4.0 + 4.0 * float(k)) * u
		var ga := (0.24 - 0.07 * float(k)) * a * (0.55 + 0.45 * pulse)
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), radius + int(g), Color(gc, ga), maxi(1, int(3 * u))), pr.grow(g))


## Halo de la carte levée (or ; vermillon au sanctuaire).
func _halo(pr: Rect2, hc: Color, radius: int, u: float, a: float, i: int) -> void:
	if i == _sel and _raise > 0.01:
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), radius + int(6 * u), Color(hc, 0.95 * a * _raise), maxi(1, int(3 * u))), pr.grow(6.0 * u))


## Reflet unique à la pose : plus franc (et doré au légendaire) dès la rareté rare.
func _sheen_pass(pr: Rect2, u: float, a: float, rank: int) -> void:
	var sk := _sheen / SHEEN_DUR
	if _chosen < 0 and sk > 0.0 and sk < 1.0:
		var sa := 0.12 if rank <= 0 else (0.18 if rank < 3 else 0.24)
		_shine(pr, u, a, sk, Color(GOLD_HI.lightened(0.35), sa) if rank == 3 else Color(1, 1, 1, sa), rank >= 1)


## Une carte : r = rectangle final (au repos), xf = transformation du moment (chute, balancement, levée,
## choix), op = déroulé du kakemono (0 roulé sous la baguette du haut, 1 déroulé, un peu plus au rebond).
## Ofuda et estampe : pas de rouleau, la carte est donnée face cachée puis se retourne (_card_flip).
func _card(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int, xf: Transform2D, op: float) -> void:
	if a <= 0.01:
		return
	if _sty() != 0:
		_card_flip(r, info, id, u, a, i, xf)
		return
	var leg := String(info.get("rarity", "")) == "legendary"
	# rouleau du bas : roulé juste sous la baguette du haut, il descend jusqu'au bas de la carte
	var c0 := (ROLL_R0 + 2.0) * u
	_cut = r.position.y + c0 + (r.size.y - c0) * maxf(op, 0.0)
	_band = 12.0 * u
	_ahead = _band * clampf(op, 0.0, 1.0)
	# le rouleau maigrit en libérant le papier (surface conservée : vite à la fin) et tourne avec lui
	var rem := clampf(1.0 - op, 0.0, 1.0)
	var r1 := ROLL_R1 * u
	var r0 := ROLL_R0 * u
	var rr := sqrt(r1 * r1 + (r0 * r0 - r1 * r1) * rem)
	var spin := (_cut - r.position.y) / rr
	var band := _band_col(info)
	var paper := _body_col(info)
	# légendaire : le dos (ensō doré) se déroule, se retourne, puis face et gerbe d'or
	var c := r.get_center()
	var sx := 1.0
	var back := false
	if leg:
		var kf := 1.0 if _chosen >= 0 else (_t - _reveal_start(i)) / REVEAL_DUR
		if kf < 0.5:
			back = true
			sx = 1.0 if kf <= 0.0 else 1.0 - kf * 2.0
		elif kf < 1.0:
			sx = (kf - 0.5) * 2.0
		if not back and _chosen < 0:
			# le contenu de la face paraît pendant la seconde moitié du retournement, le reflet juste après
			_ct = _t - _reveal_start(i) - REVEAL_DUR * 0.5 + 0.06
			_sheen = _ct - SHEEN_AT
	_xf = xf * _squash(c, maxf(sx, 0.02))
	draw_set_transform_matrix(_xf)
	_cord(r, u, a)
	if back:
		_back(r, u, a, i)
		_roller(r, u, a, rr, spin, band, LEG_BODY)
	else:
		_face(r, info, id, u, a, i)
		_roller(r, u, a, rr, spin, band, paper)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_cut = NO_CUT
	_ahead = 0.0
	if leg and not back:
		_burst(r, u, a, i, xf)


## Ofuda, estampe : la carte monte face cachée (dos), se retourne (écrasée puis rouverte), le contenu se fond.
func _card_flip(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int, xf: Transform2D) -> void:
	var leg := String(info.get("rarity", "")) == "legendary"
	var st := _sty()
	_cut = NO_CUT
	_ahead = 0.0
	var kf := 1.0 if _chosen >= 0 else (_t - _reveal_start(i)) / REVEAL_DUR
	var c := r.get_center()
	if kf < 0.5:
		var sx := 1.0 if kf <= 0.0 else 1.0 - kf * 2.0
		_xf = xf * _squash(c, maxf(sx, 0.02))
		draw_set_transform_matrix(_xf)
		if leg:
			_back(r, u, a, i)
		elif st == STYLE_V2:
			_back_v2(r, a)
		else:
			_back_print(r, u, a, st)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if _chosen < 0:
		_ct = _t - _reveal_start(i) - REVEAL_DUR * 0.5 + 0.06
		_sheen = _ct - SHEEN_AT
	var sx2 := 1.0 if kf >= 1.0 else (kf - 0.5) * 2.0
	_xf = xf * _squash(c, maxf(sx2, 0.02))
	draw_set_transform_matrix(_xf)
	if st == 1:
		_face_ofuda(r, info, id, u, a, i)
	elif st == STYLE_V2:
		_face_v2(r, info, id, u, a, i)
	else:
		_face_print(r, info, id, u, a, i)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if leg:
		_burst(r, u, a, i, xf)


## Gerbe d'or juste après le retournement du légendaire (centre à l'écran).
func _burst(r: Rect2, u: float, a: float, i: int, xf: Transform2D) -> void:
	var tr := _t - _reveal_start(i) - REVEAL_DUR
	if _chosen >= 0 or tr <= 0.0 or tr >= 0.9:
		return
	var k := tr / 0.9
	var ea := (1.0 - k) * a
	var dim := minf(r.size.x, r.size.y)
	var cs := xf * r.get_center()
	draw_rect(Rect2(Vector2.ZERO, size), Color(GOLD_HI, 0.22 * maxf(0.0, 1.0 - tr / 0.25)))
	draw_arc(cs, dim * (0.5 + 0.9 * UiKit.ease_out(k)), 0.0, TAU, 48, Color(GOLD_HI, 0.8 * ea), 3.0 * u * (1.0 - k) + 1.0)
	for ray in 18:
		var ang := TAU * float(ray) / 18.0 + 0.2
		var d := Vector2(cos(ang), sin(ang))
		var r0g := dim * (0.45 + 0.6 * k)
		var r1g := r0g + dim * 0.4 * (1.0 - k)
		draw_line(cs + d * r0g, cs + d * r1g, Color(GOLD_HI, 0.7 * ea), 2.0 * u)


## Papier déroulé de la carte en cours de dessin (du haut jusqu'au rouleau du bas).
func _paper(r: Rect2) -> Rect2:
	return Rect2(r.position, Vector2(r.size.x, clampf(_cut - r.position.y, 0.0, r.size.y * 1.1)))


## Visibilité d'un élément de carte dont le bas est en y : il n'apparaît qu'une fois sorti du rouleau.
func _rv(y: float) -> float:
	return clampf((_cut + _ahead - y) / _band, 0.0, 1.0)


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


## Soie de la monture (chūberi) autour du papier : discrète, à peine teintée de la rareté.
func _mount_col(info: Dictionary) -> Color:
	var rank := int(info.get("rarity_rank", -1))
	var body := _body_col(info)
	if rank == 3:
		return LEG_BODY.lerp(GOLD_HI, 0.14)
	if rank < 0:
		return body.lightened(0.07)
	if rank == 0:
		return body.darkened(0.07)
	var rc: Color = info.get("rarity_color", Color(0.5, 0.5, 0.5))
	return body.lerp(rc, 0.16).darkened(0.04)


## Bandes du haut et du bas de la monture (ten, chi) : la couleur de rareté, assombrie.
func _band_col(info: Dictionary) -> Color:
	var rank := int(info.get("rarity_rank", -1))
	if rank == 3:
		return GOLD_HI.darkened(0.42)
	if String(info.get("kanji", "")) == "鬼":
		return CURSE_COL.darkened(0.25)
	if rank < 0:
		return PASS_BODY.darkened(0.3)
	var rc: Color = info.get("rarity_color", Color(0.5, 0.5, 0.5))
	return rc.darkened(0.32)


## Hauteur de la bande du haut (ten) et du bas (chi) ; really : la carte allongée les élargit un peu.
func _ten(s: float, really: bool) -> float:
	return 20.0 * s + (_extra * 0.1 if really else 0.0)


func _chi(s: float, really: bool) -> float:
	return 18.0 * s + (_extra * 0.08 if really else 0.0)


## Fine baguette du haut (hassō) et ses petites coiffes d'or, de x0 à x1 à la hauteur y.
func _rod(x0_in: float, x1_in: float, y: float, u: float, a: float) -> void:
	var x0 := x0_in + 2.0 * u
	var x1 := x1_in - 2.0 * u
	var rh := 1.4 * u
	draw_rect(Rect2(Vector2(x0, y - rh), Vector2(x1 - x0, rh * 2.0)), Color(WOOD, a))
	draw_line(Vector2(x0, y - rh * 0.4), Vector2(x1, y - rh * 0.4), Color(WOOD.lightened(0.35), 0.55 * a), maxf(1.0, 0.6 * u))
	for ex in [x0, x1]:
		var ec := Vector2(float(ex), y)
		draw_circle(ec, 2.7 * u, Color(GOLD_CAP.darkened(0.4), a))
		draw_circle(ec, 2.1 * u, Color(GOLD_CAP, a))
		draw_circle(ec + Vector2(-0.6, -0.7) * u, 0.8 * u, Color(1, 1, 1, 0.55 * a))


## Cordon d'accroche (kakehimo) torsadé, des deux bouts de la baguette jusqu'au crochet de laiton (clou et crochet).
func _cord(r: Rect2, u: float, a: float) -> void:
	var hk := Vector2(r.get_center().x, r.position.y - CORD_H * u)
	var col := Color(CORD, 0.85 * a)
	var twist := Color(CORD.lightened(0.4), 0.6 * a)
	for ex in [r.position.x + 9.0 * u, r.end.x - 9.0 * u]:
		var p0 := Vector2(float(ex), r.position.y)
		var d := hk - p0
		draw_line(p0, hk, col, maxf(1.0, 1.3 * u), true)
		# torsade : petits traits clairs en biais le long du cordon
		var t := d.normalized()
		var tick := (t + Vector2(-t.y, t.x)).normalized() * 0.9 * u
		var nt := int(d.length() / (4.0 * u))
		for k in nt:
			var p := p0 + d * ((float(k) + 0.5) / float(maxi(nt, 1)))
			draw_line(p - tick, p + tick, twist, maxf(1.0, 0.6 * u))
	# crochet : clou, tige et crochet de laiton, nœud du cordon
	var gc := Color(GOLD_CAP, a)
	var lw := maxf(1.0, 1.1 * u)
	draw_line(hk + Vector2(0, -3.5 * u), hk + Vector2(0, 0.6 * u), gc, lw)
	draw_arc(hk + Vector2(1.3 * u, 0.6 * u), 1.3 * u, 0.0, PI, 10, gc, lw, true)
	draw_line(hk + Vector2(2.6 * u, 0.6 * u), hk + Vector2(2.6 * u, -0.6 * u), gc, lw)
	draw_circle(hk + Vector2(0, -3.8 * u), 1.7 * u, Color(GOLD_CAP.darkened(0.35), a))
	draw_circle(hk + Vector2(-0.4, -4.2) * u, 0.6 * u, Color(1, 1, 1, 0.5 * a))
	draw_circle(hk + Vector2(0.4 * u, 1.4 * u), 1.4 * u, Color(CORD.darkened(0.25), a))


## Rouleau du bas, au bord du papier déroulé (y = _cut) : ombre de courbure sur le papier, ombre portée, cylindre de
## papier encore roulé (rayon rr, bandes d'ombre, reflet, rayures qui défilent avec l'angle spin, spirale aux bouts),
## puis les petites coiffes d'or (jiku) qui tournent avec lui.
func _roller(r: Rect2, u: float, a: float, rr: float, spin: float, broc: Color, paper: Color) -> void:
	var y := _cut
	var x0 := r.position.x
	var x1 := r.end.x
	var shown := _cut - r.position.y
	# ombre de courbure : le papier s'assombrit juste avant de s'enrouler
	if shown > rr + 2.0 * u:
		var sh := minf(12.0 * u, shown - rr)
		for k in 4:
			var hk := sh * float(k + 1) / 4.0
			draw_rect(Rect2(Vector2(x0 + 1.0 * u, y - rr - hk), Vector2(r.size.x - 2.0 * u, hk)), Color(0, 0, 0, 0.045 * a))
	# ombre portée sous le rouleau
	draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.2 * a), maxi(1, int(rr + 2.0 * u))), Rect2(Vector2(x0 + 3.0 * u, y + rr * 0.3), Vector2(r.size.x - 6.0 * u, rr + 4.0 * u)))
	# cylindre : cinq bandes éclairées d'en haut (volume), contour sombre
	var cl := x0 + 0.5 * u
	var cw := r.size.x - 1.0 * u
	var dark := broc.darkened(0.4)
	var lite := broc.lightened(0.2)
	for k in 5:
		var t0 := -PI * 0.5 + PI * float(k) / 5.0
		var t1 := t0 + PI / 5.0
		var ya := y + rr * sin(t0)
		var yb := y + rr * sin(t1)
		var lit := clampf(0.5 + 0.5 * cos((t0 + t1) * 0.5 + 0.6), 0.0, 1.0)
		draw_rect(Rect2(Vector2(cl, ya), Vector2(cw, yb - ya + 0.5)), Color(dark.lerp(lite, lit), a))
	# rayures (fils d'or et trame sombre) qui défilent : le rouleau tourne ; plus pâles vers les bords du cylindre
	for k in 6:
		var th := spin + TAU * float(k) / 6.0
		var cz := cos(th)
		if cz <= 0.12:
			continue
		var ys := y + rr * sin(th)
		var sc: Color = GOLD_HI if k % 2 == 0 else broc.darkened(0.55)
		draw_line(Vector2(cl + 5.0 * u, ys), Vector2(cl + cw - 5.0 * u, ys), Color(sc, (0.36 if k % 2 == 0 else 0.26) * cz * a), maxf(1.0, 0.7 * u))
	# reflet fixe en haut, ombre en bas, contour
	draw_line(Vector2(cl + 4.0 * u, y - rr * 0.55), Vector2(cl + cw - 4.0 * u, y - rr * 0.55), Color(1, 1, 1, 0.28 * a), maxf(1.0, rr * 0.22))
	draw_line(Vector2(cl + 2.0 * u, y + rr * 0.78), Vector2(cl + cw - 2.0 * u, y + rr * 0.78), Color(0, 0, 0, 0.2 * a), maxf(1.0, rr * 0.18))
	draw_rect(Rect2(Vector2(cl, y - rr), Vector2(cw, rr * 2.0)), Color(Toon.SUMI, 0.4 * a), false, maxf(1.0, 0.7 * u))
	# bouts du rouleau : tranche du papier et spirale qui tourne (se voit tant que le rouleau dépasse les coiffes)
	var kr := KNOB_R * u
	if rr > kr * 0.85:
		var turns := 1.0 + 2.0 * clampf((rr - ROLL_R1 * u) / maxf(0.001, (ROLL_R0 - ROLL_R1) * u), 0.0, 1.0)
		for ex in [cl + 2.5 * u, cl + cw - 2.5 * u]:
			var ecx := float(ex)
			var ell := PackedVector2Array()
			for k in 16:
				var ang := TAU * float(k) / 16.0
				ell.append(Vector2(ecx + cos(ang) * rr * 0.32, y + sin(ang) * rr))
			draw_colored_polygon(ell, Color(paper.lightened(0.06), a))
			var sp := PackedVector2Array()
			for k in 25:
				var t := float(k) / 24.0
				var rad := lerpf(rr * 0.95, ROLL_R1 * u * 0.7, t)
				var ang2 := spin + t * TAU * turns
				sp.append(Vector2(ecx + cos(ang2) * rad * 0.32, y + sin(ang2) * rad))
			draw_polyline(sp, Color(broc.darkened(0.45), 0.6 * a), maxf(1.0, 0.7 * u), true)
	# coiffes (jiku) : petits embouts d'or, filets qui tournent, reflet
	var kw := 5.0 * u
	for side in 2:
		var ex2 := x0 if side == 0 else x1
		var kn := Rect2(Vector2(ex2 - kw * 0.5, y - kr), Vector2(kw, kr * 2.0))
		draw_style_box(UiKit.box(_sb, Color(GOLD_CAP, a), maxi(1, int(2.0 * u)), Color(GOLD_CAP.darkened(0.45), 0.8 * a), maxi(1, int(0.8 * u))), kn)
		for k in 4:
			var th2 := spin + TAU * float(k) / 4.0
			var cz2 := cos(th2)
			if cz2 <= 0.15:
				continue
			var yg := y + kr * 0.8 * sin(th2)
			draw_line(Vector2(kn.position.x + 1.0 * u, yg), Vector2(kn.end.x - 1.0 * u, yg), Color(GOLD_CAP.darkened(0.3), 0.5 * cz2 * a), maxf(1.0, 0.7 * u))
		draw_line(Vector2(kn.position.x + 1.0 * u, y - kr * 0.5), Vector2(kn.end.x - 1.0 * u, y - kr * 0.5), Color(1, 1, 1, 0.4 * a), maxf(1.0, 0.8 * u))


## Écrase horizontalement autour du centre (retournement de carte).
func _squash(c: Vector2, sx: float) -> Transform2D:
	return Transform2D(Vector2(sx, 0), Vector2(0, 1), Vector2(c.x * (1.0 - sx), 0))


## Dos du légendaire : bord d'or, fond noir, liseré d'or, ensō doré qui se trace (une fois déroulé au kakemono).
func _back(r: Rect2, u: float, a: float, i: int) -> void:
	var st := _sty()
	var radius := int((2.0 if st == 0 else (4.0 if st == 1 else 8.0)) * u)
	var pr := _paper(r) if st == 0 else r
	if pr.size.y > 1.0:
		UiKit.box(_sb, Color(LEG_BODY.lerp(GOLD_HI, 0.22), a), radius, Color(GOLD_HI, a), maxi(1, int(1.5 * u)))
		_shadow(u, a)
		draw_style_box(_sb, pr)
		var m := 4.0 * u
		var hp := Rect2(pr.position + Vector2(m, 5.0 * u), Vector2(pr.size.x - 2.0 * m, minf(_cut, r.end.y - 5.0 * u) - pr.position.y - 5.0 * u))
		if hp.size.y > 0.5:
			draw_style_box(UiKit.box(_sb, Color(LEG_BODY, a), maxi(0, radius - int(3 * u))), hp)
	if st == 0:
		_rod(r.position.x, r.end.x, r.position.y + 1.0 * u, u, a)
	var c := r.get_center()
	var dim := minf(r.size.x, r.size.y)
	a *= _rv(c.y + dim * 0.36 + 4.0 * u)  # l'ensō paraît une fois déroulé
	if a <= 0.01:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	draw_circle(c, dim * 0.44, Color(GOLD_HI, (0.06 + 0.06 * pulse) * a))
	var k0: float = ROLL_AT + 0.12 if st == 0 else 0.04
	var k := UiKit.ease_out((_t - _unroll_start(i) - k0) / 0.4)
	var start := -PI * 0.5 + 0.35
	var end := start + (TAU - 0.55) * maxf(k, 0.02)
	draw_arc(c, dim * 0.32, start, end, 48, Color(GOLD_HI, a), 6.0 * u)
	draw_arc(c, dim * 0.32 - 5 * u, start + 0.3, maxf(end - 0.2, start + 0.31), 40, Color(GOLD_HI, 0.35 * a), 2.0 * u)
	# rayons qui tournent
	for ray in 12:
		var ang := _t * 0.6 + TAU * float(ray) / 12.0
		var d := Vector2(cos(ang), sin(ang))
		draw_line(c + d * dim * 0.4, c + d * dim * 0.48, Color(GOLD_HI, 0.3 * a), 1.5 * u)


## Dos d'une carte donnée face cachée : ofuda (laque, filet et mon d'or), estampe (vagues indigo et sceau).
func _back_print(r: Rect2, u: float, a: float, st: int) -> void:
	var c := r.get_center()
	var dim := minf(r.size.x, r.size.y)
	if st == 1:
		UiKit.box(_sb, Color(OFUDA_BODY, a), int(4 * u), Color(GOLD_HI, 0.5 * a), maxi(1, int(1.2 * u)))
		_shadow(u, a)
		draw_style_box(_sb, r)
		draw_rect(r.grow(-5.0 * u), Color(GOLD_HI, 0.45 * a), false, maxf(1.0, 0.8 * u))
		UiKit.mon(self, c, dim * 0.24, "tomoe", Color(GOLD_HI, 0.55 * a))
		return
	UiKit.box(_sb, Color(Toon.PAPER, a), int(8 * u), Color(Toon.SUMI, 0.85 * a), maxi(1, int(1.5 * u)))
	_shadow(u, a)
	draw_style_box(_sb, r)
	var inner := r.grow(-5.0 * u)
	draw_style_box(UiKit.box(_sb, Color(Toon.PRUSSIAN, a), int(5 * u)), inner)
	UiKit.seigaiha(self, inner.grow(-3.0 * u), Color(Toon.WASHI, 0.22 * a), 8.0 * u)
	var sr := Rect2(c - Vector2(12.0, 14.0) * u, Vector2(24.0, 28.0) * u)
	UiKit.seal(self, sr, "印", Toon.VERMILION, Toon.WASHI, a, u, 3.0)


# ------------------------------------------------------------------ style 0 : kakemono épuré

## Face du kakemono : monture de soie, bandes ten / chi à la couleur de rareté, papier entre deux fines bandes
## ichimonji (seul le déroulé se voit), baguette du haut, contenu, rareté en clair sur la bande du bas, reflet.
func _face(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int) -> void:
	var rank := int(info.get("rarity_rank", -1))
	var leg := rank == 3
	var rc: Color = info.get("rarity_color", Color(0.5, 0.5, 0.5))
	var body := _body_col(info)
	var band := _band_col(info)
	var s := minf(u, r.size.x / 116.0)
	var radius := int(2 * u)
	var pr := _paper(r)
	var shown := pr.size.y > 4.0 * u
	if shown:
		if rank >= 2:
			_glow(pr, GOLD_HI if leg else rc, 2, radius, u, a, i)
		_halo(pr, Toon.VERMILION if rank < 0 else GOLD_HI, radius, u, a, i)
	if pr.size.y > 1.0:
		UiKit.box(_sb, Color(_mount_col(info), a), radius, Color(0, 0, 0, 0.22 * a), 1)
		_shadow(u, a)
		draw_style_box(_sb, pr)
		var ten := _ten(s, true)
		var chi := _chi(s, true)
		var ichi := 2.5 * s
		var side := 6.0 * s
		# ten : bande du haut
		draw_rect(Rect2(pr.position, Vector2(pr.size.x, minf(ten, pr.size.y))), Color(band, a))
		# papier (honshi) entre deux fines bandes ichimonji, marges de soie de part et d'autre
		var top := r.position.y + ten
		var bot := minf(_cut, r.end.y - chi)
		if bot > top + 0.5:
			var gold: Color = Color(GOLD_HI, 0.8) if leg else Color(band.lerp(GOLD_HI, 0.45), 0.85)
			var x0 := r.position.x + side
			var wd := r.size.x - 2.0 * side
			var ph := minf(bot, r.end.y - chi - ichi) - top - ichi
			if ph > 0.0:
				draw_rect(Rect2(Vector2(x0, top + ichi), Vector2(wd, ph)), Color(body, a))
			draw_rect(Rect2(Vector2(x0, top), Vector2(wd, minf(ichi, bot - top))), Color(gold, gold.a * a))
			if _cut >= r.end.y - chi:
				draw_rect(Rect2(Vector2(x0, r.end.y - chi - ichi), Vector2(wd, ichi)), Color(gold, gold.a * a))
		# chi : bande du bas, une fois déroulée
		var cb := _cut - (r.end.y - chi)
		if cb > 0.0:
			draw_rect(Rect2(Vector2(r.position.x, r.end.y - chi), Vector2(r.size.x, minf(cb, chi))), Color(band, a))
	# baguette du haut
	_rod(r.position.x, r.end.x, r.position.y + 1.0 * u, u, a)
	_content(r, info, id, u, a, i, true)
	# rareté en clair, petites capitales sur la bande du bas
	if rank >= 0:
		var ta := a * UiKit.ease_out((_ct - TXT_AT) / TXT_DUR)
		var chi2 := _chi(s, true)
		var rf := maxi(9, int(10.0 * s))
		var ry := r.end.y - chi2 * 0.5 - 1.5 * u + float(rf) * 0.36
		var rcol: Color = GOLD_HI if leg else Color(Toon.WASHI, 0.85)
		_rarity_word(info, r.get_center().x, ry, r.size.x - 14.0 * s, rf, Color(rcol, rcol.a * ta * _rv(r.end.y - 3.0 * u)))
	if shown:
		_sheen_pass(pr, u, a, rank)


## Hauteur utile d'une carte (le contenu mesuré sans être dessiné) : la carte s'arrête sous son contenu.
var _extra := 0.0  # place en plus quand la carte est allongée (répartie dans le contenu)


func _need_h(info: Dictionary, id: String, cw: float, u: float, i: int) -> float:
	var r := Rect2(Vector2.ZERO, Vector2(cw, 2000.0))
	var st := _sty()
	if st == 1:
		return _content_ofuda(r, info, id, u, 0.0, i, false)
	if st == 2:
		return _content_print(r, info, id, u, 0.0, i, false)
	return _content(r, info, id, u, 0.0, i, false) + 4.0 * u  # place du rouleau du bas


## Étiquette discrète NOUVEAU, ou « NIV 1 → 2 » pour une amélioration.
func _tag_text(info: Dictionary) -> String:
	if bool(info.get("is_new", true)):
		return "NOUVEAU"
	return "NIV %d → %d" % [int(info.get("cur_level", 0)), int(info.get("level", 1))]


## Taille d'une petite ligne qui rétrécit (jusqu'à lo px) pour tenir dans maxw.
func _fit_fs(font: Font, txt: String, fs: int, maxw: float, lo := 9) -> int:
	var f := fs
	while f > lo and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > maxw:
		f -= 1
	return f


## Mot de rareté (COMMUN, RARE…) centré, rétréci s'il déborde.
func _rarity_word(info: Dictionary, cx: float, y: float, maxw: float, fs: int, c: Color) -> void:
	var rn := String(info.get("rarity_name", ""))
	if rn == "" or c.a <= 0.01:
		return
	UiKit.text(self, _ui, rn, Vector2(cx, y), _fit_fs(_ui, rn, fs, maxw), c)


## Nom d'une carte : une ligne si possible, sinon deux plus petites ; rétrécit jusqu'à tenir (jamais coupé).
## Renvoie [lignes, taille].
func _name_fit(font: Font, nm: String, fs0: int, maxw: float) -> Array:
	var fs := fs0
	var lines := _wrap(font, nm, fs, maxw)
	if lines.size() > 1:
		fs = maxi(10, int(float(fs0) * 0.8))
		lines = _wrap(font, nm, fs, maxw)
	while lines.size() > 2 and fs > 9:
		fs -= 1
		lines = _wrap(font, nm, fs, maxw)
	lines = lines.slice(0, 2)
	for k in lines.size():
		fs = _fit_fs(font, lines[k], fs, maxw)
	return [lines, fs]


## Nom centré (une ou deux lignes) à partir de y0 ; renvoie la ligne de base de la dernière ligne.
func _name_block(font: Font, nm: String, cx: float, y0: float, maxw: float, fs0: int, col: Color, a: float, really: bool) -> float:
	var fit := _name_fit(font, nm, fs0, maxw)
	var lines: PackedStringArray = fit[0]
	var fs: int = fit[1]
	var y := y0
	for k in lines.size():
		y += float(fs) * (0.95 if k == 0 else 1.1)
		if really:
			UiKit.text(self, font, lines[k], Vector2(cx, y), fs, Color(col, col.a * a * _rv(y + float(fs) * 0.3)))
	return y


# ------------------------------------------------------------------ effet en pastilles (cartes et bulle)

var _fx_res := 0.0  # hauteur commune du bloc d'effet des cartes (les pieds restent alignés d'une carte à l'autre)


## Effet de la carte en pastilles [pictogramme, valeur, libellé] (fourni par powers.describe, sinon calculé).
func _fx_of(id: String, info: Dictionary) -> Array:
	var rows: Array = info.get("fx", [])
	if rows.is_empty():
		rows = UiKit.fx_rows(id, int(info.get("cur_level", 0)), int(info.get("level", 1)))
	return rows


## Largeur des pastilles sur une carte de largeur cw (la même pour les trois styles : mesure commune).
func _fx_w(cw: float, s: float) -> float:
	return cw - 14.0 * s


## Valeur d'une pastille en (x, y) : le chiffre en gras et en couleur ; « avant → » plus petit et pâle (amélioration).
## Renvoie sa largeur ; really = false : mesure seulement.
func _fx_val(v: String, x: float, y: float, fs: int, ink: Color, accent: Color, really: bool) -> float:
	var head := ""
	var tail := v
	var k := v.find(" → ")
	if k >= 0:
		head = v.substr(0, k + 3)
		tail = v.substr(k + 3)
	var sfs := maxi(9, int(float(fs) * 0.72))
	var hw := _ui.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x if head != "" else 0.0
	var tw := _ui.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 0.7
	if really:
		if head != "":
			draw_string(_ui, Vector2(x, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(ink, ink.a * 0.6))
		draw_string(_ui, Vector2(x + hw, y), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, accent)
		draw_string(_ui, Vector2(x + hw + 0.7, y), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, accent)
	return hw + tw


## Mise en page d'une pastille dans la largeur w (chiffre de taille `big` × s) :
## [valeur, libellé, taille du chiffre, libellé à côté ?, hauteur, taille du libellé].
## Sans chiffre (« étourdit ») : le libellé tient lieu de valeur.
func _fx_fit(row: Array, w: float, s: float, big: float) -> Array:
	var v := String(row[1])
	var lab := String(row[2])
	var vfs := _fs(big, s)
	if v == "":
		v = lab
		lab = ""
		vfs = _fs(big * 0.82, s)
	var pad := 5.0 * s
	var ir := big * 0.43 * s
	var room := w - 2.0 * pad - 2.0 * ir - 4.0 * s
	while vfs > 11 and _fx_val(v, 0.0, 0.0, vfs, Color.WHITE, Color.WHITE, false) > room:
		vfs -= 1
	var vw := _fx_val(v, 0.0, 0.0, vfs, Color.WHITE, Color.WHITE, false)
	var lfs := _fs(big * 0.68, s)
	var lw := _ui.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x if lab != "" else 0.0
	var inl := lab == "" or vw + 5.0 * s + lw <= room
	if not inl:
		lfs = _fit_fs(_ui, lab, lfs, w - 2.0 * pad, 9)
	var h := float(vfs) * 1.1 + 7.0 * s
	if not inl:
		h = float(vfs) + float(lfs) + 8.0 * s
	return [v, lab, vfs, inl, h, lfs]


## Une pastille (rect) : fond teinté, pictogramme et chiffre centrés, libellé à côté ou dessous (encre pâle).
func _fx_draw(icon: String, lay: Array, rect: Rect2, s: float, big: float, ink: Color, accent: Color, icol: Color, tint: Color, bg: Color, ka: float) -> void:
	if ka <= 0.01:
		return
	draw_style_box(UiKit.box(_sb, Color(tint, tint.a * ka), maxi(1, int(6.0 * s))), rect)
	var v := String(lay[0])
	var lab := String(lay[1])
	var vfs := int(lay[2])
	var inl := bool(lay[3])
	var lfs := int(lay[5])
	var ir := big * 0.43 * s
	var vw := _fx_val(v, 0.0, 0.0, vfs, ink, accent, false)
	var lw := _ui.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x if lab != "" else 0.0
	var cw := 2.0 * ir + 4.0 * s + vw
	if inl and lab != "":
		cw += 5.0 * s + lw
	var x := rect.get_center().x - cw / 2.0
	var cy := rect.get_center().y if inl else rect.position.y + 4.0 * s + float(vfs) * 0.5
	UiKit.glyph(self, icon, Vector2(x + ir, cy), ir, icol, bg, ka)
	_fx_val(v, x + 2.0 * ir + 4.0 * s, cy + float(vfs) * 0.36, vfs, Color(ink, ink.a * ka), Color(accent, accent.a * ka), true)
	if lab == "":
		return
	var lc := Color(ink, ink.a * 0.68 * ka)
	if inl:
		draw_string(_ui, Vector2(x + 2.0 * ir + 4.0 * s + vw + 5.0 * s, cy + float(lfs) * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, lc)
	else:
		UiKit.text(self, _ui, lab, Vector2(rect.get_center().x, rect.position.y + 5.0 * s + float(vfs) + float(lfs) * 0.8), lfs, lc)


## Pastilles d'une carte (les 2 premières), mises en page dans la largeur w.
func _fx_lay(rows: Array, w: float, s: float) -> Array:
	var out: Array = []
	for k in mini(rows.size(), 2):
		out.append(_fx_fit(rows[k], w, s, 15.0))
	return out


## Hauteur naturelle des pastilles d'une carte (écart de 4 × s entre deux).
func _fx_lay_h(lay: Array, s: float) -> float:
	var hh := 0.0
	for k in lay.size():
		var lk: Array = lay[k]
		hh += float(lk[4]) + (4.0 * s if k > 0 else 0.0)
	return hh


## Bloc d'effet d'une carte à partir de y (haut), centré en cx : au plus 2 pastilles l'une sous l'autre, centrées
## dans la hauteur commune _fx_res. icol : pictogrammes ; tint : fond des pastilles ; bg : découpes des pictogrammes.
## Renvoie le bas du bloc ; really = false : mesure seulement.
func _fx_block(id: String, info: Dictionary, cx: float, y: float, w: float, s: float, ink: Color, accent: Color, icol: Color, tint: Color, bg: Color, a: float, really: bool) -> float:
	var rows := _fx_of(id, info)
	var lay := _fx_lay(rows, w, s)
	var hh := _fx_lay_h(lay, s)
	if really:
		var yy := y + maxf(0.0, _fx_res - hh) * 0.5
		for k in lay.size():
			var lk: Array = lay[k]
			var rw: Array = rows[k]
			var rect := Rect2(Vector2(cx - w / 2.0, yy), Vector2(w, float(lk[4])))
			_fx_draw(String(rw[0]), lk, rect, s, 15.0, ink, accent, icol, tint, bg, a * _rv(rect.end.y))
			yy += float(lk[4]) + 4.0 * s
	return y + maxf(hh, _fx_res)


## Déclencheur en pictogramme seul (coin du tableau, bord du médaillon) : sceau de la figure, sinon pastille d'encre.
func _trig_badge(id: String, c: Vector2, rr: float, leg: bool, a: float) -> void:
	if a <= 0.01:
		return
	var fig := UiKit.trigger_figure(id)
	if fig != "":
		UiKit.figure(self, fig, c, rr, a)
		return
	var disc: Color = GOLD_HI if leg else Toon.SUMI
	draw_circle(c, rr + maxf(1.0, rr * 0.14), Color(Toon.PAPER, 0.95 * a))
	draw_circle(c, rr, Color(disc, a))
	UiKit.trigger_icon(self, id, c, rr * 0.62, LEG_BODY if leg else Toon.WASHI, disc, a)


## Crans de niveau en points : pris (encre), gagné maintenant (or), à venir (cercle). Rien au niveau unique.
func _pips(info: Dictionary, cx: float, y: float, s: float, ink: Color, a: float, pulse: float) -> void:
	var mx := int(info.get("max_level", 1))
	if mx <= 1 or a <= 0.01:
		return
	var lv := int(info.get("level", 1))
	var cur := int(info.get("cur_level", 0))
	var step := 9.0 * s
	var x0 := cx - step * float(mx - 1) / 2.0
	for k in mx:
		var pc := Vector2(x0 + float(k) * step, y)
		if k < cur:
			draw_circle(pc, 2.6 * s, Color(ink, 0.75 * a))
		elif k < lv:
			draw_circle(pc, 3.0 * s, Color(GOLD_HI.lerp(GOLD_HI.lightened(0.35), pulse), a))
		else:
			draw_arc(pc, 2.4 * s, 0.0, TAU, 12, Color(ink, 0.35 * a), maxf(1.0, 1.0 * s), true)


## Pied d'une carte : filet, élément (pictogramme et nom) et ses points, bonus d'élément, synergie.
## Renvoie la ligne suivante (y) ; really = false : mesure seulement.
func _footer(r: Rect2, info: Dictionary, id: String, i: int, cx: float, y0: float, s: float, ink: Color, dark: bool, rule: Color, a: float, really: bool) -> float:
	var school := String(info.get("school", ""))
	if school == "":
		return y0
	var y := y0
	var cap := _fs(11.0, s)
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)
	if really and rule.a > 0.0:
		draw_line(Vector2(r.position.x + 12.0 * s, y), Vector2(r.end.x - 12.0 * s, y), Color(rule, rule.a * a * _rv(y + 2.0 * s)), 1.0)
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
		var ka2 := a * _rv(y + 15.0 * s)
		var maxw := r.size.x - 12.0 * s - pw
		var ef := cap
		while ef > 10 and _ui.get_string_size(el, HORIZONTAL_ALIGNMENT_LEFT, -1, ef).x + 19.0 * s > maxw:
			ef -= 1
		if school != "ink":  # pouvoir général (sans élément) : pied vide, la carte garde sa hauteur
			_icon_line(el, school, scol, cx - pw / 2.0, y + 9.0 * s, maxw, ef, s, Color(ink, 0.88 * ka2), ka2, dark)
		if pips > 0:
			var tw2 := _ui.get_string_size(el, HORIZONTAL_ALIGNMENT_LEFT, -1, ef).x + 19.0 * s
			var px := cx - pw / 2.0 + tw2 / 2.0 + 6.0 * s + 4.5 * s
			var filled := mini(int(info.get("aff_next", 0)), goal)
			if bool(info.get("aff_done", false)):
				filled = goal
			for k in pips:
				var pc := Vector2(px + float(k) * 9.0 * s, y + 9.0 * s)
				if k < filled:
					draw_circle(pc, 3.4 * s, Color(scol.lightened(0.15) if dark else scol, ka2))
				else:
					draw_arc(pc, 3.0 * s, 0.0, TAU, 14, Color(ink, 0.45 * ka2), maxf(1.0, 1.2 * s), true)
	y += 18.0 * s
	if goal > 0 and school != "ink" and school != "fig" and bool(info.get("aff_hit", false)):
		# le bonus d'élément tombe avec ce choix : gélule d'or
		var tiers: Array = Data.AFF_TIERS
		var tier := maxi(0, tiers.find(goal))
		var shorts: Array = Data.AFF_SHORT.get(school, [])
		var bonus := "BONUS ! "
		if tier < shorts.size():
			bonus += _p(String(shorts[tier]))
		var bf := _fit_fs(_ui, bonus, cap, r.size.x - 20.0 * s, 9)
		if really:
			var bw2 := _ui.get_string_size(bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, bf).x + 12.0 * s
			var pl := Rect2(Vector2(cx - bw2 / 2.0, y), Vector2(bw2, 17.0 * s))
			var kb := a * _rv(pl.end.y)
			draw_style_box(UiKit.box(_sb, Color(GOLD_HI, kb * (0.85 + 0.15 * pulse)), 999), pl)
			UiKit.text(self, _ui, bonus, Vector2(cx, pl.get_center().y + float(bf) * 0.36), bf, Color(LEG_BODY, kb))
		y += 20.0 * s
	if bool(info.get("synergy_on", false)) or _has_link(i, "syn"):
		if really:
			var sc: Color = GOLD_HI if dark or Toon.ui_dark else Color("#9A6B12")
			_fit_center("+ Élément actif" if school == "fig" else "+ Synergie active", cx, y + 12.0 * s, r.size.x - 10.0 * s, cap, Color(sc, a * _rv(y + 15.0 * s)))
		y += 17.0 * s
	return y


## Contenu du kakemono, de haut en bas : étiquette NOUVEAU / NIV sur la bande du haut, médaillon (un cercle
## d'encre au pinceau, lavis et pictogramme de l'élément), crans, nom calligraphié, une ligne de valeur, pied
## discret (élément et points). really = false : mesure seulement. Renvoie la hauteur occupée (bande du bas comprise).
func _content(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int, really: bool) -> float:
	var rank := int(info.get("rarity_rank", -1))
	var leg := rank == 3
	var is_curse := String(info.get("kanji", "")) == "鬼"
	var is_pass := rank < 0 and not is_curse
	var dark := leg or rank < 0
	var ink: Color = Toon.WASHI if dark else Toon.ui_ink
	var col: Color = info.get("color", Toon.SUMI)
	var s := minf(u, r.size.x / 116.0)  # échelle du contenu (cartes plus étroites sur petit écran)
	var cx := r.position.x + r.size.x / 2.0
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)
	var cap := _fs(11.0, s)
	var ex := _extra if really else 0.0
	var ten := _ten(s, really)
	# apparition : chaque élément paraît une fois sorti du rouleau (_rv) ; le médaillon « pope » au passage du
	# rouleau. Légendaire retourné : le médaillon pope, puis le texte se fond (temps _ct).
	var pk := (_ct - POP_AT) / POP_DUR
	var ta := a * UiKit.ease_out((_ct - TXT_AT) / TXT_DUR)

	# étiquette NOUVEAU / NIV 1 → 2, en petites capitales sur la bande du haut
	if rank >= 0 and really:
		var rt := _tag_text(info)
		var is_new := bool(info.get("is_new", true))
		var rcol: Color = GOLD_HI if leg else (Toon.WASHI if is_new else UP_COL.lightened(0.5))
		var rf := _fit_fs(_ui, rt, maxi(9, cap - 2), r.size.x - 26.0 * s, 8)
		var by := r.position.y + 1.0 * u + ten * 0.5
		var ka := ta * _rv(r.position.y + ten)
		var tw0 := UiKit.text(self, _ui, rt, Vector2(cx, by + float(rf) * 0.36), rf, Color(rcol, 0.95 * ka))
		if is_new and not leg:
			draw_circle(Vector2(cx - tw0 / 2.0 - 5.0 * s, by), 1.8 * s, Color(Toon.VERMILION.lightened(0.15), ka))

	var y := r.position.y + ten + 2.5 * s + 14.0 * s + ex * 0.3
	# médaillon épuré : lavis de l'élément, cercle d'encre au pinceau (ensō fin), pictogramme
	var big := _big * 0.8
	var mc := Vector2(cx, y + big)
	var mk := minf(pk, (_cut + _ahead - (mc.y + big + 4.0 * u)) / (big * 2.0))  # sorti du rouleau, il pope
	var ma := a * UiKit.ease_out(mk / 0.4)
	if really:
		draw_set_transform_matrix(_xf * _about(mc, 0.6 + 0.4 * _settle(mk, 1.6)))
		var mcol: Color = CURSE_COL.lightened(0.25) if is_curse else (Color("#8C8FA8") if is_pass else col)
		var wash := _body_col(info).lerp(mcol, 0.2 if dark else 0.12)
		draw_circle(mc, big, Color(wash, ma))
		var ring: Color = GOLD_HI if leg else Color(ink, 0.8)
		UiKit.enso(self, mc, big + 2.0 * s, 2.6 * s, Color(ring, ring.a * ma), 1.0, -PI * 0.35)
		if leg:
			for ray in 10:
				var ang := _t * 0.5 + TAU * float(ray) / 10.0
				var d := Vector2(cos(ang), sin(ang))
				draw_line(mc + d * (big + 6.0 * s), mc + d * (big + 10.0 * s), Color(GOLD_HI, 0.4 * ma), maxf(1.0, 1.4 * s))
		# chaque malédiction a son pictogramme (encre sèche, œil d'oni, pas lourd, hâte des morts)
		var gname := String(info.get("icon", "oni")) if is_curse else ("path" if is_pass else UiKit.icon_of(id))
		var gcol: Color = GOLD_HI if leg else (Toon.WASHI if rank < 0 else mcol.darkened(0.08))
		UiKit.glyph(self, gname, mc, big * 0.6, gcol, wash, ma)
		draw_set_transform_matrix(_xf)
		if rank >= 0:
			# déclencheur : pictogramme seul, en haut à droite du médaillon
			_trig_badge(id, mc + Vector2(big * 0.8, -big * 0.8), 7.5 * s, leg, ma)
	y = mc.y + big + 12.0 * s

	# crans de niveau (même place sur toutes les cartes : tout reste aligné)
	if rank >= 0:
		if really:
			_pips(info, cx, y, s, ink, ta * _rv(y + 3.0 * s), pulse)
		y += 8.0 * s
	# nom calligraphié, petit trait de pinceau dessous
	var nm := _p(String(info.get("name", ""))) if rank < 0 else UiKit.power_label(id)
	y = _name_block(UiKit.TITLE_FONT, nm, cx, y, r.size.x - 16.0 * s, int(17 * s), GOLD_HI if leg else ink, ta, really)
	if really:
		var kl := ta * _rv(y + 8.0 * s)
		draw_line(Vector2(cx - 10 * s, y + 7 * s), Vector2(cx + 10 * s, y + 7 * s), Color(GOLD_HI if dark else Toon.VERMILION, 0.7 * kl), maxf(1.0, 1.5 * s))
	y += 24.0 * s
	var tw := r.size.x - 16.0 * s
	if rank < 0:
		y = _curse_lines(String(info.get("text", "")), cx, y, tw, cap, 14.5 * s, ta, is_curse, really)
		return y - r.position.y + _chi(s, false) + 6.0 * s
	# l'effet en pastilles (pictogramme, chiffre, libellé)
	var accent: Color = GOLD_HI if dark or Toon.ui_dark else Toon.VERMILION.darkened(0.12)
	var icol: Color = GOLD_HI if leg else (col.lightened(0.25) if Toon.ui_dark else col)
	var tint := Color(icol, 0.1)
	var body := _body_col(info)
	y = _fx_block(id, info, cx, y - 10.0 * s, _fx_w(r.size.x, s), s, Color(ink, 0.92), accent, icol, tint, body.lerp(icol, 0.1), ta, really)
	y += 12.0 * s + ex * 0.25
	# pied discret : élément et points
	y = _footer(r, info, id, i, cx, y, s, ink, dark, Color(ink, 0.14), ta, really)
	return y - r.position.y + _chi(s, false) + 4.0 * s


# ------------------------------------------------------------------ style 1 : ofuda (talisman)

## Bord de l'ofuda selon la rareté : or (légendaire), violet (épique), indigo (rare), simple (commun).
func _ofuda_edge(rank: int, rc: Color) -> Color:
	if rank == 3:
		return GOLD_HI
	if rank == 2:
		return rc.lightened(0.15)
	if rank == 1:
		return OFUDA_INDIGO
	return Color(Toon.WASHI, 0.16)


## Ofuda : carte de laque sombre, filet d'or intérieur aux coins marqués, lueur de rareté.
func _face_ofuda(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int) -> void:
	var rank := int(info.get("rarity_rank", -1))
	var rc: Color = info.get("rarity_color", Color(0.5, 0.5, 0.5))
	var radius := int(4 * u)
	var edge := _ofuda_edge(rank, rc)
	if rank >= 1:
		_glow(r, edge, 3 if rank == 3 else 2, radius, u, a, i)
	_halo(r, GOLD_HI, radius, u, a, i)
	UiKit.box(_sb, Color(OFUDA_BODY, a), radius, Color(edge, edge.a * a), maxi(1, int((1.8 if rank >= 1 else 1.0) * u)))
	_shadow(u, a)
	draw_style_box(_sb, r)
	# laque : reflet doux sur le haut
	draw_rect(Rect2(r.position + Vector2(2.0, 2.0) * u, Vector2(r.size.x - 4.0 * u, r.size.y * 0.3)), Color(1, 1, 1, 0.03 * a))
	# filet d'or intérieur, coins marqués d'un petit carré
	var ib := r.grow(-5.0 * u)
	var ga := (0.9 if rank == 3 else 0.5) * a
	draw_rect(ib, Color(GOLD_HI, ga), false, maxf(1.0, 0.8 * u))
	for k in 4:
		var pc := Vector2(ib.position.x if k % 2 == 0 else ib.end.x, ib.position.y if k < 2 else ib.end.y)
		draw_rect(Rect2(pc - Vector2(1.8, 1.8) * u, Vector2(3.6, 3.6) * u), Color(GOLD_HI, ga))
	_content_ofuda(r, info, id, u, a, i, true)
	_sheen_pass(r, u, a, rank)


## Contenu de l'ofuda : étiquette, sceau vermillon (kanji du pouvoir), fil d'or, pictogramme d'or au trait,
## nom en blanc de washi, valeur, crans, pied, rareté. really = false : mesure seulement.
func _content_ofuda(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int, really: bool) -> float:
	var rank := int(info.get("rarity_rank", -1))
	var leg := rank == 3
	var col: Color = info.get("color", Toon.SUMI)
	var s := minf(u, r.size.x / 116.0)
	var cx := r.position.x + r.size.x / 2.0
	var cap := _fs(11.0, s)
	var ex := _extra if really else 0.0
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)
	var pk := (_ct - POP_AT) / POP_DUR
	var ta := a * UiKit.ease_out((_ct - TXT_AT) / TXT_DUR)
	var ma := a * UiKit.ease_out(pk / 0.4)
	var y := r.position.y + 12.0 * s
	# étiquette NOUVEAU / NIV 1 → 2
	if rank >= 0 and really:
		var rt := _tag_text(info)
		var rf := _fit_fs(_ui, rt, maxi(9, cap - 2), r.size.x - 20.0 * s, 8)
		var rcol: Color = GOLD_HI if leg else (Toon.VERMILION.lightened(0.3) if bool(info.get("is_new", true)) else UP_COL.lightened(0.3))
		UiKit.text(self, _ui, rt, Vector2(cx, y + float(rf) * 0.8), rf, Color(rcol, ta))
	y += 15.0 * s
	# sceau vermillon : le kanji du pouvoir (un mon s'il manque à la police)
	var seal := Rect2(Vector2(cx - 11.0 * s, y), Vector2(22.0 * s, 27.0 * s))
	if really:
		var kj := String(info.get("kanji", ""))
		draw_set_transform_matrix(_xf * _about(seal.get_center(), 0.7 + 0.3 * _settle(pk, 1.8)))
		UiKit.seal(self, seal, kj.substr(0, 1), Toon.VERMILION, Toon.WASHI, ma, s, float(i) * 3.1)
		draw_set_transform_matrix(_xf)
	y = seal.end.y + 8.0 * s + ex * 0.3
	# pictogramme d'or au trait, dans deux fins cercles d'or ; lueur de l'élément derrière
	var big := _big * 0.85
	var mc := Vector2(cx, y + big)
	if really:
		draw_line(Vector2(cx, seal.end.y + 3.0 * s), Vector2(cx, mc.y - big - 3.0 * s), Color(GOLD_HI, 0.45 * ta), maxf(1.0, 0.8 * s))
		draw_set_transform_matrix(_xf * _about(mc, 0.6 + 0.4 * _settle(pk, 1.7)))
		draw_circle(mc, big * 1.25, Color(col, 0.16 * ma))
		draw_arc(mc, big, 0.0, TAU, 48, Color(GOLD_HI, 0.9 * ma), maxf(1.0, 1.3 * s), true)
		draw_arc(mc, big - 3.5 * s, 0.0, TAU, 40, Color(GOLD_HI, 0.3 * ma), maxf(1.0, 0.7 * s), true)
		if leg:
			for ray in 12:
				var ang := _t * 0.5 + TAU * float(ray) / 12.0
				var d := Vector2(cos(ang), sin(ang))
				draw_line(mc + d * (big + 4.0 * s), mc + d * (big + 9.0 * s), Color(GOLD_HI, 0.45 * ma), maxf(1.0, 1.3 * s))
		UiKit.glyph(self, UiKit.icon_of(id), mc, big * 0.56, GOLD_HI, OFUDA_BODY, ma)
		draw_set_transform_matrix(_xf)
		if rank >= 0:
			_trig_badge(id, mc + Vector2(big * 0.8, -big * 0.8), 7.5 * s, leg, ma)
	y = mc.y + big + 12.0 * s
	# nom en blanc de washi, valeur dessous
	y = _name_block(UiKit.TITLE_FONT, UiKit.power_label(id), cx, y, r.size.x - 18.0 * s, int(16 * s), Toon.WASHI, ta, really)
	y += 8.0 * s
	y = _fx_block(id, info, cx, y, _fx_w(r.size.x, s), s, Color(Toon.WASHI, 0.85), GOLD_HI, GOLD_HI, Color(Toon.WASHI, 0.06), OFUDA_BODY, ta, really)
	y += 10.0 * s
	if really:
		_pips(info, cx, y, s, Toon.WASHI, ta, pulse)
	y += 10.0 * s + ex * 0.3
	y = _footer(r, info, id, i, cx, y, s, Toon.WASHI, true, Color(GOLD_HI, 0.3), ta, really)
	# la rareté se lit au bord (or, violet, indigo, simple) : pas de mot
	return y - r.position.y + 10.0 * s


# ------------------------------------------------------------------ style 2 : estampe

## Estampe : carte de washi aux coins arrondis, fin cadre d'encre (liseré de rareté dès rare).
func _face_print(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int) -> void:
	var rank := int(info.get("rarity_rank", -1))
	var leg := rank == 3
	var rc: Color = info.get("rarity_color", Color(0.5, 0.5, 0.5))
	var radius := int(8 * u)
	if rank >= 2:
		_glow(r, GOLD_HI if leg else rc, 2, radius, u, a, i)
	_halo(r, GOLD_HI, radius, u, a, i)
	var paper: Color = LEG_BODY if leg else Toon.ui_paper
	var frame: Color = GOLD_HI if leg else Toon.SUMI
	UiKit.box(_sb, Color(paper, a), radius, Color(frame, 0.85 * a), maxi(1, int(1.5 * u)))
	_shadow(u, a)
	draw_style_box(_sb, r)
	if rank >= 1 and not leg:
		draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), maxi(1, radius - int(3 * u)), Color(rc, 0.7 * a), 1), r.grow(-3.0 * u))
	_content_print(r, info, id, u, a, i, true)
	_sheen_pass(r, u, a, rank)


## Contenu de l'estampe : tableau peint (moitié haute) et son pictogramme, étiquette et déclencheur dans les coins,
## cartouche du nom à cheval sur le bas du tableau, puis sur le washi : effet en pastilles, crans, pied, rareté.
## really = false : mesure.
func _content_print(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int, really: bool) -> float:
	var rank := int(info.get("rarity_rank", -1))
	var leg := rank == 3
	var col: Color = info.get("color", Toon.SUMI)
	var rc: Color = info.get("rarity_color", Color(0.5, 0.5, 0.5))
	var s := minf(u, r.size.x / 116.0)
	var cx := r.position.x + r.size.x / 2.0
	var cap := _fs(11.0, s)
	var ex := _extra if really else 0.0
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)
	var pk := (_ct - POP_AT) / POP_DUR
	var ta := a * UiKit.ease_out((_ct - TXT_AT) / TXT_DUR)
	var ma := a * UiKit.ease_out(pk / 0.4)
	var ink: Color = Toon.WASHI if leg else Toon.ui_ink
	var school := String(info.get("school", ""))
	var inset := 4.0 * s
	var big := _big * 0.85
	var ph := 2.0 * big + 46.0 * s + ex * 0.7
	var pr := Rect2(r.position + Vector2(inset, inset), Vector2(r.size.x - 2.0 * inset, ph))
	# cartouche du nom, mesuré d'abord : il chevauche le bas du tableau
	var fit := _name_fit(UiKit.TITLE_FONT, UiKit.power_label(id), int(15 * s), r.size.x - 26.0 * s)
	var nl: PackedStringArray = fit[0]
	var nfs: int = fit[1]
	var lw := 0.0
	for k in nl.size():
		lw = maxf(lw, UiKit.TITLE_FONT.get_string_size(nl[k], HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x)
	var chh := float(nfs) * 1.1 * float(maxi(nl.size(), 1)) + 9.0 * s
	var cwid := minf(r.size.x - 12.0 * s, lw + 18.0 * s)
	var cart := Rect2(Vector2(cx - cwid / 2.0, pr.end.y - chh * 0.45), Vector2(cwid, chh))
	if really:
		_scene(pr, school, col, leg, s, a)
		# pictogramme dans un disque de washi cerné d'encre, au milieu du tableau visible
		var mc := Vector2(cx, (pr.position.y + cart.position.y) * 0.5 + 2.0 * s)
		draw_set_transform_matrix(_xf * _about(mc, 0.6 + 0.4 * _settle(pk, 1.7)))
		draw_circle(mc + Vector2(0, 2.0 * s), big + 1.5 * s, Color(0, 0, 0, 0.18 * ma))
		draw_circle(mc, big, Color(Toon.PAPER, 0.96 * ma))
		draw_arc(mc, big, 0.0, TAU, 48, Color(Toon.SUMI, 0.85 * ma), maxf(1.0, 1.4 * s), true)
		draw_arc(mc, big - 3.0 * s, 0.0, TAU, 40, Color(GOLD_HI if leg else col, 0.55 * ma), maxf(1.0, 0.8 * s), true)
		UiKit.glyph(self, UiKit.icon_of(id), mc, big * 0.6, GOLD_HI.darkened(0.25) if leg else col, Toon.PAPER, ma)
		draw_set_transform_matrix(_xf)
		# étiquette NOUVEAU / NIV dans le coin du tableau : petit cartouche vermillon (vert d'eau : amélioration) ;
		# le déclencheur en pictogramme seul dans l'autre coin (sceau de la figure, ou pastille d'encre)
		if rank >= 0:
			_trig_badge(id, Vector2(pr.end.x - 11.0 * s, pr.position.y + 11.0 * s), 8.0 * s, leg, ma)
			var rt := _tag_text(info)
			var rf := _fit_fs(_ui, rt, maxi(9, cap - 2), pr.size.x - 38.0 * s, 8)
			var tw0 := _ui.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rf).x + 10.0 * s
			var tag := Rect2(pr.position + Vector2(4.0, 4.0) * s, Vector2(tw0, float(rf) + 5.0 * s))
			var tb: Color = GOLD_HI if leg else (Toon.VERMILION if bool(info.get("is_new", true)) else UP_COL)
			draw_style_box(UiKit.box(_sb, Color(tb, 0.92 * ta), maxi(1, int(3 * s))), tag)
			UiKit.text(self, _ui, rt, Vector2(tag.get_center().x, tag.get_center().y + float(rf) * 0.36), rf, Color(LEG_BODY if leg else Toon.WASHI, ta))
		# cartouche : washi doré, double filet d'encre, le nom
		UiKit.box(_sb, Color("#F3E6C4"), maxi(1, int(2 * s)), Color(Toon.SUMI, 0.9), maxi(1, int(1.2 * s)))
		_sb.bg_color = Color(_sb.bg_color, a)
		_sb.border_color = Color(_sb.border_color, 0.9 * a)
		draw_style_box(_sb, cart)
		draw_rect(cart.grow(-2.5 * s), Color(GOLD_HI if leg else col, 0.55 * a), false, maxf(1.0, 0.7 * s))
		var yy := cart.position.y + 4.5 * s
		for k in nl.size():
			yy += float(nfs) * (0.95 if k == 0 else 1.1)
			UiKit.text(self, UiKit.TITLE_FONT, nl[k], Vector2(cx, yy), nfs, Color(Toon.SUMI, ta))
	var y := cart.end.y + 7.0 * s
	# washi : effet en pastilles (pictogramme, chiffre en couleur, libellé court), crans, pied, rareté
	var accent: Color = GOLD_HI if leg or Toon.ui_dark else Toon.VERMILION.darkened(0.12)
	var icol: Color = GOLD_HI if leg else (col.lightened(0.25) if Toon.ui_dark else col)
	var tint := Color(icol, 0.12 if leg else 0.1)
	var paper: Color = LEG_BODY if leg else Toon.ui_paper
	y = _fx_block(id, info, cx, y, _fx_w(r.size.x, s), s, Color(ink, 0.92), accent, icol, tint, paper.lerp(icol, tint.a), ta, really)
	y += 10.0 * s
	if really:
		_pips(info, cx, y, s, ink, ta, pulse)
	y += 9.0 * s + ex * 0.2
	y = _footer(r, info, id, i, cx, y, s, ink, leg, Color(ink, 0.15), ta, really)
	var rf2 := maxi(9, int(9.5 * s))
	if rank >= 0 and really:
		var wc: Color = GOLD_HI if leg else (Color(ink, 0.45) if rank == 0 else (rc.lightened(0.2) if Toon.ui_dark else rc.darkened(0.1)))
		_rarity_word(info, cx, y + float(rf2) * 0.9, r.size.x - 16.0 * s, rf2, Color(wc, wc.a * ta))
	y += float(rf2) + 5.0 * s
	return y - r.position.y + 8.0 * s


## Rectangle aux coins arrondis, en polygone (sens horaire).
func _round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs: Array = [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for k in 4:
		var c: Vector2 = cs[k]
		for j in 5:
			var ang := -PI * 0.5 + PI * 0.5 * float(k) + PI * 0.5 * float(j) / 4.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	return pts


## Flamme en goutte posée sur base (largeur w, hauteur h), pointe penchée de lean.
func _flame(base: Vector2, w: float, h: float, lean: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 10
	for k in n + 1:
		var t := float(k) / float(n)
		var half := w * 0.5 * sin(PI * pow(1.0 - t, 2.4))
		pts.append(base + Vector2(lean * t * t + half, -h * t))
	for k in range(n - 1, 0, -1):
		var t := float(k) / float(n)
		var half := w * 0.5 * sin(PI * pow(1.0 - t, 2.4))
		pts.append(base + Vector2(lean * t * t - half, -h * t))
	draw_colored_polygon(pts, col)


## Nuage stylisé (kumo) : trois bosses sur une base plate, centré sur c, largeur ≈ 1.2 w.
func _kumo(c: Vector2, w: float, col: Color) -> void:
	draw_circle(c + Vector2(-0.35 * w, 0.0), 0.26 * w, col)
	draw_circle(c + Vector2(0.0, -0.1 * w), 0.36 * w, col)
	draw_circle(c + Vector2(0.35 * w, 0.02 * w), 0.24 * w, col)
	draw_rect(Rect2(c + Vector2(-0.6 * w, 0.0), Vector2(1.2 * w, 0.2 * w)), col)


## Tableau d'estampe : dégradé aux couleurs de l'élément, puis une petite scène (vagues seigaiha pour l'eau,
## flammes pour le feu, nuages pour le vent, éclairs pour la foudre, lune pour l'ombre, lavis pour l'encre).
func _scene(pr: Rect2, school: String, col: Color, leg: bool, s: float, a: float) -> void:
	var rad := 5.0 * s
	var top: Color = Toon.PAPER.lerp(col, 0.3)
	var bot: Color = col
	if leg:
		top = Color("#3B2F1A")
		bot = LEG_BODY
	elif school == "fire":
		top = Color("#F4D2A6")
		bot = col.darkened(0.08)
	elif school == "bolt":
		top = Color("#2B2838")
		bot = Color("#5A4E66")
	elif school == "shadow":
		top = Color("#161A2A")
		bot = Color("#3A3846")
	elif school == "ink":
		top = Toon.PAPER
		bot = Toon.PAPER.lerp(col, 0.45)
	elif school == "wind":
		top = Toon.PAPER.lerp(col, 0.2)
		bot = col.darkened(0.05)
	var pts := _round_rect(pr, rad)
	var cols := PackedColorArray()
	for k in pts.size():
		var p := pts[k]
		var f := clampf((p.y - pr.position.y) / maxf(1.0, pr.size.y), 0.0, 1.0)
		cols.append(Color(top.lerp(bot, f), a))
	draw_polygon(pts, cols)
	var x0 := pr.position.x
	var y0 := pr.position.y
	var pw := pr.size.x
	var ph := pr.size.y
	var inner := Rect2(Vector2(x0 + 1.0, y0 + rad), Vector2(pw - 2.0, ph - 2.0 * rad))
	if leg:
		UiKit.asanoha(self, inner, Color(GOLD_HI, 0.14 * a), 10.0 * s)
		var c := pr.get_center()
		var m := minf(pw, ph)
		for k in 16:
			var ang := TAU * float(k) / 16.0 + _t * 0.15
			var d := Vector2(cos(ang), sin(ang))
			draw_line(c + d * m * 0.3, c + d * m * 0.47, Color(GOLD_HI, 0.25 * a), maxf(1.0, 1.4 * s))
		return
	match school:
		"water":
			var wy := y0 + ph * 0.5
			UiKit.seigaiha(self, Rect2(Vector2(x0 + 1.0, wy), Vector2(pw - 2.0, y0 + ph - rad - wy)), Color(Toon.WASHI, 0.38 * a), 7.0 * s)
			# crête d'écume, à la Hokusai
			var crest := PackedVector2Array()
			for k in 17:
				var t := float(k) / 16.0
				crest.append(Vector2(x0 + 2.0 + t * (pw - 4.0), wy - sin(t * TAU + 0.6 + _t * 0.8) * 3.0 * s))
			draw_polyline(crest, Color(Toon.WASHI, 0.7 * a), maxf(1.0, 1.6 * s), true)
		"fire":
			for k in 6:
				var fx := x0 + pw * (0.1 + 0.16 * float(k))
				var fh := ph * (0.34 + 0.14 * sin(float(k) * 2.3 + 1.0))
				var lean := sin(_t * 2.6 + float(k) * 1.7) * 3.0 * s
				_flame(Vector2(fx, y0 + ph - rad), pw * 0.2, fh, lean, Color("#F28C38", 0.55 * a))
				_flame(Vector2(fx, y0 + ph - rad), pw * 0.11, fh * 0.6, lean * 0.6, Color("#FFD27A", 0.6 * a))
		"wind":
			for k in 3:
				var kc := Vector2(x0 + pw * (0.28 if k % 2 == 0 else 0.72), y0 + ph * (0.24 + 0.27 * float(k)))
				_kumo(kc, pw * 0.2, Color(Toon.WASHI, 0.5 * a))
			for k in 3:
				var ly := y0 + ph * (0.36 + 0.24 * float(k))
				var lx := x0 + pw * (0.08 if k % 2 == 0 else 0.5)
				draw_line(Vector2(lx, ly), Vector2(lx + pw * 0.42, ly), Color(Toon.WASHI, 0.4 * a), maxf(1.0, 1.0 * s))
		"bolt":
			UiKit.asanoha(self, inner, Color(GOLD_HI, 0.08 * a), 9.0 * s)
			for k in 2:
				var bx := x0 + pw * (0.16 if k == 0 else 0.84)
				var sd := -1.0 if k == 0 else 1.0
				var bolt := PackedVector2Array([
					Vector2(bx, y0 + rad),
					Vector2(bx + 4.0 * s * sd, y0 + ph * 0.24),
					Vector2(bx - 2.0 * s * sd, y0 + ph * 0.28),
					Vector2(bx + 5.0 * s * sd, y0 + ph * 0.55),
					Vector2(bx, y0 + ph * 0.6),
					Vector2(bx + 3.0 * s * sd, y0 + ph * 0.8),
				])
				draw_polyline(bolt, Color(GOLD_HI, 0.2 * a), maxf(1.0, 5.0 * s), true)
				draw_polyline(bolt, Color(GOLD_HI.lightened(0.2), 0.9 * a), maxf(1.0, 1.6 * s), true)
		"shadow":
			var moon := Vector2(x0 + pw * 0.76, y0 + ph * 0.27)
			var mr := pw * 0.13
			draw_circle(moon, mr * 1.5, Color("#F1E6C8", 0.08 * a))
			draw_circle(moon, mr, Color("#F1E6C8", 0.9 * a))
			draw_line(Vector2(moon.x - mr * 1.5, moon.y + mr * 0.35), Vector2(moon.x + mr * 1.3, moon.y + mr * 0.2), Color(top, 0.9 * a), maxf(1.0, 2.4 * s))
			for k in 5:
				var st := Vector2(x0 + pw * (0.1 + 0.13 * float(k)), y0 + ph * (0.14 + 0.09 * float((k * 3) % 4)))
				draw_circle(st, 0.8 * s, Color(Toon.WASHI, 0.5 * a))
			# collines en silhouette
			var hill := PackedVector2Array()
			for k in 9:
				var t := float(k) / 8.0
				hill.append(Vector2(x0 + t * pw, y0 + ph - rad - ph * (0.12 + 0.07 * sin(t * 5.3 + 0.4))))
			hill.append(Vector2(x0 + pw - rad, y0 + ph))
			hill.append(Vector2(x0 + rad, y0 + ph))
			draw_colored_polygon(hill, Color(Color("#0E0F18"), 0.75 * a))
		"ink":
			UiKit.enso(self, pr.get_center() + Vector2(0, -2.0 * s), minf(pw, ph) * 0.4, 7.0 * s, Color(Toon.SUMI, 0.18 * a), 1.0, -PI * 0.3)
			UiKit.brush_line(self, Vector2(x0 + 6.0 * s, y0 + ph - 12.0 * s), Vector2(x0 + pw - 10.0 * s, y0 + ph - 16.0 * s), 6.0 * s, Color(Toon.SUMI, 0.22 * a))
		_:
			UiKit.asanoha(self, inner, Color(Toon.WASHI, 0.25 * a), 10.0 * s)


## La carte i a-t-elle un lien de ce genre avec un pouvoir possédé ?
func _has_link(i: int, kind: String) -> bool:
	if i < 0 or i >= _links.size():
		return false
	var rel: Dictionary = _links[i]
	for oid in rel.keys():
		if String(rel[oid]) == kind:
			return true
	return false


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
					UiKit.text(self, _ui, String(line), Vector2(cx, yy), fs, Color(c, a * _rv(yy + float(fs) * 0.3)))
				yy += lh
			yy += lh * 0.4
	else:
		for line in _wrap(_ui, t, fs, width).slice(0, 3):
			if really:
				UiKit.text(self, _ui, String(line), Vector2(cx, yy), fs, Color(Toon.WASHI, (0.85 if is_curse else 0.7) * a * _rv(yy + float(fs) * 0.3)))
			yy += lh
	return yy


# ------------------------------------------------------------------ bulle de détail

## Hauteur de la bulle de détail d'une carte (le contenu mesuré sans être dessiné).
func _bubble_h(info: Dictionary, id: String, bw: float, u: float) -> float:
	return _bubble_body(Rect2(Vector2.ZERO, Vector2(bw, 4000.0)), info, id, u, 0.0, false)


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


## Pastilles de la bulle côte à côte (toutes, jusqu'à 3), de même hauteur ; renvoie le bas de la rangée.
func _bubble_fx(rows: Array, x: float, y: float, tw: float, u: float, ink: Color, accent: Color, icol: Color, tint: Color, bg: Color, a: float, really: bool) -> float:
	var n := mini(rows.size(), 3)
	if n == 0:
		return y
	var gap := 6.0 * u
	var cwd := (tw - gap * float(n - 1)) / float(n)
	var lay: Array = []
	var hh := 0.0
	for k in n:
		var lk := _fx_fit(rows[k], cwd, u, 17.0)
		lay.append(lk)
		hh = maxf(hh, float(lk[4]))
	if really:
		for k in n:
			var lk2: Array = lay[k]
			var rw: Array = rows[k]
			var rect := Rect2(Vector2(x + float(k) * (cwd + gap), y), Vector2(cwd, hh))
			_fx_draw(String(rw[0]), lk2, rect, u, 17.0, ink, accent, icol, tint, bg, a)
	return y + hh


## Bonus d'élément en une ligne courte : « Harmonie 1/2 → Feu +25 % », « Harmonie ! Feu +25 % » ; [texte, atteint ?].
func _harmony_line(info: Dictionary) -> Array:
	var goal := int(info.get("aff_goal", 0))
	var school := String(info.get("school", ""))
	if goal <= 0:
		return ["", false]
	var tiers: Array = Data.AFF_TIERS
	var tier := maxi(0, tiers.find(goal))
	var shorts: Array = Data.AFF_SHORT.get(school, [])
	var bonus := _p(String(shorts[tier])) if tier < shorts.size() else _p(String(info.get("aff_text", "")))
	if bonus == "":
		return ["", false]
	if bool(info.get("aff_hit", false)):
		return ["Harmonie ! " + bonus, true]
	if bool(info.get("aff_done", false)):
		return ["Harmonie complète : " + bonus, true]
	return ["Harmonie %d/%d → %s" % [mini(int(info.get("aff_next", 0)), goal), goal, bonus], false]


## Contenu de la bulle ; really = false : mesure seulement. Renvoie la hauteur occupée.
## Pouvoir : titre, pastilles d'effet (avant → après pour une amélioration), déclencheur (pictogramme et 1-2 mots)
## suivi d'une phrase courte, puis harmonie et synergie en une ligne chacune. Sanctuaire : le texte du pacte.
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
	if rank < 0:
		# sanctuaire : le pacte en une ou deux phrases
		var body := _wrap(_ui, _p(String(info.get("text", ""))), bfs, tw)
		var lh := float(bfs) * 1.3
		y += 2.0 * u
		for k in mini(body.size(), 3):
			y += lh
			if really:
				draw_string(_ui, Vector2(x, y), body[k], HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(ink, 0.85 * a))
		return y - box.position.y + pad * 0.9
	# l'effet en pastilles, côte à côte
	y += 10.0 * u
	var icol: Color = col.lightened(0.25) if nite else col
	y = _bubble_fx(_fx_of(id, info), x - 2.0 * u, y, tw + 4.0 * u, u, ink, accent, icol, Color(icol, 0.1), Toon.ui_paper.lerp(icol, 0.1), a, really)
	# déclencheur (pictogramme et 1-2 mots), puis une phrase courte à côté
	y += 8.0 * u
	var when := UiKit.fx_when(id)
	var fig := UiKit.trigger_figure(id)
	var chip_w := minf(_ui.get_string_size(when, HORIZONTAL_ALIGNMENT_LEFT, -1, cap).x + 34.0 * u, tw * 0.45)
	var chip := Rect2(Vector2(x, y), Vector2(chip_w, 22.0 * u))
	if really:
		draw_style_box(UiKit.box(_sb, Color(ink, a), 999), chip)
		var ic := Vector2(chip.position.x + 12.0 * u, chip.get_center().y)
		if fig != "":
			UiKit.figure(self, fig, ic, 8.0 * u, a)
		else:
			UiKit.trigger_icon(self, id, ic, 6.5 * u, Toon.ui_wash, ink, a)
		_line_fit(when, Vector2(chip.position.x + 25.0 * u, chip.get_center().y + float(cap) * 0.36), chip.size.x - 31.0 * u, cap, Color(Toon.ui_wash, a))
	var lx := chip.end.x + 9.0 * u
	var lines := _wrap(_ui, UiKit.fx_line(id), bfs, box.end.x - pad - lx)
	var nl := mini(lines.size(), 2)
	var llh := float(bfs) * 1.2
	var by := chip.get_center().y + float(bfs) * 0.36 - llh * 0.5 * float(maxi(nl - 1, 0))
	if really:
		for k in nl:
			_line_fit(lines[k], Vector2(lx, by + float(k) * llh), box.end.x - pad - lx, bfs, Color(ink, 0.8 * a))
	y = maxf(chip.end.y, by + float(maxi(nl - 1, 0)) * llh + float(bfs) * 0.3)
	# harmonie (bonus d'élément) : une ligne, pastille de l'élément
	var school := String(info.get("school", ""))
	var hl := _harmony_line(info)
	if String(hl[0]) != "":
		y += 18.0 * u
		if really:
			var scol := UiKit.school_color(school)
			draw_circle(Vector2(x + 7.0 * u, y - 4.0 * u), 7.0 * u, Color(scol, a))
			UiKit.school_icon(self, school, Vector2(x + 7.0 * u, y - 4.0 * u), 4.5 * u, Toon.WASHI, a)
			_line_fit(String(hl[0]), Vector2(x + 20.0 * u, y), tw - 20.0 * u, cap, Color(gold_ink if bool(hl[1]) else Color(ink, 0.7), a))
	# synergie : active (partenaire possédé) en or, sinon une piste
	var syn_line := ""
	var syn_on := false
	if school == "fig":
		if bool(info.get("synergy_on", false)):
			syn_line = "+ Élément : " + _p(String(info.get("synergy", "")))
			syn_on = true
	else:
		var sy := _syn_of(id)
		if not sy.is_empty():
			syn_on = bool(sy[2])
			syn_line = ("+ Avec %s : %s" if syn_on else "Avec %s : %s") % [String(sy[0]), String(sy[1])]
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


# ------------------------------------------------------------------ style 3 : carte de rouleau v2 (UI v2)

# étoile d'or à 4 branches de la pastille « nouveau » (gabarit 32)
const STAR4 := "M16 2 L19.5 12.5 L30 16 L19.5 19.5 L16 30 L12.5 19.5 L2 16 L12.5 12.5 Z"


## Écran du choix v2 (planche Rouleaux), en un bloc centré verticalement : titre souligné, bande des pouvoirs pris,
## explication (première fois), cartes, bulle d'encre de la carte touchée, relance ronde et CHOISIR au pinceau.
## Pose les rectangles de toucher (_rects, _confirm_rect, _reroll_rect, _tip_rect) comme le dessin des autres styles.
func _draw_v2() -> void:
	var w := size.x
	var h := size.y
	var u := w / 400.0
	var fade := UiKit.ease_out(_t / 0.3) if _chosen < 0 else 1.0 - UiKit.ease_out((_t - 0.25) / 0.3)
	var n := _infos.size()
	var leg := _leg_index >= 0
	var revealed := 0.0
	if leg:
		revealed = 1.0 if _chosen >= 0 else clampf((_t - _reveal_start(_leg_index) - REVEAL_DUR * 0.5) / 0.4, 0.0, 1.0)
	var ins := UiKit.safe_insets(size)
	# cartes : trois cartes de 116 u tiennent dans la largeur ; plus (Atelier : un choix de plus), elles rétrécissent
	var k := minf(1.0, (w - 24.0 * u) / maxf(1.0, (V2_W * float(n) + V2_GAP * float(maxi(n - 1, 0))) * u))
	var bub_w := minf(w - 28.0 * u, 340.0 * u)
	var bub_h := 60.0 * u  # place réservée à la bulle (la plus haute des cartes : rien ne saute au toucher)
	for i in n:
		bub_h = maxf(bub_h, _v2_bubble(Rect2(Vector2.ZERO, Vector2(bub_w, 4000.0)), _infos[i], _id(i), u, 0.0, false))
	var sub_h := 18.0 * u if _title_text != "" and _sub_text != "" else 0.0
	var strip_h := 46.0 * u if not _owned.is_empty() else 0.0
	var tip_h := _tip_h(u) + 14.0 * u if _tip_on else 0.0
	var fixed := 44.0 * u + sub_h + strip_h + tip_h + bub_h + V2_BTN_H * u
	var gsum := (18.0 + 32.0 + 22.0 + 24.0) * u
	var avail := h - ins.x - ins.y - 24.0 * u
	var gk := 1.0
	var over := fixed + gsum + V2_H * k * u - avail
	if over > 0.0:
		# écran court : les marges se resserrent d'abord, puis les cartes rapetissent
		gk = maxf(0.45, 1.0 - over / gsum)
		over = fixed + gsum * gk + V2_H * k * u - avail
		if over > 0.0:
			k = maxf(0.55, k - over / (V2_H * u))
	var cw := V2_W * k * u
	var ch := V2_H * k * u
	var gap := V2_GAP * k * u
	var y0 := ins.x + 12.0 * u + maxf(0.0, (avail - (fixed + gsum * gk + ch)) * 0.42)
	var ty := y0 + 30.0 * u  # ligne de base du titre
	var sy := y0 + 44.0 * u + sub_h + 18.0 * u * gk  # haut de la bande des pouvoirs
	var top := sy + strip_h + tip_h + 32.0 * u * gk  # haut des cartes
	var by := top + ch + 22.0 * u * gk  # haut de la bulle
	var btn_y := by + bub_h + 24.0 * u * gk  # haut de la rangée relance / CHOISIR

	# voile d'encre ; lueur d'or (cercles, sans flou) et poussière quand un légendaire est là
	draw_rect(Rect2(Vector2.ZERO, size), Color(Toon.VEIL, 0.88 * fade))
	if leg:
		var pulse := 0.5 + 0.5 * sin(_t * 2.2)
		var gcen := Vector2(w / 2.0, top + ch * 0.5)
		for g in 3:
			draw_circle(gcen, w * (0.42 + 0.08 * float(g) + 0.03 * pulse), Color(GOLD_HI, (0.05 - 0.012 * float(g)) * revealed * fade))
		_draw_motes(w, h, u, revealed * fade)

	# titre (Shippori espacée), trait vermillon qui se pose dessous
	var title := "UN ROULEAU"
	var title_col: Color = Toon.WASHI
	if leg:
		title_col = Toon.WASHI.lerp(GOLD_HI, revealed)
	if _title_text != "":
		title = _title_text
		title_col = GOLD_HI
	var tsp := maxi(1, int(6.0 * u))
	if _v2_title.spacing_glyph != tsp:
		_v2_title.spacing_glyph = tsp
	var tfs := int(26 * u)
	while tfs > 12 and _v2_title.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > w - 32.0 * u:
		tfs -= 1
	var tdy := -16.0 * u * (1.0 - fade)
	UiKit.text(self, _v2_title, title, Vector2(w / 2.0 + float(tsp) * 0.5, ty + tdy), tfs, Color(title_col, fade))
	var uk := UiKit.ease_out(clampf((_t - 0.1) / 0.4, 0.0, 1.0))
	if uk > 0.05:
		var ul := Rect2(Vector2(w / 2.0 - 100.0 * u, ty + 7.0 * u + tdy), Vector2(200.0 * u, 8.0 * u))
		draw_colored_polygon(UiKit.swash_points(ul, uk, 5.0), Color(Toon.VERMILION, fade))
	if sub_h > 0.0:
		UiKit.text(self, _ui, _p(_sub_text), Vector2(w / 2.0, ty + 34.0 * u + tdy), _fs(12.0, u), Color(GOLD_HI, 0.85 * fade))

	# bande des pouvoirs pris, puis l'explication (toute première fois)
	if strip_h > 0.0:
		_v2_strip(Vector2(w / 2.0, sy + strip_h * 0.5), w, u, fade)
	else:
		_owned_pos.clear()
	_draw_tip(sy + strip_h + 4.0 * u, w, u, fade)

	# cartes côte à côte (rectangles de toucher fixes) ; chaque carte est donnée face cachée, monte et se retourne ;
	# la carte touchée se soulève (14 u) et se dessine en dernier
	var x0 := (w - (cw * float(n) + gap * float(maxi(n - 1, 0)))) / 2.0
	_rects.clear()
	for i in n:
		_rects.append(Rect2(Vector2(x0 + float(i) * (cw + gap), top), Vector2(cw, ch)))
	var order: Array = []
	for i in n:
		if i != _sel:
			order.append(i)
	if _sel >= 0 and _sel < n:
		order.append(_sel)
	var lift := V2_LIFT * k * u
	for oi in order:
		var i := int(oi)
		var info: Dictionary = _infos[i]
		var base: Rect2 = _rects[i]
		var c := base.get_center()
		var lf: float = float(_lift[i]) if i < _lift.size() else 0.0
		var lt := _t - _unroll_start(i)
		var a := fade
		var sc := 1.0
		var dy := 0.0
		var rot := 0.0
		_ct = 99.0
		_sheen = lt - UNROLL_DUR + 0.1
		if _chosen >= 0:
			_sheen = -1.0
			if i == _chosen:
				# la choisie : petit bond et onde d'or, puis elle s'envole en s'effaçant
				var p2 := clampf((_t - 0.22) / 0.28, 0.0, 1.0)
				p2 *= p2
				sc = lerpf(1.04, 1.08, UiKit.ease_out(_t / 0.1)) - 0.1 * p2
				dy = -lift - 70.0 * u * p2
				a = 1.0 - UiKit.ease_out((_t - 0.28) / 0.22)
				lf = 1.0
				var rk := clampf(_t / 0.35, 0.0, 1.0)
				if rk < 1.0:
					draw_arc(c + Vector2(0, -lift), base.size.x * (0.55 + 0.45 * UiKit.ease_out(rk)), 0.0, TAU, 48, Color(GOLD_HI, 0.45 * (1.0 - rk)), (4.0 * (1.0 - rk) + 1.0) * u)
			else:
				# les autres s'effacent
				a = (1.0 - UiKit.ease_out((_t - 0.1) / 0.2)) * lerpf(0.75, 1.0, lf)
				dy = -lift * lf
		else:
			# donne : la carte monte face cachée jusqu'à sa place en se redressant, puis se retourne
			var sw := 1.0 if i % 2 == 0 else -1.0
			a *= UiKit.ease_out(lt / 0.14)
			dy = (1.0 - _settle(lt / DEAL_DUR, 1.2)) * DEAL_H * u
			rot = deg_to_rad(DEAL_DEG) * sw * (1.0 - UiKit.ease_out(lt / DEAL_DUR))
			# carte touchée : soulevée, ombre plus longue ; les autres s'estompent un peu
			dy -= lift * lf
			if _sel >= 0:
				a *= lerpf(0.75, 1.0, lf)
		if _down == i:
			sc *= 0.97
		_raise = lf
		var xf := Transform2D(0.0, Vector2(0, dy)) * _turn(c, rot) * _about(c, sc)
		_card(base, info, _id(i), u, a, i, xf, 1.0)
	_xf = Transform2D.IDENTITY
	_raise = 0.0
	_sheen = -1.0

	# bulle d'encre de la carte touchée, pointe vers elle
	var ba := fade * (UiKit.ease_out(_sel_t / 0.2) if _chosen < 0 else 1.0)
	if _sel >= 0 and _sel < n and ba > 0.01:
		var bh := _v2_bubble(Rect2(Vector2.ZERO, Vector2(bub_w, 4000.0)), _infos[_sel], _id(_sel), u, 0.0, false)
		var box := Rect2(Vector2(w / 2.0 - bub_w / 2.0, by + 6.0 * u * (1.0 - ba)), Vector2(bub_w, bh))
		var sr: Rect2 = _rects[_sel]
		var tipx := clampf(sr.get_center().x, box.position.x + 20.0 * u, box.end.x - 20.0 * u)
		var tri := PackedVector2Array([Vector2(tipx - 10.0 * u, box.position.y + 1.0), Vector2(tipx, box.position.y - 9.0 * u),
			Vector2(tipx + 10.0 * u, box.position.y + 1.0)])
		draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI, ba), int(12 * u), Color(UIColors.WASHI, 0.6 * ba), maxi(1, int(1.5 * u))), box)
		draw_colored_polygon(tri, Color(UIColors.SUMI, ba))
		draw_polyline(tri, Color(UIColors.WASHI, 0.6 * ba), maxf(1.0, 1.5 * u), true)
		_v2_bubble(box, _infos[_sel], _id(_sel), u, ba, true)

	# relance (bouton rond, compteur) et CHOISIR au pinceau (pâle tant qu'aucune carte n'est touchée)
	var has_rr := rerolls > 0 and _chosen < 0 and n > 0
	var bw := V2_BTN_W * u
	var bh2 := V2_BTN_H * u
	var rrd := V2_REROLL * u
	var lead := rrd + 18.0 * u if has_rr else 0.0
	var row_x := w / 2.0 - (bw + lead) / 2.0
	_confirm_rect = Rect2(Vector2(row_x + lead, btn_y), Vector2(bw, bh2))
	_reroll_rect = Rect2()
	if has_rr:
		_reroll_rect = Rect2(Vector2(row_x, btn_y + (bh2 - rrd) / 2.0), Vector2(rrd, rrd))
		_v2_reroll(_reroll_rect, u, fade)
	var ck := UiKit.ease_out(_sel_t / 0.2) if _sel >= 0 else 0.0
	_v2_choose(_confirm_rect, u, fade * lerpf(0.35, 1.0, ck))


## Bande des pouvoirs pris (planche Rouleaux) : médaillons entre deux filets ; ceux que la carte en vue améliore,
## renforce, complète ou dont elle partage l'élément sont cerclés d'or pointillé (les autres pâlissent).
func _v2_strip(c: Vector2, w: float, u: float, a: float) -> void:
	_owned_pos.clear()
	var n := _owned.size()
	if n == 0 or a <= 0.01:
		return
	var f := _focus()
	var rel: Dictionary = {}
	if f >= 0 and f < _links.size():
		rel = _links[f]
	var ms := 38.0 * u
	var gap := 10.0 * u
	var room := w - 2.0 * 84.0 * u
	if float(n) * ms + float(n - 1) * gap > room:
		gap = 6.0 * u
		ms = maxf(18.0 * u, (room - float(n - 1) * gap) / float(n))
	var row_w := float(n) * ms + float(n - 1) * gap
	var lx := c.x - row_w / 2.0
	var rule := Color(UIColors.WASHI, 0.3 * a)
	draw_line(Vector2(lx - 70.0 * u, c.y), Vector2(lx - 10.0 * u, c.y), rule, maxf(1.0, u))
	draw_line(Vector2(lx + row_w + 10.0 * u, c.y), Vector2(lx + row_w + 70.0 * u, c.y), rule, maxf(1.0, u))
	for k in n:
		var o: Array = _owned[k]
		var oid := String(o[0])
		var mc := Vector2(lx + ms / 2.0 + float(k) * (ms + gap), c.y)
		_owned_pos[oid] = mc
		var kind := String(rel.get(oid, ""))
		var ia := a if f < 0 or kind != "" else a * 0.55
		UiKit.power_medal(self, oid, mc, ms / 60.0, UIColors.element(UiKit.power_school(oid)), 27.0, 4.0, UiKit.NONE, 4.0, ia)
		if kind != "":
			UiKit.dashed_arc(self, mc, ms / 2.0 + 4.0 * u, 0.0, TAU, Color(GOLD_HI, a), maxf(1.0, 2.0 * u), 4.0 * u, 3.0 * u)


## Point d'une courbe de Bézier quadratique.
func _quad(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)


## Points d'une courbe de Bézier cubique (t de 1/10 à 1, sans le départ), gabarit -> écran (origine o, échelle k).
func _cubic_pts(o: Vector2, k: Vector2, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in range(1, 11):
		var t := float(j) / 10.0
		var mt := 1.0 - t
		var q := p0 * mt * mt * mt + p1 * 3.0 * mt * mt * t + p2 * 3.0 * mt * t * t + p3 * t * t * t
		out.append(o + q * k)
	return out


## Polyligne du gabarit (points en u) mise à l'écran (origine o, échelle s).
func _v2_pl(o: Vector2, s: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var pv: Vector2 = p
		out.append(o + pv * s)
	return out


## Texte à lettres espacées de sp px ; renvoie sa largeur. really = false : mesure seulement.
func _spaced(font: Font, txt: String, pos: Vector2, fs: int, sp: float, c: Color, really := true) -> float:
	var x := pos.x
	for j in txt.length():
		var ch := txt.substr(j, 1)
		if really:
			draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + sp
	return maxf(0.0, x - pos.x - sp)


## CHOISIR au pinceau (planche Rouleaux, gabarit 210 × 64) : trait de papier, filet vermillon dessous, mot en
## Shippori espacée ; à l'appui, le pinceau vire au vermillon.
func _v2_choose(r0: Rect2, u: float, a: float) -> void:
	if a <= 0.01:
		return
	var r := r0
	var pressed := _down == CONFIRM
	if pressed:
		r = r.grow(-3.0 * u)
	var k := Vector2(r.size.x / V2_BTN_W, r.size.y / V2_BTN_H)
	var o := r.position
	var pts := PackedVector2Array([o + Vector2(8, 14) * k])
	pts.append_array(_cubic_pts(o, k, Vector2(8, 14), Vector2(60, 4), Vector2(150, 6), Vector2(204, 10)))
	pts.append(o + Vector2(198, 30) * k)
	pts.append(o + Vector2(206, 50) * k)
	pts.append_array(_cubic_pts(o, k, Vector2(206, 50), Vector2(140, 62), Vector2(60, 62), Vector2(4, 54)))
	pts.append(o + Vector2(12, 34) * k)
	draw_colored_polygon(pts, Color(Toon.VERMILION if pressed else UIColors.WASHI, a))
	if not pressed:
		var line := PackedVector2Array([o + Vector2(30, 56) * k])
		line.append_array(_cubic_pts(o, k, Vector2(30, 56), Vector2(90, 62), Vector2(150, 60), Vector2(186, 54)))
		draw_polyline(line, Color(Toon.VERMILION, a), maxf(1.0, 3.0 * k.y), true)
	var sp := maxi(1, int(6.0 * u))
	if _v2_btn.spacing_glyph != sp:
		_v2_btn.spacing_glyph = sp
	var fs := int(20 * u)
	UiKit.text(self, _v2_btn, "CHOISIR", Vector2(r.get_center().x + float(sp) * 0.5, r.get_center().y + float(fs) * 0.36),
		fs, Color(UIColors.WASHI if pressed else UIColors.SUMI, a))


## Relance (planche Rouleaux) : bouton rond de papier cerné d'encre, pictogramme, pastille vermillon du compteur.
func _v2_reroll(r: Rect2, u: float, a: float) -> void:
	if a <= 0.01:
		return
	var c := r.get_center()
	var rad := r.size.x * 0.5
	draw_circle(c, rad, Color(UIColors.WASHI, a))
	draw_arc(c, rad - 1.0 * u, 0.0, TAU, 48, Color(UIColors.SUMI, a), maxf(1.0, 2.0 * u), true)
	UiKit.draw_icon(self, "interface/relancer", c, 26.0 * u, a, UIColors.SUMI)
	var bc := c + Vector2(22.0, -22.0) * u
	draw_circle(bc, 11.0 * u, Color(Toon.VERMILION, a))
	draw_arc(bc, 10.25 * u, 0.0, TAU, 32, Color(UIColors.SUMI, a), maxf(1.0, 1.5 * u), true)
	var fs := int(12 * u)
	UiKit.text(self, UiKit.num_font(), str(rerolls), Vector2(bc.x, bc.y + float(fs) * 0.36), fs, Color(UIColors.WASHI, a))


## Dos d'une carte v2 donnée face cachée : encre, vagues seigaiha pâles, filet de papier, ensō d'or au centre.
func _back_v2(r: Rect2, a: float) -> void:
	var s := r.size.x / V2_W
	var body := UiKit.rrect_points(r, 12.0 * s)
	draw_colored_polygon(Transform2D(0.0, Vector2(0.0, 4.0 * s)) * body, Color(0, 0, 0, 0.25 * a))
	draw_colored_polygon(body, Color(UIColors.SUMI, a))
	var inner := r.grow(-6.0 * s)
	UiKit.seigaiha(self, inner.grow(-2.0 * s), Color(UIColors.WASHI, 0.07 * a), 9.0 * s)
	var fl := UiKit.rrect_points(inner, 7.0 * s)
	fl.append(fl[0])
	draw_polyline(fl, Color(UIColors.WASHI, 0.3 * a), maxf(1.0, 1.2 * s), true)
	UiKit.enso(self, r.get_center(), 22.0 * s, 5.0 * s, Color(UIColors.GOLD, 0.8 * a), 1.0, -PI * 0.35)


## Carte de rouleau v2 (planche RouleauCard, gabarit 116 × 250, rayon 12) : bordure de rareté (seule marque de rareté),
## scène peinte de l'élément, médaillon et glyphe, pastille nouveau (étoile) ou montée de niveau (↑N), déclencheur,
## cartouche du nom, lignes d'effet (variante C), crans de niveau, anneau d'harmonie. Dessinée sous _xf.
func _face_v2(r: Rect2, info: Dictionary, id: String, u: float, a: float, i: int) -> void:
	var s := r.size.x / V2_W
	var rank := clampi(int(info.get("rarity_rank", 0)), 0, 3)
	var school := String(info.get("school", UiKit.power_school(id)))
	var el := UIColors.element(school)
	var rd := UIColors.rarity(rank)
	var bc: Color = rd["color"]
	var bw := float(rd["w"]) * s
	var rad := 12.0 * s
	var ta := a * UiKit.ease_out((_ct - TXT_AT) / TXT_DUR)
	var pk := (_ct - POP_AT) / POP_DUR
	var ma := a * UiKit.ease_out(pk / 0.4)
	var pulse := 0.5 + 0.5 * sin(_t * 3.2 + float(i) * 1.3)
	# ombre portée sans flou (deux couches décalées), plus longue quand la carte est soulevée
	var body := UiKit.rrect_points(r, rad)
	var drop := (3.0 + 7.0 * _raise) * s
	draw_colored_polygon(Transform2D(0.0, Vector2(0.0, drop + 3.0 * s)) * body, Color(0, 0, 0, (0.14 + 0.12 * _raise) * a))
	draw_colored_polygon(Transform2D(0.0, Vector2(0.0, drop)) * body, Color(0, 0, 0, (0.2 + 0.1 * _raise) * a))
	# bordure de rareté (contour d'encre en plus au légendaire), papier en retrait
	if bool(rd["outer"]):
		draw_colored_polygon(UiKit.rrect_points(r.grow(2.0 * s), rad + 2.0 * s), Color(UIColors.SUMI, a))
	draw_colored_polygon(body, Color(bc, a))
	var inner := r.grow(-bw)
	var irad := maxf(rad - bw, 1.0)
	draw_colored_polygon(UiKit.rrect_points(inner, irad), Color(UIColors.WASHI_LIGHT, a))
	var o := inner.position
	var cx := r.get_center().x
	# scène peinte de l'élément (104 u de haut), coins du haut arrondis comme la carte
	var scene_r := Rect2(o, Vector2(inner.size.x, 104.0 * s - bw))
	_v2_scene(UiKit.rrect_points(scene_r, irad, true), o, school, s, a)
	# filet intérieur (épique, légendaire), coins d'encre du légendaire
	if bool(rd["inner"]):
		var fl := UiKit.rrect_points(inner.grow(-2.75 * s), maxf(irad - 2.75 * s, 1.0))
		fl.append(fl[0])
		draw_polyline(fl, Color(bc, a), maxf(1.0, 1.5 * s), true)
	if rank == 3:
		var g := r.grow(3.0 * s)
		var l := 11.0 * s
		var lw := maxf(1.0, 2.0 * s)
		var ink := Color(UIColors.SUMI, a)
		draw_polyline(PackedVector2Array([g.position + Vector2(0, l), g.position, g.position + Vector2(l, 0)]), ink, lw)
		draw_polyline(PackedVector2Array([Vector2(g.end.x - l, g.position.y), Vector2(g.end.x, g.position.y), Vector2(g.end.x, g.position.y + l)]), ink, lw)
		draw_polyline(PackedVector2Array([Vector2(g.position.x, g.end.y - l), Vector2(g.position.x, g.end.y), Vector2(g.position.x + l, g.end.y)]), ink, lw)
		draw_polyline(PackedVector2Array([Vector2(g.end.x - l, g.end.y), g.end, Vector2(g.end.x, g.end.y - l)]), ink, lw)
	# médaillon (60 en 28, 18) : disque washi cerné d'encre, filet de l'élément, glyphe ; il « pope » au retournement
	var mc := Vector2(cx, o.y + 48.0 * s)
	draw_set_transform_matrix(_xf * _about(mc, 0.6 + 0.4 * _settle(pk, 1.7)))
	UiKit.power_medal(self, id, mc, s, UIColors.SUMI, 28.0, 2.5, el, 3.0, ma)
	draw_set_transform_matrix(_xf)
	# pastille : nouveau (étoile d'or sur rond d'encre) ou montée de niveau (pilule d'or, chevron et niveau atteint)
	if bool(info.get("is_new", true)):
		var nc := Vector2(o.x + 17.0 * s, o.y + 17.0 * s)
		draw_circle(nc, 11.0 * s, Color(UIColors.SUMI, ma))
		draw_arc(nc, 10.25 * s, 0.0, TAU, 32, Color(UIColors.GOLD, ma), maxf(1.0, 1.5 * s), true)
		UiKit.draw_path(self, STAR4, 32, nc, 12.0 * s, UIColors.GOLD, 0.5, UIColors.GOLD, ma)
	else:
		var nf := UiKit.num_font()
		var lfs := maxi(1, int(12.0 * s))
		var lv_txt := str(int(info.get("level", 1)))
		var lvw := nf.get_string_size(lv_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		var pill := Rect2(o + Vector2(6.0, 6.0) * s, Vector2(24.0 * s + lvw, 22.0 * s))
		draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD, ma), int(11.0 * s), Color(UIColors.SUMI, ma), maxi(1, int(1.5 * s))), pill)
		var pc := Vector2(pill.position.x + 11.0 * s, pill.get_center().y)
		draw_polyline(PackedVector2Array([pc + Vector2(-4.0, 2.0) * s, pc + Vector2(0.0, -2.0) * s, pc + Vector2(4.0, 2.0) * s]),
			Color(UIColors.SUMI, ma), maxf(1.0, 2.0 * s), true)
		draw_string(nf, Vector2(pill.position.x + 18.0 * s, pill.get_center().y + float(lfs) * 0.36), lv_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(UIColors.SUMI, ma))
	# déclencheur : pictogramme papier sur rond d'encre
	var tc := Vector2(inner.end.x - 18.0 * s, o.y + 18.0 * s)
	draw_circle(tc, 12.0 * s, Color(UIColors.SUMI, ma))
	draw_arc(tc, 11.25 * s, 0.0, TAU, 32, Color(UIColors.WASHI, ma), maxf(1.0, 1.5 * s), true)
	UiKit.trig_icon(self, id, tc, 16.0 * s, UIColors.WASHI, ma)
	# cartouche du nom (Shippori 800 : le seul texte de la carte)
	var nm := UiKit.power_label(id)
	var nfs := maxi(1, int(15.0 * s))
	var maxw := inner.size.x - 32.0 * s
	while nfs > 8 and UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > maxw:
		nfs -= 1
	var nw := UiKit.TITLE_FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var cart := Rect2(Vector2(cx - (nw + 20.0 * s) / 2.0, o.y + 90.0 * s), Vector2(nw + 20.0 * s, 28.0 * s))
	draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0.25 * a), int(3.0 * s)), Rect2(cart.position + Vector2(0, 2.0 * s), cart.size))
	draw_style_box(UiKit.box(_sb, Color(UIColors.WASHI_LIGHT, a), int(3.0 * s), Color(UIColors.SUMI, a), maxi(1, int(1.5 * s))), cart)
	UiKit.text(self, UiKit.TITLE_FONT, nm, Vector2(cx, cart.get_center().y + float(nfs) * 0.36), nfs, Color(UIColors.SUMI, ta))
	# lignes d'effet (variante C) : jusqu'à trois, 24 u chacune, panneau à 128 u
	var rows := _fx_of(id, info)
	for k in mini(rows.size(), 3):
		var rw: Array = rows[k]
		_v2_fx_row(rw, o.x + 8.0 * s, inner.end.x - 8.0 * s, o.y + 132.0 * s + 24.0 * s * float(k) + 12.0 * s, s, el, ta)
	# pied : crans de niveau (le cran gagné brille) et anneau d'harmonie (état après le choix ; aucun pour le neutre)
	var fy := inner.end.y - 8.0 * s - 19.0 * s
	var mx := int(info.get("max_level", 1))
	if mx > 1:
		var cur := int(info.get("cur_level", 0))
		for kk in mx:
			var cr := Rect2(Vector2(o.x + 10.0 * s + float(kk) * 16.0 * s, fy - 3.0 * s), Vector2(13.0 * s, 6.0 * s))
			if kk < cur:
				draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD_DARK, ta), int(3.0 * s)), cr)
			elif kk == cur:
				# halo sans flou : deux contours à alpha décroissant, puis l'or cerné d'encre
				for g2 in 2:
					var gg := (3.0 + 2.0 * float(g2)) * s
					draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD, (0.32 - 0.14 * float(g2)) * (0.6 + 0.4 * pulse) * ta), int(3.0 * s + gg)), cr.grow(gg))
				draw_style_box(UiKit.box(_sb, Color(UIColors.SUMI, ta), int(4.5 * s)), cr.grow(1.5 * s))
				draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD, ta), int(3.0 * s)), cr)
			else:
				draw_style_box(UiKit.box(_sb, Color(0, 0, 0, 0), int(3.0 * s), Color(UIColors.LINE_MUTED, ta), maxi(1, int(1.5 * s))), cr)
	var rc := Vector2(inner.end.x - 8.0 * s - 19.0 * s, fy)
	if Data.AFFINITY.has(school):
		var aff := mini(int(info.get("aff", 0)), 4)
		var nxt := int(info.get("aff_next", aff))
		var gain := clampi(nxt - aff, 0, 4 - aff)
		UiKit.harmony_ring(self, rc, 16.0 * s, aff, gain, el, UIColors.LINE_MUTED, ta, nxt >= int(Data.AFF_TIERS[0]), true)
	UiKit.element_icon(self, school, rc, 15.0 * s, ta)
	_sheen_pass(r, u, a, rank)


## Ligne d'effet (variante C) : pictogramme 12 à la couleur d'élément, LIBELLÉ (8,5, encre pâle), points de conduite,
## chiffre en Zen Kaku (12 ; « avant → » plus petit et pâle) et unité (8). Sans chiffre : le libellé seul.
func _v2_fx_row(rw: Array, x0: float, x1: float, ym: float, s: float, el: Color, a: float) -> void:
	if a <= 0.01 or rw.size() < 3:
		return
	UiKit.fx_icon(self, String(rw[0]), Vector2(x0 + 6.0 * s, ym), 12.0 * s, el, a)
	var lx := x0 + 15.0 * s
	var lab := UiKit.caps(String(rw[2]))
	var v := String(rw[1])
	var font: Font = UiKit.UI_FONT
	var lfs := maxi(1, int(8.5 * s))
	var muted := Color(UIColors.TEXT_MUTED, a)
	if v == "":
		while lfs > 5 and font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x > x1 - lx:
			lfs -= 1
		draw_string(font, Vector2(lx, ym + float(lfs) * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, muted)
		return
	var parts := UiKit.split_value(v)
	var head := String(parts[0])
	var num := String(parts[1])
	var unit := String(parts[2])
	var nf := UiKit.num_font()
	var vfs := maxi(1, int(12.0 * s))
	var hfs := maxi(1, int(9.0 * s))
	var ufs := maxi(1, int(8.0 * s))
	var hw := nf.get_string_size(head + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x if head != "" else 0.0
	var nw := nf.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs).x
	var uw := font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, ufs).x + 1.5 * s if unit != "" else 0.0
	var vx := x1 - (hw + nw + uw)
	# le libellé rétrécit pour laisser au moins quelques points de conduite
	while lfs > 5 and lx + font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x + 6.0 * s > vx:
		lfs -= 1
	var lw := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	draw_string(font, Vector2(lx, ym + float(lfs) * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, muted)
	var dx := lx + lw + 3.0 * s
	var dot := maxf(1.0, s)
	var dc := Color(UIColors.SUMI, 0.3 * a)
	while dx < vx - 3.0 * s:
		draw_rect(Rect2(Vector2(dx, ym + 4.0 * s), Vector2(dot, dot)), dc)
		dx += 2.0 * dot
	var bl := ym + float(vfs) * 0.36
	if head != "":
		draw_string(nf, Vector2(vx, bl), head, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(UIColors.SUMI, 0.5 * a))
	draw_string(nf, Vector2(vx + hw, bl), num, HORIZONTAL_ALIGNMENT_LEFT, -1, vfs, Color(UIColors.SUMI, a))
	if unit != "":
		draw_string(font, Vector2(vx + hw + nw + 1.5 * s, bl), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, ufs, Color(UIColors.SUMI, 0.6 * a))


## Scène peinte d'une carte v2 (gabarit 116 × 104, origine o, échelle s), découpée au polygone clip : fond de
## l'élément et son motif (flammes, vagues, éclairs, vent, rayons d'ombre, lavis, boucle de figure).
func _v2_scene(clip: PackedVector2Array, o: Vector2, school: String, s: float, a: float) -> void:
	var sc := UIColors.card_scene(school)
	var bg: Color = sc["bg"]
	var deco: Color = sc["deco"]
	draw_colored_polygon(clip, Color(bg, a))
	var lines: Array = []  # polylignes à l'écran, découpées ensuite à la scène
	match UIColors.element_of(school):
		"feu":
			var fill: Color = sc.get("fill", deco)
			var flames: Array = [[Vector2(0, 104), Vector2(8, 70), Vector2(16, 92), Vector2(24, 60), Vector2(34, 90), Vector2(44, 66), Vector2(52, 104)],
				[Vector2(64, 104), Vector2(72, 64), Vector2(82, 92), Vector2(92, 56), Vector2(102, 88), Vector2(110, 66), Vector2(116, 104)]]
			for fp in flames:
				var poly := _v2_pl(o, s, fp)
				for piece in Geometry2D.intersect_polygons(poly, clip):
					var pp: PackedVector2Array = piece
					if pp.size() >= 3 and UiKit.poly_area(pp) > 1.0:
						draw_colored_polygon(pp, Color(fill, a))
				var edge := poly.duplicate()
				edge.append(poly[0])
				lines.append(edge)
		"eau":
			for row in [[-14.0, 70.0, 5], [0.0, 84.0, 4], [-14.0, 98.0, 5]]:
				var rx := float(row[0])
				var ry := float(row[1])
				var pl := PackedVector2Array([o + Vector2(rx, ry) * s])
				for wv in int(row[2]):
					var p0 := Vector2(rx + 29.0 * float(wv), ry)
					for j in range(1, 9):
						pl.append(o + _quad(p0, p0 + Vector2(14.5, -12.0), p0 + Vector2(29.0, 0.0), float(j) / 8.0) * s)
				lines.append(pl)
		"foudre":
			lines.append(_v2_pl(o, s, [Vector2(16, 0), Vector2(6, 40), Vector2(14, 40), Vector2(8, 76)]))
			lines.append(_v2_pl(o, s, [Vector2(100, 4), Vector2(110, 38), Vector2(102, 38), Vector2(108, 70)]))
		"vent":
			for yy in [30.0, 60.0, 90.0]:
				var vy := float(yy)
				var pl2 := PackedVector2Array()
				for j in 17:
					pl2.append(o + _quad(Vector2(0, vy), Vector2(30, vy - 12.0), Vector2(58, vy), float(j) / 16.0) * s)
				for j in range(1, 17):
					pl2.append(o + _quad(Vector2(58, vy), Vector2(86, vy + 12.0), Vector2(116, vy), float(j) / 16.0) * s)
				lines.append(pl2)
		"ombre":
			lines.append(_v2_pl(o, s, [Vector2(0, 20), Vector2(58, 52), Vector2(116, 20)]))
			lines.append(_v2_pl(o, s, [Vector2(0, 84), Vector2(58, 52), Vector2(116, 84)]))
			lines.append(_v2_pl(o, s, [Vector2(58, 0), Vector2(58, 104)]))
		"neutre":
			var curves: Array = [[Vector2(10, 20), Vector2(40, 26), Vector2(70, 18)], [Vector2(30, 50), Vector2(70, 56), Vector2(110, 50)],
				[Vector2(0, 86), Vector2(30, 82), Vector2(60, 88)]]
			for q in curves:
				var qa: Vector2 = q[0]
				var qb: Vector2 = q[1]
				var qc: Vector2 = q[2]
				var pl3 := PackedVector2Array()
				for j in 13:
					pl3.append(o + _quad(qa, qb, qc, float(j) / 12.0) * s)
				lines.append(pl3)
		"figure":
			# grand arc ouvert (A46 de 58,6 à 104,40 par le grand côté)
			var fc := Vector2(59.6, 52.0)
			var pl4 := PackedVector2Array()
			for j in 41:
				var ang := deg_to_rad(lerpf(-92.0, -375.0, float(j) / 40.0))
				pl4.append(o + (fc + Vector2(cos(ang), sin(ang)) * 46.0) * s)
			lines.append(pl4)
	var lw := maxf(1.0, 2.0 * s)
	for ln in lines:
		var src: PackedVector2Array = ln
		for piece in Geometry2D.intersect_polyline_with_polygon(src, clip):
			var seg: PackedVector2Array = piece
			if seg.size() >= 2:
				draw_polyline(seg, Color(deco, a), lw, true)


## Bonus d'harmonie d'une carte en deux mots (« Feu +25 % ») : celui du palier visé ou atteint.
func _aff_bonus(info: Dictionary) -> String:
	var goal := int(info.get("aff_goal", 0))
	var school := String(info.get("school", ""))
	var tiers: Array = Data.AFF_TIERS
	var tier := maxi(0, tiers.find(goal))
	var shorts: Array = Data.AFF_SHORT.get(school, [])
	if tier < shorts.size():
		return _p(String(shorts[tier]))
	return _p(String(info.get("aff_text", "")))


## Bulle d'encre de la carte touchée (planche Rouleaux) : nom japonais en capitales d'or, déclencheur en pictogrammes,
## phrase courte ; puis l'harmonie (anneau -> pastille HARMONIE quand le palier tombe, sinon le compte et le bonus visé)
## et la synergie. Renvoie la hauteur ; really = false : mesure seulement.
func _v2_bubble(box: Rect2, info: Dictionary, id: String, u: float, a: float, really: bool) -> float:
	var px := 16.0 * u
	var py := 12.0 * u
	var x := box.position.x + px
	var tw := box.size.x - 2.0 * px
	var y := box.position.y + py
	# en-tête : nom japonais ; à droite, la figure et le déclencheur
	y += 13.0 * u
	if really:
		var sp := maxi(1, int(2.0 * u))
		if _v2_caps.spacing_glyph != sp:
			_v2_caps.spacing_glyph = sp
		var nm := UiKit.caps(_p(String(info.get("name", ""))), UiKit.TITLE_FONT)
		var f := int(12 * u)
		while f > 8 and _v2_caps.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > tw - 52.0 * u:
			f -= 1
		draw_string(_v2_caps, Vector2(x, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, f, Color(GOLD_HI, a))
		var ic := Vector2(x + tw - 9.0 * u, y - 4.5 * u)
		UiKit.trig_icon(self, id, ic, 18.0 * u, UIColors.WASHI, a)
		var fig := UiKit.trigger_figure(id)
		if fig != "":
			UiKit.figure_icon(self, fig, ic - Vector2(24.0 * u, 0.0), 18.0 * u, a)
	# la phrase
	var bfs := int(13.5 * u)
	var lh := float(bfs) * 1.35
	var short_line := UiKit.fx_line(id)
	var lines := _wrap(_ui, short_line, bfs, tw)
	y += 4.0 * u
	for k in mini(lines.size(), 3):
		y += lh
		if really:
			draw_string(_ui, Vector2(x, y), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(UIColors.WASHI, a))
	# harmonie : anneau (après le choix), flèche, pastille HARMONIE ou compte et bonus visé
	var school := String(info.get("school", ""))
	var goal := int(info.get("aff_goal", 0))
	var cap := _fs(11.0, u)
	if goal > 0 and Data.AFFINITY.has(school):
		y += 10.0 * u
		if really:
			draw_line(Vector2(x, y), Vector2(x + tw, y), Color(UIColors.WASHI, 0.2 * a), maxf(1.0, u))
		var rowc := y + 19.0 * u
		if really:
			var aff := mini(int(info.get("aff", 0)), 4)
			var nxt := int(info.get("aff_next", aff))
			var ec := UIColors.element(school, true)
			var rc := Vector2(x + 13.0 * u, rowc)
			UiKit.harmony_ring(self, rc, 16.0 * 26.0 / 38.0 * u, aff, clampi(nxt - aff, 0, 4 - aff), ec, UIColors.LINE_MUTED_DARK, a,
				false, false, 4.0, 3.0)
			UiKit.element_icon(self, school, rc, 10.5 * u, a, ec)
			UiKit.draw_path(self, "M6 16 H24 M18 10 L25 16 L18 22", 32, Vector2(x + 39.0 * u, rowc), 14.0 * u, UIColors.GOLD, 3.0, UiKit.NONE, a)
			var bonus := _aff_bonus(info)
			var tx := x + 54.0 * u
			if bool(info.get("aff_hit", false)) or bool(info.get("aff_done", false)):
				var nf := UiKit.num_font()
				var cfs := int(9 * u)
				var ww := _spaced(nf, "HARMONIE", Vector2.ZERO, cfs, 1.5 * u, Color.WHITE, false)
				var chip := Rect2(Vector2(tx, rowc - 11.0 * u), Vector2(7.0 * u + 7.0 * u + 5.0 * u + ww + 9.0 * u, 22.0 * u))
				draw_style_box(UiKit.box(_sb, Color(UIColors.GOLD, a), int(11 * u)), chip)
				UiKit.diamond(self, Vector2(chip.position.x + 10.5 * u, rowc), 3.5 * u, Color(UIColors.SUMI, a))
				_spaced(nf, "HARMONIE", Vector2(chip.position.x + 19.0 * u, rowc + float(cfs) * 0.36), cfs, 1.5 * u, Color(UIColors.SUMI, a))
				tx = chip.end.x + 8.0 * u
				if bonus != "" and x + tw - tx > 20.0 * u:
					_line_fit(bonus, Vector2(tx, rowc + float(cap) * 0.36), x + tw - tx, cap, Color(UIColors.WASHI, 0.85 * a))
			elif bonus != "":
				var txt := "%d/%d  %s" % [mini(nxt, goal), goal, bonus]
				_line_fit(txt, Vector2(tx, rowc + float(cap) * 0.36), x + tw - tx, cap, Color(UIColors.WASHI, 0.6 * a))
		y = rowc + 11.0 * u
	# synergie : active (partenaire possédé) en or, sinon une piste
	var syn_line := ""
	var syn_on := false
	if school == "fig":
		if bool(info.get("synergy_on", false)):
			syn_line = "+ Élément : " + _p(String(info.get("synergy", "")))
			syn_on = true
	else:
		var sy := _syn_of(id)
		if not sy.is_empty():
			syn_on = bool(sy[2])
			syn_line = ("+ Avec %s : %s" if syn_on else "Avec %s : %s") % [String(sy[0]), String(sy[1])]
	if syn_line != "":
		y += float(cap) * 1.6
		if really:
			var scol: Color = GOLD_HI if syn_on else Color(UIColors.WASHI, 0.55)
			_line_fit(syn_line, Vector2(x, y), tw, cap, Color(scol, scol.a * a))
	return y - box.position.y + py
