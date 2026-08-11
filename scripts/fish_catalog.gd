class_name FishCatalog
extends RefCounted

## The hand-authored species roster.
##
## Every fish is written out rather than generated from adjective x noun
## lists, so each one can carry its own habitat, silhouette, weight band,
## value, odds and flavour text. Entries are grouped by habitat below,
## which is also how the game surfaces them in the Album — adding a new
## species means appending one line to the right habitat block, and the
## per-tier indexes rebuild themselves from that.
##
## Keys, kept short because there are a lot of rows:
##   n  name          t  tier name (see FishRarity.NAMES)
##   h  habitat       m  atlas model index (tools/generate_fish_sprites.py)
##   w  [min, max] kg v  base value    d  flavour line
##   pick     relative odds within its tier (default 1.0)
##   weather / season / night   optional gating, see FishSpecies

## Habitats in the order the Album lists them: roughly home waters first,
## then further out and stranger.
const HABITATS := [
	"Reedbeds",
	"River Bend",
	"Harbour",
	"Kelp Forest",
	"Coral Shallows",
	"Open Water",
	"Storm Front",
	"Ice Shelf",
	"The Deep",
	"Sunken Ruins",
]

const SPECIES := [
	# --- Reedbeds (13) -------------------------------------------------
	# Still, shallow, weed-choked water right off the island. The gentlest
	# fishing on the map and where most careers start.
	{"n": "Silver Minnow", "t": "Common", "h": "Reedbeds", "m": 0, "w": [0.1, 0.5], "v": 1, "d": "Moves in nervous clouds that scatter at a shadow and regroup a moment later."},
	{"n": "Mud Roach", "t": "Common", "h": "Reedbeds", "m": 1, "w": [0.3, 1.2], "v": 1, "d": "Tastes of the bottom it grubs in. Nobody's favourite, but always there."},
	{"n": "Reed Rudd", "t": "Common", "h": "Reedbeds", "m": 5, "w": [0.4, 1.6], "v": 2, "d": "Red-finned and lazy, holding station between the stems until something edible drifts past."},
	{"n": "Bitterling", "t": "Common", "h": "Reedbeds", "m": 0, "w": [0.1, 0.4], "v": 1, "d": "Barely a mouthful. Lays its eggs inside living mussels and lets them do the raising."},
	{"n": "Pond Bream", "t": "Common", "h": "Reedbeds", "m": 4, "w": [0.8, 2.6], "v": 2, "d": "A flat bronze plate of a fish that feeds head-down, tail waving above the weed."},
	{"n": "Marsh Gudgeon", "t": "Common", "h": "Reedbeds", "m": 3, "w": [0.2, 0.8], "v": 1, "d": "Whiskered and speckled, walking the silt on stiff little fins."},
	{"n": "Stickleback", "t": "Common", "h": "Reedbeds", "m": 0, "w": [0.1, 0.3], "v": 1, "d": "Tiny, armoured and absurdly aggressive. The males turn scarlet and pick fights with everything."},
	{"n": "Green Tench", "t": "Uncommon", "h": "Reedbeds", "m": 9, "w": [1.2, 4.0], "v": 4, "d": "Thick-set and slime-coated. Old fishermen swear other fish rub against it to heal."},
	{"n": "Crucian Carp", "t": "Uncommon", "h": "Reedbeds", "m": 9, "w": [1.0, 3.5], "v": 4, "d": "Survives water nothing else will. Freeze the pond solid and it simply waits."},
	{"n": "Reed Perch", "t": "Uncommon", "h": "Reedbeds", "m": 8, "w": [0.8, 3.0], "v": 5, "d": "Striped like the stems it hunts from. Ambushes anything smaller than its own head."},
	{"n": "Marbled Loach", "t": "Uncommon", "h": "Reedbeds", "m": 21, "w": [0.3, 1.0], "v": 4, "d": "Rises to gulp air before a storm, which is how the reed-cutters read the weather.", "pick": 0.7},
	{"n": "Bronze Bream", "t": "Rare", "h": "Reedbeds", "m": 4, "w": [3.0, 7.5], "v": 10, "d": "A bream that outlived every heron on the marsh and grew broad enough to prove it."},
	{"n": "Reedwitch Pike", "t": "Rare", "h": "Reedbeds", "m": 14, "w": [4.0, 11.0], "v": 12, "d": "Hangs motionless among the stems like a submerged branch, right up until it isn't.", "pick": 0.6},

	# --- River Bend (17) -----------------------------------------------
	# Moving freshwater: gravel runs, undercut banks and deep slow pools.
	{"n": "River Dace", "t": "Common", "h": "River Bend", "m": 2, "w": [0.2, 0.7], "v": 1, "d": "Holds in the fast water and lets the current bring lunch to it."},
	{"n": "Stone Loach", "t": "Common", "h": "River Bend", "m": 21, "w": [0.1, 0.4], "v": 1, "d": "Spends the day wedged under a rock and the night walking the gravel on its barbels."},
	{"n": "Common Chub", "t": "Common", "h": "River Bend", "m": 6, "w": [0.6, 2.4], "v": 2, "d": "Will eat bread, beetles, cherries or a smaller chub. Suspicious of everything, eats it anyway."},
	{"n": "Gravel Bleak", "t": "Common", "h": "River Bend", "m": 2, "w": [0.1, 0.5], "v": 1, "d": "Flickers at the surface all afternoon, catching flies and the eye of every predator upstream."},
	{"n": "Barbel Fry", "t": "Common", "h": "River Bend", "m": 3, "w": [0.3, 1.1], "v": 2, "d": "Young and already built like a torpedo, nosing the gravel for anything the current uncovered."},
	{"n": "Spotted Minnow", "t": "Common", "h": "River Bend", "m": 0, "w": [0.1, 0.4], "v": 1, "d": "A thumb-length fish with a stripe that only shows when the light hits it right."},
	{"n": "Brown Trout", "t": "Uncommon", "h": "River Bend", "m": 7, "w": [0.8, 3.2], "v": 5, "d": "Butter-gold and freckled, holding in the seam where fast water meets slow."},
	{"n": "River Grayling", "t": "Uncommon", "h": "River Bend", "m": 17, "w": [0.7, 2.8], "v": 5, "d": "Sail-finned and silver. Called the lady of the stream by people who have never been bitten by one."},
	{"n": "Barbel", "t": "Uncommon", "h": "River Bend", "m": 30, "w": [2.0, 6.0], "v": 6, "d": "All shoulders and stubbornness. Hooking one is easy; landing it is a different afternoon."},
	{"n": "Bankside Eel", "t": "Uncommon", "h": "River Bend", "m": 18, "w": [1.0, 3.5], "v": 5, "d": "Comes out at dusk and ties itself in knots the moment you touch it.", "night": true},
	{"n": "Freshwater Bass", "t": "Uncommon", "h": "River Bend", "m": 15, "w": [1.2, 4.0], "v": 6, "d": "Sits in the shade of the undercut bank waiting for something careless."},
	{"n": "Golden Barbel", "t": "Rare", "h": "River Bend", "m": 30, "w": [4.0, 9.5], "v": 12, "d": "The old bend fish. Scarred, unhurried, and heavier every year the island counts."},
	{"n": "Pool Pike", "t": "Rare", "h": "River Bend", "m": 14, "w": [5.0, 13.0], "v": 14, "d": "Owns the deep pool below the willow and has done for longer than anyone remembers."},
	{"n": "Silver Salmon", "t": "Rare", "h": "River Bend", "m": 7, "w": [4.0, 10.0], "v": 15, "d": "Comes up from the sea once a year, burning through fat it will never replace.", "season": "Autumn"},
	{"n": "Moonlit Zander", "t": "Rare", "h": "River Bend", "m": 15, "w": [3.0, 8.5], "v": 14, "d": "Eyes like lamp glass. Hunts the black water on nights the moon does the work for it.", "night": true, "pick": 0.7},
	{"n": "River Sturgeon", "t": "Epic", "h": "River Bend", "m": 29, "w": [12.0, 30.0], "v": 34, "d": "Armoured in bony plates and older than the harbour. Swims the bend like it owns the deed."},
	{"n": "Great Wels", "t": "Epic", "h": "River Bend", "m": 30, "w": [15.0, 40.0], "v": 38, "d": "A catfish grown past reason in the deepest pool. Ducks have gone missing. So have oars.", "night": true, "pick": 0.7},

	# --- Harbour (14) --------------------------------------------------
	# The working water around the dock: pilings, ropes, spilled bait and
	# whatever the boats bring in with them.
	{"n": "Harbour Sprat", "t": "Common", "h": "Harbour", "m": 2, "w": [0.1, 0.4], "v": 1, "d": "Boils under the lamps at night, feeding on everything the day's cleaning washed off the deck."},
	{"n": "Dock Sardine", "t": "Common", "h": "Harbour", "m": 2, "w": [0.2, 0.6], "v": 2, "d": "Arrives in numbers that turn the water solid, then vanishes for a fortnight."},
	{"n": "Piling Blenny", "t": "Common", "h": "Harbour", "m": 3, "w": [0.1, 0.5], "v": 1, "d": "Lives in a bolt hole in the jetty and glares out at passers-by."},
	{"n": "Rope Goby", "t": "Common", "h": "Harbour", "m": 0, "w": [0.1, 0.3], "v": 1, "d": "Hides in the fenders. Comes out only when the mooring lines go slack."},
	{"n": "Tin Mackerel", "t": "Common", "h": "Harbour", "m": 2, "w": [0.4, 1.4], "v": 2, "d": "Striped like hammered metal and never still for a second."},
	{"n": "Slipway Flounder", "t": "Common", "h": "Harbour", "m": 36, "w": [0.5, 2.0], "v": 2, "d": "Lies in the silt off the ramp with both eyes on the same side of its head, watching."},
	{"n": "Bilge Carp", "t": "Common", "h": "Harbour", "m": 9, "w": [1.0, 3.0], "v": 2, "d": "Thrives on galley scraps. Tastes exactly as good as that sounds."},
	{"n": "Lamp Squid", "t": "Uncommon", "h": "Harbour", "m": 32, "w": [0.4, 1.8], "v": 5, "d": "Draws itself up to the deck lights after dark and turns the colour of the flame.", "night": true},
	{"n": "Harbour Sea Bass", "t": "Uncommon", "h": "Harbour", "m": 15, "w": [1.5, 5.0], "v": 7, "d": "Patrols the pilings at the turn of the tide, taking whatever the current dislodges."},
	{"n": "Mooring Conger", "t": "Uncommon", "h": "Harbour", "m": 19, "w": [2.0, 6.5], "v": 6, "d": "Lives under the stone quay. Every dockhand has an opinion on how big it really is."},
	{"n": "Copper Mullet", "t": "Uncommon", "h": "Harbour", "m": 6, "w": [1.0, 3.6], "v": 6, "d": "Grazes algae off the hulls in slow, unbothered circles."},
	{"n": "Anchor Ray", "t": "Rare", "h": "Harbour", "m": 28, "w": [4.0, 12.0], "v": 13, "d": "Settles over the old anchor chain until the silt makes it disappear entirely."},
	{"n": "Ballast Grouper", "t": "Rare", "h": "Harbour", "m": 12, "w": [6.0, 16.0], "v": 16, "d": "Took up residence in a scuttled hull and grew to fit the cabin."},
	{"n": "Ghost Net Eel", "t": "Rare", "h": "Harbour", "m": 18, "w": [3.0, 9.0], "v": 14, "d": "Threads a lost net every night without ever being caught by it.", "night": true, "pick": 0.6},

	# --- Kelp Forest (18) ----------------------------------------------
	# Cold green water and standing weed, thick enough to lose a boat in.
	{"n": "Kelp Blenny", "t": "Common", "h": "Kelp Forest", "m": 3, "w": [0.1, 0.5], "v": 2, "d": "Green as the fronds it clings to, right down to its eyes."},
	{"n": "Weed Pipefish", "t": "Common", "h": "Kelp Forest", "m": 25, "w": [0.1, 0.4], "v": 2, "d": "Hangs vertically among the stems and is missed by nearly everyone."},
	{"n": "Rock Wrasse", "t": "Uncommon", "h": "Kelp Forest", "m": 8, "w": [0.6, 2.4], "v": 5, "d": "Cracks shellfish against a favourite stone and returns to it for years."},
	{"n": "Kelp Perch", "t": "Uncommon", "h": "Kelp Forest", "m": 8, "w": [0.7, 2.6], "v": 5, "d": "Drifts nose-down between the stipes, pretending to be a piece of weed."},
	{"n": "Green Wrasse", "t": "Uncommon", "h": "Kelp Forest", "m": 10, "w": [0.8, 3.0], "v": 6, "d": "Changes sex when the largest male dies. The kelp forest sorts itself out."},
	{"n": "Frond Sole", "t": "Uncommon", "h": "Kelp Forest", "m": 36, "w": [0.6, 2.2], "v": 5, "d": "Flat, freckled and content to be stepped over."},
	{"n": "Otterfish", "t": "Uncommon", "h": "Kelp Forest", "m": 7, "w": [1.2, 4.2], "v": 7, "d": "Named for the way it rolls onto its back to work a shell loose."},
	{"n": "Kelp Garfish", "t": "Uncommon", "h": "Kelp Forest", "m": 25, "w": [0.8, 3.0], "v": 6, "d": "A needle with green bones. The bones put people off; the taste wins them back."},
	{"n": "Drifting Jellyfish", "t": "Uncommon", "h": "Kelp Forest", "m": 49, "w": [0.4, 1.8], "v": 6, "d": "Trails a curtain of stinging thread wherever the current decides to take it."},
	{"n": "Copper Kelpfish", "t": "Rare", "h": "Kelp Forest", "m": 6, "w": [2.5, 7.0], "v": 12, "d": "Turns rust-red in autumn when the forest starts to die back.", "season": "Autumn"},
	{"n": "Kelp Sculpin", "t": "Rare", "h": "Kelp Forest", "m": 11, "w": [2.0, 6.0], "v": 11, "d": "All head and spines. Swallows things nearly its own size and regrets nothing."},
	{"n": "Kelp Seahorse", "t": "Rare", "h": "Kelp Forest", "m": 48, "w": [0.05, 0.25], "v": 13, "d": "Anchors its curled tail to a stem of kelp and lets the whole forest sway around it."},
	{"n": "Weedbed Halibut", "t": "Rare", "h": "Kelp Forest", "m": 36, "w": [6.0, 15.0], "v": 16, "d": "A door-sized flatfish that has been mistaken for the seabed by at least one anchor."},
	{"n": "Forest Ling", "t": "Rare", "h": "Kelp Forest", "m": 19, "w": [4.0, 11.0], "v": 14, "d": "Long and mottled, working the base of the stipes where the light gives up."},
	{"n": "Emerald Wrasse", "t": "Rare", "h": "Kelp Forest", "m": 10, "w": [2.0, 6.5], "v": 15, "d": "Impossibly green, and worth more to collectors than to cooks.", "pick": 0.6},
	{"n": "Kelp Lord", "t": "Epic", "h": "Kelp Forest", "m": 12, "w": [10.0, 26.0], "v": 32, "d": "The forest's resident bulk. Holds a clearing among the stipes and tolerates no rivals."},
	{"n": "Bull Kelp Shark", "t": "Epic", "h": "Kelp Forest", "m": 26, "w": [14.0, 34.0], "v": 36, "d": "Small as sharks go, and entirely convinced otherwise."},
	{"n": "Tanglefin", "t": "Epic", "h": "Kelp Forest", "m": 24, "w": [8.0, 22.0], "v": 34, "d": "Trails fins like torn weed and vanishes the moment the forest closes behind it.", "pick": 0.7},

	# --- Coral Shallows (19) -------------------------------------------
	# Warm bright water over reef. Busiest habitat on the island and the
	# one that most rewards fishing in good weather.
	{"n": "Clown Wrasse", "t": "Common", "h": "Coral Shallows", "m": 13, "w": [0.1, 0.5], "v": 2, "d": "Painted in colours no fish that small has any business wearing."},
	{"n": "Reef Damsel", "t": "Common", "h": "Coral Shallows", "m": 13, "w": [0.1, 0.4], "v": 2, "d": "Defends a patch of coral the size of a hat against fish ten times its size."},
	{"n": "Sand Goby", "t": "Common", "h": "Coral Shallows", "m": 0, "w": [0.1, 0.4], "v": 1, "d": "Hovers over white sand, dropping out of sight whenever a shadow crosses it."},
	{"n": "Butterflyfish", "t": "Common", "h": "Coral Shallows", "m": 13, "w": [0.2, 0.7], "v": 2, "d": "Swims in pairs and stays that way for life, which the reef finds unremarkable."},
	{"n": "Parrot Wrasse", "t": "Uncommon", "h": "Coral Shallows", "m": 10, "w": [1.0, 3.6], "v": 6, "d": "Grinds coral to sand with a beak like a nutcracker. The beaches are its leavings."},
	{"n": "Coral Snapper", "t": "Uncommon", "h": "Coral Shallows", "m": 15, "w": [1.2, 4.0], "v": 7, "d": "Hangs at the reef edge in loose crowds, all facing the current."},
	{"n": "Angel Discus", "t": "Uncommon", "h": "Coral Shallows", "m": 13, "w": [0.6, 2.2], "v": 7, "d": "A flat disc of a fish that turns edge-on and disappears completely."},
	{"n": "Spotted Puffer", "t": "Uncommon", "h": "Coral Shallows", "m": 11, "w": [0.5, 2.0], "v": 6, "d": "Inflates into an indigestible ball at the first sign of trouble, then sulks."},
	{"n": "Reef Triggerfish", "t": "Uncommon", "h": "Coral Shallows", "m": 10, "w": [0.8, 3.0], "v": 6, "d": "Locks itself into a crevice with a spine and dares anything to pull it out."},
	{"n": "Sunscale Snapper", "t": "Rare", "h": "Coral Shallows", "m": 15, "w": [3.0, 8.0], "v": 13, "d": "Throws back so much light in the shallows that it is easier to catch than to look at.", "weather": "Sunny"},
	{"n": "Lionfish", "t": "Rare", "h": "Coral Shallows", "m": 24, "w": [1.0, 3.5], "v": 15, "d": "Drifts with its spines fanned, entirely unhurried, because nothing sensible attacks it."},
	{"n": "Reef Grouper", "t": "Rare", "h": "Coral Shallows", "m": 12, "w": [5.0, 14.0], "v": 15, "d": "Owns one cave and inhales anything that swims past the mouth of it."},
	{"n": "Napoleon Wrasse", "t": "Rare", "h": "Coral Shallows", "m": 10, "w": [6.0, 16.0], "v": 17, "d": "Grows a bulging forehead with age and follows divers around out of plain curiosity."},
	{"n": "Coral Barracuda", "t": "Epic", "h": "Coral Shallows", "m": 16, "w": [8.0, 20.0], "v": 30, "d": "Hangs over the drop-off like a hung knife, moving only to become somewhere else."},
	{"n": "Summer Marlin", "t": "Epic", "h": "Coral Shallows", "m": 23, "w": [16.0, 42.0], "v": 40, "d": "Comes into the warm shallows to hunt and lights up electric blue when it does.", "season": "Summer"},
	{"n": "Manta of the Shallows", "t": "Epic", "h": "Coral Shallows", "m": 35, "w": [20.0, 50.0], "v": 38, "d": "Flies rather than swims, and turns the sand dark as it passes over."},
	{"n": "Emperor Angelfish", "t": "Legendary", "h": "Coral Shallows", "m": 13, "w": [4.0, 12.0], "v": 62, "d": "Wears a pattern so exact that the reef seems to have been designed around it."},
	{"n": "Goldscale Sailfish", "t": "Legendary", "h": "Coral Shallows", "m": 24, "w": [25.0, 60.0], "v": 78, "d": "Raises its sail in the sunlit shallows and outruns anything the island can float.", "weather": "Sunny", "pick": 0.7},
	{"n": "Sunlit Mirage", "t": "Secret", "h": "Coral Shallows", "m": 40, "w": [18.0, 45.0], "v": 320, "d": "Seen only at high summer noon, and only by fishermen nobody believes afterwards.", "weather": "Sunny", "season": "Summer", "night": false},

	# --- Open Water (10) -----------------------------------------------
	# Off the shelf entirely: no bottom, no cover, nothing but fast fish.
	{"n": "Blue Runner", "t": "Rare", "h": "Open Water", "m": 16, "w": [2.0, 6.5], "v": 13, "d": "Never stops moving, not even to sleep. Nothing out here can afford to."},
	{"n": "Skipjack", "t": "Rare", "h": "Open Water", "m": 2, "w": [3.0, 9.0], "v": 14, "d": "Warm-blooded and always hungry, burning through the open sea in silver waves."},
	{"n": "Yellowfin Tuna", "t": "Epic", "h": "Open Water", "m": 15, "w": [18.0, 45.0], "v": 40, "d": "Built entirely for speed, down to fins that fold into slots so as not to spoil the line."},
	{"n": "Blue Shark", "t": "Epic", "h": "Open Water", "m": 26, "w": [20.0, 55.0], "v": 38, "d": "Follows a boat for days on the chance of something going over the side."},
	{"n": "Hammerhead", "t": "Epic", "h": "Open Water", "m": 27, "w": [24.0, 60.0], "v": 42, "d": "Sweeps that ridiculous head across the sand and reads the seabed like a page."},
	{"n": "Broadbill Swordfish", "t": "Epic", "h": "Open Water", "m": 22, "w": [22.0, 58.0], "v": 44, "d": "Hunts by feel in water too dark to see, then slashes through the shoal sideways."},
	{"n": "Blue Marlin", "t": "Legendary", "h": "Open Water", "m": 23, "w": [40.0, 95.0], "v": 82, "d": "The fight every fisherman on the island claims to have had once."},
	{"n": "Great White", "t": "Legendary", "h": "Open Water", "m": 46, "w": [60.0, 140.0], "v": 88, "d": "Arrives without warning, leaves without hurry, and ends the day's fishing either way."},
	{"n": "Thresher", "t": "Legendary", "h": "Open Water", "m": 47, "w": [35.0, 85.0], "v": 76, "d": "Stuns whole shoals with a tail longer than the rest of it.", "pick": 0.7},
	{"n": "Ocean Leviathan", "t": "Mythic", "h": "Open Water", "m": 31, "w": [120.0, 300.0], "v": 190, "d": "Charted as an island twice. Both charts were withdrawn."},

	# --- Storm Front (7) -----------------------------------------------
	# Only reachable while the weather is actively against you.
	{"n": "Squallfish", "t": "Epic", "h": "Storm Front", "m": 24, "w": [10.0, 26.0], "v": 36, "d": "Rides the front edge of a storm, feeding on everything the swell throws up.", "weather": "Stormy"},
	{"n": "Rain Piercer", "t": "Epic", "h": "Storm Front", "m": 25, "w": [6.0, 18.0], "v": 34, "d": "Leaps clean out of the chop for insects driven down by the rain.", "weather": "Rainy"},
	{"n": "Thunder Marlin", "t": "Legendary", "h": "Storm Front", "m": 23, "w": [45.0, 110.0], "v": 86, "d": "Runs ahead of the lightning. Crews claim the line hums before it strikes.", "weather": "Stormy"},
	{"n": "Galewing Ray", "t": "Legendary", "h": "Storm Front", "m": 28, "w": [30.0, 75.0], "v": 74, "d": "Breaches in heavy weather and lands flat, hard enough to be heard over the wind.", "weather": "Stormy", "pick": 0.7},
	{"n": "Tempest Serpent", "t": "Mythic", "h": "Storm Front", "m": 20, "w": [90.0, 220.0], "v": 175, "d": "Comes up the face of the swell in coils and is gone before anyone agrees on what they saw.", "weather": "Stormy"},
	{"n": "Stormheart Kraken", "t": "Mythic", "h": "Storm Front", "m": 37, "w": [110.0, 260.0], "v": 200, "d": "Takes the storm as an invitation. The harbour bell is rung when it is sighted.", "weather": "Stormy", "pick": 0.6},
	{"n": "The Drowned King", "t": "Secret", "h": "Storm Front", "m": 41, "w": [150.0, 400.0], "v": 420, "d": "Rises only in a winter storm at dead of night, crowned in weed, and looks straight at the boat.", "weather": "Stormy", "season": "Winter", "night": true},

	# --- Ice Shelf (9) -------------------------------------------------
	# Winter water at the edge of the pack ice.
	{"n": "Frost Char", "t": "Rare", "h": "Ice Shelf", "m": 7, "w": [2.0, 6.0], "v": 14, "d": "Belly turns furnace-orange against water cold enough to stop a hand.", "season": "Winter"},
	{"n": "Icecap Cod", "t": "Rare", "h": "Ice Shelf", "m": 6, "w": [4.0, 11.0], "v": 15, "d": "Carries its own antifreeze. Keeps feeding while everything else shuts down.", "season": "Winter"},
	{"n": "Glacier Halibut", "t": "Epic", "h": "Ice Shelf", "m": 36, "w": [25.0, 65.0], "v": 42, "d": "Lies under the shelf like a second floor of ice, waiting out the whole season.", "season": "Winter"},
	{"n": "Blizzard Lancet", "t": "Epic", "h": "Ice Shelf", "m": 25, "w": [8.0, 22.0], "v": 40, "d": "Only rises through the ice holes when the wind is bad enough to keep sensible people ashore.", "weather": "Blizzard"},
	{"n": "Winter Sturgeon", "t": "Legendary", "h": "Ice Shelf", "m": 29, "w": [50.0, 120.0], "v": 80, "d": "Moves beneath the pack ice at a pace that suggests it has nowhere in particular to be.", "season": "Winter"},
	{"n": "Hoarfrost Ray", "t": "Legendary", "h": "Ice Shelf", "m": 28, "w": [28.0, 70.0], "v": 76, "d": "Pale enough to read the seabed through, and cold to the touch long after landing.", "season": "Winter", "pick": 0.7},
	{"n": "Frostbound Wyrm", "t": "Mythic", "h": "Ice Shelf", "m": 38, "w": [100.0, 240.0], "v": 185, "d": "Cuts up through the pack from below. The crack is heard well before anything is seen.", "weather": "Blizzard"},
	{"n": "Whitewater Behemoth", "t": "Mythic", "h": "Ice Shelf", "m": 39, "w": [130.0, 320.0], "v": 205, "d": "Breaks the shelf apart surfacing, and the ice takes a week to close again.", "season": "Winter", "pick": 0.7},
	{"n": "Glassfin Wraith", "t": "Secret", "h": "Ice Shelf", "m": 42, "w": [40.0, 110.0], "v": 360, "d": "Transparent from nose to tail. Visible only as a bend in the lamplight, and only in fog after dark.", "weather": "Foggy", "night": true},

	# --- The Deep (10) -------------------------------------------------
	# Below the light. Almost everything here is a night catch.
	{"n": "Lanternfish", "t": "Epic", "h": "The Deep", "m": 12, "w": [3.0, 10.0], "v": 32, "d": "Rises the whole way up the water column each night and sinks again before dawn.", "night": true},
	{"n": "Gulper Eel", "t": "Epic", "h": "The Deep", "m": 19, "w": [6.0, 18.0], "v": 34, "d": "Mostly mouth. In water this empty, you eat whatever arrives, whatever its size.", "night": true},
	{"n": "Anglerfish", "t": "Legendary", "h": "The Deep", "m": 33, "w": [10.0, 30.0], "v": 70, "d": "Carries its own lure and its own light, and has never once needed daylight."},
	{"n": "Abyssal Lamprey", "t": "Legendary", "h": "The Deep", "m": 21, "w": [8.0, 24.0], "v": 68, "d": "A mouth that is also a wound. Comes up the line still attached to something else.", "night": true},
	{"n": "Hadal Chimaera", "t": "Legendary", "h": "The Deep", "m": 34, "w": [14.0, 38.0], "v": 74, "d": "Built to a design the surface abandoned a very long time ago.", "night": true, "pick": 0.7},
	{"n": "Void Serpent", "t": "Mythic", "h": "The Deep", "m": 20, "w": [95.0, 230.0], "v": 195, "d": "Comes up out of water that has no bottom worth measuring, and goes back down unhurried.", "night": true},
	{"n": "Abyssal Behemoth", "t": "Mythic", "h": "The Deep", "m": 39, "w": [140.0, 340.0], "v": 215, "d": "The pressure it lives under would fold the boat flat. It surfaces anyway, occasionally."},
	{"n": "Blindlight Kraken", "t": "Mythic", "h": "The Deep", "m": 37, "w": [120.0, 280.0], "v": 210, "d": "Lightless, eyeless, and unerring. It finds the boat every time.", "night": true, "pick": 0.6},
	{"n": "Nightglass Siren", "t": "Secret", "h": "The Deep", "m": 43, "w": [60.0, 150.0], "v": 380, "d": "Heard first, and always at the exact moment the last lamp goes out.", "night": true, "weather": "Foggy"},
	{"n": "The Long Dark", "t": "Secret", "h": "The Deep", "m": 44, "w": [200.0, 500.0], "v": 460, "d": "No fisherman has described it twice the same way. All of them stopped fishing nights.", "night": true, "weather": "Stormy"},

	# --- Sunken Ruins (5) ----------------------------------------------
	# Drowned stonework out past the shelf. Nothing here is ordinary.
	{"n": "Temple Grouper", "t": "Legendary", "h": "Sunken Ruins", "m": 12, "w": [30.0, 80.0], "v": 72, "d": "Has lived inside the same drowned doorway long enough to have shaped itself to the arch."},
	{"n": "Runic Nautilus", "t": "Legendary", "h": "Sunken Ruins", "m": 11, "w": [12.0, 34.0], "v": 78, "d": "Its shell is scored in marks that are not growth lines and are not decoration.", "pick": 0.7},
	{"n": "Drowned Colossus", "t": "Mythic", "h": "Sunken Ruins", "m": 39, "w": [150.0, 360.0], "v": 220, "d": "Sleeps in the flooded hall and moves once a season, which is when the ruins shift."},
	{"n": "Primordial Wyrm", "t": "Mythic", "h": "Sunken Ruins", "m": 38, "w": [130.0, 300.0], "v": 215, "d": "Was in the water before the stonework was above it, and expects to outlast the argument."},
	{"n": "Keeper of the Ruins", "t": "Secret", "h": "Sunken Ruins", "m": 45, "w": [180.0, 450.0], "v": 500, "d": "Surfaces in fog over the drowned city, waits until it has been properly looked at, and sinks.", "weather": "Foggy", "season": "Autumn"},
]

