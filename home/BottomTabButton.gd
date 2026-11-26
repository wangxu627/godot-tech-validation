class_name BottomTabButton
extends Control

## BottomBar 中的单个 Tab。
## 宽度由 BottomBar 通过 weight 统一分配，高度增长由 grow_target 驱动，
## 本组件只负责视觉状态、图标切换与点击输入。

signal tab_pressed(tab_id: StringName)

## 选中效果位标志，数值与 BottomBar.SelectionMode 保持一致。
## 这里用独立常量，避免 BottomBar 与按钮之间产生 class_name 循环引用。
const EFFECT_WIDEN := 1
const EFFECT_GROW := 2
const EFFECT_SWAP_ICON := 4
const EFFECT_ICON_SCALE := 8
const EFFECT_ICON_LIFT := 16

@export var tab_id: StringName = &""
@export var label_text: String = ""
@export var icon_style: String = "base"
## 选中态图标；与 icon_style 不同时，SWAP_ICON 模式会切到它。
@export var selected_icon_style: String = ""
@export var enabled: bool = true

@export var normal_bg: Color = Color(0.09, 0.10, 0.13, 1)
@export var selected_bg: Color = Color(0.20, 0.16, 0.07, 1)
@export var normal_icon_color: Color = Color(0.62, 0.68, 0.78, 1)
@export var selected_icon_color: Color = Color(1.0, 0.92, 0.60, 1)
@export var accent_color: Color = Color(1.0, 0.72, 0.18, 1)

## 选中视觉进度（0=未选中，1=选中）。setter 里触发重绘，
## 保证纯图标动画（如 ICON_LIFT 不改变宽度时）也能实时刷新底栏。
var visual_selected: float = 0.0:
	get:
		return _visual_selected
	set(value):
		if not is_equal_approx(_visual_selected, value):
			_visual_selected = value
			queue_redraw()

@export var weight: float = 1.0

## 由 BottomBar 写入：选中时希望向上长出的高度（像素），0 表示不变高。
@export var grow_target: float = 0.0
## 由 BottomBar 写入：变高动画时长，应与之宽度动画一致。
@export var grow_duration: float = 0.36
## 由 BottomBar 写入：是否启用换图（SWAP_ICON 模式）。
@export var swap_icon_enabled: bool = false
## 单个 Tab 可覆盖容器级效果；-1 表示跟随 BottomBar.selection_mode。
@export var selection_mode_override: int = -1
## 由 BottomBar 写入：本按钮最终生效的效果位标志。
@export var effective_selection_mode: int = EFFECT_WIDEN
## ICON_SCALE 模式下，选中时图标放大的倍率。
@export var selected_icon_scale: float = 1.35
## ICON_LIFT 模式下，选中时图标放大的倍率。
@export var icon_lift_scale: float = 1.28
## ICON_LIFT 模式下，选中时图标向上移动的距离（像素）；取消选中时回到居中位置。
@export var icon_lift_offset: float = 18.0

## 可选贴图：设置后优先于代码绘制的背景色/图标。
@export var normal_bg_texture: Texture2D
@export var selected_bg_texture: Texture2D
@export var icon_texture: Texture2D
@export var selected_icon_texture: Texture2D
## 按钮状态图的九宫格边距（源图像素）。
@export var patch_left: float = 15.0
@export var patch_right: float = 15.0
@export var patch_top: float = 22.0
@export var patch_bottom: float = 20.0
## 源图四周需要裁掉的深色描边宽度（源图像素）。这两张按钮图边缘自带约 7px
## 深色描边，不裁掉的话相邻按钮之间会出现深色缝。绘制时从采样区里跳过它。
@export var patch_trim_left: float = 0.0
@export var patch_trim_right: float = 0.0
@export var patch_trim_top: float = 0.0
@export var patch_trim_bottom: float = 0.0
## 贴图图标的最大绘制尺寸（像素），会按原图比例缩放。
@export var icon_max_width: float = 104.0
@export var icon_max_height: float = 104.0
## 背景绘制的左右内边距（像素）。设为 0 让相邻按钮背景铺满、无缝拼接。
@export var bg_inset_x: float = 0.0
## 背景绘制的上下内边距（像素）。设为 0 让背景铺满 BottomBar 高度。
@export var bg_inset_y: float = 0.0

var _selected: bool = false
var _visual_selected: float = 0.0
var _visual_tween: Tween = null
var _grow_tween: Tween = null
var _current_grow: float = 0.0


## 当前实际生长高度，供 BottomBar 布局读取。
var current_grow: float:
	get:
		return _current_grow


