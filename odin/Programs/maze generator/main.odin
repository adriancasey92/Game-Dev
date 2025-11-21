#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"
import "core:strings"
import rl "vendor:raylib"

//CONSTANTS
//types
Vec2 :: rl.Vector2

//window 
WIDTH :: 1600
HEIGHT :: 900

//maze 
maze_width :: 1000
maze_height :: 800
maze_start: Cell
maze_end: Cell
maze_xpos_offset: i32
maze_ypos_offset: i32
maze_cols: i32
maze_rows: i32

//cell
cell_wall_colour :: rl.WHITE
cell_size :: 20
current: ^Cell
cells_visited: i32

//program state flow
generating_maze: bool
maze_solved: bool
solving_maze: bool

//incrementing this changes our solve algorithm
maze_solve_algorithm: int
follow_wall_dir: int

//DEBUG
cell_wall_debug: bool
maze_printout_debug: bool

//Containers
maze: [dynamic]Cell
stack: [dynamic]Cell
solvestack: [dynamic]Cell
bounds: [dynamic]Cell

WINDOW_NAME :: "Maze Gen"
CENTER :: Vec2{WIDTH / 2, HEIGHT / 2}
BACKGROUND_COL :: rl.BLACK
PAUSE: bool

//Dummy struct
Cell :: struct {
	pos:        Vec2,
	cell_index: i32,
	walls:      [4]bool,
	visited:    bool,
}

//Random function
random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

//Random range function
randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

clear_all :: proc() {
	clear(&maze)
	clear(&stack)
	clear(&bounds)
	clear(&solvestack)
}

reset :: proc() {
	clear_all()
	init_program()
}

quit :: proc() {
	clear_all()
	rl.CloseWindow()
}

//initialize beginning state of our program
init_program :: proc() {
	fmt.printf("Init program:\n")

	//makes sure that when we reset our program, we do not lose our debug
	//if it was enabled previously
	if !cell_wall_debug {
		cell_wall_debug = false
	}
	if !maze_printout_debug {
		maze_printout_debug = false
	}
	//init start and end cell to {-1,-1} as a way to check they are set later
	//in our program
	maze_start = Cell {
		pos = {-1, -1},
	}
	maze_end = Cell {
		pos = {-1, -1},
	}

	//program state setup
	generating_maze = true
	solving_maze = false
	maze_solved = false

	//algorithm incrementer
	maze_solve_algorithm = 0
	cells_visited = 1
	follow_wall_dir = -1

	//maze setup
	maze_cols = i32(math.floor_div(maze_width, cell_size))
	maze_rows = i32(math.floor_div(maze_height, cell_size))
	maze_width := maze_cols * cell_size
	maze_height := maze_rows * cell_size
	maze_xpos_offset = (WIDTH - maze_width) / 2
	maze_ypos_offset = (HEIGHT - maze_height) / 2

	if maze_printout_debug {
		fmt.printf("Maze cols: %i\nMaze rows: %i\n", maze_cols, maze_rows)
		fmt.printf("Maze x offset: %i\nMaze y offset: %i\n", maze_xpos_offset, maze_ypos_offset)
	}
	offset := (WIDTH - maze_width) / 2

	for y := 0; y < int(maze_rows); y += 1 {
		for x := 0; x < int(maze_cols); x += 1 {
			c := Cell {
				pos        = Vec2{f32(x), f32(y)},
				visited    = false,
				cell_index = index(i32(x), i32(y)),
			}

			for i := 0; i < 4; i += 1 {
				c.walls[i] = true
			}
			append(&maze, c)
		}
	}
	current = &maze[randrange(i32(len(maze)))]
}

main :: proc() {
	defer delete(maze)
	defer delete(stack)
	defer delete(bounds)
	//Set to square
	rl.InitWindow(WIDTH, HEIGHT, WINDOW_NAME)
	if !rl.IsWindowReady() {
		fmt.printf("ERR: Window not ready?\n")
		return
	}

	rl.SetTargetFPS(1500)

	//init program
	init_program()

	//Program loop
	for !rl.WindowShouldClose() {
		update()
		draw()
		free_all(context.temp_allocator)
	}

	clear(&maze)
	clear(&stack)
	clear(&solvestack)
	clear(&bounds)
}

