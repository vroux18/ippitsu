extends RefCounted
## Progression permanente, sauvegardée entre les parties :
## - sumi (encre) : l'Arbre du pinceau (quatre branches de nœuds appris une fois, sommets légendaires) ;
## - pétales (sakura) : seconde monnaie, rare, réservée à la garde-robe (tenues, thèmes) ;
## - Vues : collection d'estampes ; chacune débloque une apparence (écharpe, sillage de lame, encre du trait).

const Toon = preload("res://scripts/toon.gd")
const Data = preload("res://scripts/power_data.gd")
const Gear = preload("res://scripts/gear_data.gd")
const Score = preload("res://scripts/score.gd")

const SAVE_PATH := "user://ippitsu_meta.cfg"
const MAX_PRINTS := 24
const SUMI_PER_ROOM := 8  # réglage d'équilibrage : bonus d'encre par salle franchie (0 = §5.1 strict)
const MINI_ROOM := 8  # = main.MINI_ROOM (salle du gardien)
# pétales (garde-robe) gagnés en fin de partie (award_run) : une partie correcte (gardien, un défi, parfois une Vue)
# en rapporte 3 à 5, une victoire 7 à 9 ; un élément de la garde-robe en coûte 12 à 30
const PETALS_MINI := 1  # par gardien vaincu
const PETALS_BOSS := 3  # par boss du monde vaincu
const PETALS_WIN := 2  # victoire
const WORLD_NAMES := ["Grande Vague", "Tanabata", "Cent Contes", "Fuji Rouge", "Trente-six Vues"]

## --- Arbre du pinceau (méta-progression de l'Atelier) ---
## Un tronc (déjà acquis), quatre branches de six nœuds et un sommet légendaire. Un nœud s'apprend en encre
## (sumi) quand celui du dessous est appris. Remplace la Pierre à encre (lignes à rangs) et les sceaux.
const TREE_ROOT := "root"
const TREE_VERSION := 1  # sauvegarde : 0 = ancienne Pierre à encre et sceaux (remboursés en encre une fois)
const SEAL_SUMI := 40  # les sceaux n'existent plus : chaque sceau (dépensé, gardé, ou gagné en partie) vaut 40 encre
const BRANCH_ORDER := ["lame", "encre", "papier", "voie"]
const BRANCHES := {
	"lame": {"name": "LAME", "col": Color("#C8322A"), "text": "Attaque : dégâts, critiques, chaîne."},
	"encre": {"name": "ENCRE", "col": Color("#1F3A5F"), "text": "Le trait : longueur, recharge, réserve, second souffle."},
	"papier": {"name": "PAPIER", "col": Color("#B8862F"), "text": "Survie : cœurs, garde au départ, kintsugi, dernier souffle."},
	"voie": {"name": "VOIE", "col": Color("#A8436B"), "text": "Rouleaux et figures : relances, rouleau de départ, figures."},
}
## Nœuds : branche « b », étage « t » (1..6, 7 = sommet), nom, effet, coût en encre, glyphe ; « power » : légendaire
## retiré des rouleaux tant que le sommet n'est pas appris ; « fig » : figure apprise (fig_learned).
const TREE_ORDER := ["l1", "l2", "l3", "l4", "l5", "l6", "lc", "e1", "e2", "e3", "e4", "e5", "e6", "ec",
	"p1", "p2", "p3", "p4", "p5", "p6", "pc", "v1", "v2", "v3", "v4", "v5", "v6", "vc"]
