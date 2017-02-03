class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/dev')
    .description("Do a thing!")
    .params()
    .permissions([])
    .returns([200, "something"]) \
  do
    Mp3Converter.new("/home/mst/Download/Julia Kent - Green And Grey.zip").run.to_s
  end

end
