# frozen_string_literal: true

require 'spec_helper'
require_relative '../../backend/model/marc_ao_exporter'

RSpec.describe MarcAOExporter do
  context 'when running each_resolved_ao' do
    let(:container_response) { File.open('spec/fixtures/single_container.json') }
    it 'converts json to ' do
      expect(to_enum(:each_resolved_ao, container_response)).to eq('')
    end
  end
end