const TREE := {
	"l1": {"b": "lame", "t": 1, "name": "Tranchant I", "text": "Dégâts +8 %.", "cost": 40, "glyph": "lame"},
	"l2": {"b": "lame", "t": 2, "name": "Tranchant II", "text": "Dégâts +8 % de plus.", "cost": 90, "glyph": "lame"},
	"l3": {"b": "lame", "t": 3, "name": "Fil du sabre", "text": "La chaîne passe à ×1,5 dès 2 traits réussis au lieu de 3.", "cost": 150, "glyph": "lame"},
	"l4": {"b": "lame", "t": 4, "name": "Coup net", "text": "La première touche de chaque combat est critique.", "cost": 220, "glyph": "lame"},
	"l5": {"b": "lame", "t": 5, "name": "Lame d'encre", "text": "Un ennemi tranché pendant une figure saigne 2 s.", "cost": 320, "glyph": "lame"},
	"l6": {"b": "lame", "t": 6, "name": "Élan du rōnin", "text": "Dégâts +15 % tant que la chaîne atteint 10.", "cost": 450, "glyph": "lame"},
	"lc": {"b": "lame", "t": 7, "name": "Ippitsu, un seul trait", "text": "Libère le légendaire du maître dans les rouleaux.", "cost": 600, "glyph": "lame", "power": "ink_ippitsu"},
	"e1": {"b": "encre", "t": 1, "name": "Pinceau long I", "text": "Élan max +1 m.", "cost": 30, "glyph": "encre"},
	"e2": {"b": "encre", "t": 2, "name": "Encre vive I", "text": "Recharge de l'encre +6 %.", "cost": 60, "glyph": "encre"},
	"e3": {"b": "encre", "t": 3, "name": "Pinceau long II", "text": "Élan max +1 m de plus.", "cost": 110, "glyph": "encre"},
	"e4": {"b": "encre", "t": 4, "name": "Encre vive II", "text": "Recharge +6 % de plus.", "cost": 170, "glyph": "encre"},
	"e5": {"b": "encre", "t": 5, "name": "Réserve", "text": "Encre d'avance : la jauge peut déborder d'un quart.", "cost": 250, "glyph": "encre"},
	"e6": {"b": "encre", "t": 6, "name": "Second souffle", "text": "Un filet d'encre de secours par combat.", "cost": 420, "glyph": "encre"},
	"ec": {"b": "encre", "t": 7, "name": "Kitsunebi", "text": "Libère ce légendaire de l'ombre dans les rouleaux.", "cost": 600, "glyph": "encre", "power": "shadow_kitsunebi"},
	"p1": {"b": "papier", "t": 1, "name": "Peau de papier I", "text": "+1 cœur max.", "cost": 80, "glyph": "papier"},
	"p2": {"b": "papier", "t": 2, "name": "Garde au départ", "text": "Intouchable les 2 premières secondes de chaque combat.", "cost": 120, "glyph": "papier"},
	"p3": {"b": "papier", "t": 3, "name": "Peau de papier II", "text": "+1 cœur max de plus.", "cost": 170, "glyph": "papier"},
	"p4": {"b": "papier", "t": 4, "name": "Kintsugi", "text": "Chaque gardien vaincu rend un cœur.", "cost": 240, "glyph": "papier"},
	"p5": {"b": "papier", "t": 5, "name": "Peau de papier III", "text": "+1 cœur max de plus.", "cost": 300, "glyph": "papier"},
	"p6": {"b": "papier", "t": 6, "name": "Dernier souffle", "text": "Une fois par partie, un coup mortel laisse 1 cœur.", "cost": 450, "glyph": "papier"},
	"pc": {"b": "papier", "t": 7, "name": "Hōō, le phénix", "text": "Libère ce légendaire du feu dans les rouleaux.", "cost": 600, "glyph": "papier", "power": "fire_hoo"},
	"v1": {"b": "voie", "t": 1, "name": "Seconde chance", "text": "+1 relance des rouleaux par partie.", "cost": 100, "glyph": "voie"},
	"v2": {"b": "voie", "t": 2, "name": "Figure : Vague", "text": "Apprend la Vague (un S). Sa technique Ressac entre dans les rouleaux.", "cost": 150, "glyph": "vague", "fig": "wave"},
	"v3": {"b": "voie", "t": 3, "name": "Rouleau de départ", "text": "Commence chaque partie avec un rouleau commun de ton choix.", "cost": 200, "glyph": "voie"},
	"v4": {"b": "voie", "t": 4, "name": "Figure : Pointe", "text": "Apprend la Pointe (un V aigu). Sa technique Kunai entre dans les rouleaux.", "cost": 260, "glyph": "pointe", "fig": "point"},
	"v5": {"b": "voie", "t": 5, "name": "Bénédiction", "text": "Le premier choix de rouleaux de la partie en offre un second.", "cost": 320, "glyph": "voie"},
	"v6": {"b": "voie", "t": 6, "name": "Figure : Triangle", "text": "Apprend le Triangle. Sa technique Kekkai entre dans les rouleaux.", "cost": 420, "glyph": "triangle", "fig": "triangle"},
	"vc": {"b": "voie", "t": 7, "name": "Maître des figures", "text": "L'ultime se charge en 4 figures au lieu de 5, et chaque figure rapporte +25 % de points.", "cost": 600, "glyph": "voie"},
}
## Figures de base, toujours connues ; les trois autres s'apprennent dans la branche VOIE (nœuds « fig »).
const BASE_FIGURES := ["loop", "zigzag", "return", "hook", "straight", "enso"]
## Réglages des effets de l'arbre (lus par main et score).
const TREE_DMG_STEP := 0.08  # Tranchant I et II
const RONIN_DMG := 0.15  # Élan du rōnin, chaîne >= RONIN_CHAIN
const RONIN_CHAIN := 10
const NET_CRIT := 2.0  # Coup net
const BLEED_TIME := 2.0  # Lame d'encre (s)
const BLEED_DPS := 0.6  # dégâts/s du saignement (une brûlure de base : 0,6)
const RESERVE_FRAC := 0.25  # Réserve : la jauge déborde d'un quart (25 % de l'élan max, ~4 m)
const START_GUARD := 2.0  # Garde au départ (s)
const MASTER_ULT := 0.25  # Maître des figures : part de la jauge d'ultime par figure (4 figures)
const MASTER_FIG_PTS := 1.25  # Maître des figures : points de figure

## Bourse : hors de l'arbre (décision de Victor), seule ligne à rangs gardée de l'ancienne Pierre à encre.
## Cinq rangs en encre, +5 % d'encre gagnée en fin de partie par rang ; les rangs déjà achetés sont conservés.
const PURSE_COSTS := [25, 50, 85, 130, 180]
const PURSE_STEP := 5  # % d'encre gagnée par rang

