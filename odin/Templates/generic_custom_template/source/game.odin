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
import rand "core:math/rand"
import "core:mem"
import rl "vendor:raylib"

//Struct definitions from raylib
Vec2 :: rl.Vector2
Vec4 :: rl.Vector4
Rect :: rl.Rectangle

//WINDOW GLOBALS
PIXEL_WINDOW_HEIGHT :: 180
WIDTH :: i32(1680)
HEIGHT :: i32(1050)

//GAME GLOBALS
GRAVITY :: f32(500)
USE_GRAVITY :: false
PAUSE: bool
//FONT
BASE_FONT_SIZE: i32 = 20

//ATLAS BUILDER
ATLAS_DATA :: #load("atlas.png")
MENU_MOVE :: #load("../assets/sounds/menu_move.wav")
/*HIT_SOUND :: #load("../assets/sounds/hit.wav")
LAND_SOUND :: #load("../assets/sounds/land.wav")
WIN_SOUND :: #load("../assets/sounds/win.wav")*/

Game_State :: enum {
	intro,
	play,
	quadtree,
	options,
	audio_options,
	graphics_options,
	control_options,
	level_editor,
	pause,
	mainMenu,
}

Edit_Screen :: struct {
	//menu:          Menu,
	selection_idx: i32,
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
	state:             Game_State,
	prev_state:        Game_State,
	level:             Level,
	level_num:         i32,
	won:               bool,
	game_camera:       rl.Camera2D,
	settings_sound:    Sound_Settings,
	settings_graphics: Graphics_Settings,

	//Resources
	atlas:             rl.Texture2D,
	font:              rl.Font,
	scaled_font_size:  i32,
	hit_sound:         rl.Sound,
	land_sound:        rl.Sound,
	win_sound:         rl.Sound,

	//Editor
	in_menu:           bool,
	editing:           bool,
	finished:          bool,
	time_accumulator:  f32,

	//Globals
	run:               bool,
	won_at:            f64,
	initialized:       bool,
	entities:          hm.Handle_Map(Entity, Entity_Handle, MAX_ENTITIES),
	player_handle:     Entity_Handle,
	main_menu:         Menu,
	options_menu:      Menu,
	graphics_menu:     Menu,
	editor_menu:       Menu,
	audio_menu:        Menu,
	control_menu:      Menu,
	pause_menu:        Menu,
	state_changed:     bool,
	graphics_settings: Graphics_Settings,

	//particles?
	particle_system:   Particle_System,

	//shader
	frog_shader:       rl.Shader,
	background_shader: rl.Shader,
	shader_time:       f32,
	render_target:     rl.RenderTexture2D,

	//current time
	current_time:      f64,
}

//Global variables
edit_tex: i32
atlas: rl.Texture2D
hit_sound: rl.Sound
land_sound: rl.Sound
win_sound: rl.Sound
font: rl.Font
dt: f32
real_dt: f32

//Global game memory pointer
g: ^Game_Memory

//Stops alt+enter from 'entering' menu selections
MODIFIER_KEY_DOWN: bool

//Init raylib window, position and audio device
init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(
		WIDTH,
		HEIGHT,
		"Template (Odin, Raylib, Hot-Reload, Handle-Map, Texture-Atlas, Quadtree)",
	)
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.InitAudioDevice()
	rl.SetExitKey(.KEY_NULL)
}

//Initialise everything to do with the game+systems here
init :: proc() {
	//Allocate memory for game memory struct
	g = new(Game_Memory)

	init_shaders()

	//load our texture atlas, defer unloading the memory. 
	atlas_image := rl.LoadImageFromMemory(".png", raw_data(ATLAS_DATA), i32(len(ATLAS_DATA))) //load the raw data into atlas_image
	defer (rl.UnloadImage(atlas_image))

	g^ = Game_Memory {
		state = .mainMenu,
		atlas = rl.LoadTextureFromImage(atlas_image),
		run = true,
		entities = hm.make(Entity, Entity_Handle, MAX_ENTITIES, context.allocator),
		graphics_settings = Graphics_Settings {
			borderless = false,
			windowed = true,
			fullscreen = false,
		},
		game_camera = {zoom = 1, offset = {0, 0}, rotation = 0},
		//game_shader = Game_Shader{},
	}
	rl.SetShapesTexture(atlas, SHAPES_TEXTURE_RECT)

	//This clears the handlemap and creates the player handle. 
	reset_handles()

	//fonts
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
	init_menu()
	//init_level(&g.level)

	fmt.printf("Player Pos: %v\n", level.player_pos)
	game_hot_reloaded(g)
}

