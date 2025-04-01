class MarcaoController < ApplicationController

  set_access_control  'administer_system' => [:report]

  def report
    @title = "MarcAO | Report"
    @report = JSONModel::HTTP.get_json('/marcao/last_report', {})
  end
end
