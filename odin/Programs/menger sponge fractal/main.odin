#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"
import rl "vendor:raylib"

FLT_MAX :: 340282346638528859811704183484516925440.0

Vec3 :: rl.Vector3
Vec2 :: rl.Vector2
cameraSpeed :: 3
pause: bool
colours: bool
rand_colours: bool
colNum: int
width :: 1600
height :: 900
MAX_SIZE :: 150
center :: Vec2{width / 2, height / 2}
Z_DIST :: 140
camera: rl.Camera3D
cubes: [dynamic]Cube

Cube :: struct {
	pos3d:           Vec3,
	size3d:          Vec3,
	col:             rl.Color,
	visibleByCamera: bool,
}

random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

get_size3d :: proc() -> Vec3 {
	s: f32
	s = random_uniform(1, 5)
	return Vec3{s, s, s}
}

get_random_col :: proc() -> rl.Color {
	col: rl.Color
	num := randrange(23)
	switch (num) 
	{
	case 0:
		col = rl.LIGHTGRAY
	case 1:
		col = rl.GRAY
	case 2:
		col = rl.DARKGRAY
	case 3:
		col = rl.YELLOW
	case 4:
		col = rl.GOLD
	case 5:
		col = rl.ORANGE
	case 6:
		col = rl.PINK
	case 7:
		col = rl.RED
	case 8:
		col = rl.MAROON
	case 9:
		col = rl.GREEN
	case 10:
		col = rl.LIME
	case 11:
		col = rl.DARKGREEN
	case 12:
		col = rl.SKYBLUE
	case 13:
		col = rl.BLUE
	case 14:
		col = rl.DARKBLUE
	case 15:
		col = rl.PURPLE
	case 16:
		col = rl.VIOLET
	case 17:
		col = rl.DARKPURPLE
	case 18:
		col = rl.BEIGE
	case 19:
		col = rl.BROWN
	case 20:
		col = rl.DARKBROWN
	case 21:
		col = rl.WHITE
	case 22:
		col = rl.BLACK
	case 23:
		col = rl.MAGENTA
	case 24:
		col = rl.RAYWHITE
	}
	return col
}

init_cubes :: proc() {
	c := Cube{{0, 0, 0}, {MAX_SIZE, MAX_SIZE, MAX_SIZE}, rl.RED, true}
	append(&cubes, c)
}

