#+feature dynamic-literals
package game

import "core:encoding/json"
import "core:fmt"
//import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:slice"
//import "core:strconv"
import rl "vendor:raylib"

Player_State :: enum {
	nil,
	grounded, //on the ground (can be moving)
	not_grounded,
}

Player_Action :: enum {
	nil,
	jumping,
	falling,
	climbing,
	sliding,
}

Player_Movement :: enum {
	idle,
	walking,
	running,
	swinging,
	sliding,
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
	uid:       u32,
	texture:   rl.Texture,
	size:      Vec2,
	pos:       Vec2,
	mouseOver: bool,
}

Game :: struct {
	window_size: Vec2,
	state:       Game_State,
}

Platform_Type :: enum {
	small,
	medium,
	large,
}

Platform :: struct {
	pos:           Vec2,
	size:          Vec2,
	texture:       rl.Texture,
	rotation:      f32,
	type:          Platform_Type,
	friction_face: Direction,
}

Player :: struct {
	pos:           Vec2,
	dir:           Direction,
	can_run:       bool,
	size:          Vec2,
	vel:           Vec2,
	state:         Player_State,
	action:        Player_Action,
	movement:      Player_Movement,
	apex:          bool,
	anim:          Animation,
	feet_collider: rl.Rectangle,
	face_collider: rl.Rectangle,
	head_collider: rl.Rectangle,
}

Level :: struct {
	platforms:   [dynamic]Platform,
	player:      Player,
	edit_screen: Edit_Screen,
}

running_mult: f32
grounded_timer: f32

/*
player_run_texture: rl.Texture
player_jump_texture: rl.Texture
player_idle_texture: rl.Texture
player_falling_texture: rl.Texture
player_sliding_texture: rl.Texture
platform_texture: [3]rl.Texture*/

sliding_speed: f32
edit_tex: i32
edit_rotation: f32
edit_selected: bool
fontSize: f32
fonts: [8]rl.Font
currentFont_idx: i32
camera :: rl.Camera2D
use_camera: bool
debug_info: bool
PixelWindowHeight :: 180
Gravity :: 500

gs := Game{}
level := Level {
	player = Player{},
}

ATLAS_DATA :: #load("../assets/atlas.png")
Vec2 :: rl.Vector2
Rect :: rl.Rectangle

atlas: rl.Texture2D

main :: proc() {
	//To assess memory leaks
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	//Print out memory leak information
	defer {
		for _, entry in track.allocation_map {
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}

		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}
		mem.tracking_allocator_destroy(&track)
	}

	//INIT WINDOW
	initWindow()
	initGame()
	initLevel()

	for !rl.WindowShouldClose() {
		handle_input()
		update()
		render()
		free_all(context.temp_allocator)
	}

	rl.UnloadTexture(atlas)
	rl.CloseWindow()

	saveLevel()
	delete(level.edit_screen.menu.nodes)
	delete(level.platforms)
}

loadTextures :: proc() {

	/*player_run_texture = rl.LoadTexture("resource/textures/frog1move.png")
	player_jump_texture = rl.LoadTexture("resource/textures/frog1jump.png")
	player_idle_texture = rl.LoadTexture("resource/textures/frog1idle.png")
	player_falling_texture = rl.LoadTexture("resource/textures/frog1falling.png")
	player_sliding_texture = rl.LoadTexture("resource/textures/frog1sliding.png")
	platform_texture[0] = rl.LoadTexture("resource/textures/terrain/platform1.png")
	platform_texture[1] = rl.LoadTexture("resource/textures/terrain/platform2.png")
	platform_texture[2] = rl.LoadTexture("resource/textures/terrain/platform3.png")
*/
}

delete_atlased_font :: proc(font: rl.Font) {
	delete(slice.from_ptr(font.glyphs, int(font.glyphCount)))
	delete(slice.from_ptr(font.recs, int(font.glyphCount)))
}

