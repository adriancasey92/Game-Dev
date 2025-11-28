
package main

import "core:c/libc"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:path/filepath"
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
HEIGHT :: 1000
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

MusicFile :: struct {
	filepath:  string,
	musicData: rl.Music,
}

currentMusic: ^MusicFile
currentMusicIndex: i32
music_paused: bool
music_time_played: f32
music_pan: f32
music_volume: f32
MusicLibrary: [dynamic]MusicFile
EffectsLibrary: [dynamic]rl.Sound

music_path :: "assets/sounds/music"
effects_path :: "assets/sounds/effects"

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

// initializes audio variables and starts playing music
init_audio :: proc() {
	currentMusic = &MusicLibrary[0]
	rl.PlayMusicStream(currentMusic.musicData)
	music_time_played = 0
	music_paused = false
	music_pan = 0.0
	music_volume = 0.1
	rl.SetMusicVolume(currentMusic.musicData, music_volume)
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
			   !grid[cell.neighbours[i]].checked &&
			   !grid[cell.neighbours[i]].player_flag {
				grid[cell.neighbours[i]].checked = true
				if grid[cell.neighbours[i]].num_mines_touching == cell_val {
					on_click_search(&grid[cell.neighbours[i]])
				}
			}
		}
	}
}

load_assets :: proc() {
	load_music_library(&MusicLibrary, music_path)
	load_effects_library(&EffectsLibrary, effects_path)
}

load_music_library :: proc(library: ^[dynamic]MusicFile, path: string) {
	//create a handle to the directory
	dir_handle, err := os.open(path)
	defer os.close(dir_handle)
	if err != nil {
		fmt.printf("Error opening music directory: %s\n", err)
		return
	}
	f_info: []os.File_Info


	f_info, err = os.read_dir(dir_handle, -1)
	defer os.file_info_slice_delete(f_info)
	if err != os.ERROR_NONE {
		fmt.printf("Error reading music directory: %s\n", err)
		return
	}
	fmt.printfln("Current working directory %v contains:", dir_handle)

	for f in f_info {
		d, name := filepath.split(f.fullpath)

		fmt.printf("dir: %v\n", d)
		if strings.ends_with(name, ".mp3") ||
		   strings.ends_with(name, ".wav") ||
		   strings.ends_with(name, ".ogg") {
			full_path := filepath.join({path, name})
			music := rl.LoadMusicStream(rl.TextFormat("%v", full_path))
			music_file := MusicFile {
				filepath  = full_path,
				musicData = music,
			}
			fmt.printfln("Loaded music file: %v", full_path)
			append(library, music_file)
		}
	}
}

