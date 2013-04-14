
Dequeue = require('deque').Dequeue

DataStore = require('./datastore')

TransactionLog = require('./transactionlog')

Q = require('q')

RingBuffer = require('./disruptor/ring_buffer')
BatchRunner = require('./disruptor/batch_runner')
SequenceBarrier = require('./disruptor/sequence_barrier')

Fiber = require('fibers')

module.exports = class Engine
  constructor: ->
    @transaction_log = new TransactionLog()
    @datastore = new DataStore()
    @messageBuffer = new RingBuffer() # TODO - probably want to use more than 1024 slots by default (must be power of 2)

    barrier = new SequenceBarrier(@messageBuffer)
    @syncComponents = []
    @syncComponents.push new BatchRunner @messageBuffer, barrier, (message) =>
      @transaction_log.record( JSON.stringify(message) )

    @syncComponents.push new BatchRunner @messageBuffer, barrier, (message) =>
      message[1].callback() if message[1].callback

    @engineLoop = Fiber =>
      @syncComponents.forEach (x) -> x.sync()
      return null

    @done = false

  start: =>
    return Q.fcall =>
      return @transaction_log.start()
    .then =>
      console.log 'STARTED ENGINE'

  stop: =>
    @done = true
    console.log "ENGINE! STAHP!"

  tick: =>
    @engineLoop.run()

  receive_message: (message) =>
    # journal + replicate

    ##### Disruptor impl. Need to figure out where the driver of concurency lives
    @messageBuffer.claim()(message)
    #####

    # deserialize (skipping this for now)

    # execute business logic
