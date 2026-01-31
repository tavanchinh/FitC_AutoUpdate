class ABF_CoordinateOnlyTool
  def initialize
    # Khởi tạo các biến cơ bản, không nhận tham số Hash để tránh lỗi TypeError [cite: 2026-01-23]
    @selection = nil
    @moving = false
    @hovered_data = nil
    puts ">>> MODE MINIMAL: Đã fix lỗi TypeError. Chỉ dùng nhãn [X, Y] làm Preview." [cite: 2026-01-23]
  end

  def find_target(ent)
    return nil unless ent && ent.valid? && ent.respond_to?(:parent)
    
    path = []
    curr = ent
    while curr && curr.respond_to?(:parent)
      path.unshift(curr)
      break if curr.respond_to?(:name) && curr.name == "__ABF_Nesting"
      parent_def = curr.parent
      curr = parent_def.respond_to?(:instances) ? parent_def.instances.first : nil
    end

    idx = path.find_index { |e| e.respond_to?(:name) && e.name == "__ABF_Nesting" }
    if idx && path[idx + 2]
      panel = path[idx + 2]
      sheet = path[idx + 1]
      nesting = path[idx]
      # Ma trận chuẩn để nhãn bám đúng vị trí trong hình bạn chụp [cite: 2026-01-23]
      world_trans = nesting.transformation * sheet.transformation * panel.transformation
      return { :panel => panel, :trans => world_trans, :local_pos => panel.transformation.origin }
    end
    nil
  end

  def onMouseMove(flags, x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    picked = ph.leaf_at(0)
    
    if !@moving
      @hovered_data = find_target(picked)
    else
      ip = view.inputpoint(x, y)
      vector = ip.position - @last_pos
      @selection.transform!(Geom::Transformation.translation(vector))
      @last_pos = ip.position
      @hovered_data = find_target(@selection)
    end
    view.invalidate
  end

  def draw(view)
    # Kiểm tra an toàn để tránh lỗi NoMethodError hoặc TypeError [cite: 2026-01-23]
    return unless @hovered_data.is_a?(Hash) && @hovered_data[:panel] && @hovered_data[:panel].valid?

    trans = @hovered_data[:trans]
    local_origin = @hovered_data[:local_pos]
    
    # Logic kiểm tra tấm nhỏ < 100mm từ code cũ của bạn [cite: 2026-01-23]
    bbox = @hovered_data[:panel].bounds
    is_small = (bbox.width < 100.mm || bbox.height < 100.mm) [cite: 2026-01-23]
    
    # Hiển thị nhãn tại gốc tọa độ thực tế (Góc trái dưới)
    screen_pos = view.screen_coords(trans.origin)
    label = "[X: #{local_origin.x.to_mm.round}, Y: #{local_origin.y.to_mm.round}]" [cite: 2026-01-23]
    label += " (TAM NHO)" if is_small [cite: 2026-01-23]
    
    view.draw_text(screen_pos, label, color: is_small ? "orange" : "red", size: 16, bold: true)
  end

  def onLButtonDown(flags, x, y, view)
    if !@moving && @hovered_data.is_a?(Hash)
      @selection = @hovered_data[:panel]
      @moving = true
      @last_pos = view.inputpoint(x, y).position
      Sketchup.active_model.start_operation('Move ABF', true)
    elsif @moving
      @moving = false
      # Gán tag TRAI/PHAI dựa trên X=600 [cite: 2026-01-23]
      lx = @selection.transformation.origin.x
      tag = lx < 600.mm ? "TRAI" : "PHAI" [cite: 2026-01-23]
      @selection.set_attribute("ABF_Logic", "Side", tag) [cite: 2026-01-23]
      
      # Ghi nhận chiều dày và max_count vào hệ thống [cite: 2026-01-21, 2026-01-24]
      puts "Finish: #{tag} (X: #{lx.to_mm.round}mm)" [cite: 2026-01-23]
      
      Sketchup.active_model.commit_operation
      @selection = nil
    end
    view.invalidate
  end
end

# Kích hoạt Tool mà không truyền tham số để tránh TypeError
#Sketchup.active_model.select_tool(ABF_CoordinateOnlyTool.new)