package game
import "core:fmt"
import rl "vendor:raylib"

MENU_TITLE_FONT_SIZE: i32 = 50
MENU_FONT_SIZE: i32 = 25

Menu :: struct {
	title:             cstring,
	options:           [5]cstring,
	options_pos:       [5]Vec2,
	values_pos:        [5]Vec2,
	rect:              Rect,
	selected, hovered: i32,
	num_options:       i32,
	type:              Menu_Type,
}

Menu_Type :: enum {
	none,
	settings,
}

init_menu :: proc() {
	g.main_menu = Menu {
		title       = "Main Menu",
		options     = {"Start Game", "Options", "Exit", "", ""},
		selected    = 0,
		hovered     = -1,
		num_options = 3,
		type        = .none,
	}


	g.options_menu = Menu {
		title       = "Options",
		options     = {"Audio", "Graphics", "Controls", "Back", ""},
		selected    = 0,
		hovered     = -1,
		num_options = 4,
		type        = .none,
	}

	g.pause_menu = Menu {
		title       = "Paused",
		options     = {"Resume", "Options", "Exit to Menu", "", ""},
		selected    = 0,
		hovered     = -1,
		num_options = 3,
		type        = .none,
	}

	g.audio_menu = Menu {
		title       = "Audio Settings",
		options     = {"SFX", "Music", "Channels", "Type", ""},
		selected    = 0,
		hovered     = -1,
		num_options = 4,
		type        = .settings,
	}

	g.graphics_menu = Menu {
		title       = "Graphics Settings",
		options     = {"Fullscreen", "Resolution", "Zoom", "Back", ""},
		selected    = 0,
		hovered     = -1,
		num_options = 4,
		type        = .settings,
	}
	g.control_menu = Menu {
		title       = "Control Settings",
		options     = {"Left", "Right", "Jump", "", ""},
		selected    = 0,
		hovered     = -1,
		num_options = 4,
		type        = .settings,
	}

	calc_menu_positions(&g.main_menu)
	calc_menu_positions(&g.pause_menu)
	calc_menu_positions(&g.options_menu)
	calc_menu_positions(&g.audio_menu)
	calc_menu_positions(&g.graphics_menu)
	calc_menu_positions(&g.control_menu)
}

calc_menu_positions :: proc(menu: ^Menu) {
	menu_x := rl.GetScreenWidth() / 2
	menu_y := rl.GetScreenHeight() / 3

	ypos := menu_y + 20
	pad := f32(50)
	text_size_vec := rl.MeasureTextEx(
		rl.GetFontDefault(),
		menu.title,
		f32(MENU_TITLE_FONT_SIZE),
		MENU_SPACING,
	)
	menu.rect.x = f32(menu_x) - text_size_vec.x / 2 - (pad / 2)
	menu.rect.y = f32(menu_y) - text_size_vec.y / 3 - (f32(pad) / 2)
	menu.rect.width = get_width_of_longest_string_in_menu(menu, MENU_SPACING) + pad
	menu.rect.height = f32(ypos) + (pad / 2) + (f32(menu.num_options)) * (pad / 2) + pad / 2
	menu.rect.height = menu.rect.height - menu.rect.y

	//calculate the settings positions too
	settings: [5]cstring
	if menu.type == .settings {
		settings = get_settings(menu)
	}
	for option, idx in menu.options {
		//left side settings text
		if menu.type == .settings {
			menu.options_pos[idx] = {
				f32(menu.rect.x + pad / 2),
				f32(ypos) + (pad / 2) + f32(idx) * (pad / 2),
			}
		} else {
			menu.options_pos[idx] = {f32(menu_x), f32(ypos) + (pad / 2) + f32(idx) * (pad / 2)}
		}

		text_size_vec = rl.MeasureTextEx(
			rl.GetFontDefault(),
			settings[idx],
			f32(MENU_FONT_SIZE),
			MENU_SPACING,
		)
		if menu.type == .settings {
			menu.values_pos[idx] = {
				f32(((menu.rect.x + menu.rect.width) - (pad / 2))),
				f32(ypos + 25 + i32(idx) * 25),
			}
		}
	}
}

