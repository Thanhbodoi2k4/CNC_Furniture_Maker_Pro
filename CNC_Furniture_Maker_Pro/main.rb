# encoding: UTF-8
require 'sketchup.rb'

module CNCFMP
  LIB_DIR = File.join(PLUGIN_DIR, 'lib')
  require File.join(LIB_DIR, 'utils.rb')
  require File.join(LIB_DIR, 'geometry.rb')
  require File.join(LIB_DIR, 'hardware.rb')
  require File.join(LIB_DIR, 'cabinet_builder.rb')
  require File.join(LIB_DIR, 'updater.rb')

  @dialog = nil
  @last_cutlist = []

  def self.show_dialog
    if @dialog && @dialog.visible?
      @dialog.bring_to_front
      return
    end

    @dialog = UI::HtmlDialog.new(
      dialog_title:    'CNC Furniture Maker Pro',
      preferences_key: 'cncfmp_dialog',
      scrollable:      true,
      resizable:       true,
      width:           620,
      height:          780,
      min_width:       500,
      min_height:      600,
      style:           UI::HtmlDialog::STYLE_DIALOG
    )
    @dialog.set_file(File.join(PLUGIN_DIR, 'dialog.html'))

    @dialog.add_action_callback('build_furniture') do |_ctx, json_params|
      begin
        params = Utils.parse_json(json_params)
        cutlist = CabinetBuilder.build(params)
        @last_cutlist = cutlist
        html = Utils.cutlist_to_html(cutlist)
        @dialog.execute_script("showCutlist(#{html.inspect});")
      rescue => e
        UI.messagebox("Lỗi: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
      end
    end

    @dialog.add_action_callback('export_csv') do |_ctx, _|
      if @last_cutlist.nil? || @last_cutlist.empty?
        UI.messagebox('Chưa có cutlist. Hãy tạo model trước.')
      else
        path = UI.savepanel('Lưu cutlist CSV', Dir.home, 'cutlist.csv')
        if path
          Utils.export_csv(@last_cutlist, path)
          UI.messagebox("Đã lưu: #{path}")
        end
      end
    end

    @dialog.add_action_callback('check_update') do |_ctx, _|
      Updater.check_for_update(true)
    end

    @dialog.show
  end

  def self.create_toolbar
    tb = UI::Toolbar.new('CNC Furniture Maker')
    cmd = UI::Command.new('CNC Furniture Maker Pro') { show_dialog }
    cmd.tooltip   = 'CNC Furniture Maker Pro'
    cmd.status_bar_text = 'Tạo đồ nội thất CNC tự động (mm)'
    cmd.small_icon = File.join(PLUGIN_DIR, 'icons', 'icon_24.png')
    cmd.large_icon = File.join(PLUGIN_DIR, 'icons', 'icon_32.png')
    tb.add_item(cmd)
    tb.show

    menu = UI.menu('Plugins').add_submenu('CNC Furniture Maker Pro')
    menu.add_item('Mở công cụ') { show_dialog }
    menu.add_item('Kiểm tra cập nhật...') { Updater.check_for_update(true) }
  end

  unless file_loaded?(__FILE__)
    create_toolbar
    file_loaded(__FILE__)
    # Tự động check update ngầm khi load plugin (sau 5 giây để tránh giật lag lúc mở)
    UI.start_timer(5.0, false) do
      Updater.check_for_update(false)
    end
  end
end
