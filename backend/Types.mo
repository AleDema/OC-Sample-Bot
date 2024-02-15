import O "./OCTypes";
module{

  public type BotStatus = {
    #NotInitialized;
    #Initializing;
    #Initialized;
  };

  public type RustResult<S, E> = {
    #Ok : S;
    #Err : E;
  };

    type ProposalStatus = {
    #Settled;
    #Approved;
    #Rejected;
    #Pending;
  };

  type Vote = {
    #Approved;
    #Rejected;
    #Pending;
  };

  type VoteRecords = {
    principal : Principal;
    displayName : ?Text;
    vote : Vote;
  };

  type Ingress = {
    votes : [VoteRecords];
    proposalId : Nat;
    proposalStatus : ProposalStatus;
    topic : Nat;
    tallyStatus : Vote;
    timestamp : Nat;
  };

}
