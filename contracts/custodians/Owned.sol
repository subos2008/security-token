pragma solidity >=0.4.24 <0.5.0;

import "../open-zeppelin/SafeMath.sol";
import "../SecurityToken.sol";
import "../components/Modular.sol";
import "../components/MultiSig.sol";

/** @title Owned Custodian Contract */
contract OwnedCustodian is Modular, MultiSig {

	using SafeMath32 for uint32;
	using SafeMath for uint256;
	
	/* token contract => issuer contract */
	mapping (address => IssuingEntity) issuerMap;
	mapping (bytes32 => Investor) investors;

	struct Issuer {
		uint32 tokenCount;
		bool isOwner;
	}
	
	struct Investor {
		mapping (address => Issuer) issuers;
		mapping (address => uint256) balances;
	}

	event ReceivedTokens(
		address indexed issuer,
		address indexed token,
		bytes32 indexed investorID,
		uint256 amount
	);
	event SentTokens(
		address indexed issuer,
		address indexed token,
		address indexed recipient,
		uint256 amount
	);
	event TransferOwnership(
		address indexed token,
		bytes32 indexed from,
		bytes32 indexed to,
		uint256 value
	);

	/**
		@notice Custodian constructor
		@param _owners Array of addresses to associate with owner
		@param _threshold multisig threshold for owning authority
	 */
	constructor(
		address[] _owners,
		uint32 _threshold
	)
		MultiSig(_owners, _threshold)
		public
	{

	}

	/**
		@notice Fetch an investor's current token balance held by the custodian
		@param _token address of the SecurityToken contract
		@param _id investor ID
		@return integer
	 */
	function balanceOf(
		address _token,
		bytes32 _id
	)
		external
		view
		returns (uint256)
	{
		return investors[_id].balances[_token];
	}

	/**
		@notice Check if an investor is a beneficial owner for an issuer
		@param _issuer address of the IssuingEntity contract
		@param _id investor ID
		@return bool
	 */
	function isBeneficialOwner(
		address _issuer,
		bytes32 _id
	)
		external
		view
		returns (bool)
	{
		return investors[_id].issuers[_issuer].isOwner;
	}

	/**
		@notice View function to check if an internal transfer is possible
		@param _token Address of the token to transfer
		@param _fromID Sender investor ID
		@param _toID Recipient investor ID
		@param _value Amount of tokens to transfer
		@param _stillOwner is sender still a beneficial owner for this issuer?
		@return bool success
	 */
	function checkTransferInternal(
		SecurityToken _token,
		bytes32 _fromID,
		bytes32 _toID,
		uint256 _value,
		bool _stillOwner
	)
		external
		view
		returns (bool)
	{
		Investor storage from = investors[_fromID];
		require(from.balances[_token] >= _value, "Insufficient balance");
		if (
			!_stillOwner &&
			from.balances[_token] == _value &&
			from.issuers[issuerMap[_token]].tokenCount == 1
		) {
			bool _owner;
		} else {
			_owner = true;
		}
		require (_token.checkTransferCustodian([_fromID, _toID], _owner));
		return true;
	}

	/**
		@notice Transfers tokens out of the custodian contract
		@dev callable by custodian authorities and modules
		@param _token Address of the token to transfer
		@param _to Address of the recipient
		@param _value Amount to transfer
		@param _stillOwner is recipient still a beneficial owner for this issuer?
		@return bool success
	 */
	function transfer(
		SecurityToken _token,
		address _to,
		uint256 _value,
		bool _stillOwner
	)
		external
		returns (bool)
	{
		if (
			/* msg.sig = 0x75219e4e */
			!isPermittedModule(msg.sender, msg.sig) &&
			!_checkMultiSig()
		) {
			return false;
		}
		bytes32 _id = issuerMap[_token].getID(_to);
		Investor storage i = investors[_id];
		i.balances[_token] = i.balances[_token].sub(_value);
		require(_token.transfer(_to, _value));
		if (i.balances[_token] == 0) {
			Issuer storage issuer = i.issuers[issuerMap[_token]];
			issuer.tokenCount = issuer.tokenCount.sub(1);
			if (issuer.tokenCount == 0 && !_stillOwner) {
				issuer.isOwner = false;
				issuerMap[_token].releaseOwnership(ownerID, _id);
			}
		}
		/* bytes4 signature for custodian module sentTokens() */
		_callModules(0x31b45d35, abi.encode(
			_token,
			_id,
			_value,
			issuer.isOwner
		));
		emit SentTokens(issuerMap[_token], _token, _to, _value);
		return true;
	}

	/**
		@notice Add a new token owner
		@dev called by IssuingEntity when tokens are transferred to a custodian
		@param _token Token address
		@param _id Investor ID
		@param _value Amount transferred
		@return bool success
	 */
	function receiveTransfer(
		address _token,
		bytes32 _id,
		uint256 _value
	)
		external
		returns (bool)
	{
		if (issuerMap[_token] == address(0)) {
			require(SecurityToken(_token).issuer() == msg.sender);
			issuerMap[_token] = IssuingEntity(msg.sender);
		} else {
			require(issuerMap[_token] == msg.sender);
		}
		emit ReceivedTokens(msg.sender, _token, _id, _value);
		Investor storage i = investors[_id];
		if (i.balances[_token] == 0) {
			Issuer storage issuer = i.issuers[msg.sender];
			issuer.tokenCount = issuer.tokenCount.add(1);
			if (!issuer.isOwner) {
				issuer.isOwner = true;
			}
		}
		i.balances[_token] = i.balances[_token].add(_value);
		/* bytes4 signature for custodian module receivedTokens() */
		_callModules(0xa0e7f751, abi.encode(_token, _id, _value));
		return true;
	}

	/**
		@notice Transfer token ownership within the custodian
		@dev Callable by custodian authorities and modules
		@param _token Address of the token to transfer
		@param _fromID Sender investor ID
		@param _toID Recipient investor ID
		@param _value Amount of tokens to transfer
		@param _stillOwner is sender still a beneficial owner for this issuer?
		@return bool success
	 */
	function transferInternal(
		SecurityToken _token,
		bytes32 _fromID,
		bytes32 _toID,
		uint256 _value,
		bool _stillOwner
	)
		external
		returns (bool)
	{
		if (
			/* msg.sig = 0x2965c868 */
			!isPermittedModule(msg.sender, msg.sig) &&
			!_checkMultiSig()
		) {
			return false;
		}
		Investor storage from = investors[_fromID];
		require(from.balances[_token] >= _value, "Insufficient balance");
		Investor storage to = investors[_toID];
		from.balances[_token] = from.balances[_token].sub(_value);
		to.balances[_token] = to.balances[_token].add(_value);
		if (to.balances[_token] == _value) {
			Issuer storage issuer = to.issuers[issuerMap[_token]];
			issuer.tokenCount = issuer.tokenCount.add(1);
			if (!issuer.isOwner) {
				issuer.isOwner = true;
			}
		}
		issuer = from.issuers[issuerMap[_token]];
		if (from.balances[_token] == 0) {
			issuer.tokenCount = issuer.tokenCount.sub(1);
			if (issuer.tokenCount == 0 && !_stillOwner) {
				issuer.isOwner = false;
			}
		}
		require(_token.transferCustodian(
			[_fromID, _toID],
			_value,
			issuer.isOwner
		));
		/* bytes4 signature for custodian module internalTransfer() */
		_callModules(
			0x7054b724,
			abi.encode(_token, _fromID, _toID, _value, _stillOwner)
		);
		emit TransferOwnership(_token, _fromID, _toID, _value);
		return true;
	}

	/**
		@notice Release beneficial ownership of an investor
		@dev
			Even when an investor's balance reaches 0, their beneficial owner
			status may be preserved with _stillOwner. This function can be 
			called later to revoke that status.
		@dev Callable by custodian authorities and modules
		@param _issuer Address of IssuingEntity
		@param _id investor ID
		@return bool success
	 */
	function releaseOwnership(
		address _issuer,
		bytes32 _id
	)
		external
		returns (bool)
	{
		if (
			/* msg.sig = 0xc07f6f8e */
			!isPermittedModule(msg.sender, msg.sig) &&
			!_checkMultiSig()
		) {
			return false;
		}
		Issuer storage i = investors[_id].issuers[_issuer];
		if (i.tokenCount == 0 && i.isOwner) {
			i.isOwner = false;
			IssuingEntity(_issuer).releaseOwnership(ownerID, _id);
			/* bytes4 signature of custodian module ownershipReleased() */
			_callModules(0x054d1c76, abi.encode(_issuer, _id));
		}
	}

	/**
		@notice Attach a module
		@dev
			Modules have a lot of permission and flexibility in what they
			can do. Only attach a module that has been properly auditted and
			where you understand exactly what it is doing.
			https://sft-protocol.readthedocs.io/en/latest/modules.html
		@param _module Address of the module contract
		@return bool success
	 */
	function attachModule(
		address _module
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		_attachModule(_module);
		return true;
	}

	/**
		@notice Detach a module
		@dev This function may also be called by the module itself.
		@param _module Address of the module contract
		@return bool success
	 */
	function detachModule(
		address _module
	)
		external
		returns (bool)
	{
		if (_module != msg.sender) {
			if (!_checkMultiSig()) return false;
		} else {
			/* msg.sig = 0xbb2a8522 */
			require(isPermittedModule(msg.sender, msg.sig));
		}
		_detachModule(_module);
		return true;
	}

}
