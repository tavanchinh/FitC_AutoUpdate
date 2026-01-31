module FitC
  module FindNonLabel
    
    # Hàm chính của bạn đã được đưa vào Module
    def self.find_group_without_layer(target_layer_name = "ABF_Label")
      FitC::LicenseManager.authorized? do 
        model = Sketchup.active_model
        selection = model.selection

        # 1. Kiểm tra xem người dùng có đang chọn gì không
        if selection.empty?
          UI.messagebox("Vui lòng chọn vùng cần kiểm tra trước khi chạy lệnh.")
          return
        end

        # Lấy danh sách tất cả các group trong selection
        groups = selection.grep(Sketchup::Group)
        groups_without_label = []

        groups.each do |group|
          has_label = false
          # Duyệt qua từng thực thể bên trong group để tìm layer mục tiêu
          group.entities.each do |entity|
            if entity.layer.name == target_layer_name
              has_label = true
              break 
            end
          end

          if !has_label
            groups_without_label.push(group)
          end
        end

        # Thông báo kết quả
        if groups_without_label.empty?
          UI.messagebox("Tuyệt vời! Không tìm thấy chi tiết nào thiếu layer #{target_layer_name}")
        else
          model.selection.clear
          model.selection.add(groups_without_label)
          UI.messagebox("Tìm thấy #{groups_without_label.length} chi tiết thiếu nhãn. Các chi tiết này đã được chọn!")
        end
      end
      
      
    end
  end
end