static var _by_tier: Dictionary = {}
static var _by_habitat: Dictionary = {}
static var _by_name: Dictionary = {}

static func _build() -> void:
	if not _by_tier.is_empty():
		return
	for tier in FishRarity.Tier.values():
		_by_tier[tier] = []
	for habitat in HABITATS:
		_by_habitat[habitat] = []
	for data in SPECIES:
		var species := FishSpecies.new(data)
		_by_tier[species.tier].append(species)
		if not _by_habitat.has(species.habitat):
			push_error("Species %s uses habitat %s, which is missing from HABITATS" % [species.species_name, species.habitat])
			_by_habitat[species.habitat] = []
		_by_habitat[species.habitat].append(species)
		_by_name[species.species_name] = species

static func species_for_tier(tier: FishRarity.Tier) -> Array:
	_build()
	return _by_tier[tier]

static func species_for_habitat(habitat: String) -> Array:
	_build()
	return _by_habitat.get(habitat, [])

## Looks a species up by name. Returns null for names that are no longer
## in the catalog — saved dock entries and catch history can outlive a
## species, so callers need to cope with that rather than assume.
static func find(species_name: String) -> FishSpecies:
	_build()
	return _by_name.get(species_name)

static func total_count() -> int:
	_build()
	return _by_name.size()

