extends Control
class_name SlotNumberReel

## 老虎机数字滚轮。
## 素材是一张 4 列 x 3 行的数字图集：0,1,2,3 / 4,5,6,7 / 8,9。
## 运行时把 0~9 裁剪拼接成一条循环数字带，并通过滚动 region_rect 实现转动。

signal spin_finished(value: int)

@export var atlas_texture: Texture2D
@export var cell_size: Vector2 = Vector2(102, 129)
@export_range(1, 8, 1) var columns: int = 4
@export_range(0, 10, 1) var min_turns: int = 3
@export var spin_speed: float = 1500.0
@export_range(0.0, 60.0, 0.5) var max_blur_px: float = 26.0
@export var blur_speed_reference: float = 1800.0
@export_range(0, 9, 1) var target_number: int = 0

@onready var _reel_texture: TextureRect = $ReelTexture

var _strip_height: float = 0.0
var _scroll_y: float = 0.0
var _start_y: float = 0.0
var _distance: float = 0.0
var _duration: float = 0.0
var _elapsed: float = 0.0
var _spinning: bool = false
var _material: ShaderMaterial = null


func _ready() -> void:
	# 每个滚轮必须持有独立材质，否则多个实例会共享同一组 shader uniform。
	_material = (_reel_texture.material as ShaderMaterial).duplicate()
	_reel_texture.material = _material
	if atlas_texture == null:
		push_error("SlotNumberReel: atlas_texture 未设置。")
		return

	_build_strip()
	set_value(target_number)
	_layout()
	set_process(false)


func _build_strip() -> void:
	var cell_w: int = maxi(int(cell_size.x), 1)
	var cell_h: int = maxi(int(cell_size.y), 1)
	_strip_height = float(cell_h * 10)

	var src: Image = atlas_texture.get_image()
	var strip: Image = Image.create(cell_w, cell_h * 10, false, Image.FORMAT_RGBA8)

	for digit in range(10):
		var sx: int = (digit % columns) * cell_w
		var sy: int = int(float(digit) / float(columns)) * cell_h
		var src_rect := Rect2i(sx, sy, cell_w, cell_h)
		var dst := Vector2i(0, digit * cell_h)
		strip.blit_rect(src.get_region(src_rect), Rect2i(0, 0, cell_w, cell_h), dst)

	var tex := ImageTexture.create_from_image(strip)
	_reel_texture.texture = tex

	if _material != null:
		_material.set_shader_parameter("strip_height_px", _strip_height)
		_material.set_shader_parameter("view_height_px", float(cell_h))
		_material.set_shader_parameter("blur_px", 0.0)


func _layout() -> void:
	var w: int = maxi(int(cell_size.x), 1)
	var h: int = maxi(int(cell_size.y), 1)
	_reel_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reel_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_reel_texture.position = Vector2((size.x - float(w)) * 0.5, (size.y - float(h)) * 0.5)
	_reel_texture.size = Vector2(w, h)
	_apply_scroll(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _reel_texture != null:
		_layout()


## 立即显示指定数字（接受任意整数，内部按 10 取模）。
func set_value(value: int) -> void:
	var digit := wrapi(value, 0, 10)
	target_number = digit
	_spinning = false
	set_process(false)
	_scroll_y = float(digit * maxi(int(cell_size.y), 1))
	_apply_scroll(0.0)


## 当前显示的数字。
func get_value() -> int:
	return wrapi(int(round(_scroll_y / maxf(cell_size.y, 1.0))), 0, 10)


func is_spinning() -> bool:
	return _spinning


## 转动并停在指定数字。duration <= 0 时按 spin_speed 自动计算时长。
func spin_to(value: int, duration: float = -1.0) -> void:
	if atlas_texture == null or _strip_height <= 0.0:
		return

	var digit := wrapi(value, 0, 10)
	target_number = digit

	_start_y = fmod(_scroll_y, _strip_height)
	if _start_y < 0.0:
		_start_y += _strip_height

	# 先算出沿正方向到达目标数字格的距离，再补上整圈数。
	var target_y := float(digit * maxi(int(cell_size.y), 1))
	var forward := target_y - _start_y
	if forward < 0.0:
		forward += _strip_height

	_distance = forward + float(maxi(min_turns, 0)) * _strip_height
	_duration = duration if duration > 0.0 else maxf(_distance / maxf(spin_speed, 1.0), 0.25)
	_elapsed = 0.0
	_spinning = true
	set_process(true)


func _process(delta: float) -> void:
	if not _spinning:
		return

	_elapsed += delta
	var t := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0) # 先快后慢，模拟机械减速。

	_scroll_y = fmod(_start_y + _distance * eased, _strip_height)
	if _scroll_y < 0.0:
		_scroll_y += _strip_height

	# 三次缓出的瞬时速度，用来驱动运动模糊强度。
	var speed := 3.0 * _distance * pow(1.0 - t, 2.0) / maxf(_duration, 0.001)
	var blur := clampf(speed / maxf(blur_speed_reference, 1.0) * max_blur_px, 0.0, max_blur_px)
	_apply_scroll(blur)

	if t >= 1.0:
		_spinning = false
		set_process(false)
		_scroll_y = float(target_number * maxi(int(cell_size.y), 1))
		_apply_scroll(0.0)
		spin_finished.emit(target_number)


func _apply_scroll(blur_px: float) -> void:
	if _reel_texture == null:
		return

	# 不依赖 TextureRect 的 region_rect（4.7 已移除），由着色器直接采样数字带指定区间。
	if _material != null:
		_material.set_shader_parameter("scroll_y_px", _scroll_y)
		_material.set_shader_parameter("blur_px", blur_px)
