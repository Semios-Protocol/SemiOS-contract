// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

//this file only for local test

contract Parent is Test {
    uint256 a;

    function reqestOnchain() internal {
        a = 1;
        console2.log("sender in parent: ", msg.sender);
    }
}

contract Child is Parent {
    function setUp() public { }

    function test_request_onchain() public {
        console2.log("sender in child: ", msg.sender);
        console2.log("this:", address(this));
        reqestOnchain();
    }
}

contract TestCall2 {
    uint256 i;

    constructor() {
        i = 1;
    }

    function test_call2() public {
        i++;
        console2.log(i, ": sender in test_call2: ", msg.sender);
    }

    //function test_main() public { }
}

contract TestCall is Test {
    uint256 i;

    constructor() {
        i = 1;
    }

    function test_call() public {
        i++;
        console2.log(i, ": sender in test_call: ", msg.sender);
    }

    function test_main() public {
        console2.log("caller: ", msg.sender);
        console2.log("address this: ", address(this));
        i = 2;
        uint256 g = gasleft();
        test_call();
        console2.log(i, ": gas consume: ", g - gasleft());
        g = gasleft();
        TestCall(address(this)).test_call();
        console2.log(i, ": gas consume: ", g - gasleft());
        TestCall2 tc = new TestCall2();
        g = gasleft();
        tc.test_call2();
        console2.log(i, ": gas consume call other contract: ", g - gasleft());
    }
}

