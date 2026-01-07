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
    
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(fragTexCoord, center);
    
    float pulse1 = sin(time * 3.0 - dist * 10.0) * 0.5 + 0.5;
    float pulse2 = sin(time * 2.0 - dist * 15.0) * 0.3 + 0.7;
    float pulse3 = sin(time * 4.0 - dist * 8.0) * 0.2 + 0.8;
    
    vec3 pulseColor = vec3(pulse1, pulse2, pulse3);
    
    finalColor = vec4(texelColor.rgb * pulseColor * 1.2, texelColor.a) * colDiffuse * fragColor;
}
