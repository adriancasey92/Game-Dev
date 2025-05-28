package game

import rl "vendor:raylib"

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	return {zoom = h / PIXEL_WINDOW_HEIGHT, target = get_player().pos, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	//zoom := f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT
	return {}
}
