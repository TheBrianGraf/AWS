


$sddcSvc = Get-VmcService com.vmware.vmc.orgs.sddcs
$sddcCreateSpec = $sddcSvc.Help.create.sddc_config.Create()
$sddcCreateSpec.Name = "VMUG_SDDC_1"
$sddcCreateSpec.Provider = "AWS"
$sddcCreateSpec.region = "US_WEST_2"
$sddcCreateSpec.num_hosts = "1"
$sddcCreateSpec.vpc_cidr = "172.31.0.0/16"
$sddcCreateSpec.deployment_type = "SingleAZ"
$accountLinkSpec = $sddcSvc.Help.create.sddc_config.account_link_sddc_config.Element.Create()
$accountLinkSpec.connected_account_id = "347cee52-82be-36c3-a7e7-2260e8ff8e4f"
$custSubId0 = $sddcSvc.Help.create.sddc_config.account_link_sddc_config.Element.customer_subnet_ids.Element.Create()
$custSubId0 = "subnet-742ddd0d"
$accountLinkSpec.customer_subnet_ids.Add($custSubId0)
$sddcCreateSpec.account_link_sddc_config.Add($accountLinkSpec)
$sddcSvc.create($orgId, $sddcCreateSpec)


#-----------------------------

# Create 8 VMC SDDC's for use with VMUG VMC Labs
1..8 | % {
Connect-VMCserver -RefreshToken 'df99c5e2-96c2-492a-a046-dd9aff5ce50d'
$num = $1
$orgs = Get-VmcService *orgs
#$org = $orgs.list() | Select-Object | where {$_.display_name -eq "VMUG Test Drive $num"}
$org = $orgs.list() | Select-Object | where {$_.display_name -eq "VMUG Test Drive"}
$orgid = $org.id
$accountlink = Get-VmcService com.vmware.vmc.orgs.account_link.connected_accounts
$LinkedAccount = $accountlink.get($orgid)
$LinkedAccountID = $LinkedAccount.id


$sddcSvc = Get-VmcService com.vmware.vmc.orgs.sddcs
$sddcCreateSpec = $sddcSvc.Help.create.sddc_config.Create()
$sddcCreateSpec.Name = "Katarina_SDDC"
$sddcCreateSpec.Provider = "AWS"
$sddcCreateSpec.region = "EU_WEST_2"
$sddcCreateSpec.num_hosts = "1"
$sddcCreateSpec.vpc_cidr = "10.2.0.0/16"
$sddcCreateSpec.deployment_type = "SingleAZ"
$accountLinkSpec = $sddcSvc.Help.create.sddc_config.account_link_sddc_config.Element.Create()
$custSubId0 = $sddcSvc.Help.create.sddc_config.account_link_sddc_config.Element.customer_subnet_ids.Element.Create()

switch ($num) {
    1 {$custSubId0 = "subnet-742ddd0d"}
    2 {$custSubId0 = "subnet-32896e79"}
    3 {$custSubId0 = "subnet-5e896e15"}
    4 {$custSubId0 = "subnet-2b8d6a60"}
    5 {$custSubId0 = "subnet-968f68dd"}
    6 {$custSubId0 = "subnet-f38a6db8"}
    7 {$custSubId0 = "subnet-818d6aca"}
    8 {$custSubId0 = "subnet-b88b6cf3"}
}

$accountLinkSpec.connected_account_id = "347cee52-82be-36c3-a7e7-2260e8ff8e4f"

$accountLinkSpec.customer_subnet_ids.Add($custSubId0)
$sddcCreateSpec.account_link_sddc_config.Add($accountLinkSpec)
$sddcSvc.create($orgId, $sddcCreateSpec)

Disconnect-VmcServer -Confirm:$false
}




#---------------------------------------------------------------

# Delete all SDDC's in an org

Connect-VMCserver -RefreshToken 8003df9b-44bd-410c-b850-664a73824a50
$orgs = Get-VmcService *orgs
$org = $orgs.list() | Select-Object | where {$_.display_name -eq "VMUG Test Drive"}
$orgid = $org.id

$sddcSvc = Get-VmcService com.vmware.vmc.orgs.sddcs
$SDDCs = $sddcSvc.list($orgID)
foreach ($Sddc in $sddcs) {
  $sddcsvc.delete($orgid, $sddc.id)
}