load_atlased_font :: proc() -> rl.Font {
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

	return {
		baseSize = ATLAS_FONT_SIZE,
		glyphCount = i32(num_glyphs),
		glyphPadding = 0,
		texture = atlas,
		recs = raw_data(font_rects),
		glyphs = raw_data(glyphs),
	}
}

saveLevel :: proc() {
	//Saves file into json
	if level_data, err := json.marshal(level, allocator = context.temp_allocator); err == nil {
		os.write_entire_file("level.json", level_data)
	}
	free_all(context.temp_allocator)
}

initGame :: proc() {

	//Load in atlas
	atlas_image := rl.LoadImageFromMemory(".png", raw_data(ATLAS_DATA), i32(len(ATLAS_DATA)))
	atlas = rl.LoadTextureFromImage(atlas_image)
	rl.UnloadImage(atlas_image)

	//Set player animation
	level.player.anim = animation_create(.Frog_Idle)
	rl.SetShapesTexture(atlas, SHAPES_TEXTURE_RECT)

	//For editor
	edit_tex = 0
}

initWindow :: proc() {
	gs.window_size = {1280, 720}
	use_camera = true
	running_mult = 2
	fontSize = 8

	rl.InitWindow(i32(gs.window_size.x), i32(gs.window_size.y), "Forg Game")
	//Set pos in screen space
	rl.SetWindowPosition(200, 200)
	//Set resizable
	rl.SetWindowState({.WINDOW_RESIZABLE})
	//rl.SetTargetFPS(500)

	//loadTextures()

	//Load fonts
	/*fonts[0] = rl.LoadFont("resource/fonts/pixelplay.png")
	fonts[1] = rl.LoadFont("resource/fonts/alagard.png")
	fonts[2] = rl.LoadFont("resource/fonts/alpha_beta.png")
	fonts[3] = rl.LoadFont("resource/fonts/jupiter_crash.png")
	fonts[4] = rl.LoadFont("resource/fonts/mecha.png")
	fonts[5] = rl.LoadFont("resource/fonts/pixantiqua.png")
	fonts[6] = rl.LoadFont("resource/fonts/romulus.png")
	fonts[7] = rl.LoadFont("resource/fonts/setback.png")*/
	//currentFont_idx = 0
}


cycle_font :: proc() {
	if currentFont_idx == 7 {
		currentFont_idx = 0
	} else {
		currentFont_idx += 1
	}
}

initLevel :: proc() {
	sliding_speed = 1000
	debug_info = false
	initPlayer()
	if level_data, ok := os.read_entire_file("level.json", context.temp_allocator); ok {
		if json.unmarshal(level_data, &level) != nil {
			append(
				&level.platforms,
				Platform{pos = {-20, 20}, size = {96, 16}, texture = platform_texture[0]},
			)
			append(
				&level.platforms,
				Platform{pos = {90, -20}, size = {64, 16}, texture = platform_texture[1]},
			)
		}
	}


	//Create a new menu and set selection index to -1
	level.edit_screen = {Menu{}, -1}

	for t in platform_texture {
		//Appending new node to level.edit_screen.menu.nodes
		fmt.printf("\n\nAPPENDING NEW NODE\n\n")
		append(
			&level.edit_screen.menu.nodes,
			Edit_Platforms {
				uid = t.id,
				texture = t,
				size = {16, 32},
				pos = {0, 0},
				mouseOver = false,
			},
		)
	}
}

resetPlayer :: proc() {
	level.player.pos.x = 0
	level.player.pos.y = 0
	level.player.vel.x = 0
	level.player.vel.y = 0
	level.player.state = .nil
	level.player.movement = .idle
	level.player.action = .nil
}

initPlayer :: proc() {
	level.player.pos = {5, 5}
	level.player.size = {64, 64}
	level.player.movement = .idle
	level.player.action = .nil
	level.player.apex = false
	level.player.dir = .left
}


