extends RefCounted
## Progression permanente, sauvegardée entre les parties :
## - sumi (encre) : la Pierre à encre, six lignes d'améliorations à rangs ;
## - sceaux : dons permanents achetés une fois (rouleau de départ, relance, légendaires...) ;
## - Vues : collection d'estampes ; chacune débloque une apparence (écharpe, sillage de lame, encre du trait).

const Toon = preload("res://scripts/toon.gd")
const Data = preload("res://scripts/power_data.gd")

const SAVE_PATH := "user://ippitsu_meta.cfg"
const MAX_PRINTS := 24
const SUMI_PER_ROOM := 8  # réglage d'équilibrage : bonus d'encre par salle franchie (0 = §5.1 strict)
const MINI_ROOM := 8  # = main.MINI_ROOM (salle du gardien)
const WORLD_NAMES := ["Grande Vague", "Tanabata", "Cent Contes", "Fuji Rouge", "Trente-six Vues"]

## Ordre d'affichage des lignes de la Pierre à encre.
const ORDER := ["brush", "ink", "paper", "breath", "purse", "choice"]

## Données des lignes : nom affiché, idéogramme, coûts (un par rang), texte d'effet (valeur = base + step × rang).
## Coûts revus : un rang à peu près toutes les une à deux parties au début.
const LINES := {
	"brush": {"name": "Pinceau long", "kanji": "筆", "costs": [30, 60, 110, 170, 250],
		"fmt": "Élan max +%d m", "base": 0, "step": 1},
	"ink": {"name": "Encre vive", "kanji": "墨", "costs": [30, 60, 110, 170, 250],
		"fmt": "Recharge +%d %%", "base": 0, "step": 6},
	"paper": {"name": "Peau de papier", "kanji": "士", "costs": [80, 170, 300],
		"fmt": "PV max +%d", "base": 0, "step": 1},
	"breath": {"name": "Second souffle", "kanji": "風", "costs": [200, 420],
		"fmt": "%d filets par combat", "base": 1, "step": 1},
	"purse": {"name": "Bourse", "kanji": "円", "costs": [25, 50, 85, 130, 180],
		"fmt": "Encre gagnée +%d %%", "base": 0, "step": 5},
	"choice": {"name": "Choix", "kanji": "道", "costs": [100, 200, 340],
		"fmt": "Relances +%d par partie", "base": 0, "step": 1},
}

## Dons des sceaux : achetés une fois, pour toujours. « power » : légendaire retiré des rouleaux tant qu'il n'est pas scellé.
const SEAL_ORDER := ["reroll", "scroll", "purse", "blessing", "hp", "leg_hoo", "leg_kitsune", "leg_ippitsu"]
const SEAL_ITEMS := {
	"reroll": {"name": "Seconde chance", "kanji": "返", "cost": 2,
		"text": "+1 relance des rouleaux à chaque partie."},
	"scroll": {"name": "Rouleau de départ", "kanji": "巻", "cost": 3,
		"text": "Commence chaque partie avec un rouleau commun de ton choix."},
	"purse": {"name": "Sceau du marchand", "kanji": "金", "cost": 3,
		"text": "+20 % d'encre gagnée à chaque fin de partie."},
	"blessing": {"name": "Bénédiction", "kanji": "福", "cost": 4,
		"text": "Ton premier choix de rouleaux de la partie en offre un second."},
	"hp": {"name": "Kintsugi", "kanji": "命", "cost": 5,
		"text": "+1 cœur max à chaque partie."},
	"leg_hoo": {"name": "Hōō, le phénix", "kanji": "鳳", "cost": 4, "power": "fire_hoo",
		"text": "Libère ce légendaire du feu : il pourra sortir dans les rouleaux."},
	"leg_kitsune": {"name": "Kitsunebi", "kanji": "狐", "cost": 4, "power": "shadow_kitsunebi",
		"text": "Libère ce légendaire de l'ombre : il pourra sortir dans les rouleaux."},
	"leg_ippitsu": {"name": "Ippitsu, un seul trait", "kanji": "筆", "cost": 6, "power": "ink_ippitsu",
		"text": "Libère le légendaire du maître : il pourra sortir dans les rouleaux."},
}

