extends Control
## Bestiaire (bouton BESTIAIRE de l'accueil) : tous les yōkai et ninjas, rangés par monde dans l'ordre où on
## les rencontre, le gardien et le boss à la fin de chaque monde. Un ennemi déjà croisé montre son vrai modèle
## (portrait 3D rendu une fois dans un SubViewport partagé, gardé en cache), son nom et son sceau ; les autres
## ne sont qu'une silhouette d'encre « ??? ». Toucher une fiche ouvre le détail : le modèle tourne (le doigt le
## fait pivoter), une légende, comment il attaque et comment le battre, victoires, monde de la rencontre.
## Les viewports 3D sont libérés à la fermeture ; les portraits (ImageTexture) restent en mémoire.
## Pas de 3D sans écran (robot du CI, --headless) : sceaux à la place des portraits.

const Toon = preload("res://scripts/toon.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const InkButton = preload("res://scripts/ink_button.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Worlds = preload("res://scripts/worlds.gd")

const DRAG_START := 8.0  # glissé minimal (× u) avant de faire défiler
const COLS := 3
const PORTRAIT := Vector2i(176, 220)  # portrait d'une fiche (pixels)
const BIG_VIEW := Vector2i(384, 360)  # vue tournante du détail (pixels)
const PORTRAIT_GAP := 3  # images entre deux portraits rendus : l'écran reste fluide
# ennemi -> [nom, kanji, légende, comment il attaque et comment le battre, monde par défaut]
# (le monde réel vient des poids de worlds.gd ; celui-ci ne sert que si l'ennemi n'y figure nulle part)
const INFO := {
	"oni": ["ONI", "鬼", "Ogre des montagnes à la peau rouge, il descend piller les villages au son du tambour.",
		"Un disque se remplit sous lui : sors-en, puis tranche.", 1],
	"kappa": ["KAPPA", "河童", "Esprit des rivières, une coupelle d'eau sur le crâne : renversée, il perd toute force.",
		"Il lance de grosses boules lentes : esquive de côté et fonce.", 1],
	"kappa_yumi": ["KAPPA ARCHER", "弓", "Un kappa qui a repêché l'arbalète d'un samouraï noyé.",
		"Une ligne fine annonce son tir : sors de la ligne, puis fonce.", 1],
	"tate": ["PORTE-BOUCLIER", "盾", "Garde des pontons noyés, il ne baisse jamais son grand bouclier rond.",
		"Invulnérable de face : contourne-le et frappe dans le dos.", 1],
	"funa": ["FUNAYŪREI", "船幽霊", "Noyés en quête de compagnie, ils écopent les barques à la louche jusqu'à les couler.",
		"Il émerge au bord et lance sa louche : frappe-le avant qu'il replonge.", 1],
	"umibozu": ["UMIBŌZU", "海坊主", "Moine de mer au crâne lisse, il surgit des vagues sous les barques imprudentes.",
		"Un disque annonce sa remontée sous toi : écarte-toi, frappe-le émergé.", 1],
	"brute": ["BRUTE", "巨", "Un colosse d'os en armure, lent comme un buffle et dur comme le roc.",
		"Coups lents mais larges : recule, puis enchaîne-le d'un long trait.", 1],
	"ika": ["CALMAR D'ENCRE", "烏賊", "Calmar géant des abysses ; son encre aveugle les pêcheurs.",
		"Ses obus d'encre tombent sur un disque annoncé : quitte le disque.", 1],
	"umi_nyobo": ["UMI-NYŌBŌ", "海女房", "Épouse de la mer aux écailles d'argent, elle veille sur les noyés.",
		"Elle soigne ses alliés proches : abats-la en premier.", 1],
	"kitsunebi": ["KITSUNEBI", "狐火", "Feux follets des renards, ils dansent la nuit sur les rizières.",
		"Il se téléporte sur une zone annoncée ; abattu, il se scinde en deux.", 2],
	"kamaitachi": ["KAMAITACHI", "鎌鼬", "Belette du vent aux griffes de faucille : on ne voit que l'entaille.",
		"Elle taille en zigzag annoncé, puis se pose : frappe à ce moment.", 2],
	"tanuki": ["TANUKI", "狸", "Chien viverrin farceur, maître du déguisement et du tambour-ventre.",
		"Son tambour frappe autour de lui ; DORON : un leurre prend sa place.", 2],
	"shinobi": ["SHINOBI", "忍", "Ombre du clan, il frappe là où l'œil ne regarde pas.",
		"Il cligne sur ton flanc et taille devant lui : sors du disque.", 2],
	"kitsune_tsukai": ["PRÊTRESSE RENARDE", "狐使", "Elle commande aux renards de feu par des sutras murmurés.",
		"Elle invoque des feux follets : vise-la d'abord.", 2],
	"shuriken": ["LANCEUR DE SHURIKEN", "手裏剣", "Un shinobi qui garde ses distances, étoiles d'acier entre les doigts.",
		"Trois lignes de visée en éventail : glisse-toi entre elles.", 2],
	"yukionna": ["YUKI-ONNA", "雪女", "Dame des neiges au souffle glacé ; qui croise son regard s'endort pour toujours.",
		"Elle gèle une bande annoncée : la glace freine ta ruée, évite-la.", 3],
	"yuki_warashi": ["YUKI-WARASHI", "雪童", "Enfant des neiges qui joue dans la tempête… et n'en revient jamais.",
		"Il court sur toi et explose : tranche-le de loin ou esquive.", 3],
	"onryo": ["ONRYŌ", "怨霊", "Spectre vengeur aux longs cheveux noirs, que la rancune retient ici-bas.",
		"Il s'évanouit puis surgit dans ton dos : retourne-toi et frappe.", 3],
	"tsurara": ["TSURARA", "氷柱", "Stalactites hantées des grottes gelées.",
		"Tourelle fixe : ses tirs de glace suivent une ligne annoncée.", 3],
	"kasha": ["KASHA", "火車", "Chat démon qui tire un char en flammes et vole le corps des défunts.",
		"Il charge dans un couloir annoncé et laisse du feu : sors du couloir.", 4],
	"hinotama": ["HINOTAMA", "火の玉", "Âme errante changée en boule de feu au-dessus des tombes.",
		"Il pique en ligne droite annoncée : écarte-toi, puis tranche.", 4],
	"teppo": ["ARQUEBUSIER", "鉄砲", "Un fantassin tombé au combat, la mèche toujours allumée.",
		"Sa ligne de visée te suit puis se fige : bouge à cet instant.", 4],
	"tengu": ["TENGU", "天狗", "Gobelin au long nez des cimes, maître des arts martiaux.",
		"Il sème des chausse-trapes au sol : ne trace pas à travers.", 4],
	"kanabo": ["ONI À MASSUE", "金棒", "Oni cuirassé armé du kanabō, la massue de fer hérissée.",
		"Armure de face : prends-le de dos, où tes coups portent plus.", 4],
	"moryo": ["MŌRYŌ", "魍魎", "Esprit des monts et des rivières qui se nourrit des défunts.",
		"Il pose des boucliers sur ses alliés : élimine-le d'abord.", 4],
	"kagebo": ["KAGEBŌ", "影", "Ton ombre d'encre, née de tes propres traits.",
		"Il rejoue ton dernier trait vers toi : sors du chemin annoncé.", 5],
	"sumidama": ["GOUTTE D'ENCRE", "墨玉", "Une goutte tombée du pinceau du maître, devenue vivante.",
		"Sa flaque freine et elle se divise : finis les gouttelettes.", 5],
	"kasa": ["KASA-OBAKE", "傘", "Vieux parapluie devenu yōkai au bout de cent ans, sur sa jambe unique.",
		"Il bondit sur un disque annoncé, intouchable en l'air : frappe à l'atterrissage.", 5],
	"kemuri": ["NINJA DES FUMÉES", "煙", "Il se dissout dans sa bombe de fumée ; nul ne sait d'où il revient.",
		"Il resurgit dans ton dos : guette le contour rouge et le disque.", 5],
	"kunoichi": ["KUNOICHI", "くノ一", "Espionne du clan, armée d'une faucille à chaîne.",
		"Sa chaîne balaie un arc annoncé devant elle : passe derrière elle.", 5],
	"karasu": ["KARASU-TENGU", "烏", "Tengu à bec de corbeau, gardien des forêts du Kurama.",
		"Il plonge en piqué dans un couloir annoncé : écarte-toi.", 6],
	"konoha": ["KONOHA-TENGU", "木葉", "Petit tengu-feuille, vif comme une bourrasque d'automne.",
		"Il lance des feuilles en éventail : glisse entre les lignes.", 6],
	"yamabushi": ["YAMABUSHI", "山伏", "Ermite des montagnes devenu tengu ; son éventail lève des tempêtes.",
		"Son éventail souffle dans un cône annoncé : passe sur le côté.", 6],
	"kani": ["HEIKEGANI", "蟹", "Crabe portant sur sa carapace le visage d'un samouraï noyé.",
		"Carapace de face : frappe-le de côté ou de dos.", 7],
	"ningyo": ["NINGYO", "人魚", "Sirène des mers d'Orient : manger sa chair donnerait l'immortalité.",
		"Son jet d'eau suit une ligne annoncée : sors de la ligne.", 7],
	"fugu": ["FUGU", "河豚", "Poisson-globe venimeux, délice mortel des cuisiniers.",
		"Il gonfle puis frappe autour de lui : recule, frappe après.", 7],
	"gaki": ["GAKI", "餓鬼", "Fantôme affamé au ventre gonflé, que rien ne rassasie.",
		"Rapide, il se soigne à chaque morsure : abats-le vite.", 8],
	"shiryo": ["SHIRYŌ", "死霊", "Feu froid d'une âme qui a oublié son nom.",
		"Un cercle de feu froid s'ouvre sous toi : sors-en vite.", 8],
	"gokusotsu": ["GOKUSOTSU", "獄卒", "Geôlier des enfers à tête de bœuf, chaîne de fer à la main.",
		"Armure de départ : brise-la par des figures ; sa chaîne frappe en couloir.", 8],
}
# gardiens et boss -> [nom, kanji, légende, comment le battre] (noms et kanji : main.BOSS_CARDS)
const BOSS_INFO := {
	"okappa": ["Ō-KAPPA", "大河童", "Seigneur des eaux dormantes, il règne sur tous les kappa du fleuve.",
		"Frappe-le quand il sort de l'eau."],
	"uwabami": ["UWABAMI", "蟒蛇", "Serpent géant qui avale les barques entières.",
		"Quand il fait surface : un long trait sur tout son corps."],
	"tsuchigumo": ["TSUCHIGUMO", "土蜘蛛", "L'araignée des terres tisse ses cocons dans les bambous.",
		"Trace une boucle autour du cocon pour le déchirer."],
	"kyubi": ["KYŪBI", "九尾", "Renard aux neuf queues, mille ans de ruse.",
		"Entoure-le d'une boucle ou d'un ensō."],
	"yukionna": ["YUKI-ONNA", "雪女", "La dame des neiges en personne, reine du blizzard.",
		"Après son souffle, tranche les cristaux du plus petit au plus grand."],
	"gashadokuro": ["GASHADOKURO", "餓者髑髏", "Squelette géant fait des os des affamés sans sépulture.",
		"Frappe la main posée au sol, puis la colonne de la queue au crâne."],
	"ibaraki": ["IBARAKI-DŌJI", "茨木童子", "L'oni au bras tranché, revenu reprendre son bien.",
		"Touche ses sceaux de braise dans l'ordre, d'un seul trait."],
	"daidara": ["DAIDARABOTCHI", "大太法師", "Géant qui façonne les monts ; les lacs seraient ses empreintes.",
		"Tranche ses cœurs lumineux dans l'ordre."],
	"bakekujira": ["BAKEKUJIRA", "化鯨", "Baleine-squelette qui hante les côtes, suivie d'oiseaux étranges.",
		"Quand elle charge, trace un aller-retour juste devant sa tête."],
	"kuronami": ["KURO-NAMI", "黒波", "La vague noire : l'encre de la Grande Vague devenue tempête.",
		"Coupe ses griffes en longueur, renvoie les vagues d'un aller-retour."],
	"karasu_o": ["KARASU-TENGU", "烏天狗", "Chef des corbeaux du Kurama, lame et ailes d'ébène.",
		"Quand il se pose, trace une boucle autour de lui."],
	"sojobo": ["SŌJŌBŌ", "僧正坊", "Roi des tengu du mont Kurama, maître d'armes des héros.",
		"Tranche sa tornade de plumes, puis entoure-le d'une boucle."],
	"umibozu_o": ["UMIBŌZU", "海坊主", "Moine géant des abysses, plus haut qu'un mât.",
		"Crève ses bulles d'écume dans l'ordre, d'un seul trait."],
	"ryujin": ["RYŪJIN", "龍神", "Roi dragon de la mer, maître des perles des marées.",
		"Tranche ses cinq perles dans l'ordre, d'un seul trait."],
	"gaki_o": ["GAKI-Ō", "餓鬼王", "Roi des affamés, enchaîné au fond de Yomi.",
		"Tranche ses trois chaînes en travers."],
	"izanami": ["IZANAMI", "伊邪那美", "Déesse mère devenue reine des morts au pays de Yomi.",
		"Coupe les fils des huit dieux du tonnerre, puis entoure-la d'un ensō."],
}
# variantes (scission, gouttelettes, leurre) comptées avec leur ennemi ; "" : jamais compté
const SUB_KINDS := {"kitsunebi_s": "kitsunebi", "sumidama_s": "sumidama", "tanuki_d": ""}
const NINJAS := ["shinobi", "shuriken", "kemuri", "kunoichi"]

signal closed

var meta  # instance de meta.gd, fournie par main
var main: Node  # main.gd : héros et effets pour monter les modèles, calendrier des ennemis (kind_room)
var minis: Dictionary = {}  # monde -> gardien (main.MINI_BOSS)
var bosses: Dictionary = {}  # monde -> boss (main.WORLD_BOSS)

static var _portraits := {}  # ennemi -> ImageTexture (gardés d'une ouverture à l'autre)

var _t := 0.0
var _u := 1.0
var _top := 0.0  # marges de sécurité (encoche, barre de geste), en pixels
var _bot := 0.0
var _paper := Toon.PAPER
var _wash := Toon.WASHI
var _ink := Toon.SUMI
var _accent := Toon.VERMILION
var _title := FontVariation.new()
var _ui := FontVariation.new()
var _sb := StyleBoxFlat.new()  # réutilisée pour chaque cadre dessiné
var _back: Control
var _list: Control  # la grille, découpée à sa zone
var _sheet: Control  # fiche détaillée, par-dessus tout
var _entries: Array = []  # {id, boss, mini, world}
var _heads: Array = []  # [y du titre (contenu), monde]
var _cards: Array = []  # [Rect2 (contenu), index de l'entrée] : même ordre que _entries
var _layout_w := -1.0
var _view := Rect2()  # zone de la grille (écran)
var _content_h := 0.0
var _scroll := 0.0
var _vel := 0.0
var _holding := false
var _dragging := false
var _spinning := false
var _press_pos := Vector2.ZERO
var _press_scroll := 0.0
var _drag_accum := 0.0
var _pressed := ""
var _shake_i := -1  # fiche inconnue touchée : elle tremble
var _shake := 0.0
var _found := 0
# fiche détaillée
var _detail := ""  # id de l'ennemi affiché ("" : fermée)
var _detail_i := -1
var _detail_t := 0.0
var _panel := Rect2()
var _close_rect := Rect2()
var _view3d := Rect2()
var _yaw := 0.0
# rendu 3D (portraits un par un, vue tournante du détail)
var _can_3d := false
var _vp: SubViewport = null
var _vp_cam: Camera3D = null
var _vp_root: Node3D = null
var _pending: Array = []  # index d'entrées à photographier
var _cur = null  # modèle en cours de pose (peut être libéré : jamais typé)
var _cur_id := ""
var _cur_wait := 0
var _gap := 0
var _big: SubViewport = null
var _big_cam: Camera3D = null
var _big_pivot: Node3D = null


# ------------------------------------------------------------------ données

## Ennemi compté dans le bestiaire pour un type de jeu ("" : aucun ; variantes ramenées à leur ennemi).
static func base_kind(k: String) -> String:
	if SUB_KINDS.has(k):
		return String(SUB_KINDS[k])
	return k if INFO.has(k) else ""


static func name_of(k: String) -> String:
	if INFO.has(k):
		var row: Array = INFO[k]
		return String(row[0])
	return k.to_upper()


## UI v2 : plus aucun kanji dans l'interface. La colonne reste documentaire dans INFO ; rien ne l'affiche.
static func kanji_of(_k: String) -> String:
	return ""


static func is_ninja(k: String) -> bool:
	return k in NINJAS


func _info(i: int) -> Array:
	var en: Dictionary = _entries[i]
	var id := String(en["id"])
	if bool(en["boss"]):
		var b: Array = BOSS_INFO.get(id, [id.to_upper(), "", "", ""])
		return b
	var r: Array = INFO.get(id, [id.to_upper(), "", "", "", 1])
	return r


## Clé de la sauvegarde (meta.seen) : les boss sont rangés à part (yuki-onna est aussi un ennemi courant).
func _key(i: int) -> String:
	var en: Dictionary = _entries[i]
	return ("boss_" if bool(en["boss"]) else "") + String(en["id"])


func _is_seen(i: int) -> bool:
	return meta != null and bool(meta.kind_seen(_key(i)))


func _room_of(k: String, wi: int) -> int:
	if main != null and main.has_method("kind_room"):
		return int(main.call("kind_room", k, wi))
	return 1


func _by_rank(a: Array, b: Array) -> bool:
	if int(a[0]) != int(b[0]):
		return int(a[0]) < int(b[0])
	return int(a[1]) < int(b[1])


## Fiches dans l'ordre du jeu : par monde (le premier dont les poids citent l'ennemi), puis par salle
## d'arrivée dans ce monde ; le gardien et le boss ferment chaque monde.
func _build_entries() -> void:
	_entries.clear()
	var nw: int = Worlds.WORLDS.size()
	var first := {}
	for wi in range(1, nw + 1):
		var wd: Dictionary = Worlds.world(wi)
		var ws: Dictionary = wd.get("enemies", {})
		for k in ws.keys():
			var kk := String(k)
			if INFO.has(kk) and not first.has(kk):
				first[kk] = wi
	var order: Array = INFO.keys()
	for k in order:
		var kk := String(k)
		if not first.has(kk):
			var row: Array = INFO[kk]
			first[kk] = clampi(int(row[4]), 1, nw)
	for wi in range(1, nw + 1):
		var ranked: Array = []
		for oi in order.size():
			var kk := String(order[oi])
			if int(first[kk]) == wi:
				ranked.append([_room_of(kk, wi), oi, kk])
		ranked.sort_custom(_by_rank)
		for rk in ranked:
			_entries.append({"id": String(rk[2]), "boss": false, "mini": false, "world": wi})
		var mk := String(minis.get(wi, ""))
		if BOSS_INFO.has(mk):
			_entries.append({"id": mk, "boss": true, "mini": true, "world": wi})
		var bk := String(bosses.get(wi, ""))
		if BOSS_INFO.has(bk):
			_entries.append({"id": bk, "boss": true, "mini": false, "world": wi})
	_found = 0
	for i in _entries.size():
		if _is_seen(i):
			_found += 1


# ------------------------------------------------------------------ ouverture

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title.base_font = UiKit.TITLE_FONT
	_title.spacing_glyph = UiKit.TITLE_SPACING
	_ui.base_font = UiKit.UI_FONT
	_ui.spacing_glyph = UiKit.CAPS_SPACING
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.clip_contents = true
	add_child(_list)
	_list.draw.connect(_draw_list)
	# retour à l'accueil : bouton rond à la maison, au même endroit que ceux de l'Atelier et de la garde-robe
	_back = InkButton.new()
	_back.text = "RETOUR"
	_back.style = "round"
	_back.icon = "home"
	_back.font = _ui
	add_child(_back)
	_back.pressed.connect(close)
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.visible = false
	add_child(_sheet)
	_sheet.draw.connect(_draw_sheet)


func open() -> void:
	_t = 0.0
	_scroll = 0.0
	_vel = 0.0
	_holding = false
	_dragging = false
	_spinning = false
	_pressed = ""
	_shake = 0.0
	_detail = ""
	_detail_i = -1
	_layout_w = -1.0
	_cards.clear()
	_read_theme()
	_build_entries()
	var hero_ok := false
	if main != null:
		hero_ok = is_instance_valid(main.get("hero"))
	_can_3d = DisplayServer.get_name() != "headless" and hero_ok
	_pending.clear()
	if _can_3d:
		_make_portrait_stage()
		# les ennemis déjà vus d'abord, puis les silhouettes
		for want in [true, false]:
			for i in _entries.size():
				var en: Dictionary = _entries[i]
				if bool(en["boss"]) or _portraits.has(String(en["id"])):
					continue
				if _is_seen(i) == bool(want):
					_pending.append(i)
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	_holding = false
	_dragging = false
	_detail = ""
	_detail_i = -1
	_sheet.visible = false
	_free_3d()
	closed.emit()


## Retour (bouton Android) : la fiche se referme d'abord, puis le bestiaire.
func back() -> void:
	if _detail != "":
		_close_detail()
	else:
		close()


func _read_theme() -> void:
	if meta == null:
		return
	var th: Dictionary = meta.theme_colors()
	_paper = th["paper"]
	_wash = th["wash"]
	_ink = th["ink"]
	_accent = th["accent"]


func _open_detail(i: int) -> void:
	var en: Dictionary = _entries[i]
	_detail = String(en["id"])
	_detail_i = i
	_detail_t = 0.0
	_yaw = 0.0
	if meta != null:
		meta.kind_viewed(_key(i))
	_close_big()
	if _can_3d and not bool(en["boss"]):
		_make_big(_detail)


func _close_detail() -> void:
	_detail = ""
	_detail_i = -1
	_spinning = false
	_close_big()


## Rectangle (écran) de la fiche d'un ennemi : pour le robot du CI.
func card_rect(id: String) -> Rect2:
	for c in _cards:
		var i := int(c[1])
		var en: Dictionary = _entries[i]
		if String(en["id"]) == id and not bool(en["boss"]):
			var r: Rect2 = c[0]
			return Rect2(r.position + _view.position - Vector2(0, _scroll), r.size)
	return Rect2()


func reset_scroll() -> void:
	_scroll = 0.0
	_vel = 0.0


# ------------------------------------------------------------------ entrée

func _target_at(p: Vector2) -> String:
	if _detail != "":
		if _close_rect.has_point(p) or not _panel.has_point(p):
			return "close"
		if _view3d.has_point(p):
			return "spin"
		return "panel"
	if not _view.has_point(p):
		return ""
	var cp := p - _view.position + Vector2(0, _scroll)
	for c in _cards:
		var r: Rect2 = c[0]
		if r.has_point(cp):
			return "card:%d" % int(c[1])
	return ""


## Souris (le tactile est émulé en souris : project.godot), comme l'Atelier : appui, glissé, relâché.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		accept_event()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed and _detail == "" and _t >= 0.3:
				var dir: float = -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				_scroll = clampf(_scroll + dir * 70.0 * _u, 0.0, _max_scroll())
				_vel = 0.0
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			# le toucher qui a ouvert le bestiaire n'ouvre pas de fiche
			_pressed = _target_at(mb.position) if _t >= 0.3 else ""
			_holding = true
			_dragging = false
			_spinning = _pressed == "spin"
			_press_pos = mb.position
			_press_scroll = _scroll
			_drag_accum = 0.0
			_vel = 0.0
			return
		# relâché : on n'agit que si l'appui et le relâché tombent sur la même cible (et sans glissé)
		var start := _pressed
		var was_drag := _dragging
		var was_holding := _holding
		_pressed = ""
		_holding = false
		_dragging = false
		_spinning = false
		if was_drag or not was_holding or _t < 0.3 or start == "":
			return
		if _target_at(mb.position) == start or mb.position.distance_to(_press_pos) <= 12.0 * _u:
			_tap(start)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _holding or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		accept_event()
		if _detail != "":
			# fiche : le doigt fait tourner le modèle
			if _spinning:
				_yaw += mm.relative.x * 0.012
				if absf(mm.position.x - _press_pos.x) > DRAG_START * _u:
					_dragging = true
			return
		if not _dragging:
			if not _view.has_point(_press_pos) or absf(mm.position.y - _press_pos.y) <= DRAG_START * _u:
				return
			_dragging = true
			_pressed = ""  # un glissé n'appuie sur rien
			_press_pos = mm.position
			_press_scroll = _scroll
		_scroll = _rubber(_press_scroll - (mm.position.y - _press_pos.y))
		_drag_accum += mm.relative.y


func _max_scroll() -> float:
	return maxf(0.0, _content_h - _view.size.y)


## Au-delà des bords, la liste résiste (élastique).
func _rubber(raw: float) -> float:
	var hi := _max_scroll()
	if raw < 0.0:
		return raw * 0.35
	if raw > hi:
		return hi + (raw - hi) * 0.35
	return raw


func _tap(key: String) -> void:
	if key == "close":
		_close_detail()
		return
	if key == "panel" or key == "spin":
		return
	if key.begins_with("card:"):
		var i := int(key.substr(5))
		if i < 0 or i >= _entries.size():
			return
		if not _is_seen(i):
			_shake_i = i
			_shake = 1.0
			return
		_open_detail(i)


# ------------------------------------------------------------------ rendu 3D

## Petit monde 3D à part (ciel transparent, soleil de face, contre-jour froid), caméra orthographique.
## Renvoie [SubViewport, Camera3D, racine des modèles].
func _make_stage(px: Vector2i, live: bool) -> Array:
	var vp := SubViewport.new()
	vp.size = px
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.9, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.environment = env
	cam.near = 0.1
	cam.far = 60.0
	vp.add_child(cam)
	cam.current = true
	# soleil chaud venu de devant (le modèle regarde -Z, la caméra est de ce côté)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(150), 0)
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.92, 0.82)
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-30), 0)
	fill.light_energy = 0.25
	fill.light_color = Color(0.7, 0.8, 1.0)
	vp.add_child(fill)
	var root := Node3D.new()
	vp.add_child(root)
	return [vp, cam, root]


