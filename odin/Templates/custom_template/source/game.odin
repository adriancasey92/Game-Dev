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

import hm "../handle_map"
import "core:fmt"
import "core:mem"
import rl "vendor:raylib"


//Constants
PIXEL_WINDOW_HEIGHT :: 300
GRAVITY :: 500

DEBUG_DRAW: bool
DEBUG_DRAW_COLLIDERS: bool

//ATLAS BUILDER
ATLAS_DATA :: #load("atlas.png")
/*HIT_SOUND :: #load("../assets/sounds/hit.wav")
LAND_SOUND :: #load("../assets/sounds/land.wav")
WIN_SOUND :: #load("../assets/sounds/win.wav")*/

//Struct definitions from raylib
Vec2 :: rl.Vector2
Vec4 :: rl.Vector4
Rect :: rl.Rectangle

Platform :: struct {
	pos:           Vec2,
	pos_rect:      Rect,
	size_vec2:     Vec2,
	texture_rect:  Rect,
	rotation:      f32,
	friction_face: Entity_Direction,
	corners:       [4]Rect,
}

Game_State :: enum {
	intro,
	play,
	quadtree,
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

Game_Memory :: struct {
	//Game state
	state:            Game_State,
	level:            int,
	won:              bool,

	//Resources
	atlas:            rl.Texture2D,
	font:             rl.Font,
	hit_sound:        rl.Sound,
	land_sound:       rl.Sound,
	win_sound:        rl.Sound,

	//Editor
	in_menu:          bool,
	editing:          bool,
	finished:         bool,
	time_accumulator: f32,

	//Globals
	run:              bool,
	won_at:           f64,
	initialized:      bool,
	entities:         hm.Handle_Map(Entity, Entity_Handle, 10000),
	//entity_id_gen:    u64,
	//entity_top_count: u64,
	//world_name:       string,
	player_handle:    Entity_Handle,
}

quadtree: Quadtree
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

//Init raylib window, position and audio device
init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(
		1280,
		720,
		"Template (Odin, Raylib, Hot-Reload, Handle-Map, Texture-Atlas, Quadtree)",
	)
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.InitAudioDevice()
	rl.SetExitKey(.KEY_NULL)
}

//Initialise everything to do with the game+systems here
init :: proc() {
	g = new(Game_Memory)

	//load the raw data into atlas_image
	atlas_image := rl.LoadImageFromMemory(".png", raw_data(ATLAS_DATA), i32(len(ATLAS_DATA)))
	//font = load_atlased_font()a

	// Set the shapes drawing texture, this makes rl.DrawRectangleRec etc use the atlas
	rl.SetShapesTexture(atlas, SHAPES_TEXTURE_RECT)
	g^ = Game_Memory {
		state    = .mainMenu,
		atlas    = rl.LoadTextureFromImage(atlas_image),
		run      = true,
		entities = hm.make(Entity, Entity_Handle, 10000, context.allocator),
		level    = 0,
	}
	//edit_tex = 0
	//This automatically creates the player handle for g.player_handle
	reset_handles()
	//we no longer need this image as we have our atlas
	rl.UnloadImage(atlas_image)

	//Load fonts here
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
	init_level(g.level)
	init_quadtree(&quadtree, 25, 15)
	game_hot_reloaded(g)
}

// Main update loop
// Handles input first, THEN updates entities accordingly. 
update :: proc() {
	//Have all features that will work regardless of state here
	//Borderless window toggle
	if rl.IsKeyPressed(.ENTER) && rl.IsKeyDown(.LEFT_ALT) {
		rl.ToggleBorderlessWindowed()
	}


	#partial switch (g.state) 
	{
	case .mainMenu:
		update_menu()
	case .play:
		update_play()
	case .quadtree:
		update_quadtree()
	}
}

//UPDATE LOOPS 
update_menu :: proc() {
	dt = rl.GetFrameTime()
	real_dt = dt
}

update_play :: proc() {
	dt = rl.GetFrameTime()
	real_dt = dt


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
		fmt.printf("TODO - Editor update\n")
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

	/*p := hm.get(g.entities, g.player_handle)


	input: rl.Vector2

	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}

	if input.x != 0 {
		animation_update(&p.anim, rl.GetFrameTime())
		p.flip_x = input.x < 0
	}

	input = linalg.normalize0(input)
	p.pos += input * rl.GetFrameTime() * 100

	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}*/
}

update_quadtree :: proc() {
	dt = rl.GetFrameTime()
	real_dt = dt
}


