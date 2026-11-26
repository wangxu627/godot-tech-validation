class_name Home2
extends Home

## 双按钮主页示例。
## 只提供配置，不复制 Home 的导航逻辑；BottomBar 是独立组件，按钮数量由配置条数决定。
## 选中效果由 home2.tscn 里 BottomBar 的 selection_mode 决定（当前 = ICON_LIFT 图标放大上移）。
## 这里不再硬编码每个 Tab 的 selection_mode，让它们跟随容器设置：
##   改检查器里 BottomBar 的 Selection Mode，两个按钮会一起生效。

const PAGE_SCENE := preload("res://home/DemoPage.tscn")
# ICON_CHEST / ICON_HELMET / BTN_GREY / BTN_YELLOW 继承自 Home.gd。


func _ready() -> void:
	tab_configs = _build_tabs()
	default_tab_id = &"explore"
	# 保持 -1：使用 home2.tscn 里 BottomBar 节点设置的 selection_mode。
	bottom_bar_selection_mode = -1
	super._ready()


func _build_tabs() -> Array[Dictionary]:
	return [
		{
			"id": &"explore",
			"label": "探索",
			"icon": "chest",
			"enabled": true,
			"keep_state": true,
			# 不写 selection_mode（等同 -1）：跟随 BottomBar 的容器设置。
			"icon_lift_scale": 1.32,
			"icon_lift_offset": 22.0,

			# 图片资源：灰色=未选中，黄色=选中；图标前景两张分别用于两个按钮。
			"normal_bg_texture": BTN_GREY,
			"selected_bg_texture": BTN_YELLOW,
			# 保留贴图原始描边（不裁边）；按钮之间的视觉由 BottomBar 背景统一衬托。
			"patch_trim_left": 0.0,
			"patch_trim_right": 0.0,
			"icon_texture": ICON_CHEST,
			"selected_icon_texture": ICON_CHEST,

			# 纹理缺失时的代码绘制回退配色。
			"normal_bg": Color(0.06, 0.11, 0.10, 1),
			"selected_bg": Color(0.06, 0.24, 0.20, 1),
			"normal_icon_color": Color(0.46, 0.72, 0.66, 1),
			"selected_icon_color": Color(0.66, 1.0, 0.86, 1),
			"accent_color": Color(0.22, 0.92, 0.66, 1),

			"page_scene": PAGE_SCENE,
			"page_title": "探索",
			"subtitle": "图标放大上移 · 灰底→黄底",
			"badge_text": "EXPLORE",
			"background_color": Color(0.025, 0.13, 0.12, 1),
			"accent_color_page": Color(0.24, 0.94, 0.66, 1),
			"enter_style": DemoPage.EnterStyle.FADE,
		},
		{
			"id": &"bag",
			"label": "背包",
			"icon": "helmet",
			"enabled": true,
			"keep_state": true,
			# 不写 selection_mode：跟随 BottomBar 的容器设置。
			"icon_lift_scale": 1.32,
			"icon_lift_offset": 22.0,

			"normal_bg_texture": BTN_GREY,
			"selected_bg_texture": BTN_YELLOW,
			"patch_trim_left": 0.0,
			"patch_trim_right": 0.0,
			"icon_texture": ICON_HELMET,
			"selected_icon_texture": ICON_HELMET,

			"normal_bg": Color(0.12, 0.08, 0.05, 1),
			"selected_bg": Color(0.27, 0.14, 0.045, 1),
			"normal_icon_color": Color(0.86, 0.62, 0.36, 1),
			"selected_icon_color": Color(1.0, 0.90, 0.58, 1),
			"accent_color": Color(1.0, 0.66, 0.20, 1),

			"page_scene": PAGE_SCENE,
			"page_title": "背包",
			"subtitle": "图标放大上移 · 灰底→黄底",
			"badge_text": "BAG",
			"background_color": Color(0.17, 0.09, 0.035, 1),
			"accent_color_page": Color(1.0, 0.68, 0.24, 1),
			"enter_style": DemoPage.EnterStyle.SLIDE_UP,
		},
	]