func _make_portrait_stage() -> void:
	if _vp != null:
		return
	var parts: Array = _make_stage(PORTRAIT, false)
	_vp = parts[0]
	_vp_cam = parts[1]
	_vp_root = parts[2]
	_cur = null
	_cur_id = ""
	_gap = 0


## Le vrai modèle de l'ennemi, monté comme au préchauffage de main (_warmup) : figé, pose d'attente.
func _build_model(id: String, parent: Node3D) -> Node3D:
	if main == null:
		return null
	var hero_v = main.get("hero")
	if not is_instance_valid(hero_v):
		return null
	var hero_n: Node3D = hero_v as Node3D
	if hero_n == null:
		return null
	var e := Enemy.new()
	e.setup(id, hero_n, main)
	parent.add_child(e)
	e.process_mode = Node.PROCESS_MODE_DISABLED
	_pose(e)
	return e


## Pose de portrait : au centre, face à la caméra, apparition terminée, animation d'attente (elle seule tourne).
func _pose(e: Node3D) -> void:
	e.position = Vector3.ZERO
	var b = e.get("body")
	if b is Node3D:
		var bn: Node3D = b as Node3D
		bn.position = Vector3.ZERO
		bn.rotation = Vector3.ZERO
		bn.scale = Vector3.ONE
		bn.visible = true
	var d = e.get("_deco")
	if d is Node3D:
		(d as Node3D).visible = true
	var c = e.get("ch")
	if c is Node3D:
		# le personnage seul reste vivant (squelette, animation, accessoires sur les os) : l'ennemi, lui, est figé
		(c as Node3D).process_mode = Node.PROCESS_MODE_ALWAYS
		var ap = c.get("anim")
		var idle := String(c.get("idle"))
		if ap is AnimationPlayer:
			var player: AnimationPlayer = ap as AnimationPlayer
			player.process_mode = Node.PROCESS_MODE_ALWAYS
			if idle != "" and player.has_animation(idle):
				c.call("play", idle, 1.0, 0.0)
				player.seek(0.35, true)
		elif idle != "" and c.has_method("play"):
			# rigs procéduraux (ninja, encre) : l'attente tout de suite, pas l'apparition
			c.call("play", idle, 1.0, 0.0)