// Useful for finding the positing in an array for a 2D grid
// as long as x,y is within grid, returns the index for our 
// maze[]
//NOTE - Important that x and y are whole numbers for the purposes
// of finding an array index!
index :: proc(x, y: i32) -> i32 {
	if x < 0 || y < 0 || x > maze_cols - 1 || y > maze_rows - 1 {
		return -1
	}
	return x + y * maze_cols
}

//moveCell(cell) returns the index in maze[] for a valid cell neighbour of the cell. 
//1. it checks to make sure that there are no walls on our cell.walls[x], before then 
//2. checking that the cell neighbour exists (x_index!=-1)
//3. then if we have not visited the cell, add it as a valid neighbour to our list
//4. finally it chooses randomly out of the valid neighbours and returns the index
moveCell :: proc(cell: ^Cell) -> i32 {
	if maze_printout_debug {
		fmt.printf("moveCell()\n")
	}
	//we will always have at least one wall, so 3 valid neighbours max
	valid_neighbours: [3]i32
	//this is the current index for our valid neighbours array
	nidx := 0

	//cell_index is the index for the cell arg in maze[]
	cell_index := index(i32(cell.pos.x), i32(cell.pos.y))

	//cell.walls[] holds boolean values (true/false) for whether a wall is in a
	//position. 0=top, 1=right, 2=bottom, 3=left
	//if we do not have a wall top (if cell.walls[0] == false)
	if !cell.walls[0] {
		//top index is simply our current cell pos.y -1
		top_index := index(i32(cell.pos.x), i32(cell.pos.y - 1))
		//top index could be -1 if we are at the start/exit of a maze?
		//this is because we are removing the wall for our start/end 
		//positions to make our maze 'look' like a maze :)
		if top_index != -1 {
			//if we haven't visited this cell, it's a valid neighbour
			//this is important as we only want to travel to unvisited cells
			//to progress
			if !maze[top_index].visited && !maze[top_index].walls[2] {
				//add our top_index to valid_neighbours
				valid_neighbours[nidx] = top_index
				//increment the number of entries in valid_neighbours (it's size)
				nidx += 1
			}
		}
	}

	//wall right
	if !cell.walls[1] {
		right_index := index(i32(cell.pos.x + 1), i32(cell.pos.y))
		if right_index != -1 {
			if !maze[right_index].visited && !maze[right_index].walls[3] {
				valid_neighbours[nidx] = right_index
				nidx += 1
			}
		}
	}

	//wall Bottom
	if !cell.walls[2] {
		bottom_index := index(i32(cell.pos.x), i32(cell.pos.y + 1))
		if bottom_index != -1 {
			if !maze[bottom_index].visited && !maze[bottom_index].walls[0] {
				valid_neighbours[nidx] = bottom_index
				nidx += 1
			}
		}
	}

	//wall left
	if !cell.walls[3] {
		left_index := index(i32(cell.pos.x - 1), i32(cell.pos.y))
		if left_index != -1 {
			if !maze[left_index].visited && !maze[left_index].walls[1] {
				valid_neighbours[nidx] = left_index
				nidx += 1
			}
		}
	}

	// it should always be at least one
	if nidx > 0 {
		r := math.floor_f32(f32(rl.GetRandomValue(0, i32(nidx - 1))))
		return valid_neighbours[i32(r)]
	}

	return -1
}

printCell :: proc(cell: ^Cell) {
	fmt.printf("Cell index: %i\n", cell.cell_index)
	fmt.printf("Cell walls: %t\n", cell.walls)

}

