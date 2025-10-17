package game

import hm "../handle_map"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// Camera that focuses on either the player, bounded by the current chunk
// or the center of the current chunk

game_camera :: proc() -> rl.Camera2D {
	return g.game_camera
}

// ui_camera used for editor
ui_camera :: proc() -> rl.Camera2D {
	//return {zoom = f32(rl.GetScreenHeight() / PIXEL_WINDOW_HEIGHT)}
	return g.game_camera
}

// returns true if the entity's bounding box is within the camera bounds
within_camera_bounds :: proc(entity_handle: Entity_Handle) -> bool {
	cam := game_camera()
	entity := hm.get(g.entities, entity_handle)
	pos := entity.pos
	size := entity.size

	left := pos.x - size.x / 2
	right := pos.x + size.x / 2
	top := pos.y - size.y / 2
	bottom := pos.y + size.y / 2

	cam_left := cam.target.x - (f32(rl.GetScreenWidth()) / 2) / cam.zoom
	cam_right := cam.target.x + (f32(rl.GetScreenWidth()) / 2) / cam.zoom
	cam_top := cam.target.y - (f32(rl.GetScreenHeight()) / 2) / cam.zoom
	cam_bottom := cam.target.y + (f32(rl.GetScreenHeight()) / 2) / cam.zoom

	return left < cam_right && right > cam_left && top < cam_bottom && bottom > cam_top
}

update_camera :: proc() {
	current_chunk := level.player_chunk

	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	zoom := f32(h / (CAMERA_ZOOM_BASE * CAMERA_ZOOM_MULT))
	g.game_camera = {
		zoom   = zoom,
		target = get_player().pos,
		offset = {w / 2, h / 2},
	}
}
