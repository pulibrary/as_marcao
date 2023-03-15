
# as_marcao

An ArchivesSpace plugin for exporting Archival Objects as MARC XML for selected
Resources on a schedule.

# Requirements

  1. A user with sufficient permissions (to be determined) will access a screen
     in the ArchivesSpace staff interface to find and select, or deselect,
     Resource records to be included in the export.
  2. At a time scheduled in the ArchivesSpace configuration (likely once a
     night), the exporter will find all Archival Objects belonging to the
     Resources selected in 1 above, and will export any that have changed since
     the last export.
  3. The Archival Objects will be exported in MARC XML format. The specification
     for the mapping is defined by this existing implementation:
     https://github.com/pulibrary/aspace_helpers/blob/main/reports/aspace2alma/get_ao2MARC_data.rb
  4. Each export run will generate one MARC XML file with a top level
     <collection> tag and then each Archival Object included in the export in a
     <record> tag within the <collection>.
  5. The exported file will be delivered via FTP. The FTP settings will be set
     in the ArchivesSpace configuration


For 1. use a user_defined boolean field, or maybe a new field,  on the resource
for now, and maybe a screen to see resources with the flag set.