## 高度动画是否仍在进行，BottomBar 据此决定是否重排。
func is_grow_animating() -> bool:
	return _grow_tween != null and _grow_tween.is_valid() and _grow_tween.is_running()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func configure(data: Dictionary) -> void:
	tab_id = data.get("id", &"")
	label_text = str(data.get("label", ""))
	icon_style = str(data.get("icon", "base"))
	selected_icon_style = str(data.get("selected_icon", selected_icon_style))
	enabled = bool(data.get("enabled", true))
	normal_bg = data.get("normal_bg", normal_bg)
	selected_bg = data.get("selected_bg", selected_bg)
	normal_icon_color = data.get("normal_icon_color", normal_icon_color)
	selected_icon_color = data.get("selected_icon_color", selected_icon_color)
	accent_color = data.get("accent_color", accent_color)
	selection_mode_override = int(data.get("selection_mode", -1))
	selected_icon_scale = float(data.get("selected_icon_scale", selected_icon_scale))
	icon_lift_scale = float(data.get("icon_lift_scale", icon_lift_scale))
	icon_lift_offset = float(data.get("icon_lift_offset", icon_lift_offset))
	bg_inset_x = float(data.get("bg_inset_x", bg_inset_x))
	bg_inset_y = float(data.get("bg_inset_y", bg_inset_y))
	patch_trim_left = float(data.get("patch_trim_left", patch_trim_left))
	patch_trim_right = float(data.get("patch_trim_right", patch_trim_right))
	patch_trim_top = float(data.get("patch_trim_top", patch_trim_top))
	patch_trim_bottom = float(data.get("patch_trim_bottom", patch_trim_bottom))

	var tex = data.get("normal_bg_texture", null)
	if tex is Texture2D:
		normal_bg_texture = tex
	tex = data.get("selected_bg_texture", null)
	if tex is Texture2D:
		selected_bg_texture = tex
	tex = data.get("icon_texture", null)
	if tex is Texture2D:
		icon_texture = tex
	tex = data.get("selected_icon_texture", null)
	if tex is Texture2D:
		selected_icon_texture = tex


## 判断本 Tab 最终是否启用了某种选中效果。
func has_effect(flag: int) -> bool:
	return (effective_selection_mode & flag) != 0


func set_selected(
	value: bool,
	animated: bool,
	duration: float,
	trans: Tween.TransitionType,
	ease: Tween.EaseType
) -> void:
	_selected = value
	var target := 1.0 if value else 0.0

	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()

	if not animated or duration <= 0.0:
		visual_selected = target
		queue_redraw()
		return

	_visual_tween = create_tween()
	var tweener := _visual_tween.tween_property(self, "visual_selected", target, duration)
	tweener.set_trans(trans)
	tweener.set_ease(ease)


func is_selected() -> bool:
	return _selected


## 当前应绘制的图标风格：换图模式下选中时用 selected_icon_style。
func _active_icon_style() -> String:
	if has_effect(EFFECT_SWAP_ICON) and selected_icon_style != "" and _selected:
		return selected_icon_style
	return icon_style


## 贴图图标：SWAP_ICON 模式下选中时优先用 selected_icon_texture。
func _active_icon_texture() -> Texture2D:
	if has_effect(EFFECT_SWAP_ICON) and selected_icon_texture != null and _selected:
		return selected_icon_texture
	return icon_texture


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			tab_pressed.emit(tab_id)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			accept_event()
			tab_pressed.emit(tab_id)


