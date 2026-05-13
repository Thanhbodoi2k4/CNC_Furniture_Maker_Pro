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
      comps = (p['compartments']||1).to_i
      mod = p['kitchen_module'] || 'standard'
      sys32 = p['sys32'] == true
      
      cl = []
      
      # Hồi
      panel(group, 'Hồi trái',  [0, 0, kick], [t, d, h - kick], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Hồi phải',  [w - t, 0, kick], [t, d, h - kick], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Hồi trái/phải', 2, h - kick, d, t, 'Trước 1mm')

      if sys32
        Hardware.add_system_32_holes(group.entities, [0, 0, kick], [t, d, h - kick], enabled: true, direction: 1)
        Hardware.add_system_32_holes(group.entities, [w - t, 0, kick], [t, d, h - kick], enabled: true, direction: -1)
      end

      if mod == 'dishwasher'
        panel(group, 'Giằng trên trước', [t, 0, h - t], [w - 2*t, 100, t], {thickness: t})
        panel(group, 'Giằng trên sau',   [t, d - 100, h - t], [w - 2*t, 100, t], {thickness: t})
        cl << cut_entry('Giằng trên', 2, w - 2*t, 100, t, '')
        return cl
      end

      # Đáy
      panel(group, 'Đáy', [t, 0, kick], [w - 2*t, d, t], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Đáy', 1, w - 2*t, d, t, 'Trước 1mm')

      # Giằng trên trước + sau
      panel(group, 'Giằng trên trước', [t, 0, h - t], [w - 2*t, 100, t], {thickness: t})
      panel(group, 'Giằng trên sau',   [t, d - 100, h - t], [w - 2*t, 100, t], {thickness: t})
      cl << cut_entry('Giằng trên', 2, w - 2*t, 100, t, '')

      build_back_panel(group, p, w, h, t, kick, cl)

      # Chân âm
      panel(group, 'Chân âm', [t, 50, 0], [w - 2*t, t, kick], {thickness: t})
      cl << cut_entry('Chân âm', 1, w - 2*t, kick, t, 'Trên 1mm')

      # Vách & Đợt
      build_inner_compartments(group, p, w, h - kick, d, kick, t, comps, shelves, cl, false, sys32)
      
      # Cánh
      build_doors(group, p, w, h - kick, d, kick, cl)
      cl
    end

    def self.build_wall_cabinet(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      shelves = (p['shelves']||1).to_i
      comps = (p['compartments']||1).to_i
      mod = p['kitchen_module'] || 'standard'
      sys32 = p['sys32'] == true
      
      cl = []
      panel(group, 'Hồi trái',  [0, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Hồi phải',  [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Hồi trái/phải', 2, h, d, t, 'Trước 1mm')

      if sys32
        Hardware.add_system_32_holes(group.entities, [0, 0, 0], [t, d, h], enabled: true, direction: 1)
        Hardware.add_system_32_holes(group.entities, [w - t, 0, 0], [t, d, h], enabled: true, direction: -1)
      end

      if mod == 'extractor'
        panel(group, 'Nóc', [t, 0, h - t], [w - 2*t, d, t], {thickness: t, edge: 'Trước 1mm'})
        cl << cut_entry('Nóc', 1, w - 2*t, d, t, 'Khoét lỗ hút mùi')
        panel(group, 'Đáy che ống', [t, 0, 150], [w - 2*t, d, t], {thickness: t, edge: 'Trước 1mm'})
        cl << cut_entry('Đáy che ống', 1, w - 2*t, d, t, 'Trước 1mm, khoét lỗ')
      else
        panel(group, 'Đáy', [t, 0, 0], [w - 2*t, d, t], {thickness: t, edge: 'Trước 1mm'})
        panel(group, 'Nóc', [t, 0, h - t], [w - 2*t, d, t], {thickness: t, edge: 'Trước 1mm'})
        cl << cut_entry('Đáy/Nóc', 2, w - 2*t, d, t, 'Trước 1mm')
      end

      build_back_panel(group, p, w, h, t, 0, cl)
      build_inner_compartments(group, p, w, h, d, 0, t, comps, shelves, cl, true, sys32)
      build_doors(group, p, w, h, d, 0, cl)
      cl
    end

    def self.build_wardrobe(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      kick = (p['kickboard']||80).to_f
      shelves = (p['shelves']||3).to_i
      comps = (p['compartments']||2).to_i
      sys32 = p['sys32'] == true
      cl = []
      
      panel(group, 'Hồi trái', [0, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Hồi phải', [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Hồi trái/phải', 2, h, d, t, 'Trước 1mm')
      
      if sys32
        Hardware.add_system_32_holes(group.entities, [0, 0, kick], [t, d, h], enabled: true, direction: 1)
        Hardware.add_system_32_holes(group.entities, [w - t, 0, kick], [t, d, h], enabled: true, direction: -1)
      end

      panel(group, 'Đáy', [t, 0, kick], [w - 2*t, d, t], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Nóc', [t, 0, h - t], [w - 2*t, d, t], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Đáy/Nóc', 2, w - 2*t, d, t, 'Trước 1mm')
      
      panel(group, 'Chân âm', [t, 50, 0], [w - 2*t, t, kick], {thickness: t})
      cl << cut_entry('Chân âm', 1, w - 2*t, kick, t, 'Trên 1mm')

      build_back_panel(group, p, w, h, t, kick, cl)

      build_inner_compartments(group, p, w, h - kick, d, kick, t, comps, shelves, cl, true, sys32)
      build_doors(group, p, w, h - kick, d, kick, cl)
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
      cl = []
      
      head_h = h
      side_h = h * 0.45
      
      # Đầu giường
      panel(group, 'Đầu giường', [0, 0, 0], [w, t, head_h], {thickness: t, edge: 'Trên 1mm'})
      cl << cut_entry('Đầu giường', 1, w, head_h, t, 'Trên 1mm')
      
      # Đuôi giường
      panel(group, 'Đuôi giường', [0, d - t, 0], [w, t, side_h], {thickness: t, edge: 'Trên 1mm'})
      cl << cut_entry('Đuôi giường', 1, w, side_h, t, 'Trên 1mm')

      if btype == 'floating'
        # BỆ THỤT (Chân bệ giường bay lùi vào 150mm)
        inset_b = 150.0
        base_h = 150.0 # Chiều cao bệ
        # Vai bệ (dọc)
        panel(group, 'Vai bệ trái', [inset_b, inset_b, 0], [t, d - inset_b*2, base_h], {thickness: t})
        panel(group, 'Vai bệ phải', [w - inset_b - t, inset_b, 0], [t, d - inset_b*2, base_h], {thickness: t})
        # Thang bệ (ngang)
        panel(group, 'Thang bệ trước', [inset_b + t, inset_b, 0], [w - inset_b*2 - 2*t, t, base_h], {thickness: t})
        panel(group, 'Thang bệ sau', [inset_b + t, d - inset_b - t, 0], [w - inset_b*2 - 2*t, t, base_h], {thickness: t})
        
        cl << cut_entry('Vai bệ dọc', 2, d - inset_b*2, base_h, t, '')
        cl << cut_entry('Thang bệ ngang', 2, w - inset_b*2 - 2*t, base_h, t, '')

        # VAI GIƯỜNG CHÍNH (Bay lơ lửng, cách đất base_h)
        panel(group, 'Vai giường trái',  [0, t, base_h], [t, d - 2*t, side_h - base_h], {thickness: t, edge: 'Trên 1mm'})
        panel(group, 'Vai giường phải',  [w - t, t, base_h], [t, d - 2*t, side_h - base_h], {thickness: t, edge: 'Trên 1mm'})
        cl << cut_entry('Vai giường', 2, d - 2*t, side_h - base_h, t, 'Trên 1mm')
        
        grid_base_z = base_h
        grid_h = side_h - base_h - t # Trừ độ dày mặt phản
      else
        # GIƯỜNG THƯỜNG
        panel(group, 'Vai giường trái',  [0, t, 0], [t, d - 2*t, side_h], {thickness: t, edge: 'Trên 1mm'})
        panel(group, 'Vai giường phải',  [w - t, t, 0], [t, d - 2*t, side_h], {thickness: t, edge: 'Trên 1mm'})
        cl << cut_entry('Vai giường', 2, d - 2*t, side_h, t, 'Trên 1mm')
        
        grid_base_z = 0
        grid_h = side_h - t
      end

      # KHUNG XƯƠNG ĐAN CHÉO (Egg-crate grid)
      # Để phần mềm CNC (như ABF) tự nhận ngàm mộng âm dương, ta vẽ các thanh giao nhau (intersect).
      num_long = 2 # 2 thang dọc
      num_lat = 4  # 4 thang ngang
      
      # Thang dọc (Longitudinal supports)
      inner_w = w - 2*t
      step_w = inner_w / (num_long + 1).to_f
      num_long.times do |i|
        x = t + step_w * (i + 1) - t/2.0
        panel(group, "Thang dọc xương #{i+1}", [x, t, grid_base_z], [t, d - 2*t, grid_h], {thickness: t})
      end
      cl << cut_entry('Thang dọc xương', num_long, d - 2*t, grid_h, t, 'Ngàm sập')

      # Thang ngang (Latitudinal supports)
      inner_d = d - 2*t
      step_d = inner_d / (num_lat + 1).to_f
      num_lat.times do |i|
        y = t + step_d * (i + 1) - t/2.0
        panel(group, "Thang ngang xương #{i+1}", [t, y, grid_base_z], [inner_w, t, grid_h], {thickness: t})
      end
      cl << cut_entry('Thang ngang xương', num_lat, inner_w, grid_h, t, 'Ngàm sập')

      # MẶT PHẢN GIƯỜNG (Chia 2 tấm dọc hoặc ngang)
      panel(group, 'Mặt phản 1', [t, t, side_h - t], [inner_w, inner_d/2.0 - 2, t], {thickness: t})
      panel(group, 'Mặt phản 2', [t, t + inner_d/2.0 + 2, side_h - t], [inner_w, inner_d/2.0 - 2, t], {thickness: t})
      cl << cut_entry('Mặt phản', 2, inner_w, inner_d/2.0 - 2, t, 'Trải phủ gầm')

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
        overlap = 30.0
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
          x = base_x + i * (door_w - overlap/(doors-1))
          y = i % 2 == 0 ? door_y + 35 : door_y + 5
        else
          x = base_x + i * (door_w + gap)
          y = door_y
        end

        name = doors == 1 ? 'Cánh' : (i == 0 ? 'Cánh trái' : (i == doors - 1 ? 'Cánh phải' : "Cánh #{i+1}"))
        inst = panel(group, name, [x, y, door_z], [door_w, t, door_h], {thickness: t, edge: 'Bo 4 cạnh 1mm'})
        
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
