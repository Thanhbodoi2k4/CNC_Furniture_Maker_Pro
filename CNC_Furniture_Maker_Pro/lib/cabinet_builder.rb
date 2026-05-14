# encoding: UTF-8
module CNCFMP
  module CabinetBuilder
    DICT = 'CNCFMP'
    def self.build(p)
      Utils.validate(p)
      model = Sketchup.active_model
      model.start_operation('CNC Furniture', true)
      begin
        type = p['type']
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        group = model.active_entities.add_group
        group.name = "#{type}_#{timestamp}"
        cutlist =
          case type
          when 'base_cabinet'   then build_base_cabinet(group, p)
          when 'wall_cabinet'   then build_wall_cabinet(group, p)
          when 'wardrobe'       then build_wardrobe(group, p)
          when 'bed'            then build_bed(group, p)
          when 'desk'           then build_desk(group, p)
          when 'bedside'        then build_bedside_table(group, p)
          else raise "Loại sản phẩm không hợp lệ: #{type}"
          end
        model.commit_operation
        cutlist
      rescue => e
        model.abort_operation
        raise e
      end
    end

    def self.panel(group, name, origin, size, attrs)
      Geometry.create_box_component(group.entities, name, origin, size, attrs)
    end

    def self.cut_entry(name, qty, length, width, thickness, edge = '', note = '')
      { name: name, qty: qty, length: length.round(1), width: width.round(1),
        thickness: thickness.round(1), edge: edge, note: note }
    end

    def self.part_ok?(length, width, height)
      length.to_f > 1.0 && width.to_f > 1.0 && height.to_f > 1.0
    end

    def self.internal_depth(p, d)
      has_back = p['has_back'] != false
      return d unless has_back

      btype = p['back_type'] || 'flush'
      tb = (p['back_thickness'] || 5).to_f
      inset = (p['back_inset'] || 15).to_f
      btype == 'dado' ? d - inset : d - tb
    end

    def self.auto_structural_compartments(width, thickness, requested)
      inner_w = width - 2 * thickness
      by_hanging_span = (inner_w / 900.0).ceil
      by_shelf_span = (inner_w / 800.0).ceil
      [requested.to_i, by_hanging_span, by_shelf_span, 1].max
    end

    def self.auto_kitchen_compartments(width, thickness, requested)
      inner_w = width - 2 * thickness
      by_module = (inner_w / 800.0).ceil
      [requested.to_i, by_module, 1].max
    end

    def self.kitchen_module_note(mod)
      {
        'sink' => 'Khoang chậu rửa, hậu hở kỹ thuật',
        'cooktop' => 'Khoang bếp, có thoáng khí',
        'oven' => 'Khoang lò, có khe thoát nhiệt',
        'drawer' => 'Khoang ngăn kéo phụ kiện',
        'dishwasher' => 'Khoang máy rửa bát',
        'corner_dead' => 'Góc L chết',
        'corner_45' => 'Góc L xéo 45',
        'dish_rack' => 'Khoang giá bát đĩa',
        'extractor' => 'Khoang máy hút mùi'
      }[mod] || 'Khoang tiêu chuẩn'
    end

    def self.build_drawer_bank(group, p, origin, size, count, cl)
      count = count.to_i
      return if count <= 0

      w, d, h = size
      t = (p['thickness'] || 17).to_f
      gap = (p['door_gap'] || 3).to_f
      face_t = 18.0
      usable_h = h - gap * (count + 1)
      return if usable_h <= 80.0 || w <= 120.0 || d <= 180.0

      face_h = usable_h / count.to_f
      count.times do |i|
        z = origin[2] + gap + i * (face_h + gap)
        face_origin = [origin[0] + gap, origin[1] - face_t - gap, z]
        face_size = [w - 2 * gap, face_t, face_h]
        panel(group, "Mặt ngăn kéo #{i + 1}", face_origin, face_size, {thickness: face_t, edge: 'Bo 4 cạnh 1mm'})
        Hardware.add_pull_handle(group.entities, face_origin, face_size, enabled: true, name: "Tay nắm NK #{i + 1}", horizontal: true)
        build_drawer_box(group, "Hộc kéo #{i + 1}", [origin[0], origin[1], z], [w, d, face_h], t, cl)
      end
      cl << cut_entry('Mặt ngăn kéo', count, w - 2 * gap, face_h, face_t, 'Bo 4 cạnh 1mm', 'Kèm tay nắm')
    end

    def self.build_wardrobe_front_trim(group, w, h, d, kick, t, comps, comp_w, cl)
      plinth_h = [kick, 90.0].max
      panel(group, 'Phào chân trước', [-12.0, -18.0, 0], [w + 24.0, 18.0, plinth_h], {thickness: 18, edge: 'Bo trên 1mm', note: 'Phào/chân tủ'})
      panel(group, 'Phào chân trái', [-12.0, 0, 0], [18.0, d, plinth_h], {thickness: 18, note: 'Phào hông chân'})
      panel(group, 'Phào chân phải', [w - 6.0, 0, 0], [18.0, d, plinth_h], {thickness: 18, note: 'Phào hông chân'})
      panel(group, 'Phào nóc trước', [-18.0, -20.0, h], [w + 36.0, 28.0, 60.0], {thickness: 18, edge: 'Bo cạnh', note: 'Phào nóc tủ'})
      panel(group, 'Phào nóc trái', [-18.0, 0, h], [28.0, d, 60.0], {thickness: 18, note: 'Phào nóc hông'})
      panel(group, 'Phào nóc phải', [w - 10.0, 0, h], [28.0, d, 60.0], {thickness: 18, note: 'Phào nóc hông'})

      nẹp_w = 28.0
      panel(group, 'Nẹp đứng mặt tiền trái', [-nẹp_w, -16.0, kick], [nẹp_w, 18.0, h - kick], {thickness: 18, edge: 'Bo cạnh', note: 'Nẹp mặt tiền'})
      panel(group, 'Nẹp đứng mặt tiền phải', [w, -16.0, kick], [nẹp_w, 18.0, h - kick], {thickness: 18, edge: 'Bo cạnh', note: 'Nẹp mặt tiền'})
      (comps - 1).times do |i|
        x = t + (i + 1)*comp_w + i*t - nẹp_w / 2.0
        panel(group, "Nẹp đứng chia cánh #{i + 1}", [x, -16.0, kick], [nẹp_w, 18.0, h - kick], {thickness: 18, edge: 'Bo cạnh', note: 'Che hồi giữa/chia cánh'})
      end

      foot_w = 70.0
      [[70.0, 55.0], [w - 140.0, 55.0], [70.0, d - 125.0], [w - 140.0, d - 125.0]].each_with_index do |(x, y), i|
        panel(group, "Chân tủ #{i + 1}", [x, y, 0], [foot_w, foot_w, plinth_h], {thickness: foot_w, note: 'Chân tủ nhìn thấy'})
      end

      cl << cut_entry('Phào chân', 3, w, plinth_h, 18, 'Bo trên 1mm')
      cl << cut_entry('Phào nóc', 3, w, 60, 18, 'Bo cạnh')
      cl << cut_entry('Nẹp đứng mặt tiền', comps + 1, h - kick, nẹp_w, 18, 'Bo cạnh')
    end

    def self.build_wardrobe_doors(group, p, w, h, d, base_z, comp_w, cl)
      doors = (p['doors'] || 0).to_i
      return if doors <= 0

      gap = (p['door_gap'] || 3).to_f
      t = (p['thickness'] || 17).to_f
      door_h = h - gap * 2
      door_w = (w - gap * (doors + 1)) / doors.to_f

      if p['wardrobe_open_view'] != false
        doors.times do |i|
          x_closed = gap + i * (door_w + gap)
          hinge_left = i.even?
          x = hinge_left ? x_closed : x_closed + door_w - t
          y = -door_w - 80.0
          name = doors == 1 ? 'Cánh mở' : "Cánh mở #{i + 1}"
          panel(group, name, [x, y, base_z + gap], [t, door_w, door_h], {thickness: t, edge: 'Bo 4 cạnh 1mm', note: 'Mở 90 độ để xem kết cấu trong tủ'})
          Hardware.add_pull_handle(group.entities, [x, y, base_z + gap], [t, door_w, door_h], enabled: true, name: "Tay nắm #{name}", horizontal: false)
          if p['hinges']
            Hardware.add_hinge_cup_markers(group.entities, [x, y, base_z + gap], [t, door_w, door_h], enabled: true)
          end
        end
      else
        build_doors(group, p, w, h, d, base_z, cl)
        return
      end

      cl << cut_entry('Cánh', doors, door_h, door_w, t, 'Bo 4 cạnh 1mm', 'Hiển thị mở 90 độ')
    end

    def self.build_back_panel(group, p, w, h, t, kick, cl)
      has_back = p['has_back'] != false
      return unless has_back

      tb = (p['back_thickness']||5).to_f
      btype = p['back_type'] || 'flush'
      inset = (p['back_inset']||15).to_f
      groove = (p['back_groove']||8).to_f

      # d is passed from outside, need to grab it
      d = p['depth'].to_f

      if btype == 'dado'
        # Hậu rãnh
        b_w = w - 2*t + 2*groove
        b_h = h - kick - 2*t + 2*groove
        b_x = t - groove
        b_y = d - inset - tb
        b_z = kick + t - groove
        panel(group, 'Hậu (Rãnh)', [b_x, b_y, b_z], [b_w, tb, b_h], {thickness: tb})
        panel(group, 'Dấu rãnh hậu trái', [0, b_y, b_z], [t, tb, b_h], {thickness: tb, note: "Rãnh hậu #{groove}mm"})
        panel(group, 'Dấu rãnh hậu phải', [w - t, b_y, b_z], [t, tb, b_h], {thickness: tb, note: "Rãnh hậu #{groove}mm"})
        panel(group, 'Dấu rãnh hậu đáy', [b_x, b_y, kick], [b_w, tb, t], {thickness: tb, note: "Rãnh hậu #{groove}mm"})
        panel(group, 'Dấu rãnh hậu nóc', [b_x, b_y, h - t], [b_w, tb, t], {thickness: tb, note: "Rãnh hậu #{groove}mm"})
        cl << cut_entry('Hậu', 1, b_w, b_h, tb, "Đánh rãnh #{groove}mm")
      else
        # Hậu áp
        panel(group, 'Hậu (Áp)', [t, d - tb, kick + t], [w - 2*t, tb, h - kick - 2*t], {thickness: tb})
        cl << cut_entry('Hậu', 1, w - 2*t, h - kick - 2*t, tb, '')
      end
    end

    def self.build_base_cabinet(group, p)
      w = p['width'].to_f;  h = p['height'].to_f;  d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      kick = (p['kickboard']||80).to_f
      shelves = (p['shelves']||1).to_i
      comps = auto_kitchen_compartments(w, t, (p['compartments']||1).to_i)
      drawers = (p['drawers'] || 0).to_i
      mod = p['kitchen_module'] || 'standard'
      sys32 = p['sys32'] == true
      inner_w = w - 2*t
      inner_d = internal_depth(p, d)
      body_z = kick
      body_h = h - kick
      comp_w = (inner_w - (comps - 1)*t) / comps.to_f
      open_technical_back = ['sink', 'cooktop', 'oven', 'dishwasher'].include?(mod)
      cl = []
      
      panel(group, 'Hồi ngoài trái tủ dưới',  [0, 0, body_z], [t, d, body_h], {thickness: t, edge: 'Trước 1mm', note: 'Chịu tải mặt đá'})
      panel(group, 'Hồi ngoài phải tủ dưới',  [w - t, 0, body_z], [t, d, body_h], {thickness: t, edge: 'Trước 1mm', note: 'Chịu tải mặt đá'})
      cl << cut_entry('Hồi ngoài tủ dưới', 2, body_h, d, t, 'Trước 1mm', 'Chịu lực mặt đá')

      if sys32
        Hardware.add_system_32_holes(group.entities, [0, 0, body_z + t], [t, d, body_h - t], enabled: true, direction: 1)
        Hardware.add_system_32_holes(group.entities, [w - t, 0, body_z + t], [t, d, body_h - t], enabled: true, direction: -1)
      end

      if mod == 'dishwasher'
        panel(group, 'Giằng trên trước', [t, 0, h - t], [inner_w, 100, t], {thickness: t, note: 'Đỡ mặt đá'})
        panel(group, 'Giằng trên sau',   [t, d - 100, h - t], [inner_w, 100, t], {thickness: t, note: 'Đỡ mặt đá'})
        panel(group, 'Đố giữ máy rửa bát trái', [t, 0, body_z], [t, d, body_h], {thickness: t, note: 'Khoang thiết bị'})
        panel(group, 'Đố giữ máy rửa bát phải', [w - 2*t, 0, body_z], [t, d, body_h], {thickness: t, note: 'Khoang thiết bị'})
        panel(group, 'Chân âm máy rửa bát', [t, 50, 0], [inner_w, t, kick], {thickness: t, edge: 'Trên 1mm'})
        panel(group, 'Mặt đá bếp', [-20, -20, h], [w + 40, d + 40, 20], {thickness: 20, edge: 'Bo cạnh đá', note: 'Mặt đá 18-20mm'})
        Hardware.add_adjustable_feet(group.entities, w, d, kick, t, enabled: true)
        Hardware.add_carcass_joint_markers(group.entities, [t, w - t], d, kick + t, h - t, enabled: p['cams'] != false)
        cl << cut_entry('Giằng trên', 2, inner_w, 100, t, '', 'Khoang máy rửa bát')
        cl << cut_entry('Chân âm', 1, inner_w, kick, t, 'Trên 1mm', 'Khoang máy rửa bát')
        return cl
      end

      panel(group, 'Đáy tủ dưới', [t, 0, kick], [inner_w, d, t], {thickness: t, edge: 'Trước 1mm', note: 'Đáy liền chịu lực nồi chảo'})
      cl << cut_entry('Đáy tủ dưới', 1, inner_w, d, t, 'Trước 1mm', 'Đáy liền')

      panel(group, 'Giằng mặt đá trước', [t, 0, h - t], [inner_w, 90, t], {thickness: t, note: 'Đỡ mặt đá, giữ vuông tủ'})
      panel(group, 'Giằng mặt đá sau',   [t, d - 90, h - t], [inner_w, 90, t], {thickness: t, note: 'Đỡ mặt đá, giữ vuông tủ'})
      cl << cut_entry('Giằng mặt đá', 2, inner_w, 90, t, '', 'Tủ dưới không dùng nóc kín')

      if open_technical_back
        panel(group, 'Giằng hậu kỹ thuật trên', [t, d - 80, h - 170], [inner_w, t, 90], {thickness: t, note: kitchen_module_note(mod)})
        panel(group, 'Giằng hậu kỹ thuật dưới', [t, d - 80, kick + t], [inner_w, t, 90], {thickness: t, note: 'Hậu hở đi điện nước'})
        cl << cut_entry('Giằng hậu kỹ thuật', 2, inner_w, 90, t, '', kitchen_module_note(mod))
      else
        build_back_panel(group, p, w, h, t, kick, cl)
      end

      panel(group, 'Chân âm trước', [t, 50, 0], [inner_w, t, kick], {thickness: t, edge: 'Trên 1mm'})
      panel(group, 'Chân âm sau', [t, d - 70, 0], [inner_w, t, kick], {thickness: t})
      cl << cut_entry('Chân âm', 2, inner_w, kick, t, 'Trên 1mm', 'Chống ẩm sàn')
      Hardware.add_adjustable_feet(group.entities, w, d, kick, t, enabled: true)

      joint_x = [t]
      if comps > 1
        (comps - 1).times do |i|
          x = t + (i + 1)*comp_w + i*t
          panel(group, "Hồi giữa tủ dưới #{i + 1}", [x, 0, kick + t], [t, d, h - kick - 2*t], {thickness: t, edge: 'Trước 1mm', note: 'Chia module 600-800, đỡ mặt đá'})
          joint_x << x
          if sys32
            Hardware.add_system_32_holes(group.entities, [x, 0, kick + t], [t, d, h - kick - 2*t], enabled: true, direction: 1)
            Hardware.add_system_32_holes(group.entities, [x, 0, kick + t], [t, d, h - kick - 2*t], enabled: true, direction: -1)
          end
        end
        cl << cut_entry('Hồi giữa tủ dưới', comps - 1, h - kick - 2*t, d, t, 'Trước 1mm', 'Chia khoang, đỡ thiết bị')
      end
      joint_x << (w - t)
      Hardware.add_carcass_joint_markers(group.entities, joint_x, d, kick + t, h - t, enabled: p['cams'] != false)

      if shelves > 0 && !['sink', 'oven', 'dishwasher', 'corner_dead', 'corner_45'].include?(mod)
        step_h = (h - kick - 2*t) / (shelves + 1).to_f
        comps.times do |c|
          x = t + c*(comp_w + t)
          shelves.times do |i|
            z = kick + t + step_h * (i + 1)
            panel(group, "Đợt tủ dưới khoang #{c + 1}.#{i + 1}", [x, 0, z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'Trước 1mm'})
          end
        end
        cl << cut_entry('Đợt tủ dưới', comps * shelves, comp_w, inner_d - 20, t, 'Trước 1mm', 'Để đồ khô')
      end

      if drawers > 0 || mod == 'drawer'
        drawer_count = drawers > 0 ? drawers : 3
        build_drawer_bank(group, p, [t, 0, kick + t], [comp_w, inner_d, h - kick - 2*t], drawer_count, cl)
      end

      if mod == 'sink'
        panel(group, 'Chậu rửa âm mặt đá', [t + 80, 110, h + 2], [comp_w - 160, 420, 18], {thickness: 18, note: 'Khoét chậu rửa'})
        panel(group, 'Ống kỹ thuật chậu rửa', [t + comp_w/2.0 - 25, d - 120, kick + 80], [50, 50, h - kick - 180], {thickness: 50, note: 'Đường nước/xả'})
      elsif mod == 'cooktop'
        panel(group, 'Bếp từ/bếp gas âm', [t + 80, 130, h + 2], [comp_w - 160, 380, 12], {thickness: 12, note: 'Khoét bếp, thoáng khí'})
        panel(group, 'Khe thoáng bếp', [t + 40, d - 40, h - 230], [comp_w - 80, 12, 80], {thickness: 12, note: 'Thoát nhiệt'})
      elsif mod == 'oven'
        panel(group, 'Mặt lò nướng', [t + 30, -18, kick + 140], [comp_w - 60, 18, 460], {thickness: 18, note: 'Module lò âm'})
        panel(group, 'Khe thoát nhiệt lò', [t + 60, -22, kick + 630], [comp_w - 120, 12, 35], {thickness: 12, note: 'Thoát nhiệt'})
      elsif mod == 'corner_dead'
        panel(group, 'Tấm góc chết chữ L', [w - comp_w - t, d - comp_w, kick + t], [comp_w, comp_w, t], {thickness: t, note: 'Góc L chết lưu trữ sâu'})
      elsif mod == 'corner_45'
        panel(group, 'Đố góc xéo 45', [w - comp_w, d - 80, kick + t], [comp_w, 80, h - kick - 2*t], {thickness: t, note: 'Mô phỏng góc xéo 45'})
      end

      panel(group, 'Mặt đá bếp', [-20, -20, h], [w + 40, d + 40, 20], {thickness: 20, edge: 'Bo cạnh đá', note: 'Mặt đá 18-20mm'})
      
      build_doors(group, p, w, h - kick, d, kick, cl) unless drawers > 0 || ['drawer', 'oven', 'dishwasher'].include?(mod)
      cl
    end

    def self.build_wall_cabinet(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      shelves = (p['shelves']||1).to_i
      comps = auto_kitchen_compartments(w, t, (p['compartments']||1).to_i)
      mod = p['kitchen_module'] || 'standard'
      sys32 = p['sys32'] == true
      inner_w = w - 2*t
      inner_d = internal_depth(p, d)
      comp_w = (inner_w - (comps - 1)*t) / comps.to_f
      cl = []
      panel(group, 'Hồi ngoài trái tủ trên',  [0, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm', note: 'Tủ treo tường'})
      panel(group, 'Hồi ngoài phải tủ trên',  [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm', note: 'Tủ treo tường'})
      cl << cut_entry('Hồi ngoài tủ trên', 2, h, d, t, 'Trước 1mm', 'Tủ treo nhẹ hơn tủ dưới')

      if sys32
        Hardware.add_system_32_holes(group.entities, [0, 0, 0], [t, d, h], enabled: true, direction: 1)
        Hardware.add_system_32_holes(group.entities, [w - t, 0, 0], [t, d, h], enabled: true, direction: -1)
      end

      if mod == 'extractor'
        panel(group, 'Nóc tủ hút mùi', [t, 0, h - t], [inner_w, d, t], {thickness: t, edge: 'Trước 1mm'})
        panel(group, 'Đáy che ống hút mùi', [t, 0, 150], [inner_w, d, t], {thickness: t, edge: 'Trước 1mm'})
        panel(group, 'Ống hút mùi', [w/2.0 - 75, d - 120, 150 + t], [150, 120, h - 2*t - 150], {thickness: 18, note: 'Khoang máy hút mùi'})
        cl << cut_entry('Nóc/đáy che hút mùi', 2, inner_w, d, t, 'Trước 1mm', 'Khoét ống hút')
      else
        panel(group, 'Đáy tủ trên', [t, 0, 0], [inner_w, d, t], {thickness: t, edge: 'Trước 1mm'})
        panel(group, 'Nóc tủ trên', [t, 0, h - t], [inner_w, d, t], {thickness: t, edge: 'Trước 1mm'})
        cl << cut_entry('Đáy/Nóc tủ trên', 2, inner_w, d, t, 'Trước 1mm')
      end

      build_back_panel(group, p, w, h, t, 0, cl)

      joint_x = [t]
      if comps > 1
        (comps - 1).times do |i|
          x = t + (i + 1)*comp_w + i*t
          panel(group, "Hồi giữa tủ trên #{i + 1}", [x, 0, t], [t, d, h - 2*t], {thickness: t, edge: 'Trước 1mm', note: 'Chia module tủ treo'})
          joint_x << x
        end
        cl << cut_entry('Hồi giữa tủ trên', comps - 1, h - 2*t, d, t, 'Trước 1mm')
      end
      joint_x << (w - t)
      Hardware.add_carcass_joint_markers(group.entities, joint_x, d, t, h - t, enabled: p['cams'] != false)

      if shelves > 0 && mod != 'extractor'
        step_h = (h - 2*t) / (shelves + 1).to_f
        comps.times do |c|
          x = t + c*(comp_w + t)
          shelves.times do |i|
            z = t + step_h * (i + 1)
            panel(group, "Đợt tủ trên khoang #{c + 1}.#{i + 1}", [x, 0, z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'Trước 1mm'})
          end
        end
        cl << cut_entry('Đợt tủ trên', comps * shelves, comp_w, inner_d - 20, t, 'Trước 1mm')
      end

      panel(group, 'Bas treo tường trái', [t + 20, d - 25, h - 90], [90, 12, 45], {thickness: 12, note: 'Bas treo/vít tường'})
      panel(group, 'Bas treo tường phải', [w - t - 110, d - 25, h - 90], [90, 12, 45], {thickness: 12, note: 'Bas treo/vít tường'})

      if mod == 'dish_rack'
        panel(group, 'Giá bát đĩa inox', [t + 40, 45, 120], [inner_w - 80, d - 90, 18], {thickness: 18, note: 'Giá bát đĩa cố định'})
        panel(group, 'Khay hứng nước', [t + 40, 45, 70], [inner_w - 80, d - 90, 12], {thickness: 12, note: 'Khay hứng nước giá bát'})
      end

      build_doors(group, p, w, h, d, 0, cl)
      cl
    end

    def self.build_wardrobe(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      kick = (p['kickboard']||80).to_f
      shelves = (p['shelves']||3).to_i
      requested_comps = (p['compartments']||2).to_i
      comps = auto_structural_compartments(w, t, requested_comps)
      drawers = (p['drawers'] || 0).to_i
      sys32 = p['sys32'] == true
      cl = []
      inner_w = w - 2*t
      inner_d = internal_depth(p, d)
      structural_d = d
      body_z = kick + t
      body_h = h - kick - 2*t
      body_top = h - t
      comp_w = (inner_w - (comps - 1)*t) / comps.to_f
      drawer_h = drawers > 0 ? [[body_h * 0.28, drawers * 150.0].max, body_h * 0.45].min : 0.0
      shelf_zone_z = body_z + drawer_h
      shelf_zone_h = body_h - drawer_h
      
      panel(group, 'Hồi ngoài trái', [0, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm', note: 'Bao biên ngoài tủ'})
      panel(group, 'Hồi ngoài phải', [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm', note: 'Bao biên ngoài tủ'})
      cl << cut_entry('Hồi ngoài trái/phải', 2, h, d, t, 'Trước 1mm', 'Full cao, chịu lực tổng')
      
      if sys32
        Hardware.add_system_32_holes(group.entities, [0, 0, body_z], [t, structural_d, body_h], enabled: true, direction: 1)
        Hardware.add_system_32_holes(group.entities, [w - t, 0, body_z], [t, structural_d, body_h], enabled: true, direction: -1)
      end

      panel(group, 'Đáy tủ', [t, 0, kick], [inner_w, d, t], {thickness: t, edge: 'Trước 1mm', note: 'Lọt giữa hai hồi ngoài'})
      panel(group, 'Nóc tủ', [t, 0, h - t], [inner_w, d, t], {thickness: t, edge: 'Trước 1mm', note: 'Lọt giữa hai hồi ngoài'})
      cl << cut_entry('Đáy/Nóc', 2, inner_w, d, t, 'Trước 1mm', 'Lọt giữa hồi ngoài')
      
      panel(group, 'Chân âm trước', [t, 50, 0], [inner_w, t, kick], {thickness: t, edge: 'Trên 1mm'})
      panel(group, 'Chân âm sau', [t, d - 70, 0], [inner_w, t, kick], {thickness: t})
      cl << cut_entry('Chân âm', 2, inner_w, kick, t, 'Trên 1mm')
      Hardware.add_adjustable_feet(group.entities, w, d, kick, t, enabled: true)
      build_wardrobe_front_trim(group, w, h, d, kick, t, comps, comp_w, cl)

      build_back_panel(group, p, w, h, t, kick, cl)

      if comps > 1
        (comps - 1).times do |i|
          x = t + (i + 1)*comp_w + i*t
          panel(group, "Hồi giữa #{i + 1}", [x, 0, body_z], [t, structural_d, body_h], {thickness: t, edge: 'Trước 1mm', note: 'Vách đứng chia khoang full cao'})
          if sys32
            Hardware.add_system_32_holes(group.entities, [x, 0, body_z], [t, structural_d, body_h], enabled: true, direction: 1)
            Hardware.add_system_32_holes(group.entities, [x, 0, body_z], [t, structural_d, body_h], enabled: true, direction: -1)
          end
        end
        cl << cut_entry('Hồi giữa / vách đứng', comps - 1, body_h, structural_d, t, 'Trước 1mm', 'Full cao, chia khoang và chống võng')
      end

      joint_x = [t]
      (comps - 1).times { |i| joint_x << (t + (i + 1)*comp_w + i*t) }
      joint_x << (w - t)
      Hardware.add_wardrobe_joint_markers(group.entities, joint_x, structural_d, body_z, body_top, enabled: p['cams'] != false)

      fixed_shelf_z = [h - 420.0, shelf_zone_z + 260.0].max
      fixed_shelf_z = body_top - 260.0 if fixed_shelf_z > body_top - 180.0
      if fixed_shelf_z > shelf_zone_z + 120.0
        comps.times do |c|
          x = t + c*(comp_w + t)
          panel(group, "Đợt cố định khoang #{c + 1}", [x, 0, fixed_shelf_z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'Trước 1mm', note: 'Đợt cố định khóa khoang'})
        end
        cl << cut_entry('Đợt cố định tủ áo', comps, comp_w, inner_d - 20, t, 'Trước 1mm', 'Khóa khoang, tăng cứng')
      end

      mobile_shelves = [shelves - 1, 0].max
      if mobile_shelves > 0 && shelf_zone_h > 180.0
        usable_top = fixed_shelf_z - 60.0
        usable_h = usable_top - shelf_zone_z
        max_shelves = [(usable_h / 220.0).floor, mobile_shelves].min
        if max_shelves > 0
          step_h = usable_h / (max_shelves + 1).to_f
          comps.times do |c|
            x = t + c*(comp_w + t)
            max_shelves.times do |i|
              z = shelf_zone_z + step_h * (i + 1)
              panel(group, "Đợt di động khoang #{c + 1}.#{i + 1}", [x, 0, z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'Trước 1mm', note: 'Đợt di động trên lỗ System 32'})
            end
          end
          cl << cut_entry('Đợt di động tủ áo', comps * max_shelves, comp_w, inner_d - 20, t, 'Trước 1mm', 'Nhịp đợt không vượt 800mm')
        end
      end

      long_hanging = h >= 2200.0
      rod_z = long_hanging ? [body_z + 1550.0, fixed_shelf_z - 90.0].min : [body_z + 1050.0, fixed_shelf_z - 90.0].min
      if rod_z > shelf_zone_z + 180.0 && comp_w > 120.0
        comps.times do |c|
          x = t + c*(comp_w + t) + 40.0
          panel(group, "Suốt treo khoang #{c + 1}", [x, inner_d * 0.52, rod_z], [comp_w - 80.0, 25.0, 25.0], {thickness: 25, note: long_hanging ? 'Suốt treo áo dài 1400-1600mm' : 'Suốt treo áo ngắn 900-1100mm'})
        end
      end

      if p['wardrobe_led'] == true && comp_w > 160.0
        comps.times do |c|
          x = t + c*(comp_w + t) + 40.0
          panel(group, "LED cảm biến khoang #{c + 1}", [x, 18.0, body_top - 35.0], [comp_w - 80.0, 12.0, 12.0], {thickness: 12, note: 'LED cảm biến tủ áo'})
        end
      end

      if drawers > 0
        build_drawer_bank(group, p, [t, t + 20.0, body_z], [comp_w, inner_d - t - 20.0, drawer_h], drawers, cl)
      end

      build_wardrobe_doors(group, p, w, h - kick, d, kick, comp_w, cl)
      cl
    end

    def self.build_inner_compartments(group, p, w, h, d, base_z, t, comps, shelves, cl, has_top, sys32)
      return if comps < 1
      has_back = p['has_back'] != false
      btype = p['back_type'] || 'flush'
      tb = (p['back_thickness']||5).to_f
      inset = (p['back_inset']||15).to_f

      inner_w = w - 2*t
      inner_d = has_back ? (btype == 'dado' ? d - inset : d - tb) : d
      inner_h = has_top ? h - 2*t : h - t
      
      comp_w = (inner_w - (comps - 1)*t) / comps.to_f
      
      # Vách chia
      if comps > 1
        (comps - 1).times do |i|
          x = t + (i + 1)*comp_w + i*t
          panel(group, "Vách chia #{i+1}", [x, 0, base_z + t], [t, inner_d, inner_h], {thickness: t, edge: 'Trước 1mm'})
          if sys32
            Hardware.add_system_32_holes(group.entities, [x, 0, base_z + t], [t, inner_d, inner_h], enabled: true, direction: 1)
            Hardware.add_system_32_holes(group.entities, [x, 0, base_z + t], [t, inner_d, inner_h], enabled: true, direction: -1)
          end
        end
        cl << cut_entry('Vách chia', comps - 1, inner_h, inner_d, t, 'Trước 1mm')
      end

      # Đợt
      if shelves > 0
        step_h = inner_h / (shelves + 1).to_f
        comps.times do |c|
          x = t + c*(comp_w + t)
          shelves.times do |i|
            z = base_z + t + step_h * (i + 1)
            # Rút ngắn đợt 20mm để thụt vào
            panel(group, "Đợt khoang #{c+1} đợt #{i+1}", [x, 0, z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'Trước 1mm'})
          end
        end
        cl << cut_entry('Đợt', comps * shelves, comp_w, inner_d - 20, t, 'Trước 1mm')
      end
    end

    def self.build_bed(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      btype = p['bed_type'] || 'standard'
      
      head_h = h
      side_h = (p['bed_side_h'] || 350).to_f
      drawers = (p['bed_drawers'] || 0).to_i
      top_m = (p['bed_top_margin'] || 400).to_f
      mid_m = (p['bed_mid_margin'] || 100).to_f
      bot_m = (p['bed_bot_margin'] || 200).to_f
      runner = (p['bed_runner'] || 500).to_f

      cl = []
      
      # Đầu giường (Phủ ra ngoài cùng)
      panel(group, 'Đầu giường', [0, 0, 0], [w, t, head_h], {thickness: t, edge: 'Trên 1mm'})
      cl << cut_entry('Đầu giường', 1, w, head_h, t, 'Trên 1mm')

      if btype == 'floating'
        base_h = 150.0
        inset_b = 150.0
        # Bệ thụt
        panel(group, 'Vai bệ trái', [inset_b, inset_b, 0], [t, d - inset_b*2, base_h], {thickness: t})
        panel(group, 'Vai bệ phải', [w - inset_b - t, inset_b, 0], [t, d - inset_b*2, base_h], {thickness: t})
        panel(group, 'Thang bệ trước', [inset_b + t, inset_b, 0], [w - inset_b*2 - 2*t, t, base_h], {thickness: t})
        panel(group, 'Thang bệ sau', [inset_b + t, d - inset_b - t, 0], [w - inset_b*2 - 2*t, t, base_h], {thickness: t})
        
        cl << cut_entry('Vai bệ', 2, d - inset_b*2, base_h, t, '')
        cl << cut_entry('Thang bệ', 2, w - inset_b*2 - 2*t, base_h, t, '')

        # Vai giường lơ lửng
        panel(group, 'Vai giường trái',  [0, t, base_h], [t, d - t, side_h - base_h], {thickness: t, edge: 'Trên 1mm'})
        panel(group, 'Vai giường phải',  [w - t, t, base_h], [t, d - t, side_h - base_h], {thickness: t, edge: 'Trên 1mm'})
        # Đuôi giường lọt trong vai
        panel(group, 'Đuôi giường', [t, d - t, base_h], [w - 2*t, t, side_h - base_h], {thickness: t, edge: 'Trên 1mm'})
        
        cl << cut_entry('Vai giường', 2, d - t, side_h - base_h, t, 'Trên 1mm')
        cl << cut_entry('Đuôi giường', 1, w - 2*t, side_h - base_h, t, 'Trên 1mm')
        
        grid_base_z = base_h
        grid_h = side_h - base_h - t
      else
        # GIƯỜNG THƯỜNG / GIƯỜNG NGĂN KÉO
        panel(group, 'Vai giường phải',  [w - t, t, 0], [t, d - t, side_h], {thickness: t, edge: 'Trên 1mm'})
        cl << cut_entry('Vai giường', 1, d - t, side_h, t, 'Trên 1mm')

        if drawers > 0
          # Vai trái là vai có ngăn kéo (vẽ ghép từ các đoạn để tạo lỗ, xuất cutlist là 1 tấm nguyên)
          dr_w = (d - t - top_m - bot_m - (drawers - 1) * mid_m) / drawers.to_f
          
          # Vẽ các đoạn Bản để tạo hiệu ứng 3D có lỗ
          panel(group, 'Bản đầu (Vai trái)', [0, t, 0], [t, top_m, side_h], {thickness: t})
          panel(group, 'Bản cuối (Vai trái)', [0, d - bot_m, 0], [t, bot_m, side_h], {thickness: t})
          if drawers > 1
            (drawers - 1).times do |i|
              y_mid = t + top_m + dr_w + i*(dr_w + mid_m)
              panel(group, "Bản giữa #{i+1} (Vai trái)", [0, y_mid, 0], [t, mid_m, side_h], {thickness: t})
            end
          end
          # Nẹp trên/dưới lỗ
          panel(group, 'Xà trên lỗ NK', [0, t + top_m, side_h - 40], [t, d - t - top_m - bot_m, 40], {thickness: t})
          panel(group, 'Xà dưới lỗ NK', [0, t + top_m, 0], [t, d - t - top_m - bot_m, 40], {thickness: t})

          cl << cut_entry('Vai giường (khoét lổ NK)', 1, d - t, side_h, t, 'Khoét lổ CNC')
        else
          panel(group, 'Vai giường trái',  [0, t, 0], [t, d - t, side_h], {thickness: t, edge: 'Trên 1mm'})
          cl << cut_entry('Vai giường', 1, d - t, side_h, t, 'Trên 1mm')
        end

        # Đuôi giường lọt trong vai
        panel(group, 'Đuôi giường', [t, d - t, 0], [w - 2*t, t, side_h], {thickness: t, edge: 'Trên 1mm'})
        cl << cut_entry('Đuôi giường', 1, w - 2*t, side_h, t, 'Trên 1mm')
        
        grid_base_z = 0
        grid_h = side_h - t
      end

      # KHUNG XƯƠNG
      inner_w = w - 2*t
      inner_d = d - 2*t

      if drawers > 0
        # GIƯỜNG CÓ NGĂN KÉO
        # Thang dọc ngăn kéo (Hậu của ngăn kéo)
        x_runner = t + runner
        panel(group, 'Thang dọc đỡ NK', [x_runner, t, grid_base_z], [t, inner_d, grid_h], {thickness: t})
        cl << cut_entry('Thang dọc đỡ NK', 1, inner_d, grid_h, t, '')
        
        # Thang dọc còn lại (chia đều phần không gian trống bên phải)
        rem_w = inner_w - runner - t
        x_mid = x_runner + t + rem_w/2.0
        panel(group, 'Thang dọc xương', [x_mid, t, grid_base_z], [t, inner_d, grid_h], {thickness: t})
        cl << cut_entry('Thang dọc xương', 1, inner_d, grid_h, t, '')

        # Vách ngang chia NK
        dr_w = (d - t - top_m - bot_m - (drawers - 1) * mid_m) / drawers.to_f
        y_pos = t + top_m
        drawers.times do |i|
          # Tạo hộp ngăn kéo
          build_drawer_box(group, "Hộc #{i+1}", [t, y_pos, grid_base_z], [runner, dr_w, grid_h - 20], t, cl)
          # Mặt ngăn kéo (lọt vào trong lỗ)
          panel(group, "Mặt NK #{i+1}", [t, y_pos + 2, grid_base_z + 42], [t, dr_w - 4, grid_h - 84], {thickness: t})
          Hardware.add_pull_handle(group.entities, [t, y_pos + 2, grid_base_z + 42], [t, dr_w - 4, grid_h - 84], enabled: true, name: "Tay nắm NK giường #{i+1}", horizontal: false)
          cl << cut_entry('Mặt ngăn kéo', 1, dr_w - 4, grid_h - 84, t, 'Bo 4 cạnh')

          # Vách ngang (Thang ngang) ôm 2 bên NK
          panel(group, "Vách ngang NK #{i+1} trước", [t, y_pos - t, grid_base_z], [runner, t, grid_h], {thickness: t})
          panel(group, "Vách ngang NK #{i+1} sau", [t, y_pos + dr_w, grid_base_z], [runner, t, grid_h], {thickness: t})
          
          y_pos += dr_w + mid_m
        end
        cl << cut_entry('Vách ngang ngăn kéo', drawers * 2, runner, grid_h, t, '')

      else
        # GIƯỜNG THƯỜNG ĐAN LƯỚI
        num_long = 2
        num_lat = 2 # 2 hàng ngang tạo thành 3 khoang
        
        comp_w = (inner_w - num_long*t) / (num_long + 1).to_f
        comp_d = (inner_d - num_lat*t) / (num_lat + 1).to_f
        
        # Thang dọc (nguyên tấm)
        num_long.times do |i|
          x = t + comp_w*(i+1) + t*i
          panel(group, "Thang dọc xương #{i+1}", [x, t, grid_base_z], [t, inner_d, grid_h], {thickness: t})
        end
        cl << cut_entry('Thang dọc xương', num_long, inner_d, grid_h, t, '')

        # Thang ngang (Cắt thành các đoạn nhỏ nhét giữa thang dọc)
        num_lat.times do |row|
          y = t + comp_d*(row+1) + t*row
          (num_long + 1).times do |col|
            x = t + comp_w*col + t*col
            panel(group, "Thang ngang xương", [x, y, grid_base_z], [comp_w, t, grid_h], {thickness: t})
          end
        end
        cl << cut_entry('Thang ngang xương', num_lat * (num_long + 1), comp_w, grid_h, t, '')
      end

      # MẶT PHẢN GIƯỜNG (Chia 4 tấm dấu thập)
      panel(group, 'Mặt phản Trái Trước', [t, t, side_h - t], [inner_w/2.0, inner_d/2.0, t], {thickness: t})
      panel(group, 'Mặt phản Phải Trước', [t + inner_w/2.0, t, side_h - t], [inner_w/2.0, inner_d/2.0, t], {thickness: t})
      panel(group, 'Mặt phản Trái Sau', [t, t + inner_d/2.0, side_h - t], [inner_w/2.0, inner_d/2.0, t], {thickness: t})
      panel(group, 'Mặt phản Phải Sau', [t + inner_w/2.0, t + inner_d/2.0, side_h - t], [inner_w/2.0, inner_d/2.0, t], {thickness: t})
      cl << cut_entry('Mặt phản', 4, inner_w/2.0, inner_d/2.0, t, 'Trải phủ gầm')

      cl
    end

    def self.build_desk(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      cl = []
      panel(group, 'Mặt bàn', [0, 0, h - t], [w, d, t], {thickness: t, edge: 'Trước+trái+phải 1mm'})
      cl << cut_entry('Mặt bàn', 1, w, d, t, 'Trước+trái+phải 1mm')
      panel(group, 'Hồi trái', [0, 0, 0], [t, d, h - t], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Hồi phải', [w - t, 0, 0], [t, d, h - t], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Hồi trái/phải', 2, h - t, d, t, 'Trước 1mm')
      panel(group, 'Giằng sau', [t, d - t, h - t - 200], [w - 2*t, t, 200], {thickness: t})
      cl << cut_entry('Giằng sau', 1, w - 2*t, 200, t, '')
      cl
    end

    def self.build_drawer_box(group, name, origin, size, thickness, cl)
      w, d, h = size
      t = thickness
      slide_gap = 13.0
      box_w = w - 2 * slide_gap
      box_d = d - 20 
      box_h = h - 40 

      # Hồi hộc kéo
      panel(group, "#{name} Hồi trái", [origin[0] + slide_gap, origin[1] + 10, origin[2] + 20], [t, box_d, box_h], {thickness: t, edge: 'Trên 1mm'})
      panel(group, "#{name} Hồi phải", [origin[0] + w - slide_gap - t, origin[1] + 10, origin[2] + 20], [t, box_d, box_h], {thickness: t, edge: 'Trên 1mm'})
      cl << cut_entry("#{name} Hồi", 2, box_d, box_h, t, 'Trên 1mm')

      # Trán hộc / Lưng hộc
      front_back_w = box_w - 2*t
      panel(group, "#{name} Trán", [origin[0] + slide_gap + t, origin[1] + 10, origin[2] + 20], [front_back_w, t, box_h], {thickness: t, edge: 'Trên 1mm'})
      panel(group, "#{name} Lưng", [origin[0] + slide_gap + t, origin[1] + 10 + box_d - t, origin[2] + 20], [front_back_w, t, box_h], {thickness: t, edge: 'Trên 1mm'})
      cl << cut_entry("#{name} Trán/Lưng", 2, front_back_w, box_h, t, 'Trên 1mm')

      # Đáy hộc lọt gầm
      db_t = 5.0
      panel(group, "#{name} Đáy", [origin[0] + slide_gap + t, origin[1] + 10 + t, origin[2] + 20], [front_back_w, box_d - 2*t, db_t], {thickness: db_t})
      cl << cut_entry("#{name} Đáy", 1, front_back_w, box_d - 2*t, db_t, '')
      Hardware.add_drawer_slides(group.entities, origin, size, enabled: true)
    end

    def self.build_bedside_table(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      drawers = (p['drawers']||2).to_i
      cl = []
      panel(group, 'Hồi trái', [0, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Hồi phải', [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Hồi trái/phải', 2, h, d, t, 'Trước 1mm')
      panel(group, 'Đáy', [t, 0, 0], [w - 2*t, d, t], {thickness: t})
      panel(group, 'Nóc', [t, 0, h - t], [w - 2*t, d, t], {thickness: t, edge: 'Trước+trái+phải 1mm'})
      cl << cut_entry('Đáy', 1, w - 2*t, d, t, '')
      cl << cut_entry('Nóc', 1, w - 2*t, d, t, 'Trước+trái+phải 1mm')
      
      build_back_panel(group, p, w, h, t, 0, cl)

      if drawers > 0
        inner_h = h - 2*t
        face_h = (inner_h / drawers.to_f) - 3
        drawers.times do |i|
          z = t + i * (face_h + 3)
          # Mặt hộc kéo
          panel(group, "Mặt hộc kéo #{i+1}", [3, -18, z], [w - 6, 18, face_h], {thickness: 18, edge: 'Bo 4 cạnh 1mm'})
          Hardware.add_pull_handle(group.entities, [3, -18, z], [w - 6, 18, face_h], enabled: true, name: "Tay nắm hộc #{i+1}", horizontal: true)
          # Cấu tạo hộc kéo bên trong
          build_drawer_box(group, "Hộc #{i+1}", [t, 0, z], [w - 2*t, d, face_h], t, cl)
        end
        cl << cut_entry('Mặt hộc kéo', drawers, w - 6, face_h, 18, 'Bo 4 cạnh 1mm')
      end
      cl
    end

    def self.build_doors(group, p, w, h, d, base_z, cl)
      doors = (p['doors']||0).to_i
      return if doors <= 0
      gap = (p['door_gap']||3).to_f
      t = (p['thickness']||17).to_f
      dtype = p['door_type'] || 'overlay'
      
      if dtype == 'overlay'
        door_w = (w - gap * (doors + 1)) / doors.to_f
        door_h = h - gap * 2
        door_y = -t - gap
        door_z = base_z + gap
        base_x = gap
      elsif dtype == 'inset'
        inner_w = w - 2*t
        inner_h = h - 2*t
        door_w = (inner_w - gap * (doors + 1)) / doors.to_f
        door_h = inner_h - gap * 2
        door_y = 0
        door_z = base_z + t + gap
        base_x = t + gap
      elsif dtype == 'sliding'
        inner_w = w - 2*t
        inner_h = h - 2*t
        overlap = doors > 1 ? 30.0 : 0.0
        door_w = (inner_w + overlap) / doors.to_f
        door_h = inner_h - 10 # Trừ rãnh ray trượt
        door_y = 5
        door_z = base_z + t + 5
        base_x = t
        
        # Ray trượt nhôm
        panel(group, 'Ray nhôm trên', [t, 0, base_z + t + inner_h - 10], [inner_w, 60, 10], {thickness: 10})
        panel(group, 'Ray nhôm dưới', [t, 0, base_z + t], [inner_w, 60, 10], {thickness: 10})
        cl << cut_entry('Ray lùa', 2, inner_w, 60, 10, '')
      end

      doors.times do |i|
        if dtype == 'sliding'
          x = base_x + (doors > 1 ? i * (door_w - overlap / (doors - 1).to_f) : 0)
          y = i % 2 == 0 ? door_y + 35 : door_y + 5
        else
          x = base_x + i * (door_w + gap)
          y = door_y
        end

        name = doors == 1 ? 'Cánh' : (i == 0 ? 'Cánh trái' : (i == doors - 1 ? 'Cánh phải' : "Cánh #{i+1}"))
        inst = panel(group, name, [x, y, door_z], [door_w, t, door_h], {thickness: t, edge: 'Bo 4 cạnh 1mm'})
        Hardware.add_pull_handle(group.entities, [x, y, door_z], [door_w, t, door_h], enabled: true, name: "Tay nắm #{name}", horizontal: false)
        
        if p['hinges'] && dtype != 'sliding'
          Hardware.add_hinge_cup_markers(
            group.entities, [x, y, door_z], [door_w, t, door_h], enabled: true
          )
        end
      end
      cl << cut_entry('Cánh', doors, door_h, door_w, t, 'Bo 4 cạnh 1mm')
    end
  end
end
