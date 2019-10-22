pragma solidity ^0.5.3;

import "./FlightDelayInsuranceContractBase.sol";

contract ContractTwo is FlightDelayInsuranceContractBase {
  uint constant delay4PlusBenefitDiv = uint(1);
  uint constant cancelBenefitDiv = uint(1);
  uint constant delay0to1hBenefitDiv = uint(8);
  uint constant delay1to2hBenefitDiv = uint(6);
  uint constant delay2to3hBenefitDiv = uint(3);
  uint constant delay3to4hBenefitDiv = uint(2);
  uint constant delay4hplusBenefitDiv = uint(1);
  uint constant premium = uint(1000 ether);
  uint constant maxBenefitStep = uint(200 ether);
  uint constant frozenInterval = uint(1 days); // frozen 1 day before take off
  uint constant startReportInterval = uint(1 days); // we can report after 1 day since flight take off
  uint constant endReportInterval = uint(3 days); // we can report before 3 days since flight take off
  uint constant endDisputeInterval = uint(4 days); // we can dispute before 4 days since flight take off

  constructor(uint maxBenefit, bytes32 date,
    uint timestampEndOfDate, address inputOracleAddress)
    FlightDelayInsuranceContractBase(maxBenefit, date, timestampEndOfDate, inputOracleAddress) public payable{}

  function getBenefitByFlightStatus(uint maxBenefit, FlightStatus status) public pure returns (uint) {
    // delay 4 hour plus
    if (status == FlightStatus.DELAY4H || status == FlightStatus.DELAY5H ||
      status == FlightStatus.DELAY6H || status == FlightStatus.DELAY7H ||
      status == FlightStatus.DELAY8H || status == FlightStatus.DELAY9H ||
      status == FlightStatus.DELAY10HPLUS) {
      return maxBenefit / delay4PlusBenefitDiv;
    }
    
    if (status == FlightStatus.DELAY0H) {
      return maxBenefit / delay0to1hBenefitDiv;
    }
    
    if (status == FlightStatus.DELAY1H) {
      return maxBenefit / delay1to2hBenefitDiv;
    }
    
    if (status == FlightStatus.DELAY2H) {
      return maxBenefit / delay2to3hBenefitDiv;
    }
    
    if (status == FlightStatus.DELAY3H) {
      return maxBenefit / delay3to4hBenefitDiv;
    }

    // cancel
    if (status == FlightStatus.CANCEL) {
      return maxBenefit / cancelBenefitDiv;
    }

    // return premium for result unknown
    if (status == FlightStatus.UNKNOWN) {
      return getPremium();
    }

    return uint(0);
  }

  function getPremium() public pure returns (uint) {
    return premium;
  }
  
  function whetherSupport(bytes32 flightName) public view returns (bool) {
    // AS flight
    if (flightName == "AS 266" || flightName == "AS 326" || flightName == "AS 340" || 
        flightName == "AS 363" || flightName == "AS 375" || flightName == "AS 783" ||
        flightName == "AS 627" || flightName == "AS 629" || flightName == "AS 657" || 
        flightName == "AS 665" || flightName == "AS 786" || flightName == "AS 1022" || 
        flightName == "AS 1024") {
        return true;    
    } 
    
    // UA flight
    if (flightName == "UA 213" || flightName == "UA 295" || flightName == "UA 497" || 
        flightName == "UA 535" || flightName == "UA 577" || flightName == "UA 583" || 
        flightName == "UA 753" || flightName == "UA 840" || flightName == "UA 1257" || 
        flightName == "UA 1483" || flightName == "UA 1526" || flightName == "UA 1584" || 
        flightName == "UA 1796" || flightName == "UA 1848" || flightName == "UA 1978" ||
        flightName == "UA 2006" || flightName == "UA 2044" || flightName == "UA 2065" || 
        flightName == "UA 2080" || flightName == "UA 2160" || flightName == "UA 2239" || 
        flightName == "UA 2319") {
        return true;    
    }
    
    // AA flight
    if (flightName == "AA 16" || flightName == "AA 76" || flightName == "AA 164" || 
        flightName == "AA 166" || flightName == "AA 177" || flightName == "AA 179" || 
        flightName == "AA 234" || flightName == "AA 276" || flightName == "AA 2305" || 
        flightName == "AA 2652") {
        return true;    
    }
    
    // B6 flight
    if (flightName == "B6 15" || flightName == "B6 16" || flightName == "B6 167" || 
        flightName == "B6 168" || flightName == "B6 415" || flightName == "B6 416" || 
        flightName == "B6 516" || flightName == "B6 615" || flightName == "B6 616" || 
        flightName == "B6 669" || flightName == "B6 670" || flightName == "B6 915" || 
        flightName == "B6 916" || flightName == "B6 1415" || flightName == "B6 1516" || 
        flightName == "B6 1715") {
        return true;    
    }
    
    // DL flight
    if (flightName == "DL 426" || flightName == "DL 430" || flightName == "DL 490" ||
        flightName == "DL 610" || flightName == "DL 643" || flightName == "DL 868" || 
        flightName == "DL 936" || flightName == "DL 1548" || flightName == "DL 1859" || 
        flightName == "DL 2670") {
        return true;    
    } 
    
    // HA flight
    if (flightName == "HA 2353" || flightName == "HA 2352" || flightName == "HA 2360" || 
        flightName == "HA 2361" || flightName == "HA 2362") {
        return true;    
    } 
      
    return false;
  }

  function adjustMaxBenefit(uint maxBenefit) public pure returns (uint) {
    return maxBenefit / maxBenefitStep * maxBenefitStep;
  }

  function getFrozenInterval() public pure returns (uint) {
    return frozenInterval;
  }

  function getStartReportInterval() public pure returns (uint) {
    return startReportInterval;
  }

  function getEndReportInterval() public pure returns (uint) {
    return endReportInterval;
  }

  function getEndDisputeInterval() public pure returns (uint) {
    return endDisputeInterval;
  }
}
