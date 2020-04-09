#Requires -Modules Azure
<#
.SYNOPSIS
    This script converts Azure Classic Endpoint ACL's to Azure Classic NSG's enabling the "ASM->ARM Migration"
.DESCRIPTION
    This script iterates over each VM in your Azure Classic environment and inspects it for any endpoints with ACL's enabled.  
    The script then takes those ACL's and converts them to a net-new Classic NSG rules (one NSG per VM is the max).
    
    Its VERY IMPORTANT TO NOTE the order of endpoints cannot be preserved as they are returned lexographically by their display name.
    However, the order of the ACL's WITHIN a given endpoint is preserved.
    
    Additionally, there is a portion of work where each VM will be COMPLETELY unprotected from a network prospective.  As all
    endpoint ACL's must be removed before the NSG can be applied.  This can take quite a bit of time as each purge of the ACL's requires UpdateVM
    to be invoked before continuing to the next Endpoint.  This time duration will be directly proportionate to the amount of Endpoints on a given VM.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    Version:        1.0
    Author:         Thomas Vachon
    Creation Date:  2020/Apr/09
    Purpose/Change: Initial script development
#>

$Classic_VM_List = Get-AzureVM

Foreach($vm in $Classic_VM_List) {

    $endpoint_list = Get-AzureEndpoint -VM $vm
  
    # Look at the endpoints returned to see if there are any nested ACL objects 
    # which need to be converted to NSG rules, if none exist, the rest of the script is ignored
    if($endpoint_list.Acl.length -gt 0) {

        Write-Output -MessageData ("VM {0} has {1} Endpoint ACL's to convert" -f $vm.Name, $endpoint_list.Acl.length)
        
        # Location is not derived from Get-AzureVM, but the Disk has it
        $disk = Get-AzureDisk -DiskName  $vm.VM.OSVirtualHardDisk.DiskName
        $location = $disk.Location 

        $nsg_name = $vm.Name + "-endpoint-nsg"
        $nsg = New-AzureNetworkSecurityGroup -Location $location -Name $nsg_name

        Write-Output -MessageData ("NSG {0} has been created for this conversion" -f $nsg.Name)

        $rule_id = 100

        Foreach($endpoint in $endpoint_list) {
        
            $local_port = $endpoint.LocalPort
            $protocol = $endpoint.Protocol.ToUpper()
            $acl_list = $endpoint.Acl

            # Note: This script DOES NOT preserve the order of the rules between the different ports.  
            # The order of rules IS PRESERVED for a given port.
     
            Foreach($acl in $acl_list) {
                    
                Write-Debug -Message ("Start - Next Rule is: {0}" -f $rule_id)

                if($acl.Action -eq "permit") {
                
                    $local_ip =  $vm.IpAddress + "/32"
                    Set-AzureNetworkSecurityRule -Action "Allow" -DestinationAddressPrefix $local_ip -DestinationPortRange $local_port -Name $acl.Description -NetworkSecurityGroup $nsg -Priority $rule_id -Protocol $protocol -SourceAddressPrefix $acl.RemoteSubnet -SourcePortRange "*" -Type "Inbound" | Out-Null
                }

         
                if($acl.Action -eq "deny") {
   
                    $local_ip =  $vm.IpAddress + "/32"
                    Set-AzureNetworkSecurityRule -Action "Deny" -DestinationAddressPrefix $local_ip -DestinationPortRange $local_port -Name $acl.Description -NetworkSecurityGroup $nsg -Priority $rule_id -Protocol $protocol -SourceAddressPrefix $acl.RemoteSubnet -SourcePortRange "*" -Type "Inbound" | Out-Null
            
                }

                $rule_id = $rule_id + 1
                Write-Debug -Message ("End - Next Rule is: {0}" -f $rule_id)

            }#End Acl List
        }

        Write-Information -MessageData ("VM {0} endpoint ACL purging is starting" -f $vm.Name)

        #Remove the old Endpoint ACL's
        Foreach($endpoint in $endpoint_list) {
                    
            Write-Debug -Message ("Removing Endpoint ACL's on {0}" -f $endpoint.Name)
            Remove-AzureAclConfig -EndpointName $endpoint.Name -VM $vm | Update-AzureVM | Out-Null
            
        }
        
        Write-Debug -Message ("VM {0} endpoint ACL purging is done" -f $vm.Name)

        Set-AzureNetworkSecurityGroupAssociation -Name $nsg.Name -ServiceName $vm.ServiceName -VM $vm | Out-Null
        
        Write-Output -MessageData ("VM {0} endpoint ACL purging is done and NSG is applied" -f $vm.Name)

    }
    else {

        Write-Output ("VM {0} has no endpoint ACL's to convert" -f $vm.Name)
    
    }

}