// Main update loop
// Handles input first, THEN updates entities accordingly. 
update :: proc() {
	update_camera()

	if rl.IsKeyPressed(.LEFT_ALT) {MODIFIER_KEY_DOWN = true}
	if rl.IsKeyReleased(.LEFT_ALT) {MODIFIER_KEY_DOWN = false}
	if rl.IsWindowState({.WINDOW_TOPMOST}) {rl.ClearWindowState({.WINDOW_TOPMOST})}

	//Have all features that will work regardless of state here
	//Borderless window toggle
	if rl.IsKeyPressed(.ENTER) && MODIFIER_KEY_DOWN {
		rl.ToggleBorderlessWindowed()
		g.graphics_settings.borderless = !g.graphics_settings.borderless
		g.graphics_settings.windowed = !g.graphics_settings.windowed
		g.graphics_settings.fullscreen = !g.graphics_settings.fullscreen
	}

	//DEBUG
	if rl.IsKeyPressed(.F4) {DEBUG_DRAW = !DEBUG_DRAW}
	//PAUSE
	if rl.IsKeyPressed(.P) {PAUSE = !PAUSE}
	//QUIT
	if (rl.WindowShouldClose()) {g.run = !g.run}

	//Control game state
	#partial switch (g.state) 
	{
	case .mainMenu:
		update_menu_generic(&g.main_menu)
	case .play:
		if !PAUSE {
			update_play()
		}
	case .quadtree:
		update_quadtree()
	case .options:
		update_menu_generic(&g.options_menu)
	case .audio_options:
		update_menu_generic(&g.audio_menu)
	case .graphics_options:
		update_menu_generic(&g.graphics_menu)
	case .control_options:
		update_menu_generic(&g.control_menu)
	case .pause:
		update_menu_generic(&g.pause_menu)
	case .level_editor:
		update_level_editor()
	}
}

//All of the gameplay logic goes here
update_play :: proc() {
	dt = rl.GetFrameTime()
	real_dt = dt

	//update_level(&g.level, dt)

	if rl.IsMouseButtonPressed(.LEFT) {
		m_pos_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), game_camera())
		ent_iter := hm.make_iter(&g.entities)
		for e, h in hm.iter(&ent_iter) {
			if rl.CheckCollisionPointRec(m_pos_world, e.rect) {
				if h == g.player_handle {
					//we clicked on the player
					fmt.printf("Clicked on player!\n")
				} else {
					//we clicked on another entity
					fmt.printf("Clicked on entity with handle: %v\nof type: %v\n", h, e.kind)
					e.debug_draw_bool = !e.debug_draw_bool
				}
			}
		}
		if rl.CheckCollisionPointRec(m_pos_world, get_player().rect) {
			//DO ENTITY STUFF
			debug_draw_entity(g.player_handle, get_player().pos)
			fmt.printf("Clicked on player2!\n")
		}
	}

	if rl.IsMouseButtonPressed(.RIGHT) {
		//Spawn random enemy around player
		p_pos := get_player().pos

		for i := 0; i < 1000; i += 1 {
			spawn_pos := Vec2 {
				p_pos.x + rand.float32_range(-200, 200),
				p_pos.y + rand.float32_range(-200, 200),
			}
			create_bullfrog(spawn_pos)
		}

	}
	//camera zoom
	mouse_scroll := rl.GetMouseWheelMove()
	if mouse_scroll != 0 {
		if mouse_scroll == 1 {
			CAMERA_ZOOM_MULT -= .15
		} else {
			CAMERA_ZOOM_MULT += .15
		}
	}

	if CAMERA_ZOOM_MULT > 1.5 {
		CAMERA_ZOOM_MULT = 1.5
	}
	if CAMERA_ZOOM_MULT < 0.5 {
		CAMERA_ZOOM_MULT = .5
	}

	if rl.IsKeyPressed(.C) {
		DEBUG_DRAW_COLLIDERS = !DEBUG_DRAW_COLLIDERS
	}

	//Pause game 
	if rl.IsKeyPressed(.ESCAPE) {
		//delete_current_level()
		g.state = .pause
		//g.in_menu = !g.in_menu
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
		return
	}

	//PHYSICS
	g.time_accumulator += dt
	PHYSICS_STEP :: 1 / 60.0
	/*for g.timentity_handle_accumulator >= PHYSICS_STEP {
		//do physics step
		//fmt.printf("TODO - Physics step\n")
		g.time_accumulator -= PHYSICS_STEP
		//physics_update()
	}*/

	//Update player
	update_entities(dt)
	//update_player(dt)
}

update_quadtree :: proc() {
	fmt.printf("Update quadtree\n")
	dt = rl.GetFrameTime()
	real_dt = dt

	build_quadtree()
}