## Caches the (eligible species, total weight) pair roll_species() builds,
## keyed on everything that affects it except the random draw itself.
## Weather/season/night-bucket only change a few times a real minute, but
## roll_species() runs on every catch (up to 30 fishermen every 2-5s, plus
## one throwaway Secret-tier call per catch regardless of whether Secret
## is even reachable right now) — re-scanning the tier's species and
## re-evaluating conditions_met() that often was pure churn. The picked
## species itself is never cached, only the eligible pool it's drawn from.
static var _eligible_cache: Dictionary = {}

static func _habitats_signature(habitats: Array) -> String:
	if habitats.is_empty():
		return ""
	var sorted_habitats: Array = habitats.duplicate()
	sorted_habitats.sort()
	return ",".join(sorted_habitats)

static func _bias_signature(bias: Dictionary) -> String:
	if bias.is_empty():
		return ""
	var keys: Array = bias.keys()
	keys.sort()
	var parts: Array = []
	for key in keys:
		parts.append("%s:%s" % [key, bias[key]])
	return ",".join(parts)

static func _build_eligible(tier: FishRarity.Tier, habitats: Array, bias: Dictionary, weather: String, season: String, is_night: bool) -> Dictionary:
	var eligible: Array = []
	var total_weight := 0.0
	for species in species_for_tier(tier):
		if not habitats.is_empty() and not habitats.has(species.habitat):
			continue
		if species.conditions_met(weather, season, is_night):
			eligible.append(species)
			total_weight += species.pick_weight * float(bias.get(species.habitat, 1.0))
	return {"eligible": eligible, "total_weight": total_weight}

