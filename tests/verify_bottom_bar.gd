extends SceneTree

## 自动化验证 BottomBar 的可配置选中模式与按钮数量。
## 用法：godot --headless --path <proj> -s res://tests/verify_bottom_bar.gd

const HOME_SCENE := "res://home/Home.tscn"


func _initialize() -> void:
	var failures: Array[String] = []

	await _run_case(2, BottomBar.SelectionMode.WIDEN, "2按钮/WIDEN", failures)
	await _run_case(2, BottomBar.SelectionMode.WIDEN_GROW, "2按钮/WIDEN_GROW", failures)
	await _run_case(2, BottomBar.SelectionMode.SWAP_ICON, "2按钮/SWAP_ICON", failures)
	await _run_case(2, BottomBar.SelectionMode.WIDEN_GROW | BottomBar.SelectionMode.SWAP_ICON, "2按钮/WIDEN_GROW+SWAP_ICON", failures)
	await _run_case(2, BottomBar.SelectionMode.ICON_LIFT, "2按钮/ICON_LIFT", failures)
	await _run_case(5, BottomBar.SelectionMode.WIDEN, "5按钮/WIDEN", failures)
	await _run_case(5, BottomBar.SelectionMode.WIDEN_GROW | BottomBar.SelectionMode.SWAP_ICON, "5按钮/GROW+SWAP", failures)
	await _verify_home2(failures)

	print("")
	if failures.is_empty():
		print("=== ALL PASS ===")
	else:
		print("=== FAILURES (%d) ===" % failures.size())
		for f in failures:
			print("  - ", f)
	quit(0 if failures.is_empty() else 1)


func _run_case(tab_count: int, mode: int, tag: String, failures: Array[String]) -> void:
	var home: Control = load(HOME_SCENE).instantiate()
	home.demo_preset = Home.DemoPreset.TWO_TABS if tab_count == 2 else Home.DemoPreset.FIVE_TABS
	home.bottom_bar_selection_mode = mode
	root.add_child(home)
	await process_frame
	await process_frame

	var bar: BottomBar = home.get_node("BottomBar")
	# 这套用例验证容器级模式，清掉示例配置里的 per-tab 覆盖。
	for id: StringName in bar._order:
		bar.set_tab_selection_mode(id, -1)
	var ids: Array = bar._order.duplicate()
	if ids.size() != tab_count:
		failures.append("%s: 按钮数量应为 %d，实际 %d" % [tag, tab_count, ids.size()])

	# 选中第一个 tab，等动画结束
	var first: StringName = ids[0]
	bar.select(first, false)
	await process_frame
	# 再切到第二个 tab 并用动画，然后等动画跑完，验证稳态与过渡都正常
	if ids.size() > 1:
		bar.select(ids[1], true)
		await create_timer(bar.transition_duration + 0.15).timeout
		# 回到第一个，用动画走一遍（验证过渡后能落回正确值）
		bar.select(first, true)
		await create_timer(bar.transition_duration + 0.15).timeout
	await process_frame

	var total_w := 0.0
	var widths: Array[float] = []
	var grows: Array[float] = []
	for id in ids:
		var b: BottomTabButton = bar.get_button(id)
		widths.append(b.size.x)
		grows.append(b.current_grow)
		total_w += b.size.x

	var widen := (mode & BottomBar.SelectionMode.WIDEN) != 0 or (mode & BottomBar.SelectionMode.WIDEN_GROW) != 0
	var grow_expected := (mode & BottomBar.SelectionMode.WIDEN_GROW) != 0
	var swap_expected := (mode & BottomBar.SelectionMode.SWAP_ICON) != 0

	# 宽度断言
	if widen:
		var expect_selected := bar.size.x * bar.selected_weight / (bar.selected_weight + bar.normal_weight * (tab_count - 1))
		if absf(widths[0] - expect_selected) > 1.5:
			failures.append("%s: 选中宽应≈%.1f，实际 %.1f" % [tag, expect_selected, widths[0]])
		if widths[0] <= widths[1]:
			failures.append("%s: 选中项未变宽 (%.1f vs %.1f)" % [tag, widths[0], widths[1]])
	else:
		var even := bar.size.x / float(tab_count)
		if absf(widths[0] - even) > 1.5:
			failures.append("%s: 非变宽模式宽度应均匀≈%.1f，实际 %.1f" % [tag, even, widths[0]])

	# 高度断言
	if grow_expected:
		if grows[0] <= 0.5:
			failures.append("%s: 选中项应向上长高，实际 grow=%.2f" % [tag, grows[0]])
		if absf(grows[0] - bar.selected_grow_height) > 1.5:
			failures.append("%s: 长高应≈%.1f，实际 %.2f" % [tag, bar.selected_grow_height, grows[0]])
		if grows[1] > 0.5:
			failures.append("%s: 未选中项不应长高，实际 grow=%.2f" % [tag, grows[1]])
	else:
		for i in range(grows.size()):
			if grows[i] > 0.5:
				failures.append("%s: 未启用变高时 grow 应为 0，实际[%d]=%.2f" % [tag, i, grows[i]])

	# 换图断言（贴图与代码绘制两种图标都支持）
	var b0: BottomTabButton = bar.get_button(first)
	if swap_expected:
		if not b0.swap_icon_enabled:
			failures.append("%s: 换图开关未下发到按钮" % tag)
		if b0.icon_texture != null:
			if b0.selected_icon_texture == null:
				failures.append("%s: 贴图配置缺少 selected_icon_texture" % tag)
			elif b0._active_icon_texture() != b0.selected_icon_texture:
				failures.append("%s: 选中后贴图未切换" % tag)
		elif b0.selected_icon_style == "":
			failures.append("%s: 配置缺少 selected_icon" % tag)
		elif b0._active_icon_style() != b0.selected_icon_style:
			failures.append("%s: 选中后图标应切到 %s，实际 %s" % [tag, b0.selected_icon_style, b0._active_icon_style()])
	else:
		if b0.swap_icon_enabled:
			failures.append("%s: 未启用换图时开关不应打开" % tag)
		if b0.icon_texture != null:
			if b0._active_icon_texture() != b0.icon_texture:
				failures.append("%s: 未启用换图时贴图不应变化" % tag)
		elif b0._active_icon_style() != b0.icon_style:
			failures.append("%s: 未启用换图时图标不应变化" % tag)

	# 总宽应铺满
	if absf(total_w - bar.size.x) > 2.0:
		failures.append("%s: 总宽应铺满 %.1f，实际 %.1f" % [tag, bar.size.x, total_w])

	var growth_str := "%.1f" % grows[0]
	var icon_tag := "texture" if b0.icon_texture != null else b0._active_icon_style()
	print("[%s] 数量=%d 宽=%.1f/%.1f grow=%s 图标=%s 模式=%d" % [
		tag, ids.size(), widths[0], widths[1] if widths.size() > 1 else 0.0,
		growth_str, icon_tag, mode
	])

	home.queue_free()
	await process_frame


