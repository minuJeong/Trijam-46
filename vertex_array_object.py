from mesh import Mesh
from material import Material


class VertexArrayObject(object):
    def __init__(self, mesh: Mesh, material: Material):
        super(VertexArrayObject, self).__init__()
        self._mesh = mesh
        self._material = material
        self.is_built = False

    def invalidate(self):
        self._mesh.invalidate()
        self._material.invalidate()
        self.is_built = False

    def invalidate_mesh(self):
        self._mesh.invalidate()
        self.is_built = False

    def invalidate_material(self):
        self._material.invalidate()
        self.is_built = False

    def build(self, gl):
        """ gl is gpu context """

        if not self.is_built:
            self.is_built = True
            vb, ib = self._mesh.build(gl)
            program = self._material.build(gl)
            content = [(vb, *self._mesh.signiture())]
            self.vao = gl.vertex_array(program, content, ib, skip_errors=True)

        return self.vao

    def render(self):
        self.vao.render()

    def mesh(self):
        return self._mesh

    def material(self):
        return self._material
