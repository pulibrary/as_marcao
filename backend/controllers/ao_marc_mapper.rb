class ArchivesSpaceService < Sinatra::Base
  Endpoint.get('/repositories/:repo_id/archival_objects/:id/marc')
    .description("Get a MARC version of the AO")
    .params(
            ["id", :id],
            ["repo_id", :repo_id],
            )
    .permissions([])
    .returns([200, "MARC"]) \
  do
    json = resolve_references(ArchivalObject.to_jsonmodel(params[:id]), ['subjects', 'linked_agents', 'top_container'])

    [
     200,
     {"Content-Type" => "text/xml"},
     AOMarcMapper.map(json)
    ]
  end
end
