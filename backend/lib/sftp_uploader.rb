require File.join(File.dirname(__FILE__), 'lib', 'jzlib-1.1.3.jar')
require File.join(File.dirname(__FILE__), 'lib', 'sshj-0.30.0.jar')
require File.join(File.dirname(__FILE__), 'lib', 'asn-one-0.4.0.jar')
require File.join(File.dirname(__FILE__), 'lib', 'bcpkix-jdk15on-1.66.jar')
require File.join(File.dirname(__FILE__), 'lib', 'slf4j-api-1.7.7.jar')
require File.join(File.dirname(__FILE__), 'lib', 'eddsa-0.3.0.jar')
require File.join(File.dirname(__FILE__), 'lib', 'bcprov-jdk15on-1.66.jar')

class SFTPUploader
  def initialize(hostname, username, password, opts = {})
    @ssh_client = Java::net.schmizz.sshj.SSHClient.new
    @ssh_client.addHostKeyVerifier(Java::net.schmizz.sshj.transport.verification.PromiscuousVerifier.new)

    if (connect_timeout = opts.fetch(:connect_timeout, nil))
      @ssh_client.set_connect_timeout(connect_timeout)
    end

    @ssh_client.connect(hostname, 22)

    @ssh_client.authPassword(username, password)

    @sftp_client = @ssh_client.newSFTPClient
  end

  def upload(source_file, target_path)
    @sftp_client.put(source_file, target_path)
  end

  def delete(path_to_file)
    @sftp_client.rm(path_to_file)
  end

  def finish!
    @sftp_client.close
    @ssh_client.close
  end
end
