extends Control

@onready var _reels: Array[SlotNumberReel] = [
	$Panel/VBox/Reels/Reel1,
	$Panel/VBox/Reels/Reel2,
	$Panel/VBox/Reels/Reel3,
]
@onready var _target_edit: LineEdit = $Panel/VBox/Controls/TargetEdit
@onready var _spin_button: Button = $Panel/VBox/Controls/SpinButton
@onready var _status: Label = $Panel/VBox/StatusLabel

var _finished: int = 0


func _ready() -> void:
	_spin_button.pressed.connect(_on_spin_pressed)
	_target_edit.text_submitted.connect(_on_text_submitted)

	for reel in _reels:
		reel.spin_finished.connect(_on_reel_finished)

	_reels[0].set_value(7)
	_reels[1].set_value(4)
	_reels[2].set_value(2)
	_status.text = "输入 3 位数字（例如 742），点击开始旋转。"


func _on_text_submitted(_new_text: String) -> void:
	_on_spin_pressed()


func _on_spin_pressed() -> void:
	if _spin_button.disabled:
		return

	var digits: Array[int] = []
	for c in _target_edit.text:
		if c >= "0" and c <= "9":
			digits.append(int(c))
	if digits.is_empty():
		digits = [7, 4, 2]

	_finished = 0
	_spin_button.disabled = true

	var target_text := ""
	for i in range(_reels.size()):
		var digit: int = digits[i % digits.size()]
		target_text += str(digit)
		if i > 0:
			await get_tree().create_timer(0.12).timeout
		_reels[i].spin_to(digit)

	_status.text = "旋转中… 目标：" + target_text


func _on_reel_finished(_value: int) -> void:
	_finished += 1
	if _finished >= _reels.size():
		_spin_button.disabled = false
		_status.text = "已停止：" + _current_text()


func _current_text() -> String:
	var text := ""
	for reel in _reels:
		text += str(reel.get_value())
	return text
