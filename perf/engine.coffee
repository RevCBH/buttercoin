logger = require('../lib/logger')
Buttercoin = require('../lib/buttercoin')
butter = new Buttercoin()

##### Monkey patching
butter.engine.done = false
butter.engine.stop = -> @done = true
#####

startTime = process.hrtime()

count = 10000
didDeposit = (n) ->
  if n is count
    elapsedTime = process.hrtime(startTime)
    elapsedTime = elapsedTime[0]*1000 + elapsedTime[1] / 1000000

    logger.set_levels 'development'
    logger.info "#{count} ops in #{elapsedTime.toFixed(3)} ms"
    butter.engine.stop()

doDeposit = (n) ->
  butter.api.add_deposit(account: 'Peter', currency: 'USD', amount: n).then -> didDeposit(n)

q = butter.engine.start()

 
###
q.then(=>
  # console.log "and then"
  # for n in [1 .. count]
  console.log "add: #{n}"
  butter.api.add_deposit(account: 'Peter', currency: 'USD', amount: 0.01,  callback: -> didDeposit(n)))

q.done()
###

q.then =>
  doDeposit(n).done() for n in [1..count]

  #console.log "Letting the disk catch up..."
  #return null

q.done()

