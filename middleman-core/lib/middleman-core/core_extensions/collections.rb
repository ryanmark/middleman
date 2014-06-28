require 'middleman-core/util'

module Middleman
  module CoreExtensions
    class Collections < Extension
      def initialize(app, options_hash={}, &block)
        super

        @store = CollectionStore.new(self)
      end

      def before_configuration
        app.add_to_config_context :collect, &method(:create_collection)
        app.add_to_config_context :uri_match, &method(:uri_match)
      end

      def create_collection(title, options={})
        @store.add title, options.fetch(:where), options.fetch(:group_by, false)
      end

      def uri_match(path, template)
        matcher = ::Middleman::Util::UriTemplates.uri_template(template)
        ::Middleman::Util::UriTemplates.extract_params(matcher, ::Middleman::Util.normalize_path(path))
      end

      def collected
        @store
      end

      helpers do
        def collected
          extensions[:collections].collected
        end
      end

      class CollectionStore

        delegate :app, to: :@parent

        def initialize(parent)
          @parent = parent
          @collections = {}
        end

        def add(title, where, group_by)
          @collections[title] = if group_by
            GroupedCollection.new(self, where, group_by)
          else
            Collection.new(self, where)
          end
        end

        # "Magically" find namespace if they exist
        #
        # @param [String] key The namespace to search for
        # @return [Hash, nil]
        def method_missing(key)
          if key?(key)
            @collections[key]
          else
            throw 'Collection not found'
          end
        end

        # Needed so that method_missing makes sense
        def respond_to?(method, include_private=false)
          super || key?(method)
        end

        # Act like a hash. Return requested data, or
        # nil if data does not exist
        #
        # @param [String, Symbol] key The name of the namespace
        # @return [Hash, nil]
        def [](key)
          if key?(key)
            @collections[key]
          else
            throw 'Collection not found'
          end
        end

        def key?(key)
          @collections.key?(key)
        end

        alias_method :has_key?, :key?
      end

      class Collection
        include Enumerable

        delegate :[], :each, :first, :last, to: :items
        delegate :app, to: :@store

        def initialize(store, where)
          @store = store
          @where = where
          @last_sitemap_version = nil
          @items = []
        end

        def items
          if @last_sitemap_version != app.sitemap.update_count
            @items = app.sitemap.resources.select &@where
          end

          @items
        end
      end

      class GroupedCollection
        delegate :app, to: :@store
        delegate :each, to: :groups

        def initialize(store, where, group_by)
          @store = store
          @where = where
          @group_by = group_by
          @last_sitemap_version = nil
          @groups = {}
        end

        def groups
          if @last_sitemap_version != app.sitemap.update_count
            items = app.sitemap.resources.select &@where

            @groups = items.reduce({}) do |sum, resource|
              results = Array(@group_by.call(resource)).map(&:to_s).map(&:to_sym)

              results.each do |k|
                sum[k] ||= []
                sum[k] << resource
              end

              sum
            end
          end

          @groups
        end

        # "Magically" find namespace if they exist
        #
        # @param [String] key The namespace to search for
        # @return [Hash, nil]
        def method_missing(key)
          if key?(key)
            @groups[key]
          else
            require 'pry'
            binding.pry
            throw 'Group not found'
          end
        end

        # Needed so that method_missing makes sense
        def respond_to?(method, include_private=false)
          super || key?(method)
        end

        # Act like a hash. Return requested data, or
        # nil if data does not exist
        #
        # @param [String, Symbol] key The name of the namespace
        # @return [Hash, nil]
        def [](key)
          if key?(key)
            @groups[key]
          else
            throw 'Group not found'
          end
        end

        def key?(key)
          @groups.key?(key)
        end

        alias_method :has_key?, :key?
      end
    end
  end
end