## 验证独立 home2.tscn：只有 2 个按钮，两个按钮跟随容器的 ICON_LIFT 设置。
func _verify_home2(failures: Array[String]) -> void:
	var home: Control = load("res://home/home2.tscn").instantiate()
	root.add_child(home)
	await process_frame
	await process_frame

	var bar: BottomBar = home.get_node("BottomBar")
	var ids: Array = bar._order.duplicate()
	if ids.size() != 2:
		failures.append("home2: 按钮数量应为 2，实际 %d" % ids.size())
	if ids.size() < 2:
		home.queue_free()
		return

	var first: StringName = ids[0]
	var second: StringName = ids[1]
	var b0: BottomTabButton = bar.get_button(first)
	var b1: BottomTabButton = bar.get_button(second)
	# 两个按钮都跟随容器设置：ICON_LIFT，不应含 WIDEN / WIDEN_GROW。
	var expected := BottomBar.SelectionMode.ICON_LIFT
	if b0.effective_selection_mode != expected:
		failures.append("home2: 探索按钮效果应为 %d，实际 %d" % [expected, b0.effective_selection_mode])
	if b1.effective_selection_mode != expected:
		failures.append("home2: 背包按钮效果应为 %d，实际 %d" % [expected, b1.effective_selection_mode])
	if not b0.has_effect(BottomBar.SelectionMode.ICON_LIFT) or not b1.has_effect(BottomBar.SelectionMode.ICON_LIFT):
		failures.append("home2: 两个按钮都应启用图标放大上移")
	for b: BottomTabButton in [b0, b1]:
		if b.icon_texture == null or b.selected_icon_texture == null:
			failures.append("home2: 图标前景贴图未配置")
		if b.normal_bg_texture == null or b.selected_bg_texture == null:
			failures.append("home2: 灰/黄按钮状态图未配置")
		if b.icon_lift_scale <= 1.0 or b.icon_lift_offset <= 0.0:
			failures.append("home2: 图标放大上移参数无效")

	bar.select(second, true)
	await create_timer(bar.transition_duration + 0.15).timeout
	await process_frame

	# ICON_LIFT 不改变宽度和高度：两个按钮始终各占 50%，不生长。
	if absf(b0.size.x - bar.size.x * 0.5) > 1.5 or absf(b1.size.x - bar.size.x * 0.5) > 1.5:
		failures.append("home2: ICON_LIFT 下按钮应各占 50%%，实际 %.1f/%.1f" % [b0.size.x, b1.size.x])
	if b0.current_grow > 0.01 or b1.current_grow > 0.01:
		failures.append("home2: ICON_LIFT 下不应向上长高，实际 %.2f/%.2f" % [b0.current_grow, b1.current_grow])
	if absf(b1.visual_selected - 1.0) > 0.01 or absf(b0.visual_selected) > 0.01:
		failures.append("home2: 选中动画未落到稳态，实际 %.2f/%.2f" % [b0.visual_selected, b1.visual_selected])
	if b1._active_icon_texture() != b1.icon_texture:
		failures.append("home2: 非换图模式下前景图标不应变化")

	print("[home2] 数量=2 宽=%.1f/%.1f grow=%.1f/%.1f 模式=%d/%d" % [
		b0.size.x, b1.size.x, b0.current_grow, b1.current_grow,
		b0.effective_selection_mode, b1.effective_selection_mode
	])

	home.queue_free()
	await process_frame