## Anciennes progressions (Pierre à encre sans la Bourse, sceaux), lues une seule fois pour rembourser en encre.
const LEGACY_LINE_COSTS := {"brush": [30, 60, 110, 170, 250], "ink": [30, 60, 110, 170, 250], "paper": [80, 170, 300],
	"breath": [200, 420], "choice": [100, 200, 340]}
const LEGACY_SEAL_COSTS := {"reroll": 2, "scroll": 3, "purse": 3, "blessing": 4, "hp": 5, "leg_hoo": 4, "leg_kitsune": 4, "leg_ippitsu": 6}

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

## Garde-robe : tenues et thèmes de l'interface. Une tenue teinte le hakama (et ses vagues) et l'obi du Ronin
## de papier (ninja_rig.hero_config) ; le kimono washi, le chapeau et l'écharpe (pièce « cape ») ne changent
## pas. « tex » : atlas de l'ancien modèle KayKit, l'id de la tenue en est tiré (hero.set_outfit).
## Obtention : « free » ; « print » = Vue possédée ; « prints » = nombre de Vues ; « petals » = pétales (achat unique).
## Les pétales (sakura) sont la monnaie de la garde-robe, à part de l'encre (qui ne sert qu'à l'Arbre) : rares,
## gagnés en fin de partie (award_run) ; un élément coûte environ 3 à 5 parties correctes. Les anciens prix en encre
## (120 à 900) ont été convertis ; ce qui a déjà été acheté reste acquis (section « wardrobe », clé « bought »).
const OUTFIT_ORDER := ["sumi", "indigo", "matcha", "kaki", "sakura", "neige", "glycine", "or"]
const OUTFITS := {
	"sumi": {"name": "Bleu de Prusse", "col": Color("#1F3A5C"), "tex": "res://assets/kaykit/tex/rogue_ink.png", "free": true},
	"indigo": {"name": "Indigo d'Edo", "col": Color("#2B4C7E"), "tex": "res://assets/kaykit/tex/rogue_indigo.png", "petals": 12},
	"matcha": {"name": "Matcha", "col": Color("#5E7F4A"), "tex": "res://assets/kaykit/tex/rogue_matcha.png", "print": "w2_room"},
	"kaki": {"name": "Kaki", "col": Color("#E8692A"), "tex": "res://assets/kaykit/tex/rogue_kaki.png", "petals": 18},
	"sakura": {"name": "Sakura", "col": Color("#D98AA0"), "tex": "res://assets/kaykit/tex/rogue_sakura.png", "print": "w5_room"},
	"neige": {"name": "Neige", "col": Color("#ECE8E0"), "tex": "res://assets/kaykit/tex/rogue_neige.png", "print": "w3_room"},
	"glycine": {"name": "Glycine", "col": Color("#7A5FA0"), "tex": "res://assets/kaykit/tex/rogue_glycine.png", "petals": 24},
	"or": {"name": "Or du maître", "col": Color("#E2B04A"), "tex": "res://assets/kaykit/tex/rogue_or.png", "petals": 30},
}
## Thèmes : papier des cartes, voile de l'écran, encre du texte (contrastes gardés), liseré.
const THEME_ORDER := ["washi", "nuit", "sakura", "indigo"]
const THEMES := {
	"washi": {"name": "Washi", "paper": Color("#E4D9C2"), "wash": Color("#D8CBB1"), "ink": Color("#1B1A1E"), "accent": Color("#D7372B"), "free": true},
	"nuit": {"name": "Nuit", "paper": Color("#232A3A"), "wash": Color("#151B28"), "ink": Color("#EFE6D2"), "accent": Color("#E2A93B"), "petals": 14},
	"sakura": {"name": "Sakura", "paper": Color("#FBEDEE"), "wash": Color("#F4DCE0"), "ink": Color("#3A1F2A"), "accent": Color("#C2456A"), "petals": 16},
	"indigo": {"name": "Indigo", "paper": Color("#E6ECF4"), "wash": Color("#D5DEEA"), "ink": Color("#13213A"), "accent": Color("#2F5D8A"), "prints": 6},
}