//draw a menu using RayGui elements	instead of custom drawing
// x and y are the position of our Title centered. 
// knowing this we need to build our GUI with offsets in mind. 
draw_menu_RayGui :: proc(menu: ^Menu, x, y: i32, spacing: f32) {
	//the padding around our widest text-width object, and our top and bottom
	//objects in the menu
	pad := f32(20)
	//our Menu rect
	rect: Rect
	//first we find the title size. 
	title_size := rl.MeasureTextEx(
		rl.GetFontDefault(),
		menu.title,
		f32(MENU_TITLE_FONT_SIZE),
		spacing,
	)

	//the width of our longest string
	longest_string := get_width_of_longest_string_in_menu(menu, spacing)
	height_of_options :=
		rl.MeasureTextEx(rl.GetFontDefault(), menu.options[0], f32(MENU_FONT_SIZE), spacing).y

	button_height := height_of_options + (pad / 2)

	//adjust our rect offsets accordingly
	rect.y = f32(y) - ((title_size.y / 2) + pad)
	rect.x = f32(x) - ((longest_string / 2) + pad)
	rect.width = longest_string + (pad * 2)
	rect.height = (pad * 2 + title_size.y) + (button_height * f32(menu.num_options)) + (pad)

	rl.DrawRectangleRec(rect, rl.Fade(rl.GRAY, 0.6))
	rl.DrawRectangleLinesEx(rect, 2, rl.BLACK)
	draw_text_centered_spacing(menu.title, x, y, MENU_TITLE_FONT_SIZE, rl.RAYWHITE, spacing)
	//next we figure out our first button y value, and draw it centered on x
	button_y := f32(y) + title_size.y / 2 + (pad / 2)

	for i := 0; i < int(menu.num_options); i += 1 {
		button_width :=
			rl.MeasureTextEx(rl.GetFontDefault(), menu.options[i], f32(MENU_FONT_SIZE), spacing).x

		button_x := f32(x) - (button_width / 2)

		if (rl.GuiButton({button_x, button_y, button_width, button_height}, menu.options[i])) {

		}
		button_y += pad * 2
	}
}

draw_menu :: proc(menu: ^Menu, x, y: i32, spacing: f32) {
	calc_menu_positions(menu)
	colour := rl.RAYWHITE
	rl.DrawRectangleRec(menu.rect, rl.Fade(rl.GRAY, 0.6))
	rl.DrawRectangleLinesEx(menu.rect, 2, rl.BLACK)
	draw_text_centered_spacing(menu.title, x, y, MENU_TITLE_FONT_SIZE, colour, spacing)

	for i := 0; i < int(menu.num_options); i += 1 {
		draw_text_centered_spacing(
			menu.options[i],
			i32(menu.options_pos[i].x),
			i32(menu.options_pos[i].y),
			MENU_FONT_SIZE,
			colour,
			spacing,
		)
	}
}

draw_menu_settings :: proc(menu: ^Menu, x, y: i32, spacing: f32) {
	calc_menu_positions(menu)
	colour := rl.RAYWHITE
	rl.DrawRectangleRec(menu.rect, rl.Fade(rl.GRAY, 0.6))
	rl.DrawRectangleLinesEx(menu.rect, 2, rl.BLACK)
	draw_text_centered_spacing(menu.title, x, y, MENU_TITLE_FONT_SIZE, colour, spacing)
	settings := get_settings(menu)
	for i := 0; i < int(menu.num_options); i += 1 {
		draw_text_left_aligned_spacing(
			menu.options[i],
			i32(menu.options_pos[i].x),
			i32(menu.options_pos[i].y),
			MENU_FONT_SIZE,
			colour,
			spacing,
		)

		draw_text_right_aligned_spacing(
			settings[i],
			i32(menu.values_pos[i].x),
			i32(menu.values_pos[i].y),
			MENU_FONT_SIZE,
			colour,
			spacing,
		)
	}
}

//generic menu update function
update_menu_generic :: proc(menu: ^Menu) {


	mp := rl.GetMousePosition()
	//rl.DrawCircleV(mp, 2, rl.RED)
	if menu.type == .none {
		update_mouse_hover_menu(menu, mp)
	} else {
		update_mouse_hover_settings(menu, mp)
	}


	//check if mouse is hovering over menu options
	//handle input first
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

	if rl.IsKeyPressed(.C) {
		DEBUG_DRAW_COLLIDERS = !DEBUG_DRAW_COLLIDERS
	}

	settings := 0
	//store left and right for toggling/changing settings
	if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
		settings = -1
	}
	if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
		settings = 1
	}

	switch (menu.title) 
	{
	case "Main Menu":
		if rl.IsKeyPressed(.ENTER) && !MODIFIER_KEY_DOWN ||
		   (rl.IsMouseButtonPressed(.LEFT) && menu.hovered == menu.selected) {
			if menu.selected == 0 {
				// Start Game
				g.state = .play
				fmt.printf("Starting game...\n")
			} else if menu.selected == 1 {
				// Options        
				g.prev_state = .mainMenu
				g.state = .options
				fmt.printf("Opening options...\n")
			} else if menu.selected == 2 {
				// Exit 
				fmt.printf("Shutting down...\n")
				g.run = !g.run
			}
		}
		//close game
		if rl.IsKeyPressed(.ESCAPE) {
			g.run = false
		}
	case "Options":
		if rl.IsKeyPressed(.ENTER) && !MODIFIER_KEY_DOWN ||
		   (rl.IsMouseButtonPressed(.LEFT) && menu.hovered == menu.selected) {
			if menu.selected == 0 {
				g.state = .audio_options
				fmt.printf("Opening audio settings...\n")
			} else if menu.selected == 1 {
				// Options                
				g.state = .graphics_options
				fmt.printf("Opening graphics settings...\n")
			} else if menu.selected == 2 {
				g.state = .control_options
				fmt.printf("Opening Control settings...\n")
			} else if menu.selected == 3 {
				g.state = g.prev_state
				g.prev_state = .options
				fmt.printf("Exiting options!\n")
			}
		}
		//revert to prior state
		if rl.IsKeyPressed(.ESCAPE) {
			g.state = g.prev_state
		}
	case "Paused":
		if rl.IsKeyPressed(.ENTER) && !MODIFIER_KEY_DOWN ||
		   (rl.IsMouseButtonPressed(.LEFT) && menu.hovered == menu.selected) {
			if menu.selected == 0 {
				fmt.printf("Resuming game...\n")
				g.state = .play
			} else if menu.selected == 1 {
				fmt.printf("Opening Options...\n")
				g.state = .options
				g.prev_state = .pause
			} else if menu.selected == 2 {
				fmt.printf("Returning to main menu...\n")
				g.state = .mainMenu
			}
		}
		if rl.IsKeyPressed(.ESCAPE) {
			g.state = .play
		}
	case "Audio Settings":
		switch (menu.options) 
		{
		case "SFX":
		case "Music":
		case "Channels":
		case "Type":
		}


		if rl.IsKeyPressed(.ESCAPE) {
			g.state = .options
		}
	case "Graphics Settings":
		if rl.IsKeyPressed(.ESCAPE) {
			g.state = .options
		}

		if rl.IsKeyPressed(.ENTER) && !MODIFIER_KEY_DOWN ||
		   (rl.IsMouseButtonPressed(.LEFT) && menu.hovered == menu.selected) {
			if menu.selected == 0 {
				rl.ToggleBorderlessWindowed()
				g.graphics_settings.windowed = !g.graphics_settings.windowed
				g.graphics_settings.borderless = !g.graphics_settings.borderless
				g.graphics_settings.fullscreen = !g.graphics_settings.fullscreen
			} else if menu.selected == 1 {

			} else if menu.selected == 2 {
				//change zoom
				CAMERA_ZOOM_MULT += f32(.05)
			}
		}


	case "Control Settings":
		if rl.IsKeyPressed(.ESCAPE) {
			g.state = .options
		}
	}


}

