var BountyContract = artifacts.require("./BountyContract.sol");
var CircuitBreaker = artifacts.require("./CircuitBreaker.sol");

module.exports = function (deployer) {
    deployer.deploy(BountyContract);
    deployer.deploy(CircuitBreaker);
};