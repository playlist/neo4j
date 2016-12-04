describe Neo4j::Migrations::CheckPending do
  let(:with_migrations!) do
    allow(Neo4j::Migrations::Runner).to receive(:files_path) do
      Rails.root.join('spec', 'migration_files', 'migrations', '*.rb')
    end
  end
  subject do
    app = double(call: true)
    described_class.new(app)
  end

  it 'does nothing when there are no migrations' do
    expect(Neo4j::Migrations).not_to receive(:check_for_pending_migrations!)
    subject.call({})
  end

  context 'when there are some migrations' do
    before { with_migrations! }
    it 'checks for pending' do
      expect(Neo4j::Migrations).to receive(:check_for_pending_migrations!)
      subject.call({})
    end

    it 'doesn\'t check @last_check is up to date' do
      subject.instance_variable_set(:@last_check, 9_999_999_999)
      expect(Neo4j::Migrations).not_to receive(:check_for_pending_migrations!)
      subject.call({})
    end
  end
end
