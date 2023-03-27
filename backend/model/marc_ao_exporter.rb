require 'date'
require 'net/sftp'

class MarcAOExporter

  # allowing for transactions in flight
  WINDOW_SECONDS = 5

  def self.run
    start = Time.now

    Log.info("MARC AO Exporter running")

    res_ids = UserDefined.filter(AppConfig[:marcao_flag_field].intern => 1).filter(Sequel.~(:resource_id => nil)).select(:resource_id).all.map{|r| r[:resource_id]}

    ao_ds = ArchivalObject.any_repo.filter(:root_record_id => res_ids)

    if report = last_report
      report = ASUtils.json_parse(File.read(report_file_path))
      since = DateTime.parse(last_report['export_started_at']) - WINDOW_SECONDS
      ao_ds = ao_ds.where{system_mtime > since}
    end

    ao_jsons = []

    ao_ds.all.group_by(&:repo_id).each do |repo_id, aos|
      RequestContext.open(:repo_id => repo_id) do
        ao_jsons += URIResolver.resolve_references(ArchivalObject.sequel_to_jsonmodel(aos), MarcAOMapper.resolves)
      end
    end

    File.open(export_file_path + ".tmp", 'w:UTF-8') do |fh|
      fh.write(MarcAOMapper.collection_to_marc(ao_jsons))
    end

    File.rename(export_file_path + ".tmp", export_file_path)

    if AppConfig.has_key?(:marcao_sftp_enabled)
      max_retries = 10

      max_retries.times do |retry_count|
        if retry_count > 0
          Log.info("Retrying SFTP upload (retry number #{retry_count})")
        end

        Net::SFTP.start(AppConfig[:marcao_sftp_host], AppConfig[:marcao_sftp_user], { password: AppConfig[:marcao_sftp_password] }) do |sftp|
          sftp.upload!(export_file_path, File.join(AppConfig[:marcao_sftp_path], File.basename(export_file_path)))
        end
        break
      rescue
        Log.warn("Upload to SFTP failed: #{$!}")
        if (retry_count + 1) < max_retries
          remaining_retries = max_retries - retry_count - 1
          $stderr.puts("Will retry #{remaining_retries} more time#{((remaining_retries == 1) ? '' : 's')}")
          sleep 30
        else
          Log.error("SFTP upload has failed #{max_retries} times.  Giving up!")
        end
      end
    end

    report = {
      :status => 'ok',
      :export_started_at => start,
      :export_completed_at => Time.now,
      :export_file => export_file_path,
      :resource_ids_selected => res_ids.join(','),
      :archival_objects_exported => ao_jsons.length,
    }

    File.open(report_file_path + ".tmp", 'w:UTF-8') do |fh|
      fh.write(report.to_json)
    end

    File.rename(report_file_path + ".tmp", report_file_path)

    report
  end

  def self.last_report
    if File.exist?(report_file_path)
      ASUtils.json_parse(File.read(report_file_path))
    end
  end

  def self.export_file_path
    File.join(basedir, 'marcao_export.xml')
  end

  def self.report_file_path
    File.join(basedir, 'report.json')
  end

  def self.basedir
    if @basedir
      return @basedir
    end

    @basedir = File.join(AppConfig[:shared_storage], "marcao")
    FileUtils.mkdir_p(@basedir)

    @basedir
  end

end
