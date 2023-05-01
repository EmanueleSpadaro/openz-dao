const DaoContract = artifacts.require("DAO");
const { log } = require('console');
const util = require('util');


contract("DAO", (accounts) => {
    const owner = accounts[0];
    const admin = accounts[1];
    const supervisor = accounts[2];
    const supervisor2 = accounts[3];
    const user = accounts[4];

    //This section aims to ensure that the given rank hierarchy is actually set correctly: OWNER > ADMIN > SUPERVISOR > USER
    describe("Hierarchy test", _ => {
        it("User has Supervisor as OpenZeppelin's AdminRole", async () => {
            const daoInstance = await DaoContract.deployed();
            assert.equal(
                await daoInstance.getRoleAdmin(await daoInstance.USER_ROLE()) == await daoInstance.SUPERVISOR_ROLE(),
                true,
                "supervisor should be user's adminrole"
            )
        })
        it("Supervisor has Admin as OpenZeppelin's AdminRole", async () => {
            const daoInstance = await DaoContract.deployed();
            assert.equal(
                await daoInstance.getRoleAdmin(await daoInstance.SUPERVISOR_ROLE()) == await daoInstance.ADMIN_ROLE(),
                true,
                "admin should be supervisor's adminrole"
            )
        })
        it("Admin has Owner as OpenZeppelin's AdminRole", async () => {
            const daoInstance = await DaoContract.deployed();
            assert.equal(
                await daoInstance.getRoleAdmin(await daoInstance.ADMIN_ROLE()) == await daoInstance.OWNER_ROLE(),
                true,
                "owner should be admin's adminrole"
            )
        })
        it("Owner has DEFAULT_ADMIN_ROLE as OpenZeppelin's AdminRole", async () => {
            const daoInstance = await DaoContract.deployed();
            assert.equal(
                await daoInstance.getRoleAdmin(await daoInstance.OWNER_ROLE()) == await daoInstance.DEFAULT_ADMIN_ROLE(),
                true,
                "owner should have default_admin as adminrole"
            )
        })
    })

    //This section ensures that invites work properly
    describe("Invite hierarchy compliance", _ => {
        it("First account is Owner", async () => {
            const daoInstance = await DaoContract.deployed();
            assert.equal(owner, await daoInstance.owner(), "first account should be dao owner");
        });
        it("Owner sets the DAO as Invite-Only", async () => {
            const daoInstance = await DaoContract.deployed();
            await daoInstance.setInviteOnly(true);
            assert.equal(await daoInstance.isInviteOnly(), true, "DAO should be Invite-Only after being set as such");
        });
        it("Future User can't join Invite-Only DAO", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.join({from: user});
            }catch(_){
                return true;
            }
            throw new Error("User shouldn't be able to join Invite-Only DAO without invitation"); 
        });
        it("Owner unsets the DAO as Invite-Only", async () => {
            const daoInstance = await DaoContract.deployed();
            await daoInstance.setInviteOnly(false);
            assert.equal(await daoInstance.isInviteOnly(), false, "DAO shouldn't be Invite-Only after being unset as such");
        })
        it("Owner can't rejoin the DAO since it's already in", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.join({from: owner});
            }catch(_){
                return true;
            }
            throw new Error("Owner shouldn't be able to rejoin the DAO since it's already a member");
        });
        it("Future User joins the DAO", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.join({from: user});
            }catch(_){
                throw new Error("Future User should be able to join the DAO since not a member yet");
            }
            return true;
        });
        it("Future User can't rejoin the DAO since it's already in", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.join({from: user});
            }catch(_){
                return true;
            }
            throw new Error("Future User shouldn't be able to rejoin the DAO since it's already a member");
        });
        it("Owner can't invite Future Admin as Owner", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.invite(admin, await daoInstance.OWNER_ROLE(), {from:owner})
            }catch(_){
                return true;
            }
            throw new Error("Owner shouldn't be allowed to invite future admin as owner");          
        })
        it("Future Admin can't accept non-existant invite", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.acceptInvite({from: admin});
            }catch(_){
                return true;
            }
            throw new Error("Future Admin shouldn't be allowed to accept a non-existant invite");
        })
        it("Owner invites Future Admin as Admin", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.invite(admin, await daoInstance.ADMIN_ROLE(), {from:owner})
            }catch(_){
                throw new Error('Owner should be allowed to invite future admin as admin');
            }
            return true;
        })
        it("Admin accepts invite as admin", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.acceptInvite({from:admin});
            }catch(_){
                throw new Error("Future Admin should be allowed to accept the invite");
            }
            assert.equal(
                await daoInstance.hasRole(await daoInstance.ADMIN_ROLE(), admin),
                true,
                "Future Admin should be considered an Admin after accepting the invite"
            );
        })
        it("User can't invite Future Supervisor as Supervisor", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.invite(supervisor, await daoInstance.SUPERVISOR_ROLE(), {from:user});
            }catch(_){
                return true;
            }
            throw new Error("User shouldn't be allowed to invite Future Supervisor as Supervisor");
        })
        it("User can't invite Future Supervisor as User", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.invite(supervisor, await daoInstance.USER_ROLE(), {from:user});
            }catch(_){
                return true;
            }
            throw new Error("User shouldn't be allowed to invite Future Supervisor as User");
        })
        it("Admin can't invite Future Supervisor as Admin", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.invite(supervisor, await daoInstance.ADMIN_ROLE(), {from:admin});
            }catch(_){
                return true;
            }
            throw new Error("Admin shouldn't be allowed to invite Future Supervisor as Admin");
        })
        it("Admin invites Future Supervisor as Supervisor", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.invite(supervisor, await daoInstance.SUPERVISOR_ROLE(), {from:admin});
                await daoInstance.invite(supervisor2, await daoInstance.SUPERVISOR_ROLE(), {from:admin});
            }catch(_){
                throw new Error("Admin should be allowed to invite Future Supervisor as Supervisor");
            }
            return true;
        })
        it("Supervisor accepts invite as supervisor", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.acceptInvite({from:supervisor});
                await daoInstance.acceptInvite({from:supervisor2});
            }catch(_){
                throw new Error("Future Supervisor should be allowed to accept the invite");
            }
            assert.equal(
                await daoInstance.hasRole(await daoInstance.SUPERVISOR_ROLE(), supervisor)
                && await daoInstance.hasRole(await daoInstance.SUPERVISOR_ROLE(), supervisor2),
                true,
                "Future Supervisor should be considered a Supervisor after accepting the invite"
            );
        })
    });

    describe("Promotion/Demotion system", _ => {
        it("2Phase Promotion User-Supervisor->Admin", async () => {
            const daoInstance = await DaoContract.deployed();
            //user->supervisor
            try{
                await daoInstance.modifyRank(user, await daoInstance.SUPERVISOR_ROLE());
                await daoInstance.acceptPromotion({from: user});
            }catch(_){
                throw new Error("Owner should be allowed to promote a User");
            }
            assert.equal(
                await daoInstance.hasRole(await daoInstance.USER_ROLE(), user),
                false,
                "User shouldn't be considered as such after being promoted"
            );
            assert.equal(
                await daoInstance.hasRole(await daoInstance.SUPERVISOR_ROLE(), user),
                true,
                "User should be considered a Supervisor after being promoted"
            );
            //supervisor->admin
            try{
                await daoInstance.modifyRank(user, await daoInstance.ADMIN_ROLE());
                await daoInstance.acceptPromotion({from: user});
            }catch(_){
                throw new Error("Owner should be allowed to promote a Supervisor");
            }
            assert.equal(
                await daoInstance.hasRole(await daoInstance.SUPERVISOR_ROLE(), user),
                false,
                "Supervisor shouldn't be considered as such after being promoted"
            );
            assert.equal(
                await daoInstance.hasRole(await daoInstance.ADMIN_ROLE(), user),
                true,
                "Supervisor should be considered an Admin after being promoted"
            );
        })
        it("Same role members can't modify each others", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                //User is set as Admin with the previous test iteration
                await daoInstance.modifyRank(user, await daoInstance.USER_ROLE(), {from: admin});
            }catch(_){
                return true;
            }
            throw new Error("Same role members shouldn't be allowed to modify each others");
        })
        it("Same role members can't kick each others", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.kickMember(user, {from:admin});
            }catch(_){
                return true;
            }
            throw new Error("Same role members shouldn't be allowed to kick each others");
        })
        it("1Phase Derank Admin->Supervisor->User", async () => {
            const daoInstance = await DaoContract.deployed();
            //admin->supervisor
            try{
                await daoInstance.modifyRank(user, await daoInstance.SUPERVISOR_ROLE());
            }catch(_){
                throw new Error("Owner should be allowed to demote an Admin");
            }
            assert.equal(
                await daoInstance.hasRole(await daoInstance.ADMIN_ROLE(), user),
                false,
                "Admin shouldn't be considered as such after being demoted"
            );
            assert.equal(
                await daoInstance.hasRole(await daoInstance.SUPERVISOR_ROLE(), user),
                true,
                "Admin should be considered a Supervisor after being demoted"
            );
            //supervisor->user
            try{
                await daoInstance.modifyRank(user, await daoInstance.USER_ROLE());
            }catch(_){
                throw new Error("Owner should be allowed to demote a Supervisor");
            }
            assert.equal(
                await daoInstance.hasRole(await daoInstance.SUPERVISOR_ROLE(), user),
                false,
                "Supervisor shouldn't be considered as such after being demoted"
            );
            assert.equal(
                await daoInstance.hasRole(await daoInstance.USER_ROLE(), user),
                true,
                "Supervisor should be considered a User after being demoted"
            );
        })
        it("User can't accept/refuse non-existant promotion", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.acceptPromotion({from: user});
            }catch(_){
            try{
                await daoInstance.refusePromotion({from:user});
            }catch(_){
                return true;
            }
            }
            throw new Error("User shouldn't be allowed to accept or refuse no-existant promotions");
        })
        it("Owner kicks member (member joins back right after)", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.kickMember(user);
            }catch(_){
                throw new Error("Owner should be alllowed to kick a User");
            }
            try{
                await daoInstance.join({from: user});
            }catch(_){
                throw new Error("User that got kicked couldn't join freely-joinable DAO");
            }
        })
    })
    describe('Role based micro-permissions', _ => {
        describe('Token Transfer', _ => {
            it("Owner can transfer token", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.transferToken("EUR", 250, user);
            })
            it("Admin can transfer token", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.transferToken("EUR", 250, user, {from:admin});
            })
            it("Supervisor without token auth can't transfer token", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.transferToken("EUR", 250, user, {from:supervisor});
                }catch(_){
                    return true;
                }
                throw new Error("Supervisor without token auth shouldn't be able to transfer token")
            })
            it("Admin authorizes Supervisor for Token", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.setTokenAuth("EUR", supervisor, {from:admin});
                }catch(_){
                    throw new Error("Admin should be able to authorize a supervisor for a specific token");
                }
                assert.equal(
                    await daoInstance.getTokenAuth("EUR", supervisor),
                    true,
                    "Supervisor shall be consider authorized for a token after being set as such by admin"
                )
            })
            it("Authorized Supervisor can transfer token", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.transferToken("EUR", 250, user, {from: supervisor});
                }catch(_){
                    throw new Error("Authorized Supervisor should be able to transfer a specific token for which it's authorized")
                }
            })
        })
        describe('Token Create', _ => {
            it("Owner can create a Token", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.createToken("Euro", "EUR", 2, "", "", 0, "", {from:owner});
                }catch(_){
                    throw new Error("Owner should be able to create a token");
                }
                return true;
            });
            it("Admin can create a Token", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.createToken("Euro", "EUR", 2, "", "", 0, "", {from:admin});
                }catch(_){
                    throw new Error("Admin should be able to create a token");
                }
                return true;
            });
            it("Supervisor can't create a Token", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.createToken("Euro", "EUR", 2, "", "", 0, "", {from:supervisor});
                }catch(_){
                    return true;

                }
                throw new Error("Supervisor shouldn't be able to create a token");
            });
            it("User can't create a Token", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.createToken("Euro", "EUR", 2, "", "", 0, "", {from:user});
                }catch(_){
                    return true;

                }
                throw new Error("User shouldn't be able to create a token");
            });
        })
        describe("Token Mint", _ => {
            it("Owner can mint token", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.mintToken("EUR", 250, {from: owner});
            })
            it("Admin can mint token", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.mintToken("EUR", 250, {from: admin});
            })
            it("Supervisor cannot mint token", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.mintToken("EUR", 250, {from: supervisor});
                }catch(_){
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to mint a token")
            })
            it("User cannot mint token", async () => {
                const daoInstance = await DaoContract.deployed();
                try {
                    await daoInstance.mintToken("EUR", 250, {from: user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to mint a token")
            })
        })
        describe("Token Authorizations", _ => {
            it("Supervisor can't authorize himself", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.setTokenAuth("EUR", supervisor, {from:supervisor});
                }catch(_){
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to authorize himself for a specific token")
            })
            it("Supervisor getTokenAuth consistence (true)", async () => {
                const daoInstance = await DaoContract.deployed();
                assert.equal(
                    await daoInstance.getTokenAuth("EUR", supervisor),
                    true,
                    "Supervisor getTokenAuth not consistent with previous assignments"
                );
            })
            it("Admin reverts Supervisor authorization for Token", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.removeTokenAuth("EUR", supervisor, {from:admin});
                }catch(_){
                    throw new Error("Admin should be able to authorize a supervisor for a specific token");
                }
                assert.equal(
                    await daoInstance.getTokenAuth("EUR", supervisor),
                    false,
                    "Supervisor shouldn't be consider authorized for a token after being unset by admin"
                )
            })
            it("User can't be authorized for tokens", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.setTokenAuth("EUR", user, {from:owner});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to be authorized for a specific token")
            })
            it("Owner reapplies token Authorization for Supervisor", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.setTokenAuth("EUR", supervisor, {from:owner});
                }catch(_){
                    throw new Error("Owner should be able to authorize a supervisor for a specific token");
                }
                assert.equal(
                    await daoInstance.getTokenAuth("EUR", supervisor),
                    true,
                    "Supervisor should be consider authorized for a token after being set as such by owner"
                )
            })
        })
        describe("Crowdsale Creation", _ => {
            it("Owner can create a Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.createCrowdsale(user, user, 0, 0, 0, 0, 0, "desc", "desc", "logo_hash", "tos_hash");
            })
            it("Admin can create a Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.createCrowdsale(user, user, 0, 0, 0, 0, 0, "desc", "desc", "logo_hash", "tos_hash", {from:admin});
            })
            it("Supervisor can't create a Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.createCrowdsale(user, user, 0, 0, 0, 0, 0, "desc", "desc", "logo_hash", "tos_hash", {from:supervisor});
                }catch(_){
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to create a crowdsale");
            })
            it("User can't create a Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.createCrowdsale(user, user, 0, 0, 0, 0, 0, "desc", "desc", "logo_hash", "tos_hash", {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to create a crowdsale");
            })
        })
        describe("Crowdsale Unlock", _ => {
            it("Owner can unlock Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.unlockCrowdsale(user, user, 0);
            })
            it("Admin can unlock Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.unlockCrowdsale(user, user, 0, {from:admin});
            })
            it("Supervisor cannot unlock Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.unlockCrowdsale(user, user, 0, {from:supervisor});
                }catch(_){
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to unlock a Crowdsale");
            })
            it("User cannot unlock Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.unlockCrowdsale(user, user, 0, {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to unlock a Crowdsale");
            })
        })
        describe("Crowdsale Stop", _ => {
            it("Owner can stop Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.stopCrowdsale(user);
            })
            it("Admin can stop Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.stopCrowdsale(user, {from:admin});
            })
            it("Supervisor cannot stop Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.stopCrowdsale(user, {from:supervisor});
                }catch(_){
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to stop a Crowdsale");
            })
            it("User cannot stop Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.stopCrowdsale(user, {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to stop a Crowdsale");
            })
        })
        describe("Crowdsale Join", _ => {
            it("Owner can join Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.joinCrowdsale(user, 0, "EUR", {from:owner});
            })
            it("Admin can join Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.joinCrowdsale(user, 0, "EUR", {from:admin});
            })
            //todo we'll probably have to change this test when implementing commonshood logic
            it("Supervisor can join Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.joinCrowdsale(user, 0, "EUR", {from:supervisor});
                //try{
                //    await daoInstance.joinCrowdsale(user, 0, "EUR", {from:supervisor});
                //}catch(_){
                //    return true;
                //}
                //throw new Error("Supervisor shouldn't be able to join a Crowdsale");
            })
            it("User cannot join Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.joinCrowdsale(user, {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to join a Crowdsale");
            })
        })
        describe("Crowdsale Refund", _ => {
            it("Owner can refund Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.refundMeCrowdsale(user, 0, {from:owner});
            })
            it("Admin can refund Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.refundMeCrowdsale(user, 0, {from:admin});
            })
            //todo we'll probably have to change this test when implementing commonshood logic
            it("Supervisor can refund Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.refundMeCrowdsale(user, 0, {from:supervisor});
            })
            it("User cannot refund Crowdsale", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.refundMeCrowdsale(user, {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to refund a Crowdsale");
            })
        })
        describe("Crowdsale Permissions Grant/Revoke", _ => {
            const crowdsaleID = user;
            it("Owner grants/revokes to Supervisor", async () => {
                const daoInstance = await DaoContract.deployed();
                assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, supervisor), false, "Supervisor shouldn't have permissions for given crowdsale before assignment");
                await daoInstance.makeAdminCrowdsale(crowdsaleID, supervisor, {from:owner});
                assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, supervisor), true, "Supervisor should have now permissions for given crowdsale");
                await daoInstance.removeAdminCrowdsale(crowdsaleID, supervisor, {from:owner});
                assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, supervisor), false, "Supervisor shouldn't have permissions for given crowdsale");
            })
            it("Admin grants/revokes to Supervisor", async () => {
                const daoInstance = await DaoContract.deployed();
                assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, supervisor), false, "Supervisor shouldn't have permissions for given crowdsale before assignment");
                await daoInstance.makeAdminCrowdsale(crowdsaleID, supervisor, {from:admin});
                assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, supervisor), true, "Supervisor should have now permissions for given crowdsale");
                await daoInstance.removeAdminCrowdsale(crowdsaleID, supervisor, {from:admin});
                assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, supervisor), false, "Supervisor shouldn't have permissions for given crowdsale");
            })
            it("Supervisor cannot grant/revoke", async () => {
                const daoInstance = await DaoContract.deployed();
                assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, supervisor2), false, "Supervisor shouldn't have permissions for given crowdsale before assignment");
                try{
                    await daoInstance.makeAdminCrowdsale(crowdsaleID, supervisor2, {from:supervisor});
                }catch(_){
                    assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, supervisor2), false, "Supervisor shouldn't have permissions for given crowdsale");
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to give crowdsale permissions to other users");
            })
            it("User cannot grant/revoke", async () => {
                const daoInstance = await DaoContract.deployed();
                assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, user), false, "User shouldn't have permissions for given crowdsale before assignment");
                try{
                    await daoInstance.makeAdminCrowdsale(crowdsaleID, user, {from:owner});
                }catch(_){
                    assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, user), false, "User shouldn't have permissions for given crowdsale");
                    return true;
                }
                throw new Error("User shouldn't be able to give crowdsale permissions to other users");
            })
            it("User cannot receive crowdsale permissions", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.makeAdminCrowdsale(crowdsaleID, user, {from:owner});
                }catch(_){
                    assert.equal(await daoInstance.getCrowdsaleManagement(crowdsaleID, user), false, "User shouldn't have permissions for given crowdsale");
                    return true;
                }
                throw new Error("User shouldn't be able to receive crowdsale permissions");
            })
        })
        describe("Exchange Create", _ => {
            const coinsOffered = [];
            const coinsRequired = [];
            const amountsOffered = [];
            const amountsRequired = [];
            const repeats = 0;
            const expiration = 0;
            it("Owner can create a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.createExchange(coinsOffered, coinsRequired, amountsOffered, amountsRequired, repeats, expiration, {from:owner});
            })
            it("Admin can create a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.createExchange(coinsOffered, coinsRequired, amountsOffered, amountsRequired, repeats, expiration, {from:admin});
            })
            it("Supervisor cannot create a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.createExchange(coinsOffered, coinsRequired, amountsOffered, amountsRequired, repeats, expiration, {from:supervisor});
                }catch(_){
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to create an exchange");
            })
            it("User cannot create a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.createExchange(coinsOffered, coinsRequired, amountsOffered, amountsRequired, repeats, expiration, {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to create an exchange");
            })
        })
        describe("Exchange Cancel", _ => {
            const exchangeID = user;
            it("Owner can cancel a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.cancelExchange(exchangeID, {from:owner});
            })
            it("Admin can cancel a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.cancelExchange(exchangeID, {from:admin});
            })
            it("Supervisor cannot cancel a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.cancelExchange(exchangeID, {from:supervisor});
                }catch(_){
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to cancel an exchange");
            })
            it("User cannot cancel a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.cancelExchange(exchangeID, {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to cancel an exchange");
            })
        })
        describe("Exchange Renew", _ => {
            const exchangeID = user;
            it("Owner can renew a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.renewExchange(exchangeID, {from:owner});
            })
            it("Admin can renew a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.renewExchange(exchangeID, {from:admin});
            })
            it("Supervisor cannot renew a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.renewExchange(exchangeID, {from:supervisor});
                }catch(_){
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to renew an exchange");
            })
            it("User cannot renew a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.renewExchange(exchangeID, {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to renew an exchange");
            })
        })
        describe("Exchange Accept", _ => {
            const exchangeID = user;
            const coinsRequired = [];
            const coinsAmounts = [];
            const repeats = 0;
            it("Owner can accept a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.acceptExchange(exchangeID, coinsRequired, coinsAmounts, repeats, {from:owner});
            })
            it("Admin can accept a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.acceptExchange(exchangeID, coinsRequired, coinsAmounts, repeats, {from:admin});
            })
            it("Supervisor cannot accept a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.acceptExchange(exchangeID, coinsRequired, coinsAmounts, repeats, {from:supervisor});
            })
            it("User cannot accept a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.acceptExchange(exchangeID, coinsRequired, coinsAmounts, repeats, {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to accept an exchange");
            })
        })
        describe("Exchange Refill", _ => {
            const exchangeID = user;
            const coinsOffered = [];
            const coinsAmounts = [];
            const repeats = 0;
            it("Owner can accept a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.refillExchange(exchangeID, coinsOffered, coinsAmounts, repeats, {from:owner});
            })
            it("Admin can accept a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.refillExchange(exchangeID, coinsOffered, coinsAmounts, repeats, {from:admin});
            })
            it("Supervisor cannot accept a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                await daoInstance.refillExchange(exchangeID, coinsOffered, coinsAmounts, repeats, {from:supervisor});
            })
            it("User cannot accept a Exchange", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.refillExchange(exchangeID, coinsOffered, coinsAmounts, repeats, {from:user});
                }catch(_){
                    return true;
                }
                throw new Error("User shouldn't be able to refill an exchange");
            })
        })
        describe("Exchange Permissions Grant/Revoke", _ => {
            const exchangeID = user;
            it("Owner grants/revokes to Supervisor", async () => {
                const daoInstance = await DaoContract.deployed();
                assert.equal(await daoInstance.getExchangeManagement(exchangeID, supervisor), false, "Supervisor shouldn't have permissions for given exchange before assignment");
                await daoInstance.makeAdminExchange(exchangeID, supervisor, {from:owner});
                assert.equal(await daoInstance.getExchangeManagement(exchangeID, supervisor), true, "Supervisor should have now permissions for given exchange");
                await daoInstance.removeAdminExchange(exchangeID, supervisor, {from:owner});
                assert.equal(await daoInstance.getExchangeManagement(exchangeID, supervisor), false, "Supervisor shouldn't have permissions for given exchange");
            })
            it("Admin grants/revokes to Supervisor", async () => {
                const daoInstance = await DaoContract.deployed();
                assert.equal(await daoInstance.getExchangeManagement(exchangeID, supervisor), false, "Supervisor shouldn't have permissions for given exchange before assignment");
                await daoInstance.makeAdminExchange(exchangeID, supervisor, {from:admin});
                assert.equal(await daoInstance.getExchangeManagement(exchangeID, supervisor), true, "Supervisor should have now permissions for given exchange");
                await daoInstance.removeAdminExchange(exchangeID, supervisor, {from:admin});
                assert.equal(await daoInstance.getExchangeManagement(exchangeID, supervisor), false, "Supervisor shouldn't have permissions for given exchange");
            })
            it("Supervisor cannot grant/revoke", async () => {
                const daoInstance = await DaoContract.deployed();
                assert.equal(await daoInstance.getExchangeManagement(exchangeID, supervisor2), false, "Supervisor shouldn't have permissions for given exchange before assignment");
                try{
                    await daoInstance.makeAdminExchange(exchangeID, supervisor2, {from:supervisor});
                }catch(_){
                    assert.equal(await daoInstance.getExchangeManagement(exchangeID, supervisor2), false, "Supervisor shouldn't have permissions for given exchange");
                    return true;
                }
                throw new Error("Supervisor shouldn't be able to give exchange permissions to other users");
            })
            it("User cannot grant/revoke", async () => {
                const daoInstance = await DaoContract.deployed();
                assert.equal(await daoInstance.getExchangeManagement(exchangeID, user), false, "User shouldn't have permissions for given exchange before assignment");
                try{
                    await daoInstance.makeAdminExchange(exchangeID, user, {from:owner});
                }catch(_){
                    assert.equal(await daoInstance.getExchangeManagement(exchangeID, user), false, "User shouldn't have permissions for given exchange");
                    return true;
                }
                throw new Error("User shouldn't be able to give exchange permissions to other users");
            })
            it("User cannot receive exchange permissions", async () => {
                const daoInstance = await DaoContract.deployed();
                try{
                    await daoInstance.makeAdminExchange(exchangeID, user, {from:owner});
                }catch(_){
                    assert.equal(await daoInstance.getExchangeManagement(exchangeID, user), false, "User shouldn't have permissions for given exchange");
                    return true;
                }
                throw new Error("User shouldn't be able to receive exchange permissions");
            })
        })
    })
});

