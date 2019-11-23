from glm import *
import glfw
import moderngl as mg
import numpy as np

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from mesh import Mesh
from technique import Technique
from material import Material
from vertex_array_object import VertexArrayObject


class Rendering(object):
    def __init__(self, window, width, height, gbuffer_div):
        super(Rendering, self).__init__()

        self.window = window
        self.width, self.height = width, height
        self.gbuffer_div = gbuffer_div

        self.init()

        self.pressed_keys = []
        self.movement = vec2(3.5, 1.0)

        glfw.set_key_callback(window, self.on_key)

        h = FileSystemEventHandler()
        h.on_modified = self.on_gl_modified
        o = Observer()
        o.schedule(h, "./gl/", True)
        o.start()

    def on_gl_modified(self, e):
        self.invalidate()

    def on_key(self, w, s, k, a, m):
        if a == glfw.PRESS:
            if s not in self.pressed_keys:
                self.pressed_keys.append(s)

        elif a == glfw.RELEASE:
            if s in self.pressed_keys:
                self.pressed_keys.remove(s)

    def init(self):
        self.gl = mg.create_context()

        gbuffer_size = (self.width // self.gbuffer_div, self.height // self.gbuffer_div)
        self.color = self.gl.texture(gbuffer_size, 4)
        self.normal = self.gl.texture(gbuffer_size, 4)
        self.position = self.gl.texture(gbuffer_size, 4)
        self.stencil = self.gl.texture(gbuffer_size, 4)

        self.gbuffer = self.gl.framebuffer(
            color_attachments=(self.color, self.normal, self.position, self.stencil)
        )

        vertices = np.array(
            [
                (-1.0, -1.0, 0.0, 1.0),
                (-1.0, +1.0, 0.0, 1.0),
                (+1.0, -1.0, 0.0, 1.0),
                (+1.0, +1.0, 0.0, 1.0),
            ]
        )
        indices = np.array([0, 1, 2, 2, 1, 3])
        mesh = Mesh(vertices, indices)
        technique = Technique(
            "./gl/vs/base_raymarch.glsl", "./gl/fs/base_raymarch.glsl"
        )
        material_raymarch = Material(technique)
        self.screen_vao = VertexArrayObject(mesh, material_raymarch)

        technique_postprocess = Technique(
            "./gl/vs/postprocess.glsl", "./gl/fs/postprocess.glsl"
        )
        material_postprocess = Material(technique_postprocess)
        self.postprocess_vao = VertexArrayObject(mesh, material_postprocess)

        self.build(self.gl)

        u_camera_pos = vec3(-9.0, 24.0, -9.0)

        material_raymarch.uniform("u_aspect", self.width / self.height)
        material_raymarch.uniform("u_camerapos", u_camera_pos)
        material_postprocess.uniform("u_camerapos", u_camera_pos)

    def invalidate(self):
        self.screen_vao.invalidate()
        self.postprocess_vao.invalidate()
        self.is_bulit = False

    def build(self, gl):
        self.is_bulit = True
        try:
            self.screen_vao.build(self.gl)
            self.postprocess_vao.build(self.gl)
            print("vao rebuilding done.")

        except Exception as e:
            print("[!] Renderer: vao rebuilding failed")
            print(e)

        self.prev_t = glfw.get_time()

    def read_keys(self, t):
        move = vec2(0.0, 0.0)
        for key in self.pressed_keys:
            if key == glfw.KEY_LEFT or key == glfw.KEY_A:
                move.x = -1.0

            elif key == glfw.KEY_UP or key == glfw.KEY_W:
                move.y = -1.0

            elif key == glfw.KEY_RIGHT or key == glfw.KEY_D:
                move.x = 1.0

            elif key == glfw.KEY_DOWN or key == glfw.KEY_S:
                move.y = 1.0

        self.movement += move * 10.0 * (t - self.prev_t)
        self.screen_vao.material().uniform("u_control", self.movement)
        self.screen_vao.material().uniform("u_speed", length(move))

        if length(move) > 0.1:
            self.screen_vao.material().uniform("u_char_xz_rotation", atan(move.y, -move.x))

    def render(self):
        if not self.is_bulit:
            self.build(self.gl)

        t = glfw.get_time()
        self.read_keys(t)

        self.gbuffer.use()

        self.screen_vao.material().uniform("u_time", t)
        self.screen_vao.render()

        self.gl.screen.use()
        self.color.use(0)
        self.normal.use(1)
        self.position.use(2)
        self.stencil.use(3)

        self.postprocess_vao.material().uniform("u_gbuffer_color", 0)
        self.postprocess_vao.material().uniform("u_gbuffer_normal", 1)
        self.postprocess_vao.material().uniform("u_gbuffer_position", 2)
        self.postprocess_vao.material().uniform("u_gbuffer_stencil", 3)
        self.postprocess_vao.render()

        self.prev_t = t


def main():
    width, height = 800, 600
    title = "trijam-46"
    gbuffer_div = 2

    glfw.init()
    glfw.window_hint(glfw.FLOATING, glfw.TRUE)
    glfw.window_hint(glfw.RESIZABLE, glfw.FALSE)
    window = glfw.create_window(width, height, title, None, None)
    glfw.make_context_current(window)
    rendering = Rendering(window, width, height, gbuffer_div)

    while not glfw.window_should_close(window):
        glfw.poll_events()
        rendering.render()
        glfw.swap_buffers(window)


if __name__ == "__main__":
    main()
