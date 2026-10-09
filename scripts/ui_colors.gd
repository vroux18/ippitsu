extends RefCounted
## Jetons de couleur de l'interface v2 (design/ui_v2/tokens/theme.json, handoff UI v2) : papier, encre, accents,
## éléments jour / nuit, raretés (bordure seule), encres des figures, puces de multiplicateur.
## Référencé par preload (comme ui_kit.gd) : const UIColors = preload("res://scripts/ui_colors.gd").

# ------------------------------------------------------------------ papier, encre, accents
const WASHI := Color("#EFE6D2")
const WASHI_LIGHT := Color("#F5EEDD")
const WASHI_DARK := Color("#E4D9C2")
const SUMI := Color("#1B1A1E")
const SUMI_HUD_BG := Color(0.106, 0.102, 0.118, 0.92)  # #1B1A1E à 92 % : fond du HUD, quel que soit le thème
const VERMILION := Color("#D7372B")
const VERMILION_DARK := Color("#B3261C")
const GOLD := Color("#E2A93B")
const GOLD_DARK := Color("#C49A45")
const TEXT_MUTED := Color("#5A5148")
const LINE_MUTED := Color("#CFC4AE")
const LINE_MUTED_DARK := Color("#5A5768")  # filets éteints sur fond sombre (cartes, anneaux)
const DISABLED := Color("#A99E8B")
const JADE_UP := Color("#2E7D4F")
const JADE_UP_ON_DARK := Color("#8FD6A8")
const MALUS_ON_DARK := Color("#FF8A7A")
const CHIP_ON_DARK := Color("#26302A")  # fond d'un ticket d'effet sur une bulle d'encre
# zones d'attaque : rouge à 42-45 %, contour 3,5 et liseré blanc pointillé 1,2 (6/6)
const ATTACK_ZONE_FILL := Color(0.890, 0.141, 0.169, 0.44)
const ATTACK_ZONE_STROKE := Color("#FF4A3D")
const ATTACK_ZONE_STROKE_W := 3.5
const ATTACK_ZONE_DASH_W := 1.2
const ATTACK_ZONE_DASH := 6.0

# ------------------------------------------------------------------ éléments
# clé du handoff -> couleur sur papier (jour), couleur sur fond sombre (nuit), pictogramme (UiKit.icon)
const ELEMENTS := {
	"feu": {"washi": Color("#D7372B"), "nuit": Color("#E8574A"), "icon": "elements/feu", "word": "FEU"},
	"eau": {"washi": Color("#1F3A5F"), "nuit": Color("#5B8BC9"), "icon": "elements/eau", "word": "EAU"},
	"foudre": {"washi": Color("#C49A45"), "nuit": Color("#E2B862"), "icon": "elements/foudre", "word": "FOUDRE"},
	"vent": {"washi": Color("#5F8F86"), "nuit": Color("#7DB3A8"), "icon": "elements/vent", "word": "VENT"},
	"ombre": {"washi": Color("#3A3846"), "nuit": Color("#8E89A8"), "icon": "elements/ombre", "word": "OMBRE"},
	"neutre": {"washi": Color("#6E5A44"), "nuit": Color("#B39A7C"), "icon": "elements/neutre", "word": "NEUTRE"},
	"figure": {"washi": Color("#A8436B"), "nuit": Color("#D06A93"), "icon": "elements/figure", "word": "FIGURE"},
}
# école du jeu (power_data.SCHOOLS) -> élément du handoff (l'encre est l'élément neutre : pas d'anneau d'harmonie)
const SCHOOL_ELEMENT := {"fire": "feu", "water": "eau", "bolt": "foudre", "wind": "vent", "shadow": "ombre",
	"ink": "neutre", "fig": "figure"}