//loads sound effects into the effects library
load_effects_library :: proc(library: ^[dynamic]rl.Sound, path: string) {
	//create a handle to the directory
	dir_handle, err := os.open(path)
	defer os.close(dir_handle)
	if err != nil {
		fmt.printf("Error opening effects directory: %s\n", err)
		return
	}
	f_info: []os.File_Info

	defer os.file_info_slice_delete(f_info)
	f_info, err = os.read_dir(dir_handle, -1)

	if err != os.ERROR_NONE {
		fmt.printf("Error reading effects directory: %s\n", err)
		return
	}
	fmt.printfln("Current working directory %v contains:", dir_handle)

	for f in f_info {
		_, name := filepath.split(f.fullpath)
		if f.is_dir {
			fmt.printfln("  <DIR> %s\n", name)
			continue
		} else {
			fmt.printfln("%v (%v bytes)", name, f.size)
		}

		if strings.ends_with(name, ".mp3") ||
		   strings.ends_with(name, ".wav") ||
		   strings.ends_with(name, ".ogg") {
			full_path := filepath.join({path, name})
			effect := rl.LoadSound(rl.TextFormat("%v", full_path))
			rl.SetSoundVolume(effect, 0.1)
			fmt.printfln("Loaded music file: %v", full_path)
			append(library, effect)
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
	//Disable exit key, still allows window to be closed with close button
	rl.SetExitKey(.KEY_NULL)
	//Set FPS
	rl.SetTargetFPS(60)

	rl.InitAudioDevice()

	//Load assets
	load_assets()

	//Init audio
	init_audio()
	//init program
	init_program()

	//Program loop
	for GAME_RUNNING {
		rl.UpdateMusicStream(currentMusic.musicData)
		handle_input()
		update()
		draw()
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
	clear(&grid)
	delete(grid)

	unload_music_library(&MusicLibrary)
	delete(MusicLibrary)
	unload_effects_library(&EffectsLibrary)
	delete(EffectsLibrary)
	rl.CloseAudioDevice()
	//to check if we have leaked memory
	reset_tracking_allocator(&tracking_allocator)
}


//Handles gameplay updates
update_gameplay :: proc() {
	time_elapsed += rl.GetFrameTime()
	player_flag_correct_count := 0
	player_flag_incorrect_count := 0
	player_cell_checked_count := 0

	//Check win condition
	for cell in grid {
		if cell.checked {
			//If we have clicked on a mine, end game
			if cell.is_mine {currentState = .ENDING
			} else {
				//count the number of non-mine cells that have been checked
				player_cell_checked_count += 1
			}
		} else {
			//count the number of correctly and incorrectly placed flags
			if cell.player_flag == true && cell.is_mine {
				player_flag_correct_count += 1
			} else if cell.player_flag && !cell.is_mine {
				player_flag_incorrect_count += 1
			}
		}
	}
	//Win condition - all mines have been correctly flagged, and no incorrect flags
	if i32(player_flag_correct_count) == num_mines && player_flag_incorrect_count == 0 {
		playerWins = true
		currentState = .ENDING
	}
	//Another win condition - all non-mine cells have been checked
	if i32(player_cell_checked_count) == ((grid_cols * grid_rows) - num_mines) {
		playerWins = true
		currentState = .ENDING
	}
}

//General update handler
update :: proc() {
	#partial switch (currentState) {
	case .GAMEPLAY:
		update_gameplay()
	}
}

//Handles title input
handle_input_title :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {GAME_RUNNING = false}
	if rl.IsKeyPressed(.ONE) {gameDifficulty = .Beginner}
	if rl.IsKeyPressed(.TWO) {gameDifficulty = .Intermediate}
	if rl.IsKeyPressed(.THREE) {gameDifficulty = .Expert}
	if rl.IsKeyPressed(.ENTER) {currentState = .GAMEPLAY;reset_game()}
}

//Handles gameplay input
handle_input_gameplay :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {currentState = .TITLE}
	if rl.IsKeyPressed(.R) {reset_game()}
	if rl.IsKeyPressed(.ONE) {gameDifficulty = .Beginner;reset_game()}
	if rl.IsKeyPressed(.TWO) {gameDifficulty = .Intermediate;reset_game()}
	if rl.IsKeyPressed(.THREE) {gameDifficulty = .Expert;reset_game()}
	if rl.IsMouseButtonPressed(.LEFT) {
		mpos := rl.GetMousePosition()
		cell_index := index(
			screen_to_pos_coord(mpos.x - f32(grid_xpos_offset)),
			screen_to_pos_coord(mpos.y - f32(grid_ypos_offset)),
		)
		if cell_index != -1 && !grid[cell_index].player_flag && !grid[cell_index].checked {
			if grid[cell_index].is_mine {
				rl.PlaySound(EffectsLibrary[2])
				currentState = .ENDING
				return
			} else {
				if !grid[cell_index].player_flag && !grid[cell_index].checked {
					rl.PlaySound(EffectsLibrary[1])
					grid[cell_index].checked = true
					on_click_search(&grid[cell_index])
				}
			}
		}
	}
	if rl.IsMouseButtonPressed(.RIGHT) {


		mpos := rl.GetMousePosition()
		cell_index := index(
			screen_to_pos_coord(mpos.x - f32(grid_xpos_offset)),
			screen_to_pos_coord(mpos.y - f32(grid_ypos_offset)),
		)
		if cell_index != -1 && !grid[cell_index].checked {
			rl.PlaySound(EffectsLibrary[0])
			grid[cell_index].player_flag = !grid[cell_index].player_flag
		}
	}
}

//Handles ending input
handle_input_ending :: proc() {
	if rl.IsKeyPressed(.R) {reset_game()}
}

