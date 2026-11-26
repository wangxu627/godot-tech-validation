extends SceneTree

## 渲染截图：验证 2 按钮 / 5 按钮 / home2 双场景的选中表现。
## 用法：godot --path <proj> -s res://tests/shoot_bottom_bar.gd

const OUT_DIR := "res://tests/shots"
const HOME_SCENE := "res://home/Home.tscn"
const HOME2_SCENE := "res://home/home2.tscn"

const CASES := [
	{"name": "2btn_widen", "tabs": 2, "mode": 1},
	{"name": "2btn_widen_grow", "tabs": 2, "mode": 2},
	{"name": "2btn_swap_icon", "tabs": 2, "mode": 4},
	{"name": "2btn_all", "tabs": 2, "mode": 7},
	{"name": "2btn_icon_lift", "tabs": 2, "mode": 16},
	{"name": "5btn_widen", "tabs": 5, "mode": 1},
	{"name": "5btn_all", "tabs": 5, "mode": 7},
	# home2.tscn：两个按钮各自不同的动画组合
	{"name": "home2_explore", "scene": HOME2_SCENE, "select": 0},
	{"name": "home2_bag", "scene": HOME2_SCENE, "select": 1},
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	for c in CASES:
		await _shoot(c)

	print("done")
	quit(0)


func _shoot(c: Dictionary) -> void:
	var name := str(c["name"])
	var scene_path := str(c.get("scene", HOME_SCENE))
	var home: Control = load(scene_path).instantiate()

	if not c.has("scene"):
		home.demo_preset = Home.DemoPreset.TWO_TABS if int(c["tabs"]) == 2 else Home.DemoPreset.FIVE_TABS
		home.bottom_bar_selection_mode = int(c["mode"])
	root.add_child(home)

	# 等布局与入场动画结束
	await create_timer(1.0).timeout

	var bar: BottomBar = home.get_node("BottomBar")
	if not c.has("scene"):
		# 验证容器级模式时清掉示例配置里的 per-tab 覆盖。
		for id: StringName in bar._order:
			bar.set_tab_selection_mode(id, -1)
	var ids: Array = bar._order
	if not ids.is_empty():
		var idx := clampi(int(c.get("select", 0)), 0, ids.size() - 1)
		if home.has_method("switch_to"):
			home.switch_to(ids[idx])
		else:
			bar.select(ids[idx], false)
	await create_timer(1.0).timeout

	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path, "  ", img.get_width(), "x", img.get_height())

	home.queue_free()
	await create_timer(0.2).timeout
