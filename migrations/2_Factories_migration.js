const TokenFactory = artifacts.require('TokenFactory');
const CrowdsaleFactory = artifacts.require('CrowdsaleFactory');
const ExchangeFactory = artifacts.require('ExchangeFactory');

module.exports = function(deployer, _, accounts) {
    // deployment steps
    deployer.deploy(TokenFactory);
    deployer.deploy(CrowdsaleFactory);
    deployer.deploy(ExchangeFactory);
};
