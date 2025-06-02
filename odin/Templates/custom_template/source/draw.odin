package game
import rl "vendor:raylib"

draw_text_centered_spacing :: proc(
	text: cstring,
	x, y, font_size: i32,
	color: rl.Color,
	spacing: f32,
) {
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), spacing)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		text,
		{f32(x) - (text_size.x / 2), f32(y) - (text_size.y / 2)},
		f32(font_size),
		spacing,
		color,
	)
}

draw_text_centered :: proc(text: cstring, x, y, font_size: i32, color: rl.Color) {
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), 1)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		text,
		{f32(x) - (text_size.x / 2), f32(y) - (text_size.y / 2)},
		f32(font_size),
		1,
		color,
	)
}

draw_text_left_aligned_spacing :: proc(
	text: cstring,
	x, y, font_size: i32,
	color: rl.Color,
	spacing: f32,
) {
	//text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), 1)
	rl.DrawTextEx(rl.GetFontDefault(), text, {f32(x), f32(y)}, f32(font_size), spacing, color)
}

draw_text_left_aligned :: proc(text: cstring, x, y, font_size: i32, color: rl.Color) {
	//text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), 1)
	rl.DrawTextEx(rl.GetFontDefault(), text, {f32(x), f32(y)}, f32(font_size), 1, color)
}

draw_text_right_aligned_spacing :: proc(
	text: cstring,
	x, y, font_size: i32,
	color: rl.Color,
	spacing: f32,
) {
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), 1)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		text,
		{f32(x) - text_size.x, f32(y)},
		f32(font_size),
		spacing,
		color,
	)
}
