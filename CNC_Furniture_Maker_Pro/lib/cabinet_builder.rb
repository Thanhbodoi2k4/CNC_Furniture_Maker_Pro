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

    def self.build_base_cabinet(group, p)
      w = p['width'].to_f;  h = p['height'].to_f;  d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      tb = (p['back_thickness']||5).to_f
      kick = (p['kickboard']||80).to_f
      shelves = (p['shelves']||1).to_i
      comps = (p['compartments']||1).to_i
      has_back = p['has_back'] != false
      mod = p['kitchen_module'] || 'standard'
      
      cl = []
      
      # Hồi
      panel(group, 'Hồi trái',  [0, 0, kick], [t, d, h - kick], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Hồi phải',  [w - t, 0, kick], [t, d, h - kick], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Hồi trái/phải', 2, h - kick, d, t, 'Trước 1mm')

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

      # Hậu
      if has_back
        panel(group, 'Hậu', [t, d - tb, kick + t], [w - 2*t, tb, h - kick - 2*t], {thickness: tb})
        cl << cut_entry('Hậu', 1, w - 2*t, h - kick - 2*t, tb, '')
      end

      # Kickboard
      panel(group, 'Chân âm', [t, 50, 0], [w - 2*t, t, kick], {thickness: t})
      cl << cut_entry('Chân âm', 1, w - 2*t, kick, t, 'Trên 1mm')

      # Vách & Đợt
      build_inner_compartments(group, p, w, h - kick, d, kick, t, tb, comps, shelves, cl, has_back, false)
      
      # Cánh
      build_doors(group, p, w, h - kick, d, kick, cl)
      cl
    end

    def self.build_wall_cabinet(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      tb = (p['back_thickness']||5).to_f
      shelves = (p['shelves']||1).to_i
      comps = (p['compartments']||1).to_i
      has_back = p['has_back'] != false
      mod = p['kitchen_module'] || 'standard'
      
      cl = []
      panel(group, 'Hồi trái',  [0, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Hồi phải',  [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Hồi trái/phải', 2, h, d, t, 'Trước 1mm')

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

      if has_back
        panel(group, 'Hậu', [t, d - tb, t], [w - 2*t, tb, h - 2*t], {thickness: tb})
        cl << cut_entry('Hậu', 1, w - 2*t, h - 2*t, tb, '')
      end

      build_inner_compartments(group, p, w, h, d, 0, t, tb, comps, shelves, cl, has_back, true)
      build_doors(group, p, w, h, d, 0, cl)
      cl
    end

    def self.build_wardrobe(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      tb = (p['back_thickness']||5).to_f
      kick = (p['kickboard']||80).to_f
      shelves = (p['shelves']||3).to_i
      comps = (p['compartments']||2).to_i
      cl = []
      
      panel(group, 'Hồi trái', [0, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Hồi phải', [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Hồi trái/phải', 2, h, d, t, 'Trước 1mm')
      
      panel(group, 'Đáy', [t, 0, kick], [w - 2*t, d, t], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Nóc', [t, 0, h - t], [w - 2*t, d, t], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Đáy/Nóc', 2, w - 2*t, d, t, 'Trước 1mm')
      
      panel(group, 'Chân âm', [t, 50, 0], [w - 2*t, t, kick], {thickness: t})
      cl << cut_entry('Chân âm', 1, w - 2*t, kick, t, 'Trên 1mm')

      panel(group, 'Hậu', [t, d - tb, kick + t], [w - 2*t, tb, h - kick - 2*t], {thickness: tb})
      cl << cut_entry('Hậu', 1, w - 2*t, h - kick - 2*t, tb, '')

      build_inner_compartments(group, p, w, h - kick, d, kick, t, tb, comps, shelves, cl, true, true)
      build_doors(group, p, w, h - kick, d, kick, cl)
      cl
    end

    def self.build_inner_compartments(group, p, w, h, d, base_z, t, tb, comps, shelves, cl, has_back, has_top)
      return if comps < 1
      inner_w = w - 2*t
      inner_d = has_back ? d - tb : d
      inner_h = has_top ? h - 2*t : h - t
      
      comp_w = (inner_w - (comps - 1)*t) / comps.to_f
      
      # Vách chia
      if comps > 1
        (comps - 1).times do |i|
          x = t + (i + 1)*comp_w + i*t
          panel(group, "Vách chia #{i+1}", [x, 0, base_z + t], [t, inner_d, inner_h], {thickness: t, edge: 'Trước 1mm'})
        end
        cl << cut_entry('Vách chia', comps - 1, inner_h, inner_d, t, 'Trước 1mm')
      end

      # Đợt cho từng khoang
      if shelves > 0
        step_h = inner_h / (shelves + 1).to_f
        comps.times do |c|
          x = t + c*(comp_w + t)
          shelves.times do |i|
            z = base_z + t + step_h * (i + 1)
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
      
      panel(group, 'Đầu giường', [0, 0, 0], [w, t, head_h], {thickness: t, edge: 'Trên 1mm'})
      cl << cut_entry('Đầu giường', 1, w, head_h, t, 'Trên 1mm')
      
      panel(group, 'Cuối giường', [0, d - t, 0], [w, t, side_h * 0.7], {thickness: t, edge: 'Trên 1mm'})
      cl << cut_entry('Cuối giường', 1, w, side_h * 0.7, t, 'Trên 1mm')
      
      if btype == 'floating'
        # Vai giường lùi vào trong tạo hiệu ứng lơ lửng
        float_inset = 150.0
        panel(group, 'Vai trái bay',  [float_inset, t, 0], [t, d - 2*t, side_h - 100], {thickness: t, edge: 'Trên 1mm'})
        panel(group, 'Vai phải bay',  [w - float_inset - t, t, 0], [t, d - 2*t, side_h - 100], {thickness: t, edge: 'Trên 1mm'})
        cl << cut_entry('Vai giường thu nhỏ', 2, d - 2*t, side_h - 100, t, 'Trên 1mm')
        
        # Bổ sung 2 vai ngang phụ đỡ mặt phản
        panel(group, 'Giằng phản 1', [0, d/3.0, side_h - 100 - t], [w, t, 100], {thickness: t})
        panel(group, 'Giằng phản 2', [0, 2*d/3.0, side_h - 100 - t], [w, t, 100], {thickness: t})
        cl << cut_entry('Giằng phản', 2, w, 100, t, '')
      else
        panel(group, 'Vai giường trái',  [0, t, 0], [t, d - 2*t, side_h], {thickness: t, edge: 'Trên 1mm'})
        panel(group, 'Vai giường phải',  [w - t, t, 0], [t, d - 2*t, side_h], {thickness: t, edge: 'Trên 1mm'})
        cl << cut_entry('Vai giường', 2, d - 2*t, side_h, t, 'Trên 1mm')
      end

      # Nan giường/Mặt phản
      slats = 12
      inner_d = d - 2*t
      gap = inner_d / slats.to_f
      slats.times do |i|
        y = t + gap * i + 20
        panel(group, "Nan giường #{i+1}", [t, y, side_h - 70], [w - 2*t, 70, t], {thickness: t})
      end
      cl << cut_entry('Nan giường', slats, w - 2*t, 70, t, '')
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

    def self.build_bedside_table(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      tb = (p['back_thickness']||5).to_f
      drawers = (p['drawers']||2).to_i
      cl = []
      panel(group, 'Hồi trái', [0, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      panel(group, 'Hồi phải', [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'Trước 1mm'})
      cl << cut_entry('Hồi trái/phải', 2, h, d, t, 'Trước 1mm')
      panel(group, 'Đáy', [t, 0, 0], [w - 2*t, d, t], {thickness: t})
      panel(group, 'Nóc', [t, 0, h - t], [w - 2*t, d, t], {thickness: t, edge: 'Trước+trái+phải 1mm'})
      cl << cut_entry('Đáy', 1, w - 2*t, d, t, '')
      cl << cut_entry('Nóc', 1, w - 2*t, d, t, 'Trước+trái+phải 1mm')
      panel(group, 'Hậu', [t, d - tb, t], [w - 2*t, tb, h - 2*t], {thickness: tb})
      cl << cut_entry('Hậu', 1, w - 2*t, h - 2*t, tb, '')
      if drawers > 0
        inner_h = h - 2*t
        face_h = (inner_h / drawers.to_f) - 3
        drawers.times do |i|
          z = t + i * (face_h + 3)
          panel(group, "Mặt hộc kéo #{i+1}", [3, -18, z], [w - 6, 18, face_h], {thickness: 18, edge: 'Bo 4 cạnh 1mm'})
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
        door_h = inner_h - 5 # ray trượt
        door_y = 0
        door_z = base_z + t + 2.5
        base_x = t
        
        # Ray trượt lùa
        panel(group, 'Ray trượt trên/dưới', [t, 0, base_z + t], [inner_w, 60, 10], {thickness: 10})
        cl << cut_entry('Ray trượt lùa', 2, inner_w, 60, 10, '')
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
