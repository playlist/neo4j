describe Neo4j::ActiveNode::Labels do
  before(:all) do
    @prev_wrapped_classes = Neo4j::ActiveNode::Labels._wrapped_classes
    Neo4j::ActiveNode::Labels._wrapped_classes.clear

    @class_a = Class.new do
      include Neo4j::ActiveNode::Labels
      def self.mapped_label_name
        'A'
      end
    end

    @class_b = Class.new do
      include Neo4j::ActiveNode::Labels
      def self.mapped_label_name
        'B'
      end
    end
  end

  after(:all) do
    # restore
    Neo4j::ActiveNode::Labels._wrapped_classes.concat(@prev_wrapped_classes)
  end

  describe Neo4j::ActiveNode::Labels::ClassMethods do
    describe 'index and inheritance' do
      before do
        stub_active_node_class('MyBaseClass') do
          property :things
        end
        stub_named_class('MySubClass', MyBaseClass) do
          property :stuff
        end
      end

      it 'should have labels for baseclass' do
        expect(MySubClass.mapped_label_names).to match_array([:MyBaseClass, :MySubClass])
      end
    end

    describe 'mapped_label_name' do
      it 'return the class name if not given a label name' do
        clazz = Class.new do
          extend Neo4j::ActiveNode::Labels::ClassMethods
          def self.name
            'MyClass'
          end
        end
        expect(clazz.mapped_label_name).to eq(:MyClass)
      end
    end

    describe 'set_mapped_label_name' do
      it 'sets the label name and overrides the class name' do
        clazz = Class.new { extend Neo4j::ActiveNode::Labels::ClassMethods }
        clazz.send(:mapped_label_name=, 'foo')
        expect(clazz.mapped_label_name).to eq(:foo)
      end
    end

    describe 'label' do
      it 'wraps the mapped_label_name in a Neo4j::Core::Label object' do
        clazz = Class.new do
          include Neo4j::Shared
          extend Neo4j::ActiveNode::Labels::ClassMethods
          def self.name
            'MyClass'
          end
        end

        label_double = double('label')
        expect(Neo4j::Core::Label).to receive(:new).with(:MyClass, Neo4j::ActiveBase.current_session).and_return(label_double)
        expect(clazz.send(:mapped_label)).to eq(label_double)
      end
    end

    describe 'mapped_label_names' do
      it 'returns the label of a class' do
        clazz = Class.new do
          extend Neo4j::ActiveNode::Labels::ClassMethods
          def self.name
            'mylabel'
          end
        end
        expect(clazz.mapped_label_names).to eq([:mylabel])
      end

      it 'returns all labels for inherited ancestors which have a label method' do
        base_class = Class.new do
          def self.mapped_label_name
            'base'
          end
        end

        middle_class = Class.new(base_class) do
          extend Neo4j::ActiveNode::Labels::ClassMethods

          def self.mapped_label_name
            'middle'
          end
        end

        top_class = Class.new(middle_class) do
          extend Neo4j::ActiveNode::Labels::ClassMethods

          def self.mapped_label_name
            'top'
          end
        end

        # notice the order is important since it will try to load and map in that order
        expect(middle_class.mapped_label_names).to eq([:middle, :base])
        expect(top_class.mapped_label_names).to eq([:top, :middle, :base])
      end

      it 'returns all labels for included modules which have a label class method' do
        module1 = Module.new do
          def self.mapped_label_name
            'module1'
          end
        end

        module2 = Module.new do
          def self.mapped_label_name
            'module2'
          end
        end

        clazz = Class.new do
          extend Neo4j::ActiveNode::Labels::ClassMethods
          include module1
          include module2

          def self.name
            'module'
          end
        end

        expect(clazz.mapped_label_names).to match_array([:module, :module1, :module2])
      end
    end

    describe 'model_for_labels' do
      class Event
        include Neo4j::ActiveNode
      end

      class URL
        include Neo4j::ActiveNode
      end

      module DataSource
        class URL < ::URL
          self.mapped_label_name = 'DataSource'
        end

        class Event < URL
          self.mapped_label_name = 'Event'
        end
      end

      it 'returns the correct model for the node' do
        classes = [Event, URL, DataSource::URL, DataSource::Event]

        # TODO: not sure why this is not being called when the class is defined
        classes.reverse_each { |c| Neo4j::ActiveNode::Labels.add_wrapped_class(c) }

        classes.each do |c|
          labels = c.mapped_label_names
          model = Neo4j::ActiveNode::Labels.model_for_labels(labels)
          expect(model).to eq(c)
        end
      end
    end
  end
end
