
package main

import "core:c/libc"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

//TODO
// - Add sounds 
// 		* background music? 
//		* guess sound - could be based on how close they were to a mine?
// 	    * flag noise
//      * explosion for mine 
// 	    * game over + win music


//Declare types
Vec2 :: rl.Vector2

//Constants
WIDTH :: 1600
HEIGHT :: 900
WINDOW_NAME :: "Mine Sweeper"
WIN_TEXT :: "You Win! Press 'r' to reset!"
LOSE_TEXT :: "Game Over! Press 'r' to reset!"
GAME_RUNNING: bool
BACKGROUND_COL: rl.Color

//Cell struct that makes up our grid
Cell :: struct {
	pos:                Vec2,
	cell_index:         i32,
	checked:            bool,
	player_flag:        bool,
	is_mine:            bool,
	num_mines_touching: i32,
	neighbours:         [8]i32,
}

// difficulty enum
GameDifficulty :: enum {
	Beginner,
	Intermediate,
	Expert,
}

//state switching
GameState :: enum {
	TITLE,
	GAMEPLAY,
	ENDING,
}
currentState: GameState
gameDifficulty: GameDifficulty

//Grid
grid_width :: 450
grid_height :: 450
grid_xpos_offset: i32
grid_ypos_offset: i32
grid_cols: i32
grid_rows: i32
cell_size :: 50
grid: [dynamic]Cell
num_mines: i32
enable_hint: bool
playerWins: bool
time_elapsed: f32

//Random function
random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

//Random range function between 0 and max
randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

// returns the index of our grid[dynamic] array 
// by adding the x and y and multiplying by columns
index :: proc(x, y: i32) -> i32 {
	if x < 0 || y < 0 || x > grid_cols - 1 || y > grid_rows - 1 {
		return -1
	}
	return x + y * grid_cols
}

// gives the screen coordinates of a position based on the cell size
pos_to_screen_coord :: proc(pos: f32) -> i32 {
	return i32(pos * cell_size)
}

// gives the position of a mouse click relative to the offset for our grid 
// when drawn centered. 
screen_to_pos_coord :: proc(pos: f32) -> i32 {
	return i32(pos / cell_size)
}

// initializes all necessary variables and the cell grid, mines etc
init_program :: proc() {
	GAME_RUNNING = true
	fmt.printf("Init program:\n")
	BACKGROUND_COL = rl.BLACK
	currentState = .TITLE
	playerWins = false
	time_elapsed = 0

	//easy updating of grid size and num_mines using gameDifficulty enum
	switch (gameDifficulty) 
	{
	case .Beginner:
		grid_cols = 9
		grid_rows = 9
	case .Intermediate:
		grid_cols = 16
		grid_rows = 16
	case .Expert:
		grid_cols = 30
		grid_rows = 16
	}

	//grid position and dimensions
	grid_width := grid_cols * cell_size
	grid_height := grid_rows * cell_size
	grid_xpos_offset = (WIDTH - grid_width) / 2
	grid_ypos_offset = (HEIGHT - grid_height) / 2
	offset := (WIDTH - grid_width) / 2

	//minesweeper grid setup
	for y := 0; y < int(grid_rows); y += 1 {
		for x := 0; x < int(grid_cols); x += 1 {
			c := Cell {
				pos                = Vec2{f32(x), f32(y)},
				checked            = false,
				player_flag        = false,
				is_mine            = false,
				cell_index         = index(i32(x), i32(y)),
				num_mines_touching = 0,
			}
			append(&grid, c)
		}
	}
	total_cells := grid_cols * grid_rows
	if total_cells <= 9 * 9 {
		num_mines = 10
	} else if total_cells > 9 * 9 && total_cells <= 16 * 16 {
		num_mines = 40
	} else if total_cells > 16 * 16 {
		num_mines = 99
	}

	//adds neighbours for every cell
	for &c in grid {
		add_neighbours(&c)
	}

	//add random bombs to grid
	run := true
	count := 0
	for run {
		index := randrange(i32(len(grid) - 1))
		if !grid[index].is_mine {
			grid[index].is_mine = true
			update_mine_neighbours(&grid[index])
			count += 1
		}

		// makes sure that we generate unique mine positons,
		// exacly num_mines times
		if i32(count) == num_mines {run = false}
	}
}

