# encoding: utf-8
require './lib/parser.rb'
require 'wrong/adapters/rspec'

describe 'SEQ::Parser#parse' do

  it 'throws an exception if an empty array is given' do
    p = SEQ::Parser.new
    assert { rescuing { p.parse [] } }
  end

  it 'throws an exception if nil is given' do
    p = SEQ::Parser.new
    assert { rescuing { p.parse nil } }
  end

  it 'throws an exception if something but an Array is given' do
    p = SEQ::Parser.new
    assert { rescuing { p.parse 4 } }
  end

  it 'throws no exception if a valid non-empty array is given' do
    p = SEQ::Parser.new
    deny { rescuing { p.parse ['(1..3)'] } }
  end

  it 'should parse conditional loops' do
    p = SEQ::Parser.new
    assert { p.parse(['(1..10)', 'loop', 'on', 'false']) == ['(1..10)', nil, [:condition, 'false']] }
    assert { p.parse(['0+1', 'step', 'v+=3', 'loop', 'on', 'v%3==0']) == ['0+1', [:step, 'v+=3'], [:condition, 'v%3==0']] }
    assert { p.parse(['1', '++', 'v*3', 'loop', 'on', 'false']) == ['1', [:inc, 'v*3'], [:condition, 'false']] }
    assert { p.parse(['1', '--', '3', 'loop', 'on', 'false']) == ['1', [:dec, '3'], [:condition, 'false']] }
    assert { p.parse(['\'1\'', '++', '\'a\'', 'loop', 'on', 'false']) == ['\'1\'', [:inc, '\'a\''], [:condition, 'false']] }
  end

  it 'should parse fixed count loops' do
    p = SEQ::Parser.new
    assert { p.parse(['(1..10)', 'loop', '3+4']) == ['(1..10)', nil, [:times, '3+4']] }
    assert { p.parse(['0+1', 'step', 'v+=3', 'loop', '3*$i']) == ['0+1', [:step, 'v+=3'], [:times, '3*$i']] }
    assert { p.parse(['1', '++', 'v*3', 'loop', '5']) == ['1', [:inc, 'v*3'], [:times, '5']] }
  end

  it 'should parse programs without loops' do
    p = SEQ::Parser.new
    assert { p.parse(['(1..10)']) == ['(1..10)', nil, nil] }
    assert { p.parse(['10']) == ['10', nil, nil] }
    assert { p.parse(['10', '++', '1']) == ['10', [:inc, '1'], nil] }
    assert { p.parse(['10', '--', '1']) == ['10', [:dec, '1'], nil] }
    assert { p.parse(['10', 'step', 'v+=2']) == ['10', [:step, 'v+=2'], nil] }
  end

  it 'should throw an exception if a program without loop & step is given, but the initial value is unknown' do
    p = SEQ::Parser.new
    assert { rescuing { p.parse(['\'foo\'']) } }
  end
end

describe 'SEQ::Parser#parse_expression' do

  it 'returns nil if a invalid expression is given' do
    p = SEQ::Parser.new
    assert { p.parse_expression('fn$$ord').nil? }
  end

  it 'returns value if a valid expression is given' do
    p = SEQ::Parser.new
    ['[1, 2, \'fnord\']', 'a.foo', "'fnord'.gsub('f', 'b')"].each do |e|
      assert { p.parse_expression(e) == e }
    end
  end
end

describe 'SEQ::Parser#parse_key_word' do

  it 'returns nil if nonsense is given' do
    p = SEQ::Parser.new
    ['fn$$ord', ' loop', 'looop'].each do |e|
      assert { p.parse_key_word(e).nil? }
    end
  end

  it 'returns the symbol of the keyword type if a valid expression is given (ignoring case)' do
    p = SEQ::Parser.new
    { '++' => :inc, 'loop' => :loop, 'on' => :on, 'step' => :step, 'STEP' => :step }.each_pair do |k, v|
     assert { p.parse_key_word(k) == v }
   end
  end
end

describe 'SEQ::Parser#parse_loop' do

  it 'returns nil if index is beyond the range of argv' do
    p = SEQ::Parser.new
    assert { p.parse_loop([1, 2], 2).nil? }
  end

  it 'returns nil if argv[index] is not the begin of a valid loop statement' do
    p = SEQ::Parser.new
    assert { p.parse_loop([1, 2], 2).nil? }
  end
  it 'returns [:condition, expression] if argv contains a loop with a condition at index' do
    p = SEQ::Parser.new
    assert { p.parse_loop([1, 'loop', 'on', '1+2'], 1) == [:condition, '1+2'] }
  end

  it 'returns [:times, Fixnum] if argv contains a loop with a iteration count at index' do
    p = SEQ::Parser.new
    assert { p.parse_loop([1, 'loop', '34'], 1) == [:times, '34'] }
    assert { p.parse_loop([1, 'loop', '3+4'], 1) == [:times, '3+4'] }
  end

  it 'throws an exception if insufficient parameters are given for a loop in a way that there is a  syntax error' do
    p = SEQ::Parser.new
    assert { rescuing { p.parse_loop([1, 'loop', 'on'], 1) } }
    assert { rescuing { p.parse_loop([1, 'loop'], 1) } }
  end

end