//General input handler
handle_input :: proc() {
	if rl.WindowShouldClose() {GAME_RUNNING = false}
	//Next song
	if rl.IsKeyPressed(.N) {
		currentMusicIndex := -1
		for &musicFile, i in MusicLibrary {
			if &musicFile == currentMusic {
				currentMusicIndex = i
				break
			}
		}
		if currentMusicIndex != -1 {
			rl.StopMusicStream(currentMusic.musicData)
			nextIndex := (currentMusicIndex + 1) % len(MusicLibrary)
			currentMusic = &MusicLibrary[nextIndex]
			rl.PlayMusicStream(currentMusic.musicData)
			rl.SetMusicVolume(currentMusic.musicData, music_volume)
		}
	}
	//Volume control
	//Increase/decrease volume
	if rl.IsKeyPressed(.EQUAL) || rl.IsKeyPressed(.KP_ADD) {
		music_volume += 0.1
		if music_volume > 1.0 {music_volume = 1.0}
		rl.SetMusicVolume(currentMusic.musicData, music_volume)
	}
	if rl.IsKeyPressed(.MINUS) || rl.IsKeyPressed(.KP_SUBTRACT) {
		music_volume -= 0.1
		if music_volume < 0.0 {music_volume = 0.0}
		rl.SetMusicVolume(currentMusic.musicData, music_volume)
	}

	if rl.IsKeyPressed(.F2) {
		if !playerWins && currentState == .ENDING {
			enable_hint = !enable_hint}
	}

	//State specific input handling
	#partial switch (currentState) {
	case .TITLE:
		handle_input_title()
	case .GAMEPLAY:
		handle_input_gameplay()
	case .ENDING:
		handle_input_ending()
	}
}

//Draw title screen
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
		"[2]. Intermediate  - 16x16 Grid - 40 mines",
		WIDTH / 2 - (rl.MeasureText("[2]. Intermediate  - 16x16 Grid - 40 mines", 20) / 2),
		320,
		20,
		titleCol,
	)
	rl.DrawText(
		"[3]. Expert 			 	- 16x30 Grid - 99 mines",
		WIDTH / 2 - (rl.MeasureText("[3]. Expert 			 	- 16x30 Grid - 99 mines", 20) / 2),
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
	//draw overlay
	rl.DrawRectangle(0, 0, WIDTH, HEIGHT, rl.Fade(rl.DARKGRAY, 0.6))
	if playerWins {
		//draw win text
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
		//draw lose text
		rl.DrawRectangle(
			WIDTH / 2 - (rl.MeasureText(LOSE_TEXT, 25) / 2) - 20,
			50 - 10,
			rl.MeasureText(LOSE_TEXT, 25) + 40,
			45,
			rl.Fade(rl.RED, 0.6),
		)
		rl.DrawText(LOSE_TEXT, WIDTH / 2 - (rl.MeasureText(LOSE_TEXT, 25) / 2), 50, 25, rl.WHITE)
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
					if !cell.player_flag {
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
				} else if cell.player_flag {
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

	rl.DrawText(
		"'+' | '-'",
		0 + (rl.MeasureText("Music Volume: %i%%", 20) / 2) - rl.MeasureText("'+' | '-'", 20) / 2,
		HEIGHT - 50,
		20,
		rl.WHITE,
	)
	rl.DrawText(
		rl.TextFormat("Music Volume: %.f%%", music_volume * 100),
		15,
		HEIGHT - 30,
		20,
		rl.WHITE,
	)

	rl.DrawText(
		"Press 'N' for next song.",
		WIDTH - (rl.MeasureText("Press 'N' for next song.", 20) + 20),
		HEIGHT - 50,
		20,
		rl.WHITE,
	)

	rl.DrawText(
		rl.TextFormat("%s", filepath.base(currentMusic.filepath)),
		WIDTH -
		(rl.MeasureText(rl.TextFormat("%s", filepath.base(currentMusic.filepath)), 20) + 60),
		HEIGHT - 30,
		20,
		rl.WHITE,
	)

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


unload_music_library :: proc(library: ^[dynamic]MusicFile) {
	for &musicFile in library {
		rl.UnloadMusicStream(musicFile.musicData)
	}
	clear(library)
}


unload_effects_library :: proc(library: ^[dynamic]rl.Sound) {
	for &effect in library {
		rl.UnloadSound(effect)
	}
	clear(library)
}