var sumi := 0  # encre, permanente : l'Arbre du pinceau (et la Bourse)
var petals := 0  # pétales (sakura), permanents : la garde-robe seulement
var prints := 0  # Vues collectionnées (= owned_prints.size(), max 24)
var runs := 0  # parties jouées
var best_room := 0  # meilleure salle atteinte
var wins := 0  # victoires (la première rapporte 2 sceaux, soit 80 encre)
var tree := {}  # id de nœud de l'Arbre du pinceau -> true : appris
var purse_rank := 0  # rangs de la Bourse (0..5), hors de l'arbre
const WORLD_COUNT := 8  # mondes du jeu (worlds.gd WORLDS) : bornes des déblocages
var unlocked := 1  # mondes débloqués (1..WORLD_COUNT) : le monde N+1 s'ouvre quand le monde N est vaincu
var won_top := 0  # plus haut monde dont le boss a été vaincu (0 : aucun) : rang Maître ; seul témoin du dernier monde (unlocked y plafonne)
var power_tier := 0  # paliers de rouleaux débloqués (0..4) : monde N vaincu -> palier N (power_data « unlock »)
var test_unlock_all := false  # robot (CI) et tests : tous les mondes et paliers ouverts (jamais sauvegardé)
var tuto_done := false  # tutoriel fini : bulles du coach toutes vues ou passées (anciennes sauvegardes : ancien tutoriel fait)
const COACH_MARKS := ["stroke", "cut", "ink", "figure", "ult", "run", "figures"]  # bulles du coach (coach.gd)
const COACH_EXTRA := ["seal"]  # bulles hors tutoriel (coach.EXTRA) : vues une fois, sans compter pour sa fin
var coach_seen := {}  # id de bulle -> true : déjà montrée
var intro_done := false  # intro illustrée déjà vue (sinon elle s'ouvre au premier JOUER)
var measure_mode := false  # mode mesure (caché : appui long sur le titre de l'accueil, mesure.gd)
var opening_done := false  # ouverture (mini-histoire à l'encre) déjà vue au tout premier démarrage (opening.gd)
var world_best := {}  # monde -> meilleure salle atteinte
var world_score := {}  # monde -> meilleur score (score.gd)
var world_chain := {}  # monde -> plus longue chaîne atteinte
var owned_prints := {}  # id de Vue -> true
var look := {"cape": "", "trail": "", "ink": ""}  # apparence portée : id de Vue ("" = d'origine)
var start_power_id := ""  # rouleau de départ choisi (nœud « v3 » de l'arbre)
var outfit := "sumi"  # tenue portée (OUTFITS)
var theme := "washi"  # thème de l'interface (THEMES)
var bought := {}  # « outfit:kaki », « theme:nuit »… -> true : achats de la garde-robe
# pinceaux et omamori (gear_data.gd) : choix de l'écran de départ et déblocages
const GEAR_VERSION := 1  # sauvegarde : 0 = avant les pinceaux (Fude · Maître acquis, charmes rendus d'après les rangs)
var brush_sel := "fude"  # pinceau choisi pour la prochaine partie
var aspect_sel := {}  # pinceau -> aspect choisi (0..2)
var aspects_won := {}  # pinceau -> aspects possédés (1..3 ; le premier vient avec le pinceau)
var charm_sel := ""  # omamori porté ("" : aucun)
var charms_won := {}  # omamori -> true
var gear_force := false  # robot et captures : pinceau, aspect et charme imposés même verrouillés (jamais sauvegardé)
var test_won := -1  # captures (`won=N`) : seuls les mondes 1..N comptent comme vaincus (jamais sauvegardé)
# bestiaire : id -> [victoires, premier monde, fiche ouverte (0/1)] ; boss rangés en « boss_<id> »
var seen := {}


# --- Sauvegarde -------------------------------------------------------------

func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	sumi = maxi(0, int(cf.get_value("meta", "sumi", 0)))
	petals = maxi(0, int(cf.get_value("meta", "petals", 0)))  # absent des anciennes sauvegardes : 0, l'encre reste entière
	var legacy_prints := clampi(int(cf.get_value("meta", "prints", 0)), 0, MAX_PRINTS)
	runs = maxi(0, int(cf.get_value("meta", "runs", 0)))
	best_room = maxi(0, int(cf.get_value("meta", "best_room", 0)))
	wins = maxi(0, int(cf.get_value("meta", "wins", 0)))
	unlocked = clampi(int(cf.get_value("meta", "unlocked", 1)), 1, WORLD_COUNT)
	power_tier = clampi(int(cf.get_value("meta", "power_tier", 0)), 0, Data.UNLOCK_MAX)
	won_top = clampi(int(cf.get_value("meta", "won_top", 0)), 0, WORLD_COUNT)
	tuto_done = bool(cf.get_value("meta", "tuto_done", false))
	for id in COACH_MARKS + COACH_EXTRA:
		if bool(cf.get_value("coach", id, false)):
			coach_seen[id] = true
	# anciennes sauvegardes : qui a déjà fait le tutoriel n'a pas besoin de l'intro
	intro_done = bool(cf.get_value("meta", "intro_done", tuto_done))
	opening_done = bool(cf.get_value("meta", "opening_done", false))
	measure_mode = bool(cf.get_value("meta", "measure_mode", false))
	start_power_id = String(cf.get_value("meta", "start_power", ""))
	for wid in range(1, WORLD_COUNT + 1):
		world_best[wid] = int(cf.get_value("worlds", str(wid), 0))
		world_score[wid] = maxi(0, int(cf.get_value("scores", str(wid), 0)))
		world_chain[wid] = maxi(0, int(cf.get_value("chains", str(wid), 0)))
	var tree_migrated := false
	# Bourse : section « purse » ; avant l'arbre, c'était la ligne « purse » de la Pierre à encre (rangs gardés)
	purse_rank = clampi(int(cf.get_value("purse", "rank", cf.get_value("stone", "purse", 0))), 0, PURSE_COSTS.size())
	if int(cf.get_value("meta", "tree_version", 0)) < TREE_VERSION:
		_migrate_tree(cf)
		tree_migrated = true
	else:
		for id in TREE_ORDER:
			if bool(cf.get_value("tree", id, false)):
				tree[id] = true
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
	# pinceaux et omamori
	brush_sel = String(cf.get_value("gear", "brush", "fude"))
	charm_sel = String(cf.get_value("gear", "charm", ""))
	for bid in Gear.ORDER:
		aspect_sel[bid] = clampi(int(cf.get_value("gear_aspect", bid, 0)), 0, 2)
		aspects_won[bid] = clampi(int(cf.get_value("gear_won", bid, 1)), 1, 3)
	for cid in Gear.CHARM_ORDER:
		if bool(cf.get_value("gear_charm", cid, false)):
			charms_won[cid] = true
	var gear_v := int(cf.get_value("gear", "version", 0))
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
	if learned("v3") and not Data.POWERS.has(start_power_id):
		start_power_id = _first_choice()
	if gear_v < GEAR_VERSION:
		_migrate_gear()
	_retro_charms()
	if not Gear.BRUSHES.has(brush_sel):
		brush_sel = "fude"
	if charm_sel != "" and not Gear.CHARMS.has(charm_sel):
		charm_sel = ""
	if tree_migrated or gear_v < GEAR_VERSION:
		save_data()  # une seule fois : le drapeau tree_version est écrit, les anciens achats effacés


