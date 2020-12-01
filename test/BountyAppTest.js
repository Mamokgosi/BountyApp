var BountyApp = artifacts.require("./BountyApp.sol");

contract('BountyApp', function (accounts) {

    it("should create a bounty correctly", function () {
        var bountyAppInstance;
        var bountyDesc = 'abcd';
        var bountyAmt = web3.toWei(1, "ether");
        return BountyApp.deployed().then(function (instance) {
            bountyAppInstance = instance;
            return bountyAppInstance.createBounty(bountyDesc, bountyAmt, { from: accounts[0] });
        }).then(function () {
            return bountyAppInstance.returnBountiesCount({ from: accounts[0] });
        }).then(function (numBounties) {
            assert.equal(numBounties.valueOf(), 1, "Bounty has not been created");
            return bountyAppInstance.getBounty(numBounties.valueOf() - 1, { from: accounts[0] }).then(function (bounty) {
                var bountyCreator = bounty[0];
                var desc = bounty[1];
                var amt = bounty[2];
                var bountyStage = bounty[3];
                assert.equal(bountyCreator, accounts[0], "Bounty not created correctly, creator wrong");
                assert.equal(desc, bountyDesc, "Bounty not created correctly, desc wrong");
                assert.equal(amt.valueOf(), bountyAmt, "Bounty not created correctly, amt is wrong");
                assert.equal(bountyStage.valueOf(), 0, "Bounty not created correctly, bounty stage wrong");
            })
        })
    });
    it("should create a solution correctly", function () {
        var bountyAppInstance;
        var bountyId = 0;
        var solutionId;
        var solutionDesc = 'xyz';
        return BountyContract.deployed().then(function (instance) {
            bountyAppInstance = instance;
            return bountyContractInstance.createSolution(bountyId, solutionDesc, { from: accounts[1] });
        }).then(function () {
            return bountyAppInstance.returnSolutionsCount(bountyId, { from: accounts[0] });
        }).then(function (numSolutions) {
            assert.equal(numSolutions.valueOf(), 1, "Solution has not been created");
            solutionId = numSolutions.valueOf() - 1;
            return bountyAppInstance.getSolution(bountyId, solutionId, { from: accounts[0] });
        }).then(function (solution) {
            var bountyHunter = solution[0];
            var bountySolution = solution[1];
            var solutionAcceptedState = solution[2].valueOf();
            assert.equal(bountyHunter, accounts[1], "Solution for bounty not created correctly, hunter address is wrong");
            assert.equal(bountySolution, solutionDesc, "Solution for bounty not created properly, solution desc wrong");
            assert.equal(solutionAcceptedState, false, "solution for bounty not created correctly, solution state wrong");
        })
    });
    it("should credit bounty reward to bounty hunter when solution is accepted", function () {
        var bountyAppInstance;
        var bountyId = 0;
        var solutionId = 0;
        var bountyHunter;
        var bountyReward;
        var initialCredit;
        var finalCredit;
        return BountyApp.deployed().then(function (instance) {
            bountyAppInstance = instance;
            return bountyAppInstance.getSolutionToBeAwarded(bountyId, solutionId, { from: accounts[0] });
        }).then(function (solution) {
            bountyHunter = solution[0];
            bountyReward = solution[1].valueOf();
            return bountyAppInstance.untrustedCheckBountyWinnings(bountyHunter, { from: accounts[0] });
        }).then(function (initialBalance) {
            initialCredit = initialBalance.valueOf();
            return bountyAppInstance.untrustedAcceptSolution(bountyId, solutionId, { from: accounts[0], value: bountyReward });
        }).then(function () {
            return bountyAppInstance.untrustedCheckBountyWinnings(bountyHunter, { from: accounts[0] });
        }).then(function (finalBalance) {
            finalCredit = finalBalance.valueOf();
            assert.equal(finalCredit, parseInt(initialCredit) + parseInt(bountyReward), "correct amount not credited to bounty hunter");
        })
    });
    it("should withdraw the bounty hunter's winnings from escrow to his address", function () {
        var bountyAppInstance;
        var bountyHunterAddress = accounts[1];
        var initialBalance;
        var finalBalance;
        var availableCredit;
        return BountyApp.deployed().then(function (instance) {
            bountyAppInstance = instance;
            return bountyAppInstance.untrustedCheckBountyWinnings(bountyHunterAddress, { from: bountyHunterAddress });
        }).then(function (credit) {
            availableCredit = credit.valueOf();
            initialBalance = web3.eth.getBalance(bountyHunterAddress).valueOf();
            return bountyAppInstance.untrustedWithdrawBountyReward({ from: bountyHunterAddress });
        }).then(function (tx) {
            var weiUsedForGas = parseInt(tx.receipt.gasUsed) * parseInt(web3.eth.gasPrice.valueOf());
            finalBalance = web3.eth.getBalance(bountyHunterAddress).valueOf();
            assert.equal(finalBalance, parseInt(initialBalance) + parseInt(availableCredit) - weiUsedForGas, "Bounty winnings not withdrawn to bounty hunter's address");
        })
    });
    it("should revert when bounty contract with reward 0 is created", function () {
        return BountyApp.deployed().then(function (instance) {
            return instance.createBounty("abcd", 0, { from: accounts[0] });
        }).then(assert.fail).catch(function (error) {
            assert.include(error.message, "revert", error.toString());
        })
    });
    it("should revert when bounty reward of 0 has to be credited", function () {
        return BountyContract.deployed().then(function (instance) {
            return instance.untrustedCreditTransfer(accounts[1], 0, { from: accounts[1], value: 0 });
        }).then(assert.fail).catch(function (error) {
            assert.include(error.message, "revert", error.toString());
        })
    });
    it("should revert when bounty reward of 0 has to be withdrawn", function () {
        return BountyApp.deployed().then(function (instance) {
            return instance.untrustedWithdrawBountyReward({ from: accounts[1] });
        }).then(assert.fail).catch(function (error) {
            assert.include(error.message, "revert", error.toString());
        })
    });
});
