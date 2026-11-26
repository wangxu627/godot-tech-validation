class_name Home
extends Control

## 通用小游戏主页框架。
## 上部为页面主体，底部为动态 BottomBar。
## Tab 与页面配置通过 tab_configs 注入；为空时使用内置 Demo 配置。
## 按钮数量由 tab_configs 的条数决定，选中态表现由 bottom_bar_selection_mode 决定。

const DEMO_PAGE_SCENE = preload("res://home/DemoPage.tscn")
const ICON_CHEST := preload("res://assets/bottombar/icon_chest.png")
const ICON_HELMET := preload("res://assets/bottombar/icon_helmet.png")
const BTN_GREY := preload("res://assets/bottombar/btn_grey.png")
const BTN_YELLOW := preload("res://assets/bottombar/btn_yellow.png")

## 内置演示配置的套数：5 按钮（完整 Demo）或 2 按钮（精简 Demo）。
enum DemoPreset {
	FIVE_TABS = 0,
	TWO_TABS = 1,
}

@export var default_tab_id: StringName = &"campaign"
@export var page_transition_duration: float = 0.5
@export var tab_configs: Array[Dictionary] = []
## 空配置时使用哪套内置演示。
@export var demo_preset: DemoPreset = DemoPreset.TWO_TABS
## 容器级选中效果。-1 表示尊重场景中 BottomBar 节点上设置的 selection_mode。
## >=0 时会覆盖场景设置；单个 Tab 仍可在 tab_configs 里用 selection_mode 覆盖。
@export_flags("变宽:1", "变宽+变高:2", "换图:4", "图标放大:8", "图标放大上移:16") var bottom_bar_selection_mode: int = -1

@onready var _page_host: Control = $MainContent/PageHost
@onready var _bottom_bar: BottomBar = $BottomBar

var current_tab: StringName = &""
var previous_tab: StringName = &""
var is_transitioning: bool = false

var _pages: Dictionary = {}
var _configs: Dictionary = {}
var _order: Array[StringName] = []
var _pending_tab: StringName = &""


func _ready() -> void:
	var configs := tab_configs if not tab_configs.is_empty() else _default_configs()

	for data in configs:
		var id := StringName(data.get("id", &""))
		if id == &"" or _configs.has(id):
			continue
		_configs[id] = data
		_order.append(id)

	# -1 表示使用场景里 BottomBar 节点上配置的 selection_mode（可在检查器里改）。
	if bottom_bar_selection_mode >= 0:
		_bottom_bar.selection_mode = bottom_bar_selection_mode
	_bottom_bar.configure(configs)
	_bottom_bar.tab_pressed.connect(_on_tab_pressed)

	var initial := default_tab_id
	if not _configs.has(initial):
		initial = _order[0] if not _order.is_empty() else &""
	_show_initial(initial)


## 对外切换入口。快速连续点击时会保留最后一次请求，等当前动画结束后执行。
func switch_to(tab_id: StringName) -> void:
	if not _configs.has(tab_id):
		return
	if not bool(_configs[tab_id].get("enabled", true)):
		return
	if tab_id == current_tab:
		return

	if is_transitioning:
		_pending_tab = tab_id
		return

	var next := _get_page(tab_id)
	if next == null:
		return

	var previous: HomePageBase = null
	if current_tab != &"" and _pages.has(current_tab):
		previous = _pages[current_tab]

	previous_tab = current_tab
	current_tab = tab_id
	is_transitioning = true

	_bottom_bar.select(tab_id, true)

	if previous != null and previous != next:
		previous.on_exit()
		# 立即隐藏旧页面，避免新旧文字在入场动画期间重叠。
		previous.visible = false

	next.visible = true
	next.on_enter()
	next.play_enter_animation()

	await get_tree().create_timer(page_transition_duration).timeout

	is_transitioning = false
	_drain_pending()


func get_page(tab_id: StringName) -> HomePageBase:
	return _pages.get(tab_id) as HomePageBase


func _show_initial(tab_id: StringName) -> void:
	if tab_id == &"":
		return

	var page := _get_page(tab_id)
	if page == null:
		return

	for candidate in _pages.values():
		candidate.visible = false

	current_tab = tab_id
	previous_tab = &""
	_bottom_bar.select(tab_id, false)
	page.visible = true
	page.on_enter()
	page.play_enter_animation()


