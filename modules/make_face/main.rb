module FitC
  module MakeFace
    # Sử dụng module_function để có thể gọi FitC::MakeFace.create_faces
    module_function 

    def create_faces # Bỏ 'self.' ở đây khi đã dùng module_function
      FitC::LicenseManager.authorized? do
        model = Sketchup.active_model
        selection = model.selection
        
        # 1. Lấy tất cả các Edges từ vùng chọn
        edges = selection.grep(Sketchup::Edge)
        
        if edges.empty?
          UI.messagebox("Vui lòng chọn các đường Line (Edges) để tạo mặt!")
          return # Bây giờ return đã hợp lệ vì nằm trong hàm def
        end

        model.start_operation('Hàm Tạo Mặt', true)

        begin
          # 2. Đếm số mặt trước khi thực hiện
          faces_before = model.active_entities.grep(Sketchup::Face).size

          # 3. Thực hiện tìm mặt
          edges.each do |edge|
            edge.find_faces if edge.valid?
          end

          # 4. Tính toán kết quả
          faces_after = model.active_entities.grep(Sketchup::Face).size
          new_faces_count = faces_after - faces_before

          model.commit_operation
          
          if new_faces_count > 0
            puts "Thành công: Đã tạo thêm #{new_faces_count} mặt mới."
          else
            puts "Thông báo: Không có mặt mới nào được tạo (kiểm tra lại độ hở hoặc đồng phẳng)."
          end

        rescue => e
          model.abort_operation
          UI.messagebox("Có lỗi xảy ra: #{e.message}")
        end
      
      end

      
    end
  end
end