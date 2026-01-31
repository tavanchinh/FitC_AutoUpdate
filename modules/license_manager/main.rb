require 'net/http'
require 'uri'
require 'json'

module FitC
  module LicenseManager
    # Cấu hình hệ thống
    @web_app_url = "https://script.google.com/macros/s/AKfycbxt71sDL-AcdOnlxRUsG_hSkNSU-8IEILqGYRG0ffOl7e9Ch7VgnFIFU6CJcgnGqXxrnA/exec"
    @license_path = File.join(File.dirname(__FILE__), "fitc_license.json")
    @is_authorized = nil
    @is_processing = false
    @is_checking_now = false

    # Hàm kiểm tra bản quyền chính
    def self.authorized?(&block)
      return (block.call if block; true) if @is_authorized == true

      data = get_license_data
      saved_key = data["license_key"] || ""
      saved_hwid = data["hwid"] || ""
      saved_date = data["last_check_date"] || ""
      current_hwid = self.get_hwid
      today = Time.now.strftime("%Y-%m-%d")

      # 1. Nếu chưa có Key hoặc đổi máy: Bắt kích hoạt lại
      if saved_key.empty? || saved_hwid != current_hwid
        show_activation_dialog(&block)
        return false
      end

      # 2. Nếu là ngày mới: Kiểm tra âm thầm với Server
      if saved_date != today
        puts "FitC: Ngay cu (#{saved_date}), dang kiem tra lai voi Server..."
        UI.start_timer(0.1, false) { validate_silent(saved_key, current_hwid, today, &block) }
        return false
      end

      # 3. Mọi thứ hợp lệ
      @is_authorized = true
      block.call if block
      true
    end

    private

    # ✅ Logic kiểm tra với cơ chế chặn callback lặp
    def self.validate_silent(key, hwid, today, &block)
      # CHẶN: Nếu đang có một tiến trình kiểm tra khác chạy rồi thì thôi
      return if @is_checking_now 
      @is_checking_now = true

      show_loading_dialog
      
      # ✅ QUAN TRỌNG: Tạo wrapper để đảm bảo block chỉ chạy 1 lần
      block_executed = false
      safe_block = Proc.new do |status, error_msg|
        next if block_executed  # ✅ Chặn chạy lần 2
        block_executed = true
        block.call(status, error_msg) if block
      end
      
      UI.start_timer(0.5, false) do
        begin
          is_valid = self.validate_with_server(key, hwid)
          
          # Dọn dẹp UI
          self.close_loading_dialog
          @is_checking_now = false 
          @is_processing = false

          if is_valid
            save_license_data(key, today)
            @is_authorized = true
            safe_block.call(:success, nil)  # ✅ Dùng safe_block
          else
            @is_authorized = false
            safe_block.call(:failed, nil)  # ✅ Dùng safe_block
          end

        rescue => e
          # XỬ LÝ LỖI
          self.close_loading_dialog
          @is_checking_now = false
          @is_processing = false
          
          puts "FitC Connection Error: #{e.message}"
          safe_block.call(:error, e.message)  # ✅ Dùng safe_block
        end
      end
    end

    # Giao thức kết nối
    def self.validate_with_server(key, hwid)
      url_string = "#{@web_app_url}?key=#{key}&hwid=#{hwid}"
      
      begin
        uri = URI.parse(url_string)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 5 
        http.read_timeout = 5
        
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        
        if response.code == "302" || response.code == "301"
          new_url = response['location']
          response = Net::HTTP.get_response(URI.parse(new_url))
        end
        
        result = response.body.strip
        return result == "VALID"
        
      rescue => e
        puts "!!! LOI MANG: #{e.message}"
        return false
      end
    end

    def self.show_loading_dialog
      @loading_dialog = UI::HtmlDialog.new({
        :dialog_title => "FitC Security",
        :width => 220, :height => 150,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })
      
      html = <<-HTML
        <html>
        <style>
          body { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; font-family: sans-serif; background-color: #fff; overflow: hidden; }
          .loader { border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 30px; height: 30px; animation: spin 1s linear infinite; margin-bottom: 12px; }
          @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
          span { font-size: 13px; color: #555; font-weight: bold; }
        </style>
        <body><div class="loader"></div><span>Đang kiểm tra...</span></body>
        </html>
      HTML
      
      @loading_dialog.set_html(html)
      @loading_dialog.center
      @loading_dialog.show
    end

    def self.close_loading_dialog
      @loading_dialog.close if @loading_dialog
      @loading_dialog = nil
    end

    def self.get_hwid
      @cached_hwid ||= begin
        require 'win32ole'
        wmi = WIN32OLE.connect("winmgmts://")
        id = ""
        wmi.ExecQuery("SELECT UUID FROM Win32_ComputerSystemProduct").each { |r| id = r.UUID.strip }
        id.length > 10 ? id : (ENV['COMPUTERNAME'] || "PC_UNKNOWN")
      rescue
        `wmic csproduct get uuid`.split.last rescue (ENV['COMPUTERNAME'] || "PC_UNKNOWN")
      end
    end

    def self.save_license_data(key, date)
      File.write(@license_path, JSON.pretty_generate({
        "license_key" => key,
        "last_check_date" => date,
        "hwid" => get_hwid
      }))
    end

    def self.get_license_data
      JSON.parse(File.read(@license_path)) rescue {}
    end

    def self.show_activation_dialog(&block)
      @activation_dialog = UI::HtmlDialog.new({
        :dialog_title => "Kích hoạt bản quyền FitC",
        :width => 420, :height => 300,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })

      html = <<-HTML
        <html>
        <head>
        <style>
          body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            padding: 20px; background-color: #f9f9f9; color: #333;
            display: flex; flex-direction: column; align-items: center;
          }
          h2 { color: #2c3e50; font-size: 18px; margin-bottom: 20px; }
          .input-group { width: 100%; margin-bottom: 20px; }
          input { 
            width: 100%; padding: 12px; border: 2px solid #ddd; 
            border-radius: 8px; font-size: 14px; outline: none;
            transition: border-color 0.3s; box-sizing: border-box;
          }
          input:focus { border-color: #3498db; }
          .btn {
            background-color: #3498db; color: white; padding: 10px 25px;
            border: none; border-radius: 6px; cursor: pointer;
            font-weight: bold; font-size: 14px; transition: background 0.3s;
          }
          .btn:hover { background-color: #2980b9; }
          .btn:disabled {
            background-color: #95a5a6;
            cursor: not-allowed;
          }
          .footer { margin-top: 15px; font-size: 11px; color: #95a5a6; }
        </style>
        </head>
        <body>
          <h2>Kích hoạt FitC</h2>
          <div class="input-group">
            <input type="text" id="license_key" placeholder="Dán mã kích hoạt vào đây..." spellcheck="false">
          </div>
          <button class="btn" id="activateBtn" onclick="submitKey()">KÍCH HOẠT NGAY</button>
          <div class="footer">Hardware ID: #{get_hwid}</div>

          <script>
            let isSubmitting = false;
            
            function submitKey() {
              if (isSubmitting) return;
              
              const key = document.getElementById('license_key').value.trim();
              if (key === "") {
                alert("Vui lòng nhập mã!");
                return;
              }
              
              isSubmitting = true;
              document.getElementById('activateBtn').disabled = true;
              document.getElementById('activateBtn').textContent = 'Đang xử lý...';
              
              sketchup.activate(key);
            }
            
            document.getElementById('license_key').addEventListener('keypress', function (e) {
              if (e.key === 'Enter') submitKey();
            });
          </script>
        </body>
        </html>
      HTML

      @activation_dialog.set_html(html)
      @activation_dialog.center
      
      # ✅ Callback với cơ chế chặn thực thi lặp
      callback_executed = false  # ✅ Biến chặn callback chạy 2 lần
      
      @activation_dialog.add_action_callback("activate") { |action_context, key|
        # ✅ CHẶN NẾU ĐÃ CHẠY RỒI
        next if callback_executed
        callback_executed = true
        
        next if @is_processing 
        @is_processing = true
        @activation_dialog.close
        
        # ✅ Tạo một lần duy nhất block xử lý kết quả
        result_handled = false
        
        validate_silent(key, get_hwid, Time.now.strftime("%Y-%m-%d")) do |status, error_msg|
          next if result_handled  # ✅ Chặn xử lý kết quả 2 lần
          result_handled = true
          @is_processing = false
          
          case status
          when :success
            UI.messagebox("Kích hoạt bản quyền FitC thành công!")
            block.call if block
          when :failed
            UI.messagebox("Mã kích hoạt không chính xác!")
            # Nếu muốn cho nhập lại:
            # show_activation_dialog(&block)
          when :error
            UI.messagebox("Không thể kết nối Server. Vui lòng kiểm tra internet!\nChi tiết: #{error_msg}")
          end
        end
      }

      @activation_dialog.show
    end
  end
end