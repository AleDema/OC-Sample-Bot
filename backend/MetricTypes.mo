module {
   public type CanisterStatus = {
        cycle_balance : Nat;
        memory_used : Nat;
        daily_burn : Nat;
        controllers : [Principal];
    };

    type definite_canister_settings = {
        controllers : [Principal];
        compute_allocation : Nat;
        memory_allocation : Nat;
        freezing_threshold : Nat;
    };

    public type ManagementCanisterActor = actor {
      canister_status : ({ canister_id : Principal }) -> async ({
      status : { #running; #stopping; #stopped };
      settings : definite_canister_settings;
      module_hash : ?Blob;
      memory_size : Nat;
      cycles : Nat;
      idle_cycles_burned_per_day : Nat;
    })
    };
}