moveCell_left_wall :: proc(cell: ^Cell) -> i32 {
	printCell(cell)
	if maze_printout_debug {
		fmt.printf("moveCell_left_wall()\n")
	}

	valid_neighbours: [3]i32
	nidx := 0

	//top
	if !cell.walls[0] {
		top_index := index(i32(cell.pos.x), i32(cell.pos.y - 1))
		if top_index != -1 {
			if !maze[top_index].visited && !maze[top_index].walls[2] {
				valid_neighbours[nidx] = top_index
				nidx += 1
			}
		} else {
			//direction is oppoite the entrance
			follow_wall_dir = 2
		}
	}

	//wall right
	if !cell.walls[1] {
		right_index := index(i32(cell.pos.x + 1), i32(cell.pos.y))
		if right_index != -1 {
			if !maze[right_index].visited && !maze[right_index].walls[3] {
				valid_neighbours[nidx] = right_index
				nidx += 1
			}
		} else {
			follow_wall_dir = 3
		}
	}

	//wall Bottom
	if !cell.walls[2] {
		bottom_index := index(i32(cell.pos.x), i32(cell.pos.y + 1))
		if bottom_index != -1 {
			if !maze[bottom_index].visited && !maze[bottom_index].walls[0] {
				valid_neighbours[nidx] = bottom_index
				nidx += 1
			}
		} else {
			follow_wall_dir = 0
		}
	}

	//wall left
	if !cell.walls[3] {
		left_index := index(i32(cell.pos.x - 1), i32(cell.pos.y))
		if left_index != -1 {
			if !maze[left_index].visited && !maze[left_index].walls[1] {
				valid_neighbours[nidx] = left_index
				nidx += 1
			}
		} else {
			follow_wall_dir = 1
		}
	}


	fmt.printf("Dir: %i\n", follow_wall_dir)
	switch (follow_wall_dir) 
	{
	//Direction is up
	case 0:
		fmt.printf("OUR MAZE ENTRANCE WAS TO THE BOTTOM\n")
	//Direction is right
	case 1:
		fmt.printf("OUR MAZE ENTRANCE WAS TO THE LEFT\n")
	//Direction is down
	case 2:
		fmt.printf("OUR MAZE ENTRANCE WAS TO THE UP\n")
	//Direction is left
	case 3:
		fmt.printf("OUR MAZE ENTRANCE WAS TO THE RIGHT\n")
	}

	return -1
}

//check neighbours
checkNeighbours :: proc(cell: ^Cell) -> i32 {
	//0 == top, 1 == right, 2 == bottom 3 == left
	neighbours: [4]i32
	curridx := 0

	top_index := index(i32(cell.pos.x), i32(cell.pos.y - 1))
	right_index := index(i32(cell.pos.x + 1), i32(cell.pos.y))
	bottom_index := index(i32(cell.pos.x), i32(cell.pos.y + 1))
	left_index := index(i32(cell.pos.x - 1), i32(cell.pos.y))
	cell_index := index(i32(cell.pos.x), i32(cell.pos.y))

	if top_index != -1 {
		if !maze[top_index].visited {
			neighbours[curridx] = top_index
			curridx += 1
		}
	}
	if right_index != -1 {
		if !maze[right_index].visited {
			neighbours[curridx] = right_index
			curridx += 1
		}
	}
	if bottom_index != -1 {
		if !maze[bottom_index].visited {
			neighbours[curridx] = bottom_index
			curridx += 1
		}
	}
	if left_index != -1 {
		if !maze[left_index].visited {
			neighbours[curridx] = left_index
			curridx += 1
		}
	}

	if generating_maze {
		// Left wall
		if left_index == -1 {
			edge_cell_left := maze[cell_index]
			edge_cell_left.walls[0] = false
			edge_cell_left.walls[1] = false
			edge_cell_left.walls[2] = false
			edge_cell_left.walls[3] = true
			append(&bounds, edge_cell_left)
		}

		//right wall
		if right_index == -1 {
			edge_cell_right := maze[cell_index]
			edge_cell_right.walls[0] = false
			edge_cell_right.walls[1] = true
			edge_cell_right.walls[2] = false
			edge_cell_right.walls[3] = false
			append(&bounds, edge_cell_right)
		}

		//right wall
		if top_index == -1 {
			edge_cell_top := maze[cell_index]
			edge_cell_top.walls[0] = true
			edge_cell_top.walls[1] = false
			edge_cell_top.walls[2] = false
			edge_cell_top.walls[3] = false
			append(&bounds, edge_cell_top)
		}
		//right wall
		if bottom_index == -1 {
			edge_cell_bottom := maze[cell_index]
			edge_cell_bottom.walls[0] = false
			edge_cell_bottom.walls[1] = false
			edge_cell_bottom.walls[2] = true
			edge_cell_bottom.walls[3] = false
			append(&bounds, edge_cell_bottom)
		}
	}

	if curridx > 0 {
		r := math.floor_f32(f32(rl.GetRandomValue(0, i32(curridx - 1))))
		if maze_printout_debug {
			fmt.printf("Returning neighbours[%i]: %i\n", curridx, neighbours[i32(r)])
		}
		return neighbours[i32(r)]
	}

	return -1
}