## Cadre la caméra orthographique sur les maillages visibles du modèle (vue de trois quarts, un peu d'en haut).
func _frame_cam(e: Node3D, cam: Camera3D, aspect: float, pad: float) -> void:
	var box := AABB()
	var first := true
	for n in e.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if first:
			box = bb
			first = false
		else:
			box = box.merge(bb)
	if first:
		box = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.7, 1.0))
	var c := box.get_center()
	var hgt := maxf(box.size.y, 0.6)
	var wid := maxf(box.size.x, box.size.z) * 0.8
	cam.size = maxf(hgt, wid / maxf(aspect, 0.1)) * pad
	var dir := Vector3(sin(0.5), 0.3, -cos(0.5)).normalized()
	cam.look_at_from_position(c + dir * 14.0, c, Vector3.UP)


## Prochaine fiche à photographier : d'abord celles qui sont à l'écran.
func _next_pending() -> int:
	var lo := _scroll - 40.0 * _u
	var hi := _scroll + _view.size.y + 40.0 * _u
	for pi in _pending.size():
		var i := int(_pending[pi])
		if i < _cards.size():
			var r: Rect2 = _cards[i][0]
			if r.end.y >= lo and r.position.y <= hi:
				_pending.remove_at(pi)
				return i
	return int(_pending.pop_front())