func _get_page(tab_id: StringName) -> HomePageBase:
	if _pages.has(tab_id):
		return _pages[tab_id]

	var config: Dictionary = _configs[tab_id]
	var scene := config.get("page_scene") as PackedScene
	if scene == null:
		push_error("Home: Tab %s 未配置有效的 page_scene。" % str(tab_id))
		return null

	var page := scene.instantiate() as HomePageBase
	if page == null:
		push_error("Home: page_scene 根节点必须继承 HomePageBase：%s" % str(tab_id))
		return null

	# 必须在 add_child 之前写入配置，否则页面的 _ready() 会先使用默认值初始化 UI。
	page.page_id = tab_id
	page.keep_state_on_exit = bool(config.get("keep_state", true))

	for key in ["page_title", "subtitle", "badge_text", "background_color", "accent_color", "enter_style"]:
		if config.has(key):
			page.set(key, config[key])
	if config.has("accent_color_page"):
		page.set("accent_color", config["accent_color_page"])

	var callback = config.get("enter_animation_callback", null)
	if callback is Callable and (callback as Callable).is_valid():
		page.set_enter_animation_callback(callback)

	_page_host.add_child(page)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.anchor_left = 0.0
	page.anchor_top = 0.0
	page.anchor_right = 1.0
	page.anchor_bottom = 1.0
	page.offset_left = 0.0
	page.offset_top = 0.0
	page.offset_right = 0.0
	page.offset_bottom = 0.0
	page.visible = false

	_pages[tab_id] = page
	return page


func _on_tab_pressed(tab_id: StringName) -> void:
	if tab_id == current_tab:
		return
	if is_transitioning:
		_pending_tab = tab_id
		return
	switch_to(tab_id)


func _drain_pending() -> void:
	if _pending_tab == &"":
		return
	var target := _pending_tab
	_pending_tab = &""
	if target != current_tab:
		switch_to(target)


func _default_configs() -> Array[Dictionary]:
	if demo_preset == DemoPreset.TWO_TABS:
		return _two_tab_configs()
	return _five_tab_configs()


## 2 按钮精简演示：数量、文案、图标全部走同一份配置结构。
## 这套配置使用项目里的按钮状态图和两个图标前景，并演示 ICON_LIFT 效果。
func _two_tab_configs() -> Array[Dictionary]:
	return [
		{
			"id": &"campaign",
			"label": "闯关",
			"icon": "chest",
			"enabled": true,
			"keep_state": true,
			"selection_mode": BottomBar.SelectionMode.WIDEN | BottomBar.SelectionMode.ICON_LIFT,
			"icon_lift_scale": 1.32,
			"icon_lift_offset": 22.0,
			"normal_bg_texture": BTN_GREY,
			"selected_bg_texture": BTN_YELLOW,
			"patch_trim_left": 0.0,
			"patch_trim_right": 0.0,
			"icon_texture": ICON_CHEST,
			"selected_icon_texture": ICON_CHEST,
			"normal_bg": Color(0.10, 0.08, 0.05, 1),
			"selected_bg": Color(0.23, 0.16, 0.045, 1),
			"normal_icon_color": Color(0.92, 0.80, 0.52, 1),
			"selected_icon_color": Color(1.0, 0.94, 0.66, 1),
			"accent_color": Color(1.0, 0.72, 0.16, 1),
			"page_scene": DEMO_PAGE_SCENE,
			"page_title": "闯关",
			"subtitle": "两按钮配置 · 图标放大上移",
			"badge_text": "CAMPAIGN",
			"background_color": Color(0.035, 0.17, 0.15, 1),
			"accent_color_page": Color(0.22, 0.90, 0.62, 1),
			"enter_style": DemoPage.EnterStyle.SCALE,
		},
		{
			"id": &"more",
			"label": "更多",
			"icon": "helmet",
			"enabled": true,
			"keep_state": true,
			"selection_mode": BottomBar.SelectionMode.WIDEN_GROW | BottomBar.SelectionMode.ICON_LIFT,
			"icon_lift_scale": 1.32,
			"icon_lift_offset": 22.0,
			"normal_bg_texture": BTN_GREY,
			"selected_bg_texture": BTN_YELLOW,
			"patch_trim_left": 0.0,
			"patch_trim_right": 0.0,
			"icon_texture": ICON_HELMET,
			"selected_icon_texture": ICON_HELMET,
			"normal_bg": Color(0.10, 0.075, 0.055, 1),
			"selected_bg": Color(0.20, 0.12, 0.045, 1),
			"normal_icon_color": Color(0.88, 0.66, 0.38, 1),
			"selected_icon_color": Color(1.0, 0.88, 0.56, 1),
			"accent_color": Color(0.98, 0.58, 0.22, 1),
			"page_scene": DEMO_PAGE_SCENE,
			"page_title": "更多",
			"subtitle": "两按钮配置 · 从下方上移进入",
			"badge_text": "MORE",
			"background_color": Color(0.20, 0.09, 0.045, 1),
			"accent_color_page": Color(1.0, 0.60, 0.24, 1),
			"enter_style": DemoPage.EnterStyle.SLIDE_UP,
		},
	]


