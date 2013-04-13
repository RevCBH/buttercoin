assert = require 'assert'

module.exports = class RingBuffer
  constructor: (@capacity=1024) ->
    @capacityMask = @capacity - 1 # 1024 -> 100 0000 0000; 1023 -> 011 1111 1111; x & 1023 == x % 1024
    assert (@capacity & @capacityMask) is 0 # only support rings of size 2^n for fast modulo
    @buffer = new Array(@capacity)
    @available = -1
    @next = 0
    @consumers = {}

  # TODO - take a callback and block the producer if the buffer is full? 
  claim: ->
    idx = @next & @capacityMask # bitmask modulo
    nxt = @next # copy for lambda capture 
    @next += 1
    (value) => # TODO - support multiple producers?
      @buffer[idx] = value
      @available = nxt # blindly set the next available sequence number to the one just published
                       # this isn't safe if we support multiple producers
    
  read: (n) ->
    @buffer[n & @capacityMask] # provide the nth item modulo capacity

