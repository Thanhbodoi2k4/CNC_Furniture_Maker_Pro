# encoding: UTF-8
require 'json'
require 'csv'
module CNCFMP
  module Utils
    MM_TO_INCH = 1.0 / 25.4
    # Đổi mm sang đơn vị nội bộ SketchUp (inch)
    def self.mm(v)
      v.to_f * MM_TO_INCH
    end
    def self.parse_json(str)
      JSON.parse(str)
    rescue
      {}
    end
    def self.validate(params)
      w = params['width'].to_f
      h = params['height'].to_f
      d = params['depth'].to_f
      t = params['thickness'].to_f
      raise 'Kích thước phải lớn hơn 0.' if w <= 0 || h <= 0 || d <= 0
      raise 'Độ dày ván phải > 0.' if t <= 0
      raise 'Độ dày ván quá lớn so với kích thước.' if t * 2 >= w || t * 2 >= h || t * 2 >= d
      raise 'Kích thước quá nhỏ (<100mm).' if w < 100 || h < 100 || d < 100
      true
    end
    def self.cutlist_to_html(list)
      rows = list.map do |p|
        "<tr><td>#{p[:name]}</td><td>#{p[:qty]}</td>" \
        "<td>#{p[:length]}</td><td>#{p[:width]}</td>" \
        "<td>#{p[:thickness]}</td><td>#{p[:edge]}</td>" \
        "<td>#{p[:note]}</td></tr>"
      end.join
      "<table border='1' cellpadding='4' style='border-collapse:collapse;font-size:12px;'>" \
      "<thead><tr><th>Tấm</th><th>SL</th><th>Dài</th><th>Rộng</th><th>Dày</th><th>Dán cạnh</th><th>Ghi chú</th></tr></thead>" \
      "<tbody>#{rows}</tbody></table>"
    end
    def self.export_csv(list, path)
      CSV.open(path, 'w:UTF-8', write_headers: true,
               headers: ['Tên tấm','Số lượng','Dài (mm)','Rộng (mm)','Dày (mm)','Dán cạnh','Ghi chú CNC']) do |csv|
        list.each do |p|
          csv << [p[:name], p[:qty], p[:length], p[:width], p[:thickness], p[:edge], p[:note]]
        end
      end
    end
  end
end