render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.LIGHTGRAY)

	//rl.DrawRectangleV(level.player.pos, level.player.size, rl.GREEN)
	/*player_run_width := f32(player_run_texture.width)
	player_run_height := f32(player_run_texture.height)*/

	//update sprite
	//update_animation(&level.player.current_anim)

	screen_height := f32(rl.GetScreenHeight())
	camera := rl.Camera2D {
		zoom   = screen_height / PixelWindowHeight,
		offset = {
			f32(rl.GetScreenWidth() / 2),
			(f32(rl.GetScreenHeight() / 2) + f32(rl.GetScreenHeight() / 5)),
		},
		target = level.player.pos,
	}

	if (use_camera) {
		rl.BeginMode2D(camera)
	}

	//FPS draw
	fpsPos := rl.GetScreenToWorld2D({0, 0}, camera)
	rl.DrawTextEx(
		fonts[currentFont_idx],
		rl.TextFormat("FPS: %d", rl.GetFPS()),
		{fpsPos.x + 2, fpsPos.y + 2},
		fontSize,
		1,
		rl.RED,
	)

	//Draw
	if debug_info {
		pad := 0
		rl.DrawTextEx(
			fonts[currentFont_idx],
			rl.TextFormat("Player Action: %s", level.player.action),
			{fpsPos.x + 2, fpsPos.y + 10},
			fontSize,
			.5,
			rl.RED,
		)
		pad += 10
		rl.DrawTextEx(
			fonts[currentFont_idx],
			rl.TextFormat("Player State: %s", level.player.state),
			{fpsPos.x + 2, fpsPos.y + f32(pad) + f32(fontSize)},
			fontSize,
			.5,
			rl.RED,
		)
		rl.DrawRectangleRec(level.player.feet_collider, rl.RED)
		rl.DrawRectangleRec(level.player.face_collider, rl.RED)
		rl.DrawRectangleRec(level.player.head_collider, rl.RED)
		draw_platform_collisions()
	}

	//draw_animation(level.player.current_anim, level.player.pos, level.player.dir)

	for p in level.platforms {
		//rl.DrawTextureEx(p.texture, p.pos, p.rotation, 1, rl.WHITE)
		if p.rotation > 0 {
			rl.DrawTextureEx(p.texture, {p.pos.x + 16, p.pos.y}, p.rotation, 1, rl.WHITE)
		} else if p.rotation == 0 {
			rl.DrawTextureEx(p.texture, p.pos, p.rotation, 1, rl.WHITE)
		} else if p.rotation < 0 {
			rl.DrawTextureEx(
				p.texture,
				{p.pos.x, f32(p.pos.y) + f32(p.texture.width)},
				p.rotation,
				1,
				rl.WHITE,
			)
		}
	}

	//Edit mode
	if gs.state == .edit {
		mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

		msgPos := rl.GetScreenToWorld2D(
			{gs.window_size.x / 2, (gs.window_size.y / 2) - (gs.window_size.y / 3)},
			camera,
		)

		boxPos := rl.GetScreenToWorld2D({8, gs.window_size.y - 136}, camera)
		//Try to draw a box with a texture in it scaled down?
		rl.DrawTextEx(fonts[currentFont_idx], "Editing level!", msgPos, fontSize, 1, rl.RED)

		for i := 0; i < len(level.edit_screen.menu.nodes); i = i + 1 {
			posx := f32(boxPos.x + f32(i * 32))
			posy := f32(boxPos.y)
			rl.DrawRectangleV({posx, posy}, {32, 32}, rl.GRAY)
			rl.DrawTextureEx(
				level.edit_screen.menu.nodes[i].texture,
				{
					posx +
					(32 - (f32(level.edit_screen.menu.nodes[i].texture.width) * f32(.3))) / 2,
					posy +
					(32 - (f32(level.edit_screen.menu.nodes[i].texture.height) * f32(.3))) / 2,
				},
				0,
				.3,
				rl.WHITE,
			)
			//mouseover
			if rl.CheckCollisionPointRec(mp, {posx, posy, 32, 32}) {
				rl.DrawRectangleLinesEx({posx, posy, 32, 32}, 1, rl.YELLOW)
				if rl.IsMouseButtonPressed(.LEFT) {
					level.edit_screen.selection_idx = i32(i)
					edit_tex = level.edit_screen.selection_idx
				}
			} else {
				if level.edit_screen.selection_idx != -1 {
					if edit_rotation > 0 {
						rl.DrawTextureEx(
							platform_texture[edit_tex],
							{mp.x + f32(16), mp.y},
							edit_rotation,
							1,
							rl.WHITE,
						)
					} else if edit_rotation == 0 {
						rl.DrawTextureEx(
							platform_texture[edit_tex],
							mp,
							edit_rotation,
							1,
							rl.WHITE,
						)
					} else if edit_rotation < 0 {
						rl.DrawTextureEx(
							platform_texture[level.edit_screen.selection_idx],
							{mp.x, mp.y + f32(platform_texture[edit_tex].width)},
							edit_rotation,
							1,
							rl.WHITE,
						)
					}
				}
			}
		}

		//scroll through textures
		if rl.GetMouseWheelMove() > 0 {
			if edit_tex == 2 {
				edit_tex = 0
			} else {
				edit_tex += 1
			}
		} else if rl.GetMouseWheelMove() < 0 {
			if edit_tex == 0 {
				edit_tex = 2
			} else {
				edit_tex -= 1
			}
		}


		if rl.IsMouseButtonPressed(.LEFT) {
			//fmt.printf("TEST LEFT BUTTON mp: %f,%f\n", mp.x, mp.y)
			if level.edit_screen.selection_idx != -1 {
				switch (edit_tex) 
				{
				case 0:
					fmt.printf("Rotation %f\n", edit_rotation)
					createLargePlatform(mp, edit_rotation)
				case 1:
					fmt.printf("Rotation %f\n", edit_rotation)
					createMediumPlatform(mp, edit_rotation)
				case 2:
					fmt.printf("Rotation %f\n", edit_rotation)
					createSmallPlatform(mp, edit_rotation)
				}
			} else {

			}
		}

		if rl.IsMouseButtonPressed(.RIGHT) {
			for p, idx in level.platforms {
				//checks for mouse click on a platform and if found, removes it from the dynamic []Platform array
				if rl.CheckCollisionPointRec(mp, {p.pos.x, p.pos.y, p.size.x, p.size.y}) {
					unordered_remove(&level.platforms, idx)
					break
				}
			}
		}

		if rl.IsKeyPressed(.Q) {
			if edit_rotation < 0 {
				edit_rotation = 0
			} else if edit_rotation == 0 {
				edit_rotation = 90
			}
		}
		if rl.IsKeyPressed(.E) {
			if edit_rotation > 0 {
				edit_rotation = 0
			} else if edit_rotation == 0 {
				edit_rotation = -90
			}
		}

	}
	if (use_camera) {
		rl.EndMode2D()
	}

	rl.EndDrawing()
}

