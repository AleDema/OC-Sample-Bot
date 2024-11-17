import TallyTypes "./TallyTypes";
import List "mo:base/List";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Timer "mo:base/Timer";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import Map "mo:map/Map";
import TT "../TrackerTypes";
import BT "../Bot/BotTypes";
import LT "../Log/LogTypes";
import { nhash; n64hash; n32hash; thash } "mo:map/Map";
import TU "../TextUtils";
import Util "../Utils";
import OCApi "../OC/OCApi";
import T "../Types";
import PM "../Proposal/ProposalMappings";
import GU "../Governance/GovernanceUtils";
import GT "../Governance/GovernanceTypes";

module {
    //let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";
    let NNS_PROPOSAL_GROUP_ID = "labxu-baaaa-aaaaf-anb4q-cai";
    let GOVERNANCE_ID = "rrkah-fqaaa-aaaaa-aaaaq-cai";

    func voteToText(vote : TallyTypes.Vote) : Text {
        var text = "";
        switch (vote) {
            case (#Yes) {
                text := text # "Approved"; // U+2705
            };
            case (#No) {
                text := text # "Rejected"; //U+274C
            };
            case (#Abstained) {
                text := text # "Abstained"; //U+1F634
            };
            case (#Pending) {
                text := text # "Pending"; //U+231B
            };
        };

        text;
    };

    type SubId = Text;
    type ProposalId = Nat64;
    type Sub = {
        #Channel : { communityCanisterId : Text; channelId : Nat };
        #Group : Text;
    };

    type TallyBotModel = {
        nnsGroupIndexes : Map.Map<Nat64, { nnsGroupIndex : OCApi.MessageIndex; dependentTallies : Map.Map<TallyTypes.TallyId, ()> }>;
        subscribersByTally : Map.Map<TallyTypes.TallyId, List.List<Sub>>;
        var shouldPostInNNSGroup : Bool;
    };

    public func initTallyModel() : TallyBotModel {
        {
            subscribersByTally = Map.new<TallyTypes.TallyId, List.List<Sub>>();
            nnsGroupIndexes = Map.new<ProposalId, { nnsGroupIndex : OCApi.MessageIndex; dependentTallies : Map.Map<TallyTypes.TallyId, ()> }>();
            var shouldPostInNNSGroup = false;
        };
    };

    public class TallyBot(tallyModel : TallyBotModel, botService : BT.BotService, logService : LT.LogService) {

        public func addSubscriber(tallyId : TallyTypes.TallyId, subscriber : Sub) : Result.Result<(), Text> {
            switch (Map.get(tallyModel.subscribersByTally, thash, tallyId)) {
                case (?exists) {
                    let res = List.find<Sub>(
                        exists,
                        func e : Bool {
                            switch (e, subscriber) {
                                case (#Channel(v), #Channel(v2)) {
                                    if (v.channelId == v2.channelId and v.communityCanisterId == v2.communityCanisterId) {
                                        return true;
                                    };
                                    return false;
                                };
                                case (#Group(v), #Group(v2)) {
                                    if (Text.equal(v, v2)) {
                                        return true;
                                    };
                                    return false;
                                };
                                case (_) {
                                    return false;
                                };
                            };
                        },
                    );
                    if (Option.isSome(res)) {
                        return #err("Existing sub");
                    };
                    Map.set(tallyModel.subscribersByTally, thash, tallyId, List.push(subscriber, exists));
                };
                case (_) {
                    Map.set(tallyModel.subscribersByTally, thash, tallyId, List.make(subscriber));
                };
            };

            return #ok();
        };

        public func deleteSubscription(tallyId : TallyTypes.TallyId, subscriber : Sub) : Result.Result<(), Text> {
            switch (Map.get(tallyModel.subscribersByTally, thash, tallyId)) {
                case (?exists) {
                    var check = false;
                    let newList = List.filter<Sub>(
                        exists,
                        func e : Bool {
                            switch (e, subscriber) {
                                case (#Channel(v), #Channel(v2)) {
                                    if (v.channelId == v2.channelId and v.communityCanisterId == v2.communityCanisterId) {
                                        check := true;
                                        return false;
                                    };
                                    return true;
                                };
                                case (#Group(v), #Group(v2)) {
                                    if (Text.equal(v, v2)) {
                                        check := true;
                                        return false;
                                    };
                                    return true;
                                };
                                case (_) {
                                    return true;
                                };
                            };
                        },
                    );

                    if (check) {
                        if (List.size(newList) == 0) {
                            Map.delete(tallyModel.subscribersByTally, thash, tallyId);
                        } else {
                            Map.set(tallyModel.subscribersByTally, thash, tallyId, newList);
                        };
                        #ok();
                    } else {
                        return #err("The tally isnt subscribed to this group/channel");
                    };

                };
                case (_) {
                    #err("These tally id has no active subscriptions");
                };
            };
        };

        public func getSubscribers(tallyId : ?TallyTypes.TallyId) : [(TallyTypes.TallyId, [Sub])] {
            let buf = Buffer.Buffer<(TallyTypes.TallyId, [Sub])>(50);

            switch(tallyId) {
                case (?tallyId) {
                    switch (Map.get(tallyModel.subscribersByTally, thash, tallyId)) {
                        case (?list) {
                            buf.add((tallyId, List.toArray(list)));
                        };
                        case (_) {
                            return [];
                        };
                    };
                };
                case (_) {
                    for ((k, v) in Map.entries(tallyModel.subscribersByTally)) {
                        buf.add((k, List.toArray(v)));
                    };
                };
            };
            Buffer.toArray(buf);
        };


        func getMsgIndex(target : Text, proposalId : ProposalId) : ?OCApi.MessageIndex {
            let def : ?OCApi.MessageIndex = null;
            if (target == NNS_PROPOSAL_GROUP_ID) {
                switch (Map.get(tallyModel.nnsGroupIndexes, n64hash, proposalId)) {
                    case (?indexData) {
                        return ?indexData.nnsGroupIndex;
                    };
                    case (_) {
                        logService.logError("Could not find index for proposal " # Nat64.toText(proposalId) # " in map", ?"[getMsgIndex]");
                        return def;
                    };
                };
            } else {
                def;
            };
        };

        func removeIndexDependency(proposalId : ProposalId, tallyId : TallyTypes.TallyId) : () {
            logService.logError("Calling reduceIndexDependency on: " # Nat64.toText(proposalId), ?"[reduceIndexDependency]");
            switch (Map.get(tallyModel.nnsGroupIndexes, n64hash, proposalId)) {
                case (?msgIndex) {
                    if (Map.has(msgIndex.dependentTallies, thash, tallyId)) {
                        ignore Map.remove(msgIndex.dependentTallies, thash, tallyId);
                    };

                    if (Map.size(msgIndex.dependentTallies) == 0) {
                        ignore Map.remove(tallyModel.nnsGroupIndexes, n64hash, proposalId);
                    };
                };
                case (_) {};
            };
        };

        func sendMessageToSub(sub : Sub, message : Text, msgOrThreadIndex : ?OCApi.MessageIndex) : async* Result.Result<T.SendMessageResponse, Text> {
            switch (sub) {
                case (#Channel(data)) {
                    let res = await* botService.sendChannelMessage(data.communityCanisterId, data.channelId, #Text({ text = message }), msgOrThreadIndex);
                    switch (res) {
                        case (#ok(d)) {
                            return #ok(d);
                        };
                        case (#err(e)) {
                            return #err(e);
                        };
                    };
                };
                case (#Group(id)) {
                    let res = await* botService.sendTextGroupMessage(id, message, msgOrThreadIndex);
                    switch (res) {
                        case (#ok(d)) {
                            return #ok(d);
                        };
                        case (#err(e)) {
                            return #err(e);
                        };
                    };
                };
            };
        };

        func editMessageToSub(sub : Sub, newMessage : Text, messageId : OCApi.MessageId, msgOrThreadIndex : ?OCApi.MessageIndex) : async* Result.Result<(), Text> {
            switch (sub) {
                case (#Channel(data)) {
                    let res = await* botService.editChannelMessage(data.communityCanisterId, data.channelId, messageId, msgOrThreadIndex, #Text({ text = newMessage }));
                    switch (res) {
                        case (#ok(_)) {
                            return #ok();
                        };
                        case (#err(e)) {
                            return #err(e);
                        };
                    };
                };
                case (#Group(id)) {
                    let res = await* botService.editTextGroupMessage(id, messageId, msgOrThreadIndex, newMessage);
                    switch (res) {
                        case (#ok(_)) {
                            return #ok();
                        };
                        case (#err(e)) {
                            return #err(e);
                        };
                    };
                };
            };
        };


        func updateSubscribers(feed : [TallyTypes.TallyFeed]) : async* () {
            label l for (tally in feed.vals()) {
                let #ok(subList) = Util.optToRes(Map.get(tallyModel.subscribersByTally, thash, tally.tallyId)) else {
                    continue l;
                };
                for (sub in List.toIter(subList)) {
                    for (ballot in tally.ballots.vals()) {
                        let msgKey = generateMsgKey(sub, tally.tallyId, ballot.proposalId);
                        let textBallot = formatBallot(tally.tallyId, tally.alias, ballot);
                        switch (botService.getMessageId(msgKey)) {
                            //if it already exists then edit instead of sending a new message
                            case (?msgId) {
                                logService.logInfo("Edit tally update: ", null);
                                let res = await* editMessageToSub(sub, textBallot, msgId, null);
                                switch (res) {
                                    case (#ok(_)) {};
                                    case (#err(err)) {};
                                };
                                //once tally reaches consensus, delete message id and reduce index dependency by one
                                if (ballot.tallyVote != #Pending) {
                                    botService.deleteMessageId(msgKey);
                                };
                            };
                            case (_) {
                                logService.logInfo("no msg id ", null);
                                //let msgIndex = getMsgIndex(sub.id, ballot.proposalId);
                                let res = await* sendMessageToSub(sub, textBallot, null);
                                //doesnt make sense to save if consensus has been reached
                                if (ballot.tallyVote == #Pending) {
                                    switch (res) {
                                        case (#ok(v)) {
                                            switch (v) {
                                                case (#Success(msgData)) {
                                                    //save message ids
                                                    logService.logInfo("save msg id: " # msgKey, null);
                                                    botService.saveMessageId(msgKey, msgData.message_id);
                                                };
                                                case (_) {
                                                    logService.logError("OC error", null);
                                                };
                                            };

                                        };
                                        case (#err(err)) {
                                            logService.logError("Error sending tally update: " # err, null);
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };


        func updateNNSGroup(feed : [TallyTypes.TallyFeed]) : async* () {
            //notify nnsproposalgroup
            if (tallyModel.shouldPostInNNSGroup) {
                await* fetchIndexes(feed);
                label l for (tally in feed.vals()) {
                    if (tally.governanceCanister != GOVERNANCE_ID) {
                        continue l;
                    };
                    for (ballot in tally.ballots.vals()) {
                        let msgKey = generateMsgKey(#Group NNS_PROPOSAL_GROUP_ID, tally.tallyId, ballot.proposalId);
                        let textBallot = formatBallot(tally.tallyId, tally.alias, ballot);
                        switch (botService.getMessageId(msgKey)) {
                            //if it already exists then edit instead of sending a new message
                            case (?id) {
                                logService.logInfo("Edit tally update: ", null);

                                let msgIndex = getMsgIndex(NNS_PROPOSAL_GROUP_ID, ballot.proposalId);
                                if (not Option.isSome(msgIndex)) {
                                    continue l;
                                };

                                let res = await* botService.editTextGroupMessage(NNS_PROPOSAL_GROUP_ID, id, msgIndex, textBallot);
                                switch (res) {
                                    case (#ok(_)) {};
                                    case (#err(err)) {};
                                };
                                //once tally reaches consensus, delete message id and reduce index dependency by one
                                if (ballot.tallyVote != #Pending) {
                                    botService.deleteMessageId(msgKey);
                                    removeIndexDependency(ballot.proposalId, tally.tallyId);
                                };
                            };
                            case (_) {
                                logService.logInfo("no msg id ", null);
                                let msgIndex = getMsgIndex(NNS_PROPOSAL_GROUP_ID, ballot.proposalId);
                                if (not Option.isSome(msgIndex)) {
                                    continue l;
                                };

                                let res = await* botService.sendTextGroupMessage(NNS_PROPOSAL_GROUP_ID, textBallot, msgIndex);
                                //doesnt make sense to save if consensus has been reached
                                if (ballot.tallyVote == #Pending) {
                                    switch (res) {
                                        case (#ok(v)) {
                                            switch (v) {
                                                case (#Success(msgData)) {
                                                    //save message ids
                                                    logService.logInfo("save msg id: " # msgKey, null);
                                                    botService.saveMessageId(msgKey, msgData.message_id);
                                                };
                                                case (_) {
                                                    logService.logError("OC error", null);
                                                };
                                            };

                                        };
                                        case (#err(err)) {
                                            logService.logError("Error sending tally update: " # err, null);
                                        };
                                    };
                                } else {
                                    logService.logInfo("line 226 " # msgKey, null);
                                    removeIndexDependency(ballot.proposalId, tally.tallyId);
                                };
                            };
                        };
                    };
                };
            };
        }; 

        public func tallyUpdate(feed : [TallyTypes.TallyFeed]) : async () {
            await* updateSubscribers(feed);
            await* updateNNSGroup(feed);
        };

        func fetchIndexes(feed : [TallyTypes.TallyFeed]) : async* () {
            let tempSet = Map.new<Nat64, ()>();
            let tallyIdsByProposal = Map.new<Nat64, List.List<TallyTypes.TallyId>>();
            label l for (tally in feed.vals()) {
                if (tally.governanceCanister != GOVERNANCE_ID) {
                    continue l;
                };
                for (ballot in tally.ballots.vals()) {
                    switch (Map.get(tallyIdsByProposal, n64hash, ballot.proposalId)) {
                        case (?tallyIds) {
                            Map.set(tallyIdsByProposal, n64hash, ballot.proposalId, List.push(tally.tallyId, tallyIds));
                        };
                        case (_) {
                            Map.set(tallyIdsByProposal, n64hash, ballot.proposalId, List.make(tally.tallyId));
                        };
                    };
                    //if the proposal already has a msg index then we add the counter for the proposal deending on it iff the tally will need to be posted again
                    switch (Map.get(tallyModel.nnsGroupIndexes, n64hash, ballot.proposalId)) {
                        case (?msgIndex) {
                            if (ballot.tallyVote == #Pending) {
                                logService.logInfo("Updating msg index dependency count for proposal: " # Nat64.toText(ballot.proposalId), null);
                                Map.set(msgIndex.dependentTallies, thash, tally.tallyId, ());
                            };
                        };
                        case (_) {
                            //if there is no msg index then we add it to the list to fetch
                            Map.set(tempSet, n64hash, ballot.proposalId, ());
                        };
                    };
                };
            };
            // check if any isnt in nnsGroupIndexes, if so match them
            if (Map.size(tempSet) > 0) {
                let proposalList = await* matchProposalsWithMessages(NNS_PROPOSAL_GROUP_ID, tempSet, ?3);
                logService.logInfo(" check if any isnt in nnsGroupIndexes, if so match them", null);
                switch (proposalList) {
                    case (#ok(proposalList)) {
                        // if return list is smaller than input, log error
                        if (Map.size(tempSet) > List.size(proposalList)) {
                            logService.logError("Error matching proposals with messages: Return list is smaller than input", ?"[tallyUpdate]");
                        };

                        for (proposal in List.toIter(proposalList)) {
                            //this is required due to the async nature of this method to prevent reentrancy issues
                            switch (Map.get(tallyModel.nnsGroupIndexes, n64hash, proposal.0)) {
                                case (?msgIndex) {};
                                case (_) {
                                    logService.logInfo("Setting msg index for proposal: " # Nat64.toText(proposal.0), null);
                                    let newMap : Map.Map<TallyTypes.TallyId, ()> = Map.new<TallyTypes.TallyId, ()>();
                                    switch (Map.get(tallyIdsByProposal, n64hash, proposal.0)) {
                                        case (?tallyIds) {
                                            for (tallyId in List.toIter(tallyIds)) {
                                                Map.set(newMap, thash, tallyId, ());
                                            };
                                        };
                                        case (_) {

                                        };
                                    };
                                    Map.set(tallyModel.nnsGroupIndexes, n64hash, proposal.0, { nnsGroupIndex = proposal.1; dependentTallies = newMap });
                                };
                            };
                        };

                    };
                    case (#err(err)) {
                        logService.logError("Error matching proposals with messages: " # err, ?"[tallyUpdate]");
                    };
                };
            };
        };

        let FIND_PROPOSALS_BATCH_SIZE : Nat32 = 100;
        public func matchProposalsWithMessages(groupId : Text, proposals : Map.Map<Nat64, ()>, maxEmptyRounds : ?Nat) : async* Result.Result<List.List<(Nat64, OCApi.MessageIndex)>, Text> {
            //map is empty, nothing to match
            var matchedList = List.nil<(Nat64, OCApi.MessageIndex)>();
            if (Map.size(proposals) == 0) {
                logService.addLog(#Info, "[matchProposalsWithMessages] Map empty", null);
                return #ok(matchedList);
            };

            var index = switch (await* botService.getLatestGroupMessageIndex(groupId)) {
                case (?index) { index };
                case (_) {
                    logService.addLog(#Info, "[matchProposalsWithMessages] getLatestMessageIndex error", null);
                    return #err("Error");
                };
            };

            var emptyRounds = 0;
            var start = index;
            var check = true;
            label attempts while (check) {
                var end = start - FIND_PROPOSALS_BATCH_SIZE;
                //logService.addLog(#Info, "[matchProposalsWithMessages]start: " #  Nat32.toText(start) # " end: " # Nat32.toText(end), null);
                //generate ranges for message indexes to fetch
                let indexVec = Iter.range(Nat32.toNat(end), Nat32.toNat(start)) |> Iter.map(_, func(n : Nat) : Nat32 { Nat32.fromNat(n) }) |> Iter.toArray(_);

                start := end;

                let #ok(res) = await* botService.getGroupMessagesByIndex(groupId, indexVec, null) else {
                    //Error retrieving messages
                    logService.addLog(#Error, "Error retrieving messages", null);
                    emptyRounds := emptyRounds + 1;
                    continue attempts;
                };

                //let tempMap = Map.new<Nat, OCApi.MessageIndex>();
                var atLeastOneMatch = false;
                label messages for (message in Array.vals(res.messages)) {
                    let #ok(proposalData) = botService.getNNSProposalMessageData(message) else {
                        //This shouldn't happen unless OC changes something
                        logService.addLog(#Error, "error in getNNSProposalMessageData()", null);
                        continue messages;
                    };
                    //check if proposal is in map
                    if (Map.has(proposals, n64hash, proposalData.proposalId)) {
                        atLeastOneMatch := true;
                        matchedList := List.push((proposalData.proposalId, proposalData.messageIndex), matchedList);
                    };
                };

                if (not atLeastOneMatch) {
                    emptyRounds := emptyRounds + 1;
                };

                //matched all proposals
                if (Map.size(proposals) == List.size(matchedList)) {
                    check := false;
                };

                //max number of empty rounds reached
                if (emptyRounds >= Option.get(maxEmptyRounds, emptyRounds + 1)) {
                    check := false;
                };
            };

            #ok(matchedList);
        };

        func formatBallot(tallyId : TallyTypes.TallyId, alias : ?Text, ballot : TallyTypes.Ballot) : Text {
            var text = "Tally Id: " # tallyId # "\n";
            switch(alias) {
                case (?alias) {
                    text := text # "Tally Name: " # alias # "\n";
                };
                case (_) {};
            };
            text := text # "Proposal: " # Nat64.toText(ballot.proposalId) # " " # voteToText(ballot.tallyVote) # "\n";
            for (neuronVote in ballot.neuronVotes.vals()) {
                text := text # "Neuron: " # neuronVote.neuronId # " " # voteToText(neuronVote.vote) # "\n";
            };
            //logService.logInfo("Tally update for " # tallyId # text  , null);
            text;

        };

        public func toggleNNSGroup() : Bool {
            tallyModel.shouldPostInNNSGroup := not tallyModel.shouldPostInNNSGroup;
            tallyModel.shouldPostInNNSGroup;
        };

        func generateMsgKey(sub : Sub, tallyId : TallyTypes.TallyId, proposalId : Nat64) : Text {
            switch (sub) {
                case (#Group(groupId)) {
                    return groupId # "_" # tallyId # "_" # Nat64.toText(proposalId);
                };
                case (#Channel(data)) {
                    data.communityCanisterId # Nat.toText(data.channelId) # "_" # tallyId # "_" # Nat64.toText(proposalId);
                };
            };
        };
    };
};