## Picks a species of `tier` that is catchable under the current weather,
## season and time of day, biased by each candidate's pick_weight. Returns
## null when nothing of that tier qualifies right now — routine for
## Secret, and possible for any tier whose entries are all condition-gated.
## `habitats` empty means the whole catalog; otherwise the roll is
## restricted to that fishing spot's slice of it. `bias` maps a habitat to
## a pick-weight multiplier and is how bait steers the catch — it skews
## which species come up without ever unlocking one the spot can't reach.
static func roll_species(tier: FishRarity.Tier, habitats: Array = [], bias: Dictionary = {}) -> FishSpecies:
	var current_weather: String = WorldClock.get_weather()
	var current_season: String = WorldClock.get_season_name()
	var is_night: bool = WorldClock.get_night_factor() >= 0.5
	var key := "%d|%s|%s|%s|%s|%s" % [
		tier, _habitats_signature(habitats), _bias_signature(bias), current_weather, current_season, is_night
	]
	var cached: Dictionary
	if _eligible_cache.has(key):
		cached = _eligible_cache[key]
	else:
		cached = _build_eligible(tier, habitats, bias, current_weather, current_season, is_night)
		_eligible_cache[key] = cached
	var eligible: Array = cached.eligible
	var total_weight: float = cached.total_weight
	if eligible.is_empty() or total_weight <= 0.0:
		return null
	var roll := randf() * total_weight
	var cumulative := 0.0
	for species in eligible:
		# Must use the same biased weight the total was built from, or the
		# roll lands short and skews toward the front of the list.
		cumulative += species.pick_weight * float(bias.get(species.habitat, 1.0))
		if roll <= cumulative:
			return species
	return eligible[eligible.size() - 1]
