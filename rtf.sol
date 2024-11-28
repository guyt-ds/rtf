// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Recurrence {
    uint8[] daysOfWeek; // Array of weekdays (0 = Sunday, 6 = Saturday)
    uint256 timeOfDay;  // Time of day in seconds since 00:00 (e.g., 20:00 = 72000 seconds)
}

struct ScheduledTransfer {
    address from;
    address to;
    uint256 amount;
    Recurrence recurrence;
    uint256 nextExecutionTime; // Tracks when this transfer should next execute
}

function getNextExecutionTime(uint256 currentTimestamp, Recurrence memory recurrence) internal pure returns (uint256) {
    uint256 nextTime = currentTimestamp;
    uint8 dayOfWeek = uint8((nextTime / 1 days + 4) % 7); // Calculate day of the week

    while (true) {
        // If the day matches one of the recurrence days
        for (uint8 i = 0; i < recurrence.daysOfWeek.length; i++) {
            if (recurrence.daysOfWeek[i] == dayOfWeek) {
                // Check if the time of day is valid
                uint256 todayExecutionTime = (nextTime / 1 days) * 1 days + recurrence.timeOfDay;
                if (todayExecutionTime > nextTime) {
                    return todayExecutionTime; // Found the next execution time
                }
            }
        }

        // Move to the next day
        nextTime += 1 days;
        dayOfWeek = (dayOfWeek + 1) % 7;
    }
}

function executeScheduledTransfers() external {
    uint256 currentTime = block.timestamp;

    for (uint256 i = 0; i < scheduledTransfers.length; i++) {
        ScheduledTransfer storage transfer = scheduledTransfers[i];

        if (currentTime >= transfer.nextExecutionTime) {
            // Perform the transfer
            token.transferFrom(transfer.from, transfer.to, transfer.amount);

            // Calculate the next execution time
            transfer.nextExecutionTime = getNextExecutionTime(currentTime, transfer.recurrence);
        }
    }
}


----

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TreasuryManagement {
    address public admin;

    struct ScheduledTransfer {
        address token;       // ERC20 token contract address
        address from;
        address to;
        uint256 amount;
        uint256 nextExecutionTime;
        uint256 interval; // in seconds
    }

    struct BalanceSweep {
        address token;        // ERC20 token contract address
        address source;
        address destination;
        uint256 minBalance;
    }

    ScheduledTransfer[] public scheduledTransfers;
    BalanceSweep[] public balanceSweeps;

    event ScheduledTransferExecuted(uint256 indexed transferId, address from, address to, uint256 amount);
    event BalanceSweepExecuted(uint256 indexed sweepId, address source, address destination, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function addScheduledTransfer(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 startTime,
        uint256 interval
    ) external onlyAdmin {
        require(token != address(0), "Invalid token address");
        require(from != address(0), "Invalid from address");
        require(to != address(0), "Invalid to address");
        require(amount > 0, "Amount must be greater than zero");

        scheduledTransfers.push(ScheduledTransfer(token, from, to, amount, startTime, interval));
    }

    function addBalanceSweep(
        address token,
        address source,
        address destination,
        uint256 minBalance
    ) external onlyAdmin {
        require(token != address(0), "Invalid token address");
        require(source != address(0), "Invalid source address");
        require(destination != address(0), "Invalid destination address");

        balanceSweeps.push(BalanceSweep(token, source, destination, minBalance));
    }

    function executeScheduledTransfers() external {
        for (uint256 i = 0; i < scheduledTransfers.length; i++) {
            ScheduledTransfer storage transfer = scheduledTransfers[i];
            if (block.timestamp >= transfer.nextExecutionTime) {
                IERC20 token = IERC20(transfer.token);

                // Perform transfer
                bool success = token.transferFrom(transfer.from, transfer.to, transfer.amount);
                require(success, "Transfer failed");

                // Update next execution time
                transfer.nextExecutionTime += transfer.interval;

                emit ScheduledTransferExecuted(i, transfer.from, transfer.to, transfer.amount);
            }
        }
    }

    function executeBalanceSweeps() external {
        for (uint256 i = 0; i < balanceSweeps.length; i++) {
            BalanceSweep storage sweep = balanceSweeps[i];
            IERC20 token = IERC20(sweep.token);

            uint256 sourceBalance = token.balanceOf(sweep.source);
            if (sourceBalance > sweep.minBalance) {
                uint256 excess = sourceBalance - sweep.minBalance;

                // Perform sweep
                bool success = token.transferFrom(sweep.source, sweep.destination, excess);
                require(success, "Sweep transfer failed");

                emit BalanceSweepExecuted(i, sweep.source, sweep.destination, excess);
            }
        }
    }
}