## Un portrait à la fois : le modèle est posé, rendu une fois, lu en image, puis libéré.
func _step_portraits() -> void:
	if _vp == null:
		return
	if _cur_id != "":
		_cur_wait -= 1
		if _cur_wait > 0:
			return
		var tex := _vp.get_texture()
		if tex != null:
			var img := tex.get_image()
			if img != null and not img.is_empty():
				_portraits[_cur_id] = ImageTexture.create_from_image(img)
		if is_instance_valid(_cur):
			_cur.queue_free()
		_cur = null
		_cur_id = ""
		_gap = PORTRAIT_GAP
		return
	if _pending.is_empty():
		return
	if _gap > 0:
		_gap -= 1
		return
	if _dragging or absf(_vel) > 300.0 * _u:
		return  # le défilement d'abord
	var i := _next_pending()
	if i < 0 or i >= _entries.size():
		return
	var en: Dictionary = _entries[i]
	var id := String(en["id"])
	if _portraits.has(id):
		return
	var e := _build_model(id, _vp_root)
	if e == null:
		_pending.clear()
		return
	_frame_cam(e, _vp_cam, float(PORTRAIT.x) / float(PORTRAIT.y), 1.08)
	_cur = e
	_cur_id = id
	_cur_wait = 3
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _make_big(id: String) -> void:
	var parts: Array = _make_stage(BIG_VIEW, true)
	_big = parts[0]
	_big_cam = parts[1]
	var root: Node3D = parts[2]
	_big_pivot = Node3D.new()
	root.add_child(_big_pivot)
	var e := _build_model(id, _big_pivot)
	if e == null:
		_close_big()
		return
	_frame_cam(e, _big_cam, float(BIG_VIEW.x) / float(BIG_VIEW.y), 1.2)


