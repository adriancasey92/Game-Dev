package main

import "core:c"
import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

game_state :: enum {
	mainMenu,
	play,
	pause,
}

player_state :: enum {
	running,
	idle,
	jumping,
	swinging,
	climbing,
}

ground_type :: enum {
	air,
	dirt,
	grass,
	stone,
	obsidian,
	void,
}

block_hardness :: enum {
	void,
	air,
	dirt,
	grass,
	stone,
	obsidian,
}

Game :: struct {
	state: game_state,
}

Tile :: struct {
	pos:      rl.Vector2,
	type:     ground_type,
	hardness: block_hardness,
	colour:   rl.Color,
	size:     Vec2i,
}

Player :: struct {
	state:   player_state,
	pos:     rl.Vector2,
	stamina: i32,
}


TILE_SIZE :: 32 //pixels
WORLD_PATH := "resources/world/world.txt"
WINDOW_SIZE_WIDTH :: 1280
WINDOW_SIZE_HEIGHT :: 960
WORLD_SIZE_WIDTH :: 16
WORLD_SIZE_HEIGHT :: 16
CANVAS_SIZE :: WORLD_SIZE_HEIGHT * TILE_SIZE
Vec2i :: [2]int
mPos :: rl.Vector2
debug: bool
cam_debug: bool

//world size [x][y] = tile type
world_map: [WORLD_SIZE_WIDTH][WORLD_SIZE_HEIGHT]Tile
c :: rl.Color
player: Player


//Draw things
render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.WHITE)

	if cam_debug {
		camera := rl.Camera2D {
			offset = {0, -320},
			zoom   = f32(WINDOW_SIZE_WIDTH) / CANVAS_SIZE,
		}
		rl.BeginMode2D(camera)
	}

	//Draws map
	drawGrid()

	//Draw Player
	rl.DrawRectangle(i32(player.pos.x), i32(player.pos.y), TILE_SIZE, TILE_SIZE, rl.PURPLE)
	if debug == true {
		drawOutlines()
	}


	// Draw the texture at the center of the screen

	rl.EndMode2D()
	rl.EndDrawing()
}

handleInput :: proc() {

	if rl.IsMouseButtonPressed(.LEFT) {

		fmt.println(rl.GetMousePosition())

	} else if rl.IsMouseButtonPressed(.RIGHT) {
		//init()
	}

}

update :: proc() {

}

//Create the things
init :: proc() {


	//loadWorld()
	for x := WORLD_SIZE_WIDTH - 1; x >= 0; x = x - 1 {

		for y := WORLD_SIZE_HEIGHT - 1; y >= 0; y = y - 1 {
			if y <= WORLD_SIZE_HEIGHT - 1 && y > WORLD_SIZE_HEIGHT - 2 {
				world_map[x][y] = Tile {
					{f32(x), f32(y)},
					ground_type.stone,
					block_hardness.stone,
					rl.GRAY,
					TILE_SIZE,
				}
			} else if y == WORLD_SIZE_HEIGHT - 2 {
				world_map[x][y] = Tile {
					{f32(x), f32(y)},
					ground_type.grass,
					block_hardness.grass,
					rl.GREEN,
					TILE_SIZE,
				}
			}
			/*fmt.println("Adding tile")
			world_map[x][y] = Tile {
				{x, y},
				ground_type.dirt,
				block_hardness.dirt,
				rl.BROWN,
				TILE_SIZE,
			}*/
		}
	}

}

loadWorld :: proc() {
	numLines := 0
	xPos := 0
	yPos := WORLD_SIZE_HEIGHT - 1
	fmt.printf("Loading world: %s", WORLD_PATH)
	data, ok := os.read_entire_file(WORLD_PATH, context.allocator)
	if !ok {
		// could not read file
		return
	}
	defer delete(data, context.allocator)

	it := string(data)

	for line in strings.split_lines_iterator(&it) {
		// process line
		fmt.printf("Found line %i\n", numLines)
		for l in line {
			//fmt.printf("L: %c\n", l)
			//Check each char and add it to map depending on what the integer is
			num := (int(l) - '0')
			if (ground_type(num) == ground_type.air) {
				fmt.printf("GROUND TYPE AIR FOUND\nADDING AT %i,%i\n", xPos, yPos)
				xPos += 1
			}
			if (xPos == WORLD_SIZE_WIDTH - 1) {
				yPos += 1
				xPos = 0
			}
		}
		numLines += 1
	}

}