## Les Vues (estampes). Condition : « c » = room (salle 4 atteinte), mini (gardien vaincu), win (victoire),
## curse (victoire avec 2 malédictions ou plus) dans le monde « w » ; runs (« n » parties jouées) ; all (5 mondes gagnés).
## Apparence : « kind » = cape (écharpe), trail (sillage de lame), ink (encre du trait) ; « col » sa couleur.
## Dessin : ciel, Fuji, sol ; « fx » = position du Fuji (0..1) ; « motif » = détail du premier plan.
const PRINT_ORDER := [
	"w1_room", "w1_mini", "w1_win", "w1_curse",
	"w2_room", "w2_mini", "w2_win", "w2_curse",
	"w3_room", "w3_mini", "w3_win", "w3_curse",
	"w4_room", "w4_mini", "w4_win", "w4_curse",
	"w5_room", "w5_mini", "w5_win", "w5_curse",
	"runs3", "runs10", "runs25", "all",
]
const PRINTS := {
	"w1_room": {"name": "Plage de Shichiri", "w": 1, "c": "room", "kind": "trail", "col": Color("#E9EEF0"), "look": "Sillage d'écume",
		"sky": Color("#EFE6D2"), "fuji": Color("#4A6A8A"), "ground": Color("#C9B48A"), "fx": 0.62, "motif": "pine"},
	"w1_mini": {"name": "Barques d'Oshiokuri", "w": 1, "c": "mini", "kind": "cape", "col": Color("#2B4C7E"), "look": "Écharpe indigo",
		"sky": Color("#E8D9B8"), "fuji": Color("#3E5878"), "ground": Color("#2E5A80"), "fx": 0.3, "motif": "boat"},
	"w1_win": {"name": "Sous la vague", "w": 1, "c": "win", "kind": "ink", "col": Color("#1F3A5F"), "look": "Encre de Prusse",
		"sky": Color("#E4D7BC"), "fuji": Color("#2A3F5C"), "ground": Color("#1F3A5F"), "fx": 0.6, "motif": "wave"},
	"w1_curse": {"name": "Tempête au large", "w": 1, "c": "curse", "kind": "trail", "col": Color("#5AA0E6"), "look": "Sillage de vague",
		"sky": Color("#8A93A0"), "fuji": Color("#2A3346"), "ground": Color("#24405E"), "fx": 0.45, "motif": "rain"},
	"w2_room": {"name": "Bambous de Meguro", "w": 2, "c": "room", "kind": "cape", "col": Color("#5E7F4A"), "look": "Écharpe bambou",
		"sky": Color("#E6E0C4"), "fuji": Color("#6C7F8E"), "ground": Color("#7E9A5E"), "fx": 0.55, "motif": "bamboo"},
	"w2_mini": {"name": "Feux de renards", "w": 2, "c": "mini", "kind": "trail", "col": Color("#B58BFF"), "look": "Sillage de renard",
		"sky": Color("#1F2A3A"), "fuji": Color("#3A4A60"), "ground": Color("#2C3848"), "fx": 0.7, "motif": "fox"},
	"w2_win": {"name": "Fête des étoiles", "w": 2, "c": "win", "kind": "ink", "col": Color("#2F5A48"), "look": "Encre de jade",
		"sky": Color("#24304A"), "fuji": Color("#46587A"), "ground": Color("#3E4A3A"), "fx": 0.4, "motif": "moon"},
	"w2_curse": {"name": "Nuit d'Oji", "w": 2, "c": "curse", "kind": "cape", "col": Color("#2A2830"), "look": "Écharpe de nuit",
		"sky": Color("#141A26"), "fuji": Color("#2A3346"), "ground": Color("#1E3330"), "fx": 0.55, "motif": "fox"},
	"w3_room": {"name": "Neige sur la Sumida", "w": 3, "c": "room", "kind": "cape", "col": Color("#E8E6E0"), "look": "Écharpe de neige",
		"sky": Color("#D9DFE6"), "fuji": Color("#8C8FA8"), "ground": Color("#EEF2F6"), "fx": 0.35, "motif": "snow"},
	"w3_mini": {"name": "Pont de Koishikawa", "w": 3, "c": "mini", "kind": "trail", "col": Color("#BFD6E3"), "look": "Sillage de givre",
		"sky": Color("#CBD3DE"), "fuji": Color("#7A809A"), "ground": Color("#E2E7EC"), "fx": 0.65, "motif": "bridge"},
	"w3_win": {"name": "Matin de neige", "w": 3, "c": "win", "kind": "ink", "col": Color("#2E2A5A"), "look": "Encre indigo",
		"sky": Color("#E8D6CC"), "fuji": Color("#6E7090"), "ground": Color("#F2F4F6"), "fx": 0.5, "motif": "sun"},
	"w3_curse": {"name": "Cent contes", "w": 3, "c": "curse", "kind": "cape", "col": Color("#8E6FB5"), "look": "Écharpe glycine",
		"sky": Color("#4A4E66"), "fuji": Color("#2E3046"), "ground": Color("#C6D0DC"), "fx": 0.4, "motif": "lantern"},
	"w4_room": {"name": "Vent du sud", "w": 4, "c": "room", "kind": "trail", "col": Color("#FF5A1F"), "look": "Sillage de braise",
		"sky": Color("#7E9CC0"), "fuji": Color("#A0402A"), "ground": Color("#3E5A3A"), "fx": 0.5, "motif": "cloud"},
	"w4_mini": {"name": "Ciel clair", "w": 4, "c": "mini", "kind": "cape", "col": Color("#9C4A1E"), "look": "Écharpe rouille",
		"sky": Color("#3F5677"), "fuji": Color("#8E2A1E"), "ground": Color("#2E3A2A"), "fx": 0.45, "motif": "cloud"},
	"w4_win": {"name": "Fuji rouge", "w": 4, "c": "win", "kind": "ink", "col": Color("#9E2A22"), "look": "Encre vermillon",
		"sky": Color("#E8C9A0"), "fuji": Color("#B2341E"), "ground": Color("#3A2A22"), "fx": 0.55, "motif": "sun"},
	"w4_curse": {"name": "Orage sous le sommet", "w": 4, "c": "curse", "kind": "trail", "col": Color("#D7372B"), "look": "Sillage écarlate",
		"sky": Color("#6E7C96"), "fuji": Color("#5A2A22"), "ground": Color("#241A1A"), "fx": 0.5, "motif": "storm"},
	"w5_room": {"name": "Lac de Misaka", "w": 5, "c": "room", "kind": "cape", "col": Color("#E59AAE"), "look": "Écharpe sakura",
		"sky": Color("#EAD2C8"), "fuji": Color("#5A6E8E"), "ground": Color("#8FB0C4"), "fx": 0.5, "motif": "lake"},
	"w5_mini": {"name": "Rizières de Fujimigahara", "w": 5, "c": "mini", "kind": "trail", "col": Color("#5FD6A8"), "look": "Sillage de jade",
		"sky": Color("#E4C3B8"), "fuji": Color("#4E6280"), "ground": Color("#A8B26E"), "fx": 0.62, "motif": "barrel"},
	"w5_win": {"name": "Trente-six vues", "w": 5, "c": "win", "kind": "ink", "col": Color("#5A3A22"), "look": "Encre sépia",
		"sky": Color("#EAD2C8"), "fuji": Color("#0E1A2E"), "ground": Color("#E9DFC9"), "fx": 0.5, "motif": "enso"},
	"w5_curse": {"name": "Le Fuji dans l'orage", "w": 5, "c": "curse", "kind": "cape", "col": Color("#C49A45"), "look": "Écharpe d'or",
		"sky": Color("#3A3046"), "fuji": Color("#0E1A2E"), "ground": Color("#2A2430"), "fx": 0.45, "motif": "storm"},
	"runs3": {"name": "Le pèlerin", "w": 0, "c": "runs", "n": 3, "kind": "trail", "col": Color("#2A2830"), "look": "Sillage d'encre",
		"sky": Color("#EFE6D2"), "fuji": Color("#6C7F8E"), "ground": Color("#C9B48A"), "fx": 0.7, "motif": "pilgrim"},
	"runs10": {"name": "Thé à Hodogaya", "w": 0, "c": "runs", "n": 10, "kind": "cape", "col": Color("#2E7C80"), "look": "Écharpe sarcelle",
		"sky": Color("#E6DDC0"), "fuji": Color("#5A6E8E"), "ground": Color("#8E9A5E"), "fx": 0.4, "motif": "pine"},
	"runs25": {"name": "Le vieux fou de dessin", "w": 0, "c": "runs", "n": 25, "kind": "ink", "col": Color("#4E3A63"), "look": "Encre glycine",
		"sky": Color("#EFE6D2"), "fuji": Color("#1B1A1E"), "ground": Color("#E2D6BD"), "fx": 0.6, "motif": "brush"},
	"all": {"name": "Le Fuji parfait", "w": 0, "c": "all", "kind": "trail", "col": Color("#E2A93B"), "look": "Sillage d'or",
		"sky": Color("#F2DCC0"), "fuji": Color("#C49A45"), "ground": Color("#1F3A5F"), "fx": 0.5, "motif": "sun"},
}
const LOOK_KINDS := ["cape", "trail", "ink"]
const LOOK_NAMES := {"cape": "Écharpe", "trail": "Sillage", "ink": "Encre"}

