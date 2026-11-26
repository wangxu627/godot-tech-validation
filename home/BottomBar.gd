class_name BottomBar
extends Container

## 通用底部导航栏。
## Tab 数量、顺序、图标、颜色、页面动画均通过 configure(configs) 注入。
## 选中态表现由 selection_mode 配置，支持五种效果及其组合：
##   WIDEN       —— 仅横向变宽（默认）
##   WIDEN_GROW  —— 变宽 + 变高
##   SWAP_ICON   —— 选中时切换图标
##   ICON_SCALE  —— 选中时图标放大
##   ICON_LIFT   —— 图标放大并上移，取消时缩小并回到居中位置
## 每个 Tab 还可在配置里写 selection_mode 覆盖容器级设置，因此不同按钮可以使用不同动画。
## 切换时只修改每个 Tab 的 weight / 选中态并重新布局，不重建 BottomBar。

## 选中态效果位标志，可任意按位组合。
enum SelectionMode {
	WIDEN = 1,        ## 横向变宽
	WIDEN_GROW = 2,   ## 变宽 + 变高
	SWAP_ICON = 4,    ## 选中时换图
	ICON_SCALE = 8,   ## 图标放大
	ICON_LIFT = 16,   ## 图标放大上移 / 取消时缩小回中
}

signal tab_pressed(tab_id: StringName)

@export var transition_duration: float = 0.36
@export var selected_weight: float = 2.0
@export var normal_weight: float = 1.0
@export var transition_trans: Tween.TransitionType = Tween.TRANS_CUBIC
@export var transition_ease: Tween.EaseType = Tween.EASE_OUT

## 容器级选中态效果。默认 WIDEN（仅变宽）；单个 Tab 可用配置里的 selection_mode 覆盖。
@export_flags("变宽:1", "变宽+变高:2", "换图:4", "图标放大:8", "图标放大上移:16") var selection_mode: int = SelectionMode.WIDEN
## WIDEN_GROW 模式下选中 Tab 向上额外生长的高度（像素）。
@export var selected_grow_height: float = 26.0

## 背景：纯色底先绘制，图片底叠加其上（图片可带透明区域透出底色）。
## 两者都不设时 BottomBar 透明，完全由按钮自身绘制。
@export var background_color: Color = Color(0, 0, 0, 0):
	set(value):
		background_color = value
		queue_redraw()
@export var background_texture: Texture2D:
	set(value):
		background_texture = value
		queue_redraw()
## 图片背景绘制方式：false = 拉伸铺满（默认），true = 平铺。
@export var background_tile: bool = false:
	set(value):
		background_tile = value
		queue_redraw()
## 图片背景的调制色，可用来整体染色或调整透明度。
@export var background_modulate: Color = Color(1, 1, 1, 1):
	set(value):
		background_modulate = value
		queue_redraw()

var _buttons: Dictionary = {}
var _order: Array[StringName] = []
var _selected: StringName = &""
var _weight_tween: Tween = null


func _ready() -> void:
	resized.connect(_on_resized)


## 先绘制容器背景，各 Tab 按钮作为子节点覆盖在其上。
func _draw() -> void:
	if background_color.a > 0.001:
		draw_rect(Rect2(Vector2.ZERO, size), background_color)
	if background_texture != null:
		draw_texture_rect(
			background_texture,
			Rect2(Vector2.ZERO, size),
			background_tile,
			background_modulate
		)


## 运行时设置背景；传透明色 / null 可移除对应层。
func set_background(color: Color, texture: Texture2D = null) -> void:
	background_color = color
	background_texture = texture


