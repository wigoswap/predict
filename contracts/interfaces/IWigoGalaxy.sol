// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWigoGalaxy {
    function getResidentStatus(address _residentAddress)
        external
        view
        returns (bool);

    function getReferralData(address _residentAddress)
        external
        view
        returns (
            address,
            bool,
            uint256
        );

    function hasRegistered(address _residentAddress)
        external
        view
        returns (bool);
}
