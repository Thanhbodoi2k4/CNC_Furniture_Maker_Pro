# encoding: UTF-8
module CNCFMP
  module Hardware
    # Marker lỗ cam chốt: hình trụ Ø15mm, sâu 12mm, cách mép 34mm
    def self.add_cam_lock_markers(parent_entities, panel_origin_mm, panel_size_mm, opts = {})
      return unless opts[:enabled]
      offset_edge = opts[:offset_edge] || 34.0
      cam_dia     = opts[:cam_dia]     || 15.0
      cam_depth   = opts[:cam_depth]   || 12.0
      cx = panel_origin_mm[0] + offset_edge
      cy = panel_origin_mm[1] + panel_size_mm[1] / 2.0
      cz = panel_origin_mm[2] + panel_size_mm[2] / 2.0
      make_cylinder(parent_entities, 'Lỗ cam', [cx, cy, cz], cam_dia / 2.0, cam_depth, :z)
    end
    # Marker bản lề chén Ø35, cách mép 22.5mm, trên/dưới cách đầu/cuối 100mm
    def self.add_hinge_cup_markers(parent_entities, door_origin_mm, door_size_mm, opts = {})
      return unless opts[:enabled]
      cup_dia    = opts[:cup_dia]    || 35.0
      cup_depth  = opts[:cup_depth]  || 12.0
      from_edge  = opts[:from_edge]  || 22.5
      from_end   = opts[:from_end]   || 100.0
      height = door_size_mm[2]
      positions_z = [from_end, height - from_end]
      positions_z << height / 2.0 if height > 1600.0
      positions_z.each do |z_mm|
        cx = door_origin_mm[0] + from_edge
        cy = door_origin_mm[1] + door_size_mm[1] / 2.0
        cz = door_origin_mm[2] + z_mm
        make_cylinder(parent_entities, 'Lỗ chén bản lề', [cx, cy, cz], cup_dia / 2.0, cup_depth, :x)
      end
    end
    def self.make_cylinder(ents, name, center_mm, radius_mm, depth_mm, axis)
      defs = Sketchup.active_model.definitions
      cdef = defs.add(name)
      e = cdef.entities
      r = Utils.mm(radius_mm)
      d = Utils.mm(depth_mm)
      circle = e.add_circle([0,0,0], Z_AXIS, r, 24)
      face = e.add_face(circle)
      face.pushpull(d)
      tr = Geom::Transformation.new([Utils.mm(center_mm[0]), Utils.mm(center_mm[1]), Utils.mm(center_mm[2])])
      case axis
      when :x then tr = tr * Geom::Transformation.rotation([0,0,0], Y_AXIS, 90.degrees)
      when :y then tr = tr * Geom::Transformation.rotation([0,0,0], X_AXIS, 90.degrees)
      end
      inst = ents.add_instance(cdef, tr)
      inst.name = name
      inst
    end
  end
end