//Takes in the indexes of two cells. Calculate what walls to be removed
remove_walls :: proc(curr, next: i32) {
	diffx := maze[curr].pos.x - maze[next].pos.x
	diffy := maze[curr].pos.y - maze[next].pos.y
	//right
	if diffx == 1 {
		maze[curr].walls[3] = false
		maze[next].walls[1] = false
	} else if diffx == -1 {
		maze[curr].walls[1] = false
		maze[next].walls[3] = false
	}

	if diffy == 1 {
		maze[curr].walls[0] = false
		maze[next].walls[2] = false
	} else if diffy == -1 {
		maze[curr].walls[2] = false
		maze[next].walls[0] = false
	}
}

update_generating_maze :: proc() {
	//set current maze square to true (we have visited it)
	current.visited = true

	//returns the index value for the next square to check
	next := checkNeighbours(current)
	//fmt.printf("Next index is : %i\n", next)
	if cells_visited == maze_cols * maze_width / cell_size {
		generating_maze = false
		solving_maze = true
	} else if (next == -1) {
		// if we have no valid return we get -1
		//if our stack size is above zero
		if len(stack) > 0 {
			//c is the current cell index to be popped
			c := index(i32(stack[len(stack) - 1].pos.x), i32(stack[len(stack) - 1].pos.y))
			pop(&stack)
			current = &maze[c]

			// if we have moved through every node, maze is generated

		} else {
			generating_maze = false
			solving_maze = true
		}
	} else {
		maze[next].visited = true
		cells_visited += 1
		currentidx := index(i32(current.pos.x), i32(current.pos.y))
		append(&stack, maze[currentidx])
		remove_walls(currentidx, next)
		current = &maze[next]
	}

	if generating_maze == false {
		//choosing start and end points
		if maze_start.pos.x == -1 || maze_end.pos.x == -1 {
			maze_start = bounds[randrange(i32(len(bounds) - 1))]
			maze_end = bounds[randrange(i32(len(bounds) - 1))]
			for index(i32(maze_start.pos.x), i32(maze_start.pos.y)) ==
			    index(i32(maze_end.pos.x), i32(maze_end.pos.y)) {
				maze_end = bounds[randrange(i32(len(bounds) - 1))]
			}
			if maze_start.pos.x == -1 {
				quit()
			}
			if maze_end.pos.x == -1 {
				quit()
			}
			for &c in maze {
				c.visited = false
			}


			if is_in_corner(maze_start) {
				fmt.printf("maze_start is in a corner\n")
			}

			//corner check


			current = &maze_start
			maze[index(i32(current.pos.x), i32(current.pos.y))].visited = true
		}
	}
}

is_in_corner :: proc(cell: Cell) -> bool {
	if cell.cell_index == 0 ||
	   cell.cell_index == i32(len(maze) - 1) ||
	   cell.cell_index == i32(maze_cols) ||
	   (cell.pos.x == 0 && i32(cell.pos.y) == maze_rows) {
		return true
	}
	return false
}

//reset so we can solve with other algorithms and show workings
reset_solve_vars :: proc() {
	maze_solved = false
	solving_maze = true
	fmt.printf("reset_solve_vars\n")
	clear(&solvestack)
	for &c in maze {
		c.visited = false
	}
	current = &maze_start
	maze[current.cell_index].visited = true
}

//follow wall solver
solve_wall_follower :: proc() {
	//fmt.printf("solve_wall_follower_function()\n")
	current.visited = true
	nextCell := moveCell_left_wall(current)


}

