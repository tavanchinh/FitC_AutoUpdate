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

      # Hàm kiểm tra và thực hiện cập nhật
      def check_and_update(server_info_url)
        begin
          # 1. Lấy thông tin phiên bản mới nhất từ Server
          puts "Đang kiểm tra phiên bản mới..."
          remote_info_json = URI.open(server_info_url).read
          remote_info = JSON.parse(remote_info_json)

          remote_version = remote_info['version_code']
          local_version  = get_local_version

          # 2. So sánh phiên bản
          if remote_version > local_version
            msg = "Đã có phiên bản mới: #{remote_info['version_name']}\n"
            msg += "Nội dung: #{remote_info['changelog']}\n\n"
            msg += "Bạn có muốn cập nhật tự động không?"
            
            result = UI.messagebox(msg, MB_YESNO)
            
            if result == IDYES
              # Chạy hàm tải file đã viết ở bước trước
              success = perform_update(remote_info['manifest_url'])
              
              if success
                # Cập nhật lại file version cục bộ sau khi tải xong
                File.write(local_version_file, remote_info_json)
                UI.messagebox("Cập nhật thành công! Vui lòng khởi động lại SketchUp.")
              end
            end
          else
            UI.messagebox("Bạn đang sử dụng phiên bản mới nhất (#{remote_info['version_name']}).")
          end

        rescue => e
          UI.messagebox("Không thể kiểm tra cập nhật: #{e.message}")
        end
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