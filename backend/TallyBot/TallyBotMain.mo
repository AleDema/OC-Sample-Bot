import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Time "mo:base/Time";
import Random "mo:base/Random";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Timer "mo:base/Timer";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Map "mo:map/Map";
import T "../Types";
import TU "../TextUtils";
import G "../Guards";
import MT "../MetricTypes";
import F "../Fixtures";
import TT "../TrackerTypes";
import LS "../Log/LogService";
import LT "../Log/LogTypes";
import {  nhash; n64hash; n32hash; thash } "mo:map/Map";
import BT "../Bot/BotTypes";
import BS "../Bot/BotService";
import OCS "../OC/OCService";
import OCApi "../OC/OCApi";
import GS "../Governance/GovernanceService";
import GT "../Governance/GovernanceTypes";
import PS "../Proposal/ProposalService";
import PB "../ProposalBot/ProposalBot";
import DateTime "mo:datetime/DateTime";
import Prng "mo:prng";
import TallyTypes "./TallyTypes";
import TallyBot "./TallyBot";

  //TODO connect with OC msg index for GAAS

shared ({ caller }) actor class OCBot() = Self {

  let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";
  //let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";

  stable var custodians = List.make<Principal>(caller);

  stable let logs = LS.initLogModel();
  let logService = LS.LogServiceImpl(logs, 100, true);

  stable let botData = BS.initModel();
  let ocService = OCS.OCServiceImpl();
  let botService = BS.BotServiceImpl(botData, ocService, logService);

  let tallyBot = TallyBot.TallyBot(botService, logService);

  //////////////////////////
  ////////////////// TALLY BOT
  //////////////////////////

   public func tallyUpdate (feed : [TallyTypes.TallyFeed]) : async (){
      logService.logInfo("Tally update", null);
      await tallyBot.tallyUpdate(feed);
   };

   public func toggleNNSGroup() : async Bool {
    tallyBot.toggleNNSGroup()
   };

   public func testGetProposalMessage(proposalId : Nat) : async Result.Result<Text, Text> {

    var index = switch(await* botService.getLatestGroupMessageIndex(NNS_PROPOSAL_GROUP_ID)){
        case(?index){index};
        case(_){
            logService.addLog(#Info, "getLatestMessageIndex error", null);
            return #err("Error")
        };
    };

    let #ok(res) = await* botService.getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, [index], null)
    else{
      return #err("Error getGroupMessagesByIndex");
    };
    
    for (message in Array.vals(res.messages)){
        switch(botService.getNNSProposalMessageData(message)){
          case(#ok(proposalData)){
            if (proposalId > Nat64.toNat(proposalData.proposalId)){
              return #err("not yet in group")
            };

            let diff = Nat64.toNat(proposalData.proposalId) - proposalId ;
            let #ok(res) = await* botService.getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, [index - Nat32.fromNat(diff)], null)
            else{
              return #err("Error getGroupMessagesByIndex");
            };
            for (message in Array.vals(res.messages)){
              switch(botService.getNNSProposalMessageData(message)){
                case(#ok(proposalData)){
                  return #ok(Nat64.toText(proposalData.proposalId));
                };
                case(_){
                  return #err("Error getNNSProposalMessageData")
                };
              };
            };
          };
          case(_){
          return #err("Error getNNSProposalMessageData")
        };
        };
    };
    #ok("not found")
  };

  //////////////////////////
  ////////////////// ADMIN
  //////////////////////////
  public shared ({ caller }) func addCustodian(new_custodian : Principal) : async Result.Result<Text, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    custodians := List.push(new_custodian, custodians);

    return #ok("Custodian Added");
  };

  
  //////////////////////////
  ////////////////// METRICS
  //////////////////////////
  public shared({caller}) func getCanisterStatus() : async Result.Result<MT.CanisterStatus, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    let management_canister_actor : MT.ManagementCanisterActor = actor("aaaaa-aa");
    let res = await management_canister_actor.canister_status({
      canister_id = Principal.fromActor(Self);
    });
    Debug.print(debug_show (res.settings.controllers));
    let canister_status = {
      cycle_balance = res.cycles;
      memory_used = res.memory_size;
      daily_burn = res.idle_cycles_burned_per_day;
      controllers = res.settings.controllers;
    };
    #ok(canister_status)
  };

  //////////////////////////
  ////////////////// LOGS
  //////////////////////////
  public func getLogs(filter : ?LT.LogFilter) : async [LT.Log] {
    logService.getLogs(filter);
  };

  public shared({caller}) func clearLogs() : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    logService.clearLogs();
    #ok()
  };

};