func _five_tab_configs() -> Array[Dictionary]:
	return [
		{
			"id": &"base",
			"label": "基地",
			"icon": "base",
			"selected_icon": "hero",
			"enabled": true,
			"keep_state": true,
			"normal_bg": Color(0.075, 0.085, 0.11, 1),
			"selected_bg": Color(0.18, 0.12, 0.05, 1),
			"normal_icon_color": Color(0.55, 0.66, 0.82, 1),
			"selected_icon_color": Color(1.0, 0.88, 0.52, 1),
			"accent_color": Color(0.26, 0.60, 0.98, 1),
			"page_scene": DEMO_PAGE_SCENE,
			"page_title": "基地",
			"subtitle": "蓝色淡入页面",
			"badge_text": "BASE",
			"background_color": Color(0.045, 0.10, 0.20, 1),
			"accent_color_page": Color(0.24, 0.64, 1.0, 1),
			"enter_style": DemoPage.EnterStyle.FADE,
		},
		{
			"id": &"hero",
			"label": "英雄",
			"icon": "hero",
			"selected_icon": "base",
			"enabled": true,
			"keep_state": true,
			"normal_bg": Color(0.085, 0.09, 0.10, 1),
			"selected_bg": Color(0.16, 0.13, 0.07, 1),
			"normal_icon_color": Color(0.72, 0.74, 0.78, 1),
			"selected_icon_color": Color(1.0, 0.88, 0.58, 1),
			"accent_color": Color(0.78, 0.82, 0.90, 1),
			"page_scene": DEMO_PAGE_SCENE,
			"page_title": "英雄",
			"subtitle": "从右侧滑入页面",
			"badge_text": "HERO",
			"background_color": Color(0.14, 0.11, 0.18, 1),
			"accent_color_page": Color(0.78, 0.55, 1.0, 1),
			"enter_style": DemoPage.EnterStyle.SLIDE_RIGHT,
		},
		{
			"id": &"campaign",
			"label": "战役",
			"icon": "planet",
			"selected_icon": "gift",
			"enabled": true,
			"keep_state": true,
			"normal_bg": Color(0.10, 0.08, 0.05, 1),
			"selected_bg": Color(0.23, 0.16, 0.045, 1),
			"normal_icon_color": Color(0.92, 0.80, 0.52, 1),
			"selected_icon_color": Color(1.0, 0.94, 0.66, 1),
			"accent_color": Color(1.0, 0.72, 0.16, 1),
			"page_scene": DEMO_PAGE_SCENE,
			"page_title": "战役",
			"subtitle": "绿色星球缩放进入页面",
			"badge_text": "CAMPAIGN",
			"background_color": Color(0.035, 0.17, 0.15, 1),
			"accent_color_page": Color(0.22, 0.90, 0.62, 1),
			"enter_style": DemoPage.EnterStyle.SCALE,
		},
		{
			"id": &"event",
			"label": "活动",
			"icon": "gift",
			"selected_icon": "shop",
			"enabled": true,
			"keep_state": false,
			"normal_bg": Color(0.06, 0.10, 0.08, 1),
			"selected_bg": Color(0.08, 0.19, 0.11, 1),
			"normal_icon_color": Color(0.50, 0.82, 0.56, 1),
			"selected_icon_color": Color(0.90, 1.0, 0.62, 1),
			"accent_color": Color(0.28, 0.82, 0.42, 1),
			"page_scene": DEMO_PAGE_SCENE,
			"page_title": "活动",
			"subtitle": "从下方上移进入页面",
			"badge_text": "EVENT",
			"background_color": Color(0.06, 0.19, 0.09, 1),
			"accent_color_page": Color(0.40, 0.94, 0.48, 1),
			"enter_style": DemoPage.EnterStyle.SLIDE_UP,
		},
		{
			"id": &"shop",
			"label": "商店",
			"icon": "shop",
			"selected_icon": "planet",
			"enabled": true,
			"keep_state": true,
			"normal_bg": Color(0.10, 0.075, 0.055, 1),
			"selected_bg": Color(0.20, 0.12, 0.045, 1),
			"normal_icon_color": Color(0.88, 0.66, 0.38, 1),
			"selected_icon_color": Color(1.0, 0.88, 0.56, 1),
			"accent_color": Color(0.98, 0.58, 0.22, 1),
			"page_scene": DEMO_PAGE_SCENE,
			"page_title": "商店",
			"subtitle": "无动画直接显示页面",
			"badge_text": "SHOP",
			"background_color": Color(0.20, 0.09, 0.045, 1),
			"accent_color_page": Color(1.0, 0.60, 0.24, 1),
			"enter_style": DemoPage.EnterStyle.NONE,
		},
	]