reset_game :: proc() {
	clear(&grid)
	init_program()
	currentState = .GAMEPLAY
}

// adds all cell neighbours to the cell.neighbours array
add_neighbours :: proc(cell: ^Cell) {
	cell.neighbours[0] = index(i32(cell.pos.x), i32(cell.pos.y - 1))
	cell.neighbours[1] = index(i32(cell.pos.x + 1), i32(cell.pos.y - 1))
	cell.neighbours[2] = index(i32(cell.pos.x + 1), i32(cell.pos.y))
	cell.neighbours[3] = index(i32(cell.pos.x + 1), i32(cell.pos.y + 1))
	cell.neighbours[4] = index(i32(cell.pos.x), i32(cell.pos.y + 1))
	cell.neighbours[5] = index(i32(cell.pos.x - 1), i32(cell.pos.y + 1))
	cell.neighbours[6] = index(i32(cell.pos.x - 1), i32(cell.pos.y))
	cell.neighbours[7] = index(i32(cell.pos.x - 1), i32(cell.pos.y - 1))
}


// adds the num_mines value based on how many mines are touching the cell
// assumes that cell is a mine (this should be the only case that this 
// function is called)
update_mine_neighbours :: proc(cell: ^Cell) {
	for i := 0; i < len(cell.neighbours); i += 1 {
		if cell.neighbours[i] != -1 && !grid[cell.neighbours[i]].is_mine {
			grid[cell.neighbours[i]].num_mines_touching += 1
		}
	}
}

// Searches neighbouring cells and reveals them if they are equal to or above 0
// recursively calls on_click_search on any cell that is equal to zero 
// this allows the search to grow to a perimeter of cells that are above zero
on_click_search :: proc(cell: ^Cell) {
	cell_val := cell.num_mines_touching
	if cell_val != 0 {
		return
	}

	for i := 0; i < len(cell.neighbours); i += 1 {
		if cell.neighbours[i] != -1 {
			//if the neighbouring cells are equal to zero
			if grid[cell.neighbours[i]].num_mines_touching >= cell_val &&
			   !grid[cell.neighbours[i]].is_mine &&
			   !grid[cell.neighbours[i]].checked {
				grid[cell.neighbours[i]].checked = true
				if grid[cell.neighbours[i]].num_mines_touching == cell_val {
					on_click_search(&grid[cell.neighbours[i]])
				}
			}
		}
	}
}

main :: proc() {

	//Memory leak allocator
	default_allocator := context.allocator
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
		err := false

		for _, value in a.allocation_map {
			fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
			err = true
		}

		mem.tracking_allocator_clear(a)
		return err
	}

	gameDifficulty = .Beginner

	//Set to square
	rl.InitWindow(WIDTH, HEIGHT, WINDOW_NAME)
	if !rl.IsWindowReady() {
		fmt.printf("ERR: Window not ready?\n")
		return
	}
	//Set FPS
	rl.SetTargetFPS(60)

	//init program
	init_program()

	//Program loop
	for GAME_RUNNING {
		handle_input()
		update()
		draw()
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
	clear(&grid)
	delete(grid)

	//to check if we have leaked memory
	reset_tracking_allocator(&tracking_allocator)
}

