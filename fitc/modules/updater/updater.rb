require 'net/http'
require 'open-uri'
require 'json'
require 'fileutils'

module FitC
  module Updater
    class << self
      
      # Đường dẫn file chứa version hiện tại trên máy người dùng
      # File này sẽ được Updater tự động tạo/cập nhật
      def local_version_file
        # Lưu file version ngay tại thư mục updater trên máy khách
        File.join(__dir__, 'version.json')
      end

      # Đọc phiên bản hiện tại từ máy
      def get_local_version
        if File.exist?(local_version_file)
          data = JSON.parse(File.read(local_version_file))
          return data['version_code'] || 0
        end
        0
      end

      def check_and_update(server_info_url)
        puts "--- BẮT ĐẦU KIỂM TRA CẬP NHẬT ---"
        puts "1. URL máy chủ: #{server_info_url}"
        
        begin
          # Bước 1: Kết nối Server
          puts "2. Đang kết nối tới server để lấy version.json..."
          remote_info_json = URI.open(server_info_url).read
          puts "3. Đã nhận dữ liệu từ server: #{remote_info_json}"
          
          remote_info = JSON.parse(remote_info_json)
          remote_version = remote_info['version_code']
          puts "4. Version máy chủ: #{remote_version} (#{remote_info['version_name']})"

          # Bước 2: Kiểm tra bản cục bộ
          local_version = get_local_version
          puts "5. Version máy khách hiện tại: #{local_version}"

          # Bước 3: So sánh
          if remote_version > local_version
            puts "6. Trạng thái: CÓ BẢN MỚI. Đang hiện thông báo hỏi người dùng..."
            
            msg = "Đã có phiên bản mới: #{remote_info['version_name']}\n"
            msg += "Nội dung: #{remote_info['changelog']}\n\n"
            msg += "Bạn có muốn cập nhật tự động không?"
            
            result = UI.messagebox(msg, MB_YESNO)
            
            if result == IDYES
              puts "7. Người dùng chọn YES. Bắt đầu tải manifest..."
              manifest_url = remote_info['manifest_url']
              puts "8. Manifest URL: #{manifest_url}"
              
              success = perform_update(manifest_url)
              
              if success
                puts "9. Tải file hoàn tất. Đang cập nhật file version cục bộ..."
                File.write(local_version_file, remote_info_json)
                puts "10. CẬP NHẬT THÀNH CÔNG!"
                UI.messagebox("Cập nhật thành công! Vui lòng khởi động lại SketchUp.")
              else
                puts "LỖI: Quá trình perform_update thất bại."
              end
            else
              puts "7. Người dùng chọn NO. Hủy bỏ cập nhật."
            end
          else
            puts "6. Trạng thái: ĐÃ LÀ BẢN MỚI NHẤT. Kết thúc."
            UI.messagebox("Bạn đang sử dụng phiên bản mới nhất (#{remote_info['version_name']}).")
          end

        rescue => e
          puts "!!! LỖI TẠI BƯỚC NÀO ĐÓ !!!"
          puts "Thông tin lỗi: #{e.message}"
          puts "Vị trí lỗi (Backtrace):"
          puts e.backtrace.join("\n").first(500) # Chỉ in 500 ký tự đầu của lỗi
          UI.messagebox("Không thể kiểm tra cập nhật. Xem Ruby Console để biết chi tiết.")
        end
        puts "--- KẾT THÚC QUY TRÌNH ---"
      end

      private

      def base_plugins_dir
        # Lệnh này đưa ta về thư mục Plugins (nơi chứa thư mục fitc)
        File.expand_path('../../..', __dir__)
      end

      def perform_update(manifest_url)
        base_dir = base_plugins_dir
        manifest_json = URI.open(manifest_url).read
        files_to_update = JSON.parse(manifest_json)

        files_to_update.each do |file_info|
          # Tạo đường dẫn đích: Plugins + path trong JSON
          local_path = File.join(base_dir, file_info['path'])
          
          # Tự động tạo thư mục nếu chưa có
          FileUtils.mkdir_p(File.dirname(local_path))
          
          # Tải và ghi đè
          new_content = URI.open(file_info['url']).read
          File.open(local_path, "wb") { |f| f.write(new_content) }
        end
        true
      rescue => e
        puts "Lỗi thực thi tải file: #{e.message}"
        false
      end

    end
  end
end