## Garde-robe : tenues (atlas du ronin recoloré, capuche comprise) et thèmes de l'interface.
## Obtention : « free » ; « print » = Vue possédée ; « prints » = nombre de Vues ; « cost » = encre (achat unique).
const OUTFIT_ORDER := ["sumi", "indigo", "matcha", "kaki", "sakura", "neige", "glycine", "or"]
const OUTFITS := {
	"sumi": {"name": "Encre", "col": Color("#4A4858"), "tex": "res://assets/kaykit/tex/rogue_ink.png", "free": true},
	"indigo": {"name": "Indigo d'Edo", "col": Color("#2B4C7E"), "tex": "res://assets/kaykit/tex/rogue_indigo.png", "cost": 120},
	"matcha": {"name": "Matcha", "col": Color("#5E7F4A"), "tex": "res://assets/kaykit/tex/rogue_matcha.png", "print": "w2_room"},
	"kaki": {"name": "Kaki", "col": Color("#E8692A"), "tex": "res://assets/kaykit/tex/rogue_kaki.png", "cost": 250},
	"sakura": {"name": "Sakura", "col": Color("#D98AA0"), "tex": "res://assets/kaykit/tex/rogue_sakura.png", "print": "w5_room"},
	"neige": {"name": "Neige", "col": Color("#ECE8E0"), "tex": "res://assets/kaykit/tex/rogue_neige.png", "print": "w3_room"},
	"glycine": {"name": "Glycine", "col": Color("#7A5FA0"), "tex": "res://assets/kaykit/tex/rogue_glycine.png", "cost": 400},
	"or": {"name": "Or du maître", "col": Color("#E2B04A"), "tex": "res://assets/kaykit/tex/rogue_or.png", "cost": 900},
}
## Thèmes : papier des cartes, voile de l'écran, encre du texte (contrastes gardés), liseré.
const THEME_ORDER := ["washi", "nuit", "sakura", "indigo"]
const THEMES := {
	"washi": {"name": "Washi", "paper": Color("#E4D9C2"), "wash": Color("#D8CBB1"), "ink": Color("#1B1A1E"), "accent": Color("#D7372B"), "free": true},
	"nuit": {"name": "Nuit", "paper": Color("#232A3A"), "wash": Color("#151B28"), "ink": Color("#EFE6D2"), "accent": Color("#E2A93B"), "cost": 150},
	"sakura": {"name": "Sakura", "paper": Color("#FBEDEE"), "wash": Color("#F4DCE0"), "ink": Color("#3A1F2A"), "accent": Color("#C2456A"), "cost": 200},
	"indigo": {"name": "Indigo", "paper": Color("#E6ECF4"), "wash": Color("#D5DEEA"), "ink": Color("#13213A"), "accent": Color("#2F5D8A"), "prints": 6},
}

var sumi := 0  # encre, permanente
var seals := 0  # sceaux (hanko)
var prints := 0  # Vues collectionnées (= owned_prints.size(), max 24)
var runs := 0  # parties jouées
var best_room := 0  # meilleure salle atteinte
var wins := 0  # victoires (la première rapporte +2 sceaux)
var ranks := {}  # id de ligne -> rang acheté
const WORLD_COUNT := 8  # mondes du jeu (worlds.gd WORLDS) : bornes des déblocages
var unlocked := 1  # mondes débloqués (1..WORLD_COUNT) : le monde N+1 s'ouvre quand le monde N est vaincu
var power_tier := 0  # paliers de rouleaux débloqués (0..4) : monde N vaincu -> palier N (power_data « unlock »)
var test_unlock_all := false  # robot (CI) et tests : tous les mondes et paliers ouverts (jamais sauvegardé)
var tuto_done := false  # tutoriel fini : bulles du coach toutes vues ou passées (anciennes sauvegardes : ancien tutoriel fait)
const COACH_MARKS := ["stroke", "cut", "dodge", "ink", "figure", "ult", "run", "figures"]  # bulles du coach (coach.gd)
var coach_seen := {}  # id de bulle -> true : déjà montrée
var intro_done := false  # intro illustrée déjà vue (sinon elle s'ouvre au premier JOUER)
var scroll_tip_done := false  # explication des rouleaux (picker.gd) déjà vue
var world_best := {}  # monde -> meilleure salle atteinte
var world_score := {}  # monde -> meilleur score (score.gd)
var world_chain := {}  # monde -> plus longue chaîne atteinte
var seal_owned := {}  # id de don -> true
var owned_prints := {}  # id de Vue -> true
var look := {"cape": "", "trail": "", "ink": ""}  # apparence portée : id de Vue ("" = d'origine)
var start_power_id := ""  # rouleau de départ choisi (don « scroll »)
var outfit := "sumi"  # tenue portée (OUTFITS)
var theme := "washi"  # thème de l'interface (THEMES)
var bought := {}  # « outfit:kaki », « theme:nuit »… -> true : achats de la garde-robe
# bestiaire : id -> [victoires, premier monde, fiche ouverte (0/1)] ; boss rangés en « boss_<id> »
var seen := {}


