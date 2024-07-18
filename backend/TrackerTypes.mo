module {
    public type GetProposalResponse = {
        #Success : {proposals : [ProposalAPI]; lastId :?ProposalId} ;
        #LimitReached : [ProposalAPI]
    };

    public type GetProposalError = {
        #InvalidProposalId : {
            start : ?ProposalId;
            lowestActive : ?ProposalId;
            end : ?ProposalId;
        };
        #InternalError;
        #CanisterNotTracked;
        #InvalidTopic;
    };
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
  public type ProposalId = Nat64;
  public type ProposalStatus = {
    #Executed : { #Approved; #Rejected };
    #Pending;
  };
  public type TopicStrategy = {
            #All;
            #Include : [Int32];
            #Exclude : [Int32];
    };

  public type Result = { #ok; #err : Text };
  public type Result_1 = { #ok : GetProposalResponse; #err : GetProposalError };
  public type Tracker = actor {
    getProposals : shared (Text, ?ProposalId, TopicStrategy) -> async Result_1;
    start : shared () -> async Result;
    testAddService : shared () -> async Result;
  }
}