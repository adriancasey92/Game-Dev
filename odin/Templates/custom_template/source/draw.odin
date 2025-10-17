package game
import "core:fmt"
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

//Takes the exact position text needs to be right-aligned to and measures text
//width before drawing
draw_text_right_aligned_spacing :: proc(
	text: cstring,
	x, y, font_size: i32,
	color: rl.Color,
	spacing: f32,
) {
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), MENU_SPACING)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		text,
		{f32(x) - text_size.x, f32(y)},
		f32(font_size),
		spacing,
		color,
	)
}

draw_visual_chunk :: proc(coord: ChunkCoord, chunk: Visual_Chunk, camera: rl.Camera2D) {
	// Calculate world position of chunk (your existing logic)
	chunk_world_pos := chunk_to_world_pos(coord)

	// Convert world position to screen position
	//chunk_screen_pos := world_to_screen(chunk_world_pos)

	// Draw the sprite grid
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			sprite_id := chunk.sprites[y][x]
			if sprite_id != .NONE {
				x_pos := x * TILE_SIZE - (CHUNK_SIZE * TILE_SIZE / 2)
				y_pos :=
					y - (y * TILE_SIZE) - int((coord.y * (TILE_SIZE * CHUNK_SIZE))) - TILE_SIZE
				//fmt.printf("Printing tile at pos [x,y]: [%i,%i]\n", x_pos, y_pos)
				// Calculate tile position in world space
				//tile_world_pos := chunk_world_pos + {f32(x * TILE_SIZE), f32(y * TILE_SIZE)}

				// Convert to screen space for Raylib


				draw_sprite_at_screen_pos(sprite_id, Vec2{f32(x_pos), f32(y_pos)})
			}
		}
	}

	rl.DrawPixel(0,0,rl.BLACK)
	/*
	// Handle entities and decorations similarly
	for entity in chunk.entities {
		entity_screen_pos := world_to_screen(entity.pos, camera)
		draw_sprite_at_screen_pos(entity.sprite, entity_screen_pos)
	}

	for decoration in chunk.decorations {
		decoration_screen_pos := world_to_screen(decoration.pos, camera)
		draw_sprite_at_screen_pos(decoration.sprite, decoration_screen_pos)
	}*/
}


draw_tile :: proc(sprite_id: Sprite_ID, tile_pos: Vec2) {
	//fmt.printf("Draw_tile %v\n", tile_pos)
	col := rl.PINK
	#partial switch sprite_id 
	{
	case .GRASS_TILE:
		col = rl.GREEN
	case .STONE_TILE:
		col = rl.GRAY
	}

	rl.DrawRectangleRec({tile_pos.x, tile_pos.y, TILE_SIZE, TILE_SIZE}, col)

}

draw_sprite_at_screen_pos :: proc(sprite_id: Sprite_ID, pos: Vec2) {

	col := rl.PINK
	#partial switch sprite_id 
	{
	case .GRASS_TILE:
		col = rl.GREEN
	case .STONE_TILE:
		col = rl.GRAY
	case:

	}

	rl.DrawRectangleRec({pos.x, pos.y, TILE_SIZE, TILE_SIZE}, col)
}
