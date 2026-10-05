extends RefCounted
## Données des rouleaux : écoles, raretés, pouvoirs, affinités et synergies.
## Texte : « {v} » / « {w} » remplacés par la valeur du niveau suivant (tableaux v / w).
## Clés facultatives : "max" (niveau max, 3 par défaut, 1 pour les légendaires), "kanji" (idéogramme propre),
## "needs" (au moins un de ces pouvoirs déjà pris).

const SCHOOLS := {
	"fire": {"kanji": "火", "color": Color("#D7372B"), "name": "FEU", "word": "Feu"},
	"water": {"kanji": "水", "color": Color("#1F3A5F"), "name": "EAU", "word": "Eau"},
	"bolt": {"kanji": "雷", "color": Color("#C49A45"), "name": "FOUDRE", "word": "Foudre"},
	"wind": {"kanji": "風", "color": Color("#5F8F86"), "name": "VENT", "word": "Vent"},
	"shadow": {"kanji": "影", "color": Color("#3A3846"), "name": "OMBRE", "word": "Ombre"},
	"ink": {"kanji": "墨", "color": Color("#6E5A44"), "name": "ENCRE", "word": "Encre"},
}

const RARITIES := {
	"common": {"rank": 0, "name": "COMMUN", "color": Color("#8A8478")},
	"rare": {"rank": 1, "name": "RARE", "color": Color("#3D78B8")},
	"epic": {"rank": 2, "name": "ÉPIQUE", "color": Color("#8752B5")},
	"legendary": {"rank": 3, "name": "LÉGENDAIRE", "color": Color("#E2A93B")},
}
const RARITY_ORDER := ["common", "rare", "epic", "legendary"]

# seuils d'affinité (nombre de pouvoirs différents d'une école) et leur bonus
const AFF_TIERS := [2, 4]
const AFFINITY := {
	"fire": ["feu +25 %", "feu +50 %, coups embrasants"],
	"water": ["+1 écume par salle", "soin par salle, vagues +50 %"],
	"bolt": ["ruée +10 %, foudre +25 %", "foudre +50 %, éclairs en série"],
	"wind": ["+2 m d'élan", "+4 m d'élan, ruée +15 %"],
	"shadow": ["10 % de critiques ×2", "25 % de critiques ×2.5"],
}

# [pouvoir, partenaire, effet en plus quand on a les deux]
const SYNERGIES := [
	["shadow_bunshin", "fire_trail", "Sillage : le clone embrase son trait"],
	["shadow_kitsunebi", "fire_burn", "Braise : les feux follets embrasent"],
	["bolt_raijin", "bolt_arc", "Arc : +1 cible à chaque éclair"],
	["water_kanagawa", "water_push", "Ressac : la vague frappe +1"],
	["fire_kasha", "fire_trail", "Sillage : la roue laisse du feu"],
	["wind_tsumuji", "wind_feather", "Plume : tourbillons +50 %"],
	["shadow_execute", "shadow_back", "Ushiro : seuil +10 %"],
	["wind_fujin", "wind_blades", "Kamaitachi : l'aspiration blesse"],
	["fire_fudo", "fire_edge", "Lame rouge : halo plus ardent"],
	["water_uzushio", "water_tide", "Marée : le tourbillon dure +1 s"],
	["bolt_charge", "wind_long", "Souffle long : plus de charge"],
	["ink_enso", "fire_hearth", "Foyer : l'onde d'encre brûle"],
]

