import {expect} from "chai";
import {deployments, ethers} from "hardhat";
import {Signer} from "ethers";
import {deployMockContract, MockContract} from "@ethereum-waffle/mock-contract";

import {PriceOracle} from "../src/types/PriceOracle";
import {PriceOracle__factory} from "../src/types/factories/PriceOracle__factory";
import {Erc20} from "../src/types/ERC20";
import {Erc20__factory} from "../src/types/factories/Erc20__factory";

import {CoreBTCLogic} from "../src/types/CoreBTCLogic";
import {CoreBTCLogic__factory} from "../src/types/factories/CoreBTCLogic__factory";
import {CoreBTCProxy__factory} from "../src/types/factories/CoreBTCProxy__factory";

import {takeSnapshot, revertProvider} from "./block_utils";


describe("PriceOracle", async () => {

    // Constants
    let ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
    let ONE_ADDRESS = "0x0000000000000000000000000000000000000001";
    let TWO_ADDRESS = "0x0000000000000000000000000000000000000001";

    // Accounts
    let deployer: Signer;
    let signer1: Signer;
    let deployerAddress: string;
    let signer1Address: string;

    // Contracts
    let priceOracle: PriceOracle;
    let erc20: Erc20;
    let _erc20: Erc20;
    let coreBTC: CoreBTCLogic;

    // Mock contracts
    let mockPriceProxy: MockContract;
    let _mockPriceProxy: MockContract;
    let mockSwitchBoardPush: MockContract;

    // Values
    let acceptableDelay: number;

    let snapshotId: any;

    before(async () => {
        // Sets accounts
        [deployer, signer1] = await ethers.getSigners();
        deployerAddress = await deployer.getAddress();
        signer1Address = await signer1.getAddress();

        // Deploys erc20 contracts
        const erc20Factory = new Erc20__factory(deployer);
        erc20 = await erc20Factory.deploy(
            "TestToken",
            "TT",
            1000
        );
        _erc20 = await erc20Factory.deploy(
            "AnotherTestToken",
            "ATT",
            1000
        );

        // Deploys collateralPool contract
        acceptableDelay = 120; // seconds
        const PriceOracleFactory = new PriceOracle__factory(deployer);
        priceOracle = await PriceOracleFactory.deploy(acceptableDelay)
        coreBTC = await deployCoreBTC();
        const IPriceProxy = await deployments.getArtifact(
            "IPriceProxy"
        );
        mockPriceProxy = await deployMockContract(
            deployer,
            IPriceProxy.abi
        );
        const ISwitchboardPush = await deployments.getArtifact(
            "ISwitchboardPush"
        );

        mockSwitchBoardPush = await deployMockContract(
            deployer,
            ISwitchboardPush.abi
        );

        await priceOracle.addTokenPricePair(erc20.address, 'TT/USDT');
        await priceOracle.addTokenPricePair(_erc20.address, 'ATT/USDT');
        await priceOracle.addTokenPricePair(coreBTC.address, 'BTC/USDT');
        await priceOracle.addPriceProxy(mockSwitchBoardPush.address)
        await priceOracle.addPriceProxy(mockPriceProxy.address)
        await priceOracle.selectBestPriceProxy(mockSwitchBoardPush.address)
        await priceOracle.selectBestPriceProxy(mockPriceProxy.address)

    });
    const deployCoreBTC = async (
        _signer?: Signer
    ): Promise<CoreBTCLogic> => {
        const coreBTCLogicFactory = new CoreBTCLogic__factory(deployer);
        const coreBTCLogicImpl = await coreBTCLogicFactory.deploy();
        const methodSig = ethers.utils.id(
            "initialize(string,string)"
        );
        const tokenName = "coreBTC";
        const tokenSymbol = "CBTC";
        const params = ethers.utils.defaultAbiCoder.encode(
            ['string', 'string'],
            [tokenName, tokenSymbol]
        );
        const initCode = ethers.utils.solidityPack(
            ['bytes', 'bytes'],
            [methodSig.slice(0, 10), params]
        );
        const coreBTCProxyFactory = new CoreBTCProxy__factory(deployer);
        const coreBTCProxy = await coreBTCProxyFactory.deploy(
            coreBTCLogicImpl.address,
            initCode
        );
        coreBTC = await coreBTCLogicFactory.attach(
            coreBTCProxy.address
        )
        return coreBTC;
    };

    async function setNextBlockTimestamp(
        addedTimestamp: number,
    ): Promise<void> {
        let lastBlockNumber = await ethers.provider.getBlockNumber();
        let lastBlock = await ethers.provider.getBlock(lastBlockNumber);
        let lastBlockTimestamp = lastBlock.timestamp;
        await ethers.provider.send("evm_setNextBlockTimestamp", [lastBlockTimestamp + addedTimestamp])
        await ethers.provider.send("evm_mine", []);
    }

    async function getLastBlockTimestamp(): Promise<number> {
        let lastBlockNumber = await ethers.provider.getBlockNumber();
        let lastBlock = await ethers.provider.getBlock(lastBlockNumber);
        return lastBlock.timestamp;
    }

    async function mockFunctionsPriceProxy(
        price0: number,
        decimals0: number,
        publishTime0: number,
        price1: number,
        decimals1: number,
        publishTime1: number
    ): Promise<void> {
        class Price {
            price: number;
            decimals: number;
            publishTime: number;

            constructor(amount: number, decimal: number, publishTime: number) {
                this.price = amount;
                this.decimals = decimal;
                this.publishTime = publishTime;
            }
        }

        const tokenPrice0 = new Price(price0, decimals0, publishTime0);
        const tokenPrice1 = new Price(price1, decimals1, publishTime1);
        let errmsg = 'test message'
        await mockPriceProxy.mock.getEmaPricesByPairNames.returns(tokenPrice0, tokenPrice1, errmsg)
    }


    describe("#setPriceProxy", async () => {

        beforeEach(async () => {
            snapshotId = await takeSnapshot(signer1.provider);
        });

        afterEach(async () => {
            await revertProvider(signer1.provider, snapshotId);
        });

        it("Sets a price proxy", async function () {
            // await expect(
            //     await priceOracle.setPriceProxy(erc20.address, mockPriceProxy.address)
            // ).to.emit(priceOracle, 'SetPriceProxy').withArgs(
            //     erc20.address,
            //     mockPriceProxy.address
            // );

            // expect(
            //     await priceOracle.ChainlinkPriceProxy(erc20.address)
            // ).to.equal(mockPriceProxy.address);
        })

        it("Removes a price proxy", async function () {
            // await expect(
            //     await priceOracle.setPriceProxy(erc20.address, ZERO_ADDRESS)
            // ).to.emit(priceOracle, 'SetPriceProxy').withArgs(
            //     erc20.address,
            //     ZERO_ADDRESS
            // );

            // expect(
            //     await priceOracle.ChainlinkPriceProxy(erc20.address)
            // ).to.equal(ZERO_ADDRESS);
        })

        it("Reverts since one of tokens is zero", async function () {
            // await expect(
            //     priceOracle.setPriceProxy(ZERO_ADDRESS, mockPriceProxy.address)
            // ).to.revertedWith("PriceOracle: zero address");
        })

    });

    describe("#equivalentOutputAmount", async () => {
        let price: number;
        let timeStamp: number;
        let decimals: number;
        // ERC20 decimals
        let erc20Decimals: number;
        let btcDecimals: number;
        // Sets inputs values
        let amountIn = 10000; //  token
        let btcPrice = 1000;
        let erc20Price = 2000;
        let btcPriceDecimals = 2;
        let erc20PriceDecimals = 3;

        let inDecimals = 2
        let outDecimals = 4
        decimals = outDecimals - inDecimals

        price = btcPrice * Math.pow(10, erc20PriceDecimals - btcPriceDecimals) / erc20Price
        btcDecimals = 8;
        erc20Decimals = 18;

        beforeEach(async () => {
            snapshotId = await takeSnapshot(signer1.provider);
            // TODO ???
            // await priceOracle.setPriceProxy(erc20.address, mockPriceProxy.address);
            // await priceOracle.setPriceProxy(_erc20.address, _mockPriceProxy.address);
        });

        afterEach(async () => {
            await revertProvider(signer1.provider, snapshotId);
        });

        it("Gets equal amount of output token when delay is not acceptable, but no other exchange exists (only oracle)", async function () {
            timeStamp = await getLastBlockTimestamp();
            await setNextBlockTimestamp(240);
            await expect(
                priceOracle.equivalentOutputAmount(
                    amountIn,
                    erc20PriceDecimals,
                    btcPriceDecimals,
                    erc20.address,
                    coreBTC.address
                )
            ).to.be.revertedWith("");

        })

        it("ensures correct output in unacceptable delay, different tokens(only oracle)", async function () {
            timeStamp = await getLastBlockTimestamp();
            await setNextBlockTimestamp(240);
            await mockFunctionsPriceProxy(btcPrice, btcPriceDecimals, timeStamp, erc20Price, erc20PriceDecimals, timeStamp);
            await expect(
                priceOracle.equivalentOutputAmount(
                    amountIn,
                    inDecimals,
                    outDecimals,
                    erc20.address,
                    _erc20.address
                )
            ).to.be.revertedWith("");

        })

        it("equivalent output amount for the same token", async function () {
                timeStamp = await getLastBlockTimestamp();
                expect(
                    await priceOracle.equivalentOutputAmount(
                        amountIn,
                        inDecimals,
                        inDecimals,
                        erc20.address,
                        erc20.address
                    )).to.equal(amountIn);
            }
        )

        it("equivalent output amount for the same token with different input precision", async function () {
                timeStamp = await getLastBlockTimestamp();
                let newDecimals = btcPriceDecimals - 1
                expect(
                    await priceOracle.equivalentOutputAmount(
                        amountIn,
                        newDecimals,
                        erc20PriceDecimals,
                        erc20.address,
                        erc20.address
                    )).to.equal(amountIn * Math.pow(10, erc20PriceDecimals - newDecimals));
            }
        )
        it("Gets equal amount of output token when delay is acceptable (only oracle)", async function () {
                timeStamp = await getLastBlockTimestamp();
                await mockFunctionsPriceProxy(btcPrice, btcPriceDecimals, timeStamp, erc20Price, erc20PriceDecimals, timeStamp);
                await setNextBlockTimestamp(1);
                expect(
                    await priceOracle.equivalentOutputAmount(
                        amountIn,
                        inDecimals,
                        inDecimals,
                        coreBTC.address,
                        erc20.address
                    )).to.equal(amountIn * price);
            }
        )

        it("Gets equal amount of output token when delay is acceptable, but no other exchange exists (only oracle)", async function () {
            timeStamp = await getLastBlockTimestamp();
            await mockFunctionsPriceProxy(erc20Price, erc20PriceDecimals, timeStamp, btcPrice, btcPriceDecimals, timeStamp);
            expect(
                await priceOracle.equivalentOutputAmount(
                    amountIn,
                    inDecimals,
                    outDecimals,
                    erc20.address,
                    coreBTC.address
                )
            ).to.equal(amountIn / price * Math.pow(10, decimals));
        })
    });

    describe("#setters", async () => {

        beforeEach(async () => {
            snapshotId = await takeSnapshot(signer1.provider);
        });

        afterEach(async () => {
            await revertProvider(signer1.provider, snapshotId);
        });

        it("Sets acceptable delay", async function () {
            await expect(
                priceOracle.setAcceptableDelay(100)
            ).to.emit(
                priceOracle, "NewAcceptableDelay"
            ).withArgs(acceptableDelay, 100);

            expect(
                await priceOracle.acceptableDelay()
            ).to.equal(100);

            await expect(
                priceOracle.connect(signer1).setAcceptableDelay(100)
            ).to.be.revertedWith("Ownable: caller is not the owner");

        })

        it("renounceOwnership", async function () {
            await expect(
                priceOracle.connect(signer1).renounceOwnership()
            ).to.revertedWith("Ownable: caller is not the owner");

            await priceOracle.renounceOwnership()
        })

    });

});
