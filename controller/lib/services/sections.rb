# encoding: utf-8
# TODO document me
module Schem
  # TODO document me
  class SectionService < BaseService
    def initialize(*args)
      super
      @old_sections = nil
      reload
    end

    def stop_callback
      reload
    end

    def reload
      publish(:sections) do
        sections = srv.dbg.mem_mappings
        if @old_sections != sections
          signal_waiting
          @old_sections = sections
        end
        sections
      end
    end

    def find(addr)
      get_published_value(:sections).each do |sec|
        return sec if sec.from <= addr && addr <= sec.to
      end
      false
    end

    def get_mapped_subranges(range)
      assert { range.first <= range.last }
      @mapped = sections
      # find all intersecting subranges
      intersections = @mapped.sort_by(&:from).map { |sec| sec.intersection(range) }.compact

      # removed this part, because if they are next to each other they are most
      # propably still two different sections, and that makes other stuff easier
      #
      # if there are two regions that are mapped without a hole inbetween, merge the resulting subranges
      #     intersections = intersections.inject([]) do |s,e|
      #       if s.last && s.last.max >= e.min-1
      #               s[-1]= (s.last.min..e.max) ; s
      #       else
      #               s << e; s
      #       end
      #     end

      # all the intersetcions are indeed valid maped regions
      intersections = intersections.map { |one_range| [:valid, one_range] }
      # now add the invalid reagions between the mapped ones
      res = []
      intersections.each_index do |i|
        res << intersections[i]
        if i + 1 < intersections.length && ! (intersections[i][1].max + 1) == intersections[i + 1][1].min
          res << [:invalid, ((intersections[i][1].max + 1)..(intersections[i + 1][1].min - 1))]
        end
      end
      # add invalid regions at start and end if necessary
      res = [[:invalid, range]] if res.length == 0
      res = [[:invalid, range.min..(res.first[1].min - 1)]] + res if res.first[1].min > range.min
      res << [:invalid, (res.last[1].max + 1)..range.max] if res.last[1].max + 1 <= range.max
      res
    end
  end

  register_service(:section, SectionService)
end
