#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:sort"
import "core:strings"
import rl "vendor:raylib"

//Declare types
Vec3 :: rl.Vector3
Vec2 :: rl.Vector2

//Constants
WIDTH :: 1600
HEIGHT :: 900
WINDOW_NAME :: "Screen states"
CENTER :: Vec2{WIDTH / 2, HEIGHT / 2}

MAX_BUILDINGS :: 100

BACKGROUND_COL: rl.Color
PAUSE: bool
//Cameras
camera2D: rl.Camera2D
camera3D: rl.Camera3D

GameState :: enum {
	LOGO,
	TITLE,
	GAMEPLAY,
	ENDING,
}

framesCounter: i32

//Dummy struct
Player :: struct {
	rect: rl.Rectangle,
}

player: Player
buildings: [MAX_BUILDINGS]rl.Rectangle
buildingcolours: [MAX_BUILDINGS]rl.Color
spacing: i32
currentState: GameState

//Random function
random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

//Random range function
randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

//Init camera functions
init_camera2D :: proc() {
	camera2D = {}
	camera2D.target = Vec2{player.rect.x + 20, player.rect.y + 20}
	camera2D.offset = Vec2{WIDTH / 2, HEIGHT / 2}
	camera2D.rotation = 0
	camera2D.zoom = 1
	//rl.DisableCursor()
}
init_camera3D :: proc(cam: rl.Camera) {
	//camera3D = {{15, 15, -Z_DIST}, {0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, 60.0, .PERSPECTIVE}
	//rl.DisableCursor()
}

init_program :: proc() {
	fmt.printf("Init program:\n")
	BACKGROUND_COL = rl.BLACK
	currentState = .LOGO
	framesCounter = 0
	spacing = 0
	player.rect = {400, 280, 40, 40}

	for i := 0; i < MAX_BUILDINGS; i += 1 {
		buildings[i].width = f32(rl.GetRandomValue(50, 200))
		buildings[i].height = f32(rl.GetRandomValue(100, 800))
		buildings[i].y = HEIGHT - 130 - buildings[i].height
		buildings[i].x = f32(-WIDTH * 7 + spacing)

		spacing += i32(buildings[i].width)
		buildingcolours[i] = rl.Color {
			u8(rl.GetRandomValue(200, 240)),
			u8(rl.GetRandomValue(200, 240)),
			u8(rl.GetRandomValue(200, 250)),
			255,
		}
	}
	init_camera2D()
}

main :: proc() {


	//MEMORY ALLOCATOR 
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


	//Set to square
	rl.InitWindow(WIDTH, HEIGHT, WINDOW_NAME)
	if !rl.IsWindowReady() {
		fmt.printf("ERR: Window not ready?\n")
		return
	}
	//Set FPS
	rl.SetTargetFPS(60)
	//Init camera 2D/3D
	init_camera2D()
	//init_camera3D()

	//init program
	init_program()

	//Program loop
	for !rl.WindowShouldClose() {
		fmt.printf("Current state: %s\n", currentState)
		handle_input()
		update()
		draw()
		free_all(context.temp_allocator)
	}
	rl.CloseWindow()

	//to check for leaks and bad frees
	reset_tracking_allocator(&tracking_allocator)
}
update_gameplay :: proc() {
	camera2D.target = Vec2{player.rect.x + 20, player.rect.y + 20}

	if camera2D.rotation > 40 {
		camera2D.rotation = 40
	} else if camera2D.rotation < -40 {
		camera2D.rotation = -40
	}

	camera2D.zoom += f32(rl.GetMouseWheelMove() * 0.05)
	if camera2D.zoom > 3 {
		camera2D.zoom = 3
	} else if camera2D.zoom < .1 {
		camera2D.zoom = .1
	}

}

update :: proc() {
	switch (currentState) {
	case .LOGO:
		framesCounter += 1
		if (framesCounter > 120) {
			currentState = .TITLE
		}
	case .TITLE:
	case .GAMEPLAY:
		update_gameplay()
	case .ENDING:
	}
	//Make sure we can pause/unpause
}

