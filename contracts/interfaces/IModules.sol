pragma solidity >=0.4.24 <0.5.0;

interface IBaseModule {
	function getPermissions()
		external
		pure
		returns
	(
		bytes4[] hooks,
		bytes4[] permissions
	);
	function getOwner() external view returns (address);
	function name() external view returns (string);
}

interface ISTModule {
	function getPermissions()
		external
		pure
		returns
	(
		bytes4[] hooks,
		bytes4[] permissions
	);
	function getOwner() external view returns (address);
	function token() external returns (address);
	function name() external view returns (string);
	
	/* 0x70aaf928 */
	function checkTransfer(
		address[2] _addr,
		bytes32 _authID,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		view
		returns (bool);

	/* 0x35a341da */
	function transferTokens(
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		returns (bool);

	/* 0x6eaf832c */
	function transferTokensCustodian(
		address _custodian,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		returns (bool);
	
	/* 0x4268353d */
	function balanceChanged(
		address _addr,
		bytes32 _id,
		uint8 _rating,
		uint16 _country,
		uint256 _old,
		uint256 _new
	)
		external
		returns (bool);
}

interface IIssuerModule {
	function getPermissions()
		external
		pure
		returns
	(
		bytes4[] hooks,
		bytes4[] permissions
	);
	function getOwner() external view returns (address);
	function name() external view returns (string);

	/* 0x47fca5df */
	function checkTransfer(
		address _token,
		bytes32 _authID,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		view
		returns (bool);

	/* 0x0cfb54c9 */
	function transferTokens(
		address _token,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		returns (bool);
	
	/* 0x3b59c439 */
	function transferTokensCustodian(
		address _token,
		address _custodian,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		returns (bool);

	/* 0x4268353d */
	function balanceChanged(
		address _token,
		bytes32 _id,
		uint8 _rating,
		uint16 _country,
		uint256 _old,
		uint256 _new
	)
		external
		returns (bool);
}

interface ICustodianModule {
	function getPermissions()
		external
		pure
		returns
	(
		bytes4[] hooks,
		bytes4[] permissions
	);
	function getOwner() external view returns (address);
	function name() external view returns (string);

	/**
		@notice Custodian sent tokens
		@dev
			Called after a successful token transfer from the custodian.
			Use 0x31b45d35 as the hook value for this method.
		@param _token Token address
		@param _id Recipient ID
		@param _value Amount of tokens transfered
		@param _stillOwner Is recipient still a beneficial owner for this token?
		@return bool success
	 */
	function sentTokens(
		address _token,
		bytes32 _id,
		uint256 _value,
		bool _stillOwner
	)
		external
		returns (bool);

	/**
		@notice Custodian received tokens
		@dev
			Called after a successful token transfer to the custodian.
			Use 0xa0e7f751 as the hook value for this method.
		@param _token Token address
		@param _id Recipient ID
		@param _value Amount of tokens transfered
		@return bool success
	 */
	function receivedTokens(
		address _token,
		bytes32 _id,
		uint256 _value
	)
		external
		returns (bool);

	/* 0x7054b724 */
	function internalTransfer(
		address _token,
		bytes32 _fromID,
		bytes32 _toID,
		uint256 _value,
		bool _stillOwner
	)
		external
		returns (bool);

	/* 0x054d1c76 */
	function ownershipReleased(
		address _issuer,
		bytes32 _id
	)
		external
		returns (bool);
}