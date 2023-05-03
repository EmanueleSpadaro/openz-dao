var MyContract = artifacts.require("DAOFactory");

module.exports = function(deployer, _, accounts) {
  // deployment steps
  deployer.deploy(MyContract, "Main DAO Factory", "dao_realm", {from: accounts[0]});
};
