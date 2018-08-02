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
		Create 1 or many VPCs across accounts
	
	.DESCRIPTION
        I had a requirement to make custom VPC's across about 5 different AWS accounts this week. I decided to script it all
#>
# Create all VPCs
$csv = import-csv "C:\Users\Brian\Github\AWS_Creds.csv"
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

