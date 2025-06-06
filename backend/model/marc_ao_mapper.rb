# This mapping code is adapted from an earlier implementation found here:
#   https://github.com/pulibrary/aspace_helpers/blob/main/reports/aspace2alma/get_ao2MARC_data.rb
#
# The `self.map` method expects a JSONModel rendering of an Archival Object with the following
# fields resolved: subjects, linked_agents, top_container

require 'nokogiri'

class MarcAOMapper
  def self.resolves
    [
      'subjects',
      'linked_agents',
      'top_container',
      'top_container::container_locations'
    ]
  end

  #removes EAD markup from the output
  def self.remove_tags(text)
    text.to_s.gsub(%r{</?[\D\S]+?>}, '')
  end

  def self.xml_escape(text)
    encoded = text.to_s.encode(:xml => :text)

    # incoming text might have been partially encoded already.  Where we've doubled
    # up, revert our encoding.
    #
    # fish &amp;amp; chips --> fish &amp; chips
    encoded.gsub(/&([a-z]+?);\1;/, '&\1;')
  end

  def self.collection_to_marc(ao_jsons)
    header = '<collection xmlns="http://www.loc.gov/MARC21/slim"
                          xmlns:marc="http://www.loc.gov/MARC21/slim"
                          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd">'
    footer = '</collection>'

    records = ao_jsons.map {|json| to_marc(json)}.join("\n")

    [header, records, footer].join("\n")
  end

  def self.to_marc(json)
    default_restriction = 'Collection is open for research use.'

    get_ao = json
    ref_id = get_ao['ref_id']
    title = get_ao['title']

    date_type = 'n'
    date1 = '    '
    date2 = '    '

    unless get_ao['dates'].empty?
      date_type = get_ao['dates'][0]['date_type']
      tag008_date_type =
        if date_type.match(/undated|(dates not examined)/i) || get_ao.dig('dates', 0, 'begin').nil?
          'n'
        else
          'e'
        end

      date1 = if get_ao.dig('dates', 0, 'begin')
                get_ao['dates'][0]['begin'].gsub(/(^)(\d{4})(.*$)/, '\2')
              else
                '    ' # 4 blanks
              end
      date2 = if get_ao.dig('dates', 0, 'end')
                get_ao['dates'][0]['end'].gsub(/(^)(\d{4})(.*$)/, '\2')
              else
                date1
              end
    end

    language = get_ao.dig('lang_materials', 0, 'language_and_script', 'language')
    tag008_langcode = language || 'eng'

    # process the notes requested
    notes = get_ao['notes']
    restrictions_hash = notes.select { |hash| hash['type'] == 'accessrestrict' }
    restriction_note = restrictions_hash.map do |restriction|
      remove_tags(restriction['subnotes'][0]['content'].gsub(/[\r\n]+/, ' '))
    end
    scope_hash = notes.select { |hash| hash['type'] == 'scopecontent' }
    scope_notes = scope_hash.map { |scope| remove_tags(scope['subnotes'][0]['content'].gsub(/[\r\n]+/, ' ')) }
    related_hash = notes.select { |hash| hash['type'] == 'relatedmaterial' }
    related_notes = related_hash.map do |related|
      remove_tags(related['subnotes'][0]['content'].gsub(/[\r\n]+/, ' '))
    end
    acq_hash = notes.select { |hash| hash['type'] == 'acqinfo' }
    acq_notes = acq_hash.map { |acq| remove_tags(acq['subnotes'][0]['content'].gsub(/[\r\n]+/, ' ')) }
    bioghist_hash = notes.select { |hash| hash['type'] == 'bioghist' }
    bioghist_notes = bioghist_hash.map do |bioghist|
      remove_tags(bioghist['subnotes'][0]['content'].gsub(/[\r\n]+/, ' '))
    end
    processinfo_hash = notes.select { |hash| hash['type'] == 'processinfo' }
    processinfo_notes = processinfo_hash.map do |processinfo|
      remove_tags(processinfo['subnotes'][0]['content'].gsub(/[\r\n]+/, ' '))
    end

    extents = get_ao['extents']

    # process linked agents
    agents = get_ao['linked_agents']
    agents_processed = agents.map do |agent|
      {
        'role' => agent['role'],
        'relator' => agent['relator'],
        'type' => agent['_resolved']['jsonmodel_type'],
        'source' => agent['_resolved']['names'][0]['source'],
        'family_name' => agent['_resolved']['names'][0]['family_name'],
        'primary_name' => agent['_resolved']['names'][0]['primary_name'],
        'rest_of_name' => agent['_resolved']['names'][0]['rest_of_name'],
        'name_dates' => agent['_resolved']['names'][0]['use_dates'].empty? ? nil : agent['_resolved']['names'][0]['use_dates'][0]['structured_date_range']['begin_date_expression'],
        'sort_name' => agent['_resolved']['names'][0]['sort_name'],
        'identifier' => agent['_resolved']['names'][0]['authority_id'],
        'name_order' => agent['_resolved']['names'][0]['name_order']
      }
    end

    #get instances
    instances = get_ao['instances']

    #map instance types
    leader_06 = instances&.map do |instance|
      case instance['instance_type']
      when "audio"
        "i"
      when "books"
        "a"
      when "computer_disks"
        "m"
      when "graphic_materials"
        "k"
      when "microform", "moving_images"
        "g"
      else
        "t"
      end
    end

    # process locations
    instances&.select {|instance| instance['instance_type'] == "mixed_materials"}

    #process containers first
    top_containers = instances&.map do |instance|
      if instance['sub_container'].nil? == false
        instance['sub_container']['top_container']['_resolved']
      elsif instance['top_container']
        instance['top_container']['_resolved']
      end
    end

    top_container_location_code = top_containers&.first&.dig('container_locations',0,'_resolved','classification')

    #process linked subjects
    subjects = get_ao['subjects']
    subjects_filtered = subjects.select do |subject|
      subject['_resolved']['terms'][0]['term_type'] == 'cultural_context' ||
        subject['_resolved']['terms'][0]['term_type'] == 'topical' ||
        subject['_resolved']['terms'][0]['term_type'] == 'geographic' ||
        subject['_resolved']['terms'][0]['term_type'] == 'genre_form'
    end
    subjects_processed = subjects_filtered.map do |subject|
      {
        'type' => subject['_resolved']['terms'][0]['term_type'],
        'source' => subject['_resolved']['source'],
        'full_first_term' => subject['_resolved']['terms'][0]['term'],
        'main_term' => subject['_resolved']['terms'][0]['term'].split('--')[0],
        'terms' => subject['_resolved']['terms']
      }
    end
    # add controlfields 
    leader = "<leader>00000n#{leader_06[0] || 't'}maa22000002u 4500</leader>"
    tag001 = "<controlfield tag='001'>#{ref_id}</controlfield>"
    tag003 = "<controlfield tag='003'>PULFA</controlfield>"
    tag008 = Nokogiri::XML.fragment("<controlfield tag='008'>000000#{tag008_date_type}#{date1}#{date2}xx      |           #{tag008_langcode} d</controlfield>")
    # addresses github 181 'Archival object URI??	035'
    tag035 = "<datafield ind1=' ' ind2=' ' tag='035'>
          <subfield code='a'>(PULFA)#{ref_id}</subfield>
          </datafield>"
    tag040 = '<datafield ind1=" " ind2=" " tag="040">
        <subfield code="a">NjP</subfield>
        <subfield code="b">eng</subfield>
        <subfield code="e">dacs</subfield>
        <subfield code="c">NjP</subfield>
        </datafield>'
    # addresses github 181 'Language	041'
    tag041 = "<datafield ind1=' ' ind2=' ' tag='041'>
            <subfield code='c'>#{tag008.content[35..37]}</subfield>
          </datafield>"
    # addresses github 181 'Dates/Expression	046'
    tag046 =
      if tag008.content[7..10] =~ /\d{4}/ || tag008.content[11..14] =~ /\d{4}/
        "<datafield ind1=' ' ind2=' ' tag='046'>
                <subfield code='a'>i</subfield>
                <subfield code='c'>#{tag008.content[7..10]}</subfield>
                <subfield code='e'>#{tag008.content[11..14]}</subfield>
              </datafield>"
      end
    # addresses github 181 'RefID (collection code?)/ Archival object URI??	099'
    tag099 = "<datafield ind1=' ' ind2=' ' tag='099'>
          <subfield code = 'a'>#{ref_id}</subfield>
          </datafield>"
    # addresses github 181 'Title	245'
    subfield_f =
      if date1 == date2 && date1 != '    '
        "<subfield code = 'f'>#{date1}</subfield>"
      elsif date2 && date1 != '    '
        "<subfield code = 'f'>#{date1}-#{date2}</subfield>"
      end
    tag245 = "<datafield ind1=' ' ind2=' ' tag='245'>
          <subfield code = 'a'>#{xml_escape(title)}</subfield>
          #{subfield_f ||= ''}
          </datafield>"
    # addresses github 181 Extents	300
    # somewhat unelegant conditional but works without having to refactor the Nokogiri doc
    tag300 = ''

    unless get_ao['extents'].empty?
      tag300 =
        if extents.count > 1
          repeatable_subfields =
            extents[1..-1].map do |extent|
          "<subfield code = 'a'>#{extent['number']}</subfield>
                   <subfield code = 'f'>#{extent['extent_type']})</subfield>"
        end
          Nokogiri::XML.fragment("<datafield ind1=' ' ind2=' ' tag='300'>
              <subfield code = 'a'>#{extents[0]['number']}</subfield>
              <subfield code = 'f'>#{extents[0]['extent_type']} (</subfield>
              #{repeatable_subfields.join(' ')}
            </datafield>")
        else
          Nokogiri::XML.fragment("<datafield ind1=' ' ind2=' ' tag='300'>
              <subfield code = 'a'>#{extents[0]['number']}</subfield>
              <subfield code = 'f'>#{extents[0]['extent_type']}</subfield>
              </datafield>")
        end
    end

    # addresses github 181 'Conditions Governing Access (can this be pulled from the collection-level note if there is none at the component level?)	506'
    tag506 = "<datafield ind1=' ' ind2=' ' tag='506'>
          <subfield code = 'a'>#{restriction_note[0] ||= default_restriction}</subfield>
          </datafield>"
    # addresses github 181 'Scope and contents	520'
    tags520 = scope_notes.map do |scope_note|
      "<datafield ind1=' ' ind2=' ' tag='520'>
            <subfield code = 'a'>#{xml_escape(scope_note)}</subfield>
            </datafield>"
    end
    # addresses github 181 'Immediate Source of Acquisition	541'
    tags541 = acq_notes.map do |acq_note|
      "<datafield ind1=' ' ind2=' ' tag='541'>
              <subfield code = 'a'>#{xml_escape(acq_note)}</subfield>
              </datafield>"
    end
    # adds related materials note
    tags544 = related_notes.map do |related_note|
      "<datafield ind1=' ' ind2=' ' tag='544'>
              <subfield code = 'a'>#{xml_escape(related_note)}</subfield>
              </datafield>"
    end
    # addresses github 181 '# Agents/Biographical/Historical note	545'
    tags545 = bioghist_notes.map do |bioghist_note|
      "<datafield ind1=' ' ind2=' ' tag='545'>
              <subfield code = 'a'>#{xml_escape(bioghist_note)}</subfield>
              </datafield>"
    end

    # addresses github 181 'Processing Information	583'
    tags583 = processinfo_notes.map do |processinfo_note|
      "<datafield ind1=' ' ind2=' ' tag='583'>
              <subfield code = 'a'>#{xml_escape(processinfo_note)}</subfield>
              </datafield>"
    end

    # addresses github 181 'Agent/Creator/Persname or Famname	100'
    # addresses github 181 'Agent/Creator/Corpname	110'
    # addresses github 181 'Agent/Subject	6xx'
    # addresses github 181 'Agent/Subject	7xx'
    tag1xx = []
    tags6xx_agents =
      # process tag number
      agents_processed.map do |agent|
      tag =
        if (agent['role'] == 'creator' || agent['role'] == 'source') && (agent['type'] == 'agent_person' || agent['type'] == 'agent_family')
          700
        elsif agent['role'] == 'subject' && (agent['type'] == 'agent_person' || agent['type'] == 'agent_family')
          600
        elsif (agent['role'] == 'creator' || agent['role'] == 'source') && agent['type'] == 'agent_corporate_entity'
          710
        elsif agent['role'] == 'subject' && agent['type'] == 'agent_corporate_entity'
          610
        end
      name_type =
        # we don't know in ASpace whether a name is a jurisdication name or first name only
        if agent['type'] == 'agent_person'
          1
        elsif agent['type'] == 'agent_family'
          3
        elsif agent['type'] == 'agent_corporate_entity' && agent['name_order'] == 'inverted'
          0
        elsif agent['type'] == 'agent_corporate_entity'
          2
        end

      source_code = agent['source'] == 'lcnaf' ? 0 : 7

      name =
        if agent['family_name']
          agent['family_name']
        elsif agent['rest_of_name'].nil?
          agent['primary_name']
        else
          "#{agent['primary_name']}, #{agent['rest_of_name']}"
        end
      dates = "<subfield code='d'>#{agent['name_dates']}</subfield>" unless agent['name_dates'].nil?
      subfield_e =
        if agent['relator'].nil?
          nil
        elsif agent['relator'].length == 3
          "<subfield code='4'>#{agent['relator']}</subfield>"
        else
          "<subfield code='e'>#{agent['relator']}</subfield>"
        end
      subfield_2 = source_code == 7 ? "<subfield code = '2'>#{agent['source']}</subfield>" : nil
      add_punctuation = agent['name_dates'].nil? ? '.' : ','
      subfield_0 = agent['identifier'].nil? ? nil : "<subfield code = '0'>#{agent['identifier']}</subfield>"
      # create 1xx
      # add lookahead to replace ampersands (but not entity names)
      tag1xx <<
        if agent['role'] == 'creator'
          "<datafield ind1='#{name_type}' ind2='#{source_code}' tag='1#{tag.to_s[1..2]}'>
                  <subfield code = 'a'>#{xml_escape(name)}#{add_punctuation unless name[-1] =~ /[.,)-]/}</subfield>
                  #{dates unless agent['name_dates'].nil?}
                  #{subfield_e ||= ''}
                  #{subfield_2 ||= ''}
                  #{subfield_0 ||= ''}
                </datafield>"
        end
      "<datafield ind1='#{name_type}' ind2='#{tag.to_s[0]=='7' ? ' ' : source_code}' tag='#{tag}'>
              <subfield code = 'a'>#{xml_escape(name)}#{add_punctuation unless name[-1] =~ /[.,)-]/}</subfield>
              #{dates unless agent['name_dates'].nil?}
              #{subfield_e ||= ''}
              #{subfield_2 ||= ''}
              #{subfield_0 ||= ''}
            </datafield>"
    end

    # addresses github 181 'Subjects	650'
    # addresses github 181 'Subjects	651'
    # addresses github 181 'Subjects	655'
    tags6xx_subjects =
      # process tag number
      subjects_processed.map do |subject|
      tag =
        case subject['type']
        when 'cultural_context'
          647
        when 'topical', 'temporal'
          650
        when 'geographic'
          651
        when 'genre_form'
          655
        end
      source_code =
        if subject['source'] == 'lcsh' || subject['source'] == 'Library of Congress Subject Headings'
          0
        else
          7
        end
      main_term = subject['main_term']
      subterms = subject['terms'][1..-1].map do |subterm|
        subfield_code =
          case subterm['term_type']
          when 'temporal', 'style_period', 'cultural_context'
            'y'
          when 'genre_form'
            'v'
          when 'geographic'
            'z'
          else
            'x'
          end
        "<subfield code = '#{subfield_code}'>#{subterm['term'].strip}</subfield>"
      end
      #if there are no subfields but the main term has double dashes, compute supfields
      computed_subterms =
        if subject['terms'].count == 1 && subject['full_first_term'] =~ /--/
          tokens = subject['full_first_term'].split('--')
          tokens.each(&:strip!)
          tokens[1..-1].map do |token|
          subfield_code = token =~ /^[0-9]{2}/ ? 'y' : 'x'
          "<subfield code = '#{subfield_code}'>#{token}</subfield>"
        end
        end
      #add subfield 2 if source code is 7
      subfield_2 = source_code == 7 ? "<subfield code = '2'>#{subject['source']}</subfield>" : nil

      #put the field together
      "<datafield ind1=' ' ind2='#{source_code}' tag='#{tag}'>
              <subfield code = 'a'>#{main_term}</subfield>
                #{subterms.join(' ')}
                #{computed_subterms.join(' ') unless computed_subterms.nil?}
                #{subfield_2}
              </datafield>"
    end

    # addresses github 181 'URL ?? + RefID (ex: https://findingaids.princeton.edu/catalog/C0140_c25673-42817)	856'
    tag856 = "<datafield ind1='4' ind2='2' tag='856'>
            <subfield code='z'>Search and Request</subfield>
            <subfield code = 'u'>https://findingaids.princeton.edu/catalog/#{ref_id}</subfield>
            <subfield code='y'>Princeton University Library Finding Aids</subfield>
            </datafield>"

    # addesses github 181 'Physical Location (can this be pulled from the collection-level note?)	982'
    tag982 = 
    unless top_container_location_code&.nil?
      "<datafield ind1=' ' ind2=' ' tag='982'><subfield code='c'>#{top_container_location_code}</subfield></datafield>"
    end
    # assemble the record
    record =
      "<record>
            #{leader}
            #{tag001}
            #{tag003}
            #{tag008}
            #{tag035}
            #{tag040}
            #{tag041}
            #{tag046 ||= ''}
            #{tag099}
            #{tag1xx[0] ||= ''}
            #{tag245}
            #{tag300}
            #{tag506}
            #{tags520.join(' ')}
            #{tags541.join(' ')}
            #{tags544.join(' ')}
            #{tags545.join(' ')}
            #{tags583.join(' ')}
            #{tags6xx_subjects.join(' ')}
            #{tags6xx_agents.join(' ')}
            #{tag856}
            #{tag982 ||= ''}
          </record>"
  end
end
