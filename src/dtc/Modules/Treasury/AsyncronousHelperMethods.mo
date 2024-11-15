import TreasuryTypes "../../Types/Treasury/types";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Governance "../../NNS/Governance"; 
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import NeuronManager "../HTTPRequests/NeuronManager";

module{

    public func manageNeuron( 
        neuronDataMap: TreasuryTypes.NeuronsDataMap,
        pendingActionsMap: TreasuryTypes.PendingActionsMap,
        transformFn: NeuronManager.TransformFnSignature,
        args: Governance.ManageNeuron,
        proposer: ?Principal,
        treasuryCanisterId: ?Principal,
        selfAuthPrincipal: Principal,
        publicKey: Blob
    ): async Result.Result<(), TreasuryTypes.Error> {
        
        let ?neuronId = args.id else { Debug.trap("No neuronId in request"); };
        let ?command = args.command else { Debug.trap("No command in request"); };

        let pendingActionId : Text = switch(command){
            case(#Spawn(_)) { "spawn_"#Nat64.toText(neuronId.id); };
            case(#Follow(_)) { "follow_"#Nat64.toText(neuronId.id); };
            case(#Configure(_)) { "configure_"#Nat64.toText(neuronId.id); };
            case(#Disburse(_)) { 
                let ?{contributions} = neuronDataMap.get(Nat64.toText(neuronId.id)) else { throw Error.reject("No neuron found") };
                label isCollateralized for((userPrincipal, {collateralized_stake_e8s }) in Iter.fromArray(contributions)){
                    let ?collateral = collateralized_stake_e8s else continue isCollateralized;
                    if(collateral > 0) { throw Error.reject("Neuron is collateralized. Cannot disburse from collateralized neuron.") };
                };
                "disburse_"#Nat64.toText(neuronId.id); 
            };
            case(#ClaimOrRefresh(_)) { "claimOrRefresh_"#Nat64.toText(neuronId.id);};
            case(_) { return #err(#ActionNotSupported) };
        };
        let newPendingAction: TreasuryTypes.PendingAction = {
            expectedHttpResponseType = ?#GovernanceManageNeuronResponse({neuronId = ?neuronId.id; memo = null; proposer; treasuryCanisterId; });
            function = #ManageNeuron({  input = {args; selfAuthPrincipal; public_key = publicKey; transformFn;} });
        };
        pendingActionsMap.put(pendingActionId, newPendingAction);
        ignore resolvePendingActionFromQueue( pendingActionsMap, transformFn);
        return #ok(());
    };

    public func resolvePendingActionFromQueue( pendingActionsMap: TreasuryTypes.PendingActionsMap, transformFn: NeuronManager.TransformFnSignature ): async () {

        func resolvePendingAction_(identifier: Text, action: TreasuryTypes.PendingAction): async () {
            
            let ({response; requestId; ingress_expiry;}, selfAuthPrincipal, publicKey) = switch(action.function){
                case (#ManageNeuron({input;})) { (await NeuronManager.manageNeuron(input),input.selfAuthPrincipal, input.public_key ); };
                case (#GetNeuronData({input;})){ (await NeuronManager.getNeuronData(input), input.selfAuthPrincipal, input.public_key); };
            };
            let ?expectedResponseType = action.expectedHttpResponseType else { throw Error.reject("No expected response type for action: "#identifier); };
            let readRequestResponseInput = {response; requestId; expiry = ingress_expiry; expectedResponseType;};
            let failedAttempts: Nat = 0;
            ignore await NeuronManager.readRequestResponse(readRequestResponseInput, selfAuthPrincipal, publicKey, transformFn, failedAttempts);
        };

        let pendingActionsArray = Iter.toArray(pendingActionsMap.entries());
        let length = Array.size(pendingActionsArray);
        if(length == 0) throw Error.reject("No pending actions to resolve");
        var index = 0;
        label loop_ while(index < length){
            let (identifier, action) = pendingActionsArray[index];
            ignore resolvePendingAction_(identifier, action); 
            index += 1;
        };


    };
};