package game
import rl "vendor:raylib"

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
