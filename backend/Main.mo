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
import Map "mo:map/Map";
import T "./Types";
import TU "./TextUtils";
import G "./Guards";
import OC "./OCTypes";
import MT "./MetricTypes";
import F "./Fixtures";
import TT "./TrackerTypes";

shared ({ caller }) actor class OCBot() = Self {

  //TODOs:
  // set avatar

  let TEST_MODE = true;

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
  stable var activeProposals2 = Map.new<OC.ProposalId, Map.Map<T.TextPrincipal, OC.MessageId>>();
  stable var botStatus : T.BotStatus = #NotInitialized;
  stable var botName : Text = "";
  stable var botDisplayName : ?Text = null;
  stable var lastMessageID : Nat = 0; //TODO: reconsider
  stable var latestProposalID = 0;

  stable var lastProposalId : ?Nat = null;
  stable var activeProposalMessages= Map.new<Nat, OC.MessageId>();
  stable var timerId :?Nat = null;

  stable var pendingSCMList = List.nil<TT.ProposalAPI>();
  stable var lastSCMListUpdate  : ?Time.Time = null;
  stable var latestNNSMessageIndex : ?Nat = null;
  let MAX_SCM_WAIT_FOR_QUIET = 10 * 60 * 1000; // 10 minutes
  type Testmap = Map.Map<Nat, (TT.ProposalAPI, Nat)>;
  stable let testmap : Testmap = Map.new<Nat, (TT.ProposalAPI, Nat)>();

  let BATCH_SIZE = 50;

  func topicIdToVariant(topic : Int32) : {#RVM; #SCM; #OTHER}{
    switch(topic){
      case(8){
        return #SCM;
      };
      case(13){
        return #RVM;
      };
      case(_){
        return #OTHER;
      }
    }
  };


  public func initTimer<system>(_tickrate : ?Nat) : async Result.Result<(), Text> {
            
    let tickrate : Nat = Option.get(_tickrate, 5 * 60 * 1000);
    switch(timerId){
        case(?t){ return #err("Timer already created")};
        case(_){};
    };

    timerId := ?Timer.recurringTimer<system>(#seconds(tickrate), func() : async () {
      await updateGroup(null);
    });

    return #ok()
  };

  // func matchProposalsWithMessages(groupId : Text, pendingList : Testmap) : async* Result.Result<(), Text>{
  //   var index = switch(await* getLatestMessageIndex(NNS_PROPOSAL_GROUP_ID)){
  //     case(?index){index};
  //     case(_){return #err("Error")};
  //   };

  //   var current = index;
  //   label attempts while (Nat32.toNat(current) > Option.get(latestNNSMessageIndex, 0) +  BATCH_SIZE ){
  //     //generate ranges for message indexes to fetch
  //     let end = do {
  //       if(Option.get(latestNNSMessageIndex, 0) + BATCH_SIZE  > Nat32.toNat(current)){
  //         Option.get(latestNNSMessageIndex, 0);
  //       } else {
  //         current := current - Nat32.fromNat(BATCH_SIZE);
  //         Nat32.toNat(current)
  //       };
  //     };

  //     let indexVec = Iter.range(Nat32.toNat(current), end) |> 
  //                       Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
  //                         Iter.toArray(_);
    
  //     current := current - Nat32.fromNat(BATCH_SIZE);

  //     let #ok(res) = await* getGroupMessagesByIndex(NNS_PROPOSAL_GROUP_ID, indexVec, null)
  //     else {
  //       //Error retrieving messages
  //       continue attempts;
  //     };


  //      label process for ((k,v ) in Map.entries(testmap)){
          
  //       };

  //     label messages for (message in res.messages.vals()){ 
  //       let #ok(proposalData) = getNNSProposalMessageData(message)
  //       else {
  //          //This shouldn't happen unless OC changes something
  //          //TODO: log
  //          continue messages;
  //       };



  //     };
  //   };

  //   #ok();
  // };

  public func testContains(text : Text) : async Bool {
    return TU.isSeparateBuildProcess(text);
  };

  public func testSetLastProposalId(proposalId : Nat) : async () {
    lastProposalId := ?proposalId;
  };

  stable var breakDebug = false;

  public func testBreak() : async () {
    breakDebug:= true;
  };


  func checkBreak() : Bool {
    if (breakDebug){
      breakDebug:= false;
      return true
    };
    return false;
  };

  public func updateGroup(_start : ?Nat) : async () {
    let tracker : TT.Tracker = actor ("vkqwa-eqaaa-aaaap-qhira-cai");
    var start = lastProposalId;
    if (Option.isSome(_start)){
      start := _start;
    };

    let res = await tracker.getProposals(GOVERNANCE_ID, start, [8]);
    switch(res){
      case(#ok(data)){
          // for(proposal in Array.vals(data)){
          //   Map.set(test, proposal.id, (proposal, 0));
          // };

          for(proposal in Array.vals(data)){
            if (checkBreak()){
              return;
            };
            switch(topicIdToVariant(proposal.topicId)){
              case(#RVM){
                await* createProposalThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, proposal);
              };
              case(#SCM){
                if(TU.isSeparateBuildProcess(proposal.title)){
                  await* createProposalThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, proposal);  
                } else {
                    pendingSCMList := List.push(proposal, pendingSCMList);
                    lastSCMListUpdate := ?Time.now();
                };

              };
              case(_){};
            };

            if(proposal.id > Option.get(lastProposalId, 0)){
              lastProposalId := ?proposal.id;
            };
        };
      };
      case(#err(e)){
        switch(e){
          case(#InvalidProposalId(d)){
            lastProposalId := ?d.start;
            //await updateGroup();
          };
          case(_){};
        }
      };
    };

    if((List.size(pendingSCMList) > 0 and Time.now() - MAX_SCM_WAIT_FOR_QUIET > Option.get(lastSCMListUpdate, Time.now()))){
      let arr = List.toArray(pendingSCMList);
      await* createBatchThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, arr);
      pendingSCMList := List.nil<TT.ProposalAPI>();
    } else if (List.size(pendingSCMList) > 10){
        let chunks = List.chunks(10, pendingSCMList);
       for(chunk in List.toIter(chunks)){
        await* createBatchThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, List.toArray(chunk));
       };
        pendingSCMList := List.nil<TT.ProposalAPI>();
    }
  };

  func createProposalThread(targetGroupId : Text, votingGroupId : Text, proposal : TT.ProposalAPI) : async* (){
    let text = TU.formatProposal(proposal);
    let res = await* sendTextMessageToGroup(targetGroupId, text, null);
    switch(res){
      case(#Success(d)){
        let text2 = TU.formatProposalThreadMsg(votingGroupId, proposal.id, null);
        let res = await* sendTextMessageToGroup(targetGroupId, text2, ?d.message_index);
      };
      case(_){};
    }
  };

  func createBatchThread(targetGroupId : Text, votingGroupId : Text, proposalList : [TT.ProposalAPI]) : async* (){
    let text = TU.formatProposals(proposalList);
    let res = await* sendTextMessageToGroup(targetGroupId, text, null);
    switch(res){
      case(#Success(d)){
        let text2 = TU.formatBatchProposalThreadMsg(votingGroupId, proposalList);
        let res = await* sendTextMessageToGroup(targetGroupId, text2, ?d.message_index);
      };
      case(_){};
    }
  };

  public shared({caller}) func initBot(name : Text, displayName : ?Text) : async Result.Result<Text, Text>{
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized");
    };

    switch(botStatus){
      case(#NotInitialized){
        botStatus := #Initializing;

        Cycles.add(BOT_REGISTRATION_FEE);
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
    if (not G.isCustodian(caller, custodians)) {
      return #err("Not authorized: " # Principal.toText(caller));
    };

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
