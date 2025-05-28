package game

import "core:fmt"
import rl "vendor:raylib"

Level :: struct {
	platforms:   [dynamic]Platform,
	edit_screen: Edit_Screen,
}

init_level :: proc(level_num: int) {
	fmt.printf("Initializing level\n")
	// Load level from file
	p := Platform {
		pos          = centered_pos_from_offset({0, 0}, {96, 16}),
		size_vec2    = {96, 16},
		rotation     = 0,
		texture_rect = atlas_textures[.Platform_Large].rect,
	}
	p.pos_rect = pos_to_rect(p.pos, p.size_vec2)
	p.corners = get_rect_corners(p.pos_rect)

	append(&level.platforms, p)

	p = {
		pos          = centered_pos_from_offset({0, 250}, {64, 16}),
		size_vec2    = {64, 16},
		rotation     = 0,
		texture_rect = atlas_textures[.Platform_Medium].rect,
	}
	p.pos_rect = pos_to_rect(p.pos, p.size_vec2)
	p.corners = get_rect_corners(p.pos_rect)
	append(&level.platforms, p)

	/*if level, ok := load_level_data(level); ok {
		fmt.printf("Loaded level: %i\n", level)
	} else {

	
	}*/
	/*if level_data, ok := os.read_entire_file("assets/level.json", context.temp_allocator); ok {
		if json.unmarshal(level_data, &level) != nil {
			append(
				&level.platforms,
				Platform {
					pos = {-20, 20},
					size = {96, 16},
					rect = atlas_textures[.Platform_Large].rect,
				},
			)
			append(
				&level.platforms,
				Platform {
					pos = {90, -20},
					size = {64, 16},
					rect = atlas_textures[.Platform_Medium].rect,
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
	for p in level.platforms {
		rl.DrawTextureRec(g.atlas, p.texture_rect, p.pos, rl.Fade(rl.WHITE, fade))
		if DEBUG_DRAW {
			rl.DrawRectangleLinesEx(p.pos_rect, 1, rl.Fade(rl.RED, fade))
			//text position
			text := rl.TextFormat("%.2f, %.2f", p.pos.x, p.pos.y)
			text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, 5, 2)
			rl.DrawTextEx(
				rl.GetFontDefault(),
				text,
				{
					p.pos.x + (p.size_vec2.x / 2) - (text_size.x / 2),
					p.pos.y + (p.size_vec2.y / 2) - (text_size.y / 2),
				},
				5,
				2,
				rl.Fade(rl.RED, fade),
			)
		}
		if DEBUG_DRAW_COLLIDERS {
			for c in p.corners {
				rl.DrawRectangleLinesEx(c, 1, rl.YELLOW)
			}
		}
	}
}