update_gameplay :: proc() {
	time_elapsed += rl.GetFrameTime()
	player_flag_correct_count := 0
	player_flag_incorrect_count := 0

	player_cell_checked_count := 0
	for cell in grid {
		//check game over
		if cell.checked {
			if cell.is_mine {
				fmt.printf("Game over!\n")
				currentState = .ENDING
			} else {
				player_cell_checked_count += 1
			}
		} else {
			if cell.player_flag == true && cell.is_mine {
				player_flag_correct_count += 1
			} else if cell.player_flag && !cell.is_mine {
				player_flag_incorrect_count += 1
			}
		}
	}
	if i32(player_flag_correct_count) == num_mines && player_flag_incorrect_count == 0 {
		playerWins = true
		currentState = .ENDING
	}

	if i32(player_cell_checked_count) == ((grid_cols * grid_rows) - num_mines) {
		playerWins = true
		currentState = .ENDING
	}
}


update :: proc() {

	#partial switch (currentState) {
	case .GAMEPLAY:
		update_gameplay()
	case .ENDING:
	}
	//Make sure we can pause/unpause
}

handle_input_title :: proc() {
	if rl.IsKeyPressed(.ONE) {
		gameDifficulty = .Beginner
	}
	if rl.IsKeyPressed(.TWO) {
		gameDifficulty = .Intermediate
	}
	if rl.IsKeyPressed(.THREE) {
		gameDifficulty = .Expert
	}
	if rl.IsKeyPressed(.ENTER) {
		currentState = .GAMEPLAY
		reset_game()
	}
}

handle_input_gameplay :: proc() {
	if rl.IsKeyPressed(.R) {reset_game()}
	if rl.IsKeyPressed(.ONE) {
		gameDifficulty = .Beginner
		reset_game()
	}

	if rl.IsKeyPressed(.TWO) {
		gameDifficulty = .Intermediate
		reset_game()
	}

	if rl.IsKeyPressed(.THREE) {
		gameDifficulty = .Expert
		reset_game()
	}


	if rl.IsKeyPressed(.F2) {
		enable_hint = !enable_hint
	}

	if rl.IsMouseButtonPressed(.LEFT) {
		mpos := rl.GetMousePosition()
		cell_index := index(
			screen_to_pos_coord(mpos.x - f32(grid_xpos_offset)),
			screen_to_pos_coord(mpos.y - f32(grid_ypos_offset)),
		)
		if cell_index != -1 {
			grid[cell_index].checked = true
			on_click_search(&grid[cell_index])
		}

	}

	if rl.IsMouseButtonPressed(.RIGHT) {
		mpos := rl.GetMousePosition()
		cell_index := index(
			screen_to_pos_coord(mpos.x - f32(grid_xpos_offset)),
			screen_to_pos_coord(mpos.y - f32(grid_ypos_offset)),
		)
		if cell_index != -1 {
			grid[cell_index].player_flag = !grid[cell_index].player_flag
		}
	}
}

handle_input_ending :: proc() {
	if rl.IsKeyPressed(.R) {
		reset_game()
	}
	if rl.IsKeyPressed(.F2) {
		enable_hint = !enable_hint
	}
}

handle_input :: proc() {

	if rl.WindowShouldClose() {
		GAME_RUNNING = false
	}

	#partial switch (currentState) {
	case .TITLE:
		handle_input_title()
	case .GAMEPLAY:
		handle_input_gameplay()
	case .ENDING:
		handle_input_ending()
	}
}

