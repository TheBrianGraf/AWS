<#
    .NOTES
    ===========================================================================
	 Created by:   	Brian Graf
     Date:          July 7, 2018
	 Organization: 	VMware
     Blog:          www.brianjgraf.com
     Twitter:       @vBrianGraf
	===========================================================================

	.SYNOPSIS
		Delete 1 or many VPCs across accounts
	
	.DESCRIPTION
        I had a requirement to akke custom VPC's across about 5 different AWS accounts this week. I decided to script it all, but I also needed a script for tearing them down
#>

# DELETE VPCs

# Defining the regions I know I put VPCs in
$regions = @("us-west-2","us-east-1","eu-west-2")

# save the info from the CSV to a variable
$csv = import-csv "C:\Users\Brian\Github\AWS_CREDENTIALS.csv"

# for each row in the CSV
foreach ($item in $csv) {
    
    # Save the credentials
    $accesskey = $item.My_Access_Key
    $secretkey =  $item.My_Secret_Access_Key

    # In each region, do the following
    foreach ($region in $regions){

        # If there are any ec2 instances, delete them
        if (Get-EC2Instance -AccessKey $accesskey -SecretKey $secretkey -region $region) {Get-EC2Instance -AccessKey $accesskey -SecretKey $secretkey -region $region | % {Remove-EC2Instance -InstanceId $_.Instances.InstanceId -AccessKey $accesskey -SecretKey $secretkey -Force -region $region} else {write-host "No EC2 Instances exist"}}
        
        # If there are any RDS instances, delete them
        if (Get-RDSDBInstance -AccessKey $accesskey -SecretKey $secretkey -region $region) {Get-RDSDBInstance -AccessKey $accesskey -SecretKey $secretkey -region $region | % {Remove-RDSDBInstance -InstanceId $_.Instances.InstanceId -AccessKey $accesskey -SecretKey $secretkey -Force -region $region} else {write-host "No RDS Instances exist"}}
        
        # If there are any VPC's in the region, do the following
        if (get-ec2vpc -AccessKey $accesskey -SecretKey $secretkey -region $region){

            # Save the VPC to a variable
            $VPCs = get-ec2vpc -AccessKey $accesskey -SecretKey $secretkey -region $region 
            
            # Do the following for each VPC
            foreach ($vpcinstance in $vpcs) {

                # Find the endpoints and delete them
                $endpoints = get-ec2vpcendpoint -AccessKey $accesskey -SecretKey $secretkey -region $region | where {$_.VpcId -eq $vpc.vpcid}
                if ($endpoints -ne $null) {
                Remove-EC2VpcEndpoint -VpcEndpointId $endpoints.VpcEndpointId -Force -Confirm:$false -AccessKey $accesskey -SecretKey $secretkey -region $region}

                # Find the subnets and delete them
                foreach ($subnet in (Get-EC2Subnet -AccessKey $accesskey -SecretKey $secretkey -region $region)){
                    remove-ec2subnet -SubnetId $subnet.SubnetId -Force -AccessKey $accesskey -SecretKey $secretkey -region $region
                }
                # Find the IGW, dismount it, and delete it
                $IGWs = (Get-EC2InternetGateway -region $region -AccessKey $accesskey -SecretKey $secretkey) | where {$_.Attachments.vpcid -eq $vpcinstance.vpcid}
                foreach ($IGW in $IGWs){
                    
                    Dismount-EC2InternetGateway -InternetGatewayId $IGW.InternetGatewayId -VpcId $vpcinstance.vpcid -region $region -AccessKey $accesskey -SecretKey $secretkey -Force -Confirm:$false 
                    Remove-EC2InternetGateway -InternetGatewayId $IGW.InternetGatewayId -region $region -AccessKey $accesskey -SecretKey $secretkey -Force -Confirm:$false
                }
                # Find the route tables and delete them
                    $routetables = Get-EC2RouteTable -region $region -AccessKey $accesskey -SecretKey $secretkey | where {$_.vpcid -eq $vpcinstance.vpcid}
                    foreach ($route in $routetables) {
                    
                        Remove-EC2RouteTable -RouteTableId $route.RouteTableId -Force -Confirm:$false -region $region -AccessKey $accesskey -SecretKey $secretkey
                    }
                
                # output the VPC information
                write-host $vpcinstance.vpcid -AccessKey $accesskey -SecretKey $secretkey -region $region

                # Remove (delete) the VPC
                remove-ec2vpc -vpcID $vpcinstance.vpcId -AccessKey $accesskey -SecretKey $secretkey -region $region -Confirm:$false -Force

            }
        } 
    }

}


