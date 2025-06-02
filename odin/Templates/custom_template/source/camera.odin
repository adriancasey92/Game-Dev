package game

import rl "vendor:raylib"

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	zoom := f32(h / (CAMERA_ZOOM_BASE * CAMERA_ZOOM_MULT))
	return {zoom = zoom, target = get_player().pos, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	//zoom := f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT
	return {}
}