draw_platform_collisions :: proc() {

	for p in level.platforms {
		rl.DrawRectangleLines(i32(p.pos.x), i32(p.pos.y), i32(p.size.x), i32(p.size.y), rl.BLUE)
	}

}

//handles diagonal inputs by not using nested if/else statement
//must do checks on vel.x and vel.y to return velocity to zero
handle_input :: proc() {
	if debug_info {
		if rl.IsKeyPressed(.EQUAL) {
			fontSize += 1
		}
		if rl.IsKeyPressed(.MINUS) {
			if fontSize >= 1 {
				fontSize -= 1
			}
		}
		if rl.IsKeyPressed(.SLASH) {
			cycle_font()
		}
	}

	//Edit mode
	if rl.IsKeyPressed(.F2) {
		if gs.state != .edit {
			gs.state = .edit
		} else {
			gs.state = .play
		}
	}

	if rl.IsKeyPressed(.F4) {
		debug_info = !debug_info
	}

	if rl.IsKeyPressed(.F3) {

		use_camera = !use_camera
	}

	if rl.IsKeyDown(.R) {
		resetPlayer()
	}

	if rl.IsKeyDown(.LEFT_SHIFT) {
		level.player.can_run = true
	} else {
		level.player.can_run = false
	}

	//Move left
	if rl.IsKeyDown(.A) {
		level.player.dir = .left
		level.player.vel.x = -120
		if level.player.action != .jumping {
			if level.player.can_run {
				level.player.movement = .running
			} else {
				level.player.movement = .walking
			}
			/*
			if level.player.current_anim.name != .run {
				level.player.current_anim = level.player.player_run
			}*/
		}
	}

	//Move right
	if rl.IsKeyDown(.D) {
		level.player.dir = .right
		level.player.vel.x = 120
		if level.player.action != .jumping {
			if level.player.can_run {
				level.player.movement = .running
			} else {
				level.player.movement = .walking
			}
			/*
			if level.player.current_anim.name != .run {
				level.player.current_anim = level.player.player_run
			}*/
		}
	}

	if rl.IsKeyDown(.SPACE) {
		//if player is on ground
		if (level.player.state == .grounded) {
			level.player.state = .not_grounded
			level.player.vel.y = -200
			level.player.action = .jumping
			/*
			if level.player.current_anim.name != .jump {
				level.player.current_anim = level.player.player_jump
			}*/
		}
	}

	//used to slow down player velocity so we don't slide around 
	if level.player.vel.x != 0 {
		if level.player.vel.x > 0 {
			level.player.vel.x -= 60
		} else {
			level.player.vel.x += 60
		}
	}
}