draw_title :: proc() {
	titleCol := rl.WHITE
	rl.DrawText(WINDOW_NAME, WIDTH / 2 - (rl.MeasureText(WINDOW_NAME, 60) / 2), 100, 60, titleCol)
	rl.DrawText(
		rl.TextFormat("Game Difficulty: %s", gameDifficulty),
		WIDTH / 2 - (rl.MeasureText(rl.TextFormat("Game Difficulty: %s", gameDifficulty), 20) / 2),
		220,
		20,
		titleCol,
	)
	rl.DrawText(
		"[1]. Beginner 			  -  9x9  Grid - 10 mines",
		WIDTH / 2 - (rl.MeasureText("[1]. Beginner 			 -  9x9  Grid - 10 mines", 20) / 2),
		280,
		20,
		titleCol,
	)
	rl.DrawText(
		"[2]. Intermediate- 16x16 Grid - 40 mines",
		WIDTH / 2 - (rl.MeasureText("[1]. Beginner 			 -  9x9  Grid - 10 mines", 20) / 2),
		320,
		20,
		titleCol,
	)
	rl.DrawText(
		"[3]. Expert 			 	- 16x30 Grid - 99 mines",
		WIDTH / 2 - (rl.MeasureText("[1]. Beginner 			 -  9x9  Grid - 10 mines", 20) / 2),
		360,
		20,
		titleCol,
	)
	rl.DrawText(
		"Press [Enter] to start!",
		WIDTH / 2 - (rl.MeasureText("Press [Enter] to start!", 40) / 2),
		450,
		40,
		titleCol,
	)
}

draw_ending :: proc() {
	if playerWins {
		rl.DrawRectangle(
			WIDTH / 2 - (rl.MeasureText(WIN_TEXT, 25) / 2) - 20,
			HEIGHT / 2 - 10,
			rl.MeasureText(WIN_TEXT, 25) + 40,
			50,
			rl.Fade(rl.LIME, 0.6),
		)
		rl.DrawText(
			WIN_TEXT,
			WIDTH / 2 - (rl.MeasureText(WIN_TEXT, 25) / 2),
			HEIGHT / 2,
			25,
			rl.WHITE,
		)
	} else {
		rl.DrawRectangle(
			WIDTH / 2 - (rl.MeasureText(LOSE_TEXT, 25) / 2) - 20,
			HEIGHT / 2 - 10,
			rl.MeasureText(LOSE_TEXT, 25) + 40,
			45,
			rl.Fade(rl.RED, 0.6),
		)
		rl.DrawText(
			LOSE_TEXT,
			WIDTH / 2 - (rl.MeasureText(LOSE_TEXT, 25) / 2),
			HEIGHT / 2,
			25,
			rl.WHITE,
		)
	}
}

