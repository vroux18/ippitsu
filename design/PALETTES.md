# Ippitsu — palettes des huit mondes

*9 octobre 2026. Référence pour `scripts/worlds.gd` (WORLDS, floor_look, water_style), `arena.gd` (ponts, haies), `hazards.gd` (trous), `puzzle_art.gd` (pierre des énigmes).*

## Règles communes

- **Hiérarchie de contraste** : le trait d'encre (sumi / blanc) et les disques d'annonce (vermillon `#D7372B`, écume `#E9EEF0` au flash) sont toujours les éléments les plus contrastés de l'image. Donc : aucun sol rouge, orange ou blanc pur ; aucun émissif chaud hors des dangers ; les flammes de décor sont **ambre-or** (`#D9A64A`, cœur `#FFE2A0`), jamais orange.
- **Sol** : saturation et valeur moyennes (albédo entre 0,35 et 0,65 de luminance ; la lumière du monde l'éclaircit d'un tiers environ). Les ennemis sont sumi + masque washi + étoffes bleu de Prusse : le sol n'est jamais sumi, washi ni Prusse.
- **Six couches** (AUDIT_2026-10-09) : sol / bordure (liseré sumi, flanc = sol assombri, bois de pont teinté par la clé `bridge_wood`) / vide (`water_style`) / repères (sumi + or : torii de sortie, haies) / fond lointain (seule couche où le vermillon est permis) / props (palette du monde).
- **Harmonie avec l'UI** (`design/ui_v2/tokens/theme.json`) : les sols sont des voisins désaturés de washi, sumi et des couleurs d'élément ; le vermillon et l'or de l'interface ne sont jamais repris tels quels au sol ni sur les props.
- **Progression** : 1 clair → 2 sombre → 3 très clair → 4 sombre chaud → 5 clair neutre → 6 moyen → 7 moyen-sombre → 8 le plus sombre. Jamais deux mondes consécutifs dans la même famille (ocre / vert-bleu nuit / bleu glace / cendre chaude / papier / vert / sarcelle / violet-gris).

## Monde 1 — Grande Vague (jour, mer calme)

| Rôle | Hex | Justification |
|---|---|---|
| Sol (planches) | `#AE9B76` ±, alt `#8E7A58` | sable mouillé de la bible : l'hinoki doré d'avant criait et saturait l'image |
| Flanc / bordure | `#4A3E33` / sumi | bois mouillé sous le ponton |
| Vide (mer) | `#142A48` → `#24466E`, écume `#E2E8EA` | bleu de Prusse de l'estampe, seigaiha au large |
| Props | hinoki pâle `#CDB78E`, pieux `#4A3A2E`, bannières `#2E4A6B` | port de pêche, tissus indigo |
| Fond | ciel washi, soleil vermillon, Fuji `#3F5878` | *Sous la vague* : le seul vermillon est le soleil du premier jour |
| Lumière | soleil `(1.0, 0.92, 0.8)` 0,66 ; ambiance `(0.86, 0.9, 1.0)` 0,3 | aube claire, ombres bleutées |
| Accent | planche de laque `#4A5A72` (rare), pétales rose |  |

## Monde 2 — Tanabata (nuit, bambouseraie, feux de renards)

| Rôle | Hex | Justification |
|---|---|---|
| Sol (dalles) | `#747A6C` ±, alt `#5E6A5A`, mousse `#3E5A40` | pierre tiède sous la lune : plus claire que l'étang et moins verte que les bambous |
| Flanc / bordure | `#363E34` / `#1E2420` |  |
| Vide (étang) | `#0F1D1A` → `#1E3630`, écume `#8FAE9C` | eau noire de la nuit d'Ōji |
| Végétation | bambou `#5E7F4A`, jade pâle `#A3B07A`, tanzaku pastel | bible |
| Fond | ciel `#2E3B4E` → `#121A26`, lune `#F4ECD2`, torii lointains `#6E2420` | nuit des étoiles |
| Lumière | lune `(0.76, 0.84, 1.0)` 0,52 ; ambiance `(0.58, 0.68, 0.86)` 0,52 | nuit lisible, pas noire |
| Accent | feu de renard `#F1E3A6`, bavoir des renards `#6E2A24` (braise sombre) | or pâle, pas de vermillon |

