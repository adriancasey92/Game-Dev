#version 330
// fragment.fs - Fragment Shader (Animated Wave Effect)
/*


// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform vec2 resolution;

// Output fragment color
out vec4 finalColor;

void main()
{
    // Normalize coordinates to -1.0 to 1.0
    vec2 uv = (fragTexCoord * 2.0) - 1.0;
    
    // Create animated wave effect
    float wave = sin(uv.x * 10.0 + time * 2.0) * 0.1;
    wave += sin(uv.y * 15.0 + time * 3.0) * 0.05;
    
    // Create color based on position and time
    vec3 color = vec3(
        0.5 + 0.5 * sin(time + uv.x),
        0.5 + 0.5 * sin(time + uv.y + 2.0),
        0.5 + 0.5 * sin(time + uv.x + uv.y + 4.0)
    );
    
    // Apply wave distortion
    color += wave;
    
    // Output final color
    finalColor = vec4(color, 1.0) * colDiffuse * fragColor;
}*/

//---------------------------------------------------

// Alternative simple color-shifting fragment shader

#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;

out vec4 finalColor;

void main()
{
    // Sample the texture
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    // Create color shift effect
    vec3 colorShift = vec3(
        sin(time) * 0.5 + 0.5,
        sin(time + 2.0) * 0.5 + 0.5,
        sin(time + 4.0) * 0.5 + 0.5
    );
    
    finalColor = texelColor * vec4(colorShift, 1.0) * colDiffuse * fragColor;
}
*/