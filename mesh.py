import numpy as np


class Mesh(object):
    def __init__(self, vertices: np.ndarray, indices: np.ndarray):
        super(Mesh, self).__init__()

        vertices = vertices.astype(np.float32)
        indices = indices.astype(np.int32)

        self.vertices = vertices
        self.indices = indices
        self.vertex_components = "4f"
        self.vertex_signiture = ("in_position")
        self.is_built = False

    def invalidate(self):
        self.is_built = False

    def build(self, gl):
        """ gl is gpu context """

        if not self.is_built:
            self.is_built = True
            self.vertex_buffer_object = gl.buffer(self.vertices.tobytes())
            self.index_buffer_object = gl.buffer(self.indices.tobytes())

        return self.vertex_buffer_object, self.index_buffer_object

    def set_vertex_components(self, components: str):
        self.vertex_components = components

    def set_vertex_signiture(self, signiture: list):
        self.vertex_signiture = signiture

    def signiture(self):
        return (self.vertex_components, self.vertex_signiture)
