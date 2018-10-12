module.exports = {
    norpc: true,
    //port: 8545,
    //testrpcOptions: '--port 8545 --gasLimit 0xfffffffffff --gasPrice 0x01'
    testCommand: 'node ./scripts/testMinimalCoverage.js',
    compileCommand: 'node ../node_modules/.bin/truffle compile',
    copyPackages: ['web3']
};