## Ancienne sauvegarde (Pierre à encre et sceaux) : tout ce qui a été dépensé est rendu en encre (somme des
## coûts des rangs et des dons possédés ; un sceau vaut SEAL_SUMI encre), ainsi que les sceaux gardés ; la Bourse
## (ligne « purse ») n'est pas remboursée : ses rangs restent (purse_rank) ; le Sceau du marchand, lui, l'est.
## Puis ces achats sont effacés (save_data ne réécrit plus les sections « stone » et « seals »).
## L'arbre part vide : le joueur réapprend ce qu'il veut avec l'encre rendue.
func _migrate_tree(cf: ConfigFile) -> void:
	var refund := 0
	for id in LEGACY_LINE_COSTS.keys():
		var costs: Array = LEGACY_LINE_COSTS[id]
		var r := clampi(int(cf.get_value("stone", String(id), 0)), 0, costs.size())
		for i in r:
			refund += int(costs[i])
	var seal_n := maxi(0, int(cf.get_value("meta", "seals", 0)))
	for id in LEGACY_SEAL_COSTS.keys():
		if bool(cf.get_value("seals", String(id), false)):
			seal_n += int(LEGACY_SEAL_COSTS[id])
	refund += seal_n * SEAL_SUMI
	sumi += refund
	tree = {}
	if refund > 0:
		print("Atelier : Pierre à encre et sceaux remplacés par l'Arbre du pinceau, %d encre rendue" % refund)


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
	# sauvegardes d'avant won_top : un monde est vaincu dès que le suivant est ouvert
	won_top = clampi(maxi(won_top, maxi(top_won, unlocked - 1)), 0, WORLD_COUNT)


## Sauvegarde d'avant les pinceaux : Fude · Maître acquis d'office (aspects_won vaut 1 par défaut), aucun
## charme porté ; les omamori déjà mérités (rang Maître d'un monde) sont rendus par _retro_charms.
func _migrate_gear() -> void:
	brush_sel = "fude"
	charm_sel = ""
	for bid in Gear.ORDER:
		aspect_sel[bid] = 0
		aspects_won[bid] = maxi(1, int(aspects_won.get(bid, 1)))


## Omamori mérités d'après les records : rang Maître (極) au meilleur score d'un monde vaincu.
func _retro_charms() -> void:
	for cid in Gear.CHARM_ORDER:
		var wid := int(Gear.CHARMS[cid]["world"])
		if Score.rank_of(world_score_of(wid), wid, world_cleared(wid)) >= Score.RANK_PTS.size():
			charms_won[cid] = true


func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("gear", "version", GEAR_VERSION)
	cf.set_value("gear", "brush", brush_sel)
	cf.set_value("gear", "charm", charm_sel)
	for bid in Gear.ORDER:
		cf.set_value("gear_aspect", bid, int(aspect_sel.get(bid, 0)))
		cf.set_value("gear_won", bid, int(aspects_won.get(bid, 1)))
	for cid in Gear.CHARM_ORDER:
		cf.set_value("gear_charm", cid, charms_won.has(cid))
	cf.set_value("meta", "sumi", sumi)
	cf.set_value("meta", "petals", petals)
	cf.set_value("meta", "tree_version", TREE_VERSION)
	cf.set_value("meta", "prints", prints)
	cf.set_value("meta", "runs", runs)
	cf.set_value("meta", "best_room", best_room)
	cf.set_value("meta", "wins", wins)
	cf.set_value("meta", "unlocked", unlocked)
	cf.set_value("meta", "power_tier", power_tier)
	cf.set_value("meta", "won_top", won_top)
	cf.set_value("meta", "tuto_done", tuto_done)
	for id in COACH_MARKS + COACH_EXTRA:
		cf.set_value("coach", id, coach_seen.has(id))
	cf.set_value("meta", "intro_done", intro_done)
	cf.set_value("meta", "opening_done", opening_done)
	cf.set_value("meta", "measure_mode", measure_mode)
	cf.set_value("meta", "start_power", start_power_id)
	for wid in world_best.keys():
		cf.set_value("worlds", str(wid), int(world_best[wid]))
	for wid in world_score.keys():
		cf.set_value("scores", str(wid), int(world_score[wid]))
	for wid in world_chain.keys():
		cf.set_value("chains", str(wid), int(world_chain[wid]))
	for id in TREE_ORDER:
		cf.set_value("tree", id, learned(id))
	cf.set_value("purse", "rank", purse_rank)
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
	return seen.has(k) or test_unlock_all  # ?unlockall : bestiaire complet (captures)


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
	for m in COACH_MARKS + COACH_EXTRA:
		coach_seen[m] = true
	tuto_done = true


