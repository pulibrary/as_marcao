
# as_marcao

An ArchivesSpace plugin for exporting Archival Objects as MARC XML for selected
Resources on a schedule.


## Overview

The plugin is designed to run under a schedule, specified in configuration (see
below).

Each run will export all of the Archival Objects belonging to all Resources that
have a flag set (a User Defined Boolean field) in one Marc XML file. The top
level tag will be a &lt;collection&gt; tag, then each AO will be a
&lt;record&gt; tag within it.

The Marc XML is exported to a file called `marcao/marcao_export.xml` in
ArchivesSpace's shared data area. Another file is generated called
`marcao/report.json`. This contains metadata about the last export run -- the
one that produced the export file.

Then the export file is uploaded via SFTP using the specified configuration.

Each export run will only export AOs that have been modified since the last
export. To force a full export, remove the `report.json` file.


## Installation

The plugin requires a Gem (net/sftp). After installation run the initialize
script to import the Gem, like this:
```
  # Linux
  ./scripts/initialize-plugin.sh as_marcao
  # Windows
  scripts\initialize-plugin.bat as_marcao
```

The plugin has no other special installation requirements.
No template overrides.
No database migrations.

## Configuration

Sample configuration:
```
  AppConfig[:marcao_schedule] = '22 2 * * *'
  AppConfig[:marcao_flag_field] = 'boolean_1'
  AppConfig[:marcao_sftp_host] = '127.0.0.1'
  AppConfig[:marcao_sftp_user] = 'a_user'
  AppConfig[:marcao_sftp_password] = 'secret password'
  AppConfig[:marcao_sftp_path] = '/remote/path'
```

### marcao_schedule
A cron string that defines when the export will run.
The example says to run at 2:22AM every day.

### marcao_flag_field
The name of the User Defined Boolean field to check to see if a Resource
should be included in the export.
Valid values: `boolean_1`, `boolean_2`, `boolean_3`

### marcao_sftp_host
The hostname or IP address of the SFTP server to upload to.

### marcao_sftp_user
The username to authenticate with on the SFTP server.

### marcao_sftp_password
The password to authenticate with on the SFTP server.

### marcao_sftp_path
The path on the SFTP server to upload the exported records to.


## Backend Endpoints

The plugin provides backend endpoints that allow for running marcao manually.

```
  GET /marcao/export
  GET /marcao/last_report
  GET /repositories/:repo_id/resources/:id/marcao
```

### /marcao/export
Run the export. This runs the whole export process, including the SFTP upload,
just as though it had run under the scheduler.

### /marcao/last_report
Returns the report of the last export as JSON.

### /repositories/:repo_id/resources/:id/marcao
Returns the Marc XML for the Archival Objects under the Resource.
It accepts an optional `since` parameter that specifies a Datetime.
Only AOs modified since that Datetime will be included.
Examples: `since=2023-03-01`, `since=2023-03-01T12:00:00`
