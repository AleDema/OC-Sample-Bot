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

module{

    public type ProposalsLookup = Map.Map<Nat, {proposalData : TT.ProposalAPI; messageIndex : ?Nat32; attempts : Nat}>;


    public type ProposalBotModel = {
        var lastProposalId : ?Nat;
        var timerId :?Nat;
        var pendingSCMList : List.List<TT.ProposalAPI>;
        var latestNNSMessageIndex : ?Nat32;
        proposalsLookup : ProposalsLookup;
        var numberOfTicksSinceUpdate : Nat;
    };

    public func initModel() : ProposalBotModel{
        {
            var lastProposalId = null;
            var timerId = null;
            var pendingSCMList = List.nil<TT.ProposalAPI>();
            var latestNNSMessageIndex = null;
            proposalsLookup : ProposalsLookup = Map.new();
            var numberOfTicksSinceUpdate = 0;
        }
    };

    let FIND_PROPOSALS_BATCH_SIZE : Nat32 = 100;
    let PENDING_SCM_LIMIT = 10;
    let MAX_TICKS_WITHOUT_UPDATE = 3;

    let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";
    let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
    let GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";
    
    public class ProposalBot(model : ProposalBotModel, botService : BT.BotService, logService : LT.LogService) = {
        
        public func initTimer<system>(_tickrateInSeconds : ?Nat) : async Result.Result<(), Text> {
                    
            let tickrate : Nat = Option.get(_tickrateInSeconds, 5* 60); // 1 minutes
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

        public func update(start : ?Nat) : async () {
            logService.addLog(#Info, "Running update", null);
            let tracker : TT.Tracker = actor ("vkqwa-eqaaa-aaaap-qhira-cai");

            model.numberOfTicksSinceUpdate := model.numberOfTicksSinceUpdate + 1;
            logService.addLog(#Info, "Number of ticks since last update: " # Nat.toText(model.numberOfTicksSinceUpdate), null);
            let res = await tracker.getProposals(GOVERNANCE_ID, start, [8, 13]);
            switch(res){
                case(#ok(data)){
                    for(proposal in Array.vals(data)){
                        Map.set(model.proposalsLookup, nhash, proposal.id, { proposalData = proposal; messageIndex = null; attempts = 0});
                    };

                    ignore await* matchProposalsWithMessages(NNS_PROPOSAL_GROUP_ID, model.proposalsLookup);
                };
                case(#err(e)){
                    switch(e){
                        case(#InvalidProposalId(d)){
                            logService.addLog(#Info, "InvalidProposalId, set last proposal id to: " # Nat.toText(d.end + 1), null);
                            model.lastProposalId := ?(d.end); //TODO; remove temp fix until poll service is fixed
                        };
                        case(_){};
                    };
                };
            };

            for(proposal in Map.vals(model.proposalsLookup)){

                switch(T.topicIdToVariant(proposal.proposalData.topicId)){
                    case(#RVM){
                    if(Option.isSome(proposal.messageIndex) or proposal.attempts > 3){
                        await* createProposalThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, proposal.proposalData, proposal.messageIndex);
                        Map.delete(model.proposalsLookup, nhash, proposal.proposalData.id);
                    }
                    };
                    case(#SCM){
                    if(TU.isSeparateBuildProcess(proposal.proposalData.title)){
                        if(Option.isSome(proposal.messageIndex) or proposal.attempts > 3){
                            await* createProposalThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, proposal.proposalData, proposal.messageIndex);
                            Map.delete(model.proposalsLookup, nhash, proposal.proposalData.id);
                        };
                    } else {
                        if(not List.some(model.pendingSCMList, func(p : TT.ProposalAPI) : Bool { return p.id == proposal.proposalData.id})){
                            model.pendingSCMList := List.push(proposal.proposalData, model.pendingSCMList);
                            model.numberOfTicksSinceUpdate := 0;
                            logService.addLog(#Info, "Pushing to list: " # Nat.toText(proposal.proposalData.id), null);
                        } else {
                            logService.addLog(#Info, "Already in list" # Nat.toText(proposal.proposalData.id), null);
                        };
                    };

                    };
                    case(_){};
            };

                if(proposal.proposalData.id > Option.get(model.lastProposalId, 0)){
                    model.lastProposalId := ?(proposal.proposalData.id); //TODO; remove temp fix until poll service is fixed
                };
            };

            if((List.size(model.pendingSCMList) > 0 and List.size(model.pendingSCMList) < PENDING_SCM_LIMIT and model.numberOfTicksSinceUpdate > MAX_TICKS_WITHOUT_UPDATE)){
                logService.addLog(#Info, "Sending pending list cause wait for quiet expired", null);
                let arr = List.toArray(List.reverse(model.pendingSCMList));
                await* createBatchThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, arr, model.proposalsLookup);
                for (p in Array.vals(arr) ){
                    Map.delete(model.proposalsLookup, nhash, p.id);
                };
                model.pendingSCMList := List.nil<TT.ProposalAPI>();
            } else if (List.size(model.pendingSCMList) > PENDING_SCM_LIMIT){
                logService.addLog(#Info, "Sending pending list cause too may entries", null);
                //reverses the list to print in ascending order
                model.pendingSCMList := List.reverse(model.pendingSCMList);
                let chunks = List.chunks(PENDING_SCM_LIMIT, model.pendingSCMList);
                for(chunk in List.toIter(chunks)){
                if (List.size(chunk) < PENDING_SCM_LIMIT){
                    model.pendingSCMList := chunk;
                    return;
                } else {
                    await* createBatchThread(TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID, List.toArray(chunk), model.proposalsLookup);
                    for ( p in List.toIter(chunk) ){
                        Map.delete(model.proposalsLookup, nhash, p.id);
                    };
                }
                };
                model.pendingSCMList := List.nil<TT.ProposalAPI>();
            };

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

        func createProposalThread(targetGroupId : Text, votingGroupId : Text, proposal : TT.ProposalAPI, messageIndex : ?Nat32) : async* (){
            //logService.addLog(#Info, "[createProposalThread] Creating proposal thread: " # Nat.toText(proposal.id) # " messageIndex: " # Nat32.toText(Option.get(messageIndex, Nat32.fromNat(0))));
            let text = TU.formatProposal(proposal);
            let res = await* botService.sendTextGroupMessage(targetGroupId, text, null);

            switch(res){
                case(#ok(data)){
                    switch(data){
                        case(#Success(d)){
                            let text2 = TU.formatProposalThreadMsg(votingGroupId, proposal.id, messageIndex);
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

        func createBatchThread(targetGroupId : Text, votingGroupId : Text, proposalList : [TT.ProposalAPI], proposalsLookup : ProposalsLookup) : async* (){
            let text = TU.formatProposals(proposalList);
            let #ok(res) = await* botService.sendTextGroupMessage(targetGroupId, text, null)
            else {
                logService.addLog(#Error, "Error sending message", ?"createBatchThread");
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
    }
}