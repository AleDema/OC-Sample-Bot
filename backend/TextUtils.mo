import T "./Types";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";

module {
  public func voteToText(vote : T.Vote) : Text {
    switch(vote){
      case(#Abstained){
        return "Abstained";
        };
        case(#Approved){
          return "Accepted";
        };
        case(#Rejected){
          return "Rejected";
        };
        case(#Pending){
          return "Pending";
        };
    };
  };

  public func proposalStatusToText(status : T.ProposalStatus) : Text {
    switch(status){
      case(#Pending){
        return "Pending"; 
      };
      case(#Executed(verdict)){
        switch(verdict){
          case(#Approved){
            return "Approved";
          };
          case(#Rejected){
            return "Rejected";
          };
        };
      };
    };
  };

  public func formatMessage(tally : T.TallyData) : Text {
    var approves = 0;
    var rejects = 0;
    let total = Nat.toText(Array.size(tally.votes));

    var tmp : Text = "";
    for(voteRecord in tally.votes.vals()){
      switch(voteRecord.vote){
        case(#Approved){
          approves := approves + 1;
        };
        case(#Rejected){
          rejects := rejects + 1;
        };
        case(_){};
      };
      tmp := tmp # "Neuron ID: " # Nat64.toText(voteRecord.neuronId) # " | Alias: " # Option.get(voteRecord.displayName, "()") # " | Vote: " # voteToText(voteRecord.vote) # "\n";
    };

    var res =  "Tally Status: " # voteToText(tally.tallyStatus) # "\n Approves: " # Nat.toText(approves) # "Rejects: " #  Nat.toText(rejects) # "Total: " # total #  "\n";
    res := res # tmp;
    res
  };
};