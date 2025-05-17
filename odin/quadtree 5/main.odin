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
Vec2 :: rl.Vector2

//Constants
WIDTH :: 1280
HEIGHT :: 960
MAX_OBJECTS :: 4
MAX_CHILDREN :: 4
NUM_POINTS :: 1000
WINDOW_NAME :: "Perlin Noise"
CENTER :: Vec2{WIDTH / 2, HEIGHT / 2}
BACKGROUND_COL: rl.Color
PAUSE: bool
//Cameras
camera2D: rl.Camera2D
camera3D: rl.Camera3D

//Dummy struct
Point :: struct {
	pos: Vec2,
}

QuadTree :: struct {
	bound:        Rect,
	capacity:     i32,
	objects:      [MAX_OBJECTS]Point,
	obj_index:    i32,
	child_nodes:  [MAX_CHILDREN]^QuadTree,
	has_children: bool,
}

Rect :: struct {
	pos_centered: Vec2,
	half_size:    Vec2,
	pos_true:     Vec2,
}

quadtreePtr: ^QuadTree

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
	camera2D = {{0, 0}, {0.0, 0.0}, 0, 0}
	//rl.DisableCursor()
}
init_camera3D :: proc(cam: rl.Camera) {
	//camera3D = {{15, 15, -Z_DIST}, {0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, 60.0, .PERSPECTIVE}
	//rl.DisableCursor()
}

init_program :: proc() {
	fmt.printf("Init program:\n")
	//Default backgroundcolor
	BACKGROUND_COL = rl.BLACK

	//generate points
	for i := 0; i < 4; i += 1 {
		p := Point {
			pos = Vec2{f32(randrange(WIDTH)), f32(randrange(HEIGHT))},
		}
		insert(quadtreePtr, p)
	}
}

create_quadtree :: proc(rect: Rect) -> ^QuadTree {
	n := new(QuadTree)
	n.bound = rect
	n.capacity = MAX_OBJECTS
	n.child_nodes = nil
	n.obj_index = 0
	n.objects = {}
	n.has_children = false
	return n
}

contains_point :: proc(bound: Rect, pos: Vec2) -> bool {
	b_topleft_x := bound.pos_centered.x - bound.half_size.x
	b_topleft_y := bound.pos_centered.y - bound.half_size.y

	b_botright_x := bound.pos_centered.x + bound.half_size.x
	b_botright_y := bound.pos_centered.y + bound.half_size.y

	//outside our x vals
	if pos.x < b_topleft_x || pos.x > b_botright_x {
		//fmt.printf("p.x: p.%f Not inside xmin,xmax: %f,%f\n", p.pos.x, b_topleft_x, b_botright_x)
		return false
	}
	if pos.y < b_topleft_y || pos.y > b_botright_y {
		//fmt.printf("p.y: p.%f Not inside ymin,ymax: %f,%f\n", p.pos.y, b_topleft_y, b_botright_y)
		return false
	}

	return true
}

//inserts into the quadtree
insert :: proc(quadtree: ^QuadTree, p: Point) -> bool {

	if !contains_point(quadtree.bound, p.pos) {
		return false
	}

	if quadtree.obj_index < MAX_OBJECTS && quadtree.child_nodes[0] == nil {
		quadtree.objects[quadtree.obj_index] = p
		quadtree.obj_index += 1
		return true
	}

	//subdivide if we have filled our points
	if !quadtree.has_children {
		subdivide(quadtree)
		quadtree.has_children = true
	}

	//try to reassign points
	for i := 0; i < MAX_CHILDREN; i += 1 {
		if insert(quadtree.child_nodes[i], p) {return true}
	}

	return false
}