## « Revoir le tutoriel » : les bulles reviendront, et le prochain JOUER mène droit au monde 1.
func coach_reset() -> void:
	coach_seen = {}
	tuto_done = false


## Tout premier lancement (ou tutoriel à revoir) : JOUER mène droit au monde 1, avec le coach.
func coach_first_run() -> bool:
	return not tuto_done and not coach_seen.has("stroke")


# --- Arbre du pinceau --------------------------------------------------------

## Nœud appris (le tronc l'est toujours).
func learned(id: String) -> bool:
	return id == TREE_ROOT or bool(tree.get(id, false))


## Nœud du dessous ("root" pour le premier de chaque branche, "" si l'id est inconnu).
func node_prereq(id: String) -> String:
	if not TREE.has(id):
		return ""
	var n: Dictionary = TREE[id]
	var t := int(n["t"])
	if t <= 1:
		return TREE_ROOT
	for k in TREE_ORDER:
		var m: Dictionary = TREE[k]
		if String(m["b"]) == String(n["b"]) and int(m["t"]) == t - 1:
			return String(k)
	return ""


## Disponible : pas encore appris, et celui du dessous l'est.
func node_open(id: String) -> bool:
	return TREE.has(id) and not learned(id) and learned(node_prereq(id))


func node_cost(id: String) -> int:
	if not TREE.has(id):
		return -1
	var n: Dictionary = TREE[id]
	return int(n["cost"])


func can_learn(id: String) -> bool:
	return node_open(id) and sumi >= node_cost(id)


## Débite l'encre, apprend le nœud et sauvegarde.
func learn(id: String) -> bool:
	if not can_learn(id):
		return false
	sumi -= node_cost(id)
	tree[id] = true
	if id == "v3" and not (start_power_id in start_choices()):
		start_power_id = _first_choice()
	save_data()
	return true


## Vrai si un nœud au moins est à la portée de l'encre actuelle (pastille sur l'onglet).
func any_learnable() -> bool:
	for id in TREE_ORDER:
		if can_learn(String(id)):
			return true
	return can_buy_purse()


## Bourse : prix du prochain rang (-1 au rang max).
func purse_cost() -> int:
	return -1 if purse_rank >= PURSE_COSTS.size() else int(PURSE_COSTS[purse_rank])


func can_buy_purse() -> bool:
	var c := purse_cost()
	return c >= 0 and sumi >= c


## Débite l'encre, monte la Bourse d'un rang et sauvegarde.
func buy_purse() -> bool:
	if not can_buy_purse():
		return false
	sumi -= purse_cost()
	purse_rank += 1
	save_data()
	return true


## Nombre de nœuds appris parmi ids.
func _count(ids: Array) -> int:
	var n := 0
	for id in ids:
		if learned(String(id)):
			n += 1
	return n


## Figure connue : les six de base toujours ; Vague, Pointe et Triangle une fois apprises (v2, v4, v6).
func fig_learned(kind: String) -> bool:
	if kind in BASE_FIGURES:
		return true
	for id in ["v2", "v4", "v6"]:
		var n: Dictionary = TREE[id]
		if String(n.get("fig", "")) == kind:
			return learned(id)
	return false


## Rouleaux communs proposés au départ (débloqués, et qui ne dépendent d'aucun autre pouvoir).
func start_choices() -> Array:
	var out: Array = []
	for key in Data.POWERS.keys():
		var d: Dictionary = Data.POWERS[key]
		if String(d.get("rarity", "")) == "common" and not d.has("needs") and power_unlocked(String(key)):
			var tf := Data.tree_figure(String(key))  # technique d'une figure de l'arbre : seulement si elle est apprise
			if tf != "" and not fig_learned(tf):
				continue
			out.append(String(key))
	return out


func _first_choice() -> String:
	var ch := start_choices()
	return "" if ch.is_empty() else String(ch[0])


## Rouleau de départ effectif ("" sans le nœud « Rouleau de départ »).
func start_power() -> String:
	if not learned("v3"):
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


## Sommet de l'arbre qui libère ce pouvoir ("" s'il n'en dépend pas).
func _node_of_power(id: String) -> String:
	for nid in TREE_ORDER:
		var n: Dictionary = TREE[nid]
		if String(n.get("power", "")) == id:
			return String(nid)
	return ""


## Vrai pour un légendaire de l'arbre dont le sommet n'est pas encore appris.
func power_sealed(id: String) -> bool:
	var nid := _node_of_power(id)
	return nid != "" and not learned(nid)


## Palier de rouleaux effectif (tout ouvert pour le robot et les tests).
func effective_tier() -> int:
	return Data.UNLOCK_MAX if test_unlock_all else power_tier