randomize_map :: proc() {
	for x := 0; x < WORLD_SIZE_WIDTH; x = x + 1 {
		for y := 0; y < WORLD_SIZE_HEIGHT; y = y + 1 {
			s := rand.choice_enum(ground_type)
			switch (s) 
			{
			case ground_type.air:
				world_map[x][y] = Tile {
					{f32(x), f32(y)},
					s,
					block_hardness.air,
					rl.WHITE,
					TILE_SIZE,
				}
			case ground_type.dirt:
				world_map[x][y] = Tile {
					{f32(x), f32(y)},
					s,
					block_hardness.dirt,
					rl.BROWN,
					TILE_SIZE,
				}
			case ground_type.grass:
				world_map[x][y] = Tile {
					{f32(x), f32(y)},
					s,
					block_hardness.grass,
					rl.GREEN,
					TILE_SIZE,
				}
			case ground_type.stone:
				world_map[x][y] = Tile {
					{f32(x), f32(y)},
					s,
					block_hardness.stone,
					rl.GRAY,
					TILE_SIZE,
				}
			case ground_type.void:
				world_map[x][y] = Tile {
					{f32(x), f32(y)},
					s,
					block_hardness.void,
					rl.VIOLET,
					TILE_SIZE,
				}
			case ground_type.obsidian:
				world_map[x][y] = Tile {
					{f32(x), f32(y)},
					s,
					block_hardness.obsidian,
					rl.PURPLE,
					TILE_SIZE,
				}
			}
		}
	}
}

main :: proc() {
	player.state = player_state.idle
	player.pos.x = 0
	player.pos.y = ((WORLD_SIZE_HEIGHT - 3) * TILE_SIZE)
	player.stamina = 10
	debug = true
	cam_debug = true
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE_WIDTH, WINDOW_SIZE_HEIGHT, "GridGame")
	defer rl.CloseWindow()

	init()

	for rl.WindowShouldClose() == false {
		handleInput()
		update()
		render()
	}
}

drawGrid :: proc() {
	for x := 0; x < WORLD_SIZE_WIDTH; x = x + 1 {
		for y := 0; y < WORLD_SIZE_HEIGHT; y = y + 1 {
			drawTile(&world_map[x][y])
		}
	}
}

drawOutlines :: proc() {
	fmt.println("Drawing outlines")
	rl.DrawLineEx({0, 0}, {WORLD_SIZE_WIDTH * TILE_SIZE, 0}, 3, rl.RED)
	rl.DrawLineEx({0, 0}, {0, WORLD_SIZE_HEIGHT * TILE_SIZE}, 3, rl.RED)
	rl.DrawLineEx(
		{WORLD_SIZE_WIDTH * TILE_SIZE, 0},
		{WORLD_SIZE_WIDTH * TILE_SIZE, WORLD_SIZE_HEIGHT * TILE_SIZE},
		3,
		rl.RED,
	)
	rl.DrawLineEx(
		{0, WORLD_SIZE_HEIGHT * TILE_SIZE},
		{WORLD_SIZE_WIDTH * TILE_SIZE, WORLD_SIZE_HEIGHT * TILE_SIZE},
		3,
		rl.RED,
	)

	//Ycounter means I can calculate every xth block from the bottom of the map and draw bounds. useful for level sizes?

	ycounter := 0
	for y := WORLD_SIZE_HEIGHT - 1; y > 0; y = y - 1 {
		ycounter += 1
		for x := 0; x < WORLD_SIZE_WIDTH; x = x + 1 {
			//EVERY 10th TILE?
			if int(ycounter) % 12 == 0 {
				rl.DrawLineEx(
					{0, f32(y) * TILE_SIZE},
					{WORLD_SIZE_WIDTH * TILE_SIZE, f32(y) * TILE_SIZE},
					2,
					rl.RED,
				)
			}
		}
	}
}

destroyTile :: proc(pos: rl.Vector2) {
	world_map[int(pos.x) / TILE_SIZE][int(pos.y) / TILE_SIZE] = Tile {
		{f32(pos.x), f32(pos.y)},
		ground_type.air,
		block_hardness.air,
		rl.WHITE,
		TILE_SIZE,
	}
}

drawTile :: proc(t: ^Tile) {
	rl.DrawRectangle(
		i32(t.pos.x) * i32(t.size.x),
		i32(t.pos.y) * i32(t.size.x),
		i32(t.size.x),
		i32(t.size.y),
		t.colour,
	)

	if (t.type != ground_type.air) {
		rl.DrawRectangleLines(
			i32(t.pos.x) * i32(t.size.x),
			i32(t.pos.y) * i32(t.size.x),
			i32(t.size.x),
			i32(t.size.y),
			rl.WHITE,
		)
	}
}
