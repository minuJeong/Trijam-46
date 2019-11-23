#version 460

in vec4 in_position;
out vec4 vs_position;

void main()
{
    vs_position = in_position;
    gl_Position = in_position;
}
