// color_pulse.fs - Pulsing Color Effect
#version 330

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
    
    // Create pulsing effect based on distance from center
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(fragTexCoord, center);
    
    // Multiple pulse waves
    float pulse1 = sin(time * 3.0 - dist * 10.0) * 0.5 + 0.5;
    float pulse2 = sin(time * 2.0 - dist * 15.0) * 0.3 + 0.7;
    float pulse3 = sin(time * 4.0 - dist * 8.0) * 0.2 + 0.8;
    
    // Create color based on pulses
    vec3 pulseColor = vec3(
        pulse1,
        pulse2,
        pulse3
    );
    
    // Blend with original color
    vec3 finalRGB = texelColor.rgb * pulseColor;
    
    finalColor = vec4(finalRGB, texelColor.a) * colDiffuse * fragColor;
}

//---------------------------------------------------