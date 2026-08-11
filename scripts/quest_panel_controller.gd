class_name QuestPanelController
extends Panel

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")
const READY_COLOR := Color(0.4, 0.85, 0.4)

@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/QuestScroll/QuestRows

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	QuestManager.quests_updated.connect(_on_quests_updated)

func toggle() -> void:
	visible = not visible
	if visible:
		build()

func _on_quests_updated() -> void:
	if visible:
		build()

func build() -> void:
	UiListUtils.clear_children(rows_container)
	var ready_count := 0
	for quest in QuestManager.active_quests:
		if quest.completed:
			ready_count += 1
	title_label.text = "Quests (%d ready)" % ready_count if ready_count > 0 else "Quests"
	for quest in QuestManager.active_quests:
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		rows_container.add_child(row)
		var reward_label := "%d %s" % [quest.reward_amount, "Coins" if quest.reward_currency == "coins" else "Scales"]
		var progress_label: String = "Ready to claim!" if quest.completed else "%d / %d" % [quest.progress, quest.goal]
		row.setup(quest.description, progress_label, reward_label)
		row.disabled = not quest.completed
		if quest.completed:
			row.set_right_color(READY_COLOR)
		row.pressed.connect(_on_quest_pressed.bind(quest.id))

func _on_quest_pressed(quest_id: String) -> void:
	QuestManager.claim(quest_id)

func _on_close_button_pressed() -> void:
	visible = false