solve_old_function :: proc() {
	//fmt.printf("solve_old_function()\n")
	current.visited = true
	//This should be a cell with the highest score
	nextCell := moveCell(current)
	//check first
	if index(i32(current.pos.x), i32(current.pos.y)) ==
	   index(i32(maze_end.pos.x), i32(maze_end.pos.y)) {
		current.visited = true
		currentidx := index(i32(current.pos.x), i32(current.pos.y))
		append(&solvestack, maze[currentidx])
		maze_solved = true
	}

	if (nextCell == -1) {
		//if our stack size is above zero
		if len(solvestack) > 0 {
			//c is the current cell index to be popped
			c := index(
				i32(solvestack[len(solvestack) - 1].pos.x),
				i32(solvestack[len(solvestack) - 1].pos.y),
			)
			pop(&solvestack)
			current = &maze[c]
		}
	} else {
		maze[nextCell].visited = true
		currentidx := index(i32(current.pos.x), i32(current.pos.y))
		append(&solvestack, maze[currentidx])
		current = &maze[nextCell]
	}
}

//switch between solve types
update_solving_maze :: proc() {
	//fmt.printf("maze_solve val: %i\n", maze_solve_algorithm)
	switch (maze_solve_algorithm) 
	{
	case 0:
		if maze_printout_debug {
			fmt.printf("update_solving_maze() - original function()\n")
		}
		solve_old_function()
	case 1:
		if maze_printout_debug {
			fmt.printf("update_solving_maze() - wall_follower()\n")
		}
		solve_wall_follower()
	}
}


update :: proc() {
	//if not paused run
	if !PAUSE {
		//handle keyboard/mouse input
		handle_input()
		//maze generation
		if generating_maze {
			update_generating_maze()
		}
		//solving maze
		if solving_maze {
			if !maze_solved {
				update_solving_maze()
			}
		}
	}
	//Make sure we can pause/unpause
	if rl.IsKeyPressed(.P) {
		PAUSE = !PAUSE
	}
}

handle_input :: proc() {
	if rl.IsKeyPressed(.R) {
		reset()
	}

	if rl.IsKeyPressed(.SPACE) {
		//only change algorithm when solving
		//fmt.printf("Space pressed: gen_maze %t\n", generating_maze)
		if !generating_maze {
			//fmt.printf("Retting solve_vars\n")
			reset_solve_vars()
		}
		maze_solve_algorithm += 1
		if (maze_solve_algorithm > 1) {
			maze_solve_algorithm = 0
		}
	}

	if rl.IsKeyPressed(.A) {

	}
	if rl.IsKeyPressed(.D) {

	}
	if rl.IsKeyPressed(.F1) {
		cell_wall_debug = !cell_wall_debug
	}

	if rl.IsKeyPressed(.F2) {
		maze_printout_debug = !maze_printout_debug
	}

	if rl.IsKeyPressed(.LEFT_SHIFT) {

	}
	if rl.IsKeyReleased(.LEFT_SHIFT) {

	}

	if rl.IsMouseButtonPressed(.LEFT) {
		mpos := rl.GetMousePosition()
		fmt.printf("Mouse clicked at %f,%f\n", mpos.x, mpos.y)
		fmt.printf(
			"maze_start.pos.x %f\nmaze_start.pos.y %f\n",
			f32(pos_to_screen_coord(maze_start.pos.x)) + f32(maze_xpos_offset),
			f32(pos_to_screen_coord(maze_start.pos.y)) + f32(maze_ypos_offset),
		)
		if rl.CheckCollisionPointRec(
			mpos,
			rl.Rectangle {
				f32(pos_to_screen_coord(maze_start.pos.x)) + f32(maze_xpos_offset),
				f32(pos_to_screen_coord(maze_start.pos.y)) + f32(maze_ypos_offset),
				cell_size,
				cell_size,
			},
		) {
			fmt.printf("CLICKED ON START CELL\n")
		}
	}
	if rl.IsMouseButtonPressed(.RIGHT) {

	}
}

pos_to_screen_coord :: proc(pos: f32) -> i32 {
	return i32(pos * cell_size)
}

checkCollisions :: proc() {

}

