class_name RankCatalog
extends RefCounted

## Cosmetic-only rank ladder (Fisherman.get_rank_score()/get_rank_title()).
## Ascending by score; title_for() picks the highest threshold the score
## has cleared. No gameplay effect — see the "Fisherman rank system"
## memory note for why (avoids stacking another power-creep axis on top
## of level+gear+perk+meta-shop).
const RANKS := [
	{"score": 0, "title": "Novice"},
	{"score": 50, "title": "Apprentice"},
	{"score": 150, "title": "Angler"},
	{"score": 300, "title": "Skilled Angler"},
	{"score": 500, "title": "Veteran"},
	{"score": 750, "title": "Expert Angler"},
	{"score": 1100, "title": "Master Angler"},
	{"score": 1600, "title": "Legendary Angler"},
	{"score": 3500, "title": "Grandmaster Angler"},
	{"score": 8000, "title": "Sea Sage"},
	{"score": 20000, "title": "Tide Whisperer"},
	{"score": 50000, "title": "Storm Chaser"},
	{"score": 100000, "title": "Leviathan Hunter"},
	{"score": 250000, "title": "Island Legend"},
	{"score": 500000, "title": "Mythic Angler"},
	{"score": 1000000, "title": "Living Legend"},
]

static func title_for(score: int) -> String:
	var title: String = RANKS[0].title
	for rank in RANKS:
		if score >= rank.score:
			title = rank.title
		else:
			break
	return title