update :: proc() {
	// if player isn't grounded start a timer
	fmt.printf("Player state : %s\n", level.player.state)

	//Gravity
	level.player.vel.y += Gravity * rl.GetFrameTime()

	//Used to check if player
	old_pos := level.player.pos

	if level.player.can_run {
		level.player.pos += (level.player.vel * running_mult) * rl.GetFrameTime()
	} else {
		level.player.pos += level.player.vel * rl.GetFrameTime()
	}

	//janky falling detection?
	/*if level.player.pos.y < old_pos.y {
		level.player.player_falling_frames_counter += 1
		if level.player.player_falling_frames_counter > 30 {
			level.player.action = .falling
			level.player.current_anim = level.player.player_fall
		}
	}*/

	if (level.player.action != .jumping) {
		if level.player.vel.x == 0 {
			/*
			if level.player.current_anim.name != .idle {
				level.player.current_anim = level.player.player_idle
				level.player.movement = .idle
			}*/
		}
	}

	//Colliders for collision detection
	level.player.feet_collider = {level.player.pos.x - 2, level.player.pos.y - 1, 4, 1}
	level.player.head_collider = {level.player.pos.x - 2, level.player.pos.y - 12, 4, 1}
	if level.player.dir == .left {
		level.player.face_collider = {level.player.pos.x - 5, level.player.pos.y - 6, 1, 4}
	} else if level.player.dir == .right {
		level.player.face_collider = {level.player.pos.x + 5, level.player.pos.y - 6, 1, 4}
	}

	//JUMPING
	for p in level.platforms {
		if rl.CheckCollisionRecs(
			   level.player.feet_collider,
			   {p.pos.x, p.pos.y, p.size.x, p.size.y},
		   ) &&
		   (level.player.vel.y > 0) {
			level.player.vel.y = 0
			level.player.pos.y = p.pos.y
			level.player.state = .grounded
			level.player.action = .nil
		} else if rl.CheckCollisionRecs(
			   level.player.face_collider,
			   {p.pos.x, p.pos.y, p.size.x, p.size.y},
		   ) &&
		   (level.player.vel.x != 0) {
			if level.player.dir == .left {
				level.player.action = .sliding
				level.player.state = .not_grounded
				/*if level.player.current_anim.name != .sliding {
					level.player.current_anim = level.player.player_slide
				}*/
				if p.friction_face == .right {
					level.player.vel.y = sliding_speed * rl.GetFrameTime()
					level.player.state = .grounded

				}
				level.player.vel.x = 0
				level.player.pos.x = p.pos.x + p.size.x + 5
			} else if level.player.dir == .right {
				level.player.action = .sliding
				level.player.state = .not_grounded
				/*if level.player.current_anim.name != .sliding {
					level.player.current_anim = level.player.player_slide
				}*/
				if p.friction_face == .left {
					level.player.vel.y = sliding_speed * rl.GetFrameTime()
					level.player.state = .grounded
				}
				level.player.vel.x = 0
				level.player.pos.x = p.pos.x - 6
			}
		} else if rl.CheckCollisionRecs(
			   level.player.head_collider,
			   {p.pos.x, p.pos.y, p.size.x, p.size.y},
		   ) &&
		   (level.player.vel.y < 0) {
			fmt.printf("HEAD COLLISION\n")
			level.player.vel.y = 0
		}
	}

	if level.player.state != .grounded && level.player.action == .jumping {
		if old_pos.y < level.player.pos.y {
			level.player.apex = true
		} else {
			level.player.apex = false
		}
	}

	if old_pos == level.player.pos {
		level.player.movement = .idle
		/*if level.player.current_anim.name != .idle {
			level.player.current_anim = level.player.player_idle
		}*/
	}
}


