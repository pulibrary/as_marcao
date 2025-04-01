ArchivesSpace::Application.extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

if AppConfig.has_key?(:marcao_sftp_host) &&
    AppConfig.has_key?(:marcao_sftp_user) &&
    AppConfig.has_key?(:marcao_sftp_password) &&
    AppConfig.has_key?(:marcao_sftp_path)
  AppConfig[:marcao_sftp_enabled] = true
else
  AppConfig[:marcao_sftp_enabled] = false
end
