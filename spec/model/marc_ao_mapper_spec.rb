# frozen_string_literal: true

require 'spec_helper'
require_relative '../../backend/model/marc_ao_mapper'
require_relative '../../backend/model/marc_ao_exporter'

RSpec.describe MarcAOMapper do
  context 'when running collection_to_marc' do
    let(:container_response) { File.open('spec/fixtures/single_container.json') }
    it 'converts json to marc' do
      ao_jsons = to_enum(MarcAOExporter::each_resolved_ao.to_sym, container_response)
      expect(described_class.collection_to_marc(ao_jsons)).to eq('')
    end
  end
end
