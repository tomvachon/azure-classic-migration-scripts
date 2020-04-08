$Classic_VM_List = Get-AzureVM

Foreach($vm in $Classic_VM_List) {


    $endpoint_list = Get-AzureEndpoint -VM $vm

    
    if($endpoint_list.Acl.length -gt 0) {
        
        # Location is not derived from Get-AzureVM, but the Disk has it
        $disk = Get-AzureDisk -DiskName  $vm.VM.OSVirtualHardDisk.DiskName
        $location = $disk.Location 

        $nsg_name = $vm.Name + "-endpoint-nsg"
        $nsg = New-AzureNetworkSecurityGroup -Location $location -Name $nsg_name

        $endpoint_list

        $rule_id = 100

        Foreach($endpoint in $endpoint_list) {
        
          $remote_port = $endpoint.port
          $local_port = $endpoint.LocalPort
          $protocol = $endpoint.Protocol.ToUpper()
          $vip = $endpoint.Vip
          $acl_list = $endpoint.Acl

          $ip_protocol = ""

          # Note: This script DOES NOT preserve the order of the rules between the different ports.  The order of rules IS PRESERVED for a given port.
     
          Foreach($acl in $acl_list) {
                    
            Write-Debug "Start - Next Rule is: " + $rule_id

            if($acl.Action -eq "permit") {
                
                $local_ip =  $vm.IpAddress + "/32"

                $rule = Set-AzureNetworkSecurityRule  -Action "Allow" -DestinationAddressPrefix $local_ip  -DestinationPortRange $local_port -Name $acl.Description -NetworkSecurityGroup $nsg -Priority $rule_id -Protocol $protocol -SourceAddressPrefix $acl.RemoteSubnet -SourcePortRange "*" -Type "Inbound"
            }

         
            if($acl.Action -eq "deny") {
   
                $local_ip =  $vm.IpAddress + "/32"

               $rule = Set-AzureNetworkSecurityRule -Action "Deny" -DestinationAddressPrefix $local_ip -DestinationPortRange $local_port -Name $acl.Description -NetworkSecurityGroup $nsg -Priority $rule_id -Protocol $protocol -SourceAddressPrefix $acl.RemoteSubnet -SourcePortRange "*" -Type "Inbound"
            }

          $rule_id = $rule_id + 1
            
          Write-Debug "End - Next Rule is: " $rule_id 

          }#End Acl List
        }

   

         #Remove the old Endpoint ACL's
         Foreach($endpoint in $endpoint_list) {

            Write-Debug "Removing Endpoint: " $endpoint.Name                   
            $junk = Remove-AzureAclConfig -EndpointName $endpoint.Name -VM $vm | Update-AzureVM
            
         }
         Set-AzureNetworkSecurityGroupAssociation -Name $nsg.Name -ServiceName $vm.ServiceName -VM $vm
         

   }

  
}