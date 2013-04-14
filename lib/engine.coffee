
Dequeue = require('deque').Dequeue

DataStore = require('./datastore/datastore')

TransactionLog = require('./transactionlog')

Q = require('q')

operations = require("./operations")

RingBuffer = require('./disruptor/ring_buffer')
BatchRunner = require('./disruptor/batch_runner')
SequenceBarrier = require('./disruptor/sequence_barrier')

Fiber = require('fibers')

module.exports = class Engine
  constructor: ->
    @transaction_log = new TransactionLog(@)
    @datastore = new DataStore()
    @messageBuffer = new RingBuffer() # TODO - probably want to use more than 1024 slots by default (must be power of 2)

    barrier = new SequenceBarrier(@messageBuffer)
    @syncComponents = []
    @syncComponents.push new BatchRunner @messageBuffer, barrier, (message) =>
      @transaction_log.record( JSON.stringify(message) ).then =>
        # deserialize (skipping this for now)
        @replay_message(message)

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

    console.log 'RECEIVED MESSAGE'

    ##### Disruptor impl. Need to figure out where the driver of concurency lives
    @messageBuffer.claim()(message)
    #####
    
    # execute business logic

  replay_message: (message) =>
    console.log 'REPLAY MESSAGE', message

    if message[0] == operations.ADD_DEPOSIT
      @datastore.add_deposit(message[1])
    else
      throw Error("Unknown Operation Type")

  flush: =>
    @transaction_log.flush()
