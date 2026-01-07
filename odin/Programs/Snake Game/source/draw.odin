package game
import hm "../handle_map"
import "core:fmt"
import rl "vendor:raylib"

//ENTITIES
ENTITES_DRAWN: i32 = 0

draw_texture :: proc(
	texture_name: Texture_Name,
	pos: Vec2,
	fade: f32,
	flip_x: bool,
	flip_y: bool,
	rotation: f32,
) {
	tint_col := rl.WHITE

	texture := atlas_textures[texture_name]
	atlas_rect := texture.rect
	offset: Vec2

	//Normal	
	if rotation == 0 {
		offset = Vec2{texture.offset_left, texture.offset_top}
		//Rotated right
	} else if rotation == 90 {
		offset = Vec2{-texture.offset_top, texture.offset_left}
		//upside down
	} else if rotation == 180 {
		offset = Vec2{-texture.offset_right, -texture.offset_top}
		//rotated left
	} else if rotation == 270 {
		offset = Vec2{texture.offset_top, -texture.offset_left}
	}

	if flip_x {
		atlas_rect.width = -atlas_rect.width
		offset.x = texture.offset_right
	}
	if flip_y {
		atlas_rect.height = -atlas_rect.height
		offset.y = texture.offset_bottom
	}
	origin := Vec2{texture.document_size.x / 2, texture.document_size.y}
	dest := Rect{pos.x + offset.x, pos.y + offset.y, texture.rect.width, texture.rect.height}

	rl.DrawTexturePro(atlas, atlas_rect, dest, origin, rotation, tint_col)
}

draw_entities :: proc(fade: f32) {
	ENTITES_DRAWN = 0
	//iter := hm.make_iter(&g.entities)
	//     for e in hm.iter(&my_iter) {})
	for &item in g.entities.items {
		//Skips entity with idx 0
		if hm.skip(item) {continue}
		//Skips entity if it is not within camera bounds
		if within_camera_bounds(item.handle) == false {continue}
		draw_entity_generic(item.handle, fade)
		ENTITES_DRAWN += 1
	}
}

draw_entity_generic :: proc(entity_handle: Entity_Handle, fade: f32) {
	//fmt.printf("Drawing entity with handle %v\n", entity_handle)
	if !hm.valid(g.entities, entity_handle) {
		fmt.printf("Entity handle %v is not valid, cannot draw it\n", entity_handle)
		return
	}
	ent := hm.get(g.entities, entity_handle)

	if ent == nil {
		fmt.printf("Entity with handle %v not found\n", entity_handle)
		return
	}

	if ent.kind == .nil {
		fmt.printf("Entity with handle %v has no kind set, cannot draw it\n", entity_handle)
		return
	}

	anim_texture := animation_atlas_texture(ent.anim)
	atlas_rect := anim_texture.rect
	offset := Vec2{anim_texture.offset_left, anim_texture.offset_top}

	//flip is based on ent.direction, flipping offset accordingly
	if ent.flip_x {
		atlas_rect.width = -atlas_rect.width
		offset.x = anim_texture.offset_right
	}
	if ent.flip_y {
		atlas_rect.height = -atlas_rect.height
		offset.y = anim_texture.offset_bottom
	}

	//destination rect tells us where on screeen to draw the entity
	//adjusted by the offset
	dest := Rect {
		ent.pos.x + offset.x,
		ent.pos.y + offset.y,
		anim_texture.rect.width,
		anim_texture.rect.height,
	}

	//Handle rotation based on entity orientation
	rotation: f32
	/*switch (ent.orientation) 
	{
	case .norm:
		if ent.movement == .falling {
			if ent.dir == .right {
				dest.x -= 1
			} else {
				dest.x += 2
			}
		}
	case .rot_left:
		rotation = 270
		dest.x += (anim_texture.rect.width * .5) + 2
		dest.y -= (anim_texture.rect.width) + 2
	case .rot_right:
		rotation = 90
		dest.x -= (anim_texture.rect.width) + 2
		dest.y -= (anim_texture.rect.width * .5)
	case .upside_down:
		dest.y += (anim_texture.rect.height) * 2 + 3
		dest.x -= 1
	}*/
	rotation = f32(0)

	//The origin is the the center of the entity
	origin := Vec2 {
		anim_texture.document_size.x / 2,
		anim_texture.document_size.y - 1, // -1 because there's an outline in the player anim that takes an extra pixel
	}
	dest.y -= 1
	//rl.DrawRectangleLinesEx(dest, 1, rl.RED)
	//rl.DrawPixelV(origin, rl.BLUE)
	rl.DrawTexturePro(atlas, atlas_rect, dest, origin, rotation, rl.Fade(rl.WHITE, fade))

	//DEBUG - draw colliders
	if DEBUG_DRAW_COLLIDERS {draw_entity_colliders(entity_handle)}

}

