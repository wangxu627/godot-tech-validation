class_name DemoPage
extends HomePageBase

## 5 个示例页面共用的占位页面。
## 通过 enter_style 展示不同入场动画；业务页面可继承 HomePageBase 自行实现。

enum EnterStyle {
	FADE,
	SLIDE_RIGHT,
	SCALE,
	SLIDE_UP,
	NONE,
}

@export var page_title: String = "示例页面"
@export var subtitle: String = "用于验证页面切换与入场动画"
@export var badge_text: String = "PAGE"
@export var background_color: Color = Color(0.06, 0.12, 0.22, 1)
@export var accent_color: Color = Color(0.20, 0.72, 1.0, 1)
@export var enter_style: EnterStyle = EnterStyle.FADE

@onready var _background: ColorRect = $Background
@onready var _glow: ColorRect = $Glow
@onready var _badge: Label = $Center/Badge
@onready var _title: Label = $Center/Title
@onready var _subtitle: Label = $Center/Subtitle
@onready var _hint: Label = $Center/Hint


func _ready() -> void:
	_background.color = background_color
	_glow.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.16)
	_badge.text = badge_text
	_title.text = page_title
	_subtitle.text = subtitle
	_hint.text = "动画：" + str(EnterStyle.keys()[enter_style])
	_update_pivot()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func on_enter_animation() -> void:
	match enter_style:
		EnterStyle.FADE:
			super.on_enter_animation()
		EnterStyle.SLIDE_RIGHT:
			_tween_enter(Vector2(minf(size.x * 0.38, 280.0), 0), 0.46, false)
		EnterStyle.SCALE:
			_tween_enter(Vector2.ZERO, 0.44, true)
		EnterStyle.SLIDE_UP:
			_tween_enter(Vector2(0, minf(size.y * 0.12, 140.0)), 0.44, false)
		EnterStyle.NONE:
			notify_enter_animation_finished()


func _tween_enter(offset: Vector2, duration: float, use_scale: bool) -> void:
	var tween := _begin_animation().set_parallel(true)
	tween.tween_property(self, "position", Vector2.ZERO, duration).from(offset)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), duration).from(Color(1, 1, 1, 0.25))
	if use_scale:
		tween.tween_property(self, "scale", Vector2.ONE, duration).from(Vector2(0.82, 0.82))
	tween.finished.connect(notify_enter_animation_finished)
