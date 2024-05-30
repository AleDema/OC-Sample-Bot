import List "mo:base/List";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Map "mo:map/Map";
import TT "../TrackerTypes";
import BT "../OC/BotTypes";
import LT "../Log/LogTypes";
import {  nhash; n64hash; n32hash; thash } "mo:map/Map";
import TU "../TextUtils";
import OC "../OC/OCApi";
import T "../Types";
import PS "../Proposal/ProposalService";
import PM "../Proposal/ProposalMappings";
import GU "../Governance/GovernanceUtils";
import GT "../Governance/GovernanceTypes";
module{

    public type Proposal = {proposalData : TT.ProposalAPI; messageIndex : ?Nat32; attempts : Nat};

    public type ProposalsLookup = Map.Map<Nat, Proposal>;

    public type Subscriber = {
        #Group : {topics : [Int32]; groupCanister : Text;};
        #Channel : {topics : [Int32]; communityCanister : Text; channelId : Nat;};
    };


    public type ProposalBotModel = {
        var lastProposalId : ?Nat;
        var timerId :?Nat;
        var latestNNSMessageIndex : ?Nat32;
        proposalsLookup : ProposalsLookup;
        var numberOfTicksSinceUpdate : Nat;
        subscribers : Map.Map<Text, Subscriber>;
    };

    public type UpdateState = {
        #Running;
        #Stopped;
    };

    public func initModel() : ProposalBotModel{
        {
            var lastProposalId = null;
            var timerId = null;
            var latestNNSMessageIndex = null;
            proposalsLookup : ProposalsLookup = Map.new();
            var numberOfTicksSinceUpdate = 0;
            subscribers : Map.Map<Text, Subscriber> = Map.new();

        }
    };

    let FIND_PROPOSALS_BATCH_SIZE : Nat32 = 100;
    let PENDING_SCM_LIMIT = 10;
    let MAX_TICKS_WITHOUT_UPDATE = 3;

    let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";
    //let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
    let GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";
    //let VOTING_GROUP_ID = "6q22t-qaaaq-aaaaf-aaamq-cai";
    
    public class ProposalBot(model : ProposalBotModel, botService : BT.BotService, proposalService : PS.ProposalService, logService : LT.LogService) = {
        var updateState : UpdateState = #Stopped;
        public func initTimer<system>(_tickrateInSeconds : ?Nat) : async Result.Result<(), Text> {
                    
            let tickrate : Nat = Option.get(_tickrateInSeconds, 5* 60); // 5 minutes
            switch(model.timerId){
                case(?t){ return #err("Timer already created")};
                case(_){};
            };

            model.timerId := ?Timer.recurringTimer<system>(#seconds(tickrate), func() : async () {
                await update(model.lastProposalId);
            });

            return #ok()
        };

        public func cancelTimer() : async Result.Result<(), Text> {
            switch(model.timerId){
                case(?t){
                    Timer.cancelTimer(t);
                    model.timerId := null;
                    return #ok();
                };
                case(_){
                    return #err("No Timer to delete");
                }
            }
        };

        func updateInternalState(arg : Result.Result<GT.ListProposalInfoResponse, Text>) : () {
            switch(arg){
                case(#ok(proposals)){
                   // logService.logInfo("Array size: " # Nat.toText(Array.size(proposals.proposal_info)), null);
                    let mappedProps = PM.mapGetProposals(proposals.proposal_info);
                    //logService.logInfo("mappedProps size: " # Nat.toText(Array.size(mappedProps)), null);
                    for(proposal in Array.vals(mappedProps)){
                        //logService.logInfo("[Adding to map", null);
                        Map.set(model.proposalsLookup, nhash, proposal.id, { proposalData = PM.proposalToAPI(proposal); messageIndex = null; attempts = 0});

                        if(T.topicIdToVariant(proposal.topicId) == #SCM and (not TU.isSeparateBuildProcess(proposal.title) or Option.isNull(TU.extractGitHash(proposal.title, proposal.description)))){
                            if(Map.has(model.proposalsLookup, nhash, proposal.id)){
                               // model.pendingSCMList := List.push<TT.ProposalAPI>(PM.proposalToAPI(proposal), model.pendingSCMList);
                                model.numberOfTicksSinceUpdate := 0;
                                logService.addLog(#Info, "Pushing to list: " # Nat.toText(proposal.id), null);
                            } else {
                                logService.addLog(#Info, "Already in list" # Nat.toText(proposal.id), null);
                            };
                        };

                        if(proposal.id > Option.get(model.lastProposalId, 0) or Option.isNull(model.lastProposalId)){
                            model.lastProposalId := ?(proposal.id);
                        };
                    };
                };
                case(#err(e)){
                    logService.logError("listProposalsAfterd return err: " # e, null);
                };
            };
        };

        func getUpdateBatch() : ([Proposal], [Proposal], List.List<[Proposal]>) {
            var rvmList = List.nil<Proposal>();
            var scmList = List.nil<Proposal>();
            var scmBatchList = List.nil<[Proposal]>();
            var tmpMap : Map.Map<Text, List.List<Proposal>> = Map.new();

            for(proposal in Map.vals(model.proposalsLookup)){

                switch(T.topicIdToVariant(proposal.proposalData.topicId)){
                    case(#RVM){
                        if(Option.isSome(proposal.messageIndex) or proposal.attempts >= MAX_TICKS_WITHOUT_UPDATE){
                            rvmList := List.push(proposal, rvmList);
                            Map.delete(model.proposalsLookup, nhash, proposal.proposalData.id);
                        }
                    };
                    case(#SCM){
                        let proposalHash = TU.extractGitHash(proposal.proposalData.title, proposal.proposalData.description);
                        //logService.logInfo("Proposal ID: " # Nat.toText(proposal.proposalData.id) #  " has git hash: " # Option.get(proposalHash, "Null") # " Description: " # Option.get(proposal.proposalData.description, "null"), ?"[getUpdateBatch]");
                        if(TU.isSeparateBuildProcess(proposal.proposalData.title) or Option.isNull(proposalHash)){
                            if(Option.isSome(proposal.messageIndex) or proposal.attempts >= MAX_TICKS_WITHOUT_UPDATE){
                                scmList := List.push(proposal, scmList);
                                Map.delete(model.proposalsLookup, nhash, proposal.proposalData.id);
                            };
                        } else if(not TU.isSeparateBuildProcess(proposal.proposalData.title) and Option.isSome(proposalHash)){
                            let key = Option.get(proposalHash, "");
                            let newList = Option.get(Map.get(tmpMap, thash, key), List.nil<Proposal>());
                            Map.set(tmpMap, thash, key, List.push(proposal, newList));
                        };


                    };
                    case(_){};
                };
            };

            for((key, pList) in Map.entries(tmpMap)){
                if(List.size(pList) > 0 and List.size(pList) < PENDING_SCM_LIMIT and model.numberOfTicksSinceUpdate >= MAX_TICKS_WITHOUT_UPDATE){
                    logService.addLog(#Info, "Sending pending list cause wait for quiet expired", null);
                    scmBatchList := List.push(List.toArray(List.reverse(pList)), scmBatchList);
                    for (p in List.toIter(pList)){
                        Map.delete(model.proposalsLookup, nhash, p.proposalData.id);
                    };

                } else if (List.size(pList) > PENDING_SCM_LIMIT){
                    logService.addLog(#Info, "Sending pending list cause too may entries", null);
                    let chunks = List.chunks(PENDING_SCM_LIMIT, pList);
                    //filter chunks big enough
                    let l = List.filter(chunks, func(chunk : List.List<Proposal>) : Bool{
                        if(List.size(chunk) == PENDING_SCM_LIMIT){
                            for (p in List.toIter(chunk) ){
                                Map.delete(model.proposalsLookup, nhash, p.proposalData.id);
                            };
                            return true;
                        };
                        return false;
                    });

                    for(chunk in List.toIter(l)){
                        scmBatchList := List.push(List.toArray(List.reverse(chunk)), scmBatchList);
                    };
                };
            };

            return (List.toArray(List.reverse(rvmList)), List.toArray(List.reverse(scmList)), List.reverse(scmBatchList));

        };

        func sendMessages(rvmList : [Proposal], scmList : [Proposal], scmBatchList : List.List<[Proposal]>) : async* (){
            for(sub in Map.vals(model.subscribers)){
                switch(sub){
                    case(#Group(group)){
                        for(tid in group.topics.vals()){
                            switch(T.topicIdToVariant(tid)){
                                case(#RVM){
                                    for(p in rvmList.vals()){
                                        await* createProposalGroupThread(group.groupCanister, p)
                                    };
                                };
                              case(#SCM){
                                    for(p in scmList.vals()){
                                        await* createProposalGroupThread(group.groupCanister, p)
                                    };

                                    for(chunk in List.toIter(scmBatchList)){
                                        await* createBatchGroupThread(group.groupCanister, chunk)
                                    };

                                };
                              case(_){};
                            }
                        };

                    };
                    case(#Channel(channel)){
                        for(tid in channel.topics.vals()){
                            switch(T.topicIdToVariant(tid)){
                                case(#RVM){
                                    for(p in rvmList.vals()){
                                        await* createProposalChannelThread(channel.communityCanister, channel.channelId, p)
                                    };
                                };
                              case(#SCM){
                                for(p in scmList.vals()){
                                    await* createProposalChannelThread(channel.communityCanister, channel.channelId, p)
                                };

                                for(chunk in List.toIter(scmBatchList)){
                                    await* createBatchChannelThread(channel.communityCanister, channel.channelId, chunk)
                                };
                              };
                              case(_){};
                            }
                        };
                    };
                }
            };
        };

        public func update(after : ?Nat) : async () {
            if(updateState == #Running){
                logService.logWarn("Update already running", ?"[update]");
                return;
            };

            updateState:= #Running;
            model.numberOfTicksSinceUpdate := model.numberOfTicksSinceUpdate + 1;
            logService.addLog(#Info, "[Running update] Number of ticks since last update: " # Nat.toText(model.numberOfTicksSinceUpdate), null);
            
            let topics = PS.processIncludeTopics(GU.NNSFunctions,[8,13]);

            let res = await* proposalService.listProposalsAfterd(GOVERNANCE_ID, after, {PS.ListProposalArgsDefault()
                with excludeTopic = topics;
                omitLargeFields = ?false;
            });

            updateInternalState(res);

            ignore await* matchProposalsWithMessages(NNS_PROPOSAL_GROUP_ID, model.proposalsLookup);

            let (rvmList, scmList, batchMap) = getUpdateBatch();

            await* sendMessages(rvmList, scmList, batchMap);
            
            updateState:= #Stopped;
            logService.addLog(#Info, "Finished update", null);
        };

        func matchProposalsWithMessages(groupId : Text, pending : ProposalsLookup) : async* Result.Result<(), Text>{
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
            if(index == Option.get(model.latestNNSMessageIndex, index + 1)){
                logService.addLog(#Info, "[matchProposalsWithMessages] up to date", null);
                return #ok();
            };


            var start = index;
            var check = true;
            label attempts while (check){

            //if model.latestNNSMessageIndex is null, get last BATCH_SIZE once
            if(Option.isNull(model.latestNNSMessageIndex)){
                logService.addLog(#Info, "[matchProposalsWithMessages] model.latestNNSMessageIndex is null", null);
                check := false;
            };


            var end = start - FIND_PROPOSALS_BATCH_SIZE;
            if (end <= Option.get(model.latestNNSMessageIndex, end - 1)){
                end := Option.get(model.latestNNSMessageIndex, Nat32.fromNat(0)) + 1;
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

            model.latestNNSMessageIndex := ?index;
            #ok();
        };

        public func addSubscriber(subscriber : Subscriber, inviteCode : ?Nat64) : async* Result.Result<(), Text>{

            switch(subscriber){
                case(#Group(data)){
                    if(Map.has(model.subscribers, thash, data.groupCanister)){
                        return #err("Subscriber already exists");
                    };
                    let res = await* botService.joinGroup(data.groupCanister, inviteCode);
                    switch(res){
                        case(#ok(_)){
                            Map.set(model.subscribers, thash, data.groupCanister, subscriber);
                        };
                        case(#err(err)){
                            return #err(err);
                        }
                    }
                };
                case(#Channel(data)){
                    if(Map.has(model.subscribers, thash, Nat.toText(data.channelId))){
                        return #err("Subscriber already exists");
                    };
                    let res = await* botService.joinCommunity(data.communityCanister, inviteCode : ?Nat64);
                    Map.set(model.subscribers, thash, Nat.toText(data.channelId), subscriber); //TODO: fix idl error
                    switch(res){
                        case(#ok(_)){
                            let res2 = await* botService.joinChannel(data.communityCanister, data.channelId, inviteCode);
                             switch(res2){
                                case(#ok(_)){
                                    Map.set(model.subscribers, thash, Nat.toText(data.channelId), subscriber);
                                };
                                case(#err(err)){
                                    return #err(err);
                                }
                             };
                        };
                        case(#err(err)){
                            return #err(err);
                        }
                    }
                };
            };

            #ok();
        };

        public func updateSubscriber(id : Text, newTopics : [Int32]) : Result.Result<(), Text> {
            switch(Map.get(model.subscribers, thash, id)){
                case(?val){
                    switch(val){
                        case(#Group(data)){
                            Map.set(model.subscribers, thash, id, #Group({data with topics = newTopics}));
                        };
                        case(#Channel(data)){
                            Map.set(model.subscribers, thash, id, #Channel({data with topics = newTopics}));
                        }
                    };

                    #ok();
                };
                case(_){
                    return #err("Subscriber does not exist");
                };
            }
        };

        public func deleteSubscriber(id : Text) : Result.Result<(), Text>{
            switch(Map.remove(model.subscribers, thash, id)){
                case(?val){
                    #ok();
                };
                case(_){
                    return #err("Subscriber does not exist");
                };
            }
        };

        public func getSubscribers() : [Subscriber]{
            return Map.toArrayMap<Text, Subscriber, Subscriber>(model.subscribers, func (k : Text, v : Subscriber) : ?Subscriber {
                return ?v;
            });
        };


        func createProposalGroupThread(targetGroupId : Text, proposal : Proposal) : async* (){
            //logService.addLog(#Info, "[createProposalThread] Creating proposal thread: " # Nat.toText(proposal.id) # " messageIndex: " # Nat32.toText(Option.get(messageIndex, Nat32.fromNat(0))));
            let text = TU.formatProposal(proposal.proposalData);
            let res = await* botService.sendTextGroupMessage(targetGroupId, text, null);

            switch(res){
                case(#ok(data)){
                    switch(data){
                        case(#Success(d)){
                            let text2 = TU.formatProposalThreadMsg(NNS_PROPOSAL_GROUP_ID, proposal.proposalData.id, proposal.messageIndex);
                            let res = await* botService.sendTextGroupMessage(targetGroupId, text2, ?d.message_index);
                        };
                        case(_){};
                    };
                };
                case(#err(e)){
                    logService.addLog(#Error, "Error sending message: " # e, ?"[createProposalThread]");
                }
            };
        };

        func createBatchGroupThread(targetGroupId : Text, proposalList : [Proposal]) : async* (){
            let text = TU.formatProposals(proposalList);
            let #ok(res) = await* botService.sendTextGroupMessage(targetGroupId, text, null)
            else {
                logService.addLog(#Error, "Error sending message", ?"createBatchThread");
                return;
            };
            switch(res){
                case(#Success(d)){
                    let text2 = TU.formatBatchProposalThreadMsg(NNS_PROPOSAL_GROUP_ID, proposalList);
                    let res = await* botService.sendTextGroupMessage(targetGroupId, text2, ?d.message_index);
                };
                case(_){};
            }
        };

        func createProposalChannelThread(communityId : Text, channelId : Nat, proposal : Proposal) : async* (){
            //logService.addLog(#Info, "[createProposalThread] Creating proposal thread: " # Nat.toText(proposal.id) # " messageIndex: " # Nat32.toText(Option.get(messageIndex, Nat32.fromNat(0))));
            let text = TU.formatProposal(proposal.proposalData);
            let res = await* botService.sendChannelMessage(communityId, channelId, #Text({text = text}), null);

            switch(res){
                case(#ok(data)){
                    switch(data){
                        case(#Success(d)){
                            let text2 = TU.formatProposalThreadMsg(NNS_PROPOSAL_GROUP_ID, proposal.proposalData.id, proposal.messageIndex);
                            let res = await* botService.sendChannelMessage(communityId, channelId, #Text({text = text2}), ?d.message_index);
                        };
                        case(_){};
                    };
                };
                case(#err(e)){
                    logService.addLog(#Error, "Error sending message: " # e, ?"[createProposalThread]");
                }
            };
        };

        func createBatchChannelThread(communityId : Text, channelId : Nat, proposalList : [Proposal]) : async* (){
            let text = TU.formatProposals(proposalList);
            let #ok(res) = await* botService.sendChannelMessage(communityId, channelId, #Text({text = text}), null)
            else {
                logService.addLog(#Error, "Error sending message", ?"createBatchThread");
                return;
            };
            switch(res){
                case(#Success(d)){
                let text2 = TU.formatBatchProposalThreadMsg(NNS_PROPOSAL_GROUP_ID, proposalList);
                   let res = await* botService.sendChannelMessage(communityId, channelId, #Text({text = text2}), ?d.message_index);
                };
                case(_){};
            }
        };
    }
}