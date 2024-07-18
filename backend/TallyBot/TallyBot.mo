import TallyTypes "./TallyTypes";
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
import BT "../Bot/BotTypes";
import LT "../Log/LogTypes";
import {  nhash; n64hash; n32hash; thash } "mo:map/Map";
import TU "../TextUtils";
import OCApi "../OC/OCApi";
import T "../Types";
import PS "../Proposal/ProposalService";
import PM "../Proposal/ProposalMappings";
import GU "../Governance/GovernanceUtils";
import GT "../Governance/GovernanceTypes";

module{
    let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
    let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";

    func voteToText(vote : TallyTypes.Vote) : Text{
        var text = "";
        switch(vote){
            case(#Yes){
                text := text # "Approved"; // U+2705
            };
            case(#No){
                text := text # "Rejected"; //U+274C
            }; 
            case(#Abstained){
                text := text # "Abstained"; //U+1F634
            };
            case(#Pending){
                text := text # "Pending"; //U+231B
            };
        };

        text
    };

    type SubId = Text;
    type ProposalId = Nat64;

    type TallyBotModel = {
        //messages : Map.Map<ProposalId, Map.Map<SubId, Map.Map<TallyTypes.TallyId, OCApi.MessageId>>>;
        nnsGroupIndexes : Map.Map<Nat64, OCApi.MessageIndex>;
    };

    public func initTallyModel() : TallyBotModel{
        {
            nnsGroupIndexes = Map.new<Nat64, OCApi.MessageIndex>();
        }
    };

    public class TallyBot(tallyModel : TallyBotModel, botService : BT.BotService, logService : LT.LogService){
        var shouldPostInNNSGroup = false;

        // func formatTally(tally : TallyTypes.TallyFeed) : Text{
        //     var text = "Feed Id: " # tally.tallyId # "\n";
        //     for(ballot in tally.ballots.vals()){
        //         text := text # "Proposal: " # Nat64.toText(ballot.proposalId) # " " # voteToText(ballot.tallyVote) # "\n";
        //         for(voteRecord in ballot.neuronVotes.vals()){
        //             text := text # "Neuron: " # Nat64.toText(voteRecord.neuronId) # " " # voteToText(voteRecord.vote) # "\n";
        //         };
        //         text := text # "\n";
        //     };
        //     logService.logInfo("Tally update for " # tally.tallyId # text  , null);
        //     text;

        // };

        func formatBallot(tallyId : TallyTypes.TallyId, ballot : TallyTypes.Ballot) : Text{
            var text = "Feed Id: " # tallyId # "\n";
            text := text # "Proposal: " # Nat64.toText(ballot.proposalId) # " " # voteToText(ballot.tallyVote) # "\n";
            for(neuronVote in ballot.neuronVotes.vals()){
                text := text # "Neuron: " # Nat64.toText(neuronVote.neuronId) # " " # voteToText(neuronVote.vote) # "\n";
            };
            //logService.logInfo("Tally update for " # tallyId # text  , null);
            text;

        };

        public func toggleNNSGroup() : Bool {
            shouldPostInNNSGroup := not shouldPostInNNSGroup;
            shouldPostInNNSGroup
        };

        func generateMsgKey(target : Text, tallyId : TallyTypes.TallyId, proposalId : Nat64) : Text{
            target # "_" # tallyId # "_" # Nat64.toText(proposalId);
        };

        let targets : [Text] = [TEST_GROUP_ID, NNS_PROPOSAL_GROUP_ID];

        public func tallyUpdate(feed : [TallyTypes.TallyFeed]) : async (){
            let nnsMessageIndexLookup = Map.new<Nat64, OCApi.MessageIndex>();

            if(shouldPostInNNSGroup){
                //create proposal map
                let tempSet = Map.new<Nat64, ()>();
                for(tally in feed.vals()){
                    for(ballot in tally.ballots.vals()){
                        let msgKey = generateMsgKey(NNS_PROPOSAL_GROUP_ID, tally.tallyId, ballot.proposalId);
                        if(not Option.isSome(botService.getMessageId(msgKey))){
                            Map.set(tempSet, n64hash, ballot.proposalId, ());
                        }
                    };
                };
                // check if any isnt in nnsGroupIndexes, if so match them
                if(Map.size(tempSet) > 0){
                    let proposalList = await* matchProposalsWithMessages(NNS_PROPOSAL_GROUP_ID, tempSet, ?3);
                    switch(proposalList){
                        case(#ok(proposalList)){
                            // if return list is smaller than input, log error
                            if(Map.size(tempSet) > List.size(proposalList)){
                                logService.logError("Error matching proposals with messages: Return list is smaller than input", ?"[tallyUpdate]");
                            };

                            for(proposal in List.toIter(proposalList)){
                                Map.set(nnsMessageIndexLookup, n64hash, proposal.0, proposal.1);
                            };

                        };
                        case(#err(err)){
                            logService.logError("Error matching proposals with messages: " # err, ?"[tallyUpdate]");
                        };
                    };
                };
            };

            //send feeds to subscribers
            label l for(target in targets.vals()){
                if(target == NNS_PROPOSAL_GROUP_ID and not shouldPostInNNSGroup){ continue l;};

                for(tally in feed.vals()){
                    for(ballot in tally.ballots.vals()){
                        let msgKey = generateMsgKey(target, tally.tallyId, ballot.proposalId);
                        let textBallot = formatBallot(tally.tallyId, ballot);
                        switch(botService.getMessageId(msgKey)){
                            //if it already exists then edit instead of sending a new message
                            case(?id){
                                //once taly reaches consensus, delete message id
                                if(ballot.tallyVote != #Pending){
                                    botService.deleteMessageId(msgKey);
                                };
                                logService.logInfo("Edit tally update: ", null);

                                let res = await* botService.editTextGroupMessage(target, id, textBallot);
                                switch(res){
                                    case(#ok(_)){};
                                    case(#err(err)){};
                                };
                            };
                            case(_){
                                 logService.logInfo("no msg id ", null);
                                let msgIndex = do{
                                    if(target == NNS_PROPOSAL_GROUP_ID){
                                        Map.get(nnsMessageIndexLookup, n64hash, ballot.proposalId)
                                    } else{
                                        null
                                    }
                                };
                                let res = await* botService.sendTextGroupMessage(target, textBallot, msgIndex);
                                //doesnt make sense to save if consensus has been reached
                                if(ballot.tallyVote == #Pending){
                                    switch(res){
                                        case(#ok(v)){
                                            switch(v){
                                                case(#Success(msgData)){
                                                    //save message ids
                                                    logService.logInfo("save msg id: " # msgKey, null);
                                                    botService.saveMessageId(msgKey, msgData.message_id);
                                                };
                                                case(_){
                                                    logService.logError("OC error", null);
                                                };
                                            };

                                        };
                                        case(#err(err)){
                                            logService.logError("Error sending tally update: " # err, null);
                                        };
                                    };
                                }
                            };
                        };
                    };
                };
            };
           
        };

    let FIND_PROPOSALS_BATCH_SIZE : Nat32 = 100;
    public func matchProposalsWithMessages(groupId : Text, proposals : Map.Map<Nat64, ()>, maxEmptyRounds : ?Nat) : async* Result.Result<List.List<(Nat64, OCApi.MessageIndex)>, Text>{
    //map is empty, nothing to match
    var matchedList = List.nil<(Nat64, OCApi.MessageIndex)>();
    if(Map.size(proposals) == 0){
        logService.addLog(#Info, "[matchProposalsWithMessages] Map empty", null);
        return #ok(matchedList);
    };

    var index = switch(await* botService.getLatestGroupMessageIndex(groupId)){
        case(?index){index};
        case(_){
            logService.addLog(#Info, "[matchProposalsWithMessages] getLatestMessageIndex error", null);
            return #err("Error")};
    };

    var emptyRounds = 0;
    var start = index;
    var check = true;
    label attempts while (check){
        var end = start - FIND_PROPOSALS_BATCH_SIZE;
        //logService.addLog(#Info, "[matchProposalsWithMessages]start: " #  Nat32.toText(start) # " end: " # Nat32.toText(end), null);
        //generate ranges for message indexes to fetch
        let indexVec = Iter.range(Nat32.toNat(end), Nat32.toNat(start)) |> 
                        Iter.map(_, func (n : Nat) : Nat32 {Nat32.fromNat(n)}) |> 
                            Iter.toArray(_);
    
        start := end;

        let #ok(res) = await* botService.getGroupMessagesByIndex(groupId, indexVec, null)
        else {
            //Error retrieving messages
            logService.addLog(#Error, "Error retrieving messages", null);
            emptyRounds := emptyRounds + 1;
            continue attempts;
        };
        
        //let tempMap = Map.new<Nat, OCApi.MessageIndex>();
        var atLeastOneMatch = false;
        label messages for (message in Array.vals(res.messages)){ 
            let #ok(proposalData) = botService.getNNSProposalMessageData(message)
            else {
                //This shouldn't happen unless OC changes something
                logService.addLog(#Error, "error in getNNSProposalMessageData()", null);
                continue messages;
            };
            //check if proposal is in map
            if(Map.has(proposals, n64hash, proposalData.proposalId)){
                atLeastOneMatch := true;
                matchedList := List.push((proposalData.proposalId, proposalData.messageIndex), matchedList);
            };
        };

        if(not atLeastOneMatch){
            emptyRounds := emptyRounds + 1;
        };

        //matched all proposals
        if(Map.size(proposals) == List.size(matchedList)){
            check := false;
        };

        //max number of empty rounds reached
        if(emptyRounds >= Option.get(maxEmptyRounds, emptyRounds + 1)){
            check := false;
        };
    };  

    #ok(matchedList);
};

    };
}