# scène peinte d'une carte de rouleau, par élément (RouleauCard) : fond, motif (trait), motif (remplissage)
const CARD_SCENE := {
	"feu": {"bg": Color("#D7372B"), "deco": Color("#E8574A"), "fill": Color("#F2A33A")},
	"eau": {"bg": Color("#2B4A6E"), "deco": Color("#5B8BC9")},
	"foudre": {"bg": Color("#3A3150"), "deco": Color("#E2B862")},
	"vent": {"bg": Color("#5F8F86"), "deco": Color("#9CC5BC")},
	"ombre": {"bg": Color("#2A2833"), "deco": Color("#5A5768")},
	"neutre": {"bg": Color("#8C7458"), "deco": Color("#A08C72")},
	"figure": {"bg": Color("#7E3354"), "deco": Color("#D06A93")},
}

# encre des six figures (Icones : « couleur d'encre »)
const FIGURES_INK := {"loop": Color("#3E9C8C"), "zigzag": Color("#D9A93A"), "straight": Color("#C8463A"),
	"return": Color("#3D7EC4"), "enso": Color("#C2668F"), "hook": Color("#8A5BB0")}

# ------------------------------------------------------------------ rareté = bordure seule (jamais de mot)
# rang (power_data.RARITIES) -> couleur, épaisseur (× u), filet intérieur 1,5 à 2 de retrait, contour sumi extérieur 2
const RARITY := {
	0: {"color": Color("#8C8273"), "w": 2.0, "inner": false, "outer": false},
	1: {"color": Color("#2F5D8A"), "w": 3.0, "inner": false, "outer": false},
	2: {"color": Color("#8A5BB0"), "w": 3.0, "inner": true, "outer": false},
	3: {"color": Color("#C49A45"), "w": 3.0, "inner": true, "outer": true},
}
const PACT_BORDER := Color("#D7372B")  # pacte : vermillon, pas de crans

# ------------------------------------------------------------------ mondes
# clé du monde (worlds.gd « kanji », jamais affichée) -> picto du monde (HUD, pause, accueil)
const WORLD_ICON := {"波": "hud/vague", "竹": "hud/bambou", "雪": "hud/neige", "火": "elements/feu", "墨": "hud/pinceau",
	"天": "hud/etoile", "龍": "hud/couronne", "冥": "elements/ombre"}

# ------------------------------------------------------------------ puces de multiplicateur (HUD)
const MULT_CHIP := {"x1.5": Color("#3E9C8C"), "x2": Color("#E2A93B"), "x3": Color("#E25A3F"), "x4": Color("#C2668F")}


## Élément du handoff d'une école du jeu ("fire" -> "feu") ; "neutre" si inconnue.
static func element_of(school: String) -> String:
	return String(SCHOOL_ELEMENT.get(school, "neutre"))


## Couleur d'un élément du handoff ("feu"…), version claire (nuit) pour un fond sombre.
static func element_key_color(key: String, night := false) -> Color:
	var e: Dictionary = ELEMENTS.get(key, ELEMENTS["neutre"])
	var c: Color = e["nuit"] if night else e["washi"]
	return c


## Couleur de l'élément d'une école du jeu ; night : sur fond sombre.
static func element(school: String, night := false) -> Color:
	return element_key_color(element_of(school), night)


## Pictogramme (clé UiKit.icon) de l'élément d'une école du jeu.
static func element_icon(school: String) -> String:
	var e: Dictionary = ELEMENTS.get(element_of(school), ELEMENTS["neutre"])
	return String(e["icon"])


## Nom de l'élément en capitales (étiquette « picto + NOM »).
static func element_word(school: String) -> String:
	var e: Dictionary = ELEMENTS.get(element_of(school), ELEMENTS["neutre"])
	return String(e["word"])


## Bordure de rareté d'un rang (0 commun … 3 légendaire).
static func rarity(rank: int) -> Dictionary:
	return RARITY.get(clampi(rank, 0, 3), RARITY[0])


## Scène d'une carte de rouleau pour l'élément d'une école.
static func card_scene(school: String) -> Dictionary:
	return CARD_SCENE.get(element_of(school), CARD_SCENE["neutre"])


## Couleur hexadécimale « #RRGGBB » (pour recolorer une source SVG).
static func hex(c: Color) -> String:
	return "#" + c.to_html(false).to_upper()
