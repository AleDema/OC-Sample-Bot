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

  public type ProposalStatus = {
    #Executed : {#Approved; #Rejected;};
    #Pending;
  };

  public type Vote = {
    #Approved;
    #Rejected;
    #Abstained;
    #Pending;
  };

  type VoteRecords = {
    principal : Principal;
    displayName : ?Text;
    vote : Vote;
  };

 public type TallyData = {
    votes : [VoteRecords];
    proposalId : Nat;
    proposalStatus : ProposalStatus;
    proposalTopic : Nat;
    tallyStatus : Vote;
    timestamp : Nat;
  };

}