const POWERS := {
	# ---------------------------------------------------------------- FEU
	"fire_burn": {"school": "fire", "rarity": "common", "name": "Braise",
		"text": "Les ennemis tranchés brûlent 3 s ({v} dégâts/s)", "v": [0.5, 0.8, 1.1]},
	"fire_trail": {"school": "fire", "rarity": "common", "name": "Sillage",
		"text": "Le trait laisse du feu 3 s ({v} dégâts/s)", "v": [0.6, 0.9, 1.2]},
	"fire_edge": {"school": "fire", "rarity": "common", "name": "Lame rouge",
		"text": "+{v} % de dégâts sur les ennemis en feu", "v": [30, 45, 60], "needs": ["fire_burn", "fire_fudo"]},
	"fire_hearth": {"school": "fire", "rarity": "rare", "name": "Foyer",
		"text": "Cercle de feu à l'arrivée ({v} dégâts)", "v": [1.0, 1.5, 2.0]},
	"fire_spark": {"school": "fire", "rarity": "rare", "name": "Hibana",
		"text": "Un ennemi qui meurt en feu explose ({v} dégâts) et propage le feu", "v": [0.6, 0.9, 1.2],
		"needs": ["fire_burn", "fire_fudo"]},
	"fire_kasha": {"school": "fire", "rarity": "epic", "name": "Kasha",
		"text": "La boucle (渦) lâche une roue de feu qui chasse les ennemis ({v} dégâts/s)", "v": [1.5, 2.0, 2.5]},
	"fire_fudo": {"school": "fire", "rarity": "legendary", "name": "Fudō Myōō", "kanji": "炎", "max": 1,
		"text": "Un halo de flammes t'entoure : il embrase et brûle tout ce qui approche (2 dégâts/s)", "v": [2.0]},
	"fire_hoo": {"school": "fire", "rarity": "legendary", "name": "Hōō", "kanji": "鳳", "max": 1,
		"text": "+1 vie max. Un coup fatal te fait renaître (3 vies) dans une explosion, puis dégâts +25 %", "v": [3]},

	# ---------------------------------------------------------------- EAU
	"water_push": {"school": "water", "rarity": "common", "name": "Ressac",
		"text": "Repousse les ennemis tranchés ({v} m)", "v": [2.5, 3.2, 4.0]},
	"water_dew": {"school": "water", "rarity": "common", "name": "Rosée",
		"text": "+1 vie tous les {v} ennemis tués", "v": [12, 10, 8]},
	"water_foam": {"school": "water", "rarity": "rare", "name": "Écume",
		"text": "{v} coup(s) bloqué(s) par salle ; l'écume éclate ({w} dégâts)", "v": [1, 1, 2], "w": [1.0, 2.0, 2.0]},
	"water_tide": {"school": "water", "rarity": "rare", "name": "Marée",
		"text": "À l'arrivée, une vague blesse et repousse autour de toi ({v} dégâts)", "v": [0.8, 1.2, 1.6]},
	"water_uzushio": {"school": "water", "rarity": "epic", "name": "Uzushio", "kanji": "渦",
		"text": "Un combo de 3 ouvre un tourbillon qui aspire et broie ({v} dégâts/s)", "v": [0.8, 1.1, 1.4]},
	"water_mirror": {"school": "water", "rarity": "epic", "name": "Kagami", "kanji": "返",
		"text": "Ta ruée renvoie les projectiles qu'elle frôle ({v} m)", "v": [1.0, 1.4, 1.8]},
	"water_kanagawa": {"school": "water", "rarity": "legendary", "name": "Kanagawa", "kanji": "波", "max": 1,
		"text": "Tous les 3 traits, la Grande Vague déferle sur tout le trait (3 dégâts). +1 écume par salle", "v": [3]},

	# ---------------------------------------------------------------- FOUDRE
	"bolt_arc": {"school": "bolt", "rarity": "common", "name": "Arc",
		"text": "Chaque coup foudroie {v} ennemi(s) proche(s)", "v": [1, 2, 3]},
	"bolt_quick": {"school": "bolt", "rarity": "common", "name": "Vif",
		"text": "Ruée {v} % plus rapide", "v": [20, 30, 40]},
	"bolt_charge": {"school": "bolt", "rarity": "common", "name": "Charge",
		"text": "Chaque mètre tracé charge {v} dégât, libéré à l'arrivée", "v": [0.08, 0.11, 0.14]},
	"bolt_storm": {"school": "bolt", "rarity": "rare", "name": "Orage",
		"text": "Toutes les {v} touches, la foudre frappe 3 ennemis", "v": [8, 6, 4]},
	"bolt_thunder": {"school": "bolt", "rarity": "rare", "name": "Tonnerre",
		"text": "Combo de 3 : étourdit les ennemis tranchés, +{v} dégâts", "v": [0.4, 0.7, 1.0]},
	"bolt_raiju": {"school": "bolt", "rarity": "epic", "name": "Raijū",
		"text": "Toutes les {v} s, un loup-tonnerre foudroie et étourdit un ennemi (2 dégâts)", "v": [6, 5, 4]},
	"bolt_inazuma": {"school": "bolt", "rarity": "epic", "name": "Inazuma",
		"text": "Le zigzag (雷) foudroie {v} ennemis de plus et les étourdit", "v": [3, 5, 7]},
	"bolt_raijin": {"school": "bolt", "rarity": "legendary", "name": "Raijin no Taiko", "kanji": "神", "max": 1,
		"text": "Chaque coup foudroie 2 ennemis. Tous les 4 traits, le tambour frappe chaque ennemi qui attaque", "v": [2]},

	# ---------------------------------------------------------------- VENT
	"wind_long": {"school": "wind", "rarity": "common", "name": "Souffle long",
		"text": "+{v} m de trait", "v": [3, 5, 7]},
	"wind_gust": {"school": "wind", "rarity": "common", "name": "Bourrasque",
		"text": "Élan {v} % plus rapide", "v": [30, 45, 60]},
	"wind_feather": {"school": "wind", "rarity": "common", "name": "Plume",
		"text": "Bond d'esquive gratuit et plus long ({v} m)", "v": [3.2, 3.6, 4.0]},
	"wind_blades": {"school": "wind", "rarity": "rare", "name": "Kamaitachi",
		"text": "Deux lames de vent élargissent la coupe ({v} dégâts)", "v": [0.5, 0.8, 1.1]},
	"wind_tsumuji": {"school": "wind", "rarity": "epic", "name": "Tsumuji",
		"text": "Chaque esquive laisse un tourbillon tranchant à ses deux bouts ({v} dégâts)", "v": [1.2, 1.6, 2.0]},
	"wind_stillness": {"school": "wind", "rarity": "epic", "name": "Souffle suspendu",
		"text": "Poser le doigt ralentit le temps {v} s (recharge 5 s)", "v": [0.6, 0.8, 1.0]},
	"wind_fujin": {"school": "wind", "rarity": "legendary", "name": "Fūjin", "kanji": "嵐", "max": 1,
		"text": "Le trait aspire les ennemis proches sur sa ligne, l'arrivée souffle tout. +4 m d'élan", "v": [4]},

	# ---------------------------------------------------------------- OMBRE
	"shadow_back": {"school": "shadow", "rarity": "common", "name": "Ushiro",
		"text": "Dans le dos : dégâts ×{v}", "v": [2.0, 2.5, 3.0]},
	"shadow_step": {"school": "shadow", "rarity": "common", "name": "Pas d'ombre",
		"text": "Après une esquive : intouchable {v} s", "v": [0.5, 0.8, 1.1]},
	"shadow_veil": {"school": "shadow", "rarity": "common", "name": "Voile",
		"text": "2 ennemis d'un trait : intouchable {v} s", "v": [0.6, 0.9, 1.2]},
	"shadow_execute": {"school": "shadow", "rarity": "rare", "name": "Kaishaku", "kanji": "斬",
		"text": "Achève d'un coup les ennemis sous {v} % de vie", "v": [20, 25, 30]},
	"shadow_utsusemi": {"school": "shadow", "rarity": "epic", "name": "Utsusemi", "kanji": "逃",
		"text": "{v} coup(s) par salle ne frappe(nt) qu'une mue d'ombre, qui riposte ({w} dégâts)", "v": [1, 1, 2], "w": [1.5, 2.5, 2.5]},
	"shadow_stolen": {"school": "shadow", "rarity": "epic", "name": "Instant volé",
		"text": "Combo de 4 : le temps ralentit {v} s", "v": [0.8, 1.0, 1.2]},
	"shadow_bunshin": {"school": "shadow", "rarity": "legendary", "name": "Kage Bunshin", "kanji": "幻", "max": 1,
		"text": "Un clone d'ombre refait chacun de tes traits juste derrière toi", "v": [1]},
	"shadow_kitsunebi": {"school": "shadow", "rarity": "legendary", "name": "Kitsunebi", "kanji": "狐", "max": 1,
		"text": "Trois feux de renard tournent autour de toi et brûlent ce qu'ils touchent", "v": [3]},

	# ---------------------------------------------------------------- ENCRE (sans école)
	"ink_daruma": {"school": "ink", "rarity": "common", "name": "Daruma",
		"text": "+1 vie max et soin de {v}", "v": [1, 1, 2]},
	"ink_omamori": {"school": "ink", "rarity": "rare", "name": "Omamori",
		"text": "Raretés plus généreuses (+{v} %) et +1 relance", "v": [30, 60, 90]},
	"ink_rakkan": {"school": "ink", "rarity": "epic", "name": "Rakkan", "max": 1,
		"text": "Ton sceau compte +1 dans chaque affinité déjà commencée", "v": [1]},
	"ink_enso": {"school": "ink", "rarity": "legendary", "name": "Ensō parfait", "kanji": "円", "max": 1,
		"text": "Chaque forme lance une onde d'encre. L'ensō frappe double, plus large, et soigne", "v": [2]},
	"ink_ippitsu": {"school": "ink", "rarity": "legendary", "name": "Ippitsu", "kanji": "筆", "max": 1,
		"text": "Chaque coup d'un trait frappe +25 % de plus. Un trait de 4 coups double le suivant", "v": [25]},
}
