require 'set'
require 'monitor'

module Schem
  class RangeTree
    CACHE_SIZE = 128

    class Node
      MAX_COLLAPSED_SUBTREE_SIZE = 128

      attr_accessor :position, :ranges, :left, :right, :collapsed_subtree,
                    :represented_range

      def initialize(represented_range)
        @represented_range = represented_range
        @position = (@represented_range.max + @represented_range.min) / 2
        @ranges = Set.new
        @left = nil
        @right = nil
        @collapsed_subtree = Set.new
      end

      def insert(range)
        if range.include? @position
          @ranges << range
        else
          insert_in_child(range)
        end
      end

      def insert_in_child(range)
        next_node = next_child(range.max)
        if next_node.nil?
          insert_as_collapsed_subtree(range)
        else
          next_node.insert(range)
        end
      end

      def insert_as_collapsed_subtree(range)
        @collapsed_subtree << range
        if @collapsed_subtree.size >= MAX_COLLAPSED_SUBTREE_SIZE
          overflow_collapsed_subtree
        end
      end

      def overflow_collapsed_subtree
        @left ||= Node.new(@represented_range.min .. @position - 1)
        @right ||= Node.new(@position + 1 .. @represented_range.max)
        @collapsed_subtree.each do |range|
          insert_in_child(range)
        end
        @collapsed_subtree.clear
      end

      def lookup_ranges(point)
        res = []
        @collapsed_subtree.each do |range|
          res << range if range.include? point
        end
        @ranges.each do |range|
          res << range if range.include? point
        end
        next_node = next_child(point)
        return res unless next_node
        res + next_node.lookup_ranges(point)
      end

      def next_child(point)
        point < @position ? @left : @right
      end

      def empty?
        return false if @ranges.size > 0
        return false if @collapsed_subtree.size > 0
        (!@left || @left.empty?) && (!@right || @right.empty?)
      end

      def remove_range(range)
        return @ranges.delete(range) if range.include?(@position) && @ranges.include?(range)
        return @collapsed_subtree.delete(range) if @collapsed_subtree.include?(range)
        next_node = next_child(range.max)
        next_node.remove_range(range) if next_node
        @left = nil if @left && @left.empty?
        @right = nil if @right && @right.empty?
      end
    end

    # class RangeTree actually begins here

    attr_accessor :root, :min, :max, :values_by_ranges

    include MonitorMixin

    def initialize(range = 0..2**64)
      @values_by_ranges = {}
      @root = Node.new(range)
      @cache = {}
      super()
    end

    def insert(range, value)
      synchronize do
        unless @values_by_ranges.include? range
          insert_in_cache(range)
          @root.insert(range)
          @values_by_ranges[range] = Set.new
        end
        @values_by_ranges[range] << value
      end
    end

    def lookup_cached(point)
      ranges = @cache[point]
      if ranges
        @cache.delete point
        @cache[point] = ranges
      end
      ranges
    end

    def add_to_cache(point, ranges)
      @cache[point] = ranges
      if @cache.size > CACHE_SIZE
        point_to_delete, _ = @cache.first
        @cache.delete point_to_delete
      end
    end

    def insert_in_cache(range)
      @cache.each_pair do |point, ranges|
        ranges << range if range.include? point
      end
    end

    def remove_from_cache(range)
      @cache.each_pair do |point, ranges|
        ranges.delete range if range.include? point
      end
    end

    def lookup_ranges(point)
      synchronize do
        looked_up = lookup_cached(point)
        return looked_up if looked_up
        ranges = @root.lookup_ranges(point)
        add_to_cache(point, ranges)
        return ranges
      end
    end

    def lookup_values(point)
      res = Set.new
      synchronize do
        lookup_ranges(point).each { |range| res += @values_by_ranges[range] }
      end
      res
    end

    def lookup_pairs(point)
      synchronize do
        lookup_ranges(point).reduce({}) do |h, range|
          h[range] = @values_by_ranges[range]; h
        end
      end
    end

    def remove_value(range, value)
      synchronize do
        if @values_by_ranges.include? range
          @values_by_ranges[range].delete(value)
          remove_range(range) if @values_by_ranges[range].size == 0
        end
      end
    end

    def remove_range(range)
      synchronize do
        remove_from_cache(range)
        @root.remove_range(range)
        @values_by_ranges.delete(range)
      end
    end
  end
end
