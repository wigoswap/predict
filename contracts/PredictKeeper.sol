// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "./interfaces/IPredict.sol";

contract PredictKeeper is KeeperCompatibleInterface, Ownable, Pausable {
    address public predictContract;
    address public register;

    uint256 public constant MaxAheadTime = 30;
    uint256 public aheadTimeForCheckUpkeep = 1;
    uint256 public aheadTimeForPerformUpkeep = 1;

    event NewRegister(address indexed register);
    event NewPredictContract(address indexed predictContract);
    event NewAheadTimeForCheckUpkeep(uint256 time);
    event NewAheadTimeForPerformUpkeep(uint256 time);

    /**
     * @notice Constructor
     * @param _predictContract: Predict Contract address
     */
    constructor(address _predictContract) {
        require(_predictContract != address(0), "Cannot be zero address");
        predictContract = _predictContract;
    }

    modifier onlyRegister() {
        require(
            msg.sender == register || register == address(0),
            "Not register"
        );
        _;
    }

    //The logic is consistent with the following performUpkeep function, in order to make the code logic clearer.
    function checkUpkeep(bytes calldata)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory)
    {
        if (!paused()) {
            bool genesisStartOnce = IPredict(predictContract)
                .genesisStartOnce();
            bool genesisLockOnce = IPredict(predictContract).genesisLockOnce();
            bool paused = IPredict(predictContract).paused();
            uint256 currentEpoch = IPredict(predictContract).currentEpoch();
            uint256 bufferSeconds = IPredict(predictContract).bufferSeconds();
            IPredict.Round memory round = IPredict(predictContract).rounds(
                currentEpoch
            );
            uint256 lockTimestamp = round.lockTimestamp;

            if (paused) {
                //need to unpause
                upkeepNeeded = true;
            } else {
                if (!genesisStartOnce) {
                    upkeepNeeded = true;
                } else if (!genesisLockOnce) {
                    // Too early for locking of round, skip current job (also means previous lockRound was successful)
                    if (
                        lockTimestamp == 0 ||
                        block.timestamp + aheadTimeForCheckUpkeep <
                        lockTimestamp
                    ) {} else if (
                        lockTimestamp != 0 &&
                        block.timestamp > (lockTimestamp + bufferSeconds)
                    ) {
                        // Too late to lock round, need to pause
                        upkeepNeeded = true;
                    } else {
                        //run genesisLockRound
                        upkeepNeeded = true;
                    }
                } else {
                    if (
                        block.timestamp + aheadTimeForCheckUpkeep >
                        lockTimestamp
                    ) {
                        // Too early for end/lock/start of round, skip current job
                        if (
                            lockTimestamp == 0 ||
                            block.timestamp + aheadTimeForCheckUpkeep <
                            lockTimestamp
                        ) {} else if (
                            lockTimestamp != 0 &&
                            block.timestamp > (lockTimestamp + bufferSeconds)
                        ) {
                            // Too late to end round, need to pause
                            upkeepNeeded = true;
                        } else {
                            //run executeRound
                            upkeepNeeded = true;
                        }
                    }
                }
            }
        }
    }

    function performUpkeep(bytes calldata)
        external
        override
        onlyRegister
        whenNotPaused
    {
        require(predictContract != address(0), "predictContract Not Set!");
        bool genesisStartOnce = IPredict(predictContract).genesisStartOnce();
        bool genesisLockOnce = IPredict(predictContract).genesisLockOnce();
        bool paused = IPredict(predictContract).paused();
        uint256 currentEpoch = IPredict(predictContract).currentEpoch();
        uint256 bufferSeconds = IPredict(predictContract).bufferSeconds();
        IPredict.Round memory round = IPredict(predictContract).rounds(
            currentEpoch
        );
        uint256 lockTimestamp = round.lockTimestamp;
        if (paused) {
            // unpause operation
            IPredict(predictContract).unpause();
        } else {
            if (!genesisStartOnce) {
                IPredict(predictContract).genesisStartRound();
            } else if (!genesisLockOnce) {
                // Too early for locking of round, skip current job (also means previous lockRound was successful)
                if (
                    lockTimestamp == 0 ||
                    block.timestamp + aheadTimeForPerformUpkeep < lockTimestamp
                ) {} else if (
                    lockTimestamp != 0 &&
                    block.timestamp > (lockTimestamp + bufferSeconds)
                ) {
                    // Too late to lock round, need to pause
                    IPredict(predictContract).pause();
                } else {
                    //run genesisLockRound
                    IPredict(predictContract).genesisLockRound();
                }
            } else {
                if (
                    block.timestamp + aheadTimeForPerformUpkeep > lockTimestamp
                ) {
                    // Too early for end/lock/start of round, skip current job
                    if (
                        lockTimestamp == 0 ||
                        block.timestamp + aheadTimeForPerformUpkeep <
                        lockTimestamp
                    ) {} else if (
                        lockTimestamp != 0 &&
                        block.timestamp > (lockTimestamp + bufferSeconds)
                    ) {
                        // Too late to end round, need to pause
                        IPredict(predictContract).pause();
                    } else {
                        //run executeRound
                        IPredict(predictContract).executeRound();
                    }
                }
            }
        }
    }

    function setRegister(address _register) external onlyOwner {
        //When register is address(0), anyone can execute performUpkeep function
        register = _register;
        emit NewRegister(_register);
    }

    function setPredictContract(address _predictContract) external onlyOwner {
        require(_predictContract != address(0), "Cannot be zero address");
        predictContract = _predictContract;
        emit NewPredictContract(_predictContract);
    }

    function setAheadTimeForCheckUpkeep(uint256 _time) external onlyOwner {
        require(
            _time <= MaxAheadTime,
            "aheadTimeForCheckUpkeep cannot be more than MaxAheadTime"
        );
        aheadTimeForCheckUpkeep = _time;
        emit NewAheadTimeForCheckUpkeep(_time);
    }

    function setAheadTimeForPerformUpkeep(uint256 _time) external onlyOwner {
        require(
            _time <= MaxAheadTime,
            "aheadTimeForPerformUpkeep cannot be more than MaxAheadTime"
        );
        aheadTimeForPerformUpkeep = _time;
        emit NewAheadTimeForPerformUpkeep(_time);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
