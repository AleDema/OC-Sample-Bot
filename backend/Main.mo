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
import Map "mo:map/Map";
import T "./Types";
import TU "./TextUtils";
import G "./Guards";
import OC "./OCTypes";
import MT "./MetricTypes";
import F "./Fixtures";
import TT "./TrackerTypes";
import LS "./Log/LogService";
import LT "./Log/LogTypes";
import {  nhash; n64hash; n32hash; thash } "mo:map/Map";
import BT "./OC/BotTypes";
import BS "./OC/BotService";
import OCS "./OC/OCService";
shared ({ caller }) actor class OCBot() = Self {


  let FIND_PROPOSALS_BATCH_SIZE : Nat32 = 100;
  let PENDING_SCM_LIMIT = 10;
  let MAX_TICKS_WITHOUT_UPDATE = 3;

  let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";
  let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
  let GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";

  stable var custodians = List.make<Principal>(caller);
  stable var groups = List.nil<Principal>();
  stable var activeProposals = Map.new<OC.ProposalId, OC.MessageId>();
  stable var botStatus : T.BotStatus = #NotInitialized;
  stable var botName : Text = "";
  stable var botDisplayName : ?Text = null;
  stable var lastMessageID : Nat = 0; //TODO: reconsider

  stable var lastProposalId : ?Nat = null;
  stable var timerId :?Nat = null;
  stable var pendingSCMList = List.nil<TT.ProposalAPI>();
  stable var latestNNSMessageIndex : ?Nat32 = null;
  stable let proposalsLookup : T.ProposalsLookup = Map.new();
  stable var numberOfTicksSinceUpdate = 0;

  stable let logs = LS.initLogModel();
  let logService = LS.LogServiceImpl(logs, 100, true);

  stable let botData = BS.initModel();
  let ocService = OCS.OCServiceImpl();
  let botService = BS.BotService(botData, ocService, logService);

  //////////////////////////
  ////////////////// PROPOSAL BOT
  //////////////////////////

  system func postupgrade() {
    if(Option.isSome(timerId)){
      timerId := ?Timer.recurringTimer<system>(#seconds(5* 6), func() : async () {
        await update(lastProposalId);
      });
    }
  };

  public func initTimer<system>(_tickrateInSeconds : ?Nat) : async Result.Result<(), Text> {
            
    let tickrate : Nat = Option.get(_tickrateInSeconds, 5* 60); // 1 minutes
    switch(timerId){
        case(?t){ return #err("Timer already created")};
        case(_){};
    };

    timerId := ?Timer.recurringTimer<system>(#seconds(tickrate), func() : async () {
      await updateGroup(lastProposalId);
    });

    return #ok()
  };

  public func cancelTimer() : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    switch(timerId){
      case(?t){
        Timer.cancelTimer(t);
        timerId := null;
        return #ok();
      };
      case(_){
        return #err("No Timer to delete");
      }
    }
  };

  public func update(start : ?Nat) : async () {
    logService.addLog(#Info, "Running update", null);
    let tracker : TT.Tracker = actor ("vkqwa-eqaaa-aaaap-qhira-cai");

    numberOfTicksSinceUpdate := numberOfTicksSinceUpdate + 1;
    logService.addLog(#Info, "Number of ticks since last update: " # Nat.toText(numberOfTicksSinceUpdate), null);
    let res = await tracker.getProposals(GOVERNANCE_ID, start, [8, 13]);
    switch(res){
      case(#ok(data)){
          for(proposal in Array.vals(data)){
            Map.set(proposalsLookup, nhash, proposal.id, { proposalData = proposal; messageIndex = null; attempts = 0});
          };

          ignore await* matchProposalsWithMessages(NNS_PROPOSAL_GROUP_ID, proposalsLookup);
      };
      case(#err(e)){
        switch(e){
          case(#InvalidProposalId(d)){
            logService.addLog(#Info, "InvalidProposalId, set last proposal id to: " # Nat.toText(d.end + 1), null);
            lastProposalId := ?(d.end + 1); //TODO; remove temp fix until poll service is fixed
          };
          case(_){};
        };
      };
    };

    for(proposal in Map.vals(proposalsLookup)){

      switch(T.topicIdToVariant(proposal.proposalData.topicId)){
        case(#RVM){
          if(Option.isSome(proposal.messageIndex) or proposal.attempts > 3){
            await* createProposalThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, proposal.proposalData, proposal.messageIndex);
            Map.delete(proposalsLookup, nhash, proposal.proposalData.id);
          }
        };
        case(#SCM){
          if(TU.isSeparateBuildProcess(proposal.proposalData.title)){
            if(Option.isSome(proposal.messageIndex) or proposal.attempts > 3){
              await* createProposalThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, proposal.proposalData, proposal.messageIndex);
              Map.delete(proposalsLookup, nhash, proposal.proposalData.id);
            };
          } else {
            if(not List.some(pendingSCMList, func(p : TT.ProposalAPI) : Bool { return p.id == proposal.proposalData.id})){
              pendingSCMList := List.push(proposal.proposalData, pendingSCMList);
              numberOfTicksSinceUpdate := 0;
              logService.addLog(#Info, "Pushing to list: " # Nat.toText(proposal.proposalData.id), null);
            } else {
              logService.addLog(#Info, "Already in list" # Nat.toText(proposal.proposalData.id), null);
            };
          };

        };
        case(_){};
      };

      if(proposal.proposalData.id > Option.get(lastProposalId, 0)){
        lastProposalId := ?(proposal.proposalData.id + 1); //TODO; remove temp fix until poll service is fixed
      };
    };

    if((List.size(pendingSCMList) > 0 and List.size(pendingSCMList) < PENDING_SCM_LIMIT and numberOfTicksSinceUpdate > MAX_TICKS_WITHOUT_UPDATE)){
      logService.addLog(#Info, "Sending pending list cause wait for quiet expired", null);
      let arr = List.toArray(pendingSCMList);
      await* createBatchThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, arr, proposalsLookup);
      for (p in Array.vals(arr) ){
        Map.delete(proposalsLookup, nhash, p.id);
      };
      pendingSCMList := List.nil<TT.ProposalAPI>();
    } else if (List.size(pendingSCMList) > PENDING_SCM_LIMIT){
        logService.addLog(#Info, "Sending pending list cause too may entries", null);
        let chunks = List.chunks(PENDING_SCM_LIMIT, pendingSCMList);
        for(chunk in List.toIter(chunks)){
          if (List.size(chunk) < PENDING_SCM_LIMIT){
              pendingSCMList := chunk;
              return;
          } else {
            await* createBatchThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, List.toArray(chunk), proposalsLookup);
            for ( p in List.toIter(chunk) ){
              Map.delete(proposalsLookup, nhash, p.id);
            };
          }
        };
        pendingSCMList := List.nil<TT.ProposalAPI>();
    };

    logService.addLog(#Info, "Finished update", null);
  };

  func matchProposalsWithMessages(groupId : Text, pending : T.ProposalsLookup) : async* Result.Result<(), Text>{
    //map is empty, nothing to match
    if(Map.size(pending) == 0){
      logService.addLog(#Info, "[matchProposalsWithMessages] Map empty", null);
      return #ok();
    };

    var index = switch(await* botService.getLatestGroupMessageIndex(groupId)){
      case(?index){index};
      case(_){
         logService.addLog(#Info, "[matchProposalsWithMessages] getLatestMessageIndex error", null);
        return #err("Error")};
    };

    //if the index is the same as the latest message index, nothing to match
    if(index == Option.get(latestNNSMessageIndex, index + 1)){
      logService.addLog(#Info, "[matchProposalsWithMessages] up to date", null);
      return #ok();
    };


    var start = index;
    var check = true;
    label attempts while (check){

    //if latestNNSMessageIndex is null, get last BATCH_SIZE once
    if(Option.isNull(latestNNSMessageIndex)){
      logService.addLog(#Info, "[matchProposalsWithMessages] latestNNSMessageIndex is null", null);
      check := false;
    };


    var end = start - FIND_PROPOSALS_BATCH_SIZE;
    if (end <= Option.get(latestNNSMessageIndex, end - 1)){
      end := Option.get(latestNNSMessageIndex, Nat32.fromNat(0)) + 1;
      check := false;
      logService.addLog(#Info, "[matchProposalsWithMessages] reached end", null);
    };

    logService.addLog(#Info, "[matchProposalsWithMessages]start: " #  Nat32.toText(start) # " end: " # Nat32.toText(end), null);
    //generate ranges for message indexes to fetch
    let indexVec = Iter.range(Nat32.toNat(end), Nat32.toNat(start)) |> 
                      Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
                        Iter.toArray(_);
  
    start := end;

    let #ok(res) = await* botService.getGroupMessagesByIndex(groupId, indexVec, null)
    else {
      //Error retrieving messages
      logService.addLog(#Error, "Error retrieving messages", null);
      continue attempts;
    };
      
    let tempMap = Map.new<Nat, OC.MessageIndex>();
    label messages for (message in Array.vals(res.messages)){ 
      let #ok(proposalData) = botService.getNNSProposalMessageData(message)
        else {
          //This shouldn't happen unless OC changes something
          logService.addLog(#Error, "error in getNNSProposalMessageData()", null);
          continue messages;
        };
        //logService.addLog(#Info, "Test");
        Map.set(tempMap, nhash, Nat64.toNat(proposalData.proposalId), proposalData.messageIndex);
    };

    var f = true;
    label process for ((k,v) in Map.entries(pending)){
        if (Option.isNull(v.messageIndex)){
          f := false;
        };
        switch(Map.get(tempMap, nhash, k)){
          case(?val){
            Map.set(pending, nhash, k, {v with messageIndex = ?val});
          };
          case(_){
            Map.set(pending, nhash, k, {v with attempts = v.attempts + 1});
          }
        }
      };
      //if all proposals have a message index, stop
      if(f){
        check := false;
      };
    };  

    latestNNSMessageIndex := ?index;
    #ok();
  };

  func createProposalThread(targetGroupId : Text, votingGroupId : Text, proposal : TT.ProposalAPI, messageIndex : ?Nat32) : async* (){
    //logService.addLog(#Info, "[createProposalThread] Creating proposal thread: " # Nat.toText(proposal.id) # " messageIndex: " # Nat32.toText(Option.get(messageIndex, Nat32.fromNat(0))));
    let text = TU.formatProposal(proposal);
    let #ok(res) = await* botService.sendTextGroupMessage(targetGroupId, text, null)
    else {
      logService.addLog(#Error, "Error sending message", ?"createProposalThread");
      return;
    };
    switch(res){
      case(#Success(d)){
        let text2 = TU.formatProposalThreadMsg(votingGroupId, proposal.id, messageIndex);
        let res = await* botService.sendTextGroupMessage(targetGroupId, text2, ?d.message_index);
      };
      case(_){};
    }
  };

  func createBatchThread(targetGroupId : Text, votingGroupId : Text, proposalList : [TT.ProposalAPI], proposalsLookup : T.ProposalsLookup) : async* (){
    let text = TU.formatProposals(proposalList);
    let #ok(res) = await* botService.sendTextGroupMessage(targetGroupId, text, null)
    else {
      logService.addLog(#Error, "Error sending message", ?"createProposalThread");
      return;
    };
    switch(res){
      case(#Success(d)){
        let text2 = TU.formatBatchProposalThreadMsg(votingGroupId, proposalList, proposalsLookup);
        let res = await* botService.sendTextGroupMessage(targetGroupId, text2, ?d.message_index);
      };
      case(_){};
    }
  };


  //////////////////////////
  ////////////////// TEST ENDPOINTS
  //////////////////////////

    public func testSetLastProposalId(proposalId : Nat) : async () {
    lastProposalId := ?proposalId;
  };

  public func testGetLastProposalId() : async ?Nat {
    lastProposalId
  };

  public func testGetPendingList() : async ([TT.ProposalAPI], Nat, Nat){
    (List.toArray(pendingSCMList), numberOfTicksSinceUpdate, List.size(pendingSCMList))
  };

  public func testClearPendingList() : async (){
    pendingSCMList := List.nil<TT.ProposalAPI>();
  };

  public func testGetProposalsLookup() : async [(Nat, {proposalData : TT.ProposalAPI; messageIndex : ?Nat32; attempts : Nat})] {
    Map.toArray(proposalsLookup);
  };

  public func testClearProposalsLookup() : async (){
    Map.clear(proposalsLookup);
  };

  public func testGetLatestNNSMessageIndex() : async?Nat32{
    latestNNSMessageIndex;
  };

  public func testSetLatestNNSMessageIndex(index :?Nat32) : async (){
    latestNNSMessageIndex := index;
  };

  public func testResetState() : async (){
    pendingSCMList := List.nil<TT.ProposalAPI>();
    Map.clear(proposalsLookup);
    latestNNSMessageIndex := null;
  };

  ////////////////// OC API
  public shared({caller}) func joinTestGroup() : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    await* botService.joinGroup(TEST_GROUP_ID, null);
  };

  public shared({caller}) func testJoinGroup(groupCanisterId : T.TextPrincipal) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };
    await* botService.joinGroup(groupCanisterId, null);
  };

  public shared({caller}) func testSendMessage(content : Text) : async Result.Result<T.SendMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let #ok(res) = await* botService.sendTextGroupMessage(TEST_GROUP_ID, content, null)
    else {
     return #err("Error sending message");
    };
    #ok(res)
  };

  public shared({caller}) func testSendMessageThread(content : Text, threadIndexId : Nat32) : async Result.Result<T.SendMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let #ok(res) = await* botService.sendTextGroupMessage(TEST_GROUP_ID, content, ?threadIndexId)
    else {
      return #err("Error sending message in thread");
    };
    #ok(res)
  };

  public shared({caller}) func testEditMessage(messageId : Nat, newContent : Text) : async Result.Result<OC.EditMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let #ok(res) = await*  botService.editTextGroupMessage(TEST_GROUP_ID, messageId, newContent)
    else{
      return #err("Error editing message");
    };
    #ok(res)
  };

  public shared({caller}) func testGetMessages(indexes : [Nat32]) : async Result.Result<OC.MessagesResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    await*  botService.getGroupMessagesByIndex(TEST_GROUP_ID, indexes, ?0);
  };

  public shared({caller}) func testGetNNSProposals(indexes : [Nat32]) : async Result.Result<OC.MessagesResponse, Text>{
    // if (not G.isCustodian(caller, custodians)) {
    //   return #err("Not authorized: " # Principal.toText(caller));
    // };

    await*  botService.getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexes, ?0);
  };

  public shared({caller}) func testGetProposalsGroupLastId() : async Result.Result<OC.MessageIndex, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };
    var index = switch(await* botService.getLatestGroupMessageIndex(NNS_PROPOSAL_GROUP_ID)){
      case(?index){index};
      case(_){return #err("Error")};
    };

    return #ok(index)
  };

  
  public func testRange(start: Int, end: Nat) : async Result.Result<([OC.MessageEventWrapper], [Nat32]), ()>{
    let indexVec = Iter.range(end, start) |> 
                      Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
                        Iter.toArray(_);

    let #ok(res) = await* botService.getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexVec, null)
    else {
      //Error retrieving messages
      logService.addLog(#Error, "[testRange] Error retrieving messages", null);
      return #err();
    };

    #ok((res.messages, indexVec))
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

  public func clearLogs() : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    logService.clearLogs();
    #ok()
  };

};


  // let messageRange : Nat32 = 10;
  // // Attempt to send messages for new proposals and register the corresponding message ID in the associative map.
  // // To keep payload size at a minimum it retrieves 10 messages at a time for a max of maxRetries.
  // func trySendMessages( tallies : [T.TallyData]) : async* Result.Result<Text, Text> {

  //   var index = switch(await* getLatestMessageIndex(NNS_PROPOSAL_GROUP_ID)){
  //     case(?index){index};
  //     case(_){return #err("Error")};
  //   };

  //   var _tallies = tallies;

  //   //TODO: consider compromising cross canister calls with increased payload size
  //   var maxRetries = 3;
  //   label attempts while (maxRetries > 0){
  //     maxRetries := maxRetries - 1;

  //     //generate ranges for message indexes to fetch
  //     let indexVec = Iter.range(Nat32.toNat(index) - Nat32.toNat(messageRange) , Nat32.toNat(index)) |> 
  //                       Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
  //                         Iter.toArray(_);
    

  //     let #ok(res) = await* getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexVec, null)
  //     else {
  //       //Error retrieving messages
  //       continue attempts;
  //     };

  //     label messages for (message in res.messages.vals()){ 
  //       let #ok(proposalData) = getNNSProposalMessageData(message)
  //       else {
  //          //This shouldn't happen unless OC changes something
  //          //TODO: log
  //          continue messages;
  //       };
  //       let exists = Array.find<T.TallyData>(_tallies, func (t : T.TallyData) : Bool {
  //         return proposalData.proposalId == t.proposalId;
  //       });


  //       let tally = switch(exists){
  //         case(?t){t};
  //         case(_){
  //           continue messages;
  //         };
  //       };

  //       var group_id = NNS_PROPOSAL_GROUP_ID;
  //       if (TEST_MODE){group_id := TEST_GROUP_ID};

  //       var messageIndex = ?proposalData.messageIndex;

  //       if(TEST_MODE){messageIndex := null};

  //       let res = await* sendTextMessageToGroup(group_id, TU.formatMessage(tally), messageIndex);

  //       switch (res){
  //         case(#Success(msgData)){
  //           //remove from tallies
  //           _tallies := Array.filter(_tallies, func(n : T.TallyData) : Bool {
  //             return n.proposalId != tally.proposalId;
  //           });

  //           //handle edge case where a proposal is settled on the first send, it won;t be updated so there is no need to add to the map
  //           switch(tally.proposalStatus){
  //             case(#Pending){
  //               //Dont save to hashmap in testmode for now
  //               if(not TEST_MODE){
  //                 Map.set(activeProposals, n64hash, proposalData.proposalId, msgData.message_id);
  //               }
  //             };
  //             case(_){};
  //           }
  //         };
  //         case(_){ //TODO: log error
  //         };
  //       };
  //     };

  //     index := index - messageRange;
  //     //return early if all tallies are matched
  //     if ((Array.size(_tallies) == 0)){
  //       return #ok("Tallies updated 2");
  //     };
  //   };

  //   var notFound = "";
  //   for(i in _tallies.vals()){
  //     notFound := notFound # Nat64.toText(i.proposalId) # " ";
  //   };

  //   //TODO: log unmatched proposal ids
  //    return #err("Max retries reached: Proposals not found: " # notFound);
  // };


  //TODO: remove
  //////////////////////////
  ////////////////// TALLIES
  //////////////////////////

  // public shared({caller}) func updateTallies(tallies : [T.TallyData]) : async Result.Result<Text, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized: " # Principal.toText(caller));
  //   };

  //   var _tallies = tallies;
  //   label it for (tally in tallies.vals()){
  //     let p = switch(Map.get(activeProposals, n64hash, tally.proposalId)){
  //       case(?p){p};
  //       case(_){ continue it; };
  //     };
  //     // edit message
  //     let res = await* editTextGroupMessage(NNS_PROPOSAL_GROUP_ID, p, TU.formatMessage(tally));
  //     //TODO: log edit errors
  //     // if proposal is over, remove from map
  //     switch (tally.tallyStatus, tally.proposalStatus){
  //       //TODO: reconsider after polling canister design
  //       case((#Approved or #Rejected), #Executed(verdict)){
  //         Map.delete(activeProposals, n64hash, tally.proposalId);
  //       };
  //       case(_){};
  //     };

  //     // Remove updated tallies
  //     _tallies := Array.filter(_tallies, func(n : T.TallyData) : Bool {
  //       return n.proposalId != tally.proposalId;
  //     });
  //   };

  //   //at least one proposal is new
  //   if (Array.size(_tallies) > 0){
  //     return await* trySendMessages(_tallies);
  //   };
  //   return #ok("Tallies updated 1");
  // };


  // public shared({caller}) func test() : async Result.Result<Text, Text>{
  //   let mock = F.basicMockData();
  //   return await updateTallies(mock);
  // };

  // public shared({caller}) func test2() : async Result.Result<Text, Text>{
  //   let mock = F.wrongMockData();
  //   return await updateTallies(mock);
  // };

  // public shared({caller}) func testGetNeuron(id : Nat64) : async GT.ListNeuronsResponse{
  //   let gs = GS.GovernanceService(GOVERNANCE_ID);
  //   return await* gs.listNeurons({
  //               neuron_ids = [id];
  //               include_neurons_readable_by_caller = false;
  //           });
  // };

  // public shared({caller}) func testGetNeuronVote(id : Nat64, proposalId : OC.ProposalId) : async ({#Approved; #Rejected; #Unspecified}, Nat64, Nat64){
  //   let gs = GS.GovernanceService(GOVERNANCE_ID);
  //   return await* gs.getVoteStatus(id, proposalId);
  // };


  
  // public shared({caller}) func initBot<system>(name : Text, displayName : ?Text) : async Result.Result<Text, Text>{
  //   if (not G.isCustodian(caller, custodians)) {
  //     return #err("Not authorized");
  //   };

  //   switch(botStatus){
  //     case(#NotInitialized){
  //       botStatus := #Initializing;

  //       Cycles.add<system>(BOT_REGISTRATION_FEE);
  //       let user_index : OC.UserIndexCanister = actor (USER_INDEX_CANISTER);
  //       try{
  //         let res = await user_index.c2c_register_bot({username= name; display_name= displayName});

  //         switch (res){
  //           case (#Success or #AlreadyRegistered){

  //             botStatus := #Initialized;
  //             botName := name;
  //             botDisplayName := displayName;
  //             return #ok("Initialized");
  //           };
  //           case (#InsufficientCyclesProvided(n)) {
  //             botStatus := #NotInitialized;
  //             return #err("Not enough cycles. Required: " # Nat.toText(n));
  //           };
  //           case(_){
  //             botStatus := #NotInitialized;
  //             return #err("Error")
  //           };
  //         };
  //         botStatus := #Initialized;
  //         return #ok("Initialized")
  //         } catch(e){
  //           botStatus := #NotInitialized;
  //           return #err("Trapped")
  //         }
  //     };
  //     case(#Initializing){
  //       return #err("Initializing")
  //     };
  //     case(#Initialized){
  //       return #err("Initialized")
  //     }
  //   }
  // };

  // func joinGroup(groupCanisterId : T.TextPrincipal, inviteCode : ?Nat64) : async* Result.Result<Text, Text>{

  //   let indexCanister = await* lookupLocalUserIndex(groupCanisterId);

  //   switch(indexCanister){
  //     case(#ok(id)){
  //       let localIndexCanister : OC.LocalUserIndexCanister = actor (Principal.toText(id));
  //       let res = await localIndexCanister.join_group({ chat_id= Principal.fromText(groupCanisterId); invite_code= inviteCode; correlation_id =  0});
  //       switch(res){
  //         case(#Success(_)){
  //           groups := List.push(Principal.fromText(groupCanisterId), groups);
  //           #ok("OK")
  //         };
  //         case(#AlreadyInGroup or #AlreadyInGroupV2(_)){
  //           #err("Already in group")
  //         };
  //         case(_){
  //           #err("Error")
  //         }
  //       }
  //     };
  //      case (#err(response)){
  //       return #err("Lookup error");
  //     }
  //   }
  // };

  // func lookupLocalUserIndex(group: T.TextPrincipal) : async* Result.Result<Principal, OC.GroupLookupResponse> {
  //   let group_canister : OC.GroupIndexCanister = actor (group);
  //   let res = await group_canister.public_summary({ invite_code = null});

  //   switch(res){
  //     case (#Success(response)){
  //       #ok(response.summary.local_user_index_canister_id)
  //     };
  //     case (#NotAuthorized(_)){
  //       #err(#GroupNotFound)
  //     };
  //   }
  // };


  // func sendMessageToGroup(groupCanisterId : T.TextPrincipal, content : OC.MessageContentInitial, threadIndexId : ?Nat32) : async* T.SendMessageResponse{
  //     let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
  //     lastMessageID := lastMessageID + 1;
  //     let msgIdCls = lastMessageID;
  //     let res = await group_canister.send_message_v2({
  //       message_id = lastMessageID;
  //       thread_root_message_index = threadIndexId;
  //       content = content;
  //       sender_name = botName;
  //       sender_display_name = botDisplayName;
  //       replies_to =  null;
  //       mentioned = [];
  //       forwarding = false;
  //       rules_accepted=  null;
  //       message_filter_failed = null;
  //       correlation_id= 0;
  //       block_level_markdown = false;
  //     });
  //     switch(res){
  //       case(#Success(response)){
  //         #Success({ response with message_id = msgIdCls;})
  //       };
  //       case(#ChannelNotFound){
  //         #ChannelNotFound
  //       };
  //       case(#ThreadMessageNotFound){
  //         #ThreadMessageNotFound
  //       };
  //       case(#MessageEmpty){
  //         #MessageEmpty
  //       };
  //       case(#TextTooLong(n)){
  //         #TextTooLong(n)
  //       };
  //       case(#InvalidPoll(reason)){
  //         #InvalidPoll(reason) 
  //       };
  //       case(#NotAuthorized){
  //         #NotAuthorized
  //       };
  //       case(#UserNotInCommunity){
  //         #UserNotInCommunity
  //       };
  //       case(#UserNotInChannel){
  //         #UserNotInChannel
  //       };
  //       case(#UserSuspended){
  //         #UserSuspended
  //       };
  //       case(#InvalidRequest(reason)){
  //         #InvalidRequest(reason)
  //       };
  //       case(#CommunityFrozen){
  //         #CommunityFrozen
  //       };
  //       case(#RulesNotAccepted){
  //         #RulesNotAccepted
  //       };
  //       case(#CommunityRulesNotAccepted){
  //         #CommunityRulesNotAccepted
  //       };

  //     };
  // };

  // func sendTextMessageToGroup(groupCanisterId : T.TextPrincipal, content : Text, threadIndexId : ?Nat32) : async* T.SendMessageResponse{
  //   await* sendMessageToGroup(groupCanisterId, #Text({text = content}), threadIndexId);
  // };

  // func editGroupMessage(groupCanisterId : T.TextPrincipal, messageId : OC.MessageId, newContent : OC.MessageContentInitial) : async* OC.EditMessageResponse{
  //     let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
  //     let res = await group_canister.edit_message_v2({
  //       message_id = messageId;
  //       thread_root_message_index = null;
  //       content = newContent;
  //       correlation_id= 0;
  //     });

  //    res
  // };

  // func editTextGroupMessage(groupCanisterId : T.TextPrincipal, messageId : OC.MessageId, newContent : Text) : async* OC.EditMessageResponse{
  //   await* editGroupMessage(groupCanisterId, messageId, #Text({text = newContent}));
  // };

  // func getGroupMessagesByIndex(groupCanisterId : T.TextPrincipal, indexes : [Nat32] ,latest_known_update : ?Nat64) : async* Result.Result<OC.MessagesResponse, Text> {
  //   let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
  //   let res = await group_canister.messages_by_message_index({
  //     thread_root_message_index = null;
  //     messages = indexes;
  //     latest_known_update = latest_known_update;
  //   });

  //   switch(res){
  //     case(#Success(val)){
  //       #ok(val);
  //     };
  //     case(_){
  //       return #err("Error")
  //     };
  //   }
  // };

  // func getNNSProposalMessageData(message : OC.MessageEventWrapper) : Result.Result<{proposalId : OC.ProposalId; messageIndex : OC.MessageIndex}, Text>{
  //   let event = message.event;
  //   switch(event.content){
  //     case(#GovernanceProposal(p)){
  //       switch(p.proposal){
  //         case(#NNS(proposal)){
  //           return #ok({
  //             proposalId = proposal.id;
  //             messageIndex = event.message_index;
  //           })
  //         };
  //         case(#SNS(_)){
  //           return #err("Not a NNS proposal");
  //         };
  //       }
  //     };
  //     case(_){
  //       return #err("Not a governance proposal");
  //     }
  //   }
  // };

  // func getLatestMessageIndex(groupCanisterId : T.TextPrincipal) : async* ?OC.MessageIndex{
  //   let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
  //   let res = await group_canister.public_summary({
  //     invite_code = null;
  //     correlation_id = 0;
  //   });

  //   switch(res){
  //     case(#Success(val)){
  //       return val.summary.latest_message_index;
  //     };
  //     case(_){
  //       return null;
  //     };
  //   };
  // };