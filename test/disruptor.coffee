chai = require('chai')
chai.should()
expect = chai.expect
assert = chai.assert
sinon = require('sinon')

RingBuffer = require('../lib/disruptor/ring_buffer')
SequenceBarrier = require('../lib/disruptor/sequence_barrier')
BatchRunner = require('../lib/disruptor/batch_runner')

describe 'RingBuffer', ->
  buffer = null
  beforeEach (done) ->
    buffer = new RingBuffer()
    done()

  it 'should enforce 2^n buffer size at creation', (done) ->
    (buffer.capacity & (buffer.capacity - 1)).should.equal 0
    (-> new RingBuffer(1000)).should.throw('AssertionError')
    done()

  it 'should update the sequence number after a claim is completed', (done) ->
    initial = buffer.sequence()
    claim = buffer.claim()
    buffer.sequence().should.equal(initial)
    claim({})
    buffer.sequence().should.equal(initial + 1)
    done()

  it 'should lookup items by sequence number modulo capacity', (done) ->
    buffer.claim()(1)
    seq = buffer.sequence()
    seq2 = seq + buffer.capacity

    buffer.read(seq).should.equal 1
    buffer.read(seq2).should.equal 1
    done()

describe 'SequenceBarrier', ->
  it 'should require at least one upstream dependency', (done) ->
    (-> new SequenceBarrier()).should.throw('AssertionError')
    done()

  it 'should produce the lowest upstream sequence number', (done) ->
    class DummySeq
      constructor: (@sequence) ->

    upstream = [0, 2, 3].map (x) -> new DummySeq(x)
    barrier = new SequenceBarrier(upstream)
    barrier.sequence().should.equal 0
    upstream[0].sequence = 5
    barrier.sequence().should.equal 2
    done()
  
  it 'should work with function-based upstream sequence properties', (done) ->
    class DummySeq
      constructor: (@seq) ->
      sequence: -> @seq
    
    barrier = new SequenceBarrier(new DummySeq(4))
    barrier.sequence().should.equal 4
    done()

describe 'BatchRunner', ->
  buffer = null
  beforeEach (done) ->
    buffer = new RingBuffer()
    done()

  it 'should not call the processor if there\'s no new work', (done) ->
    barrier = new SequenceBarrier(buffer)
    spy = sinon.spy()
    runner = new BatchRunner(buffer, barrier, spy)
    runner.sync()
    spy.called.should.not.equal true
    done()

  it 'should call the processor once for each new work item', (done) ->
    barrier = new SequenceBarrier(buffer)
    spy = sinon.spy()
    runner = new BatchRunner(buffer, barrier, spy)

    buffer.claim()({})
    buffer.claim()({})

    runner.sync()
    spy.calledTwice.should.equal true

    runner.sync()
    spy.calledTwice.should.equal true
    done()

