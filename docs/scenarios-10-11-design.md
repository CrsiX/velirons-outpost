# Scenarios 10 and 11: the finale

Part of the scenario design; index in scenarios-design.md. Numbers, waves, texts and tile coordinates live in `scripts/scenarios/scenario_10.gd` and `scenario_11.gd`. Cutscene dialogue is not copied here.

Both scenarios are the Dread Legion's: Rhodri's bound soldiers (`story-design.md`) come in force, every other monster category joins them, and the hero cannot be revived. Riders: `enemies-design.md` §15e has the rules. The campaign reason for the cavalry is only that the Legion is an army with horse; each scenario shows a hint that halberdiers are the answer.

## Scenario 10: The Last Wardline

**Story and intent.** Home, at its strongest, on the scenario 3 map. The village sided with no one in scenario 1; now it stands with Fiona, as Brenna does, and the Legion comes because of it. The restored Wardline, built to keep the wilderness out, has to hold against the kingdom's own bound soldiers. Brenna chooses to stay and defend rather than chase Rhodri, and she is the one who cannot be revived and cannot leave her post: that is the point of the scenario.

Beats:
- Intro on the home wall at dusk, the horizon full of torches: Brenna names the captains out there, Lysa and Torben, and vows to free them.
- Her father Einar greets her cheerfully as if nothing were wrong: a small warm beat before the fight, a gimmick. Whether he lives is not tracked.
- Lothar rides up under a white flag with one more demand for surrender. It is a choice, and opening the gates loses.
- Fiona is absent (she prepares something, not said) but sends her mages one wave later; they join the player's reserve.
- Torben and Lysa lead later waves and fall back when beaten. The last wave is **Halvard's**, the Legion's marshal, with both of them.
- Outro: the legion stopped, the dying marshal thanks Brenna; a messenger says Fiona, the priests and the mages ride for the capital.

**Why it is built this way.**
- *Everything is already restored.* The baseline reuses scenario 3's ruins (every Wardline tower and the barracks, plus the home ruin), restored and manned at the start, so the player sees what the tech tree gives late. The units are a mix of branches (crossbow, swiftbow, warrior, halberdier, berserker, inquisitor, high priest, fire summoner) for the same reason. A prebuilt post can therefore be a restored ruin (`"ruin": i`, counted nearest the village first); this is the first scenario to need it.
- *Enemies come by every road at once and the economy is stretched,* so the pressure is defence in breadth, not a single chokepoint.
- *Halvard is a commander,* a new Legion kind: soldiers near him strike faster and take less damage, and while he lives he rallies fresh footmen down the roads. That makes killing him early matter instead of a long slog against his escort. He can be killed (released like any Legion soldier), unlike Rhodri.
- *Guild caravans* come down the Wardline road at fixed waves, because Brenna restored that road. They halt while enemies are near and pay at the gate. Enemies leave them alone on purpose: the test is defending the road, not losing the cart to bad luck.
- *Reinforcements* (Fiona's mages) are given as units into the reserve (`ScenarioRunner.give_units`), so the player still decides where they stand.
- Pell must not die; the hero's downing is a defeat even at home.

## Scenario 11: The Crown

**Story and intent.** The end of the war and its cost. The crown breaks, but the curse does not die with it; the spies' origin (the "goldsmith") stays unsolved, and what comes after is left open. There is no branching.

Setting: the capital's throne hall district, a city of cobbles and standing and ruined houses. The vegetation is gone (ash land, a few steppe spots where trees grow), so there are **no farms**: food comes only from caravans and Pell's stall. Brenna's and Fiona's forces hold a final camp with the village's walls half broken; Fiona is at home in her house and not under the player's control (her death is a defeat), and her mages man the towers, bound to them.

Beats:
- Intro: Brenna gives Fiona the First King's Hand; cut to Rhodri on his throne with the crown, a pale court around him, smiling.
- Rhodri speaks to Brenna during the fight and shows what is left of him.
- In the last wave Rhodri comes out with Lothar, the last of the court to fall (his last need in the story). At 0 HP Rhodri is not killed: he is downed and flees into the throne hall, where he is alone.
- Win: when the last wave is over and Rhodri beaten, the victory sound plays and the outro runs. Fiona confronts him; for a moment he is himself; she beheads him with the Hand; the crown breaks, the curse spreads through the hall and into her, her eyes turn black. End of campaign.

**Why it is built this way.**
- *A new zone, not a new map type:* the city (cobbles, houses standing where a zone's mountain tiles would be) is hand-made, never generated, and the generator stays out of it. Cobbles forbid farms. The map format grew a version for it, and the tidy-up and editor know the zone's house tiles.
- *The throne hall is a landmark:* a campaign treasure that can never be looted, so it is a place on the map for the story, not a reward.
- *Rhodri is a commander with a cleave, and is downed rather than killed:* the campaign's last boss must not die to a stray arrow; nothing can target him once downed, and he falls back along his road and is gone. He has two phases (mounted, then on foot once his horse falls).
- *A food cart after every wave but the last* comes down the road farthest from the throne hall, away from the fight, because there is no other income of food.
- *No worker camp at the start:* no trees stand by the walls, so the player must choose a grove; a card teaches it.
- Fiona's mages are bound (no orders), which keeps the finale about Brenna's army and the player's placement.

## What 10 and 11 added to the engine

- Commanders (`CommanderBehavior`): an aura for Legion soldiers, a rally, and the king's `"downed"` retreat (he keeps 1 HP, is untargetable, falls back faster than he came and vanishes at the road's end with no release). The strongest banner or commander counts, with no stacking.
- A restored ruin as a prebuilt post; reinforcement units into the reserve.
- Scripted caravans (`ScenarioCaravan`): they halt when an enemy comes near and go on only once it is farther off (hysteresis), so a cart does not stutter at the edge.
- The city zone with its own `"peaks"` houses, and landmark treasures.
- The `curse` burst and the portraits of Halvard and the cursed Fiona.
- `tools/make_scenario_map.gd` builds the city. Scenario 10's map is scenario 3's file, hand-edited: see `.claude/rules/scenarios-and-maps.md` and the edit-handmade-map skill before touching it.
