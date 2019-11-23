from technique import Technique


class Material(object):
    def __init__(self, technique: Technique):
        super(Material, self).__init__()
        self.technique = technique
        self._propertymap = {}
        self.is_built = False

    def invalidate(self):
        self.technique.invalidate()

    def build(self, gl):
        """ gl is gpu context """

        program = self.technique.build(gl)
        for u_name, u_value in self._propertymap.items():
            self.technique.uniform(u_name, u_value)
        return program

    def uniform(self, u_name, u_value):
        self._propertymap[u_name] = u_value
        self.technique.uniform(u_name, u_value)

    def __getitem__(self, u_name):
        if u_name not in self._propertymap:
            return None
        return self._propertymap[u_name]
