pragma solidity ^0.5.3;

import "./FlightStatusOracle.sol";

contract FlightDelayInsuranceContractBase {

  enum FlightStatus {
    // We can not get result
    UNKNOWN,
    // Flight arrive on time
    ONTIME,
    // Flight is cancelled
    CANCEL,
    // Flight get diverted
    DIVERT,
    // Flight delay (0, 1h)
    DELAY0H,
    // Flight delay [1h, 2h)
    DELAY1H,
    // Flight delay [2h, 3h)
    DELAY2H,
    // Flight delay [3h, 4h)
    DELAY3H,
    // Flight delay [4h, 5h)
    DELAY4H,
    // Flight delay [5h, 6h)
    DELAY5H,
    // Flight delay [6h, 7h)
    DELAY6H,
    // Flight delay [7h, 8h)
    DELAY7H,
    // Flight delay [8h, 9h)
    DELAY8H,
    // Flight delay [9h, 10h)
    DELAY9H,
    // Flight delay >= 10h
    DELAY10HPLUS
  }

  enum ContractStatus {
    // Contract created, but still open to buy
    OPEN,
    // Waiting for report result
    WAITING4REPORT,
    // Waiting for dispute
    WAITING4DISPUTE,
    // Already settled
    SETTLED,
    // Cancelled before deal
    CANCELLED
  }

  address payable public seller;
  address payable public buyer;
  address public oracleAddress;
  uint public validMaxBenefit;
  bytes32 public validFlightName;
  uint public validTimestampEndOfDate;
  bytes32 public validDate;

  ContractStatus public contractStatus;
  FlightStatus public flightStatus;

  event SellerDeposit(address indexed _from, uint _value);
  event BuyerDeposit(address indexed _from, uint _value);
  event ContractBuyRefund(address indexed _from, uint _value);
  event ContractBought(
    address indexed _from, address contractAddress);
  event ContractCreateRefund(address indexed _from, uint _value);
  event ContractCreated(
    address indexed _from, uint _maxBenefit, bytes32 _date);

  constructor(
    uint maxBenefit, bytes32 date,
    uint timestampEndOfDate, address inputOracleAddress) public payable {
    // potential adjust maxBenefit
    require(maxBenefit > getPremium(), "max benefit should larger than premium");
    uint adjustedMaxBenefit = adjustMaxBenefit(maxBenefit);

    require(checkMaxBenefit(adjustedMaxBenefit), "real max benefit should equal to max benefit!");
    require(msg.value >= adjustedMaxBenefit, "insufficient initial deposit fund!");
    require(timestampEndOfDate - getFrozenInterval() > block.timestamp, "schedule take off time should at least ");

    validMaxBenefit = adjustedMaxBenefit;
    validTimestampEndOfDate = timestampEndOfDate;
    oracleAddress = inputOracleAddress;
    validDate = date;

    seller = msg.sender;
    uint remainingAmount = msg.value;

    // seller deposit
    remainingAmount -= validMaxBenefit;
    emit SellerDeposit(seller, validMaxBenefit);

    // return remaining value
    seller.transfer(remainingAmount);
    emit ContractCreateRefund(seller, remainingAmount);
    emit ContractCreated(seller, validMaxBenefit, validDate);

    flightStatus = FlightStatus.UNKNOWN;
    contractStatus = ContractStatus.OPEN;
  }

  // cancel this order before deal
  function cancelContract() public payable {
    require(msg.sender == seller, "only owner can cancel this contract");
    require(contractStatus == ContractStatus.OPEN, "contract status need to be open");

    contractStatus = ContractStatus.CANCELLED;
    // return remaining balance back to seller
    seller.transfer(address(this).balance);
  }

  // buy contract
  function buyContract(bytes32 flightName) public payable {
    require(msg.value >= getPremium(), "insufficient fund for premium!");
    require(validTimestampEndOfDate - getFrozenInterval() > block.timestamp, "should buy getFrozenPeriod before schedule take off time");
    require(contractStatus == ContractStatus.OPEN, "contract status need to be open");
    require(whetherSupport(flightName) == true, "do not support this flight");

    buyer = msg.sender;
    uint remainingAmount = msg.value;

    // buyer deposit
    remainingAmount -= getPremium();
    emit BuyerDeposit(buyer, getPremium());

    // return remaining value
    buyer.transfer(remainingAmount);
    validFlightName = flightName;
    
    emit ContractBuyRefund(buyer, remainingAmount);
    emit ContractBought(buyer, address(this));

    contractStatus = ContractStatus.WAITING4REPORT;
  }

  // report flight status
  function oracleReportStatus(FlightStatus reportFlightStatus) public {
    require(msg.sender == oracleAddress, "only registred oracle can report result!");
    require(validTimestampEndOfDate + getStartReportInterval() < block.timestamp, "should report after (schedule_take_off_time + start_report_interval)");
    require(validTimestampEndOfDate + getEndReportInterval() >= block.timestamp, "should report before (schedule_take_off_time + end_report_interval)");
    require(contractStatus == ContractStatus.WAITING4REPORT, "contract status need to be waiting for report");

    // set status
    flightStatus = reportFlightStatus;
    contractStatus = ContractStatus.WAITING4DISPUTE;
  }

  // change result from dispute
  function oracleChangeStatus(FlightStatus updatedFlightStatus) public {
    require(msg.sender == oracleAddress, "only registred oracle can change result!");
    require(validTimestampEndOfDate + getEndReportInterval() < block.timestamp, "should change after (schedule_take_off_time + end_report_interval)");
    require(validTimestampEndOfDate + getEndDisputeInterval() >= block.timestamp, "should change before (schedule_take_off_time + end_dispute_interval)");
    require(contractStatus == ContractStatus.WAITING4DISPUTE, "contract status need to be waiting for dispute");

    // set status
    flightStatus = updatedFlightStatus;
  }

  // settle this contract, anyone can call
  // collect platform fee from buyer if buyer win, or visa versa.
  // However, we still collect platform fee if result is unknown
  function settle() public payable {
    require(
      validTimestampEndOfDate + getEndDisputeInterval() < block.timestamp,
      "should settle after (schedule_take_off_time + end_dispute_interval)");
    require(
      contractStatus == ContractStatus.WAITING4DISPUTE || contractStatus == ContractStatus.WAITING4REPORT,
      "contract status need to be waiting for dispute");

    FlightStatusOracle oracle = FlightStatusOracle(oracleAddress);
    address payable oraclePayAddress = oracle.owner();
    uint remainingAmount = address(this).balance;

    uint oweBuyer = getBenefitByFlightStatus(validMaxBenefit, flightStatus);
    remainingAmount -= oweBuyer;
    if (oweBuyer != 0) {
      if (flightStatus != FlightStatus.UNKNOWN) {
        // collect oracle fee from buyer if we know result and buyer win;
        uint feeOfOracle = oracle.getOracleFee(oweBuyer);
        oweBuyer -= feeOfOracle;
        oraclePayAddress.transfer(feeOfOracle);
      }

      // pay to buyer
      buyer.transfer(oweBuyer);
    } else {
      //  collect oracle fee from seller if we know result and seller win;
      if (flightStatus != FlightStatus.UNKNOWN) {
        //  collect oracle fee from seller if we know result and seller win;
        uint feeOfOracle = oracle.getOracleFee(getPremium());
        remainingAmount -= feeOfOracle;
        oraclePayAddress.transfer(feeOfOracle);
      }
    }

    uint oweSeller = remainingAmount;
    remainingAmount -= oweBuyer;
    if (oweSeller != 0) {
      // pay to seller
      seller.transfer(oweSeller);
    }

    // set status
    contractStatus = ContractStatus.SETTLED;
  }

  // check whether benefit is set correctly
  function checkMaxBenefit(uint maxBenefit) private pure returns (bool) {
    uint realMaxBenefit = 0;

    // loop all flight status
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.UNKNOWN)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.UNKNOWN);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.ONTIME)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.ONTIME);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.CANCEL)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.CANCEL);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DIVERT)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DIVERT);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY0H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY0H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY1H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY1H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY2H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY2H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY3H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY3H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY4H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY4H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY5H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY5H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY6H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY6H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY7H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY7H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY8H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY8H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY9H)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY9H);
    }
    if (realMaxBenefit < getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY10HPLUS)) {
      realMaxBenefit = getBenefitByFlightStatus(maxBenefit, FlightStatus.DELAY10HPLUS);
    }

    return realMaxBenefit == maxBenefit;
  }

  function getBenefitByFlightStatus(uint maxBenefit, FlightStatus status) public pure returns (uint);

  function getPremium() public pure returns (uint);
  
  function whetherSupport(bytes32 flightName) public view returns (bool);

  function adjustMaxBenefit(uint maxBenefit) public pure returns (uint) {
    return maxBenefit;
  }

  // contract is frozen after (schedule_take_off_time - frozen_interval)
  function getFrozenInterval() public pure returns (uint);

  // we should report result after (schedule_take_off_time + start_report_interval)
  function getStartReportInterval() public pure returns (uint);

  // we should report result before (schedule_take_off_time + end_report_interval)
  function getEndReportInterval() public pure returns (uint);

  // we should dispute before (schedule_take_off_time + end_dispute_interval)
  function getEndDisputeInterval() public pure returns (uint);
}
