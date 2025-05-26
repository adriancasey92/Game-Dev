/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
	pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g` global
	variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

//import "core:encoding/json"
import "core:fmt"
import "core:math/linalg"
import "core:mem"
//import "core:os"
import "core:strings"
//import b2d "vendor:box2d"
import rl "vendor:raylib"

//Constants
PIXEL_WINDOW_HEIGHT :: 180
GRAVITY :: 500

DEBUG_DRAW: bool
DEBUG_DRAW_COLLIDERS: bool

//ATLAS BUILDER
ATLAS_DATA :: #load("atlas.png")
HIT_SOUND :: #load("../assets/sounds/hit.wav")
LAND_SOUND :: #load("../assets/sounds/land.wav")
WIN_SOUND :: #load("../assets/sounds/win.wav")

//Struct definitions for the atlas
Vec2 :: rl.Vector2
Rect :: rl.Rectangle

//Level strings
//levels := [?]string{"assets/level.sjson", "assets/level2.sjson", "assets/level3.sjson"}

Player :: struct {
	pos:               Vec2,
	rect:              Rect,
	dir:               Direction,
	input:             Vec2,
	can_run:           bool,
	size:              Vec2,
	vel:               Vec2,
	state:             Player_State,
	movement:          Player_Movement,
	orientation:       Player_Orientation,
	last_orientation:  Player_Orientation,
	jumping_direction: Direction,
	wall_climbing:     bool,
	can_wall_climb:    bool,
	air_time:          f32,
	apex:              bool,
	//texture: Atlas_Texture,
	anim:              Animation,
	flip_x:            bool,
	flip_y:            bool,
	feet_collider:     Rect,
	face_collider:     Rect,
	head_collider:     Rect,
	corner_collider:   Rect,
	tongue:            Tongue,
	can_attack:        bool,
}

Tongue :: struct {
	pos:      Vec2,
	length:   f32,
	fired:    bool,
	attached: bool,
}

Level :: struct {
	platforms:   [dynamic]Platform,
	edit_screen: Edit_Screen,
}

Player_State :: enum {
	nil,
	grounded, //on the ground (can be moving)
	not_grounded,
}

Player_Movement :: enum {
	idle,
	walking,
	climbing_side,
	climbing_upside_down,
	jumping,
	fall_transition,
	falling,
	running,
	swinging,
	sliding,
}

Player_Orientation :: enum {
	norm,
	rot_left,
	rot_right,
	upside_down,
}

Platform :: struct {
	pos:           Vec2,
	pos_rect:      Rect,
	size_vec2:     Vec2,
	texture_rect:  Rect,
	rotation:      f32,
	friction_face: Direction,
	corners:       [4]Rect,
}

Direction :: enum {
	nil,
	left,
	right,
	up,
	down,
}

Game_State :: enum {
	intro,
	play,
	edit,
	pause,
	mainMenu,
}

Edit_Screen :: struct {
	menu:          Menu,
	selection_idx: i32,
}

Menu :: struct {
	size:  Vec2,
	pos:   Vec2,
	nodes: [dynamic]Edit_Platforms,
}

Edit_Platforms :: struct {
	rect:      Rect,
	size:      Vec2,
	pos:       Vec2,
	mouseOver: bool,
}

Game_Memory :: struct {
	//Game state
	state:            Game_State,
	current_level:    int,
	won:              bool,

	//Editor
	in_menu:          bool,
	editing:          bool,
	finished:         bool,
	time_accumulator: f32,

	//Resources
	atlas:            rl.Texture2D,
	font:             rl.Font,
	hit_sound:        rl.Sound,
	land_sound:       rl.Sound,
	win_sound:        rl.Sound,

	//Entities
	player:           Player,

	//Globals
	some_number:      int,
	run:              bool,
	won_at:           f64,
}

running_multiplier: f32
sliding_speed: f32

edit_tex: i32
atlas: rl.Texture2D
hit_sound: rl.Sound
land_sound: rl.Sound
win_sound: rl.Sound
level: Level
g: ^Game_Memory
font: rl.Font

dt: f32
real_dt: f32

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {zoom = h / PIXEL_WINDOW_HEIGHT, target = g.player.pos, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

delete_current_level :: proc() {
	//TODO
	//fmt.printf("TODO - DELETE_CURRENT_LEVEL()\nDeleting current level\n")
}

resetPlayer :: proc() {
	//fmt.printf("RESETTING PLAYER\n")
	g.player.anim = animation_create(.Frog_Idle)
	g.player.pos.x = 0
	g.player.pos.y = 0
	g.player.vel.x = 0
	g.player.vel.y = 0
	g.player.state = .grounded
	g.player.movement = .idle
}

//TODO - Implement this function to load the level data from a file
load_level :: proc(level_idx: int) -> bool {
	fmt.print("TODO - LOAD_LEVEL\nLoading level %i\n", level_idx)
	delete_current_level()

	/*level, level_ok := load_level_data(level_idx)

	if !level_ok {
		return false
	}

	g_mem.current_level = level_idx
	color1_loc := rl.GetShaderLocation(g_mem.ground_shader, "groundColor1")
	color2_loc := rl.GetShaderLocation(g_mem.ground_shader, "groundColor2")
	color3_loc := rl.GetShaderLocation(g_mem.ground_shader, "groundColor3")

	c1 := Vec3{0.44, 0.69, 0.3}
	c2 := Vec3{0.2, 0.37, 0.15}
	c3 := Vec3{0.3, 0.15, 0.13}

	if level_idx == 1 {
		c1 = {0.5, 0.49, 0.2}
		c2 = {0.77, 0.4, 0.15}
		c3 = {0.15, 0.3, 0.3}
	}

	if level_idx == 2 {
		c1 = {0.7, 0.3, 0.3}
		c2 = {0.4, 0.4, 0.5}
		c3 = {0.2, 0.1, 0.2}
	}

	rl.SetShaderValue(g_mem.ground_shader, color1_loc, &c1, .VEC3)
	rl.SetShaderValue(g_mem.ground_shader, color2_loc, &c2, .VEC3)
	rl.SetShaderValue(g_mem.ground_shader, color3_loc, &c3, .VEC3)

	world_def := b2.DefaultWorldDef()
	world_def.gravity = GRAVITY
	world_def.enableContinous = true
	g_mem.physics_world = b2.CreateWorld(world_def)

	g_mem.walls = {}
	g_mem.long_cat_spawns = 0
	for w in level.walls {
		make_wall(w.rect, w.rot)
	}

	g_mem.tuna = level.tuna_pos
	g_mem.starting_pos = level.starting_pos
	g_mem.rc = round_cat_make(g_mem.starting_pos)
	g_mem.lc.state = .Not_Spawned*/
	return true
}

/*SHADERS_DIR :: "../shaders"

BACKGROUND_SHADER_DATA :: #load(SHADERS_DIR + "/bg_shader.glsl")
GROUND_SHADER_DATA :: #load(SHADERS_DIR + "/ground_shader.glsl")
GROUND_SHADER_VS_DATA :: #load(SHADERS_DIR + "/ground_shader_vs.glsl")
*/
temp_cstring :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

// This returns a position offset by the width of the object to center the drawing
// of the object relative to the poisition given. 
centered_pos_from_offset :: proc(pos: Vec2, size: Vec2) -> Vec2 {
	return {pos.x - (size.x / 2), pos.y}
}

//returns center pos of player. 
player_center :: proc() -> Vec2 {
	dest := g.player.pos
	switch (g.player.orientation) 
	{
	case .norm:
		dest.y -= g.player.rect.height / 2
	case .rot_left:
		dest.x -= g.player.rect.width / 2
	case .rot_right:
		dest.x += g.player.rect.height / 2
	case .upside_down:
		dest.y += g.player.rect.height / 2
	}

	return dest
}

//Main logic update loop
update :: proc() {

	//local variables
	dt = rl.GetFrameTime()
	real_dt = dt


	//Borderless window toggle
	if rl.IsKeyPressed(.ENTER) && rl.IsKeyDown(.LEFT_ALT) {
		rl.ToggleBorderlessWindowed()
	}

	if rl.IsKeyPressed(.F4) {
		DEBUG_DRAW = !DEBUG_DRAW
	}
	if rl.IsKeyPressed(.C) {
		DEBUG_DRAW_COLLIDERS = !DEBUG_DRAW_COLLIDERS
	}

	//Pause game 
	//unloads level, 
	if rl.IsKeyPressed(.ESCAPE) {
		//delete_current_level()
		g.in_menu = !g.in_menu
		g.finished = false
		g.won = false
		return
	}
	//finished?
	if g.finished {return}
	if g.won {
		dt = 0
		if rl.IsMouseButtonPressed(.LEFT) && rl.GetTime() > g.won_at + 0.5 {
			g.won = false
			rl.PlaySound(g.win_sound)
			return
		}
	}
	if !g.in_menu && rl.IsKeyPressed(.F2) {
		if g.editing {
			/*level := Level {
				walls        = make([]Level_Wall, len(g.walls), context.temp_allocator),
				starting_pos = g.starting_pos,
			}*/
			/*for w, i in g.walls {
				level.walls[i].rect = w.rect
				level.walls[i].rot = w.rot
			}*/

			//save_level_data(g.current_level, level)
		}
		g.editing = !g.editing
	}
	//Todo - editor update
	if g.editing {
		//fmt.printf("TODO - Editor update\n")
		//editor_update()
	}
	//Main menu
	if g.in_menu {
		//fmt.printf("TODO - Menu\n")
		if rl.IsKeyPressed(.ESCAPE) {
			g.in_menu = false

		}
		return
	}
	//PHYSICS
	g.time_accumulator += dt
	PHYSICS_STEP :: 1 / 60.0
	/*for g.time_accumulator >= PHYSICS_STEP {
		//do physics step
		//fmt.printf("TODO - Physics step\n")
		g.time_accumulator -= PHYSICS_STEP
		//physics_update()
	}*/


	//Update player+entities

	update_player(dt)
	g.some_number += 1
}

//Does all input handling and collision/position/animation updating
update_player :: proc(dt: f32) {
	g.player.input = {}
	//wall climbing stuff - turns off gravity if we are climbing/upside down
	if !g.player.wall_climbing {g.player.vel.y += GRAVITY * dt} else {g.player.vel.y += 0 * dt}

	//old_pos := g.player.pos
	if g.player.state != .grounded {
		g.player.air_time += dt
		if g.player.air_time > .75 {
			if g.player.movement != .falling {
				g.player.movement = .falling
				g.player.anim = animation_create(.Frog_Fall)
			}
		}
	} else {
		g.player.air_time = 0
	}

	//Checking if player is able to run
	if g.player.can_run {
		g.player.pos += (g.player.vel * running_multiplier) * dt
	} else {
		g.player.pos += (g.player.vel * dt)
	}

	//Reset player position and states/actions
	if rl.IsKeyPressed(.R) {
		resetPlayer()
	}

	//Hold onto walls?
	if rl.IsKeyDown(.LEFT_SHIFT) {
		g.player.can_wall_climb = true
	} else {
		g.player.can_wall_climb = false
	}

	//Movement - depends on orientation
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		switch (g.player.orientation) 
		{
		case .norm:
			if g.player.last_orientation == .rot_left {
				g.player.input.x += 1
				if g.player.dir != .right {g.player.dir = .right}
			} else {
				g.player.input.x -= 1
				if g.player.dir != .left {g.player.dir = .left}
			}
			if g.player.movement != .walking && g.player.state == .grounded {
				g.player.movement = .walking
				g.player.anim = animation_create(.Frog_Move)
			}
		//hanging onto right side of wall/platform
		case .rot_left:
			//fix direction change when going from upside down to rotated (left/right is reversed)
			if g.player.last_orientation == .upside_down {
				g.player.input.y -= 1
				if g.player.dir != .right {g.player.dir = .right}
			} else {
				g.player.input.y += 1
				if g.player.dir != .left {g.player.dir = .left}
			}
		case .rot_right:
			g.player.input.y -= 1
			if g.player.dir != .left {g.player.dir = .left}
		//left.right is reversed here
		case .upside_down:
			if g.player.last_orientation == .rot_left {
				g.player.input.x += 1
				if g.player.dir != .left {g.player.dir = .left}
			} else {
				g.player.input.x -= 1
				if g.player.dir != .right {g.player.dir = .right}
			}
		}
	}

	//fixes issue where player cannot move left after moving around a platform
	//from the left side to upside down. 
	if rl.IsKeyReleased(.LEFT) || rl.IsKeyReleased(.A) {
		g.player.last_orientation = g.player.orientation
	}

	//right
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		switch (g.player.orientation) 
		{
		case .norm:
			if g.player.last_orientation == .rot_right {
				g.player.input.x -= 1
				if g.player.dir != .left {g.player.dir = .left}
			} else {
				g.player.input.x += 1
				if g.player.dir != .right {g.player.dir = .right}
			}
			if g.player.movement != .walking && g.player.state == .grounded {
				g.player.movement = .walking
				g.player.anim = animation_create(.Frog_Move)
			}
		case .rot_left:
			g.player.input.y -= 1
			if g.player.dir != .right {g.player.dir = .right}
			if g.player.movement != .climbing_side && g.player.state == .grounded {
				g.player.movement = .climbing_side
				g.player.anim = animation_create(.Frog_Move)
			}
		case .rot_right:
			if g.player.last_orientation == .upside_down {
				g.player.input.y -= 1
				if g.player.dir != .left {g.player.dir = .left}
			} else {
				g.player.input.y += 1
				if g.player.dir != .right {g.player.dir = .right}
			}
			if g.player.movement != .climbing_side && g.player.state == .grounded {
				g.player.movement = .climbing_side
				g.player.anim = animation_create(.Frog_Climb)
			}
		case .upside_down:
			if g.player.last_orientation == .rot_right {g.player.input.x -= 1
				if g.player.dir != .right {g.player.dir = .right}
			} else {
				g.player.input.x += 1
				if g.player.dir != .left {g.player.dir = .left}
			}
		}
	}

	if rl.IsKeyReleased(.RIGHT) || rl.IsKeyReleased(.D) {
		g.player.last_orientation = g.player.orientation
	}

	//Jumping
	if rl.IsKeyPressed(.SPACE) || rl.IsKeyDown(.W) {
		if g.player.orientation != .upside_down {
			if g.player.state == .grounded {
				//fmt.printf("Jumping\n")
				g.player.input.y = -1
				g.player.vel.y = -150
				g.player.state = .not_grounded
				g.player.movement = .jumping
				g.player.anim = animation_create(.Frog_Jump)
				//rl.PlaySound(g.land_sound)
			}
		}
	}

	//Tongue attack?	
	if rl.IsMouseButtonPressed(.LEFT) {
		if g.player.can_attack {
			pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), game_camera())
			player_attack(pos)
			//if we click to our right, turn right
			if g.player.dir == .left && pos.x > g.player.pos.x {
				g.player.dir = .right
			} else if g.player.dir == .right && pos.x < g.player.pos.x {
				g.player.dir = .left
			}
		}
	}


	//idle check - dependent on rotation
	if g.player.orientation == .norm {
		if g.player.input.x == 0 && g.player.state == .grounded {
			//fmt.printf("Player is idle\n")
			if g.player.movement != .idle {
				g.player.movement = .idle
				g.player.anim = animation_create(.Frog_Idle)
			}
		}
	} else {
		//if rotated and not climbing
		if (g.player.orientation == .rot_left || g.player.orientation == .rot_right) &&
		   g.player.input.y == 0 {
			if g.player.movement != .climbing_side {
				g.player.movement = .climbing_side
				g.player.anim = animation_create(.Frog_Climb)
			}
		} else if g.player.orientation == .upside_down {

		}

		/*if g.player.input.y == 0 && g.player.state == .grounded {
			if g.player.movement != .idle {
				g.player.movement = .idle
				g.player.anim = animation_create(.Frog_Idle)
			}
		}*/
	}
	g.player.input = linalg.normalize0(g.player.input)
	g.player.pos += g.player.input * dt * 75

	//Check if player is grounded using colliders with platforms
	//collider update - based on orientation
	//rotate_player rotates all colliders etc.
	has_collided := false
	update_player_colliders()
	if g.player.orientation != .norm {
		rotate_player()
	} else {
		//facing left
		if g.player.dir == .left {
			g.player.head_collider = {
				g.player.pos.x - (g.player.rect.width / 2) + 2,
				g.player.rect.y,
				4,
				1,
			}
			g.player.feet_collider = {g.player.pos.x, g.player.pos.y, g.player.rect.width / 2, 1}
			g.player.face_collider = {
				g.player.pos.x - (g.player.rect.width / 2),
				g.player.pos.y - (g.player.rect.height * .75),
				1,
				4,
			}
			g.player.corner_collider = {g.player.pos.x + 4, g.player.pos.y, 1, 1}

			//facing right
		} else if g.player.dir == .right {
			g.player.head_collider = {g.player.pos.x, g.player.rect.y, 4, 1}
			g.player.feet_collider = {
				g.player.rect.x + 1,
				g.player.pos.y,
				g.player.rect.width / 2,
				1,
			}
			g.player.face_collider = {
				g.player.rect.x + g.player.rect.width - 1,
				g.player.pos.y - (g.player.rect.height * .75),
				1,
				4,
			}
			g.player.corner_collider = {g.player.pos.x - 4, g.player.pos.y, 1, 1}
		}
	}

	//checking if we have collided with feet collider - if we aren't moving we are idle. 
	for platform in level.platforms {
		//feet collider
		if rl.CheckCollisionRecs(g.player.feet_collider, platform.pos_rect) {
			g.player.state = .grounded
			g.player.vel.y = 0
			g.player.pos.y = platform.pos_rect.y - g.player.size.y - 1

			if g.player.movement != .idle {
				if g.player.input.x == 0 {
					g.player.movement = .idle
					g.player.anim = animation_create(.Frog_Idle)
				}
			}
			has_collided = true
		}
	}

	//if we have not collided with any platforms, we are not grounded
	if !has_collided && !g.player.wall_climbing {
		if g.player.movement != .jumping {
			g.player.state = .not_grounded

			//If player walked off a platform, we want to delay the falling animation
			if g.player.movement == .walking {
				//fall transition
				g.player.movement = .fall_transition
			} else {
				if g.player.vel.y > 0 {
					if g.player.movement != .falling {
						g.player.movement = .falling
						g.player.anim = animation_create(.Frog_Fall)
					}
				} else if g.player.vel.y < 0 {
					if g.player.movement != .jumping {
						//fmt.printf("Jumping\n")
						g.player.movement = .jumping
						g.player.anim = animation_create(.Frog_Jump)
					}
				}
			}
		}
	}

	//corner collision and wall walking/climbing detection
	for p in level.platforms {
		//check if player is colliding with the corner of a platform
		for c, idx in p.corners {
			if rl.CheckCollisionRecs(c, g.player.corner_collider) &&
			   g.player.movement != .jumping {
				// Switch based on player orientation is easiest way to seperate logic
				switch (g.player.orientation) {
				//Player is oriented normally
				case .norm:
					//Player has leftshift down to enable wall climbing
					if g.player.can_wall_climb {
						//if player is facing left and collides with left corner of a platform
						if idx == 0 && g.player.dir == .left {
							g.player.last_orientation = .norm
							g.player.last_orientation = .norm
							g.player.orientation = .rot_left
							g.player.wall_climbing = true
							g.player.pos.x = c.x
							g.player.pos.y = c.y + c.height + 2
							//if player is facing right and collides with right corner of a platform
						} else if idx == 1 && g.player.dir == .right {
							g.player.last_orientation = .norm
							g.player.orientation = .rot_right
							g.player.wall_climbing = true
							g.player.pos.x = c.x + c.width / 2
							g.player.pos.y = c.y + c.height + 2
						}
					}
				case .rot_left:
					if idx == 0 && g.player.dir == .right {
						g.player.last_orientation = .rot_left
						g.player.orientation = .norm
						g.player.wall_climbing = false
						g.player.pos.x = c.x + c.width
						g.player.pos.y = c.y
					} else if idx == 2 && g.player.dir == .left {
						g.player.last_orientation = .rot_left
						g.player.orientation = .upside_down
						g.player.wall_climbing = true
						g.player.pos.x = p.pos.x + 2
						g.player.pos.y = p.pos.y + p.pos_rect.height
					}
				case .rot_right:
					if idx == 1 && g.player.dir == .left {
						g.player.last_orientation = .rot_right
						g.player.orientation = .norm
						g.player.wall_climbing = false
						g.player.pos.x = c.x
						g.player.pos.y = c.y
					} else if idx == 3 && g.player.dir == .right {
						g.player.last_orientation = .rot_right
						g.player.orientation = .upside_down
						g.player.wall_climbing = true
						g.player.pos.x = c.x
						g.player.pos.y = p.pos_rect.height
					}
				//dir is reversed!
				case .upside_down:
					if idx == 2 && g.player.dir == .right {
						g.player.last_orientation = .upside_down
						g.player.orientation = .rot_left
						g.player.pos.x = c.x
						g.player.pos.y = c.y
					} else if idx == 3 && g.player.dir == .left {
						g.player.last_orientation = .upside_down
						g.player.orientation = .rot_right
						g.player.pos.x = p.pos.x + p.pos_rect.width
						g.player.pos.y = c.y
					}
				}
			}
		}
	}

	update_player_colliders()

	//JUMPING
	/*for p in level.platforms {
		if rl.CheckCollisionRecs(g.player.feet_collider, {p.pos.x, p.pos.y, p.size.x, p.size.y}) &&
		   (g.player.vel.y > 0) {
			g.player.vel.y = 0
			g.player.pos.y = p.pos.y
			g.player.state = .grounded
			g.player.action = .nil
		} else if rl.CheckCollisionRecs(
			   g.player.face_collider,
			   {p.pos.x, p.pos.y, p.size.x, p.size.y},
		   ) &&
		   (g.player.vel.x != 0) {
			if g.player.dir == .left {
				g.player.action = .sliding
				g.player.state = .not_grounded
				/*if level.player.current_anim.name != .sliding {
					level.player.current_anim = level.player.player_slide
				}*/
				if p.friction_face == .right {
					g.player.vel.y = sliding_speed * rl.GetFrameTime()
					g.player.state = .grounded

				}
				g.player.vel.x = 0
				g.player.pos.x = p.pos.x + p.size.x + 5
			} else if g.player.dir == .right {
				g.player.action = .sliding
				g.player.state = .not_grounded
				/*if level.player.current_anim.name != .sliding {
					level.player.current_anim = level.player.player_slide
				}*/
				if p.friction_face == .left {
					g.player.vel.y = sliding_speed * rl.GetFrameTime()
					g.player.state = .grounded
				}
				g.player.vel.x = 0
				g.player.pos.x = p.pos.x - 6
			}
		} else if rl.CheckCollisionRecs(
			   g.player.head_collider,
			   {p.pos.x, p.pos.y, p.size.x, p.size.y},
		   ) &&
		   (g.player.vel.y < 0) {
			//fmt.printf("HEAD COLLISION\n")
			g.player.vel.y = 0
		}
	}*/

	//fmt.printf("Updating player animation %v\n", g.player.anim.atlas_anim)
	animation_update(&g.player.anim, dt)

	if g.player.dir == .left {
		g.player.flip_x = true
	} else {
		g.player.flip_x = false
	}

	if g.player.orientation == .upside_down {

		g.player.flip_y = true
		if g.player.dir == .right {
			g.player.flip_x = true
		} else {
			g.player.flip_x = false
		}
	} else {
		g.player.flip_y = false
	}
}

//player attacks with tongue the direction they click
player_attack :: proc(mp: Vec2) {
	fmt.printf("PLAYER_ATTACK\n")
	//Center of player
	//length of tongue in pixels?
	attack_length := i32(10)

	dest := calc_point(mp, player_center(), attack_length)
	g.player.tongue.pos = dest
	fmt.printf("MP pos: %.2f, %.2f\n", mp.x, mp.y)
	fmt.printf("Tongue pos: %.2f, %.2f\n", dest.x, dest.y)
	g.player.tongue.fired = true
}

//calculates the position based on start and end point and a given length
//P = (1-t)A + tB
//P is the return point
//A and B are given points
// t is the lenght
calc_point :: proc(mp, origin: Vec2, length: i32) -> Vec2 {
	// Calculate direction vector between two points
	dir := Vec2{mp.x - origin.x, mp.y - origin.y}

	// Normalize the direction vector
	length_dir := linalg.length(dir)
	if length_dir == 0 {
		return origin
	}

	dir = dir / length_dir

	// Calculate point at given length along direction
	return Vec2{origin.x + (dir.x * f32(length)), origin.y + (dir.y * f32(length))}
}

//Ideally this will create a rect that is relative to player pos and current animation
//texture size (width and height)
update_player_colliders :: proc() {
	r := animation_atlas_texture(g.player.anim).rect
	p_width, p_height: f32
	switch (g.player.orientation) 
	{
	case .norm:
		p_width = r.width
		p_height = r.height
		g.player.rect = {
			g.player.pos.x - p_width / 2,
			g.player.pos.y - p_height + 1,
			p_width,
			p_height,
		}
	case .rot_left:
		p_width = r.height
		p_height = r.width
		g.player.rect = {
			g.player.pos.x - p_width + 1,
			g.player.pos.y - p_height / 2,
			p_width,
			p_height,
		}
	case .rot_right:
		p_width = r.height
		p_height = r.width
		g.player.rect = {g.player.pos.x, g.player.pos.y - p_height / 2 + 1.5, p_width, p_height}
	case .upside_down:
		p_width = r.width
		p_height = r.height
		g.player.rect = {g.player.pos.x - p_width / 2, g.player.pos.y, p_width, p_height}
	}

}

//Rotates the player and it's colliders based on the rotation direction and facing
rotate_player :: proc() {
	#partial switch (g.player.orientation) 
	{
	case .rot_left:
		g.player.jumping_direction = .left
		if g.player.dir == .left {
			//Left == facing down
			g.player.corner_collider = {g.player.pos.x, g.player.pos.y - 3, 1, 1}
			g.player.feet_collider = {
				g.player.pos.x,
				g.player.pos.y - g.player.rect.height / 2,
				1,
				6,
			}
			g.player.head_collider = {
				g.player.rect.x,
				g.player.rect.y + (g.player.rect.height * .5),
				1,
				4,
			}
			g.player.face_collider = {
				g.player.pos.x - (g.player.rect.width * .75),
				g.player.pos.y + (g.player.rect.height / 2),
				4,
				1,
			}
		} else if g.player.dir == .right {
			//Right = facing up 
			g.player.corner_collider = {g.player.pos.x, g.player.pos.y + 3, 1, 1}
			//g.player.corner_collider = {g.player.pos.x + 4, g.player.pos.y - 2, 4, 4}
			g.player.feet_collider = {
				g.player.rect.x + g.player.rect.width - 1,
				g.player.rect.y + g.player.rect.height / 2,
				1,
				6,
			}
		}

	//hanging on a wall on the left of player
	case .rot_right:
		g.player.jumping_direction = .right
		if g.player.dir == .right {
			//Right = facing down 
			g.player.corner_collider = {g.player.pos.x, g.player.pos.y - 3, 1, 1}
			//g.player.corner_collider = {g.player.pos.x + 4, g.player.pos.y - 2, 4, 4}
			g.player.feet_collider = {
				g.player.pos.x,
				g.player.pos.y - g.player.rect.height / 2,
				1,
				6,
			}
		} else if g.player.dir == .left {
			//Left == facing up
			g.player.corner_collider = {g.player.pos.x, g.player.pos.y + 3, 1, 1}
			g.player.feet_collider = {g.player.pos.x, g.player.pos.y, 1, 6}
		}
	case .upside_down:
		g.player.jumping_direction = .down
		if g.player.dir == .left {
			//Right = facing down 
			g.player.corner_collider = {g.player.pos.x - 3, g.player.pos.y, 1, 1}
			//g.player.corner_collider = {g.player.pos.x + 4, g.player.pos.y - 2, 4, 4}
			g.player.feet_collider = {
				g.player.pos.x - g.player.rect.width / 2,
				g.player.pos.y,
				6,
				1,
			}
		} else if g.player.dir == .right {
			//Left == facing up
			g.player.corner_collider = {g.player.pos.x + 3, g.player.pos.y, 1, 1}
			g.player.feet_collider = {g.player.pos.x, g.player.pos.y, 5, 1}
		}
	}
}

draw_player :: proc(p: Player) {
	// Fetch the texture for the current frame of the animation.

	anim_texture := animation_atlas_texture(p.anim)

	// The region inside atlas.png where this animation frame lives
	atlas_rect := anim_texture.rect

	// The texture has four offset fields: offset_top, right, bottom and left. The offsets records
	// the distance between the pixels in the atlas and the edge of the original document in the
	// image editing software. Since the atlas is tightly packed, any empty pixels are removed.
	// These offsets can be used to correct for that removal.
	//
	// This can be especially obvious in animations where different frames can have different
	// amounts of empty pixels around it. By adding the offsets everything will look OK.
	//
	// Note that when when flip_x is true we need to add the offset_right instead of the offset_left.
	offset := Vec2{anim_texture.offset_left, anim_texture.offset_top}

	// Flip player when walking to the left. This means both flipping the atlas_rect width, but also
	// using the right offset instead of the left one.
	if p.flip_x {
		atlas_rect.width = -atlas_rect.width
		offset.x = anim_texture.offset_right
	}

	if p.flip_y {
		atlas_rect.height = -atlas_rect.height
		offset.y = anim_texture.offset_bottom
	}

	// The dest rectangle tells us where on screen to draw the player.
	dest := Rect {
		p.pos.x + offset.x,
		p.pos.y + offset.y,
		anim_texture.rect.width,
		anim_texture.rect.height,
	}

	rotation: f32
	switch (p.orientation) 
	{
	case .norm:
	case .rot_left:
		rotation = 270
		dest.x += (anim_texture.rect.width * .5) + 2
		dest.y -= (anim_texture.rect.width) + 2
	case .rot_right:
		rotation = 90
		dest.x -= (anim_texture.rect.width) + 2
		dest.y -= (anim_texture.rect.width * .5)
	case .upside_down:
		dest.y += (anim_texture.rect.height) * 2 - 1
	}

	// I want origin of player to be at the feet.
	// Use document_size for origin instead of anim_texture.rect.width (and height), because those
	// may vary from frame to frame due to being tightly packed in atlas.
	origin := Vec2 {
		anim_texture.document_size.x / 2,
		anim_texture.document_size.y - 1, // -1 because there's an outline in the player anim that takes an extra pixel
	}

	// Draw texture. Note how we are drawing using the atlas but choosing a specific region in it
	// using atlas_rect.
	if g.player.tongue.fired {
		rl.DrawLineEx(player_center(), g.player.tongue.pos, 1, rl.PINK)
		//rl.DrawRectangle(i32(g.player.tongue.pos.x), i32(g.player.tongue.pos.y), 1, 1, rl.RED)
	}
	rl.DrawTexturePro(atlas, atlas_rect, dest, origin, rotation, rl.WHITE)

	//DEBUG
	if DEBUG_DRAW {draw_player_debug(p)}
	if DEBUG_DRAW_COLLIDERS {draw_player_colliders(p)}
}

draw_player_debug :: proc(p: Player) {
	font_size := f32(7)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("%.2f, %.2f", p.pos.x, p.pos.y),
		{p.pos.x, p.pos.y + 5},
		4,
		2,
		rl.RED,
	)
	text_pos := rl.GetScreenToWorld2D({0, 0}, game_camera())
	col_2 := rl.MeasureText(rl.TextFormat("Player State: %s", g.player.state), i32(font_size)) + 10
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player State: %s", g.player.state),
		{text_pos.x + 2, text_pos.y + 2},
		font_size,
		.5,
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Pos: %.2f,%.2f", g.player.pos.x, g.player.pos.y),
		{text_pos.x + 2 + f32(col_2), text_pos.y + 2},
		font_size,
		.5,
		rl.RED,
	)
	pad := 1
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Movement: %s", g.player.movement),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Input: %v", g.player.input),
		{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	pad += 6
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Direction: %s", g.player.dir),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Flip_x: %v", g.player.flip_x),
		{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	pad += 6
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Orientation: %s", g.player.orientation),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	pad += 6
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Animation: %v", g.player.anim.atlas_anim),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	pad += 6
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Animation Frame?: %v", g.player.anim.current_frame),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
}

draw_player_colliders :: proc(p: Player) {
	rl.DrawRectangleLines(
		i32(g.player.rect.x),
		i32(g.player.rect.y),
		i32(g.player.rect.width),
		i32(g.player.rect.height),
		rl.BLUE,
	)
	rl.DrawRectangleRec(g.player.feet_collider, rl.YELLOW)
	//rl.DrawRectangleRec(g.player.face_collider, rl.WHITE)
	//rl.DrawRectangleRec(g.player.head_collider, rl.BLACK)
	rl.DrawRectangleLinesEx(g.player.corner_collider, .25, rl.PINK)
	rl.DrawPixelV(g.player.pos, rl.PURPLE)
}

draw_level :: proc() {
	width := rl.GetScreenWidth()
	height := rl.GetScreenHeight()
	//Draw background tiles
	if DEBUG_DRAW {
		for x := -width; x < width; x += 10 {
			rl.DrawLine(x, -height, x, height, rl.WHITE)
			for y := -height; y < height; y += 10 {
				rl.DrawLine(x, y, width, y, rl.WHITE)
			}
		}
	}
	// Draw platforms
	for p in level.platforms {
		rl.DrawTextureRec(g.atlas, p.texture_rect, p.pos, rl.WHITE)
		if DEBUG_DRAW {
			rl.DrawRectangleLinesEx(p.pos_rect, 1, rl.RED)
			//text position
			text := rl.TextFormat("%.2f, %.2f", p.pos.x, p.pos.y)
			text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, 5, 2)
			rl.DrawTextEx(
				rl.GetFontDefault(),
				text,
				{
					p.pos.x + (p.size_vec2.x / 2) - (text_size.x / 2),
					p.pos.y + (p.size_vec2.y / 2) - (text_size.y / 2),
				},
				5,
				2,
				rl.RED,
			)
		}
		if DEBUG_DRAW_COLLIDERS {
			for c in p.corners {
				rl.DrawRectangleLinesEx(c, 1, rl.YELLOW)
			}
		}
	}
	draw_player(g.player)
}

pos_to_rect :: proc(pos: Vec2, size: Vec2) -> Rect {
	return {pos.x, pos.y, size.x, size.y}
}

get_rect_corners :: proc(rect: Rect) -> [4]Rect {
	c: [4]Rect
	size: f32
	size = 2
	//top left, top right, bottom right, bottom left
	//y value is offeset by 1 to ensure player colliders can collide with 
	// the corners
	c[0] = {rect.x - 1, rect.y - 1, size, size}
	c[1] = {rect.x + (rect.width - size) + 1, rect.y - 1, size, size}
	c[2] = {rect.x - 1, rect.y + (rect.height - size) + 1, size, size}
	c[3] = {rect.x + rect.width - size + 1, rect.y + rect.height - size / 2, size, size}

	return c
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.SKYBLUE)
	//Draw using game_camera
	rl.BeginMode2D(game_camera())
	{
		draw_level()
	}
	rl.EndMode2D()
	rl.BeginMode2D(ui_camera())
	rl.EndMode2D()
	rl.EndDrawing()
}

init_window :: proc() {
	fmt.printf("Initializing window\n")
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Forg Game")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.InitAudioDevice()
	rl.SetExitKey(.KEY_NULL)
}

init :: proc() {
	fmt.printf("Initializing game\n")
	g = new(Game_Memory)
	DEBUG_DRAW = false
	//load the raw data into atlas_image
	atlas_image := rl.LoadImageFromMemory(".png", raw_data(ATLAS_DATA), i32(len(ATLAS_DATA)))
	//font = load_atlased_font()

	// Set the shapes drawing texture, this makes rl.DrawRectangleRec etc use the atlas
	rl.SetShapesTexture(atlas, SHAPES_TEXTURE_RECT)
	g^ = Game_Memory {
		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		atlas = rl.LoadTextureFromImage(atlas_image),
		hit_sound = rl.LoadSoundFromWave(
			rl.LoadWaveFromMemory(".wav", raw_data(HIT_SOUND), i32(len(HIT_SOUND))),
		),
		land_sound = rl.LoadSoundFromWave(
			rl.LoadWaveFromMemory(".wav", raw_data(LAND_SOUND), i32(len(LAND_SOUND))),
		),
		win_sound = rl.LoadSoundFromWave(
			rl.LoadWaveFromMemory(".wav", raw_data(WIN_SOUND), i32(len(WIN_SOUND))),
		),
		run = true,
		current_level = 0,
		player = {
			anim = animation_create(.Frog_Idle),
			pos = {0, 0},
			rect = {},
			dir = .left,
			can_run = true,
			can_attack = true,
			size = {},
			vel = {0, 0},
			state = .grounded,
			movement = .idle,
			orientation = .norm,
			apex = false,
			flip_x = false,
			feet_collider = Rect{},
			face_collider = Rect{},
			head_collider = Rect{},
			corner_collider = Rect{},
		},
	}

	edit_tex = 0

	//Sound volume set here
	//rl.SetSoundVolume(g.hit_sound, 0.5)
	//rl.SetSoundVolume(g.land_sound, 0.5)
	//rl.SetSoundVolume(g.win_sound, 0.5)

	rl.UnloadImage(atlas_image)

	num_glyphs := len(atlas_glyphs)
	font_rects := make([]Rect, num_glyphs)
	glyphs := make([]rl.GlyphInfo, num_glyphs)
	for ag, idx in atlas_glyphs {
		font_rects[idx] = ag.rect
		glyphs[idx] = {
			value    = ag.value,
			offsetX  = i32(ag.offset_x),
			offsetY  = i32(ag.offset_y),
			advanceX = i32(ag.advance_x),
		}
	}
	g.font = {
		baseSize     = ATLAS_FONT_SIZE,
		glyphCount   = i32(num_glyphs),
		glyphPadding = 0,
		texture      = g.atlas,
		recs         = raw_data(font_rects),
		glyphs       = raw_data(glyphs),
	}

	// Set up current level
	init_level(g.current_level)
	game_hot_reloaded(g)
}

init_level :: proc(level_num: int) {
	fmt.printf("Initializing level\n")
	// Load level from file
	p := Platform {
		pos          = centered_pos_from_offset({0, 0}, {96, 16}),
		size_vec2    = {96, 16},
		rotation     = 0,
		texture_rect = atlas_textures[.Platform_Large].rect,
	}
	p.pos_rect = pos_to_rect(p.pos, p.size_vec2)
	p.corners = get_rect_corners(p.pos_rect)

	append(&level.platforms, p)

	/*p = {
		pos          = {0, 250},
		size         = {64, 16},
		rotation     = 0,
		texture_rect = atlas_textures[.Platform_Medium].rect,
	}
	p.pos_rect = pos_to_rect(p.pos, p.size)
	append(&level.platforms, p)
	*/
	/*if level, ok := load_level_data(level); ok {
		fmt.printf("Loaded level: %i\n", level)
	} else {

	
	}*/
	/*if level_data, ok := os.read_entire_file("assets/level.json", context.temp_allocator); ok {
		if json.unmarshal(level_data, &level) != nil {
			append(
				&level.platforms,
				Platform {
					pos = {-20, 20},
					size = {96, 16},
					rect = atlas_textures[.Platform_Large].rect,
				},
			)
			append(
				&level.platforms,
				Platform {
					pos = {90, -20},
					size = {64, 16},
					rect = atlas_textures[.Platform_Medium].rect,
				},
			)
		}
	} else {
		fmt.printf("Failed to load level data\n")
		return
	}*/

	//Set up edit screen with -1 as selection index
	/*level.edit_screen = {Menu{}, -1}
	append(
		&level.edit_screen.menu.nodes,
		Edit_Platforms {
			rect = atlas_textures[.Platform_Small].rect,
			size = {16, 32},
			pos = {0, 0},
			mouseOver = false,
		},
	)
	append(
		&level.edit_screen.menu.nodes,
		Edit_Platforms {
			rect = atlas_textures[.Platform_Medium].rect,
			size = {16, 32},
			pos = {0, 0},
			mouseOver = false,
		},
	)
	append(
		&level.edit_screen.menu.nodes,
		Edit_Platforms {
			rect = atlas_textures[.Platform_Large].rect,
			size = {16, 32},
			pos = {0, 0},
			mouseOver = false,
		},
	)*/
}

game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g.run
}

refresh_globals :: proc() {
	fmt.printfln("Refreshing globals")
	reload_global_data()
	atlas = g.atlas
	font = g.font
	/*hit_sound = g.hit_sound
	land_sound = g.land_sound
	win_sound = g.win_sound*/
}

//IS THIS NEEDED?
reload_global_data :: proc() {
	ATLAS_DATA :: #load("atlas.png")
	/*HIT_SOUND :: #load("../assets/sounds/hit.wav")
	LAND_SOUND :: #load("../assets/sounds/land.wav")
	WIN_SOUND :: #load("../assets/sounds/win.wav")*/
	atlas_image := rl.LoadImageFromMemory(".png", raw_data(ATLAS_DATA), i32(len(ATLAS_DATA)))
	/*hit_sound = rl.LoadSoundFromWave(
		rl.LoadWaveFromMemory(".wav", raw_data(HIT_SOUND), i32(len(HIT_SOUND))),
	)
	land_sound = rl.LoadSoundFromWave(
		rl.LoadWaveFromMemory(".wav", raw_data(LAND_SOUND), i32(len(LAND_SOUND))),
	)
	win_sound = rl.LoadSoundFromWave(
		rl.LoadWaveFromMemory(".wav", raw_data(WIN_SOUND), i32(len(WIN_SOUND))),
	)*/
	g.atlas = rl.LoadTextureFromImage(atlas_image)

	rl.UnloadImage(atlas_image)

	edit_tex = 0
}

//Memory management
// This is called when the game is shutting down.
// Delete any dynamic memory here
// and free the memory allocated for game memory.
shutdown :: proc() {
	fmt.printf("Shutting down game\n")

	// delete all dynamic memory containers
	delete(level.platforms)
	delete(level.edit_screen.menu.nodes)

	mem.free(g.font.recs)
	mem.free(g.font.glyphs)
	free(g)
}

//Close window and audo device
shutdown_window :: proc() {
	fmt.printf("Shutting down window\n")
	rl.CloseAudioDevice()
	rl.CloseWindow()
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
