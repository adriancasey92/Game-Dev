#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:sort"
import "core:strings"
import rl "vendor:raylib"

//TYPES
Vec2 :: rl.Vector2
Vec3 :: rl.Vector3

//WINDOW
WIDTH: i32
HEIGHT: i32
WINDOW_NAME :: "Quadtree Asteroids"
BACKGROUND_COL :: rl.BLACK


//CAMERA
camera: rl.Camera2D
camera_width: f32
camera_height: f32
camera_min: Vec2
camera_max: Vec2
camera_rect: Rect

//GAME CONSTANTS
GAME_RUNNING: bool
GAME_OVER: bool
GAME_WON: bool
PAUSE: bool

//RENDERING
TOTAL_ENTITIES_RENDERED: i32
ZOOM_FONT: i32

//TRAIL
TRAIL_LIFETIME :: 3.0

//DEBUG
DEBUG_FONT_SIZE :: 15
DEBUG_WINDOW_WIDTH: i32
DEBUG: bool
DISPLAY_QUADTREE: bool
DEBUG_ENTITIES: bool
DEBUG_DRAW_QUADS: bool
DEBUG_DRAW_QUAD_POINT_NUM: bool
DEBUG_LEVEL_QUAD_FONT :: 150
SELECTED_ENTITY_ID: i32
SELECTED_ENTITY_BOOL: bool

//controls the flow of the game
GameState :: enum {
	MENU,
	GAMEPLAY,
	ENDING,
}

//LEVEL
LEVEL_QUAD_SIZE :: 150
LEVEL_NUM_QUAD_W :: 3
LEVEL_NUM_QUAD_H :: 3

//ENTITIES
TOTAL_ENTITIES: i32

Level :: struct {
	ENTITIES_LEVEL: Entity,
	quadrants:      [LEVEL_NUM_QUAD_W * LEVEL_NUM_QUAD_H]Quad,
}

Quad :: struct {
	size:          Vec2,
	player_inside: bool,
	enemy_inside:  bool,
	centered_pos:  Vec2,
	actual_pos:    Vec2,
	index:         i32,
}

//QUADTREE
MAX_OBJECTS :: 8
MAX_NODES :: 1024
QUAD_AREAS :: 4
MAX_DEPTH :: 5

//ENTITIES
LOCK_ENTITIES: bool
ENTITIES: [MAX_ENTITIES_TOTAL]Entity
DEAD_ENTITIES: [MAX_ENTITIES_TOTAL]i32
DEAD_ENTITIES_ID: i32
ENTITY_ID: i32
MAX_ENTITIES_PER_QUAD :: 4
MAX_ENTITIES_TOTAL :: 500

Quadtree :: struct {
	nodes:      [MAX_NODES]QuadtreeNode, // Flat array of nodes
	node_count: i32, // Keeps track of the next available node index
}

QuadtreeNode :: struct {
	bounds:       Rect,
	entities_id:  [MAX_ENTITIES_PER_QUAD]i32,
	entity_count: i32,
	children:     [4]i32, // Indices into the node pool
	parent:       i32,
	has_children: bool,
	depth:        i32,
}

Rect :: struct {
	min, max: Vec2,
	pos:      Vec2,
}

Player :: struct {
	rect: rl.Rectangle,
}

//PLAYER
PLAYER_BASE_SIZE :: 20
PLAYER_SPEED :: 6
PLAYER_MAX_SHOTS :: 10
PLAYER_SHIPHEIGHT: f32

Entity :: struct {
	pos:          Vec2,
	speed:        Vec2,
	size:         Vec2,
	id:           i32,
	rotation:     f32,
	acceleration: f32,
	color:        rl.Color,
	type:         Entity_Type,
	trail:        Trail,
	debug:        bool,
}

Trail :: struct {
	pos:                   Vec2,
	time:                  f32,
	radius:                f32,
	active:                bool,
	particles:             [5]Particle,
	current_partcicle_idx: i32,
	color:                 rl.Color,
	type:                  Trail_Type,
}

Particle :: struct {
	pos:      Vec2,
	lifetime: f32,
	active:   bool,
}

Trail_Type :: enum {
	Trail_Smoke,
	Trail_Spark,
	Trail_Explosion,
}

Projectile_Type :: union {
	Projectile_Rocket,
	Projectile_Laser,
	Projectile_Bullet,
}

Projectile_Rocket :: struct {
	color:    rl.Color,
	lifetime: f32,
}

Projectile_Laser :: struct {
	color:    rl.Color,
	lifetime: f32,
}

Projectile_Bullet :: struct {
	radius:   f32,
	color:    rl.Color,
	lifetime: f32,
}

Entity_Type :: union {
	Entity_Player,
	Entity_Enemy,
	Entity_Projectile,
	Entity_Asteroid,
}

Enemy_Entity_Type :: union {
	Enemy_Ship_Basic,
	Enemy_Ship_Advanced,
}

Enemy_Ship_Basic :: struct {}
ENEMY_BASIC_SHIPHEIGHT: f32
ENEMY_BASIC_BASE_SIZE :: 5
MAX_ENEMY_BASIC_SHIPS :: 10
ENEMY_BASIC_SHIP_COUNT: i32

Enemy_Ship_Advanced :: struct {}
ENEMY_ADVANCED_SHIPHEIGHT: f32
ENEMY_ADVANCED_BASE_SIZE :: 2
MAX_ENEMY_ADVANCED_SHIPS :: 2
ENEMY_ADVANCED_SHIP_COUNT: i32

Entity_Projectile :: struct {
	radius: f32,
	active: bool,
	type:   Projectile_Type,
}

Entity_Player :: struct {
	can_fire: bool,
	collider: Vec3,
}
Entity_Enemy :: struct {
	can_fire:   bool,
	collider:   Vec3,
	enemy_type: Enemy_Entity_Type,
}

Entity_Asteroid :: struct {
	radius: f32,
	type:   Asteroid_Type,
}

Asteroid_Type :: enum {
	Asteroid_Large,
	Asteroid_Medium,
	Asteroid_Small,
}

//ASTEROID
ASTEROID_SPEED :: 2
MAX_LARGE_ASTEROIDS :: 4
MAX_MEDIUM_ASTEROIDS :: 8
MAX_SMALL_METEORS :: 16

//ENEMIES

large_asteroid_count: i32
medium_asteroid_count: i32
small_asteroid_count: i32
asteroids_destroyed: i32


//HANDLES
currentState: GameState
quadtree: Quadtree
level: Level
player_id: i32

//TIMESTEP
time: f32
d_time: f32

//Random function 
random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

//Random range function
randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

