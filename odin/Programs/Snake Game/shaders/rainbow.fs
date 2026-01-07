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
    
    float rainbow = time * 2.0 + fragTexCoord.x * 6.28 + fragTexCoord.y * 3.14;
    
    vec3 rainbowColor = vec3(
        sin(rainbow) * 0.5 + 0.5,
        sin(rainbow + 2.094) * 0.5 + 0.5, 
        sin(rainbow + 4.188) * 0.5 + 0.5
    );
    
    finalColor = vec4(texelColor.rgb * rainbowColor * 1.5, texelColor.a) * colDiffuse * fragColor;
}