draw_entity_colliders :: proc(entity_handle: Entity_Handle) {
	ent := hm.get(g.entities, entity_handle)

	rl.DrawRectangleLines(
		i32(ent.rect.x),
		i32(ent.rect.y),
		i32(ent.rect.width),
		i32(ent.rect.height),
		rl.BLUE,
	)
	rl.DrawRectangleRec(ent.feet_collider, rl.YELLOW)
	rl.DrawRectangleRec(ent.face_collider, rl.ORANGE)
	rl.DrawRectangleRec(ent.head_collider, rl.RED)
	rl.DrawRectangleLinesEx(ent.corner_collider, .25, rl.PINK)
	rl.DrawPixelV(ent.pos, rl.PURPLE)
}

draw_text_centered_spacing :: proc(
	text: cstring,
	x, y, font_size: i32,
	colour: rl.Color,
	spacing: f32,
	highlight: bool,
) {
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), spacing)

	if highlight {
		rl.DrawTextEx(
			rl.GetFontDefault(),
			text,
			{f32(x) - (text_size.x / 2), f32(y) - (text_size.y / 2)},
			f32(font_size),
			spacing,
			rl.YELLOW,
		)
		draw_texture(
			.Menu_Selection,
			{f32(x) - (text_size.x / 2 * 1.1), f32(y)},
			1,
			false,
			false,
			270,
		)
		draw_texture(
			.Menu_Selection,
			{f32(x) + (text_size.x / 2 * 1.1), f32(y)},
			1,
			false,
			false,
			90,
		)
	} else {
		rl.DrawTextEx(
			rl.GetFontDefault(),
			text,
			{f32(x) - (text_size.x / 2), f32(y) - (text_size.y / 2)},
			f32(font_size),
			spacing,
			colour,
		)
	}

}

draw_text_centered :: proc(text: cstring, x, y, font_size: i32, color: rl.Color, highlight: bool) {
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), 1)
	if highlight {
		rl.DrawTextEx(
			rl.GetFontDefault(),
			text,
			{f32(x) - (text_size.x / 2), f32(y) - (text_size.y / 2)},
			f32(font_size),
			1,
			rl.YELLOW,
		)
		draw_texture(
			.Menu_Selection,
			{f32(x) - (text_size.x / 2 * 1.1), f32(y)},
			1,
			false,
			false,
			270,
		)
		draw_texture(
			.Menu_Selection,
			{f32(x) + (text_size.x / 2 * 1.1), f32(y)},
			1,
			false,
			false,
			90,
		)
	} else {
		rl.DrawTextEx(
			rl.GetFontDefault(),
			text,
			{f32(x) - (text_size.x / 2), f32(y) - (text_size.y / 2)},
			f32(font_size),
			1,
			color,
		)
	}
}

draw_text_left_aligned_spacing :: proc(
	text: cstring,
	x, y, font_size: i32,
	color: rl.Color,
	spacing: f32,
	highlight: bool,
) {
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), 1)
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
	highlight: bool,
) {
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font_size), spacing)
	if highlight {
		rl.DrawTextEx(
			rl.GetFontDefault(),
			text,
			{f32(x) - (text_size.x), f32(y)},
			f32(font_size),
			spacing,
			rl.YELLOW,
		)
		draw_texture(.Menu_Selection, {f32(x) - (text_size.x), f32(y)}, 1, false, false, 270)
		draw_texture(.Menu_Selection, {f32(x) + (text_size.x), f32(y)}, 1, false, false, 90)
	} else {
		rl.DrawTextEx(
			rl.GetFontDefault(),
			text,
			{f32(x) - text_size.x, f32(y)},
			f32(font_size),
			spacing,
			color,
		)
	}
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

	rl.DrawPixel(0, 0, rl.BLACK)
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