func _init() -> void:
	for id in ORDER:
		ranks[id] = 0


# --- Sauvegarde -------------------------------------------------------------

func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	sumi = maxi(0, int(cf.get_value("meta", "sumi", 0)))
	seals = maxi(0, int(cf.get_value("meta", "seals", 0)))
	var legacy_prints := clampi(int(cf.get_value("meta", "prints", 0)), 0, MAX_PRINTS)
	runs = maxi(0, int(cf.get_value("meta", "runs", 0)))
	best_room = maxi(0, int(cf.get_value("meta", "best_room", 0)))
	wins = maxi(0, int(cf.get_value("meta", "wins", 0)))
	unlocked = clampi(int(cf.get_value("meta", "unlocked", 1)), 1, WORLD_COUNT)
	power_tier = clampi(int(cf.get_value("meta", "power_tier", 0)), 0, Data.UNLOCK_MAX)
	tuto_done = bool(cf.get_value("meta", "tuto_done", false))
	for id in COACH_MARKS:
		if bool(cf.get_value("coach", id, false)):
			coach_seen[id] = true
	# anciennes sauvegardes : qui a déjà fait le tutoriel n'a pas besoin de l'intro
	intro_done = bool(cf.get_value("meta", "intro_done", tuto_done))
	scroll_tip_done = bool(cf.get_value("meta", "scroll_tip", false))
	start_power_id = String(cf.get_value("meta", "start_power", ""))
	for wid in range(1, WORLD_COUNT + 1):
		world_best[wid] = int(cf.get_value("worlds", str(wid), 0))
		world_score[wid] = maxi(0, int(cf.get_value("scores", str(wid), 0)))
		world_chain[wid] = maxi(0, int(cf.get_value("chains", str(wid), 0)))
	for id in ORDER:
		ranks[id] = clampi(int(cf.get_value("stone", id, 0)), 0, max_rank(id))
	for id in SEAL_ORDER:
		if bool(cf.get_value("seals", id, false)):
			seal_owned[id] = true
	var had_vues := cf.has_section("vues")
	for id in PRINT_ORDER:
		if bool(cf.get_value("vues", id, false)):
			owned_prints[id] = true
	for kind in LOOK_KINDS:
		var pid := String(cf.get_value("look", kind, ""))
		look[kind] = pid if _look_ok(pid, kind) else ""
	var bl = cf.get_value("wardrobe", "bought", [])
	if bl is Array or bl is PackedStringArray:
		for b in bl:
			bought[String(b)] = true
	outfit = String(cf.get_value("wardrobe", "outfit", "sumi"))
	theme = String(cf.get_value("wardrobe", "theme", "washi"))
	# bestiaire (section absente des anciennes sauvegardes : rien de vu)
	if cf.has_section("bestiary"):
		for k in cf.get_section_keys("bestiary"):
			var v = cf.get_value("bestiary", k, [])
			if v is Array and (v as Array).size() >= 2:
				var arr: Array = v
				var fresh := 0
				if arr.size() >= 3:
					fresh = clampi(int(arr[2]), 0, 1)
				seen[String(k)] = [maxi(0, int(arr[0])), clampi(int(arr[1]), 1, WORLD_COUNT), fresh]
	# Vues déjà méritées d'après les records (salles atteintes, parties jouées)
	_retro_prints()
	# anciennes sauvegardes : les Vues n'étaient qu'un nombre ; on garde au moins autant d'estampes
	if not had_vues and legacy_prints > owned_prints.size():
		for id in PRINT_ORDER:
			if owned_prints.size() >= legacy_prints:
				break
			owned_prints[id] = true
	prints = owned_prints.size()
	if not cosmetic_owned("outfit", outfit):
		outfit = "sumi"
	if not cosmetic_owned("theme", theme):
		theme = "washi"
	_migrate_progress()
	# rouleau de départ : on garde le choix même s'il n'est pas encore débloqué (start_power() le vérifie)
	if owns_seal("scroll") and not Data.POWERS.has(start_power_id):
		start_power_id = _first_choice()


## Anciennes sauvegardes (mondes tous ouverts du prototype, paliers absents) : les victoires passées
## ouvrent le monde suivant et leur palier de rouleaux ; tout monde déjà joué reste ouvert.
func _migrate_progress() -> void:
	var top_won := 0
	var reached := 1
	for wid in range(1, WORLD_COUNT + 1):
		if world_won(wid):
			top_won = wid
		if int(world_best.get(wid, 0)) > 0:
			reached = wid
	# (les Vues « w<id>_win » n'existent que pour les mondes 1 à 5 : au-delà, unlocked fait foi)
	unlocked = clampi(maxi(unlocked, maxi(top_won + 1, reached)), 1, WORLD_COUNT)
	power_tier = clampi(maxi(power_tier, top_won), 0, Data.UNLOCK_MAX)


