using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$maxItems = 13370 #zero based ids!

#get query parameters
$page = $Request.Query.page 
$pageSize = $Request.Query.pageSize
$offset = $Request.Query.offset 

Write-Host "Function invoked with parameters: `npage: $page`npageSize: $pageSize`noffset: $offset"

#if an offset is supplied, calculate the page number based on the offset and page size
if($offset){
    $page = [math]::Ceiling($offset/$pageSize)
}
#set default values if not supplied
if((-not $page -or $page -eq 0) -and -not $offset){
    $page = 1
}
if(-not $pageSize -or $pageSize -eq 0){
    $pageSize = 100
}

#generate random but consistent values for each record
#using the id as a seed for Get-Random to ensure the same value is returned for
function Get-Record {
    param(
        [int]$id
        )
    
    $value = [math]::round((Get-Random -Minimum 10.00 -Maximum 100.00 -SetSeed $id),2)

    return @{
        id = $id
        value = $value
    }
}

#create pages and include multiple pagination styles
function Get-PaginatedItems {
    param(
        [int]$page = 1,
        [int]$pageSize = 10,
        [int]$offset = 0
    )

    #calculate smallest id based on offset and pagesize
    $minId = (($offset, ($pageSize * ($page-1))) | Measure -Maximum).Maximum
    Write-Host "Min ID: $minId"


    #generate records for the next items starting at minId until the maxium pageSize or maxItems have been reached
    $items = @()
    $upperBound = (($maxItems, ($pageSize+$minId)) | Measure -Minimum).Minimum
    Write-Host "Upper bound: $upperBound"
    for ($i = $minId; $i -lt $upperBound; $i++) {
        $items += Get-Record -id $i
    }

    $totalPages = [math]::Ceiling($maxItems / $pageSize)

    $result = @{
        items      = $items
        page       = $page
        pageSize   = $pageSize
        totalItems = $maxItems
        totalPages = $totalPages
    }

    $links = @{}
    $relLinks = @{}
    $hasMore = $false
    $baseUrl =  $Request.Url.ToString().split("?")[0]

    
    if ($page -gt 1) {
        $links["prev"] = $baseUrl + "?page=$($page - 1)&pageSize=$pageSize"
        $relLinks["prev"] = "?page=$($page - 1)&pageSize=$pageSize"
    }
    if ($page -lt $totalPages) {
        $links["next"] = $baseUrl + "?page=$($page + 1)&pageSize=$pageSize"
        $relLinks["next"] = "?page=$($page + 1)&pageSize=$pageSize"
        $hasMore = $true
    }

    $result["links"] = $links
    $result["relativeLinks"] = $relLinks
    if($hasMore -and $upperBound -lt $maxItems){
        $result["hasMore"] = $hasMore
    }
    return $result
}

$result = Get-PaginatedItems -page $page -pageSize $pageSize -offset $offset

$headers = @{
    "link" = "<" + $result.links.next + '>; rel="next"'
}
$body = $result

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = $body
        Headers = $headers
    })
