module.exports = {
  testCommand: 'node --max-old-space-size=4096 ./scripts/testCoverage.js; node --max-old-space-size=4096 ./scripts/testZEPValidatorCoverage.js;',
  copyPackages: ['web3']
}