func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "sumi", sumi)
	cf.set_value("meta", "seals", seals)
	cf.set_value("meta", "prints", prints)
	cf.set_value("meta", "runs", runs)
	cf.set_value("meta", "best_room", best_room)
	cf.set_value("meta", "wins", wins)
	cf.set_value("meta", "unlocked", unlocked)
	cf.set_value("meta", "power_tier", power_tier)
	cf.set_value("meta", "tuto_done", tuto_done)
	for id in COACH_MARKS:
		cf.set_value("coach", id, coach_seen.has(id))
	cf.set_value("meta", "intro_done", intro_done)
	cf.set_value("meta", "scroll_tip", scroll_tip_done)
	cf.set_value("meta", "start_power", start_power_id)
	for wid in world_best.keys():
		cf.set_value("worlds", str(wid), int(world_best[wid]))
	for wid in world_score.keys():
		cf.set_value("scores", str(wid), int(world_score[wid]))
	for wid in world_chain.keys():
		cf.set_value("chains", str(wid), int(world_chain[wid]))
	for id in ORDER:
		cf.set_value("stone", id, rank(id))
	for id in SEAL_ORDER:
		cf.set_value("seals", id, owns_seal(id))
	for id in PRINT_ORDER:
		cf.set_value("vues", id, has_print(id))
	for kind in LOOK_KINDS:
		cf.set_value("look", kind, String(look.get(kind, "")))
	cf.set_value("wardrobe", "outfit", outfit)
	cf.set_value("wardrobe", "theme", theme)
	cf.set_value("wardrobe", "bought", bought.keys())
	for k in seen.keys():
		cf.set_value("bestiary", String(k), seen[k])
	cf.save(SAVE_PATH)


# --- Bestiaire ---------------------------------------------------------------
# k : type d'ennemi (main.KIND_XP), ou « boss_<id> » pour un gardien ou un boss.

func kind_seen(k: String) -> bool:
	return seen.has(k)


## Première rencontre : vrai si l'ennemi est nouveau (main l'annonce).
func see_kind(k: String, w: int) -> bool:
	if k == "" or seen.has(k):
		return false
	seen[k] = [0, clampi(w, 1, WORLD_COUNT), 0]
	return true


## Un ennemi déjà rencontré tombe.
func kill_kind(k: String) -> void:
	if not seen.has(k):
		return
	var v: Array = seen[k]
	v[0] = int(v[0]) + 1


func kind_kills(k: String) -> int:
	if not seen.has(k):
		return 0
	var v: Array = seen[k]
	return int(v[0])


## Monde de la première rencontre (0 : jamais vu).
func kind_world(k: String) -> int:
	if not seen.has(k):
		return 0
	var v: Array = seen[k]
	return int(v[1])


## Fiche jamais ouverte dans le bestiaire (point vermillon).
func kind_fresh(k: String) -> bool:
	if not seen.has(k):
		return false
	var v: Array = seen[k]
	return v.size() < 3 or int(v[2]) == 0


func kind_viewed(k: String) -> void:
	if not seen.has(k):
		return
	var v: Array = seen[k]
	while v.size() < 3:
		v.append(0)
	v[2] = 1


# --- Coach (tutoriel en jeu) ------------------------------------------------

## Bulle vue : le tutoriel est fini quand toutes l'ont été.
func coach_see(id: String) -> void:
	coach_seen[id] = true
	for m in COACH_MARKS:
		if not coach_seen.has(m):
			return
	tuto_done = true


## « Passer » : tout est vu.
func coach_skip() -> void:
	for m in COACH_MARKS:
		coach_seen[m] = true
	tuto_done = true


## « Revoir le tutoriel » : les bulles reviendront, et le prochain JOUER mène droit au monde 1.
func coach_reset() -> void:
	coach_seen = {}
	tuto_done = false
	scroll_tip_done = false


## Tout premier lancement (ou tutoriel à revoir) : JOUER mène droit au monde 1, avec le coach.
func coach_first_run() -> bool:
	return not tuto_done and not coach_seen.has("stroke")


# --- Pierre à encre ---------------------------------------------------------

func rank(id: String) -> int:
	return int(ranks.get(id, 0))


func max_rank(id: String) -> int:
	if not LINES.has(id):
		return 0
	var line: Dictionary = LINES[id]
	var costs: Array = line["costs"]
	return costs.size()


## Prix du prochain rang, -1 si la ligne est au maximum (ou inconnue).
func cost(id: String) -> int:
	var r := rank(id)
	if r >= max_rank(id):
		return -1
	var line: Dictionary = LINES[id]
	var costs: Array = line["costs"]
	return int(costs[r])


func can_buy(id: String) -> bool:
	var c := cost(id)
	return c >= 0 and sumi >= c


## Débite l'encre, monte le rang et sauvegarde.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	sumi -= cost(id)
	ranks[id] = rank(id) + 1
	save_data()
	return true


## Texte d'effet total au rang donné (par défaut : le prochain rang, ou le rang max atteint).
func effect_text(id: String, at_rank := -1) -> String:
	if not LINES.has(id):
		return ""
	var line: Dictionary = LINES[id]
	var r := at_rank
	if r < 0:
		r = mini(rank(id) + 1, max_rank(id))
	var v := int(line["base"]) + int(line["step"]) * r
	return String(line["fmt"]) % v


## Vrai si une ligne au moins est à la portée de l'encre actuelle (pastille sur l'onglet).
func any_affordable() -> bool:
	for id in ORDER:
		if can_buy(String(id)):
			return true
	return false


# --- Sceaux ----------------------------------------------------------------

func owns_seal(id: String) -> bool:
	return bool(seal_owned.get(id, false))


func seal_cost(id: String) -> int:
	if not SEAL_ITEMS.has(id):
		return -1
	var it: Dictionary = SEAL_ITEMS[id]
	return int(it["cost"])


func can_buy_seal(id: String) -> bool:
	return SEAL_ITEMS.has(id) and not owns_seal(id) and seals >= seal_cost(id)


func any_seal_affordable() -> bool:
	for id in SEAL_ORDER:
		if can_buy_seal(String(id)):
			return true
	return false


## Débite les sceaux, acquiert le don pour toujours et sauvegarde.
func buy_seal(id: String) -> bool:
	if not can_buy_seal(id):
		return false
	seals -= seal_cost(id)
	seal_owned[id] = true
	if id == "scroll" and not (start_power_id in start_choices()):
		start_power_id = _first_choice()
	save_data()
	return true


