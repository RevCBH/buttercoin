Q = require('q')
QFS = require("q-io/fs")
fs = require("fs")
jspack = require('jspack').jspack
logger = require('./logger')

module.exports = class TransactionLog
  constructor: (@engine) ->
    @filename = 'transaction.log'

  start: =>
    return QFS.exists(@filename).then (retval) =>
      if retval
        logger.info 'LOG EXISTS'
        Q.fcall =>
          @replay_log().then =>
            # This is dangerous
            @initialize_log()
      else
        logger.info 'LOG DOES NOT EXIST'
        Q.fcall =>
          @initialize_log().then =>
            return null

  initialize_log: =>
    logger.info 'INITIALIZING LOG'
    Q.nfcall(fs.open, @filename, "w").then (writefd) =>
      logger.info 'GOT FD', writefd
      @writefd = writefd

  replay_log: =>
    # XXX: This code is basically guaranteed to have chunking problems right now.
    # Fix and then test rigorously!!!

    @readstream = fs.createReadStream(@filename, {flags: "r"})

    logger.info 'GOT READSTREAM'

    deferred = Q.defer()

    Q.fcall =>
      parts = []
      @readstream.on 'end', =>
        logger.info 'done reading'
        @readstream.close()
        deferred.resolve()

      @readstream.on 'readable', =>
        data = @readstream.read()
        logger.info 'READ', data, data.isEncoding
        lenprefix = jspack.Unpack('I', (c.charCodeAt(0) for c in data.slice(0,4).toString('binary').split('')), 0 )[0]

        logger.info 'lenprefix', lenprefix

        chunk = data.slice(4, 4 + lenprefix)

        if data.length > 4 + lenprefix
          rest = data.slice(4 + lenprefix)
        else
          rest = ''

        logger.info 'LENS', data.length, chunk.length, rest.length
        logger.info 'CHUNK', chunk.toString()

        logger.info 'rest', rest


        if chunk.length == lenprefix
          message = JSON.parse(chunk.toString())
          logger.info 'message', message
          @engine.replay_message(message)
          @readstream.unshift(rest)
        else
          @readstream.unshift(data)

    .fail =>
      logger.error 'ERROR'
    .done()

    return deferred.promise

  record: (message) =>
    # logger.info 'RECORDING', message
    l = message.length

    part = jspack.Pack('I', [l])

    buf = Buffer.concat [ Buffer(part), Buffer(message) ]

    writeq = Q.nfcall(fs.write, @writefd, buf, 0, buf.length, null)
    logger.info 'DONE WRITING', writeq, buf
    return writeq

  flush: =>
    Q.nfcall(fs.fsync, @writefd).then =>
      logger.info 'FLUSHED'
