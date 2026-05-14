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
          else raise "Loáº¡i sáº£n pháº©m khÃ´ng há»£p lá»‡: #{type}"
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
        'sink' => 'Khoang cháº­u rá»­a, háº­u há»Ÿ ká»¹ thuáº­t',
        'cooktop' => 'Khoang báº¿p, cÃ³ thoÃ¡ng khÃ­',
        'oven' => 'Khoang lÃ², cÃ³ khe thoÃ¡t nhiá»‡t',
        'drawer' => 'Khoang ngÄƒn kÃ©o phá»¥ kiá»‡n',
        'dishwasher' => 'Khoang mÃ¡y rá»­a bÃ¡t',
        'corner_dead' => 'GÃ³c L cháº¿t',
        'corner_45' => 'GÃ³c L xÃ©o 45',
        'dish_rack' => 'Khoang giÃ¡ bÃ¡t Ä‘Ä©a',
        'extractor' => 'Khoang mÃ¡y hÃºt mÃ¹i'
      }[mod] || 'Khoang tiÃªu chuáº©n'
    end

    def self.build_drawer_bank(group, p, origin, size, count, cl)
      count = count.to_i
      return if count <= 0

      w, d, h = size
      t = (p['thickness'] || 17).to_f
      gap = (p['door_gap'] || 3).to_f
      face_t = t
      usable_h = h - gap * (count + 1)
      return if usable_h <= 80.0 || w <= 120.0 || d <= 180.0

      face_h = usable_h / count.to_f
      count.times do |i|
        z = origin[2] + gap + i * (face_h + gap)
        face_origin = [origin[0] + gap, origin[1] - face_t - gap, z]
        face_size = [w - 2 * gap, face_t, face_h]
        panel(group, "Máº·t ngÄƒn kÃ©o #{i + 1}", face_origin, face_size, {thickness: face_t, edge: 'Bo 4 cáº¡nh 1mm'})
        build_drawer_box(group, "Há»™c kÃ©o #{i + 1}", [origin[0], origin[1], z], [w, d, face_h], t, cl)
      end
      cl << cut_entry('Máº·t ngÄƒn kÃ©o', count, w - 2 * gap, face_h, face_t, 'Bo 4 cáº¡nh 1mm')
    end

    def self.build_wardrobe_front_trim(group, w, h, d, kick, t, comps, comp_w, cl)
      plinth_h = [kick, 90.0].max
      top_rail_h = 60.0
      rail_len = [w - 2*t, t].max

      panel(group, 'Phao chan truoc', [t, -t, 0], [rail_len, t, plinth_h], {thickness: t, edge: 'Bo tren 1mm', note: 'Thanh chan truoc nam giua hai hoi ngoai'})
      panel(group, 'Phao chan sau', [t, d, 0], [rail_len, t, plinth_h], {thickness: t, edge: 'Bo tren 1mm', note: 'Thanh chan sau nam giua hai hoi ngoai'})
      panel(group, 'Phao noc truoc', [t, -t, h - top_rail_h], [rail_len, t, top_rail_h], {thickness: t, edge: 'Bo canh', note: 'Thanh phao noc truoc nam trong chieu cao tu, giua hai hoi ngoai'})
      panel(group, 'Phao noc sau', [t, d, h - top_rail_h], [rail_len, t, top_rail_h], {thickness: t, edge: 'Bo canh', note: 'Thanh phao noc sau nam trong chieu cao tu, giua hai hoi ngoai'})

      cl << cut_entry('Phao chan truoc/sau', 2, rail_len, plinth_h, t, 'Bo tren 1mm')
      cl << cut_entry('Phao noc truoc/sau', 2, rail_len, top_rail_h, t, 'Bo canh')
    end
    def self.build_wardrobe_doors(group, p, w, h, d, base_z, comp_w, cl)
      levels = [[(p['wardrobe_levels'] || 1).to_i, 1].max, 2].min
      dtype = p['door_type'] || 'overlay'
      t = (p['thickness'] || 17).to_f
      gap = (p['door_gap'] || 3).to_f

      if levels == 2
        upper_h = [h * 0.28, 420.0].max
        upper_h = [upper_h, h * 0.38].min
        lower_h = h - upper_h - t
        split_z = base_z + lower_h
        panel(group, 'Äá»£t chia táº§ng cÃ¡nh', [t, 0, split_z], [w - 2*t, d, t], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'TÃ¡ch cÃ¡nh táº§ng trÃªn/dÆ°á»›i'})
        cl << cut_entry('Äá»£t chia táº§ng cÃ¡nh', 1, w - 2*t, d, t, 'TrÆ°á»›c 1mm')

        build_doors_for_zone(group, p, w, lower_h, d, base_z, cl, "#{dtype}_dÆ°á»›i")
        build_doors_for_zone(group, p, w, upper_h, d, split_z + t, cl, "#{dtype}_trÃªn")
      else
        build_doors_for_zone(group, p, w, h, d, base_z, cl, dtype)
      end
    end

    def self.build_doors_for_zone(group, p, w, h, d, base_z, cl, label)
      doors = (p['doors'] || 0).to_i
      return if doors <= 0

      gap = (p['door_gap'] || 3).to_f
      t = (p['thickness'] || 17).to_f
      dtype = p['door_type'] || 'overlay'

      if dtype == 'sliding'
        inner_w = w - 2*t
        rail_d = t
        overlap = doors > 1 ? 30.0 : 0.0
        door_w = (inner_w + overlap * [doors - 1, 0].max) / doors.to_f
        door_h = h - 2*gap - 2*rail_d
        door_z = base_z + gap + rail_d
        base_x = t

        panel(group, "Ray lÃ¹a trÃªn #{label}", [t, -t, base_z + h - rail_d], [inner_w, t, rail_d], {thickness: t, note: 'RÃ£nh/ray cá»­a lÃ¹a'})
        panel(group, "Ray lÃ¹a dÆ°á»›i #{label}", [t, -t, base_z], [inner_w, t, rail_d], {thickness: t, note: 'RÃ£nh/ray cá»­a lÃ¹a'})
        cl << cut_entry('Ray lÃ¹a', 2, inner_w, t, t, '', label)

        doors.times do |i|
          x = base_x + (doors > 1 ? i * (door_w - overlap) : 0)
          y = -t - (i.even? ? t : 2*t + gap)
          name = doors == 1 ? "CÃ¡nh lÃ¹a #{label}" : "CÃ¡nh lÃ¹a #{label} #{i + 1}"
          panel(group, name, [x, y, door_z], [door_w, t, door_h], {thickness: t, edge: 'Bo 4 cáº¡nh 1mm'})
        end
        cl << cut_entry('CÃ¡nh lÃ¹a', doors, door_h, door_w, t, 'Bo 4 cáº¡nh 1mm', label)
      else
        build_doors(group, p, w, h, d, base_z, cl)
      end
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
        # Háº­u rÃ£nh
        b_w = w - 2*t + 2*groove
        b_h = h - kick - 2*t + 2*groove
        b_x = t - groove
        b_y = d - inset - tb
        b_z = kick + t - groove
        panel(group, 'Háº­u (RÃ£nh)', [b_x, b_y, b_z], [b_w, tb, b_h], {thickness: tb})
        cl << cut_entry('Háº­u', 1, b_w, b_h, tb, "ÄÃ¡nh rÃ£nh #{groove}mm")
      else
        # Háº­u Ã¡p
        panel(group, 'Háº­u (Ãp)', [t, d - tb, kick + t], [w - 2*t, tb, h - kick - 2*t], {thickness: tb})
        cl << cut_entry('Háº­u', 1, w - 2*t, h - kick - 2*t, tb, '')
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
      sys32 = false
      inner_w = w - 2*t
      inner_d = internal_depth(p, d)
      body_z = kick
      body_h = h - kick
      comp_w = (inner_w - (comps - 1)*t) / comps.to_f
      open_technical_back = ['sink', 'cooktop', 'oven', 'dishwasher'].include?(mod)
      cl = []
      
      panel(group, 'Há»“i ngoÃ i trÃ¡i tá»§ dÆ°á»›i',  [0, 0, body_z], [t, d, body_h], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Chá»‹u táº£i máº·t Ä‘Ã¡'})
      panel(group, 'Há»“i ngoÃ i pháº£i tá»§ dÆ°á»›i',  [w - t, 0, body_z], [t, d, body_h], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Chá»‹u táº£i máº·t Ä‘Ã¡'})
      cl << cut_entry('Há»“i ngoÃ i tá»§ dÆ°á»›i', 2, body_h, d, t, 'TrÆ°á»›c 1mm', 'Chá»‹u lá»±c máº·t Ä‘Ã¡')

      if sys32
        Hardware.add_system_32_holes(group.entities, [0, 0, body_z + t], [t, d, body_h - t], enabled: true, direction: 1)
        Hardware.add_system_32_holes(group.entities, [w - t, 0, body_z + t], [t, d, body_h - t], enabled: true, direction: -1)
      end

      if mod == 'dishwasher'
        panel(group, 'Giáº±ng trÃªn trÆ°á»›c', [t, 0, h - t], [inner_w, 100, t], {thickness: t, note: 'Äá»¡ máº·t Ä‘Ã¡'})
        panel(group, 'Giáº±ng trÃªn sau',   [t, d - 100, h - t], [inner_w, 100, t], {thickness: t, note: 'Äá»¡ máº·t Ä‘Ã¡'})
        panel(group, 'Äá»‘ giá»¯ mÃ¡y rá»­a bÃ¡t trÃ¡i', [t, 0, body_z], [t, d, body_h], {thickness: t, note: 'Khoang thiáº¿t bá»‹'})
        panel(group, 'Äá»‘ giá»¯ mÃ¡y rá»­a bÃ¡t pháº£i', [w - 2*t, 0, body_z], [t, d, body_h], {thickness: t, note: 'Khoang thiáº¿t bá»‹'})
        panel(group, 'ChÃ¢n Ã¢m mÃ¡y rá»­a bÃ¡t', [t, 50, 0], [inner_w, t, kick], {thickness: t, edge: 'TrÃªn 1mm'})
        panel(group, 'Máº·t Ä‘Ã¡ báº¿p', [-20, -20, h], [w + 40, d + 40, t], {thickness: t, edge: 'Bo cáº¡nh Ä‘Ã¡', note: 'DÃ y theo váº­t liá»‡u nháº­p'})
        Hardware.add_adjustable_feet(group.entities, w, d, kick, t, enabled: true)
        Hardware.add_carcass_joint_markers(group.entities, [t, w - t], d, kick + t, h - t, enabled: false)
        cl << cut_entry('Giáº±ng trÃªn', 2, inner_w, 100, t, '', 'Khoang mÃ¡y rá»­a bÃ¡t')
        cl << cut_entry('ChÃ¢n Ã¢m', 1, inner_w, kick, t, 'TrÃªn 1mm', 'Khoang mÃ¡y rá»­a bÃ¡t')
        return cl
      end

      panel(group, 'ÄÃ¡y tá»§ dÆ°á»›i', [t, 0, kick], [inner_w, d, t], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'ÄÃ¡y liá»n chá»‹u lá»±c ná»“i cháº£o'})
      cl << cut_entry('ÄÃ¡y tá»§ dÆ°á»›i', 1, inner_w, d, t, 'TrÆ°á»›c 1mm', 'ÄÃ¡y liá»n')

      panel(group, 'Giáº±ng máº·t Ä‘Ã¡ trÆ°á»›c', [t, 0, h - t], [inner_w, 90, t], {thickness: t, note: 'Äá»¡ máº·t Ä‘Ã¡, giá»¯ vuÃ´ng tá»§'})
      panel(group, 'Giáº±ng máº·t Ä‘Ã¡ sau',   [t, d - 90, h - t], [inner_w, 90, t], {thickness: t, note: 'Äá»¡ máº·t Ä‘Ã¡, giá»¯ vuÃ´ng tá»§'})
      cl << cut_entry('Giáº±ng máº·t Ä‘Ã¡', 2, inner_w, 90, t, '', 'Tá»§ dÆ°á»›i khÃ´ng dÃ¹ng nÃ³c kÃ­n')

      if open_technical_back
        panel(group, 'Giáº±ng háº­u ká»¹ thuáº­t trÃªn', [t, d - 80, h - 170], [inner_w, t, 90], {thickness: t, note: kitchen_module_note(mod)})
        panel(group, 'Giáº±ng háº­u ká»¹ thuáº­t dÆ°á»›i', [t, d - 80, kick + t], [inner_w, t, 90], {thickness: t, note: 'Háº­u há»Ÿ Ä‘i Ä‘iá»‡n nÆ°á»›c'})
        cl << cut_entry('Giáº±ng háº­u ká»¹ thuáº­t', 2, inner_w, 90, t, '', kitchen_module_note(mod))
      else
        build_back_panel(group, p, w, h, t, kick, cl)
      end

      panel(group, 'ChÃ¢n Ã¢m trÆ°á»›c', [t, 50, 0], [inner_w, t, kick], {thickness: t, edge: 'TrÃªn 1mm'})
      panel(group, 'ChÃ¢n Ã¢m sau', [t, d - 70, 0], [inner_w, t, kick], {thickness: t})
      cl << cut_entry('ChÃ¢n Ã¢m', 2, inner_w, kick, t, 'TrÃªn 1mm', 'Chá»‘ng áº©m sÃ n')
      Hardware.add_adjustable_feet(group.entities, w, d, kick, t, enabled: true)

      joint_x = [t]
      if comps > 1
        (comps - 1).times do |i|
          x = t + (i + 1)*comp_w + i*t
          panel(group, "Há»“i giá»¯a tá»§ dÆ°á»›i #{i + 1}", [x, 0, kick + t], [t, d, h - kick - 2*t], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Chia module 600-800, Ä‘á»¡ máº·t Ä‘Ã¡'})
          joint_x << x
          if sys32
            Hardware.add_system_32_holes(group.entities, [x, 0, kick + t], [t, d, h - kick - 2*t], enabled: true, direction: 1)
            Hardware.add_system_32_holes(group.entities, [x, 0, kick + t], [t, d, h - kick - 2*t], enabled: true, direction: -1)
          end
        end
        cl << cut_entry('Há»“i giá»¯a tá»§ dÆ°á»›i', comps - 1, h - kick - 2*t, d, t, 'TrÆ°á»›c 1mm', 'Chia khoang, Ä‘á»¡ thiáº¿t bá»‹')
      end
      joint_x << (w - t)
      Hardware.add_carcass_joint_markers(group.entities, joint_x, d, kick + t, h - t, enabled: false)

      if shelves > 0 && !['sink', 'oven', 'dishwasher', 'corner_dead', 'corner_45'].include?(mod)
        step_h = (h - kick - 2*t) / (shelves + 1).to_f
        comps.times do |c|
          x = t + c*(comp_w + t)
          shelves.times do |i|
            z = kick + t + step_h * (i + 1)
            panel(group, "Äá»£t tá»§ dÆ°á»›i khoang #{c + 1}.#{i + 1}", [x, 0, z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
          end
        end
        cl << cut_entry('Äá»£t tá»§ dÆ°á»›i', comps * shelves, comp_w, inner_d - 20, t, 'TrÆ°á»›c 1mm', 'Äá»ƒ Ä‘á»“ khÃ´')
      end

      if drawers > 0 || mod == 'drawer'
        drawer_count = drawers > 0 ? drawers : 3
        build_drawer_bank(group, p, [t, 0, kick + t], [comp_w, inner_d, h - kick - 2*t], drawer_count, cl)
      end

      if mod == 'sink'
        panel(group, 'Cháº­u rá»­a Ã¢m máº·t Ä‘Ã¡', [t + 80, 110, h + 2], [comp_w - 160, 420, t], {thickness: t, note: 'KhoÃ©t cháº­u rá»­a'})
        panel(group, 'á»ng ká»¹ thuáº­t cháº­u rá»­a', [t + comp_w/2.0 - t/2.0, d - 120, kick + 80], [t, t, h - kick - 180], {thickness: t, note: 'ÄÆ°á»ng nÆ°á»›c/xáº£'})
      elsif mod == 'cooktop'
        panel(group, 'Báº¿p tá»«/báº¿p gas Ã¢m', [t + 80, 130, h + 2], [comp_w - 160, 380, t], {thickness: t, note: 'KhoÃ©t báº¿p, thoÃ¡ng khÃ­'})
        panel(group, 'Khe thoÃ¡ng báº¿p', [t + 40, d - 40, h - 230], [comp_w - 80, t, 80], {thickness: t, note: 'ThoÃ¡t nhiá»‡t'})
      elsif mod == 'oven'
        panel(group, 'Máº·t lÃ² nÆ°á»›ng', [t + 30, -t, kick + 140], [comp_w - 60, t, 460], {thickness: t, note: 'Module lÃ² Ã¢m'})
        panel(group, 'Khe thoÃ¡t nhiá»‡t lÃ²', [t + 60, -t, kick + 630], [comp_w - 120, t, 35], {thickness: t, note: 'ThoÃ¡t nhiá»‡t'})
      elsif mod == 'corner_dead'
        panel(group, 'Táº¥m gÃ³c cháº¿t chá»¯ L', [w - comp_w - t, d - comp_w, kick + t], [comp_w, comp_w, t], {thickness: t, note: 'GÃ³c L cháº¿t lÆ°u trá»¯ sÃ¢u'})
      elsif mod == 'corner_45'
        panel(group, 'Äá»‘ gÃ³c xÃ©o 45', [w - comp_w, d - 80, kick + t], [comp_w, 80, h - kick - 2*t], {thickness: t, note: 'MÃ´ phá»ng gÃ³c xÃ©o 45'})
      end

      panel(group, 'Máº·t Ä‘Ã¡ báº¿p', [-20, -20, h], [w + 40, d + 40, t], {thickness: t, edge: 'Bo cáº¡nh Ä‘Ã¡', note: 'DÃ y theo váº­t liá»‡u nháº­p'})
      
      build_doors(group, p, w, h - kick, d, kick, cl) unless drawers > 0 || ['drawer', 'oven', 'dishwasher'].include?(mod)
      cl
    end

    def self.build_wall_cabinet(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      shelves = (p['shelves']||1).to_i
      comps = auto_kitchen_compartments(w, t, (p['compartments']||1).to_i)
      mod = p['kitchen_module'] || 'standard'
      sys32 = false
      inner_w = w - 2*t
      inner_d = internal_depth(p, d)
      comp_w = (inner_w - (comps - 1)*t) / comps.to_f
      cl = []
      panel(group, 'Há»“i ngoÃ i trÃ¡i tá»§ trÃªn',  [0, 0, 0], [t, d, h], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Tá»§ treo tÆ°á»ng'})
      panel(group, 'Há»“i ngoÃ i pháº£i tá»§ trÃªn',  [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Tá»§ treo tÆ°á»ng'})
      cl << cut_entry('Há»“i ngoÃ i tá»§ trÃªn', 2, h, d, t, 'TrÆ°á»›c 1mm', 'Tá»§ treo nháº¹ hÆ¡n tá»§ dÆ°á»›i')

      if sys32
        Hardware.add_system_32_holes(group.entities, [0, 0, 0], [t, d, h], enabled: true, direction: 1)
        Hardware.add_system_32_holes(group.entities, [w - t, 0, 0], [t, d, h], enabled: true, direction: -1)
      end

      if mod == 'extractor'
        panel(group, 'NÃ³c tá»§ hÃºt mÃ¹i', [t, 0, h - t], [inner_w, d, t], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
        panel(group, 'ÄÃ¡y che á»‘ng hÃºt mÃ¹i', [t, 0, 150], [inner_w, d, t], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
        panel(group, 'á»ng hÃºt mÃ¹i', [w/2.0 - 75, d - 120, 150 + t], [150, 120, h - 2*t - 150], {thickness: t, note: 'Khoang mÃ¡y hÃºt mÃ¹i'})
        cl << cut_entry('NÃ³c/Ä‘Ã¡y che hÃºt mÃ¹i', 2, inner_w, d, t, 'TrÆ°á»›c 1mm', 'KhoÃ©t á»‘ng hÃºt')
      else
        panel(group, 'ÄÃ¡y tá»§ trÃªn', [t, 0, 0], [inner_w, d, t], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
        panel(group, 'NÃ³c tá»§ trÃªn', [t, 0, h - t], [inner_w, d, t], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
        cl << cut_entry('ÄÃ¡y/NÃ³c tá»§ trÃªn', 2, inner_w, d, t, 'TrÆ°á»›c 1mm')
      end

      build_back_panel(group, p, w, h, t, 0, cl)

      joint_x = [t]
      if comps > 1
        (comps - 1).times do |i|
          x = t + (i + 1)*comp_w + i*t
          panel(group, "Há»“i giá»¯a tá»§ trÃªn #{i + 1}", [x, 0, t], [t, d, h - 2*t], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Chia module tá»§ treo'})
          joint_x << x
        end
        cl << cut_entry('Há»“i giá»¯a tá»§ trÃªn', comps - 1, h - 2*t, d, t, 'TrÆ°á»›c 1mm')
      end
      joint_x << (w - t)
      Hardware.add_carcass_joint_markers(group.entities, joint_x, d, t, h - t, enabled: false)

      if shelves > 0 && mod != 'extractor'
        step_h = (h - 2*t) / (shelves + 1).to_f
        comps.times do |c|
          x = t + c*(comp_w + t)
          shelves.times do |i|
            z = t + step_h * (i + 1)
            panel(group, "Äá»£t tá»§ trÃªn khoang #{c + 1}.#{i + 1}", [x, 0, z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
          end
        end
        cl << cut_entry('Äá»£t tá»§ trÃªn', comps * shelves, comp_w, inner_d - 20, t, 'TrÆ°á»›c 1mm')
      end

      panel(group, 'Bas treo tÆ°á»ng trÃ¡i', [t + 20, d - t, h - 90], [90, t, 45], {thickness: t, note: 'Bas treo/vÃ­t tÆ°á»ng'})
      panel(group, 'Bas treo tÆ°á»ng pháº£i', [w - t - 110, d - t, h - 90], [90, t, 45], {thickness: t, note: 'Bas treo/vÃ­t tÆ°á»ng'})

      if mod == 'dish_rack'
        panel(group, 'GiÃ¡ bÃ¡t Ä‘Ä©a inox', [t + 40, 45, 120], [inner_w - 80, d - 90, t], {thickness: t, note: 'GiÃ¡ bÃ¡t Ä‘Ä©a cá»‘ Ä‘á»‹nh'})
        panel(group, 'Khay há»©ng nÆ°á»›c', [t + 40, 45, 70], [inner_w - 80, d - 90, t], {thickness: t, note: 'Khay há»©ng nÆ°á»›c giÃ¡ bÃ¡t'})
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
      sys32 = false
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
      
      panel(group, 'Há»“i ngoÃ i trÃ¡i', [0, 0, 0], [t, d, h], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Bao biÃªn ngoÃ i tá»§'})
      panel(group, 'Há»“i ngoÃ i pháº£i', [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Bao biÃªn ngoÃ i tá»§'})
      cl << cut_entry('Há»“i ngoÃ i trÃ¡i/pháº£i', 2, h, d, t, 'TrÆ°á»›c 1mm', 'Full cao, chá»‹u lá»±c tá»•ng')
      
      if sys32
        Hardware.add_system_32_holes(group.entities, [0, 0, body_z], [t, structural_d, body_h], enabled: true, direction: 1)
        Hardware.add_system_32_holes(group.entities, [w - t, 0, body_z], [t, structural_d, body_h], enabled: true, direction: -1)
      end

      panel(group, 'ÄÃ¡y tá»§', [t, 0, kick], [inner_w, d, t], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Lá»t giá»¯a hai há»“i ngoÃ i'})
      panel(group, 'NÃ³c tá»§', [t, 0, h - t], [inner_w, d, t], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Lá»t giá»¯a hai há»“i ngoÃ i'})
      cl << cut_entry('ÄÃ¡y/NÃ³c', 2, inner_w, d, t, 'TrÆ°á»›c 1mm', 'Lá»t giá»¯a há»“i ngoÃ i')
      build_wardrobe_front_trim(group, w, h, d, kick, t, comps, comp_w, cl)

      build_back_panel(group, p, w, h, t, kick, cl)

      if comps > 1
        (comps - 1).times do |i|
          x = t + (i + 1)*comp_w + i*t
          panel(group, "Há»“i giá»¯a #{i + 1}", [x, 0, body_z], [t, structural_d, body_h], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'VÃ¡ch Ä‘á»©ng chia khoang full cao'})
          if sys32
            Hardware.add_system_32_holes(group.entities, [x, 0, body_z], [t, structural_d, body_h], enabled: true, direction: 1)
            Hardware.add_system_32_holes(group.entities, [x, 0, body_z], [t, structural_d, body_h], enabled: true, direction: -1)
          end
        end
        cl << cut_entry('Há»“i giá»¯a / vÃ¡ch Ä‘á»©ng', comps - 1, body_h, structural_d, t, 'TrÆ°á»›c 1mm', 'Full cao, chia khoang vÃ  chá»‘ng vÃµng')
      end

      joint_x = [t]
      (comps - 1).times { |i| joint_x << (t + (i + 1)*comp_w + i*t) }
      joint_x << (w - t)
      Hardware.add_wardrobe_joint_markers(group.entities, joint_x, structural_d, body_z, body_top, enabled: false)

      fixed_shelf_z = [h - 420.0, shelf_zone_z + 260.0].max
      fixed_shelf_z = body_top - 260.0 if fixed_shelf_z > body_top - 180.0
      if fixed_shelf_z > shelf_zone_z + 120.0
        comps.times do |c|
          x = t + c*(comp_w + t)
          panel(group, "Äá»£t cá»‘ Ä‘á»‹nh khoang #{c + 1}", [x, 0, fixed_shelf_z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Äá»£t cá»‘ Ä‘á»‹nh khÃ³a khoang'})
        end
        cl << cut_entry('Äá»£t cá»‘ Ä‘á»‹nh tá»§ Ã¡o', comps, comp_w, inner_d - 20, t, 'TrÆ°á»›c 1mm', 'KhÃ³a khoang, tÄƒng cá»©ng')
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
              panel(group, "Äá»£t di Ä‘á»™ng khoang #{c + 1}.#{i + 1}", [x, 0, z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'TrÆ°á»›c 1mm', note: 'Äá»£t di Ä‘á»™ng trÃªn lá»— System 32'})
            end
          end
          cl << cut_entry('Äá»£t di Ä‘á»™ng tá»§ Ã¡o', comps * max_shelves, comp_w, inner_d - 20, t, 'TrÆ°á»›c 1mm', 'Nhá»‹p Ä‘á»£t khÃ´ng vÆ°á»£t 800mm')
        end
      end

      long_hanging = h >= 2200.0
      rod_z = long_hanging ? [body_z + 1550.0, fixed_shelf_z - 90.0].min : [body_z + 1050.0, fixed_shelf_z - 90.0].min
      if rod_z > shelf_zone_z + 180.0 && comp_w > 120.0
        comps.times do |c|
          x = t + c*(comp_w + t) + 40.0
          panel(group, "Suá»‘t treo khoang #{c + 1}", [x, inner_d * 0.52, rod_z], [comp_w - 80.0, t, t], {thickness: t, note: long_hanging ? 'Suá»‘t treo Ã¡o dÃ i 1400-1600mm' : 'Suá»‘t treo Ã¡o ngáº¯n 900-1100mm'})
        end
      end

      if p['wardrobe_led'] == true && comp_w > 160.0
        comps.times do |c|
          x = t + c*(comp_w + t) + 40.0
          panel(group, "LED cáº£m biáº¿n khoang #{c + 1}", [x, t, body_top - 35.0], [comp_w - 80.0, t, t], {thickness: t, note: 'LED cáº£m biáº¿n tá»§ Ã¡o'})
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
      
      # VÃ¡ch chia
      if comps > 1
        (comps - 1).times do |i|
          x = t + (i + 1)*comp_w + i*t
          panel(group, "VÃ¡ch chia #{i+1}", [x, 0, base_z + t], [t, inner_d, inner_h], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
          if sys32
            Hardware.add_system_32_holes(group.entities, [x, 0, base_z + t], [t, inner_d, inner_h], enabled: true, direction: 1)
            Hardware.add_system_32_holes(group.entities, [x, 0, base_z + t], [t, inner_d, inner_h], enabled: true, direction: -1)
          end
        end
        cl << cut_entry('VÃ¡ch chia', comps - 1, inner_h, inner_d, t, 'TrÆ°á»›c 1mm')
      end

      # Äá»£t
      if shelves > 0
        step_h = inner_h / (shelves + 1).to_f
        comps.times do |c|
          x = t + c*(comp_w + t)
          shelves.times do |i|
            z = base_z + t + step_h * (i + 1)
            # RÃºt ngáº¯n Ä‘á»£t 20mm Ä‘á»ƒ thá»¥t vÃ o
            panel(group, "Äá»£t khoang #{c+1} Ä‘á»£t #{i+1}", [x, 0, z], [comp_w, inner_d - 20, t], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
          end
        end
        cl << cut_entry('Äá»£t', comps * shelves, comp_w, inner_d - 20, t, 'TrÆ°á»›c 1mm')
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
      
      # Äáº§u giÆ°á»ng (Phá»§ ra ngoÃ i cÃ¹ng)
      panel(group, 'Äáº§u giÆ°á»ng', [0, 0, 0], [w, t, head_h], {thickness: t, edge: 'TrÃªn 1mm'})
      cl << cut_entry('Äáº§u giÆ°á»ng', 1, w, head_h, t, 'TrÃªn 1mm')

      if btype == 'floating'
        base_h = 150.0
        inset_b = 150.0
        # Bá»‡ thá»¥t
        panel(group, 'Vai bá»‡ trÃ¡i', [inset_b, inset_b, 0], [t, d - inset_b*2, base_h], {thickness: t})
        panel(group, 'Vai bá»‡ pháº£i', [w - inset_b - t, inset_b, 0], [t, d - inset_b*2, base_h], {thickness: t})
        panel(group, 'Thang bá»‡ trÆ°á»›c', [inset_b + t, inset_b, 0], [w - inset_b*2 - 2*t, t, base_h], {thickness: t})
        panel(group, 'Thang bá»‡ sau', [inset_b + t, d - inset_b - t, 0], [w - inset_b*2 - 2*t, t, base_h], {thickness: t})
        
        cl << cut_entry('Vai bá»‡', 2, d - inset_b*2, base_h, t, '')
        cl << cut_entry('Thang bá»‡', 2, w - inset_b*2 - 2*t, base_h, t, '')

        # Vai giÆ°á»ng lÆ¡ lá»­ng
        panel(group, 'Vai giÆ°á»ng trÃ¡i',  [0, t, base_h], [t, d - t, side_h - base_h], {thickness: t, edge: 'TrÃªn 1mm'})
        panel(group, 'Vai giÆ°á»ng pháº£i',  [w - t, t, base_h], [t, d - t, side_h - base_h], {thickness: t, edge: 'TrÃªn 1mm'})
        # ÄuÃ´i giÆ°á»ng lá»t trong vai
        panel(group, 'ÄuÃ´i giÆ°á»ng', [t, d - t, base_h], [w - 2*t, t, side_h - base_h], {thickness: t, edge: 'TrÃªn 1mm'})
        
        cl << cut_entry('Vai giÆ°á»ng', 2, d - t, side_h - base_h, t, 'TrÃªn 1mm')
        cl << cut_entry('ÄuÃ´i giÆ°á»ng', 1, w - 2*t, side_h - base_h, t, 'TrÃªn 1mm')
        
        grid_base_z = base_h
        grid_h = side_h - base_h - t
      else
        # GIÆ¯á»œNG THÆ¯á»œNG / GIÆ¯á»œNG NGÄ‚N KÃ‰O
        panel(group, 'Vai giÆ°á»ng pháº£i',  [w - t, t, 0], [t, d - t, side_h], {thickness: t, edge: 'TrÃªn 1mm'})
        cl << cut_entry('Vai giÆ°á»ng', 1, d - t, side_h, t, 'TrÃªn 1mm')

        if drawers > 0
          # Vai trÃ¡i lÃ  vai cÃ³ ngÄƒn kÃ©o (váº½ ghÃ©p tá»« cÃ¡c Ä‘oáº¡n Ä‘á»ƒ táº¡o lá»—, xuáº¥t cutlist lÃ  1 táº¥m nguyÃªn)
          dr_w = (d - t - top_m - bot_m - (drawers - 1) * mid_m) / drawers.to_f
          
          # Váº½ cÃ¡c Ä‘oáº¡n Báº£n Ä‘á»ƒ táº¡o hiá»‡u á»©ng 3D cÃ³ lá»—
          panel(group, 'Báº£n Ä‘áº§u (Vai trÃ¡i)', [0, t, 0], [t, top_m, side_h], {thickness: t})
          panel(group, 'Báº£n cuá»‘i (Vai trÃ¡i)', [0, d - bot_m, 0], [t, bot_m, side_h], {thickness: t})
          if drawers > 1
            (drawers - 1).times do |i|
              y_mid = t + top_m + dr_w + i*(dr_w + mid_m)
              panel(group, "Báº£n giá»¯a #{i+1} (Vai trÃ¡i)", [0, y_mid, 0], [t, mid_m, side_h], {thickness: t})
            end
          end
          # Náº¹p trÃªn/dÆ°á»›i lá»—
          panel(group, 'XÃ  trÃªn lá»— NK', [0, t + top_m, side_h - 40], [t, d - t - top_m - bot_m, 40], {thickness: t})
          panel(group, 'XÃ  dÆ°á»›i lá»— NK', [0, t + top_m, 0], [t, d - t - top_m - bot_m, 40], {thickness: t})

          cl << cut_entry('Vai giÆ°á»ng (khoÃ©t lá»• NK)', 1, d - t, side_h, t, 'KhoÃ©t lá»• CNC')
        else
          panel(group, 'Vai giÆ°á»ng trÃ¡i',  [0, t, 0], [t, d - t, side_h], {thickness: t, edge: 'TrÃªn 1mm'})
          cl << cut_entry('Vai giÆ°á»ng', 1, d - t, side_h, t, 'TrÃªn 1mm')
        end

        # ÄuÃ´i giÆ°á»ng lá»t trong vai
        panel(group, 'ÄuÃ´i giÆ°á»ng', [t, d - t, 0], [w - 2*t, t, side_h], {thickness: t, edge: 'TrÃªn 1mm'})
        cl << cut_entry('ÄuÃ´i giÆ°á»ng', 1, w - 2*t, side_h, t, 'TrÃªn 1mm')
        
        grid_base_z = 0
        grid_h = side_h - t
      end

      # KHUNG XÆ¯Æ NG
      inner_w = w - 2*t
      inner_d = d - 2*t

      if drawers > 0
        # GIÆ¯á»œNG CÃ“ NGÄ‚N KÃ‰O
        # Thang dá»c ngÄƒn kÃ©o (Háº­u cá»§a ngÄƒn kÃ©o)
        x_runner = t + runner
        panel(group, 'Thang dá»c Ä‘á»¡ NK', [x_runner, t, grid_base_z], [t, inner_d, grid_h], {thickness: t})
        cl << cut_entry('Thang dá»c Ä‘á»¡ NK', 1, inner_d, grid_h, t, '')
        
        # Thang dá»c cÃ²n láº¡i (chia Ä‘á»u pháº§n khÃ´ng gian trá»‘ng bÃªn pháº£i)
        rem_w = inner_w - runner - t
        x_mid = x_runner + t + rem_w/2.0
        panel(group, 'Thang dá»c xÆ°Æ¡ng', [x_mid, t, grid_base_z], [t, inner_d, grid_h], {thickness: t})
        cl << cut_entry('Thang dá»c xÆ°Æ¡ng', 1, inner_d, grid_h, t, '')

        # VÃ¡ch ngang chia NK
        dr_w = (d - t - top_m - bot_m - (drawers - 1) * mid_m) / drawers.to_f
        y_pos = t + top_m
        drawers.times do |i|
          # Táº¡o há»™p ngÄƒn kÃ©o
          build_drawer_box(group, "Há»™c #{i+1}", [t, y_pos, grid_base_z], [runner, dr_w, grid_h - 20], t, cl)
          # Máº·t ngÄƒn kÃ©o (lá»t vÃ o trong lá»—)
          panel(group, "Máº·t NK #{i+1}", [t, y_pos + 2, grid_base_z + 42], [t, dr_w - 4, grid_h - 84], {thickness: t})
          cl << cut_entry('Máº·t ngÄƒn kÃ©o', 1, dr_w - 4, grid_h - 84, t, 'Bo 4 cáº¡nh')

          # VÃ¡ch ngang (Thang ngang) Ã´m 2 bÃªn NK
          panel(group, "VÃ¡ch ngang NK #{i+1} trÆ°á»›c", [t, y_pos - t, grid_base_z], [runner, t, grid_h], {thickness: t})
          panel(group, "VÃ¡ch ngang NK #{i+1} sau", [t, y_pos + dr_w, grid_base_z], [runner, t, grid_h], {thickness: t})
          
          y_pos += dr_w + mid_m
        end
        cl << cut_entry('VÃ¡ch ngang ngÄƒn kÃ©o', drawers * 2, runner, grid_h, t, '')

      else
        # GIÆ¯á»œNG THÆ¯á»œNG ÄAN LÆ¯á»šI
        num_long = 2
        num_lat = 2 # 2 hÃ ng ngang táº¡o thÃ nh 3 khoang
        
        comp_w = (inner_w - num_long*t) / (num_long + 1).to_f
        comp_d = (inner_d - num_lat*t) / (num_lat + 1).to_f
        
        # Thang dá»c (nguyÃªn táº¥m)
        num_long.times do |i|
          x = t + comp_w*(i+1) + t*i
          panel(group, "Thang dá»c xÆ°Æ¡ng #{i+1}", [x, t, grid_base_z], [t, inner_d, grid_h], {thickness: t})
        end
        cl << cut_entry('Thang dá»c xÆ°Æ¡ng', num_long, inner_d, grid_h, t, '')

        # Thang ngang (Cáº¯t thÃ nh cÃ¡c Ä‘oáº¡n nhá» nhÃ©t giá»¯a thang dá»c)
        num_lat.times do |row|
          y = t + comp_d*(row+1) + t*row
          (num_long + 1).times do |col|
            x = t + comp_w*col + t*col
            panel(group, "Thang ngang xÆ°Æ¡ng", [x, y, grid_base_z], [comp_w, t, grid_h], {thickness: t})
          end
        end
        cl << cut_entry('Thang ngang xÆ°Æ¡ng', num_lat * (num_long + 1), comp_w, grid_h, t, '')
      end

      # Máº¶T PHáº¢N GIÆ¯á»œNG (Chia 4 táº¥m dáº¥u tháº­p)
      panel(group, 'Máº·t pháº£n TrÃ¡i TrÆ°á»›c', [t, t, side_h - t], [inner_w/2.0, inner_d/2.0, t], {thickness: t})
      panel(group, 'Máº·t pháº£n Pháº£i TrÆ°á»›c', [t + inner_w/2.0, t, side_h - t], [inner_w/2.0, inner_d/2.0, t], {thickness: t})
      panel(group, 'Máº·t pháº£n TrÃ¡i Sau', [t, t + inner_d/2.0, side_h - t], [inner_w/2.0, inner_d/2.0, t], {thickness: t})
      panel(group, 'Máº·t pháº£n Pháº£i Sau', [t + inner_w/2.0, t + inner_d/2.0, side_h - t], [inner_w/2.0, inner_d/2.0, t], {thickness: t})
      cl << cut_entry('Máº·t pháº£n', 4, inner_w/2.0, inner_d/2.0, t, 'Tráº£i phá»§ gáº§m')

      cl
    end

    def self.build_desk(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      cl = []
      panel(group, 'Máº·t bÃ n', [0, 0, h - t], [w, d, t], {thickness: t, edge: 'TrÆ°á»›c+trÃ¡i+pháº£i 1mm'})
      cl << cut_entry('Máº·t bÃ n', 1, w, d, t, 'TrÆ°á»›c+trÃ¡i+pháº£i 1mm')
      panel(group, 'Há»“i trÃ¡i', [0, 0, 0], [t, d, h - t], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
      panel(group, 'Há»“i pháº£i', [w - t, 0, 0], [t, d, h - t], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
      cl << cut_entry('Há»“i trÃ¡i/pháº£i', 2, h - t, d, t, 'TrÆ°á»›c 1mm')
      panel(group, 'Giáº±ng sau', [t, d - t, h - t - 200], [w - 2*t, t, 200], {thickness: t})
      cl << cut_entry('Giáº±ng sau', 1, w - 2*t, 200, t, '')
      cl
    end

    def self.build_drawer_box(group, name, origin, size, thickness, cl)
      w, d, h = size
      t = thickness
      slide_gap = 13.0
      box_w = w - 2 * slide_gap
      box_d = d - 20 
      box_h = h - 40 

      # Há»“i há»™c kÃ©o
      panel(group, "#{name} Há»“i trÃ¡i", [origin[0] + slide_gap, origin[1] + 10, origin[2] + 20], [t, box_d, box_h], {thickness: t, edge: 'TrÃªn 1mm'})
      panel(group, "#{name} Há»“i pháº£i", [origin[0] + w - slide_gap - t, origin[1] + 10, origin[2] + 20], [t, box_d, box_h], {thickness: t, edge: 'TrÃªn 1mm'})
      cl << cut_entry("#{name} Há»“i", 2, box_d, box_h, t, 'TrÃªn 1mm')

      # TrÃ¡n há»™c / LÆ°ng há»™c
      front_back_w = box_w - 2*t
      panel(group, "#{name} TrÃ¡n", [origin[0] + slide_gap + t, origin[1] + 10, origin[2] + 20], [front_back_w, t, box_h], {thickness: t, edge: 'TrÃªn 1mm'})
      panel(group, "#{name} LÆ°ng", [origin[0] + slide_gap + t, origin[1] + 10 + box_d - t, origin[2] + 20], [front_back_w, t, box_h], {thickness: t, edge: 'TrÃªn 1mm'})
      cl << cut_entry("#{name} TrÃ¡n/LÆ°ng", 2, front_back_w, box_h, t, 'TrÃªn 1mm')

      # ÄÃ¡y há»™c lá»t gáº§m
      db_t = t
      panel(group, "#{name} ÄÃ¡y", [origin[0] + slide_gap + t, origin[1] + 10 + t, origin[2] + 20], [front_back_w, box_d - 2*t, db_t], {thickness: db_t})
      cl << cut_entry("#{name} ÄÃ¡y", 1, front_back_w, box_d - 2*t, db_t, '')
      Hardware.add_drawer_slides(group.entities, origin, size, enabled: true)
    end

    def self.build_bedside_table(group, p)
      w = p['width'].to_f; h = p['height'].to_f; d = p['depth'].to_f
      t = (p['thickness']||17).to_f
      drawers = (p['drawers']||2).to_i
      cl = []
      panel(group, 'Há»“i trÃ¡i', [0, 0, 0], [t, d, h], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
      panel(group, 'Há»“i pháº£i', [w - t, 0, 0], [t, d, h], {thickness: t, edge: 'TrÆ°á»›c 1mm'})
      cl << cut_entry('Há»“i trÃ¡i/pháº£i', 2, h, d, t, 'TrÆ°á»›c 1mm')
      panel(group, 'ÄÃ¡y', [t, 0, 0], [w - 2*t, d, t], {thickness: t})
      panel(group, 'NÃ³c', [t, 0, h - t], [w - 2*t, d, t], {thickness: t, edge: 'TrÆ°á»›c+trÃ¡i+pháº£i 1mm'})
      cl << cut_entry('ÄÃ¡y', 1, w - 2*t, d, t, '')
      cl << cut_entry('NÃ³c', 1, w - 2*t, d, t, 'TrÆ°á»›c+trÃ¡i+pháº£i 1mm')
      
      build_back_panel(group, p, w, h, t, 0, cl)

      if drawers > 0
        inner_h = h - 2*t
        face_h = (inner_h / drawers.to_f) - 3
        drawers.times do |i|
          z = t + i * (face_h + 3)
          # Máº·t há»™c kÃ©o
          panel(group, "Máº·t há»™c kÃ©o #{i+1}", [3, -t, z], [w - 6, t, face_h], {thickness: t, edge: 'Bo 4 cáº¡nh 1mm'})
          # Cáº¥u táº¡o há»™c kÃ©o bÃªn trong
          build_drawer_box(group, "Há»™c #{i+1}", [t, 0, z], [w - 2*t, d, face_h], t, cl)
        end
        cl << cut_entry('Máº·t há»™c kÃ©o', drawers, w - 6, face_h, t, 'Bo 4 cáº¡nh 1mm')
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
        rail_d = t
        overlap = doors > 1 ? 30.0 : 0.0
        door_w = (inner_w + overlap * [doors - 1, 0].max) / doors.to_f
        door_h = inner_h - 2*rail_d - gap
        door_y = -t
        door_z = base_z + t + rail_d
        base_x = t
        
        # Ray trÆ°á»£t nhÃ´m
        panel(group, 'Ray lÃ¹a trÃªn', [t, -t, base_z + h - t - rail_d], [inner_w, t, rail_d], {thickness: t})
        panel(group, 'Ray lÃ¹a dÆ°á»›i', [t, -t, base_z + t], [inner_w, t, rail_d], {thickness: t})
        cl << cut_entry('Ray lÃ¹a', 2, inner_w, t, t, '')
      end

      doors.times do |i|
        if dtype == 'sliding'
          x = base_x + (doors > 1 ? i * (door_w - overlap) : 0)
          y = i % 2 == 0 ? door_y : door_y - t - gap
        else
          x = base_x + i * (door_w + gap)
          y = door_y
        end

        name = doors == 1 ? 'CÃ¡nh' : (i == 0 ? 'CÃ¡nh trÃ¡i' : (i == doors - 1 ? 'CÃ¡nh pháº£i' : "CÃ¡nh #{i+1}"))
        inst = panel(group, name, [x, y, door_z], [door_w, t, door_h], {thickness: t, edge: 'Bo 4 cáº¡nh 1mm'})
        
      end
      cl << cut_entry('CÃ¡nh', doors, door_h, door_w, t, 'Bo 4 cáº¡nh 1mm')
    end
  end
end
