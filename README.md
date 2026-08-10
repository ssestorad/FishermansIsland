# Fisherman's Island

A pixel-art, Stardew Valley-styled idle desktop game. Fishermen live on an island, autonomously walking to the dock to fish, and are upgraded and expanded by the player over time.

## Status

Early prototype in Godot 4.7. Fishermen are currently placeholder squares that walk to the dock, wait a variable amount of time, roll a fish rarity, and walk back home to rest before repeating.

## Tech stack

- [Godot 4.7](https://godotengine.org/) (GDScript)

## Running the project

Open this folder as a project in the Godot editor, then run the `Main` scene (`scenes/main/Main.tscn`).

## Project structure

- `scenes/` — Godot scenes
- `scripts/` — GDScript source
- `assets/` — sprites and tilesets (pixel art, not yet added)

## Fish catalog

The catalog (`scripts/fish_catalog.gd`) is generated, not hand-written: each rarity tier
has 5 adjectives and 5 base names, combined into 25 species per tier (5x5), for 150
species total across the 6 tiers. A handful of extra species are layered on top with
catch conditions tied to the world clock (`scripts/world_clock.gd`).

### Generated species (5 adjectives x 5 base names per tier)

| Tier | Adjectives | Base names |
|---|---|---|
| Common | Common, Small, Grey, Plain, River | Minnow, Sardine, Gudgeon, Bream, Roach |
| Uncommon | Spotted, Striped, Silver, Pond, Creek | Perch, Carp, Trout, Chub, Rudd |
| Rare | Golden, Shadow, Deep, Amber, Coral | Bass, Pike, Catfish, Eel, Grayling |
| Epic | Crimson, Storm, Glacial, Obsidian, Radiant | Salmon, Sturgeon, Barracuda, Marlin, Tarpon |
| Legendary | Ancient, Celestial, Phantom, Runic, Eternal | Swordfish, Anglerfish, Manta Ray, Moray Eel, Nautilus |
| Mythic | Abyssal, Void, Cosmic, Primordial, Draconic | Leviathan, Kraken, Siren, Behemoth, Wyrm |

Each species is named `"<Adjective> <Base name>"` (e.g. "Golden Bass", "Void Kraken").

### Exclusive species (catch conditions)

These don't follow the naming grid above and can only be rolled when their condition
is met — otherwise they're excluded from that tier's roll pool entirely.

| Species | Tier | Condition |
|---|---|---|
| Frostbound Wyrm | Mythic | Weather is Blizzard |
| Bloomtail Carp | Legendary | Season is Spring |
| Sunscale Marlin | Legendary | Season is Summer |
| Harvest Salmon | Legendary | Season is Autumn |
| Icebound Sturgeon | Legendary | Season is Winter |

Blizzard is itself a rare weather type that can only occur during Winter (see below),
so the Frostbound Wyrm is effectively a "rare weather within a rare season" catch.

### World clock (weather, day/night, seasons)

`scripts/world_clock.gd` drives four nested cycles. Current durations are short
placeholders for testing — the original design target is day/night = 20 real minutes,
season = 1 real hour, weather = 5 real minutes.

| Weather | Chance | Luck bonus | Speed bonus |
|---|---|---|---|
| Sunny | 40% | — | — |
| Rainy | 25% | +0.05 | — |
| Foggy | 20% | +0.05 | −0.05 |
| Stormy | 12% | +0.15 | −0.15 |
| Blizzard | 3%, Winter only | +0.25 | −0.20 |

| Season | Luck bonus | Speed bonus | Power bonus |
|---|---|---|---|
| Spring | +0.10 | — | — |
| Summer | — | +0.10 | — |
| Autumn | — | — | +0.10 |
| Winter | +0.15 | −0.10 | — |

Weather and season bonuses stack with each other and with a fisherman's own
level-derived stats and equipped gear.
