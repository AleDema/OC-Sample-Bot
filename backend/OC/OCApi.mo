import Nat64 "mo:base/Nat64";
// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module {
  public type AcceptSwapSuccess = { token1_txn_in : Nat64 };
  public type AccessGate = {
    #VerifiedCredential : VerifiedCredentialGate;
    #SnsNeuron : SnsNeuronGate;
    #TokenBalance : TokenBalanceGate;
    #DiamondMember;
    #Payment : PaymentGate;
  };
  public type AccessGateUpdate = {
    #NoChange;
    #SetToNone;
    #SetToSome : AccessGate;
  };
  public type AccessorId = Principal;
  public type AccountIdentifier = Blob;
  public type AddedToChannelNotification = {
    channel_id : ChannelId;
    community_id : CommunityId;
    added_by_name : Text;
    added_by : UserId;
    channel_name : Text;
    community_avatar_id : ?Nat;
    added_by_display_name : ?Text;
    community_name : Text;
    channel_avatar_id : ?Nat;
  };
  public type AudioContent = {
    mime_type : Text;
    blob_reference : ?BlobReference;
    caption : ?Text;
  };
  public type AvatarChanged = {
    changed_by : UserId;
    previous_avatar : ?Nat;
    new_avatar : ?Nat;
  };
  public type BannerChanged = {
    new_banner : ?Nat;
    changed_by : UserId;
    previous_banner : ?Nat;
  };
  public type BlobReference = { blob_id : Nat; canister_id : CanisterId };
  public type BlockIndex = Nat64;
  public type BuildVersion = { major : Nat32; minor : Nat32; patch : Nat32 };
  public type CanisterId = Principal;
  public type CanisterUpgradeStatus = { #NotRequired; #InProgress };
  public type CanisterWasm = {
    compressed : Bool;
    version : BuildVersion;
    module_ : Blob;
  };
  public type ChannelId = Nat;
  public type ChannelMatch = {
    id : ChannelId;
    subtype : ?GroupSubtype;
    gate : ?AccessGate;
    name : Text;
    description : Text;
    avatar_id : ?Nat;
    member_count : Nat32;
  };
  public type ChannelMessageNotification = {
    channel_id : ChannelId;
    community_id : CommunityId;
    image_url : ?Text;
    sender_display_name : ?Text;
    sender : UserId;
    channel_name : Text;
    community_avatar_id : ?Nat;
    community_name : Text;
    sender_name : Text;
    message_text : ?Text;
    message_type : Text;
    event_index : EventIndex;
    thread_root_message_index : ?MessageIndex;
    channel_avatar_id : ?Nat;
    crypto_transfer : ?NotificationCryptoTransferDetails;
    message_index : MessageIndex;
  };
  public type ChannelMessageTippedNotification = {
    tip : Text;
    channel_id : ChannelId;
    tipped_by_display_name : ?Text;
    community_id : CommunityId;
    message_event_index : EventIndex;
    channel_name : Text;
    tipped_by : UserId;
    community_avatar_id : ?Nat;
    community_name : Text;
    tipped_by_name : Text;
    thread_root_message_index : ?MessageIndex;
    channel_avatar_id : ?Nat;
    message_index : MessageIndex;
  };
  public type ChannelReactionAddedNotification = {
    channel_id : ChannelId;
    community_id : CommunityId;
    added_by_name : Text;
    message_event_index : EventIndex;
    added_by : UserId;
    channel_name : Text;
    community_avatar_id : ?Nat;
    added_by_display_name : ?Text;
    community_name : Text;
    thread_root_message_index : ?MessageIndex;
    channel_avatar_id : ?Nat;
    reaction : Reaction;
    message_index : MessageIndex;
  };
  public type Chat = {
    #Group : ChatId;
    #Channel : (CommunityId, ChannelId);
    #Direct : ChatId;
  };
  public type ChatEvent = {
    #Empty;
    #ParticipantJoined : ParticipantJoined;
    #GroupDescriptionChanged : GroupDescriptionChanged;
    #GroupChatCreated : GroupChatCreated;
    #MessagePinned : MessagePinned;
    #UsersInvited : UsersInvited;
    #UsersBlocked : UsersBlocked;
    #MessageUnpinned : MessageUnpinned;
    #ParticipantsRemoved : ParticipantsRemoved;
    #GroupVisibilityChanged : GroupVisibilityChanged;
    #Message : Message;
    #PermissionsChanged : PermissionsChanged;
    #MembersAddedToDefaultChannel : MembersAddedToDefaultChannel;
    #ChatFrozen : GroupFrozen;
    #GroupInviteCodeChanged : GroupInviteCodeChanged;
    #UsersUnblocked : UsersUnblocked;
    #ChatUnfrozen : GroupUnfrozen;
    #ParticipantLeft : ParticipantLeft;
    #GroupRulesChanged : GroupRulesChanged;
    #GroupNameChanged : GroupNameChanged;
    #GroupGateUpdated : GroupGateUpdated;
    #RoleChanged : RoleChanged;
    #EventsTimeToLiveUpdated : EventsTimeToLiveUpdated;
    #DirectChatCreated : DirectChatCreated;
    #AvatarChanged : AvatarChanged;
    #ParticipantsAdded : ParticipantsAdded;
  };
  public type ChatEventWrapper = {
    event : ChatEvent;
    timestamp : TimestampMillis;
    index : EventIndex;
    correlation_id : Nat64;
    expires_at : ?TimestampMillis;
  };
  public type ChatId = CanisterId;
  public type ChatMetrics = {
    prize_winner_messages : Nat64;
    audio_messages : Nat64;
    chat_messages : Nat64;
    edits : Nat64;
    icp_messages : Nat64;
    last_active : TimestampMillis;
    giphy_messages : Nat64;
    deleted_messages : Nat64;
    file_messages : Nat64;
    poll_votes : Nat64;
    text_messages : Nat64;
    message_reminders : Nat64;
    image_messages : Nat64;
    replies : Nat64;
    video_messages : Nat64;
    sns1_messages : Nat64;
    polls : Nat64;
    proposals : Nat64;
    reported_messages : Nat64;
    ckbtc_messages : Nat64;
    reactions : Nat64;
    kinic_messages : Nat64;
    custom_type_messages : Nat64;
    prize_messages : Nat64;
  };
  public type CommunityCanisterChannelSummary = {
    latest_message_sender_display_name : ?Text;
    channel_id : ChannelId;
    is_public : Bool;
    metrics : ChatMetrics;
    subtype : ?GroupSubtype;
    permissions_v2 : GroupPermissions;
    date_last_pinned : ?TimestampMillis;
    min_visible_event_index : EventIndex;
    gate : ?AccessGate;
    name : Text;
    latest_message_index : ?MessageIndex;
    description : Text;
    events_ttl : ?Milliseconds;
    last_updated : TimestampMillis;
    avatar_id : ?Nat;
    membership : ?GroupMembership;
    latest_event_index : EventIndex;
    history_visible_to_new_joiners : Bool;
    min_visible_message_index : MessageIndex;
    member_count : Nat32;
    events_ttl_last_updated : TimestampMillis;
    latest_message : ?MessageEventWrapper;
  };
  public type CommunityCanisterChannelSummaryUpdates = {
    latest_message_sender_display_name : ?Text;
    channel_id : ChannelId;
    is_public : ?Bool;
    metrics : ?ChatMetrics;
    subtype : GroupSubtypeUpdate;
    permissions_v2 : ?GroupPermissions;
    date_last_pinned : ?TimestampMillis;
    gate : AccessGateUpdate;
    name : ?Text;
    latest_message_index : ?MessageIndex;
    description : ?Text;
    events_ttl : EventsTimeToLiveUpdate;
    last_updated : TimestampMillis;
    avatar_id : DocumentIdUpdate;
    membership : ?GroupMembershipUpdates;
    latest_event_index : ?EventIndex;
    updated_events : [(?Nat32, Nat32, Nat64)];
    member_count : ?Nat32;
    events_ttl_last_updated : ?TimestampMillis;
    latest_message : ?MessageEventWrapper;
  };
  public type CommunityCanisterCommunitySummary = {
    is_public : Bool;
    permissions : CommunityPermissions;
    community_id : CommunityId;
    metrics : ChatMetrics;
    gate : ?AccessGate;
    name : Text;
    description : Text;
    last_updated : TimestampMillis;
    channels : [CommunityCanisterChannelSummary];
    user_groups : [UserGroup];
    avatar_id : ?Nat;
    membership : ?CommunityMembership;
    local_user_index_canister_id : CanisterId;
    frozen : ?FrozenGroupInfo;
    latest_event_index : EventIndex;
    banner_id : ?Nat;
    member_count : Nat32;
    primary_language : Text;
  };
  public type CommunityCanisterCommunitySummaryUpdates = {
    is_public : ?Bool;
    permissions : ?CommunityPermissions;
    community_id : CommunityId;
    channels_updated : [CommunityCanisterChannelSummaryUpdates];
    metrics : ?ChatMetrics;
    user_groups_deleted : [Nat32];
    gate : AccessGateUpdate;
    name : ?Text;
    description : ?Text;
    last_updated : TimestampMillis;
    channels_removed : [ChannelId];
    user_groups : [UserGroup];
    avatar_id : DocumentIdUpdate;
    channels_added : [CommunityCanisterChannelSummary];
    membership : ?CommunityMembershipUpdates;
    frozen : FrozenGroupUpdate;
    latest_event_index : ?EventIndex;
    banner_id : DocumentIdUpdate;
    member_count : ?Nat32;
    primary_language : ?Text;
  };
  public type CommunityId = CanisterId;
  public type CommunityMatch = {
    id : CommunityId;
    channel_count : Nat32;
    gate : ?AccessGate;
    name : Text;
    description : Text;
    moderation_flags : Nat32;
    score : Nat32;
    avatar_id : ?Nat;
    banner_id : ?Nat;
    member_count : Nat32;
    primary_language : Text;
  };
  public type CommunityMember = {
    role : CommunityRole;
    user_id : UserId;
    display_name : ?Text;
    date_added : TimestampMillis;
  };
  public type CommunityMembership = {
    role : CommunityRole;
    display_name : ?Text;
    joined : TimestampMillis;
    rules_accepted : Bool;
  };
  public type CommunityMembershipUpdates = {
    role : ?CommunityRole;
    display_name : TextUpdate;
    rules_accepted : ?Bool;
  };
  public type CommunityPermissionRole = { #Owners; #Admins; #Members };
  public type CommunityPermissions = {
    create_public_channel : CommunityPermissionRole;
    manage_user_groups : CommunityPermissionRole;
    update_details : CommunityPermissionRole;
    remove_members : CommunityPermissionRole;
    invite_users : CommunityPermissionRole;
    change_roles : CommunityPermissionRole;
    create_private_channel : CommunityPermissionRole;
  };
  public type CommunityRole = { #Member; #Admin; #Owner };
  public type CompletedCryptoTransaction = {
    #NNS : NnsCompletedCryptoTransaction;
    #ICRC1 : Icrc1CompletedCryptoTransaction;
  };
  public type CryptoContent = {
    recipient : UserId;
    caption : ?Text;
    transfer : CryptoTransaction;
  };
  public type CryptoTransaction = {
    #Failed : FailedCryptoTransaction;
    #Completed : CompletedCryptoTransaction;
    #Pending : PendingCryptoTransaction;
  };
  public type Cryptocurrency = {
    #InternetComputer;
    #CHAT;
    #SNS1;
    #KINIC;
    #CKBTC;
    #Other : Text;
  };
  public type CustomMessageContent = { data : Blob; kind : Text };
  public type CustomPermission = { subtype : Text; role : PermissionRole };
  public type Cycles = Nat;
  public type CyclesRegistrationFee = {
    recipient : Principal;
    valid_until : TimestampMillis;
    amount : Cycles;
  };
  public type DeletedContent = {
    timestamp : TimestampMillis;
    deleted_by : UserId;
  };
  public type DiamondMembershipDetails = {
    pay_in_chat : Bool;
    subscription : DiamondMembershipSubscription;
    recurring : ?DiamondMembershipSubscription;
    expires_at : TimestampMillis;
  };
  public type DiamondMembershipPlanDuration = {
    #OneYear;
    #Lifetime;
    #ThreeMonths;
    #OneMonth;
  };
  public type DiamondMembershipStatus = { #Inactive; #Lifetime; #Active };
  public type DiamondMembershipStatusFull = {
    #Inactive;
    #Lifetime;
    #Active : DiamondMembershipDetails;
  };
  public type DiamondMembershipSubscription = {
    #OneYear;
    #ThreeMonths;
    #Disabled;
    #OneMonth;
  };
  public type DirectChatCreated = {};
  public type DirectChatSummary = {
    read_by_them_up_to : ?MessageIndex;
    date_created : TimestampMillis;
    metrics : ChatMetrics;
    them : UserId;
    notifications_muted : Bool;
    latest_message_index : MessageIndex;
    events_ttl : ?Milliseconds;
    last_updated : TimestampMillis;
    latest_event_index : EventIndex;
    read_by_me_up_to : ?MessageIndex;
    archived : Bool;
    events_ttl_last_updated : TimestampMillis;
    my_metrics : ChatMetrics;
    latest_message : MessageEventWrapper;
  };
  public type DirectChatSummaryUpdates = {
    read_by_them_up_to : ?MessageIndex;
    metrics : ?ChatMetrics;
    notifications_muted : ?Bool;
    latest_message_index : ?MessageIndex;
    events_ttl : EventsTimeToLiveUpdate;
    last_updated : TimestampMillis;
    latest_event_index : ?EventIndex;
    updated_events : [(Nat32, Nat64)];
    read_by_me_up_to : ?MessageIndex;
    chat_id : ChatId;
    archived : ?Bool;
    events_ttl_last_updated : ?TimestampMillis;
    my_metrics : ?ChatMetrics;
    latest_message : ?MessageEventWrapper;
  };
  public type DirectMessageNotification = {
    image_url : ?Text;
    sender_display_name : ?Text;
    sender_avatar_id : ?Nat;
    sender : UserId;
    sender_name : Text;
    message_text : ?Text;
    message_type : Text;
    event_index : EventIndex;
    thread_root_message_index : ?MessageIndex;
    crypto_transfer : ?NotificationCryptoTransferDetails;
    message_index : MessageIndex;
  };
  public type DirectMessageTippedNotification = {
    tip : Text;
    username : Text;
    message_event_index : EventIndex;
    them : UserId;
    display_name : ?Text;
    user_avatar_id : ?Nat;
    thread_root_message_index : ?MessageIndex;
    message_index : MessageIndex;
  };
  public type DirectReactionAddedNotification = {
    username : Text;
    message_event_index : EventIndex;
    them : UserId;
    display_name : ?Text;
    user_avatar_id : ?Nat;
    thread_root_message_index : ?MessageIndex;
    reaction : Reaction;
    message_index : MessageIndex;
  };
  public type Document = { id : Nat; data : Blob; mime_type : Text };
  public type DocumentIdUpdate = { #NoChange; #SetToNone; #SetToSome : Nat };
  public type DocumentUpdate = { #NoChange; #SetToNone; #SetToSome : Document };
  public type EmptyArgs = {};
  public type EventIndex = Nat32;
  public type EventsSuccessResult = {
    expired_message_ranges : [(MessageIndex, MessageIndex)];
    chat_last_updated : TimestampMillis;
    events : [ChatEventWrapper];
    latest_event_index : Nat32;
    expired_event_ranges : [(EventIndex, EventIndex)];
  };
  public type EventsTimeToLiveUpdate = {
    #NoChange;
    #SetToNone;
    #SetToSome : Milliseconds;
  };
  public type EventsTimeToLiveUpdated = {
    new_ttl : ?Milliseconds;
    updated_by : UserId;
  };
  public type FailedCryptoTransaction = {
    #NNS : NnsFailedCryptoTransaction;
    #ICRC1 : Icrc1FailedCryptoTransaction;
  };
  public type FieldTooLongResult = {
    length_provided : Nat32;
    max_length : Nat32;
  };
  public type FieldTooShortResult = {
    length_provided : Nat32;
    min_length : Nat32;
  };
  public type FileContent = {
    name : Text;
    mime_type : Text;
    file_size : Nat32;
    blob_reference : ?BlobReference;
    caption : ?Text;
  };
  public type FileId = Nat;
  public type FrozenGroupInfo = {
    timestamp : TimestampMillis;
    frozen_by : UserId;
    reason : ?Text;
  };
  public type FrozenGroupUpdate = {
    #NoChange;
    #SetToNone;
    #SetToSome : FrozenGroupInfo;
  };
  public type GiphyContent = {
    title : Text;
    desktop : GiphyImageVariant;
    caption : ?Text;
    mobile : GiphyImageVariant;
  };
  public type GiphyImageVariant = {
    url : Text;
    height : Nat32;
    mime_type : Text;
    width : Nat32;
  };
  public type GovernanceProposalsSubtype = {
    is_nns : Bool;
    governance_canister_id : CanisterId;
  };
  public type GroupCanisterGroupChatSummary = {
    is_public : Bool;
    metrics : ChatMetrics;
    subtype : ?GroupSubtype;
    permissions_v2 : GroupPermissions;
    date_last_pinned : ?TimestampMillis;
    min_visible_event_index : EventIndex;
    gate : ?AccessGate;
    name : Text;
    role : GroupRole;
    wasm_version : BuildVersion;
    notifications_muted : Bool;
    latest_message_index : ?MessageIndex;
    description : Text;
    events_ttl : ?Milliseconds;
    last_updated : TimestampMillis;
    joined : TimestampMillis;
    avatar_id : ?Nat;
    rules_accepted : Bool;
    membership : ?GroupMembership;
    local_user_index_canister_id : CanisterId;
    latest_threads : [GroupCanisterThreadDetails];
    frozen : ?FrozenGroupInfo;
    latest_event_index : EventIndex;
    history_visible_to_new_joiners : Bool;
    min_visible_message_index : MessageIndex;
    mentions : [Mention];
    chat_id : ChatId;
    events_ttl_last_updated : TimestampMillis;
    participant_count : Nat32;
    my_metrics : ChatMetrics;
    latest_message : ?MessageEventWrapper;
  };
  public type GroupCanisterGroupChatSummaryUpdates = {
    is_public : ?Bool;
    metrics : ?ChatMetrics;
    subtype : GroupSubtypeUpdate;
    permissions_v2 : ?GroupPermissions;
    date_last_pinned : ?TimestampMillis;
    gate : AccessGateUpdate;
    name : ?Text;
    role : ?GroupRole;
    wasm_version : ?BuildVersion;
    notifications_muted : ?Bool;
    latest_message_index : ?MessageIndex;
    description : ?Text;
    events_ttl : EventsTimeToLiveUpdate;
    last_updated : TimestampMillis;
    unfollowed_threads : [MessageIndex];
    avatar_id : DocumentIdUpdate;
    rules_accepted : ?Bool;
    membership : ?GroupMembershipUpdates;
    latest_threads : [GroupCanisterThreadDetails];
    frozen : FrozenGroupUpdate;
    latest_event_index : ?EventIndex;
    updated_events : [(?Nat32, Nat32, Nat64)];
    mentions : [Mention];
    chat_id : ChatId;
    events_ttl_last_updated : ?TimestampMillis;
    participant_count : ?Nat32;
    my_metrics : ?ChatMetrics;
    latest_message : ?MessageEventWrapper;
  };
  public type GroupCanisterThreadDetails = {
    root_message_index : MessageIndex;
    last_updated : TimestampMillis;
    latest_event : EventIndex;
    latest_message : MessageIndex;
  };
  public type GroupChatCreated = {
    name : Text;
    description : Text;
    created_by : UserId;
  };
  public type GroupChatSummary = {
    is_public : Bool;
    metrics : ChatMetrics;
    subtype : ?GroupSubtype;
    permissions_v2 : GroupPermissions;
    date_last_pinned : ?TimestampMillis;
    min_visible_event_index : EventIndex;
    gate : ?AccessGate;
    name : Text;
    role : GroupRole;
    wasm_version : BuildVersion;
    notifications_muted : Bool;
    latest_message_index : ?MessageIndex;
    description : Text;
    events_ttl : ?Milliseconds;
    last_updated : TimestampMillis;
    joined : TimestampMillis;
    avatar_id : ?Nat;
    rules_accepted : Bool;
    local_user_index_canister_id : CanisterId;
    latest_threads : [ThreadSyncDetails];
    frozen : ?FrozenGroupInfo;
    latest_event_index : EventIndex;
    history_visible_to_new_joiners : Bool;
    read_by_me_up_to : ?MessageIndex;
    min_visible_message_index : MessageIndex;
    mentions : [Mention];
    chat_id : ChatId;
    date_read_pinned : ?TimestampMillis;
    archived : Bool;
    events_ttl_last_updated : TimestampMillis;
    participant_count : Nat32;
    my_metrics : ChatMetrics;
    latest_message : ?MessageEventWrapper;
  };
  public type GroupDescriptionChanged = {
    new_description : Text;
    previous_description : Text;
    changed_by : UserId;
  };
  public type GroupFrozen = { frozen_by : UserId; reason : ?Text };
  public type GroupGateUpdated = {
    updated_by : UserId;
    new_gate : ?AccessGate;
  };
  public type GroupInviteCodeChange = { #Enabled; #Disabled; #Reset };
  public type GroupInviteCodeChanged = {
    changed_by : UserId;
    change : GroupInviteCodeChange;
  };
  public type GroupMatch = {
    id : ChatId;
    subtype : ?GroupSubtype;
    gate : ?AccessGate;
    name : Text;
    description : Text;
    avatar_id : ?Nat;
    member_count : Nat32;
  };
  public type GroupMembership = {
    role : GroupRole;
    notifications_muted : Bool;
    joined : TimestampMillis;
    rules_accepted : Bool;
    latest_threads : [GroupCanisterThreadDetails];
    mentions : [Mention];
    my_metrics : ChatMetrics;
  };
  public type GroupMembershipUpdates = {
    role : ?GroupRole;
    notifications_muted : ?Bool;
    unfollowed_threads : [MessageIndex];
    rules_accepted : ?Bool;
    latest_threads : [GroupCanisterThreadDetails];
    mentions : [Mention];
    my_metrics : ?ChatMetrics;
  };
  public type GroupMessageNotification = {
    image_url : ?Text;
    group_avatar_id : ?Nat;
    sender_display_name : ?Text;
    sender : UserId;
    sender_name : Text;
    message_text : ?Text;
    message_type : Text;
    chat_id : ChatId;
    event_index : EventIndex;
    thread_root_message_index : ?MessageIndex;
    group_name : Text;
    crypto_transfer : ?NotificationCryptoTransferDetails;
    message_index : MessageIndex;
  };
  public type GroupMessageTippedNotification = {
    tip : Text;
    tipped_by_display_name : ?Text;
    group_avatar_id : ?Nat;
    message_event_index : EventIndex;
    tipped_by : UserId;
    tipped_by_name : Text;
    chat_id : ChatId;
    thread_root_message_index : ?MessageIndex;
    group_name : Text;
    message_index : MessageIndex;
  };
  public type GroupNameChanged = {
    changed_by : UserId;
    new_name : Text;
    previous_name : Text;
  };
  public type GroupPermissions = {
    mention_all_members : PermissionRole;
    delete_messages : PermissionRole;
    remove_members : PermissionRole;
    update_group : PermissionRole;
    message_permissions : MessagePermissions;
    invite_users : PermissionRole;
    thread_permissions : ?MessagePermissions;
    change_roles : PermissionRole;
    add_members : PermissionRole;
    pin_messages : PermissionRole;
    react_to_messages : PermissionRole;
  };
  public type GroupReactionAddedNotification = {
    added_by_name : Text;
    group_avatar_id : ?Nat;
    message_event_index : EventIndex;
    added_by : UserId;
    added_by_display_name : ?Text;
    chat_id : ChatId;
    thread_root_message_index : ?MessageIndex;
    group_name : Text;
    reaction : Reaction;
    message_index : MessageIndex;
  };
  public type GroupReplyContext = { event_index : EventIndex };
  public type GroupRole = { #Participant; #Admin; #Moderator; #Owner };
  public type GroupRulesChanged = {
    changed_by : UserId;
    enabled : Bool;
    prev_enabled : Bool;
  };
  public type GroupSubtype = {
    #GovernanceProposals : GovernanceProposalsSubtype;
  };
  public type GroupSubtypeUpdate = {
    #NoChange;
    #SetToNone;
    #SetToSome : GroupSubtype;
  };
  public type GroupUnfrozen = { unfrozen_by : UserId };
  public type GroupVisibilityChanged = {
    changed_by : UserId;
    now_public : Bool;
  };
  public type Hash = Blob;
  public type ICP = Tokens;
  public type ICPRegistrationFee = {
    recipient : AccountIdentifier;
    valid_until : TimestampMillis;
    amount : ICP;
  };
  public type Icrc1Account = { owner : Principal; subaccount : ?Blob };
  public type Icrc1AccountOrMint = { #Mint; #Account : Icrc1Account };
  public type Icrc1CompletedCryptoTransaction = {
    to : Icrc1AccountOrMint;
    fee : Nat;
    created : TimestampNanos;
    token : Cryptocurrency;
    block_index : BlockIndex;
    from : Icrc1AccountOrMint;
    memo : ?Memo;
    ledger : CanisterId;
    amount : Nat;
  };
  public type Icrc1FailedCryptoTransaction = {
    to : Icrc1AccountOrMint;
    fee : Nat;
    created : TimestampNanos;
    token : Cryptocurrency;
    from : Icrc1AccountOrMint;
    memo : ?Memo;
    error_message : Text;
    ledger : CanisterId;
    amount : Nat;
  };
  public type Icrc1PendingCryptoTransaction = {
    to : Icrc1Account;
    fee : Nat;
    created : TimestampNanos;
    token : Cryptocurrency;
    memo : ?Memo;
    ledger : CanisterId;
    amount : Nat;
  };
  public type ImageContent = {
    height : Nat32;
    mime_type : Text;
    blob_reference : ?BlobReference;
    thumbnail_data : Text;
    caption : ?Text;
    width : Nat32;
  };
  public type IndexedNotification = {
    value : NotificationEnvelope;
    index : Nat64;
  };
  public type InvalidPollReason = {
    #DuplicateOptions;
    #TooFewOptions : Nat32;
    #TooManyOptions : Nat32;
    #OptionTooLong : Nat32;
    #EndDateInThePast;
    #PollsNotValidForDirectChats;
  };
  public type MembersAddedToDefaultChannel = { count : Nat32 };
  public type Memo = Blob;
  public type Mention = {
    message_id : MessageId;
    event_index : EventIndex;
    thread_root_message_index : ?MessageIndex;
    mentioned_by : UserId;
    message_index : MessageIndex;
  };
  public type Message = {
    forwarded : Bool;
    content : MessageContent;
    edited : Bool;
    tips : [(CanisterId, [(UserId, Nat)])];
    last_updated : ?TimestampMillis;
    sender : UserId;
    thread_summary : ?ThreadSummary;
    message_id : MessageId;
    replies_to : ?ReplyContext;
    reactions : [(Text, [UserId])];
    message_index : MessageIndex;
  };
  public type MessageContent = {
    #ReportedMessage : ReportedMessage;
    #Giphy : GiphyContent;
    #File : FileContent;
    #Poll : PollContent;
    #Text : TextContent;
    #P2PSwap : P2PSwapContent;
    #Image : ImageContent;
    #Prize : PrizeContent;
    #Custom : CustomMessageContent;
    #GovernanceProposal : ProposalContent;
    #PrizeWinner : PrizeWinnerContent;
    #Audio : AudioContent;
    #Crypto : CryptoContent;
    #Video : VideoContent;
    #Deleted : DeletedContent;
    #MessageReminderCreated : MessageReminderCreated;
    #MessageReminder : MessageReminder;
  };
  public type MessageContentInitial = {
    #Giphy : GiphyContent;
    #File : FileContent;
    #Poll : PollContent;
    #Text : TextContent;
    #P2PSwap : P2PSwapContentInitial;
    #Image : ImageContent;
    #Prize : PrizeContentInitial;
    #Custom : CustomMessageContent;
    #GovernanceProposal : ProposalContent;
    #Audio : AudioContent;
    #Crypto : CryptoContent;
    #Video : VideoContent;
    #Deleted : DeletedContent;
    #MessageReminderCreated : MessageReminderCreated;
    #MessageReminder : MessageReminder;
  };
  public type MessageEventWrapper = {
    event : Message;
    timestamp : TimestampMillis;
    index : EventIndex;
    correlation_id : Nat64;
    expires_at : ?TimestampMillis;
  };
  public type MessageId = Nat;
  public type MessageIndex = Nat32;
  public type MessageIndexRange = { end : MessageIndex; start : MessageIndex };
  public type MessageMatch = {
    content : MessageContent;
    sender : UserId;
    score : Nat32;
    message_index : MessageIndex;
  };
  public type MessagePermissions = {
    audio : ?PermissionRole;
    video : ?PermissionRole;
    custom : [CustomPermission];
    file : ?PermissionRole;
    poll : ?PermissionRole;
    text : ?PermissionRole;
    crypto : ?PermissionRole;
    giphy : ?PermissionRole;
    default : PermissionRole;
    image : ?PermissionRole;
    prize : ?PermissionRole;
    p2p_swap : ?PermissionRole;
  };
  public type MessagePinned = {
    pinned_by : UserId;
    message_index : MessageIndex;
  };
  public type MessageReminder = { notes : ?Text; reminder_id : Nat64 };
  public type MessageReminderCreated = {
    hidden : Bool;
    notes : ?Text;
    remind_at : TimestampMillis;
    reminder_id : Nat64;
  };
  public type MessageReport = {
    notes : ?Text;
    timestamp : TimestampMillis;
    reported_by : UserId;
    reason_code : Nat32;
  };
  public type MessageUnpinned = {
    due_to_message_deleted : Bool;
    unpinned_by : UserId;
    message_index : MessageIndex;
  };
  public type MessagesSuccessResult = {
    messages : [MessageEventWrapper];
    chat_last_updated : TimestampMillis;
    latest_event_index : EventIndex;
  };
  public type Milliseconds = Nat64;
  public type MultiUserChat = {
    #Group : ChatId;
    #Channel : (CommunityId, ChannelId);
  };
  public type NnsCompletedCryptoTransaction = {
    to : NnsCryptoAccount;
    fee : Tokens;
    created : TimestampNanos;
    token : Cryptocurrency;
    transaction_hash : TransactionHash;
    block_index : BlockIndex;
    from : NnsCryptoAccount;
    memo : Nat64;
    ledger : CanisterId;
    amount : Tokens;
  };
  public type NnsCryptoAccount = { #Mint; #Account : AccountIdentifier };
  public type NnsFailedCryptoTransaction = {
    to : NnsCryptoAccount;
    fee : Tokens;
    created : TimestampNanos;
    token : Cryptocurrency;
    transaction_hash : TransactionHash;
    from : NnsCryptoAccount;
    memo : Nat64;
    error_message : Text;
    ledger : CanisterId;
    amount : Tokens;
  };
  public type NnsNeuronId = Nat64;
  public type NnsPendingCryptoTransaction = {
    to : NnsUserOrAccount;
    fee : ?Tokens;
    created : TimestampNanos;
    token : Cryptocurrency;
    memo : ?Nat64;
    ledger : CanisterId;
    amount : Tokens;
  };
  public type NnsProposal = {
    id : ProposalId;
    url : Text;
    status : ProposalDecisionStatus;
    payload_text_rendering : ?Text;
    tally : Tally;
    title : Text;
    created : TimestampMillis;
    topic : Int32;
    last_updated : TimestampMillis;
    deadline : TimestampMillis;
    reward_status : ProposalRewardStatus;
    summary : Text;
    proposer : NnsNeuronId;
  };
  public type NnsUserOrAccount = {
    #User : UserId;
    #Account : AccountIdentifier;
  };
  public type Notification = {
    #GroupReactionAdded : GroupReactionAddedNotification;
    #ChannelMessageTipped : ChannelMessageTippedNotification;
    #DirectMessageTipped : DirectMessageTippedNotification;
    #DirectMessage : DirectMessageNotification;
    #ChannelReactionAdded : ChannelReactionAddedNotification;
    #DirectReactionAdded : DirectReactionAddedNotification;
    #GroupMessage : GroupMessageNotification;
    #GroupMessageTipped : GroupMessageTippedNotification;
    #AddedToChannel : AddedToChannelNotification;
    #ChannelMessage : ChannelMessageNotification;
  };
  public type NotificationCryptoTransferDetails = {
    recipient : UserId;
    ledger : CanisterId;
    recipient_username : ?Text;
    amount : Nat;
    symbol : Text;
  };
  public type NotificationEnvelope = {
    notification_bytes : Blob;
    recipients : [UserId];
    timestamp : TimestampMillis;
  };
  public type OptionalCommunityPermissions = {
    create_public_channel : ?CommunityPermissionRole;
    manage_user_groups : ?CommunityPermissionRole;
    update_details : ?CommunityPermissionRole;
    remove_members : ?CommunityPermissionRole;
    invite_users : ?CommunityPermissionRole;
    change_roles : ?CommunityPermissionRole;
    create_private_channel : ?CommunityPermissionRole;
  };
  public type OptionalGroupPermissions = {
    mention_all_members : ?PermissionRole;
    delete_messages : ?PermissionRole;
    remove_members : ?PermissionRole;
    update_group : ?PermissionRole;
    message_permissions : ?OptionalMessagePermissions;
    invite_users : ?PermissionRole;
    thread_permissions : OptionalMessagePermissionsUpdate;
    change_roles : ?PermissionRole;
    pin_messages : ?PermissionRole;
    react_to_messages : ?PermissionRole;
  };
  public type OptionalMessagePermissions = {
    custom_updated : [CustomPermission];
    audio : PermissionRoleUpdate;
    video : PermissionRoleUpdate;
    file : PermissionRoleUpdate;
    poll : PermissionRoleUpdate;
    text : PermissionRoleUpdate;
    crypto : PermissionRoleUpdate;
    giphy : PermissionRoleUpdate;
    custom_deleted : [Text];
    default : ?PermissionRole;
    p2p_trade : PermissionRoleUpdate;
    image : PermissionRoleUpdate;
    prize : PermissionRoleUpdate;
    p2p_swap : PermissionRoleUpdate;
  };
  public type OptionalMessagePermissionsUpdate = {
    #NoChange;
    #SetToNone;
    #SetToSome : OptionalMessagePermissions;
  };
  public type P2PSwapAccepted = { accepted_by : UserId; token1_txn_in : Nat64 };
  public type P2PSwapCancelled = { token0_txn_out : ?Nat64 };
  public type P2PSwapCompleted = {
    accepted_by : UserId;
    token1_txn_out : Nat64;
    token0_txn_out : Nat64;
    token1_txn_in : Nat64;
  };
  public type P2PSwapContent = {
    status : P2PSwapStatus;
    token0_txn_in : Nat64;
    swap_id : Nat32;
    token0_amount : Nat;
    token0 : TokenInfo;
    token1 : TokenInfo;
    caption : ?Text;
    token1_amount : Nat;
    expires_at : TimestampMillis;
  };
  public type P2PSwapContentInitial = {
    token0_amount : Nat;
    token0 : TokenInfo;
    token1 : TokenInfo;
    caption : ?Text;
    token1_amount : Nat;
    expires_in : Milliseconds;
  };
  public type P2PSwapExpired = P2PSwapCancelled;
  public type P2PSwapReserved = { reserved_by : UserId };
  public type P2PSwapStatus = {
    #Reserved : P2PSwapReserved;
    #Open;
    #Accepted : P2PSwapAccepted;
    #Cancelled : P2PSwapCancelled;
    #Completed : P2PSwapCompleted;
    #Expired : P2PSwapExpired;
  };
  public type Participant = {
    role : GroupRole;
    user_id : UserId;
    date_added : TimestampMillis;
  };
  public type ParticipantJoined = { user_id : UserId; invited_by : ?UserId };
  public type ParticipantLeft = { user_id : UserId };
  public type ParticipantsAdded = {
    user_ids : [UserId];
    unblocked : [UserId];
    added_by : UserId;
  };
  public type ParticipantsRemoved = {
    user_ids : [UserId];
    removed_by : UserId;
  };
  public type PaymentGate = {
    fee : Nat;
    ledger_canister_id : CanisterId;
    amount : Nat;
  };
  public type PendingCryptoTransaction = {
    #NNS : NnsPendingCryptoTransaction;
    #ICRC1 : Icrc1PendingCryptoTransaction;
  };
  public type PermissionRole = {
    #None;
    #Moderators;
    #Owner;
    #Admins;
    #Members;
  };
  public type PermissionRoleUpdate = {
    #NoChange;
    #SetToNone;
    #SetToSome : PermissionRole;
  };
  public type PermissionsChanged = {
    changed_by : UserId;
    old_permissions_v2 : GroupPermissions;
    new_permissions_v2 : GroupPermissions;
  };
  public type PinnedMessageUpdate = {
    #NoChange;
    #SetToNone;
    #SetToSome : MessageIndex;
  };
  public type PollConfig = {
    allow_multiple_votes_per_user : Bool;
    text : ?Text;
    show_votes_before_end_date : Bool;
    end_date : ?TimestampMillis;
    anonymous : Bool;
    allow_user_to_change_vote : Bool;
    options : [Text];
  };
  public type PollContent = {
    votes : PollVotes;
    ended : Bool;
    config : PollConfig;
  };
  public type PollVotes = { total : TotalPollVotes; user : [Nat32] };
  public type PrizeContent = {
    token : Cryptocurrency;
    end_date : TimestampMillis;
    prizes_remaining : Nat32;
    prizes_pending : Nat32;
    caption : ?Text;
    diamond_only : Bool;
    winners : [UserId];
  };
  public type PrizeContentInitial = {
    end_date : TimestampMillis;
    caption : ?Text;
    prizes : [Tokens];
    transfer : CryptoTransaction;
    diamond_only : Bool;
  };
  public type PrizeWinnerContent = {
    transaction : CompletedCryptoTransaction;
    winner : UserId;
    prize_message : MessageIndex;
  };
  public type Proposal = { #NNS : NnsProposal; #SNS : SnsProposal };
  public type ProposalContent = {
    my_vote : ?Bool;
    governance_canister_id : CanisterId;
    proposal : Proposal;
  };
  public type ProposalDecisionStatus = {
    #Failed;
    #Open;
    #Rejected;
    #Executed;
    #Adopted;
    #Unspecified;
  };
  public type ProposalId = Nat64;
  public type ProposalRewardStatus = {
    #ReadyToSettle;
    #AcceptVotes;
    #Unspecified;
    #Settled;
  };
  public type PublicGroupSummary = {
    is_public : Bool;
    subtype : ?GroupSubtype;
    gate : ?AccessGate;
    name : Text;
    wasm_version : BuildVersion;
    latest_message_index : ?MessageIndex;
    description : Text;
    events_ttl : ?Milliseconds;
    last_updated : TimestampMillis;
    avatar_id : ?Nat;
    local_user_index_canister_id : CanisterId;
    frozen : ?FrozenGroupInfo;
    latest_event_index : EventIndex;
    history_visible_to_new_joiners : Bool;
    chat_id : ChatId;
    events_ttl_last_updated : TimestampMillis;
    participant_count : Nat32;
    latest_message : ?MessageEventWrapper;
  };
  public type PushEventResult = {
    timestamp : TimestampMillis;
    index : EventIndex;
    expires_at : ?TimestampMillis;
  };
  public type Reaction = Text;
  public type RegistrationFee = {
    #ICP : ICPRegistrationFee;
    #Cycles : CyclesRegistrationFee;
  };
  public type ReplyContext = {
    chat_if_other : ?(Chat, ?MessageIndex);
    event_index : EventIndex;
  };
  public type ReportedMessage = { count : Nat32; reports : [MessageReport] };
  public type ReserveP2PSwapResult = {
    #Success : ReserveP2PSwapSuccess;
    #SwapNotFound;
    #Failure : P2PSwapStatus;
  };
  public type ReserveP2PSwapSuccess = {
    created : TimestampMillis;
    content : P2PSwapContent;
    created_by : UserId;
  };
  public type RoleChanged = {
    user_ids : [UserId];
    changed_by : UserId;
    old_role : GroupRole;
    new_role : GroupRole;
  };
  public type Rules = { text : Text; enabled : Bool };
  public type SelectedGroupUpdates = {
    blocked_users_removed : [UserId];
    pinned_messages_removed : [MessageIndex];
    invited_users : ?[UserId];
    last_updated : TimestampMillis;
    members_added_or_updated : [Participant];
    pinned_messages_added : [MessageIndex];
    chat_rules : ?VersionedRules;
    members_removed : [UserId];
    timestamp : TimestampMillis;
    latest_event_index : EventIndex;
    blocked_users_added : [UserId];
  };
  public type SnsNeuronGate = {
    min_stake_e8s : ?Nat64;
    min_dissolve_delay : ?Milliseconds;
    governance_canister_id : CanisterId;
  };
  public type SnsNeuronId = Blob;
  public type SnsProposal = {
    id : ProposalId;
    url : Text;
    status : ProposalDecisionStatus;
    payload_text_rendering : ?Text;
    tally : Tally;
    title : Text;
    created : TimestampMillis;
    action : Nat64;
    minimum_yes_proportion_of_total : Nat32;
    last_updated : TimestampMillis;
    deadline : TimestampMillis;
    reward_status : ProposalRewardStatus;
    summary : Text;
    proposer : SnsNeuronId;
    minimum_yes_proportion_of_exercised : Nat32;
  };
  public type Subscription = {
    value : SubscriptionInfo;
    last_active : TimestampMillis;
  };
  public type SubscriptionInfo = { endpoint : Text; keys : SubscriptionKeys };
  public type SubscriptionKeys = { auth : Text; p256dh : Text };
  public type SwapStatusError = {
    #Reserved : SwapStatusErrorReserved;
    #Accepted : SwapStatusErrorAccepted;
    #Cancelled : SwapStatusErrorCancelled;
    #Completed : SwapStatusErrorCompleted;
    #Expired : SwapStatusErrorExpired;
  };
  public type SwapStatusErrorAccepted = {
    accepted_by : UserId;
    token1_txn_in : Nat64;
  };
  public type SwapStatusErrorCancelled = { token0_txn_out : ?Nat64 };
  public type SwapStatusErrorCompleted = {
    accepted_by : UserId;
    token1_txn_out : Nat64;
    token0_txn_out : Nat64;
    token1_txn_in : Nat64;
  };
  public type SwapStatusErrorExpired = { token0_txn_out : ?Nat64 };
  public type SwapStatusErrorReserved = { reserved_by : UserId };
  public type Tally = {
    no : Nat64;
    yes : Nat64;
    total : Nat64;
    timestamp : TimestampMillis;
  };
  public type TextContent = { text : Text };
  public type TextUpdate = { #NoChange; #SetToNone; #SetToSome : Text };
  public type ThreadPreview = {
    latest_replies : [MessageEventWrapper];
    total_replies : Nat32;
    root_message : MessageEventWrapper;
  };
  public type ThreadSummary = {
    latest_event_timestamp : TimestampMillis;
    participant_ids : [UserId];
    reply_count : Nat32;
    latest_event_index : EventIndex;
    followed_by_me : Bool;
  };
  public type ThreadSyncDetails = {
    root_message_index : MessageIndex;
    last_updated : TimestampMillis;
    read_up_to : ?MessageIndex;
    latest_event : ?EventIndex;
    latest_message : ?MessageIndex;
  };
  public type TimestampMillis = Nat64;
  public type TimestampNanos = Nat64;
  public type TimestampUpdate = {
    #NoChange;
    #SetToNone;
    #SetToSome : TimestampMillis;
  };
  public type TokenBalanceGate = {
    min_balance : Nat;
    ledger_canister_id : CanisterId;
  };
  public type TokenInfo = {
    fee : Nat;
    decimals : Nat8;
    token : Cryptocurrency;
    ledger : CanisterId;
  };
  public type Tokens = { e8s : Nat64 };
  public type TotalPollVotes = {
    #Anonymous : [(Nat32, Nat32)];
    #Visible : [(Nat32, [UserId])];
    #Hidden : Nat32;
  };
  public type TransactionHash = Blob;
  public type UpdatedRules = {
    new_version : Bool;
    text : Text;
    enabled : Bool;
  };
  public type User = { username : Text; user_id : UserId };
  public type UserGroup = {
    members : Nat32;
    name : Text;
    user_group_id : Nat32;
  };
  public type UserId = CanisterId;
  public type UserSummary = {
    username : Text;
    diamond_member : Bool;
    diamond_membership_status : DiamondMembershipStatus;
    user_id : UserId;
    is_bot : Bool;
    display_name : ?Text;
    avatar_id : ?Nat;
    suspended : Bool;
  };
  public type UsersBlocked = { user_ids : [UserId]; blocked_by : UserId };
  public type UsersInvited = { user_ids : [UserId]; invited_by : UserId };
  public type UsersUnblocked = { user_ids : [UserId]; unblocked_by : UserId };
  public type VerifiedCredentialGate = { credential : Text; issuer : Text };
  public type Version = Nat32;
  public type VersionedRules = {
    text : Text;
    version : Version;
    enabled : Bool;
  };
  public type VideoContent = {
    height : Nat32;
    image_blob_reference : ?BlobReference;
    video_blob_reference : ?BlobReference;
    mime_type : Text;
    thumbnail_data : Text;
    caption : ?Text;
    width : Nat32;
  };
  public type VoteOperation = { #RegisterVote; #DeleteVote };

  
  public type GroupLookupResponse = {
      #Success;
      #AlreadyInGroup;
      #GroupNotFound;
      #NotInvited;
      #GateCheckFailed;
      #ParticipantLimitReached;
      #Blocked;
      #UserSuspended;
      #ChatFrozen;
      #InternalError : Text;
  };

  public type InitializeBotResponse = {
    #Success;
    #EndDateInPast;
    #AlreadyRegistered;
    #UserLimitReached;
    #UsernameTaken;
    #UsernameInvalid;
    #UsernameTooShort : Nat16;
    #UsernameTooLong : Nat16;
    #InsufficientCyclesProvided : Nat;
    #InternalError : Text;
  };

  public type JoinGroupArgs =  {
    chat_id : Principal;
    invite_code : ?Nat64;
    correlation_id : Nat64;
  };


  public type JoinGroupResponse =  {
    #Success : {};
    #AlreadyInGroupV2 : {};
    #AlreadyInGroup;
    #GateCheckFailed : {};
    #GroupNotFound;
    #GroupNotPublic;
    #NotInvited;
    #ParticipantLimitReached : Nat32;
    #Blocked;
    #UserSuspended;
    #ChatFrozen;
    #InternalError : Text;
  };

  public type SendMessageV2Args =  {
      message_id : Nat;
      thread_root_message_index : ?Nat32;
      content : MessageContentInitial;
      sender_name : Text;
      sender_display_name : ?Text;
      replies_to : ?{event_index : Nat32};
      mentioned : [User];
      forwarding : Bool;
      rules_accepted : ?Nat32;
      message_filter_failed : ?Nat64;
      correlation_id : Nat64;
      block_level_markdown : Bool;
  };

  public type SendMessageResponse = {
      #Success : {
          event_index : Nat32;
          message_index : Nat32;
      };
      #ChannelNotFound;
      #ThreadMessageNotFound;
      #MessageEmpty;
      #TextTooLong : Nat32;
      #InvalidPoll : InvalidPollReason;
      #NotAuthorized;
      #UserNotInCommunity;
      #UserNotInChannel;
      #UserSuspended;
      #InvalidRequest : Text;
      #CommunityFrozen;
      #RulesNotAccepted;
      #CommunityRulesNotAccepted;
  };

  public type EditMessageV2Args = {
      thread_root_message_index : ?Nat32;
      message_id : MessageId;
      content : MessageContentInitial;
      correlation_id : Nat64;
  };

  public type EditMessageResponse =  {
      #Success;
      #MessageNotFound;
      #CallerNotInGroup;
      #UserSuspended;
      #ChatFrozen;
  };


  // public type PublicGroupSummary = {
  //   local_user_index_canister_id : Principal;
  // };

    type C2CReplyContext = {
    #ThisChat : MessageId;
    #OtherChat : (Chat, ?MessageIndex, EventIndex);
  };

  type HandleMessageArgs = {
    message_id: MessageId;
    sender_message_index: MessageIndex;
    sender_name: Text;
    content: MessageContent;
    replies_to: ?C2CReplyContext;
    forwarding: Bool;
    correlation_id: Nat64;
};


  type BotMessage = {
    content: MessageContentInitial;
    message_id: ?MessageId;
  };

 type SuccessResult = {
    bot_name: Text;
    bot_display_name: ?Text;
    messages: [BotMessage];
  };

  type Response = {
    #Success : SuccessResult
  };

  public type PublicSummarySuccessResult = {
      summary: PublicGroupSummary
  };

  public type MessagesByMessageIndexArgs = {
    thread_root_message_index : ?MessageIndex;
    messages: [MessageIndex];
    latest_known_update: ?Nat64;
  };

  public type MessagesResponse = {
    messages: [MessageEventWrapper];
    latest_event_index: EventIndex;
    chat_last_updated: TimestampMillis;
  };

  public type MessagesByMessageIndexResponse = {
    #Success: MessagesResponse;
    #CallerNotInGroup;
    #ThreadMessageNotFound;
    #ReplicaNotUpToDateV2: TimestampMillis;
  };

  //Actors

  public type UserIndexCanister = actor {
    c2c_register_bot : ({username : Text; display_name : ?Text}) -> async InitializeBotResponse;
  };

  public type LocalUserIndexCanister = actor {
    join_group : (JoinGroupArgs) -> async JoinGroupResponse;
  };

  public type SendChannelMessageArgs = {
   channel_id: ChannelId;
   thread_root_message_index: ?MessageIndex;
   message_id: MessageId;
   content: MessageContent;
   sender_name: Text;
   sender_display_name: ?Text;
   replies_to: ?GroupReplyContext;
   mentioned: [User];
   forwarding: Bool;
   block_level_markdown: Bool;
   community_rules_accepted: ?Version;
   channel_rules_accepted: ?Version;
   message_filter_failed: ?Nat64;
};

public type  VerifiedCredentialGateArgs = {
  user_ii_principal: Principal;
  credential_jwt: Text;
  ii_origin: Text;
};

 public type JoinCommunityArgs = {
    user_id: UserId;
    principal: Principal;
    invite_code: ?Nat64;
    is_platform_moderator: Bool;
    is_bot: Bool;
    diamond_membership_expires_at: ?Int;
    verified_credential_args:?VerifiedCredentialGateArgs;
  };

 public type JoinCommunityResponse = {
    #Success;
    #AlreadyInCommunity;
    #GateCheckFailed;
    #NotInvited;
    #UserBlocked;
    #MemberLimitReached : Nat32;
    #CommunityFrozen;
    #InternalError : Text;
};

  public type GroupIndexCanister = actor {
     public_summary : query ({invite_code : ?Nat64;}) -> async {
      #Success: PublicSummarySuccessResult;
      #NotAuthorized
    };
    messages_by_message_index : query (MessagesByMessageIndexArgs) -> async (MessagesByMessageIndexResponse);
    send_message_v2 : (SendMessageV2Args) -> async (SendMessageResponse);
    edit_message_v2 : (EditMessageV2Args) -> async (EditMessageResponse);
  };

  public type CommunityIndexCanister = actor {
    send_message : (SendChannelMessageArgs) -> async (SendMessageResponse);
    join_community : (JoinCommunityArgs) -> async (JoinCommunityResponse);
  };

}