#---------------------------------------------------------------

# Create all VPCs
$csv = import-csv "C:\Users\Brian\OneDrive - VMware, Inc\VMUG AWS CREDENTIALS.csv"
foreach ($item in $csv) { 
    $accesskey = $item.My_Access_Key
    $secretkey =  $item.My_Secret_Access_Key
    $VPC = New-EC2Vpc  -CidrBlock "172.17.0.0/16" -Region $item.aws_region -AccessKey $accesskey -SecretKey $secretkey 
    $user = $item.user.Split(" ")[0]

    $tag = New-Object Amazon.EC2.Model.Tag
    $tag.Key = "Name"
    $tag.Value = "VPC-$user-1"

    New-EC2Tag -Resource $VPC.VpcId -Tag $tag -AccessKey $accesskey -SecretKey $secretkey -Region $item.aws_region
    Edit-EC2VpcAttribute -VpcId $VPC.vpcId -EnableDnsSupport $true -AccessKey $accesskey -SecretKey $secretkey -Region $item.aws_region
    Edit-EC2VpcAttribute -VpcId $VPC.vpcId -EnableDnsHostnames $true -AccessKey $accesskey -SecretKey $secretkey -Region $item.aws_region

    # Add IGW
    $igwResult = New-EC2InternetGateway -AccessKey $accesskey -SecretKey $secretkey -Region $item.aws_region
    $tag = New-Object Amazon.EC2.Model.Tag
    $tag.Key = "Name"
    $tag.Value = "IGW-$user-1"
    New-EC2Tag -Resource $igwResult.InternetGatewayId -Tag $tag -AccessKey $accesskey -SecretKey $secretkey -Region $item.aws_region

    # Attach to VPC
    Add-EC2InternetGateway -InternetGatewayId $igwResult.InternetGatewayId -VpcId $VPC.vpcId -AccessKey $accesskey -SecretKey $secretkey -Region $item.aws_region

    # Create Subnets for each VPC
    get-ec2vpc -Region $item.aws_region -AccessKey $accesskey -SecretKey $secretkey
    foreach ($zone in (Get-EC2AvailabilityZone -Region $item.aws_region -AccessKey $accesskey -SecretKey $secretkey).ZoneName){
        switch ($zone[-1]){
            "a" {$cidr = "172.17.1.0/24"}
            "b" {$cidr = "172.17.2.0/24"}
            "c" {$cidr = "172.17.3.0/24"}
            "d" {$cidr = "172.17.4.0/24"}
            "e" {$cidr = "172.17.5.0/24"}
            "f" {$cidr = "172.17.6.0/24"}
            "g" {$cidr = "172.17.7.0/24"}
            "h" {$cidr = "172.17.8.0/24"}

        }
        $newsubnet = New-EC2Subnet -VpcId $VPC.VPCId -AvailabilityZone $Zone -CidrBlock $cidr -Region $item.aws_region -AccessKey $accesskey -SecretKey $secretkey
        $tag = New-Object Amazon.EC2.Model.Tag
        $tag.Key = "Name"
        $simpleCIDR = $cidr.Split("/")[0]
        $tag.Value = "$simpleCIDR-$zone"
        New-EC2Tag -Resource $newsubnet.SubnetId -Tag $tag -AccessKey $accesskey -SecretKey $secretkey -Region $item.aws_region
    }
    $RT = Get-EC2RouteTable -Region $item.aws_region -AccessKey $accesskey -SecretKey $secretkey | where {$_.vpcid -eq $VPC.VPCId}
    $tag = New-Object Amazon.EC2.Model.Tag
    $tag.Key = "Name"
    $tag.Value = "$user-1-RT"
    New-EC2Tag -Resource $RT.RouteTableId -Tag $tag -AccessKey $accesskey -SecretKey $secretkey -Region $item.aws_region
    
    Register-EC2RouteTable -RouteTableId $rt.RouteTableId -SubnetId $newsubnet.SubnetId -Region $item.aws_region -AccessKey $accesskey -SecretKey $secretkey
    #Create new Route
    $newRoute = New-EC2Route -RouteTableId $rt.RouteTableId -GatewayId $igwresult.InternetGatewayId -DestinationCidrBlock ‘0.0.0.0/0’ -Region $item.aws_region -AccessKey $accesskey -SecretKey $secretkey

    #EC2 S3 Endpoint
    $simplifiedzone = $zone.Substring(0,$zone.Length-1)
    $endpoint = New-EC2VpcEndpoint -ServiceName "com.amazonaws.$simplifiedzone.s3" -RouteTableId $rt.RouteTableId -VpcId $vpc.vpcid -Region $item.aws_region -AccessKey $accesskey -SecretKey $secretkey
}