func _close_big() -> void:
	if _big != null:
		_big.queue_free()
	_big = null
	_big_cam = null
	_big_pivot = null


func _free_3d() -> void:
	if is_instance_valid(_cur):
		_cur.queue_free()
	_cur = null
	_cur_id = ""
	_pending.clear()
	if _vp != null:
		_vp.queue_free()
	_vp = null
	_vp_cam = null
	_vp_root = null
	_close_big()


# ------------------------------------------------------------------ mise en page

func _layout() -> void:
	var w := size.x
	var h := size.y
	var ins := UiKit.safe_insets(size)
	_top = ins.x
	_bot = ins.y
	_u = w / 400.0
	var u := _u
	var top := _top + 84.0 * u
	_view = Rect2(Vector2(0, top), Vector2(w, maxf(10.0, h - _bot - top)))
	_list.position = _view.position
	_list.size = _view.size
	if absf(_layout_w - w) < 0.5 and _cards.size() == _entries.size():
		return
	_layout_w = w
	_cards.clear()
	_heads.clear()
	var mx: float = UiKit.SP_M * u
	var gap := 8.0 * u
	var cw := (w - 2.0 * mx - gap * float(COLS - 1)) / float(COLS)
	var chh := cw + 34.0 * u
	var y := 4.0 * u
	var cur_w := 0
	var col := 0
	for i in _entries.size():
		var en: Dictionary = _entries[i]
		var wi := int(en["world"])
		if wi != cur_w:
			if col > 0:
				y += chh + gap
				col = 0
			if cur_w != 0:
				y += 12.0 * u
			cur_w = wi
			_heads.append([y + 20.0 * u, wi])
			y += 32.0 * u
		_cards.append([Rect2(Vector2(mx + (cw + gap) * float(col), y), Vector2(cw, chh)), i])
		col += 1
		if col >= COLS:
			col = 0
			y += chh + gap
	if col > 0:
		y += chh + gap
	_content_h = y + 24.0 * u


