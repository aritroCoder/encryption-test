// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract PasswordManager{
    struct Credential{
        string website;
        string username;
        string password;
    }
    struct Signature{
        bytes32 merkleRoot;
        bytes signature;
    }
    mapping(address=>Credential[]) passwords;
    mapping(address=>Signature) signs;

    function addCredentials(string memory _website, string memory _username, string memory _password, bytes memory _signature) external {
        // recalculate merkle root => send merkleroot back => recieve signature => verify and add signature
        passwords[msg.sender].push(Credential({website: _website, username: _username, password: _password}));
        bytes32 merkleRoot = getMerkleRoot(passwords[msg.sender]);
        VerifySignature v = new VerifySignature();
        if(v.verify(msg.sender, merkleRoot, _signature)){
            signs[msg.sender] = Signature({merkleRoot: merkleRoot, signature: _signature});
        }else{
            revert("Invalid signature!");
        }
    }

    function getAllCredentials() external returns (Credential[] memory){
        VerifySignature v = new VerifySignature();
        if(v.verify(msg.sender, signs[msg.sender].merkleRoot, signs[msg.sender].signature)){
            return passwords[msg.sender]; 
        }else{
            revert("Signature verification failed");
        }
    }

    function getCredential(string memory _website) external returns (Credential memory){
        VerifySignature v = new VerifySignature();
        if(v.verify(msg.sender, signs[msg.sender].merkleRoot, signs[msg.sender].signature)){
            for(uint i=0; i<passwords[msg.sender].length; i++){
                if(keccak256(abi.encodePacked(passwords[msg.sender][i].website))==keccak256(abi.encodePacked(_website))){ // simple string comparison operation
                    return passwords[msg.sender][i];
                }
            }
            revert("Credential not found for the website");
        }else{
            revert("Signature Verification failed");
        }
    }


    // below are functionality related to merkle tree
    bytes32[] hashes;
    function getMerkleRoot(Credential[] memory transactions) internal returns(bytes32){
        // proper merkle tree will only form if count is a power of 2
        uint number_of_hashes = nearestPowerOfTwo(transactions.length);

        uint pos = 0;
        for(uint i = 0; i < number_of_hashes; i++) {
            hashes.push(makeHash(string.concat(transactions[pos].website, transactions[pos].username, transactions[pos].password)));
            if(pos<transactions.length-1) pos++;
        }

        uint count = number_of_hashes;  // number of leaves
        uint offset = 0;

        while(count > 0) {
            for(uint i = 0; i < count - 1; i += 2) {
                hashes.push(keccak256(
                    abi.encodePacked(
                        hashes[offset + i], hashes[offset + i + 1]
                    )
                ));
            }
            offset += count;
            count = count / 2;
        }
        return hashes[hashes.length-1];
    }

    function nearestPowerOfTwo(uint n) internal pure returns(uint){
        uint cp = n;
        uint pow2 = 1;
        if(n==0) { return pow2; }
        while(n != 1){
            pow2*=2;
            n = n/2;
        }
        if(pow2==cp){
            return pow2;
        }else{
            return pow2*2;
        }
    }

    function makeHash(string memory input) public pure returns(bytes32) {
        return keccak256(
            abi.encodePacked(input)
        );
    }
}

contract VerifySignature {
    // Only function needed to call from outside
    function verify(
        address _signer,
        bytes32 _message,
        bytes memory signature
    ) external pure returns (bool) {
        bytes32 messageHash = getMessageHash(_message);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    // internal functions for implementation
    function getMessageHash(bytes32 _message) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_message));
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) internal pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