//main draw function
draw :: proc() {
	//used when inside menu to fade background images
	fade: f32
	fade = 1
	#partial switch (g.state) 
	{
	case .mainMenu:
		draw_menu_generic(&g.main_menu, fade)
	case .play:
		draw_play(fade)
	case .quadtree:
		draw_quadtree()
	case .options:
		draw_menu_generic(&g.options_menu, fade)
	case .audio_options:
		draw_menu_generic(&g.audio_menu, fade)
	case .graphics_options:
		draw_menu_generic(&g.graphics_menu, fade)
	case .control_options:
		draw_menu_generic(&g.control_menu, fade)
	case .pause:
		//we still draw the game in the background with a fade
		draw_menu_generic(&g.pause_menu, fade)
	case .level_editor:
		draw_level_editor()
	}

	font_size := get_scaled_font_size()
	text_size := rl.MeasureTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("%i FPS", rl.GetFPS()),
		font_size,
		MENU_SPACING,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("%i FPS", rl.GetFPS()),
		{f32(rl.GetScreenWidth()) - (text_size.x + 10), 10},
		font_size,
		MENU_SPACING,
		rl.BLACK,
	)

	text_size = rl.MeasureTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Entities Drawn: %i/%i", ENTITES_DRAWN, hm.len(g.entities)),
		font_size,
		MENU_SPACING,
	)

	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Entities Drawn: %i/%i", ENTITES_DRAWN, hm.len(g.entities)),
		{
			f32(rl.GetScreenWidth()) - (text_size.x + 10),
			f32(rl.GetScreenHeight()) - (text_size.y + 40),
		},
		font_size,
		MENU_SPACING,
		rl.BLACK,
	)

	text_size = rl.MeasureTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Entities: %i", hm.len(g.entities)),
		font_size,
		MENU_SPACING,
	)

	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Entities: %i", hm.len(g.entities)),
		{
			f32(rl.GetScreenWidth()) - (text_size.x + 10),
			f32(rl.GetScreenHeight()) - (text_size.y + 10),
		},
		font_size,
		MENU_SPACING,
		rl.BLACK,
	)

	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat(
			"Camera Position: [%.2f,%.2f]",
			g.game_camera.target.x,
			g.game_camera.target.y,
		),
		{10, f32(rl.GetScreenHeight()) - 20},
		font_size,
		MENU_SPACING,
		rl.BLACK,
	)
}

draw_play :: proc(fade: f32) {
	//fade := f32(1)
	rl.BeginDrawing()
	rl.ClearBackground(rl.SKYBLUE)

	//Draw using game_camera
	rl.BeginMode2D(game_camera())
	{
		//draw_level(fade)
		draw_particle_system(&g.particle_system, fade)
		draw_entities(fade)
	}
	rl.EndMode2D()

	/*rl.BeginMode2D(ui_camera())
	rl.EndMode2D()*/

	//if DEBUG_DRAW {draw_player_debug()}
	if DEBUG_DRAW {
		for &item, _ in g.entities.items {
			if hm.skip(item) {
				// If you want to skip drawing this entity, you can continue here
				continue
			}
			if within_camera_bounds(item.handle) {
				if item.kind == .player {
					debug_player_draw()
				} else {
					if item.debug_draw_bool {
						// Draw debug info for the entity
						debug_draw_entity(
							item.handle,
							rl.GetWorldToScreen2D(item.pos, game_camera()),
						)
					}
				}
			}
		}
	}

	rl.EndDrawing()
}

draw_quadtree :: proc() {
	/*
	fade := f32(.9)
	rl.BeginDrawing()
	//rl.ClearBackground(rl.SKYBLUE)
	//Draw using game_camera
	draw_quad_tree(&quadtree)
	rl.BeginMode2D(game_camera())
	{
		//draw_level(fade)
		//draw_player(fade)
	}
	rl.EndMode2D()
	rl.BeginMode2D(ui_camera())
	rl.EndMode2D()
	rl.EndDrawing()*/
	fmt.printf("Draw quadtree - not implemented\n")
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
	level = g.level
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
WIN_SOUND :: #load("../assets/sounds/win.wav")*/

/*hit_sound = rl.LoadSoundFromWave(
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
	create_player_entity({0, 0})
}

//Memory management
// This is called when the game is shutting down.
// Delete any dynamic memory here
// and free the memory allocated for game memory.
shutdown :: proc() {
	fmt.printf("Shutdown...\n")
	rl.UnloadRenderTexture(g.render_target)
	rl.UnloadShader(g.frog_shader)
	//delete(level.platforms)
	//free(&level.platforms)
	//delete(level.edit_screen.menu.nodes)

	delete(g.level.collision_map)
	for coord in level.active_chunks {
		delete(level.active_chunks[coord].entities)
		delete(level.active_chunks[coord].decorations)
	}
	delete(g.level.active_chunks)


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
