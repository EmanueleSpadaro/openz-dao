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
        it("Owner can transfer token", async () => {
            const daoInstance = await DaoContract.deployed();
            await daoInstance.transferToken("EUR", 250, user);
        })
    })
});

