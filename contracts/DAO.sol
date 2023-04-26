//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract DAO is AccessControl {
    //External project requirement, it states "dao" to distinguish the DAO from standard user
    string public realm;
    //Address of the owner
    address public owner;

    //DAO's name, its uniqueness shall be managed by a Factory contract
    string public name;
    //External project requirement, it states the ID of a place inside a map. Each DAO has to be linked to a given place
    string public firstlifePlaceID;

    //External proejct requirement, DAO's description
    string public description_cid;
    //Specifies whether you can join this DAO freely or under invitation
    bool public isInviteOnly = false;



    //Rank system
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE"); 
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    mapping(address => bytes32) usersRole;
    mapping(address => bytes32) invites;
    mapping(address => bytes32) promotions;
    mapping(bytes32 => mapping(DaoPermission => bool)) rolePermissions;
    mapping(string => mapping(address => bool)) tokenAuthorization;

    enum DaoPermission {
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
        token_auth
    }

    //Modifier that allows to execute the code only if the caller IS a member
    modifier isMember(address addr) {
        require(usersRole[addr] != 0x00, "you're required to be a member");
        _;
    }

    //Modifier that allows to execute the code only if the caller IS NOT a member
    modifier isNotMember(address addr) {
        require(usersRole[addr] == 0x00, "you're required to not be a member");
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
        require(isAdminOfRole(msg.sender, usersRole[ofAddress]), "you're required to be of higher rank");
        _;
    }

    //Modifier that extends the behaviour achievable with onlyRole(getRoleAdmin(role)) to hierarchically superior ranks 
    modifier onlyAdmins(bytes32 role) {
        require(isAdminOfRole(msg.sender, role), "only higher ranks of the given role are allowed");
        _;
    }

    modifier hasPermission(DaoPermission permission) {
        require(rolePermissions[usersRole[msg.sender]][permission], "not enough permissions");
        _;
    }

    modifier canManageToken(string memory tokenSymbol) {
        require(getTokenAuth(tokenSymbol, msg.sender), "not authorized to manage token");
        //require(hasPermissions(DaoPermission.token_all) || (hasPermissions(DaoPermission.token_specific) &&
        //tokenAuthorization[tokenSymbol][msg.sender]), "not authorized to manage token");
        _;
    }

    event UserJoined(address indexed user, bytes32 asRole);
    event UserInvited(address indexed by, address user);
    event UserDeranked(address indexed by, address user, bytes32 toRole);
    event UserPromotionProposed(address indexed by, address user, bytes32 toRole);
    event UserPromoted(address indexed user, bytes32 toRole);
    event UserKicked(address indexed by, address user);

    constructor(

    ){
        realm = "dao";
        owner = msg.sender;
        name = "Test_DAO";
        firstlifePlaceID = "paoloBorsellinoFID";
        description_cid = "La best residenza da quittare asap";
        isInviteOnly = false;
        _grantRole(OWNER_ROLE, msg.sender);
        //We setup the role hierarchy in terms of admin role:
        //OWNER -> ADMIN -> SUPERVISOR -> USER
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(SUPERVISOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(USER_ROLE, SUPERVISOR_ROLE);
        //We setup the role permissions
        _grantPermission(DaoPermission.token_all, OWNER_ROLE);
        _grantPermission(DaoPermission.token_transfer, OWNER_ROLE);
        _grantPermission(DaoPermission.token_specific, OWNER_ROLE);
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
        return isAdminOfRole(usersRole[isAdmin], ofRole);
    }

    //Joins the DAO
    function join() public isNotMember(msg.sender) {
        require(!isInviteOnly, "can't freely join invite-only dao");
        delete invites[msg.sender];
        _grantRole(USER_ROLE, msg.sender);
        emit UserJoined(msg.sender, USER_ROLE);
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
        emit UserJoined(msg.sender, usersRole[msg.sender]);
    }

    //Declines an invite to the DAO
    function declineInvite() public hasInvite{
        //We delete the invite since it's been declined
        invites[msg.sender] = 0;
    }

    //Offers a promotion if the new role is higher than the current one, otherwise it deranks instantly, if we have enough permissions
    function modifyRank(address toModify, bytes32 newRole) public isMember(toModify) isAdminOf(toModify) onlyAdmins(newRole) {
        bool isPromotion = isAdminOfRole(newRole, usersRole[toModify]);
        //If there's a pending promotion, we delete it whether it's a promotion or not
        delete promotions[toModify];
        //If it's a promotion, there is a 2Phase (offer && accept/refuse)
        if(isPromotion){
            promotions[toModify] = newRole;
            emit UserPromotionProposed(msg.sender, toModify, newRole);
            return;
        }
        //If it's not a promotion, we just revoke the role and emit the event
        _revokeRole(usersRole[toModify], toModify);
        _grantRole(newRole, toModify);
        emit UserDeranked(msg.sender, toModify, newRole);
    }

    function acceptPromotion() public isMember(msg.sender) hasPromotion {
        _revokeRole(usersRole[msg.sender], msg.sender);
        _grantRole(promotions[msg.sender], msg.sender);
        delete promotions[msg.sender];
        emit UserPromoted(msg.sender, usersRole[msg.sender]);
    }

    function refusePromotion() public isMember(msg.sender) hasPromotion {
        delete promotions[msg.sender];
    }

    //Kicks a member if we have enough permissions
    function kickMember(address toKick) public isMember(toKick) isAdminOf(toKick) {
        //We clear out possible promotions before kicking the member
        delete promotions[toKick];
        _revokeRole(usersRole[toKick], toKick);
        emit UserKicked(msg.sender, toKick);
    }

    function transferToken(string memory symbol, uint256 amount, address to)
    public isMember(msg.sender) hasPermission(DaoPermission.token_transfer) canManageToken(symbol){
        //todo when user is kicked or permission changed between roles, reset the specific auths
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
    public isMember(msg.sender) canManageToken(symbol) hasPermission(DaoPermission.token_auth) {
        require(tokenAuthorization[symbol][_address] == false,"Address already authorized for this Token");
        tokenAuthorization[symbol][_address] = true;
    }

    function getTokenAuth(string memory tokenSymbol, address _address) public view returns (bool){
        return rolePermissions[getRole(_address)][DaoPermission.token_all] ||
        (rolePermissions[getRole(_address)][DaoPermission.token_specific] &&
        tokenAuthorization[tokenSymbol][_address]);
    }

    //Returns if the users role has a specific permission
    function hasPermissions(DaoPermission perm) public view returns (bool) {
        return rolePermissions[getMyRole()][perm];
    }

    //Returns the caller's role
    function getMyRole() public view returns(bytes32){
        return usersRole[msg.sender];
    }

    //Returns the provided address' role
    function getRole(address account) public view returns(bytes32){
        return usersRole[account];
    }

    //Gives a permission to a lower role
    function grantPermission(DaoPermission perm, bytes32 toRole)
    internal isMember(msg.sender) onlyAdmins(toRole) hasPermission(perm) {
        _grantPermission(perm, toRole);
    }

    //Revokes a permission to a lower role
    function revokePermission(DaoPermission perm, bytes32 toRole)
    internal isMember(msg.sender) onlyAdmins(toRole) hasPermission(perm) {
        _revokePermission(perm, toRole);
    }

    //UNSAFELY Gives permissions to a role without checks
    function _grantPermission(DaoPermission perm, bytes32 toRole) internal {
        rolePermissions[toRole][perm] = true;
    }

    //UNSAFELY Revokes permissions to a role without checks
    function _revokePermission(DaoPermission perm, bytes32 toRole) internal {
        rolePermissions[toRole][perm] = false;
    }

    //Extended safe grantRole: allows only hierarchically superior ranks to execute it
    function grantRole(bytes32 role, address account) public virtual override onlyAdmins(role) isAdminOf(account) {
        _grantRole(role, account);
    }

    //Extended safe grantRole: allows only hierarchically superior ranks to execute it
    function revokeRole(bytes32 role, address account) public virtual override onlyAdmins(role) isAdminOf(account) {
        _revokeRole(role, account);
    }

    //Writes the new role to the role mapping, and then calls the base method
    function _grantRole(bytes32 role, address account) internal override {
        usersRole[account] = role;
        super._grantRole(role, account);
    }

    //Deletes the users role mapping value, and then calls the base method
    function _revokeRole(bytes32 role, address account) internal override {
        delete usersRole[account];
        super._revokeRole(role, account);
    }
}