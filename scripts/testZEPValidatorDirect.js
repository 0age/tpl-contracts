// get web3 provider from configuration files
const applicationConfig = require('../config.js')
const connectionConfig = require('../truffle.js')
const connection = connectionConfig.networks[applicationConfig.network]
let web3Provider = connection.provider

// import tests
var testZEPValidator = require('./testZEPValidator.js')

// run coverage tests
testZEPValidator.test(web3Provider, 'direct')
