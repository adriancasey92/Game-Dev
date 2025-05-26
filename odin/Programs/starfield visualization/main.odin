#+feature dynamic-literals
package main
import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"
import rl "vendor:raylib"

Vec3 :: rl.Vector3
Vec2 :: rl.Vector2
velocity: f32
pause: bool
colours: bool
width :: 1600
height :: 900
center :: Vec2{width / 2, height / 2}
Z_DIST :: 140
stars: [5000]Star
currentShape: i32
alpha :: 120

// 0 = square
// 1 = circle
// 2 = triangle
CurrentShape :: enum {
	square,
	circle,
	triangle,
}

Star :: struct {
	pos3d: Vec3,
	pos2d: Vec2,
	size:  f32,
	vel:   f32,
	col:   rl.Color,
}

sort_arr :: proc(arr: []Star) {
	n := len(arr)
	swapped := true
	loops := 0
	for (swapped) {
		loops += 1
		fmt.printf("Loops: %i\n", loops)
		swapped = false
		for i := 1; i <= n - 1; i += 1 {
			if arr[i - 1].pos3d.z > arr[i].pos3d.z {
				tmp := arr[i]
				arr[i] = arr[i - 1]
				arr[i - 1] = tmp
				swapped = true
			}
		}
	}
}

print_arr :: proc(arr: []Star) {
	for n, idx in arr {
		fmt.printf("Star# %i, Z: %f\n", idx, n.pos3d.z)
	}
}

create_stars :: proc() {
	for i := 0; i < len(stars); i += 1 {
		stars[i] = Star{get_pos3d(), {0, 0}, 8, random_uniform(velocity, velocity + .2), rl.WHITE}
		//fmt.printf("Creating star x,y : %i, %i\n", stars[i].x, stars[i].y)
	}
}

random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

get_pos3d :: proc() -> Vec3 {
	scalePos := 35
	v := Vec3{0, 0, 0}
	angle := random_uniform(0, 2 * math.PI)
	radius := randrange(height) * i32(scalePos)
	x := f32(radius) * math.sin(angle)
	y := f32(radius) * math.cos(angle)
	return Vec3{x, y, f32(randrange(Z_DIST))}
}

main :: proc() {
	colours = true
	velocity = 0.05
	//Set to square
	currentShape = 0
	rl.InitWindow(width, height, "Starfield Visualizer")
	if !rl.IsWindowReady() {
		fmt.printf("ERR: Window not ready?\n")
		return
	}
	rl.SetTargetFPS(144)
	create_stars()
	//print_arr(stars[:])
	for !rl.WindowShouldClose() {
		update()
		draw()
		free_all(context.temp_allocator)
	}
}

update :: proc() {

	if rl.IsKeyPressed(.P) {
		pause = !pause
	}

	if rl.IsKeyPressed(.C) {
		colours = !colours
	}
	// Cycle shape
	if rl.IsKeyPressed(.SPACE) {
		currentShape += 1
		if currentShape > 2 {
			currentShape = 0
		}
	}

	if rl.IsKeyPressed(.DOWN) {
		velocity -= 0.05
		if velocity < -2 {
			velocity = -2
		}
	}
	if rl.IsKeyPressed(.UP) {
		velocity += 0.05
		if velocity > 2 {
			velocity = 2
		}
	}

	//if NOT paused
	if !pause {

		//for evey s in stars (every Star in stars[])
		for &s, idx in stars {
			//increment the z axis, (bringing it closer or further depending on velocity)
			s.pos3d.z -= s.vel

			//if the zpoz < 0.5 (too big) reset
			if s.pos3d.z < 0.5 {
				s.pos3d = get_pos3d()
			} else {
				s.pos3d = s.pos3d
			}

			//2d space
			s.pos2d = Vec2{s.pos3d.x, s.pos3d.y} / s.pos3d.z + center

			//size - scaled by zdistance (closeness to screen)
			s.size = (Z_DIST - s.pos3d.z) / (0.5 * s.pos3d.z)

			//if colours,set colours
			if colours {
				if (s.size > 0 && s.size <= 1) {
					s.col = rl.PURPLE
				} else if s.size > 1 && s.size <= 2 {
					s.col = rl.VIOLET
				} else if s.size > 2 && s.size <= 3 {
					s.col = rl.DARKBLUE
				} else if s.size > 3 && s.size <= 4 {
					s.col = rl.BLUE
				} else if s.size > 4 && s.size <= 5 {
					s.col = rl.SKYBLUE
				} else if s.size > 5 && s.size <= 6 {
					s.col = rl.DARKGREEN
				} else if s.size > 6 && s.size <= 7 {
					s.col = rl.GREEN
				} else if s.size > 7 && s.size <= 8 {
					s.col = rl.LIME
				} else if s.size > 8 && s.size <= 9 {
					s.col = rl.YELLOW
				} else {
					s.col = rl.WHITE
				}
			} else {
				s.col = rl.WHITE
			}
			s.vel = random_uniform(velocity, velocity + .2)
		}

		//Sorts array by zdist
		sort_arr(stars[:])
	}


}

draw :: proc() {
	rl.BeginDrawing()
	rl.BeginBlendMode(.ADDITIVE)
	rl.ClearBackground(rl.BLACK)

	/*(camera := rl.Camera2D {
		target = {width / 2, height / 2},
	}*/

	//rl.BeginMode2D(camera)

	switch (currentShape) 
	{
	case 0:
		for i := 0; i < len(stars); i += 1 {
			rl.DrawRectangle(
				i32(stars[i].pos2d.x),
				i32(stars[i].pos2d.y),
				i32(stars[i].size),
				i32(stars[i].size),
				stars[i].col,
			)
		}
	case 1:
		for i := 0; i < len(stars); i += 1 {
			rl.DrawCircle(
				i32(stars[i].pos2d.x),
				i32(stars[i].pos2d.y),
				f32(stars[i].size) / 2,
				stars[i].col,
			)
		}
	case 2:
		for i := 0; i < len(stars); i += 1 {
			rl.DrawRectangle(
				i32(stars[i].pos2d.x),
				i32(stars[i].pos2d.y),
				i32(stars[i].size),
				i32(stars[i].size),
				stars[i].col,
			)
		}
	}

	//rl.EndMode2D()
	rl.EndDrawing()
}
