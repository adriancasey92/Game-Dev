package game
import "core:fmt"
import rl "vendor:raylib"

TITLE_FONT_SIZE: i32 = 50
MENU_FONT_SIZE: i32 = 25

Menu :: struct {
	title:             cstring,
	options:           [5]cstring,
	selected, hovered: i32,
	num_options:       i32,
}

init_menu :: proc() {
	g.main_menu = Menu {
		title       = "Main Menu",
		options     = {"Start Game", "Options", "Exit", "", ""},
		selected    = 0,
		hovered     = -1,
		num_options = 3,
	}

	g.options_menu = Menu {
		title       = "Options",
		options     = {"Audio", "Graphics", "Controls", "Back", ""},
		selected    = 0,
		hovered     = -1,
		num_options = 4,
	}

	g.pause_menu = Menu {
		title       = "Pause Menu",
		options     = {"Resume", "Options", "Exit", "", ""},
		selected    = 0,
		hovered     = -1,
		num_options = 3,
	}
}

draw_menu :: proc(menu: Menu, x, y: i32) {
	//Draw menu heading
	draw_text_centered(menu.title, x, y, TITLE_FONT_SIZE, rl.RAYWHITE)
	ypos := y + 20
	colour := rl.RAYWHITE
	//rl.DrawText(menu.title, x, y, 20, rl.RAYWHITE)
	for option, idx in menu.options {
		if option != "" {
			if idx == int(menu.selected) {
				colour = rl.YELLOW
			} else if idx == int(menu.hovered) {
				colour = rl.LIGHTGRAY
			} else {
				colour = rl.RAYWHITE
			}
			draw_text_centered(
				menu.options[idx],
				x,
				ypos + 25 + i32(idx) * 25,
				MENU_FONT_SIZE,
				colour,
			)
		}
	}
}

// Handle menu input and update the menu state  
update_menu :: proc(menu: ^Menu) {
	fmt.printf("update menu\n")
	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		menu.selected -= 1
		if menu.selected < 0 {
			menu.selected = menu.num_options - 1
		}
	} else if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.TAB) || rl.IsKeyPressed(.S) {
		menu.selected += 1
		if menu.selected >= menu.num_options {
			menu.selected = 0
		}
	}

	if rl.IsKeyPressed(.ENTER) {
		if menu.selected == 0 {
			// Start Game
			g.state = .play
			//init_level(g.level)
			//init_quadtree(&quadtree, 25, 15)
			fmt.printf("Starting game...\n")
		} else if menu.selected == 1 {
			// Options                
			g.state = .options
			fmt.printf("Opening options...\n")
		} else if menu.selected == 2 {
			// Exit 
			fmt.printf("Shutting down...\n")
			g.run = false
		}
	}
}

draw_main_menu :: proc() {
	fade := f32(0.5)
	rl.BeginDrawing()
	rl.ClearBackground(rl.SKYBLUE)
	rl.BeginMode2D(game_camera())
	{
		draw_level(fade)
		draw_player(fade)
		//draw_menu

	}
	rl.EndMode2D()

	//UI DRAW
	rl.BeginMode2D(ui_camera())
	{


	}
	rl.EndMode2D()

	//Menu text
	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.Fade(rl.BLACK, fade))
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()
	draw_menu(g.main_menu, w / 2, h / 3)

	if DEBUG_DRAW {
		// Draw debug info
		draw_text_centered(rl.TextFormat("FPS: %i", rl.GetFPS()), w / 2, h - 50, 20, rl.RAYWHITE)
		draw_text_centered(
			rl.TextFormat("Entities: %i", len(g.entities.items)),
			w / 2,
			h - 75,
			20,
			rl.RAYWHITE,
		)
		draw_text_centered(
			rl.TextFormat("Quadtree Nodes: %i", quadtree.node_count),
			w / 2,
			h - 100,
			20,
			rl.RAYWHITE,
		)

		/*font_size := f32(7)
		text_pos := rl.GetScreenToWorld2D({0, 0}, game_camera())
		col_2 :=
			rl.MeasureText(rl.TextFormat("Player Grounded?: %v", p.is_on_ground), i32(font_size)) +
			10
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Grounded: %v", p.is_on_ground),
			{text_pos.x + 2, text_pos.y + 2},
			font_size,
			.5,
			rl.RED,
		)
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Pos: %.2f,%.2f", p.pos.x, p.pos.y),
			{text_pos.x + 2 + f32(col_2), text_pos.y + 2},
			font_size,
			.5,
			rl.RED,
		)
		pad := 1
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Movement: %s", p.movement),
			{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
			font_size,
			.5,
			rl.RED,
		)
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Input: %v", p.input),
			{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
			font_size,
			.5,
			rl.RED,
		)
		pad += 6
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Direction: %s", p.dir),
			{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
			font_size,
			.5,
			rl.RED,
		)
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Flip_x: %v", p.flip_x),
			{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
			font_size,
			.5,
			rl.RED,
		)
		pad += 6
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Orientation: %s", p.orientation),
			{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
			font_size,
			.5,
			rl.RED,
		)
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Climbing: %v", p.wall_climbing),
			{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
			font_size,
			.5,
			rl.RED,
		)
		pad += 6
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Animation: %v", p.anim.atlas_anim),
			{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
			font_size,
			.5,
			rl.RED,
		)
		pad += 6
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Player Animation Frame?: %v", p.anim.current_frame),
			{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
			font_size,
			.5,
			rl.RED,
		)
		pad += 6
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("Side Jump: %v", p.side_jump),
			{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
			font_size,
			.5,
			rl.RED,
		)*/
	}
	rl.EndDrawing()
}
