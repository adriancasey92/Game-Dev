// thermal_shift.fs - Thermal/Heat Map Style Color Shifting
#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;

out vec4 finalColor;

vec3 heatmapColor(float t) {
    // Clamp t to 0-1 range
    t = clamp(t, 0.0, 1.0);
    
    // Heat map: black -> red -> yellow -> white
    vec3 color;
    if (t < 0.33) {
        // Black to red
        color = vec3(t * 3.0, 0.0, 0.0);
    } else if (t < 0.66) {
        // Red to yellow
        float local_t = (t - 0.33) * 3.0;
        color = vec3(1.0, local_t, 0.0);
    } else {
        // Yellow to white
        float local_t = (t - 0.66) * 3.0;
        color = vec3(1.0, 1.0, local_t);
    }
    
    return color;
}

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    // Create heat value based on brightness and time
    float brightness = dot(texelColor.rgb, vec3(0.299, 0.587, 0.114));
    float heat = brightness + sin(time * 2.0) * 0.3;
    
    // Apply thermal color mapping
    vec3 thermalColor = heatmapColor(heat);
    
    finalColor = vec4(thermalColor, texelColor.a) * colDiffuse * fragColor;
}

//---------------------------------------------------