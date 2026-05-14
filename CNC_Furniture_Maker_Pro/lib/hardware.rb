# encoding: UTF-8
module CNCFMP
  module Hardware
    def self.get_marker_def(name, radius_mm, depth_mm, segments = 24)
      def_name = "#{name}_#{radius_mm}_#{depth_mm}"
      defs = Sketchup.active_model.definitions
      found = defs[def_name]
      return found if found

      cdef = defs.add(def_name)
      ents = cdef.entities
      circle = ents.add_circle([0, 0, 0], Z_AXIS, Utils.mm(radius_mm), segments)
      face = ents.add_face(circle)
      face.pushpull(Utils.mm(depth_mm))
      cdef
    end

    def self.add_pull_handle(parent_entities, origin_mm, size_mm, opts = {})
      return unless opts[:enabled]
      name = opts[:name] || 'Tay nắm'
      horizontal = opts.key?(:horizontal) ? opts[:horizontal] : size_mm[0] >= size_mm[2]
      length = opts[:length] || (horizontal ? [size_mm[0] * 0.42, 160.0].min : [size_mm[2] * 0.35, 220.0].min)
      length = [length, 96.0].max
      bar = opts[:bar] || 12.0
      stand = opts[:stand] || 24.0

      if horizontal
        x = origin_mm[0] + (size_mm[0] - length) / 2.0
        y = origin_mm[1] - stand
        z = origin_mm[2] + size_mm[2] - 70.0
        Geometry.create_box_component(parent_entities, name, [x, y, z], [length, bar, bar], thickness: bar, note: 'Phụ kiện tay nắm')
        Geometry.create_box_component(parent_entities, "#{name} chân trái", [x + 18.0, origin_mm[1] - stand, z - 18.0], [bar, stand, bar], thickness: bar, note: 'Chân tay nắm')
        Geometry.create_box_component(parent_entities, "#{name} chân phải", [x + length - 30.0, origin_mm[1] - stand, z - 18.0], [bar, stand, bar], thickness: bar, note: 'Chân tay nắm')
      else
        x = origin_mm[0] + size_mm[0] - 55.0
        y = origin_mm[1] - stand
        z = origin_mm[2] + (size_mm[2] - length) / 2.0
        Geometry.create_box_component(parent_entities, name, [x, y, z], [bar, bar, length], thickness: bar, note: 'Phụ kiện tay nắm')
        Geometry.create_box_component(parent_entities, "#{name} chân trên", [x - 18.0, origin_mm[1] - stand, z + length - 30.0], [bar, stand, bar], thickness: bar, note: 'Chân tay nắm')
        Geometry.create_box_component(parent_entities, "#{name} chân dưới", [x - 18.0, origin_mm[1] - stand, z + 18.0], [bar, stand, bar], thickness: bar, note: 'Chân tay nắm')
      end
    end

    def self.add_drawer_slides(parent_entities, origin_mm, size_mm, opts = {})
      return unless opts[:enabled]
      w, d, h = size_mm
      slide_len = [[d - 35.0, 250.0].max, opts[:max_length] || 550.0].min
      rail_h = opts[:rail_h] || 12.0
      rail_t = opts[:rail_t] || 12.0
      y = origin_mm[1] + 18.0
      z = origin_mm[2] + [h * 0.42, 55.0].max
      Geometry.create_box_component(parent_entities, 'Ray bi trái', [origin_mm[0] + 3.0, y, z], [rail_t, slide_len, rail_h], thickness: rail_t, note: 'Ray ngăn kéo')
      Geometry.create_box_component(parent_entities, 'Ray bi phải', [origin_mm[0] + w - rail_t - 3.0, y, z], [rail_t, slide_len, rail_h], thickness: rail_t, note: 'Ray ngăn kéo')
    end

    def self.add_adjustable_feet(parent_entities, cabinet_w, cabinet_d, kick_h, thickness, opts = {})
      return unless opts[:enabled]
      foot_dia = opts[:diameter] || 45.0
      foot_h = opts[:height] || [kick_h - 10.0, 60.0].min
      inset = opts[:inset] || 70.0
      positions = [
        [inset, inset],
        [cabinet_w - inset - foot_dia, inset],
        [inset, cabinet_d - inset - foot_dia],
        [cabinet_w - inset - foot_dia, cabinet_d - inset - foot_dia]
      ]
      positions.each_with_index do |(x, y), i|
        Geometry.create_box_component(parent_entities, "Chân tăng #{i + 1}", [x, y, 0], [foot_dia, foot_dia, foot_h], thickness: foot_dia, note: 'Chân tăng chỉnh')
      end
      if cabinet_w > 1200.0
        Geometry.create_box_component(parent_entities, 'Chân tăng giữa trước', [(cabinet_w - foot_dia) / 2.0, inset, 0], [foot_dia, foot_dia, foot_h], thickness: foot_dia, note: 'Chân tăng chỉnh')
      end
    end

    def self.add_fastener_marker(parent_entities, name, center_mm, opts = {})
      radius = opts[:radius] || 3.0
      depth = opts[:depth] || 12.0
      axis = opts[:axis] || :x
      make_cylinder(parent_entities, name, center_mm, radius, depth, axis)
    end

    def self.add_wardrobe_joint_markers(parent_entities, x_positions, depth_mm, bottom_z, top_z, opts = {})
      return unless opts[:enabled]
      front_y = opts[:front_y] || 37.0
      back_y = [depth_mm - (opts[:back_y] || 37.0), front_y + 80.0].max
      cam_offset = opts[:cam_offset] || 34.0
      z_low = bottom_z + cam_offset
      z_high = top_z - cam_offset

      x_positions.each do |x|
        [front_y, back_y].each do |y|
          add_fastener_marker(parent_entities, 'Cam liên kết đáy', [x, y, z_low], radius: 7.5, depth: 12.0, axis: :x)
          add_fastener_marker(parent_entities, 'Cam liên kết nóc', [x, y, z_high], radius: 7.5, depth: 12.0, axis: :x)
          add_fastener_marker(parent_entities, 'Chốt gỗ đáy', [x, y + 24.0, z_low], radius: 4.0, depth: 28.0, axis: :x)
          add_fastener_marker(parent_entities, 'Chốt gỗ nóc', [x, y + 24.0, z_high], radius: 4.0, depth: 28.0, axis: :x)
          add_fastener_marker(parent_entities, 'Vít confirmat', [x, y + 48.0, z_low + 28.0], radius: 2.5, depth: 45.0, axis: :x)
          add_fastener_marker(parent_entities, 'Vít confirmat', [x, y + 48.0, z_high - 28.0], radius: 2.5, depth: 45.0, axis: :x)
        end
      end
    end

    def self.add_carcass_joint_markers(parent_entities, x_positions, depth_mm, bottom_z, top_z, opts = {})
      add_wardrobe_joint_markers(parent_entities, x_positions, depth_mm, bottom_z, top_z, opts)
    end

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
        p_front = [Utils.mm(panel_origin[0] + x_pos), Utils.mm(panel_origin[1] + y_front), Utils.mm(panel_origin[2] + z)]
        tr_front = Geom::Transformation.translation(p_front)
        tr_rot_front = Geom::Transformation.rotation([0, 0, 0], Y_AXIS, rot_y)
        inst1 = entities.add_instance(cdef, tr_front * tr_rot_front)
        inst1.name = 'Sys32_Marker'

        # Back hole
          y_back = d - back_dist
        if y_back > y_front + 32
          p_back = [Utils.mm(panel_origin[0] + x_pos), Utils.mm(panel_origin[1] + y_back), Utils.mm(panel_origin[2] + z)]
          tr_back = Geom::Transformation.translation(p_back)
          tr_rot_back = Geom::Transformation.rotation([0, 0, 0], Y_AXIS, rot_y)
          inst2 = entities.add_instance(cdef, tr_back * tr_rot_back)
          inst2.name = 'Sys32_Marker'
        end
      end
    end
  end
end
