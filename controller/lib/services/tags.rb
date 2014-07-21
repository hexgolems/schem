require_relative '../madtree.rb'

# TODO document me
module Schem
  # TODO document me
  class Tag
    attr_accessor :range, :name, :type, :data
    def initialize(name, range, type = :unknown, data = {})
      @name = name
      @range = range
      @type = type
      @data = data
    end

    def as_json_(text = @name)
      [@name, text, @data[:color]]
    end
  end

  # TODO document me
  class TagsService < BaseService
    attr_accessor :tags_by_name

    def initialize(*args)
      super
      @tree = RangeTree.new
      @tags_by_name = {}
    end

    def add(tag)
      @tree.insert(tag.range, tag)
      @tags_by_name[tag.name] ||= Set.new
      @tags_by_name[tag.name] << tag
    end

    def by_address(point)
      @tree.lookup_values(point)
    end

    def by_range(range)
      res = Set.new
      range.each do |addr| # TODO implement fast & smart algorithm in tree
        res += @tree.lookup_values(addr)
      end
      res
    end

    def by_name(name)
      @tags_by_name[name]
    end

    def remove(tag)
      @tree.remove_value(tag.range, tag)
    end

    # TODO create reader?
    def dump
      @tree
    end
  end
  register_service(:tags, TagsService)
end
