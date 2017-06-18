# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 09-Nov-2016.

# https://www.appveyor.com/docs/how-to/git-push/

param(
    $Info,

    # Git username
    [string] $User,

    # Git password. You can use Github Token here if you omit username.
    [string] $Password,

    #Force git commit when package is updated but not pushed.
    [switch] $Force
)

[array]$packages = if ($Force) { $Info.result.updated } else { $Info.result.pushed }
if ($packages.Length -eq 0) { Write-Host "No package updated, skipping"; return }

$root = Split-Path $packages[0].Path
pushd $root
$origin  = git config --get remote.origin.url
$origin -match '(?<=:/+)[^/]+' | Out-Null
$machine = $Matches[0]

if ($User -and $Password) {
    Write-Host "Setting credentials for: $machine"

    if ( "machine $server" -notmatch (gc ~/_netrc)) {
        Write-Host "Credentials already found for machine: $machine"
    }
    "machine $machine", "login $User", "password $Password" | Out-File -Append ~/_netrc -Encoding ascii
} elseif ($Password) {
    Write-Host "Setting oauth token for: $machine"
    git config --global credential.helper store
    Add-Content "$env:USERPROFILE\.git-credentials" "https://${Password}:x-oauth-basic@$machine`n"
}

Write-Host "Executing git pull"
git checkout -q master
git pull -q origin master

Write-Host "Adding updated packages to git repository: $( $packages | % Name)"
$packages | % { git add -u $_.Path }
git status

Write-Host "Commiting"
$message = "AU: $($packages.Length) updated - $($packages | % Name)"
$gist_url = $Info.plugin_results.Gist -split '\n' | select -Last 1
git commit -m "$message`n[skip ci] $gist_url" --allow-empty

Write-Host "Pushing Master"
git push -q

Write-Host "Merging master -> dev"
git checkout -q dev
git pull -q origin dev
git merge -Xtheirs -q master
git status

Write-Host "Pushing Dev"
git push -q

Write-Host "Merging dev -> staging"
git checkout -q staging
git pull -q origin staging
git merge -Xtheirs -q dev
git status

Write-Host "Pushing Staging"
git push -q


popd
