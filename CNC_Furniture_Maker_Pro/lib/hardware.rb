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

    def self.add_system_32_holes(entities, panel_origin, panel_size, options = {})
      return unless options[:enabled]
      t = panel_size[0] # Độ dày ván (x)
      d = panel_size[1] # Chiều sâu ván (y)
      h = panel_size[2] # Chiều cao ván (z)

      return if d < 100 || h < 200

      # System 32 rules
      front_dist = 37.0
      back_dist = 37.0
      hole_spacing = 32.0
      hole_depth = 10.0
      hole_radius = 2.5

      cdef = get_marker_def('Sys32_Hole', hole_radius, hole_depth)

      # Determine start and end z
      z_start = 100.0
      z_end = h - 100.0
      num_holes = ((z_end - z_start) / hole_spacing).floor
      return if num_holes < 1

      # Center the holes vertically
      actual_span = (num_holes - 1) * hole_spacing
      start_z = (h - actual_span) / 2.0

      # Determine which face to drill
      # If the panel is on the left side of the cabinet (origin.x == 0), drill on the right face (+x).
      # If panel is on the right, drill on the left face (-x).
      # We'll just pass a direction or assume it based on options.
      dir = options[:direction] || 1 # 1 for +x, -1 for -x
      x_pos = (dir == 1) ? t : 0
      rot_y = (dir == 1) ? 90.degrees : -90.degrees

      num_holes.times do |i|
        z = start_z + i * hole_spacing
        
        # Front hole
        y_front = front_dist
        tr_front = Geom::Transformation.translation([panel_origin[0] + x_pos, panel_origin[1] + y_front, panel_origin[2] + z])
        tr_rot_front = Geom::Transformation.rotation([panel_origin[0] + x_pos, panel_origin[1] + y_front, panel_origin[2] + z], Y_AXIS, rot_y)
        inst1 = entities.add_instance(cdef, tr_front * tr_rot_front)
        inst1.name = 'Sys32_Marker'

        # Back hole
        y_back = d - back_dist
        if y_back > y_front + 32
          tr_back = Geom::Transformation.translation([panel_origin[0] + x_pos, panel_origin[1] + y_back, panel_origin[2] + z])
          tr_rot_back = Geom::Transformation.rotation([panel_origin[0] + x_pos, panel_origin[1] + y_back, panel_origin[2] + z], Y_AXIS, rot_y)
          inst2 = entities.add_instance(cdef, tr_back * tr_rot_back)
          inst2.name = 'Sys32_Marker'
        end
      end
    end
  end
end
