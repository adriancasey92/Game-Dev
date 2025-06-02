// neon_shift.fs - Neon Glow Color Shifting
#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;

out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    // Create neon colors that shift over time
    float phase = time * 1.5;
    
    vec3 neonColors[4];
    neonColors[0] = vec3(1.0, 0.0, 1.0); // Magenta
    neonColors[1] = vec3(0.0, 1.0, 1.0); // Cyan
    neonColors[2] = vec3(1.0, 1.0, 0.0); // Yellow
    neonColors[3] = vec3(1.0, 0.2, 0.8); // Hot Pink
    
    // Cycle through neon colors
    int index = int(phase) % 4;
    int nextIndex = (index + 1) % 4;
    float blend = fract(phase);
    
    vec3 currentNeon = mix(neonColors[index], neonColors[nextIndex], blend);
    
    // Boost brightness for neon effect
    vec3 boostedColor = texelColor.rgb * currentNeon * 1.5;
    
    finalColor = vec4(boostedColor, texelColor.a) * colDiffuse * fragColor;
}