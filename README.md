# Azure Classic to ARM Migration Scripts

These are helper scripts which assist in Azure Classic to ARM migration prerequisites.

### [Migrate-AzureClassic-EndpointACL-to-NSG.ps1](Migrate-AzureClassic-EndpointACL-to-NSG.ps1)
This script iterates over each VM in your Azure Classic environment and inspects it for any endpoints with ACL's enabled.  
The script then takes those ACL's and converts them to a net-new Classic NSG rules (one NSG per VM is the max).
    
Its ***VERY IMPORTANT TO NOTE*** the order of endpoints cannot be preserved as they are returned lexographically by their display name.
However, the order of the ACL's WITHIN a given endpoint is preserved.
    
Additionally, there is a portion of work where each VM will be ***COMPLETELY*** unprotected from a network prospective.  As all
endpoint ACL's must be removed before the NSG can be applied.  This can take quite a bit of time as each purge of the ACL's requires UpdateVM
to be invoked before continuing to the next Endpoint.  This time duration will be directly proportionate to the amount of Endpoints on a given VM.