# DELETE VPCs
$regions = @("us-west-2","us-east-1","eu-west-2")
$csv = import-csv "C:\Users\Brian\OneDrive - VMware, Inc\VMUG AWS CREDENTIALS.csv"
foreach ($item in $csv) { 
    $accesskey = $item.My_Access_Key
    $secretkey =  $item.My_Secret_Access_Key
    foreach ($region in $regions){
        if (Get-EC2Instance -AccessKey $accesskey -SecretKey $secretkey -region $region) {Get-EC2Instance -AccessKey $accesskey -SecretKey $secretkey -region $region | % {Remove-EC2Instance -InstanceId $_.Instances.InstanceId -AccessKey $accesskey -SecretKey $secretkey -Force -region $region} else {write-host "No EC2 Instances exist"}}
        if (Get-RDSDBInstance -AccessKey $accesskey -SecretKey $secretkey -region $region) {Get-RDSDBInstance -AccessKey $accesskey -SecretKey $secretkey -region $region | % {Remove-RDSDBInstance -InstanceId $_.Instances.InstanceId -AccessKey $accesskey -SecretKey $secretkey -Force -region $region} else {write-host "No RDS Instances exist"}}
        if (get-ec2vpc -AccessKey $accesskey -SecretKey $secretkey -region $region){
            $VPCs = get-ec2vpc -AccessKey $accesskey -SecretKey $secretkey -region $region 
            foreach ($vpcinstance in $vpcs) {
                $endpoints = get-ec2vpcendpoint -AccessKey $accesskey -SecretKey $secretkey -region $region | where {$_.VpcId -eq $vpc.vpcid}
                if ($endpoints -ne $null) {
                Remove-EC2VpcEndpoint -VpcEndpointId $endpoints.VpcEndpointId -Force -Confirm:$false -AccessKey $accesskey -SecretKey $secretkey -region $region}

                foreach ($subnet in (Get-EC2Subnet -AccessKey $accesskey -SecretKey $secretkey -region $region)){
                    remove-ec2subnet -SubnetId $subnet.SubnetId -Force -AccessKey $accesskey -SecretKey $secretkey -region $region
                }
                # IGW
                $IGWs = (Get-EC2InternetGateway -region $region -AccessKey $accesskey -SecretKey $secretkey) | where {$_.Attachments.vpcid -eq $vpcinstance.vpcid}
                foreach ($IGW in $IGWs){
                    
                    Dismount-EC2InternetGateway -InternetGatewayId $IGW.InternetGatewayId -VpcId $vpcinstance.vpcid -region $region -AccessKey $accesskey -SecretKey $secretkey -Force -Confirm:$false 
                    Remove-EC2InternetGateway -InternetGatewayId $IGW.InternetGatewayId -region $region -AccessKey $accesskey -SecretKey $secretkey -Force -Confirm:$false
                }
                # Route Tables
                    $routetables = Get-EC2RouteTable -region $region -AccessKey $accesskey -SecretKey $secretkey | where {$_.vpcid -eq $vpcinstance.vpcid}
                    foreach ($route in $routetables) {
                    
                        Remove-EC2RouteTable -RouteTableId $route.RouteTableId -Force -Confirm:$false -region $region -AccessKey $accesskey -SecretKey $secretkey
                    }

                write-host $vpcinstance.vpcid -AccessKey $accesskey -SecretKey $secretkey -region $region
                remove-ec2vpc -vpcID $vpcinstance.vpcId -AccessKey $accesskey -SecretKey $secretkey -region $region -Confirm:$false -Force

            }
        } 
    }

}

