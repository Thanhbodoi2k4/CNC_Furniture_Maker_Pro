# encoding: UTF-8
# CNC Furniture Maker Pro - Root loader
require 'sketchup.rb'
require 'extensions.rb'
module CNCFMP
  PLUGIN_ID      = 'CNC_Furniture_Maker_Pro'
  PLUGIN_NAME    = 'CNC Furniture Maker Pro'
  PLUGIN_VERSION = '1.1.4'
  PLUGIN_AUTHOR  = 'CNCFMP'
  PLUGIN_DESC    = 'Tạo nội thất CNC chuẩn sản xuất (mm): tủ bếp, tủ áo, giường, bàn, táp...'
  PLUGIN_DIR = File.join(File.dirname(__FILE__), PLUGIN_ID)
  unless file_loaded?(__FILE__)
    ex = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_DIR, 'main.rb'))
    ex.version     = PLUGIN_VERSION
    ex.creator     = PLUGIN_AUTHOR
    ex.description = PLUGIN_DESC
    Sketchup.register_extension(ex, true)
    file_loaded(__FILE__)
  end
end