## Rouleaux communs proposés au départ (débloqués, et qui ne dépendent d'aucun autre pouvoir).
func start_choices() -> Array:
	var out: Array = []
	for key in Data.POWERS.keys():
		var d: Dictionary = Data.POWERS[key]
		if String(d.get("rarity", "")) == "common" and not d.has("needs") and power_unlocked(String(key)):
			out.append(String(key))
	return out


func _first_choice() -> String:
	var ch := start_choices()
	return "" if ch.is_empty() else String(ch[0])


## Rouleau de départ effectif ("" sans le don).
func start_power() -> String:
	if not owns_seal("scroll"):
		return ""
	return start_power_id if String(start_power_id) in start_choices() else _first_choice()


## Passe au rouleau de départ suivant (dir = 1) ou précédent (dir = -1).
func cycle_start_power(dir: int) -> void:
	var ch := start_choices()
	if ch.is_empty():
		return
	var i := ch.find(start_power())
	i = posmod(i + dir, ch.size())
	start_power_id = String(ch[i])
	save_data()


## Sceau de l'Atelier qui libère ce pouvoir ("" s'il n'en dépend pas).
func _seal_of(id: String) -> String:
	for sid in SEAL_ORDER:
		var it: Dictionary = SEAL_ITEMS[sid]
		if String(it.get("power", "")) == id:
			return String(sid)
	return ""


## Vrai pour un légendaire de l'Atelier dont le sceau n'est pas encore acheté.
func power_sealed(id: String) -> bool:
	var sid := _seal_of(id)
	return sid != "" and not owns_seal(sid)


## Palier de rouleaux effectif (tout ouvert pour le robot et les tests).
func effective_tier() -> int:
	return Data.UNLOCK_MAX if test_unlock_all else power_tier


## Vrai si ce pouvoir peut sortir dans les rouleaux : légendaire de l'Atelier -> son sceau (quel que soit
## le palier) ; sinon son palier « unlock » doit être atteint. powers.gd écarte les autres de ses offres.
func power_unlocked(id: String) -> bool:
	var sid := _seal_of(id)
	if sid != "":
		return owns_seal(sid)
	return Data.unlock_tier(id) <= effective_tier()


## Pouvoirs d'un palier (dans l'ordre de power_data), sans les légendaires des sceaux.
func powers_of_tier(t: int) -> Array:
	var out: Array = []
	for key in Data.POWERS.keys():
		var id := String(key)
		if Data.unlock_tier(id) == t and _seal_of(id) == "":
			out.append(id)
	return out


## Monde vaincu (Vue « w<id>_win »).
func world_won(wid: int) -> bool:
	return has_print("w%d_win" % wid)


## Pouvoirs encore verrouillés par un sceau (légendaires à sceller).
func locked_powers() -> Array:
	var out: Array = []
	for sid in SEAL_ORDER:
		var it: Dictionary = SEAL_ITEMS[sid]
		var p := String(it.get("power", ""))
		if p != "" and not owns_seal(String(sid)):
			out.append(p)
	return out


# --- Vues (estampes) et apparence --------------------------------------------

func has_print(id: String) -> bool:
	return bool(owned_prints.get(id, false))


## Condition d'une Vue, en clair (long : bandeau ; court : sous l'estampe verrouillée).
func print_how(id: String, short := false) -> String:
	if not PRINTS.has(id):
		return ""
	var p: Dictionary = PRINTS[id]
	var wi := int(p["w"])
	var wn: String = WORLD_NAMES[wi - 1] if wi >= 1 and wi <= 5 else ""
	match String(p["c"]):
		"room":
			return "3 combats" if short else "Remporte 3 combats dans le monde %s." % wn
		"mini":
			return "Gardien" if short else "Bats le gardien (étape 4) du monde %s." % wn
		"win":
			return "Victoire" if short else "Remporte le monde %s." % wn
		"curse":
			return "2 malédictions" if short else "Remporte le monde %s avec 2 malédictions ou plus." % wn
		"runs":
			var n := int(p.get("n", 1))
			return ("%d parties" % n) if short else "Joue %d parties (tu en as joué %d)." % [n, runs]
		"all":
			return "5 mondes" if short else "Remporte les cinq mondes."
	return ""


func _look_ok(pid: String, kind: String) -> bool:
	if pid == "" or not PRINTS.has(pid) or not has_print(pid):
		return false
	var p: Dictionary = PRINTS[pid]
	return String(p["kind"]) == kind


func is_worn(pid: String) -> bool:
	if not PRINTS.has(pid):
		return false
	var p: Dictionary = PRINTS[pid]
	return String(look.get(String(p["kind"]), "")) == pid


## Porte l'apparence d'une Vue possédée, ou l'ôte si elle est déjà portée. Renvoie vrai si elle est portée.
func toggle_look(pid: String) -> bool:
	if not has_print(pid):
		return false
	var p: Dictionary = PRINTS[pid]
	var kind := String(p["kind"])
	var on := not is_worn(pid)
	look[kind] = pid if on else ""
	save_data()
	return on


func look_on(kind: String) -> bool:
	return _look_ok(String(look.get(kind, "")), kind)


## Couleur portée pour un type d'apparence (couleur d'origine si rien n'est porté).
func look_color(kind: String) -> Color:
	if look_on(kind):
		var p: Dictionary = PRINTS[String(look[kind])]
		return p["col"]
	match kind:
		"cape":
			return Toon.VERMILION
		"trail":
			return Toon.FOAM
	return Toon.SUMI


func look_name(kind: String) -> String:
	if look_on(kind):
		var p: Dictionary = PRINTS[String(look[kind])]
		return String(p["look"])
	return "d'origine"


## Débloque une Vue ; renvoie vrai si elle est nouvelle.
func _grant(id: String) -> bool:
	if not PRINTS.has(id) or has_print(id):
		return false
	owned_prints[id] = true
	prints = owned_prints.size()
	return true