## Vrai si ce pouvoir peut sortir dans les rouleaux : légendaire de l'arbre -> son sommet (quel que soit
## le palier) ; sinon son palier « unlock » doit être atteint. powers.gd écarte les autres de ses offres.
func power_unlocked(id: String) -> bool:
	var nid := _node_of_power(id)
	if nid != "":
		return learned(nid)
	return Data.unlock_tier(id) <= effective_tier()


## Pouvoirs d'un palier (dans l'ordre de power_data), sans les légendaires de l'arbre.
func powers_of_tier(t: int) -> Array:
	var out: Array = []
	for key in Data.POWERS.keys():
		var id := String(key)
		if Data.unlock_tier(id) == t and _node_of_power(id) == "":
			out.append(id)
	return out


## Boss du monde déjà vaincu une fois (rang Maître permis) : vaut aussi pour le dernier monde, sans monde suivant.
func world_cleared(wid: int) -> bool:
	if test_won >= 0:
		return wid >= 1 and wid <= test_won  # captures `won=N` : progression de démonstration
	return wid >= 1 and (wid <= won_top or world_won(wid))


## Monde vaincu (Vue « w<id>_win »).
func world_won(wid: int) -> bool:
	return has_print("w%d_win" % wid)


## Pouvoirs encore verrouillés par un sommet de l'arbre (légendaires à apprendre).
func locked_powers() -> Array:
	var out: Array = []
	for nid in TREE_ORDER:
		var n: Dictionary = TREE[nid]
		var p := String(n.get("power", ""))
		if p != "" and not learned(String(nid)):
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


## Prix en pétales (-1 : ne s'achète pas).
func cosmetic_cost(cat: String, id: String) -> int:
	var d := _cosmetic(cat, id)
	return int(d.get("petals", -1))


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
	if d.has("petals"):
		return "S'achète %d pétales." % int(d["petals"])
	if d.has("print"):
		var pid := String(d["print"])
		var p: Dictionary = PRINTS.get(pid, {})
		return "Vue « %s » : %s" % [String(p.get("name", pid)), print_how(pid)]
	if d.has("prints"):
		return "Collectionne %d Vues (tu en as %d)." % [int(d["prints"]), prints]
	return ""


func can_buy_cosmetic(cat: String, id: String) -> bool:
	var c := cosmetic_cost(cat, id)
	return c >= 0 and not cosmetic_owned(cat, id) and petals >= c


## Achète (pétales) puis porte ; sauvegarde. Renvoie vrai si l'achat a eu lieu.
func buy_cosmetic(cat: String, id: String) -> bool:
	if not can_buy_cosmetic(cat, id):
		return false
	petals -= cosmetic_cost(cat, id)
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


# --- Pinceaux et omamori ------------------------------------------------------

## Pinceau débloqué : Fude d'office, les autres en battant le boss de leur monde.
func brush_unlocked(id: String) -> bool:
	if not Gear.BRUSHES.has(id):
		return false
	var w := int(Gear.BRUSHES[id]["world"])
	return w <= 0 or world_cleared(w)


## Aspect `k` du pinceau possédé (le premier vient avec le pinceau, les suivants dans l'ordre).
func aspect_owned(id: String, k: int) -> bool:
	return brush_unlocked(id) and k >= 0 and k < int(aspects_won.get(id, 1))


func charm_owned(id: String) -> bool:
	return charms_won.has(id)


## Équipement de la partie qui commence : le choix gardé, ramené à ce qui est possédé (sauf gear_force).
## Renvoie {"brush", "aspect", "charm"}.
func gear_now() -> Dictionary:
	var b := brush_sel if Gear.BRUSHES.has(brush_sel) else "fude"
	var k := clampi(int(aspect_sel.get(b, 0)), 0, 2)
	var c := charm_sel if Gear.CHARMS.has(charm_sel) else ""
	if not gear_force:
		if not brush_unlocked(b):
			b = "fude"
			k = 0
		if not aspect_owned(b, k):
			k = 0
		if c != "" and not charm_owned(c):
			c = ""
	return {"brush": b, "aspect": k, "charm": c}


## Choix de l'écran de départ (PARTIR) : gardé pour les parties suivantes.
func choose_gear(b: String, k: int, c: String) -> void:
	brush_sel = b
	aspect_sel[b] = clampi(k, 0, 2)
	charm_sel = c
	save_data()


## Boss du monde vaincu avec le pinceau `b` : son aspect suivant (dans l'ordre), et les pinceaux qu'ouvre ce
## monde (`before` : brushes_open() avant la victoire). Renvoie [{"kind": "brush"|"aspect", "id", "k"}].
func on_world_won(b: String, before: Dictionary) -> Array:
	var out: Array = []
	if Gear.BRUSHES.has(b) and brush_unlocked(b) and not gear_force:
		var n := int(aspects_won.get(b, 1))
		if n < 3:
			aspects_won[b] = n + 1
			out.append({"kind": "aspect", "id": b, "k": n})
	for bid in Gear.ORDER:
		if not bool(before.get(bid, false)) and brush_unlocked(bid):
			out.append({"kind": "brush", "id": bid, "k": 0})
	save_data()
	return out