subdivide :: proc(quadtree: ^QuadTree) {
	//NW
	quadtree.child_nodes[0] = create_quadtree(
		Rect {
			pos_centered = {
				quadtree.bound.pos_centered.x - quadtree.bound.half_size.x / 2,
				quadtree.bound.pos_centered.y - quadtree.bound.half_size.y / 2,
			},
			half_size = {quadtree.bound.half_size.x / 2, quadtree.bound.half_size.y / 2},
			pos_true = {
				quadtree.bound.pos_centered.x - quadtree.bound.half_size.x,
				quadtree.bound.pos_centered.y - quadtree.bound.half_size.y,
			},
		},
	)
	//NE
	quadtree.child_nodes[1] = create_quadtree(
		Rect {
			pos_centered = {
				quadtree.bound.pos_centered.x + quadtree.bound.half_size.x / 2,
				quadtree.bound.pos_centered.y - quadtree.bound.half_size.y / 2,
			},
			half_size = {quadtree.bound.half_size.x / 2, quadtree.bound.half_size.y / 2},
			pos_true = {
				quadtree.bound.pos_centered.x,
				quadtree.bound.pos_centered.y - quadtree.bound.half_size.y,
			},
		},
	)
	//SW
	quadtree.child_nodes[2] = create_quadtree(
		Rect {
			pos_centered = {
				quadtree.bound.pos_centered.x - quadtree.bound.half_size.x,
				quadtree.bound.pos_centered.y + quadtree.bound.half_size.y,
			},
			half_size = {quadtree.bound.half_size.x / 2, quadtree.bound.half_size.y / 2},
			pos_true = {
				quadtree.bound.pos_centered.x - quadtree.bound.half_size.x,
				quadtree.bound.pos_centered.y,
			},
		},
	)
	//SE
	quadtree.child_nodes[3] = create_quadtree(
		Rect {
			pos_centered = {
				quadtree.bound.pos_centered.x + quadtree.bound.half_size.x,
				quadtree.bound.pos_centered.y + quadtree.bound.half_size.y,
			},
			half_size = {quadtree.bound.half_size.x / 2, quadtree.bound.half_size.y / 2},
			pos_true = {quadtree.bound.pos_centered.x, quadtree.bound.pos_centered.y},
		},
	)

	// this should hopefully reassign points from parent quad to child nodes
	fmt.printf("quad.numPoints %i\n", quadtree.obj_index)
	for i := 0; i < int(quadtree.obj_index); i += 1 {
		for j := 0; j < MAX_CHILDREN; j += 1 {
			//loop over every c_node
			if contains_point(quadtree.child_nodes[j].bound, quadtree.objects[i].pos) {
				insert(quadtree.child_nodes[j], quadtree.objects[i])
			} else {
				fmt.printf("Couldn't reassign point!\n")
			}
		}
	}

	quadtree.obj_index = 0
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
	quadtreePtr = create_quadtree(
		Rect {
			pos_centered = {WIDTH / 2, HEIGHT / 2},
			half_size = {WIDTH / 2, HEIGHT / 2},
			pos_true = {0, 0},
		},
	)


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
	for !rl.WindowShouldClose() {
		update()
		draw()
		free_all(context.temp_allocator)
	}

	reset_tracking_allocator(&tracking_allocator)
}

update :: proc() {
	if !PAUSE {
		handle_input()
	}

	//Make sure we can pause/unpause
	if rl.IsKeyPressed(.SPACE) {
		PAUSE = !PAUSE
	}
}

handle_input :: proc() {
	if rl.IsKeyPressed(.W) {

	}
	if rl.IsKeyPressed(.S) {

	}
	if rl.IsKeyPressed(.A) {

	}
	if rl.IsKeyPressed(.D) {

	}
	if rl.IsKeyPressed(.LEFT_SHIFT) {

	}
	if rl.IsKeyReleased(.LEFT_SHIFT) {

	}

	if rl.IsMouseButtonPressed(.LEFT) {

	}
	if rl.IsMouseButtonPressed(.RIGHT) {

	}
}

draw_quad_tree :: proc(quadtree: ^QuadTree) {
	//if we have children, recall this recursively
	if quadtree.child_nodes[0] == nil {
		for i := 0; i < int(quadtree.capacity); i += 1 {
			draw_quad_tree(quadtree.child_nodes[i])
		}
	}

	for i := 0; i < int(quadtree.obj_index); i += 1 {
		fmt.printf(
			"Drawing Points x,y %f,%f\n",
			quadtree.objects[i].pos.x,
			quadtree.objects[i].pos.y,
		)
		rl.DrawPixel(i32(quadtree.objects[i].pos.x), i32(quadtree.objects[i].pos.y), rl.WHITE)
	}

	rl.DrawRectangleLines(
		i32(quadtree.bound.pos_true.x),
		i32(quadtree.bound.pos_true.y),
		i32(quadtree.bound.half_size.x * 2),
		i32(quadtree.bound.half_size.y * 2),
		rl.WHITE,
	)
}

checkCollisions :: proc() {

}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	//draw_quad_tree(quadtreePtr)

	rl.EndDrawing()
}
