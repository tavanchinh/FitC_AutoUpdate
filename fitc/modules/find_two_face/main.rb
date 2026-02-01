require 'json'

module FitC
  module FindTwoFace
    class << self
      def run_panel_manager
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end

        model = Sketchup.active_model
        entities_to_check = model.selection.empty? ? model.active_entities : model.selection
        @panel_data = {} 

        entities_to_check.each do |ent|
          next unless ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)
          defn = ent.is_a?(Sketchup::ComponentInstance) ? ent.definition : ent.entities.parent
          faces = defn.entities.grep(Sketchup::Face)
          next if faces.empty?
          
          main_face = faces.max_by { |f| f.area }
          main_normal = main_face.normal
          distances = faces.select { |f| f.normal.parallel?(main_normal) }.map { |f| f.vertices[0].position.distance_to_plane(main_face.plane) }
          max_thickness = distances.max || 0
          
          has_top, has_bottom = false, false
          defn.entities.each do |sub_ent|
            next unless sub_ent.is_a?(Sketchup::ComponentInstance) || sub_ent.is_a?(Sketchup::Group)
            next if (sub_ent.name + sub_ent.definition.name).downcase.include?("sidedrill")
            dist = sub_ent.bounds.center.distance_to_plane(main_face.plane)
            if dist < 1.0.mm; has_bottom = true
            elsif (dist - max_thickness).abs < 1.0.mm; has_top = true
            end
          end

          if has_top && has_bottom
            @panel_data[ent.entityID.to_s] = {
              name: ent.name.empty? ? "Panel #{ent.entityID}" : ent.name,
              material: ent.material ? ent.material.name : "Chưa có màu",
              thickness: max_thickness.to_mm.round(1)
            }
          end
        end

        if @panel_data.empty?
          UI.messagebox("Không tìm thấy tấm ván 2 mặt nào!")
          return
        end

        show_dialog
      end

      def show_dialog
        @dialog = UI::HtmlDialog.new({
          :dialog_title => "FitC - Quản lý tấm 2 mặt",
          :width => 520, :height => 750,
          :style => UI::HtmlDialog::STYLE_DIALOG
        })

        # Đường dẫn file HTML cùng thư mục với file ruby này
        html_path = File.join(__dir__, 'ui.html')
        @dialog.set_file(html_path)

        # HTML báo đã load xong DOM
        @dialog.add_action_callback("ready") { |ctx| send_data_to_ui }

        @dialog.add_action_callback("call_ruby") { |ctx, type, ids, suffix|
          handle_actions(type, ids, suffix)
        }

        @dialog.show
      end

      def send_data_to_ui
        # Gom nhóm theo vật liệu giống bản gốc của bạn
        grouped = @panel_data.group_by { |id, info| info[:material] }
        # Chuyển thành JSON để truyền sang JS an toàn
        @dialog.execute_script("renderTable(#{grouped.to_json})")
      end

      def handle_actions(type, ids, suffix)
        model = Sketchup.active_model
        model.start_operation('CNC V12', true)
        target_ents = ids.map { |id| model.find_entity_by_id(id.to_i) }.compact

        case type
        when "select"
          model.selection.clear; model.selection.add(target_ents)
        when "update_mat"
          target_ents.each do |ent|
            old_mat = ent.material
            curr_name = old_mat ? old_mat.name : "Default"
            new_name = curr_name.end_with?(suffix) ? curr_name : (curr_name + suffix)
            ent.set_attribute("CNC_Params", "OriginalMaterial", curr_name) unless curr_name.end_with?(suffix)
            new_mat = model.materials[new_name] || model.materials.add(new_name)
            if old_mat && new_mat.texture.nil?
              new_mat.color = old_mat.color
              new_mat.texture = old_mat.texture.filename if old_mat.texture
            end
            ent.material = new_mat
          end
          @dialog.execute_script("showToast('Đã đổi màu thành công!')")
        when "restore_mat"
          target_ents.each do |ent|
            orig = ent.get_attribute("CNC_Params", "OriginalMaterial")
            ent.material = (orig == "Default") ? nil : model.materials[orig] if orig
          end
          @dialog.execute_script("showToast('Đã khôi phục màu gốc!')")
        end
        model.commit_operation
      end
    end
  end
end