init_camera :: proc() {
	camera = {{15, 15, -Z_DIST}, {0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, 60.0, .PERSPECTIVE}
	rl.DisableCursor()
}

menger_sponge :: proc() {
	size := len(cubes)
	cubeLen := cubes[size - 1].size3d.x
	inc := cubeLen / 3
	totalCubes := size * 27
	count := 0
	internalCubeCount := 0
	add: bool
	fmt.printf("Number of cubes: %i\n", size)
	fmt.printf("Current cube length: %f\n", cubeLen)
	fmt.printf("New cube length: %f\n", inc)

	tmp_cubes: []Cube
	tmp_cubes = make([]Cube, totalCubes)

	txpos: f32
	typos: f32
	tzpos: f32
	//for each cube found 
	for i := 0; i < size; i += 1 {
		//tmp_col := get_random_col()
		xpos := cubes[i].pos3d.x
		ypos := cubes[i].pos3d.y
		zpos := cubes[i].pos3d.z

		//iterate over the cubes face, and divide face by 3 (every face is divided by 3)
		for w := -1; w < 2; w += 1 {
			for h := -1; h < 2; h += 1 {
				for d := -1; d < 2; d += 1 {
					sum := math.abs(w) + math.abs(h) + math.abs(d)

					//fmt.printf("Adding Cube %i: x,y,z: %f,%f,%f\n", count, txpos, typos, tzpos)
					if sum > 1 {
						if rand_colours {
							tmp_cubes[count] = Cube {
								{
									xpos + (inc * f32(w)),
									ypos + (inc * f32(h)),
									zpos + (inc * f32(d)),
								},
								{inc, inc, inc},
								rl.ColorFromHSV((f32)(((w + h + d) * 45) % 360), 0.75, 0.9),
								true,
							}
						} else {
							tmp_cubes[count] = Cube {
								{
									xpos + (inc * f32(w)),
									ypos + (inc * f32(h)),
									zpos + (inc * f32(d)),
								},
								{inc, inc, inc},
								rl.BLUE,
								true,
							}
						}

					}
					count += 1
				}
			}
		}
	}
	clear(&cubes)
	for c in tmp_cubes {
		append(&cubes, c)
	}
}

main :: proc() {
	colours = false
	rand_colours = true
	//Set to square

	rl.InitWindow(width, height, "menger sponge fractal")
	if !rl.IsWindowReady() {
		fmt.printf("ERR: Window not ready?\n")
		return
	}
	init_camera()
	rl.SetTargetFPS(144)
	init_cubes()
	//print_arr(stars[:])
	for !rl.WindowShouldClose() {
		update()
		draw()
		free_all(context.temp_allocator)
	}
}

update :: proc() {
	collision: rl.RayCollision = {}
	collision.distance = FLT_MAX
	collision.hit = false


	//ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), camera)
	for &c, idx in cubes {
		//fmt.printf("CHECKING COLLISONS?")
		/*cubeCollision := rl.GetRayCollisionBox(ray, rl.BoundingBox{c.pos3d, c.pos3d + c.size3d})

		if ((cubeCollision.hit) && cubeCollision.distance < collision.distance) {

			c.visibleByCamera = true
		} else {
			c.col = rl.Color(rl.Fade(rl.WHITE, 0.1))
		}*/
		screen_pos := rl.GetWorldToScreen(c.pos3d, camera)
		minC := c.pos3d - Vec3{c.size3d.x / 2, c.size3d.y / 2, c.size3d.z / 2}
		maxC := c.pos3d + Vec3{c.size3d.x / 2, c.size3d.y / 2, c.size3d.z / 2}
		if (minC.x > width ||
			   maxC.x < 0 ||
			   minC.y > height ||
			   maxC.y < 0 ||
			   minC.z > camera.fovy ||
			   maxC.z < camera.fovy) {
			c.visibleByCamera = false // Not visible if offscreen in any dimension
		}
	}
	rl.UpdateCamera(&camera, .FREE)
	if rl.IsKeyDown(.W) {
		rl.CameraMoveForward(&camera, cameraSpeed, false)
	}
	if rl.IsKeyDown(.S) {
		rl.CameraMoveForward(&camera, -cameraSpeed, false)
	}
	if rl.IsKeyDown(.A) {
		rl.CameraMoveRight(&camera, -cameraSpeed, false)
	}
	if rl.IsKeyDown(.D) {
		rl.CameraMoveRight(&camera, cameraSpeed, false)
	}

	if rl.IsKeyDown(.SPACE) {
		rl.CameraMoveUp(&camera, cameraSpeed)
	}
	if rl.IsKeyDown(.LEFT_SHIFT) {
		rl.CameraMoveUp(&camera, -cameraSpeed)
	}

	if rl.IsKeyPressed(.C) {
		colours = !colours
	}

	if rl.IsMouseButtonPressed(.LEFT) {
		menger_sponge()
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		rand_colours = !rand_colours
	}

	if !pause {

	}
}

draw :: proc() {
	rl.BeginDrawing()
	//rl.BeginBlendMode(.ADDITIVE)

	rl.ClearBackground(rl.WHITE)
	rl.BeginMode3D(camera)


	rl.DrawGrid(50, 40)
	for c in cubes {
		if c.visibleByCamera {
			if rand_colours {
				rl.DrawCubeV(
					c.pos3d,
					c.size3d,
					/*rl.ColorFromHSV(
						(f32)(i32((c.pos3d.x + c.pos3d.y + c.pos3d.z) * 45) % 360),
						0.75,
						0.9,
					)*/
					c.col,
				)
			} else {
				rl.DrawCubeV(c.pos3d, c.size3d, rl.BLUE)
			}

			rl.DrawCubeWiresV(c.pos3d, c.size3d, rl.BLACK)
		}

	}

	//rl.BeginMode2D(camera)
	//rl.EndMode2D()
	rl.EndMode3D()
	rl.EndDrawing()
}

is_cube_visible :: proc(cam: rl.Camera3D, c: Cube) -> bool {


	return false
}


draw_cube :: proc(c: Cube) {

	rl.DrawCubeV(c.pos3d, c.size3d, c.col)
}
