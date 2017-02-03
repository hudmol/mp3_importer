require 'zip'
require 'id3tag'
require 'tempfile'

class Mp3Converter < Converter

  include JSONModel

  # Returns descriptive metadata for the import type(s) implemented by this
  # Converter.
  def self.import_types(show_hidden = false)
    [
      {
        :name => "mp3",
        :description => "Import a zip file of MP3s"
      }
    ]
  end

  # If this Converter will handle `type` and `input_file`, return an instance.
  def self.instance_for(type, input_file)
    if type == "mp3"
      self.new(input_file)
    else
      nil
    end
  end

  # Process @input_file and load records into @batch.
  def run
    tracks = []

    Mp3TagReader.new(@input_file).each do |track|
      tracks << track
    end

    raise "Track list was empty" if tracks.empty?

    # Create a resource
    resource_uri = "/repositories/12345/resources/import_#{SecureRandom.hex}"
    resource = JSONModel(:resource).from_hash({
                                                'uri' => resource_uri,
                                                'title' => tracks[0].album,
                                                'id_0' => SecureRandom.hex,
                                                'level' => 'collection',
                                                'extents' => [
                                                  {
                                                    'jsonmodel_type' => 'extent',
                                                    'number' => tracks.length.to_s,
                                                    'extent_type' => 'tracks',
                                                    'portion' => 'whole'
                                                  },
                                                ],
                                                'dates' => [
                                                  {
                                                    'jsonmodel_type' => 'date',
                                                    'date_type' => 'single',
                                                    'label' => 'publication',
                                                    'expression' => tracks[0].year.to_s,
                                                  }
                                                ]
                                              })

    @batch << resource

    # Archival objects
    tracks.each_with_index do |track, idx|
      ao_uri = "/repositories/12345/archival_objects/import_#{SecureRandom.hex}"

      ao = JSONModel(:archival_object).from_hash({
                                                   #'uri' => ao_uri,
                                                   #'resource' => {'ref' => resource_uri},
                                                   'level' => 'file',
                                                   'title' => track.title,
                                                   'linked_agents' => [
                                                     {
                                                       'ref' => create_agent(track.artist),
                                                       'role' => 'creator',
                                                     },
                                                   ],
                                                   'dates' => [
                                                     {
                                                       'jsonmodel_type' => 'date',
                                                       'date_type' => 'single',
                                                       'label' => 'publication',
                                                       'expression' => track.year.to_s,
                                                     }
                                                   ],
                                                   'position' => idx,
                                                   'notes' => [
                                                     {
                                                       'jsonmodel_type' => 'note_singlepart',
                                                       'content' => [track.comments],
                                                       'type' => 'physdesc',
                                                     }
                                                   ]
                                                 })


      @batch << ao
    end
  end

  private

  def create_agent(agent_name)
    @seen_agents ||= {}

    return @seen_agents[agent_name] if @seen_agents[agent_name]

    agent_uri = "/agents/people/import_#{SecureRandom.hex}"
    agent = JSONModel(:agent_person).from_hash({
                                                 'uri' => agent_uri,
                                                 'names' => [
                                                   {
                                                     'jsonmodel_type' => 'name_person',
                                                     'primary_name' => agent_name,
                                                     'name_order' => 'direct',
                                                     'sort_name_auto_generate' => true,
                                                     'source' => 'local',
                                                   }
                                                 ],
                                               })

    @batch << agent

    @seen_agents[agent_name] = agent_uri

    agent_uri
  end


  class Mp3TagReader

    Track = Struct.new(:album, :artist, :title, :track_nr, :year, :comments)

    def initialize(input_file)
      @input_file = input_file
    end

    def each
      Zip::File.open(@input_file) do |zip_file|
        zip_file.each do |entry|
          next unless entry.name.end_with?('.mp3')

          Tempfile.open("track") do |mp3|
            begin
              IO.copy_stream(entry.get_input_stream, mp3)

              tag = ID3Tag.read(mp3)

              yield Track.new(tag.album, tag.artist, tag.title, Integer(tag.track_nr), Integer(tag.year), tag.comments)
            ensure
              mp3.unlink
            end
          end
        end
      end
    end

  end

end