func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	var real := UiKit.real_delta()
	_t += real
	_detail_t += real
	_shake = maxf(0.0, _shake - real * 3.0)
	_layout()
	var hi := _max_scroll()
	if _dragging and _detail == "":
		if real > 0.0:
			_vel = lerpf(_vel, -_drag_accum / real, 0.35)
		_drag_accum = 0.0
	else:
		_drag_accum = 0.0
		# lancé : la liste continue sur son élan puis freine ; elle revient en place si elle dépasse
		if absf(_vel) > 2.0:
			_scroll += _vel * real
			_vel *= exp(-4.0 * real)
		else:
			_vel = 0.0
		if _scroll < 0.0 or _scroll > hi:
			_vel *= exp(-18.0 * real)
			_scroll = lerpf(_scroll, clampf(_scroll, 0.0, hi), 1.0 - exp(-14.0 * real))
	_step_portraits()
	if _big_pivot != null:
		if not _spinning:
			_yaw += real * 0.6
		_big_pivot.rotation.y = _yaw
	var u := _u
	var a := UiKit.ease_out(clampf(_t / 0.35, 0.0, 1.0))
	var ib: float = UiKit.ICON_BTN * u
	_back.size = Vector2(ib, ib)
	_back.position = Vector2(UiKit.HEAD_X * u - ib / 2.0, _top + UiKit.HEAD_Y * u - ib / 2.0 - 16.0 * u * (1.0 - a))
	_back.modulate.a = a
	_back.visible = _detail == ""
	_sheet.visible = _detail != ""
	queue_redraw()
	_list.queue_redraw()
	if _sheet.visible:
		_sheet.queue_redraw()


# ------------------------------------------------------------------ dessin

func _fit_fs(font: Font, txt: String, fs: int, maxw: float) -> int:
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > maxw and tw > 0.0 and maxw > 0.0:
		return maxi(1, int(float(fs) * maxw / tw))
	return maxi(1, fs)


## Image de taille sz posée dans r (proportions gardées, calée en bas).
func _fit(r: Rect2, sz: Vector2) -> Rect2:
	if sz.x <= 0.0 or sz.y <= 0.0:
		return r
	var k := minf(r.size.x / sz.x, r.size.y / sz.y)
	var s := sz * k
	return Rect2(r.position + Vector2((r.size.x - s.x) / 2.0, r.size.y - s.y), s)


func _draw() -> void:
	if size.x < 10.0:
		return
	var w := size.x
	var u := _u
	var a := UiKit.ease_out(clampf(_t / 0.3, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(_wash, a))
	UiKit.asanoha(self, Rect2(Vector2.ZERO, size), Color(_ink, 0.035 * a), 30.0 * u)
	# en-tête commun : retour à gauche (InkButton rond), titre souligné de vermillon et sceau 妖 (yōkai)
	var hy := _top
	UiKit.screen_title(self, _title, "BESTIAIRE", Vector2(w / 2.0, hy + UiKit.HEAD_BASE * u - 8.0 * u * (1.0 - a)), u, _ink, a,
		"", w - 2.0 * 96.0 * u, UiKit.ease_out(clampf((_t - 0.15) / 0.4, 0.0, 1.0)))
	# fiches découvertes / total, en haut à droite
	var txt := "%d/%d" % [_found, _entries.size()]
	var fs := int(UiKit.FS_NUMBER * 0.8 * u)
	var tw := UiKit.TITLE_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(UiKit.TITLE_FONT, Vector2(w - UiKit.SP_M * u - tw, hy + UiKit.HEAD_Y * u + float(fs) * 0.36), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_ink, 0.75 * a))


