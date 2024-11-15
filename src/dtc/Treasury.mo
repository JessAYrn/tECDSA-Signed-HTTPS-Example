import Governance "NNS/Governance";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Text "mo:base/Text";
import TreasuryTypes "Types/Treasury/types";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import IC "Types/IC/types";
import Debug "mo:base/Debug";
import AsyncronousHelperMethods "Modules/Treasury/AsyncronousHelperMethods";

shared actor class Treasury () = this {

    private stable var selfAuthenticatingPrincipal : ?Principal = null;
    private stable var public_key : ?Blob = null;
    private stable var pendingActionsArray : TreasuryTypes.PendingActionArray = [];
    private var pendingActionsMap : TreasuryTypes.PendingActionsMap = HashMap.fromIter<Text, TreasuryTypes.PendingAction>( Iter.fromArray(pendingActionsArray), Iter.size(Iter.fromArray(pendingActionsArray)), Text.equal, Text.hash );
    private stable var usersTreasuryDataArray : TreasuryTypes.UsersTreasuryDataArray = [];
    private var usersTreasuryDataMap : TreasuryTypes.UsersTreasuryDataMap = HashMap.fromIter<TreasuryTypes.PrincipalAsText, TreasuryTypes.UserTreasuryData>(Iter.fromArray(usersTreasuryDataArray), Iter.size(Iter.fromArray(usersTreasuryDataArray)), Text.equal, Text.hash);
    private stable var neuronDataArray : TreasuryTypes.NeuronsDataArray = [];
    private var neuronDataMap : TreasuryTypes.NeuronsDataMap = HashMap.fromIter<TreasuryTypes.NeuronIdAsText, TreasuryTypes.NeuronData>(Iter.fromArray(neuronDataArray), Iter.size(Iter.fromArray(neuronDataArray)), Text.equal, Text.hash);

    private func getSelfAuthenticatingPrincipalAndPublicKey_(): {selfAuthPrincipal: Principal; publicKey: Blob;} {
        let ?publicKey = public_key else { Debug.trap("Public key not populated."); };
        let ?selfAuthPrincipal = selfAuthenticatingPrincipal else Debug.trap("Self authenticating principal not populated.");
        return {selfAuthPrincipal; publicKey};
    };

    public shared func manageNeuron( args: Governance.ManageNeuron, proposer: Principal): async Result.Result<() , TreasuryTypes.Error>{
        let {selfAuthPrincipal; publicKey} = getSelfAuthenticatingPrincipalAndPublicKey_();
        let response = await AsyncronousHelperMethods.manageNeuron( neuronDataMap, pendingActionsMap, transformFn, args, ?proposer, ?Principal.fromActor(this), selfAuthPrincipal, publicKey);
        switch(response){ case(#ok()) return #ok(()); case(#err(_)) { throw Error.reject("Error managing neuron.") }; };
    };

    public query func transformFn({ response : IC.http_response; }) : async IC.http_response {
        let transformed : IC.http_response = { status = response.status; body = response.body; headers = []; };
        transformed;
    };

    system func preupgrade() { usersTreasuryDataArray := Iter.toArray(usersTreasuryDataMap.entries()); neuronDataArray := Iter.toArray(neuronDataMap.entries()); };
    system func postupgrade() { usersTreasuryDataArray:= []; neuronDataArray := []; };    
};