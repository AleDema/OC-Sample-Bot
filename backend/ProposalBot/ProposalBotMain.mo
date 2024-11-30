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
import PB "./ProposalBot";
import DateTime "mo:datetime/DateTime";
import Prng "mo:prng";

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

  let governanceService = GS.GovernanceService();
  let proposalService = PS.ProposalService(governanceService, logService);

  stable let proposalBotData = PB.initModel();
  let proposalBot= PB.ProposalBot(proposalBotData, botService, proposalService, logService);

  //////////////////////////
  ////////////////// PROPOSAL BOT
  //////////////////////////

  system func postupgrade() {
    if(Option.isSome(proposalBotData.timerId)){
        proposalBotData.timerId := ?Timer.recurringTimer<system>(#seconds(5* 60), func() : async () {
        await proposalBot.update(proposalBotData.lastProposalId);
      });
    }
  };

  public func initTimer<system>(_tickrateInSeconds : ?Nat) : async Result.Result<(), Text> {
      await proposalBot.initTimer(_tickrateInSeconds);
  };

  public shared({caller}) func initBot<system>(name : Text, _displayName : ?Text) : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };
    await botService.initBot(name : Text, _displayName : ?Text);
  };

  public shared({caller}) func cancelTimer() : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    await proposalBot.cancelTimer();
  };

  public shared({caller}) func update(start : ?Nat64) : async () {
    if (not G.isCustodian(caller, custodians)) {
      return
    };

    await proposalBot.update(start);
  };

  public shared({caller}) func addSubscriber(sub : PB.Subscriber, inviteCode : ?Nat64) : async Result.Result<(), Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

   await* proposalBot.addSubscriber(sub, inviteCode, Principal.fromActor(Self));
  };

  public func getSubscribers() : async [PB.Subscriber] {
    proposalBot.getSubscribers();
  };

  public shared({caller}) func deleteSubscriber(id : Text) : async Result.Result<(), Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    
    proposalBot.deleteSubscriber(id);
  };

  public shared({caller}) func updateSubscriber(id : Text, newTopics : [Int32]) : async Result.Result<(), Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    
    proposalBot.updateSubscriber(id, newTopics);
  };

  public shared({caller}) func tryJoinCommunity(communityCanisterId : Text, inviteCode : ?Nat64) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    
    await* botService.joinCommunity(communityCanisterId : Text, inviteCode : ?Nat64, Principal.fromActor(Self));
  };

  public shared({caller}) func tryJoinChannel(communityCanisterId : Text, channelId : Nat, inviteCode : ?Nat64) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    await* botService.joinChannel(communityCanisterId : Text,  channelId, inviteCode : ?Nat64);
  };

  // public func testGetProposalMessage(proposalId : Nat) : async Result.Result<Text, Text> {

  //   var index = switch(await* botService.getLatestGroupMessageIndex(NNS_PROPOSAL_GROUP_ID)){
  //       case(?index){index};
  //       case(_){
  //           logService.addLog(#Info, "getLatestMessageIndex error", null);
  //           return #err("Error")
  //       };
  //   };

  //   let #ok(res) = await* botService.getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, [index], null)
  //   else{
  //     return #err("Error getGroupMessagesByIndex");
  //   };
    
  //   for (message in Array.vals(res.messages)){
  //       switch(botService.getNNSProposalMessageData(message)){
  //         case(#ok(proposalData)){
  //           if (proposalId > Nat64.toNat(proposalData.proposalId)){
  //             return #err("not yet in group")
  //           };

  //           let diff = Nat64.toNat(proposalData.proposalId) - proposalId ;
  //           let #ok(res) = await* botService.getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, [index - Nat32.fromNat(diff)], null)
  //           else{
  //             return #err("Error getGroupMessagesByIndex");
  //           };
  //           for (message in Array.vals(res.messages)){
  //             switch(botService.getNNSProposalMessageData(message)){
  //               case(#ok(proposalData)){
  //                 return #ok(Nat64.toText(proposalData.proposalId));
  //               };
  //               case(_){
  //                 return #err("Error getNNSProposalMessageData")
  //               };
  //             };
  //           };
  //         };
  //         case(_){
  //         return #err("Error getNNSProposalMessageData")
  //       };
  //       };
  //   };
  //   #ok("not found")
  // };

  // public func testCommunitySummary() : async Result.Result<OCApi.CommunitySummaryResponse, Text>{
  //   await* ocService.publicCommunitySummary("x5c7v-eyaaa-aaaar-bfcca-cai", {
  //     invite_code= null;
  //   });
  // };

  // public func testListProposals(start : Nat) : async Result.Result<Nat, Text>{
  //  let res = await* proposalService.listProposalsAfterId("rrkah-fqaaa-aaaaa-aaaaq-cai", ?start, {PS.ListProposalArgsDefault() with omitLargeFields = ?true});

  //   switch(res){
  //     case(#ok(data)){
  //      #ok(Array.size(data.proposal_info));
  //     };
  //     case(#err(err)){
  //      #err(err)
  //     }
  //   }
  // };

  // public func testSendChannelMessage(communityCanisterId : Text, channelId : Nat, text : Text) : async Result.Result<OCApi.SendMessageResponse, Text>{
  //   let seed : Nat64 = Nat64.fromIntWrap(Time.now());
  //   let rng = Prng.Seiran128();
  //   rng.init(seed);
  //   let id = Nat64.toNat(rng.next());
  //   await* ocService.sendChannelMessage(communityCanisterId, channelId, "test_bot", null, #Text({text = text}), id,  null)
  // };

  // public func testUserSummary(userId : ?Principal, username : ?Text) : async Result.Result<OCApi.UserSummaryResponse, Text>{
  //   await* ocService.userSummary("4bkt6-4aaaa-aaaaf-aaaiq-cai", {userId = userId; username= username});
  // };

  //////////////////////////
  ////////////////// TEST ENDPOINTS
  //////////////////////////

  // public func testDate(secs : Int) : async Text{
  //   let fmt = "YYYY-MM-DD HH:mm";
  //   let date = DateTime.DateTime(secs * 1_000_000_000); //secs to nano
  //   DateTime.toTextAdvanced(date, #custom({format = fmt; locale = null}))
  // };


  //////////////////PROPOSAL BOT
  public shared({caller}) func testSetLastProposalId(proposalId : Nat64) : async () {
    if (not G.isCustodian(caller, custodians)) {
      return
    };

    proposalBotData.lastProposalId := ?proposalId;
  };

  public func testGetLastProposalId() : async ?Nat64 {
    proposalBotData.lastProposalId
  };

  // public func testGetPendingList() : async ([TT.ProposalAPI], Nat, Nat){
  //   (List.toArray(proposalBotData.pendingSCMList), proposalBotData.numberOfTicksSinceUpdate, List.size(proposalBotData.pendingSCMList))
  // };

  // public func testClearPendingList() : async (){
  //   proposalBotData.pendingSCMList := List.nil<TT.ProposalAPI>();
  // };

