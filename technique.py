from glm import *


class Technique(object):
    def __init__(self, vertex_shader_path, fragment_shader_path):
        super(Technique, self).__init__()
        self.vertex_shader_path = vertex_shader_path
        self.fragment_shader_path = fragment_shader_path
        self.is_load = False

    def invalidate(self):
        self.is_load = False

    def read_shader(self, path):
        with open(path, "r") as fp:
            content = fp.read()

        inc = "#include "
        lines = []
        for line in content.splitlines():
            if line.startswith(inc):
                inc_path = line.split(inc)[1]
                lines.append(self.read_shader(inc_path))

            else:
                lines.append(line)
        return "\n".join(lines)

    def build(self, gl):
        """ gl is gpu context """

        if not self.is_load:
            self.is_load = True
            self.vertex_shader = self.read_shader(self.vertex_shader_path)
            self.fragment_shader = self.read_shader(self.fragment_shader_path)
            self._program = gl.program(
                vertex_shader=self.vertex_shader, fragment_shader=self.fragment_shader
            )
        return self._program

    def uniform(self, u_name, u_value):
        if u_name not in self._program:
            return

        if isinstance(u_value, (vec2, vec3, vec4, mat4)):
            self._program[u_name].write(bytes(u_value))
        else:
            self._program[u_name].value = u_value

    def program(self):
        return self.build()
