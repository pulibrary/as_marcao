
# check that marcao is properly configured
unless AppConfig.has_key?(:marcao_flag_field) && AppConfig[:marcao_flag_field] =~ /^boolean_[1,2,3]$/
  raise "marcao plugin configuration error: Set AppConfig[:marcao_flag_field] to a user_defined boolean field to use as the flag for inclusion in the export: boolean_1, boolean_2, or boolean_3"
end

unless AppConfig.has_key?(:marcao_schedule)
  raise "marcao plugin configuration error: Set AppConfig[:marcao_schedule] to a cron string to specify when the exporter should run."
end

ArchivesSpaceService.settings.scheduler.cron(AppConfig[:marcao_schedule], :tags => 'marcao_exporter', :allow_overlapping => false) do
  MarcAOExporter.run
end
