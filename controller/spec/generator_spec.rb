# encoding: utf-8
require './lib/generator.rb'
require 'wrong/adapters/rspec'

describe 'SEQ::Generator#need_init?' do
  it 'returns true in the first iteration' do
    g = SEQ::Generator.new([nil, nil, nil])
    assert { g.need_init? == true }
  end

  it 'returns true if the loop condition is met' do
    module SEQ
      class Generator
        attr_accessor :index, :iteration
      end
    end

    g = SEQ::Generator.new(['1', nil, [:condition, 'i%2 == 0']])
    g.iteration = 12 # no need to test first iteration again
    assert { g.need_init? == true }
    g.index = 1
    assert { g.need_init? == false }
    g.index = 2
    assert { g.need_init? == true }
  end

  it 'returns true if the loop counter equals the number of iterations since the last reset' do
    module SEQ
      class Generator
        attr_accessor :iteration, :index
      end
    end

    g = SEQ::Generator.new(['1', nil, [:times, '5']])
    g.iteration = 12 # no need to test first iteration again
    assert { g.need_init? == false }
    g.index = 5
    assert { g.need_init? == true }
    g.index += 1
    assert { g.need_init? == false }
  end
end

describe 'SEQ::Generator#step' do
  it 'returns the initial value if re-initialised with a steping program' do
    g = SEQ::Generator.new(['(2..3)', [:step, 'v = v'], [:times, '1']])
    assert { g.step('line') == (2..3) }
  end

  it 'returns the first element if re-initialised with a program without step' do
    g = SEQ::Generator.new(['(3..5)', nil, [:times, '1']])
    assert { g.step('line') == 3 }

    g = SEQ::Generator.new(['[\'foo\']', nil, [:times, '1']])
    assert { g.step('line') == 'foo' }

    g = SEQ::Generator.new(['1+2', nil, [:times, '1']])
    assert { g.step('line') == 3 }
  end

  it 'executes increment' do
    g = SEQ::Generator.new(['1+1', [:inc, '2'], nil])
    assert { g.step('line') == 2 }
    assert { g.step('line') == 4 }
    assert { g.step('line') == 6 }
  end

  it 'executes decrement' do
    g = SEQ::Generator.new(['1+1', [:dec, '2'], nil])
    assert { g.step('line') == 2  }
    assert { g.step('line') == 0  }
    assert { g.step('line') == -2 }
  end

  it 'executes steps' do
    g = SEQ::Generator.new(['1+1', [:step, 'v = v*3'], nil])
    assert { g.step('line') == 2  }
    assert { g.step('line') == 6  }
    assert { g.step('line') == 18 }
  end

  it 'execute loop- & stepless programs' do
    g = SEQ::Generator.new(['(1..2)', nil, nil])
    assert { g.step('line') == 1 }
    assert { g.step('line') == 2 }
    assert { g.step('line') == 1 }

    g = SEQ::Generator.new(['[4, 2]', nil, nil])
    assert { g.step('line') == 4 }
    assert { g.step('line') == 2 }
    assert { g.step('line') == 4 }

    g = SEQ::Generator.new(['4', nil, nil])
    assert { g.step('line') == 4 }
    assert { g.step('line') == 5 }
    assert { g.step('line') == 6 }
  end
end