get_random_coord :: proc() -> Vec2 {
	return Vec2 {
		random_uniform(
			-(LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2,
			(LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2,
		),
		random_uniform(
			-(LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2,
			(LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2,
		),
	}
}

within_player_camera_range :: proc(e: Entity) -> bool {

	if e.pos.x > camera_min.x &&
	   e.pos.x < camera_max.x &&
	   e.pos.y > camera_min.y &&
	   e.pos.y < camera_max.y {
		return true
	}
	return false
}

is_inside_quad :: proc(e: Entity, q: Quad) -> bool {
	v1, v2, v3 := get_triangle_pos(e.pos, e.rotation)

	if rl.CheckCollisionPointRec(
		   v1,
		   rl.Rectangle{q.actual_pos.x, q.actual_pos.y, q.size.x, q.size.y},
	   ) ||
	   rl.CheckCollisionPointRec(
		   v2,
		   rl.Rectangle{q.actual_pos.x, q.actual_pos.y, q.size.x, q.size.y},
	   ) ||
	   rl.CheckCollisionPointRec(
		   v3,
		   rl.Rectangle{q.actual_pos.x, q.actual_pos.y, q.size.x, q.size.y},
	   ) {
		return true
	}
	return false
}

create_entity :: proc(type: string, pos: Vec2) -> i32 {
	//fmt.printf("create_entity() - ENTITY_ID: %i\n", ENTITY_ID)
	curr_id := ENTITY_ID

	if ENTITY_ID >= MAX_ENTITIES_TOTAL {
		fmt.printf("create_entity() - ENTITY_ID: %i\n", ENTITY_ID)
		fmt.printf("create_entity() - Max entities reached\n")
		return -1
	}
	switch (type) 
	{
	case "player":
		ENTITIES[ENTITY_ID] = create_player_entity(pos, curr_id)
	case "enemy_basic":
		ENTITIES[ENTITY_ID] = create_enemy_entity(pos, curr_id)
		ENEMY_BASIC_SHIP_COUNT += 1
	case "enemy_advanced":
		ENTITIES[ENTITY_ID] = create_enemy_entity(pos, curr_id)
		ENEMY_ADVANCED_SHIP_COUNT += 1
	case "asteroid1":
		ENTITIES[ENTITY_ID] = create_asteroid_entity(pos, curr_id, .Asteroid_Large)
	case "asteroid2":
		ENTITIES[ENTITY_ID] = create_asteroid_entity(pos, curr_id, .Asteroid_Medium)
	case "asteroid3":
		ENTITIES[ENTITY_ID] = create_asteroid_entity(pos, curr_id, .Asteroid_Small)
	case "missile":
		ENTITIES[ENTITY_ID] = create_missile_entity(pos, curr_id)
	}

	TOTAL_ENTITIES += 1
	ENTITY_ID += 1
	fmt.printf("create_entity() - ENTITY_ID: %i\n", ENTITY_ID)
	fmt.printf("total entities: %i\n", TOTAL_ENTITIES)
	//fmt.printf("create_entity() - ENTITY_ID is now: %i\n", ENTITY_ID)

	return curr_id
}

delete_random_enemy_entity :: proc() {
	//fmt.printf("delete_random_enemy_entity()\n")
	if ENTITY_ID > 0 {
		//fmt.printf("delete_random_enemy_entity() - ENTITY_ID: %i\n", ENTITY_ID)
		fin := false
		// can never == 0
		id := random_uniform(1, f32(ENTITY_ID))
		fmt.printf("Total number of entities is: %i\n", ENTITY_ID)
		delete_entity(i32(id))
		fmt.printf("delete_random_enemy_entity() - Deleted entity with ID: %i\n", id)
		fmt.printf("Total number of entities is: %i\n", ENTITY_ID)

	}
}

delete_entity :: proc(id: i32) {
	/*fmt.printf("delete_entity() - ENTITY_ID: %i\n", ENTITY_ID)
	fmt.printf("delete_entity() - ID: %i\n", id)
	fmt.printf("delete_entity() - ENTITIES[%i]: %v\n", id, ENTITIES[id])*/

	if TOTAL_ENTITIES == 1 {
		fmt.printf("Only entity left is Player\n")
		ENTITIES[player_id] = Entity{}
		fmt.printf("Game over\n")
	} else {
		ENTITIES[id] = Entity{}
	}

	for i := id; i < TOTAL_ENTITIES - 1; i += 1 {
		fmt.printf("Moving entities down: %i\n", i)
		ENTITIES[i] = ENTITIES[i + 1]
	}
	TOTAL_ENTITIES -= 1
	ENTITY_ID -= 1
	//fmt.printf("delete_entity() - ENTITY_ID is now: %i\n", ENTITY_ID)
}


create_player_entity :: proc(pos: Vec2, id: i32) -> Entity {
	fmt.printf("create_player_entity(): %i\n", id)
	e := Entity{}
	e.pos = pos
	e.speed = {0, 0}
	e.acceleration = 0
	e.rotation = 0
	e.color = rl.LIGHTGRAY
	e.id = id
	e.type = Entity_Player {
		can_fire = true,
		collider = Vec3 {
			e.pos.x + math.sin_f32(e.rotation * rl.DEG2RAD) * (PLAYER_SHIPHEIGHT / 2.5),
			e.pos.y - math.cos_f32(e.rotation * rl.DEG2RAD) * (PLAYER_SHIPHEIGHT / 2.5),
			12,
		},
	}
	e.trail = Trail {
		pos                   = e.pos,
		time                  = 5,
		radius                = 2,
		active                = false,
		color                 = rl.RED,
		type                  = .Trail_Smoke,
		current_partcicle_idx = 0,
		particles             = {},
	}

	for &p in e.trail.particles {
		p.pos = e.pos
		p.lifetime = 5
		p.active = false
	}
	return e
}

create_enemy_entity :: proc(pos: Vec2, id: i32) -> Entity {
	//fmt.printf("create_enemy_entity()\n")
	//fmt.printf("Random pos is (x,y): %f,%f\n", pos.x, pos.y)
	e := Entity{}
	e.pos = pos
	e.speed = {0, 0}
	e.acceleration = 0
	e.rotation = random_uniform(0, 360)
	e.color = rl.ORANGE
	e.id = id
	e.type = Entity_Enemy {
		can_fire = true,
		collider = Vec3 {
			e.pos.x + math.sin_f32(e.rotation * rl.DEG2RAD) * (ENEMY_BASIC_SHIPHEIGHT / 2.5),
			e.pos.y - math.cos_f32(e.rotation * rl.DEG2RAD) * (ENEMY_BASIC_SHIPHEIGHT / 2.5),
			12,
		},
	}

	return e
}

create_missile_entity :: proc(pos: Vec2, id: i32) -> Entity {
	e := Entity{}
	e.pos = pos
	e.id = id
	e.type = Entity_Projectile {
		radius = 15,
		active = true,
		type = Projectile_Rocket{color = rl.RED, lifetime = 5},
	}
	return e
}

fire_missile :: proc(id: i32) {
	fmt.printf("fire_missile()\n")
	fmt.printf("Firing missile from entity %i\n", id)
	m_id := create_entity("missile", ENTITIES[id].pos)
	ENTITIES[m_id].speed.x = math.sin_f32(ENTITIES[id].rotation * rl.DEG2RAD) * 10
	ENTITIES[m_id].speed.y = math.cos_f32(ENTITIES[id].rotation * rl.DEG2RAD) * 10
	ENTITIES[m_id].rotation = ENTITIES[id].rotation
}

create_asteroid_entity :: proc(pos: Vec2, id: i32, type: Asteroid_Type) -> Entity {
	e := Entity{}
	e.pos = pos
	e.speed = {0, 0}
	e.acceleration = 0
	e.rotation = random_uniform(0, 360)
	e.color = rl.ORANGE
	e.id = id
	e.type = Entity_Asteroid {
		radius = 0,
		type   = type,
	}

	return e
}

reset_quadtree :: proc() {
	//fmt.printf("Resetting quadtree\n")
	for i := 0; i < int(quadtree.node_count); i += 1 {
		//fmt.printf("Resetting node: %i\n", i)
		node := &quadtree.nodes[i]
		node.entity_count = 0
		node.has_children = false
	}

	init_quadtree(&quadtree)
}

init_quadtree :: proc(tree: ^Quadtree) {
	total_level_size := LEVEL_QUAD_SIZE * LEVEL_NUM_QUAD_W
	root_bounds := Rect {
		min = {f32(0 - (total_level_size / 2)), f32(0 - (total_level_size / 2))},
		max = {f32((total_level_size / 2)), f32((total_level_size / 2))},
	}
	//	fmt.printf("bounds pos: %v,%v\n", root_bounds.min, root_bounds.max)

	tree.node_count = 1
	tree.nodes[0].depth = 1
	tree.nodes[0] = QuadtreeNode {
		bounds       = root_bounds,
		entity_count = 0,
		has_children = false,
		parent       = -1,
	}
}

init_enemies :: proc() {

	fmt.printf("Init enemies\n")
	//create enemies
	for i := 0; i < 10 - 1; i += 1 {
		create_entity("enemy_basic", get_random_coord())
	}

	/*for i := 0; i < MAX_ENEMY_BASIC_SHIPS; i += 1 {
		create_entity("enemy_basic", get_random_coord())
	}
	for i := 0; i < MAX_ENEMY_ADVANCED_SHIPS; i += 1 {
		create_entity("enemy_advanced", get_random_coord())
	}*/
	//create_entity("enemy_basic", get_random_coord())
	//create_entity("enemy_advanced", get_random_coord())
}

init_program :: proc() {
	WIDTH := rl.GetScreenWidth()
	HEIGHT := rl.GetScreenHeight()

	//Game setup
	GAME_RUNNING = true
	GAME_OVER = false
	GAME_WON = false
	DEBUG_ENTITIES = false
	DISPLAY_QUADTREE = false
	//Player
	PLAYER_SHIPHEIGHT = 0 // this gets set later

	//Enemy
	ENEMY_BASIC_SHIPHEIGHT = 0
	ENEMY_ADVANCED_SHIPHEIGHT = 0

	ENTITY_ID = 0
	currentState = .GAMEPLAY

	curx, cury: i32
	total_level_size := LEVEL_QUAD_SIZE * LEVEL_NUM_QUAD_W
	fmt.printf("TotalLevel size: %i\n", total_level_size)
	curx = curx - i32(total_level_size) / 2
	xMIN := curx
	cury = cury - i32(total_level_size) / 2
	yMIN := cury
	count := 0

	for i := 0; i < LEVEL_NUM_QUAD_W; i += 1 {
		for j := 0; j < LEVEL_NUM_QUAD_H; j += 1 {
			level.quadrants[count].size = {LEVEL_QUAD_SIZE, LEVEL_QUAD_SIZE}
			level.quadrants[count].actual_pos = {f32(curx), f32(cury)}
			level.quadrants[count].index = i32(j + i * LEVEL_NUM_QUAD_W)

			fmt.printf(
				"Actual %i : Curx,Cury %v\n",
				level.quadrants[count].index,
				level.quadrants[count].actual_pos,
			)
			curx += LEVEL_QUAD_SIZE
			count += 1
		}
		cury += LEVEL_QUAD_SIZE
		curx = xMIN
	}

	camera = {}
	posx, posy: i32
	velx, vely: i32
	correct_range: bool

	//Player
	PLAYER_SHIPHEIGHT = (PLAYER_BASE_SIZE / 2) / math.tan_f32(20 * rl.DEG2RAD)
	player_id = create_entity("player", {-50, -50})

	//Enemy
	ENEMY_BASIC_SHIPHEIGHT = (ENEMY_BASIC_BASE_SIZE / 2) / math.tan_f32(20 * rl.DEG2RAD)
	ENEMY_ADVANCED_SHIPHEIGHT = (ENEMY_ADVANCED_BASE_SIZE / 2) / math.tan_f32(20 * rl.DEG2RAD)

	//create enemies
	init_enemies()

	camera.target = {ENTITIES[player_id].pos.x + 20, ENTITIES[player_id].pos.y + 20}
	camera.offset = {f32(WIDTH / 2), f32(HEIGHT / 2)}
	camera.rotation = 0
	camera.zoom = 1

	// DEBUG BOOLS
	if DEBUG_DRAW_QUAD_POINT_NUM == false {DEBUG_DRAW_QUAD_POINT_NUM = false}
	if DEBUG_DRAW_QUADS == false {DEBUG_DRAW_QUADS = false}

	//QUADTREE
	init_quadtree(&quadtree)

	for i := 0; i < int(ENTITY_ID); i += 1 {
		//fmt.printf("Inserting entity %i\n", i)
		//fmt.printf("Entity Pos: %v\n", ENTITIES[i].pos)
		insert_entity(
			&quadtree,
			0,
			i32(i),
			Rect {
				min = {ENTITIES[i].pos.x, ENTITIES[i].pos.y},
				max = {
					ENTITIES[i].pos.x + PLAYER_SHIPHEIGHT,
					ENTITIES[i].pos.y + PLAYER_SHIPHEIGHT,
				},
				pos = {ENTITIES[i].pos.x, ENTITIES[i].pos.y},
			},
		)
	}
}

// Checks if two rectangles overlap
rect_overlaps :: proc(a, b: Rect) -> bool {
	return a.min.x < b.max.x && a.max.x > b.min.x && a.min.y < b.max.y && a.max.y > b.min.y
}

compute_child_bounds :: proc(parent_bounds: Rect, index: i32) -> Rect {
	//if xmin =  and xmax = 1250
	//w = 1250 - (-1250) / 2 = 1250 + 1250 / 2 = 1250
	//h = 1250 - (-1250) / 2 = 1250 + 1250 / 2 = 1250
	w := (parent_bounds.max.x - parent_bounds.min.x) / 2
	//fmt.printf("W: %f\n", w)
	h := (parent_bounds.max.y - parent_bounds.min.y) / 2
	//fmt.printf("H: %f\n", h)
	mid := Vec2{parent_bounds.min.x + w, parent_bounds.min.y + h}
	//fmt.printf("Mid: %v\n", mid)

	switch (index) 
	{
	case 0:
		return Rect{min = parent_bounds.min, max = mid}
	case 1:
		return Rect{min = {mid.x, parent_bounds.min.y}, max = {parent_bounds.max.x, mid.y}}
	case 2:
		return Rect{min = {parent_bounds.min.x, mid.y}, max = {mid.x, parent_bounds.max.y}}
	case 3:
		return Rect{min = mid, max = parent_bounds.max}
	}

	fmt.printf("Returning parent bounds\n")
	return parent_bounds
}


get_entity_bounds :: proc(e: Entity) -> Rect {

	shipheight: f32

	if _, ok := e.type.(Entity_Player); ok {
		shipheight = PLAYER_SHIPHEIGHT
	} else if _, ok := e.type.(Entity_Enemy); ok {
		shipheight = ENEMY_BASIC_SHIPHEIGHT
	}

	return Rect {
		min = {e.pos.x, e.pos.y},
		max = {e.pos.x + shipheight, e.pos.y + shipheight},
		pos = e.pos,
	}
}

//Tree is the quadtree object
//node index is the current tree node we are trying to insert into
//entity id is the entity we are trying to insert
//entity bounds is the bounds of the entity we are trying to insert
//This function will insert the entity into the quadtree
insert_entity :: proc(tree: ^Quadtree, node_index: i32, entity_id: i32, entity_bounds: Rect) {
	//current node
	node := &tree.nodes[node_index]
	// If already subdivided, pass entity to children

	//fmt.printf("insert_entity(%i) - :%v\n", entity_id, entity_bounds)
	if node.has_children {
		//fmt.printf("Node has children, passing off!\n")
		for i := 0; i < 4; i += 1 {
			child_idx := node.children[i]
			if rect_overlaps(tree.nodes[child_idx].bounds, entity_bounds) {
				/*fmt.printf(
					"Child bound %v \noverlaps with entity %i\n",
					tree.nodes[child_idx].bounds,
					entity_bounds,
				)*/
				insert_entity(tree, child_idx, entity_id, entity_bounds)
				return
			}
		}
	}
	//fmt.printf("No children, checking if there's room\n")

	// Store entity if there's room
	if node.entity_count < MAX_ENTITIES_PER_QUAD {
		//fmt.printf("Inserting entity %i into node %i\n", entity_id, node_index)
		node.entities_id[node.entity_count] = entity_id
		node.entity_count += 1
		return
	}
	//fmt.printf("Node is full, need to subdivide\n")
	// Subdivide if needed
	if !node.has_children {
		//fmt.printf("Subdividing node: %i\n", node_index)
		subdivide(tree, node_index)
	}

	// Reassign entities to children
	i := 0
	//loop over parent entities
	//fmt.printf("Reassigning entities to children\n")
	for i < int(node.entity_count) {
		//check children of parent node for overlap with entity
		/*fmt.printf(
			"Reassigning entity %i, pos: %v:\n",
			node.entities_id[i],
			get_entity_bounds(ENTITIES[node.entities_id[i]]),
		)*/
		for j := 0; j < 4; j += 1 {
			child_idx := node.children[j]
			//fmt.printf("Checking child %i, %v:\n", child_idx, tree.nodes[child_idx].bounds)
			if rect_overlaps(
				tree.nodes[child_idx].bounds,
				get_entity_bounds(ENTITIES[node.entities_id[i]]),
			) {
				//fmt.printf("Child %i has entity %i\n", child_idx, node.entities_id[i])
				insert_entity(
					tree,
					child_idx,
					node.entities_id[i],
					get_entity_bounds(ENTITIES[node.entities_id[i]]),
				)
				node.entities_id[i] = node.entities_id[node.entity_count - 1] // Remove entity from parent
				node.entity_count -= 1
				i -= 1
				break
			} else {
				//fmt.printf("Child %i does not have entity %i\n", child_idx, node.entities_id[i])
			}
		}
		i += 1
	}
	// Insert the new entity
	insert_entity(tree, node_index, entity_id, entity_bounds)
}

subdivide :: proc(tree: ^Quadtree, node_index: i32) {
	if tree.node_count + 4 >= MAX_NODES {
		fmt.printf("Subdivide - max nodes reached\n")
		return // Prevent overflow
	}

	node := &tree.nodes[node_index]
	for i := 0; i < 4; i += 1 {
		child_idx := tree.node_count
		tree.node_count += 1
		tree.nodes[child_idx] = QuadtreeNode {
			bounds       = compute_child_bounds(node.bounds, i32(i)),
			entity_count = 0,
			has_children = false,
			parent       = node_index,
		}
		//fmt.printf("Child %i bounds: %v\n", i, tree.nodes[child_idx].bounds)

		node.children[i] = child_idx
	}

	node.has_children = true
}

// Finds the index of the node containing the entity with the given ID
find_entity_quad :: proc(id: i32) -> i32 {
	for i := 0; i < int(quadtree.node_count); i += 1 {
		node := &quadtree.nodes[i]
		for j := 0; j < int(node.entity_count); j += 1 {
			if node.entities_id[j] == id {
				return i32(i)
			}
		}
	}
	return -1
}

query_quadtree :: proc(
	tree: ^Quadtree,
	node_index: i32,
	query_bounds: Rect,
	result: ^[MAX_ENTITIES_PER_QUAD]i32,
	result_count: ^i32,
) {
	node := &tree.nodes[node_index]

	if !rect_overlaps(node.bounds, query_bounds) {
		return
	}

	// Add entities in the current node
	for i := 0; i < int(node.entity_count); i += 1 {
		result[result_count^] = node.entities_id[i]
		result_count^ += 1
	}

	// Recursively check children
	if node.has_children {
		for i := 0; i < 4; i += 1 {
			query_quadtree(tree, node.children[i], query_bounds, result, result_count)
		}
	}
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
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 960, WINDOW_NAME)
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
		//fmt.printf("Current state: %s\n", currentState)
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

	//camera
	camera.target = {ENTITIES[player_id].pos.x + 20, ENTITIES[player_id].pos.y + 20}
	camera.zoom += rl.GetMouseWheelMove() * 0.05
	if camera.zoom > 3 {camera.zoom = 3} else if camera.zoom < 0.25 {camera.zoom = 0.25}

	//Set font size based on zoom level
	if camera.zoom >= 0.25 && camera.zoom <= 0.3 {
		ZOOM_FONT = 40
	} else if camera.zoom > 0.3 && camera.zoom <= 0.5 {
		ZOOM_FONT = 35
	} else if camera.zoom >= 0.6 && camera.zoom <= 1 {
		ZOOM_FONT = 25
	} else if camera.zoom > 1 && camera.zoom <= 2 {
		ZOOM_FONT = 15
	} else if camera.zoom > 2 && camera.zoom <= 3 {
		ZOOM_FONT = 10
	}

	camera_width = f32(rl.GetScreenWidth()) / camera.zoom
	camera_height = f32(rl.GetScreenHeight()) / camera.zoom
	camera_min = {camera.target.x - camera_width / 2, camera.target.y - camera_width / 2}
	camera_max = {camera.target.x + camera_width / 2, camera.target.y + camera_width / 2}
	camera_rect := Rect {
		min = {camera_min.x, camera_min.y},
		max = {camera_max.x, camera_max.y},
		pos = camera.target,
	}

	if !PAUSE {
		//update entities
		LOCK_ENTITIES = true
		for &e in ENTITIES {
			switch &t in e.type {
			case Entity_Player:
				{
					//speed
					v1, v2, v3 := get_triangle_pos(e.pos, e.rotation)

					e.speed.x = math.sin_f32(e.rotation * rl.DEG2RAD) * PLAYER_SPEED
					e.speed.y = math.cos_f32(e.rotation * rl.DEG2RAD) * PLAYER_SPEED

					//movement
					e.pos.x += (e.speed.x * e.acceleration)
					e.pos.y -= (e.speed.y * e.acceleration)
				}
			case Entity_Enemy:
				{
					//speed
					v1, v2, v3 := get_triangle_pos(e.pos, e.rotation)

					e.speed.x = math.sin_f32(e.rotation * rl.DEG2RAD) * PLAYER_SPEED
					e.speed.y = math.cos_f32(e.rotation * rl.DEG2RAD) * PLAYER_SPEED

					//movement
					e.pos.x += (e.speed.x * e.acceleration)
					e.pos.y -= (e.speed.y * e.acceleration)
				}
			case Entity_Projectile:
				{
					fmt.printf("Projectile id %i\n", e.id)
					e.speed.x = math.sin_f32(e.rotation * rl.DEG2RAD) * PLAYER_SPEED
					e.speed.y = math.cos_f32(e.rotation * rl.DEG2RAD) * PLAYER_SPEED

					//movement
					e.pos.x += (e.speed.x * e.acceleration)
					e.pos.y -= (e.speed.y * e.acceleration)
					fmt.printf("Projectile type %v\n", e.type)
					switch &p in t.type 
					{
					case Projectile_Rocket:
						{
							fmt.printf("Projectile rocket id %i\n", e.id)
							if t.active {
								p.lifetime -= rl.GetFrameTime()
								if p.lifetime <= 0 {
									t.active = false
								}
							} else {
								fmt.printf("Projectile rocket id %i inactive\n", e.id)
								//delete the entity
								//delete_entity(e.id)
							}
						}
					case Projectile_Laser:
						{
							fmt.printf("Projectile laser id %i\n", e.id)
							if t.active {
								p.lifetime -= rl.GetFrameTime()
								if p.lifetime <= 0 {
									t.active = false
								}
							} else {
								//delete the entity
								delete_entity(e.id)
							}
						}
					case Projectile_Bullet:
						{
							fmt.printf("Projectile bullet id %i\n", e.id)
							if t.active {
								p.lifetime -= rl.GetFrameTime()
								if p.lifetime <= 0 {
									t.active = false
								}
							} else {
								//delete the entity
								delete_entity(e.id)
							}
						}
					}
				}
			case Entity_Asteroid:
				{
					//speed
					v1, v2, v3 := get_triangle_pos(e.pos, e.rotation)

					e.speed.x = math.sin_f32(e.rotation * rl.DEG2RAD) * PLAYER_SPEED
					e.speed.y = math.cos_f32(e.rotation * rl.DEG2RAD) * PLAYER_SPEED

					//movement
					e.pos.x += (e.speed.x * e.acceleration)
					e.pos.y -= (e.speed.y * e.acceleration)
				}
			}


			//Trail particles
			/*if e.trail.active {
				fmt.printf("Trail active\n")
				//set the current particle to the ship position

				e.trail.particles[e.trail.current_partcicle_idx].active = true
				e.trail.particles[e.trail.current_partcicle_idx].pos = e.trail.pos
				//for every particle in the trail
				for &p in e.trail.particles {
					//if particle is active, update its lifetime
					if p.active {
						fmt.printf("Particle active\n")
						fmt.printf("Particle lifetime: %f\n", p.lifetime)
						p.lifetime -= rl.GetFrameTime()
						fmt.printf("Particle lifetime updated: %f\n", p.lifetime)
						if p.lifetime <= 0 {
							p.active = false
						}
					}
				}
			}

			e.trail.current_partcicle_idx += 1
			if e.trail.current_partcicle_idx >= len(e.trail.particles) {
				e.trail.current_partcicle_idx = 0
			}*/
		}
		LOCK_ENTITIES = false

		//reset the quadrant
		for &q in level.quadrants {
			q.player_inside = false
			q.enemy_inside = false
		}

		for &q in level.quadrants {
			for &e in ENTITIES {
				if is_inside_quad(e, q) {
					if _, ok := e.type.(Entity_Player); ok {
						q.player_inside = true
					} else if _, ok := e.type.(Entity_Enemy); ok {
						q.enemy_inside = true
					}
				}
			}
		}

		//update quadtree
		reset_quadtree()
		//fmt.printf("Reset quadtree\n")
		for i := 0; i < int(TOTAL_ENTITIES); i += 1 {
			//fmt.printf("Entity %i pos %v:\n", i, ENTITIES[i].pos)
			insert_entity(
				&quadtree,
				0,
				i32(i),
				Rect {
					min = {ENTITIES[i].pos.x, ENTITIES[i].pos.y},
					max = {
						ENTITIES[i].pos.x + PLAYER_SHIPHEIGHT,
						ENTITIES[i].pos.y + PLAYER_SHIPHEIGHT,
					},
					pos = ENTITIES[i].pos,
				},
			)
		}
	}
}

update :: proc() {

	/*result: [MAX_ENTITIES_PER_QUAD]i32
	result_count: i32 = 0
	query_quadtree(&quadtree, 0, Rect{min = {0, 0}, max = {50, 50}}, &result, &result_count)
	*/
	if rl.IsWindowResized() {
		WIDTH = rl.GetScreenWidth()
		HEIGHT = rl.GetScreenHeight()
		camera.offset = {f32(WIDTH / 2), f32(HEIGHT / 2)}
		camera.target = {ENTITIES[player_id].pos.x + 20, ENTITIES[player_id].pos.y + 20}
	}
	#partial switch (currentState) {
	case .GAMEPLAY:
		update_gameplay()
		handle_collisions()
	//Make sure we can pause/unpause
	}
}

//Handles the ships moving to opposite edge
handle_collisions :: proc() {
	// Collision logic: player vs walls

	for &e, idx in ENTITIES {
		if _, ok := e.type.(Entity_Player); ok {
			//fmt.printf("PLAYER ENTITY HANDLE COLLSION\n")
			//If player has collided with the right wall
			if e.pos.x > ((LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2) - (PLAYER_SHIPHEIGHT) {
				e.pos.x = 0 - ((LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2) + PLAYER_SHIPHEIGHT
			} else if e.pos.x < (-(LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2) + PLAYER_SHIPHEIGHT {
				e.pos.x = 0 + ((LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2) - PLAYER_SHIPHEIGHT
			}

			if e.pos.y > ((LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2) - PLAYER_SHIPHEIGHT {
				e.pos.y = 0 - ((LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2) + PLAYER_SHIPHEIGHT
			} else if e.pos.y < (-(LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2) + PLAYER_SHIPHEIGHT {
				e.pos.y = 0 + ((LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2) - PLAYER_SHIPHEIGHT
			}

		} else if _, ok := e.type.(Entity_Enemy); ok {
			//fmt.printf("ENEMY ENTITY HANDLE COLLISION\n")
			if e.pos.x > ((LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2) - (PLAYER_SHIPHEIGHT) {
				e.pos.x = 0 - ((LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2) + PLAYER_SHIPHEIGHT
			} else if e.pos.x < (-(LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2) + PLAYER_SHIPHEIGHT {
				e.pos.x = 0 + ((LEVEL_NUM_QUAD_W * LEVEL_QUAD_SIZE) / 2) - PLAYER_SHIPHEIGHT
			}

			if e.pos.y > ((LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2) - PLAYER_SHIPHEIGHT {
				e.pos.y = 0 - ((LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2) + PLAYER_SHIPHEIGHT
			} else if e.pos.y < (-(LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2) + PLAYER_SHIPHEIGHT {
				e.pos.y = 0 + ((LEVEL_NUM_QUAD_H * LEVEL_QUAD_SIZE) / 2) - PLAYER_SHIPHEIGHT
			}
		}
	}
}

handle_input_menu :: proc() {

}

handle_input_gameplay :: proc() {

	if rl.IsMouseButtonPressed(.LEFT) {
		mouse_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
		for &e in ENTITIES {
			v1, v2, v3 := get_triangle_pos(e.pos, e.rotation)
			if rl.CheckCollisionPointTriangle(mouse_pos, v1, v2, v3) {
				fmt.printf("Clicked on entity %i\n", e.id)
				e.debug = !e.debug
			}
		}
	}
	if rl.IsKeyPressed(.F3) {
		DEBUG_DRAW_QUADS = !DEBUG_DRAW_QUADS
		DEBUG_DRAW_QUAD_POINT_NUM = !DEBUG_DRAW_QUAD_POINT_NUM
		DEBUG_ENTITIES = !DEBUG_ENTITIES
	}
	if rl.IsKeyPressed(.F11) {
		rl.ToggleFullscreen()

	}

	if rl.IsKeyPressed(.F4) {DISPLAY_QUADTREE = !DISPLAY_QUADTREE}
	if rl.IsKeyPressed(.P) {PAUSE = !PAUSE}
	if rl.IsKeyPressed(.F2) {DEBUG = !DEBUG}

	//rotate left
	if rl.IsKeyDown(.A) {
		if ENTITIES[player_id].rotation == 0 {
			ENTITIES[player_id].rotation = 355
		} else {
			ENTITIES[player_id].rotation -= 5
		}
	}

	//rotate right
	if rl.IsKeyDown(.D) {
		if ENTITIES[player_id].rotation == 360 {
			ENTITIES[player_id].rotation = 5
		} else {
			ENTITIES[player_id].rotation += 5
		}
	}
	if rl.IsKeyDown(.W) {
		// if accel is less than 1 increase by .04
		if (ENTITIES[player_id].acceleration < 1) {
			ENTITIES[player_id].acceleration += 0.04
		}

		//trail logic
		if ENTITIES[player_id].trail.active == false {
			ENTITIES[player_id].trail.active = true
			ENTITIES[player_id].trail.pos = ENTITIES[player_id].pos
			//fmt.printf("Trail active\n")
		}

	} else {
		//deceleration logic
		if (ENTITIES[player_id].acceleration > 0) {
			ENTITIES[player_id].acceleration -= 0.02
		} else if (ENTITIES[player_id].acceleration < 0) {
			ENTITIES[player_id].acceleration = 0
		}
	}
	if rl.IsKeyDown(.S) {
		//slow down slightly faster than above decel logic
		if (ENTITIES[player_id].acceleration > 0) {
			ENTITIES[player_id].acceleration -= 0.04
		} else if (ENTITIES[player_id].acceleration < 0) {
			ENTITIES[player_id].acceleration = 0
		}
	}

	if ENTITIES[player_id].acceleration == 0 {
		//fmt.printf("Trail inactive\n")
		ENTITIES[player_id].trail.active = false
	}

	if rl.IsKeyPressed(.SPACE) {
		fire_missile(player_id)
	}

	if rl.IsKeyPressed(.R) {
		fmt.printf("Resetting quadtree\n")
		reset_quadtree()
	}

	//DEBUG/TESTING
	//create basic enemy
	if rl.IsKeyPressed(.C) {
		fmt.printf("Creating random basic enemy\n")
		create_entity("enemy_basic", get_random_coord())
	}
	//print all entities
	if rl.IsKeyPressed(.L) {
		fmt.printf("Printing Entities\n")
		for i := 0; i < int(ENTITY_ID); i += 1 {
			fmt.printf("Entity ID: %i\n", ENTITIES[i].id)
			fmt.printf("Entity pos: %v\n", ENTITIES[i].pos)
			fmt.printf("Entity speed: %v\n", ENTITIES[i].speed)
			fmt.printf("Entity rotation: %f\n", ENTITIES[i].rotation)
			fmt.printf("Entity type: %v\n", ENTITIES[i].type)
		}
	}
	//delete random non-player entity
	if rl.IsKeyPressed(.K) {
		if ENTITY_ID - 1 > 0 {
			fmt.printf("Deleting random basic enemy\n")
			fmt.printf("ENTITY_ID: %i\n", ENTITY_ID)
			fmt.printf("ENTITY length: %i\n", len(ENTITIES))
			delete_random_enemy_entity()
		} else {
			fmt.printf("No enemies to delete\n")
		}
	}

	//ENEMY
	//enemy acceleration
	if rl.IsKeyDown(.UP) {
		for &e in ENTITIES {
			if _, ok := e.type.(Entity_Enemy); ok {
				e.acceleration += 0.04
			}
		}
	}
	//enemy deceleration
	if rl.IsKeyDown(.DOWN) {
		for &e in ENTITIES {
			if _, ok := e.type.(Entity_Enemy); ok {
				e.acceleration -= 0.04
			}
		}
	}
}

//Handle user input per game state
handle_input :: proc() {

	if rl.IsKeyPressed(.ESCAPE) {
		PAUSE = !PAUSE
	}
	if rl.WindowShouldClose() {
		//GAME_RUNNING = false
	}
	switch (currentState) {
	case .MENU:
		handle_input_menu()
	case .GAMEPLAY:
		handle_input_gameplay()
	case .ENDING:
		if rl.IsKeyPressed(.ENTER) {
			currentState = .GAMEPLAY
		}
	}
}

//Draw the quadtree node boundary
draw_quad_tree_node :: proc(quadTreeNode: QuadtreeNode) {
	rl.DrawText(
		rl.TextFormat("%i", quadTreeNode.entity_count),
		i32(quadTreeNode.bounds.min.x + 15),
		i32(quadTreeNode.bounds.min.y + 15),
		ZOOM_FONT,
		rl.Fade(rl.WHITE, .8),
	)
	rl.DrawText(
		rl.TextFormat("%i", quadTreeNode.parent),
		i32(quadTreeNode.bounds.min.x + 15),
		i32(quadTreeNode.bounds.min.y + 45),
		ZOOM_FONT,
		rl.Fade(rl.WHITE, .8),
	)
	rl.DrawRectangleLines(
		i32(quadTreeNode.bounds.min.x),
		i32(quadTreeNode.bounds.min.y),
		i32(quadTreeNode.bounds.max.x - quadTreeNode.bounds.min.x),
		i32(quadTreeNode.bounds.max.y - quadTreeNode.bounds.min.y),
		rl.SKYBLUE,
	)
}

//Draw the quadtree nodes boundary 
draw_quad_tree :: proc(quadtree: ^Quadtree) {
	for i := 0; i < int(quadtree.node_count); i += 1 {
		if !quadtree.nodes[i].has_children {
			draw_quad_tree_node(quadtree.nodes[i])
		}
	}
}

draw_menu :: proc() {
	rl.DrawText("Menu", WIDTH / 2 - 50, HEIGHT / 2 - 50, 20, rl.RED)
	rl.DrawText("Press ENTER to start", WIDTH / 2 - 100, HEIGHT / 2, 20, rl.RED)
	rl.DrawText("Press ESCAPE to exit", WIDTH / 2 - 100, HEIGHT / 2 + 50, 20, rl.RED)
}

get_triangle_pos :: proc(p: Vec2, r: f32) -> (Vec2, Vec2, Vec2) {
	v1, v2, v3: Vec2
	v1 = Vec2 {
		p.x + math.sin_f32(r * rl.DEG2RAD) * (PLAYER_SHIPHEIGHT),
		p.y - math.cos_f32(r * rl.DEG2RAD) * (PLAYER_SHIPHEIGHT),
	}
	v2 = Vec2 {
		p.x - math.cos_f32(r * rl.DEG2RAD) * (PLAYER_BASE_SIZE / 2),
		p.y - math.sin_f32(r * rl.DEG2RAD) * (PLAYER_BASE_SIZE / 2),
	}
	v3 = Vec2 {
		p.x + math.cos_f32(r * rl.DEG2RAD) * (PLAYER_BASE_SIZE / 2),
		p.y + math.sin_f32(r * rl.DEG2RAD) * (PLAYER_BASE_SIZE / 2),
	}
	return v1, v2, v3
}

//draws an entity based on its properties within ENTITIES
draw_entity :: proc(e: Entity) {
	if DEBUG && DEBUG_ENTITIES {
		//draw debug for entities
		switch t in e.type {
		case Entity_Player:
			v1, v2, v3 := get_triangle_pos(e.pos, e.rotation)
			rl.DrawTriangleLines(v1, v2, v3, rl.RED)
			rl.DrawText(
				rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
				i32(
					e.pos.x +
					(e.pos.x + PLAYER_SHIPHEIGHT - e.pos.x) / 2 -
					f32(
						rl.MeasureText(
							rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
							ZOOM_FONT,
						) /
						2,
					),
				),
				i32(
					e.pos.y +
					(e.pos.y + PLAYER_SHIPHEIGHT - e.pos.y) / 2 -
					f32(
						rl.MeasureText(
							rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
							ZOOM_FONT,
						) /
						2,
					),
				),
				ZOOM_FONT,
				rl.WHITE,
			)
		case Entity_Enemy:
			v1, v2, v3 := get_triangle_pos(e.pos, e.rotation)
			rl.DrawTriangleLines(v1, v2, v3, rl.ORANGE)
			//Debug text for entities
			rl.DrawText(
				rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
				i32(
					e.pos.x +
					(e.pos.x + ENEMY_BASIC_SHIPHEIGHT - e.pos.x) / 2 -
					f32(
						rl.MeasureText(
							rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
							ZOOM_FONT,
						) /
						2,
					),
				),
				i32(
					e.pos.y +
					(e.pos.y + ENEMY_BASIC_SHIPHEIGHT - e.pos.y) / 2 -
					f32(
						rl.MeasureText(
							rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
							ZOOM_FONT,
						) /
						2,
					),
				),
				ZOOM_FONT,
				rl.WHITE,
			)
		case Entity_Asteroid:
		case Entity_Projectile:
		}
	} else {
		switch t in e.type {
		case Entity_Player:
			v1, v2, v3 := get_triangle_pos(e.pos, e.rotation)
			rl.DrawTriangle(v1, v2, v3, e.color)

			//trail
			if e.trail.active {
				//fmt.printf("Drawing trail\n")
				//fmt.printf("Trail pos: %v\n", e.trail.pos)
				//fmt.printf("Trail color: %v\n", e.trail.color)
				//fmt.printf("Trail radius: %f\n", e.trail.radius)
				for p in e.trail.particles {
					if p.active {
						rl.DrawCircle(i32(v2.x), i32(v2.y), e.trail.radius, e.trail.color)
						rl.DrawCircle(i32(v3.x), i32(v3.y), e.trail.radius, e.trail.color)
					}
				}
			}

			//debug text for entities
			if e.debug {
				rl.DrawText(
					rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
					i32(
						e.pos.x +
						(e.pos.x + PLAYER_SHIPHEIGHT - e.pos.x) / 2 -
						f32(
							rl.MeasureText(
								rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
								ZOOM_FONT,
							) /
							2,
						),
					),
					i32(
						e.pos.y +
						(e.pos.y + PLAYER_SHIPHEIGHT - e.pos.y) / 2 -
						f32(
							rl.MeasureText(
								rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
								ZOOM_FONT,
							) /
							2,
						),
					),
					ZOOM_FONT,
					rl.WHITE,
				)
			}

		case Entity_Enemy:
			v1, v2, v3 := get_triangle_pos(e.pos, e.rotation)
			rl.DrawTriangle(v1, v2, v3, e.color)
			if e.debug {
				rl.DrawText(
					rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
					i32(
						e.pos.x +
						(e.pos.x + ENEMY_BASIC_SHIPHEIGHT - e.pos.x) / 2 -
						f32(
							rl.MeasureText(
								rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
								ZOOM_FONT,
							) /
							2,
						),
					),
					i32(
						e.pos.y +
						(e.pos.y + ENEMY_BASIC_SHIPHEIGHT - e.pos.y) / 2 -
						f32(
							rl.MeasureText(
								rl.TextFormat("%i\n%.2f,%.2f", e.id, e.pos.x, e.pos.y),
								ZOOM_FONT,
							) /
							2,
						),
					),
					ZOOM_FONT,
					rl.WHITE,
				)
			}
		case Entity_Asteroid:
		case Entity_Projectile:
			fmt.printf("Drawing projectile\n")
			fmt.printf("Projectile: %v\n", e)
			rl.DrawCircle(i32(e.pos.x), i32(e.pos.y), e.type.(Entity_Projectile).radius, e.color)

		}


	}
}

//TODO - 
//Add tracking for quadtree regions around player
//Debug menu for the game
draw_debug_menu :: proc() {
	textArray: [10]cstring
	textArray[0] = "Debug Menu"
	textArray[1] = rl.TextFormat("\nDebug Entities: %t\n", DEBUG_ENTITIES)
	textArray[2] = rl.TextFormat("Debug Draw Quad: %t\n", DEBUG_DRAW_QUADS)
	textArray[3] = rl.TextFormat("Debug Draw Quad PointNum: %t\n", DEBUG_DRAW_QUAD_POINT_NUM)
	textArray[4] = rl.TextFormat("Debug Draw Quadtree: %t\n", DISPLAY_QUADTREE)
	textArray[5] = rl.TextFormat("FPS: %i\n", rl.GetFPS())
	debug_text := rl.TextFormat(
		"%s%s%s%s%s",
		textArray[1],
		textArray[2],
		textArray[3],
		textArray[4],
		textArray[5],
	)
	length := rl.MeasureText(textArray[0], DEBUG_FONT_SIZE)
	for s in textArray {
		if rl.MeasureText(s, DEBUG_FONT_SIZE) > length {
			length = rl.MeasureText(s, DEBUG_FONT_SIZE)
		}
	}
	DEBUG_WINDOW_WIDTH = length + 20
	if DEBUG_WINDOW_WIDTH < 260 {
		DEBUG_WINDOW_WIDTH = 260
	}
	rl.SetTextLineSpacing(20)
	rl.DrawRectangle(1, 1, DEBUG_WINDOW_WIDTH, HEIGHT - 1, rl.Fade(rl.BLUE, 0.5))
	rl.DrawRectangleLines(0, 0, DEBUG_WINDOW_WIDTH + 1, HEIGHT, rl.Fade(rl.RED, 0.5))
	rl.DrawText(
		textArray[0],
		(DEBUG_WINDOW_WIDTH) / 2 - (rl.MeasureText(textArray[0], DEBUG_FONT_SIZE + 10) / 2),
		10,
		DEBUG_FONT_SIZE + 10,
		rl.WHITE,
	)
	rl.DrawText(debug_text, 5, 50, DEBUG_FONT_SIZE, rl.WHITE)
	rl.DrawText(
		rl.TextFormat(
			"Player Pos (x,y): [%.1f,%.1f]\nPlayer Rotation: %.1f\n",
			ENTITIES[player_id].pos.x,
			ENTITIES[player_id].pos.y,
			ENTITIES[player_id].rotation,
		),
		5,
		HEIGHT - 70,
		DEBUG_FONT_SIZE,
		rl.WHITE,
	)
}

draw_pause_menu :: proc() {
	//draw pause menu
	rl.DrawRectangle(
		i32(camera.target.x - camera_width / 2),
		i32(camera.target.y - camera_height / 2),
		i32(camera_width),
		i32(camera_height),
		rl.Fade(rl.BLUE, 0.5),
	)
	rl.DrawText(
		"PAUSED",
		i32(camera.target.x) - rl.MeasureText("PAUSED", ZOOM_FONT) / 2,
		i32(camera.target.y) - rl.MeasureText("PAUSED", ZOOM_FONT) / 2,
		ZOOM_FONT,
		rl.RED,
	)
}

draw_game :: proc() {
	rl.BeginMode2D(camera)
	//Draw the quad tree if enabled
	if DISPLAY_QUADTREE {draw_quad_tree(&quadtree)}

	//Draw entities if they are within the camera bounds
	for i := 0; i < int(TOTAL_ENTITIES); i += 1 {
		if within_player_camera_range(ENTITIES[i]) {
			draw_entity(ENTITIES[i])
			TOTAL_ENTITIES_RENDERED += 1
		}
	}
	//Draw the level quadrants
	if DEBUG {draw_level_quads()}
	//Draw the pause menu
	if PAUSE {draw_pause_menu()}
	rl.EndMode2D()

	textArray: [10]cstring
	textArray[0] = "DEBUG\n"
	textArray[1] = rl.TextFormat(
		"Entities Rendered: %i/%i\n",
		TOTAL_ENTITIES_RENDERED,
		TOTAL_ENTITIES,
	)
	textArray[2] = rl.TextFormat("Camera Zoom: %.2f\n", camera.zoom)
	textArray[3] = rl.TextFormat("Quadtree Node Count: %i\n", quadtree.node_count)
	//textArray[4] = rl.TextFormat("Debug Draw Quadtree: %t\n", QUADTREE)
	//textArray[5] = rl.TextFormat("FPS: %i\n", rl.GetFPS())
	debug_text := rl.TextFormat("%s%s%s%s", textArray[0], textArray[1], textArray[2], textArray[3])
	rl.SetTextLineSpacing(20)
	rl.DrawText(debug_text, 5, 5, 25, rl.WHITE)
	TOTAL_ENTITIES_RENDERED = 0
}

visible_by_camera :: proc(q: Quad) -> bool {
	//fmt.printf("Camera min: %v\n", camera_min)
	//fmt.printf("Camera max: %v\n", camera_max)
	//fmt.printf("Quad min: %v\n", q.bounds.min)
	//fmt.printf("Quad max: %v\n", q.bounds.max)
	return(
		q.actual_pos.x < camera_max.x ||
		q.actual_pos.x > camera_min.x ||
		q.actual_pos.y < camera_max.y ||
		q.actual_pos.y > camera_min.y \
	)
}

draw_level_quads :: proc() {
	count := 0
	for q in level.quadrants {

		//only draw the quads that are within the camera bounds
		if (visible_by_camera(q)) {
			count += 1
			col := rl.Fade(rl.YELLOW, 0.1)
			if q.player_inside {
				col = rl.GREEN
			} else if q.enemy_inside {
				col = rl.RED
			}
			rl.DrawRectangleLines(
				i32(q.actual_pos.x),
				i32(q.actual_pos.y),
				i32(q.size.x),
				i32(q.size.y),
				col,
			)
			rl.DrawText(
				rl.TextFormat("%i", q.index),
				i32(
					(q.actual_pos.x + (q.size.x / 2)) -
					f32((rl.MeasureText(rl.TextFormat("%i", q.index), DEBUG_LEVEL_QUAD_FONT)) / 2),
				),
				i32(
					(q.actual_pos.y + (q.size.y / 2)) -
					f32((rl.MeasureText(rl.TextFormat("%i", q.index), DEBUG_LEVEL_QUAD_FONT)) / 2),
				),
				DEBUG_LEVEL_QUAD_FONT,
				rl.Fade(rl.WHITE, 0.1),
			)

		}
	}
	rl.BeginMode2D(camera)
	rl.DrawText(
		rl.TextFormat("Quads: %i", count),
		i32(camera_max.x + 100),
		i32(camera_max.y + 50),
		DEBUG_LEVEL_QUAD_FONT,
		rl.Fade(rl.WHITE, .9),
	)
	rl.EndMode2D()
}

draw_credits :: proc() {

}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	switch (currentState) {
	case .MENU:
		draw_menu()
	case .GAMEPLAY:
		draw_game()
		//draw debug window
		if DEBUG {
			draw_debug_menu()
		}

	case .ENDING:
		draw_credits()
	}
	//rl.EndMode2D()
	rl.EndDrawing()
}