func _draw_list() -> void:
	if _list.size.x < 10.0:
		return
	var u := _u
	var a := UiKit.ease_out(clampf(_t / 0.35, 0.0, 1.0))
	var vh := _list.size.y
	var x0: float = UiKit.SP_M * u
	var x1: float = _list.size.x - UiKit.SP_M * u
	for hd in _heads:
		var y := float(hd[0]) - _scroll
		if y < -30.0 * u or y > vh + 30.0 * u:
			continue
		var wi := int(hd[1])
		var wd: Dictionary = Worlds.world(wi)
		var lab := UiKit.plain("MONDE %d  ·  %s" % [wi, String(wd.get("name", ""))]).to_upper()
		UiKit.section(_list, _ui, lab, x0, x1, y, u, _ink, a, String(wd.get("kanji", "")))
	for c in _cards:
		var r: Rect2 = c[0]
		var rr := Rect2(r.position - Vector2(0, _scroll), r.size)
		if rr.end.y < 0.0 or rr.position.y > vh:
			continue
		_draw_card(rr, int(c[1]), a)
	# barre de défilement discrète
	if _content_h > vh + 1.0:
		var bh := maxf(24.0 * u, vh * vh / _content_h)
		var k := clampf(_scroll / maxf(1.0, _max_scroll()), 0.0, 1.0)
		var br := Rect2(Vector2(_list.size.x - 5.0 * u, (vh - bh) * k), Vector2(3.0 * u, bh))
		_list.draw_style_box(UiKit.box(_sb, Color(_ink, 0.2 * a), int(1.5 * u)), br)


func _draw_card(r0: Rect2, i: int, a: float) -> void:
	var u := _u
	var en: Dictionary = _entries[i]
	var id := String(en["id"])
	var boss := bool(en["boss"])
	var mini := bool(en["mini"])
	var seen := _is_seen(i)
	var info := _info(i)
	var r := r0
	if i == _shake_i and _shake > 0.0:
		r.position.x += sin(_shake * 28.0) * 4.0 * u * _shake
	var bc := Color(_ink, 0.16)
	var bw: float = UiKit.BW
	if seen and boss:
		bc = Color(UiKit.gold(), 0.9) if mini else Color(_accent, 0.9)
		bw = UiKit.BW_STRONG
	_list.draw_style_box(UiKit.box(_sb, Color(_paper, (0.97 if seen else 0.55) * a), int(UiKit.R_M * u), Color(bc, bc.a * a), maxi(1, int(bw * u))), r)
	var pr := Rect2(r.position + Vector2(5.0, 5.0) * u, Vector2(r.size.x - 10.0 * u, r.size.x - 10.0 * u))
	UiKit.seigaiha(_list, pr, Color(_ink, UiKit.A_PATTERN * a), 9.0 * u)
	if boss:
		# gardien et boss : leur sceau à picto (couronne or, oni vermillon), grand ; inconnu : « ? »
		var s := pr.size.x * 0.56
		var sr := Rect2(pr.get_center() - Vector2(s, s) / 2.0, Vector2(s, s))
		if seen:
			UiKit.monster_badge(_list, _sb, sr, mini, a, u)
		else:
			_unknown(_list, pr.get_center(), s, a)
	else:
		var tex: Texture2D = _portraits.get(id, null)
		if tex != null:
			var fr := _fit(pr, tex.get_size())
			# inconnu : silhouette d'encre
			_list.draw_texture_rect(tex, fr, false, Color(1, 1, 1, a) if seen else Color(0, 0, 0, 0.72 * a))
		elif seen:
			# portrait pas encore rendu : picto oni en filigrane (UI v2 : plus de kanji)
			UiKit.draw_icon(_list, "hud/oni", pr.get_center(), pr.size.x * 0.42, 0.25 * a, _ink)
		else:
			_unknown(_list, pr.get_center(), pr.size.x * 0.42, a)
	# nom (ou ???), puis victoires ou monde où il rôde
	var nm: String = UiKit.plain(String(info[0])) if seen else "???"
	var nfs := _fit_fs(UiKit.TITLE_FONT, nm, int(UiKit.FS_CAPTION * 1.15 * u), r.size.x - 8.0 * u)
	UiKit.text(_list, UiKit.TITLE_FONT, nm, Vector2(r.get_center().x, pr.end.y + 14.0 * u), nfs, Color(_ink, (0.9 if seen else 0.45) * a))
	var sub := ""
	var sc := Color(_ink, 0.5 * a)
	if not seen:
		sub = "MONDE %d" % int(en["world"])
	elif boss:
		sub = "GARDIEN" if mini else "BOSS"
		sc = Color(UiKit.gold() if mini else _accent, a)
	var kills: int = int(meta.kind_kills(_key(i))) if seen else 0
	if seen and kills > 0:
		sub = ("%s  ·  ×%d" % [sub, kills]) if sub != "" else "×%d" % kills
	if sub != "":
		var sfs := _fit_fs(_ui, sub, int(UiKit.FS_MICRO * u), r.size.x - 8.0 * u)
		UiKit.text(_list, _ui, sub, Vector2(r.get_center().x, pr.end.y + 27.0 * u), sfs, sc)
	# nouvelle fiche (jamais ouverte) : point vermillon
	if seen and bool(meta.kind_fresh(_key(i))):
		_list.draw_circle(Vector2(r.end.x - 9.0 * u, r.position.y + 9.0 * u), 4.0 * u, Color(_accent, a))


