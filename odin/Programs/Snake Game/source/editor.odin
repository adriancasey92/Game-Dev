package game

import hm "../handle_map"
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"


save_prompt: bool

update_level_editor :: proc() {

	fmt.printf("update level editor\n")
	if rl.IsKeyPressed(.ESCAPE) {
		fmt.printf("Closing editor\n")

		g.state = .mainMenu
	}

}

draw_level_editor :: proc() {
	fmt.printf("Drawing level editor\n")

	//If user has tried exiting editor
	if save_prompt {

		length := rl.MeasureTextEx(
			rl.GetFontDefault(),
			"Do you wish to save your current level? (Y/N)?\n",
			f32(BASE_FONT_SIZE),
			MENU_SPACING,
		)
		rl.DrawRectangleLinesEx(
			{
				f32(WIDTH / 2) - (length.x / 2) - 10,
				f32(HEIGHT / 2) - (length.y / 2) - 10,
				length.x + 20,
				length.y + 20,
			},
			1,
			rl.RED,
		)
		rl.DrawText(
			"Do you wish to save your current level? (Y/N)?\n",
			WIDTH / 2,
			HEIGHT / 2,
			BASE_FONT_SIZE,
			rl.BLACK,
		)
	}
}
