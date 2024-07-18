
module {
    public type ProposalId = Nat64;

    public type ListProposalArgs = {
        includeRewardStatus :  [Int32];
        omitLargeFields : ?Bool;
        excludeTopic: [Int32];
        includeAllManageNeuronProposals : ?Bool;
        includeStatus : [Int32];
    };
    public type Proposal = {
        id : ProposalId;
        topicId : Int32;
        title : Text;
        description : ?Text;
        proposer : Nat64;
        timestamp : Nat64;
        var status : ProposalStatus;
        var deadlineTimestampSeconds : ?Nat64;
        proposalTimestampSeconds : Nat64;
    };

    //add type
    public type ProposalAPI = {
        id : ProposalId;
        topicId : Int32;
        title : Text;
        description : ?Text;
        proposer : Nat64;
        timestamp : Nat64;
        status : ProposalStatus;
        deadlineTimestampSeconds : ?Nat64;
        proposalTimestampSeconds : Nat64;
    };

    public type ProposalStatus = {
        #Pending; 
        #Executed : {#Approved; #Rejected}
    };
}