## Pinceaux débloqués à cet instant (pour comparer avant / après une victoire).
func brushes_open() -> Dictionary:
	var d := {}
	for bid in Gear.ORDER:
		d[bid] = brush_unlocked(bid)
	return d


## Omamori gagné au rang Maître du monde `wid` (après score.finish) : son id, sinon "".
func check_charm(wid: int) -> String:
	for cid in Gear.CHARM_ORDER:
		if int(Gear.CHARMS[cid]["world"]) == wid and not charms_won.has(cid):
			if Score.rank_of(world_score_of(wid), wid, world_cleared(wid)) >= Score.RANK_PTS.size():
				charms_won[cid] = true
				save_data()
				return cid
	return ""


# --- Effets appliqués à une partie -------------------------------------------

## Mètres d'élan max en plus (Pinceau long I et II).
func elan_bonus() -> float:
	return float(_count(["e1", "e3"]))


## Multiplicateur de recharge de l'élan (Encre vive I et II).
func regen_mult() -> float:
	return 1.0 + 0.06 * _count(["e2", "e4"])


## PV max en plus (Peau de papier I, II, III).
func hp_bonus() -> int:
	return _count(["p1", "p3", "p5"])


## Filets de sécurité par salle (1 de base, +1 avec Second souffle).
func safety_per_room() -> int:
	return 1 + _count(["e6"])


## Relances de rouleaux par partie (Seconde chance).
func rerolls() -> int:
	return _count(["v1"])


## Multiplicateur de l'encre gagnée en fin de partie (Bourse).
func sumi_mult() -> float:
	return 1.0 + 0.01 * PURSE_STEP * purse_rank


## Multiplicateur des dégâts du trait : Tranchant I et II, Élan du rōnin (chaîne >= RONIN_CHAIN).
func dmg_mult(chain: int) -> float:
	var m := 1.0 + TREE_DMG_STEP * _count(["l1", "l2"])
	if chain >= RONIN_CHAIN and learned("l6"):
		m *= 1.0 + RONIN_DMG
	return m


## Jauge d'élan : plafond de la recharge (Réserve : déborde d'environ un trait au-delà de l'élan max).
func reserve_mult() -> float:
	return 1.0 + RESERVE_FRAC if learned("e5") else 1.0


## Part de la jauge d'ultime par figure (main.ULT_PER_FIGURE sans le Maître des figures).
func ult_per_figure(base: float) -> float:
	return MASTER_ULT if learned("vc") else base


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
	if learned("v5"):
		m._extra_picks = int(m._extra_picks) + 1


# --- Fin de partie ----------------------------------------------------------

## Calcule et crédite les gains d'une partie (§5.1), sauvegarde, renvoie {"sumi", "petals", "seals", "print", "prints"}.
## Les anciens sceaux sont payés en encre (SEAL_SUMI chacun) : 1 par gardien, 2 par boss, et en cas de victoire
## 1 par malédiction portée (3 au plus), 2 à la toute première victoire ; « seals » vaut toujours 0. Vues : selon le monde joué (world_id) et le nombre de parties.
## Pétales (garde-robe) : PETALS_MINI par gardien, PETALS_BOSS par boss, PETALS_WIN pour une victoire, 1 par défi
## relevé (challenges : élites des recoins) et 1 par Vue nouvelle.
func award_run(rooms_cleared: int, kills: int, boss_kills: int, curses: int, victory: bool, mini_boss_kills := 0, world_id := 0, challenges := 0) -> Dictionary:
	var base := float(floori(maxi(0, kills) / 5.0) + 10 * mini_boss_kills + 30 * boss_kills + SUMI_PER_ROOM * rooms_cleared)
	base *= 1.0 + 0.15 * maxi(0, curses)
	var gained := maxi(0, int(round(base * sumi_mult())))
	var new_seals := maxi(0, mini_boss_kills) + 2 * maxi(0, boss_kills)
	if victory:
		new_seals += mini(maxi(0, curses), 3)
		if wins == 0:
			new_seals += 2
		wins += 1
	gained += new_seals * SEAL_SUMI
	sumi += gained
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
	var new_petals := PETALS_MINI * maxi(0, mini_boss_kills) + PETALS_BOSS * maxi(0, boss_kills) + maxi(0, challenges) + new_prints.size()
	if victory:
		new_petals += PETALS_WIN
	petals += new_petals
	save_data()
	return {"sumi": gained, "petals": new_petals, "seals": 0, "print": not new_prints.is_empty(), "prints": new_prints}


## Fin d'une partie dans un monde : record du monde ; en cas de victoire, le monde suivant s'ouvre et le
## palier de rouleaux du monde aussi. Renvoie ce que la victoire a débloqué :
## {"world": monde ouvert (0 : aucun), "tier": nouveau palier (-1 : aucun), "powers": ids, "family": nom}.
func record_world(world_id: int, room_reached: int, victory: bool) -> Dictionary:
	var res := {"world": 0, "tier": -1, "powers": [], "family": ""}
	world_best[world_id] = maxi(int(world_best.get(world_id, 0)), room_reached)
	if victory:
		var before := unlocked
		unlocked = clampi(maxi(unlocked, world_id + 1), 1, WORLD_COUNT)
		won_top = clampi(maxi(won_top, world_id), 0, WORLD_COUNT)
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

