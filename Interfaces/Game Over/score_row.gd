extends HBoxContainer

@onready var rank_label  = $RankLabel
@onready var name_label  = $NameLabel
@onready var wins_label  = $WinsLabel
@onready var kills_label = $KillsLabel

func setup(rank: int, player_name: String, wins: int, kills: int, is_you: bool):
	rank_label.text  = "#" + str(rank)
	wins_label.text  = str(wins)
	kills_label.text = str(kills)
	
	if is_you:
		name_label.text = player_name + "  [YOU]"
		name_label.add_theme_color_override("font_color", Color("#e8f0e8"))
		rank_label.add_theme_color_override("font_color", Color("#4caf50"))
		wins_label.add_theme_color_override("font_color", Color("#4caf50"))
	else:
		name_label.text = player_name
		name_label.add_theme_color_override("font_color", Color("#a0c0a0"))
		rank_label.add_theme_color_override("font_color", Color("#3a5a3a"))
		wins_label.add_theme_color_override("font_color", Color("#5a7a5a"))
	
	# kills always dim regardless of who
	kills_label.add_theme_color_override("font_color", Color("#5a7a5a"))
