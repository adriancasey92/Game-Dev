// rainbow_shift.fs - Rainbow Color Shifting
#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;

out vec4 finalColor;

void main()
{
    // Sample the original texture/color
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    // Create rainbow effect based on time and position
    float rainbow = time * 2.0 + fragTexCoord.x * 3.14159 + fragTexCoord.y * 1.57;
    
    vec3 rainbowColor = vec3(
        sin(rainbow) * 0.5 + 0.5,           // Red channel
        sin(rainbow + 2.094) * 0.5 + 0.5,   // Green channel (120° phase)
        sin(rainbow + 4.188) * 0.5 + 0.5    // Blue channel (240° phase)
    );
    
    // Blend original color with rainbow effect
    vec3 finalRGB = mix(texelColor.rgb, rainbowColor, 0.7);
    
    finalColor = vec4(finalRGB, texelColor.a) * colDiffuse * fragColor;
}

//---------------------------------------------------
// This shader creates a dynamic rainbow color shifting effect based on time and texture coordinates.
// The rainbow effect is blended with the original texture color, creating a vibrant and colorful appearance.