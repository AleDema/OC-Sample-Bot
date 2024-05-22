module {
  public type GetProposalError = {
    #InvalidTopic;
    #CanisterNotTracked;
    #InternalError;
    #InvalidProposalId : { end : ProposalId; start : ProposalId };
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
  public type ProposalId = Nat;
  public type ProposalStatus = {
    #Executed : { #Approved; #Rejected };
    #Pending;
  };
  public type Result = { #ok; #err : Text };
  public type Result_1 = { #ok : [ProposalAPI]; #err : GetProposalError };
  public type Tracker = actor {
    getProposals : shared (Text, ?ProposalId, [Int32]) -> async Result_1;
    start : shared () -> async Result;
    testAddService : shared () -> async Result;
  }
}