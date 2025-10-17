package game

import "core:fmt"
import os "core:os"
import rl "vendor:raylib"

Shader :: struct {
	file:           rl.Shader,
	time_loc:       i32,
	hue_offset_loc: i32,
	resolution_loc: i32,
}

file_names: [4]cstring = {
	"shaders/default.vs",
	"shaders/rainbow.fs",
	"shaders/hue_shift.fs",
	"shaders/pulse.fs",
}

init_shaders :: proc() {
	fmt.printf("TODO - IMPLEMENT SHADERS\n")
	/*
	g.render_target = rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())
	for i := 0; i < len(file_names); i += 1 {
		if !file_exists(string(file_names[i])) {
			fmt.printf("Shader file not found: %s\n", file_names[i])
			fmt.println("Creating default shader files...")
			create_shader_files()
		}
	}*/
}

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