## 配置 Tab 列表。configs 中每项支持：
##   id / label / icon / selected_icon / enabled / keep_state /
##   normal_bg / selected_bg / normal_icon_color / selected_icon_color / accent_color /
##   normal_bg_texture / selected_bg_texture / icon_texture / selected_icon_texture /
##   selection_mode / selected_icon_scale / icon_lift_scale / icon_lift_offset /
##   badge_text / page_scene / page_title / subtitle / background_color /
##   accent_color_page / enter_style
func configure(configs: Array[Dictionary]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_order.clear()
	_selected = &""

	for data in configs:
		var id := StringName(data.get("id", &""))
		if id == &"" or _buttons.has(id):
			continue

		var button := BottomTabButton.new()
		button.configure(data)
		_apply_effective_mode(button)
		button.tab_pressed.connect(_on_tab_button_pressed)
		add_child(button)

		_buttons[id] = button
		_order.append(id)

	_sort_children()


## 运行时切换容器级选中效果（位组合）。配置了自身 selection_mode 的 Tab 不受影响。
func set_selection_mode(mode: int) -> void:
	selection_mode = mode
	_sync_grow_target()
	_sort_children()


## 运行时单独修改某个 Tab 的效果；传 -1 表示恢复跟随容器设置。
func set_tab_selection_mode(tab_id: StringName, mode: int) -> void:
	if not _buttons.has(tab_id):
		return
	_buttons[tab_id].selection_mode_override = mode
	_apply_effective_mode(_buttons[tab_id])
	_sort_children()


func has_mode(mode: int) -> bool:
	return (selection_mode & mode) != 0


## Tab 配置里的 selection_mode >= 0 时覆盖容器级设置。
func _apply_effective_mode(button: BottomTabButton) -> void:
	var override := button.selection_mode_override
	button.effective_selection_mode = override if override >= 0 else selection_mode
	button.swap_icon_enabled = button.has_effect(SelectionMode.SWAP_ICON)
	button.queue_redraw()


func select(tab_id: StringName, animated: bool = true) -> void:
	if not _buttons.has(tab_id):
		return

	var tapped: BottomTabButton = _buttons[tab_id]
	if not tapped.enabled:
		return

	if _selected == tab_id and not is_transitioning():
		return

	_selected = tab_id

	for id: StringName in _order:
		var button: BottomTabButton = _buttons[id]
		_apply_effective_mode(button)
		var is_selected := id == tab_id
		button.set_selected(
			is_selected,
			animated,
			transition_duration if animated else 0.0,
			transition_trans,
			transition_ease
		)

	_animate_weights(tab_id, animated)


func get_selected() -> StringName:
	return _selected


func get_button(tab_id: StringName) -> BottomTabButton:
	return _buttons.get(tab_id) as BottomTabButton


func is_transitioning() -> bool:
	return _weight_tween != null and _weight_tween.is_running()


func set_tab_enabled(tab_id: StringName, value: bool) -> void:
	if _buttons.has(tab_id):
		_buttons[tab_id].enabled = value
		_buttons[tab_id].queue_redraw()


func _animate_weights(tab_id: StringName, animated: bool) -> void:
	if _weight_tween != null and _weight_tween.is_valid():
		_weight_tween.kill()
		_weight_tween = null

	var dur := transition_duration if animated else 0.0

	# 高度与宽度同步动画；每个 Tab 用自己生效的位标志决定效果。
	for id: StringName in _order:
		var button: BottomTabButton = _buttons[id]
		var can_grow := button.has_effect(SelectionMode.WIDEN_GROW)
		var want := selected_grow_height if (id == tab_id and can_grow) else 0.0
		button.set_grow(want, animated, dur, transition_trans, transition_ease)

	if not animated:
		for id: StringName in _order:
			_buttons[id].weight = _target_weight(id, tab_id)
		_sort_children()
		return

	_weight_tween = create_tween().set_parallel(true)
	for id: StringName in _order:
		var target := _target_weight(id, tab_id)
		var tweener := _weight_tween.tween_property(_buttons[id], "weight", target, transition_duration)
		tweener.set_trans(transition_trans)
		tweener.set_ease(transition_ease)
	_weight_tween.finished.connect(_on_weight_tween_finished)


func _target_weight(id: StringName, selected_id: StringName) -> float:
	var button: BottomTabButton = _buttons[id]
	var widen := button.has_effect(SelectionMode.WIDEN) or button.has_effect(SelectionMode.WIDEN_GROW)
	return (selected_weight if id == selected_id else normal_weight) if widen else 1.0


## 把“选中 Tab 应向上长出多少”和换图开关写给每个按钮，按钮自己按比例动画。
func _sync_grow_target() -> void:
	for id: StringName in _order:
		var button: BottomTabButton = _buttons[id]
		_apply_effective_mode(button)
		button.grow_duration = transition_duration
		var can_grow := button.has_effect(SelectionMode.WIDEN_GROW)
		button.set_grow(selected_grow_height if (id == _selected and can_grow) else 0.0, false, 0.0, transition_trans, transition_ease)


func _on_weight_tween_finished() -> void:
	_weight_tween = null
	_sort_children()


func _on_tab_button_pressed(tab_id: StringName) -> void:
	if not _buttons.has(tab_id):
		return
	if not _buttons[tab_id].enabled:
		return
	tab_pressed.emit(tab_id)


func _on_resized() -> void:
	_sort_children()


func _sort_children() -> void:
	if _order.is_empty() or size.x <= 0.0:
		return

	var total_weight := 0.0
	for id: StringName in _order:
		total_weight += maxf(_buttons[id].weight, 0.001)
	if total_weight <= 0.0:
		return

	var x := 0.0
	for id: StringName in _order:
		var button: BottomTabButton = _buttons[id]
		var width := size.x * maxf(button.weight, 0.001) / total_weight
		var grow := button.current_grow
		button.position = Vector2(x, -grow)
		button.size = Vector2(width, size.y + grow)
		x += width


func _process(_delta: float) -> void:
	if is_transitioning():
		_sort_children()
		return
	var any_grow := false
	for id: StringName in _order:
		if _buttons[id].has_effect(SelectionMode.WIDEN_GROW):
			any_grow = true
			break
	if not any_grow:
		return
	# 变高动画期间每帧重排，否则新的高度不会反映到布局上。
	for id: StringName in _order:
		if _buttons[id].is_grow_animating():
			_sort_children()
			return