## Monde 3 — Cent Contes (neige, temple)

| Rôle | Hex | Justification |
|---|---|---|
| Sol (neige) | `#CBD3DC` ±, alt `#B0BAC8` | neige bleutée, jamais blanche : le blanc reste à l'écume des annonces et aux masques |
| Flanc / bordure | gris lavande `#8C8FA8` / `#3A3A48` | ombres sur la neige (bible) |
| Vide (étang gelé) | `#22324A` → `#3A4E66`, écume `#DCE6EE` |  |
| Props | pierre `#8F8E92`, bonnets `#2E3446`, lanternes `#F6D58A` | jizō à bonnet sombre |
| Fond | ciel `#D3D9E2` → `#6F7896`, soleil pâle rosé | *Neige sur la Sumida* |
| Lumière | `(0.95, 0.97, 1.0)` 0,48 ; ambiance `(0.78, 0.84, 0.95)` 0,36 | baissée pour que la neige ne sature plus |
| Accent | bleu de Prusse (bandes des haies), or pâle des tōrō |  |

## Monde 4 — Fuji Rouge (feu, faille)

| Rôle | Hex | Justification |
|---|---|---|
| Sol (basalte) | cendre `#5E5753` ±, alt `#44403C`, fissures d'encre `#2A2422` | `#5A5550` de la bible, remonté pour les silhouettes sumi ; plus de veines d'or au sol |
| Flanc / bordure | `#2A2220` / `#141215` |  |
| Vide (lave) | sumi `#16100F` → `#2A1C18`, veines or `#C49A45` | « sumi + veines or » : l'orange d'avant concurrençait les annonces |
| Props | basalte `#3A3433`, fer `#3B3A3E`, braise `#8E2A1E` (masques), flammes ambre `#D9A64A` | aucun émissif orange |
| Fond | ciel Prusse, Fuji `#B5502F`, nuages écailles washi | *Gaifū kaisei* : le rouge reste au fond |
| Lumière | `(1.0, 0.8, 0.62)` 0,72 ; ambiance `(0.92, 0.74, 0.64)` 0,3 | chaud mais pas orange |
| Accent | or `#C49A45` (lave, haies, repères) |  |

## Monde 5 — Trente-six Vues (encre, papier, Fuji)

| Rôle | Hex | Justification |
|---|---|---|
| Sol (papier) | `#AFA796` ±, alt `#A39A88` | papier vieilli ; lumière baissée pour qu'il ne blanchisse plus |
| Flanc / bordure | `#3A3530` / sumi |  |
| Vide (encre) | `#0E1A2E` → `#1B2A44`, écume papier `#CFC6B2` | indigo nuit de la bible |
| Props | papier `#F1E8D6`, pinceaux sumi, sceau `#9E3028` | le sceau du peintre reste le seul rouge, assombri |
| Fond | rose aube `#E4B7B0`, ensō sumi, donjon washi | |
| Lumière | `(1.0, 0.9, 0.84)` 0,6 ; ambiance `(0.98, 0.9, 0.9)` 0,32 | |
| Accent | rose aube (rare) |  |

## Monde 6 — Kurama (montagne des tengu, brume verte)

