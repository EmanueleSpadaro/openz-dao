var MyContract = artifacts.require("DAO");

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(MyContract);
};
