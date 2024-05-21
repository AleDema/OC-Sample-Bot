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
import LS "./LogService";

shared ({ caller }) actor class OCBot() = Self {

  //TODOs:
  // set avatar

  let TEST_MODE = true;

  let FIND_PROPOSALS_BATCH_SIZE : Nat32 = 100;
  let PENDING_SCM_LIMIT = 10;
  let MAX_TICKS_WITHOUT_UPDATE = 3;

  let USER_INDEX_CANISTER = "4bkt6-4aaaa-aaaaf-aaaiq-cai";
  let LOCAL_USER_INDEX_ID = "nq4qv-wqaaa-aaaaf-bhdgq-cai";
  let GROUP_INDEX_ID = "4ijyc-kiaaa-aaaaf-aaaja-cai";
  let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";
  let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
  let GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";
  let BOT_REGISTRATION_FEE: Nat = 10_000_000_000_000; // 10T

  let { nhash; n64hash; n32hash } = Map;

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

  system func postupgrade() {
    if(Option.isSome(timerId)){
      timerId := ?Timer.recurringTimer<system>(#seconds(5* 6), func() : async () {
        await updateGroup(lastProposalId);
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

  public func testSetLastProposalId(proposalId : Nat) : async () {
    lastProposalId := ?proposalId;
  };

  public func testGetLastProposalId() : async ?Nat {
    lastProposalId
  };

  public func getPendignList() : async ([TT.ProposalAPI], Nat, Nat){
    (List.toArray(pendingSCMList), numberOfTicksSinceUpdate, List.size(pendingSCMList))
  };

  public func clearPendingList() : async (){
    pendingSCMList := List.nil<TT.ProposalAPI>();
  };

  public func getProposalsLookup() : async [(Nat, {proposalData : TT.ProposalAPI; messageIndex : ?Nat32; attempts : Nat})] {
    Map.toArray(proposalsLookup);
  };

  public func clearProposalsLookup() : async (){
    Map.clear(proposalsLookup);
  };
  

  public func updateGroup(start : ?Nat) : async () {
    logService.log(#Info, "Running update");
    let tracker : TT.Tracker = actor ("vkqwa-eqaaa-aaaap-qhira-cai");

    numberOfTicksSinceUpdate := numberOfTicksSinceUpdate + 1;
    logService.log(#Info, "Number of ticks since last update: " # Nat.toText(numberOfTicksSinceUpdate));
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
            logService.log(#Info, "InvalidProposalId, set last proposal id to: " # Nat.toText(d.end + 1));
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
              pendingSCMList := List.push(proposal.proposalData, pendingSCMList);
              //lastSCMListUpdate := ?Time.now();
              numberOfTicksSinceUpdate := 0;
              logService.log(#Info, "Pushing to list");
          };

        };
        case(_){};
      };

      if(proposal.proposalData.id > Option.get(lastProposalId, 0)){
        lastProposalId := ?(proposal.proposalData.id + 1); //TODO; remove temp fix until poll service is fixed
      };
    };

    if((List.size(pendingSCMList) > 0 and List.size(pendingSCMList) < PENDING_SCM_LIMIT and numberOfTicksSinceUpdate > MAX_TICKS_WITHOUT_UPDATE)){
      logService.log(#Info, "Sending pending list cause wait for quiet expired");
      let arr = List.toArray(pendingSCMList);
      await* createBatchThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, arr, proposalsLookup);
      for (p in Array.vals(arr) ){
        Map.delete(proposalsLookup, nhash, p.id);
      };
      pendingSCMList := List.nil<TT.ProposalAPI>();
    } else if (List.size(pendingSCMList) > PENDING_SCM_LIMIT){
        logService.log(#Info, "Sending pending list cause too may entries");
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

    logService.log(#Info, "Finished update");
  };

  func matchProposalsWithMessages(groupId : Text, pending : T.ProposalsLookup) : async* Result.Result<(), Text>{
    //map is empty, nothing to match
    if(Map.size(pending) == 0){
      logService.log(#Info, "[matchProposalsWithMessages] Map empty");
      return #ok();
    };

    var index = switch(await* getLatestMessageIndex(groupId)){
      case(?index){index};
      case(_){
         logService.log(#Info, "[matchProposalsWithMessages] getLatestMessageIndex error");
        return #err("Error")};
    };

    //if the index is the same as the latest message index, nothing to match
    if(index == Option.get(latestNNSMessageIndex, index + 1)){
      logService.log(#Info, "[matchProposalsWithMessages] up to date");
      return #ok();
    };


    var start = index;
    var check = true;
    label attempts while (check){

      //if latestNNSMessageIndex is null, get last BATCH_SIZE once
      if(Option.isNull(latestNNSMessageIndex)){
        logService.log(#Info, "[matchProposalsWithMessages] latestNNSMessageIndex is null");
        check := false;
      };


      var end = start - FIND_PROPOSALS_BATCH_SIZE;
      if (end <= Option.get(latestNNSMessageIndex, end - 1)){
        end := Option.get(latestNNSMessageIndex, Nat32.fromNat(0)) + 1;
        check := false;
        logService.log(#Info, "[matchProposalsWithMessages] reached end");
      };

      logService.log(#Info, "[matchProposalsWithMessages]start: " #  Nat32.toText(start) # " end: " # Nat32.toText(end));
      //generate ranges for message indexes to fetch
      let indexVec = Iter.range(Nat32.toNat(end), Nat32.toNat(start)) |> 
                        Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
                          Iter.toArray(_);
    
      start := end;

      let #ok(res) = await* getGroupMessagesByIndex(groupId, indexVec, null)
      else {
        //Error retrieving messages
        logService.log(#Error, "Error retrieving messages");
        continue attempts;
      };
      
      let tempMap = Map.new<Nat, OC.MessageIndex>();
      label messages for (message in Array.vals(res.messages)){ 
        let #ok(proposalData) = getNNSProposalMessageData(message)
          else {
            //This shouldn't happen unless OC changes something
            logService.log(#Error, "error in getNNSProposalMessageData()");
            continue messages;
          };
          //logService.log(#Info, "Test");
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

  public func testRange(start: Int, end: Nat) : async Result.Result<([OC.MessageEventWrapper], [Nat32]), ()>{
    let indexVec = Iter.range(end, start) |> 
                      Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
                        Iter.toArray(_);

    let #ok(res) = await* getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexVec, null)
    else {
      //Error retrieving messages
      logService.log(#Error, "[testRange] Error retrieving messages");
      return #err();
    };

    #ok((res.messages, indexVec))

  };

  public func getLatestNNSMessageIndex() : async?Nat32{
    latestNNSMessageIndex;
  };

  public func setLatestNNSMessageIndex(index :?Nat32) : async (){
    latestNNSMessageIndex := index;
  };

  func createProposalThread(targetGroupId : Text, votingGroupId : Text, proposal : TT.ProposalAPI, messageIndex : ?Nat32) : async* (){
    //logService.log(#Info, "[createProposalThread] Creating proposal thread: " # Nat.toText(proposal.id) # " messageIndex: " # Nat32.toText(Option.get(messageIndex, Nat32.fromNat(0))));
    let text = TU.formatProposal(proposal);
    let res = await* sendTextMessageToGroup(targetGroupId, text, null);
    switch(res){
      case(#Success(d)){
        let text2 = TU.formatProposalThreadMsg(votingGroupId, proposal.id, messageIndex);
        let res = await* sendTextMessageToGroup(targetGroupId, text2, ?d.message_index);
      };
      case(_){};
    }
  };

  func createBatchThread(targetGroupId : Text, votingGroupId : Text, proposalList : [TT.ProposalAPI], proposalsLookup : T.ProposalsLookup) : async* (){
    let text = TU.formatProposals(proposalList);
    let res = await* sendTextMessageToGroup(targetGroupId, text, null);
    switch(res){
      case(#Success(d)){
        let text2 = TU.formatBatchProposalThreadMsg(votingGroupId, proposalList, proposalsLookup);
        let res = await* sendTextMessageToGroup(targetGroupId, text2, ?d.message_index);
      };
      case(_){};
    }
  };

  public shared({caller}) func initBot<system>(name : Text, displayName : ?Text) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    switch(botStatus){
      case(#NotInitialized){
        botStatus := #Initializing;

        Cycles.add<system>(BOT_REGISTRATION_FEE);
        let user_index : OC.UserIndexCanister = actor (USER_INDEX_CANISTER);
        try{
          let res = await user_index.c2c_register_bot({username= name; display_name= displayName});

          switch (res){
            case (#Success or #AlreadyRegistered){

              botStatus := #Initialized;
              botName := name;
              botDisplayName := displayName;
              return #ok("Initialized");
            };
            case (#InsufficientCyclesProvided(n)) {
              botStatus := #NotInitialized;
              return #err("Not enough cycles. Required: " # Nat.toText(n));
            };
            case(_){
              botStatus := #NotInitialized;
              return #err("Error")
            };
          };
          botStatus := #Initialized;
          return #ok("Initialized")
          } catch(e){
            botStatus := #NotInitialized;
            return #err("Trapped")
          }
      };
      case(#Initializing){
        return #err("Initializing")
      };
      case(#Initialized){
        return #err("Initialized")
      }
    }
  };

  func joinGroup(groupCanisterId : T.TextPrincipal, inviteCode : ?Nat64) : async* Result.Result<Text, Text>{

    let indexCanister = await* lookupLocalUserIndex(groupCanisterId);

    switch(indexCanister){
      case(#ok(id)){
        let localIndexCanister : OC.LocalUserIndexCanister = actor (Principal.toText(id));
        let res = await localIndexCanister.join_group({ chat_id= Principal.fromText(groupCanisterId); invite_code= inviteCode; correlation_id =  0});
        switch(res){
          case(#Success(_)){
            groups := List.push(Principal.fromText(groupCanisterId), groups);
            #ok("OK")
          };
          case(#AlreadyInGroup or #AlreadyInGroupV2(_)){
            #err("Already in group")
          };
          case(_){
            #err("Error")
          }
        }
      };
       case (#err(response)){
        return #err("Lookup error");
      }
    }
  };

  func lookupLocalUserIndex(group: T.TextPrincipal) : async* Result.Result<Principal, OC.GroupLookupResponse> {
    let group_canister : OC.GroupIndexCanister = actor (group);
    let res = await group_canister.public_summary({ invite_code = null});

    switch(res){
      case (#Success(response)){
        #ok(response.summary.local_user_index_canister_id)
      };
      case (#NotAuthorized(_)){
        #err(#GroupNotFound)
      };
    }
  };


  func sendMessageToGroup(groupCanisterId : T.TextPrincipal, content : OC.MessageContentInitial, threadIndexId : ?Nat32) : async* T.SendMessageResponse{
      let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
      lastMessageID := lastMessageID + 1;
      let msgIdCls = lastMessageID;
      let res = await group_canister.send_message_v2({
        message_id = lastMessageID;
        thread_root_message_index = threadIndexId;
        content = content;
        sender_name = botName;
        sender_display_name = botDisplayName;
        replies_to =  null;
        mentioned = [];
        forwarding = false;
        rules_accepted=  null;
        message_filter_failed = null;
        correlation_id= 0;
        block_level_markdown = false;
      });
      switch(res){
        case(#Success(response)){
          #Success({ response with message_id = msgIdCls;})
        };
        case(#ChannelNotFound){
          #ChannelNotFound
        };
        case(#ThreadMessageNotFound){
          #ThreadMessageNotFound
        };
        case(#MessageEmpty){
          #MessageEmpty
        };
        case(#TextTooLong(n)){
          #TextTooLong(n)
        };
        case(#InvalidPoll(reason)){
          #InvalidPoll(reason) 
        };
        case(#NotAuthorized){
          #NotAuthorized
        };
        case(#UserNotInCommunity){
          #UserNotInCommunity
        };
        case(#UserNotInChannel){
          #UserNotInChannel
        };
        case(#UserSuspended){
          #UserSuspended
        };
        case(#InvalidRequest(reason)){
          #InvalidRequest(reason)
        };
        case(#CommunityFrozen){
          #CommunityFrozen
        };
        case(#RulesNotAccepted){
          #RulesNotAccepted
        };
        case(#CommunityRulesNotAccepted){
          #CommunityRulesNotAccepted
        };

      };
  };

  func sendTextMessageToGroup(groupCanisterId : T.TextPrincipal, content : Text, threadIndexId : ?Nat32) : async* T.SendMessageResponse{
    await* sendMessageToGroup(groupCanisterId, #Text({text = content}), threadIndexId);
  };

  func editGroupMessage(groupCanisterId : T.TextPrincipal, messageId : OC.MessageId, newContent : OC.MessageContentInitial) : async* OC.EditMessageResponse{
      let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
      let res = await group_canister.edit_message_v2({
        message_id = messageId;
        thread_root_message_index = null;
        content = newContent;
        correlation_id= 0;
      });

     res
  };

  func editTextGroupMessage(groupCanisterId : T.TextPrincipal, messageId : OC.MessageId, newContent : Text) : async* OC.EditMessageResponse{
    await* editGroupMessage(groupCanisterId, messageId, #Text({text = newContent}));
  };

  func getGroupMessagesByIndex(groupCanisterId : T.TextPrincipal, indexes : [Nat32] ,latest_known_update : ?Nat64) : async* Result.Result<OC.MessagesResponse, Text> {
    let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
    let res = await group_canister.messages_by_message_index({
      thread_root_message_index = null;
      messages = indexes;
      latest_known_update = latest_known_update;
    });

    switch(res){
      case(#Success(val)){
        #ok(val);
      };
      case(_){
        return #err("Error")
      };
    }
  };

  func getNNSProposalMessageData(message : OC.MessageEventWrapper) : Result.Result<{proposalId : OC.ProposalId; messageIndex : OC.MessageIndex}, Text>{
    let event = message.event;
    switch(event.content){
      case(#GovernanceProposal(p)){
        switch(p.proposal){
          case(#NNS(proposal)){
            return #ok({
              proposalId = proposal.id;
              messageIndex = event.message_index;
            })
          };
          case(#SNS(_)){
            return #err("Not a NNS proposal");
          };
        }
      };
      case(_){
        return #err("Not a governance proposal");
      }
    }
  };

  func getLatestMessageIndex(groupCanisterId : T.TextPrincipal) : async* ?OC.MessageIndex{
    let group_canister : OC.GroupIndexCanister = actor (groupCanisterId);
    let res = await group_canister.public_summary({
      invite_code = null;
      correlation_id = 0;
    });

    switch(res){
      case(#Success(val)){
        return val.summary.latest_message_index;
      };
      case(_){
        return null;
      };
    };
  };


  let messageRange : Nat32 = 10;
  // Attempt to send messages for new proposals and register the corresponding message ID in the associative map.
  // To keep payload size at a minimum it retrieves 10 messages at a time for a max of maxRetries.
  func trySendMessages( tallies : [T.TallyData]) : async* Result.Result<Text, Text> {

    var index = switch(await* getLatestMessageIndex(NNS_PROPOSAL_GROUP_ID)){
      case(?index){index};
      case(_){return #err("Error")};
    };

    var _tallies = tallies;

    //TODO: consider compromising cross canister calls with increased payload size
    var maxRetries = 3;
    label attempts while (maxRetries > 0){
      maxRetries := maxRetries - 1;

      //generate ranges for message indexes to fetch
      let indexVec = Iter.range(Nat32.toNat(index) - Nat32.toNat(messageRange) , Nat32.toNat(index)) |> 
                        Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
                          Iter.toArray(_);
    

      let #ok(res) = await* getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexVec, null)
      else {
        //Error retrieving messages
        continue attempts;
      };

      label messages for (message in res.messages.vals()){ 
        let #ok(proposalData) = getNNSProposalMessageData(message)
        else {
           //This shouldn't happen unless OC changes something
           //TODO: log
           continue messages;
        };
        let exists = Array.find<T.TallyData>(_tallies, func (t : T.TallyData) : Bool {
          return proposalData.proposalId == t.proposalId;
        });


        let tally = switch(exists){
          case(?t){t};
          case(_){
            continue messages;
          };
        };

        var group_id = NNS_PROPOSAL_GROUP_ID;
        if (TEST_MODE){group_id := TEST_GROUP_ID};

        var messageIndex = ?proposalData.messageIndex;

        if(TEST_MODE){messageIndex := null};

        let res = await* sendTextMessageToGroup(group_id, TU.formatMessage(tally), messageIndex);

        switch (res){
          case(#Success(msgData)){
            //remove from tallies
            _tallies := Array.filter(_tallies, func(n : T.TallyData) : Bool {
              return n.proposalId != tally.proposalId;
            });

            //handle edge case where a proposal is settled on the first send, it won;t be updated so there is no need to add to the map
            switch(tally.proposalStatus){
              case(#Pending){
                //Dont save to hashmap in testmode for now
                if(not TEST_MODE){
                  Map.set(activeProposals, n64hash, proposalData.proposalId, msgData.message_id);
                }
              };
              case(_){};
            }
          };
          case(_){ //TODO: log error
          };
        };
      };

      index := index - messageRange;
      //return early if all tallies are matched
      if ((Array.size(_tallies) == 0)){
        return #ok("Tallies updated 2");
      };
    };

    var notFound = "";
    for(i in _tallies.vals()){
      notFound := notFound # Nat64.toText(i.proposalId) # " ";
    };

    //TODO: log unmatched proposal ids
     return #err("Max retries reached: Proposals not found: " # notFound);
  };

  public shared({caller}) func updateTallies(tallies : [T.TallyData]) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    var _tallies = tallies;
    label it for (tally in tallies.vals()){
      let p = switch(Map.get(activeProposals, n64hash, tally.proposalId)){
        case(?p){p};
        case(_){ continue it; };
      };
      // edit message
      let res = await* editTextGroupMessage(NNS_PROPOSAL_GROUP_ID, p, TU.formatMessage(tally));
      //TODO: log edit errors
      // if proposal is over, remove from map
      switch (tally.tallyStatus, tally.proposalStatus){
        //TODO: reconsider after polling canister design
        case((#Approved or #Rejected), #Executed(verdict)){
          Map.delete(activeProposals, n64hash, tally.proposalId);
        };
        case(_){};
      };

      // Remove updated tallies
      _tallies := Array.filter(_tallies, func(n : T.TallyData) : Bool {
        return n.proposalId != tally.proposalId;
      });
    };

    //at least one proposal is new
    if (Array.size(_tallies) > 0){
      return await* trySendMessages(_tallies);
    };
    return #ok("Tallies updated 1");
  };

  //TEST ENDPOINTS

  public shared({caller}) func test() : async Result.Result<Text, Text>{
    let mock = F.basicMockData();
    return await updateTallies(mock);
  };

  public shared({caller}) func test2() : async Result.Result<Text, Text>{
    let mock = F.wrongMockData();
    return await updateTallies(mock);
  };

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

  public shared({caller}) func joinTestGroup() : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    await* joinGroup(TEST_GROUP_ID, null);
  };

  public shared({caller}) func testJoinGroup(groupCanisterId : T.TextPrincipal) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };
    await* joinGroup(groupCanisterId, null);
  };

  public shared({caller}) func testSendMessage(content : Text) : async Result.Result<T.SendMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let res = await* sendTextMessageToGroup(TEST_GROUP_ID, content, null);
    #ok(res)
  };

  public shared({caller}) func testSendMessageThread(content : Text, threadIndexId : Nat32) : async Result.Result<T.SendMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let res = await* sendTextMessageToGroup(TEST_GROUP_ID, content, ?threadIndexId);
    #ok(res)
  };

  public shared({caller}) func testEditMessage(messageId : Nat, newContent : Text) : async Result.Result<OC.EditMessageResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    let res = await* editTextGroupMessage(TEST_GROUP_ID, messageId, newContent);
    #ok(res)
  };

  public shared({caller}) func testGetMessages(indexes : [Nat32]) : async Result.Result<OC.MessagesResponse, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

    await* getGroupMessagesByIndex(TEST_GROUP_ID, indexes, ?0);
  };

  public shared({caller}) func testGetNNSProposals(indexes : [Nat32]) : async Result.Result<OC.MessagesResponse, Text>{
    // if (not G.isCustodian(caller, custodians)) {
    //   return #err("Not authorized: " # Principal.toText(caller));
    // };

    await* getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexes, ?0);
  };

  public shared({caller}) func testGetProposalsGroupLastId() : async Result.Result<OC.MessageIndex, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };
    var index = switch(await* getLatestMessageIndex(NNS_PROPOSAL_GROUP_ID)){
      case(?index){index};
      case(_){return #err("Error")};
    };

    return #ok(index)
  };

  // ADMIN //
  public shared ({ caller }) func addCustodian(new_custodian : Principal) : async Result.Result<Text, Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    custodians := List.push(new_custodian, custodians);

    return #ok("Custodian Added");
  };

  //METRICS
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

  public func getLogs(height : ?Nat) : async [LS.Log] {
    logService.getLogs(height);
  };

  public func clearLogs(height : ?Nat) : async Result.Result<(), Text> {
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };
    logService.clearLogs(height);
    #ok()
  };

  //Waiting for OC support
  // public shared({caller}) func handle_direct_message_msgpack(data : HandleMessageArgs) : async Result.Result<Text, Text>{
  //   //TODO: validate caller

  //   let group_canister : T.GroupIndexCanister = actor (TEST_GROUP_ID);
  //   let res = await group_canister.messages_by_message_index(null, [], null);

  //   switch(res){
  //     case(#Success(val)){
  //       #ok(val.latest_event_index);
  //     };
  //     case(_){
  //       return #err("Error")
  //     };
  //   }
  // };

  // Not supported 
  // public func sendTestGovernanceMessage() : async T.SendMessageResponse{
  //     let group_canister : T.GroupIndexCanister = actor (TEST_GROUP_ID);
  //     let res = await group_canister.send_message_v2({
  //       message_id = lastMessageID; //TODO: save messageIDs for edits, 3453453
  //       thread_root_message_index = null;
  //       content = #GovernanceProposal({    
  //           my_vote = null;
  //           governance_canister_id =  Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
  //           proposal =
  //             #NNS({
  //                 id = 73327;
  //                 url =  "Text";
  //                 status =  #Open;
  //                 payload_text_rendering =  ?"Test";
  //                 tally =  {
  //                     no =  12;
  //                     yes =  12;
  //                     total =  24;
  //                     timestamp =  2222;
  //                   };
  //                 title =  "Test title";
  //                 created =  22;
  //                 topic =  5;
  //                 last_updated =  22;
  //                 deadline =  22;
  //                 reward_status =  #Settled;
  //                 summary =  "Text";
  //                 proposer =  222;
  //             });
  //         });
  //         sender_name = "test_bot";
  //       sender_display_name = null;
  //       replies_to =  null;
  //       mentioned = [];
  //       forwarding = false;
  //       rules_accepted=  null;
  //       message_filter_failed = null;
  //       correlation_id= 0;
  //     });
  //     lastMessageID := lastMessageID + 1;
  //     res
  // };
};
