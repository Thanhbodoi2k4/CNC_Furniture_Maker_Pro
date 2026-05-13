# encoding: UTF-8
require 'json'
require 'net/http'
require 'uri'
require 'tmpdir'

module CNCFMP
  module Updater
    # Đường dẫn GitHub thô (raw) trỏ tới file version.json
    UPDATE_URL = 'https://raw.githubusercontent.com/Thanhbodoi2k4/CNC_Furniture_Maker_Pro/main/version.json'

    def self.check_for_update(show_up_to_date_msg = false)
      request = Sketchup::Http::Request.new(UPDATE_URL, Sketchup::Http::GET)
      
      request.start do |req, res|
        if res.status_code == 200
          begin
            data = JSON.parse(res.body)
            remote_version = data['version']
            download_url = data['url']
            notes = data['notes']

            if Gem::Version.new(remote_version) > Gem::Version.new(PLUGIN_VERSION)
              msg = "Có bản cập nhật mới: #{remote_version} (Bản hiện tại: #{PLUGIN_VERSION})\n\n"
              msg += "Ghi chú: #{notes}\n\n"
              msg += "Bạn có muốn tải xuống và cài đặt ngay không?"
              
              result = UI.messagebox(msg, MB_YESNO)
              if result == IDYES
                download_and_install(download_url)
              end
            else
              UI.messagebox("Bạn đang sử dụng phiên bản mới nhất (#{PLUGIN_VERSION}).") if show_up_to_date_msg
            end
          rescue => e
            UI.messagebox("Lỗi khi đọc file cấu hình update: #{e.message}") if show_up_to_date_msg
          end
        else
          UI.messagebox("Không thể kết nối đến máy chủ cập nhật. Mã lỗi: #{res.status_code}") if show_up_to_date_msg
        end
      end
    end

    def self.download_and_install(url)
      UI.messagebox("Đang tiến hành tải xuống bản cập nhật. Vui lòng chờ...")
      
      request = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
      
      # Download action
      request.start do |req, res|
        if res.status_code == 200
          begin
            tmp_dir = Dir.tmpdir
            file_path = File.join(tmp_dir, "CNC_Furniture_Maker_Pro_update.rbz")
            
            File.open(file_path, 'wb') do |f|
              f.write(res.body)
            end
            
            # Cài đặt file rbz
            Sketchup.install_from_archive(file_path)
            
            UI.messagebox("Cập nhật thành công! Vui lòng khởi động lại SketchUp nếu cần thiết.")
            
            # Xóa file tạm
            File.delete(file_path) if File.exist?(file_path)
          rescue => e
            UI.messagebox("Lỗi trong quá trình lưu hoặc cài đặt: #{e.message}")
          end
        elsif res.status_code == 301 || res.status_code == 302
            # Handle redirect
            redirect_url = res.headers["Location"]
            if redirect_url
               download_and_install(redirect_url)
            else
               UI.messagebox("Lỗi redirect nhưng không tìm thấy link.")
            end
        else
          UI.messagebox("Tải xuống thất bại. Mã lỗi: #{res.status_code}")
        end
      end
    end
  end
end