contract TestTest is Test {
    Account signer = makeAccount("Signer");
    uint256 public counter;
    bytes public datas;

    struct Foo1 {
        uint256 a1;
        uint256 b1;
    }

    struct Foo {
        uint256 a;
        uint256 b;
        Foo1 c;
    }

    struct Foo2 {
        Foo1[] foo1s;
    }

    uint256[][] arr2;

    mapping(uint256 => Foo) foos;
    Foo foo;
    Foo foo1;
    Foo foo2;
    Foo1[] foo1array;
    uint256[] uintarray;
    Foo2 foo2arrayinstruct;

    event LogTopic1(uint256 indexed a1, uint256 indexed a2, uint256 indexed a3);
    event LogTopic2(uint256 b1, uint256 b2, uint256 b3);

    function setUp() public { }

    function test_recordLogs() public {
        vm.recordLogs();
        emit LogTopic1(1, 2, 3);
        emit LogTopic2(4, 5, 6);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(keccak256("LogTopic1(uint256,uint256,uint256)"));
        console2.logBytes32(entries[0].topics[0]);
        console2.log(entries[0].topics.length);
        console2.logBytes32(entries[0].topics[1]);
        console2.logBytes32(entries[0].topics[2]);
        console2.logBytes32(entries[0].topics[3]);
        console2.logBytes(entries[0].data);

        console2.logBytes32(keccak256("LogTopic2(uint256,uint256,uint256)"));
        console2.logBytes32(entries[1].topics[0]);
        console2.log(entries[1].topics.length);
        console2.logBytes(entries[1].data);
        (uint256 a, uint256 b, uint256 c) = abi.decode(entries[1].data, (uint256, uint256, uint256));
        console2.log(a);
        console2.log(b);
        console2.log(c);
    }

    function test_struct_array_assignment() public {
        Foo1[] memory foom = new Foo1[](2);
        foom[0] = Foo1(1, 2);
        foom[1] = Foo1(3, 4);
        Foo1[] memory foom1;

        //foo1array = foom;
        foom1 = foom;
        console2.log(foom1[0].a1);
        console2.log(foom1[1].a1);

        Foo2 memory foo2m;
        foo2m.foo1s = foom;
        console2.log("foom:");
        console2.log(foom[0].a1);
        console2.log(foom[0].b1);
        console2.log(foom[1].a1);
        console2.log(foom[1].b1);
        console2.log("foo2m.foo1s:");
        console2.log(foo2m.foo1s[0].a1);
        console2.log(foo2m.foo1s[0].b1);
        console2.log(foo2m.foo1s[1].a1);
        console2.log(foo2m.foo1s[1].b1);

        foo2arrayinstruct.foo1s.push(Foo1(0, 0));
        foo2arrayinstruct.foo1s.push(Foo1(0, 0));

        Foo2 memory f2ai;
        f2ai = foo2m;

        //foo2arrayinstruct = foo2m;

        // console2.log(foo2arrayinstruct.foo1s[0].a1);
        // console2.log(foo2arrayinstruct.foo1s[0].b1);
        // console2.log(foo2arrayinstruct.foo1s[1].a1);
        // console2.log(foo2arrayinstruct.foo1s[1].b1);
        console2.log(f2ai.foo1s[0].a1);
    }

    function test_array_assignment() public {
        uint256[] memory temp = new uint256[](4);
        temp[0] = 1;
        temp[1] = 2;
        temp[2] = 3;
        temp[3] = 4;

        uintarray = temp;
        console2.log("length:", uintarray.length);
        console2.log(uintarray[0]);
        console2.log(uintarray[1]);
        console2.log(uintarray[2]);
        console2.log(uintarray[3]);

        uint256[] memory temp1 = new uint256[](2);
        temp1[0] = 5;
        temp1[1] = 6;
        uintarray = temp1;
        console2.log("length:", uintarray.length);
        console2.log(uintarray[0]);
        console2.log(uintarray[1]);
        // vm.expectRevert();
        // console2.log(uintarray[2]);

        uint256[] memory temp2 = new uint256[](5);
        temp2[0] = 7;
        temp2[1] = 8;
        temp2[2] = 9;
        temp2[3] = 10;
        temp2[4] = 11;
        uintarray = temp2;

        console2.log("length:", uintarray.length);
        console2.log(uintarray[0]);
        console2.log(uintarray[1]);
        console2.log(uintarray[2]);
        console2.log(uintarray[3]);
        console2.log(uintarray[4]);

        delete uintarray;
        console2.log("length:", uintarray.length);

        Foo1[] memory foo1temp = new Foo1[](2);
        foo1temp[0] = Foo1(1, 2);
        foo1temp[1] = Foo1(3, 4);
        Foo1[] memory foo2temp;
        foo2temp = foo1temp;
        console2.log("fooarray");
        console2.log(foo2temp[0].a1);
        console2.log(foo2temp[0].b1);
    }

    function test_gas() public {
        console2.log(msg.sender);
        console2.log(address(this));
        datas =
            "0x123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789001234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890";
        console2.logBytes(datas);
        datas = hex"012345";
        console2.logBytes(datas);
    }

    function test_struct_assignment() public {
        foo = Foo(1, 2, Foo1(3, 4));
        console2.log(foo.a);
        console2.log(foo.b);
        console2.log(foo.c.a1);
        console2.log(foo.c.b1);
        Foo memory foo11 = Foo(5, 6, Foo1(7, 8));
        foo1 = foo11;
        console2.log("foo1:");
        console2.log(foo1.a);
        console2.log(foo1.b);
        console2.log(foo1.c.a1);
        console2.log(foo1.c.b1);
        console2.log("foo2:");
        foo2 = foo1;
        console2.log(foo2.a);
        console2.log(foo2.b);
        console2.log(foo2.c.a1);
        console2.log(foo2.c.b1);
        foo1.a = 9;
        console2.log(foo2.a);
        foo2.b = 10;
        console2.log(foo1.b);
    }

    function test_storage_value() public {
        Foo storage fooa = foos[1];
        fooa.a = 3;
        fooa.b = 4;
        fooa = foos[2];
        console2.log(fooa.a); //0
        console2.log(fooa.b); //0
        console2.log(foos[1].a); //3
        console2.log(foos[1].b); //4

        Foo storage fooc = foos[3];
        fooc = foos[1];

        console2.log(fooc.a); // 3
        console2.log(fooc.b); // 4
        console2.log(foos[3].a); //0
        console2.log(foos[3].b); //0
        fooc.a = 5;
        console2.log(foos[3].a); //0
        console2.log(foos[1].a); //5

        Foo memory food = foos[1];
        console2.log(food.a); // 5
        console2.log(food.b); // 4
        food.a = 8;
        console2.log(food.a); //8
        console2.log(foos[1].a); // 5
        food = foos[2];
        console2.log(food.a); // 0
        console2.log(food.b); // 0
        console2.log(foos[1].a); //5
        console2.log(foos[1].b); //4
    }

    function test_sign() public {
        console2.log(signer.addr);
        console2.logBytes32(keccak256("1")); //0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6
        console2.logBytes32(keccak256(abi.encode("1"))); //0xc586dcbfc973643dc5f885bf1a38e054d2675b03fe283a5b7337d70dda9f7171
        console2.logBytes32(keccak256(abi.encode(1))); //0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6
        console2.logBytes32(keccak256(abi.encodePacked(uint256(1)))); //0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6
        console2.logBytes32(keccak256(abi.encodePacked(uint8(1)))); //0x5fe7f977e71dba2ea1a68e21057beebb9be2ac30c6410aa38d4f3fbe41dcffd2
        console2.logBytes32(keccak256(abi.encode(uint256(1)))); //0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6
        console2.logBytes32(keccak256(abi.encode(uint8(1)))); //0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6
        console2.log(uint256(1));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer.key, keccak256("1"));
    }

    function test_recover() public {
        ++counter;
        address signer_ = ecrecover(
            0x39de7b89f4d7128167508050d499d2f2effda54d945ea0af2d5e7c0b34db6d9c,
            uint8(28),
            bytes32(uint256(1)),
            bytes32(uint256(2))
        );
        if (signer_ == address(0)) {
            console2.log(counter);
            //revert();
        }
        console2.log(signer_);
    }
}
