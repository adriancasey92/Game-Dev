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

import "core:fmt"
import "core:math/linalg"
//import "core:mem"
//import b2d "vendor:box2d"
import rl "vendor:raylib"


//Constants
PIXEL_WINDOW_HEIGHT :: 180
GRAVITY :: 500

//ATLAS BUILDER
ATLAS_DATA :: #load("atlas.png")
HIT_SOUND :: #load("../assets/sounds/hit.wav")
LAND_SOUND :: #load("../assets/sounds/land.wav")
WIN_SOUND :: #load("../assets/sounds/win.wav")

//Struct definitions for the atlas
Vec2 :: rl.Vector2
Rect :: rl.Rectangle

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
	//texture: Atlas_Texture,
	anim:          Animation,
	flip_x:        bool,
	feet_collider: Rect,
	face_collider: Rect,
	head_collider: Rect,
}

Level :: struct {
	platforms:   [dynamic]Platform,
	player:      Player,
	edit_screen: Edit_Screen,
}

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

Platform :: struct {
	pos:           Vec2,
	size:          Vec2,
	texture:       rl.Texture,
	rotation:      f32,
	type:          Platform_Type,
	friction_face: Direction,
}

Platform_Type :: enum {
	small,
	medium,
	large,
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


Game_Memory :: struct {
	state:       Game_State,
	level:       Level,
	//Resources
	atlas:       rl.Texture2D,
	font:        rl.Font,
	hit_sound:   rl.Sound,
	land_sound:  rl.Sound,
	win_sound:   rl.Sound,

	//Entities
	//player:         Player,
	//player_pos:     rl.Vector2,
	//player_texture: rl.Texture,

	//Globals
	some_number: int,
	run:         bool,
}

atlas: rl.Texture2D
hit_sound: rl.Sound
land_sound: rl.Sound
win_sound: rl.Sound
g: ^Game_Memory
font: rl.Font

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {zoom = h / PIXEL_WINDOW_HEIGHT, target = g.level.player.pos, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

update :: proc() {
	input: rl.Vector2

	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}

	if input.x != 0 {
		animation_update(&g.level.player.anim, rl.GetFrameTime())
		g.level.player.flip_x = input.x < 0
	}

	input = linalg.normalize0(input)
	g.level.player.pos += input * rl.GetFrameTime() * 100

	g.some_number += 1

	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
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

	// The dest rectangle tells us where on screen to draw the player.
	dest := Rect {
		p.pos.x + offset.x,
		p.pos.y + offset.y,
		anim_texture.rect.width,
		anim_texture.rect.height,
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
	rl.DrawTexturePro(atlas, atlas_rect, dest, origin, 0, rl.WHITE)
}


draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.SKYBLUE)

	rl.BeginMode2D(game_camera())
	//rl.DrawTextureEx(g.player_texture, g.player_pos, 0, 1, rl.WHITE)
	rl.DrawTextureRec(atlas, atlas_textures[.Platform1].rect, {0, 0}, rl.WHITE)
	draw_player(g.level.player)

	rl.EndMode2D()
	rl.BeginMode2D(ui_camera())

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.
	rl.DrawText(
		fmt.ctprintf("some_number: %v\nplayer_pos: %v", g.some_number, g.level.player.pos),
		5,
		5,
		8,
		rl.WHITE,
	)

	rl.EndMode2D()

	rl.EndDrawing()
}

init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.InitAudioDevice()
	rl.SetExitKey(.KEY_NULL)
}

init :: proc() {
	g = new(Game_Memory)

	//load the raw data into atlas_image
	atlas_image := rl.LoadImageFromMemory(".png", raw_data(ATLAS_DATA), i32(len(ATLAS_DATA)))
	//font = load_atlased_font()

	// Set the shapes drawing texture, this makes rl.DrawRectangleRec etc use the atlas
	rl.SetShapesTexture(atlas, SHAPES_TEXTURE_RECT)
	g^ = Game_Memory {
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
		some_number = 100,
		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		level = {
			player = {pos = {0, 0}, anim = animation_create(.Frog_Fall)},
			platforms = [dynamic]Platform{},
		},
	}
	rl.UnloadImage(atlas_image)
	game_hot_reloaded(g)
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
	hit_sound = g.hit_sound
	land_sound = g.land_sound
	win_sound = g.win_sound

	g.level.player.anim = animation_create(.Frog_Move)
}

reload_global_data :: proc() {
	ATLAS_DATA :: #load("atlas.png")
	HIT_SOUND :: #load("../assets/sounds/hit.wav")
	LAND_SOUND :: #load("../assets/sounds/land.wav")
	WIN_SOUND :: #load("../assets/sounds/win.wav")
	atlas_image := rl.LoadImageFromMemory(".png", raw_data(ATLAS_DATA), i32(len(ATLAS_DATA)))
	hit_sound = rl.LoadSoundFromWave(
		rl.LoadWaveFromMemory(".wav", raw_data(HIT_SOUND), i32(len(HIT_SOUND))),
	)
	land_sound = rl.LoadSoundFromWave(
		rl.LoadWaveFromMemory(".wav", raw_data(LAND_SOUND), i32(len(LAND_SOUND))),
	)
	win_sound = rl.LoadSoundFromWave(
		rl.LoadWaveFromMemory(".wav", raw_data(WIN_SOUND), i32(len(WIN_SOUND))),
	)
	g.atlas = rl.LoadTextureFromImage(atlas_image)


	// This is a bit of a hack. The atlas data is stored in the `atlas_textures` variable.
	// We need to reload it so that the new DLL has the same data as the old one.
	// This is not necessary if you don't use hot reload, but it is a good idea to do it anyway.
	// It also makes sure that the atlas data is always up to date with the latest version of the atlas.png file.
}

shutdown :: proc() {
	//delete any dynamic memory here 
	//delete(g.walls)
	//mem.free(g.font.recs)
	//mem.free(g.font.glyphs)
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