## Vues que les records prouvent déjà (salles atteintes, parties jouées).
func _retro_prints() -> void:
	for wid in range(1, 6):
		var best := int(world_best.get(wid, 0))
		if best >= 4:
			_grant("w%d_room" % wid)
		if best > MINI_ROOM:
			_grant("w%d_mini" % wid)
	_grant_runs()


func _grant_runs() -> Array:
	var out: Array = []
	for id in ["runs3", "runs10", "runs25"]:
		var p: Dictionary = PRINTS[id]
		if runs >= int(p["n"]) and _grant(String(id)):
			out.append(String(id))
	return out


# --- Garde-robe ---------------------------------------------------------------
## Catégories : outfit (tenue), cape, trail, ink (apparences des Vues), theme (interface).
## Pour cape / trail / ink, l'id est celui d'une Vue ("" = d'origine).

func _cosmetic(cat: String, id: String) -> Dictionary:
	if cat == "outfit":
		return OUTFITS.get(id, {})
	if cat == "theme":
		return THEMES.get(id, {})
	return {}


## Ids proposés dans une catégorie, dans l'ordre d'affichage.
func cosmetic_ids(cat: String) -> Array:
	if cat == "outfit":
		return OUTFIT_ORDER.duplicate()
	if cat == "theme":
		return THEME_ORDER.duplicate()
	var out: Array = [""]
	for pid in PRINT_ORDER:
		var p: Dictionary = PRINTS[pid]
		if String(p["kind"]) == cat:
			out.append(String(pid))
	return out


func cosmetic_name(cat: String, id: String) -> String:
	if cat in LOOK_KINDS:
		if id == "":
			return "D'origine"
		var p: Dictionary = PRINTS.get(id, {})
		return String(p.get("look", id))
	var d := _cosmetic(cat, id)
	return String(d.get("name", id))


## Couleur de la pastille.
func cosmetic_color(cat: String, id: String) -> Color:
	if cat in LOOK_KINDS:
		if id == "":
			match cat:
				"cape":
					return Toon.VERMILION
				"trail":
					return Toon.FOAM
			return Toon.SUMI
		var p: Dictionary = PRINTS.get(id, {})
		return p.get("col", Toon.SUMI)
	if cat == "theme":
		var t := _cosmetic(cat, id)
		return t.get("paper", Toon.PAPER)
	var d := _cosmetic(cat, id)
	return d.get("col", Toon.SUMI)


## Prix en encre (-1 : ne s'achète pas).
func cosmetic_cost(cat: String, id: String) -> int:
	var d := _cosmetic(cat, id)
	return int(d.get("cost", -1))


func cosmetic_owned(cat: String, id: String) -> bool:
	if cat in LOOK_KINDS:
		return id == "" or (has_print(id) and _look_ok(id, cat))
	var d := _cosmetic(cat, id)
	if d.is_empty():
		return false
	if bool(d.get("free", false)) or bool(bought.get("%s:%s" % [cat, id], false)):
		return true
	if d.has("print"):
		return has_print(String(d["print"]))
	if d.has("prints"):
		return prints >= int(d["prints"])
	return false


func cosmetic_worn(cat: String, id: String) -> bool:
	match cat:
		"outfit":
			return outfit == id
		"theme":
			return theme == id
	if cat in LOOK_KINDS:
		var cur := String(look.get(cat, "")) if look_on(cat) else ""
		return cur == id
	return false


## Comment l'obtenir, en clair (vide si possédé).
func cosmetic_how(cat: String, id: String) -> String:
	if cosmetic_owned(cat, id):
		return ""
	if cat in LOOK_KINDS:
		return print_how(id)
	var d := _cosmetic(cat, id)
	if d.has("cost"):
		return "S'achète %d encre." % int(d["cost"])
	if d.has("print"):
		var pid := String(d["print"])
		var p: Dictionary = PRINTS.get(pid, {})
		return "Vue « %s » : %s" % [String(p.get("name", pid)), print_how(pid)]
	if d.has("prints"):
		return "Collectionne %d Vues (tu en as %d)." % [int(d["prints"]), prints]
	return ""


func can_buy_cosmetic(cat: String, id: String) -> bool:
	var c := cosmetic_cost(cat, id)
	return c >= 0 and not cosmetic_owned(cat, id) and sumi >= c


## Achète (encre) puis porte ; sauvegarde. Renvoie vrai si l'achat a eu lieu.
func buy_cosmetic(cat: String, id: String) -> bool:
	if not can_buy_cosmetic(cat, id):
		return false
	sumi -= cosmetic_cost(cat, id)
	bought["%s:%s" % [cat, id]] = true
	wear_cosmetic(cat, id)
	save_data()
	return true


## Porte un élément possédé (sauvegarde). Renvoie vrai s'il est porté.
func wear_cosmetic(cat: String, id: String) -> bool:
	if not cosmetic_owned(cat, id):
		return false
	match cat:
		"outfit":
			outfit = id
		"theme":
			theme = id
		_:
			if not (cat in LOOK_KINDS):
				return false
			look[cat] = id
	save_data()
	return true


## Couleurs du thème porté : {paper, wash, ink, accent}.
func theme_colors() -> Dictionary:
	var t: Dictionary = THEMES.get(theme, THEMES["washi"])
	return {"paper": t["paper"], "wash": t["wash"], "ink": t["ink"], "accent": t["accent"]}


## Texture de la tenue portée (atlas du ronin).
func outfit_texture() -> Texture2D:
	var d: Dictionary = OUTFITS.get(outfit, OUTFITS["sumi"])
	var tex := load(String(d["tex"])) as Texture2D
	return tex