## 由 BottomBar 在切换选中时调用，让高度变化与宽度动画同步。
func set_grow(value: float, animated: bool, duration: float, trans: Tween.TransitionType, ease: Tween.EaseType) -> void:
	grow_target = value

	if _grow_tween != null and _grow_tween.is_valid():
		_grow_tween.kill()
		_grow_tween = null

	if not animated or duration <= 0.0:
		_current_grow = value
		queue_redraw()
		return

	_grow_tween = create_tween()
	var tweener := _grow_tween.tween_property(self, "_current_grow", value, duration)
	tweener.set_trans(trans)
	tweener.set_ease(ease)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(_delta: float) -> void:
	# 高度变化由 tween 直接写 _current_grow，这里只需在变化时重绘。
	if not is_equal_approx(_current_grow, grow_target):
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(bg_inset_x, bg_inset_y, maxf(size.x - bg_inset_x * 2.0, 1.0), maxf(size.y - bg_inset_y * 2.0, 1.0))

	var use_texture_bg := normal_bg_texture != null and selected_bg_texture != null
	var bg_alpha := 0.45 if not enabled else 1.0

	if use_texture_bg:
		if visual_selected < 0.999:
			_draw_nine_patch(normal_bg_texture, rect, Color(1, 1, 1, (1.0 - visual_selected) * bg_alpha))
		if visual_selected > 0.001:
			_draw_nine_patch(selected_bg_texture, rect, Color(1, 1, 1, visual_selected * bg_alpha))
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = normal_bg.lerp(selected_bg, visual_selected)
		style.set_corner_radius_all(12)
		var border := int(round(lerpf(1.0, 3.0, visual_selected)))
		style.border_width_left = border
		style.border_width_top = border
		style.border_width_right = border
		style.border_width_bottom = border
		style.border_color = accent_color.lerp(Color(1.0, 0.86, 0.25, 1), visual_selected)
		style.shadow_color = Color(0, 0, 0, 0.38)
		style.shadow_size = 4
		draw_style_box(style, rect)

	if not use_texture_bg and visual_selected > 0.02:
		var glow := Color(1.0, 0.84, 0.24, 0.95 * visual_selected)
		draw_rect(Rect2(rect.position.x + 12, rect.position.y + 6, maxf(rect.size.x - 24, 1), 4), glow)
		_draw_chevron(Vector2(rect.position.x + 8, size.y * 0.46), -1, glow)
		_draw_chevron(Vector2(rect.end.x - 8, size.y * 0.46), 1, glow)

	var icon_color := normal_icon_color.lerp(selected_icon_color, visual_selected)
	var alpha := lerpf(0.75, 1.0, visual_selected)
	if not enabled:
		alpha *= 0.35
	icon_color.a = alpha

	var effect_scale := 1.0
	var lift := 0.0
	if has_effect(EFFECT_ICON_SCALE):
		effect_scale *= lerpf(1.0, selected_icon_scale, visual_selected)
	if has_effect(EFFECT_ICON_LIFT):
		effect_scale *= lerpf(1.0, icon_lift_scale, visual_selected)
		# 选中时上移；取消选中时 visual_selected 回到 0，图标下移回居中位置。
		lift = -icon_lift_offset * visual_selected

	var tex := _active_icon_texture()
	var icon_center := Vector2(size.x * 0.5, size.y * (0.44 if tex != null else 0.42) + lift)
	if tex != null:
		_draw_texture_icon(tex, icon_center, effect_scale, alpha)
	else:
		var icon_scale := clampf(minf(size.x, size.y) / 110.0, 0.55, 1.25) * effect_scale
		_draw_icon(icon_center, icon_scale, icon_color)

	var label_alpha := lerpf(0.45, 1.0, visual_selected)
	if not enabled:
		label_alpha *= 0.35
	var label_color := Color(1, 1, 1, label_alpha)
	var font := ThemeDB.fallback_font
	var font_size := int(round(lerpf(17.0, 22.0, visual_selected)))
	draw_string(
		font,
		Vector2(0, size.y - 13),
		label_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		font_size,
		label_color
	)


## 九宫格绘制按钮状态图，避免把窄图横向拉伸导致圆角变形。
func _draw_nine_patch(tex: Texture2D, rect: Rect2, modulate: Color) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	if tw <= 0.0 or th <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	# 先从采样区裁掉源图自带的深色描边，再在“有效图”上做九宫格切片。
	var tl := clampf(patch_trim_left, 0.0, tw * 0.4)
	var tr := clampf(patch_trim_right, 0.0, tw * 0.4)
	var tt := clampf(patch_trim_top, 0.0, th * 0.4)
	var tb := clampf(patch_trim_bottom, 0.0, th * 0.4)
	var ew := tw - tl - tr   # 有效图宽度
	var eh := th - tt - tb   # 有效图高度
	if ew <= 0.0 or eh <= 0.0:
		return

	var l := clampf(patch_left, 0.0, ew * 0.45)
	var r := clampf(patch_right, 0.0, ew * 0.45)
	var t := clampf(patch_top, 0.0, eh * 0.45)
	var b := clampf(patch_bottom, 0.0, eh * 0.45)

	if rect.size.x < l + r:
		var hscale := rect.size.x / (l + r)
		l *= hscale
		r *= hscale
	if rect.size.y < t + b:
		var vscale := rect.size.y / (t + b)
		t *= vscale
		b *= vscale

	var cw := rect.size.x - l - r
	var ch := rect.size.y - t - b
	var sx := ew - l - r
	var sy := eh - t - b
	var x := rect.position.x
	var y := rect.position.y

	draw_texture_rect_region(tex, Rect2(x, y, l, t), Rect2(tl, tt, l, t), modulate)
	draw_texture_rect_region(tex, Rect2(x + l, y, cw, t), Rect2(tl + l, tt, sx, t), modulate)
	draw_texture_rect_region(tex, Rect2(x + l + cw, y, r, t), Rect2(tl + l + sx, tt, r, t), modulate)

	draw_texture_rect_region(tex, Rect2(x, y + t, l, ch), Rect2(tl, tt + t, l, sy), modulate)
	draw_texture_rect_region(tex, Rect2(x + l, y + t, cw, ch), Rect2(tl + l, tt + t, sx, sy), modulate)
	draw_texture_rect_region(tex, Rect2(x + l + cw, y + t, r, ch), Rect2(tl + l + sx, tt + t, r, sy), modulate)

	draw_texture_rect_region(tex, Rect2(x, y + t + ch, l, b), Rect2(tl, tt + t + sy, l, b), modulate)
	draw_texture_rect_region(tex, Rect2(x + l, y + t + ch, cw, b), Rect2(tl + l, tt + t + sy, sx, b), modulate)
	draw_texture_rect_region(tex, Rect2(x + l + cw, y + t + ch, r, b), Rect2(tl + l + sx, tt + t + sy, r, b), modulate)


