Buttercoin = require('./lib/buttercoin')

butter = new Buttercoin()

console.log "starting up"
startTime = process.hrtime()

count = 10000
didDeposit = (n) ->
  if n > count
    elapsedTime = process.hrtime(startTime)
    elapsedTime = elapsedTime[0]*1000 + elapsedTime[1] / 1000000

    console.log "#{count} ops in #{elapsedTime.toFixed(3)} ms"
    butter.engine.stop()

doDeposit = (n) ->
  butter.api.add_deposit(account: 'Peter', currency: 'USD', amount: n, callback: -> didDeposit(n))

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
  n = 1
  `while (!butter.engine.done) {
    //console.log("tick");
    doDeposit(n).done();
    butter.engine.tick();
    n += 1;
  }`
  console.log "Letting the disk catch up..."
  return null

q.done()
