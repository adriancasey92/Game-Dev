package game

import hm "../handle_map"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

//Constants
CAMERA_ZOOM_BASE :: f32(400)
CAMERA_ZOOM: f32 = CAMERA_ZOOM_BASE
CAMERA_ZOOM_MULT: f32 = 1

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
	if entity == nil {
		fmt.printf("within_camera_bounds: Entity with handle %d not found\n", entity_handle)
		return false
	}
	pos := entity.pos
	size := entity.size

	left := pos.x - size.x / 2
	right := pos.x + size.x / 2
	top := pos.y - size.y / 2
	bottom := pos.y + size.y / 2

	cam_left := (cam.target.x - (f32(rl.GetScreenWidth()) / 2) / cam.zoom) - 8
	cam_right := (cam.target.x + (f32(rl.GetScreenWidth()) / 2) / cam.zoom) + 8
	cam_top := (cam.target.y - (f32(rl.GetScreenHeight()) / 2) / cam.zoom) - 8
	cam_bottom := (cam.target.y + (f32(rl.GetScreenHeight()) / 2) / cam.zoom) + 8

	return left < cam_right && right > cam_left && top < cam_bottom && bottom > cam_top
}

//Todo - Fix update camera to lock to chunks? 
update_camera :: proc() {
	current_chunk := level.player_chunk
	w := f32(CHUNK_SIZE * TILE_SIZE)
	h := f32(rl.GetScreenHeight())
	zoom := f32(h / (CAMERA_ZOOM_BASE * CAMERA_ZOOM_MULT))
	target := get_player().pos
	offset := Vec2{f32(rl.GetScreenWidth()) / 2, h / 1.5}
	g.game_camera = {
		zoom   = zoom,
		target = target,
		offset = offset,
	}
}
