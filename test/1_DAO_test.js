const DaoContract = artifacts.require("DAO");
const { log } = require('console');
const util = require('util');


contract("DAO", (accounts) => {
    const owner = accounts[0];
    const admin = accounts[1];
    const supervisor = accounts[2];
    const user = accounts[3];

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

    //This section aims to ensure that the custom isAdminOf goes up the rank ladder to ensure that we recognize, for example, OWNER, as upper admin of USER
    // describe("Custom Method Hierarchy test", _ => {
    //     it("User has Admin as upperRole", async () => {
    //         const daoInstance = await DaoContract.deployed();
    //         assert.equal(
    //             await daoInstance.isAdminOf(user), true, "owner should be user's upper admin"
    //         )
    //     })
    // })

    //This section ensures that invites work properly
    describe("Invite hierarchy compliance", _ => {
        it("First account is Owner", async () => {
            const daoInstance = await DaoContract.deployed();
            assert.equal(owner, await daoInstance.owner(), "first account should be dao owner");
        });
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
            }catch(_){
                throw new Error("Admin should be allowed to invite Future Supervisor as Supervisor");
            }
            return true;
        })
        it("Supervisor accepts invite as supervisor", async () => {
            const daoInstance = await DaoContract.deployed();
            try{
                await daoInstance.acceptInvite({from:supervisor});
            }catch(_){
                throw new Error("Future Supervisor should be allowed to accept the invite");
            }
            assert.equal(
                await daoInstance.hasRole(await daoInstance.SUPERVISOR_ROLE(), supervisor),
                true,
                "Future Supervisor should be considered a Supervisor after accepting the invite"
            );
        })
    })

    
    // it("Fourth account joins freely joinable dao as user", async () => {
    //     const daoInstance = await DaoContract.deployed();
    //     await daoInstance.join({from: user});
    //     assert.equal(await daoInstance.hasRole(await daoInstance.USER_ROLE(), user), true, "fourth user should be user");
    // })
    // it("Second account shouldn't be user", async () => {
    //     const daoInstance = await DaoContract.deployed();
    //     assert.equal(await daoInstance.hasRole(await daoInstance.USER_ROLE(), admin), false, "second user shouldn't be user");
    // })
    // it("Owner shall be higher admin of fourth user even though it's not OpenZeppelin admin", async () => {
    //     const daoInstance = await DaoContract.deployed();
    //     assert.equal(
    //         await daoInstance.isAdminOf(user, {from: owner}), true, "owner should be user's upper admin"
    //     )
    // })

});

