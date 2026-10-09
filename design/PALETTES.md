# Ippitsu — palettes des huit mondes

*9 octobre 2026. Référence pour `scripts/worlds.gd` (WORLDS, floor_look, water_style), `arena.gd` (ponts, haies), `hazards.gd` (trous), `puzzle_art.gd` (pierre des énigmes).*

## Règles communes

- **Hiérarchie de contraste** : le trait d'encre (sumi / blanc) et les disques d'annonce (vermillon `#D7372B`, écume `#E9EEF0` au flash) sont toujours les éléments les plus contrastés de l'image. Donc : aucun sol rouge, orange ou blanc pur ; aucun émissif chaud hors des dangers ; les flammes de décor sont **ambre-or** (`#D9A64A`, cœur `#FFE2A0`), jamais orange.
- **Sol** : saturation et valeur moyennes (albédo entre 0,35 et 0,65 de luminance ; la lumière du monde l'éclaircit d'un tiers environ). Les ennemis sont sumi + masque washi + étoffes bleu de Prusse : le sol n'est jamais sumi, washi ni Prusse.
- **Six couches** (AUDIT_2026-10-09) : sol / bordure (liseré sumi, flanc = sol assombri, bois de pont teinté par la clé `bridge_wood`) / vide (`water_style`) / repères (sumi + or : torii de sortie, haies) / fond lointain (seule couche où le vermillon est permis) / props (palette du monde).
- **Harmonie avec l'UI** (`design/ui_v2/tokens/theme.json`) : les sols sont des voisins désaturés de washi, sumi et des couleurs d'élément ; le vermillon et l'or de l'interface ne sont jamais repris tels quels au sol ni sur les props.
- **Progression** : 1 clair → 2 sombre → 3 très clair → 4 sombre chaud → 5 clair neutre → 6 moyen chaud (crépuscule) → 7 moyen-sombre froid (grand fond) → 8 le plus sombre. Jamais deux mondes consécutifs dans la même famille (ocre / vert-bleu nuit / bleu glace / cendre chaude / papier / rose-orangé et violet / outremer et sable / violet-gris). Le vert est réservé au monde 2 (bambous, nuit) : les mondes 6 et 7 n'en ont plus que des touches (fougères, varech).

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

## Monde 6 — Kurama (montagne des tengu au crépuscule)

*Deuxième passe (9 octobre, soir) : après la première passe, 6 et 7 se ressemblaient (dominante verte / sarcelle, sol clair verdâtre). Kurama devient une **fin de jour en montagne** : ciel orangé-violet, cèdres bleu-noir en contre-jour, brumes mauves, sol de granit rose-gris jonché d'aiguilles rousses, lanternes braise. Plus aucun vert dans la lumière ni au sol : la famille « vert » est laissée au monde 2.*

| Rôle | Hex | Justification |
|---|---|---|
| Sol (granit) | `#7E7270` ±, alt `#6A5A5A`, aiguilles dans les joints `#7E5A3E` (`moss_k` 0,4) | granit rose-gris, valeur moyenne ; prend la lumière chaude du soir sans virer au rose bonbon (la première valeur `#847472` était trop rose) |
| Flanc / bordure | `#3A2E38` / `#14121A` | ombre violette du ravin |
| Vide (ravin) | `#0A0C18` → `#1A2036`, brume `#B4A0B4`, pas de seigaiha | bleu-noir du soir, brumes mauves qui s'accrochent aux berges |
| Végétation | cèdres `#222A3A` / `#2C3A4C` (bleu-noir), litière d'aiguilles `#6E4A34` (`NEEDLES`, îlots et socles), fougères rousses `#8A6236` | contre-jour : les cèdres sont des silhouettes froides, le sol et la litière sont chauds |
| Roche | granit `#6A5E66` (`KURAMA_ROCK`), rocher sacré `#76686E`, falaise `#5E5260`, poteaux `#4A3E48` | plus de roche vert-de-gris |
| Fond | ciel `#E8B07A` → `#C88A86` → `#4A3A66`, soleil couchant `#F2C27A` / `#E8A860`, chaînes `#5A4C70` → `#1C1A2C`, brumes `#E6C0B4` / `#B894A0`, temple `#9A3324`, escalier `#7A6E74` | l'orangé et l'or restent au ciel et au soleil (fond lointain) ; le temple vermillon reste au fond |
| Lumière | soleil `(1.0, 0.86, 0.7)` 0,58 ; ambiance `(0.66, 0.6, 0.8)` 0,4 ; brouillard `#9A7E8E` 0,0036 | soleil bas et chaud, ombres violettes : complémentaires |
| Accent | braise `#8E2A1E` (masques de tengu, lanternes de papier, bandes des haies) ; lucioles de l'arche `#F2C288` ; aiguilles qui tombent `#8A5E3A` / `#A8804C` / `#5E3E2A` | ambre et braise, jamais le vermillon des annonces |
| Fosses | parois `#5E5054`, fond `#0C0E1C`, reflets `(1.0, 0.84, 0.66)` ; trous (hazards) liseré mauve `#6A5478`, lèvre `#A89896` |  |
| Énigmes | pierre `#8A7A78`, aiguilles `#7E5A3E`, galets `#8C7C7A` |  |

