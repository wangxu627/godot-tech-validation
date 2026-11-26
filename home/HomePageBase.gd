class_name HomePageBase
extends Control

## 主页页面基类。
## 业务页面只需继承并按需重写 on_enter / on_exit / on_enter_animation，
## 或通过 set_enter_animation_callback() 注入自定义入场动画，无需改动 BottomBar。

signal enter_animation_finished()

@export var page_id: StringName = &""
@export var keep_state_on_exit: bool = true

var enter_animation_callback: Callable = Callable()
var _animation_tween: Tween = null


func on_enter() -> void:
	visible = true
	set_process(true)
	modulate = Color(1, 1, 1, 1)
	position = Vector2.ZERO
	scale = Vector2.ONE


func on_exit() -> void:
	set_process(false)
	if not keep_state_on_exit:
		reset_state()


## 页面被回收状态时重写此方法。
func reset_state() -> void:
	pass


## 由外部配置注入的动画回调；Callable 无效时回退到 on_enter_animation()。
func set_enter_animation_callback(callback: Callable) -> void:
	enter_animation_callback = callback


## 由 Home 调用，统一入口。
func play_enter_animation() -> void:
	if enter_animation_callback.is_valid():
		enter_animation_callback.call()
	else:
		on_enter_animation()


## 默认入场动画：淡入 + 轻微上移。业务页面可重写此方法。
func _begin_animation() -> Tween:
	if _animation_tween != null and _animation_tween.is_valid():
		_animation_tween.kill()
	_animation_tween = create_tween()
	return _animation_tween


## Home 在切走页面时调用，避免新旧页面文字重叠。
func fade_out(duration: float) -> void:
	var tween := _begin_animation()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), maxf(duration, 0.01))


func on_enter_animation() -> void:
	var tween := _begin_animation().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.38).from(Color(1, 1, 1, 0))
	tween.tween_property(self, "position", Vector2.ZERO, 0.38).from(Vector2(0, 28))
	tween.finished.connect(_on_default_animation_finished)


func _on_default_animation_finished() -> void:
	enter_animation_finished.emit()


## 自定义动画结束时调用，通知外部动画已完成。
func notify_enter_animation_finished() -> void:
	enter_animation_finished.emit()