## Apparence complète sur le héros (tenue, écharpe, sillage) et encre du trait : début de partie,
## accueil et garde-robe (aperçu immédiat).
func apply_look(hero) -> void:
	if hero != null and hero.has_method("set_look"):
		hero.set_look(look_color("cape"), look_on("cape"), look_color("trail"), look_on("trail"))
	if hero != null and hero.has_method("set_outfit"):
		hero.set_outfit(outfit_texture())
	# encre du trait : variable statique « ink » de ink_stroke.gd (sans effet tant qu'elle n'existe pas).
	# Le trait multiplie la teinte par elle-même : on passe la racine pour retrouver la couleur voulue.
	var ink := Toon.SUMI
	if look_on("ink"):
		var c := look_color("ink")
		ink = Color(sqrt(c.r), sqrt(c.g), sqrt(c.b))
	var stroke_script: Script = load("res://scripts/ink_stroke.gd")
	if stroke_script != null:
		stroke_script.set("ink", ink)


# --- Effets appliqués à une partie -------------------------------------------

## Mètres d'élan max en plus.
func elan_bonus() -> float:
	return float(rank("brush"))


## Multiplicateur de recharge de l'élan.
func regen_mult() -> float:
	return 1.0 + 0.06 * rank("ink")


## PV max en plus (Peau de papier + don Kintsugi).
func hp_bonus() -> int:
	return rank("paper") + (1 if owns_seal("hp") else 0)


## Filets de sécurité par salle (1 de base).
func safety_per_room() -> int:
	return 1 + rank("breath")


## Relances de rouleaux par partie (Choix + don Seconde chance).
func rerolls() -> int:
	return rank("choice") + (1 if owns_seal("reroll") else 0)


## Multiplicateur de l'encre gagnée en fin de partie (Bourse + Sceau du marchand).
func sumi_mult() -> float:
	return 1.0 + 0.05 * rank("purse") + (0.2 if owns_seal("purse") else 0.0)


## Début de partie (appelé par main._start une fois le héros créé et ses PV posés) :
## apparence du héros et de l'encre, rouleau de départ, bénédiction.
func apply_run_start(m) -> void:
	if m == null:
		return
	apply_look(m.hero)
	var sp := start_power()
	if sp != "" and m.powers != null:
		m.powers.add(sp)
		m.elan = m.elan_max()
	if owns_seal("blessing"):
		m._extra_picks = int(m._extra_picks) + 1


# --- Fin de partie ----------------------------------------------------------

## Calcule et crédite les gains d'une partie (§5.1), sauvegarde, renvoie {"sumi", "seals", "print", "prints"}.
## Sceaux : +1 par gardien, +2 par boss, et en cas de victoire +1 par malédiction portée (3 au plus),
## +2 à la toute première victoire. Vues : selon le monde joué (world_id) et le nombre de parties.
func award_run(rooms_cleared: int, kills: int, boss_kills: int, curses: int, victory: bool, mini_boss_kills := 0, world_id := 0) -> Dictionary:
	var base := float(floori(maxi(0, kills) / 5.0) + 10 * mini_boss_kills + 30 * boss_kills + SUMI_PER_ROOM * rooms_cleared)
	base *= 1.0 + 0.15 * maxi(0, curses)
	var gained := maxi(0, int(round(base * sumi_mult())))
	var new_seals := maxi(0, mini_boss_kills) + 2 * maxi(0, boss_kills)
	if victory:
		new_seals += mini(maxi(0, curses), 3)
		if wins == 0:
			new_seals += 2
		wins += 1
	sumi += gained
	seals += new_seals
	runs += 1
	best_room = maxi(best_room, rooms_cleared)
	# Vues gagnées
	var new_prints: Array = []
	if world_id >= 1 and world_id <= 5:
		var conds := []
		if rooms_cleared >= 3:
			conds.append("room")
		if mini_boss_kills > 0 or rooms_cleared >= MINI_ROOM:
			conds.append("mini")
		if victory:
			conds.append("win")
			if curses >= 2:
				conds.append("curse")
		for c in conds:
			var pid := "w%d_%s" % [world_id, String(c)]
			if _grant(pid):
				new_prints.append(pid)
	new_prints.append_array(_grant_runs())
	var all_won := true
	for wid in range(1, 6):
		if not has_print("w%d_win" % wid):
			all_won = false
	if all_won and _grant("all"):
		new_prints.append("all")
	save_data()
	return {"sumi": gained, "seals": new_seals, "print": not new_prints.is_empty(), "prints": new_prints}


## Fin d'une partie dans un monde : record du monde ; en cas de victoire, le monde suivant s'ouvre et le
## palier de rouleaux du monde aussi. Renvoie ce que la victoire a débloqué :
## {"world": monde ouvert (0 : aucun), "tier": nouveau palier (-1 : aucun), "powers": ids, "family": nom}.
func record_world(world_id: int, room_reached: int, victory: bool) -> Dictionary:
	var res := {"world": 0, "tier": -1, "powers": [], "family": ""}
	world_best[world_id] = maxi(int(world_best.get(world_id, 0)), room_reached)
	if victory:
		var before := unlocked
		unlocked = clampi(maxi(unlocked, world_id + 1), 1, WORLD_COUNT)
		if world_id + 1 <= WORLD_COUNT and before < world_id + 1:
			res["world"] = world_id + 1
		var tb := power_tier
		power_tier = clampi(maxi(power_tier, world_id), 0, Data.UNLOCK_MAX)
		if power_tier > tb:
			var ids: Array = []
			for t in range(tb + 1, power_tier + 1):
				ids.append_array(powers_of_tier(t))
			res["tier"] = power_tier
			res["powers"] = ids
			res["family"] = String(Data.UNLOCK_NAMES[power_tier])
	save_data()
	return res


## Meilleur score d'un monde (0 : jamais marqué).
func world_score_of(world_id: int) -> int:
	return int(world_score.get(world_id, 0))


func world_chain_of(world_id: int) -> int:
	return int(world_chain.get(world_id, 0))


## Score d'une partie dans un monde : garde le meilleur score et la plus longue chaîne, sauvegarde.
## Renvoie vrai si le score bat l'ancien record.
func record_score(world_id: int, pts: int, chain: int) -> bool:
	var rec := pts > world_score_of(world_id)
	if rec:
		world_score[world_id] = pts
	world_chain[world_id] = maxi(world_chain_of(world_id), chain)
	save_data()
	return rec