## Monde 7 — Ryūgū-jō (grand fond, palais du roi dragon)

*Deuxième passe : la mer n'est plus sarcelle claire mais **outremer sombre** ; le parvis est de bois flotté et de sable nacré chaud ; les coraux rose / pêche / mauve sont les seuls accents. Lumière de surface froide (ambiance, perles, lanternes, caustiques) sur un sol chaud : complémentaires. Le soleil est resté presque neutre : avec un soleil bleu, le sable virait au gris-blanc.*

| Rôle | Hex | Justification |
|---|---|---|
| Sol (planches de bois flotté) | `#A69070` ±, alt `#8A7858`, algue bleue dans les joints `#4E6E7E` (`moss_k` 0,2) | sable nacré chaud (`#B8A88C` du brief, baissé pour rester en valeur moyenne sous une lumière qui l'éclaircit) ; le seul sol chaud sur une eau froide |
| Flanc / bordure | `#2A3052` / `#0C1024` | indigo |
| Vide (eau) | `#060C24` → `#0C1A3E`, caustiques `#7AA0CC`, seigaiha 0,26 | outremer presque noir : le parvis clair flotte dessus ; les deux premières valeurs (`#0A1640`, `#081230`) rendaient un bleu roi trop vif |
| Props | corail rose `#C86E7E`, pêche `#D9A078`, mauve `#9A5C86`, sable `#E0C27A` ; varech `#3A5E4A` / `#5A7A50`, herbes `#3E6650` ; roche du récif `#2E3A5A` (`REEF_ROCK`) ; colonnes laque sombre `#6E2A28` + nacre `#E7D9C8` ; buttes de sable `#C4B094` | la roche prend l'indigo de l'eau, les coraux restent les seules couleurs vives |
| Fond | eau `#0C1A44` → `#16306E` → `#4A80B8` (plus claire vers la surface), perle `#F4F1EA`, chaînes `#122A5E` → `#0A1636`, mont de corail cime `#C87A86`, palais laque sombre `#7A2E34` / `#6E2A30` + toits d'or `#C49A45` + fenêtres de nacre, rayons `(0.75, 0.9, 1.0)` | plus de palais vermillon : laque sombre et nacre, l'or reste au fond |
| Lumière | soleil `(0.98, 0.96, 0.9)` 0,54 ; ambiance `(0.48, 0.58, 0.9)` 0,44 ; brouillard `#24427A` 0,005 ; perles et lanternes `(0.62, 0.82, 1.0)` (`CAUSTIC`) | ambiance et lumières ponctuelles froides, soleil neutre |
| Accent | perle `#F4F1EA`, bulles `(0.8, 0.9, 1.0)`, plancton `(0.6, 0.82, 1.0)` / `(1.0, 0.94, 0.72)`, bulles de l'arche `#BFE0FF`, bannières `#1E2E5A` + or |  |
| Fosses | parois `#706858`, fond `#0A1838`, reflets `(0.7, 0.86, 1.0)` ; trous (hazards) liseré `#4E8AC8`, lèvre `#C8BCA0` |  |
| Énigmes | pierre `#AE9E84`, algue `#4E6E7E`, galets `#A89C86` |  |
| Accueil | socles `#4E5A6E`, tours de porte laque sombre + tuiles indigo `#2E4A66` + or |  |

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
| 7 | `#8A8270` `#9C9480` `#6E6858` | bois flotté blanchi |
| 8 | `#4A464E` `#5A565E` `#3A363E` | bois de cendre |

## Trous (`hazards.gd` HOLE_STYLES)

Allure par monde : planches (1), dalles (2, 6, 7, 8), glace (3), lave sumi + or (4), encre (5). Les mondes 6 à 8 ont leur propre palette de dalles (granit rose-gris sur le ravin bleu-noir du soir, bois flotté et sable sur l'outremer, cendre sur fleuve violet).
