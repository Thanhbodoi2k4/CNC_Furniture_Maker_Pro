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

    def self.download_and_install(url, redirects = 0)
      if url.nil? || url.to_s.strip.empty?
        UI.messagebox('Link tải cập nhật đang trống. Hãy kiểm tra lại version.json trên GitHub.')
        return
      end

      if redirects > 5
        UI.messagebox('Tải xuống thất bại: link cập nhật redirect quá nhiều lần.')
        return
      end

      UI.messagebox("Bắt đầu tải bản cập nhật.\nNếu GitHub báo lỗi, plugin sẽ hiện thông báo chi tiết.")
      
      request = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
      
      # Download action
      request.start do |req, res|
        if res.status_code == 200
          begin
            body = res.body
            if body.nil? || body.bytesize < 100 || body.byteslice(0, 2) != 'PK'
              UI.messagebox("Tải xuống không phải file RBZ hợp lệ.\n\nURL: #{url}\nDung lượng: #{body ? body.bytesize : 0} bytes\n\nHãy kiểm tra link trong version.json phải trỏ trực tiếp tới file .rbz raw.")
              next
            end

            tmp_dir = Dir.tmpdir
            file_path = File.join(tmp_dir, "CNC_Furniture_Maker_Pro_update.rbz")
            
            File.open(file_path, 'wb') do |f|
              f.write(body)
            end
            
            # Cài đặt file rbz
            Sketchup.install_from_archive(file_path)
            
            UI.messagebox("Cập nhật thành công! Vui lòng khởi động lại SketchUp nếu cần thiết.")
            
            # Xóa file tạm
            File.delete(file_path) if File.exist?(file_path)
          rescue => e
            UI.messagebox("Lỗi trong quá trình lưu hoặc cài đặt: #{e.message}")
          end
        elsif [301, 302, 303, 307, 308].include?(res.status_code)
            # Handle redirect
            redirect_url = res.headers['Location'] || res.headers['location']
            if redirect_url
               if redirect_url.start_with?('/')
                 uri = URI.parse(url)
                 redirect_url = "#{uri.scheme}://#{uri.host}#{redirect_url}"
               end
               download_and_install(redirect_url, redirects + 1)
            else
               UI.messagebox("Lỗi redirect nhưng không tìm thấy link.")
            end
        elsif res.status_code == 404
          UI.messagebox("Không tìm thấy file cập nhật trên GitHub (404).\n\nURL đang dùng:\n#{url}\n\nHãy upload CNC_Furniture_Maker_Pro.rbz lên đúng đường dẫn hoặc sửa version.json.")
        else
          UI.messagebox("Tải xuống thất bại. Mã lỗi: #{res.status_code}\nURL: #{url}")
        end
      end
    end
  end
end