## Fiche inconnue : un « ? » d'encre pâle (plus de hanko).
func _unknown(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var fs := maxi(1, int(s * 0.7))
	UiKit.text(ci, UiKit.TITLE_FONT, "?", c + Vector2(0, float(fs) * 0.36), fs, Color(_ink, 0.3 * a))


func _draw_sheet() -> void:
	if _detail_i < 0 or _detail_i >= _entries.size():
		return
	var w := size.x
	var h := size.y
	var u := _u
	var en: Dictionary = _entries[_detail_i]
	var boss := bool(en["boss"])
	var info := _info(_detail_i)
	var k := UiKit.ease_out(clampf(_detail_t / 0.25, 0.0, 1.0))
	_sheet.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45 * k))
	var pw := w - 2.0 * UiKit.SP_M * u
	var ph := minf(h - _top - _bot - 40.0 * u, 600.0 * u)
	var px := (w - pw) / 2.0
	var py := _top + (h - _top - _bot - ph) / 2.0 + 30.0 * u * (1.0 - k)
	_panel = Rect2(Vector2(px, py), Vector2(pw, ph))
	UiKit.sheet(_sheet, _panel, _paper, _ink, k, u, 3.0, 54.0)
	# fermer : flèche (fenêtre qui se referme sur l'écran d'avant)
	var hc := _panel.position + Vector2(UiKit.HEAD_X, UiKit.HEAD_Y) * u
	UiKit.back_button(_sheet, hc, u, k, 1.0 if _pressed == "close" else 0.0)
	_close_rect = UiKit.back_rect(hc, u)
	# la vue : le modèle qui tourne, posé sur un ensō d'encre
	var vh := clampf(ph - 330.0 * u, 140.0 * u, 270.0 * u)
	_view3d = Rect2(Vector2(px + 16.0 * u, py + 62.0 * u), Vector2(pw - 32.0 * u, vh))
	var vc := _view3d.get_center()
	UiKit.enso(_sheet, vc, vh * 0.44, 3.0 * u, Color(_ink, 0.12 * k), k)
	if boss:
		var s := vh * 0.62
		UiKit.monster_badge(_sheet, _sb, Rect2(vc - Vector2(s, s) / 2.0, Vector2(s, s)), bool(en["mini"]), k, u)
	else:
		var ell := PackedVector2Array()
		for j in 24:
			var ang := TAU * float(j) / 24.0
			ell.append(Vector2(vc.x + cos(ang) * vh * 0.32, _view3d.end.y - 10.0 * u + sin(ang) * vh * 0.05))
		_sheet.draw_colored_polygon(ell, Color(_ink, 0.1 * k))
		var tex: Texture2D = null
		if _big != null:
			tex = _big.get_texture()
		else:
			tex = _portraits.get(_detail, null)
		if tex != null:
			_sheet.draw_texture_rect(tex, _fit(_view3d, tex.get_size()), false, Color(1, 1, 1, k))
		else:
			UiKit.draw_icon(_sheet, "hud/oni", vc, vh * 0.45, 0.2 * k, _ink)
	# nom (UI v2 : sans sceau à kanji)
	var cx := w / 2.0
	var ny := _view3d.end.y + 34.0 * u
	UiKit.screen_title(_sheet, _title, UiKit.plain(String(info[0])), Vector2(cx, ny), u, _ink, k, "", pw - 40.0 * u, k)
	# légende (folklore)
	var bfs := int(UiKit.FS_BODY * u)
	var ly := ny + 32.0 * u
	var lore := UiKit.wrap(_ui, UiKit.plain(String(info[2])), bfs, pw - 48.0 * u, ["·", ":", "»"])
	var nl := mini(lore.size(), 3)
	for li in nl:
		UiKit.text(_sheet, _ui, lore[li], Vector2(cx, ly + 15.0 * u * float(li)), bfs, Color(_ink, 0.6 * k))
	ly += 15.0 * u * float(nl) + 4.0 * u
	# comment il attaque et comment le battre : encart au filet vermillon
	var tip := UiKit.wrap(_ui, UiKit.plain(String(info[3])), bfs, pw - 76.0 * u, ["·", ":", "»"])
	var nt := mini(tip.size(), 3)
	var tr := Rect2(Vector2(px + 20.0 * u, ly), Vector2(pw - 40.0 * u, 14.0 * u + 15.0 * u * float(nt)))
	_sheet.draw_style_box(UiKit.box(_sb, Color(_ink, 0.06 * k), int(UiKit.R_S * u)), tr)
	_sheet.draw_rect(Rect2(tr.position + Vector2(0, 6.0 * u), Vector2(3.0 * u, tr.size.y - 12.0 * u)), Color(_accent, k))
	UiKit.shuriken(_sheet, Vector2(tr.position.x + 17.0 * u, tr.position.y + 7.0 * u + 7.5 * u), 6.0 * u, Color(_accent, k), 0.3)
	for ti in nt:
		_sheet.draw_string(_ui, Vector2(tr.position.x + 30.0 * u, tr.position.y + 7.0 * u + 15.0 * u * float(ti) + float(bfs) * 0.95),
			tip[ti], HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(_ink, 0.9 * k))
	# victoires et monde de la rencontre
	var sy := tr.end.y + 30.0 * u
	var key := _key(_detail_i)
	var kills: int = int(meta.kind_kills(key)) if meta != null else 0
	var lx := px + pw * 0.28
	var nfs := int(UiKit.FS_NUMBER * 1.2 * u)
	UiKit.text(_sheet, UiKit.TITLE_FONT, str(kills), Vector2(lx, sy), nfs, Color(_ink, k))
	UiKit.text(_sheet, _ui, "VAINCUS", Vector2(lx, sy + 16.0 * u), int(UiKit.FS_CAPTION * u), Color(_ink, UiKit.A_CAPTION * k))
	var fw: int = int(meta.kind_world(key)) if meta != null else int(en["world"])
	if fw <= 0:
		fw = int(en["world"])
	var wd: Dictionary = Worlds.world(fw)
	var wcol: Color = wd.get("color", Toon.PRUSSIAN)
	var rx := px + pw * 0.72
	var ss := 22.0 * u
	var wl := "MONDE %d" % fw
	var lfs := int(UiKit.FS_LABEL * u)
	var lw := _ui.get_string_size(wl, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var gx := rx - (ss + 6.0 * u + lw) / 2.0
	UiKit.world_badge(_sheet, _sb, Rect2(Vector2(gx, sy - ss * 0.8), Vector2(ss, ss)), String(wd.get("kanji", "")), wcol, k)
	_sheet.draw_string(_ui, Vector2(gx + ss + 6.0 * u, sy - ss * 0.8 + ss / 2.0 + float(lfs) * 0.36), wl, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(_ink, k))
	UiKit.text(_sheet, _ui, "1RE RENCONTRE", Vector2(rx, sy + 16.0 * u), int(UiKit.FS_CAPTION * u), Color(_ink, UiKit.A_CAPTION * k))
