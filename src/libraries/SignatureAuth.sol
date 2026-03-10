//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SignatureAuth {
    bytes32 public constant APPROVAL_TYPEHASH = keccak256(
        "Approval(bytes32 proposalId,address signer,uint nonce,uint deadline)"
    );


    function getDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint chainId,address verifyingContract)"),
            keccak256("ARES Protocol"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    function getStructHash(
        bytes32 _proposalId,
        address _signer,
        uint _nonce,
        uint _deadline
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            APPROVAL_TYPEHASH,
            _proposalId,
            _signer,
            _nonce,
            _deadline
        ));
    }

    function getDigest(
        bytes32 _proposalId,
        address _signer,
        uint _nonce,
        uint _deadline
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            getDomainSeparator(),
            getStructHash(_proposalId, _signer, _nonce, _deadline)
        ));
    }

    function recoverSigner(
        bytes32 _proposalId,
        address _expectedSigner,
        uint _nonce,
        uint _deadline,
        bytes memory _signature
    ) internal view returns (address) {
        require(_signature.length == 65, "invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }


        require(
            uint(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "invalid s value"
        );

        require(v == 27 || v == 28, "invalid v value");

        bytes32 digest_ = getDigest(_proposalId, _expectedSigner, _nonce, _deadline);

        address recovered_ = ecrecover(digest_, v, r, s);
        require(recovered_ != address(0), "invalid signature");

        return recovered_;
    }

    function verifyThreshold(
        bytes32 _proposalId,
        address[] calldata _signers,
        bytes[] calldata _signatures,
        uint[] calldata _signerNonces,
        uint _deadline,
        uint _threshold
    ) internal view returns (bool) {
        require(block.timestamp <= _deadline, "signatures expired");
        require(_signers.length == _signatures.length, "length mismatch");

        uint validCount_ = 0;

        for (uint i = 0; i < _signers.length; i++) {
            address recovered_ = recoverSigner(
                _proposalId,
                _signers[i],
                _signerNonces[i],
                _deadline,
                _signatures[i]
            );

            if (recovered_ == _signers[i]) {
                validCount_++;
            }
        }

        return validCount_ >= _threshold;
    }
}