package main

import "core:fmt"
import "core:math"
import "core:os"
import rl "vendor:raylib"

file_names: [4]cstring = {
	"shaders/default.vs",
	"shaders/rainbow.fs",
	"shaders/hue_shift.fs",
	"shaders/pulse.fs",
}

main :: proc() {
	screen_width: i32 = 800
	screen_height: i32 = 450

	rl.InitWindow(screen_width, screen_height, "Color Shifting - Separate Files")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// Create render texture for full-screen effects
	render_target := rl.LoadRenderTexture(screen_width, screen_height)
	defer rl.UnloadRenderTexture(render_target)

	for i := 0; i < len(file_names); i += 1 {
		if !file_exists(string(file_names[i])) {
			fmt.printf("Shader file not found: %s\n", file_names[i])
			fmt.println("Creating default shader files...")
			create_shader_files()
			return
		}
	}

	// Load shaders from files
	rainbow_shader, rainbow_ok := load_shader_safe("shaders/default.vs", "shaders/rainbow.fs")
	if !rainbow_ok {
		fmt.println("Failed to load rainbow shader")
		return
	}
	defer rl.UnloadShader(rainbow_shader)

	hue_shift_shader, hue_ok := load_shader_safe("shaders/default.vs", "shaders/hue_shift.fs")
	if !hue_ok {
		fmt.println("Failed to load hue shift shader")
		return
	}
	defer rl.UnloadShader(hue_shift_shader)

	pulse_shader, pulse_ok := load_shader_safe("shaders/default.vs", "shaders/pulse.fs")
	if !pulse_ok {
		fmt.println("Failed to load pulse shader")
		return
	}
	defer rl.UnloadShader(pulse_shader)

	// Get uniform locations
	time_loc_rainbow := rl.GetShaderLocation(rainbow_shader, "time")

	time_loc_hue := rl.GetShaderLocation(hue_shift_shader, "time")
	hue_offset_loc := rl.GetShaderLocation(hue_shift_shader, "hueOffset")

	time_loc_pulse := rl.GetShaderLocation(pulse_shader, "time")
	resolution_loc_pulse := rl.GetShaderLocation(pulse_shader, "resolution")

	time: f32 = 0.0
	current_shader := 0
	hue_offset: f32 = 0.0

	for !rl.WindowShouldClose() {
		time += rl.GetFrameTime()

		// Switch shaders
		if rl.IsKeyPressed(rl.KeyboardKey.ONE) do current_shader = 0
		if rl.IsKeyPressed(rl.KeyboardKey.TWO) do current_shader = 1
		if rl.IsKeyPressed(rl.KeyboardKey.THREE) do current_shader = 2

		// Control hue offset
		if rl.IsKeyDown(rl.KeyboardKey.LEFT) do hue_offset -= 180.0 * rl.GetFrameTime()
		if rl.IsKeyDown(rl.KeyboardKey.RIGHT) do hue_offset += 180.0 * rl.GetFrameTime()

		// Render to texture first
		rl.BeginTextureMode(render_target)
		rl.ClearBackground(rl.BLACK)
		draw_test_objects()
		rl.EndTextureMode()

		// Now draw to screen with shader applied
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		// Apply selected shader and draw the render target
		switch current_shader {
		case 0:
			// Rainbow
			rl.SetShaderValue(
				rainbow_shader,
				time_loc_rainbow,
				&time,
				rl.ShaderUniformDataType.FLOAT,
			)
			rl.BeginShaderMode(rainbow_shader)

		case 1:
			// Hue shift
			rl.SetShaderValue(
				hue_shift_shader,
				time_loc_hue,
				&time,
				rl.ShaderUniformDataType.FLOAT,
			)
			rl.SetShaderValue(
				hue_shift_shader,
				hue_offset_loc,
				&hue_offset,
				rl.ShaderUniformDataType.FLOAT,
			)
			rl.BeginShaderMode(hue_shift_shader)

		case 2:
			// Pulse
			resolution := [2]f32{f32(screen_width), f32(screen_height)}
			rl.SetShaderValue(pulse_shader, time_loc_pulse, &time, rl.ShaderUniformDataType.FLOAT)
			rl.SetShaderValue(
				pulse_shader,
				resolution_loc_pulse,
				&resolution,
				rl.ShaderUniformDataType.VEC2,
			)
			rl.BeginShaderMode(pulse_shader)
		}

		// Draw the render texture (flipped vertically for OpenGL)
		rl.DrawTextureRec(
			render_target.texture,
			rl.Rectangle {
				0,
				0,
				f32(render_target.texture.width),
				-f32(render_target.texture.height),
			},
			rl.Vector2{0, 0},
			rl.WHITE,
		)

		rl.EndShaderMode()

		// Draw UI without shader
		rl.DrawText("Press 1, 2, 3 to switch shaders", 10, 10, 20, rl.WHITE)
		rl.DrawText("Use LEFT/RIGHT arrows for hue control", 10, 35, 20, rl.WHITE)

		shader_names := [3]cstring{"Rainbow Shift", "Hue Shift", "Color Pulse"}
		rl.DrawText(shader_names[current_shader], 10, 60, 20, rl.YELLOW)

		rl.DrawFPS(10, screen_height - 30)

		rl.EndDrawing()
	}
}