| Rôle | Hex | Justification |
|---|---|---|
| Sol (granit) | `#8A8873` ±, alt `#6A6A58`, mousse `#4A6440` | plus clair et plus chaud que le ravin : avant, sol, eau et props étaient du même vert |
| Flanc / bordure | `#3E4634` / `#1A1E1A` |  |
| Vide (ravin) | `#101C14` → `#22352A`, écume `#9CB08E` |  |
| Végétation | cèdre `#2E4A34` / `#3A5A40`, mousse `#3E5A3A`, fougère `#4F6E3E` |  |
| Fond | brume `#D9DDC8` → `#6E8278`, temple `#9A3324` | le temple vermillon reste au fond |
| Lumière | `(0.98, 0.96, 0.86)` 0,62 ; ambiance `(0.74, 0.86, 0.74)` 0,4 |  |
| Accent | braise `#8E2A1E` (masques de tengu, lanternes, bandes des haies) | à la place de `#D9573F` |

## Monde 7 — Ryūgū-jō (fond marin)

| Rôle | Hex | Justification |
|---|---|---|
| Sol (dalles) | nacre `#9E9A88` ±, alt algue `#7E8A80`, mousse `#3E6E66` | la laque rouge d'avant se confondait avec les annonces ; plus de laque dorée au sol |
| Flanc / bordure | `#2A3A3E` / `#14181C` |  |
| Vide (eau) | `#082A33` → `#145060`, écume `#9EE0DA` | turquoise profond |
| Props | corail rose `#C86E7E`, pêche `#D9A078`, mauve `#9A5C86`, sable `#E0C27A` ; varech `#4E6E3A` ; colonnes laque sombre `#6E2A28` + nacre `#E7D9C8` | plus de corail vermillon ni de piliers rouge et or près de l'arène |
| Fond | palais vermillon `#B8452E` + or, perle de lumière | le palais garde ses couleurs au fond |
| Lumière | `(0.8, 0.96, 0.94)` 0,58 ; ambiance `(0.6, 0.9, 0.92)` 0,48 |  |
| Accent | perle `#F4F1EA`, reflets turquoise |  |

## Monde 8 — Yomi (cendre)

| Rôle | Hex | Justification |
|---|---|---|
| Sol (dalles) | cendre `#625F64` ±, alt `#524E56` | gris désaturé : le lilas des âmes est la seule couleur vive |
| Flanc / bordure | `#28242C` / `#0E0C10` |  |
| Vide (fleuve) | `#0D0A13` → `#1E1826`, écume `#7E70A0` |  |
| Props | cendre `#6E6A70`, os `#D8D2C4`, lanternes `#D9D0E6` |  |
| Fond | violet-noir `#5A4A66` → `#120E18`, lune pâle |  |
| Lumière | `(0.8, 0.76, 0.94)` 0,52 ; ambiance `(0.66, 0.6, 0.84)` 0,46 |  |
| Accent | lilas `#B9A8E8` (âmes, glints, haies `#5A3A7A`) |  |

## Bois des ponts (`bridge_wood`, trois teintes par monde)

| Monde | Teintes | |
|---|---|---|
| 1 | `#8E6B3E` `#A88452` `#7A5A34` | hinoki brut du port |
| 2 | `#8A8A5A` `#9C9A68` `#6E6E48` | bambou vieilli |
| 3 | `#8C7A62` `#A08E74` `#6E5E4A` | bois givré |
| 4 | `#4A3A30` `#5C4A3C` `#3A2E26` | bois brûlé |
| 5 | `#5A544C` `#6E685E` `#44403A` | bois lavé d'encre |
| 6 | `#7A4A34` `#8E5A40` `#5E3A28` | cèdre rouge |
| 7 | `#6E6A58` `#82806C` `#585646` | bois flotté |
| 8 | `#4A464E` `#5A565E` `#3A363E` | bois de cendre |

## Trous (`hazards.gd` HOLE_STYLES)

Allure par monde : planches (1), dalles (2, 6, 7, 8), glace (3), lave sumi + or (4), encre (5). Les mondes 6 à 8 ont leur propre palette de dalles (granit moussu, nacre sur eau turquoise, cendre sur fleuve violet).