draw :: proc() {

	#partial switch (g.state) 
	{
	case .mainMenu:
		draw_main_menu()
	case .play:
		draw_play()
	case .quadtree:
		draw_quadtree()
	}
}

draw_main_menu :: proc() {
	fade := f32(0.5)
	rl.BeginDrawing()
	rl.ClearBackground(rl.SKYBLUE)
	//GAME DRAW
	rl.BeginMode2D(game_camera())
	{
		draw_level(fade)
		draw_player(fade)
	}
	rl.EndMode2D()

	//UI DRAW
	rl.BeginMode2D(ui_camera())
	{
		//draw_menu
		rl.DrawText(
			rl.TextFormat("Main Menu"),
			rl.GetScreenHeight() / 2,
			rl.GetScreenWidth() / 2,
			25,
			rl.WHITE,
		)
	}
	rl.EndMode2D()
	rl.EndDrawing()
}

draw_play :: proc() {
	fade := f32(0)
	rl.BeginDrawing()
	rl.ClearBackground(rl.SKYBLUE)
	//Draw using game_camera
	rl.BeginMode2D(game_camera())
	{
		draw_level(fade)
		draw_player(fade)
	}
	rl.EndMode2D()
	rl.BeginMode2D(ui_camera())
	rl.EndMode2D()
	rl.EndDrawing()
}

draw_quadtree :: proc() {
	fade := f32(.9)
	rl.BeginDrawing()
	rl.ClearBackground(rl.SKYBLUE)
	//Draw using game_camera
	draw_quad_tree(&quadtree)
	rl.BeginMode2D(game_camera())
	{
		draw_level(fade)
		draw_player(fade)
	}
	rl.EndMode2D()
	rl.BeginMode2D(ui_camera())
	rl.EndMode2D()
	rl.EndDrawing()

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
	//GLOB_player = hm.get(g.entities, g.player_handle)
	//GLOB_player.anim = animation_create(.Frog_Move)
}

//Reloads all global data needed for the hot-reload to function without losing references 
//to our sounds and atlas. 
//This also re-creates our atlas. Our Hot-Reload.bat runs the atlas_builder lib, re-generating our 
//atlas and adding any added textures. 
//This usually breaks things regarless. 
/*HIT_SOUND :: #load("../assets/sounds/hit.wav")
	LAND_SOUND :: #load("../assets/sounds/land.wav")
	WIN_SOUND :: #load("../assets/sounds/win.wav")
	
	hit_sound = rl.LoadSoundFromWave(
		rl.LoadWaveFromMemory(".wav", raw_data(HIT_SOUND), i32(len(HIT_SOUND))),
	)
	land_sound = rl.LoadSoundFromWave(
		rl.LoadWaveFromMemory(".wav", raw_data(LAND_SOUND), i32(len(LAND_SOUND))),
	)
	win_sound = rl.LoadSoundFromWave(
		rl.LoadWaveFromMemory(".wav", raw_data(WIN_SOUND), i32(len(WIN_SOUND))),
	)*/
reload_global_data :: proc() {
	ATLAS_DATA :: #load("atlas.png")
	atlas_image := rl.LoadImageFromMemory(".png", raw_data(ATLAS_DATA), i32(len(ATLAS_DATA)))
	g.atlas = rl.LoadTextureFromImage(atlas_image)

	rl.UnloadImage(atlas_image)
	edit_tex = 0
}

//Clear the handles in our handlemap, and re-create player handle. 
reset_handles :: proc() {
	hm.clear(&g.entities)
	g.player_handle = hm.add(
		&g.entities,
		Entity {
			anim = animation_create(.Frog_Idle),
			pos = {0, 0},
			rect = {},
			dir = .left,
			can_run = true,
			vel = {0, 0},
			is_on_ground = true,
			movement = .idle,
			orientation = .norm,
			flip_x = false,
			flip_y = false,
			feet_collider = Rect{},
			face_collider = Rect{},
			head_collider = Rect{},
			corner_collider = Rect{},
		},
	)
}

//Memory management
// This is called when the game is shutting down.
// Delete any dynamic memory here
// and free the memory allocated for game memory.
shutdown :: proc() {
	delete(level.platforms)
	delete(level.edit_screen.menu.nodes)
	hm.delete(&g.entities)
	mem.free(g.font.recs)
	mem.free(g.font.glyphs)
	free(g)
}

shutdown_window :: proc() {
	rl.CloseAudioDevice()
	rl.CloseWindow()
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