draw_game :: proc() {
	rl.DrawText(rl.TextFormat("Time Elapsed: %.2f", time_elapsed), 10, 10, 20, rl.WHITE)
	rl.DrawText(
		rl.TextFormat("Game Difficulty: %s - %i mines.", gameDifficulty, num_mines),
		WIDTH / 2 -
		(rl.MeasureText(
					rl.TextFormat("Game Difficulty: %s - %i mines.", gameDifficulty, num_mines),
					20,
				) /
				2),
		10,
		20,
		rl.WHITE,
	)
	rl.DrawText(rl.TextFormat("Press 'r' to reset game!"), WIDTH - 260, 10, 20, rl.WHITE)
	//draw grid
	for cell in grid {
		//draw the grid outlines
		rl.DrawRectangleLines(
			i32(f32(pos_to_screen_coord(cell.pos.x)) + f32(grid_xpos_offset)),
			i32(f32(pos_to_screen_coord(cell.pos.y)) + f32(grid_ypos_offset)),
			cell_size,
			cell_size,
			rl.GREEN,
		)

		//if we press f2 - show mines and the num_mines_touching values
		if enable_hint {
			//if the cell is a mine, draw the mine
			if cell.is_mine {
				//draw mine only if player_flag is false
				if !cell.player_flag {
					rl.DrawText(
						"{M}",
						i32(
							f32(pos_to_screen_coord(cell.pos.x)) +
							f32(grid_xpos_offset) +
							cell_size / 5,
						),
						i32(
							f32(pos_to_screen_coord(cell.pos.y)) +
							f32(grid_ypos_offset) +
							cell_size / 3,
						),
						20,
						rl.BLUE,
					)
				} else {
					rl.DrawText(
						"{F}",
						i32(
							f32(pos_to_screen_coord(cell.pos.x)) +
							f32(grid_xpos_offset) +
							cell_size / 5,
						),
						i32(
							f32(pos_to_screen_coord(cell.pos.y)) +
							f32(grid_ypos_offset) +
							cell_size / 3,
						),
						20,
						rl.YELLOW,
					)
				}
			} else {
				rl.DrawText(
					rl.TextFormat("%i", cell.num_mines_touching),
					i32(
						f32(pos_to_screen_coord(cell.pos.x)) +
						f32(grid_xpos_offset) +
						cell_size / 2.5,
					),
					i32(
						f32(pos_to_screen_coord(cell.pos.y)) +
						f32(grid_ypos_offset) +
						cell_size / 3,
					),
					20,
					rl.RED,
				)
			}
		} else {
			//if a cell has been left clicked, it has been checked
			if cell.checked {
				//if a cell isn't a mine, draw the number of mines touching the cell. 
				if !cell.is_mine {
					rl.DrawText(
						rl.TextFormat("%i", cell.num_mines_touching),
						i32(
							f32(pos_to_screen_coord(cell.pos.x)) +
							f32(grid_xpos_offset) +
							cell_size / 2.5,
						),
						i32(
							f32(pos_to_screen_coord(cell.pos.y)) +
							f32(grid_ypos_offset) +
							cell_size / 3,
						),
						20,
						rl.RED,
					)
				} else {
					rl.DrawText(
						"{M}",
						i32(
							f32(pos_to_screen_coord(cell.pos.x)) +
							f32(grid_xpos_offset) +
							cell_size / 5,
						),
						i32(
							f32(pos_to_screen_coord(cell.pos.y)) +
							f32(grid_ypos_offset) +
							cell_size / 3,
						),
						20,
						rl.BLUE,
					)
				}
			} else {
				if currentState == .GAMEPLAY {
					if cell.player_flag {
						rl.DrawText(
							"{F}",
							i32(
								f32(pos_to_screen_coord(cell.pos.x)) +
								f32(grid_xpos_offset) +
								cell_size / 5,
							),
							i32(
								f32(pos_to_screen_coord(cell.pos.y)) +
								f32(grid_ypos_offset) +
								cell_size / 3,
							),
							20,
							rl.YELLOW,
						)
						/*rl.DrawRectangle(
							i32(f32(pos_to_screen_coord(cell.pos.x)) + f32(grid_xpos_offset) + cell_size / 4),
							i32(f32(pos_to_screen_coord(cell.pos.y)) + f32(grid_ypos_offset)) + cell_size / 4,
							cell_size / 2,
							cell_size / 2,
							rl.YELLOW,
						)*/
					}
				}
			}
			if currentState == .ENDING {
				if cell.is_mine {
					rl.DrawText(
						"{M}",
						i32(
							f32(pos_to_screen_coord(cell.pos.x)) +
							f32(grid_xpos_offset) +
							cell_size / 5,
						),
						i32(
							f32(pos_to_screen_coord(cell.pos.y)) +
							f32(grid_ypos_offset) +
							cell_size / 3,
						),
						20,
						rl.BLUE,
					)
				} else {
					rl.DrawText(
						rl.TextFormat("%i", cell.num_mines_touching),
						i32(
							f32(pos_to_screen_coord(cell.pos.x)) +
							f32(grid_xpos_offset) +
							cell_size / 2.5,
						),
						i32(
							f32(pos_to_screen_coord(cell.pos.y)) +
							f32(grid_ypos_offset) +
							cell_size / 3,
						),
						20,
						rl.RED,
					)
				}
			}
		}
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	switch (currentState) {
	case .TITLE:
		draw_title()
	case .GAMEPLAY:
		draw_game()
	case .ENDING:
		draw_game()
		draw_ending()
	}
	//rl.EndMode2D()
	rl.EndDrawing()
}
