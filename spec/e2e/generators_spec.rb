require 'rails/generators'
require 'rails/generators/neo4j_generator'
require 'rails/generators/neo4j/model/model_generator'
require 'rails/generators/neo4j/migration/migration_generator'
require 'rails/generators/neo4j/upgrade_v8/upgrade_v8_generator'

describe 'Generators' do
  before do
    allow(Time).to receive(:zone).and_return(double(now: Time.parse('10/12/1990')))
  end

  describe Neo4j::Generators::ModelGenerator do
    it 'has a `source_root`' do
      expect(described_class.source_root).to include('rails/generators/neo4j/model/templates')
    end

    it 'creates a model and a migration file' do
      expect_any_instance_of(described_class).to receive(:template).with('model.erb', 'app/models/some.rb')
      expect_any_instance_of(described_class).to receive(:template).with('migration.erb', 'db/neo4j/migrate/19901210000000_some.rb')
      described_class.new(['some']).create_model_file
    end
  end

  describe Neo4j::Generators::MigrationGenerator do
    it 'has a `source_root`' do
      expect(described_class.source_root).to include('rails/generators/neo4j/migration/templates')
    end

    it 'creates a migration file' do
      expect_any_instance_of(described_class).to receive(:template).with('migration.erb', 'db/neo4j/migrate/19901210000000_some.rb')
      described_class.new(['some']).create_migration_file
    end
  end

  describe Neo4j::Generators::UpgradeV8Generator do
    before do
      app = double
      allow(app).to receive(:eager_load!) do
        stub_active_node_class('Person') do
          property :name, index: :exact
        end
      end
      allow(Rails).to receive(:application).and_return(app)
    end

    it 'has a `source_root`' do
      expect(described_class.source_root).to include('rails/generators/neo4j/upgrade_v8/templates')
    end

    it 'creates a migration file' do
      expect_any_instance_of(described_class).to receive(:template).with('migration.erb', 'db/neo4j/migrate/19901210000000_upgrate_to_v8.rb')
      described_class.new.create_upgrade_v8_file
    end
  end
end