draw_test_objects :: proc() {
	// Draw colorful shapes
	rl.DrawRectangle(50, 100, 150, 100, rl.RED)
	rl.DrawRectangle(220, 100, 150, 100, rl.GREEN)
	rl.DrawRectangle(390, 100, 150, 100, rl.BLUE)
	rl.DrawRectangle(560, 100, 150, 100, rl.YELLOW)

	rl.DrawCircle(125, 280, 50, rl.MAGENTA)
	rl.DrawCircle(295, 280, 50, rl.BLUE)
	rl.DrawCircle(465, 280, 50, rl.ORANGE)
	rl.DrawCircle(635, 280, 50, rl.PURPLE)

	// Draw some triangles
	rl.DrawTriangle(rl.Vector2{100, 350}, rl.Vector2{150, 400}, rl.Vector2{200, 350}, rl.PINK)

	rl.DrawTriangle(rl.Vector2{300, 350}, rl.Vector2{350, 400}, rl.Vector2{400, 350}, rl.LIME)
}

// Safe shader loading with error checking
load_shader_safe :: proc(vs_path, fs_path: cstring) -> (rl.Shader, bool) {
	// Check if files exist first
	if !file_exists(string(vs_path)) {
		fmt.printf("Vertex shader file not found: %s\n", vs_path)
		return rl.Shader{}, false
	}

	if !file_exists(string(fs_path)) {
		fmt.printf("Fragment shader file not found: %s\n", fs_path)
		return rl.Shader{}, false
	}

	fmt.printf("Loading shaders: %s, %s\n", vs_path, fs_path)

	shader := rl.LoadShader(vs_path, fs_path)

	// Check if shader loaded successfully
	if shader.id == 0 {
		fmt.printf("Failed to compile shader: %s, %s\n", vs_path, fs_path)
		return shader, false
	}

	fmt.printf("Shader loaded successfully (ID: %d)\n", shader.id)
	return shader, true
}

// Check if file exists
file_exists :: proc(filepath: string) -> bool {
	file_info, err := os.stat(filepath)
	return err == nil
}

// Helper to create shader directory and files
create_shader_files :: proc() {
	// Create shaders directory
	os.make_directory("shaders")

	// Write vertex shader
	vs_content := `#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;

out vec2 fragTexCoord;
out vec4 fragColor;

void main()
{
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
`


	rainbow_fs := `#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse; 
uniform float time;

out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    float rainbow = time * 2.0 + fragTexCoord.x * 6.28 + fragTexCoord.y * 3.14;
    
    vec3 rainbowColor = vec3(
        sin(rainbow) * 0.5 + 0.5,
        sin(rainbow + 2.094) * 0.5 + 0.5, 
        sin(rainbow + 4.188) * 0.5 + 0.5
    );
    
    finalColor = vec4(texelColor.rgb * rainbowColor * 1.5, texelColor.a) * colDiffuse * fragColor;
}
`


	hue_shift_fs := `#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform float hueOffset;

out vec4 finalColor;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    vec3 hsv = rgb2hsv(texelColor.rgb);
    hsv.x += (time * 0.5 + hueOffset / 360.0);
    hsv.x = fract(hsv.x);
    
    vec3 shiftedColor = hsv2rgb(hsv);
    
    finalColor = vec4(shiftedColor, texelColor.a) * colDiffuse * fragColor;
}
`


	pulse_fs := `#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform vec2 resolution;

out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(fragTexCoord, center);
    
    float pulse1 = sin(time * 3.0 - dist * 10.0) * 0.5 + 0.5;
    float pulse2 = sin(time * 2.0 - dist * 15.0) * 0.3 + 0.7;
    float pulse3 = sin(time * 4.0 - dist * 8.0) * 0.2 + 0.8;
    
    vec3 pulseColor = vec3(pulse1, pulse2, pulse3);
    
    finalColor = vec4(texelColor.rgb * pulseColor * 1.2, texelColor.a) * colDiffuse * fragColor;
}
`


	// Write files
	os.write_entire_file("shaders/default.vs", transmute([]u8)vs_content)
	os.write_entire_file("shaders/rainbow.fs", transmute([]u8)rainbow_fs)
	os.write_entire_file("shaders/hue_shift.fs", transmute([]u8)hue_shift_fs)
	os.write_entire_file("shaders/pulse.fs", transmute([]u8)pulse_fs)

	fmt.println("Shader files created in 'shaders/' directory")
}
