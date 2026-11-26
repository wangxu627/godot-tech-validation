shader_type canvas_item;
render_mode blend_mix;

// 滚动条当前显示的起始位置（像素）。
uniform float scroll_y_px = 0.0;
// 由 10 个数字拼接出的完整滚动条高度。
uniform float strip_height_px = 1290.0;
// 可视窗口高度（一个数字格）。
uniform float view_height_px = 129.0;
// 运动模糊强度，由滚轮速度在运行时驱动。
uniform float blur_px = 0.0;

const int MAX_SAMPLES = 12;

void fragment() {
	// 把 TextureRect 的局部 UV 换算成整条数字带上的 UV，
	// 这样模糊采样可以跨过相邻数字，得到真正的纵向拖影。
	float base_y = (scroll_y_px + UV.y * view_height_px) / max(strip_height_px, 1.0);

	vec4 accum = vec4(0.0);
	float weight_sum = 0.0;

	for (int i = 0; i < MAX_SAMPLES; i++) {
		float t = (float(i) - float(MAX_SAMPLES - 1) * 0.5) / float(MAX_SAMPLES - 1);
		float y = fract(base_y + t * blur_px / max(strip_height_px, 1.0));
		float weight = 1.0 - abs(t) * 0.6;
		accum += texture(TEXTURE, vec2(UV.x, y)) * weight;
		weight_sum += weight;
	}

	COLOR = accum / max(weight_sum, 0.0001);
}
