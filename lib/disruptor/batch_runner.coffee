module.exports = class BatchRunner
  constructor: (@buffer, @processor) -> # TODO - additional sequence deps
    @sequence = -1

  sync: ->
    # TODO - handle sequence overflow
    # TODO - poll multiple sequence deps
    
    return unless @sequence < @buffer.available
    
    # Using JS for loop to avoid array allocations from coffeescript for loop
    # for n in [(@sequence + 1) .. @buffer.available]
    `for (var n = this.sequence + 1; n <= this.buffer.available; n++) {`
    @processor(@buffer.read(n))
    `}`

    @sequence = @buffer.available

