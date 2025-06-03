package game

//import "core:encoding/json"
import "core:fmt"
//import "core:os"
import rl "vendor:raylib"

Level :: struct {
	level_chunks: []Level_Chunk,
	platforms:    [5]Platform,
	edit_screen:  Edit_Screen,
}

//Chunks are 'stages' for each level. 
//Camera will be centered on the chunk, and the chunk will be drawn
//in the center of the screen.
Level_Chunk :: struct {
	camera_pos: Vec2,
	platforms:  []Platform,
}

init_level :: proc(level_num: int) {
	fmt.printf("Initializing level %i\n", level_num)
	// Load level from file
	p := Platform {
		pos          = centered_pos_from_offset({0, 0}, {96, 16}),
		size_vec2    = {96, 16},
		rotation     = 0,
		texture_rect = atlas_textures[.Platform_Large].rect,
		exists       = true,
	}

	p.pos_rect = pos_to_rect(p.pos, p.size_vec2)
	p.corners = get_rect_corners(p.pos_rect)
	p.faces = get_rect_faces(p.pos_rect)

	level.platforms[0] = p
	//append(&level.platforms, p)

	p = {
		pos          = centered_pos_from_offset({0, 250}, {64, 16}),
		size_vec2    = {64, 16},
		rotation     = 0,
		texture_rect = atlas_textures[.Platform_Medium].rect,
		exists       = true,
	}
	p.pos_rect = pos_to_rect(p.pos, p.size_vec2)
	p.corners = get_rect_corners(p.pos_rect)
	p.faces = get_rect_faces(p.pos_rect)
	level.platforms[1] = p
	//append(&level.platforms, p)

	/*&if level_data, ok := os.read_entire_file("assets/level.json", context.temp_allocator); ok {
		if json.unmarshal(level_data, &level) != nil {
			append(
				&level.platforms,
				Platform {
					pos = {-20, 20},
					size = {96, 16},
					texture_rect = atlas_textures[.Platform_Large].rect,
				},
			)
			append(
				&level.platforms,
				Platform {
					pos = {90, -20},
					size = {64, 16},
					texture_rect = atlas_textures[.Platform_Medium].rect,
				},
			)
		}
	} else {
		fmt.printf("Failed to load level data\n")
		return
	}*/


	//Set up edit screen with -1 as selection index
	/*level.edit_screen = {Menu{}, -1}
	append(
		&level.edit_screen.menu.nodes,
		Edit_Platforms {
			rect = atlas_textures[.Platform_Small].rect,
			size = {16, 32},
			pos = {0, 0},
			mouseOver = false,
		},
	)
	append(
		&level.edit_screen.menu.nodes,
		Edit_Platforms {
			rect = atlas_textures[.Platform_Medium].rect,
			size = {16, 32},
			pos = {0, 0},
			mouseOver = false,
		},
	)
	append(
		&level.edit_screen.menu.nodes,
		Edit_Platforms {
			rect = atlas_textures[.Platform_Large].rect,
			size = {16, 32},
			pos = {0, 0},
			mouseOver = false,
		},
	)*/
}

//Fade draws the level with a fade
draw_level :: proc(fade: f32) {
	// Draw platforms
	for p, idx in level.platforms {
		if p.exists {
			rl.DrawTextureRec(g.atlas, p.texture_rect, p.pos, rl.Fade(rl.WHITE, fade))
			if DEBUG_DRAW {
				rl.DrawRectangleLinesEx(p.pos_rect, 1, rl.Fade(rl.RED, fade))
				//text position
				text := rl.TextFormat("%.2f, %.2f", p.pos.x, p.pos.y)
				//text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, 5, 2)

				draw_text_centered(
					text,
					i32(p.pos.x + p.pos_rect.width / 2),
					i32(p.pos.y + p.pos_rect.height / 2),
					5,
					rl.Fade(rl.RED, fade),
				)
				/*rl.DrawTextEx(
				rl.GetFontDefault(),
				text,
				{
					p.pos.x + (p.size_vec2.x / 2) - (text_size.x / 2),
					p.pos.y + (p.size_vec2.y / 2) - (text_size.y / 2),
				},
				5,
				2,
				rl.Fade(rl.RED, fade),
			)*/
			}
			if DEBUG_DRAW_COLLIDERS {
				for c, c_idx in p.corners {
					rl.DrawRectangleLinesEx(c, 1, rl.YELLOW)
					draw_text_centered(
						rl.TextFormat("%i,%i", idx, c_idx),
						i32(c.x),
						i32(c.y),
						4,
						rl.BLACK,
					)
				}
				for f in p.faces {
					rl.DrawRectangleLinesEx(f, 1, rl.PURPLE)
				}
			}
		}
	}
}