draw_cell_c :: proc(cell: Cell, col: rl.Color) {
	offset := i32(0)
	xPos: i32
	yPos: i32
	endPosX: i32
	endPosY: i32
	//draw top
	if cell.walls[0] == true {
		xPos = i32((cell.pos.x) * cell_size) + maze_xpos_offset
		yPos = i32((cell.pos.y) * cell_size) + maze_ypos_offset
		endPosX = xPos + cell_size
		endPosY = yPos
		rl.DrawLine(xPos + offset, yPos + offset, endPosX - offset, endPosY + offset, col)
	}

	//right
	if cell.walls[1] == true {
		xPos = i32((cell.pos.x) * cell_size) + maze_xpos_offset + cell_size
		yPos = i32((cell.pos.y) * cell_size) + maze_ypos_offset
		endPosX = xPos
		endPosY := yPos + cell_size
		rl.DrawLine(xPos - offset, yPos + offset, endPosX - offset, endPosY - offset, col)
	}

	//bottom
	if cell.walls[2] == true {
		xPos = i32((cell.pos.x) * cell_size) + maze_xpos_offset
		yPos = i32((cell.pos.y) * cell_size) + maze_ypos_offset + cell_size
		endPosX = xPos + cell_size
		endPosY = yPos

		rl.DrawLine(xPos + offset, yPos - offset, endPosX - offset, endPosY - offset, col)
	}
	//left
	if cell.walls[3] == true {
		xPos = i32((cell.pos.x) * cell_size) + maze_xpos_offset
		yPos = i32((cell.pos.y) * cell_size) + maze_ypos_offset
		endPosX = xPos
		endPosY = yPos + cell_size

		rl.DrawLine(xPos + offset, yPos - offset, endPosX + offset, endPosY + offset, col)
	}
}

draw_cell :: proc(cell: Cell) {

	cellwallcolour: rl.Color
	cellwallcolour = cell_wall_colour
	offset := i32(0)
	if cell_wall_debug {
		offset = i32(cell_size * .1)
	}
	//fmt.printf("Drawing cell x,y: %f,%f\n", cell.pos.x, cell.pos.y)

	xPos: i32
	yPos: i32
	endPosX: i32
	endPosY: i32


	//draw top
	if cell.walls[0] == true {
		xPos = pos_to_screen_coord(cell.pos.x) + maze_xpos_offset
		yPos = pos_to_screen_coord(cell.pos.y) + maze_ypos_offset
		endPosX = xPos + cell_size
		endPosY = yPos
		if cell_wall_debug {
			cellwallcolour = rl.RED
		}
		rl.DrawLine(
			xPos + offset,
			yPos + offset,
			endPosX - offset,
			endPosY + offset,
			cellwallcolour,
		)
	}

	//right
	if cell.walls[1] == true {
		xPos = pos_to_screen_coord(cell.pos.x) + maze_xpos_offset + cell_size
		yPos = pos_to_screen_coord(cell.pos.y) + maze_ypos_offset
		endPosX = xPos
		endPosY := yPos + cell_size
		if cell_wall_debug {
			cellwallcolour = rl.BLUE
		}
		rl.DrawLine(
			xPos - offset,
			yPos + offset,
			endPosX - offset,
			endPosY - offset,
			cellwallcolour,
		)
	}

	//bottom
	if cell.walls[2] == true {
		xPos = pos_to_screen_coord(cell.pos.x) + maze_xpos_offset
		yPos = pos_to_screen_coord(cell.pos.y) + maze_ypos_offset + cell_size
		endPosX = xPos + cell_size
		endPosY = yPos
		if cell_wall_debug {
			cellwallcolour = rl.GREEN
		}
		rl.DrawLine(
			xPos + offset,
			yPos - offset,
			endPosX - offset,
			endPosY - offset,
			cellwallcolour,
		)
	}
	//left
	if cell.walls[3] == true {
		xPos = pos_to_screen_coord(cell.pos.x) + maze_xpos_offset
		yPos = pos_to_screen_coord(cell.pos.y) + maze_ypos_offset
		endPosX = xPos
		endPosY = yPos + cell_size
		if cell_wall_debug {
			cellwallcolour = rl.YELLOW
		}
		rl.DrawLine(
			xPos + offset,
			yPos - offset,
			endPosX + offset,
			endPosY + offset,
			cellwallcolour,
		)
	}
}