//   public func testGetProposalsLookup() : async [{proposalId : Nat64; topicId : Int32; messageIndex : ?Nat32; attempts : Nat}] {
//     Map.toArrayMapDesc<Nat, {proposalData : TT.ProposalAPI; messageIndex : ?Nat32; attempts : Nat}, {proposalId : Nat64; topicId : Int32; messageIndex : ?Nat32; attempts : Nat}>(proposalBotData.proposalsLookup,
//     func (k, v) : ?{proposalId : Nat; topicId : Int32; messageIndex : ?Nat32; attempts : Nat} {
//       return ?{proposalId = k; topicId = v.proposalData.topicId; messageIndex = v.messageIndex; attempts = v.attempts};
//     });
//   };

  public shared({caller}) func testClearProposalsLookup() : async (){
    if (not G.isCustodian(caller, custodians)) {
      return
    };
    
    Map.clear(proposalBotData.proposalsLookup);
  };

  public func testGetLatestNNSMessageIndex() : async?Nat32{
    proposalBotData.latestNNSMessageIndex;
  };

  public shared({caller}) func testSetLatestNNSMessageIndex(index :?Nat32) : async (){
    if (not G.isCustodian(caller, custodians)) {
      return
    };
    
    proposalBotData.latestNNSMessageIndex := index;
  };

  public shared({caller}) func testResetState() : async (){
    if (not G.isCustodian(caller, custodians)) {
      return
    };
    
    Map.clear(proposalBotData.proposalsLookup);
    proposalBotData.latestNNSMessageIndex := null;
  };

  ////////////////// OC API

  public func getBotStatus() : async BT.BotStatus {
    botService.getBotStatus();
  };

  // public func setBotStatus() {
  //   botService.setBotStatus();
  // };

  // public shared({caller}) func joinTestGroup() : async Result.Result<Text, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized: " # Principal.toText(caller));
  //   };

  //   await* botService.joinGroup(TEST_GROUP_ID, null);
  // };

  // public shared({caller}) func testJoinGroup(groupCanisterId : T.TextPrincipal) : async Result.Result<Text, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized: " # Principal.toText(caller));
  //   };
  //   await* botService.joinGroup(groupCanisterId, null);
  // };

  // public shared({caller}) func testSendMessage(content : Text) : async Result.Result<T.SendMessageResponse, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized: " # Principal.toText(caller));
  //   };

  //   let #ok(res) = await* botService.sendTextGroupMessage(TEST_GROUP_ID, content, null)
  //   else {
  //    return #err("Error sending message");
  //   };
  //   #ok(res)
  // };

  // public shared({caller}) func testSendMessageThread(content : Text, threadIndexId : Nat32) : async Result.Result<T.SendMessageResponse, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized: " # Principal.toText(caller));
  //   };

  //   let #ok(res) = await* botService.sendTextGroupMessage(TEST_GROUP_ID, content, ?threadIndexId)
  //   else {
  //     return #err("Error sending message in thread");
  //   };
  //   #ok(res)
  // };

  // public shared({caller}) func testEditMessage(messageId : Nat, newContent : Text) : async Result.Result<OC.EditMessageResponse, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized: " # Principal.toText(caller));
  //   };

  //   let #ok(res) = await*  botService.editTextGroupMessage(TEST_GROUP_ID, messageId, newContent)
  //   else{
  //     return #err("Error editing message");
  //   };
  //   #ok(res)
  // };

  // public shared({caller}) func testGetMessages(indexes : [Nat32]) : async Result.Result<OC.MessagesResponse, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized: " # Principal.toText(caller));
  //   };

  //   await*  botService.getGroupMessagesByIndex(TEST_GROUP_ID, indexes, ?0);
  // };

  // public shared({caller}) func testGetNNSProposals(indexes : [Nat32]) : async Result.Result<OC.MessagesResponse, Text>{
  //   // if (not G.isCustodian(caller, custodians)) {
  //   //   return #err("Not authorized: " # Principal.toText(caller));
  //   // };

  //   await*  botService.getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexes, ?0);
  // };

  // public shared({caller}) func testGetProposalsGroupLastId() : async Result.Result<OC.MessageIndex, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized: " # Principal.toText(caller));
  //   };
  //   var index = switch(await* botService.getLatestGroupMessageIndex(NNS_PROPOSAL_GROUP_ID)){
  //     case(?index){index};
  //     case(_){return #err("Error")};
  //   };

  //   return #ok(index)
  // };

  
  // public func testRange(start: Int, end: Nat) : async Result.Result<([OCApi.MessageEventWrapper], [Nat32]), ()>{
  //   let indexVec = Iter.range(end, start) |> 
  //                     Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
  //                       Iter.toArray(_);

  //   let #ok(res) = await* botService.getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexVec, null)
  //   else {
  //     //Error retrieving messages
  //     logService.addLog(#Error, "[testRange] Error retrieving messages", null);
  //     return #err();
  //   };

  //   #ok((res.messages, indexVec))
  // };

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