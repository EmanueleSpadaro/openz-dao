//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./DAOFactory.sol";
import './CrowdsaleFactory.sol';
import './ExchangeFactory.sol';
import './TokenFactory.sol';

contract DAO is AccessControlEnumerable {
    //We use this util set to easily manage existing roles
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    //External project requirement, it states "dao" to distinguish the DAO from standard user
    string public realm;
    //Address of the owner
    address public owner;
    //Address of the DAOFactory that generated this contract
    DAOFactory public daoFactory;
    CrowdsaleFactory public crowdsaleFactory;
    ExchangeFactory public exchangeFactory;
    TokenFactory public tokenFactory;

    //DAO's name, its uniqueness shall be managed by a Factory contract
    string public name;
    //It states the ID of a place inside a map. Each DAO has to be linked to a given place
    string public firstlifePlaceID;

    //DAO's description
    string public description_cid;
    //Specifies whether you can join this DAO freely or under invitation
    bool public isInviteOnly = false;



    //Rank system
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE"); 
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    //Auxiliary struct to allow us to delete rolePermissions in case of role deletion
    struct RolePermissionsStruct {
        EnumerableSet.UintSet permissions;
    }

    struct UserStruct {
        bytes32 role;
        EnumerableSet.Bytes32Set tokenManagement;
        EnumerableSet.AddressSet crowdsaleManagement;
        EnumerableSet.AddressSet exchangeManagement;
    }

    EnumerableSet.Bytes32Set roles;
    mapping(address => UserStruct) users;
    mapping(address => bytes32) invites;
    mapping(address => bytes32) promotions;
    mapping(bytes32 => RolePermissionsStruct) rolePermissions;

    enum DaoPermission {
        //Whether it can alter the inviteOnly flag for the given DAO
        invite_switch,
        //Whether it can manage all tokens
        token_all,
        //Whether it can manage only specific tokens
        token_specific,
        //Whether it can transfer manageable tokens
        token_transfer,
        //Whether it can create tokens
        token_create,
        //Whether it can mint manageable tokens
        token_mint,
        //Whether it can authorize others to use a specific token
        token_auth,
        //Whether it can be set as authorized to manage specific tokens
        token_canmanage,
        //Whether it can create a crowdsale
        crowd_create,
        //Whether it can join a crowdsale
        crowd_join,
        //Whether it can unlock a crowdsale
        crowd_unlock,
        //Whether it can refund a crowdsale
        crowd_refund,
        //Whether it can stop a crowdsale
        crowd_stop,
        //Whether it can offer / revoke a DAO member (must have crowd_canmanage permission) management privileges regarding a specific crowdsale
        crowd_setadmin,
        //Whether it can be set as crowdsale manager by members with crowd_setadmin permissions
        crowd_canmanage,
        //Whether it can create an exchange
        exchange_create,
        //Whether it can cancel an exchange
        exchange_cancel,
        //Whether it can renew an exchange
        exchange_renew,
        //Whether it can accept an exchange
        exchange_accept,
        //Whether it can refill an exchange
        exchange_refill,
        //Whether it can offer / revoke a DAO member (that has exchange_canmanage permission) management privileges regarding a specific exchange
        exchange_setadmin,
        //Whether it can be set as exchange manager by members with exchange_setadmin permissions
        exchange_canmanage
    }

    //Modifier that allows to execute the code only if the caller IS a member
    modifier isMember(address addr) {
        require(users[addr].role != bytes32(0), "you're required to be a member");
        _;
    }

    //Modifier that allows to execute the code only if the caller IS NOT a member
    modifier isNotMember(address addr) {
        require(users[addr].role == bytes32(0), "you're required to not be a member");
        _;
    }

    //Modifier that allows to execute the code only if the caller has a pending invitation
    modifier hasInvite() {
        require(invites[msg.sender] != 0, "no invite available for you");
        _;
    }

    //Modifier that allows to execute the code only if the caller has a pending promotion
    modifier hasPromotion() {
        require(promotions[msg.sender] != 0, "no promotion pending");
        _;
    }

    //Modifier that allows to execute the code only if the caller is hierarchically superior in terms of rank
    modifier isAdminOf(address ofAddress) {
        require(isAdminOfRole(msg.sender, users[ofAddress].role), "you're required to be of higher rank");
        _;
    }

    //Modifier that extends the behaviour achievable with onlyRole(getRoleAdmin(role)) to hierarchically superior ranks
    modifier onlyAdmins(bytes32 role) {
        require(isAdminOfRole(msg.sender, role), "only higher ranks of the given role are allowed");
        _;
    }

    modifier hasPermission(DaoPermission permission) {
        require(rolePermissions[users[msg.sender].role].permissions.contains(uint256(permission)), "not enough permissions");
        _;
    }

    modifier canManageToken(string memory tokenSymbol) {
        require(getTokenAuth(tokenSymbol, msg.sender), "not authorized to manage token");
        _;
    }

    modifier isLegitRole(bytes32 role) {
        require(roles.contains(role), "non-existing role");
        _;
    }

    modifier notDefaultRole(bytes32 role) {
        require(role != OWNER_ROLE && role != ADMIN_ROLE && role != SUPERVISOR_ROLE && role != USER_ROLE,
        "non-default DAO role expected");
        _;
    }

    event UserJoined(address indexed user, bytes32 asRole);
    event UserInvited(address indexed by, address user);
    event UserDeranked(address indexed by, address user, bytes32 toRole);
    event UserPromotionProposed(address indexed by, address user, bytes32 toRole);
    event UserPromoted(address indexed user, bytes32 toRole);
    event UserKicked(address indexed by, address user);
    event UserTokenAuthorization(address indexed by, address user, string token);
    event UserTokenAuthorizationRevoked(address indexed by, address user, string token);

    constructor(
        address _owner,
        string memory _name,
        string memory _description,
        string memory _firstlifePlaceID,
        address _tokenFactory,
        address _crowdsaleFactory,
        address _exchangeFactory,
        address _daoFactory
    ){
        realm = "dao";
        owner = _owner;
        name = "Test_DAO";
        firstlifePlaceID = _firstlifePlaceID;
        description_cid = "La best residenza da quittare asap";
        daoFactory = DAOFactory(_daoFactory);
        tokenFactory = TokenFactory(_tokenFactory);
        crowdsaleFactory = CrowdsaleFactory(_crowdsaleFactory);
        exchangeFactory = ExchangeFactory(_crowdsaleFactory);
        isInviteOnly = false;
        _grantRole(OWNER_ROLE, owner);
        //We setup the role hierarchy in terms of admin role:
        //OWNER -> ADMIN -> SUPERVISOR -> USER
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(SUPERVISOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(USER_ROLE, SUPERVISOR_ROLE);
        //We add the roles to our set (this shall be the only case where we call roles.add instead of addRole)
        roles.add(OWNER_ROLE);
        roles.add(ADMIN_ROLE);
        roles.add(SUPERVISOR_ROLE);
        roles.add(USER_ROLE);
        //We setup the role permissions
        //OWNER
        _grantPermission(DaoPermission.token_all, OWNER_ROLE);
        _grantPermission(DaoPermission.token_specific, OWNER_ROLE);
        _grantPermission(DaoPermission.token_transfer, OWNER_ROLE);
        _grantPermission(DaoPermission.token_create, OWNER_ROLE);
        _grantPermission(DaoPermission.token_mint, OWNER_ROLE);
        _grantPermission(DaoPermission.token_auth, OWNER_ROLE);
        _grantPermission(DaoPermission.token_canmanage, OWNER_ROLE);
        _grantPermission(DaoPermission.crowd_create, OWNER_ROLE);
        _grantPermission(DaoPermission.crowd_join, OWNER_ROLE);
        _grantPermission(DaoPermission.crowd_unlock, OWNER_ROLE);
        _grantPermission(DaoPermission.crowd_refund, OWNER_ROLE);
        _grantPermission(DaoPermission.crowd_stop, OWNER_ROLE);
        _grantPermission(DaoPermission.crowd_setadmin, OWNER_ROLE);
        _grantPermission(DaoPermission.crowd_canmanage, OWNER_ROLE);
        _grantPermission(DaoPermission.exchange_create, OWNER_ROLE);
        _grantPermission(DaoPermission.exchange_cancel, OWNER_ROLE);
        _grantPermission(DaoPermission.exchange_renew, OWNER_ROLE);
        _grantPermission(DaoPermission.exchange_accept, OWNER_ROLE);
        _grantPermission(DaoPermission.exchange_refill, OWNER_ROLE);
        _grantPermission(DaoPermission.exchange_setadmin, OWNER_ROLE);
        _grantPermission(DaoPermission.exchange_canmanage, OWNER_ROLE);
        _grantPermission(DaoPermission.invite_switch, OWNER_ROLE);
        //ADMIN
        _grantPermission(DaoPermission.token_all, ADMIN_ROLE);
        _grantPermission(DaoPermission.token_specific, ADMIN_ROLE);
        _grantPermission(DaoPermission.token_transfer, ADMIN_ROLE);
        _grantPermission(DaoPermission.token_create, ADMIN_ROLE);
        _grantPermission(DaoPermission.token_mint, ADMIN_ROLE);
        _grantPermission(DaoPermission.token_auth, ADMIN_ROLE);
        _grantPermission(DaoPermission.token_canmanage, ADMIN_ROLE);
        _grantPermission(DaoPermission.crowd_create, ADMIN_ROLE);
        _grantPermission(DaoPermission.crowd_join, ADMIN_ROLE);
        _grantPermission(DaoPermission.crowd_unlock, ADMIN_ROLE);
        _grantPermission(DaoPermission.crowd_refund, ADMIN_ROLE);
        _grantPermission(DaoPermission.crowd_stop, ADMIN_ROLE);
        _grantPermission(DaoPermission.crowd_setadmin, ADMIN_ROLE);
        _grantPermission(DaoPermission.crowd_canmanage, ADMIN_ROLE);
        _grantPermission(DaoPermission.exchange_create, ADMIN_ROLE);
        _grantPermission(DaoPermission.exchange_cancel, ADMIN_ROLE);
        _grantPermission(DaoPermission.exchange_renew, ADMIN_ROLE);
        _grantPermission(DaoPermission.exchange_accept, ADMIN_ROLE);
        _grantPermission(DaoPermission.exchange_refill, ADMIN_ROLE);
        _grantPermission(DaoPermission.exchange_setadmin, ADMIN_ROLE);
        _grantPermission(DaoPermission.exchange_canmanage, ADMIN_ROLE);
        _grantPermission(DaoPermission.invite_switch, ADMIN_ROLE);
        //SUPERVISOR
        _grantPermission(DaoPermission.token_specific, SUPERVISOR_ROLE);
        _grantPermission(DaoPermission.token_transfer, SUPERVISOR_ROLE);
        _grantPermission(DaoPermission.token_canmanage, SUPERVISOR_ROLE);
        _grantPermission(DaoPermission.crowd_join, SUPERVISOR_ROLE);
        _grantPermission(DaoPermission.crowd_refund, SUPERVISOR_ROLE);
        _grantPermission(DaoPermission.crowd_canmanage, SUPERVISOR_ROLE);
        _grantPermission(DaoPermission.exchange_accept, SUPERVISOR_ROLE);
        _grantPermission(DaoPermission.exchange_refill, SUPERVISOR_ROLE);
        _grantPermission(DaoPermission.exchange_canmanage, SUPERVISOR_ROLE);
        //USER must have no permissions
    }

    function isAdminOfRole(bytes32 isAdminRole, bytes32 ofRole) public view returns(bool){
        bytes32 ofRoleAdminRole = getRoleAdmin(ofRole);
        while(ofRoleAdminRole != DEFAULT_ADMIN_ROLE){
            if(ofRoleAdminRole == isAdminRole){
                return true;
            }
            ofRoleAdminRole = getRoleAdmin(ofRoleAdminRole);
        }
        return isAdminRole == DEFAULT_ADMIN_ROLE;
    }

    function isAdminOfRole(address isAdmin, bytes32 ofRole) public view returns(bool){
        return isAdminOfRole(users[isAdmin].role, ofRole);
    }

    //Joins the DAO
    function join() public isNotMember(msg.sender) {
        require(!isInviteOnly, "can't freely join invite-only dao");
        delete invites[msg.sender];
        _grantRole(USER_ROLE, msg.sender);
        daoFactory.addJoinedDaoTo(msg.sender);
        emit UserJoined(msg.sender, USER_ROLE);
    }

    //Alters the DAO Invite-Only flag
    function setInviteOnly(bool newValue) public isMember(msg.sender) hasPermission(DaoPermission.invite_switch) {
        require(isInviteOnly != newValue, "invite only already set as desired value");
        isInviteOnly = newValue;
    }

    //Invites a user with the given role to join the DAO
    function invite(address toInvite, bytes32 offeredRole) public isMember(msg.sender) isNotMember(toInvite) onlyAdmins(offeredRole) {
        invites[toInvite] = offeredRole;
        emit UserInvited(msg.sender, toInvite);
    }

    //Accepts an invite to the DAO
    function acceptInvite() public hasInvite{
        //We assign the role
        _grantRole(invites[msg.sender], msg.sender);
        //We delete the invite since it's been accepted
        invites[msg.sender] = 0;
        daoFactory.addJoinedDaoTo(msg.sender);
        emit UserJoined(msg.sender, users[msg.sender].role);
    }

    //Declines an invite to the DAO
    function declineInvite() public hasInvite{
        //We delete the invite since it's been declined
        invites[msg.sender] = 0;
    }

    //Offers a promotion if the new role is higher than the current one, otherwise it deranks instantly, if we have enough permissions
    function modifyRank(address toModify, bytes32 newRole) public isMember(toModify) isAdminOf(toModify) onlyAdmins(newRole) {
        bool isPromotion = isAdminOfRole(newRole, users[toModify].role);
        //If there's a pending promotion, we delete it whether it's a promotion or not
        delete promotions[toModify];
        //If it's a promotion, there is a 2Phase (offer && accept/refuse)
        if(isPromotion){
            promotions[toModify] = newRole;
            emit UserPromotionProposed(msg.sender, toModify, newRole);
            return;
        }
        //If it's not a promotion, we just revoke the role and emit the event
        _revokeRole(users[toModify].role, toModify);
        _grantRole(newRole, toModify);
        emit UserDeranked(msg.sender, toModify, newRole);
    }

    function acceptPromotion() public isMember(msg.sender) hasPromotion {
        _revokeRole(users[msg.sender].role, msg.sender);
        _grantRole(promotions[msg.sender], msg.sender);
        delete promotions[msg.sender];
        emit UserPromoted(msg.sender, users[msg.sender].role);
    }

    function refusePromotion() public isMember(msg.sender) hasPromotion {
        delete promotions[msg.sender];
    }

    //Kicks a member if we have enough permissions
    function kickMember(address toKick) public isMember(toKick) isAdminOf(toKick) {
        //We clear out possible promotions before kicking the member
        delete promotions[toKick];
        //Revoke role inherently deletes the kicked member struct, deleting their management permissions
        _revokeRole(users[toKick].role, toKick);
        daoFactory.removeJoinedDaoFrom(toKick);
        emit UserKicked(msg.sender, toKick);
    }

    function transferToken(string memory symbol, uint256 amount, address to)
    public isMember(msg.sender) hasPermission(DaoPermission.token_transfer) canManageToken(symbol){
        //todo implement actual logic from commonshood
    }

    function createToken(string memory _name, string memory _symbol, uint8 _decimals, string memory _logoURL, string memory _logoHash, uint256 _hardCap, string memory _contractHash)
    public isMember(msg.sender) hasPermission(DaoPermission.token_create) {
        //todo implement actual logic from commonshood
    }

    function mintToken(string memory _name, uint256 _value)
    public isMember(msg.sender) hasPermission(DaoPermission.token_mint) {
        //todo implement actual logic from commonshood
    }

    function setTokenAuth(string memory symbol, address _address)
    public isMember(_address) isMember(msg.sender) hasPermission(DaoPermission.token_auth) canManageToken(symbol) {
        require(hasPermissions(DaoPermission.token_canmanage, _address), "Target user has no permissions to be authorized for tokens");
        require(!users[_address].tokenManagement.contains(keccak256(abi.encodePacked(symbol))),"Address already authorized for this Token");
        users[_address].tokenManagement.add(keccak256(abi.encodePacked(symbol)));
        emit UserTokenAuthorization(msg.sender, _address, symbol);
    }

    function removeTokenAuth(string memory symbol, address _address)
    public isMember(_address) isMember(msg.sender) hasPermission(DaoPermission.token_auth) canManageToken(symbol) {
        require(users[_address].tokenManagement.contains(keccak256(abi.encodePacked(symbol))),"Address already not authorized for this Token");
        users[_address].tokenManagement.remove(keccak256(abi.encodePacked(symbol)));
        emit UserTokenAuthorizationRevoked(msg.sender, _address, symbol);
    }

    function getTokenAuth(string memory tokenSymbol, address _address) public view returns (bool){
        return rolePermissions[getRole(_address)].permissions.contains(uint256(DaoPermission.token_all)) ||
        (rolePermissions[getRole(_address)].permissions.contains(uint256(DaoPermission.token_specific)) &&
        users[_address].tokenManagement.contains(keccak256(abi.encodePacked(tokenSymbol))));
    }

    function createCrowdsale(address _tokenToGive, address _tokenToAccept, uint256 _start, uint256 _end, uint256 _acceptRatio, uint256 _giveRatio, uint256 _maxCap, string memory _title, string memory _description, string memory _logoHash, string memory _TOSHash)
    public isMember(msg.sender) hasPermission(DaoPermission.crowd_create) {
        //todo implement actual logic from commonshood
    }

    function unlockCrowdsale(address _crowdsaleID, address _tokenToGive, uint256 _amount)
    public isMember(msg.sender) hasPermission(DaoPermission.crowd_unlock) {
        //todo implement actual logic from commonshood
    }

    function stopCrowdsale(address _crowdsaleID)
    public isMember(msg.sender) hasPermission(DaoPermission.crowd_stop) {
        //todo implement actual logic from commonshood
    }

    function joinCrowdsale(address _crowdsaleID, uint256 _amount, string memory _symbol)
    public isMember(msg.sender) hasPermission(DaoPermission.crowd_join) {
        //todo implement actual logic from commonshood
    }

    function refundMeCrowdsale(address _crowdsaleID, uint256 _amount)
    public isMember(msg.sender) hasPermission(DaoPermission.crowd_refund) {
        //todo implement actual logic from commonshood
    }

    function makeAdminCrowdsale (address _crowdsaleID, address _address)
    public isMember(msg.sender) isMember(_address) hasPermission(DaoPermission.crowd_setadmin) {
        require(hasPermissions(DaoPermission.crowd_canmanage, _address), "target user has not enough permissions to be set as crowdsale admin");
        //tood check for crowdsale existance
        //todo implement actual logic from commonshood
        require(!users[_address].crowdsaleManagement.contains(_crowdsaleID), "target user already has permissions for the given crowdsale");
        users[_address].crowdsaleManagement.add(_crowdsaleID);
    }

    function removeAdminCrowdsale (address _crowdsaleID, address _address)
    public isMember(msg.sender) isMember(_address) hasPermission(DaoPermission.crowd_setadmin) {
        require(hasPermissions(DaoPermission.crowd_canmanage, _address), "target user has not enough permissions to be set as crowdsale admin");
        //todo check for crowdsale existance
        //todo implement actual logic from commonshood
        require(users[_address].crowdsaleManagement.contains(_crowdsaleID), "target user already has no permissions for the given crowdsale");
        users[_address].crowdsaleManagement.remove(_crowdsaleID);
    }

    function getCrowdsaleManagement (address _crowdsale, address _address) public view returns(bool) {
        //If the user has crowd_setadmin permissions, it can set admins for crowdsale, so it's inherently able to
        //manage any crowdsale, otherwise, if it has crowd_canmanage set, we check if it's been granted management
        //privileges for the specific crowdsale
        return rolePermissions[getRole(_address)].permissions.contains(uint256(DaoPermission.crowd_setadmin)) || (
        rolePermissions[getRole(_address)].permissions.contains(uint256(DaoPermission.crowd_canmanage)) &&
        users[_address].crowdsaleManagement.contains(_crowdsale)
        );
    }

    function createExchange(address[] memory _coinsOffered, address[] memory _coinsRequired, uint256[] memory _amountsOffered, uint256[] memory _amountsRequired, uint256 _repeats, uint256 _expiration)
    public isMember(msg.sender) hasPermission(DaoPermission.exchange_create) returns(address) {
        //todo implement actual logic from commonshood
        return address(0x0);
    }

    function cancelExchange(address _exchangeID)
    public isMember(msg.sender) hasPermission(DaoPermission.exchange_cancel) {
        //todo implement actual logic from commonshood
    }

    function renewExchange(address _exchangeID)
    public isMember(msg.sender) hasPermission(DaoPermission.exchange_renew) {
        //todo implement actual logic from commonshood
    }

    function acceptExchange(address _exchangeID, address[] memory _coinsRequired, uint256[] memory _amountsRequired, uint256 repeats )
    public isMember(msg.sender) hasPermission(DaoPermission.exchange_accept) {
        //todo implement actual logic from commonshood
    }

    function refillExchange(address _exchangeID, address[] memory _coinsOffered, uint256[] memory _amountsOffered, uint256 _repeats)
    public isMember(msg.sender) hasPermission(DaoPermission.exchange_refill){
        //todo implement actual logic from commonshood
    }

    function makeAdminExchange(address _exchangeID, address _address)
    public isMember(msg.sender) isMember(_address) hasPermission(DaoPermission.exchange_setadmin){
        require(hasPermissions(DaoPermission.exchange_canmanage, _address), "target user has not enough permissions to be set as exchange admin");
        //todo implement actual logic from commonshood
        require(!users[_address].exchangeManagement.contains(_exchangeID), "target user already has permissions for the given exchange");
        users[_address].exchangeManagement.add(_exchangeID);
    }

    function removeAdminExchange(address _exchangeID, address _address)
    public isMember(msg.sender) isMember(_address) hasPermission(DaoPermission.exchange_setadmin){
        require(hasPermissions(DaoPermission.exchange_canmanage, _address), "target user has not enough permissions to be set as exchange admin");
        //todo implement actual logic from commonshood
        require(users[_address].exchangeManagement.contains(_exchangeID), "target user already has not permissions for the given exchange");
        users[_address].exchangeManagement.remove(_exchangeID);
    }

    function getExchangeManagement(address _exchangeID, address _address) public view returns(bool) {
        return users[_address].exchangeManagement.contains(_exchangeID);
    }

    //Returns if the users role has a specific permission
    function hasPermissions(DaoPermission perm) public view returns (bool) {
        return rolePermissions[getMyRole()].permissions.contains(uint256(perm));
    }

    //Returns if the given user has a specific permission
    function hasPermissions(DaoPermission perm, address user) public view returns (bool){
        return rolePermissions[getRole(user)].permissions.contains(uint256(perm));
    }

    //Returns the caller's role
    function getMyRole() public view returns(bytes32){
        return users[msg.sender].role;
    }

    //Returns the provided address' role
    function getRole(address account) public view returns(bytes32){
        return users[account].role;
    }

    //Returns all the members of the given role
    function getRoleMembers(bytes32 role) public view returns(address[] memory) {
        uint256 memberCount = getRoleMemberCount(role);
        address[] memory members = new address[](memberCount);
        for (uint256 i = 0; i < memberCount; i++) {
            members[i] = getRoleMember(role, i);
        }
        return members;
    }

    //O(n) complexity, it's not advised to use it outside of views
    function getAllMembers() public view returns(address[] memory) {
        uint256 totalMembers = 0;
        for(uint256 i = 0; i < roles.length(); i++){
            totalMembers += getRoleMemberCount(roles.at(i));
        }
        address[] memory members = new address[](totalMembers);
        uint256 membersIndex = 0;
        for(uint256 i = 0; i < roles.length(); i++){
            bytes32 role = roles.at(i);
            for(uint256 j = 0; j < getRoleMemberCount(role); j++){
                members[membersIndex++] = getRoleMember(role, j);
            }
        }
        return members;
    }

    //Returns all the roles without order
    function getAllRoles() public view returns(bytes32[] memory) {
        return roles.values();
    }

    //Returns all the roles in an ordered manner (from lowest to highest)
    function getRoleHierarchy() public view returns(bytes32[] memory) {
        bytes32[] memory rolesArr = new bytes32[](roles.length());
        bytes32 role = USER_ROLE;
        uint i = 0;
        while(role != DEFAULT_ADMIN_ROLE) {
            rolesArr[i++] = role;
            role = getRoleAdmin(role);
        }
        return rolesArr;
    }

    function addRole(bytes32 newRole, bytes32 adminRole) public onlyRole(OWNER_ROLE) isLegitRole(adminRole) {
        require(!roles.contains(newRole), "already existing role");
        require(adminRole != USER_ROLE, "user role shall not have ranks below");
        require(newRole != DEFAULT_ADMIN_ROLE, "cannot add DEFAULT_ADMIN_ROLE to role hierarchy");
        bytes32 role = USER_ROLE;
        while(getRoleAdmin(role) != adminRole) {
            role = getRoleAdmin(role);
        }
        _setRoleAdmin(role, newRole);
        _setRoleAdmin(newRole, adminRole);
        roles.add(newRole);
    }

    function removeRole(bytes32 toRemove) public onlyRole(OWNER_ROLE) isLegitRole(toRemove) notDefaultRole(toRemove){
        //We remove the role from the EnumerableSet
        roles.remove(toRemove);
        //We remove the role permissions from storage
        delete rolePermissions[toRemove];
        //We iterate over each member of the role to demote them to User
        for(uint256 i = 0; i < getRoleMembers(toRemove).length; i++){
            address member = getRoleMember(toRemove, i);
            modifyRank(member, USER_ROLE);
        }
        bytes32 upperRankOfRemovedOne = getRoleAdmin(toRemove);
        //We rebuild the hierarchy, we need to find the role right below the removed one
        bytes32 role = USER_ROLE;
        while(getRoleAdmin(role) != toRemove) {
            //We got up until we have the removed one as admin
            role = getRoleAdmin(role);
        }
        _setRoleAdmin(role, upperRankOfRemovedOne);
    }

    //Gives a permission to a lower role
    function grantPermission(DaoPermission perm, bytes32 toRole) onlyRole(OWNER_ROLE)
    internal isMember(msg.sender) onlyAdmins(toRole) hasPermission(perm) isLegitRole(toRole) {
        _grantPermission(perm, toRole);
    }

    //Revokes a permission to a lower role
    function revokePermission(DaoPermission perm, bytes32 toRole) onlyRole(OWNER_ROLE)
    internal isMember(msg.sender) onlyAdmins(toRole) hasPermission(perm) isLegitRole(toRole) {
        _revokePermission(perm, toRole);
    }

    //UNSAFELY Gives permissions to a role without checks
    function _grantPermission(DaoPermission perm, bytes32 toRole) internal {
        rolePermissions[toRole].permissions.add(uint256(perm));
    }

    //UNSAFELY Revokes permissions to a role without checks
    function _revokePermission(DaoPermission perm, bytes32 toRole) internal {
        rolePermissions[toRole].permissions.remove(uint256(perm));
    }

    //Extended safe grantRole: if the role exists, it allows only hierarchically superior ranks to execute it
    function grantRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) onlyAdmins(role) isAdminOf(account) isLegitRole(role) {
        _grantRole(role, account);
    }

    //Extended safe grantRole: if the role exists, it allows only hierarchically superior ranks to execute it
    function revokeRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) onlyAdmins(role) isAdminOf(account) isLegitRole(role) {
        _revokeRole(role, account);
    }

    //Writes the new role to the role mapping, and then calls the base method
    function _grantRole(bytes32 role, address account) internal override {
        roles.add(role);
        users[account].role = role;
        super._grantRole(role, account);
    }

    //Deletes the users role mapping value, and then calls the base method, of course the user loses the previous management privileges
    function _revokeRole(bytes32 role, address account) internal override {
        delete users[account];
        super._revokeRole(role, account);
    }
}