## 按比例绘制贴图图标，effect_scale 由选中动画驱动。
func _draw_texture_icon(tex: Texture2D, center: Vector2, scale: float, alpha: float) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	if tw <= 0.0 or th <= 0.0 or scale <= 0.0:
		return
	var fit := minf(icon_max_width / tw, icon_max_height / th)
	var w := tw * fit * scale
	var h := th * fit * scale
	draw_texture_rect(
		tex,
		Rect2(center.x - w * 0.5, center.y - h * 0.5, w, h),
		false,
		Color(1, 1, 1, alpha)
	)


func _draw_chevron(center: Vector2, direction: int, color: Color) -> void:
	var tip := center + Vector2(9 * direction, 0)
	var back := center + Vector2(-7 * direction, 0)
	var polygon := PackedVector2Array([
		tip,
		back + Vector2(0, -11),
		back + Vector2(0, 11),
	])
	draw_colored_polygon(polygon, color)


func _draw_icon(center: Vector2, s: float, color: Color) -> void:
	match _active_icon_style():
		"hero":
			_draw_hero_icon(center, s, color)
		"planet":
			_draw_planet_icon(center, s, color)
		"gift":
			_draw_gift_icon(center, s, color)
		"shop":
			_draw_shop_icon(center, s, color)
		_:
			_draw_base_icon(center, s, color)


func _draw_base_icon(center: Vector2, s: float, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-27, -20) * s, Vector2(54, 42) * s), color)
	draw_rect(Rect2(center + Vector2(-21, -13) * s, Vector2(14, 11) * s), Color(0.1, 0.13, 0.17, color.a))
	draw_rect(Rect2(center + Vector2(-3, -13) * s, Vector2(14, 11) * s), Color(0.1, 0.13, 0.17, color.a))
	draw_rect(Rect2(center + Vector2(15, -13) * s, Vector2(8, 11) * s), Color(0.1, 0.13, 0.17, color.a))
	draw_rect(Rect2(center + Vector2(-21, 8) * s, Vector2(42, 6) * s), Color(0.1, 0.13, 0.17, color.a))


func _draw_hero_icon(center: Vector2, s: float, color: Color) -> void:
	draw_circle(center + Vector2(0, -16) * s, 13 * s, color)
	var polygon := PackedVector2Array([
		center + Vector2(-22, 26) * s,
		center + Vector2(0, -4) * s,
		center + Vector2(22, 26) * s,
	])
	draw_colored_polygon(polygon, color)


func _draw_planet_icon(center: Vector2, s: float, color: Color) -> void:
	draw_circle(center + Vector2(0, -3) * s, 22 * s, color)
	draw_arc(center + Vector2(0, -3) * s, 31 * s, 0.15 * PI, 0.85 * PI, 24, color, 4 * s, true)
	draw_arc(center + Vector2(0, -3) * s, 31 * s, 1.15 * PI, 1.85 * PI, 24, color, 4 * s, true)
	draw_circle(center + Vector2(21, -22) * s, 5 * s, Color(0.95, 0.35, 0.32, color.a))


func _draw_gift_icon(center: Vector2, s: float, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-24, -10) * s, Vector2(48, 38) * s), color)
	draw_rect(Rect2(center + Vector2(-4, -10) * s, Vector2(8, 38) * s), Color(0.98, 0.66, 0.18, color.a))
	draw_rect(Rect2(center + Vector2(-24, 2) * s, Vector2(48, 7) * s), Color(0.98, 0.66, 0.18, color.a))
	draw_circle(center + Vector2(-10, -15) * s, 8 * s, color)
	draw_circle(center + Vector2(10, -15) * s, 8 * s, color)


func _draw_shop_icon(center: Vector2, s: float, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-24, -8) * s, Vector2(48, 40) * s), color)
	draw_arc(center + Vector2(0, -8) * s, 14 * s, PI, TAU, 20, color, 4 * s, true)
	draw_rect(Rect2(center + Vector2(-15, 7) * s, Vector2(30, 5) * s), Color(0.1, 0.13, 0.17, color.a))