handle_input_gameplay :: proc() {
	if rl.IsKeyPressed(.W) {}
	if rl.IsKeyPressed(.S) {}
	if rl.IsKeyDown(.A) {player.rect.x -= 2}
	if rl.IsKeyDown(.D) {player.rect.x += 2}
	if rl.IsKeyPressed(.R) {camera2D.zoom = 1;camera2D.rotation = 0}
	// Camera rotation
	if rl.IsKeyDown(.Q) {camera2D.rotation -= 1}
	if rl.IsKeyDown(.E) {camera2D.rotation += 1}
	if rl.IsKeyPressed(.ENTER) {currentState = .ENDING}
}

handle_input :: proc() {
	switch (currentState) {
	case .LOGO:
		if rl.IsKeyDown(.KEY_NULL) {
			fmt.printf(".LOGO - KEY_NULL\n")
		}
	case .TITLE:
		if rl.IsKeyPressed(.ENTER) {
			currentState = .GAMEPLAY
		}
	case .GAMEPLAY:
		handle_input_gameplay()
	case .ENDING:
		if rl.IsKeyPressed(.ENTER) {
			currentState = .GAMEPLAY
		}
	}
}

draw_intro :: proc() {
	rl.DrawText("Logo screen", 20, 20, 40, rl.LIGHTGRAY)
	rl.DrawText("Wait for 2 seconds...", 290, 220, 20, rl.GRAY)
}

draw_main_menu :: proc() {
	rl.DrawRectangle(0, 0, WIDTH, HEIGHT, rl.GREEN)
	rl.DrawText("TITLE SCREEN", 20, 20, 40, rl.DARKGREEN)
	rl.DrawText("PRESS ENTER or TAP to JUMP to GAMEPLAY SCREEN", 120, 220, 20, rl.DARKGREEN)
}
draw_game :: proc() {
	rl.BeginMode2D(camera2D)
	{
		rl.DrawRectangle(-6000, 320, 13000, 8000, rl.DARKGRAY)
		for i := 0; i < MAX_BUILDINGS; i += 1 {
			rl.DrawRectangleRec(buildings[i], buildingcolours[i])
		}

		//player 
		rl.DrawRectangleRec(player.rect, rl.RED)

		//
		rl.DrawLine(
			i32(camera2D.target.x),
			-HEIGHT * 10,
			i32(camera2D.target.x),
			HEIGHT * 10,
			rl.GREEN,
		)
		rl.DrawLine(
			-WIDTH * 10,
			i32(camera2D.target.y),
			WIDTH * 10,
			i32(camera2D.target.y),
			rl.GREEN,
		)
	}
	rl.EndMode2D()

	rl.DrawText("SCREEN AREA", 640, 10, 20, rl.RED)

	rl.DrawRectangle(0, 0, WIDTH, 5, rl.RED)
	rl.DrawRectangle(0, 5, 5, HEIGHT - 10, rl.RED)
	rl.DrawRectangle(WIDTH - 5, 5, 5, HEIGHT - 10, rl.RED)
	rl.DrawRectangle(0, HEIGHT - 5, WIDTH, 5, rl.RED)

	rl.DrawRectangle(10, 10, 250, 113, rl.Fade(rl.SKYBLUE, 0.5))
	rl.DrawRectangleLines(10, 10, 250, 113, rl.BLUE)

	rl.DrawText("Free 2d camera controls:", 20, 20, 10, rl.BLACK)
	rl.DrawText("- A / D to move Offset", 40, 40, 10, rl.DARKGRAY)
	rl.DrawText("- Mouse Wheel to Zoom in-out", 40, 60, 10, rl.DARKGRAY)
	rl.DrawText("- Q / E to Rotate", 40, 80, 10, rl.DARKGRAY)
	rl.DrawText("- R to reset Zoom and Rotation", 40, 100, 10, rl.DARKGRAY)
}

draw_credits :: proc() {
	rl.DrawRectangle(0, 0, WIDTH, HEIGHT, rl.BLUE)
	rl.DrawText("ENDING SCREEN", 20, 20, 40, rl.DARKBLUE)
	rl.DrawText("PRESS ENTER or TAP to RETURN to TITLE SCREEN", 120, 220, 20, rl.DARKBLUE)
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	switch (currentState) {
	case .LOGO:
		draw_intro()
	case .TITLE:
		draw_main_menu()
	case .GAMEPLAY:
		draw_game()
	case .ENDING:
		draw_credits()
	}

	//rl.EndMode2D()
	rl.EndDrawing()
}