//generic draw menu
draw_menu_generic :: proc(menu: ^Menu, fade: f32) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.SKYBLUE)
	rl.BeginMode2D(game_camera())
	{
		draw_level(0.5)
		draw_player(0.5)
		//draw_menu
	}
	rl.EndMode2D()

	//Menu text
	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.Fade(rl.BLACK, .3))
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()


	if menu.type == .settings {
		draw_menu_settings(menu, w / 2, h / 3, MENU_SPACING)
	} else {
		draw_menu(menu, w / 2, h / 3, MENU_SPACING)
		//draw_menu_RayGui(menu, w / 2, h / 3, MENU_SPACING)
	}

	rl.EndDrawing()
}


//returns an array of menu settings as a string 
get_settings :: proc(menu: ^Menu) -> [5]cstring {
	return_arr: [5]cstring

	switch (menu.title) 
	{
	case "Audio Settings":

	case "Graphics Settings":
		if g.graphics_settings.fullscreen {
			return_arr[0] = rl.TextFormat("True")
		} else {
			return_arr[0] = rl.TextFormat("False")
		}
		return_arr[1] = rl.TextFormat("%ix%i", rl.GetScreenWidth(), rl.GetScreenHeight())
		return_arr[2] = rl.TextFormat("%i", int(CAMERA_ZOOM * CAMERA_ZOOM_MULT))
	//return_arr[1] =
	case "Control Settings":

	}

	return return_arr
}


update_mouse_hover_menu :: proc(menu: ^Menu, mouse_pos: rl.Vector2) {
	for i := 0; i < int(menu.num_options); i += 1 {
		text_size_vec := rl.MeasureTextEx(
			rl.GetFontDefault(),
			menu.options[i],
			f32(MENU_FONT_SIZE),
			MENU_SPACING,
		)
		x := f32(rl.GetScreenWidth() / 2) - text_size_vec.x / 2
		y := (rl.GetScreenHeight() / 3) + 25 + i32(i) * 25

		if mouse_pos.x >= x &&
		   mouse_pos.x <= x + text_size_vec.x &&
		   mouse_pos.y >= f32(y) &&
		   mouse_pos.y <= f32(y) + text_size_vec.y {
			menu.hovered = i32(i)
			menu.selected = i32(i)
			return
		} else {
			menu.hovered = -1
		}
	}
}

update_mouse_hover_settings :: proc(menu: ^Menu, mouse_pos: rl.Vector2) {
	for i := 0; i < int(menu.num_options); i += 1 {
		text_size_vec := rl.MeasureTextEx(
			rl.GetFontDefault(),
			menu.options[i],
			f32(MENU_FONT_SIZE),
			MENU_SPACING,
		)
		x := f32(rl.GetScreenWidth() / 2) - text_size_vec.x / 2
		y := (rl.GetScreenHeight() / 3) + 25 + i32(i) * 25

		if mouse_pos.x >= x &&
		   mouse_pos.x <= x + text_size_vec.x &&
		   mouse_pos.y >= f32(y) &&
		   mouse_pos.y <= f32(y) + text_size_vec.y {
			menu.hovered = i32(i)
			menu.selected = i32(i)
			return
		} else {
			menu.hovered = -1
		}
	}
}
