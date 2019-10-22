pragma solidity ^0.5.3;

import "./FlightDelayInsuranceContractBase.sol";

contract FlightStatusOracle {
  bytes32 public oracleName;
  address payable public owner;
  uint public oracleRatioDividend;

  constructor(bytes32 inputOracleName, uint inpitOracleRatioDividend) public payable {
    oracleName = inputOracleName;
    oracleRatioDividend = inpitOracleRatioDividend;

    owner = msg.sender;
  }

  // report
  function reportStatus(address contractAddress, FlightDelayInsuranceContractBase.FlightStatus reportFlightStatus) public {
    require(msg.sender == owner, "only owner can report status!");

    FlightDelayInsuranceContractBase flightContract = FlightDelayInsuranceContractBase(contractAddress);
    flightContract.oracleReportStatus(reportFlightStatus);
  }

  // change
  function changeStatus(address contractAddress, FlightDelayInsuranceContractBase.FlightStatus changeFlightStatus) public {
    require(msg.sender == owner, "only owner can change status!");

    FlightDelayInsuranceContractBase flightContract = FlightDelayInsuranceContractBase(contractAddress);
    flightContract.oracleChangeStatus(changeFlightStatus);
  }

  // pay to oracle
  function getOracleFee(uint amount) public view returns (uint) {
    return amount / oracleRatioDividend;
  }

  // get oracle pay address
  function getOraclePayAddress() public view returns (address payable) {
    return owner;
  }
}
