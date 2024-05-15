import OC "./OCTypes";
import T "./Types";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Result "mo:base/Result";

module{

    func generateVoteRecord(neuronId :OC.NnsNeuronId, displayName : ?Text, vote : T.Vote) : T.VoteRecord {
        {
            neuronId = neuronId;
            displayName = displayName;
            vote = vote;
        }
    };


    //used to simulate data receive from polling canister
    func generateTally(name : ?Text, proposalId : OC.ProposalId, proposalStatus : T.ProposalStatus, votes : [T.VoteRecord]) : T.TallyData {

        let total = Array.size(votes);
        var approves = 0;
        var rejects = 0;
        for(vote in votes.vals()){
            switch(vote.vote){
                case(#Approved){
                    approves += 1;
                };
                case(#Rejected){
                    rejects += 1;
                };
                case(_){};
            };
        };
        var tallyStatus : T.Vote = #Pending;
        if(approves >= (total/2) + 1){tallyStatus := #Approved}
        else if(rejects >= (total/2) + 1){tallyStatus := #Rejected}
        else {
            switch(proposalStatus){
                case(#Executed(_)){
                    tallyStatus := #Abstained
                };
                case(_){};
            };
        };

        {
            name = name;
            subscribers = [#NNSGROUP];
            proposalId = proposalId;
            proposalTopic = 12;
            proposalStatus = proposalStatus;
            tallyStatus = tallyStatus;
            votes = votes;
            timestamp = 2222;
        }
    };

    //mixed batch with new and existing proposals
    //proposal removal
    //abstained correctly registered

    //basic multiple proposals batch
    public func basicMockData() : [T.TallyData] {
        
        let r1 = generateVoteRecord(222222, ?"Test", #Approved);
        let r2 = generateVoteRecord(333333, ?"Test2", #Rejected);
        let r3 = generateVoteRecord(444444, ?"Test3", #Approved);
        let r4 = generateVoteRecord(555555, ?"Test4", #Approved);

        let t1 = generateTally(?"Synapse", 127768, #Pending, [r1, r2, r3, r4]);
        let t2 = generateTally(?"Codegov", 127766, #Pending, [r1, r2, r3, r4]);

        [t1, t2]
        
    };

    //mixed batch with wrong and correct proposals
    public func wrongMockData() : [T.TallyData] {
        
        let r1 = generateVoteRecord(222222, ?"Test", #Approved);
        let r2 = generateVoteRecord(333333, ?"Test2", #Rejected);
        let r3 = generateVoteRecord(444444, ?"Test3", #Approved);
        let r4 = generateVoteRecord(555555, ?"Test4", #Approved);

        let t1 = generateTally(?"Synapse", 127768, #Pending, [r1, r2, r3, r4]);
        let t2 = generateTally(?"Codegov", 127766, #Pending, [r1, r2, r3, r4]);
        let t3 = generateTally(?"Codegov", 1, #Pending, [r1, r2, r3, r4]); //wrong on purpose

        [t1, t2, t3]
        
    };

    class SystemTests(){

    }

}
