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
import OC "../OC/OCApi";
import T "../Types";
import PS "../Proposal/ProposalService";
import PM "../Proposal/ProposalMappings";
import GU "../Governance/GovernanceUtils";
import GT "../Governance/GovernanceTypes";

module{
    let TEST_GROUP_ID = "evg6t-laaaa-aaaar-a4j5q-cai";

    func voteToText(vote : TallyTypes.Vote) : Text{
        var text = "";
        switch(vote){
            case(#Yes){
                text := text # "Approved";
            };
            case(#No){
                text := text # "Rejected";
            }; 
            case(#Abstained){
                text := text # "Abstained";
            };
            case(#Pending){
                text := text # "Pending";
            };
        };

        text
    };

    public class TallyBot( botService : BT.BotService, logService : LT.LogService){
        var shouldPostInNNSGroup = false;

        func formatTally(tally : TallyTypes.TallyFeed) : Text{
            var text = "Feed Id: " # tally.tallyId # "\n";
            for(ballot in tally.ballots.vals()){
                text := text # "Proposal: " # Nat64.toText(ballot.proposalId) # " " # voteToText(ballot.tallyVote) # "\n";
                for(voteRecord in ballot.neuronVotes.vals()){
                    text := text # "Neuron: " # Nat64.toText(voteRecord.neuronId) # " " # voteToText(voteRecord.vote) # "\n";
                };
                text := text # "\n";
            };
            logService.logInfo("Tally update for " # tally.tallyId # text  , null);
            text;

        };

        public func toggleNNSGroup() : Bool {
            shouldPostInNNSGroup := not shouldPostInNNSGroup;
            shouldPostInNNSGroup
        };

        public func tallyUpdate(feed : [TallyTypes.TallyFeed]) : async (){
            for(tally in feed.vals()){
                let res = await* botService.sendTextGroupMessage(TEST_GROUP_ID, formatTally(tally), null);
                switch(res){
                    case(#ok(v)){
                        switch(v){
                            case(#Success(mdata)){

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
            };
        };
    };
}