draw_maze_generation :: proc() {
	for cell in maze {
		if cell.visited {
			rl.DrawRectangle(
				i32(f32(pos_to_screen_coord(cell.pos.x)) + f32(maze_xpos_offset)),
				i32(f32(pos_to_screen_coord(cell.pos.y)) + f32(maze_ypos_offset)),
				cell_size,
				cell_size,
				rl.GREEN,
			)
		}
		draw_cell(cell)
	}

	rl.DrawRectangle(
		i32(f32(pos_to_screen_coord(current.pos.x)) + f32(maze_xpos_offset)),
		i32(f32(pos_to_screen_coord(current.pos.y)) + f32(maze_ypos_offset)),
		cell_size,
		cell_size,
		rl.ORANGE,
	)
}

draw_maze_solving :: proc() {
	//Draw maze and cell
	for cell in maze {
		if cell.visited {
			rl.DrawRectangle(
				i32(f32(pos_to_screen_coord(cell.pos.x)) + f32(maze_xpos_offset)),
				i32(f32(pos_to_screen_coord(cell.pos.y)) + f32(maze_ypos_offset)),
				cell_size,
				cell_size,
				rl.BLUE,
			)
		}
		if cell.cell_index != maze_start.cell_index && cell.cell_index != maze_end.cell_index {
			draw_cell(cell)
		}

	}
	//show current solving
	for cell in solvestack {
		if cell.visited {
			rl.DrawRectangle(
				i32(pos_to_screen_coord(cell.pos.x) + maze_xpos_offset + (cell_size * .1)),
				i32(pos_to_screen_coord(cell.pos.y) + maze_ypos_offset + (cell_size * .1)),
				cell_size * .5,
				cell_size * .5,
				rl.YELLOW,
			)
		}
	}
	//start 
	rl.DrawRectangle(
		i32(((maze_start.pos.x) * cell_size) + f32(maze_xpos_offset)),
		i32(((maze_start.pos.y) * cell_size) + f32(maze_ypos_offset)),
		cell_size,
		cell_size,
		rl.GREEN,
	)
	//end
	rl.DrawRectangle(
		i32(f32(pos_to_screen_coord(maze_end.pos.x)) + f32(maze_xpos_offset)),
		i32(f32(pos_to_screen_coord(maze_end.pos.y)) + f32(maze_ypos_offset)),
		cell_size,
		cell_size,
		rl.RED,
	)
	//current cell
	rl.DrawRectangle(
		i32(f32(pos_to_screen_coord(current.pos.x)) + f32(maze_xpos_offset)),
		i32(f32(pos_to_screen_coord(current.pos.y)) + f32(maze_ypos_offset)),
		cell_size,
		cell_size,
		rl.ORANGE,
	)
}

draw_maze_completed :: proc() {
	for cell in maze {
		if cell.cell_index != maze_start.cell_index && cell.cell_index != maze_end.cell_index {
			draw_cell(cell)
		}
	}
	for cell in solvestack {
		if cell.visited {
			rl.DrawRectangle(
				i32(
					f32(pos_to_screen_coord(cell.pos.x)) + f32(maze_xpos_offset) + (cell_size / 4),
				),
				i32(
					f32(pos_to_screen_coord(cell.pos.y)) + f32(maze_ypos_offset) + (cell_size / 4),
				),
				cell_size / 4,
				cell_size / 4,
				rl.YELLOW,
			)
		}
	}
	//start 
	rl.DrawRectangleLines(
		i32(((maze_start.pos.x) * cell_size) + f32(maze_xpos_offset)),
		i32(((maze_start.pos.y) * cell_size) + f32(maze_ypos_offset)),
		cell_size,
		cell_size,
		rl.GREEN,
	)
	//end
	rl.DrawRectangleLines(
		i32(((maze_end.pos.x) * cell_size) + f32(maze_xpos_offset)),
		i32(((maze_end.pos.y) * cell_size) + f32(maze_ypos_offset)),
		cell_size,
		cell_size,
		rl.RED,
	)
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	// if we are generating draw the maze generating
	if generating_maze {
		draw_maze_generation()
	}

	if solving_maze {
		if !maze_solved {
			draw_maze_solving()
		} else {
			draw_maze_completed()
		}

	}
	//rl.EndMode2D()
	rl.EndDrawing()
}
