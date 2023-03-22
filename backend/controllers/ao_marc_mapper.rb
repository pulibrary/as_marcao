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
    json = resolve_references(ArchivalObject.to_jsonmodel(params[:id]), AOMarcMapper.resolves)

    [
     200,
     {"Content-Type" => "text/xml"},
     AOMarcMapper.to_marc(json)
    ]
  end

  Endpoint.get('/repositories/:repo_id/resources/:id/marcao')
    .description("Get MARC versions of this Resource's AOs wrapped in a collection tag")
    .params(
            ["id", :id],
            ["repo_id", :repo_id],
            ["since", String, "Only include AOs modified since the specified date/time", :optional => true]
            )
    .permissions([])
    .returns([200, "MARC"]) \
  do
    ao_ds = ArchivalObject.filter(:root_record_id => params[:id])

    if since = params[:since]
      ao_ds = ao_ds.where{system_mtime > since}
    end

    ao_jsons = resolve_references(ArchivalObject.sequel_to_jsonmodel(ao_ds.all), AOMarcMapper.resolves)
    [
     200,
     {"Content-Type" => "text/xml"},
     AOMarcMapper.collection_to_marc(ao_jsons)
    ]
  end
end
