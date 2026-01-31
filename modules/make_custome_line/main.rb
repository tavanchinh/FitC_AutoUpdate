require 'json'

module FitC
  module MakeCustomeLine
    module_function

    def get_path(file)
      File.join(File.dirname(__FILE__), file)
    end

    def create_custom_line
      # --- BƯỚC KIỂM TRA KEY ---
      FitC::LicenseManager.authorized? do
        # Toàn bộ logic cũ được đưa vào trong block này
        
        fixed_group_name = "ABF_X" 
        model = Sketchup.active_model
        selection = model.selection

        # Kiểm tra đối tượng được chọn
        group_a = selection.find { |e| e.is_a?(Sketchup::Group) }
        group_b_input = selection.find { |e| e.is_a?(Sketchup::Group) && e != group_a }
        lines_input = selection.grep(Sketchup::Edge)

        if group_a.nil? || (group_b_input.nil? && lines_input.empty?)
          UI.messagebox("Vui lòng chọn: Group đích (A) và (Group B hoặc các Line)!")
          next # Dùng next thay cho return trong block
        end

        # Cấu hình Dialog
        dialog = UI::HtmlDialog.new({
          :dialog_title => "FitC - Tạo đường tùy biến",
          :width => 380, :height => 280,
          :style => UI::HtmlDialog::STYLE_DIALOG
        })

        html_path = get_path('web/dialog.html')
        if File.exist?(html_path)
          dialog.set_html(File.read(html_path))
        else
          UI.messagebox("Không tìm thấy file dialog.html!")
          next
        end

        dialog.show do
          layer_names = model.layers.map(&:name).sort
          dialog.execute_script("populateLayers(#{JSON.generate(layer_names)})")
        end

        dialog.add_action_callback("get_layers_from_ruby") { |action_context|
          layer_names = Sketchup.active_model.layers.map(&:name).sort
          dialog.execute_script("populateLayers(#{JSON.generate(layer_names)})")
        }

        dialog.add_action_callback("process_logic") { |action_context, layer_name|
          model.start_operation('Make Custome Line', true)
          
          begin
            target_layer = model.layers.add(layer_name)
            target_group = nil

            if group_b_input
              relative_transform = group_a.transformation.inverse * group_b_input.transformation
              target_group = group_a.entities.add_instance(group_b_input.definition, relative_transform)
              group_b_input.erase!
            else
              temp_group = model.active_entities.add_group
              lines_input.each { |edge| temp_group.entities.add_edges(edge.start.position, edge.end.position) }
              relative_transform = group_a.transformation.inverse * temp_group.transformation
              target_group = group_a.entities.add_instance(temp_group.definition, relative_transform)
              temp_group.erase!
              lines_input.each { |edge| edge.erase! if edge.valid? }
            end

            target_group.name = fixed_group_name
            target_group.layer = target_layer
            target_group.definition.entities.each { |ent| ent.layer = target_layer }

            model.commit_operation
            dialog.close
            puts "Thành công! Đối tượng đã được đưa vào Group A với tên '#{fixed_group_name}'."
            
          rescue => e
            model.abort_operation
            UI.messagebox("Lỗi thực thi: #{e.message}")
          end
        }
      end # Kết thúc block authorized?
    end
  end
end