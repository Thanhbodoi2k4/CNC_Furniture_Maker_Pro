# encoding: UTF-8
module CNCFMP
  module Geometry
    # Tạo component dạng hộp chữ nhật, kích thước mm
    # size_mm = [x_size, y_size, z_size]
    # origin_mm = [x, y, z]
    def self.create_box_component(parent, name, origin_mm, size_mm, attrs = {})
      defs = Sketchup.active_model.definitions
      cdef = defs.add(name)
      ents = cdef.entities
      x = Utils.mm(size_mm[0])
      y = Utils.mm(size_mm[1])
      z = Utils.mm(size_mm[2])
      pts = [[0,0,0],[x,0,0],[x,y,0],[0,y,0]]
      face = ents.add_face(pts)
      face.reverse! if face.normal.z < 0
      face.pushpull(z)
      ox = Utils.mm(origin_mm[0])
      oy = Utils.mm(origin_mm[1])
      oz = Utils.mm(origin_mm[2])
      tr = Geom::Transformation.new([ox, oy, oz])
      inst = parent.add_instance(cdef, tr)
      inst.name = name
      assign_attrs(inst, name, size_mm, attrs)
      inst
    end
    def self.assign_attrs(inst, name, size_mm, attrs)
      dict = 'CNCFMP'
      inst.set_attribute(dict, 'part_name', name)
      inst.set_attribute(dict, 'width_mm',  size_mm[0])
      inst.set_attribute(dict, 'depth_mm',  size_mm[1])
      inst.set_attribute(dict, 'height_mm', size_mm[2])
      inst.set_attribute(dict, 'material_thickness_mm', attrs[:thickness] || nil)
      inst.set_attribute(dict, 'quantity',     attrs[:qty]  || 1)
      inst.set_attribute(dict, 'edge_banding', attrs[:edge] || '')
      inst.set_attribute(dict, 'cnc_note',     attrs[:note] || '')
    end
  end
end