//Creates a short platform at the location in pos
createSmallPlatform :: proc(p: Vec2, rot: f32) {
	if rot == 90 {
		append(
			&level.platforms,
			Platform {
				pos = {p.x, p.y},
				size = {16, 32},
				texture = platform_texture[2],
				rotation = rot,
				friction_face = .right,
			},
		)
	} else if rot == -90 {
		append(
			&level.platforms,
			Platform {
				pos = p,
				size = {16, 32},
				texture = platform_texture[2],
				rotation = rot,
				friction_face = .left,
			},
		)
	} else {
		append(
			&level.platforms,
			Platform {
				pos = p,
				size = {32, 16},
				texture = platform_texture[2],
				rotation = rot,
				friction_face = .up,
			},
		)
	}

}

createMediumPlatform :: proc(p: Vec2, rot: f32) {
	fmt.printf("CREATING MEDIUMAT x,y: %f,%f\n", p.x, p.y)
	if rot == 90 {
		append(
			&level.platforms,
			Platform {
				pos = {p.x, p.y},
				size = {16, 64},
				texture = platform_texture[1],
				rotation = rot,
				friction_face = .right,
			},
		)
	} else if rot == -90 {
		append(
			&level.platforms,
			Platform {
				pos = p,
				size = {16, 64},
				texture = platform_texture[1],
				rotation = rot,
				friction_face = .left,
			},
		)
	} else {
		append(
			&level.platforms,
			Platform {
				pos = p,
				size = {64, 16},
				texture = platform_texture[1],
				rotation = rot,
				friction_face = .up,
			},
		)
	}
}

createLargePlatform :: proc(p: Vec2, rot: f32) {
	if rot == 90 {
		append(
			&level.platforms,
			Platform {
				pos = {p.x, p.y},
				size = {16, 96},
				texture = platform_texture[0],
				rotation = rot,
				friction_face = .right,
			},
		)
	} else if rot == -90 {
		append(
			&level.platforms,
			Platform {
				pos = p,
				size = {16, 96},
				texture = platform_texture[0],
				rotation = rot,
				friction_face = .left,
			},
		)
	} else {
		append(
			&level.platforms,
			Platform {
				pos = p,
				size = {96, 16},
				texture = platform_texture[0],
				rotation = rot,
				friction_face = .up,
			},
		)
	}
}
