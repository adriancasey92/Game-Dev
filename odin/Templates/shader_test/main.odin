package main

import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
	// Initialize window
	screen_width: i32 = 800
	screen_height: i32 = 450

	rl.InitWindow(screen_width, screen_height, "Odin Raylib Shader Example")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	// Load shader - you need vertex and fragment shader files
	shader, ok := load_shader_safe("vertex.vs", "fragment.fs")
	if !ok {
		return
	}
	defer rl.UnloadShader(shader)

	// Get shader uniform locations
	time_loc := rl.GetShaderLocation(shader, "time")
	resolution_loc := rl.GetShaderLocation(shader, "resolution")

	// Create a render texture to apply the shader to
	target := rl.LoadRenderTexture(screen_width, screen_height)
	defer rl.UnloadRenderTexture(target)

	time: f32 = 0.0

	for !rl.WindowShouldClose() {
		// Update
		time += rl.GetFrameTime()

		// Set shader uniforms
		rl.SetShaderValue(shader, time_loc, &time, rl.ShaderUniformDataType.FLOAT)
		resolution := [2]f32{f32(screen_width), f32(screen_height)}
		rl.SetShaderValue(shader, resolution_loc, &resolution, rl.ShaderUniformDataType.VEC2)

		// Draw to render texture
		rl.BeginTextureMode(target)
		rl.ClearBackground(rl.BLACK)

		// Draw something to apply shader to
		rl.DrawRectangle(0, 0, screen_width / 2, screen_height / 2, rl.WHITE)

		rl.EndTextureMode()

		// Draw to screen with shader
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.BeginShaderMode(shader)
		// Draw the render texture (flipped vertically)
		rl.DrawTextureRec(
			target.texture,
			rl.Rectangle{0, 0, f32(target.texture.width), -f32(target.texture.height)},
			rl.Vector2{0, 0},
			rl.WHITE,
		)
		rl.EndShaderMode()

		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}

// Alternative approach: Apply shader to specific geometry
draw_with_shader :: proc(shader: rl.Shader) {
	rl.BeginShaderMode(shader)

	// Draw rectangles, textures, or other geometry
	rl.DrawRectangle(100, 100, 200, 200, rl.RED)
	rl.DrawCircle(400, 300, 50, rl.BLUE)

	rl.EndShaderMode()
}

// Helper function to load shader with error checking
load_shader_safe :: proc(vs_path, fs_path: cstring) -> (rl.Shader, bool) {
	shader := rl.LoadShader(vs_path, fs_path)

	// Check if shader loaded successfully
	if shader.id == 0 {
		fmt.println("Failed to load shader")
		return shader, false
	}

	fmt.println("Shader loaded successfully")
	return shader, true
}
